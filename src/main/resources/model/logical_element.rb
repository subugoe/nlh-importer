require 'helper/mappings'

class LogicalElement

  attr_accessor :doctype,
                :id,
                :dmdid,
                :admid,
                :order,
                :start_page_index,
                :end_page_index,
                :part_product,
                :part_work,
                :part_key,
                :level,
                :parentdoc_work,
                :parentdoc_label,
                :parentdoc_type,
                :dmdsec_meta,      # :label, :type, :volume_uri
                :isLog_part

  def initialize
    @isLog_part = false
  end

  def label=(label)
    # Mapping no longer desired
    # l = Mappings.strctype_label(label)
    #l = label if l == nil
    #l = label
    #@label = l
    @label = label
  end

  def label
    @label
  end

  def type=(type)
    #t = Mappings.strctype_type(type)
    #t = type if t == nil
    #@type = t
    @type = type
  end

  def type
    @type
  end

end
