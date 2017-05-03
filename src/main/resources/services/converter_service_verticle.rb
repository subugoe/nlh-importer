require 'vertx-web/router'
require 'vertx-web/body_handler'

require 'json'
require 'redis'
require 'logger'


context      = ENV['CONTEXT']

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG
@logger.debug "[converter_service_verticle.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@file_logger       = Logger.new(ENV['LOG'] + "/#{context}_converter_service_verticle_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)





def pushToQueue(queue, arr)
  @rredis.lpush(queue, arr)
end

def send_error(status_code, response)
  response.set_status_code(status_code).end
end


router = VertxWeb::Router.router($vertx)
router.route().handler(&VertxWeb::BodyHandler.create().method(:handle))

# addOne
router.post("/api/conversion/jobs").blocking_handler(lambda { |routingContext|


  begin
    hsh = routingContext.get_body_as_json
    #puts  routingContext.get_body_as_json
    #puts  routingContext.get_body_as_json['ppn']
    #puts  routingContext.get_body_as_json['context']

    #routingContext.response.end

    if hsh == nil
      @logger.error("Expected JSON body missing \t#{e.message}\n\t#{e.backtrace}")
      send_error(400, response)
    else
      pushToQueue('indexer', [hsh].to_json)
    end

  rescue Exception => e
    @logger.error("Problem with request body \t#{e.message}\n\t#{e.backtrace}")
    @file_logger.error("Problem with request body \t#{e.message}")
  end

  routingContext.response.end

}, false)

$vertx.create_http_server.request_handler(&router.method(:accept)).listen 8080