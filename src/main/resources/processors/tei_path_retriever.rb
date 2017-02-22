require 'vertx/vertx'
require 'oai'
require 'logger'
require 'open-uri'
require 'redis'
require 'json'


productin = ENV['IN'] + '/' + ENV['PRODUCT']
inpath = productin + ENV['TEI_IN_SUB_PATH']


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)

@logger.debug "[tei_path_retrieve worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end

work_paths = Dir.glob("#{inpath}/*", File::FNM_CASEFOLD).select { |e| File.directory? e }

work_paths.each { |wp|
  arr   = Array.new
  paths = Dir.glob("#{wp}/*.tei.xml", File::FNM_CASEFOLD).select { |e| !File.directory? e }
  paths.each { |path|
    arr << {"path" => path}.to_json
  }
  pushToQueue(arr, 'teicopier')
}

