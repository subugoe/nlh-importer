require 'vertx-web/router'
require 'vertx-web/body_handler'

require 'json'
require 'redis'
require 'logger'
require 'oai'
require 'open-uri'


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/indexer_service_verticle_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@queue  = ENV['REDIS_INDEX_QUEUE']
@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)


# ---

@logger.debug "[indexer_service] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def pushToQueue(queue, arr)
  @rredis.lpush(queue, arr)
end


def send_error(status_code, response)
  response.set_status_code(status_code).end
end

# --- routes ---

router = VertxWeb::Router.router($vertx)
router.route().handler(&VertxWeb::BodyHandler.create().method(:handle))


# POST http://141.5.103.92:8083   /api/indexer/jobs
# { "ppn": "PPN248412353", "context": "gdz" }
# or
# {"path": "/inpath/ZDB-1-AHN/METS_Daten/mets_ahn_11B3080EDF6EAD38.xml" , "context": "nlh"}
router.post("/api/indexer/jobs").blocking_handler(lambda { |routingContext|

  begin
    hsh = routingContext.get_body_as_json

    if hsh == nil
      @logger.error("[indexer_service] Expected JSON body missing")
      @file_logger.error("[indexer_service]  Expected JSON body missing")
      send_error(400, response)
    else
      @logger.info("[indexer_service] Got message: \t#{hsh}")
      pushToQueue(@queue, [hsh.to_json])
    end


  rescue Exception => e
    @logger.error("[indexer_service] Problem with request body \t#{e.message}\n\t#{e.backtrace}")
    @file_logger.error("[indexer_service] Problem with request body \t#{e.message}")
  end

  routingContext.response.end

}, false)


$vertx.create_http_server.request_handler(&router.method(:accept)).listen 8083