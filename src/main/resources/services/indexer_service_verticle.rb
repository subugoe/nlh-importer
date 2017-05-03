require 'vertx-web/router'
require 'vertx-web/body_handler'

require 'json'
require 'redis'
require 'logger'
require 'oai'
require 'open-uri'


MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i
oai_endpoint = ENV['GDZ_OAI_ENDPOINT']
productin    = ENV['IN'] + '/' + ENV['PRODUCT']
@inpath       = productin + ENV['METS_IN_SUB_PATH']
@queue       = ENV['REDIS_INDEX_QUEUE']


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/indexer_service_verticle_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)
@oai_client   = OAI::Client.new oai_endpoint

# ---

@logger.debug "[indexer_service_verticle.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def pushToQueue(queue, arr)
  @rredis.lpush(queue, arr)
end



def send_error(status_code, response)
  response.set_status_code(status_code).end
end

def parseId(id)

  id = id.to_s

  begin
    i = id.rindex(':')
    j = id.rindex('|')
    j ||= id.size
    s = id[(i+1)..(j-1)]
    return s
  rescue Exception => e
    @logger.debug("Exception while parse id string: #{id} #{e.message}")
  end

end



# --- routes ---


router = VertxWeb::Router.router($vertx)
router.route().handler(&VertxWeb::BodyHandler.create().method(:handle))

# POST http://127.0.0.1:8080   /api/indexer/jobs
# {"ppn": "PPN248412353" , "context": "gdz"}
router.post("/api/indexer/jobs").blocking_handler(lambda { |routingContext|

  arr = Array.new

  begin
    hsh = routingContext.get_body_as_json

    if hsh == nil
      @logger.error("Expected JSON body missing \t#{e.message}\n\t#{e.backtrace}")
      send_error(400, response)
    else
      arr << hsh.to_json
    end

    pushToQueue(@queue, arr)

  rescue Exception => e
    @logger.error("Problem with request body \t#{e.message}\n\t#{e.backtrace}")
    @file_logger.error("Problem with request body \t#{e.message}")
  end

  routingContext.response.end

}, false)


$vertx.create_http_server.request_handler(&router.method(:accept)).listen 8080