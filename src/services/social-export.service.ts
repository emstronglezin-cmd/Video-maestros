/**
 * SocialExportService - Export direct vers TikTok et Instagram
 * Intégration TikTok Content Posting API + Instagram Graph API
 */

import axios, { AxiosInstance } from 'axios';
import * as fs from 'fs/promises';
import { logger } from '../utils/logger';

// Configuration TikTok
const TIKTOK_API_BASE = 'https://open-api.tiktok.com';
const TIKTOK_CLIENT_KEY = process.env.TIKTOK_CLIENT_KEY || '';
const TIKTOK_CLIENT_SECRET = process.env.TIKTOK_CLIENT_SECRET || '';

// Configuration Instagram
const INSTAGRAM_API_BASE = 'https://graph.facebook.com/v18.0';
const INSTAGRAM_APP_ID = process.env.INSTAGRAM_APP_ID || '';
const INSTAGRAM_APP_SECRET = process.env.INSTAGRAM_APP_SECRET || '';

export interface SocialAccount {
  platform: 'tiktok' | 'instagram';
  userId: string;           // User ID Video Maestro
  platformUserId: string;   // ID utilisateur sur la plateforme
  platformUsername: string;
  accessToken: string;
  refreshToken?: string;
  expiresAt: Date;
  isActive: boolean;
  createdAt: Date;
}

export interface PostConfig {
  title: string;
  description: string;
  hashtags: string[];
  privacy: 'public' | 'friends' | 'private';
  allowComments: boolean;
  allowDuet: boolean;      // TikTok only
  allowStitch: boolean;    // TikTok only
  disableAds: boolean;     // Instagram only
}

export interface PostResult {
  success: boolean;
  platform: 'tiktok' | 'instagram';
  postId?: string;
  postUrl?: string;
  error?: string;
}

export class SocialExportService {
  private tiktokClient: AxiosInstance;
  private instagramClient: AxiosInstance;
  private accounts: Map<string, SocialAccount>;

  constructor() {
    this.tiktokClient = axios.create({
      baseURL: TIKTOK_API_BASE,
      timeout: 60000,
      headers: {
        'Content-Type': 'application/json'
      }
    });

    this.instagramClient = axios.create({
      baseURL: INSTAGRAM_API_BASE,
      timeout: 60000
    });

    this.accounts = new Map();
    
    logger.info('✅ SocialExportService initialized');
  }

  /**
   * Connecte un compte TikTok (OAuth 2.0)
   */
  async connectTikTokAccount(userId: string, authCode: string): Promise<SocialAccount> {
    logger.info('🔗 Connecting TikTok account', { userId });

    try {
      // Échanger le code d'autorisation contre un access token
      const tokenResponse = await this.tiktokClient.post('/oauth/access_token/', {
        client_key: TIKTOK_CLIENT_KEY,
        client_secret: TIKTOK_CLIENT_SECRET,
        code: authCode,
        grant_type: 'authorization_code'
      });

      const { access_token, refresh_token, expires_in, open_id } = tokenResponse.data.data;

      // Récupérer les infos utilisateur
      const userResponse = await this.tiktokClient.get('/user/info/', {
        params: { open_id },
        headers: { 'Authorization': `Bearer ${access_token}` }
      });

      const username = userResponse.data.data.user.display_name;

      // Créer l'account
      const account: SocialAccount = {
        platform: 'tiktok',
        userId,
        platformUserId: open_id,
        platformUsername: username,
        accessToken: access_token,
        refreshToken: refresh_token,
        expiresAt: new Date(Date.now() + expires_in * 1000),
        isActive: true,
        createdAt: new Date()
      };

      this.accounts.set(`tiktok-${userId}`, account);

      logger.info('✅ TikTok account connected', { userId, username });

      return account;

    } catch (error) {
      logger.error('❌ Failed to connect TikTok account', { userId, error });
      throw new Error('TikTok connection failed');
    }
  }

  /**
   * Connecte un compte Instagram (OAuth 2.0)
   */
  async connectInstagramAccount(userId: string, authCode: string, redirectUri: string): Promise<SocialAccount> {
    logger.info('🔗 Connecting Instagram account', { userId });

    try {
      // Échanger le code contre un short-lived token
      const tokenResponse = await this.instagramClient.post('/oauth/access_token', {
        client_id: INSTAGRAM_APP_ID,
        client_secret: INSTAGRAM_APP_SECRET,
        grant_type: 'authorization_code',
        redirect_uri: redirectUri,
        code: authCode
      });

      const shortLivedToken = tokenResponse.data.access_token;
      const igUserId = tokenResponse.data.user_id;

      // Échanger short-lived token contre long-lived token (60 jours)
      const longLivedResponse = await this.instagramClient.get('/oauth/access_token', {
        params: {
          grant_type: 'ig_exchange_token',
          client_secret: INSTAGRAM_APP_SECRET,
          access_token: shortLivedToken
        }
      });

      const longLivedToken = longLivedResponse.data.access_token;
      const expiresIn = longLivedResponse.data.expires_in;

      // Récupérer username
      const userResponse = await this.instagramClient.get(`/${igUserId}`, {
        params: {
          fields: 'username',
          access_token: longLivedToken
        }
      });

      const username = userResponse.data.username;

      // Créer l'account
      const account: SocialAccount = {
        platform: 'instagram',
        userId,
        platformUserId: igUserId,
        platformUsername: username,
        accessToken: longLivedToken,
        expiresAt: new Date(Date.now() + expiresIn * 1000),
        isActive: true,
        createdAt: new Date()
      };

      this.accounts.set(`instagram-${userId}`, account);

      logger.info('✅ Instagram account connected', { userId, username });

      return account;

    } catch (error) {
      logger.error('❌ Failed to connect Instagram account', { userId, error });
      throw new Error('Instagram connection failed');
    }
  }

  /**
   * Post une vidéo sur TikTok
   */
  async postToTikTok(
    userId: string,
    videoPath: string,
    config: PostConfig
  ): Promise<PostResult> {
    logger.info('📤 Posting to TikTok', { userId, videoPath });

    const accountKey = `tiktok-${userId}`;
    const account = this.accounts.get(accountKey);

    if (!account || !account.isActive) {
      return {
        success: false,
        platform: 'tiktok',
        error: 'TikTok account not connected'
      };
    }

    try {
      // Vérifier expiration token
      if (account.expiresAt < new Date()) {
        await this.refreshTikTokToken(account);
      }

      // Step 1: Initier l'upload
      const initResponse = await this.tiktokClient.post(
        '/share/video/upload/',
        {
          video: {
            file_path: videoPath
          }
        },
        {
          headers: {
            'Authorization': `Bearer ${account.accessToken}`,
            'Content-Type': 'application/json'
          }
        }
      );

      const uploadUrl = initResponse.data.data.upload_url;

      // Step 2: Upload le fichier vidéo
      const videoBuffer = await fs.readFile(videoPath);
      
      await axios.put(uploadUrl, videoBuffer, {
        headers: {
          'Content-Type': 'video/mp4'
        }
      });

      // Step 3: Publier la vidéo
      const caption = this.buildCaption(config);
      
      const publishResponse = await this.tiktokClient.post(
        '/share/video/upload/complete/',
        {
          video_id: initResponse.data.data.video_id,
          post_info: {
            title: config.title,
            caption: caption,
            privacy_level: config.privacy === 'public' ? 'PUBLIC_TO_EVERYONE' : 'SELF_ONLY',
            disable_duet: !config.allowDuet,
            disable_stitch: !config.allowStitch,
            disable_comment: !config.allowComments
          }
        },
        {
          headers: {
            'Authorization': `Bearer ${account.accessToken}`
          }
        }
      );

      const postId = publishResponse.data.data.publish_id;
      const shareUrl = `https://www.tiktok.com/@${account.platformUsername}/video/${postId}`;

      logger.info('✅ Posted to TikTok successfully', { userId, postId });

      return {
        success: true,
        platform: 'tiktok',
        postId,
        postUrl: shareUrl
      };

    } catch (error) {
      logger.error('❌ Failed to post to TikTok', { userId, error });
      return {
        success: false,
        platform: 'tiktok',
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }

  /**
   * Post un Reel sur Instagram
   */
  async postToInstagram(
    userId: string,
    videoPath: string,
    _thumbnailPath: string,
    config: PostConfig
  ): Promise<PostResult> {
    logger.info('📤 Posting to Instagram', { userId, videoPath });

    const accountKey = `instagram-${userId}`;
    const account = this.accounts.get(accountKey);

    if (!account || !account.isActive) {
      return {
        success: false,
        platform: 'instagram',
        error: 'Instagram account not connected'
      };
    }

    try {
      // Step 1: Créer un container média
      const caption = this.buildCaption(config);
      
      const containerResponse = await this.instagramClient.post(
        `/${account.platformUserId}/media`,
        {
          media_type: 'REELS',
          video_url: videoPath,  // Doit être une URL publique
          caption: caption,
          thumb_offset: 0,
          share_to_feed: true
        },
        {
          params: {
            access_token: account.accessToken
          }
        }
      );

      const containerId = containerResponse.data.id;

      // Step 2: Attendre que la vidéo soit traitée
      let status = 'IN_PROGRESS';
      let attempts = 0;
      const maxAttempts = 30;  // 5 minutes max

      while (status === 'IN_PROGRESS' && attempts < maxAttempts) {
        await this.delay(10000);  // Attendre 10s

        const statusResponse = await this.instagramClient.get(
          `/${containerId}`,
          {
            params: {
              fields: 'status_code',
              access_token: account.accessToken
            }
          }
        );

        status = statusResponse.data.status_code;
        attempts++;
      }

      if (status !== 'FINISHED') {
        throw new Error(`Video processing failed with status: ${status}`);
      }

      // Step 3: Publier le média
      const publishResponse = await this.instagramClient.post(
        `/${account.platformUserId}/media_publish`,
        {
          creation_id: containerId
        },
        {
          params: {
            access_token: account.accessToken
          }
        }
      );

      const mediaId = publishResponse.data.id;
      const shareUrl = `https://www.instagram.com/reel/${mediaId}`;

      logger.info('✅ Posted to Instagram successfully', { userId, mediaId });

      return {
        success: true,
        platform: 'instagram',
        postId: mediaId,
        postUrl: shareUrl
      };

    } catch (error) {
      logger.error('❌ Failed to post to Instagram', { userId, error });
      return {
        success: false,
        platform: 'instagram',
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }

  /**
   * Rafraîchit le token TikTok
   */
  private async refreshTikTokToken(account: SocialAccount): Promise<void> {
    logger.info('🔄 Refreshing TikTok token', { userId: account.userId });

    const response = await this.tiktokClient.post('/oauth/refresh_token/', {
      client_key: TIKTOK_CLIENT_KEY,
      grant_type: 'refresh_token',
      refresh_token: account.refreshToken
    });

    account.accessToken = response.data.data.access_token;
    account.refreshToken = response.data.data.refresh_token;
    account.expiresAt = new Date(Date.now() + response.data.data.expires_in * 1000);

    logger.info('✅ TikTok token refreshed');
  }

  /**
   * Construit la caption avec hashtags
   */
  private buildCaption(config: PostConfig): string {
    let caption = config.description;
    
    if (config.hashtags.length > 0) {
      const hashtagsStr = config.hashtags.map(tag => 
        tag.startsWith('#') ? tag : `#${tag}`
      ).join(' ');
      
      caption += '\n\n' + hashtagsStr;
    }

    return caption;
  }

  /**
   * Récupère les comptes connectés d'un utilisateur
   */
  getConnectedAccounts(userId: string): SocialAccount[] {
    const accounts: SocialAccount[] = [];

    for (const account of this.accounts.values()) {
      if (account.userId === userId && account.isActive) {
        accounts.push(account);
      }
    }

    return accounts;
  }

  /**
   * Déconnecte un compte social
   */
  disconnectAccount(userId: string, platform: 'tiktok' | 'instagram'): boolean {
    const key = `${platform}-${userId}`;
    const account = this.accounts.get(key);

    if (!account) {
      return false;
    }

    account.isActive = false;
    this.accounts.delete(key);

    logger.info('🔌 Social account disconnected', { userId, platform });

    return true;
  }

  /**
   * Utilitaire: delay
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

export const socialExportService = new SocialExportService();
