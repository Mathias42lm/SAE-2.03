# SAE-2.03 — Déploiement WordPress avec Docker

> Projet universitaire (SAE 2.03) — Déploiement d'un site WordPress conteneurisé avec MariaDB et phpMyAdmin via Docker Compose.

---

## 📋 Présentation

Ce projet met en place une stack web complète reposant sur trois conteneurs Docker :

| Conteneur    | Image                     | Rôle                                      |
|--------------|---------------------------|-------------------------------------------|
| `wordpress`  | `wordpress` (officielle)  | Serveur web + application WordPress       |
| `mariadb`    | `mariadb` (officielle)    | Base de données relationnelle             |
| `phpmyadmin` | `phpmyadmin/phpmyadmin`   | Interface d'administration de la base SQL |

Les conteneurs communiquent sur un réseau Docker dédié (`sae_network`) en bridge, avec des adresses IP statiques.

---

## 🗂️ Structure du projet

```
SAE-2.03/
├── docker-compose.yml      # Définition de la stack Docker
├── start.sh                # Script de démarrage (Linux/macOS)
├── stop.sh                 # Script d'arrêt + sauvegarde (Linux/macOS)
├── w-start.ps1             # Script de démarrage (Windows PowerShell)
├── w-stop.ps1              # Script d'arrêt + sauvegarde (Windows PowerShell)
├── db/                     # Volume persistant de MariaDB (généré automatiquement)
├── wordpress/              # Volume persistant de WordPress (généré automatiquement)
└── save/
    ├── init.sql            # Dernier dump de la base de données
    └── wp-content/         # Sauvegarde des thèmes, plugins et médias WordPress
```

---

## ⚙️ Prérequis

- [Docker](https://docs.docker.com/get-docker/) ≥ 20.x
- [Docker Compose](https://docs.docker.com/compose/install/) ≥ 2.x (intégré dans Docker Desktop)
- **Linux/macOS** : Bash, `sudo` disponible
- **Windows** : PowerShell ≥ 5.1, Docker Desktop installé

---

## 🚀 Démarrage

### Linux / macOS

```bash
chmod +x start.sh
./start.sh
```

### Windows (PowerShell)

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
.\w-start.ps1
```

Le script effectue les opérations suivantes :
1. Vérification et correction des artefacts Docker résiduels.
2. Création des répertoires de volumes si nécessaire.
3. Lancement de la stack avec `docker compose up -d`.
4. Injection des sauvegardes WordPress (thèmes, plugins, médias) si elles existent.
5. Application des permissions internes au conteneur WordPress.
6. Attente de la disponibilité de MariaDB (healthcheck).

Une fois démarré, les services sont accessibles aux adresses suivantes :

| Service           | URL                                    |
|-------------------|----------------------------------------|
| WordPress         | http://192.168.100.10 (Linux)          |
|                   | http://localhost (Windows)             |
| WordPress Admin   | http://192.168.100.10/wp-admin/        |
| phpMyAdmin        | http://localhost:8080                  |

---

## 🛑 Arrêt et sauvegarde

### Linux / macOS

```bash
./stop.sh
```

### Windows (PowerShell)

```powershell
.\w-stop.ps1
```

Le script effectue les opérations suivantes :
1. Export des thèmes, plugins et médias WordPress vers `save/wp-content/`.
2. Rotation de l'ancien dump SQL (archivage horodaté).
3. Dump de la base de données MariaDB vers `save/init.sql`.
4. Nettoyage des réseaux Docker inutilisés.
5. Arrêt des conteneurs.

---

## 🔧 Configuration

Les paramètres de connexion à la base de données sont définis dans `docker-compose.yml` :

| Variable                  | Valeur par défaut |
|---------------------------|-------------------|
| `WORDPRESS_DB_USER`       | `mathias`         |
| `WORDPRESS_DB_PASSWORD`   | `root`            |
| `WORDPRESS_DB_NAME`       | `sae`             |
| `MYSQL_USER`              | `mathias`         |
| `MYSQL_PASSWORD`          | `root`            |
| `MYSQL_DATABASE`          | `sae`             |

> ⚠️ Ces valeurs sont adaptées à un environnement de développement local. Ne pas utiliser en production sans les modifier.

---

## 💾 Sauvegarde manuelle de la base de données

Pour effectuer un dump manuel de la base depuis le conteneur MariaDB :

```bash
docker exec mariadb mariadb-dump -u mathias -proot sae > save/init.sql
```

---

## 📚 Ressources

- [Documentation WordPress Docker](https://hub.docker.com/_/wordpress)
- [Documentation MariaDB Docker](https://hub.docker.com/_/mariadb)
- [Documentation phpMyAdmin Docker](https://hub.docker.com/_/phpmyadmin)
- [Démarrage avec Docker Compose](https://docs.docker.com/compose/gettingstarted/)
