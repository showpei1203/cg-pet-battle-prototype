# RMVX_SCRIPT_INDEX: 277
# RMVX_SCRIPT_ID: 277
# RMVX_SCRIPT_NAME: CG Human Rank2 Tactical Skills v2.6.2b
# RMVX_SOURCE_SHA256: d81a24c3875e952548ee71d27f38f1309919942c2db927a6b1e45e8be6f765d0

#==============================================================================
# ■ CG Human Rank-2 Tactical Skills Authority v2.6.2b
#------------------------------------------------------------------------------
# Phase 3C Batch B: one Rank-2 tactical skill per canonical Human class.
# Extends v2.6.1 Human Trait + Skill Tree Authority without modifying sealed
# Pokemon Move / Ability / Grid / Priority / Field / Action lifecycle scripts.
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_HumanRank2Tactical"] = "2.6.2b"

module ALBERT_CG
  HUMAN_RANK2_TACTICAL_VERSION = "2.6.2b"

  HUMAN_RANK2_SKILLS = {
    1 => 113,
    2 => 114,
    3 => 115,
    4 => 116,
    5 => 117,
    6 => 118
  }

  HUMAN_RANK2_BRANCH = {
    1 => :pressure,
    2 => :guard,
    3 => :ranged,
    4 => :arcane,
    5 => :support,
    6 => :combo
  }

  HUMAN_RANK2_SKILLS.each do |class_id, skill_id|
    rows = HUMAN_SKILL_TREE[class_id]
    rows = [] if rows == nil
    exists = rows.any? { |row| row[:skill_id].to_i == skill_id.to_i }
    rows.push({:skill_id=>skill_id, :rank=>2, :branch=>HUMAN_RANK2_BRANCH[class_id]}) unless exists
    HUMAN_SKILL_TREE[class_id] = rows

    by_rank = JOB_SKILL_CAPS[class_id]
    next if by_rank == nil
    {2=>5, 3=>7, 4=>9, 5=>10}.each do |rank, cap|
      by_rank[rank] = {:default=>0} if by_rank[rank] == nil
      by_rank[rank][skill_id] = cap
    end
  end

  if const_defined?(:SKILL_PROFILE_BY_ID)
    SKILL_PROFILE_BY_ID[113] = :physical
    SKILL_PROFILE_BY_ID[114] = :status
    SKILL_PROFILE_BY_ID[115] = :status
    SKILL_PROFILE_BY_ID[116] = :all_magic
    SKILL_PROFILE_BY_ID[117] = :status
    SKILL_PROFILE_BY_ID[118] = :physical
  end

  module HUMAN_RANK2_V262
    VERSION = "2.6.2b"
    SWORD_ARMOR_BREAK = 113
    GUARDIAN_INTERCEPT = 114
    ARCHER_HUNTER_MARK = 115
    MAGE_ARCANE_BURST = 116
    CLERIC_PURIFY_LIGHT = 117
    BRAWLER_INTERRUPT = 118
    HUNTER_MARK_PERCENT = 115
    HUNTER_MARK_TURNS = 2

    def self.record(user, data)
      return data if user == nil
      if defined?(ALBERT_CG::HUMAN_TRAIT_V261) && ALBERT_CG::HUMAN_TRAIT_V261.respond_to?(:record)
        return ALBERT_CG::HUMAN_TRAIT_V261.record(user, data)
      end
      records = user.instance_variable_get(:@cg_human_trait_records)
      records = [] unless records.is_a?(Array)
      records.push(data)
      user.instance_variable_set(:@cg_human_trait_records, records)
      return data
    rescue
      return data
    end

    def self.primary_status_ids
      if defined?(ALBERT_CG::MOVE_EFFECT) && ALBERT_CG::MOVE_EFFECT.respond_to?(:primary_cure_state_ids)
        return ALBERT_CG::MOVE_EFFECT.primary_cure_state_ids
      end
      return [31, 56, 37, 39, 40, 38]
    rescue
      return [31, 56, 37, 39, 40, 38]
    end

    def self.apply_armor_break(user, target)
      return false if user == nil || target == nil
      return false unless target.respond_to?(:cg_change_stat_stage)
      before = target.respond_to?(:cg_stat_stage) ? target.cg_stat_stage(:def).to_i : 0
      delta = target.cg_change_stat_stage(:def, -1).to_i
      after = target.respond_to?(:cg_stat_stage) ? target.cg_stat_stage(:def).to_i : before
      record(user, {:kind=>:armor_break, :skill_id=>SWORD_ARMOR_BREAK,
        :target=>target.name.to_s, :before=>before, :after=>after, :delta=>delta})
      return after < before
    rescue
      return false
    end

    def self.apply_guardian_intercept(user)
      return false if user == nil
      ok = false
      if defined?(ALBERT_CG::UNIQUE_C_V236) && ALBERT_CG::UNIQUE_C_V236.respond_to?(:set_redirect)
        ALBERT_CG::UNIQUE_C_V236.set_redirect(user, :follow_me)
        ok = true
      end
      record(user, {:kind=>:guardian_intercept, :skill_id=>GUARDIAN_INTERCEPT,
        :target=>user.name.to_s, :active=>ok})
      return ok
    rescue
      return false
    end

    def self.apply_hunter_mark(user, target)
      return false if user == nil || target == nil
      side = user.actor? ? :actor : :enemy
      target.instance_variable_set(:@cg_human_v262_mark_side, side)
      target.instance_variable_set(:@cg_human_v262_mark_turns, HUNTER_MARK_TURNS)
      target.instance_variable_set(:@cg_human_v262_mark_source, user.name.to_s)
      record(user, {:kind=>:hunter_mark, :skill_id=>ARCHER_HUNTER_MARK,
        :target=>target.name.to_s, :side=>side, :turns=>HUNTER_MARK_TURNS})
      return true
    rescue
      return false
    end

    def self.marked_for?(user, target)
      return false if user == nil || target == nil
      return false if target.instance_variable_get(:@cg_human_v262_mark_turns).to_i <= 0
      side = target.instance_variable_get(:@cg_human_v262_mark_side)
      return side == (user.actor? ? :actor : :enemy)
    rescue
      return false
    end

    def self.ranged_skill?(obj)
      return false if obj == nil
      if defined?(ALBERT_CG::HUMAN_TRAIT_V261) && ALBERT_CG::HUMAN_TRAIT_V261.respond_to?(:skill_ranged?)
        return true if ALBERT_CG::HUMAN_TRAIT_V261.skill_ranged?(obj)
      end
      if obj.respond_to?(:cg_range_type)
        range = obj.cg_range_type
        return true if range == :ranged
        return false if range == :melee
      end
      if defined?(CG_PMD) && CG_PMD.respond_to?(:skill_motion_for)
        motion = CG_PMD.skill_motion_for(obj)
        return true if motion == :shoot || motion == :stationary_attack
        return false if motion == :melee_attack
      end
      return false
    rescue
      return false
    end

    def self.ranged_basic_attack?(user)
      return false if user == nil
      return user.respond_to?(:cg_basic_attack_range_type) && user.cg_basic_attack_range_type == :ranged
    rescue
      return false
    end

    def self.apply_hunter_mark_bonus(user, target, obj, damage)
      value = damage.to_i
      return value if value <= 0 || !marked_for?(user, target) || !ranged_skill?(obj)
      before = value
      value = [value * HUNTER_MARK_PERCENT / 100, 1].max
      record(user, {:kind=>:hunter_mark_bonus, :skill_id=>(obj == nil ? 0 : obj.id.to_i),
        :target=>target.name.to_s, :before=>before, :after=>value,
        :percent=>HUNTER_MARK_PERCENT})
      return value
    rescue
      return damage.to_i
    end

    def self.apply_hunter_mark_attack_bonus(user, target, damage)
      value = damage.to_i
      return value if value <= 0 || !marked_for?(user, target) || !ranged_basic_attack?(user)
      before = value
      value = [value * HUNTER_MARK_PERCENT / 100, 1].max
      record(user, {:kind=>:hunter_mark_bonus, :skill_id=>0, :basic_attack=>true,
        :target=>target.name.to_s, :before=>before, :after=>value,
        :percent=>HUNTER_MARK_PERCENT})
      return value
    rescue
      return damage.to_i
    end

    def self.apply_purify_light(user, target)
      return false if user == nil || target == nil
      removed = []
      for sid in primary_status_ids
        next unless target.respond_to?(:state?) && target.state?(sid.to_i)
        target.remove_state(sid.to_i)
        removed.push(sid.to_i) unless target.state?(sid.to_i)
      end
      before = target.respond_to?(:cg_stat_stage) ? target.cg_stat_stage(:spd).to_i : 0
      delta = target.respond_to?(:cg_change_stat_stage) ? target.cg_change_stat_stage(:spd, 1).to_i : 0
      after = target.respond_to?(:cg_stat_stage) ? target.cg_stat_stage(:spd).to_i : before
      record(user, {:kind=>:purify_light, :skill_id=>CLERIC_PURIFY_LIGHT,
        :target=>target.name.to_s, :removed=>removed, :spd_before=>before,
        :spd_after=>after, :spd_delta=>delta})
      return !removed.empty? || after > before
    rescue
      return false
    end

    def self.pending_action?(target)
      if defined?(ALBERT_CG::ABILITY_SECONDARY_V2510) &&
         ALBERT_CG::ABILITY_SECONDARY_V2510.respond_to?(:target_has_pending_action?)
        return ALBERT_CG::ABILITY_SECONDARY_V2510.target_has_pending_action?(target)
      end
      return true
    rescue
      return true
    end

    def self.apply_interrupt(user, target)
      return false if user == nil || target == nil || target.hp.to_i <= 0
      return false unless pending_action?(target)
      sid = defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_FLINCH : 48
      return false if target.state?(sid)
      target.add_state(sid)
      ok = target.state?(sid)
      if ok && target.respond_to?(:added_states) && !target.added_states.include?(sid)
        target.added_states.push(sid)
      end
      record(user, {:kind=>:interrupt, :skill_id=>BRAWLER_INTERRUPT,
        :target=>target.name.to_s, :state=>sid, :pending=>true, :applied=>ok})
      return ok
    rescue
      return false
    end

    def self.tick_marks
      battlers = []
      battlers += $game_party.members if $game_party != nil
      battlers += $game_troop.members if $game_troop != nil
      battlers.each do |b|
        next if b == nil
        turns = b.instance_variable_get(:@cg_human_v262_mark_turns).to_i
        next if turns <= 0
        turns -= 1
        b.instance_variable_set(:@cg_human_v262_mark_turns, turns)
        if turns <= 0
          b.instance_variable_set(:@cg_human_v262_mark_side, nil)
          b.instance_variable_set(:@cg_human_v262_mark_source, nil)
        end
      end
      return true
    rescue
      return false
    end
  end
end

class Game_Battler
  alias cg_v262_human_rank2_obj_damage make_obj_damage_value
  def make_obj_damage_value(user, obj)
    cg_v262_human_rank2_obj_damage(user, obj)
    if @hp_damage.to_i > 0 && obj != nil
      @hp_damage = ALBERT_CG::HUMAN_RANK2_V262.apply_hunter_mark_bonus(user, self, obj, @hp_damage.to_i)
      if @cg_last_damage_breakdown.is_a?(Hash)
        @cg_last_damage_breakdown[:human_rank2_final] = @hp_damage.to_i
      end
    end
  end

  alias cg_v262b_human_rank2_attack_damage make_attack_damage_value
  def make_attack_damage_value(attacker)
    cg_v262b_human_rank2_attack_damage(attacker)
    if @hp_damage.to_i > 0
      @hp_damage = ALBERT_CG::HUMAN_RANK2_V262.apply_hunter_mark_attack_bonus(attacker, self, @hp_damage.to_i)
      if @cg_last_damage_breakdown.is_a?(Hash)
        @cg_last_damage_breakdown[:human_rank2_final] = @hp_damage.to_i
      end
    end
  end

  alias cg_v262_human_rank2_skill_effect skill_effect
  def skill_effect(user, skill)
    sid = skill == nil ? 0 : skill.id.to_i

    if sid == ALBERT_CG::HUMAN_RANK2_V262::GUARDIAN_INTERCEPT && user == self
      clear_action_results
      ALBERT_CG::HUMAN_RANK2_V262.apply_guardian_intercept(user)
      return
    elsif sid == ALBERT_CG::HUMAN_RANK2_V262::ARCHER_HUNTER_MARK
      clear_action_results
      ALBERT_CG::HUMAN_RANK2_V262.apply_hunter_mark(user, self)
      return
    elsif sid == ALBERT_CG::HUMAN_RANK2_V262::CLERIC_PURIFY_LIGHT
      clear_action_results
      ALBERT_CG::HUMAN_RANK2_V262.apply_purify_light(user, self)
      return
    end

    cg_v262_human_rank2_skill_effect(user, skill)
    return if skill == nil || @skipped || @missed || @evaded || @hp_damage.to_i <= 0

    if sid == ALBERT_CG::HUMAN_RANK2_V262::SWORD_ARMOR_BREAK
      ALBERT_CG::HUMAN_RANK2_V262.apply_armor_break(user, self)
    elsif sid == ALBERT_CG::HUMAN_RANK2_V262::BRAWLER_INTERRUPT
      ALBERT_CG::HUMAN_RANK2_V262.apply_interrupt(user, self)
    end
  end

  alias cg_v262_human_rank2_remove_states_battle remove_states_battle
  def remove_states_battle
    cg_v262_human_rank2_remove_states_battle
    @cg_human_v262_mark_side = nil
    @cg_human_v262_mark_turns = 0
    @cg_human_v262_mark_source = nil
  end
end

class Scene_Battle < Scene_Base
  alias cg_v262_human_rank2_turn_end turn_end
  def turn_end
    result = cg_v262_human_rank2_turn_end
    ALBERT_CG::HUMAN_RANK2_V262.tick_marks
    return result
  end
end

module RPG
  class Skill
    alias cg_v262_human_rank2_base_action base_action
    def base_action
      case @id.to_i
      when 113
        return "NORMAL_ATTACK"
      when 114
        return "SKILL_USE"
      when 115
        return "THROW_WEAPON"
      when 116
        return "SKILL_ALL"
      when 117
        return "SKILL_USE"
      when 118
        return "STOMP"
      end
      return cg_v262_human_rank2_base_action
    end
  end
end
