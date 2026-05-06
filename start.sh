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

# 3. Lancement de la stack
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
# Suppression des -it pour compatibilité script CI/CD
docker exec wordpress chown -R www-data:www-data /var/www/html
docker exec wordpress find /var/www/html -type d -exec chmod 755 {} \;
docker exec wordpress find /var/www/html -type f -exec chmod 644 {} \;

# 6. Initialisation et permissions Symfony
echo "[*] Installation des dépendances Symfony (Composer)..."
if docker ps | grep -q symfony; then
    docker exec symfony composer install --no-interaction --optimize-autoloader
    echo "[*] Application des ACL internes (Symfony)..."
    docker exec symfony chown -R www-data:www-data /var/www/html/var
else
    echo -e "${RED}[-] Erreur: Le conteneur Symfony ne semble pas être actif.${NC}"
fi

# 6. Initialisation et permissions Symfony (Mode Production)
echo "[*] Installation des dépendances Symfony (Mode Prod)..."
if docker ps | grep -q symfony; then
    # --no-dev ignore les packages inutiles en production (ex: web-profiler)
    docker exec symfony composer install --no-dev --no-interaction --optimize-autoloader
    
    # Génération du cache de production
    docker exec symfony php bin/console cache:clear --env=prod
    
    echo "[*] Application des ACL internes (Symfony)..."
    docker exec symfony chown -R www-data:www-data /var/www/html/var
else
    echo -e "${RED}[-] Erreur: Le conteneur Symfony ne semble pas être actif.${NC}"
fi

# 7. Healthcheck MariaDB
echo -n "[*] Attente de MariaDB..."
until docker exec mariadb mariadb-admin ping -h localhost -umathias -proot --silent; do
    echo -n "."
    sleep 2
done
echo -e "\n${GREEN}[+] MariaDB est prêt.${NC}"

# 8. Résumé des accès
echo -e "\n\033[0;32m[!] Déploiement terminé. Architecture par Ports (Virtual Hosts).\033[0m"
echo "-------------------------------------------------------"
echo -e "WordPress         : \033[0;36mhttp://localhost\033[0m"
echo -e "Admin WordPress   : \033[0;36mhttp://localhost/wp-admin/\033[0m"
echo -e "Symfony Portfolio : \033[0;35mhttp://localhost:8080\033[0m"
echo -e "phpMyAdmin        : \033[0;33mhttp://localhost:8081\033[0m"
echo "-------------------------------------------------------"