# RMVX_SCRIPT_INDEX: 164
# RMVX_SCRIPT_ID: 98941069
# RMVX_SCRIPT_NAME: CG Battle HUD & Gauge Polish v1.8.4b
# RMVX_SOURCE_SHA256: cd922e8451a5f065fa4d98fcf8745a063e900bdbca5f106eb254dbd17836a81d

#==============================================================================
# ■ CG Battle HUD & Gauge Polish v1.8.4b
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【本版調整】
#  1. Battle Status 保持貼底，但整體下移並縮短高度，減少遮住戰場。
#  2. HP／MP Gauge 加粗，並以逐掃描線位移做輕微斜切效果。
#  3. 狀態資訊移至中央行走圖左側，避免壓縮 MP Gauge。
#  4. Battle Command 超過四項時，將上下捲動箭頭畫在卡片右緣內側，
#     不再畫到 Window contents 範圍之外。
#
# 【腳本位置】
#  放在 CG Battle Status Readability v1.8.4a 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattleHUDGaugePolish_1_8_4b"] = true

module ALBERT_CG
  remove_const(:BATTLE_UI_VERSION) if const_defined?(:BATTLE_UI_VERSION)
  BATTLE_UI_VERSION = "1.8.4b"

  remove_const(:BATTLE_STATUS_Y) if const_defined?(:BATTLE_STATUS_Y)
  remove_const(:BATTLE_STATUS_HEIGHT) if const_defined?(:BATTLE_STATUS_HEIGHT)

  # 544×416：保持貼底，從 v1.8.4a 的 y=248／高168 下移 12px。
  BATTLE_STATUS_Y = 260
  BATTLE_STATUS_HEIGHT = 156

  module BattleStatusV184
    [:PORTRAIT_RADIUS, :PORTRAIT_Y, :PORTRAIT_W, :PORTRAIT_H,
     :TYPE_Y, :HP_TEXT_Y, :HP_GAUGE_Y, :MP_TEXT_Y, :MP_GAUGE_Y,
     :STATE_Y].each do |name|
      remove_const(name) if const_defined?(name)
    end

    PORTRAIT_RADIUS = 23
    PORTRAIT_Y = 34
    PORTRAIT_W = 34
    PORTRAIT_H = 40

    TYPE_Y = 54
    HP_TEXT_Y = 66
    HP_GAUGE_Y = 79
    MP_TEXT_Y = 96
    MP_GAUGE_Y = 109
    STATE_Y = 36
  end

  module BattleHUDGaugeV184b
    GAUGE_HEIGHT = 14
    GAUGE_SLANT = 4
    ARROW_COLOR = Color.new(255, 230, 72, 255)
    ARROW_LIGHT = Color.new(255, 255, 196, 255)
    ARROW_SHADOW = Color.new(0, 0, 0, 220)
    ARROW_BACK = Color.new(15, 20, 25, 210)

    def self.apply_title
      return if $data_system == nil
      $data_system.game_title = "CG Pet Battle Prototype v1.8.4b"
    end

    def self.draw_triangle(bitmap, center_x, top_y, direction, color)
      return if bitmap == nil || bitmap.disposed?
      size = 5
      if direction == :up
        for row in 0...size
          half = row
          bitmap.fill_rect(center_x - half, top_y + row,
            half * 2 + 1, 1, color)
        end
      else
        for row in 0...size
          half = size - row - 1
          bitmap.fill_rect(center_x - half, top_y + row,
            half * 2 + 1, 1, color)
        end
      end
    rescue
    end
  end
end

#==============================================================================
# ■ Generic Gauge：Battle Status 專用斜切繪製
#==============================================================================
module ALBERT_CG::GenericGauge
  def self.draw_slanted(target, kind, x, y, width, height,
      value, maximum, slant = 4, opacity = 255)
    return if target == nil || target.disposed?
    width = width.to_i
    height = height.to_i
    slant = slant.to_i
    return if width <= 2 || height <= 0
    slant = 0 if slant < 0
    slant = width / 4 if slant > width / 4
    base_width = width - slant
    base_width = 1 if base_width < 1

    temp = Bitmap.new(base_width, height)
    draw(temp, kind, 0, 0, base_width, height, value, maximum, opacity)

    denominator = [height - 1, 1].max
    for row in 0...height
      # 上緣向右偏移，形成輕微「／」斜切；下緣保持原位。
      shift = ((height - 1 - row) * slant / denominator).to_i
      target.blt(x + shift, y + row, temp,
        Rect.new(0, row, base_width, 1), opacity)
    end
    temp.dispose
  rescue
    temp.dispose if temp != nil && !temp.disposed?
  end
end

#==============================================================================
# ■ Battle Command 捲動箭頭
#==============================================================================
module ALBERT_CG::BattlerSidecarUI
  def self.draw_scroll_arrows(bitmap, top_index, item_count)
    return if bitmap == nil || bitmap.disposed?
    count = item_count.to_i
    top = top_index.to_i
    return if count <= SIDE_MAX_ROWS

    # 舊版把箭頭畫在 VERTICAL_CARD_WIDTH 之外；現在固定放在卡片右緣內側。
    card_right = [VERTICAL_CARD_WIDTH - 7, bitmap.width - 7].min
    card_right = 7 if card_right < 7
    step = VERTICAL_CARD_HEIGHT + VERTICAL_GAP
    visible_bottom = SIDE_MAX_ROWS * step - VERTICAL_GAP
    visible_bottom = bitmap.height if visible_bottom > bitmap.height

    if top > 0
      y = 3
      ALBERT_CG::BattleVisualV183b.fill_round_gradient(bitmap,
        card_right - 8, y - 2, 16, 11, 4,
        ALBERT_CG::BattleHUDGaugeV184b::ARROW_BACK,
        Color.new(15, 20, 25, 100))
      ALBERT_CG::BattleHUDGaugeV184b.draw_triangle(bitmap,
        card_right + 1, y + 1, :up,
        ALBERT_CG::BattleHUDGaugeV184b::ARROW_SHADOW)
      ALBERT_CG::BattleHUDGaugeV184b.draw_triangle(bitmap,
        card_right, y, :up,
        ALBERT_CG::BattleHUDGaugeV184b::ARROW_LIGHT)
    end

    if top + SIDE_MAX_ROWS < count
      y = visible_bottom - 9
      y = bitmap.height - 9 if y > bitmap.height - 9
      y = 1 if y < 1
      ALBERT_CG::BattleVisualV183b.fill_round_gradient(bitmap,
        card_right - 8, y - 2, 16, 11, 4,
        ALBERT_CG::BattleHUDGaugeV184b::ARROW_BACK,
        Color.new(15, 20, 25, 100))
      ALBERT_CG::BattleHUDGaugeV184b.draw_triangle(bitmap,
        card_right + 1, y + 1, :down,
        ALBERT_CG::BattleHUDGaugeV184b::ARROW_SHADOW)
      ALBERT_CG::BattleHUDGaugeV184b.draw_triangle(bitmap,
        card_right, y, :down,
        ALBERT_CG::BattleHUDGaugeV184b::ARROW_COLOR)
    end
  rescue
  end
end

#==============================================================================
# ■ Window_BattleStatus
#==============================================================================
class Window_BattleStatus < Window_Selectable
  # 身分與配對標記移到上方兩側，中央區保留給角色與狀態。
  def cg_v184_draw_identity_pair(actor, rect, pair_number)
    identity = ALBERT_CG.cg_ui_identity_text(actor).to_s
    identity_color = cg_identity_color(actor)
    pair_color = cg_pair_color(pair_number)

    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 8
    self.contents.font.bold = true

    y = rect.y + 17
    left_x = rect.x + 5
    ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
      left_x, y, 15, 13, 5, identity_color,
      Color.new(identity_color.red, identity_color.green,
        identity_color.blue, 115))
    self.contents.font.color = Color.new(255, 255, 255)
    self.contents.draw_text(left_x, y - 1, 15, 14, identity, 1)

    right_x = rect.x + rect.width - 23
    ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
      right_x, y, 18, 13, 5, pair_color,
      Color.new(pair_color.red, pair_color.green, pair_color.blue, 110))
    self.contents.font.color = Color.new(255, 255, 255)
    self.contents.draw_text(right_x, y - 1, 18, 14,
      "P" + pair_number.to_i.to_s, 1)

    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  rescue
  end

  # HP／MP：較粗、輕微斜切、數字保持清楚。
  def cg_v184_draw_resource(actor, rect, kind)
    x = rect.x + 8
    width = rect.width - 16
    if kind == :hp
      value = actor.hp.to_i
      maximum = actor.maxhp.to_i
      label = "HP"
      text_y = rect.y + ALBERT_CG::BattleStatusV184::HP_TEXT_Y
      gauge_y = rect.y + ALBERT_CG::BattleStatusV184::HP_GAUGE_Y
      text_color = hp_color(actor)
    else
      value = actor.mp.to_i
      maximum = actor.maxmp.to_i
      label = "MP"
      text_y = rect.y + ALBERT_CG::BattleStatusV184::MP_TEXT_Y
      gauge_y = rect.y + ALBERT_CG::BattleStatusV184::MP_GAUGE_Y
      text_color = mp_color(actor)
    end

    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 11
    self.contents.font.bold = true

    text = value.to_s + "/" + maximum.to_s
    self.contents.font.color = Color.new(0, 0, 0, 235)
    self.contents.draw_text(x + 1, text_y + 1, 22, 13, label, 0)
    self.contents.draw_text(x + 23, text_y + 1, width - 23, 13, text, 2)
    self.contents.font.color = text_color
    self.contents.draw_text(x, text_y, 22, 13, label, 0)
    self.contents.draw_text(x + 22, text_y, width - 22, 13, text, 2)

    if defined?(ALBERT_CG::GenericGauge)
      ALBERT_CG::GenericGauge.draw_slanted(self.contents, kind,
        x, gauge_y, width,
        ALBERT_CG::BattleHUDGaugeV184b::GAUGE_HEIGHT,
        value, maximum, ALBERT_CG::BattleHUDGaugeV184b::GAUGE_SLANT)
    else
      rate = maximum <= 0 ? 0.0 : value.to_f / maximum.to_f
      rate = 0.0 if rate < 0.0
      rate = 1.0 if rate > 1.0
      slant = ALBERT_CG::BattleHUDGaugeV184b::GAUGE_SLANT
      height = ALBERT_CG::BattleHUDGaugeV184b::GAUGE_HEIGHT
      for row in 0...height
        shift = ((height - 1 - row) * slant / [height - 1, 1].max).to_i
        row_width = width - slant
        self.contents.fill_rect(x + shift, gauge_y + row,
          row_width, 1, Color.new(0, 0, 0, 205))
        fill_width = (row_width * rate).to_i
        color = kind == :hp ? Color.new(82, 220, 102) :
          Color.new(75, 145, 245)
        self.contents.fill_rect(x + shift, gauge_y + row,
          fill_width, 1, color) if fill_width > 0
      end
    end

    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  rescue
  end

  # 狀態顯示放在角色左側。最多兩個大圖示，更多以 +N 呈現。
  def cg_v184_draw_state_row(actor, rect)
    states = []
    begin
      for state in actor.states
        states.push(state) if state != nil && state.icon_index.to_i > 0
      end
    rescue
    end

    x = rect.x + 7
    y = rect.y + ALBERT_CG::BattleStatusV184::STATE_Y
    if states.empty?
      ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
        x, y, 28, 13, 5,
        Color.new(46, 118, 78, 220), Color.new(24, 60, 42, 115))
      old_size = self.contents.font.size
      old_bold = self.contents.font.bold
      old_color = self.contents.font.color
      self.contents.font.size = 8
      self.contents.font.bold = true
      self.contents.font.color = Color.new(225, 255, 233)
      self.contents.draw_text(x, y - 1, 28, 14, "正常", 1)
      self.contents.font.size = old_size
      self.contents.font.bold = old_bold
      self.contents.font.color = old_color
      return
    end

    iconset = Cache.system("IconSet")
    visible = [states.size, 2].min
    for i in 0...visible
      icon = states[i].icon_index.to_i
      source = Rect.new(icon % 16 * 24, icon / 16 * 24, 24, 24)
      target = Rect.new(x + i * 18, y - 2, 18, 18)
      if defined?(ALBERT_CG::TRGSSXVisual)
        ALBERT_CG::TRGSSXVisual.stretch_blt(
          self.contents, target, iconset, source, 255)
      else
        self.contents.stretch_blt(target, iconset, source)
      end
    end

    if states.size > visible
      badge_x = x + 18
      ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
        badge_x, y + 1, 22, 14, 5,
        Color.new(42, 48, 58, 235), Color.new(18, 22, 28, 120))
      old_size = self.contents.font.size
      old_bold = self.contents.font.bold
      old_color = self.contents.font.color
      self.contents.font.size = 8
      self.contents.font.bold = true
      self.contents.font.color = Color.new(255, 255, 255)
      self.contents.draw_text(badge_x, y, 22, 15,
        "+" + (states.size - 1).to_s, 1)
      self.contents.font.size = old_size
      self.contents.font.bold = old_bold
      self.contents.font.color = old_color
    end
  rescue
  end

  def cg_v184_draw_empty_slot(rect, index, pair_number, pair_color)
    cx = rect.x + rect.width / 2
    cy = rect.y + ALBERT_CG::BattleStatusV184::PORTRAIT_Y
    cg_v183a_fill_circle(cx, cy, 21,
      ALBERT_CG::BattleStatusV184::EMPTY_START,
      ALBERT_CG::BattleStatusV184::EMPTY_END)
    cg_v183a_draw_circle_outline(cx, cy, 21,
      Color.new(pair_color.red, pair_color.green, pair_color.blue, 105))

    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 9
    self.contents.font.bold = true
    self.contents.font.color = Color.new(145, 158, 166, 195)
    label = index % 2 == 0 ? "人物空位" : "寵物空位"
    self.contents.draw_text(rect.x + 4, rect.y + 69,
      rect.width - 8, 16, label, 1)
    self.contents.font.size = 8
    self.contents.font.color = pair_color
    self.contents.draw_text(rect.x + 4, rect.y + 91,
      rect.width - 8, 14, "P" + pair_number.to_i.to_s, 1)
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  rescue
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  unless method_defined?(:albert_cg_v184b_load_database)
    alias albert_cg_v184b_load_database load_database
  end

  def load_database
    albert_cg_v184b_load_database
    ALBERT_CG::BattleHUDGaugeV184b.apply_title
  end
end
