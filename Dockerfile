# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🎬 VIDEO MAESTRO BACKEND - RENDER FREE TIER OPTIMIZED
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Production-ready Docker image for Render.com FREE tier
# Optimized: 512MB RAM, 0.1 vCPU, no persistent storage
# Stack: Node.js 20 + FFmpeg + Faster-Whisper tiny + Piper TTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 1: BUILDER - Build TypeScript application
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FROM node:20-bullseye AS builder

WORKDIR /build

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including devDependencies for TypeScript build)
RUN npm ci --include=dev --no-audit --no-fund

# Copy source code
COPY . .

# Build TypeScript to JavaScript
RUN npm run build

# Verify build output
RUN ls -la /build/dist && \
    test -f /build/dist/app.js || (echo "❌ Build failed: dist/app.js not found" && exit 1)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 2: RUNTIME - Lightweight production image
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FROM node:20-bullseye-slim

# Memory optimization for Render FREE tier (512MB RAM)
ENV NODE_ENV=production \
    NODE_OPTIONS="--max-old-space-size=384" \
    NPM_CONFIG_LOGLEVEL=error

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INSTALL SYSTEM DEPENDENCIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RUN apt-get update && apt-get install -y --no-install-recommends \
    # FFmpeg for video processing
    ffmpeg \
    # Python 3 for AI services
    python3 \
    python3-pip \
    python3-venv \
    # Build tools for native modules
    build-essential \
    # Network tools
    curl \
    wget \
    ca-certificates \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Verify FFmpeg installation
RUN ffmpeg -version && ffprobe -version

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SETUP PYTHON ENVIRONMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python AI services (LIGHTWEIGHT - CPU only)
COPY python_services/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SETUP APPLICATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install PRODUCTION dependencies only
RUN npm ci --only=production --no-audit --no-fund

# Copy built application from builder stage
COPY --from=builder /build/dist ./dist

# Copy Python services
COPY python_services ./python_services

# Copy configuration files
COPY .env.example ./.env.example

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CREATE DIRECTORIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RUN mkdir -p \
    /app/uploads \
    /app/outputs \
    /app/temp \
    /app/logs \
    /opt/whisper/models \
    /opt/piper/models

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DOWNLOAD AI MODELS (Whisper TINY - 50MB)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RUN python3 -c "from faster_whisper import WhisperModel; \
    print('📥 Downloading Whisper tiny model...'); \
    model = WhisperModel('tiny', download_root='/opt/whisper/models', device='cpu', compute_type='int8'); \
    print('✅ Whisper tiny model downloaded successfully')" || \
    echo "⚠️  Whisper model download failed - will retry at runtime"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CREATE STARTUP SCRIPT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"\n\
echo "🎬 VIDEO MAESTRO BACKEND - RENDER FREE TIER"\n\
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"\n\
echo "📊 Memory: NODE_OPTIONS=$NODE_OPTIONS"\n\
echo "🌐 Port: ${PORT:-3000}"\n\
echo "📁 Upload: ${UPLOAD_DIR:-/app/uploads}"\n\
echo "📁 Output: ${OUTPUT_DIR:-/app/outputs}"\n\
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"\n\
\n\
# Verify critical dependencies\n\
echo "🔍 Verifying dependencies..."\n\
command -v node >/dev/null 2>&1 || { echo "❌ Node.js not found"; exit 1; }\n\
command -v ffmpeg >/dev/null 2>&1 || { echo "❌ FFmpeg not found"; exit 1; }\n\
command -v python3 >/dev/null 2>&1 || { echo "❌ Python3 not found"; exit 1; }\n\
test -f /app/dist/app.js || { echo "❌ dist/app.js not found"; exit 1; }\n\
echo "✅ All dependencies verified"\n\
\n\
# Start Python AI services (background, non-blocking)\n\
if [ -f "/app/python_services/whisper_service.py" ]; then\n\
  echo "🎙️ Starting Whisper service (tiny model, CPU)..."\n\
  python3 /app/python_services/whisper_service.py > /app/logs/whisper.log 2>&1 &\n\
  echo "✅ Whisper service started (background)"\n\
else\n\
  echo "⚠️  Whisper service not found - transcription disabled"\n\
fi\n\
\n\
if [ -f "/app/python_services/piper_service.py" ]; then\n\
  echo "🎤 Starting Piper TTS service..."\n\
  python3 /app/python_services/piper_service.py > /app/logs/piper.log 2>&1 &\n\
  echo "✅ Piper TTS service started (background)"\n\
else\n\
  echo "⚠️  Piper TTS service not found - TTS disabled"\n\
fi\n\
\n\
# Wait for services initialization\n\
echo "⏳ Waiting for services initialization (5s)..."\n\
sleep 5\n\
\n\
# Start Node.js backend (foreground)\n\
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"\n\
echo "🚀 Starting Node.js backend..."\n\
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"\n\
exec node dist/app.js\n\
' > /app/start.sh && chmod +x /app/start.sh

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENVIRONMENT VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ENV PORT=3000 \
    UPLOAD_DIR=/app/uploads \
    OUTPUT_DIR=/app/outputs \
    TEMP_DIR=/app/temp \
    # Python AI services
    TTS_SERVICE_URL=http://localhost:5001 \
    WHISPER_SERVICE_URL=http://localhost:5002 \
    WHISPER_MODEL_SIZE=tiny \
    WHISPER_MODELS_DIR=/opt/whisper/models \
    # FFmpeg paths
    FFMPEG_BINARY=ffmpeg \
    FFPROBE_BINARY=ffprobe \
    # Render compatibility
    NODE_ENV=production

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EXPOSE PORT & HEALTHCHECK
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000}/api/health || exit 1

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# START APPLICATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CMD ["/app/start.sh"]
