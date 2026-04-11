import { logger } from './logger';
import os from 'os';
import * as fs from 'fs/promises';

/**
 * 📊 SYSTÈME DE MONITORING PRODUCTION
 * Surveillance continue de la santé de l'application
 */

interface SystemMetrics {
  timestamp: number;
  cpu: {
    usage: number;
    loadAverage: number[];
    cores: number;
  };
  memory: {
    total: number;
    free: number;
    used: number;
    usagePercent: number;
    processRss: number;
    processHeapUsed: number;
    processHeapTotal: number;
  };
  disk: {
    uploadsSize: number;
    outputsSize: number;
  };
  process: {
    uptime: number;
    pid: number;
    version: string;
    platform: string;
  };
  requests: {
    total: number;
    errors: number;
    avgResponseTime: number;
  };
}

class ProductionMonitor {
  private metrics: SystemMetrics[] = [];
  private maxMetrics = 1000; // Garder 1000 dernières métriques
  private monitoringInterval?: NodeJS.Timeout;
  private requestStats = {
    total: 0,
    errors: 0,
    responseTimes: [] as number[],
  };

  constructor() {
    this.startMonitoring();
  }

  /**
   * Démarrer le monitoring continu
   */
  private startMonitoring(): void {
    logger.info('🔍 Starting production monitoring...');

    // Collecter les métriques toutes les 30 secondes
    this.monitoringInterval = setInterval(() => {
      this.collectMetrics();
    }, 30000);

    // Vérifier la santé toutes les 2 minutes
    setInterval(() => {
      this.checkHealth();
    }, 120000);

    // Rapport résumé toutes les 10 minutes
    setInterval(() => {
      this.generateHealthReport();
    }, 600000);
  }

  /**
   * Collecter les métriques système
   */
  private async collectMetrics(): Promise<void> {
    try {
      const uploadDir = process.env.UPLOAD_DIR || './uploads';
      const outputDir = process.env.OUTPUT_DIR || './outputs';

      const [uploadsSize, outputsSize] = await Promise.all([
        this.getDirSize(uploadDir),
        this.getDirSize(outputDir),
      ]);

      const metrics: SystemMetrics = {
        timestamp: Date.now(),
        cpu: {
          usage: process.cpuUsage().user / 1000000, // En secondes
          loadAverage: os.loadavg(),
          cores: os.cpus().length,
        },
        memory: {
          total: os.totalmem(),
          free: os.freemem(),
          used: os.totalmem() - os.freemem(),
          usagePercent: ((os.totalmem() - os.freemem()) / os.totalmem()) * 100,
          processRss: process.memoryUsage().rss,
          processHeapUsed: process.memoryUsage().heapUsed,
          processHeapTotal: process.memoryUsage().heapTotal,
        },
        disk: {
          uploadsSize,
          outputsSize,
        },
        process: {
          uptime: process.uptime(),
          pid: process.pid,
          version: process.version,
          platform: process.platform,
        },
        requests: {
          total: this.requestStats.total,
          errors: this.requestStats.errors,
          avgResponseTime: this.calculateAvgResponseTime(),
        },
      };

      this.metrics.push(metrics);

      // Limiter la taille du buffer
      if (this.metrics.length > this.maxMetrics) {
        this.metrics = this.metrics.slice(-this.maxMetrics);
      }
    } catch (error) {
      logger.error('Failed to collect metrics', { error });
    }
  }

  /**
   * Vérifier la santé du système
   */
  private checkHealth(): void {
    const latest = this.metrics[this.metrics.length - 1];
    if (!latest) return;

    const warnings: string[] = [];
    const criticals: string[] = [];

    // Vérification mémoire
    if (latest.memory.usagePercent > 90) {
      criticals.push(`Memory usage critical: ${latest.memory.usagePercent.toFixed(1)}%`);
    } else if (latest.memory.usagePercent > 75) {
      warnings.push(`Memory usage high: ${latest.memory.usagePercent.toFixed(1)}%`);
    }

    // Vérification CPU
    const avgLoad = latest.cpu.loadAverage[0];
    const cpuThreshold = latest.cpu.cores * 0.8;
    if (avgLoad > cpuThreshold) {
      warnings.push(`CPU load high: ${avgLoad.toFixed(2)} (${latest.cpu.cores} cores)`);
    }

    // Vérification disque
    const totalDiskUsage = latest.disk.uploadsSize + latest.disk.outputsSize;
    const diskLimitMB = 10 * 1024; // 10 GB
    if (totalDiskUsage > diskLimitMB * 1024 * 1024) {
      warnings.push(`Disk usage high: ${(totalDiskUsage / (1024 * 1024 * 1024)).toFixed(2)} GB`);
    }

    // Vérification taux d'erreur
    const errorRate = (latest.requests.errors / Math.max(latest.requests.total, 1)) * 100;
    if (errorRate > 10) {
      criticals.push(`Error rate critical: ${errorRate.toFixed(1)}%`);
    } else if (errorRate > 5) {
      warnings.push(`Error rate elevated: ${errorRate.toFixed(1)}%`);
    }

    // Logger les problèmes
    if (criticals.length > 0) {
      logger.error('🚨 CRITICAL HEALTH ISSUES', { criticals, metrics: latest });
    }
    if (warnings.length > 0) {
      logger.warn('⚠️ Health warnings', { warnings });
    }
  }

  /**
   * Générer un rapport de santé complet
   */
  private generateHealthReport(): void {
    if (this.metrics.length === 0) return;

    const latest = this.metrics[this.metrics.length - 1];
    const last10 = this.metrics.slice(-10);

    const avgMemory = last10.reduce((sum, m) => sum + m.memory.usagePercent, 0) / last10.length;
    const avgCpu = last10.reduce((sum, m) => sum + m.cpu.loadAverage[0], 0) / last10.length;

    logger.info('📊 Health Report (Last 5 minutes)', {
      uptime: `${(latest.process.uptime / 3600).toFixed(2)} hours`,
      memory: {
        current: `${latest.memory.usagePercent.toFixed(1)}%`,
        average: `${avgMemory.toFixed(1)}%`,
        process: `${(latest.memory.processRss / (1024 * 1024)).toFixed(0)} MB`,
      },
      cpu: {
        cores: latest.cpu.cores,
        load: latest.cpu.loadAverage[0].toFixed(2),
        average: avgCpu.toFixed(2),
      },
      requests: {
        total: latest.requests.total,
        errors: latest.requests.errors,
        errorRate: `${((latest.requests.errors / Math.max(latest.requests.total, 1)) * 100).toFixed(2)}%`,
        avgResponseTime: `${latest.requests.avgResponseTime.toFixed(0)}ms`,
      },
      disk: {
        uploads: `${(latest.disk.uploadsSize / (1024 * 1024)).toFixed(0)} MB`,
        outputs: `${(latest.disk.outputsSize / (1024 * 1024)).toFixed(0)} MB`,
        total: `${((latest.disk.uploadsSize + latest.disk.outputsSize) / (1024 * 1024)).toFixed(0)} MB`,
      },
    });
  }

  /**
   * Enregistrer une requête
   */
  public recordRequest(responseTime: number, isError: boolean = false): void {
    this.requestStats.total++;
    if (isError) {
      this.requestStats.errors++;
    }
    this.requestStats.responseTimes.push(responseTime);

    // Limiter la taille du buffer
    if (this.requestStats.responseTimes.length > 1000) {
      this.requestStats.responseTimes = this.requestStats.responseTimes.slice(-1000);
    }
  }

  /**
   * Calculer le temps de réponse moyen
   */
  private calculateAvgResponseTime(): number {
    if (this.requestStats.responseTimes.length === 0) return 0;
    const sum = this.requestStats.responseTimes.reduce((a, b) => a + b, 0);
    return sum / this.requestStats.responseTimes.length;
  }

  /**
   * Obtenir la taille d'un répertoire
   */
  private async getDirSize(dirPath: string): Promise<number> {
    try {
      await fs.access(dirPath);
      const files = await fs.readdir(dirPath);
      let totalSize = 0;

      for (const file of files) {
        try {
          const filePath = `${dirPath}/${file}`;
          const stats = await fs.stat(filePath);
          if (stats.isFile()) {
            totalSize += stats.size;
          } else if (stats.isDirectory()) {
            totalSize += await this.getDirSize(filePath);
          }
        } catch (err) {
          // Ignorer les fichiers inaccessibles
        }
      }

      return totalSize;
    } catch (error) {
      return 0;
    }
  }

  /**
   * Obtenir les métriques actuelles
   */
  public getCurrentMetrics(): SystemMetrics | null {
    return this.metrics[this.metrics.length - 1] || null;
  }

  /**
   * Obtenir l'historique des métriques
   */
  public getMetricsHistory(count: number = 100): SystemMetrics[] {
    return this.metrics.slice(-count);
  }

  /**
   * Arrêter le monitoring
   */
  public stop(): void {
    if (this.monitoringInterval) {
      clearInterval(this.monitoringInterval);
      logger.info('Production monitoring stopped');
    }
  }

  /**
   * Nettoyage automatique des fichiers anciens
   */
  public async cleanOldFiles(dirPath: string, maxAgeDays: number = 7): Promise<number> {
    try {
      const files = await fs.readdir(dirPath);
      const now = Date.now();
      const maxAgeMs = maxAgeDays * 24 * 60 * 60 * 1000;
      let deletedCount = 0;

      for (const file of files) {
        try {
          const filePath = `${dirPath}/${file}`;
          const stats = await fs.stat(filePath);
          
          if (now - stats.mtimeMs > maxAgeMs) {
            await fs.unlink(filePath);
            deletedCount++;
            logger.info('Deleted old file', { file: filePath, age: Math.floor((now - stats.mtimeMs) / (24 * 60 * 60 * 1000)) });
          }
        } catch (err) {
          logger.warn('Failed to delete old file', { file, error: err });
        }
      }

      return deletedCount;
    } catch (error) {
      logger.error('Failed to clean old files', { dirPath, error });
      return 0;
    }
  }
}

// Singleton instance
export const productionMonitor = new ProductionMonitor();

/**
 * Middleware pour tracker les requêtes
 */
export function monitoringMiddleware(_req: any, res: any, next: any): void {
  const startTime = Date.now();

  res.on('finish', () => {
    const responseTime = Date.now() - startTime;
    const isError = res.statusCode >= 400;
    productionMonitor.recordRequest(responseTime, isError);
  });

  next();
}

/**
 * Nettoyage automatique périodique
 */
if (process.env.NODE_ENV === 'production') {
  // Nettoyer les fichiers anciens tous les jours à 3h du matin
  const scheduleCleanup = () => {
    const now = new Date();
    const target = new Date();
    target.setHours(3, 0, 0, 0);
    
    if (target <= now) {
      target.setDate(target.getDate() + 1);
    }

    const delay = target.getTime() - now.getTime();

    setTimeout(async () => {
      logger.info('🧹 Starting scheduled cleanup...');
      const uploadDir = process.env.UPLOAD_DIR || './uploads';
      const outputDir = process.env.OUTPUT_DIR || './outputs';

      const [uploadsCleaned, outputsCleaned] = await Promise.all([
        productionMonitor.cleanOldFiles(uploadDir, 7),
        productionMonitor.cleanOldFiles(outputDir, 7),
      ]);

      logger.info('✅ Scheduled cleanup completed', {
        uploadsCleaned,
        outputsCleaned,
        total: uploadsCleaned + outputsCleaned,
      });

      // Reprogrammer pour le lendemain
      scheduleCleanup();
    }, delay);
  };

  scheduleCleanup();
}
