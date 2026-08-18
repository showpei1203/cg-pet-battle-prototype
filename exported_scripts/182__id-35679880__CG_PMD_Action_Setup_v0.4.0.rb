# RMVX_SCRIPT_INDEX: 182
# RMVX_SCRIPT_ID: 35679880
# RMVX_SCRIPT_NAME: CG PMD Action Setup v0.4.0
# RMVX_SOURCE_SHA256: 92f68fd53d0fa9f9fa9e2ec52ad92e7f74312a030e46f918850fdb71cc4a1db2

#==============================================================================
# ■ CG_PMD_Action_Setup.rb  v0.4.0
#------------------------------------------------------------------------------
# 【用途】
#  將 Tankentai SBS 技能流程接到 PMD Native 身體動作。
#  v0.4.0 在既有 melee / stationary / shoot / charge / pose 分類上新增：
#    1. 每次技能依使用者 Species + Move 選擇 Native Action。
#    2. Native Action 缺失時使用 Move Effect Core 的 fallback chain。
#    3. 2～10 Hit 技能使用真正重複 OBJ_ANIM_WEIGHT，逐 Hit 傷害／狀態判定。
#
# 【PMD 技能流程】
#  melee：
#    接近目標 -> Native Action -> HitFrame -> 傷害 -> ... -> 返回
#  stationary / shoot / charge：
#    原地 Native Action -> HitFrame -> 傷害
#  pose：
#    Native Action 播放到結束 -> 套用效果
#
# 【多段攻擊】
#  Move Metadata min_hits/max_hits > 0 時，skill_sequence_for 會在行動開始時
#  抽出本次 hit count，並選擇 CG_PMD_MULTI_*_2～10。
#  每一 Hit 都重新：
#    Native Action -> HitFrame -> OBJ_ANIM_WEIGHT
#  因此 Critical、Secondary Effect、Drain、Recoil 都有逐 Hit Runtime 入口。
#
# 【專用技能／Species 特調】
#  ALBERT_CG::MOVE_EFFECT::SPECIES_MOVE_NATIVE_ACTION 可指定：
#    25 => { 85 => ["Shock","Shoot","Charge"] }
#  若 Pikachu PMD 有 Shock 就使用；沒有就自動退回 Shoot / Charge。
#
# 【人類】
#  不受影響。人類仍走 RPG::Skill 原本 Tankentai base_action，
#  後續六職業技能直接使用 SBS 預設近戰／遠程／施法分類。
#==============================================================================

module N01
  ANIME.merge!({
    "PMD_IDLE"             => ["pmd_idle", :auto],
    "PMD_HURT_WAIT"        => ["pmd", "Hurt", :auto, false, :end, nil],
    "PMD_FAINT_WAIT"       => ["pmd", "Faint", :auto, false, :end, nil],
    "PMD_ATTACK_HIT"       => ["pmd", "Attack", :auto, false, :hit, nil],
    "PMD_SHOOT_HIT"        => ["pmd", "Shoot", :auto, false, :hit, nil],
    "PMD_CHARGE_HIT"       => ["pmd", "Charge", :auto, false, :hit, nil],
    "PMD_POSE_END"         => ["pmd", "Pose", :auto, false, :end, nil],
    "PMD_SKILL_NATIVE_HIT" => ["pmd_skill_native", :hit],
    "PMD_SKILL_NATIVE_END" => ["pmd_skill_native", :end],
    "PMD_WAIT_END"         => ["pmd_wait", :end],
    "PMD_WAIT_RETURN"      => ["pmd_wait", :return],
    "PMD_VIEW_FRONT"       => ["pmd_view", :front],
    "PMD_VIEW_BACK"        => ["pmd_view", :back],
    "PMD_VIEW_BATTLE"      => ["pmd_view", :battle],
    "PMD_MIRROR_SBS"       => ["pmd_mirror", :sbs],
  })

  ACTION.merge!({
    "CG_PMD_TEST_ATTACK" => [
      "PMD_ATTACK_HIT", "OBJ_ANIM", "PMD_WAIT_END", "PMD_IDLE",
    ],

    "CG_PMD_NORMAL_ATTACK" => [
      "PREV_MOVING_TARGET", "PMD_ATTACK_HIT", "OBJ_ANIM_WEIGHT",
      "PMD_WAIT_END", "Can Collapse", "FLEE_RESET",
    ],

    "CG_PMD_SKILL_MELEE" => [
      "PREV_MOVING_TARGET", "PMD_SKILL_NATIVE_HIT", "OBJ_ANIM_WEIGHT",
      "PMD_WAIT_END", "Can Collapse", "FLEE_RESET",
    ],

    "CG_PMD_SKILL_ATTACK_STAY" => [
      "PMD_SKILL_NATIVE_HIT", "OBJ_ANIM_WEIGHT",
      "PMD_WAIT_END", "Can Collapse", "COORD_RESET",
    ],

    "CG_PMD_SKILL_SHOOT" => [
      "PMD_SKILL_NATIVE_HIT", "OBJ_ANIM_WEIGHT",
      "PMD_WAIT_END", "Can Collapse", "COORD_RESET",
    ],

    "CG_PMD_SKILL_CHARGE" => [
      "PMD_SKILL_NATIVE_HIT", "OBJ_ANIM_WEIGHT",
      "PMD_WAIT_END", "Can Collapse", "COORD_RESET",
    ],

    "CG_PMD_SKILL_POSE" => [
      "PMD_SKILL_NATIVE_END", "OBJ_ANIM_WEIGHT",
      "Can Collapse", "COORD_RESET",
    ],
  })

  #--------------------------------------------------------------------------
  # 真正多段攻擊 Sequence：2～10 Hit。
  #--------------------------------------------------------------------------
  for hits in 2..10
    body = ["PREV_MOVING_TARGET"]
    hits.times do |index|
      body.push("PMD_SKILL_NATIVE_HIT")
      body.push("OBJ_ANIM_WEIGHT")
      body.push("4") if index < hits - 1
    end
    body.push("PMD_WAIT_END")
    body.push("Can Collapse")
    body.push("FLEE_RESET")
    ACTION["CG_PMD_MULTI_MELEE_" + hits.to_s] = body

    body = []
    hits.times do |index|
      body.push("PMD_SKILL_NATIVE_HIT")
      body.push("OBJ_ANIM_WEIGHT")
      body.push("4") if index < hits - 1
    end
    body.push("PMD_WAIT_END")
    body.push("Can Collapse")
    body.push("COORD_RESET")
    ACTION["CG_PMD_MULTI_STAY_" + hits.to_s] = body

    body = []
    hits.times do |index|
      body.push("PMD_SKILL_NATIVE_HIT")
      body.push("OBJ_ANIM_WEIGHT")
      body.push("4") if index < hits - 1
    end
    body.push("PMD_WAIT_END")
    body.push("Can Collapse")
    body.push("COORD_RESET")
    ACTION["CG_PMD_MULTI_SHOOT_" + hits.to_s] = body

    body = []
    hits.times do |index|
      body.push("PMD_SKILL_NATIVE_HIT")
      body.push("OBJ_ANIM_WEIGHT")
      body.push("4") if index < hits - 1
    end
    body.push("PMD_WAIT_END")
    body.push("Can Collapse")
    body.push("COORD_RESET")
    ACTION["CG_PMD_MULTI_CHARGE_" + hits.to_s] = body
  end
end

module CG_PMD
  SKILL_MOTION_TABLE = {
    600 => :stationary_attack,
    601 => :shoot,
    602 => :shoot,
    607 => :melee_attack,
    608 => :shoot,
    612 => :melee_attack,
    617 => :shoot,
    653 => :shoot,
    618 => :pose,
    654 => :melee_attack,
  }

  SKILL_SEQUENCE_TABLE = {
    :melee_attack      => "CG_PMD_SKILL_MELEE",
    :stationary_attack => "CG_PMD_SKILL_ATTACK_STAY",
    :shoot             => "CG_PMD_SKILL_SHOOT",
    :charge            => "CG_PMD_SKILL_CHARGE",
    :pose              => "CG_PMD_SKILL_POSE",
  }

  def self.skill_note_motion(skill)
    return nil if skill == nil || !skill.respond_to?(:note)
    text = skill.note.to_s
    if text =~ /<pmd_motion\s*:\s*([a-z_]+)\s*>/i
      value = $1.to_s.downcase
      return :melee_attack if value == "melee" || value == "melee_attack"
      return :stationary_attack if value == "attack" || value == "stationary_attack"
      return :shoot if value == "shoot"
      return :charge if value == "charge" || value == "cast"
      return :pose if value == "pose" || value == "guard"
    end
    return nil
  end

  def self.skill_range_for(skill)
    return nil if skill == nil
    if skill.respond_to?(:cg_range_type)
      value = skill.cg_range_type
      return value unless value == nil
    end
    text = skill.respond_to?(:note) ? skill.note.to_s : ""
    return :melee if text =~ /<cg_range\s*:\s*melee\s*>/i
    return :ranged if text =~ /<cg_range\s*:\s*ranged\s*>/i
    return nil
  end

  def self.skill_combat_class_for(skill)
    return nil if skill == nil
    if defined?(ALBERT_CG) && defined?(ALBERT_CG::POKEMON_COMBAT_DATA)
      data = ALBERT_CG::POKEMON_COMBAT_DATA.skill_data(skill.id)
      return data[:class] if data != nil && data[:class] != nil
    end
    return :physical if skill.respond_to?(:physical_attack) && skill.physical_attack
    return nil
  end

  def self.skill_motion_for(skill)
    return :charge if skill == nil
    note_motion = skill_note_motion(skill)
    return note_motion unless note_motion == nil
    table_motion = SKILL_MOTION_TABLE[skill.id.to_i]
    return table_motion unless table_motion == nil

    # v2.2 Master Data 已對 937 招建立初步 motion hint。
    if defined?(ALBERT_CG::POKEMON_MASTER)
      mid = ALBERT_CG::POKEMON_MASTER.move_id_for_skill(skill.id).to_i
      return ALBERT_CG::POKEMON_MASTER.move_motion_hint(mid) if mid > 0
    end

    combat_class = skill_combat_class_for(skill)
    range = skill_range_for(skill)
    if combat_class == :physical
      return :melee_attack if range == :melee
      return :shoot if range == :ranged
      return :melee_attack
    elsif combat_class == :special
      return :shoot
    elsif combat_class == :status
      return :charge
    end
    return :charge
  end

  def self.multi_sequence_name(motion, hits)
    hits = [[hits.to_i, 2].max, 10].min
    case motion
    when :melee_attack
      return "CG_PMD_MULTI_MELEE_" + hits.to_s
    when :stationary_attack
      return "CG_PMD_MULTI_STAY_" + hits.to_s
    when :shoot
      return "CG_PMD_MULTI_SHOOT_" + hits.to_s
    when :charge
      return "CG_PMD_MULTI_CHARGE_" + hits.to_s
    end
    return nil
  end

  def self.skill_sequence_for(skill, battler = nil)
    motion = skill_motion_for(skill)

    native = case motion
    when :melee_attack, :stationary_attack then "Attack"
    when :shoot then "Shoot"
    when :pose then "Pose"
    else "Charge"
    end

    if battler != nil && defined?(ALBERT_CG::MOVE_EFFECT)
      native = ALBERT_CG::MOVE_EFFECT.resolve_native_action(battler, skill, motion)
    end
    battler.instance_variable_set(:@cg_pmd_pending_native_action, native) if battler != nil

    if defined?(ALBERT_CG::MOVE_EFFECT)
      mid = ALBERT_CG::MOVE_EFFECT.move_id(skill)
      if mid > 0
        hits = ALBERT_CG::MOVE_EFFECT.multi_hit_count(mid)
        battler.instance_variable_set(:@cg_pmd_pending_multi_hits, hits) if battler != nil
        if hits > 1
          sequence = multi_sequence_name(motion, hits)
          return sequence unless sequence == nil
        end
      end
    end

    return SKILL_SEQUENCE_TABLE[motion] || "CG_PMD_SKILL_CHARGE"
  end
end

class Game_Actor < Game_Battler
  alias cg_pmd_non_weapon_action non_weapon
  def non_weapon
    return "CG_PMD_NORMAL_ATTACK" if respond_to?(:cg_pmd_enabled?) && cg_pmd_enabled?
    return cg_pmd_non_weapon_action
  end
end

class Game_Enemy < Game_Battler
  alias cg_pmd_enemy_base_action base_action
  def base_action
    return "CG_PMD_NORMAL_ATTACK" if respond_to?(:cg_pmd_enabled?) && cg_pmd_enabled?
    return cg_pmd_enemy_base_action
  end
end

module RPG
  class Skill
    alias cg_pmd_native_skill_base_action base_action
    def base_action
      battler = nil
      begin
        battler = $scene.instance_variable_get(:@active_battler) if
          defined?($scene) && $scene != nil
      rescue
        battler = nil
      end

      if battler != nil && battler.respond_to?(:cg_pmd_enabled?) &&
         battler.cg_pmd_enabled?
        sequence = CG_PMD.skill_sequence_for(self, battler)
        if defined?(CG_PMD_BATTLE_INIT_TRACE)
          native = battler.instance_variable_get(:@cg_pmd_pending_native_action)
          hits = battler.instance_variable_get(:@cg_pmd_pending_multi_hits)
          CG_PMD_BATTLE_INIT_TRACE.log(
            "SKILL_SEQUENCE battler=" + battler.name.to_s +
            " skill=" + self.id.to_s + ":" + self.name.to_s +
            " motion=" + CG_PMD.skill_motion_for(self).to_s +
            " native=" + native.to_s +
            " hits=" + (hits == nil ? "1" : hits.to_s) +
            " sequence=" + sequence.to_s)
        end
        return sequence
      end
      return cg_pmd_native_skill_base_action
    end
  end
end
