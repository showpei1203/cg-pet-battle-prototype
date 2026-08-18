# RMVX_SCRIPT_INDEX: 19
# RMVX_SCRIPT_ID: 37972201
# RMVX_SCRIPT_NAME: Game_Actors
# RMVX_SOURCE_SHA256: ba12a7d3b955061aecc0df6825a1d1e63bbd64924b083ee7a08232f2241f0bb9

#==============================================================================
# ** Game_Actors
#------------------------------------------------------------------------------
#  This class handles the actor array. The instance of this class is
# referenced by $game_actors.
#==============================================================================

class Game_Actors
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize
    @data = []
  end
  #--------------------------------------------------------------------------
  # * Get Actor
  #     actor_id : actor ID
  #--------------------------------------------------------------------------
  def [](actor_id)
    if @data[actor_id] == nil and $data_actors[actor_id] != nil
      @data[actor_id] = Game_Actor.new(actor_id)
    end
    return @data[actor_id]
  end
end
