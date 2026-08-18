# RMVX_SCRIPT_INDEX: 159
# RMVX_SCRIPT_ID: 98941064
# RMVX_SCRIPT_NAME: CG Battle Visual Polish v1.8.3b
# RMVX_SOURCE_SHA256: 9953d2b23ef972b153ddff2077481d0b32897df7782c71bfc69323c3cc2fc5b4

#==============================================================================
# ■ CG Battle Visual Polish v1.8.3b
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【修正與美化】
#  1. 戰鬥者側掛介面的每一列，都以該列對應顏色連到目前操作 battler。
#  2. battler 腳下高光環改到 battler 後方，不再蓋住角色圖。
#  3. 行動順序卡放大；目前行動者使用更大的菱形卡與脈動金邊。
#  4. Battle Status 每張角色卡改為圓角半透明面板。
#  5. Command／Skill／Item／移動／換寵等所有側掛卡片改為圓角，
#     背景由左側實色漸變為右側透明。
#
# 【腳本位置】
#  放在 CG Battle Runtime & Status Polish v1.8.3a 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattleVisualPolish_1_8_3b"] = true

module ALBERT_CG
  if const_defined?(:BATTLE_UI_VERSION)
    remove_const(:BATTLE_UI_VERSION)
  end
  BATTLE_UI_VERSION = "1.8.3b"

  [:ORDER_WINDOW_X, :ORDER_WINDOW_Y, :ORDER_WINDOW_WIDTH,
   :ORDER_WINDOW_HEIGHT, :ORDER_CARD_COUNT].each do |name|
    remove_const(name) if const_defined?(name)
  end
  ORDER_WINDOW_WIDTH = 320
  ORDER_WINDOW_HEIGHT = 88
  ORDER_WINDOW_X = 544 - ORDER_WINDOW_WIDTH
  ORDER_WINDOW_Y = BATTLE_STATUS_Y - 76
  ORDER_CARD_COUNT = 8

  module BattleInteractionPolish
    [:CURRENT_SIZE, :WAITING_SIZE, :CURRENT_X, :WAITING_START_X,
     :WAITING_STEP, :ORDER_Y, :ORDER_MOVE_FRAMES].each do |name|
      remove_const(name) if const_defined?(name)
    end
    CURRENT_SIZE = 50
    WAITING_SIZE = 36
    CURRENT_X = 0
    WAITING_START_X = 52
    WAITING_STEP = 33
    ORDER_Y = 1
    ORDER_MOVE_FRAMES = 7
  end

  module BattleVisualV183b
    ROUND_RADIUS = 8
    CARD_RADIUS = 6
    STATUS_BORDER = Color.new(92, 112, 132, 205)
    STATUS_END_ALPHA = 42
    ACTIVE_END_ALPHA = 92
    LINE_SHADOW = Color.new(0, 0, 0, 125)

    def self.apply_title
      return if $data_system == nil
      $data_system.game_title = "CG Pet Battle Prototype v1.8.3b"
    end

    def self.round_inset(row, height, radius)
      radius = [radius.to_i, 1].max
      return 0 if row >= radius && row < height - radius
      local = row < radius ? row : height - row - 1
      dy = radius - local - 0.5
      value = radius * radius - dy * dy
      value = 0 if value < 0
      dx = Math.sqrt(value)
      inset = (radius - dx).ceil
      inset = 0 if inset < 0
      return inset
    rescue
      return 0
    end

    def self.fill_round_gradient(bitmap, x, y, width, height, radius,
      color1, color2)
      return if bitmap == nil || bitmap.disposed?
      width = width.to_i
      height = height.to_i
      return if width <= 0 || height <= 0
      radius = [radius.to_i, width / 2, height / 2].min
      radius = 1 if radius < 1
      for row in 0...height
        inset = round_inset(row, height, radius)
        line_width = width - inset * 2
        next if line_width <= 0
        bitmap.gradient_fill_rect(x + inset, y + row,
          line_width, 1, color1, color2, false)
      end
    rescue
    end

    def self.draw_line(bitmap, x1, y1, x2, y2, color, thickness = 1)
      return if bitmap == nil || bitmap.disposed?
      x1 = x1.to_i
      y1 = y1.to_i
      x2 = x2.to_i
      y2 = y2.to_i
      dx = (x2 - x1).abs
      dy = (y2 - y1).abs
      steps = [dx, dy, 1].max
      for i in 0..steps
        rate = i.to_f / steps.to_f
        x = (x1 + (x2 - x1) * rate).round
        y = (y1 + (y2 - y1) * rate).round
        bitmap.fill_rect(x - thickness / 2, y - thickness / 2,
          thickness, thickness, color)
      end
    rescue
    end

    def self.line_color(type, selected, enabled)
      pair = ALBERT_CG::BattlerSidecarUI.command_type_color(type)
      base = pair == nil ? Color.new(120, 190, 220) : pair[0]
      alpha = selected ? 245 : 135
      alpha = 70 unless enabled
      return Color.new(base.red, base.green, base.blue, alpha)
    rescue
      return Color.new(120, 190, 220, selected ? 245 : 135)
    end
  end
end

#==============================================================================
# ■ Battler Sidecar card cache
#==============================================================================
module ALBERT_CG
  module BattlerSidecarUI
    def self.fixed_card(text, type, selected, enabled, icon_index = nil,
      quantity = nil)
      @card_cache = {} if @card_cache == nil
      key = [:round_v183b, text.to_s, type, selected ? 1 : 0,
        enabled ? 1 : 0, icon_index.to_i, quantity]
      bitmap = @card_cache[key]
      return bitmap if bitmap != nil && !bitmap.disposed?

      width = VERTICAL_CARD_WIDTH
      height = VERTICAL_CARD_HEIGHT
      bitmap = Bitmap.new(width, height)
      colors = selected && enabled ? command_type_color(type) : gray_colors
      left_alpha = enabled ? (selected ? 245 : 205) : 125
      right_alpha = enabled ? (selected ? 78 : 28) : 18
      c1 = Color.new(colors[0].red, colors[0].green, colors[0].blue,
        left_alpha)
      c2 = Color.new(colors[1].red, colors[1].green, colors[1].blue,
        right_alpha)
      border = selected ? FOCUS_GOLD : Color.new(36, 40, 48,
        enabled ? 185 : 105)

      ALBERT_CG::BattleVisualV183b.fill_round_gradient(bitmap,
        0, 0, width, height, ALBERT_CG::BattleVisualV183b::CARD_RADIUS,
        border, Color.new(border.red, border.green, border.blue,
        [border.alpha - 70, 20].max))
      ALBERT_CG::BattleVisualV183b.fill_round_gradient(bitmap,
        1, 1, width - 2, height - 2,
        [ALBERT_CG::BattleVisualV183b::CARD_RADIUS - 1, 1].max,
        c1, c2)

      accent = command_type_color(type)[0] rescue FOCUS_CYAN
      accent_alpha = selected ? 255 : (enabled ? 175 : 80)
      bitmap.fill_rect(3, 4, 3, height - 8,
        Color.new(accent.red, accent.green, accent.blue, accent_alpha))
      if selected
        bitmap.fill_rect(8, 2, width - 16, 1,
          Color.new(255, 250, 205, 220))
      end

      text_x = 9
      if icon_index != nil && icon_index.to_i > 0
        icon_index = icon_index.to_i
        if selected && enabled
          iconset = Cache.system("IconSet")
          source = Rect.new(icon_index % 16 * 24,
            icon_index / 16 * 24, 24, 24)
          target = Rect.new(7, 2, 18, 18)
          if defined?(ALBERT_CG::TRGSSXVisual)
            ALBERT_CG::TRGSSXVisual.stretch_blt(
              bitmap, target, iconset, source, left_alpha)
          else
            bitmap.stretch_blt(target, iconset, source, left_alpha)
          end
        else
          gray = gray_icon(icon_index)
          if gray != nil
            target = Rect.new(7, 2, 18, 18)
            if defined?(ALBERT_CG::TRGSSXVisual)
              ALBERT_CG::TRGSSXVisual.stretch_blt(
                bitmap, target, gray, gray.rect, left_alpha)
            else
              bitmap.stretch_blt(target, gray, gray.rect, left_alpha)
            end
          end
        end
        text_x = 28
      end

      right_space = quantity == nil ? 5 : 24
      old_size = bitmap.font.size
      old_bold = bitmap.font.bold
      old_color = bitmap.font.color
      bitmap.font.bold = selected
      fit_font(bitmap, text.to_s, width - text_x - right_space,
        FONT_SIZE, 9)
      bitmap.font.color = Color.new(0, 0, 0, enabled ? 220 : 145)
      bitmap.draw_text(text_x + 1, 1, width - text_x - right_space,
        height - 2, text.to_s, 0)
      bitmap.font.color = enabled ? Color.new(255, 255, 255) :
        Color.new(178, 178, 182)
      bitmap.draw_text(text_x, 0, width - text_x - right_space,
        height - 2, text.to_s, 0)

      if quantity != nil
        bitmap.font.size = 9
        bitmap.font.bold = true
        qtext = quantity.to_i.to_s
        bitmap.font.color = Color.new(0, 0, 0, 210)
        bitmap.draw_text(width - 23, 2, 19, height - 3, qtext, 2)
        bitmap.font.color = Color.new(255, 255, 255)
        bitmap.draw_text(width - 24, 1, 19, height - 3, qtext, 2)
      end
      bitmap.font.size = old_size
      bitmap.font.bold = old_bold
      bitmap.font.color = old_color
      @card_cache[key] = bitmap
      return bitmap
    end
  end
end

#==============================================================================
# ■ Sidecar line information
#==============================================================================
class Window_ActorCommand < Window_Command
  def cg_v183b_line_specs
    result = []
    count = @commands == nil ? 0 : @commands.size
    for i in 0...count
      slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
        @cg_v182b_open_tick, i, count)
      result.push([i, cg_v182_command_type(i), i == @index,
        cg_v182_command_enabled(i), slide_x, opacity])
    end
    return result
  rescue
    return []
  end
end

class Window_PartyCommand < Window_Command
  def cg_v183b_line_specs
    result = []
    count = @commands == nil ? 0 : @commands.size
    for i in 0...count
      slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
        @cg_v182b_open_tick, i, count)
      result.push([i, cg_v182_party_type(i), i == @index,
        cg_v182_party_enabled(i), slide_x, opacity])
    end
    return result
  rescue
    return []
  end
end

class Window_Skill < Window_Selectable
  def cg_v183b_line_specs
    return [] unless @cg_v182_sidecar_battle
    result = []
    top = @cg_v182b_top_index.to_i
    finish = [top + ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS,
      @item_max.to_i].min
    local = 0
    for i in top...finish
      skill = @data == nil ? nil : @data[i]
      enabled = skill != nil && @actor.skill_can_use?(skill)
      slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
        @cg_v182b_open_tick, local, finish - top)
      result.push([local, :skill_row, i == @index,
        enabled, slide_x, opacity])
      local += 1
    end
    return result
  rescue
    return []
  end
end

class Window_Item < Window_Selectable
  def cg_v183b_line_specs
    return [] unless @cg_v182_sidecar_battle
    result = []
    top = @cg_v182b_top_index.to_i
    finish = [top + ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS,
      @item_max.to_i].min
    local = 0
    for i in top...finish
      item = @data == nil ? nil : @data[i]
      enabled = item != nil && enable?(item)
      slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
        @cg_v182b_open_tick, local, finish - top)
      result.push([local, :item_row, i == @index,
        enabled, slide_x, opacity])
      local += 1
    end
    return result
  rescue
    return []
  end
end

class Window_CG_BattleSidecarList < Window_Selectable
  def cg_v183b_line_specs
    result = []
    top = @top_index.to_i
    finish = [top + ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS,
      @item_max.to_i].min
    local = 0
    for i in top...finish
      data = @entries == nil ? nil : @entries[i]
      type = data != nil && data[:type] != nil ? data[:type] : @type
      type = :pet_switch if type == :switch || type == :recall
      slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
        @open_tick, local, finish - top)
      result.push([local, type, i == @index,
        enabled?(i), slide_x, opacity])
      local += 1
    end
    return result
  rescue
    return []
  end
end

#==============================================================================
# ■ Sprite_CG_BattlerFocus
#==============================================================================
class Sprite_CG_BattlerFocus
  def initialize
    @ring = Sprite.new
    @ring.bitmap = Bitmap.new(72, 72)
    @ring.ox = 36
    @ring.oy = 36
    @ring.z = 80
    @ring.zoom_y = 0.46
    @ring.visible = false

    @line_layer = Sprite.new
    @line_layer.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    @line_layer.x = 0
    @line_layer.y = 0
    @line_layer.z = 539
    @line_layer.visible = false
    @cg_v183_ring_type = nil
    cg_v183_draw_ring(:attack)
  end

  def hide
    @ring.visible = false if @ring != nil
    if @line_layer != nil
      @line_layer.visible = false
      @line_layer.bitmap.clear if @line_layer.bitmap != nil &&
        !@line_layer.bitmap.disposed?
    end
  end

  def update(anchor, window, type = nil, battler_z = nil)
    if anchor == nil || window == nil || !window.visible
      hide
      return
    end
    type = :attack if type == nil
    cg_v183_draw_ring(type) if @cg_v183_ring_type != type
    center_x = anchor[4].to_i
    foot_y = anchor[3].to_i - 2
    @ring.x = center_x
    @ring.y = foot_y
    @ring.z = battler_z == nil ? 80 : [battler_z.to_i - 1, 1].max
    @ring.opacity = 170 + ((Graphics.frame_count / 3) % 2) * 55
    @ring.visible = true

    bitmap = @line_layer.bitmap
    bitmap.clear
    specs = window.respond_to?(:cg_v183b_line_specs) ?
      window.cg_v183b_line_specs : []
    specs = [[0, type, true, true, 0, 255]] if specs == nil || specs.empty?
    right_side = window.x.to_i >= center_x
    ring_x = right_side ? center_x + 27 : center_x - 27
    ring_y = foot_y

    for spec in specs
      row, row_type, selected, enabled, slide_x, row_opacity = spec
      card_y = window.y.to_i + 16 + row.to_i *
        (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
        ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP)
      finish_y = card_y + ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT / 2
      if right_side
        finish_x = window.x.to_i + 16 + slide_x.to_i
      else
        finish_x = window.x.to_i + 16 +
          ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_WIDTH - slide_x.to_i
      end
      color = ALBERT_CG::BattleVisualV183b.line_color(
        row_type, selected, enabled)
      alpha = color.alpha * row_opacity.to_i / 255
      color = Color.new(color.red, color.green, color.blue, alpha)
      shadow = Color.new(0, 0, 0, [alpha / 2, 35].max)
      ALBERT_CG::BattleVisualV183b.draw_line(bitmap,
        ring_x, ring_y + 1, finish_x, finish_y + 1, shadow,
        selected ? 4 : 3)
      ALBERT_CG::BattleVisualV183b.draw_line(bitmap,
        ring_x, ring_y, finish_x, finish_y, color,
        selected ? 3 : 2)
      bitmap.fill_rect(finish_x - 2, finish_y - 2,
        selected ? 5 : 4, selected ? 5 : 4, color)
    end
    @line_layer.opacity = 255
    @line_layer.visible = true
  rescue
    hide
  end

  def dispose
    if @ring != nil
      @ring.bitmap.dispose if @ring.bitmap != nil && !@ring.bitmap.disposed?
      @ring.dispose unless @ring.disposed?
    end
    if @line_layer != nil
      @line_layer.bitmap.dispose if @line_layer.bitmap != nil &&
        !@line_layer.bitmap.disposed?
      @line_layer.dispose unless @line_layer.disposed?
    end
  end
end

#==============================================================================
# ■ Battle Status rounded cards
#==============================================================================
class Window_BattleStatus < Window_Selectable
  def cg_draw_status_slot(index, actor)
    rect = item_rect(index)
    self.contents.clear_rect(rect.x, rect.y, rect.width, rect.height)
    pair_number = actor == nil ? (index / 2 + 1) :
      ALBERT_CG.cg_ui_pair_number(actor)
    pair_number = index / 2 + 1 if pair_number.to_i <= 0
    pair_color = cg_pair_color(pair_number)
    selected = actor != nil && index == @index
    pulse = (Graphics.frame_count / 5) % 2

    panel_start = selected ? ALBERT_CG::BattleStatusV183a::PANEL_ACTIVE :
      ((index / 2) % 2 == 0 ? ALBERT_CG::BattleStatusV183a::PANEL_NORMAL :
      ALBERT_CG::BattleStatusV183a::PANEL_ALT)
    end_alpha = selected ? ALBERT_CG::BattleVisualV183b::ACTIVE_END_ALPHA :
      ALBERT_CG::BattleVisualV183b::STATUS_END_ALPHA
    panel_end = Color.new(panel_start.red, panel_start.green,
      panel_start.blue, end_alpha)
    border = selected ? (pulse == 0 ?
      ALBERT_CG::BattleStatusV183a::ACTIVE_GOLD :
      ALBERT_CG::BattleStatusV183a::ACTIVE_LIGHT) :
      Color.new(pair_color.red, pair_color.green, pair_color.blue, 190)

    ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
      rect.x + 1, rect.y + 1, rect.width - 2, rect.height - 2,
      ALBERT_CG::BattleVisualV183b::ROUND_RADIUS, border,
      Color.new(border.red, border.green, border.blue, 72))
    ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
      rect.x + 3, rect.y + 3, rect.width - 6, rect.height - 6,
      ALBERT_CG::BattleVisualV183b::ROUND_RADIUS - 2,
      panel_start, panel_end)

    if index % 2 == 0
      bar_width = [rect.width * 2 - 10,
        self.contents.width - rect.x - 5].min
      ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
        rect.x + 5, rect.y + rect.height - 5, bar_width, 2, 1,
        pair_color, Color.new(pair_color.red, pair_color.green,
        pair_color.blue, 45))
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

    if actor.dead?
      ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
        rect.x + 3, rect.y + 3, rect.width - 6, rect.height - 6,
        ALBERT_CG::BattleVisualV183b::ROUND_RADIUS - 2,
        Color.new(0, 0, 0, 115), Color.new(0, 0, 0, 55))
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
end

#==============================================================================
# ■ Scene_Battle focus z and bigger order window
#==============================================================================
class Scene_Battle < Scene_Base
  def cg_v182b_update_focus
    return if @cg_v182b_focus == nil
    window = cg_v182b_focus_window
    battler = cg_v182b_focus_battler(window)
    if window == nil || battler == nil
      @cg_v182b_focus.hide
      return
    end
    anchor = cg_v182_sidecar_anchor(battler)
    battler_z = nil
    if @spriteset != nil &&
       @spriteset.respond_to?(:cg_v171_find_battler_sprite)
      sprite = @spriteset.cg_v171_find_battler_sprite(battler)
      battler_z = sprite.z if sprite != nil && sprite.respond_to?(:z)
    end
    @cg_v182b_focus.update(anchor, window,
      cg_v183_focus_type(window), battler_z)
  rescue
    @cg_v182b_focus.hide if @cg_v182b_focus != nil
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  unless method_defined?(:albert_cg_v183b_load_database)
    alias albert_cg_v183b_load_database load_database
  end

  def load_database
    albert_cg_v183b_load_database
    ALBERT_CG::BattleVisualV183b.apply_title
  end
end
