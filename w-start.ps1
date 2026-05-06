# Configuration de l'encodage
$OutputEncoding = [System.Text.Encoding]::UTF8

# Couleurs
$GREEN = "Green"
$RED = "Red"
$CYAN = "Cyan"

# Variables
$SYMFONY_REPO_URL = "https://github.com/Mathias42lm/EportfolioMathias.git"
$SYMFONY_DIR = "./symfony_app"
$IP_FIXE = "192.168.100.10"

Write-Host "[*] Initialisation du déploiement SAE-2.03..." -ForegroundColor $GREEN

# 0. Préparation Git
if (Test-Path "$SYMFONY_DIR\.git") {
    Write-Host "[*] Mise à jour du dépôt Symfony..." -ForegroundColor $CYAN
    git -C $SYMFONY_DIR pull
} else {
    Write-Host "[*] Clonage du dépôt Symfony..." -ForegroundColor $CYAN
    git clone $SYMFONY_REPO_URL $SYMFONY_DIR
}

# 1. Nettoyage et Dossiers
if (Test-Path "./init.sql" -PathType Container) {
    Remove-Item -Recurse -Force "./init.sql"
    New-Item -ItemType File "./init.sql" | Out-Null
}

foreach ($dir in @("./db", "./wordpress", "./nginx/ssl")) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

# 2. Lancement Docker
Write-Host "[*] Lancement de Docker Compose..." -ForegroundColor $CYAN
docker compose up -d --build --remove-orphans

if ($LASTEXITCODE -ne 0) {
    Write-Host "[-] Erreur Docker Compose." -ForegroundColor $RED
    exit 1
}

# 3. Permissions WordPress
Write-Host "[*] Configuration des permissions WordPress..." -ForegroundColor $CYAN
docker exec wordpress chown -R www-data:www-data /var/www/html
docker exec wordpress find /var/www/html -type d -exec chmod 755 {} ";"
docker exec wordpress find /var/www/html -type f -exec chmod 644 {} ";"

# 4. Initialisation Symfony (CORRECTION DU FLAG -n)
Write-Host "[*] Installation des dépendances Symfony..." -ForegroundColor $CYAN
if (docker ps -q -f name=symfony) {
    # Utilisation de --% pour empêcher PowerShell d'analyser les tirets suivants
    # OU utilisation d'une chaîne de caractères via /bin/sh (méthode la plus robuste)
    docker exec symfony /bin/sh -c "composer install --no-interaction --optimize-autoloader"
    docker exec symfony chown -R www-data:www-data /var/www/html/var
}

# 5. Healthcheck MariaDB
Write-Host -NoNewline "[*] Attente de MariaDB..." -ForegroundColor $CYAN
while ($true) {
    docker exec mariadb mariadb-admin ping -h localhost -umathias -proot --silent 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host -NoNewline "."
    Start-Sleep -Seconds 2
}

Write-Host "`n[!] Déploiement terminé avec succès." -ForegroundColor $GREEN
Write-Host "Accès HTTP  : http://$IP_FIXE"
Write-Host "Accès HTTPS : https://$IP_FIXE"