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
require 'rsolr'

class PurgerService

  MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

  def initialize

#    @logger       = Logger.new(STDOUT)
#    @logger.level = ENV['DEBUG_MODE'].to_i

    @logger       = GELF::Logger.new(ENV['GRAYLOG_URI'], ENV['GRAYLOG_PORT'].to_i, "WAN", {:facility => ENV['GRAYLOG_FACILITY']})
    @logger.level = ENV['DEBUG_MODE'].to_i

    @rredis = Redis.new(
        :host               => ENV['REDIS_HOST'],
        :port               => ENV['REDIS_EXTERNAL_PORT'].to_i,
        :db                 => ENV['REDIS_DB'].to_i,
        :reconnect_attempts => 3
    )
    @queue  = ENV['REDIS_INDEX_QUEUE']



    @nlh_bucket = ENV['S3_NLH_BUCKET']
    @gdz_bucket = ENV['S3_GDZ_BUCKET']

    @solr_gdz        = RSolr.connect :url => ENV['SOLR_GDZ_ADR']

    @logger.debug "[purge_service] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

  end


  def send_status(status_code, response, msg_hsh)
    response.set_status_code(status_code).end(msg_hsh.to_json)
  end


  def purge(context, document, product)

    i      = 0
    bucket = ''

    begin


      if context == "gdz"
        bucket = product
      elsif context.downcase.start_with?("nlh")
        bucket = product
      elsif context == "digizeit"
        # todo
      else
        raise "Bucket '#{bucket}' unknown"
      end



      if (document.strip) == "" || (document == nil)
        raise "Document '#{document}' is not a valid Id"
      else

        keys = ["mets/#{document}.xml",
                "pdf/#{document}/",
                "fulltext/#{document}/",
                "summary/#{document}/",
                "orig/#{document}/",
                "cache/#{bucket}:#{document}/"]


        if bucket.start_with?("gdz")
          @s3_client = Aws::S3::Client.new(
              :access_key_id     => ENV['S3_SUB_AWS_ACCESS_KEY_ID'],
              :secret_access_key => ENV['S3_SUB_AWS_SECRET_ACCESS_KEY'],
              :endpoint          => ENV['S3_SUB_ENDPOINT'],
              :force_path_style  => true,
              :region            => 'us-west-2')
        else bucket.start_with?("nlh")
          @s3_client = Aws::S3::Client.new(
              :access_key_id     => ENV['S3_NLH_AWS_ACCESS_KEY_ID'],
              :secret_access_key => ENV['S3_NLH_AWS_SECRET_ACCESS_KEY'],
              :endpoint          => ENV['S3_NLH_ENDPOINT'],
              :force_path_style  => true,
              :region            => 'us-west-2')
        end

        @resource = Aws::S3::Resource.new(client: @s3_client)

        keys.each { |s3_key|
          if !s3_key.start_with?("cache")
            @resource.bucket(bucket).objects({prefix: s3_key}).each { |el|
              el.move_to(:bucket => bucket, :key => "remove/" + el.key)
            }
          else
            objects = @resource.bucket(bucket).objects({prefix: s3_key})
            @resource.bucket(bucket).delete_objects(objects)
          end
        }

        @solr_gdz.delete_by_query "work_id:#{document}"

      end

    rescue Exception => e
      raise
    end

  end

  def process_response(hsh, response)

    begin

      if hsh == nil
        @logger.error("[purge_service] Expected JSON body missing")
        send_status(400, response, {"status" => "-1", "msg" => "Expected JSON body missing"})
        return
      else

        json = JSON.parse hsh.to_json

        context  = json['context']
        document = json['document']
        product = json['product']

        if (context != nil) && (context.downcase == "gdz")
          purge("gdz", document, "gdz")

        elsif (context != nil) && (context.downcase == "nlh")
          purge("nlh", document, product)

        else
          @logger.error "[purge_service] Could not process context '#{context}'"
          send_error(400, response)
          return
        end

      end

      @logger.info "[purge_service] Purge started"
      send_status(200, response, {"status" => "0", "msg" => "Purge started"})
      return

    rescue Exception => e
      @logger.error("[purge_service] Purge for document '#{document}' not possible \t#{e.message}")
      send_status(400, response, {"status" => "-1", "msg" => "Couldnot process request"})
    end

  end

end



