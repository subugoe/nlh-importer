require 'vertx-web/router'
require 'vertx-web/body_handler'

require 'json'
require 'redis'
require 'logger'
require 'rsolr'


@options = {
    'sendTimeout' => 300000
}


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG
@logger.debug "[converter_service] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@file_logger       = Logger.new(ENV['LOG'] + "/converter_service_verticle_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

# ---

@work_queue   = ENV['REDIS_WORK_CONVERT_QUEUE']
@unique_queue = ENV['REDIS_UNIQUE_QUEUE']
@rredis       = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)
@solr         = RSolr.connect :url => ENV['SOLR_ADR']


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

      send_status(400, response, {"status" => "-1a", "msg" => "Requst body missing"})

    else
      @logger.info("[converter_service] Got message: \t#{hsh}")

      id                   = hsh['document']
      log                  = hsh['log']
      context              = hsh['context']
      log_id               = "#{id}___#{log}"
      request_logical_part = (id != log)


      if (id == nil) || (log == nil) || (context == nil)
        send_status(400, response, {"status" => "-1b", "msg" => "Required parameters missed (document, log, context)"})
        return
      else

        #resp = (@solr.get 'select', :params => {:q => "id:#{id}", :fl => "page   log_id   log_start_page_index   log_end_page_index doctype"})['response']['docs'].first

        resp = (@solr.get 'select', :params => {:q => "id:#{id}", :fl => "page   log_id   log_start_page_index   log_end_page_index doctype"})['response']
        puts "resp: #{resp}"

        doc = resp['docs']&.first
        puts "doc: #{doc}"

        if resp['numFound'] == 0
          send_status(400, response, {"status" => "-1c", "msg" => "No index entry for #{id}, job not staged"})
          return

        elsif resp['docs']&.first['doctype'] != 'work'
          send_status(400, response, {"status" => "-1c", "msg" => "No conversion of doctype != 'work'"})
          return
        else

          already_in_queue = @rredis.hget(@unique_queue, log_id)
          puts "already_in_queue: #{already_in_queue}"
          if already_in_queue != nil
            @logger.debug "[converter_job_builder] Job for #{log_id} already started, process next"

            # conversion error
            if @rredis.hget(log_id, 'err') != nil
              @logger.error("[converter_service] Errors in queue #{log_id}, job not staged")
              @file_logger.error("[converter_service] Errors in queue #{log_id}, job not staged")

              send_status(400, response, {"status" => "-1d", "msg" => "Conversion errors"})
              return

            else


              if request_logical_part

                puts "logical"
                log_id_index = resp['docs']&.first['log_id'].index log

                log_start_page_index = (resp['docs']&.first['log_start_page_index'][log_id_index])-1
                log_end_page_index   = (resp['docs']&.first['log_end_page_index'][log_id_index])-1

                size = log_end_page_index.to_i - log_start_page_index.to_i

              else

                size = resp['docs']&.first['page'].size
                puts "full, size: #{size}"
              end

              #keys = @rredis.hkeys(log_id)

              puts "to_process: #{to_process}, log_id: #{log_id}, size: #{size}"
              #converted = keys.size # -1, since the field "0" is not related to a real page, it sets a lock on the id


              i = 100 - (to_process * 100 / size)
              puts "to_process: #{to_process}, size: #{size}, i: #{i}"

              if i <= 0
                send_status(200, response, {"status" => i, "msg" => "staged"})
                return
              elsif i > 0 && i < 100
                send_status(200, response, {"status" => i, "msg" => "processing"})
                return
              elsif i >= 100
                send_status(200, response, {"status" => i, "msg" => "finished"})
                return
              end
            end


          else
            @rredis.hset(@unique_queue, log_id, 0)
            pushToQueue(@work_queue, [hsh.to_json])
            #send_status(200, response, {"status" => 0, "msg" => "Work #{log_id} staged for conversion"})
          end
        end
      end
    end

  rescue Exception => e
    @logger.error("[converter_service] Problem with request body \t#{e.message}")
    @file_logger.error("[converter_service] Problem with request body \t#{e.message}\n\t#{e.backtrace}")

    # any error
    send_status(400, response, {"status" => "-1e", "msg" => "Request could not processed"})
    return
  end

  #routingContext.response.end

}, false)


$vertx.create_http_server.request_handler(&router.method(:accept)).listen 8080