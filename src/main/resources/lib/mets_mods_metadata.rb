class MetsModsMetadata

  attr_accessor :identifiers,
                :record_identifiers,
                :title_infos,
                :names,
                :type_of_resources,
                :genres,

                :original_infos,
                :edition_infos,
                :languages,
                :physical_descriptions,
                :notes,

                :product,
                :work,
                :nlh_ids,

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

    @original_infos        = Array.new
    @edition_infos         = Array.new
    @languages             = Array.new
    @physical_descriptions = Array.new
    @notes                 = Array.new

    @nlh_ids       = Array.new
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

  def addOriginalInfo=(originInfo)
    @original_infos += originInfo
  end

  def addEditionInfo=(originInfo)
    @edition_infos += originInfo
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

  def addNlh_id=(nlh_id)
    @nlh_ids += nlh_id
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


    # originInfo: edition
    h.merge! ({:place_digitization => @edition_infos.collect { |origin_info| origin_info.place }})
    h.merge! ({:facet_place_digitization => @edition_infos.collect { |origin_info| origin_info.placeFacet }})
    h.merge! ({:year_digitization_start => @edition_infos.collect { |origin_info| origin_info.date_captured_start }})
    h.merge! ({:year_digitization_end => @edition_infos.collect { |origin_info| origin_info.date_captured_end }})
    h.merge! ({:publisher_digitization => @edition_infos.collect { |origin_info| origin_info.publisher }})
    h.merge! ({:facet_publisher_digitization => @edition_infos.collect { |origin_info| origin_info.publisherFacet }})

    # originInfo: original
    h.merge! ({:place_publish => @original_infos.collect { |origin_info| origin_info.place }})
    h.merge! ({:facet_place_publish => @original_infos.collect { |origin_info| origin_info.placeFacet }})
    h.merge! ({:year_publish => @original_infos.collect { |origin_info| origin_info.date_issued }})
    h.merge! ({:publisher => @original_infos.collect { |origin_info| origin_info.publisher }})
    h.merge! ({:facet_publisher => @original_infos.collect { |origin_info| origin_info.publisherFacet }})


    h.merge! ({:lang => @languages.collect { |lang| lang.languageterm }})

    h.merge! ({:product => @product})
    h.merge! ({:work => @work})
    h.merge! ({:nlh_id => @nlh_ids.collect { |nlh_ids| nlh_ids }})


    # :form, :reformattingQuality, :extent, :digitalOrigin
    h.merge! ({:phys_desc_form => @physical_descriptions.collect { |pd| pd.form }})
    h.merge! ({:phys_desc_reformattingQuality => @physical_descriptions.collect { |pd| pd.reformattingQuality }})
    h.merge! ({:phys_desc_extent => @physical_descriptions.collect { |pd| pd.extent }})
    h.merge! ({:phys_desc_digitalOrigin => @physical_descriptions.collect { |pd| pd.digitalOrigin }})


    # @notes.each { |note|
    #   h.merge! note.to_solr_string
    # }
    #

    # :subject_name, :subject_date, :subject_title, :subject_geographic, :subject_topic, :subject_temporal, :subject_country, :subject_state, :subject_city
    # @subjects

    name     = Array.new
    date     = Array.new
    title    = Array.new
    temporal = Array.new

    geographic = Set.new
    topic      = Set.new
    country    = Set.new
    state      = Set.new
    city       = Set.new

    @subjects.each { |subject|

      name << subject.name
      date << subject.date
      title << subject.title
      temporal << subject.temporal

      geographic.merge subject.geographic.to_a
      topic.merge subject.topic.to_a

      country.merge subject.country.to_a
      state.merge subject.state.to_a
      city.merge subject.city.to_a
    }

    h.merge! ({:subject_name => name})
    h.merge! ({:subject_date => date})
    h.merge! ({:subject_title => title})
    h.merge! ({:subject_temporal => temporal})

    h.merge! ({:subject_geographic => geographic})
    h.merge! ({:subject_topic => topic})
    h.merge! ({:subject_country => country})
    h.merge! ({:subject_state => state})
    h.merge! ({:subject_city => city})


    h.merge! ({:parentdoc_title => @related_items.collect { |rel_item| rel_item.title }})
    h.merge! ({:parentdoc_title_abbreviated => @related_items.collect { |rel_item| rel_item.title_abbreviated }})
    h.merge! ({:parentdoc_title_partnumber => @related_items.collect { |rel_item| rel_item.title_partnumber }})
    h.merge! ({:parentdoc_note => @related_items.collect { |rel_item| rel_item.note }})
    h.merge! ({:parentdoc_type => @related_items.collect { |rel_item| rel_item.type }})


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