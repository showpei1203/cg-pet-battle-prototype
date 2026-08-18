# RMVX_SCRIPT_INDEX: 67
# RMVX_SCRIPT_ID: 72766194
# RMVX_SCRIPT_NAME: Window_TargetEnemy
# RMVX_SOURCE_SHA256: c2154ede36ead7a1f7bb15c204902ec4193089ede010a355cb24c879228a6b3f

#==============================================================================
# ** Window_TargetEnemy
#------------------------------------------------------------------------------
#  Window for selecting the enemy who is the action target on the battle
# screen.
#==============================================================================

class Window_TargetEnemy < Window_Command
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize
    commands = []
    @enemies = []
    for enemy in $game_troop.members
      next unless enemy.exist?
      commands.push(enemy.name)
      @enemies.push(enemy)
    end
    super(416, commands, 2, 4)
  end
  #--------------------------------------------------------------------------
  # * Get Enemy Object
  #--------------------------------------------------------------------------
  def enemy
    return @enemies[@index]
  end
end
