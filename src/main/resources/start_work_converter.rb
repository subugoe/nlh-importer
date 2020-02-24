require 'vertx/vertx'

require 'rubygems'
require 'logger'
require 'gelf'
require "converter/work_converter_job_builder"

#@logger       = Logger.new(STDOUT)
#@logger.level = ENV['DEBUG_MODE'].to_i

@logger       = GELF::Logger.new(ENV['GRAYLOG_URI'], ENV['GRAYLOG_PORT'].to_i, "WAN", {:facility => ENV['GRAYLOG_FACILITY']})
@logger.level = ENV['DEBUG_MODE'].to_i

@logger.info "[start_converter] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


work_job_builder_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'blockedThreadCheckInterval' => 3600000,
    'warningExceptionTime'       => 3600000,
    'maxWorkerExecuteTime'       => 3400000000000,
    'maxEventLoopExecuteTime'    => 600000000000,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}


# converter service endpoint
$vertx.deploy_verticle("converter/work_converter_job_builder.rb", work_job_builder_options)


