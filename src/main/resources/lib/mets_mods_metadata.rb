class MetsModsMetadata

  attr_accessor :identifiers,
                :record_identifiers,
                :title_infos,
                :names,
                :type_of_resources,
                :genres,

                :origin_infos,
                :languages,
                :physical_descriptions,
                :notes,

                :subjects,
                :related_items,
                :record_infos,

                :structype,
                :dmdid,
                :logid,
                :admid,

                :docstrct,
                :bytitle,

                :right_infos,
                :mods,

                :presentation_image_uris,
                :thumb_image_uris,
                :fulltext_uris,

                :dateindexed,
                :datemodified

  def initialize
    @identifiers        = Hash.new
    @record_identifiers = Hash.new
    @title_infos        = Array.new
    @names              = Array.new
    @type_of_resources  = Array.new
    @genres             = Array.new

    @origin_infos          = Array.new
    @languages             = Array.new
    @physical_descriptions = Array.new
    @notes                 = Array.new

    @subjects      = Array.new
    @related_items = Array.new
    @record_infos  = Array.new
    @right_infos   = Array.new

    @presentation_image_uris = Array.new
    @thumb_image_uris        = Array.new
    @fulltext_uris           = Array.new

  end

  def addIdentifiers=(identifiersHash)
    @identifiers.merge!(identifiersHash)
  end

  def addRecordIdentifiers=(record_identifier_hash)
    @record_identifiers.merge!(record_identifier_hash)
  end


  def addTitleInfo=(titleInfo)
    @title_infos += titleInfo
  end

  def addName=(name)
    @names += name
  end


  def addTypeOfResource=(typeOfResource)
    @type_of_resources += typeOfResource
  end

  def addGenre=(name)
    @genres += name
  end

  def addOriginInfo=(originInfo)
    @origin_infos += originInfo
  end

  def addLanguage=(language)
    @languages += language
  end

  def addPhysicalDescription=(physicalDescription)
    @physical_descriptions += physicalDescription
  end

  def addNote=(note)
    @notes += note
  end

  def addSubject=(subject)
    @subjects += subject
  end

  def addRelatedItem=(relatedItem)
    @related_items += relatedItem
  end

  def addRecordInfo=(recordInfo)
    @record_infos += recordInfo
  end

  def addRightInfo=(rightInfo)
    @rightInfos += rightInfo
  end

  def addPresentationImageUri=(presentationImageUri)
    @presentation_image_uris += presentationImageUri
  end

  def addThumbImageUri=(thumbImageUri)
    @thumb_image_uris += thumbImageUri
  end

  def addFulltextUri=(fulltextUri)
    @fulltext_uris += fulltextUri

  end


  def to_s
    @identifier
  end

  def to_es

  end

  def to_solr_string

    h = Hash.new

    h.merge! ({:isnlh => true})
    h.merge! ({:iswork => true})

    h.merge! ({:context => "nlh"})
    h.merge! ({:doctype => "work"})


    (@identifiers.collect { |k, v| {k => "#{k} #{v}"} }).each { |a| h.merge!(a) }
    (@identifiers.collect { |k, v| {"id_#{k.to_s}_s" => "#{k} #{v}"} }).each { |a| h.merge!(a) }
    #(@identifiers.collect { |k, v| {:identifier => "#{k} #{v}"} }).each { |a| h.merge!(a) }
    h.merge! ({:identifier => @identifiers.collect { |k, v| "#{k} #{v}" }})
    h.merge! ({:pid => @record_identifiers.first[1]})

    h.merge! ({:title => @title_infos.collect { |title| title.title }})
    h.merge! ({:subtitle => @title_infos.collect { |title| title.subtitle }})
    h.merge! ({:nonsort => @title_infos.collect { |title| title.nonsort }})

    h.merge! ({:creator => @names.collect { |name| name.displayform }})

    h.merge! ({:genre => @genres.collect { |genre| genre.genre }})

    @origin_infos.each { |originInfo|
      h.merge! originInfo.to_solr_string
    }


    h.merge! ({:lang => @languages.collect { |lang| lang.languageterm }})


    # @physicalDescriptions.each { |pd|
    #   h.merge! pd.to_solr_string
    # }
    #
    # @notes.each { |note|
    #   h.merge! note.to_solr_string
    # }
    #
    # @subjects.each { |s|
    #   h.merge! s.to_solr_string
    # }

    @related_items.each { |relInfo|
      h.merge! relInfo.to_solr_string
    }


    @record_infos.each { |recInfo|
      h.merge! recInfo.to_solr_string
    }


    @right_infos.each { |gightInfo|
      h.merge! gightInfo.to_solr_string
    }

    h.merge! ({:presentation_url => @presentation_image_uris})
#    h.merge! ({:thumbs_url => @thumb_image_uris})
    h.merge! ({:fulltext_url => @fulltext_uris})

    #h.merge! ({:presentation_url => @presentationImageURIs.collect { |uri| uri }})
    #h.merge! ({:thumbs_url => @thumbImageURIs.collect { |uri| uri }})
    #h.merge! ({:fulltext_url => @fulltextURIs.collect { |uri| uri }})


    h.merge! ({:dmdid => @dmdid})
    #h.merge! ({:logid => @logid})
    #h.merge! ({:mods => @mods})
    h.merge! ({:bytitle => @bytitle})
    h.merge! ({:docstrct => @docstrct})

    return h
  end

end