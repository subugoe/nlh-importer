require 'vertx/vertx'
require 'oai'
require 'logger'
require 'open-uri'
require 'redis'
require 'json'
require 'rsolr'

product = ENV['SHORT_PRODUCT']
inpath  = ENV['IN'] + ENV['METS_IN_SUB_PATH']
solr_fq = ENV['SOLR_FQ']

@logger       = Logger.new(STDOUT) # 'gdz_object.log')
@logger.level = Logger::DEBUG

@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)
@solr        = RSolr.connect :url => ENV['SOLR_ADR']

@logger.debug "[update before date_indexed worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end


solr_works_to_update = @solr.get 'select', :params => {:q => "product:#{product}", :fl => 'work', :fq => solr_fq, :rows => 100000}

arr = Array.new
solr_works_to_update['response']['docs'].each { |doc|
  work = doc['work']
  #METS_DATEN/mets_<product>_<work>.xml
  path = "#{inpath}/mets_#{product}_#{work}.xml"
  arr << {"path" => path}.to_json
}

pushToQueue(arr, 'metsindexer')


