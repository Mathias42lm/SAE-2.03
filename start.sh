#!/bin/bash

# Couleurs pour le feedback
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}[*] Initialisation du déploiement SAE-2.03...${NC}"

# 1. Nettoyage des artefacts Docker fantômes
if [ -d "./init.sql" ]; then
    echo -e "${RED}[!] Alerte : init.sql est un répertoire (erreur Docker). Suppression...${NC}"
    rm -rf ./save/init.sql
    touch ./save/init.sql
fi

# 2. Correction préventive des permissions sur l'hôte
# MariaDB (UID 999) et WordPress (UID 33)
echo "[*] Correction des permissions des volumes..."
sudo chown -R 999:999 ./db 2>/dev/null || echo "Info: volume db non encore créé"
sudo chown -R 33:33 ./wordpress 2>/dev/null || echo "Info: volume wordpress non encore créé"

# 3. Lancement de la stack
echo "[*] Lancement de Docker Compose..."
docker compose up -d --remove-orphans

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[+] Stack démarrée.${NC}"
else
    echo -e "${RED}[-] Erreur lors du docker compose up.${NC}"
    exit 1
fi

# 4. Correction dynamique des permissions (post-boot)
echo "[*] Application des ACL internes (www-data)..."
docker exec -it wordpress chown -R www-data:www-data /var/www/html
docker exec -it wordpress find /var/www/html -type d -exec chmod 755 {} \;
docker exec -it wordpress find /var/www/html -type f -exec chmod 644 {} \;

# 5. Healthcheck MariaDB
echo -n "[*] Attente de MariaDB..."
until docker exec mariadb mariadb-admin ping -h localhost --silent; do
    echo -n "."
    sleep 2
done
echo -e "\n${GREEN}[+] MariaDB est prêt.${NC}"

echo -e "${GREEN}[!] Déploiement terminé avec succès.${NC}"
echo "Wordpress: http://localhost:8081"
echo "phpMyAdmin: http://localhost:8080"
echo "Wordpress Admin : http://0.0.0.0:8081/wp-admin/"