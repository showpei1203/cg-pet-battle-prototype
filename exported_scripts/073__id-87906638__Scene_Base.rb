# RMVX_SCRIPT_INDEX: 73
# RMVX_SCRIPT_ID: 87906638
# RMVX_SCRIPT_NAME: Scene_Base
# RMVX_SOURCE_SHA256: e20a112766dfe422797b3ed7a039a7ef3892d73569085116db11e72e3cb5187e

#==============================================================================
# ** Scene_Base
#------------------------------------------------------------------------------
#  This is a superclass of all scenes in the game.
#==============================================================================

class Scene_Base
  #--------------------------------------------------------------------------
  # * Main Processing
  #--------------------------------------------------------------------------
  def main
    start                         # Start processing
    perform_transition            # Perform transition
    post_start                    # Post-start processing
    Input.update                  # Update input information
    loop do
      Graphics.update             # Update game screen
      Input.update                # Update input information
      update                      # Update frame
      break if $scene != self     # When screen is switched, interrupt loop
    end
    Graphics.update
    pre_terminate                 # Pre-termination processing
    Graphics.freeze               # Prepare transition
    terminate                     # Termination processing
  end
  #--------------------------------------------------------------------------
  # * Start processing
  #--------------------------------------------------------------------------
  def start
  end
  #--------------------------------------------------------------------------
  # * Execute Transition
  #--------------------------------------------------------------------------
  def perform_transition
    Graphics.transition(10)
  end
  #--------------------------------------------------------------------------
  # * Post-Start Processing
  #--------------------------------------------------------------------------
  def post_start
  end
  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
  def update
  end
  #--------------------------------------------------------------------------
  # * Pre-termination Processing
  #--------------------------------------------------------------------------
  def pre_terminate
  end
  #--------------------------------------------------------------------------
  # * Termination Processing
  #--------------------------------------------------------------------------
  def terminate
  end
  #--------------------------------------------------------------------------
  # * Create Snapshot for Using as Background of Another Screen
  #--------------------------------------------------------------------------
  def snapshot_for_background
    $game_temp.background_bitmap.dispose
    $game_temp.background_bitmap = Graphics.snap_to_bitmap
    $game_temp.background_bitmap.blur
  end
  #--------------------------------------------------------------------------
  # * Create Background for Menu Screen
  #--------------------------------------------------------------------------
  def create_menu_background
    @menuback_sprite = Sprite.new
    @menuback_sprite.bitmap = $game_temp.background_bitmap
    @menuback_sprite.color.set(16, 16, 16, 128)
    update_menu_background
  end
  #--------------------------------------------------------------------------
  # * Dispose of Background for Menu Screen
  #--------------------------------------------------------------------------
  def dispose_menu_background
    @menuback_sprite.dispose
  end
  #--------------------------------------------------------------------------
  # * Update Background for Menu Screen
  #--------------------------------------------------------------------------
  def update_menu_background
  end
end
