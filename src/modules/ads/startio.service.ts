/**
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * 📺 START.IO ADS INTEGRATION MODULE
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * Gestion des publicités pour les utilisateurs gratuits
 * - Affichage de publicités Start.io
 * - Vérification du statut Premium
 * - Tracking des impressions publicitaires
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 */

import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

/**
 * Interface pour les configurations Start.io
 */
export interface StartIoConfig {
  publisherId: string;
  enabled: boolean;
  adTypes: {
    banner: boolean;
    interstitial: boolean;
    video: boolean;
  };
}

/**
 * Configuration Start.io (depuis variables d'environnement)
 */
const startIoConfig: StartIoConfig = {
  publisherId: process.env.STARTIO_PUBLISHER_ID || '0', // À configurer
  enabled: process.env.STARTIO_ENABLED === 'true',
  adTypes: {
    banner: true,
    interstitial: true,
    video: true,
  },
};

/**
 * Vérifier si l'utilisateur est Premium
 */
export function isPremiumUser(userId: string): boolean {
  // Cette fonction devrait vérifier le statut dans votre base de données
  // Pour l'instant, retourne false par défaut (tous les utilisateurs voient les pubs)
  // À implémenter avec Firebase/MongoDB selon votre architecture
  
  // Exemple d'implémentation:
  // const user = await getUserFromDatabase(userId);
  // return user.subscriptionStatus === 'premium' && user.subscriptionExpiresAt > Date.now();
  
  return false; // Par défaut, tous les utilisateurs sont gratuits
}

/**
 * Middleware pour injecter les informations publicitaires dans la réponse
 */
export async function injectAdsMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    // Récupérer l'ID utilisateur (depuis le token Firebase)
    const userId = (req as any).user?.uid;
    
    if (!userId) {
      // Pas d'utilisateur connecté, continuer sans publicités
      next();
      return;
    }
    
    // Vérifier si l'utilisateur est Premium
    const isPremium = isPremiumUser(userId);
    
    // Ajouter les informations publicitaires à la réponse
    (res.locals as any).adsConfig = {
      showAds: !isPremium && startIoConfig.enabled,
      isPremium,
      startIoPublisherId: startIoConfig.publisherId,
      adTypes: startIoConfig.adTypes,
    };
    
    next();
  } catch (error) {
    logger.error('Ads middleware error:', error);
    next(); // Continuer même en cas d'erreur
  }
}

/**
 * Endpoint pour récupérer la configuration publicitaire
 * GET /api/ads/config
 */
export async function getAdsConfig(req: Request, res: Response): Promise<void> {
  try {
    const userId = (req as any).user?.uid;
    
    if (!userId) {
      res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
      return;
    }
    
    // Vérifier le statut Premium
    const isPremium = isPremiumUser(userId);
    
    // Retourner la configuration
    res.json({
      success: true,
      data: {
        showAds: !isPremium && startIoConfig.enabled,
        isPremium,
        subscriptionPrice: 2000, // 2000 FCFA
        startIo: {
          publisherId: startIoConfig.publisherId,
          enabled: startIoConfig.enabled,
          adTypes: startIoConfig.adTypes,
        },
      },
    });
  } catch (error: any) {
    logger.error('Get ads config error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get ads config',
    });
  }
}

/**
 * Endpoint pour tracker une impression publicitaire
 * POST /api/ads/impression
 */
export async function trackAdImpression(req: Request, res: Response): Promise<void> {
  try {
    const userId = (req as any).user?.uid;
    const { adType, adId } = req.body;
    
    if (!userId) {
      res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
      return;
    }
    
    // Logger l'impression publicitaire
    logger.info('Ad impression tracked', {
      userId,
      adType,
      adId,
      timestamp: new Date().toISOString(),
    });
    
    // Ici, vous pouvez sauvegarder les impressions dans votre base de données
    // pour des statistiques ou des analyses
    
    res.json({
      success: true,
      data: {
        tracked: true,
      },
    });
  } catch (error: any) {
    logger.error('Track ad impression error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to track impression',
    });
  }
}

/**
 * Endpoint pour récupérer les statistiques publicitaires (admin uniquement)
 * GET /api/ads/stats
 */
export async function getAdsStats(req: Request, res: Response): Promise<void> {
  try {
    const userId = (req as any).user?.uid;
    
    // Vérifier les droits admin (à implémenter selon votre architecture)
    // const isAdmin = await checkAdminRights(userId);
    
    // Pour l'instant, retourner des statistiques basiques
    res.json({
      success: true,
      data: {
        totalImpressions: 0,
        freeUsers: 0,
        premiumUsers: 0,
        revenue: 0,
      },
    });
  } catch (error: any) {
    logger.error('Get ads stats error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get ads stats',
    });
  }
}

/**
 * Exporter la configuration Start.io
 */
export function getStartIoConfig(): StartIoConfig {
  return startIoConfig;
}
