# RMVX_SCRIPT_INDEX: 10
# RMVX_SCRIPT_ID: 65768432
# RMVX_SCRIPT_NAME: Game_Switches
# RMVX_SOURCE_SHA256: 61bec22f73cfc209215d5b55ee910cb53894eb14f351fa601245ff10c463b555

#==============================================================================
# ** Game_Switches
#------------------------------------------------------------------------------
#  This class handles switches. It's a wrapper for the built-in class "Array."
# The instance of this class is referenced by $game_switches.
#==============================================================================

class Game_Switches
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize
    @data = []
  end
  #--------------------------------------------------------------------------
  # * Get Switch
  #     switch_id : switch ID
  #--------------------------------------------------------------------------
  def [](switch_id)
    if @data[switch_id] == nil
      return false
    else
      return @data[switch_id]
    end
  end
  #--------------------------------------------------------------------------
  # * Set Switch
  #     switch_id : switch ID
  #     value     : ON (true) / OFF (false)
  #--------------------------------------------------------------------------
  def []=(switch_id, value)
    if switch_id <= 5000
      @data[switch_id] = value
    end
  end
end
