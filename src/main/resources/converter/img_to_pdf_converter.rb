# encoding: UTF-8
require 'rubygems'

require 'logger'
require 'gelf'
require 'aws-sdk'
require 'redis'
require 'rsolr'
require 'json'
require 'open-uri'
require 'net/http'
require 'fileutils'
require 'mini_magick'
require 'vips'
require "prawn-svg"

require 'model/disclaimer_info'

class ImgToPdfConverter


  MAX_ATTEMPTS     = ENV['MAX_ATTEMPTS'].to_i
  CONVERSION_ERROR = 1
  DOWNLOAD_ERROR   = 1

  def initialize


    @pdfoutpath   = ENV['OUT'] + ENV['PDF_OUT_SUB_PATH']
    @img_base_url = ENV['GDZ_IMG_BASE_URL']

    @logger       = GELF::Logger.new(ENV['GRAYLOG_URI'], ENV['GRAYLOG_PORT'].to_i, "WAN", {:facility => ENV['GRAYLOG_FACILITY']})
    @logger.level = ENV['DEBUG_MODE'].to_i

    #@img_convert_queue  = ENV['REDIS_IMG_CONVERT_QUEUE']
    #@work_convert_queue  = ENV['REDIS_CONVERT_QUEUE']
    @rredis = Redis.new(
        :host               => ENV['REDIS_HOST'],
        :port               => ENV['REDIS_EXTERNAL_PORT'].to_i,
        :db                 => ENV['REDIS_DB'].to_i,
        :reconnect_attempts => 3
    )

    @unique_queue = ENV['REDIS_UNIQUE_QUEUE']

    @solr_gdz = RSolr.connect :url => ENV['SOLR_GDZ_ADR']

    @use_s3 = false
    @use_s3 = true if ENV['USE_S3'] == 'true'

    if @use_s3
      @s3 = Aws::S3::Client.new(
          :access_key_id     => ENV['S3_AWS_ACCESS_KEY_ID'],
          :secret_access_key => ENV['S3_AWS_SECRET_ACCESS_KEY'],
          :endpoint          => ENV['S3_ENDPOINT'],
          :force_path_style  => true,
          :region            => 'us-west-2')
    end

    @nlh_bucket = ENV['S3_NLH_BUCKET']
    @gdz_bucket = ENV['S3_GDZ_BUCKET']

    @s3_pdf_key_pattern   = ENV['S3_PDF_KEY_PATTERN']
    @s3_image_key_pattern = ENV['S3_IMAGE_KEY_PATTERN']

    MiniMagick.configure do |config|
      config.validate_on_create = false
      config.validate_on_write  = false
      #config.whiny              = false
    end

    #MiniMagick.logger.level = Logger::DEBUG

  end

# ---

  def download_via_http(url, path)

    attempts = 0

    begin
      open(path, 'wb') do |file|
        file << open(url).read
      end
    rescue Exception => e
      attempts = attempts + 1
      retry if (attempts < MAX_ATTEMPTS)
      @logger.error("[img_converter] [GDZ-527] Could not download '#{url}' \t#{e.message}")
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
      @logger.error "[img_converter] [GDZ-527] Could not download file (#{s3_bucket}/#{s3_key}) from S3 \t#{e.message}"
      attempts = attempts + 1
      retry if (attempts < MAX_ATTEMPTS)

      return false
    end

    return true
  end


  def upload_object_to_s3(to_full_pdf_path, s3_bucket, s3_key)

    begin

      File.open(to_full_pdf_path, 'rb') do |file|

        begin
          resp = @s3.put_object(
              {
                  bucket: s3_bucket,
                  key:    s3_key,
                  body:   file.read
              }
          )
          @logger.debug("[img_converter] Full PDF #{to_full_pdf_path} added to S3")
        rescue Aws::S3::Errors::ServiceError => e
          @logger.error "[img_converter] Could not upload PDF #{to_full_pdf_path} to to S3 \t#{e.message}"
        end

      end


    rescue Exception => e
      @logger.error "[img_converter] Could not push file (#{s3_key}) to S3 \t#{e.message}"
    end


  end


  def get_page_count

    solr_resp = (@solr_gdz.get 'select', :params => {:q => "id:#{work}", :fl => "page log_id log_start_page_index log_end_page_index"})['response']['docs'].first

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
      pages_count          = json['pages_count']

      page                 = json['page']
      pdf_exist            = json['pdf_exist']
      log_start_page_index = json['log_start_page_index']
      log_end_page_index   = json['log_end_page_index']

      # ---

      solr_work = (@solr_gdz.get 'select', :params => {:q => "id:#{id}", :fl => "image_format, product, baseurl"})['response']['docs'].first

      image_format = solr_work['image_format']
      baseurl      = solr_work['baseurl']
      product      = solr_work['product']

      pdf_dir          = "#{@pdfoutpath}/#{product}/#{id}"
      to_pdf_dir       = "#{@pdfoutpath}/#{product}/#{id}/#{log}"
      img_url          = "#{@img_base_url}/tiff/#{id}/#{page}.#{image_format}"
      to_tmp_img       = "#{to_pdf_dir}/#{page}.#{image_format}"
      to_tmp_jpg       = "#{to_pdf_dir}/#{page}.jpg"
      to_page_pdf_path = "#{to_pdf_dir}/#{page}.pdf"
      to_full_pdf_path = "#{to_pdf_dir}/#{id}.pdf"
      to_log_pdf_path  = "#{to_pdf_dir}/#{log}.pdf"

      if request_logical_part
        to_full_pdf_path = "#{to_pdf_dir}/#{log}.pdf"
      else
        to_full_pdf_path = "#{to_pdf_dir}/#{id}.pdf"
      end

      FileUtils.mkdir_p(to_pdf_dir)

      # s3://gdz/  OR s3://nlh/
      case context
        when 'nlh'
          s3_bucket = @nlh_bucket
        when 'gdz'
          s3_bucket = @gdz_bucket
      end

      s3_pdf_key     = @s3_pdf_key_pattern % [id, id]
      s3_log_pdf_key = @s3_pdf_key_pattern % [id, log]


      if pdf_exist && request_logical_part

        download_from_s3(s3_bucket, s3_pdf_key, to_full_pdf_path)

        removeQueue(log_id)

        #merge_to_full_pdf_pdftk_system(to_pdf_dir, id, log, request_logical_part)
        cut_from_full_pdf_pdftk_system(to_full_pdf_path, to_pdf_dir, id, log, log_start_page_index, log_end_page_index)

        # todo folow up from here

        disclaimer_info = load_metadata(id)

        # log pdf instead of to_full_pdf
        add_disclaimer_pdftk_system(to_log_pdf_path, to_pdf_dir, id, log, request_logical_part, disclaimer_info)

        if @use_s3
          upload_object_to_s3(to_log_pdf_path, s3_bucket, s3_log_pdf_key)
        end

        remove_dir(to_pdf_dir)

        @logger.info("[img_converter] Finish PDF creation for '#{log_id}'")

        @rredis.del(@unique_queue, log_id)

      elsif !pdf_exist


        s3_image_key = @s3_image_key_pattern % [id, page, image_format]

        if @use_s3
          load_succeed = download_from_s3(s3_bucket, s3_image_key, to_tmp_img)
        else
          load_succeed = download_via_http(img_url, to_tmp_img)
        end

        if load_succeed
          convert(to_tmp_img, to_tmp_jpg, to_page_pdf_path)
        else
          FileUtils.cp("templates/page_not_found_error_1.pdf", to_page_pdf_path)
        end

        pushToQueue(log_id, page, true)

        if all_images_converted?(log_id, pages_count)

          removeQueue(log_id)

          merge_to_full_pdf_pdftk_system(to_pdf_dir, id, log, request_logical_part)

          disclaimer_info = load_metadata(id)

          unless request_logical_part
            add_bookmarks_pdftk_system(to_pdf_dir, id, log, disclaimer_info)
          end

          add_disclaimer_pdftk_system(to_full_pdf_path, to_pdf_dir, id, log, request_logical_part, disclaimer_info)
          begin
            if @use_s3
              if request_logical_part
                upload_object_to_s3(to_full_pdf_path, s3_bucket, s3_log_pdf_key)
              else
                upload_object_to_s3(to_full_pdf_path, s3_bucket, s3_pdf_key)
              end
            end
          rescue Exception => e

            GC.start

            remove_dir(to_pdf_dir)

            @logger.error("[img_converter] Upload to S3 failed #{log_id}\t#{e.message}")

            @rredis.del(@unique_queue, log_id)

          end

          GC.start

          remove_dir(to_pdf_dir)

          @logger.info("[img_converter] Finish PDF creation for #{log_id}")

          @rredis.del(@unique_queue, log_id)

        end

      else
        # nothing to do
        @logger.debug("[img_converter] PDF for '#{log_id}'  already exist (do nothing)")

        @rredis.del(@unique_queue, log_id)
      end

    rescue Exception => e
      @logger.error "[img_converter] Processing problem with request data '#{json}' \t#{e.message}"
    end
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

    solr_work = (@solr_gdz.get 'select', :params => {:q => "id:#{id}", :fl => "purl catalogue log_id log_label  log_start_page_index  log_level   log_type    title subtitle shelfmark bycreator year_publish_string publisher place_publish genre dc subject rights_owner parentdoc_work parentdoc_label parentdoc_type"})['response']['docs'].first


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

  def add_bookmarks_pdftk_system(to_pdf_dir, id, log, disclaimer_info)

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
      #unless request_logical_part
      (0..(disclaimer_info.log_label_arr.size-1)).each {|index|
        add_to_bookmark_str(bookmark_str, disclaimer_info.log_label_arr[index], disclaimer_info.log_level_arr[index], disclaimer_info.log_start_page_index_arr[index])
      }
      # else
      #   log_id_index = solr_resp['log_id'].index log
      #
      #   log_start_page_index = solr_resp['log_start_page_index'][log_id_index]
      #   log_end_page_index   = solr_resp['log_end_page_index'][log_id_index]
      #
      #   (disclaimer_info.log_label_arr[log_start_page_index]..disclaimer_info.log_label_arr[log_end_page_index]).each {|index|
      #     add_to_bookmark_str(bookmark_str, disclaimer_info.log_label_arr[index], disclaimer_info.log_level_arr[index], disclaimer_info.log_start_page_index_arr[index])
      #   }
      #end
    end

    open(data_file, 'w') {|f|
      f.puts bookmark_str
    }

    system "pdftk #{to_pdf_dir}/tmp.pdf update_info_utf8 #{data_file} output #{to_pdf_dir}/tmp_2.pdf"

    @logger.debug("[img_converter] Metadata added to #{to_pdf_dir}/tmp_2.pdf")
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
      return false if (obj == nil) || (obj.empty?) || (obj.first == " ") || (obj.first == "")
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


# @param [Object]  pdf_path
# @param [Object]  to_pdf_dir
# @param [Object]  id
# @param [Object]  log
# @param [Object]  request_logical_part
# @param [Object]  disclaimer_info
# @return [Object]
  def add_disclaimer_pdftk_system(pdf_path, to_pdf_dir, id, log, request_logical_part, disclaimer_info)

    begin

      Prawn::Document.generate("#{to_pdf_dir}/disclaimer.pdf", page_size: [595, 842], page_layout: :portrait) do |pdf|

        pdf.font_families.update(
            "OpenSans" => {:normal => "#{ENV['FONT_PATH']}/OpenSans/OpenSans-Regular.ttf",
                           :bold   => "#{ENV['FONT_PATH']}/OpenSans/OpenSans-Bold.ttf"})

        pdf.svg IO.read(ENV['LOGO_PATH']), at: [200, 780]

        pdf.move_down 40
        pdf.font_size 9
        pdf.font "OpenSans", :style => :normal


        pdf.text "<font size='12'><b>Werk</b></font><br><br>", :inline_format => true

        if check_nil_or_empty_string disclaimer_info.title_arr

          title_arr = disclaimer_info.title_arr.map {|title|
            if title.size > 80
              title[0..80]
            else
              title
            end
          }
          add_label_and_value("Titel", title_arr, pdf)

        end

        add_label_and_value("Untertitel", disclaimer_info.subtitle_arr, pdf) if check_nil_or_empty_string disclaimer_info.subtitle_arr

        add_label_and_value("Autor", disclaimer_info.bycreator, pdf) if check_nil_or_empty_string disclaimer_info.bycreator
        add_label_and_value("Verlag", disclaimer_info.publisher, pdf) if check_nil_or_empty_string disclaimer_info.publisher
        add_label_and_value("Ort", disclaimer_info.place_publish, pdf) if check_nil_or_empty_string disclaimer_info.place_publish
        add_label_and_value("Jahr", disclaimer_info.year_publish_string, pdf) if check_nil_or_empty_string disclaimer_info.year_publish_string

        add_label_and_value("Kollektion", disclaimer_info.dc_arr, pdf) if check_nil_or_empty_string disclaimer_info.dc_arr
        add_label_and_value("Gattung", disclaimer_info.genre_arr, pdf) if check_nil_or_empty_string disclaimer_info.genre_arr

        add_label_and_value("Signatur", disclaimer_info.shelfmark_arr, pdf) if check_nil_or_empty_string disclaimer_info.shelfmark_arr
        add_label_and_value("Digitalisiert", disclaimer_info.rights_owner_arr, pdf) if check_nil_or_empty_string disclaimer_info.rights_owner_arr
        add_label_and_value("Werk Id", id, pdf) unless id == nil

        add_label_and_value("PURL", disclaimer_info.purl, pdf) if check_nil_or_empty_string disclaimer_info.purl

        if id.start_with? 'PPN'
          ppn = id.match(/PPN(\S*)/)[1]

          if request_catalogue(ppn).code.to_i < 400
            add_label_and_value("OPAC", "http://opac.sub.uni-goettingen.de/DB=1/PPN?PPN=#{ppn}", pdf)
          end
        end

        if request_logical_part

          pdf.move_down 5

          add_label_and_value("LOG Id", log, pdf)
          i = disclaimer_info.log_id.index log

          add_label_and_value("LOG Titel", disclaimer_info.log_label_arr[i], pdf)
          add_label_and_value("LOG Typ", disclaimer_info.log_type_arr[i], pdf)
        end

        if check_nil_or_empty_string disclaimer_info.parentdoc_work
          pdf.move_down 10
          pdf.text("<font size='12'><b>Übergeordnetes Werk</b></font><br><br>", :inline_format => true)

          parent_work = disclaimer_info.parentdoc_work
          #add_label_and_value("Title", disclaimer_info.parentdoc_label, pdf) if check_nil_or_empty_string disclaimer_info.parentdoc_label
          add_label_and_value("Werk Id", parent_work, pdf) if check_nil_or_empty_string parent_work
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

        pdf.move_down 200
        pdf.text ENV['DISCLAIMER_TEXT'], :inline_format => true

        #pdf.move_down 25
        pdf.text ENV['CONTACT_TEXT'], :inline_format => true, :valign => :bottom

      end

      unless request_logical_part
        system "pdftk #{to_pdf_dir}/disclaimer.pdf #{to_pdf_dir}/tmp_2.pdf  cat output #{pdf_path}"
        FileUtils.rm("#{to_pdf_dir}/tmp_2.pdf")
      else
        system "pdftk #{to_pdf_dir}/disclaimer.pdf #{to_pdf_dir}/tmp.pdf  cat output #{pdf_path}"
        FileUtils.rm("#{to_pdf_dir}/tmp.pdf")
      end

    rescue Exception => e
      @logger.error("[img_converter] Problem with disclaimer creation \t#{e.message}")

      unless request_logical_part
        system "pdftk templates/disclaimer.pdf #{to_pdf_dir}/tmp_2.pdf  cat output #{pdf_path}"
        FileUtils.rm("#{to_pdf_dir}/tmp_2.pdf")
      else
        system "pdftk templates/disclaimer.pdf #{to_pdf_dir}/tmp.pdf  cat output #{pdf_path}"
        FileUtils.rm("#{to_pdf_dir}/tmp.pdf")
      end

    end

    @logger.debug("[img_converter] Disclaimer added to #{pdf_path}")
  end

  def cut_from_full_pdf_pdftk_system(pdf_path, to_pdf_dir, id, log, log_start_page_index, log_end_page_index)

    #response = (@solr_gdz.get 'select', :params => {:q => "id:#{id}", :fl => "phys_order"})['response']['docs'].first
    #if response['numFound'] > 0
    solr_resp = (@solr_gdz.get 'select', :params => {:q => "id:#{id}", :fl => "phys_order"})['response']['docs'].first


    #first_page = solr_resp['phys_order'][log_start_page_index].to_i
    #last_page  = solr_resp['phys_order'][log_end_page_index].to_i

    first_page = (solr_resp['phys_order'][log_start_page_index].to_i)+1
    last_page  = (solr_resp['phys_order'][log_end_page_index].to_i)+1

    system "pdftk #{pdf_path} cat #{first_page}-#{last_page} output #{to_pdf_dir}/tmp.pdf"

    @logger.debug("[img_converter] Temporary Full PDF #{to_pdf_dir}/tmp.pdf created")

  end

  def merge_to_full_pdf_pdftk_system(to_pdf_dir, id, log, request_logical_part)

    solr_resp = (@solr_gdz.get 'select', :params => {:q => "id:#{id}", :fl => "page log_id log_start_page_index log_end_page_index"})['response']['docs'].first

    log_start_page_index = 0
    log_end_page_index   = -1

    if request_logical_part

      log_id_index = solr_resp['log_id'].index log

      log_start_page_index = (solr_resp['log_start_page_index'][log_id_index])-1
      log_end_page_index   = (solr_resp['log_end_page_index'][log_id_index])-1

      #log_start_page_index = (solr_resp['log_start_page_index'][log_id_index])
      #log_end_page_index   = (solr_resp['log_end_page_index'][log_id_index])

    end

    solr_page_path_arr = (solr_resp['page'][log_start_page_index..log_end_page_index]).collect {|el| "#{to_pdf_dir}/#{el}.pdf"}

    system "pdftk #{solr_page_path_arr.join ' '} cat output #{to_pdf_dir}/tmp.pdf"

    @logger.debug("[img_converter] Temporary Full PDF #{to_pdf_dir}/tmp.pdf created")

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

      image = JSON.parse(j)['image']

      if image != nil
        return [image['depth'], image['resolution']]
      else
        return [nil, {}]
      end
    rescue Exception => e
      @logger.error("[img_converter] Problem with image meta data for path #{path} \t#{e.message}")
      return [nil, {}]
    end

  end


  def convert(to_tmp_img, to_tmp_jpg, to_page_pdf_path)

    begin

      depth, resolution_hsh = get_image_depth_and_resolution (to_tmp_img)

      succeed = false

      if (resolution_hsh != nil) && (!resolution_hsh.empty?) && (resolution_hsh['x'].to_i > 72) && (depth.to_i != nil) && (depth.to_i > 1)
        begin
          Vips::Image.tiffload(to_tmp_img).jpegsave(to_tmp_jpg)
          succeed = true
        rescue Exception => e
          # nothing
        end
      end

      MiniMagick::Tool::Convert.new do |convert|
        convert << "-define" << "pdf:use-cropbox=true"

        if succeed
          convert << "#{to_tmp_jpg}"
        else
          convert << "#{to_tmp_img}"
        end
        convert << "#{to_page_pdf_path}"
      end

      if succeed
        FileUtils.rm(to_tmp_jpg)
        FileUtils.rm(to_tmp_img)
      else
        FileUtils.rm(to_tmp_img)
      end

    rescue Exception => e
      FileUtils.cp("templates/conversion_error_2.pdf", to_page_pdf_path)

      @logger.error("[img_converter] [GDZ-677] Could not convert '#{to_tmp_img}' to: '#{to_page_pdf_path}'")
      #@logger.error("[img_converter] [GDZ-677] Could not convert '#{to_tmp_img}' to: '#{to_page_pdf_path}' \t#{e.message}")
    end
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
