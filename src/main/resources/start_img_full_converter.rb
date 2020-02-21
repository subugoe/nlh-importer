require 'vertx/vertx'

require 'rubygems'
require 'logger'
require 'gelf'
require "converter/img_to_pdf_converter_job_builder"

@logger       = Logger.new(STDOUT)
@logger.level = ENV['DEBUG_MODE'].to_i
@logger.info "[start_converter] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


img_job_builder_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'blockedThreadCheckInterval' => 3600000,
    'warningExceptionTime'       => 3600000,
    'maxWorkerExecuteTime'       => 3400000000000,
    'maxEventLoopExecuteTime'    => 600000000000,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}


# converter loader eb
$vertx.deploy_verticle("converter/img_to_pdf_converter_job_builder.rb", img_job_builder_options)

