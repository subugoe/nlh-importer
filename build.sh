#!/usr/bin/env bash


export myUID=`id -u ${whoami}`
export myIP=`ifconfig $(netstat -rn | grep -E "^default|^0.0.0.0" | head -1 | awk '{print $NF}') | grep 'inet ' | awk '{print $2}' | grep -Eo '([0-9]*\.){3}[0-9]*'`

cp src/main/resources/start_services.rb docker/
cp src/main/resources/start_indexer.rb docker/
cp src/main/resources/start_converter.rb docker/

cp docker/Dockerfile_orig  docker/Dockerfile
cp .env.dist .env


SERVICE_VERTICLE=start_services.rb
INDEXER_VERTICLE=start_indexer.rb
CONVERTER_VERTICLE=start_converter.rb
VERTICLE_HOME=/usr/verticles


if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|<UID>|${myUID}|" ./docker/Dockerfile
    sed -i '' "s|<VERTICLE_HOME>|${VERTICLE_HOME}|" ./docker/Dockerfile
    sed -i '' "s|<myIP>|${myIP}|" .env
    sed -i '' "s|<solr_user>|${solr_user}|" .env
    sed -i '' "s|<solr_password>|${solr_password}|" .env
    sed -i '' "s|<SERVICE_VERTICLE>|${SERVICE_VERTICLE}|" .env
    sed -i '' "s|<INDEXER_VERTICLE>|${INDEXER_VERTICLE}|" .env
    sed -i '' "s|<CONVERTER_VERTICLE>|${CONVERTER_VERTICLE}|" .env
    sed -i '' "s|<VERTICLE_HOME>|${VERTICLE_HOME}|" .env
else
    sed -i "s|<UID>|${myUID}|" ./docker/Dockerfile
    sed -i "s|<VERTICLE_HOME>|${VERTICLE_HOME}|" ./docker/Dockerfile
    sed -i "s|<myIP>|${myIP}|" .env
    sed -i "s|<solr_user>|${solr_user}|" .env
    sed -i "s|<solr_password>|${solr_password}|" .env
    sed -i "s|<SERVICE_VERTICLE>|${SERVICE_VERTICLE}|" .env
    sed -i "s|<INDEXER_VERTICLE>|${INDEXER_VERTICLE}|" .env
    sed -i "s|<CONVERTER_VERTICLE>|${CONVERTER_VERTICLE}|" .env
    sed -i "s|<VERTICLE_HOME>|${VERTICLE_HOME}|" .env
fi


#mvn clean package
#cp target/nlh-importer-verticle-1.0-SNAPSHOT.jar  docker/lib/

#docker-compose build --force-rm --no-cache
docker-compose build --force-rm

docker-compose stop
docker-compose rm -f
docker-compose up -d importer_converter importer_indexer importer_services solr redis

