/**
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * 📺 ADS CONTROLLER - Start.io Integration
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 */

import { Router } from 'express';
import { getAdsConfig, trackAdImpression, getAdsStats } from '../modules/ads/startio.service';
import { verifyIdToken } from '../middleware/firebase.middleware';

const router = Router();

/**
 * GET /api/ads/config
 * Récupérer la configuration publicitaire pour l'utilisateur
 */
router.get('/config', verifyIdToken, getAdsConfig);

/**
 * POST /api/ads/impression
 * Tracker une impression publicitaire
 */
router.post('/impression', verifyIdToken, trackAdImpression);

/**
 * GET /api/ads/stats
 * Statistiques publicitaires (admin uniquement)
 */
router.get('/stats', verifyIdToken, getAdsStats);

export default router;
