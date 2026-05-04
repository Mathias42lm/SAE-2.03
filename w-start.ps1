# Configuration de l'encodage pour les emojis et couleurs
$OutputEncoding = [System.Text.Encoding]::UTF8

# Couleurs pour le feedback
$GREEN = "Green"
$RED = "Red"
$WHITE = "White"

Write-Host "[*] Initialisation du déploiement SAE-2.03..." -ForegroundColor $GREEN

# 1. Nettoyage des artefacts Docker fantômes
# Sous Windows/Docker Desktop, les montages de fichiers inexistants créent parfois des dossiers
if (Test-Path "./init.sql" -PathType Container) {
    Write-Host "[!] Alerte : init.sql est un répertoire. Correction..." -ForegroundColor $RED
    Remove-Item -Recurse -Force "./save/init.sql"
    New-Item -ItemType File "./save/init.sql" > $null
}

# 2. Correction des permissions sur l'hôte
# Note : Sur Windows (NTFS), chown 999:999 n'est pas applicable directement. 
# Docker Desktop gère généralement le mapping. On s'assure juste que les dossiers existent.
Write-Host "[*] Vérification des répertoires de volumes..."
foreach ($dir in @("./db", "./wordpress")) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory $dir | Out-Null
    }
}

# 3. Lancement de la stack
Write-Host "[*] Lancement de Docker Compose..."
docker compose up -d --remove-orphans

if ($LASTEXITCODE -eq 0) {
    Write-Host "[+] Stack démarrée." -ForegroundColor $GREEN
} else {
    Write-Host "[-] Erreur lors du docker compose up." -ForegroundColor $RED
    exit 1
}

# 4. Correction dynamique des permissions (post-boot)
# On exécute les commandes à l'intérieur du conteneur Linux
Write-Host "[*] Application des ACL internes (www-data)..."
docker exec -it wordpress chown -R www-data:www-data /var/www/html
docker exec -it wordpress find /var/www/html -type d -exec chmod 755 {} ";"
docker exec -it wordpress find /var/www/html -type f -exec chmod 644 {} ";"

# 5. Healthcheck MariaDB
Write-Host -NoNewline "[*] Attente de MariaDB..."
while ($true) {
    docker exec mariadb mariadb-admin ping -h localhost --silent 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host -NoNewline "."
    Start-Sleep -Seconds 2
}
Write-Host "`n[+] MariaDB est prêt." -ForegroundColor $GREEN

Write-Host "[!] Déploiement terminé avec succès." -ForegroundColor $GREEN
Write-Host "Wordpress: http://localhost:80"
Write-Host "phpMyAdmin: http://localhost:8080"
Write-Host "Wordpress Admin : http://localhost:80/wp-admin/"