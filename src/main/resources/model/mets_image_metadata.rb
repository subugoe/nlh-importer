class MetsImageMetadata

  attr_accessor :image_format,
               # :baseurl,
                :access_pattern,
                :product,
                :work,
                :pages,
                :page_keys

  #             :presentation_image_uris,
  #             :thumb_image_uris,


  def initialize
    #@presentation_image_uris = Array.new
    #@thumb_image_uris        = Array.new
    @pages     = Array.new
    @page_keys = Array.new

  end

=begin
  def addPresentationImageUri=(presentationImageUri)
    @presentation_image_uris = presentationImageUri
  end

  def addThumbImageUri=(thumbImageUri)
    @thumb_image_uris += thumbImageUri
  end
=end

  def add_page_arr=(page_arr)
    @pages = page_arr
  end

  def add_page_key_arr=(page_key_arr)
    @page_keys = page_key_arr
  end

  def to_solr_string

    h = Hash.new

    h.merge!({:work => @work}) unless @work == nil
    h.merge!({:product => @product}) unless @product == nil

    h.merge!({:image_format => @image_format}) unless @image_format == nil
    #h.merge! ({:baseurl => @baseurl}) unless @baseurl == nil
    #h.merge! ({:access_pattern => @access_pattern}) unless @access_pattern == nil

    h.merge! ({:page => @pages})
    h.merge! ({:page_key => @page_keys})

    return h

  end


end