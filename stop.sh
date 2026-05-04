#!/bin/bash

# Définition des variables
SAVE_DIR="./save"
FILE="$SAVE_DIR/init.sql"
# Format : YYYY-MM-DD_HH-MM-SS
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S") 

# Création du dossier si inexistant (évite une erreur de redirection)
mkdir -p "$SAVE_DIR"

# 1. Rotation de l'ancienne sauvegarde
# Si le fichier init.sql existe, on le renomme avec le timestamp actuel
if [ -f "$FILE" ]; then
    mv "$FILE" "$SAVE_DIR/init-$TIMESTAMP.sql"
fi

# 2. Exécution du dump
# Sécurité : On passe le mot de passe via une variable d'environnement pour éviter qu'il n'apparaisse dans les logs/processus
# Note : Pour MariaDB, on utilise MARIADB_PWD (ou MYSQL_PWD)
if docker exec mariadb mariadb-dump -u mathias -proot sae > "$FILE"; then
    echo "[+] Dump réussi : $FILE"
else
    echo "[-] Erreur lors du dump. Restauration de l'ancienne sauvegarde..."
    # Rollback de base en cas de crash du conteneur pendant le dump
    [ -f "$SAVE_DIR/init-$TIMESTAMP.sql" ] && mv "$SAVE_DIR/init-$TIMESTAMP.sql" "$FILE"
    exit 1
fi

# 3. Nettoyage et arrêt
# Le flag -f (force) est obligatoire dans un script pour bypasser le prompt de confirmation
docker network prune -f 

# Arrêt des conteneurs
docker compose stop