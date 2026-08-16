const admin = require('firebase-admin');

async function checkDocumentExpiry(dbMock = null, fetchMock = null) {
  console.log('Starting Document Expiry Check...');

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

  const EMAILJS_SERVICE_ID = process.env.EMAILJS_SERVICE_ID_CRYPTAF || process.env.EMAILJS_SERVICE_ID || 'mock_service_id';
  const EMAILJS_TEMPLATE_ID = process.env.EMAILJS_TEMPLATE_ID_DOCUMENT_EXPIRY || 'mock_template_id';
  const EMAILJS_USER_ID = process.env.EMAILJS_USER_ID_DOCUMENT_EXPIRY || process.env.EMAILJS_USER_ID || 'mock_user_id';
  const EMAILJS_PRIVATE_KEY = process.env.EMAILJS_PRIVATE_KEY || 'mock_private_key';

  if (!process.env.EMAILJS_SERVICE_ID_CRYPTAF && !fetchMock) {
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

    const today = new Date();
    today.setHours(0, 0, 0, 0); // Normalize to start of day for accurate day calculation
    
    console.log(`Checking ${snapshot.size} total users for document expiry...`);

    for (const doc of snapshot.docs) {
      const userData = doc.data();
      const userEmail = userData.email;
      
      if (!userEmail) {
        continue;
      }

      const expiryDocsRef = doc.ref.collection('expiry_docs');
      const docsSnapshot = await expiryDocsRef.get();

      if (docsSnapshot.empty) {
        continue;
      }

      for (const expiryDoc of docsSnapshot.docs) {
        const data = expiryDoc.data();
        const alertSent = data.alertSent || false;
        const ts = data.expiryDate;
        
        if (!ts) continue;
        
        let date;
        if (ts.toDate) {
           date = ts.toDate();
        } else {
           date = new Date(ts.seconds * 1000);
        }
        
        const expDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        
        // Calculate days remaining
        const diffTime = expDate.getTime() - today.getTime();
        const daysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        
        console.log(`User ${doc.id} - Document "${data.title}" (${data.type}) | daysRemaining: ${daysRemaining} | alertSent: ${alertSent}`);

        // Condition: <= 30 days, > 0 days, not yet sent
        if (daysRemaining <= 0) {
          console.log(`  -> Skip: already expired`);
        } else if (daysRemaining > 30) {
          console.log(`  -> Skip: not within 30-day window yet`);
        } else if (alertSent) {
          console.log(`  -> Skip: already alerted`);
        } else {
          console.log(`  -> Action: Sending alert...`);
          
          if (EMAILJS_SERVICE_ID) {
            const formattedDate = expDate.toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' });
            const docTypeStr = data.type ? `${data.type} document` : 'document';
            const message = `Your ${docTypeStr} "${data.title}" is expiring in ${daysRemaining} days on ${formattedDate}. Please review your vault.`;
            
            const payload = {
              service_id: EMAILJS_SERVICE_ID,
              template_id: EMAILJS_TEMPLATE_ID,
              user_id: EMAILJS_USER_ID,
              accessToken: EMAILJS_PRIVATE_KEY,
              template_params: {
                to_email: userEmail,
                subject: 'Action Required: Document Expiring Soon',
                message: message
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
                console.log(`Successfully sent document expiry email to ${userEmail}.`);
                await expiryDoc.ref.update({ alertSent: true });
                console.log(`Marked alertSent=true for document ${expiryDoc.id}.`);
              } else {
                let text = '';
                if (response.text) text = await response.text();
                console.error(`Failed to send email to ${userEmail}: ${response.status} - ${text}`);
                hasErrors = true;
              }
            } catch (emailErr) {
              console.error(`Exception sending email to ${userEmail}:`, emailErr);
              hasErrors = true;
            }
          }
        }
      }
    }
    console.log('Document Expiry Check complete.');
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
  checkDocumentExpiry();
}

module.exports = { checkDocumentExpiry };
