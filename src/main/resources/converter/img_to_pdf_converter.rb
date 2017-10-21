# encoding: UTF-8

require 'logger'
require 'aws-sdk'
require 'redis'
require 'rsolr'
require 'json'
require 'open-uri'
require 'net/http'
require 'fileutils'
require 'mini_magick'
require "prawn"
#require 'pdftk'

require 'model/disclaimer_info'

class ImgToPdfConverter


  MAX_ATTEMPTS = ENV['MAX_ATTEMPTS'].to_i

  def initialize


    @pdfoutpath = ENV['OUT'] + ENV['PDF_OUT_SUB_PATH']
    @img_base_url = ENV['GDZ_IMG_BASE_URL']

    @logger       = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG

    @file_logger       = Logger.new(ENV['LOG'] + "/img_to_pdf_converter_#{Time.new.strftime('%y-%m-%d')}.log")
    @file_logger.level = Logger::DEBUG


    #@img_convert_queue  = ENV['REDIS_IMG_CONVERT_QUEUE']
    #@work_convert_queue  = ENV['REDIS_CONVERT_QUEUE']
    @rredis = Redis.new(
        :host => ENV['REDIS_HOST'],
        :port => ENV['REDIS_EXTERNAL_PORT'].to_i,
        :db => ENV['REDIS_DB'].to_i,
        :reconnect_attempts => 3
    #  :timeout            => 30,
    )

    @unique_queue = ENV['REDIS_UNIQUE_QUEUE']

    @solr = RSolr.connect :url => ENV['SOLR_ADR']

    @s3 = Aws::S3::Client.new(
        :access_key_id     => ENV['S3_AWS_ACCESS_KEY_ID'],
        :secret_access_key => ENV['S3_AWS_SECRET_ACCESS_KEY'],
        :endpoint          => ENV['S3_ENDPOINT'],
        :force_path_style  => true,
        :region            => 'us-west-2')

    @use_s3 = false
    @use_s3 = true if ENV['USE_S3'] == 'true'


    @nlh_bucket = ENV['S3_NLH_BUCKET']
    @gdz_bucket = ENV['S3_GDZ_BUCKET']

    @s3_pdf_key_pattern   = ENV['S3_PDF_KEY_PATTERN']
    @s3_image_key_pattern = ENV['S3_IMAGE_KEY_PATTERN']

    MiniMagick.configure do |config|
      config.validate_on_create = false
      config.validate_on_write  = false
      config.whiny              = false
    end

    #MiniMagick.logger.level = Logger::DEBUG

  end


  def log_error(msg, e)
    if e == nil
      @logger.error("[img_to_pdf_converter] #{msg}")
      @file_logger.error("[img_to_pdf_converter] #{msg}")
    else
      @logger.error("[img_to_pdf_converter] #{msg} \t#{e.message}")
      @file_logger.error("[img_to_pdf_converter] #{msg} \t#{e.message}\n\t#{e.backtrace}")
    end
  end

  def log_info(msg)
    @logger.info("[img_to_pdf_converter] #{msg}")
    @file_logger.info("[img_to_pdf_converter] #{msg}")
  end

  def log_debug(msg)
    @logger.debug("[img_to_pdf_converter] #{msg}")
    @file_logger.debug("[img_to_pdf_converter] #{msg}")
  end


# ---


  def download_from_webserver(img_url, to_tmp_img)
    attempts = 0
    begin
      resp = @s3.get_object(
          {bucket: s3_bucket, key: s3_key},
          target: path
      )
    rescue Exception => e
      @logger.error "[img_to_pdf_converter_job_builder] Could not get file (#{s3_bucket}/#{s3_key}) from S3 \t#{e.message}"
      @file_logger.error "[img_to_pdf_converter_job_builder] Could not get file (#{s3_bucket}/#{s3_key}) from S3 \t#{e.message}\n\t#{e.backtrace}"
      attempts = attempts + 1
      retry if (attempts < MAX_ATTEMPTS)

      return false
    end

    return true
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


  def download_from_s3(s3_bucket, s3_key, path)

    attempts = 0
    begin
      resp = @s3.get_object(
          {bucket: s3_bucket, key: s3_key},
          target: path
      )
    rescue Exception => e
      @logger.error "[img_to_pdf_converter_job_builder] Could not get file (#{s3_bucket}/#{s3_key}) from S3 \t#{e.message}"
      @file_logger.error "[img_to_pdf_converter_job_builder] Could not get file (#{s3_bucket}/#{s3_key}) from S3 \t#{e.message}\n\t#{e.backtrace}"
      attempts = attempts + 1
      retry if (attempts < MAX_ATTEMPTS)

      return false
    end

    return true
  end


  def push_object_to_s3(to_full_pdf_path, s3_bucket, s3_key)

    begin

      File.open(to_full_pdf_path, 'rb') do |file|

        begin
          resp = @s3.put_object(
              {
                  bucket: s3_bucket,
                  key: s3_key,
                  body: file.read
              }
          )

          log_debug "Full PDF #{to_full_pdf_path} added to S3"
        rescue Aws::S3::Errors::ServiceError => e
          puts "e.message: #{e}"
        end

      end


    rescue Exception => e
      @logger.error "[img_to_pdf_converter_job_builder] Could not push file (#{s3_key}) to S3 \t#{e.message}"
      @file_logger.error "[img_to_pdf_converter_job_builder] Could not push file (#{s3_key}) to S3 \t#{e.message}\n\t#{e.backtrace}"
    end


  end


  def get_page_count

    solr_resp = (@solr.get 'select', :params => {:q => "id:#{work}", :fl => "page log_id log_start_page_index log_end_page_index"})['response']['docs'].first

    log_start_page_index = 0
    log_end_page_index   = -1

    if request_logical_part

      log_id_index = solr_resp['log_id'].index log_id

      log_start_page_index = (solr_resp['log_start_page_index'][log_id_index])-1
      log_end_page_index   = (solr_resp['log_end_page_index'][log_id_index])-1

    end

    solr_page_path_arr = (solr_resp['page'][log_start_page_index..log_end_page_index]).collect {|el| "#{to_pdf_dir}/#{el}.pdf"}

  end

  def process_response(json)

    begin

      context              = json['context']
      id                   = json['id']
      log                  = json['log']
      log_id               = json['log_id']
      request_logical_part = json['request_logical_part']
      page                 = json['page']
      pages_count          = json['pages_count']

      # ---

      solr_work = (@solr.get 'select', :params => {:q => "id:#{id}", :fl => "image_format, product, baseurl"})['response']['docs'].first

      image_format = solr_work['image_format']
      baseurl      = solr_work['baseurl']
      product      = solr_work['product']

      to_pdf_dir = "#{@pdfoutpath}/#{product}/#{id}/#{log}"
      img_url = "#{@img_base_url}/tiff/#{id}/#{page}.#{image_format}"
      to_tmp_img = "#{to_pdf_dir}/#{page}.#{image_format}"
      to_page_pdf_path = "#{to_pdf_dir}/#{page}.pdf"


      FileUtils.mkdir_p(to_pdf_dir)

      if request_logical_part
        to_full_pdf_path = "#{to_pdf_dir}/#{log_id}.pdf"
      else
        to_full_pdf_path = "#{to_pdf_dir}/#{id}.pdf"
      end

      # s3://gdz/  OR s3://nlh/
      case context
        when 'nlh'
          s3_bucket = @nlh_bucket
        when 'gdz'
          s3_bucket = @gdz_bucket
      end

      s3_image_key = @s3_image_key_pattern % [id, page, image_format]

      if request_logical_part
        #s3_pdf_key = @s3_pdf_key_pattern % [work, id]
        s3_pdf_key = @s3_pdf_key_pattern % [id, log]
      else
        s3_pdf_key = @s3_pdf_key_pattern % [id, id]
      end


      # todo remove comment
      if @use_s3
        loaded = download_from_s3(s3_bucket, s3_image_key, to_tmp_img)
      else
        loaded = download_via_http(img_url, to_tmp_img)
      end

      if loaded

        if convert(to_tmp_img, to_page_pdf_path)

          pushToQueue(log_id, page, true)

          if all_images_converted?(log_id, pages_count)

            if !conversion_errors?(log_id)

              removeQueue(log_id)

              merge_to_full_pdf_pdftk_system(to_pdf_dir, id, log, request_logical_part)

              disclaimer_info = load_metadata(id)

              unless request_logical_part
                add_bookmarks_pdftk_system(to_pdf_dir, id, log, request_logical_part, disclaimer_info)
              end

              add_disclaimer_pdftk_system(to_full_pdf_path, to_pdf_dir, id, log, request_logical_part, disclaimer_info)

              if @use_s3
                upload_object_to_s3(to_full_pdf_path, s3_bucket, s3_pdf_key)
              end

              # cleanup
              remove_dir(to_pdf_dir)
              @rredis.del(@unique_queue, log_id)
              @logger.info "[img_to_pdf_converter] Finish PDF creation for '#{log_id}'"

            else
              pushToQueue(id, 'err', "Conversion of #{log_id} failed")
              @rredis.del(@unique_queue, log_id)
            end

          end
        else
          pushToQueue(log_id, 'err', "Download for #{log_id} failed")
          @rredis.del(@unique_queue, log_id)
        end

      end

    rescue Exception => e
      pushToQueue(id, 'err', "Download for #{log_id} failed")

      @rredis.del(@unique_queue, log_id)

      @logger.error "[img_to_pdf_converter] Processing problem with '#{json}' \t#{e.message}"
      @file_logger.error "[img_to_pdf_converter] Processing problem with '#{json}' \t#{e.message}\n\t#{e.backtrace}"
    end
  end


  def remove_file(path)
    FileUtils.remove_file(path, force = true)
  end

  def remove_dir(path)
    FileUtils.remove_dir(path, force = true)
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
      return false
    else
      log_error "Conversion errors with queue '#{queue}' (#{@rredis.hget(queue, 'err')})", nil
      return true
    end
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

  def load_metadata(id)

    disclaimer_info = DisclaimerInfo.new

    solr_work = (@solr.get 'select', :params => {:q => "id:#{id}", :fl => "purl catalogue log_id log_label  log_start_page_index  log_level   log_type    title subtitle shelfmark bycreator year_publish_string publisher place_publish genre dc subject rights_owner parentdoc_work parentdoc_label parentdoc_type"})['response']['docs'].first


    disclaimer_info.log_id                   = solr_work['log_id']
    disclaimer_info.log_label_arr            = solr_work['log_label']
    disclaimer_info.log_start_page_index_arr = solr_work['log_start_page_index']
    disclaimer_info.log_level_arr            = solr_work['log_level']
    disclaimer_info.log_type_arr             = solr_work['log_type']

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

  def add_bookmarks_pdftk_system(to_pdf_dir, id, log, request_logical_part, disclaimer_info)

    data_file = "#{to_pdf_dir}/data.txt"

    bookmark_str = ""

    add_info_str(bookmark_str, 'PURL', disclaimer_info.purl) if check_nil_or_empty_string disclaimer_info.purl
    add_info_str(bookmark_str, 'Catalogue', disclaimer_info.catalogue_arr.join(' ')) if check_nil_or_empty_string disclaimer_info.catalogue_arr

    add_info_str(bookmark_str, 'Work', id)
    add_info_str(bookmark_str, 'LOGID', log) if id != log
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


    if disclaimer_info.log_label_arr!= nil
      unless request_logical_part
        (0..(disclaimer_info.log_label_arr.size-1)).each {|index|
          add_to_bookmark_str(bookmark_str, disclaimer_info.log_label_arr[index], disclaimer_info.log_level_arr[index], disclaimer_info.log_start_page_index_arr[index])
        }
      else
        log_id_index = solr_resp['log_id'].index log

        log_start_page_index = solr_resp['log_start_page_index'][log_id_index]
        log_end_page_index   = solr_resp['log_end_page_index'][log_id_index]

        (disclaimer_info.log_label_arr[log_start_page_index]..disclaimer_info.log_label_arr[log_end_page_index]).each {|index|
          add_to_bookmark_str(bookmark_str, disclaimer_info.log_label_arr[index], disclaimer_info.log_level_arr[index], disclaimer_info.log_start_page_index_arr[index])
        }
      end
    end

    open(data_file, 'w') {|f|
      f.puts bookmark_str
    }

    system "pdftk #{to_pdf_dir}/tmp.pdf update_info_utf8 #{data_file} output #{to_pdf_dir}/tmp_2.pdf"

    log_debug "Metadata added to #{to_pdf_dir}/tmp_2.pdf"
  end

  def add_label_and_value label, text, pdf_obj

    if text.class == Array
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


  def request_catalogue(ppn)

    response   = ''
    unapi_url  = ENV['UNAPI_URI']
    unapi_path = ENV['UNAPI_PATH'] % ppn
    url        = URI(unapi_url)

    Net::HTTP.start(url.host, url.port) {|http|
      response = http.head(unapi_path)
      response
    }

    return response

  end


  def add_disclaimer_pdftk_system(to_full_pdf_path, to_pdf_dir, id, log, request_logical_part, disclaimer_info)

    begin

      Prawn::Document.generate("#{to_pdf_dir}/disclaimer.pdf", page_size: [595, 842], page_layout: :portrait) do |pdf|

        pdf.font_families.update(
            "OpenSans" => {:normal => "#{ENV['FONT_PATH']}/OpenSans/OpenSans-Regular.ttf",
                           :bold   => "#{ENV['FONT_PATH']}/OpenSans/OpenSans-Bold.ttf"})

        pdf.image "#{ENV['LOGO_PATH']}", :position => :right

        pdf.move_down 40
        pdf.font_size 9
        pdf.font "OpenSans", :style => :normal


        pdf.text "<font size='12'><b>Work</b></font><br><br>", :inline_format => true

        if check_nil_or_empty_string disclaimer_info.title_arr

          title_arr = disclaimer_info.title_arr.map {|title|
            if title.size > 80
              title[0..80]
            else
              title
            end
          }
          add_label_and_value("Title", title_arr, pdf)

        end

        add_label_and_value("Subtitle", disclaimer_info.subtitle_arr, pdf) if check_nil_or_empty_string disclaimer_info.subtitle_arr

        add_label_and_value("Creator", disclaimer_info.bycreator, pdf) if check_nil_or_empty_string disclaimer_info.bycreator
        add_label_and_value("Publisher", disclaimer_info.publisher, pdf) if check_nil_or_empty_string disclaimer_info.publisher
        add_label_and_value("Place", disclaimer_info.place_publish, pdf) if check_nil_or_empty_string disclaimer_info.place_publish
        add_label_and_value("Year", disclaimer_info.year_publish_string, pdf) if check_nil_or_empty_string disclaimer_info.year_publish_string

        add_label_and_value("Collection", disclaimer_info.dc_arr, pdf) if check_nil_or_empty_string disclaimer_info.dc_arr
        add_label_and_value("Genre", disclaimer_info.genre_arr, pdf) if check_nil_or_empty_string disclaimer_info.genre_arr

        add_label_and_value("Shelfmark", disclaimer_info.shelfmark_arr, pdf) if check_nil_or_empty_string disclaimer_info.shelfmark_arr
        add_label_and_value("Digitized at", disclaimer_info.rights_owner_arr, pdf) if check_nil_or_empty_string disclaimer_info.rights_owner_arr
        add_label_and_value("Work Id", id, pdf) unless id == nil

        add_label_and_value("PURL", disclaimer_info.purl, pdf) if check_nil_or_empty_string disclaimer_info.purl

        if id.start_with? 'PPN'
          ppn = id.match(/PPN(\S*)/)[1]

          if request_catalogue(ppn).code.to_i < 400
            add_label_and_value("OPAC", "http://opac.sub.uni-goettingen.de/DB=1/PPN?PPN=#{ppn}", pdf)
          end
        end

        if request_logical_part

          pdf.move_down 5

          add_label_and_value("LOGID", log, pdf)
          i = disclaimer_info.log_id.index log

          add_label_and_value("LOG Label", disclaimer_info.log_label_arr[i], pdf)
          add_label_and_value("LOG Type", disclaimer_info.log_type_arr[i], pdf)
        end

        if check_nil_or_empty_string disclaimer_info.parentdoc_work
          pdf.move_down 10
          pdf.text("<font size='12'><b>Parent Work</b></font><br><br>", :inline_format => true)

          parent_work = disclaimer_info.parentdoc_work
          #add_label_and_value("Title", disclaimer_info.parentdoc_label, pdf) if check_nil_or_empty_string disclaimer_info.parentdoc_label
          add_label_and_value("Work Id", parent_work, pdf) if check_nil_or_empty_string parent_work
          add_label_and_value("PURL", "http://resolver.sub.uni-goettingen.de/purl?#{disclaimer_info.parentdoc_work.first}", pdf) if check_nil_or_empty_string disclaimer_info.parentdoc_work

          parent_work = disclaimer_info.parentdoc_work.first
          if parent_work.start_with? 'PPN'
            ppn = parent_work.match(/PPN(\S*)/)[1]

            if request_catalogue(ppn).code.to_i < 400
              add_label_and_value("OPAC", "http://opac.sub.uni-goettingen.de/DB=1/PPN?PPN=#{ppn}", pdf)
            end
          end
        end

        pdf.font "OpenSans", :style => :normal

        pdf.move_down 250
        pdf.text ENV['DISCLAIMER_TEXT'], :inline_format => true

        pdf.move_down 25
        pdf.text ENV['CONTACT_TEXT'], :inline_format => true, :valign => :bottom

      end

      unless request_logical_part
        system "pdftk #{to_pdf_dir}/disclaimer.pdf #{to_pdf_dir}/tmp_2.pdf  cat output #{to_full_pdf_path}"
      else
        system "pdftk #{to_pdf_dir}/disclaimer.pdf #{to_pdf_dir}/tmp.pdf  cat output #{to_full_pdf_path}"
      end

    rescue Exception => e
      log_error "Problem with disclaimer creation", e

      unless request_logical_part
        system "pdftk templates/disclaimer.pdf #{to_pdf_dir}/tmp_2.pdf  cat output #{to_full_pdf_path}"
      else
        system "pdftk templates/disclaimer.pdf #{to_pdf_dir}/tmp.pdf  cat output #{to_full_pdf_path}"
      end

    end

    log_debug "Disclaimer added to #{to_full_pdf_path}"
  end

  def merge_to_full_pdf_pdftk_system(to_pdf_dir, id, log, request_logical_part)

    solr_resp = (@solr.get 'select', :params => {:q => "id:#{id}", :fl => "page log_id log_start_page_index log_end_page_index"})['response']['docs'].first

    log_start_page_index = 0
    log_end_page_index   = -1

    if request_logical_part

      log_id_index = solr_resp['log_id'].index log

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

    json.gsub!("\\\"", "'")

    json.gsub!("\r\n", " ")
    json.gsub!("\r", " ")
    json.gsub!("\n", " ")
    j = json.encode!('UTF-8', :invalid => :replace, :undef => :replace, replace: '')

    begin
      data = JSON.parse(j)
      return [data["image"]['depth'], data["image"]['resolution']]
    rescue Exception => e
      log_error "Problem with image data \njson: '#{json}' \nj: '#{j}'", e
    end

  end


  def convert(to_tmp_img, to_page_pdf_path)

    begin

      FileUtils.rm(to_page_pdf_path, :force => true)

      depth, resolution_arr = get_image_depth_and_resolution (to_tmp_img)

      if (resolution_arr != nil) && (!resolution_arr.empty?) && (resolution_arr['x'].to_i > 72) && (depth.to_i != nil) && (depth.to_i > 1)
        MiniMagick::Tool::Convert.new do |convert|
          convert << "-define" << "pdf:use-cropbox=true"
          convert << "#{to_tmp_img}"
          #convert << "-filter" << "Gaussian"
          #convert << "-units" << "PixelsPerInch"
          convert << "-resize" << "595x842"
          #convert << "-resize" << "364x598"
          convert << "-density" << "72"
          convert << "-quality" << "95"
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

    return true
  end


  def all_images_converted?(queue, pages_count)

    keys = @rredis.hkeys(queue)

    if keys.size < pages_count
      false
    else
      true
    end
  end


end

# {"id":"PPN669170356" , "context": "gdz"}
# {"s3_key": "mets/PPN669170356.xml" , "context": "gdz"}