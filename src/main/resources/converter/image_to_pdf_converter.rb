require 'vertx/vertx'
require 'rsolr'
require 'logger'
require 'nokogiri'
require 'redis'
require 'json'
require 'fileutils'
require 'mini_magick'
require 'model/mets_mods_metadata'
require 'open-uri'
#require 'combine_pdf'

require 'vertx/future'
require 'vertx/composite_future'


@options = {
    'sendTimeout' => 300000
}

context      = ENV['CONTEXT']
MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

productin     = ENV['IN'] + '/' + ENV['PRODUCT']
@imageinpath  = productin + ENV['IMAGE_IN_SUB_PATH']
@imageoutpath = ENV['OUT'] + ENV['IMAGE_OUT_SUB_PATH']

@image_in_format  = ENV['IMAGE_IN_FORMAT']
@image_out_format = ENV['IMAGE_OUT_FORMAT']


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/image_to_pdf_converter_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@queue  = ENV['REDIS_CONVERT_QUEUE']
@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)
@solr   = RSolr.connect :url => ENV['SOLR_ADR']


# ---

def log_error(msg, e)

  unless e == nil
    @logger.error("[image_to_pdf_converter] #{msg} \t#{e.message}")
    @file_logger.error("[image_to_pdf_converter] #{msg} \t#{e.message}\n\t#{e.backtrace}")
  else
    @logger.error("[image_to_pdf_converter] #{msg}")
    @file_logger.error("[image_to_pdf_converter] #{msg}")
  end

end


def log_info(msg)
  @logger.info("[image_to_pdf_converter] #{msg}")
  @file_logger.info("[image_to_pdf_converter] #{msg}")
end

def log_debug(msg)
  @logger.debug("[image_to_pdf_converter] #{msg}")
  @file_logger.debug("[image_to_pdf_converter] #{msg}")
end

# ---

log_debug "Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def removeQueue(queue)
  keys = @rredis.hkeys(queue)
  unless keys.empty?
    @rredis.hdel(queue, keys)
  end
end


def push_to_event_bus(id, context)

  request_logical_part = false

  if id.include? '___LOG_'
    match = id.match(/(\S*)___(LOG_)([\d]*)/)
    work  = match[1]
    #log_id_value         = match[3]
    log_id               = match[2]+match[3]
    request_logical_part = true
  else
    work = id
    #log_id_value = 0
    log_id = "LOG_0000"
  end

  solr_resp = @solr.get 'select', :params => {:q => "work:#{work}", :fl => "id doctype"}
  if solr_resp['response']['numFound'] == 0
    log_error "Work: '#{work}' for id: '#{id}' could not be found in index, conversion not possible", nil
    return
  end

  doctype = solr_resp['response']['docs'].first['doctype']

  if doctype == 'work'

    resp = (@solr.get 'select', :params => {:q => "work:#{work}", :fl => "page log_id log_start_page_index log_end_page_index"})['response']['docs'].first

    log_start_page_index = 0
    log_end_page_index   = -1

    if request_logical_part

      log_id_index = resp['log_id'].index log_id

      log_start_page_index = (resp['log_start_page_index'][log_id_index])-1
      log_end_page_index   = (resp['log_end_page_index'][log_id_index])-1

    end

    pages       = resp['page'][log_start_page_index..log_end_page_index]
    pages_count = pages.size

    # todo remove this
    puts "log_id: #{log_id}, pages_count: #{pages_count}"

    pages.each {|page|
      msg = {
          'context'              => context,
          'id'                   => id,
          'work'                 => work,
          "log_id"               => log_id,
          "request_logical_part" => request_logical_part,
          'page'                 => page,
          'pages_count'          => pages_count
      }
      $vertx.event_bus().send("image.load", msg.to_json, @options)
    }

    unless request_logical_part
      log_debug "Generate PDF for work #{work}"
    else
      log_debug "Generate PDF for logical part #{log_id} of #{work}"
    end


  else
    log_error "Could not create a PDF for the multivolume work: '#{work}', PDF not created", nil
  end

end

def removeQueue(queue)
  keys = @rredis.hkeys(queue)
  unless keys.empty?
    @rredis.hdel(queue, keys)
  end
end


$vertx.execute_blocking(lambda {|future|


  while true do

    res = @rredis.brpop(@queue) # ⇒ nil, [String, String]


    attempts = 0

    begin

      if (res != '' && res != nil)

        msg  = res[1]
        json = JSON.parse msg

        context = json['context']

        unless context == nil

          raise "Unknown context '#{context}', use {gdz | nlh}" unless (context.downcase == "nlh") || (context.downcase == "gdz")

          id = json['id']

          log_info "Convert work id=#{id}"

          removeQueue(id)

          push_to_event_bus(id, context)

        else
          raise "No context specified in request, use {gdz | nlh}"
        end

      else
        raise "Could not process empty string or nil"
      end

    rescue Exception => e
      attempts = attempts + 1
      retry if (attempts < MAX_ATTEMPTS)
      log_error "Could not process redis data '#{res[1]}'", e
      next
    end
  end


  # future.complete(doc.to_s)

}) {|res_err, res|
  #
}

