require 'helper/mappings'

class LogicalElement

  attr_accessor :doctype, :id, :dmdid, :admid, :start_page_index, :end_page_index, :part_product, :part_work, :part_key, :level, :parentdoc_work, :parentdoc_label, :parentdoc_type # :label, :type, :volume_uri

  def label=(label)
    l = Mappings.strctype_label(label)
    l = label if l == nil

    @label = l
  end

  def label
    @label
  end

  def type=(type)
    t = Mappings.strctype_type(type)
    t = type if t == nil

    @type = t
  end

  def type
    @type
  end

end
