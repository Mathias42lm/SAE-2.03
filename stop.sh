docker exec mariadb mariadb-dump -u mathias -proot sae > ./save/init.sql
docker network prune
docker compose stop 