require 'vertx/vertx'
require 'vertx-redis/redis_client'

require 'rubygems'

require 'logger'
require 'redis'
require 'rsolr'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG


logger.debug "[start.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)

@solr = RSolr.connect :url => ENV['SOLR_ADR']

pdf_retriever_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'workerPoolName'             => 'retrieve_pdfs_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

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

pdf_converter_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'pdf_worker_pool',
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

mets_copier_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'mets_copier_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

pdf_copier_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'workerPoolName'             => 'pdf_copier_worker_pool',
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

if ENV['PREPARE'] == 'true'
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


  $vertx.deploy_verticle("processors/pdf_copier.rb", pdf_copier_options)
  $vertx.deploy_verticle("processors/image_input_paths_mapper.rb", mapper_options)
  $vertx.deploy_verticle("processors/path_retrieve.rb", retriever_options)
  $vertx.deploy_verticle("processors/pdf_path_retrieve.rb", pdf_retriever_options)


else

  $vertx.deploy_verticle("processors/pdf_converter.rb", pdf_converter_options)

  $vertx.deploy_verticle("processors/mets_indexer.rb", indexer_options)

  $vertx.deploy_verticle("processors/mets_indexer.rb", indexer_options)
  $vertx.deploy_verticle("processors/image_processor.rb", image_processor_options)
  $vertx.deploy_verticle("processors/mets_copier.rb", mets_copier_options)


  if ENV['FULLTEXTS_EXIST'] == 'true'
    c = $vertx.deploy_verticle("processors/fulltext_processor.rb", fulltext_processor_options)
  end

  # f = $vertx.deploy_verticle("processors/fixity_checker.rb", checker_options)
  # g = $vertx.deploy_verticle("de.unigoettingen.sub.converter.PdfFromImagesConverterVerticle", converter_options)


end
