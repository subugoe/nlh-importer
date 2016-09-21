class Name

  attr_accessor :type, :usage, :nameparts, :roles, :displayForm

  def initialize(type, usage, displayForm)
    @type = type
    @usage = usage
    @displayForm = displayForm
    @nameparts = Array.new
    @roles = Array.new
  end

  def addNamepart=(namepart)
    @nameparts << namepart
  end

  def addRole=(role)
    @roles << role
  end


end

class NamePart

  attr_accessor :type, :namePart

  def initialize(type, namePart)
    @type = type
    @namePart = namePart
  end

end

class Role

  attr_accessor :type, :authority, :valueURI, :role

  def initialize(type, authority, valueURI, role)
    @type = type
    @authority = authority
    @valueURI = valueURI
    @role = role
  end



end