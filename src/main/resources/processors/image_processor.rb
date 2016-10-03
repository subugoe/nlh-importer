require 'vertx/vertx'
require 'vertx-redis/redis_client'

require 'rsolr'
#require 'elasticsearch'
require 'logger'
require 'nokogiri'
require 'redis'
require 'json'
require 'lib/mets_mods_metadata'
require 'fileutils'
require 'mini_magick'


redis_config = {
    'host' => ENV['REDIS_HOST'],
    'port' => ENV['REDIS_EXTERNAL_PORT'].to_i
}



@redis       = VertxRedis::RedisClient.create($vertx, redis_config)


@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i)
@solr        = RSolr.connect :url => ENV['SOLR_ADR']

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/nlh_fileNotFound.log")
@file_logger.level = Logger::DEBUG


MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i


@inpath  = ENV['IN'] + ENV['IMAGE_IM_SUB_PATH']
@outpath = ENV['OUT'] + ENV['IMAGE_OUT_SUB_PATH']

#----------------


@logger.debug "[image_processor worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

def pushToQueue(queue, hsh)
  @rredis.lpush(queue, hsh.to_json)
end


def convert(from, to, to_dir)

  begin
    FileUtils.mkdir_p(to_dir)

    MiniMagick::Tool::Convert.new do |convert|
      convert << "#{from}"
      convert << "-density" << "300"
      convert << "-crop" << "100%x100%"
      convert << "#{to}"
    end


    # fixity = (Digest::MD5.file from).hexdigest
    #
    # hsh = Hash.new
    # hsh.merge!({"from" => from})
    # hsh.merge!({"to" => to})
    # hsh.merge!({"fixity" => fixity})
    #
    # pushToQueue("fixitychecker", hsh)


    @rredis.incr 'imagescopied'

  rescue Exception => e
    @file_logger.error "Could not convert image: '#{from}' to: '#{to}'\n\t#{e.message}"
    pushToQueue("filenotfound", from)
  end

end


$vertx.execute_blocking(lambda { |future|

  seconds = 20

  while true do

    res = @rredis.brpop("processImageURI")

    if (res != '' && res != nil)

      json = JSON.parse res[1]

      match   = json['image_uri'].match(/(\S*)\/(\S*):(\S*):(\S*)\/(\S*)\/(\S*)\/(\S*)\/(\S*)\.(\S*)/)
      product = match[2]
      work    = match[3]
      file    = match[4]
      format  = match[9]


      from   = "#{@inpath}/#{work}/#{file}.gif" # "#{format}"
      to     = "#{@outpath}/#{product}/#{work}/#{file}.jpg"
      to_dir = "#{@outpath}/#{product}/#{work}"

      convert(from, to, to_dir)

      # file size, resolution, ...

      seconds = seconds / 2 if seconds > 20

    else
      @logger.error "Get empty string or nil from redis"
      sleep 20
      seconds = seconds * 2 if seconds < 300
    end
  end

  # future.complete(doc.to_s)

}) { |res_err, res|
  #
}
