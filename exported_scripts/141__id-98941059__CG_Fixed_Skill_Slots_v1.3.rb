# RMVX_SCRIPT_INDEX: 141
# RMVX_SCRIPT_ID: 98941059
# RMVX_SCRIPT_NAME: CG Fixed Skill Slots v1.3
# RMVX_SOURCE_SHA256: 9a62d9d4fb3e2fb44ad723f9ecc0787300e79bcf15002e13f9ce44b6ee234730

#==============================================================================
# 【繁體中文說明】ALBERT CG 固定技能欄與技能資料介面
#------------------------------------------------------------------------------
# 【版本】v1.3
# 【用途】
#  1. 人類技能欄固定 8 格。
#  2. 寵物技能欄依目前物種／進化型態設定。
#  3. 已學技能就是技能欄內容，不再存在「技能庫＋裝備格」雙層結構。
#  4. 技能欄已滿時，學習新技能必須指定要取代的欄位。
#  5. F4 隊伍育成與 F5 寵物管理都可查看技能欄、等級與熟練度。
#
# 【寵物技能格】
#  在 PET_SKILL_SLOT_LIMITS 以 Actor／物種 ID 設定。
#  Clone 寵物優先讀取 cg_species_id；固定寵物使用自己的 Actor ID。
#
# 【學習接口】
#  actor.cg_learn_skill_to_slot(skill_id, level, replace_index)
#    成功             => true
#    格滿未指定取代   => :need_replace
#    無效資料         => false
#
#  replace_index 使用 0 起算。例：取代第 3 格請傳 2。
#
# 【注意】
#  - 人類技能商店應只傳 level = 1。
#  - 寵物技能商店可傳 level = 1～10。
#  - 一般事件直接呼叫 learn_skill 時，格滿會拒絕學習，避免形成隱藏技能庫。
#
# 【腳本位置】
#  取代舊 CG Skill Slots Manager，放在 CG Universal Growth 下方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_FixedSkillSlots"] = true

module ALBERT_CG
  FIXED_SKILL_SLOTS_VERSION = "1.3"
  HUMAN_SKILL_SLOT_LIMIT = 8 unless const_defined?(:HUMAN_SKILL_SLOT_LIMIT)
  PET_DEFAULT_SKILL_SLOT_LIMIT = 6
  PET_SKILL_SLOT_LIMITS = {
    100 => 6, 101 => 7, 102 => 8,
    103 => 6, 104 => 7, 105 => 8,
    106 => 6, 107 => 7, 108 => 8
  }

  # RGSS2 的 Input 沒有 Input::F4，使用 Win32 API 偵測實體 F4。
  CG_VK_F4 = 0x73 unless const_defined?(:CG_VK_F4)
  begin
    CG_GET_ASYNC_KEY_STATE = Win32API.new("user32", "GetAsyncKeyState", "i", "i") unless const_defined?(:CG_GET_ASYNC_KEY_STATE)
  rescue
    CG_GET_ASYNC_KEY_STATE = nil unless const_defined?(:CG_GET_ASYNC_KEY_STATE)
  end

  def self.cg_f4_trigger?
    return false if CG_GET_ASYNC_KEY_STATE == nil
    down = (CG_GET_ASYNC_KEY_STATE.call(CG_VK_F4) & 0x8000) != 0
    trigger = down && @cg_f4_was_down != true
    @cg_f4_was_down = down
    return trigger
  rescue
    return false
  end
end

class Game_Actor < Game_Battler
  #--------------------------------------------------------------------------
  # ● 技能格上限
  #--------------------------------------------------------------------------
  def cg_skill_slot_limit
    if respond_to?(:cg_skill_pet?) && cg_skill_pet?
      species_id = respond_to?(:cg_species_id) ? cg_species_id.to_i : id.to_i
      value = ALBERT_CG::PET_SKILL_SLOT_LIMITS[species_id]
      value = ALBERT_CG::PET_DEFAULT_SKILL_SLOT_LIMIT if value == nil
      # 個體曾經擁有較高欄位時不因進化／資料調整而縮減。
      @cg_highest_skill_slot_limit = value if @cg_highest_skill_slot_limit == nil
      @cg_highest_skill_slot_limit = value if value > @cg_highest_skill_slot_limit.to_i
      return [@cg_highest_skill_slot_limit.to_i, 1].max
    end
    return ALBERT_CG::HUMAN_SKILL_SLOT_LIMIT
  end

  #--------------------------------------------------------------------------
  # ● 舊存檔遷移與同步
  #--------------------------------------------------------------------------
  def cg_prepare_skill_slot_data
    source = nil
    source = @cg_skill_slot_ids if @cg_skill_slot_ids != nil
    source = @cg_equipped_skill_ids if source == nil && @cg_equipped_skill_ids != nil
    source = @skills if source == nil
    source = [] if source == nil

    result = []
    for skill_id in source
      skill_id = skill_id.to_i
      next if skill_id <= 0 || $data_skills[skill_id] == nil
      result.push(skill_id) unless result.include?(skill_id)
      break if result.size >= cg_skill_slot_limit
    end
    @cg_skill_slot_ids = result
    @cg_equipped_skill_ids = result.dup
    @skills = result.dup
    cg_prepare_skill_level_data if respond_to?(:cg_prepare_skill_level_data)
    return @cg_skill_slot_ids
  end

  def cg_skill_slot_ids
    return cg_prepare_skill_slot_data
  end

  def cg_skill_slot_skills
    result = []
    for skill_id in cg_skill_slot_ids
      skill = $data_skills[skill_id]
      result.push(skill) if skill != nil
    end
    return result
  end

  # 舊版相容名稱。現在所有技能都已在真正技能欄內。
  def cg_equipped_skill_ids
    return cg_skill_slot_ids
  end

  def cg_equipped_skills
    return cg_skill_slot_skills
  end

  def cg_skill_equipped?(skill_id)
    return cg_skill_slot_ids.include?(skill_id.to_i)
  end

  def cg_skill_slot_index(skill_id)
    return cg_skill_slot_ids.index(skill_id.to_i)
  end

  #--------------------------------------------------------------------------
  # ● 真正技能欄學習／取代
  #--------------------------------------------------------------------------
  alias albert_cg_v13_slots_base_learn_skill learn_skill
  def learn_skill(skill_id)
    return false if @cg_block_level_learning == true
    return cg_learn_skill_to_slot(skill_id, 1, nil)
  end

  # 角色升級只提升能力與 BP，不依 Class learnings 自動學習新技能。
  # 以旗標攔截原生 level_up 內部的 learn_skill，保留其他腳本的升級處理。
  alias albert_cg_v13_slots_level_up level_up
  def level_up
    @cg_block_level_learning = true
    begin
      albert_cg_v13_slots_level_up
    ensure
      @cg_block_level_learning = false
    end
  end

  def cg_learn_skill_to_slot(skill_id, level = 1, replace_index = nil)
    skill_id = skill_id.to_i
    return false if skill_id <= 0 || $data_skills[skill_id] == nil
    ids = cg_skill_slot_ids
    if ids.include?(skill_id)
      cg_set_skill_level(skill_id, [cg_skill_level(skill_id), level.to_i].max) if respond_to?(:cg_set_skill_level)
      return true
    end

    if ids.size >= cg_skill_slot_limit
      return :need_replace if replace_index == nil
      replace_index = replace_index.to_i
      return false if replace_index < 0 || replace_index >= ids.size
      old_id = ids[replace_index]
      ids[replace_index] = skill_id
      @skills.delete(old_id) if @skills != nil
      @skills.push(skill_id) unless @skills.include?(skill_id)
      if @cg_skill_levels != nil
        @cg_skill_levels.delete(old_id)
        @cg_skill_proficiency.delete(old_id) if @cg_skill_proficiency != nil
      end
    else
      ids.push(skill_id)
      @skills.push(skill_id) unless @skills.include?(skill_id)
    end
    @cg_equipped_skill_ids = ids.dup
    cg_set_skill_level(skill_id, level) if respond_to?(:cg_set_skill_level)
    return true
  end

  alias albert_cg_v13_slots_base_forget_skill forget_skill
  def forget_skill(skill_id)
    skill_id = skill_id.to_i
    albert_cg_v13_slots_base_forget_skill(skill_id)
    @cg_skill_slot_ids.delete(skill_id) if @cg_skill_slot_ids != nil
    @cg_equipped_skill_ids.delete(skill_id) if @cg_equipped_skill_ids != nil
    @cg_skill_levels.delete(skill_id) if @cg_skill_levels != nil
    @cg_skill_proficiency.delete(skill_id) if @cg_skill_proficiency != nil
    return true
  end

  def cg_forget_skill_slot(index)
    ids = cg_skill_slot_ids
    index = index.to_i
    return false if index < 0 || index >= ids.size
    return forget_skill(ids[index])
  end

  # 不再允許「卸下但仍保留在技能庫」。
  def cg_equip_skill(skill_id)
    return cg_skill_equipped?(skill_id)
  end

  def cg_unequip_skill(skill_id)
    return false
  end

  def cg_toggle_skill(skill_id)
    return false
  end

  # 技能顯示順序必須依欄位，不使用 VX 原生排序後的 @skills。
  def skills
    return cg_skill_slot_skills
  end
end

#==============================================================================
# ■ 戰鬥技能視窗
#==============================================================================
class Window_Skill < Window_Selectable
  alias albert_cg_v13_slots_refresh refresh
  def refresh
    unless $game_temp != nil && $game_temp.in_battle && @actor.respond_to?(:cg_skill_slot_skills)
      return albert_cg_v13_slots_refresh
    end
    @data = @actor.cg_skill_slot_skills
    @item_max = @data.size
    create_contents
    for i in 0...@item_max
      draw_item(i)
    end
  end
end

#==============================================================================
# ■ 技能管理畫面
#==============================================================================
class Window_CG_SkillSlots < Window_Selectable
  attr_reader :actor
  def initialize(actor)
    super(0, 56, 300, 360)
    @actor = actor
    @column_max = 1
    @item_max = actor.cg_skill_slot_limit
    refresh
    self.index = 0
  end

  def skill_id
    return nil if self.index < 0
    return @actor.cg_skill_slot_ids[self.index]
  end

  def skill
    id = skill_id
    return id == nil ? nil : $data_skills[id]
  end

  def refresh
    @item_max = @actor.cg_skill_slot_limit
    create_contents
    self.contents.clear
    for i in 0...@item_max
      draw_item(i)
    end
  end

  def draw_item(index)
    rect = item_rect(index)
    self.contents.clear_rect(rect)
    self.contents.font.color = system_color
    self.contents.draw_text(rect.x + 4, rect.y, 34, rect.height, (index + 1).to_s + ".")
    skill_id = @actor.cg_skill_slot_ids[index]
    if skill_id == nil
      self.contents.font.color = text_color(7)
      self.contents.draw_text(rect.x + 38, rect.y, rect.width - 42, rect.height, "－－空格－－")
      return
    end
    skill = $data_skills[skill_id]
    self.contents.font.color = normal_color
    level = @actor.respond_to?(:cg_skill_level) ? @actor.cg_skill_level(skill_id) : 1
    self.contents.draw_text(rect.x + 38, rect.y, rect.width - 104, rect.height, skill.name)
    self.contents.font.color = system_color
    self.contents.draw_text(rect.x + rect.width - 68, rect.y, 64, rect.height, "Lv." + level.to_s, 2)
    self.contents.font.color = normal_color
  end
end

class Window_CG_SkillDetail < Window_Base
  def initialize(actor, slot_window)
    super(300, 56, 244, 360)
    @actor = actor
    @slot_window = slot_window
    @last_index = nil
    refresh
  end

  def update
    super
    if @last_index != @slot_window.index
      @last_index = @slot_window.index
      refresh
    end
  end

  def refresh
    self.contents.clear
    self.contents.font.size = 16
    skill = @slot_window.skill
    if skill == nil
      self.contents.font.color = system_color
      self.contents.draw_text(0, 0, contents.width, 24, "空技能欄")
      self.contents.font.color = normal_color
      self.contents.draw_text(0, 30, contents.width, 48, "技能商人學習新技能時，可將技能放入此欄。")
      self.contents.font.size = Font.default_size
      return
    end
    level = @actor.cg_skill_level(skill.id)
    draw_line(0, "技能", skill.name)
    draw_line(26, "等級", "Lv." + level.to_s)
    draw_line(52, "使用次數", @actor.cg_skill_use_count(skill.id).to_s)
    if @actor.cg_skill_pet?
      draw_line(78, "成長方式", "技能商人")
      self.contents.font.color = system_color
      self.contents.draw_text(0, 112, contents.width, 24, "寵物規則")
      self.contents.font.color = normal_color
      self.contents.draw_text(0, 138, contents.width, 48, "使用技能不會增加熟練度，也不會自動升級。")
    else
      cap = @actor.cg_human_skill_level_cap(skill.id)
      rate = @actor.cg_human_skill_proficiency_rate(skill.id)
      draw_line(78, "職業上限", "Lv." + cap.to_s)
      draw_line(104, "熟練倍率", rate.to_s + "%")
      prof = @actor.cg_skill_proficiency(skill.id)
      progress = level >= cap ? "已達上限" : prof.to_s + "/" + ALBERT_CG.skill_level_threshold(level + 1, skill.id).to_s
      draw_line(130, "熟練進度", progress)
    end
    self.contents.font.color = system_color
    self.contents.draw_text(0, 184, contents.width, 24, "說明")
    self.contents.font.color = normal_color
    self.contents.draw_text(0, 210, contents.width, 86, skill.description.to_s)
    self.contents.font.size = Font.default_size
  end

  def draw_line(y, label, value)
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 82, 24, label)
    self.contents.font.color = normal_color
    self.contents.draw_text(82, y, contents.width - 82, 24, value.to_s)
  end
end

class Scene_CG_SkillManager < Scene_Base
  def initialize(actor_id, return_kind = :party, return_mode = :carried)
    @actor_id = actor_id.to_i
    @return_kind = return_kind
    @return_mode = return_mode
  end

  def main
    start
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
    @actor = $game_actors[@actor_id]
    if @actor == nil
      return_scene
      return
    end
    @actor.cg_prepare_skill_slot_data
    create_menu_background
    @title_window = Window_Base.new(0, 0, 544, 56)
    kind = @actor.cg_skill_pet? ? "寵物技能" : "人類技能"
    @title_window.contents.draw_text(0, 0, 512, Window_Base::WLH,
      @actor.name + "　" + kind + "欄　B：返回")
    @slot_window = Window_CG_SkillSlots.new(@actor)
    @detail_window = Window_CG_SkillDetail.new(@actor, @slot_window)
  end

  def terminate
    super
    dispose_menu_background
    @title_window.dispose if @title_window != nil
    @slot_window.dispose if @slot_window != nil
    @detail_window.dispose if @detail_window != nil
  end

  def update
    super
    update_menu_background
    @slot_window.update
    @detail_window.update
    if Input.trigger?(Input::B)
      Sound.play_cancel
      return_scene
    end
  end

  def return_scene
    if @return_kind == :petlab
      $scene = Scene_CG_PetLab.new(@return_mode, @actor_id)
    else
      $scene = Scene_CG_PartyDevelopment.new(@actor_id)
    end
  end
end

#==============================================================================
# ■ F4 隊伍育成基礎畫面
#==============================================================================
class Scene_CG_PartyDevelopment < Scene_Base
  def initialize(selected_actor_id = nil)
    @selected_actor_id = selected_actor_id
  end

  def main
    start
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
    create_menu_background
    @title_window = Window_Base.new(0, 0, 544, 56)
    @title_window.contents.draw_text(0, 0, 512, Window_Base::WLH, "隊伍育成　F4 開啟　C：操作　B：返回")
    @actor_window = Window_CG_DevelopmentActorList.new
    if @selected_actor_id != nil
      data = @actor_window.instance_variable_get(:@data)
      for i in 0...data.size
        @actor_window.index = i if data[i].id == @selected_actor_id.to_i
      end
    end
    @detail_window = Window_CG_DevelopmentDetail.new
    @command_window = Window_Command.new(304, ["能力配點", "技能資料", "取消"])
    @command_window.x = 240
    @command_window.y = 264
    @command_window.active = false
    @command_window.index = -1
    refresh_detail
  end

  def terminate
    super
    dispose_menu_background
    @title_window.dispose if @title_window != nil
    @actor_window.dispose if @actor_window != nil
    @detail_window.dispose if @detail_window != nil
    @command_window.dispose if @command_window != nil
  end

  def update
    super
    update_menu_background
    @actor_window.update
    @command_window.update
    refresh_detail
    if @command_window.active
      update_command
    elsif Input.trigger?(Input::B)
      Sound.play_cancel
      $scene = Scene_Map.new
    elsif Input.trigger?(Input::C)
      if @actor_window.actor == nil
        Sound.play_buzzer
      else
        Sound.play_decision
        @actor_window.active = false
        @command_window.active = true
        @command_window.index = 0
      end
    end
  end

  def refresh_detail
    @detail_window.actor = @actor_window.actor
  end

  def update_command
    if Input.trigger?(Input::B)
      Sound.play_cancel
      close_command
      return
    end
    return unless Input.trigger?(Input::C)
    actor = @actor_window.actor
    case @command_window.index
    when 0
      Sound.play_decision
      $scene = Scene_CG_UniversalGrowth.new(actor.id, actor.id)
    when 1
      Sound.play_decision
      $scene = Scene_CG_SkillManager.new(actor.id, :party)
    when 2
      Sound.play_cancel
      close_command
    end
  end

  def close_command
    @command_window.active = false
    @command_window.index = -1
    @actor_window.active = true
  end
end

#==============================================================================
# ■ F5 寵物管理加入技能資料
#==============================================================================
class Scene_CG_PetLab < Scene_Base
  def rebuild_command_window
    old_active = @command_window != nil && @command_window.active
    @command_window.dispose if @command_window != nil
    commands = if @mode == :storage
      ["取出／交換至攜帶", "能力配點", "技能資料", "放生", "取消"]
    else
      ["設為出戰", "能力配點", "技能資料", "存入倉庫", "收回目前寵物", "放生", "取消"]
    end
    @command_window = Window_Command.new(304, commands, 1, 5)
    @command_window.x = 240
    @command_window.y = 264
    @command_window.active = old_active
    @command_window.index = old_active ? 0 : -1
  end

  def update_carried_command(pet)
    case @command_window.index
    when 0
      pet != nil && $game_party.cg_map_deploy_pet(pet.id) ? (Sound.play_equip; refresh_all) : Sound.play_buzzer
    when 1
      cg_open_growth_scene(pet); return
    when 2
      if pet != nil
        Sound.play_decision
        $scene = Scene_CG_SkillManager.new(pet.id, :petlab, @mode)
        return
      else
        Sound.play_buzzer
      end
    when 3
      pet != nil && $game_party.cg_store_pet(pet.id) ? (Sound.play_equip; refresh_all) : Sound.play_buzzer
    when 4
      $game_party.cg_map_recall_pet ? (Sound.play_equip; refresh_all) : Sound.play_buzzer
    when 5
      pet != nil && $game_actors.cg_delete_pet(pet.id) ? (Sound.play_decision; refresh_all) : Sound.play_buzzer
    when 6
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
        $game_party.cg_withdraw_pet(pet.id) ? (Sound.play_equip; refresh_all) : Sound.play_buzzer
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
      cg_open_growth_scene(pet); return
    when 2
      if pet != nil
        Sound.play_decision
        $scene = Scene_CG_SkillManager.new(pet.id, :petlab, @mode)
        return
      else
        Sound.play_buzzer
      end
    when 3
      pet != nil && $game_actors.cg_delete_pet(pet.id) ? (Sound.play_decision; refresh_all) : Sound.play_buzzer
    when 4
      Sound.play_cancel
    end
    close_command
  end
end

class Game_Interpreter
  def cg_open_skill_manager(actor_id)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil
    $scene = Scene_CG_SkillManager.new(actor.id, :party)
    return true
  end

  def cg_learn_skill_to_slot(actor_id, skill_id, level = 1, replace_index = nil)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil
    return actor.cg_learn_skill_to_slot(skill_id, level, replace_index)
  end
end

class Scene_Map < Scene_Base
  alias albert_cg_v13_slots_development_update update
  def update
    albert_cg_v13_slots_development_update
    if ALBERT_CG.cg_f4_trigger? && !$game_temp.in_battle
      Sound.play_decision
      $scene = Scene_CG_PartyDevelopment.new
    end
  end
end
