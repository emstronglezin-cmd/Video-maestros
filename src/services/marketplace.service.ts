/**
 * MarketplaceService - Service de marketplace d'effets et packs premium
 * Gestion packs transitions, overlays, sons vendus individuellement
 * Stockage serveur, téléchargement à la demande
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { logger } from '../utils/logger';

export type EffectType = 'transition' | 'overlay' | 'sound' | 'filter' | 'sticker';
export type EffectCategory = 'viral' | 'cinematic' | 'corporate' | 'fun' | 'music' | 'nature' | 'retro';

export interface Effect {
  id: string;
  name: string;
  description: string;
  type: EffectType;
  category: EffectCategory;
  previewUrl: string;
  filePath: string;
  fileSize: number;
  duration?: number;  // Pour transitions et sons
  isPremium: boolean;
  price: number;      // En centimes (0 = gratuit)
  tags: string[];
  downloads: number;
  rating: number;
  createdAt: Date;
}

export interface EffectPack {
  id: string;
  name: string;
  description: string;
  coverImageUrl: string;
  effects: Effect[];
  isPremium: boolean;
  price: number;      // Prix du pack (souvent moins cher que la somme)
  discount: number;   // % de réduction
  tags: string[];
  downloads: number;
  rating: number;
  createdAt: Date;
}

export interface Purchase {
  id: string;
  userId: string;
  itemId: string;     // Effect ID ou Pack ID
  itemType: 'effect' | 'pack';
  price: number;
  purchasedAt: Date;
}

export interface UserLibrary {
  userId: string;
  ownedEffects: Set<string>;
  ownedPacks: Set<string>;
  purchases: Purchase[];
}

export class MarketplaceService {
  private effects: Map<string, Effect>;
  private packs: Map<string, EffectPack>;
  private userLibraries: Map<string, UserLibrary>;
  private assetsDir: string;

  constructor() {
    this.effects = new Map();
    this.packs = new Map();
    this.userLibraries = new Map();
    this.assetsDir = process.env.MARKETPLACE_ASSETS_DIR || './marketplace-assets';
    
    this.initialize();
  }

  /**
   * Initialise le service avec des effets par défaut
   */
  private async initialize(): Promise<void> {
    await this.ensureAssetsDir();
    await this.loadDefaultEffects();
    await this.loadDefaultPacks();
    
    logger.info('✅ MarketplaceService initialized', {
      effects: this.effects.size,
      packs: this.packs.size
    });
  }

  /**
   * Assure que le répertoire assets existe
   */
  private async ensureAssetsDir(): Promise<void> {
    try {
      await fs.mkdir(this.assetsDir, { recursive: true });
      await fs.mkdir(path.join(this.assetsDir, 'transitions'), { recursive: true });
      await fs.mkdir(path.join(this.assetsDir, 'overlays'), { recursive: true });
      await fs.mkdir(path.join(this.assetsDir, 'sounds'), { recursive: true });
      await fs.mkdir(path.join(this.assetsDir, 'filters'), { recursive: true });
      await fs.mkdir(path.join(this.assetsDir, 'stickers'), { recursive: true });
    } catch (error) {
      logger.error('Failed to create assets directories', { error });
    }
  }

  /**
   * Charge les effets par défaut
   */
  private async loadDefaultEffects(): Promise<void> {
    const defaultEffects: Effect[] = [
      // TRANSITIONS GRATUITES
      {
        id: 'transition-fade-basic',
        name: 'Fade Basique',
        description: 'Transition fade simple et élégante',
        type: 'transition',
        category: 'viral',
        previewUrl: '/previews/fade-basic.mp4',
        filePath: '/marketplace-assets/transitions/fade-basic.json',
        fileSize: 2048,
        duration: 0.5,
        isPremium: false,
        price: 0,
        tags: ['fade', 'simple', 'gratuit'],
        downloads: 1500,
        rating: 4.5,
        createdAt: new Date()
      },
      {
        id: 'transition-wipe-left',
        name: 'Wipe Gauche',
        description: 'Transition wipe de gauche à droite',
        type: 'transition',
        category: 'viral',
        previewUrl: '/previews/wipe-left.mp4',
        filePath: '/marketplace-assets/transitions/wipe-left.json',
        fileSize: 3072,
        duration: 0.3,
        isPremium: false,
        price: 0,
        tags: ['wipe', 'direction', 'gratuit'],
        downloads: 1200,
        rating: 4.3,
        createdAt: new Date()
      },

      // TRANSITIONS PREMIUM
      {
        id: 'transition-zoom-burst',
        name: 'Zoom Burst',
        description: 'Transition zoom explosif style viral',
        type: 'transition',
        category: 'viral',
        previewUrl: '/previews/zoom-burst.mp4',
        filePath: '/marketplace-assets/transitions/zoom-burst.json',
        fileSize: 8192,
        duration: 0.8,
        isPremium: true,
        price: 199,  // 1.99€
        tags: ['zoom', 'viral', 'dynamique', 'premium'],
        downloads: 850,
        rating: 4.8,
        createdAt: new Date()
      },
      {
        id: 'transition-glitch-rgb',
        name: 'Glitch RGB',
        description: 'Transition glitch avec effet RGB split',
        type: 'transition',
        category: 'fun',
        previewUrl: '/previews/glitch-rgb.mp4',
        filePath: '/marketplace-assets/transitions/glitch-rgb.json',
        fileSize: 10240,
        duration: 0.6,
        isPremium: true,
        price: 249,  // 2.49€
        tags: ['glitch', 'rgb', 'moderne', 'premium'],
        downloads: 920,
        rating: 4.9,
        createdAt: new Date()
      },

      // OVERLAYS GRATUITS
      {
        id: 'overlay-light-leaks',
        name: 'Light Leaks Simple',
        description: 'Overlay de fuites de lumière basique',
        type: 'overlay',
        category: 'cinematic',
        previewUrl: '/previews/light-leaks.mp4',
        filePath: '/marketplace-assets/overlays/light-leaks.mp4',
        fileSize: 5120,
        isPremium: false,
        price: 0,
        tags: ['light', 'leak', 'cinematic', 'gratuit'],
        downloads: 2100,
        rating: 4.6,
        createdAt: new Date()
      },

      // OVERLAYS PREMIUM
      {
        id: 'overlay-film-grain-4k',
        name: 'Film Grain 4K',
        description: 'Grain de film professionnel 4K',
        type: 'overlay',
        category: 'cinematic',
        previewUrl: '/previews/film-grain-4k.mp4',
        filePath: '/marketplace-assets/overlays/film-grain-4k.mp4',
        fileSize: 51200,
        isPremium: true,
        price: 399,  // 3.99€
        tags: ['film', 'grain', '4k', 'professionnel', 'premium'],
        downloads: 650,
        rating: 4.9,
        createdAt: new Date()
      },

      // SONS GRATUITS
      {
        id: 'sound-whoosh-basic',
        name: 'Whoosh Basique',
        description: 'Son whoosh pour transitions',
        type: 'sound',
        category: 'viral',
        previewUrl: '/previews/whoosh-basic.mp3',
        filePath: '/marketplace-assets/sounds/whoosh-basic.mp3',
        fileSize: 24576,
        duration: 1.2,
        isPremium: false,
        price: 0,
        tags: ['whoosh', 'transition', 'gratuit'],
        downloads: 3200,
        rating: 4.4,
        createdAt: new Date()
      },

      // SONS PREMIUM
      {
        id: 'sound-cinematic-hit',
        name: 'Cinematic Hit',
        description: 'Impact cinématique puissant',
        type: 'sound',
        category: 'cinematic',
        previewUrl: '/previews/cinematic-hit.mp3',
        filePath: '/marketplace-assets/sounds/cinematic-hit.wav',
        fileSize: 98304,
        duration: 2.5,
        isPremium: true,
        price: 149,  // 1.49€
        tags: ['hit', 'impact', 'cinematic', 'premium'],
        downloads: 1100,
        rating: 4.7,
        createdAt: new Date()
      }
    ];

    defaultEffects.forEach(effect => {
      this.effects.set(effect.id, effect);
    });
  }

  /**
   * Charge les packs par défaut
   */
  private async loadDefaultPacks(): Promise<void> {
    const defaultPacks: EffectPack[] = [
      {
        id: 'pack-viral-starter',
        name: 'Viral Starter Pack',
        description: 'Pack complet pour débuter sur TikTok/Reels',
        coverImageUrl: '/previews/pack-viral-starter.jpg',
        effects: [
          this.effects.get('transition-zoom-burst')!,
          this.effects.get('transition-glitch-rgb')!,
          this.effects.get('sound-whoosh-basic')!,
          this.effects.get('overlay-light-leaks')!
        ],
        isPremium: true,
        price: 499,  // 4.99€ (économie de ~40%)
        discount: 40,
        tags: ['viral', 'tiktok', 'reels', 'starter'],
        downloads: 420,
        rating: 4.8,
        createdAt: new Date()
      },
      {
        id: 'pack-cinematic-pro',
        name: 'Cinematic Pro Pack',
        description: 'Pack professionnel pour vidéos cinématiques',
        coverImageUrl: '/previews/pack-cinematic-pro.jpg',
        effects: [
          this.effects.get('overlay-film-grain-4k')!,
          this.effects.get('overlay-light-leaks')!,
          this.effects.get('sound-cinematic-hit')!,
          this.effects.get('transition-fade-basic')!
        ],
        isPremium: true,
        price: 699,  // 6.99€ (économie de ~35%)
        discount: 35,
        tags: ['cinematic', 'professional', 'film'],
        downloads: 310,
        rating: 4.9,
        createdAt: new Date()
      }
    ];

    defaultPacks.forEach(pack => {
      this.packs.set(pack.id, pack);
    });
  }

  /**
   * Récupère tous les effets (filtrés par type et catégorie)
   */
  getAllEffects(
    type?: EffectType,
    category?: EffectCategory,
    isPremium?: boolean,
    userIsPremium: boolean = false
  ): Effect[] {
    let effects = Array.from(this.effects.values());

    // Filtrer par type
    if (type) {
      effects = effects.filter(e => e.type === type);
    }

    // Filtrer par catégorie
    if (category) {
      effects = effects.filter(e => e.category === category);
    }

    // Filtrer par premium
    if (isPremium !== undefined) {
      effects = effects.filter(e => e.isPremium === isPremium);
    }

    // Cacher les effets premium pour utilisateurs free
    if (!userIsPremium) {
      effects = effects.filter(e => !e.isPremium);
    }

    return effects.sort((a, b) => b.downloads - a.downloads);
  }

  /**
   * Récupère tous les packs
   */
  getAllPacks(userIsPremium: boolean = false): EffectPack[] {
    let packs = Array.from(this.packs.values());

    // Cacher les packs premium pour utilisateurs free
    if (!userIsPremium) {
      packs = packs.filter(p => !p.isPremium);
    }

    return packs.sort((a, b) => b.downloads - a.downloads);
  }

  /**
   * Récupère un effet par ID
   */
  getEffectById(effectId: string): Effect | null {
    return this.effects.get(effectId) || null;
  }

  /**
   * Récupère un pack par ID
   */
  getPackById(packId: string): EffectPack | null {
    return this.packs.get(packId) || null;
  }

  /**
   * Achète un effet
   */
  async purchaseEffect(userId: string, effectId: string): Promise<Purchase> {
    const effect = this.getEffectById(effectId);

    if (!effect) {
      throw new Error('Effect not found');
    }

    // Vérifier si déjà possédé
    const library = this.getUserLibrary(userId);
    if (library.ownedEffects.has(effectId)) {
      throw new Error('Effect already owned');
    }

    // Créer l'achat
    const purchase: Purchase = {
      id: uuidv4(),
      userId,
      itemId: effectId,
      itemType: 'effect',
      price: effect.price,
      purchasedAt: new Date()
    };

    // Ajouter à la bibliothèque
    library.ownedEffects.add(effectId);
    library.purchases.push(purchase);

    // Incrémenter compteur downloads
    effect.downloads++;

    logger.info('💳 Effect purchased', { userId, effectId, price: effect.price });

    return purchase;
  }

  /**
   * Achète un pack
   */
  async purchasePack(userId: string, packId: string): Promise<Purchase> {
    const pack = this.getPackById(packId);

    if (!pack) {
      throw new Error('Pack not found');
    }

    // Vérifier si déjà possédé
    const library = this.getUserLibrary(userId);
    if (library.ownedPacks.has(packId)) {
      throw new Error('Pack already owned');
    }

    // Créer l'achat
    const purchase: Purchase = {
      id: uuidv4(),
      userId,
      itemId: packId,
      itemType: 'pack',
      price: pack.price,
      purchasedAt: new Date()
    };

    // Ajouter à la bibliothèque
    library.ownedPacks.add(packId);
    library.purchases.push(purchase);

    // Ajouter tous les effets du pack
    pack.effects.forEach(effect => {
      library.ownedEffects.add(effect.id);
    });

    // Incrémenter compteur downloads
    pack.downloads++;

    logger.info('💳 Pack purchased', { userId, packId, price: pack.price, effectCount: pack.effects.length });

    return purchase;
  }

  /**
   * Récupère la bibliothèque d'un utilisateur
   */
  getUserLibrary(userId: string): UserLibrary {
    if (!this.userLibraries.has(userId)) {
      this.userLibraries.set(userId, {
        userId,
        ownedEffects: new Set<string>(),
        ownedPacks: new Set<string>(),
        purchases: []
      });
    }

    return this.userLibraries.get(userId)!;
  }

  /**
   * Télécharge un effet (retourne le chemin du fichier)
   */
  async downloadEffect(userId: string, effectId: string): Promise<string> {
    const effect = this.getEffectById(effectId);

    if (!effect) {
      throw new Error('Effect not found');
    }

    // Vérifier propriété
    const library = this.getUserLibrary(userId);
    if (!library.ownedEffects.has(effectId) && effect.price > 0) {
      throw new Error('Effect not owned. Purchase required.');
    }

    // Vérifier que le fichier existe
    try {
      await fs.access(effect.filePath);
    } catch {
      throw new Error('Effect file not found on server');
    }

    logger.info('⬇️ Effect downloaded', { userId, effectId, fileName: path.basename(effect.filePath) });

    return effect.filePath;
  }

  /**
   * Récupère les statistiques du marketplace
   */
  getMarketplaceStats(): {
    totalEffects: number;
    totalPacks: number;
    totalDownloads: number;
    topEffects: Effect[];
    topPacks: EffectPack[];
  } {
    const effects = Array.from(this.effects.values());
    const packs = Array.from(this.packs.values());

    const totalDownloads = effects.reduce((sum, e) => sum + e.downloads, 0) +
                           packs.reduce((sum, p) => sum + p.downloads, 0);

    return {
      totalEffects: effects.length,
      totalPacks: packs.length,
      totalDownloads,
      topEffects: effects.sort((a, b) => b.downloads - a.downloads).slice(0, 5),
      topPacks: packs.sort((a, b) => b.downloads - a.downloads).slice(0, 5)
    };
  }
}

export const marketplaceService = new MarketplaceService();
