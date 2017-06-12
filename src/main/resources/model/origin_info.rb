class OriginInfo

  attr_accessor :place, :edition, :publisher, :date_issued_string, :date_captured_string #,  :issuance, :eventType
  attr_reader :date_issued_start, :date_issued_end, :date_captured_start, :date_captured_end

  def check_date(date)

    match = date.match(/(\d*)-(\d*)-(\d*)/)
    return match[1].to_i if match

    match = date.match(/\[(\d*)\]/)
    return match[1].to_i if match


    match = date.match(/(s.a.)/)
    return nil if match

    match = date.match(/(\[ca. )(\d*)\]/)
    return match[2].to_i if match


    match = date.match(/(\d*)(XX)/)
    if match
      value = match[1].to_i
      return {:start => value * 100, :end => value * 100 + 99}
    end

    match = date.match(/(\d\d)(\d*)\/(\d*)/)
    if match
      value1 = (match[1]+match[2]).to_i
      if match[3].size == 2
        value2 = (match[1]+match[3]).to_i
      else
        value2 = (match[3]).to_i
      end
      return {:start => value1, :end => value2}
    end


    return date.to_i

  end

  def date_issued_start=(date_issued_start)
    value = check_date(date_issued_start)
    if value.class == Hash
      @date_issued_start = value[:start]
      @date_issued_end   = value[:end]
    else
      @date_issued_start = value
    end
  end

  def date_issued_end=(date_issued_end)
    @date_issued_end = check_date(date_issued_end)
  end


  def date_captured_start=(date_captured_start)
    value = check_date(date_captured_start)
    if value.class == Hash
      @date_captured_start = value[:start]
      @date_captured_end   = value[:end]
    else
      @date_captured_start = value
    end
  end


  def date_captured_end=(date_captured_end)
    @date_captured_end = check_date(date_captured_end)
  end


  # todo not yet implemented
  PUBLISHER = Hash.new

  # todo not yet implemented
  PLACES    = {

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


  def placeFacet

    switch = PLACES[@place]
    if switch == nil
      return @place
    else
      return switch
    end
  end

  def publisherFacet

    switch = PUBLISHER[@plublisher]
    if switch == nil
      # todo better solution required
      return @publisher.gsub(/(Printed and sold by )|(Printed by )/, '')
    else
      return switch #.gsub(/(Printed and sold by )|(Printed by )/, '')
    end
  end


end

