#!/usr/bin/env bash

source .cfg

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

export myUID=`id -u ${whoami}`

export SOLR_PORT=8983
export SOLR_EXTERNAL_PORT=8443

export SOLR_JAVA_MEM='-Xms512M -Xmx7G'

export SERVICE_VERTICLE=start_services.rb
export INDEXER_VERTICLE=start_indexer.rb
export CONVERTER_VERTICLE=start_converter.rb

export VERTICLE_HOME=/usr/verticles
export CONVERTER_VERTX_OPTIONS="--workerPoolSize 40 --blockedThreadCheckInterval 3600000 --maxEventLoopExecuteTime 600000000000 --maxWorkerExecuteTime 3400000000000 maxEventLoopExecuteTime 600000000000"

export LOGO_PATH=${VERTICLE_HOME}/image/sub-blue.svg
export FONT_PATH=${VERTICLE_HOME}/font

export PATH="$HOME/.cargo/bin:/usr/local/go/bin:$PATH"
export GOPATH=/Users/jpanzer/Documents/projects/test/go
export GOROOT=/usr/local/go

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


if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|<uid>|${myUID}|"                           ./docker/Dockerfile
    sed -i '' "s|<verticle_home>|${VERTICLE_HOME}|"         ./docker/Dockerfile

    sed -i '' "s|<verticle_home>|${VERTICLE_HOME}|"         ./docker/Dockerfile

    sed -i '' "s|<solr_core>|${solr_core}|g"                ./docker-compose.yml
    sed -i '' "s|<solr_core2>|${solr_core2}|g"              ./docker-compose.yml

    sed -i '' "s|<solr_core>|${solr_core}|"                 ./docker/solr/Dockerfile
    sed -i '' "s|<solr_core2>|${solr_core2}|"               ./docker/solr/Dockerfile
    sed -i '' "s|<solr_port>|${SOLR_PORT}|"                 ./docker/solr/Dockerfile

    sed -i '' "s|<solr_core>|${solr_core}|"                 ./docker/solr/config/sub/core.properties
    sed -i '' "s|<solr_core>|${solr_core2}|"                ./docker/solr/config/sub/core2.properties

    sed -i '' "s|<solr_port>|${SOLR_PORT}|g"                ./docker/solr/config/sub/jetty.xml

    sed -i '' "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"         ./docker/solr/config/solr.in.sh
    sed -i '' "s|<solr_port>|${SOLR_PORT}|"                 ./docker/solr/config/solr.in.sh

    sed -i '' "s|<solr_port>|${SOLR_PORT}|g"                                .env
    sed -i '' "s|<solr_external_port>|${SOLR_EXTERNAL_PORT}|g"              .env
    sed -i '' "s|<logo_path>|${LOGO_PATH}|g"                                .env
    sed -i '' "s|<font_path>|${FONT_PATH}|g"                                .env
    sed -i '' "s|<s3_provider>|${S3_PROVIDER}|g"                            .env
    sed -i '' "s|<s3_aws_access_key_id>|${S3_AWS_ACCESS_KEY_ID}|g"          .env
    sed -i '' "s|<s3_aws_secret_access_key>|${S3_AWS_SECRET_ACCESS_KEY}|g"  .env
    sed -i '' "s|<s3_endpoint>|${S3_ENDPOINT}|g"                            .env
    sed -i '' "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"                         .env
    sed -i '' "s|<local_host>|${LOCAL_HOST}|"                               .env
    sed -i '' "s|<service_host>|${SERVICE_HOST}|"                           .env
    sed -i '' "s|<redis_host>|${REDIS_HOST}|"                               .env
    sed -i '' "s|<solr_host>|${SOLR_HOST}|"                                 .env
    sed -i '' "s|<graylog_host>|${GRAYLOG_HOST}|"                           .env
    sed -i '' "s|<graylog_port>|${GRAYLOG_PORT}|"                           .env
    sed -i '' "s|<solr_core>|${solr_core}|"                                 .env
    sed -i '' "s|<solr_core2>|${solr_core2}|"                               .env
    sed -i '' "s|<service_verticle>|${SERVICE_VERTICLE}|"                   .env
    sed -i '' "s|<indexer_verticle>|${INDEXER_VERTICLE}|"                   .env
    sed -i '' "s|<converter_verticle>|${CONVERTER_VERTICLE}|"               .env
    sed -i '' "s|<verticle_home>|${VERTICLE_HOME}|"                         .env
    sed -i '' "s|<converter_vertx_options>|${CONVERTER_VERTX_OPTIONS}|"     .env

else
    sed -i "s|<uid>|${myUID}|"                               ./docker/Dockerfile
    sed -i "s|<verticle_home>|${VERTICLE_HOME}|"             ./docker/Dockerfile

    sed -i "s|<solr_core>|${solr_core}|g"                    ./docker-compose.yml
    sed -i "s|<solr_core2>|${solr_core2}|g"                  ./docker-compose.yml

    sed -i "s|<solr_core>|${solr_core}|"                     ./docker/solr/Dockerfile
    sed -i "s|<solr_core2>|${solr_core2}|"                   ./docker/solr/Dockerfile
    sed -i "s|<solr_port>|${SOLR_PORT}|"                     ./docker/solr/Dockerfile

    sed -i "s|<solr_core>|${solr_core}|"                     ./docker/solr/config/sub/core.properties
    sed -i "s|<solr_core>|${solr_core2}|"                    ./docker/solr/config/sub/core2.properties

    sed -i "s|<solr_port>|${SOLR_PORT}|g"                    ./docker/solr/config/sub/jetty.xml

    sed -i "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"             ./docker/solr/config/solr.in.sh
    sed -i "s|<solr_port>|${SOLR_PORT}|"                     ./docker/solr/config/solr.in.sh

    sed -i "s|<solr_port>|${SOLR_PORT}|g"                                   .env
    sed -i "s|<solr_external_port>|${SOLR_EXTERNAL_PORT}|g"                 .env
    sed -i "s|<logo_path>|${LOGO_PATH}|g"                                   .env
    sed -i "s|<font_path>|${FONT_PATH}|g"                                   .env
    sed -i "s|<s3_provider>|${S3_PROVIDER}|g"                               .env
    sed -i "s|<s3_aws_access_key_id>|${S3_AWS_ACCESS_KEY_ID}|g"             .env
    sed -i "s|<s3_aws_secret_access_key>|${S3_AWS_SECRET_ACCESS_KEY}|g"     .env
    sed -i "s|<s3_endpoint>|${S3_ENDPOINT}|g"                               .env
    sed -i "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"                            .env
    sed -i "s|<local_host>|${LOCAL_HOST}|"                                  .env
    sed -i "s|<service_host>|${SERVICE_HOST}|"                              .env
    sed -i "s|<redis_host>|${REDIS_HOST}|"                                  .env
    sed -i "s|<solr_host>|${SOLR_HOST}|"                                    .env
    sed -i "s|<graylog_host>|${GRAYLOG_HOST}|"                              .env
    sed -i "s|<graylog_port>|${GRAYLOG_PORT}|"                              .env
    sed -i "s|<solr_core>|${solr_core}|"                                    .env
    sed -i "s|<solr_core2>|${solr_core2}|"                                  .env
    sed -i "s|<service_verticle>|${SERVICE_VERTICLE}|"                      .env
    sed -i "s|<indexer_verticle>|${INDEXER_VERTICLE}|"                      .env
    sed -i "s|<converter_verticle>|${CONVERTER_VERTICLE}|"                  .env
    sed -i "s|<verticle_home>|${VERTICLE_HOME}|"                            .env
    sed -i "s|<converter_vertx_options>|${CONVERTER_VERTX_OPTIONS}|"        .env
fi



#mvn clean package
#cp target/nlh-importer-verticle-1.0-SNAPSHOT.jar  docker/lib/


# 18.25
#docker-compose build --force-rm  importer_services solr redis
#docker-compose stop
#docker-compose rm -f
#docker-compose up -d importer_services solr redis

# 19.72
#docker-compose build --force-rm  importer_indexer importer_converter
#docker-compose stop
#docker-compose rm -f
#docker-compose up -d importer_log_converter importer_converter importer_indexer

# local
#docker-compose build --force-rm
#docker-compose stop
#docker-compose rm -f
#docker-compose up -d




# docker-compose up -d --scale  importer_converter=2 importer_converter importer_indexer

