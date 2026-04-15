#!/usr/bin/env python3
"""
🎤 PIPER TTS SERVICE - Open Source Text-to-Speech
Installation: pip install piper-tts
"""

import os
import subprocess
import tempfile
from pathlib import Path
from typing import Optional, Dict, List
import json

class PiperTTSService:
    """Service TTS open source utilisant Piper"""
    
    def __init__(self, model_path: Optional[str] = None):
        """
        Initialiser le service Piper TTS
        
        Args:
            model_path: Chemin vers le modèle Piper (téléchargé automatiquement si None)
        """
        self.model_path = model_path or self._download_default_model()
        self.voices_available = self._list_available_voices()
        
    def _download_default_model(self) -> str:
        """
        Télécharger le modèle par défaut si nécessaire
        
        Returns:
            Chemin vers le modèle téléchargé
        """
        models_dir = Path.home() / '.local' / 'share' / 'piper' / 'models'
        models_dir.mkdir(parents=True, exist_ok=True)
        
        # Modèle par défaut: en_US-lessac-medium (haute qualité)
        model_name = 'en_US-lessac-medium'
        model_file = models_dir / f'{model_name}.onnx'
        config_file = models_dir / f'{model_name}.onnx.json'
        
        if not model_file.exists():
            print(f"📥 Téléchargement du modèle {model_name}...")
            base_url = f'https://huggingface.co/rhasspy/piper-voices/resolve/main/{model_name}'
            
            # Télécharger le modèle ONNX
            subprocess.run([
                'wget', '-q', '-O', str(model_file),
                f'{base_url}.onnx'
            ], check=True)
            
            # Télécharger la config JSON
            subprocess.run([
                'wget', '-q', '-O', str(config_file),
                f'{base_url}.onnx.json'
            ], check=True)
            
            print(f"✅ Modèle {model_name} téléchargé")
        
        return str(model_file)
    
    def _list_available_voices(self) -> List[Dict[str, str]]:
        """
        Lister les voix disponibles
        
        Returns:
            Liste des voix avec leurs métadonnées
        """
        return [
            {
                'id': 'en_US-lessac-medium',
                'language': 'en-US',
                'quality': 'medium',
                'gender': 'male',
                'description': 'Voix masculine américaine naturelle'
            },
            {
                'id': 'en_GB-alba-medium',
                'language': 'en-GB',
                'quality': 'medium',
                'gender': 'female',
                'description': 'Voix féminine britannique'
            },
            {
                'id': 'fr_FR-siwis-medium',
                'language': 'fr-FR',
                'quality': 'medium',
                'gender': 'female',
                'description': 'Voix féminine française'
            }
        ]
    
    def synthesize(
        self,
        text: str,
        output_path: str,
        voice_id: str = 'en_US-lessac-medium',
        speed: float = 1.0
    ) -> Dict[str, any]:
        """
        Synthétiser du texte en audio
        
        Args:
            text: Texte à synthétiser
            output_path: Chemin de sortie du fichier audio
            voice_id: ID de la voix à utiliser
            speed: Vitesse de parole (0.5 = lent, 2.0 = rapide)
            
        Returns:
            Métadonnées du fichier généré
        """
        try:
            # Créer répertoire de sortie si nécessaire
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            
            # Commande Piper
            cmd = [
                'piper',
                '--model', self.model_path,
                '--output_file', output_path,
                '--length_scale', str(1.0 / speed)  # Piper utilise length_scale inverse
            ]
            
            # Exécuter Piper avec le texte en stdin
            result = subprocess.run(
                cmd,
                input=text.encode('utf-8'),
                capture_output=True,
                check=True
            )
            
            # Obtenir la durée du fichier audio
            duration = self._get_audio_duration(output_path)
            
            return {
                'success': True,
                'output_path': output_path,
                'duration': duration,
                'voice_id': voice_id,
                'text_length': len(text),
                'file_size': os.path.getsize(output_path)
            }
            
        except subprocess.CalledProcessError as e:
            return {
                'success': False,
                'error': f'Piper TTS failed: {e.stderr.decode()}'
            }
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }
    
    def _get_audio_duration(self, audio_path: str) -> float:
        """
        Obtenir la durée d'un fichier audio en secondes
        
        Args:
            audio_path: Chemin vers le fichier audio
            
        Returns:
            Durée en secondes
        """
        try:
            result = subprocess.run([
                'ffprobe',
                '-v', 'quiet',
                '-show_entries', 'format=duration',
                '-of', 'json',
                audio_path
            ], capture_output=True, text=True)
            
            data = json.loads(result.stdout)
            return float(data['format']['duration'])
        except:
            return 0.0
    
    def batch_synthesize(
        self,
        texts: List[str],
        output_dir: str,
        voice_id: str = 'en_US-lessac-medium',
        speed: float = 1.0
    ) -> List[Dict[str, any]]:
        """
        Synthétiser plusieurs textes en batch
        
        Args:
            texts: Liste de textes à synthétiser
            output_dir: Répertoire de sortie
            voice_id: ID de la voix
            speed: Vitesse de parole
            
        Returns:
            Liste des résultats pour chaque synthèse
        """
        os.makedirs(output_dir, exist_ok=True)
        results = []
        
        for i, text in enumerate(texts):
            output_path = os.path.join(output_dir, f'tts_{i:04d}.wav')
            result = self.synthesize(text, output_path, voice_id, speed)
            results.append(result)
        
        return results
    
    def get_voices(self) -> List[Dict[str, str]]:
        """
        Obtenir la liste des voix disponibles
        
        Returns:
            Liste des voix avec métadonnées
        """
        return self.voices_available


# API Flask simple pour le service TTS
if __name__ == '__main__':
    from flask import Flask, request, jsonify, send_file
    
    app = Flask(__name__)
    tts_service = PiperTTSService()
    
    @app.route('/tts/voices', methods=['GET'])
    def get_voices():
        """Liste des voix disponibles"""
        return jsonify({
            'success': True,
            'voices': tts_service.get_voices()
        })
    
    @app.route('/tts/synthesize', methods=['POST'])
    def synthesize():
        """Synthétiser du texte"""
        data = request.get_json()
        
        text = data.get('text')
        voice_id = data.get('voice_id', 'en_US-lessac-medium')
        speed = data.get('speed', 1.0)
        
        if not text:
            return jsonify({
                'success': False,
                'error': 'Text is required'
            }), 400
        
        # Créer fichier temporaire
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
            output_path = tmp.name
        
        result = tts_service.synthesize(text, output_path, voice_id, speed)
        
        if result['success']:
            return send_file(
                output_path,
                mimetype='audio/wav',
                as_attachment=True,
                download_name='tts_output.wav'
            )
        else:
            return jsonify(result), 500
    
    print("🎤 Piper TTS Service démarré sur http://localhost:5001")
    app.run(host='0.0.0.0', port=5001, debug=False)
