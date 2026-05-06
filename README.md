# SAE-2.03 — Déploiement WordPress + Symfony avec Docker

> Projet universitaire (SAE 2.03) — Déploiement d'une stack web conteneurisée composée de WordPress, d'une application Symfony (e-portfolio), MariaDB, phpMyAdmin et Nginx via Docker Compose.

---

## 📋 Présentation

Ce projet met en place une stack web complète reposant sur cinq conteneurs Docker :

| Conteneur    | Image / Build             | Rôle                                      |
|--------------|---------------------------|-------------------------------------------|
| `nginx`      | `nginx:latest`            | Reverse proxy (HTTP/HTTPS, IP statique)   |
| `wordpress`  | `wordpress` (officielle)  | Application WordPress                     |
| `symfony`    | `Dockerfile.symfony`      | Application Symfony (e-portfolio)         |
| `mariadb`    | `mariadb` (officielle)    | Base de données relationnelle             |
| `phpmyadmin` | `phpmyadmin/phpmyadmin`   | Interface d'administration de la base SQL |

Les conteneurs communiquent sur un réseau Docker dédié (`sae_network`) en bridge, avec un sous-réseau `192.168.100.0/24`. Nginx dispose d'une adresse IP statique (`192.168.100.10`) et agit comme point d'entrée unique pour WordPress.

---

## 🗂️ Structure du projet

```
SAE-2.03/
├── docker-compose.yml      # Définition de la stack Docker
├── Dockerfile.symfony      # Image personnalisée pour Symfony (PHP 8.3 + Apache + Composer)
├── start.sh                # Script de démarrage (Linux/macOS)
├── stop.sh                 # Script d'arrêt + sauvegarde (Linux/macOS)
├── w-start.ps1             # Script de démarrage (Windows PowerShell)
├── w-stop.ps1              # Script d'arrêt + sauvegarde (Windows PowerShell)
├── nginx/
│   ├── default.conf        # Configuration Nginx (reverse proxy WordPress + Symfony)
│   └── ssl/                # Certificats SSL (HTTPS)
├── symfony_app/            # Code source de l'application Symfony (e-portfolio)
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
- **Linux/macOS** : Bash, `sudo` disponible, `git` installé
- **Windows** : PowerShell ≥ 5.1, Docker Desktop installé, `git` installé

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
1. Vérification/mise à jour du dépôt Symfony (`symfony_app/`) via `git clone` ou `git pull`.
2. Nettoyage des artefacts Docker résiduels.
3. Correction préventive des permissions sur les volumes hôtes.
4. Lancement de la stack avec `docker compose up -d --build`.
5. Injection des sauvegardes WordPress (thèmes, plugins, médias) si elles existent.
6. Application des permissions internes au conteneur WordPress.
7. Installation des dépendances Composer dans le conteneur Symfony.
8. Application des permissions sur le dossier `var/` de Symfony.
9. Attente de la disponibilité de MariaDB (healthcheck).

Une fois démarré, les services sont accessibles aux adresses suivantes :

| Service           | URL                                    |
|-------------------|----------------------------------------|
| WordPress         | http://192.168.100.10 (Linux)          |
|                   | http://localhost (Windows)             |
| WordPress (HTTPS) | https://192.168.100.10                 |
| WordPress Admin   | http://192.168.100.10/wp-admin/        |
| Symfony App       | http://localhost:8001                  |
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
| `DATABASE_URL` (Symfony)  | `mysql://mathias:root@mariadb:3306/sae` |

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
- [Documentation Nginx Docker](https://hub.docker.com/_/nginx)
- [Démarrage avec Docker Compose](https://docs.docker.com/compose/gettingstarted/)
- [Documentation Symfony](https://symfony.com/doc/current/index.html)
- [Dépôt e-portfolio Symfony](https://github.com/Mathias42lm/EportfolioMathias)
