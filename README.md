# Importer
## Introduction

The application is [docker](https://www.docker.com) based. We construct the solr image (v.6.4.1) and the importer image within the build process. The importer reuse the [Vert.x framework](http://vertx.io) to build non-blocking processing components (verticles in Vert.x terminology).


## Build and Run
To build and run the application you need to install [docker-engine](https://docs.docker.com/engine/installation/) and [docker-compose](https://github.com/docker/compose). For installation instructions see the web pages 

##### Preparation: Clone the GitHub Project:


```
git clone https://github.com/subugoe/nlh-importer.git
cd nlh-importer
```

The nlh-importer directory is the project root, and the base directory for docker commands. 

##### Preparation: For GDZ Reindex set the user/password to access the GDZ Solr 

```
export solr_user=changeme
export solr_password=changeme
```

##### Preparation: Change the config file rootdir/.env.dist

TODO

##### (Re-)Build and start the docker images (also after changes)

```
./build.sh
```
 
In web image will be constructed in the build process, this will take a few minutes.


##### See log output

```
export myUID=`id -u ${whoami}`
export myGID=`id -g ${whoami}`
docker-compose logs -f <service>
```

Switch <service> to 'importer' or 'solr'. Most interesting is 'importer'. If you leave the service-info, the merged log of all services is shown. 


##### Index a single document

```
POST 127.0.0.1:8080     /api/indexer/jobs
{ 
    "ppn ": "PPN591416441_1 ", 
    "context": "gdz" 
}
```

##### Re-Index all document 

```
POST 127.0.0.1:8080     /api/reindexer/jobs
{
	"context": "gdz"
}
```

##### Get the number of Documents to Re-Index 

```
GET 127.0.0.1:8080     /api/reindexer/status
```

##### Convert a document

```
POST 127.0.0.1:8080     /api/converter/works
{
	"ppn": "PPN591416441",
	"context": "gdz"
}
```


##### Connect to solr admin view (for local deployment)
 
* [solr-admin](http://0.0.0.0:8443/)


