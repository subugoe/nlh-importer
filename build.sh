#!/usr/bin/env bash
if ! [[ -f ./.env ]]; then cp .env.dist .env; fi

export myUID=`id -u ${whoami}`
export myGID=`id -g ${whoami}`
export myIP=`ifconfig $(netstat -rn | grep -E "^default|^0.0.0.0" | head -1 | awk '{print $NF}') | grep 'inet ' | awk '{print $2}' | grep -Eo '([0-9]*\.){3}[0-9]*'`

#mvn clean package
#cp target/nlh-importer-verticle-1.0-SNAPSHOT.jar  docker/lib/
cp src/main/resources/start.rb docker/

#docker-compose build --force-rm --no-cache
docker-compose build --force-rm

docker-compose stop
docker-compose rm -f

docker-compose up -d

