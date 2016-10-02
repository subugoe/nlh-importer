require 'vertx/vertx'

require 'logger'
require 'redis'
require 'json'
require 'digest'




@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i)

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new('nlh_fixity.log')
@file_logger.level = Logger::DEBUG

MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i


#----------------


@logger.debug "[fixity_checker worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def checkfixity(to, fixity)
  return fixity == (Digest::MD5.file to).hexdigest
end


# def push_many(queue, arr)
#
#   @redis.lpush_many(queue, arr) { |res_err, res|
#
#     if res_err != nil
#       @logger.error("Error: '#{res_err}'")
#     else
#       @logger.info "Pushed #{arr.size} URIs to redis (#{queue})"
#     end
#   }
#
# end

$vertx.execute_blocking(lambda { |future|

  seconds = 20

  catch (:stop) do

    while true do

      begin

        # "fixitychecker", [{'from' => from, 'to' => to, 'fixity' => fixity}]

        #@redis.brpop("paths1", 20) { |res_err, res|

        res = @rredis.brpop("fixitychecker")

        #@logger.debug "check_fixity: processing...  '#{res}'"

        if (res != '' && res != nil)

          json   = JSON.parse res[1]
          from   = json['from']
          to     = json['to']
          fixity = json['fixity']


          unless checkfixity(to, fixity)
            @file_logger.error "Fixity mismatch - from: #{from} to: #{to}"
          else
            # ok
          end

          seconds = seconds / 2 if seconds > 20

        else
          @logger.error "Get empty string or nil from redis"
          sleep seconds
          seconds = seconds * 2 if seconds < 300
        end

      rescue Exception => e
        @logger.error("Error: #{e.message}- #{e.backtrace.join('\n\t')}")
        throw :stop
      end



      @rredis.incr 'fixitieschecked'

    end
  end

  # future.complete(doc.to_s)

}) { |res_err, res|
#
}