# RMVX_SCRIPT_INDEX: 147
# RMVX_SCRIPT_ID: 15010001
# RMVX_SCRIPT_NAME: CG Pet Evolution v1.5
# RMVX_SOURCE_SHA256: 42292abcbcb463438dea06285621ca60be3a4398ad954ad2119af4510487e1df

#==============================================================================
# 【繁體中文說明】ALBERT CG 寵物進化與個體型態核心
#------------------------------------------------------------------------------
# 【版本】v1.5
# 【適用】RPG Maker VX / RGSS2 / Tankentai SBS 3.3
#
# 【核心規則】
#  1. 進化不會建立新 Actor 個體，也不會更換個體 ID。
#  2. 進化後會更換資料庫型態 Actor，因此名稱、臉圖、行走圖、戰鬥圖、
#     Class 與種族能力值會立即改變。
#  3. 掉檔、BP、技能欄內容、技能等級、技能熟練度、技能使用統計、忠誠、
#     傷勢、親本、世代與配種次數均保留。
#  4. 主角 Clone 寵物與隊友固定普通 Actor 寵物都能使用同一套進化資料。
#  5. 寵物不會因升級自動學習技能；進化本身也不會額外贈送技能。
#
# 【測試快捷鍵】
#  地圖按實體鍵盤 F10：開啟寵物進化管理。
#  C：進化符合條件的個體。
#  A（Shift）：測試用，將目前個體補到下一階段所需等級。
#  B：返回地圖。
#
# 【設定位置】
#  EVOLUTION_RULES：目前型態 => 下一型態、需求等級。
#  EVOLUTION_LINEAGES：每條進化系譜包含的 Actor ID，第一個 ID 為初始型態。
#
# 【事件／腳本指令】
#  cg_open_pet_evolution
#  cg_pet_evolution_ready?(actor_id)
#  cg_evolve_pet(actor_id)                     # 符合條件才進化
#  cg_force_pet_form(actor_id, form_actor_id)   # 劇情／測試強制切換型態
#  cg_prepare_evolution_test(actor_id)          # 補到下一階段需求等級
#
# 【VX 相容性】
#  本腳本不讀取 RPG::Actor 或 RPG::Class 的 Note。所有規則集中於腳本常數。
#  RGSS2 Input 沒有 Input::F10，因此使用 Win32API 偵測實體 F10。
#
# 【腳本位置】
#  放在 CG Pet Breeding、CG Skill Merchant 之後，Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PetEvolution"] = true

module ALBERT_CG
  PET_EVOLUTION_VERSION = "1.5"

  # 原型測試採低等級門檻，方便直接驗證兩段進化。
  # 正式資料只需修改 :level，不必改存檔結構。
  EVOLUTION_RULES = {
    100 => {:to=>101, :level=>5},
    101 => {:to=>102, :level=>10},
    103 => {:to=>104, :level=>5},
    104 => {:to=>105, :level=>10},
    106 => {:to=>107, :level=>16},
    107 => {:to=>108, :level=>36}
  }

  EVOLUTION_LINEAGES = {
    100 => [100, 101, 102],
    103 => [103, 104, 105],
    106 => [106, 107, 108]
  }

  # v1.5 原型用進化型態。正式專案可改由資料庫建立相同 Actor ID。
  # 格式：[名稱, Class ID, 行走圖, 臉圖, [HP, MP, ATK, DEF, SPI, AGI]]
  EVOLUTION_TEST_FORMS = {
    101 => ["妙蛙草", 100, "$Actor12_2", "Actor12", [60, 60, 62, 63, 80, 60]],
    102 => ["妙蛙花", 100, "$Actor12_3", "Actor12", [80, 80, 82, 83, 100, 80]],
    104 => ["火恐龍", 101, "$Actor22_1", "Actor22", [58, 58, 64, 58, 65, 80]],
    105 => ["噴火龍", 101, "$Actor22_3", "Actor22", [78, 78, 84, 78, 85, 100]],
    107 => ["卡咪龜", 102, "$Actor26_1", "Actor26", [59, 54, 63, 80, 72, 58]],
    108 => ["水箭龜", 102, "$Actor26_3", "Actor26", [79, 71, 83, 100, 95, 78]]
  }

  CG_VK_F10 = 0x79 unless const_defined?(:CG_VK_F10)
  begin
    CG_GET_ASYNC_KEY_STATE_F10 = Win32API.new("user32", "GetAsyncKeyState", "i", "i") unless const_defined?(:CG_GET_ASYNC_KEY_STATE_F10)
  rescue
    CG_GET_ASYNC_KEY_STATE_F10 = nil unless const_defined?(:CG_GET_ASYNC_KEY_STATE_F10)
  end

  def self.cg_f10_trigger?
    return false if CG_GET_ASYNC_KEY_STATE_F10 == nil
    down = (CG_GET_ASYNC_KEY_STATE_F10.call(CG_VK_F10) & 0x8000) != 0
    trigger = down && @cg_f10_was_down != true
    @cg_f10_was_down = down
    return trigger
  rescue
    return false
  end

  def self.evolution_rule(species_id)
    return EVOLUTION_RULES[species_id.to_i]
  end

  def self.evolution_next_form(species_id)
    rule = evolution_rule(species_id)
    return nil if rule == nil
    return rule[:to].to_i
  end

  def self.evolution_required_level(species_id)
    rule = evolution_rule(species_id)
    return 0 if rule == nil
    return [rule[:level].to_i, 1].max
  end

  def self.evolution_lineage(species_id)
    species_id = species_id.to_i
    for base_id in EVOLUTION_LINEAGES.keys
      forms = EVOLUTION_LINEAGES[base_id]
      return forms if forms.include?(species_id)
    end
    return [species_id]
  end

  def self.evolution_base_form(species_id)
    forms = evolution_lineage(species_id)
    return forms.empty? ? species_id.to_i : forms[0].to_i
  end

  def self.evolution_stage(species_id)
    forms = evolution_lineage(species_id)
    index = forms.index(species_id.to_i)
    return index == nil ? 1 : index + 1
  end

  def self.evolution_form_name(species_id)
    data = $data_actors == nil ? nil : $data_actors[species_id.to_i]
    return data == nil ? "未知型態" : data.name.to_s
  end

  def self.apply_v15_evolution_test_data
    return if $data_actors == nil
    return unless defined?(ALBERT_CG::TEST_DATA)
    for actor_id in EVOLUTION_TEST_FORMS.keys
      data = EVOLUTION_TEST_FORMS[actor_id]
      ALBERT_CG::TEST_DATA.ensure_index($data_actors, actor_id)
      $data_actors[actor_id] = ALBERT_CG::TEST_DATA.make_actor(actor_id, data)
    end
  end

  def self.apply_v15_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.5"
  end
end

#==============================================================================
# ■ Game_Actor
#==============================================================================
class Game_Actor < Game_Battler
  # 固定普通 Actor 寵物需要保留原 Actor ID 給主人配對，因此以型態覆寫讀取
  # 資料庫 Actor；Clone 寵物也使用相同欄位，個體 ID 完全不變。
  alias albert_cg_v15_evolution_actor actor
  def actor
    if @cg_evolution_form_actor_id != nil
      data = $data_actors[@cg_evolution_form_actor_id.to_i]
      return data if data != nil
    end
    return albert_cg_v15_evolution_actor
  end

  alias albert_cg_v15_evolution_database_actor_id cg_database_actor_id
  def cg_database_actor_id
    if cg_evolution_pet? && @cg_evolution_form_actor_id != nil
      return @cg_evolution_form_actor_id.to_i
    end
    return albert_cg_v15_evolution_database_actor_id
  end

  alias albert_cg_v15_evolution_model_actor_id cg_model_actor_id
  def cg_model_actor_id
    if respond_to?(:cg_pet?) && cg_pet? && @cg_evolution_form_actor_id != nil
      return @cg_evolution_form_actor_id.to_i
    end
    return albert_cg_v15_evolution_model_actor_id
  end

  def cg_evolution_pet?
    return true if respond_to?(:cg_pet?) && cg_pet?
    return true if respond_to?(:cg_fixed_partner_pet?) && cg_fixed_partner_pet?
    return false
  end

  def cg_current_form_actor_id
    return cg_database_actor_id.to_i
  end

  def cg_evolution_lineage
    return ALBERT_CG.evolution_lineage(cg_current_form_actor_id)
  end

  def cg_evolution_base_form
    return ALBERT_CG.evolution_base_form(cg_current_form_actor_id)
  end

  def cg_evolution_stage
    return ALBERT_CG.evolution_stage(cg_current_form_actor_id)
  end

  def cg_evolution_next_form
    return ALBERT_CG.evolution_next_form(cg_current_form_actor_id)
  end

  def cg_evolution_required_level
    return ALBERT_CG.evolution_required_level(cg_current_form_actor_id)
  end

  def cg_evolution_ready?
    return false unless cg_evolution_pet?
    next_id = cg_evolution_next_form
    return false if next_id == nil || next_id <= 0
    return false if $data_actors[next_id] == nil
    return @level.to_i >= cg_evolution_required_level
  end

  def cg_evolution_history
    @cg_evolution_history = [] if @cg_evolution_history == nil
    return @cg_evolution_history
  end

  # 符合條件時進化。force=true 供劇情或測試直接切換指定型態。
  def cg_evolve_to(form_actor_id = nil, force = false)
    return false unless cg_evolution_pet?
    current_id = cg_current_form_actor_id
    if form_actor_id == nil
      form_actor_id = cg_evolution_next_form
    end
    form_actor_id = form_actor_id.to_i
    return false if form_actor_id <= 0 || form_actor_id == current_id
    new_data = $data_actors[form_actor_id]
    return false if new_data == nil

    unless force
      rule = ALBERT_CG.evolution_rule(current_id)
      return false if rule == nil
      return false unless rule[:to].to_i == form_actor_id
      return false if @level.to_i < [rule[:level].to_i, 1].max
    end

    old_maxhp = [maxhp.to_i, 1].max
    old_maxmp = [maxmp.to_i, 1].max
    old_hp = hp.to_i
    old_mp = mp.to_i
    old_exp = @exp.to_i

    cg_evolution_history.push(current_id)
    @cg_evolution_form_actor_id = form_actor_id
    @name = new_data.name.to_s
    @character_name = new_data.character_name
    @character_index = new_data.character_index
    @face_name = new_data.face_name
    @face_index = new_data.face_index
    @class_id = new_data.class_id

    # 型態可以有不同經驗曲線，但個體的等級與當前進度盡量保留。
    @exp_list = Array.new(101)
    make_exp_list
    min_exp = @exp_list[@level] == nil ? 0 : @exp_list[@level]
    next_exp = @level >= 99 ? 0 : @exp_list[@level + 1]
    @exp = [old_exp, min_exp].max
    if next_exp != nil && next_exp > 0 && @exp >= next_exp
      @exp = next_exp - 1
    end

    # 依新種族值按比例保留 HP／MP；瀕死個體仍保持瀕死。
    self.hp = old_hp <= 0 ? 0 : [[old_hp * maxhp / old_maxhp, 1].max, maxhp].min
    self.mp = [[old_mp * maxmp / old_maxmp, 0].max, maxmp].min

    # 只同步技能欄容量，不學習、不遺忘任何技能。
    cg_prepare_skill_slot_data if respond_to?(:cg_prepare_skill_slot_data)
    return true
  end

  def cg_evolve
    return cg_evolve_to(nil, false)
  end

  def cg_prepare_evolution_test_level
    return false unless cg_evolution_pet?
    need = cg_evolution_required_level
    return false if need <= 0
    change_level(need, false) if @level.to_i < need
    return true
  end

  # 進化後仍視為同一進化系譜配種；子代由配種核心回到初始型態。
  if $imported["ALBERT_CG_PetBreeding"]
    alias albert_cg_v15_evolution_breed_group cg_breed_group
    def cg_breed_group
      return albert_cg_v15_evolution_breed_group unless respond_to?(:cg_pet?) && cg_pet?
      current_id = cg_current_form_actor_id
      base_id = cg_evolution_base_form
      blocked = ALBERT_CG::PET_NO_BREED_SPECIES
      if blocked != nil
        return nil if blocked.include?(current_id) || blocked.include?(base_id)
      end
      groups = ALBERT_CG::PET_BREED_GROUPS
      group = nil
      group = groups[current_id] if groups != nil
      group = groups[base_id] if group == nil && groups != nil
      return "species_" + base_id.to_s if group == nil || group.to_s.strip == ""
      return group.to_s.strip.downcase
    end
  end
end

#==============================================================================
# ■ Game_Party
#==============================================================================
class Game_Party < Game_Unit
  def cg_evolution_pets
    result = []
    if respond_to?(:cg_carried_pets)
      for pet in cg_carried_pets
        result.push(pet) if pet != nil && !result.include?(pet)
      end
    end
    if respond_to?(:cg_storage_pets)
      for pet in cg_storage_pets
        result.push(pet) if pet != nil && !result.include?(pet)
      end
    end
    if result.empty? && respond_to?(:cg_owned_pets)
      for pet in cg_owned_pets
        result.push(pet) if pet != nil && !result.include?(pet)
      end
    end

    # 只列出目前已加入隊伍之隊友的固定普通 Actor 寵物。
    if respond_to?(:cg_prepare_fixed_partner_pet_data)
      map = cg_prepare_fixed_partner_pet_data
      for owner_id in map.keys
        owner = $game_actors[owner_id]
        next if owner == nil || !members.include?(owner)
        pet = $game_actors[map[owner_id]]
        result.push(pet) if pet != nil && !result.include?(pet)
      end
    end
    return result
  end

  def cg_evolution_pet_location_label(pet)
    return "" if pet == nil
    if pet.respond_to?(:cg_pet?) && pet.cg_pet?
      if respond_to?(:cg_pet_location)
        location = cg_pet_location(pet.id)
        return "攜帶" if location == :carried
        return "倉庫" if location == :storage
      end
      return "主角寵物"
    end
    return "隊友固定"
  end

  if $imported["ALBERT_CG_PetBreeding"]
    alias albert_cg_v15_evolution_breed_child_species cg_breed_child_species
    def cg_breed_child_species(parent_a, parent_b)
      species_id = albert_cg_v15_evolution_breed_child_species(parent_a, parent_b)
      return ALBERT_CG.evolution_base_form(species_id)
    end
  end
end

#==============================================================================
# ■ 進化管理視窗
#==============================================================================
class Window_CG_EvolutionPetList < Window_Selectable
  attr_reader :data

  def initialize
    super(0, 56, 240, 360)
    @column_max = 1
    @data = []
    refresh
    self.index = 0
  end

  def refresh
    @data = $game_party.cg_evolution_pets
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
    marker = pet.cg_evolution_ready? ? "◆" : "　"
    self.contents.font.color = normal_color
    self.contents.draw_text(rect.x + 2, rect.y, 22, rect.height, marker)
    self.contents.draw_text(rect.x + 24, rect.y, 132, rect.height, pet.name.to_s)
    self.contents.draw_text(rect.x + 156, rect.y, 52, rect.height,
      "Lv." + pet.level.to_s, 2)
  end
end

class Window_CG_EvolutionDetail < Window_Base
  attr_accessor :message

  def initialize
    super(240, 56, 304, 360)
    @pet = nil
    @message = ""
  end

  def pet=(pet)
    return if @pet == pet && @last_message == @message
    @pet = pet
    refresh
  end

  def refresh
    self.contents.clear
    @last_message = @message
    if @pet == nil
      self.contents.draw_text(0, 0, contents.width, Window_Base::WLH,
        "沒有可管理的寵物。", 1)
      return
    end

    self.contents.font.size = 18
    self.contents.font.color = system_color
    self.contents.draw_text(0, 0, 170, 24, @pet.name.to_s)
    self.contents.font.size = 16
    self.contents.font.color = normal_color
    begin
      draw_character(@pet.character_name, @pet.character_index, 242, 64)
    rescue
    end

    y = 34
    draw_evolution_line(y, "類型", $game_party.cg_evolution_pet_location_label(@pet)); y += 24
    draw_evolution_line(y, "個體 ID", @pet.id.to_s); y += 24
    draw_evolution_line(y, "目前等級", "Lv." + @pet.level.to_s); y += 24
    draw_evolution_line(y, "目前型態", ALBERT_CG.evolution_form_name(@pet.cg_current_form_actor_id)); y += 24
    draw_evolution_line(y, "進化階段", @pet.cg_evolution_stage.to_s + "／" + @pet.cg_evolution_lineage.size.to_s); y += 24

    next_id = @pet.cg_evolution_next_form
    if next_id == nil
      draw_evolution_line(y, "下一型態", "已是最終型態"); y += 24
    else
      draw_evolution_line(y, "下一型態", ALBERT_CG.evolution_form_name(next_id)); y += 24
      draw_evolution_line(y, "進化條件", "Lv." + @pet.cg_evolution_required_level.to_s); y += 24
      status = @pet.cg_evolution_ready? ? "可以進化" : "尚未達成"
      draw_evolution_line(y, "目前狀態", status); y += 24
    end

    self.contents.font.color = system_color
    self.contents.draw_text(0, 232, contents.width, 22, "保留資料")
    self.contents.font.color = normal_color
    self.contents.font.size = 14
    self.contents.draw_text(0, 254, contents.width, 20,
      "掉檔、BP、技能／等級／熟練度、世代與親本")
    self.contents.draw_text(0, 274, contents.width, 20,
      "個體 ID 不變；名稱、圖像與種族值改為新型態")

    self.contents.font.size = 15
    self.contents.font.color = @message.to_s == "" ? normal_color : crisis_color
    text = @message.to_s == "" ? "C：進化　A：測試補等級　B：返回" : @message.to_s
    self.contents.draw_text(0, 304, contents.width, 22, text, 1)
  end

  def draw_evolution_line(y, label, value)
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 86, 22, label)
    self.contents.font.color = normal_color
    self.contents.draw_text(88, y, contents.width - 88, 22, value.to_s)
  end
end

#==============================================================================
# ■ Scene_CG_PetEvolution
#==============================================================================
class Scene_CG_PetEvolution < Scene_Base
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
    @title_window.contents.draw_text(0, 0, 512, Window_Base::WLH,
      "寵物進化管理　F10 開啟")
    @list_window = Window_CG_EvolutionPetList.new
    @detail_window = Window_CG_EvolutionDetail.new
    update_detail(true)
  end

  def terminate
    super
    dispose_menu_background
    @title_window.dispose if @title_window != nil
    @list_window.dispose if @list_window != nil
    @detail_window.dispose if @detail_window != nil
  end

  def update
    super
    update_menu_background
    @list_window.update
    update_detail(false)
    if Input.trigger?(Input::B)
      Sound.play_cancel
      $scene = Scene_Map.new
      return
    end
    if Input.trigger?(Input::A)
      prepare_test_level
      return
    end
    evolve_selected_pet if Input.trigger?(Input::C)
  end

  def update_detail(force = false)
    pet = @list_window.pet
    if force || @detail_pet != pet
      @detail_pet = pet
      @detail_window.message = ""
      @detail_window.pet = pet
    end
  end

  def prepare_test_level
    pet = @list_window.pet
    if pet == nil || pet.cg_evolution_next_form == nil
      Sound.play_buzzer
      @detail_window.message = "此個體沒有下一階段。"
      @detail_window.refresh
      return
    end
    if pet.cg_prepare_evolution_test_level
      Sound.play_decision
      @list_window.refresh
      @detail_window.message = "已補到進化所需等級。"
      @detail_window.refresh
    else
      Sound.play_buzzer
    end
  end

  def evolve_selected_pet
    pet = @list_window.pet
    if pet == nil
      Sound.play_buzzer
      return
    end
    next_id = pet.cg_evolution_next_form
    if next_id == nil
      Sound.play_buzzer
      @detail_window.message = "已是最終型態。"
      @detail_window.refresh
      return
    end
    unless pet.cg_evolution_ready?
      Sound.play_buzzer
      @detail_window.message = "需要 Lv." + pet.cg_evolution_required_level.to_s + "。"
      @detail_window.refresh
      return
    end
    old_name = pet.name.to_s
    if pet.cg_evolve
      Sound.play_decision
      $game_player.refresh if $game_player != nil
      @list_window.refresh
      @detail_pet = nil
      update_detail(true)
      @detail_window.message = old_name + "進化成" + pet.name.to_s + "！"
      @detail_window.refresh
    else
      Sound.play_buzzer
      @detail_window.message = "進化失敗，請檢查型態設定。"
      @detail_window.refresh
    end
  end
end

#==============================================================================
# ■ Scene_Map / Game_Interpreter / Scene_Title
#==============================================================================
class Scene_Map < Scene_Base
  alias albert_cg_v15_evolution_scene_map_update update
  def update
    albert_cg_v15_evolution_scene_map_update
    return unless $scene == self
    if ALBERT_CG.cg_f10_trigger? && !$game_temp.in_battle
      Sound.play_decision
      snapshot_for_background
      $scene = Scene_CG_PetEvolution.new
    end
  end
end

class Game_Interpreter
  def cg_open_pet_evolution
    $scene.snapshot_for_background if $scene.respond_to?(:snapshot_for_background)
    $scene = Scene_CG_PetEvolution.new
    return true
  end

  def cg_pet_evolution_ready?(actor_id)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil || !actor.respond_to?(:cg_evolution_ready?)
    return actor.cg_evolution_ready?
  end

  def cg_evolve_pet(actor_id)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil || !actor.respond_to?(:cg_evolve)
    result = actor.cg_evolve
    $game_player.refresh if result && $game_player != nil
    return result
  end

  def cg_force_pet_form(actor_id, form_actor_id)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil || !actor.respond_to?(:cg_evolve_to)
    result = actor.cg_evolve_to(form_actor_id.to_i, true)
    $game_player.refresh if result && $game_player != nil
    return result
  end

  def cg_prepare_evolution_test(actor_id)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil || !actor.respond_to?(:cg_prepare_evolution_test_level)
    return actor.cg_prepare_evolution_test_level
  end
end

class Scene_Title < Scene_Base
  alias albert_cg_v15_evolution_load_database load_database
  def load_database
    albert_cg_v15_evolution_load_database
    ALBERT_CG.apply_v15_evolution_test_data
    ALBERT_CG.apply_v15_title
  end

  alias albert_cg_v15_evolution_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v15_evolution_load_bt_database
    ALBERT_CG.apply_v15_evolution_test_data
    ALBERT_CG.apply_v15_title
  end
end
