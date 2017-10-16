require 'vertx/vertx'

require 'logger'
require 'nokogiri'
require 'redis'
require 'rsolr'
require 'json'
require 'fileutils'
require 'mini_magick'
require 'open-uri'

require 'converter/work_converter'

# prepare config (gdz): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (gdz): 20 instances, 8GB importer, 3GB redis, 5GB solr

# prepare config (nlh): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (nlh): 8 instances, 8GB importer, 3GB redis, 5GB solr


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/converter_job_builder_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@logger.debug "[converter_job_builder] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@queue  = ENV['REDIS_WORK_CONVERT_QUEUE']
@unique_queue  = ENV['REDIS_UNIQUE_QUEUE']

@rredis = Redis.new(
    :host => ENV['REDIS_HOST'],
    :port => ENV['REDIS_EXTERNAL_PORT'].to_i,
    :db   => ENV['REDIS_DB'].to_i
)


=begin
$vertx.event_bus().consumer("image.load") {|message|

  @logger.debug "[img_to_pdf_converter_job_builder] GC.start #{GC.start} -> max: #{GC.stat[:max]}"

  begin
    body = message.body()

    if (body != '' && body != nil)

      json = JSON.parse body

      Benchmark.bm(7) do |x|
        x.report("Begin benchmark") {
          converter = WorkConverter.new
          converter.process_response(res)
        }
      end
    else
      raise "Could not process empty string or nil"
    end
  rescue Exception => e
    @logger.error "[img_to_pdf_converter_job_builder] Processing problem with '#{json}' \t#{e.message}\n\t#{e.backtrace}"
    @file_logger.error "[img_to_pdf_converter_job_builder] Processing problem with '#{json}' \t#{e.message}\n\t#{e.backtrace}"
  end
}
=end


def pushToQueue(queue, field, value)
  @rredis.hset(queue, field, value)
end



def removeQueue(queue)
  keys = @rredis.hkeys(queue)
  unless keys.empty?
    @rredis.hdel(queue, keys)
  end
end

$vertx.execute_blocking(lambda {|future|

  @logger.debug "[converter_job_builder] GC.start #{GC.start} -> max: #{GC.stat[:max]}"

  begin

    while true do

      # {"id":"PPN826737668___LOG_0000","context":"gdz"}
      res = @rredis.brpop(@queue) # , :timeout => nil)

      msg  = res[1]
      json = JSON.parse msg
      id      = json['id']

      exist = @rredis.hget(@unique_queue, id)
      unless exist == nil
        @logger.debug "[converter_job_builder] Job for #{id} already started, process next"
        next
      end
      @rredis.hset(@unique_queue, id, -1)

      converter = WorkConverter.new
      converter.process_response(res)

    end

  rescue Exception => e
    @logger.error "[converter_job_builder] Redis problem \t#{e.message}"
    @file_logger.error "[converter_job_builder] Processing problem with '#{res}' \t#{e.message}\n\t#{e.backtrace}"

    retry
  end
  # future.complete(@doc.to_s)

}) {|res_err, res|
  #
}

