# Configuration de l'encodage
$OutputEncoding = [System.Text.Encoding]::UTF8
$IP_LOCALE = "192.168.100.10"
$SYMFONY_DIR = "./symfony_app"
$SYMFONY_REPO_URL = "https://github.com/Mathias42lm/EportfolioMathias.git"

Write-Host "[*] Déploiement SAE-2.03 - Script Master (Architecture Multi-Ports & Prod)" -ForegroundColor Green

# 1. Récupération / Pull du E-Portfolio
Write-Host "[*] Etape 1 : Récupération du code Symfony..." -ForegroundColor Cyan
if (Test-Path "$SYMFONY_DIR\.git") {
    git -C $SYMFONY_DIR pull
} else {
    git clone $SYMFONY_REPO_URL $SYMFONY_DIR
}

# 2. Nettoyage préventif et préparation des volumes
Write-Host "[*] Etape 2 : Préparation des volumes hôtes..." -ForegroundColor Cyan
if (Test-Path "./init.sql" -PathType Container) { Remove-Item -Recurse -Force "./init.sql" }
foreach ($dir in @("./db", "./wordpress", "./nginx/ssl")) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

# 3. Démarrage de l'infrastructure Docker
Write-Host "[*] Etape 3 : Lancement de Docker Compose..." -ForegroundColor Cyan
docker compose up -d --build --remove-orphans
if ($LASTEXITCODE -ne 0) { Write-Host "[-] Erreur critique Docker." -ForegroundColor Red; exit 1 }

# 4. Blocage Anti-Race Condition
Write-Host -NoNewline "[*] Etape 4 : Attente des services (MariaDB & Core WordPress)..." -ForegroundColor Cyan
while ($true) {
    docker exec mariadb mariadb-admin ping -h localhost -umathias -proot --silent 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host -NoNewline "." ; Start-Sleep -Seconds 2
}
while ($true) {
    docker exec wordpress ls /var/www/html/wp-content/themes 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host -NoNewline "." ; Start-Sleep -Seconds 2
}
Write-Host "`n[+] Services prêts à recevoir les données." -ForegroundColor Green

# 5. Injection directe de la Base de Données (Init.sql)
Write-Host "[*] Etape 5 : Restauration de la base de données..." -ForegroundColor Cyan
if (Test-Path "./save/init.sql") {
    Write-Host "    -> Copie du fichier SQL dans le conteneur..."
    docker cp ./save/init.sql mariadb:/tmp/init.sql
    
    Write-Host "    -> Exécution de l'import (source)..."
    # Ajout de --skip-ssl et --default-character-set=utf8mb4
    docker exec mariadb mariadb -umathias -proot --skip-ssl --default-character-set=utf8mb4 -f sae -e "source /tmp/init.sql"
    
    if ($LASTEXITCODE -eq 0) { Write-Host "    -> Base de données importée avec succès." }
} else {
    Write-Host "    [!] Fichier ./save/init.sql introuvable. Skip." -ForegroundColor Yellow
}

# 6. Injection des assets WordPress
Write-Host "[*] Etape 6 : Injection des assets WordPress..." -ForegroundColor Cyan
if (Test-Path "./save/wp-content") {
    foreach ($asset in @("themes", "plugins", "uploads")) {
        if (Test-Path "./save/wp-content/$asset") {
            Write-Host "    -> Copie de $asset..."
            docker cp "./save/wp-content/$asset/." "wordpress:/var/www/html/wp-content/$asset/"
        }
    }
}

# 7. Application des permissions (WordPress)
Write-Host "[*] Etape 7 : Application des permissions WP (www-data)..." -ForegroundColor Cyan
docker exec wordpress chown -R www-data:www-data /var/www/html
docker exec wordpress find /var/www/html -type d -exec chmod 755 {} ";"
docker exec wordpress find /var/www/html -type f -exec chmod 644 {} ";"

# 8. Auto-Build Symfony (Mode Production Strict)
Write-Host "[*] Etape 8 : Auto-build de l'application Symfony (Mode Production)..." -ForegroundColor Cyan
if (docker ps -q -f name=symfony) {
    
    Write-Host "    -> Suppression du cache résiduel (Dev)..."
    docker exec symfony rm -rf /var/www/html/var/cache/
    
    Write-Host "    -> Installation de Composer (Mode Prod)..."
    docker exec -e APP_ENV=prod -e APP_DEBUG=0 symfony composer install --no-dev --no-interaction --optimize-autoloader
    
    Write-Host "    -> Compilation du Cache Symfony..."
    docker exec -e APP_ENV=prod -e APP_DEBUG=0 symfony php bin/console cache:clear
    
    Write-Host "    -> Verrouillage des permissions sur var/..."
    docker exec symfony chown -R www-data:www-data /var/www/html/var
    
    Write-Host "    [+] Build Symfony terminé avec succès." -ForegroundColor Green
} else {
    Write-Host "    [-] Conteneur Symfony inactif." -ForegroundColor Red
}

# 9. Affichage des accès
Write-Host "`n[!] Déploiement terminé avec succès." -ForegroundColor Green
Write-Host "-------------------------------------------------------"
Write-Host "=> WordPress (HTTP/S) : https://localhost" -ForegroundColor Cyan
Write-Host "=> Admin WordPress    : https://localhost/wp-admin/" -ForegroundColor Cyan
Write-Host "=> Symfony Portfolio  : https://localhost:8080" -ForegroundColor Magenta
Write-Host "=> phpMyAdmin         : https://localhost:8081" -ForegroundColor Yellow
Write-Host "-------------------------------------------------------"
Write-Host "Note : Remplace 'localhost' par '$IP_LOCALE' depuis une autre machine du réseau."