# RMVX_SCRIPT_INDEX: 128
# RMVX_SCRIPT_ID: 98941046
# RMVX_SCRIPT_NAME: CG Fixed Pet Battle Role v0.5.11
# RMVX_SOURCE_SHA256: bbbf82f0a450f4afd877866067e1f227958a3626cd3d70f7dca8ddaa2d0c3667

#==============================================================================
# ** ALBERT CG 固定寵物戰鬥身分與雙向換位修正
#------------------------------------------------------------------------------
#  版本：v0.5.11
#  引擎：RPG Maker VX／RGSS2
#  前置：CG Owner Pet Rules v0.5.10
#------------------------------------------------------------------------------
# 【用途】
#  隊友固定寵物雖然使用普通資料庫 Actor，戰鬥中仍必須被辨識為寵物。
#  本腳本統一修正固定寵物的身分、指令、預設站位與主人配對。
#
# 【主要規則】
#  1. FIXED_PARTNER_PET_ACTORS 右側的 Actor 一律視為固定寵物。
#  2. 固定寵物不會再被列為正式人物，也不會取得人物指令組。
#  3. 固定寵物預設站在主人同列、另一排的位置。
#  4. 主人只能與自己的寵物交換位置。
#  5. 寵物也可以從自己的指令列選擇「移動」，主動與主人交換位置。
#  6. 主角 Clone 寵物同樣可以主動與主角交換位置。
#  7. 沒有寵物出戰時，主人仍只能移到自己同列、另一排的寵物空格。
#  8. 每名主人仍可透過「換寵」收回自己的寵物。
#
# 【固定寵物設定】
#  請在 CG Config 設定：
#    FIXED_PARTNER_PET_ACTORS = {2 => 103}
#  代表 Actor 2 的固定寵物是 Actor 103。
#
# 【腳本位置】
#  請放在「CG Owner Pet Rules」下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_FixedPetBattleRole"] = true

module ALBERT_CG
  FIXED_PET_BATTLE_ROLE_VERSION = "0.5.11"
end

#==============================================================================
# ■ Game_Actor
#------------------------------------------------------------------------------
#  普通資料庫 Actor 也能依固定配對表被辨識為戰鬥寵物。
#==============================================================================
class Game_Actor < Game_Battler
  def cg_fixed_partner_pet?
    return false if respond_to?(:cg_pet?) && cg_pet?
    actor_id = @actor_id.to_i
    if $game_party != nil &&
       $game_party.respond_to?(:cg_fixed_partner_pet_actor?)
      return true if $game_party.cg_fixed_partner_pet_actor?(actor_id)
    end
    map = defined?(ALBERT_CG::FIXED_PARTNER_PET_ACTORS) ?
      ALBERT_CG::FIXED_PARTNER_PET_ACTORS : {}
    for owner_id in map.keys
      return true if map[owner_id].to_i == actor_id
    end
    return false
  end

  def cg_battle_pet?
    return true if respond_to?(:cg_pet?) && cg_pet?
    return cg_fixed_partner_pet?
  end
end

#==============================================================================
# ■ Game_Party
#------------------------------------------------------------------------------
#  使用一份穩定的主人／固定寵物配對表，提供身分、站位與換位查詢。
#==============================================================================
class Game_Party < Game_Unit
  # 合併 Config 預設配對與存檔中的動態配對；動態配對優先。
  def cg_v0511_fixed_partner_map
    result = {}
    defaults = defined?(ALBERT_CG::FIXED_PARTNER_PET_ACTORS) ?
      ALBERT_CG::FIXED_PARTNER_PET_ACTORS : {}
    for owner_id in defaults.keys
      result[owner_id.to_i] = defaults[owner_id].to_i
    end
    if @cg_fixed_partner_pet_map != nil
      for owner_id in @cg_fixed_partner_pet_map.keys
        result[owner_id.to_i] = @cg_fixed_partner_pet_map[owner_id].to_i
      end
    end
    return result
  end

  def cg_fixed_partner_pet_actor_id(owner_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ?
      owner_actor_or_id.id : owner_actor_or_id.to_i
    return cg_v0511_fixed_partner_map[owner_id]
  end

  def cg_fixed_partner_owner_id_for(pet_actor_or_id)
    pet_id = pet_actor_or_id.respond_to?(:id) ?
      pet_actor_or_id.id : pet_actor_or_id.to_i
    map = cg_v0511_fixed_partner_map
    for owner_id in map.keys
      return owner_id if map[owner_id].to_i == pet_id
    end
    return nil
  end

  def cg_fixed_partner_pet_actor?(actor_or_id)
    return cg_fixed_partner_owner_id_for(actor_or_id) != nil
  end

  def cg_fixed_partner_pair?(owner_actor_or_id, pet_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ?
      owner_actor_or_id.id : owner_actor_or_id.to_i
    pet_id = pet_actor_or_id.respond_to?(:id) ?
      pet_actor_or_id.id : pet_actor_or_id.to_i
    return cg_fixed_partner_pet_actor_id(owner_id).to_i == pet_id
  end

  # 取得寵物自己的主人。主角 Clone 寵物固定由主要寵物主人操作。
  def cg_battle_owner_for_pet(pet)
    return nil if pet == nil
    owner_id = nil
    if pet.respond_to?(:cg_pet?) && pet.cg_pet?
      owner_id = ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    else
      owner_id = cg_fixed_partner_owner_id_for(pet)
    end
    return nil if owner_id == nil
    owner = respond_to?(:cg_actor_by_any_id) ?
      cg_actor_by_any_id(owner_id) : $game_actors[owner_id]
    return nil if owner == nil
    return nil unless members.include?(owner)
    return owner
  end

  # 固定普通 Actor 寵物以「實際在隊伍中」作為出戰權威。
  alias albert_cg_v0511_active_pet_for cg_active_pet_for
  def cg_active_pet_for(human)
    return nil if human == nil
    if human.id != ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
      pet_id = cg_fixed_partner_pet_actor_id(human.id)
      if pet_id != nil
        pet = $game_actors[pet_id]
        return nil if pet == nil
        return members.include?(pet) ? pet : nil
      end
    end
    return albert_cg_v0511_active_pet_for(human)
  end

  # 人物清單排除 Clone 寵物與固定普通 Actor 寵物。
  def cg_human_members
    result = []
    for member in members
      is_pet = member.respond_to?(:cg_battle_pet?) && member.cg_battle_pet?
      result.push(member) unless is_pet
    end
    return result
  end

  # 主人與寵物配對驗證。參數順序固定為「主人、寵物」。
  def cg_owner_pet_pair?(owner, pet)
    return false if owner == nil || pet == nil
    if owner.id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
      return false unless pet.respond_to?(:cg_pet?) && pet.cg_pet?
      return respond_to?(:cg_owned_pet_ids) && cg_owned_pet_ids.include?(pet.id)
    end
    return cg_fixed_partner_pair?(owner, pet)
  end

  # 在既有配置完成後，再確保固定寵物位於主人同列的另一排。
  alias albert_cg_v0511_assign_default_slots cg_assign_default_battle_slots
  def cg_assign_default_battle_slots
    result = albert_cg_v0511_assign_default_slots
    map = cg_v0511_fixed_partner_map
    for owner_id in map.keys
      pet_id = map[owner_id]
      owner = $game_actors[owner_id]
      pet = $game_actors[pet_id]
      next if owner == nil || pet == nil
      next unless members.include?(owner) && members.include?(pet)
      next unless owner.respond_to?(:cg_battle_slot_assigned?)
      next unless owner.cg_battle_slot_assigned?

      desired_row = owner.cg_front_row? ? :back : :front
      desired_column = owner.cg_battle_column
      needs_default = !pet.cg_battle_slot_assigned? || !pet.cg_battle_slot_manual?
      if needs_default &&
         !cg_slot_occupied_by_other?(desired_row, desired_column, pet, false)
        pet.cg_set_default_battle_slot(desired_row, desired_column)
      end
    end
    return result
  end
end

#==============================================================================
# ■ Window_ActorCommand
#------------------------------------------------------------------------------
#  寵物指令追加「移動」。人物的原有指令排列不變。
#==============================================================================
class Window_ActorCommand < Window_Command
  alias albert_cg_v0511_actor_command_setup setup
  def setup(actor)
    albert_cg_v0511_actor_command_setup(actor)
    return if actor == nil
    return unless actor.respond_to?(:cg_battle_pet?) && actor.cg_battle_pet?
    @cg_command_types = [] if @cg_command_types == nil
    unless @cg_command_types.include?(:move)
      @commands.push("移動")
      @cg_command_types.push(:move)
      @item_max = @commands.size
      create_contents
      self.top_row = 0 if respond_to?(:top_row=)
      refresh
      self.index = 0 if self.index == nil || self.index < 0
    end
  end
end

#==============================================================================
# ■ Scene_Battle
#------------------------------------------------------------------------------
#  人物與寵物都能使用同一套成對換位流程。
#==============================================================================
class Scene_Battle < Scene_Base
  # 最後載入的攔截層：寵物選擇「移動」時也能進入移動選單。
  alias albert_cg_v0511_update_actor_command update_actor_command_selection
  def update_actor_command_selection
    if Input.trigger?(Input::C) && @active_battler != nil &&
       @actor_command_window != nil &&
       @actor_command_window.respond_to?(:cg_command_type) &&
       @actor_command_window.cg_command_type == :move &&
       @active_battler.respond_to?(:cg_battle_pet?) &&
       @active_battler.cg_battle_pet?
      Sound.play_decision
      cg_start_move_command
      return
    end
    albert_cg_v0511_update_actor_command
  end

  # 人物只能與自己的寵物交換；寵物只能與自己的主人交換。
  # 主人沒有寵物時，仍只可移到同列另一排的寵物空格。
  def cg_move_entries
    entries = []
    battler = @active_battler
    return entries if battler == nil

    if battler.respond_to?(:cg_battle_pet?) && battler.cg_battle_pet?
      owner = $game_party.cg_battle_owner_for_pet(battler)
      if owner != nil && owner.exist? && battler.exist? &&
         owner.cg_battle_slot_assigned? && battler.cg_battle_slot_assigned?
        entries.push({:type => :swap_pair,
          :target_id => owner.id,
          :text => "與自己的主人交換位置"})
      end
      return entries
    end

    return entries unless $game_party.cg_owner_pet_manager?(battler)
    pet = $game_party.cg_active_pet_for(battler)
    if pet != nil && $game_party.members.include?(pet)
      if battler.exist? && pet.exist? &&
         battler.cg_battle_slot_assigned? && pet.cg_battle_slot_assigned?
        entries.push({:type => :swap_pair,
          :target_id => pet.id,
          :text => "與自己的寵物交換位置"})
      end
      return entries
    end

    return entries unless battler.cg_battle_slot_assigned?
    row = battler.cg_front_row? ? :back : :front
    column = battler.cg_battle_column
    unless $game_party.cg_slot_occupied_by_other?(row, column, battler, false)
      entries.push({:type => :move,
        :text => "移至自己的寵物空位「" +
                 ALBERT_CG.cg_slot_text(row, column) + "」",
        :row => row, :column => column})
    end
    return entries
  end

  # 保存成對換位目標。cg_swap_pet_id 雖沿用舊名稱，現在可保存主人或寵物 ID。
  def cg_start_move_command
    entries = cg_move_entries
    if entries.empty?
      Sound.play_buzzer
      cg_restore_actor_command_after_popup
      return
    end
    commands = entries.collect { |entry| entry[:text] }
    window = Window_Command.new(272, commands, 1, [commands.size, 8].min)
    index = cg_run_battle_popup(window, "選擇本回合的移動方式")
    if index < 0
      cg_restore_actor_command_after_popup
      return
    end
    entry = entries[index]
    if entry[:type] == :swap_pair
      target = $game_party.cg_actor_by_any_id(entry[:target_id])
      if target == nil || !target.exist?
        Sound.play_buzzer
        cg_restore_actor_command_after_popup
        return
      end
      @active_battler.action.cg_set_swap_pet(target.id)
    else
      @active_battler.action.cg_set_move_slot(entry[:row], entry[:column])
    end
    Sound.play_decision
    next_actor
  end

  # 執行時重新確認配對，避免目標在行動前離場或被換成別人的寵物。
  def cg_execute_swap_pet
    initiator = @active_battler
    target = $game_party.cg_actor_by_any_id(initiator.action.cg_swap_pet_id)
    owner = nil
    pet = nil
    if initiator != nil && initiator.respond_to?(:cg_battle_pet?) &&
       initiator.cg_battle_pet?
      pet = initiator
      owner = target
    else
      owner = initiator
      pet = target
    end

    if owner != nil && pet != nil &&
       $game_party.cg_owner_pet_pair?(owner, pet) &&
       $game_party.cg_swap_human_and_pet_slots(owner, pet, true)
      cg_play_slot_move_sequence([owner, pet])
      text = initiator.name.to_s + "主動與" + target.name.to_s + "交換位置。"
    else
      text = "交換位置失敗：只能與自己的主人或寵物交換。"
    end
    cg_show_special_action_text(text)
  end
end
