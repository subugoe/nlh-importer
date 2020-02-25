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

##### Preparation: Set environment variables 

Copy the file .cfg_orig and modify the values.

##### (Re-)Build and start the docker images (also after changes)

Change the docker-compose commands at the bottom of the file.

```
./build.sh
```
 
In web image will be constructed in the build process, this will take a few minutes.


##### See log output

```
docker-compose logs -f <service>
```

Use the service names from the docker-compose-yml.

##### Index a single document

```
POST 134.76.18.25:8083     /api/indexer/jobs
{ 
    "document": "PPN591416441",
    "context": "gdz",
    "product": "gdz",
    "reindex": false
}
```

##### Re-Index all document 

```
POST 134.76.18.25:8083     /api/reindexer/jobs
{
	"context": "gdz",
    "product": "gdz"
}
```

##### Convert a document

```
POST 134.76.18.25:8083     /api/converter/jobs
{
    "document": "PPN591416441",
    "log": "PPN591416441",
    "context": "gdz",
    "product": "gdz"
}
```

##### Convert a structural document part 

```
{
    "document": "PPN591416441",
    "log": "LOG_0007",
    "context": "gdz",
    "product": "gdz"
}
```


##### Connect to solr admin view (for local deployment)
 
* [solr-admin](http://0.0.0.0:8443/)


