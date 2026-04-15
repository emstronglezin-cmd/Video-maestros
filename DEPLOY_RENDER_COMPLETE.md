# 🚀 VIDEO MAESTRO V3 - Guide de Déploiement Render.com (100% Open Source)

**Date**: 15 Avril 2025  
**Version**: V3.0.0 Production  
**Coût total**: 0 € / mois (100% gratuit)

---

## 📋 TABLE DES MATIÈRES

1. [Architecture Complète](#architecture)
2. [Pré-requis](#prérequis)
3. [Déploiement Backend (Node.js + Python)](#backend)
4. [Déploiement Frontend (Flutter Web)](#frontend)
5. [Configuration Environnement](#config)
6. [Tests & Validation](#tests)
7. [Monitoring & Maintenance](#monitoring)

---

## 🏗️ ARCHITECTURE COMPLÈTE {#architecture}

```
┌─────────────────────────────────────────────────────────────────┐
│                    VIDEO MAESTRO V3 - ARCHITECTURE              │
│                         (Zero-Cost Stack)                       │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────┐       HTTPS       ┌──────────────────────┐
│   Flutter Web App    │ ◄───────────────► │   Node.js Backend    │
│  (Static Hosting)    │                   │   (Web Service)      │
│                      │                   │                      │
│  • PWA Ready         │                   │  • Express Server    │
│  • 31 MB Build       │                   │  • Port 3000         │
│  • Responsive UI     │                   │  • Firebase Auth     │
└──────────────────────┘                   │  • File Upload       │
                                           └───────┬──────────────┘
                                                   │
                                           ┌───────┴──────────────┐
                                           │   Python Services    │
                                           │   (Subprocess)       │
                                           ├──────────────────────┤
                                           │  • Piper TTS         │
                                           │    Port: 5001        │
                                           │  • Faster-Whisper    │
                                           │    Port: 5002        │
                                           └──────────────────────┘
                                                   │
                                           ┌───────┴──────────────┐
                                           │   Redis Server       │
                                           │   (Local Instance)   │
                                           │   Port: 6379         │
                                           └──────────────────────┘
                                                   │
                                           ┌───────┴──────────────┐
                                           │   File Storage       │
                                           │   (Local Filesystem) │
                                           │   /opt/render/       │
                                           │   Auto-cleanup: 7d   │
                                           └──────────────────────┘
```

---

## ✅ PRÉ-REQUIS {#prérequis}

### 1. Compte Render.com
- Créer un compte gratuit: https://render.com/register
- Pas de carte bancaire requise pour le plan gratuit

### 2. Repository GitHub
- Repository: https://github.com/emstronglezin-cmd/Video-maestros
- Branch Backend: `main`
- Branch Flutter: `flutter`

### 3. Variables Firebase (Optionnel)
Si vous utilisez Firebase Authentication:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

---

## 🔧 DÉPLOIEMENT BACKEND {#backend}

### **Service 1: Node.js Backend + Python Services**

#### Step 1: Créer un Web Service
1. Dashboard Render → **New** → **Web Service**
2. Connecter GitHub repository: `Video-maestros`
3. Sélectionner branch: `main`

#### Step 2: Configuration Service

**Basic Info:**
- **Name**: `video-maestro-backend`
- **Region**: `Frankfurt (EU Central)` (ou le plus proche)
- **Branch**: `main`
- **Root Directory**: `video-editor-backend`

**Build & Deploy:**
- **Build Command**:
```bash
# Install Node.js dependencies
npm install

# Install Python and dependencies
python3 -m pip install --user -r python_services/requirements.txt

# Download Piper TTS models (French & English)
mkdir -p /opt/piper/models
wget -O /opt/piper/models/fr_FR-siwis-medium.onnx https://github.com/rhasspy/piper/releases/download/v1.0.0/fr_FR-siwis-medium.onnx
wget -O /opt/piper/models/fr_FR-siwis-medium.onnx.json https://github.com/rhasspy/piper/releases/download/v1.0.0/fr_FR-siwis-medium.onnx.json

# Install Redis
apt-get update && apt-get install -y redis-server

# Build TypeScript
npm run build
```

- **Start Command**:
```bash
# Start Redis server in background
redis-server --daemonize yes --port 6379

# Start Python TTS Service (port 5001)
cd python_services && python3 piper_tts_service.py &

# Start Python Whisper Service (port 5002)
cd python_services && python3 faster_whisper_service.py &

# Wait for Python services to be ready
sleep 5

# Start Node.js Backend
cd .. && npm start
```

**Environment:**
- **Runtime**: `Node`
- **Plan**: `Free` (512 MB RAM, suspend après 15 min inactivité)

**Environment Variables** (optionnel):
```
PORT=3000
REDIS_HOST=localhost
REDIS_PORT=6379
OLLAMA_URL=http://localhost:11434
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=your-client-email
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

#### Step 3: Déployer
- Cliquer sur **Create Web Service**
- Attendre 10-15 minutes pour le premier build
- Backend URL: `https://video-maestro-backend.onrender.com`

---

## 🌐 DÉPLOIEMENT FRONTEND {#frontend}

### **Service 2: Flutter Web (Static Site)**

#### Step 1: Créer un Static Site
1. Dashboard Render → **New** → **Static Site**
2. Connecter GitHub repository: `Video-maestros`
3. Sélectionner branch: `flutter`

#### Step 2: Configuration Service

**Basic Info:**
- **Name**: `video-maestro-web`
- **Region**: `Frankfurt (EU Central)`
- **Branch**: `flutter`
- **Root Directory**: `flutter_app`

**Build & Deploy:**
- **Build Command**:
```bash
# Update apt-get
apt-get update

# Install Flutter dependencies (déjà pré-installé sur Render)
flutter pub get

# Build for web
flutter build web --release
```

- **Publish Directory**: `build/web`

**Environment Variables:**
```
API_URL=https://video-maestro-backend.onrender.com
```

**Headers (CORS):**
```
/*
  Access-Control-Allow-Origin: *
  X-Frame-Options: ALLOWALL
  Content-Security-Policy: frame-ancestors *
```

#### Step 3: Déployer
- Cliquer sur **Create Static Site**
- Attendre 5-10 minutes pour le build
- Frontend URL: `https://video-maestro-web.onrender.com`

---

## ⚙️ CONFIGURATION ENVIRONNEMENT {#config}

### Backend Environment Variables Complet

| Variable | Description | Requis | Défaut |
|----------|-------------|--------|--------|
| `PORT` | Port Node.js | Non | `3000` |
| `UPLOAD_DIR` | Dossier uploads | Non | `uploads` |
| `OUTPUT_DIR` | Dossier outputs | Non | `outputs` |
| `REDIS_HOST` | Redis host | Non | `localhost` |
| `REDIS_PORT` | Redis port | Non | `6379` |
| `REDIS_ENABLED` | Activer Redis | Non | `false` |
| `OLLAMA_URL` | Ollama API URL | Non | - |
| `OLLAMA_ENABLED` | Activer Ollama | Non | `false` |
| `FIREBASE_PROJECT_ID` | Firebase Project | Oui* | - |
| `FIREBASE_CLIENT_EMAIL` | Firebase Email | Oui* | - |
| `FIREBASE_PRIVATE_KEY` | Firebase Key | Oui* | - |

*Requis uniquement si vous utilisez Firebase Authentication

### Frontend Configuration

**lib/services/api_service.dart:**
```dart
class ApiService {
  static const String baseUrl = 'https://video-maestro-backend.onrender.com';
  // ...
}
```

---

## 🧪 TESTS & VALIDATION {#tests}

### 1. Test Backend Health
```bash
curl https://video-maestro-backend.onrender.com/api/health
```
**Réponse attendue:**
```json
{
  "status": "OK",
  "timestamp": "2025-04-15T...",
  "services": {
    "ollama": false,
    "redis": true,
    "piper_tts": true,
    "faster_whisper": true
  }
}
```

### 2. Test Upload
```bash
curl -X POST https://video-maestro-backend.onrender.com/api/upload \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "files=@test.mp4"
```

### 3. Test TTS Generation
```bash
curl -X POST https://video-maestro-backend.onrender.com/api/v3/tts/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "text": "Bonjour, ceci est un test",
    "language": "fr",
    "style": "professional",
    "speed": 1.0,
    "volume": 1.0
  }'
```

### 4. Test Flutter Web
1. Ouvrir: https://video-maestro-web.onrender.com
2. Vérifier que tous les écrans chargent:
   - ✅ Home (Create Video)
   - ✅ My Videos
   - ✅ Profile
   - ✅ TTS Controls
   - ✅ Marketplace

---

## 📊 MONITORING & MAINTENANCE {#monitoring}

### Monitoring Automatique
Le backend inclut un système de monitoring 24/7:

**Métriques surveillées:**
- CPU Usage (%)
- Memory Usage (MB / %)
- Disk Usage (GB / %)
- Request Count
- Error Count

**Alertes automatiques:**
- Memory > 90% → Critical
- Error Rate > 10% → Critical
- Rapports automatiques toutes les 10 minutes

**Logs disponibles:**
- Render Dashboard → Service → Logs
- Real-time streaming
- 7 jours d'historique

### Nettoyage Automatique
**Fichiers temporaires:**
- Suppression automatique après 7 jours
- Cron job: `0 3 * * *` (3h du matin)
- Répertoires nettoyés: `uploads/`, `outputs/`

### Scaling & Performance
**Plan Gratuit Render:**
- CPU: Partagé
- RAM: 512 MB
- Disk: 5 GB (temporaire)
- Bandwidth: Illimité
- Suspend: 15 minutes inactivité
- Cold start: ~30 secondes

**Upgrade Options (si besoin):**
- Starter: $7/mois (512 MB RAM, always-on)
- Standard: $25/mois (2 GB RAM, priority)
- Pro: $85/mois (4 GB RAM, SLA 99.95%)

---

## 🔐 SÉCURITÉ

**Implémentations:**
- ✅ Firebase ID Token Verification
- ✅ Rate Limiting (3-level)
  - Global: 1000 req/15 min
  - Upload: 10 req/1 min
  - Critical: 30 req/1 min
- ✅ XSS Protection
- ✅ SQL Injection Prevention
- ✅ Path Traversal Protection
- ✅ CORS Configuration
- ✅ Helmet Security Headers
- ✅ File Upload Validation (200 MB max)
- ✅ MIME Type Verification

**Best Practices:**
- Tokens expirés automatiquement (Firebase)
- Pas de credentials en clair dans le code
- Environment variables pour secrets
- HTTPS enforced

---

## 💰 COÛT TOTAL

### Avant (Stack Payant)
- ElevenLabs TTS: ~45 €/mois
- AssemblyAI: ~30 €/mois
- Upstash Redis: ~8 €/mois
- Cloudinary: ~25 €/mois
- **Total: ~108 €/mois (~1300 €/an)**

### Après (Stack Open Source)
- Piper TTS: **0 € (Open Source)**
- Faster-Whisper: **0 € (Open Source)**
- Redis Local: **0 € (Self-hosted)**
- File Storage: **0 € (Render filesystem)**
- Render Free Plan: **0 € (512 MB RAM)**
- **Total: 0 €/mois (0 €/an) ✅**

**Économie annuelle: 1300 € !**

---

## 🎯 URLS FINALES

**Production:**
- Backend API: https://video-maestro-backend.onrender.com
- Flutter Web: https://video-maestro-web.onrender.com
- GitHub Repo: https://github.com/emstronglezin-cmd/Video-maestros

**Branches:**
- Backend: `main` (commit: 2693b9e)
- Flutter: `flutter` (commit: cbc756c)

**Documentation:**
- `render.yaml` - Configuration complète
- `DEPLOY_RENDER_OPEN_SOURCE.md` - Guide détaillé
- `RESUME_OPEN_SOURCE.txt` - Résumé du projet

---

## 🆘 SUPPORT & TROUBLESHOOTING

### Problème: Backend ne démarre pas
**Solution:**
1. Vérifier les logs Render
2. Confirmer que Python services démarrent
3. Vérifier Redis: `redis-cli ping`

### Problème: Flutter Web ne charge pas
**Solution:**
1. Vérifier le build logs
2. Confirmer que `build/web/` est généré
3. Vérifier CORS headers

### Problème: TTS ne fonctionne pas
**Solution:**
1. Vérifier que Piper models sont téléchargés
2. Confirmer port 5001 disponible
3. Tester: `curl http://localhost:5001/health`

---

## ✅ CHECKLIST DE DÉPLOIEMENT

- [ ] Compte Render.com créé
- [ ] Repository GitHub connecté
- [ ] Backend Web Service créé
- [ ] Flutter Static Site créé
- [ ] Environment variables configurées
- [ ] Backend health check OK
- [ ] Flutter Web accessible
- [ ] TTS generation testée
- [ ] Upload de fichiers testé
- [ ] Monitoring actif
- [ ] Documentation à jour

---

**🎉 Félicitations! Video Maestro V3 est maintenant déployé en production avec un coût de 0 €/mois !**

*Document créé le: 15 Avril 2025*  
*Dernière mise à jour: 15 Avril 2025*
