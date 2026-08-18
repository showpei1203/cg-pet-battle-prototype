# RMVX_SCRIPT_INDEX: 45
# RMVX_SCRIPT_ID: 77997554
# RMVX_SCRIPT_NAME: Window_Help
# RMVX_SOURCE_SHA256: 685d451798f6b9b6b3227803b8e60482d39f3d0314f6b368dfde2292feb82b0b

#==============================================================================
# ** Window_Help
#------------------------------------------------------------------------------
#  This window shows skill and item explanations along with actor status.
#==============================================================================

class Window_Help < Window_Base
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize
    super(0, 0, 544, WLH + 32)
  end
  #--------------------------------------------------------------------------
  # * Set Text
  #  text  : character string displayed in window
  #  align : alignment (0..flush left, 1..center, 2..flush right)
  #--------------------------------------------------------------------------
  def set_text(text, align = 0)
    if text != @text or align != @align
      self.contents.clear
      self.contents.font.color = normal_color
      self.contents.draw_text(4, 0, self.width - 40, WLH, text, align)
      @text = text
      @align = align
    end
  end
end
