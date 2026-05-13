# 🚀 INSTRUCTIONS DÉPLOIEMENT RENDER.COM

## 📋 PRÉREQUIS

✅ Compte GitHub avec repository Video-maestros
✅ Compte Render.com (gratuit)
✅ Compte Upstash Redis (gratuit)
✅ Firebase project avec Admin SDK key

## 🔐 ÉTAPE 1: CRÉER REDIS UPSTASH (Obligatoire)

1. Aller sur **https://upstash.com**
2. Créer un compte gratuit
3. **Console** → **Create Database**
   - Name: `video-maestro-queue`
   - Type: `Regional`
   - Region: Choisir le plus proche
   - TLS: ✅ **ENABLED** (obligatoire)
4. Copier **REDIS_URL** avec TLS (commence par `rediss://`)
   ```
   rediss://default:xxxxx@xxxxx.upstash.io:6379
   ```

## 🚀 ÉTAPE 2: DÉPLOYER SUR RENDER.COM

### Option A: GitHub Auto-Deploy (Recommandé)

1. **Connexion Render.com**
   - Aller sur https://render.com
   - Se connecter avec GitHub

2. **Créer Web Service**
   - Dashboard → **New +** → **Web Service**
   - **Connect GitHub repository**
   - Sélectionner: `emstronglezin-cmd/Video-maestros`

3. **Configuration automatique**
   ```
   ✅ Render détecte render.yaml
   ✅ Name: video-maestro-backend
   ✅ Runtime: Docker
   ✅ Plan: Free
   ✅ Branch: main
   ```

4. **Variables d'environnement** (onglet Environment)
   
   **Obligatoires:**
   ```bash
   # Redis Upstash (ÉTAPE 1)
   REDIS_URL=rediss://default:xxx@xxx.upstash.io:6379
   
   # Node.js Memory
   NODE_OPTIONS=--max-old-space-size=384
   
   # Firebase Admin SDK (upload JSON ou base64)
   FIREBASE_ADMIN_SDK_JSON={"type":"service_account",...}
   # OU
   FIREBASE_ADMIN_SDK_PATH=/opt/render/firebase-admin-sdk.json
   ```
   
   **Optionnels:**
   ```bash
   # Start.io Ads (monétisation)
   STARTIO_PUBLISHER_ID=your_id
   STARTIO_ENABLED=true
   
   # URLs autorisées CORS
   ALLOWED_ORIGINS=https://your-flutter-app.com,https://app.example.com
   
   # Logs
   LOG_LEVEL=info
   NODE_ENV=production
   ```

5. **Déployer**
   - Cliquer **Create Web Service**
   - ⏳ Build initial: ~3-5 minutes
   - ✅ URL générée: `https://video-maestro-backend-xxx.onrender.com`

### Option B: Upload backend.zip

1. **Créer Web Service manuellement**
   - Dashboard → **New +** → **Web Service**
   - Sélectionner **Docker**

2. **Upload backend.zip**
   ```
   📦 Fichier: backend.zip (184 KB)
   ✅ Contient: Dockerfile, render.yaml, src/, etc.
   ```

3. **Même configuration** que Option A (étapes 4-5)

## ✅ ÉTAPE 3: VÉRIFIER DÉPLOIEMENT

1. **Attendre fin du build**
   ```
   Logs Render:
   ✅ Building Docker image...
   ✅ npm install
   ✅ npm run build
   ✅ Starting server...
   ✅ Deploy succeeded
   ```

2. **Tester API Health**
   ```bash
   curl https://video-maestro-backend-xxx.onrender.com/api/health
   
   # Réponse attendue:
   {
     "success": true,
     "data": {
       "api": "healthy",
       "ollama": "unhealthy",  # Normal (désactivé)
       "timestamp": "2026-05-12T05:50:00.000Z"
     }
   }
   ```

3. **Vérifier Logs**
   - Render Dashboard → Service → **Logs**
   - Rechercher: `🚀 Video Maestro Backend - PRODUCTION`

## 🔄 ÉTAPE 4: AUTO-DEPLOY GITHUB

**Configuration:**
- ✅ Auto-deploy activé sur branch `main`
- Chaque push GitHub → déploiement automatique
- ⏳ Build: ~3-5 minutes

**Workflow:**
```bash
# Local development
git add .
git commit -m "Update backend feature"
git push origin main

# Render auto-deploy
✅ GitHub webhook triggered
✅ Build started
✅ Deploy succeeded
```

## 🐛 TROUBLESHOOTING

### Erreur: "Redis connection failed"
```bash
Solution:
1. Vérifier REDIS_URL commence par rediss:// (TLS)
2. Tester connexion Upstash console
3. Vérifier pas de firewall bloquant port 6379
```

### Erreur: "Out of memory"
```bash
Solution:
1. Vérifier NODE_OPTIONS=--max-old-space-size=384
2. Code utilise Whisper tiny (50MB)
3. Ollama désactivé (trop de RAM)
```

### Erreur: "Build failed"
```bash
Solution:
1. Vérifier npm run build local fonctionne
2. Checker Dockerfile syntaxe
3. Consulter Render logs détaillés
```

### Erreur: "Firebase Admin SDK not found"
```bash
Solution:
1. Upload firebase-admin-sdk.json dans Render
2. OU encoder en base64 dans FIREBASE_ADMIN_SDK_JSON
3. Vérifier FIREBASE_ADMIN_SDK_PATH
```

## 📊 LIMITES FREE TIER

**Render.com FREE:**
- 512 MB RAM (optimisé ✅)
- 0.1 vCPU partagé
- 0 GB persistent disk (storage éphémère)
- Auto-suspend après 15min inactivité
- Cold start ~30 secondes
- 750 heures/mois gratuites

**Upstash Redis FREE:**
- 10,000 commandes/jour
- 256 MB storage
- TLS inclus
- Pas de cold start

**Solutions:**
- ✅ Backend optimisé pour 512MB
- ✅ Cleanup automatique uploads/outputs
- ✅ Redis externe (Upstash) pour persistence
- ✅ Firebase Storage pour fichiers permanents

## 🔐 SÉCURITÉ

**Secrets à ne JAMAIS commiter:**
```
❌ .env
❌ firebase-admin-sdk.json
❌ REDIS_URL avec password
❌ STARTIO_PUBLISHER_ID (si privé)
```

**Configurer dans Render Environment Variables:**
```
✅ Toutes les clés sensibles
✅ Encrypted at rest
✅ Pas exposées dans logs
```

## 📝 CHECKLIST DÉPLOIEMENT

- [ ] Compte Render.com créé
- [ ] Compte Upstash Redis créé
- [ ] REDIS_URL copié (rediss://)
- [ ] Firebase Admin SDK JSON disponible
- [ ] Repository GitHub connecté à Render
- [ ] Variables d'environnement configurées
- [ ] Premier déploiement réussi
- [ ] Health endpoint testé
- [ ] Logs vérifiés
- [ ] Auto-deploy GitHub activé
- [ ] URL backend communiquée au frontend Flutter

## 🎯 PROCHAINES ÉTAPES

1. **Backend déployé** ✅
2. **Configurer Flutter app**
   ```dart
   // lib/config/api_config.dart
   const String API_BASE_URL = 
     'https://video-maestro-backend-xxx.onrender.com';
   ```

3. **Tester intégration complète**
   - Upload vidéo depuis Flutter
   - Génération sous-titres
   - Batch processing
   - Social export

4. **Monitoring**
   - Render Dashboard → Metrics
   - Upstash Console → Usage
   - Firebase Console → Logs

---

**Support:** https://render.com/docs
**Status:** ✅ PRODUCTION READY
