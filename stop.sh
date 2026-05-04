# Configuration de l'encodage
$OutputEncoding = [System.Text.Encoding]::UTF8

# Définition des variables
$SAVE_DIR = "./save"
$FILE = "$SAVE_DIR/init.sql"
# Format : YYYY-MM-DD_HH-MM-SS
$TIMESTAMP = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Création du dossier si inexistant
if (-not (Test-Path $SAVE_DIR)) {
    New-Item -ItemType Directory -Path $SAVE_DIR | Out-Null
}

# 1. Rotation de l'ancienne sauvegarde
if (Test-Path $FILE) {
    $BACKUP_PATH = "$SAVE_DIR/init-$TIMESTAMP.sql"
    Move-Item -Path $FILE -Destination $BACKUP_PATH -Force
}

# 2. Exécution du dump
Write-Host "[*] Tentative de dump MariaDB..."
# Redirection du flux vers le fichier
# Note : On utilise --no-defaults ou les variables d'env si nécessaire pour les credentials
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

# 3. Nettoyage et arrêt
Write-Host "[*] Nettoyage des réseaux non utilisés..."
docker network prune -f

Write-Host "[*] Arrêt de la stack Docker Compose..."
docker compose stop

Write-Host "[+] Opérations terminées." -ForegroundColor Green