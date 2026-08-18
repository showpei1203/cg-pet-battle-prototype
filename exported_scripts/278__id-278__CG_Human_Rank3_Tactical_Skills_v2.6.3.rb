# RMVX_SCRIPT_INDEX: 278
# RMVX_SCRIPT_ID: 278
# RMVX_SCRIPT_NAME: CG Human Rank3 Tactical Skills v2.6.3
# RMVX_SOURCE_SHA256: 63803cdb5699bc0af76175be699c8789f62aea31f5bd260141307219ae858fa1

#==============================================================================
# ■ CG Human Rank-3 Tactical Skills Authority v2.6.3
#------------------------------------------------------------------------------
# 【用途】
#  在已封版的 Human Rank-1 / Rank-2 架構上加入六職 Rank-3 戰術節點。
#  本頁只擴充 Human Skill Tree 與戰鬥機制，不修改 Pokémon Move / Ability / Grid /
#  Priority / Field / Action lifecycle 的既有 Authority。
#
# 【六職 Rank-3】
#  119 裂甲追斬（劍士） ：目標 DEF Stage < 0 時，本技能最終傷害再 ×130%。
#  120 聖盾堡壘（守衛） ：Priority +4；啟動既有 Follow Me Redirect，並 DEF / SpD +1。
#  121 獵殺箭（弓手）   ：攻擊己方 Hunter Mark 目標時再 ×135%，命中後消耗標記。
#  122 奧術領域（法師） ：SpA +1，並透過既有 FIELD_V233 建立 Psychic Terrain 3 回合。
#  123 聖域祈禱（神官） ：全體回復，並透過 FIELD_V233 為己方建立 Safeguard 3 回合。
#  124 疾風連拳（格鬥家）：沿用 RAPID_MULTI_ATTACK / combo rhythm；本 Action 首次命中 SPE +1。
#
# 【設定】
#  SWORD_BROKEN_DEF_PERCENT = 130
#  ARCHER_MARK_EXECUTE_PERCENT = 135
#  ARCANE_TERRAIN_TURNS = 3
#  SANCTUARY_TURNS = 3
#
# 【機制規則】
#  - 裂甲追斬的條件直接讀正式 cg_stat_stage(:def)，不維護第二套破甲旗標。
#  - 獵殺箭直接讀 Rank-2 Hunter Mark Authority；傷害成功後將正式 mark turns 歸零。
#  - 聖盾堡壘直接呼叫 Rank-2 Guardian Redirect Authority，再追加正式六維 Stage。
#  - 奧術領域 / 聖域祈禱只寫入 FIELD_V233 唯一 Field state / side effect。
#  - 疾風連拳仍由 Rank-1 combo rhythm 處理逐 hit 增傷，本頁只在同一 Action 首次命中
#    增加一次 SPE，避免多 hit 重複堆階。
#
# 【呼叫方式】
#  正式玩家流程直接使用 Skill 119..124；不需要事件 Script Call。
#  Debug/測試若需查詢，可使用：
#    ALBERT_CG::HUMAN_RANK3_V263.record(...)
#    ALBERT_CG::HUMAN_RANK3_V263.apply_arcane_domain(user)
#
# 【範例】
#  劍士先用 Rank-2 破甲斬令敵方 DEF -1，下一回合裂甲追斬會觸發 130% 追擊倍率。
#  弓手先用獵人標記，再用獵殺箭命中同一目標，會吃標記增傷並消耗該標記。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_HumanRank3Tactical"] = "2.6.3"

module ALBERT_CG
  HUMAN_RANK3_TACTICAL_VERSION = "2.6.3"

  HUMAN_RANK3_SKILLS = {
    1 => 119,
    2 => 120,
    3 => 121,
    4 => 122,
    5 => 123,
    6 => 124
  }

  HUMAN_RANK3_BRANCH = {
    1 => :pressure,
    2 => :guard,
    3 => :ranged,
    4 => :arcane,
    5 => :support,
    6 => :combo
  }

  HUMAN_RANK3_SKILLS.each do |class_id, skill_id|
    rows = HUMAN_SKILL_TREE[class_id]
    rows = [] if rows == nil
    exists = rows.any? { |row| row[:skill_id].to_i == skill_id.to_i }
    rows.push({:skill_id=>skill_id, :rank=>3, :branch=>HUMAN_RANK3_BRANCH[class_id]}) unless exists
    HUMAN_SKILL_TREE[class_id] = rows

    by_rank = JOB_SKILL_CAPS[class_id]
    next if by_rank == nil
    {3=>7, 4=>9, 5=>10}.each do |rank, cap|
      by_rank[rank] = {:default=>0} if by_rank[rank] == nil
      by_rank[rank][skill_id] = cap
    end
  end

  if const_defined?(:SKILL_PROFILE_BY_ID)
    SKILL_PROFILE_BY_ID[119] = :physical
    SKILL_PROFILE_BY_ID[120] = :status
    SKILL_PROFILE_BY_ID[121] = :physical
    SKILL_PROFILE_BY_ID[122] = :status
    SKILL_PROFILE_BY_ID[123] = :healing
    SKILL_PROFILE_BY_ID[124] = :physical
  end

  module HUMAN_RANK3_V263
    VERSION = "2.6.3"

    SWORD_SHATTER_PURSUIT = 119
    GUARDIAN_BASTION = 120
    ARCHER_MARK_EXECUTE = 121
    MAGE_ARCANE_DOMAIN = 122
    CLERIC_SANCTUARY = 123
    BRAWLER_GALE_COMBO = 124

    SWORD_BROKEN_DEF_PERCENT = 130
    ARCHER_MARK_EXECUTE_PERCENT = 135
    ARCANE_TERRAIN_TURNS = 3
    SANCTUARY_TURNS = 3

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

    def self.def_stage(target)
      return 0 if target == nil || !target.respond_to?(:cg_stat_stage)
      return target.cg_stat_stage(:def).to_i
    rescue
      return 0
    end

    def self.apply_sword_followup_bonus(user, target, obj, damage)
      value = damage.to_i
      return value if value <= 0 || obj == nil || obj.id.to_i != SWORD_SHATTER_PURSUIT
      stage = def_stage(target)
      return value unless stage < 0
      before = value
      value = [value * SWORD_BROKEN_DEF_PERCENT / 100, 1].max
      record(user, {:kind=>:sword_rank3_followup, :skill_id=>SWORD_SHATTER_PURSUIT,
        :target=>target.name.to_s, :def_stage=>stage, :before=>before, :after=>value,
        :percent=>SWORD_BROKEN_DEF_PERCENT})
      return value
    rescue
      return damage.to_i
    end

    def self.apply_archer_execute_bonus(user, target, obj, damage)
      value = damage.to_i
      return value if value <= 0 || obj == nil || obj.id.to_i != ARCHER_MARK_EXECUTE
      return value unless defined?(ALBERT_CG::HUMAN_RANK2_V262)
      return value unless ALBERT_CG::HUMAN_RANK2_V262.marked_for?(user, target)
      before = value
      turns_before = target.instance_variable_get(:@cg_human_v262_mark_turns).to_i
      value = [value * ARCHER_MARK_EXECUTE_PERCENT / 100, 1].max
      target.instance_variable_set(:@cg_human_v262_mark_turns, 0)
      target.instance_variable_set(:@cg_human_v262_mark_side, nil)
      target.instance_variable_set(:@cg_human_v262_mark_source, nil)
      record(user, {:kind=>:archer_rank3_execute, :skill_id=>ARCHER_MARK_EXECUTE,
        :target=>target.name.to_s, :mark_turns_before=>turns_before, :mark_consumed=>true,
        :before=>before, :after=>value, :percent=>ARCHER_MARK_EXECUTE_PERCENT})
      return value
    rescue
      return damage.to_i
    end

    def self.apply_guardian_bastion(user)
      return false if user == nil
      redirect = false
      if defined?(ALBERT_CG::HUMAN_RANK2_V262)
        redirect = ALBERT_CG::HUMAN_RANK2_V262.apply_guardian_intercept(user)
      end
      def_before = user.respond_to?(:cg_stat_stage) ? user.cg_stat_stage(:def).to_i : 0
      spd_before = user.respond_to?(:cg_stat_stage) ? user.cg_stat_stage(:spd).to_i : 0
      user.cg_change_stat_stage(:def, 1) if user.respond_to?(:cg_change_stat_stage)
      user.cg_change_stat_stage(:spd, 1) if user.respond_to?(:cg_change_stat_stage)
      def_after = user.respond_to?(:cg_stat_stage) ? user.cg_stat_stage(:def).to_i : def_before
      spd_after = user.respond_to?(:cg_stat_stage) ? user.cg_stat_stage(:spd).to_i : spd_before
      ok = redirect && def_after > def_before && spd_after > spd_before
      record(user, {:kind=>:guardian_rank3_bastion, :skill_id=>GUARDIAN_BASTION,
        :redirect=>redirect, :def_before=>def_before, :def_after=>def_after,
        :spd_before=>spd_before, :spd_after=>spd_after})
      return ok
    rescue
      return false
    end

    def self.apply_arcane_domain(user)
      return false if user == nil || !defined?(ALBERT_CG::FIELD_V233)
      spa_before = user.respond_to?(:cg_stat_stage) ? user.cg_stat_stage(:spa).to_i : 0
      user.cg_change_stat_stage(:spa, 1) if user.respond_to?(:cg_change_stat_stage)
      spa_after = user.respond_to?(:cg_stat_stage) ? user.cg_stat_stage(:spa).to_i : spa_before
      st = ALBERT_CG::FIELD_V233.state
      st.terrain = :psychic
      st.terrain_turns = ARCANE_TERRAIN_TURNS
      if defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.respond_to?(:notify_terrain_changed)
        ALBERT_CG::ABILITY_V250.notify_terrain_changed(user)
      end
      record(user, {:kind=>:mage_rank3_domain, :skill_id=>MAGE_ARCANE_DOMAIN,
        :terrain=>st.terrain, :turns=>st.terrain_turns.to_i,
        :spa_before=>spa_before, :spa_after=>spa_after})
      return st.terrain == :psychic && st.terrain_turns.to_i == ARCANE_TERRAIN_TURNS && spa_after > spa_before
    rescue
      return false
    end

    def self.apply_sanctuary(user, target)
      return false if user == nil || target == nil || !defined?(ALBERT_CG::FIELD_V233)
      side = ALBERT_CG::FIELD_V233.side_key(user)
      ALBERT_CG::FIELD_V233.set_side_effect(side, :safeguard, SANCTUARY_TURNS)
      record(user, {:kind=>:cleric_rank3_sanctuary, :skill_id=>CLERIC_SANCTUARY,
        :target=>target.name.to_s, :side=>side, :safeguard_turns=>SANCTUARY_TURNS})
      return ALBERT_CG::FIELD_V233.side_effect?(side, :safeguard)
    rescue
      return false
    end

    def self.apply_brawler_momentum(user, target, obj)
      return false if user == nil || obj == nil || obj.id.to_i != BRAWLER_GALE_COMBO
      action = user.respond_to?(:action) ? user.action : nil
      action_id = action == nil ? obj.object_id : action.object_id
      last = user.instance_variable_get(:@cg_v263_momentum_action_id)
      return false if last.to_i == action_id.to_i
      before = user.respond_to?(:cg_stat_stage) ? user.cg_stat_stage(:spe).to_i : 0
      user.cg_change_stat_stage(:spe, 1) if user.respond_to?(:cg_change_stat_stage)
      after = user.respond_to?(:cg_stat_stage) ? user.cg_stat_stage(:spe).to_i : before
      user.instance_variable_set(:@cg_v263_momentum_action_id, action_id)
      record(user, {:kind=>:brawler_rank3_momentum, :skill_id=>BRAWLER_GALE_COMBO,
        :target=>target == nil ? "" : target.name.to_s, :spe_before=>before, :spe_after=>after,
        :action_id=>action_id})
      return after > before
    rescue
      return false
    end
  end
end

class Game_Battler
  alias cg_v263_human_rank3_obj_damage make_obj_damage_value
  def make_obj_damage_value(user, obj)
    cg_v263_human_rank3_obj_damage(user, obj)
    if @hp_damage.to_i > 0 && obj != nil
      @hp_damage = ALBERT_CG::HUMAN_RANK3_V263.apply_sword_followup_bonus(user, self, obj, @hp_damage.to_i)
      @hp_damage = ALBERT_CG::HUMAN_RANK3_V263.apply_archer_execute_bonus(user, self, obj, @hp_damage.to_i)
      if @cg_last_damage_breakdown.is_a?(Hash)
        @cg_last_damage_breakdown[:human_rank3_final] = @hp_damage.to_i
      end
    end
  end

  alias cg_v263_human_rank3_skill_effect skill_effect
  def skill_effect(user, skill)
    sid = skill == nil ? 0 : skill.id.to_i
    if sid == ALBERT_CG::HUMAN_RANK3_V263::GUARDIAN_BASTION && user == self
      clear_action_results
      ALBERT_CG::HUMAN_RANK3_V263.apply_guardian_bastion(user)
      return
    elsif sid == ALBERT_CG::HUMAN_RANK3_V263::MAGE_ARCANE_DOMAIN && user == self
      clear_action_results
      ALBERT_CG::HUMAN_RANK3_V263.apply_arcane_domain(user)
      return
    end

    cg_v263_human_rank3_skill_effect(user, skill)

    if sid == ALBERT_CG::HUMAN_RANK3_V263::CLERIC_SANCTUARY
      ALBERT_CG::HUMAN_RANK3_V263.apply_sanctuary(user, self)
    elsif sid == ALBERT_CG::HUMAN_RANK3_V263::BRAWLER_GALE_COMBO &&
          !@skipped && !@missed && !@evaded && @hp_damage.to_i > 0
      ALBERT_CG::HUMAN_RANK3_V263.apply_brawler_momentum(user, self, skill)
    end
  end

  alias cg_v263_human_rank3_remove_states_battle remove_states_battle
  def remove_states_battle
    cg_v263_human_rank3_remove_states_battle
    @cg_v263_momentum_action_id = nil
  end
end

module RPG
  class Skill
    alias cg_v263_human_rank3_base_action base_action
    def base_action
      case @id.to_i
      when 119
        return "NORMAL_ATTACK"
      when 120
        return "SKILL_USE"
      when 121
        return "THROW_WEAPON"
      when 122
        return "SKILL_USE"
      when 123
        return "SKILL_ALL"
      when 124
        return "RAPID_MULTI_ATTACK"
      end
      return cg_v263_human_rank3_base_action
    end
  end
end
