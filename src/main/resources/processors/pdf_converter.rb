require 'vertx/vertx'

require 'rsolr'
#require 'elasticsearch'
require 'logger'
require 'nokogiri'
require 'redis'
require 'json'
require 'lib/mets_mods_metadata'
require 'fileutils'
require 'mini_magick'


@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)
@solr   = RSolr.connect :url => ENV['SOLR_ADR']

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/nlh_fileNotFound.log")
@file_logger.level = Logger::DEBUG


MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

@image_in_format  = ENV['IMAGE_IN_FORMAT']
@image_out_format = ENV['IMAGE_OUT_FORMAT']

@inpath       = ENV['IN'] + ENV['PDF_IN_SUB_PATH']
@imageoutpath = ENV['OUT'] + ENV['IMAGE_OUT_SUB_PATH']
@pdfoutpath   = ENV['OUT'] + ENV['PDF_OUT_SUB_PATH']
@originpath   = ENV['ORIG']
@pdfdensity   = ENV['PDFDENSITY']

#----------------


@logger.debug "[pdf converter worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end


def copyFile(from, to, to_dir)

  begin
    FileUtils.mkdir_p(to_dir)
    FileUtils.cp(from, to)

    @rredis.incr 'pdfscopied'
  rescue Exception => e
    @file_logger.error "Could not copy PDF from: '#{from}' to: '#{to}'\n\t#{e.message}"
  end

  return to

end

def convert(from, to, to_dir, isPDF)

  begin
    FileUtils.mkdir_p(to_dir)

    MiniMagick::Tool::Convert.new do |convert|
      convert << "-density" << "400" unless isPDF
      convert << "-define" << "pdf:use-cropbox=true"
      convert << "#{from}"
      convert << "#{to}"
    end

    @logger.debug "from: #{from} to: #{to}"

    @rredis.incr 'pdfsconverted'


  rescue Exception => e
    @file_logger.error "Could not convert PDF: '#{from}' to: '#{to}'\n\t#{e.message}"
  end

end


$vertx.execute_blocking(lambda { |future|

  seconds = 20

  catch (:stop) do

    while true do

      begin

        res = @rredis.brpop("convertpdf")

        product = ENV['SHORT_PRODUCT']


        if (res != '' && res != nil)

          json  = JSON.parse(res[1])


          # /Volumes/NLH-1/ORIG/ZDB-1-EMO/CD2/Section II/A Tale of Indian Heroes.PDF
          match = json['path'].match(/([\S\W]*)\/([\S\W]*).(pdf|PDF)/)

          from                     = match[0]
          name                     = match[2]
          name_without_whitespaces = name.gsub(' ', '').downcase

          convert_to_image_dir   = "#{@imageoutpath}/#{product}/#{name_without_whitespaces}/%06d.#{@image_out_format}"

          to_image_dir = "#{@imageoutpath}/#{product}/#{name_without_whitespaces}/"

          convert(from, convert_to_image_dir, to_image_dir, false) # convert to images


          # file size, resolution, ...

          seconds = seconds / 2 if seconds > 20

        else
          @logger.error "Get empty string or nil from redis"
          sleep 20
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
