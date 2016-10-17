require 'vertx/vertx'
#require 'vertx-redis/redis_client'

require 'rsolr'
#require 'elasticsearch'
require 'logger'
require 'nokogiri'
require 'redis'
require 'json'
require 'lib/mets_mods_metadata'
require 'lib/title_info'
require 'lib/origin_info'
require 'lib/name'
require 'lib/genre'
require 'lib/language'
require 'lib/related_item'
require 'lib/record_info'
require 'lib/physical_description'
require 'lib/subject'
require 'lib/note'

@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

redis_config = {
    'host' => ENV['REDIS_HOST'],
    'port' => ENV['REDIS_EXTERNAL_PORT'].to_i
}

MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

#@redis  = VertxRedis::RedisClient.create($vertx, redis_config)
@rredis      = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_EXTERNAL_PORT'].to_i)

@solr = RSolr.connect :url => ENV['SOLR_ADR']


@logger.debug "[mets_indexer worker] Running in #{Java::JavaLang::Thread.current_thread().get_name()}"


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
  begin
    @solr.add [document]
    @solr.commit

    @rredis.incr 'indexed'

  rescue Exception => e
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


def getIdentifiers(mods, path)

  ids = Hash.new

  begin
    identifiers = mods.xpath('mods:identifier', 'mods' => 'http://www.loc.gov/mods/v3')
    identifiers.each do |id_element|
      type      = id_element.attributes['type'].value
      id        = id_element.text
      ids[type] = id
    end
  rescue Exception => e
    @logger.error("Could not retrieve an identifier #{path}\n\t#{e.message}\n\t#{e.backtrace}")
  end

  return ids
end


def getRecordIdentifiers(mods, path)

  ids = Hash.new

  begin
    recordIdentifiers = mods.xpath('mods:recordInfo/mods:recordIdentifier', 'mods' => 'http://www.loc.gov/mods/v3')
    recordIdentifiers.each do |id_element|
      source = id_element.attributes['source']
      if source != nil
        type = id_element.attributes['source'].value
      else
        type = 'recordIdentifier'
      end
      id        = id_element.text
      ids[type] = id
    end
  rescue Exception => e
    @logger.error("Could not retrieve the recordidentifier #{path}\n\t#{e.message}\n\t#{e.backtrace}")
  end

  return ids
end


# todo check alternatives for empty fields instead of ' '
def getTitleInfos(modsTitleInfoElements)

  titleInfoArr = Array.new
  modsTitleInfoElements.each { |ti|
    titleInfo = TitleInfo.new

    titleInfo.title = ti.xpath('mods:title', 'mods' => 'http://www.loc.gov/mods/v3').text

    titleInfo.subtitle = checkEmptyString ti.xpath('mods:subTitle', 'mods' => 'http://www.loc.gov/mods/v3').text

    nonsort = ti.xpath('mods:nonSort', 'mods' => 'http://www.loc.gov/mods/v3').text
    if nonsort == ""
      nonsort = titleInfo.title
    else
      nonsort = nonsort + ' ' if (nonsort[-1] != " ")
      nonsort = nonsort + titleInfo.title
    end
    titleInfo.nonsort = nonsort

    titleInfoArr << titleInfo
  }

  return titleInfoArr
end

def getName(modsNameElements)

  #persNameArr = Array.new
  #corpNameArr = Array.new
  nameArr = Array.new

  # corp = modsNameElements.select {|name| name['type'] == 'corporate'}
  # pers = modsNameElements.select {|name| name['type'] == 'personal'}
  #
  # pers.each { |n|
  #   name = Name.new
  #
  #   name.displayform = n.xpath('mods:displayForm', 'mods' => 'http://www.loc.gov/mods/v3').text
  #
  #   persNameArr << name
  # }
  #
  # corp.each { |n|
  #   name = Name.new
  #
  #   name.displayform = n.xpath('mods:displayForm', 'mods' => 'http://www.loc.gov/mods/v3').text
  #
  #   corpNameArr << name
  # }

  modsNameElements.each { |name|

    n = Name.new

    n.type        = checkEmptyString name['type']
    n.displayform = checkEmptyString name.xpath('mods:displayForm', 'mods' => 'http://www.loc.gov/mods/v3').text

    nameArr << n
  }

  #return {:personal => persNameArr, :corporate => corpNameArr}
  return nameArr

end

# todo - not implemented yet
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
      originInfo.date_captured_start = oi.xpath("mods:dateCaptured[@keyDate='yes']", 'mods' => 'http://www.loc.gov/mods/v3').text
      originInfo.date_captured_end   = oi.xpath("mods:dateCaptured[@point='end']", 'mods' => 'http://www.loc.gov/mods/v3').text

    else
      # The date that the resource was published, released or issued.
      # multi:  dateIssued[encoding, point, keyDate]/value
      originInfo.date_issued = oi.xpath("mods:dateIssued[@keyDate='yes']", 'mods' => 'http://www.loc.gov/mods/v3').text
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


# todo - not implemented yet
def getNote(modsNoteElements)

  noteArr = Array.new

  return noteArr
end


# todo - not implemented yet
def getSubject(modsSubjectElements)

  subjectArr = Array.new

  modsSubjectElements.each { |subject|
    s          = Subject.new

    # :name, :date, :title, :geographic, :topic, :temporal, :country, :state, :city


    s.name     = checkEmptyString subject.xpath('mods:name[@type="personal"]/mods:namePart[not(@type)]', 'mods' => 'http://www.loc.gov/mods/v3').text
    s.date     = checkEmptyString subject.xpath('mods:name[@type="personal"]/mods:namePart[@type="date"]', 'mods' => 'http://www.loc.gov/mods/v3').text
    s.title    = checkEmptyString subject.xpath('mods:titleInfo/mods:title', 'mods' => 'http://www.loc.gov/mods/v3').text
    s.temporal = checkEmptyString subject.xpath('mods:temporal', 'mods' => 'http://www.loc.gov/mods/v3').text

    s.geographic = subject.xpath('mods:geographic', 'mods' => 'http://www.loc.gov/mods/v3').map { |el| el.text }
    s.topic      = subject.xpath('mods:topic', 'mods' => 'http://www.loc.gov/mods/v3').map { |el| el.text }
    hg           = subject.xpath('mods:hierarchicalGeographic', 'mods' => 'http://www.loc.gov/mods/v3')
    s.country    = hg.xpath('mods:country', 'mods' => 'http://www.loc.gov/mods/v3').map { |el| el.text }
    s.state      = hg.xpath('mods:state', 'mods' => 'http://www.loc.gov/mods/v3').map { |el| el.text }
    s.city       = hg.xpath('mods:city', 'mods' => 'http://www.loc.gov/mods/v3').map { |el| el.text }

    subjectArr << s
  }


  return subjectArr
end


def getRelatedItem(modsRelatedItemElements)

#  subtitle = ti.xpath('mods:subTitle', 'mods' => 'http://www.loc.gov/mods/v3').text
#  subtitle = ' ' if subtitle == ""
#  titleInfo.subtitle = subtitle


  relatedItemArr = Array.new
  modsRelatedItemElements.each { |ri|
    relatedItem = RelatedItem.new

    relatedItem.title             = checkEmptyString ri.xpath('mods:titleInfo[not(@type="abbreviated")]/mods:title', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.title_abbreviated = checkEmptyString ri.xpath('mods:titleInfo[@type="abbreviated"]/mods:title', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.title_partnumber  = checkEmptyString ri.xpath('mods:titleInfo/mods:partNumber', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.note              = checkEmptyString ri.xpath('mods:note', 'mods' => 'http://www.loc.gov/mods/v3').text
    relatedItem.type              = checkEmptyString ri.xpath("@type", 'mods' => 'http://www.loc.gov/mods/v3').text

    relatedItemArr << relatedItem
  }

  return relatedItemArr
end


# todo - not implemented yet
def getRecordInfo(modsRecordInfoElements)

  recordInfoArr = Array.new


  return recordInfoArr
end


# # conversion, calculate hash, copy to storage, check
# def processThumbs(meta)
#
# end

# # conversion, calculate hash, copy to storage, check
# def   processFullPDFs(meta)
#
# end


# # conversion, calculate hash, copy to storage, check
# def processFullPDFs(meta)
#
# end

# calculate hash, copy to storage, check
def processPresentationImages(meta, path)

  arr    = Array.new
  id_arr = Array.new

  presentation_image_uris = meta.presentation_image_uris


  # https://nl.sub.uni-goettingen.de/image/eai1:0FDAB937D2065D58:0FD91D99A5423158/full/full/0/default.jpg

  firstUri                = presentation_image_uris[0]

  match   = firstUri.match(/(\S*\/)(\S*):(\S*):(\S*)(\/\S*\/\S*\/\S*\/\S*)/)
  product = match[2]
  work    = match[3]

  meta.product = product
  meta.work    = work

  presentation_image_uris.each { |image_uri|

    match  = image_uri.match(/(\S*\/)(\S*:\S*:\S*)(\/\S*\/\S*\/\S*\/\S*)/)
    nlh_id = match[2]
    id_arr << nlh_id

    arr << {"path" => path, "image_uri" => image_uri}.to_json
  }

  meta.addNlh_id = id_arr

  push_many("processImageURI", arr)

end


# index, calculate hash, copy to storage, check
def processFulltexts(meta, path)

  arr = Array.new

  i = 1
  meta.fulltext_uris.each { |fulltexturi|

    id_parentdoc = meta.record_identifiers.first[1]
    image_index  = i
    doctype      = "fulltext"
    context      = "nhl"

    arr << {"path" => path, "fulltexturi" => fulltexturi, "id_parentdoc" => id_parentdoc, "imageindex" => image_index, "doctype" => doctype, "context" => context}.to_json

    i += 1
  }

  push_many("processFulltextURI", arr)

end


def push_many(queue, arr)
  @rredis.lpush(queue, arr)
  #@logger.info "Pushed #{arr.size} URIs to redis (to queue: #{queue})"
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
    @logger.warn("Problem to open file #{path}")
    attempts = attempts + 1
    retry if (attempts < MAX_ATTEMPTS)
    @logger.error("Could not open file #{path} #{e.message}")
    return
  end

  mods   = doc.xpath('//mods:mods', 'mods' => 'http://www.loc.gov/mods/v3')[0]

  # todo add rights info
  rights = doc.xpath('//dv:rights', 'dv' => 'http://dfg-viewer.de/')[0]

  meta = MetsModsMetadata.new

  meta.mods = mods.to_xml

  meta.addIdentifiers      = getIdentifiers(mods, path)
  meta.addRecordIdentifiers= getRecordIdentifiers(mods, path)

  # todo purl?

  # structtype, logid, dmdid
  begin

    docpart = doc.xpath("//mets:structMap[@TYPE='LOGICAL']/mets:div", 'mets' => 'http://www.loc.gov/METS/').first

    type          = docpart.xpath("@TYPE", 'mets' => 'http://www.loc.gov/METS/').first
    meta.docstrct = type.value if type != nil

    dmdid      = docpart.xpath("@DMDID", 'mets' => 'http://www.loc.gov/METS/').first
    meta.dmdid = dmdid.value if dmdid != nil

    id         = docpart.xpath("@ID", 'mets' => 'http://www.loc.gov/METS/').first
    meta.logid = id.value if id != nil

    admid      = docpart.xpath("@ADMID", 'mets' => 'http://www.loc.gov/METS/').first
    meta.admid = admid.value if admid != nil

    label = docpart.xpath("@LABEL", 'mets' => 'http://www.loc.gov/METS/').first
    if (label != nil)
      meta.bytitle = label.value
    else
      meta.bytitle = ''
    end

  rescue Exception => e
    @logger.error("Problems to resolve attributes of logical structMap (@TYPE, @DMDID, @ID, @ADMID or @LABEL) #{path} (#{e.message})")
    # todo
  end


  # # todo physical type ???
  # begin
  #   meta.structype = doc.xpath("//mets:structMap[@TYPE='LOGICAL']/mets:div/@TYPE", 'mets' => 'http://www.loc.gov/METS/').first.value
  # rescue Exception => e
  #   @logger.info("Mets structype info is nil for #{path} (#{e.message})")
  # end


  # Titel
  begin
    modsTitleInfoElements = mods.xpath('mods:titleInfo', 'mods' => 'http://www.loc.gov/mods/v3')

    meta.addTitleInfo = getTitleInfos(modsTitleInfoElements)
  rescue Exception => e
    @logger.error("Problems to resolve mods:titleInfo #{path} (#{e.message})")
  end


  # Erscheinungsort
  begin
    modsOriginInfoElements = mods.xpath('mods:originInfo', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    originInfoArr        = getOriginInfo(modsOriginInfoElements)
    meta.addOriginalInfo = originInfoArr[:original]
    meta.addEditionInfo  = originInfoArr[:edition]
  rescue Exception => e
    @logger.error("Problems to resolve mods:originInfo #{path} (#{e.message})")
  end


  # Name
  begin
    modsNameElements = mods.xpath('mods:name', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    #namesHash = getName(modsNameElements)
    #meta.addPersonalNames  = namesHash[:personal]
    #meta.addCorporateNames = namesHash[:corporate]

    meta.names = getName(modsNameElements)

  rescue Exception => e
    @logger.error("Problems to resolve mods:name #{path} (#{e.message})")
  end

  # TypeOfResource:   todo - not implemented yet
  begin
    modsTypeOfResourceElements = mods.xpath('mods:typeOfResource', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    meta.addTypeOfResource = getTypeOfResource(modsTypeOfResourceElements)
  rescue Exception => e
    @logger.error("Problems to resolve mods:typeOfResource #{path} (#{e.message})")
  end

  # Genre
  begin
    modsGenreElements = mods.xpath('mods:genre', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    meta.addGenre = getGenre(modsGenreElements)
  rescue Exception => e
    @logger.error("Problems to resolve mods:genre #{path} (#{e.message})")
  end

  # Language
  begin
    modsLanguageElements = mods.xpath('mods:language', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    meta.addLanguage = getLanguage(modsLanguageElements)
  rescue Exception => e
    @logger.error("Problems to resolve mods:language #{path} (#{e.message})")
  end

  # PhysicalDescription:   todo - not implemented yet
  begin
    modsPhysicalDescriptionElements = mods.xpath('mods:physicalDescription', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    meta.addPhysicalDescription = getphysicalDescription(modsPhysicalDescriptionElements)
  rescue Exception => e
    @logger.error("Problems to resolve mods:physicalDescription #{path} (#{e.message})")
  end


  # Note:   todo - not implemented yet
  begin
    modsNoteElements = mods.xpath('mods:note', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    meta.addNote = getNote(modsNoteElements)
  rescue Exception => e
    @logger.error("Problems to resolve mods:note #{path} (#{e.message})")
  end

  # Subject:   todo - not implemented yet
  begin
    modsSubjectElements = mods.xpath('mods:subject', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    meta.addSubject = getSubject(modsSubjectElements)
  rescue Exception => e
    @logger.error("Problems to resolve mods:subject #{path} (#{e.message})")
  end

  # RelatedItem
  begin
    modsRelatedItemElements = mods.xpath('mods:relatedItem', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    meta.addRelatedItem = getRelatedItem(modsRelatedItemElements)
  rescue Exception => e
    @logger.error("Problems to resolve mods:relatedItem #{path} (#{e.message})")
  end


  # RecordInfo:   todo - not implemented yet
  begin
    modsRecordInfoElements = mods.xpath('mods:recordInfo', 'mods' => 'http://www.loc.gov/mods/v3') # [0].text

    meta.addRecordInfo = getRecordInfo(modsRecordInfoElements)
  rescue Exception => e
    @logger.error("Problems to resolve mods:recordInfo #{path} (#{e.message})")
  end

  #---

  # presentation images
  begin
    metsPresentationImageUriElements = doc.xpath("//mets:fileSec/mets:fileGrp[@USE='DEFAULT']/mets:file/mets:FLocat", 'mets' => 'http://www.loc.gov/METS/')

    meta.addPresentationImageUri = metsPresentationImageUriElements.xpath("@xlink:href", 'xlink' => 'http://www.w3.org/1999/xlink').collect { |el| el.text }
    processPresentationImages(meta, path)

  rescue Exception => e
    @logger.error("Problems to resolve presentation images #{path} (#{e.message})")
  end


  # full texts
  begin
    metsFullTextUriElements = doc.xpath("//mets:fileSec/mets:fileGrp[@USE='TEI']/mets:file/mets:FLocat", 'mets' => 'http://www.loc.gov/METS/')

    meta.addFulltextUri = metsFullTextUriElements.xpath("@xlink:href", 'xlink' => 'http://www.w3.org/1999/xlink').collect { |el| el.text }
    processFulltexts(meta, path)

  rescue Exception => e
    @logger.error("Problems to resolve full texts #{path} (#{e.message})")
  end

  return meta
end


$vertx.execute_blocking(lambda { |future|


  seconds = 20

  catch (:stop) do

    while true do

      begin

        res = @rredis.brpop("metsindexer")

        if (res != '' && res != nil)

          json             = JSON.parse res[1]
          metsModsMetadata = parsePath(json['path'])

          addDocsToSolr(metsModsMetadata.to_solr_string) if metsModsMetadata != nil

          seconds = seconds / 2 if seconds > 20

        else
          @logger.error "Get empty string or nil from redis"
          sleep seconds
          seconds = seconds * 2 if seconds < 300
        end


      rescue Exception => e
        @logger.error("Error: #{e.message}- #{e.backtrace.join('\n\t')}")
        throw :stop
      end

    end
  end

  # future.complete(doc.to_s)

}) { |res_err, res|
#
}


