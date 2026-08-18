# RMVX_SCRIPT_INDEX: 144
# RMVX_SCRIPT_ID: 12010001
# RMVX_SCRIPT_NAME: CG Pet Breeding Core v1.2.2
# RMVX_SOURCE_SHA256: e9032569db3e30a41695e76ab2c87376d31ef9d82c27e410a0a77d92fc54d44e

#==============================================================================
# 【繁體中文說明】ALBERT CG 寵物配種、個體繼承與孵化核心
#------------------------------------------------------------------------------
# 【版本】v1.2.2
# 【用途】
#  讓主角捕捉得到的 Clone 寵物進行配種，產生全新的獨立個體。
#  子代會保存父母、世代、掉檔繼承與技能繼承資料，並自動加入攜帶名冊
#  或寵物倉庫。
#
# 【適用對象】
#  - 只適用於主角持有的 Clone 寵物。
#  - 隊友固定普通 Actor 寵物不參與配種。
#
# 【開啟方法】
#  - 地圖按實體鍵盤 F3。
#  - 事件腳本：cg_open_pet_breeding
#
# 【基本規則】
#  1. 兩隻寵物不可為同一個體，且都必須存活。
#  2. 最低等級預設 5 級。
#  3. 每隻個體預設最多配種 3 次。
#  4. 未設定配種群組時，只能與同物種配種。
#  5. RPG Maker VX 的 Actor／Class 沒有 Note 欄位，因此配種群組改在本腳本
#     的 PET_BREED_GROUPS 設定表中指定。相同群組可跨物種配種。
#  6. 禁止配種的物種請加入 PET_NO_BREED_SPECIES。
#  7. 同物種子代維持該物種；跨物種同群組時，子代物種從雙親隨機選一。
#  8. 子代等級固定為 1，名稱直接使用資料庫 Actor 名稱，不加英文字母。
#
# 【掉檔繼承】
#  每項掉檔先隨機繼承其中一名親本，再進行小幅突變：
#  - 15% 機率改善 1 點。
#  - 20% 機率惡化 1 點。
#  - 其餘維持繼承值。
#  最終仍限制在 0～GRADE_LOSS_MAX；掉檔越低越好。
#
# 【技能繼承】
#  子代會從雙親已學技能中，依「雙親共同擁有」與「使用次數」排序，
#  最多額外繼承 2 招自身尚未學會的技能。技能使用次數不繼承。
#
# 【容量】
#  攜帶與倉庫同時滿時不可配種。子代會沿用寵物倉庫的自動分流規則。
#
# 【測試／事件指令】
#  cg_open_pet_breeding
#  cg_breed_pets(親本個體ID_A, 親本個體ID_B)  # 成功回傳子代個體ID
#  cg_make_breeding_test_pet(物種ActorID)       # 建立同物種測試親本
#
# 【VX 相容性注意】
#  Window_Base 在 VX 中沒有 disabled_color 方法；不可用文字統一使用 text_color(7)
#  或 ALBERT_CG::DISABLED_COMMAND_COLOR_INDEX。
#  RPG::Actor 與 RPG::Class 在 VX 中沒有 note 方法。本腳本不會讀取兩者 Note。
#  技能、物品、敵人的 Note 仍可由其他系統正常使用。
#
# 【腳本位置】
#  請放在 CG Pet Storage、CG Skill Slots Manager 等個體系統之後，Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PetBreeding"] = true

module ALBERT_CG
  PET_BREEDING_VERSION = "1.2.2"
  PET_BREED_MIN_LEVEL = 5 unless const_defined?(:PET_BREED_MIN_LEVEL)
  PET_BREED_MAX_COUNT = 3 unless const_defined?(:PET_BREED_MAX_COUNT)
  PET_BREED_INHERITED_SKILLS = 2 unless const_defined?(:PET_BREED_INHERITED_SKILLS)

  #--------------------------------------------------------------------------
  # 【VX 專用配種群組設定】
  # RPG Maker VX 的 Actor 與 Class 沒有 Note 欄位，因此請在這裡設定。
  # 鍵為物種 Actor ID，值為任意群組名稱。未列出的物種只能同物種配種。
  # 範例：
  # PET_BREED_GROUPS = {
  #   100 => :plant,
  #   101 => :plant,
  #   103 => :dragon
  # }
  #--------------------------------------------------------------------------
  PET_BREED_GROUPS = {} unless const_defined?(:PET_BREED_GROUPS)

  # 禁止配種的物種 Actor ID。範例：[150, 151]
  PET_NO_BREED_SPECIES = [] unless const_defined?(:PET_NO_BREED_SPECIES)

  CG_VK_F3 = 0x72 unless const_defined?(:CG_VK_F3)
  begin
    CG_BREED_GET_ASYNC_KEY_STATE = Win32API.new("user32", "GetAsyncKeyState", "i", "i") unless const_defined?(:CG_BREED_GET_ASYNC_KEY_STATE)
  rescue
    CG_BREED_GET_ASYNC_KEY_STATE = nil unless const_defined?(:CG_BREED_GET_ASYNC_KEY_STATE)
  end

  def self.cg_f3_trigger?
    return false if CG_BREED_GET_ASYNC_KEY_STATE == nil
    down = (CG_BREED_GET_ASYNC_KEY_STATE.call(CG_VK_F3) & 0x8000) != 0
    trigger = down && @cg_f3_was_down != true
    @cg_f3_was_down = down
    return trigger
  rescue
    return false
  end
end

#==============================================================================
# ■ Game_Actor
#==============================================================================
class Game_Actor < Game_Battler
  def cg_prepare_breeding_data
    return false unless respond_to?(:cg_pet?) && cg_pet?
    @cg_breed_count = 0 if @cg_breed_count == nil
    @cg_generation = 1 if @cg_generation == nil
    @cg_parent_pet_ids = [] if @cg_parent_pet_ids == nil
    @cg_inherited_skill_ids = [] if @cg_inherited_skill_ids == nil
    return true
  end

  def cg_breed_count
    return 0 unless cg_prepare_breeding_data
    return @cg_breed_count.to_i
  end

  def cg_generation
    return 1 unless cg_prepare_breeding_data
    return @cg_generation.to_i
  end

  def cg_parent_pet_ids
    return [] unless cg_prepare_breeding_data
    return @cg_parent_pet_ids
  end

  def cg_inherited_skill_ids
    return [] unless cg_prepare_breeding_data
    return @cg_inherited_skill_ids
  end

  def cg_breed_group
    return nil unless respond_to?(:cg_pet?) && cg_pet?
    species_id = cg_species_id.to_i
    return nil if species_id <= 0
    blocked = ALBERT_CG::PET_NO_BREED_SPECIES
    return nil if blocked != nil && blocked.include?(species_id)
    groups = ALBERT_CG::PET_BREED_GROUPS
    group = groups == nil ? nil : groups[species_id]
    if group == nil || group.to_s.strip == ""
      return "species_" + species_id.to_s
    end
    return group.to_s.strip.downcase
  end

  def cg_breed_available?
    return false unless respond_to?(:cg_pet?) && cg_pet?
    return false if cg_breed_group == nil
    return false if @level.to_i < ALBERT_CG::PET_BREED_MIN_LEVEL
    return false if dead?
    return false if cg_breed_count >= ALBERT_CG::PET_BREED_MAX_COUNT
    return true
  end

  def cg_breed_compatible_with?(other)
    return false if other == nil || other == self
    return false unless other.respond_to?(:cg_pet?) && other.cg_pet?
    return false unless cg_breed_available? && other.cg_breed_available?
    group_a = cg_breed_group
    group_b = other.cg_breed_group
    return false if group_a == nil || group_b == nil
    return group_a == group_b
  end

  def cg_increment_breed_count
    return false unless cg_prepare_breeding_data
    @cg_breed_count += 1
    return true
  end

  def cg_setup_child_breeding_data(parent_a, parent_b, inherited_skill_ids)
    return false unless cg_prepare_breeding_data
    @cg_breed_count = 0
    @cg_generation = [parent_a.cg_generation, parent_b.cg_generation].max + 1
    @cg_parent_pet_ids = [parent_a.id, parent_b.id]
    @cg_inherited_skill_ids = inherited_skill_ids.clone
    return true
  end
end

#==============================================================================
# ■ Game_Party
#==============================================================================
class Game_Party < Game_Unit
  def cg_breeding_pets
    pets = []
    if respond_to?(:cg_carried_pets)
      pets += cg_carried_pets
    end
    if respond_to?(:cg_storage_pets)
      pets += cg_storage_pets
    end
    if pets.empty? && respond_to?(:cg_owned_pets)
      pets = cg_owned_pets
    end
    result = []
    for pet in pets
      next if pet == nil
      result.push(pet) unless result.include?(pet)
    end
    return result
  end

  def cg_breeding_capacity_available?
    carry_full = respond_to?(:cg_carry_full?) ? cg_carry_full? : false
    storage_full = respond_to?(:cg_storage_full?) ? cg_storage_full? : false
    return !(carry_full && storage_full)
  end

  def cg_breed_child_species(parent_a, parent_b)
    return parent_a.cg_species_id if parent_a.cg_species_id == parent_b.cg_species_id
    return rand(2) == 0 ? parent_a.cg_species_id : parent_b.cg_species_id
  end

  def cg_breed_grade_loss(parent_a, parent_b)
    result = []
    count = defined?(ALBERT_CG::GRADE_STAT_COUNT) ? ALBERT_CG::GRADE_STAT_COUNT : 5
    max_loss = defined?(ALBERT_CG::GRADE_LOSS_MAX) ? ALBERT_CG::GRADE_LOSS_MAX : 4
    count.times do |index|
      a = parent_a.cg_grade_loss_at(index).to_i
      b = parent_b.cg_grade_loss_at(index).to_i
      value = rand(2) == 0 ? a : b
      roll = rand(100)
      value -= 1 if roll < 15
      value += 1 if roll >= 15 && roll < 35
      value = 0 if value < 0
      value = max_loss if value > max_loss
      result.push(value)
    end
    return result
  end

  def cg_breed_inherited_skill_ids(parent_a, parent_b, child)
    score = {}
    known_a = parent_a.skills.collect { |skill| skill.id }
    known_b = parent_b.skills.collect { |skill| skill.id }
    all_ids = (known_a + known_b).uniq
    for skill_id in all_ids
      begin
        already_known = child.skill_learn?($data_skills[skill_id])
      rescue
        already_known = false
      end
      next if already_known
      value = 0
      value += 1000 if known_a.include?(skill_id) && known_b.include?(skill_id)
      value += parent_a.cg_skill_use_count(skill_id) if parent_a.respond_to?(:cg_skill_use_count)
      value += parent_b.cg_skill_use_count(skill_id) if parent_b.respond_to?(:cg_skill_use_count)
      score[skill_id] = value
    end
    ordered = score.keys.sort do |a, b|
      compare = score[b] <=> score[a]
      compare = a <=> b if compare == 0
      compare
    end
    return ordered[0, ALBERT_CG::PET_BREED_INHERITED_SKILLS] || []
  end

  # 成功回傳子代個體，失敗回傳 nil。
  def cg_breed_pets(parent_a_id, parent_b_id)
    parent_a = $game_actors.cg_pet(parent_a_id.to_i)
    parent_b = $game_actors.cg_pet(parent_b_id.to_i)
    return nil if parent_a == nil || parent_b == nil
    return nil unless cg_breeding_pets.include?(parent_a) && cg_breeding_pets.include?(parent_b)
    return nil unless parent_a.cg_breed_compatible_with?(parent_b)
    return nil unless cg_breeding_capacity_available?

    species_id = cg_breed_child_species(parent_a, parent_b)
    actor_data = $data_actors[species_id]
    return nil if actor_data == nil
    child = $game_actors.cg_create_pet(species_id, 1, actor_data.name,
      ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID)
    return nil if child == nil

    grade_loss = cg_breed_grade_loss(parent_a, parent_b)
    child.instance_variable_set(:@cg_grade_loss, grade_loss)
    child.instance_variable_set(:@cg_bonus_points, Array.new(grade_loss.size, 0))
    inherited_ids = cg_breed_inherited_skill_ids(parent_a, parent_b, child)
    for skill_id in inherited_ids
      child.learn_skill(skill_id)
    end
    child.cg_setup_child_breeding_data(parent_a, parent_b, inherited_ids)
    child.cg_loyalty = (parent_a.cg_loyalty + parent_b.cg_loyalty) / 2 if child.respond_to?(:cg_loyalty=)
    child.recover_all

    unless cg_register_pet(child.id)
      $game_actors.cg_delete_pet(child.id)
      return nil
    end
    parent_a.cg_increment_breed_count
    parent_b.cg_increment_breed_count
    return child
  end
end

#==============================================================================
# ■ Window_CG_BreedPetList
#==============================================================================
class Window_CG_BreedPetList < Window_Selectable
  attr_reader :data

  def initialize
    super(0, 56, 240, 360)
    @data = []
    refresh
    self.index = 0
  end

  def refresh
    @data = $game_party.cg_breeding_pets
    @item_max = @data.size
    create_contents
    for i in 0...@item_max
      draw_item(i)
    end
  end

  def pet
    return nil if self.index < 0
    return @data[self.index]
  end

  def draw_item(index)
    pet = @data[index]
    return if pet == nil
    rect = item_rect(index)
    self.contents.clear_rect(rect)
    enabled = pet.cg_breed_available?
    disabled_index = defined?(ALBERT_CG::DISABLED_COMMAND_COLOR_INDEX) ?
      ALBERT_CG::DISABLED_COMMAND_COLOR_INDEX : 7
    self.contents.font.color = enabled ? normal_color : text_color(disabled_index)
    mark = pet.cg_breed_available? ? "◇" : "×"
    self.contents.draw_text(rect.x, rect.y, 24, rect.height, mark)
    self.contents.draw_text(rect.x + 24, rect.y, 128, rect.height, pet.name)
    self.contents.draw_text(rect.x + 152, rect.y, 58, rect.height, "Lv." + pet.level.to_s, 2)
  end
end

#==============================================================================
# ■ Window_CG_BreedDetail
#==============================================================================
class Window_CG_BreedDetail < Window_Base
  def initialize
    super(240, 56, 304, 250)
    @pet = nil
    @parent_a = nil
  end

  def set_data(pet, parent_a)
    return if @pet == pet && @parent_a == parent_a
    @pet = pet
    @parent_a = parent_a
    refresh
  end

  def refresh
    self.contents.clear
    return if @pet == nil
    self.contents.font.size = 16
    y = 0
    draw_line("個體 ID", @pet.id.to_s, y); y += 24
    draw_line("物種", @pet.actor.name, y); y += 24
    draw_line("等級／世代", @pet.level.to_s + "／G" + @pet.cg_generation.to_s, y); y += 24
    draw_line("配種次數", @pet.cg_breed_count.to_s + "／" + ALBERT_CG::PET_BREED_MAX_COUNT.to_s, y); y += 24
    group = @pet.cg_breed_group
    draw_line("配種群組", group == nil ? "不可配種" : group, y); y += 24
    grades = []
    count = defined?(ALBERT_CG::GRADE_STAT_COUNT) ? ALBERT_CG::GRADE_STAT_COUNT : 5
    count.times { |i| grades.push(@pet.cg_grade_loss_at(i).to_s) }
    draw_line("掉檔", grades.join("／"), y); y += 24
    location = $game_party.respond_to?(:cg_pet_location) ? $game_party.cg_pet_location(@pet.id) : nil
    location_text = location == :storage ? "倉庫" : "攜帶"
    draw_line("位置", location_text, y); y += 24
    if @parent_a != nil
      self.contents.font.color = system_color
      self.contents.draw_text(0, y, contents.width, 24, "第一親本：" + @parent_a.name + " #" + @parent_a.id.to_s)
    end
    self.contents.font.size = Font.default_size
  end

  def draw_line(label, value, y)
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 90, 24, label)
    self.contents.font.color = normal_color
    self.contents.draw_text(92, y, contents.width - 92, 24, value.to_s)
  end
end

#==============================================================================
# ■ Window_CG_BreedInfo
#==============================================================================
class Window_CG_BreedInfo < Window_Base
  def initialize
    super(240, 306, 304, 110)
    @text = "選擇第一親本。"
    refresh
  end

  def text=(value)
    @text = value.to_s
    refresh
  end

  def refresh
    self.contents.clear
    self.contents.font.size = 16
    lines = @text.to_s.split(/\n/)
    for i in 0...lines.size
      break if i * 24 + 24 > contents.height
      self.contents.draw_text(0, i * 24, contents.width, 24, lines[i])
    end
    self.contents.font.size = Font.default_size
  end
end

#==============================================================================
# ■ Scene_CG_PetBreeding
#==============================================================================
class Scene_CG_PetBreeding < Scene_Base
  def start
    super
    create_menu_background
    @parent_a = nil
    @title_window = Window_Base.new(0, 0, 544, 56)
    @title_window.contents.font.size = 18
    @title_window.contents.draw_text(0, 0, 512, Window_Base::WLH,
      "寵物配種　F3：開啟　C：選擇　B：返回")
    @list_window = Window_CG_BreedPetList.new
    @detail_window = Window_CG_BreedDetail.new
    @info_window = Window_CG_BreedInfo.new
    update_detail
  end

  def terminate
    super
    dispose_menu_background
    @title_window.dispose
    @list_window.dispose
    @detail_window.dispose
    @info_window.dispose
  end

  def update
    super
    update_menu_background
    @list_window.update
    update_detail
    if Input.trigger?(Input::B)
      if @parent_a != nil
        Sound.play_cancel
        @parent_a = nil
        @info_window.text = "已取消第一親本。\n請重新選擇第一親本。"
        @list_window.refresh
        update_detail
      else
        Sound.play_cancel
        $scene = Scene_Map.new
      end
    elsif Input.trigger?(Input::C)
      select_pet
    end
  end

  def update_detail
    @detail_window.set_data(@list_window.pet, @parent_a)
  end

  def select_pet
    pet = @list_window.pet
    if pet == nil || !pet.cg_breed_available?
      Sound.play_buzzer
      @info_window.text = "此個體目前不能配種。\n需存活、Lv." + ALBERT_CG::PET_BREED_MIN_LEVEL.to_s + "以上且次數未滿。"
      return
    end
    if @parent_a == nil
      Sound.play_decision
      @parent_a = pet
      @info_window.text = "第一親本：" + pet.name + " #" + pet.id.to_s + "\n請選擇第二親本。"
      @list_window.refresh
      update_detail
      return
    end
    if pet == @parent_a
      Sound.play_buzzer
      @info_window.text = "不能選擇同一個體作為雙親。"
      return
    end
    unless @parent_a.cg_breed_compatible_with?(pet)
      Sound.play_buzzer
      @info_window.text = "配種群組不相容。\n未設定群組時只能同物種配種。"
      return
    end
    unless $game_party.cg_breeding_capacity_available?
      Sound.play_buzzer
      @info_window.text = "攜帶名冊與寵物倉庫都已滿。"
      return
    end
    child = $game_party.cg_breed_pets(@parent_a.id, pet.id)
    if child == nil
      Sound.play_buzzer
      @info_window.text = "配種失敗，請檢查個體與容量。"
      return
    end
    Sound.play_decision
    destination = $game_party.respond_to?(:cg_pet_location) ? $game_party.cg_pet_location(child.id) : nil
    place = destination == :storage ? "寵物倉庫" : "攜帶名冊"
    skill_names = []
    for skill_id in child.cg_inherited_skill_ids
      skill = $data_skills[skill_id]
      skill_names.push(skill.name) if skill != nil
    end
    text = "孵化成功：" + child.name + " #" + child.id.to_s + "　G" + child.cg_generation.to_s
    text += "\n已加入" + place + "。"
    text += "　繼承：" + skill_names.join("、") unless skill_names.empty?
    @info_window.text = text
    @parent_a = nil
    @list_window.refresh
    update_detail
  end
end

#==============================================================================
# ■ Scene_Map
#==============================================================================
class Scene_Map < Scene_Base
  alias albert_cg_v12_breeding_update update
  def update
    albert_cg_v12_breeding_update
    return unless $scene == self
    if ALBERT_CG.cg_f3_trigger?
      Sound.play_decision
      $scene = Scene_CG_PetBreeding.new
    end
  end
end

#==============================================================================
# ■ Game_Interpreter
#==============================================================================
class Game_Interpreter
  def cg_open_pet_breeding
    $scene = Scene_CG_PetBreeding.new
    return true
  end

  def cg_breed_pets(parent_a_id, parent_b_id)
    child = $game_party.cg_breed_pets(parent_a_id, parent_b_id)
    return child == nil ? nil : child.id
  end

  def cg_make_breeding_test_pet(model_actor_id = 100)
    data = $data_actors[model_actor_id.to_i]
    return nil if data == nil
    pet = $game_actors.cg_create_pet(model_actor_id.to_i,
      ALBERT_CG::PET_BREED_MIN_LEVEL, data.name,
      ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID)
    return nil if pet == nil
    unless $game_party.cg_register_pet(pet.id)
      $game_actors.cg_delete_pet(pet.id)
      return nil
    end
    return pet.id
  end
end
