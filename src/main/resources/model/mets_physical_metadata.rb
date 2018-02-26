class MetsPhysicalMetadata

  attr_accessor :physicalElements

  def initialize
    @physicalElements = Hash.new
  end


  # def addPhysicalElement=(physicalElement)
  #   @physicalElements += physicalElement
  # end

  def addToPhysicalElement(physicalElement)
    @physicalElements[physicalElement.id] = physicalElement
  end

  # add physical info (e.g. ORDER, ORDERLABEL)


  def to_solr_string

    h = Hash.new

    if !@physicalElements.empty?

      order      = Array.new
      orderlabel = Array.new
      contentids = Array.new

      @physicalElements.values.each {|el|
        order << el.order.to_i
        orderlabel << el.orderlabel
        contentids << el.contentid
      }

      h.merge! ({:phys_order => order})
      h.merge! ({:phys_orderlabel => orderlabel})
      h.merge! ({:phys_content_id => contentids})
    end

    return h

  end

end