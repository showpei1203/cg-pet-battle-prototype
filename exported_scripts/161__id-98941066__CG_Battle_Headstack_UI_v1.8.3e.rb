# RMVX_SCRIPT_INDEX: 161
# RMVX_SCRIPT_ID: 98941066
# RMVX_SCRIPT_NAME: CG Battle Headstack UI v1.8.3e
# RMVX_SOURCE_SHA256: 1b6d54ea03ca6f4e85821020911e0aafcdefa196e7d6d60085a124fa4d78f93a

#==============================================================================
# ■ CG Battle Headstack UI v1.8.3e
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【本版調整】
#  1. Battle Command、Skill、Item、移動與換寵清單最多同時顯示 4 項。
#  2. 選項超過 4 項時，以 ▲／▼ 清楚提示仍可上下捲動。
#  3. 選單改放在目前 battler 頭頂；第 4 個可見選項的底端位於頭頂上方。
#  4. 目前選中項目以水平→垂直→水平的直角折線連到 battler 高光圈。
#  5. 保留既有圓角、漸變半透明卡片與逐列滑入動畫。
#
# 【腳本位置】
#  放在 CG Battle Window & Link Polish v1.8.3d 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattleHeadstackUI_1_8_3e"] = true

module ALBERT_CG
  if const_defined?(:BATTLE_UI_VERSION)
    remove_const(:BATTLE_UI_VERSION)
  end
  BATTLE_UI_VERSION = "1.8.3e"

  module BattlerSidecarUI
    remove_const(:SIDE_MAX_ROWS) if const_defined?(:SIDE_MAX_ROWS)
    remove_const(:SIDE_WINDOW_WIDTH) if const_defined?(:SIDE_WINDOW_WIDTH)
    SIDE_MAX_ROWS = 4
    SIDE_WINDOW_WIDTH = VERTICAL_CARD_WIDTH + 44
    SCROLL_LANE_WIDTH = 12
    HEAD_GAP = 4

    def self.visible_rows(item_count)
      count = item_count.to_i
      count = 1 if count < 1
      return [count, SIDE_MAX_ROWS].min
    end

    def self.window_height_for(item_count)
      rows = visible_rows(item_count)
      return rows * (VERTICAL_CARD_HEIGHT + VERTICAL_GAP) + 32
    end

    def self.normalize_top_index(index, top_index, item_count)
      item_count = item_count.to_i
      return 0 if item_count <= SIDE_MAX_ROWS
      index = index.to_i
      index = 0 if index < 0
      index = item_count - 1 if index >= item_count
      top_index = top_index.to_i
      if index < top_index
        top_index = index
      elsif index >= top_index + SIDE_MAX_ROWS
        top_index = index - SIDE_MAX_ROWS + 1
      end
      maximum = [item_count - SIDE_MAX_ROWS, 0].max
      top_index = maximum if top_index > maximum
      top_index = 0 if top_index < 0
      return top_index
    end

    def self.draw_scroll_arrows(bitmap, top_index, item_count)
      return if bitmap == nil || bitmap.disposed?
      return if item_count.to_i <= SIDE_MAX_ROWS
      old_size = bitmap.font.size
      old_bold = bitmap.font.bold
      old_color = bitmap.font.color
      bitmap.font.size = 11
      bitmap.font.bold = true
      x = VERTICAL_CARD_WIDTH + 1
      width = [bitmap.width - x, 10].max
      shadow = Color.new(0, 0, 0, 220)
      light = Color.new(255, 232, 112, 255)
      if top_index.to_i > 0
        bitmap.font.color = shadow
        bitmap.draw_text(x + 1, 1, width, 12, "▲", 1)
        bitmap.font.color = light
        bitmap.draw_text(x, 0, width, 12, "▲", 1)
      end
      if top_index.to_i + SIDE_MAX_ROWS < item_count.to_i
        y = bitmap.height - 12
        bitmap.font.color = shadow
        bitmap.draw_text(x + 1, y + 1, width, 12, "▼", 1)
        bitmap.font.color = light
        bitmap.draw_text(x, y, width, 12, "▼", 1)
      end
      bitmap.font.size = old_size
      bitmap.font.bold = old_bold
      bitmap.font.color = old_color
    end
  end

  module BattleHeadstackV183e
    def self.apply_title
      return if $data_system == nil
      $data_system.game_title = "CG Pet Battle Prototype v1.8.3e"
    end
  end
end

#==============================================================================
# ■ Window_ActorCommand
#==============================================================================
class Window_ActorCommand < Window_Command
  def cg_v183e_update_top_index
    count = @commands == nil ? 0 : @commands.size
    @cg_v183e_top_index = ALBERT_CG::BattlerSidecarUI.normalize_top_index(
      @index, @cg_v183e_top_index, count)
  end

  def cg_v182_reset_sidecar
    count = @commands == nil ? 0 : @commands.size
    self.width = ALBERT_CG::BattlerSidecarUI::SIDE_WINDOW_WIDTH
    self.height = ALBERT_CG::BattlerSidecarUI.window_height_for(count)
    self.opacity = 0
    self.back_opacity = 0
    self.contents_opacity = 255
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    @column_max = 1
    @cg_v183e_top_index = 0
    @cg_v182b_open_tick = 0
    @cg_v182b_open_total = ALBERT_CG::BattlerSidecarUI.open_total(
      ALBERT_CG::BattlerSidecarUI.visible_rows(count))
    create_contents
    refresh
  end

  def refresh
    unless @cg_v182_ready
      return super
    end
    create_contents if self.contents == nil || self.contents.disposed?
    self.contents.clear
    return if @commands == nil
    count = @commands.size
    cg_v183e_update_top_index
    top = @cg_v183e_top_index.to_i
    finish = [top + ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, count].min
    local = 0
    for i in top...finish
      selected = i == @index
      enabled = cg_v182_command_enabled(i)
      card = ALBERT_CG::BattlerSidecarUI.fixed_card(
        @commands[i], cg_v182_command_type(i), selected, enabled)
      slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
        @cg_v182b_open_tick, local, finish - top)
      y = local * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
        ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP)
      self.contents.blt(slide_x, y, card, card.rect, opacity)
      local += 1
    end
    ALBERT_CG::BattlerSidecarUI.draw_scroll_arrows(
      self.contents, top, count)
    update_cursor
  end

  unless method_defined?(:albert_cg_v183e_actor_index_set)
    alias albert_cg_v183e_actor_index_set index=
  end
  def index=(value)
    albert_cg_v183e_actor_index_set(value)
    old_top = @cg_v183e_top_index
    cg_v183e_update_top_index
    refresh if @cg_v182_ready && old_top != @cg_v183e_top_index
  end

  def cg_v183e_selected_line_info
    count = @commands == nil ? 0 : @commands.size
    return nil if count <= 0 || @index == nil || @index < 0
    cg_v183e_update_top_index
    local = @index.to_i - @cg_v183e_top_index.to_i
    return nil if local < 0 || local >= ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS
    slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
      @cg_v182b_open_tick, local,
      [count - @cg_v183e_top_index.to_i,
       ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS].min)
    return [local, cg_v182_command_type(@index),
      cg_v182_command_enabled(@index), slide_x, opacity]
  rescue
    return nil
  end
end

#==============================================================================
# ■ Window_PartyCommand
#==============================================================================
class Window_PartyCommand < Window_Command
  def cg_v183e_update_top_index
    count = @commands == nil ? 0 : @commands.size
    @cg_v183e_top_index = ALBERT_CG::BattlerSidecarUI.normalize_top_index(
      @index, @cg_v183e_top_index, count)
  end

  def cg_v182_reset_sidecar
    count = @commands == nil ? 0 : @commands.size
    self.width = ALBERT_CG::BattlerSidecarUI::SIDE_WINDOW_WIDTH
    self.height = ALBERT_CG::BattlerSidecarUI.window_height_for(count)
    self.opacity = 0
    self.back_opacity = 0
    self.contents_opacity = 255
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    @column_max = 1
    @cg_v183e_top_index = 0
    @cg_v182b_open_tick = 0
    @cg_v182b_open_total = ALBERT_CG::BattlerSidecarUI.open_total(
      ALBERT_CG::BattlerSidecarUI.visible_rows(count))
    create_contents
    refresh
  end

  def refresh
    unless @cg_v182_ready
      return super
    end
    create_contents if self.contents == nil || self.contents.disposed?
    self.contents.clear
    return if @commands == nil
    count = @commands.size
    cg_v183e_update_top_index
    top = @cg_v183e_top_index.to_i
    finish = [top + ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, count].min
    local = 0
    for i in top...finish
      selected = i == @index
      enabled = cg_v182_party_enabled(i)
      card = ALBERT_CG::BattlerSidecarUI.fixed_card(
        @commands[i], cg_v182_party_type(i), selected, enabled)
      slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
        @cg_v182b_open_tick, local, finish - top)
      y = local * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
        ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP)
      self.contents.blt(slide_x, y, card, card.rect, opacity)
      local += 1
    end
    ALBERT_CG::BattlerSidecarUI.draw_scroll_arrows(
      self.contents, top, count)
    update_cursor
  end

  unless method_defined?(:albert_cg_v183e_party_index_set)
    alias albert_cg_v183e_party_index_set index=
  end
  def index=(value)
    albert_cg_v183e_party_index_set(value)
    old_top = @cg_v183e_top_index
    cg_v183e_update_top_index
    refresh if @cg_v182_ready && old_top != @cg_v183e_top_index
  end

  def cg_v183e_selected_line_info
    count = @commands == nil ? 0 : @commands.size
    return nil if count <= 0 || @index == nil || @index < 0
    cg_v183e_update_top_index
    local = @index.to_i - @cg_v183e_top_index.to_i
    slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
      @cg_v182b_open_tick, local,
      [count - @cg_v183e_top_index.to_i,
       ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS].min)
    return [local, cg_v182_party_type(@index),
      cg_v182_party_enabled(@index), slide_x, opacity]
  rescue
    return nil
  end
end

#==============================================================================
# ■ Skill / Item vertical windows
#==============================================================================
module CG_BattleSidecarVertical
  def cg_v182b_draw_scroll_mark
    return unless cg_v182_sidecar_battle?
    ALBERT_CG::BattlerSidecarUI.draw_scroll_arrows(
      self.contents, @cg_v182b_top_index.to_i, @item_max.to_i)
  end
end

class Window_Skill < Window_Selectable
  def cg_v183e_selected_line_info
    return nil unless @cg_v182_sidecar_battle
    top = @cg_v182b_top_index.to_i
    local = @index.to_i - top
    return nil if local < 0 || local >= ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS
    skill = @data == nil ? nil : @data[@index]
    enabled = skill != nil && @actor.skill_can_use?(skill)
    slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
      @cg_v182b_open_tick, local,
      [[@item_max.to_i - top, 1].max,
       ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS].min)
    return [local, :skill_row, enabled, slide_x, opacity]
  rescue
    return nil
  end
end

class Window_Item < Window_Selectable
  def cg_v183e_selected_line_info
    return nil unless @cg_v182_sidecar_battle
    top = @cg_v182b_top_index.to_i
    local = @index.to_i - top
    return nil if local < 0 || local >= ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS
    item = @data == nil ? nil : @data[@index]
    enabled = item != nil && enable?(item)
    slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
      @cg_v182b_open_tick, local,
      [[@item_max.to_i - top, 1].max,
       ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS].min)
    return [local, :item_row, enabled, slide_x, opacity]
  rescue
    return nil
  end
end

#==============================================================================
# ■ Window_CG_BattleSidecarList
#==============================================================================
class Window_CG_BattleSidecarList < Window_Selectable
  unless method_defined?(:albert_cg_v183e_popup_refresh)
    alias albert_cg_v183e_popup_refresh refresh
  end
  def refresh
    albert_cg_v183e_popup_refresh
    ALBERT_CG::BattlerSidecarUI.draw_scroll_arrows(
      self.contents, @top_index.to_i, @item_max.to_i)
  end

  def cg_v183e_selected_line_info
    top = @top_index.to_i
    local = @index.to_i - top
    return nil if local < 0 || local >= ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS
    data = @entries == nil ? nil : @entries[@index]
    type = data != nil && data[:type] != nil ? data[:type] : @type
    type = :pet_switch if type == :switch || type == :recall
    slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
      @open_tick, local,
      [[@item_max.to_i - top, 1].max,
       ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS].min)
    return [local, type, enabled?(@index), slide_x, opacity]
  rescue
    return nil
  end
end

#==============================================================================
# ■ Scene_Battle：選單放在 battler 頭頂
#==============================================================================
class Scene_Battle < Scene_Base
  def cg_v183e_headstack_origin(window, battler)
    return [0, 0] if window == nil || battler == nil
    anchor = cg_v182_sidecar_anchor(battler)
    return [0, 0] if anchor == nil
    card_width = ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_WIDTH
    center_x = anchor[4].to_i
    head_y = anchor[1].to_i
    x = center_x - 16 - card_width / 2
    maximum_x = Graphics.width - window.width
    x = maximum_x if x > maximum_x
    x = 0 if x < 0

    rows = (window.height.to_i - 32) /
      (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
       ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP)
    rows = 1 if rows < 1
    rows = ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS if
      rows > ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS
    visual_height = 16 + rows *
      (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
       ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP) -
      ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP
    y = head_y - ALBERT_CG::BattlerSidecarUI::HEAD_GAP - visual_height
    y = 0 if y < 0
    return [x, y]
  rescue
    return [0, 0]
  end

  def cg_v182b_sidecar_origin(battler)
    height = ALBERT_CG::BattlerSidecarUI.window_height_for(
      ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS)
    proxy = Struct.new(:width, :height).new(
      ALBERT_CG::BattlerSidecarUI::SIDE_WINDOW_WIDTH, height)
    return cg_v183e_headstack_origin(proxy, battler)
  rescue
    return [0, 0]
  end

  def cg_v182_place_vertical_sidecar(window, battler)
    return if window == nil || battler == nil
    x, y = cg_v183e_headstack_origin(window, battler)
    window.x = x
    window.y = y
  end

  def cg_v182_place_row_window(window)
    return if window == nil || @active_battler == nil
    cg_v182_place_vertical_sidecar(window, @active_battler)
  end

  def cg_v182b_sidecar_origin_for_window(window, battler)
    return cg_v183e_headstack_origin(window, battler)
  end

  # Popup lists use the same headstack position and do not fall back to the
  # older right-side origin.
  def cg_run_battle_popup(window, help_text)
    help = Window_Help.new
    help.set_text(help_text, 1)
    help.z = 500
    x, y = cg_v183e_headstack_origin(window, @active_battler)
    window.x = x
    window.y = y
    window.z = 540
    window.active = true
    window.visible = true
    @actor_command_window.active = false
    @actor_command_window.visible = false
    @cg_v182b_popup_window = window
    result = -1
    loop do
      update_basic
      window.update
      if Input.trigger?(Input::B)
        Sound.play_cancel
        result = -1
        break
      elsif Input.trigger?(Input::C)
        if window.respond_to?(:enabled?) && !window.enabled?(window.index)
          Sound.play_buzzer
          next
        end
        result = window.index
        break
      end
    end
    @cg_v182b_popup_window = nil
    window.active = false
    window.dispose
    help.dispose
    return result
  end
end

#==============================================================================
# ■ Sprite_CG_BattlerFocus：選中卡片的直角折線
#==============================================================================
class Sprite_CG_BattlerFocus
  def update(anchor, window, type = nil, battler_z = nil)
    if anchor == nil || window == nil || !window.visible
      hide
      return
    end
    info = window.respond_to?(:cg_v183e_selected_line_info) ?
      window.cg_v183e_selected_line_info : nil
    type = info == nil ? (type == nil ? :attack : type) : info[1]
    cg_v183_draw_ring(type) if @cg_v183_ring_type != type

    center_x = anchor[4].to_i
    foot_y = anchor[3].to_i - 2
    @ring.x = center_x
    @ring.y = foot_y
    @ring.z = battler_z == nil ? 80 : [battler_z.to_i - 1, 1].max
    @ring.opacity = 180 + ((Graphics.frame_count / 3) % 2) * 55
    @ring.visible = true

    bitmap = @line_layer.bitmap
    bitmap.clear
    if info == nil
      @line_layer.visible = false
      return
    end

    local, row_type, enabled, slide_x, row_opacity = info
    card_width = ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_WIDTH
    card_height = ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT
    card_gap = ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP
    card_x = window.x.to_i + 16 + slide_x.to_i
    card_y = window.y.to_i + 16 + local.to_i * (card_height + card_gap)
    target_y = card_y + card_height / 2

    # Keep the vertical trunk beside the battler, never through the sprite.
    use_right = center_x < Graphics.width / 2
    if use_right
      start_x = center_x + 27
      trunk_x = center_x + 38
      target_x = card_x + card_width
    else
      start_x = center_x - 27
      trunk_x = center_x - 38
      target_x = card_x
    end
    start_y = foot_y

    color = ALBERT_CG::BattleVisualV183b.line_color(
      row_type, true, enabled)
    opacity = row_opacity == nil ? 255 : row_opacity.to_i
    opacity = 255 if opacity > 255
    opacity = 120 if opacity < 120
    alpha = color.alpha * opacity / 255
    alpha = 220 if enabled && alpha < 220
    color = Color.new(color.red, color.green, color.blue, alpha)
    shadow = Color.new(0, 0, 0, 170)

    # Shadow: horizontal → vertical → horizontal.
    ALBERT_CG::BattleVisualV183d.axis_line(bitmap,
      start_x, start_y + 1, trunk_x, start_y + 1, shadow, 5)
    ALBERT_CG::BattleVisualV183d.axis_line(bitmap,
      trunk_x + 1, start_y, trunk_x + 1, target_y, shadow, 5)
    ALBERT_CG::BattleVisualV183d.axis_line(bitmap,
      trunk_x, target_y + 1, target_x, target_y + 1, shadow, 5)

    ALBERT_CG::BattleVisualV183d.axis_line(bitmap,
      start_x, start_y, trunk_x, start_y, color, 3)
    ALBERT_CG::BattleVisualV183d.axis_line(bitmap,
      trunk_x, start_y, trunk_x, target_y, color, 3)
    ALBERT_CG::BattleVisualV183d.axis_line(bitmap,
      trunk_x, target_y, target_x, target_y, color, 3)
    bitmap.fill_rect(trunk_x - 2, target_y - 2, 5, 5, color)
    bitmap.fill_rect(target_x - 2, target_y - 2, 5, 5,
      ALBERT_CG::BattlerSidecarUI::FOCUS_GOLD)

    @line_layer.x = 0
    @line_layer.y = 0
    @line_layer.z = 539
    @line_layer.opacity = 255
    @line_layer.visible = true
  rescue
    @ring.visible = true if @ring != nil
    if @line_layer != nil
      @line_layer.visible = false
      @line_layer.bitmap.clear if @line_layer.bitmap != nil &&
        !@line_layer.bitmap.disposed?
    end
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  unless method_defined?(:albert_cg_v183e_load_database)
    alias albert_cg_v183e_load_database load_database
  end
  def load_database
    albert_cg_v183e_load_database
    ALBERT_CG::BattleHeadstackV183e.apply_title
  end
end
