require 'vertx/vertx'

require 'rsolr'
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


@logger.debug "[pdf copier worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


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


$vertx.execute_blocking(lambda { |future|

  seconds = 20

  catch (:stop) do

    while true do

      begin

        res = @rredis.brpop("copypdf")

        product = ENV['SHORT_PRODUCT']


        if (res != '' && res != nil)

          json = JSON.parse(res[1])


          from   = json['from']
          name   = json['name']
          format = json['format']

          copy_to_pdf_dir = "#{@pdfoutpath}/#{product}/#{name}/#{name}.#{format}"
          to_pdf_dir      = "#{@pdfoutpath}/#{product}/#{name}/"

          copyFile(from, copy_to_pdf_dir, to_pdf_dir)


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
