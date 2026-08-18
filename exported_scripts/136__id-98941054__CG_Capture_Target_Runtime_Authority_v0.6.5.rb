# RMVX_SCRIPT_INDEX: 136
# RMVX_SCRIPT_ID: 98941054
# RMVX_SCRIPT_NAME: CG Capture Target Runtime Authority v0.6.5
# RMVX_SOURCE_SHA256: 4c64d4d87f6b6347741bb3bb9af17a044fb386c24eb69cf1c4f31f8fdaf7e5a7

#==============================================================================
# ** ALBERT CG 捕捉目標與機率執行期權威修正
#------------------------------------------------------------------------------
#  版本：v0.6.5
#  引擎：RPG Maker VX／RGSS2
#  前置：CG Capture Core v0.6.1 ～ CG Capture Input Authority v0.6.4
#------------------------------------------------------------------------------
# 【用途】
#  修正捕捉目標視窗與人物行動提示視窗互相遮蓋，以及實機中敵人雖然
#  可以被游標選取，捕捉率卻固定顯示 0%，導致執行時被判定為不可捕捉、
#  封印卡也不會消耗的問題。
#
# 【問題原因】
#  1. 捕捉入口直接呼叫合法敵人選擇流程，沒有先隱藏右上角的人物行動
#     提示視窗，因此兩個 Window_Help 疊在一起。
#  2. 原型敵人使用 Tankentai 內建 Kaduki 圖像當佔位素材；部分執行環境
#     讀到的敵人名稱或資料庫 ID 與動態測試資料不同，使舊版只靠 Note、
#     Enemy ID 或顯示名稱時無法取得物種 Actor ID。
#  3. cg_capture_chance 在物種判定失敗時直接回傳 0，執行階段也會在消耗
#     封印卡之前取消，因此看起來像是「0% 所以卡片沒有被使用」。
#
# 【本版規則】
#  - 捕捉目標選擇開始時隱藏人物行動提示視窗，避免頂端視窗重疊。
#  - 物種辨識依序使用：敵人 Note、真實 @enemy_id、Battler 圖檔名稱、
#    敵人顯示名稱。
#  - 原型 Kaduki 圖檔後備對應：
#      $Actor12／Actor12 → Actor 100（妙蛙種子）
#      $Actor22／Actor22 → Actor 103（小火龍）
#      $Actor26／Actor26 → Actor 106（傑尼龜）
#  - 可捕捉敵人的成功率一定套用 5%～95% 限制，不會再顯示 0%。
#  - 捕捉模式的 Help Window 優先顯示物種名稱，而不是佔位敵人的舊名稱。
#  - 真正執行時仍會檢查敵人存活、禁止捕捉 Note、物種模板與封印卡數量。
#
# 【正式專案注意】
#  正式敵人請在 Note 設定：
#      <cg_species: ActorID>
#  Battler 圖檔後備表只供目前原型測試，不應取代正式資料設定。
#
# 【腳本位置】
#  放在 CG Capture Input Authority v0.6.4 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_CaptureTargetRuntimeAuthority"] = true

module ALBERT_CG
  CAPTURE_TARGET_RUNTIME_AUTHORITY_VERSION = "0.6.5"

  CAPTURE_DEMO_SPECIES_BY_BATTLER = {
    "$Actor12" => 100,
    "Actor12"  => 100,
    "$Actor22" => 103,
    "Actor22"  => 103,
    "$Actor26" => 106,
    "Actor26"  => 106
  }

  #--------------------------------------------------------------------------
  # ● 從 Note 取得物種 Actor ID
  #--------------------------------------------------------------------------
  def self.cg_capture_species_from_note(enemy)
    return 0 if enemy == nil
    data = enemy.respond_to?(:enemy) ? enemy.enemy : nil
    text = data != nil && data.respond_to?(:note) ? data.note.to_s : ""
    return $1.to_i if text =~ /<cg_species\s*:\s*(\d+)\s*>/i
    return $1.to_i if text =~ /<cg_capture_species\s*:\s*(\d+)\s*>/i
    return 0
  end

  #--------------------------------------------------------------------------
  # ● 從真實 Enemy ID 取得原型物種
  #--------------------------------------------------------------------------
  def self.cg_capture_species_from_enemy_id(enemy)
    return 0 if enemy == nil
    enemy_id = if respond_to?(:cg_runtime_enemy_id)
      cg_runtime_enemy_id(enemy).to_i
    else
      value = enemy.instance_variable_get(:@enemy_id)
      value == nil ? 0 : value.to_i
    end
    table = defined?(CAPTURE_DEMO_SPECIES_BY_ENEMY_ID) ?
      CAPTURE_DEMO_SPECIES_BY_ENEMY_ID : {}
    value = table[enemy_id]
    return value == nil ? 0 : value.to_i
  end

  #--------------------------------------------------------------------------
  # ● 從 Tankentai Battler 圖檔名稱取得原型物種
  #--------------------------------------------------------------------------
  def self.cg_capture_species_from_battler(enemy)
    return 0 if enemy == nil
    data = enemy.respond_to?(:enemy) ? enemy.enemy : nil
    name = nil
    if data != nil && data.respond_to?(:battler_name)
      name = data.battler_name
    end
    if name == nil || name.to_s.empty?
      name = enemy.instance_variable_get(:@battler_name)
    end
    value = CAPTURE_DEMO_SPECIES_BY_BATTLER[name.to_s]
    return value == nil ? 0 : value.to_i
  end

  #--------------------------------------------------------------------------
  # ● 從顯示名稱取得原型物種
  #--------------------------------------------------------------------------
  def self.cg_capture_species_from_name(enemy)
    return 0 if enemy == nil
    table = defined?(CAPTURE_DEMO_SPECIES_BY_NAME) ?
      CAPTURE_DEMO_SPECIES_BY_NAME : {}
    value = table[enemy.name.to_s]
    return value == nil ? 0 : value.to_i
  end

  #--------------------------------------------------------------------------
  # ● 捕捉物種的唯一權威入口
  #--------------------------------------------------------------------------
  def self.cg_resolve_capture_species_id(enemy)
    value = cg_capture_species_from_note(enemy)
    return value if value > 0
    value = cg_capture_species_from_enemy_id(enemy)
    return value if value > 0
    value = cg_capture_species_from_battler(enemy)
    return value if value > 0
    value = cg_capture_species_from_name(enemy)
    return value if value > 0
    return 0
  end

  #--------------------------------------------------------------------------
  # ● 取得捕捉模式應顯示的物種名稱
  #--------------------------------------------------------------------------
  def self.cg_capture_species_name(enemy)
    species_id = cg_resolve_capture_species_id(enemy)
    if species_id > 0 && $data_actors != nil && $data_actors[species_id] != nil
      return $data_actors[species_id].name.to_s
    end
    return enemy == nil ? "" : enemy.name.to_s
  end
end

#==============================================================================
# ■ Game_Enemy
#==============================================================================
class Game_Enemy < Game_Battler
  #--------------------------------------------------------------------------
  # ● 統一取得物種 Actor ID
  #--------------------------------------------------------------------------
  def cg_capture_species_id
    return ALBERT_CG.cg_resolve_capture_species_id(self)
  end

  #--------------------------------------------------------------------------
  # ● 是否可捕捉
  #--------------------------------------------------------------------------
  def cg_capturable?
    return false unless exist?
    return false if respond_to?(:cg_uncapturable?) && cg_uncapturable?
    species_id = cg_capture_species_id.to_i
    return false if species_id <= 0
    return false if $data_actors == nil
    return false if $data_actors[species_id] == nil
    return true
  end

  #--------------------------------------------------------------------------
  # ● 捕捉率
  #--------------------------------------------------------------------------
  def cg_capture_chance(user = nil, card = nil)
    return 0 unless cg_capturable?

    max_value = maxhp.to_i
    hp_value = hp.to_i
    missing_rate = if max_value <= 0
      0
    else
      100 - hp_value * 100 / max_value
    end
    missing_rate = 0 if missing_rate < 0
    missing_rate = 100 if missing_rate > 100

    hp_bonus = missing_rate * ALBERT_CG::CAPTURE_HP_BONUS_MAX / 100
    state_bonus = respond_to?(:cg_capture_status_bonus) ?
      cg_capture_status_bonus.to_i : 0
    card_bonus = card != nil && card.respond_to?(:cg_capture_card_bonus) ?
      card.cg_capture_card_bonus.to_i : 0
    base_rate = respond_to?(:cg_capture_base_rate) ?
      cg_capture_base_rate.to_i : 5

    value = base_rate + hp_bonus + state_bonus + card_bonus
    return ALBERT_CG.cg_capture_clamp(value)
  end
end

#==============================================================================
# ■ Scene_Battle
#==============================================================================
class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # ● 開始捕捉目標選擇前隱藏右上角人物行動提示
  #--------------------------------------------------------------------------
  alias albert_cg_v065_capture_start_target cg_start_capture_target_selection
  def cg_start_capture_target_selection
    cg_hide_phase_window if respond_to?(:cg_hide_phase_window)
    result = albert_cg_v065_capture_start_target
    if @help_window2 != nil
      @help_window2.x = 0
      @help_window2.y = 0
      @help_window2.z = 1000
    end
    return result
  end

  #--------------------------------------------------------------------------
  # ● 捕捉模式 Help Window
  #--------------------------------------------------------------------------
  alias albert_cg_v065_capture_help_text cg_target_help_text
  def cg_target_help_text(enemy)
    unless @cg_capture_target_mode
      return albert_cg_v065_capture_help_text(enemy)
    end
    return "" if enemy == nil

    text = ALBERT_CG.cg_capture_species_name(enemy)
    if ALBERT_CG::SHOW_GRID_LABELS && enemy.respond_to?(:cg_grid_label)
      text += " [" + enemy.cg_grid_label.to_s + "]"
    end

    if enemy.respond_to?(:cg_capturable?) && enemy.cg_capturable?
      rate = enemy.cg_capture_chance(@active_battler, cg_capture_card)
      text += "　捕捉率 " + rate.to_s + "%"
    else
      text += "　不可捕捉"
    end
    text += "　封印卡 " + cg_capture_card_count.to_s
    return text
  end

  #--------------------------------------------------------------------------
  # ● 捕捉行動執行前重新以權威物種判定目標
  #--------------------------------------------------------------------------
  alias albert_cg_v065_capture_execute cg_execute_capture_action
  def cg_execute_capture_action
    target = cg_capture_target_from_action
    if target != nil && target.exist?
      species_id = ALBERT_CG.cg_resolve_capture_species_id(target)
      if species_id <= 0
        cg_show_special_action_text("捕捉失敗：找不到目標的物種設定。")
        return
      end
    end
    albert_cg_v065_capture_execute
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  alias albert_cg_v065_capture_load_database load_database
  def load_database
    albert_cg_v065_capture_load_database
    $data_system.game_title = "CG Pet Battle Prototype v0.6.5" if $data_system != nil
  end

  alias albert_cg_v065_capture_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v065_capture_load_bt_database
    $data_system.game_title = "CG Pet Battle Prototype v0.6.5" if $data_system != nil
  end
end

#==============================================================================
# ■ 測試指令
#==============================================================================
module ALBERT_CG
  def self.run_capture_target_runtime_test_v065
    for pair in CAPTURE_DEMO_SPECIES_BY_BATTLER
      name = pair[0]
      actor_id = pair[1]
      raise "CG v0.6.5：Battler 後備值錯誤 #{name}" if actor_id.to_i <= 0
      raise "CG v0.6.5：缺少物種 Actor #{actor_id}" if
        $data_actors == nil || $data_actors[actor_id] == nil
    end
    p "CG v0.6.5 捕捉目標資料測試通過" if DEBUG_MESSAGE
    return true
  end
end

class Game_Interpreter
  def cg_capture_target_runtime_test
    return ALBERT_CG.run_capture_target_runtime_test_v065
  end
end
