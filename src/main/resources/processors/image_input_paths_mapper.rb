require 'vertx/vertx'
require 'logger'
require 'redis'
require 'json'


inpath = ENV['ORIG']

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)

@logger.debug "[image_input_paths_mapper worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


arr_2  = Array.new

arr = Dir.glob("#{inpath}/*").select { |f| (File.directory? f) && (!f.include? ".") && (f.include? "release") }
arr.each { |path|
  arr_2 << File.basename(path)
}


arr_2.each { |release|
  arr = Dir.glob("#{inpath}/#{release}/*").select { |f| (File.directory? f) && (!f.include? ".") }

  arr.each { |path|
    name = File.basename path
    @rredis.hset('mapping', name, release)
  }
}



