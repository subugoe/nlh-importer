class OriginInfo

  attr_accessor :place, :edition, :publisher, :date_issued, :date_captured_start, :date_captured_end #,  :issuance, :eventType

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


  SWITCHES = {

      '[Albany]'                            => 'Albany',


      'Boston'                              => 'Boston [N.E.]',
      '[Boston]'                            => 'Boston [N.E.]',
      'Boston?'                             => 'Boston [N.E.]',
      'Printed at Boston'                   => 'Boston [N.E.]',
      'Boston N.E.'                         => 'Boston [N.E.]',
      'Boston in N.E'                       => 'Boston [N.E.]',
      'Boston, in N.E'                      => 'Boston [N.E.]',
      'Boston in New-England'               => 'Boston [N.E.]',
      'Boston, New-England'                 => 'Boston [N.E.]',
      'Boston; New-England'                 => 'Boston [N.E.]',
      'Bostoniæ [Boston]'                   => 'Boston [N.E.]',
      'Boston New-England'                  => 'Boston [N.E.]',

      'Cambridge, Mass'                     => 'Cambridge [Mass.]',

      'Charleston [S.C.]'                   => 'Charlestown [S.C.]',
      'Charleston, S.C.'                    => 'Charlestown [S.C.]',
      'Charles-Town [S.C.]'                 => 'Charlestown [S.C.]',


      'Printed at Exeter [N.H.]'            => 'Exeter [N.H.]',
      'Exeter, N.H'                         => 'Exeter [N.H.]',
      '[Exeter, N.H.]'                      => 'Exeter [N.H.]',

      '[Hartford]'                          => 'Hartford',
      'Hartford?'                           => 'Hartford',

      'Lancaster, Pa'                       => 'Lancaster [Pa.]',
      'Lancäster [Pa.]'                     => 'Lancaster [Pa.]',

      'New Bern, N.C.'                      => 'New Bern [N.C.]',


      'Newbury-Port [Mass.]'                => 'Newburyport [Mass.]',
      '[Newburyport, Mass.]'                => 'Newburyport [Mass.]',
      '[Newburyport, Conn.]'                => 'Newburyport [Mass.]',
      'Printed at Newburyport [Mass.]'      => 'Newburyport [Mass.]',

      'New-Haven'                           => 'New Haven',
      '[New Haven]'                         => 'New Haven',
      'New Haven?'                          => 'New Haven',

      '[New-London, Conn.]'                 => 'New-London [Conn.]',
      'N. London [i.e., New London, Conn.]' => 'New-London [Conn.]',

      'Newport, R.I'                        => 'Newport [R.I.]',
      '[Newport, R.I.]'                     => 'Newport [R.I.]',
      'Newport, Rhode-Island'               => 'Newport [R.I.]',


      'New-York'                            => 'New York',
      'New-York?'                           => 'New York',


      '[Philadelphia]'                      => 'Philadelphia',
      'Philadelphia?'                       => 'Philadelphia',

      '[Portsmouth, N.H.]'                  => 'Portsmouth [N.H.]',
      'Portsmouth, N.H.'                    => 'Portsmouth [N.H.]',
      'Portsmouth, New-Hampshire'           => 'Portsmouth [N.H.]',


      '[Providence]'                        => 'Providence',
      'Providence?'                         => 'Providence',
      'Printed at Providence'               => 'Providence',


      '[Salem, Mass.]'                      => 'Salem [Mass.]',
      'Salem, Mass'                         => 'Salem [Mass.]',

      'Watertown, Mass'                     => 'Watertown [Mass.]',

      'Williamsburg, VA'                    => 'Williamsburg [VA.]',

      'Wilmington, Del.'                    => 'Wilmington [Del.]',
      '[Wilmington, Del.]'                  => 'Wilmington [Del.]',

      'Woodbridge, in New-Jersey'           => 'Woodbridge [N.J.]',

      'Printed at Worcester [Mass.]'        => 'Worcester [Mass.]',
      'Printed at Worcester, Massachusetts' => 'Worcester [Mass.]'


  }


  def placeFacete

    switch = SWITCHES[@place]
    if switch == nil
      return @place
    else
      return switch
    end
  end

end

