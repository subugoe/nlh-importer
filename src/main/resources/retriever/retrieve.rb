require 'vertx/vertx'
require 'vertx-redis/redis_client'

require 'oai'
require 'logger'
require 'open-uri'
#require 'redis'
require 'json'

@logger       = Logger.new(STDOUT) # 'gdz_object.log')
@logger.level = Logger::DEBUG

redis_config  = {
    'host' => ENV['REDIS_HOST'],
    'port' => ENV['REDIS_PORT'].to_i
}


@redis         = VertxRedis::RedisClient.create($vertx, redis_config)
#redis        = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_PORT'])

@logger.debug "[retrieve worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

# todo change this
#inpath = '/inpath/'
inpath = '/Volumes/NLH/PROD/ZDB-1-EAI/METS_Daten'

def dirname(path)
  path = path.to_s

  i = path.rindex('/')
  s = path[0..(i-1)]
  i = s.rindex('/')
  s = s[(i+1)..(s.size-1)]


  return s.gsub(/\s/, "_") #.downcase
end


def filename(path)
  path = path.to_s

  i = path.rindex('/')
  s = path[(i+1)..(path.size-1)]

  i = s.rindex('.')
  s = s[(0)..(i-1)]

  return s # .gsub(/\s/, "")#.downcase
end


def push(arr)
  @redis.lpush_many("paths", arr) { |res_err, res|

    if res_err != nil
      @logger.error("Error: '#{res_err}'")
    else
      @logger.info "Pushed #{arr.size} paths to redis"
    end
  }

end


=begin
sum      = 0


sum += response.count
@logger.info("identifieres: #{sum}")

arr = Array.new
response.each do |record|
  identifier = record.identifier
  ppn        = parseId(identifier)
  arr << {"ppn" => ppn}.to_json
end
push(arr)
=end


# todo change inpath to /Volumes/NLH/PROD/**/METS_Daten
paths = Dir.glob("#{inpath}/*.xml", File::FNM_CASEFOLD).select { |e| !File.directory? e }

arr = Array.new
paths.each {|path|
  file = filename path
  arr << {"path" => path, "filename" => file}.to_json
}
push(arr)



@redis.set("pathscount", paths.size.to_s) { |res_err, res|
  #
}


converter_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'workerPoolName'             => 'converter_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000
}

#puts "paths.size: #{paths.size}"


#c = $vertx.deploy_verticle("de.unigoettingen.sub.converter.ConvertVerticle", converter_options)




