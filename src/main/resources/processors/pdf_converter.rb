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

@inpath        = ENV['IN'] + ENV['PDF_IN_SUB_PATH']
@imageoutpath  = ENV['OUT'] + ENV['IMAGE_OUT_SUB_PATH']
@pdfoutpath    = ENV['OUT'] + ENV['PDF_OUT_SUB_PATH']
@originpath    = ENV['ORIG']
@pdfdensity    = ENV['PDFDENSITY']
@from_full_pdf = ENV['IMAGES_FROM_FULL_PDF']

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

def convert(from, to, to_dir, toPDF, removeBefore)

  begin
    FileUtils.mkdir_p(to_dir)
    FileUtils.rm(to, :force => true) if removeBefore == true

    @logger.debug "from: #{from} to: #{to}"

    MiniMagick::Tool::Convert.new do |convert|

      convert << "-define" << "pdf:use-cropbox=true"
      unless toPDF
        convert << "-density" << "400"
      else
        convert << "-density" << "100"
      end
      #convert << "-scene" << start.to_s unless toFullPDF

      convert << "#{from}"
      convert << "#{to}"
    end

    @rredis.incr 'pdfsconverted'


  rescue Exception => e
    @file_logger.error "Could not convert PDF: '#{from}' to: '#{to}'\n\t#{e.message}"
  end

end


def mogrifyPDFs(from, to_dir, format)

  @logger.debug "from: #{from} to: #{to_dir}"

  begin
    FileUtils.mkdir_p(to_dir)

    MiniMagick::Tool::Mogrify.new do |mogrify|
      mogrify << "-format" << format
      mogrify << "-path" << to_dir
      mogrify << "#{from}"
    end

  rescue Exception => e
    @file_logger.error "Could not convert PDFs: '#{from}' to: '#{to_dir}'\n\t#{e.message}"
  end

end

$vertx.execute_blocking(lambda { |future|

  seconds = 20

  catch (:stop) do

    while true do

      begin

        res = @rredis.brpop("convertpdftoimage") # or convertpdftopdf

        product = ENV['SHORT_PRODUCT']

        start = 1

        if (res != '' && res != nil)

          json = JSON.parse(res[1])

          if @from_full_pdf == "true"
            from = json['from']
            work = json['work']

            solr_work     = @solr.get 'select', :params => {:q => "work:#{work}"}
            first_page    = solr_work['response']['docs'].first['page'].first
            # start      = first_page.to_i

            solr_page_arr = @solr_work['response']['docs'].first['page']

            to_image_dir = "#{@imageoutpath}/#{product}/#{work}/"
            to_pdf_dir   = "#{@pdfoutpath}/#{product}/#{work}/"

            to_full_pdf    = "#{@pdfoutpath}/#{product}/#{work}/#{work}.pdf"

            solr_page_arr.each_index { |index|

              to_page_image = "#{@imageoutpath}/#{product}/#{work}/#{solr_page_arr[index]}.#{@image_out_format}"
              to_page_pdf   = "#{@pdfoutpath}/#{product}/#{work}/#{solr_page_arr[index]}.pdf"

              convert(from + "[#{index}]", to_page_image, to_image_dir, false, false) # convert to images
              convert(from + "[#{index}]", to_page_pdf, to_pdf_dir, true, false) # convert to page pdfs
            }
            copyFile(from, to_full_pdf, to_pdf_dir) # copy full pdf


            # file size, resolution, ...

            seconds = seconds / 2 if seconds > 20

          else
            # {"from" => from, "work" => work, "page" => page, "format" => format}.to_json
            from         = json['from']
            work         = json['work']
            #page         = json['page']
            #format       = json['format']


            #to_page_image = "#{@imageoutpath}/#{product}/#{work}/#{page}.#{@image_out_format}"
            #to_page_pdf   = "#{@pdfoutpath}/#{product}/#{work}/#{page}.pdf"

            to_image_dir = "#{@imageoutpath}/#{product}/#{work}/"
            to_pdf_dir   = "#{@pdfoutpath}/#{product}/#{work}/"


            mogrifyPDFs("#{from}/*.pdf", "#{to_image_dir}", @image_out_format) unless @image_out_format == 'pdf' # convert page pdfs to page images
            mogrifyPDFs("#{from}/*.pdf", "#{to_pdf_dir}", 'pdf') unless @image_out_format == 'pdf' # copy page pdfs to page pdfs
            convert("#{from}/*.pdf", "#{to_pdf_dir}/#{work}.pdf", to_pdf_dir, true, true) # convert page pdfs to full pdf

          end

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
