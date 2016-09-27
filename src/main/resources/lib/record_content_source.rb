class RecordContentSource

  attr_accessor :authority, :recordContentSource

  def initialize(recordContentSource, recordCreationDate, recordChangeDate, recordIdentifier, recordOrigin)
    @recordContentSource = recordContentSource
  end

end