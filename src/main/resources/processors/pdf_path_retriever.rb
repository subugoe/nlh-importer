require 'vertx/vertx'
require 'oai'
require 'logger'
require 'open-uri'
require 'redis'
require 'json'

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)

@logger.debug "[pdf_path_retrieve worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


pdf_inpath    = ENV['IN'] + ENV['PDF_IN_SUB_PATH']
mets_inpath   = ENV['IN'] + ENV['METS_IN_SUB_PATH']
from_full_pdf = ENV['IMAGES_FROM_FULL_PDF']

def pushToQueue(arr, queue)
  @rredis.lpush(queue, arr)
end

if from_full_pdf == "true"
  paths = Dir.glob("#{pdf_inpath}/*.pdf", File::FNM_CASEFOLD).select { |e| !File.directory? e }

  arr = Array.new
  paths.each { |path|

    match = path.match(/([\S\W]*)\/([\S\W]*).(pdf|PDF)/)

    from   = match[0]
    work   = match[2].gsub(' ', '')
    format = match[3].downcase


    arr << {"from" => from, "work" => work, "format" => format}.to_json
  }
else
  paths = Dir.glob("#{pdf_inpath}/*", File::FNM_CASEFOLD).select { |e| File.directory? e }

  arr = Array.new
  paths.each { |path|

    #match = path.match(/([\S\W]*)\/([\S\W]*)\/([\S\W]*).(pdf|PDF)/)
    match = path.match(/([\S\W]*)\/([\S\W]*)/)

    from = "#{match[1]}/#{match[2]}"
    work = match[2].gsub(' ', '')
    #page   = match[3].gsub(' ', '')
    #format = match[4]


    #arr << {"from" => from, "work" => work, "page" => page, "format" => format}.to_json
    arr << {"from" => from, "work" => work}.to_json
  }
end


pushToQueue(arr, 'copypdf')
pushToQueue(arr, 'convertpdftoimage')
pushToQueue(arr, 'convertpdftopdf')

