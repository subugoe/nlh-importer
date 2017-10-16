require 'vertx/vertx'
require 'rubygems'
require 'logger'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
logger.debug "[start_indexer] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


indexer_options = {
    'instances'                  => 5,
    'worker'                     => true,
    'blockedThreadCheckInterval' => 3600000,
    'warningExceptionTime'       => 3600000,
    'maxWorkerExecuteTime'       => 3400000000000,
    'maxEventLoopExecuteTime'    => 600000000000,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}

# indexer
$vertx.deploy_verticle("indexer/indexer_job_builder.rb", indexer_options)

