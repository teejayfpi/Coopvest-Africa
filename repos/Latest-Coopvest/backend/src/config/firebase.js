/**
 * Firebase Admin SDK Configuration
 *
 * Initializes the Firebase Admin SDK using a service account JSON stored
 * in the FIREBASE_SERVICE_ACCOUNT_JSON environment variable, or falls back
 * to Application Default Credentials (ADC) when running on Google Cloud.
 */

const admin = require('firebase-admin');
const logger = require('../utils/logger');

let firebaseApp;

const initializeFirebase = () => {
  if (admin.apps.length > 0) {
    return admin.apps[0];
  }

  try {
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

    if (serviceAccountJson) {
      const serviceAccount = JSON.parse(serviceAccountJson);
      firebaseApp = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: serviceAccount.project_id,
      });
      logger.info('✅ Firebase Admin SDK initialized with service account');
    } else {
      // Fall back to ADC (works on Google Cloud / Cloud Run automatically)
      firebaseApp = admin.initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID || 'coopvest-africa-46a86',
      });
      logger.info('✅ Firebase Admin SDK initialized with Application Default Credentials');
    }

    return firebaseApp;
  } catch (err) {
    logger.error('FATAL: Firebase Admin SDK initialization failed:', err.message);
    throw err;
  }
};

const getFirebaseAdmin = () => {
  if (!admin.apps.length) {
    initializeFirebase();
  }
  return admin;
};

module.exports = { initializeFirebase, getFirebaseAdmin };
