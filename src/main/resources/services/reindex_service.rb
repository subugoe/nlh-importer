require 'vertx/vertx'
require 'vertx-web/router'
require 'vertx-web/body_handler'

require 'logger'
require 'gelf'
require 'json'
require 'redis'
require 'oai'
require 'open-uri'
require 'aws-sdk'

class ReindexService

  MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

  def initialize

    #@logger       = Logger.new(STDOUT)
    #@logger.level = ENV['DEBUG_MODE'].to_i

    @logger       = GELF::Logger.new(ENV['GRAYLOG_URI'], ENV['GRAYLOG_PORT'].to_i, "WAN", {:facility => ENV['GRAYLOG_FACILITY']})
    @logger.level = ENV['DEBUG_MODE'].to_i

    @rredis = Redis.new(
        :host               => ENV['REDIS_HOST'],
        :port               => ENV['REDIS_EXTERNAL_PORT'].to_i,
        :db                 => ENV['REDIS_DB'].to_i,
        :reconnect_attempts => 3
    )
    @queue  = ENV['REDIS_INDEX_QUEUE']

    @s3_client = Aws::S3::Client.new(
        :access_key_id     => ENV['S3_AWS_ACCESS_KEY_ID'],
        :secret_access_key => ENV['S3_AWS_SECRET_ACCESS_KEY'],
        :endpoint          => ENV['S3_ENDPOINT'],
        :force_path_style  => true,
        :region            => 'us-west-2')

    @gdz_bucket = ENV['S3_GDZ_BUCKET']

    @logger.debug "[reindex_service] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

  end

  def pushToQueue(queue, arr)
    @rredis.lpush(queue, arr)
  end


  def send_status(status_code, response, msg_hsh)
    response.set_status_code(status_code).end(msg_hsh.to_json)
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


  def process_keys keys, context

    arr = Array.new
    keys.each {|key|
      begin
        id = key.match(/mets\/(\S*).xml/)[1]
      rescue Exception => e
        @logger.error("[reindex_service] Regex pattern doesn't match #{key} #{e.message}")
        next
      end
      # {"document":"PPN876605080",  "log":"PPN876605080",  "context": "gdz", "reindex":true}
      # {"document"=>"PPN234688475", "log"=>"PPN234688475", "context"=>"gdz", "reindex"=>true}
      arr << {"document" => id, "context" => context, "reindex" => true}.to_json
    }

    pushToQueue(@queue, arr)
  end

  def reindex(context, product)

    i      = 0
    bucket = ''

    @rredis.del @queue


    if context == "gdz"
      bucket = product
    elsif @context.downcase.start_with?("nlh")
      bucket = product
    elsif @context == "digizeit"
      # todo
    else
      raise "Bucket '#{bucket}' unknown"
    end


    begin

      response = @s3_client.list_objects(bucket: bucket, prefix: 'mets')

      keys = response.contents.map(&:key)
      process_keys keys, context

      i += keys.size

      while response.next_page? do
        response = response.next_page
        keys     = response.contents.map(&:key)
        process_keys keys, context
        i += keys.size
      end

    rescue Exception => e
      @logger.error("[reindex_service] #{e.message}")
    end

    @logger.debug("[reindex_service] sum=#{i}")

  end

  def process_response(hsh, response)

    begin

      if hsh == nil
        @logger.error("[reindex_service] Expected JSON body missing")
        send_status(400, response, {"status" => "-1", "msg" => "Expected JSON body missing"})
        return
      else

        json = JSON.parse hsh.to_json

        context = json['context']
        product = json['product']


        if (context != nil) && (context.downcase == "gdz") || (context.downcase == "nlh")
          reindex( context, product)
        else
          @logger.error "[reindex_service] Could not process context '#{context}'"
          send_error(400, response)
          return
        end

      end

      @logger.info "[reindex_service] Reindex started"
      send_status(200, response, {"status" => "0", "msg" => "Reindex started"})
      return

    rescue Exception => e
      @logger.error("[reindex_service] Problem with request body \t#{e.message}")
      send_status(400, response, {"status" => "-1", "msg" => "Couldnot process request"})
    end

  end

end



