require 'vertx/vertx'
require 'oai'
require 'logger'
require 'open-uri'
require 'redis'
require 'json'

MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i
context = ENV['CONTEXT']
inpath       = ENV['IN'] + ENV['METS_IN_SUB_PATH']
oai_endpoint = ENV['METS_VIA_OAI']

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/#{context}_path_retrieval_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@logger.debug "[path_retrieve worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)


def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end

def parseId(id)

  id = id.to_s

  begin
    i = id.rindex(':')
    j = id.rindex('|')
    j ||= id.size
    s = id[(i+1)..(j-1)]
    return s
  rescue Exception => e
    @logger.debug("Exception while parse id string: #{id} #{e.message}")
  end

end


$vertx.execute_blocking(lambda { |future|

  catch (:stop) do

    arr = Array.new

    unless oai_endpoint == 'true'

      paths = Dir.glob("#{inpath}/*.xml", File::FNM_CASEFOLD).select { |e| !File.directory? e }
      paths.each { |path|
        arr << {"path" => path}.to_json
      }

      pushToQueue(arr, 'metsindexer')
      pushToQueue(arr, 'metscopier')

    else

      sum      = 0
      client   = OAI::Client.new ENV['GDZ_OAI_ENDPOINT']

      # Get the first page of identifiers
      response = client.list_identifiers(:metadataPrefix => "mets")

      sum += response.count

      arr = Array.new
      response.each do |record|
        identifier = record.identifier
        ppn        = parseId(identifier)
        arr << {"ppn" => ppn}.to_json
      end

      pushToQueue(arr, 'metsindexer')
      pushToQueue(arr, 'metscopier')

      @logger.debug("sum=#{sum}")

      while true do

        attempts = 0

        begin

          arr = Array.new

          response = client.list_identifiers(:resumption_token => response.resumption_token)

          sum += response.count

          @logger.debug("resumption_token: #{response.resumption_token}") if sum > 54000

          response.each do |record|
            next if record == nil

            begin
              next if record.identifier == nil
              identifier = record.identifier
              ppn        = parseId(identifier)
              arr << {"ppn" => ppn}.to_json
            rescue Exception => e
              @logger.debug("Problem to parse identifier: #{e.message}")
            end

          end

        rescue Exception => e
          attempts = attempts + 1
          retry if (attempts < MAX_ATTEMPTS)
          @logger.error("Exception while identifiers retrieval from OAI: (#{Java::JavaLang::Thread.current_thread().get_name()})")
          @file_logger.error "Exception while identifiers retrieval from OAI: (#{Java::JavaLang::Thread.current_thread().get_name()}) \n\t#{e.message}"
        end

        unless arr.empty?
          pushToQueue(arr, 'metsindexer')
          pushToQueue(arr, 'metscopier')
          @logger.debug("sum=#{sum}")
        else
          throw :stop
        end

      end

    end

  end
  # future.complete(doc.to_s)

}) { |res_err, res|
#
}

