import { Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { logger } from '../utils/logger';

/**
 * Helmet configuration for security headers
 */
export const helmetMiddleware = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", 'data:', 'https:'],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
});

/**
 * CORS configuration - strict production settings
 */
export const corsMiddleware = cors({
  origin: (origin, callback) => {
    const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [
      'http://localhost:3000',
      'http://localhost:5060',
    ];

    // Allow requests with no origin (mobile apps, curl, etc.)
    if (!origin) {
      return callback(null, true);
    }

    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      logger.warn(`❌ Blocked CORS request from: ${origin}`);
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  maxAge: 86400, // 24 hours
});

/**
 * Global rate limiter - prevents brute force attacks
 */
export const globalRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Max 100 requests per windowMs
  message: {
    success: false,
    error: 'Too many requests, please try again later',
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn(`⚠️  Rate limit exceeded for IP: ${req.ip}`);
    res.status(429).json({
      success: false,
      error: 'Too many requests, please try again later',
    });
  },
});

/**
 * Stricter rate limiter for sensitive endpoints (auth, uploads)
 */
export const strictRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // Max 20 requests per windowMs
  skipSuccessfulRequests: false,
  message: {
    success: false,
    error: 'Too many attempts, please try again later',
  },
  handler: (req, res) => {
    logger.warn(`⚠️  Strict rate limit exceeded for IP: ${req.ip}`);
    res.status(429).json({
      success: false,
      error: 'Too many attempts, please try again later',
    });
  },
});

/**
 * Validate file mimetype to prevent malicious uploads
 */
export const validateMimetype = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  if (!req.file && !req.files) {
    return next();
  }

  const allowedMimetypes = [
    // Images
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    // Videos
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
    'video/x-matroska',
    // Audio
    'audio/mpeg',
    'audio/wav',
    'audio/flac',
  ];

  const files = req.files
    ? Array.isArray(req.files)
      ? req.files
      : Object.values(req.files).flat()
    : req.file
    ? [req.file]
    : [];

  for (const file of files) {
    if (!allowedMimetypes.includes(file.mimetype)) {
      logger.warn(`❌ Invalid mimetype: ${file.mimetype} from IP: ${req.ip}`);
      return res.status(400).json({
        success: false,
        error: `Invalid file type: ${file.mimetype}`,
      }) as any;
    }
  }

  next();
};

/**
 * Block path traversal attacks
 */
export const sanitizePath = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const params = { ...req.params, ...req.query, ...req.body };

  for (const [key, value] of Object.entries(params)) {
    if (typeof value === 'string' && (value.includes('..') || value.includes('~'))) {
      logger.warn(`⚠️  Path traversal attempt detected: ${key}=${value} from IP: ${req.ip}`);
      return res.status(400).json({
        success: false,
        error: 'Invalid path',
      }) as any;
    }
  }

  next();
};

/**
 * Disable x-powered-by header
 */
export const disablePoweredBy = (
  _req: Request,
  res: Response,
  next: NextFunction
): void => {
  res.removeHeader('X-Powered-By');
  next();
};
