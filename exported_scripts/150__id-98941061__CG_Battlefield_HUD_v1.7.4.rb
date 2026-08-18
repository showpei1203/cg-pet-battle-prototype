# RMVX_SCRIPT_INDEX: 150
# RMVX_SCRIPT_ID: 98941061
# RMVX_SCRIPT_NAME: CG Battlefield HUD v1.7.4
# RMVX_SOURCE_SHA256: e72bd24cb1762cce20c8e4984047afb1960d7a7a8f210e883724372ee30b5a01

#==============================================================================
# 【繁體中文說明】ALBERT CG 戰場浮動 HUD／浮動指令／捕捉訊息修正
#------------------------------------------------------------------------------
# 【版本】v1.7.4
# 【引擎】RPG Maker VX / RGSS2 / Ruby 1.8
# 【需求】Tankentai SBS 3.3、CG Action Order Preview v1.0、v1.6.1
#------------------------------------------------------------------------------
# 【用途】
#  1. 以跟隨戰鬥者位置的分離式 HUD 取代底部 Window_BattleStatus。
#  2. 我方 HP／MP 顯示在 Sprite 正右側；敵方短條顯示在 Sprite 左側。
#     雙方短條長度一致；我方只顯示目前 HP／MP，不顯示最大值。
#     名稱顯示在腳下，狀態在名稱下方。
#  3. 角色／寵物指令視窗顯示在目前行動者右側，並隨位置移動。
#  4. 將行動順序預覽固定為畫面最下方的緊湊資訊列。
#  5. 修正捕捉成功只有音效／SBS 動作、沒有可見訊息的問題。
#
# 【狀態顯示】
#  - 每名戰鬥者最多顯示 5 個有 Icon 的狀態。
#  - 超過 5 個時，最後顯示「+N」。
#  - 死亡中的我方仍保留 HUD，敵人死亡／逃離／捕捉後隱藏 HUD。
#
# 【介面原則】
#  - 原本的 @status_window 仍保留給內部索引與友方目標選擇使用，
#    但平時不顯示，避免破壞原生與 Tankentai 流程。
#  - 技能、物品及目標選擇視窗仍沿用既有流程。
#  - 浮動指令視窗會依目前 Sprite 座標重新定位；若靠近畫面邊緣，
#    會自動限制在可視範圍內。
#
# 【可調設定】
#  BATTLE_HUD_ALLY_BAR_WIDTH：我方 HP／MP 條總寬。
#  BATTLE_HUD_ENEMY_BAR_WIDTH：敵方 HP／MP 條總寬。
#  BATTLE_HUD_BAR_GAP：血條與 Sprite 左右距離。
#  BATTLE_HUD_NAME_GAP：名稱與 Sprite 腳底距離。
#  FLOAT_COMMAND_WIDTH / FLOAT_COMMAND_HEIGHT：指令視窗尺寸。
#  ACTION_ORDER_BOTTOM_Y：行動順序視窗 Y 座標。
#
# 【腳本位置】
#  放在 CG Capture Breeding Feedback Fix v1.6.1 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattlefieldHUD"] = true

module ALBERT_CG
  if const_defined?(:BATTLEFIELD_HUD_VERSION)
    remove_const(:BATTLEFIELD_HUD_VERSION)
  end
  BATTLEFIELD_HUD_VERSION = "1.7.4"

  # v1.7.4：我方與敵方使用同長短條；我方只顯示目前值。
  BATTLE_HUD_BAR_SPRITE_WIDTH = 42 unless const_defined?(:BATTLE_HUD_BAR_SPRITE_WIDTH)
  BATTLE_HUD_BAR_SPRITE_HEIGHT = 20 unless const_defined?(:BATTLE_HUD_BAR_SPRITE_HEIGHT)
  BATTLE_HUD_LABEL_WIDTH = 82 unless const_defined?(:BATTLE_HUD_LABEL_WIDTH)
  BATTLE_HUD_LABEL_HEIGHT = 32 unless const_defined?(:BATTLE_HUD_LABEL_HEIGHT)
  BATTLE_HUD_ALLY_BAR_WIDTH = 42 unless const_defined?(:BATTLE_HUD_ALLY_BAR_WIDTH)
  BATTLE_HUD_ENEMY_BAR_WIDTH = 42 unless const_defined?(:BATTLE_HUD_ENEMY_BAR_WIDTH)
  BATTLE_HUD_BAR_GAP = 2 unless const_defined?(:BATTLE_HUD_BAR_GAP)
  BATTLE_HUD_NAME_GAP = 1 unless const_defined?(:BATTLE_HUD_NAME_GAP)
  BATTLE_HUD_PET_BAR_Y_OFFSET = -20 unless const_defined?(:BATTLE_HUD_PET_BAR_Y_OFFSET)
  BATTLE_HUD_HUMAN_BAR_Y_OFFSET = 2 unless const_defined?(:BATTLE_HUD_HUMAN_BAR_Y_OFFSET)
  BATTLE_HUD_MAX_STATE_ICONS = 5 unless const_defined?(:BATTLE_HUD_MAX_STATE_ICONS)

  FLOAT_COMMAND_WIDTH = 112 unless const_defined?(:FLOAT_COMMAND_WIDTH)
  FLOAT_COMMAND_HEIGHT = 128 unless const_defined?(:FLOAT_COMMAND_HEIGHT)
  FLOAT_COMMAND_X_OFFSET = 18 unless const_defined?(:FLOAT_COMMAND_X_OFFSET)

  # 行動順序視窗必須在建立 Window 前就使用正確尺寸。
  # v1.7 先建立再 resize，某些 RGSS2 環境會留下空白 contents。
  [:ORDER_WINDOW_X, :ORDER_WINDOW_Y, :ORDER_WINDOW_WIDTH,
   :ORDER_WINDOW_HEIGHT].each do |constant_name|
    remove_const(constant_name) if const_defined?(constant_name)
  end
  ORDER_WINDOW_X = 0
  ORDER_WINDOW_Y = 352
  ORDER_WINDOW_WIDTH = 544
  ORDER_WINDOW_HEIGHT = 64
  ACTION_ORDER_BOTTOM_Y = ORDER_WINDOW_Y unless const_defined?(:ACTION_ORDER_BOTTOM_Y)

  CAPTURE_NOTICE_WIDTH = 488 unless const_defined?(:CAPTURE_NOTICE_WIDTH)
  CAPTURE_NOTICE_HEIGHT = 120 unless const_defined?(:CAPTURE_NOTICE_HEIGHT)
  CAPTURE_NOTICE_WAIT = 150 unless const_defined?(:CAPTURE_NOTICE_WAIT)

  def self.apply_v17_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.7.4"
  end
end

#==============================================================================
# ■ Sprite_CG_BattlerHUD
#------------------------------------------------------------------------------
#  戰場上的透明小型狀態面板。使用 Sprite 而非 Window，避免大量視窗。
#==============================================================================
class Sprite_CG_BattlerHUD
  def initialize(viewport, battler)
    @battler = battler
    @last_signature = nil

    @bar_sprite = Sprite.new(viewport)
    @bar_sprite.bitmap = Bitmap.new(ALBERT_CG::BATTLE_HUD_BAR_SPRITE_WIDTH,
      ALBERT_CG::BATTLE_HUD_BAR_SPRITE_HEIGHT)
    @bar_sprite.z = 260
    @bar_sprite.visible = false

    @label_sprite = Sprite.new(viewport)
    @label_sprite.bitmap = Bitmap.new(ALBERT_CG::BATTLE_HUD_LABEL_WIDTH,
      ALBERT_CG::BATTLE_HUD_LABEL_HEIGHT)
    @label_sprite.z = 261
    @label_sprite.visible = false
  end

  def disposed?
    return true if @bar_sprite == nil || @label_sprite == nil
    return @bar_sprite.disposed? || @label_sprite.disposed?
  end

  def dispose
    if @bar_sprite != nil && !@bar_sprite.disposed?
      @bar_sprite.bitmap.dispose if @bar_sprite.bitmap != nil &&
        !@bar_sprite.bitmap.disposed?
      @bar_sprite.dispose
    end
    if @label_sprite != nil && !@label_sprite.disposed?
      @label_sprite.bitmap.dispose if @label_sprite.bitmap != nil &&
        !@label_sprite.bitmap.disposed?
      @label_sprite.dispose
    end
    @bar_sprite = nil
    @label_sprite = nil
  end

  def visible=(value)
    value = value ? true : false
    @bar_sprite.visible = value if @bar_sprite != nil
    @label_sprite.visible = value if @label_sprite != nil
  end

  def cg_signature(active)
    state_ids = []
    begin
      for state in @battler.states
        state_ids.push(state.id.to_i) if state != nil && state.icon_index.to_i > 0
      end
    rescue
    end
    level = @battler.respond_to?(:level) ? @battler.level.to_i : 0
    return [@battler.name.to_s, level, @battler.hp.to_i,
      @battler.maxhp.to_i, @battler.mp.to_i, @battler.maxmp.to_i,
      state_ids, active ? 1 : 0]
  end

  def cg_ratio(value, maximum)
    maximum = maximum.to_i
    return 0 if maximum <= 0
    ratio = value.to_i * 100 / maximum
    ratio = 0 if ratio < 0
    ratio = 100 if ratio > 100
    return ratio
  end

  def cg_draw_bar(bitmap, x, y, width, value, maximum, color1, color2)
    ratio = cg_ratio(value, maximum)
    inner_width = width - 4
    fill_width = inner_width * ratio / 100
    bitmap.fill_rect(x, y, width, 9, Color.new(0, 0, 0, 255))
    bitmap.fill_rect(x + 1, y + 1, width - 2, 7,
      Color.new(18, 18, 18, 225))
    bitmap.fill_rect(x + 2, y + 2, inner_width, 5,
      Color.new(48, 48, 48, 230))
    if fill_width > 0
      fill_width = 1 if fill_width < 1
      fill_width = inner_width if fill_width > inner_width
      bitmap.gradient_fill_rect(x + 2, y + 2, fill_width, 5,
        color1, color2)
    end
  end

  # 我方與敵方都使用 42px 短條。
  # 我方只在條內顯示目前值，不顯示最大 HP／MP。
  def cg_draw_gauge_row(bitmap, x, y, width, value, maximum, color1, color2,
      show_value)
    cg_draw_bar(bitmap, x, y, width, value, maximum, color1, color2)
    return unless show_value
    text = value.to_i.to_s
    old_size = bitmap.font.size
    old_bold = bitmap.font.bold
    old_color = bitmap.font.color
    bitmap.font.size = 9
    bitmap.font.bold = true
    bitmap.font.color = Color.new(0, 0, 0, 230)
    bitmap.draw_text(x + 1, y - 2, width - 3, 12, text, 2)
    bitmap.font.color = Color.new(255, 255, 255)
    bitmap.draw_text(x, y - 3, width - 3, 12, text, 2)
    bitmap.font.size = old_size
    bitmap.font.bold = old_bold
    bitmap.font.color = old_color
  end

  def cg_draw_small_icon(bitmap, icon_index, x, y)
    return if icon_index.to_i <= 0
    iconset = Cache.system("IconSet")
    sx = icon_index.to_i % 16 * 24
    sy = icon_index.to_i / 16 * 24
    source = Rect.new(sx, sy, 24, 24)
    target = Rect.new(x, y, 12, 12)
    bitmap.stretch_blt(target, iconset, source)
  rescue
  end

  def cg_hp_colors
    ratio = cg_ratio(@battler.hp, @battler.maxhp)
    if ratio <= 25
      return [Color.new(255, 72, 72), Color.new(170, 20, 20)]
    elsif ratio <= 50
      return [Color.new(255, 220, 72), Color.new(190, 120, 20)]
    end
    return [Color.new(96, 255, 112), Color.new(22, 160, 54)]
  end

  def cg_battle_pet_actor?
    return false unless @battler.actor?
    if @battler.respond_to?(:cg_battle_pet?)
      return @battler.cg_battle_pet? ? true : false
    end
    if @battler.respond_to?(:cg_pet?)
      return @battler.cg_pet? ? true : false
    end
    return false
  rescue
    return false
  end

  def refresh(active = false)
    bar_bitmap = @bar_sprite.bitmap
    label_bitmap = @label_sprite.bitmap
    bar_bitmap.clear
    label_bitmap.clear

    show_value = @battler.actor?
    gauge_width = show_value ? ALBERT_CG::BATTLE_HUD_ALLY_BAR_WIDTH :
      ALBERT_CG::BATTLE_HUD_ENEMY_BAR_WIDTH
    gauge_x = show_value ? 0 : bar_bitmap.width - gauge_width
    font = bar_bitmap.font
    font.size = 9
    font.bold = false
    font.color = Color.new(255, 255, 255)
    hp1, hp2 = cg_hp_colors
    cg_draw_gauge_row(bar_bitmap, gauge_x, 0, gauge_width,
      @battler.hp, @battler.maxhp, hp1, hp2, show_value)
    cg_draw_gauge_row(bar_bitmap, gauge_x, 10, gauge_width,
      @battler.mp, @battler.maxmp,
      Color.new(80, 190, 255), Color.new(34, 88, 210), show_value)

    # 名稱仍在腳下，不畫底框。字太長時自動縮小，避免踩到隔壁單位。
    label_font = label_bitmap.font
    label_font.bold = active
    label = @battler.name.to_s
    name_size = 14
    label_font.size = name_size
    while name_size > 10 && label_bitmap.text_size(label).width >
        label_bitmap.width - 4
      name_size -= 1
      label_font.size = name_size
    end
    label_font.color = Color.new(0, 0, 0, 220)
    label_bitmap.draw_text(3, 1, label_bitmap.width - 4, 16, label, 1)
    label_font.color = active ? Color.new(255, 236, 130) :
      Color.new(255, 255, 255)
    label_bitmap.draw_text(2, 0, label_bitmap.width - 4, 16, label, 1)

    states = []
    begin
      for state in @battler.states
        states.push(state) if state != nil && state.icon_index.to_i > 0
      end
    rescue
    end
    maximum = ALBERT_CG::BATTLE_HUD_MAX_STATE_ICONS
    display_count = [states.size, maximum].min
    icon_total_width = display_count * 14
    icon_x = (label_bitmap.width - icon_total_width) / 2
    for i in 0...display_count
      cg_draw_small_icon(label_bitmap, states[i].icon_index,
        icon_x + i * 14, 18)
    end
    if states.size > maximum
      label_font.size = 10
      label_font.bold = false
      label_font.color = Color.new(255, 220, 120)
      label_bitmap.draw_text(label_bitmap.width - 28, 17, 26, 14,
        "+" + (states.size - maximum).to_s, 2)
    end
  end

  # anchor = [left, top, right, bottom, center_x, center_y]
  def update_display(anchor, active, show)
    self.visible = show
    return unless show
    return if anchor == nil
    signature = cg_signature(active)
    if @last_signature != signature
      @last_signature = signature
      refresh(active)
    end

    left, top, right, bottom, center_x, center_y = anchor
    if @battler.actor?
      panel_width = ALBERT_CG::BATTLE_HUD_ALLY_BAR_WIDTH
      panel_x = right.to_i + ALBERT_CG::BATTLE_HUD_BAR_GAP
      maximum_panel_x = Graphics.width - panel_width - 2
      panel_x = maximum_panel_x if panel_x > maximum_panel_x
      panel_x = 2 if panel_x < 2
      @bar_sprite.x = panel_x
      # 我方人物與寵物一律緊貼 Sprite 正右側，垂直置中。
      @bar_sprite.y = center_y.to_i - @bar_sprite.bitmap.height / 2
    else
      panel_width = ALBERT_CG::BATTLE_HUD_ENEMY_BAR_WIDTH
      panel_x = left.to_i - panel_width - ALBERT_CG::BATTLE_HUD_BAR_GAP
      panel_x = 2 if panel_x < 2
      # 敵方短條畫在 bitmap 的右側，讓可見區緊貼 Sprite 左邊。
      @bar_sprite.x = panel_x - (@bar_sprite.bitmap.width - panel_width)
      @bar_sprite.y = center_y.to_i - @bar_sprite.bitmap.height / 2
    end

    @label_sprite.x = center_x.to_i - @label_sprite.bitmap.width / 2
    @label_sprite.y = bottom.to_i + ALBERT_CG::BATTLE_HUD_NAME_GAP

    @bar_sprite.y = 2 if @bar_sprite.y < 2
    maximum_bar_y = ALBERT_CG::ORDER_WINDOW_Y - @bar_sprite.bitmap.height - 2
    @bar_sprite.y = maximum_bar_y if @bar_sprite.y > maximum_bar_y

    @label_sprite.x = 0 if @label_sprite.x < 0
    if @label_sprite.x + @label_sprite.bitmap.width > Graphics.width
      @label_sprite.x = Graphics.width - @label_sprite.bitmap.width
    end
    maximum_label_y = ALBERT_CG::ORDER_WINDOW_Y - @label_sprite.bitmap.height - 2
    @label_sprite.y = maximum_label_y if @label_sprite.y > maximum_label_y
    @label_sprite.y = 0 if @label_sprite.y < 0
  end
end

#==============================================================================
# ■ Window_CG_BattleNotice
#------------------------------------------------------------------------------
#  捕捉成功專用訊息，不依賴 BattleMessage／HelpWindow 的生命週期。
#==============================================================================
class Window_CG_BattleNotice < Window_Base
  def initialize(lines)
    width = ALBERT_CG::CAPTURE_NOTICE_WIDTH
    height = ALBERT_CG::CAPTURE_NOTICE_HEIGHT
    x = (Graphics.width - width) / 2
    y = (Graphics.height - height) / 2
    super(x, y, width, height)
    self.z = 600
    self.back_opacity = 220
    @lines = lines == nil ? [] : lines
    refresh
  end

  def refresh
    self.contents.clear
    old_size = self.contents.font.size
    for i in 0...@lines.size
      break if i >= 4
      self.contents.font.size = i == 0 ? 22 : 18
      self.contents.font.color = i == 0 ? power_up_color : normal_color
      self.contents.draw_text(0, i * 22, self.contents.width, 22,
        @lines[i].to_s, i == 0 ? 1 : 0)
    end
    self.contents.font.size = old_size
  end
end

#==============================================================================
# ■ Window_ActorCommand：浮動版尺寸
#==============================================================================
class Window_ActorCommand < Window_Command
  alias albert_cg_v17_floating_command_setup setup
  def setup(actor)
    albert_cg_v17_floating_command_setup(actor)
    self.width = ALBERT_CG::FLOAT_COMMAND_WIDTH
    self.height = ALBERT_CG::FLOAT_COMMAND_HEIGHT
    create_contents
    self.contents.font.size = 17
    self.top_row = 0 if respond_to?(:top_row=)
    refresh
    self.index = 0 if self.index == nil || self.index < 0
    self.back_opacity = 205
  end
end

#==============================================================================
# ■ Spriteset_Battle：取得真正對應 Battler 的即時 Sprite 範圍
#------------------------------------------------------------------------------
#  不再只相信 battler.index，避免動態隊伍／換寵後 HUD 跟錯 Sprite。
#==============================================================================
class Spriteset_Battle
  def cg_v171_find_battler_sprite(battler)
    return nil if battler == nil
    sprites = battler.actor? ? @actor_sprites : @enemy_sprites
    return nil if sprites == nil
    for sprite in sprites
      next if sprite == nil
      sprite_battler = nil
      begin
        sprite_battler = sprite.battler
      rescue
      end
      return sprite if sprite_battler.equal?(battler)
    end
    return nil
  end

  def cg_v171_battler_anchor(battler)
    sprite = cg_v171_find_battler_sprite(battler)
    return nil if sprite == nil
    width = 32
    height = 32
    begin
      width = sprite.src_rect.width if sprite.src_rect != nil &&
        sprite.src_rect.width.to_i > 0
      height = sprite.src_rect.height if sprite.src_rect != nil &&
        sprite.src_rect.height.to_i > 0
    rescue
    end
    zoom_x = sprite.respond_to?(:zoom_x) ? sprite.zoom_x.to_f : 1.0
    zoom_y = sprite.respond_to?(:zoom_y) ? sprite.zoom_y.to_f : 1.0
    width = (width * zoom_x).to_i
    height = (height * zoom_y).to_i
    ox = sprite.respond_to?(:ox) ? (sprite.ox.to_f * zoom_x).to_i : width / 2
    oy = sprite.respond_to?(:oy) ? (sprite.oy.to_f * zoom_y).to_i : height
    left = sprite.x.to_i - ox
    top = sprite.y.to_i - oy
    right = left + width
    bottom = top + height
    center_x = left + width / 2
    center_y = top + height / 2
    return [left, top, right, bottom, center_x, center_y]
  rescue
    return nil
  end
end

#==============================================================================
# ■ Window_CG_ActionOrder：v1.7.4 緊湊底部列
#==============================================================================
class Window_CG_ActionOrder < Window_Base
  alias albert_cg_v171_order_initialize initialize
  def initialize
    albert_cg_v171_order_initialize
    self.x = ALBERT_CG::ORDER_WINDOW_X
    self.y = ALBERT_CG::ORDER_WINDOW_Y
    self.width = ALBERT_CG::ORDER_WINDOW_WIDTH
    self.height = ALBERT_CG::ORDER_WINDOW_HEIGHT
    self.z = 420
    self.opacity = 255
    self.contents_opacity = 255
    self.back_opacity = 185
    create_contents
    clear_order
  end

  alias albert_cg_v171_order_set_order set_order
  def set_order(current_battler, current_action, queue)
    if self.contents == nil || self.contents.disposed? ||
       self.contents.width != self.width - 32 ||
       self.contents.height != self.height - 32
      create_contents
    end
    self.opacity = 255
    self.contents_opacity = 255
    albert_cg_v171_order_set_order(current_battler, current_action, queue)
  end

  def draw_order_card(index, battler, action, current)
    x = index * ALBERT_CG::ORDER_CARD_WIDTH
    width = ALBERT_CG::ORDER_CARD_WIDTH - 2
    height = self.contents.height
    border = current ? power_up_color : system_color
    background = current ? Color.new(255, 255, 255, 42) : Color.new(0, 0, 0, 58)
    self.contents.fill_rect(x, 0, width, height, border)
    self.contents.fill_rect(x + 1, 1, width - 2, height - 2, background)

    draw_order_character(battler, x + 13, 27)
    old_size = self.contents.font.size
    old_color = self.contents.font.color
    self.contents.font.size = 13
    self.contents.font.color = current ? power_up_color : normal_color
    self.contents.draw_text(x + 27, 0, width - 29, 15,
      battler.name.to_s, 0)

    label = action == nil ? "待機" : action.cg_order_action_name
    self.contents.font.size = 11
    self.contents.font.color = battler.actor? ? system_color : crisis_color
    speed_text = ""
    if ALBERT_CG::ORDER_SHOW_SPEED
      speed = action == nil ? 0 : action.speed.to_i
      speed_text = " " + speed.to_s
    end
    self.contents.draw_text(x + 27, 15, width - 29, 14,
      label.to_s + speed_text, 0)
    self.contents.font.size = old_size
    self.contents.font.color = old_color
  end

  def draw_order_character(battler, x, y)
    name, index = cg_character_data(battler)
    return if name == nil || name.empty?
    begin
      bitmap = Cache.character(name)
      sign = name[/^[\!\$]./]
      single = sign != nil && sign.include?("$")
      cw = bitmap.width / (single ? 3 : 12)
      ch = bitmap.height / (single ? 4 : 8)
      pattern = 1
      direction = 0
      if single
        sx = pattern * cw
        sy = direction * ch
      else
        sx = (index % 4 * 3 + pattern) * cw
        sy = (index / 4 * 4 + direction) * ch
      end
      source = Rect.new(sx, sy, cw, ch)
      destination = Rect.new(x - 10, y - 22, 20, 22)
      self.contents.stretch_blt(destination, bitmap, source)
    rescue
    end
  end
end

#==============================================================================
# ■ Scene_Battle
#==============================================================================
class Scene_Battle < Scene_Base
  alias albert_cg_v17_hud_start start
  def start
    albert_cg_v17_hud_start
    @cg_v17_hud_viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @cg_v17_hud_viewport.z = 240
    @cg_v17_hud_sprites = {}
    cg_v17_configure_battle_windows
    cg_v17_sync_hud_sprites
  end

  alias albert_cg_v17_hud_terminate terminate
  def terminate
    cg_v17_dispose_hud
    albert_cg_v17_hud_terminate
  end

  def cg_v17_dispose_hud
    if @cg_v17_hud_sprites != nil
      for key in @cg_v17_hud_sprites.keys
        sprite = @cg_v17_hud_sprites[key]
        sprite.dispose if sprite != nil && !sprite.disposed?
      end
      @cg_v17_hud_sprites.clear
    end
    if @cg_v17_hud_viewport != nil && !@cg_v17_hud_viewport.disposed?
      @cg_v17_hud_viewport.dispose
    end
    @cg_v17_hud_viewport = nil
  end

  def cg_v17_configure_battle_windows
    if @status_window != nil
      @status_window.visible = false
      @status_window.active = false
    end
    if @info_viewport != nil
      @info_viewport.visible = false
    end
    if @actor_command_window != nil
      @actor_command_window.viewport = nil
      @actor_command_window.z = 500
      @actor_command_window.visible = false
    end
    if @party_command_window != nil
      @party_command_window.viewport = nil
      @party_command_window.z = 500
      @party_command_window.x = Graphics.width - @party_command_window.width - 4
      @party_command_window.y = Graphics.height - @party_command_window.height - 4
      @party_command_window.visible = false
    end
    if @cg_phase_window != nil
      @cg_phase_window.visible = false
    end
    if @cg_action_order_window != nil
      @cg_action_order_window.viewport = nil
      @cg_action_order_window.x = ALBERT_CG::ORDER_WINDOW_X
      @cg_action_order_window.y = ALBERT_CG::ORDER_WINDOW_Y
      @cg_action_order_window.z = 420
      @cg_action_order_window.opacity = 255
      @cg_action_order_window.contents_opacity = 255
    end
  end

  def cg_v17_all_hud_battlers
    result = []
    if $game_party != nil
      for actor in $game_party.members
        result.push(actor) if actor != nil
      end
    end
    if $game_troop != nil
      for enemy in $game_troop.members
        result.push(enemy) if enemy != nil
      end
    end
    return result
  end

  def cg_v17_sync_hud_sprites
    return if @cg_v17_hud_viewport == nil
    @cg_v17_hud_sprites = {} if @cg_v17_hud_sprites == nil
    battlers = cg_v17_all_hud_battlers
    wanted = {}
    for battler in battlers
      key = battler.object_id
      wanted[key] = true
      unless @cg_v17_hud_sprites.has_key?(key)
        @cg_v17_hud_sprites[key] = Sprite_CG_BattlerHUD.new(
          @cg_v17_hud_viewport, battler)
      end
    end
    for key in @cg_v17_hud_sprites.keys
      next if wanted[key]
      sprite = @cg_v17_hud_sprites[key]
      sprite.dispose if sprite != nil && !sprite.disposed?
      @cg_v17_hud_sprites.delete(key)
    end
  end

  def cg_v17_battler_anchor(battler)
    return nil if battler == nil || @spriteset == nil
    if @spriteset.respond_to?(:cg_v171_battler_anchor)
      anchor = @spriteset.cg_v171_battler_anchor(battler)
      return anchor if anchor != nil
    end
    index = battler.index
    return nil if index == nil
    point = @spriteset.set_cursor(battler.actor?, index)
    return nil if point == nil
    x = point[0].to_i
    y = point[1].to_i
    return [x - 16, y - 32, x + 16, y, x, y - 16]
  rescue
    return nil
  end

  def cg_v17_hud_visible_for?(battler)
    return false if battler == nil
    if battler.actor?
      return false if $game_party == nil
      return $game_party.members.include?(battler)
    end
    return battler.respond_to?(:exist?) ? battler.exist? : true
  end

  def cg_v17_update_huds
    cg_v17_sync_hud_sprites
    return if @cg_v17_hud_sprites == nil
    for battler in cg_v17_all_hud_battlers
      sprite = @cg_v17_hud_sprites[battler.object_id]
      next if sprite == nil
      anchor = cg_v17_battler_anchor(battler)
      active = @active_battler == battler && @actor_command_window != nil &&
        @actor_command_window.active
      sprite.update_display(anchor, active, cg_v17_hud_visible_for?(battler))
    end
  end

  def cg_v17_place_actor_command
    return if @actor_command_window == nil
    return if @active_battler == nil
    anchor = cg_v17_battler_anchor(@active_battler)
    return if anchor == nil
    x = anchor[2].to_i + ALBERT_CG::FLOAT_COMMAND_X_OFFSET
    maximum_x = Graphics.width - @actor_command_window.width - 4
    x = maximum_x if x > maximum_x
    x = 4 if x < 4
    y = anchor[5].to_i - @actor_command_window.height / 2
    maximum_y = Graphics.height - @actor_command_window.height - 4
    y = maximum_y if y > maximum_y
    y = 4 if y < 4
    @actor_command_window.x = x
    @actor_command_window.y = y
  end

  def cg_v17_update_window_visibility
    if @info_viewport != nil
      @info_viewport.visible = false
    end
    @status_window.visible = false if @status_window != nil
    @cg_phase_window.visible = false if @cg_phase_window != nil

    if @actor_command_window != nil
      visible = @actor_command_window.active && !$game_message.visible
      visible = false if @skill_window != nil || @item_window != nil
      @actor_command_window.visible = visible
      cg_v17_place_actor_command if visible
    end
    if @party_command_window != nil
      visible = @party_command_window.active && !$game_message.visible
      @party_command_window.visible = visible
    end
  end

  alias albert_cg_v17_hud_update_basic update_basic
  def update_basic(main = false)
    albert_cg_v17_hud_update_basic(main)
    cg_v17_update_huds
    cg_v17_update_window_visibility
  end

  alias albert_cg_v17_hud_start_party_command start_party_command_selection
  def start_party_command_selection
    result = albert_cg_v17_hud_start_party_command
    cg_v17_configure_battle_windows
    if @party_command_window != nil
      @party_command_window.visible = @party_command_window.active
    end
    return result
  end

  alias albert_cg_v17_hud_start_actor_command start_actor_command_selection
  def start_actor_command_selection
    result = albert_cg_v17_hud_start_actor_command
    cg_v17_configure_battle_windows
    @actor_command_window.visible = true if @actor_command_window != nil
    cg_v17_place_actor_command
    return result
  end

  alias albert_cg_v17_hud_start_main start_main
  def start_main
    @actor_command_window.visible = false if @actor_command_window != nil
    @actor_command_window.active = false if @actor_command_window != nil
    @party_command_window.visible = false if @party_command_window != nil
    @party_command_window.active = false if @party_command_window != nil
    albert_cg_v17_hud_start_main
  end

  # 捕捉成功改用獨立訊息視窗，避免 BattleMessage 不吃 $game_message。
  def cg_v17_show_battle_notice(lines, duration = nil)
    duration = ALBERT_CG::CAPTURE_NOTICE_WAIT if duration == nil
    window = Window_CG_BattleNotice.new(lines)
    wait_count = 0
    loop do
      update_basic
      window.update
      wait_count += 1
      break if wait_count >= duration.to_i
      if wait_count >= 12 && (Input.trigger?(Input::C) || Input.trigger?(Input::B))
        Sound.play_decision
        break
      end
    end
    window.dispose unless window.disposed?
  end

  # 覆寫 v1.6.1 的成功訊息層；音效、VICTORY 與姿勢恢復仍沿用。
  def cg_v161_show_capture_success(user, pet, rate)
    place = cg_v161_capture_destination_text(pet)
    identity = ""
    if pet.respond_to?(:cg_gender_symbol) && pet.respond_to?(:cg_nature_name)
      identity = " " + pet.cg_gender_symbol.to_s + "／" + pet.cg_nature_name.to_s
    end
    ALBERT_CG.play_capture_success_sound
    cg_v161_play_capture_victory(user)
    lines = []
    lines.push("捕捉成功！")
    lines.push(user.name.to_s + "捕捉了" + pet.name.to_s + identity + "。")
    lines.push("個體 #" + pet.id.to_s + " 已加入" + place + "。")
    lines.push("本次捕捉成功率：" + rate.to_s + "%")
    cg_v17_show_battle_notice(lines)
    cg_v161_restore_capture_user_pose(user)
  end
end

#==============================================================================
# ■ Scene_Title：版本標題
#==============================================================================
class Scene_Title < Scene_Base
  alias albert_cg_v17_hud_load_database load_database
  def load_database
    albert_cg_v17_hud_load_database
    ALBERT_CG.apply_v17_title
  end

  alias albert_cg_v17_hud_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v17_hud_load_bt_database
    ALBERT_CG.apply_v17_title
  end
end
