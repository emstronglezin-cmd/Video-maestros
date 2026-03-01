# 🎬 Video Maestro - Guide de Déploiement Production

## ✅ État du Projet

### 🔐 Firebase Configuration
- ✅ **google-services.json** : Installé et configuré
- ✅ **Package Android** : `com.videomaestro.editor`
- ✅ **Project ID** : `video-maestros`
- ✅ **Firebase Auth** : Activé (email/password)
- ✅ **SHA-1 Fingerprint** : `DA:6B:4A:D3:EE:B7:7C:BD:3B:D7:A1:9A:9B:EB:D0:93:B1:58:13:2B`

⚠️ **ACTION REQUISE** : Ajoutez le SHA-1 dans Firebase Console :
1. https://console.firebase.google.com/project/video-maestros/settings/general
2. Section "Vos applications" → Android app
3. Ajoutez le SHA-1 ci-dessus

### 📦 Backend (Node.js + TypeScript)
- ✅ **Compilé** : `dist/` prêt
- ✅ **Firebase Admin SDK** : Configuré via variables d'environnement
- ✅ **Sécurité** : Helmet, CORS, Rate Limiting, Zod validation
- ✅ **Authentification** : Middleware `verifyIdToken` sur toutes les routes API
- ✅ **Process Manager** : PM2 avec auto-restart
- ✅ **Logging** : Pino production-ready
- ✅ **Queue** : BullMQ avec Redis

**GitHub** : https://github.com/emstronglezin-cmd/Video-maestros (branche `main`)

### 📱 Flutter App
- ✅ **APK Release** : `app-release.apk` (54 MB) - Signé
- ✅ **AAB Release** : `app-release.aab` (47 MB) - Signé
- ✅ **Firebase Auth** : Intégré avec refresh automatique de token
- ✅ **API Service** : Gestion automatique des tokens Firebase
- ✅ **5 Screens** : Auth, Upload, Script, Progress, Result

**GitHub** : https://github.com/emstronglezin-cmd/Video-maestros (branche `flutter`)

---

## 🚀 Déploiement Backend

### Option 1 : Hébergement Gratuit Temporaire (Recommandé pour tests)

#### **Railway.app** (Gratuit avec GitHub)
Railway offre 5$ de crédit gratuit/mois + $5 supplémentaires avec vérification.

```bash
# 1. Créez compte sur https://railway.app (connexion GitHub)

# 2. Créez nouveau projet depuis GitHub
# Sélectionnez: emstronglezin-cmd/Video-maestros (branche main)

# 3. Configuration automatique
# Railway détecte package.json et build automatiquement

# 4. Variables d'environnement (ajoutez dans Railway dashboard)
NODE_ENV=production
PORT=3000
REDIS_HOST=redis-railway-internal.railway.app
REDIS_PORT=6379
OLLAMA_URL=http://ollama-service:11434
FREE_DAILY_EXPORTS=2
FREE_MAX_RESOLUTION=720
FIREBASE_PROJECT_ID=video-maestros
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@video-maestros.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="<votre clé privée>"
LOG_LEVEL=info
CORS_ORIGIN=*

# 5. Ajoutez Redis Plugin
# Dashboard → Add Plugin → Redis

# 6. Deploy automatique
# Railway déploie automatiquement à chaque push GitHub
```

**URL générée** : `https://your-app.up.railway.app`

#### **Render.com** (Gratuit, limitations: sleep après 15min inactivité)

```bash
# 1. Créez compte sur https://render.com (connexion GitHub)

# 2. New Web Service
# Connect repository: emstronglezin-cmd/Video-maestros

# 3. Configuration
Build Command: npm install && npm run build
Start Command: node dist/app.js
Branch: main

# 4. Variables d'environnement (même que Railway)
# Ajoutez dans Render dashboard

# 5. Deploy automatique
# Render redéploie à chaque push GitHub
```

**URL générée** : `https://your-app.onrender.com`

#### **Glitch.com** (Gratuit, limitations: 4000 req/heure)

```bash
# 1. Créez compte sur https://glitch.com

# 2. Import from GitHub
# URL: https://github.com/emstronglezin-cmd/Video-maestros

# 3. Configuration dans .env
# Copiez contenu de .env.example et remplissez

# 4. Glitch démarre automatiquement
```

**URL générée** : `https://your-app.glitch.me`

---

### Option 2 : VPS Production (Payant mais stable)

Quand vous êtes prêt pour production réelle :

```bash
# 1. Clonez le repository
git clone https://github.com/emstronglezin-cmd/Video-maestros.git
cd Video-maestros

# 2. Installez dépendances
npm install

# 3. Configurez .env (copiez depuis .env.example)
cp .env.example .env
nano .env

# 4. Lancez en production (PM2)
chmod +x start-production.sh
./start-production.sh

# 5. Configuration auto-start système
pm2 startup
pm2 save
```

**Requis VPS** :
- Ubuntu 20.04+ / Debian 11+
- 2GB RAM minimum
- Node.js 18+
- Redis
- FFmpeg
- Ollama (optionnel pour génération IA)

---

## 📱 Installation App Flutter

### APK Release (pour tests)

```bash
# 1. Téléchargez APK depuis GitHub
# Releases: https://github.com/emstronglezin-cmd/Video-maestros/releases

# 2. Installation via ADB
adb install app-release.apk

# 3. Ou transférez l'APK sur votre téléphone
# Activez "Sources inconnues" dans paramètres Android
# Installez l'APK manuellement
```

### AAB Release (pour Google Play)

```bash
# 1. Créez application sur Google Play Console
# https://play.google.com/console

# 2. Upload AAB dans Production/Test tracks
# Fichier: app-release.aab

# 3. Google Play signe et distribue automatiquement
```

---

## 🔧 Configuration Backend URL

**Avant de builder l'app**, mettez à jour l'URL backend :

```dart
// lib/services/api_service.dart
final String baseUrl = 'https://your-backend-url.com'; // ⚠️ Changez cette URL
```

Puis rebuildez :
```bash
flutter build apk --release
flutter build appbundle --release
```

---

## 🧪 Test Firebase Auth

### 1. Activez Firebase Authentication

```bash
# Firebase Console → Authentication → Sign-in method
# Activez: Email/Password
```

### 2. Créez un compte test

```bash
# Dans l'app Flutter:
1. Lancez l'app
2. Créez un compte avec email/password
3. Vérifiez dans Firebase Console → Authentication → Users
```

### 3. Testez connexion backend

```bash
# L'app envoie automatiquement le token Firebase dans chaque requête
# Header: Authorization: Bearer <firebase_token>

# Backend vérifie le token avec Firebase Admin SDK
# Middleware: verifyIdToken
```

---

## 📊 Monitoring & Logs

### Backend Logs (PM2)

```bash
# Logs en temps réel
pm2 logs video-editor-backend

# Logs erreurs uniquement
pm2 logs video-editor-backend --err

# Monitoring
pm2 monit
```

### Flutter Logs

```bash
# Android Logcat
adb logcat | grep Flutter

# Ou dans Android Studio: Logcat panel
```

---

## 🛡️ Sécurité Production

### Checklist ✅

- [x] Firebase Admin SDK via variables d'environnement (pas de fichier JSON exposé)
- [x] Toutes les routes protégées par `verifyIdToken`
- [x] Rate Limiting activé (100 req/15min)
- [x] Helmet headers de sécurité (15+ headers)
- [x] Validation Zod stricte sur toutes les entrées
- [x] CORS configuré
- [x] Logs production (Pino)
- [x] APK/AAB signés avec keystore
- [x] ProGuard rules (protection code Flutter)
- [x] HTTPS obligatoire en production

---

## 💰 Coût Estimé

### Hébergement Gratuit (Railway/Render)
- **Backend** : Gratuit (limitations traffic)
- **Firebase** : Gratuit (Spark Plan, 50k lectures/jour)
- **Total** : 0€/mois

### VPS Production
- **VPS** : 5-10€/mois (Hetzner, OVH, DigitalOcean)
- **Firebase** : 0-5€/mois (selon usage)
- **Total** : 5-15€/mois

---

## 🆘 Support & Dépannage

### Problèmes fréquents

**1. Firebase Auth ne fonctionne pas**
- Vérifiez que le SHA-1 est ajouté dans Firebase Console
- Vérifiez `google-services.json` dans `android/app/`
- Vérifiez `.env` backend avec bonnes credentials Firebase

**2. Backend inaccessible**
- Vérifiez logs : `pm2 logs`
- Vérifiez Redis : `redis-cli ping`
- Vérifiez port : `netstat -tulpn | grep 3000`

**3. App ne se connecte pas au backend**
- Vérifiez URL dans `lib/services/api_service.dart`
- Vérifiez CORS dans `.env` backend
- Vérifiez que backend est accessible : `curl https://your-backend/api/health`

---

## 📚 Documentation Complète

- **Backend** : `GUIDE_PRODUCTION.md`
- **Frontend** : `README.md`
- **Firebase** : `FIREBASE_CONFIG_GUIDE.md`
- **API** : `API_DOCUMENTATION.md`

---

## 🎯 Prochaines Étapes

1. ✅ Ajoutez SHA-1 dans Firebase Console
2. ✅ Déployez backend sur Railway/Render
3. ✅ Mettez à jour l'URL backend dans Flutter
4. ✅ Rebuildez APK/AAB
5. ✅ Testez l'authentification
6. ✅ Uploadez sur Google Play (optionnel)

---

**🎬 Votre app Video Maestro est prête pour production !**

Repository : https://github.com/emstronglezin-cmd/Video-maestros
