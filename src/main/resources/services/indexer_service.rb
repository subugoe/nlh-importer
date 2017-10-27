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


  def send_status(status_code, response, msg_hsh)
    response.set_status_code(status_code).end(msg_hsh.to_json)
  end



  def process_response(hsh, response)

    begin

      if hsh == nil
        @logger.error("[indexer_service] Expected JSON body missing")
        @file_logger.error("[indexer_service]  Expected JSON body missing")
        send_status(400, response, {"status" => "-1", "msg" => "Expected JSON body missing"})
        return
      else
        pushToQueue(@queue, [hsh.to_json])
      end

      @logger.info "[indexer_service] Indexing started"
      send_status(200, response, {"status" => "0", "msg" => "Indexing started"})
      return

    rescue Exception => e
      @logger.error("[indexer_service] Problem with request body \t#{e.message}\n\t#{e.backtrace}")
      @file_logger.error("[indexer_service] Problem with request body \t#{e.message}")

      # any error
      puts "could not processed"
      send_status(400, response, {"status" => "-1", "msg" => "Couldnot process request"})
      return
    end

  end
end

