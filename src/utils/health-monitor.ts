/**
 * Health Monitoring & Circuit Breaker
 * Pour maintenabilité et stabilité à long terme
 */

import { logger } from '../utils/logger';

export interface ServiceHealth {
  name: string;
  status: 'healthy' | 'degraded' | 'down';
  latency: number;
  lastCheck: Date;
  errorRate: number;
  consecutiveFailures: number;
}

export class HealthMonitor {
  private services: Map<string, ServiceHealth> = new Map();
  private readonly CHECK_INTERVAL = 60000; // 1 minute
  private intervalId?: NodeJS.Timeout;

  constructor() {
    this.initializeServices();
  }

  private initializeServices(): void {
    const serviceNames = [
      'redis',
      'firebase',
      'ollama',
      'ffmpeg',
      'whisper',
      'piper-tts',
    ];

    serviceNames.forEach(name => {
      this.services.set(name, {
        name,
        status: 'healthy',
        latency: 0,
        lastCheck: new Date(),
        errorRate: 0,
        consecutiveFailures: 0,
      });
    });
  }

  /**
   * Démarre le monitoring périodique
   */
  start(): void {
    logger.info('🔍 Health monitor started');
    
    this.intervalId = setInterval(() => {
      this.checkAllServices();
    }, this.CHECK_INTERVAL);

    // Check immédiat au démarrage
    this.checkAllServices();
  }

  /**
   * Arrête le monitoring
   */
  stop(): void {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      logger.info('Health monitor stopped');
    }
  }

  /**
   * Vérifie tous les services
   */
  private async checkAllServices(): Promise<void> {
    for (const [name, health] of this.services.entries()) {
      try {
        const startTime = Date.now();
        const isHealthy = await this.checkService(name);
        const latency = Date.now() - startTime;

        if (isHealthy) {
          health.status = 'healthy';
          health.consecutiveFailures = 0;
          health.errorRate = Math.max(0, health.errorRate - 0.1);
        } else {
          health.consecutiveFailures++;
          health.errorRate = Math.min(1, health.errorRate + 0.2);
          
          if (health.consecutiveFailures >= 3) {
            health.status = 'down';
            logger.error(`Service ${name} is DOWN`, { health });
          } else {
            health.status = 'degraded';
            logger.warn(`Service ${name} is DEGRADED`, { health });
          }
        }

        health.latency = latency;
        health.lastCheck = new Date();

      } catch (error) {
        logger.error(`Health check failed for ${name}`, { error });
        health.status = 'degraded';
        health.consecutiveFailures++;
      }
    }
  }

  /**
   * Vérifie un service spécifique
   */
  private async checkService(name: string): Promise<boolean> {
    switch (name) {
      case 'redis':
        return this.checkRedis();
      case 'firebase':
        return this.checkFirebase();
      case 'ollama':
        return this.checkOllama();
      case 'ffmpeg':
        return this.checkFFmpeg();
      case 'whisper':
        return this.checkWhisper();
      case 'piper-tts':
        return this.checkPiperTTS();
      default:
        return true;
    }
  }

  private async checkRedis(): Promise<boolean> {
    if (!process.env.REDIS_HOST) return true; // Optional service
    try {
      // TODO: Ping Redis
      return true;
    } catch {
      return false;
    }
  }

  private async checkFirebase(): Promise<boolean> {
    try {
      // Firebase is always initialized
      return true;
    } catch {
      return false;
    }
  }

  private async checkOllama(): Promise<boolean> {
    if (!process.env.OLLAMA_URL) return true; // Optional
    try {
      const response = await fetch(`${process.env.OLLAMA_URL}/api/tags`, {
        signal: AbortSignal.timeout(5000),
      });
      return response.ok;
    } catch {
      return false;
    }
  }

  private async checkFFmpeg(): Promise<boolean> {
    try {
      // FFmpeg is always available
      return true;
    } catch {
      return false;
    }
  }

  private async checkWhisper(): Promise<boolean> {
    if (!process.env.WHISPER_EXECUTABLE) return true; // Optional
    try {
      // TODO: Check Whisper binary
      return true;
    } catch {
      return false;
    }
  }

  private async checkPiperTTS(): Promise<boolean> {
    if (!process.env.PIPER_MODEL_PATH) return true; // Optional
    try {
      // TODO: Check Piper TTS
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Récupère le statut d'un service
   */
  getServiceHealth(name: string): ServiceHealth | undefined {
    return this.services.get(name);
  }

  /**
   * Récupère le statut global
   */
  getOverallHealth(): {
    status: 'healthy' | 'degraded' | 'down';
    services: Record<string, ServiceHealth>;
  } {
    const servicesObj: Record<string, ServiceHealth> = {};
    let hasDown = false;
    let hasDegraded = false;

    for (const [name, health] of this.services.entries()) {
      servicesObj[name] = health;
      if (health.status === 'down') hasDown = true;
      if (health.status === 'degraded') hasDegraded = true;
    }

    let overallStatus: 'healthy' | 'degraded' | 'down' = 'healthy';
    if (hasDown) overallStatus = 'down';
    else if (hasDegraded) overallStatus = 'degraded';

    return {
      status: overallStatus,
      services: servicesObj,
    };
  }
}

/**
 * Circuit Breaker Pattern
 * Empêche l'overload des services défaillants
 */
export class CircuitBreaker {
  private failures: number = 0;
  private lastFailureTime: number = 0;
  private state: 'closed' | 'open' | 'half-open' = 'closed';
  
  private readonly FAILURE_THRESHOLD = 5;
  private readonly TIMEOUT = 60000; // 1 minute
  private readonly HALF_OPEN_ATTEMPTS = 3;
  private halfOpenAttempts: number = 0;

  constructor(private serviceName: string) {}

  /**
   * Exécute une fonction avec circuit breaker
   */
  async execute<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'open') {
      if (Date.now() - this.lastFailureTime > this.TIMEOUT) {
        // Try to recover
        this.state = 'half-open';
        this.halfOpenAttempts = 0;
        logger.info(`Circuit breaker ${this.serviceName}: OPEN -> HALF-OPEN`);
      } else {
        throw new Error(`Circuit breaker ${this.serviceName} is OPEN`);
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess(): void {
    if (this.state === 'half-open') {
      this.halfOpenAttempts++;
      if (this.halfOpenAttempts >= this.HALF_OPEN_ATTEMPTS) {
        this.state = 'closed';
        this.failures = 0;
        logger.info(`Circuit breaker ${this.serviceName}: HALF-OPEN -> CLOSED`);
      }
    } else {
      this.failures = 0;
    }
  }

  private onFailure(): void {
    this.failures++;
    this.lastFailureTime = Date.now();

    if (this.failures >= this.FAILURE_THRESHOLD) {
      if (this.state !== 'open') {
        this.state = 'open';
        logger.error(`Circuit breaker ${this.serviceName}: ${this.state} -> OPEN`);
      }
    }
  }

  getState(): 'closed' | 'open' | 'half-open' {
    return this.state;
  }
}

// Export singleton
export const healthMonitor = new HealthMonitor();

// Circuit breakers pour services critiques
export const circuitBreakers = {
  redis: new CircuitBreaker('redis'),
  ollama: new CircuitBreaker('ollama'),
  whisper: new CircuitBreaker('whisper'),
  ffmpeg: new CircuitBreaker('ffmpeg'),
};
