# RMVX_SCRIPT_INDEX: 139
# RMVX_SCRIPT_ID: 98941057
# RMVX_SCRIPT_NAME: CG Pet Growth v0.8.1
# RMVX_SOURCE_SHA256: 3166a870c10978a49c91bb2e492478f00eb79f832cacc4cccec986aaadaad15b

#==============================================================================
# 【繁體中文說明】ALBERT CG 寵物育成與能力配點
#------------------------------------------------------------------------------
# 【版本】v0.8.1
# 【用途】
#  1. Clone 寵物每提升 1 級獲得可分配 BP。
#  2. 在 F5 寵物管理中加入「能力配點」。
#  3. 可將 BP 分配至體力、力量、強度、速度、魔法五項成長。
#  4. 攜帶名冊與寵物倉庫中的個體都能配點，資料跟隨個體 ID 保存。
#
# 【五項能力對應】
#  體力：每點最大 HP +5
#  力量：每點攻擊力 +1
#  強度：每點防禦力 +1
#  速度：每點敏捷度 +1
#  魔法：每點最大 MP +3、精神力 +1
#
# 【BP 規則】
#  - 每提升 1 級獲得 PET_BP_PER_LEVEL 點 BP，預設為 1。
#  - Lv.5 的新寵物會擁有 4 點可分配 BP。
#  - 舊存檔首次讀取時，會依目前等級與已分配點數補算可用 BP。
#  - 已確認離開配點畫面的點數不可免費重置。
#  - 配點畫面中，僅能退回「本次進入畫面後」剛分配的點數。
#
# 【操作】
#  F5 寵物管理 → 選擇個體 → 能力配點
#  上／下：選擇能力
#  右方向鍵或 C：分配 1 點
#  左方向鍵：退回本次剛分配的 1 點
#  B：返回寵物管理
#
# 【事件指令】
#  cg_open_pet_growth(個體ID)       # 開啟指定寵物的配點畫面
#  cg_give_pet_bp(個體ID, 數量)    # 額外給予可分配 BP
#
# 【v0.8.1 修正】
#  - Scene_CG_PetGrowth 的標題繪製改用 Window_Base::WLH。
#  - 避免 Scene 直接引用 Window_Base 專屬常數而發生 NameError。
#
# 【注意事項】
#  - 本功能只套用於主角可捕捉的 Clone 寵物。
#  - 隊友固定普通 Actor 寵物不使用 Clone 個體配點。
#  - 本腳本必須放在 CG Pet Storage UI Battle Sprite Fix 下方、Main 上方。
#  - 所有設定與說明皆使用繁體中文，方便後續直接維護。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PetGrowth"] = true

module ALBERT_CG
  PET_GROWTH_VERSION = "0.8.1"
  PET_BP_PER_LEVEL = 1 unless const_defined?(:PET_BP_PER_LEVEL)
  PET_BP_STAT_NAMES = ["體力", "力量", "強度", "速度", "魔法"] unless const_defined?(:PET_BP_STAT_NAMES)
  PET_BP_STAT_EFFECTS = [
    "每點最大 HP +5",
    "每點攻擊力 +1",
    "每點防禦力 +1",
    "每點敏捷度 +1",
    "每點最大 MP +3、精神力 +1"
  ] unless const_defined?(:PET_BP_STAT_EFFECTS)
end

#==============================================================================
# ■ Game_Actor
#------------------------------------------------------------------------------
#  保存個體可用 BP、等級發放進度與能力配點操作。
#==============================================================================
class Game_Actor < Game_Battler
  attr_reader :cg_unspent_bp
  attr_reader :cg_bp_awarded_level

  # 舊存檔與新個體共用的資料修復。
  def cg_prepare_growth_data
    return false unless respond_to?(:cg_pet?) && cg_pet?
    cg_prepare_pet_data if respond_to?(:cg_prepare_pet_data)
    if @cg_bp_awarded_level == nil
      allocated = 0
      if @cg_bonus_points != nil
        for value in @cg_bonus_points
          allocated += value.to_i
        end
      end
      earned = [@level.to_i - 1, 0].max * ALBERT_CG::PET_BP_PER_LEVEL
      @cg_unspent_bp = [earned - allocated, 0].max if @cg_unspent_bp == nil
      @cg_bp_awarded_level = @level.to_i
    else
      @cg_unspent_bp = 0 if @cg_unspent_bp == nil
      if @level.to_i > @cg_bp_awarded_level.to_i
        gained_levels = @level.to_i - @cg_bp_awarded_level.to_i
        @cg_unspent_bp += gained_levels * ALBERT_CG::PET_BP_PER_LEVEL
        @cg_bp_awarded_level = @level.to_i
      elsif @level.to_i < @cg_bp_awarded_level.to_i
        @cg_bp_awarded_level = @level.to_i
      end
    end
    @cg_unspent_bp = [@cg_unspent_bp.to_i, 0].max
    return true
  end

  def cg_unspent_bp
    return 0 unless cg_prepare_growth_data
    return @cg_unspent_bp.to_i
  end

  def cg_total_allocated_bp
    return 0 unless respond_to?(:cg_pet?) && cg_pet?
    cg_prepare_pet_data
    total = 0
    for value in @cg_bonus_points
      total += value.to_i
    end
    return total
  end

  def cg_growth_stat_value(index)
    case index.to_i
    when 0
      return maxhp
    when 1
      return atk
    when 2
      return self.def
    when 3
      return agi
    when 4
      return spi
    end
    return 0
  end

  def cg_growth_stat_value_text(index)
    if index.to_i == 4
      return "MP " + maxmp.to_s + "／精神 " + spi.to_s
    end
    return cg_growth_stat_value(index).to_s
  end

  def cg_allocate_bp(index, amount = 1)
    return false unless respond_to?(:cg_pet?) && cg_pet?
    index = index.to_i
    amount = amount.to_i
    return false if index < 0 || index >= ALBERT_CG::GRADE_STAT_COUNT
    return false if amount <= 0
    cg_prepare_growth_data
    return false if @cg_unspent_bp < amount
    old_maxhp = maxhp
    old_maxmp = maxmp
    old_hp = self.hp
    old_mp = self.mp
    @cg_bonus_points[index] += amount
    @cg_unspent_bp -= amount
    hp_gain = maxhp - old_maxhp
    mp_gain = maxmp - old_maxmp
    self.hp = old_hp + hp_gain if hp_gain > 0 && old_hp > 0
    self.mp = old_mp + mp_gain if mp_gain > 0
    return true
  end

  # 只供配點畫面退回本次剛分配的點數。
  def cg_refund_bp(index, amount = 1)
    return false unless respond_to?(:cg_pet?) && cg_pet?
    index = index.to_i
    amount = amount.to_i
    return false if index < 0 || index >= ALBERT_CG::GRADE_STAT_COUNT
    return false if amount <= 0
    cg_prepare_growth_data
    return false if @cg_bonus_points[index].to_i < amount
    @cg_bonus_points[index] -= amount
    @cg_unspent_bp += amount
    self.hp = [self.hp, maxhp].min
    self.mp = [self.mp, maxmp].min
    return true
  end

  def cg_gain_unspent_bp(amount)
    return false unless respond_to?(:cg_pet?) && cg_pet?
    amount = amount.to_i
    return false if amount == 0
    cg_prepare_growth_data
    @cg_unspent_bp += amount
    @cg_unspent_bp = 0 if @cg_unspent_bp < 0
    return true
  end

  alias albert_cg_v08_growth_level_up level_up
  def level_up
    albert_cg_v08_growth_level_up
    cg_prepare_growth_data if respond_to?(:cg_pet?) && cg_pet?
  end
end

#==============================================================================
# ■ Window_CG_PetDetail
#------------------------------------------------------------------------------
#  F5 詳細資料改為顯示可用 BP、戰鬥能力與五項已分配點數。
#==============================================================================
class Window_CG_PetDetail < Window_Base
  def refresh
    self.contents.clear
    if @pet == nil
      self.contents.draw_text(0, 0, contents.width, WLH, "選擇一隻寵物")
      return
    end
    @pet.cg_prepare_pet_data
    @pet.cg_prepare_growth_data if @pet.respond_to?(:cg_prepare_growth_data)
    self.contents.font.size = 16
    y = 0
    cg_v08_detail_line(y, "個體／物種", @pet.id.to_s + "／" + @pet.cg_species_id.to_s)
    y += 22
    cg_v08_detail_line(y, "等級／可用BP", @pet.level.to_s + "／" + @pet.cg_unspent_bp.to_s)
    y += 22
    cg_v08_detail_line(y, "HP／MP", @pet.hp.to_s + "/" + @pet.maxhp.to_s + "　" + @pet.mp.to_s + "/" + @pet.maxmp.to_s)
    y += 22
    cg_v08_detail_line(y, "攻／防／精／敏", @pet.atk.to_s + "／" + @pet.def.to_s + "／" + @pet.spi.to_s + "／" + @pet.agi.to_s)
    y += 22
    points = []
    5.times { |i| points.push(@pet.cg_bonus_point(i).to_s) }
    cg_v08_detail_line(y, "配點 體力起", points.join("／"))
    y += 22
    grades = []
    5.times { |i| grades.push(@pet.cg_grade_loss_at(i).to_s) }
    cg_v08_detail_line(y, "掉檔 體力起", grades.join("／"))
    y += 22
    names = @pet.skills.collect { |skill| skill.name }
    cg_v08_detail_line(y, "技能", names.join("、"))
    self.contents.font.size = Font.default_size
  end

  def cg_v08_detail_line(y, label, value)
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 94, 22, label.to_s)
    self.contents.font.color = normal_color
    self.contents.draw_text(94, y, contents.width - 94, 22, value.to_s)
  end
end

#==============================================================================
# ■ Window_CG_GrowthList
#------------------------------------------------------------------------------
#  五項配點選擇視窗。
#==============================================================================
class Window_CG_GrowthList < Window_Selectable
  attr_reader :pet

  def initialize(pet)
    super(0, 80, 280, 336)
    @pet = pet
    @column_max = 1
    @item_max = 5
    refresh
    self.index = 0
  end

  def refresh
    create_contents
    self.contents.clear
    for i in 0...5
      draw_item(i)
    end
  end

  def draw_item(index)
    rect = item_rect(index)
    self.contents.clear_rect(rect)
    name = ALBERT_CG::PET_BP_STAT_NAMES[index]
    allocated = @pet.cg_bonus_point(index)
    value = @pet.cg_growth_stat_value_text(index)
    self.contents.draw_text(rect.x + 4, rect.y, 70, WLH, name)
    self.contents.font.color = system_color
    self.contents.draw_text(rect.x + 76, rect.y, 54, WLH, "+" + allocated.to_s)
    self.contents.font.color = normal_color
    self.contents.draw_text(rect.x + 130, rect.y, rect.width - 134, WLH, value, 2)
  end
end

#==============================================================================
# ■ Window_CG_GrowthInfo
#------------------------------------------------------------------------------
#  顯示個體資料、可用 BP、本次分配與目前選項說明。
#==============================================================================
class Window_CG_GrowthInfo < Window_Base
  def initialize(pet)
    super(280, 80, 264, 336)
    @pet = pet
    @index = 0
    @session_added = Array.new(5, 0)
    refresh
  end

  def index=(value)
    value = value.to_i
    return if @index == value
    @index = value
    refresh
  end

  def session_added(index)
    return @session_added[index.to_i].to_i
  end

  def add_session_point(index)
    @session_added[index.to_i] += 1
    refresh
  end

  def remove_session_point(index)
    i = index.to_i
    return false if @session_added[i].to_i <= 0
    @session_added[i] -= 1
    refresh
    return true
  end

  def refresh
    self.contents.clear
    self.contents.font.size = 18
    draw_actor_graphic(@pet, 210, 56)
    self.contents.font.color = system_color
    self.contents.draw_text(0, 0, 120, WLH, "寵物")
    self.contents.font.color = normal_color
    self.contents.draw_text(58, 0, 140, WLH, @pet.name.to_s)
    self.contents.font.color = system_color
    self.contents.draw_text(0, 28, 90, WLH, "Lv.／BP")
    self.contents.font.color = normal_color
    self.contents.draw_text(90, 28, 110, WLH, @pet.level.to_s + "／" + @pet.cg_unspent_bp.to_s)
    self.contents.font.color = system_color
    self.contents.draw_text(0, 62, 200, WLH, "目前選擇")
    self.contents.font.color = normal_color
    self.contents.draw_text(0, 88, 210, WLH, ALBERT_CG::PET_BP_STAT_NAMES[@index])
    self.contents.draw_text(0, 114, 220, WLH, ALBERT_CG::PET_BP_STAT_EFFECTS[@index])
    self.contents.font.color = system_color
    self.contents.draw_text(0, 154, 200, WLH, "已分配／本次")
    self.contents.font.color = normal_color
    text = @pet.cg_bonus_point(@index).to_s + "／+" + session_added(@index).to_s
    self.contents.draw_text(0, 180, 200, WLH, text)
    self.contents.font.color = system_color
    self.contents.draw_text(0, 212, 220, WLH, "操作")
    self.contents.font.color = normal_color
    self.contents.font.size = 16
    self.contents.draw_text(0, 238, 220, 22, "右／C：分配 1 點")
    self.contents.draw_text(0, 260, 220, 22, "左：退回本次 1 點")
    self.contents.draw_text(0, 282, 220, 22, "B：返回寵物管理")
    self.contents.font.size = Font.default_size
  end
end

#==============================================================================
# ■ Scene_CG_PetGrowth
#------------------------------------------------------------------------------
#  寵物能力配點場景。
#==============================================================================
class Scene_CG_PetGrowth < Scene_Base
  def initialize(pet_id, return_mode = :carried)
    @pet_id = pet_id.to_i
    @return_mode = return_mode
  end

  def main
    start
    return if $scene != self
    perform_transition
    Input.update
    loop do
      Graphics.update
      Input.update
      update
      break if $scene != self
    end
    Graphics.update
    pre_terminate
    Graphics.freeze
    terminate
  end

  def start
    super
    @pet = $game_actors.cg_pet(@pet_id)
    if @pet == nil
      $scene = Scene_CG_PetLab.new(@return_mode, @pet_id)
      return
    end
    @pet.cg_prepare_growth_data
    create_menu_background
    @title_window = Window_Base.new(0, 0, 544, 80)
    @title_window.contents.font.size = 20
    @title_window.contents.draw_text(0, 0, 512, Window_Base::WLH, "寵物能力配點")
    @title_window.contents.font.size = 16
    @title_window.contents.draw_text(0, 24, 512, Window_Base::WLH, "上／下選擇　右或 C 分配　左退回本次　B 返回")
    @list_window = Window_CG_GrowthList.new(@pet)
    @info_window = Window_CG_GrowthInfo.new(@pet)
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
      $scene = Scene_CG_PetLab.new(@return_mode, @pet.id)
    elsif Input.trigger?(Input::LEFT)
      index = @list_window.index
      if @info_window.session_added(index) > 0 && @pet.cg_refund_bp(index, 1)
        @info_window.remove_session_point(index)
        Sound.play_cursor
        refresh_windows
      else
        Sound.play_buzzer
      end
    elsif Input.trigger?(Input::RIGHT) || Input.trigger?(Input::C)
      index = @list_window.index
      if @pet.cg_allocate_bp(index, 1)
        @info_window.add_session_point(index)
        Sound.play_equip
        refresh_windows
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

#==============================================================================
# ■ Window_CG_PetList
#------------------------------------------------------------------------------
#  讓配點場景返回時，能重新選取原本的個體。
#==============================================================================
class Window_CG_PetList < Window_Selectable
  def cg_select_pet_id(actor_id)
    return false if @data == nil
    for i in 0...@data.size
      if @data[i] != nil && @data[i].id == actor_id.to_i
        self.index = i
        return true
      end
    end
    return false
  end
end

#==============================================================================
# ■ Scene_CG_PetLab
#------------------------------------------------------------------------------
#  F5 加入「能力配點」，並保留返回時的頁籤與個體位置。
#==============================================================================
class Scene_CG_PetLab < Scene_Base
  alias albert_cg_v08_petlab_start start

  def initialize(initial_mode = :carried, selected_pet_id = nil)
    @cg_v08_initial_mode = initial_mode
    @cg_v08_selected_pet_id = selected_pet_id
  end

  def start
    albert_cg_v08_petlab_start
    target_mode = @cg_v08_initial_mode == :storage ? :storage : :carried
    if @mode != target_mode
      @mode = target_mode
      @pet_window.mode = @mode
      rebuild_command_window
      refresh_title
    end
    @pet_window.cg_select_pet_id(@cg_v08_selected_pet_id) if @cg_v08_selected_pet_id != nil
    refresh_detail
  end

  # 攜帶頁新增能力配點，共六項；倉庫頁新增能力配點，共四項。
  def rebuild_command_window
    old_active = @command_window != nil && @command_window.active
    @command_window.dispose if @command_window != nil
    commands = if @mode == :storage
      ["取出／交換至攜帶", "能力配點", "放生", "取消"]
    else
      ["設為出戰", "能力配點", "存入倉庫", "收回目前寵物", "放生", "取消"]
    end
    @command_window = Window_Command.new(304, commands, 1, 5)
    @command_window.x = 240
    @command_window.y = 264
    @command_window.active = old_active
    @command_window.index = old_active ? 0 : -1
  end

  def cg_open_growth_scene(pet)
    if pet == nil || !pet.respond_to?(:cg_pet?) || !pet.cg_pet?
      Sound.play_buzzer
      return false
    end
    Sound.play_decision
    $scene = Scene_CG_PetGrowth.new(pet.id, @mode)
    return true
  end

  def update_carried_command(pet)
    case @command_window.index
    when 0
      if pet != nil && $game_party.cg_map_deploy_pet(pet.id)
        Sound.play_equip
        refresh_all
      else
        Sound.play_buzzer
      end
    when 1
      cg_open_growth_scene(pet)
      return
    when 2
      if pet != nil && $game_party.cg_store_pet(pet.id)
        Sound.play_equip
        refresh_all
      else
        Sound.play_buzzer
      end
    when 3
      if $game_party.cg_map_recall_pet
        Sound.play_equip
        refresh_all
      else
        Sound.play_buzzer
      end
    when 4
      if pet != nil && $game_actors.cg_delete_pet(pet.id)
        Sound.play_decision
        refresh_all
      else
        Sound.play_buzzer
      end
    when 5
      Sound.play_cancel
    end
    close_command
  end

  def update_storage_command(pet)
    case @command_window.index
    when 0
      if pet == nil
        Sound.play_buzzer
      elsif !$game_party.cg_carry_full?
        if $game_party.cg_withdraw_pet(pet.id)
          Sound.play_equip
          refresh_all
        else
          Sound.play_buzzer
        end
      else
        @pending_storage_pet_id = pet.id
        @swap_mode = true
        @command_window.active = false
        @command_window.index = -1
        @pet_window.active = true
        @mode = :carried
        @pet_window.mode = :carried
        refresh_title
        refresh_detail
        Sound.play_decision
        return
      end
    when 1
      cg_open_growth_scene(pet)
      return
    when 2
      if pet != nil && $game_actors.cg_delete_pet(pet.id)
        Sound.play_decision
        refresh_all
      else
        Sound.play_buzzer
      end
    when 3
      Sound.play_cancel
    end
    close_command
  end
end

#==============================================================================
# ■ Game_Interpreter
#------------------------------------------------------------------------------
#  事件用配點指令。
#==============================================================================
class Game_Interpreter
  def cg_open_pet_growth(actor_id)
    pet = $game_actors.cg_pet(actor_id.to_i)
    return false if pet == nil
    mode = $game_party.respond_to?(:cg_storage_pet_ids) &&
      $game_party.cg_storage_pet_ids.include?(pet.id) ? :storage : :carried
    $scene = Scene_CG_PetGrowth.new(pet.id, mode)
    return true
  end

  def cg_give_pet_bp(actor_id, amount)
    pet = $game_actors.cg_pet(actor_id.to_i)
    return false if pet == nil
    return pet.cg_gain_unspent_bp(amount.to_i)
  end
end

#==============================================================================
# ■ ALBERT_CG 測試
#==============================================================================
module ALBERT_CG
  def self.run_pet_growth_data_test
    return false if $game_actors == nil
    pets = $game_actors.cg_all_pets
    return false if pets.empty?
    pet = pets[0]
    before_bp = pet.cg_unspent_bp
    before_point = pet.cg_bonus_point(0)
    return false unless pet.cg_gain_unspent_bp(1)
    return false unless pet.cg_allocate_bp(0, 1)
    passed = pet.cg_bonus_point(0) == before_point + 1 &&
      pet.cg_unspent_bp == before_bp
    p "CG v0.8 寵物配點資料測試：" + (passed ? "成功" : "失敗")
    return passed
  end
end
