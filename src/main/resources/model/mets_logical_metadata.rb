require 'logger'
require 'gelf'


class MetsLogicalMetadata

  attr_accessor :logicalElements,
                :doctype,
                :work,
                :title_page_index,
                :title_page,
                :phys_first_page_index,
                :phys_last_page_index,

                :facet_creator_personal,
                :facet_creator_corporate,
                :facet_person_personal,
                :facet_person_corporate,
                :date_modified,
                :date_indexed

  def initialize
    @logger       = GELF::Logger.new(ENV['GRAYLOG_URI'], ENV['GRAYLOG_PORT'].to_i, "WAN", {:facility => ENV['GRAYLOG_FACILITY']})
    @logger.level = ENV['DEBUG_MODE'].to_i


    @logicalElements = Hash.new

    @facet_creator_personal  = Array.new
    @facet_creator_corporate = Array.new
    @facet_person_personal   = Array.new
    @facet_person_corporate  = Array.new

    @title_page = 1
  end

  def addToLogicalElement(logicalElement)
    @logicalElements[logicalElement.id] = logicalElement
  end


  def to_solr_string

    h = Hash.new

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
      unless @doctype == "anchor"
        @logicalElements.values.each {|el|

          if (el.start_page_index != -1) && (el.end_page_index != -1)
            arr << el
          else
            h.merge! ({:parentdoc_work => el.parentdoc_work})
            h.merge! ({:parentdoc_label => el.label})
            h.merge! ({:parentdoc_type => el.type})
          end
        }
      else
        arr = @logicalElements.values
      end

      docstrct = arr[0]&.type
      docstrct = 'volume' if (@doctype == 'work') && (docstrct == 'map')

      h.merge! ({:docstrct => docstrct})

      arr[1..-1].each {|el|

        if (el.start_page_index != nil) && (el.end_page_index != nil)
          id << el.id
          type << el.type
          label << el.label

          start_page_index << el.start_page_index unless @doctype == "anchor"
          end_page_index << el.end_page_index unless @doctype == "anchor"

          level << el.level

          part_product << el.part_product
          part_work << el.part_work
          part_key << el.part_key
        else
          if el.id != nil
            @logger.error("[indexer] [GDZ-761] Inconsistency between logical and physical structMap for #{@work} (#{el.id})")
          end
        end

      }

      h.merge! ({:log_id => id})
      h.merge! ({:work_id => @work})
      h.merge! ({:log_type => type})
      h.merge! ({:log_label => label})

      h.merge! ({:log_start_page_index => start_page_index})
      h.merge! ({:log_end_page_index => end_page_index})

      h.merge! ({:log_level => level})

      h.merge! ({:log_part_product => part_product})
      h.merge! ({:log_part_work => part_work})
      h.merge! ({:log_part_key => part_key})

    end

    h.merge! ({:phys_first_page_index => @phys_first_page_index})
    h.merge! ({:phys_last_page_index => @phys_last_page_index})
    h.merge! ({:title_page => @title_page}) if (@title_page != nil) && (@doctype != "anchor")

    h.merge! ({:date_modified => @date_modified})
    h.merge! ({:date_indexed => @date_indexed})

    return h

  end


  def to_child_solr_string

    log_child_arr = Array.new

    hsh = Hash.new
    arr = Array.new

    if !@logicalElements.empty?

      unless @doctype == "anchor"
        @logicalElements.values.each {|el|

          if (el.start_page_index != -1) && (el.end_page_index != -1)
            arr << el
          else
            hsh.merge! ({:parentdoc_work => el.parentdoc_work})
            hsh.merge! ({:parentdoc_label => el.label})
            hsh.merge! ({:parentdoc_type => el.type})
          end
        }
      else
        arr = @logicalElements.values
      end

      docstrct = arr[0]&.type
      docstrct = 'volume' if (@doctype == 'work') && (docstrct == 'map')

      hsh.merge! ({:docstrct => docstrct})


      arr[1..-1].each {|el|

        child = Hash.new

        child.merge! ({:id => "#{@work}___#{el.id}"})
        child.merge! ({:work_id => @work})
        child.merge! ({:islog => true})
        child.merge! ({:doctype => 'log'})
        child.merge! ({:log_id => el.id})
        child.merge! ({:log_type => el.type}) unless el.type == nil
        child.merge! ({:log_label => el.label}) unless el.label == nil

        unless el.id == nil
          # LOG_0001  OR   log1
          if !el.id.index(/^LOG_/).nil?
            child.merge! ({:log_order => el.id.match(/LOG_(\d*)/)[1].to_i})
          elsif !el.id.index(/^log\d/).nil?
            child.merge! ({:log_order => el.id.match(/log(\d*)/)[1].to_i})
          else
            @logger.error("[indexer] Unexpected ID pattern #{el.id} for work #{@work}\t#{e.message}")
          end
        end

        child.merge! ({:log_start_page_index => el.start_page_index}) unless @doctype == "anchor"
        child.merge! ({:log_end_page_index => el.end_page_index}) unless @doctype == "anchor"
        child.merge! ({:log_level => el.level}) unless el.level == nil
        child.merge! ({:log_part_product => el.part_product}) unless el.part_product == nil
        child.merge! ({:log_part_work => el.part_work}) unless el.part_work == nil
        child.merge! ({:log_part_key => el.part_key}) unless el.part_key == nil
        child.merge! ({:parentdoc_work => el.parentdoc_work}) unless el.parentdoc_work == nil
        child.merge! ({:parentdoc_label => el.parentdoc_label}) unless el.parentdoc_label == nil
        child.merge! ({:parentdoc_type => el.parentdoc_type}) unless el.parentdoc_type == nil

        unless el.dmdsec_meta == nil
          el.dmdsec_meta.is_child = true
          child.merge! el.dmdsec_meta.to_solr_string
=begin
          @facet_creator_personal  += el.dmdsec_meta.facet_creator_personal if el.dmdsec_meta.facet_creator_personal != nil
          @facet_creator_corporate += el.dmdsec_meta.facet_creator_corporate if el.dmdsec_meta.facet_creator_corporate != nil
          @facet_person_personal   += el.dmdsec_meta.facet_person_personal if el.dmdsec_meta.facet_person_personal != nil
          @facet_person_corporate  += el.dmdsec_meta.facet_person_corporate if el.dmdsec_meta.facet_person_corporate != nil
=end
        end

        child.merge! ({:date_modified => @date_modified})
        child.merge! ({:date_indexed => @date_indexed})

        log_child_arr << child

      }

      hsh.merge! "_childDocuments_" => log_child_arr

      # todo add this, if logical info is removed from main solr doc
      # hsh.merge!({:phys_first_page_index => @phys_first_page_index})
      # hsh.merge!({:phys_last_page_index => @phys_last_page_index})
      # hsh.merge!(:title_page => @title_page) unless @title_page == nil

    end

    return hsh

  end

end
