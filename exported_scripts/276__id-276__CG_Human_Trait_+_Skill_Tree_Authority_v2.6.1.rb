# RMVX_SCRIPT_INDEX: 276
# RMVX_SCRIPT_ID: 276
# RMVX_SCRIPT_NAME: CG Human Trait + Skill Tree Authority v2.6.1
# RMVX_SOURCE_SHA256: 98acacc7b99306d43b210e269d25f37212f55a208660c0bb791d4f8532f18aa2

#==============================================================================
# ■ CG Human Trait + Skill Tree Authority v2.6.1
#------------------------------------------------------------------------------
# Phase 3C Batch A: one signature trait + one Rank-1 starter skill per class.
# Human jobs share the already sealed Priority / Grid / Six-Stat / Field /
# Action lifecycle. Presentation remains Tankentai Human SBS.
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_HumanTraitSkillTree"] = "2.6.1"

module ALBERT_CG
  HUMAN_TRAIT_SKILL_TREE_VERSION = "2.6.1"

  HUMAN_STARTER_SKILLS = {
    1 => 107, # 劍士・破陣斬
    2 => 108, # 守衛・盾擊
    3 => 109, # 弓手・速射
    4 => 110, # 法師・魔彈
    5 => 111, # 神官・治癒禱言
    6 => 112  # 格鬥家・連環拳
  }

  HUMAN_SIGNATURE_TRAITS = {
    1 => :blade_pressure,
    2 => :bulwark,
    3 => :eagle_eye,
    4 => :arcane_focus,
    5 => :benediction,
    6 => :combo_rhythm
  }

  HUMAN_SIGNATURE_TRAIT_NAMES = {
    :blade_pressure => "劍勢",
    :bulwark        => "堡壘",
    :eagle_eye      => "鷹眼",
    :arcane_focus   => "魔導專注",
    :benediction    => "聖恩",
    :combo_rhythm   => "連擊節奏"
  }

  HUMAN_SKILL_TREE = {
    1 => [{:skill_id=>107, :rank=>1, :branch=>:pressure}],
    2 => [{:skill_id=>108, :rank=>1, :branch=>:guard}],
    3 => [{:skill_id=>109, :rank=>1, :branch=>:ranged}],
    4 => [{:skill_id=>110, :rank=>1, :branch=>:arcane}],
    5 => [{:skill_id=>111, :rank=>1, :branch=>:support}],
    6 => [{:skill_id=>112, :rank=>1, :branch=>:combo}]
  }

  def self.human_signature_trait(class_id)
    return HUMAN_SIGNATURE_TRAITS[class_id.to_i]
  end

  def self.human_signature_trait_name(class_id)
    key = human_signature_trait(class_id)
    value = HUMAN_SIGNATURE_TRAIT_NAMES[key]
    return value == nil ? "" : value
  end

  def self.human_tree_entries(class_id)
    row = HUMAN_SKILL_TREE[class_id.to_i]
    return row == nil ? [] : row
  end

  def self.human_tree_skill_ids(class_id, rank = 5)
    result = []
    for row in human_tree_entries(class_id)
      next if row[:rank].to_i > rank.to_i
      sid = row[:skill_id].to_i
      result.push(sid) if sid > 0 && !result.include?(sid)
    end
    return result
  end

  def self.human_tree_skill?(skill_id)
    sid = skill_id.to_i
    for class_id in HUMAN_SKILL_TREE.keys
      return true if human_tree_skill_ids(class_id, 5).include?(sid)
    end
    return false
  end

  def self.human_tree_owner(skill_id)
    sid = skill_id.to_i
    for class_id in HUMAN_SKILL_TREE.keys
      return class_id.to_i if human_tree_skill_ids(class_id, 5).include?(sid)
    end
    return 0
  end

  HUMAN_STARTER_SKILLS.each do |class_id, skill_id|
    by_rank = JOB_SKILL_CAPS[class_id]
    next if by_rank == nil
    {1=>3, 2=>5, 3=>7, 4=>9, 5=>10}.each do |rank, cap|
      by_rank[rank] = {:default=>0} if by_rank[rank] == nil
      by_rank[rank][skill_id] = cap
    end
  end

  if const_defined?(:SKILL_PROFILE_BY_ID)
    SKILL_PROFILE_BY_ID[107] = :physical
    SKILL_PROFILE_BY_ID[108] = :physical
    SKILL_PROFILE_BY_ID[109] = :physical
    SKILL_PROFILE_BY_ID[110] = :single_magic
    SKILL_PROFILE_BY_ID[111] = :healing
    SKILL_PROFILE_BY_ID[112] = :physical
  end

  module HUMAN_TRAIT_V261
    VERSION = "2.6.1"
    SWORD_PERCENT = 112
    GUARDIAN_PERCENT = 80
    ARCHER_PERCENT = 115
    MAGE_PERCENT = 115
    CLERIC_HEAL_PERCENT = 120
    COMBO_STEP_PERCENT = 10
    COMBO_MAX_BONUS = 50

    def self.human?(battler)
      return false if battler == nil || !battler.actor?
      return false if battler.respond_to?(:cg_skill_pet?) && battler.cg_skill_pet?
      return battler.class_id.to_i >= 1 && battler.class_id.to_i <= 6
    rescue
      return false
    end

    def self.class_id(battler)
      return human?(battler) ? battler.class_id.to_i : 0
    end

    def self.front?(battler)
      return battler.respond_to?(:cg_front_row?) ? battler.cg_front_row? : true
    rescue
      return true
    end

    def self.back?(battler)
      return battler.respond_to?(:cg_back_row?) ? battler.cg_back_row? : !front?(battler)
    rescue
      return false
    end

    def self.skill_physical?(obj)
      return false if obj == nil
      return obj.cg_pokemon_damage_class == :physical if obj.respond_to?(:cg_pokemon_damage_class)
      return obj.respond_to?(:physical_attack) && obj.physical_attack
    rescue
      return false
    end

    def self.skill_special?(obj)
      return false if obj == nil
      return obj.cg_pokemon_damage_class == :special if obj.respond_to?(:cg_pokemon_damage_class)
      return false
    rescue
      return false
    end

    def self.skill_melee?(obj)
      return false if obj == nil
      range = obj.respond_to?(:cg_range_type) ? obj.cg_range_type : nil
      return range == :melee if range != nil
      return skill_physical?(obj)
    rescue
      return false
    end

    def self.skill_ranged?(obj)
      return false if obj == nil
      return obj.respond_to?(:cg_range_type) && obj.cg_range_type == :ranged
    rescue
      return false
    end

    def self.combo_skill?(obj)
      return false if obj == nil
      return obj.note.to_s =~ /<cg_human_combo>/i ? true : false
    rescue
      return false
    end

    def self.record(battler, data)
      return data if battler == nil
      records = battler.instance_variable_get(:@cg_human_trait_records)
      records = [] unless records.is_a?(Array)
      records.push(data)
      records.shift while records.size > 32
      battler.instance_variable_set(:@cg_human_trait_records, records)
      battler.instance_variable_set(:@cg_human_trait_last_record, data)
      return data
    rescue
      return data
    end

    def self.apply_outgoing_skill(user, target, obj, damage)
      value = damage.to_i
      return value if value <= 0 || !human?(user)
      cid = class_id(user)
      before = value
      kind = nil
      percent = 100
      if cid == 1 && front?(user) && skill_physical?(obj) && skill_melee?(obj)
        kind = :blade_pressure
        percent = SWORD_PERCENT
      elsif cid == 3 && back?(user) && skill_physical?(obj) && skill_ranged?(obj)
        kind = :eagle_eye
        percent = ARCHER_PERCENT
      elsif cid == 4 && skill_special?(obj)
        kind = :arcane_focus
        percent = MAGE_PERCENT
      elsif cid == 6 && skill_physical?(obj) && combo_skill?(obj)
        action = user.respond_to?(:action) ? user.action : nil
        action_id = action == nil ? obj.object_id : action.object_id
        last_id = user.instance_variable_get(:@cg_human_combo_action_id)
        if last_id.to_i != action_id.to_i
          user.instance_variable_set(:@cg_human_combo_action_id, action_id)
          user.instance_variable_set(:@cg_human_combo_hit_count, 0)
        end
        hit = user.instance_variable_get(:@cg_human_combo_hit_count).to_i + 1
        user.instance_variable_set(:@cg_human_combo_hit_count, hit)
        bonus = (hit - 1) * COMBO_STEP_PERCENT
        bonus = COMBO_MAX_BONUS if bonus > COMBO_MAX_BONUS
        kind = :combo_rhythm
        percent = 100 + bonus
        value = [value * percent / 100, 1].max
        record(user, {:kind=>kind, :class_id=>cid, :skill_id=>obj.id.to_i,
          :before=>before, :after=>value, :percent=>percent, :hit=>hit,
          :target=>target == nil ? "" : target.name.to_s})
        return value
      end
      return value if kind == nil
      value = [value * percent / 100, 1].max
      record(user, {:kind=>kind, :class_id=>cid, :skill_id=>obj.id.to_i,
        :before=>before, :after=>value, :percent=>percent,
        :target=>target == nil ? "" : target.name.to_s})
      return value
    rescue
      return damage.to_i
    end

    def self.apply_outgoing_attack(user, target, damage)
      value = damage.to_i
      return value if value <= 0 || !human?(user)
      cid = class_id(user)
      range = user.respond_to?(:cg_basic_attack_range_type) ? user.cg_basic_attack_range_type : :melee
      kind = nil
      percent = 100
      if cid == 1 && front?(user) && range != :ranged
        kind = :blade_pressure
        percent = SWORD_PERCENT
      elsif cid == 3 && back?(user) && range == :ranged
        kind = :eagle_eye
        percent = ARCHER_PERCENT
      end
      return value if kind == nil
      before = value
      value = [value * percent / 100, 1].max
      record(user, {:kind=>kind, :class_id=>cid, :skill_id=>0,
        :before=>before, :after=>value, :percent=>percent,
        :target=>target == nil ? "" : target.name.to_s})
      return value
    rescue
      return damage.to_i
    end

    def self.apply_incoming(target, user, obj, damage)
      value = damage.to_i
      return value if value <= 0 || !human?(target)
      return value unless class_id(target) == 2 && front?(target)
      before = value
      value = [value * GUARDIAN_PERCENT / 100, 1].max
      record(target, {:kind=>:bulwark, :class_id=>2,
        :skill_id=>obj == nil ? 0 : obj.id.to_i,
        :before=>before, :after=>value, :percent=>GUARDIAN_PERCENT,
        :attacker=>user == nil ? "" : user.name.to_s})
      return value
    rescue
      return damage.to_i
    end

    def self.apply_heal(user, target, obj, hp_damage)
      value = hp_damage.to_i
      return value unless value < 0 && human?(user) && class_id(user) == 5
      before = value
      amount = [-value, 1].max
      amount = [amount * CLERIC_HEAL_PERCENT / 100, 1].max
      value = -amount
      record(user, {:kind=>:benediction, :class_id=>5,
        :skill_id=>obj == nil ? 0 : obj.id.to_i,
        :before=>before, :after=>value, :percent=>CLERIC_HEAL_PERCENT,
        :target=>target == nil ? "" : target.name.to_s})
      return value
    rescue
      return hp_damage.to_i
    end
  end
end

class Game_Battler
  def cg_human_trait_records
    value = @cg_human_trait_records
    return value.is_a?(Array) ? value : []
  end

  def cg_clear_human_trait_records
    @cg_human_trait_records = []
    @cg_human_trait_last_record = nil
    @cg_human_combo_action_id = nil
    @cg_human_combo_hit_count = 0
    return true
  end

  alias cg_v261_human_trait_obj_damage make_obj_damage_value
  def make_obj_damage_value(user, obj)
    cg_v261_human_trait_obj_damage(user, obj)
    return if obj == nil
    if @hp_damage.to_i > 0
      value = ALBERT_CG::HUMAN_TRAIT_V261.apply_outgoing_skill(user, self, obj, @hp_damage.to_i)
      value = ALBERT_CG::HUMAN_TRAIT_V261.apply_incoming(self, user, obj, value)
      @hp_damage = value
      if @cg_last_damage_breakdown.is_a?(Hash)
        @cg_last_damage_breakdown[:human_trait_final] = value
      end
    elsif @hp_damage.to_i < 0
      @hp_damage = ALBERT_CG::HUMAN_TRAIT_V261.apply_heal(user, self, obj, @hp_damage.to_i)
    end
  end

  alias cg_v261_human_trait_attack_damage make_attack_damage_value
  def make_attack_damage_value(attacker)
    cg_v261_human_trait_attack_damage(attacker)
    if @hp_damage.to_i > 0
      value = ALBERT_CG::HUMAN_TRAIT_V261.apply_outgoing_attack(attacker, self, @hp_damage.to_i)
      value = ALBERT_CG::HUMAN_TRAIT_V261.apply_incoming(self, attacker, nil, value)
      @hp_damage = value
      if @cg_last_damage_breakdown.is_a?(Hash)
        @cg_last_damage_breakdown[:human_trait_final] = value
      end
    end
  end
end

class Game_Actor < Game_Battler
  def cg_human_job_loadouts
    @cg_human_job_loadouts = {} unless @cg_human_job_loadouts.is_a?(Hash)
    return @cg_human_job_loadouts
  end

  def cg_human_default_job_loadout(class_id = nil)
    class_id = @class_id if class_id == nil
    sid = ALBERT_CG::HUMAN_STARTER_SKILLS[class_id.to_i]
    return sid == nil ? [] : [sid.to_i]
  end

  def cg_human_save_job_loadout(class_id = nil)
    return false unless cg_job_human?
    class_id = @class_id if class_id == nil
    ids = respond_to?(:cg_skill_slot_ids) ? cg_skill_slot_ids.clone : []
    cg_human_job_loadouts[class_id.to_i] = ids
    return true
  end

  def cg_human_apply_job_loadout(class_id = nil)
    return false unless cg_job_human?
    class_id = @class_id if class_id == nil
    ids = cg_human_job_loadouts[class_id.to_i]
    if ids == nil || ids.empty?
      ids = cg_human_default_job_loadout(class_id)
      cg_human_job_loadouts[class_id.to_i] = ids.clone
    end
    valid = []
    for sid in ids
      next if $data_skills[sid.to_i] == nil
      next if ALBERT_CG.human_tree_owner(sid.to_i) > 0 &&
              ALBERT_CG.human_tree_owner(sid.to_i) != class_id.to_i
      valid.push(sid.to_i) unless valid.include?(sid.to_i)
    end
    if valid.empty?
      valid = cg_human_default_job_loadout(class_id)
      cg_human_job_loadouts[class_id.to_i] = valid.clone
    end
    @cg_skill_slot_ids = valid.clone
    @cg_equipped_skill_ids = valid.clone
    @skills = valid.clone
    for sid in valid
      cg_set_skill_level(sid, 1) if respond_to?(:cg_set_skill_level) && cg_skill_level(sid).to_i <= 0
    end
    return true
  end

  def cg_human_tree_available_skill_ids(class_id = nil)
    class_id = @class_id if class_id == nil
    rank = respond_to?(:cg_job_rank) ? cg_job_rank(class_id) : 1
    return ALBERT_CG.human_tree_skill_ids(class_id, rank)
  end

  def cg_human_learn_tree_skill(skill_id)
    return false unless cg_job_human?
    sid = skill_id.to_i
    return false unless cg_human_tree_available_skill_ids.include?(sid)
    return false if $data_skills[sid] == nil
    result = cg_learn_skill_to_slot(sid, 1, nil) if respond_to?(:cg_learn_skill_to_slot)
    cg_human_save_job_loadout(@class_id) if result
    return result == true
  rescue
    return false
  end

  alias cg_v261_human_prepare_job_data cg_prepare_job_data
  def cg_prepare_job_data
    result = cg_v261_human_prepare_job_data
    if cg_job_human?
      cid = @class_id.to_i
      unless cg_human_job_loadouts.has_key?(cid)
        cg_human_job_loadouts[cid] = cg_human_default_job_loadout(cid)
      end
      cg_human_apply_job_loadout(cid) if respond_to?(:cg_skill_slot_ids) && cg_skill_slot_ids.empty?
    end
    return result
  end

  alias cg_v261_human_change_job cg_change_job
  def cg_change_job(class_id)
    old_class = @class_id.to_i
    cg_human_save_job_loadout(old_class) if cg_job_human?
    result = cg_v261_human_change_job(class_id)
    cg_human_apply_job_loadout(@class_id.to_i) if result && cg_job_human?
    return result
  end
end


class Scene_Battle < Scene_Base
  alias cg_v261_human_trait_execute_action execute_action
  def execute_action
    b = @active_battler
    if b != nil && ALBERT_CG::HUMAN_TRAIT_V261.human?(b) &&
       ALBERT_CG::HUMAN_TRAIT_V261.class_id(b) == 6 && b.action != nil && b.action.skill?
      obj = b.action.skill
      if ALBERT_CG::HUMAN_TRAIT_V261.combo_skill?(obj)
        b.instance_variable_set(:@cg_human_combo_action_id, b.action.object_id)
        b.instance_variable_set(:@cg_human_combo_hit_count, 0)
      end
    end
    return cg_v261_human_trait_execute_action
  end
end

module RPG
  class Skill
    alias cg_v261_human_base_action base_action
    def base_action
      case @id.to_i
      when 107
        return "NORMAL_ATTACK"
      when 108
        return "STOMP"
      when 109
        return "THROW_WEAPON"
      when 110
        return "SKILL_USE"
      when 111
        return "SKILL_USE"
      when 112
        return "RAPID_MULTI_ATTACK"
      end
      return cg_v261_human_base_action
    end
  end

  class Weapon
    alias cg_v261_human_weapon_base_action base_action
    def base_action
      return "THROW_WEAPON" if @id.to_i == 1
      return cg_v261_human_weapon_base_action
    end
  end
end
