import ffmpeg from 'fluent-ffmpeg';
import path from 'path';
import fs from 'fs/promises';
import { Timeline } from './timeline.schema';
import { v4 as uuidv4 } from 'uuid';

/**
 * Options de rendu
 */
export interface RenderOptions {
  timeline: Timeline;
  uploadDir: string;
  outputDir: string;
  userId: string;
}

/**
 * Résultat du rendu
 */
export interface RenderResult {
  outputPath: string;
  duration: number;
  fileSize: number;
}

/**
 * Moteur de rendu FFmpeg
 */
export class FFmpegEngine {
  private uploadDir: string;
  private outputDir: string;

  constructor(uploadDir: string, outputDir: string) {
    this.uploadDir = uploadDir;
    this.outputDir = outputDir;
  }

  /**
   * Lance le rendu d'une timeline
   */
  async render(options: RenderOptions): Promise<RenderResult> {
    const { timeline, userId } = options;

    // Crée un ID unique pour ce rendu
    const renderId = uuidv4();
    const outputFilename = `video_${userId}_${renderId}.mp4`;
    const outputPath = path.join(this.outputDir, outputFilename);

    // Assure que le dossier de sortie existe
    await fs.mkdir(this.outputDir, { recursive: true });

    try {
      // Génère la vidéo selon la timeline
      await this.buildVideo(timeline, outputPath);

      // Récupère les informations du fichier
      const stats = await fs.stat(outputPath);
      const duration = await this.getVideoDuration(outputPath);

      return {
        outputPath,
        duration,
        fileSize: stats.size
      };
    } catch (error) {
      // Nettoie en cas d'erreur
      await this.cleanup(outputPath);
      throw error;
    }
  }

  /**
   * Construit la vidéo à partir de la timeline
   */
  private async buildVideo(timeline: Timeline, outputPath: string): Promise<void> {
    // Filtre les éléments vidéo et image
    const mediaElements = timeline.timeline.filter(
      el => el.type === 'video' || el.type === 'image'
    ) as Array<{ type: 'video' | 'image'; file: string; duration: number }>;

    if (mediaElements.length === 0) {
      throw new Error('Aucun élément média dans la timeline');
    }

    // Cas simple : un seul élément
    if (mediaElements.length === 1) {
      await this.renderSingleElement(mediaElements[0], timeline, outputPath);
      return;
    }

    // Cas multiple : concat avec transitions
    await this.renderMultipleElements(mediaElements, timeline, outputPath);
  }

  /**
   * Rend un seul élément
   */
  private async renderSingleElement(
    element: { type: 'video' | 'image'; file: string; duration: number },
    timeline: Timeline,
    outputPath: string
  ): Promise<void> {
    const inputPath = path.join(this.uploadDir, element.file);
    const resolution = this.getResolution(timeline.resolution || '1080');

    return new Promise((resolve, reject) => {
      let command = ffmpeg(inputPath);

      // Si c'est une image, crée une vidéo statique
      if (element.type === 'image') {
        command = command
          .loop(element.duration)
          .inputOptions(['-framerate 1']);
      }

      command
        .size(resolution)
        .fps(timeline.fps || 30)
        .videoCodec('libx264')
        .audioCodec('aac')
        .outputOptions([
          '-preset fast',
          '-crf 23',
          '-pix_fmt yuv420p'
        ]);

      // Ajoute l'audio si présent
      if (timeline.audio?.file) {
        const audioPath = path.join(this.uploadDir, timeline.audio.file);
        command = command.input(audioPath);
        command = command.outputOptions([
          `-filter_complex [1:a]volume=${timeline.audio.volume || 0.5}[a]`,
          '-map 0:v',
          '-map [a]',
          '-shortest'
        ]);
      }

      command
        .output(outputPath)
        .on('end', () => resolve())
        .on('error', (err) => reject(new Error(`FFmpeg error: ${err.message}`)))
        .run();
    });
  }

  /**
   * Rend plusieurs éléments avec transitions
   */
  private async renderMultipleElements(
    elements: Array<{ type: 'video' | 'image'; file: string; duration: number }>,
    timeline: Timeline,
    outputPath: string
  ): Promise<void> {
    // Détecte les transitions
    const transitions = timeline.timeline.filter(el => el.type === 'transition');
    const hasTransitions = transitions.length > 0;

    if (!hasTransitions) {
      // Concat simple sans transition
      await this.simpleConcat(elements, timeline, outputPath);
    } else {
      // Concat avec transitions fade
      await this.concatWithFade(elements, transitions as any[], timeline, outputPath);
    }
  }

  /**
   * Concaténation simple sans transitions
   */
  private async simpleConcat(
    elements: Array<{ type: 'video' | 'image'; file: string; duration: number }>,
    timeline: Timeline,
    outputPath: string
  ): Promise<void> {
    const resolution = this.getResolution(timeline.resolution || '1080');
    const fps = timeline.fps || 30;

    return new Promise((resolve, reject) => {
      const command = ffmpeg();

      // Ajoute tous les inputs
      elements.forEach(el => {
        const inputPath = path.join(this.uploadDir, el.file);
        command.input(inputPath);
      });

      // Construit le filter_complex pour concat
      const filterParts: string[] = [];
      elements.forEach((_, index) => {
        filterParts.push(`[${index}:v]scale=${resolution},setsar=1,fps=${fps}[v${index}]`);
      });

      const concatInputs = elements.map((_, i) => `[v${i}]`).join('');
      filterParts.push(`${concatInputs}concat=n=${elements.length}:v=1:a=0[outv]`);

      command.complexFilter(filterParts);

      command
        .outputOptions(['-map [outv]'])
        .videoCodec('libx264')
        .outputOptions([
          '-preset fast',
          '-crf 23',
          '-pix_fmt yuv420p'
        ]);

      // Ajoute l'audio si présent
      if (timeline.audio?.file) {
        const audioPath = path.join(this.uploadDir, timeline.audio.file);
        command.input(audioPath);
        command.outputOptions([
          `-filter_complex [${elements.length}:a]volume=${timeline.audio.volume || 0.5}[a]`,
          '-map [a]',
          '-shortest'
        ]);
      }

      command
        .output(outputPath)
        .on('end', () => resolve())
        .on('error', (err) => reject(new Error(`FFmpeg concat error: ${err.message}`)))
        .run();
    });
  }

  /**
   * Concaténation avec transitions fade
   */
  private async concatWithFade(
    elements: Array<{ type: 'video' | 'image'; file: string; duration: number }>,
    transitions: Array<{ effect: string; duration: number }>,
    timeline: Timeline,
    outputPath: string
  ): Promise<void> {
    const resolution = this.getResolution(timeline.resolution || '1080');
    const fps = timeline.fps || 30;
    const fadeDuration = transitions[0]?.duration || 1;

    return new Promise((resolve, reject) => {
      const command = ffmpeg();

      // Ajoute tous les inputs
      elements.forEach(el => {
        const inputPath = path.join(this.uploadDir, el.file);
        command.input(inputPath);
      });

      // Construit le filter_complex avec fade
      const filterParts: string[] = [];
      
      // Scale tous les inputs
      elements.forEach((_, index) => {
        filterParts.push(`[${index}:v]scale=${resolution},setsar=1,fps=${fps}[v${index}]`);
      });

      // Applique fade entre chaque paire
      if (elements.length === 2) {
        filterParts.push(
          `[v0][v1]xfade=transition=fade:duration=${fadeDuration}:offset=${elements[0].duration - fadeDuration}[outv]`
        );
      } else {
        // Pour plus de 2 éléments, chaîne les xfade
        let currentOffset = 0;
        for (let i = 0; i < elements.length - 1; i++) {
          const inputA = i === 0 ? `[v${i}]` : `[vf${i - 1}]`;
          const inputB = `[v${i + 1}]`;
          const output = i === elements.length - 2 ? '[outv]' : `[vf${i}]`;
          
          currentOffset += elements[i].duration - fadeDuration;
          filterParts.push(
            `${inputA}${inputB}xfade=transition=fade:duration=${fadeDuration}:offset=${currentOffset}${output}`
          );
        }
      }

      command.complexFilter(filterParts);

      command
        .outputOptions(['-map [outv]'])
        .videoCodec('libx264')
        .outputOptions([
          '-preset fast',
          '-crf 23',
          '-pix_fmt yuv420p'
        ]);

      // Ajoute l'audio si présent
      if (timeline.audio?.file) {
        const audioPath = path.join(this.uploadDir, timeline.audio.file);
        command.input(audioPath);
        command.outputOptions([
          `-filter_complex [${elements.length}:a]volume=${timeline.audio.volume || 0.5}[a]`,
          '-map [a]',
          '-shortest'
        ]);
      }

      command
        .output(outputPath)
        .on('end', () => resolve())
        .on('error', (err) => reject(new Error(`FFmpeg fade error: ${err.message}`)))
        .run();
    });
  }

  /**
   * Récupère la durée d'une vidéo
   */
  private getVideoDuration(filePath: string): Promise<number> {
    return new Promise((resolve, reject) => {
      ffmpeg.ffprobe(filePath, (err, metadata) => {
        if (err) return reject(err);
        resolve(metadata.format.duration || 0);
      });
    });
  }

  /**
   * Convertit la résolution en format WxH
   */
  private getResolution(res: string): string {
    const resolutions: Record<string, string> = {
      '720': '1280x720',
      '1080': '1920x1080',
      '2160': '3840x2160'
    };
    return resolutions[res] || resolutions['1080'];
  }

  /**
   * Nettoie un fichier
   */
  private async cleanup(filePath: string): Promise<void> {
    try {
      await fs.unlink(filePath);
    } catch {
      // Ignore si le fichier n'existe pas
    }
  }
}
