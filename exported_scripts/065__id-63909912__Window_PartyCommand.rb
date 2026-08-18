# RMVX_SCRIPT_INDEX: 65
# RMVX_SCRIPT_ID: 63909912
# RMVX_SCRIPT_NAME: Window_PartyCommand
# RMVX_SOURCE_SHA256: 49a95c048eab22ef9f1f39750bc64782de0ea73242e47a139b1f7698db3cd8b5

#==============================================================================
# ** Window_PartyCommand
#------------------------------------------------------------------------------
#  This window is used to select whether to fight or escape on the battle
# screen.
#==============================================================================

class Window_PartyCommand < Window_Command
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize
    s1 = Vocab::fight
    s2 = Vocab::escape
    super(128, [s1, s2], 1, 4)
    draw_item(0, true)
    draw_item(1, $game_troop.can_escape)
    self.active = false
  end
end
