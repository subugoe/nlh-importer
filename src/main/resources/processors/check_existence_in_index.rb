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
@solr        = RSolr.connect :url => ENV['SOLR_ADR']

@logger.debug "[path_retrieve worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

product = ENV['SHORT_PRODUCT']
inpath = ENV['IN'] + ENV['METS_IN_SUB_PATH']



def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end


$vertx.execute_blocking(lambda { |future|

  while true do

    res = @rredis.brpop("checkmets")

    attempts = 0
    begin
      if (res != '' && res != nil)

        json = JSON.parse res[1]
        path = json['path']


        @logger.debug "Checking METS: #{path} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"

        # /inpath/METS_Daten/mets_eai2_10C95FDFE3EA5600.xml
        match2  = path.match(/(\S*)\/(\S*)_(\S*)_(\S*)\.(\S*)/)
        prefix  = match2[2]
        product = match2[3]
        work    = match2[4]
        format  = match2[5]


        solr_works = @solr.get 'select', :params => {:q => "product:#{product} & work:#{work}", :fl => 'work'}
        if solr_works['response']['docs'].empty?        
          pushToQueue([{"path" => path}.to_json], 'metsindexer')
          pushToQueue([{"path" => path}.to_json], 'metscopier')
        end
        
         @logger.debug "\tFinish checking METS: #{path} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"

      else
         @logger.error "Get empty string or nil from redis"
      end


    rescue Exception => e
      attempts = attempts + 1
      retry if (attempts < MAX_ATTEMPTS)
      @file_logger.error "Could not process redis data '#{res[1]}' (#{Java::JavaLang::Thread.current_thread().get_name()})"
      @file_logger.error "Could not process redis data '#{res[1]}' (#{Java::JavaLang::Thread.current_thread().get_name()}) \n\t#{e.message}"
    end

  end

  # future.complete(doc.to_s)

}) { |res_err, res|
#
}

