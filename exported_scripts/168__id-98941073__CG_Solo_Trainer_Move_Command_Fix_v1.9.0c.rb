# RMVX_SCRIPT_INDEX: 168
# RMVX_SCRIPT_ID: 98941073
# RMVX_SCRIPT_NAME: CG Solo Trainer Move Command Fix v1.9.0c
# RMVX_SOURCE_SHA256: b54335288afb4fdd6a756902720047445e6d3c069bdace1afcd735d248a98e67

#==============================================================================
# ■ CG Solo Trainer Move Command Fix v1.9.0c
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【修正內容】
#  1. 最終攔截所有「移動」指令，停用舊 PairedMove 腳本的單一配對
#     自動交換流程。主角不會再一按移動就自動與寵物 1 交換。
#  2. 三隻主角寵物都使用同一套移動／換位選單，不再只有寵物 1
#     能執行移動。
#  3. Popup 開啟後必須等玩家放開確認鍵，再接受下一次確認，避免
#     同一個按鍵同時開啟並選中第一項。
#  4. 最終補正三隻主角寵物的「移動」指令存在且可用。
#
# 【放置位置】
#  CG Solo Trainer Input Fix v1.9.0b 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_SoloTrainerMoveCommandFix_1_9_0c"] = true

module ALBERT_CG
  SOLO_TRAINER_MOVE_COMMAND_FIX_VERSION = "1.9.0c"

  def self.apply_solo_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.9.0c"
  end
end

#==============================================================================
# ■ Window_ActorCommand
#------------------------------------------------------------------------------
# 最終保證每一隻主角攜帶寵物都具有「移動」指令。舊腳本曾將移動
# 綁定到單一主人／寵物配對，這裡只保留目前 Solo Trainer 規則。
#==============================================================================
class Window_ActorCommand
  alias albert_cg_v190c_move_command_setup setup
  def setup(actor)
    albert_cg_v190c_move_command_setup(actor)
    return if actor == nil

    is_solo_pet = false
    if $game_party != nil &&
       $game_party.respond_to?(:cg_v190a_solo_pet?)
      is_solo_pet = $game_party.cg_v190a_solo_pet?(actor)
    elsif actor.respond_to?(:cg_battle_pet?)
      is_solo_pet = actor.cg_battle_pet?
    end

    if is_solo_pet
      @commands = [] if @commands == nil
      @cg_command_types = [] if @cg_command_types == nil
      unless @cg_command_types.include?(:move)
        @commands.push("移動")
        @cg_command_types.push(:move)
      end
    end

    # 三寵物全數在場，本專案不再使用戰鬥中「換寵」。
    if @cg_command_types != nil
      loop do
        index = @cg_command_types.index(:switch_pet)
        break if index == nil
        @cg_command_types.delete_at(index)
        @commands.delete_at(index) if @commands != nil
      end
    end

    @item_max = @commands == nil ? 0 : @commands.size
    create_contents if respond_to?(:create_contents)
    refresh
    self.index = 0 if @item_max > 0 &&
      (self.index == nil || self.index < 0 || self.index >= @item_max)
  end
end

#==============================================================================
# ■ Scene_Battle
#==============================================================================
class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # ● 最終攔截「移動」
  #--------------------------------------------------------------------------
  # 不能再交給舊的 PairedMove_ExecutionFix。舊腳本認為每名人物只有
  # 一隻配對寵物，因此會直接把第一個配對對象保存為換位行動。
  alias albert_cg_v190c_update_actor_command_selection \
    update_actor_command_selection
  def update_actor_command_selection
    if @actor_command_window != nil && @actor_command_window.active &&
       @active_battler != nil && Input.trigger?(Input::C) &&
       @actor_command_window.respond_to?(:cg_command_type) &&
       @actor_command_window.cg_command_type == :move
      if @actor_command_window.respond_to?(:cg_command_enabled?) &&
         !@actor_command_window.cg_command_enabled?
        Sound.play_buzzer
        return
      end
      Sound.play_decision
      cg_start_move_command
      return
    end
    albert_cg_v190c_update_actor_command_selection
  end

  #--------------------------------------------------------------------------
  # ● 指令開始時刷新「移動」可用性
  #--------------------------------------------------------------------------
  alias albert_cg_v190c_start_actor_command_selection \
    start_actor_command_selection
  def start_actor_command_selection
    result = albert_cg_v190c_start_actor_command_selection
    if @actor_command_window != nil && @active_battler != nil &&
       @actor_command_window.respond_to?(:cg_set_command_enabled) &&
       @actor_command_window.respond_to?(:cg_command_types) &&
       @actor_command_window.cg_command_types != nil &&
       @actor_command_window.cg_command_types.include?(:move)
      enabled = !cg_move_entries.empty?
      @actor_command_window.cg_set_command_enabled(:move, enabled)
    end
    return result
  end

  #--------------------------------------------------------------------------
  # ● Popup：等待確認鍵真正放開
  #--------------------------------------------------------------------------
  # 以「放開後再次按下」取代固定等待兩幀。玩家若按鍵時間稍長，固定
  # 兩幀仍可能把同一個確認輸入帶進子選單。
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

    # 至少顯示兩幀，並等待開啟選單的確認鍵放開。
    guard_frames = 0
    loop do
      update_basic
      window.update
      guard_frames += 1
      released = !Input.press?(Input::C)
      break if guard_frames >= 2 && released
      break if guard_frames >= 60
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
