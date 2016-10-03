require 'vertx/vertx'
require 'vertx-redis/redis_client'

require 'logger'
require 'redis'
require 'json'
require 'fileutils'


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/nlh_fileNotFound.log")
@file_logger.level = Logger::DEBUG

redis_config = {
    'host' => ENV['REDIS_HOST'],
    'port' => ENV['REDIS_EXTERNAL_PORT'].to_i
}




@redis       = VertxRedis::RedisClient.create($vertx, redis_config)


@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i)

MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i


@inpath  = ENV['IN'] + ENV['METS_IN_SUB_PATH']
@outpath = ENV['OUT'] + ENV['METS_OUT_SUB_PATH']


#----------------


@logger.debug "[mets_copier worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def pushToQueue(queue, hsh)
  @rredis.lpush(queue, hsh.to_json)
end


def copyFile(from, to, to_dir)

  begin
    FileUtils.mkdir_p(to_dir)
    FileUtils.cp(from, to)

    fixity = (Digest::MD5.file from).hexdigest

    hsh = Hash.new
    hsh.merge!({"from" => from})
    hsh.merge!({"to" => to})
    hsh.merge!({"fixity" => fixity})

    pushToQueue("fixitychecker", hsh)


    @rredis.incr 'metscopied'

  rescue Exception => e
    @file_logger.error "Could not copy mets: '#{from}' to: '#{to}'\n\t#{e.message}"
    pushToQueue("filenotfound", from)
  end

  return to

end


$vertx.execute_blocking(lambda { |future|

  seconds = 20

  catch (:stop) do

    while true do

      begin

        res = @rredis.brpop("metscopier")

        if (res != '' && res != nil)
          json = JSON.parse res[1]
          uri  = json['path']

          match1   = uri.match(/(\S*)\/(\S*_\S*_\S*)/)
          filename = match1[2]

          match2  = uri.match(/(\S*)\/(\S*)_(\S*)_(\S*)\.(\S*)/)
          prefix  = match2[2]
          product = match2[3]
          work    = match2[4]
          format  = match2[5]


          from   = "#{@inpath}/#{filename}"
          to     = "#{@outpath}/#{product}/#{work}.#{prefix}.#{format}"
          to_dir = "#{@outpath}/#{product}"

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