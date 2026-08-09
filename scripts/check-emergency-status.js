const admin = require('firebase-admin');

async function checkEmergencyStatus(dbMock = null, fetchMock = null) {
  console.log('Starting Emergency Status Check...');

  let db = dbMock;
  let customFetch = fetchMock || (typeof fetch !== 'undefined' ? fetch : null);

  if (!dbMock) {
    try {
      if (process.env.FIREBASE_SERVICE_ACCOUNT) {
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        if (admin.apps.length === 0) {
          admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
          });
        }
      } else {
        if (admin.apps.length === 0) {
          admin.initializeApp();
        }
      }
      console.log('Firebase Admin initialized successfully.');
      db = admin.firestore();
    } catch (error) {
      console.error('Failed to parse FIREBASE_SERVICE_ACCOUNT or initialize Firebase Admin:', error);
      process.exit(1);
    }
  }

  const EMAILJS_SERVICE_ID = process.env.EMAILJS_SERVICE_ID || 'mock_service_id';
  const EMAILJS_TEMPLATE_ID = process.env.EMAILJS_TEMPLATE_ID_DEFAULT || 'mock_template_id';
  const EMAILJS_USER_ID = process.env.EMAILJS_USER_ID || 'mock_user_id';
  const EMAILJS_PRIVATE_KEY = process.env.EMAILJS_PRIVATE_KEY || 'mock_private_key';

  if (!process.env.EMAILJS_SERVICE_ID && !fetchMock) {
    console.warn('EmailJS environment variables are missing. Emails will not be sent.');
  }

  let hasErrors = false;

  try {
    const usersRef = db.collection('users');
    const snapshot = await usersRef.get();

    if (snapshot.empty) {
      console.log('No users found.');
      return;
    }

    const now = new Date();
    console.log(`Checking ${snapshot.size} total users...`);

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const userName = data.name || data.email || 'User';

      // Load authoritative info document
      const infoRef = doc.ref.collection('publicMeta').doc('info');
      const infoSnapshot = await infoRef.get();

      if (!infoSnapshot.exists) {
        continue;
      }

      const infoData = infoSnapshot.data();

      if (infoData.emergencyEnabled !== true) {
        console.log(`User ${doc.id} - emergencyEnabled is false or missing. Skipping...`);
        continue;
      }

      if (!infoData.emergencyDeadline) {
        console.log(`User ${doc.id} - Missing emergencyDeadline. Skipping...`);
        continue;
      }

      let deadlineDate;
      if (infoData.emergencyDeadline.toDate) {
         deadlineDate = infoData.emergencyDeadline.toDate();
      } else {
         // Mock timestamp fallback
         deadlineDate = new Date(infoData.emergencyDeadline.seconds * 1000);
      }
      
      const deadlineEpoch = deadlineDate.getTime();
      const isExpired = now >= deadlineDate;

      console.log(`User ${doc.id} - Deadline: ${deadlineDate.toISOString()}. Now: ${now.toISOString()}.`);
      
      if (isExpired) {
        console.log(`User ${doc.id} timer EXPIRED.`);
        
        // 1. Fetch nominees
        const nomineesSnapshot = await doc.ref.collection('nominees').get();
        console.log(`Found ${nomineesSnapshot.size} nominees for user ${doc.id}.`);

        // 2. Send email to each nominee (with per-nominee retry tracking)
        for (const nomineeDoc of nomineesSnapshot.docs) {
          const nomineeData = nomineeDoc.data();
          const nomineeEmail = nomineeData.email;
          const notifiedMap = nomineeData.notifiedDeadlines || {};

          // Idempotency check: has this nominee already been notified for THIS EXACT deadline?
          if (notifiedMap[deadlineEpoch] === true) {
            console.log(`User ${doc.id} - Nominee ${nomineeEmail} already notified for deadline ${deadlineEpoch}. Skipping.`);
            continue;
          }

          if (nomineeEmail && EMAILJS_SERVICE_ID) {
            console.log(`Sending email to nominee: ${nomineeEmail}`);
            
            const message = `The vault owner (${userName}) has been inactive and emergency access has been granted. Eligible inherited files are now available. Visit https://cryptaf-36296.web.app/nominee-access?vaultOwner=${doc.id} to request access.`;
            
            const payload = {
              service_id: EMAILJS_SERVICE_ID,
              template_id: EMAILJS_TEMPLATE_ID,
              user_id: EMAILJS_USER_ID,
              accessToken: EMAILJS_PRIVATE_KEY,
              template_params: {
                email: nomineeEmail,
                message: message,
                passcode: message
              }
            };

            try {
              if (!customFetch) throw new Error('Fetch API not available');
              
              const response = await customFetch('https://api.emailjs.com/api/v1.0/email/send', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
              });
              
              if (response.ok) {
                console.log(`Successfully sent email to ${nomineeEmail}.`);
                // Mark success for this specific deadline
                await nomineeDoc.ref.set({
                  notifiedDeadlines: {
                    [deadlineEpoch]: true
                  }
                }, { merge: true });
                console.log(`Recorded notification success for nominee ${nomineeEmail}.`);
              } else {
                let text = '';
                if (response.text) text = await response.text();
                console.error(`Failed to send email to ${nomineeEmail}: ${response.status} - ${text}`);
                hasErrors = true;
                // DO NOT write success marker, allows retry on next run.
              }
            } catch (emailErr) {
              console.error(`Exception sending email to ${nomineeEmail}:`, emailErr);
              hasErrors = true;
              // DO NOT write success marker, allows retry on next run.
            }
          } else {
             console.log(`Skipping email for nominee ${nomineeDoc.id} - missing email`);
          }
        }
        
        // Update emergencyStatus conditionally (informational only)
        if (infoData.emergencyStatus !== 'expired') {
          await infoRef.set({ emergencyStatus: 'expired' }, { merge: true });
        }

      } else {
         console.log(`User ${doc.id} timer has NOT expired yet.`);
      }
    }
    console.log('Emergency Status Check complete.');
    if (hasErrors) {
      throw new Error('One or more emails failed to send.');
    }
  } catch (error) {
    console.error('Error querying users or processing data:', error);
    if (!dbMock) {
       process.exit(1);
    }
    throw error;
  }
}

if (require.main === module) {
  checkEmergencyStatus();
}

module.exports = { checkEmergencyStatus };
