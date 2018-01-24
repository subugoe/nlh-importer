require 'vertx/vertx'
require 'rsolr'
require 'logger'
require 'nokogiri'
require 'redis'
require 'json'
require 'fileutils'
require 'mini_magick'
require 'model/mets_mods_metadata'

context      = ENV['CONTEXT']
MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

productin   = ENV['IN'] + '/' + ENV['PRODUCT']
@inpath  = productin + ENV['IMAGE_IN_SUB_PATH']
@outpath = ENV['OUT'] + ENV['IMAGE_OUT_SUB_PATH']

@image_in_format  = ENV['IMAGE_IN_FORMAT']
@image_out_format = ENV['IMAGE_OUT_FORMAT']

@rredis = Redis.new(
    :host            => ENV['REDIS_HOST'],
    :port            => ENV['REDIS_EXTERNAL_PORT'].to_i,
    :db              => ENV['REDIS_DB'].to_i,
    :reconnect_attempts => 3
)

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/#{context}_image_processing_#{Time.new.strftime('%y-%m-%d')}.log", 3, 20 * 1024000)
@file_logger.level = Logger::DEBUG


@logger.debug "[image_processor worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

def pushToQueue(queue, hsh)
  @rredis.lpush(queue, hsh.to_json)
end

def copyFile(from, to, to_dir)

  begin
    FileUtils.mkdir_p(to_dir)
    FileUtils.cp(from, to)

  rescue Exception => e
    @file_logger.error "Could not copy image from: '#{from}' to: '#{to}'\n\t#{e.message}"
  end

  return to

end

def convert(from, to, to_dir)

  begin
    FileUtils.mkdir_p(to_dir)

    MiniMagick::Tool::Convert.new do |convert|
      convert << "#{from}"
      # convert << "-density" << "300"
      # convert << "-crop" << "100%x100%"
      convert << "#{to}"
    end

  rescue Exception => e
    @file_logger.error "Could not convert image: '#{from}' to: '#{to}'\n\t#{e.message}"
  end

end


$vertx.execute_blocking(lambda { |future|

  while true do

    res = @rredis.brpop("processImageURI")

    attempts = 0
    begin

      if (res != '' && res != nil)


        json      = JSON.parse res[1]
        image_uri = json['image_uri']


        # image_uri = "https://nl.sub.uni-goettingen.de/image/ecj:worldvolume4:0653/full/800,/0/default.jpg"
        match     = image_uri.match(/(\S*)\/(\S*):(\S*):(\S*)\/(\S*)\/(\S*)\/(\S*)\/(\S*)\.(\S*)/)
        product   = match[2]
        work      = match[3]
        file      = match[4]
        format    = match[9]

        @logger.debug "Start image processing for work #{work} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"


        from   = "#{@inpath}/#{work}/#{file}.#{@image_in_format}"
        to     = "#{@outpath}/#{product}/#{work}/#{file}.#{@image_out_format}"
        to_dir = "#{@outpath}/#{product}/#{work}"


        if @image_in_format == @image_out_format
          copyFile(from, to, to_dir)
        else
          convert(from, to, to_dir)
        end

        @logger.debug "\tFinish image processing \t(#{Java::JavaLang::Thread.current_thread().get_name()})"

      else
        @logger.error "Get empty string or nil from redis"
      end

    rescue Exception => e
      attempts = attempts + 1
      retry if (attempts < MAX_ATTEMPTS)
      @logger.error "Could not process redis data '#{res[1]}' (#{Java::JavaLang::Thread.current_thread().get_name()})"
      @file_logger.error "Could not process redis data '#{res[1]}' (#{Java::JavaLang::Thread.current_thread().get_name()}) \n\t#{e.message}"
    end

  end

  # future.complete(doc.to_s)

}) { |res_err, res|
  #
}
