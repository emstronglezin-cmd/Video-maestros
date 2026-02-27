import { Queue, Worker, Job } from 'bullmq';
import { FFmpegEngine, RenderOptions, RenderResult } from '../modules/video/ffmpeg.engine';

/**
 * Configuration Redis
 */
const redisConnection = {
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  maxRetriesPerRequest: null
};

/**
 * Job data pour le rendu
 */
export interface RenderJobData extends RenderOptions {
  jobId: string;
}

/**
 * Gestionnaire de queue pour les rendus vidéo
 */
export class RenderQueue {
  private queue: Queue<RenderJobData>;
  private worker: Worker<RenderJobData, RenderResult>;
  private ffmpegEngine: FFmpegEngine;

  constructor(uploadDir: string, outputDir: string) {
    this.ffmpegEngine = new FFmpegEngine(uploadDir, outputDir);

    // Crée la queue
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

    // Crée le worker
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
  }

  /**
   * Ajoute un job de rendu à la queue
   */
  async addRenderJob(data: RenderJobData): Promise<Job<RenderJobData>> {
    return this.queue.add('render-video', data, {
      jobId: data.jobId
    });
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
      id: job.id,
      state,
      progress,
      data: job.data,
      returnvalue: job.returnvalue,
      failedReason: job.failedReason
    };
  }

  /**
   * Traite un job de rendu
   */
  private async processRenderJob(job: Job<RenderJobData>): Promise<RenderResult> {
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
   * Configure les listeners d'événements
   */
  private setupEventListeners(): void {
    this.worker.on('completed', (job, result) => {
      console.log(`✅ Job ${job.id} terminé : ${result.outputPath}`);
    });

    this.worker.on('failed', (job, err) => {
      console.error(`❌ Job ${job?.id} échoué :`, err.message);
    });

    this.worker.on('active', (job) => {
      console.log(`🎬 Job ${job.id} démarré`);
    });

    this.queue.on('error', (err) => {
      console.error('❌ Erreur queue :', err);
    });
  }

  /**
   * Ferme proprement la queue et le worker
   */
  async close(): Promise<void> {
    await this.worker.close();
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
