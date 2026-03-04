import { Queue, Worker, Job } from 'bullmq';
import { FFmpegEngine, RenderOptions, RenderResult } from '../modules/video/ffmpeg.engine';
import { logger } from '../utils/logger';

/**
 * Configuration Redis (optionnel pour Railway)
 */
const REDIS_ENABLED = process.env.REDIS_HOST ? true : false;

const redisConnection = REDIS_ENABLED ? {
  host: process.env.REDIS_HOST!,
  port: parseInt(process.env.REDIS_PORT || '6379'),
  maxRetriesPerRequest: null
} : null;

/**
 * Job data pour le rendu
 */
export interface RenderJobData extends RenderOptions {
  jobId: string;
}

/**
 * Interface commune pour tous les types de queues
 */
interface JobStatus {
  id: string;
  state: string;
  progress: number | object;
  returnvalue?: RenderResult;
  failedReason?: string;
}

/**
 * In-Memory Queue Fallback (quand Redis n'est pas disponible)
 */
class InMemoryQueue {
  private jobs: Map<string, { data: RenderJobData; status: JobStatus; processing: boolean }> = new Map();
  private ffmpegEngine: FFmpegEngine;

  constructor(uploadDir: string, outputDir: string) {
    this.ffmpegEngine = new FFmpegEngine(uploadDir, outputDir);
    logger.warn('⚠️  Using in-memory queue (not recommended for production)');
  }

  async add(_name: string, data: RenderJobData): Promise<{ id: string }> {
    const job = {
      data,
      status: {
        id: data.jobId,
        state: 'waiting',
        progress: 0,
      },
      processing: false
    };
    
    this.jobs.set(data.jobId, job);
    
    // Traiter immédiatement (pas de vrai queueing)
    this.processJob(data.jobId).catch(err => {
      logger.error(`Job ${data.jobId} failed:`, err);
    });
    
    return { id: data.jobId };
  }

  private async processJob(jobId: string): Promise<void> {
    const job = this.jobs.get(jobId);
    if (!job || job.processing) return;

    job.processing = true;
    job.status.state = 'active';
    job.status.progress = 10;

    try {
      logger.info(`🎬 Job ${jobId} started (in-memory)`);
      const result = await this.ffmpegEngine.render(job.data);
      
      job.status.state = 'completed';
      job.status.progress = 100;
      job.status.returnvalue = result;
      
      logger.info(`✅ Job ${jobId} completed: ${result.outputPath}`);
    } catch (error: any) {
      job.status.state = 'failed';
      job.status.failedReason = error.message;
      logger.error(`❌ Job ${jobId} failed:`, error.message);
    }
  }

  async getJob(jobId: string): Promise<{ getState: () => Promise<string>; progress: number | object; data: RenderJobData; returnvalue?: RenderResult; failedReason?: string } | null> {
    const job = this.jobs.get(jobId);
    if (!job) return null;

    return {
      getState: async () => job.status.state,
      progress: job.status.progress,
      data: job.data,
      returnvalue: job.status.returnvalue,
      failedReason: job.status.failedReason
    };
  }

  async getWaitingCount(): Promise<number> {
    return Array.from(this.jobs.values()).filter(j => j.status.state === 'waiting').length;
  }

  async getActiveCount(): Promise<number> {
    return Array.from(this.jobs.values()).filter(j => j.status.state === 'active').length;
  }

  async getCompletedCount(): Promise<number> {
    return Array.from(this.jobs.values()).filter(j => j.status.state === 'completed').length;
  }

  async getFailedCount(): Promise<number> {
    return Array.from(this.jobs.values()).filter(j => j.status.state === 'failed').length;
  }

  async close(): Promise<void> {
    this.jobs.clear();
  }
}

/**
 * Gestionnaire de queue pour les rendus vidéo
 * Supporte Redis (production) et in-memory (développement/Railway)
 */
export class RenderQueue {
  private queue: Queue<RenderJobData> | InMemoryQueue;
  private worker?: Worker<RenderJobData, RenderResult>;
  private ffmpegEngine?: FFmpegEngine;
  private isRedis: boolean;

  constructor(uploadDir: string, outputDir: string) {
    this.isRedis = REDIS_ENABLED;

    if (REDIS_ENABLED && redisConnection) {
      logger.info('✅ Using Redis-based queue');
      
      this.ffmpegEngine = new FFmpegEngine(uploadDir, outputDir);

      // Crée la queue Redis
      this.queue = new Queue<RenderJobData>('video-render', {
        connection: redisConnection,
        defaultJobOptions: {
          attempts: 3,
          backoff: {
            type: 'exponential',
            delay: 5000
          },
          removeOnComplete: {
            age: 3600, // Garde les jobs complétés 1h
            count: 100
          },
          removeOnFail: {
            age: 86400 // Garde les jobs échoués 24h
          }
        }
      });

      // Crée le worker Redis
      this.worker = new Worker<RenderJobData, RenderResult>(
        'video-render',
        async (job: Job<RenderJobData>) => {
          return this.processRenderJob(job);
        },
        {
          connection: redisConnection,
          concurrency: parseInt(process.env.FFMPEG_THREADS || '2')
        }
      );

      this.setupEventListeners();
    } else {
      logger.warn('⚠️  Redis not available - using in-memory queue');
      this.queue = new InMemoryQueue(uploadDir, outputDir);
    }
  }

  /**
   * Ajoute un job de rendu à la queue
   */
  async addRenderJob(data: RenderJobData): Promise<Job<RenderJobData> | { id: string }> {
    if (this.isRedis && this.queue instanceof Queue) {
      return this.queue.add('render-video', data, {
        jobId: data.jobId
      });
    } else {
      return (this.queue as InMemoryQueue).add('render-video', data);
    }
  }

  /**
   * Récupère l'état d'un job
   */
  async getJobStatus(jobId: string): Promise<any> {
    const job = await this.queue.getJob(jobId);
    if (!job) {
      return null;
    }

    const state = await job.getState();
    const progress = job.progress;

    return {
      id: jobId,
      state,
      progress,
      data: job.data,
      returnvalue: job.returnvalue,
      failedReason: job.failedReason
    };
  }

  /**
   * Traite un job de rendu (Redis uniquement)
   */
  private async processRenderJob(job: Job<RenderJobData>): Promise<RenderResult> {
    if (!this.ffmpegEngine) {
      throw new Error('FFmpeg engine not initialized');
    }

    try {
      // Met à jour la progression
      await job.updateProgress(10);

      // Lance le rendu
      const result = await this.ffmpegEngine.render(job.data);

      // Progression finale
      await job.updateProgress(100);

      return result;
    } catch (error) {
      throw new Error(`Erreur de rendu : ${error}`);
    }
  }

  /**
   * Configure les listeners d'événements (Redis uniquement)
   */
  private setupEventListeners(): void {
    if (!this.worker) return;

    this.worker.on('completed', (job, result) => {
      logger.info(`✅ Job ${job.id} terminé : ${result.outputPath}`);
    });

    this.worker.on('failed', (job, err) => {
      logger.error(`❌ Job ${job?.id} échoué :`, err.message);
    });

    this.worker.on('active', (job) => {
      logger.info(`🎬 Job ${job.id} démarré`);
    });

    if (this.queue instanceof Queue) {
      this.queue.on('error', (err) => {
        logger.error('❌ Erreur queue :', err);
      });
    }
  }

  /**
   * Ferme proprement la queue et le worker
   */
  async close(): Promise<void> {
    if (this.worker) {
      await this.worker.close();
    }
    await this.queue.close();
  }

  /**
   * Récupère les stats de la queue
   */
  async getStats() {
    const waiting = await this.queue.getWaitingCount();
    const active = await this.queue.getActiveCount();
    const completed = await this.queue.getCompletedCount();
    const failed = await this.queue.getFailedCount();

    return {
      waiting,
      active,
      completed,
      failed,
      total: waiting + active + completed + failed
    };
  }
}

// Singleton
let renderQueueInstance: RenderQueue | null = null;

export function getRenderQueue(): RenderQueue {
  if (!renderQueueInstance) {
    const uploadDir = process.env.UPLOAD_DIR || './uploads';
    const outputDir = process.env.OUTPUT_DIR || './outputs';
    renderQueueInstance = new RenderQueue(uploadDir, outputDir);
  }
  return renderQueueInstance;
}
