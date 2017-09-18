class MetsSummaryMetadata

  attr_accessor :summary

  def initialize
    @summary = Array.new
  end

  def addSummary=(summary)
    @summary = summary
  end


  def to_solr_string

    h = Hash.new

    if !@summary.empty?

      summary_name              = Array.new
      summary_content           = Array.new
      summary_ref               = Array.new
      summary_content_with_tags = Array.new

      @summary.each {|summary|

        summary_name << summary.summary_name
        summary_content << summary.summary_content
        summary_content_with_tags << summary.summary_content_with_tags
        summary_ref << summary.summary_ref
      }

      h.merge! ({:summary_name => summary_name})
      h.merge! ({:summary_content => summary_content})
      h.merge! ({:summary_content_with_tags => summary_content_with_tags})
      h.merge! ({:summary_ref => summary_ref})

    end

    return h

  end

end