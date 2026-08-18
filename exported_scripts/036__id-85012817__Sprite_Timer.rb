# RMVX_SCRIPT_INDEX: 36
# RMVX_SCRIPT_ID: 85012817
# RMVX_SCRIPT_NAME: Sprite_Timer
# RMVX_SOURCE_SHA256: 0ae6251d91ed3646ef1bf54dc87a0b822454081b943ba93ffbfbfc11fab6d8dc

#==============================================================================
# ** Sprite_Timer
#------------------------------------------------------------------------------
#  This sprite is used to display the timer. It observes the $game_system
# and automatically changes sprite conditions.
#==============================================================================

class Sprite_Timer < Sprite
  #--------------------------------------------------------------------------
  # * Object Initialization
  #     viewport : viewport
  #--------------------------------------------------------------------------
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(88, 48)
    self.bitmap.font.name = "Arial"
    self.bitmap.font.size = 32
    self.x = 544 - self.bitmap.width
    self.y = 0
    self.z = 200
    update
  end
  #--------------------------------------------------------------------------
  # * Dispose
  #--------------------------------------------------------------------------
  def dispose
    self.bitmap.dispose
    super
  end
  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
  def update
    super
    self.visible = $game_system.timer_working
    if $game_system.timer / Graphics.frame_rate != @total_sec
      self.bitmap.clear
      @total_sec = $game_system.timer / Graphics.frame_rate
      min = @total_sec / 60
      sec = @total_sec % 60
      text = sprintf("%02d:%02d", min, sec)
      self.bitmap.font.color.set(255, 255, 255)
      self.bitmap.draw_text(self.bitmap.rect, text, 1)
    end
  end
end
