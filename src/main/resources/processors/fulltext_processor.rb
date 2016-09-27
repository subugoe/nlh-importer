require 'vertx/vertx'
require 'vertx-redis/redis_client'

require 'rsolr'
#require 'elasticsearch'
require 'logger'
require 'nokogiri'
#require 'redis'
require 'json'
require 'mets_mods_metadata'


redis_config  = {
    'host' => ENV['REDIS_HOST'],
    'port' => ENV['REDIS_EXTERNAL_PORT'].to_i
}
@redis = VertxRedis::RedisClient.create($vertx, redis_config)
@solr  = RSolr.connect :url => ENV['SOLR_ADR']

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

MAX_ATTEMPTS  = ENV['MAX_ATTEMPTS'].to_i

@logger.debug "[index worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def addDocsToSolr(document)

  #document.merge!({:pid => srand, :logid => srand})


  @logger.debug "document: #{document}"
  #@logger.debug "document.class: #{document.class}"

  #return

  begin
    @solr.add [document]
    @solr.commit
  rescue Exception => e
    @logger.error("Could not add doc to solr\n\t#{e.message}\n\t#{e.backtrace.join('\n\t')}")
  end

end



# index, calculate hash, copy to storage, check


# arr << {"fulltexturi" => fulltexturi, "id_parent_doc" => id_parent_doc, "imageindex" => imageindex, "doctype" => doctype, "context" => context}.to_json
#-> "{\"fulltexturiuri\":\"http://nl.sub.uni-goettingen.de/tei/eai1:0F7D2C6057409748:0F7CC9AE5FE9BD20.xml\",\"parent\":\"aas03037038\",\"index\":\"\",\"doctype\":\"fulltext\",\"context\":\"nhl\"}"



@redis.brpop("processFulltextURI", 30) { |res_err, res|
  if res_err == nil
    json             = JSON.parse res[1]
    puts json['fulltexturi']
    puts json['id_parentdoc']
    puts json['imageindex']
    puts json['doctype']
    puts json['context']
    puts "fulltext"

    #addDocsToSolr(metsModsMetadata.to_solr_string) if metsModsMetadata != nil

  else
    @logger.error(res_err)
  end
}