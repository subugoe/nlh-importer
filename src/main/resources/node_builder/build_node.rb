require 'vertx/vertx'
require 'vertx-redis/redis_client'
require 'logger'

require 'open-uri'
#require 'redis'
require 'orchard'
require 'json'
require 'digest'


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

redis_config = {
    'host' => ENV['REDIS_HOST'],
    'port' => ENV['REDIS_PORT'].to_i
}
@redis        = VertxRedis::RedisClient.create($vertx, redis_config)

#redis        = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_PORT'])

@logger.debug "[node-build worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def buildNodeFor(ppn)


  md5 = Digest::MD5.hexdigest ppn
# sha1 = Digest::SHA1.hexdigest ppn


  pt  = Orchard::Pairtree.id_to_ppath(md5)


# pt  = Orchard::Pairtree.id_to_ppath(ppn)
  a   = `curl -is -X PUT $FEDORA_BASE_URL/#{pt}`

  object_uri = a.tr("\r", "").split("\n").to_a.last


  hsh = {"ppn" => ppn, "object_uri" => object_uri}

  @redis.lpush("ppn_to_index", hsh.to_json) { |res_err, res|
    if res_err != nil
      @logger.error("Error: '#{res_err}'")
    else
      @logger.info("Info: PPN stored in redis '#{res}'")
    end
  }


end


#$vertx.execute_blocking(lambda { |future|

catch (:stop) do

  # todo remove counter
  i = 0


  while true do

    throw :stop if i==1 # ENV['OBJECTS_TO_PROCESS'].to_i

    begin


      #ppn = redis.brpop("ppn_to_build", :timeout => nil)[1]

      @redis.brpop("ppn_to_build", 30) { |res_err, res|
        if res_err == nil
          @logger.debug("res: #{res}")
          json = JSON.parse res[1]
          buildNodeFor(json['ppn'])
        else
          # error
        end
      }


    rescue Exception => e
      @logger.debug("Exception in build_node.rb: #{e.message}")
      throw :stop
    end


    i +=1

  end

end


#future.complete(doc.to_s)

#}) { |res_err, res|
#
#}