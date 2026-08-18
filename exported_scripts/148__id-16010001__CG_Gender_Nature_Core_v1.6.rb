# RMVX_SCRIPT_INDEX: 148
# RMVX_SCRIPT_ID: 16010001
# RMVX_SCRIPT_NAME: CG Gender Nature Core v1.6
# RMVX_SOURCE_SHA256: 1e1d889ef18bd84f2856f01eeaf533aaac83bd4e8e217f781ebe51bd9a4c58a2

#==============================================================================
# 【繁體中文說明】ALBERT CG 性別、寶可夢個性與配種限制核心
#------------------------------------------------------------------------------
# 【版本】v1.6
# 【適用】RPG Maker VX／RGSS2／Tankentai SBS 3.3
#
# 【設計來源】
#  本腳本參考 Jet10985 的「Pokemon Statistics System」之 Nature 概念，
#  但不直接覆蓋原專案能力公式，也不導入原腳本的 IV／EV。
#  本專案已經有掉檔、BP、進化與技能等級，因此只整合「個性」倍率，
#  避免同一項能力被兩套個體值系統重複計算。
#
# 【性別規則】
#  1. 性別保存於每一個 Game_Actor 個體，不隨進化改變。
#  2. 主角、隊友與隊友固定寵物可在設定表指定。
#  3. Clone 寵物、配種子代及未指定的普通 Actor 隨機決定。
#  4. 配種只接受同一進化系譜、不同個體、異性且可配種的 Clone 寵物。
#  5. :genderless（無性別）預設不可配種。
#
# 【個性規則】
#  1. 個性保存於個體，不隨進化、轉職或加入／離隊改變。
#  2. 個性只修正 ATK／DEF／SPI／AGI，HP／MP 不受影響。
#  3. 一般為某項 110%、另一項 90%；中性個性全部 100%。
#  4. VX 只有一項 SPI，同時代表特殊攻擊與特殊防禦，因此部分原作個性
#     會有相同效果；「馬虎、慎重」在本專案視為中性，避免同一 SPI 同時
#     增加又降低。
#
# 【指定設定】
#  ACTOR_IDENTITY_SETUP：主角／隊友 Actor ID => 性別、個性。
#  FIXED_PET_IDENTITY_SETUP：隊友固定寵物 Actor ID => 性別、個性。
#  未列入設定表者會在首次建立或讀取時隨機生成。
#
# 【事件指令】
#  cg_set_actor_gender(actor_id, :male)       # :male / :female / :genderless
#  cg_set_actor_nature(actor_id, :brave)      # 可用個性 key、中文名或 ID
#  cg_actor_gender(actor_id)                  # 回傳 Symbol
#  cg_actor_nature_id(actor_id)               # 回傳 0～24
#  cg_actor_nature_name(actor_id)             # 回傳繁體中文名稱
#
# 【配種維持規則】
#  - 同一進化系譜的不同型態可以互相配種。
#  - 子代固定回到該進化系譜第一型態。
#  - 本版保留既有最低等級、存活、容量與每個體最多 3 次限制。
#
# 【腳本位置】
#  放在 CG Pet Evolution v1.5 之後、Main 之前。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_GenderNature"] = true

module ALBERT_CG
  GENDER_NATURE_VERSION = "1.6"

  #--------------------------------------------------------------------------
  # ● 主角／隊友指定資料
  #--------------------------------------------------------------------------
  # 測試專案：Actor 1 Tom、Actor 2 Arwen。
  # 正式專案可繼續加入 Actor 3～6，不需改 Game_Actor 程式。
  # nature 可填 ID、key 或中文名，例如 2、:brave、"勇敢"。
  #--------------------------------------------------------------------------
  ACTOR_IDENTITY_SETUP = {
    1 => {:gender => :male,   :nature => :hardy},
    2 => {:gender => :female, :nature => :bold}
  }

  # 隊友固定寵物使用普通 Actor，因此必須獨立設定，不能套 Clone 隨機值。
  FIXED_PET_IDENTITY_SETUP = {
    103 => {:gender => :male, :nature => :brave}
  }

  # 每條進化系譜的雄性百分比。未設定預設 50。
  # 值可填 0～100，或 :genderless。
  # 會先將目前型態轉成進化系譜第一型態再查表。
  SPECIES_MALE_RATE = {
    # 100 => 875,  # 若未來需要 87.5%，可使用千分率 875
    # 150 => :genderless
  }

  #--------------------------------------------------------------------------
  # ● 25 種個性
  #--------------------------------------------------------------------------
  # 欄位：ID => [key, 中文名, ATK%, DEF%, SPI%, AGI%]
  # VX 只有單一 SPI，因此特攻／特防互換型個性需合併處理。
  #--------------------------------------------------------------------------
  NATURES = {
     0 => [:hardy,   "勤奮",   100, 100, 100, 100],
     1 => [:lonely,  "怕寂寞", 110,  90, 100, 100],
     2 => [:brave,   "勇敢",   110, 100, 100,  90],
     3 => [:adamant, "固執",   110, 100,  90, 100],
     4 => [:naughty, "頑皮",   110, 100,  90, 100],
     5 => [:bold,    "大膽",    90, 110, 100, 100],
     6 => [:docile,  "坦率",   100, 100, 100, 100],
     7 => [:relaxed, "悠閒",   100, 110, 100,  90],
     8 => [:impish,  "淘氣",   100, 110,  90, 100],
     9 => [:lax,     "樂天",   100, 110,  90, 100],
    10 => [:timid,   "膽小",    90, 100, 100, 110],
    11 => [:hasty,   "急躁",   100,  90, 100, 110],
    12 => [:serious, "認真",   100, 100, 100, 100],
    13 => [:jolly,   "爽朗",   100, 100,  90, 110],
    14 => [:naive,   "天真",   100, 100,  90, 110],
    15 => [:modest,  "內斂",    90, 100, 110, 100],
    16 => [:mild,    "慢吞吞", 100,  90, 110, 100],
    17 => [:quiet,   "冷靜",   100, 100, 110,  90],
    18 => [:bashful, "害羞",   100, 100, 100, 100],
    19 => [:rash,    "馬虎",   100, 100, 100, 100],
    20 => [:calm,    "溫和",    90, 100, 110, 100],
    21 => [:gentle,  "溫順",   100,  90, 110, 100],
    22 => [:sassy,   "自大",   100, 100, 110,  90],
    23 => [:careful, "慎重",   100, 100, 100, 100],
    24 => [:quirky,  "浮躁",   100, 100, 100, 100]
  }

  NATURE_STAT_INDEX = {
    :atk => 2,
    :def => 3,
    :spi => 4,
    :agi => 5
  }

  def self.normalize_gender(value)
    return :male if value == :male || value == :m || value == 0
    return :female if value == :female || value == :f || value == 1
    return :genderless if value == :genderless || value == :none || value == 2
    text = value.to_s.downcase
    return :male if ["male", "m", "男", "雄"].include?(text)
    return :female if ["female", "f", "女", "雌"].include?(text)
    return :genderless if ["genderless", "none", "無性別", "無"].include?(text)
    return nil
  end

  def self.nature_id(value)
    if value.is_a?(Integer)
      return value if NATURES.has_key?(value)
      return 0
    end
    text = value.to_s
    return text.to_i if text =~ /^\d+$/ && NATURES.has_key?(text.to_i)
    lower = text.downcase
    for id in NATURES.keys
      data = NATURES[id]
      return id if data[0].to_s.downcase == lower
      return id if data[1].to_s == text
    end
    return 0
  end

  def self.random_nature_id
    ids = NATURES.keys.sort
    return ids[rand(ids.size)]
  end

  def self.identity_setup_for(actor)
    return nil if actor == nil
    actor_id = actor.id.to_i
    if actor.respond_to?(:cg_pet?) && actor.cg_pet?
      return nil
    end
    data = FIXED_PET_IDENTITY_SETUP[actor_id]
    return data if data != nil
    return ACTOR_IDENTITY_SETUP[actor_id]
  end

  def self.gender_rate_for_actor(actor)
    return 500 if actor == nil
    species_id = if actor.respond_to?(:cg_evolution_base_form) && actor.respond_to?(:cg_evolution_pet?) && actor.cg_evolution_pet?
      actor.cg_evolution_base_form.to_i
    elsif actor.respond_to?(:cg_species_id) && actor.respond_to?(:cg_battle_pet?) && actor.cg_battle_pet?
      actor.cg_species_id.to_i
    else
      0
    end
    rate = SPECIES_MALE_RATE[species_id]
    return :genderless if rate == :genderless
    return 500 if rate == nil
    rate = rate.to_i
    rate *= 10 if rate >= 0 && rate <= 100
    rate = 0 if rate < 0
    rate = 1000 if rate > 1000
    return rate
  end

  def self.random_gender_for(actor)
    rate = gender_rate_for_actor(actor)
    return :genderless if rate == :genderless
    return rand(1000) < rate.to_i ? :male : :female
  end

  def self.gender_text(gender, pet = false)
    case normalize_gender(gender)
    when :male
      return pet ? "雄" : "男"
    when :female
      return pet ? "雌" : "女"
    else
      return "無性別"
    end
  end

  def self.gender_symbol(gender)
    case normalize_gender(gender)
    when :male; return "♂"
    when :female; return "♀"
    else; return "－"
    end
  end

  def self.apply_v16_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.6"
  end
end

#==============================================================================
# ■ Game_Actor：個體性別與個性
#==============================================================================
class Game_Actor < Game_Battler
  attr_reader :cg_gender
  attr_reader :cg_nature_id

  alias albert_cg_v16_identity_initialize initialize
  def initialize(*args)
    albert_cg_v16_identity_initialize(*args)
    cg_prepare_identity_data
  end

  def cg_prepare_identity_data
    setup = ALBERT_CG.identity_setup_for(self)
    if @cg_gender == nil
      configured = setup == nil ? nil : ALBERT_CG.normalize_gender(setup[:gender])
      @cg_gender = configured == nil ? ALBERT_CG.random_gender_for(self) : configured
    end
    if @cg_nature_id == nil
      configured = setup == nil ? nil : setup[:nature]
      @cg_nature_id = configured == nil ? ALBERT_CG.random_nature_id : ALBERT_CG.nature_id(configured)
    end
    @cg_nature_id = ALBERT_CG.nature_id(@cg_nature_id)
    return true
  end

  def cg_gender
    cg_prepare_identity_data if @cg_gender == nil
    return @cg_gender
  end

  def cg_gender=(value)
    normalized = ALBERT_CG.normalize_gender(value)
    return false if normalized == nil
    @cg_gender = normalized
    return true
  end

  def cg_nature_id
    cg_prepare_identity_data if @cg_nature_id == nil
    return @cg_nature_id.to_i
  end

  def cg_nature_id=(value)
    @cg_nature_id = ALBERT_CG.nature_id(value)
    return true
  end

  def cg_nature_data
    return ALBERT_CG::NATURES[cg_nature_id]
  end

  def cg_nature_key
    data = cg_nature_data
    return data == nil ? :hardy : data[0]
  end

  def cg_nature_name
    data = cg_nature_data
    return data == nil ? "勤奮" : data[1]
  end

  def cg_nature_rate(stat)
    data = cg_nature_data
    return 100 if data == nil
    index = ALBERT_CG::NATURE_STAT_INDEX[stat.to_sym]
    return 100 if index == nil
    return data[index].to_i
  end

  def cg_identity_pet?
    return respond_to?(:cg_battle_pet?) && cg_battle_pet?
  end

  def cg_gender_text
    return ALBERT_CG.gender_text(cg_gender, cg_identity_pet?)
  end

  def cg_gender_symbol
    return ALBERT_CG.gender_symbol(cg_gender)
  end

  def cg_identity_text
    return cg_gender_text + "／" + cg_nature_name
  end

  def cg_opposite_gender_with?(other)
    return false if other == nil || !other.respond_to?(:cg_gender)
    a = cg_gender
    b = other.cg_gender
    return false if a == :genderless || b == :genderless
    return a != b
  end

  # 個性只套用四項非 HP／MP 能力。此頁位於所有既有成長腳本之後，
  # 因此掉檔、BP、資料庫種族值與裝備先計算，再套 90／110%。
  alias albert_cg_v16_nature_base_atk base_atk
  def base_atk
    value = albert_cg_v16_nature_base_atk
    return [value.to_i * cg_nature_rate(:atk) / 100, 1].max
  end

  alias albert_cg_v16_nature_base_def base_def
  def base_def
    value = albert_cg_v16_nature_base_def
    return [value.to_i * cg_nature_rate(:def) / 100, 1].max
  end

  alias albert_cg_v16_nature_base_spi base_spi
  def base_spi
    value = albert_cg_v16_nature_base_spi
    return [value.to_i * cg_nature_rate(:spi) / 100, 1].max
  end

  alias albert_cg_v16_nature_base_agi base_agi
  def base_agi
    value = albert_cg_v16_nature_base_agi
    return [value.to_i * cg_nature_rate(:agi) / 100, 1].max
  end

  # 本版將配種範圍固定為同一進化系譜，不再允許外部群組跨系譜。
  if $imported["ALBERT_CG_PetBreeding"]
    def cg_breed_group
      return nil unless respond_to?(:cg_pet?) && cg_pet?
      current_id = respond_to?(:cg_current_form_actor_id) ? cg_current_form_actor_id.to_i : cg_species_id.to_i
      base_id = respond_to?(:cg_evolution_base_form) ? cg_evolution_base_form.to_i : current_id
      blocked = ALBERT_CG::PET_NO_BREED_SPECIES
      if blocked != nil
        return nil if blocked.include?(current_id) || blocked.include?(base_id)
      end
      return "lineage_" + base_id.to_s
    end

    alias albert_cg_v16_gender_breed_available cg_breed_available?
    def cg_breed_available?
      return false unless albert_cg_v16_gender_breed_available
      return false if cg_gender == :genderless
      return true
    end

    def cg_breed_compatible_with?(other)
      return false if other == nil || other == self
      return false unless other.respond_to?(:cg_pet?) && other.cg_pet?
      return false unless cg_breed_available? && other.cg_breed_available?
      return false unless cg_opposite_gender_with?(other)
      base_a = respond_to?(:cg_evolution_base_form) ? cg_evolution_base_form.to_i : cg_species_id.to_i
      base_b = other.respond_to?(:cg_evolution_base_form) ? other.cg_evolution_base_form.to_i : other.cg_species_id.to_i
      return base_a == base_b
    end
  end
end

#==============================================================================
# ■ Game_Party：子代固定回到系譜第一型態
#==============================================================================
class Game_Party < Game_Unit
  if $imported["ALBERT_CG_PetBreeding"]
    def cg_breed_child_species(parent_a, parent_b)
      species_id = if parent_a.respond_to?(:cg_evolution_base_form)
        parent_a.cg_evolution_base_form.to_i
      else
        parent_a.cg_species_id.to_i
      end
      return ALBERT_CG.evolution_base_form(species_id) if ALBERT_CG.respond_to?(:evolution_base_form)
      return species_id
    end
  end
end

#==============================================================================
# ■ F5 寵物詳細資料：顯示性別與個性
#==============================================================================
if defined?(Window_CG_PetDetail)
  class Window_CG_PetDetail < Window_Base
    def refresh
      self.contents.clear
      if @pet == nil
        self.contents.draw_text(0, 0, contents.width, WLH, "選擇一隻寵物")
        return
      end
      @pet.cg_prepare_pet_data if @pet.respond_to?(:cg_prepare_pet_data)
      @pet.cg_prepare_growth_data if @pet.respond_to?(:cg_prepare_growth_data)
      @pet.cg_prepare_identity_data
      self.contents.font.size = 16
      y = 0
      form_id = @pet.respond_to?(:cg_current_form_actor_id) ? @pet.cg_current_form_actor_id : @pet.cg_species_id
      cg_v08_detail_line(y, "個體／型態", @pet.id.to_s + "／" + form_id.to_s); y += 22
      cg_v08_detail_line(y, "性別／個性", @pet.cg_identity_text); y += 22
      bp = @pet.respond_to?(:cg_unspent_bp) ? @pet.cg_unspent_bp : 0
      cg_v08_detail_line(y, "等級／可用BP", @pet.level.to_s + "／" + bp.to_s); y += 22
      cg_v08_detail_line(y, "HP／MP", @pet.hp.to_s + "/" + @pet.maxhp.to_s + "　" + @pet.mp.to_s + "/" + @pet.maxmp.to_s); y += 22
      cg_v08_detail_line(y, "攻／防／精／敏", @pet.atk.to_s + "／" + @pet.def.to_s + "／" + @pet.spi.to_s + "／" + @pet.agi.to_s); y += 22
      points = []
      5.times { |i| points.push(@pet.cg_bonus_point(i).to_s) }
      cg_v08_detail_line(y, "配點 體力起", points.join("／")); y += 22
      grade_text = ALBERT_CG.respond_to?(:pet_grade_rank_text) ? ALBERT_CG.pet_grade_rank_text(@pet) : ""
      cg_v08_detail_line(y, "掉檔 體力起", grade_text); y += 22
      names = []
      for skill in @pet.skills
        level = @pet.respond_to?(:cg_skill_level) ? @pet.cg_skill_level(skill.id) : 1
        names.push(skill.name + " Lv." + level.to_s)
      end
      cg_v08_detail_line(y, "技能", names.join("、"))
      self.contents.font.size = Font.default_size
    end
  end
end

#==============================================================================
# ■ F4 人物詳細資料：顯示指定性別與個性
#==============================================================================
if defined?(Window_CG_DevelopmentDetail)
  class Window_CG_DevelopmentDetail < Window_Base
    def refresh
      self.contents.clear
      return self.contents.draw_text(0, 0, contents.width, WLH, "選擇一名角色") if @actor == nil
      @actor.cg_prepare_identity_data
      self.contents.font.size = 18
      draw_actor_graphic(@actor, 264, 52)
      y = 0
      draw_line(y, "類型", @actor.cg_growth_role_name); y += 24
      draw_line(y, "性別／個性", @actor.cg_identity_text); y += 24
      draw_line(y, "等級／BP", @actor.level.to_s + "／" + @actor.cg_growth_unspent_bp.to_s); y += 24
      draw_line(y, "HP／MP", @actor.hp.to_s + "/" + @actor.maxhp.to_s + "　" + @actor.mp.to_s + "/" + @actor.maxmp.to_s); y += 24
      draw_line(y, "攻防精敏", @actor.atk.to_s + "／" + @actor.def.to_s + "／" + @actor.spi.to_s + "／" + @actor.agi.to_s); y += 24
      if @actor.respond_to?(:cg_job_human?) && @actor.cg_job_human?
        draw_line(y, "職業", ALBERT_CG.job_name(@actor.class_id)); y += 24
        draw_line(y, "階級", @actor.cg_job_rank_name)
      else
        values = []
        5.times { |i| values.push(@actor.cg_growth_bonus_point(i).to_s) }
        draw_line(y, "配點", values.join("／"))
      end
      self.contents.font.size = Font.default_size
    end
  end
end

#==============================================================================
# ■ F3 配種 UI：顯示性別、個性與系譜
#==============================================================================
if defined?(Window_CG_BreedPetList)
  class Window_CG_BreedPetList < Window_Selectable
    def draw_item(index)
      pet = @data[index]
      return if pet == nil
      rect = item_rect(index)
      self.contents.clear_rect(rect)
      enabled = pet.cg_breed_available?
      disabled_index = defined?(ALBERT_CG::DISABLED_COMMAND_COLOR_INDEX) ?
        ALBERT_CG::DISABLED_COMMAND_COLOR_INDEX : 7
      self.contents.font.color = enabled ? normal_color : text_color(disabled_index)
      mark = enabled ? "◇" : "×"
      self.contents.draw_text(rect.x, rect.y, 22, rect.height, mark)
      self.contents.draw_text(rect.x + 22, rect.y, 112, rect.height, pet.name)
      self.contents.draw_text(rect.x + 134, rect.y, 22, rect.height, pet.cg_gender_symbol, 1)
      self.contents.draw_text(rect.x + 156, rect.y, 52, rect.height, "Lv." + pet.level.to_s, 2)
    end
  end
end

if defined?(Window_CG_BreedDetail)
  class Window_CG_BreedDetail < Window_Base
    def refresh
      self.contents.clear
      return if @pet == nil
      @pet.cg_prepare_identity_data
      self.contents.font.size = 16
      y = 0
      draw_line("個體 ID", @pet.id.to_s, y); y += 24
      draw_line("目前型態", @pet.actor.name, y); y += 24
      draw_line("性別／個性", @pet.cg_identity_text, y); y += 24
      draw_line("等級／世代", @pet.level.to_s + "／G" + @pet.cg_generation.to_s, y); y += 24
      draw_line("配種次數", @pet.cg_breed_count.to_s + "／" + ALBERT_CG::PET_BREED_MAX_COUNT.to_s, y); y += 24
      base_id = @pet.respond_to?(:cg_evolution_base_form) ? @pet.cg_evolution_base_form : @pet.cg_species_id
      base_name = ALBERT_CG.respond_to?(:evolution_form_name) ? ALBERT_CG.evolution_form_name(base_id) : base_id.to_s
      draw_line("進化系譜", base_name, y); y += 24
      grade_text = ALBERT_CG.respond_to?(:pet_grade_rank_text) ? ALBERT_CG.pet_grade_rank_text(@pet) : ""
      draw_line("掉檔", grade_text, y); y += 24
      location = $game_party.respond_to?(:cg_pet_location) ? $game_party.cg_pet_location(@pet.id) : nil
      draw_line("位置", location == :storage ? "倉庫" : "攜帶", y); y += 24
      if @parent_a != nil
        self.contents.font.color = system_color
        text = "第一親本：" + @parent_a.name + " " + @parent_a.cg_gender_symbol
        self.contents.draw_text(0, y, contents.width, 24, text)
      end
      self.contents.font.size = Font.default_size
    end
  end
end

if defined?(Scene_CG_PetBreeding)
  class Scene_CG_PetBreeding < Scene_Base
    def select_pet
      pet = @list_window.pet
      if pet == nil || !pet.cg_breed_available?
        Sound.play_buzzer
        @info_window.text = "此個體目前不能配種。\n需存活、異性別資格、Lv." + ALBERT_CG::PET_BREED_MIN_LEVEL.to_s + "以上且次數未滿。"
        return
      end
      if @parent_a == nil
        Sound.play_decision
        @parent_a = pet
        @info_window.text = "第一親本：" + pet.name + " " + pet.cg_gender_symbol + " #" + pet.id.to_s + "\n請選擇同系譜的異性第二親本。"
        @list_window.refresh
        update_detail
        return
      end
      if pet == @parent_a
        Sound.play_buzzer
        @info_window.text = "不能選擇同一個體作為雙親。"
        return
      end
      unless @parent_a.cg_opposite_gender_with?(pet)
        Sound.play_buzzer
        @info_window.text = "同性別或無性別個體無法配對。"
        return
      end
      base_a = @parent_a.respond_to?(:cg_evolution_base_form) ? @parent_a.cg_evolution_base_form : @parent_a.cg_species_id
      base_b = pet.respond_to?(:cg_evolution_base_form) ? pet.cg_evolution_base_form : pet.cg_species_id
      if base_a.to_i != base_b.to_i
        Sound.play_buzzer
        @info_window.text = "進化系譜不相同。\n只有同一系譜的不同型態可以配種。"
        return
      end
      unless @parent_a.cg_breed_compatible_with?(pet)
        Sound.play_buzzer
        @info_window.text = "此組合目前不符合配種條件。"
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
      child.cg_prepare_identity_data
      Sound.play_decision
      destination = $game_party.respond_to?(:cg_pet_location) ? $game_party.cg_pet_location(child.id) : nil
      place = destination == :storage ? "寵物倉庫" : "攜帶名冊"
      skill_names = []
      for skill_id in child.cg_inherited_skill_ids
        skill = $data_skills[skill_id]
        skill_names.push(skill.name) if skill != nil
      end
      text = "孵化成功：" + child.name + " " + child.cg_gender_symbol + "／" + child.cg_nature_name
      text += "　#" + child.id.to_s + "　G" + child.cg_generation.to_s
      text += "\n已加入" + place + "。"
      text += "　繼承：" + skill_names.join("、") unless skill_names.empty?
      @info_window.text = text
      @parent_a = nil
      @list_window.refresh
      update_detail
    end
  end
end

#==============================================================================
# ■ 事件指令與標題
#==============================================================================
class Game_Interpreter
  def cg_set_actor_gender(actor_id, gender)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil || !actor.respond_to?(:cg_gender=)
    return actor.send(:cg_gender=, gender)
  end

  def cg_set_actor_nature(actor_id, nature)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil || !actor.respond_to?(:cg_nature_id=)
    actor.cg_nature_id = nature
    return true
  end

  def cg_actor_gender(actor_id)
    actor = $game_actors[actor_id.to_i]
    return nil if actor == nil || !actor.respond_to?(:cg_gender)
    return actor.cg_gender
  end

  def cg_actor_nature_id(actor_id)
    actor = $game_actors[actor_id.to_i]
    return nil if actor == nil || !actor.respond_to?(:cg_nature_id)
    return actor.cg_nature_id
  end

  def cg_actor_nature_name(actor_id)
    actor = $game_actors[actor_id.to_i]
    return "" if actor == nil || !actor.respond_to?(:cg_nature_name)
    return actor.cg_nature_name
  end

  # 建立同系譜、指定異性的快速測試雙親。成功回傳 [雄個體ID, 雌個體ID]。
  def cg_make_identity_test_pair(model_actor_id = 100)
    return nil unless respond_to?(:cg_make_breeding_test_pet)
    male_id = cg_make_breeding_test_pet(model_actor_id)
    return nil if male_id == nil
    female_id = cg_make_breeding_test_pet(model_actor_id)
    return nil if female_id == nil
    male = $game_actors[male_id]
    female = $game_actors[female_id]
    male.send(:cg_gender=, :male) if male != nil
    female.send(:cg_gender=, :female) if female != nil
    return [male_id, female_id]
  end
end

class Scene_Title < Scene_Base
  alias albert_cg_v16_identity_load_database load_database
  def load_database
    albert_cg_v16_identity_load_database
    ALBERT_CG.apply_v16_title
  end

  alias albert_cg_v16_identity_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v16_identity_load_bt_database
    ALBERT_CG.apply_v16_title
  end
end
