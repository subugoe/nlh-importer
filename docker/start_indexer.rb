require 'vertx/vertx'
require 'rubygems'
require 'logger'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
logger.debug "[start.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"



indexer_options = {
    'instances'      => 10,
    'worker'         => true,
    'workerPoolName' => 'indexer_worker_pool',
    'GEM_PATH'       => '/opt/jruby/lib/ruby/gems/shared/gems'
}


# indexer
$vertx.deploy_verticle("indexer/mets_indexer.rb", indexer_options)

