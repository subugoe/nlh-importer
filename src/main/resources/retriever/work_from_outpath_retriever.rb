require 'vertx/vertx'
require 'oai'
require 'logger'
require 'open-uri'
require 'redis'
require 'json'

# prepare config (NLH): 1 instance, 11GB importer, 2GB redis, 3GB solr
# process config (gdz): 20 instances, 11GB importer, 2GB redis, 3GB solr


outpath = ENV['OUT'] + ENV['IMAGE_OUT_SUB_PATH']
product = ENV['SHORT_PRODUCT']

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)

@logger.debug "[retrieve work from outpath worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end



paths = Dir.glob("#{outpath}/#{product}/*", File::FNM_CASEFOLD).select { |e| File.directory? e }

arr = Array.new

paths.each {|path|
  match = path.match(/([\S\W]*)\/([\S\W]*)/)
  work = match[2]
  arr << {"work" => work, "product" => product}.to_json
}

pushToQueue(arr, 'worksToProcess')




