require 'vertx/vertx'

require 'rsolr'
require 'logger'
require 'nokogiri'
require 'open-uri'
require 'redis'
require 'json'
require 'set'

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
require 'model/logical_element'
require 'model/physical_element'
require 'model/classification'
require 'model/location'
require 'model/fulltext'
require 'model/summary'


# prepare config (gdz): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (gdz): 20 instances, 8GB importer, 3GB redis, 5GB solr

# prepare config (nlh): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (nlh): 8 instances, 8GB importer, 3GB redis, 5GB solr

@dc_hsh = {
    "vd18 digital"   => "vd18.digital",
    "VD18 digital"   => "vd18.digital",
    "vd18 göttingen" => "vd18.göttingen",
    "VD18 göttingen" => "vd18.göttingen"
}

@summary_hsh = {
    "HANS_DE_7_w042080" => {'uri' => "http://wwwuser.gwdg.de/~subtypo3/gdz/misc/summary/HANS_DE_7_w042080/Cantor_Geometrie.html", 'name' => "Cantor_Geometrie"},
    "HANS_DE_7_w042081" => {'uri' => "http://wwwuser.gwdg.de/~subtypo3/gdz/misc/summary/HANS_DE_7_w042081/Cantor_Algebra.html", 'name' => "Cantor_Algebra"}
}

MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

#@oai_endpoint   = ENV['METS_VIA_OAI']
@short_product  = ENV['SHORT_PRODUCT']
@access_pattern = ENV['ACCESS_PATTERN']

productin   = ENV['IN'] + '/' + ENV['PRODUCT']
@teiinpath  = productin + ENV['TEI_IN_SUB_PATH']
@teioutpath = ENV['OUT'] + ENV['TEI_OUT_SUB_PATH']

@fulltextexist = ENV['FULLTEXTS_EXIST']
#@imagefrompdf  = ENV['IMAGE_FROM_PDF']
#@context       = ENV['CONTEXT']

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/mets_indexer_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@logger.debug "[mets_indexer] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@queue  = ENV['REDIS_INDEX_QUEUE']
@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)

@solr = RSolr.connect :url => ENV['SOLR_ADR']

# todo comment in
@s3 = Aws::S3::Client.new(
    :access_key_id     => ENV['S3_AWS_ACCESS_KEY_ID'],
    :secret_access_key => ENV['S3_AWS_SECRET_ACCESS_KEY'],
    :endpoint          => ENV['S3_ENDPOINT'],
    :force_path_style  => true,
    :region            => 'us-west-2')

@nlh_bucket = ENV['S3_NLH_BUCKET']
@gdz_bucket = ENV['S3_GDZ_BUCKET']


def fileNotFound(type, e)
  if e.message.start_with? "redirection forbidden"
    @logger.error("[mets_indexer] [GDZ-527] #{type} #{@id} not available \t#{e.message}")
    @file_logger.error("[mets_indexer] [GDZ-527] #{type} #{@id} not available \t#{e.message}\n\t#{e.backtrace}")
  elsif e.message.start_with? "Failed to open TCP connection"
    @logger.error("[mets_indexer] [GDZ-527] Failed to open #{type} #{@id} because of TCP connection problems \t#{e.message}")
    @file_logger.error("[mets_indexer] [GDZ-527] Failed to open #{type} #{@id} because of TCP connection problems \t#{e.message}\n\t#{e.backtrace}")
  else
    @logger.error("[mets_indexer] Could not open #{type} #{@id} \t#{e.message}")
    @file_logger.error("[mets_indexer] Could not open #{type} #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end
end


def modifyUrisInArray(images, object_uri)
  arr = images.collect {|uri|
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
    if document.class == Array
      @solr.add document # , :add_attributes => {:commitWithin => 10}
    else
      @solr.add [document] # , :add_attributes => {:commitWithin => 10}
    end
    @solr.commit

  rescue Exception => e
    attempts = attempts + 1
    retry if (attempts < MAX_ATTEMPTS)
    @logger.error("[mets_indexer] Could not add doc to solr \t#{e.message}")
    @file_logger.error("[mets_indexer] Could not add doc to solr \t#{e.message}\n\t#{e.backtrace}")
  end
end

def checkEmptyString(str)
  if (str == "") || (str == nil)
    return ' '
  else
    return str
  end
end


def getIdentifiers(mods)

  ids = Array.new

  begin
    identifiers = mods.xpath('mods:identifier', 'mods' => 'http://www.loc.gov/mods/v3')

    #.each do |id_element|

    while identifiers.count > 0

      id_element = identifiers.shift
      type       = id_element.attributes['type']&.value
      type       = "unknown" if type == nil

      id = id_element.text
      ids << "#{type} #{id}"
    end
    identifiers = nil

    recordIdentifiers = mods.xpath('mods:recordInfo/mods:recordIdentifier', 'mods' => 'http://www.loc.gov/mods/v3')

    #.each do |id_element|

    while recordIdentifiers.count > 0

      id_element = recordIdentifiers.shift

      type = id_element.attributes['id']&.value
      type = id_element.attributes['type']&.value if type == nil
      type = "unknown" if type == nil

      id = id_element.text
      ids << "#{type} #{id}"
    end
    recordIdentifiers = nil

  rescue Exception => e
    @logger.error("[mets_indexer] Could not retrieve an identifier for #{@id} \t#{e.message}")
    @file_logger.error("[mets_indexer] Could not retrieve an identifier for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end

  return ids
end


def getRecordIdentifiers(mods)

  ids = Hash.new

  begin
    recordIdentifiers = mods.xpath('mods:identifier[@type="gbv-ppn"]',
                                   'mods' => 'http://www.loc.gov/mods/v3')


    recordIdentifiers = mods.xpath('mods:recordInfo/mods:recordIdentifier[@source="gbv-ppn"]',
                                   'mods' => 'http://www.loc.gov/mods/v3') if recordIdentifiers.empty?


    recordIdentifiers = mods.xpath('mods:identifier[@type="ppn"
        or @type="PPN"]',
                                   'mods' => 'http://www.loc.gov/mods/v3') if recordIdentifiers.empty?

    recordIdentifiers = mods.xpath('mods:identifier[@type="urn"
or @type="URN"]',
                                   'mods' => 'http://www.loc.gov/mods/v3') if recordIdentifiers.empty?

    recordIdentifiers = mods.xpath('mods:recordInfo/mods:recordIdentifier[@source="Kalliope"]',
                                   'mods' => 'http://www.loc.gov/mods/v3') if recordIdentifiers.empty?

    recordIdentifiers = mods.xpath('mods:identifier[@type="DE-7/hans"]',
                                   'mods' => 'http://www.loc.gov/mods/v3') if recordIdentifiers.empty?


    recordIdentifiers = mods.xpath('mods:identifier[@type="local"][not(@invalid="yes")]',
                                   'mods' => 'http://www.loc.gov/mods/v3') if recordIdentifiers.empty?

    recordIdentifiers = mods.xpath('mods:recordInfo/mods:recordIdentifier',
                                   'mods' => 'http://www.loc.gov/mods/v3') if recordIdentifiers.empty?

    while recordIdentifiers.count > 0

      #recordIdentifiers.each do |id_element|
      id_element = recordIdentifiers.shift

      id_source = id_element.attributes['source']
      id_type   = id_element.attributes['type']

      type = id_source&.value
      type = id_type&.value if type == nil
      type = 'recordIdentifier' if type != nil

      id        = id_element.text
      ids[type] = id
    end
    recordIdentifiers = nil

  rescue Exception => e
    @logger.error("[mets_indexer] Could not retrieve the recordidentifier for #{@id} \t#{e.message}")
    @file_logger.error("[mets_indexer] Could not retrieve the recordidentifier for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end

  return ids
end


def get_purl_and_catalogue(doc)

  # info in dv:presentation is build upon the wrong schema
  #purl = doc.xpath("/mets:mets/mets:amdSec/mets:digiprovMD/mets:mdWrap/mets:xmlData/dv:links/dv:presentation", 'mets' => 'http://www.loc.gov/METS/', 'dv' => 'http://dfg-viewer.de/').text
  purl = doc.xpath("/mets:mets/mets:dmdSec/mets:mdWrap/mets:xmlData/mods:mods/mods:identifier[@type='purl']", 'mets' => 'http://www.loc.gov/METS/', 'mods' => 'http://www.loc.gov/mods/v3').text
  purl = doc.xpath("/mets:mets/mets:dmdSec/mets:mdWrap/mets:xmlData/mods:mods/mods:location/mods:url", 'mets' => 'http://www.loc.gov/METS/', 'mods' => 'http://www.loc.gov/mods/v3').text if purl == nil

  catalogue = doc.xpath("/mets:mets/mets:amdSec/mets:digiprovMD/mets:mdWrap/mets:xmlData/dv:links/dv:reference", 'mets' => 'http://www.loc.gov/METS/', 'dv' => 'http://dfg-viewer.de/').map {|el| "OPAC #{el.text}"}

  return [purl, catalogue]
end


def getTitleInfos(modsTitleInfoElements)

  titleInfoArr = Array.new

  while modsTitleInfoElements.count > 0


    ti = modsTitleInfoElements.shift

    titleInfo = TitleInfo.new

    titleInfo.title    = ti.xpath('mods:title', 'mods' => 'http://www.loc.gov/mods/v3').text
    titleInfo.subtitle = checkEmptyString ti.xpath('mods:subTitle', 'mods' => 'http://www.loc.gov/mods/v3').text
    titleInfo.nonsort  = ti.xpath('mods:nonSort', 'mods' => 'http://www.loc.gov/mods/v3').text

    titleInfoArr << titleInfo
  end
  modsTitleInfoElements = nil

  return titleInfoArr
end


def getMissingTitleInfos(modsPartElements, structMapDiv)

  detail = modsPartElements.xpath('mods:detail', 'mods' => 'http://www.loc.gov/mods/v3')
  unless detail.empty?
    currentno = checkEmptyString detail.first.xpath('mods:number', 'mods' => 'http://www.loc.gov/mods/v3').text
    label     = structMapDiv.xpath("@LABEL", 'mets' => 'http://www.loc.gov/METS/').first

    titleInfoArr       = Array.new
    titleInfo          = TitleInfo.new
    titleInfo.title    = label.value + " - Band " + currentno
    titleInfo.subtitle = ""
    titleInfo.nonsort  = ""
    titleInfoArr << titleInfo
  end
  label  = nil
  detail = nil

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
      n.gndNumber = checkEmptyString value[(value.rindex('/')+1)..-1]
    else
      n.gndURI    = ' '
      n.gndNumber = ' '
    end

    roleterm             = name.xpath('mods:role/mods:roleTerm[@type="code"]', 'mods' => 'http://www.loc.gov/mods/v3')
    n.roleterm_authority = checkEmptyString roleterm.xpath('@authority', 'mods' => 'http://www.loc.gov/mods/v3').text
    n.roleterm           = checkEmptyString roleterm.text

    n.family = checkEmptyString name.xpath('mods:namePart[@type="family"]', 'mods' => 'http://www.loc.gov/mods/v3').text
    n.given  = checkEmptyString name.xpath('mods:namePart[@type="given"]', 'mods' => 'http://www.loc.gov/mods/v3').text

    n.displayform = checkEmptyString name.xpath('mods:displayForm', 'mods' => 'http://www.loc.gov/mods/v3').text

    n.namepart = checkEmptyString name.xpath('mods:namePart[not(@type="date")]', 'mods' => 'http://www.loc.gov/mods/v3').text

    n.date = checkEmptyString name.xpath('mods:namePart[@type="date"]', 'mods' => 'http://www.loc.gov/mods/v3').text


    nameArr << n

  end

  modsNameElements = nil

  return nameArr

end


def getLocation(modsLocationElements)

  locationArr = Array.new

  while modsLocationElements.count > 0

    li = modsLocationElements.shift

    locationInfo = Location.new

    shelfmark_l1 = li.xpath("mods:physicalLocation[@type='shelfmark']", 'mods' => 'http://www.loc.gov/mods/v3').text
    shelfmark_l2 = li.xpath("mods:shelfLocator", 'mods' => 'http://www.loc.gov/mods/v3').text

    if (shelfmark_l1 != nil && shelfmark_l1 != '')
      locationInfo.shelfmark = shelfmark_l1
    elsif (shelfmark_l2 != nil && shelfmark_l2 != '')
      locationInfo.shelfmark = shelfmark_l2
    end

    locationArr << locationInfo

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

    classification.value     = c
    classification.authority = checkEmptyString dc["authority"]


    classificationArr << classification

  end
  modsClassificationElements = nil

  return classificationArr
end

def getOriginInfo(modsOriginInfoElements)

  originalInfoArr = Array.new
  editionInfoArr  = Array.new

  while modsOriginInfoElements.count > 0

    oi = modsOriginInfoElements.shift

    originInfo = OriginInfo.new

    originInfo.places     = oi.xpath("mods:place/mods:placeTerm[@type='text']", 'mods' => 'http://www.loc.gov/mods/v3').collect {|el| el.text}
    originInfo.publishers = oi.xpath("mods:publisher", 'mods' => 'http://www.loc.gov/mods/v3').collect {|el| el.text}
    #originInfo.issuance = oi.xpath("mods:issuance", 'mods' => 'http://www.loc.gov/mods/v3').text

    originInfo.edition = oi.xpath("mods:edition", 'mods' => 'http://www.loc.gov/mods/v3').text

    if (originInfo.edition == '[Electronic ed.]')

      # The date on which the resource was digitized or a subsequent snapshot was taken.
      # multi_ dateCaptured[encoding, point, keyDate]/value
      # just the start

      captured_start_date = oi.xpath("mods:dateCaptured[@keyDate='yes' or @point='start']", 'mods' => 'http://www.loc.gov/mods/v3').text
      captured_end_date   = oi.xpath("mods:dateCaptured[@point='end']", 'mods' => 'http://www.loc.gov/mods/v3').text

      captured_start_date = oi.xpath("mods:dateCaptured", 'mods' => 'http://www.loc.gov/mods/v3').text if captured_start_date == ''


      unless captured_start_date == ''
        originInfo.date_captured_string = captured_start_date
        originInfo.check_and_add_date_captured_start(captured_start_date, @id)
      end


      unless captured_end_date == ''
        originInfo.check_and_add_date_captured_end(captured_end_date, @id)
      end


      if originInfo.date_captured_start == 0
        @logger.error("[mets_indexer] [GDZ-546] date_captured_start=0 for #{@id} (check conversion problem)")
        @file_logger.error("[mets_indexer] [GDZ-546] date_captured_start=0 for #{@id} (check conversion problem)")
      end

    else
      # The date that the resource was published, released or issued.
      # multi:  dateIssued[encoding, point, keyDate]/value
      issued_start_date = oi.xpath("mods:dateIssued[@keyDate='yes' or @point='start']", 'mods' => 'http://www.loc.gov/mods/v3').text
      issued_end_date   = oi.xpath("mods:dateIssued[@point='end']", 'mods' => 'http://www.loc.gov/mods/v3').text

      unless issued_start_date == ''
        originInfo.date_issued_string = issued_start_date
        originInfo.check_and_add_date_issued_start(issued_start_date, @id)
      end

      unless issued_end_date == ''
        originInfo.check_and_add_date_issued_end(issued_end_date, @id)
      end

      if originInfo.date_issued_start == 0
        @logger.error("[mets_indexer] [GDZ-546] date_issued_start=0 for #{@id} (check conversion problem)")
        @file_logger.error("[mets_indexer] [GDZ-546] date_issued_start=0 for #{@id} (check conversion problem)")
      end

    end

    if (originInfo.edition == '[Electronic ed.]')
      editionInfoArr << originInfo
    else
      originalInfoArr << originInfo
    end

  end
  modsOriginInfoElements = nil

  return {:original => originalInfoArr, :edition => editionInfoArr}

end

def getLanguage(modsLanguageElements)

  langArr = Array.new
  while modsLanguageElements.count > 0

    l = modsLanguageElements.shift

    lang = LanguageTerm.new

    lang.languageterm = l.xpath('mods:languageTerm', 'mods' => 'http://www.loc.gov/mods/v3').text

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

    # e.g.  => [{"marcform"=>"electronic"}, {"marccategory"=>"electronic resource"}, {"marcsmd"=>"remote"}, {"gmd"=>"electronic resource "}]
    #pd.forms = physdesc.xpath('mods:form', 'mods' => 'http://www.loc.gov/mods/v3').map {|el| {el['authority'] => el.text}}

    forms = Hash.new
    physdesc.xpath('mods:form', 'mods' => 'http://www.loc.gov/mods/v3').each {|el| forms.merge! el['authority'] => el.text}

    pd.form                = forms['marccategory']
    pd.reformattingQuality = physdesc.xpath('mods:reformattingQuality', 'mods' => 'http://www.loc.gov/mods/v3').text
    pd.extent              = physdesc.xpath('mods:extent', 'mods' => 'http://www.loc.gov/mods/v3').text
    pd.digitalOrigin       = physdesc.xpath('mods:digitalOrigin', 'mods' => 'http://www.loc.gov/mods/v3').text

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


    personal   = su.xpath('mods:name[@type="personal"]/mods:namePart', 'mods' => 'http://www.loc.gov/mods/v3')
    corporate  = su.xpath('mods:name[@type="corporate"]/mods:namePart', 'mods' => 'http://www.loc.gov/mods/v3')
    topic      = su.xpath('mods:geographic|mods:topic|mods:temporal', 'mods' => 'http://www.loc.gov/mods/v3')
    geographic = su.xpath('mods:hierarchicalGeographic', 'mods' => 'http://www.loc.gov/mods/v3')


    if !personal.empty?

      subject.type = 'personal'

      str             = personal.collect {|s| s.text if s != nil}.join("; ")
      subject.subject = str


    elsif !corporate.empty?

      subject.type    = 'corporate'
      str             = corporate.collect {|s| s.text if s != nil}.join("; ")
      subject.subject = str


    elsif !geographic.empty?

      subject.type    = 'geographic'
      subject.subject = geographic.children.collect {|s| s.text if (s != nil && s.children != nil)}.join("/")


    elsif !topic.empty?

      subject.type    = 'topic'
      subject.subject = topic.collect {|s| s.child.text if (s != nil && s.child != nil)}.join("/")

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

    relatedItem.id                = checkEmptyString ri.xpath('mods:recordInfo/mods:recordIdentifier', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.title             = checkEmptyString ri.xpath('mods:titleInfo[not(@type="abbreviated")]/mods:title', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.title_abbreviated = checkEmptyString ri.xpath('mods:titleInfo[@type="abbreviated"]/mods:title', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.title_partnumber  = checkEmptyString ri.xpath('mods:titleInfo/mods:partNumber', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.note              = checkEmptyString ri.xpath('mods:note', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.type              = checkEmptyString ri.xpath("@type", 'mods' => 'http://www.loc.gov/mods/v3').text

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

    part.currentnosort = checkEmptyString p.xpath("@order", 'mods' => 'http://www.loc.gov/mods/v3').text

    detail = p.xpath('mods:detail', 'mods' => 'http://www.loc.gov/mods/v3')

    unless detail.empty?
      part.currentno = checkEmptyString detail.first.xpath('mods:number', 'mods' => 'http://www.loc.gov/mods/v3').text
    end

    partArr << part

  end
  return partArr

end


def getRecordInfo(modsRecordInfoElements)
  recordInfoArr = Array.new
  return recordInfoArr
end


def processPresentationImages(doc, image_meta)

  presentation_image_uris_arr = doc.xpath("//mets:fileSec/mets:fileGrp[@USE='DEFAULT']/mets:file/mets:FLocat/@xlink:href", 'mets' => 'http://www.loc.gov/METS/', 'xlink' => 'http://www.w3.org/1999/xlink').to_a

  #path_arr = Array.new
  id_arr   = Array.new
  page_arr = Array.new


  firstUri = presentation_image_uris_arr[0].text

  if (@context != nil) && (@context.downcase == "nlh")

    begin
      # NLH:  https://nl.sub.uni-goettingen.de/image/eai1:0FDAB937D2065D58:0FD91D99A5423158/full/full/0/default.jpg
      match   = firstUri.match(/(\S*)\/(\S*)\/(\S*):(\S*):(\S*)(\/\S*\/\S*\/\S*\/\S*)/)
      baseurl = match[1]
      product = match[3]
      work    = match[4]
    rescue Exception => e
      @logger.error("[mets_indexer] No regex match for NLH/IIIF image URI #{firstUri} \t#{e.message}")
      @file_logger.error("[mets_indexer] No regex match for NLH/IIIF image URI #{firstUri} \t#{e.message}\n\t#{e.backtrace}")
      raise
    end

    image_meta.image_format   = ENV['IMAGE_OUT_FORMAT']
    image_meta.baseurl        = baseurl
    image_meta.access_pattern = @access_pattern
    image_meta.product        = product
    image_meta.work           = work

    while presentation_image_uris_arr.count > 0

      image_uri = presentation_image_uris_arr.shift.text

      begin
        match = image_uri.match(/(\S*\/)(\S*):(\S*):(\S*)(\/\S*\/\S*\/\S*\/\S*)/)
        page  = match[4]
      rescue Exception => e
        @logger.error("[mets_indexer] No regex match for NLH/IIIF image URI #{image_uri} \t#{e.message}")
        @file_logger.error("[mets_indexer] No regex match for NLH/IIIF image URI #{image_uri} \t#{e.message}\n\t#{e.backtrace}")
        raise
      end

      id_arr << "#{product}:#{work}:#{page}"
      page_arr << page
      #path_arr << {"image_uri" => image_uri}.to_json

    end
    presentation_image_uris_arr = nil

  elsif (@context != nil) && (@context.downcase == "gdz")

    begin
      # GDZ:  http://gdz-srv1.sub.uni-goettingen.de/content/PPN663109388/120/0/00000007.jpg
      match = firstUri.match(/(\S*)\/(\S*)\/(\S*)\/(\S*)\/(\S*)\/(\S*)\.(\S*)/)

      baseurl      = match[1]
      work         = match[3]
      image_format = match[7]
    rescue Exception => e
      @logger.error("[mets_indexer] No regex match for GDZ/IIIF image URI #{firstUri} \t#{e.message}")
      @file_logger.error("[mets_indexer] No regex match for GDZ/IIIF image URI #{firstUri} \t#{e.message}\n\t#{e.backtrace}")
      raise
    end

    product = @short_product

    image_meta.image_format   = ENV['IMAGE_OUT_FORMAT']
    image_meta.baseurl        = baseurl
    image_meta.access_pattern = @access_pattern
    image_meta.product        = product
    image_meta.work           = work


    while presentation_image_uris_arr.count > 0

      image_uri = presentation_image_uris_arr.shift.text

      begin
        match = image_uri.match(/(\S*)\/(\S*)\/(\S*)\/(\S*)\/(\S*)\/(\S*)\.(\S*)/)
        page  = match[6]
      rescue Exception => e
        @logger.error("[mets_indexer] No regex match for GDZ/IIIF image URI #{image_uri} \t#{e.message}")
        @file_logger.error("[mets_indexer] No regex match for GDZ/IIIF image URI #{image_uri} \t#{e.message}\n\t#{e.backtrace}")
        raise
      end

      id_arr << "#{product}:#{work}:#{page}"
      page_arr << page
      #path_arr << {"image_uri" => image_uri}.to_json

    end
    presentation_image_uris_arr = nil

  end

  image_meta.add_page_key_arr = id_arr
  image_meta.add_page_arr     = page_arr

end

def getSummary(html_path)

  attempts = 0
  fulltext = ""

  begin

    if html_path.start_with? 'http'

      fulltext = Nokogiri::HTML(open(html_path))
      return fulltext

    else

      fulltext = File.open(html_path) {|f|
        Nokogiri::HTML(f) {|config|
          #config.noblanks
        }
      }
      return fulltext

    end

  rescue Exception => e
    attempts = attempts + 1
    if (attempts < MAX_ATTEMPTS)
      sleep 1
      retry
    end
    fileNotFound("summary", e)
    return nil
  end


end


def getFulltext(xml_path)

  attempts = 0
  fulltext = ""

  begin

    if xml_path.start_with? 'http'

      fulltext = Nokogiri::XML(open(xml_path))
      return fulltext

    else

      fulltext = File.open(xml_path) {|f|
        Nokogiri::XML(f) {|config|
          #config.noblanks
        }
      }
      return fulltext

    end

  rescue Exception => e
    attempts = attempts + 1
    if (attempts < MAX_ATTEMPTS)
      sleep 1
      retry
    end
    fileNotFound("fulltext", e)
    return nil
  end


end

def processSummary(summary_hsh)

  s = Summary.new

  s.summary_name = summary_hsh['name']
  summary_ref    = summary_hsh['uri']
  s.summary_ref  = summary_ref
  content        = getSummary(summary_ref)

  if content == nil
    s.summary_content = "ERROR"
  else
    s.summary_content = content.xpath('//text()').to_a.join(" ")
  end

  return s

end


def processFulltexts(fulltext_meta, doc)


  #fulltext_FLocat = doc.xpath("//mets:fileSec/mets:fileGrp[@USE='FULLTEXT' or @USE='TEI' or @USE='GDZOCR']/mets:file/mets:FLocat", 'mets' => 'http://www.loc.gov/METS/')
  #fulltext_uris   = fulltext_FLocat.xpath("@xlink:href", 'xlink' => 'http://www.w3.org/1999/xlink').collect { |el| el.text }
  fulltext_uris = doc.xpath("//mets:fileSec/mets:fileGrp[@USE='FULLTEXT' or @USE='TEI' or @USE='GDZOCR']/mets:file/mets:FLocat/@xlink:href", 'mets' => 'http://www.loc.gov/METS/', 'xlink' => 'http://www.w3.org/1999/xlink')

  #phy_struct_map = doc.xpath("//mets:structMap[@TYPE='PHYSICAL']", 'mets' => 'http://www.loc.gov/METS/')

  if @fulltextexist == 'true'

    fulltextUriArr = Array.new
    fulltextArr    = Array.new

    #fulltext_uris = fulltext_meta.fulltext_uris
    #firstUri = fulltext_FLocat.first.xpath("@xlink:href", 'xlink' => 'http://www.w3.org/1999/xlink').text
    firstUri = fulltext_uris.first&.text

    if (@context != nil) && (@context.downcase == "nlh")

      begin
        # https://nl.sub.uni-goettingen.de/tei/eai1:0F7AD82E731D8E58:0F7A4A0624995AB0.tei.xml
        match   = firstUri.match(/(\S*)\/(\S*):(\S*):(\S*).(tei).(xml)/)
        product = match[2]
        work    = match[3]
      rescue Exception => e
        @logger.error("[mets_indexer] No regex match for fulltext URI #{firstUri} \t#{e.message}")
        @file_logger.error("[mets_indexer] No regex match for fulltext URI #{firstUri} \t#{e.message}\n\t#{e.backtrace}")
        raise
      end

      while fulltext_uris.count > 0

        uri_node = fulltext_uris.shift
        uri      = uri_node&.text

        fulltext = Fulltext.new

        #  uri = flocat.xpath("@xlink:href", 'xlink' => 'http://www.w3.org/1999/xlink').text

        begin
          match    = uri.match(/(\S*)\/(\S*):(\S*):(\S*).(tei).(xml)/)
          file     = match[4]
          filename = match[4] + '.tei.xml'
        rescue Exception => e
          @logger.error("[mets_indexer] No regex match for fulltext URI #{uri} \t#{e.message}")
          @file_logger.error("[mets_indexer] No regex match for fulltext URI #{uri} \t#{e.message}\n\t#{e.backtrace}")
          fulltext.fulltext             = "ERROR"
          fulltext.fulltext_ref         = "ERROR"
          fulltext.fulltext_of_work     = "ERROR"
          fulltext.fulltext_page_number = "ERROR"

          fulltextArr << fulltext
          next
        end

        from = "#{@teiinpath}/#{work}/#{filename}"
        to   = "#{@teioutpath}/#{product}/#{work}/#{filename}"

        to_dir = "#{@teioutpath}/#{product}/#{work}"

        fulltext.fulltext_of_work = work

        id = uri_node.xpath("parent::*/parent::*/@ID").text

        page_number                   = doc.xpath("//mets:structMap[@TYPE='PHYSICAL']//mets:fptr[@FILEID='#{id}']/parent::*/@ORDER", 'mets' => 'http://www.loc.gov/METS/').text
        fulltext.fulltext_page_number = page_number


        if @fulltextexist == 'true'
          ftext = getFulltext(from)
          if ftext == nil
            fulltext.fulltext     = "ERROR"
            fulltext.fulltext_ref = from
          else
            ftxt = ftext.root.text.gsub(/\s+/, " ").strip
            ftxt.gsub!(/</, "&lt;")
            ftxt.gsub!(/>/, "&gt;")
            fulltext.fulltext     = ftxt
            fulltext.fulltext_ref = from
          end
          fulltextArr << fulltext
        end

        fulltextUriArr << {"fulltexturi" => from, "to" => to, "to_dir" => to_dir}.to_json

      end
      fulltext_uris = nil
    elsif (@context != nil) && (@context.downcase == "gdz")


      begin
        # gdzocr_url": [
        #   "http://gdz.sub.uni-goettingen.de/gdzocr/PPN517650908/00000001.xml",... ]
        match = firstUri.match(/(\S*)\/(\S*)\/(\S*)\/(\S*)\.(\S*)/)
        work  = match[3]
      rescue Exception => e
        @logger.error("[mets_indexer] No regex match for fulltext URI #{firstUri} \t#{e.message}")
        @file_logger.error("[mets_indexer] No regex match for fulltext URI #{firstUri} \t#{e.message}\n\t#{e.backtrace}")
        raise
      end

      product = @short_product

      while fulltext_uris.count > 0

        uri_node = fulltext_uris.shift
        uri      = uri_node&.text

        fulltext = Fulltext.new

        #uri = flocat.xpath("@xlink:href", 'xlink' => 'http://www.w3.org/1999/xlink').text

        begin
          match  = uri.match(/(\S*)\/(\S*)\/(\S*)\/(\S*)\.(\S*)/)
          page   = match[4]
          format = match[5]
          from   = match[0]
        rescue Exception => e
          @logger.error("[mets_indexer] No regex match for fulltext URI #{uri} \t#{e.message}")
          @file_logger.error("[mets_indexer] No regex match for fulltext URI #{uri} \t#{e.message}\n\t#{e.backtrace}")
          fulltext.fulltext             = "ERROR"
          fulltext.fulltext_ref         = "ERROR"
          fulltext.fulltext_of_work     = "ERROR"
          fulltext.fulltext_page_number = "ERROR"

          fulltextArr << fulltext
          next
        end

        #to_dir = "#{@teioutpath}/#{product}/#{work}"

        fulltext.fulltext_of_work = work

        id = uri_node.xpath("parent::*/parent::*/@ID").text
        #id = flocat.xpath("parent::*/@ID").text
        #        phy_struct_map.xpath("mets:fptr[@FILEID=#{id}]").xpath("parent::*/@ORDER").text

        #page_number                   = phy_struct_map.xpath("//mets:fptr[@FILEID='#{id}']", 'mets' => 'http://www.loc.gov/METS/').xpath("parent::*/@ORDER", 'mets' => 'http://www.loc.gov/METS/').text
        page_number                   = doc.xpath("//mets:structMap[@TYPE='PHYSICAL']//mets:fptr[@FILEID='#{id}']/parent::*/@ORDER", 'mets' => 'http://www.loc.gov/METS/').text
        fulltext.fulltext_page_number = page_number

        if @fulltextexist == 'true'
          ftext = getFulltext(from)
          if ftext == nil
            fulltext.fulltext     = "ERROR"
            fulltext.fulltext_ref = from
          else
            ftxt = ftext.root.text.gsub(/\s+/, " ").strip
            ftxt.gsub!(/</, "&lt;")
            ftxt.gsub!(/>/, "&gt;")
            fulltext.fulltext     = ftxt
            fulltext.fulltext_ref = from
          end
          fulltextArr << fulltext
        end

        # todo not required to copy the fulltexts, retrieved via HTTP
        #fulltextUriArr << {"fulltexturi" => fulltexturi, "to" => to, "to_dir" => to_dir}.to_json


      end
      fulltext_uris = nil
    end

    fulltext_meta.addFulltext = fulltextArr


  end

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

def get_logical_page_range(doc, logical_meta, from_logical_id_to_physical_ids_hsh)

  from_log_id_to_start_end_hsh = Hash.new

  min, max = 1, 1

  while from_logical_id_to_physical_ids_hsh.count > 0

    logical_id, physical_ids = from_logical_id_to_physical_ids_hsh.shift

    to  = doc.xpath("//mets:structMap[@TYPE='PHYSICAL']//mets:div[@ID='#{physical_ids.first}']/@ORDER", 'mets' => 'http://www.loc.gov/METS/').text&.to_i
    max = to if to > max
    min = to if to < min
    addToHash(from_log_id_to_start_end_hsh, logical_id, to)


    to  = doc.xpath("//mets:structMap[@TYPE='PHYSICAL']//mets:div[@ID='#{physical_ids.last}']/@ORDER", 'mets' => 'http://www.loc.gov/METS/').text&.to_i
    max = to if to > max
    min = to if to < min
    addToHash(from_log_id_to_start_end_hsh, logical_id, to)


  end

  logical_meta.phys_first_page_index = min
  logical_meta.phys_last_page_index  = max

  return from_log_id_to_start_end_hsh

end


def get_info_from_mets_mptrs(part_url)

  product = ''
  work    = ''

  #if !part_uri.empty?

  #part_uri = mptrs[0].xpath("@xlink:href", 'xlink' => 'http://www.w3.org/1999/xlink').text


  if (@context != nil) && (@context.downcase == "nlh")

    begin
      # https://nl.sub.uni-goettingen.de/mets/ecj:busybody.mets.xml
      match = part_url.match(/(\S*)\/(\S*):(\S*).(mets).(xml)/)
      match = part_url.match(/(\S*)\/(\S*)_(\S*).(mets).(xml)/) if match == nil

      product = match[2]
      work    = match[3]
    rescue Exception => e
      @logger.error("[mets_indexer] No regex match for part URI #{part_url} in parent #{@path} \t#{e.message}")
      @file_logger.error("[mets_indexer] No regex match for part URI #{part_url} in parent #{@path} \t#{e.message}\n\t#{e.backtrace}")
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

      work    = match[2]
      product = "gdz"

    rescue Exception => e
      if (match == nil) && (count < 1)
        count += 1

        @logger.error("[mets_indexer] [GDZ-522] - #{@id} - Problem with part URI '#{part_url}'. Remove spaces and processed again!")
        @file_logger.error("[mets_indexer] [GDZ-522] - #{@id} - Problem with part URI '#{part_url}'. Remove spaces and processed again!")

        part_url.gsub!(' ', '')

        retry
      end
      @logger.error("[mets_indexer] No regex match for '#{part_url}' in parent #{@id} \t#{e.message}")
      @file_logger.error("[mets_indexer] No regex match for '#{part_url}' in parent #{@id} \t#{e.message}\n\t#{e.backtrace}")
      raise
    end
  end

  return {'work' => work, 'product' => product}

  #end

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
  logicalElement.label   = logicalElement.type if (logicalElement.label == " ") || (logicalElement.label == nil)

  logicalElement.dmdsec_meta = dmdsec_hsh[logicalElement.dmdid]

  part_url = div.xpath("mets:mptr[@LOCTYPE='URL']/@xlink:href", 'mets' => 'http://www.loc.gov/METS/', 'xlink' => 'http://www.w3.org/1999/xlink').text


  if !part_url.empty?
    if doctype == "collection"

      hsh = get_info_from_mets_mptrs(part_url)

      if hsh != nil
        logicalElement.part_product = hsh['product']
        logicalElement.part_work    = hsh['work']
        logicalElement.part_key     = "#{hsh['product']}:#{hsh['work']}"
      end

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

  if (doctype == "work")

    if (from_log_id_to_start_end_hsh[logicalElement.id] != nil)
      logicalElement.start_page_index = from_log_id_to_start_end_hsh[logicalElement.id]["start"]
      logicalElement.end_page_index   = from_log_id_to_start_end_hsh[logicalElement.id]["end"]

      if logicalElement.type != ' '
        if (logicalElement.type == "titlepage") || (logicalElement.type == "title_page") || (logicalElement.type == "TitlePage") || (logicalElement.type == "Title_Page")
          logical_meta.title_page_index = from_log_id_to_start_end_hsh[logicalElement.id]["start"] if logical_meta.title_page_index == 1
        end
      end

    end

  end

  return logicalElement

end


=begin

def getLogicalElements(div, log_level_arr, log_start_stop_hsh, doctype, logical_meta, level)
  logicalElement = get_attributes_from_logical_div(div, doctype, log_start_stop_hsh, log_level_arr[level], meta)
  meta.addToLogicalElement(logicalElement)
end
=end


def metsRigthsMDElements(rights)

  ri = Right.new

  if rights != nil

    ri.owner        = "Niedersächsische Staats- und Universitätsbibliothek Göttingen"
    ri.owner        = rights.xpath('dv:owner', 'dv' => 'http://dfg-viewer.de/').text if @id == "PPN726234869"
    ri.ownerContact = rights.xpath('dv:ownerContact', 'dv' => 'http://dfg-viewer.de/').text
    ri.ownerSiteURL = rights.xpath('dv:ownerSiteURL', 'dv' => 'http://dfg-viewer.de/').text
    ri.license      = rights.xpath('dv:license', 'dv' => 'http://dfg-viewer.de/').text

    links        = rights.xpath('dv:links', 'dv' => 'http://dfg-viewer.de/')[0]
    ri.reference = links.xpath('dv:reference', 'dv' => 'http://dfg-viewer.de/').text if links != nil

  end

  return ri

end

def metsUri()
  return "http://gdz.sub.uni-goettingen.de/mets/#{@id}" # ".xml"
end


def checkwork(doc)
  doc.xpath("//mets:fileSec", 'mets' => 'http://www.loc.gov/METS/').first
end


# todo comment in
def get_doc_from_s3 s3_key, s3_bucket
  resp = @s3.get_object({bucket: s3_bucket, key: s3_key})
  Nokogiri::XML(resp.body.read.gsub('"', "'"))
end


def get_doc_from_path()

  attempts = 0
  doc      = ""

  begin
    doc = File.open(@id) {|f|
      Nokogiri::XML(f) {|config|
        config.noblanks
      }
    }
  rescue Exception => e
    attempts = attempts + 1
    if (attempts < MAX_ATTEMPTS)
      sleep 1
      retry
    end
    fileNotFound("METS", e)
    return nil
  end

  return doc

end

def get_doc_from_ppn(uri)

  attempts = 0
  doc      = ""

  begin
    doc = Nokogiri::XML(open(uri))
  rescue Exception => e
    attempts = attempts + 1
    if (attempts < MAX_ATTEMPTS)
      sleep 1
      retry
    end
    fileNotFound("METS", e)
    return nil
  end

  return doc

end


def metadata_for_dmdsec(doc, dmdSec_id)

  dmdsec_meta = MetsDmdsecMetadata.new

  mods = doc.xpath("//mets:dmdSec[@ID='#{dmdSec_id}']/mets:mdWrap/mets:xmlData/mods:mods", 'mods' => 'http://www.loc.gov/mods/v3', 'mets' => 'http://www.loc.gov/METS/')

  # Identifier
  dmdsec_meta.addIdentifiers       = getIdentifiers(mods)
  dmdsec_meta.addRecordIdentifiers = getRecordIdentifiers(mods)

  dmdsec_meta.addPurl, dmdsec_meta.addCatalogue = get_purl_and_catalogue(doc)

  # Titel
  begin

    if !mods.xpath('mods:titleInfo', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      dmdsec_meta.addTitleInfo = getTitleInfos(mods.xpath('mods:titleInfo', 'mods' => 'http://www.loc.gov/mods/v3'))
    elsif !mods.xpath('mods:titleInfo/mods:detail/mods:number', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      modsPartElements         = mods.xpath('mods:part', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text
      structMapDiv             = doc.xpath("//mets:structMap[@TYPE='LOGICAL']/mets:div[@LABEL]", 'mets' => 'http://www.loc.gov/METS/').first
      dmdsec_meta.addTitleInfo = getMissingTitleInfos(modsPartElements, structMapDiv)
    end

  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve mods:titleInfo for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve mods:titleInfo for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end


  # Erscheinungsort
  begin

    unless mods.xpath('mods:originInfo', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      originInfoHash              = getOriginInfo(mods.xpath('mods:originInfo', 'mods' => 'http://www.loc.gov/mods/v3'))
      dmdsec_meta.addOriginalInfo = originInfoHash[:original]
      dmdsec_meta.addEditionInfo  = originInfoHash[:edition]
    end


  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve mods:originInfo for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve mods:originInfo for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end


  # Name
  begin


    unless mods.xpath('mods:name', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      dmdsec_meta.addName = getName(mods.xpath('mods:name', 'mods' => 'http://www.loc.gov/mods/v3'))
    end


  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve mods:name for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve mods:name for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end


  # Location (shelfmark)
  begin

    unless mods.xpath('mods:location', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      dmdsec_meta.addLocation = getLocation(mods.xpath('mods:location', 'mods' => 'http://www.loc.gov/mods/v3'))
    end


  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve mods:location for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve mods:location for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end


  # Genre
  begin

    unless mods.xpath('mods:genre', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      dmdsec_meta.addGenre = getGenre(mods.xpath('mods:genre', 'mods' => 'http://www.loc.gov/mods/v3'))
    end


    unless mods.xpath('mods:subject/mods:genre', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      dmdsec_meta.addSubjectGenre = getGenre(mods.xpath('mods:subject/mods:genre', 'mods' => 'http://www.loc.gov/mods/v3'))
    end


  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve mods:genre for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve mods:genre for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end

  # Classification
  begin

    unless mods.xpath('mods:classification', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      dmdsec_meta.addClassification = getClassification(mods.xpath('mods:classification', 'mods' => 'http://www.loc.gov/mods/v3'))
    end


  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve mods:classification for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve mods:classification for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end


  # Language
  begin

    unless mods.xpath('mods:language', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      dmdsec_meta.addLanguage = getLanguage(mods.xpath('mods:language', 'mods' => 'http://www.loc.gov/mods/v3'))
    end


  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve mods:language for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve mods:language for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end

  # PhysicalDescription:
  begin

    unless mods.xpath('mods:physicalDescription', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      dmdsec_meta.addPhysicalDescription = getphysicalDescription(mods.xpath('mods:physicalDescription', 'mods' => 'http://www.loc.gov/mods/v3'))
    end


  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve mods:physicalDescription for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve mods:physicalDescription for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end


  # Note:
  begin

    unless mods.xpath('mods:note', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      dmdsec_meta.addNote = getNote(mods.xpath('mods:note', 'mods' => 'http://www.loc.gov/mods/v3'))
    end


  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve mods:note for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve mods:note for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end


  # Sponsor:
  begin

    unless mods.xpath('gdz:sponsorship', 'gdz' => 'http://gdz.sub.uni-goettingen.de/').empty?
      dmdsec_meta.addSponsor = mods.xpath('gdz:sponsorship', 'gdz' => 'http://gdz.sub.uni-goettingen.de/').text
    end


  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve gdz:sponsorship for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve gdz:sponsorship for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end


  # Subject:
  begin

    unless mods.xpath('mods:subject', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      dmdsec_meta.addSubject = getSubject(mods.xpath('mods:subject', 'mods' => 'http://www.loc.gov/mods/v3'))
    end


  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve mods:subject for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve mods:subject for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end

  # RelatedItem
  begin

    unless mods.xpath('mods:relatedItem', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      dmdsec_meta.addRelatedItem = getRelatedItem(mods.xpath('mods:relatedItem', 'mods' => 'http://www.loc.gov/mods/v3'))
    end


  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve mods:relatedItem for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve mods:relatedItem for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end

  # Part (of multipart Documents)
  begin

    unless mods.xpath('mods:part', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      dmdsec_meta.addPart = getPart(mods.xpath('mods:part', 'mods' => 'http://www.loc.gov/mods/v3'))
    end


  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve mods:part for #{@id} (#{e.message})\n#{e.backtrace}")
    @file_logger.error("[mets_indexer] Problems to resolve mods:part for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end


  # RecordInfo:
  begin

    unless mods.xpath('mods:recordInfo', 'mods' => 'http://www.loc.gov/mods/v3').empty?
      dmdsec_meta.addRecordInfo = getRecordInfo(mods.xpath('mods:recordInfo', 'mods' => 'http://www.loc.gov/mods/v3'))
    end


  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve mods:recordInfo for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve mods:recordInfo for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end

  # rights info
  begin

    rightsInfoArr = Array.new

    doc.xpath("//mets:amdSec/mets:rightsMD/mets:mdWrap/mets:xmlData", 'mets' => 'http://www.loc.gov/METS/').each {|right|

      rights = right.xpath('dv:rights', 'dv' => 'http://dfg-viewer.de/')[0]
      rights = right.xpath('dv:rights', 'dv' => 'http://dfg-viewer.de')[0] if rights == nil


      rightsInfoArr << metsRigthsMDElements(rights)
    }

    dmdsec_meta.addRightInfo = rightsInfoArr

  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve rights info for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve rights info for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end

  return dmdsec_meta

end

def metadata_for_structure_elements(doc)

  dmdsec_hsh = Hash.new

  doc.xpath('//mets:dmdSec/@ID', 'mods' => 'http://www.loc.gov/mods/v3', 'mets' => 'http://www.loc.gov/METS/').map {|el|

    dmdSec_id = el.text

    dmdsec_hsh[dmdSec_id] = metadata_for_dmdsec(doc, dmdSec_id)

  }


  first_dmd_id                      = dmdsec_hsh.keys.sort.first
  dmdsec_hsh[first_dmd_id].is_child = false

  return dmdsec_hsh

end

def retrieve_fulltext_data(doc, fulltext_meta)
  begin
    unless doc.xpath("//mets:fileSec/mets:fileGrp[@USE='FULLTEXT' or @USE='TEI' or @USE='GDZOCR']/mets:file/mets:FLocat", 'mets' => 'http://www.loc.gov/METS/').empty?
      processFulltexts(fulltext_meta, doc)
    end
  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve full texts for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve full texts for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end
end

def retrieve_image_data(doc, image_meta)

  begin
    processPresentationImages(doc, image_meta)
  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve presentation images for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve presentation images for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end

end


def retrieve_summary_data(doc, summary_meta)
  begin
    summary_meta.addSummary = [processSummary(@summary_hsh[@id])]
  rescue Exception => e
    @logger.error("[mets_indexer] Problems to resolve summary texts for #{@id} (#{e.message})")
    @file_logger.error("[mets_indexer] Problems to resolve summary texts for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end
end

def get_from_logical_id_to_physical_ids_hsh(doc)
  from_logical_id_to_physical_ids_hsh = Hash.new
  doc.xpath("//mets:structMap[@TYPE='LOGICAL']//mets:div/@ID", 'mets' => 'http://www.loc.gov/METS/').map {|el| el.text}.each {|el|
    from_logical_id_to_physical_ids_hsh[el] = doc.xpath("//mets:structLink/mets:smLink[@xlink:from='#{el}']/@xlink:to", 'mets' => 'http://www.loc.gov/METS/', 'xlink' => "http://www.w3.org/1999/xlink").map {|e| e.text}
  }
  from_logical_id_to_physical_ids_hsh
end


def retrieve_logical_structure_data(doc, logical_meta, dmdsec_hsh)
  # e.g.: {"LOG_0000"=>["PHYS_0001", "PHYS_0002", "PHYS_0003", "PHYS_0004", "PHYS_0005", "PHYS_0006"], "LOG_0001"=> ...


  from_log_id_to_start_end_hsh = get_logical_page_range(doc, logical_meta, get_from_logical_id_to_physical_ids_hsh(doc)) if logical_meta.doctype == "work"

  base_level = doc.xpath("//mets:structMap[@TYPE='LOGICAL']//mets:div", 'mets' => 'http://www.loc.gov/METS/')[0]&.ancestors.length
  div_arr    = doc.xpath("//mets:structMap[@TYPE='LOGICAL']//mets:div", 'mets' => 'http://www.loc.gov/METS/')

  while div_arr.count > 0

    div = div_arr.shift

    logical_meta.addToLogicalElement(
        get_attributes_from_logical_div(
            div,
            logical_meta.doctype,
            from_log_id_to_start_end_hsh,
            base_level,
            logical_meta, dmdsec_hsh))

  end
  base_level                   = nil
  from_log_id_to_start_end_hsh = nil
  log_id_arr                   = nil


  if (logical_meta.doctype == "collection") & (logical_meta.logicalElements.empty?)
    @logger.error("[mets_indexer] [GDZ-532] No child documents referenced in '#{@id}'.")
    @file_logger.error("[mets_indexer] [GDZ-532] No child documents referenced in '#{@id}'.")
  end
end

def retrieve_physical_structure_data(doc, physical_meta)

  level       = 0
  phys_id_arr = doc.xpath("//mets:structMap[@TYPE='PHYSICAL']//mets:div/@ID", 'mets' => 'http://www.loc.gov/METS/')

  while phys_id_arr.count > 0

    phys_id = phys_id_arr.shift.text

    if level == 0
      level += 1
      next
    end

    physicalElement = PhysicalElement.new

    div_attributes_hsh = doc.xpath("//mets:structMap[@TYPE='PHYSICAL']//mets:div[@ID='#{phys_id}']", 'mets' => 'http://www.loc.gov/METS/').first.attributes

    physicalElement.id         = checkEmptyString(div_attributes_hsh['ID']&.value)
    physicalElement.order      = checkEmptyString(div_attributes_hsh['ORDER']&.value)
    physicalElement.orderlabel = checkEmptyString(div_attributes_hsh['ORDERLABEL']&.value)
    physicalElement.ordertype  = checkEmptyString(div_attributes_hsh['TYPE']&.value)

    physical_meta.addToPhysicalElement(physicalElement)

    div_attributes_hsh = nil

    level += 1


  end

  phys_id_arr = nil

end

def parseDoc(doc)

  # meta = MetsDmdsecMetadata.new


  # get metadata
  dmdsec_hsh = metadata_for_structure_elements(doc)

  first_dmd_id = dmdsec_hsh.keys.sort.first

  meta = dmdsec_hsh[first_dmd_id]

  meta.context = @context
  meta.product = ENV['SHORT_PRODUCT']
  meta.work    = @id


  if checkwork(doc) != nil
    meta.iswork  = true
    meta.doctype = "work"
  else
    meta.iswork = false
    # todo is collection the right naming (it is a multivolume work)
    meta.doctype  = "collection"
    meta.isanchor = true

    # todo change this when nlh has switched to use a recordId or workId
    if (@context != nil) && (@context.downcase == "nlh")

      # /inpath/METS_Daten/mets_emo_farminstructordiaryno2farmcluny19091920.xml

      begin
        match           = @id.match(/(\S*)\/(\S*)_(\S*)_(\S*).xml/)
        meta.collection = match[4]
        meta.product    = match[3]
      rescue Exception => e
        @logger.error("[mets_indexer] No regex match for collection #{@id} \t#{e.message}")
        @file_logger.error("[mets_indexer] No regex match for collection #{@id} \t#{e.message}\n\t#{e.backtrace}")
        raise
      end

    elsif (@context != nil) && (@context.downcase == "gdz")
      meta.collection = @id
    end


  end


  # logical structure
  logical_meta         = MetsLogicalMetadata.new
  logical_meta.doctype = meta.doctype
  logical_meta.work    = @id
  retrieve_logical_structure_data(doc, logical_meta, dmdsec_hsh)


  # get physical structure
  physical_meta = MetsPhysicalMetadata.new
  # <product_id>:<work_id>:<seiten-bezeichner>
  retrieve_physical_structure_data(doc, physical_meta) if meta.doctype == "work"


  # get image data or collection
  image_meta = MetsImageMetadata.new
  retrieve_image_data(doc, image_meta) if meta.doctype == "work"


  # get fulltexts
  fulltext_meta = MetsFulltextMetadata.new
  retrieve_fulltext_data(doc, fulltext_meta) if meta.doctype == "work"


  # get summary(id)
  if @summary_hsh[@id]
    summary_meta = MetsSummaryMetadata.new
    retrieve_summary_data(doc, summary_meta)
  end

  unless meta.product == nil || meta.work == nil || image_meta.pages == nil || logical_meta.title_page_index == nil
    logical_meta.title_page = "#{meta.product}:#{meta.work}:#{image_meta.pages[logical_meta.title_page_index - 1]}"
  end

  # add MODS
  begin
    mods      = doc.xpath('//mods:mods', 'mods' => 'http://www.loc.gov/mods/v3')[0]
    meta.mods = mods.to_xml
  rescue Exception => e
    @logger.error "[mets_indexer] Could not get MODS XML for #{@id} \t#{e.message}"
    @file_logger.error("[mets_indexer] Could not get MODS XML for #{@id} \t#{e.message}\n\t#{e.backtrace}")
  end


  # do some data checks
  if (meta.doctype != 'collection') && (image_meta.pages.size != logical_meta.phys_last_page_index)
    @logger.error("[mets_indexer] [GDZ-497] - #{@id} - number of pages is not equal physical page size")
    @file_logger.error("[mets_indexer] [GDZ-497] - #{@id} - number of pages is not equal physical page size")
  end


  return {:meta          => meta,
          :logical_meta  => logical_meta,
          :physical_meta => physical_meta,
          :image_meta    => image_meta,
          :fulltext_meta => fulltext_meta,
          :summary_meta  => summary_meta}

end


$vertx.execute_blocking(lambda {|future|

  from_s3 = true

  while true do

    res = @rredis.brpop(@queue)

    attempts = 0

    begin

      if (res != '' && res != nil)

        doc = ''

        # {"s3_key" => key, "context" => context}.to_json
        # s3_obj_key= mets/<id>.xml
        msg  = res[1]
        json = JSON.parse msg

        @context = json['context']
        s3_key   = json['s3_key']


        s3_bucket = ''

        case @context
          when 'nlh'
            s3_bucket = @nlh_bucket
          when 'gdz'
            s3_bucket = @gdz_bucket
        end


        puts "@context: #{@context}, s3_key: #{s3_key}, s3_bucket: #{s3_bucket}"


        @id = s3_key.match(/mets\/([\S\s]*)(.xml)/)[1]

        if from_s3

          if (@context != nil) && ((@context.downcase == "gdz") || (@context.downcase == "nlh"))

            if attempts == 0
              @logger.info "[mets_indexer] Indexing METS: #{@id} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
            else
              @logger.info "[mets_indexer] Retry Indexing METS: #{@id} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
            end

            doc = get_doc_from_s3(s3_key, s3_bucket)

          else
            @logger.error "[mets_indexer] Could not process context '#{@context}'"
            next
          end

        else

          # todo remove for prod
          if (@context.downcase == "gdz")
            doc = get_doc_from_ppn(metsUri())
          elsif (@context.downcase == "nlh")
            doc = get_doc_from_path()
          end
          # end remove

        end


        if doc != nil

          # [meta, logical_meta, physical_meta, image_meta, fulltext_meta, summary_meta]
          metsModsMetadata = parseDoc(doc)

          if metsModsMetadata != nil
            hsh = Hash.new
            metsModsMetadata.each_value {|part|
              hsh.merge! part.to_solr_string unless part == nil
            }

            # todo remove the embedded log fields and use the following (externalized) solr logical documents
            hsh.merge! metsModsMetadata[:logical_meta].to_child_solr_string

            # todo add fulltexts as child-docs

            addDocsToSolr(hsh)

            addDocsToSolr(metsModsMetadata[:fulltext_meta].fulltext_to_solr_string) unless metsModsMetadata[:fulltext_meta] == nil

            @logger.info "[mets_indexer] Finish indexing METS: #{@id} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
          else
            @logger.error "[mets_indexer] Could not process #{@id} metadata, object is nil "
            @file_logger.error "[mets_indexer] Could not process #{@id} metadata, object is nil"
            next
          end
        end

      end

    rescue Exception => e
      @logger.error "[mets_indexer] Processing problem with '#{res[1]}' \t#{e.message}\n\t#{e.backtrace}"
      attempts = attempts + 1
      retry if (attempts < MAX_ATTEMPTS)
      @file_logger.error "[mets_indexer] Could not process redis data '#{res[1]}'  \t#{e.message}\n\t#{e.backtrace}"
    end

  end

  # future.complete(doc.to_s)

}) {|res_err, res|
#
}


