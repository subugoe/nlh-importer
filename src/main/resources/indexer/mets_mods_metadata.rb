class MetsModsMetadata
  include HappyMapper


  register_namespace 'dv', 'http://dfg-viewer.de/'
  register_namespace 'mods', 'http://www.loc.gov/mods/v3'

  attr_accessor :identifiers,
                :titleInfos,
                :names,
                :typeOfResource,
                :genres,

                :originInfos,
                :languages,
                :physicalDescriptions,
                :notes,

                :subjects,
                :relatedItems,
                :recordInfos,
                :rightInfos

  def initialize
    @identifiers = Array.new
    @titleInfos  = Array.new
    @names       = Array.new
    @genres      = Array.new

    @originInfos          = Array.new
    @languages            = Array.new
    @physicalDescriptions = Array.new
    @notes                = Array.new

    @subjects     = Array.new
    @relatedItems = Array.new
    @recordInfos  = Array.new
    @rightInfos   = Array.new

  end

  def addIdentifier=(identifier)
    @identifiers << {type => value}
  end

  def addTitleInfo=(titleInfo)
    @titleInfos << title
  end

  def addName=(name)
    @names << name
  end

  def addGenre=(name)
    @genres << name
  end

  def addOriginInfo=(originInfo)
    @originInfos << originInfo
  end

  def addLanguageTerm=(languageTerm)
    @languages << languageTerm
  end

  def addPhysicalDescription=(physicalDescription)
    @physicalDescriptions << physicalDescription
  end

  def addNote(note)
    @notes << note
  end

  def addSubject(subject)
    @subjects << subject
  end

  def addRelatedItem(relatedItem)
    @relatedItems << relatedItem
  end

  def addRecordInfo(recordInfo)
    @recordInfos << recordInfo
  end

  def addRightInfo(rightInfo)
    @rightInfos << rightInfo
  end


  def to_s
    @identifier
  end

  def to_es

  end

  def to_solr

  end

end