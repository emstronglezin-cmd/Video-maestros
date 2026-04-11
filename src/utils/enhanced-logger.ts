/**
 * Enhanced Logging System
 * Pour maintenabilité et debugging à long terme
 */

import pino from 'pino';
import * as fs from 'fs';
import * as path from 'path';

// Créer répertoire logs
const LOG_DIR = process.env.LOG_DIR || './logs';
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

// Rotation des logs
const logFile = path.join(LOG_DIR, `app-${new Date().toISOString().split('T')[0]}.log`);
const errorLogFile = path.join(LOG_DIR, `error-${new Date().toISOString().split('T')[0]}.log`);

/**
 * Logger principal avec rotation automatique
 */
export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport: {
    targets: [
      {
        target: 'pino-pretty',
        level: 'info',
        options: {
          colorize: true,
          translateTime: 'SYS:standard',
          ignore: 'pid,hostname',
        },
      },
      {
        target: 'pino/file',
        level: 'info',
        options: { destination: logFile },
      },
      {
        target: 'pino/file',
        level: 'error',
        options: { destination: errorLogFile },
      },
    ],
  },
});

/**
 * Request logging middleware avec métriques
 */
import { Request, Response, NextFunction } from 'express';

export interface RequestMetrics {
  method: string;
  path: string;
  statusCode: number;
  responseTime: number;
  userId?: string;
  userAgent?: string;
  ip?: string;
}

const requestMetrics: RequestMetrics[] = [];
const MAX_METRICS = 10000; // Garder 10k dernières requêtes

export function requestLogger(req: Request, res: Response, next: NextFunction): void {
  const startTime = Date.now();

  // Capture response
  const originalSend = res.json.bind(res);
  res.json = function(body: any) {
    const responseTime = Date.now() - startTime;
    
    const metrics: RequestMetrics = {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      responseTime,
      userId: (req as any).user?.uid,
      userAgent: req.get('user-agent'),
      ip: req.ip,
    };

    // Store metrics
    requestMetrics.push(metrics);
    if (requestMetrics.length > MAX_METRICS) {
      requestMetrics.shift();
    }

    // Log based on status
    if (res.statusCode >= 500) {
      logger.error({
        msg: 'Request failed',
        ...metrics,
      });
    } else if (res.statusCode >= 400) {
      logger.warn({
        msg: 'Request error',
        ...metrics,
      });
    } else if (responseTime > 5000) {
      logger.warn({
        msg: 'Slow request',
        ...metrics,
      });
    } else {
      logger.info({
        msg: 'Request completed',
        ...metrics,
      });
    }

    return originalSend(body);
  };

  next();
}

/**
 * Performance monitoring
 */
export class PerformanceMonitor {
  private metrics: Map<string, number[]> = new Map();

  track(operation: string, duration: number): void {
    if (!this.metrics.has(operation)) {
      this.metrics.set(operation, []);
    }

    const durations = this.metrics.get(operation)!;
    durations.push(duration);

    // Keep last 1000 measurements
    if (durations.length > 1000) {
      durations.shift();
    }
  }

  getStats(operation: string): {
    avg: number;
    min: number;
    max: number;
    p95: number;
    p99: number;
  } | null {
    const durations = this.metrics.get(operation);
    if (!durations || durations.length === 0) {
      return null;
    }

    const sorted = [...durations].sort((a, b) => a - b);
    const sum = sorted.reduce((a, b) => a + b, 0);

    return {
      avg: sum / sorted.length,
      min: sorted[0],
      max: sorted[sorted.length - 1],
      p95: sorted[Math.floor(sorted.length * 0.95)],
      p99: sorted[Math.floor(sorted.length * 0.99)],
    };
  }

  getAllStats(): Record<string, ReturnType<typeof this.getStats>> {
    const stats: Record<string, ReturnType<typeof this.getStats>> = {};
    
    for (const [operation] of this.metrics) {
      stats[operation] = this.getStats(operation);
    }

    return stats;
  }
}

export const performanceMonitor = new PerformanceMonitor();

/**
 * Structured error logging
 */
export function logError(error: Error, context?: Record<string, any>): void {
  logger.error({
    msg: error.message,
    stack: error.stack,
    name: error.name,
    ...context,
  });
}

/**
 * Log rotation cleanup (daily)
 */
export function cleanupOldLogs(daysToKeep: number = 30): void {
  try {
    const files = fs.readdirSync(LOG_DIR);
    const now = Date.now();
    const maxAge = daysToKeep * 24 * 60 * 60 * 1000;

    for (const file of files) {
      if (!file.endsWith('.log')) continue;

      const filePath = path.join(LOG_DIR, file);
      const stats = fs.statSync(filePath);
      const age = now - stats.mtimeMs;

      if (age > maxAge) {
        fs.unlinkSync(filePath);
        logger.info(`Deleted old log file: ${file}`);
      }
    }
  } catch (error) {
    logger.error('Failed to cleanup old logs', { error });
  }
}

// Schedule daily cleanup
setInterval(() => {
  cleanupOldLogs();
}, 24 * 60 * 60 * 1000);

/**
 * Export request metrics for monitoring
 */
export function getRequestMetrics(): {
  total: number;
  avgResponseTime: number;
  errorRate: number;
  slowRequests: number;
} {
  if (requestMetrics.length === 0) {
    return {
      total: 0,
      avgResponseTime: 0,
      errorRate: 0,
      slowRequests: 0,
    };
  }

  const totalTime = requestMetrics.reduce((sum, m) => sum + m.responseTime, 0);
  const errors = requestMetrics.filter(m => m.statusCode >= 400).length;
  const slow = requestMetrics.filter(m => m.responseTime > 5000).length;

  return {
    total: requestMetrics.length,
    avgResponseTime: totalTime / requestMetrics.length,
    errorRate: errors / requestMetrics.length,
    slowRequests: slow,
  };
}
