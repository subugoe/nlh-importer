class PhysicalDescription

  attr_accessor :forms, :reformattingQuality, :extent, :digitalOrigin

  def initialize
    @forms               = Array.new
  end

  def addForm=(form)
    @form << form
  end

end

