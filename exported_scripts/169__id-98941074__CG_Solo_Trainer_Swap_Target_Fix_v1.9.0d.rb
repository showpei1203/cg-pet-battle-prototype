# RMVX_SCRIPT_INDEX: 169
# RMVX_SCRIPT_ID: 98941074
# RMVX_SCRIPT_NAME: CG Solo Trainer Swap Target Fix v1.9.0d
# RMVX_SOURCE_SHA256: 4e96454ccff68d48e3b14084866776b28337f7f850545ae3f2fa09137740d9f3

#==============================================================================
# ■ CG Solo Trainer Swap Target Fix v1.9.0d
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【修正內容】
#  1. 主角的「移動」改由目前實際戰鬥隊伍建立換位候選，不再依賴
#     舊的單一主寵配對表或 @actors 原始陣列。
#  2. 主角位於前排／後排時，會列出另一排的所有攜帶寵物。
#  3. 寵物的換位資格同樣以目前戰鬥成員判定，三隻寵物一視同仁。
#  4. 執行換位時，以實際戰鬥成員尋找目標，避免 Clone 寵物只找到
#     第一隻或被舊資料權威過濾。
#
# 【放置位置】
#  CG Solo Trainer Move Command Fix v1.9.0c 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_SoloTrainerSwapTargetFix_1_9_0d"] = true

module ALBERT_CG
  SOLO_TRAINER_SWAP_TARGET_FIX_VERSION = "1.9.0d"

  def self.apply_solo_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.9.0d"
  end
end

#==============================================================================
# ■ Game_Party
#------------------------------------------------------------------------------
#  從目前實際 members 取得主角與三隻寵物。Solo Trainer 模式中除了
#  Actor 1 以外，其餘戰鬥成員全部都是主角攜帶寵物，因此不再讓舊的
#  owner/pair authority 決定誰有資格換位。
#==============================================================================
class Game_Party < Game_Unit
  def cg_v190d_battle_human
    list = members
    for actor in list
      next if actor == nil
      return actor if actor.id.to_i == ALBERT_CG::SOLO_HUMAN_ACTOR_ID
    end
    return $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
  rescue
    return nil
  end

  def cg_v190d_battle_pets
    result = []
    human = cg_v190d_battle_human
    human_id = human == nil ? ALBERT_CG::SOLO_HUMAN_ACTOR_ID : human.id.to_i
    list = members
    for actor in list
      next if actor == nil
      next if actor.id.to_i == human_id
      next if result.include?(actor)
      result.push(actor)
    end
    return result[0, ALBERT_CG::SOLO_PET_SLOTS] || []
  rescue
    return []
  end

  # 舊 API 轉向目前戰鬥成員，避免只有第一隻 Clone 通過舊配對判定。
  def cg_v190a_solo_human
    return cg_v190d_battle_human
  end

  def cg_v190a_solo_pet?(actor)
    return false if actor == nil
    for pet in cg_v190d_battle_pets
      return true if pet.equal?(actor)
      return true if pet.id.to_i == actor.id.to_i
    end
    return false
  rescue
    return false
  end

  def cg_v190a_actor_by_id(actor_id)
    actor_id = actor_id.to_i
    for actor in members
      next if actor == nil
      return actor if actor.id.to_i == actor_id
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

  def cg_v190d_valid_battle_member?(actor)
    return false if actor == nil
    for member in members
      next if member == nil
      return true if member.equal?(actor)
      return true if member.id.to_i == actor.id.to_i
    end
    return false
  rescue
    return false
  end

  # 主角只能與另一排、仍在場的任一攜帶寵物互換。
  def cg_v190a_legal_swap_pair?(actor_a, actor_b)
    return false if actor_a == nil || actor_b == nil
    human = cg_v190d_battle_human
    return false if human == nil

    if actor_a.id.to_i == human.id.to_i
      pet = actor_b
    elsif actor_b.id.to_i == human.id.to_i
      pet = actor_a
    else
      return false
    end

    return false unless cg_v190a_solo_pet?(pet)
    return false unless cg_v190d_valid_battle_member?(human)
    return false unless cg_v190d_valid_battle_member?(pet)
    return false if human.respond_to?(:exist?) && !human.exist?
    return false if pet.respond_to?(:exist?) && !pet.exist?
    return false unless human.respond_to?(:cg_battle_row)
    return false unless pet.respond_to?(:cg_battle_row)
    human_row = human.cg_battle_row
    pet_row = pet.cg_battle_row
    return false unless [:front, :back].include?(human_row)
    return false unless [:front, :back].include?(pet_row)
    return false if human_row == pet_row
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
  # ● 建立目前角色的移動／換位候選
  #--------------------------------------------------------------------------
  def cg_move_entries
    entries = []
    battler = @active_battler
    return entries if battler == nil
    return entries unless battler.respond_to?(:cg_battle_row)
    return entries unless battler.respond_to?(:cg_battle_column)

    human = $game_party.cg_v190d_battle_human
    pets = $game_party.cg_v190d_battle_pets
    swap_locked = cg_v190a_swap_planned_before_current?

    unless swap_locked
      if human != nil && battler.id.to_i == human.id.to_i
        # 依 HUD／隊伍中的實際寵物順序編號。主角可看見另一排的全部寵物。
        for i in 0...pets.size
          pet = pets[i]
          next unless $game_party.cg_v190a_legal_swap_pair?(human, pet)
          entries.push({
            :type => :swap_pet,
            :target_id => pet.id,
            :text => "與寵物" + (i + 1).to_s + "「" +
              pet.name.to_s + "」交換位置"
          })
        end
      elsif $game_party.cg_v190a_solo_pet?(battler)
        if $game_party.cg_v190a_legal_swap_pair?(battler, human)
          entries.push({
            :type => :swap_pet,
            :target_id => human.id,
            :text => "與主角「" + human.name.to_s + "」交換位置"
          })
        end
      end
    end

    # 普通移動仍列出所有未被其他我方成員占用的合法格位。
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

  # 每次開啟角色指令時重新刷新，避免前一隻寵物的換位狀態污染後續角色。
  alias albert_cg_v190d_start_actor_command_selection \
    start_actor_command_selection
  def start_actor_command_selection
    result = albert_cg_v190d_start_actor_command_selection
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
