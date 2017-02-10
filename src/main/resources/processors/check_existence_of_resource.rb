require 'vertx/vertx'
require 'oai'
require 'logger'
require 'open-uri'
require 'redis'
require 'json'
require 'rsolr'


# prepare config: 1 instance, 5GB importer, 4GB redis, 7GB solr
# process config: 20 instances, 5GB importer, 4GB redis, 7GB solr


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

context      = ENV['CONTEXT']


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(logpath + "/#{context}_check_existence_of_resource_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@rredis = Redis.new(:host => redishost, :port => redisport.to_i, :db => redisdb.to_i)
@solr   = RSolr.connect :url => solradr

@logger.debug "[check_existence_of_resource.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


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
        unless (File.size (path)) > 0
          @logger.error "File #{path} is empty"
          @file_logger.error "File #{path} is empty"
        end
      else
        @logger.error "File #{path} doesn't exist"
        @file_logger.error "File #{path} doesn't exist"
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


  while (len = @rredis.llen 'check_path_without_fulltext') != 0
    res = @rredis.brpop('check_path_without_fulltext')
    check res
  end

  while (len = @rredis.llen 'check_path_with_fulltext') != 0
    res = @rredis.brpop('check_path_with_fulltext')
    check res
  end


  # future.complete(doc.to_s)

}) { |res_err, res|
  #
}

