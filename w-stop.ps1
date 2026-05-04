# Configuration des chemins et variables
$SaveDir = "./save"
$File = Join-Path $SaveDir "init.sql"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Création du dossier de sauvegarde s'il n'existe pas
if (-not (Test-Path $SaveDir)) {
    New-Item -ItemType Directory -Path $SaveDir | Out-Null
}

# 1. Rotation : Si init.sql existe, on le renomme avec le timestamp
if (Test-Path $File) {
    $OldFile = Join-Path $SaveDir "init-$Timestamp.sql"
    Move-Item -Path $File -Destination $OldFile -Force
    Write-Host "[+] Ancienne sauvegarde archivée : $OldFile" -ForegroundColor Cyan
}

# 2. Exécution du dump MariaDB
# Utilisation de la variable d'environnement pour éviter le mot de passe en clair dans les logs de processus
$env:MARIADB_PWD = "root"

Write-Host "[*] Démarrage du dump de la base 'sae'..." -ForegroundColor Yellow

# On utilise --result-file ou la redirection. 
# Note : En PowerShell, la redirection '>' peut impacter l'encodage (UTF-16 par défaut sur PS 5.1).
# On force l'encodage en UTF8 pour la compatibilité SQL.
docker exec -e MARIADB_PWD=$env:MARIADB_PWD mariadb mariadb-dump -u mathias sae | Out-File -FilePath $File -Encoding utf8

if ($LASTEXITCODE -eq 0) {
    Write-Host "[+] Sauvegarde réussie : $File" -ForegroundColor Green
} else {
    Write-Error "[-] Échec du dump MariaDB."
    exit $LASTEXITCODE
}

# 3. Nettoyage des réseaux Docker inutilisés
Write-Host "[*] Nettoyage des réseaux..." -ForegroundColor Yellow
docker network prune -f

# 4. Arrêt des services
Write-Host "[*] Arrêt de Docker Compose..." -ForegroundColor Yellow
docker compose stop

Write-Host "[+] Opération terminée avec succès." -ForegroundColor Green