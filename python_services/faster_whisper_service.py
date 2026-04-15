#!/usr/bin/env python3
"""
🎙️ FASTER-WHISPER SERVICE - Open Source Speech-to-Text
Installation: pip install faster-whisper
"""

import os
import subprocess
import tempfile
from pathlib import Path
from typing import Optional, Dict, List, Tuple
import json
from faster_whisper import WhisperModel

class FasterWhisperService:
    """Service de transcription open source utilisant Faster Whisper"""
    
    def __init__(self, model_size: str = 'base'):
        """
        Initialiser le service Faster Whisper
        
        Args:
            model_size: Taille du modèle (tiny, base, small, medium, large-v3)
                       base = bon compromis qualité/vitesse
        """
        self.model_size = model_size
        self.model = None
        self._load_model()
        
    def _load_model(self):
        """Charger le modèle Whisper"""
        print(f"📥 Chargement du modèle Whisper '{self.model_size}'...")
        
        # Utiliser CPU ou GPU selon disponibilité
        device = "cuda" if self._check_cuda() else "cpu"
        compute_type = "int8" if device == "cpu" else "float16"
        
        self.model = WhisperModel(
            self.model_size,
            device=device,
            compute_type=compute_type
        )
        
        print(f"✅ Modèle chargé (device: {device})")
    
    def _check_cuda(self) -> bool:
        """Vérifier si CUDA est disponible"""
        try:
            import torch
            return torch.cuda.is_available()
        except:
            return False
    
    def transcribe(
        self,
        audio_path: str,
        language: Optional[str] = None,
        task: str = 'transcribe',
        word_timestamps: bool = True
    ) -> Dict[str, any]:
        """
        Transcrire un fichier audio
        
        Args:
            audio_path: Chemin vers le fichier audio
            language: Code langue (fr, en, auto pour détection auto)
            task: 'transcribe' ou 'translate' (vers anglais)
            word_timestamps: Inclure timestamps au niveau des mots
            
        Returns:
            Résultat de transcription avec segments et timestamps
        """
        try:
            # Détection automatique si language='auto'
            if language == 'auto':
                language = None
            
            # Transcrire
            segments, info = self.model.transcribe(
                audio_path,
                language=language,
                task=task,
                word_timestamps=word_timestamps,
                vad_filter=True,  # Voice Activity Detection
                vad_parameters=dict(
                    min_silence_duration_ms=500,
                    threshold=0.5
                )
            )
            
            # Convertir segments en liste
            segments_list = []
            full_text = []
            
            for segment in segments:
                segment_dict = {
                    'id': segment.id,
                    'start': segment.start,
                    'end': segment.end,
                    'text': segment.text.strip(),
                    'confidence': segment.avg_logprob
                }
                
                # Ajouter word-level timestamps si disponible
                if word_timestamps and segment.words:
                    segment_dict['words'] = [
                        {
                            'word': word.word,
                            'start': word.start,
                            'end': word.end,
                            'confidence': word.probability
                        }
                        for word in segment.words
                    ]
                
                segments_list.append(segment_dict)
                full_text.append(segment.text.strip())
            
            return {
                'success': True,
                'text': ' '.join(full_text),
                'segments': segments_list,
                'language': info.language,
                'language_probability': info.language_probability,
                'duration': info.duration,
                'model_size': self.model_size
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }
    
    def generate_srt(
        self,
        audio_path: str,
        output_path: str,
        language: Optional[str] = None
    ) -> Dict[str, any]:
        """
        Générer un fichier SRT de sous-titres
        
        Args:
            audio_path: Chemin vers le fichier audio
            output_path: Chemin de sortie du fichier SRT
            language: Code langue
            
        Returns:
            Résultat avec chemin du fichier SRT
        """
        try:
            # Transcrire
            result = self.transcribe(audio_path, language=language)
            
            if not result['success']:
                return result
            
            # Générer contenu SRT
            srt_content = self._segments_to_srt(result['segments'])
            
            # Écrire fichier
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(srt_content)
            
            return {
                'success': True,
                'srt_path': output_path,
                'segments_count': len(result['segments']),
                'language': result['language']
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }
    
    def _segments_to_srt(self, segments: List[Dict]) -> str:
        """
        Convertir segments en format SRT
        
        Args:
            segments: Liste de segments avec timestamps
            
        Returns:
            Contenu SRT formaté
        """
        srt_lines = []
        
        for i, segment in enumerate(segments, 1):
            # Index
            srt_lines.append(str(i))
            
            # Timestamps
            start_time = self._format_timestamp(segment['start'])
            end_time = self._format_timestamp(segment['end'])
            srt_lines.append(f"{start_time} --> {end_time}")
            
            # Texte
            srt_lines.append(segment['text'])
            srt_lines.append('')  # Ligne vide
        
        return '\n'.join(srt_lines)
    
    def _format_timestamp(self, seconds: float) -> str:
        """
        Formater timestamp en format SRT (HH:MM:SS,mmm)
        
        Args:
            seconds: Temps en secondes
            
        Returns:
            Timestamp formaté
        """
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        millis = int((seconds % 1) * 1000)
        
        return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"
    
    def generate_vtt(
        self,
        audio_path: str,
        output_path: str,
        language: Optional[str] = None
    ) -> Dict[str, any]:
        """
        Générer un fichier WebVTT de sous-titres
        
        Args:
            audio_path: Chemin vers le fichier audio
            output_path: Chemin de sortie du fichier VTT
            language: Code langue
            
        Returns:
            Résultat avec chemin du fichier VTT
        """
        try:
            # Transcrire
            result = self.transcribe(audio_path, language=language)
            
            if not result['success']:
                return result
            
            # Générer contenu VTT
            vtt_content = self._segments_to_vtt(result['segments'])
            
            # Écrire fichier
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(vtt_content)
            
            return {
                'success': True,
                'vtt_path': output_path,
                'segments_count': len(result['segments']),
                'language': result['language']
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }
    
    def _segments_to_vtt(self, segments: List[Dict]) -> str:
        """Convertir segments en format WebVTT"""
        vtt_lines = ['WEBVTT', '']
        
        for segment in segments:
            start_time = self._format_vtt_timestamp(segment['start'])
            end_time = self._format_vtt_timestamp(segment['end'])
            vtt_lines.append(f"{start_time} --> {end_time}")
            vtt_lines.append(segment['text'])
            vtt_lines.append('')
        
        return '\n'.join(vtt_lines)
    
    def _format_vtt_timestamp(self, seconds: float) -> str:
        """Formater timestamp en format WebVTT (HH:MM:SS.mmm)"""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        millis = int((seconds % 1) * 1000)
        
        return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"


# API Flask simple pour le service de transcription
if __name__ == '__main__':
    from flask import Flask, request, jsonify, send_file
    
    app = Flask(__name__)
    whisper_service = FasterWhisperService(model_size='base')
    
    @app.route('/transcribe', methods=['POST'])
    def transcribe():
        """Transcrire un fichier audio"""
        if 'audio' not in request.files:
            return jsonify({
                'success': False,
                'error': 'No audio file provided'
            }), 400
        
        audio_file = request.files['audio']
        language = request.form.get('language', 'auto')
        
        # Sauvegarder temporairement
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
            audio_path = tmp.name
            audio_file.save(audio_path)
        
        try:
            result = whisper_service.transcribe(audio_path, language=language)
            return jsonify(result)
        finally:
            if os.path.exists(audio_path):
                os.unlink(audio_path)
    
    @app.route('/transcribe/srt', methods=['POST'])
    def transcribe_srt():
        """Générer fichier SRT"""
        if 'audio' not in request.files:
            return jsonify({
                'success': False,
                'error': 'No audio file provided'
            }), 400
        
        audio_file = request.files['audio']
        language = request.form.get('language', 'auto')
        
        # Sauvegarder temporairement
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_audio:
            audio_path = tmp_audio.name
            audio_file.save(audio_path)
        
        with tempfile.NamedTemporaryFile(suffix='.srt', delete=False) as tmp_srt:
            srt_path = tmp_srt.name
        
        try:
            result = whisper_service.generate_srt(audio_path, srt_path, language=language)
            
            if result['success']:
                return send_file(
                    srt_path,
                    mimetype='text/plain',
                    as_attachment=True,
                    download_name='subtitles.srt'
                )
            else:
                return jsonify(result), 500
        finally:
            if os.path.exists(audio_path):
                os.unlink(audio_path)
    
    @app.route('/health', methods=['GET'])
    def health():
        """Health check"""
        return jsonify({
            'success': True,
            'service': 'faster-whisper',
            'model_size': whisper_service.model_size
        })
    
    print("🎙️ Faster-Whisper Service démarré sur http://localhost:5002")
    app.run(host='0.0.0.0', port=5002, debug=False)
