class MetsSummaryMetadata

  attr_accessor :summary

  def initialize
    @summary = Array.new
  end

  def addSummary=(summary)
    @summary += summary
  end


  def to_solr_string

    h = Hash.new
    h.merge! ({:summary_content => @summary})

    return h

  end

end