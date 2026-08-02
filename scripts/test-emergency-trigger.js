const admin = require('firebase-admin');

async function testEmergencyTrigger() {
  console.log('Starting Test Emergency Trigger...');

  // Initialize Firebase Admin
  try {
    const fs = require('fs');
    const serviceAccount = JSON.parse(fs.readFileSync('C:\\Users\\BAGYALAKSHMI\\Downloads\\cryptaf-36296-firebase-adminsdk-fbsvc-308fa2e013.json', 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('Firebase Admin initialized successfully.');
  } catch (error) {
    console.error('Failed to parse local service account JSON or initialize Firebase Admin:', error);
    process.exit(1);
  }

  const db = admin.firestore();
  
  const EMAILJS_SERVICE_ID = process.env.EMAILJS_SERVICE_ID;
  const EMAILJS_TEMPLATE_ID = process.env.EMAILJS_TEMPLATE_ID_DEFAULT;
  const EMAILJS_USER_ID = process.env.EMAILJS_USER_ID;
  const EMAILJS_PRIVATE_KEY = process.env.EMAILJS_PRIVATE_KEY;

  if (!EMAILJS_SERVICE_ID || !EMAILJS_TEMPLATE_ID || !EMAILJS_USER_ID || !EMAILJS_PRIVATE_KEY) {
    console.warn('EmailJS environment variables (including private key) are missing. Emails will not be sent.');
  }

  const userId = 'BVimd4RYK9Zdv77ju5SuyhV6nRx1';
  let originalDuration = 72;

  try {
    const userRef = db.collection('users').doc(userId);
    const doc = await userRef.get();

    if (!doc.exists) {
      console.log(`User ${userId} not found.`);
      process.exit(1);
    }

    const data = doc.data();
    originalDuration = data.emergencyDurationHours || 72;
    console.log(`Step 1: Found user. Original emergencyDurationHours is ${originalDuration}.`);

    // Temporarily set to 1
    console.log(`Step 2: Temporarily setting emergencyDurationHours to 1...`);
    await userRef.update({
      emergencyDurationHours: 1
    });

    // Run the expiry check logic for this specific user
    console.log(`Step 3: Running expiry check logic for user ${userId}...`);
    
    // Fetch again just to be sure we have the updated data
    const updatedDoc = await userRef.get();
    const updatedData = updatedDoc.data();
    
    const now = new Date();
    const lastActiveTs = updatedData.lastActiveTime;
    const durationHours = updatedData.emergencyDurationHours; 
    const currentStatus = updatedData.emergencyStatus;
    const userName = updatedData.name || updatedData.email || 'User';

    if (!lastActiveTs) {
      console.log(`User ${userId} has no lastActiveTime. Cannot proceed with check.`);
    } else {
      const lastActiveTime = lastActiveTs.toDate();
      const diffMs = now.getTime() - lastActiveTime.getTime();
      const diffHours = diffMs / (1000 * 60 * 60);

      console.log(`User ${userId} - Inactive for ${diffHours.toFixed(2)} hours (Threshold: ${durationHours} hours). Status: ${currentStatus}`);

      if (diffHours >= durationHours) {
        if (currentStatus !== 'expired') {
          console.log(`User ${userId} timer EXPIRED. Updating status to "expired".`);
          
          // 1. Update status in Firestore
          await userRef.update({
            emergencyStatus: 'expired'
          });
          console.log(`Updated user ${userId} emergencyStatus to 'expired'.`);

          // 2. Fetch nominees
          const nomineesSnapshot = await userRef.collection('nominees').get();
          console.log(`Found ${nomineesSnapshot.size} nominees for user ${userId}.`);

          // 3. Send email to each nominee
          for (const nomineeDoc of nomineesSnapshot.docs) {
            const nomineeData = nomineeDoc.data();
            const nomineeEmail = nomineeData.email;

            if (nomineeEmail && EMAILJS_SERVICE_ID) {
              console.log(`Sending email to nominee: ${nomineeEmail}`);
              
              const timeStr = `${now.getHours()}:${now.getMinutes().toString().padStart(2, '0')} on ${now.getDate()}/${now.getMonth() + 1}/${now.getFullYear()}`;
              const message = `The vault owner (${userName}) has been inactive and emergency access has been granted. Visit https://cryptaf-36296.web.app/nominee-access?vaultOwner=${userId} to request access.`;
              
              const payload = {
                service_id: EMAILJS_SERVICE_ID,
                template_id: EMAILJS_TEMPLATE_ID,
                user_id: EMAILJS_USER_ID,
                accessToken: EMAILJS_PRIVATE_KEY,
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
          console.log(`User ${userId} is already expired. No action needed.`);
        }
      } else {
        console.log(`User ${userId} timer has not expired yet.`);
      }
    }

  } catch (error) {
    console.error('Error during test execution:', error);
  } finally {
    // Restore the original duration
    console.log(`Step 4: Restoring original emergencyDurationHours to ${originalDuration}...`);
    try {
      const userRef = db.collection('users').doc(userId);
      await userRef.update({
        emergencyDurationHours: originalDuration
      });
      console.log('Restoration complete.');
    } catch (restoreError) {
      console.error('Failed to restore original emergencyDurationHours:', restoreError);
    }
    process.exit(0);
  }
}

testEmergencyTrigger();
