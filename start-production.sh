#!/bin/bash

# Video Maestro Backend - Production Startup Script
# This script builds and starts the backend with PM2

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     🚀 Video Maestro Backend - Production Startup          ║"
echo "╚════════════════════════════════════════════════════════════╝"

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found"
    echo "Please create .env from .env.example"
    exit 1
fi

# Check critical environment variables
echo "🔍 Checking environment variables..."
source .env

REQUIRED_VARS=("PORT" "REDIS_HOST" "REDIS_PORT" "OLLAMA_URL")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "❌ Error: Missing required environment variables:"
    printf '   - %s\n' "${MISSING_VARS[@]}"
    exit 1
fi

echo "✅ All required environment variables present"

# Create necessary directories
echo "📂 Creating directories..."
mkdir -p uploads outputs logs

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install --cache /tmp/npm-cache
fi

# Build TypeScript
echo "🔨 Building TypeScript..."
npm run build

# Check if build succeeded
if [ ! -f "dist/app.js" ]; then
    echo "❌ Error: Build failed - dist/app.js not found"
    exit 1
fi

echo "✅ Build successful"

# Stop existing PM2 process if running
echo "🛑 Stopping existing PM2 process..."
npx pm2 stop video-maestro-backend 2>/dev/null || true
npx pm2 delete video-maestro-backend 2>/dev/null || true

# Start with PM2
echo "🚀 Starting backend with PM2..."
npx pm2 start ecosystem.config.js

# Save PM2 configuration for auto-start on reboot
echo "💾 Saving PM2 configuration..."
npx pm2 save

# Setup PM2 startup script (requires sudo)
echo "⚙️  To enable auto-start on system boot, run:"
echo "    sudo pm2 startup"
echo "    sudo pm2 save"

# Show status
echo ""
echo "✅ Backend started successfully!"
echo ""
npx pm2 status
echo ""
echo "📊 View logs:"
echo "   pm2 logs video-maestro-backend"
echo ""
echo "🔄 Restart:"
echo "   pm2 restart video-maestro-backend"
echo ""
echo "🛑 Stop:"
echo "   pm2 stop video-maestro-backend"
