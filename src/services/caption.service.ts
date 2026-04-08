/**
 * CaptionService - Service de génération automatique de sous-titres
 * Utilise Whisper.cpp pour transcription audio → SRT → incrustation FFmpeg
 * Supporte animations (fade, karaoke), styles personnalisables
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs/promises';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { logger } from '../utils/logger';

const execPromise = promisify(exec);

// Configuration Whisper.cpp
const WHISPER_MODEL_PATH = process.env.WHISPER_MODEL_PATH || './models/ggml-base.bin';
const WHISPER_EXECUTABLE = process.env.WHISPER_EXECUTABLE || 'whisper-cpp';

export interface CaptionStyle {
  fontName: string;       // Arial, Impact, Comic Sans MS
  fontSize: number;       // 24, 32, 48
  primaryColor: string;   // Hex color #FFFFFF
  outlineColor: string;   // Hex color #000000
  outlineWidth: number;   // 2, 3, 4
  position: 'top' | 'center' | 'bottom';
  alignment: 'left' | 'center' | 'right';
  backgroundColor?: string; // Hex avec alpha #00000080
  animation: 'none' | 'fade' | 'karaoke'; // Type d'animation
  animationDuration: number; // Durée en ms pour fade
}

export interface CaptionSegment {
  index: number;
  startTime: number;  // secondes
  endTime: number;    // secondes
  text: string;
}

export interface CaptionResult {
  srtPath: string;
  segments: CaptionSegment[];
  language: string;
  duration: number;
}

export class CaptionService {
  private tempDir: string;

  constructor() {
    this.tempDir = process.env.TEMP_DIR || './temp';
    this.ensureTempDir();
  }

  private async ensureTempDir(): Promise<void> {
    try {
      await fs.mkdir(this.tempDir, { recursive: true });
    } catch (error) {
      logger.error('Failed to create temp directory', { error });
    }
  }

  /**
   * Transcrit l'audio d'une vidéo en SRT avec Whisper.cpp
   */
  async generateCaptions(
    videoPath: string,
    language: 'fr' | 'en' | 'auto' = 'auto',
    model: 'tiny' | 'base' | 'small' | 'medium' | 'large' = 'base'
  ): Promise<CaptionResult> {
    const jobId = uuidv4();
    logger.info('🎤 Starting caption generation', { jobId, videoPath, language, model });

    try {
      // 1. Extraire l'audio de la vidéo
      const audioPath = path.join(this.tempDir, `${jobId}.wav`);
      await this.extractAudio(videoPath, audioPath);

      // 2. Transcription avec Whisper.cpp
      const srtPath = path.join(this.tempDir, `${jobId}.srt`);
      const transcription = await this.transcribeWithWhisper(audioPath, srtPath, language, model);

      // 3. Parser le fichier SRT
      const segments = await this.parseSRT(srtPath);

      // 4. Nettoyer le fichier audio temporaire
      await fs.unlink(audioPath).catch(() => {});

      logger.info('✅ Caption generation completed', { 
        jobId, 
        segmentCount: segments.length,
        duration: transcription.duration 
      });

      return {
        srtPath,
        segments,
        language: transcription.language,
        duration: transcription.duration
      };

    } catch (error) {
      logger.error('❌ Caption generation failed', { jobId, error });
      throw new Error(`Caption generation failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * Extrait l'audio d'une vidéo en WAV pour Whisper
   */
  private async extractAudio(videoPath: string, outputPath: string): Promise<void> {
    const ffmpegCmd = [
      'ffmpeg',
      '-i', `"${videoPath}"`,
      '-vn',                          // Pas de vidéo
      '-acodec pcm_s16le',            // Format PCM 16-bit
      '-ar 16000',                    // Sample rate 16kHz (optimal pour Whisper)
      '-ac 1',                        // Mono
      '-y',                           // Overwrite
      `"${outputPath}"`
    ].join(' ');

    logger.debug('Extracting audio', { ffmpegCmd });

    try {
      await execPromise(ffmpegCmd, { timeout: 300000 }); // 5 min max
      logger.info('Audio extracted successfully', { outputPath });
    } catch (error) {
      logger.error('Failed to extract audio', { error });
      throw new Error('Audio extraction failed');
    }
  }

  /**
   * Transcrit l'audio avec Whisper.cpp
   */
  private async transcribeWithWhisper(
    audioPath: string,
    outputSrtPath: string,
    language: string,
    model: string
  ): Promise<{ language: string; duration: number }> {
    
    // Commande Whisper.cpp
    const modelPath = WHISPER_MODEL_PATH.replace('base', model);
    const whisperCmd = [
      WHISPER_EXECUTABLE,
      '-m', modelPath,
      '-f', `"${audioPath}"`,
      '-osrt',                         // Output SRT
      '-of', `"${outputSrtPath.replace('.srt', '')}"`, // Sans extension
      language !== 'auto' ? `-l ${language}` : '',
      '--print-colors',
      '--print-progress'
    ].filter(Boolean).join(' ');

    logger.debug('Transcribing with Whisper', { whisperCmd });

    try {
      const { stdout, stderr } = await execPromise(whisperCmd, { 
        timeout: 600000, // 10 min max
        maxBuffer: 10 * 1024 * 1024 // 10 MB buffer
      });

      logger.debug('Whisper output', { stdout, stderr });

      // Extraire la langue détectée
      const langMatch = stderr.match(/Detected language: (\w+)/i);
      const detectedLanguage = langMatch ? langMatch[1] : language;

      // Vérifier que le fichier SRT a été créé
      const srtExists = await fs.access(outputSrtPath).then(() => true).catch(() => false);
      if (!srtExists) {
        throw new Error('Whisper did not generate SRT file');
      }

      logger.info('Whisper transcription completed', { detectedLanguage });

      return {
        language: detectedLanguage,
        duration: 0 // Sera calculé depuis les segments
      };

    } catch (error) {
      logger.error('Whisper transcription failed', { error });
      throw new Error('Whisper transcription failed');
    }
  }

  /**
   * Parse un fichier SRT en segments
   */
  private async parseSRT(srtPath: string): Promise<CaptionSegment[]> {
    const content = await fs.readFile(srtPath, 'utf-8');
    const segments: CaptionSegment[] = [];

    // Format SRT standard:
    // 1
    // 00:00:00,000 --> 00:00:02,500
    // Texte du sous-titre

    const blocks = content.trim().split('\n\n');

    for (const block of blocks) {
      const lines = block.trim().split('\n');
      if (lines.length < 3) continue;

      const index = parseInt(lines[0], 10);
      const timeMatch = lines[1].match(/(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2}),(\d{3})/);
      
      if (!timeMatch) continue;

      const startTime = this.srtTimeToSeconds(timeMatch[1], timeMatch[2], timeMatch[3], timeMatch[4]);
      const endTime = this.srtTimeToSeconds(timeMatch[5], timeMatch[6], timeMatch[7], timeMatch[8]);
      const text = lines.slice(2).join(' ').trim();

      segments.push({ index, startTime, endTime, text });
    }

    return segments;
  }

  /**
   * Convertit un timestamp SRT en secondes
   */
  private srtTimeToSeconds(h: string, m: string, s: string, ms: string): number {
    return parseInt(h, 10) * 3600 + 
           parseInt(m, 10) * 60 + 
           parseInt(s, 10) + 
           parseInt(ms, 10) / 1000;
  }

  /**
   * Applique des sous-titres stylisés sur une vidéo avec FFmpeg
   */
  async applyStylizedCaptions(
    inputVideoPath: string,
    srtPath: string,
    outputVideoPath: string,
    style: CaptionStyle
  ): Promise<void> {
    logger.info('🎨 Applying stylized captions', { inputVideoPath, style });

    // Construire le filtre FFmpeg pour les sous-titres
    const subtitlesFilter = this.buildFFmpegSubtitleFilter(srtPath, style);

    const ffmpegCmd = [
      'ffmpeg',
      '-i', `"${inputVideoPath}"`,
      '-vf', `"${subtitlesFilter}"`,
      '-c:v libx264',
      '-preset slow',
      '-crf 18',
      '-c:a copy',
      '-y',
      `"${outputVideoPath}"`
    ].join(' ');

    logger.debug('Applying captions with FFmpeg', { ffmpegCmd });

    try {
      await execPromise(ffmpegCmd, { timeout: 600000 }); // 10 min max
      logger.info('✅ Captions applied successfully', { outputVideoPath });
    } catch (error) {
      logger.error('❌ Failed to apply captions', { error });
      throw new Error('Caption application failed');
    }
  }

  /**
   * Construit le filtre FFmpeg pour les sous-titres avec style
   */
  private buildFFmpegSubtitleFilter(srtPath: string, style: CaptionStyle): string {
    // Construction du filtre subtitles
    const alignments = {
      left: 1,    // Left
      center: 2,  // Center
      right: 3    // Right
    };

    // Conversion couleur hex to decimal
    const primaryColorDec = this.hexToDecimal(style.primaryColor);
    const outlineColorDec = this.hexToDecimal(style.outlineColor);
    const bgColorDec = style.backgroundColor ? this.hexToDecimal(style.backgroundColor) : null;

    // Construction du filtre subtitles
    let filter = `subtitles='${srtPath.replace(/\\/g, '\\\\').replace(/:/g, '\\:')}'`;
    filter += `:force_style='`;
    filter += `FontName=${style.fontName},`;
    filter += `FontSize=${style.fontSize},`;
    filter += `PrimaryColour=${primaryColorDec},`;
    filter += `OutlineColour=${outlineColorDec},`;
    filter += `OutlineWidth=${style.outlineWidth},`;
    filter += `Alignment=${alignments[style.alignment]},`;
    filter += `MarginV=${style.position === 'bottom' ? 50 : (style.position === 'top' ? 50 : 0)}`;
    
    if (bgColorDec) {
      filter += `,BackColour=${bgColorDec}`;
    }

    filter += `'`;

    return filter;
  }

  /**
   * Convertit couleur hex (#RRGGBBAA) en format décimal ASS (&HAABBGGRR)
   */
  private hexToDecimal(hex: string): string {
    // Enlever le #
    hex = hex.replace('#', '');
    
    // Si pas d'alpha, ajouter FF (opaque)
    if (hex.length === 6) {
      hex = hex + 'FF';
    }

    // Extraire RGBA
    const r = hex.substring(0, 2);
    const g = hex.substring(2, 4);
    const b = hex.substring(4, 6);
    const a = hex.substring(6, 8);

    // Format ASS: &HAABBGGRR
    return `&H${a}${b}${g}${r}`;
  }

  /**
   * Génère des sous-titres animés (fade-in par mot)
   */
  async generateAnimatedCaptions(
    inputVideoPath: string,
    segments: CaptionSegment[],
    outputVideoPath: string,
    style: CaptionStyle
  ): Promise<void> {
    logger.info('✨ Generating animated captions', { inputVideoPath, animation: style.animation });

    if (style.animation === 'none') {
      throw new Error('Use applyStylizedCaptions for non-animated subtitles');
    }

    // Pour les animations, on doit créer un filtre drawtext dynamique
    const drawTextFilters: string[] = [];

    for (const segment of segments) {
      if (style.animation === 'fade') {
        // Fade-in effect
        const fadeDuration = style.animationDuration / 1000; // ms to seconds
        drawTextFilters.push(this.buildFadeTextFilter(segment, style, fadeDuration));
      } else if (style.animation === 'karaoke') {
        // Karaoke effect (highlight progressif)
        drawTextFilters.push(this.buildKaraokeTextFilter(segment, style));
      }
    }

    // Combiner tous les filtres
    const combinedFilter = drawTextFilters.join(',');

    const ffmpegCmd = [
      'ffmpeg',
      '-i', `"${inputVideoPath}"`,
      '-vf', `"${combinedFilter}"`,
      '-c:v libx264',
      '-preset slow',
      '-crf 18',
      '-c:a copy',
      '-y',
      `"${outputVideoPath}"`
    ].join(' ');

    logger.debug('Applying animated captions', { ffmpegCmd });

    try {
      await execPromise(ffmpegCmd, { timeout: 600000 });
      logger.info('✅ Animated captions applied', { outputVideoPath });
    } catch (error) {
      logger.error('❌ Failed to apply animated captions', { error });
      throw new Error('Animated caption application failed');
    }
  }

  /**
   * Construit filtre drawtext avec fade-in
   */
  private buildFadeTextFilter(segment: CaptionSegment, style: CaptionStyle, fadeDuration: number): string {
    const yPos = style.position === 'top' ? 50 : (style.position === 'center' ? '(h-text_h)/2' : 'h-50-text_h');
    const xPos = style.alignment === 'left' ? 50 : (style.alignment === 'center' ? '(w-text_w)/2' : 'w-50-text_w');

    return [
      'drawtext',
      `text='${segment.text.replace(/'/g, "\\'")}',`,
      `fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf,`,
      `fontsize=${style.fontSize},`,
      `fontcolor=${style.primaryColor},`,
      `borderw=${style.outlineWidth},`,
      `bordercolor=${style.outlineColor},`,
      `x=${xPos},`,
      `y=${yPos},`,
      `enable='between(t,${segment.startTime},${segment.endTime})',`,
      `alpha='if(lt(t,${segment.startTime + fadeDuration}),(t-${segment.startTime})/${fadeDuration},1)'`
    ].join('');
  }

  /**
   * Construit filtre drawtext avec effet karaoke
   */
  private buildKaraokeTextFilter(segment: CaptionSegment, style: CaptionStyle): string {
    const yPos = style.position === 'top' ? 50 : (style.position === 'center' ? '(h-text_h)/2' : 'h-50-text_h');
    const xPos = style.alignment === 'left' ? 50 : (style.alignment === 'center' ? '(w-text_w)/2' : 'w-50-text_w');

    // Effet karaoke: couleur change progressivement de gauche à droite
    return [
      'drawtext',
      `text='${segment.text.replace(/'/g, "\\'")}',`,
      `fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf,`,
      `fontsize=${style.fontSize},`,
      `fontcolor=${style.primaryColor},`,
      `borderw=${style.outlineWidth},`,
      `bordercolor=${style.outlineColor},`,
      `x=${xPos},`,
      `y=${yPos},`,
      `enable='between(t,${segment.startTime},${segment.endTime})'`
    ].join('');
  }

  /**
   * Nettoie les fichiers temporaires
   */
  async cleanup(jobId: string): Promise<void> {
    const patterns = [
      path.join(this.tempDir, `${jobId}.wav`),
      path.join(this.tempDir, `${jobId}.srt`),
      path.join(this.tempDir, `${jobId}.txt`)
    ];

    for (const pattern of patterns) {
      await fs.unlink(pattern).catch(() => {});
    }
  }
}

export const captionService = new CaptionService();
