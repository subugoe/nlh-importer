require 'vertx/vertx'

require 'benchmark'
require 'logger'
require 'redis'
require 'json'

require 'indexer/indexer'

# prepare config (gdz): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (gdz): 20 instances, 8GB importer, 3GB redis, 5GB solr

# prepare config (nlh): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (nlh): 8 instances, 8GB importer, 3GB redis, 5GB solr


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/indexer_job_builder_#{Time.new.strftime('%y-%m-%d')}.log", 3, 20 * 1024000)
@file_logger.level = Logger::DEBUG

@queue  = ENV['REDIS_INDEX_QUEUE']
@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db   => ENV['REDIS_DB'].to_i)


@logger.debug "[indexer_job_builder] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


$vertx.execute_blocking(lambda {|future|

  @logger.debug "[indexer_job_builder] GC.start #{GC.start} -> max: #{GC.stat[:max]}"

  begin

    while true do
      res     = @rredis.brpop(@queue) #, :timeout => nil)
      indexer = Indexer.new
      indexer.process_response(res)
    end

  rescue Exception => e
    @logger.error "[indexer_job_builder] Redis problem \t#{e.message}"
    @file_logger.error "[indexer_job_builder] Redis problem '#{res}' \t#{e.message}"

    retry
  end
  # future.complete(@doc.to_s)

}) {|res_err, res|
  #
}

