import rateLimit from 'express-rate-limit';
import { Request, Response } from 'express';

/**
 * Rate limiter global pour toutes les routes
 */
export const globalRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // 100 requêtes par IP
  message: 'Trop de requêtes depuis cette IP, veuillez réessayer plus tard',
  standardHeaders: true,
  legacyHeaders: false,
  handler: (_req: Request, res: Response) => {
    res.status(429).json({
      success: false,
      error: 'Trop de requêtes. Limite: 100 requêtes par 15 minutes'
    });
  }
});

/**
 * Rate limiter strict pour l'upload
 */
export const uploadRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 heure
  max: 20, // 20 uploads par heure
  message: 'Limite d\'upload atteinte',
  skipSuccessfulRequests: false
});

/**
 * Rate limiter pour la création de vidéos
 */
export const videoCreationRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 heure
  max: 10, // 10 créations par heure
  message: 'Limite de création de vidéos atteinte'
});

/**
 * Rate limiter pour les endpoints de parsing
 */
export const parsingRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 30, // 30 requêtes par minute
  message: 'Trop de requêtes de parsing'
});
