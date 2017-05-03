#!/usr/bin/env bash
if ! [[ -f ./.env ]]; then cp .env.dist .env; fi
docker-compose stop importer
docker-compose rm -f importer
#mvn clean package
#cp target/nlh-importer-verticle-1.0-SNAPSHOT.jar  docker/lib/
cp src/main/resources/start.rb docker/
#docker-compose build --no-cache --force-rm importer
docker-compose build --force-rm importer
docker-compose up -d importer
