require 'net/http'

class MetsDmdsecMetadata

  attr_accessor :is_child,
                :isnlh,
                :iswork,
                :islog,
                :isanchor,
                :context,
                :doctype,

                :product,
                :collection,
                :work,

                :id,
                :identifiers,
                :record_identifiers,
                :purl,
                :catalogues,
                :dmdid,
                :idparentdoc,

                :title_infos,
                :bytitle,

                #:personalNames,
                #:corporateNames,
                :names,
                :facet_creator_personal,
                :facet_creator_corporate,
                :facet_person_personal,
                :facet_person_corporate,

                :type_of_resources,
                :locations,
                :genres,
                :subject_genres,
                :classifications,
                :digital_collections,
                :sponsors,

                :original_infos,
                :edition_infos,

                :languages,
                :scriptterms,

                :physical_descriptions,

                :notes,

                :subjects,
                :related_items,
                :parts,
                :record_infos,

                :structype,

                :right_infos,
                :access_condition_info,

                :mods,

                :dateindexed,
                :datemodified


  def initialize

    @identifiers        = Array.new
    @record_identifiers = Hash.new

    @is_child = false

    @catalogues = Array.new

    @title_infos = Array.new
    #@personalNames      = Array.new
    #@corporateNames     = Array.new
    @names                   = Array.new
    @facet_creator_personal  = Array.new
    @facet_creator_corporate = Array.new
    @facet_person_personal   = Array.new
    @facet_person_corporate  = Array.new


    @type_of_resources   = Array.new
    @locations           = Array.new
    @genres              = Array.new
    @subject_genres      = Array.new
    @classifications     = Array.new
    @digital_collections = Array.new
    @sponsors            = Array.new

    @original_infos        = Array.new
    @edition_infos         = Array.new
    @languages             = Array.new
    @scriptterms           = Array.new
    @physical_descriptions = Array.new
    @notes                 = Array.new

    #@volumes =Array.new

    @subjects      = Array.new
    @related_items = Array.new
    @parts         = Array.new
    @record_infos  = Array.new
    @right_infos   = Array.new

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

  def addDigital_collection=(digital_collection)
    @digital_collections = digital_collection
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

  def addScriptTerm=(scriptterm)
    @scriptterms = scriptterm
  end


  def addPhysicalDescription=(physicalDescription)
    @physical_descriptions = physicalDescription
  end

  def addNote=(note)
    @notes = note
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

  def addAccessConditionInfo=(access_condition)
    @access_condition_info = access_condition
  end

  def to_s
    @identifier
  end

  def to_solr_string

    h = Hash.new

    h.merge! ({:dmdid => @dmdid})

    h.merge! ({:iswork => @iswork}) unless @iswork == nil
    h.merge! ({:islog => @islog}) unless @islog == nil
    h.merge! ({:isanchor => @isanchor}) unless @isanchor == nil

    h.merge! ({:context => @context}) unless @context == nil
    h.merge! ({:doctype => @doctype}) unless @doctype == nil

    h.merge! ({:isparent => true}) if (@doctype == "work") || (@doctype == "anchor")

    h.merge! ({:identifier => @identifiers}) unless @identifiers.empty?

    if !@record_identifiers.empty?
      r_id = @record_identifiers.first
      h.merge! ({:record_identifier => r_id[1]})
    end


    # e.g. http://resolver.sub.uni-goettingen.de/purl?PPN13357363X

    if !@is_child
      purl = "http://resolver.sub.uni-goettingen.de/purl?#{@work}" if (@work != nil)
      h.merge! ({:purl => purl}) if purl != nil
    elsif @is_child
      r_id = @record_identifiers.first[1] if !@record_identifiers.empty?
      purl = "http://resolver.sub.uni-goettingen.de/purl?#{r_id}" if (r_id != nil)
      h.merge! ({:purl => purl}) if purl != nil
    end

    # e.g. http://opac.sub.uni-goettingen.de/DB=1/PPN?PPN=23760034X
    unless @work == nil


      # todo modify to create HANS, ASCH, ... catalogue refs
      if @work.start_with? 'PPN'
        id = @work.match(/PPN(\S*)/)[1]

        unapi_url  = ENV['UNAPI_URI']
        unapi_path = ENV['UNAPI_PATH'] % id

        response = ''
        url      = URI(unapi_url)

        Net::HTTP.start(url.host) {|http|
          response = http.head(unapi_path)
          response
        }

        if response.code.to_i < 400
          @catalogues << "OPAC http://opac.sub.uni-goettingen.de/DB=1/PPN?PPN=#{id}" if (@catalogues.empty?) && (id != nil)
          h.merge! ({:catalogue => @catalogues}) unless @is_child
        end

      else

        @identifiers.each {|id|
          if (id.downcase.include? "kalliope-verbund.info")
            @catalogues << "Kalliope #{id}"
            break
          elsif (id.downcase.include? "de-")


            resp = RestClient.get(ENV['KALLIOPE_URI'] + ENV['KALLIOPE_SRU_PATH'] % id)
            records = Nokogiri::XML( resp ).xpath("//srw:numberOfRecords", "srw" => "http://www.loc.gov/zing/srw/").text.to_i

            if records > 0
              @catalogues << "Kalliope #{ENV['KALLIOPE_URI'] + ENV['KALLIOPE_PATH'] % id}"
              break
            end
          end
        }
        h.merge! ({:catalogue => @catalogues}) if (!@is_child && !@catalogues.empty?)

      end

    end

    if !@title_infos.empty?
      merge_title_info(h)
    end

    if !@names.empty?

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
          if name.given != ' '
            n = "#{name.family}, #{name.given}"
          else
            n = name.family
          end
        else
          n = name.namepart if name.namepart != ' '
          n = name.displayform if n == ''
        end

        if (name.roleterm == 'aut') || (name.roleterm == 'cre')
          creator_displayform << n
          creator_type << name.type

          if n != ''
            if name.type == 'personal'
              @facet_creator_personal << n
            elsif name.type == 'corporate'
              @facet_creator_corporate << n
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
              @facet_person_personal << n
            elsif name.type == 'corporate'
              @facet_person_corporate << n
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

      h.merge! ({:facet_creator_personal => @facet_creator_personal})
      h.merge! ({:facet_creator_corporate => @facet_creator_corporate})

      h.merge! ({:facet_person_personal => @facet_person_personal})
      h.merge! ({:facet_person_corporate => @facet_person_corporate})

    end

    # ---

    h.merge! ({:sponsor => @sponsors})

    # ---

    h.merge! ({:shelfmark => @locations.collect {|location| location.shelfmark}})

    h.merge! ({:genre => @genres.collect {|genre| genre.genre}})
    h.merge! ({:subject_genre => @subject_genres.collect {|genre| genre.genre}})

    # ---

    if !(@classifications.empty?) || !(@digital_collections.empty?)

      dc = Array.new

      @classifications.each {|classification|
        dc << classification.value
      }

      # (added for new Goobi Ruleset)
      @digital_collections.each {|digital_collection|
        dc << digital_collection.value
      }

      h.merge! ({:dc => dc})

    end

    # ---

    # originInfo: edition

    if !@edition_infos.empty?

      places      = Array.new
      placesFacet = Array.new
      editions    = Array.new

      publishers      = Array.new
      publishersFacet = Array.new

      date_captured_string = ''
      date_captured_start  = ''
      date_captured_end    = ''

      @edition_infos.each {|ei|

        places << ei.places&.join('; ') # _to_s
        placesFacet << ei.placesFacet_to_s&.join('; ')
        editions << ei.edition # _to_s

        publishers << ei.publishers&.join('; ') # _to_s
        publishersFacet << ei.publishersFacet_to_s&.join('; ')

        date_captured_string= ei.date_captured_string
        date_captured_start = ei.date_captured_start
        date_captured_end   = ei.date_captured_end
      }


      h.merge! ({:edition_digitization => (editions&.select {|el| el != ''}).join("; ")})
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
      editions    = Array.new

      publishers      = Array.new
      publishersFacet = Array.new

      date_issued_string = ''
      date_issued_start  = ''
      date_issued_end    = ''


      @original_infos.each {|oi|

        places << oi.places&.join('; ') # _to_s
        placesFacet << oi.placesFacet_to_s&.join('; ')
        editions << oi.edition # _to_s

        publishers << oi.publishers&.join('; ') # _to_s
        publishersFacet << oi.publishersFacet_to_s&.join('; ')

        date_issued_string = oi.date_issued_string
        date_issued_start  = oi.date_issued_start
        date_issued_end    = oi.date_issued_end
      }


      h.merge! ({:edition => (editions&.select {|el| el != ''}).join("; ")})
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
    h.merge! ({:scriptterm => @scriptterms})

    h.merge! ({:product => @product})

    if @doctype == "work"
      h.merge! ({:work => @work})


      # unless ENV['METS_VIA_OAI'] == 'true'
      #   mets_path = "mets/#{@product}/#{@work}.mets.xml"
      # else
      #   mets_path = "http://gdz.sub.uni-goettingen.de/mets/#{@work}"
      # end
      #
      # h.merge! ({:mets_path => mets_path})

    elsif @doctype == "anchor"
      h.merge! ({:collection => @collection})

      # unless ENV['METS_VIA_OAI'] == 'true'
      #   mets_path = "mets/#{@product}/#{@collection}.mets.xml"
      # else
      #   mets_path = "http://gdz.sub.uni-goettingen.de/mets/#{@collection}"
      # end
      # h.merge! ({:mets_path => mets_path})
    end


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


    if !@right_infos.empty? && !@is_child

      h.merge! ({:rights_owner => @right_infos.collect {|rights| rights&.owner}})
      h.merge! ({:rights_owner_site_url => @right_infos.collect {|rights| rights&.ownerSiteURL}})
      h.merge! ({:rights_owner_contact => @right_infos.collect {|rights| rights&.ownerContact}})
      h.merge! ({:rights_owner_logo => @right_infos.collect {|rights| rights&.ownerLogo}})
      h.merge! ({:rights_license => @right_infos.collect {|rights| rights&.license}})
      h.merge! ({:rights_sponsor => @right_infos.collect {|rights| rights&.sponsor}})
      h.merge! ({:rights_sponsor_site_url => @right_infos.collect {|rights| rights&.sponsorSiteURL}})
      #h.merge! ({:rights_reference => @right_infos.collect {|rights| rights&.reference}})
    end

    if (@access_condition_info != nil) && !@is_child
      h.merge! ({:rights_access_condition => @access_condition_info.value})
    end

    unless @related_items.empty?

      h.merge! ({:relateditem_id => @related_items.collect {|rel_item| rel_item&.id}})
      h.merge! ({:relateditem_title => @related_items.collect {|rel_item| rel_item&.title}})
      h.merge! ({:relateditem_title_abbreviated => @related_items.collect {|rel_item| rel_item&.title_abbreviated}})
      h.merge! ({:relateditem_title_partnumber => @related_items.collect {|rel_item| rel_item&.title_partnumber}})
      h.merge! ({:relateditem_note => @related_items.collect {|rel_item| rel_item&.note}})
      h.merge! ({:relateditem_type => @related_items.collect {|rel_item| rel_item&.type}})

    end


    # currentno, currentnosort

    unless @parts.empty?

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


    # ---

    h.merge! ({:mods => @mods})

    return h
  end


  def merge_title_info(h)
    title     = Array.new
    subtitle  = Array.new
    sorttitle = Array.new

    @title_infos.each {|ti|
      if ti.nonsort != ""
        title << ti.nonsort + " " + ti.title
      else
        title << ti.title
      end
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

