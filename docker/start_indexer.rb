require 'vertx/vertx'
require 'rubygems'
require 'logger'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
logger.debug "[start_indexer] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


indexer_options = {
    'instances'                  => 10,
    'worker'                     => true,
    'blockedThreadCheckInterval' => 60000,
    'warningExceptionTime'       => 45000,
    'maxWorkerExecuteTime'       => 3600000000000,
    'maxEventLoopExecuteTime'    => 60000000000,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}


# indexer
$vertx.deploy_verticle("indexer/mets_indexer.rb", indexer_options)

