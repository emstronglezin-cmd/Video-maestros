import { Timeline } from './timeline.schema';
import { getRenderQueue } from '../../queue/render.queue';
import { getSubscriptionManager } from '../subscription/subscription.manager';
import { v4 as uuidv4 } from 'uuid';

/**
 * Requête de création de vidéo
 */
export interface CreateVideoRequest {
  userId: string;
  timeline: Timeline;
  uploadDir: string;
  outputDir: string;
}

/**
 * Réponse de création de vidéo
 */
export interface CreateVideoResponse {
  jobId: string;
  message: string;
}

/**
 * Statut d'un job
 */
export interface JobStatusResponse {
  id: string;
  state: string;
  progress: number;
  result?: {
    outputPath: string;
    duration: number;
    fileSize: number;
  };
  error?: string;
}

/**
 * Service de gestion vidéo
 */
export class VideoService {
  /**
   * Crée une nouvelle vidéo
   */
  async createVideo(request: CreateVideoRequest): Promise<CreateVideoResponse> {
    const { userId, timeline, uploadDir, outputDir } = request;

    // Vérifie les quotas
    const subManager = getSubscriptionManager();
    const canExport = await subManager.canExport(userId);

    if (!canExport.allowed) {
      throw new Error(canExport.reason || 'Export non autorisé');
    }

    // Vérifie la résolution
    const resolutionAllowed = await subManager.isResolutionAllowed(
      userId,
      timeline.resolution || '1080'
    );

    if (!resolutionAllowed) {
      const limits = await subManager.getUserLimits(userId);
      throw new Error(
        `Résolution ${timeline.resolution}p non autorisée. Maximum : ${limits.maxResolution}p`
      );
    }

    // Génère un ID de job unique
    const jobId = uuidv4();

    // Ajoute le job à la queue
    const renderQueue = getRenderQueue();
    await renderQueue.addRenderJob({
      jobId,
      timeline,
      uploadDir,
      outputDir,
      userId
    });

    // Enregistre l'export
    await subManager.recordExport(userId);

    return {
      jobId,
      message: 'Vidéo en cours de création'
    };
  }

  /**
   * Récupère le statut d'un job
   */
  async getJobStatus(jobId: string): Promise<JobStatusResponse | null> {
    const renderQueue = getRenderQueue();
    const status = await renderQueue.getJobStatus(jobId);

    if (!status) {
      return null;
    }

    return {
      id: status.id,
      state: status.state,
      progress: status.progress || 0,
      result: status.returnvalue,
      error: status.failedReason
    };
  }

  /**
   * Récupère les stats utilisateur
   */
  async getUserStats(userId: string) {
    const subManager = getSubscriptionManager();
    const tier = await subManager.getUserTier(userId);
    const limits = await subManager.getUserLimits(userId);
    const todayExports = await subManager.getTodayExportCount(userId);

    return {
      tier,
      limits,
      todayExports,
      remainingExports: limits.dailyExports === -1 
        ? 'illimité' 
        : limits.dailyExports - todayExports
    };
  }

  /**
   * Récupère les stats de la queue
   */
  async getQueueStats() {
    const renderQueue = getRenderQueue();
    return renderQueue.getStats();
  }
}

// Singleton
let videoServiceInstance: VideoService | null = null;

export function getVideoService(): VideoService {
  if (!videoServiceInstance) {
    videoServiceInstance = new VideoService();
  }
  return videoServiceInstance;
}
