require 'vertx/vertx'
require 'vertx-redis/redis_client'

require 'logger'
#require 'redis'

logger       = Logger.new(STDOUT) # 'gdz_object.log')
logger.level = Logger::DEBUG


logger.debug "[start.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

retriever_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'workerPoolName'             => 'retrieve_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000
}

node_builder_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'build_node_worker_pool',
    'workerPoolSize'             => 4,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000
}

indexer_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'index_worker_pool',
    'workerPoolSize'             => 4,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000
}

importer_options = {
    'instances'                  => 2,
    'worker'                     => true,
    'workerPoolName'             => 'import_worker_pool',
    'workerPoolSize'             => 2,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000
}


#d = $vertx.deploy_verticle("retriever/retrieve.rb", retriever_options)

#c = $vertx.deploy_verticle("node_builder/build_node.rb", node_builder_options)

b = $vertx.deploy_verticle("indexer/index.rb", indexer_options)

#a = $vertx.deploy_verticle("importer/import.rb", importer_options)

=begin
$vertx.deploy_verticle("indexer/index.rb", options2) { |res_err, res|

  if (res_err == nil)
     $vertx.deploy_verticle("id_retrieval/retrieve.rb", options1)
    #logger.debug "Deployment succeed! #{res}"
  else
    logger.debug "Deployment failed! #{res_err}"
  end

}
=end


=begin
  redis.del 'ppn'
  redis.del 'ppn_processed'
  redis.del 'couldNotOpen'

  redis.del 'noResultSetFor'
=end



=begin

$vertx.execute_blocking(lambda { |future|


  sleep 600

  catch (:stop) do

    while true
      size = redis.llen("object_to_import")
      throw :stop if size == 0
      sleep 15
    end

  end


  vertx.undeploy(d)
  vertx.undeploy(c)
  vertx.undeploy(b)
  vertx.undeploy(a)

  logger.debug "[start.rb] finished processing."


  #future.complete(doc.to_s)

}) { |res_err, res|
  #
}
=end




