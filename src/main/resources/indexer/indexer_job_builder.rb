require 'vertx/vertx'

require 'logger'
require 'gelf'
require 'redis'
require 'json'

require 'indexer/indexer'


# prepare config (gdz): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (gdz): 20 instances, 8GB importer, 3GB redis, 5GB solr

# prepare config (nlh): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (nlh): 8 instances, 8GB importer, 3GB redis, 5GB solr


@logger       = GELF::Logger.new(ENV['GRAYLOG_URI'], ENV['GRAYLOG_PORT'].to_i, "WAN", {:facility => ENV['GRAYLOG_FACILITY']})
@logger.level = ENV['DEBUG_MODE'].to_i


@queue  = ENV['REDIS_INDEX_QUEUE']
@rredis = Redis.new(
    :host               => ENV['REDIS_HOST'],
    :port               => ENV['REDIS_EXTERNAL_PORT'].to_i,
    :db                 => ENV['REDIS_DB'].to_i,
    :reconnect_attempts => 3
)


@logger.debug "[indexer_job_builder] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


$vertx.execute_blocking(lambda {|future|

  @logger.debug "[indexer_job_builder] GC.start #{GC.start} -> max: #{GC.stat[:max]}"

  attempts = 0
  begin

    while true do
      res = @rredis.brpop(@queue)

      indexer = Indexer.new(res)
      indexer.process_response()

    end

  rescue Exception => e
    sleep(1)
    if attempts < 3
      attempts += 1
      retry
    else
      attempts = 0
      @logger.error("[indexer_job_builder.rb] Error #{e.message}\nrequest data: #{res}")
      next
    end
  end
  # future.complete(@doc.to_s)

}) {|res_err, res|
  #
}

