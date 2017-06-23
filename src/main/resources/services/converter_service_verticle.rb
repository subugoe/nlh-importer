require 'vertx-web/router'
require 'vertx-web/body_handler'

require 'json'
require 'redis'
require 'logger'


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG
@logger.debug "[converter_service] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@file_logger       = Logger.new(ENV['LOG'] + "/converter_service_verticle_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

# ---

@queue             = ENV['REDIS_CONVERT_QUEUE']
@rredis            = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)


def pushToQueue(queue, arr)
  @rredis.lpush(queue, arr)
end

def send_error(status_code, response)
  response.set_status_code(status_code).end
end


router = VertxWeb::Router.router($vertx)
router.route().handler(&VertxWeb::BodyHandler.create().method(:handle))

# POST http://127.0.0.1:8080   /api/converter/jobs
# {"ppn": "PPN826737668" , "context": "gdz"}
# or
# {"id": "mets_emo_farminstructordiaryno2farmcluny19091920.xml" , "context": "nlh"}
router.post("/api/converter/jobs").blocking_handler(lambda { |routingContext|

  begin
    hsh = routingContext.get_body_as_json

    if hsh == nil
      @logger.error("[converter_service] Expected JSON body missing")
      @file_logger.error("[converter_service]  Expected JSON body missing")
      send_error(400, response)
    else
      @logger.info("[converter_service] Got message: \t#{hsh}")
      pushToQueue(@queue, [hsh.to_json])
    end


  rescue Exception => e
    @logger.error("[converter_service] Problem with request body \t#{e.message}")
    @file_logger.error("[converter_service] Problem with request body \t#{e.message}\n\t#{e.backtrace}")
  end

  routingContext.response.end

}, false)


$vertx.create_http_server.request_handler(&router.method(:accept)).listen 8080