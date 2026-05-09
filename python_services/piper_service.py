#!/usr/bin/env python3
"""
🎤 PIPER TTS SERVICE (Open Source)
Service de synthèse vocale local utilisant Piper
Port: 5001
"""

from flask import Flask, request, jsonify, send_file
import os
import subprocess
import tempfile
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
PIPER_MODELS_DIR = os.getenv('PIPER_MODELS_DIR', '/opt/piper/models')
DEFAULT_MODEL = 'fr_FR-upmc-medium'

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'Piper TTS',
        'models_dir': PIPER_MODELS_DIR
    })

@app.route('/generate', methods=['POST'])
def generate_tts():
    """
    Generate speech from text
    POST /generate
    Body: {
        "text": "Text to speak",
        "language": "fr-FR" (optional),
        "speed": 1.0 (optional),
        "voice": "medium" (optional)
    }
    Returns: audio/wav file
    """
    try:
        data = request.get_json()
        text = data.get('text', '')
        speed = data.get('speed', 1.0)
        
        if not text:
            return jsonify({'error': 'Text is required'}), 400
        
        # Validate speed
        speed = max(0.5, min(2.0, float(speed)))
        
        # Model path
        model_path = f"{PIPER_MODELS_DIR}/{DEFAULT_MODEL}.onnx"
        
        if not os.path.exists(model_path):
            logger.error(f"Model not found: {model_path}")
            return jsonify({'error': 'TTS model not found'}), 500
        
        # Create temporary output file
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_audio:
            output_path = tmp_audio.name
        
        # Generate speech using Piper
        cmd = [
            'piper',
            '--model', model_path,
            '--output_file', output_path,
            '--length_scale', str(1.0 / speed)  # Inverse for Piper
        ]
        
        # Run Piper
        process = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        stdout, stderr = process.communicate(input=text)
        
        if process.returncode != 0:
            logger.error(f"Piper failed: {stderr}")
            return jsonify({'error': 'TTS generation failed'}), 500
        
        # Return audio file
        return send_file(
            output_path,
            mimetype='audio/wav',
            as_attachment=True,
            download_name='speech.wav'
        )
        
    except Exception as e:
        logger.error(f"TTS error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/voices', methods=['GET'])
def list_voices():
    """List available voices"""
    try:
        models = []
        if os.path.exists(PIPER_MODELS_DIR):
            for file in os.listdir(PIPER_MODELS_DIR):
                if file.endswith('.onnx'):
                    models.append(file.replace('.onnx', ''))
        
        return jsonify({
            'voices': models,
            'default': DEFAULT_MODEL
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    logger.info(f"🎤 Starting Piper TTS service on port 5001...")
    logger.info(f"📁 Models directory: {PIPER_MODELS_DIR}")
    app.run(host='0.0.0.0', port=5001, debug=False)
