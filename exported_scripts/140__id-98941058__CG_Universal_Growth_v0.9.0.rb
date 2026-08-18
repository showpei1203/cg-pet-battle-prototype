# RMVX_SCRIPT_INDEX: 140
# RMVX_SCRIPT_ID: 98941058
# RMVX_SCRIPT_NAME: CG Universal Growth v0.9.0
# RMVX_SOURCE_SHA256: bacb25635b46997b94a577642ef29b29546321534c0a2e378be1106e9fea1b18

#==============================================================================
# 【繁體中文說明】ALBERT CG 全角色能力配點
#------------------------------------------------------------------------------
# 【版本】v0.9.0
# 【用途】
#  1. 讓主角、一般隊友與隊友固定寵物都能獲得並分配 BP。
#  2. Clone 寵物仍沿用 CG Pet Growth 的個體 BP，不重複建立資料。
#  3. 提供 F4「隊伍育成」介面，可選擇能力配點或技能管理。
#
# 【配點效果】
#  體力：最大 HP +5　力量：攻擊力 +1　強度：防禦力 +1
#  速度：敏捷度 +1　魔法：最大 MP +3、精神力 +1
#
# 【BP 規則】
#  - 主角、隊友、固定寵物每升 1 級獲得 1 點 BP。
#  - Lv.5 的普通 Actor 初始可用 BP 為 4。
#  - Clone 寵物仍使用既有 cg_unspent_bp／cg_bonus_points。
#
# 【操作】
#  地圖按 F4 → 選擇角色 → 能力配點
#  上／下選能力，右或 C 分配，左退回本次分配，B 返回。
#
# 【事件指令】
#  cg_open_party_development                 # 開啟隊伍育成
#  cg_open_actor_growth(actor_id)            # 開啟指定普通 Actor 配點
#  cg_give_actor_bp(actor_id, amount)        # 額外給予普通 Actor BP
#
# 【注意】
#  - 固定寵物雖是普通 Actor，仍有自己獨立的配點資料。
#  - 本腳本放在 CG Pet Growth 下方、技能管理腳本上方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_UniversalGrowth"] = true

module ALBERT_CG
  UNIVERSAL_GROWTH_VERSION = "0.9.0"
  ACTOR_BP_PER_LEVEL = 1 unless const_defined?(:ACTOR_BP_PER_LEVEL)
  ACTOR_BP_STAT_NAMES = ["體力", "力量", "強度", "速度", "魔法"] unless const_defined?(:ACTOR_BP_STAT_NAMES)
  ACTOR_BP_STAT_EFFECTS = [
    "每點最大 HP +5", "每點攻擊力 +1", "每點防禦力 +1",
    "每點敏捷度 +1", "每點最大 MP +3、精神力 +1"
  ] unless const_defined?(:ACTOR_BP_STAT_EFFECTS)
end

class Game_Actor < Game_Battler
  def cg_clone_pet_growth?
    return respond_to?(:cg_pet?) && cg_pet?
  end

  def cg_prepare_actor_growth_data
    return false if cg_clone_pet_growth?
    @cg_actor_bonus_points = Array.new(5, 0) if @cg_actor_bonus_points == nil || @cg_actor_bonus_points.size != 5
    allocated = 0
    for value in @cg_actor_bonus_points
      allocated += value.to_i
    end
    if @cg_actor_bp_awarded_level == nil
      earned = [@level.to_i - 1, 0].max * ALBERT_CG::ACTOR_BP_PER_LEVEL
      @cg_actor_unspent_bp = [earned - allocated, 0].max if @cg_actor_unspent_bp == nil
      @cg_actor_bp_awarded_level = @level.to_i
    else
      @cg_actor_unspent_bp = 0 if @cg_actor_unspent_bp == nil
      if @level.to_i > @cg_actor_bp_awarded_level.to_i
        gain = @level.to_i - @cg_actor_bp_awarded_level.to_i
        @cg_actor_unspent_bp += gain * ALBERT_CG::ACTOR_BP_PER_LEVEL
      end
      @cg_actor_bp_awarded_level = @level.to_i
    end
    @cg_actor_unspent_bp = [@cg_actor_unspent_bp.to_i, 0].max
    return true
  end

  def cg_growth_unspent_bp
    if cg_clone_pet_growth?
      return cg_unspent_bp
    end
    cg_prepare_actor_growth_data
    return @cg_actor_unspent_bp.to_i
  end

  def cg_growth_bonus_point(index)
    if cg_clone_pet_growth?
      return cg_bonus_point(index)
    end
    cg_prepare_actor_growth_data
    return 0 if index.to_i < 0 || index.to_i >= 5
    return @cg_actor_bonus_points[index.to_i].to_i
  end

  def cg_growth_role_name
    return "Clone 寵物" if cg_clone_pet_growth?
    if respond_to?(:cg_fixed_partner_pet?) && cg_fixed_partner_pet?
      return "固定寵物"
    end
    return "人物"
  end

  def cg_growth_allocate(index, amount = 1)
    return cg_allocate_bp(index, amount) if cg_clone_pet_growth?
    index = index.to_i
    amount = amount.to_i
    return false if index < 0 || index >= 5 || amount <= 0
    cg_prepare_actor_growth_data
    return false if @cg_actor_unspent_bp.to_i < amount
    old_maxhp = maxhp
    old_maxmp = maxmp
    old_hp = hp
    old_mp = mp
    @cg_actor_bonus_points[index] += amount
    @cg_actor_unspent_bp -= amount
    hp_gain = maxhp - old_maxhp
    mp_gain = maxmp - old_maxmp
    self.hp = old_hp + hp_gain if hp_gain > 0 && old_hp > 0
    self.mp = old_mp + mp_gain if mp_gain > 0
    return true
  end

  def cg_growth_refund(index, amount = 1)
    return cg_refund_bp(index, amount) if cg_clone_pet_growth?
    index = index.to_i
    amount = amount.to_i
    return false if index < 0 || index >= 5 || amount <= 0
    cg_prepare_actor_growth_data
    return false if @cg_actor_bonus_points[index].to_i < amount
    @cg_actor_bonus_points[index] -= amount
    @cg_actor_unspent_bp += amount
    self.hp = [hp, maxhp].min
    self.mp = [mp, maxmp].min
    return true
  end

  def cg_growth_gain_bp(amount)
    return cg_gain_unspent_bp(amount) if cg_clone_pet_growth?
    cg_prepare_actor_growth_data
    @cg_actor_unspent_bp += amount.to_i
    @cg_actor_unspent_bp = 0 if @cg_actor_unspent_bp < 0
    return true
  end

  def cg_growth_stat_value_text(index)
    case index.to_i
    when 0; return maxhp.to_s
    when 1; return atk.to_s
    when 2; return self.def.to_s
    when 3; return agi.to_s
    when 4; return "MP " + maxmp.to_s + "／精神 " + spi.to_s
    end
    return "0"
  end

  alias albert_cg_v09_actor_growth_level_up level_up
  def level_up
    albert_cg_v09_actor_growth_level_up
    cg_prepare_actor_growth_data unless cg_clone_pet_growth?
  end

  alias albert_cg_v09_actor_growth_base_maxhp base_maxhp
  def base_maxhp
    value = albert_cg_v09_actor_growth_base_maxhp
    return value if cg_clone_pet_growth?
    cg_prepare_actor_growth_data
    return [value + @cg_actor_bonus_points[0].to_i * 5, 1].max
  end

  alias albert_cg_v09_actor_growth_base_maxmp base_maxmp
  def base_maxmp
    value = albert_cg_v09_actor_growth_base_maxmp
    return value if cg_clone_pet_growth?
    cg_prepare_actor_growth_data
    return [value + @cg_actor_bonus_points[4].to_i * 3, 0].max
  end

  alias albert_cg_v09_actor_growth_base_atk base_atk
  def base_atk
    value = albert_cg_v09_actor_growth_base_atk
    return value if cg_clone_pet_growth?
    cg_prepare_actor_growth_data
    return [value + @cg_actor_bonus_points[1].to_i, 1].max
  end

  alias albert_cg_v09_actor_growth_base_def base_def
  def base_def
    value = albert_cg_v09_actor_growth_base_def
    return value if cg_clone_pet_growth?
    cg_prepare_actor_growth_data
    return [value + @cg_actor_bonus_points[2].to_i, 1].max
  end

  alias albert_cg_v09_actor_growth_base_spi base_spi
  def base_spi
    value = albert_cg_v09_actor_growth_base_spi
    return value if cg_clone_pet_growth?
    cg_prepare_actor_growth_data
    return [value + @cg_actor_bonus_points[4].to_i, 1].max
  end

  alias albert_cg_v09_actor_growth_base_agi base_agi
  def base_agi
    value = albert_cg_v09_actor_growth_base_agi
    return value if cg_clone_pet_growth?
    cg_prepare_actor_growth_data
    return [value + @cg_actor_bonus_points[3].to_i, 1].max
  end
end

class Window_CG_DevelopmentActorList < Window_Selectable
  def initialize
    super(0, 56, 240, 360)
    @column_max = 1
    refresh
    self.index = 0
  end

  def actor
    return nil if @data == nil || @data.empty?
    return @data[self.index]
  end

  def refresh
    @data = []
    for actor in $game_party.members
      next if actor == nil
      next if actor.respond_to?(:cg_pet?) && actor.cg_pet?
      @data.push(actor)
    end
    @item_max = [@data.size, 1].max
    create_contents
    if @data.empty?
      self.contents.draw_text(4, 0, contents.width - 8, WLH, "沒有可育成角色")
    else
      for i in 0...@data.size
        draw_item(i)
      end
    end
  end

  def draw_item(index)
    actor = @data[index]
    return if actor == nil
    rect = item_rect(index)
    self.contents.clear_rect(rect)
    role = actor.cg_growth_role_name
    self.contents.draw_text(rect.x + 4, rect.y, rect.width - 60, WLH, actor.name)
    self.contents.font.color = system_color
    self.contents.draw_text(rect.x + rect.width - 92, rect.y, 88, WLH, role, 2)
    self.contents.font.color = normal_color
  end
end

class Window_CG_DevelopmentDetail < Window_Base
  def initialize
    super(240, 56, 304, 208)
    @actor = nil
  end

  def actor=(actor)
    return if @actor == actor
    @actor = actor
    refresh
  end

  def refresh
    self.contents.clear
    return self.contents.draw_text(0, 0, contents.width, WLH, "選擇一名角色") if @actor == nil
    self.contents.font.size = 18
    draw_actor_graphic(@actor, 264, 52)
    y = 0
    draw_line(y, "類型", @actor.cg_growth_role_name); y += 24
    draw_line(y, "等級／BP", @actor.level.to_s + "／" + @actor.cg_growth_unspent_bp.to_s); y += 24
    draw_line(y, "HP／MP", @actor.hp.to_s + "/" + @actor.maxhp.to_s + "　" + @actor.mp.to_s + "/" + @actor.maxmp.to_s); y += 24
    draw_line(y, "攻防精敏", @actor.atk.to_s + "／" + @actor.def.to_s + "／" + @actor.spi.to_s + "／" + @actor.agi.to_s); y += 24
    values = []
    5.times { |i| values.push(@actor.cg_growth_bonus_point(i).to_s) }
    draw_line(y, "配點", values.join("／"))
    self.contents.font.size = Font.default_size
  end

  def draw_line(y, label, value)
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 88, 24, label)
    self.contents.font.color = normal_color
    self.contents.draw_text(88, y, contents.width - 88, 24, value)
  end
end

class Window_CG_UniversalGrowthList < Window_Selectable
  attr_reader :actor
  def initialize(actor)
    super(0, 80, 280, 336)
    @actor = actor
    @column_max = 1
    @item_max = 5
    refresh
    self.index = 0
  end
  def refresh
    create_contents
    self.contents.clear
    5.times { |i| draw_item(i) }
  end
  def draw_item(index)
    rect = item_rect(index)
    name = ALBERT_CG::ACTOR_BP_STAT_NAMES[index]
    self.contents.draw_text(rect.x + 4, rect.y, 70, WLH, name)
    self.contents.font.color = system_color
    self.contents.draw_text(rect.x + 76, rect.y, 54, WLH, "+" + @actor.cg_growth_bonus_point(index).to_s)
    self.contents.font.color = normal_color
    self.contents.draw_text(rect.x + 130, rect.y, rect.width - 134, WLH, @actor.cg_growth_stat_value_text(index), 2)
  end
end

class Window_CG_UniversalGrowthInfo < Window_Base
  def initialize(actor)
    super(280, 80, 264, 336)
    @actor = actor
    @index = 0
    @session_added = Array.new(5, 0)
    refresh
  end
  def index=(value)
    return if @index == value.to_i
    @index = value.to_i
    refresh
  end
  def session_added(index); return @session_added[index.to_i].to_i; end
  def add_session(index); @session_added[index.to_i] += 1; refresh; end
  def remove_session(index)
    i = index.to_i
    return false if @session_added[i] <= 0
    @session_added[i] -= 1
    refresh
    return true
  end
  def refresh
    self.contents.clear
    self.contents.font.size = 18
    draw_actor_graphic(@actor, 210, 56)
    draw_line(0, @actor.cg_growth_role_name, @actor.name)
    draw_line(28, "Lv.／BP", @actor.level.to_s + "／" + @actor.cg_growth_unspent_bp.to_s)
    self.contents.font.color = system_color
    self.contents.draw_text(0, 66, 200, WLH, "目前選擇")
    self.contents.font.color = normal_color
    self.contents.draw_text(0, 92, 220, WLH, ALBERT_CG::ACTOR_BP_STAT_NAMES[@index])
    self.contents.font.size = 16
    self.contents.draw_text(0, 118, 220, 22, ALBERT_CG::ACTOR_BP_STAT_EFFECTS[@index])
    self.contents.font.size = 18
    draw_line(156, "已分配／本次", @actor.cg_growth_bonus_point(@index).to_s + "／+" + session_added(@index).to_s)
    self.contents.font.color = system_color
    self.contents.draw_text(0, 208, 220, WLH, "操作")
    self.contents.font.color = normal_color
    self.contents.font.size = 16
    self.contents.draw_text(0, 234, 220, 22, "右／C：分配 1 點")
    self.contents.draw_text(0, 256, 220, 22, "左：退回本次 1 點")
    self.contents.draw_text(0, 278, 220, 22, "B：返回")
    self.contents.font.size = Font.default_size
  end
  def draw_line(y, label, value)
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 90, WLH, label)
    self.contents.font.color = normal_color
    self.contents.draw_text(90, y, 120, WLH, value)
  end
end

class Scene_CG_UniversalGrowth < Scene_Base
  def initialize(actor_id, return_actor_id = nil)
    @actor_id = actor_id.to_i
    @return_actor_id = return_actor_id == nil ? @actor_id : return_actor_id.to_i
  end
  def main
    start
    perform_transition
    Input.update
    loop do
      Graphics.update; Input.update; update
      break if $scene != self
    end
    Graphics.update; pre_terminate; Graphics.freeze; terminate
  end
  def start
    super
    @actor = $game_actors[@actor_id]
    if @actor == nil
      $scene = Scene_CG_PartyDevelopment.new
      return
    end
    @actor.cg_prepare_actor_growth_data unless @actor.cg_clone_pet_growth?
    create_menu_background
    @title_window = Window_Base.new(0, 0, 544, 80)
    @title_window.contents.draw_text(0, 0, 512, Window_Base::WLH, "角色能力配點")
    @title_window.contents.font.size = 16
    @title_window.contents.draw_text(0, 24, 512, Window_Base::WLH, "上／下選擇　右或 C 分配　左退回本次　B 返回")
    @list_window = Window_CG_UniversalGrowthList.new(@actor)
    @info_window = Window_CG_UniversalGrowthInfo.new(@actor)
  end
  def terminate
    super
    dispose_menu_background
    @title_window.dispose if @title_window != nil
    @list_window.dispose if @list_window != nil
    @info_window.dispose if @info_window != nil
  end
  def update
    super
    update_menu_background
    @list_window.update
    @info_window.index = @list_window.index
    if Input.trigger?(Input::B)
      Sound.play_cancel
      $scene = Scene_CG_PartyDevelopment.new(@return_actor_id)
    elsif Input.trigger?(Input::LEFT)
      i = @list_window.index
      if @info_window.session_added(i) > 0 && @actor.cg_growth_refund(i, 1)
        @info_window.remove_session(i); Sound.play_cursor; refresh_windows
      else
        Sound.play_buzzer
      end
    elsif Input.trigger?(Input::RIGHT) || Input.trigger?(Input::C)
      i = @list_window.index
      if @actor.cg_growth_allocate(i, 1)
        @info_window.add_session(i); Sound.play_equip; refresh_windows
      else
        Sound.play_buzzer
      end
    end
  end
  def refresh_windows
    @list_window.refresh
    @info_window.refresh
  end
end

class Game_Interpreter
  def cg_open_party_development
    $scene = Scene_CG_PartyDevelopment.new
    return true
  end
  def cg_open_actor_growth(actor_id)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil || (actor.respond_to?(:cg_pet?) && actor.cg_pet?)
    $scene = Scene_CG_UniversalGrowth.new(actor.id)
    return true
  end
  def cg_give_actor_bp(actor_id, amount)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil || (actor.respond_to?(:cg_pet?) && actor.cg_pet?)
    return actor.cg_growth_gain_bp(amount)
  end
end
