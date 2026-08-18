# RMVX_SCRIPT_INDEX: 155
# RMVX_SCRIPT_ID: 0
# RMVX_SCRIPT_NAME: CG Battler Sidecar UI v1.8.2b
# RMVX_SOURCE_SHA256: e56511e1da9e83e5822819eb05220009b6fc43cd7e85dd3e65b22119e050eecb

#==============================================================================
# ■ CG Battler Sidecar UI v1.8.2b
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2
# 專案：CG Pet Battle Prototype
#
# 【正式名稱】CG Battler Sidecar UI（戰鬥者側掛介面）
#
# 【設計】
#  - Command／Fight-Escape：跟隨 battler 右側，自上而下排列。
#  - 選中項目保留彩色；未選中項目即時轉為灰階。
#  - Skill／Item：跟隨目前 battler，單排最多顯示 8 格。
#  - 進場／切換使用 5 幀短滑入動畫，參考「子選項 Final VX」的
#    位圖快取與移動概念，但不沿用其 30 幀等待與多層子選單架構。
#  - 行動順序：完全透明，只留下平面卡片；最左側為 NOW 標記，
#    後續行動卡由右往左滑入。
#
# 【相容】
#  - 保留 @commands、@cg_command_types、index、cg_command_enabled?。
#  - 不修改雙指令、捕捉、換寵、移動、傷害與速度規則。
#  - TRGSSX 缺少時仍可使用 RGSS2 原生繪圖。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattlerSidecarUI_1_8_2b"] = true

module ALBERT_CG
  if const_defined?(:BATTLE_UI_VERSION)
    remove_const(:BATTLE_UI_VERSION)
  end
  BATTLE_UI_VERSION = "1.8.2b"

  module BattlerSidecarUI
    VERTICAL_CARD_WIDTH = 80
    VERTICAL_CARD_HEIGHT = 22
    VERTICAL_GAP = 2
    VERTICAL_PADDING = 8
    FONT_SIZE = 12
    OPEN_FRAMES = 5
    SELECT_FRAMES = 3

    ROW_VISIBLE = 8
    ROW_CARD_WIDTH = 36
    ROW_CARD_HEIGHT = 36
    ROW_GAP = 1
    ROW_PADDING = 6
    ROW_WINDOW_WIDTH = ROW_VISIBLE * (ROW_CARD_WIDTH + ROW_GAP) + 56
    ROW_WINDOW_HEIGHT = ROW_CARD_HEIGHT + 32

    ORDER_MARKER_WIDTH = 34
    ORDER_CARD_WIDTH = 30
    ORDER_VISIBLE = 8
    ORDER_SLIDE_FRAMES = 5

    @card_cache = {}
    @gray_icon_cache = {}
    @blank_windowskin = nil

    def self.blank_windowskin
      if @blank_windowskin == nil || @blank_windowskin.disposed?
        @blank_windowskin = Bitmap.new(128, 128)
      end
      return @blank_windowskin
    end

    def self.command_type_color(type)
      case type
      when :attack then return [Color.new(216, 82, 66), Color.new(132, 38, 34)]
      when :skill then return [Color.new(70, 142, 218), Color.new(34, 72, 132)]
      when :guard then return [Color.new(88, 178, 124), Color.new(38, 104, 70)]
      when :item then return [Color.new(208, 170, 72), Color.new(128, 88, 30)]
      when :capture then return [Color.new(196, 92, 168), Color.new(116, 42, 94)]
      when :move then return [Color.new(66, 176, 176), Color.new(28, 100, 106)]
      when :pet_switch, :switch_pet then return [Color.new(162, 108, 204), Color.new(88, 48, 126)]
      when :wait then return [Color.new(132, 142, 152), Color.new(66, 72, 78)]
      when :fight then return [Color.new(216, 82, 66), Color.new(132, 38, 34)]
      when :escape then return [Color.new(122, 132, 154), Color.new(58, 64, 82)]
      when :item_row then return [Color.new(208, 170, 72), Color.new(128, 88, 30)]
      when :skill_row then return [Color.new(70, 142, 218), Color.new(34, 72, 132)]
      end
      return [Color.new(128, 142, 158), Color.new(58, 68, 80)]
    end

    def self.gray_colors
      return [Color.new(124, 124, 128), Color.new(54, 54, 58)]
    end

    def self.fit_font(bitmap, text, max_width, start_size = FONT_SIZE,
      minimum = 9)
      size = start_size
      bitmap.font.size = size
      while size > minimum && bitmap.text_size(text.to_s).width > max_width
        size -= 1
        bitmap.font.size = size
      end
      return size
    end

    def self.command_card(text, type, selected, enabled)
      key = [:command, text.to_s, type, selected ? 1 : 0, enabled ? 1 : 0]
      bitmap = @card_cache[key]
      return bitmap if bitmap != nil && !bitmap.disposed?

      width = VERTICAL_CARD_WIDTH
      height = VERTICAL_CARD_HEIGHT
      bitmap = Bitmap.new(width, height)
      colors = selected && enabled ? command_type_color(type) : gray_colors
      opacity = enabled ? 245 : 150
      c1 = Color.new(colors[0].red, colors[0].green, colors[0].blue, opacity)
      c2 = Color.new(colors[1].red, colors[1].green, colors[1].blue, opacity)
      bitmap.gradient_fill_rect(0, 1, width - 5, height - 2, c1, c2)
      bitmap.fill_rect(width - 5, 4, 5, height - 8,
        selected ? Color.new(255, 226, 112, opacity) :
          Color.new(40, 40, 44, opacity))
      if selected
        bitmap.fill_rect(0, 0, width - 5, 1, Color.new(255, 248, 194, 235))
      end

      old_size = bitmap.font.size
      old_bold = bitmap.font.bold
      old_color = bitmap.font.color
      bitmap.font.bold = selected
      fit_font(bitmap, text.to_s, width - 14, FONT_SIZE, 9)
      bitmap.font.color = Color.new(0, 0, 0, enabled ? 230 : 170)
      bitmap.draw_text(5, 1, width - 13, height - 2, text.to_s, 0)
      bitmap.font.color = enabled ? Color.new(255, 255, 255) :
        Color.new(178, 178, 182)
      bitmap.draw_text(4, 0, width - 13, height - 2, text.to_s, 0)
      bitmap.font.size = old_size
      bitmap.font.bold = old_bold
      bitmap.font.color = old_color
      @card_cache[key] = bitmap
      return bitmap
    end

    def self.gray_icon(icon_index)
      icon_index = icon_index.to_i
      bitmap = @gray_icon_cache[icon_index]
      return bitmap if bitmap != nil && !bitmap.disposed?
      bitmap = Bitmap.new(24, 24)
      iconset = Cache.system("IconSet")
      sx = icon_index % 16 * 24
      sy = icon_index / 16 * 24
      for py in 0...24
        for px in 0...24
          color = iconset.get_pixel(sx + px, sy + py)
          gray = (color.red * 30 + color.green * 59 + color.blue * 11) / 100
          bitmap.set_pixel(px, py,
            Color.new(gray, gray, gray, color.alpha))
        end
      end
      @gray_icon_cache[icon_index] = bitmap
      return bitmap
    rescue
      return nil
    end

    def self.row_card(object, selected, enabled, type, quantity = nil)
      id = object == nil ? 0 : object.id.to_i
      name = object == nil ? "" : object.name.to_s
      icon_index = object == nil ? 0 : object.icon_index.to_i
      key = [:row, object == nil ? "nil" : object.class.to_s, id, name,
        icon_index, selected ? 1 : 0, enabled ? 1 : 0, type, quantity]
      bitmap = @card_cache[key]
      return bitmap if bitmap != nil && !bitmap.disposed?

      width = ROW_CARD_WIDTH
      height = ROW_CARD_HEIGHT
      bitmap = Bitmap.new(width, height)
      colors = selected && enabled ? command_type_color(type) : gray_colors
      opacity = enabled ? 240 : 150
      c1 = Color.new(colors[0].red, colors[0].green, colors[0].blue, opacity)
      c2 = Color.new(colors[1].red, colors[1].green, colors[1].blue, opacity)
      bitmap.gradient_fill_rect(1, 1, width - 2, height - 2, c1, c2, true)
      bitmap.fill_rect(0, 0, width, 1,
        selected ? Color.new(255, 238, 142, 255) : Color.new(40, 40, 44, 180))

      if icon_index > 0
        if selected && enabled
          iconset = Cache.system("IconSet")
          source = Rect.new(icon_index % 16 * 24,
            icon_index / 16 * 24, 24, 24)
          bitmap.blt((width - 18) / 2, 2, iconset, source, 255)
        else
          gray_icon = gray_icon(icon_index)
          if gray_icon != nil
            target = Rect.new((width - 18) / 2, 2, 18, 18)
            if defined?(ALBERT_CG::TRGSSXVisual)
              ALBERT_CG::TRGSSXVisual.stretch_blt(
                bitmap, target, gray_icon, gray_icon.rect, opacity)
            else
              bitmap.stretch_blt(target, gray_icon, gray_icon.rect, opacity)
            end
          end
        end
      end

      old_size = bitmap.font.size
      old_color = bitmap.font.color
      old_bold = bitmap.font.bold
      bitmap.font.bold = selected
      fit_font(bitmap, name, width - 4, 9, 7)
      bitmap.font.color = Color.new(0, 0, 0, enabled ? 230 : 160)
      bitmap.draw_text(1, height - 15, width - 2, 14, name, 1)
      bitmap.font.color = enabled ? Color.new(255, 255, 255) :
        Color.new(175, 175, 180)
      bitmap.draw_text(0, height - 16, width - 2, 14, name, 1)
      if quantity != nil
        bitmap.font.size = 8
        bitmap.font.bold = true
        text = quantity.to_i.to_s
        bitmap.font.color = Color.new(0, 0, 0, 230)
        bitmap.draw_text(width - 17, 0, 15, 12, text, 2)
        bitmap.font.color = Color.new(255, 255, 255)
        bitmap.draw_text(width - 18, -1, 15, 12, text, 2)
      end
      bitmap.font.size = old_size
      bitmap.font.color = old_color
      bitmap.font.bold = old_bold
      @card_cache[key] = bitmap
      return bitmap
    end

    def self.clear_cache
      for bitmap in @card_cache.values
        bitmap.dispose if bitmap != nil && !bitmap.disposed?
      end
      @card_cache = {}
      for bitmap in @gray_icon_cache.values
        bitmap.dispose if bitmap != nil && !bitmap.disposed?
      end
      @gray_icon_cache = {}
    rescue
    end
  end

  def self.apply_v182_title
    $data_system.game_title = "CG Pet Battle Prototype v1.8.2" if
      $data_system != nil
  end
end

#==============================================================================
# ■ Window_ActorCommand：垂直側掛圖片選單
#==============================================================================
class Window_ActorCommand < Window_Command
  alias albert_cg_v182_sidecar_initialize initialize
  def initialize
    @cg_v182_ready = false
    albert_cg_v182_sidecar_initialize
    @cg_v182_ready = true
    cg_v182_reset_sidecar
  end

  alias albert_cg_v182_sidecar_setup setup
  def setup(actor)
    albert_cg_v182_sidecar_setup(actor)
    cg_v182_reset_sidecar
    @cg_v182_open_frames = ALBERT_CG::BattlerSidecarUI::OPEN_FRAMES
    @cg_v182_last_index = @index
    refresh
  end

  def cg_v182_reset_sidecar
    count = [@commands == nil ? 0 : @commands.size, 1].max
    self.width = ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_WIDTH + 32
    self.height = count * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
      ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP) + 32
    self.opacity = 0
    self.back_opacity = 0
    self.contents_opacity = 255
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    @column_max = 1
    create_contents
    refresh
  end

  def cg_v182_command_type(index)
    if @cg_command_types != nil && @cg_command_types[index] != nil
      return @cg_command_types[index]
    end
    return [:attack, :skill, :guard, :item][index] || :wait
  end

  def cg_v182_command_enabled(index)
    return cg_command_enabled?(index) if respond_to?(:cg_command_enabled?)
    return true
  rescue
    return true
  end

  def refresh
    unless @cg_v182_ready
      return super
    end
    create_contents if self.contents == nil || self.contents.disposed?
    self.contents.clear
    return if @commands == nil
    for i in 0...@commands.size
      selected = i == @index
      enabled = cg_v182_command_enabled(i)
      card = ALBERT_CG::BattlerSidecarUI.command_card(
        @commands[i], cg_v182_command_type(i), selected, enabled)
      base_x = selected ? 0 : 4
      open = @cg_v182_open_frames == nil ? 0 : @cg_v182_open_frames
      x = base_x + open * 7 + i * 2
      y = i * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
        ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP)
      opacity = 255 - open * 34
      opacity = 96 if opacity < 96
      self.contents.blt(x, y, card, card.rect, opacity)
    end
    update_cursor
  end

  def draw_item(index, enabled = true)
    refresh if @cg_v182_ready
  end

  def item_rect(index)
    return Rect.new(0,
      index.to_i * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
        ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP),
      ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_WIDTH,
      ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT)
  end

  def update_cursor
    self.cursor_rect.empty
  end

  def cursor_down(wrap = false)
    return if @item_max == nil || @item_max <= 0
    self.index = (@index.to_i + 1) % @item_max
  end

  def cursor_up(wrap = false)
    return if @item_max == nil || @item_max <= 0
    self.index = (@index.to_i - 1 + @item_max) % @item_max
  end

  def cursor_right(wrap = false)
    cursor_down(wrap)
  end

  def cursor_left(wrap = false)
    cursor_up(wrap)
  end

  def cursor_pagedown
  end

  def cursor_pageup
  end

  def index=(value)
    old_index = @index
    super(value)
    if @cg_v182_ready && old_index != @index
      @cg_v182_select_frames = ALBERT_CG::BattlerSidecarUI::SELECT_FRAMES
      refresh
    end
  end

  def update
    old_index = @index
    super
    changed = old_index != @index
    if changed
      @cg_v182_select_frames = ALBERT_CG::BattlerSidecarUI::SELECT_FRAMES
    end
    animating = false
    if @cg_v182_open_frames != nil && @cg_v182_open_frames > 0
      @cg_v182_open_frames -= 1
      animating = true
    end
    if @cg_v182_select_frames != nil && @cg_v182_select_frames > 0
      @cg_v182_select_frames -= 1
      animating = true
    end
    refresh if changed || animating
  end
end

#==============================================================================
# ■ Window_PartyCommand：Fight／Escape 使用同一側掛樣式
#==============================================================================
class Window_PartyCommand < Window_Command
  alias albert_cg_v182_party_initialize initialize
  def initialize
    @cg_v182_ready = false
    albert_cg_v182_party_initialize
    @cg_v182_ready = true
    cg_v182_reset_sidecar
  end

  def cg_v182_reset_sidecar
    count = [@commands == nil ? 0 : @commands.size, 1].max
    self.width = ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_WIDTH + 32
    self.height = count * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
      ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP) + 32
    self.opacity = 0
    self.back_opacity = 0
    self.contents_opacity = 255
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    @column_max = 1
    @cg_v182_open_frames = ALBERT_CG::BattlerSidecarUI::OPEN_FRAMES
    create_contents
    refresh
  end

  def cg_v182_party_type(index)
    return index.to_i == 0 ? :fight : :escape
  end

  def cg_v182_party_enabled(index)
    return true if index.to_i == 0
    return $game_troop == nil ? true : $game_troop.can_escape
  rescue
    return true
  end

  def refresh
    unless @cg_v182_ready
      return super
    end
    create_contents if self.contents == nil || self.contents.disposed?
    self.contents.clear
    return if @commands == nil
    for i in 0...@commands.size
      selected = i == @index
      enabled = cg_v182_party_enabled(i)
      card = ALBERT_CG::BattlerSidecarUI.command_card(
        @commands[i], cg_v182_party_type(i), selected, enabled)
      open = @cg_v182_open_frames == nil ? 0 : @cg_v182_open_frames
      x = (selected ? 0 : 4) + open * 7 + i * 2
      y = i * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
        ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP)
      opacity = 255 - open * 34
      opacity = 96 if opacity < 96
      self.contents.blt(x, y, card, card.rect, opacity)
    end
    update_cursor
  end

  def draw_item(index, enabled = true)
    refresh if @cg_v182_ready
  end

  def item_rect(index)
    return Rect.new(0,
      index.to_i * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
        ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP),
      ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_WIDTH,
      ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT)
  end

  def update_cursor
    self.cursor_rect.empty
  end

  def update
    old_index = @index
    super
    animating = old_index != @index
    if @cg_v182_open_frames != nil && @cg_v182_open_frames > 0
      @cg_v182_open_frames -= 1
      animating = true
    end
    refresh if animating
  end
end

#==============================================================================
# ■ Battle Skill／Item：單排 8 格圖片卡
#==============================================================================
module CG_BattleSidecarRow
  def cg_v182_sidecar_battle?
    return @cg_v182_sidecar_battle == true
  end

  def cg_v182_page_start
    index = @index == nil || @index < 0 ? 0 : @index
    return index / ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE *
      ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE
  end

  def cg_v182_setup_row_window
    self.width = ALBERT_CG::BattlerSidecarUI::ROW_WINDOW_WIDTH
    self.height = ALBERT_CG::BattlerSidecarUI::ROW_WINDOW_HEIGHT
    self.opacity = 0
    self.back_opacity = 0
    self.contents_opacity = 255
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    @column_max = ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE
    @cg_v182_open_frames = ALBERT_CG::BattlerSidecarUI::OPEN_FRAMES
    create_contents
  end

  def cg_v182_row_item_rect(index)
    local = index.to_i - cg_v182_page_start
    if local < 0 || local >= ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE
      return Rect.new(-999, 0, 1, 1)
    end
    x = local * (ALBERT_CG::BattlerSidecarUI::ROW_CARD_WIDTH +
      ALBERT_CG::BattlerSidecarUI::ROW_GAP)
    return Rect.new(x, 0,
      ALBERT_CG::BattlerSidecarUI::ROW_CARD_WIDTH,
      ALBERT_CG::BattlerSidecarUI::ROW_CARD_HEIGHT)
  end

  def cg_v182_update_row_cursor
    return self.cursor_rect.empty unless cg_v182_sidecar_battle?
    self.cursor_rect.empty
  end

  def cg_v182_row_update
    old_index = @index
    yield
    changed = old_index != @index
    if @cg_v182_open_frames != nil && @cg_v182_open_frames > 0
      @cg_v182_open_frames -= 1
      changed = true
    end
    refresh if changed
  end

  def cursor_down(wrap = false)
    if cg_v182_sidecar_battle?
      self.index = (@index + 1) % [@item_max, 1].max
    else
      super(wrap)
    end
  end

  def cursor_up(wrap = false)
    if cg_v182_sidecar_battle?
      self.index = (@index - 1 + [@item_max, 1].max) % [@item_max, 1].max
    else
      super(wrap)
    end
  end

  def cursor_pagedown
    if cg_v182_sidecar_battle?
      self.index = [@index + ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE,
        @item_max - 1].min
    else
      super
    end
  end

  def cursor_pageup
    if cg_v182_sidecar_battle?
      self.index = [@index - ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE, 0].max
    else
      super
    end
  end
end

class Window_Skill < Window_Selectable
  include CG_BattleSidecarRow

  alias albert_cg_v182_skill_previous_draw_item draw_item
  alias albert_cg_v182_skill_initialize initialize
  def initialize(x, y, width, height, actor)
    @cg_v182_sidecar_battle = $game_temp != nil && $game_temp.in_battle
    @cg_v182_ready = false
    albert_cg_v182_skill_initialize(x, y, width, height, actor)
    if @cg_v182_sidecar_battle
      cg_v182_setup_row_window
      @cg_v182_ready = true
      refresh
    end
  end

  alias albert_cg_v182_skill_normal_refresh refresh
  def refresh
    unless @cg_v182_sidecar_battle && @cg_v182_ready
      return albert_cg_v182_skill_normal_refresh
    end
    if @actor.respond_to?(:cg_skill_slot_skills)
      @data = @actor.cg_skill_slot_skills
    else
      @data = @actor.skills
    end
    @data = [] if @data == nil
    @item_max = @data.size
    @index = 0 if @item_max > 0 && (@index == nil || @index < 0)
    @index = @item_max - 1 if @item_max > 0 && @index >= @item_max
    create_contents if self.contents == nil || self.contents.disposed?
    self.contents.clear
    start_index = cg_v182_page_start
    finish_index = [start_index + ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE,
      @item_max].min
    for i in start_index...finish_index
      cg_v182_draw_skill_card(i)
    end
    cg_v182_draw_page_mark
    update_cursor
  end

  def cg_v182_draw_skill_card(index)
    skill = @data[index]
    return if skill == nil
    enabled = @actor.skill_can_use?(skill)
    selected = index == @index
    card = ALBERT_CG::BattlerSidecarUI.row_card(
      skill, selected, enabled, :skill_row, nil)
    rect = cg_v182_row_item_rect(index)
    open = @cg_v182_open_frames == nil ? 0 : @cg_v182_open_frames
    x = rect.x + open * 7 + (index - cg_v182_page_start) * 2
    opacity = 255 - open * 34
    opacity = 96 if opacity < 96
    self.contents.blt(x, rect.y, card, card.rect, opacity)
  end

  def cg_v182_draw_page_mark
    pages = (@item_max + ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE - 1) /
      ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE
    return if pages <= 1
    page = cg_v182_page_start / ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE + 1
    old_size = self.contents.font.size
    old_color = self.contents.font.color
    self.contents.font.size = 9
    self.contents.font.color = Color.new(235, 235, 240)
    self.contents.draw_text(self.contents.width - 26, 0, 26, 12,
      page.to_s + "/" + pages.to_s, 2)
    self.contents.font.size = old_size
    self.contents.font.color = old_color
  end

  def draw_item(index)
    if @cg_v182_sidecar_battle && @cg_v182_ready
      refresh
    else
      albert_cg_v182_skill_previous_draw_item(index)
    end
  end

  def item_rect(index)
    return cg_v182_row_item_rect(index) if cg_v182_sidecar_battle?
    return super(index)
  end

  def update_cursor
    return cg_v182_update_row_cursor if cg_v182_sidecar_battle?
    super
  end

  def index=(value)
    old_index = @index
    super(value)
    refresh if @cg_v182_sidecar_battle && @cg_v182_ready && old_index != @index
  end

  def update
    if @cg_v182_sidecar_battle
      old_index = @index
      super
      changed = old_index != @index
      if @cg_v182_open_frames != nil && @cg_v182_open_frames > 0
        @cg_v182_open_frames -= 1
        changed = true
      end
      refresh if changed
    else
      super
    end
  end
end

class Window_Item < Window_Selectable
  include CG_BattleSidecarRow

  alias albert_cg_v182_item_previous_draw_item draw_item
  alias albert_cg_v182_item_initialize initialize
  def initialize(x, y, width, height)
    @cg_v182_sidecar_battle = $game_temp != nil && $game_temp.in_battle
    @cg_v182_ready = false
    albert_cg_v182_item_initialize(x, y, width, height)
    if @cg_v182_sidecar_battle
      cg_v182_setup_row_window
      @cg_v182_ready = true
      refresh
    end
  end

  alias albert_cg_v182_item_normal_refresh refresh
  def refresh
    unless @cg_v182_sidecar_battle && @cg_v182_ready
      return albert_cg_v182_item_normal_refresh
    end
    @data = []
    for item in $game_party.items
      next unless include?(item)
      @data.push(item)
    end
    @data.push(nil) if include?(nil)
    @item_max = @data.size
    @index = 0 if @item_max > 0 && (@index == nil || @index < 0)
    @index = @item_max - 1 if @item_max > 0 && @index >= @item_max
    create_contents if self.contents == nil || self.contents.disposed?
    self.contents.clear
    start_index = cg_v182_page_start
    finish_index = [start_index + ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE,
      @item_max].min
    for i in start_index...finish_index
      cg_v182_draw_item_card(i)
    end
    cg_v182_draw_page_mark
    update_cursor
  end

  def cg_v182_draw_item_card(index)
    object = @data[index]
    return if object == nil
    enabled = enable?(object)
    selected = index == @index
    quantity = $game_party.item_number(object)
    card = ALBERT_CG::BattlerSidecarUI.row_card(
      object, selected, enabled, :item_row, quantity)
    rect = cg_v182_row_item_rect(index)
    open = @cg_v182_open_frames == nil ? 0 : @cg_v182_open_frames
    x = rect.x + open * 7 + (index - cg_v182_page_start) * 2
    opacity = 255 - open * 34
    opacity = 96 if opacity < 96
    self.contents.blt(x, rect.y, card, card.rect, opacity)
  end

  def cg_v182_draw_page_mark
    pages = (@item_max + ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE - 1) /
      ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE
    return if pages <= 1
    page = cg_v182_page_start / ALBERT_CG::BattlerSidecarUI::ROW_VISIBLE + 1
    old_size = self.contents.font.size
    old_color = self.contents.font.color
    self.contents.font.size = 9
    self.contents.font.color = Color.new(235, 235, 240)
    self.contents.draw_text(self.contents.width - 26, 0, 26, 12,
      page.to_s + "/" + pages.to_s, 2)
    self.contents.font.size = old_size
    self.contents.font.color = old_color
  end

  def draw_item(index)
    if @cg_v182_sidecar_battle && @cg_v182_ready
      refresh
    else
      albert_cg_v182_item_previous_draw_item(index)
    end
  end

  def item_rect(index)
    return cg_v182_row_item_rect(index) if cg_v182_sidecar_battle?
    return super(index)
  end

  def update_cursor
    return cg_v182_update_row_cursor if cg_v182_sidecar_battle?
    super
  end

  def index=(value)
    old_index = @index
    super(value)
    refresh if @cg_v182_sidecar_battle && @cg_v182_ready && old_index != @index
  end

  def update
    if @cg_v182_sidecar_battle
      old_index = @index
      super
      changed = old_index != @index
      if @cg_v182_open_frames != nil && @cg_v182_open_frames > 0
        @cg_v182_open_frames -= 1
        changed = true
      end
      refresh if changed
    else
      super
    end
  end
end

#==============================================================================
# ■ Window_CG_ActionOrder：左側 NOW 標記＋向左滑入
#==============================================================================
class Window_CG_ActionOrder < Window_Base
  alias albert_cg_v182_order_initialize initialize
  def initialize
    albert_cg_v182_order_initialize
    self.opacity = 0
    self.back_opacity = 0
    self.contents_opacity = 255
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    @cg_v182_order_signature = nil
    @cg_v182_slide_frames = 0
  end

  def cg_v182_order_key(entries)
    result = []
    for entry in entries
      battler = entry[0]
      action = entry[1]
      current = entry[2]
      result.push([battler == nil ? 0 : battler.object_id,
        action == nil ? 0 : action.object_id, current ? 1 : 0])
    end
    return result
  end

  def refresh
    self.opacity = 0
    self.back_opacity = 0
    self.contents_opacity = 255
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    entries = cg_display_entries
    if entries.empty?
      self.contents.clear
      self.visible = false
      return
    end
    signature = cg_v182_order_key(entries)
    if @cg_v182_order_signature != nil && signature != @cg_v182_order_signature
      @cg_v182_slide_frames = ALBERT_CG::BattlerSidecarUI::ORDER_SLIDE_FRAMES
    end
    @cg_v182_order_signature = signature
    cg_v182_render_order(entries)
    self.visible = true
  end

  def update
    super
    self.opacity = 0
    self.back_opacity = 0
    if @cg_v182_slide_frames != nil && @cg_v182_slide_frames > 0
      @cg_v182_slide_frames -= 1
      cg_v182_render_order(cg_display_entries)
    end
  end

  def cg_v182_render_order(entries)
    self.contents.clear
    return if entries == nil || entries.empty?
    marker_width = ALBERT_CG::BattlerSidecarUI::ORDER_MARKER_WIDTH
    card_width = ALBERT_CG::BattlerSidecarUI::ORDER_CARD_WIDTH
    maximum = [entries.size, ALBERT_CG::BattlerSidecarUI::ORDER_VISIBLE].min
    slide = @cg_v182_slide_frames == nil ? 0 : @cg_v182_slide_frames
    slide_offset = slide * card_width /
      ALBERT_CG::BattlerSidecarUI::ORDER_SLIDE_FRAMES

    # NOW 標記只用角標與下方線，不畫 Window 或完整外框。
    gold = Color.new(255, 220, 82, 245)
    self.contents.fill_rect(0, 0, 10, 2, gold)
    self.contents.fill_rect(0, 0, 2, 10, gold)
    self.contents.fill_rect(marker_width - 10, 0, 10, 2, gold)
    self.contents.fill_rect(marker_width - 2, 0, 2, 10, gold)
    self.contents.fill_rect(0, self.contents.height - 2, marker_width, 2, gold)
    old_size = self.contents.font.size
    old_color = self.contents.font.color
    old_bold = self.contents.font.bold
    self.contents.font.size = 8
    self.contents.font.bold = true
    self.contents.font.color = gold
    self.contents.draw_text(0, self.contents.height - 13, marker_width, 11,
      "NOW", 1)
    self.contents.font.size = old_size
    self.contents.font.color = old_color
    self.contents.font.bold = old_bold

    for index in 0...maximum
      battler, action, current = entries[index]
      if index == 0
        x = 2 + slide_offset
      else
        x = marker_width + (index - 1) * card_width + slide_offset
      end
      cg_v182_draw_flat_order_card(x, battler, index == 0)
    end
  end

  def cg_v182_draw_flat_order_card(x, battler, in_marker)
    width = ALBERT_CG::BattlerSidecarUI::ORDER_CARD_WIDTH - 2
    height = [self.contents.height - 2, 30].min
    y = 0
    if battler.actor?
      c1 = Color.new(66, 142, 218, 230)
      c2 = Color.new(24, 70, 132, 230)
    else
      c1 = Color.new(218, 92, 86, 230)
      c2 = Color.new(128, 34, 40, 230)
    end
    # 卡片本身不畫外框，只留平面色塊。
    self.contents.gradient_fill_rect(x, y + 1, width, height - 2, c1, c2, true)
    if in_marker
      self.contents.fill_rect(x, y + 1, width, 2,
        Color.new(255, 244, 174, 220))
    end
    draw_order_character_card(battler, x + 1, y + 1, width - 2, height - 2)
  end
end

#==============================================================================
# ■ Battle Status：更明確標記目前輸入／行動角色
#==============================================================================
class Window_BattleStatus < Window_Selectable
  alias albert_cg_v182_status_draw_slot cg_draw_status_slot
  def cg_draw_status_slot(index, actor)
    albert_cg_v182_status_draw_slot(index, actor)
    return if actor == nil || index != @index
    rect = item_rect(index)
    pulse = 170 + ((Graphics.frame_count / 4) % 2) * 70
    gold = Color.new(255, 220, 72, pulse)
    # 大型箭頭＋四角，避免只靠細框判讀。
    self.contents.fill_rect(rect.x + 2, rect.y + 1, rect.width - 4, 3, gold)
    self.contents.fill_rect(rect.x + 2, rect.y + 1, 3, 13, gold)
    self.contents.fill_rect(rect.x + rect.width - 5, rect.y + 1, 3, 13, gold)
    self.contents.fill_rect(rect.x + 2, rect.y + rect.height - 4,
      rect.width - 4, 3, gold)
    self.contents.fill_rect(rect.x + rect.width - 12, rect.y + 7, 8, 8, gold)
    self.contents.fill_rect(rect.x + rect.width - 16, rect.y + 9, 4, 4, gold)
  end
end

#==============================================================================
# ■ Scene_Battle：側掛位置與窗口配置
#==============================================================================
class Scene_Battle < Scene_Base
  def cg_v182_sidecar_anchor(battler)
    return nil if battler == nil
    return cg_v17_battler_anchor(battler) if respond_to?(:cg_v17_battler_anchor)
    x = battler.respond_to?(:screen_x) ? battler.screen_x.to_i : 0
    y = battler.respond_to?(:screen_y) ? battler.screen_y.to_i : 0
    return [x - 16, y - 32, x + 16, y, x, y - 16]
  rescue
    return nil
  end

  def cg_v182_place_vertical_sidecar(window, battler)
    return if window == nil || battler == nil
    anchor = cg_v182_sidecar_anchor(battler)
    return if anchor == nil
    x = anchor[2].to_i + 4
    maximum_x = Graphics.width - window.width + 8
    x = maximum_x if x > maximum_x
    x = 0 if x < 0
    y = anchor[5].to_i - window.height / 2
    y = 0 if y < 0
    maximum_y = ALBERT_CG::BATTLE_STATUS_Y - window.height + 8
    y = maximum_y if y > maximum_y
    window.x = x
    window.y = y
  end

  def cg_v182_primary_human
    return nil if $game_party == nil
    actor_id = defined?(ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID) ?
      ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID : 1
    for actor in $game_party.members
      return actor if actor != nil && actor.id.to_i == actor_id.to_i
    end
    return $game_actors == nil ? nil : $game_actors[actor_id]
  rescue
    return nil
  end

  # 覆寫 v1.8.1a 的 Spin 定位。
  def cg_v17_place_actor_command
    cg_v182_place_vertical_sidecar(@actor_command_window, @active_battler)
  end

  def cg_v182_place_party_command
    cg_v182_place_vertical_sidecar(@party_command_window, cg_v182_primary_human)
  end

  def cg_v182_place_row_window(window)
    return if window == nil || @active_battler == nil
    anchor = cg_v182_sidecar_anchor(@active_battler)
    return if anchor == nil
    x = anchor[2].to_i + 4
    maximum_x = Graphics.width - window.width + 8
    x = maximum_x if x > maximum_x
    x = 0 if x < 0
    y = anchor[5].to_i - window.height / 2
    y = 0 if y < 0
    maximum_y = ALBERT_CG::BATTLE_STATUS_Y - window.height + 8
    y = maximum_y if y > maximum_y
    window.x = x
    window.y = y
  end

  alias albert_cg_v182_start_skill_selection start_skill_selection
  def start_skill_selection
    result = albert_cg_v182_start_skill_selection
    if @skill_window != nil
      @skill_window.viewport = nil
      @skill_window.z = 540
      cg_v182_place_row_window(@skill_window)
    end
    return result
  end

  alias albert_cg_v182_start_item_selection start_item_selection
  def start_item_selection
    result = albert_cg_v182_start_item_selection
    if @item_window != nil
      @item_window.viewport = nil
      @item_window.z = 540
      cg_v182_place_row_window(@item_window)
    end
    return result
  end

  alias albert_cg_v182_configure_battle_windows cg_v17_configure_battle_windows
  def cg_v17_configure_battle_windows
    albert_cg_v182_configure_battle_windows
    if @actor_command_window != nil
      @actor_command_window.z = 540
      @actor_command_window.opacity = 0
      @actor_command_window.back_opacity = 0
    end
    if @party_command_window != nil
      @party_command_window.z = 540
      @party_command_window.opacity = 0
      @party_command_window.back_opacity = 0
      cg_v182_place_party_command
    end
    if @cg_action_order_window != nil
      @cg_action_order_window.opacity = 0
      @cg_action_order_window.back_opacity = 0
      @cg_action_order_window.windowskin =
        ALBERT_CG::BattlerSidecarUI.blank_windowskin
    end
  end

  alias albert_cg_v182_update_window_visibility cg_v17_update_window_visibility
  def cg_v17_update_window_visibility
    albert_cg_v182_update_window_visibility
    message_visible = cg_v180a_message_visible?

    if @party_command_window != nil
      @party_command_window.visible = @party_command_window.active &&
        !message_visible
      cg_v182_place_party_command if @party_command_window.visible
    end
    if @actor_command_window != nil && @actor_command_window.visible
      cg_v182_place_vertical_sidecar(@actor_command_window, @active_battler)
    end
    if @skill_window != nil
      cg_v182_place_row_window(@skill_window)
    end
    if @item_window != nil
      cg_v182_place_row_window(@item_window)
    end
    if @cg_action_order_window != nil
      @cg_action_order_window.opacity = 0
      @cg_action_order_window.back_opacity = 0
    end

    # 主狀態列直接追蹤目前 battler，不再只依賴舊指令流程偶爾設定 index。
    if @status_window != nil && @status_window != @target_actor_window
      new_index = -1
      if @active_battler != nil && @active_battler.actor? && $game_party != nil
        new_index = $game_party.members.index(@active_battler)
        new_index = -1 if new_index == nil
      end
      @status_window.index = new_index if @status_window.index != new_index
    end
  end

  alias albert_cg_v182_terminate terminate
  def terminate
    albert_cg_v182_terminate
    ALBERT_CG::BattlerSidecarUI.clear_cache
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  alias albert_cg_v182_sidecar_load_database load_database
  def load_database
    albert_cg_v182_sidecar_load_database
    ALBERT_CG.apply_v182_title
  end

  alias albert_cg_v182_sidecar_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v182_sidecar_load_bt_database
    ALBERT_CG.apply_v182_title
  end
end


#==============================================================================
# ■ v1.8.2b Interaction Polish
#------------------------------------------------------------------------------
#  1. 行動序列：目前行動卡會從等待列滑入最左側 NOW 槽。
#  2. Battle Command：所有卡片固定同寬同高，依序由左滑入。
#  3. Skill／Item／移動／換寵：統一為相同位置的垂直側掛清單。
#  4. 操作焦點：目前 battler 顯示脈動光環，並以連接線連到側掛選單。
#==============================================================================

module ALBERT_CG
  module BattlerSidecarUI
    # 統一主選單與子選單的尺寸。所有卡片以同一寬度繪製，避免文字長短
    # 造成背景看起來忽大忽小。
    remove_const(:VERTICAL_CARD_WIDTH) if const_defined?(:VERTICAL_CARD_WIDTH)
    remove_const(:VERTICAL_CARD_HEIGHT) if const_defined?(:VERTICAL_CARD_HEIGHT)
    remove_const(:VERTICAL_GAP) if const_defined?(:VERTICAL_GAP)
    remove_const(:OPEN_FRAMES) if const_defined?(:OPEN_FRAMES)
    remove_const(:SELECT_FRAMES) if const_defined?(:SELECT_FRAMES)
    remove_const(:ROW_VISIBLE) if const_defined?(:ROW_VISIBLE)
    VERTICAL_CARD_WIDTH = 120
    VERTICAL_CARD_HEIGHT = 22
    VERTICAL_GAP = 2
    OPEN_FRAMES = 6
    SELECT_FRAMES = 2
    ROW_VISIBLE = 8

    SIDE_WINDOW_WIDTH = VERTICAL_CARD_WIDTH + 32
    SIDE_MAX_ROWS = 8
    SIDE_TOP_OFFSET = 92
    SIDE_X_GAP = 8
    OPEN_STAGGER = 1
    FOCUS_GOLD = Color.new(255, 222, 82, 255)
    FOCUS_CYAN = Color.new(92, 224, 244, 220)
    ORDER_MOVE_FRAMES = 6

    def self.open_total(count)
      count = 1 if count == nil || count < 1
      return OPEN_FRAMES + (count - 1) * OPEN_STAGGER
    end

    def self.slide_state(tick, index, count)
      tick = 0 if tick == nil
      delay = index.to_i * OPEN_STAGGER
      local = tick.to_i - delay
      local = 0 if local < 0
      local = OPEN_FRAMES if local > OPEN_FRAMES
      rate = local.to_f / OPEN_FRAMES.to_f
      # 短促 ease-out，避免像舊子選項腳本那樣等完一輪才准玩家操作。
      rate = 1.0 - (1.0 - rate) * (1.0 - rate)
      x = (-VERTICAL_CARD_WIDTH * (1.0 - rate)).to_i
      opacity = (255 * rate).to_i
      return [x, opacity]
    end

    def self.fixed_card(text, type, selected, enabled, icon_index = nil,
      quantity = nil)
      key = [:fixed_v182b, text.to_s, type, selected ? 1 : 0,
        enabled ? 1 : 0, icon_index.to_i, quantity]
      bitmap = @card_cache[key]
      return bitmap if bitmap != nil && !bitmap.disposed?

      width = VERTICAL_CARD_WIDTH
      height = VERTICAL_CARD_HEIGHT
      bitmap = Bitmap.new(width, height)
      colors = selected && enabled ? command_type_color(type) : gray_colors
      opacity = enabled ? 242 : 145
      c1 = Color.new(colors[0].red, colors[0].green, colors[0].blue, opacity)
      c2 = Color.new(colors[1].red, colors[1].green, colors[1].blue, opacity)

      # 背景永遠使用完整固定矩形。選中狀態只改色與內部高光，不改尺寸。
      bitmap.gradient_fill_rect(0, 0, width, height, c1, c2)
      bitmap.fill_rect(0, 0, 3, height,
        selected ? FOCUS_GOLD : Color.new(42, 42, 46, opacity))
      bitmap.fill_rect(3, 0, width - 3, 1,
        selected ? Color.new(255, 250, 205, 235) : Color.new(25, 25, 28, 150))
      bitmap.fill_rect(3, height - 1, width - 3, 1,
        selected ? Color.new(230, 184, 46, 230) : Color.new(25, 25, 28, 150))

      text_x = 7
      if icon_index != nil && icon_index.to_i > 0
        icon_index = icon_index.to_i
        if selected && enabled
          iconset = Cache.system("IconSet")
          source = Rect.new(icon_index % 16 * 24,
            icon_index / 16 * 24, 24, 24)
          target = Rect.new(5, 2, 18, 18)
          if defined?(ALBERT_CG::TRGSSXVisual)
            ALBERT_CG::TRGSSXVisual.stretch_blt(
              bitmap, target, iconset, source, opacity)
          else
            bitmap.stretch_blt(target, iconset, source, opacity)
          end
        else
          gray = gray_icon(icon_index)
          if gray != nil
            target = Rect.new(5, 2, 18, 18)
            if defined?(ALBERT_CG::TRGSSXVisual)
              ALBERT_CG::TRGSSXVisual.stretch_blt(
                bitmap, target, gray, gray.rect, opacity)
            else
              bitmap.stretch_blt(target, gray, gray.rect, opacity)
            end
          end
        end
        text_x = 26
      end

      right_space = quantity == nil ? 5 : 24
      old_size = bitmap.font.size
      old_bold = bitmap.font.bold
      old_color = bitmap.font.color
      bitmap.font.bold = selected
      fit_font(bitmap, text.to_s, width - text_x - right_space,
        FONT_SIZE, 9)
      bitmap.font.color = Color.new(0, 0, 0, enabled ? 225 : 150)
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
        bitmap.font.color = Color.new(0, 0, 0, 220)
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
# ■ Window_ActorCommand／Window_PartyCommand：固定卡片＋逐列左滑
#==============================================================================
class Window_ActorCommand < Window_Command
  def cg_v182_reset_sidecar
    count = [@commands == nil ? 0 : @commands.size, 1].max
    self.width = ALBERT_CG::BattlerSidecarUI::SIDE_WINDOW_WIDTH
    self.height = count * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
      ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP) + 32
    self.opacity = 0
    self.back_opacity = 0
    self.contents_opacity = 255
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    @column_max = 1
    @cg_v182b_open_tick = 0
    @cg_v182b_open_total = ALBERT_CG::BattlerSidecarUI.open_total(count)
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
    for i in 0...count
      selected = i == @index
      enabled = cg_v182_command_enabled(i)
      card = ALBERT_CG::BattlerSidecarUI.fixed_card(
        @commands[i], cg_v182_command_type(i), selected, enabled)
      slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
        @cg_v182b_open_tick, i, count)
      y = i * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
        ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP)
      self.contents.blt(slide_x, y, card, card.rect, opacity)
    end
    update_cursor
  end

  def update
    old_index = @index
    super
    changed = old_index != @index
    if @cg_v182b_open_tick == nil
      @cg_v182b_open_tick = @cg_v182b_open_total.to_i
    elsif @cg_v182b_open_tick < @cg_v182b_open_total.to_i
      @cg_v182b_open_tick += 1
      changed = true
    end
    refresh if changed
  end
end

class Window_PartyCommand < Window_Command
  def cg_v182_reset_sidecar
    count = [@commands == nil ? 0 : @commands.size, 1].max
    self.width = ALBERT_CG::BattlerSidecarUI::SIDE_WINDOW_WIDTH
    self.height = count * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
      ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP) + 32
    self.opacity = 0
    self.back_opacity = 0
    self.contents_opacity = 255
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    @column_max = 1
    @cg_v182b_open_tick = 0
    @cg_v182b_open_total = ALBERT_CG::BattlerSidecarUI.open_total(count)
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
    for i in 0...count
      selected = i == @index
      enabled = cg_v182_party_enabled(i)
      card = ALBERT_CG::BattlerSidecarUI.fixed_card(
        @commands[i], cg_v182_party_type(i), selected, enabled)
      slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
        @cg_v182b_open_tick, i, count)
      y = i * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
        ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP)
      self.contents.blt(slide_x, y, card, card.rect, opacity)
    end
    update_cursor
  end

  def update
    old_index = @index
    super
    changed = old_index != @index
    if @cg_v182b_open_tick == nil
      @cg_v182b_open_tick = @cg_v182b_open_total.to_i
    elsif @cg_v182b_open_tick < @cg_v182b_open_total.to_i
      @cg_v182b_open_tick += 1
      changed = true
    end
    refresh if changed
  end
end

#==============================================================================
# ■ Battle Skill／Item：同位置、同寬、垂直單欄，最多顯示八項
#==============================================================================
module CG_BattleSidecarVertical
  def cg_v182b_visible_rows
    rows = [@item_max.to_i, ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS].min
    return [rows, 1].max
  end

  def cg_v182_setup_row_window
    self.width = ALBERT_CG::BattlerSidecarUI::SIDE_WINDOW_WIDTH
    self.height = ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS *
      (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
       ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP) + 32
    self.opacity = 0
    self.back_opacity = 0
    self.contents_opacity = 255
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    @column_max = 1
    @cg_v182b_top_index = 0
    @cg_v182b_open_tick = 0
    @cg_v182b_open_total = ALBERT_CG::BattlerSidecarUI.open_total(
      ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS)
    create_contents
  end

  def cg_v182b_resize_vertical
    rows = cg_v182b_visible_rows
    new_height = rows * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
      ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP) + 32
    if self.height != new_height
      self.height = new_height
      create_contents
    elsif self.contents == nil || self.contents.disposed?
      create_contents
    end
  end

  def cg_v182b_update_top_index
    @cg_v182b_top_index = 0 if @cg_v182b_top_index == nil
    index = @index == nil || @index < 0 ? 0 : @index
    if index < @cg_v182b_top_index
      @cg_v182b_top_index = index
    elsif index >= @cg_v182b_top_index +
        ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS
      @cg_v182b_top_index = index -
        ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS + 1
    end
    maximum = [@item_max.to_i -
      ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, 0].max
    @cg_v182b_top_index = maximum if @cg_v182b_top_index > maximum
    @cg_v182b_top_index = 0 if @cg_v182b_top_index < 0
  end

  def cg_v182b_item_rect(index)
    local = index.to_i - @cg_v182b_top_index.to_i
    return Rect.new(-999, 0, 1, 1) if local < 0 ||
      local >= ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS
    y = local * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
      ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP)
    return Rect.new(0, y,
      ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_WIDTH,
      ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT)
  end

  def item_rect(index)
    return cg_v182b_item_rect(index) if cg_v182_sidecar_battle?
    return super(index)
  end

  def update_cursor
    return self.cursor_rect.empty if cg_v182_sidecar_battle?
    super
  end

  def cursor_down(wrap = false)
    if cg_v182_sidecar_battle?
      return if @item_max.to_i <= 0
      self.index = (@index.to_i + 1) % @item_max
    else
      super(wrap)
    end
  end

  def cursor_up(wrap = false)
    if cg_v182_sidecar_battle?
      return if @item_max.to_i <= 0
      self.index = (@index.to_i - 1 + @item_max) % @item_max
    else
      super(wrap)
    end
  end

  def cursor_right(wrap = false)
    cursor_down(wrap) if cg_v182_sidecar_battle?
    super(wrap) unless cg_v182_sidecar_battle?
  end

  def cursor_left(wrap = false)
    cursor_up(wrap) if cg_v182_sidecar_battle?
    super(wrap) unless cg_v182_sidecar_battle?
  end

  def cursor_pagedown
    if cg_v182_sidecar_battle?
      self.index = [@index.to_i +
        ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, @item_max - 1].min
    else
      super
    end
  end

  def cursor_pageup
    if cg_v182_sidecar_battle?
      self.index = [@index.to_i -
        ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, 0].max
    else
      super
    end
  end

  def cg_v182b_draw_scroll_mark
    return if @item_max.to_i <= ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS
    old_size = self.contents.font.size
    old_color = self.contents.font.color
    self.contents.font.size = 9
    self.contents.font.color = Color.new(238, 238, 242)
    text = (@cg_v182b_top_index.to_i + 1).to_s + "-" +
      [@cg_v182b_top_index.to_i +
        ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, @item_max].min.to_s +
      "/" + @item_max.to_s
    self.contents.draw_text(0, self.contents.height - 12,
      self.contents.width, 12, text, 2)
    self.contents.font.size = old_size
    self.contents.font.color = old_color
  end

  def cg_v182b_update_animation
    if @cg_v182b_open_tick == nil
      @cg_v182b_open_tick = @cg_v182b_open_total.to_i
      return false
    end
    if @cg_v182b_open_tick < @cg_v182b_open_total.to_i
      @cg_v182b_open_tick += 1
      return true
    end
    return false
  end
end

class Window_Skill < Window_Selectable
  include CG_BattleSidecarVertical

  def refresh
    unless @cg_v182_sidecar_battle && @cg_v182_ready
      return albert_cg_v182_skill_normal_refresh
    end
    @data = @actor.respond_to?(:cg_skill_slot_skills) ?
      @actor.cg_skill_slot_skills : @actor.skills
    @data = [] if @data == nil
    @item_max = @data.size
    @index = 0 if @item_max > 0 && (@index == nil || @index < 0)
    @index = @item_max - 1 if @item_max > 0 && @index >= @item_max
    cg_v182b_update_top_index
    cg_v182b_resize_vertical
    self.contents.clear
    finish = [@cg_v182b_top_index +
      ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, @item_max].min
    local = 0
    for i in @cg_v182b_top_index...finish
      skill = @data[i]
      next if skill == nil
      enabled = @actor.skill_can_use?(skill)
      selected = i == @index
      card = ALBERT_CG::BattlerSidecarUI.fixed_card(
        skill.name, :skill_row, selected, enabled, skill.icon_index, nil)
      slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
        @cg_v182b_open_tick, local, finish - @cg_v182b_top_index)
      rect = cg_v182b_item_rect(i)
      self.contents.blt(slide_x, rect.y, card, card.rect, opacity)
      local += 1
    end
    cg_v182b_draw_scroll_mark
    update_cursor
  end

  def draw_item(index)
    refresh if @cg_v182_sidecar_battle && @cg_v182_ready
  end

  def index=(value)
    old_index = @index
    super(value)
    if @cg_v182_sidecar_battle && @cg_v182_ready && old_index != @index
      cg_v182b_update_top_index
      refresh
    end
  end

  def update
    if @cg_v182_sidecar_battle
      old_index = @index
      super
      changed = old_index != @index
      changed = true if cg_v182b_update_animation
      refresh if changed
    else
      super
    end
  end
end

class Window_Item < Window_Selectable
  include CG_BattleSidecarVertical

  def refresh
    unless @cg_v182_sidecar_battle && @cg_v182_ready
      return albert_cg_v182_item_normal_refresh
    end
    @data = []
    for item in $game_party.items
      next unless include?(item)
      @data.push(item)
    end
    @data.push(nil) if include?(nil)
    @item_max = @data.size
    @index = 0 if @item_max > 0 && (@index == nil || @index < 0)
    @index = @item_max - 1 if @item_max > 0 && @index >= @item_max
    cg_v182b_update_top_index
    cg_v182b_resize_vertical
    self.contents.clear
    finish = [@cg_v182b_top_index +
      ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, @item_max].min
    local = 0
    for i in @cg_v182b_top_index...finish
      item = @data[i]
      next if item == nil
      enabled = enable?(item)
      selected = i == @index
      quantity = $game_party.item_number(item)
      card = ALBERT_CG::BattlerSidecarUI.fixed_card(
        item.name, :item_row, selected, enabled, item.icon_index, quantity)
      slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
        @cg_v182b_open_tick, local, finish - @cg_v182b_top_index)
      rect = cg_v182b_item_rect(i)
      self.contents.blt(slide_x, rect.y, card, card.rect, opacity)
      local += 1
    end
    cg_v182b_draw_scroll_mark
    update_cursor
  end

  def draw_item(index)
    refresh if @cg_v182_sidecar_battle && @cg_v182_ready
  end

  def index=(value)
    old_index = @index
    super(value)
    if @cg_v182_sidecar_battle && @cg_v182_ready && old_index != @index
      cg_v182b_update_top_index
      refresh
    end
  end

  def update
    if @cg_v182_sidecar_battle
      old_index = @index
      super
      changed = old_index != @index
      changed = true if cg_v182b_update_animation
      refresh if changed
    else
      super
    end
  end
end

#==============================================================================
# ■ Window_CG_BattleSidecarList：移動／換寵等共用子選項
#==============================================================================
class Window_CG_BattleSidecarList < Window_Selectable
  attr_reader :entries

  def initialize(entries, type = :move)
    @entries = entries == nil ? [] : entries
    @type = type
    @item_max = @entries.size
    rows = [[@item_max, ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS].min, 1].max
    super(0, 0, ALBERT_CG::BattlerSidecarUI::SIDE_WINDOW_WIDTH,
      rows * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
      ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP) + 32)
    self.opacity = 0
    self.back_opacity = 0
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    self.active = false
    self.index = 0
    @top_index = 0
    @open_tick = 0
    @open_total = ALBERT_CG::BattlerSidecarUI.open_total(rows)
    refresh
  end

  def entry
    return nil if @index == nil || @index < 0 || @index >= @entries.size
    return @entries[@index]
  end

  def enabled?(index)
    data = @entries[index]
    return false if data == nil
    return data.has_key?(:enabled) ? data[:enabled] : true
  end

  def item_rect(index)
    local = index - @top_index
    return Rect.new(-999, 0, 1, 1) if local < 0 ||
      local >= ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS
    y = local * (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
      ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP)
    return Rect.new(0, y,
      ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_WIDTH,
      ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT)
  end

  def update_top_index
    if @index < @top_index
      @top_index = @index
    elsif @index >= @top_index + ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS
      @top_index = @index - ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS + 1
    end
    maximum = [@item_max - ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, 0].max
    @top_index = maximum if @top_index > maximum
    @top_index = 0 if @top_index < 0
  end

  def refresh
    self.contents.clear
    finish = [@top_index + ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS,
      @item_max].min
    local = 0
    for i in @top_index...finish
      data = @entries[i]
      text = data == nil ? "" : data[:text].to_s
      type = data != nil && data[:type] != nil ? data[:type] : @type
      type = :pet_switch if type == :switch || type == :recall
      selected = i == @index
      card = ALBERT_CG::BattlerSidecarUI.fixed_card(
        text, type, selected, enabled?(i))
      slide_x, opacity = ALBERT_CG::BattlerSidecarUI.slide_state(
        @open_tick, local, finish - @top_index)
      rect = item_rect(i)
      self.contents.blt(slide_x, rect.y, card, card.rect, opacity)
      local += 1
    end
    update_cursor
  end

  def update_cursor
    self.cursor_rect.empty
  end

  def cursor_down(wrap = false)
    return if @item_max <= 0
    self.index = (@index + 1) % @item_max
  end

  def cursor_up(wrap = false)
    return if @item_max <= 0
    self.index = (@index - 1 + @item_max) % @item_max
  end

  def cursor_right(wrap = false)
    cursor_down(wrap)
  end

  def cursor_left(wrap = false)
    cursor_up(wrap)
  end

  def index=(value)
    old = @index
    super(value)
    if old != @index
      update_top_index
      refresh
    end
  end

  def update
    old = @index
    super
    changed = old != @index
    if @open_tick < @open_total
      @open_tick += 1
      changed = true
    end
    refresh if changed
  end
end

#==============================================================================
# ■ Window_CG_ActionOrder：真正由右往左推進 NOW 槽
#==============================================================================
class Window_CG_ActionOrder < Window_Base
  def clear_order
    @current_battler = nil
    @current_action = nil
    @queue = []
    @cg_v182b_previous_positions = {}
    @cg_v182b_start_positions = {}
    @cg_v182b_move_frames = 0
    self.contents.clear
    self.visible = false
  end

  def cg_v182b_key(battler, action)
    return [battler == nil ? 0 : battler.object_id,
      action == nil ? 0 : action.object_id]
  end

  def cg_v182b_state_entries(current_battler, current_action, queue)
    result = []
    if current_battler != nil
      result.push([current_battler, current_action, true])
    end
    queue = [] if queue == nil
    for entry in queue
      next unless cg_valid_entry?(entry)
      result.push([cg_entry_battler(entry), cg_entry_action(entry), false])
    end
    return result
  end

  def cg_v182b_target_positions(entries)
    positions = {}
    card_width = ALBERT_CG::BattlerSidecarUI::ORDER_CARD_WIDTH
    queue_index = 0
    for data in entries
      battler, action, current = data
      key = cg_v182b_key(battler, action)
      if current
        positions[key] = 0
      else
        positions[key] = card_width + queue_index * card_width
        queue_index += 1
      end
    end
    return positions
  end

  def set_order(current_battler, current_action, queue)
    old_entries = cg_v182b_state_entries(@current_battler,
      @current_action, @queue)
    old_positions = cg_v182b_target_positions(old_entries)

    @current_battler = current_battler
    @current_action = current_action
    @queue = queue == nil ? [] : queue.dup
    new_entries = cg_v182b_state_entries(@current_battler,
      @current_action, @queue)
    new_positions = cg_v182b_target_positions(new_entries)

    @cg_v182b_start_positions = {}
    moved = false
    for data in new_entries
      battler, action, current = data
      key = cg_v182b_key(battler, action)
      target = new_positions[key]
      start = old_positions.has_key?(key) ? old_positions[key] : target +
        ALBERT_CG::BattlerSidecarUI::ORDER_CARD_WIDTH
      @cg_v182b_start_positions[key] = start
      moved = true if start != target
    end
    @cg_v182b_move_frames = moved ?
      ALBERT_CG::BattlerSidecarUI::ORDER_MOVE_FRAMES : 0
    refresh
  end

  def refresh
    self.opacity = 0
    self.back_opacity = 0
    self.contents_opacity = 255
    self.windowskin = ALBERT_CG::BattlerSidecarUI.blank_windowskin
    entries = cg_display_entries
    if entries.empty?
      self.contents.clear
      self.visible = false
      return
    end
    cg_v182b_render(entries)
    self.visible = true
  end

  def update
    super
    self.opacity = 0
    self.back_opacity = 0
    if @cg_v182b_move_frames != nil && @cg_v182b_move_frames > 0
      @cg_v182b_move_frames -= 1
      cg_v182b_render(cg_display_entries)
    end
  end

  def cg_v182b_render(entries)
    self.contents.clear
    return if entries == nil || entries.empty?
    target_positions = cg_v182b_target_positions(entries)
    total = ALBERT_CG::BattlerSidecarUI::ORDER_MOVE_FRAMES.to_f
    remain = @cg_v182b_move_frames.to_i
    ratio = total <= 0 ? 0.0 : remain.to_f / total
    ratio = ratio * ratio
    maximum = [entries.size, ALBERT_CG::BattlerSidecarUI::ORDER_VISIBLE].min

    for i in 0...maximum
      battler, action, current = entries[i]
      key = cg_v182b_key(battler, action)
      target = target_positions[key].to_i
      start = @cg_v182b_start_positions == nil ? target :
        (@cg_v182b_start_positions[key] || target)
      x = (target + (start - target) * ratio).to_i
      cg_v182b_draw_order_card(x, battler, current)
    end
  end

  def cg_v182b_draw_order_card(x, battler, current)
    width = ALBERT_CG::BattlerSidecarUI::ORDER_CARD_WIDTH - 2
    height = [self.contents.height - 2, 30].min
    y = 0
    if battler.actor?
      c1 = Color.new(66, 142, 218, 232)
      c2 = Color.new(24, 70, 132, 232)
    else
      c1 = Color.new(218, 92, 86, 232)
      c2 = Color.new(128, 34, 40, 232)
    end
    self.contents.gradient_fill_rect(x, y + 1, width, height - 2, c1, c2, true)
    if current
      pulse = 170 + ((Graphics.frame_count / 3) % 2) * 70
      gold = Color.new(255, 222, 82, pulse)
      self.contents.fill_rect(x, y, width, 2, gold)
      self.contents.fill_rect(x, y + height - 2, width, 2, gold)
      self.contents.fill_rect(x, y, 3, height, gold)
    end
    draw_order_character_card(battler, x + 1, y + 1, width - 2, height - 2)
  end
end

#==============================================================================
# ■ Sprite_CG_BattlerFocus：操作角色光環＋選單連接線
#==============================================================================
class Sprite_CG_BattlerFocus
  def initialize
    @ring = Sprite.new
    @ring.bitmap = Bitmap.new(72, 72)
    @ring.ox = 36
    @ring.oy = 36
    @ring.z = 515
    @ring.zoom_y = 0.46
    @ring.visible = false

    @line = Sprite.new
    @line.bitmap = Bitmap.new(256, 12)
    @line.z = 514
    @line.visible = false
    draw_ring
  end

  def draw_ring
    bitmap = @ring.bitmap
    bitmap.clear
    outer = ALBERT_CG::BattlerSidecarUI::FOCUS_CYAN
    inner = ALBERT_CG::BattlerSidecarUI::FOCUS_GOLD
    drawn = false
    if defined?(ALBERT_CG::TRGSSXVisual)
      drawn = ALBERT_CG::TRGSSXVisual.draw_regular_polygon(
        bitmap, 36, 36, 30, 32, outer, 3)
      ALBERT_CG::TRGSSXVisual.draw_regular_polygon(
        bitmap, 36, 36, 25, 32, inner, 2) if drawn
    end
    return if drawn
    for degree in 0...360
      next unless degree % 3 == 0
      rad = degree * Math::PI / 180.0
      x1 = 36 + Math.cos(rad) * 30
      y1 = 36 + Math.sin(rad) * 30
      x2 = 36 + Math.cos(rad) * 25
      y2 = 36 + Math.sin(rad) * 25
      bitmap.fill_rect(x1.to_i, y1.to_i, 2, 2, outer)
      bitmap.fill_rect(x2.to_i, y2.to_i, 2, 2, inner)
    end
  end

  def hide
    @ring.visible = false
    @line.visible = false
  end

  def update(anchor, window)
    if anchor == nil || window == nil || !window.visible
      hide
      return
    end
    center_x = anchor[4].to_i
    foot_y = anchor[3].to_i - 2
    @ring.x = center_x
    @ring.y = foot_y
    @ring.opacity = 170 + ((Graphics.frame_count / 3) % 2) * 55
    @ring.angle = 0
    @ring.visible = true

    menu_left = window.x.to_i + 16
    menu_mid_y = window.y.to_i + 16 +
      ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT / 2
    start_x = center_x + 22
    finish_x = menu_left
    left = [start_x, finish_x].min
    right = [start_x, finish_x].max
    length = [right - left, 1].max
    length = 250 if length > 250
    bitmap = @line.bitmap
    bitmap.clear
    gold = ALBERT_CG::BattlerSidecarUI::FOCUS_GOLD
    bitmap.fill_rect(0, 5, length, 2, gold)
    bitmap.fill_rect(length - 4, 3, 4, 6, gold)
    @line.x = left
    @line.y = menu_mid_y - 6
    @line.src_rect.set(0, 0, length, 12)
    @line.visible = true
  end

  def dispose
    if @ring != nil
      @ring.bitmap.dispose if @ring.bitmap != nil && !@ring.bitmap.disposed?
      @ring.dispose unless @ring.disposed?
    end
    if @line != nil
      @line.bitmap.dispose if @line.bitmap != nil && !@line.bitmap.disposed?
      @line.dispose unless @line.disposed?
    end
  end
end

#==============================================================================
# ■ Scene_Battle：統一側掛位置、子選單與操作焦點
#==============================================================================
class Scene_Battle < Scene_Base
  alias albert_cg_v182b_start start
  def start
    albert_cg_v182b_start
    @cg_v182b_focus = Sprite_CG_BattlerFocus.new
    @cg_v182b_popup_window = nil
  end

  def cg_v182b_sidecar_origin(battler)
    anchor = cg_v182_sidecar_anchor(battler)
    return [0, 0] if anchor == nil
    x = anchor[2].to_i + ALBERT_CG::BattlerSidecarUI::SIDE_X_GAP
    maximum_x = Graphics.width -
      ALBERT_CG::BattlerSidecarUI::SIDE_WINDOW_WIDTH + 8
    x = maximum_x if x > maximum_x
    x = 0 if x < 0
    y = anchor[5].to_i - ALBERT_CG::BattlerSidecarUI::SIDE_TOP_OFFSET
    y = 0 if y < 0
    maximum_height = ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS *
      (ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT +
       ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP) + 32
    maximum_y = ALBERT_CG::BATTLE_STATUS_Y - maximum_height + 8
    y = maximum_y if y > maximum_y
    return [x, y]
  end

  def cg_v182_place_vertical_sidecar(window, battler)
    return if window == nil || battler == nil
    x, y = cg_v182b_sidecar_origin(battler)
    window.x = x
    window.y = y
  end

  def cg_v182_place_row_window(window)
    return if window == nil || @active_battler == nil
    x, y = cg_v182b_sidecar_origin(@active_battler)
    window.x = x
    window.y = y
  end

  def cg_v182b_focus_window
    return @cg_v182b_popup_window if @cg_v182b_popup_window != nil &&
      !@cg_v182b_popup_window.disposed? && @cg_v182b_popup_window.visible
    return @skill_window if @skill_window != nil &&
      !@skill_window.disposed? && @skill_window.visible
    return @item_window if @item_window != nil &&
      !@item_window.disposed? && @item_window.visible
    return @actor_command_window if @actor_command_window != nil &&
      !@actor_command_window.disposed? && @actor_command_window.visible
    return @party_command_window if @party_command_window != nil &&
      !@party_command_window.disposed? && @party_command_window.visible
    return nil
  end

  def cg_v182b_focus_battler(window)
    return nil if window == nil
    return cg_v182_primary_human if window == @party_command_window
    return @active_battler
  end

  def cg_v182b_update_focus
    return if @cg_v182b_focus == nil
    window = cg_v182b_focus_window
    battler = cg_v182b_focus_battler(window)
    if window == nil || battler == nil
      @cg_v182b_focus.hide
      return
    end
    anchor = cg_v182_sidecar_anchor(battler)
    @cg_v182b_focus.update(anchor, window)
  end

  alias albert_cg_v182b_update_basic update_basic
  def update_basic(main = false)
    albert_cg_v182b_update_basic(main)
    cg_v182b_update_focus
  end

  # 共用子選單在主指令相同位置顯示。
  def cg_run_battle_popup(window, help_text)
    help = Window_Help.new
    help.set_text(help_text, 1)
    help.z = 500
    x, y = cg_v182b_sidecar_origin(@active_battler)
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

  def cg_start_move_command
    entries = cg_move_entries
    if entries.empty?
      Sound.play_buzzer
      cg_restore_actor_command_after_popup
      return
    end
    window = Window_CG_BattleSidecarList.new(entries, :move)
    index = cg_run_battle_popup(window, "選擇人物本回合的移動方式")
    if index < 0
      cg_restore_actor_command_after_popup
      return
    end
    entry = entries[index]
    if entry[:type] == :swap_pet
      pet = $game_party.cg_active_pet_for(@active_battler)
      if pet == nil || !pet.exist?
        Sound.play_buzzer
        cg_restore_actor_command_after_popup
        return
      end
      @active_battler.action.cg_set_swap_pet(pet.id)
    else
      @active_battler.action.cg_set_move_slot(entry[:row], entry[:column])
    end
    Sound.play_decision
    next_actor
  end

  def cg_start_pet_switch_command
    if cg_pet_management_already_planned?(@active_battler)
      Sound.play_buzzer
      @help_window.set_text("同一人物每回合只能安排一次派寵、換寵或收回。", 1) if
        @help_window != nil
      cg_restore_actor_command_after_popup
      return
    end
    unless $game_party.cg_free_pet_switch_owner?(@active_battler)
      Sound.play_buzzer
      cg_restore_actor_command_after_popup
      return
    end
    entries = cg_pet_switch_entries
    window = Window_CG_BattleSidecarList.new(entries, :pet_switch)
    index = cg_run_battle_popup(window, "選擇要收回或派出的寵物")
    if index < 0
      cg_restore_actor_command_after_popup
      return
    end
    entry = entries[index]
    if entry == nil || entry[:type] == :cancel
      Sound.play_cancel
      cg_restore_actor_command_after_popup
      return
    end
    unless entry[:enabled]
      Sound.play_buzzer
      cg_restore_actor_command_after_popup
      return
    end
    if entry[:type] == :recall
      @active_battler.action.cg_set_recall_pet(entry[:pet_id])
    else
      @active_battler.action.cg_set_switch_pet(entry[:pet_id])
    end
    Sound.play_decision
    next_actor
  end

  alias albert_cg_v182b_terminate terminate
  def terminate
    if @cg_v182b_focus != nil
      @cg_v182b_focus.dispose
      @cg_v182b_focus = nil
    end
    albert_cg_v182b_terminate
  end
end

#==============================================================================
# ■ v1.8.2b direct method priority fix
#------------------------------------------------------------------------------
#  Window_Skill／Window_Item 在 v1.8.2 已直接定義橫排游標方法；Ruby 的
#  類別方法會優先於 include module，因此在最末端直接覆寫成垂直規則。
#==============================================================================
class Window_Skill < Window_Selectable
  def item_rect(index)
    return cg_v182b_item_rect(index) if cg_v182_sidecar_battle?
    return super(index)
  end

  def update_cursor
    return self.cursor_rect.empty if cg_v182_sidecar_battle?
    super
  end

  def cursor_down(wrap = false)
    if cg_v182_sidecar_battle?
      return if @item_max.to_i <= 0
      self.index = (@index.to_i + 1) % @item_max
    else
      super(wrap)
    end
  end

  def cursor_up(wrap = false)
    if cg_v182_sidecar_battle?
      return if @item_max.to_i <= 0
      self.index = (@index.to_i - 1 + @item_max) % @item_max
    else
      super(wrap)
    end
  end

  def cursor_right(wrap = false)
    return cursor_down(wrap) if cg_v182_sidecar_battle?
    super(wrap)
  end

  def cursor_left(wrap = false)
    return cursor_up(wrap) if cg_v182_sidecar_battle?
    super(wrap)
  end

  def cursor_pagedown
    if cg_v182_sidecar_battle?
      self.index = [@index.to_i +
        ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, @item_max - 1].min
    else
      super
    end
  end

  def cursor_pageup
    if cg_v182_sidecar_battle?
      self.index = [@index.to_i -
        ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, 0].max
    else
      super
    end
  end
end

class Window_Item < Window_Selectable
  def item_rect(index)
    return cg_v182b_item_rect(index) if cg_v182_sidecar_battle?
    return super(index)
  end

  def update_cursor
    return self.cursor_rect.empty if cg_v182_sidecar_battle?
    super
  end

  def cursor_down(wrap = false)
    if cg_v182_sidecar_battle?
      return if @item_max.to_i <= 0
      self.index = (@index.to_i + 1) % @item_max
    else
      super(wrap)
    end
  end

  def cursor_up(wrap = false)
    if cg_v182_sidecar_battle?
      return if @item_max.to_i <= 0
      self.index = (@index.to_i - 1 + @item_max) % @item_max
    else
      super(wrap)
    end
  end

  def cursor_right(wrap = false)
    return cursor_down(wrap) if cg_v182_sidecar_battle?
    super(wrap)
  end

  def cursor_left(wrap = false)
    return cursor_up(wrap) if cg_v182_sidecar_battle?
    super(wrap)
  end

  def cursor_pagedown
    if cg_v182_sidecar_battle?
      self.index = [@index.to_i +
        ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, @item_max - 1].min
    else
      super
    end
  end

  def cursor_pageup
    if cg_v182_sidecar_battle?
      self.index = [@index.to_i -
        ALBERT_CG::BattlerSidecarUI::SIDE_MAX_ROWS, 0].max
    else
      super
    end
  end
end
