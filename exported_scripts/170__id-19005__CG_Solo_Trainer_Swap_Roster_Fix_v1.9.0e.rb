# RMVX_SCRIPT_INDEX: 170
# RMVX_SCRIPT_ID: 19005
# RMVX_SCRIPT_NAME: CG Solo Trainer Swap Roster Fix v1.9.0e
# RMVX_SOURCE_SHA256: e422f5aa6b6b6ffb17d1775e3c18c4bc7e39579939b9526c7c2b8897cc75f4c4

#==============================================================================
# ■ CG Solo Trainer Swap Roster Fix v1.9.0e
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【修正目的】
#  v1.9.0d 仍透過 Game_Party#members 判定換位候選。舊版名冊權威層的
#  members／active cache 仍帶有「主角只配一隻出戰寵物」的歷史邏輯，
#  因此畫面與 HUD 雖有三隻攜帶寵物，換位選單仍只取得第一隻。
#
# 【本版規則】
#  1. 換位候選唯一以三個攜帶欄 cg_carried_pet_slot(0..2) 為準。
#  2. 不再使用 members、cg_active_pet、舊 owner/pair cache 篩選寵物。
#  3. 主角位於後排時，可選擇另一排的任一攜帶寵物。
#  4. 寵物位於主角另一排時，可選擇與主角交換。
#  5. 每回合最多安排一次主角／寵物交換；普通移動不會鎖住交換。
#
# 【放置位置】
#  CG Solo Trainer Swap Target Fix v1.9.0d 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_SoloTrainerSwapRosterFix_1_9_0e"] = true

module ALBERT_CG
  SOLO_TRAINER_SWAP_ROSTER_FIX_VERSION = "1.9.0e"

  def self.apply_solo_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.9.0e"
  end
end

#==============================================================================
# ■ Game_Party
#==============================================================================
class Game_Party < Game_Unit
  #--------------------------------------------------------------------------
  # ● 直接從三個攜帶欄取得本場三隻寵物
  #--------------------------------------------------------------------------
  def cg_v190e_carried_battle_pets
    result = []
    slot_count = ALBERT_CG::SOLO_PET_SLOTS.to_i
    for slot_index in 0...slot_count
      pet = nil
      if respond_to?(:cg_carried_pet_slot)
        pet = cg_carried_pet_slot(slot_index)
      elsif respond_to?(:cg_active_pets)
        list = cg_active_pets
        pet = list[slot_index] if list != nil
      end
      next if pet == nil
      duplicate = false
      for existing in result
        if existing.equal?(pet) || existing.id.to_i == pet.id.to_i
          duplicate = true
          break
        end
      end
      result.push(pet) unless duplicate
    end
    return result
  rescue
    return []
  end

  def cg_v190e_solo_human
    return $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID] if $game_actors != nil
    return nil
  rescue
    return nil
  end

  # 舊 API 最終改接攜帶欄，避免後載入舊權威層又只承認第一隻。
  def cg_v190d_battle_human
    return cg_v190e_solo_human
  end

  def cg_v190d_battle_pets
    return cg_v190e_carried_battle_pets
  end

  def cg_v190a_solo_human
    return cg_v190e_solo_human
  end

  def cg_v190a_solo_pet?(actor)
    return false if actor == nil
    for pet in cg_v190e_carried_battle_pets
      return true if pet.equal?(actor)
      return true if pet.id.to_i == actor.id.to_i
    end
    return false
  rescue
    return false
  end

  def cg_v190a_actor_by_id(actor_id)
    actor_id = actor_id.to_i
    human = cg_v190e_solo_human
    return human if human != nil && human.id.to_i == actor_id
    for pet in cg_v190e_carried_battle_pets
      return pet if pet.id.to_i == actor_id
    end
    if $game_actors != nil && $game_actors.respond_to?(:cg_pet)
      pet = $game_actors.cg_pet(actor_id)
      return pet if pet != nil
    end
    return $game_actors[actor_id] if $game_actors != nil
    return nil
  rescue
    return nil
  end

  # 不再以 members 判定是否「在場」。Solo Trainer 模式的戰鬥名冊就是
  # Actor 1 加三個攜帶欄，畫面、輸入槽與 HUD 皆由同一資料源建立。
  def cg_v190e_in_solo_battle_roster?(actor)
    return false if actor == nil
    human = cg_v190e_solo_human
    return true if human != nil && actor.id.to_i == human.id.to_i
    return cg_v190a_solo_pet?(actor)
  rescue
    return false
  end

  def cg_v190d_valid_battle_member?(actor)
    return cg_v190e_in_solo_battle_roster?(actor)
  end

  def cg_v190a_legal_swap_pair?(actor_a, actor_b)
    return false if actor_a == nil || actor_b == nil
    human = cg_v190e_solo_human
    return false if human == nil

    if actor_a.id.to_i == human.id.to_i
      pet = actor_b
    elsif actor_b.id.to_i == human.id.to_i
      pet = actor_a
    else
      return false
    end

    return false unless cg_v190a_solo_pet?(pet)
    return false unless cg_v190e_in_solo_battle_roster?(human)
    return false unless cg_v190e_in_solo_battle_roster?(pet)
    return false if human.respond_to?(:exist?) && !human.exist?
    return false if pet.respond_to?(:exist?) && !pet.exist?
    return false unless human.respond_to?(:cg_battle_slot_assigned?)
    return false unless pet.respond_to?(:cg_battle_slot_assigned?)
    return false unless human.cg_battle_slot_assigned?
    return false unless pet.cg_battle_slot_assigned?
    return false if human.cg_battle_row == pet.cg_battle_row
    return true
  rescue
    return false
  end
end

#==============================================================================
# ■ Scene_Battle
#==============================================================================
class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # ● 依三個攜帶欄建立完整移動／交換選項
  #--------------------------------------------------------------------------
  def cg_move_entries
    entries = []
    battler = @active_battler
    return entries if battler == nil
    return entries unless battler.respond_to?(:cg_battle_slot_assigned?)
    return entries unless battler.cg_battle_slot_assigned?

    human = $game_party.cg_v190e_solo_human
    pets = $game_party.cg_v190e_carried_battle_pets
    swap_locked = cg_v190a_swap_planned_before_current?

    unless swap_locked
      if human != nil && battler.id.to_i == human.id.to_i
        for slot_index in 0...ALBERT_CG::SOLO_PET_SLOTS
          pet = pets[slot_index]
          next if pet == nil
          next unless $game_party.cg_v190a_legal_swap_pair?(human, pet)
          entries.push({
            :type => :swap_pet,
            :target_id => pet.id,
            :pet_slot => slot_index,
            :text => "與寵物" + (slot_index + 1).to_s + "「" +
              pet.name.to_s + "」交換位置"
          })
        end
      elsif $game_party.cg_v190a_solo_pet?(battler)
        if human != nil &&
           $game_party.cg_v190a_legal_swap_pair?(battler, human)
          entries.push({
            :type => :swap_pet,
            :target_id => human.id,
            :text => "與主角「" + human.name.to_s + "」交換位置"
          })
        end
      end
    end

    # 普通移動保留。只有真正安排 swap_pet 才會鎖住後續交換。
    for row in [:front, :back]
      for column in 0...ALBERT_CG::BATTLE_COLUMNS
        next if battler.cg_battle_row == row &&
          battler.cg_battle_column == column
        next if $game_party.cg_slot_occupied_by_other?(row, column,
          battler, false)
        entries.push({
          :type => :move,
          :text => "移至" + ALBERT_CG.cg_slot_text(row, column),
          :row => row,
          :column => column
        })
      end
    end
    return entries
  rescue
    return []
  end

  # 開啟指令時再次以攜帶欄刷新可用性。
  unless method_defined?(:albert_cg_v190e_start_actor_command_selection)
    alias albert_cg_v190e_start_actor_command_selection \
      start_actor_command_selection
  end
  def start_actor_command_selection
    result = albert_cg_v190e_start_actor_command_selection
    if @actor_command_window != nil && @active_battler != nil &&
       @actor_command_window.respond_to?(:cg_set_command_enabled) &&
       @actor_command_window.respond_to?(:cg_command_types) &&
       @actor_command_window.cg_command_types != nil &&
       @actor_command_window.cg_command_types.include?(:move)
      @actor_command_window.cg_set_command_enabled(:move,
        !cg_move_entries.empty?)
    end
    return result
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  unless method_defined?(:albert_cg_v190e_load_database)
    alias albert_cg_v190e_load_database load_database
  end
  def load_database
    albert_cg_v190e_load_database
    ALBERT_CG.apply_solo_title
  end
end
