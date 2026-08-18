# RMVX_SCRIPT_INDEX: 158
# RMVX_SCRIPT_ID: 98941063
# RMVX_SCRIPT_NAME: CG Battle Runtime & Status Polish v1.8.3a
# RMVX_SOURCE_SHA256: c37ec3497886fa322717218f1021c1b7af6eb130d07f1653143f06ccc7d08efe

#==============================================================================
# ■ CG Battle Runtime & Status Polish v1.8.3a
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【修正】
#  1. 修正主角選擇「換寵」時，Window_CG_BattleSidecarList 的
#     @top_index 尚未建立，造成 Fixnum 與 nil 比較的 ArgumentError。
#  2. Battle Status 改為「圓形行走圖＋右側 HP／MP」形式：
#     - 行走圖置於圓形框內。
#     - 右側顯示屬性／狀態方格與 HP／MP 圖片 Gauge。
#     - 主人／自由寵物／固定夥伴與配對編號仍保留。
#     - 目前操作角色以金色脈動圓環明確標示。
#
# 【腳本位置】
#  放在 CG Battle Interaction Polish v1.8.3 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattleRuntimeStatusPolish_1_8_3a"] = true

module ALBERT_CG
  if const_defined?(:BATTLE_UI_VERSION)
    remove_const(:BATTLE_UI_VERSION)
  end
  BATTLE_UI_VERSION = "1.8.3a"

  module BattleStatusV183a
    CIRCLE_RADIUS = 21
    CIRCLE_CENTER_X = 25
    CIRCLE_CENTER_Y = 39
    CHARACTER_W = 28
    CHARACTER_H = 34

    PANEL_NORMAL = Color.new(3, 10, 18, 135)
    PANEL_ALT = Color.new(7, 18, 15, 135)
    PANEL_ACTIVE = Color.new(44, 34, 5, 185)
    CIRCLE_INNER = Color.new(18, 28, 38, 245)
    CIRCLE_EDGE = Color.new(92, 112, 132, 245)
    ACTIVE_GOLD = Color.new(255, 222, 72, 255)
    ACTIVE_LIGHT = Color.new(255, 250, 178, 255)
    CHIP_BACK = Color.new(0, 0, 0, 210)

    def self.apply_title
      return if $data_system == nil
      $data_system.game_title = "CG Pet Battle Prototype v1.8.3a"
    end
  end
end

#==============================================================================
# ■ Window_CG_BattleSidecarList
#------------------------------------------------------------------------------
#  v1.8.2b 在 initialize 中先執行 self.index = 0，當時 @top_index 尚未
#  建立；index= 會立即呼叫 update_top_index，於是產生 nil 比較錯誤。
#==============================================================================
class Window_CG_BattleSidecarList < Window_Selectable
  def initialize(entries, type = :move)
    @entries = entries == nil ? [] : entries
    @type = type
    @item_max = @entries.size
    @top_index = 0
    @open_tick = 0
    rows = [[@item_max, ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS].min, 1].max
    @open_total = ALBERT_CG::BattlerSidecarUI.open_total(rows)
    super(0, 0, ALBERT_CG::BattlerSidecarUI::SIDE_WINDOW_WIDTH,
      rows * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
      ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP) + 32)
    self.opacity = 0
    self.back_opacity = 0
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    self.active = false
    @index = @item_max > 0 ? 0 : -1
    refresh
  end

  def update_top_index
    @item_max = @entries == nil ? 0 : @entries.size if @item_max == nil
    @top_index = 0 if @top_index == nil
    @index = @item_max.to_i > 0 ? 0 : -1 if @index == nil
    if @index >= 0
      if @index < @top_index
        @top_index = @index
      elsif @index >= @top_index + ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS
        @top_index = @index - ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS + 1
      end
    end
    maximum = [@item_max.to_i -
      ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, 0].max
    @top_index = maximum if @top_index > maximum
    @top_index = 0 if @top_index < 0
  end

  def item_rect(index)
    @top_index = 0 if @top_index == nil
    local = index.to_i - @top_index.to_i
    return Rect.new(-999, 0, 1, 1) if local < 0 ||
      local >= ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS
    y = local * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
      ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP)
    return Rect.new(0, y,
      ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_WIDTH,
      ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT)
  end

  def update
    old = @index
    super
    changed = old != @index
    @open_tick = 0 if @open_tick == nil
    @open_total = 0 if @open_total == nil
    if @open_tick < @open_total
      @open_tick += 1
      changed = true
    end
    refresh if changed
  end
end

#==============================================================================
# ■ Window_BattleStatus
#------------------------------------------------------------------------------
#  六張小卡仍以隊伍順序為權威，避免破壞戰鬥目標索引。
#==============================================================================
class Window_BattleStatus < Window_Selectable
  def cg_draw_status_slot(index, actor)
    rect = item_rect(index)
    pair_number = actor == nil ? (index / 2 + 1) :
      ALBERT_CG.cg_ui_pair_number(actor)
    pair_number = index / 2 + 1 if pair_number.to_i <= 0
    pair_color = cg_pair_color(pair_number)
    selected = actor != nil && index == @index
    pulse = (Graphics.frame_count / 5) % 2

    panel_color = selected ? ALBERT_CG::BattleStatusV183a::PANEL_ACTIVE :
      ((index / 2) % 2 == 0 ? ALBERT_CG::BattleStatusV183a::PANEL_NORMAL :
      ALBERT_CG::BattleStatusV183a::PANEL_ALT)
    self.contents.fill_rect(rect.x + 1, rect.y + 1,
      rect.width - 2, rect.height - 2, panel_color)

    # 配對分隔。每兩張卡視為一組主人＋寵物。
    if index % 2 == 0
      self.contents.fill_rect(rect.x + 1, rect.y + rect.height - 3,
        [rect.width * 2 - 2, self.contents.width - rect.x - 1].min,
        2, pair_color)
    end
    if index > 0 && index % 2 == 0
      self.contents.fill_rect(rect.x, rect.y + 5, 2,
        rect.height - 10, Color.new(pair_color.red, pair_color.green,
        pair_color.blue, 180))
    end

    if actor == nil
      cg_v183a_draw_empty_slot(rect, index, pair_number, pair_color)
      return
    end

    cg_v183a_draw_name_level(actor, rect)
    cg_v183a_draw_portrait_circle(actor, rect, selected, pulse, pair_color)
    cg_v183a_draw_identity_pair(actor, rect, pair_number)
    cg_v183a_draw_info_chip(actor, rect)
    cg_v183a_draw_compact_gauge(actor, rect, :hp, 40)
    cg_v183a_draw_compact_gauge(actor, rect, :mp, 57)

    if selected
      glow = pulse == 0 ? ALBERT_CG::BattleStatusV183a::ACTIVE_GOLD :
        ALBERT_CG::BattleStatusV183a::ACTIVE_LIGHT
      self.contents.fill_rect(rect.x + 1, rect.y + 1,
        rect.width - 2, 3, glow)
      self.contents.fill_rect(rect.x + rect.width - 4, rect.y + 5,
        3, rect.height - 10, glow)
    end

    if actor.dead?
      self.contents.fill_rect(rect.x + 1, rect.y + 1,
        rect.width - 2, rect.height - 2, Color.new(0, 0, 0, 105))
      old_size = self.contents.font.size
      old_bold = self.contents.font.bold
      old_color = self.contents.font.color
      self.contents.font.size = 10
      self.contents.font.bold = true
      self.contents.font.color = Color.new(255, 120, 120)
      self.contents.draw_text(rect.x + 42, rect.y + 24,
        rect.width - 44, 18, "不能戰鬥", 1)
      self.contents.font.size = old_size
      self.contents.font.bold = old_bold
      self.contents.font.color = old_color
    end
  end

  def cg_v183a_draw_empty_slot(rect, index, pair_number, pair_color)
    cx = rect.x + ALBERT_CG::BattleStatusV183a::CIRCLE_CENTER_X
    cy = rect.y + ALBERT_CG::BattleStatusV183a::CIRCLE_CENTER_Y
    cg_v183a_fill_circle(cx, cy, 19,
      Color.new(16, 24, 30, 180), Color.new(72, 82, 92, 170))
    old_size = self.contents.font.size
    old_color = self.contents.font.color
    self.contents.font.size = 9
    self.contents.font.color = Color.new(130, 140, 150)
    label = index % 2 == 0 ? "人物" : "寵物"
    self.contents.draw_text(rect.x + 45, rect.y + 26,
      rect.width - 48, 16, label + "空位", 1)
    self.contents.font.size = 8
    self.contents.font.color = pair_color
    self.contents.draw_text(rect.x + 2, rect.y + rect.height - 15,
      20, 12, "P" + pair_number.to_s, 1)
    self.contents.font.size = old_size
    self.contents.font.color = old_color
  end

  def cg_v183a_draw_name_level(actor, rect)
    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    name = actor.name.to_s
    size = 11
    self.contents.font.size = size
    self.contents.font.bold = true
    maximum = rect.width - 25
    while size > 8 && self.contents.text_size(name).width > maximum
      size -= 1
      self.contents.font.size = size
    end
    self.contents.font.color = hp_color(actor)
    self.contents.draw_text(rect.x + 2, rect.y + 1, maximum, 14, name, 0)
    self.contents.font.size = 8
    self.contents.font.bold = false
    self.contents.font.color = system_color
    self.contents.draw_text(rect.x + rect.width - 24, rect.y + 2,
      21, 12, "L" + actor.level.to_i.to_s, 2)
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  end

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
    cg_draw_small_character(actor, cx - 14, cy - 18,
      ALBERT_CG::BattleStatusV183a::CHARACTER_W,
      ALBERT_CG::BattleStatusV183a::CHARACTER_H)
  end

  def cg_v183a_fill_circle(cx, cy, radius, center_color, edge_color)
    if defined?(ALBERT_CG::TRGSSXVisual) &&
       ALBERT_CG::TRGSSXVisual.available?
      drawn = ALBERT_CG::TRGSSXVisual.fill_regular_polygon(
        self.contents, cx, cy, radius, 48, center_color, edge_color)
      return if drawn
    end
    radius = [radius.to_i, 1].max
    for dy in -radius..radius
      width = Math.sqrt([radius * radius - dy * dy, 0].max).to_i
      rate = dy.abs.to_f / radius
      red = (center_color.red * (1.0 - rate) + edge_color.red * rate).to_i
      green = (center_color.green * (1.0 - rate) + edge_color.green * rate).to_i
      blue = (center_color.blue * (1.0 - rate) + edge_color.blue * rate).to_i
      alpha = (center_color.alpha * (1.0 - rate) + edge_color.alpha * rate).to_i
      self.contents.fill_rect(cx - width, cy + dy, width * 2 + 1, 1,
        Color.new(red, green, blue, alpha))
    end
  rescue
  end

  def cg_v183a_draw_circle_outline(cx, cy, radius, color)
    if defined?(ALBERT_CG::TRGSSXVisual) &&
       ALBERT_CG::TRGSSXVisual.available?
      drawn = ALBERT_CG::TRGSSXVisual.draw_regular_polygon(
        self.contents, cx, cy, radius, 48, color, 2)
      return if drawn
    end
    for degree in 0...360
      next unless degree % 4 == 0
      radian = degree * Math::PI / 180.0
      x = cx + Math.cos(radian) * radius
      y = cy + Math.sin(radian) * radius
      self.contents.fill_rect(x.to_i, y.to_i, 2, 2, color)
    end
  rescue
  end

  def cg_v183a_draw_identity_pair(actor, rect, pair_number)
    text = ALBERT_CG.cg_ui_identity_text(actor)
    color = cg_identity_color(actor)
    x = rect.x + 3
    y = rect.y + 58
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

  def cg_v183a_draw_info_chip(actor, rect)
    x = rect.x + 47
    y = rect.y + 15
    width = [rect.width - 50, 18].max
    width = 20 if width > 20
    height = 16
    self.contents.fill_rect(x, y, width, height,
      ALBERT_CG::BattleStatusV183a::CHIP_BACK)

    state = nil
    begin
      for item in actor.states
        if item != nil && item.icon_index.to_i > 0
          state = item
          break
        end
      end
    rescue
    end
    if state != nil
      iconset = Cache.system("IconSet")
      icon = state.icon_index.to_i
      source = Rect.new(icon % 16 * 24, icon / 16 * 24, 24, 24)
      target = Rect.new(x + (width - 14) / 2, y + 1, 14, 14)
      self.contents.stretch_blt(target, iconset, source)
      return
    end

    keys = ALBERT_CG.cg_ui_type_keys(actor)
    keys = [] if keys == nil
    keys = keys[0, 2]
    if keys.empty?
      keys = [:normal]
    end
    part = [width / keys.size, 1].max
    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    for i in 0...keys.size
      key = keys[i]
      color = ALBERT_CG.cg_ui_type_color(key)
      bx = x + i * part
      bw = i == keys.size - 1 ? x + width - bx : part
      self.contents.fill_rect(bx, y, bw, height, color)
      self.contents.font.size = 8
      self.contents.font.bold = true
      brightness = color.red + color.green + color.blue
      self.contents.font.color = brightness > 470 ?
        Color.new(30, 30, 30) : Color.new(255, 255, 255)
      label = ALBERT_CG::TYPE_NAMES[key] || "?"
      self.contents.draw_text(bx, y, bw, height, label, 1)
    end
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  rescue
  end

  def cg_v183a_draw_compact_gauge(actor, rect, kind, y_offset)
    x = rect.x + 47
    width = rect.width - 50
    width = 18 if width < 18
    if kind == :hp
      value = actor.hp.to_i
      maximum = actor.maxhp.to_i
      label = "H"
      text_color = hp_color(actor)
    else
      value = actor.mp.to_i
      maximum = actor.maxmp.to_i
      label = "M"
      text_color = mp_color(actor)
    end
    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 8
    self.contents.font.bold = true
    self.contents.font.color = text_color
    self.contents.draw_text(x, rect.y + y_offset - 8, width, 10,
      label + " " + value.to_s, 2)
    if defined?(ALBERT_CG::GenericGauge)
      ALBERT_CG::GenericGauge.draw(self.contents, kind,
        x, rect.y + y_offset + 2, width, 7, value, maximum)
    else
      rate = maximum <= 0 ? 0.0 : value.to_f / maximum.to_f
      rate = 0.0 if rate < 0.0
      rate = 1.0 if rate > 1.0
      self.contents.fill_rect(x, rect.y + y_offset + 3,
        width, 5, Color.new(0, 0, 0, 190))
      color = kind == :hp ? Color.new(90, 220, 110) :
        Color.new(90, 150, 245)
      self.contents.fill_rect(x + 1, rect.y + y_offset + 4,
        ((width - 2) * rate).to_i, 3, color)
    end
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  rescue
  end

  def cg_v183a_draw_states(actor, rect)
    states = []
    begin
      for state in actor.states
        states.push(state) if state != nil && state.icon_index.to_i > 0
      end
    rescue
    end
    return if states.empty?
    iconset = Cache.system("IconSet")
    maximum = [states.size, 2].min
    start_x = rect.x + 48
    y = rect.y + 66
    for i in 0...maximum
      icon = states[i].icon_index.to_i
      source = Rect.new(icon % 16 * 24, icon / 16 * 24, 24, 24)
      target = Rect.new(start_x + i * 15, y, 13, 13)
      self.contents.stretch_blt(target, iconset, source)
    end
  rescue
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  unless method_defined?(:albert_cg_v183a_load_database)
    alias albert_cg_v183a_load_database load_database
  end

  def load_database
    albert_cg_v183a_load_database
    ALBERT_CG::BattleStatusV183a.apply_title
  end
end
