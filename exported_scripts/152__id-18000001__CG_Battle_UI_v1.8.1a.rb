# RMVX_SCRIPT_INDEX: 152
# RMVX_SCRIPT_ID: 18000001
# RMVX_SCRIPT_NAME: CG Battle UI v1.8.1a
# RMVX_SOURCE_SHA256: 36ec1a54a912e3a4229b34c2d4470e3688d16edd95112623fdf6877f0374bbc8

#==============================================================================
# 【繁體中文說明】ALBERT CG 正式戰鬥 UI 第一階段
#------------------------------------------------------------------------------
# 【版本】v1.8.1a
# 【引擎】RPG Maker VX / RGSS2 / Ruby 1.8
# 【需求】CG Battlefield HUD v1.7.4、CG Action Order Preview v1.0
#------------------------------------------------------------------------------
# 【本版範圍】
#  1. Spin Command 改以目前 battler 為圓心，指令文字移到角色下方。
#  2. 行動順序 Window 的 opacity／back_opacity 均固定為 0，只顯示卡片。
#  3. Battle Status 目前行動者改為金色粗框、底色脈動與「行動」標記。
#  4. 支援 TRGSSX 視覺轉接層：
#     - DLL 存在時使用高品質行走圖縮放與正六角形 Spin 節點。
#     - DLL 缺少時自動退回 RGSS2 原生繪圖，不破壞戰鬥流程。
#  5. 保留 v1.8.1 的動態 4／5／7 項 Spin Command、敵方 HUD、
#     Battle Message 隱藏 Battle Status 與底部六格配對狀態。
#
# 【刻意不處理】
#  - 格位／範圍目標預覽：排入 v1.8.2。
#  - 寶可夢完整傷害公式與相剋：排入後續屬性核心。
#  - 雙指令、捕捉、換寵、速度與戰場規則：本版不修改。
#
# 【腳本位置】
#  放在 CG Battlefield HUD v1.7.4 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattleUI_1_8_1a"] = true

module ALBERT_CG
  if const_defined?(:BATTLE_UI_VERSION)
    remove_const(:BATTLE_UI_VERSION)
  end
  BATTLE_UI_VERSION = "1.8.1a"

  #------------------------------------------------------------------------
  # Battle layout
  #------------------------------------------------------------------------
  BATTLE_ORDER_HEIGHT = 64 unless const_defined?(:BATTLE_ORDER_HEIGHT)
  BATTLE_STATUS_Y = 304 unless const_defined?(:BATTLE_STATUS_Y)
  BATTLE_STATUS_HEIGHT = 112 unless const_defined?(:BATTLE_STATUS_HEIGHT)
  BATTLE_STATUS_SLOT_COUNT = 6 unless const_defined?(:BATTLE_STATUS_SLOT_COUNT)
  BATTLE_STATUS_MAX_STATES = 3 unless const_defined?(:BATTLE_STATUS_MAX_STATES)

  # Action Order：緊貼 Battle Status 右上方。
  [:ORDER_WINDOW_X, :ORDER_WINDOW_Y, :ORDER_WINDOW_WIDTH,
   :ORDER_WINDOW_HEIGHT, :ORDER_CARD_WIDTH, :ORDER_CARD_COUNT].each do |name|
    remove_const(name) if const_defined?(name)
  end
  ORDER_WINDOW_WIDTH = 288
  ORDER_WINDOW_HEIGHT = 64
  ORDER_WINDOW_X = 544 - ORDER_WINDOW_WIDTH
  ORDER_WINDOW_Y = BATTLE_STATUS_Y - ORDER_WINDOW_HEIGHT + 12
  ORDER_CARD_WIDTH = 32
  ORDER_CARD_COUNT = 8

  # Spin Command layout.
  # 視窗透明；真正的圓心以 battler 中心為準。
  # 文字標籤放在角色下方，不再擋住中央行走圖。
  SPIN_WINDOW_WIDTH = 160
  SPIN_WINDOW_HEIGHT = 160
  SPIN_CENTER_X = 64
  SPIN_CENTER_Y = 52
  SPIN_LABEL_OFFSET_Y = 20
  SPIN_RADIUS = 39
  SPIN_NODE_SIZE = 24
  SPIN_COMMAND_GAP = 0
  SPIN_Z = 520

  #------------------------------------------------------------------------
  # Pokemon type UI interface
  #------------------------------------------------------------------------
  TYPE_NAMES = {
    :normal=>"普", :fighting=>"鬥", :flying=>"飛", :poison=>"毒",
    :ground=>"地", :rock=>"岩", :bug=>"蟲", :ghost=>"幽",
    :steel=>"鋼", :fire=>"火", :water=>"水", :grass=>"草",
    :electric=>"電", :psychic=>"超", :ice=>"冰", :dragon=>"龍",
    :dark=>"惡", :fairy=>"妖"
  }

  # Prototype species only. The formal type database will replace this table.
  SPECIES_TYPE_KEYS = {
    100=>[:grass, :poison], 101=>[:grass, :poison],
    102=>[:grass, :poison],
    103=>[:fire], 104=>[:fire], 105=>[:fire, :flying],
    106=>[:water], 107=>[:water, :ground], 108=>[:water, :ground]
  }

  def self.cg_ui_type_color(key)
    case key
    when :normal   then return Color.new(168, 168, 120)
    when :fighting then return Color.new(192, 48, 40)
    when :flying   then return Color.new(168, 144, 240)
    when :poison   then return Color.new(160, 64, 160)
    when :ground   then return Color.new(224, 192, 104)
    when :rock     then return Color.new(184, 160, 56)
    when :bug      then return Color.new(168, 184, 32)
    when :ghost    then return Color.new(112, 88, 152)
    when :steel    then return Color.new(184, 184, 208)
    when :fire     then return Color.new(240, 128, 48)
    when :water    then return Color.new(104, 144, 240)
    when :grass    then return Color.new(120, 200, 80)
    when :electric then return Color.new(248, 208, 48)
    when :psychic  then return Color.new(248, 88, 136)
    when :ice      then return Color.new(152, 216, 216)
    when :dragon   then return Color.new(112, 56, 248)
    when :dark     then return Color.new(112, 88, 72)
    when :fairy    then return Color.new(238, 153, 172)
    end
    return Color.new(128, 128, 128)
  end

  def self.cg_ui_actor_form_id(actor)
    return 0 if actor == nil
    if actor.respond_to?(:cg_current_form_actor_id)
      value = actor.cg_current_form_actor_id.to_i
      return value if value > 0
    end
    if actor.respond_to?(:cg_database_actor_id)
      value = actor.cg_database_actor_id.to_i
      return value if value > 0
    end
    if actor.respond_to?(:cg_species_id)
      value = actor.cg_species_id.to_i
      return value if value > 0
    end
    return actor.respond_to?(:id) ? actor.id.to_i : 0
  rescue
    return actor.respond_to?(:id) ? actor.id.to_i : 0
  end

  def self.cg_ui_type_keys(battler)
    return [] if battler == nil
    if battler.actor?
      is_pet = battler.respond_to?(:cg_battle_pet?) && battler.cg_battle_pet?
      return [:normal] unless is_pet
      form_id = cg_ui_actor_form_id(battler)
      result = SPECIES_TYPE_KEYS[form_id]
      return result == nil ? [] : result.clone
    end
    if battler.respond_to?(:cg_capture_species_id)
      species_id = battler.cg_capture_species_id.to_i
      result = SPECIES_TYPE_KEYS[species_id]
      return result == nil ? [] : result.clone
    end
    return []
  rescue
    return []
  end

  def self.cg_ui_fixed_pet?(actor)
    return false if actor == nil
    return actor.cg_fixed_partner_pet? if actor.respond_to?(:cg_fixed_partner_pet?)
    if $game_party != nil && $game_party.respond_to?(:cg_fixed_partner_pet_actor?)
      return $game_party.cg_fixed_partner_pet_actor?(actor)
    end
    return false
  rescue
    return false
  end

  def self.cg_ui_identity_text(actor)
    return "" if actor == nil
    is_pet = actor.respond_to?(:cg_battle_pet?) && actor.cg_battle_pet?
    return "人" unless is_pet
    return "契" if cg_ui_fixed_pet?(actor)
    return "寵"
  end

  def self.cg_ui_pair_owner(actor)
    return nil if actor == nil || $game_party == nil
    is_pet = actor.respond_to?(:cg_battle_pet?) && actor.cg_battle_pet?
    return actor unless is_pet
    if $game_party.respond_to?(:cg_battle_pair_owner_for)
      return $game_party.cg_battle_pair_owner_for(actor)
    end
    if $game_party.respond_to?(:cg_battle_owner_for_pet)
      return $game_party.cg_battle_owner_for_pet(actor)
    end
    return nil
  rescue
    return nil
  end

  def self.cg_ui_pair_number(actor)
    return 0 if actor == nil || $game_party == nil
    owner = cg_ui_pair_owner(actor)
    return 0 if owner == nil
    humans = $game_party.respond_to?(:cg_human_members) ?
      $game_party.cg_human_members : $game_party.members
    index = humans.index(owner)
    return index == nil ? 0 : index + 1
  rescue
    return 0
  end

  def self.apply_v180_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.8.1a"
  end
end

#==============================================================================
# ■ Window_BattleStatus
#------------------------------------------------------------------------------
#  Six compact cards. Party order remains authoritative so all existing actor
#  indices, command slots and target indices stay unchanged.
#==============================================================================
class Window_BattleStatus < Window_Selectable
  def initialize
    super(0, ALBERT_CG::BATTLE_STATUS_Y, Graphics.width,
      ALBERT_CG::BATTLE_STATUS_HEIGHT)
    self.z = 430
    self.opacity = 0
    self.back_opacity = 0
    self.active = false
    self.index = -1
    @item_max = 0
    @cg_last_signature = nil
    @cg_refresh_wait = 0
    refresh
  end

  def item_max
    return @item_max == nil ? 0 : @item_max
  end

  def cg_slot_width
    return self.contents.width / ALBERT_CG::BATTLE_STATUS_SLOT_COUNT
  end

  def item_rect(index)
    width = cg_slot_width
    x = index.to_i * width
    if index.to_i == ALBERT_CG::BATTLE_STATUS_SLOT_COUNT - 1
      width = self.contents.width - x
    end
    return Rect.new(x, 0, width, self.contents.height)
  end

  def index=(value)
    old_index = @index
    @index = value == nil ? -1 : value.to_i
    refresh if old_index != @index && self.contents != nil
  end

  def refresh
    return if self.contents == nil || self.contents.disposed?
    self.contents.clear
    members = $game_party == nil ? [] : $game_party.members
    @item_max = [members.size, ALBERT_CG::BATTLE_STATUS_SLOT_COUNT].min
    for slot_index in 0...ALBERT_CG::BATTLE_STATUS_SLOT_COUNT
      actor = slot_index < @item_max ? members[slot_index] : nil
      cg_draw_status_slot(slot_index, actor)
    end
    @cg_last_signature = cg_status_signature
    update_cursor
  end

  def update
    super
    @cg_refresh_wait += 1
    return if @cg_refresh_wait < 4
    @cg_refresh_wait = 0
    signature = cg_status_signature
    refresh if signature != @cg_last_signature
  end

  def update_cursor
    if @index == nil || @index < 0 || @index >= @item_max
      self.cursor_rect.empty
    else
      rect = item_rect(@index)
      rect.x += 2
      rect.y += 2
      rect.width -= 4
      rect.height -= 4
      self.cursor_rect.set(rect.x, rect.y, rect.width, rect.height)
    end
  end

  def cg_status_signature
    # 目前指令角色加入柔和脈動，讓高亮不只是一條幾乎看不見的邊框。
    pulse = @index != nil && @index >= 0 ?
      (Graphics.frame_count / 10) % 2 : 0
    result = [@index, self.active ? 1 : 0, pulse]
    return result if $game_party == nil
    members = $game_party.members
    maximum = [members.size, ALBERT_CG::BATTLE_STATUS_SLOT_COUNT].min
    for i in 0...maximum
      actor = members[i]
      states = []
      begin
        for state in actor.states
          states.push(state.id.to_i) if state != nil
        end
      rescue
      end
      result.push([actor.object_id, actor.name.to_s, actor.level.to_i,
        actor.hp.to_i, actor.maxhp.to_i, actor.mp.to_i, actor.maxmp.to_i,
        states, ALBERT_CG.cg_ui_actor_form_id(actor)])
    end
    return result
  end

  def cg_pair_color(pair_number)
    case pair_number.to_i
    when 1 then return Color.new(86, 150, 214, 210)
    when 2 then return Color.new(102, 184, 126, 210)
    when 3 then return Color.new(214, 150, 82, 210)
    end
    return Color.new(150, 150, 150, 180)
  end

  def cg_identity_color(actor)
    text = ALBERT_CG.cg_ui_identity_text(actor)
    return Color.new(88, 138, 210, 230) if text == "人"
    return Color.new(185, 116, 210, 230) if text == "契"
    return Color.new(94, 178, 112, 230)
  end

  def cg_draw_status_slot(index, actor)
    rect = item_rect(index)
    pair_number = actor == nil ? (index / 2 + 1) :
      ALBERT_CG.cg_ui_pair_number(actor)
    pair_number = index / 2 + 1 if pair_number <= 0
    pair_color = cg_pair_color(pair_number)
    selected = actor != nil && index == @index
    pulse = (Graphics.frame_count / 10) % 2

    if selected
      background = pulse == 0 ?
        Color.new(58, 45, 10, 235) : Color.new(78, 60, 12, 242)
    else
      background = (index / 2) % 2 == 0 ?
        Color.new(4, 12, 24, 205) : Color.new(11, 22, 18, 205)
    end
    self.contents.fill_rect(rect.x + 1, rect.y + 1,
      rect.width - 2, rect.height - 2, background)
    self.contents.fill_rect(rect.x + 1, rect.y + 1,
      rect.width - 2, selected ? 5 : 3,
      selected ? Color.new(255, 222, 82, 245) : pair_color)

    # Card border and pair separators.
    if selected
      glow = pulse == 0 ? Color.new(255, 224, 84, 255) :
        Color.new(255, 248, 170, 255)
      cg_draw_thick_rect_border(rect.x + 1, rect.y + 1,
        rect.width - 2, rect.height - 2, glow, 3)
      self.contents.fill_rect(rect.x + 4, rect.y + 5,
        rect.width - 8, rect.height - 9, Color.new(255, 230, 110, 20))
    else
      cg_draw_rect_border(rect.x + 1, rect.y + 1,
        rect.width - 2, rect.height - 2, Color.new(120, 140, 160, 150))
    end

    if index % 2 == 0
      self.contents.fill_rect(rect.x + 2, rect.height - 13, 18, 11,
        Color.new(pair_color.red, pair_color.green, pair_color.blue, 190))
      old_size = self.contents.font.size
      old_color = self.contents.font.color
      self.contents.font.size = 9
      self.contents.font.color = Color.new(255, 255, 255)
      self.contents.draw_text(rect.x + 2, rect.height - 15, 18, 14,
        "P" + pair_number.to_s, 1)
      self.contents.font.size = old_size
      self.contents.font.color = old_color
    end

    if actor == nil
      cg_draw_empty_status_slot(rect, index)
      return
    end

    cg_draw_actor_name_line(actor, rect)
    cg_draw_small_character(actor, rect.x + 4, rect.y + 19, 31, 34)
    cg_draw_identity_badge(actor, rect.x + 3, rect.y + 18)
    cg_draw_type_badges(actor, rect.x + 4, rect.y + 53)
    cg_draw_status_gauge(actor, rect.x + 38, rect.y + 21,
      rect.width - 42, :hp)
    cg_draw_status_gauge(actor, rect.x + 38, rect.y + 39,
      rect.width - 42, :mp)
    state_width = rect.width - 42
    state_width -= 29 if selected
    cg_draw_state_icons(actor, rect.x + 38, rect.y + 58, state_width)
    cg_draw_active_badge(rect, pulse) if selected

    if actor.dead?
      self.contents.fill_rect(rect.x + 2, rect.y + 4,
        rect.width - 4, rect.height - 6, Color.new(0, 0, 0, 95))
      old_size = self.contents.font.size
      old_color = self.contents.font.color
      self.contents.font.size = 14
      self.contents.font.bold = true
      self.contents.font.color = Color.new(255, 120, 120)
      self.contents.draw_text(rect.x, rect.y + 29, rect.width, 22,
        "戰鬥不能", 1)
      self.contents.font.bold = false
      self.contents.font.size = old_size
      self.contents.font.color = old_color
    end
  end

  def cg_draw_empty_status_slot(rect, index)
    old_size = self.contents.font.size
    old_color = self.contents.font.color
    self.contents.font.size = 11
    self.contents.font.color = Color.new(128, 138, 148)
    label = index % 2 == 0 ? "人物空位" : "寵物空位"
    self.contents.draw_text(rect.x + 3, rect.y + 29,
      rect.width - 6, 20, label, 1)
    self.contents.font.size = old_size
    self.contents.font.color = old_color
  end

  def cg_draw_actor_name_line(actor, rect)
    old_size = self.contents.font.size
    old_color = self.contents.font.color
    old_bold = self.contents.font.bold
    name = actor.name.to_s
    size = 13
    self.contents.font.size = size
    self.contents.font.bold = actor == nil ? false : actor.hp > 0
    maximum_name_width = rect.width - 31
    while size > 9 && self.contents.text_size(name).width > maximum_name_width
      size -= 1
      self.contents.font.size = size
    end
    self.contents.font.color = hp_color(actor)
    self.contents.draw_text(rect.x + 4, rect.y + 3,
      maximum_name_width, 16, name, 0)
    self.contents.font.size = 9
    self.contents.font.bold = false
    self.contents.font.color = system_color
    self.contents.draw_text(rect.x + rect.width - 29, rect.y + 4,
      25, 14, "L" + actor.level.to_i.to_s, 2)
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  end

  def cg_draw_small_character(actor, x, y, max_width, max_height)
    return if actor == nil
    name = actor.respond_to?(:character_name) ? actor.character_name.to_s : ""
    index = actor.respond_to?(:character_index) ? actor.character_index.to_i : 0
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
      scale_x = max_width.to_f / cw
      scale_y = max_height.to_f / ch
      scale = [scale_x, scale_y, 1.0].min
      draw_width = [(cw * scale).to_i, 1].max
      draw_height = [(ch * scale).to_i, 1].max
      target_x = x + (max_width - draw_width) / 2
      target_y = y + max_height - draw_height
      target = Rect.new(target_x, target_y, draw_width, draw_height)
      opacity = actor.dead? ? 100 : 255
      if defined?(ALBERT_CG::TRGSSXVisual)
        ALBERT_CG::TRGSSXVisual.stretch_blt(
          self.contents, target, bitmap, source, opacity)
      else
        self.contents.stretch_blt(target, bitmap, source, opacity)
      end
    rescue
    end
  end

  def cg_draw_identity_badge(actor, x, y)
    text = ALBERT_CG.cg_ui_identity_text(actor)
    return if text == nil || text.empty?
    color = cg_identity_color(actor)
    self.contents.fill_rect(x, y, 13, 13, color)
    old_size = self.contents.font.size
    old_color = self.contents.font.color
    old_bold = self.contents.font.bold
    self.contents.font.size = 9
    self.contents.font.bold = true
    self.contents.font.color = Color.new(255, 255, 255)
    self.contents.draw_text(x, y - 1, 13, 14, text, 1)
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  end

  def cg_draw_type_badges(actor, x, y)
    keys = ALBERT_CG.cg_ui_type_keys(actor)
    return if keys == nil || keys.empty?
    keys = keys[0, 2]
    badge_width = keys.size > 1 ? 15 : 31
    for i in 0...keys.size
      key = keys[i]
      color = ALBERT_CG.cg_ui_type_color(key)
      bx = x + i * 16
      self.contents.fill_rect(bx, y, badge_width, 12,
        Color.new(color.red, color.green, color.blue, 225))
      old_size = self.contents.font.size
      old_color = self.contents.font.color
      old_bold = self.contents.font.bold
      self.contents.font.size = 9
      self.contents.font.bold = true
      brightness = color.red + color.green + color.blue
      self.contents.font.color = brightness > 470 ?
        Color.new(36, 36, 36) : Color.new(255, 255, 255)
      label = ALBERT_CG::TYPE_NAMES[key] || "?"
      self.contents.draw_text(bx, y - 1, badge_width, 13, label, 1)
      self.contents.font.size = old_size
      self.contents.font.bold = old_bold
      self.contents.font.color = old_color
    end
  end

  def cg_draw_status_gauge(actor, x, y, width, kind)
    width = 12 if width < 12
    if kind == :hp
      value = actor.hp.to_i
      maximum = actor.maxhp.to_i
      label = "H"
      color1 = hp_gauge_color1
      color2 = hp_gauge_color2
      text_color = hp_color(actor)
    else
      value = actor.mp.to_i
      maximum = actor.maxmp.to_i
      label = "M"
      color1 = mp_gauge_color1
      color2 = mp_gauge_color2
      text_color = mp_color(actor)
    end
    rate = maximum <= 0 ? 0 : value * 100 / maximum
    rate = 0 if rate < 0
    rate = 100 if rate > 100
    self.contents.fill_rect(x, y + 9, width, 5, gauge_back_color)
    fill_width = width * rate / 100
    self.contents.gradient_fill_rect(x, y + 9, fill_width, 5,
      color1, color2) if fill_width > 0

    old_size = self.contents.font.size
    old_color = self.contents.font.color
    self.contents.font.size = 9
    self.contents.font.color = system_color
    self.contents.draw_text(x, y - 2, 10, 12, label, 0)
    self.contents.font.color = text_color
    text = value.to_s + "/" + maximum.to_s
    self.contents.draw_text(x + 8, y - 2, width - 8, 12, text, 2)
    self.contents.font.size = old_size
    self.contents.font.color = old_color
  end

  def cg_draw_state_icons(actor, x, y, width)
    states = []
    begin
      for state in actor.states
        states.push(state) if state != nil && state.icon_index.to_i > 0
      end
    rescue
    end
    maximum = [ALBERT_CG::BATTLE_STATUS_MAX_STATES, width / 15].min
    maximum = 1 if maximum < 1
    display_count = [states.size, maximum].min
    iconset = Cache.system("IconSet")
    for i in 0...display_count
      if i == maximum - 1 && states.size > maximum
        old_size = self.contents.font.size
        old_color = self.contents.font.color
        self.contents.font.size = 9
        self.contents.font.color = Color.new(255, 255, 255)
        self.contents.draw_text(x + i * 15, y, 15, 14,
          "+" + (states.size - maximum + 1).to_s, 1)
        self.contents.font.size = old_size
        self.contents.font.color = old_color
        break
      end
      icon = states[i].icon_index.to_i
      source = Rect.new(icon % 16 * 24, icon / 16 * 24, 24, 24)
      target = Rect.new(x + i * 15, y, 14, 14)
      self.contents.stretch_blt(target, iconset, source)
    end
  rescue
  end

  def cg_draw_rect_border(x, y, width, height, color)
    return if width <= 0 || height <= 0
    self.contents.fill_rect(x, y, width, 1, color)
    self.contents.fill_rect(x, y + height - 1, width, 1, color)
    self.contents.fill_rect(x, y, 1, height, color)
    self.contents.fill_rect(x + width - 1, y, 1, height, color)
  end

  def cg_draw_thick_rect_border(x, y, width, height, color, thickness)
    thickness = [thickness.to_i, 1].max
    for i in 0...thickness
      cg_draw_rect_border(x + i, y + i, width - i * 2,
        height - i * 2, color)
    end
  end

  def cg_draw_active_badge(rect, pulse)
    width = 27
    height = 13
    x = rect.x + rect.width - width - 3
    y = rect.y + rect.height - height - 2
    edge = pulse == 0 ? Color.new(255, 216, 70, 255) :
      Color.new(255, 248, 170, 255)
    self.contents.fill_rect(x + 1, y + 1, width, height,
      Color.new(0, 0, 0, 170))
    self.contents.fill_rect(x, y, width, height, edge)
    self.contents.fill_rect(x + 1, y + 1, width - 2, height - 2,
      Color.new(82, 48, 4, 240))
    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 9
    self.contents.font.bold = true
    self.contents.font.color = Color.new(255, 255, 225)
    self.contents.draw_text(x, y - 1, width, height + 1, "行動", 1)
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  end
end


#==============================================================================
# ■ Sprite_CG_BattlerHUD
#------------------------------------------------------------------------------
#  v1.8.1a：行動順序改放在 Battle Status 右上方後，HUD 的可用區域必須改為：
#  畫面頂端 ～ BATTLE_STATUS_TOP。
#  舊版以 ORDER_WINDOW_Y 當作下邊界，當 Y=0 時會把敵方 HUD 全夾到頂端。
#==============================================================================
class Sprite_CG_BattlerHUD
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
      @bar_sprite.y = center_y.to_i - @bar_sprite.bitmap.height / 2
    else
      panel_width = ALBERT_CG::BATTLE_HUD_ENEMY_BAR_WIDTH
      panel_x = left.to_i - panel_width - ALBERT_CG::BATTLE_HUD_BAR_GAP
      panel_x = 2 if panel_x < 2
      @bar_sprite.x = panel_x - (@bar_sprite.bitmap.width - panel_width)
      @bar_sprite.y = center_y.to_i - @bar_sprite.bitmap.height / 2
    end

    @label_sprite.x = center_x.to_i - @label_sprite.bitmap.width / 2
    @label_sprite.y = bottom.to_i + ALBERT_CG::BATTLE_HUD_NAME_GAP

    minimum_bar_y = 2
    maximum_bar_y = ALBERT_CG::BATTLE_STATUS_Y -
      @bar_sprite.bitmap.height - 2
    @bar_sprite.y = minimum_bar_y if @bar_sprite.y < minimum_bar_y
    @bar_sprite.y = maximum_bar_y if @bar_sprite.y > maximum_bar_y

    @label_sprite.x = 0 if @label_sprite.x < 0
    if @label_sprite.x + @label_sprite.bitmap.width > Graphics.width
      @label_sprite.x = Graphics.width - @label_sprite.bitmap.width
    end
    minimum_label_y = 2
    maximum_label_y = ALBERT_CG::BATTLE_STATUS_Y -
      @label_sprite.bitmap.height - 2
    @label_sprite.y = minimum_label_y if @label_sprite.y < minimum_label_y
    @label_sprite.y = maximum_label_y if @label_sprite.y > maximum_label_y
  end
end

#==============================================================================
# ■ Window_ActorCommand
#------------------------------------------------------------------------------
#  v1.8.1a Spin Command：保留原本 @commands、@cg_command_types、index 與
#  cg_command_enabled? 介面，因此既有 CG 捕捉／移動／換寵補丁不需改寫。
#==============================================================================
class Window_ActorCommand < Window_Command
  alias albert_cg_v181a_spin_initialize initialize
  def initialize
    albert_cg_v181a_spin_initialize
    @cg_spin_actor = nil
    @cg_spin_offset = 0.0
    self.width = ALBERT_CG::SPIN_WINDOW_WIDTH
    self.height = ALBERT_CG::SPIN_WINDOW_HEIGHT
    self.opacity = 0
    self.back_opacity = 0
    self.z = ALBERT_CG::SPIN_Z
    @column_max = 1
    create_contents
    self.cursor_rect.empty
  end

  alias albert_cg_v181a_spin_setup setup
  def setup(actor)
    albert_cg_v181a_spin_setup(actor)
    @cg_spin_actor = actor
    @column_max = [@item_max.to_i, 1].max
    self.width = ALBERT_CG::SPIN_WINDOW_WIDTH
    self.height = ALBERT_CG::SPIN_WINDOW_HEIGHT
    self.oy = 0
    create_contents
    @cg_spin_offset = 0.0
    refresh
    self.index = 0
  end

  alias albert_cg_v181a_spin_index_set index=
  def index=(value)
    old_index = @index
    albert_cg_v181a_spin_index_set(value)
    refresh if old_index != @index && self.contents != nil
  end

  def cursor_down(wrap = false)
    cg_spin_move(1)
  end

  def cursor_right(wrap = false)
    cg_spin_move(1)
  end

  def cursor_up(wrap = false)
    cg_spin_move(-1)
  end

  def cursor_left(wrap = false)
    cg_spin_move(-1)
  end

  def cursor_pagedown
  end

  def cursor_pageup
  end

  def cg_spin_move(delta)
    return if @item_max == nil || @item_max <= 1
    old_index = @index.to_i
    @index = (@index.to_i + delta.to_i + @item_max) % @item_max
    return if @index == old_index
    step = 360.0 / @item_max
    @cg_spin_offset = delta.to_i > 0 ? step : -step
    refresh
  end

  def update
    super
    if @cg_spin_offset != nil && @cg_spin_offset.abs > 0.35
      @cg_spin_offset *= 0.64
      refresh
    elsif @cg_spin_offset != nil && @cg_spin_offset != 0.0
      @cg_spin_offset = 0.0
      refresh
    end
  end

  def update_cursor
    self.cursor_rect.empty
  end

  def refresh
    return if self.contents == nil || self.contents.disposed?
    self.contents.clear
    return if @commands == nil || @commands.empty?

    cx = ALBERT_CG::SPIN_CENTER_X
    cy = ALBERT_CG::SPIN_CENTER_Y
    radius = ALBERT_CG::SPIN_RADIUS
    count = @commands.size
    step = 360.0 / count
    offset = @cg_spin_offset == nil ? 0.0 : @cg_spin_offset

    cg_draw_spin_ring(cx, cy, radius)
    for i in 0...count
      relative = i - @index.to_i
      angle = -90.0 + relative * step + offset
      radian = angle * Math::PI / 180.0
      node_size = i == @index ? ALBERT_CG::SPIN_NODE_SIZE + 4 :
        ALBERT_CG::SPIN_NODE_SIZE
      node_x = cx + Math.cos(radian) * radius - node_size / 2
      node_y = cy + Math.sin(radian) * radius - node_size / 2
      cg_draw_spin_node(i, node_x.to_i, node_y.to_i, node_size)
    end
    cg_draw_spin_center(cx, cy)
  end

  def cg_spin_command_type(index)
    return nil if @cg_command_types == nil
    return @cg_command_types[index]
  end

  def cg_spin_command_label(type, command)
    case type
    when :attack then return "攻"
    when :skill then return "技"
    when :guard then return "防"
    when :item then return "物"
    when :capture then return "捕"
    when :move then return "移"
    when :switch_pet then return "寵"
    when :wait then return "待"
    end
    text = command.to_s
    return text.empty? ? "?" : text[0, 1]
  end

  def cg_spin_command_color(type, enabled)
    return Color.new(92, 92, 100, 230) unless enabled
    case type
    when :attack then return Color.new(196, 86, 70, 235)
    when :skill then return Color.new(82, 128, 214, 235)
    when :guard then return Color.new(93, 160, 111, 235)
    when :item then return Color.new(185, 142, 72, 235)
    when :capture then return Color.new(176, 93, 193, 235)
    when :move then return Color.new(67, 164, 169, 235)
    when :switch_pet then return Color.new(199, 113, 157, 235)
    when :wait then return Color.new(112, 120, 135, 235)
    end
    return Color.new(100, 120, 150, 235)
  end

  def cg_draw_spin_ring(cx, cy, radius)
    color = Color.new(180, 205, 230, 105)
    if defined?(ALBERT_CG::TRGSSXVisual) &&
       ALBERT_CG::TRGSSXVisual.draw_regular_polygon(
         self.contents, cx, cy, radius, 12, color, 1)
      return
    end
    for degree in 0...360
      next unless degree % 8 == 0
      radian = degree * Math::PI / 180.0
      x = cx + Math.cos(radian) * radius
      y = cy + Math.sin(radian) * radius
      self.contents.fill_rect(x.to_i, y.to_i, 2, 2, color)
    end
  end

  def cg_draw_spin_node(index, x, y, size)
    type = cg_spin_command_type(index)
    enabled = respond_to?(:cg_command_enabled?) ?
      cg_command_enabled?(index) : true
    color = cg_spin_command_color(type, enabled)
    selected = index == @index
    border = selected ? Color.new(255, 230, 112, 255) :
      Color.new(225, 235, 245, 205)
    shadow = Color.new(0, 0, 0, 150)
    center_x = x + size / 2
    center_y = y + size / 2
    radius = size / 2

    polygon_drawn = false
    if defined?(ALBERT_CG::TRGSSXVisual)
      ALBERT_CG::TRGSSXVisual.fill_regular_polygon(
        self.contents, center_x + 2, center_y + 2, radius, 6,
        shadow, shadow)
      polygon_drawn = ALBERT_CG::TRGSSXVisual.fill_regular_polygon(
        self.contents, center_x, center_y, radius, 6,
        Color.new([color.red + 32, 255].min,
          [color.green + 32, 255].min,
          [color.blue + 32, 255].min, color.alpha),
        color)
      if polygon_drawn
        ALBERT_CG::TRGSSXVisual.draw_regular_polygon(
          self.contents, center_x, center_y, radius, 6, border,
          selected ? 3 : 1)
      end
    end

    unless polygon_drawn
      self.contents.fill_rect(x + 2, y + 2, size, size, shadow)
      self.contents.fill_rect(x, y, size, size, border)
      self.contents.fill_rect(x + 1, y + 1, size - 2, size - 2,
        Color.new(color.red, color.green, color.blue, color.alpha))
      if selected
        self.contents.fill_rect(x + 3, y + 3, size - 6, 2,
          Color.new(255, 250, 190, 220))
      end
    end

    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = selected ? 14 : 13
    self.contents.font.bold = true
    self.contents.font.color = enabled ? Color.new(255, 255, 255) :
      Color.new(190, 190, 195)
    label = cg_spin_command_label(type, @commands[index])
    self.contents.draw_text(x, y - 1, size, size + 2, label, 1)
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  end

  def cg_draw_spin_center(cx, cy)
    width = 82
    height = 20
    x = cx - width / 2
    y = cy + ALBERT_CG::SPIN_LABEL_OFFSET_Y
    enabled = respond_to?(:cg_command_enabled?) ?
      cg_command_enabled?(@index) : true

    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 12
    self.contents.font.bold = true
    command = @commands[@index] == nil ? "" : @commands[@index].to_s

    # 不再使用遮住角色的中央文字盒，只畫外陰影與文字。
    self.contents.font.color = Color.new(0, 0, 0, 230)
    self.contents.draw_text(x - 1, y, width, height, command, 1)
    self.contents.draw_text(x + 1, y, width, height, command, 1)
    self.contents.draw_text(x, y - 1, width, height, command, 1)
    self.contents.draw_text(x, y + 1, width, height, command, 1)
    self.contents.font.color = enabled ? Color.new(255, 255, 255) :
      Color.new(170, 170, 175)
    self.contents.draw_text(x, y, width, height, command, 1)

    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  end
end

#==============================================================================
# ■ Window_CG_ActionOrder
#------------------------------------------------------------------------------
#  v1.8.1a Beautiful Card Mode：
#  - 緊貼 Battle Status 右上方並向右對齊。
#  - 我方藍卡、敵方紅卡、目前行動者金色外框。
#  - 卡片內只放行走圖，不顯示名稱、行動名稱或速度。
#  - Help Window 與 Battle Message 不再控制本列的顯示狀態。
#==============================================================================
class Window_CG_ActionOrder < Window_Base
  alias albert_cg_v181a_order_initialize initialize
  def initialize
    albert_cg_v181a_order_initialize
    self.opacity = 0
    self.back_opacity = 0
    self.contents_opacity = 255
  end

  def refresh
    self.contents.clear
    entries = cg_display_entries
    if entries.empty?
      self.visible = false
      return
    end
    maximum = [entries.size, ALBERT_CG::ORDER_CARD_COUNT].min
    total_width = maximum * ALBERT_CG::ORDER_CARD_WIDTH
    @cg_card_start_x = self.contents.width - total_width
    @cg_card_start_x = 0 if @cg_card_start_x < 0
    for index in 0...maximum
      battler, action, current = entries[index]
      draw_order_card(index, battler, action, current)
    end
    self.visible = true
  end

  def draw_order_card(index, battler, action, current)
    x = @cg_card_start_x + index * ALBERT_CG::ORDER_CARD_WIDTH
    y = current ? 0 : 2
    width = ALBERT_CG::ORDER_CARD_WIDTH - 3
    height = self.contents.height - y
    height = 30 if height > 30
    height = 24 if height < 24

    if battler.actor?
      top_color = Color.new(74, 145, 224, 235)
      bottom_color = Color.new(28, 70, 132, 235)
    else
      top_color = Color.new(224, 100, 92, 235)
      bottom_color = Color.new(132, 38, 42, 235)
    end

    shadow = Color.new(0, 0, 0, 145)
    border = current ? Color.new(255, 224, 92, 255) :
      Color.new(225, 235, 245, 190)

    self.contents.fill_rect(x + 2, y + 2, width, height, shadow)
    self.contents.fill_rect(x, y, width, height, border)
    self.contents.gradient_fill_rect(x + 1, y + 1,
      width - 2, height - 2, top_color, bottom_color, true)

    if current
      self.contents.fill_rect(x + 2, y + 2, width - 4, 2,
        Color.new(255, 248, 180, 220))
    end

    draw_order_character_card(battler, x + 2, y + 1,
      width - 4, height - 2)
  end

  def draw_order_character_card(battler, x, y, width, height)
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
      max_width = width - 2
      max_height = height - 2
      scale_x = max_width.to_f / cw
      scale_y = max_height.to_f / ch
      scale = [scale_x, scale_y, 1.0].min
      draw_width = [(cw * scale).to_i, 1].max
      draw_height = [(ch * scale).to_i, 1].max
      target_x = x + (width - draw_width) / 2
      target_y = y + height - draw_height
      target = Rect.new(target_x, target_y, draw_width, draw_height)
      if defined?(ALBERT_CG::TRGSSXVisual)
        ALBERT_CG::TRGSSXVisual.stretch_blt(
          self.contents, target, bitmap, source, 255)
      else
        self.contents.stretch_blt(target, bitmap, source)
      end
    rescue
    end
  end
end

#==============================================================================
# ■ Scene_Battle
#==============================================================================
class Scene_Battle < Scene_Base
  # Enemy HUD only. This also disposes any actor HUDs already created by v1.7.4.
  def cg_v17_all_hud_battlers
    result = []
    if $game_troop != nil
      for enemy in $game_troop.members
        result.push(enemy) if enemy != nil
      end
    end
    return result
  end

  def cg_v17_hud_visible_for?(battler)
    return false if battler == nil || battler.actor?
    return battler.respond_to?(:exist?) ? battler.exist? : true
  end

  # Keep the internal VX info viewport hidden, but detach the formal status
  # window so it can remain visible at the bottom of the screen.
  def cg_v17_configure_battle_windows
    if @info_viewport != nil
      @info_viewport.visible = false
    end
    if @status_window != nil
      @status_window.viewport = nil
      @status_window.x = 0
      @status_window.y = ALBERT_CG::BATTLE_STATUS_Y
      @status_window.z = 430
      @status_window.visible = !cg_v180a_message_visible?
      @status_window.active = false unless @target_actor_window == @status_window
    end
    if @actor_command_window != nil
      @actor_command_window.viewport = nil
      @actor_command_window.z = ALBERT_CG::SPIN_Z
      @actor_command_window.visible = false
    end
    if @party_command_window != nil
      @party_command_window.viewport = nil
      @party_command_window.z = 500
      @party_command_window.x = Graphics.width - @party_command_window.width - 4
      @party_command_window.y = 4
      @party_command_window.visible = false
    end
    @cg_phase_window.visible = false if @cg_phase_window != nil
    if @cg_action_order_window != nil
      @cg_action_order_window.viewport = nil
      @cg_action_order_window.x = ALBERT_CG::ORDER_WINDOW_X
      @cg_action_order_window.y = ALBERT_CG::ORDER_WINDOW_Y
      @cg_action_order_window.width = ALBERT_CG::ORDER_WINDOW_WIDTH
      @cg_action_order_window.height = ALBERT_CG::ORDER_WINDOW_HEIGHT
      @cg_action_order_window.z = 420
      @cg_action_order_window.opacity = 0
      @cg_action_order_window.back_opacity = 0
      @cg_action_order_window.contents_opacity = 255
      if @cg_action_order_window.contents == nil ||
         @cg_action_order_window.contents.disposed? ||
         @cg_action_order_window.contents.width !=
           @cg_action_order_window.width - 32 ||
         @cg_action_order_window.contents.height !=
           @cg_action_order_window.height - 32
        @cg_action_order_window.create_contents
      end
    end
  end

  def cg_v17_place_actor_command
    return if @actor_command_window == nil || @active_battler == nil
    anchor = cg_v17_battler_anchor(@active_battler)
    return if anchor == nil

    # Spin Command 的圓心與 battler 中心完全重合。
    # Window 本身有 16px 內距，所以必須以 contents 圓心反推座標。
    x = anchor[4].to_i - 16 - ALBERT_CG::SPIN_CENTER_X
    y = anchor[5].to_i - 16 - ALBERT_CG::SPIN_CENTER_Y

    minimum_x = -8
    maximum_x = Graphics.width - @actor_command_window.width + 8
    x = minimum_x if x < minimum_x
    x = maximum_x if x > maximum_x

    minimum_y = -8
    maximum_y = ALBERT_CG::BATTLE_STATUS_Y -
      @actor_command_window.height + 12
    y = minimum_y if y < minimum_y
    y = maximum_y if y > maximum_y

    @actor_command_window.x = x
    @actor_command_window.y = y
  end

  def cg_v180a_message_visible?
    return true if $game_message != nil && $game_message.visible
    if @message_window != nil && @message_window.visible
      if $game_message != nil && $game_message.respond_to?(:texts)
        return true unless $game_message.texts.empty?
      end
    end
    return false
  rescue
    return false
  end

  def cg_v180a_help_visible?
    return false if @help_window == nil
    return @help_window.visible ? true : false
  rescue
    return false
  end

  def cg_v17_update_window_visibility
    @info_viewport.visible = false if @info_viewport != nil
    message_visible = cg_v180a_message_visible?

    if @status_window != nil
      @status_window.visible = !message_visible
      @status_window.z = 430
    end
    @cg_phase_window.visible = false if @cg_phase_window != nil

    if @cg_action_order_window != nil
      # v1.8.1a：行動卡片位於 Battle Status 右上方，不再與 Help Window
      # 爭奪空間。其 visible 只由 set_order／refresh 的佇列內容決定。
      @cg_action_order_window.z = 440
    end

    if @actor_command_window != nil
      visible = @actor_command_window.active && !message_visible
      visible = false if @skill_window != nil || @item_window != nil
      @actor_command_window.visible = visible
      cg_v17_place_actor_command if visible
    end
    if @party_command_window != nil
      visible = @party_command_window.active && !message_visible
      @party_command_window.visible = visible
    end
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  alias albert_cg_v181a_ui_load_database load_database
  def load_database
    albert_cg_v181a_ui_load_database
    ALBERT_CG.apply_v180_title
  end

  alias albert_cg_v181a_ui_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v181a_ui_load_bt_database
    ALBERT_CG.apply_v180_title
  end
end
