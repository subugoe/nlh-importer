require 'vertx/vertx'
require 'vertx-web/router'
require 'vertx-web/body_handler'

require 'logger'
require 'gelf'

require 'services/converter_service'
require 'services/indexer_service'
require 'services/reindex_service'
require 'services/purger_service'


#@logger       = Logger.new(STDOUT)
#@logger.level = ENV['DEBUG_MODE'].to_i

@logger       = GELF::Logger.new(ENV['GRAYLOG_URI'], ENV['GRAYLOG_PORT'].to_i, "WAN", {:facility => ENV['GRAYLOG_FACILITY']})
@logger.level = ENV['DEBUG_MODE'].to_i

@logger.info "[services_verticle] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def send_status(status_code, response, msg_hsh)
  response.set_status_code(status_code).end(msg_hsh.to_json)
end

def check_request(routingContext, route)

  begin
    hsh      = routingContext.get_body_as_json
    response = routingContext.response

    if hsh == nil
      @logger.error("[services_verticle] Expected JSON body missing")
      send_error(400, response)
    else

      case route
        when "converter"
          @logger.info("[services_verticle] Receive converter job: \t#{hsh}")
          converter = ConverterService.new
          converter.process_response(hsh, response)
        when "indexer"
          @logger.info("[services_verticle] Receive indexer job: \t#{hsh}")
          indexer = IndexerService.new
          indexer.process_response(hsh, response)
        when "reindexer"
          @logger.info("[services_verticle] Receive reindexer job: \t#{hsh}")
          reindexer = ReindexService.new
          reindexer.process_response(hsh, response)
        when "purge"
          @logger.info("[services_verticle] Receive purge job: \t#{hsh}")
          purger = PurgerService.new
          purger.process_response(hsh, response)
        else
          # TODO
      end

    end

  rescue Exception => e
    @logger.error("[services_verticle] Problem with request body \t#{e.message}")

    # any error
    send_status(400, response, {"status" => "-1", "msg" => "Could not process request"})
  end

end



router = VertxWeb::Router.router($vertx)
router.route().handler(&VertxWeb::BodyHandler.create().method(:handle))


# --- converter service ---


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
router.post(ENV['CONVERTER_CTX_PATH']).blocking_handler(lambda {|routingContext|

  check_request(routingContext, "converter")

}, false)


# --- index service ---


# POST http://134.76.18.25:8083  /api/indexer/jobs
# Request
# {
#     "document": "PPN591416441",
#     "context": "gdz"
# }
router.post(ENV['INDEXER_CTX_PATH']).blocking_handler(lambda {|routingContext|

  check_request(routingContext, "indexer")

}, false)


# --- reindex service ---


# POST http://134.76.18.25:8083   /api/reindexer/jobs
# Request
# {
#     "context": "gdz"
# }
router.post(ENV['REINDEXER_CTX_PATH']).blocking_handler(lambda {|routingContext|

  check_request(routingContext, "reindexer")

}, false)

# --- purge service ---


# POST http://134.76.18.25:8083   /api/purge/jobs
# Request
# {
#     "document": "PPN591416441",
#     "context": "gdz"
# }
router.post(ENV['PURGE_CTX_PATH']).blocking_handler(lambda {|routingContext|

  check_request(routingContext, "purge")

}, false)




$vertx.create_http_server.request_handler(&router.method(:accept)).listen 8080