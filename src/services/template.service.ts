/**
 * TemplateService - Gestion des templates viraux TikTok/Reels/Shorts
 * Templates prédéfinis 9:16, durées max, styles transitions, positions sous-titres
 * Free vs Premium templates
 */

import { logger } from '../utils/logger';

export type TemplatePlatform = 'tiktok' | 'reels' | 'shorts' | 'universal';
export type TransitionStyle = 'cut' | 'fade' | 'dissolve' | 'wipe' | 'zoom' | 'slide';
export type CaptionPosition = 'top' | 'center' | 'bottom' | 'top-center' | 'bottom-center';

export interface TemplateConfig {
  id: string;
  name: string;
  description: string;
  platform: TemplatePlatform;
  isPremium: boolean;
  
  // Caractéristiques vidéo
  aspectRatio: string;        // "9:16" pour vertical
  width: number;              // 1080
  height: number;             // 1920
  maxDuration: number;        // secondes (15, 30, 60, 180)
  fps: number;                // 24, 30, 60
  
  // Style visuel
  transitions: {
    style: TransitionStyle;
    duration: number;         // secondes
    frequency: 'every-clip' | 'every-2-clips' | 'custom';
  };
  
  // Sous-titres
  captions: {
    enabled: boolean;
    position: CaptionPosition;
    fontSize: number;
    fontName: string;
    primaryColor: string;
    outlineColor: string;
    outlineWidth: number;
    animation: 'none' | 'fade' | 'karaoke';
  };
  
  // Audio
  audio: {
    enableBackgroundMusic: boolean;
    backgroundMusicVolume: number;  // 0.0 - 1.0
    enableVoiceover: boolean;
    voiceoverVolume: number;
  };
  
  // Effets spéciaux
  effects: {
    colorGrading?: string;      // "vibrant", "cinematic", "vintage", "none"
    vignette: boolean;
    blur: boolean;
    speedRamp: boolean;         // Ralentis/accélérés
  };
  
  // Métadonnées
  tags: string[];
  category: string;
  trending: boolean;
  createdAt: Date;
}

export class TemplateService {
  private templates: Map<string, TemplateConfig>;

  constructor() {
    this.templates = new Map();
    this.initializeDefaultTemplates();
  }

  /**
   * Initialise les templates par défaut
   */
  private initializeDefaultTemplates(): void {
    const defaultTemplates: TemplateConfig[] = [
      // FREE TEMPLATES
      {
        id: 'tiktok-basic-15s',
        name: 'TikTok Basic 15s',
        description: 'Template TikTok basique 15 secondes, transitions simples',
        platform: 'tiktok',
        isPremium: false,
        aspectRatio: '9:16',
        width: 1080,
        height: 1920,
        maxDuration: 15,
        fps: 30,
        transitions: {
          style: 'fade',
          duration: 0.3,
          frequency: 'every-clip'
        },
        captions: {
          enabled: true,
          position: 'bottom-center',
          fontSize: 48,
          fontName: 'Arial',
          primaryColor: '#FFFFFF',
          outlineColor: '#000000',
          outlineWidth: 3,
          animation: 'none'
        },
        audio: {
          enableBackgroundMusic: false,
          backgroundMusicVolume: 0.3,
          enableVoiceover: true,
          voiceoverVolume: 1.0
        },
        effects: {
          colorGrading: 'none',
          vignette: false,
          blur: false,
          speedRamp: false
        },
        tags: ['basic', 'free', 'beginner'],
        category: 'standard',
        trending: false,
        createdAt: new Date()
      },
      {
        id: 'reels-simple-30s',
        name: 'Reels Simple 30s',
        description: 'Template Instagram Reels simple 30 secondes',
        platform: 'reels',
        isPremium: false,
        aspectRatio: '9:16',
        width: 1080,
        height: 1920,
        maxDuration: 30,
        fps: 30,
        transitions: {
          style: 'cut',
          duration: 0,
          frequency: 'every-clip'
        },
        captions: {
          enabled: true,
          position: 'center',
          fontSize: 56,
          fontName: 'Impact',
          primaryColor: '#FFFFFF',
          outlineColor: '#000000',
          outlineWidth: 4,
          animation: 'fade'
        },
        audio: {
          enableBackgroundMusic: true,
          backgroundMusicVolume: 0.4,
          enableVoiceover: true,
          voiceoverVolume: 0.8
        },
        effects: {
          colorGrading: 'vibrant',
          vignette: false,
          blur: false,
          speedRamp: false
        },
        tags: ['reels', 'free', 'instagram'],
        category: 'social',
        trending: true,
        createdAt: new Date()
      },
      {
        id: 'shorts-quickfire-60s',
        name: 'Shorts Quickfire 60s',
        description: 'Template YouTube Shorts rapide 60 secondes',
        platform: 'shorts',
        isPremium: false,
        aspectRatio: '9:16',
        width: 1080,
        height: 1920,
        maxDuration: 60,
        fps: 30,
        transitions: {
          style: 'dissolve',
          duration: 0.5,
          frequency: 'every-2-clips'
        },
        captions: {
          enabled: true,
          position: 'top-center',
          fontSize: 52,
          fontName: 'Arial',
          primaryColor: '#FFFF00',
          outlineColor: '#000000',
          outlineWidth: 3,
          animation: 'none'
        },
        audio: {
          enableBackgroundMusic: true,
          backgroundMusicVolume: 0.3,
          enableVoiceover: true,
          voiceoverVolume: 1.0
        },
        effects: {
          colorGrading: 'none',
          vignette: false,
          blur: false,
          speedRamp: false
        },
        tags: ['shorts', 'free', 'youtube'],
        category: 'educational',
        trending: true,
        createdAt: new Date()
      },

      // PREMIUM TEMPLATES
      {
        id: 'tiktok-viral-pro-60s',
        name: 'TikTok Viral Pro 60s',
        description: 'Template TikTok viral premium avec effets avancés',
        platform: 'tiktok',
        isPremium: true,
        aspectRatio: '9:16',
        width: 1080,
        height: 1920,
        maxDuration: 60,
        fps: 60,
        transitions: {
          style: 'zoom',
          duration: 0.8,
          frequency: 'every-clip'
        },
        captions: {
          enabled: true,
          position: 'bottom-center',
          fontSize: 64,
          fontName: 'Impact',
          primaryColor: '#FF00FF',
          outlineColor: '#000000',
          outlineWidth: 5,
          animation: 'karaoke'
        },
        audio: {
          enableBackgroundMusic: true,
          backgroundMusicVolume: 0.5,
          enableVoiceover: true,
          voiceoverVolume: 0.9
        },
        effects: {
          colorGrading: 'vibrant',
          vignette: true,
          blur: false,
          speedRamp: true
        },
        tags: ['premium', 'viral', 'tiktok', 'trending'],
        category: 'viral',
        trending: true,
        createdAt: new Date()
      },
      {
        id: 'reels-cinematic-90s',
        name: 'Reels Cinematic 90s',
        description: 'Template Instagram Reels cinématique premium',
        platform: 'reels',
        isPremium: true,
        aspectRatio: '9:16',
        width: 1080,
        height: 1920,
        maxDuration: 90,
        fps: 60,
        transitions: {
          style: 'slide',
          duration: 1.0,
          frequency: 'every-clip'
        },
        captions: {
          enabled: true,
          position: 'bottom',
          fontSize: 48,
          fontName: 'Cinzel',
          primaryColor: '#FFFFFF',
          outlineColor: '#1A1A1A',
          outlineWidth: 2,
          animation: 'fade'
        },
        audio: {
          enableBackgroundMusic: true,
          backgroundMusicVolume: 0.6,
          enableVoiceover: true,
          voiceoverVolume: 1.0
        },
        effects: {
          colorGrading: 'cinematic',
          vignette: true,
          blur: true,
          speedRamp: true
        },
        tags: ['premium', 'cinematic', 'reels', 'professional'],
        category: 'professional',
        trending: false,
        createdAt: new Date()
      },
      {
        id: 'shorts-education-180s',
        name: 'Shorts Education 3min',
        description: 'Template YouTube Shorts éducatif premium 3 minutes',
        platform: 'shorts',
        isPremium: true,
        aspectRatio: '9:16',
        width: 1080,
        height: 1920,
        maxDuration: 180,
        fps: 30,
        transitions: {
          style: 'wipe',
          duration: 0.6,
          frequency: 'every-2-clips'
        },
        captions: {
          enabled: true,
          position: 'top',
          fontSize: 56,
          fontName: 'Roboto',
          primaryColor: '#00FF00',
          outlineColor: '#000000',
          outlineWidth: 4,
          animation: 'fade'
        },
        audio: {
          enableBackgroundMusic: true,
          backgroundMusicVolume: 0.2,
          enableVoiceover: true,
          voiceoverVolume: 1.0
        },
        effects: {
          colorGrading: 'none',
          vignette: false,
          blur: false,
          speedRamp: false
        },
        tags: ['premium', 'education', 'shorts', 'long-form'],
        category: 'educational',
        trending: false,
        createdAt: new Date()
      },
      {
        id: 'universal-storytelling-120s',
        name: 'Universal Storytelling 2min',
        description: 'Template universel storytelling premium multi-plateforme',
        platform: 'universal',
        isPremium: true,
        aspectRatio: '9:16',
        width: 1080,
        height: 1920,
        maxDuration: 120,
        fps: 30,
        transitions: {
          style: 'fade',
          duration: 1.0,
          frequency: 'every-clip'
        },
        captions: {
          enabled: true,
          position: 'bottom-center',
          fontSize: 52,
          fontName: 'Georgia',
          primaryColor: '#FFFFFF',
          outlineColor: '#333333',
          outlineWidth: 3,
          animation: 'fade'
        },
        audio: {
          enableBackgroundMusic: true,
          backgroundMusicVolume: 0.4,
          enableVoiceover: true,
          voiceoverVolume: 1.0
        },
        effects: {
          colorGrading: 'vintage',
          vignette: true,
          blur: false,
          speedRamp: false
        },
        tags: ['premium', 'storytelling', 'universal', 'narrative'],
        category: 'storytelling',
        trending: true,
        createdAt: new Date()
      }
    ];

    // Charger les templates dans la Map
    defaultTemplates.forEach(template => {
      this.templates.set(template.id, template);
    });

    logger.info(`✅ Initialized ${defaultTemplates.length} default templates`, {
      free: defaultTemplates.filter(t => !t.isPremium).length,
      premium: defaultTemplates.filter(t => t.isPremium).length
    });
  }

  /**
   * Récupère tous les templates (filtrés par premium)
   */
  getAllTemplates(userIsPremium: boolean): TemplateConfig[] {
    const allTemplates = Array.from(this.templates.values());
    
    if (userIsPremium) {
      return allTemplates;
    }
    
    // Utilisateurs free voient seulement les templates free
    return allTemplates.filter(t => !t.isPremium);
  }

  /**
   * Récupère un template par ID
   */
  getTemplateById(templateId: string, userIsPremium: boolean): TemplateConfig | null {
    const template = this.templates.get(templateId);
    
    if (!template) {
      return null;
    }
    
    // Vérifier accès premium
    if (template.isPremium && !userIsPremium) {
      throw new Error('Premium template requires premium subscription');
    }
    
    return template;
  }

  /**
   * Récupère templates par plateforme
   */
  getTemplatesByPlatform(platform: TemplatePlatform, userIsPremium: boolean): TemplateConfig[] {
    return this.getAllTemplates(userIsPremium).filter(t => 
      t.platform === platform || t.platform === 'universal'
    );
  }

  /**
   * Récupère templates trending
   */
  getTrendingTemplates(userIsPremium: boolean): TemplateConfig[] {
    return this.getAllTemplates(userIsPremium)
      .filter(t => t.trending)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  /**
   * Récupère templates par catégorie
   */
  getTemplatesByCategory(category: string, userIsPremium: boolean): TemplateConfig[] {
    return this.getAllTemplates(userIsPremium).filter(t => t.category === category);
  }

  /**
   * Valide la configuration utilisateur contre un template
   */
  validateUserConfigAgainstTemplate(
    templateId: string,
    videoDuration: number,
    clipCount: number,
    userIsPremium: boolean
  ): { valid: boolean; errors: string[] } {
    const template = this.getTemplateById(templateId, userIsPremium);
    const errors: string[] = [];

    if (!template) {
      errors.push('Template not found');
      return { valid: false, errors };
    }

    // Vérifier durée max
    if (videoDuration > template.maxDuration) {
      errors.push(`Video duration ${videoDuration}s exceeds template max ${template.maxDuration}s`);
    }

    // Vérifier nombre de clips (optionnel)
    if (clipCount < 1) {
      errors.push('At least one clip is required');
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }

  /**
   * Applique les paramètres du template à une configuration vidéo
   */
  applyTemplateToVideoConfig(templateId: string, baseConfig: any, userIsPremium: boolean): any {
    const template = this.getTemplateById(templateId, userIsPremium);
    
    if (!template) {
      throw new Error('Template not found');
    }

    logger.info('Applying template to video config', { templateId, templateName: template.name });

    return {
      ...baseConfig,
      resolution: {
        width: template.width,
        height: template.height
      },
      aspectRatio: template.aspectRatio,
      fps: template.fps,
      maxDuration: template.maxDuration,
      transitions: template.transitions,
      captions: template.captions,
      audio: template.audio,
      effects: template.effects,
      templateId: template.id,
      templateName: template.name
    };
  }

  /**
   * Crée un template personnalisé (admin only)
   */
  createCustomTemplate(config: Omit<TemplateConfig, 'id' | 'createdAt'>): TemplateConfig {
    const newTemplate: TemplateConfig = {
      ...config,
      id: `custom-${Date.now()}-${Math.random().toString(36).substring(7)}`,
      createdAt: new Date()
    };

    this.templates.set(newTemplate.id, newTemplate);
    
    logger.info('Custom template created', { templateId: newTemplate.id, name: newTemplate.name });
    
    return newTemplate;
  }

  /**
   * Met à jour un template existant (admin only)
   */
  updateTemplate(templateId: string, updates: Partial<TemplateConfig>): TemplateConfig | null {
    const existing = this.templates.get(templateId);
    
    if (!existing) {
      return null;
    }

    const updated: TemplateConfig = {
      ...existing,
      ...updates,
      id: existing.id,  // Ne pas changer l'ID
      createdAt: existing.createdAt  // Ne pas changer la date création
    };

    this.templates.set(templateId, updated);
    
    logger.info('Template updated', { templateId, name: updated.name });
    
    return updated;
  }

  /**
   * Supprime un template (admin only)
   */
  deleteTemplate(templateId: string): boolean {
    const deleted = this.templates.delete(templateId);
    
    if (deleted) {
      logger.info('Template deleted', { templateId });
    }
    
    return deleted;
  }

  /**
   * Statistiques des templates
   */
  getTemplateStats(): {
    total: number;
    free: number;
    premium: number;
    byPlatform: Record<TemplatePlatform, number>;
    trending: number;
  } {
    const all = Array.from(this.templates.values());
    
    return {
      total: all.length,
      free: all.filter(t => !t.isPremium).length,
      premium: all.filter(t => t.isPremium).length,
      byPlatform: {
        tiktok: all.filter(t => t.platform === 'tiktok').length,
        reels: all.filter(t => t.platform === 'reels').length,
        shorts: all.filter(t => t.platform === 'shorts').length,
        universal: all.filter(t => t.platform === 'universal').length
      },
      trending: all.filter(t => t.trending).length
    };
  }
}

export const templateService = new TemplateService();
