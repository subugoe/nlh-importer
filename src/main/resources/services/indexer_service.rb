require 'vertx/vertx'
require 'vertx-web/router'
require 'vertx-web/body_handler'


require 'logger'
require 'gelf'
require 'json'
require 'redis'
require 'oai'
require 'open-uri'

class IndexerService

  def initialize

    @logger       = Logger.new(STDOUT)
    @logger.level = ENV['DEBUG_MODE'].to_i

    @queue  = ENV['REDIS_INDEX_QUEUE']
    @rredis = Redis.new(
        :host               => ENV['REDIS_HOST'],
        :port               => ENV['REDIS_EXTERNAL_PORT'].to_i,
        :db                 => ENV['REDIS_DB'].to_i,
        :reconnect_attempts => 3
    )

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
        send_status(400, response, {"status" => "-1", "msg" => "Expected JSON body missing"})
        return
      else
        pushToQueue(@queue, [hsh.to_json])
      end

      id = hsh['document']

      @logger.debug "[indexer_service] Indexing for #{id} has started"
      send_status(200, response, {"status" => "0", "msg" => "Indexing started"})
      return

    rescue Exception => e
      @logger.error("[indexer_service] Problem with request body \t#{e.message} \n#{e.backtrace}")
      send_status(400, response, {"status" => "-1", "msg" => "Couldnot process request", "error" => e.message})
      return
    end

  end
end

