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

export solr_port=8983
export solr_external_port=8443

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
cp .env_orig .env

cp docker/solr/Dockerfile_orig  docker/solr/Dockerfile
cp docker/solr/config/solr.in.sh_orig ./docker/solr/config/solr.in.sh
cp docker/solr/config/sub/jetty_orig.xml docker/solr/config/sub/jetty.xml

export S3_PROVIDER=${S3_PROVIDER}
export S3_AWS_ACCESS_KEY_ID=${S3_AWS_ACCESS_KEY_ID}
export S3_AWS_SECRET_ACCESS_KEY=${S3_AWS_SECRET_ACCESS_KEY}
export S3_ENDPOINT=${S3_ENDPOINT}


export SERVICE_VERTICLE=start_services.rb
export INDEXER_VERTICLE=start_indexer.rb
export CONVERTER_VERTICLE=start_converter.rb
export VERTICLE_HOME=/usr/verticles
export CONVERTER_VERTX_OPTIONS="--workerPoolSize 40 --blockedThreadCheckInterval 3600000 --maxEventLoopExecuteTime 600000000000 --maxWorkerExecuteTime 3400000000000 maxEventLoopExecuteTime 600000000000"
export LOGO_PATH=${VERTICLE_HOME}/image/sub-blue.svg
export FONT_PATH=${VERTICLE_HOME}/font

export SOLR_JAVA_MEM='-Xms512M -Xmx7G'



if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|<UID>|${myUID}|"                               ./docker/Dockerfile
    sed -i '' "s|<VERTICLE_HOME>|${VERTICLE_HOME}|"             ./docker/Dockerfile


    sed -i '' "s|<solr_core>|${solr_core}|"                     ./docker/solr/Dockerfile
    sed -i '' "s|<solr_core2>|${solr_core2}|"                   ./docker/solr/Dockerfile
    sed -i '' "s|<solr_port>|${solr_port}|"                     ./docker/solr/Dockerfile

    sed -i '' "s|<solr_core>|${solr_core}|g"                    ./docker-compose.yml
    sed -i '' "s|<solr_core2>|${solr_core2}|g"                  ./docker-compose.yml


    sed -i '' "s|<solr_core>|${solr_core}|"                     ./docker/solr/config/sub/core.properties
    sed -i '' "s|<solr_core>|${solr_core2}|"                    ./docker/solr/config/sub/core2.properties



    sed -i '' "s|<solr_port>|${solr_port}|g"                            .env
    sed -i '' "s|<solr_port2>|${solr_port2}|g"                          .env

    sed -i '' "s|<solr_external_port>|${solr_external_port}|g"          .env
    sed -i '' "s|<solr_external_port2>|${solr_external_port2}|g"        .env

    sed -i '' "s|<logo_path>|${LOGO_PATH}|g"         .env
    sed -i '' "s|<font_path>|${FONT_PATH}|g"         .env


    sed -i '' "s|<S3_PROVIDER>|${S3_PROVIDER}|g"                             .env
    sed -i '' "s|<S3_AWS_ACCESS_KEY_ID>|${S3_AWS_ACCESS_KEY_ID}|g"           .env
    sed -i '' "s|<S3_AWS_SECRET_ACCESS_KEY>|${S3_AWS_SECRET_ACCESS_KEY}|g"   .env
    sed -i '' "s|<S3_ENDPOINT>|${S3_ENDPOINT}|g"                             .env



    sed -i '' "s|<solr_port>|${solr_port}|g"                    ./docker/solr/config/sub/jetty.xml


    sed -i '' "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"             ./docker/solr/config/solr.in.sh


    sed -i '' "s|<solr_port>|${solr_port}|"                     ./docker/solr/config/solr.in.sh


    sed -i '' "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"             .env


    sed -i '' "s|<myIP>|${myIP}|"                               .env

    sed -i '' "s|<solr_core>|${solr_core}|"                     .env
    sed -i '' "s|<solr_core2>|${solr_core2}|"                   .env

    sed -i '' "s|<solr_user>|${solr_user}|"                     .env
    sed -i '' "s|<solr_password>|${solr_password}|"             .env

    sed -i '' "s|<SERVICE_VERTICLE>|${SERVICE_VERTICLE}|"       .env
    sed -i '' "s|<INDEXER_VERTICLE>|${INDEXER_VERTICLE}|"       .env
    sed -i '' "s|<CONVERTER_VERTICLE>|${CONVERTER_VERTICLE}|"   .env
    sed -i '' "s|<VERTICLE_HOME>|${VERTICLE_HOME}|"             .env
    sed -i '' "s|<CONVERTER_VERTX_OPTIONS>|${CONVERTER_VERTX_OPTIONS}|"             .env

else
    sed -i "s|<UID>|${myUID}|"                               ./docker/Dockerfile
    sed -i "s|<VERTICLE_HOME>|${VERTICLE_HOME}|"             ./docker/Dockerfile


    sed -i "s|<solr_core>|${solr_core}|"                     ./docker/solr/Dockerfile
    sed -i "s|<solr_core2>|${solr_core2}|"                   ./docker/solr/Dockerfile
    sed -i "s|<solr_port>|${solr_port}|"                     ./docker/solr/Dockerfile

    sed -i "s|<solr_core>|${solr_core}|g"                    ./docker-compose.yml
    sed -i "s|<solr_core2>|${solr_core2}|g"                  ./docker-compose.yml


    sed -i "s|<solr_core>|${solr_core}|"                     ./docker/solr/config/sub/core.properties
    sed -i "s|<solr_core>|${solr_core2}|"                    ./docker/solr/config/sub/core2.properties



    sed -i "s|<solr_port>|${solr_port}|g"                            .env
    sed -i "s|<solr_port2>|${solr_port2}|g"                          .env

    sed -i "s|<solr_external_port>|${solr_external_port}|g"          .env
    sed -i "s|<solr_external_port2>|${solr_external_port2}|g"        .env

    sed -i "s|<logo_path>|${LOGO_PATH}|g"         .env
    sed -i "s|<font_path>|${FONT_PATH}|g"         .env

    sed -i "s|<S3_PROVIDER>|${S3_PROVIDER}|g"                             .env
    sed -i "s|<S3_AWS_ACCESS_KEY_ID>|${S3_AWS_ACCESS_KEY_ID}|g"           .env
    sed -i "s|<S3_AWS_SECRET_ACCESS_KEY>|${S3_AWS_SECRET_ACCESS_KEY}|g"   .env
    sed -i "s|<S3_ENDPOINT>|${S3_ENDPOINT}|g"                             .env




    sed -i "s|<solr_port>|${solr_port}|g"                    ./docker/solr/config/sub/jetty.xml


    sed -i "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"             ./docker/solr/config/solr.in.sh


    sed -i "s|<solr_port>|${solr_port}|"                     ./docker/solr/config/solr.in.sh


    sed -i "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"             .env


    sed -i "s|<myIP>|${myIP}|"                               .env

    sed -i "s|<solr_core>|${solr_core}|"                     .env
    sed -i "s|<solr_core2>|${solr_core2}|"                   .env

    sed -i "s|<solr_user>|${solr_user}|"                     .env
    sed -i "s|<solr_password>|${solr_password}|"             .env

    sed -i "s|<SERVICE_VERTICLE>|${SERVICE_VERTICLE}|"       .env
    sed -i "s|<INDEXER_VERTICLE>|${INDEXER_VERTICLE}|"       .env
    sed -i "s|<CONVERTER_VERTICLE>|${CONVERTER_VERTICLE}|"   .env
    sed -i "s|<VERTICLE_HOME>|${VERTICLE_HOME}|"             .env
    sed -i "s|<CONVERTER_VERTX_OPTIONS>|${CONVERTER_VERTX_OPTIONS}|"             .env
fi



#mvn clean package
#cp target/nlh-importer-verticle-1.0-SNAPSHOT.jar  docker/lib/

docker-compose build --force-rm  # importer_services importer_indexer importer_converter solr


docker-compose stop
docker-compose rm -f
#docker-compose up -d importer_converter importer_services importer_converter
#docker-compose up -d --no-deps --no-recreate --no-build
#docker-compose up -d --scale importer_converter=1
docker-compose up -d
#docker-compose up -d --scale importer_converter=3 redis importer_converter
#docker-compose up -d --scale  importer_indexer=2 importer_converter importer_indexer
