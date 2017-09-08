require 'logger'
require 'json'
require 'open-uri'
require 'fileutils'
require 'mini_magick'
require 'benchmark'
require 'redis'
require 'rsolr'
require 'model/disclaimer_info'
#require 'combine_pdf'

require "prawn"
#require 'pdftk'

MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

@pdfoutpath = ENV['OUT'] + ENV['PDF_OUT_SUB_PATH']


@logger       = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

@file_logger       = Logger.new(ENV['LOG'] + "/image_loader_eb_#{Time.new.strftime('%y-%m-%d')}.log")
@file_logger.level = Logger::DEBUG

@rredis = Redis.new(
    :host               => ENV['REDIS_HOST'],
    :port               => ENV['REDIS_EXTERNAL_PORT'].to_i,
    :db                 => ENV['REDIS_DB'].to_i,
    :timeout            => 30,
    :reconnect_attempts => 3
)

@solr = RSolr.connect :url => ENV['SOLR_ADR']

def initialize

  MiniMagick.configure do |config|
    config.validate_on_create = false
    config.validate_on_write  = false
    config.whiny              = false
  end

  #MiniMagick.logger.level = Logger::DEBUG
end


def log_error(msg, e)
  @logger.error("[image_loader_eb] #{msg} \t#{e.message}\n\t#{e.backtrace}")
  @file_logger.error("[image_loader_eb] #{msg} \t#{e.message}")
end

def log_info(msg)
  @logger.info("[image_loader_eb] #{msg}")
  @file_logger.info("[image_loader_eb] #{msg}")
end

def log_debug(msg)
  @logger.debug("[image_loader_eb] #{msg}")
  @file_logger.debug("[image_loader_eb] #{msg}")
end


# ---

log_debug "Running in #{Java::JavaLang::Thread.current_thread().get_name()}"

def delete(to_tmp_img)
  FileUtils.remove_file(to_tmp_img, force = true)
end

def pushToQueue(queue, field, value)
  @rredis.hset(queue, field, value)
end

def removeQueue(queue)
  keys = @rredis.hkeys(queue)
  unless keys.empty?
    @rredis.hdel(queue, keys)
  end
end


def conversion_errors?(queue)
  if @rredis.hget(queue, 'err') == nil
    false
  else
    true
  end
end

def download_via_s3(url, path)
  return false
end

def download_via_http(url, path)

  attempts = 0


  begin
    open(path, 'wb') do |file|
      file << open(url).read
    end
  rescue Exception => e
    attempts = attempts + 1
    retry if (attempts < MAX_ATTEMPTS)
    log_error "Could not download '#{url}'", e
    return false
  end

  return true

end

def download_via_mount(url, path)
  return false
end


def download(url, path)


  unless download_via_s3(url, path)
    unless download_via_http(url, path)
      unless download_via_mount(url, path)
        return false
      end
    end
  end

  #log_debug "Download of '#{url}' finished"

  return true

end

def add_info_str(bookmark_str, info_key, info_value)
  bookmark_str << "InfoBegin\n"
  bookmark_str << "InfoKey: #{info_key}\n"
  bookmark_str << "InfoValue: #{info_value}\n"
end

def add_to_bookmark_str(bookmark_str, bm_title, bm_level, bm_page_number)
  bookmark_str << "BookmarkBegin\n"
  bookmark_str << "BookmarkTitle: #{bm_title}\n"
  bookmark_str << "BookmarkLevel: #{bm_level}\n"
  bookmark_str << "BookmarkPageNumber: #{bm_page_number}\n"
end

def load_metadata(work)

  disclaimer_info = DisclaimerInfo.new

  solr_work = (@solr.get 'select', :params => {:q => "work:#{work}", :fl => "purl catalogue log_id log_label  log_start_page_index  log_level  title subtitle shelfmark bycreator year_publish_string publisher place_publish genre dc subject rights_owner parentdoc_work parentdoc_label parentdoc_type"})['response']['docs'].first


  disclaimer_info.log_id                   = solr_work['log_id']
  disclaimer_info.log_label_arr            = solr_work['log_label']
  disclaimer_info.log_start_page_index_arr = solr_work['log_start_page_index']
  disclaimer_info.log_level_arr            = solr_work['log_level']

  disclaimer_info.purl          = solr_work['purl']
  disclaimer_info.catalogue_arr = solr_work['catalogue']

  disclaimer_info.title_arr           = solr_work['title']
  disclaimer_info.subtitle_arr        = solr_work['subtitle']
  disclaimer_info.bycreator           = solr_work['bycreator']
  disclaimer_info.publisher           = solr_work['publisher']
  disclaimer_info.place_publish       = solr_work['place_publish']
  disclaimer_info.year_publish_string = solr_work['year_publish_string']
  disclaimer_info.genre_arr           = solr_work['genre']
  disclaimer_info.dc_arr              = solr_work['dc']
  disclaimer_info.subject_arr         = solr_work['subject']
  disclaimer_info.year_publisher      = solr_work['year_publisher']
  disclaimer_info.shelfmark_arr       = solr_work['shelfmark']
  disclaimer_info.rights_owner_arr    = solr_work['rights_owner']

  disclaimer_info.parentdoc_work  = solr_work['parentdoc_work']
  disclaimer_info.parentdoc_label = solr_work['parentdoc_label']
  disclaimer_info.parentdoc_type  = solr_work['parentdoc_type']

  solr_work = nil

  return disclaimer_info

end

def add_bookmarks_pdftk_system(to_pdf_dir, work, log_id, request_logical_part, disclaimer_info)

  data_file = "#{to_pdf_dir}/data.txt"

  bookmark_str = ""

  add_info_str(bookmark_str, 'PURL', disclaimer_info.purl) if check_nil_or_empty_string disclaimer_info.purl
  add_info_str(bookmark_str, 'Catalogue', disclaimer_info.catalogue_arr.join(' ')) if check_nil_or_empty_string disclaimer_info.catalogue_arr

  add_info_str(bookmark_str, 'Work', work)
  add_info_str(bookmark_str, 'LOGID', log_id)
  add_info_str(bookmark_str, 'Title', disclaimer_info.title_arr.join(' ')) if check_nil_or_empty_string disclaimer_info.title_arr
  add_info_str(bookmark_str, 'Subtitle', disclaimer_info.subtitle_arr.join(' ')) if check_nil_or_empty_string disclaimer_info.subtitle_arr

  add_info_str(bookmark_str, 'Creator', disclaimer_info.bycreator) if check_nil_or_empty_string disclaimer_info.bycreator
  add_info_str(bookmark_str, 'Publisher', disclaimer_info.publisher) if check_nil_or_empty_string disclaimer_info.publisher
  add_info_str(bookmark_str, 'Place', disclaimer_info.place_publish) if check_nil_or_empty_string disclaimer_info.place_publish
  add_info_str(bookmark_str, 'Year', disclaimer_info.year_publish_string) if check_nil_or_empty_string disclaimer_info.year_publish_string

  add_info_str(bookmark_str, 'Collection', disclaimer_info.dc_arr.join(' ')) if check_nil_or_empty_string disclaimer_info.dc_arr
  add_info_str(bookmark_str, 'Genre', disclaimer_info.genre_arr.join(' ')) if check_nil_or_empty_string disclaimer_info.genre_arr

  #add_info_str(bookmark_str, 'Subject', disclaimer_info.subject_arr.join(' ')) if check_nil_or_empty_string disclaimer_info.subject_arr

  add_info_str(bookmark_str, 'Shelfmark', disclaimer_info.shelfmark_arr.join(' ')) if check_nil_or_empty_string disclaimer_info.shelfmark_arr
  add_info_str(bookmark_str, 'Digitized at', disclaimer_info.rights_owner_arr.join(' ')) if check_nil_or_empty_string disclaimer_info.rights_owner_arr


  unless request_logical_part
    (0..(disclaimer_info.log_label_arr.size-1)).each {|index|
      add_to_bookmark_str(bookmark_str, disclaimer_info.log_label_arr[index], disclaimer_info.log_level_arr[index], disclaimer_info.log_start_page_index_arr[index])
    }
  else
    log_id_index = solr_resp['log_id'].index log_id

    log_start_page_index = solr_resp['log_start_page_index'][log_id_index]
    log_end_page_index   = solr_resp['log_end_page_index'][log_id_index]

    (disclaimer_info.log_label_arr[log_start_page_index]..disclaimer_info.log_label_arr[log_end_page_index]).each {|index|
      add_to_bookmark_str(bookmark_str, disclaimer_info.log_label_arr[index], disclaimer_info.log_level_arr[index], disclaimer_info.log_start_page_index_arr[index])
    }
  end

  #FileUtils.rm(to_full_pdf, :force => true)

  open(data_file, 'w') {|f|
    f.puts bookmark_str
  }

  system "pdftk #{to_pdf_dir}/tmp.pdf update_info_utf8 #{data_file} output #{to_pdf_dir}/tmp_2.pdf"

  log_debug "Finish Metadata creation #{to_pdf_dir}/tmp_2.pdf"
end

def add_label_and_value label, text, pdf_obj

  # todo remove this
  puts "label: #{label}, text: #{text} (#{text.class})"

  if text.class == Array
    puts "label-> #{text.class}"
    pdf_obj.text("<b>#{label}:</b> #{text.join '; '}", :inline_format => true)
  else
    pdf_obj.text("<b>#{label}:</b> #{text}", :inline_format => true)
  end

end

def check_nil_or_empty_string obj

  if obj.class == Array
    return false if (obj == nil) || (obj.empty?) || (obj.first == " ")
  else
    return false if (obj == nil) || (obj == " ") || (obj == "")
  end

  return true

end

def add_disclaimer_pdftk_system(to_full_pdf_path, to_pdf_dir, work, log_id, request_logical_part, disclaimer_info)

  # todo differentiate work and log_parts

  Prawn::Document.generate("#{to_pdf_dir}/disclaimer.pdf", page_size: [595, 842], page_layout: :portrait) do |pdf|

    pdf.image "#{ENV['LOGO_PATH']}", :position => :right

    pdf.move_down 40
    pdf.font_size 9
    pdf.font "Helvetica", :style => :normal

    pdf.text "<font size='12'><b>Work</b></font><br><br>", :inline_format => true

    add_label_and_value("Title", disclaimer_info.title_arr, pdf) if check_nil_or_empty_string disclaimer_info.title_arr
    add_label_and_value("Subtitle", disclaimer_info.subtitle_arr, pdf) if check_nil_or_empty_string disclaimer_info.subtitle_arr

    add_label_and_value("Creator", disclaimer_info.bycreator, pdf) if check_nil_or_empty_string disclaimer_info.bycreator
    add_label_and_value("Publisher", disclaimer_info.publisher, pdf) if check_nil_or_empty_string disclaimer_info.publisher
    add_label_and_value("Place", disclaimer_info.place_publish, pdf) if check_nil_or_empty_string disclaimer_info.place_publish
    add_label_and_value("Year", disclaimer_info.year_publish_string, pdf) if check_nil_or_empty_string disclaimer_info.year_publish_string

    add_label_and_value("Collection", disclaimer_info.dc_arr, pdf) if check_nil_or_empty_string disclaimer_info.dc_arr
    add_label_and_value("Genre", disclaimer_info.genre_arr, pdf) if check_nil_or_empty_string disclaimer_info.genre_arr

    #add_label_and_value("Subject", disclaimer_info.subject_arr, pdf) if check_nil_or_empty_string disclaimer_info.subject_arr

    add_label_and_value("Shelfmark", disclaimer_info.shelfmark_arr, pdf) if check_nil_or_empty_string disclaimer_info.shelfmark_arr
    add_label_and_value("Digitized at", disclaimer_info.rights_owner_arr, pdf) if check_nil_or_empty_string disclaimer_info.rights_owner_arr
    add_label_and_value("Work Id", work, pdf) unless work == nil

    add_label_and_value("PURL", disclaimer_info.purl, pdf) if check_nil_or_empty_string disclaimer_info.purl

    if check_nil_or_empty_string disclaimer_info.catalogue_arr
      disclaimer_info.catalogue_arr.each {|el|
        begin
          url = el.match(/(\S*\W)(\S*)/)[2]
        rescue Exception => e
          url = el
        end
        add_label_and_value("OPAC", "#{url}<br>", pdf)
      }
    end

    if request_logical_part
      puts "disclaimer_info.log_id: #{disclaimer_info.log_id}"

      pdf.move_down 5

      add_label_and_value("LOGID", log_id, pdf)
      i = disclaimer_info.log_id.index log_id
      puts "i: #{i}, disclaimer_info.log_id[i]: #{disclaimer_info.log_id[i]}"

      add_label_and_value("LOG Label", disclaimer_info.log_label_arr[i], pdf)
    end


    # todo remove this
    puts "disclaimer_info.parentdoc_work: #{disclaimer_info.parentdoc_work}"

    if check_nil_or_empty_string disclaimer_info.parentdoc_work
      pdf.move_down 10
      pdf.text("<font size='12'><b>Parent Work</b></font><br><br>", :inline_format => true)

      #add_label_and_value("Title", disclaimer_info.parentdoc_label, pdf) if check_nil_or_empty_string disclaimer_info.parentdoc_label
      add_label_and_value("Work Id", disclaimer_info.parentdoc_work, pdf) if check_nil_or_empty_string disclaimer_info.parentdoc_work
      add_label_and_value("PURL", "http://resolver.sub.uni-goettingen.de/purl?#{disclaimer_info.parentdoc_work.first}", pdf) if check_nil_or_empty_string disclaimer_info.parentdoc_work
      ppn = disclaimer_info.parentdoc_work.first.match(/PPN(\S*)/)[1]
      add_label_and_value("OPAC", "http://opac.sub.uni-goettingen.de/DB=1/PPN?PPN=#{ppn}", pdf) if check_nil_or_empty_string ppn
    end

    pdf.move_down 25
    pdf.text ENV['DISCLAIMER_TEXT'], :inline_format => true

    pdf.move_down 25
    pdf.text ENV['CONTACT_TEXT'], :inline_format => true, :valign => :bottom

  end


  unless request_logical_part
    system "pdftk #{to_pdf_dir}/disclaimer.pdf #{to_pdf_dir}/tmp_2.pdf  cat output #{to_full_pdf_path}"
  else
    system "pdftk #{to_pdf_dir}/disclaimer.pdf #{to_pdf_dir}/tmp.pdf  cat output #{to_full_pdf_path}"
  end

end


def merge_to_full_pdf_pdftk_system(to_pdf_dir, work, log_id, request_logical_part)

  solr_resp = (@solr.get 'select', :params => {:q => "work:#{work}", :fl => "page log_id log_start_page_index log_end_page_index"})['response']['docs'].first

  log_start_page_index = 0
  log_end_page_index   = -1

  if request_logical_part

    log_id_index = solr_resp['log_id'].index log_id

    log_start_page_index = (solr_resp['log_start_page_index'][log_id_index])-1
    log_end_page_index   = (solr_resp['log_end_page_index'][log_id_index])-1

  end

  solr_page_path_arr = (solr_resp['page'][log_start_page_index..log_end_page_index]).collect {|el| "#{to_pdf_dir}/#{el}.pdf"}

  system "pdftk #{solr_page_path_arr.join ' '} cat output #{to_pdf_dir}/tmp.pdf"

  solr_resp          = nil
  solr_page_path_arr = nil

  log_debug "Temporary Full PDF #{to_pdf_dir}/tmp.pdf created"
end


def get_image_depth_and_resolution path
  json = MiniMagick::Tool::Convert.new do |convert|
    convert << path
    convert << "json:"
  end

  json.gsub!("\r\n", " ")
  json.gsub!("\r", " ")
  json.gsub!("\n", " ")

  j = json.encode('UTF-8', :invalid => :replace, :undef => :replace)

  data = JSON.parse(j)
  [data["image"]['depth'], data["image"]['resolution']]
end


def convert(to_tmp_img, to_page_pdf_path)
  begin

    FileUtils.rm(to_page_pdf_path, :force => true)

    depth, resolution_arr = get_image_depth_and_resolution (to_tmp_img)

    #if (depth.to_i > 1) && (resolution_arr['x'].to_i > 72)
    if (resolution_arr['x'].to_i > 72) && (depth.to_i > 1)
      MiniMagick::Tool::Convert.new do |convert|
        convert << "-define" << "pdf:use-cropbox=true"
        convert << "#{to_tmp_img}"
        #convert << "-filter" << "Gaussian"
        #convert << "-units" << "PixelsPerInch"
        convert << "-resize" << "595x842"
        #convert << "-resize" << "364x598"
        convert << "-density" << "72"
        #convert << "-quality" << "85"
        convert << "#{to_page_pdf_path}"
      end
    else

      MiniMagick::Tool::Convert.new do |convert|
        convert << "-define" << "pdf:use-cropbox=true"
        convert << "#{to_tmp_img}"
        convert << "#{to_page_pdf_path}"
      end

    end


  rescue Exception => e
    log_error "Could not convert '#{to_tmp_img}' to: '#{to_page_pdf_path}'", e
    return false
  end

  log_debug "Conversion '#{to_tmp_img}' -> '#{to_page_pdf_path}' finished"

  return true
end


def all_images_converted?(work, pages_count)

  keys = @rredis.hkeys(work)
  if keys.size < pages_count
    false
  else
    true
  end
end


$vertx.event_bus().consumer("image.load") {|message|

  body = message.body()

  if (body != '' && body != nil)

    #msg  = body[1]
    json = JSON.parse body


    # todo remove this
    puts "json: #{json}"

    context              = json['context']
    id                   = json['id']
    work                 = json['work']
    log_id               = json['log_id']
    request_logical_part = json['request_logical_part']
    page                 = json['page']
    pages_count          = json['pages_count']

    # ---

    solr_work = (@solr.get 'select', :params => {:q => "work:#{work}", :fl => "image_format, product, baseurl"})['response']['docs'].first

    image_format = solr_work['image_format']
    baseurl      = solr_work['baseurl']
    product      = solr_work['product']

    to_pdf_dir       = "#{@pdfoutpath}/#{product}/#{work}/#{log_id}"
    img_url          = "#{baseurl}/tiff/#{work}/#{page}.#{image_format}"
    to_tmp_img       = "#{to_pdf_dir}/#{page}.#{image_format}"
    to_page_pdf_path = "#{to_pdf_dir}/#{page}.pdf"
    to_full_pdf_path = "#{to_pdf_dir}/#{work}.pdf"

    if request_logical_part
      to_full_pdf_path = "#{to_pdf_dir}/#{work}___#{log_id}.pdf"
    end

    FileUtils.mkdir_p(to_pdf_dir)

    # todo remove comment
    if download(img_url, to_tmp_img)

      # todo remove comment
      if convert(to_tmp_img, to_page_pdf_path)

        pushToQueue(work, page, true)

        #delete(to_tmp_img)
        #log_debug "deletion of #{to_tmp_img} finished"

        unless conversion_errors?(work)

          if all_images_converted?(work, pages_count)

            removeQueue(work)

            # todo remove comment
            merge_to_full_pdf_pdftk_system(to_pdf_dir, work, log_id, request_logical_part)


            disclaimer_info = load_metadata(work)

            unless request_logical_part
              # todo remove comment
              add_bookmarks_pdftk_system(to_pdf_dir, work, log_id, request_logical_part, disclaimer_info)
            end


            add_disclaimer_pdftk_system(to_full_pdf_path, to_pdf_dir, work, log_id, request_logical_part, disclaimer_info)


          end


          #    message.reply("#{img_url} processed")

        end

      else
        pushToQueue(work, 'err', "Conversion of #{work} failed")
      end
    else
      pushToQueue(work, 'err', "Download of #{work} failed")
    end

  end

}