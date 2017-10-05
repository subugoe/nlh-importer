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
                :facet_person_corporate


  def initialize
    @logicalElements = Hash.new

    @facet_creator_personal  = Array.new
    @facet_creator_corporate = Array.new
    @facet_person_personal   = Array.new
    @facet_person_corporate  = Array.new

    @title_page = 1
    #@title_page_index = 0

    @logger       = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG
  end

  # def addLogicalElement=(logicalElement)
  #   @logicalElements += logicalElement
  # end

  def addToLogicalElement(logicalElement)
    @logicalElements[logicalElement.id] = logicalElement
  end


  def to_solr_string

    h = Hash.new

    if !@logicalElements.empty?

      id               = Array.new
      work_id          = Array.new
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
      unless @doctype == "collection"
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

      h.merge! ({:docstrct => arr[0]&.type})

      arr[1..-1].each {|el|

        id << el.id
        work_id << @work
        type << el.type
        label << el.label

        #dmdid << el.dmdid
        #admid << el.admid

        start_page_index << el.start_page_index unless @doctype == "collection"
        end_page_index << el.end_page_index unless @doctype == "collection"

        level << el.level

        part_product << el.part_product
        part_work << el.part_work
        part_key << el.part_key
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
    h.merge! ({:title_page => @title_page}) if (@title_page != nil) && (@doctype != "collection")

    return h

  end


  def to_child_solr_string

    log_child_arr = Array.new

    hsh = Hash.new
    arr = Array.new

    if !@logicalElements.empty?

      unless @doctype == "collection"
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

      hsh.merge! ({:docstrct => arr[0]&.type})

      arr[1..-1].each {|el|

        child = Hash.new

        child.merge! ({:id => "#{@work}___#{el.id}"})
        child.merge! ({:work_id => @work})
        child.merge! ({:islog => true})
        child.merge! ({:doctype => 'log'})
        child.merge! ({:log_id => el.id})
        child.merge! ({:log_type => el.type}) unless el.type == nil
        child.merge! ({:log_label => el.label}) unless el.label == nil
        child.merge! ({:log_order => el.id.match(/LOG_(\d*)/)[1].to_i}) unless el.id == nil
        child.merge! ({:log_start_page_index => el.start_page_index}) unless @doctype == "collection"
        child.merge! ({:log_end_page_index => el.end_page_index}) unless @doctype == "collection"
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
