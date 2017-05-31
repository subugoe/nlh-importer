require 'vertx/vertx'
require 'rubygems'
require 'logger'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
logger.debug "[start_services] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

vertx_options = {
    'maxEventLoopExecuteTime' => 600000000000
}

converter_service_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'blockedThreadCheckInterval' => 3600000,
    'warningExceptionTime'       => 3500000,
    'maxWorkerExecuteTime'       => 3400000000000,
    'maxEventLoopExecuteTime'    => 590000000000,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}


indexer_service_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'blockedThreadCheckInterval' => 3300000,
    'warningExceptionTime'       => 3200000,
    'maxWorkerExecuteTime'       => 3100000000000,
    'maxEventLoopExecuteTime'    => 580000000000,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}

reindex_service_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'blockedThreadCheckInterval' => 3000000,
    'warningExceptionTime'       => 2900000,
    'maxWorkerExecuteTime'       => 2800000000000,
    'maxEventLoopExecuteTime'    => 570000000000,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}


#vertx = Vertx::Vertx.vertx(vertx_options)

# indexing service endpoint
$vertx.deploy_verticle("services/indexer_service_verticle.rb", indexer_service_options)

# reindex service endpoint
$vertx.deploy_verticle("services/reindex_service_verticle.rb", reindex_service_options)

# converter service endpoint
#$vertx.deploy_verticle("services/converter_service_verticle.rb", converter_service_options)


