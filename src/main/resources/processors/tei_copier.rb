require 'vertx/vertx'
#require 'vertx-redis/redis_client'

require 'oai'
require 'logger'
require 'open-uri'
require 'redis'
require 'json'
require 'fileutils'

@logger       = Logger.new(STDOUT) # 'gdz_object.log')
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/nlh_fileNotFound.log")
@file_logger.level = Logger::DEBUG


redis_config  = {
    'host' => ENV['REDIS_HOST'],
    'port' => ENV['REDIS_EXTERNAL_PORT'].to_i
}



#@redis         = VertxRedis::RedisClient.create($vertx, redis_config)
@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)

@logger.debug "[tei copier worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

outpath = ENV['OUT'] + ENV['TEI_IN_SUB_PATH']


def copyFile(from, to, to_dir)

  begin
    FileUtils.mkdir_p(to_dir)
    FileUtils.cp(from, to)

    @rredis.incr 'teiscopied'
  rescue Exception => e
    @file_logger.error "Could not copy PDF from: '#{from}' to: '#{to}'\n\t#{e.message}"
  end

end


$vertx.execute_blocking(lambda { |future|

  seconds = 20

  catch (:stop) do

    while true do

      begin

        res = @rredis.brpop("teicopier")

        if (res != '' && res != nil)
          json = JSON.parse res[1]
          uri  = json['path']

          # /mnt/nlhstorage/PROD/ZDB-1-EAP/TEI/scan_process_006/release_0001/10487A71838609E0/104876242DF07B98.tei.xml

          match1   = uri.match(/([\s\S]*)\/([\s\S]*)\/([\s\S]*.tei.xml)/)

          from = match1[0]
          to     = "#{outpath}/#{match1[2]}/#{match1[3]}"
          to_dir = "#{outpath}/#{match1[2]}"

          copyFile(from, to, to_dir)


          seconds = seconds / 2 if seconds > 20

        else
          @logger.error "Get empty string or nil from redis"
          sleep seconds
          seconds = seconds * 2 if seconds < 300
        end

      rescue Exception => e
        @logger.error("Error: #{e.message}- #{e.backtrace.join('\n\t')}")
        throw :stop
      end
    end
  end

  # future.complete(doc.to_s)

}) { |res_err, res|
#
}