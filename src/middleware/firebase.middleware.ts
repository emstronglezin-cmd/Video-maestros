import { Request, Response, NextFunction } from 'express';
import admin from 'firebase-admin';
import { logger } from '../utils/logger';

// Initialize Firebase Admin SDK
let firebaseInitialized = false;

export const initializeFirebase = (): void => {
  if (firebaseInitialized) {
    return;
  }

  try {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

    if (!projectId || !clientEmail || !privateKey) {
      logger.warn('⚠️  Firebase credentials missing - Auth middleware will be disabled');
      return;
    }

    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey,
      }),
    });

    firebaseInitialized = true;
    logger.info('✅ Firebase Admin SDK initialized');
  } catch (error) {
    logger.error('❌ Failed to initialize Firebase Admin SDK:', error);
  }
};

// Extended Request interface with Firebase user
export interface AuthenticatedRequest extends Request {
  user?: {
    uid: string;
    email?: string;
    isPremium: boolean;
  };
}

/**
 * Middleware to verify Firebase ID token
 * Extracts user info and premium status from custom claims
 */
export const verifyIdToken = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    // Check if Firebase is initialized
    if (!firebaseInitialized) {
      logger.warn('⚠️  Firebase not initialized - skipping auth');
      return next();
    }

    // Extract token from Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      logger.warn('❌ Missing or invalid Authorization header');
      res.status(401).json({
        success: false,
        error: 'Unauthorized - Missing authentication token',
      });
      return;
    }

    const idToken = authHeader.split('Bearer ')[1];

    // Verify the token
    const decodedToken = await admin.auth().verifyIdToken(idToken);

    // Extract user info and premium status from custom claims
    const isPremium = decodedToken.premium === true || false;

    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      isPremium,
    };

    logger.debug(`✅ Authenticated user: ${decodedToken.uid} (premium: ${isPremium})`);
    next();
  } catch (error: any) {
    logger.error('❌ Token verification failed:', error.message);
    res.status(401).json({
      success: false,
      error: 'Unauthorized - Invalid or expired token',
    });
  }
};

/**
 * Optional middleware - allows requests without auth
 * If token is present, it will be verified
 */
export const optionalAuth = async (
  req: AuthenticatedRequest,
  _res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!firebaseInitialized) {
      return next();
    }

    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }

    const idToken = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const isPremium = decodedToken.premium === true || false;

    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      isPremium,
    };

    next();
  } catch (error) {
    // If token is invalid, just continue without auth
    next();
  }
};
