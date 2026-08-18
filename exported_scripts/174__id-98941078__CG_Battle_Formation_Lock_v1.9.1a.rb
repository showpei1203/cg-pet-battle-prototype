# RMVX_SCRIPT_INDEX: 174
# RMVX_SCRIPT_ID: 98941078
# RMVX_SCRIPT_NAME: CG Battle Formation Lock v1.9.1a
# RMVX_SOURCE_SHA256: cf0689a2860ee43459dff1c2a493d2123075b72ea3810a276a524514b5608d27

#==============================================================================
# ■ CG Battle Formation Lock v1.9.1a
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【正式規則】
#  1. 保留前排／後排、欄位、射程與前排阻擋等戰鬥判定。
#  2. 戰鬥開始後位置固定，不提供「移動／換位」指令。
#  3. 主角與三隻寵物都不能在戰鬥中交換位置或移到空格。
#  4. 主角預設後排中央；三隻寵物預設前排左／中／右。
#  5. 寵物管理中的攜帶／倉庫「替換」不受影響。
#
# 【相容處理】
#  本腳本放在全部 Move／Swap 修正腳本下方、Main 上方，作為最後規則。
#  除了從 Battle Command 移除「移動」，也攔截舊補丁可能殘留的移動
#  行動，確保不會再改變戰場位置。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattleFormationLock_1_9_1a"] = true

module ALBERT_CG
  BATTLE_FORMATION_LOCK_VERSION = "1.9.1a"
  BATTLE_POSITION_CHANGE_ENABLED = false

  def self.apply_solo_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.9.1a"
  end
end

#==============================================================================
# ■ Window_ActorCommand
#------------------------------------------------------------------------------
# 從人物與三隻寵物的指令中移除「移動」。
#==============================================================================
class Window_ActorCommand
  alias albert_cg_v191_formation_lock_setup setup
  def setup(actor)
    albert_cg_v191_formation_lock_setup(actor)
    cg_v191_remove_position_commands
  end

  def cg_v191_remove_position_commands
    @commands = [] if @commands == nil
    @cg_command_types = [] if @cg_command_types == nil

    indexes = []
    for i in 0...@commands.size
      type = @cg_command_types[i]
      text = @commands[i].to_s
      if type == :move || type == :swap || type == :swap_pair ||
         text == "移動" || text == "換位" || text == "交換位置"
        indexes.push(i)
      end
    end

    indexes.reverse.each do |index|
      @commands.delete_at(index)
      @cg_command_types.delete_at(index) if index < @cg_command_types.size
    end

    # RGSS2 使用 Ruby 1.8，Window 物件不保證提供
    # Object#instance_variable_defined?。未定義的 instance variable 直接讀取
    # 只會得到 nil，因此以 nil 判斷取代，避免按下 Fight 時啟動失敗。
    if @cg_v058_enabled != nil
      @cg_v058_enabled.delete(:move)
      @cg_v058_enabled.delete(:swap)
      @cg_v058_enabled.delete(:swap_pair)
    end

    @item_max = @commands.size
    if respond_to?(:cg_v182_reset_sidecar)
      cg_v182_reset_sidecar
    else
      create_contents if respond_to?(:create_contents)
      refresh
    end

    if @item_max <= 0
      self.index = -1
    elsif self.index == nil || self.index < 0 || self.index >= @item_max
      self.index = 0
    end
  end
end

#==============================================================================
# ■ Game_BattleAction
#------------------------------------------------------------------------------
# 即使舊補丁嘗試保存移動／交換，也改成待命，避免建立特殊位置行動。
#==============================================================================
class Game_BattleAction
  def cg_set_move_slot(row, column)
    clear
    @kind = 0
    @basic = 3
  end

  def cg_set_swap_pet(pet_id)
    clear
    @kind = 0
    @basic = 3
  end
end

#==============================================================================
# ■ Scene_Battle
#------------------------------------------------------------------------------
# 封鎖所有戰鬥中位置變更入口。前後排資料仍照常存在並參與判定。
#==============================================================================
class Scene_Battle < Scene_Base
  def cg_move_entries
    return []
  end

  def cg_start_move_command
    Sound.play_buzzer
    if respond_to?(:cg_restore_actor_command_after_popup)
      cg_restore_actor_command_after_popup
    elsif @actor_command_window != nil
      @actor_command_window.visible = true
      @actor_command_window.active = true
    end
  end

  def cg_execute_move_slot
    return
  end

  def cg_execute_swap_pet
    return
  end
end
