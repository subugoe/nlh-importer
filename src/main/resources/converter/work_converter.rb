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
        id      = json['id']

        @s3_bucket = ''

        case context
          when 'nlh'
            @s3_bucket = @nlh_bucket
          when 'gdz'
            @s3_bucket = @gdz_bucket
        end


        unless context == nil

          raise "Unknown context '#{context}', use {gdz | nlh}" unless (context.downcase == "nlh") || (context.downcase == "gdz")

          log_info "Convert work id=#{id}"

          build_jobs(id, context)

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


  def build_jobs(id, context)

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

    solr_resp = @solr.get 'select', :params => {:q => "id:#{work}", :fl => "id doctype"}
    if solr_resp['response']['numFound'] == 0
      log_error "Work: '#{work}' for id: '#{id}' could not be found in index, conversion not possible", nil
      return
    end

    removeQueue(id)

    doctype = solr_resp['response']['docs'].first['doctype']

    if doctype == 'work'

      resp = (@solr.get 'select', :params => {:q => "id:#{work}", :fl => "page log_id log_start_page_index log_end_page_index"})['response']['docs'].first

      log_start_page_index = 0
      log_end_page_index   = -1

      if request_logical_part

        log_id_index = resp['log_id'].index log_id

        log_start_page_index = (resp['log_start_page_index'][log_id_index])-1
        log_end_page_index   = (resp['log_end_page_index'][log_id_index])-1

      end

      pages       = resp['page'][log_start_page_index..log_end_page_index]
      pages_count = pages.size

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


        #$vertx.event_bus().send("image.load", msg.to_json, @options)

        pushToQueue(@img_convert_queue, [msg.to_json])

      }

      unless request_logical_part
        log_debug "Generate PDF for work #{work}"
      else
        log_debug "Generate PDF for logical part #{log_id} of #{work}"
      end


    else
      log_error "Could not create a PDF for the multivolume work: '#{work}', PDF not created", nil
      @rredis.hdel(@unique_queue, id)
    end

  end

end