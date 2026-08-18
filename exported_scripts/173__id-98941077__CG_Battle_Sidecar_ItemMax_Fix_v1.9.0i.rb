# RMVX_SCRIPT_INDEX: 173
# RMVX_SCRIPT_ID: 98941077
# RMVX_SCRIPT_NAME: CG Battle Sidecar ItemMax Fix v1.9.0i
# RMVX_SOURCE_SHA256: 449b9135a4e1fc520f9fed21bdc2d589e8d54a12adaab8a9c34faa34e905254f

#==============================================================================
# ■ CG Battle Sidecar ItemMax Fix v1.9.0i
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【真正原因】
# Window_CG_BattleSidecarList 在呼叫 Window_Selectable#initialize 之前，
# 先把 @item_max 設為 entries.size；但 VX 原生 Window_Selectable#initialize
# 會再次把 @item_max 重設為 1。
#
# 因此移動候選其實可能已建立三至五項，畫面與游標卻永遠只承認一項。
# 這也解釋了為什麼寵物 2、3 自己的單一換位選項可用，而主角的多個
# 候選永遠只顯示第一隻寵物。
#
# 【修正】
# 1. 先呼叫 super 建立 Window，再把 @item_max 設回完整 entries 數量。
# 2. 每次 refresh 前重新同步 @item_max，避免後續清單內容被替換後失真。
# 3. 保留既有頭頂側掛、四項捲動、圓角卡片、滑入動畫與連線功能。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattleSidecarItemMaxFix_1_9_0i"] = true

module ALBERT_CG
  SOLO_TRAINER_SIDECAR_FIX_VERSION = "1.9.0i"

  def self.apply_solo_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.9.0i"
  end
end

class Window_CG_BattleSidecarList < Window_Selectable
  #--------------------------------------------------------------------------
  # ● 先讓 VX 原生 Window_Selectable 完成初始化，再恢復真正項目數
  #--------------------------------------------------------------------------
  def initialize(entries, type = :move)
    @entries = entries == nil ? [] : entries
    @type = type
    @top_index = 0
    @open_tick = 0

    count = @entries.size
    rows = [[count, ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS].min, 1].max
    @open_total = ALBERT_CG::BattlerSidecarUI.open_total(rows)

    super(0, 0, ALBERT_CG::BattlerSidecarUI::SIDE_WINDOW_WIDTH,
      rows * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
      ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP) + 32)

    # Window_Selectable#initialize 會把它改回 1，必須在 super 後設定。
    @item_max = count
    @column_max = 1
    @index = @item_max > 0 ? 0 : -1

    self.opacity = 0
    self.back_opacity = 0
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    self.active = false
    refresh
  end

  unless method_defined?(:albert_cg_v190i_sidecar_refresh)
    alias albert_cg_v190i_sidecar_refresh refresh
  end

  def refresh
    @entries = [] if @entries == nil
    @item_max = @entries.size
    @top_index = 0 if @top_index == nil
    if @item_max <= 0
      @index = -1
      @top_index = 0
    else
      @index = 0 if @index == nil || @index < 0
      @index = @item_max - 1 if @index >= @item_max
      maximum = [@item_max -
        ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, 0].max
      @top_index = maximum if @top_index > maximum
      @top_index = 0 if @top_index < 0
    end
    albert_cg_v190i_sidecar_refresh
  end
end

class Scene_Title < Scene_Base
  unless method_defined?(:albert_cg_v190i_load_database)
    alias albert_cg_v190i_load_database load_database
  end
  def load_database
    albert_cg_v190i_load_database
    ALBERT_CG.apply_solo_title
  end

  unless method_defined?(:albert_cg_v190i_load_bt_database)
    alias albert_cg_v190i_load_bt_database load_bt_database
  end
  def load_bt_database
    albert_cg_v190i_load_bt_database
    ALBERT_CG.apply_solo_title
  end
end
