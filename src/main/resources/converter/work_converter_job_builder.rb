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

@file_logger       = Logger.new(ENV['LOG'] + "/work_converter_job_builder_#{Time.new.strftime('%y-%m-%d')}.log", 3, 20 * 1024000)
@file_logger.level = Logger::DEBUG

@queue        = ENV['REDIS_WORK_CONVERT_QUEUE']
@unique_queue = ENV['REDIS_UNIQUE_QUEUE']

@rredis = Redis.new(
    :host => ENV['REDIS_HOST'],
    :port => ENV['REDIS_EXTERNAL_PORT'].to_i,
    :db   => ENV['REDIS_DB'].to_i
)

def pushToQueue(queue, field, value)
  @rredis.hset(queue, field, value)
end


$vertx.execute_blocking(lambda {|future|

  GC.start
  @logger.debug "[work_converter_job_builder] Start verticle (#{Java::JavaLang::Thread.current_thread().get_name()},  max: #{GC.stat[:max]})"

  begin

    while true do

      res = @rredis.brpop(@queue) # , :timeout => nil)

      converter = WorkConverter.new
      converter.process_response(res)

    end

  rescue Exception => e
    @logger.error "[work_converter_job_builder] Redis problem \t#{e.message}"
    @file_logger.error "[work_converter_job_builder] Processing problem with '#{res}' \t#{e.message}\n\t#{e.backtrace}"

    retry
  end
  # future.complete(@doc.to_s)

}) {|res_err, res|
  #
}

