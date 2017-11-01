require 'vertx/vertx'
require 'rubygems'
require 'logger'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
logger.debug "[start_converter] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"



job_builder_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'blockedThreadCheckInterval' => 3600000,
    'warningExceptionTime'       => 3600000,
    'maxWorkerExecuteTime'       => 3400000000000,
    'maxEventLoopExecuteTime'    => 600000000000,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}


converter_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'blockedThreadCheckInterval' => 3600000,
    'warningExceptionTime'       => 3600000,
    'maxWorkerExecuteTime'       => 3400000000000,
    'maxEventLoopExecuteTime'    => 600000000000,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}


# converter service endpoint
$vertx.deploy_verticle("converter/work_converter_job_builder.rb", job_builder_options)

# converter loader eb
$vertx.deploy_verticle("converter/img_to_pdf_converter_job_builder.rb", converter_options)

