require 'vertx/vertx'
#require 'vertx-redis/redis_client'

require 'oai'
require 'logger'
require 'open-uri'
require 'redis'
require 'json'

@logger       = Logger.new(STDOUT) # 'gdz_object.log')
@logger.level = Logger::DEBUG

redis_config  = {
    'host' => ENV['REDIS_HOST'],
    'port' => ENV['REDIS_EXTERNAL_PORT'].to_i
}



#@redis         = VertxRedis::RedisClient.create($vertx, redis_config)
@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)

@logger.debug "[path_retrieve worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


inpath = ENV['IN'] + ENV['METS_IN_SUB_PATH']



def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end

paths = Dir.glob("#{inpath}/*.xml", File::FNM_CASEFOLD).select { |e| !File.directory? e }

arr = Array.new
paths.each {|path|
  arr << {"path" => path}.to_json
}

# =begin
pushToQueue(arr, 'metsindexer')
pushToQueue(arr, 'metscopier')
# =end

# pushToQueue(arr, 'checkmets')


