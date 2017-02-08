require 'vertx/vertx'
require 'oai'
require 'logger'
require 'open-uri'
require 'redis'
require 'json'
require 'rsolr'

# config: 5GB importer, 4GB redis, 7GB solr

#outpath  = ENV['IN'] + ENV['METS_IN_SUB_PATH']
outpath   = ENV['OUT']
#metspath  = outpath + ENV['METS_OUT_SUB_PATH']
imagepath = outpath + ENV['IMAGE_OUT_SUB_PATH']
teipath   = outpath + ENV['TEI_OUT_SUB_PATH']
pdfpath   = outpath + ENV['PDF_OUT_SUB_PATH']
logpath   = ENV['LOG']
redishost = ENV['REDIS_HOST']
redisport = ENV['REDIS_EXTERNAL_PORT']
redisdb   = ENV['REDIS_DB']
solradr   = ENV['SOLR_ADR']

#solr_fq = ENV['SOLR_FQ']
context   = ENV['CONTEXT']

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(logpath + "/#{context}_check_existence_of_resource_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@rredis = Redis.new(:host => redishost, :port => redisport.to_i, :db => redisdb.to_i)
@solr   = RSolr.connect :url => solradr

@logger.debug "[update before date_indexed worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

i           = 0
rows        = 100
works       = 0
collections = 0
pages       = 0

def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end


$vertx.execute_blocking(lambda { |future|

  catch (:stop) do

    while true

      solr_works_with_fulltext = @solr.get 'select', :params => {:q => "fulltext:*", :fl => 'pid, product, work, page, doctype, image_format', :start => i*rows, :rows => rows}
      unless solr_works_with_fulltext['response']['docs'].size == 0

        arr = Array.new
        solr_works_with_fulltext['response']['docs'].each { |doc|
          doctype = doc['doctype']
          if doctype == "work"
            works        += 1
            pid          = doc['pid']
            image_format = doc['image_format']
            product      = doc['product']
            work         = doc['work']
            page         = doc['page']

            fullpdf_path = "#{pdfpath}/#{product}/#{work}/#{work}.pdf"
            arr << {"path" => fullpdf_path}.to_json

            page.each { |p|
              pages     += 1

              image_path = "#{imagepath}/#{product}/#{work}/#{p}.#{image_format}"
              arr << {"path" => image_path}.to_json

              pagepdf_path = "#{pdfpath}/#{product}/#{work}/#{p}.pdf"
              arr << {"path" => pagepdf_path}.to_json

              fulltext_path = "#{teipath}/#{product}/#{work}/#{p}.tei.xml"
              arr << {"path" => fulltext_path}.to_json
            }
          else
            collections += 1
          end
        }

        pushToQueue(arr, 'check_path')

      else
        @logger.debug "Response from solr is empty. Retrieved #{works} works with fulltext #{Java::JavaLang::Thread.current_thread().get_name()}"
        throw :stop
      end

      i += 1
      @logger.debug "works=#{works}, collections=#{collections}, pages=#{pages}"

    end

  end

  @logger.debug "works=#{works}, collections=#{collections}, pages=#{pages}"

#solr_works_without_fulltext = @solr.get 'select', :params => {:q => "!fulltext:*", :fl => 'pid, product, work, page', :fq => solr_fq, :rows => 100000}


# future.complete(doc.to_s)

}) { |res_err, res|
#
}

