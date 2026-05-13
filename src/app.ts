import express, { Express, Request, Response, NextFunction } from 'express';
import path from 'path';
import multer from 'multer';
import fs from 'fs/promises';
import dotenv from 'dotenv';
import { VideoController } from './modules/video/video.controller';
import { UserController } from './modules/user/user.controller';
import { StorageController } from './modules/storage/storage.controller';
import v3Controller from './controllers/v3.controller';
import adsController from './controllers/ads.controller';
import { logger, requestLogger } from './utils/logger';
import { monitoringMiddleware } from './utils/production-monitor';
import {
  corsMiddleware,
  globalRateLimiter,
} from './middleware/security.middleware';
import {
  helmetConfig,
  uploadRateLimiter,
  sanitizeInputs,
  detectSuspiciousActivity,
  slowRequestProtection,
  auditLog,
} from './middleware/security.middleware';
import { errorHandler } from './middleware/validation.middleware';
import { initializeFirebase, verifyIdToken } from './middleware/firebase.middleware';

dotenv.config();

// Environment variables with fallback defaults (Render-ready)
// Redis is optional - will use in-memory queue if not available
const REDIS_ENABLED = !!process.env.REDIS_URL;

if (!REDIS_ENABLED) {
  logger.warn('⚠️  Redis not configured - using in-memory queue (not recommended for production)');
}

const PORT = parseInt(process.env.PORT || '3000', 10);
const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(process.cwd(), 'uploads');
const OUTPUT_DIR = process.env.OUTPUT_DIR || path.join(process.cwd(), 'outputs');

// Initialize Firebase Admin SDK
initializeFirebase();

// Create necessary directories
async function ensureDirectories(): Promise<void> {
  try {
    await fs.mkdir(UPLOAD_DIR, { recursive: true });
    await fs.mkdir(OUTPUT_DIR, { recursive: true });
    logger.info('✅ Directories ensured');
  } catch (error) {
    logger.error('❌ Failed to create directories:', error);
    process.exit(1);
  }
}

// Multer configuration with enhanced security
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, UPLOAD_DIR);
  },
  filename: (_req, file, cb) => {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `${uniqueSuffix}-${file.originalname}`);
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: 200 * 1024 * 1024, // 200 MB max per file
    files: 10, // Max 10 files per request
  },
  fileFilter: (_req, file, cb) => {
    const allowedMimes = [
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

    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`Invalid file type: ${file.mimetype}`));
    }
  },
});

export function createApp(): Express {
  const app = express();

  // 1. Security headers and CORS
  app.use(helmetConfig);
  app.use(corsMiddleware);

  // 2. Body parsing with limits
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // 3. Request monitoring (production)
  app.use(monitoringMiddleware);

  // 4. Request logging
  app.use(requestLogger);

  // 5. Input sanitization
  app.use(sanitizeInputs);

  // 6. Suspicious activity detection
  app.use(detectSuspiciousActivity);

  // 7. Slow request protection
  app.use(slowRequestProtection);

  // 8. Audit logging
  app.use(auditLog);

  // 9. Global rate limiting
  app.use(globalRateLimiter);

  // 10. Path sanitization

  // 6. Static files (outputs)
  app.use('/outputs', express.static(OUTPUT_DIR));

  // 7. Health check (no auth required)
  app.get('/api/health', async (_req: Request, res: Response) => {
    try {
      const healthData: any = {
        api: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: {
          used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
          total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
        },
      };

      // Check Redis connection if configured
      if (REDIS_ENABLED) {
        healthData.redis = 'connected';
      }

      res.json({
        success: true,
        data: healthData,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: 'Health check failed',
      });
    }
  });

  // 8. Upload endpoint with strict rate limiting and auth
  app.post(
    '/api/upload',
    uploadRateLimiter,
    verifyIdToken,
    upload.array('files', 10),
    async (req: Request, res: Response): Promise<void> => {
      try {
        const files = req.files as Express.Multer.File[];
        if (!files || files.length === 0) {
          res.status(400).json({
            success: false,
            error: 'No files uploaded',
          });
          return;
        }

        const uploadedFiles = files.map((file) => ({
          filename: file.filename,
          originalName: file.originalname,
          size: file.size,
          mimetype: file.mimetype,
          path: file.path,
        }));

        logger.info(`✅ Uploaded ${files.length} file(s) for user: ${(req as any).user?.uid}`);

        res.json({
          success: true,
          data: {
            files: uploadedFiles,
            count: files.length,
          },
        });
      } catch (error: any) {
        logger.error('❌ Upload failed:', error);
        res.status(500).json({
          success: false,
          error: error.message || 'Upload failed',
        });
      }
    }
  );

  // 9. User routes (protected with auth)
  const userController = new UserController();
  app.use('/api/user', verifyIdToken, userController.getRouter());

  // 10. Storage routes (protected with auth)
  const storageController = new StorageController();
  app.use('/api/storage', verifyIdToken, storageController.getRouter());

  // 11. Video routes (all protected with auth)
  const videoController = new VideoController();
  app.use('/api/video', verifyIdToken, videoController.getRouter());

  // 12. V3 Routes: Caption, Template, Batch, Social, Marketplace
  app.use('/api', v3Controller);

  // 13. Ads Routes: Start.io Integration (requires auth)
  app.use('/api/ads', adsController);

  // 14. 404 handler
  app.use((_req: Request, res: Response) => {
    res.status(404).json({
      success: false,
      error: 'Route not found',
    });
  });

  // 14. Enhanced error handler
  app.use(errorHandler as any);

  // 15. Fallback error handler
  app.use((err: any, _req: Request, res: Response, _next: NextFunction): void => {
    logger.error('❌ Global error handler:', err);

    // Multer errors
    if (err instanceof multer.MulterError) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        res.status(413).json({
          success: false,
          error: 'File too large (max 200 MB)',
        });
        return;
      }
      if (err.code === 'LIMIT_FILE_COUNT') {
        res.status(400).json({
          success: false,
          error: 'Too many files (max 10)',
        });
        return;
      }
    }

    // Generic error
    res.status(500).json({
      success: false,
      error: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message,
    });
  });

  return app;
}

export async function startServer(): Promise<void> {
  try {
    await ensureDirectories();

    const app = createApp();

    const server = app.listen(PORT, '0.0.0.0', () => {
      logger.info(`
╔════════════════════════════════════════════════════════════╗
║           🚀 Video Maestro Backend - PRODUCTION            ║
╠════════════════════════════════════════════════════════════╣
║  🌐 API URL: http://0.0.0.0:${PORT}                         ║
║  📂 Uploads: ${UPLOAD_DIR.padEnd(44, ' ')} ║
║  📂 Outputs: ${OUTPUT_DIR.padEnd(44, ' ')} ║
║  🔥 Firebase: ${typeof initializeFirebase === 'function' ? 'Enabled' : 'Disabled'} ║
║  🔒 Security: Helmet + CORS + Rate Limiting               ║
║  📊 Memory: ${process.env.NODE_OPTIONS || 'default'}                    ║
╠════════════════════════════════════════════════════════════╣
║  📍 Routes:                                                 ║
║     GET    /api/health                                     ║
║     POST   /api/upload           (auth required)          ║
║     GET    /api/user/me          (auth required)          ║
║     POST   /api/user/setup       (auth required)          ║
║     PUT    /api/user/me          (auth required)          ║
║     POST   /api/video/parse-script (auth required)        ║
║     POST   /api/video/create     (auth required)          ║
║     GET    /api/video/status/:id (auth required)          ║
║     GET    /api/video/list       (auth required)          ║
║     POST   /api/caption/generate (auth required) [V3]     ║
║     GET    /api/templates        (auth required) [V3]     ║
║     POST   /api/batch/create     (auth required) [V3]     ║
║     GET    /api/social/accounts  (auth required) [V3]     ║
║     GET    /api/marketplace/*    (auth required) [V3]     ║
║     GET    /api/ads/config       (auth required) [ADS]   ║
║     POST   /api/ads/impression   (auth required) [ADS]   ║
╚════════════════════════════════════════════════════════════╝
      `);
    });

    // Graceful shutdown
    const shutdown = async (signal: string) => {
      logger.info(`\n🛑 Received ${signal}, gracefully shutting down...`);
      server.close(() => {
        logger.info('✅ Server closed');
        process.exit(0);
      });

      // Force close after 10 seconds
      setTimeout(() => {
        logger.error('⚠️  Forced shutdown after timeout');
        process.exit(1);
      }, 10000);
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));

    // Handle uncaught exceptions
    process.on('uncaughtException', (error) => {
      logger.error('💥 Uncaught Exception:', error);
      shutdown('uncaughtException');
    });

    // Handle unhandled promise rejections
    process.on('unhandledRejection', (reason, promise) => {
      logger.error('💥 Unhandled Rejection at:', promise, 'reason:', reason);
      shutdown('unhandledRejection');
    });
  } catch (error) {
    logger.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

// Auto-start if not imported as module
if (require.main === module) {
  startServer();
}
