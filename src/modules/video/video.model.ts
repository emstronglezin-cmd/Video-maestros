import { Firestore } from 'firebase-admin/firestore';
import { getFirestore } from 'firebase-admin/firestore';
import { z } from 'zod';

/**
 * Statut d'une vidéo
 */
export enum VideoStatus {
  QUEUED = 'queued',
  PROCESSING = 'processing',
  COMPLETED = 'completed',
  FAILED = 'failed',
}

/**
 * Schéma de validation vidéo
 */
export const VideoSchema = z.object({
  id: z.string(),
  userId: z.string(),
  jobId: z.string(),
  title: z.string().optional(),
  description: z.string().optional(),
  status: z.nativeEnum(VideoStatus),
  progress: z.number().min(0).max(100).default(0),
  inputFiles: z.array(z.string()),
  outputUrl: z.string().optional(),
  thumbnailUrl: z.string().optional(),
  duration: z.number().optional(), // en secondes
  resolution: z.string().optional(), // ex: "1920x1080"
  fileSize: z.number().optional(), // en bytes
  error: z.string().optional(),
  createdAt: z.date().or(z.string()),
  updatedAt: z.date().or(z.string()),
  completedAt: z.date().or(z.string()).optional(),
});

export type Video = z.infer<typeof VideoSchema>;

/**
 * Interface pour la création de vidéo
 */
export interface CreateVideoInput {
  userId: string;
  jobId: string;
  title?: string;
  description?: string;
  inputFiles: string[];
}

/**
 * Interface pour la mise à jour de vidéo
 */
export interface UpdateVideoInput {
  status?: VideoStatus;
  progress?: number;
  outputUrl?: string;
  thumbnailUrl?: string;
  duration?: number;
  resolution?: string;
  fileSize?: number;
  error?: string;
  title?: string;
  description?: string;
}

/**
 * Modèle de gestion des vidéos dans Firestore
 */
export class VideoModel {
  private db: Firestore;
  private collection: string = 'videos';

  constructor() {
    this.db = getFirestore();
  }

  /**
   * Crée une nouvelle vidéo
   */
  async create(input: CreateVideoInput): Promise<Video> {
    const now = new Date();
    const videoRef = this.db.collection(this.collection).doc();

    const videoData: Video = {
      id: videoRef.id,
      userId: input.userId,
      jobId: input.jobId,
      title: input.title,
      description: input.description,
      status: VideoStatus.QUEUED,
      progress: 0,
      inputFiles: input.inputFiles,
      createdAt: now,
      updatedAt: now,
    };

    await videoRef.set(videoData);
    return videoData;
  }

  /**
   * Trouve une vidéo par ID
   */
  async findById(videoId: string): Promise<Video | null> {
    const doc = await this.db.collection(this.collection).doc(videoId).get();
    if (!doc.exists) {
      return null;
    }
    return doc.data() as Video;
  }

  /**
   * Trouve une vidéo par jobId
   */
  async findByJobId(jobId: string): Promise<Video | null> {
    const snapshot = await this.db
      .collection(this.collection)
      .where('jobId', '==', jobId)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return null;
    }

    return snapshot.docs[0].data() as Video;
  }

  /**
   * Récupère toutes les vidéos d'un utilisateur
   */
  async findByUserId(userId: string, limit: number = 50): Promise<Video[]> {
    const snapshot = await this.db
      .collection(this.collection)
      .where('userId', '==', userId)
      .limit(limit)
      .get();

    if (snapshot.empty) {
      return [];
    }

    // Sort in memory by createdAt (descending)
    const videos = snapshot.docs.map(doc => doc.data() as Video);
    videos.sort((a, b) => {
      const dateA = new Date(a.createdAt).getTime();
      const dateB = new Date(b.createdAt).getTime();
      return dateB - dateA;
    });

    return videos;
  }

  /**
   * Récupère les vidéos d'un utilisateur avec un statut spécifique
   */
  async findByUserIdAndStatus(
    userId: string,
    status: VideoStatus,
    limit: number = 50
  ): Promise<Video[]> {
    const snapshot = await this.db
      .collection(this.collection)
      .where('userId', '==', userId)
      .where('status', '==', status)
      .limit(limit)
      .get();

    if (snapshot.empty) {
      return [];
    }

    // Sort in memory
    const videos = snapshot.docs.map(doc => doc.data() as Video);
    videos.sort((a, b) => {
      const dateA = new Date(a.createdAt).getTime();
      const dateB = new Date(b.createdAt).getTime();
      return dateB - dateA;
    });

    return videos;
  }

  /**
   * Met à jour une vidéo
   */
  async update(videoId: string, input: UpdateVideoInput): Promise<Video> {
    const video = await this.findById(videoId);
    if (!video) {
      throw new Error('Video not found');
    }

    const updateData: any = {
      ...input,
      updatedAt: new Date(),
    };

    // Si le statut passe à COMPLETED, ajouter completedAt
    if (input.status === VideoStatus.COMPLETED && video.status !== VideoStatus.COMPLETED) {
      updateData.completedAt = new Date();
    }

    await this.db.collection(this.collection).doc(videoId).update(updateData);

    return await this.findById(videoId) as Video;
  }

  /**
   * Met à jour le statut et la progression
   */
  async updateProgress(videoId: string, status: VideoStatus, progress: number): Promise<void> {
    await this.update(videoId, { status, progress });
  }

  /**
   * Marque une vidéo comme échouée
   */
  async markAsFailed(videoId: string, error: string): Promise<void> {
    await this.update(videoId, {
      status: VideoStatus.FAILED,
      error,
    });
  }

  /**
   * Marque une vidéo comme complétée
   */
  async markAsCompleted(
    videoId: string,
    outputUrl: string,
    metadata?: {
      duration?: number;
      resolution?: string;
      fileSize?: number;
      thumbnailUrl?: string;
    }
  ): Promise<void> {
    await this.update(videoId, {
      status: VideoStatus.COMPLETED,
      progress: 100,
      outputUrl,
      ...metadata,
    });
  }

  /**
   * Supprime une vidéo
   */
  async delete(videoId: string): Promise<void> {
    await this.db.collection(this.collection).doc(videoId).delete();
  }

  /**
   * Compte le nombre de vidéos d'un utilisateur
   */
  async countByUserId(userId: string): Promise<number> {
    const snapshot = await this.db
      .collection(this.collection)
      .where('userId', '==', userId)
      .count()
      .get();

    return snapshot.data().count;
  }

  /**
   * Compte le nombre de vidéos d'un utilisateur par statut
   */
  async countByUserIdAndStatus(userId: string, status: VideoStatus): Promise<number> {
    const snapshot = await this.db
      .collection(this.collection)
      .where('userId', '==', userId)
      .where('status', '==', status)
      .count()
      .get();

    return snapshot.data().count;
  }
}
