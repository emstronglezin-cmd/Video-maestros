# 🎬 Video Maestro - Configuration Production

## ✅ Backend Railway Configuré

**URL Backend** : `https://video-maestros-production.up.railway.app`
**Port** : 8080 (géré automatiquement par Railway)

### Configuration Flutter

L'URL backend a été configurée dans :
```dart
// lib/services/api_service.dart
static const String baseUrl = 'https://video-maestros-production.up.railway.app';
```

---

## 📱 Builds Release Générés

### APK Release
- **Fichier** : `build/app/outputs/flutter-apk/app-release.apk`
- **Taille** : 54 MB
- **Signé** : ✅ Oui (release-key.jks)
- **Installation** : 
  ```bash
  adb install build/app/outputs/flutter-apk/app-release.apk
  ```

### AAB Release (Google Play)
- **Fichier** : `build/app/outputs/bundle/release/app-release.aab`
- **Taille** : 47 MB
- **Signé** : ✅ Oui (release-key.jks)
- **Usage** : Upload sur Google Play Console

---

## 🔐 Configuration Firebase

### Android
- **Package** : `com.videomaestro.editor`
- **SHA-1** : `DA:6B:4A:D3:EE:B7:7C:BD:3B:D7:A1:9A:9B:EB:D0:93:B1:58:13:2B`
- **google-services.json** : ✅ Configuré

**⚠️ ACTION REQUISE** : 
Ajoutez le SHA-1 dans Firebase Console :
→ https://console.firebase.google.com/project/video-maestros/settings/general

---

## 🚀 Test de l'Application

### 1. Vérifiez le Backend
```bash
curl https://video-maestros-production.up.railway.app/api/health
```

**Réponse attendue** :
```json
{
  "status": "healthy",
  "timestamp": "...",
  "environment": "production",
  "services": {
    "redis": false,
    "ollama": false,
    "firebase": true
  }
}
```

### 2. Installez l'APK
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 3. Testez l'Authentification
1. Ouvrez l'app
2. Créez un compte (email + password)
3. Vérifiez dans Firebase Console → Authentication → Users

---

## 📊 Architecture Production

```
┌─────────────────────────────────────────────────────────────┐
│ Flutter App (Android)                                       │
│ - Package: com.videomaestro.editor                          │
│ - Builds: APK (54MB) + AAB (47MB)                          │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  │ HTTPS
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ Backend Railway                                             │
│ - URL: video-maestros-production.up.railway.app           │
│ - Port: 8080 (auto-assigné)                               │
│ - Redis: In-memory (optionnel)                            │
│ - Ollama: Désactivé (optionnel)                           │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  │ Firebase Admin SDK
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ Firebase (Google Cloud)                                     │
│ - Authentication (Email/Password)                           │
│ - Project: video-maestros                                   │
│ - Firestore Database (optionnel)                           │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 Variables d'Environnement Railway

**Configuration minimale (déjà configurée)** :
```env
FIREBASE_PROJECT_ID=video-maestros
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@video-maestros.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY=<votre-clé-privée>
```

**Variables optionnelles** :
```env
NODE_ENV=production
PORT=8080
CORS_ORIGIN=*
LOG_LEVEL=info
```

---

## 📝 Changelog

### Version 1.0.0 (Production)
- ✅ Backend Railway configuré
- ✅ URL production ajoutée à Flutter
- ✅ APK Release signé (54 MB)
- ✅ AAB Release signé (47 MB)
- ✅ Firebase Auth configuré
- ✅ google-services.json intégré
- ✅ SHA-1 généré

---

## 🎯 Prochaines Étapes

1. ✅ Backend déployé sur Railway
2. ✅ URL backend configurée dans Flutter
3. ✅ APK/AAB générés
4. ⚠️ **Ajoutez SHA-1 dans Firebase Console**
5. Testez l'authentification
6. (Optionnel) Upload AAB sur Google Play

---

## 📞 Support

**Repository** : https://github.com/emstronglezin-cmd/Video-maestros
**Backend Branch** : main
**Flutter Branch** : flutter

**Backend URL** : https://video-maestros-production.up.railway.app

---

**🎬 Video Maestro - Production Ready !**
