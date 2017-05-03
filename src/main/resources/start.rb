require 'vertx/vertx'
require 'rubygems'
require 'logger'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
logger.debug "[start.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


converter_service_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}

indexer_service_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}

reindex_service_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}

indexer_options = {
    'instances'                  => 30,
    'worker'                     => true,
    'workerPoolName'             => 'indexer_worker_pool',
    'workerPoolSize'             => 35,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}


# indexing service endpoint
$vertx.deploy_verticle("services/indexer_service_verticle.rb", indexer_service_options)

# reindex service endpoint
$vertx.deploy_verticle("services/reindex_service_verticle.rb", reindex_service_options)

# converter service endpoint
$vertx.deploy_verticle("services/converter_service_verticle.rb", converter_service_options)

# indexer
$vertx.deploy_verticle("indexer/mets_indexer.rb", indexer_options)

