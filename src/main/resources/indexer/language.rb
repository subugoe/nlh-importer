class LanguageTerm

  attr_accessor :authority, :type, :valueURI, :languageTerm

  def initialize(authority, type, valueURI, languageTerm)
    @authority    = authority
    @type         = type
    @valueURI     = valueURI
    @languageTerm = languageTerm
  end

end