class OriginInfo

  attr_accessor :eventType, :place, :edition, :publisher, :dateIssued, :dateCaptured, :issuance

  def initialize(issuance, eventType, edition)
    @eventType  = eventType
    @edition    = edition
    @issuance   = issuance
    @publisher  = Array.new
    @placeTerm  = Array.new
    @dateIssues = Array.new
  end

  def addPlaceTerm(placeTerm)
    @place << placeTerm
  end

  def addPublisher=(publisher)
    @publisher << publisher
  end

  def addDateIssued(date)
    @dateIssued << date
  end

  def addDateCaptured(date)
    @dateCaptured << date
  end

end


class PlaceTerm

  attr_accessor :type, :authority, :placeTerm

  def initialize(type, authority, placeTerm)
    @type      = type
    @authority = authority
    @placeTerm = placeTerm
  end

end


class Date

  attr_accessor :isKeyDate, :encoding, :point, :date

  def initialize(isKeyDate, encoding, point, date)
    @isKeyDate = isKeyDate
    @encoding  = encoding
    @point = point
    @date      = date
  end

end