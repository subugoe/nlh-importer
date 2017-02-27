class MetsModsMetadata

  attr_accessor :identifiers,
                :record_identifiers,
                :idparentdoc,
                :title_infos,
                #:personalNames,
                #:corporateNames,
                :names,
                :type_of_resources,
                :genres,
                :classifications,
                :sponsors,

                :isnlh,
                :iswork,
                :isanchor,
                :context,
                :doctype,

                :access_pattern,
                :baseurl,

                :original_infos,
                :edition_infos,
                :languages,
                :physical_descriptions,
                :notes,

                :product,
                :collection,
                :work,
                :pages,
                :page_keys,
                :image_format,

                #          :volumes,

                :subjects,
                :related_items,
                :parts,
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
                :logicalElements,
                :physicalElements,
                :phys_first_page_index,
                :phys_last_page_index,


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
    @classifications    = Array.new
    @sponsors           = Array.new

    @original_infos        = Array.new
    @edition_infos         = Array.new
    @languages             = Array.new
    @physical_descriptions = Array.new
    @notes                 = Array.new

    #@volumes =Array.new

    @pages                 = Array.new
    @page_keys               = Array.new
    @subjects              = Array.new
    @related_items         = Array.new
    @parts                 = Array.new
    @record_infos          = Array.new
    @right_infos           = Array.new

    @presentation_image_uris = Array.new
    @thumb_image_uris        = Array.new
    @fulltext_uris           = Array.new
    @logicaElements          = Array.new
    @physicalElements        = Array.new

    @fulltexts = Array.new

    #@image_format = ENV['IMAGE_OUT_FORMAT']
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

  def addSponsor=(sponsor)
    @sponsors += sponsor
  end

  def addTypeOfResource=(typeOfResource)
    @type_of_resources += typeOfResource
  end

  def addGenre=(genre)
    @genres += genre
  end

  def addClassification=(classification)
    @classifications += classification
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

  def addPage_key=(page_key)
    @page_keys += page_key
  end

  #def addVolume=(volume)
  #  @volumes += volume
  #end

  def addSubject=(subject)
    @subjects += subject
  end

  def addRelatedItem=(relatedItem)
    @related_items += relatedItem
  end

  def addPart=(part)
    @parts += part
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


  def addLogicalElement=(logicalElement)
    @logicaElements += logicalElement
  end

  def addPhysicalElement=(physicalElement)
    @physicalElements += physicalElement
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

    h.merge! ({:iswork => @iswork})
    h.merge! ({:isanchor => @isanchor})

    h.merge! ({:context => @context})
    h.merge! ({:doctype => @doctype})


    # todo should we put v in single quotes?, e.g.  "<key-type> <value>" -> "vd18 VD18 10268960" -> "vd18 'VD18 10268960'"
    h.merge! ({:identifier => @identifiers.collect { |k, v| "#{k} #{v}" }})
    h.merge! ({:id => @record_identifiers.first[1]})

    h.merge! ({:access_pattern => @access_pattern})
    h.merge! ({:baseurl => @baseurl})


    title     = Array.new
    subtitle  = Array.new
    sorttitle = Array.new

    @title_infos.each { |ti|
      title << ti.nonsort + ti.title
      subtitle << ti.subtitle
      unless (ti.title == nil)
        if ti.title.size > 1
          sorttitle << ti.title[0].upcase + ti.title[1..-1]
        elsif ti.title.size == 1
          sorttitle << ti.title[0].upcase
        else
          sorttitle << ''
        end
      end
    }

    h.merge! ({:title => title})
    h.merge! ({:subtitle => subtitle})
    h.merge! ({:bytitle => sorttitle.join('; ')})


    h.merge! ({:id => @record_identifiers.first[1]})

    # --- :displayform, :type, :role, :namepart, :date


    facet_creator_personal  = Array.new
    facet_creator_corporate = Array.new

    facet_person_personal  = Array.new
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

    h.merge! ({:sponsor => @sponsors})

    # ---

    h.merge! ({:genre => @genres.collect { |genre| genre.genre }})

    # ---

    dc = Array.new
    dc_authority = Array.new

    @classifications.each {|classification|

      dc << classification.value
      dc_authority << classification.authority
    }

    h.merge! ({:dc => dc})
    h.merge! ({:dc_authority => dc_authority})

    # ---

    # originInfo: edition
    place               = Array.new
    placeFacet          = Array.new
    date_captured_string = ''
    date_captured_start = ''
    date_captured_end   = ''
    publisher           = Array.new
    publisherFacet      = Array.new

    @edition_infos.each { |ei|

      place << ei.place
      placeFacet << ei.placeFacet
      date_captured_string= ei.date_captured_string
      date_captured_start = ei.date_captured_start
      date_captured_end   = ei.date_captured_end
      publisher << ei.publisher
      publisherFacet << ei.publisherFacet
    }

    h.merge! ({:place_digitization => place})
    h.merge! ({:facet_place_digitization => placeFacet})
    h.merge! ({:year_digitization_string => date_captured_string}) unless date_captured_string == ''
    h.merge! ({:year_digitization_start => date_captured_start}) unless date_captured_start == ''
    h.merge! ({:year_digitization_end => date_captured_end}) unless date_captured_end == ''
    h.merge! ({:publisher_digitization => publisher})
    h.merge! ({:facet_publisher_digitization => publisherFacet})

    # originInfo: original
    place             = Array.new
    placeFacet        = Array.new
    date_issued_string = ''
    date_issued_start = ''
    date_issued_end   = ''
    publisher         = Array.new
    publisherFacet    = Array.new


    @original_infos.each { |oi|

      place << oi.place
      placeFacet << oi.placeFacet
      date_issued_string = oi.date_issued_string
      date_issued_start = oi.date_issued_start
      date_issued_end   = oi.date_issued_end
      publisher << oi.publisher
      publisherFacet << oi.publisherFacet
    }

    h.merge! ({:place_publish => place})
    h.merge! ({:facet_place_publish => placeFacet})
    h.merge! ({:year_publish_string => date_issued_string}) unless date_issued_string == ''
    h.merge! ({:year_publish => date_issued_start}) unless date_issued_start == ''
    h.merge! ({:year_publish_start => date_issued_start}) unless date_issued_start == ''
    h.merge! ({:year_publish_end => date_issued_end}) unless date_issued_end == ''
    h.merge! ({:publisher => publisher})
    h.merge! ({:facet_publisher => publisherFacet})


    h.merge! ({:lang => @languages.collect { |lang| lang.languageterm }})


    h.merge! ({:product => @product})

    if @doctype == "work"
      h.merge! ({:work => @work})
      h.merge! ({:page => @pages})

      mets_path = "mets/#{@product}/#{@work}.mets.xml"
      h.merge! ({:mets_path => mets_path})

    elsif @doctype == "collection"
      h.merge! ({:collection => @collection})

      mets_path = "mets/#{@product}/#{@collection}.mets.xml"
      h.merge! ({:mets_path => mets_path})

    end

    # add logical info (e.g. volume info)

    id               = Array.new
    type             = Array.new
    label            = Array.new
    dmdid            = Array.new
    admid            = Array.new
    start_page_index = Array.new
    end_page_index   = Array.new
    part_product     = Array.new
    part_work        = Array.new
    part_key         = Array.new
    level            = Array.new

    @logicaElements.each { |el|

      id << el.id
      type << el.type
      label << el.label

      dmdid << el.dmdid
      admid << el.admid
      start_page_index << el.start_page_index
      end_page_index << el.end_page_index
      part_product << el.part_product
      part_work << el.part_work
      part_key << el.part_key
      level << el.level

    }

    h.merge! ({:log_id => id})
    h.merge! ({:log_type => type})
    h.merge! ({:log_label => label})


    h.merge! ({:log_start_page_index => start_page_index})
    h.merge! ({:log_end_page_index => end_page_index})
    h.merge! ({:log_level => level})
    h.merge! ({:log_part_product => part_product})
    h.merge! ({:log_part_work => part_work})
    h.merge! ({:log_part_key => part_key})


    # add physical info (e.g. ORDER, ORDERLABEL)
    #:type, :id, :order, :orderlabel

    order      = Array.new
    orderlabel = Array.new


    @physicalElements.each { |el|

      order << el.order.to_i
      orderlabel << el.orderlabel

    }

    h.merge! ({:phys_order => order})
    h.merge! ({:phys_orderlabel => orderlabel})

    h.merge! ({:phys_first_page_index => @phys_first_page_index})
    h.merge! ({:phys_last_page_index => @phys_last_page_index})

    # ---


    h.merge! ({:page_key => @page_keys})


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


    h.merge! ({:parentdoc_id => @related_items.collect { |rel_item| rel_item.id }})
    h.merge! ({:parentdoc_title => @related_items.collect { |rel_item| rel_item.title }})
    h.merge! ({:parentdoc_title_abbreviated => @related_items.collect { |rel_item| rel_item.title_abbreviated }})
    h.merge! ({:parentdoc_title_partnumber => @related_items.collect { |rel_item| rel_item.title_partnumber }})
    h.merge! ({:parentdoc_note => @related_items.collect { |rel_item| rel_item.note }})
    h.merge! ({:parentdoc_type => @related_items.collect { |rel_item| rel_item.type }})

    # currentno, currentnosort

    currentnosort = Array.new
    currentno     = Array.new

    @parts.each { |part|

      cns = part.currentnosort.to_i
      if cns < 2147483647
        currentnosort << cns
      end

      currentno << part.currentno
    }

    h.merge! ({:currentnosort => currentnosort})
    h.merge! ({:currentno => currentno})


    if @iswork == true
      h.merge! ({:fulltext => @fulltexts})
    end


    h.merge! ({:dmdid => @dmdid})
    h.merge! ({:mods => @mods})
    h.merge! ({:docstrct => @docstrct})

    return h
  end


  def checkInSolr
    inpath = '/Volumes/gdzs-1/nlh/mets/emo'
    paths  = Dir.glob("#{inpath}/*.xml", File::FNM_CASEFOLD).select { |e| !File.directory? e }
    paths.each { |path|

      doc              = File.open(path) { |f| Nokogiri::XML(f) { |config| config.noblanks } }
      mods             = doc.xpath('//mods:mods', 'mods' => 'http://www.loc.gov/mods/v3')[0]
      recordIdentifier = mods.xpath('mods:recordInfo/mods:recordIdentifier', 'mods' => 'http://www.loc.gov/mods/v3').first.text

      solr = RSolr.connect :url => 'http://134.76.19.103:8443/solr/nlh'

      q        = "id:#{recordIdentifier}"
      response = solr.get 'select', :params => {:q => q}
      if response['response']['docs'].empty?
        puts path
      end


    }
  end

  def checkMupltipleUsedId

    hsh      = Hash.new
    err_keys = Set.new

    inpath = '/Volumes/gdzs-1/nlh/mets/emo'
    paths  = Dir.glob("#{inpath}/*.xml", File::FNM_CASEFOLD).select { |e| !File.directory? e }
    paths.each { |path|

      doc              = File.open(path) { |f| Nokogiri::XML(f) { |config| config.noblanks } }
      mods             = doc.xpath('//mods:mods', 'mods' => 'http://www.loc.gov/mods/v3')[0]
      recordIdentifier = mods.xpath('mods:recordInfo/mods:recordIdentifier', 'mods' => 'http://www.loc.gov/mods/v3').first.text

      unless hsh.include? recordIdentifier
        hsh[recordIdentifier] = [path]
      else
        hsh[recordIdentifier] << [path]
        err_keys << recordIdentifier
      end

      err_keys.each { |key|
        puts hsh[key]
      }
    }
  end


end
