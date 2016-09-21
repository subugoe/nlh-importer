class PhysicalDescription

  attr_accessor :forms, :reformattingQuality, :extent, :digitalOrigin

  def initialize(reformattingQuality, extent, digitalOrigin)
    @reformattingQuality = reformattingQuality
    @extent              = extent
    @digitalOrigin       = digitalOrigin
    @forms               = Array.new
  end

  def addForm=(form)
    @form << form
  end

end

class Form

  attr_accessor :authority, :form

  def initialize(authority, form)
    @authority = authority
    @form             = form
  end

end