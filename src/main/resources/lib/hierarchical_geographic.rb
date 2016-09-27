class HierarchicalGeographic

  attr_accessor :country, :state, :city

  def initialize(country, state, city)
    @country = country
    @state = state
    @city = city
  end

end