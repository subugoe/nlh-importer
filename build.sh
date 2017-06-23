#!/usr/bin/env bash


if [ -z "$solr_core" ]
then
    export solr_core="gdz"
fi


if [ -z "$solr_core2" ]
then
    export solr_core2="gdz_tmp"
fi


if [ -z "$environment" ]
then
    export environment="develop"
fi


export solr_core=${solr_core}
export myUID=`id -u ${whoami}`
export myIP=`ifconfig $(netstat -rn | grep -E "^default|^0.0.0.0" | head -1 | awk '{print $NF}') | grep 'inet ' | awk '{print $2}' | grep -Eo '([0-9]*\.){3}[0-9]*'`

mkdir -p data/solr/$solr_core/data/
mkdir -p data/solr/$solr_core2/data/

cp src/main/resources/start_services.rb docker/
cp src/main/resources/start_indexer.rb docker/
cp src/main/resources/start_converter.rb docker/

cp docker-compose_orig.yml docker-compose.yml

cp docker/Dockerfile_orig  docker/Dockerfile
cp docker/solr/Dockerfile_orig  docker/solr/Dockerfile
cp docker/solr/config/sub/core.properties_orig  docker/solr/config/sub/core.properties
cp docker/solr/config/sub/core.properties_orig  docker/solr/config/sub/core2.properties
cp .env_orig .env
cp ./docker/solr/config/solr.in.sh_orig ./docker/solr/config/solr.in.sh


SERVICE_VERTICLE=start_services.rb
INDEXER_VERTICLE=start_indexer.rb
CONVERTER_VERTICLE=start_converter.rb
VERTICLE_HOME=/usr/verticles

SOLR_JAVA_MEM="-Xms512M -Xmx7424M"
SOLR_MEM_LIMIT=8GB


if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|<UID>|${myUID}|"                               ./docker/Dockerfile
    sed -i '' "s|<VERTICLE_HOME>|${VERTICLE_HOME}|"             ./docker/Dockerfile

    sed -i '' "s|<solr_core>|${solr_core}|"                     ./docker/solr/Dockerfile
    sed -i '' "s|<solr_core2>|${solr_core2}|"                   ./docker/solr/Dockerfile

    sed -i '' "s|<solr_core>|${solr_core}|"                     ./docker/solr/config/sub/core.properties
    sed -i '' "s|<solr_core>|${solr_core2}|"                    ./docker/solr/config/sub/core2.properties

    sed -i '' "s|<solr_core>|${solr_core}|g"                    ./docker-compose.yml
    sed -i '' "s|<solr_core2>|${solr_core2}|g"                  ./docker-compose.yml

    sed -i '' "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"             ./docker/solr/config/solr.in.sh
    sed -i '' "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"             .env
    sed -i '' "s|<solr_mem_limit>|${SOLR_MEM_LIMIT}|"           .env

    sed -i '' "s|<myIP>|${myIP}|"                               .env

    sed -i '' "s|<solr_core>|${solr_core}|"                     .env
    sed -i '' "s|<solr_core2>|${solr_core2}|"                   .env

    sed -i '' "s|<solr_user>|${solr_user}|"                     .env
    sed -i '' "s|<solr_password>|${solr_password}|"             .env

    sed -i '' "s|<SERVICE_VERTICLE>|${SERVICE_VERTICLE}|"       .env
    sed -i '' "s|<INDEXER_VERTICLE>|${INDEXER_VERTICLE}|"       .env
    sed -i '' "s|<CONVERTER_VERTICLE>|${CONVERTER_VERTICLE}|"   .env
    sed -i '' "s|<VERTICLE_HOME>|${VERTICLE_HOME}|"             .env

else
    sed -i "s|<UID>|${myUID}|"                               ./docker/Dockerfile
    sed -i "s|<VERTICLE_HOME>|${VERTICLE_HOME}|"             ./docker/Dockerfile

    sed -i "s|<solr_core>|${solr_core}|"                     ./docker/solr/Dockerfile
    sed -i "s|<solr_core2>|${solr_core2}|"                   ./docker/solr/Dockerfile

    sed -i "s|<solr_core>|${solr_core}|"                     ./docker/solr/config/sub/core.properties
    sed -i "s|<solr_core>|${solr_core2}|"                    ./docker/solr/config/sub/core2.properties

    sed -i "s|<solr_core>|${solr_core}|g"                    ./docker-compose.yml
    sed -i "s|<solr_core2>|${solr_core2}|g"                  ./docker-compose.yml

    sed -i "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"             ./docker/solr/config/solr.in.sh
    sed -i "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"             .env
    sed -i "s|<solr_mem_limit>|${SOLR_MEM_LIMIT}|"           .env

    sed -i "s|<myIP>|${myIP}|"                               .env

    sed -i "s|<solr_core>|${solr_core}|"                     .env
    sed -i "s|<solr_core2>|${solr_core2}|"                   .env

    sed -i "s|<solr_user>|${solr_user}|"                     .env
    sed -i "s|<solr_password>|${solr_password}|"             .env

    sed -i "s|<SERVICE_VERTICLE>|${SERVICE_VERTICLE}|"       .env
    sed -i "s|<INDEXER_VERTICLE>|${INDEXER_VERTICLE}|"       .env
    sed -i "s|<CONVERTER_VERTICLE>|${CONVERTER_VERTICLE}|"   .env
    sed -i "s|<VERTICLE_HOME>|${VERTICLE_HOME}|"             .env
fi



#mvn clean package
#cp target/nlh-importer-verticle-1.0-SNAPSHOT.jar  docker/lib/


#docker-compose build --force-rm --no-cache solr
#docker-compose build --force-rm importer_converter importer_indexer importer_services redis
docker-compose build --force-rm


docker-compose stop
docker-compose rm -f
#docker-compose up -d importer_converter importer_indexer importer_services solr redis
docker-compose up -d


