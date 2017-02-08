require 'vertx/vertx'
require 'oai'
require 'logger'
require 'open-uri'
require 'redis'
require 'json'

outpath = ENV['OUT'] + ENV['IMAGE_OUT_SUB_PATH']
product = ENV['SHORT_PRODUCT']

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)

@logger.debug "[retrieve work from outpath worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


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




