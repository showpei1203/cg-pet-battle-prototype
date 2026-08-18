# RMVX_SCRIPT_INDEX: 167
# RMVX_SCRIPT_ID: 98941072
# RMVX_SCRIPT_NAME: CG Solo Trainer Input Fix v1.9.0b
# RMVX_SOURCE_SHA256: 65ea3d577e4367eb359bca0c23f02180be10da7cfedaef67d6044105e294ed66

#==============================================================================
# ■ CG Solo Trainer Input Fix v1.9.0b
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【修正內容】
#  1. 修正從 Battle Command 選擇「移動」後，同一個確認鍵被子選單
#     立即再次讀取，導致直接選中第一項並與寵物 1 自動換位。
#  2. 主角的移動清單會明確列出所有合法的交換對象。
#  3. 修正攜帶欄第 3 格按下時循環回第 1 格的問題。
#  4. 攜帶欄第 3 格按下會切換到倉庫第 1 格。
#  5. 倉庫第 1 格按上會切換到攜帶欄第 3 格，空欄亦可定位。
#  6. 攜帶與倉庫清單在各自區域內不再首尾循環。
#
# 【放置位置】
#  CG Solo Trainer Runtime Fix v1.9.0a 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_SoloTrainerInputFix_1_9_0b"] = true

module ALBERT_CG
  SOLO_TRAINER_INPUT_FIX_VERSION = "1.9.0b"

  def self.apply_solo_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.9.0b"
  end
end

#==============================================================================
# ■ 攜帶／倉庫清單
#------------------------------------------------------------------------------
# Window_Selectable 在單欄清單收到一次方向鍵 trigger 時，預設允許首尾
# wrap。上下兩個 Window 的邊界需要交給 Scene 切換焦點，因此此處禁止
# 各自循環。
#==============================================================================
class Window_CG_SoloCarrySlots < Window_Selectable
  def cursor_down(wrap = false)
    return if @item_max == nil || @item_max <= 0
    return if @index >= @item_max - 1
    @index += 1
  end

  def cursor_up(wrap = false)
    return if @item_max == nil || @item_max <= 0
    return if @index <= 0
    @index -= 1
  end
end

class Window_CG_SoloStorageList < Window_Selectable
  def cursor_down(wrap = false)
    return if @item_max == nil || @item_max <= 0
    return if @index >= @item_max - 1
    @index += 1
  end

  def cursor_up(wrap = false)
    return if @item_max == nil || @item_max <= 0
    return if @index <= 0
    @index -= 1
  end
end

#==============================================================================
# ■ Scene_Battle
#==============================================================================
class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # ● 主角／寵物的移動與換位候選
  #--------------------------------------------------------------------------
  # 再次於最末層建立，避免舊的單一配對腳本把主角固定連到寵物 1。
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

    # 換位以外，仍可選擇移動至任何合法空格。
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

  #--------------------------------------------------------------------------
  # ● 共用戰鬥 Popup
  #--------------------------------------------------------------------------
  # Battle Command 的確認鍵與 Popup 建立發生在同一幀。若立即檢查 C，
  # 新清單會把開啟選單的那次按鍵當成選中第一項。先跑兩個保護幀，
  # 消耗舊 trigger，玩家放開後再次按 C 才會真正確認。
  def cg_run_battle_popup(window, help_text)
    help = Window_Help.new
    help.set_text(help_text, 1)
    help.z = 500

    if respond_to?(:cg_v183e_headstack_origin)
      x, y = cg_v183e_headstack_origin(window, @active_battler)
    elsif respond_to?(:cg_v182b_sidecar_origin_for_window)
      x, y = cg_v182b_sidecar_origin_for_window(window, @active_battler)
    else
      x, y = [0, 0]
    end
    window.x = x
    window.y = y
    window.z = 540
    window.active = true
    window.visible = true

    if @actor_command_window != nil
      @actor_command_window.active = false
      @actor_command_window.visible = false
    end
    @cg_v182b_popup_window = window

    # 清除開啟 Popup 的確認鍵，並讓滑入動畫先顯示兩幀。
    2.times do
      update_basic
      window.update
    end

    result = -1
    loop do
      update_basic
      window.update
      if Input.trigger?(Input::B)
        Sound.play_cancel
        result = -1
        break
      elsif Input.trigger?(Input::C)
        if window.respond_to?(:enabled?) && !window.enabled?(window.index)
          Sound.play_buzzer
          next
        end
        result = window.index
        break
      end
    end

    @cg_v182b_popup_window = nil
    window.active = false
    window.dispose unless window.disposed?
    help.dispose unless help.disposed?
    return result
  end
end
