class MetsModsMetadata

  attr_accessor :identifiers,
                :record_identifiers,
                :title_infos,
                #:personalNames,
                #:corporateNames,
                :names,
                :type_of_resources,
                :genres,

                :isnlh,
                :iswork,
                :context,
                :doctype,

                :original_infos,
                :edition_infos,
                :languages,
                :physical_descriptions,
                :notes,

                :product,
                :collection,
                :work,
                :pages,
                :nlh_ids,
                :image_format,

                :volumes,

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

                :fulltexts,

                :dateindexed,
                :datemodified


  def initialize
    @identifiers        = Hash.new
    @record_identifiers = Hash.new
    @title_infos        = Array.new
    #@personalNames      = Array.new
    #@corporateNames     = Array.new
    @names              = Array.new
    @type_of_resources  = Array.new
    @genres             = Array.new

    @original_infos        = Array.new
    @edition_infos         = Array.new
    @languages             = Array.new
    @physical_descriptions = Array.new
    @notes                 = Array.new

    @volumes =Array.new

    @pages         = Array.new
    @nlh_ids       = Array.new
    @subjects      = Array.new
    @related_items = Array.new
    @record_infos  = Array.new
    @right_infos   = Array.new

    @presentation_image_uris = Array.new
    @thumb_image_uris        = Array.new
    @fulltext_uris           = Array.new

    @fulltexts = Array.new

    @image_format = ENV['IMAGE_OUT_FORMAT']
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


  # def addPersonalName(name)
  #   @personalNames += name
  # end
  #
  # def addCorporateName(name)
  #   @corporateNames += name
  # end


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

  def addPage=(page)
    @pages += page
  end

  def addNlh_id=(nlh_id)
    @nlh_ids += nlh_id
  end

  def addVolume=(volume)
    @volumes += volume
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
    @right_infos += rightInfo
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

  def addFulltext=(fulltext)
    @fulltexts += fulltext
  end


  def to_s
    @identifier
  end

  def to_es

  end

  def to_solr_string

    h = Hash.new

    h.merge!({:image_format => @image_format})

    # todo remove is... fields
    h.merge! ({:isnlh => true})
    h.merge! ({:iswork => @iswork})

    h.merge! ({:context => @context})
    h.merge! ({:doctype => @doctype})


    h.merge! ({:identifier => @identifiers.collect { |k, v| "#{k} #{v}" }})
    h.merge! ({:pid => @record_identifiers.first[1]})

    title     = Array.new
    subtitle  = Array.new
    sorttitle = Array.new

    @title_infos.each { |ti|
      title << ti.nonsort + ti.title
      subtitle << ti.subtitle
      sorttitle << ti.title[0].upcase + ti.title[1..-1]
    }

    h.merge! ({:title => title})
    h.merge! ({:subtitle => subtitle})
    h.merge! ({:bytitle => sorttitle.join('; ')})

    begin
      h.merge! ({:pid => @record_identifiers.first[1]})
    rescue Exception => e
      puts e.message
      puts @record_identifiers
      puts @identifiers
    end

    # --- :displayform, :type, :role, :namepart, :date


    facet_creator_personal = Array.new
    facet_creator_corporate = Array.new

    facet_person_personal = Array.new
    facet_person_corporate = Array.new

    creator_displayform = Array.new
    creator_type        = Array.new
    creator_bycreator   = Array.new


    person_displayform = Array.new
    person_type        = Array.new
    person_byperson    = Array.new


    @names.each { |name|

      if name.role == 'aut'
        creator_displayform << name.displayform
        creator_type << name.type

        if name.type == 'personal'
          facet_creator_personal << name.namepart
        elsif name.type == 'corporate'
          facet_creator_corporate << name.namepart
        end

        creator_bycreator << name.namepart
      else
        person_displayform << name.displayform
        person_type << name.type

        if name.type == 'personal'
          facet_person_personal << name.namepart
        elsif name.type == 'corporate'
          facet_person_corporate << name.namepart
        end

        person_byperson << name.namepart

      end

    }

    byc = creator_bycreator.join('; ')
    byp = person_byperson.join('; ')

    h.merge! ({:creator => creator_displayform})
    h.merge! ({:creator_type => creator_type})
    h.merge! ({:bycreator => byc})

    h.merge! ({:person => person_displayform})
    h.merge! ({:person_type => person_type})
    h.merge! ({:byperson => byp})

    h.merge! ({:facet_creator_personal => facet_creator_personal})
    h.merge! ({:facet_creator_corporate => facet_creator_corporate})

    h.merge! ({:facet_person_personal => facet_person_personal})
    h.merge! ({:facet_person_corporate => facet_person_corporate})


    # ---

    h.merge! ({:genre => @genres.collect { |genre| genre.genre }})


    # ---

    # originInfo: edition
    place               = Array.new
    placeFacet          = Array.new
    date_captured_start = Array.new
    date_captured_end   = Array.new
    publisher           = Array.new
    publisherFacet      = Array.new

    @edition_infos.each { |ei|

      place << ei.place
      placeFacet << ei.placeFacet
      date_captured_start << ei.date_captured_start
      date_captured_end << ei.date_captured_end
      publisher << ei.publisher
      publisherFacet << ei.publisherFacet
    }

    h.merge! ({:place_digitization => place})
    h.merge! ({:facet_place_digitization => placeFacet})
    h.merge! ({:year_digitization_start => date_captured_start})
    h.merge! ({:year_digitization_end => date_captured_end})
    h.merge! ({:publisher_digitization => publisher})
    h.merge! ({:facet_publisher_digitization => publisherFacet})

    # originInfo: original
    place          = Array.new
    placeFacet     = Array.new
    date_issued    = Array.new
    publisher      = Array.new
    publisherFacet = Array.new


    @original_infos.each { |oi|

      place << oi.place
      placeFacet << oi.placeFacet
      date_issued << oi.date_issued
      publisher << oi.publisher
      publisherFacet << oi.publisherFacet
    }

    h.merge! ({:place_publish => place})
    h.merge! ({:facet_place_publish => placeFacet})
    h.merge! ({:year_publish => date_issued})
    h.merge! ({:publisher => publisher})
    h.merge! ({:facet_publisher => publisherFacet})


    h.merge! ({:lang => @languages.collect { |lang| lang.languageterm }})


    h.merge! ({:product => @product})
    if @doctype == "work"
      h.merge! ({:work => @work})
      h.merge! ({:page => @pages})
    elsif @doctype == "collection"
      h.merge! ({:collection => @collection})

      # add volume info
      id    = Array.new
      type  = Array.new
      label = Array.new

      @volumes.each { |vol|

        id << vol.id
        type << vol.type
        label << vol.label

      }

      h.merge! ({:volume_id => id})
      h.merge! ({:volume_type => type})
      h.merge! ({:volume_label => label})

    end
    h.merge! ({:nlh_id => @nlh_ids})


    # ---
    form                = Array.new
    reformattingQuality = Array.new
    extent              = Array.new
    digitalOrigin       = Array.new

    @physical_descriptions.each { |pd|

      form << pd.form
      reformattingQuality << pd.reformattingQuality
      extent << pd.extent
      digitalOrigin << pd.digitalOrigin
    }

    h.merge! ({:phys_desc_form => form})
    h.merge! ({:phys_desc_reformattingQuality => reformattingQuality})
    h.merge! ({:phys_desc_extent => extent})
    h.merge! ({:phys_desc_digitalOrigin => digitalOrigin})


    # ---
    type  = Array.new
    value = Array.new

    @notes.each { |n|

      type << n.type
      value << n.value
    }

    h.merge! ({:note_type => type})
    h.merge! ({:note => value})


    # :subject_name, :subject_date, :subject_title, :subject_geographic, :subject_topic, :subject_temporal, :subject_country, :subject_state, :subject_city
    # @subjects

    type       = Array.new
    subject    = Array.new
    topic      = Array.new
    geographic = Array.new

    @subjects.each { |subj|

      t = subj.type
      s = subj.subject

      type << t
      subject << s

      topic << s if t == 'topic'
      geographic << s if t == 'geographic'

    }

    h.merge! ({:subject_type => type})
    h.merge! ({:subject => subject})
    h.merge! ({:facet_subject_topic => topic})
    h.merge! ({:facet_subject_geographic => geographic})


    # rights_owner, rights_owner_site_url, rights_owner_contact, rights_license,  rights_reference
    h.merge! ({:rights_owner => @right_infos.collect { |rights| rights.owner }})
    h.merge! ({:rights_owner_site_url => @right_infos.collect { |rights| rights.ownerSiteURL }})
    h.merge! ({:rights_owner_contact => @right_infos.collect { |rights| rights.ownerContact }})
    h.merge! ({:rights_license => @right_infos.collect { |rights| rights.license }})
    h.merge! ({:rights_reference => @right_infos.collect { |rights| rights.reference }})


    h.merge! ({:parentdoc_title => @related_items.collect { |rel_item| rel_item.title }})
    h.merge! ({:parentdoc_title_abbreviated => @related_items.collect { |rel_item| rel_item.title_abbreviated }})
    h.merge! ({:parentdoc_title_partnumber => @related_items.collect { |rel_item| rel_item.title_partnumber }})
    h.merge! ({:parentdoc_note => @related_items.collect { |rel_item| rel_item.note }})
    h.merge! ({:parentdoc_type => @related_items.collect { |rel_item| rel_item.type }})


    # @record_infos.each { |recInfo|
    #   h.merge! recInfo.to_solr_string
    # }


    if @iswork == "true"
      h.merge! ({:fulltext => @fulltexts})

      #h.merge! ({:presentation_url => @presentation_image_uris})
      #    h.merge! ({:thumbs_url => @thumb_image_uris})
      #h.merge! ({:fulltext_url => @fulltext_uris})

    end


    #h.merge! ({:presentation_url => @presentationImageURIs.collect { |uri| uri }})
    #h.merge! ({:thumbs_url => @thumbImageURIs.collect { |uri| uri }})
    #h.merge! ({:fulltext_url => @fulltextURIs.collect { |uri| uri }})


    h.merge! ({:dmdid => @dmdid})
    #h.merge! ({:logid => @logid})
    h.merge! ({:mods => @mods})
    h.merge! ({:docstrct => @docstrct})

    return h
  end

end