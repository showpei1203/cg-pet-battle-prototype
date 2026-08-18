# RMVX_SCRIPT_INDEX: 162
# RMVX_SCRIPT_ID: 98941067
# RMVX_SCRIPT_NAME: CG Battle Status & Scroll Polish v1.8.3g
# RMVX_SOURCE_SHA256: 1f2f63dd176cc5b23d31d166ce77263cadc78a0ad7a9f1f90ed1c05eb8ba6a53

#==============================================================================
# ■ CG Battle Status & Scroll Polish v1.8.3g
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【本版調整】
#  1. 捲動提示不再使用字型符號，改以 Bitmap 直接繪製三角箭頭，
#     避免 VX 字型或窄欄位讓 ▼ 消失。
#  2. Battle Status 向上延伸：由 y=304／高112 改為 y=280／高136。
#  3. 圓形行走圖上移，HP／MP 改到卡片下半部並使用更寬的 Gauge。
#  4. 行動順序列跟著 Battle Status 上移，避免兩者重疊。
#
# 【腳本位置】
#  放在 CG Battle Headstack UI v1.8.3e 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattleStatusScrollPolish_1_8_3g"] = true

module ALBERT_CG
  if const_defined?(:BATTLE_UI_VERSION)
    remove_const(:BATTLE_UI_VERSION)
  end
  BATTLE_UI_VERSION = "1.8.3f"

  remove_const(:BATTLE_STATUS_Y) if const_defined?(:BATTLE_STATUS_Y)
  remove_const(:BATTLE_STATUS_HEIGHT) if const_defined?(:BATTLE_STATUS_HEIGHT)
  remove_const(:ORDER_WINDOW_Y) if const_defined?(:ORDER_WINDOW_Y)
  BATTLE_STATUS_Y = 280
  BATTLE_STATUS_HEIGHT = 136
  ORDER_WINDOW_Y = BATTLE_STATUS_Y - 76

  module BattleStatusV183a
    remove_const(:CIRCLE_CENTER_Y) if const_defined?(:CIRCLE_CENTER_Y)
    remove_const(:CIRCLE_RADIUS) if const_defined?(:CIRCLE_RADIUS)
    remove_const(:CHARACTER_W) if const_defined?(:CHARACTER_W)
    remove_const(:CHARACTER_H) if const_defined?(:CHARACTER_H)
    CIRCLE_CENTER_Y = 30
    CIRCLE_RADIUS = 22
    CHARACTER_W = 30
    CHARACTER_H = 36
  end

  module BattleStatusScrollV183g
    ARROW_COLOR = Color.new(255, 231, 104, 255)
    ARROW_SHADOW = Color.new(0, 0, 0, 210)
    ARROW_BACK = Color.new(8, 12, 18, 175)

    def self.apply_title
      return if $data_system == nil
      $data_system.game_title = "CG Pet Battle Prototype v1.8.3g"
    end

    def self.draw_triangle(bitmap, center_x, top_y, direction, color)
      return if bitmap == nil || bitmap.disposed?
      size = 5
      if direction == :up
        for row in 0...size
          half = row
          y = top_y + row
          bitmap.fill_rect(center_x - half, y, half * 2 + 1, 1, color)
        end
      else
        for row in 0...size
          half = size - row - 1
          y = top_y + row
          bitmap.fill_rect(center_x - half, y, half * 2 + 1, 1, color)
        end
      end
    rescue
    end
  end
end

#==============================================================================
# ■ Scroll arrows：以圖形取代 ▲／▼ 字元
#==============================================================================
module ALBERT_CG::BattlerSidecarUI
  def self.draw_scroll_arrows(bitmap, top_index, item_count)
    return if bitmap == nil || bitmap.disposed?
    item_count = item_count.to_i
    top_index = top_index.to_i
    return if item_count <= SIDE_MAX_ROWS

    lane_x = VERTICAL_CARD_WIDTH + 2
    lane_w = [bitmap.width - lane_x - 1, 10].max
    center_x = lane_x + lane_w / 2
    pulse = 210 + ((Graphics.frame_count / 5) % 2) * 45
    light = Color.new(
      ALBERT_CG::BattleStatusScrollV183g::ARROW_COLOR.red,
      ALBERT_CG::BattleStatusScrollV183g::ARROW_COLOR.green,
      ALBERT_CG::BattleStatusScrollV183g::ARROW_COLOR.blue,
      pulse)

    if top_index > 0
      bitmap.fill_rect(lane_x, 0, lane_w, 11,
        ALBERT_CG::BattleStatusScrollV183g::ARROW_BACK)
      ALBERT_CG::BattleStatusScrollV183g.draw_triangle(bitmap,
        center_x + 1, 3, :up,
        ALBERT_CG::BattleStatusScrollV183g::ARROW_SHADOW)
      ALBERT_CG::BattleStatusScrollV183g.draw_triangle(bitmap,
        center_x, 2, :up, light)
    end

    if top_index + SIDE_MAX_ROWS < item_count
      y = bitmap.height - 8
      bitmap.fill_rect(lane_x, bitmap.height - 11, lane_w, 11,
        ALBERT_CG::BattleStatusScrollV183g::ARROW_BACK)
      ALBERT_CG::BattleStatusScrollV183g.draw_triangle(bitmap,
        center_x + 1, y + 1, :down,
        ALBERT_CG::BattleStatusScrollV183g::ARROW_SHADOW)
      ALBERT_CG::BattleStatusScrollV183g.draw_triangle(bitmap,
        center_x, y, :down, light)
    end
  rescue
  end
end

#==============================================================================
# ■ Window_BattleStatus
#==============================================================================
class Window_BattleStatus < Window_Selectable
  # 身分與配對標記上移，將卡片下半部完整留給 Gauge。
  def cg_v183a_draw_identity_pair(actor, rect, pair_number)
    text = ALBERT_CG.cg_ui_identity_text(actor)
    color = cg_identity_color(actor)
    x = rect.x + 3
    y = rect.y + 47
    self.contents.fill_rect(x, y, 13, 12, color)
    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 8
    self.contents.font.bold = true
    self.contents.font.color = Color.new(255, 255, 255)
    self.contents.draw_text(x, y - 1, 13, 13, text.to_s, 1)
    self.contents.font.size = 8
    self.contents.font.color = cg_pair_color(pair_number)
    self.contents.draw_text(x + 14, y - 1, 18, 13,
      "P" + pair_number.to_s, 0)
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  end

  # 圓形行走圖上移，讓下方 HP／MP 能橫跨整張卡片。
  def cg_v183a_draw_portrait_circle(actor, rect, selected, pulse, pair_color)
    cx = rect.x + ALBERT_CG::BattleStatusV183a::CIRCLE_CENTER_X
    cy = rect.y + ALBERT_CG::BattleStatusV183a::CIRCLE_CENTER_Y
    radius = ALBERT_CG::BattleStatusV183a::CIRCLE_RADIUS

    self.contents.fill_rect(cx - radius + 2, cy + radius - 1,
      radius * 2 - 4, 3, Color.new(0, 0, 0, 115))
    if selected
      edge = pulse == 0 ? ALBERT_CG::BattleStatusV183a::ACTIVE_GOLD :
        ALBERT_CG::BattleStatusV183a::ACTIVE_LIGHT
      cg_v183a_fill_circle(cx, cy, radius + 2, edge, edge)
      cg_v183a_fill_circle(cx, cy, radius - 1,
        ALBERT_CG::BattleStatusV183a::CIRCLE_INNER, pair_color)
    else
      cg_v183a_fill_circle(cx, cy, radius,
        ALBERT_CG::BattleStatusV183a::CIRCLE_INNER,
        ALBERT_CG::BattleStatusV183a::CIRCLE_EDGE)
      cg_v183a_draw_circle_outline(cx, cy, radius, pair_color)
    end
    cg_draw_small_character(actor, cx - 15, cy - 19,
      ALBERT_CG::BattleStatusV183a::CHARACTER_W,
      ALBERT_CG::BattleStatusV183a::CHARACTER_H)
  end

  # HP／MP 改為卡片下方全寬 Gauge，並顯示目前值／最大值。
  def cg_v183a_draw_compact_gauge(actor, rect, kind, ignored_offset)
    x = rect.x + 6
    width = rect.width - 12
    width = 24 if width < 24
    if kind == :hp
      value = actor.hp.to_i
      maximum = actor.maxhp.to_i
      label = "HP"
      text_color = hp_color(actor)
      text_y = rect.y + 59
      gauge_y = rect.y + 70
    else
      value = actor.mp.to_i
      maximum = actor.maxmp.to_i
      label = "MP"
      text_color = mp_color(actor)
      text_y = rect.y + 79
      gauge_y = rect.y + 90
    end

    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 8
    self.contents.font.bold = true
    self.contents.font.color = text_color
    self.contents.draw_text(x, text_y, 18, 10, label, 0)
    self.contents.draw_text(x + 18, text_y, width - 18, 10,
      value.to_s + "/" + maximum.to_s, 2)

    if defined?(ALBERT_CG::GenericGauge)
      ALBERT_CG::GenericGauge.draw(self.contents, kind,
        x, gauge_y, width, 9, value, maximum)
    else
      rate = maximum <= 0 ? 0.0 : value.to_f / maximum.to_f
      rate = 0.0 if rate < 0.0
      rate = 1.0 if rate > 1.0
      self.contents.fill_rect(x, gauge_y + 1,
        width, 7, Color.new(0, 0, 0, 190))
      color = kind == :hp ? Color.new(90, 220, 110) :
        Color.new(90, 150, 245)
      self.contents.fill_rect(x + 1, gauge_y + 2,
        ((width - 2) * rate).to_i, 5, color)
    end
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  rescue
  end
end

#==============================================================================
# ■ Scene_Battle：既有戰鬥中如重新定位視窗，統一使用新高度
#==============================================================================
class Scene_Battle < Scene_Base
  unless method_defined?(:albert_cg_v183g_update)
    alias albert_cg_v183g_update update
  end
  def update
    albert_cg_v183g_update
    if @status_window != nil && !@status_window.disposed?
      @status_window.y = ALBERT_CG::BATTLE_STATUS_Y
    end
    if @cg_action_order_window != nil &&
       !@cg_action_order_window.disposed?
      @cg_action_order_window.y = ALBERT_CG::ORDER_WINDOW_Y
    end
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  unless method_defined?(:albert_cg_v183g_load_database)
    alias albert_cg_v183g_load_database load_database
  end
  def load_database
    albert_cg_v183g_load_database
    ALBERT_CG::BattleStatusScrollV183g.apply_title
  end
end
