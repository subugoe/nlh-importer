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

@logger.debug "[pdf copier worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"



inpath = ENV['ORIG']
outpath = ENV['OUT'] + ENV['PDF_OUT_SUB_PATH']
product = ENV['PRODUCT']

def copyFile(from, to, to_dir)

  begin
    FileUtils.mkdir_p(to_dir)
    FileUtils.cp(from, to)

    # fixity = (Digest::MD5.file from).hexdigest
    #
    # hsh = Hash.new
    # hsh.merge!({"from" => from})
    # hsh.merge!({"to" => to})
    # hsh.merge!({"fixity" => fixity})
    #
    # pushToQueue("fixitychecker", hsh)


    @rredis.incr 'pdfscopied'

  rescue Exception => e
    @file_logger.error "Could not copy pdf: '#{from}' to: '#{to}'\n\t#{e.message}"
  end

  # return to

end




$vertx.execute_blocking(lambda { |future|

  seconds = 20

  catch (:stop) do

    while true do

      begin

        res = @rredis.brpop("pdfpath")

        if (res != '' && res != nil)
          json = JSON.parse res[1]
          uri  = json['path']

          match1   = path.match(/([\s\S]*)\/([\s\S]*).(pdf|PDF)/)
          match2 = path.match(/([\s\S]*)\/([\s\S]*.[pdf|PDF])/)
          from = match1[0]

          origName = match2[2]
          name = origName.gsub(' ', '').downcase

          to     = "#{outpath}/#{product}/#{name}"
          to_dir = "#{outpath}/#{product}"

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