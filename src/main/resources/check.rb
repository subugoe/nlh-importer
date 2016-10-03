require 'rubygems'

require 'logger'
require 'redis'

logger       = Logger.new(STDOUT) # 'gdz_object.log')
logger.level = Logger::DEBUG


#logger.debug "[start.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i)



def getValueFromQueue(queue)
  @rredis.get(queue).to_i || 0
end

checked = getValueFromQueue 'fixitieschecked'

fulltexts_copied = getValueFromQueue 'fulltextscopied'
fulltexts_indexed = getValueFromQueue 'fulltextsindexed'

images_copied = getValueFromQueue 'imagescopied'

mets_copied = getValueFromQueue 'metscopied'

indexed = getValueFromQueue 'indexed'

retrieved = getValueFromQueue 'retrieved'


puts "paths retrieved: '#{retrieved}'"
puts "documents indexed: '#{indexed}'"
puts "mets files copied: '#{mets_copied}'"

puts "fulltexts indexed: '#{fulltexts_indexed}'"
puts "fulltexts copied: '#{fulltexts_copied}'"

puts "images copied: '#{images_copied}'"

ok = (checked == mets_copied + fulltexts_copied + images_copied)
puts "fixities checked: '#{checked}' - all files checked? #{checked == mets_copied + fulltexts_copied + images_copied}"

