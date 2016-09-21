class RelatedItem

  attr_accessor :type, :titleInfos, :note, :recordInfo

  def initialize(type, note, recordInfo)
    @type = type
    @note = note
    @recordInfo = recordInfo

    @titleInfos = Array.new
  end

  def addTitleInfo=(titleInfo)
    @titleInfos << titleInfo
  end

end