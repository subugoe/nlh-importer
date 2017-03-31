require 'json'

class ImageResource
  include Mongoid::Document

  Mongoid.load!("path/to/your/mongoid.yml", :production)

  attr_accessor :id, :size, :path, :url, :resolution, :units, :geometry


  field :_id, type: String, default: -> { id }

  field :id, type: String
  field :size, type: Integer
  field :path, type: String
  field :url, type: String
  field :resolution, type: String
  field :units, type: String
  field :geometry, type: String


  def to_json
    {"id"         => self.id,
     "size"       => self.size,
     "path"       => self.path,
     "url"        => self.url,
     "resolution" => self.resolution, # e.g. 200x200
     "units"      => self.units, # e.g. PixelsPerInch
     "geometry"   => self.geometry # e.g. 2432x2992+0+0
    }.to_json
  end


end
