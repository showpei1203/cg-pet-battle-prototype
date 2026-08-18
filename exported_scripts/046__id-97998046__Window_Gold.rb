# RMVX_SCRIPT_INDEX: 46
# RMVX_SCRIPT_ID: 97998046
# RMVX_SCRIPT_NAME: Window_Gold
# RMVX_SOURCE_SHA256: de086426dde1bf4ecd93a4b4756980c0756f7e25caaf100f39f1a774f72eecdd

#==============================================================================
# ** Window_Gold
#------------------------------------------------------------------------------
#  This window displays the amount of gold.
#==============================================================================

class Window_Gold < Window_Base
  #--------------------------------------------------------------------------
  # * Object Initialization
  #     x : window X coordinate
  #     y : window Y coordinate
  #--------------------------------------------------------------------------
  def initialize(x, y)
    super(x, y, 160, WLH + 32)
    refresh
  end
  #--------------------------------------------------------------------------
  # * Refresh
  #--------------------------------------------------------------------------
  def refresh
    self.contents.clear
    draw_currency_value($game_party.gold, 4, 0, 120)
  end
end
