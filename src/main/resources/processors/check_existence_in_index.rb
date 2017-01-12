require 'vertx/vertx'
#require 'vertx-redis/redis_client'

require 'oai'
require 'logger'
require 'open-uri'
require 'redis'
require 'json'
require 'rsolr'

@logger       = Logger.new(STDOUT) # 'gdz_object.log')
@logger.level = Logger::DEBUG

redis_config  = {
    'host' => ENV['REDIS_HOST'],
    'port' => ENV['REDIS_EXTERNAL_PORT'].to_i
}



#@redis         = VertxRedis::RedisClient.create($vertx, redis_config)
@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)

@logger.debug "[path_retrieve worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

product = ENV['SHORT_PRODUCT']
inpath = ENV['IN'] + ENV['METS_IN_SUB_PATH']



def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end

paths = Dir.glob("#{inpath}/*.xml", File::FNM_CASEFOLD).select { |e| !File.directory? e }

arr = Array.new
paths.each {|path|
  solr_works = @solr.get 'select', :params => {:q => "product:#{product}", :fl => 'work'}
  arr << {"path" => path}.to_json if solr_works['response']['docs'].empty?
}

pushToQueue(arr, 'metsindexer')

