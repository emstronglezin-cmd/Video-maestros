#!/bin/bash

# Video Maestro Backend - Auto-Start Local (Gratuit)
# Script qui démarre le backend automatiquement sans VPS payant

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     🚀 Video Maestro Backend - Démarrage Automatique       ║"
echo "║                    (Solution Locale Gratuite)             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ==============================================================================
# VÉRIFICATION ENVIRONNEMENT
# ==============================================================================

echo -e "${BLUE}📋 Vérification environnement...${NC}"

# Vérifier Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js non installé${NC}"
    echo "Installation requise: https://nodejs.org/"
    exit 1
fi

# Vérifier npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ npm non installé${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Node.js: $(node --version)${NC}"
echo -e "${GREEN}✅ npm: $(npm --version)${NC}"

# ==============================================================================
# VÉRIFICATION .env
# ==============================================================================

echo ""
echo -e "${BLUE}🔍 Vérification configuration...${NC}"

if [ ! -f .env ]; then
    echo -e "${RED}❌ Fichier .env non trouvé${NC}"
    echo "Création depuis .env.example..."
    cp .env.example .env
    echo -e "${YELLOW}⚠️  IMPORTANT: Éditez .env avec vos credentials Firebase${NC}"
fi

# Vérifier variables critiques
source .env 2>/dev/null || true

REQUIRED_VARS=("PORT" "REDIS_HOST" "FIREBASE_PROJECT_ID")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Variables manquantes dans .env:${NC}"
    printf '   - %s\n' "${MISSING_VARS[@]}"
    echo ""
    echo "Le backend démarrera en mode dégradé (sans Firebase Admin SDK)"
fi

echo -e "${GREEN}✅ Configuration chargée${NC}"

# ==============================================================================
# CRÉATION RÉPERTOIRES
# ==============================================================================

echo ""
echo -e "${BLUE}📂 Création répertoires...${NC}"

mkdir -p uploads outputs logs /tmp/video-maestro/uploads /tmp/video-maestro/outputs

echo -e "${GREEN}✅ Répertoires créés${NC}"

# ==============================================================================
# INSTALLATION DÉPENDANCES
# ==============================================================================

echo ""
echo -e "${BLUE}📦 Vérification dépendances...${NC}"

if [ ! -d "node_modules" ]; then
    echo "Installation dépendances npm..."
    npm install --cache /tmp/npm-cache --loglevel=error
    echo -e "${GREEN}✅ Dépendances installées${NC}"
else
    echo -e "${GREEN}✅ Dépendances déjà présentes${NC}"
fi

# ==============================================================================
# BUILD TYPESCRIPT
# ==============================================================================

echo ""
echo -e "${BLUE}🔨 Compilation TypeScript...${NC}"

if npm run build; then
    echo -e "${GREEN}✅ Build réussi${NC}"
else
    echo -e "${RED}❌ Erreur compilation${NC}"
    exit 1
fi

# Vérifier que dist existe
if [ ! -f "dist/app.js" ]; then
    echo -e "${RED}❌ dist/app.js non trouvé après build${NC}"
    exit 1
fi

# ==============================================================================
# SOLUTION GRATUITE: PM2 LOCAL (Sans VPS Payant)
# ==============================================================================

echo ""
echo -e "${BLUE}🚀 Démarrage backend (Solution locale gratuite)...${NC}"
echo ""
echo -e "${YELLOW}💡 Ce backend tourne LOCALEMENT (aucun VPS payant)${NC}"
echo -e "${YELLOW}   Pour accès externe, utilisez ngrok (gratuit):${NC}"
echo -e "${YELLOW}   → npx ngrok http 3000${NC}"
echo ""

# Arrêter process existant si présent
pkill -f "node dist/app.js" 2>/dev/null || true
sleep 1

# Démarrer en arrière-plan avec nohup (gratuit, local)
nohup node dist/app.js > logs/backend.log 2>&1 &
BACKEND_PID=$!

echo -e "${GREEN}✅ Backend démarré (PID: $BACKEND_PID)${NC}"
echo ""

# Attendre que le serveur démarre
echo "⏳ Attente démarrage serveur..."
sleep 3

# Vérifier que le process tourne
if ps -p $BACKEND_PID > /dev/null; then
    echo -e "${GREEN}✅ Process actif${NC}"
else
    echo -e "${RED}❌ Process terminé immédiatement${NC}"
    echo "Logs:"
    tail -20 logs/backend.log
    exit 1
fi

# Test santé
echo ""
echo "🔍 Test connexion..."
if curl -s http://localhost:3000/api/health > /dev/null; then
    echo -e "${GREEN}✅ API répond correctement${NC}"
else
    echo -e "${YELLOW}⚠️  API ne répond pas encore (normal si Redis/Ollama manquants)${NC}"
fi

# ==============================================================================
# INFORMATIONS FINALES
# ==============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              ✅ BACKEND DÉMARRÉ AVEC SUCCÈS                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}📍 API locale:${NC} http://localhost:3000"
echo -e "${GREEN}📊 Health:${NC} http://localhost:3000/api/health"
echo ""
echo -e "${BLUE}📋 Commandes utiles:${NC}"
echo "   Voir logs:       tail -f logs/backend.log"
echo "   Arrêter:         pkill -f 'node dist/app.js'"
echo "   Redémarrer:      ./auto-start-local.sh"
echo ""
echo -e "${YELLOW}💡 Solution gratuite (local):${NC}"
echo "   Le backend tourne sur votre machine (aucun VPS payant)"
echo "   Pour accès externe: npx ngrok http 3000"
echo ""
echo -e "${YELLOW}🔮 Migration VPS future:${NC}"
echo "   Le code est prêt pour VPS"
echo "   Utilisez ./start-production.sh sur le VPS"
echo ""

# Sauvegarder PID pour arrêt futur
echo $BACKEND_PID > logs/backend.pid

echo -e "${GREEN}✅ Backend opérationnel !${NC}"
