require 'vertx/vertx'
require 'vertx-web/router'
require 'vertx-web/body_handler'


require 'json'
require 'redis'
require 'logger'
require 'oai'
require 'open-uri'

class IndexerService

  def initialize

    @logger       = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG

    @file_logger       = Logger.new(ENV['LOG'] + "/indexer_service_verticle_#{Time.new.strftime('%y-%m-%d')}.log")
    @file_logger.level = Logger::DEBUG

    @queue  = ENV['REDIS_INDEX_QUEUE']
    @rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)

    @logger.debug "[indexer_service] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

  end

  def pushToQueue(queue, arr)
    @rredis.lpush(queue, arr)
  end


  def send_error(status_code, response)
    response.set_status_code(status_code).end
  end


  def process_response(hsh, response)

    begin

      if hsh == nil
        @logger.error("[indexer_service] Expected JSON body missing")
        @file_logger.error("[indexer_service]  Expected JSON body missing")
        send_error(400, response)
        return
      else
        @logger.info("[indexer_service] Got message: \t#{hsh}")
        pushToQueue(@queue, [hsh.to_json])
      end

      @logger.error "[indexer_service] Indexing started"
      send_error(200, response)
      return

    rescue Exception => e
      @logger.error("[indexer_service] Problem with request body \t#{e.message}\n\t#{e.backtrace}")
      @file_logger.error("[indexer_service] Problem with request body \t#{e.message}")

      # any error
      puts "could not processed"
      send_status(400, response, {"status" => "-1", "msg" => "Request could not processed"})
      return
    end

  end
end

