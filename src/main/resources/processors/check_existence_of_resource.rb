require 'vertx/vertx'
require 'oai'
require 'logger'
require 'open-uri'
require 'redis'
require 'json'
require 'rsolr'

# prepare config: 1 instance, 6GB importer, 4GB redis, 6GB solr
# process config: 20 instances, 10GB importer, 5GB redis, 1GB solr

MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i
#outpath  = ENV['IN'] + ENV['METS_IN_SUB_PATH']
outpath      = ENV['OUT']
#metspath  = outpath + ENV['METS_OUT_SUB_PATH']
imagepath    = outpath + ENV['IMAGE_OUT_SUB_PATH']
teipath      = outpath + ENV['TEI_OUT_SUB_PATH']
pdfpath      = outpath + ENV['PDF_OUT_SUB_PATH']
logpath      = ENV['LOG']
redishost    = ENV['REDIS_HOST']
redisport    = ENV['REDIS_EXTERNAL_PORT']
redisdb      = ENV['REDIS_DB']
solradr      = ENV['SOLR_ADR']

#solr_fq = ENV['SOLR_FQ']
context      = ENV['CONTEXT']
prepare      = ENV['REPARE']


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(logpath + "/#{context}_check_existence_of_resource_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@rredis = Redis.new(:host => redishost, :port => redisport.to_i, :db => redisdb.to_i)
@solr   = RSolr.connect :url => solradr

@logger.debug "[check_existence_of_resource.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

redisQueues = ['check_path_nofulltext', 'check_path_fulltext']


def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end

def check res
  attempts = 0
  begin

    if (res != '' && res != nil)

      json = JSON.parse(res[1])

      path = json['path']

      if File.exist? (path)
        if (File.size (path)) > 0
          @logger.info "File exists"
        else
          @logger.error "File #{path} is empty"
        end
      else
        @logger.error "File #{path} doesn't exist"
      end

    end
  rescue Exception => e
    attempts = attempts + 1
    retry if (attempts < MAX_ATTEMPTS)
    @logger.error "Could not process redis data '#{res[1]}' (#{e.message})"
    @file_logger.error "Could not process redis data '#{res[1]}'  \t#{e.message}\n\t#{e.backtrace}"
  end
end




$vertx.execute_blocking(lambda { |future|

  while true
    res = @rredis.brpop(redisQueues[0])
    check res
  end

  # future.complete(doc.to_s)

}) { |res_err, res|
  #
}

$vertx.execute_blocking(lambda { |future|

  while true
    res = @rredis.brpop(redisQueues[1])
    check res
  end

  # future.complete(doc.to_s)

}) { |res_err, res|
  #
}
