class MetsFulltextMetadata

  attr_accessor :fulltexts,
                :fulltext_uris

  def initialize
    @fulltext_uris = Array.new
    @fulltexts     = Array.new
  end


  def addFulltextUri=(fulltextUri)
    @fulltext_uris = fulltextUri
  end


  def addFulltext=(fulltext)
    @fulltexts = fulltext
  end


  def fulltext_to_solr_string

    docs = Array.new

    if @iswork == true

      if !@fulltexts.empty?
        @fulltexts.each {|ft|

          h = Hash.new

          h.merge! ({:id => "#{ft.fulltext_of_work}_page_#{ft.fulltext_page_number}"})
          h.merge! ({:ft => ft.fulltext})
          h.merge! ({:ft_ref => ft.fulltext_ref})
          h.merge! ({:ft_of_work => ft.fulltext_of_work})
          h.merge! ({:ft_page_number => ft.fulltext_page_number})
          h.merge! ({:doctype => 'fulltext'})

          merge_title_info(h)

          docs << h
        }
      end

    end
    return docs

  end

  def to_solr_string

    h = Hash.new

    if !@fulltexts.empty?

      fulltext_arr     = Array.new
      fulltext_ref_arr = Array.new

      @fulltexts.each {|ft|
        fulltext_arr << ft.fulltext
        fulltext_ref_arr << ft.fulltext_ref
      }

      h.merge! ({:fulltext => fulltext_arr})
      h.merge! ({:fulltext_ref => fulltext_ref_arr})

    end

    return h

  end

end