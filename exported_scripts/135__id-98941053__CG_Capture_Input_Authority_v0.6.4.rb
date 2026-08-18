# RMVX_SCRIPT_INDEX: 135
# RMVX_SCRIPT_ID: 98941053
# RMVX_SCRIPT_NAME: CG Capture Input Authority v0.6.4
# RMVX_SOURCE_SHA256: 970063cdb3dab1def393624f5e4fefbee3b976b7862ec31ac0e23b17c818f23a

#==============================================================================
# ** ALBERT CG 捕捉輸入權威修正
#------------------------------------------------------------------------------
#  版本：v0.6.4
#  引擎：RPG Maker VX／RGSS2
#  前置：CG Capture Core v0.6.1～v0.6.3
#------------------------------------------------------------------------------
# 【用途】
#  修正背包確實持有封印卡，但人物「捕捉」指令與物品中的封印卡仍被
#  判定為不可使用的問題。
#
# 【原因】
#  舊版在三個不同位置各自判定可用性：人物指令、物品視窗、敵人候補。
#  其中任何一處讀到不同步的物種資料或舊狀態，就會把整個入口關閉。
#
# 【本版規則】
#  1. 主角持有至少一張封印卡，且場上仍有存活敵人時，「捕捉」可用。
#  2. 戰鬥物品視窗中的封印卡只依「戰鬥中＋持有數量」判定可用。
#  3. 從物品視窗確認封印卡時，直接建立捕捉行動並開啟敵人游標，
#     不再經過 VX 原始物品 Scope 判定。
#  4. 捕捉選擇階段可游標選擇所有存活敵人；真正執行時仍會檢查該敵人
#     是否有物種資料或 <cg_uncapturable>。
#  5. 測試敵人的物種可由 Note、Enemy ID 或名稱三種來源取得。
#
# 【腳本位置】
#  放在 CG Capture Availability Fix v0.6.3 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_CaptureInputAuthority"] = true

module ALBERT_CG
  CAPTURE_INPUT_AUTHORITY_VERSION = "0.6.4"

  #--------------------------------------------------------------------------
  # ● 判斷物品是否為封印卡
  #--------------------------------------------------------------------------
  def self.cg_capture_card_item?(item)
    return false if item == nil
    return false unless item.is_a?(RPG::Item)
    return true if item.respond_to?(:id) &&
      item.id.to_i == CAPTURE_ITEM_ID.to_i
    note = item.respond_to?(:note) ? item.note.to_s : ""
    return true if note =~ /<cg_capture_card\s*:/i
    return item.respond_to?(:name) && item.name.to_s == "初級封印卡"
  end

  #--------------------------------------------------------------------------
  # ● 依敵人名稱取得原型物種後備值
  #--------------------------------------------------------------------------
  CAPTURE_DEMO_SPECIES_BY_NAME = {
    "妙蛙種子" => 100,
    "小火龍"   => 103,
    "傑尼龜"   => 106
  }
end

#==============================================================================
# ■ Game_Party
#==============================================================================
class Game_Party < Game_Unit
  alias albert_cg_v064_capture_item_can_use item_can_use?
  def item_can_use?(item)
    if ALBERT_CG.cg_capture_card_item?(item)
      return false if $game_temp == nil || !$game_temp.in_battle
      return item_number(item).to_i > 0
    end
    return albert_cg_v064_capture_item_can_use(item)
  end
end

#==============================================================================
# ■ Window_Item
#==============================================================================
class Window_Item < Window_Selectable
  alias albert_cg_v064_capture_enable enable?
  def enable?(item)
    if ALBERT_CG.cg_capture_card_item?(item)
      return false if $game_party == nil
      return $game_party.item_number(item).to_i > 0
    end
    return albert_cg_v064_capture_enable(item)
  end
end

#==============================================================================
# ■ Game_Enemy
#==============================================================================
class Game_Enemy < Game_Battler
  #--------------------------------------------------------------------------
  # ● 統一取得捕捉物種
  #--------------------------------------------------------------------------
  def cg_capture_species_id
    text = respond_to?(:cg_capture_note) ? cg_capture_note.to_s : ""
    return $1.to_i if text =~ /<cg_species\s*:\s*(\d+)\s*>/i
    return $1.to_i if text =~ /<cg_capture_species\s*:\s*(\d+)\s*>/i

    enemy_id = ALBERT_CG.respond_to?(:cg_runtime_enemy_id) ?
      ALBERT_CG.cg_runtime_enemy_id(self) : 0
    if defined?(ALBERT_CG::CAPTURE_DEMO_SPECIES_BY_ENEMY_ID)
      value = ALBERT_CG::CAPTURE_DEMO_SPECIES_BY_ENEMY_ID[enemy_id]
      return value.to_i if value != nil && value.to_i > 0
    end

    value = ALBERT_CG::CAPTURE_DEMO_SPECIES_BY_NAME[name.to_s]
    return value == nil ? 0 : value.to_i
  end

  #--------------------------------------------------------------------------
  # ● 是否可捕捉
  #--------------------------------------------------------------------------
  def cg_capturable?
    return false unless exist?
    return false if respond_to?(:cg_uncapturable?) && cg_uncapturable?
    species_id = cg_capture_species_id.to_i
    return false if species_id <= 0
    return false if $data_actors == nil || $data_actors[species_id] == nil
    return true
  end
end

#==============================================================================
# ■ Scene_Battle
#==============================================================================
class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # ● 取得所有存活敵人索引
  #--------------------------------------------------------------------------
  def cg_v064_alive_enemy_indices
    result = []
    return result if $game_troop == nil
    members = $game_troop.members
    for i in 0...members.size
      enemy = members[i]
      next if enemy == nil
      next unless enemy.exist?
      result.push(i)
    end
    return result
  end

  #--------------------------------------------------------------------------
  # ● 捕捉指令可用性
  #--------------------------------------------------------------------------
  def cg_capture_command_available?(actor = nil)
    actor = @active_battler if actor == nil
    return false if actor == nil
    return false unless actor.id.to_i == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    return false if actor.respond_to?(:cg_battle_pet?) && actor.cg_battle_pet?
    return false if cg_capture_card_count.to_i <= 0
    return !cg_v064_alive_enemy_indices.empty?
  end

  #--------------------------------------------------------------------------
  # ● 刷新捕捉指令顏色
  #--------------------------------------------------------------------------
  def cg_refresh_capture_command
    return if @actor_command_window == nil || @active_battler == nil
    return unless @actor_command_window.respond_to?(:cg_set_command_enabled)
    @actor_command_window.cg_set_command_enabled(:capture,
      cg_capture_command_available?(@active_battler))
  end

  alias albert_cg_v064_capture_start_actor_command start_actor_command_selection
  def start_actor_command_selection
    result = albert_cg_v064_capture_start_actor_command
    cg_refresh_capture_command
    return result
  end

  #--------------------------------------------------------------------------
  # ● 人物指令「捕捉」直接進入敵人選擇
  #--------------------------------------------------------------------------
  alias albert_cg_v064_capture_update_actor_command update_actor_command_selection
  def update_actor_command_selection
    if Input.trigger?(Input::C) && @active_battler != nil &&
       @actor_command_window != nil &&
       @actor_command_window.respond_to?(:cg_command_type) &&
       @actor_command_window.cg_command_type == :capture
      unless cg_capture_command_available?(@active_battler)
        Sound.play_buzzer
        cg_refresh_capture_command
        return
      end
      Sound.play_decision
      @active_battler.action.cg_set_capture
      @cg_capture_from_item = false
      cg_start_capture_target_selection
      return
    end
    albert_cg_v064_capture_update_actor_command
  end

  #--------------------------------------------------------------------------
  # ● 物品視窗確認封印卡時直接進入捕捉目標選擇
  #--------------------------------------------------------------------------
  alias albert_cg_v064_capture_update_item_selection update_item_selection
  def update_item_selection
    if @item_window != nil && @item_window.active && Input.trigger?(Input::C)
      selected = @item_window.item
      if ALBERT_CG.cg_capture_card_item?(selected)
        @item = selected
        $game_party.last_item_id = selected.id if selected.respond_to?(:id)
        unless @active_battler != nil &&
               @active_battler.id.to_i == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID &&
               $game_party.item_number(selected).to_i > 0 &&
               !cg_v064_alive_enemy_indices.empty?
          Sound.play_buzzer
          @item_window.active = true
          return
        end
        Sound.play_decision
        @active_battler.action.cg_set_capture
        @item_window.active = false
        @cg_capture_from_item = true
        cg_start_capture_target_selection
        return
      end
    end
    albert_cg_v064_capture_update_item_selection
  end

  #--------------------------------------------------------------------------
  # ● 直接建立捕捉目標選擇
  #--------------------------------------------------------------------------
  def cg_start_capture_target_selection
    @cg_capture_target_mode = true
    if cg_v064_alive_enemy_indices.empty?
      @cg_capture_target_mode = false
      Sound.play_buzzer
      if @cg_capture_from_item && @item_window != nil
        @item_window.visible = true
        @item_window.active = true
      else
        @actor_command_window.active = true if @actor_command_window != nil
      end
      return
    end
    cg_start_legal_enemy_target_selection
  end

  # 捕捉模式不套用近戰距離或舊物種候補篩選。
  alias albert_cg_v064_capture_legal_indices cg_legal_enemy_target_indices
  def cg_legal_enemy_target_indices
    if @cg_capture_target_mode
      return cg_v064_alive_enemy_indices
    end
    return albert_cg_v064_capture_legal_indices
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  alias albert_cg_v064_capture_load_database load_database
  def load_database
    albert_cg_v064_capture_load_database
    $data_system.game_title = "CG Pet Battle Prototype v0.6.4" if $data_system != nil
  end

  alias albert_cg_v064_capture_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v064_capture_load_bt_database
    $data_system.game_title = "CG Pet Battle Prototype v0.6.4" if $data_system != nil
  end
end

#==============================================================================
# ■ 測試指令
#==============================================================================
module ALBERT_CG
  def self.run_capture_input_test_v064
    card = capture_card
    raise "CG v0.6.4：找不到封印卡" if card == nil
    raise "CG v0.6.4：封印卡辨識失敗" unless cg_capture_card_item?(card)
    raise "CG v0.6.4：封印卡 Scope 錯誤" unless card.scope.to_i == 1
    p "CG v0.6.4 捕捉輸入資料測試通過" if DEBUG_MESSAGE
    return true
  end
end

class Game_Interpreter
  def cg_capture_input_test
    return ALBERT_CG.run_capture_input_test_v064
  end
end
