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


# --- ---


def reindex(context)

  @rredis.del @queue

  catch (:stop) do

    arr = Array.new

    case context

    when :nlh

      paths = Dir.glob("#{@inpath}/*.xml", File::FNM_CASEFOLD).select { |e| !File.directory? e }
      paths.each { |path|
        arr << {"path" => path, "context" => "nlh"}.to_json
      }

      pushToQueue(@queue, arr)
      #pushToQueue('metscopier', arr)

    when :gdz

      sum      = 0

      # Get the first page of identifiers
      response = @oai_client.list_identifiers(:metadataPrefix => "mets")

      sum += response.count

      arr = Array.new
      response.each do |record|
        identifier = record.identifier
        ppn        = parseId(identifier)
        arr << {"ppn" => ppn, "context" => "gdz"}.to_json
      end

      pushToQueue(@queue, arr)

      @logger.debug("sum=#{sum}")

      while true do

        attempts = 0

        begin

          arr = Array.new

          response = @oai_client.list_identifiers(:resumption_token => response.resumption_token)

          sum += response.count

          @logger.debug("resumption_token: #{response.resumption_token}") if sum > 54000

          response.each do |record|
            next if record == nil

            begin
              next if record.identifier == nil
              identifier = record.identifier
              ppn        = parseId(identifier)
              arr << {"ppn" => ppn, "context" => "gdz"}.to_json
            rescue Exception => e
              @logger.debug("Problem to parse identifier: #{e.message}")
            end

          end

        rescue Exception => e
          attempts = attempts + 1
          retry if (attempts < MAX_ATTEMPTS)
          @logger.error("Exception while identifiers retrieval from OAI: (#{Java::JavaLang::Thread.current_thread().get_name()})")
          @file_logger.error "Exception while identifiers retrieval from OAI: (#{Java::JavaLang::Thread.current_thread().get_name()}) \n\t#{e.message}"
        end

        unless arr.empty?
          pushToQueue(@queue, arr)
          @logger.debug("sum=#{sum}")
        else
          throw :stop
        end

      end

    end

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



# POST http://127.0.0.1:8080   /api/indexer/reindex
# {"context": "gdz"}
router.post("/api/indexer/reindex").blocking_handler(lambda { |routingContext|


  begin
    hsh = routingContext.get_body_as_json

    if hsh == nil
      @logger.error("Expected JSON body missing \t#
{e.message}\n\t#{e.backtrace}")
      send_error(400, response)
    else

      json = JSON.parse hsh.to_json

      context = json['context']


      if (context != nil) && (context.downcase == "gdz")
        reindex :gdz

      elsif (context != nil) && (context.downcase == "nlh")
        reindex :nlh

      else
        @logger.error "\tCould not process context '#{context}',\t(#{Java::JavaLang::Thread.current_thread().get_name()})"
        send_error(400, response)
      end

    end

  rescue Exception => e
    @logger.error("Problem with request body \t#{e.message}\n\t#{e.backtrace}")
    @file_logger.error("Problem with request body \t#{e.message}")
  end

  routingContext.response.end

}, false)


# GET http://127.0.0.1:8080   /api/indexer/reindex/status
router.get("/api/indexer/reindex/status").blocking_handler(lambda { |routingContext|


  size = @rredis.llen @queue


  routingContext.response.put_header("content-type", "application/json").end(JSON.generate({'size' => size}))

}, false)


$vertx.create_http_server.request_handler(&router.method(:accept)).listen 8080