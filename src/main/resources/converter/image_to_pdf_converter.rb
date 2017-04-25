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

productin     = ENV['IN'] + '/' + ENV['PRODUCT']
@imageinpath  = productin + ENV['IMAGE_IN_SUB_PATH']
@imageoutpath = ENV['OUT'] + ENV['IMAGE_OUT_SUB_PATH']
@pdfoutpath   = ENV['OUT'] + ENV['PDF_OUT_SUB_PATH']

@image_in_format  = ENV['IMAGE_IN_FORMAT']
@image_out_format = ENV['IMAGE_OUT_FORMAT']

@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)
@solr   = RSolr.connect :url => ENV['SOLR_ADR']

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/#{context}_image_to_pdf_converter_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@logger.debug "[image to pdf converter worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

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


    @rredis.incr 'imagescopied'
  rescue Exception => e
    @file_logger.error "Could not copy image from: '#{from}' to: '#{to}'\n\t#{e.message}"
  end

  return to

end

def convert(work, product, solr_page_arr, image_format, to_full_pdf, to_pdf_dir)

  begin
    FileUtils.mkdir_p(to_pdf_dir)
    FileUtils.rm(to_full_pdf, :force => true)

    @logger.debug "creating #{to_full_pdf}"

    MiniMagick::Tool::Convert.new do |convert|


      solr_page_arr.each { |path|
        convert << "#{path}"
      }
      convert << "-define" << "pdf:use-cropbox=true"
#      convert << "-density" << "100"

#      convert << solr_page_arr.join(' ')
      convert << "#{to_full_pdf}"
    end

  rescue Exception => e
    @file_logger.error "Could not convert images to Full PDF: '#{to_full_pdf}'\n\t#{e.message}"
  end

end


def convert(from, to_page_pdf, to_pdf_dir)

  begin
    FileUtils.mkdir_p(to_pdf_dir)
    #FileUtils.rm(to_full_pdf, :force => true)

    MiniMagick::Tool::Convert.new do |convert|

      convert << from
      convert << "-define" << "pdf:use-cropbox=true"
      #convert << "-density" << "100"
      convert << "#{to_page_pdf}"

    end

  rescue Exception => e
    @file_logger.error "Could not convert images to Full PDF: '#{to_page_pdf}'\n\t#{e.message}"
  end

end


$vertx.execute_blocking(lambda { |future|


  while true do

    res = @rredis.brpop("worksToProcess") # ⇒ nil, [String, String]

    attempts = 0
    begin

      if (res != '' && res != nil)


        json    = JSON.parse(res[1])
        work    = json['work']
        product = json['product']


        solr_work = @solr.get 'select', :params => {:q => "work:#{work}", :fl => "image_format, page"}


        image_format  = solr_work['response']['docs'].first['image_format']
        solr_page_arr = solr_work['response']['docs'].first['page']

        @logger.debug "Creating #{solr_page_arr.size} PDFs for Work: #{work} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"

        to_pdf_dir = "#{@pdfoutpath}/#{product}/#{work}/"

        solr_page_arr.each { |page|

          from        = "#{@imageoutpath}/#{product}/#{work}/#{page}.#{image_format}"
          to_page_pdf = "#{@pdfoutpath}/#{product}/#{work}/#{page}.pdf"
          convert(from, to_page_pdf, to_pdf_dir) # convert to page pdfs
        }

        @logger.debug "\tFinish PDF creation for work: #{work} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"

        #convert(work, product, image_paths, image_format, to_full_pdf, to_pdf_dir) # convert to page pdfs


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

