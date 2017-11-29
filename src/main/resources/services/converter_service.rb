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

    @file_logger       = Logger.new(ENV['LOG'] + "/converter_service_verticle_#{Time.new.strftime('%y-%m-%d')}.log")
    @file_logger.level = Logger::DEBUG

    @work_queue   = ENV['REDIS_WORK_CONVERT_QUEUE']
    @unique_queue = ENV['REDIS_UNIQUE_QUEUE']
    @rredis       = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)

    @solr_gdz         = RSolr.connect :url => ENV['SOLR_GDZ_ADR']

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
        @file_logger.error("[converter_service]  Expected JSON body missing")

        # TODO check response codes

        send_status(400, response, {"status" => "-1", "msg" => "Requst body missing"})

      else

        id                   = hsh['document']
        log                  = hsh['log']
        context              = hsh['context']
        log_id               = "#{id}___#{log}"
        request_logical_part = (id != log)


        if (id == nil) || (log == nil) || (context == nil)
          puts "parameters missed"
          send_status(400, response, {"status" => "-1", "msg" => "Required parameters missed (document, log, context)"})
          return
        else

          resp = (@solr_gdz.get 'select', :params => {:q => "id:#{id}", :fl => "page   log_id   log_start_page_index   log_end_page_index doctype"})['response']

          doc = resp['docs']&.first

          if resp['numFound'] == 0
            puts "No index entry"
            send_status(400, response, {"status" => "-1", "msg" => "No index entry for #{id}, job not staged"})
            return

          elsif resp['docs']&.first['doctype'] != 'work'
            puts "wrong doctype"
            send_status(400, response, {"status" => "-1", "msg" => "No conversion of doctype != 'work'"})
            return
          else

            already_in_queue = @rredis.hget(@unique_queue, log_id)

            if already_in_queue != nil
              puts "already started"
              @logger.debug "[converter_service] Job for #{log_id} already started, process next"

              # conversion error
              if @rredis.hget(log_id, 'err') != nil
                puts "conversion errors"
                @logger.error("[converter_service] Errors in queue #{log_id}, job not staged")
                @file_logger.error("[converter_service] Errors in queue #{log_id}, job not staged")

                send_status(400, response, {"status" => "-1", "msg" => "Conversion errors"})
                return

              else

                if request_logical_part

                  puts "request log part"
                  log_id_index = resp['docs']&.first['log_id'].index log

                  log_start_page_index = (resp['docs']&.first['log_start_page_index'][log_id_index])-1
                  log_end_page_index   = (resp['docs']&.first['log_end_page_index'][log_id_index])-1

                  size = log_end_page_index.to_i - log_start_page_index.to_i

                else
                  puts "request full pdf"
                  size = resp['docs']&.first['page'].size
                end

                keys = @rredis.hkeys(log_id)

                to_process = keys.size # -1, since the field "0" is not related to a real page, it sets a lock on the id

                i = to_process * 100 / size

                puts "converted: #{to_process}, should: #{size}, percentage: #{i}"

                if i <= 0
                  puts "staged"
                  send_status(200, response, {"status" => i, "msg" => "staged"})
                  return
                elsif i > 0 && i < 100
                  puts "percentage"
                  send_status(200, response, {"status" => i, "msg" => "processing"})
                  return
                elsif i >= 100
                  puts "finished"
                  send_status(200, response, {"status" => i, "msg" => "finished"})
                  return
                end
              end


            else
              @rredis.hset(@unique_queue, log_id, 0)
              pushToQueue(@work_queue, [hsh.to_json])
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
      @file_logger.error("[converter_service] Problem with request body \t#{e.message}\n\t#{e.backtrace}")

      # any error
      puts "not processed"
      send_status(400, response, {"status" => "-1", "msg" => "Could not process request"})
      return
    end

  end

end