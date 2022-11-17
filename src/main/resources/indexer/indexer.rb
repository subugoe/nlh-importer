require 'benchmark'

require 'logger'
require 'gelf'
require 'rsolr'
require 'nokogiri'
require 'saxerator'
require 'open-uri'
require 'redis'
require 'json'
require 'set'
require 'cgi'

require 'rest-client'
require 'aws-sdk'

require 'model/mets_dmdsec_metadata'
require 'model/mets_fulltext_metadata'
require 'model/mets_image_metadata'
require 'model/mets_logical_metadata'
require 'model/mets_physical_metadata'
require 'model/mets_summary_metadata'

require 'model/title_info'
require 'model/origin_info'
require 'model/name'
require 'model/genre'
require 'model/language'
require 'model/related_item'
require 'model/part'
require 'model/record_info'
require 'model/physical_description'
require 'model/subject'
require 'model/note'
require 'model/right'
require 'model/access_condition'
require 'model/logical_element'
require 'model/physical_element'
require 'model/classification'
require 'model/location'
require 'model/fulltext'
require 'model/summary'


class Indexer

  MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

  def initialize(res)

    if (res != '' && res != nil)

      # {"s3_key" => key, "context" => context}.to_json
      # s3_obj_key= mets/<id>.xml
      msg = res[1]

      json = JSON.parse msg

      @context = json['context']
      @prod    = json['product']
      @id      = json['document']
      @reindex = json['reindex']


      if @context == "nlh"
        @s3_key = "mets/#{@id}.mets.xml"
      else
        @s3_key = "mets/#{@id}.xml"
      end


    end

    @dc_hsh = {'vd18 digital' => 'vd18.digital',
        'VD18 digital' => 'vd18.digital',
        'vd18 göttingen' => 'vd18.göttingen',
        'VD18 göttingen' => 'vd18.göttingen'
      }

    @image_format_hsh = {
        "nlh-ahn"  => "gif",
        "nlh-bcn"  => "tif",
        "nlh-bln"  => "tif",
        "nlh-ddr"  => "tif",
        "nlh-eai1" => "gif",
        "nlh-eai2" => "gif",
        "nlh-ecc"  => "tif",
        "nlh-ecj"  => "jpg",
        "nlh-eha"  => "jpg",
        "nlh-emo"  => "jpg",
        "nlh-fta"  => "jpg",
        "nlh-mme"  => "tif",
        "nlh-mmh"  => "jpg",
        "nlh-mml"  => "tif",
        "nlh-mmp"  => "jpg",
        "nlh-mms"  => "tif",
        "nlh-moc"  => "jpg",
        "nlh-ncn"  => "tif",
        "nlh-nid"  => "jpg",
        "nlh-tda1" => "tif",
        "nlh-tda2" => "tif",
        "nlh-tls"  => "jpg",
        "nlh-tcn"  => "tif",
        "nlh-usc"  => "jpg",
        "gdz"      => "tif"
    }

    @access_pattern = ENV['ACCESS_PATTERN']

    productin   = ENV['IN'] + '/' + @prod
    @teiinpath  = productin + ENV['TEI_IN_SUB_PATH']
    @teioutpath = ENV['OUT'] + ENV['TEI_OUT_SUB_PATH']

    @fulltextexist = ENV['FULLTEXTS_EXIST']

    @logger       = GELF::Logger.new(ENV['GRAYLOG_URI'], ENV['GRAYLOG_PORT'].to_i, "WAN", {:facility => ENV['GRAYLOG_FACILITY']})
    @logger.level = ENV['DEBUG_MODE'].to_i

#    @logger       = Logger.new(STDOUT)
#    @logger.level = ENV['DEBUG_MODE'].to_i


    @services_adr = ENV['SERVICES_ADR']

    @queue                    = ENV['REDIS_INDEX_QUEUE']
    @content_id_date_kv_store = ENV['REDIS_CONTENT_ID_DATE_KV_STORE']

    @rredis = Redis.new(
        :host               => ENV['REDIS_HOST'],
        :port               => ENV['REDIS_EXTERNAL_PORT'].to_i,
        :db                 => ENV['REDIS_DB'].to_i,
        :reconnect_attempts => 3
    )

    @solr_gdz_tmp = RSolr.connect :url => ENV['SOLR_GDZ_TMP_ADR']
    @solr_gdz     = RSolr.connect :url => ENV['SOLR_GDZ_ADR']

    attempts = 0
    begin
      if @context == "gdz"
        access_key_id     = ENV['S3_SUB_AWS_ACCESS_KEY_ID']
        secret_access_key = ENV['S3_SUB_AWS_SECRET_ACCESS_KEY']
        endpoint          = ENV['S3_SUB_ENDPOINT']
        region            = ENV['S3_SUB_REGION']
      elsif @context == "digizeit"
        access_key_id     = ENV['S3_DIGIZEIT_AWS_ACCESS_KEY_ID']
        secret_access_key = ENV['S3_DIGIZEIT_AWS_SECRET_ACCESS_KEY']
        endpoint          = ENV['S3_DIGIZEIT_ENDPOINT']
        region            = ENV['S3_DIGIZEIT_REGION']
      elsif @context.downcase.start_with?("nlh")
        access_key_id     = ENV['S3_NLH_AWS_ACCESS_KEY_ID']
        secret_access_key = ENV['S3_NLH_AWS_SECRET_ACCESS_KEY']
        endpoint          = ENV['S3_NLH_ENDPOINT']
        region            = ENV['S3_NLH_REGION']
      end

      @s3 = Aws::S3::Client.new(
          :access_key_id     => access_key_id,
          :secret_access_key => secret_access_key,
          :endpoint          => endpoint,
          :region            => region,
          :force_path_style  => false)

    rescue Exception => e
      attempts = attempts + 1
      if (attempts < MAX_ATTEMPTS)
        sleep 0.2
        retry
      end

      raise e
    end


    @resource = Aws::S3::Resource.new(client: @s3)

    @gdz_bucket = ENV['S3_GDZ_BUCKET']

  end


  def fileNotFound(type, e)
    if e.message.start_with? "redirection forbidden"
      @logger.error("[indexer] [GDZ-527] #{type} #{@id} not available \t#{e.message}")
    elsif e.message.start_with? "Failed to open TCP connection"
      @logger.error("[indexer] [GDZ-527] Failed to open #{type} #{@id} because of TCP connection problems \t#{e.message}")
    else
      @logger.error("[indexer] Could not open #{type} #{@id} \t#{e.message}")
    end
  end


  def modifyUrisInArray(images, object_uri)
    arr = images.collect { |uri|
      switchToFedoraUri uri, object_uri
    }

    return arr
  end


  def switchToFedoraUri uri, object_uri
    "#{object_uri}/images/#{parseId(uri)}"
  end


  def addDocsToSolr(document)

    attempts = 0
    begin

      if !@reindex
        if document.class == Array
          @solr_gdz.add document # , :add_attributes => {:commitWithin => 10}
        else
          @solr_gdz.add [document] # , :add_attributes => {:commitWithin => 10}
        end
        @solr_gdz.commit
      else
        if document.class == Array
          @solr_gdz_tmp.add document # , :add_attributes => {:commitWithin => 10}
        else
          @solr_gdz_tmp.add [document] # , :add_attributes => {:commitWithin => 10}
        end
        @solr_gdz_tmp.commit
      end

    rescue Exception => e
      attempts = attempts + 1
      retry if (attempts < MAX_ATTEMPTS)
      @logger.error("[indexer] Could not add doc to solr \t#{e.message}")
    end
  end

  def checkEmptyString(str)
    if (str == "") || (str == nil)
      return ' '
    else
      return str
    end
  end


  def getIdentifiers(id, mods)

    ids = Array.new

    begin

      mods.xpath('identifier').each { |id_element|
        ids << id_element.text
      }

      mods.xpath('recordInfo/recordIdentifier')&.each { |id_element|
        ids << id_element.text
      }

    rescue Exception => e
      @logger.error("[indexer] Could not retrieve an identifier for #{@id} \t#{e.message}")
    end

    return ids
  end


  def getRecordIdentifiers(id, mods)

    ids = Hash.new

    begin
      recordIdentifiers = mods.xpath('identifier[@type="gbv-ppn"]')
      recordIdentifiers = mods.xpath('recordInfo/recordIdentifier[@source="gbv-ppn"]') if recordIdentifiers.empty?
      recordIdentifiers = mods.xpath('identifier[@type="ppn" or @type="PPN"]') if recordIdentifiers.empty?
      recordIdentifiers = mods.xpath('identifier[@type="urn" or @type="URN"]') if recordIdentifiers.empty?
      recordIdentifiers = mods.xpath('recordInfo/recordIdentifier[@source="DE-611"]') if recordIdentifiers.empty?
      #recordIdentifiers = mods.xpath('recordInfo/recordIdentifier[@source="Kalliope"]') if recordIdentifiers.empty?
      #recordIdentifiers = mods.xpath('identifier[@type="DE-7/hans"]') if recordIdentifiers.empty?
      recordIdentifiers = mods.xpath('identifier[@type="local"][not(@invalid="yes")]') if recordIdentifiers.empty?
      recordIdentifiers = mods.xpath('recordInfo/recordIdentifier') if recordIdentifiers.empty?

      while recordIdentifiers.count > 0

        id_element = recordIdentifiers.shift

        id_source = id_element.attributes['source']
        id_type   = id_element.attributes['type']

        type = id_source&.value
        type = id_type&.value if type == nil
        type = 'recordIdentifier' if type == nil

        id        = id_element.text
        ids[type] = id
      end
      recordIdentifiers = nil

    rescue Exception => e
      @logger.error("[indexer] Could not retrieve the recordidentifier for #{@id} \t#{e.message}")
    end

    return ids
  end


  def getTitleInfos(modsTitleInfoElements)

    titleInfoArr = Array.new
    while modsTitleInfoElements.count > 0
      ti = modsTitleInfoElements.shift

      titleInfo = TitleInfo.new

      titleInfo.title    = ti.xpath('title').text
      titleInfo.subtitle = checkEmptyString ti.xpath('subTitle').text
      titleInfo.nonsort  = ti.xpath('nonSort').text

      titleInfoArr << titleInfo
    end
    modsTitleInfoElements = nil

    return titleInfoArr
  end


  def getName(modsNameElements)

    nameArr = Array.new

    while modsNameElements.count > 0

      name = modsNameElements.shift

      n = Name.new

      n.type    = checkEmptyString name['type']
      authority = name['authority']
      if authority == 'gnd'
        value       = name['valueURI']
        n.gndURI    = checkEmptyString value
        n.gndNumber = checkEmptyString value[(value.rindex('/') + 1)..-1]
      else
        n.gndURI    = ' '
        n.gndNumber = ' '
      end

      roleterm             = name.xpath('role/roleTerm[@type="code"]')
      n.roleterm_authority = checkEmptyString roleterm.xpath('@authority').text
      n.roleterm           = checkEmptyString roleterm.text

      n.family = checkEmptyString name.xpath('namePart[@type="family"]').text
      n.given  = checkEmptyString name.xpath('namePart[@type="given"]').text

      n.displayform = checkEmptyString name.xpath('displayForm').text

      #n.namepart = checkEmptyString name.xpath('namePart[not(@type="date")]').text
      n.namepart = checkEmptyString name.xpath('namePart[not(@type)]').text

      n.date = checkEmptyString name.xpath('namePart[@type="date"]').text

      nameArr << n

    end

    modsNameElements = nil

    return nameArr

  end

  def getLocation(modsLocationElements)

    locationArr = Array.new

    while modsLocationElements.count > 0
      li = modsLocationElements.shift

      li.xpath("physicalLocation[@type='shelfmark']").each { |shelfmark|
        if (shelfmark.text != '')
          loc           = Location.new
          loc.shelfmark = shelfmark.text
          locationArr << loc
        end
      }


      li.xpath("shelfLocator").each { |shelfmark|
        if (shelfmark.text != '')
          loc           = Location.new
          loc.shelfmark = shelfmark.text
          locationArr << loc
        end
      }
    end

    modsLocationElements = nil

    return locationArr
  end

  def getGenre(modsGenreElements)
    genreArr = Array.new

    while modsGenreElements.count > 0

      g = modsGenreElements.shift

      genre = Genre.new

      genre.genre = g.text

      genreArr << genre

    end
    modsGenreElements = nil

    return genreArr

  end

  def getClassification(modsClassificationElements)

    classificationArr = Array.new

    while modsClassificationElements.count > 0

      dc = modsClassificationElements.shift

      classification = Classification.new

      c = checkEmptyString dc.text
      c = @dc_hsh[c] unless @dc_hsh[c] == nil

      classification.value     = c.downcase
      classification.authority = checkEmptyString dc["authority"]

      classificationArr << classification

    end
    modsClassificationElements = nil

    return classificationArr
  end


  def getDigitalCollections(modsDigitalCollectionElements)

    digitalCollectionArr = Array.new

    while modsDigitalCollectionElements.count > 0

      col = modsDigitalCollectionElements.shift

      classification = Classification.new

      c = checkEmptyString col.text.downcase
      c = @dc_hsh[col] unless @dc_hsh[col] == nil

      classification.value = c

      digitalCollectionArr << classification

    end
    modsDigitalCollectionElements = nil

    return digitalCollectionArr
  end


  def getOriginInfo(modsOriginInfoElements)

    originalInfoArr = Array.new
    editionInfoArr  = Array.new

    while modsOriginInfoElements.count > 0

      oi = modsOriginInfoElements.shift

      originInfo = OriginInfo.new

      originInfo.places     = oi.xpath("place/placeTerm[@type='text']").collect { |el| el.text }
      originInfo.publishers = oi.xpath("publisher").collect { |el| el.text }
      #originInfo.issuance = oi.xpath("issuance").text

      originInfo.edition = oi.xpath("edition").text

      if (originInfo.edition == '[Electronic ed.]')

        # The date on which the resource was digitized or a subsequent snapshot was taken.
        # multi_ dateCaptured[encoding, point, keyDate]/value
        # just the start

        captured_start_date = oi.xpath("dateCaptured[@keyDate='yes' or @point='start']").text
        captured_end_date   = oi.xpath("dateCaptured[@point='end']").text

        captured_start_date = oi.xpath("dateCaptured").text if captured_start_date == ''


        unless captured_start_date == ''
          originInfo.date_captured_string = captured_start_date
          originInfo.check_and_add_date_captured_start(captured_start_date, @id)
        end


        unless captured_end_date == ''
          originInfo.check_and_add_date_captured_end(captured_end_date, @id)
        end


        if originInfo.date_captured_start == 0
          @logger.error("[indexer] [GDZ-546] date_captured_start=0 for #{@id} (check conversion problem)")
        end

      else
        # The date that the resource was published, released or issued.
        # multi:  dateIssued[encoding, point, keyDate]/value
        issued_start_date = oi.xpath("dateIssued[@keyDate='yes' or @point='start']").text
        issued_end_date   = oi.xpath("dateIssued[@point='end']").text

        # add new fiel for creation date in index and put the following info to this field
        if issued_start_date == ''
          issued_start_date = oi.xpath("dateCreated[@keyDate='yes' or @point='start']").text
          issued_end_date   = oi.xpath("dateCreated[@point='end']").text
        end

        unless issued_start_date == ''
          originInfo.date_issued_string = issued_start_date
          originInfo.check_and_add_date_issued_start(issued_start_date, @id)
        end

        unless issued_end_date == ''
          originInfo.check_and_add_date_issued_end(issued_end_date, @id)
        end

        if originInfo.date_issued_start == 0
          @logger.error("[indexer] [GDZ-546] date_issued_start=0 for #{@id} (check conversion problem)")
        end

      end

      if (originInfo.edition == '[Electronic ed.]')
        editionInfoArr << originInfo
      else
        originalInfoArr << originInfo
      end

    end
    modsOriginInfoElements = nil

    return [originalInfoArr, editionInfoArr]

  end

  def getScriptterm(modsLanguageElements)

    langArr = Array.new
    while modsLanguageElements.count > 0
      l = modsLanguageElements.shift
      langArr << l.xpath("scriptTerm").text
    end
    modsLanguageElements = nil
    return langArr

  end

  def getLanguage(modsLanguageElements)

    langArr = Array.new
    while modsLanguageElements.count > 0

      l                 = modsLanguageElements.shift
      lang              = LanguageTerm.new
      lang.languageterm = l.xpath("languageTerm[@type='code']").text
      langArr << lang

    end
    modsLanguageElements = nil
    return langArr

  end


  def getphysicalDescription(modsPhysicalDescriptionElements)

    physicalDescriptionArr = Array.new

    while modsPhysicalDescriptionElements.count > 0

      physdesc = modsPhysicalDescriptionElements.shift
      pd       = PhysicalDescription.new

      forms = Hash.new
      physdesc.xpath('form').each { |el| forms.merge! el['authority'] => el.text }

      pd.form                = forms['marccategory']
      pd.reformattingQuality = physdesc.xpath('reformattingQuality').text
      pd.extent              = physdesc.xpath('extent').text
      pd.digitalOrigin       = physdesc.xpath('digitalOrigin').text

      physicalDescriptionArr << pd

    end

    modsPhysicalDescriptionElements = nil
    return physicalDescriptionArr
  end


  def getNote(modsNoteElements)

    noteArr = Array.new

    while modsNoteElements.count > 0

      note = modsNoteElements.shift
      n    = Note.new

      n.type  = checkEmptyString note["type"]
      n.value = checkEmptyString note.text

      noteArr << n

    end
    modsNoteElements = nil

    return noteArr
  end


  def getSubject(modsSubjectElements)

    subjectArr = Array.new

    while modsSubjectElements.count > 0

      su = modsSubjectElements.shift

      subject = Subject.new

      personal   = su.xpath('name[@type="personal"]/namePart')
      corporate  = su.xpath('name[@type="corporate"]/namePart')
      topic      = su.xpath('geographic|topic|temporal')
      geographic = su.xpath('hierarchicalGeographic')

      if !personal.empty?
        subject.type    = 'personal'
        str             = personal.collect { |s| s.text if s != nil }.join("; ")
        subject.subject = str

      elsif !corporate.empty?
        subject.type    = 'corporate'
        str             = corporate.collect { |s| s.text if s != nil }.join("; ")
        subject.subject = str

      elsif !geographic.empty?
        subject.type    = 'geographic'
        subject.subject = geographic.children.collect { |s| s.text if (s != nil && s.children != nil) }.join("/")

      elsif !topic.empty?
        subject.type    = 'topic'
        subject.subject = topic.collect { |s| s.child.text if (s != nil && s.child != nil) }.join("/")

      end

      subjectArr << subject

    end
    modsSubjectElements = nil

    return subjectArr
  end


  def getRelatedItem(modsRelatedItemElements)

    relatedItemArr = Array.new

    while modsRelatedItemElements.count > 0

      ri          = modsRelatedItemElements.shift
      relatedItem = RelatedItem.new

      relatedItem.id                = checkEmptyString ri.xpath('recordInfo/recordIdentifier').text
      relatedItem.title             = checkEmptyString ri.xpath('titleInfo[not(@type="abbreviated")]/title').text
      relatedItem.title_abbreviated = checkEmptyString ri.xpath('titleInfo[@type="abbreviated"]/title').text
      relatedItem.title_partnumber  = checkEmptyString ri.xpath('titleInfo/partNumber').text
      relatedItem.note              = checkEmptyString ri.xpath('note').text
      relatedItem.type              = checkEmptyString ri.xpath("@type").text

      relatedItemArr << relatedItem

    end
    modsRelatedItemElements = nil
    return relatedItemArr
  end


  def getPart(modsPartElements)

    partArr = Array.new
    while modsPartElements.count > 0

      p = modsPartElements.shift

      part = Part.new

      part.currentnosort = checkEmptyString p.xpath("@order").text

      detail = p.xpath('detail')

      unless detail.empty?
        part.currentno = checkEmptyString detail.first.xpath('number').text
      end

      partArr << part

    end
    return partArr

  end


  def getRecordInfo(modsRecordInfoElements)
    recordInfoArr = Array.new
    return recordInfoArr
  end


  def retrieve_image_data(image_meta)

    #@str_doc = open("http://gdz.sub.uni-goettingen.de/mets/PPN235181684_0126.xml")
    #@str_doc = open("http://gdz.sub.uni-goettingen.de/mets/DE_611_BF_5619_1772_1779.xml")
    doc_parser = Saxerator.parser(@str_doc) { |config|
      config.ignore_namespaces!
      config.output_type = :xml
    }

    fileGrp = doc_parser.for_tag('fileGrp').with_attribute('USE', 'PRESENTATION')
    fileGrp = doc_parser.for_tag('fileGrp').with_attribute('USE', 'MAX') if fileGrp.first.to_s == ''
    fileGrp = doc_parser.for_tag('fileGrp').with_attribute('USE', 'DEFAULT') if fileGrp.first.to_s == ''


    fileGrp_str = fileGrp.first.to_s.gsub("xlink:href", "href")
    # or strip_namespaces! :xlink
    fileGrp_parser = Saxerator.parser(fileGrp_str) { |config|
      config.ignore_namespaces!
      config.put_attributes_in_hash!
      #config.strip_namespaces! :xlink
    }
    files          = fileGrp_parser.within('file')

    id_arr   = Array.new
    page_arr = Array.new

    firstUri = files.first.attributes['href']

    if (@context != nil) && (@context.downcase == "nlh")

      begin

        # NLH:  https://nl.sub.uni-goettingen.de/image/eai1:0FDAB937D2065D58:0FD91D99A5423158/full/full/0/default.jpg
        match = firstUri.match(/(\S*)\/(\S*)\/(\S*):(\S*):(\S*)(\/\S*\/\S*\/\S*\/\S*)/)
        work = match[4]
      rescue Exception => e
        @logger.error("[indexer] [GDZ-757] No regex match for NLH/IIIF image URI #{firstUri.to_s} \t#{e.message}")
        raise
      end


      image_meta.image_format = @image_format_hsh[@prod]
      image_meta.access_pattern = @access_pattern
      image_meta.product        = @prod
      image_meta.work           = work

    elsif (@context != nil) && (@context.downcase == "gdz")

      begin


        #   http://gdz.sub.uni-goettingen.de/tiff/DE_611_BF_5619_1772_1779/00000001.tif
        #   http://gdz.sub.uni-goettingen.de/tiff/PPN898111889/00000001.tif
        match = firstUri.match(/(\S*)\/tiff\/(\S*)\/(\S*)\.(\S*)/)
        if match == nil
          #   file:///goobi/tiff001/sbb/PPN726234869/00000001.tif
          match = firstUri.match(/(\S*)\/sbb\/(\S*)\/(\S*)\.(\S*)/)
        end
        work = match[2]
      rescue Exception => e
        @logger.error("[indexer] [GDZ-757] No regex match for GDZ/IIIF image URI #{firstUri.to_s} \t#{e.message}")
        raise
      end

      image_meta.image_format = @image_format_hsh[@prod]
      image_meta.access_pattern = @access_pattern
      image_meta.product        = @prod
      image_meta.work           = work
    end

    files = fileGrp_parser.within('file')
    files.each { |file|

      image_uri = file.attributes['href']

      begin
        if (@context != nil) && (@context.downcase == "gdz")
          match = image_uri.match(/(\S*)\/tiff\/(\S*)\/(\S*)\.(\S*)/)
          if match == nil
            match = image_uri.match(/(\S*)\/sbb\/(\S*)\/(\S*)\.(\S*)/)
          end
          page = match[3]
        elsif (@context != nil) && (@context.downcase == "nlh")
          match = image_uri.match(/(\S*\/)(\S*):(\S*):(\S*)(\/\S*\/\S*\/\S*\/\S*)/)
          page  = match[4]
        end
      rescue Exception => e
        @logger.error("[indexer] No regex match for GDZ/IIIF image URI #{image_uri} \t#{e.message}")
        raise
      end

      id_arr << "#{@prod}:#{work}:#{page}"
      page_arr << page

    }

    image_meta.add_page_key_arr = id_arr
    image_meta.add_page_arr     = page_arr

  end

  def processFulltexts(fulltext_meta)

    from_physical_id_to_attr_hsh, from_file_id_to_order_phys_id_hsh = get_physical_attr_hash
    doc_parser = Saxerator.parser(@str_doc) { |config|
      config.ignore_namespaces!
      config.output_type = :xml
    }
    fileGrp    = doc_parser.for_tag('fileGrp').with_attribute('USE', 'GDZOCR')
    fileGrp    = doc_parser.for_tag('fileGrp').with_attribute('USE', 'FULLTEXT') if fileGrp.first.to_s == ''
    fileGrp    = doc_parser.for_tag('fileGrp').with_attribute('USE', 'TEI') if fileGrp.first.to_s == ''
    return if fileGrp.first.to_s == ''

    fileGrp_str    = fileGrp.first.to_s.gsub("xlink:href", "href")
    fileGrp_parser = Saxerator.parser(fileGrp_str) { |config|
      config.ignore_namespaces!
      config.put_attributes_in_hash!
    }
    files          = fileGrp_parser.within('file')
    firstUri       = files.first.attributes['href']

    fulltextUriArr = Array.new
    fulltextArr    = Array.new

    begin

      if (@context != nil) && (@context.downcase == "nlh")
        # https://nl.sub.uni-goettingen.de/tei/eai1:0F7AD82E731D8E58:0F7A4A0624995AB0.tei.xml
        match = firstUri.match(/(\S*)\/(\S*):(\S*):(\S*)\.(tei\.xml|txt\.xml|html)/)
        work = match[3]
      elsif (@context != nil) && (@context.downcase == "gdz")
        match = firstUri.match(/(\S*)\/(\S*)\/(\S*)\/(\S*)\.(\S*)/)
        work  = match[3]
      end

    rescue Exception => e
      @logger.error("[indexer] No regex match for fulltext URI #{firstUri} \t#{e.message}")
      raise
    end

    files = fileGrp_parser.for_tag('file')
    files.each { |file|

      fulltext = Fulltext.new
      uri      = file['FLocat'].attributes['href']
      id       = file.attributes['ID']

      begin
        if (@context != nil) && (@context.downcase == "nlh")
          match    = uri.match(/\S*:\S*:(\S*)\.(tei\.xml|txt\.xml|html)/)
          page     = match[1]
          format   = match[2]
          filename = match[1] + '.' + match[2]
        elsif (@context != nil) && (@context.downcase == "gdz")
          match  = uri.match(/\S*\/(\S*)\.(xml|txt|html)/)
          page   = match[1]
          format = match[2]
          filename = match[1] + '.' + match[2]
        end
      rescue Exception => e
        @logger.error("[indexer] No regex match for fulltext URI #{uri} \t#{e.message}")
        fulltext.fulltext             = "ERROR"
        fulltext.fulltext_ref         = "ERROR"
        fulltext.fulltext_of_work     = "ERROR"
        fulltext.fulltext_page_number = "ERROR"

        fulltextArr << fulltext
        next
      end

      fulltext.fulltext_of_work = work

      phys_id = from_file_id_to_order_phys_id_hsh[id]

      if phys_id != nil
        page_number = from_physical_id_to_attr_hsh[phys_id]['order']
      else
        @logger.error "[indexer] from_file_id_to_order_phys_id_hsh[id]: #{from_file_id_to_order_phys_id_hsh[id]}, (id: #{id})"
        next
      end

      fulltext.fulltext_page_number = page_number

      ftext = get_fulltext_from_s3(filename, format)


      @logger.error "[indexer]  ftext: '#{ftext}' (#{ftext == ""} #{ftext == nil})"
      
      if ftext == nil
        fulltext.fulltext     = ""
        fulltext.fulltext_ref = uri
      elsif ftext == ""
        fulltext.fulltext     = ""
        fulltext.fulltext_ref = uri
      elsif format == "txt"
        fulltext.fulltext     = ftext
        fulltext.fulltext_ref = uri
      else
        if ftext&.root == nil
          @logger.error "[indexer] ERROR root element of fulltext is nil (#{work}/#{page}.#{format})"
          fulltext.fulltext     = ""
          fulltext.fulltext_ref = uri
        else
          ftxt = ftext.root.text.gsub(/\s+/, " ").strip
          #ftxt.gsub!(/</, "&lt;")
          #ftxt.gsub!(/>/, "&gt;")
          ftxt = CGI.escapeHTML(ftxt)

          fulltext.fulltext     = ftxt
          fulltext.fulltext_ref = uri
        end
      end

      fulltextArr << fulltext
    }

    fulltext_meta.addFulltext = fulltextArr

  end

  def addToHash(from_log_id_to_start_end_hsh, logical_id, to)

    if from_log_id_to_start_end_hsh[logical_id] == nil
      from_log_id_to_start_end_hsh[logical_id] = {'start' => to, 'end' => to}
    else
      if from_log_id_to_start_end_hsh[logical_id]['start'] > to
        from_log_id_to_start_end_hsh[logical_id]['start'] = to
      end
      if from_log_id_to_start_end_hsh[logical_id]['end'] < to
        from_log_id_to_start_end_hsh[logical_id]['end'] = to
      end
    end

  end

  def get_logical_divs_for_tag
    #xml_parser = Saxerator.parser(open('http://gdz.sub.uni-goettingen.de/mets/PPN496972103_0197.xml')) {|config|
    xml_parser = Saxerator.parser(@str_doc) { |config|
      config.output_type = :xml
      config.ignore_namespaces!
    }
    structmap  = xml_parser.for_tag("structMap").with_attribute("TYPE", "LOGICAL")

    structmap_parser = Saxerator.parser(structmap.first.to_s.gsub("xlink:href", "href")) { |config|
      #config.ignore_namespaces!
      #config.put_attributes_in_hash!
      config.output_type = :xml
    }

    divs = structmap_parser.for_tag("div")
    divs
  end

  def get_physical_divs_within
    xml_parser = Saxerator.parser(@str_doc) { |config|
      config.output_type = :xml
      config.ignore_namespaces!
    }
    structmap  = xml_parser.for_tag("structMap").with_attribute("TYPE", "PHYSICAL")

    structmap_parser = Saxerator.parser(structmap.first.to_s) { |config|
      #config.ignore_namespaces!
      config.put_attributes_in_hash!
      #config.output_type = :xml
    }

    divs = structmap_parser.within("div")

    divs
  end


  # todo clean up
  def get_physical_attr_hash


    from_physical_id_to_attr_hsh      = Hash.new
    from_file_id_to_order_phys_id_hsh = Hash.new

    divs = get_physical_divs_within
    divs.each { |el|
      attrs = el.attributes
      id    = attrs['ID']

      from_physical_id_to_attr_hsh[id] = {
          'id'         => id,
          'order'      => attrs['ORDER'],
          'orderlabel' => attrs['ORDERLABEL'],
          'type'       => attrs['TYPE'],
          'contentid'  => attrs['CONTENTIDS']
      }

      el['fptr'].each { |fptr|
        from_file_id_to_order_phys_id_hsh[fptr['FILEID']] = id
      }
    }

    return [from_physical_id_to_attr_hsh, from_file_id_to_order_phys_id_hsh]

  end

  def get_logical_page_range(logical_meta, from_logical_id_to_physical_ids_hsh)

    from_physical_id_to_attr_hsh, from_file_id_to_order_phys_id_hsh = get_physical_attr_hash

    from_log_id_to_start_end_hsh = Hash.new
    min, max                     = 1, 1

    while from_logical_id_to_physical_ids_hsh.count > 0

      logical_id, physical_ids = from_logical_id_to_physical_ids_hsh.shift

      begin
        to = from_physical_id_to_attr_hsh[physical_ids.first]&.fetch('order')&.to_i
      rescue Exception => e
        @logger.error("[indexer] Problem to get Hash value\t#{e.message}")
      end

      to  = 1 if (to == nil) or (to == 0)
      max = to if to > max
      min = to if to < min
      addToHash(from_log_id_to_start_end_hsh, logical_id, to)

      begin
        to = from_physical_id_to_attr_hsh[physical_ids.last]&.fetch('order')&.to_i
      rescue Exception => e
        @logger.error("[indexer] Problem to get Hash value\t#{e.message}")
      end

      to  = 1 if (to == nil) or (to == 0)
      max = to if to > max
      min = to if to < min
      addToHash(from_log_id_to_start_end_hsh, logical_id, to)

    end

    logical_meta.phys_first_page_index = min
    logical_meta.phys_last_page_index  = max

    return from_log_id_to_start_end_hsh

  end


  def get_info_from_mets_mptrs(part_url)

    work = ''

    if (@context != nil) && (@context.downcase == "nlh")

      begin
        # https://nl.sub.uni-goettingen.de/mets/ecj:busybody.mets.xml
        match = part_url.match(/(\S*)\/(\S*):(\S*).(mets).(xml)/)
        match = part_url.match(/(\S*)\/(\S*)_(\S*).(mets).(xml)/) if match == nil

        work = match[3]
      rescue Exception => e
        @logger.error("[indexer] No regex match for part URI #{part_url} in parent #{@path} \t#{e.message}")
        raise
      end


    elsif (@context != nil) && (@context.downcase == "gdz")

      count = 0

      # http://gdz.sub.uni-goettingen.de/mets_export.php?PPN=PPN877624038
      begin
        match = part_url.match(/(\S*PPN=)(\S*)/)
        if match == nil
          # http://gdz.sub.uni-goettingen.de/mets/PPN807026034.xml
          match = part_url.match(/(\S*)\/mets\/(\S*).xml/)
        end
        work = match[2]

      rescue Exception => e
        if (match == nil) && (count < 1)
          count += 1

          @logger.error("[indexer] [GDZ-522] - #{@id} - Problem with part URI '#{part_url}'. Remove spaces and processed again!")

          part_url.gsub!(' ', '')

          retry
        end
        @logger.error("[indexer] No regex match for '#{part_url}' in parent #{@id} \t#{e.message}")
        raise
      end
    end

    return {'work' => work, 'product' => @prod}

  end


  def get_attributes_from_logical_div(div, doctype, from_log_id_to_start_end_hsh, base_level, logical_meta, dmdsec_hsh)

    logicalElement = LogicalElement.new

    logicalElement.doctype = doctype
    logicalElement.level   = div.ancestors.length - base_level
    logicalElement.type    = checkEmptyString(div.attributes['TYPE']&.text)
    logicalElement.dmdid   = checkEmptyString(div.attributes['DMDID']&.text)
    logicalElement.id      = checkEmptyString(div.attributes['ID']&.text)
    logicalElement.admid   = checkEmptyString(div.attributes['ADMID']&.text)
    logicalElement.label   = checkEmptyString(div.attributes['LABEL']&.text)
    logicalElement.label   = Mappings.strctype_label(logicalElement.type) if (logicalElement.label == " ") || (logicalElement.label == nil)
    logicalElement.label   = logicalElement.type if (logicalElement.label == " ") || (logicalElement.label == nil)

    logicalElement.dmdsec_meta = dmdsec_hsh[logicalElement.dmdid]

    part_url = div.xpath("mptr[@LOCTYPE='URL']/@href").text

    if !part_url.empty?
      if doctype == "anchor"

        hsh = get_info_from_mets_mptrs(part_url)

        if hsh != nil
          logicalElement.part_product = hsh['product']
          logicalElement.part_work    = hsh['work']
          logicalElement.part_key     = "#{hsh['product']}:#{hsh['work']}"
        end

        return logicalElement

      elsif logicalElement.level == 0

        hsh = get_info_from_mets_mptrs(part_url)

        if hsh != nil
          logicalElement.parentdoc_work   = hsh['work']
          logicalElement.start_page_index = -1
          logicalElement.end_page_index   = -1
        end

        return logicalElement

      end
    end

    logicalElement.isLog_part = true

    if (doctype == "work")

      if (from_log_id_to_start_end_hsh[logicalElement.id] != nil)
        logicalElement.start_page_index = from_log_id_to_start_end_hsh[logicalElement.id]["start"]
        logicalElement.end_page_index   = from_log_id_to_start_end_hsh[logicalElement.id]["end"]

        if logicalElement.type != ' '
          if (logicalElement.type == "titlepage") || (logicalElement.type == "title_page") || (logicalElement.type == "TitlePage") || (logicalElement.type == "Title_Page")
            logical_meta.title_page_index = from_log_id_to_start_end_hsh[logicalElement.id]["start"] if logical_meta.title_page_index == nil

          end
        end

      end

    end

    return logicalElement

  end


  def metsRigthsMDElements(right)

    ri = Right.new

    ri.owner          = "Niedersächsische Staats- und Universitätsbibliothek Göttingen"
    ri.owner          = right['owner'] if @id == "PPN726234869"
    ri.ownerContact   = right['ownerContact']
    ri.ownerSiteURL   = right['ownerSiteURL']
    ri.license        = right['license']
    ri.ownerLogo      = right['ownerLogo']
    ri.sponsor        = right['sponsor']
    ri.sponsorSiteURL = right['sponsorSiteURL']

    return ri

  end

  def metsUri()
    return "http://gdz.sub.uni-goettingen.de/mets/#{@id}" # ".xml"
  end


  def is_work?
    hash_parser = Saxerator.parser(@str_doc)
    el          = hash_parser.for_tag('mets:fileSec').first
    el          = hash_parser.for_tag('METS:fileSec').first if el == nil
    return el
  end

  def getFulltext(xml_path)

    attempts = 0
    fulltext = ""

    begin

      if xml_path.start_with? 'http'

        fulltext = Nokogiri::XML(open(xml_path))
        return fulltext

      else

        fulltext = File.open(xml_path) { |f|
          Nokogiri::XML(f) { |config|
            #config.noblanks
          }
        }
        return fulltext

      end

    rescue Exception => e
      attempts = attempts + 1
      if (attempts < MAX_ATTEMPTS)
        sleep 0.2
        retry
      end
      fileNotFound("fulltext", e)
      return nil
    end

  end

  def get_fulltext_from_s3(file, format)

    #s3://gdz/fulltext/<work_id>/<page>.xml

    if (@context != nil) && (@context.downcase == "nlh")
      s3_fulltext_key = "fulltext/#{@id}/#{file}"
    elsif (@context != nil) && (@context.downcase == "gdz")
      s3_fulltext_key = "fulltext/#{@id}/#{file}"
    end

    attempts = 0
    begin
      resp = @s3.get_object({bucket: @s3_bucket, key: s3_fulltext_key})
      str  = resp.body.read.gsub('"', "'")
      return "" if str.size == 0
      if format == "xml"
        return Nokogiri::XML(str)
      else
        return str   
      end
      
    rescue Exception => e
      attempts = attempts + 1
      if (attempts < MAX_ATTEMPTS)
        sleep 0.2
        retry
      end
      raise e
    end
  end


  def get_str_doc_from_s3

    attempts = 0
    begin
      resp     = @s3.get_object({bucket: @s3_bucket, key: @s3_key})
      @str_doc = resp.body.read
    rescue Exception => e
      attempts = attempts + 1
      if (attempts < MAX_ATTEMPTS)
        sleep 0.2
        retry
      end

      @logger.error("[img_converter] [GDZ-527] Could not download file (#{@s3_bucket}/#{@s3_key}) from S3 \t#{e.message} ")
      raise e
    end
  end


  def get_doc_from_s3
    Nokogiri::XML(@str_doc)
  end

  def get_doc_from_str_doc

    begin
      @doc = Nokogiri::XML(@str_doc)
    rescue Exception => e
      @logger.error("[indexer] Could not build DOM for #{@id}\t#{e.message}")
      return nil
    end
  end

  def get_doc_from_string(xml_str)

    begin
      doc = Nokogiri::XML(xml_str)
    rescue Exception => e
      @logger.error("[indexer] Could not parse part XML String for #{@id}\t#{e.message}")
      return nil
    end

    return doc
  end

  def get_doc_from_ppn(uri)

    attempts = 0

    begin
      @doc = Nokogiri::XML(open(uri))
    rescue Exception => e
      attempts = attempts + 1
      if (attempts < MAX_ATTEMPTS)
        sleep 0.2
        retry
      end
      fileNotFound("METS", e)
      return nil
    end
  end


  def metadata_for_dmdsec(id, mods)

    dmdsec_meta = MetsDmdsecMetadata.new

    dmdsec_meta.dmdid = id

    # Identifier
    dmdsec_meta.addIdentifiers       = getIdentifiers(id, mods)
    dmdsec_meta.addRecordIdentifiers = getRecordIdentifiers(id, mods)


    # Titel
    begin
      if !mods.xpath('titleInfo').empty?
        dmdsec_meta.addTitleInfo = getTitleInfos(mods.xpath('titleInfo'))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve titleInfo for #{@id} (#{e.message})")
    end


    # Erscheinungsort
    begin
      unless mods.xpath('originInfo').empty?
        dmdsec_meta.addOriginalInfo, dmdsec_meta.addEditionInfo = getOriginInfo(mods.xpath('originInfo'))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve originInfo for #{@id} (#{e.message})")
    end


    # Name
    begin
      unless mods.xpath('name').empty?
        dmdsec_meta.addName = getName(mods.xpath('name'))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve name for #{@id} (#{e.message})")
    end


    # Location (shelfmark)
    begin
      unless mods.xpath('location').empty?
        dmdsec_meta.addLocation = getLocation(mods.xpath('location'))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve location for #{@id} (#{e.message})")
    end


    # Genre
    begin
      unless mods.xpath('genre').empty?
        dmdsec_meta.addGenre = getGenre(mods.xpath('genre'))
      end
      unless mods.xpath('subject/genre').empty?
        dmdsec_meta.addSubjectGenre = getGenre(mods.xpath('subject/genre'))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve genre for #{@id} (#{e.message})")
    end


    # Classification
    begin
      unless mods.xpath('classification').empty?
        dmdsec_meta.addClassification = getClassification(mods.xpath('classification[@authority="ZVDD" or @authority="zvdd" or @authority="GDZ" or @authority="gdz"]'))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve classification for #{@id} (#{e.message})")
    end

    # Collection (added for new Goobi Ruleset)
    begin

      unless mods.xpath('extension/edm/isGatheredInto').empty?
        dmdsec_meta.addDigital_collection = getDigitalCollections(mods.xpath('extension/edm/isGatheredInto'))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve digital collections for #{@id} (#{e.message})")
    end


    # Language
    begin
      unless mods.xpath('language').empty?
        dmdsec_meta.addLanguage   = getLanguage(mods.xpath("language[not(scriptTerm and languageTerm[text() = 'und'])]"))
        dmdsec_meta.addScriptTerm = getScriptterm(mods.xpath("language[scriptTerm and languageTerm[text() = 'und']]"))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve language for #{@id} (#{e.message})")
    end


    # PhysicalDescription:
    begin
      unless mods.xpath('physicalDescription').empty?
        dmdsec_meta.addPhysicalDescription = getphysicalDescription(mods.xpath('physicalDescription'))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve physicalDescription for #{@id} (#{e.message})")
    end


    # Note:
    begin
      unless mods.xpath('note').empty?
        dmdsec_meta.addNote = getNote(mods.xpath('note'))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve note for #{@id} (#{e.message})")
    end


    # Sponsor:
    begin
      sponsor = ''

      if !mods.xpath('gdz:sponsorship', 'gdz' => 'http://gdz.sub.uni-goettingen.de/').empty?
        sponsor = mods.xpath('gdz:sponsorship', 'gdz' => 'http://gdz.sub.uni-goettingen.de/').text
      elsif !mods.xpath('GDZ:sponsorship', 'GDZ' => 'http://gdz.sub.uni-goettingen.de/').empty?
        sponsor = mods.xpath('GDZ:sponsorship', 'GDZ' => 'http://gdz.sub.uni-goettingen.de/').text
      end

      dmdsec_meta.addSponsor = sponsor

    rescue Exception => e
      @logger.error("[indexer] Problems to resolve gdz:sponsorship for #{@id} (#{e.message})")
    end


    # Subject:
    begin
      unless mods.xpath('subject').empty?
        dmdsec_meta.addSubject = getSubject(mods.xpath('subject'))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve subject for #{@id} (#{e.message})")
    end


    # RelatedItem
    begin
      unless mods.xpath('relatedItem').empty?
        dmdsec_meta.addRelatedItem = getRelatedItem(mods.xpath('relatedItem'))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve relatedItem for #{@id} (#{e.message})")
    end


    # Part (of multipart Documents)
    begin
      unless mods.xpath('part').empty?
        dmdsec_meta.addPart = getPart(mods.xpath('part'))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve part for #{@id} (#{e.message})")
    end


    # RecordInfo:
    begin
      unless mods.xpath('recordInfo').empty?
        dmdsec_meta.addRecordInfo = getRecordInfo(mods.xpath('recordInfo'))
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve recordInfo for #{@id} (#{e.message})")
    end


    # AccessCondition:
    begin
      unless mods.xpath('accessCondition').empty?
        ac                                 = AccessCondition.new
        ac.value                           = mods.xpath('accessCondition[@type="use and reproduction"]').text
        dmdsec_meta.addAccessConditionInfo = ac
      end
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve accessCondition for #{@id} (#{e.message})")
    end


    # todo put this in a separate section
    # rights info
    begin

      rightsInfoArr = Array.new

      xml_parser = Saxerator.parser(@str_doc) { |config|
        config.output_type = :xml
        config.ignore_namespaces!
        #config.put_attributes_in_hash!
      }

      amdsec = xml_parser.for_tag('amdSec').first.to_s # .each {|amdsec|


      amdsec_parser = Saxerator.parser(amdsec) { |config|
        #xml_parser = Saxerator.parser(@str_doc) {|config|
        #config.output_type = :xml
        #config.ignore_namespaces!
        #config.put_attributes_in_hash!
      }

      right = amdsec_parser.for_tag('rights').each { |right|
        rightsInfoArr << metsRigthsMDElements(right)
      }

      dmdsec_meta.addRightInfo = rightsInfoArr

    rescue Exception => e
      @logger.error("[indexer] Problems to resolve rights info for #{@id} (#{e.message})")
    end

    mods = nil

    return dmdsec_meta

  end

  def check_content_id_date(contentid)

    date = @rredis.hget(@content_id_date_kv_store, contentid)
    if date != nil
      return date
    else
      # YYYY-MM-DDThh:mm:ssZ
      now   = Time.now.utc.to_s.gsub(" UTC", "Z").gsub(" ", "T")
      added = @rredis.hset(@content_id_date_kv_store, contentid, now)
      if !added
        @logger.error("[indexer] Could not add content_id_data to KV-Store: #{e.message}")
      end
      return now
    end
  end

  def retrieve_physical_structure_data(physical_meta)

    from_physical_id_to_attr_hsh, from_file_id_to_order_phys_id_hsh = get_physical_attr_hash

    from_physical_id_to_attr_hsh.each_value { |el|

      physicalElement = PhysicalElement.new

      physicalElement.id         = checkEmptyString(el['id'])
      physicalElement.order      = checkEmptyString(el['order'])
      physicalElement.orderlabel = checkEmptyString(el['orderlabel'])
      physicalElement.ordertype  = checkEmptyString(el['type'])

      contentid                 = checkEmptyString(el['contentid'])
      physicalElement.contentid = contentid

      if (contentid != nil) && (contentid != " ")
        date                                 = check_content_id_date(contentid)
        physicalElement.contentid_changed_at = date
      end

      physical_meta.addToPhysicalElement(physicalElement)
    }

  end


  def metadata_for_structure_elements()

    dmdsec_hsh = Hash.new

    xml_parser = Saxerator.parser(@str_doc) { |config|
      config.output_type = :xml
      config.ignore_namespaces!
      #config.put_attributes_in_hash!
    }

    xml_parser.for_tag('dmdSec').each { |dmdsec|

      dmd_parser = Saxerator.parser(dmdsec.to_s) { |config|
        config.output_type = :xml
        config.ignore_namespaces!
      }

      id = Nokogiri::XML(dmdsec.to_s).child.attributes['ID']&.text

      dmd_parser.for_tag('mods').each { |mods_el|

        mods = Nokogiri::XML(mods_el.to_s).child

        begin
          meta = metadata_for_dmdsec(id, mods)
        rescue Exception => e
          @logger.error("[indexer] Problems ??? (#{e.message})")
        end
        meta.id = "#{@id}___#{id}"

        dmdsec_hsh[id] = meta

      }
    }

    return dmdsec_hsh

  end


  def retrieve_fulltext_data(fulltext_meta)
    begin
      processFulltexts(fulltext_meta)
    rescue Exception => e
      @logger.error("[indexer] Problems to resolve full texts for #{@id} (#{@context}, #{@product})\t#{e.message}")
      @logger.debug("[indexer] Problems to resolve full texts for #{@id} (#{@context}, #{@product})\t#{e.backtrace}")
    end
  end


  def add_key_value_to_hash(hash, id, value)


    if hash[id] == nil
      hash[id] = [value]
    else
      hash[id] << value
    end

  end


  def get_from_logical_id_to_physical_ids_hsh()

    from_logical_id_to_physical_ids_hsh = Hash.new

    xml_parser = Saxerator.parser(@str_doc) { |config|
      #config.output_type = :xml
      config.ignore_namespaces!
      config.put_attributes_in_hash!
    }
    xml_parser.within('structLink').each { |attr|
      add_key_value_to_hash(from_logical_id_to_physical_ids_hsh, attr['xlink:from'], attr['xlink:to'])
    }

    from_logical_id_to_physical_ids_hsh
  end


  def retrieve_logical_structure_data(logical_meta, dmdsec_hsh)
    # e.g.: {"LOG_0000"=>["PHYS_0001", "PHYS_0002", "PHYS_0003", "PHYS_0004", "PHYS_0005", "PHYS_0006"], "LOG_0001"=> ...

    firstmeta                           = ''
    from_logical_id_to_physical_ids_hsh = get_from_logical_id_to_physical_ids_hsh()


    from_log_id_to_start_end_hsh        = get_logical_page_range(logical_meta, from_logical_id_to_physical_ids_hsh) if logical_meta.doctype == "work"

    divs = get_logical_divs_for_tag

    doc = get_doc_from_string(divs.first.to_s)

    base_level = doc.xpath("//div")[0]&.ancestors.length
    doc.xpath("//div").each { |div|

      meta = get_attributes_from_logical_div(
          div,
          logical_meta.doctype,
          from_log_id_to_start_end_hsh,
          base_level,
          logical_meta, dmdsec_hsh)

      logical_meta.addToLogicalElement(meta)

      firstmeta = meta if (meta.isLog_part == true) && (firstmeta == '')
    }


    if (logical_meta.doctype == "anchor") & (logical_meta.logicalElements.empty?)
      @logger.error("[indexer] [GDZ-532] No child documents referenced in '#{@id}'.")
    end

    return firstmeta

  end


  def parseDoc()

    @logger.debug "[indexer] parseDoc -> used: #{GC.stat[:used]}}\n\n"

    @logger.debug "[indexer] (#{@id}) before metadata_for_structure_elements -> used: #{GC.stat[:used]}}\n\n"
    # get metadata
    dmdsec_hsh = metadata_for_structure_elements()

    if is_work?
      doctype = "work"
    else
      doctype = "anchor"
    end

    @logger.debug "[indexer] (#{@id}) before logical-meta -> used: #{GC.stat[:used]}}\n\n"

    # logical structure
    logical_meta          = MetsLogicalMetadata.new
    logical_meta.doctype  = doctype
    logical_meta.work     = @id
    first_logical_element = retrieve_logical_structure_data(logical_meta, dmdsec_hsh)

    begin
      date_modified = ""
      date_indexed  = ""


      if (@reindex == "true") || (@reindex == true)
        solr_resp = (@solr_gdz.get 'select', :params => {:q => "id:#{RSolr.solr_escape @id}", :fl => "date_modified date_indexed"})['response']['docs'].first
        if (solr_resp != nil) && (solr_resp&.size > 0)
          date_modified = solr_resp['date_modified']
          date_indexed  = solr_resp['date_indexed']
        end
      else
        solr_resp = (@solr_gdz_tmp.get 'select', :params => {:q => "id:#{RSolr.solr_escape @id}", :fl => "date_indexed"})['response']['docs'].first
        if (solr_resp != nil) && (solr_resp&.size > 0)
          date_indexed = solr_resp['date_indexed']
        end
      end

      if (date_indexed != "")
        logical_meta.date_indexed  = date_indexed
        logical_meta.date_modified = date_modified if date_modified != ""
      end

    rescue Exception => e
      @logger.error("[indexer] Problem to read date_indexed/date_modified from old index (#{@id}) \t#{e.message}")
      raise
    end

    meta         = dmdsec_hsh[first_logical_element.dmdid] #.clone
    meta.context = @context
    meta.product = @prod
    #meta.product = ENV['SHORT_PRODUCT']
    meta.work = @id


    if is_work?
      meta.iswork   = true
      meta.doctype  = "work"
      meta.isanchor = false
      meta.islog    = false
    else
      meta.iswork = false
      # todo is collection the right naming (it is a multivolume work)
      meta.doctype  = "anchor"
      meta.isanchor = true
      meta.islog    = false

      # todo change this when nlh switch to use a recordId or workId
      if (@context != nil) && (@context.downcase == "nlh")

        # /inpath/METS_Daten/mets_emo_farminstructordiaryno2farmcluny19091920.xml

        begin
          match           = @id.match(/(\S*)\/(\S*)_(\S*)_(\S*).xml/)
          meta.collection = match[4]
          meta.product    = @prod
            #meta.product    = match[3]
        rescue Exception => e
          @logger.error("[indexer] No regex match for collection #{@id} \t#{e.message}")
          raise
        end

      elsif (@context != nil) && (@context.downcase == "gdz")
        meta.collection = @id
      end


    end

    @logger.debug "[indexer] (#{@id}) before physical-meta -> used: #{GC.stat[:used]}}\n\n"
    # get physical structure
    physical_meta = MetsPhysicalMetadata.new
    retrieve_physical_structure_data(physical_meta) if meta.doctype == "work"


    @logger.debug "[indexer] (#{@id}) before image-meta -> used: #{GC.stat[:used]}}\n\n"
    # get image data or collection
    image_meta = MetsImageMetadata.new
    retrieve_image_data(image_meta) if meta.doctype == "work"


    @logger.debug "[indexer] (#{@id}) before fulltext-meta -> used: #{GC.stat[:used]}}\n\n"
    # get fulltexts
    fulltext_meta      = MetsFulltextMetadata.new
    fulltext_meta.work = @id
    retrieve_fulltext_data(fulltext_meta) if meta.doctype == "work"

    @logger.debug "[indexer] (#{@id}) before summary-meta -> used: #{GC.stat[:used]}}\n\n"

    s3_key = "summary/#{@id}/"

    begin
      summaries = @resource.bucket(@s3_bucket).objects({prefix: s3_key})
    rescue Exception => e
      attempts = attempts + 1
      if (attempts < MAX_ATTEMPTS)
        sleep 0.2
        retry
      end

      raise e
    end


    if summaries.count > 0

      summary_arr = Array.new

      summaries.each { |el|

        if el.key.end_with?('html')

          attempts = 0
          begin
            resp    = @s3.get_object({bucket: @s3_bucket, key: el.key})
            doc     = resp.body.read
            content = Nokogiri::HTML(doc).xpath('//text()').to_a.join(" ")

            summary_arr << content
          rescue Exception => e
            attempts = attempts + 1
            if (attempts < MAX_ATTEMPTS)
              sleep 0.2
              retry
            end

            raise e
          end

        end

      }


      summary_meta            = MetsSummaryMetadata.new
      summary_meta.addSummary = summary_arr

    end


    if meta.product != nil && meta.work != nil && image_meta.pages != nil && logical_meta.title_page_index != nil
      logical_meta.title_page = "#{meta.product}:#{meta.work}:#{image_meta.pages[logical_meta.title_page_index - 1]}"
    elsif meta.product != nil && meta.work != nil && image_meta.pages != nil && logical_meta.title_page_index == nil
      logical_meta.title_page = "#{meta.product}:#{meta.work}:#{image_meta.pages[0]}"
    end

    if (meta.doctype != 'anchor') && (image_meta.pages.size != logical_meta.phys_last_page_index&.to_i)
      @logger.error("[indexer] [GDZ-497] - #{@id} - number of pages is not equal physical page size (#{image_meta.pages.size} vs #{logical_meta.phys_last_page_index&.to_i})")
    end


    return {:meta          => meta,
            :logical_meta  => logical_meta,
            :physical_meta => physical_meta,
            :image_meta    => image_meta,
            :fulltext_meta => fulltext_meta,
            :summary_meta  => summary_meta}

  end

  def merge_array(first, second)
    first  = [] if first == nil
    second = [] if second == nil

    return first + second
  end

  def process_response()

    attempts = 0

    begin

      if @context == "gdz"
        @s3_bucket = @gdz_bucket
      elsif @context.downcase.start_with?("nlh")
        @s3_bucket = @prod
      elsif @context == "digizeit"
        # todo
      end

      if (@context != nil) && ((@context.downcase == "gdz") || (@context.downcase == "nlh"))

        if attempts == 0
          @logger.debug "[indexer] Indexing METS: #{@id} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
        else
          @logger.debug "[indexer] Retry Indexing METS: #{@id} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
        end

        get_str_doc_from_s3()
      else
        @logger.error "[indexer] Could not process context '#{@context}'"
        return
      end


      if (@str_doc != nil)

        # [meta, logical_meta, physical_meta, image_meta, fulltext_meta, summary_meta]

        metsModsMetadata = parseDoc()

        if metsModsMetadata != nil

          hsh = Hash.new
          hsh.merge! ({:id => @id})

          hsh.merge! metsModsMetadata[:meta].to_solr_string unless metsModsMetadata[:meta] == nil
          hsh.merge! metsModsMetadata[:logical_meta].to_solr_string unless metsModsMetadata[:logical_meta] == nil
          hsh.merge! metsModsMetadata[:physical_meta].to_solr_string unless metsModsMetadata[:physical_meta] == nil
          hsh.merge! metsModsMetadata[:image_meta].to_solr_string unless metsModsMetadata[:image_meta] == nil
          hsh.merge! metsModsMetadata[:fulltext_meta].to_solr_string unless metsModsMetadata[:fulltext_meta] == nil
          hsh.merge! metsModsMetadata[:summary_meta].to_solr_string unless metsModsMetadata[:summary_meta] == nil


          # todo remove the embedded log fields and use the following (externalized) solr logical documents
          hsh.merge! metsModsMetadata[:logical_meta].to_child_solr_string unless metsModsMetadata[:logical_meta] == nil

          addDocsToSolr(metsModsMetadata[:fulltext_meta].fulltext_to_solr_string) unless metsModsMetadata[:fulltext_meta] == nil

          # todo add fulltexts as child-docs

          addDocsToSolr(hsh)

          if @context.downcase == "nlh"
            #
          elsif @context.downcase == "gdz"
            unless (@reindex == "true") || (@reindex == true)
              create_pdf_conversion(@id, @context, @prod)
            end
          end


          @logger.info "[indexer] Finish indexing METS: #{@id} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
        else
          @logger.error "[indexer] Could not process #{@id} metadata, object is nil "
          # next
        end

      end

    rescue Exception => e
      @logger.error "[indexer] Processing problem with '#{@id}' \nmsg: #{e.message} \nbacktrace: #{e.backtrace}"
    end

  end

  def remove_s3_directory(id)

    return if (id.size < 3) || (id.include? ' ')

    s3_key = "pdf/#{id}/"

    attempts = 0
    begin
      @resource.bucket(@s3_bucket).objects({prefix: s3_key}).batch_delete!
    rescue Exception => e
      attempts = attempts + 1
      if (attempts < MAX_ATTEMPTS)
        sleep 0.2
        retry
      end

      @logger.error("[indexer] Problem to delete s3-key #{s3_key} before conversion \t#{e.message}")
    end

  end

  def create_pdf_conversion(id, context, product)

    begin
      remove_s3_directory(id)

      url = ENV['SERVICES_ADR'] + ENV['CONVERTER_CTX_PATH']

      RestClient.post url, {"document" => id, "log" => id, "context" => context, "product" => product}.to_json, {content_type: :json, accept: :json}

    rescue Exception => e
      @logger.error("[indexer] Problem to create conversion job for #{id} \t#{e.message}")
    end

  end

end

