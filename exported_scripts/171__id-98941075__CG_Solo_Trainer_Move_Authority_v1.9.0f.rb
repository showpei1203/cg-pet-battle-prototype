# RMVX_SCRIPT_INDEX: 171
# RMVX_SCRIPT_ID: 98941075
# RMVX_SCRIPT_NAME: CG Solo Trainer Move Authority v1.9.0f
# RMVX_SOURCE_SHA256: 692825111a2cb6b327c691c824a947abfa10e4975049bb2a07bc1db0bdda5e8c

#==============================================================================
# ■ CG Solo Trainer Move Authority v1.9.0f
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【修正目的】
#  v1.9.0e 的換位候選仍可能被舊名冊、exist?、戰場欄位快取或攜帶欄
#  過濾，導致主角只看見第一隻寵物。本腳本不再從舊主人／寵物配對
#  系統建立候選，而以本回合真正建立的 @cg_input_slots 為最高權威。
#
# 【正式規則】
#  1. 本回合輸入槽中的 Actor 1 為主角，其餘最多三名為出戰寵物。
#  2. 主角可與另一排的任一出戰寵物交換。
#  3. 寵物可與另一排的主角交換。
#  4. 同一回合最多安排一次主角／寵物交換。
#  5. 普通移動的占位判定也使用同一份本回合戰鬥名冊。
#  6. 若舊存檔缺少戰場欄位，只補齊缺少的欄位，不覆蓋玩家已移動的位置。
#
# 【診斷】
#  每次開啟移動選單會覆寫遊戲根目錄的 CG_SwapDebug.log。若仍有問題，
#  該檔會列出實際輸入槽、角色 ID、列／欄與最終選項，避免再靠猜測修補。
#
# 【放置位置】
#  CG Solo Trainer Swap Roster Fix v1.9.0e 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_SoloTrainerMoveAuthority_1_9_0f"] = true

module ALBERT_CG
  SOLO_TRAINER_MOVE_AUTHORITY_VERSION = "1.9.0f"

  def self.apply_solo_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.9.0f"
  end
end

class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # ● 物件是否已存在於陣列，不以 actor id 取代物件身分
  #--------------------------------------------------------------------------
  def cg_v190f_include_battler?(list, battler)
    return false if battler == nil
    for existing in list
      return true if existing.equal?(battler)
    end
    return false
  end

  #--------------------------------------------------------------------------
  # ● 本回合真正參與輸入的戰鬥名冊
  #--------------------------------------------------------------------------
  def cg_v190f_runtime_battlers
    result = []

    if @cg_input_slots != nil
      for slot in @cg_input_slots
        battler = slot == nil ? nil : slot.battler
        next if battler == nil
        result.push(battler) unless cg_v190f_include_battler?(result, battler)
      end
    end

    if @active_battler != nil &&
       !cg_v190f_include_battler?(result, @active_battler)
      result.push(@active_battler)
    end

    # 尚未建立輸入槽時，才使用 Solo Trainer 攜帶名冊補齊。
    if $game_party != nil
      human = $game_actors == nil ? nil :
        $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if human != nil && !cg_v190f_include_battler?(result, human)
        result.unshift(human)
      end

      pets = []
      if $game_party.respond_to?(:cg_active_pets)
        pets = $game_party.cg_active_pets
      elsif $game_party.respond_to?(:cg_v190e_carried_battle_pets)
        pets = $game_party.cg_v190e_carried_battle_pets
      end
      pets = [] if pets == nil
      for pet in pets
        next if pet == nil
        result.push(pet) unless cg_v190f_include_battler?(result, pet)
      end
    end

    return result
  rescue
    return []
  end

  #--------------------------------------------------------------------------
  # ● 分離主角與三隻寵物
  #--------------------------------------------------------------------------
  def cg_v190f_human_and_pets
    human = nil
    pets = []
    for battler in cg_v190f_runtime_battlers
      next if battler == nil
      if battler.respond_to?(:id) &&
         battler.id.to_i == ALBERT_CG::SOLO_HUMAN_ACTOR_ID
        human = battler
      else
        pets.push(battler) unless cg_v190f_include_battler?(pets, battler)
      end
    end
    human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID] if
      human == nil && $game_actors != nil
    return [human, pets[0, ALBERT_CG::SOLO_PET_SLOTS] || []]
  rescue
    return [nil, []]
  end

  #--------------------------------------------------------------------------
  # ● 取得有效列；舊存檔缺失時依實際 X 座標推斷
  #--------------------------------------------------------------------------
  def cg_v190f_row_of(battler, default_row)
    return default_row if battler == nil
    row = battler.respond_to?(:cg_battle_row) ? battler.cg_battle_row : nil
    return row if row == :front || row == :back

    if battler.respond_to?(:screen_x)
      x = battler.screen_x.to_i
      front_distance = (x - ALBERT_CG::ACTOR_FRONT_X.to_i).abs
      back_distance = (x - ALBERT_CG::ACTOR_BACK_X.to_i).abs
      return front_distance <= back_distance ? :front : :back
    end
    return default_row
  rescue
    return default_row
  end

  #--------------------------------------------------------------------------
  # ● 只補齊缺少的戰場欄位
  #--------------------------------------------------------------------------
  def cg_v190f_prepare_slots(human, pets)
    if human != nil
      assigned = human.respond_to?(:cg_battle_slot_assigned?) &&
        human.cg_battle_slot_assigned?
      human.cg_set_battle_slot(:back, 1, true) unless assigned
    end

    for i in 0...pets.size
      pet = pets[i]
      next if pet == nil
      assigned = pet.respond_to?(:cg_battle_slot_assigned?) &&
        pet.cg_battle_slot_assigned?
      pet.cg_set_battle_slot(:front, i, true) unless assigned
    end
  rescue
  end

  #--------------------------------------------------------------------------
  # ● 本回合名冊的格位占用判定
  #--------------------------------------------------------------------------
  def cg_v190f_slot_occupied?(row, column, except_battler = nil)
    for member in cg_v190f_runtime_battlers
      next if member == nil || member.equal?(except_battler)
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
  # ● 主角／寵物是否可交換，不呼叫舊配對權威
  #--------------------------------------------------------------------------
  def cg_v190f_legal_swap?(human, pet)
    return false if human == nil || pet == nil
    human_row = cg_v190f_row_of(human, :back)
    pet_row = cg_v190f_row_of(pet, :front)
    return false if human_row == pet_row
    return true
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

    human, pets = cg_v190f_human_and_pets
    cg_v190f_prepare_slots(human, pets)
    swap_locked = cg_v190a_swap_planned_before_current?

    unless swap_locked
      if human != nil && battler.equal?(human)
        for i in 0...pets.size
          pet = pets[i]
          next if pet == nil
          next unless cg_v190f_legal_swap?(human, pet)
          entries.push({
            :type => :swap_pet,
            :target_id => pet.id,
            :pet_slot => i,
            :text => "與寵物" + (i + 1).to_s + "「" +
              pet.name.to_s + "」交換位置"
          })
        end
      elsif cg_v190f_include_battler?(pets, battler)
        if human != nil && cg_v190f_legal_swap?(human, battler)
          entries.push({
            :type => :swap_pet,
            :target_id => human.id,
            :text => "與主角「" + human.name.to_s + "」交換位置"
          })
        end
      end
    end

    battler_row = cg_v190f_row_of(battler,
      battler.equal?(human) ? :back : :front)
    battler_column = battler.respond_to?(:cg_battle_column) ?
      battler.cg_battle_column.to_i : 1

    for row in [:front, :back]
      for column in 0...ALBERT_CG::BATTLE_COLUMNS
        next if battler_row == row && battler_column == column
        next if cg_v190f_slot_occupied?(row, column, battler)
        entries.push({
          :type => :move,
          :text => "移至" + ALBERT_CG.cg_slot_text(row, column),
          :row => row,
          :column => column
        })
      end
    end

    cg_v190f_write_swap_debug(human, pets, battler, entries)
    return entries
  rescue => error
    cg_v190f_write_error_debug(error)
    return []
  end

  #--------------------------------------------------------------------------
  # ● 由本回合名冊尋找換位目標
  #--------------------------------------------------------------------------
  def cg_v190f_actor_by_id(actor_id)
    actor_id = actor_id.to_i
    for battler in cg_v190f_runtime_battlers
      next if battler == nil
      return battler if battler.id.to_i == actor_id
    end
    return $game_actors.cg_pet(actor_id) if $game_actors != nil &&
      $game_actors.respond_to?(:cg_pet) && $game_actors.cg_pet(actor_id) != nil
    return $game_actors[actor_id] if $game_actors != nil
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
      target = cg_v190f_actor_by_id(entry[:target_id])
      human, pets = cg_v190f_human_and_pets
      pet = @active_battler.equal?(human) ? target : @active_battler
      unless cg_v190f_legal_swap?(human, pet)
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

  #--------------------------------------------------------------------------
  # ● 最終執行換位
  #--------------------------------------------------------------------------
  def cg_execute_swap_pet
    initiator = @active_battler
    if initiator == nil || initiator.action == nil
      cg_show_special_action_text("交換位置失敗：找不到行動者。")
      return
    end

    target = cg_v190f_actor_by_id(initiator.action.cg_swap_pet_id)
    human, pets = cg_v190f_human_and_pets
    pet = initiator.equal?(human) ? target : initiator
    unless cg_v190f_legal_swap?(human, pet)
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

  #--------------------------------------------------------------------------
  # ● 診斷紀錄
  #--------------------------------------------------------------------------
  def cg_v190f_write_swap_debug(human, pets, active, entries)
    File.open("CG_SwapDebug.log", "wb") do |file|
      file.write("CG Solo Trainer Move Authority v1.9.0f\r\n")
      file.write("input_slot_index=#{@cg_input_slot_index.inspect}\r\n")
      file.write("active=#{cg_v190f_debug_battler(active)}\r\n")
      file.write("human=#{cg_v190f_debug_battler(human)}\r\n")
      for i in 0...pets.size
        file.write("pet#{i + 1}=#{cg_v190f_debug_battler(pets[i])}\r\n")
      end
      file.write("entries=#{entries.size}\r\n")
      for i in 0...entries.size
        file.write("  #{i}: #{entries[i].inspect}\r\n")
      end
      if @cg_input_slots != nil
        file.write("input_slots=#{@cg_input_slots.size}\r\n")
        for i in 0...@cg_input_slots.size
          slot = @cg_input_slots[i]
          file.write("  slot#{i}=#{cg_v190f_debug_battler(slot == nil ? nil : slot.battler)}\r\n")
        end
      end
    end
  rescue
  end

  def cg_v190f_debug_battler(battler)
    return "nil" if battler == nil
    row = battler.respond_to?(:cg_battle_row) ? battler.cg_battle_row : nil
    column = battler.respond_to?(:cg_battle_column) ?
      battler.cg_battle_column : nil
    exists = battler.respond_to?(:exist?) ? battler.exist? : nil
    return "#{battler.name}(id=#{battler.id},object=#{battler.object_id},row=#{row},column=#{column},exist=#{exists})"
  rescue
    return battler.class.to_s
  end

  def cg_v190f_write_error_debug(error)
    File.open("CG_SwapDebug.log", "wb") do |file|
      file.write("ERROR #{error.class}: #{error.message}\r\n")
      file.write((error.backtrace || []).join("\r\n"))
    end
  rescue
  end
end

class Scene_Title < Scene_Base
  unless method_defined?(:albert_cg_v190f_load_database)
    alias albert_cg_v190f_load_database load_database
  end
  def load_database
    albert_cg_v190f_load_database
    ALBERT_CG.apply_solo_title
  end
end
