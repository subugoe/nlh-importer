export myUID=`id -u ${whoami}`
export myIP=`ifconfig $(netstat -rn | grep -E "^default|^0.0.0.0" | head -1 | awk '{print $NF}') | grep 'inet ' | awk '{print $2}' | grep -Eo '([0-9]*\.){3}[0-9]*'`

docker-compose stop importer_indexer
docker-compose rm -f importer_indexer
docker-compose up -d importer_indexer

