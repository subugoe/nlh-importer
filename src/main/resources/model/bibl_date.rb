class BiblDate

  attr_accessor :isKeyDate, :encoding, :point, :date

  def initialize(isKeyDate, encoding, point, date)
    @isKeyDate = isKeyDate
    @encoding  = encoding
    @point = point
    @date      = date
  end

end