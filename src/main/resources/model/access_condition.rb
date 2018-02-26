class AccessCondition

  attr_reader :value

  ACCESS_CONDITION_HASH = {
      "http://creativecommons.org/publicdomain/mark/1.0/" => "Public Domain Mark 1.0 (PDM)",
      "http://rightsstatements.org/vocab/InC/1.0/"        => "In Copyright (InC)",
      "http://rightsstatements.org/vocab/InC-OW-EU/1.0/"  => "In Copyright - EU Orphan Work (InC-EU-OW)",
      "http://rightsstatements.org/vocab/CNE/1.0/"        => "Copyright Not Evaluated (CNE)"
  }


  def value=(access_condition_info)
    ac = ACCESS_CONDITION_HASH[access_condition_info]
    ac = access_condition_info if ac == nil

    @value = ac
  end

end