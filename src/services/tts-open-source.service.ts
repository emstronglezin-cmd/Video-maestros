import axios from 'axios';
import path from 'path';
import fs from 'fs/promises';
import { v4 as uuidv4 } from 'uuid';
import { logger } from '../utils/logger';

/**
 * 🎤 TTS SERVICE - Wrapper pour Piper TTS (Open Source)
 * Appelle le service Python Flask Piper TTS
 */

export enum TTSLanguage {
  FRENCH = 'fr_FR',
  ENGLISH = 'en_US',
  ENGLISH_GB = 'en_GB'
}

export enum TTSVoiceStyle {
  PROFESSIONAL = 'professional',
  FUN = 'fun',
  STORYTELLING = 'storytelling'
}

export interface TTSOptions {
  text: string;
  language: TTSLanguage;
  style: TTSVoiceStyle;
  speed?: number;
  volume?: number;
}

export interface TTSResult {
  audioPath: string;
  duration: number;
  fileSize: number;
}

/**
 * Mapping des styles vers les voice IDs Piper
 */
const VOICE_MAPPING: Record<string, string> = {
  // French
  'fr_FR-professional': 'fr_FR-siwis-medium',
  'fr_FR-fun': 'fr_FR-gilles-low',
  'fr_FR-storytelling': 'fr_FR-tom-medium',
  
  // English US
  'en_US-professional': 'en_US-lessac-medium',
  'en_US-fun': 'en_US-danny-low',
  'en_US-storytelling': 'en_US-ryan-high',
  
  // English GB
  'en_GB-professional': 'en_GB-alba-medium',
  'en_GB-fun': 'en_GB-northern_english_male-medium',
  'en_GB-storytelling': 'en_GB-semaine-medium'
};

export class TTSService {
  private outputDir: string;
  private ttsServiceUrl: string;

  constructor(outputDir: string) {
    this.outputDir = outputDir;
    this.ttsServiceUrl = process.env.TTS_SERVICE_URL || 'http://localhost:5001';
  }

  /**
   * Générer audio TTS
   */
  async generateSpeech(options: TTSOptions): Promise<TTSResult> {
    try {
      // Résoudre le voice ID
      const voiceKey = `${options.language}-${options.style}`;
      const voiceId = VOICE_MAPPING[voiceKey] || 'en_US-lessac-medium';

      // Préparer la requête
      const response = await axios.post(
        `${this.ttsServiceUrl}/tts/synthesize`,
        {
          text: options.text,
          voice_id: voiceId,
          speed: options.speed || 1.0
        },
        {
          responseType: 'arraybuffer',
          timeout: 60000 // 60s timeout
        }
      );

      // Sauvegarder le fichier audio
      const outputFilename = `tts_${uuidv4()}.wav`;
      const outputPath = path.join(this.outputDir, outputFilename);

      await fs.mkdir(this.outputDir, { recursive: true });
      await fs.writeFile(outputPath, response.data);

      // Obtenir info fichier
      const stats = await fs.stat(outputPath);
      const duration = await this.getAudioDuration(outputPath);

      logger.info('TTS audio generated', {
        voiceId,
        textLength: options.text.length,
        duration,
        fileSize: stats.size
      });

      return {
        audioPath: outputPath,
        duration,
        fileSize: stats.size
      };

    } catch (error: any) {
      logger.error('TTS generation failed', {
        error: error.message,
        options
      });
      throw new Error(`TTS generation failed: ${error.message}`);
    }
  }

  /**
   * Obtenir la liste des voix disponibles
   */
  async getAvailableVoices(): Promise<any[]> {
    try {
      const response = await axios.get(`${this.ttsServiceUrl}/tts/voices`);
      return response.data.voices;
    } catch (error: any) {
      logger.error('Failed to get voices', { error: error.message });
      return [];
    }
  }

  /**
   * Générer batch TTS pour plusieurs textes
   */
  async generateBatchSpeech(
    texts: string[],
    language: TTSLanguage,
    style: TTSVoiceStyle
  ): Promise<TTSResult[]> {
    const results: TTSResult[] = [];

    for (const text of texts) {
      try {
        const result = await this.generateSpeech({
          text,
          language,
          style,
          speed: 1.0
        });
        results.push(result);
      } catch (error) {
        logger.error('Batch TTS item failed', { text, error });
        // Continue avec les autres
      }
    }

    return results;
  }

  /**
   * Obtenir la durée d'un fichier audio avec FFprobe
   */
  private async getAudioDuration(audioPath: string): Promise<number> {
    try {
      const { exec } = require('child_process');
      const { promisify } = require('util');
      const execAsync = promisify(exec);

      const { stdout } = await execAsync(
        `ffprobe -v quiet -show_entries format=duration -of json "${audioPath}"`
      );

      const data = JSON.parse(stdout);
      return parseFloat(data.format.duration) || 0;
    } catch (error) {
      logger.warn('Failed to get audio duration', { error });
      return 0;
    }
  }

  /**
   * Health check du service TTS
   */
  async healthCheck(): Promise<boolean> {
    try {
      const response = await axios.get(`${this.ttsServiceUrl}/tts/voices`, {
        timeout: 5000
      });
      return response.status === 200;
    } catch (error) {
      return false;
    }
  }
}
