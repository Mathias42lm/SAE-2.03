# Configuration de l'encodage pour les couleurs et accents
$OutputEncoding = [System.Text.Encoding]::UTF8

# Couleurs pour le feedback
$GREEN = "Green"
$RED = "Red"
$CYAN = "Cyan"

# Variables Symfony
$SYMFONY_REPO_URL = "https://github.com/Mathias42lm/EportfolioMathias.git"
$SYMFONY_DIR = "./symfony_app"

Write-Host "[*] Initialisation du déploiement SAE-2.03..." -ForegroundColor $GREEN

# 0. Préparation du code Symfony (Git sécurisé)
Write-Host "[*] Vérification du dépôt Symfony..." -ForegroundColor $CYAN
if (Test-Path "$SYMFONY_DIR\.git") {
    Write-Host "    -> Dépôt détecté. Mise à jour (Pull)..."
    # Lancement silencieux de git pull. Si erreur, on catch le code de sortie.
    git -C $SYMFONY_DIR pull
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] Attention : Le git pull a échoué. On continue avec le code local." -ForegroundColor $RED
    }
} else {
    Write-Host "    -> Clonage du dépôt Symfony..."
    git clone $SYMFONY_REPO_URL $SYMFONY_DIR
}

# 1. Nettoyage des artefacts Docker fantômes
if (Test-Path "./init.sql" -PathType Container) {
    Write-Host "[!] Alerte : init.sql est un répertoire (erreur Docker). Suppression..." -ForegroundColor $RED
    Remove-Item -Recurse -Force "./init.sql"
    New-Item -ItemType File "./init.sql" | Out-Null
}

# 2. Correction préventive des permissions sur l'hôte
# Sur Windows, pas de chown. On sécurise juste la création des dossiers pour éviter le mapping root de Docker
Write-Host "[*] Vérification des répertoires de volumes..." -ForegroundColor $CYAN
foreach ($dir in @("./db", "./wordpress")) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory $dir | Out-Null
    }
}

# 3. Lancement de la stack (Forçage strict du fichier docker-compose.yml)
Write-Host "[*] Lancement de Docker Compose..." -ForegroundColor $CYAN
docker compose -f docker-compose.yml up -d --build --remove-orphans

if ($LASTEXITCODE -eq 0) {
    Write-Host "[+] Stack démarrée." -ForegroundColor $GREEN
} else {
    Write-Host "[-] Erreur lors du docker compose up." -ForegroundColor $RED
    exit 1
}

# 4. Restauration WordPress (Thèmes, Plugins, Uploads)
if (Test-Path "./save/wp-content" -PathType Container) {
    Write-Host "[*] Injection des thèmes, plugins et médias sauvegardés..." -ForegroundColor $CYAN
    try { docker cp ./save/wp-content/themes wordpress:/var/www/html/wp-content/ 2>$null } catch {}
    try { docker cp ./save/wp-content/plugins wordpress:/var/www/html/wp-content/ 2>$null } catch {}
    if (Test-Path "./save/wp-content/uploads" -PathType Container) {
        try { docker cp ./save/wp-content/uploads wordpress:/var/www/html/wp-content/ 2>$null } catch {}
    }
}

# 5. Correction dynamique des permissions WordPress
Write-Host "[*] Application des ACL internes (WordPress)..." -ForegroundColor $CYAN
docker exec -it wordpress chown -R www-data:www-data /var/www/html
# Les guillemets autour du point-virgule sont obligatoires en PowerShell pour le find
docker exec -it wordpress find /var/www/html -type d -exec chmod 755 {} ";"
docker exec -it wordpress find /var/www/html -type f -exec chmod 644 {} ";"

# 6. Initialisation et permissions Symfony
Write-Host "[*] Installation des dépendances Symfony (Composer)..." -ForegroundColor $CYAN
# On vérifie si le conteneur existe et tourne
$symfonyStatus = docker ps -q -f name=symfony
if ($symfonyStatus) {
    docker exec -it symfony composer install --no-interaction --optimize-autoloader
    Write-Host "[*] Application des ACL internes (Symfony)..." -ForegroundColor $CYAN
    docker exec -it symfony chown -R www-data:www-data /var/www/html/var
} else {
    Write-Host "[-] Erreur: Le conteneur Symfony ne semble pas être actif." -ForegroundColor $RED
}

# 7. Healthcheck MariaDB (Avec les bons credentials)
Write-Host -NoNewline "[*] Attente de MariaDB..." -ForegroundColor $CYAN
while ($true) {
    docker exec mariadb mariadb-admin ping -h localhost -umathias -proot --silent 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host -NoNewline "."
    Start-Sleep -Seconds 2
}
Write-Host "`n[+] MariaDB est prêt." -ForegroundColor $GREEN

Write-Host "[!] Déploiement terminé avec succès." -ForegroundColor $GREEN
Write-Host "Wordpress       : http://192.168.100.10:80"
Write-Host "Wordpress Admin : http://192.168.100.10:80/wp-admin/"
Write-Host "Symfony App     : http://localhost:8001"
Write-Host "phpMyAdmin      : http://localhost:8080"