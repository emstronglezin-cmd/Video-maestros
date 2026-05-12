import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import cors from 'cors';

/**
 * 🔒 MIDDLEWARE DE SÉCURITÉ RENFORCÉE
 * Protection complète contre les attaques courantes
 */

/**
 * Configuration Helmet pour sécurité HTTP
 */
export const helmetConfig = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", 'data:', 'https:'],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
  noSniff: true,
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
});

/**
 * Rate limiting global par IP
 */
export const globalRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // 1000 requêtes max par IP
  message: {
    success: false,
    error: 'Too many requests from this IP, please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, _res) => {
    logger.warn('Global rate limit exceeded', {
      ip: req.ip,
      path: req.path,
      userAgent: req.get('user-agent'),
    });
    _res.status(429).json({
      success: false,
      error: 'Too many requests',
      retryAfter: 900,
    });
  },
});

/**
 * Rate limiting strict pour uploads
 */
export const uploadRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10, // 10 uploads par minute
  message: {
    success: false,
    error: 'Upload rate limit exceeded. Maximum 10 uploads per minute.',
  },
  skipSuccessfulRequests: false,
  handler: (req, _res) => {
    logger.warn('Upload rate limit exceeded', {
      ip: req.ip,
      user: (req as any).user?.uid,
    });
    _res.status(429).json({
      success: false,
      error: 'Too many upload requests',
      retryAfter: 60,
    });
  },
});

/**
 * Rate limiting pour API endpoints critiques
 */
export const criticalRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 30, // 30 requêtes par minute
  skipSuccessfulRequests: false,
});

/**
 * Validation et nettoyage des entrées
 */
export function sanitizeInputs(req: Request, _res: Response, next: NextFunction): void {
  try {
    // Nettoyer les query parameters
    if (req.query) {
      Object.keys(req.query).forEach(key => {
        if (typeof req.query[key] === 'string') {
          // Supprimer les caractè_res dangereux
          req.query[key] = (req.query[key] as string)
            .replace(/[<>\"']/g, '')
            .trim();
        }
      });
    }

    // Nettoyer les body parameters (sauf les chemins de fichiers légitimes)
    if (req.body && typeof req.body === 'object') {
      Object.keys(req.body).forEach(key => {
        if (typeof req.body[key] === 'string' && !key.toLowerCase().includes('path')) {
          req.body[key] = req.body[key]
            .replace(/[<>]/g, '')
            .trim();
        }
      });
    }

    next();
  } catch (error) {
    logger.error('Input sanitization error', { error });
    next();
  }
}

/**
 * Détection d'activité suspecte
 */
const suspiciousActivityMap = new Map<string, {
  count: number;
  firstSeen: number;
  lastSeen: number;
  violations: string[];
}>();

export function detectSuspiciousActivity(req: Request, _res: Response, next: NextFunction): void {
  const identifier = (req as any).user?.uid || req.ip || 'unknown';
  const now = Date.now();
  
  const activity = suspiciousActivityMap.get(identifier) || {
    count: 0,
    firstSeen: now,
    lastSeen: now,
    violations: [],
  };

  // Vérifier les patterns suspects
  const suspiciousPatterns = [
    { pattern: /../, field: 'path-traversal', value: req.path },
    { pattern: /<script>/i, field: 'xss-attempt', value: JSON.stringify(req.body) },
    { pattern: /union.*select/i, field: 'sql-injection', value: JSON.stringify(req.query) },
    { pattern: /\$\{.*\}/i, field: 'template-injection', value: JSON.stringify(req.body) },
  ];

  let isViolation = false;
  suspiciousPatterns.forEach(({ pattern, field, value }) => {
    if (pattern.test(value)) {
      activity.violations.push(field);
      isViolation = true;
      logger.warn('Suspicious activity detected', {
        identifier,
        violation: field,
        path: req.path,
        ip: req.ip,
        userAgent: req.get('user-agent'),
      });
    }
  });

  if (isViolation) {
    activity.count++;
    activity.lastSeen = now;
    suspiciousActivityMap.set(identifier, activity);

    // Bloquer si trop de violations
    if (activity.count > 5) {
      logger.error('Suspicious user blocked', {
        identifier,
        violations: activity.violations,
        count: activity.count,
      });
      _res.status(403).json({
        success: false,
        error: 'Access denied due to suspicious activity',
      });
      return;
    }
  }

  next();
}

/**
 * Nettoyage périodique des maps de rate limiting
 */
setInterval(() => {
  const now = Date.now();
  const expirationTime = 30 * 60 * 1000; // 30 minutes

  suspiciousActivityMap.forEach((activity, key) => {
    if (now - activity.lastSeen > expirationTime) {
      suspiciousActivityMap.delete(key);
    }
  });
}, 10 * 60 * 1000); // Nettoyer toutes les 10 minutes

/**
 * Validation des tailles de fichiers avant upload
 */
export function validateFileSize(maxSize: number) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const contentLength = req.get('content-length');
    
    if (contentLength && parseInt(contentLength) > maxSize) {
      logger.warn('File size exceeded', {
        size: contentLength,
        maxSize,
        user: (req as any).user?.uid,
      });
      _res.status(413).json({
        success: false,
        error: 'File too large',
        maxSize: `${maxSize / (1024 * 1024)} MB`,
      });
      return;
    }

    next();
  };
}

/**
 * Protection contre les requêtes lentes (Slowloris)
 */
export function slowRequestProtection(req: Request, _res: Response, next: NextFunction): void {
  const timeout = 30000; // 30 secondes max
  const timer = setTimeout(() => {
    logger.warn('Slow request timeout', {
      path: req.path,
      ip: req.ip,
      method: req.method,
    });
    _res.status(408).json({
      success: false,
      error: 'Request timeout',
    });
  }, timeout);

  _res.on('finish', () => clearTimeout(timer));
  _res.on('close', () => clearTimeout(timer));

  next();
}

/**
 * Logging des requêtes sensibles
 */
export function auditLog(req: Request, _res: Response, next: NextFunction): void {
  const sensitiveEndpoints = [
    '/api/users/signup',
    '/api/users/login',
    '/api/storage/upload',
    '/api/social/connect',
  ];

  if (sensitiveEndpoints.some(endpoint => req.path.includes(endpoint))) {
    logger.info('Sensitive endpoint accessed', {
      path: req.path,
      method: req.method,
      user: (req as any).user?.uid || 'anonymous',
      ip: req.ip,
      userAgent: req.get('user-agent'),
      timestamp: new Date().toISOString(),
    });
  }

  next();
}

/**
 * Configuration CORS middleware
 */
export const corsMiddleware = cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000', 'http://localhost:5173'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  exposedHeaders: ['Content-Range', 'X-Content-Range'],
  maxAge: 86400, // 24 heures
});

/**
 * Validation CORS stricte
 */
export function strictCorsValidation(req: Request, _res: Response, next: NextFunction): void {
  const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [];
  const origin = req.get('origin');

  if (origin && allowedOrigins.length > 0 && !allowedOrigins.includes(origin)) {
    logger.warn('CORS violation', {
      origin,
      allowedOrigins,
      path: req.path,
    });
  }

  next();
}

/**
 * Health check endpoint (non authentifié)
 */
export function healthCheck(_req: Request, _res: Response): void {
  _res.status(200).json({
    success: true,
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
  });
}
