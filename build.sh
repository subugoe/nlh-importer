#!/usr/bin/env bash

if [ -z "$solr_core" ]
then
    export solr_core="gdz"
fi


if [ -z "$environment" ]
then
    export environment="develop"
fi


export solr_core=${solr_core}
export myUID=`id -u ${whoami}`
export myIP=`ifconfig $(netstat -rn | grep -E "^default|^0.0.0.0" | head -1 | awk '{print $NF}') | grep 'inet ' | awk '{print $2}' | grep -Eo '([0-9]*\.){3}[0-9]*'`


cp src/main/resources/start_services.rb docker/
cp src/main/resources/start_indexer.rb docker/
cp src/main/resources/start_converter.rb docker/

cp docker-compose_orig.yml docker-compose.yml
cp docker-compose_deploy_orig.yml docker-compose_deploy.yml

cp docker/Dockerfile_orig  docker/Dockerfile
cp docker/solr/Dockerfile_orig  docker/solr/Dockerfile
cp docker/solr/config/sub/core.properties_orig  docker/solr/config/sub/core.properties
cp .env_orig .env


SERVICE_VERTICLE=start_services.rb
INDEXER_VERTICLE=start_indexer.rb
CONVERTER_VERTICLE=start_converter.rb
VERTICLE_HOME=/usr/verticles


if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|<UID>|${myUID}|" ./docker/Dockerfile
    sed -i '' "s|<VERTICLE_HOME>|${VERTICLE_HOME}|" ./docker/Dockerfile
    sed -i '' "s|<solr_core>|${solr_core}|" ./docker/solr/Dockerfile
    sed -i '' "s|<solr_core>|${solr_core}|" ./docker/solr/config/sub/core.properties
    sed -i '' "s|<solr_core>|${solr_core}|" ./docker-compose.yml
    sed -i '' "s|<solr_core>|${solr_core}|" ./docker-compose_deploy.yml

    sed -i '' "s|<myIP>|${myIP}|" .env
    sed -i '' "s|<solr_core>|${solr_core}|" .env

    sed -i '' "s|<solr_user>|${solr_user}|" .env
    sed -i '' "s|<solr_password>|${solr_password}|" .env
    sed -i '' "s|<SERVICE_VERTICLE>|${SERVICE_VERTICLE}|" .env
    sed -i '' "s|<INDEXER_VERTICLE>|${INDEXER_VERTICLE}|" .env
    sed -i '' "s|<CONVERTER_VERTICLE>|${CONVERTER_VERTICLE}|" .env
    sed -i '' "s|<VERTICLE_HOME>|${VERTICLE_HOME}|" .env
else
    sed -i "s|<UID>|${myUID}|" ./docker/Dockerfile
    sed -i "s|<VERTICLE_HOME>|${VERTICLE_HOME}|" ./docker/Dockerfile
    sed -i "s|<solr_core>|${solr_core}|" ./docker/solr/Dockerfile
    sed -i "s|<solr_core>|${solr_core}|" ./docker/solr/config/sub/core.properties
    sed -i "s|<solr_core>|${solr_core}|" ./docker-compose.yml
    sed -i "s|<solr_core>|${solr_core}|" ./docker-compose_deploy.yml

    sed -i "s|<myIP>|${myIP}|" .env
    sed -i "s|<solr_core>|${solr_core}|" .env

    sed -i "s|<solr_user>|${solr_user}|" .env
    sed -i "s|<solr_password>|${solr_password}|" .env
    sed -i "s|<SERVICE_VERTICLE>|${SERVICE_VERTICLE}|" .env
    sed -i "s|<INDEXER_VERTICLE>|${INDEXER_VERTICLE}|" .env
    sed -i "s|<CONVERTER_VERTICLE>|${CONVERTER_VERTICLE}|" .env
    sed -i "s|<VERTICLE_HOME>|${VERTICLE_HOME}|" .env
fi



#mvn clean package
#cp target/nlh-importer-verticle-1.0-SNAPSHOT.jar  docker/lib/


if [ "$environment" == "develop" ]

then

    #docker-compose build --force-rm --no-cache
    docker-compose build --force-rm

    docker-compose stop
    docker-compose rm -f
    docker-compose up -d importer_converter importer_indexer importer_services solr redis
    #docker-compose up -d

else

    docker-compose -f docker-compose_deploy.yml build --force-rm --no-cache
    #docker-compose -f docker-compose_deploy.yml build --force-rm

    docker-compose -f docker-compose_deploy.yml stop
    docker-compose -f docker-compose_deploy.yml rm -f
    docker-compose -f docker-compose_deploy.yml up -d  importer_indexer importer_services importer_converter solr redis
    #docker-compose up -d

fi

