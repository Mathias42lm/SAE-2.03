#!/bin/bash

# Définition des variables
SAVE_DIR="./save"
FILE="$SAVE_DIR/init.sql"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S") 

# Création des dossiers si inexistants
mkdir -p "$SAVE_DIR/wp-content"

# 1. Sauvegarde des fichiers WordPress (Thèmes, Plugins, Uploads)
echo "[*] Exportation des thèmes, plugins et médias..."
docker cp wordpress:/var/www/html/wp-content/themes "$SAVE_DIR/wp-content/"
docker cp wordpress:/var/www/html/wp-content/plugins "$SAVE_DIR/wp-content/"
docker cp wordpress:/var/www/html/wp-content/uploads "$SAVE_DIR/wp-content/" 2>/dev/null || true

# Forçage des droits pour Git sur l'hôte physique
sudo chown -R $USER:$USER "$SAVE_DIR/wp-content"

# 2. Rotation de l'ancienne sauvegarde SQL
if [ -f "$FILE" ]; then
    mv "$FILE" "$SAVE_DIR/init-$TIMESTAMP.sql"
fi

# 3. Exécution du dump SQL
echo "[*] Dump de la base de données..."
if docker exec mariadb mariadb-dump -u mathias -proot sae > "$FILE"; then
    echo "[+] Dump réussi : $FILE"
else
    echo "[-] Erreur lors du dump. Restauration de l'ancienne sauvegarde..."
    [ -f "$SAVE_DIR/init-$TIMESTAMP.sql" ] && mv "$SAVE_DIR/init-$TIMESTAMP.sql" "$FILE"
    exit 1
fi

# 4. Nettoyage et arrêt (Approche statique robuste)
echo "[*] Nettoyage réseau et destruction des conteneurs..."
# Le 'down' remplace avantageusement le 'stop' + 'prune'
# Il détruit les conteneurs et supprime proprement le réseau associé
docker compose -f docker-compose.yml down

echo "[+] Sauvegarde et arrêt terminés avec succès."