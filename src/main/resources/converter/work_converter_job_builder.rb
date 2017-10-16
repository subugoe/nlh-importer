require 'vertx/vertx'

require 'logger'
require 'nokogiri'
require 'redis'
require 'rsolr'
require 'json'
require 'fileutils'
require 'mini_magick'
require 'open-uri'

require 'converter/converter'

# prepare config (gdz): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (gdz): 20 instances, 8GB importer, 3GB redis, 5GB solr

# prepare config (nlh): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (nlh): 8 instances, 8GB importer, 3GB redis, 5GB solr


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/converter_job_builder_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@logger.debug "[converter_job_builder] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@queue  = ENV['REDIS_CONVERT_QUEUE']
@rredis = Redis.new(
    :host => ENV['REDIS_HOST'],
    :port => ENV['REDIS_EXTERNAL_PORT'].to_i,
    :db   => ENV['REDIS_DB'].to_i
)


$vertx.execute_blocking(lambda {|future|

  @logger.debug "[converter_job_builder] GC.start #{GC.start} -> max: #{GC.stat[:max]}"

  begin

    while true do

      res = @rredis.brpop(@queue, :timeout => nil)

      Benchmark.bm(7) do |x|
        x.report("Begin benchmark") {
          converter = Converter.new
          converter.process_response(res)
        }
      end
    end

  rescue Exception => e
    @logger.error "[converter_job_builder] Processing problem with '#{res[1]}' \t#{e.message}\n\t#{e.backtrace}"
    @file_logger.error "[converter_job_builder] Processing problem with '#{res[1]}'  \t#{e.message}\n\t#{e.backtrace}"

    retry
  end
  # future.complete(@doc.to_s)

}) {|res_err, res|
  #
}

