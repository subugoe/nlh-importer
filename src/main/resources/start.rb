require 'vertx/vertx'
require 'rubygems'
require 'logger'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
logger.debug "[start.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


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
    'instances'                  => 1,
    'worker'                     => true,
    'workerPoolName'             => 'index_worker_pool',
    'workerPoolSize'             => 20,
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

converter_options = {
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


if ENV['PREPARE'] == 'true'


# info_retriever
#$vertx.deploy_verticle("retriever/path_retriever.rb", retriever_options)
#  $vertx.deploy_verticle("retriever/pdf_path_retriever.rb", pdf_retriever_options)
#  $vertx.deploy_verticle("retriever/tei_path_retriever.rb", tei_retriever_options)
#  $vertx.deploy_verticle("retriever/work_from_outpath_retriever.rb", retriever_options)

# helper
#  $vertx.deploy_verticle("helper/check_existence_of_resource_prepare.rb", retriever_options)

else


# converter
#  $vertx.deploy_verticle("converter/image_to_pdf_converter.rb", image_processor_options)
#  $vertx.deploy_verticle("converter/pdf_converter.rb", converter_options)

# copier
#  $vertx.deploy_verticle("copier/mets_copier.rb", mets_copier_options)
#  $vertx.deploy_verticle("copier/pdf_copier.rb", pdf_copier_options)
#  $vertx.deploy_verticle("copier/tei_copier.rb", tei_copier_options)

# indexer
  $vertx.deploy_verticle("indexer/mets_indexer.rb", indexer_options)
#  $vertx.deploy_verticle("indexer/fulltext_processor.rb", fulltext_processor_options)
#  $vertx.deploy_verticle("indexer/image_processor.rb", image_processor_options)

# validator


# helper
#  $vertx.deploy_verticle("helper/check_and_update_all_before_date_indexed.rb", indexer_options)
#  $vertx.deploy_verticle("helper/check_existence_in_index.rb", indexer_options)
#  $vertx.deploy_verticle("helper/check_existence_of_resource.rb", indexer_options)
#  $vertx.deploy_verticle("helper/fixity_checker.rb", checker_options)
#  $vertx.deploy_verticle("helper/work_based_converter.rb", converter_options)


# g = $vertx.deploy_verticle("de.unigoettingen.sub.converter.PdfFromImagesConverterVerticle", converter_options)


end


# $vertx.deploy_verticle("services/service_verticle.rb", retriever_options)


