import { Router, Request, Response } from 'express';
import { getVideoService } from './video.service';
import { VideoModel } from './video.model';
import { parseScriptWithOllama } from '../ai/script.parser';
import { timelineSchema } from './timeline.schema';
import { logger } from '../../utils/logger';
import { AuthenticatedRequest } from '../../middleware/firebase.middleware';
import path from 'path';

export class VideoController {
  private router: Router;
  private videoService = getVideoService();
  private videoModel: VideoModel;

  constructor() {
    this.router = Router();
    this.videoModel = new VideoModel();
    this.setupRoutes();
  }

  private setupRoutes(): void {
    this.router.post('/parse-script', this.parseScript.bind(this));
    this.router.post('/create', this.createVideo.bind(this));
    this.router.get('/status/:id', this.getStatus.bind(this));
    this.router.get('/list', this.listVideos.bind(this));
    this.router.get('/stats', this.getUserStats.bind(this));
    this.router.get('/queue-stats', this.getQueueStats.bind(this));
  }

  /**
   * POST /api/video/parse-script
   * Parse script with Ollama and return timeline JSON
   */
  private async parseScript(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const { script } = req.body;

      if (!script || typeof script !== 'string') {
        res.status(400).json({
          success: false,
          error: 'Script is required and must be a string',
        });
        return;
      }

      if (!req.user) {
        res.status(401).json({
          success: false,
          error: 'Authentication required',
        });
        return;
      }

      logger.info(`📝 Parsing script for user: ${req.user.uid}`);

      // Call Ollama to parse script
      const timeline = await parseScriptWithOllama(script);

      // Validate with Zod
      const validatedTimeline = timelineSchema.parse(timeline);

      logger.info(`✅ Script parsed successfully for user: ${req.user.uid}`);

      res.json({
        success: true,
        data: {
          timeline: validatedTimeline,
        },
      });
    } catch (error: any) {
      logger.error('❌ Script parsing failed:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Failed to parse script',
      });
    }
  }

  /**
   * POST /api/video/create
   * Create video from timeline
   */
  private async createVideo(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const { timeline } = req.body;

      if (!timeline) {
        res.status(400).json({
          success: false,
          error: 'Timeline is required',
        });
        return;
      }

      if (!req.user) {
        res.status(401).json({
          success: false,
          error: 'Authentication required',
        });
        return;
      }

      // Validate timeline with Zod
      const validatedTimeline = timelineSchema.parse(timeline);

      logger.info(`🎬 Creating video for user: ${req.user.uid} (premium: ${req.user.isPremium})`);

      // Create video
      const result = await this.videoService.createVideo({
        userId: req.user.uid,
        timeline: validatedTimeline,
        uploadDir: process.env.UPLOAD_DIR || path.join(process.cwd(), 'uploads'),
        outputDir: process.env.OUTPUT_DIR || path.join(process.cwd(), 'outputs'),
      });

      logger.info(`✅ Video job created: ${result.jobId} for user: ${req.user.uid}`);

      res.json({
        success: true,
        data: result,
      });
    } catch (error: any) {
      logger.error('❌ Video creation failed:', error);

      // Handle quota errors with specific message
      if (error.message.includes('quota') || error.message.includes('autorisé')) {
        res.status(403).json({
          success: false,
          error: error.message,
        });
        return;
      }

      res.status(500).json({
        success: false,
        error: error.message || 'Failed to create video',
      });
    }
  }

  /**
   * GET /api/video/status/:id
   * Get video job status
   */
  private async getStatus(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const { id } = req.params;

      if (!id) {
        res.status(400).json({
          success: false,
          error: 'Job ID is required',
        });
        return;
      }

      const status = await this.videoService.getJobStatus(id);

      if (!status) {
        res.status(404).json({
          success: false,
          error: 'Job not found',
        });
        return;
      }

      res.json({
        success: true,
        data: status,
      });
    } catch (error: any) {
      logger.error('❌ Failed to get status:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Failed to get status',
      });
    }
  }

  /**
   * GET /api/video/list
   * List all videos for the authenticated user
   */
  private async listVideos(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      if (!req.user) {
        res.status(401).json({
          success: false,
          error: 'Authentication required',
        });
        return;
      }

      const videos = await this.videoModel.findByUserId(req.user.uid);

      res.json({
        success: true,
        data: {
          videos,
          count: videos.length,
        },
      });
    } catch (error: any) {
      logger.error('❌ Failed to list videos:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Failed to list videos',
      });
    }
  }

  /**
   * GET /api/video/stats
   * Get user stats (exports, limits, etc.)
   */
  private async getUserStats(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      if (!req.user) {
        res.status(401).json({
          success: false,
          error: 'Authentication required',
        });
        return;
      }

      const stats = await this.videoService.getUserStats(req.user.uid);
      const totalVideos = await this.videoModel.countByUserId(req.user.uid);

      res.json({
        success: true,
        data: {
          ...stats,
          isPremium: req.user.isPremium,
          totalVideos,
        },
      });
    } catch (error: any) {
      logger.error('❌ Failed to get user stats:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Failed to get stats',
      });
    }
  }

  /**
   * GET /api/video/queue-stats
   * Get render queue statistics
   */
  private async getQueueStats(_req: Request, res: Response): Promise<void> {
    try {
      const stats = await this.videoService.getQueueStats();

      res.json({
        success: true,
        data: stats,
      });
    } catch (error: any) {
      logger.error('❌ Failed to get queue stats:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Failed to get queue stats',
      });
    }
  }

  public getRouter(): Router {
    return this.router;
  }
}
