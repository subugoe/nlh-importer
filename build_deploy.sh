#!/usr/bin/env bash
if ! [[ -f ./.env ]]; then cp .env.dist .env; fi

export myUID=`id -u ${whoami}`
export myGID=`id -g ${whoami}`

cp src/main/resources/start.rb docker/

docker-compose -f docker-compose_deploy.yml build --force-rm

docker-compose -f docker-compose_deploy.yml stop
docker-compose -f docker-compose_deploy.yml rm -f

docker-compose -f docker-compose_deploy.yml up -d

