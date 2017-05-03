require 'json'
require 'vertx-web/router'
require 'vertx-web/body_handler'
require 'logger'

logger       = Logger.new(STDOUT)
logger.level = Logger::DEBUG
logger.debug "[simple_rest.rb] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"



@products = Hash.new()

def add_product(product)
  @products[product['id']] = product
end

def set_up_initial_data()
  add_product({
                  'id'     => "prod3568",
                  'name'   => "Egg Whisk",
                  'price'  => 3.99,
                  'weight' => 150
              })
  add_product({
                  'id'     => "prod7340",
                  'name'   => "Tea Cosy",
                  'price'  => 5.99,
                  'weight' => 100
              })
  add_product({
                  'id'     => "prod8643",
                  'name'   => "Spatula",
                  'price'  => 1.0,
                  'weight' => 80
              })
end


set_up_initial_data()

router = VertxWeb::Router.router($vertx)
router.route().handler(&VertxWeb::BodyHandler.create().method(:handle))

router.put("/products/:productID").blocking_handler(lambda { |routingContext|

  puts "\tin thread #{Java::JavaLang::Thread.current_thread().get_name()}"


  productID = routingContext.request().get_param("productID")
  puts @products[productID]

  routingContext.response().end()

}, false)

$vertx.create_http_server().request_handler(&router.method(:accept)).listen(8080)