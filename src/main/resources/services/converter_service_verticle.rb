require 'vertx-web/router'
require 'vertx-web/body_handler'

require 'json'
require 'redis'
require 'logger'


@options = {
    'sendTimeout' => 300000
}


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG
@logger.debug "[converter_service] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@file_logger       = Logger.new(ENV['LOG'] + "/converter_service_verticle_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

# ---

@queue  = ENV['REDIS_WORK_CONVERT_QUEUE']
@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)


def pushToQueue(queue, arr)
  @rredis.lpush(queue, arr)
end

def send_status(status_code, response, msg_hsh)
  response.set_status_code(status_code).end(msg_hsh.to_json)
end


router = VertxWeb::Router.router($vertx)
router.route().handler(&VertxWeb::BodyHandler.create().method(:handle))

# POST 134.76.18.25:8083     /api/converter/jobs
# Request
# {
#     "document": "PPN591416441",
#     "log": "PPN591416441",
#     "context": "gdz"
# }
#
# or
#
# {
#     "document": "PPN591416441",
#     "log": "LOG_0007",
#     "context": "gdz"
# }
#
# Response
# {
#     "status":"<percentage> | -1>"
# }
router.post("/api/converter/jobs").blocking_handler(lambda {|routingContext|

  begin

    hsh      = routingContext.get_body_as_json
    response = routingContext.response

    if hsh == nil
      @logger.error("[converter_service] Expected JSON body missing")
      @file_logger.error("[converter_service]  Expected JSON body missing")

      # TODO check response codes

      send_status(400, response, {"status" => -1, "msg" => "Requst body missing"})

    else
      @logger.info("[converter_service] Got message: \t#{hsh}")

      id      = hsh['document']
      log     = hsh['log']
      context = hsh['context']

      send_status(400, response, {"status" => -1, "msg" => "Required parameters missed (document, log, context)"}) if (id == nil) || (log == nil) || (context == nil)

      log_id = "#{id}___#{log}"

      exist = @rredis.hget(@unique_queue, log_id)

      if exist != nil
        @logger.debug "[converter_job_builder] Job for #{log_id} already started, process next"

        # conversion error
        if @rredis.hget(log_id, 'err') != nil
          @logger.error("[converter_service] Errors in queue #{log_id}, job not staged")
          @file_logger.error("[converter_service] Errors in queue #{log_id}, job not staged")

          send_status(400, response, {"status" => -1, "msg" => "Conversion errors"})

        else

          resp = (@solr.get 'select', :params => {:q => "id:#{id}", :fl => "page   log_id   log_start_page_index   log_end_page_index doctype"})['response']['docs'].first

          # no conversion of doctype != 'work'
          send_status(400, response, {"status" => -4}) if resp['doctype'] == 'work'

          if request_logical_part

            log_id_index = resp['log_id'].index log

            log_start_page_index = (resp['log_start_page_index'][log_id_index])-1
            log_end_page_index   = (resp['log_end_page_index'][log_id_index])-1

            size = log_end_page_index.to_i - log_start_page_index.to_i

          else
            size = resp['page'].size
          end

          converted = (@rredis.hkeys(log_id)).size-1 # -1, since the field "0" is not related to a real page, it sets a lock on the id

          i = converted * 100 / size

          send_status(200, response, {"status" => i})

        end

      else
        @rredis.hset(@unique_queue, log_id, 0)
        pushToQueue(@queue, [hsh.to_json])
        send_status(200, response, {"status" => 0, "msg" => "Work #{log_id} staged for conversion"})
      end

    end

  rescue Exception => e
    @logger.error("[converter_service] Problem with request body \t#{e.message}")
    @file_logger.error("[converter_service] Problem with request body \t#{e.message}\n\t#{e.backtrace}")

    # any error
    send_status(400, response, {"status" => -1, "msg" => "Request could not processed"})
  end

  #routingContext.response.end

}, false)


$vertx.create_http_server.request_handler(&router.method(:accept)).listen 8080