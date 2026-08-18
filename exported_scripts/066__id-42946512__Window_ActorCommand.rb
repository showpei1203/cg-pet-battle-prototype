# RMVX_SCRIPT_INDEX: 66
# RMVX_SCRIPT_ID: 42946512
# RMVX_SCRIPT_NAME: Window_ActorCommand
# RMVX_SOURCE_SHA256: 7f077940857d1a1b68478a247a85cb01fc03a9edc4c8f58f54e70d534537b2f7

#==============================================================================
# ** Window_ActorCommand
#------------------------------------------------------------------------------
#  This window is used to select actor commands, such as "Attack" or "Skill".
#==============================================================================

class Window_ActorCommand < Window_Command
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize
    super(128, [], 1, 4)
    self.active = false
  end
  #--------------------------------------------------------------------------
  # * Setup
  #     actor : actor
  #--------------------------------------------------------------------------
  def setup(actor)
    s1 = Vocab::attack
    s2 = Vocab::skill
    s3 = Vocab::guard
    s4 = Vocab::item
    if actor.class.skill_name_valid     # Skill command name is valid?
      s2 = actor.class.skill_name       # Replace command name
    end
    @commands = [s1, s2, s3, s4]
    @item_max = 4
    refresh
    self.index = 0
  end
end
