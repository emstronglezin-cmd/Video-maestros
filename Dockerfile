# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🎬 VIDEO MAESTRO BACKEND - RENDER FREE TIER OPTIMIZED
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 1: BUILDER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FROM node:20-bullseye AS builder

WORKDIR /build
COPY package*.json ./
RUN npm ci --include=dev --no-audit --no-fund
COPY . .
RUN npm run build
RUN ls -la /build/dist && \
    test -f /build/dist/app.js || (echo "❌ Build failed: dist/app.js not found" && exit 1)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 2: RUNTIME
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FROM node:20-bullseye-slim

ENV NODE_ENV=production \
    NODE_OPTIONS="--max-old-space-size=384" \
    NPM_CONFIG_LOGLEVEL=error

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SYSTEM DEPENDENCIES — libsndfile1 ajouté pour fix erreur 'av'
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libsndfile1 \
    libsndfile1-dev \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    curl \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

RUN ffmpeg -version && ffprobe -version

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PYTHON ENVIRONMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY python_services/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# APPLICATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production --no-audit --no-fund
COPY --from=builder /build/dist ./dist
COPY python_services ./python_services
COPY .env.example ./.env.example

RUN mkdir -p \
    /app/uploads \
    /app/outputs \
    /app/temp \
    /app/logs \
    /opt/whisper/models

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DOWNLOAD WHISPER TINY MODEL (50MB)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RUN python3 -c "from faster_whisper import WhisperModel; \
    print('📥 Downloading Whisper tiny model...'); \
    model = WhisperModel('tiny', download_root='/opt/whisper/models', device='cpu', compute_type='int8'); \
    print('✅ Whisper tiny model ready')" || \
    echo "⚠️  Whisper model download failed - will retry at runtime"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STARTUP SCRIPT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RUN printf '#!/bin/bash\nset -e\n\
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"\n\
echo "🎬 VIDEO MAESTRO - RENDER FREE TIER"\n\
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"\n\
echo "🌐 Port: ${PORT:-3000}"\n\
command -v node >/dev/null || { echo "❌ Node.js not found"; exit 1; }\n\
command -v ffmpeg >/dev/null || { echo "❌ FFmpeg not found"; exit 1; }\n\
command -v python3 >/dev/null || { echo "❌ Python3 not found"; exit 1; }\n\
test -f /app/dist/app.js || { echo "❌ dist/app.js not found"; exit 1; }\n\
echo "✅ All dependencies verified"\n\
if [ -f "/app/python_services/whisper_service.py" ]; then\n\
  echo "🎙️ Starting Whisper service..."\n\
  python3 /app/python_services/whisper_service.py > /app/logs/whisper.log 2>&1 &\n\
fi\n\
echo "⏳ Waiting 5s for services..."\n\
sleep 5\n\
echo "🚀 Starting Node.js backend..."\n\
exec node dist/app.js\n' > /app/start.sh && chmod +x /app/start.sh

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENV VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ENV PORT=3000 \
    UPLOAD_DIR=/app/uploads \
    OUTPUT_DIR=/app/outputs \
    TEMP_DIR=/app/temp \
    WHISPER_SERVICE_URL=http://localhost:5002 \
    WHISPER_MODEL_SIZE=tiny \
    WHISPER_MODELS_DIR=/opt/whisper/models \
    FFMPEG_BINARY=ffmpeg \
    FFPROBE_BINARY=ffprobe

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000}/api/health || exit 1

CMD ["/app/start.sh"]
