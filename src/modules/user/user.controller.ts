import { Request, Response, Router } from 'express';
import { UserModel, CreateUserInput, UpdateUserInput } from './user.model';
import { logger } from '../../utils/logger';
import { z } from 'zod';

/**
 * Schéma de validation pour la création d'utilisateur
 */
const CreateUserSchema = z.object({
  username: z.string().min(3).max(30).regex(/^[a-zA-Z0-9_]+$/, {
    message: 'Username must contain only letters, numbers and underscore',
  }),
  displayName: z.string().optional(),
  photoURL: z.string().url().optional(),
});

/**
 * Schéma de validation pour la mise à jour d'utilisateur
 */
const UpdateUserSchema = z.object({
  username: z.string().min(3).max(30).regex(/^[a-zA-Z0-9_]+$/).optional(),
  displayName: z.string().optional(),
  photoURL: z.string().url().optional(),
});

/**
 * Schéma de validation pour la vérification de username
 */
const CheckUsernameSchema = z.object({
  username: z.string().min(3).max(30),
});

/**
 * Contrôleur pour la gestion des utilisateurs
 */
export class UserController {
  private router: Router;
  private userModel: UserModel;

  constructor() {
    this.router = Router();
    this.userModel = new UserModel();
    this.setupRoutes();
  }

  private setupRoutes(): void {
    // GET /me - Récupérer le profil de l'utilisateur connecté
    this.router.get('/me', this.getProfile.bind(this));

    // POST /setup - Configuration initiale du profil (username)
    this.router.post('/setup', this.setupProfile.bind(this));

    // PUT /me - Mettre à jour le profil
    this.router.put('/me', this.updateProfile.bind(this));

    // GET /check-username/:username - Vérifier si un username est disponible
    this.router.get('/check-username/:username', this.checkUsername.bind(this));
  }

  /**
   * GET /me - Récupérer le profil de l'utilisateur connecté
   */
  private async getProfile(req: Request, res: Response): Promise<void> {
    try {
      const user = (req as any).user;
      if (!user || !user.uid) {
        res.status(401).json({
          success: false,
          error: 'Unauthorized',
        });
        return;
      }

      const profile = await this.userModel.findById(user.uid);

      if (!profile) {
        // Utilisateur authentifié mais pas de profil créé
        res.status(404).json({
          success: false,
          error: 'Profile not found',
          needsSetup: true,
        });
        return;
      }

      res.json({
        success: true,
        data: profile,
      });
    } catch (error: any) {
      logger.error('❌ Get profile error:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Failed to get profile',
      });
    }
  }

  /**
   * POST /setup - Configuration initiale du profil (username)
   */
  private async setupProfile(req: Request, res: Response): Promise<void> {
    try {
      const user = (req as any).user;
      if (!user || !user.uid || !user.email) {
        res.status(401).json({
          success: false,
          error: 'Unauthorized',
        });
        return;
      }

      // Validation des données
      const validation = CreateUserSchema.safeParse(req.body);
      if (!validation.success) {
        res.status(400).json({
          success: false,
          error: 'Invalid input',
          details: validation.error.errors,
        });
        return;
      }

      const input: CreateUserInput = {
        uid: user.uid,
        email: user.email,
        username: validation.data.username,
        displayName: validation.data.displayName,
        photoURL: validation.data.photoURL,
      };

      const profile = await this.userModel.create(input);

      logger.info(`✅ User profile created: ${profile.username} (${profile.uid})`);

      res.status(201).json({
        success: true,
        data: profile,
      });
    } catch (error: any) {
      logger.error('❌ Setup profile error:', error);

      if (error.message === 'Username already taken') {
        res.status(409).json({
          success: false,
          error: 'Username already taken',
        });
        return;
      }

      if (error.message === 'User already exists') {
        res.status(409).json({
          success: false,
          error: 'Profile already exists',
        });
        return;
      }

      res.status(500).json({
        success: false,
        error: error.message || 'Failed to setup profile',
      });
    }
  }

  /**
   * PUT /me - Mettre à jour le profil
   */
  private async updateProfile(req: Request, res: Response): Promise<void> {
    try {
      const user = (req as any).user;
      if (!user || !user.uid) {
        res.status(401).json({
          success: false,
          error: 'Unauthorized',
        });
        return;
      }

      // Validation des données
      const validation = UpdateUserSchema.safeParse(req.body);
      if (!validation.success) {
        res.status(400).json({
          success: false,
          error: 'Invalid input',
          details: validation.error.errors,
        });
        return;
      }

      const input: UpdateUserInput = validation.data;
      const updatedProfile = await this.userModel.update(user.uid, input);

      logger.info(`✅ User profile updated: ${updatedProfile.username} (${updatedProfile.uid})`);

      res.json({
        success: true,
        data: updatedProfile,
      });
    } catch (error: any) {
      logger.error('❌ Update profile error:', error);

      if (error.message === 'User not found') {
        res.status(404).json({
          success: false,
          error: 'Profile not found',
        });
        return;
      }

      if (error.message === 'Username already taken') {
        res.status(409).json({
          success: false,
          error: 'Username already taken',
        });
        return;
      }

      res.status(500).json({
        success: false,
        error: error.message || 'Failed to update profile',
      });
    }
  }

  /**
   * GET /check-username/:username - Vérifier si un username est disponible
   */
  private async checkUsername(req: Request, res: Response): Promise<void> {
    try {
      const { username } = req.params;

      // Validation
      const validation = CheckUsernameSchema.safeParse({ username });
      if (!validation.success) {
        res.status(400).json({
          success: false,
          error: 'Invalid username format',
          details: validation.error.errors,
        });
        return;
      }

      const isAvailable = await this.userModel.isUsernameAvailable(username);

      res.json({
        success: true,
        data: {
          username,
          available: isAvailable,
        },
      });
    } catch (error: any) {
      logger.error('❌ Check username error:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Failed to check username',
      });
    }
  }

  public getRouter(): Router {
    return this.router;
  }
}
