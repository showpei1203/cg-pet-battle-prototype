# RMVX_SCRIPT_INDEX: 172
# RMVX_SCRIPT_ID: 98941076
# RMVX_SCRIPT_NAME: CG Solo Trainer Raw Roster Fix v1.9.0h
# RMVX_SOURCE_SHA256: fb0b227a5644e9f8cf1e4dfddb4d34f78bfc50baea7069489bbe687b12970af8

#==============================================================================
# ■ CG Solo Trainer Raw Roster Fix v1.9.0h
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【修正目的】
#  v1.9.0f 在主角輸入指令時仍可能只能取得第一隻寵物；但寵物 2、3
#  自己輸入時又能與主角交換。這表示舊的 active pet／input slot 權威
#  仍在主角回合把名冊裁成「主角＋寵物1」。
#
# 【本版唯一權威】
#  戰鬥開始時 Game_Party 的原始 @actors 已實際保存：
#    Actor 1、攜帶寵物1、攜帶寵物2、攜帶寵物3
#  本補丁直接讀取這份原始戰鬥名冊，不呼叫 members、cg_active_pet、
#  cg_active_pets、配對表或會重整名冊的 prepare 方法。
#
# 【正式規則】
#  1. 主角可與另一排的任一隻實際參戰寵物交換。
#  2. 寵物可與另一排的主角交換。
#  3. 同一回合最多安排一次交換；普通移動不鎖住交換。
#  4. 執行交換時，也從同一份原始名冊尋找目標。
#  5. 每次開啟移動選單會寫出 CG_SwapDebug.log。
#
# 【放置位置】
#  所有 CG Solo Trainer 修正腳本下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_SoloTrainerRawRosterFix_1_9_0h"] = true

module ALBERT_CG
  SOLO_TRAINER_RAW_ROSTER_FIX_VERSION = "1.9.0h"

  def self.apply_solo_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.9.0h"
  end
end

#==============================================================================
# ■ Game_Party
#==============================================================================
class Game_Party < Game_Unit
  #--------------------------------------------------------------------------
  # ● 不觸發任何舊同步鏈，直接讀取目前戰鬥的原始 @actors
  #--------------------------------------------------------------------------
  def cg_v190g_raw_solo_roster
    result = []
    raw_ids = @actors == nil ? [] : @actors.dup
    for actor_id in raw_ids
      actor_id = actor_id.to_i
      battler = nil
      if $game_actors != nil && $game_actors.respond_to?(:cg_pet)
        battler = $game_actors.cg_pet(actor_id)
      end
      battler = $game_actors[actor_id] if battler == nil &&
        $game_actors != nil
      next if battler == nil
      duplicate = false
      for existing in result
        if existing.equal?(battler)
          duplicate = true
          break
        end
      end
      result.push(battler) unless duplicate
    end
    return result
  rescue
    return []
  end

  def cg_v190g_raw_human
    for battler in cg_v190g_raw_solo_roster
      return battler if battler.respond_to?(:id) &&
        battler.id.to_i == ALBERT_CG::SOLO_HUMAN_ACTOR_ID
    end
    return $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID] if
      $game_actors != nil
    return nil
  rescue
    return nil
  end

  def cg_v190g_raw_pets
    result = []
    for battler in cg_v190g_raw_solo_roster
      next if battler == nil
      next if battler.respond_to?(:id) &&
        battler.id.to_i == ALBERT_CG::SOLO_HUMAN_ACTOR_ID
      result.push(battler)
      break if result.size >= ALBERT_CG::SOLO_PET_SLOTS.to_i
    end

    # 舊存檔或腳本順序異常時，直接讀取原始攜帶 ID 補齊；不呼叫
    # cg_prepare_pet_storage_data，避免它再次經過舊 active pet 同步鏈。
    if result.size < ALBERT_CG::SOLO_PET_SLOTS.to_i
      raw_carried = instance_variable_get(:@cg_carried_pet_ids)
      raw_carried = [] if raw_carried == nil
      for pet_id in raw_carried
        pet = $game_actors == nil ? nil : $game_actors.cg_pet(pet_id.to_i)
        next if pet == nil
        duplicate = false
        for existing in result
          if existing.equal?(pet)
            duplicate = true
            break
          end
        end
        result.push(pet) unless duplicate
        break if result.size >= ALBERT_CG::SOLO_PET_SLOTS.to_i
      end
    end
    return result
  rescue
    return []
  end
end

#==============================================================================
# ■ Scene_Battle
#==============================================================================
class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # ● 本版的唯一戰鬥名冊
  #--------------------------------------------------------------------------
  def cg_v190g_human_and_pets
    human = $game_party == nil ? nil : $game_party.cg_v190g_raw_human
    pets = $game_party == nil ? [] : $game_party.cg_v190g_raw_pets

    # 若原始 @actors 尚未完成同步，以輸入槽補齊，但不讓它覆蓋原名冊。
    if @cg_input_slots != nil
      for slot in @cg_input_slots
        battler = slot == nil ? nil : slot.battler
        next if battler == nil
        if battler.respond_to?(:id) &&
           battler.id.to_i == ALBERT_CG::SOLO_HUMAN_ACTOR_ID
          human = battler if human == nil
        else
          duplicate = false
          for existing in pets
            if existing.equal?(battler)
              duplicate = true
              break
            end
          end
          pets.push(battler) unless duplicate
        end
      end
    end

    return [human, pets[0, ALBERT_CG::SOLO_PET_SLOTS.to_i] || []]
  rescue
    return [nil, []]
  end

  def cg_v190g_same_battler?(a, b)
    return false if a == nil || b == nil
    return true if a.equal?(b)
    return false unless a.respond_to?(:id) && b.respond_to?(:id)
    return a.id.to_i == b.id.to_i
  rescue
    return false
  end

  def cg_v190g_row(battler, fallback)
    return fallback if battler == nil
    if battler.respond_to?(:cg_battle_row)
      row = battler.cg_battle_row
      return row if row == :front || row == :back
    end
    return fallback
  rescue
    return fallback
  end

  def cg_v190g_legal_swap?(human, pet)
    return false if human == nil || pet == nil
    return false if cg_v190g_same_battler?(human, pet)
    return cg_v190g_row(human, :back) != cg_v190g_row(pet, :front)
  rescue
    return false
  end

  def cg_v190g_slot_occupied?(row, column, except_battler = nil)
    human, pets = cg_v190g_human_and_pets
    roster = []
    roster.push(human) if human != nil
    roster.concat(pets)
    for member in roster
      next if member == nil
      next if except_battler != nil && cg_v190g_same_battler?(member,
        except_battler)
      next unless member.respond_to?(:cg_battle_row)
      next unless member.respond_to?(:cg_battle_column)
      return true if member.cg_battle_row == row &&
        member.cg_battle_column.to_i == column.to_i
    end
    return false
  rescue
    return false
  end

  #--------------------------------------------------------------------------
  # ● 最終移動／換位候選
  #--------------------------------------------------------------------------
  def cg_move_entries
    entries = []
    battler = @active_battler
    return entries if battler == nil

    human, pets = cg_v190g_human_and_pets
    swap_locked = cg_v190a_swap_planned_before_current?

    unless swap_locked
      if cg_v190g_same_battler?(battler, human)
        for slot_index in 0...pets.size
          pet = pets[slot_index]
          next if pet == nil
          next unless cg_v190g_legal_swap?(human, pet)
          entries.push({
            :type => :swap_pet,
            :target_id => pet.id,
            :target_object_id => pet.object_id,
            :pet_slot => slot_index,
            :text => "與寵物" + (slot_index + 1).to_s + "「" +
              pet.name.to_s + "」交換位置"
          })
        end
      else
        active_is_pet = false
        for pet in pets
          if cg_v190g_same_battler?(pet, battler)
            active_is_pet = true
            break
          end
        end
        if active_is_pet && cg_v190g_legal_swap?(human, battler)
          entries.push({
            :type => :swap_pet,
            :target_id => human.id,
            :target_object_id => human.object_id,
            :text => "與主角「" + human.name.to_s + "」交換位置"
          })
        end
      end
    end

    battler_row = cg_v190g_row(battler,
      cg_v190g_same_battler?(battler, human) ? :back : :front)
    battler_column = battler.respond_to?(:cg_battle_column) ?
      battler.cg_battle_column.to_i : 1

    for row in [:front, :back]
      for column in 0...ALBERT_CG::BATTLE_COLUMNS
        next if battler_row == row && battler_column == column
        next if cg_v190g_slot_occupied?(row, column, battler)
        entries.push({
          :type => :move,
          :text => "移至" + ALBERT_CG.cg_slot_text(row, column),
          :row => row,
          :column => column
        })
      end
    end

    cg_v190g_write_debug(human, pets, battler, entries)
    return entries
  rescue => error
    cg_v190g_write_error(error)
    return []
  end

  #--------------------------------------------------------------------------
  # ● 以 object_id 優先尋找本場目標
  #--------------------------------------------------------------------------
  def cg_v190g_find_target(entry)
    return nil if entry == nil
    object_id = entry[:target_object_id]
    actor_id = entry[:target_id]
    human, pets = cg_v190g_human_and_pets
    roster = []
    roster.push(human) if human != nil
    roster.concat(pets)
    for battler in roster
      next if battler == nil
      return battler if object_id != nil && battler.object_id == object_id.to_i
    end
    for battler in roster
      next if battler == nil || !battler.respond_to?(:id)
      return battler if actor_id != nil && battler.id.to_i == actor_id.to_i
    end
    return nil
  rescue
    return nil
  end

  #--------------------------------------------------------------------------
  # ● 最終移動子選單
  #--------------------------------------------------------------------------
  def cg_start_move_command
    entries = cg_move_entries
    if entries.empty?
      Sound.play_buzzer
      cg_restore_actor_command_after_popup
      return
    end

    window = Window_CG_BattleSidecarList.new(entries, :move)
    index = cg_run_battle_popup(window, "選擇本回合的移動或交換方式")
    if index < 0
      cg_restore_actor_command_after_popup
      return
    end

    entry = entries[index]
    if entry == nil
      Sound.play_buzzer
      cg_restore_actor_command_after_popup
      return
    end

    if entry[:type] == :swap_pet
      target = cg_v190g_find_target(entry)
      human, pets = cg_v190g_human_and_pets
      pet = cg_v190g_same_battler?(@active_battler, human) ? target :
        @active_battler
      unless cg_v190g_legal_swap?(human, pet)
        Sound.play_buzzer
        cg_restore_actor_command_after_popup
        return
      end
      @active_battler.action.cg_set_swap_pet(target.id)
      @active_battler.action.instance_variable_set(:@cg_v190g_swap_object_id,
        target.object_id)
    else
      @active_battler.action.cg_set_move_slot(entry[:row], entry[:column])
    end
    Sound.play_decision
    next_actor
  end

  #--------------------------------------------------------------------------
  # ● 最終執行換位
  #--------------------------------------------------------------------------
  def cg_execute_swap_pet
    initiator = @active_battler
    if initiator == nil || initiator.action == nil
      cg_show_special_action_text("交換位置失敗：找不到行動者。")
      return
    end

    object_id = initiator.action.instance_variable_get(
      :@cg_v190g_swap_object_id)
    entry = {
      :target_id => initiator.action.cg_swap_pet_id,
      :target_object_id => object_id
    }
    target = cg_v190g_find_target(entry)
    human, pets = cg_v190g_human_and_pets
    pet = cg_v190g_same_battler?(initiator, human) ? target : initiator
    unless cg_v190g_legal_swap?(human, pet)
      cg_show_special_action_text(
        "交換位置失敗：主角與目標寵物必須分處前後排。")
      return
    end

    if $game_party.cg_v190a_swap_solo_positions(initiator, target, true)
      cg_play_slot_move_sequence([initiator, target])
      cg_show_special_action_text(initiator.name.to_s + "與" +
        target.name.to_s + "交換位置。")
    else
      cg_show_special_action_text("交換位置失敗：站位資料已改變。")
    end
  end

  def cg_v190g_write_debug(human, pets, active, entries)
    File.open("CG_SwapDebug.log", "wb") do |file|
      file.write("CG Solo Trainer Raw Roster Fix v1.9.0h\r\n")
      raw_ids = $game_party.instance_variable_get(:@actors) rescue []
      carried_ids = $game_party.instance_variable_get(
        :@cg_carried_pet_ids) rescue []
      file.write("raw_party_ids=#{raw_ids.inspect}\r\n")
      file.write("raw_carried_ids=#{carried_ids.inspect}\r\n")
      file.write("active=#{cg_v190f_debug_battler(active)}\r\n")
      file.write("human=#{cg_v190f_debug_battler(human)}\r\n")
      for i in 0...pets.size
        file.write("pet#{i + 1}=#{cg_v190f_debug_battler(pets[i])}\r\n")
      end
      file.write("entries=#{entries.size}\r\n")
      for i in 0...entries.size
        file.write("  #{i}: #{entries[i].inspect}\r\n")
      end
    end
  rescue
  end

  def cg_v190g_write_error(error)
    File.open("CG_SwapDebug.log", "wb") do |file|
      file.write("ERROR #{error.class}: #{error.message}\r\n")
      file.write((error.backtrace || []).join("\r\n"))
    end
  rescue
  end
end

class Scene_Title < Scene_Base
  unless method_defined?(:albert_cg_v190g_load_database)
    alias albert_cg_v190g_load_database load_database
  end
  def load_database
    albert_cg_v190g_load_database
    ALBERT_CG.apply_solo_title
  end
end
