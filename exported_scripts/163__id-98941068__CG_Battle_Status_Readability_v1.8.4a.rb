# RMVX_SCRIPT_INDEX: 163
# RMVX_SCRIPT_ID: 98941068
# RMVX_SCRIPT_NAME: CG Battle Status Readability v1.8.4a
# RMVX_SOURCE_SHA256: 2060464b071074e45aa3bc50accf5e2acb1f59dc48bb67a611a44ecd0ad06b0a

#==============================================================================
# ■ CG Battle Status Readability v1.8.4a
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【本版目的】
#  1. Battle Status 改為資訊優先版，行走圖置於每張卡片中央。
#  2. HP／MP 使用更寬、更粗的圖片式 Gauge，數值字體同步放大。
#  3. 狀態圖示固定放在卡片最下方，最多顯示 4 個；超過時顯示 +N。
#  4. 人物／自由寵物／固定夥伴與 P1～P2 標記縮小並移到圓框兩側。
#  5. 目前操作或選擇中的角色使用強烈金色圓框、卡片外框與頂部指標。
#  6. Battle Status 改為四張寬卡，並將行動序列移到 Help Window 下方中央。
#
# 【腳本位置】
#  放在 CG Battle Status & Scroll Polish v1.8.3g 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattleStatusReadability_1_8_4a"] = true

module ALBERT_CG
  remove_const(:BATTLE_UI_VERSION) if const_defined?(:BATTLE_UI_VERSION)
  BATTLE_UI_VERSION = "1.8.4a"

  [:BATTLE_STATUS_Y, :BATTLE_STATUS_HEIGHT, :BATTLE_STATUS_SLOT_COUNT,
   :ORDER_WINDOW_X, :ORDER_WINDOW_Y, :ORDER_WINDOW_WIDTH,
   :ORDER_WINDOW_HEIGHT, :ORDER_CARD_COUNT].each do |name|
    remove_const(name) if const_defined?(name)
  end

  # 正式戰鬥改為兩組「人物＋寵物」，共四張較寬的角色卡。
  # Window_Base 會扣除上下 16px padding，168px 高可得到 136px 內容區。
  BATTLE_STATUS_Y = 248
  BATTLE_STATUS_HEIGHT = 168
  BATTLE_STATUS_SLOT_COUNT = 4

  # 行動序列置於 Help Window 下方、畫面水平中央。
  # 透明 Window 只承載菱形卡片，不再壓到戰場上的人物。
  ORDER_WINDOW_WIDTH = 360
  ORDER_WINDOW_HEIGHT = 88
  ORDER_WINDOW_X = (544 - ORDER_WINDOW_WIDTH) / 2
  ORDER_WINDOW_Y = 58
  ORDER_CARD_COUNT = 8

  # 將菱形鏈在 328px 的內容區內置中。
  module BattleInteractionPolish
    [:CURRENT_X, :WAITING_START_X].each do |name|
      remove_const(name) if const_defined?(name)
    end
    CURRENT_X = 20
    WAITING_START_X = 72
  end

  module BattleStatusV184
    CARD_RADIUS = 9
    INNER_RADIUS = 7
    PORTRAIT_RADIUS = 26
    PORTRAIT_Y = 38
    PORTRAIT_W = 36
    PORTRAIT_H = 42

    NAME_Y = 1
    TYPE_Y = 65
    HP_TEXT_Y = 75
    HP_GAUGE_Y = 86
    MP_TEXT_Y = 98
    MP_GAUGE_Y = 108
    STATE_Y = 120

    ACTIVE_GOLD = Color.new(255, 211, 62, 255)
    ACTIVE_LIGHT = Color.new(255, 250, 176, 255)
    ACTIVE_FILL = Color.new(112, 78, 8, 225)
    ACTIVE_END = Color.new(72, 44, 4, 100)
    NORMAL_A = Color.new(16, 35, 49, 220)
    NORMAL_B = Color.new(18, 45, 35, 220)
    NORMAL_END = Color.new(8, 14, 20, 86)
    EMPTY_START = Color.new(26, 34, 40, 180)
    EMPTY_END = Color.new(10, 15, 19, 66)
    CIRCLE_INNER = Color.new(18, 27, 34, 235)
    STATE_BACK = Color.new(0, 0, 0, 105)

    def self.apply_title
      return if $data_system == nil
      $data_system.game_title = "CG Pet Battle Prototype v1.8.4a"
    end

    def self.draw_down_triangle(bitmap, center_x, top_y, color)
      return if bitmap == nil || bitmap.disposed?
      for row in 0...5
        half = 4 - row
        bitmap.fill_rect(center_x - half, top_y + row,
          half * 2 + 1, 1, color)
      end
    rescue
    end
  end
end

#==============================================================================
# ■ Window_BattleStatus
#==============================================================================
class Window_BattleStatus < Window_Selectable
  #--------------------------------------------------------------------------
  # ● 角色卡主繪製
  #--------------------------------------------------------------------------
  def cg_draw_status_slot(index, actor)
    rect = item_rect(index)
    self.contents.clear_rect(rect.x, rect.y, rect.width, rect.height)

    pair_number = actor == nil ? (index / 2 + 1) :
      ALBERT_CG.cg_ui_pair_number(actor)
    pair_number = index / 2 + 1 if pair_number.to_i <= 0
    pair_color = cg_pair_color(pair_number)
    selected = actor != nil && index == @index
    pulse = (Graphics.frame_count / 5) % 2

    cg_v184_draw_panel(rect, index, selected, pulse, pair_color)

    if actor == nil
      cg_v184_draw_empty_slot(rect, index, pair_number, pair_color)
      return
    end

    cg_v184_draw_name_level(actor, rect)
    cg_v184_draw_center_portrait(actor, rect, selected, pulse, pair_color)
    cg_v184_draw_identity_pair(actor, rect, pair_number)
    cg_v184_draw_type_row(actor, rect)
    cg_v184_draw_resource(actor, rect, :hp)
    cg_v184_draw_resource(actor, rect, :mp)
    cg_v184_draw_state_row(actor, rect)
    cg_v184_draw_active_marker(rect, pulse) if selected
    cg_v184_draw_dead_overlay(actor, rect) if actor.dead?
  end

  #--------------------------------------------------------------------------
  # ● 圓角卡片背景
  #--------------------------------------------------------------------------
  def cg_v184_draw_panel(rect, index, selected, pulse, pair_color)
    if selected
      border = pulse == 0 ?
        ALBERT_CG::BattleStatusV184::ACTIVE_GOLD :
        ALBERT_CG::BattleStatusV184::ACTIVE_LIGHT
      start_color = ALBERT_CG::BattleStatusV184::ACTIVE_FILL
      end_color = ALBERT_CG::BattleStatusV184::ACTIVE_END
    else
      border = Color.new(pair_color.red, pair_color.green,
        pair_color.blue, 215)
      start_color = (index / 2) % 2 == 0 ?
        ALBERT_CG::BattleStatusV184::NORMAL_A :
        ALBERT_CG::BattleStatusV184::NORMAL_B
      end_color = ALBERT_CG::BattleStatusV184::NORMAL_END
    end

    ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
      rect.x + 1, rect.y + 1, rect.width - 2, rect.height - 2,
      ALBERT_CG::BattleStatusV184::CARD_RADIUS,
      border, Color.new(border.red, border.green, border.blue, 90))
    ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
      rect.x + 3, rect.y + 3, rect.width - 6, rect.height - 6,
      ALBERT_CG::BattleStatusV184::INNER_RADIUS,
      start_color, end_color)

    # 每兩張卡共用一條主人／寵物配對底線。
    if index % 2 == 0
      width = [rect.width * 2 - 10,
        self.contents.width - rect.x - 5].min
      ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
        rect.x + 5, rect.y + rect.height - 4, width, 2, 1,
        pair_color, Color.new(pair_color.red, pair_color.green,
        pair_color.blue, 50))
    end
  rescue
  end

  #--------------------------------------------------------------------------
  # ● 名稱與等級
  #--------------------------------------------------------------------------
  def cg_v184_draw_name_level(actor, rect)
    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color

    name = actor.name.to_s
    level_text = "L" + actor.level.to_i.to_s
    size = 11
    self.contents.font.size = size
    self.contents.font.bold = true
    maximum = rect.width - 23
    while size > 9 && self.contents.text_size(name).width > maximum
      size -= 1
      self.contents.font.size = size
    end
    self.contents.font.color = hp_color(actor)
    self.contents.draw_text(rect.x + 3,
      rect.y + ALBERT_CG::BattleStatusV184::NAME_Y,
      maximum, 15, name, 1)

    self.contents.font.size = 8
    self.contents.font.bold = true
    self.contents.font.color = system_color
    self.contents.draw_text(rect.x + rect.width - 22,
      rect.y + ALBERT_CG::BattleStatusV184::NAME_Y + 1,
      19, 12, level_text, 2)

    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  end

  #--------------------------------------------------------------------------
  # ● 中央圓形行走圖
  #--------------------------------------------------------------------------
  def cg_v184_draw_center_portrait(actor, rect, selected, pulse, pair_color)
    cx = rect.x + rect.width / 2
    cy = rect.y + ALBERT_CG::BattleStatusV184::PORTRAIT_Y
    radius = ALBERT_CG::BattleStatusV184::PORTRAIT_RADIUS

    # 柔和陰影。
    self.contents.fill_rect(cx - radius + 4, cy + radius - 1,
      radius * 2 - 8, 3, Color.new(0, 0, 0, 130))

    if selected
      edge = pulse == 0 ?
        ALBERT_CG::BattleStatusV184::ACTIVE_GOLD :
        ALBERT_CG::BattleStatusV184::ACTIVE_LIGHT
      cg_v183a_fill_circle(cx, cy, radius + 3, edge, edge)
      cg_v183a_fill_circle(cx, cy, radius,
        ALBERT_CG::BattleStatusV184::CIRCLE_INNER, pair_color)
    else
      cg_v183a_fill_circle(cx, cy, radius + 1,
        Color.new(pair_color.red, pair_color.green, pair_color.blue, 225),
        Color.new(pair_color.red, pair_color.green, pair_color.blue, 145))
      cg_v183a_fill_circle(cx, cy, radius - 2,
        ALBERT_CG::BattleStatusV184::CIRCLE_INNER,
        Color.new(26, 38, 47, 235))
    end

    cg_draw_small_character(actor,
      cx - ALBERT_CG::BattleStatusV184::PORTRAIT_W / 2,
      cy - ALBERT_CG::BattleStatusV184::PORTRAIT_H / 2,
      ALBERT_CG::BattleStatusV184::PORTRAIT_W,
      ALBERT_CG::BattleStatusV184::PORTRAIT_H)
  rescue
  end

  #--------------------------------------------------------------------------
  # ● 身分與配對標記
  #--------------------------------------------------------------------------
  def cg_v184_draw_identity_pair(actor, rect, pair_number)
    cy = rect.y + ALBERT_CG::BattleStatusV184::PORTRAIT_Y
    identity = ALBERT_CG.cg_ui_identity_text(actor).to_s
    identity_color = cg_identity_color(actor)
    pair_color = cg_pair_color(pair_number)

    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 8
    self.contents.font.bold = true

    x1 = rect.x + 4
    y = cy - 7
    ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
      x1, y, 15, 14, 5, identity_color,
      Color.new(identity_color.red, identity_color.green,
      identity_color.blue, 120))
    self.contents.font.color = Color.new(255, 255, 255)
    self.contents.draw_text(x1, y - 1, 15, 14, identity, 1)

    x2 = rect.x + rect.width - 22
    ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
      x2, y, 18, 14, 5, pair_color,
      Color.new(pair_color.red, pair_color.green, pair_color.blue, 115))
    self.contents.font.color = Color.new(255, 255, 255)
    self.contents.draw_text(x2, y - 1, 18, 14,
      "P" + pair_number.to_i.to_s, 1)

    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  rescue
  end

  #--------------------------------------------------------------------------
  # ● 單／雙屬性小標籤
  #--------------------------------------------------------------------------
  def cg_v184_draw_type_row(actor, rect)
    keys = ALBERT_CG.cg_ui_type_keys(actor)
    keys = [] if keys == nil
    keys = keys[0, 2]
    keys = [:normal] if keys.empty?

    total_width = keys.size == 1 ? 30 : 48
    start_x = rect.x + (rect.width - total_width) / 2
    y = rect.y + ALBERT_CG::BattleStatusV184::TYPE_Y
    part = total_width / keys.size

    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 8
    self.contents.font.bold = true

    for i in 0...keys.size
      key = keys[i]
      color = ALBERT_CG.cg_ui_type_color(key)
      x = start_x + i * part
      width = i == keys.size - 1 ? start_x + total_width - x : part
      ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
        x, y, width, 11, 4,
        Color.new(color.red, color.green, color.blue, 235),
        Color.new(color.red, color.green, color.blue, 105))
      brightness = color.red + color.green + color.blue
      self.contents.font.color = brightness > 470 ?
        Color.new(24, 24, 24) : Color.new(255, 255, 255)
      label = ALBERT_CG::TYPE_NAMES[key] || "?"
      label = label.to_s
      self.contents.draw_text(x, y - 1, width, 12, label, 1)
    end

    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  rescue
  end

  #--------------------------------------------------------------------------
  # ● HP／MP：加寬 Gauge 與較大的數字
  #--------------------------------------------------------------------------
  def cg_v184_draw_resource(actor, rect, kind)
    x = rect.x + 6
    width = rect.width - 12
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
    self.contents.font.size = 10
    self.contents.font.bold = true

    self.contents.font.color = Color.new(0, 0, 0, 235)
    self.contents.draw_text(x + 1, text_y + 1, 19, 12, label, 0)
    self.contents.draw_text(x + 18, text_y + 1, width - 18, 12,
      value.to_s + "/" + maximum.to_s, 2)
    self.contents.font.color = text_color
    self.contents.draw_text(x, text_y, 19, 12, label, 0)
    self.contents.draw_text(x + 17, text_y, width - 17, 12,
      value.to_s + "/" + maximum.to_s, 2)

    if defined?(ALBERT_CG::GenericGauge)
      ALBERT_CG::GenericGauge.draw(self.contents, kind,
        x, gauge_y, width, 11, value, maximum)
    else
      rate = maximum <= 0 ? 0.0 : value.to_f / maximum.to_f
      rate = 0.0 if rate < 0.0
      rate = 1.0 if rate > 1.0
      self.contents.fill_rect(x, gauge_y + 1, width, 9,
        Color.new(0, 0, 0, 205))
      color = kind == :hp ? Color.new(82, 220, 102) :
        Color.new(75, 145, 245)
      self.contents.fill_rect(x + 1, gauge_y + 2,
        ((width - 2) * rate).to_i, 7, color)
    end

    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  rescue
  end

  #--------------------------------------------------------------------------
  # ● 狀態圖示列
  #--------------------------------------------------------------------------
  def cg_v184_draw_state_row(actor, rect)
    states = []
    begin
      for state in actor.states
        if state != nil && state.icon_index.to_i > 0
          states.push(state)
        end
      end
    rescue
    end

    y = rect.y + ALBERT_CG::BattleStatusV184::STATE_Y
    available = rect.width - 10
    icon_size = 16

    if states.empty?
      old_size = self.contents.font.size
      old_color = self.contents.font.color
      self.contents.font.size = 9
      self.contents.font.color = Color.new(185, 205, 210, 205)
      self.contents.draw_text(rect.x + 5, y, available, 15,
        "狀態正常", 1)
      self.contents.font.size = old_size
      self.contents.font.color = old_color
      return
    end

    visible = states.size > 4 ? 3 : [states.size, 4].min
    extra_width = states.size > visible ? 20 : 0
    total = visible * icon_size + extra_width
    start_x = rect.x + (rect.width - total) / 2
    iconset = Cache.system("IconSet")

    for i in 0...visible
      icon = states[i].icon_index.to_i
      source = Rect.new(icon % 16 * 24, icon / 16 * 24, 24, 24)
      target = Rect.new(start_x + i * icon_size, y, icon_size, icon_size)
      if defined?(ALBERT_CG::TRGSSXVisual)
        ALBERT_CG::TRGSSXVisual.stretch_blt(
          self.contents, target, iconset, source, 255)
      else
        self.contents.stretch_blt(target, iconset, source)
      end
    end

    if states.size > visible
      x = start_x + visible * icon_size
      ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
        x + 1, y + 2, 18, 14, 5,
        Color.new(34, 40, 48, 230), Color.new(20, 24, 30, 120))
      old_size = self.contents.font.size
      old_bold = self.contents.font.bold
      old_color = self.contents.font.color
      self.contents.font.size = 8
      self.contents.font.bold = true
      self.contents.font.color = Color.new(255, 255, 255)
      self.contents.draw_text(x + 1, y + 1, 18, 15,
        "+" + (states.size - visible).to_s, 1)
      self.contents.font.size = old_size
      self.contents.font.bold = old_bold
      self.contents.font.color = old_color
    end
  rescue
  end

  #--------------------------------------------------------------------------
  # ● 當前角色強化標記
  #--------------------------------------------------------------------------
  def cg_v184_draw_active_marker(rect, pulse)
    color = pulse == 0 ?
      ALBERT_CG::BattleStatusV184::ACTIVE_GOLD :
      ALBERT_CG::BattleStatusV184::ACTIVE_LIGHT
    center_x = rect.x + rect.width / 2
    ALBERT_CG::BattleStatusV184.draw_down_triangle(self.contents,
      center_x, rect.y + 3, color)
    self.contents.fill_rect(rect.x + 8, rect.y + 2,
      rect.width - 16, 2, color)
  rescue
  end

  #--------------------------------------------------------------------------
  # ● 戰鬥不能遮罩
  #--------------------------------------------------------------------------
  def cg_v184_draw_dead_overlay(actor, rect)
    ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
      rect.x + 3, rect.y + 3, rect.width - 6, rect.height - 6,
      ALBERT_CG::BattleStatusV184::INNER_RADIUS,
      Color.new(0, 0, 0, 118), Color.new(0, 0, 0, 60))
    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 11
    self.contents.font.bold = true
    self.contents.font.color = Color.new(255, 125, 125)
    self.contents.draw_text(rect.x + 3,
      rect.y + ALBERT_CG::BattleStatusV184::PORTRAIT_Y - 8,
      rect.width - 6, 18, "不能戰鬥", 1)
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  rescue
  end

  #--------------------------------------------------------------------------
  # ● 空位
  #--------------------------------------------------------------------------
  def cg_v184_draw_empty_slot(rect, index, pair_number, pair_color)
    cx = rect.x + rect.width / 2
    cy = rect.y + ALBERT_CG::BattleStatusV184::PORTRAIT_Y
    cg_v183a_fill_circle(cx, cy, 22,
      ALBERT_CG::BattleStatusV184::EMPTY_START,
      ALBERT_CG::BattleStatusV184::EMPTY_END)
    cg_v183a_draw_circle_outline(cx, cy, 22,
      Color.new(pair_color.red, pair_color.green, pair_color.blue, 105))

    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 9
    self.contents.font.bold = true
    self.contents.font.color = Color.new(145, 158, 166, 195)
    label = index % 2 == 0 ? "人物空位" : "寵物空位"
    self.contents.draw_text(rect.x + 4, rect.y + 66,
      rect.width - 8, 16, label, 1)
    self.contents.font.size = 8
    self.contents.font.color = pair_color
    self.contents.draw_text(rect.x + 4, rect.y + 85,
      rect.width - 8, 14, "P" + pair_number.to_i.to_s, 1)
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  rescue
  end
end

#==============================================================================
# ■ Scene_Battle：確保視窗與行動順序使用新位置
#==============================================================================
class Scene_Battle < Scene_Base
  unless method_defined?(:albert_cg_v184_update)
    alias albert_cg_v184_update update
  end

  def update
    albert_cg_v184_update
    cg_v184a_apply_battle_layout
  end

  def cg_v184a_apply_battle_layout
    if @status_window != nil && !@status_window.disposed?
      resize = @status_window.width != Graphics.width ||
        @status_window.height != ALBERT_CG::BATTLE_STATUS_HEIGHT
      @status_window.x = 0
      @status_window.y = ALBERT_CG::BATTLE_STATUS_Y
      @status_window.width = Graphics.width if @status_window.width != Graphics.width
      @status_window.height = ALBERT_CG::BATTLE_STATUS_HEIGHT if
        @status_window.height != ALBERT_CG::BATTLE_STATUS_HEIGHT
      if resize
        @status_window.create_contents
        @status_window.refresh
      end
    end

    if @cg_action_order_window != nil &&
       !@cg_action_order_window.disposed?
      resize = @cg_action_order_window.width != ALBERT_CG::ORDER_WINDOW_WIDTH ||
        @cg_action_order_window.height != ALBERT_CG::ORDER_WINDOW_HEIGHT
      @cg_action_order_window.x = ALBERT_CG::ORDER_WINDOW_X
      @cg_action_order_window.y = ALBERT_CG::ORDER_WINDOW_Y
      @cg_action_order_window.width = ALBERT_CG::ORDER_WINDOW_WIDTH if
        @cg_action_order_window.width != ALBERT_CG::ORDER_WINDOW_WIDTH
      @cg_action_order_window.height = ALBERT_CG::ORDER_WINDOW_HEIGHT if
        @cg_action_order_window.height != ALBERT_CG::ORDER_WINDOW_HEIGHT
      if resize
        @cg_action_order_window.create_contents
        @cg_action_order_window.refresh
      end
    end
  rescue
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  unless method_defined?(:albert_cg_v184_load_database)
    alias albert_cg_v184_load_database load_database
  end

  def load_database
    albert_cg_v184_load_database
    ALBERT_CG::BattleStatusV184.apply_title
  end
end
