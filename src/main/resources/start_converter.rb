require 'vertx/vertx'
require 'rubygems'
require 'logger'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
logger.debug "[start_converter] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


converter_options = {
    'instances'                  => 10,
    'worker'                     => true,
    'blockedThreadCheckInterval' => 60000,
    'warningExceptionTime'       => 45000,
    'maxWorkerExecuteTime'       => 3600000000000,
    'maxEventLoopExecuteTime'    => 60000000000,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}


# converter service endpoint
$vertx.deploy_verticle("converter/image_to_pdf_converter.rb", converter_options)
