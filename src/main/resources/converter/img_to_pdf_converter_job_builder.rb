require 'vertx/vertx'

require 'logger'
require 'gelf'
require 'json'
require 'redis'
require 'rsolr'

require 'converter/img_to_pdf_converter'

@logger       = GELF::Logger.new(ENV['GRAYLOG_URI'], ENV['GRAYLOG_PORT'].to_i, "WAN", {:facility => ENV['GRAYLOG_FACILITY']})
@logger.level = ENV['DEBUG_MODE'].to_i

if ENV['CONVERTER_TYPE'] == "full"
  @img_convert_queue = ENV['REDIS_IMG_CONVERT_FULL_QUEUE']
elsif ENV['CONVERTER_TYPE'] == "log"
  @img_convert_queue = ENV['REDIS_IMG_CONVERT_LOG_QUEUE']
end


@rredis = Redis.new(
    :host               => ENV['REDIS_HOST'],
    :port               => ENV['REDIS_EXTERNAL_PORT'].to_i,
    :db                 => ENV['REDIS_DB'].to_i,
    :reconnect_attempts => 3
)

$vertx.execute_blocking(lambda {|future|

  GC.start
  @logger.debug "[img_converter_job_builder] Start verticle (#{Java::JavaLang::Thread.current_thread().get_name()},  max: #{GC.stat[:max]})"

  begin

    while true do
      res       = @rredis.brpop(@img_convert_queue) #, :timeout => 5)
      msg       = res[1]
      json      = JSON.parse msg
      converter = ImgToPdfConverter.new
      converter.process_response(json)
    end

  rescue Exception => e
    #@logger.error "[img_converter_job_builder] Redis problem \t#{e.message}\n\t#{e.bachtrace}"
    sleep(5)
    retry
  end

  # future.complete(@doc.to_s)

}) {|res_err, res|
  #
}
