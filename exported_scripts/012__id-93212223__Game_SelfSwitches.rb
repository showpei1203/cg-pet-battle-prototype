# RMVX_SCRIPT_INDEX: 12
# RMVX_SCRIPT_ID: 93212223
# RMVX_SCRIPT_NAME: Game_SelfSwitches
# RMVX_SOURCE_SHA256: 85e8db5069f9d62dd1f9b8bb8c801b4fca3f43a221b23f12175b6ef22cf5357e

#==============================================================================
# ** Game_SelfSwitches
#------------------------------------------------------------------------------
#  This class handles self switches. It's a wrapper for the built-in class
# "Hash." The instance of this class is referenced by $game_self_switches.
#==============================================================================

class Game_SelfSwitches
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize
    @data = {}
  end
  #--------------------------------------------------------------------------
  # * Get Self Switch 
  #     key : key
  #--------------------------------------------------------------------------
  def [](key)
    return @data[key] == true ? true : false
  end
  #--------------------------------------------------------------------------
  # * Set Self Switch
  #     key   : key
  #     value : ON (true) / OFF (false)
  #--------------------------------------------------------------------------
  def []=(key, value)
    @data[key] = value
  end
end
