# 🎬 Video Maestro V3 - Open Source Edition

## 🌟 Caractéristiques

**100% Open Source & Gratuit** - Aucune clé API externe requise !

### Backend (Node.js + Python)
- ✅ **TTS**: Piper (open source) - Synthèse vocale multilingue
- ✅ **Transcription**: Faster-Whisper (open source) - Sous-titres automatiques
- ✅ **Queue**: Redis auto-hébergé (gratuit)
- ✅ **Storage**: Système de fichiers local + nettoyage automatique
- ✅ **Auth**: Firebase Authentication
- ✅ **Video**: FFmpeg pour traitement vidéo

### Frontend (Flutter Web)
- ✅ **Cross-platform**: Web + Mobile (Android/iOS)
- ✅ **Material Design 3**: Interface moderne et responsive
- ✅ **Écrans**: Home, Templates, Batch, Marketplace, TTS Controls
- ✅ **Real-time**: Suivi progression en temps réel

---

## 📦 Architecture

```
Video Maestro V3
│
├── Backend (Render Web Service)
│   ├── Node.js Express API
│   ├── Python Piper TTS (Flask)
│   ├── Python Faster-Whisper (Flask)
│   ├── Redis auto-hébergé (BullMQ)
│   └── FFmpeg (traitement vidéo)
│
├── Frontend (Render Static Site)
│   └── Flutter Web (build/web/)
│
└── Storage
    ├── Uploads (10 GB disk Render)
    ├── Outputs (auto-cleanup après 7 jours)
    └── Firebase Storage (optionnel)
```

---

## 🚀 Déploiement Render.com (Gratuit)

### Prérequis

1. **Compte Render.com** (gratuit): https://render.com
2. **Compte GitHub** avec le repository Video Maestro
3. **Compte Firebase** (gratuit): https://console.firebase.google.com

### Étape 1: Préparer Firebase

1. Créer un projet Firebase
2. Activer **Authentication** (Email/Password)
3. Activer **Firestore Database** (optionnel)
4. Générer une clé privée Admin SDK:
   - Project Settings → Service Accounts
   - Generate new private key
5. Copier les credentials:
   - `project_id`
   - `private_key`
   - `client_email`

### Étape 2: Pousser sur GitHub

```bash
# Backend (branche main)
cd video-editor-backend
git add .
git commit -m "🚀 Backend V3 Open Source ready"
git push origin main

# Flutter (branche flutter)
cd ../flutter_app
git add .
git commit -m "🌐 Flutter Web V3 ready"
git push origin flutter
```

### Étape 3: Déployer sur Render

**Option A: Via render.yaml (Automatique)**

1. Aller sur Render Dashboard
2. New → Blueprint
3. Connecter votre repository GitHub
4. Render détectera automatiquement `render.yaml`
5. Ajouter les variables d'environnement Firebase:
   ```
   FIREBASE_PROJECT_ID=your-project-id
   FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
   FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@your-project.iam.gserviceaccount.com
   ```
6. Cliquer "Apply"

**Option B: Manuel (Étape par étape)**

**Service 1: Backend**
1. New → Web Service
2. Connecter repository (branche `main`)
3. Nom: `video-maestro-backend`
4. Environment: `Node`
5. Build Command: (copier depuis render.yaml)
6. Start Command: (copier depuis render.yaml)
7. Variables d'environnement:
   ```
   NODE_ENV=production
   PORT=3000
   UPLOAD_DIR=/opt/render/project/src/uploads
   OUTPUT_DIR=/opt/render/project/src/outputs
   REDIS_HOST=127.0.0.1
   REDIS_PORT=6379
   TTS_SERVICE_URL=http://localhost:5001
   WHISPER_SERVICE_URL=http://localhost:5002
   FIREBASE_PROJECT_ID=...
   FIREBASE_PRIVATE_KEY=...
   FIREBASE_CLIENT_EMAIL=...
   ALLOWED_ORIGINS=https://video-maestro-web.onrender.com
   ```
8. Disk: Ajouter 10 GB à `/opt/render/project/src`
9. Créer le service

**Service 2: Flutter Web**
1. New → Static Site
2. Connecter repository (branche `flutter`)
3. Nom: `video-maestro-web`
4. Build Command:
   ```bash
   flutter clean && 
   flutter pub get && 
   flutter build web --release --dart-define=API_URL=https://video-maestro-backend.onrender.com
   ```
5. Publish directory: `build/web`
6. Créer le service

### Étape 4: Vérifier le Déploiement

**Backend**: https://video-maestro-backend.onrender.com/api/health
```json
{
  "success": true,
  "api": "healthy",
  "timestamp": "2024-04-15T13:14:15.000Z"
}
```

**Frontend**: https://video-maestro-web.onrender.com
- Devrait afficher l'app Flutter

---

## 🔧 Développement Local

### Backend

```bash
cd video-editor-backend

# Installer Node.js dependencies
npm install

# Installer Python dependencies
pip install -r python_services/requirements.txt

# Installer Redis (Mac/Linux)
brew install redis  # Mac
sudo apt-get install redis-server  # Linux

# Démarrer Redis
redis-server

# Démarrer services Python
python3 python_services/piper_tts_service.py &
python3 python_services/faster_whisper_service.py &

# Démarrer backend Node.js
npm run dev
```

### Flutter Web

```bash
cd flutter_app

# Get dependencies
flutter pub get

# Run web
flutter run -d chrome --web-port=8080

# Build web
flutter build web --release
```

---

## 📋 Variables d'Environnement

### Backend (.env)

```env
NODE_ENV=production
PORT=3000

# Storage
UPLOAD_DIR=./uploads
OUTPUT_DIR=./outputs
AUTO_CLEANUP_DAYS=7

# Redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379

# Python Services
TTS_SERVICE_URL=http://localhost:5001
WHISPER_SERVICE_URL=http://localhost:5002

# Firebase
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@your-project.iam.gserviceaccount.com

# Security
ALLOWED_ORIGINS=http://localhost:8080,https://your-domain.com
```

### Flutter (Build time)

```bash
flutter build web --dart-define=API_URL=https://your-backend.onrender.com
```

---

## 📊 Coûts

**Total: 0€/mois (Plan Gratuit Render)**

| Service | Plan | Coût |
|---------|------|------|
| Backend Node.js | Starter | Gratuit |
| Flutter Web | Static Site | Gratuit |
| Redis | Auto-hébergé | Gratuit |
| Piper TTS | Local | Gratuit |
| Faster-Whisper | Local | Gratuit |
| Storage (10 GB) | Disk | Gratuit |
| Firebase Auth | Spark | Gratuit |

**Limitations plan gratuit Render**:
- 512 MB RAM par service
- 10 GB disk storage
- Inactif après 15 min (redémarre auto)
- 750 heures/mois gratuites

---

## 🔒 Sécurité

### Backend
- ✅ Helmet (CSP strict)
- ✅ CORS validation
- ✅ Rate limiting (3 niveaux)
- ✅ Input sanitization
- ✅ Suspicious activity detection
- ✅ Firebase Authentication

### Frontend
- ✅ Firebase Authentication
- ✅ Secure HTTP client
- ✅ Input validation
- ✅ Error boundaries
- ✅ Safe async operations

---

## 📱 Fonctionnalités

### Backend API
- **POST** `/api/caption/generate` - Générer sous-titres
- **POST** `/api/caption/apply` - Appliquer sous-titres
- **GET** `/api/templates` - Templates vidéo
- **POST** `/api/batch/create` - Créer session batch
- **POST** `/api/batch/add-jobs` - Ajouter jobs
- **GET** `/api/batch/status/:sessionId` - Statut batch
- **GET** `/api/marketplace/effects` - Effects marketplace
- **POST** `/api/tts/synthesize` - Synthèse vocale
- **POST** `/api/transcribe` - Transcription audio

### Flutter Screens
- **Home** - Dashboard principal
- **Template Selector** - Choisir template vidéo
- **Batch Dashboard** - Suivi jobs en temps réel
- **Marketplace** - Acheter effects
- **TTS Controls** - Configuration voix
- **My Videos** - Bibliothèque vidéos
- **Profile** - Paramètres utilisateur

---

## 🛠️ Technologies

**Backend**:
- Node.js 18+
- TypeScript 5.x
- Express.js 4.x
- BullMQ (Redis)
- Python 3.11+
- Piper TTS
- Faster-Whisper
- FFmpeg

**Frontend**:
- Flutter 3.35.4
- Dart 3.9.2
- Material Design 3
- Provider (state management)
- Firebase Auth

---

## 📚 Documentation

- **Backend API**: `/video-editor-backend/README.md`
- **Services Python**: `/video-editor-backend/python_services/README.md`
- **Flutter**: `/flutter_app/README.md`
- **Déploiement**: Ce fichier
- **Sécurité**: `/SECURITY_HARDENING_COMPLETE.md`

---

## 🤝 Support

Pour toute question:
1. Vérifier la documentation
2. Consulter les logs Render
3. Tester en local
4. Créer une issue GitHub

---

## 📄 Licence

MIT License - 100% Open Source

---

## 🎉 Félicitations !

Vous avez maintenant une application de montage vidéo complète, gratuite et open source déployée sur Render !

**URLs**:
- Backend: https://video-maestro-backend.onrender.com
- Frontend: https://video-maestro-web.onrender.com

**Prochaines étapes**:
1. Configurer Firebase Authentication
2. Tester l'upload de vidéo
3. Générer des sous-titres
4. Créer un batch de vidéos
5. Profiter ! 🚀
