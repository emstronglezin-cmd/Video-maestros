#!/usr/bin/env python3
"""
🎙️ FASTER-WHISPER TRANSCRIPTION SERVICE (Open Source)
Service de transcription audio local utilisant Faster-Whisper
Port: 5002
"""

from flask import Flask, request, jsonify
import os
import tempfile
import logging
from faster_whisper import WhisperModel

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
WHISPER_MODELS_DIR = os.getenv('WHISPER_MODELS_DIR', '/opt/whisper/models')
WHISPER_MODEL_SIZE = os.getenv('WHISPER_MODEL_SIZE', 'base')

# Initialize model (lazy loading)
_model = None

def get_model():
    """Load Whisper model (lazy initialization)"""
    global _model
    if _model is None:
        logger.info(f"Loading Faster-Whisper model: {WHISPER_MODEL_SIZE}")
        _model = WhisperModel(
            WHISPER_MODEL_SIZE,
            device="cpu",
            compute_type="int8",
            download_root=WHISPER_MODELS_DIR
        )
        logger.info("✅ Model loaded successfully")
    return _model

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'Faster-Whisper',
        'model': WHISPER_MODEL_SIZE,
        'models_dir': WHISPER_MODELS_DIR
    })

@app.route('/transcribe', methods=['POST'])
def transcribe_audio():
    """
    Transcribe audio file
    POST /transcribe
    Form-data:
        - audio: audio file (mp3, wav, m4a, flac, ogg)
        - language: optional language code (fr, en, etc.)
    Returns: {
        "text": "transcribed text",
        "language": "detected language",
        "segments": [...]
    }
    """
    try:
        # Check if audio file is present
        if 'audio' not in request.files:
            return jsonify({'error': 'Audio file is required'}), 400
        
        audio_file = request.files['audio']
        language = request.form.get('language', None)
        
        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(suffix='.audio', delete=False) as tmp_audio:
            audio_path = tmp_audio.name
            audio_file.save(audio_path)
        
        try:
            # Load model
            model = get_model()
            
            # Transcribe
            logger.info(f"Transcribing audio (language: {language or 'auto'})")
            segments, info = model.transcribe(
                audio_path,
                language=language,
                beam_size=5,
                vad_filter=True,  # Voice Activity Detection
                vad_parameters=dict(min_silence_duration_ms=500)
            )
            
            # Collect segments
            transcription_segments = []
            full_text = []
            
            for segment in segments:
                transcription_segments.append({
                    'start': segment.start,
                    'end': segment.end,
                    'text': segment.text.strip()
                })
                full_text.append(segment.text.strip())
            
            result = {
                'text': ' '.join(full_text),
                'language': info.language,
                'language_probability': info.language_probability,
                'duration': info.duration,
                'segments': transcription_segments
            }
            
            logger.info(f"✅ Transcription completed: {len(transcription_segments)} segments")
            return jsonify(result)
            
        finally:
            # Cleanup temporary file
            if os.path.exists(audio_path):
                os.unlink(audio_path)
        
    except Exception as e:
        logger.error(f"Transcription error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/languages', methods=['GET'])
def list_languages():
    """List supported languages"""
    languages = [
        'af', 'am', 'ar', 'as', 'az', 'ba', 'be', 'bg', 'bn', 'bo', 'br', 'bs',
        'ca', 'cs', 'cy', 'da', 'de', 'el', 'en', 'es', 'et', 'eu', 'fa', 'fi',
        'fo', 'fr', 'gl', 'gu', 'ha', 'haw', 'he', 'hi', 'hr', 'ht', 'hu', 'hy',
        'id', 'is', 'it', 'ja', 'jw', 'ka', 'kk', 'km', 'kn', 'ko', 'la', 'lb',
        'ln', 'lo', 'lt', 'lv', 'mg', 'mi', 'mk', 'ml', 'mn', 'mr', 'ms', 'mt',
        'my', 'ne', 'nl', 'nn', 'no', 'oc', 'pa', 'pl', 'ps', 'pt', 'ro', 'ru',
        'sa', 'sd', 'si', 'sk', 'sl', 'sn', 'so', 'sq', 'sr', 'su', 'sv', 'sw',
        'ta', 'te', 'tg', 'th', 'tk', 'tl', 'tr', 'tt', 'uk', 'ur', 'uz', 'vi',
        'yi', 'yo', 'zh'
    ]
    return jsonify({
        'languages': languages,
        'count': len(languages)
    })

if __name__ == '__main__':
    logger.info(f"🎙️ Starting Faster-Whisper service on port 5002...")
    logger.info(f"📁 Models directory: {WHISPER_MODELS_DIR}")
    logger.info(f"🤖 Model size: {WHISPER_MODEL_SIZE}")
    app.run(host='0.0.0.0', port=5002, debug=False)
