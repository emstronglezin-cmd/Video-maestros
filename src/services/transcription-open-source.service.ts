import axios from 'axios';
import path from 'path';
import fs from 'fs/promises';
import FormData from 'form-data';
import { logger } from '../utils/logger';

/**
 * 🎙️ TRANSCRIPTION SERVICE - Wrapper pour Faster-Whisper (Open Source)
 * Appelle le service Python Flask Faster-Whisper
 */

export interface TranscriptionOptions {
  audioPath: string;
  language?: string; // 'fr', 'en', 'auto' pour détection auto
  task?: 'transcribe' | 'translate'; // translate = vers anglais
  wordTimestamps?: boolean;
}

export interface TranscriptionSegment {
  id: number;
  start: number;
  end: number;
  text: string;
  confidence: number;
  words?: Array<{
    word: string;
    start: number;
    end: number;
    confidence: number;
  }>;
}

export interface TranscriptionResult {
  success: boolean;
  text: string;
  segments: TranscriptionSegment[];
  language: string;
  languageProbability: number;
  duration: number;
  modelSize: string;
}

export interface SRTGenerationResult {
  success: boolean;
  srtPath: string;
  segmentsCount: number;
  language: string;
}

export class TranscriptionService {
  private whisperServiceUrl: string;
  private outputDir: string;

  constructor(outputDir: string) {
    this.outputDir = outputDir;
    this.whisperServiceUrl = process.env.WHISPER_SERVICE_URL || 'http://localhost:5002';
  }

  /**
   * Transcrire un fichier audio
   */
  async transcribe(options: TranscriptionOptions): Promise<TranscriptionResult> {
    try {
      // Lire le fichier audio
      const audioBuffer = await fs.readFile(options.audioPath);

      // Créer FormData
      const form = new FormData();
      form.append('audio', audioBuffer, {
        filename: path.basename(options.audioPath),
        contentType: 'audio/wav'
      });
      form.append('language', options.language || 'auto');

      // Envoyer au service Whisper
      const response = await axios.post(
        `${this.whisperServiceUrl}/transcribe`,
        form,
        {
          headers: form.getHeaders(),
          timeout: 300000, // 5 min timeout pour transcription
          maxContentLength: Infinity,
          maxBodyLength: Infinity
        }
      );

      const result = response.data;

      logger.info('Transcription completed', {
        language: result.language,
        segmentsCount: result.segments?.length || 0,
        duration: result.duration,
        textLength: result.text?.length || 0
      });

      return {
        success: result.success,
        text: result.text || '',
        segments: result.segments || [],
        language: result.language || 'unknown',
        languageProbability: result.language_probability || 0,
        duration: result.duration || 0,
        modelSize: result.model_size || 'base'
      };

    } catch (error: any) {
      logger.error('Transcription failed', {
        error: error.message,
        audioPath: options.audioPath
      });
      
      return {
        success: false,
        text: '',
        segments: [],
        language: 'unknown',
        languageProbability: 0,
        duration: 0,
        modelSize: 'base'
      };
    }
  }

  /**
   * Générer un fichier SRT de sous-titres
   */
  async generateSRT(
    audioPath: string,
    outputPath?: string,
    language?: string
  ): Promise<SRTGenerationResult> {
    try {
      // Lire le fichier audio
      const audioBuffer = await fs.readFile(audioPath);

      // Créer FormData
      const form = new FormData();
      form.append('audio', audioBuffer, {
        filename: path.basename(audioPath),
        contentType: 'audio/wav'
      });
      form.append('language', language || 'auto');

      // Envoyer au service Whisper
      const response = await axios.post(
        `${this.whisperServiceUrl}/transcribe/srt`,
        form,
        {
          headers: form.getHeaders(),
          timeout: 300000,
          responseType: 'arraybuffer',
          maxContentLength: Infinity,
          maxBodyLength: Infinity
        }
      );

      // Déterminer le chemin de sortie
      const srtPath = outputPath || path.join(
        this.outputDir,
        `${path.basename(audioPath, path.extname(audioPath))}.srt`
      );

      // Sauvegarder le fichier SRT
      await fs.mkdir(path.dirname(srtPath), { recursive: true });
      await fs.writeFile(srtPath, response.data);

      // Compter les segments
      const srtContent = response.data.toString('utf-8');
      const segmentsCount = (srtContent.match(/^\d+$/gm) || []).length;

      logger.info('SRT file generated', {
        srtPath,
        segmentsCount
      });

      return {
        success: true,
        srtPath,
        segmentsCount,
        language: language || 'auto'
      };

    } catch (error: any) {
      logger.error('SRT generation failed', {
        error: error.message,
        audioPath
      });

      return {
        success: false,
        srtPath: '',
        segmentsCount: 0,
        language: 'unknown'
      };
    }
  }

  /**
   * Générer un fichier WebVTT de sous-titres
   */
  async generateVTT(
    audioPath: string,
    outputPath?: string,
    language?: string
  ): Promise<{ success: boolean; vttPath: string }> {
    try {
      // D'abord générer SRT
      const srtResult = await this.generateSRT(audioPath, undefined, language);
      
      if (!srtResult.success) {
        throw new Error('Failed to generate SRT');
      }

      // Déterminer le chemin VTT
      const vttPath = outputPath || path.join(
        this.outputDir,
        `${path.basename(audioPath, path.extname(audioPath))}.vtt`
      );

      // Convertir SRT en VTT
      const srtContent = await fs.readFile(srtResult.srtPath, 'utf-8');
      const vttContent = this.convertSrtToVtt(srtContent);

      // Sauvegarder VTT
      await fs.writeFile(vttPath, vttContent, 'utf-8');

      // Nettoyer le fichier SRT temporaire
      await fs.unlink(srtResult.srtPath);

      logger.info('VTT file generated', { vttPath });

      return {
        success: true,
        vttPath
      };

    } catch (error: any) {
      logger.error('VTT generation failed', {
        error: error.message,
        audioPath
      });

      return {
        success: false,
        vttPath: ''
      };
    }
  }

  /**
   * Convertir SRT en WebVTT
   */
  private convertSrtToVtt(srtContent: string): string {
    // Remplacer les virgules par des points dans les timestamps
    const vttContent = srtContent.replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, '$1.$2');
    
    // Ajouter l'en-tête WebVTT
    return `WEBVTT\n\n${vttContent}`;
  }

  /**
   * Extraire l'audio d'une vidéo pour transcription
   */
  async extractAudioFromVideo(videoPath: string): Promise<string> {
    try {
      const { exec } = require('child_process');
      const { promisify } = require('util');
      const execAsync = promisify(exec);

      const audioPath = path.join(
        this.outputDir,
        `${path.basename(videoPath, path.extname(videoPath))}_audio.wav`
      );

      await fs.mkdir(this.outputDir, { recursive: true });

      // Extraire audio avec FFmpeg
      await execAsync(
        `ffmpeg -i "${videoPath}" -vn -acodec pcm_s16le -ar 16000 -ac 1 "${audioPath}" -y`
      );

      logger.info('Audio extracted from video', {
        videoPath,
        audioPath
      });

      return audioPath;

    } catch (error: any) {
      logger.error('Audio extraction failed', {
        error: error.message,
        videoPath
      });
      throw error;
    }
  }

  /**
   * Health check du service Whisper
   */
  async healthCheck(): Promise<boolean> {
    try {
      const response = await axios.get(`${this.whisperServiceUrl}/health`, {
        timeout: 5000
      });
      return response.status === 200 && response.data.success;
    } catch (error) {
      return false;
    }
  }
}
