require 'vertx/vertx'
require 'logger'
require 'redis'
require 'json'
require 'fileutils'


context = ENV['CONTEXT']
MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

@inpath  = ENV['IN'] + ENV['METS_IN_SUB_PATH']
@outpath = ENV['OUT'] + ENV['METS_OUT_SUB_PATH']


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/#{context}_mets_copier_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)


@logger.debug "[mets_copier worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


def pushToQueue(queue, hsh)
  @rredis.lpush(queue, hsh.to_json)
end


def copyFile(from, to, to_dir)

  begin
    FileUtils.mkdir_p(to_dir)
    FileUtils.cp(from, to)

    @rredis.incr 'metscopied'

  rescue Exception => e
    @file_logger.error "Could not copy mets: '#{from}' to: '#{to}'\n\t#{e.message}"
  end

end


$vertx.execute_blocking(lambda { |future|

  while true do

    res = @rredis.brpop("metscopier")

    attempts = 0
    begin

      if (res != '' && res != nil)
        json = JSON.parse res[1]
        uri  = json['path']

        match1   = uri.match(/(\S*)\/(\S*_\S*_\S*)/)
        filename = match1[2]

        match2  = uri.match(/(\S*)\/(\S*)_(\S*)_(\S*)\.(\S*)/)
        prefix  = match2[2]
        product = match2[3]
        work    = match2[4]
        format  = match2[5]


        from   = "#{@inpath}/#{filename}"
        to     = "#{@outpath}/#{product}/#{work}.#{prefix}.#{format}"
        to_dir = "#{@outpath}/#{product}"

        @logger.debug "Copying METS file for work: #{work} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"

        copyFile(from, to, to_dir)
        @logger.debug "\tFinish copying METS file for work: #{work} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"

      else
        @logger.error "Get empty string or nil from redis"
      end

    rescue Exception => e
      attempts = attempts + 1
      retry if (attempts < MAX_ATTEMPTS)
      @logger.error("Could not process redis data '#{res[1]}' (#{Java::JavaLang::Thread.current_thread().get_name()})")
      @file_logger.error("Could not process redis data '#{res[1]}' (#{Java::JavaLang::Thread.current_thread().get_name()}) \n\t#{e.message}")
    end
  end

  # future.complete(doc.to_s)

}) { |res_err, res|
#
}
