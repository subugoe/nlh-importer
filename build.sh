#!/usr/bin/env bash

source .cfg

if [ -z "$solr_gdz_core" ]
then
    export solr_gdz_core="gdz"
fi


if [ -z "$solr_gdz_core2" ]
then
    export solr_gdz_core2="gdz_tmp"
fi

export solr_nlh_core="nlh"

if [ -z "$environment" ]
then
    export environment="develop"
fi

export myUID=`id -u ${whoami}`

export SOLR_GDZ_PORT=8983
export SOLR_GDZ_EXTERNAL_PORT=8900

export SOLR_JAVA_MEM='-Xms512M -Xmx7G'

export SERVICE_VERTICLE=start_services.rb
export INDEXER_VERTICLE=start_indexer.rb
export CONVERTER_WORK_VERTICLE=start_work_converter.rb
export CONVERTER_IMG_LOG_VERTICLE=start_img_log_converter.rb
export CONVERTER_IMG_FULL_VERTICLE=start_img_full_converter.rb

export VERTICLE_HOME=/usr/verticles
export CONVERTER_VERTX_OPTIONS="--workerPoolSize 40 --blockedThreadCheckInterval 3600000 --maxEventLoopExecuteTime 600000000000 --maxWorkerExecuteTime 3400000000000 maxEventLoopExecuteTime 600000000000"

export GDZ_LOGO_PATH=${VERTICLE_HOME}/image/sub-blue.svg
export NLH_LOGO_PATH=${VERTICLE_HOME}/image/nlh_logo_2.png
export NLH_FOOTER_PATH=${VERTICLE_HOME}/image/nlh_products_footer.png
export FONT_PATH=${VERTICLE_HOME}/font

export PATH="$HOME/.cargo/bin:/usr/local/go/bin:$PATH"
export GOPATH=/Users/jpanzer/Documents/projects/test/go
export GOROOT=/usr/local/go

mkdir -p data/solr/$solr_gdz_core/data/
mkdir -p data/solr/$solr_gdz_core2/data/

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

    sed -i '' "s|<solr_gdz_core>|${solr_gdz_core}|g"                ./docker-compose.yml
    sed -i '' "s|<solr_gdz_core2>|${solr_gdz_core2}|g"              ./docker-compose.yml

    sed -i '' "s|<solr_gdz_core>|${solr_gdz_core}|"                 ./docker/solr/Dockerfile
    sed -i '' "s|<solr_gdz_core2>|${solr_gdz_core2}|"               ./docker/solr/Dockerfile
    sed -i '' "s|<solr_gdz_port>|${SOLR_GDZ_PORT}|"                 ./docker/solr/Dockerfile

    sed -i '' "s|<solr_gdz_core>|${solr_gdz_core}|"                 ./docker/solr/config/sub/core.properties
    sed -i '' "s|<solr_gdz_core>|${solr_gdz_core2}|"                ./docker/solr/config/sub/core2.properties

    sed -i '' "s|<solr_gdz_port>|${SOLR_GDZ_PORT}|g"                ./docker/solr/config/sub/jetty.xml

    sed -i '' "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"         ./docker/solr/config/solr.in.sh
    sed -i '' "s|<solr_gdz_port>|${SOLR_GDZ_PORT}|"                 ./docker/solr/config/solr.in.sh

    sed -i '' "s|<solr_gdz_port>|${SOLR_GDZ_PORT}|g"                                .env
    sed -i '' "s|<solr_gdz_external_port>|${SOLR_GDZ_EXTERNAL_PORT}|g"              .env
    sed -i '' "s|<gdz_logo_path>|${GDZ_LOGO_PATH}|g"                                        .env
    sed -i '' "s|<nlh_logo_path>|${NLH_LOGO_PATH}|g"                                        .env
    sed -i '' "s|<nlh_footer_path>|${NLH_FOOTER_PATH}|g"                                        .env
    sed -i '' "s|<font_path>|${FONT_PATH}|g"                                        .env
    sed -i '' "s|<s3_sub_provider>|${S3_SUB_PROVIDER}|g"                            .env
    sed -i '' "s|<s3_sub_aws_access_key_id>|${S3_SUB_AWS_ACCESS_KEY_ID}|g"          .env
    sed -i '' "s|<s3_sub_aws_secret_access_key>|${S3_SUB_AWS_SECRET_ACCESS_KEY}|g"  .env
    sed -i '' "s|<s3_sub_region>|${S3_SUB_REGION}|g"                                .env
    sed -i '' "s|<s3_sub_endpoint>|${S3_SUB_ENDPOINT}|g"                            .env
    sed -i '' "s|<s3_nlh_provider>|${S3_NLH_PROVIDER}|g"                            .env
    sed -i '' "s|<s3_nlh_aws_access_key_id>|${S3_NLH_AWS_ACCESS_KEY_ID}|g"          .env
    sed -i '' "s|<s3_nlh_aws_secret_access_key>|${S3_NLH_AWS_SECRET_ACCESS_KEY}|g"  .env
    sed -i '' "s|<s3_nlh_region>|${S3_NLH_REGION}|g"                                .env
    sed -i '' "s|<s3_nlh_endpoint>|${S3_NLH_ENDPOINT}|g"                            .env
    sed -i '' "s|<s3_digizeit_provider>|${S3_DIGIZEIT_PROVIDER}|g"                            .env
    sed -i '' "s|<s3_digizeit_aws_access_key_id>|${S3_DIGIZEIT_AWS_ACCESS_KEY_ID}|g"          .env
    sed -i '' "s|<s3_digizeit_aws_secret_access_key>|${S3_DIGIZEIT_AWS_SECRET_ACCESS_KEY}|g"  .env
    sed -i '' "s|<s3_digizeit_region>|${S3_DIGIZEIT_REGION}|g"                            .env
    sed -i '' "s|<s3_digizeit_endpoint>|${S3_DIGIZEIT_ENDPOINT}|g"                            .env
    sed -i '' "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"                         .env
    sed -i '' "s|<local_host>|${LOCAL_HOST}|"                               .env
    sed -i '' "s|<service_host>|${SERVICE_HOST}|"                           .env
    sed -i '' "s|<redis_host>|${REDIS_HOST}|"                               .env
    sed -i '' "s|<solr_gdz_host>|${SOLR_GDZ_HOST}|"                                 .env
    sed -i '' "s|<solr_nlh_host>|${SOLR_NLH_HOST}|"                                 .env
    sed -i '' "s|<graylog_uri>|${GRAYLOG_URI}|"                           .env
    sed -i '' "s|<graylog_port>|${GRAYLOG_PORT}|"                           .env
    sed -i '' "s|<solr_gdz_core>|${solr_gdz_core}|"                                 .env
    sed -i '' "s|<solr_gdz_core2>|${solr_gdz_core2}|"                               .env
    sed -i '' "s|<solr_nlh_core>|${solr_nlh_core}|"                                 .env
    sed -i '' "s|<service_verticle>|${SERVICE_VERTICLE}|"                   .env
    sed -i '' "s|<indexer_verticle>|${INDEXER_VERTICLE}|"                   .env
    sed -i '' "s|<converter_work_verticle>|${CONVERTER_WORK_VERTICLE}|"               .env
    sed -i '' "s|<converter_img_log_verticle>|${CONVERTER_IMG_LOG_VERTICLE}|"               .env
    sed -i '' "s|<converter_img_full_verticle>|${CONVERTER_IMG_FULL_VERTICLE}|"               .env
    sed -i '' "s|<verticle_home>|${VERTICLE_HOME}|"                         .env
    sed -i '' "s|<converter_vertx_options>|${CONVERTER_VERTX_OPTIONS}|"     .env

else
    sed -i "s|<uid>|${myUID}|"                               ./docker/Dockerfile
    sed -i "s|<verticle_home>|${VERTICLE_HOME}|"             ./docker/Dockerfile

    sed -i "s|<solr_gdz_core>|${solr_gdz_core}|g"                    ./docker-compose.yml
    sed -i "s|<solr_gdz_core2>|${solr_gdz_core2}|g"                  ./docker-compose.yml

    sed -i "s|<solr_gdz_core>|${solr_gdz_core}|"                     ./docker/solr/Dockerfile
    sed -i "s|<solr_gdz_core2>|${solr_gdz_core2}|"                   ./docker/solr/Dockerfile
    sed -i "s|<solr_gdz_port>|${SOLR_GDZ_PORT}|"                     ./docker/solr/Dockerfile

    sed -i "s|<solr_gdz_core>|${solr_gdz_core}|"                     ./docker/solr/config/sub/core.properties
    sed -i "s|<solr_gdz_core>|${solr_gdz_core2}|"                    ./docker/solr/config/sub/core2.properties

    sed -i "s|<solr_gdz_port>|${SOLR_GDZ_PORT}|g"                    ./docker/solr/config/sub/jetty.xml

    sed -i "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"             ./docker/solr/config/solr.in.sh
    sed -i "s|<solr_gdz_port>|${SOLR_GDZ_PORT}|"                     ./docker/solr/config/solr.in.sh

    sed -i "s|<solr_gdz_port>|${SOLR_GDZ_PORT}|g"                                   .env
    sed -i "s|<solr_gdz_external_port>|${SOLR_GDZ_EXTERNAL_PORT}|g"                 .env
    sed -i "s|<gdz_logo_path>|${GDZ_LOGO_PATH}|g"                                   .env
    sed -i "s|<nlh_logo_path>|${NLH_LOGO_PATH}|g"                                   .env
    sed -i "s|<nlh_footer_path>|${NLH_FOOTER_PATH}|g"                                   .env
    sed -i "s|<font_path>|${FONT_PATH}|g"                                   .env
    sed -i "s|<s3_sub_provider>|${S3_SUB_PROVIDER}|g"                            .env
    sed -i "s|<s3_sub_aws_access_key_id>|${S3_SUB_AWS_ACCESS_KEY_ID}|g"          .env
    sed -i "s|<s3_sub_aws_secret_access_key>|${S3_SUB_AWS_SECRET_ACCESS_KEY}|g"  .env
    sed -i "s|<s3_sub_region>|${S3_SUB_REGION}|g"                            .env
    sed -i "s|<s3_sub_endpoint>|${S3_SUB_ENDPOINT}|g"                            .env
    sed -i "s|<s3_nlh_provider>|${S3_NLH_PROVIDER}|g"                            .env
    sed -i "s|<s3_nlh_aws_access_key_id>|${S3_NLH_AWS_ACCESS_KEY_ID}|g"          .env
    sed -i "s|<s3_nlh_aws_secret_access_key>|${S3_NLH_AWS_SECRET_ACCESS_KEY}|g"  .env
    sed -i "s|<s3_nlh_region>|${S3_NLH_REGION}|g"                            .env
    sed -i "s|<s3_nlh_endpoint>|${S3_NLH_ENDPOINT}|g"                            .env
    sed -i "s|<s3_digizeit_provider>|${S3_DIGIZEIT_PROVIDER}|g"                            .env
    sed -i "s|<s3_digizeit_aws_access_key_id>|${S3_DIGIZEIT_AWS_ACCESS_KEY_ID}|g"          .env
    sed -i "s|<s3_digizeit_aws_secret_access_key>|${S3_DIGIZEIT_AWS_SECRET_ACCESS_KEY}|g"  .env
    sed -i "s|<s3_digizeit_region>|${S3_DIGIZEIT_REGION}|g"                            .env
    sed -i "s|<s3_digizeit_endpoint>|${S3_DIGIZEIT_ENDPOINT}|g"                            .env
    sed -i "s|<solr_java_mem>|${SOLR_JAVA_MEM}|"                            .env
    sed -i "s|<local_host>|${LOCAL_HOST}|"                                  .env
    sed -i "s|<service_host>|${SERVICE_HOST}|"                              .env
    sed -i "s|<redis_host>|${REDIS_HOST}|"                                  .env
    sed -i "s|<solr_gdz_host>|${SOLR_GDZ_HOST}|"                                    .env
    sed -i "s|<solr_nlh_host>|${SOLR_NLH_HOST}|"                                    .env
    sed -i "s|<graylog_uri>|${GRAYLOG_URI}|"                              .env
    sed -i "s|<graylog_port>|${GRAYLOG_PORT}|"                              .env
    sed -i "s|<solr_gdz_core>|${solr_gdz_core}|"                                    .env
    sed -i "s|<solr_gdz_core2>|${solr_gdz_core2}|"                                  .env
    sed -i "s|<solr_nlh_core>|${solr_nlh_core}|"                                    .env
    sed -i "s|<service_verticle>|${SERVICE_VERTICLE}|"                      .env
    sed -i "s|<indexer_verticle>|${INDEXER_VERTICLE}|"                      .env
    sed -i "s|<converter_work_verticle>|${CONVERTER_WORK_VERTICLE}|"                  .env
    sed -i "s|<converter_img_log_verticle>|${CONVERTER_IMG_LOG_VERTICLE}|"                  .env
    sed -i "s|<converter_img_full_verticle>|${CONVERTER_IMG_FULL_VERTICLE}|"                  .env
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
#docker-compose build --force-rm  importer_converter=1  importer_work_converter importer_indexer
#docker-compose stop
#docker-compose rm -f
#docker-compose up -d --scale  importer_converter=1  importer_work_converter importer_img_full_converter importer_img_log_converter importer_indexer

# local
#docker-compose build --force-rm
#docker-compose stop
#docker-compose rm -f
#docker-compose up -d





