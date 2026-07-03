const functions = require("firebase-functions");
const admin = require("firebase-admin");
const cors = require("cors")({ origin: true });
const axios = require("axios");

admin.initializeApp();

const rateLimits = {};

exports.askGemini = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }

    try {
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).send({ error: 'Unauthorized: Missing or invalid token' });
      }

      const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown';
      const nowMs = Date.now();
      if (!rateLimits[ip]) {
        rateLimits[ip] = { count: 1, firstRequest: nowMs };
      } else {
        if (nowMs - rateLimits[ip].firstRequest > 60000) {
          rateLimits[ip] = { count: 1, firstRequest: nowMs };
        } else {
          rateLimits[ip].count++;
          if (rateLimits[ip].count > 10) {
            return res.status(429).send({ error: 'Too Many Requests' });
          }
        }
      }

      const idToken = authHeader.split('Bearer ')[1];
      try {
        await admin.auth().verifyIdToken(idToken);
      } catch (error) {
        return res.status(401).send({ error: 'Unauthorized: Invalid token' });
      }

      const userMessage = req.body.message;
      if (!userMessage) {
        return res.status(400).send({ error: "Message is required" });
      }

      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) {
        return res.status(500).send({ error: "Gemini API key is not configured" });
      }
      
      const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;
      
      const payload = {
        contents: [
          {
            parts: [{ text: userMessage }]
          }
        ]
      };

      const geminiResponse = await axios.post(url, payload, {
        headers: { 'Content-Type': 'application/json' }
      });

      res.status(200).send(geminiResponse.data);
    } catch (error) {
      console.error("Gemini Error:", error.response ? JSON.stringify(error.response.data) : error.message);
      res.status(500).send({ 
        error: "Failed to connect to Gemini API", 
        details: error.response ? error.response.data : error.message 
      });
    }
  });
});

exports.checkDeadMansSwitch = functions.pubsub.schedule('every 1 hours').onRun(async (context) => {
  const db = admin.firestore();
  const now = Date.now();
  
  const usersSnapshot = await db.collection('users')
    .where('emergencyEnabled', '==', true)
    .get();

  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    
    if (data.deadMansSwitchTriggered === true || data.emergencyStatus === 'expired') {
      continue;
    }
    
    const emergencyDurationHours = data.emergencyDurationHours || 168; // Default 7 days
    if (emergencyDurationHours < 1 || emergencyDurationHours > 720) {
      console.warn(`Invalid emergency duration for user ${doc.id}: ${emergencyDurationHours}. Skipping.`);
      continue;
    }
    const durationMs = emergencyDurationHours * 60 * 60 * 1000;
    
    let lastActiveTs = data.lastActiveTime;
    if (!lastActiveTs) {
      lastActiveTs = data.activationTimestamp;
    }
    
    if (!lastActiveTs) continue;
    
    const lastActiveTimeMs = lastActiveTs.toDate().getTime();
    
    if (now - lastActiveTimeMs > durationMs) {
      // Triggered!
      const userName = data.name || data.email || 'User';
      
      const nomineesSnap = await db.collection('users').doc(doc.id).collection('nominees').get();
      
      for (const nomineeDoc of nomineesSnap.docs) {
        const nomineeData = nomineeDoc.data();
        const nomineeEmail = nomineeData.email;
        if (!nomineeEmail) continue;
        
        try {
          const nowDt = new Date();
          const timeStr = `${nowDt.getHours()}:${nowDt.getMinutes().toString().padStart(2, '0')} on ${nowDt.getDate()}/${nowDt.getMonth() + 1}/${nowDt.getFullYear()}`;
          const message = `You have been granted access to ${userName}'s vault. Visit https://cryptaf-36296.web.app/nominee-access to access.`;

          await axios.post('https://api.emailjs.com/api/v1.0/email/send', {
            service_id: 'service_ojzr03j',
            template_id: 'template_login_alert',
            user_id: 'swqxQASivvKsrJjvQ',
            template_params: {
              email: nomineeEmail,
              time: timeStr,
              message: message,
              passcode: message
            }
          }, {
            headers: { 'Content-Type': 'application/json' }
          });
          console.log(`Sent email to ${nomineeEmail}`);
        } catch (error) {
          console.error(`Failed to send email to ${nomineeEmail}:`, error.message);
        }
      }
      
      // Update user document
      await db.collection('users').doc(doc.id).update({
        deadMansSwitchTriggered: true,
        emergencyStatus: 'expired'
      });
      console.log(`Triggered dead man's switch for user ${doc.id}`);
    }
  }
});

