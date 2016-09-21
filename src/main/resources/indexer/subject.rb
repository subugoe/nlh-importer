class Subject

  attr_accessor :authority, :topic, :geographic, :hierarchicalGeographic

  def initialize(authority, topic, geographic)
    @authority = authority
    @topic = topic
    @geographic = geographic
  end

end


class HierarchicalGeographic

  attr_accessor :country, :state, :city

  def initialize(country, state, city)
    @country = country
    @state = state
    @city = city
  end

end