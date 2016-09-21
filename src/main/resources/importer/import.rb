require 'vertx/vertx'
require 'vertx-redis/redis_client'

require 'logger'
#require 'redis'
require 'open-uri'


puts "[import worker] Starting in #{Java::JavaLang::Thread.current_thread().get_name()}"


logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
redis_config = {
    'host' => ENV['REDIS_HOST'],
    'port' => ENV['REDIS_PORT'].to_i
}
#redis        = VertxRedis::RedisClient.create($vertx, redis_config)
redis        = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_PORT'])


logger.debug "[import worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def uploadToFedora(obj, logger)

  # todo do file check
  max      = 3 # ENV['MAX_ATTEMPTS'].to_i
  attempts = 0


  json                 = JSON.parse(obj)
  object_uri           = json["object_uri"]
  orig_image_uri_array = json["orig_image_uri_array"]
  new_image_uri_array  = json["new_image_uri_array"]
  retries              = json["retries"]

  size = orig_image_uri_array.size
  (0..size-1).each { |el|
    #uploadToFedora(object_uri, orig_image_uri_array[el], new_image_uri_array[el], retries, logger)

    orig_image_uri = orig_image_uri_array[el]
    new_image_uri  = new_image_uri_array[el]

    if (orig_image_uri == nil)
      logger.error "orig_image_uri is nil '#{orig_image_uri}'"
      return
    elsif (new_image_uri == nil)
      logger.error "new_image_uri is nil '#{orig_image_uri}'"
      return
    end

    begin
      #if (scheme == "http")
      open(orig_image_uri, "r") { |f|


        resp = `curl -is -X PUT --upload-file #{f.path} -H "Content-Type: image/tiff"  #{new_image_uri}`

        logger.debug "#{resp}"
      }
=begin
    elsif (scheme == "file")
      open(href.path) { |f|
        Hydra::Works::UploadFileToFileSet.call(pfs, f)
      }
=end
        # end


        # f1           = pfs.files.first
        #f1.mime_type = mimetype


    rescue Exception => e
      logger.info("Problem to upload image #{orig_image_uri}")
      attempts = attempts + 1
      retry if (attempts < max)
      logger.error("Could not upload image #{orig_image_uri} for #{object_uri} (#{e.message})")

      if retries < 5
        h = {"object_uri" => object_uri, "orig_image_uri_array" => v, "new_image_uri_array" => v_new, "retries" => retries+1}
        redis.lpush("object_to_import", h.to_json)
      else
        redis.lpush("object_to_import", h.to_json)
      end

    end
  }

end


$vertx.execute_blocking(lambda { |future|


  catch (:stop) do

    # todo remove counter
    i = 0


    while true do

      throw :stop if i > 499


      begin

        obj = redis.brpop("object_to_import", :timeout => nil)[1]

        uploadToFedora(obj, logger)

      rescue Exception => e
        logger.debug("Exception in import.rb: #{e.message}")
        throw :stop
      end


      i += 1

    end

  end


  #future.complete(doc.to_s)

}) { |res_err, res|
  #
}


