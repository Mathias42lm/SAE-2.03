# Configuration de l'encodage
$OutputEncoding = [System.Text.Encoding]::UTF8

# Définition des variables
$SAVE_DIR = "./save"
$FILE = "$SAVE_DIR/init.sql"
$TIMESTAMP = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Création des dossiers si inexistants
if (-not (Test-Path "$SAVE_DIR/wp-content")) {
    New-Item -ItemType Directory -Path "$SAVE_DIR/wp-content" | Out-Null
}

# 1. Sauvegarde des fichiers WordPress
Write-Host "[*] Exportation des thèmes, plugins et médias..." -ForegroundColor Cyan
docker cp wordpress:/var/www/html/wp-content/themes "$SAVE_DIR/wp-content/"
docker cp wordpress:/var/www/html/wp-content/plugins "$SAVE_DIR/wp-content/"
try { docker cp wordpress:/var/www/html/wp-content/uploads "$SAVE_DIR/wp-content/" 2>$null } catch {}

# 2. Rotation de l'ancienne sauvegarde SQL
if (Test-Path $FILE) {
    # Si par erreur Windows a créé un dossier init.sql, on le détruit
    $item = Get-Item $FILE
    if ($item.PSIsContainer) {
        Remove-Item -Recurse -Force $FILE
    } else {
        $BACKUP_PATH = "$SAVE_DIR/init-$TIMESTAMP.sql"
        Move-Item -Path $FILE -Destination $BACKUP_PATH -Force
    }
}

# 3. Exécution du dump SQL (Sécurisation MAXIMALE via Hex-Blob)
Write-Host "[*] Tentative de dump MariaDB (Extraction interne BLOB)..." -ForegroundColor Cyan

# Nettoyage préventif via l'interpréteur bash du conteneur
docker exec mariadb sh -c "rm -rf /tmp/db_dump.sql"

# Le dump se fait avec --hex-blob. C'est LE paramètre qui protège l'arborescence des menus WordPress
docker exec -e LANG=C.UTF-8 mariadb sh -c "mariadb-dump -u mathias -proot --default-character-set=utf8mb4 --hex-blob sae > /tmp/db_dump.sql"
$dumpExitCode = $LASTEXITCODE

if ($dumpExitCode -eq 0) {
    # On force la création d'un fichier vide sur Windows pour éviter que docker cp ne crée un dossier
    New-Item -ItemType File -Path $FILE -Force | Out-Null
    
    # On rapatrie le fichier de manière binaire
    docker cp mariadb:/tmp/db_dump.sql $FILE
    
    # Nettoyage
    docker exec mariadb sh -c "rm -f /tmp/db_dump.sql"
    
    Write-Host "[+] Dump réussi et protégé : $FILE" -ForegroundColor Green
} else {
    Write-Host "[-] Erreur lors du dump. Restauration de l'ancienne sauvegarde..." -ForegroundColor Red
    if (Test-Path $BACKUP_PATH) {
        Move-Item -Path $BACKUP_PATH -Destination $FILE -Force
    }
    exit 1
}

# 4. Nettoyage et arrêt
Write-Host "[*] Arrêt et nettoyage de la stack Docker Compose..." -ForegroundColor Cyan
# Forçage du fichier compose et utilisation de 'down' pour détruire l'environnement réseau proprement
docker compose -f docker-compose.yml down

Write-Host "[+] Opérations terminées avec succès." -ForegroundColor Green