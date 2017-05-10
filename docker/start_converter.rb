require 'vertx/vertx'
require 'rubygems'
require 'logger'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
logger.debug "[start_converter] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"



converter_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'blockedThreadCheckInterval' => 60000,
    'warningExceptionTime'       => 45000,
    'maxWorkerExecuteTime'       => 3600000000000,
    'maxEventLoopExecuteTime'    => 60000000000,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}


# indexing service endpoint
# $vertx.deploy_verticle("services/indexer_service_verticle.rb", indexer_service_options)

