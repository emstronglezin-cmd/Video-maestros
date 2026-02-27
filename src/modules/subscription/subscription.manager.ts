import { Redis } from 'ioredis';

/**
 * Tiers d'abonnement
 */
export enum SubscriptionTier {
  FREE = 'free',
  PREMIUM = 'premium'
}

/**
 * Limites par tier
 */
export interface TierLimits {
  dailyExports: number;
  maxResolution: number;
  maxDuration: number;
  watermark: boolean;
}

/**
 * Configuration des limites
 */
const TIER_LIMITS: Record<SubscriptionTier, TierLimits> = {
  [SubscriptionTier.FREE]: {
    dailyExports: parseInt(process.env.FREE_DAILY_EXPORTS || '2'),
    maxResolution: parseInt(process.env.FREE_MAX_RESOLUTION || '720'),
    maxDuration: 60, // 60 secondes
    watermark: true
  },
  [SubscriptionTier.PREMIUM]: {
    dailyExports: -1, // Illimité
    maxResolution: parseInt(process.env.PREMIUM_MAX_RESOLUTION || '4096'),
    maxDuration: -1, // Illimité
    watermark: false
  }
};

/**
 * Gestionnaire d'abonnements
 */
export class SubscriptionManager {
  private redis: Redis;

  constructor() {
    this.redis = new Redis({
      host: process.env.REDIS_HOST || 'localhost',
      port: parseInt(process.env.REDIS_PORT || '6379')
    });
  }

  /**
   * Récupère le tier d'un utilisateur
   */
  async getUserTier(userId: string): Promise<SubscriptionTier> {
    const tier = await this.redis.get(`user:${userId}:tier`);
    return (tier as SubscriptionTier) || SubscriptionTier.FREE;
  }

  /**
   * Définit le tier d'un utilisateur
   */
  async setUserTier(userId: string, tier: SubscriptionTier): Promise<void> {
    await this.redis.set(`user:${userId}:tier`, tier);
  }

  /**
   * Récupère les limites d'un utilisateur
   */
  async getUserLimits(userId: string): Promise<TierLimits> {
    const tier = await this.getUserTier(userId);
    return TIER_LIMITS[tier];
  }

  /**
   * Vérifie si l'utilisateur peut exporter
   */
  async canExport(userId: string): Promise<{ allowed: boolean; reason?: string }> {
    const tier = await this.getUserTier(userId);
    const limits = TIER_LIMITS[tier];

    // Premium = toujours autorisé
    if (tier === SubscriptionTier.PREMIUM) {
      return { allowed: true };
    }

    // Vérifie le quota quotidien pour FREE
    const today = new Date().toISOString().split('T')[0];
    const key = `user:${userId}:exports:${today}`;
    const exportCount = parseInt(await this.redis.get(key) || '0');

    if (exportCount >= limits.dailyExports) {
      return {
        allowed: false,
        reason: `Limite quotidienne atteinte (${limits.dailyExports} exports/jour). Passez Premium pour des exports illimités.`
      };
    }

    return { allowed: true };
  }

  /**
   * Enregistre un export
   */
  async recordExport(userId: string): Promise<void> {
    const today = new Date().toISOString().split('T')[0];
    const key = `user:${userId}:exports:${today}`;
    
    await this.redis.incr(key);
    // Expire à minuit
    await this.redis.expireat(key, this.getMidnightTimestamp());
  }

  /**
   * Récupère le nombre d'exports aujourd'hui
   */
  async getTodayExportCount(userId: string): Promise<number> {
    const today = new Date().toISOString().split('T')[0];
    const key = `user:${userId}:exports:${today}`;
    return parseInt(await this.redis.get(key) || '0');
  }

  /**
   * Vérifie si une résolution est autorisée
   */
  async isResolutionAllowed(userId: string, resolution: string): Promise<boolean> {
    const limits = await this.getUserLimits(userId);
    const requestedRes = parseInt(resolution);
    return requestedRes <= limits.maxResolution;
  }

  /**
   * Récupère le timestamp de minuit
   */
  private getMidnightTimestamp(): number {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(0, 0, 0, 0);
    return Math.floor(tomorrow.getTime() / 1000);
  }

  /**
   * Ferme la connexion Redis
   */
  async close(): Promise<void> {
    await this.redis.quit();
  }
}

// Singleton
let subscriptionManagerInstance: SubscriptionManager | null = null;

export function getSubscriptionManager(): SubscriptionManager {
  if (!subscriptionManagerInstance) {
    subscriptionManagerInstance = new SubscriptionManager();
  }
  return subscriptionManagerInstance;
}
