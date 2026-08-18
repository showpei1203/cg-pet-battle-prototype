# RMVX_SCRIPT_INDEX: 134
# RMVX_SCRIPT_ID: 98941052
# RMVX_SCRIPT_NAME: CG Capture Availability Fix v0.6.3
# RMVX_SOURCE_SHA256: 2d6caefb801e2ec5ff1edbce63ff66a0b6cad7b44137806b9f80f035910f311d

#==============================================================================
# ** ALBERT CG 捕捉可用性最終修正
#------------------------------------------------------------------------------
#  版本：v0.6.3
#  引擎：RPG Maker VX／RGSS2
#  前置：CG Capture Core v0.6.1、CG Capture Runtime Fix v0.6.2
#------------------------------------------------------------------------------
# 【用途】
#  修正人物指令「捕捉」與戰鬥物品「初級封印卡」仍被錯誤判定為
#  不可使用的問題。v0.6.2 雖然修正了 Scope 與 Window_Item，但實機
#  仍可能因測試封印卡沒有真正進入隊伍背包，或敵人判定讀到不同資料
#  來源，使兩個入口同時變成禁用色。
#
# 【本版規則】
#  1. 原型測試專案每個新存檔第一次進入戰鬥時，若背包沒有封印卡，
#     會可靠地補發 CAPTURE_DEMO_CARD_COUNT 張。
#  2. Window_Item 與 Game_Party#item_can_use? 對封印卡使用相同規則：
#     戰鬥中、持有數量大於 0，即可選擇。
#  3. 主角「捕捉」指令的可用性只依下列條件：
#       - 使用者是 PRIMARY_PET_HANDLER_ACTOR_ID
#       - 持有封印卡
#       - 場上存在至少一名可捕捉的存活敵人
#  4. 測試敵人會直接以 Game_Enemy 的 @enemy_id 查詢後備物種表，
#     不再依賴 RPG::Enemy#id 是否能在該執行環境正常讀取。
#  5. 正式遊戲若不希望自動補發測試卡，將 AUTO_BOOTSTRAP_DEMO 設為
#     false 即可；正式取得封印卡仍可使用事件指令：
#       cg_give_capture_cards(數量)
#
# 【腳本位置】
#  放在 CG Capture Runtime Fix v0.6.2 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_CaptureAvailabilityFix"] = true

module ALBERT_CG
  CAPTURE_AVAILABILITY_FIX_VERSION = "0.6.3"

  #--------------------------------------------------------------------------
  # ● 可靠取得測試封印卡
  #--------------------------------------------------------------------------
  def self.cg_prepare_capture_inventory_v063
    return 0 if $game_party == nil
    card = respond_to?(:cg_normalize_capture_card) ?
      cg_normalize_capture_card : capture_card
    return 0 if card == nil

    count = $game_party.item_number(card).to_i
    demo_mode = defined?(AUTO_BOOTSTRAP_DEMO) && AUTO_BOOTSTRAP_DEMO
    granted = $game_party.instance_variable_get(:@cg_capture_cards_given_v063)

    if demo_mode && count <= 0 && !granted
      $game_party.gain_item(card, CAPTURE_DEMO_CARD_COUNT)
      $game_party.instance_variable_set(:@cg_capture_cards_given_v063, true)
      count = $game_party.item_number(card).to_i
    end
    return count
  end

  #--------------------------------------------------------------------------
  # ● 取得敵人的真實資料庫 ID
  #--------------------------------------------------------------------------
  def self.cg_runtime_enemy_id(enemy)
    return 0 if enemy == nil
    value = enemy.instance_variable_get(:@enemy_id)
    return value.to_i if value != nil && value.to_i > 0
    data = enemy.respond_to?(:enemy) ? enemy.enemy : nil
    return data.id.to_i if data != nil && data.respond_to?(:id)
    return 0
  end
end

#==============================================================================
# ■ Game_Party
#==============================================================================
class Game_Party < Game_Unit
  alias albert_cg_v063_capture_item_can_use item_can_use?
  def item_can_use?(item)
    if item != nil && item.is_a?(RPG::Item) &&
       item.id.to_i == ALBERT_CG::CAPTURE_ITEM_ID
      return false if $game_temp == nil || !$game_temp.in_battle
      return item_number(item).to_i > 0
    end
    return albert_cg_v063_capture_item_can_use(item)
  end
end

#==============================================================================
# ■ Window_Item
#==============================================================================
class Window_Item < Window_Selectable
  alias albert_cg_v063_capture_enable enable?
  def enable?(item)
    if item != nil && item.is_a?(RPG::Item) &&
       item.id.to_i == ALBERT_CG::CAPTURE_ITEM_ID
      return false if $game_party == nil
      return $game_party.item_number(item).to_i > 0
    end
    return albert_cg_v063_capture_enable(item)
  end
end

#==============================================================================
# ■ Game_Enemy
#==============================================================================
class Game_Enemy < Game_Battler
  # 使用真實 @enemy_id 作為後備物種查詢來源。
  def cg_capture_species_id
    text = cg_capture_note.to_s
    return $1.to_i if text =~ /<cg_species\s*:\s*(\d+)\s*>/i
    return $1.to_i if text =~ /<cg_capture_species\s*:\s*(\d+)\s*>/i

    enemy_id = ALBERT_CG.cg_runtime_enemy_id(self)
    table = defined?(ALBERT_CG::CAPTURE_DEMO_SPECIES_BY_ENEMY_ID) ?
      ALBERT_CG::CAPTURE_DEMO_SPECIES_BY_ENEMY_ID : {}
    value = table[enemy_id]
    return value == nil ? 0 : value.to_i
  end

  def cg_capturable?
    return false unless exist?
    return false if cg_uncapturable?
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
  alias albert_cg_v063_capture_start start
  def start
    result = albert_cg_v063_capture_start
    ALBERT_CG.cg_prepare_capture_inventory_v063
    return result
  end

  # 每次讀取數量時先完成一次可靠初始化，避免指令建立時仍為 0。
  def cg_capture_card_count
    ALBERT_CG.cg_prepare_capture_inventory_v063
    item = ALBERT_CG.capture_card
    return 0 if item == nil || $game_party == nil
    return $game_party.item_number(item).to_i
  end

  # 不依賴其他舊快取，直接讀取當前戰場。
  def cg_capture_candidate_enemies
    result = []
    return result if $game_troop == nil
    for enemy in $game_troop.members
      next if enemy == nil
      next unless enemy.respond_to?(:cg_capturable?)
      result.push(enemy) if enemy.cg_capturable?
    end
    return result
  end

  def cg_capture_command_available?(actor = nil)
    actor = @active_battler if actor == nil
    return false if actor == nil
    return false unless actor.id.to_i == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    return false if actor.respond_to?(:cg_battle_pet?) && actor.cg_battle_pet?
    return false if cg_capture_card_count <= 0
    return !cg_capture_candidate_enemies.empty?
  end

  # 物品視窗開啟後再刷新一次，確保補發後立刻顯示正常顏色與數量。
  alias albert_cg_v063_capture_start_item_selection start_item_selection
  def start_item_selection
    ALBERT_CG.cg_prepare_capture_inventory_v063
    result = albert_cg_v063_capture_start_item_selection
    @item_window.refresh if @item_window != nil
    return result
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  alias albert_cg_v063_capture_load_database load_database
  def load_database
    albert_cg_v063_capture_load_database
    ALBERT_CG.cg_normalize_capture_card if ALBERT_CG.respond_to?(:cg_normalize_capture_card)
    $data_system.game_title = "CG Pet Battle Prototype v0.6.3" if $data_system != nil
  end

  alias albert_cg_v063_capture_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v063_capture_load_bt_database
    ALBERT_CG.cg_normalize_capture_card if ALBERT_CG.respond_to?(:cg_normalize_capture_card)
    $data_system.game_title = "CG Pet Battle Prototype v0.6.3" if $data_system != nil
  end
end

#==============================================================================
# ■ 測試指令
#==============================================================================
module ALBERT_CG
  def self.run_capture_availability_test_v063
    card = capture_card
    raise "CG v0.6.3：找不到封印卡" if card == nil
    raise "CG v0.6.3：封印卡 Scope 錯誤" unless card.scope.to_i == 1
    for pair in CAPTURE_DEMO_SPECIES_BY_ENEMY_ID
      enemy_id = pair[0]
      actor_id = pair[1]
      raise "CG v0.6.3：缺少 Enemy #{enemy_id}" if $data_enemies[enemy_id] == nil
      raise "CG v0.6.3：缺少 Actor #{actor_id}" if $data_actors[actor_id] == nil
    end
    p "CG v0.6.3 捕捉可用性資料測試通過" if DEBUG_MESSAGE
    return true
  end
end

class Game_Interpreter
  def cg_capture_availability_test
    return ALBERT_CG.run_capture_availability_test_v063
  end
end
