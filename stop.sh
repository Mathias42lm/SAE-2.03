docker exec mariadb mariadb-dump -u mathias -proot sae > init.sql
docker compose stop 