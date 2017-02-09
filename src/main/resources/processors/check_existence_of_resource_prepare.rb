require 'vertx/vertx'
require 'oai'
require 'logger'
require 'open-uri'
require 'redis'
require 'json'
require 'rsolr'

# prepare config: 1 instance, 5GB importer, 4GB redis, 7GB solr
# process config: 20 instances, 10GB importer, 5GB redis, 1GB solr

MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i
#outpath  = ENV['IN'] + ENV['METS_IN_SUB_PATH']
outpath      = ENV['OUT']
#metspath  = outpath + ENV['METS_OUT_SUB_PATH']
@imagepath   = outpath + ENV['IMAGE_OUT_SUB_PATH']
@teipath     = outpath + ENV['TEI_OUT_SUB_PATH']
@pdfpath     = outpath + ENV['PDF_OUT_SUB_PATH']
logpath      = ENV['LOG']
redishost    = ENV['REDIS_HOST']
redisport    = ENV['REDIS_EXTERNAL_PORT']
redisdb      = ENV['REDIS_DB']
solradr      = ENV['SOLR_ADR']

#solr_fq = ENV['SOLR_FQ']
context      = ENV['CONTEXT']
prepare      = ENV['REPARE']


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(logpath + "/#{context}_check_existence_of_resource_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@rredis = Redis.new(:host => redishost, :port => redisport.to_i, :db => redisdb.to_i)
@solr   = RSolr.connect :url => solradr

@logger.debug "[check_existence_of_resource_prepare.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

i            = 0
rows         = 100
@works       = 0
@collections = 0
@pages       = 0


def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end


def retrievePaths(solr_works_with_fulltext, queue)

  arr = Array.new
  solr_works_with_fulltext['response']['docs'].each { |doc|
    doctype = doc['doctype']
    if doctype == "work"
      @works       += 1
      pid          = doc['pid']
      image_format = doc['image_format']
      product      = doc['product']
      work         = doc['work']
      page         = doc['page']

      fullpdf_path = "#{@pdfpath}/#{product}/#{work}/#{work}.pdf"
      arr << {"path" => fullpdf_path}.to_json

      page.each { |p|
        @pages += 1

        image_path = "#{@imagepath}/#{product}/#{work}/#{p}.#{image_format}"
        arr << {"path" => image_path}.to_json

        pagepdf_path = "#{@pdfpath}/#{product}/#{work}/#{p}.pdf"
        arr << {"path" => pagepdf_path}.to_json

        fulltext_path = "#{@teipath}/#{product}/#{work}/#{p}.tei.xml"
        arr << {"path" => fulltext_path}.to_json
      }
    else
      @collections += 1
    end
  }

  pushToQueue(arr, queue)

end


qi     = 0
query  = "fulltext:*"
queue = 'check_path_with_fulltext'


catch (:stop) do

  while true

    attempts = 0
    begin

      solr_works_with_fulltext = @solr.get 'select', :params => {:q => query, :fl => 'pid, product, work, page, doctype, image_format', :start => i*rows, :rows => rows}

      unless solr_works_with_fulltext['response']['docs'].size == 0

        retrievePaths(solr_works_with_fulltext, queue)

      else
        @logger.info "Response from solr is empty. Retrieved #{@works} works with fulltext. Start query for works without fulltext."
        if qi < 2
          qi           += 1
          query        = "!fulltext:*"
          queue       = "check_path_without_fulltext"
          @works       = 0
          @collections = 0
          @pages       = 0
          i            = -1
        else
          @logger.debug "Retrieved #{@works} works without fulltext. All Queries processed."
          throw :stop
        end
      end

    rescue Exception => e
      attempts = attempts + 1
      retry if (attempts < MAX_ATTEMPTS)
      @logger.error "Problem to get Solr data (#{e.message})"
      @file_logger.error "Problem to get Solr data \t#{e.message}\n\t#{e.backtrace}"
    end

    i += 1
    @logger.debug "works=#{@works}, collections=#{@collections}, pages=#{@pages}"


  end
end

