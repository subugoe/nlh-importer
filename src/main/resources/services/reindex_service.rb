require 'vertx/vertx'
require 'vertx-web/router'
require 'vertx-web/body_handler'

require 'rsolr'
require 'json'
require 'redis'
require 'logger'
require 'oai'
require 'open-uri'
require 'aws-sdk'

class ReindexService


  MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

  def initialize
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

    @s3_client = Aws::S3::Client.new(
        :access_key_id     => ENV['S3_AWS_ACCESS_KEY_ID'],
        :secret_access_key => ENV['S3_AWS_SECRET_ACCESS_KEY'],
        :endpoint          => ENV['S3_ENDPOINT'],
        :force_path_style  => true,
        :region            => 'us-west-2')

    @nlh_bucket = ENV['S3_NLH_BUCKET']
    @gdz_bucket = ENV['S3_GDZ_BUCKET']

    @logger.debug "[reindex_service] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

  end

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

  def process_keys keys, context

    puts "keys.size: #{keys.size}"

    arr = Array.new
    keys.each {|key|
      arr << {"s3_key" => key, "context" => context}.to_json
    }

    pushToQueue(@queue, arr)
  end

  def reindex(context)

    @rredis.del @queue

    bucket = ''

    case context
      when "nlh"
        bucket = @nlh_bucket
      when "gdz"
        bucket = @gdz_bucket
    end


    i = 0
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
      puts "e.message: #{e.message}\n\te.backtrace: #{e.backtrace}"
    end

    @logger.debug("[reindex_service] sum=#{i}")

  end

  def process_response(hsh, response)

    begin

      if hsh == nil
        @logger.error("[reindex_service] Expected JSON body missing")
        @file_logger.error("[reindex_service]  Expected JSON body missing")
        send_error(400, response)
        return
      else

        @logger.info("[reindex_service] Got message: \t#{hsh}")

        json = JSON.parse hsh.to_json

        context = json['context']


        if (context != nil) && (context.downcase == "gdz")
          reindex "gdz"

        elsif (context != nil) && (context.downcase == "nlh")
          reindex ":nlh"

        else
          @logger.error "[reindex_service] Could not process context '#{context}',\t(#{Java::JavaLang::Thread.current_thread().get_name()})"
          send_error(400, response)
          return
        end

      end

      @logger.error "[reindex_service] Reindex started"
      send_error(200, response)
      return

    rescue Exception => e
      @logger.error("[reindex_service] Problem with request body \t#{e.message}\n\t#{e.backtrace}")
      @file_logger.error("[reindex_service] Problem with request body \t#{e.message}")
    end

  end

end


