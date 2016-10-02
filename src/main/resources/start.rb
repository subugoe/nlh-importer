require 'vertx/vertx'
require 'vertx-redis/redis_client'

require 'rubygems'

require 'logger'
require 'redis'

logger       = Logger.new(STDOUT) # 'gdz_object.log')
logger.level = Logger::DEBUG


logger.debug "[start.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i)

retriever_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'workerPoolName'             => 'retrieve_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

indexer_options = {
    'instances'                  => 1,
    'worker'                     => false,
    #'workerPoolName'             => 'index_worker_pool',
    #'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

fulltext_processor_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'fulltext_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

image_processor_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'image_worker_pool',
    'workerPoolSize'             => 2,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

converter_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'workerPoolName'             => 'converter_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

copier_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'copier_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}


checker_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'checker_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}


@rredis.del 'fixitieschecked'
@rredis.del 'fulltextscopied'
@rredis.del 'fulltextsindexed'
@rredis.del 'imagescopied'
@rredis.del 'metscopied'
@rredis.del 'indexed'
@rredis.del 'retrieved'


a = $vertx.deploy_verticle("processors/path_retrieve.rb", retriever_options)
b = $vertx.deploy_verticle("processors/mets_indexer.rb", indexer_options)
c = $vertx.deploy_verticle("processors/fulltext_processor.rb", fulltext_processor_options)
d = $vertx.deploy_verticle("processors/image_processor.rb", image_processor_options)
e = $vertx.deploy_verticle("processors/mets_copier.rb", copier_options)
f = $vertx.deploy_verticle("processors/fixity_checker.rb", checker_options)


#a = $vertx.deploy_verticle("de.unigoettingen.sub.converter.ConvertVerticle", converter_options)


#c = $vertx.deploy_verticle("node_builder/build_node.rb", node_builder_options)


=begin
$vertx.deploy_verticle("indexer/mets_indexer.rb", options2) { |res_err, res|

  if (res_err == nil)
     $vertx.deploy_verticle("id_retrieval/path_retrieve.rb", options1)
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




