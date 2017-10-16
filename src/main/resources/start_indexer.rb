require 'vertx/vertx'
require 'rubygems'
require 'logger'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
logger.debug "[start_indexer] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


indexer_options = {
    'instances'                  => 5,
    'worker'                     => true,
    'blockedThreadCheckInterval' => 3600000,
    'warningExceptionTime'       => 3600000,
    'maxWorkerExecuteTime'       => 3400000000000,
    'maxEventLoopExecuteTime'    => 600000000000,
    'GEM_PATH'                   => '/opt/jruby/lib/ruby/gems/shared/gems'
}

# indexer
$vertx.deploy_verticle("indexer/indexer_job_builder.rb", indexer_options)

=begin
      redis.lpush('indexer', [
          {"s3_key" => 'mets/PPN13357363X.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/PPN237600412.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/PPN23760034X.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/DE_611_BF_5619_1772_1779.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/PPN235181684_0126.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/HANS_DE_7_w042080.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/HANS_DE_7_w042081.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/PPN672522489.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/PPN672255316.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/PPN13357363X.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/PPN237600412.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/PPN23760034X.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/DE_611_BF_5619_1772_1779.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/PPN235181684_0126.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/HANS_DE_7_w042080.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/HANS_DE_7_w042081.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/PPN672522489.xml', "context" => 'gdz'}.to_json,
          {"s3_key" => 'mets/PPN672255316.xml', "context" => 'gdz'}.to_json
      ]
      )
=end
