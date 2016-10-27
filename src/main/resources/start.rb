require 'vertx/vertx'
require 'vertx-redis/redis_client'

require 'rubygems'

require 'logger'
require 'redis'
require 'rsolr'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG


logger.debug "[start.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i)

@solr = RSolr.connect :url => ENV['SOLR_ADR']


retriever_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'workerPoolName'             => 'retrieve_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

mapper_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'workerPoolName'             => 'mapper_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

indexer_options = {
    'instances'                  => 4,
    'worker'                     => false,
    #'workerPoolName'             => 'index_worker_pool',
    #'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

fulltext_processor_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'fulltext_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

image_processor_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'image_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

converter_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'workerPoolName'             => 'converter_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

copier_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'copier_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}


checker_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'checker_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

def cleanupSolr
  @solr.update :data => '<delete><query>*:*</query></delete>'
  @solr.update :data => '<commit/>'
end


#cleanupSolr

if false #true
@rredis.del 'fixitieschecked'
@rredis.del 'fulltextscopied'
@rredis.del 'fulltextsindexed'
@rredis.del 'imagescopied'
@rredis.del 'metscopied'
@rredis.del 'indexed'
@rredis.del 'retrieved'


@rredis.del 'fixitychecker'
@rredis.del 'metspath'
@rredis.del 'processImageURI'
@rredis.del 'processFulltextURI'
@rredis.del 'processPdfFromImageURI'
@rredis.del 'metsindexer'
@rredis.del 'metscopier'
end

z = $vertx.deploy_verticle("processors/image_input_paths_mapper.rb", mapper_options)
a = $vertx.deploy_verticle("processors/path_retrieve.rb", retriever_options)

#b = $vertx.deploy_verticle("processors/mets_indexer.rb", indexer_options)
#d = $vertx.deploy_verticle("processors/image_processor.rb", image_processor_options)
#e = $vertx.deploy_verticle("processors/mets_copier.rb", copier_options)


# c = $vertx.deploy_verticle("processors/fulltext_processor.rb", fulltext_processor_options)
# f = $vertx.deploy_verticle("processors/fixity_checker.rb", checker_options)
# g = $vertx.deploy_verticle("de.unigoettingen.sub.converter.PdfFromImagesConverterVerticle", converter_options)




