# Configuration de l'encodage
$OutputEncoding = [System.Text.Encoding]::UTF8
$IP_LOCALE = "192.168.100.10"
$SYMFONY_DIR = "./symfony_app"
$SYMFONY_REPO_URL = "https://github.com/Mathias42lm/EportfolioMathias.git"

Write-Host "[*] Déploiement SAE-2.03 - Mode Injection Directe" -ForegroundColor Green

# 0. Gestion Git Symfony
if (Test-Path "$SYMFONY_DIR\.git") {
    git -C $SYMFONY_DIR pull
} else {
    git clone $SYMFONY_REPO_URL $SYMFONY_DIR
}

# 1. Préparation des volumes et nettoyage
if (Test-Path "./init.sql" -PathType Container) { Remove-Item -Recurse -Force "./init.sql" }
foreach ($dir in @("./db", "./wordpress", "./nginx/ssl")) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

# 2. Lancement de la stack
Write-Host "[*] Démarrage des conteneurs..." -ForegroundColor Cyan
docker compose up -d --build --remove-orphans
if ($LASTEXITCODE -ne 0) { Write-Host "[-] Erreur Docker." -ForegroundColor Red; exit 1 }

# 3. Injection forcée des Thèmes et Plugins (DEPUIS ./save/)
Write-Host "[*] Injection des assets de sauvegarde vers Docker..." -ForegroundColor Cyan
if (Test-Path "./save/wp-content") {
    if (Test-Path "./save/wp-content/themes") {
        Get-ChildItem -Directory "./save/wp-content/themes" | ForEach-Object {
            docker cp $_.FullName wordpress:/var/www/html/wp-content/themes/
        }
    }
    if (Test-Path "./save/wp-content/plugins") {
        Get-ChildItem -Directory "./save/wp-content/plugins" | ForEach-Object {
            docker cp $_.FullName wordpress:/var/www/html/wp-content/plugins/
        }
    }
}

# 4. Correction des permissions et ACL (WordPress)
Write-Host "[*] Application des permissions (www-data)..." -ForegroundColor Cyan
docker exec wordpress chown -R www-data:www-data /var/www/html
docker exec wordpress find /var/www/html -type d -exec chmod 755 {} ";"
docker exec wordpress find /var/www/html -type f -exec chmod 644 {} ";"

# 5. Initialisation Symfony (Correction du flag -n)
if (docker ps -q -f name=symfony) {
    Write-Host "[*] Setup Symfony..." -ForegroundColor Cyan
    docker exec symfony /bin/sh -c "composer install --no-interaction --optimize-autoloader"
    docker exec symfony chown -R www-data:www-data /var/www/html/var
}

# 6. Healthcheck MariaDB
Write-Host -NoNewline "[*] Attente MariaDB..." -ForegroundColor Cyan
while ($true) {
    docker exec mariadb mariadb-admin ping -h localhost -umathias -proot --silent 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host -NoNewline "." ; Start-Sleep -Seconds 2
}

# 7. Résumé des accès
Write-Host "`n[!] Déploiement terminé." -ForegroundColor Green
Write-Host "WordPress (HTTP)  : http://$IP_LOCALE"
Write-Host "WordPress (HTTPS) : https://$IP_LOCALE"
Write-Host "phpMyAdmin        : http://localhost:8080"
Write-Host "Symfony App       : http://localhost:8001"

Write-Host "`n[?] Liste des thèmes injectés :" -ForegroundColor Cyan
docker exec wordpress ls /var/www/html/wp-content/themes