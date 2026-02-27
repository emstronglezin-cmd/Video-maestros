import { Request, Response, NextFunction } from 'express';
import admin from 'firebase-admin';
import { logger } from '../utils/logger';

/**
 * Interface utilisateur étendue
 */
export interface AuthenticatedRequest extends Request {
  user?: {
    uid: string;
    email?: string;
    isPremium: boolean;
  };
}

/**
 * Initialise Firebase Admin SDK
 */
export function initializeFirebase(): void {
  try {
    // Vérifie si Firebase est déjà initialisé
    if (admin.apps.length > 0) {
      logger.info('Firebase Admin SDK déjà initialisé');
      return;
    }

    // Initialise avec les credentials depuis les variables d'environnement
    const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
    
    if (!serviceAccount) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT manquant dans .env');
    }

    const credentials = JSON.parse(serviceAccount);

    admin.initializeApp({
      credential: admin.credential.cert(credentials),
      projectId: process.env.FIREBASE_PROJECT_ID
    });

    logger.info('✅ Firebase Admin SDK initialisé avec succès');
  } catch (error) {
    logger.error('❌ Erreur initialisation Firebase:', error);
    throw error;
  }
}

/**
 * Middleware d'authentification Firebase
 * Vérifie le token ID Firebase et enrichit la requête avec les infos utilisateur
 */
export async function verifyFirebaseToken(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    // Récupère le token depuis le header Authorization
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        error: 'Token d\'authentification manquant'
      });
      return;
    }

    const idToken = authHeader.split('Bearer ')[1];

    // Vérifie le token avec Firebase Admin
    const decodedToken = await admin.auth().verifyIdToken(idToken);

    // Récupère les custom claims pour vérifier le rôle premium
    const userRecord = await admin.auth().getUser(decodedToken.uid);
    const customClaims = userRecord.customClaims || {};

    // Enrichit la requête avec les infos utilisateur
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      isPremium: customClaims.premium === true
    };

    logger.info(`✅ Utilisateur authentifié: ${req.user.uid} (Premium: ${req.user.isPremium})`);
    next();
  } catch (error) {
    logger.error('❌ Erreur vérification token Firebase:', error);
    res.status(401).json({
      success: false,
      error: 'Token d\'authentification invalide'
    });
  }
}

/**
 * Middleware optionnel - permet requêtes non authentifiées
 */
export async function optionalFirebaseToken(
  req: AuthenticatedRequest,
  _res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      const idToken = authHeader.split('Bearer ')[1];
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      const userRecord = await admin.auth().getUser(decodedToken.uid);
      const customClaims = userRecord.customClaims || {};

      req.user = {
        uid: decodedToken.uid,
        email: decodedToken.email,
        isPremium: customClaims.premium === true
      };
    }

    next();
  } catch (error) {
    // En cas d'erreur, on continue sans utilisateur
    next();
  }
}
