# Video Maestro Backend - Railway Deployment

## Déploiement automatique sur Railway.app

### 🚀 Configuration minimale (sans Redis ni Ollama)

Le backend fonctionne **sans configuration** avec ces valeurs par défaut :
- **In-memory queue** (si Redis non configuré)
- **AI features désactivées** (si Ollama non configuré)
- **Port automatique** (Railway l'assigne automatiquement)

### ⚡ Déploiement rapide (5 minutes)

#### 1. Créez compte Railway
→ https://railway.app (connexion GitHub recommandée)

#### 2. Nouveau projet
- Cliquez "New Project"
- Sélectionnez "Deploy from GitHub repo"
- Choisissez : `emstronglezin-cmd/Video-maestros`
- Branche : `main`

#### 3. Variables d'environnement MINIMALES (Firebase uniquement)

**Variables OBLIGATOIRES** :
```
FIREBASE_PROJECT_ID=video-maestros
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@video-maestros.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----
...votre clé privée Firebase...
-----END PRIVATE KEY-----
```

**Variables OPTIONNELLES** (valeurs par défaut Railway-friendly) :
```
NODE_ENV=production
PORT=$PORT                    # Railway l'assigne automatiquement
LOG_LEVEL=info
CORS_ORIGIN=*
FREE_DAILY_EXPORTS=2
FREE_MAX_RESOLUTION=720
```

#### 4. Ajoutez Redis (OPTIONNEL mais recommandé)

Pour activer la queue Redis :
- Dans Railway Dashboard → "Add Plugin" → "Redis"
- Railway crée automatiquement ces variables :
  - `REDIS_HOST`
  - `REDIS_PORT`
- Le backend les détecte automatiquement ✅

#### 5. Déploiement

Railway déploie automatiquement à chaque push GitHub !

### 🎯 Configuration production complète (optionnelle)

Si vous voulez toutes les fonctionnalités :

**Avec Redis Plugin** :
```
REDIS_HOST=<auto-généré par Railway>
REDIS_PORT=<auto-généré par Railway>
```

**Avec Ollama externe** (si vous avez un serveur Ollama) :
```
OLLAMA_URL=https://your-ollama-server.com
OLLAMA_MODEL=llama3.2:3b
```

**Stockage** (valeurs par défaut suffisantes) :
```
UPLOAD_DIR=./uploads
OUTPUT_DIR=./outputs
```

**FFmpeg** (valeurs par défaut suffisantes) :
```
FFMPEG_THREADS=4
FFMPEG_TIMEOUT=120000
```

**Sécurité** :
```
MAX_FILE_SIZE=209715200
MAX_BODY_SIZE=10485760
```

### ✅ Vérification Deployment

Une fois déployé, Railway vous donne une URL :
→ `https://your-app.up.railway.app`

Testez le health check :
```bash
curl https://your-app.up.railway.app/api/health
```

Réponse attendue :
```json
{
  "status": "healthy",
  "timestamp": "...",
  "uptime": "...",
  "services": {
    "redis": false,       // Si pas de Redis Plugin
    "ollama": false,      // Si pas d'Ollama configuré
    "firebase": true      // Si credentials OK
  }
}
```

### 🔧 Dépannage

**Problème** : Build échoue avec erreur TypeScript
→ **Solution** : Le code est déjà compilé, Railway build automatiquement

**Problème** : "Missing Firebase credentials"
→ **Solution** : Vérifiez les 3 variables Firebase dans Railway Dashboard

**Problème** : Redis connection failed
→ **Solution** : Normal si pas de Redis Plugin - le backend fonctionne en in-memory

**Problème** : Ollama not available
→ **Solution** : Normal si OLLAMA_URL pas configuré - AI features désactivées

### 📊 Monitoring

Railway Dashboard montre :
- **Logs en temps réel**
- **Métriques CPU/RAM**
- **Requêtes HTTP**
- **Erreurs**

### 💰 Coût

Railway offre :
- **5$ de crédit gratuit/mois**
- **5$ supplémentaires avec vérification**
- Redis Plugin inclus dans le crédit

### 🔄 Mises à jour automatiques

À chaque `git push` sur la branche `main`, Railway redéploie automatiquement ! 🚀

---

**🎬 Votre backend Video Maestro est prêt sur Railway !**
