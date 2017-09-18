require 'vertx-web/router'
require 'vertx-web/body_handler'

require 'rsolr'
require 'json'
require 'redis'
require 'logger'
require 'oai'
require 'open-uri'
#require 'fog'
require 'aws-sdk'


MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i
oai_endpoint = ENV['GDZ_OAI_ENDPOINT']
productin    = ENV['IN'] + '/' + ENV['PRODUCT']
@inpath      = productin + ENV['METS_IN_SUB_PATH']
@queue       = ENV['REDIS_INDEX_QUEUE']


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/reindex_service_verticle_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@rredis     = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)
@oai_client = OAI::Client.new oai_endpoint

@gdzsolr = RSolr.connect :url => ENV['GDZ_SOLR_ADR']

# todo comment in
@s3_client = Aws::S3::Client.new(
    :access_key_id     => ENV['S3_AWS_ACCESS_KEY_ID'],
    :secret_access_key => ENV['S3_AWS_SECRET_ACCESS_KEY'],
    :endpoint          => ENV['S3_ENDPOINT'],
    :force_path_style  => true,
    :region            => 'us-west-2')

@nlh_bucket = ENV['S3_NLH_BUCKET']
@gdz_bucket = ENV['S3_GDZ_BUCKET']

# ---

@logger.debug "[reindex_service] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def get_s3_mets_keys directory

  # for test
  # returns just 1000 keys (the first page of results - by default, 10k)
  #@s3.directories.get(directory, prefix: 'mets/').files.map {|file| file.key}

  # returns just all keys
  #keys = Array.new
  #@s3.directories.get(directory, prefix: 'mets/').files.each {|file| keys << file.key}
  #return keys

end

def pushToQueue(queue, arr)
  @rredis.lpush(queue, arr)
end


def send_error(status_code, response)
  response.set_status_code(status_code).end
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
    @logger.debug("[reindex_service] Exception while parse id string: #{id} #{e.message}")
  end

end

def process_keys keys, context

  puts "keys.size: #{keys.size}"

  arr = Array.new
  keys.each {|key|
    arr << {"s3_key" => key, "context" => context}.to_json
  }

  pushToQueue(@queue, arr)
end

# --- ---


def reindex(context)

  #puts "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"

  @rredis.del @queue

  bucket = ''

  case context
    when "nlh"
      bucket = @nlh_bucket
    when "gdz"
      bucket = @gdz_bucket
  end


  i = 0
  begin

    # todo comment in
    response = @s3_client.list_objects(bucket: bucket, prefix: 'mets')

    keys = response.contents.map(&:key)
    process_keys keys, context

    i += keys.size

=begin
      while response.next_page? do
        response = response.next_page
        keys =  response.contents.map(&:key)
        process_keys keys, context
        i += keys.size
      end
=end

  rescue Exception => e
    puts "e.message: #{e.message}\n\te.backtrace: #{e.backtrace}"
  end

  @logger.debug("[reindex_service] sum=#{i}")

end

# --- routes ---


router = VertxWeb::Router.router($vertx)
router.route().handler(&VertxWeb::BodyHandler.create().method(:handle))


# POST http://127.0.0.1:8080   /api/reindexer/jobs
# {"s3_key": "mets/PPN129323659_0031.xml" , "context": "gdz"}
router.post("/api/reindexer/jobs").blocking_handler(lambda {|routingContext|

  begin
    hsh = routingContext.get_body_as_json

    if hsh == nil
      @logger.error("[reindex_service] Expected JSON body missing")
      @file_logger.error("[reindex_service]  Expected JSON body missing")
      send_error(400, response)
    else

      @logger.info("[reindex_service] Got message: \t#{hsh}")

      json = JSON.parse hsh.to_json

      context = json['context']


      if (context != nil) && (context.downcase == "gdz")
        reindex "gdz"

      elsif (context != nil) && (context.downcase == "nlh")
        reindex ":nlh"

      else
        @logger.error "[reindex_service] Could not process context '#{context}',\t(#{Java::JavaLang::Thread.current_thread().get_name()})"
        send_error(400, response)
      end

    end

  rescue Exception => e
    @logger.error("[reindex_service] Problem with request body \t#{e.message}\n\t#{e.backtrace}")
    @file_logger.error("[reindex_service] Problem with request body \t#{e.message}")
  end

  routingContext.response.end

}, false)


# GET http://127.0.0.1:8080   /api/reindexer/status
router.get("/api/reindexer/status").blocking_handler(lambda {|routingContext|

  size = @rredis.llen(@queue)
  routingContext.response.put_header("content-type", "application/json").end(JSON.generate({'size' => size}))

}, false)


$vertx.create_http_server.request_handler(&router.method(:accept)).listen 8080