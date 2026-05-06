# Configuration de l'encodage
$OutputEncoding = [System.Text.Encoding]::UTF8
$IP_LOCALE = "192.168.100.10"
$SYMFONY_DIR = "./symfony_app"
$SYMFONY_REPO_URL = "https://github.com/Mathias42lm/EportfolioMathias.git"

Write-Host "[*] Déploiement SAE-2.03 - Script Master" -ForegroundColor Green

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

# 4. Blocage Anti-Race Condition (Attente des processus internes)
Write-Host -NoNewline "[*] Etape 4 : Attente des services (MariaDB & Core WordPress)..." -ForegroundColor Cyan
while ($true) {
    # Test ping MariaDB
    docker exec mariadb mariadb-admin ping -h localhost -umathias -proot --silent 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host -NoNewline "." ; Start-Sleep -Seconds 2
}
while ($true) {
    # Test extraction WordPress (on attend que le dossier par défaut existe)
    docker exec wordpress ls /var/www/html/wp-content/themes 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host -NoNewline "." ; Start-Sleep -Seconds 2
}
Write-Host "`n[+] Services prêts à recevoir les données." -ForegroundColor Green

# 5. Injection directe de la Base de Données (Init.sql)
Write-Host "[*] Etape 5 : Restauration de la base de données..." -ForegroundColor Cyan
if (Test-Path "./save/init.sql") {
    # Utilisation de cmd.exe pour bypasser les problèmes d'encodage de pipe (<) sous PowerShell
    cmd.exe /c "docker exec -i mariadb mariadb -umathias -proot sae < .\save\init.sql"
    if ($LASTEXITCODE -eq 0) { Write-Host "    -> Base de données importée." }
} else {
    Write-Host "    [!] Fichier ./save/init.sql introuvable. Skip." -ForegroundColor Yellow
}

# 6. Injection des assets WordPress (Thèmes, Plugins, Uploads)
Write-Host "[*] Etape 6 : Injection des assets WordPress..." -ForegroundColor Cyan
if (Test-Path "./save/wp-content") {
    foreach ($asset in @("themes", "plugins", "uploads")) {
        if (Test-Path "./save/wp-content/$asset") {
            Write-Host "    -> Copie de $asset..."
            # Le '/.' copie le contenu total du dossier pour éviter les conflits d'arborescence
            docker cp "./save/wp-content/$asset/." "wordpress:/var/www/html/wp-content/$asset/"
        }
    }
}

# 7. Application des permissions sur le Web (WordPress)
Write-Host "[*] Etape 7 : Application des permissions (www-data)..." -ForegroundColor Cyan
docker exec wordpress chown -R www-data:www-data /var/www/html
docker exec wordpress find /var/www/html -type d -exec chmod 755 {} ";"
docker exec wordpress find /var/www/html -type f -exec chmod 644 {} ";"

# 8. Initialisation de Symfony
Write-Host "[*] Etape 8 : Setup du Web Symfony..." -ForegroundColor Cyan
if (docker ps -q -f name=symfony) {
    # /bin/sh -c évite l'erreur de flag avec PowerShell
    docker exec symfony /bin/sh -c "composer install --no-interaction --optimize-autoloader"
    # Permissions sur les dossiers de cache/log Symfony
    docker exec symfony chown -R www-data:www-data /var/www/html/var
    Write-Host "    -> Dépendances et permissions Symfony configurées."
} else {
    Write-Host "    [-] Conteneur Symfony inactif." -ForegroundColor Red
}

# 9. Affichage des accès
Write-Host "`n[!] Déploiement terminé avec succès." -ForegroundColor Green
Write-Host "-------------------------------------------------------"
Write-Host "=> WordPress (HTTP)  : http://$IP_LOCALE" -ForegroundColor Cyan
Write-Host "=> WordPress (HTTPS) : https://$IP_LOCALE" -ForegroundColor Cyan
Write-Host "=> Admin WordPress   : http://$IP_LOCALE/wp-admin/" -ForegroundColor Cyan
Write-Host "=> Symfony App       : http://$IP_LOCALE/symfony/" -ForegroundColor Magenta
Write-Host "=> phpMyAdmin        : http://$IP_LOCALE/phpmyadmin/" -ForegroundColor Yellow
Write-Host "-------------------------------------------------------"
Write-Host "Note : Les accès sont également fonctionnels sur 'localhost'"