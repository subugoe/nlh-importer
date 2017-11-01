require 'vertx/vertx'

require 'logger'
require 'benchmark'
require 'json'
require 'redis'
require 'rsolr'

require 'converter/img_to_pdf_converter'

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/img_converter_job_builder_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@queue  = ENV['REDIS_IMG_CONVERT_QUEUE']
@rredis = Redis.new(
    :host => ENV['REDIS_HOST'],
    :port => ENV['REDIS_EXTERNAL_PORT'].to_i,
    :db   => ENV['REDIS_DB'].to_i
)


$vertx.execute_blocking(lambda {|future|

  GC.start
  @logger.debug "[img_converter_job_builder] Start verticle (#{Java::JavaLang::Thread.current_thread().get_name()},  max: #{GC.stat[:max]})"

  begin

    while true do

      res = @rredis.brpop(@queue) #, :timeout => nil)

      msg  = res[1]
      json = JSON.parse msg

      converter = ImgToPdfConverter.new
      converter.process_response(json)

    end

  rescue Exception => e
    @logger.error "[img_converter_job_builder] Redis problem \t#{e.message}"
    @file_logger.error "[img_converter_job_builder] Redis problem '#{res}' \t#{e.message}\n\t#{e.backtrace}"

    retry
  end

  # future.complete(@doc.to_s)

}) {|res_err, res|
  #
}

=begin
$vertx.event_bus().consumer("image.load") {|message|

  @logger.debug "[img_converter_job_builder] GC.start #{GC.start} -> max: #{GC.stat[:max]}"

  begin
    body = message.body()

    if (body != '' && body != nil)

      json = JSON.parse body

      Benchmark.bm(7) do |x|
        x.report("Begin benchmark") {
          converter = ImgToPdfConverter.new
          converter.process_response(json)
        }
      end
    else
      raise "Could not process empty string or nil"
    end
  rescue Exception => e
    @logger.error "[img_converter_job_builder] Processing problem with '#{json}' \t#{e.message}\n\t#{e.backtrace}"
    @file_logger.error "[img_converter_job_builder] Processing problem with '#{json}' \t#{e.message}\n\t#{e.backtrace}"
  end
}
=end
