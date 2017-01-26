require 'vertx/vertx'
require 'rsolr'
require 'logger'
require 'nokogiri'
require 'open-uri'
require 'redis'
require 'json'
require 'set'
require 'lib/mets_mods_metadata'
require 'lib/title_info'
require 'lib/origin_info'
require 'lib/name'
require 'lib/genre'
require 'lib/language'
require 'lib/related_item'
require 'lib/part'
require 'lib/record_info'
require 'lib/physical_description'
require 'lib/subject'
require 'lib/note'
require 'lib/right'
require 'lib/logical_element'


MAX_ATTEMPTS        = ENV['MAX_ATTEMPTS'].to_i
@oai_endpoint       = ENV['METS_VIA_OAI']
@short_product      = ENV['SHORT_PRODUCT']
@teiinpath          = ENV['IN'] + ENV['TEI_IN_SUB_PATH']
@teioutpath         = ENV['OUT'] + ENV['TEI_OUT_SUB_PATH']
@originpath         = ENV['ORIG']
#@from_orig = ENV['GET_IMAGES_FROM_ORIG']
#@image_from_orig = ENV['GET_IMAGES_FROM_ORIG']
@fulltext_from_orig = ENV['GET_FULLTEXT_FROM_ORIG']
@fulltextexist      = ENV['FULLTEXTS_EXIST']
#@imagefrompdf  = ENV['IMAGE_FROM_PDF']
@context            = ENV['CONTEXT']


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/nlh_mets_indexer.log")
@file_logger.level = Logger::DEBUG

@logger.debug "[mets_indexer worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

@rredis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i, :db => ENV['REDIS_DB'].to_i)
@solr   = RSolr.connect :url => ENV['SOLR_ADR']


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
    @solr.add [document] # , :add_attributes => {:commitWithin => 10}
    @solr.commit

#    @rredis.incr 'indexed'

  rescue Exception => e
    attempts = attempts + 1
    retry if (attempts < MAX_ATTEMPTS)
    @logger.error("Could not add doc to solr\n\t#{e.message}\n\t#{e.backtrace}")
  end
end

def checkEmptyString(str)
  if (str == "") || (str == nil)
    return ' '
  else
    return str
  end
end


def getIdentifiers(mods, source)

  ids = Hash.new

  begin
    identifiers = mods.xpath('mods:identifier', 'mods' => 'http://www.loc.gov/mods/v3')
    identifiers.each do |id_element|
      type      = id_element.attributes['type'].value
      id        = id_element.text
      ids[type] = id
    end
  rescue Exception => e
    @logger.error("Could not retrieve an identifier for #{source}\n\t#{e.message}\n\t#{e.backtrace}")
  end

  return ids
end


def getRecordIdentifiers(mods, source)

  ids = Hash.new

  begin
    recordIdentifiers = mods.xpath('mods:recordInfo/mods:recordIdentifier', 'mods' => 'http://www.loc.gov/mods/v3')

    if recordIdentifiers.empty?
      recordIdentifiers = mods.xpath('mods:recordInfo/mods:recordIdentifer', 'mods' => 'http://www.loc.gov/mods/v3')
    end

    recordIdentifiers.each do |id_element|
      id_source = id_element.attributes['source']
      if id_source != nil
        type = id_element.attributes['source'].value
      else
        type = 'recordIdentifier'
      end
      id        = id_element.text
      ids[type] = id
    end
  rescue Exception => e
    @logger.error("Could not retrieve the recordidentifier for #{source}\n\t#{e.message}\n\t#{e.backtrace}")
  end

  return ids
end


def getTitleInfos(modsTitleInfoElements)

  titleInfoArr = Array.new
  modsTitleInfoElements.each { |ti|
    titleInfo = TitleInfo.new

    titleInfo.title = ti.xpath('mods:title', 'mods' => 'http://www.loc.gov/mods/v3').text

    titleInfo.subtitle = checkEmptyString ti.xpath('mods:subTitle', 'mods' => 'http://www.loc.gov/mods/v3').text

    titleInfo.nonsort = ti.xpath('mods:nonSort', 'mods' => 'http://www.loc.gov/mods/v3').text

    # if nonsort == ""
    #   nonsort = titleInfo.title
    # else
    #   nonsort = nonsort + ' ' if (nonsort[-1] != " ")
    #   nonsort = nonsort + titleInfo.title
    # end
    #
    #titleInfo.nonsort = nonsort

    titleInfoArr << titleInfo
  }

  return titleInfoArr
end


def getName(modsNameElements)

  nameArr = Array.new

  modsNameElements.each { |name|

    n = Name.new

    n.type        = checkEmptyString name['type']
    n.displayform = checkEmptyString name.xpath('mods:displayForm', 'mods' => 'http://www.loc.gov/mods/v3').text
    n.role        = checkEmptyString name.xpath('mods:role/mods:roleTerm[@type="code"]', 'mods' => 'http://www.loc.gov/mods/v3').text
    namepart      = name.xpath('mods:namePart[@type="family"]', 'mods' => 'http://www.loc.gov/mods/v3')
    namepart      = name.xpath('mods:namePart[not(@type="date")]', 'mods' => 'http://www.loc.gov/mods/v3') if namepart.empty?
    n.namepart    = checkEmptyString namepart.text
    n.date        = checkEmptyString name.xpath('mods:namePart[@type="date"]', 'mods' => 'http://www.loc.gov/mods/v3').text

    nameArr << n
  }

  return nameArr

end

def getTypeOfResource(modsTypeOfResourceElements)

  typeOfResourceArr = Array.new

  return typeOfResourceArr
end


def getGenre(modsGenreElements)

  genreArr = Array.new
  modsGenreElements.each { |g|
    genre = Genre.new

    genre.genre = g.text

    genreArr << genre
  }

  return genreArr
end


def getOriginInfo(modsOriginInfoElements)

  originalInfoArr = Array.new
  editionInfoArr  = Array.new

  modsOriginInfoElements.each { |oi|

    originInfo = OriginInfo.new

    originInfo.place     = oi.xpath("mods:place/mods:placeTerm[@type='text']", 'mods' => 'http://www.loc.gov/mods/v3').text
    originInfo.publisher = oi.xpath("mods:publisher", 'mods' => 'http://www.loc.gov/mods/v3').text
    #originInfo.issuance = oi.xpath("mods:issuance", 'mods' => 'http://www.loc.gov/mods/v3').text

    originInfo.edition   = oi.xpath("mods:edition", 'mods' => 'http://www.loc.gov/mods/v3').text

    if (originInfo.edition == '[Electronic ed.]')

      # The date on which the resource was digitized or a subsequent snapshot was taken.
      # multi_ dateCaptured[encoding, point, keyDate]/value
      # just the start
      captured_start_date = oi.xpath("mods:dateCaptured[@keyDate='yes']", 'mods' => 'http://www.loc.gov/mods/v3').text
      captured_end_date   = oi.xpath("mods:dateCaptured[@point='end']", 'mods' => 'http://www.loc.gov/mods/v3').text

      originInfo.date_captured_start = captured_start_date.to_i

      unless captured_end_date == ''
        originInfo.date_captured_end = captured_end_date.to_i
      else
        originInfo.date_captured_end = captured_start_date.to_i
      end


    else
      # The date that the resource was published, released or issued.
      # multi:  dateIssued[encoding, point, keyDate]/value
      issued_start_date = oi.xpath("mods:dateIssued[@keyDate='yes']", 'mods' => 'http://www.loc.gov/mods/v3').text
      issued_end_date   = oi.xpath("mods:dateIssued[@point='end']", 'mods' => 'http://www.loc.gov/mods/v3').text

      originInfo.date_issued_start = issued_start_date.to_i

      unless issued_end_date == ''
        originInfo.date_issued_end = issued_end_date.to_i
      else
        originInfo.date_issued_end = issued_start_date.to_i
      end

    end

    if (originInfo.edition == '[Electronic ed.]')
      editionInfoArr << originInfo
    else
      originalInfoArr << originInfo
    end

  }

  return {:original => originalInfoArr, :edition => editionInfoArr}

end

def getLanguage(modsLanguageElements)

  langArr = Array.new
  modsLanguageElements.each { |l|
    lang = LanguageTerm.new

    lang.languageterm = l.xpath('mods:languageTerm', 'mods' => 'http://www.loc.gov/mods/v3').text

    langArr << lang
  }

  return langArr
end


def getphysicalDescription(modsPhysicalDescriptionElements)

  physicalDescriptionArr = Array.new

  modsPhysicalDescriptionElements.each { |physdesc|
    pd    = PhysicalDescription.new

    # e.g.  => [{"marcform"=>"electronic"}, {"marccategory"=>"electronic resource"}, {"marcsmd"=>"remote"}, {"gmd"=>"electronic resource "}]
    #pd.forms = physdesc.xpath('mods:form', 'mods' => 'http://www.loc.gov/mods/v3').map {|el| {el['authority'] => el.text}}

    forms = Hash.new
    physdesc.xpath('mods:form', 'mods' => 'http://www.loc.gov/mods/v3').each { |el| forms.merge! el['authority'] => el.text }

    pd.form                = forms['marccategory']
    pd.reformattingQuality = physdesc.xpath('mods:reformattingQuality', 'mods' => 'http://www.loc.gov/mods/v3').text
    pd.extent              = physdesc.xpath('mods:extent', 'mods' => 'http://www.loc.gov/mods/v3').text
    pd.digitalOrigin       = physdesc.xpath('mods:digitalOrigin', 'mods' => 'http://www.loc.gov/mods/v3').text

    physicalDescriptionArr << pd
  }

  return physicalDescriptionArr
end


def getNote(modsNoteElements)

  noteArr = Array.new


  modsNoteElements.each { |note|
    n       = Note.new

    # :type, :note

    n.type  = checkEmptyString note["type"]
    n.value = checkEmptyString note.text

    noteArr << n
  }


  return noteArr
end


def getSubject(modsSubjectElements)

  subjectArr = Array.new

  modsSubjectElements.each { |su|
    subject = Subject.new


    personal   = su.xpath('mods:name[@type="personal"]/mods:namePart', 'mods' => 'http://www.loc.gov/mods/v3')
    corporate  = su.xpath('mods:name[@type="corporate"]/mods:namePart', 'mods' => 'http://www.loc.gov/mods/v3')
    topic      = su.xpath('mods:geographic|mods:topic|mods:temporal', 'mods' => 'http://www.loc.gov/mods/v3')
    geographic = su.xpath('mods:hierarchicalGeographic', 'mods' => 'http://www.loc.gov/mods/v3')


    if !personal.empty?

      subject.type = 'personal'

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

  }


  return subjectArr
end


def getRelatedItem(modsRelatedItemElements)

  relatedItemArr = Array.new

  modsRelatedItemElements.each { |ri|
    relatedItem = RelatedItem.new

    relatedItem.id                = checkEmptyString ri.xpath('mods:recordInfo/mods:recordIdentifier', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.title             = checkEmptyString ri.xpath('mods:titleInfo[not(@type="abbreviated")]/mods:title', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.title_abbreviated = checkEmptyString ri.xpath('mods:titleInfo[@type="abbreviated"]/mods:title', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.title_partnumber  = checkEmptyString ri.xpath('mods:titleInfo/mods:partNumber', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.note              = checkEmptyString ri.xpath('mods:note', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.type              = checkEmptyString ri.xpath("@type", 'mods' => 'http://www.loc.gov/mods/v3').text

    relatedItemArr << relatedItem
  }

  return relatedItemArr
end


def getPart(modsPartElements)

  partArr = Array.new

  modsPartElements.each { |p|
    part = Part.new

    part.order = checkEmptyString p.xpath("@order", 'mods' => 'http://www.loc.gov/mods/v3').text

    detail = p.xpath('mods:detail', 'mods' => 'http://www.loc.gov/mods/v3')

    unless detail.empty?
      part.type   = checkEmptyString detail.first.xpath("@type", 'mods' => 'http://www.loc.gov/mods/v3').text
      part.number = checkEmptyString detail.first.xpath('mods:number', 'mods' => 'http://www.loc.gov/mods/v3').text
    end

    partArr << part
  }

  return partArr

end


def getRecordInfo(modsRecordInfoElements)

  recordInfoArr = Array.new


  return recordInfoArr
end


def processPresentationImages(meta)

  path_arr = Array.new
  id_arr   = Array.new
  page_arr = Array.new

  presentation_image_uris = meta.presentation_image_uris


  firstUri = presentation_image_uris[0]

  unless @oai_endpoint == 'true'

    # NLH:  https://nl.sub.uni-goettingen.de/image/eai1:0FDAB937D2065D58:0FD91D99A5423158/full/full/0/default.jpg
    match   = firstUri.match(/(\S*\/)(\S*):(\S*):(\S*)(\/\S*\/\S*\/\S*\/\S*)/)
    product = match[2]
    work    = match[3]


    meta.product = product
    meta.work    = work

    presentation_image_uris.each { |image_uri|

      match = image_uri.match(/(\S*\/)(\S*:\S*:\S*)(\/\S*\/\S*\/\S*\/\S*)/)
      id_arr << match[2]

      match2 = image_uri.match(/(\S*\/)(\S*):(\S*):(\S*)(\/\S*\/\S*\/\S*\/\S*)/)
      page_arr << match2[4]

      path_arr << {"image_uri" => image_uri}.to_json

    }

  else

    # todo modify for gdz

    # GDZ:  http://gdz-srv1.sub.uni-goettingen.de/content/PPN663109388/120/0/00000007.jpg
    match = firstUri.match(/(\S*\/content\/)(\S*)\/(\S*)\/(\S*)\/(\S*)\.(\S*)/)

    work    = match[2]
    product = @short_product

    meta.product = product
    meta.work    = work

    presentation_image_uris.each { |image_uri|

      match = image_uri.match(/(\S*\/content\/)(\S*)\/(\S*)\/(\S*)\/(\S*)\.(\S*)/)
      page  = match[5]

      id_arr << "#{product}:#{work}:#{page}"

      page_arr << page

      path_arr << {"image_uri" => image_uri}.to_json

    }
  end

  meta.addNlh_id = id_arr
  meta.addPage   = page_arr

  push_many("processImageURI", path_arr)

end

def getFulltext(path)

  attempts = 0
  fulltext = ""

  begin
    if @fulltext_from_orig == 'true'
      return File.read(path)
    else
      fulltext = File.open(path) { |f|
        Nokogiri::XML(f) { |config|
          #config.noblanks
        }
      }

      return fulltext.root.text.gsub(/\s+/, " ").strip
    end

  rescue Exception => e
    @logger.warn("Problem to open file #{path}")
    attempts = attempts + 1
    retry if (attempts < MAX_ATTEMPTS)
    @file_logger.error("Could not open file #{path} #{e.message}")
    return
  end


end

def processFulltexts(meta)

  if @fulltextexist == 'true'

    fulltextUriArr = Array.new
    fulltextArr    = Array.new

    unless @oai_endpoint == 'true'

      meta.fulltext_uris.each { |fulltexturi|

        # https://nl.sub.uni-goettingen.de/tei/eai1:0F7AD82E731D8E58:0F7A4A0624995AB0.tei.xml
        match = fulltexturi.match(/(\S*)\/(\S*):(\S*):(\S*).(tei).(xml)/)

        product  = match[2]
        work     = match[3]
        file     = match[4]
        filename = match[4] + '.tei.xml'

        if @fulltext_from_orig == 'true'
          release = @rredis.hget('mapping', work)
          from    = "#{@originpath}/#{release}/#{work}/#{file}.txt"
          to      = "#{@teioutpath}/#{product}/#{work}/#{file}.txt"
        else
          from = "#{@teiinpath}/#{work}/#{filename}"
          to   = "#{@teioutpath}/#{product}/#{work}/#{filename}"
        end


        to_dir = "#{@teioutpath}/#{product}/#{work}"


        if @fulltextexist == 'true'
          fulltextArr << getFulltext(from)
        end

        fulltextUriArr << {"fulltexturi" => fulltexturi, "to" => to, "to_dir" => to_dir}.to_json
      }

    else

      # todo modify for gdz

      meta.fulltext_uris.each { |fulltexturi|

        # gdzocr_url": [
        #   "http://gdz.sub.uni-goettingen.de/gdzocr/PPN517650908/00000001.xml",... ]

        match = fulltexturi.match(/(\S*gdzocr)\/(\S*)\/(\S*)\.(\S*)/)

        work    = match[2]
        product = @short_product
        page = match[3]
        format = match[4]
        filename = "#{page}.#{format}"

        #product  = match[2]
        #work     = match[3]
        #file     = match[4]
        #filename = match[4] + '.tei.xml'

        #if @fulltext_from_orig == 'true'
        #  release = @rredis.hget('mapping', work)
        #  from    = "#{@originpath}/#{release}/#{work}/#{file}.txt"
        #  to      = "#{@teioutpath}/#{product}/#{work}/#{file}.txt"
        #else
        #  from = "#{@teiinpath}/#{work}/#{filename}"
        #  to   = "#{@teioutpath}/#{product}/#{work}/#{filename}"
        #end

        from = match[0]

        to_dir = "#{@teioutpath}/#{product}/#{work}"


        if @fulltextexist == 'true'
          fulltextArr << getFulltext(from)
        end

        fulltextUriArr << {"fulltexturi" => fulltexturi, "to" => to, "to_dir" => to_dir}.to_json
      }

    end


    meta.addFulltext = fulltextArr

    push_many("processFulltextURI", fulltextUriArr)

  end

end

def getLogicalPageRange(smLinks)

  logIdSet = Set.new
  smLinks.each { |link|
    logIdSet << link.xpath('@xlink:from', 'xlink' => "http://www.w3.org/1999/xlink").to_s
  }

  hsh = Hash.new
  logIdSet.each { |logid|

    arr = smLinks.select { |link| link.xpath("@xlink:from='#{logid}'", 'xlink' => "http://www.w3.org/1999/xlink") }

    physId = Array.new
    arr.each { |link| physId << link.attr('xlink:to').match(/(\S*_)(\S*)/)[2].to_i }

    physId.sort!
    hsh[logid] = {"start" => physId.min, "end" => physId.max}
  }

  return hsh
end


def getAttributesFromLogicalDiv(div, doctype, logicalElementStartStopMapping, level)

  logicalElement = LogicalElement.new

  type = div.xpath("@TYPE", 'mets' => 'http://www.loc.gov/METS/').first
  if type != nil
    logicalElement.type = checkEmptyString(type.value)
  else
    logicalElement.type = ' '
  end

  dmdid = div.xpath("@DMDID", 'mets' => 'http://www.loc.gov/METS/').first
  if dmdid != nil
    logicalElement.dmdid = checkEmptyString(dmdid.value)
  else
    logicalElement.dmdid = ' '
  end

  id = div.xpath("@ID", 'mets' => 'http://www.loc.gov/METS/').first
  if id != nil
    logicalElement.id = checkEmptyString(id.value)
  else
    logicalElement.id = ' '
  end

  admid = div.xpath("@ADMID", 'mets' => 'http://www.loc.gov/METS/').first
  if admid != nil
    logicalElement.admid = checkEmptyString(admid.value)
  else
    logicalElement.admid = ' '
  end

  label = div.xpath("@LABEL", 'mets' => 'http://www.loc.gov/METS/').first
  if label != nil
    logicalElement.label = checkEmptyString(label.value)
  else
    logicalElement.label = ' '
  end


  if doctype == "collection"

    mptrs = div.xpath("mets:mptr[@LOCTYPE='URL']", 'mets' => 'http://www.loc.gov/METS/')

    if !mptrs.empty?

      part_uri = mptrs[0].xpath("@xlink:href", 'xlink' => 'http://www.w3.org/1999/xlink').text

      # https//nl.sub.uni-goettingen.de/mets/emo:zanzibarvol1.mets.xml
      match    = part_uri.match(/(\S*)\/(\S*):(\S*).(mets).(xml)/)
      product  = match[2]
      work     = match[3]


      logicalElement.part_product = product
      logicalElement.part_work    = work
      #logicalElement.volume_uri = volume_uri
      logicalElement.part_nlh_id  = "#{product}:#{work}"

      #meta.product              = product if i == 0

      #id_arr << "#{product}:#{vol}"
      #logicalElementArr << logicalElement

      #i += 1


      #meta.addVolume = logicalElementArr
      #meta.addNlh_id = id_arr

    end

  else

    unless logicalElementStartStopMapping[logicalElement.id] == nil

      logicalElement.start_page_index = logicalElementStartStopMapping[logicalElement.id]["start"].to_i
      logicalElement.end_page_index   = logicalElementStartStopMapping[logicalElement.id]["end"].to_i
    else
      logicalElement.start_page_index = -1
      logicalElement.end_page_index   = -1
    end
  end

  logicalElement.level = level


  return logicalElement

end

def getLogicalElements(logicalElementArr, div, links, logicalElementStartStopMapping, doctype, level)


  # todo abschließen

  logicalElementArr << getAttributesFromLogicalDiv(div, doctype, logicalElementStartStopMapping, level)

  divs = div.xpath("mets:div", 'mets' => 'http://www.loc.gov/METS/')


  divs.each { |innerdiv|

    getLogicalElements(logicalElementArr, innerdiv, links, logicalElementStartStopMapping, doctype, level+1)
  }

end


def metsRigthsMDElements(metsRightsMDElements)

  rightsInfoArr = Array.new

  metsRightsMDElements.each { |right|

    ri = Right.new

    rights = right.xpath('dv:rights', 'dv' => 'http://dfg-viewer.de/')[0]
    if rights != nil
      ri.owner        = rights.xpath('dv:owner', 'dv' => 'http://dfg-viewer.de/').text
      ri.ownerContact = rights.xpath('dv:ownerContact', 'dv' => 'http://dfg-viewer.de/').text
      ri.ownerSiteURL = rights.xpath('dv:ownerSiteURL', 'dv' => 'http://dfg-viewer.de/').text
      ri.license      = rights.xpath('dv:license', 'dv' => 'http://dfg-viewer.de/').text


      links        = right.xpath('dv:links', 'dv' => 'http://dfg-viewer.de/')[0]
      ri.reference = links.xpath('dv:reference', 'dv' => 'http://dfg-viewer.de/').text if links != nil

    end

    rightsInfoArr << ri

  }

  return rightsInfoArr


end

def metsUri(ppn)
  return "http://gdz.sub.uni-goettingen.de/mets/#{ppn}.xml"
end

def push_many(queue, arr)
  @rredis.lpush(queue, arr)

end

def pushToQueue(queue, hsh)
  @rredis.lpush(queue, hsh.to_json)
end

def checkwork(doc)
  doc.xpath("//mets:fileSec", 'mets' => 'http://www.loc.gov/METS/').first
end


def parsePath(path)

  attempts = 0
  doc      = ""

  begin
    doc = File.open(path) { |f|
      Nokogiri::XML(f) { |config|
        config.noblanks
      }
    }
  rescue Exception => e
    attempts = attempts + 1
    retry if (attempts < MAX_ATTEMPTS)
    @logger.error("Problem to open file #{path}")
    @file_logger.error("Could not open file #{path} #{e.message}")
    return
  end

  return parseDoc(doc, path)

end

def parsePPN(ppn)

  uri = metsUri(ppn)

  attempts = 0
  doc      = ""

  begin
    doc = Nokogiri::XML(open(uri))
  rescue Exception => e
    attempts = attempts + 1
    retry if (attempts < MAX_ATTEMPTS)
    @logger.error("Problem to open uri #{uri}")
    @file_logger.error("Could not open uri #{uri} #{e.message}")
    return
  end

  return parseDoc(doc, uri)

end

def parseDoc(doc, source)

  meta = MetsModsMetadata.new

#=begin

  mods = doc.xpath('//mods:mods', 'mods' => 'http://www.loc.gov/mods/v3')[0]

  meta.context = @context

  begin
    meta.mods = mods.to_xml
  rescue Exception => e
    @logger.debug "#{source}, #{e.message}"
  end
  meta.addIdentifiers      = getIdentifiers(mods, source)
  meta.addRecordIdentifiers= getRecordIdentifiers(mods, source)

  meta.product = ENV['SHORT_PRODUCT']


# Titel
  begin
    modsTitleInfoElements = mods.xpath('mods:titleInfo', 'mods' => 'http://www.loc.gov/mods/v3')

    unless modsTitleInfoElements.empty?
      meta.addTitleInfo = getTitleInfos(modsTitleInfoElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:titleInfo for #{source} (#{e.message})")
  end


# Erscheinungsort
  begin
    modsOriginInfoElements = mods.xpath('mods:originInfo', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsOriginInfoElements.empty?
      originInfoHash       = getOriginInfo(modsOriginInfoElements)
      meta.addOriginalInfo = originInfoHash[:original]
      meta.addEditionInfo  = originInfoHash[:edition]
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:originInfo for #{source} (#{e.message})")
  end


# Name
  begin
    modsNameElements = mods.xpath('mods:name', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsNameElements.empty?
      meta.addName = getName(modsNameElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:name for #{source} (#{e.message})")
  end

# TypeOfResource:
  begin
    modsTypeOfResourceElements = mods.xpath('mods:typeOfResource', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsTypeOfResourceElements.empty?
      meta.addTypeOfResource = getTypeOfResource(modsTypeOfResourceElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:typeOfResource for #{source} (#{e.message})")
  end

# Genre
  begin
    modsGenreElements = mods.xpath('mods:genre', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsGenreElements.empty?
      meta.addGenre = getGenre(modsGenreElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:genre for #{source} (#{e.message})")
  end

# Language
  begin
    modsLanguageElements = mods.xpath('mods:language', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsLanguageElements.empty?
      meta.addLanguage = getLanguage(modsLanguageElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:language for #{source} (#{e.message})")
  end

# PhysicalDescription:
  begin
    modsPhysicalDescriptionElements = mods.xpath('mods:physicalDescription', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsPhysicalDescriptionElements.empty?
      meta.addPhysicalDescription = getphysicalDescription(modsPhysicalDescriptionElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:physicalDescription for #{source} (#{e.message})")
  end


# Note:
  begin
    modsNoteElements = mods.xpath('mods:note', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsNoteElements.empty?
      meta.addNote = getNote(modsNoteElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:note for #{source} (#{e.message})")
  end

# Subject:
  begin
    modsSubjectElements = mods.xpath('mods:subject', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsSubjectElements.empty?
      meta.addSubject = getSubject(modsSubjectElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:subject for #{source} (#{e.message})")
  end

# RelatedItem
  begin
    modsRelatedItemElements = mods.xpath('mods:relatedItem', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsRelatedItemElements.empty?
      meta.addRelatedItem = getRelatedItem(modsRelatedItemElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:relatedItem for #{source} (#{e.message})")
  end

# Part (of multipart Documents)
  begin
    modsPartElements = mods.xpath('mods:part', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsPartElements.empty?
      meta.addPart = getPart(modsPartElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:part for #{source} (#{e.message})\n#{e.backtrace}")
  end


# RecordInfo:
  begin
    modsRecordInfoElements = mods.xpath('mods:recordInfo', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsRecordInfoElements.empty?
      meta.addRecordInfo = getRecordInfo(modsRecordInfoElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:recordInfo for #{source} (#{e.message})")
  end


# rights info
  begin
    metsRightsMDElements = doc.xpath("//mets:amdSec/mets:rightsMD/mets:mdWrap/mets:xmlData", 'mets' => 'http://www.loc.gov/METS/')

    unless metsRightsMDElements.empty?
      meta.addRightInfo = metsRigthsMDElements(metsRightsMDElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve rights info for #{source} (#{e.message})")
  end

#=end

  if checkwork(doc) != nil

    meta.iswork  = true
    meta.doctype = "work"

    # presentation images
    begin
      metsPresentationImageUriElements = doc.xpath("//mets:fileSec/mets:fileGrp[@USE='DEFAULT']/mets:file/mets:FLocat", 'mets' => 'http://www.loc.gov/METS/')

      unless metsPresentationImageUriElements.empty?
        meta.addPresentationImageUri = metsPresentationImageUriElements.xpath("@xlink:href", 'xlink' => 'http://www.w3.org/1999/xlink').collect { |el| el.text }
        processPresentationImages(meta)
      end
    rescue Exception => e
      @logger.error("Problems to resolve presentation images for #{source} (#{e.message})")
    end

    # =begin

    # full texts
    begin
      metsFullTextUriElements = doc.xpath("//mets:fileSec/mets:fileGrp[@USE='FULLTEXT' or @USE='TEI']/mets:file/mets:FLocat", 'mets' => 'http://www.loc.gov/METS/')

      unless metsFullTextUriElements.empty?
        meta.addFulltextUri = metsFullTextUriElements.xpath("@xlink:href", 'xlink' => 'http://www.w3.org/1999/xlink').collect { |el| el.text }
        processFulltexts(meta)
      end
    rescue Exception => e
      @logger.error("Problems to resolve full texts for #{source} (#{e.message})")
    end

# =end

  else

    meta.iswork   = false
    meta.doctype  = "collection"
    meta.isanchor = true

  end


# logical structure

  logicalElementArr = Array.new

  maindiv                        = doc.xpath("//mets:structMap[@TYPE='LOGICAL']/mets:div", 'mets' => 'http://www.loc.gov/METS/').first
  links                          = doc.xpath("//mets:structLink/mets:smLink", 'mets' => 'http://www.loc.gov/METS/')
  logicalElementStartStopMapping = getLogicalPageRange(links)

  getLogicalElements(logicalElementArr, maindiv, links, logicalElementStartStopMapping, meta.doctype, 0)


  meta.addLogicalElement = logicalElementArr

  return meta

end


$vertx.execute_blocking(lambda { |future|

  unless @oai_endpoint == 'true'

    while true do

      res = @rredis.brpop("metsindexer")

      attempts = 0
      begin
        if (res != '' && res != nil)

          json = JSON.parse res[1]
          path = json['path']


          @logger.debug "Indexing METS: #{path} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"

          metsModsMetadata = parsePath(path)

          if metsModsMetadata != nil
            addDocsToSolr(metsModsMetadata.to_solr_string)


            @logger.debug "\tFinish indexing METS: #{path} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
          else
            @logger.debug "\tCould not process #{path} metadata object is nil \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
          end
        else
          @logger.error "Get empty string or nil from redis"
        end


      rescue Exception => e
        attempts = attempts + 1
        retry if (attempts < MAX_ATTEMPTS)
        @logger.error "Could not process redis data '#{res[1]}' (#{Java::JavaLang::Thread.current_thread().get_name()})"
        @file_logger.error "Could not process redis data '#{res[1]}' (#{Java::JavaLang::Thread.current_thread().get_name()}) \n\t#{e.message}"
      end

    end

  else

    while true do

      res = @rredis.brpop("metsindexer")

      attempts = 0
      begin
        if (res != '' && res != nil)

          json = JSON.parse res[1]
          ppn  = json['ppn']


          @logger.debug "Indexing METS: #{ppn} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"

          metsModsMetadata = parsePPN(ppn)

          if metsModsMetadata != nil
            addDocsToSolr(metsModsMetadata.to_solr_string)


            @logger.debug "\tFinish indexing METS: #{ppn} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
          else
            @logger.debug "\tCould not process #{ppn} metadata object is nil \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
          end
        else
          @logger.error "Get empty string or nil from redis"
        end


      rescue Exception => e
        attempts = attempts + 1
        retry if (attempts < MAX_ATTEMPTS)
        @logger.error "Could not process redis data '#{res[1]}' (#{Java::JavaLang::Thread.current_thread().get_name()})"
        @file_logger.error "Could not process redis data '#{res[1]}' (#{Java::JavaLang::Thread.current_thread().get_name()}) \n\t#{e.message}"
      end

    end

  end

  # future.complete(doc.to_s)

}) { |res_err, res|
#
}

