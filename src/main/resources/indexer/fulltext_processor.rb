require 'vertx/vertx'
require 'rsolr'
require 'logger'
require 'gelf'
require 'rsolr'
require 'nokogiri'
require 'redis'
require 'json'
require 'fileutils'
require 'model/mets_mods_metadata'

context = ENV['CONTEXT']
MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

productin   = ENV['IN'] + '/' + ENV['PRODUCT']
@inpath  = productin + ENV['TEI_IN_SUB_PATH']
@outpath = ENV['OUT'] + ENV['TEI_OUT_SUB_PATH']

@rredis = Redis.new(
    :host            => ENV['REDIS_HOST'],
    :port            => ENV['REDIS_EXTERNAL_PORT'].to_i,
    :db              => ENV['REDIS_DB'].to_i,
    :reconnect_attempts => 3
)

@logger       = GELF::Logger.new(ENV['GRAYLOG_URI'], ENV['GRAYLOG_PORT'].to_i, "WAN", {:facility => ENV['GRAYLOG_FACILITY']})
@logger.level = ENV['DEBUG_MODE'].to_i


@logger.debug "[fulltext_processor worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

def pushToQueue(queue, hsh)
  @rredis.lpush(queue, hsh.to_json)
end


def copyFile(from, to, to_dir)

  begin
    FileUtils.mkdir_p(to_dir)
    FileUtils.cp(from, to)

    fixity = (Digest::MD5.file from).hexdigest

    hsh = Hash.new
    hsh.merge!({"from" => from})
    hsh.merge!({"to" => to})
    hsh.merge!({"fixity" => fixity})

    pushToQueue("fixitychecker", hsh)


    @rredis.incr 'fulltextscopied'
  rescue Exception => e
    @logger.error "Could not copy fulltext from: '#{from}' to: '#{to}'\n\t#{e.message}"
  end

  return to

end



# index, calculate hash, copy to storage, check


$vertx.execute_blocking(lambda { |future|

  while true do

    res = @rredis.brpop("processFulltextURI")

    if (res != '' && res != nil)

      json   = JSON.parse res[1]

      # arr << {"fulltexturi" => fulltexturi, "to" => to, "to_dir" => to_dir}.to_json
      from   = json['from']
      to     = json['to']
      to_dir = json['to_dir']

      copyFile(from, to, to_dir)

    else
      @logger.error "Get empty string or nil from redis"
      sleep 20
    end

  end

  # future.complete(doc.to_s)

}) { |res_err, res|
  #
}



