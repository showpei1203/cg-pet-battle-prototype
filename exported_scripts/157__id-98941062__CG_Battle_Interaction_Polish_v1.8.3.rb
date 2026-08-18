# RMVX_SCRIPT_INDEX: 157
# RMVX_SCRIPT_ID: 98941062
# RMVX_SCRIPT_NAME: CG Battle Interaction Polish v1.8.3
# RMVX_SOURCE_SHA256: 2ee138d9ff8b052433e095fd0d9af49cbca6281de7622bb4d348e711259c825c

#==============================================================================
# ■ CG Battle Interaction Polish v1.8.3
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【本版重點】
#  1. 行動順序改為「菱形序列」。我方藍色、敵方紅色，目前行動者
#     放大並以金色高光。真正的佇列資料與速度規則完全不變。
#  2. 延續 CG Battler Sidecar UI：主指令、Fight／Escape、Skill、Item、
#     移動、換位與換寵均使用固定同尺寸的垂直圖片卡。
#  3. 選單開啟時，各列由上到下依序從左側短距離滑入。
#  4. 目前操作者腳下顯示脈動光環，光環與側掛選單以同色連接線相連；
#     顏色會跟隨目前選擇的指令分類。
#
# 【腳本位置】
#  放在 CG Runtime Fix v1.8.2b 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattleInteractionPolish_1_8_3"] = true

module ALBERT_CG
  if const_defined?(:BATTLE_UI_VERSION)
    remove_const(:BATTLE_UI_VERSION)
  end
  BATTLE_UI_VERSION = "1.8.3"

  # 行動順序仍位於 Battle Status 右上方。Window 本身完全透明；
  # 實際可見內容只會落在 y=260～300 左右，不遮住底部狀態列。
  [:ORDER_WINDOW_X, :ORDER_WINDOW_Y, :ORDER_WINDOW_WIDTH,
   :ORDER_WINDOW_HEIGHT, :ORDER_CARD_WIDTH, :ORDER_CARD_COUNT].each do |name|
    remove_const(name) if const_defined?(name)
  end
  ORDER_WINDOW_WIDTH = 288
  ORDER_WINDOW_HEIGHT = 72
  ORDER_WINDOW_X = 544 - ORDER_WINDOW_WIDTH
  ORDER_WINDOW_Y = BATTLE_STATUS_Y - 60
  ORDER_CARD_WIDTH = 24
  ORDER_CARD_COUNT = 8

  module BattleInteractionPolish
    CURRENT_SIZE = 38
    WAITING_SIZE = 26
    CURRENT_X = 0
    WAITING_START_X = 40
    WAITING_STEP = 25
    ORDER_Y = 1
    ORDER_MOVE_FRAMES = 7

    ALLY_CENTER = Color.new(76, 164, 242, 238)
    ALLY_EDGE = Color.new(28, 72, 144, 244)
    ENEMY_CENTER = Color.new(238, 104, 98, 238)
    ENEMY_EDGE = Color.new(138, 38, 48, 244)
    ORDER_GOLD = Color.new(255, 224, 82, 255)
    ORDER_WHITE = Color.new(235, 244, 255, 225)
    ORDER_SHADOW = Color.new(0, 0, 0, 135)

    def self.focus_type_color(type)
      colors = ALBERT_CG::BattlerSidecarUI.command_type_color(type)
      return colors == nil ? Color.new(92, 224, 244, 225) : colors[0]
    rescue
      return Color.new(92, 224, 244, 225)
    end
  end

  def self.apply_v183_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.8.3"
  end
end

#==============================================================================
# ■ Window_CG_ActionOrder
#------------------------------------------------------------------------------
#  菱形鏈：等待中的行動排列於右側；行動開始時，該卡由等待位置滑入
#  最左側，並同步放大。其他卡片向左補位。
#==============================================================================
class Window_CG_ActionOrder < Window_Base
  def clear_order
    @current_battler = nil
    @current_action = nil
    @queue = []
    @cg_v183_start_geometry = {}
    @cg_v183_move_frames = 0
    self.contents.clear
    self.visible = false
  end

  def cg_v183_key(battler, action)
    return [battler == nil ? 0 : battler.object_id,
      action == nil ? 0 : action.object_id]
  end

  def cg_v183_state_entries(current_battler, current_action, queue)
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

  def cg_v183_target_geometry(entries)
    result = {}
    waiting_index = 0
    for data in entries
      battler, action, current = data
      key = cg_v183_key(battler, action)
      if current
        result[key] = [ALBERT_CG::BattleInteractionPolish::CURRENT_X,
          ALBERT_CG::BattleInteractionPolish::CURRENT_SIZE]
      else
        x = ALBERT_CG::BattleInteractionPolish::WAITING_START_X +
          waiting_index * ALBERT_CG::BattleInteractionPolish::WAITING_STEP
        result[key] = [x, ALBERT_CG::BattleInteractionPolish::WAITING_SIZE]
        waiting_index += 1
      end
    end
    return result
  end

  def set_order(current_battler, current_action, queue)
    old_entries = cg_v183_state_entries(@current_battler,
      @current_action, @queue)
    old_geometry = cg_v183_target_geometry(old_entries)

    @current_battler = current_battler
    @current_action = current_action
    @queue = queue == nil ? [] : queue.dup

    new_entries = cg_v183_state_entries(@current_battler,
      @current_action, @queue)
    new_geometry = cg_v183_target_geometry(new_entries)
    @cg_v183_start_geometry = {}
    moved = false

    for data in new_entries
      battler, action, current = data
      key = cg_v183_key(battler, action)
      target = new_geometry[key]
      if old_geometry.has_key?(key)
        start = old_geometry[key]
      else
        start = [target[0] + ALBERT_CG::BattleInteractionPolish::WAITING_STEP,
          ALBERT_CG::BattleInteractionPolish::WAITING_SIZE]
      end
      @cg_v183_start_geometry[key] = start
      moved = true if start[0] != target[0] || start[1] != target[1]
    end

    @cg_v183_move_frames = moved ?
      ALBERT_CG::BattleInteractionPolish::ORDER_MOVE_FRAMES : 0
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
    cg_v183_render(entries)
    self.visible = true
  end

  def update
    super
    self.opacity = 0
    self.back_opacity = 0
    if @cg_v183_move_frames != nil && @cg_v183_move_frames > 0
      @cg_v183_move_frames -= 1
      cg_v183_render(cg_display_entries)
    elsif @current_battler != nil && Graphics.frame_count % 8 == 0
      # 目前行動者的金色外光會輕微脈動。
      cg_v183_render(cg_display_entries)
    end
  end

  def cg_v183_render(entries)
    self.contents.clear
    return if entries == nil || entries.empty?
    target_geometry = cg_v183_target_geometry(entries)
    total = ALBERT_CG::BattleInteractionPolish::ORDER_MOVE_FRAMES.to_f
    remain = @cg_v183_move_frames.to_i
    ratio = total <= 0 ? 0.0 : remain.to_f / total
    # ease-out：起初移動明顯，接近定位時放慢。
    ratio = ratio * ratio
    maximum = [entries.size, ALBERT_CG::ORDER_CARD_COUNT].min

    for i in 0...maximum
      battler, action, current = entries[i]
      key = cg_v183_key(battler, action)
      target = target_geometry[key]
      start = @cg_v183_start_geometry == nil ? target :
        (@cg_v183_start_geometry[key] || target)
      x = (target[0] + (start[0] - target[0]) * ratio).to_i
      size = (target[1] + (start[1] - target[1]) * ratio).to_i
      cg_v183_draw_order_diamond(x, battler, current, size)
    end

    if entries.size > maximum
      old_size = self.contents.font.size
      old_bold = self.contents.font.bold
      old_color = self.contents.font.color
      self.contents.font.size = 9
      self.contents.font.bold = true
      self.contents.font.color = Color.new(245, 245, 250)
      text = "+" + (entries.size - maximum).to_s
      self.contents.draw_text(self.contents.width - 24,
        self.contents.height - 13, 24, 12, text, 2)
      self.contents.font.size = old_size
      self.contents.font.bold = old_bold
      self.contents.font.color = old_color
    end
  end

  def cg_v183_draw_order_diamond(x, battler, current, size)
    return if battler == nil
    size = [size.to_i, 12].max
    y = ALBERT_CG::BattleInteractionPolish::ORDER_Y +
      (ALBERT_CG::BattleInteractionPolish::CURRENT_SIZE - size) / 2
    cx = x + size / 2
    cy = y + size / 2
    radius = size / 2

    if battler.actor?
      center_color = ALBERT_CG::BattleInteractionPolish::ALLY_CENTER
      edge_color = ALBERT_CG::BattleInteractionPolish::ALLY_EDGE
    else
      center_color = ALBERT_CG::BattleInteractionPolish::ENEMY_CENTER
      edge_color = ALBERT_CG::BattleInteractionPolish::ENEMY_EDGE
    end

    # 陰影。
    cg_v183_fill_diamond(cx + 2, cy + 2, radius,
      ALBERT_CG::BattleInteractionPolish::ORDER_SHADOW,
      ALBERT_CG::BattleInteractionPolish::ORDER_SHADOW)

    if current
      pulse = 205 + ((Graphics.frame_count / 4) % 2) * 45
      gold = Color.new(255, 224, 82, pulse)
      cg_v183_fill_diamond(cx, cy, radius, gold, gold)
      cg_v183_fill_diamond(cx, cy, [radius - 3, 2].max,
        center_color, edge_color)
    else
      cg_v183_fill_diamond(cx, cy, radius,
        ALBERT_CG::BattleInteractionPolish::ORDER_WHITE,
        ALBERT_CG::BattleInteractionPolish::ORDER_WHITE)
      cg_v183_fill_diamond(cx, cy, [radius - 2, 2].max,
        center_color, edge_color)
    end

    draw_width = current ? size - 8 : size - 6
    draw_height = current ? size - 4 : size - 5
    draw_x = cx - draw_width / 2
    draw_y = cy - draw_height / 2 - (current ? 2 : 1)
    draw_order_character_card(battler, draw_x, draw_y,
      draw_width, draw_height)
  end

  def cg_v183_fill_diamond(cx, cy, radius, center_color, edge_color)
    # 直接以水平掃描線畫出菱形，避免不同 TRGSSX 版本對四邊形
    # 起始角度的解讀不同，導致有些環境畫成正方形。行走圖縮放仍會
    # 使用 TRGSSX，高解析縮放功能沒有被浪費。
    radius = [radius.to_i, 1].max
    for dy in -radius..radius
      half = radius - dy.abs
      next if half < 0
      rate = radius <= 0 ? 0.0 : dy.abs.to_f / radius.to_f
      red = (center_color.red * (1.0 - rate) + edge_color.red * rate).to_i
      green = (center_color.green * (1.0 - rate) +
        edge_color.green * rate).to_i
      blue = (center_color.blue * (1.0 - rate) +
        edge_color.blue * rate).to_i
      alpha = (center_color.alpha * (1.0 - rate) +
        edge_color.alpha * rate).to_i
      color = Color.new(red, green, blue, alpha)
      self.contents.fill_rect(cx - half, cy + dy, half * 2 + 1, 1, color)
    end
  rescue
  end
end

#==============================================================================
# ■ Sidecar 各窗口：提供焦點顏色類型
#==============================================================================
class Window_ActorCommand < Window_Command
  def cg_v183_focus_type
    return cg_v182_command_type(@index) if respond_to?(:cg_v182_command_type)
    return :attack
  rescue
    return :attack
  end
end

class Window_PartyCommand < Window_Command
  def cg_v183_focus_type
    return cg_v182_party_type(@index) if respond_to?(:cg_v182_party_type)
    return @index.to_i == 0 ? :fight : :escape
  rescue
    return :fight
  end
end

class Window_Skill < Window_Selectable
  def cg_v183_focus_type
    return :skill
  end
end

class Window_Item < Window_Selectable
  def cg_v183_focus_type
    return :item
  end
end

class Window_CG_BattleSidecarList < Window_Selectable
  def cg_v183_focus_type
    entry = respond_to?(:entry) ? self.entry : nil
    if entry != nil && entry[:type] != nil
      type = entry[:type]
      return :pet_switch if type == :switch || type == :recall
      return type
    end
    return @type == nil ? :move : @type
  rescue
    return :move
  end
end

#==============================================================================
# ■ Sprite_CG_BattlerFocus
#------------------------------------------------------------------------------
#  光環顏色跟隨目前選項分類；連接線會由 battler 朝向選單最近一側。
#==============================================================================
class Sprite_CG_BattlerFocus
  def cg_v183_draw_ring(type)
    @cg_v183_ring_type = type
    bitmap = @ring.bitmap
    bitmap.clear
    accent = ALBERT_CG::BattleInteractionPolish.focus_type_color(type)
    gold = ALBERT_CG::BattlerSidecarUI::FOCUS_GOLD
    drawn = false
    if defined?(ALBERT_CG::TRGSSXVisual)
      drawn = ALBERT_CG::TRGSSXVisual.draw_regular_polygon(
        bitmap, 36, 36, 31, 32, accent, 4)
      ALBERT_CG::TRGSSXVisual.draw_regular_polygon(
        bitmap, 36, 36, 25, 32, gold, 2) if drawn
    end
    unless drawn
      for degree in 0...360
        next unless degree % 3 == 0
        rad = degree * Math::PI / 180.0
        x1 = 36 + Math.cos(rad) * 31
        y1 = 36 + Math.sin(rad) * 31
        x2 = 36 + Math.cos(rad) * 25
        y2 = 36 + Math.sin(rad) * 25
        bitmap.fill_rect(x1.to_i, y1.to_i, 2, 2, accent)
        bitmap.fill_rect(x2.to_i, y2.to_i, 2, 2, gold)
      end
    end
  end

  def update(anchor, window, type = nil)
    if anchor == nil || window == nil || !window.visible
      hide
      return
    end
    type = :attack if type == nil
    cg_v183_draw_ring(type) if @cg_v183_ring_type != type
    accent = ALBERT_CG::BattleInteractionPolish.focus_type_color(type)

    center_x = anchor[4].to_i
    foot_y = anchor[3].to_i - 2
    @ring.x = center_x
    @ring.y = foot_y
    @ring.opacity = 175 + ((Graphics.frame_count / 3) % 2) * 55
    @ring.visible = true

    # 選單在右側時連到左邊緣；被畫面限制到角色左側時則連到右邊緣。
    if window.x.to_i >= center_x
      start_x = center_x + 23
      finish_x = window.x.to_i + 16
    else
      start_x = center_x - 23
      finish_x = window.x.to_i + window.width.to_i - 16
    end
    menu_mid_y = window.y.to_i + 16 +
      ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT / 2
    left = [start_x, finish_x].min
    right = [start_x, finish_x].max
    length = [right - left, 1].max
    length = 250 if length > 250

    bitmap = @line.bitmap
    bitmap.clear
    bitmap.fill_rect(0, 4, length, 4,
      Color.new(0, 0, 0, 125))
    bitmap.fill_rect(0, 5, length, 2, accent)
    bitmap.fill_rect(length - 5, 2, 5, 8,
      ALBERT_CG::BattlerSidecarUI::FOCUS_GOLD)
    @line.x = left
    @line.y = menu_mid_y - 6
    @line.src_rect.set(0, 0, length, 12)
    @line.opacity = 185 + ((Graphics.frame_count / 4) % 2) * 45
    @line.visible = true
  end
end

#==============================================================================
# ■ Scene_Battle
#==============================================================================
class Scene_Battle < Scene_Base
  alias albert_cg_v183_configure_battle_windows cg_v17_configure_battle_windows
  def cg_v17_configure_battle_windows
    albert_cg_v183_configure_battle_windows
    if @cg_action_order_window != nil
      @cg_action_order_window.viewport = nil
      @cg_action_order_window.x = ALBERT_CG::ORDER_WINDOW_X
      @cg_action_order_window.y = ALBERT_CG::ORDER_WINDOW_Y
      @cg_action_order_window.width = ALBERT_CG::ORDER_WINDOW_WIDTH
      @cg_action_order_window.height = ALBERT_CG::ORDER_WINDOW_HEIGHT
      @cg_action_order_window.z = 440
      @cg_action_order_window.opacity = 0
      @cg_action_order_window.back_opacity = 0
      @cg_action_order_window.windowskin =
        ALBERT_CG::BattlerSidecarUI.blank_windowskin
      required_width = @cg_action_order_window.width - 32
      required_height = @cg_action_order_window.height - 32
      if @cg_action_order_window.contents == nil ||
         @cg_action_order_window.contents.disposed? ||
         @cg_action_order_window.contents.width != required_width ||
         @cg_action_order_window.contents.height != required_height
        @cg_action_order_window.create_contents
        @cg_action_order_window.refresh
      end
    end
  end

  def cg_v183_focus_type(window)
    return :attack if window == nil
    return window.cg_v183_focus_type if window.respond_to?(:cg_v183_focus_type)
    return :attack
  rescue
    return :attack
  end

  # 覆寫 v1.8.2b 的焦點更新，使光環、連線與目前選項使用同一色系。
  def cg_v182b_update_focus
    return if @cg_v182b_focus == nil
    window = cg_v182b_focus_window
    battler = cg_v182b_focus_battler(window)
    if window == nil || battler == nil
      @cg_v182b_focus.hide
      return
    end
    anchor = cg_v182_sidecar_anchor(battler)
    @cg_v182b_focus.update(anchor, window, cg_v183_focus_type(window))
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  unless method_defined?(:albert_cg_v183_load_database)
    alias albert_cg_v183_load_database load_database
  end

  def load_database
    albert_cg_v183_load_database
    ALBERT_CG.apply_v183_title
  end
end
