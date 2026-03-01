# 🎬 Video Maestro

**Application de montage vidéo automatique avec IA**

[![Production Ready](https://img.shields.io/badge/status-production%20ready-brightgreen)](https://github.com/emstronglezin-cmd/Video-maestros)
[![Firebase](https://img.shields.io/badge/firebase-configured-orange)](https://firebase.google.com)
[![TypeScript](https://img.shields.io/badge/typescript-5.x-blue)](https://www.typescriptlang.org/)
[![Flutter](https://img.shields.io/badge/flutter-3.35.4-blue)](https://flutter.dev)

---

## ✨ Features

### 🎥 Backend (Node.js + TypeScript)
- ✅ **Génération IA** : Scripts vidéo avec Ollama (llama3.2:3b)
- ✅ **Rendu vidéo** : FFmpeg pipeline robuste
- ✅ **Queue BullMQ** : Gestion jobs asynchrones avec Redis
- ✅ **Authentification Firebase** : JWT token verification
- ✅ **Sécurité totale** : Helmet, CORS, Rate Limiting, Zod validation
- ✅ **Freemium** : 2 exports/jour (gratuit), 720p max
- ✅ **PM2 Auto-restart** : Zero-downtime deployment
- ✅ **Logs production** : Pino structured logging

### 📱 App Flutter
- ✅ **Firebase Auth** : Inscription/Connexion sécurisée
- ✅ **Upload multiple** : Images, vidéos, audio
- ✅ **Génération script IA** : Assistant automatique
- ✅ **Progress tracking** : Suivi temps réel du rendu
- ✅ **Lecture intégrée** : Video player natif
- ✅ **Offline-ready** : Gestion état local

---

## 🚀 Quick Start

### Backend (3 min)

#### Option 1 : Railway.app (Gratuit)
```bash
1. Créez compte : https://railway.app
2. New Project → Deploy from GitHub
3. Sélectionnez : emstronglezin-cmd/Video-maestros (branche main)
4. Add Plugin → Redis
5. Ajoutez variables d'environnement (.env.example)
6. Deploy automatique ✅
```

#### Option 2 : Local/VPS
```bash
git clone https://github.com/emstronglezin-cmd/Video-maestros.git
cd Video-maestros
npm install
cp .env.example .env
nano .env  # Configurez variables Firebase
./auto-start-backend.sh  # Démarre avec PM2
```

### Flutter App (2 min)

#### Installation APK
```bash
# Téléchargez depuis Releases
adb install app-release.apk
```

#### Build depuis source
```bash
git clone -b flutter https://github.com/emstronglezin-cmd/Video-maestros.git flutter-app
cd flutter-app
flutter pub get

# Changez URL backend dans lib/services/api_service.dart
flutter build apk --release
```

---

## 🔐 Firebase Setup (5 min)

### 1. Créez projet Firebase
```bash
1. https://console.firebase.google.com
2. Créez nouveau projet : "video-maestros"
3. Activez Authentication → Email/Password
4. Créez Firestore Database
```

### 2. Configuration Android
```bash
1. Ajoutez app Android : com.videomaestro.editor
2. Téléchargez google-services.json
3. Placez dans android/app/google-services.json
4. Ajoutez SHA-1 : DA:6B:4A:D3:EE:B7:7C:BD:3B:D7:A1:9A:9B:EB:D0:93:B1:58:13:2B
```

### 3. Firebase Admin SDK
```bash
1. Paramètres projet → Comptes de service
2. Sélectionnez Python
3. Générez clé privée (JSON)
4. Ajoutez dans .env backend :
   FIREBASE_PROJECT_ID=video-maestros
   FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@xxx.iam.gserviceaccount.com
   FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

---

## 📦 Architecture

### Backend
```
video-editor-backend/
├── src/
│   ├── app.ts                  # Express app
│   ├── middleware/
│   │   ├── firebase.middleware.ts   # Auth JWT
│   │   └── security.middleware.ts   # Helmet, CORS, Rate Limit
│   ├── modules/
│   │   ├── video/              # Création vidéo
│   │   ├── render/             # FFmpeg pipeline
│   │   ├── ai/                 # Ollama script generation
│   │   └── subscription/       # Freemium logic
│   └── utils/
│       └── logger.ts           # Pino logging
├── ecosystem.config.js         # PM2 config
├── auto-start-backend.sh       # Auto-start script
└── .env.example
```

### Flutter
```
flutter_app/
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart   # Firebase config
│   ├── screens/
│   │   ├── auth_screen.dart
│   │   ├── upload_screen.dart
│   │   ├── script_screen.dart
│   │   ├── progress_screen.dart
│   │   └── result_screen.dart
│   ├── services/
│   │   └── api_service.dart    # Backend communication
│   ├── models/
│   └── providers/
└── android/
    └── app/
        ├── google-services.json
        ├── release-key.jks
        └── build.gradle.kts
```

---

## 🛡️ Sécurité

```
✅ Firebase Admin SDK via environment variables
✅ JWT token verification sur toutes routes
✅ Rate Limiting : 100 req/15min (global)
✅ Helmet : 15+ security headers
✅ CORS configuré
✅ Zod validation stricte
✅ Path traversal protection
✅ MIME type verification
✅ Body size limits
✅ Keystore APK/AAB signé
✅ ProGuard obfuscation
```

---

## 📊 Monitoring

### Backend
```bash
# Status PM2
pm2 status

# Logs temps réel
pm2 logs video-editor-backend

# Monitoring
pm2 monit

# Restart
pm2 restart video-editor-backend
```

### Health Check
```bash
curl http://localhost:3000/api/health
```

---

## 💰 Coût

### Hébergement Gratuit
- **Railway** : 5$ gratuit/mois + 5$ avec vérification
- **Render** : Gratuit (sleep après 15min inactivité)
- **Firebase Spark** : Gratuit (50k lectures/jour)
- **Total** : 0€/mois ✅

### Production VPS
- **VPS** : 5-10€/mois (Hetzner, OVH)
- **Firebase Blaze** : Pay-as-you-go
- **Total** : 5-15€/mois

---

## 📚 Documentation

- **[LIVRAISON_FINALE_AUTOMATIQUE.md](LIVRAISON_FINALE_AUTOMATIQUE.md)** - Guide complet production
- **[DEPLOIEMENT_PRODUCTION_COMPLET.md](DEPLOIEMENT_PRODUCTION_COMPLET.md)** - Déploiement détaillé
- **[GUIDE_PRODUCTION.md](GUIDE_PRODUCTION.md)** - Guide technique backend
- **[MODE_EMPLOI_ULTRA_SIMPLE.md](MODE_EMPLOI_ULTRA_SIMPLE.md)** - Guide utilisateur 3 étapes

---

## 🔧 Configuration

### Variables d'environnement Backend
```env
NODE_ENV=production
PORT=3000
REDIS_HOST=localhost
REDIS_PORT=6379
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2:3b
FREE_DAILY_EXPORTS=2
FREE_MAX_RESOLUTION=720
FIREBASE_PROJECT_ID=video-maestros
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@xxx.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

### Flutter Backend URL
```dart
// lib/services/api_service.dart
final String baseUrl = 'https://your-backend-url.com';
```

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.

---

## 📝 License

MIT License - See [LICENSE](LICENSE) file

---

## 👤 Author

**Video Maestro Team**

- GitHub: [@emstronglezin-cmd](https://github.com/emstronglezin-cmd)
- Repository: [Video-maestros](https://github.com/emstronglezin-cmd/Video-maestros)

---

## 🎯 Statut Production

```
✅ Backend compilé et déployé
✅ Firebase configuré et sécurisé
✅ APK/AAB signés et prêts
✅ Documentation complète
✅ Zéro commande manuelle
✅ Auto-restart configuré
✅ Tests production réussis
✅ Hébergement gratuit disponible
```

**🚀 Production Ready !**

---

## 📞 Support

Pour questions ou problèmes :
1. Consultez la documentation complète
2. Ouvrez une issue sur GitHub
3. Vérifiez Firebase Console pour erreurs auth

---

**Made with ❤️ using Flutter, TypeScript, Firebase & FFmpeg**
