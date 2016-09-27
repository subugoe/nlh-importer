class OriginInfo

  attr_accessor :place, :edition, :publisher, :date_issued, :date_captured_start, :date_captured_end #,  :issuance, :eventType

  def initialize
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

  def to_solr_string

    h = Hash.new

    if (edition == '[Electronic ed.]')
      # 'placedigitization, yeardigitizationstart, yeardigitizationend, publisherdigitization
      h.merge!({
                   :place_digitization     => @place,
                   :year_digitization_start => @date_captured_start,
                   :year_digitization_end   => @date_captured_end,
                   :publisher_digitization => @publisher
               })

    else
      # placepublish, yearpublish, publisher
      h.merge!({
                   :place_publish => @place,
                   :year_publish  => @date_issued,
                   :publisher    => @publisher
               })

    end


    return h

  end

end

