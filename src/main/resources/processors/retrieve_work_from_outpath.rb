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

@logger.debug "[retrieve work from outpath worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


outpath = ENV['OUT'] + ENV['IMAGE_OUT_SUB_PATH']
product = ENV['SHORT_PRODUCT']



def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end


puts outpath

paths = Dir.glob("#{outpath}/#{product}/*", File::FNM_CASEFOLD).select { |e| File.directory? e }

arr = Array.new
puts paths.first
puts paths.last
puts paths.size

paths.each {|path|
  match = path.match(/([\S\W]*)\/([\S\W]*)/)
  work = match[2]
  arr << {"work" => work, "product" => product}.to_json
}

pushToQueue(arr, 'worksToProcess')




