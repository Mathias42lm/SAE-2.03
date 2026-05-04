# Configuration de l'encodage
$OutputEncoding = [System.Text.Encoding]::UTF8

# Définition des variables
$SAVE_DIR = "./save"
$FILE = "$SAVE_DIR/init.sql"
# Format : YYYY-MM-DD_HH-MM-SS
$TIMESTAMP = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Création des dossiers si inexistants
if (-not (Test-Path "$SAVE_DIR/wp-content")) {
    New-Item -ItemType Directory -Path "$SAVE_DIR/wp-content" | Out-Null
}

# 1. Sauvegarde des fichiers WordPress (Thèmes, Plugins, Uploads)
# Doit être fait avant l'arrêt des conteneurs
Write-Host "[*] Exportation des thèmes, plugins et médias..." -ForegroundColor Cyan
docker cp wordpress:/var/www/html/wp-content/themes "$SAVE_DIR/wp-content/"
docker cp wordpress:/var/www/html/wp-content/plugins "$SAVE_DIR/wp-content/"
# On ajoute un catch d'erreur silencieux au cas où le dossier uploads n'existe pas encore
try {
    docker cp wordpress:/var/www/html/wp-content/uploads "$SAVE_DIR/wp-content/" 2>$null
} catch {
    # Ignorer si uploads n'existe pas
}

# Sous Windows, pas besoin de chown pour Git, Docker copie les fichiers avec les droits de l'utilisateur courant.

# 2. Rotation de l'ancienne sauvegarde SQL
if (Test-Path $FILE) {
    $BACKUP_PATH = "$SAVE_DIR/init-$TIMESTAMP.sql"
    Move-Item -Path $FILE -Destination $BACKUP_PATH -Force
}

# 3. Exécution du dump
Write-Host "[*] Tentative de dump MariaDB..." -ForegroundColor Cyan
# Redirection du flux vers le fichier
docker exec mariadb mariadb-dump -u mathias -proot sae | Out-File -FilePath $FILE -Encoding utf8

if ($LASTEXITCODE -eq 0) {
    Write-Host "[+] Dump réussi : $FILE" -ForegroundColor Green
} else {
    Write-Host "[-] Erreur lors du dump. Restauration de l'ancienne sauvegarde..." -ForegroundColor Red
    # Rollback : Si la sauvegarde précédente a été déplacée, on la remet en place
    if (Test-Path $BACKUP_PATH) {
        Move-Item -Path $BACKUP_PATH -Destination $FILE -Force
    }
    exit 1
}

# 4. Nettoyage et arrêt
Write-Host "[*] Nettoyage des réseaux non utilisés..." -ForegroundColor Cyan
docker network prune -f

Write-Host "[*] Arrêt de la stack Docker Compose..." -ForegroundColor Cyan
docker compose stop

Write-Host "[+] Opérations terminées avec succès." -ForegroundColor Green