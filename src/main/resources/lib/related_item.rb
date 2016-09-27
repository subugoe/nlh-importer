class RelatedItem

  attr_accessor :title, :title_abbreviated, :title_partnumber, :type, :note #, :recordInfo # , :titleInfos

  def to_solr_string

    h = Hash.new

    h.merge!({
                 :parentdoc_title             => @title,
                 :parentdoc_title_abbreviated => @title_abbreviated,
                 :parentdoc_title_partnumber  => @title_partnumber,
                 :parentdoc_note              => @note,
                 :parentdoc_type              => @type

             })

    return h

  end

end