# Définition de l'encodage pour l'affichage console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[*] Initialisation de l'infrastructure SAÉ2.04..." -ForegroundColor Yellow

# Lancement des conteneurs en mode détaché
docker compose up -d

# Vérification du code de retour de la commande précédente
if ($LASTEXITCODE -eq 0) {
    Write-Host "[+] Conteneurs démarrés avec succès.`n" -ForegroundColor Green
} else {
    Write-Error "[-] Échec lors du démarrage de l'infrastructure."
    exit $LASTEXITCODE
}

# Affichage des processus en cours
Write-Host "[*] État des services :" -ForegroundColor Cyan
docker compose ps

# Rappel des routes d'accès réseau (à adapter selon tes ports réels)
Write-Host "`n[i] Points d'accès réseau :" -ForegroundColor DarkGray
Write-Host "  > Portfolio (Symfony) : http://localhost:8080"
Write-Host "  > MariaDB (Interne)   : mariadb:3306"
Write-Host "  > Samba               : \\localhost\partage (ou via IP du réseau sae_bridge)"