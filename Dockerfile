# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🎬 VIDEO MAESTRO - RENDER FREE TIER OPTIMIZED
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Optimisé pour Render Free: 512MB RAM, 0.1 vCPU
# Services légers uniquement - SANS Ollama
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FROM node:20-slim

# Variables d'environnement pour optimisation mémoire
ENV NODE_ENV=production \
    NODE_OPTIONS="--max-old-space-size=384" \
    NPM_CONFIG_LOGLEVEL=error

# Installation dépendances système (léger)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # FFmpeg (video processing)
    ffmpeg \
    # Python léger pour services IA
    python3.11 \
    python3-pip \
    python3-venv \
    # Build tools minimaux
    build-essential \
    curl \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Créer app directory
WORKDIR /app

# Créer Python virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Installer Python dependencies (LÉGER - pas de torch complet)
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    # Faster-Whisper TINY (modèle léger)
    faster-whisper==1.0.3 \
    # Piper TTS léger
    piper-tts==1.2.0 \
    # Flask pour services
    flask==3.0.0 \
    # Numpy léger
    numpy==1.26.4

# Copier package files
COPY package*.json ./

# Installer Node dependencies (production uniquement)
RUN npm ci --only=production --no-audit --no-fund

# Copier source code
COPY . .

# Build TypeScript
RUN npm run build

# Créer directories nécessaires
RUN mkdir -p \
    /app/uploads \
    /app/outputs \
    /app/temp \
    /app/logs \
    /opt/whisper/models

# Télécharger modèle Whisper TINY (50MB au lieu de 400MB)
RUN python3 -c "from faster_whisper import WhisperModel; WhisperModel('tiny', download_root='/opt/whisper/models', device='cpu', compute_type='int8')"

# Note: Piper models téléchargés au runtime pour économiser space

# Créer script de démarrage optimisé
RUN echo '#!/bin/bash\n\
set -e\n\
echo "🚀 Starting Video Maestro Backend (Render Free Tier)..."\n\
echo "📊 Memory optimization: NODE_OPTIONS=$NODE_OPTIONS"\n\
\n\
# Start Faster-Whisper service (background)\n\
if [ -f "/app/python_services/whisper_service.py" ]; then\n\
  echo "🎙️ Starting Whisper service (tiny model)..."\n\
  python3 /app/python_services/whisper_service.py &\n\
  WHISPER_PID=$!\n\
  echo "✅ Whisper service started (PID: $WHISPER_PID)"\n\
else\n\
  echo "⚠️  Whisper service not found, skipping"\n\
fi\n\
\n\
# Start Piper TTS service (background) - optional\n\
if [ -f "/app/python_services/piper_service.py" ]; then\n\
  echo "🎤 Starting Piper TTS service..."\n\
  python3 /app/python_services/piper_service.py &\n\
  PIPER_PID=$!\n\
  echo "✅ Piper service started (PID: $PIPER_PID)"\n\
else\n\
  echo "⚠️  Piper service not found, skipping"\n\
fi\n\
\n\
# Wait for services to initialize\n\
sleep 3\n\
\n\
# Start Node.js backend\n\
echo "🎬 Starting Node.js backend..."\n\
node dist/app.js\n\
' > /app/start.sh && chmod +x /app/start.sh

# Environment variables
ENV PORT=3000 \
    UPLOAD_DIR=/app/uploads \
    OUTPUT_DIR=/app/outputs \
    TTS_SERVICE_URL=http://localhost:5001 \
    WHISPER_SERVICE_URL=http://localhost:5002 \
    WHISPER_MODEL_SIZE=tiny \
    WHISPER_MODELS_DIR=/opt/whisper/models \
    FFMPEG_BINARY=ffmpeg \
    FFPROBE_BINARY=ffprobe

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/api/health || exit 1

# Start application
CMD ["/app/start.sh"]
