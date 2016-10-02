source .env

docker-compose stop
docker-compose rm -f
mvn clean package
cp target/nlh-importer-verticle-1.0-SNAPSHOT.jar  docker/lib/
cp src/main/resources/start.rb docker/
#docker-compose build --no-cache
docker-compose build --force-rm
docker-compose up -d