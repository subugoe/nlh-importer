require 'vertx/vertx'
#require 'vertx-redis/redis_client'

require 'logger'
require 'gelf'
require 'aws-sdk'
require 'redis'
require 'rsolr'
require 'json'


class WorkConverter

  MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

  def initialize

    @options = {
        'sendTimeout' => 300000
    }

    # productin     = ENV['IN'] + '/' + ENV['PRODUCT']
    # @imageinpath  = productin + ENV['IMAGE_IN_SUB_PATH']
    # @imageoutpath = ENV['OUT'] + ENV['IMAGE_OUT_SUB_PATH']

    @image_in_format  = ENV['IMAGE_IN_FORMAT']
    @image_out_format = ENV['IMAGE_OUT_FORMAT']

    @logger       = GELF::Logger.new(ENV['GRAYLOG_URI'], ENV['GRAYLOG_PORT'].to_i, "WAN", {:facility => ENV['GRAYLOG_FACILITY']})
    @logger.level = ENV['DEBUG_MODE'].to_i

    #@logger       = Logger.new(STDOUT)
    #@logger.level = ENV['DEBUG_MODE'].to_i


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
    @solr_nlh = RSolr.connect :url => ENV['SOLR_NLH_ADR']


    @s3_pdf_key_pattern = ENV['S3_PDF_KEY_PATTERN']

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

        #overwrite = json['overwrite']
        context = json['context']
        product = json['product']
        id      = json['document']
        log     = json['log']
        log_id  = "#{id}___#{log}"

        @logger.debug "[work_converter] Start processing for '#{log_id}'"

        @s3_bucket = ''

        if context.downcase == "gdz"
          @s3_bucket = @gdz_bucket
        elsif context.downcase.start_with?("nlh")
          @s3_bucket = product
        end

        unless context == nil

          raise "Unknown context '#{context}', use {gdz | nlh}" unless (context.downcase.start_with?("nlh")) || (context.downcase == "gdz")

          @logger.debug("[work_converter] Convert work #{log_id}")

          build_jobs(context, product, id, log, log_id)

        else
          raise "No context specified in request, use {gdz | nlh}"
        end

      else
        raise "Could not process empty string or nil"
      end

    rescue Exception => e
      @logger.error "[work_converter] Processing problem with '#{res}' \t#{e.message}\n#{e.backtrace}"
    end

  end

# ---

  def removeQueue(queue)

    keys = @rredis.hkeys(queue)
    unless keys.empty?
      @rredis.hdel(queue, keys)
    end
  end


  def pushToQueue(queue, arr)
    @rredis.lpush(queue, arr)
  end

  def s3_object_exist?(id, object_id, context)

    #s3_key    = @s3_pdf_key_pattern % [id, id]
    s3_key = @s3_pdf_key_pattern % [id, object_id]


    if context.downcase == "gdz"
      access_key_id     = ENV['S3_SUB_AWS_ACCESS_KEY_ID']
      secret_access_key = ENV['S3_SUB_AWS_SECRET_ACCESS_KEY']
      endpoint          = ENV['S3_SUB_ENDPOINT']
      region            = 'us-west-2'
    elsif context.downcase == "digizeit"
      access_key_id     = ENV['S3_DIGIZEIT_AWS_ACCESS_KEY_ID']
      secret_access_key = ENV['S3_DIGIZEIT_AWS_SECRET_ACCESS_KEY']
      endpoint          = ENV['S3_DIGIZEIT_ENDPOINT']
      region            = 'us-west-2'
    elsif context.downcase.start_with?("nlh")
      access_key_id     = ENV['S3_NLH_AWS_ACCESS_KEY_ID']
      secret_access_key = ENV['S3_NLH_AWS_SECRET_ACCESS_KEY']
      endpoint          = ENV['S3_NLH_ENDPOINT']
      region            = 'us-west-2'
    end

    @s3 = Aws::S3::Client.new(
        :access_key_id     => access_key_id,
        :secret_access_key => secret_access_key,
        :endpoint          => endpoint,
        :region            => region,
        :force_path_style  => false)

    res = Aws::S3::Resource.new(client: @s3)
    exist = res.bucket(@s3_bucket).object(s3_key).exists?

    if exist
      return true
    else
      return false
    end

  end


  def build_jobs(context, product, id, log, log_id)

    if id == log
      # if context.downcase.start_with?("nlh")
      #   @logger.error("[work_converter] PDF conversion disabled for the complete work (#{id}___#{log})")
      #   return
      # end
      request_logical_part = false
    else
      request_logical_part = true
    end

    if context.downcase == "gdz"
      solr_resp = @solr_gdz.get 'select', :params => {:q => "id:#{id}", :fl => "id doctype log_id record_identifier"}
    elsif context.downcase.start_with?("nlh")
      solr_resp = @solr_nlh.get 'select', :params => {:q => "id:#{id}", :fl => "id doctype log_id record_identifier work"}
    elsif context.downcase == "digizeit"
      # todo
    end


    if (solr_resp['response']['numFound'] == 0) || (request_logical_part && (solr_resp['response']['docs'].first['log_id'] == nil))
      @logger.error("[work_converter] Couldn't find #{id} in index, conversion for #{log_id} not possible")
      return
    end

    if context.downcase.start_with?("nlh")
      id = solr_resp['response']['docs'].first['work']
    end

    removeQueue(log_id)

    doctype           = solr_resp['response']['docs'].first['doctype']
    record_identifier = solr_resp['response']['docs'].first['record_identifier']

    if doctype == 'work'

      if context.downcase == "gdz"
        resp = (@solr_gdz.get 'select', :params => {:q => "id:#{id}", :fl => "page   log_id   log_start_page_index   log_end_page_index image_format "})['response']['docs'].first
      elsif context.downcase.start_with?("nlh")
        resp = (@solr_nlh.get 'select', :params => {:q => "work:#{id}", :fl => "page   log_id   log_start_page_index   log_end_page_index image_format "})['response']['docs'].first
      elsif context.downcase == "digizeit"
        # todo
      end

      log_start_page_index = 0
      log_end_page_index   = -1

      image_format = resp['image_format']
      #product      = resp['product']

      if request_logical_part

        log_id_index = resp['log_id'].index log

        if log_id_index == nil
          @logger.error "[work_converter] Log-Id #{log} for work #{id} not found in index"
          return
        end

        log_start_page_index = (resp['log_start_page_index'][log_id_index]) - 1
        log_end_page_index   = (resp['log_end_page_index'][log_id_index]) - 1

        if log_end_page_index < log_start_page_index
          log_end_page_index = log_start_page_index
        end

        #else
        #  log_end_page_index = (resp['log_end_page_index'][-1]) if resp['log_end_page_index'] != nil
      end

      #if !context.downcase.start_with?("nlh") && s3_object_exist?(id, id, context)
      if s3_object_exist?(id, id, context)
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
            'record_identifier'    => record_identifier,
            'log'                  => log,
            "log_id"               => log_id,
            "request_logical_part" => request_logical_part,
            "pages_count"          => pages_count,
            "pdf_exist"            => pdf_exist,
            "log_start_page_index" => log_start_page_index,
            "log_end_page_index"   => log_end_page_index,
            "image_format"         => image_format,
            "product"              => product
        }

        if request_logical_part
          pushToQueue(@img_convert_log_queue, [msg.to_json])
        else
          pushToQueue(@img_convert_full_queue, [msg.to_json])
        end

      else
        pages.each { |page|
          msg = {
              "context"              => context,
              "id"                   => id,
              "log"                  => log,
              "log_id"               => log_id,
              "record_identifier"    => record_identifier,
              "request_logical_part" => request_logical_part,
              "page"                 => page,
              "pages_count"          => pages_count,
              "pdf_exist"            => pdf_exist,
              "log_start_page_index" => log_start_page_index,
              "log_end_page_index"   => log_end_page_index,
              "image_format"         => image_format,
              "product"              => product
          }

          if request_logical_part
            pushToQueue(@img_convert_log_queue, [msg.to_json])
          else
            pushToQueue(@img_convert_full_queue, [msg.to_json])
          end

        }
      end

      if request_logical_part
        @logger.debug "[work_converter] Start Part PDF creation #{id}"
      else
        @logger.debug "[work_converter] Start Full PDF creation #{id}"
      end


    else
      @logger.error("[work_converter] Could not create PDF for multivolume work '#{id}', PDF not created")
      @rredis.hdel(@unique_queue, log_id)
    end

  end

end