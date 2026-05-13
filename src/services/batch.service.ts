/**
 * BatchService - Service de traitement batch de vidéos
 * Permet jusqu'à 10 vidéos par session, priorité premium > free
 * Gestion de queue BullMQ avec retry et suivi temps réel
 */

import { Queue, Worker, Job, QueueEvents } from 'bullmq';
import { Redis } from 'ioredis';
import { v4 as uuidv4 } from 'uuid';
import { logger } from '../utils/logger';

// Configuration Redis (Upstash TLS compatible)
const redisUrl = process.env.REDIS_URL;

if (!redisUrl) {
  logger.error('❌ REDIS_URL environment variable is required');
  throw new Error('REDIS_URL not configured - BullMQ requires Redis');
}

const redisConnection = new Redis(redisUrl, {
  maxRetriesPerRequest: null,
  enableReadyCheck: false,
  retryStrategy: (times: number) => {
    const delay = Math.min(times * 50, 2000);
    return delay;
  },
});

export interface BatchJobData {
  userId: string;
  isPremium: boolean;
  videoConfig: any;
  templateId?: string;
  priority: number;  // Premium: 1, Free: 10
  sessionId: string;
}

export interface BatchJobProgress {
  percentage: number;
  stage: string;
  message: string;
}

export interface BatchJobResult {
  success: boolean;
  videoPath?: string;
  duration?: number;
  fileSize?: number;
  error?: string;
}

export interface BatchSession {
  sessionId: string;
  userId: string;
  totalJobs: number;
  completedJobs: number;
  failedJobs: number;
  pendingJobs: number;
  jobs: Array<{
    jobId: string;
    status: 'pending' | 'processing' | 'completed' | 'failed';
    progress: number;
    createdAt: Date;
    startedAt?: Date;
    completedAt?: Date;
    result?: BatchJobResult;
  }>;
  createdAt: Date;
}

const BATCH_QUEUE_NAME = 'video-batch-render';
const MAX_JOBS_PER_SESSION = 10;
// Concurrent job limits
const MAX_CONCURRENT_JOBS_PREMIUM = 3;

export class BatchService {
  private queue: Queue<BatchJobData, BatchJobResult>;
  private worker: Worker<BatchJobData, BatchJobResult>;
  private queueEvents: QueueEvents;
  private sessions: Map<string, BatchSession>;

  constructor() {
    // Créer la queue
    this.queue = new Queue(BATCH_QUEUE_NAME, {
      connection: redisConnection,
      defaultJobOptions: {
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 5000  // 5s, 25s, 125s
        },
        removeOnComplete: {
          age: 86400,  // Garder 24h
          count: 100
        },
        removeOnFail: {
          age: 604800  // Garder 7 jours
        }
      }
    });

    // Créer le worker
    this.worker = new Worker<BatchJobData, BatchJobResult>(
      BATCH_QUEUE_NAME,
      async (job: Job<BatchJobData, BatchJobResult>) => {
        return await this.processVideoJob(job);
      },
      {
        connection: redisConnection.duplicate(),
        concurrency: MAX_CONCURRENT_JOBS_PREMIUM,
        limiter: {
          max: 10,
          duration: 60000  // Max 10 jobs par minute
        }
      }
    );

    // Événements queue
    this.queueEvents = new QueueEvents(BATCH_QUEUE_NAME, {
      connection: redisConnection.duplicate()
    });

    this.sessions = new Map();
    this.setupEventHandlers();

    logger.info('✅ BatchService initialized', { queueName: BATCH_QUEUE_NAME });
  }

  /**
   * Configure les event handlers
   */
  private setupEventHandlers(): void {
    this.worker.on('completed', (job: Job<BatchJobData, BatchJobResult>) => {
      logger.info('✅ Batch job completed', { 
        jobId: job.id, 
        userId: job.data.userId,
        duration: Date.now() - (job.processedOn || 0)
      });
      this.updateSessionJobStatus(job.data.sessionId, job.id!, 'completed');
    });

    this.worker.on('failed', (job: Job<BatchJobData, BatchJobResult> | undefined, error: Error) => {
      if (!job) return;
      logger.error('❌ Batch job failed', { 
        jobId: job.id, 
        userId: job.data.userId, 
        error: error.message,
        attempts: job.attemptsMade
      });
      this.updateSessionJobStatus(job.data.sessionId, job.id!, 'failed');
    });

    this.worker.on('progress', (job: Job<BatchJobData, BatchJobResult>, progress: any) => {
      logger.debug('📊 Batch job progress', { 
        jobId: job.id, 
        progress: progress.percentage,
        stage: progress.stage
      });
    });

    this.worker.on('error', (error: Error) => {
      logger.error('❌ Worker error', { error: error.message });
    });
  }

  /**
   * Crée une nouvelle session batch
   */
  createBatchSession(userId: string): string {
    const sessionId = uuidv4();
    
    const session: BatchSession = {
      sessionId,
      userId,
      totalJobs: 0,
      completedJobs: 0,
      failedJobs: 0,
      pendingJobs: 0,
      jobs: [],
      createdAt: new Date()
    };

    this.sessions.set(sessionId, session);
    
    logger.info('📦 Batch session created', { sessionId, userId });
    
    return sessionId;
  }

  /**
   * Ajoute des jobs à une session batch
   */
  async addJobsToSession(
    sessionId: string,
    userId: string,
    isPremium: boolean,
    videoConfigs: any[]
  ): Promise<string[]> {
    const session = this.sessions.get(sessionId);
    
    if (!session) {
      throw new Error('Batch session not found');
    }

    if (session.userId !== userId) {
      throw new Error('Unauthorized access to batch session');
    }

    // Vérifier limite de jobs
    const newJobCount = videoConfigs.length;
    const currentJobCount = session.totalJobs;

    if (currentJobCount + newJobCount > MAX_JOBS_PER_SESSION) {
      throw new Error(`Maximum ${MAX_JOBS_PER_SESSION} jobs per session (current: ${currentJobCount})`);
    }

    // Créer les jobs
    const jobIds: string[] = [];
    const priority = isPremium ? 1 : 10;  // Premium = haute priorité

    for (const config of videoConfigs) {
      const jobId = uuidv4();
      
      // Ajouter à la queue BullMQ
      await this.queue.add(
        `video-render-${jobId}`,
        {
          userId,
          isPremium,
          videoConfig: config,
          templateId: config.templateId,
          priority,
          sessionId
        },
        {
          jobId,
          priority,
          attempts: isPremium ? 5 : 3  // Plus de retries pour premium
        }
      );

      // Ajouter à la session
      session.jobs.push({
        jobId,
        status: 'pending',
        progress: 0,
        createdAt: new Date()
      });

      jobIds.push(jobId);
    }

    // Mettre à jour compteurs
    session.totalJobs += newJobCount;
    session.pendingJobs += newJobCount;

    logger.info('📥 Jobs added to batch session', { 
      sessionId, 
      newJobCount, 
      totalJobs: session.totalJobs,
      isPremium 
    });

    return jobIds;
  }

  /**
   * Traite un job vidéo individuel
   */
  private async processVideoJob(job: Job<BatchJobData, BatchJobResult>): Promise<BatchJobResult> {
    const { userId, isPremium, sessionId } = job.data;

    logger.info('🎬 Processing batch video job', { 
      jobId: job.id, 
      userId, 
      isPremium,
      sessionId 
    });

    // Mettre à jour le statut
    this.updateSessionJobStatus(sessionId, job.id!, 'processing');

    try {
      // Stage 1: Validation (10%)
      await job.updateProgress({
        percentage: 10,
        stage: 'validation',
        message: 'Validating video configuration'
      });

      // Valider la config (simulé)
      await this.delay(500);

      // Stage 2: Pre-processing (30%)
      await job.updateProgress({
        percentage: 30,
        stage: 'preprocessing',
        message: 'Preparing media files'
      });

      await this.delay(1000);

      // Stage 3: Rendering (70%)
      await job.updateProgress({
        percentage: 70,
        stage: 'rendering',
        message: 'Rendering video with FFmpeg'
      });

      // Appeler FFmpeg service (à implémenter avec votre FFmpegServiceV3)
      // const result = await ffmpegServiceV3.renderVideo(videoConfig);
      await this.delay(3000);  // Simuler rendering

      // Stage 4: Post-processing (90%)
      await job.updateProgress({
        percentage: 90,
        stage: 'postprocessing',
        message: 'Finalizing video'
      });

      await this.delay(500);

      // Stage 5: Complete (100%)
      await job.updateProgress({
        percentage: 100,
        stage: 'completed',
        message: 'Video rendering completed'
      });

      const result: BatchJobResult = {
        success: true,
        videoPath: `/outputs/${userId}/${job.id}.mp4`,
        duration: 30,
        fileSize: 15728640  // 15 MB
      };

      return result;

    } catch (error) {
      logger.error('❌ Batch job processing failed', { 
        jobId: job.id, 
        error: error instanceof Error ? error.message : String(error) 
      });

      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }

  /**
   * Met à jour le statut d'un job dans la session
   */
  private updateSessionJobStatus(
    sessionId: string,
    jobId: string,
    status: 'pending' | 'processing' | 'completed' | 'failed'
  ): void {
    const session = this.sessions.get(sessionId);
    if (!session) return;

    const job = session.jobs.find(j => j.jobId === jobId);
    if (!job) return;

    const previousStatus = job.status;
    job.status = status;

    // Mettre à jour timestamps
    if (status === 'processing') {
      job.startedAt = new Date();
      session.pendingJobs--;
    } else if (status === 'completed') {
      job.completedAt = new Date();
      session.completedJobs++;
      job.progress = 100;
    } else if (status === 'failed') {
      job.completedAt = new Date();
      session.failedJobs++;
    }

    logger.debug('Job status updated', { sessionId, jobId, previousStatus, newStatus: status });
  }

  /**
   * Récupère l'état d'une session batch
   */
  async getBatchSessionStatus(sessionId: string, userId: string): Promise<BatchSession | null> {
    const session = this.sessions.get(sessionId);
    
    if (!session || session.userId !== userId) {
      return null;
    }

    // Mettre à jour les progrès des jobs en cours
    for (const job of session.jobs) {
      if (job.status === 'processing') {
        const bullJob = await this.queue.getJob(job.jobId);
        if (bullJob) {
          // BullMQ v4: progress is a property, not a method
          const progressData = bullJob.progress as any;
          if (progressData && typeof progressData === 'object') {
            job.progress = progressData.percentage || 0;
          }
        }
      }
    }

    return session;
  }

  /**
   * Récupère l'état d'un job individuel
   */
  async getJobStatus(jobId: string): Promise<any> {
    const job = await this.queue.getJob(jobId);
    
    if (!job) {
      return null;
    }

    const state = await job.getState();
    // BullMQ v4: progress is a property, not a method
    const progressData = job.progress as any;

    return {
      jobId: job.id,
      state,
      progress: progressData,
      data: job.data,
      result: job.returnvalue,
      failedReason: job.failedReason,
      attemptsMade: job.attemptsMade,
      processedOn: job.processedOn,
      finishedOn: job.finishedOn
    };
  }

  /**
   * Annule un job
   */
  async cancelJob(jobId: string, userId: string): Promise<boolean> {
    const job = await this.queue.getJob(jobId);
    
    if (!job) {
      return false;
    }

    // Vérifier que c'est le bon utilisateur
    if (job.data.userId !== userId) {
      throw new Error('Unauthorized to cancel this job');
    }

    await job.remove();
    
    // Mettre à jour la session
    const sessionId = job.data.sessionId;
    this.updateSessionJobStatus(sessionId, jobId, 'failed');

    logger.info('🚫 Job cancelled', { jobId, userId });

    return true;
  }

  /**
   * Annule toute une session batch
   */
  async cancelBatchSession(sessionId: string, userId: string): Promise<number> {
    const session = this.sessions.get(sessionId);
    
    if (!session || session.userId !== userId) {
      throw new Error('Batch session not found or unauthorized');
    }

    let cancelledCount = 0;

    for (const job of session.jobs) {
      if (job.status === 'pending' || job.status === 'processing') {
        try {
          await this.cancelJob(job.jobId, userId);
          cancelledCount++;
        } catch (error) {
          logger.error('Failed to cancel job', { jobId: job.jobId, error });
        }
      }
    }

    logger.info('🚫 Batch session cancelled', { sessionId, cancelledCount });

    return cancelledCount;
  }

  /**
   * Récupère les statistiques de la queue
   */
  async getQueueStats(): Promise<any> {
    const [waiting, active, completed, failed, delayed] = await Promise.all([
      this.queue.getWaitingCount(),
      this.queue.getActiveCount(),
      this.queue.getCompletedCount(),
      this.queue.getFailedCount(),
      this.queue.getDelayedCount()
    ]);

    return {
      waiting,
      active,
      completed,
      failed,
      delayed,
      total: waiting + active + completed + failed + delayed
    };
  }

  /**
   * Nettoie les anciennes sessions (> 24h)
   */
  async cleanupOldSessions(): Promise<number> {
    const now = Date.now();
    const maxAge = 24 * 60 * 60 * 1000;  // 24 heures
    let cleanedCount = 0;

    for (const [sessionId, session] of this.sessions.entries()) {
      const age = now - session.createdAt.getTime();
      
      if (age > maxAge) {
        this.sessions.delete(sessionId);
        cleanedCount++;
      }
    }

    if (cleanedCount > 0) {
      logger.info('🧹 Old batch sessions cleaned', { cleanedCount });
    }

    return cleanedCount;
  }

  /**
   * Utilitaire: delay
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Ferme proprement le service
   */
  async close(): Promise<void> {
    await this.worker.close();
    await this.queue.close();
    await this.queueEvents.close();
    await redisConnection.quit();
    logger.info('BatchService closed');
  }
}

export const batchService = new BatchService();
