#!/usr/bin/env bash


export myUID=`id -u ${whoami}`
export myIP=`ifconfig $(netstat -rn | grep -E "^default|^0.0.0.0" | head -1 | awk '{print $NF}') | grep 'inet ' | awk '{print $2}' | grep -Eo '([0-9]*\.){3}[0-9]*'`


cp docker/Dockerfile_orig  docker/Dockerfile
cp .env.dist .env


if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|<UID>|${myUID}|" ./docker/Dockerfile
    sed -i '' "s|<myIP>|${myIP}|" .env
    sed -i '' "s|<solr_user>|${solr_user}|" .env
    sed -i '' "s|<solr_password>|${solr_password}|" .env
else
    sed -i "s|<UID>|${myUID}|" ./docker/Dockerfile
    sed -i "s|<myIP>|${myIP}|" .env
    sed -i "s|<solr_user>|${solr_user}|" .env
    sed -i "s|<solr_password>|${solr_password}|" .env
fi


#mvn clean package
#cp target/nlh-importer-verticle-1.0-SNAPSHOT.jar  docker/lib/
cp src/main/resources/start.rb docker/

docker-compose -f docker-compose_deploy.yml build --force-rm --no-cache
#docker-compose -f docker-compose_deploy.yml build --force-rm

docker-compose -f docker-compose_deploy.yml stop
docker-compose -f docker-compose_deploy.yml rm -f
docker-compose -f docker-compose_deploy.yml up -d

