#!/usr/bin/env bash
if ! [[ -f ./.env ]]; then cp .env.dist .env; fi



export myUID=`id -u ${whoami}`
export myGID=`id -g ${whoami}`
export myIP=`ifconfig $(netstat -rn | grep -E "^default|^0.0.0.0" | head -1 | awk '{print $NF}') | grep 'inet ' | awk '{print $2}' | grep -Eo '([0-9]*\.){3}[0-9]*'`

cp docker/solr/Dockerfile_orig  docker/solr/Dockerfile
cp docker/redis/Dockerfile_orig  docker/redis/Dockerfile
cp docker/Dockerfile_orig  docker/Dockerfile

sed -i '' "s|<UID>|${myUID}|" ./docker/solr/Dockerfile
sed -i '' "s|<GID>|${myGID}|" ./docker/solr/Dockerfile

sed -i '' "s|<UID>|${myUID}|" ./docker/redis/Dockerfile
sed -i '' "s|<GID>|${myGID}|" ./docker/redis/Dockerfile

sed -i '' "s|<UID>|${myUID}|" ./docker/Dockerfile
sed -i '' "s|<GID>|${myGID}|" ./docker/Dockerfile


#mvn clean package
#cp target/nlh-importer-verticle-1.0-SNAPSHOT.jar  docker/lib/
cp src/main/resources/start.rb docker/

#docker-compose -f docker-compose_deploy.yml build --force-rm --no-cache
docker-compose -f docker-compose_deploy.yml build --force-rm

docker-compose -f docker-compose_deploy.yml stop
docker-compose -f docker-compose_deploy.yml rm -f

docker-compose -f docker-compose_deploy.yml up -d
