class RecordInfo

  attr_accessor :descriptionStandards, :recordContentSource, :recordCreationDate, :recordChangeDate, :recordIdentifier, :recordOrigin

  def initialize(recordContentSource, recordCreationDate, recordChangeDate, recordIdentifier, recordOrigin)
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


class RecordContentSource

  attr_accessor :authority, :recordContentSource

  def initialize(recordContentSource, recordCreationDate, recordChangeDate, recordIdentifier, recordOrigin)
    @recordContentSource = recordContentSource
  end

end