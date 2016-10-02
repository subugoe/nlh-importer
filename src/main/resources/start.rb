require 'vertx/vertx'
require 'vertx-redis/redis_client'

require 'rubygems'

require 'logger'
require 'redis'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG


logger.debug "[start.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i)

retriever_options = {
    'instances'                  => 1,
    'worker'                     => true,
    'workerPoolName'             => 'retrieve_worker_pool',
    'workerPoolSize'             => 1,
    'blockedThreadCheckInterval' => 15000,
    'warningExceptionTime'       => 45000,
    'GEM_PATH'                   => '/usr/share/jruby/lib/ruby/gems/shared/gems'
}

indexer_options = {
    'instances'                  => 1,
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
    'workerPoolSize'             => 2,
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


@rredis.del 'fixitieschecked'
@rredis.del 'fulltextscopied'
@rredis.del 'fulltextsindexed'
@rredis.del 'imagescopied'
@rredis.del 'metscopied'
@rredis.del 'indexed'
@rredis.del 'retrieved'


a = $vertx.deploy_verticle("processors/path_retrieve.rb", retriever_options)
b = $vertx.deploy_verticle("processors/mets_indexer.rb", indexer_options)
c = $vertx.deploy_verticle("processors/fulltext_processor.rb", fulltext_processor_options)
d = $vertx.deploy_verticle("processors/image_processor.rb", image_processor_options)
e = $vertx.deploy_verticle("processors/mets_copier.rb", copier_options)
f = $vertx.deploy_verticle("processors/fixity_checker.rb", checker_options)





