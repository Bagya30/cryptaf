const admin = require('firebase-admin');

async function checkEmergencyStatus() {
  console.log('Starting Emergency Status Check...');

  // Initialize Firebase Admin
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('Firebase Admin initialized successfully.');
  } catch (error) {
    console.error('Failed to parse FIREBASE_SERVICE_ACCOUNT or initialize Firebase Admin:', error);
    process.exit(1);
  }

  const db = admin.firestore();
  
  const EMAILJS_SERVICE_ID = process.env.EMAILJS_SERVICE_ID;
  const EMAILJS_TEMPLATE_ID = process.env.EMAILJS_TEMPLATE_ID_DEFAULT;
  const EMAILJS_USER_ID = process.env.EMAILJS_USER_ID;

  if (!EMAILJS_SERVICE_ID || !EMAILJS_TEMPLATE_ID || !EMAILJS_USER_ID) {
    console.warn('EmailJS environment variables are missing. Emails will not be sent.');
  }

  try {
    const usersRef = db.collection('users');
    const snapshot = await usersRef.where('emergencyEnabled', '==', true).get();

    if (snapshot.empty) {
      console.log('No users with emergency enabled found.');
      return;
    }

    const now = new Date();
    console.log(`Checking ${snapshot.size} users with emergencyEnabled...`);

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const lastActiveTs = data.lastActiveTime;
      const durationHours = data.emergencyDurationHours || 168; // default to 7 days
      const currentStatus = data.emergencyStatus;
      const userName = data.name || data.email || 'User';

      if (!lastActiveTs) {
        console.log(`User ${doc.id} has no lastActiveTime. Skipping.`);
        continue;
      }

      const lastActiveTime = lastActiveTs.toDate();
      const diffMs = now.getTime() - lastActiveTime.getTime();
      const diffHours = diffMs / (1000 * 60 * 60);

      console.log(`User ${doc.id} - Inactive for ${diffHours.toFixed(2)} hours (Threshold: ${durationHours} hours). Status: ${currentStatus}`);

      if (diffHours >= durationHours) {
        if (currentStatus !== 'expired') {
          console.log(`User ${doc.id} timer EXPIRED. Updating status to "expired".`);
          
          // 1. Update status in Firestore
          await doc.ref.update({
            emergencyStatus: 'expired'
          });
          console.log(`Updated user ${doc.id} emergencyStatus to 'expired'.`);

          // 2. Fetch nominees
          const nomineesSnapshot = await doc.ref.collection('nominees').get();
          console.log(`Found ${nomineesSnapshot.size} nominees for user ${doc.id}.`);

          // 3. Send email to each nominee
          for (const nomineeDoc of nomineesSnapshot.docs) {
            const nomineeData = nomineeDoc.data();
            const nomineeEmail = nomineeData.email;

            if (nomineeEmail && EMAILJS_SERVICE_ID) {
              console.log(`Sending email to nominee: ${nomineeEmail}`);
              
              const timeStr = `${now.getHours()}:${now.getMinutes().toString().padStart(2, '0')} on ${now.getDate()}/${now.getMonth() + 1}/${now.getFullYear()}`;
              const message = `The vault owner (${userName}) has been inactive and emergency access has been granted. Visit https://cryptaf-36296.web.app/nominee-access?vaultOwner=${doc.id} to request access.`;
              
              const payload = {
                service_id: EMAILJS_SERVICE_ID,
                template_id: EMAILJS_TEMPLATE_ID,
                user_id: EMAILJS_USER_ID,
                template_params: {
                  email: nomineeEmail,
                  time: timeStr,
                  message: message,
                  passcode: message
                }
              };

              try {
                // Node 18+ has built-in fetch
                const response = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify(payload)
                });
                
                if (response.ok) {
                  console.log(`Successfully sent email to ${nomineeEmail}.`);
                } else {
                  const text = await response.text();
                  console.error(`Failed to send email to ${nomineeEmail}: ${response.status} ${response.statusText} - ${text}`);
                }
              } catch (emailErr) {
                console.error(`Exception sending email to ${nomineeEmail}:`, emailErr);
              }
            } else {
               console.log(`Skipping email for nominee ${nomineeDoc.id} - missing email or EmailJS config`);
            }
          }
        } else {
          console.log(`User ${doc.id} is already expired. No action needed.`);
        }
      }
    }
    console.log('Emergency Status Check complete.');
  } catch (error) {
    console.error('Error querying users or processing data:', error);
    process.exit(1);
  }
}

checkEmergencyStatus();
