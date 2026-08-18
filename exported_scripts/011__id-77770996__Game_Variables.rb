# RMVX_SCRIPT_INDEX: 11
# RMVX_SCRIPT_ID: 77770996
# RMVX_SCRIPT_NAME: Game_Variables
# RMVX_SOURCE_SHA256: 39475d4d63170f98ee595e0e4e10f4faef8660bb50e4f177398acb220829e154

#==============================================================================
# ** Game_Variables
#------------------------------------------------------------------------------
#  This class handles variables. It's a wrapper for the built-in class "Array."
# The instance of this class is referenced by $game_variables.
#==============================================================================

class Game_Variables
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize
    @data = []
  end
  #--------------------------------------------------------------------------
  # * Get Variable
  #     variable_id : variable ID
  #--------------------------------------------------------------------------
  def [](variable_id)
    if @data[variable_id] == nil
      return 0
    else
      return @data[variable_id]
    end
  end
  #--------------------------------------------------------------------------
  # * Set Variable
  #     variable_id : variable ID
  #     value       : the variable's value
  #--------------------------------------------------------------------------
  def []=(variable_id, value)
    if variable_id <= 5000
      @data[variable_id] = value
    end
  end
end
