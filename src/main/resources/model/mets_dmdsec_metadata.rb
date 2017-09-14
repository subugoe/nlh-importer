class MetsModsMetadata

  attr_accessor :identifiers,
                :record_identifiers,

                :purl,
                :catalogues,

                :idparentdoc,
                :title_infos,
                #:personalNames,
                #:corporateNames,
                :names,
                :type_of_resources,
                :locations,
                :genres,
                :subject_genres,
                :classifications,
                :sponsors,

                :is_child,
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

                :title_page,

                :subjects,
                :related_items,
                :parts,
                :record_infos,

                :structype,
                :dmdid,
                :logid,
                :admid,

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
                :summary,

                :dateindexed,
                :datemodified


  def initialize
    @title_page = 1

    @identifiers        = Array.new
    @record_identifiers = Hash.new

    @catalogues = Array.new

    @title_infos = Array.new
    #@personalNames      = Array.new
    #@corporateNames     = Array.new
    @names             = Array.new
    @type_of_resources = Array.new
    @locations         = Array.new
    @genres            = Array.new
    @subject_genres    = Array.new
    @classifications   = Array.new
    @sponsors          = Array.new

    @original_infos        = Array.new
    @edition_infos         = Array.new
    @languages             = Array.new
    @physical_descriptions = Array.new
    @notes                 = Array.new

    #@volumes =Array.new

    @pages         = Array.new
    @page_keys     = Array.new
    @subjects      = Array.new
    @related_items = Array.new
    @parts         = Array.new
    @record_infos  = Array.new
    @right_infos   = Array.new

    @presentation_image_uris = Array.new
    @thumb_image_uris        = Array.new
    @fulltext_uris           = Array.new
    @logicalElements         = Hash.new
    @physicalElements        = Hash.new

    @fulltexts = Array.new
    @summary   = Array.new

    #@image_format = ENV['IMAGE_OUT_FORMAT']
  end

  def addIdentifiers=(identifier)
    @identifiers = identifier
  end

  def addRecordIdentifiers=(record_identifier_hash)
    @record_identifiers.merge!(record_identifier_hash)
  end

  def addPurl=(purl)
    @purl = purl
  end

  def addCatalogue=(catalogues)
    @catalogues = catalogues
  end

  def addTitleInfo=(titleInfo)
    @title_infos = titleInfo
  end


  # def addPersonalName(name)
  #   @personalNames += name
  # end
  #
  # def addCorporateName(name)
  #   @corporateNames += name
  # end


  def addName=(name)
    @names = name
  end

  def addSponsor=(sponsor)
    @sponsors = sponsor
  end

  def addTypeOfResource=(typeOfResource)
    @type_of_resources = typeOfResource
  end

  def addLocation=(location)
    @locations = location
  end

  def addGenre=(genre)
    @genres = genre
  end

  def addSubjectGenre=(subject_genre)
    @subject_genres = subject_genre
  end

  def addClassification=(classification)
    @classifications = classification
  end

  def addOriginalInfo=(originInfo)
    @original_infos = originInfo
  end

  def addEditionInfo=(originInfo)
    @edition_infos = originInfo
  end


  def addLanguage=(language)
    @languages = language
  end

  def addPhysicalDescription=(physicalDescription)
    @physical_descriptions = physicalDescription
  end

  def addNote=(note)
    @notes = note
  end

  def addPage=(page)
    @pages = page
  end

  def addPage_key=(page_key)
    @page_keys = page_key
  end

  #def addVolume=(volume)
  #  @volumes += volume
  #end

  def addSubject=(subject)
    @subjects = subject
  end

  def addRelatedItem=(relatedItem)
    @related_items = relatedItem
  end

  def addPart=(part)
    @parts = part
  end

  def addRecordInfo=(recordInfo)
    @record_infos = recordInfo
  end

  def addRightInfo=(rightInfo)
    @right_infos = rightInfo
  end

  def addPresentationImageUri=(presentationImageUri)
    @presentation_image_uris = presentationImageUri
  end

  def addThumbImageUri=(thumbImageUri)
    @thumb_image_uris += thumbImageUri
  end

  def addFulltextUri=(fulltextUri)
    @fulltext_uris = fulltextUri
  end


  # def addLogicalElement=(logicalElement)
  #   @logicalElements += logicalElement
  # end

  def addToLogicalElement(logicalElement)
    @logicalElements[logicalElement.id] = logicalElement
  end


  # def addPhysicalElement=(physicalElement)
  #   @physicalElements += physicalElement
  # end

  def addToPhysicalElement(physicalElement)
    @physicalElements[physicalElement.id] = physicalElement
  end

  def addFulltext=(fulltext)
    @fulltexts = fulltext
  end

  def addSummary=(summary)
    @summary = summary
  end

  def to_s
    @identifier
  end

  def to_es

  end

  def fulltext_to_solr_string

    docs = Array.new

    if @iswork == true

      if !@fulltexts.empty?
        @fulltexts.each {|ft|

          h = Hash.new

          h.merge! ({:id => "#{ft.fulltext_of_work}_page_#{ft.fulltext_page_number}"})
          h.merge! ({:ft => ft.fulltext})
          h.merge! ({:ft_ref => ft.fulltext_ref})
          h.merge! ({:ft_of_work => ft.fulltext_of_work})
          h.merge! ({:ft_page_number => ft.fulltext_page_number})
          h.merge! ({:doctype => 'fulltext'})

          merge_title_info(h)

          docs << h
        }
      end

    end

    return docs

  end

  def doc_to_solr_string

    h = Hash.new

    h.merge!({:image_format => @image_format}) unless @image_format == nil

    h.merge! ({:iswork => @iswork}) unless @iswork == nil
    h.merge! ({:isanchor => @isanchor}) unless @isanchor == nil

    h.merge! ({:context => @context}) unless @context == nil
    h.merge! ({:doctype => @doctype}) unless @doctype == nil


    h.merge! ({:identifier => @identifiers}) unless @identifiers.empty?

    if !@record_identifiers.empty?
      r_id = @record_identifiers.first
      h.merge! ({:id => r_id[1]})
    end

    # e.g. http://resolver.sub.uni-goettingen.de/purl?PPN13357363X
    @purl = "http://resolver.sub.uni-goettingen.de/purl?#{@work}" if (@purl == nil) && (@work != nil)
    h.merge! ({:purl => @purl}) unless @purl == nil

    # e.g. http://opac.sub.uni-goettingen.de/DB=1/PPN?PPN=23760034X
    id          = @work.match(/PPN(\S*)/)[1] unless @work == nil
    @catalogues += "OPAC http://opac.sub.uni-goettingen.de/DB=1/PPN?PPN=#{id}" if (@catalogues.empty?) && (id != nil)
    h.merge! ({:catalogue => @catalogues})

    h.merge! ({:access_pattern => @access_pattern}) unless @access_pattern == nil
    h.merge! ({:baseurl => @baseurl}) unless @baseurl == nil

    if !@title_infos.empty?
      merge_title_info(h)
    end

    if !@names.empty?

      facet_creator_personal  = Array.new
      facet_creator_corporate = Array.new

      facet_person_personal  = Array.new
      facet_person_corporate = Array.new

      creator_displayform        = Array.new
      creator_type               = Array.new
      creator_bycreator          = Array.new
      creator_gndURI             = Array.new
      creator_gndNumber          = Array.new
      creator_roleterm           = Array.new
      creator_roleterm_authority = Array.new

      person_displayform        = Array.new
      person_type               = Array.new
      person_byperson           = Array.new
      person_gndURI             = Array.new
      person_gndNumber          = Array.new
      person_roleterm           = Array.new
      person_roleterm_authority = Array.new


      @names.each {|name|

        n = ''
        if name.family != ' '
          n = name.family
          n += ", " + name.given if name.given != ' '
        else
          n = name.displayform if name.displayform != ' '
        end

        if (name.roleterm == 'aut') || (name.roleterm == 'cre')
          creator_displayform << n
          creator_type << name.type

          if n != ''
            if name.type == 'personal'
              facet_creator_personal << n
            elsif name.type == 'corporate'
              facet_creator_corporate << n
            end

            creator_bycreator << n
          end


          creator_gndURI << name.gndURI
          creator_gndNumber << name.gndNumber
          creator_roleterm << name.roleterm
          creator_roleterm_authority << name.roleterm_authority

        else
          person_displayform << n
          person_type << name.type

          if n != ''
            if name.type == 'personal'
              facet_person_personal << n
            elsif name.type == 'corporate'
              facet_person_corporate << n
            end

            person_byperson << n
          end

          person_gndURI << name.gndURI
          person_gndNumber << name.gndNumber
          person_roleterm << name.roleterm
          person_roleterm_authority << name.roleterm_authority

        end

      }

      byc = creator_bycreator.join('; ')
      byp = person_byperson.join('; ')


      h.merge! ({:creator => creator_displayform})
      h.merge! ({:creator_type => creator_type})
      h.merge! ({:creator_gndURI => creator_gndURI})
      h.merge! ({:creator_gndNumber => creator_gndNumber})
      h.merge! ({:creator_roleterm => creator_roleterm})
      h.merge! ({:creator_roleterm_authority => creator_roleterm_authority})
      h.merge! ({:bycreator => byc})

      h.merge! ({:person => person_displayform})
      h.merge! ({:person_type => person_type})
      h.merge! ({:person_gndURI => person_gndURI})
      h.merge! ({:person_gndNumber => person_gndNumber})
      h.merge! ({:person_roleterm => person_roleterm})
      h.merge! ({:person_roleterm_authority => person_roleterm_authority})
      h.merge! ({:byperson => byp})

      h.merge! ({:facet_creator_personal => facet_creator_personal})
      h.merge! ({:facet_creator_corporate => facet_creator_corporate})

      h.merge! ({:facet_person_personal => facet_person_personal})
      h.merge! ({:facet_person_corporate => facet_person_corporate})

    end

    # ---

    h.merge! ({:sponsor => @sponsors})

    # ---

    h.merge! ({:shelfmark => @locations.collect {|location| location.shelfmark}})

    h.merge! ({:genre => @genres.collect {|genre| genre.genre}})
    h.merge! ({:subject_genre => @subject_genres.collect {|genre| genre.genre}})

    # ---
    if !@classifications.empty?

      dc           = Array.new
      dc_authority = Array.new

      @classifications.each {|classification|

        dc << classification.value
        dc_authority << classification.authority
      }

      h.merge! ({:dc => dc})
      h.merge! ({:dc_authority => dc_authority})

    end

    # ---

    # originInfo: edition

    if !@edition_infos.empty?

      places      = Array.new
      placesFacet = Array.new

      publishers      = Array.new
      publishersFacet = Array.new

      date_captured_string = ''
      date_captured_start  = ''
      date_captured_end    = ''

      @edition_infos.each {|ei|

        places << ei.places # _to_s
        placesFacet << ei.placesFacet_to_s

        publishers << ei.publishers # _to_s
        publishersFacet << ei.publishersFacet_to_s

        date_captured_string= ei.date_captured_string
        date_captured_start = ei.date_captured_start
        date_captured_end   = ei.date_captured_end
      }

      h.merge! ({:place_digitization => places})
      h.merge! ({:facet_place_digitization => placesFacet})

      h.merge! ({:publisher_digitization => publishers})
      h.merge! ({:facet_publisher_digitization => publishersFacet})

      h.merge! ({:year_digitization_string => date_captured_string}) unless date_captured_string == ''
      h.merge! ({:year_digitization_start => date_captured_start}) unless date_captured_start == ''
      h.merge! ({:year_digitization_end => date_captured_end}) unless date_captured_end == ''

    end

    # originInfo: original

    if !@original_infos.empty?

      places      = Array.new
      placesFacet = Array.new

      publishers      = Array.new
      publishersFacet = Array.new

      date_issued_string = ''
      date_issued_start  = ''
      date_issued_end    = ''


      @original_infos.each {|oi|

        places << oi.places # _to_s
        placesFacet << oi.placesFacet_to_s

        publishers << oi.publishers # _to_s
        publishersFacet << oi.publishersFacet_to_s

        date_issued_string = oi.date_issued_string
        date_issued_start  = oi.date_issued_start
        date_issued_end    = oi.date_issued_end
      }

      h.merge! ({:place_publish => places})
      h.merge! ({:facet_place_publish => placesFacet})

      h.merge! ({:publisher => publishers})
      h.merge! ({:facet_publisher => publishersFacet})

      h.merge! ({:year_publish_string => date_issued_string}) unless date_issued_string == ''
      h.merge! ({:year_publish => date_issued_start}) unless date_issued_start == ''
      h.merge! ({:year_publish_start => date_issued_start}) unless date_issued_start == ''
      h.merge! ({:year_publish_end => date_issued_end}) unless date_issued_end == ''

    end

    h.merge! ({:lang => @languages.collect {|lang| lang.languageterm}})


    h.merge! ({:product => @product})

    if @doctype == "work"
      h.merge! ({:work => @work})
      h.merge! ({:page => @pages})

      unless ENV['METS_VIA_OAI'] == 'true'
        mets_path = "mets/#{@product}/#{@work}.mets.xml"
      else
        mets_path = "http://gdz.sub.uni-goettingen.de/mets/#{@work}"
      end

      h.merge! ({:mets_path => mets_path})

    elsif @doctype == "collection"
      h.merge! ({:collection => @collection})

      unless ENV['METS_VIA_OAI'] == 'true'
        mets_path = "mets/#{@product}/#{@collection}.mets.xml"
      else
        mets_path = "http://gdz.sub.uni-goettingen.de/mets/#{@collection}"
      end
      h.merge! ({:mets_path => mets_path})
    end


    # add title page

    # <product_id>:<work_id>:<seiten-bezeichner>
    unless @product == nil || @work == nil || @pages == nil || @title_page == nil
      h.merge! ({:title_page => "#{@product}:#{@work}:#{@pages[@title_page - 1]}"})
    end


    # add logical info (e.g. volume info)

    unless is_child

      if !@logicalElements.empty?

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


        arr = Array.new
        unless @doctype == "collection"
          @logicalElements.values.each {|el|

            if (el.start_page_index != -1) && (el.end_page_index != -1)
              arr << el
            else
              h.merge! ({:parentdoc_work => el.parentdoc_work})
              h.merge! ({:parentdoc_label => el.label})
              h.merge! ({:parentdoc_type => el.type})
              #h.merge! ({:parentdoc_url => el.urls})
            end
          }
        else
          arr = @logicalElements.values
        end

        h.merge! ({:docstrct => arr[0]&.type})

        arr[1..-1].each {|el|

          id << el.id
          type << el.type
          label << el.label

          dmdid << el.dmdid
          admid << el.admid
          start_page_index << el.start_page_index unless @doctype == "collection"
          end_page_index << el.end_page_index unless @doctype == "collection"
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

      end

    end

    # add logical info as child docs


    if !@logicalElements.empty?

      log_child_arr = Array.new

      @logicalElements.values.each {|el|

        child = Hash.new

        # :dmdid, :admid, :dmdsec_mets

        child.merge! ({:id => "#{@work}___#{el.id}"})

        child.merge! ({:log_type => el.type}) unless el.type == nil
        child.merge! ({:log_label => el.label}) unless el.label == nil

        child.merge! ({:log_order => el.id.match(/LOG_(\d*)/)[1].to_i}) unless el.id == nil

        unless el.dmdid == ' '

          child.merge! ({:log_start_page_index => el.start_page_index}) unless (@doctype == "collection") && (el.start_page_index == nil)
          child.merge! ({:log_end_page_index => el.end_page_index}) unless (@doctype == "collection") && (el.end_page_index == nil)

          child.merge! ({:log_level => el.level}) unless el.level == nil

          child.merge! ({:log_part_product => el.part_product}) unless el.part_product == nil
          child.merge! ({:log_part_work => el.part_work}) unless el.part_work == nil
          child.merge! ({:log_part_key => el.part_key}) unless el.part_key == nil

          child.merge! ({:parentdoc_work => el.parentdoc_work}) unless el.parentdoc_work == nil
          child.merge! ({:parentdoc_label => el.parentdoc_label}) unless el.parentdoc_label == nil
          child.merge! ({:parentdoc_type => el.parentdoc_type}) unless el.parentdoc_type == nil

          begin

            child.merge! el.dmdsec_meta.doc_to_solr_string unless el.dmdsec_meta == nil

          rescue Exception => e
            puts "message: #{e.message} \nbacktrace: #{e.backtrace}"
          end

        end

        log_child_arr << child
      }

      h.merge! ({"_childDocuments_" => log_child_arr})

    end

    # add physical info (e.g. ORDER, ORDERLABEL)


    if !@physicalElements.empty?

      order      = Array.new
      orderlabel = Array.new

      @physicalElements.values.each {|el|

        order << el.order.to_i
        orderlabel << el.orderlabel

      }

      h.merge! ({:phys_order => order})
      h.merge! ({:phys_orderlabel => orderlabel})

      h.merge! ({:phys_first_page_index => @phys_first_page_index})
      h.merge! ({:phys_last_page_index => @phys_last_page_index})
    end
    # ---


    h.merge! ({:page_key => @page_keys})


    # ---

    if !@physical_descriptions.empty?

      form                = Array.new
      reformattingQuality = Array.new
      extent              = Array.new
      digitalOrigin       = Array.new

      @physical_descriptions.each {|pd|

        form << pd.form
        reformattingQuality << pd.reformattingQuality
        extent << pd.extent
        digitalOrigin << pd.digitalOrigin
      }

      h.merge! ({:phys_desc_form => form})
      h.merge! ({:phys_desc_reformattingQuality => reformattingQuality})
      h.merge! ({:phys_desc_extent => extent})
      h.merge! ({:phys_desc_digitalOrigin => digitalOrigin})

    end

    # ---

    if !@notes.empty?

      type  = Array.new
      value = Array.new

      @notes.each {|n|

        type << n.type
        value << n.value
      }

      h.merge! ({:note_type => type})
      h.merge! ({:note => value})

    end

    # :subject_name, :subject_date, :subject_title, :subject_geographic, :subject_topic, :subject_temporal, :subject_country, :subject_state, :subject_city
    # @subjects

    if !@subjects.empty?

      type       = Array.new
      subject    = Array.new
      topic      = Array.new
      geographic = Array.new

      @subjects.each {|subj|

        t = subj.type
        s = subj.subject

        type << t
        subject << s

        topic << s if t == 'topic'
        geographic << s if t == 'geographic'

      }

      h.merge! ({:subject_type => type}) if !type.empty?
      h.merge! ({:subject => subject}) if !subject.empty?
      h.merge! ({:facet_subject_topic => topic}) if !topic.empty?
      h.merge! ({:facet_subject_geographic => geographic}) if !geographic.empty?

    end

    # rights_owner, rights_owner_site_url, rights_owner_contact, rights_license,  rights_reference


    if !@right_infos.empty?

      h.merge! ({:rights_owner => @right_infos.collect {|rights| rights&.owner}})
      h.merge! ({:rights_owner_site_url => @right_infos.collect {|rights| rights&.ownerSiteURL}})
      h.merge! ({:rights_owner_contact => @right_infos.collect {|rights| rights&.ownerContact}})
      h.merge! ({:rights_license => @right_infos.collect {|rights| rights&.license}})
      h.merge! ({:rights_reference => @right_infos.collect {|rights| rights&.reference}})

    end


    if !@related_items.empty?

      h.merge! ({:relateditem_id => @related_items.collect {|rel_item| rel_item&.id}})
      h.merge! ({:relateditem_title => @related_items.collect {|rel_item| rel_item&.title}})
      h.merge! ({:relateditem_title_abbreviated => @related_items.collect {|rel_item| rel_item&.title_abbreviated}})
      h.merge! ({:relateditem_title_partnumber => @related_items.collect {|rel_item| rel_item&.title_partnumber}})
      h.merge! ({:relateditem_note => @related_items.collect {|rel_item| rel_item&.note}})
      h.merge! ({:relateditem_type => @related_items.collect {|rel_item| rel_item&.type}})

    end


    # currentno, currentnosort

    if !@parts.empty?

      currentnosort = Array.new
      currentno     = Array.new

      @parts.each {|part|

        cns = part.currentnosort.to_i
        if cns < 2147483647
          currentnosort << cns
        end

        currentno << part.currentno
      }

      h.merge! ({:currentnosort => currentnosort})
      h.merge! ({:currentno => currentno})

    end

    if @iswork == true

      fulltext_arr     = Array.new
      fulltext_ref_arr = Array.new

      summary_name              = Array.new
      summary_content           = Array.new
      summary_ref               = Array.new
      summary_content_with_tags = Array.new


      @fulltexts.each {|ft|
        fulltext_arr << ft.fulltext
        fulltext_ref_arr << ft.fulltext_ref
      }


      @summary.each {|summary|

        summary_name << summary.summary_name
        summary_content << summary.summary_content
        summary_content_with_tags << summary.summary_content_with_tags
        summary_ref << summary.summary_ref

      }

      h.merge! ({:fulltext => fulltext_arr})
      h.merge! ({:fulltext_ref => fulltext_ref_arr})

      h.merge! ({:summary_name => summary_name})
      h.merge! ({:summary_content => summary_content})
      h.merge! ({:summary_content_with_tags => summary_content_with_tags})
      h.merge! ({:summary_ref => summary_ref})

    end


    h.merge! ({:mods => @mods})

    return h
  end


  def merge_title_info(h)
    title     = Array.new
    subtitle  = Array.new
    sorttitle = Array.new

    @title_infos.each {|ti|
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
    h.merge! ({:sorttitle => sorttitle})
    h.merge! ({:sorttitle_first_value => sorttitle.first})

    h.merge! ({:subtitle => subtitle})
    h.merge! ({:bytitle => sorttitle.join('; ')})
  end

end

