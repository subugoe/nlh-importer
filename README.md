# Importer
## Introduction

The application is [docker](https://www.docker.com) based. We construct the solr image (v.6.4.1) and the importer image within the build process. The importer reuse the [Vert.x framework](http://vertx.io) to build non-blocking processing components (verticles in Vert.x terminology).


## Build and Run
To build and run the application you need to install [docker-engine](https://docs.docker.com/engine/installation/) and [docker-compose](https://github.com/docker/compose). For installation instructions see the web pages 

##### Preparation: Clone the GitHub Project:


```
git clone https://github.com/subugoe/nlh-importer.git
cd ample
```

The nlh-importer directory is the project root, and the base directory for docker commands. 

##### Preparation: set the IP-Address environment variable for solr (edit .env)

* Replace the used IP Address with your solr address

##### Preparation: Start solr container (only once, or after schema changes) 

```
docker-compose up -d solr

```


##### (Re-)Build and start the importer docker image (after changes)

```
./build.sh
```
 
In web image will be constructed in the build process, this will take a few minutes.


##### See log output

```
docker-compose logs -f <service>
```

Switch <service> to 'importer' or 'solr'. Most interesting is 'importer'. If you leave the service-info, the merged log of all services is shown. 


##### Index a document via REST

```
127.0.0.1:8080/api/conversion/jobs
{
	"ppn": "PPN591416441",
	"context": "gdz"
}
```

##### Connect to solr admin view (for local deployment)
 
* [solr-admin](http://0.0.0.0:8443/solr/nlh)


