require 'vertx/vertx'
require 'rubygems'
require 'logger'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
logger.debug "[start.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"



indexer_options = {
    'instances'      => 30,
    'worker'         => true,
    'workerPoolName' => 'indexer_worker_pool',
    'workerPoolSize' => 35,
    'GEM_PATH'       => '/opt/jruby/lib/ruby/gems/shared/gems'
}


# indexer
$vertx.deploy_verticle("indexer/mets_indexer.rb", indexer_options)

