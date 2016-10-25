require 'vertx/vertx'
#require 'vertx-redis/redis_client'

require 'logger'
require 'redis'
require 'json'

@logger       = Logger.new(STDOUT) # 'gdz_object.log')
@logger.level = Logger::DEBUG

redis_config = {
    'host' => ENV['REDIS_HOST'],
    'port' => ENV['REDIS_EXTERNAL_PORT'].to_i
}


#@redis         = VertxRedis::RedisClient.create($vertx, redis_config)
@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i)

@logger.debug "[image_input_paths_mapper worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


inpath = ENV['IN_ORIG']
#inpath = "/Volumes/NLH/ORIG/ZDB-1-EAI/va006/raid/scan_process_001"


# ---

arr_2  = Array.new

arr = Dir.glob("#{inpath}/*").select { |f| (File.directory? f) && (!f.include? ".") && (f.include? "release") }
arr.each { |path|
  arr_2 << File.basename(path)
}


#arr_2.each {|release|
release = arr_2[0]
arr     = Dir.glob("#{inpath}/#{release}/*").select { |f| (File.directory? f) && (!f.include? ".") }

arr.each { |path|
  name = File.basename path
  @rredis.hset('mapping', name, release)
  #puts name
}


#}


# ---



