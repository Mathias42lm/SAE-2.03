#!/bin/bash

# Couleurs pour le feedback
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Variables Symfony
SYMFONY_REPO_URL="https://github.com/Mathias42lm/EportfolioMathias.git"
SYMFONY_DIR="./symfony_app"

echo -e "${GREEN}[*] Initialisation du déploiement SAE-2.03...${NC}"

# 0. Préparation du code Symfony (Git sécurisé)
echo "[*] Vérification du dépôt Symfony..."
if [ -d "$SYMFONY_DIR/.git" ]; then
    echo "    -> Dépôt détecté. Mise à jour (Pull)..."
    # Utilisation de git -C pour exécuter la commande sans changer de répertoire (évite le bug du cd)
    git -C "$SYMFONY_DIR" pull || echo -e "${RED}[!] Attention : Le git pull a échoué. On continue avec le code local.${NC}"
else
    echo "    -> Clonage du dépôt Symfony..."
    git clone "$SYMFONY_REPO_URL" "$SYMFONY_DIR"
fi

# 1. Nettoyage des artefacts Docker fantômes
if [ -d "./init.sql" ]; then
    echo -e "${RED}[!] Alerte : init.sql est un répertoire (erreur Docker). Suppression...${NC}"
    rm -rf ./init.sql
    touch ./init.sql
fi

# 2. Correction préventive des permissions sur l'hôte
echo "[*] Correction des permissions des volumes..."
sudo chown -R 999:999 ./db 2>/dev/null || true
sudo chown -R 33:33 ./wordpress 2>/dev/null || true

# 3. Lancement de la stack (Forçage strict du fichier docker-compose.yml)
echo "[*] Lancement de Docker Compose..."
docker compose -f docker-compose.yml up -d --build --remove-orphans

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[+] Stack démarrée.${NC}"
else
    echo -e "${RED}[-] Erreur lors du docker compose up.${NC}"
    exit 1
fi

# 4. Restauration WordPress (Thèmes, Plugins, Uploads)
if [ -d "./save/wp-content" ]; then
    echo "[*] Injection des thèmes, plugins et médias sauvegardés..."
    docker cp ./save/wp-content/themes wordpress:/var/www/html/wp-content/ 2>/dev/null
    docker cp ./save/wp-content/plugins wordpress:/var/www/html/wp-content/ 2>/dev/null
    [ -d "./save/wp-content/uploads" ] && docker cp ./save/wp-content/uploads wordpress:/var/www/html/wp-content/ 2>/dev/null
fi

# 5. Correction dynamique des permissions WordPress
echo "[*] Application des ACL internes (WordPress)..."
docker exec -it wordpress chown -R www-data:www-data /var/www/html
docker exec -it wordpress find /var/www/html -type d -exec chmod 755 {} \;
docker exec -it wordpress find /var/www/html -type f -exec chmod 644 {} \;

# 6. Initialisation et permissions Symfony
echo "[*] Installation des dépendances Symfony (Composer)..."
if docker ps | grep -q symfony; then
    docker exec -it symfony composer install --no-interaction --optimize-autoloader
    echo "[*] Application des ACL internes (Symfony)..."
    docker exec -it symfony chown -R www-data:www-data /var/www/html/var
else
    echo -e "${RED}[-] Erreur: Le conteneur Symfony ne semble pas être actif.${NC}"
fi

# 7. Healthcheck MariaDB (Avec les bons credentials)
echo -n "[*] Attente de MariaDB..."
until docker exec mariadb mariadb-admin ping -h localhost -umathias -proot --silent; do
    echo -n "."
    sleep 2
done
echo -e "\n${GREEN}[+] MariaDB est prêt.${NC}"

echo -e "${GREEN}[!] Déploiement terminé avec succès.${NC}"
echo "Wordpress       : http://192.168.100.10:80"
echo "Wordpress Admin : http://192.168.100.10:80/wp-admin/"
echo "Symfony App     : http://localhost:8001"
echo "phpMyAdmin      : http://localhost:8080"