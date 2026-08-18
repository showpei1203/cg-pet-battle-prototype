# RMVX_SCRIPT_INDEX: 122
# RMVX_SCRIPT_ID: 98941041
# RMVX_SCRIPT_NAME: CG Dual Command Core v0.4.2
# RMVX_SOURCE_SHA256: 1f7f8ba392df9e1183e2719bc43b53040c6518f5b18cb13c79285337fadd956d

#==============================================================================
# 【繁體中文說明】ALBERT CG 人物／寵物雙指令核心
#------------------------------------------------------------------------------
# 【用途】每名人物與自己的寵物各輸入一次；主角使用 Clone 寵物，隊友可使用固定普通 Actor 寵物。
#  無寵物或寵物戰鬥不能時，該人物取得兩個行動。
# 【使用】兩個行動分別加入全體排序，但同一人物的第二動不得超越第一動；狀態回合只結算一次。
# 【位置】請放在 CG Config 下方，並依專案腳本索引指定順序排列。
#==============================================================================

#==============================================================================
# ** ALBERT CG Dual Command Core
#------------------------------------------------------------------------------
#  Version : 0.4.2
#  Engine  : RPG Maker VX / RGSS2
#  Requires: Tankentai SBS 3.3 + ALBERT CG Pet Clone Core
#------------------------------------------------------------------------------
#  Round command rules used by this prototype:
#    1. A living human and a living deployed pet each receive one command.
#    2. If no pet is deployed, or the deployed pet is dead, the lead human
#       receives two independent commands.
#    3. If a living pet is unable to act because of a state, the human does
#       not gain a bonus command merely because the pet is disabled.
#    4. Both commands are sorted independently by final action speed.
#    5. MP, item inventory, user state and targets are checked again when the
#       action actually executes.
#    6. State duration is processed once per battler per round, not once per
#       queued action.
#
#  Pet actor commands:
#    Attack / Skill / Guard / Wait
#
#  Battlefield positioning and legal melee targets are supplied by
#  ALBERT CG Battlefield Grid v0.4.
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_DualCommand"] = true

module ALBERT_CG
  class CommandSlot
    attr_accessor :battler
    attr_accessor :ordinal
    attr_accessor :label
    attr_accessor :manual
    attr_accessor :action

    def initialize(battler, ordinal, label, manual = true)
      @battler = battler
      @ordinal = ordinal
      @label = label
      @manual = manual
      @action = nil
    end
  end

  class ActionEntry
    attr_accessor :battler
    attr_accessor :action
    attr_accessor :sequence

    def initialize(battler, action, sequence)
      @battler = battler
      @action = action
      @sequence = sequence
    end
  end
end

class Game_BattleAction
  def cg_copy_for(new_battler = nil)
    battler = new_battler == nil ? @battler : new_battler
    copy = Game_BattleAction.new(battler)
    copy.speed = @speed
    copy.kind = @kind
    copy.basic = @basic
    copy.skill_id = @skill_id
    copy.item_id = @item_id
    copy.target_index = @target_index
    copy.forcing = @forcing
    copy.value = @value
    return copy
  end
end

class Game_Battler
  def cg_assign_action(action)
    @action = action == nil ? Game_BattleAction.new(self) : action
    @action.battler = self
    return @action
  end

  def cg_round_actions
    @cg_round_actions = [] if @cg_round_actions == nil
    return @cg_round_actions
  end

  def cg_round_actions=(actions)
    @cg_round_actions = actions == nil ? [] : actions
  end

  def cg_clear_round_actions
    @cg_round_actions = []
  end
end

class Window_ActorCommand < Window_Command
  alias albert_cg_v03_actor_command_setup setup
  def setup(actor)
    albert_cg_v03_actor_command_setup(actor)
    if actor != nil && actor.respond_to?(:cg_battle_pet?) && actor.cg_battle_pet?
      @commands[3] = "待命"
      refresh
      self.index = 0
    end
  end
end

class Window_CG_CommandPhase < Window_Base
  def initialize
    super(304, 0, 240, 56)
    self.z = 300
    self.visible = false
  end

  def set_slot(slot)
    self.contents.clear
    if slot == nil or slot.battler == nil
      self.visible = false
      return
    end
    text = slot.label.to_s + "：" + slot.battler.name.to_s
    self.contents.draw_text(0, 0, contents.width, WLH, text, 1)
    self.visible = true
  end
end

class Scene_Battle < Scene_Base
  alias albert_cg_v03_scene_start start
  def start
    albert_cg_v03_scene_start
    @cg_phase_window = Window_CG_CommandPhase.new
    cg_reset_round_command_data
  end

  alias albert_cg_v03_scene_terminate terminate
  def terminate
    if @cg_phase_window != nil
      @cg_phase_window.dispose unless @cg_phase_window.disposed?
      @cg_phase_window = nil
    end
    albert_cg_v03_scene_terminate
  end

  alias albert_cg_v03_start_party_command_selection start_party_command_selection
  def start_party_command_selection
    cg_reset_round_command_data
    cg_hide_phase_window
    albert_cg_v03_start_party_command_selection
  end

  def cg_reset_round_command_data
    @cg_input_slots = nil
    @cg_input_slot_index = -1
    @cg_state_processed = {}
    if $game_party != nil
      for member in $game_party.members
        member.cg_clear_round_actions if member.respond_to?(:cg_clear_round_actions)
      end
    end
  end

  def cg_hide_phase_window
    @cg_phase_window.visible = false if @cg_phase_window != nil
  end

  def cg_current_command_slot
    return nil if @cg_input_slots == nil
    return nil if @cg_input_slot_index == nil
    return nil if @cg_input_slot_index < 0
    return nil if @cg_input_slot_index >= @cg_input_slots.size
    return @cg_input_slots[@cg_input_slot_index]
  end

  def cg_make_auto_slot(battler, ordinal, label)
    slot = ALBERT_CG::CommandSlot.new(battler, ordinal, label, false)
    battler.make_action
    slot.action = battler.action.cg_copy_for(battler)
    return slot
  end

  def cg_make_slot(battler, ordinal, label)
    if battler.auto_battle
      return cg_make_auto_slot(battler, ordinal, label)
    end
    return ALBERT_CG::CommandSlot.new(battler, ordinal, label, true)
  end

  def cg_build_input_slots
    @cg_input_slots = []
    @cg_input_slot_index = -1
    humans = $game_party.respond_to?(:cg_human_members) ?
      $game_party.cg_human_members : $game_party.members

    # 依人物逐組建立指令：人物 → 該人物自己的寵物。
    # 若自己的寵物不存在或戰鬥不能，該人物取得第二動。
    for human in humans
      next unless human.exist?
      human_can_input = human.inputable? or human.auto_battle
      first_slot = nil
      if human_can_input
        first_slot = cg_make_slot(human, 1, "人物行動")
        @cg_input_slots.push(first_slot)
      end

      pet = if $game_party.respond_to?(:cg_active_pet_for)
        $game_party.cg_active_pet_for(human)
      else
        $game_party.respond_to?(:cg_active_pet) ? $game_party.cg_active_pet : nil
      end
      pet_in_party = pet != nil && $game_party.members.include?(pet)
      living_pet = pet_in_party && pet.exist?

      if living_pet
        if pet.inputable? or pet.auto_battle
          @cg_input_slots.push(cg_make_slot(pet, 1, "寵物行動"))
        end
      elsif human_can_input
        first_slot.label = "人物行動 1" if first_slot != nil
        @cg_input_slots.push(cg_make_slot(human, 2, "人物行動 2"))
      end
    end
    return @cg_input_slots
  end

  def cg_store_current_slot_action
    slot = cg_current_command_slot
    return if slot == nil
    return unless slot.manual
    return if @active_battler == nil
    slot.action = @active_battler.action.cg_copy_for(slot.battler)
  end

  def cg_clear_slots_after(index)
    return if @cg_input_slots == nil
    for i in index...@cg_input_slots.size
      slot = @cg_input_slots[i]
      slot.action = nil if slot.manual
    end
  end

  def cg_finalize_round_actions
    grouped = {}
    for member in $game_party.members
      grouped[member.object_id] = []
      member.cg_clear_round_actions
    end
    for slot in @cg_input_slots
      next if slot == nil or slot.action == nil
      key = slot.battler.object_id
      grouped[key] = [] if grouped[key] == nil
      grouped[key].push(slot.action.cg_copy_for(slot.battler))
    end
    for member in $game_party.members
      member.cg_round_actions = grouped[member.object_id] || []
    end
  end

  def cg_play_command_pose(battler, entering)
    return if battler == nil
    return unless battler.actor?
    return unless battler.inputable?
    return if @spriteset == nil
    action_name = entering ? battler.command_b : battler.command_a
    @spriteset.set_action(true, battler.index, action_name)
  end

  def cg_activate_command_slot(slot)
    @active_battler = slot.battler
    @actor_index = $game_party.members.index(@active_battler)
    @status_window.index = @actor_index
    action = slot.action == nil ? Game_BattleAction.new(@active_battler) :
      slot.action.cg_copy_for(@active_battler)
    @active_battler.cg_assign_action(action)
    start_actor_command_selection
    @cg_phase_window.set_slot(slot) if @cg_phase_window != nil
    cg_play_command_pose(@active_battler, true)
  end

  # Replaces the default member-index traversal with command-slot traversal.
  def next_actor
    cg_build_input_slots if @cg_input_slots == nil
    if cg_current_command_slot != nil
      cg_store_current_slot_action
      cg_play_command_pose(@active_battler, false)
    end
    loop do
      @cg_input_slot_index += 1
      if @cg_input_slot_index >= @cg_input_slots.size
        cg_finalize_round_actions
        cg_hide_phase_window
        @wait_count = 32
        start_main
        return
      end
      slot = @cg_input_slots[@cg_input_slot_index]
      next unless slot.manual
      cg_activate_command_slot(slot)
      return
    end
  end

  # Replaces the default actor traversal so B can return from action 2 to 1.
  def prior_actor
    slot = cg_current_command_slot
    if slot != nil
      slot.action = nil if slot.manual
      @active_battler.action.clear if @active_battler != nil
      cg_play_command_pose(@active_battler, false)
      cg_clear_slots_after(@cg_input_slot_index)
    end
    index = @cg_input_slot_index - 1
    while index >= 0
      previous = @cg_input_slots[index]
      if previous.manual
        @cg_input_slot_index = index
        cg_activate_command_slot(previous)
        return
      end
      index -= 1
    end
    start_party_command_selection
  end

  alias albert_cg_v03_start_actor_command_selection start_actor_command_selection
  def start_actor_command_selection
    albert_cg_v03_start_actor_command_selection
    slot = cg_current_command_slot
    @cg_phase_window.set_slot(slot) if @cg_phase_window != nil && slot != nil
  end

  alias albert_cg_v03_update_actor_command_selection update_actor_command_selection
  def update_actor_command_selection
    if Input.trigger?(Input::C) && @active_battler != nil &&
       @active_battler.respond_to?(:cg_battle_pet?) && @active_battler.cg_battle_pet? &&
       @actor_command_window.index == 3
      Sound.play_decision
      @active_battler.action.kind = 0
      @active_battler.action.basic = 3
      next_actor
      return
    end
    albert_cg_v03_update_actor_command_selection
  end

  alias albert_cg_v03_start_skill_selection start_skill_selection
  def start_skill_selection
    cg_hide_phase_window
    albert_cg_v03_start_skill_selection
  end

  alias albert_cg_v03_end_skill_selection end_skill_selection
  def end_skill_selection
    albert_cg_v03_end_skill_selection
    slot = cg_current_command_slot
    if @actor_command_window.active && slot != nil && @cg_phase_window != nil
      @cg_phase_window.set_slot(slot)
    end
  end

  alias albert_cg_v03_start_item_selection start_item_selection
  def start_item_selection
    cg_hide_phase_window
    albert_cg_v03_start_item_selection
  end

  alias albert_cg_v03_end_item_selection end_item_selection
  def end_item_selection
    albert_cg_v03_end_item_selection
    slot = cg_current_command_slot
    if @actor_command_window.active && slot != nil && @cg_phase_window != nil
      @cg_phase_window.set_slot(slot)
    end
  end

  # Tankentai 3.3 uses this common cursor method for actor/enemy targets.
  alias albert_cg_v03_start_target_selection start_target_selection
  def start_target_selection(actor = false)
    cg_hide_phase_window
    albert_cg_v03_start_target_selection(actor)
  end

  alias albert_cg_v03_end_target_selection end_target_selection
  def end_target_selection
    albert_cg_v03_end_target_selection
    slot = cg_current_command_slot
    if @actor_command_window.active && slot != nil && @cg_phase_window != nil
      @cg_phase_window.set_slot(slot)
    end
  end

  def cg_add_order_entry(entries, battler, action, sequence, speed_rate = 100)
    action = action.cg_copy_for(battler)
    action.make_speed
    action.speed = action.speed * speed_rate / 100
    entry = ALBERT_CG::ActionEntry.new(battler, action, sequence)
    entries.push(entry)
    return entry
  end

  def cg_enemy_order_entries(entries, enemy, sequence)
    data = enemy.respond_to?(:action_time) ? enemy.action_time : [1, 100, 100]
    maximum = [data[0].to_i, 1].max
    probability = [[data[1].to_i, 0].max, 100].min
    rapidity = [data[2].to_i, 1].max
    count = 1
    for i in 1...maximum
      count += 1 if rand(100) < probability
    end
    speed_rate = 100
    for i in 0...count
      enemy.make_action if i > 0
      cg_add_order_entry(entries, enemy, enemy.action, sequence, speed_rate)
      sequence += 1
      speed_rate = speed_rate * rapidity / 100
    end
    enemy.act_time = 0 if enemy.respond_to?(:act_time=)
    enemy.adj_speed = nil if enemy.respond_to?(:adj_speed=)
    return sequence
  end

  # Fully replaces Tankentai's action-order array so one battler may safely
  # appear more than once with a different Game_BattleAction each time.
  def make_action_orders
    entries = []
    sequence = 0
    unless $game_troop.surprise
      for battler in $game_party.members
        actions = battler.cg_round_actions
        if actions.empty?
          if battler.auto_battle && battler.exist? && battler.movable?
            battler.make_action
            actions = [battler.action.cg_copy_for(battler)]
          else
            # Keep one empty action so confusion, berserk and state-duration
            # processing still receive one round opportunity.
            actions = [Game_BattleAction.new(battler)]
          end
        end
        previous_speed = nil
        for action in actions
          entry = cg_add_order_entry(entries, battler, action, sequence)
          # 同一人物的第二動可以被敵人插入，但不能反過來超越第一動。
          # 若第二動原始速度更快，壓到與第一動相同；同速時 sequence 會維持輸入順序。
          if previous_speed != nil && entry.action.speed > previous_speed
            entry.action.speed = previous_speed
          end
          previous_speed = entry.action.speed
          sequence += 1
        end
      end
    end
    unless $game_troop.preemptive
      for enemy in $game_troop.members
        sequence = cg_enemy_order_entries(entries, enemy, sequence)
      end
    end
    entries.sort! do |a, b|
      if a.action.speed == b.action.speed
        a.sequence <=> b.sequence
      else
        b.action.speed <=> a.action.speed
      end
    end
    @action_battlers = entries
    @cg_state_processed = {}
  end

  # Accepts both v0.3 action entries and raw battlers inserted by Tankentai's
  # derivation / forced-action mechanisms.
  def set_next_active_battler
    loop do
      if $game_troop.forcing_battler != nil
        @active_battler = $game_troop.forcing_battler
        $game_troop.forcing_battler = nil
      else
        entry = @action_battlers.shift
        if entry.is_a?(ALBERT_CG::ActionEntry)
          @active_battler = entry.battler
          @active_battler.cg_assign_action(entry.action)
        else
          @active_battler = entry
        end
      end
      return if @active_battler == nil
      return if @active_battler.index != nil
    end
  end

  def cg_action_entry_for_battler?(entry, battler)
    return entry.battler == battler if entry.is_a?(ALBERT_CG::ActionEntry)
    return entry == battler
  end

  def cg_more_queued_actions_for?(battler)
    return false if @action_battlers == nil
    for entry in @action_battlers
      return true if cg_action_entry_for_battler?(entry, battler)
    end
    return false
  end

  alias albert_cg_v03_remove_states_auto remove_states_auto
  def remove_states_auto
    return if @active_battler == nil
    return if cg_more_queued_actions_for?(@active_battler)
    key = @active_battler.object_id
    return if @cg_state_processed != nil && @cg_state_processed[key]
    @cg_state_processed = {} if @cg_state_processed == nil
    @cg_state_processed[key] = true
    albert_cg_v03_remove_states_auto
  end

  alias albert_cg_v03_display_current_state display_current_state
  def display_current_state
    return if @active_battler != nil && cg_more_queued_actions_for?(@active_battler)
    albert_cg_v03_display_current_state
  end

  alias albert_cg_v03_start_main start_main
  def start_main
    cg_hide_phase_window
    albert_cg_v03_start_main
  end
end
