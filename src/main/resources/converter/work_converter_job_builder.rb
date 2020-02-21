require 'vertx/vertx'

require 'logger'
require 'gelf'
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


@logger       = GELF::Logger.new(ENV['GRAYLOG_URI'], ENV['GRAYLOG_PORT'].to_i, "WAN", {:facility => ENV['GRAYLOG_FACILITY']})
@logger.level = ENV['DEBUG_MODE'].to_i

@queue        = ENV['REDIS_WORK_CONVERT_QUEUE']
@unique_queue = ENV['REDIS_UNIQUE_QUEUE']

@rredis = Redis.new(
    :host            => ENV['REDIS_HOST'],
    :port            => ENV['REDIS_EXTERNAL_PORT'].to_i,
    :db              => ENV['REDIS_DB'].to_i
)

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
    sleep(5)
    retry
  end
  # future.complete(@doc.to_s)

}) {|res_err, res|
  #
}

