import { z } from 'zod';
import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

/**
 * Schémas de validation Zod pour sécurité maximale
 */

// Caption validation
export const captionGenerateSchema = z.object({
  videoPath: z.string().min(1).max(500).regex(/^[a-zA-Z0-9_\-/.]+$/),
  language: z.enum(['fr', 'en', 'auto']).default('auto'),
  model: z.enum(['tiny', 'base', 'small', 'medium', 'large']).default('base'),
});

export const captionApplySchema = z.object({
  inputVideoPath: z.string().min(1).max(500),
  srtPath: z.string().min(1).max(500),
  outputVideoPath: z.string().min(1).max(500),
  style: z.object({
    fontName: z.string().min(1).max(100),
    fontSize: z.number().int().min(12).max(200),
    primaryColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
    outlineColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
    outlineWidth: z.number().int().min(1).max(10),
    position: z.enum(['top', 'center', 'bottom']),
    alignment: z.enum(['left', 'center', 'right']),
    animation: z.enum(['none', 'fade', 'karaoke']),
    animationDuration: z.number().int().min(0).max(5000),
  }),
});

// Template validation
export const templateIdSchema = z.object({
  id: z.string().min(1).max(100).regex(/^[a-z0-9\-]+$/),
});

// Batch validation
export const batchCreateSchema = z.object({
  // No body params for create
});

export const batchAddJobsSchema = z.object({
  sessionId: z.string().uuid(),
  videoConfigs: z.array(z.object({
    templateId: z.string().optional(),
    duration: z.number().min(1).max(300),
    resolution: z.enum(['720p', '1080p', '4K']).default('1080p'),
  })).min(1).max(10),
});

// Social export validation
export const socialConnectSchema = z.object({
  authCode: z.string().min(10).max(1000),
  redirectUri: z.string().url().optional(),
});

export const socialPostSchema = z.object({
  videoPath: z.string().min(1).max(500),
  thumbnailPath: z.string().min(1).max(500).optional(),
  config: z.object({
    title: z.string().min(1).max(150),
    description: z.string().max(2000),
    hashtags: z.array(z.string().max(50)).max(30),
    privacy: z.enum(['public', 'friends', 'private']),
    allowComments: z.boolean(),
    allowDuet: z.boolean().optional(),
    allowStitch: z.boolean().optional(),
    disableAds: z.boolean().optional(),
  }),
});

// Marketplace validation
export const marketplaceEffectIdSchema = z.object({
  effectId: z.string().min(1).max(100).regex(/^[a-z0-9\-]+$/),
});

export const marketplacePackIdSchema = z.object({
  packId: z.string().min(1).max(100).regex(/^[a-z0-9\-]+$/),
});

export const marketplaceFiltersSchema = z.object({
  type: z.enum(['transition', 'overlay', 'sound', 'filter', 'sticker']).optional(),
  category: z.enum(['viral', 'cinematic', 'corporate', 'fun', 'music', 'nature', 'retro']).optional(),
  isPremium: z.enum(['true', 'false']).optional(),
});

/**
 * Middleware de validation générique
 */
export function validateRequest(schema: z.ZodSchema) {
  return async (req: Request, res: Response,   next: NextFunction): Promise<void> => {
    try {
      // Valider body, query et params
      const validated = await schema.parseAsync({
        ...req.body,
        ...req.query,
        ...req.params,
      });

      // Remplacer req.body avec données validées
      req.body = validated;
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        logger.warn('Validation failed', {
          path: req.path,
          errors: error.errors,
          body: req.body,
        });

        res.status(400).json({
          success: false,
          error: 'Validation failed',
          details: error.errors.map(err => ({
            field: err.path.join('.'),
            message: err.message,
            code: err.code,
          })),
        });
        return;
      }

      logger.error('Validation middleware error', { error });
      res.status(500).json({
        success: false,
        error: 'Internal validation error',
      });
    }
  };
}

/**
 * Sanitization helpers
 */
export function sanitizeFilePath(path: string): string {
  // Remove dangerous characters
  return path.replace(/[^a-zA-Z0-9_\-./]/g, '');
}

export function sanitizeHtml(text: string): string {
  return text
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g, '&#x2F;');
}

/**
 * Rate limiting par utilisateur
 */
export const userRateLimitMap = new Map<string, { count: number; resetAt: number }>();

export function checkUserRateLimit(userId: string, maxRequests: number, windowMs: number): boolean {
  const now = Date.now();
  const userLimit = userRateLimitMap.get(userId);

  if (!userLimit || userLimit.resetAt < now) {
    // Reset window
    userRateLimitMap.set(userId, {
      count: 1,
      resetAt: now + windowMs,
    });
    return true;
  }

  if (userLimit.count >= maxRequests) {
    return false;
  }

  userLimit.count++;
  return true;
}

export function userRateLimiter(maxRequests: number, windowMs: number) {
  return (req: Request, res: Response,   next: NextFunction): void => {
    const userId = (req as any).user?.uid;

    if (!userId) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    if (!checkUserRateLimit(userId, maxRequests, windowMs)) {
      logger.warn('User rate limit exceeded', { userId, path: req.path });
      res.status(429).json({
        success: false,
        error: 'Too many requests',
        message: `Maximum ${maxRequests} requests per ${windowMs / 1000} seconds`,
      });
      return;
    }

    next();
  };
}

/**
 * Error boundary middleware
 */
export class AppError extends Error {
  constructor(
    public statusCode: number,
    public message: string,
    public isOperational: boolean = true
  ) {
    super(message);
    Error.captureStackTrace(this, this.constructor);
  }
}

export function errorHandler(
  err: Error | AppError,
  req: Request,
  res: Response,
    _next: NextFunction
): void {
  if (err instanceof AppError) {
    logger.error('Operational error', {
      statusCode: err.statusCode,
      message: err.message,
      path: req.path,
      method: req.method,
    });

    res.status(err.statusCode).json({
      success: false,
      error: err.message,
    });
    return;
  }

  // Erreur non-opérationnelle (bug)
  logger.error('Non-operational error', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  res.status(500).json({
    success: false,
    error: process.env.NODE_ENV === 'production' 
      ? 'Internal server error' 
      : err.message,
  });
}

/**
 * Async handler pour éviter try-catch répétitifs
 */
export function asyncHandler(fn: Function) {
  return (req: Request, res: Response,   next: NextFunction): void => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

/**
 * Validation environnement au démarrage
 */
export function validateEnvironment(): void {
  const required = [
    'PORT',
    'UPLOAD_DIR',
    'OUTPUT_DIR',
  ];

  const missing = required.filter(key => !process.env[key]);

  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  // Warn about optional but recommended vars
  const recommended = [
    'REDIS_HOST',
    'OLLAMA_URL',
    'FIREBASE_PROJECT_ID',
  ];

  const missingRecommended = recommended.filter(key => !process.env[key]);
  if (missingRecommended.length > 0) {
    logger.warn('Missing recommended environment variables', {
      variables: missingRecommended,
    });
  }

  logger.info('✅ Environment validation passed');
}
