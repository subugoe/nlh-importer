require 'vertx/vertx'
require 'vertx-web/router'
require 'vertx-web/body_handler'

require 'json'
require 'redis'
require 'logger'
require 'rsolr'

class ConverterService


  def initialize

    @logger       = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG

    @file_logger       = Logger.new(ENV['LOG'] + "/converter_service_verticle_#{Time.new.strftime('%y-%m-%d')}.log", 3, 1024000)
    @file_logger.level = Logger::DEBUG

    @work_queue   = ENV['REDIS_WORK_CONVERT_QUEUE']
    @unique_queue = ENV['REDIS_UNIQUE_QUEUE']

    @rredis       = Redis.new(
        :host               => ENV['REDIS_HOST'],
        :port               => ENV['REDIS_EXTERNAL_PORT'].to_i,
        :db                 => ENV['REDIS_DB'].to_i,
        :reconnect_attempts => 3
    )

    @solr_gdz = RSolr.connect :url => ENV['SOLR_GDZ_ADR']

    @logger.debug "[converter_service] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

  end

  def pushToQueue(queue, arr)
    @rredis.lpush(queue, arr)
  end

  def send_status(status_code, response, msg_hsh)
    response.set_status_code(status_code).end(msg_hsh.to_json)
  end


  def process_response(hsh, response)

    begin

      if hsh == nil
        @logger.error("[converter_service] Expected JSON body missing")

        # TODO check response codes

        send_status(400, response, {"status" => "-1", "msg" => "Requst body missing"})

      else

        id                   = hsh['document']
        log                  = hsh['log']
        context              = hsh['context']
        log_id               = "#{id}___#{log}"
        request_logical_part = (id != log)


        if (id == nil) || (log == nil) || (context == nil)
          @logger.error "[converter_service] Required parameters (document, log, context) missed"
          send_status(400, response, {"status" => "-1", "msg" => "Required parameters (document, log, context) missed"})
          return
        else

          resp = (@solr_gdz.get 'select', :params => {:q => "id:#{id}", :fl => "page   log_id   log_start_page_index   log_end_page_index doctype"})['response']

          doc = resp['docs']&.first


          if (resp['response']['numFound'] == 0) || (request_logical_part && (doc['log_id'] == nil))
            @logger.error "[converter_service] No index entry found for #{log_id}, job not staged"
            send_status(400, response, {"status" => "-1", "msg" => "No index entry found for #{log_id}, job not staged"})
            return

          elsif doc['doctype'] != 'work'
            @logger.error "[converter_service] No conversion defined for doctype (#{doc['doctype']}) of #{id}, job not staged"
            send_status(400, response, {"status" => "-1", "msg" => "No conversion defined for doctype (#{doc['doctype']}) of #{id}, job not staged"})
            return
          else

            already_in_queue = @rredis.hget(@unique_queue, log_id)


            if already_in_queue != nil

              # conversion error
              if @rredis.hget(log_id, 'err') != nil
                @logger.error("[converter_service] Errors in queue #{log_id}, job not staged")
                @file_logger.error("[converter_service] Errors in queue #{log_id}, job not staged")
                send_status(400, response, {"status" => "-1", "msg" => "Conversion errors"})
                return
              else

                if request_logical_part
                  log_id_index = resp['docs']&.first['log_id'].index log

                  if log_id_index == nil
                    send_status(400, response, {"status" => "-1", "msg" => "Log-Id #{log} not found in index"})
                    return
                  end

                  log_start_page_index = (resp['docs']&.first['log_start_page_index'][log_id_index])-1
                  log_end_page_index   = (resp['docs']&.first['log_end_page_index'][log_id_index])-1

                  if log_start_page_index == log_end_page_index
                    size = 1
                  elsif log_end_page_index < log_start_page_index
                    log_end_page_index = log_start_page_index
                    size               = 1
                  else
                    size = log_end_page_index.to_i - log_start_page_index.to_i
                  end

                else
                  size = resp['docs']&.first['page'].size
                end

                keys       = @rredis.hkeys(log_id)
                to_process = keys.size
                i          = to_process * 100 / size

                if i <= 0
                  @logger.info "[converter_service] Processing for #{log_id} has started"
                  send_status(200, response, {"status" => i, "msg" => "staged"})
                  return
                elsif i > 0 && i < 100
                  @logger.info "[converter_service] Processing for #{log_id} in work (#{i}% done)"
                  send_status(200, response, {"status" => i, "msg" => "processing"})
                  return
                elsif i >= 100
                  @logger.info "[converter_service] Processing for #{log_id} has finished"
                  send_status(200, response, {"status" => i, "msg" => "finished"})
                  return
                end
              end

            else

              if @rredis.hset(@unique_queue, log_id, 0) == 0
                @logger.info "[converter_service] Work #{log_id} already instaged"
                send_status(200, response, {"status" => 0, "msg" => "staged"})
                return
              end

              pushToQueue(@work_queue, [hsh.to_json])

              @logger.info "[converter_service] Work #{log_id} staged for conversion"
              send_status(200, response, {"status" => 0, "msg" => "Work #{log_id} staged for conversion"})
              return
            end
          end
        end
      end

      @logger.info "[converter_service] Conversion started"
      send_error(200, response)
      return

    rescue Exception => e
      @logger.error("[converter_service] Problem with request body \t#{e.message}")
      @file_logger.error("[converter_service] Problem with request body \t#{e.message}")

      # any error
      send_status(400, response, {"status" => "-1", "msg" => "Problem with request body"})
      return
    end

  end

end