#!/bin/bash

echo "🚀 Démarrage de Video Maestro Backend"
echo ""

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Vérifier Redis
echo -n "🔍 Vérification de Redis... "
if redis-cli ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Redis est actif${NC}"
else
    echo -e "${RED}✗ Redis n'est pas actif${NC}"
    echo -e "${YELLOW}Démarrez Redis avec: redis-server${NC}"
    exit 1
fi

# Vérifier Ollama
echo -n "🔍 Vérification d'Ollama... "
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ollama est actif${NC}"
else
    echo -e "${RED}✗ Ollama n'est pas actif${NC}"
    echo -e "${YELLOW}Démarrez Ollama et installez llama3.2:3b${NC}"
    echo -e "${YELLOW}ollama pull llama3.2:3b${NC}"
    exit 1
fi

# Vérifier FFmpeg
echo -n "🔍 Vérification de FFmpeg... "
if command -v ffmpeg > /dev/null 2>&1; then
    echo -e "${GREEN}✓ FFmpeg est installé${NC}"
else
    echo -e "${RED}✗ FFmpeg n'est pas installé${NC}"
    echo -e "${YELLOW}Installez FFmpeg: sudo apt install ffmpeg${NC}"
    exit 1
fi

# Créer les dossiers nécessaires
echo "📁 Création des dossiers..."
mkdir -p uploads outputs
echo -e "${GREEN}✓ Dossiers créés${NC}"

# Installer les dépendances si nécessaire
if [ ! -d "node_modules" ]; then
    echo "📦 Installation des dépendances..."
    npm install
fi

echo ""
echo "✨ Tout est prêt !"
echo ""
echo "🎬 Démarrage du serveur..."
echo ""

# Démarrer le serveur
npm run dev
