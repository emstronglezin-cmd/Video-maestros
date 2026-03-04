import axios from 'axios';
import { validateTimeline, Timeline } from '../video/timeline.schema';

/**
 * Configuration Ollama (optionnel - désactivé si pas configuré)
 */
const OLLAMA_URL = process.env.OLLAMA_URL || '';
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'llama3.2:3b';
const OLLAMA_ENABLED = !!OLLAMA_URL;

/**
 * Prompt système pour guider l'IA
 */
const SYSTEM_PROMPT = `Tu es un assistant spécialisé dans la conversion de scripts vidéo en JSON structuré.

Ta tâche est de transformer un script texte en une timeline JSON STRICTE avec cette structure :

{
  "timeline": [
    {
      "type": "video",
      "file": "nom_du_fichier.mp4",
      "duration": 5,
      "volume": 1
    },
    {
      "type": "transition",
      "effect": "fade",
      "duration": 1
    },
    {
      "type": "image",
      "file": "nom_image.jpg",
      "duration": 3
    },
    {
      "type": "text",
      "content": "Texte à afficher",
      "duration": 2,
      "position": "center"
    }
  ],
  "audio": {
    "file": "music.mp3",
    "volume": 0.4
  },
  "resolution": "1080",
  "fps": 30
}

RÈGLES STRICTES :
1. Réponds UNIQUEMENT avec du JSON valide, AUCUN autre texte
2. Types possibles : "video", "image", "transition", "text"
3. Transitions : "fade", "dissolve", "wipe", "slide"
4. Les durées sont en secondes
5. Les volumes entre 0 et 1
6. Résolutions : "720", "1080", "2160"

Exemple de script :
"Commence avec video1.mp4 pendant 5 secondes, ajoute une transition fade de 1 seconde, puis image1.jpg pendant 3 secondes. Musique de fond music.mp3 à 40%."

Réponds avec le JSON correspondant UNIQUEMENT.`;

/**
 * Interface pour la réponse Ollama
 */
interface OllamaResponse {
  model: string;
  response: string;
  done: boolean;
}

/**
 * Parse un script utilisateur en timeline JSON via Ollama
 */
export class ScriptParser {
  /**
   * Appelle Ollama pour générer la timeline
   */
  private async callOllama(prompt: string): Promise<string> {
    try {
      const response = await axios.post<OllamaResponse>(
        `${OLLAMA_URL}/api/generate`,
        {
          model: OLLAMA_MODEL,
          prompt: `${SYSTEM_PROMPT}\n\nSCRIPT UTILISATEUR :\n${prompt}\n\nJSON :`,
          stream: false,
          temperature: 0.1, // Très bas pour des réponses consistantes
          top_p: 0.9
        },
        {
          timeout: 60000 // 60 secondes timeout
        }
      );

      return response.data.response;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        throw new Error(`Erreur Ollama : ${error.message}`);
      }
      throw error;
    }
  }

  /**
   * Extrait le JSON de la réponse de l'IA
   */
  private extractJSON(text: string): string {
    // Cherche un bloc JSON entre accolades
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error('Aucun JSON trouvé dans la réponse de l\'IA');
    }
    return jsonMatch[0];
  }

  /**
   * Parse un script et retourne une timeline validée
   * Si Ollama n'est pas disponible, retourne une erreur explicite
   */
  async parseScript(script: string, availableFiles: string[]): Promise<Timeline> {
    if (!OLLAMA_ENABLED) {
      throw new Error('⚠️ Ollama service not configured - AI script generation is disabled. Please configure OLLAMA_URL environment variable.');
    }

    // Ajoute les fichiers disponibles au contexte
    const enhancedPrompt = `${script}\n\nFichiers disponibles : ${availableFiles.join(', ')}`;

    // Appelle l'IA
    const aiResponse = await this.callOllama(enhancedPrompt);

    // Extrait le JSON
    const jsonString = this.extractJSON(aiResponse);

    // Parse le JSON
    let parsedData: unknown;
    try {
      parsedData = JSON.parse(jsonString);
    } catch (error) {
      throw new Error('Le JSON généré par l\'IA est invalide');
    }

    // Valide avec Zod
    try {
      const timeline = validateTimeline(parsedData);
      return timeline;
    } catch (error) {
      throw new Error(`Validation échouée : ${error}`);
    }
  }

  /**
   * Vérifie si Ollama est disponible
   */
  async checkHealth(): Promise<boolean> {
    if (!OLLAMA_ENABLED) {
      return false;
    }

    try {
      const response = await axios.get(`${OLLAMA_URL}/api/tags`, {
        timeout: 5000
      });
      return response.status === 200;
    } catch {
      return false;
    }
  }
}

// Export singleton
export const scriptParser = new ScriptParser();

/**
 * Helper function for easy usage
 */
export async function parseScriptWithOllama(script: string, availableFiles: string[] = []): Promise<Timeline> {
  return scriptParser.parseScript(script, availableFiles);
}
