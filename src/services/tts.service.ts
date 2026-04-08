import { exec } from 'child_process';
import { promisify } from 'util';
import path from 'path';
import fs from 'fs/promises';
import { v4 as uuidv4 } from 'uuid';
import { logger } from '../utils/logger';

const execAsync = promisify(exec);

/**
 * Langues supportées par Piper TTS
 */
export enum TTSLanguage {
  FRENCH = 'fr_FR',
  ENGLISH = 'en_US',
  ENGLISH_GB = 'en_GB'
}

/**
 * Styles de voix
 */
export enum TTSVoiceStyle {
  PROFESSIONAL = 'professional', // Voix claire et neutre
  FUN = 'fun',                   // Voix enjouée
  STORYTELLING = 'storytelling'  // Voix narrative
}

/**
 * Options TTS
 */
export interface TTSOptions {
  text: string;
  language: TTSLanguage;
  style: TTSVoiceStyle;
  speed?: number; // 0.5 à 2.0
  volume?: number; // 0.0 à 1.0
}

/**
 * Résultat TTS
 */
export interface TTSResult {
  audioPath: string;
  duration: number;
  fileSize: number;
}

/**
 * Configuration des modèles Piper par langue et style
 */
interface PiperModelConfig {
  language: TTSLanguage;
  style: TTSVoiceStyle;
  modelName: string;
  modelPath: string;
}

/**
 * Service TTS avec Piper
 * 
 * Piper est plus léger et rapide que Coqui TTS
 * Installation: https://github.com/rhasspy/piper
 * 
 * Premium only feature
 */
export class TTSService {
  private outputDir: string;
  private piperBinary: string;
  private modelsDir: string;
  private models: PiperModelConfig[];

  constructor(outputDir: string) {
    this.outputDir = outputDir;
    this.piperBinary = process.env.PIPER_BINARY || 'piper';
    this.modelsDir = process.env.PIPER_MODELS_DIR || '/opt/piper/models';
    
    // Configuration des modèles disponibles
    this.models = [
      // Français
      {
        language: TTSLanguage.FRENCH,
        style: TTSVoiceStyle.PROFESSIONAL,
        modelName: 'fr_FR-siwis-medium',
        modelPath: path.join(this.modelsDir, 'fr_FR-siwis-medium.onnx')
      },
      {
        language: TTSLanguage.FRENCH,
        style: TTSVoiceStyle.FUN,
        modelName: 'fr_FR-gilles-low',
        modelPath: path.join(this.modelsDir, 'fr_FR-gilles-low.onnx')
      },
      {
        language: TTSLanguage.FRENCH,
        style: TTSVoiceStyle.STORYTELLING,
        modelName: 'fr_FR-tom-medium',
        modelPath: path.join(this.modelsDir, 'fr_FR-tom-medium.onnx')
      },
      // Anglais US
      {
        language: TTSLanguage.ENGLISH,
        style: TTSVoiceStyle.PROFESSIONAL,
        modelName: 'en_US-lessac-medium',
        modelPath: path.join(this.modelsDir, 'en_US-lessac-medium.onnx')
      },
      {
        language: TTSLanguage.ENGLISH,
        style: TTSVoiceStyle.FUN,
        modelName: 'en_US-amy-medium',
        modelPath: path.join(this.modelsDir, 'en_US-amy-medium.onnx')
      },
      {
        language: TTSLanguage.ENGLISH,
        style: TTSVoiceStyle.STORYTELLING,
        modelName: 'en_US-ryan-high',
        modelPath: path.join(this.modelsDir, 'en_US-ryan-high.onnx')
      },
      // Anglais GB
      {
        language: TTSLanguage.ENGLISH_GB,
        style: TTSVoiceStyle.PROFESSIONAL,
        modelName: 'en_GB-alan-medium',
        modelPath: path.join(this.modelsDir, 'en_GB-alan-medium.onnx')
      }
    ];
  }

  /**
   * Vérifie si Piper est installé
   */
  async checkInstallation(): Promise<boolean> {
    try {
      const { stdout } = await execAsync(`${this.piperBinary} --version`);
      logger.info(`✅ Piper TTS version: ${stdout.trim()}`);
      return true;
    } catch (error) {
      logger.error('❌ Piper TTS not found. Install from: https://github.com/rhasspy/piper');
      return false;
    }
  }

  /**
   * Trouve le modèle correspondant
   */
  private findModel(language: TTSLanguage, style: TTSVoiceStyle): PiperModelConfig | undefined {
    return this.models.find(m => m.language === language && m.style === style);
  }

  /**
   * Génère un fichier audio depuis du texte
   */
  async generateSpeech(options: TTSOptions): Promise<TTSResult> {
    const {
      text,
      language,
      style,
      speed = 1.0,
      volume = 1.0
    } = options;

    if (!text || text.trim().length === 0) {
      throw new Error('Text is required for TTS');
    }

    if (speed < 0.5 || speed > 2.0) {
      throw new Error('Speed must be between 0.5 and 2.0');
    }

    // Trouve le modèle
    const model = this.findModel(language, style);
    if (!model) {
      throw new Error(`No model found for language ${language} and style ${style}`);
    }

    // Vérifie que le modèle existe
    try {
      await fs.access(model.modelPath);
    } catch {
      throw new Error(`Model file not found: ${model.modelPath}`);
    }

    logger.info(`🎤 Generating speech: ${language} ${style}`);
    logger.info(`   Text: "${text.substring(0, 50)}${text.length > 50 ? '...' : ''}"`);

    // Génère un nom de fichier unique
    const outputId = uuidv4();
    const rawOutputPath = path.join(this.outputDir, `tts_${outputId}_raw.wav`);
    const finalOutputPath = path.join(this.outputDir, `tts_${outputId}.wav`);

    try {
      // Assure que le dossier existe
      await fs.mkdir(this.outputDir, { recursive: true });

      // Écrit le texte dans un fichier temporaire
      const textFilePath = path.join(this.outputDir, `tts_${outputId}_text.txt`);
      await fs.writeFile(textFilePath, text, 'utf-8');

      // Commande Piper
      const piperCommand = `cat "${textFilePath}" | ${this.piperBinary} --model "${model.modelPath}" --output_file "${rawOutputPath}"`;
      
      logger.info(`🎬 Piper command: ${piperCommand}`);

      // Exécute Piper
      const { stderr } = await execAsync(piperCommand, {
        timeout: 120000 // 2 minutes max
      });

      if (stderr) {
        logger.warn(`⚠️  Piper stderr: ${stderr}`);
      }

      // Vérifie que le fichier a été créé
      const stats = await fs.stat(rawOutputPath);
      if (stats.size === 0) {
        throw new Error('Generated audio file is empty');
      }

      logger.info(`✅ Raw audio generated: ${stats.size} bytes`);

      // Applique speed et volume avec FFmpeg
      const ffmpegCommand = `ffmpeg -i "${rawOutputPath}" -filter:a "atempo=${speed},volume=${volume}" -y "${finalOutputPath}"`;
      
      await execAsync(ffmpegCommand, {
        timeout: 60000 // 1 minute max
      });

      // Récupère les infos finales
      const finalStats = await fs.stat(finalOutputPath);
      const duration = await this.getAudioDuration(finalOutputPath);

      // Nettoie les fichiers temporaires
      await fs.unlink(textFilePath);
      await fs.unlink(rawOutputPath);

      logger.info(`✅ TTS complete: ${duration.toFixed(2)}s, ${finalStats.size} bytes`);

      return {
        audioPath: finalOutputPath,
        duration,
        fileSize: finalStats.size
      };
    } catch (error: any) {
      logger.error(`❌ TTS generation error: ${error.message}`);
      
      // Nettoie en cas d'erreur
      try {
        await fs.unlink(rawOutputPath).catch(() => {});
        await fs.unlink(finalOutputPath).catch(() => {});
      } catch {}

      throw new Error(`Failed to generate speech: ${error.message}`);
    }
  }

  /**
   * Récupère la durée d'un fichier audio
   */
  private async getAudioDuration(audioPath: string): Promise<number> {
    const command = `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${audioPath}"`;
    const { stdout } = await execAsync(command);
    return parseFloat(stdout.trim());
  }

  /**
   * Liste les modèles disponibles
   */
  async listAvailableModels(): Promise<PiperModelConfig[]> {
    const available: PiperModelConfig[] = [];

    for (const model of this.models) {
      try {
        await fs.access(model.modelPath);
        available.push(model);
      } catch {
        logger.warn(`⚠️  Model not found: ${model.modelPath}`);
      }
    }

    return available;
  }

  /**
   * Télécharge un modèle Piper (helper)
   */
  async downloadModel(language: TTSLanguage, style: TTSVoiceStyle): Promise<void> {
    const model = this.findModel(language, style);
    if (!model) {
      throw new Error(`No model configuration for ${language} ${style}`);
    }

    logger.info(`📥 Downloading model: ${model.modelName}`);

    // URL de téléchargement (exemple)
    const baseUrl = 'https://github.com/rhasspy/piper/releases/download/v1.2.0';
    const modelUrl = `${baseUrl}/${model.modelName}.tar.gz`;

    try {
      // Crée le dossier des modèles
      await fs.mkdir(this.modelsDir, { recursive: true });

      // Télécharge avec wget ou curl
      const downloadCommand = `wget -O "${this.modelsDir}/${model.modelName}.tar.gz" "${modelUrl}"`;
      await execAsync(downloadCommand, { timeout: 300000 }); // 5 minutes

      // Décompresse
      const extractCommand = `tar -xzf "${this.modelsDir}/${model.modelName}.tar.gz" -C "${this.modelsDir}"`;
      await execAsync(extractCommand);

      // Nettoie l'archive
      await fs.unlink(`${this.modelsDir}/${model.modelName}.tar.gz`);

      logger.info(`✅ Model downloaded: ${model.modelName}`);
    } catch (error: any) {
      logger.error(`❌ Model download failed: ${error.message}`);
      throw error;
    }
  }

  /**
   * Génère une voix off pour un script complet
   * Divise le texte en segments si trop long
   */
  async generateVoiceOver(
    script: string,
    language: TTSLanguage,
    style: TTSVoiceStyle,
    maxSegmentLength: number = 500
  ): Promise<TTSResult> {
    // Divise le script en segments
    const segments = this.splitTextIntoSegments(script, maxSegmentLength);
    
    if (segments.length === 1) {
      // Un seul segment, génération directe
      return await this.generateSpeech({
        text: segments[0],
        language,
        style
      });
    }

    // Plusieurs segments, génère et concatène
    logger.info(`📝 Generating voice-over in ${segments.length} segments`);

    const segmentPaths: string[] = [];
    let totalDuration = 0;

    try {
      for (let i = 0; i < segments.length; i++) {
        logger.info(`   Segment ${i + 1}/${segments.length}`);
        const result = await this.generateSpeech({
          text: segments[i],
          language,
          style
        });
        segmentPaths.push(result.audioPath);
        totalDuration += result.duration;
      }

      // Concatène tous les segments
      const outputId = uuidv4();
      const finalOutputPath = path.join(this.outputDir, `tts_${outputId}_voiceover.wav`);

      await this.concatenateAudioFiles(segmentPaths, finalOutputPath);

      // Nettoie les segments
      for (const segmentPath of segmentPaths) {
        await fs.unlink(segmentPath);
      }

      const finalStats = await fs.stat(finalOutputPath);

      logger.info(`✅ Voice-over complete: ${totalDuration.toFixed(2)}s`);

      return {
        audioPath: finalOutputPath,
        duration: totalDuration,
        fileSize: finalStats.size
      };
    } catch (error) {
      // Nettoie en cas d'erreur
      for (const segmentPath of segmentPaths) {
        await fs.unlink(segmentPath).catch(() => {});
      }
      throw error;
    }
  }

  /**
   * Divise un texte en segments
   */
  private splitTextIntoSegments(text: string, maxLength: number): string[] {
    const sentences = text.match(/[^.!?]+[.!?]+/g) || [text];
    const segments: string[] = [];
    let currentSegment = '';

    for (const sentence of sentences) {
      if (currentSegment.length + sentence.length <= maxLength) {
        currentSegment += sentence;
      } else {
        if (currentSegment) {
          segments.push(currentSegment.trim());
        }
        currentSegment = sentence;
      }
    }

    if (currentSegment) {
      segments.push(currentSegment.trim());
    }

    return segments;
  }

  /**
   * Concatène plusieurs fichiers audio
   */
  private async concatenateAudioFiles(inputPaths: string[], outputPath: string): Promise<void> {
    const listFilePath = path.join(this.outputDir, `concat_${uuidv4()}.txt`);
    
    // Crée le fichier de liste pour FFmpeg
    const listContent = inputPaths.map(p => `file '${p}'`).join('\n');
    await fs.writeFile(listFilePath, listContent, 'utf-8');

    const command = `ffmpeg -f concat -safe 0 -i "${listFilePath}" -c copy -y "${outputPath}"`;
    
    await execAsync(command, { timeout: 120000 });

    await fs.unlink(listFilePath);
  }
}
