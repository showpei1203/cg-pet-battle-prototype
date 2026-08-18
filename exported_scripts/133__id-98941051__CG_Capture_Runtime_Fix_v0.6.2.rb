# RMVX_SCRIPT_INDEX: 133
# RMVX_SCRIPT_ID: 98941051
# RMVX_SCRIPT_NAME: CG Capture Runtime Fix v0.6.2
# RMVX_SOURCE_SHA256: 9a04e15ab4947d3f19a7a978644317079d21e399551ec4d0e2d4700c4021bd62

#==============================================================================
# ** ALBERT CG 捕捉執行期修正
#------------------------------------------------------------------------------
#  版本：v0.6.2
#  引擎：RPG Maker VX／RGSS2
#  前置：CG Capture Core v0.6.1
#------------------------------------------------------------------------------
# 【用途】
#  修正封印卡在戰鬥物品視窗被判定為不可使用，以及人物「捕捉」指令
#  因捕捉卡初始化或測試敵人物種資料不同步而錯誤變成禁用色的問題。
#
# 【正式規則】
#  - 只有 PRIMARY_PET_HANDLER_ACTOR_ID 指定的主角能使用捕捉。
#  - 封印卡數量大於 0，且場上至少有一名可捕捉敵人時，「捕捉」可用。
#  - 戰鬥物品視窗中的封印卡只依持有數量判定，不再被 VX 原始 Scope
#    或 Occasion 判定錯誤封鎖。
#  - 捕捉目標仍必須具備 <cg_species: ActorID>，或存在於本原型的測試
#    敵人物種後備表中。
#  - 測試專案第一次進入戰鬥時，若尚未執行過測試封印卡贈送，會補發
#    CAPTURE_DEMO_CARD_COUNT 張；已領取或已用完時不會無限補充。
#
# 【測試敵人物種後備表】
#    Enemy 600 → Actor 100（妙蛙種子）
#    Enemy 603 → Actor 103（小火龍）
#    Enemy 606 → Actor 106（傑尼龜）
#
# 【事件指令】
#    cg_give_capture_cards(10)
#
# 【腳本位置】
#  請放在 CG Capture Core v0.6.1 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_CaptureRuntimeFix"] = true

module ALBERT_CG
  CAPTURE_RUNTIME_FIX_VERSION = "0.6.2"

  CAPTURE_DEMO_SPECIES_BY_ENEMY_ID = {
    600 => 100,
    603 => 103,
    606 => 106
  }

  def self.cg_normalize_capture_card
    return nil if $data_items == nil
    card = $data_items[CAPTURE_ITEM_ID]
    return nil if card == nil
    # 單體敵人 Scope 可讓 VX 及其他物品視窗腳本明確知道此物品有目標。
    # 實際目標選擇仍由 CG Capture Core 接管。
    card.scope = 1
    card.occasion = 1
    card.consumable = true
    return card
  end

  def self.cg_ensure_demo_capture_cards_for_battle
    return 0 if $game_party == nil
    return 0 unless defined?(AUTO_BOOTSTRAP_DEMO) && AUTO_BOOTSTRAP_DEMO
    card = cg_normalize_capture_card
    return 0 if card == nil
    given = $game_party.instance_variable_get(:@cg_capture_demo_cards_given)
    unless given
      give_capture_cards(CAPTURE_DEMO_CARD_COUNT)
      $game_party.instance_variable_set(:@cg_capture_demo_cards_given, true)
    end
    return $game_party.item_number(card)
  end
end

#==============================================================================
# ■ Game_Enemy
#==============================================================================
class Game_Enemy < Game_Battler
  alias albert_cg_v062_capture_species_id cg_capture_species_id
  def cg_capture_species_id
    value = albert_cg_v062_capture_species_id.to_i
    return value if value > 0
    data = enemy
    enemy_id = data == nil ? 0 : data.id.to_i
    fallback = ALBERT_CG::CAPTURE_DEMO_SPECIES_BY_ENEMY_ID[enemy_id]
    return fallback == nil ? 0 : fallback.to_i
  end
end

#==============================================================================
# ■ Window_Item
#==============================================================================
class Window_Item < Window_Selectable
  alias albert_cg_v062_capture_item_enable enable?
  def enable?(item)
    if $game_temp != nil && $game_temp.in_battle &&
       item != nil && item.is_a?(RPG::Item) &&
       item.id.to_i == ALBERT_CG::CAPTURE_ITEM_ID
      return false if $game_party == nil
      return $game_party.item_number(item) > 0
    end
    return albert_cg_v062_capture_item_enable(item)
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  alias albert_cg_v062_capture_load_database load_database
  def load_database
    albert_cg_v062_capture_load_database
    ALBERT_CG.cg_normalize_capture_card
    $data_system.game_title = "CG Pet Battle Prototype v0.6.2" if $data_system != nil
  end

  alias albert_cg_v062_capture_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v062_capture_load_bt_database
    ALBERT_CG.cg_normalize_capture_card
    $data_system.game_title = "CG Pet Battle Prototype v0.6.2" if $data_system != nil
  end
end

#==============================================================================
# ■ Scene_Battle
#==============================================================================
class Scene_Battle < Scene_Base
  alias albert_cg_v062_capture_start start
  def start
    ALBERT_CG.cg_normalize_capture_card
    ALBERT_CG.cg_ensure_demo_capture_cards_for_battle
    albert_cg_v062_capture_start
  end

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

  def cg_any_capturable_enemy?
    return !cg_capture_candidate_enemies.empty?
  end

  def cg_capture_command_available?(actor = nil)
    actor = @active_battler if actor == nil
    return false if actor == nil
    return false unless actor.id.to_i == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    if actor.respond_to?(:cg_battle_pet?) && actor.cg_battle_pet?
      return false
    end
    return false if cg_capture_card_count <= 0
    return !cg_capture_candidate_enemies.empty?
  end
end

#==============================================================================
# ■ ALBERT_CG 測試
#==============================================================================
module ALBERT_CG
  def self.run_capture_runtime_fix_test
    card = cg_normalize_capture_card
    raise "CG v0.6.2：找不到封印卡" if card == nil
    raise "CG v0.6.2：封印卡 Scope 不是單體敵人" unless card.scope.to_i == 1
    raise "CG v0.6.2：封印卡 Occasion 錯誤" unless card.occasion.to_i == 1
    for pair in CAPTURE_DEMO_SPECIES_BY_ENEMY_ID
      enemy_id = pair[0]
      actor_id = pair[1]
      raise "CG v0.6.2：缺少測試敵人 #{enemy_id}" if $data_enemies[enemy_id] == nil
      raise "CG v0.6.2：缺少物種 Actor #{actor_id}" if $data_actors[actor_id] == nil
    end
    p "CG v0.6.2 捕捉執行期資料測試通過" if DEBUG_MESSAGE
    return true
  end
end

class Game_Interpreter
  def cg_capture_runtime_fix_test
    return ALBERT_CG.run_capture_runtime_fix_test
  end
end
