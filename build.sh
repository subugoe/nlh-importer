source env.sh

docker-compose stop
docker-compose rm -f
mvn clean package
cp target/gdz-importer-verticle-1.0-SNAPSHOT.jar  docker/lib/
#docker-compose build --no-cache
docker-compose build
docker-compose up -d