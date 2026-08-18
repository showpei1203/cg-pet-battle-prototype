# RMVX_SCRIPT_INDEX: 115
# RMVX_SCRIPT_ID: 91000011
# RMVX_SCRIPT_NAME: CG Config v0.5.13
# RMVX_SOURCE_SHA256: 941328f56753eae0d21b50bef98938e558803d8cef645fa9ce45bc833aecee15

#==============================================================================
# ** ALBERT CG 原型專案設定
#------------------------------------------------------------------------------
#  專案：魔力寶貝式寵物戰鬥原型
#  引擎：RPG Maker VX／RGSS2
#  版本：v0.5.13
#------------------------------------------------------------------------------
# 【放置位置】
#  請放在 Tankentai SBS 3.3 核心下方、所有 ALBERT CG 腳本上方。
#
# 【用途】
#  集中管理寵物個體、三列戰場座標、測試資料與除錯開關。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_Config"] = true


#------------------------------------------------------------------------------
# ■ 正式戰鬥隊伍容量
#------------------------------------------------------------------------------
#  正式戰鬥改為「主角＋3 隻自由寵物」，合計最多 4 名戰鬥成員。
#  隊友與隊友固定寵物系統已於 v1.9.0 停用。
#------------------------------------------------------------------------------
if defined?(Game_Party)
  Game_Party.send(:remove_const, :MAX_MEMBERS) if
    Game_Party.const_defined?(:MAX_MEMBERS)
  Game_Party.const_set(:MAX_MEMBERS, 4)
end

if defined?(N01)
  N01.send(:remove_const, :MAX_MEMBER) if N01.const_defined?(:MAX_MEMBER)
  N01.const_set(:MAX_MEMBER, 4)
end

module ALBERT_CG
  VERSION = "0.5.13"

  PET_ACTOR_ID_START = 1000
  LAST_CREATED_PET_VARIABLE = 0

  DEFAULT_LOYALTY = 60
  DEFAULT_INJURY = 0
  DEFAULT_SKILL_SLOTS = 8
  GRADE_STAT_COUNT = 5
  GRADE_LOSS_MAX = 4

  # 所有 Clone 寵物都由主角管理。攜帶中的前三隻會直接參戰。
  # 舊版無主人或主人 ID 無效的寵物，會自動歸給此 Actor ID。
  PRIMARY_PET_HANDLER_ACTOR_ID = 1

  # v1.9.0 起不再使用隊友固定寵物；保留空 Hash 只供舊腳本相容。
  FIXED_PARTNER_PET_ACTORS = {}

  # 主角可攜帶並同時派出三隻 Clone 寵物。
  MAX_ACTIVE_PETS_PER_OWNER = 3
  MAX_ACTIVE_PETS = 3
  BATTLE_COLUMNS = 3
  AUTO_BOOTSTRAP_DEMO = true
  DEBUG_MESSAGE = true

  # 戰鬥指令無法使用時的文字色票。VX 預設 7 為灰色。
  # 同一人物本回合已安排過派寵／換寵／收回後，「換寵」會以此色顯示。
  DISABLED_COMMAND_COLOR_INDEX = 7

  # Three-column / two-row battlefield coordinates.
  # Actor side faces left. Front row is closer to the center.
  GRID_COLUMN_Y = [152, 218, 284]
  ACTOR_FRONT_X = 372
  ACTOR_BACK_X  = 452
  ENEMY_FRONT_X = 172
  ENEMY_BACK_X  = 92

  # Troop editor coordinates are interpreted using this midpoint.
  ENEMY_ROW_MID_X = (ENEMY_FRONT_X + ENEMY_BACK_X) / 2

  DEFAULT_HUMAN_ROW = :back
  DEFAULT_HUMAN_COLUMN = 1
  DEFAULT_PET_ROW = :front
  DEFAULT_PET_COLUMN = 1

  # true: show row/column in command phase and target help.
  SHOW_GRID_LABELS = true

  # 戰鬥換位使用 Tankentai 既有 RESET_POSITION 序列。
  # v0.5.6 保留 Sprite_Battler 位移同步，人物與寵物交換時兩邊都會播放。
  BATTLE_SLOT_MOVE_ACTION = "RESET_POSITION"
  BATTLE_SLOT_MOVE_WAIT = 20

  # 派出／收回寵物動畫。0 代表停用。
  # 目前使用 VX 內建 Rise1／Drop1，之後可替換成正式召喚動畫。
  PET_SUMMON_ANIMATION_ID = 43
  PET_RECALL_ANIMATION_ID = 45
  PET_SWITCH_ANIMATION_WAIT = 24

  DEMO_ACTOR_IDS = [100, 103, 106]
  DEMO_ENEMY_IDS = [600, 603, 606]
  DEMO_TROOP_ID = 609
end
