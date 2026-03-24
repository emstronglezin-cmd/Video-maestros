import { Router, Response } from 'express';
import { getStorage } from 'firebase-admin/storage';
import { logger } from '../../utils/logger';
import { AuthenticatedRequest } from '../../middleware/firebase.middleware';
import { v4 as uuidv4 } from 'uuid';

/**
 * Contrôleur pour la gestion du stockage Firebase
 */
export class StorageController {
  private router: Router;
  private storage = getStorage();

  constructor() {
    this.router = Router();
    this.setupRoutes();
  }

  private setupRoutes(): void {
    // POST /signed-url - Génère une URL signée pour l'upload
    this.router.post('/signed-url', this.getSignedUploadUrl.bind(this));

    // POST /signed-download-url - Génère une URL signée pour le téléchargement
    this.router.post('/signed-download-url', this.getSignedDownloadUrl.bind(this));
  }

  /**
   * POST /signed-url
   * Génère une URL signée pour permettre l'upload direct vers Firebase Storage
   */
  private async getSignedUploadUrl(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const user = req.user;
      if (!user || !user.uid) {
        res.status(401).json({
          success: false,
          error: 'Unauthorized',
        });
        return;
      }

      const { fileName, contentType } = req.body;

      if (!fileName || !contentType) {
        res.status(400).json({
          success: false,
          error: 'fileName and contentType are required',
        });
        return;
      }

      // Valider le contentType
      const allowedTypes = [
        'image/jpeg',
        'image/jpg',
        'image/png',
        'image/gif',
        'video/mp4',
        'video/quicktime',
        'video/x-msvideo',
        'video/x-matroska',
        'audio/mpeg',
        'audio/wav',
        'audio/flac',
      ];

      if (!allowedTypes.includes(contentType)) {
        res.status(400).json({
          success: false,
          error: `Invalid content type: ${contentType}`,
        });
        return;
      }

      // Générer un nom de fichier unique
      const fileId = uuidv4();
      const extension = fileName.split('.').pop();
      const storagePath = `users/${user.uid}/uploads/${fileId}.${extension}`;

      // Obtenir le bucket par défaut
      const bucket = this.storage.bucket();
      const file = bucket.file(storagePath);

      // Générer une URL signée pour l'upload (valide 15 minutes)
      const [signedUrl] = await file.getSignedUrl({
        version: 'v4',
        action: 'write',
        expires: Date.now() + 15 * 60 * 1000, // 15 minutes
        contentType,
      });

      logger.info(`✅ Generated signed upload URL for user: ${user.uid}, file: ${storagePath}`);

      res.json({
        success: true,
        data: {
          signedUrl,
          storagePath,
          fileId,
          expiresIn: 15 * 60, // secondes
        },
      });
    } catch (error: any) {
      logger.error('❌ Failed to generate signed upload URL:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Failed to generate signed URL',
      });
    }
  }

  /**
   * POST /signed-download-url
   * Génère une URL signée pour le téléchargement
   */
  private async getSignedDownloadUrl(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const user = req.user;
      if (!user || !user.uid) {
        res.status(401).json({
          success: false,
          error: 'Unauthorized',
        });
        return;
      }

      const { storagePath } = req.body;

      if (!storagePath) {
        res.status(400).json({
          success: false,
          error: 'storagePath is required',
        });
        return;
      }

      // Vérifier que le fichier appartient à l'utilisateur
      if (!storagePath.startsWith(`users/${user.uid}/`)) {
        res.status(403).json({
          success: false,
          error: 'Access denied',
        });
        return;
      }

      const bucket = this.storage.bucket();
      const file = bucket.file(storagePath);

      // Vérifier que le fichier existe
      const [exists] = await file.exists();
      if (!exists) {
        res.status(404).json({
          success: false,
          error: 'File not found',
        });
        return;
      }

      // Générer une URL signée pour le téléchargement (valide 1 heure)
      const [signedUrl] = await file.getSignedUrl({
        version: 'v4',
        action: 'read',
        expires: Date.now() + 60 * 60 * 1000, // 1 heure
      });

      logger.info(`✅ Generated signed download URL for user: ${user.uid}, file: ${storagePath}`);

      res.json({
        success: true,
        data: {
          signedUrl,
          expiresIn: 60 * 60, // secondes
        },
      });
    } catch (error: any) {
      logger.error('❌ Failed to generate signed download URL:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Failed to generate signed URL',
      });
    }
  }

  public getRouter(): Router {
    return this.router;
  }
}
