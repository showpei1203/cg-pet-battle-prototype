# RMVX_SCRIPT_INDEX: 87
# RMVX_SCRIPT_ID: 19266
# RMVX_SCRIPT_NAME: Scene_Gameover
# RMVX_SOURCE_SHA256: cd0add9ece27796195c348e8a544346d8cdf3f8bae41807a08c1896b20226c48

#==============================================================================
# ** Scene_Gameover
#------------------------------------------------------------------------------
#  This class performs game over screen processing.
#==============================================================================

class Scene_Gameover < Scene_Base
  #--------------------------------------------------------------------------
  # * Start processing
  #--------------------------------------------------------------------------
  def start
    super
    RPG::BGM.stop
    RPG::BGS.stop
    $data_system.gameover_me.play
    Graphics.transition(120)
    Graphics.freeze
    create_gameover_graphic
  end
  #--------------------------------------------------------------------------
  # * Termination Processing
  #--------------------------------------------------------------------------
  def terminate
    super
    dispose_gameover_graphic
    $scene = nil if $BTEST
  end
  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
  def update
    super
    if Input.trigger?(Input::C)
      $scene = Scene_Title.new
      Graphics.fadeout(120)
    end
  end
  #--------------------------------------------------------------------------
  # * Execute Transition
  #--------------------------------------------------------------------------
  def perform_transition
    Graphics.transition(180)
  end
  #--------------------------------------------------------------------------
  # * Create Game Over Graphic
  #--------------------------------------------------------------------------
  def create_gameover_graphic
    @sprite = Sprite.new
    @sprite.bitmap = Cache.system("GameOver")
  end
  #--------------------------------------------------------------------------
  # * Dispose of Game Over Graphic
  #--------------------------------------------------------------------------
  def dispose_gameover_graphic
    @sprite.bitmap.dispose
    @sprite.dispose
  end
end
