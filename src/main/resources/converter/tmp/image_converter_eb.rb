require 'logger'
require 'tempfile'
require 'rest-client'


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/image_converter_eb_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG



$vertx.event_bus().consumer("image.convert") { |message|
  puts "[Worker] Consuming data in #{Java::JavaLang::Thread.current_thread().get_name()}"
  body = message.body()
  message.reply(body.to_upper_case())
}