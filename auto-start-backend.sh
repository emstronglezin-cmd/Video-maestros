#!/bin/bash
# Video Maestro - Auto-Start Backend Script
# Ce script démarre automatiquement le backend sans commande manuelle

set -e

echo "🎬 Video Maestro - Démarrage Automatique Backend"
echo "================================================"

# Configuration
BACKEND_DIR="/home/user/video-editor-backend"
LOG_FILE="/tmp/video-maestro-backend.log"

# Vérifier si le backend existe
if [ ! -d "$BACKEND_DIR" ]; then
    echo "❌ Backend directory not found: $BACKEND_DIR"
    exit 1
fi

# Aller dans le répertoire backend
cd "$BACKEND_DIR"

# Vérifier si déjà compilé
if [ ! -d "dist" ]; then
    echo "📦 Compilation backend..."
    npm run build > "$LOG_FILE" 2>&1
    echo "✅ Backend compilé"
fi

# Vérifier si .env existe
if [ ! -f ".env" ]; then
    echo "⚠️  Création .env depuis .env.example"
    cp .env.example .env
fi

# Vérifier Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js non installé"
    exit 1
fi

# Vérifier PM2
if ! command -v pm2 &> /dev/null; then
    echo "📦 Installation PM2..."
    npm install -g pm2
fi

# Arrêter instance existante
pm2 delete video-editor-backend 2>/dev/null || true

# Démarrer avec PM2
echo "🚀 Démarrage backend avec PM2..."
pm2 start ecosystem.config.js

# Sauvegarder configuration PM2
pm2 save

# Configurer auto-start système (systemd)
pm2 startup > /tmp/pm2-startup.sh 2>&1
if [ -f /tmp/pm2-startup.sh ]; then
    echo "✅ Configuration auto-start système"
fi

echo ""
echo "================================================"
echo "✅ Backend démarré automatiquement !"
echo "================================================"
echo ""
echo "📊 Status:"
pm2 status

echo ""
echo "📝 Logs en temps réel:"
echo "   pm2 logs video-editor-backend"
echo ""
echo "🔄 Redémarrer:"
echo "   pm2 restart video-editor-backend"
echo ""
echo "🛑 Arrêter:"
echo "   pm2 stop video-editor-backend"
echo ""
echo "🌐 Backend URL: http://localhost:3000"
echo "🏥 Health Check: http://localhost:3000/api/health"
echo ""
