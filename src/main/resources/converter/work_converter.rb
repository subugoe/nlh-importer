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

    @file_logger = Logger.new(ENV['LOG'] + "/work_converter_#{Time.new.strftime('%y-%m-%d')}.log", 3, 20 * 1024000)

    @file_logger.level = Logger::DEBUG

    @unique_queue = ENV['REDIS_UNIQUE_QUEUE']

    @img_convert_full_queue = ENV['REDIS_IMG_CONVERT_FULL_QUEUE']
    @img_convert_log_queue  = ENV['REDIS_IMG_CONVERT_LOG_QUEUE']


    @rredis = Redis.new(
        :host               => ENV['REDIS_HOST'],
        :port               => ENV['REDIS_EXTERNAL_PORT'].to_i,
        :db                 => ENV['REDIS_DB'].to_i,
        :reconnect_attempts => 3
    )

    @solr_gdz = RSolr.connect :url => ENV['SOLR_GDZ_ADR']

    @use_s3 = false
    @use_s3 = true if ENV['USE_S3'] == 'true'

    if @use_s3
      @s3 = Aws::S3::Client.new(
          :access_key_id     => ENV['S3_AWS_ACCESS_KEY_ID'],
          :secret_access_key => ENV['S3_AWS_SECRET_ACCESS_KEY'],
          :endpoint          => ENV['S3_ENDPOINT'],
          :force_path_style  => true,
          :region            => 'us-west-2')
    end
    @s3_pdf_key_pattern = ENV['S3_PDF_KEY_PATTERN']

    @nlh_bucket = ENV['S3_NLH_BUCKET']
    @gdz_bucket = ENV['S3_GDZ_BUCKET']

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
        #overwrite = json['overwrite']
        id     = json['document']
        log    = json['log']
        log_id = "#{id}___#{log}"

        @logger.info "[work_converter] Start processing for '#{log_id}'"

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
      @logger.error "[work_converter] Processing problem with '#{res}' \t#{e.message}"
      @file_logger.error "[work_converter] Processing problem with '#{res}' \t#{e.message}"
    end

  end

# ---

  def log_error(msg, e)

    unless e == nil
      @logger.error("[work_converter] #{msg} \t#{e.message}")
      @file_logger.error("[work_converter] #{msg} \t#{e.message}")
    else
      @logger.error("[work_converter] #{msg}")
      @file_logger.error("[work_converter] #{msg}")
    end

  end


  def log_info(msg)
    @logger.info("[work_converter] #{msg}")
    @file_logger.info("[work_converter] #{msg}")
  end

  def log_debug(msg)
    @logger.debug("[work_converter] #{msg}")
    @file_logger.debug("[work_converter] #{msg}")
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

    s3_key    = @s3_pdf_key_pattern % [id, id]
    s3_bucket = @s3_bucket

    resource = Aws::S3::Resource.new(client: @s3)

    exist = resource.bucket(s3_bucket).object(s3_key).exists?

    if exist
      return true
    else
      return false
    end

  end


  def build_jobs(context, id, log, log_id)

    if id == log
      request_logical_part = false
    else
      request_logical_part = true
    end

    solr_resp = @solr_gdz.get 'select', :params => {:q => "id:#{id}", :fl => "id doctype log_id"}
    if (solr_resp['response']['numFound'] == 0) || (request_logical_part && (solr_resp['response']['log_id'] == nil))
      log_error "Couldn't find #{id} in index, conversion for #{log_id} not possible", nil
      return
    end

    removeQueue(log_id)

    doctype = solr_resp['response']['docs'].first['doctype']

    if doctype == 'work'


      resp = (@solr_gdz.get 'select', :params => {:q => "id:#{id}", :fl => "page   log_id   log_start_page_index   log_end_page_index"})['response']['docs'].first

      log_start_page_index = 0
      log_end_page_index   = -1


      if request_logical_part

        log_id_index = resp['log_id'].index log

        if log_id_index == nil
          @logger.error "[work_converter] Log-Id #{log} for work #{id} not found in index"
          @file_logger.error "[work_converter] Log-Id #{log} for work #{id} not found in index"
          return
        end

        log_start_page_index = (resp['log_start_page_index'][log_id_index])-1
        log_end_page_index   = (resp['log_end_page_index'][log_id_index])-1

        if log_end_page_index < log_start_page_index
          log_end_page_index = log_start_page_index
        end

      else
        log_end_page_index = (resp['log_end_page_index'][-1])
      end


      # TODO add if overwrite == true
      # if overwrite == true
      #  pdf_exist = false

      if @use_s3 && s3_object_exist?(id, log) # (request_logical_part == true) && s3_object_exist?(id, log)
        # add implementation, cup from full PDF
        pdf_exist = true
      else
        pdf_exist = false
      end

      pages       = resp['page'][log_start_page_index..log_end_page_index]
      pages_count = pages.size


      if pdf_exist
        msg = {
            'context'              => context,
            'id'                   => id,
            'log'                  => log,
            "log_id"               => log_id,
            "request_logical_part" => request_logical_part,
            "pages_count"          => pages_count,
            "pdf_exist"            => pdf_exist,
            "log_start_page_index" => log_start_page_index,
            "log_end_page_index"   => log_end_page_index
        }

        if request_logical_part
          pushToQueue(@img_convert_log_queue, [msg.to_json])
        else
          pushToQueue(@img_convert_full_queue, [msg.to_json])
        end

      else
        pages.each {|page|
          msg = {
              "context"              => context,
              "id"                   => id,
              "log"                  => log,
              "log_id"               => log_id,
              "request_logical_part" => request_logical_part,
              "page"                 => page,
              "pages_count"          => pages_count,
              "pdf_exist"            => pdf_exist,
              "log_start_page_index" => log_start_page_index,
              "log_end_page_index"   => log_end_page_index
          }

          if request_logical_part
            pushToQueue(@img_convert_log_queue, [msg.to_json])
          else
            pushToQueue(@img_convert_full_queue, [msg.to_json])
          end

        }
      end

      if request_logical_part
        @logger.info "[work_converter] Generate PDF for logical part #{log_id} of #{id}"
      else
        @logger.info "[work_converter] Generate PDF for work #{id}"
      end


    else
      log_error "Could not create a PDF for the multivolume work: '#{id}', PDF not created", nil
      @rredis.hdel(@unique_queue, log_id)
    end

  end

end