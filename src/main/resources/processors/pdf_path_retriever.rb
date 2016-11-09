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

@logger.debug "[pdf_path_retrieve worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"



inpath = ENV['ORIG']




def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end

paths = Dir.glob("#{inpath}/*/*/*.pdf", File::FNM_CASEFOLD).select { |e| !File.directory? e }

arr = Array.new
paths.each {|path|
  arr << {"path" => path}.to_json
}

pushToQueue(arr, 'pdfpath')

