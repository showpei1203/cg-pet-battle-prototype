# RMVX_SCRIPT_INDEX: 166
# RMVX_SCRIPT_ID: 98941071
# RMVX_SCRIPT_NAME: CG Solo Trainer Runtime Fix v1.9.0a
# RMVX_SOURCE_SHA256: 212439c56dec5f2d8fc547c561e8319e062e673d8e560f94461cea3242ea5925

#==============================================================================
# ■ CG Solo Trainer Runtime Fix v1.9.0a
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【修正內容】
#  1. 修正戰鬥結束時 Viewport 沒有 disposed? 方法造成的錯誤。
#  2. 將「交換位置」改為主角與三隻攜帶寵物共用的單回合權威規則。
#  3. 同一回合最多只能安排一次主角／寵物交換位置。
#  4. 主角只能和位於另一排的寵物交換；寵物也只能和另一排的主角交換。
#  5. 主角在後排時，可選擇三隻前排寵物中的任一隻。
#  6. 主角在前排時，只能和後排寵物交換；前排寵物不會出現換位項目。
#  7. 修正寵物管理由攜帶欄 2 按下時過早跳到倉庫的問題。
#  8. 從能力配點／技能資料返回後，重新開啟原寵物的子選單。
#  9. 取消「替換」選擇時，返回原寵物子選單的「替換」項目。
#
# 【放置位置】
#  CG Solo Trainer System v1.9.0 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_SoloTrainerRuntimeFix_1_9_0a"] = true

module ALBERT_CG
  SOLO_TRAINER_RUNTIME_FIX_VERSION = "1.9.0a"

  # Scene_Title 既有補丁會呼叫這個方法，因此在最後一層更新標題即可。
  def self.apply_solo_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.9.0a"
  end
end

#==============================================================================
# ■ Game_Temp
#------------------------------------------------------------------------------
# 保存從寵物配點／技能畫面返回時要重新開啟的子選單。
#==============================================================================
class Game_Temp
  attr_accessor :cg_v190a_petlab_reopen_command
end

#==============================================================================
# ■ Game_Party
#------------------------------------------------------------------------------
# 主角與三隻自由寵物的換位，不再借用舊的單一配對表。
#==============================================================================
class Game_Party < Game_Unit
  def cg_v190a_solo_human
    return nil if $game_actors == nil
    return $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
  end

  def cg_v190a_actor_by_id(actor_id)
    actor_id = actor_id.to_i
    actor = nil
    if $game_actors != nil && $game_actors.respond_to?(:cg_pet)
      actor = $game_actors.cg_pet(actor_id)
    end
    actor = $game_actors[actor_id] if actor == nil && $game_actors != nil
    return actor
  rescue
    return nil
  end

  def cg_v190a_raw_member?(actor)
    return false if actor == nil
    @actors = [] if @actors == nil
    return @actors.include?(actor.id.to_i)
  end

  def cg_v190a_solo_pet?(actor)
    return false if actor == nil
    return false unless actor.respond_to?(:cg_pet?) && actor.cg_pet?
    return cg_carried_pet_ids.include?(actor.id.to_i)
  rescue
    return false
  end

  # 規則：只能由主角與另一排的攜帶寵物互換。
  def cg_v190a_legal_swap_pair?(actor_a, actor_b)
    return false if actor_a == nil || actor_b == nil
    human = cg_v190a_solo_human
    return false if human == nil

    if actor_a.id.to_i == human.id.to_i
      pet = actor_b
    elsif actor_b.id.to_i == human.id.to_i
      pet = actor_a
    else
      return false
    end

    return false unless cg_v190a_solo_pet?(pet)
    return false unless cg_v190a_raw_member?(human)
    return false unless cg_v190a_raw_member?(pet)
    return false unless human.exist? && pet.exist?
    return false unless human.respond_to?(:cg_battle_slot_assigned?)
    return false unless pet.respond_to?(:cg_battle_slot_assigned?)
    return false unless human.cg_battle_slot_assigned?
    return false unless pet.cg_battle_slot_assigned?
    return false if human.cg_battle_row == pet.cg_battle_row
    return true
  rescue
    return false
  end

  # 直接交換目前格位，保留 Tankentai 的位移前座標供動畫使用。
  def cg_v190a_swap_solo_positions(actor_a, actor_b, animated = true)
    return false unless cg_v190a_legal_swap_pair?(actor_a, actor_b)

    actor_a_old_x = actor_a.respond_to?(:position_x) ? actor_a.position_x : 0
    actor_a_old_y = actor_a.respond_to?(:position_y) ? actor_a.position_y : 0
    actor_b_old_x = actor_b.respond_to?(:position_x) ? actor_b.position_x : 0
    actor_b_old_y = actor_b.respond_to?(:position_y) ? actor_b.position_y : 0

    a_row = actor_a.cg_battle_row
    a_column = actor_a.cg_battle_column
    b_row = actor_b.cg_battle_row
    b_column = actor_b.cg_battle_column

    actor_a.cg_set_battle_slot(b_row, b_column, true)
    actor_b.cg_set_battle_slot(a_row, a_column, true)

    if animated && respond_to?(:cg_prepare_animated_slot_transition)
      cg_prepare_animated_slot_transition(actor_a, actor_a_old_x, actor_a_old_y)
      cg_prepare_animated_slot_transition(actor_b, actor_b_old_x, actor_b_old_y)
    else
      actor_a.reset_coordinate if actor_a.respond_to?(:reset_coordinate)
      actor_b.reset_coordinate if actor_b.respond_to?(:reset_coordinate)
      actor_a.base_position if actor_a.respond_to?(:base_position)
      actor_b.base_position if actor_b.respond_to?(:base_position)
    end
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
  # ● HUD 安全釋放
  #--------------------------------------------------------------------------
  # RGSS2 的 Viewport 有 dispose，但沒有 Sprite／Bitmap 的 disposed? API。
  def cg_v17_dispose_hud
    if @cg_v17_hud_sprites != nil
      for key in @cg_v17_hud_sprites.keys
        object = @cg_v17_hud_sprites[key]
        next if object == nil
        begin
          if object.respond_to?(:disposed?)
            object.dispose unless object.disposed?
          elsif object.respond_to?(:dispose)
            object.dispose
          end
        rescue
        end
      end
      @cg_v17_hud_sprites.clear
    end

    viewport = @cg_v17_hud_viewport
    @cg_v17_hud_viewport = nil
    if viewport != nil
      begin
        if viewport.respond_to?(:disposed?)
          viewport.dispose unless viewport.disposed?
        else
          viewport.dispose
        end
      rescue
      end
    end
  end

  #--------------------------------------------------------------------------
  # ● 是否已有較早的指令槽安排換位
  #--------------------------------------------------------------------------
  def cg_v190a_swap_action?(action)
    return false if action == nil
    return false unless action.kind == 0
    return action.basic == ALBERT_CG::CG_BASIC_SWAP_PET
  rescue
    return false
  end

  def cg_v190a_swap_planned_before_current?
    return false if @cg_input_slots == nil
    return false if @cg_input_slot_index == nil
    maximum = [@cg_input_slot_index.to_i, @cg_input_slots.size].min
    for i in 0...maximum
      slot = @cg_input_slots[i]
      next if slot == nil
      return true if cg_v190a_swap_action?(slot.action)
    end
    return false
  end

  #--------------------------------------------------------------------------
  # ● 建立移動／交換選項
  #--------------------------------------------------------------------------
  def cg_move_entries
    entries = []
    battler = @active_battler
    return entries if battler == nil
    return entries unless battler.respond_to?(:cg_battle_slot_assigned?)
    return entries unless battler.cg_battle_slot_assigned?

    human = $game_party.cg_v190a_solo_human
    pets = $game_party.cg_active_pets
    swap_locked = cg_v190a_swap_planned_before_current?

    unless swap_locked
      if human != nil && battler.id.to_i == human.id.to_i
        # 主角可選擇所有位於另一排的攜帶寵物。
        for pet in pets
          next unless $game_party.cg_v190a_legal_swap_pair?(human, pet)
          entries.push({:type => :swap_pet,
            :target_id => pet.id,
            :text => "與" + pet.name.to_s + "交換位置"})
        end
      elsif $game_party.cg_v190a_solo_pet?(battler)
        # 寵物只有在與主角分處前後排時才可選擇換位。
        if $game_party.cg_v190a_legal_swap_pair?(battler, human)
          entries.push({:type => :swap_pet,
            :target_id => human.id,
            :text => "與" + human.name.to_s + "交換位置"})
        end
      end
    end

    # 保留原本的空格移動；單回合換位鎖只限制「交換位置」。
    for row in [:front, :back]
      for column in 0...ALBERT_CG::BATTLE_COLUMNS
        next if battler.cg_battle_row == row &&
          battler.cg_battle_column == column
        next if $game_party.cg_slot_occupied_by_other?(row, column,
          battler, false)
        entries.push({:type => :move,
          :text => "移至" + ALBERT_CG.cg_slot_text(row, column),
          :row => row, :column => column})
      end
    end
    return entries
  end

  #--------------------------------------------------------------------------
  # ● Sidecar 移動子選單
  #--------------------------------------------------------------------------
  def cg_start_move_command
    entries = cg_move_entries
    if entries.empty?
      Sound.play_buzzer
      cg_restore_actor_command_after_popup
      return
    end

    window = if defined?(Window_CG_BattleSidecarList)
      Window_CG_BattleSidecarList.new(entries, :move)
    else
      commands = entries.collect { |entry| entry[:text] }
      Window_Command.new(272, commands, 1, [commands.size, 8].min)
    end
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
      target = $game_party.cg_v190a_actor_by_id(entry[:target_id])
      unless $game_party.cg_v190a_legal_swap_pair?(@active_battler, target)
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
  # ● 執行主角／寵物換位
  #--------------------------------------------------------------------------
  def cg_execute_swap_pet
    initiator = @active_battler
    if initiator == nil || initiator.action == nil
      cg_show_special_action_text("交換位置失敗：找不到行動者。")
      return
    end

    target = $game_party.cg_v190a_actor_by_id(
      initiator.action.cg_swap_pet_id)
    unless $game_party.cg_v190a_legal_swap_pair?(initiator, target)
      cg_show_special_action_text(
        "交換位置失敗：主角與目標寵物必須分處前後排且仍能戰鬥。")
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
end

#==============================================================================
# ■ Scene_CG_PetLab
#==============================================================================
class Scene_CG_PetLab < Scene_Base
  # 保存 Window_Selectable 在本幀處理方向鍵前的索引。
  alias albert_cg_v190a_petlab_update update
  def update
    @cg_v190a_carry_index_before_update = @carry_window == nil ? -1 :
      @carry_window.index
    @cg_v190a_storage_index_before_update = @storage_window == nil ? -1 :
      @storage_window.index
    albert_cg_v190a_petlab_update
  end

  # 從配點／技能畫面返回時，回到原本的子選單與選項。
  alias albert_cg_v190a_petlab_start start
  def start
    albert_cg_v190a_petlab_start
    data = $game_temp == nil ? nil :
      $game_temp.cg_v190a_petlab_reopen_command
    return if data == nil
    $game_temp.cg_v190a_petlab_reopen_command = nil

    pet_id = data[0].to_i
    command_index = data[1].to_i
    pet = cg_v190_current_pet
    if pet == nil || pet.id.to_i != pet_id
      cg_v190_restore_selection(pet_id)
      cg_v190_activate_focus(@focus)
      cg_v190_refresh_detail
      pet = cg_v190_current_pet
    end
    if pet != nil && pet.id.to_i == pet_id
      cg_v190_open_command(pet)
      @command_window.index = command_index if @command_window != nil
    end
  end

  # 攜帶欄 2 → 3 只移動游標；已經位於欄 3 再按下才進入倉庫。
  def cg_v190_update_lists
    if Input.trigger?(Input::B)
      Sound.play_cancel
      $scene = Scene_Map.new
      return
    elsif Input.trigger?(Input::L) || Input.trigger?(Input::R)
      cg_v190_switch_focus
      return
    end

    if @focus == :carry && Input.trigger?(Input::DOWN) &&
       @cg_v190a_carry_index_before_update.to_i >=
       ALBERT_CG::SOLO_PET_SLOTS - 1 &&
       @carry_window.index >= ALBERT_CG::SOLO_PET_SLOTS - 1
      cg_v190_activate_focus(:storage)
      @storage_window.index = 0
      Sound.play_cursor
      return
    elsif @focus == :storage && Input.trigger?(Input::UP) &&
       @cg_v190a_storage_index_before_update.to_i <= 0 &&
       @storage_window.index <= 0
      cg_v190_activate_focus(:carry)
      @carry_window.index = ALBERT_CG::SOLO_PET_SLOTS - 1
      Sound.play_cursor
      return
    end

    return unless Input.trigger?(Input::C)
    pet = cg_v190_current_pet
    if pet == nil
      if @focus == :carry && !@storage_window.data.empty?
        @swap_origin = :carry
        @swap_slot_index = @carry_window.index
        @swap_pet_id = nil
        cg_v190_activate_focus(:storage)
        @storage_window.index = 0
        Sound.play_decision
        cg_v190_refresh_title
      else
        Sound.play_buzzer
      end
      return
    end
    Sound.play_decision
    cg_v190_open_command(pet)
  end

  # 配點／技能資料離開後回到相同子選單項目。
  def cg_v190_update_command
    if Input.trigger?(Input::B)
      Sound.play_cancel
      cg_v190_close_command
      return
    end
    return unless Input.trigger?(Input::C)
    pet = cg_v190_current_pet
    if pet == nil
      Sound.play_buzzer
      cg_v190_close_command
      return
    end

    case @command_window.index
    when 0
      Sound.play_decision
      $game_temp.cg_v190a_petlab_reopen_command = [pet.id, 0]
      $scene = Scene_CG_PetGrowth.new(pet.id,
        @focus == :storage ? :storage : :carried)
    when 1
      Sound.play_decision
      $game_temp.cg_v190a_petlab_reopen_command = [pet.id, 1]
      $scene = Scene_CG_SkillManager.new(pet.id, :petlab,
        @focus == :storage ? :storage : :carried)
    when 2
      cg_v190_begin_replace(pet)
    when 3
      cg_v190_open_release_confirm(pet)
    when 4
      Sound.play_cancel
      cg_v190_close_command
    end
  end

  # 取消替換時，回到原寵物子選單的「替換」。
  def cg_v190_cancel_replace
    origin = @swap_origin
    pet_id = @swap_pet_id
    slot_index = @swap_slot_index

    @swap_origin = nil
    @swap_pet_id = nil
    @swap_slot_index = nil

    if origin == :carry
      cg_v190_activate_focus(:carry)
      @carry_window.index = slot_index.to_i if slot_index != nil
    elsif origin == :storage
      cg_v190_activate_focus(:storage)
      if pet_id != nil
        for i in 0...@storage_window.data.size
          pet = @storage_window.data[i]
          if pet != nil && pet.id.to_i == pet_id.to_i
            @storage_window.index = i
            break
          end
        end
      end
    else
      cg_v190_activate_focus(:carry)
    end

    cg_v190_refresh_title
    cg_v190_refresh_detail
    pet = cg_v190_current_pet
    if pet != nil && pet_id != nil
      cg_v190_open_command(pet)
      @command_window.index = 2 if @command_window != nil
    end
  end
end
