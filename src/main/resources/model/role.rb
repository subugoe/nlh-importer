class Role

  attr_accessor :type, :authority, :valueURI, :role

  def initialize(type, authority, valueURI, role)
    @type = type
    @authority = authority
    @valueURI = valueURI
    @role = role
  end

end