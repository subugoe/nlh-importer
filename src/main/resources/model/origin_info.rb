require 'logger'
require 'gelf'

class OriginInfo

  attr_accessor :places, :publishers, :edition, :date_issued_string, :date_issued_start, :date_issued_end, :date_captured_string, :date_captured_start, :date_captured_end #,  :issuance, :eventType


  def initialize
    @logger       = GELF::Logger.new(ENV['GRAYLOG_URI'], ENV['GRAYLOG_PORT'].to_i, "WAN", {:facility => ENV['GRAYLOG_FACILITY']})
    @logger.level = ENV['DEBUG_MODE'].to_i
    @places       = Array.new
    @publishers   = Array.new
  end


  def check_date(date, id)

    match = date.match(/(\d*)-(\d*)-(\d*)/)
    if match
      @logger.warn("[origin_info.rb] [GDZ-580] Year mapping (2) for #{id}")
      return match[1].to_i
    end

    match = date.match(/(\d*)\.(\d*)\.(\d\d\d\d)/)
    if match
      @logger.warn("[origin_info.rb] [GDZ-580] Year mapping (10) for #{id}")
      return match[3].to_i
    end

    match = date.match(/\[(\d*)\]/)
    if match
      @logger.warn("[origin_info.rb] [GDZ-580] Year mapping (1) for #{id}")
      return match[1].to_i
    end


    match = date.match(/(s.a.)/)
    if match
      @logger.warn("[origin_info.rb] [GDZ-580] Year mapping (3) for #{id}")
      return nil
    end

    match = date.match(/(\[ca. )(\d*)\]/)
    if match
      @logger.warn("[origin_info.rb] [GDZ-580] Year mapping (4) for #{id}")
      return match[2].to_i
    end

    match = date.match(/([\S]*) (\d\d\d\d)/)
    if match
      @logger.warn("[origin_info.rb] [GDZ-580] Year mapping (9) for #{id}")
      return match[2].to_i
    end

    match = date.match(/(\d*)(XX)/)
    if match
      @logger.warn("[origin_info.rb] [GDZ-580] Year mapping (5) for #{id}")
      value = match[1].to_i
      return {:start => value * 100, :end => value * 100 + 99}
    end

    match = date.match(/(\d\d)(\d*)\/(\d*)/)
    if match
      @logger.warn("[origin_info.rb] [GDZ-580] Year mapping (6) for #{id}")
      value1 = (match[1]+match[2]).to_i
      if match[3].size == 2
        value2 = (match[1]+match[3]).to_i
      else
        value2 = (match[3]).to_i
      end
      return {:start => value1, :end => value2}
    end


    if date.downcase.start_with? 'ppn'
      @logger.warn("[origin_info.rb] [GDZ-580] Year mapping (8) for #{id}")
      return nil
    end

    match = date.match(/(\d\d\d\d)(\d\d\d\d)/)
    if match
      @logger.warn("[origin_info.rb] [GDZ-580] Year mapping (7) for #{id}")
      return {:start => (match[1]).to_i, :end => (match[2]).to_i, :str => "#{match[1]}/#{match[2]}"}
    end


    return date.to_i

  end

  def check_and_add_date_issued_start(date_issued_start, id)
    value = check_date(date_issued_start, id)
    if value.class == Hash
      @date_issued_start  = value[:start]
      @date_issued_end    = value[:end]
      @date_issued_string = value[:str] if value[:str]
    else
      @date_issued_start = value
    end
  end

  def check_and_add_date_issued_end(date_issued_end, id)
    @date_issued_end = check_date(date_issued_end, id)
  end


  def check_and_add_date_captured_start(date_captured_start, id)
    value = check_date(date_captured_start, id)
    if value.class == Hash
      @date_captured_start  = value[:start]
      @date_captured_end    = value[:end]
      @date_captured_string = value[:str] if value[:str]
    else
      @date_captured_start = value
    end
  end


  def check_and_add_date_captured_end(date_captured_end, id)
    @date_captured_end = check_date(date_captured_end, id)
  end


  PUBLISHER = Hash.new

  PLACES = {

      '[Albany]'                            => 'Albany',

      '[Baltimore]'                         => 'Baltimore',

      'Boston'                              => 'Boston [N.E.]',
      '[Boston]'                            => 'Boston [N.E.]',
      'Boston?'                             => 'Boston [N.E.]',
      'Printed at Boston'                   => 'Boston [N.E.]',
      'Boston N.E.'                         => 'Boston [N.E.]',
      'Boston N.E'                          => 'Boston [N.E.]',
      'Boston, N.E'                         => 'Boston [N.E.]',
      'Boston in N.E'                       => 'Boston [N.E.]',
      'Boston, in N.E'                      => 'Boston [N.E.]',
      'Boston in New-England'               => 'Boston [N.E.]',
      'Boston, in New-England'              => 'Boston [N.E.]',
      'Boston, New-England'                 => 'Boston [N.E.]',
      'Boston; New-England'                 => 'Boston [N.E.]',
      'Bostoniæ [Boston]'                   => 'Boston [N.E.]',
      'Boston New-England'                  => 'Boston [N.E.]',

      'Cambridge, Mass'                     => 'Cambridge [Mass.]',

      'Charleston [S.C.]'                   => 'Charlestown [S.C.]',
      'Charleston, S.C.'                    => 'Charlestown [S.C.]',
      'Charleston, S.C'                     => 'Charlestown [S.C.]',
      '[Charleston, S.C.]'                  => 'Charlestown [S.C.]',
      'Charles-Town [S.C.]'                 => 'Charlestown [S.C.]',
      'South-Carolina. Charles-Town'        => 'Charlestown [S.C.]',


      'Printed at Exeter [N.H.]'            => 'Exeter [N.H.]',
      'Exeter, N.H'                         => 'Exeter [N.H.]',
      '[Exeter, N.H.]'                      => 'Exeter [N.H.]',

      'Germantown, Pa'                      => 'Germantown [Pa.]',
      'Germantown [Pa.]'                    => 'Germantown [Pa.]',

      '[Hartford]'                          => 'Hartford',
      'Hartford?'                           => 'Hartford',

      'Lancaster, Pa'                       => 'Lancaster [Pa.]',
      'Lancaster [Pa.]'                     => 'Lancaster [Pa.]',
      'Lancäster [Pa.]'                     => 'Lancaster [Pa.]',

      'Lexington, Ky'                       => 'Lexington [Ky]',

      'New Bern, N.C.'                      => 'New Bern [N.C.]',


      'Newbury-Port [Mass.]'                => 'Newburyport [Mass.]',
      'Newburyport, Mass'                   => 'Newburyport [Mass.]',
      '[Newburyport, Mass.]'                => 'Newburyport [Mass.]',
      '[Newburyport, Conn.]'                => 'Newburyport [Mass.]',
      'Printed at Newburyport [Mass.]'      => 'Newburyport [Mass.]',

      'New-Haven'                           => 'New Haven',
      '[New Haven]'                         => 'New Haven',
      'New Haven?'                          => 'New Haven',

      'New London, Conn'                    => 'New-London [Conn.]',
      '[New-London, Conn.]'                 => 'New-London [Conn.]',
      '[New London, Conn.]'                 => 'New-London [Conn.]',
      'N. London [i.e., New London, Conn.]' => 'New-London [Conn.]',

      'Newport, R.I'                        => 'Newport [R.I.]',
      '[Newport, R.I.]'                     => 'Newport [R.I.]',
      'Newport, Rhode-Island'               => 'Newport [R.I.]',


      'New-York'                            => 'New York',
      'New York?'                           => 'New York',
      '(New-York'                           => 'New York',
      'New-York?'                           => 'New York',
      '[New York]'                          => 'New York',

      '[Norwich, Conn.]'                    => 'Norwich [Conn.]',

      'Pennsylvania?'                       => 'Pennsylvania',

      '[Philadelphia]'                      => 'Philadelphia',
      'Philadelphia?'                       => 'Philadelphia',

      '[Portsmouth, N.H.]'                  => 'Portsmouth [N.H.]',
      'Portsmouth, N.H.'                    => 'Portsmouth [N.H.]',
      'Portsmouth, N.H'                     => 'Portsmouth [N.H.]',
      'Portsmouth, New-Hampshire'           => 'Portsmouth [N.H.]',
      'Portsmouth New-Hampshire'            => 'Portsmouth [N.H.]',

      'Printed at Portland [Me.]'           => 'Portland [Me.]',


      '[Providence]'                        => 'Providence',
      'Providence?'                         => 'Providence',
      'Printed at Providence'               => 'Providence',


      '[Salem, Mass.]'                      => 'Salem [Mass.]',
      'Salem, Mass'                         => 'Salem [Mass.]',

      'Warren (Rhode-Island)'               => 'Warren [R.I.]',

      'Watertown, Mass'                     => 'Watertown [Mass.]',

      'Williamsburg, VA'                    => 'Williamsburg [VA.]',

      'Wilmington, Del.'                    => 'Wilmington [Del.]',
      '[Wilmington, Del.]'                  => 'Wilmington [Del.]',

      'Woodbridge, in New-Jersey'           => 'Woodbridge [N.J.]',

      'Printed at Worcester [Mass.]'        => 'Worcester [Mass.]',
      '[Worcester, Mass.]'                  => 'Worcester [Mass.]',
      'Printed at Worcester, Massachusetts' => 'Worcester [Mass.]',
      'Worcester, (Massachusetts)'          => 'Worcester [Mass.]'

  }


  def places_to_s
    unless @places.empty?
      @places.join '; '
    else
      return nil
    end
  end

  def publishers_to_s
    unless @publishers.empty?
      return @publishers.join '; '
    else
      return nil
    end
  end

  def placesFacet_to_s

    arr = Array.new
    @places.each {|el|
      switch = PLACES[el]
      if switch == nil
        arr << el
      else
        arr << switch
      end
    }

    unless arr.empty?
      return arr
    else
      return nil
    end
  end


  def publishersFacet_to_s

    arr = Array.new
    @publishers.each {|el|
      switch = PUBLISHER[el]
      if switch == nil
        arr << el.gsub(/(Printed and sold by )|(Printed by )/, '')
      else
        arr << switch.gsub(/(Printed and sold by )|(Printed by )/, '')
      end
    }

    unless arr.empty?
      return arr
    else
      return nil
    end

  end


end

