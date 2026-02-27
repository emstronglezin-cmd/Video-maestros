import { z } from 'zod';

/**
 * Schéma pour un élément vidéo dans la timeline
 */
export const VideoElementSchema = z.object({
  type: z.literal('video'),
  file: z.string().min(1, 'Le nom du fichier est requis'),
  startTime: z.number().min(0).optional().default(0),
  duration: z.number().positive('La durée doit être positive'),
  volume: z.number().min(0).max(1).optional().default(1),
  speed: z.number().positive().optional().default(1)
});

/**
 * Schéma pour un élément image dans la timeline
 */
export const ImageElementSchema = z.object({
  type: z.literal('image'),
  file: z.string().min(1, 'Le nom du fichier est requis'),
  duration: z.number().positive('La durée doit être positive')
});

/**
 * Schéma pour une transition
 */
export const TransitionSchema = z.object({
  type: z.literal('transition'),
  effect: z.enum(['fade', 'dissolve', 'wipe', 'slide']),
  duration: z.number().positive('La durée doit être positive').max(5, 'Durée max 5s')
});

/**
 * Schéma pour un élément texte
 */
export const TextElementSchema = z.object({
  type: z.literal('text'),
  content: z.string().min(1, 'Le contenu du texte est requis'),
  duration: z.number().positive('La durée doit être positive'),
  position: z.enum(['top', 'center', 'bottom']).optional().default('center'),
  fontSize: z.number().positive().optional().default(48),
  color: z.string().optional().default('white')
});

/**
 * Union de tous les types d'éléments possibles
 */
export const TimelineElementSchema = z.discriminatedUnion('type', [
  VideoElementSchema,
  ImageElementSchema,
  TransitionSchema,
  TextElementSchema
]);

/**
 * Schéma pour la configuration audio
 */
export const AudioConfigSchema = z.object({
  file: z.string().optional(),
  volume: z.number().min(0).max(1).optional().default(0.5),
  fadeIn: z.number().min(0).optional().default(0),
  fadeOut: z.number().min(0).optional().default(0)
});

/**
 * Schéma complet de la timeline
 */
export const TimelineSchema = z.object({
  timeline: z.array(TimelineElementSchema).min(1, 'La timeline doit contenir au moins un élément'),
  audio: AudioConfigSchema.optional(),
  resolution: z.enum(['720', '1080', '2160']).optional().default('1080'),
  fps: z.number().positive().optional().default(30)
});

/**
 * Types TypeScript exportés
 */
export type VideoElement = z.infer<typeof VideoElementSchema>;
export type ImageElement = z.infer<typeof ImageElementSchema>;
export type Transition = z.infer<typeof TransitionSchema>;
export type TextElement = z.infer<typeof TextElementSchema>;
export type TimelineElement = z.infer<typeof TimelineElementSchema>;
export type AudioConfig = z.infer<typeof AudioConfigSchema>;
export type Timeline = z.infer<typeof TimelineSchema>;

/**
 * Validation helper
 */
export function validateTimeline(data: unknown): Timeline {
  return TimelineSchema.parse(data);
}

// Export aussi le schema pour compatibilité
export const timelineSchema = TimelineSchema;
