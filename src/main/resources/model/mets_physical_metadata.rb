class MetsPhysicalMetadata

  attr_accessor :physicalElements

  def initialize
    @physicalElements = Hash.new
  end

  def addToPhysicalElement(physicalElement)
    @physicalElements[physicalElement.id] = physicalElement
  end

  def to_solr_string

    h = Hash.new

    if !@physicalElements.empty?

      order      = Array.new
      orderlabel = Array.new
      contentids = Array.new
      contentids_changed_at = Array.new

      @physicalElements.values.each {|el|
        order << el.order.to_i
        orderlabel << el.orderlabel
        contentids << el.contentid
        contentids_changed_at << el.contentid_changed_at
      }

      h.merge! ({:phys_order => order})
      h.merge! ({:phys_orderlabel => orderlabel})
      h.merge! ({:phys_content_id => contentids})
      h.merge! ({:phys_content_id_changed_at => contentids_changed_at})
    end

    return h

  end

end