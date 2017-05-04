#!/usr/bin/env bash
if ! [[ -f ./.env ]]; then cp .env.dist .env; fi

export myUID=`id -u ${whoami}`
export myGID=`id -g ${whoami}`
export myIP=`ifconfig $(netstat -rn | grep -E "^default|^0.0.0.0" | head -1 | awk '{print $NF}') | grep 'inet ' | awk '{print $2}' | grep -Eo '([0-9]*\.){3}[0-9]*'`

cp src/main/resources/start.rb docker/

docker-compose -f docker-compose_deploy.yml build --no-cache --force-rm

docker-compose -f docker-compose_deploy.yml stop
docker-compose -f docker-compose_deploy.yml rm -f

docker-compose -f docker-compose_deploy.yml up -d

