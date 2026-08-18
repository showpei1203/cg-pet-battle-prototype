# RMVX_SCRIPT_INDEX: 142
# RMVX_SCRIPT_ID: 98941060
# RMVX_SCRIPT_NAME: CG Action Order Preview v1.0
# RMVX_SOURCE_SHA256: 7e95b931c39fd48f3b6cd4baf11fc13527c2240a5af616cd5eeb1faf1a8158a1

#==============================================================================
# 【繁體中文說明】ALBERT CG 行動順序預覽與速度修正核心
#------------------------------------------------------------------------------
# 【版本】v1.0
# 【引擎】RPG Maker VX / RGSS2 / Ruby 1.8
# 【需求】Tankentai SBS 3.3、CG Dual Command Core v0.4.2 以上
#------------------------------------------------------------------------------
# 【用途】
#  1. 在所有人物、寵物與敵人完成指令後，顯示本回合實際行動順序。
#  2. 行動執行時持續更新目前行動者與後續佇列。
#  3. 支援同一人物一回合兩動、人物／寵物雙指令、敵人多次行動。
#  4. 提供簡單 Note 速度修正，不接管 Tankentai 的回合流程。
#------------------------------------------------------------------------------
# 【顯示內容】
#  每張卡片會顯示：
#    角色行走圖、名稱、行動名稱、最終行動速度。
#  最左邊卡片為目前正在執行的行動；其後依序為等待中的行動。
#------------------------------------------------------------------------------
# 【Note 使用方式】
#  技能／物品 Note：
#    <cg_order_speed: 50>
#  代表該行動額外增加 50 點速度；可以使用負數。
#
#  Actor／Enemy／武器／防具 Note：
#    <cg_order_rate: 120>
#  代表該戰鬥者的最終行動速度乘以 120%。
#  多個來源採加總差額，例如 120% 與 90% 合計為 110%。
#------------------------------------------------------------------------------
# 【重要規則】
#  - 本腳本只顯示 CG Dual Command Core 已排好的真實佇列，不另建回合制。
#  - 同一人物第二動不得超越第一動的規則仍由 Dual Command Core 管理。
#  - 換寵後新寵物本回合沒有行動，因此不會憑空插入順序卡。
#  - 被收回或離隊的角色，其尚未執行卡片會在刷新時自動略過。
#------------------------------------------------------------------------------
# 【腳本位置】
#  請放在全部 ALBERT CG 戰鬥補丁下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_ActionOrderPreview"] = true

module ALBERT_CG
  ORDER_WINDOW_X = 0
  ORDER_WINDOW_Y = 0
  ORDER_WINDOW_WIDTH = 544
  ORDER_WINDOW_HEIGHT = 80
  ORDER_CARD_WIDTH = 84
  ORDER_CARD_COUNT = 6
  ORDER_SHOW_SPEED = true
  ORDER_SPEED_RATE_MIN = 10
  ORDER_SPEED_RATE_MAX = 300

  def self.cg_order_clamp(value, minimum, maximum)
    value = value.to_i
    value = minimum if value < minimum
    value = maximum if value > maximum
    return value
  end

  def self.cg_order_note_value(note, key)
    return nil if note == nil
    pattern = /<#{key}\s*:\s*([+-]?\d+)\s*>/i
    return $1.to_i if note.to_s =~ pattern
    return nil
  end
end

#==============================================================================
# ■ RPG::BaseItem
#==============================================================================
class RPG::BaseItem
  def cg_order_speed_bonus
    value = ALBERT_CG.cg_order_note_value(@note, "cg_order_speed")
    return value == nil ? 0 : value.to_i
  end

  def cg_order_speed_rate
    value = ALBERT_CG.cg_order_note_value(@note, "cg_order_rate")
    return value
  end
end

#==============================================================================
# ■ Game_Battler
#==============================================================================
class Game_Battler
  def cg_order_note_sources
    result = []
    if actor?
      begin
        data = self.actor
        result.push(data) if data != nil
      rescue
      end
      begin
        if respond_to?(:equips)
          for equip in equips
            result.push(equip) if equip != nil
          end
        end
      rescue
      end
    else
      begin
        data = self.enemy
        result.push(data) if data != nil
      rescue
      end
    end
    return result
  end

  def cg_order_speed_rate
    rate = 100
    for source in cg_order_note_sources
      next unless source.respond_to?(:cg_order_speed_rate)
      value = source.cg_order_speed_rate
      rate += value.to_i - 100 if value != nil
    end
    return ALBERT_CG.cg_order_clamp(rate,
      ALBERT_CG::ORDER_SPEED_RATE_MIN,
      ALBERT_CG::ORDER_SPEED_RATE_MAX)
  end
end

#==============================================================================
# ■ Game_BattleAction
#==============================================================================
class Game_BattleAction
  def cg_order_object
    return skill if skill?
    return item if item?
    return nil
  end

  def cg_order_speed_bonus
    object = cg_order_object
    return 0 if object == nil
    return object.respond_to?(:cg_order_speed_bonus) ?
      object.cg_order_speed_bonus.to_i : 0
  end

  alias albert_cg_v10_order_make_speed make_speed
  def make_speed
    albert_cg_v10_order_make_speed
    @speed += cg_order_speed_bonus
    rate = @battler.respond_to?(:cg_order_speed_rate) ?
      @battler.cg_order_speed_rate : 100
    @speed = @speed * rate.to_i / 100
  end

  def cg_order_action_name
    if attack?
      return "攻擊"
    elsif guard?
      return "防禦"
    elsif skill?
      object = skill
      return object == nil ? "技能" : object.name.to_s
    elsif item?
      object = item
      return object == nil ? "物品" : object.name.to_s
    end

    if @kind == 0
      if defined?(ALBERT_CG::CG_BASIC_MOVE_SLOT) &&
         @basic == ALBERT_CG::CG_BASIC_MOVE_SLOT
        return "移動"
      elsif defined?(ALBERT_CG::CG_BASIC_SWAP_PET) &&
            @basic == ALBERT_CG::CG_BASIC_SWAP_PET
        return "交換位置"
      elsif defined?(ALBERT_CG::CG_BASIC_SWITCH_PET) &&
            @basic == ALBERT_CG::CG_BASIC_SWITCH_PET
        return "換寵"
      elsif defined?(ALBERT_CG::CG_BASIC_RECALL_PET) &&
            @basic == ALBERT_CG::CG_BASIC_RECALL_PET
        return "收回寵物"
      elsif defined?(ALBERT_CG::CG_BASIC_CAPTURE) &&
            @basic == ALBERT_CG::CG_BASIC_CAPTURE
        return "捕捉"
      elsif @basic == 2
        return "逃跑"
      elsif @basic == 3
        return "待命"
      end
    end
    return "待機"
  end
end

#==============================================================================
# ■ Window_CG_ActionOrder
#==============================================================================
class Window_CG_ActionOrder < Window_Base
  def initialize
    super(ALBERT_CG::ORDER_WINDOW_X,
          ALBERT_CG::ORDER_WINDOW_Y,
          ALBERT_CG::ORDER_WINDOW_WIDTH,
          ALBERT_CG::ORDER_WINDOW_HEIGHT)
    self.z = 360
    self.back_opacity = 180
    self.visible = false
    @current_battler = nil
    @current_action = nil
    @queue = []
  end

  def clear_order
    @current_battler = nil
    @current_action = nil
    @queue = []
    self.contents.clear
    self.visible = false
  end

  def set_order(current_battler, current_action, queue)
    @current_battler = current_battler
    @current_action = current_action
    @queue = queue == nil ? [] : queue.dup
    refresh
  end

  def cg_entry_battler(entry)
    return entry.battler if entry.is_a?(ALBERT_CG::ActionEntry)
    return entry
  end

  def cg_entry_action(entry)
    return entry.action if entry.is_a?(ALBERT_CG::ActionEntry)
    battler = cg_entry_battler(entry)
    return battler == nil ? nil : battler.action
  end

  def cg_valid_entry?(entry)
    battler = cg_entry_battler(entry)
    return false if battler == nil
    return false if battler.respond_to?(:index) && battler.index == nil
    return true
  end

  def cg_display_entries
    result = []
    if @current_battler != nil
      result.push([@current_battler, @current_action, true])
    end
    for entry in @queue
      next unless cg_valid_entry?(entry)
      result.push([cg_entry_battler(entry), cg_entry_action(entry), false])
    end
    return result
  end

  def refresh
    self.contents.clear
    entries = cg_display_entries
    if entries.empty?
      self.visible = false
      return
    end
    self.visible = true
    maximum = [entries.size, ALBERT_CG::ORDER_CARD_COUNT].min
    for index in 0...maximum
      battler, action, current = entries[index]
      draw_order_card(index, battler, action, current)
    end
    if entries.size > maximum
      old_size = self.contents.font.size
      self.contents.font.size = 14
      text = "+" + (entries.size - maximum).to_s
      self.contents.draw_text(self.contents.width - 32, 30, 30, 18, text, 2)
      self.contents.font.size = old_size
    end
  end

  def draw_order_card(index, battler, action, current)
    x = index * ALBERT_CG::ORDER_CARD_WIDTH
    width = ALBERT_CG::ORDER_CARD_WIDTH - 2
    height = self.contents.height
    border = current ? power_up_color : system_color
    background = current ? Color.new(255, 255, 255, 38) : Color.new(0, 0, 0, 48)
    self.contents.fill_rect(x, 0, width, height, border)
    self.contents.fill_rect(x + 1, 1, width - 2, height - 2, background)

    old_size = self.contents.font.size
    old_color = self.contents.font.color
    self.contents.font.size = 16
    self.contents.font.color = current ? power_up_color : normal_color
    self.contents.draw_text(x + 3, 0, width - 6, 18, battler.name.to_s, 0)

    draw_order_character(battler, x + 13, 42)

    label = action == nil ? "待機" : action.cg_order_action_name
    self.contents.font.size = 14
    self.contents.font.color = battler.actor? ? system_color : crisis_color
    self.contents.draw_text(x + 30, 19, width - 32, 17, label.to_s, 0)

    if ALBERT_CG::ORDER_SHOW_SPEED
      speed = action == nil ? 0 : action.speed.to_i
      self.contents.font.size = 12
      self.contents.font.color = normal_color
      self.contents.draw_text(x + 30, 35, width - 32, 15,
        "速 " + speed.to_s, 0)
    end
    self.contents.font.size = old_size
    self.contents.font.color = old_color
  end

  def cg_character_data(battler)
    if battler.actor?
      name = battler.respond_to?(:character_name) ? battler.character_name : ""
      index = battler.respond_to?(:character_index) ? battler.character_index : 0
      return [name.to_s, index.to_i]
    end
    name = battler.respond_to?(:battler_name) ? battler.battler_name : ""
    return [name.to_s, 0]
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
      destination = Rect.new(x - 11, y - 23, 22, 24)
      self.contents.stretch_blt(destination, bitmap, source)
    rescue
      # 圖檔不存在時只略過行走圖，不中斷戰鬥。
    end
  end
end

#==============================================================================
# ■ Scene_Battle
#==============================================================================
class Scene_Battle < Scene_Base
  alias albert_cg_v10_order_start start
  def start
    albert_cg_v10_order_start
    @cg_action_order_window = Window_CG_ActionOrder.new
  end

  alias albert_cg_v10_order_terminate terminate
  def terminate
    if @cg_action_order_window != nil
      unless @cg_action_order_window.disposed?
        @cg_action_order_window.dispose
      end
      @cg_action_order_window = nil
    end
    albert_cg_v10_order_terminate
  end

  alias albert_cg_v10_order_party_command start_party_command_selection
  def start_party_command_selection
    @cg_action_order_window.clear_order if @cg_action_order_window != nil
    albert_cg_v10_order_party_command
  end

  alias albert_cg_v10_order_make_action_orders make_action_orders
  def make_action_orders
    albert_cg_v10_order_make_action_orders
    if @cg_action_order_window != nil
      @cg_action_order_window.set_order(nil, nil, @action_battlers)
    end
  end

  alias albert_cg_v10_order_set_next_active_battler set_next_active_battler
  def set_next_active_battler
    albert_cg_v10_order_set_next_active_battler
    if @cg_action_order_window != nil
      action = @active_battler == nil ? nil : @active_battler.action
      @cg_action_order_window.set_order(@active_battler, action,
        @action_battlers)
    end
  end

  alias albert_cg_v10_order_turn_end turn_end
  def turn_end
    @cg_action_order_window.clear_order if @cg_action_order_window != nil
    albert_cg_v10_order_turn_end
  end
end
