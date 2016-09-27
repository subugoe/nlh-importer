class RecordInfo

  attr_accessor :descriptionStandards, :recordContentSource, :recordCreationDate, :recordChangeDate, :recordIdentifier, :recordOrigin

  def initialize
    @recordContentSource = recordContentSource
    @recordCreationDate  = recordCreationDate
    @recordChangeDate    = recordChangeDate
    @recordIdentifier    = recordIdentifier
    @recordOrigin        = recordOrigin

    @descriptionStandards = Array.new
  end

  def addDescriptionStandard=(descriptionStandard)
    descriptionStandards << descriptionStandard
  end

end

