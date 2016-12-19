class OriginInfo

  attr_accessor :place, :edition, :publisher, :date_issued_start, :date_issued_end, :date_captured_start, :date_captured_end #,  :issuance, :eventType

  # def initialize
  #   @publisher  = Array.new
  #   @placeTerm  = Array.new
  #   @dateIssues = Array.new
  #
  # end
  #
  # def addPlaceTerm(placeTerm)
  #   @place << placeTerm
  # end
  #
  # def addPublisher=(publisher)
  #   @publisher << publisher
  # end
  #
  # def addDateIssued(date)
  #   @dateIssued << date
  # end
  #
  # def addDateCaptured(date)
  #   @dateCaptured << date
  # end


  # todo not yet implemented
  PUBLISHER = Hash.new

  # todo not yet implemented
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

