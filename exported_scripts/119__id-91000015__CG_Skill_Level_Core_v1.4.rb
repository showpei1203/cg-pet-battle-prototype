# RMVX_SCRIPT_INDEX: 119
# RMVX_SCRIPT_ID: 91000015
# RMVX_SCRIPT_NAME: CG Skill Level Core v1.4
# RMVX_SOURCE_SHA256: 85866424a4acb4c0d0a0894209d9e477a3277a336197f61bd0aacd4ce55503d9

#==============================================================================
# 【繁體中文說明】ALBERT CG 人類／寵物技能等級與熟練度核心
#------------------------------------------------------------------------------
# 【版本】v1.4
# 【適用】RPG Maker VX / RGSS2 / Tankentai SBS 3.3
#
# 【正式規則】
#  1. 人物與寵物都不會因角色等級提升而自動學會技能。
#  2. 人類技能商人只教授 Lv.1；人類使用技能時累積熟練度並升級。
#  3. 寵物技能商人可直接教授 Lv.1～Lv.10；寵物使用技能不會升級。
#  4. 人類熟練度增量可受「職業＋職業階級＋特定技能」倍率修正。
#  5. 人類本體固定為一般系；普攻與無明確屬性的物理技能套用一般系。
#  6. 所有 Clone 寵物與隊友固定寵物，在戰鬥中都不能使用物品。
#
# 【技能資料】
#  每一招技能只需要一個資料庫 Skill ID。角色個體另存：
#    @cg_skill_levels       技能等級 1～10
#    @cg_skill_proficiency  人類技能熟練度
#    @cg_skill_use_counts   使用次數統計
#
# 【技能等級效果】
#  v1.4 改為「技能類型成長表」。每一招技能可指定：
#    傷害／回復倍率、MP 消耗倍率、熟練度門檻。
#  未指定技能仍使用 :default，保留 v1.3 的 +8% 威力、+5% MP 規則。
#
# 【正式設定位置】
#  SKILL_LEVEL_PROFILES：建立技能類型的 Lv.1～Lv.10 成長表。
#  SKILL_PROFILE_BY_ID：將資料庫 Skill ID 指定到技能類型。
#  SKILL_LEVEL_OVERRIDES：只覆寫某一招技能的個別成長表。
#
# 【熟練需求】
#  每個技能類型都能設定自己的 :thresholds。人類使用技能才會增加熟練度；
#  寵物即使使用同一招，也只記錄次數，不會增加熟練度。
#
# 【事件／腳本指令】
#  actor.cg_set_skill_level(skill_id, level)
#  actor.cg_skill_level(skill_id)
#  actor.cg_skill_proficiency(skill_id)
#  actor.cg_record_skill_use(skill_id, amount)
#  actor.cg_teach_pet_skill(skill_id, level, replace_index)
#
# 【腳本位置】
#  取代舊 CG Learn Skill By Use，放在 CG Skill Note Effects 下方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_SkillLevelCore"] = true

module ALBERT_CG
  SKILL_LEVEL_CORE_VERSION = "1.4"
  NORMAL_ELEMENT_ID = 4 unless const_defined?(:NORMAL_ELEMENT_ID)
  MAX_SKILL_LEVEL = 10 unless const_defined?(:MAX_SKILL_LEVEL)

  # 所有陣列 index 0 保留不用，index 1～10 對應技能等級。
  SKILL_LEVEL_PROFILES = {
    :default => {
      :power => [0, 100,108,116,124,132,140,148,156,164,172],
      :mp => [0, 100,105,110,115,120,125,130,135,140,145],
      :thresholds => [0, 0,3,8,15,25,38,54,73,95,120]
    },
    :physical => {
      :power => [0, 100,108,116,124,132,140,148,156,164,172],
      :mp => [0, 100,104,108,112,116,120,124,128,132,136],
      :thresholds => [0, 0,3,8,15,25,38,54,73,95,120]
    },
    :single_magic => {
      :power => [0, 100,112,124,136,148,160,172,184,196,208],
      :mp => [0, 100,108,116,124,132,140,148,156,164,172],
      :thresholds => [0, 0,3,8,15,25,38,54,73,95,120]
    },
    :area_magic => {
      :power => [0, 100,108,116,124,132,140,148,156,164,172],
      :mp => [0, 100,110,120,130,140,150,160,170,180,190],
      :thresholds => [0, 0,3,8,15,25,38,54,73,95,120]
    },
    :healing => {
      :power => [0, 100,110,120,130,140,150,160,170,180,190],
      :mp => [0, 100,106,112,118,124,130,136,142,148,154],
      :thresholds => [0, 0,3,8,15,25,38,54,73,95,120]
    },
    :status => {
      :power => [0, 100,100,100,100,100,100,100,100,100,100],
      :mp => [0, 100,105,110,115,120,125,130,135,140,145],
      :thresholds => [0, 0,3,8,15,25,38,54,73,95,120]
    }
  }

  # 目前測試資料庫的技能分類。後續新增技能時只需在此集中登錄。
  SKILL_PROFILE_BY_ID = {
    1=>:physical, 2=>:physical, 3=>:physical, 4=>:physical,
    5=>:physical, 6=>:physical, 7=>:physical, 8=>:physical,
    27=>:physical, 28=>:physical, 29=>:physical,
    84=>:physical, 85=>:physical, 86=>:physical, 87=>:physical,
    88=>:physical, 89=>:physical, 90=>:physical, 93=>:physical,
    94=>:physical, 95=>:physical,

    31=>:healing, 32=>:healing, 33=>:healing, 34=>:healing,
    35=>:healing, 36=>:healing, 37=>:healing, 38=>:healing,
    41=>:healing, 42=>:healing,

    43=>:status, 44=>:status, 45=>:status, 46=>:status,
    47=>:status, 48=>:status, 49=>:status, 50=>:status,
    51=>:status, 52=>:status, 53=>:status, 54=>:status,
    55=>:status, 56=>:status,

    57=>:single_magic, 58=>:single_magic, 59=>:single_magic,
    60=>:single_magic, 63=>:single_magic, 64=>:single_magic,
    67=>:single_magic, 68=>:single_magic, 71=>:single_magic,
    73=>:single_magic, 75=>:single_magic, 77=>:single_magic,
    79=>:single_magic, 81=>:single_magic,

    61=>:area_magic, 62=>:area_magic, 65=>:area_magic,
    66=>:area_magic, 69=>:area_magic, 70=>:area_magic,
    72=>:area_magic, 74=>:area_magic, 76=>:area_magic,
    78=>:area_magic, 80=>:area_magic, 82=>:area_magic
  }

  # 個別技能覆寫範例：
  #  59 => {:power=>[0,100,115,...], :mp=>[0,100,108,...]}
  SKILL_LEVEL_OVERRIDES = {}

  def self.skill_profile_key(skill_id)
    key = SKILL_PROFILE_BY_ID[skill_id.to_i]
    return key == nil ? :default : key
  end

  def self.skill_level_profile(skill_id)
    key = skill_profile_key(skill_id)
    profile = SKILL_LEVEL_PROFILES[key]
    profile = SKILL_LEVEL_PROFILES[:default] if profile == nil
    return profile
  end

  def self.skill_level_table(skill_id, key)
    override = SKILL_LEVEL_OVERRIDES[skill_id.to_i]
    table = override == nil ? nil : override[key]
    table = skill_level_profile(skill_id)[key] if table == nil
    table = SKILL_LEVEL_PROFILES[:default][key] if table == nil
    return table
  end

  def self.skill_power_rate(level, skill_id = 0)
    level = [[level.to_i, 1].max, MAX_SKILL_LEVEL].min
    table = skill_level_table(skill_id, :power)
    value = table[level]
    return value == nil ? 100 : value.to_i
  end

  def self.skill_mp_rate(level, skill_id = 0)
    level = [[level.to_i, 1].max, MAX_SKILL_LEVEL].min
    table = skill_level_table(skill_id, :mp)
    value = table[level]
    return value == nil ? 100 : value.to_i
  end

  def self.skill_level_threshold(level, skill_id = 0)
    level = [[level.to_i, 1].max, MAX_SKILL_LEVEL].min
    table = skill_level_table(skill_id, :thresholds)
    value = table[level]
    return value == nil ? 999999 : value.to_i
  end

end

class Game_Actor < Game_Battler
  #--------------------------------------------------------------------------
  # ● 人類／寵物身分
  #--------------------------------------------------------------------------
  def cg_skill_pet?
    return true if respond_to?(:cg_pet?) && cg_pet?
    return true if respond_to?(:cg_fixed_partner_pet?) && cg_fixed_partner_pet?
    return true if respond_to?(:cg_battle_pet?) && cg_battle_pet?
    return false
  end

  def cg_skill_human?
    return !cg_skill_pet?
  end

  #--------------------------------------------------------------------------
  # ● 技能個體資料
  #--------------------------------------------------------------------------
  def cg_prepare_skill_level_data
    @cg_skill_levels = {} if @cg_skill_levels == nil
    @cg_skill_proficiency = {} if @cg_skill_proficiency == nil
    @cg_skill_use_counts = {} if @cg_skill_use_counts == nil
    @cg_skill_prof_rate_remainder = {} if @cg_skill_prof_rate_remainder == nil
    if @skills != nil
      for skill_id in @skills
        @cg_skill_levels[skill_id.to_i] = 1 if @cg_skill_levels[skill_id.to_i] == nil
        @cg_skill_proficiency[skill_id.to_i] = 0 if @cg_skill_proficiency[skill_id.to_i] == nil
        @cg_skill_use_counts[skill_id.to_i] = 0 if @cg_skill_use_counts[skill_id.to_i] == nil
      end
    end
    return true
  end

  def cg_skill_use_counts
    cg_prepare_skill_level_data
    return @cg_skill_use_counts
  end

  def cg_skill_use_count(skill_id)
    cg_prepare_skill_level_data
    return @cg_skill_use_counts[skill_id.to_i].to_i
  end

  def cg_skill_level(skill_id)
    cg_prepare_skill_level_data
    value = @cg_skill_levels[skill_id.to_i]
    return value == nil ? 1 : [[value.to_i, 1].max, ALBERT_CG::MAX_SKILL_LEVEL].min
  end

  def cg_set_skill_level(skill_id, level)
    cg_prepare_skill_level_data
    skill_id = skill_id.to_i
    return false if skill_id <= 0 || $data_skills[skill_id] == nil
    level = [[level.to_i, 1].max, ALBERT_CG::MAX_SKILL_LEVEL].min
    @cg_skill_levels[skill_id] = level
    max_prof = ALBERT_CG.skill_level_threshold(level + 1, skill_id)
    if level >= ALBERT_CG::MAX_SKILL_LEVEL
      @cg_skill_proficiency[skill_id] = ALBERT_CG.skill_level_threshold(level, skill_id)
    elsif @cg_skill_proficiency[skill_id].to_i >= max_prof
      @cg_skill_proficiency[skill_id] = [max_prof - 1, 0].max
    end
    return true
  end

  def cg_skill_proficiency(skill_id)
    cg_prepare_skill_level_data
    return @cg_skill_proficiency[skill_id.to_i].to_i
  end

  # 舊版相容：原先的 cg_skill_exp 改視為技能熟練度儲存。
  def cg_skill_exp_for(skill_id)
    return cg_skill_proficiency(skill_id)
  end

  def cg_gain_skill_exp(skill_id, amount)
    cg_prepare_skill_level_data
    skill_id = skill_id.to_i
    @cg_skill_proficiency[skill_id] = cg_skill_proficiency(skill_id) + amount.to_i
    @cg_skill_proficiency[skill_id] = 0 if @cg_skill_proficiency[skill_id] < 0
    return @cg_skill_proficiency[skill_id]
  end

  #--------------------------------------------------------------------------
  # ● 人類技能熟練倍率
  #  五階職業核心會覆寫此方法；尚未載入時使用 100%。
  #--------------------------------------------------------------------------
  def cg_human_skill_proficiency_rate(skill_id)
    return 100
  end

  def cg_human_skill_level_cap(skill_id)
    return ALBERT_CG::MAX_SKILL_LEVEL
  end

  #--------------------------------------------------------------------------
  # ● 使用技能
  #  寵物只記錄使用次數，不增加熟練度。
  #--------------------------------------------------------------------------
  def cg_record_skill_use(skill_id, amount = 1)
    cg_prepare_skill_level_data
    skill_id = skill_id.to_i
    amount = amount.to_i
    amount = 1 if amount <= 0
    @cg_skill_use_counts[skill_id] = cg_skill_use_count(skill_id) + amount
    return [] if cg_skill_pet?

    current_level = cg_skill_level(skill_id)
    cap = [[cg_human_skill_level_cap(skill_id).to_i, 1].max, ALBERT_CG::MAX_SKILL_LEVEL].min
    return [] if current_level >= cap

    rate = [cg_human_skill_proficiency_rate(skill_id).to_i, 0].max
    raw_gain = amount * rate + @cg_skill_prof_rate_remainder[skill_id].to_i
    gain = raw_gain / 100
    @cg_skill_prof_rate_remainder[skill_id] = raw_gain % 100
    @cg_skill_proficiency[skill_id] = cg_skill_proficiency(skill_id) + gain

    raised = []
    while current_level < cap
      next_level = current_level + 1
      need = ALBERT_CG.skill_level_threshold(next_level, skill_id)
      break if cg_skill_proficiency(skill_id) < need
      current_level = next_level
      @cg_skill_levels[skill_id] = current_level
      raised.push(current_level)
    end
    return raised
  end

  #--------------------------------------------------------------------------
  # ● 寵物技能商人用接口
  #  固定技能欄核心載入後，會處理滿格取代。
  #--------------------------------------------------------------------------
  def cg_teach_pet_skill(skill_id, level, replace_index = nil)
    return false unless cg_skill_pet?
    if respond_to?(:cg_learn_skill_to_slot)
      return cg_learn_skill_to_slot(skill_id, level, replace_index)
    end
    learn_skill(skill_id)
    cg_set_skill_level(skill_id, level)
    return true
  end

  #--------------------------------------------------------------------------
  # ● 人類普攻固定為一般系
  #--------------------------------------------------------------------------
  alias albert_cg_v13_skill_element_set element_set
  def element_set
    return [ALBERT_CG::NORMAL_ELEMENT_ID] if cg_skill_human?
    return albert_cg_v13_skill_element_set
  end
end

class Game_Battler
  #--------------------------------------------------------------------------
  # ● 技能等級傷害與人類物理技能一般系補正
  #--------------------------------------------------------------------------
  alias albert_cg_v13_skill_make_obj_damage_value make_obj_damage_value
  def make_obj_damage_value(user, obj)
    albert_cg_v13_skill_make_obj_damage_value(user, obj)
    return unless user != nil && user.actor? && obj.is_a?(RPG::Skill)

    # 人類的「沒有明確屬性」物理技能，視為一般系。
    if user.respond_to?(:cg_skill_human?) && user.cg_skill_human? &&
       obj.physical_attack && (obj.element_set == nil || obj.element_set.empty?)
      normal_rate = element_rate(ALBERT_CG::NORMAL_ELEMENT_ID)
      @hp_damage = @hp_damage * normal_rate / 100 if @hp_damage != nil
      @mp_damage = @mp_damage * normal_rate / 100 if @mp_damage != nil
    end

    level = user.respond_to?(:cg_skill_level) ? user.cg_skill_level(obj.id) : 1
    rate = ALBERT_CG.skill_power_rate(level, obj.id)
    @hp_damage = @hp_damage * rate / 100 if @hp_damage != nil
    @mp_damage = @mp_damage * rate / 100 if @mp_damage != nil
  end

  #--------------------------------------------------------------------------
  # ● 技能等級 MP 消耗
  #--------------------------------------------------------------------------
  alias albert_cg_v13_skill_calc_mp_cost calc_mp_cost
  def calc_mp_cost(skill)
    cost = albert_cg_v13_skill_calc_mp_cost(skill)
    return cost unless actor? && respond_to?(:cg_skill_level)
    rate = ALBERT_CG.skill_mp_rate(cg_skill_level(skill.id), skill.id)
    return [cost * rate / 100, 0].max
  end
end

class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # ● 戰鬥技能使用後記錄
  #--------------------------------------------------------------------------
  alias albert_cg_v13_skill_execute_action_skill execute_action_skill
  def execute_action_skill
    actor = @active_battler
    skill = actor == nil ? nil : actor.action.skill
    can_count = actor != nil && actor.actor? && skill != nil &&
      actor.respond_to?(:cg_record_skill_use) && actor.skill_can_use?(skill)
    albert_cg_v13_skill_execute_action_skill
    if can_count
      raised = actor.cg_record_skill_use(skill.id, 1)
      if raised != nil && !raised.empty? && @message_window != nil
        @message_window.add_instant_text(actor.name + " 的 " + skill.name + " 提升至 Lv." + raised[-1].to_s + "！")
      end
    end
  end

  #--------------------------------------------------------------------------
  # ● 執行層硬性禁止寵物使用物品
  #--------------------------------------------------------------------------
  alias albert_cg_v13_skill_execute_action_item execute_action_item
  def execute_action_item
    if @active_battler != nil && @active_battler.actor? &&
       @active_battler.respond_to?(:cg_skill_pet?) && @active_battler.cg_skill_pet?
      @message_window.add_instant_text(@active_battler.name + " 無法使用物品。") if @message_window != nil
      return
    end
    albert_cg_v13_skill_execute_action_item
  end
end

class Scene_Skill < Scene_Base
  alias albert_cg_v13_skill_use_skill_nontarget use_skill_nontarget
  def use_skill_nontarget
    actor = @actor
    skill = @skill
    albert_cg_v13_skill_use_skill_nontarget
    # 本方法只會在技能效果已成功成立後執行，因此零 MP 技能也要計次。
    if actor != nil && skill != nil && actor.respond_to?(:cg_record_skill_use)
      actor.cg_record_skill_use(skill.id, 1)
    end
  end
end

class Window_Skill < Window_Selectable
  alias albert_cg_v13_skill_draw_item draw_item
  def draw_item(index)
    rect = item_rect(index)
    self.contents.clear_rect(rect)
    skill = @data[index]
    return if skill == nil
    rect.width -= 4
    enabled = @actor.skill_can_use?(skill)
    draw_icon(skill.icon_index, rect.x, rect.y, enabled)
    self.contents.font.color = enabled ? normal_color : text_color(7)
    level = @actor.respond_to?(:cg_skill_level) ? @actor.cg_skill_level(skill.id) : 1
    name = skill.name + " Lv." + level.to_s
    self.contents.draw_text(rect.x + 24, rect.y, rect.width - 74, WLH, name)
    self.contents.draw_text(rect, @actor.calc_mp_cost(skill), 2)
  rescue
    albert_cg_v13_skill_draw_item(index)
  end

  alias albert_cg_v13_skill_update_help update_help
  def update_help
    skill_data = skill
    if skill_data == nil || @actor == nil || !@actor.respond_to?(:cg_skill_level)
      return albert_cg_v13_skill_update_help
    end
    level = @actor.cg_skill_level(skill_data.id)
    if @actor.respond_to?(:cg_skill_pet?) && @actor.cg_skill_pet?
      text = skill_data.description.to_s + "  Lv." + level.to_s + "（寵物技能不會因使用升級）"
    else
      cap = @actor.cg_human_skill_level_cap(skill_data.id)
      prof = @actor.cg_skill_proficiency(skill_data.id)
      if level >= cap
        progress = "已達目前職業上限"
      else
        progress = prof.to_s + "/" + ALBERT_CG.skill_level_threshold(level + 1, skill_data.id).to_s
      end
      text = skill_data.description.to_s + "  Lv." + level.to_s + "  熟練 " + progress
    end
    @help_window.set_text(text)
  end
end
