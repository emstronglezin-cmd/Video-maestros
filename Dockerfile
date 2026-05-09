# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🎬 VIDEO MAESTRO V3 - PRODUCTION DOCKERFILE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Open Source Stack:
#   - Node.js 20 LTS
#   - FFmpeg (video processing)
#   - Python 3.11 + pip
#   - Piper TTS (text-to-speech)
#   - Faster-Whisper (transcription)
#   - Ollama (optional AI)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FROM node:20-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # FFmpeg for video processing
    ffmpeg \
    # Python for AI services
    python3.11 \
    python3-pip \
    python3-venv \
    # Build tools
    build-essential \
    curl \
    wget \
    git \
    # Cleanup
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Create Python virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies for AI services
RUN pip install --no-cache-dir \
    # Faster-Whisper for transcription
    faster-whisper==1.0.3 \
    # Piper TTS dependencies
    piper-tts==1.2.0 \
    # Flask for Python services
    flask==3.0.0 \
    # Utilities
    numpy==1.26.4 \
    torch==2.1.0 \
    torchaudio==2.1.0

# Copy package files
COPY package*.json ./

# Install Node.js dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Build TypeScript
RUN npm run build

# Create necessary directories
RUN mkdir -p /app/uploads /app/outputs /app/temp /app/logs \
    /opt/piper/models /opt/whisper/models

# Download Piper TTS models (lightweight French model)
RUN wget -q -O /opt/piper/models/fr_FR-upmc-medium.onnx \
    https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR/upmc/medium/fr_FR-upmc-medium.onnx && \
    wget -q -O /opt/piper/models/fr_FR-upmc-medium.onnx.json \
    https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR/upmc/medium/fr_FR-upmc-medium.onnx.json

# Download Faster-Whisper model (base model for speed/quality balance)
RUN python3 -c "from faster_whisper import WhisperModel; WhisperModel('base', download_root='/opt/whisper/models')"

# Create startup script
RUN echo '#!/bin/bash\n\
echo "🚀 Starting Video Maestro V3 Backend..."\n\
\n\
# Start Piper TTS service\n\
python3 /app/python_services/piper_service.py &\n\
echo "✅ Piper TTS service started on port 5001"\n\
\n\
# Start Faster-Whisper service\n\
python3 /app/python_services/whisper_service.py &\n\
echo "✅ Faster-Whisper service started on port 5002"\n\
\n\
# Start Ollama (optional - if configured)\n\
if [ -n "$OLLAMA_URL" ]; then\n\
  echo "⚠️  Ollama configured at: $OLLAMA_URL"\n\
fi\n\
\n\
# Start Node.js backend\n\
echo "🎬 Starting main backend server..."\n\
node dist/app.js\n\
' > /app/start.sh && chmod +x /app/start.sh

# Environment variables
ENV NODE_ENV=production \
    PORT=3000 \
    UPLOAD_DIR=/app/uploads \
    OUTPUT_DIR=/app/outputs \
    TTS_SERVICE_URL=http://localhost:5001 \
    WHISPER_SERVICE_URL=http://localhost:5002 \
    PIPER_MODELS_DIR=/opt/piper/models \
    WHISPER_MODELS_DIR=/opt/whisper/models \
    FFMPEG_BINARY=ffmpeg \
    FFPROBE_BINARY=ffprobe

# Expose ports
EXPOSE 3000 5001 5002

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/api/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Start all services
CMD ["/app/start.sh"]
