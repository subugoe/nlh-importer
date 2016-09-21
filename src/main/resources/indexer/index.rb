require 'vertx/vertx'
require 'vertx-redis/redis_client'

#require 'rsolr'
require 'elasticsearch'
require 'logger'
#require 'open-uri'
#require 'uri'
#require 'net/http'
#require 'nokogiri'
#require 'redis'
require 'json'


logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
redis_config = {
    'host' => ENV['REDIS_HOST'],
    'port' => ENV['REDIS_PORT'].to_i
}
#redis        = VertxRedis::RedisClient.create($vertx, redis_config)
redis        = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_PORT'])

#solr         = RSolr.connect :url => ENV['SOLR_ADR']
#sub_gdz_solr = RSolr.connect :url => ENV['SUB_GDZ_SOLR_ADR']

logger.debug "[index worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def readFromElast(ppn, object_uri, redis, solr, sub_gdz_solr, logger)


  response = sub_gdz_solr.get 'select', :params => {:q => "pid:#{ppn}"}

  if response['response']['numFound']==0
    redis.lpush("noResultSetFor", "#{ppn}")
    logger.debug("Exception, no results for #{ppn} in solr")
    return
  end

  # todo check required fields pid, logid, ...
  #arr_solr = Array.new

  response["response"]['docs'].each { |doc|
    hsh = Hash.new
    doc.each { |k, v|


      unless (k=='id' || k=='_version_' || k=='min_url' || k=='thumbs_url' \
      || k=='max_url' || k=='default_url' || k=='presentation_url')
        h = {k => v}
        hsh.merge!(h)
      end

      if k=='presentation_url'
        v_new = modifyUrisInArray(v, object_uri)


        h = {"object_uri" => object_uri, "orig_image_uri_array" => v, "new_image_uri_array" => v_new, "retries" => 0}

        redis.lpush("object_to_import", h.to_json)

        h = {k => v_new}
        hsh.merge!(h)
=begin
      $vertx.execute_blocking(lambda { |future|
        addImagesToFedora(v)
        #future.complete(doc)
      }) { |res_err, res|
        # res
      }
=end
=begin
      else

        arr_solr << hsh
=end
      end


    }

    #arr_solr << hsh

    # todo possibly call addDocsToSolr here
    #}


    addDocsToSolr([hsh], solr)

=begin
    $vertx.execute_blocking(lambda { |future|
      addDocsToSolr(arr_solr, solr)
      #future.complete(doc)
    }) { |res_err, res|
      # res
    }
=end


  }


end

def parseId(id)

  # http://gdz.sub.uni-goettingen.de/tiff/HANS_DE_7_w44876/00000046.tif"
  # >>> /tiff/HANS_DE_7_w44876/00000046.tif"
  id = id.to_s

  begin
    i = id.rindex('/tiff')
    raise "expected subpath '/tiff' missing" if i == nil
    j = id.size
    s = id[(i+1)..(j-1)]
    return s
  rescue Exception => e
    logger.error ("Exception with uri #{id} #{e.message}")
  end

end


def modifyUrisInArray(images, object_uri)

  # http://gdz.sub.uni-goettingen.de/tiff/HANS_DE_7_w44876/00000046.tif"

  arr = images.collect { |uri|
    switchToFedoraUri uri, object_uri
  }

  return arr
end

def switchToFedoraUri uri, object_uri
  "#{object_uri}/images/#{parseId(uri)}"
end


def addDocsToSolr(documents, solr)

  begin
    solr.add documents
    solr.commit
  rescue Exception => e
    # ...
  end

end


$vertx.execute_blocking(lambda { |future|

  catch (:stop) do

    # todo remove counter
    i = 0


    while true do

      throw :stop if i==499


      begin

        obj = redis.brpop("ppn_to_index", :timeout => nil)[1]


        json = JSON.parse(obj)


        ppn = json["ppn"]


        object_uri = json["object_uri"]


        readFromSolr(ppn, object_uri, redis, solr, sub_gdz_solr, logger)

      rescue Exception => e
        logger.debug("Exception in index.rb: #{ppn} - #{e.message}") # "- #{e.backtrace.join('\n\t')}")
        throw :stop
      end


      i +=1

    end

  end

#future.complete(doc.to_s)

}) { |res_err, res|
  #
}

=begin
def parseSolrDoc(doc, redis, logger)

  documents = Array.new # [{:id=>1, :price=>1.00}, {:id=>2, :price=>10.50}]


  incr("mets_sum", redis, logger)

  ocrs = doc.xpath("//mets:fileGrp[@USE='GDZOCR']//mets:file", 'mets' => 'http://www.loc.gov/METS/')
  incrby("ocr_sum", ocrs.size, redis) if ocrs != nil

  logicalDivs = doc.xpath("//mets:structMap[@TYPE='LOGICAL']//mets:div", 'mets' => 'http://www.loc.gov/METS/')
  incrby("logical_sum", logicalDivs.size, redis) if logicalDivs != nil

  tiffs = doc.xpath("//mets:fileGrp[@USE='PRESENTATION']//mets:file", 'mets' => 'http://www.loc.gov/METS/')
  incrby("tiff_sum", tiffs.size, redis) if tiffs != nil

end

def incrby(queue, value, redis)
  redis.incrby(queue, value)
end

def incr(queue, redis, logger)
  count = redis.incr(queue)
  logger.debug("#{count} doc's processed") if count%1000 == 0
end


def metsUri(ppn)
  return "http://gdz.sub.uni-goettingen.de/mets/#{ppn}.xml"
end
=end

