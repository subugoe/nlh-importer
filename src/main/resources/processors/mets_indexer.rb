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
require 'lib/physical_element'
require 'lib/classification'


# prepare config (gdz): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (gdz): 20 instances, 8GB importer, 3GB redis, 5GB solr

# prepare config (nlh): 1 instance, 8GB importer, 3GB redis, 5GB solr
# process config (nlh): 8 instances, 8GB importer, 3GB redis, 5GB solr

@dc_hsh = {
    "vd18 digital" => "vd18.digital"
}

context         = ENV['CONTEXT']
MAX_ATTEMPTS    = ENV['MAX_ATTEMPTS'].to_i

@oai_endpoint   = ENV['METS_VIA_OAI']
@short_product  = ENV['SHORT_PRODUCT']
@access_pattern = ENV['ACCESS_PATTERN']

productin   = ENV['IN'] + '/' + ENV['PRODUCT']
@teiinpath  = productin + ENV['TEI_IN_SUB_PATH']
@teioutpath = ENV['OUT'] + ENV['TEI_OUT_SUB_PATH']

@fulltextexist = ENV['FULLTEXTS_EXIST']
#@imagefrompdf  = ENV['IMAGE_FROM_PDF']
@context       = ENV['CONTEXT']

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/#{context}_mets_indexer_#{Time.new.strftime('%y-%m-%d')}.log")
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
    @logger.error("Could not add doc to solr \t#{e.message}")
    @file_logger.error("Could not add doc to solr \t#{e.message}\n\t#{e.backtrace}")
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
    @logger.error("Could not retrieve an identifier for #{source} \t#{e.message}")
    @file_logger.error("Could not retrieve an identifier for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end

  return ids
end


def getRecordIdentifiers(mods, source)

  ids = Hash.new

  begin
    recordIdentifiers = mods.xpath('mods:recordInfo/mods:recordIdentifier', 'mods' => 'http://www.loc.gov/mods/v3')

    if recordIdentifiers.empty?
      # check wrong written tag
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
    @logger.error("Could not retrieve the recordidentifier for #{source} \t#{e.message}")
    @file_logger.error("Could not retrieve the recordidentifier for #{source} \t#{e.message}\n\t#{e.backtrace}")
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

def getClassification(modsClassificationElements)

  classificationArr = Array.new
  modsClassificationElements.each { |dc|
    classification = Classification.new

    c = checkEmptyString dc.text
    c = @dc_hsh[c] unless @dc_hsh[c] == nil

    classification.value     = c
    classification.authority = checkEmptyString dc["authority"]


    classificationArr << classification
  }

  return classificationArr
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

      unless captured_start_date == ''
        originInfo.date_captured_start = captured_start_date.to_i
      else
        originInfo.date_captured_start = -1
      end


      unless captured_end_date == ''
        originInfo.date_captured_end = captured_end_date.to_i
      else
        originInfo.date_captured_end = originInfo.date_captured_start
      end


    else
      # The date that the resource was published, released or issued.
      # multi:  dateIssued[encoding, point, keyDate]/value
      issued_start_date = oi.xpath("mods:dateIssued[@keyDate='yes']", 'mods' => 'http://www.loc.gov/mods/v3').text
      issued_end_date   = oi.xpath("mods:dateIssued[@point='end']", 'mods' => 'http://www.loc.gov/mods/v3').text

      unless issued_start_date == ''
        originInfo.date_issued_start = issued_start_date.to_i
      else
        originInfo.date_issued_start = -1
      end

      unless issued_end_date == ''
        originInfo.date_issued_end = issued_end_date.to_i
      else
        originInfo.date_issued_end = originInfo.date_issued_start
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

    part.currentnosort = checkEmptyString p.xpath("@order", 'mods' => 'http://www.loc.gov/mods/v3').text

    detail = p.xpath('mods:detail', 'mods' => 'http://www.loc.gov/mods/v3')

    unless detail.empty?
      part.currentno = checkEmptyString detail.first.xpath('mods:number', 'mods' => 'http://www.loc.gov/mods/v3').text
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

    begin
      # NLH:  https://nl.sub.uni-goettingen.de/image/eai1:0FDAB937D2065D58:0FD91D99A5423158/full/full/0/default.jpg
      match   = firstUri.match(/(\S*)\/(\S*)\/(\S*):(\S*):(\S*)(\/\S*\/\S*\/\S*\/\S*)/)
      baseurl = match[1]
      product = match[3]
      work    = match[4]
    rescue Exception => e
      @logger.error("No regex match for NLH/IIIF image URI #{firstUri} \t#{e.message}")
      @file_logger.error("No regex match for NLH/IIIF image URI #{firstUri} \t#{e.message}\n\t#{e.backtrace}")
      raise
    end

    meta.baseurl        = baseurl
    meta.access_pattern = @access_pattern
    meta.product        = product
    meta.work           = work
    meta.image_format   = ENV['IMAGE_OUT_FORMAT']

    presentation_image_uris.each { |image_uri|

      begin
        match = image_uri.match(/(\S*\/)(\S*):(\S*):(\S*)(\/\S*\/\S*\/\S*\/\S*)/)
        page  = match[4]
      rescue Exception => e
        @logger.error("No regex match for NLH/IIIF image URI #{image_uri} \t#{e.message}")
        @file_logger.error("No regex match for NLH/IIIF image URI #{image_uri} \t#{e.message}\n\t#{e.backtrace}")
        raise
      end

      id_arr << "#{product}:#{work}:#{page}"
      page_arr << page
      path_arr << {"image_uri" => image_uri}.to_json

    }

  else

    begin
      # GDZ:  http://gdz-srv1.sub.uni-goettingen.de/content/PPN663109388/120/0/00000007.jpg
      match = firstUri.match(/(\S*)\/(\S*)\/(\S*)\/(\S*)\/(\S*)\/(\S*)\.(\S*)/)

      baseurl      = match[1]
      work         = match[3]
      image_format = match[7]
    rescue Exception => e
      @logger.error("No regex match for GDZ/IIIF image URI #{firstUri} \t#{e.message}")
      @file_logger.error("No regex match for GDZ/IIIF image URI #{firstUri} \t#{e.message}\n\t#{e.backtrace}")
      raise
    end

    product = @short_product

    meta.baseurl        = baseurl
    meta.access_pattern = @access_pattern
    meta.product        = product
    meta.work           = work
    meta.image_format   = image_format

    presentation_image_uris.each { |image_uri|

      begin
        match = image_uri.match(/(\S*)\/(\S*)\/(\S*)\/(\S*)\/(\S*)\/(\S*)\.(\S*)/)
        page  = match[6]
      rescue Exception => e
        @logger.error("No regex match for GDZ/IIIF image URI #{image_uri} \t#{e.message}")
        @file_logger.error("No regex match for GDZ/IIIF image URI #{image_uri} \t#{e.message}\n\t#{e.backtrace}")
        raise
      end

      id_arr << "#{product}:#{work}:#{page}"
      page_arr << page
      path_arr << {"image_uri" => image_uri}.to_json

    }
  end

  meta.addPage_key = id_arr
  meta.addPage     = page_arr

  push_many("processImageURI", path_arr)

end

def getFulltext(path)

  attempts = 0
  fulltext = ""

  begin
    fulltext = File.open(path) { |f|
      Nokogiri::XML(f) { |config|
        #config.noblanks
      }
    }

    return fulltext.root.text.gsub(/\s+/, " ").strip

  rescue Exception => e
    attempts = attempts + 1
    retry if (attempts < MAX_ATTEMPTS)
    @logger.error("Could not open file #{path} \t#{e.message}")
    @file_logger.error("Could not open file #{path} \t#{e.message}\n\t#{e.backtrace}")
    return
  end


end

def processFulltexts(meta)

  if @fulltextexist == 'true'

    fulltextUriArr = Array.new
    fulltextArr    = Array.new

    fulltext_uris = meta.fulltext_uris
    firstUri      = fulltext_uris[0]

    unless @oai_endpoint == 'true'

      begin
        # https://nl.sub.uni-goettingen.de/tei/eai1:0F7AD82E731D8E58:0F7A4A0624995AB0.tei.xml
        match   = firstUri.match(/(\S*)\/(\S*):(\S*):(\S*).(tei).(xml)/)
        product = match[2]
        work    = match[3]
      rescue Exception => e
        @logger.error("No regex match for fulltext URI #{firstUri} \t#{e.message}")
        @file_logger.error("No regex match for fulltext URI #{firstUri} \t#{e.message}\n\t#{e.backtrace}")
        raise
      end

      fulltext_uris.each { |fulltexturi|

        begin
          match    = fulltexturi.match(/(\S*)\/(\S*):(\S*):(\S*).(tei).(xml)/)
          file     = match[4]
          filename = match[4] + '.tei.xml'
        rescue Exception => e
          @logger.error("No regex match for fulltext URI #{fulltexturi} \t#{e.message}")
          @file_logger.error("No regex match for fulltext URI #{fulltexturi} \t#{e.message}\n\t#{e.backtrace}")
          raise
        end


        from = "#{@teiinpath}/#{work}/#{filename}"
        to   = "#{@teioutpath}/#{product}/#{work}/#{filename}"


        to_dir = "#{@teioutpath}/#{product}/#{work}"


        if @fulltextexist == 'true'
          fulltextArr << getFulltext(from)
        end

        fulltextUriArr << {"fulltexturi" => fulltexturi, "to" => to, "to_dir" => to_dir}.to_json
      }

    else

      # todo modify for gdz

      begin
        # gdzocr_url": [
        #   "http://gdz.sub.uni-goettingen.de/gdzocr/PPN517650908/00000001.xml",... ]
        match = firstUri.match(/(\S*)\/(\S*)\/(\S*)\/(\S*)\.(\S*)/)
        work  = match[3]
      rescue Exception => e
        @logger.error("No regex match for fulltext URI #{firstUri} \t#{e.message}")
        @file_logger.error("No regex match for fulltext URI #{firstUri} \t#{e.message}\n\t#{e.backtrace}")
        raise
      end

      product = @short_product

      fulltext_uris.each { |fulltexturi|

        begin
          match  = fulltexturi.match(/(\S*)\/(\S*)\/(\S*)\/(\S*)\.(\S*)/)
          page   = match[4]
          format = match[5]
          from   = match[0]
        rescue Exception => e
          @logger.error("No regex match for fulltext URI #{fulltexturi} \t#{e.message}")
          @file_logger.error("No regex match for fulltext URI #{fulltexturi} \t#{e.message}\n\t#{e.backtrace}")
          raise
        end

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

def addToHash(hsh, pos, val)
  if hsh[pos] == nil
    hsh[pos] = [val]
  else
    hsh[pos] << val
  end
end

def getLogicalPageRange(smLinks, meta)

  logPhyHsh = Hash.new
  max       = 1
  min       = 1

  smLinks.each { |link|
    #logIdSet << link.xpath('@xlink:from', 'xlink' => "http://www.w3.org/1999/xlink").to_s
    from_ = link.xpath('@xlink:from', 'xlink' => "http://www.w3.org/1999/xlink").to_s
    to_   = link.xpath('@xlink:to', 'xlink' => "http://www.w3.org/1999/xlink").to_s
    begin
      if to_.downcase.include? "phys_"
        to = to_.match(/(\S*_)(\S*)/)[2].to_i
      elsif to_.downcase.include? "phys"
        to = to_.downcase.gsub('phys', '').to_i
      else
        raise "Link target (#{to_}) doesn't match the expected pattern"
      end
    rescue Exception => e
      @logger.error("No regex match for link target #{to_} \t#{e.message}")
      @file_logger.error("No regex match for link target #{to_} \t#{e.message}\n\t#{e.backtrace}")
      raise
    end

    if meta.doctype == "work"
      max = to if to > max
      min = to if to < min
    end

    addToHash(logPhyHsh, from_, to)
  }

  if meta.doctype == "work"
    meta.phys_first_page_index = min
    meta.phys_last_page_index  = max
  end

  hsh = Hash.new

  logPhyHsh.each { |key, value|
    value.sort!
    hsh[key] = {"start" => value.min, "end" => value.max}
  }


  return hsh
end

def getAttributesFromPhysicalDiv(div, doctype, level)

  physicalElement = PhysicalElement.new


  # type = div.xpath("@TYPE", 'mets' => 'http://www.loc.gov/METS/').first
  # if type != nil
  #   physicalElement.type = checkEmptyString(type.value)
  # else
  #   physicalElement.type = ' '
  # end
  #
  # id = div.xpath("@ID", 'mets' => 'http://www.loc.gov/METS/').first
  # if id != nil
  #   physicalElement.id = checkEmptyString(id.value)
  # else
  #   physicalElement.id = ' '
  # end
  #
  # physicalElement.level = level


  order           = div.xpath("@ORDER", 'mets' => 'http://www.loc.gov/METS/').first
  if order != nil
    physicalElement.order = checkEmptyString(order.value)
  else
    physicalElement.order = '-1'
  end

  orderlabel = div.xpath("@ORDERLABEL", 'mets' => 'http://www.loc.gov/METS/').first
  if orderlabel != nil
    physicalElement.orderlabel = checkEmptyString(orderlabel.value)
  else
    physicalElement.orderlabel = ' '
  end


  return physicalElement

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

      unless @oai_endpoint == 'true'

        begin
          # https//nl.sub.uni-goettingen.de/mets/emo:zanzibarvol1.mets.xml
          match   = part_uri.match(/(\S*)\/(\S*):(\S*).(mets).(xml)/)
          product = match[2]
          work    = match[3]
        rescue Exception => e
          @logger.error("No regex match for part URI #{part_uri} in parent #{@path} \t#{e.message}")
          @file_logger.error("No regex match for part URI #{part_uri} in parent #{@path} \t#{e.message}\n\t#{e.backtrace}")
          raise
        end


        #meta.product              = product if i == 0

        #id_arr << "#{product}:#{vol}"
        #logicalElementArr << logicalElement

        #i += 1


        #meta.addVolume = logicalElementArr
        #meta.addPage_key = id_arr

      else

        count = 0

        # http://gdz.sub.uni-goettingen.de/mets_export.php?PPN=PPN877624038
        begin
          match = part_uri.match(/(\S*PPN=)(\S*)/)
          if match == nil
            # http://gdz.sub.uni-goettingen.de/mets/PPN807026034.xml
            match = part_uri.match(/(\S*)\/mets\/(\S*).xml/)
          end

          work = match[2]
        rescue Exception => e
          if (match == nil) && (count < 1)
            count += 1

            @logger.error("Problem with part URI #{part_uri} in parent #{@ppn}. Remove spaces and processed again!")
            @file_logger.error("Problem with part URI #{part_uri} in parent #{@ppn}. Remove spaces and processed again!")

            part_uri.gsub!(' ', '')

            retry
          end
          @logger.error("No regex match for #{part_uri} in parent #{@ppn} \t#{e.message}")
          @file_logger.error("No regex match for #{part_uri} in parent #{@ppn} \t#{e.message}\n\t#{e.backtrace}")
          raise
        end

        product = @short_product


      end

      logicalElement.part_product  = product
      logicalElement.part_work     = work
      #logicalElement.volume_uri = volume_uri
      logicalElement.part_page_key = "#{product}:#{work}"

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

  logicalElementArr << getAttributesFromLogicalDiv(div, doctype, logicalElementStartStopMapping, level)

  divs = div.xpath("mets:div", 'mets' => 'http://www.loc.gov/METS/')


  unless divs.empty?
    divs.each { |innerdiv|
      getLogicalElements(logicalElementArr, innerdiv, links, logicalElementStartStopMapping, doctype, level+1)
    }
  end


end


def getPhysicalElements(physicalElementArr, div, doctype, level)

  physicalElementArr << getAttributesFromPhysicalDiv(div, doctype, level) unless level == 0

  divs = div.xpath("mets:div", 'mets' => 'http://www.loc.gov/METS/')


  unless divs.empty?
    divs.each { |innerdiv|
      getPhysicalElements(physicalElementArr, innerdiv, doctype, level+1)
    }
  end


end


def metsRigthsMDElements(metsRightsMDElements)

  rightsInfoArr = Array.new

  metsRightsMDElements.each { |right|

    ri = Right.new

    rights = right.xpath('dv:rights', 'dv' => 'http://dfg-viewer.de/')[0]
    rights = right.xpath('dv:rights', 'dv' => 'http://dfg-viewer.de')[0] if rights == nil


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

  @path = path

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
    @logger.error("Could not open file #{path} \t#{e.message}")
    @file_logger.error("Could not open file #{path} \t#{e.message}\n\t#{e.backtrace}")
    return
  end

  return parseDoc(doc, path)

end

def parsePPN(ppn)

  @ppn = ppn

  uri = metsUri(ppn)

  attempts = 0
  doc      = ""

  begin
    doc = Nokogiri::XML(open(uri))
  rescue Exception => e
    attempts = attempts + 1
    retry if (attempts < MAX_ATTEMPTS)
    @logger.error("Could not open uri #{uri} \t#{e.message}")
    @file_logger.error("Could not open uri #{uri} \t#{e.message}\n\t#{e.backtrace}")
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
    @logger.error "Could not get MODS XML for #{source} \t#{e.message}"
    @file_logger.error("Could not get MODS XML for #{source} \t#{e.message}\n\t#{e.backtrace}")
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
    @file_logger.error("Problems to resolve mods:titleInfo for #{source} \t#{e.message}\n\t#{e.backtrace}")
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
    @file_logger.error("Problems to resolve mods:originInfo for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end


# Name
  begin
    modsNameElements = mods.xpath('mods:name', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsNameElements.empty?
      meta.addName = getName(modsNameElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:name for #{source} (#{e.message})")
    @file_logger.error("Problems to resolve mods:name for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end

# TypeOfResource:
  begin
    modsTypeOfResourceElements = mods.xpath('mods:typeOfResource', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsTypeOfResourceElements.empty?
      meta.addTypeOfResource = getTypeOfResource(modsTypeOfResourceElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:typeOfResource for #{source} (#{e.message})")
    @file_logger.error("Problems to resolve mods:typeOfResource for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end

# Genre
  begin
    modsGenreElements = mods.xpath('mods:genre', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsGenreElements.empty?
      meta.addGenre = getGenre(modsGenreElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:genre for #{source} (#{e.message})")
    @file_logger.error("Problems to resolve mods:genre for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end

# Classification
  begin
    modsClassificationElements = mods.xpath('mods:classification', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsClassificationElements.empty?
      meta.addClassification = getClassification(modsClassificationElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:classificationfor #{source} (#{e.message})")
    @file_logger.error("Problems to resolve mods:classification for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end


# Language
  begin
    modsLanguageElements = mods.xpath('mods:language', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsLanguageElements.empty?
      meta.addLanguage = getLanguage(modsLanguageElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:language for #{source} (#{e.message})")
    @file_logger.error("Problems to resolve mods:language for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end

# PhysicalDescription:
  begin
    modsPhysicalDescriptionElements = mods.xpath('mods:physicalDescription', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsPhysicalDescriptionElements.empty?
      meta.addPhysicalDescription = getphysicalDescription(modsPhysicalDescriptionElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:physicalDescription for #{source} (#{e.message})")
    @file_logger.error("Problems to resolve mods:physicalDescription for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end


# Note:
  begin
    modsNoteElements= mods.xpath('mods:note', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsNoteElements.empty?
      meta.addNote = getNote(modsNoteElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:note for #{source} (#{e.message})")
    @file_logger.error("Problems to resolve mods:note for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end

# Sponsor:
  begin
    modsSponsorElements = mods.xpath('gdz:sponsorship', 'gdz' => 'http://gdz.sub.uni-goettingen.de/') # [0].text

    unless modsSponsorElements.empty?
      meta.addSponsor = modsSponsorElements.text
    end

  rescue Exception => e
    @logger.error("Problems to resolve gdz:sponsorship for #{source} (#{e.message})")
    @file_logger.error("Problems to resolve gdz:sponsorship for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end


# Subject:
  begin
    modsSubjectElements = mods.xpath('mods:subject', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsSubjectElements.empty?
      meta.addSubject = getSubject(modsSubjectElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:subject for #{source} (#{e.message})")
    @file_logger.error("Problems to resolve mods:subject for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end

# RelatedItem
  begin
    modsRelatedItemElements = mods.xpath('mods:relatedItem', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsRelatedItemElements.empty?
      meta.addRelatedItem = getRelatedItem(modsRelatedItemElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:relatedItem for #{source} (#{e.message})")
    @file_logger.error("Problems to resolve mods:relatedItem for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end

# Part (of multipart Documents)
  begin
    modsPartElements = mods.xpath('mods:part', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsPartElements.empty?
      meta.addPart = getPart(modsPartElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:part for #{source} (#{e.message})\n#{e.backtrace}")
    @file_logger.error("Problems to resolve mods:part for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end


# RecordInfo:
  begin
    modsRecordInfoElements = mods.xpath('mods:recordInfo', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    unless modsRecordInfoElements.empty?
      meta.addRecordInfo = getRecordInfo(modsRecordInfoElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve mods:recordInfo for #{source} (#{e.message})")
    @file_logger.error("Problems to resolve mods:recordInfo for #{source} \t#{e.message}\n\t#{e.backtrace}")
  end


# rights info
  begin
    metsRightsMDElements = doc.xpath("//mets:amdSec/mets:rightsMD/mets:mdWrap/mets:xmlData", 'mets' => 'http://www.loc.gov/METS/')

    unless metsRightsMDElements.empty?
      meta.addRightInfo = metsRigthsMDElements(metsRightsMDElements)
    end
  rescue Exception => e
    @logger.error("Problems to resolve rights info for #{source} (#{e.message})")
    @file_logger.error("Problems to resolve rights info for #{source} \t#{e.message}\n\t#{e.backtrace}")
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
      @file_logger.error("Problems to resolve presentation images for #{source} \t#{e.message}\n\t#{e.backtrace}")
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
      @file_logger.error("Problems to resolve full texts for #{source} \t#{e.message}\n\t#{e.backtrace}")
    end

# =end

  else

    meta.iswork   = false
    meta.doctype  = "collection"
    meta.isanchor = true

    unless @oai_endpoint == 'true'
      # /inpath/METS_Daten/mets_emo_farminstructordiaryno2farmcluny19091920.xml

      begin
        match           = @path.match(/(\S*)\/(\S*)_(\S*)_(\S*).xml/)
        meta.collection = match[4]
        meta.product    = match[3]
      rescue Exception => e
        @logger.error("No regex match for collection #{@path} \t#{e.message}")
        @file_logger.error("No regex match for collection #{@path} \t#{e.message}\n\t#{e.backtrace}")
        raise
      end

    else
      meta.collection = @ppn
    end

  end


# logical structure

  logicalElementArr = Array.new

  maindiv                        = doc.xpath("//mets:structMap[@TYPE='LOGICAL']/mets:div", 'mets' => 'http://www.loc.gov/METS/').first
  links                          = doc.xpath("//mets:structLink/mets:smLink", 'mets' => 'http://www.loc.gov/METS/')
  logicalElementStartStopMapping = getLogicalPageRange(links, meta)

  getLogicalElements(logicalElementArr, maindiv, links, logicalElementStartStopMapping, meta.doctype, 0)


  meta.addLogicalElement = logicalElementArr


# physical structure

  unless meta.doctype == "collection"

    physicalElementArr = Array.new

    maindiv = doc.xpath("//mets:structMap[@TYPE='PHYSICAL']/mets:div", 'mets' => 'http://www.loc.gov/METS/').first

    getPhysicalElements(physicalElementArr, maindiv, meta.doctype, 0)

    meta.addPhysicalElement = physicalElementArr

  end


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


          @logger.info "Indexing METS: #{path} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"

          metsModsMetadata = parsePath(path)

          if metsModsMetadata != nil
            addDocsToSolr(metsModsMetadata.to_solr_string)

            @logger.info "\tFinish indexing METS: #{path} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
          else
            @logger.error "\tCould not process #{path} metadata, object is nil \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
            @file_logger.error "\tCould not process #{path} metadata, object is nil"
          end
        else
          @logger.error "Get empty string or nil from redis (#{res[1]})"
          @file_logger.error "Get empty string or nil from redis (#{res[1]})"
        end


      rescue Exception => e
        attempts = attempts + 1
        retry if (attempts < MAX_ATTEMPTS)
        @logger.error "Could not process redis data '#{res[1]}' (#{e.message})"
        @file_logger.error "Could not process redis data '#{res[1]}'  \t#{e.message}\n\t#{e.backtrace}"
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


          @logger.info "Indexing METS: #{ppn} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"

          metsModsMetadata = parsePPN(ppn)

          if metsModsMetadata != nil
            addDocsToSolr(metsModsMetadata.to_solr_string)


            @logger.info "\tFinish indexing METS: #{ppn} \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
          else
            @logger.error "\tCould not process #{ppn} metadata, object is nil \t(#{Java::JavaLang::Thread.current_thread().get_name()})"
            @file_logger.error "\tCould not process #{path} metadata, object is nil"
          end
        else
          @logger.error "Get empty string or nil from redis (#{res[1]})"
          @file_logger.error "Get empty string or nil from redis (#{res[1]})"
        end


      rescue Exception => e
        attempts = attempts + 1
        retry if (attempts < MAX_ATTEMPTS)
        @logger.error "Could not process redis data '#{res[1]}' (#{e.message})"
        @file_logger.error "Could not process redis data '#{res[1]}'  \t#{e.message}\n\t#{e.backtrace}"
      end

    end

  end

  # future.complete(doc.to_s)

}) { |res_err, res|
#
}

