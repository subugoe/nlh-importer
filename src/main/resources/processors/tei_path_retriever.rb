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

@logger.debug "[tei_path_retrieve worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


inpath = ENV['IN'] + ENV['TEI_IN_SUB_PATH']



def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end

work_paths = Dir.glob("#{inpath}/*", File::FNM_CASEFOLD).select { |e| File.directory? e }

work_paths.each {|wp|
  arr = Array.new
  paths = Dir.glob("#{wp}/*.tei.xml", File::FNM_CASEFOLD).select { |e| !File.directory? e }
  paths.each {|path|
    arr << {"path" => path}.to_json
  }
  pushToQueue(arr, 'teicopier')
}

