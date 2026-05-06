/**
 * Controllers V3 - Gestion des nouvelles routes
 * Caption, Template, Batch, Social Export, Marketplace
 */

import { Router, Request, Response } from 'express';
import { verifyIdToken } from '../middleware/firebase.middleware';
import { 
  validateRequest, 
  asyncHandler, 
  userRateLimiter,
  captionGenerateSchema,
} from '../middleware/validation.middleware';
import { captionService } from '../services/caption.service';
import { templateService } from '../services/template.service';
import { batchService } from '../services/batch.service';
import { socialExportService } from '../services/socialExport.service';
import { marketplaceService } from '../services/marketplace.service';
import { logger } from '../utils/logger';

const router = Router();

// =======================
// CAPTION ROUTES
// =======================

/**
 * POST /api/caption/generate
 * Génère des sous-titres automatiques avec Whisper
 */
router.post(
  '/caption/generate',
  verifyIdToken,
  userRateLimiter(10, 60000),
  validateRequest(captionGenerateSchema),
  asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { videoPath, language, model } = req.body;
    const result = await captionService.generateCaptions(videoPath, language, model);

    res.json({
      success: true,
      data: result
    });
  })
);

/**
 * POST /api/caption/apply
 * Applique des sous-titres stylisés sur une vidéo
 */
router.post('/caption/apply', verifyIdToken, async (req: Request, res: Response): Promise<void> => {
  try {
    const { inputVideoPath, srtPath, outputVideoPath, style } = req.body;

    if (!inputVideoPath || !srtPath || !outputVideoPath) {
      res.status(400).json({ error: 'Missing required parameters' });
      return;
    }

    await captionService.applyStylizedCaptions(inputVideoPath, srtPath, outputVideoPath, style);

    res.json({
      success: true,
      outputPath: outputVideoPath
    });

  } catch (error) {
    logger.error('Caption application failed', { error });
    res.status(500).json({ 
      error: 'Caption application failed',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// =======================
// TEMPLATE ROUTES
// =======================

/**
 * GET /api/templates
 * Récupère tous les templates disponibles
 */
router.get('/templates', verifyIdToken, async (req: Request, res: Response): Promise<void> => {
  try {
    const userIsPremium = (req as any).user?.isPremium || false;
    const { platform, trending } = req.query;

    let templates;

    if (trending === 'true') {
      templates = templateService.getTrendingTemplates(userIsPremium);
    } else if (platform) {
      templates = templateService.getTemplatesByPlatform(platform as any, userIsPremium);
    } else {
      templates = templateService.getAllTemplates(userIsPremium);
    }

    res.json({
      success: true,
      data: templates,
      count: templates.length
    });

  } catch (error) {
    logger.error('Failed to get templates', { error });
    res.status(500).json({ error: 'Failed to retrieve templates' });
  }
});

/**
 * GET /api/templates/:id
 * Récupère un template par ID
 */
router.get('/templates/:id', verifyIdToken, async (req: Request, res: Response): Promise<void> => {
  try {
    const userIsPremium = (req as any).user?.isPremium || false;
    const template = templateService.getTemplateById(req.params.id, userIsPremium);

    if (!template) {
      res.status(404).json({ error: 'Template not found' });
      return;
    }

    res.json({
      success: true,
      data: template
    });

  } catch (error) {
    logger.error('Failed to get template', { error });
    res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
  }
});

/**
 * GET /api/templates/stats
 * Statistiques des templates
 */
router.get('/templates/stats', async (_req: Request, res: Response): Promise<void> => {
  try {
    const stats = templateService.getTemplateStats();
    res.json({ success: true, data: stats });
  } catch (error) {
    res.status(500).json({ error: 'Failed to get template stats' });
  }
});

// =======================
// BATCH ROUTES
// =======================

/**
 * POST /api/batch/create
 * Crée une nouvelle session batch
 */
router.post('/batch/create', verifyIdToken, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.uid;
    const sessionId = batchService.createBatchSession(userId);

    res.json({
      success: true,
      sessionId
    });

  } catch (error) {
    logger.error('Failed to create batch session', { error });
    res.status(500).json({ error: 'Failed to create batch session' });
  }
});

/**
 * POST /api/batch/:sessionId/add-jobs
 * Ajoute des jobs à une session batch
 */
router.post('/batch/:sessionId/add-jobs', verifyIdToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.uid;
    const isPremium = (req as any).user.isPremium || false;
    const { sessionId } = req.params;
    const { videoConfigs } = req.body;

    if (!videoConfigs || !Array.isArray(videoConfigs)) {
      res.status(400).json({ error: 'videoConfigs array is required' });
      return;
    }

    const jobIds = await batchService.addJobsToSession(sessionId, userId, isPremium, videoConfigs);

    res.json({
      success: true,
      jobIds,
      count: jobIds.length
    });

  } catch (error) {
    logger.error('Failed to add jobs to batch', { error });
    res.status(500).json({ 
      error: error instanceof Error ? error.message : 'Failed to add jobs' 
    });
  }
});

/**
 * GET /api/batch/:sessionId/status
 * Récupère l'état d'une session batch
 */
router.get('/batch/:sessionId/status', verifyIdToken, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.uid;
    const { sessionId } = req.params;

    const status = await batchService.getBatchSessionStatus(sessionId, userId);

    if (!status) {
      res.status(404).json({ error: 'Batch session not found' });
      return;
    }

    res.json({
      success: true,
      data: status
    });

  } catch (error) {
    logger.error('Failed to get batch status', { error });
    res.status(500).json({ error: 'Failed to retrieve batch status' });
  }
});

/**
 * POST /api/batch/:sessionId/cancel
 * Annule une session batch
 */
router.post('/batch/:sessionId/cancel', verifyIdToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.uid;
    const { sessionId } = req.params;

    const cancelledCount = await batchService.cancelBatchSession(sessionId, userId);

    res.json({
      success: true,
      cancelledCount
    });

  } catch (error) {
    logger.error('Failed to cancel batch', { error });
    res.status(500).json({ 
      error: error instanceof Error ? error.message : 'Failed to cancel batch' 
    });
  }
});

/**
 * GET /api/batch/queue-stats
 * Statistiques de la queue batch
 */
router.get('/batch/queue-stats', verifyIdToken, async (req: Request, res: Response): Promise<void> => {
  try {
    const stats = await batchService.getQueueStats();
    res.json({ success: true, data: stats });
  } catch (error) {
    res.status(500).json({ error: 'Failed to get queue stats' });
  }
});

// =======================
// SOCIAL EXPORT ROUTES
// =======================

/**
 * POST /api/social/connect/tiktok
 * Connecte un compte TikTok
 */
router.post('/social/connect/tiktok', verifyIdToken, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.uid;
    const { authCode } = req.body;

    if (!authCode) {
      res.status(400).json({ error: 'authCode is required' });
      return;
    }

    const account = await socialExportService.connectTikTokAccount(userId, authCode);

    res.json({
      success: true,
      data: {
        platform: account.platform,
        username: account.platformUsername,
        connected: true
      }
    });

  } catch (error) {
    logger.error('Failed to connect TikTok', { error });
    res.status(500).json({ 
      error: error instanceof Error ? error.message : 'Failed to connect TikTok' 
    });
  }
});

/**
 * POST /api/social/connect/instagram
 * Connecte un compte Instagram
 */
router.post('/social/connect/instagram', verifyIdToken, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.uid;
    const { authCode, redirectUri } = req.body;

    if (!authCode || !redirectUri) {
      res.status(400).json({ error: 'authCode and redirectUri are required' });
      return;
    }

    const account = await socialExportService.connectInstagramAccount(userId, authCode, redirectUri);

    res.json({
      success: true,
      data: {
        platform: account.platform,
        username: account.platformUsername,
        connected: true
      }
    });

  } catch (error) {
    logger.error('Failed to connect Instagram', { error });
    res.status(500).json({ 
      error: error instanceof Error ? error.message : 'Failed to connect Instagram' 
    });
  }
});

/**
 * POST /api/social/post/tiktok
 * Publie une vidéo sur TikTok
 */
router.post('/social/post/tiktok', verifyIdToken, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.uid;
    const { videoPath, config } = req.body;

    if (!videoPath || !config) {
      res.status(400).json({ error: 'videoPath and config are required' });
      return;
    }

    const result = await socialExportService.postToTikTok(userId, videoPath, config);

    if (!result.success) {
      res.status(400).json({ error: result.error });
      return;
    }

    res.json({
      success: true,
      data: result
    });

  } catch (error) {
    logger.error('Failed to post to TikTok', { error });
    res.status(500).json({ error: 'Failed to post to TikTok' });
  }
});

/**
 * POST /api/social/post/instagram
 * Publie un Reel sur Instagram
 */
router.post('/social/post/instagram', verifyIdToken, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.uid;
    const { videoPath, thumbnailPath, config } = req.body;

    if (!videoPath || !config) {
      res.status(400).json({ error: 'videoPath and config are required' });
      return;
    }

    const result = await socialExportService.postToInstagram(userId, videoPath, thumbnailPath, config);

    if (!result.success) {
      res.status(400).json({ error: result.error });
      return;
    }

    res.json({
      success: true,
      data: result
    });

  } catch (error) {
    logger.error('Failed to post to Instagram', { error });
    res.status(500).json({ error: 'Failed to post to Instagram' });
  }
});

/**
 * GET /api/social/accounts
 * Récupère les comptes sociaux connectés
 */
router.get('/social/accounts', verifyIdToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.uid;
    const accounts = socialExportService.getConnectedAccounts(userId);

    res.json({
      success: true,
      data: accounts.map(acc => ({
        platform: acc.platform,
        username: acc.platformUsername,
        connected: acc.isActive
      }))
    });

  } catch (error) {
    logger.error('Failed to get social accounts', { error });
    res.status(500).json({ error: 'Failed to retrieve social accounts' });
  }
});

/**
 * DELETE /api/social/disconnect/:platform
 * Déconnecte un compte social
 */
router.delete('/social/disconnect/:platform', verifyIdToken, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = (req as any).user.uid;
    const platform = req.params.platform as 'tiktok' | 'instagram';

    if (!['tiktok', 'instagram'].includes(platform)) {
      res.status(400).json({ error: 'Invalid platform' });
      return;
    }

    const success = socialExportService.disconnectAccount(userId, platform);

    res.json({ success });

  } catch (error) {
    logger.error('Failed to disconnect social account', { error });
    res.status(500).json({ error: 'Failed to disconnect account' });
  }
});

// =======================
// MARKETPLACE ROUTES
// =======================

/**
 * GET /api/marketplace/effects
 * Récupère tous les effets du marketplace
 */
router.get('/marketplace/effects', verifyIdToken, async (req: Request, res: Response) => {
  try {
    const userIsPremium = (req as any).user?.isPremium || false;
    const { type, category, isPremium } = req.query;

    const effects = marketplaceService.getAllEffects(
      type as any,
      category as any,
      isPremium === 'true' ? true : isPremium === 'false' ? false : undefined,
      userIsPremium
    );

    res.json({
      success: true,
      data: effects,
      count: effects.length
    });

  } catch (error) {
    logger.error('Failed to get effects', { error });
    res.status(500).json({ error: 'Failed to retrieve effects' });
  }
});

/**
 * GET /api/marketplace/packs
 * Récupère tous les packs du marketplace
 */
router.get('/marketplace/packs', verifyIdToken, async (req: Request, res: Response) => {
  try {
    const userIsPremium = (req as any).user?.isPremium || false;
    const packs = marketplaceService.getAllPacks(userIsPremium);

    res.json({
      success: true,
      data: packs,
      count: packs.length
    });

  } catch (error) {
    logger.error('Failed to get packs', { error });
    res.status(500).json({ error: 'Failed to retrieve packs' });
  }
});

/**
 * POST /api/marketplace/purchase/effect/:effectId
 * Achète un effet
 */
router.post('/marketplace/purchase/effect/:effectId', verifyIdToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.uid;
    const { effectId } = req.params;

    const purchase = await marketplaceService.purchaseEffect(userId, effectId);

    res.json({
      success: true,
      data: purchase
    });

  } catch (error) {
    logger.error('Failed to purchase effect', { error });
    res.status(400).json({ 
      error: error instanceof Error ? error.message : 'Purchase failed' 
    });
  }
});

/**
 * POST /api/marketplace/purchase/pack/:packId
 * Achète un pack
 */
router.post('/marketplace/purchase/pack/:packId', verifyIdToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.uid;
    const { packId } = req.params;

    const purchase = await marketplaceService.purchasePack(userId, packId);

    res.json({
      success: true,
      data: purchase
    });

  } catch (error) {
    logger.error('Failed to purchase pack', { error });
    res.status(400).json({ 
      error: error instanceof Error ? error.message : 'Purchase failed' 
    });
  }
});

/**
 * GET /api/marketplace/library
 * Récupère la bibliothèque de l'utilisateur
 */
router.get('/marketplace/library', verifyIdToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.uid;
    const library = marketplaceService.getUserLibrary(userId);

    res.json({
      success: true,
      data: {
        ownedEffects: Array.from(library.ownedEffects),
        ownedPacks: Array.from(library.ownedPacks),
        purchases: library.purchases
      }
    });

  } catch (error) {
    logger.error('Failed to get user library', { error });
    res.status(500).json({ error: 'Failed to retrieve library' });
  }
});

/**
 * GET /api/marketplace/download/:effectId
 * Télécharge un effet
 */
router.get('/marketplace/download/:effectId', verifyIdToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user.uid;
    const { effectId } = req.params;

    const filePath = await marketplaceService.downloadEffect(userId, effectId);

    res.download(filePath);

  } catch (error) {
    logger.error('Failed to download effect', { error });
    res.status(400).json({ 
      error: error instanceof Error ? error.message : 'Download failed' 
    });
  }
});

/**
 * GET /api/marketplace/stats
 * Statistiques du marketplace
 */
router.get('/marketplace/stats', async (_req: Request, res: Response) => {
  try {
    const stats = marketplaceService.getMarketplaceStats();
    res.json({ success: true, data: stats });
  } catch (error) {
    res.status(500).json({ error: 'Failed to get marketplace stats' });
  }
});

export default router;
