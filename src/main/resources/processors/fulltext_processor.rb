require 'vertx/vertx'
require 'vertx-redis/redis_client'

require 'rsolr'
#require 'elasticsearch'
require 'logger'
require 'nokogiri'
require 'redis'
require 'json'
require 'lib/mets_mods_metadata'
require 'fileutils'


redis_config = {
    'host' => ENV['REDIS_HOST'],
    'port' => ENV['REDIS_EXTERNAL_PORT'].to_i
}


@redis       = VertxRedis::RedisClient.create($vertx, redis_config)


@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i)
@solr        = RSolr.connect :url => ENV['SOLR_ADR']

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new('nlh_fileNotFound.log')
@file_logger.level = Logger::DEBUG

MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i


@inpath  = ENV['IN'] + ENV['TEI_IN_SUB_PATH']
@outpath = ENV['OUT'] + ENV['TEI_OUT_SUB_PATH']

#----------------


@logger.debug "[fulltext_processor worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


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
    @file_logger.error "Could not copy from: '#{from}' to: '#{to}'\n\t#{e.message}"
  end

  return to

end


def addDocsToSolr(document)

  begin
    @solr.add [document]
    @solr.commit

    @rredis.incr 'fulltextsindexed'
  rescue Exception => e
    @logger.debug document
    @logger.error("Could not add fulltext child doc to solr\n\t#{e.message}\n\t#{e.backtrace}")
  end

end


def getFulltext(path)

  attempts = 0
  fulltext = ""

  begin
    fulltext = File.open(path) { |f|
      Nokogiri::XML(f) { |config|
        #config.noblanks
      }

    }
  rescue Exception => e
    @logger.warn("Problem to open file #{path}")
    attempts = attempts + 1
    retry if (attempts < MAX_ATTEMPTS)
    @logger.error("Could not open file #{path} #{e.message}")
    return
  end

  return fulltext.root.text.gsub(/\s+/, " ").strip

end

# index, calculate hash, copy to storage, check


$vertx.execute_blocking(lambda { |future|

  i = 0
  while true do

    res = @rredis.brpop("processFulltextURI")

    if (res != '' && res != nil)

      json = JSON.parse res[1]

      match    = json['fulltexturi'].match(/(\S*)\/(\S*):(\S*):(\S*).(xml)/)
      product  = match[2]
      work     = match[3]
      file     = match[4]
      filename = match[4] + '.' + match[5]

      from     = "#{@inpath}/#{work}/#{filename}"
      to       = "#{@outpath}/#{product}/#{work}/#{filename}"
      to_dir   = "#{@outpath}/#{product}/#{work}"

      fulltext     = getFulltext(from)

      id_parentdoc = json['id_parentdoc']
      imageindex   = json['imageindex']
      doctype      = json['doctype']
      context      = json['context']

      h = Hash.new
      h.merge! ({
          :pid          => product + '_' + work + '_' + file,
          :id_parentdoc => id_parentdoc,
          :image_index  => imageindex,
          :doctype      => doctype,
          :context      => context,
          :fulltext     => fulltext
      })

      addDocsToSolr(h)
      copyFile(from, to, to_dir)

      i += 1
    else
      @logger.error "Get empty string or nil from redis"
      sleep 20
    end

  end

  # future.complete(doc.to_s)

}) { |res_err, res|
  #
}



