require 'vertx/vertx'
#require 'vertx-redis/redis_client'

require 'benchmark'

require 'logger'
require 'redis'

require 'json'
require 'indexer/indexer'



# prepare config (gdz): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (gdz): 20 instances, 8GB importer, 3GB redis, 5GB solr

# prepare config (nlh): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (nlh): 8 instances, 8GB importer, 3GB redis, 5GB solr

  MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i
  @logger       = Logger.new(STDOUT)
  @logger.level = Logger::DEBUG

  @file_logger       = Logger.new(ENV['LOG'] + "/mets_indexer_#{Time.new.strftime('%y-%m-%d')}.log")
  @file_logger.level = Logger::DEBUG

  @logger.debug "[mets_indexer] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

  @queue  = ENV['REDIS_INDEX_QUEUE']
  @rredis = Redis.new(
      :host => ENV['REDIS_HOST'],
      :port => ENV['REDIS_EXTERNAL_PORT'].to_i,
      :db => ENV['REDIS_DB'].to_i #,
      #:timeout => 10
  )




$vertx.execute_blocking(lambda {|future|

  @from_s3 = false
  @logger.debug "[mets_indexer] GC.start #{GC.start} -> max: #{GC.stat[:max]}"

  begin

    while true do

      res = @rredis.brpop(@queue, :timeout => nil)

      Benchmark.bm(7) do |x|
        x.report("Begin benchmark") {

          indexer = Indexer.new
          indexer.process_response(res)
          #process_response(res)
          #GC.start

        }
      end
    end

  rescue Exception => e
    @logger.error "[mets_indexer] Processing problem with '#{res[1]}' \t#{e.message}\n\t#{e.backtrace}"
    @file_logger.error "[mets_indexer] Processing problem with '#{res[1]}'  \t#{e.message}\n\t#{e.backtrace}"

    retry
  end
  # future.complete(@doc.to_s)

}) {|res_err, res|
  #
}

