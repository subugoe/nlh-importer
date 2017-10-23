require 'vertx/vertx'
#require 'vertx-redis/redis_client'

require 'benchmark'
require 'aws-sdk'
require 'logger'
require 'redis'
require 'rsolr'
require 'json'


class WorkConverter

  MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

  def initialize

    @options = {
        'sendTimeout' => 300000
    }

    productin     = ENV['IN'] + '/' + ENV['PRODUCT']
    @imageinpath  = productin + ENV['IMAGE_IN_SUB_PATH']
    @imageoutpath = ENV['OUT'] + ENV['IMAGE_OUT_SUB_PATH']

    @image_in_format  = ENV['IMAGE_IN_FORMAT']
    @image_out_format = ENV['IMAGE_OUT_FORMAT']

    @logger       = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG

    @file_logger       = Logger.new(ENV['LOG'] + "/converter_#{Time.new.strftime('%y-%m-%d')}.log")

    @file_logger.level = Logger::DEBUG


    @from_s3 = false
    @from_s3 = true if ENV['USE_S3'] == 'true'

    @unique_queue  = ENV['REDIS_UNIQUE_QUEUE']
    @img_convert_queue  = ENV['REDIS_IMG_CONVERT_QUEUE']
    @work_convert_queue = ENV['REDIS_CONVERT_QUEUE']
    @rredis             = Redis.new(
        :host => ENV['REDIS_HOST'],
        :port => ENV['REDIS_EXTERNAL_PORT'].to_i,
        :db   => ENV['REDIS_DB'].to_i)

    @solr = RSolr.connect :url => ENV['SOLR_ADR']

    @s3 = Aws::S3::Client.new(
        :access_key_id     => ENV['S3_AWS_ACCESS_KEY_ID'],
        :secret_access_key => ENV['S3_AWS_SECRET_ACCESS_KEY'],
        :endpoint          => ENV['S3_ENDPOINT'],
        :force_path_style  => true,
        :region            => 'us-west-2')

    @s3_pdf_key_pattern = ENV['S3_PDF_KEY_PATTERN']

    @nlh_bucket = ENV['S3_NLH_BUCKET']
    @gdz_bucket = ENV['S3_GDZ_BUCKET']


    @logger.debug "[converter] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

  end

  def get_s3_key(id)
    return
  end

  def process_response(res)

    begin

      if (res != '' && res != nil)

        # {"id" => key, "context" => context}.to_json
        msg  = res[1]
        json = JSON.parse msg

        context = json['context']
        id = json['document']
        log = json['log']
        log_id = "#{id}___#{log}"

        @s3_bucket = ''

        case context
          when 'nlh'
            @s3_bucket = @nlh_bucket
          when 'gdz'
            @s3_bucket = @gdz_bucket
        end


        unless context == nil

          raise "Unknown context '#{context}', use {gdz | nlh}" unless (context.downcase == "nlh") || (context.downcase == "gdz")

          log_info "Convert work #{log_id}"

          build_jobs(context, id, log, log_id)

        else
          raise "No context specified in request, use {gdz | nlh}"
        end

      else
        raise "Could not process empty string or nil"
      end

    rescue Exception => e
      @logger.error "[converter] Processing problem with '#{res}' \t#{e.message}"
      @file_logger.error "[converter] Processing problem with '#{res}' \t#{e.message}\n\t#{e.backtrace}"
    end

  end

# ---

  def log_error(msg, e)

    unless e == nil
      @logger.error("[converter] #{msg} \t#{e.message}")
      @file_logger.error("[converter] #{msg} \t#{e.message}\n\t#{e.backtrace}")
    else
      @logger.error("[converter] #{msg}")
      @file_logger.error("[converter] #{msg}")
    end

  end


  def log_info(msg)
    @logger.info("[converter] #{msg}")
    @file_logger.info("[converter] #{msg}")
  end

  def log_debug(msg)
    @logger.debug("[converter] #{msg}")
    @file_logger.debug("[converter] #{msg}")
  end

  def removeQueue(queue)
    keys = @rredis.hkeys(queue)
    unless keys.empty?
      @rredis.hdel(queue, keys)
    end
  end


  def pushToQueue(queue, arr)
    @rredis.lpush(queue, arr)
  end

  def s3_object_exist?(id, log)

    s3_key = @s3_pdf_key_pattern % [id, id]
    s3_bucket = @s3_bucket

    resource = Aws::S3::Resource.new(client: @s3)

    exist = resource.bucket(s3_bucket).object(s3_key).exists?

    if exist
      # puts "exist"
      return true
    else
      # puts "does not exist"
      return false
    end

  end


  def build_jobs(context, id, log, log_id)

    request_logical_part = false
    if id == log
      log_id = id
    else
      request_logical_part = true
    end


    solr_resp = @solr.get 'select', :params => {:q => "id:#{id}", :fl => "id doctype"}
    if solr_resp['response']['numFound'] == 0
      log_error "Couldn't find #{id} in index, conversion for #{log_id} not possible", nil
      return
    end

    removeQueue(log_id)

    doctype = solr_resp['response']['docs'].first['doctype']

    if doctype == 'work'


      resp = (@solr.get 'select', :params => {:q => "id:#{id}", :fl => "page   log_id   log_start_page_index   log_end_page_index"})['response']['docs'].first

      log_start_page_index = 0
      log_end_page_index   = -1

      if request_logical_part

        log_id_index = resp['log_id'].index log

        log_start_page_index = (resp['log_start_page_index'][log_id_index])-1
        log_end_page_index   = (resp['log_end_page_index'][log_id_index])-1

      end


      if s3_object_exist?(id, log) # (request_logical_part == true) && s3_object_exist?(id, log)
        # add implementation, cup from full PDF
        pdf_exist = true
      else
        pdf_exist = false
      end

      pages = resp['page'][log_start_page_index..log_end_page_index]
      pages_count = pages.size

      if pdf_exist
        msg = {
            'context'              => context,
            'id'                   => id,
            'log'                  => log,
            "log_id"               => log_id,
            "request_logical_part" => request_logical_part,
            "pages_count" => pages_count,
            "pdf_exist" => pdf_exist
        }
        pushToQueue(@img_convert_queue, [msg.to_json])
      else
        pages.each {|page|
          msg = {
              "context" => context,
              "id" => id,
              "log" => log,
              "log_id" => log_id,
              "request_logical_part" => request_logical_part,
              "page" => page,
              "pages_count" => pages_count,
              "pdf_exist" => pdf_exist
          }
          pushToQueue(@img_convert_queue, [msg.to_json])
        }
      end

      unless request_logical_part
        log_debug "Generate PDF for work #{id}"
      else
        log_debug "Generate PDF for logical part #{log_id} of #{id}"
      end


    else
      log_error "Could not create a PDF for the multivolume work: '#{id}', PDF not created", nil
      @rredis.hdel(@unique_queue, log_id)
    end

  end

end