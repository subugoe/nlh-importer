class Right

  attr_accessor :owner, :ownerSiteURL, :ownerContact, :license, :links

  def initialize(owner, ownerSiteURL, ownerContact, license)
    @owner = owner
    @ownerSiteURL = ownerSiteURL
    @ownerContact = ownerContact
    @license = license
    @links = Array.new
  end

  def addLink=(link)
    @links << link
  end

end