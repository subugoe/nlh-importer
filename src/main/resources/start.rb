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


retriever_options = {
    'instances'                  => 1,
    'worker'                     => true,
    # 'workerPoolName'             => 'retrieve_worker_pool',
    # 'workerPoolSize'             => 1,
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
    'instances'                  => 10,
    'worker'                     => true,
    #'workerPoolName'             => 'index_worker_pool',
    #'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}


image_processor_options = {
    'instances'                  => 8,
    'worker'                     => true,
    #    'workerPoolName'             => 'image_worker_pool',
    #    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}


mets_copier_options = {
    'instances'                  => 10,
    'worker'                     => true,
    #    'workerPoolName'             => 'mets_copier_worker_pool',
    #    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

pdf_retriever_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'workerPoolName'             => 'retrieve_pdfs_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

pdf_converter_options = {
    'instances'                  => 5,
    'worker'                     => true,
    #  'workerPoolName'             => 'pdf_converter_worker_pool',
    #  'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

pdf_copier_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'pdf_copier_worker_pool',
    #  'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

tei_retriever_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'workerPoolName'             => 'retrieve_teis_worker_pool',
    'workerPoolSize'             => 1,
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

tei_copier_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'tei_copier_worker_pool',
    #'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

checker_options = {
    'instances'                  => 4,
    'worker'                     => true,
    'workerPoolName'             => 'checker_worker_pool',
    #'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

# def cleanupSolr
#   @solr.update :data => '<delete><query>*:*</query></delete>'
#   @solr.update :data => '<commit/>'
# end


# cleanupSolr

if ENV['PREPARE'] == 'true'
  @rredis.del 'fixitieschecked'
  @rredis.del 'fulltextscopied'
  @rredis.del 'fulltextsindexed'
  @rredis.del 'imagescopied'
  @rredis.del 'metscopied'
  @rredis.del 'indexed'
  @rredis.del 'retrieved'
  @rredis.del 'pdfsconverted'
  @rredis.del 'pdfscopied'


  @rredis.del 'pdfpath'
  @rredis.del 'copypdf'
  @rredis.del 'convertpdf'
  @rredis.del 'fixitychecker'
  @rredis.del 'metspath'
  @rredis.del 'processImageURI'
  @rredis.del 'processFulltextURI'
  @rredis.del 'processPdfFromImageURI'
  @rredis.del 'metsindexer'
  @rredis.del 'metscopier'
  @rredis.del 'teicopier'

  @rredis.del 'convertpdftopdf'
  @rredis.del 'convertpdftoimage'
  @rredis.del 'worksToProcess'

  @rredis.del 'checkmets'
  @rredis.del 'check_path_with_fulltext'
  @rredis.del 'check_path_without_fulltext'

# info_retriever
$vertx.deploy_verticle("processors/core/info_retriever/path_retriever.rb", retriever_options)
#  $vertx.deploy_verticle("processors/core/info_retriever/pdf_path_retriever.rb", pdf_retriever_options)
#  $vertx.deploy_verticle("processors/core/info_retriever/tei_path_retriever.rb", tei_retriever_options)
#  $vertx.deploy_verticle("processors/core/info_retriever/work_from_outpath_retriever.rb", retriever_options)

# helper
#  $vertx.deploy_verticle("processors/helper/check_existence_of_resource_prepare.rb", retriever_options)

else


# converter
#  $vertx.deploy_verticle("processors/core/converter/image_to_pdf_converter.rb", image_processor_options)
#  $vertx.deploy_verticle("processors/core/converter/pdf_converter.rb", converter_options)

# copier
#  $vertx.deploy_verticle("processors/core/copier/mets_copier.rb", mets_copier_options)
#  $vertx.deploy_verticle("processors/core/copier/pdf_copier.rb", pdf_copier_options)
#  $vertx.deploy_verticle("processors/core/copier/tei_copier.rb", tei_copier_options)

# indexer
#  $vertx.deploy_verticle("processors/mets_indexer.rb", indexer_options)

# resource_processor
#  $vertx.deploy_verticle("processors/core/resource_processor/fulltext_processor.rb", fulltext_processor_options)
#  $vertx.deploy_verticle("processors/core/resource_processor/image_processor.rb", image_processor_options)

# validator


# helper
#  $vertx.deploy_verticle("processors/helper/check_and_update_all_before_date_indexed.rb", indexer_options)
#  $vertx.deploy_verticle("processors/helper/check_existence_in_index.rb", indexer_options)
#  $vertx.deploy_verticle("processors/helper/check_existence_of_resource.rb", indexer_options)
#  $vertx.deploy_verticle("processors/helper/fixity_checker.rb", checker_options)
#  $vertx.deploy_verticle("processors/helper/work_based_converter.rb", converter_options)






# g = $vertx.deploy_verticle("de.unigoettingen.sub.converter.PdfFromImagesConverterVerticle", converter_options)


end

