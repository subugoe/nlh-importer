require 'vertx-web/router'
require 'vertx-web/body_handler'

require 'rsolr'
require 'json'
require 'redis'
require 'logger'
require 'oai'
require 'open-uri'


MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i
oai_endpoint = ENV['GDZ_OAI_ENDPOINT']
productin    = ENV['IN'] + '/' + ENV['PRODUCT']
@inpath      = productin + ENV['METS_IN_SUB_PATH']
@queue       = ENV['REDIS_INDEX_QUEUE']


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/reindex_service_verticle_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@rredis     = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)
@oai_client = OAI::Client.new oai_endpoint

@gdzsolr = RSolr.connect :url => ENV['GDZ_SOLR_ADR']

# ---

@logger.debug "[reindex_service] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


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
    @logger.debug("[reindex_service] Exception while parse id string: #{id} #{e.message}")
  end

end


# --- ---


def reindex(context)

  @rredis.del @queue


  case context

    when :nlh

      arr = Array.new

      paths = Dir.glob("#{@inpath}/*.xml", File::FNM_CASEFOLD).select { |e| !File.directory? e }
      paths.each { |path|
        arr << {"path" => path, "context" => "nlh"}.to_json
      }

      pushToQueue(@queue, arr)
      @logger.debug("[reindex_service] sum=#{arr.size}")

    when :gdz

      arr = Array.new

      gdz_works = @gdzsolr.get 'select', :params => {:q => "iswork:true", :sort => "pid asc", :fl => "pid", :wt => "csv", :rows => 100000, :indent => "true"}
      ppn_arr   = gdz_works.split("\n")
      ppn_arr.each { |ppn|
        arr << {"ppn" => ppn, "context" => "gdz"}.to_json
      }

      pushToQueue(@queue, arr)
      @logger.debug("[reindex_service] sum=#{arr.size}")


  end


end

# --- routes ---


router = VertxWeb::Router.router($vertx)
router.route().handler(&VertxWeb::BodyHandler.create().method(:handle))


# POST http://127.0.0.1:8080   /api/reindex
# {"context": "gdz"}
router.post("/api/reindex").blocking_handler(lambda { |routingContext|

  begin
    hsh = routingContext.get_body_as_json

    if hsh == nil
      @logger.error("[reindex_service] Expected JSON body missing \t#{e.message}\n\t#{e.backtrace}")
      send_error(400, response)
    else

      json = JSON.parse hsh.to_json

      context = json['context']


      if (context != nil) && (context.downcase == "gdz")
        reindex :gdz

      elsif (context != nil) && (context.downcase == "nlh")
        reindex :nlh

      else
        @logger.error "[reindex_service] Could not process context '#{context}',\t(#{Java::JavaLang::Thread.current_thread().get_name()})"
        send_error(400, response)
      end

    end

  rescue Exception => e
    @logger.error("[reindex_service] Problem with request body \t#{e.message}\n\t#{e.backtrace}")
    @file_logger.error("[reindex_service] Problem with request body \t#{e.message}")
  end

  routingContext.response.end

}, false)


# GET http://127.0.0.1:8080   /api/reindex/status
router.get("/api/reindex/status").blocking_handler(lambda { |routingContext|

  size = @rredis.llen(@queue)
  routingContext.response.put_header("content-type", "application/json").end(JSON.generate({'size' => size}))

}, false)


$vertx.create_http_server.request_handler(&router.method(:accept)).listen 8080