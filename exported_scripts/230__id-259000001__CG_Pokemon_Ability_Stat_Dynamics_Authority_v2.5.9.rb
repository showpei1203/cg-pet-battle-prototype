# RMVX_SCRIPT_INDEX: 230
# RMVX_SCRIPT_ID: 259000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Stat Dynamics Authority v2.5.9
# RMVX_SOURCE_SHA256: 490e2dd23c6aeaec53787440075f3cf53310f0c640c96bf57488ebd88094e0de

#==============================================================================
# ■ CG Pokemon Ability Stat Dynamics Authority v2.5.9
#------------------------------------------------------------------------------
# 【用途】
#  建立 Ability Batch J 共用的「能力階級轉換／下降反應／畏縮反應／暴擊反應／
#  回合末 Moody／換出回復」權威層，正式支援 Simple、Contrary、Defiant、
#  Competitive、Steadfast、Anger Point、Moody、Regenerator。
#
# 【主要設定項】
#  MOODY_STATS = [:atk,:def,:spa,:spd,:spe]：依現代主系列規則，Moody 不再抽
#  Accuracy / Evasion；每回合 +2 一項、-1 另一項。
#  REGENERATOR_PERCENT = 33：換出時回復約 MaxHP 1/3。
#
# 【機制規則】
#  1. Simple：任何實際套用到自己的 stage change 數值 x2，正負皆適用。
#  2. Contrary：任何實際套用到自己的 stage change 反向；既有 stage 不倒轉。
#  3. Defiant / Competitive：只有「敵方來源」真正造成負 stage delta 後觸發；
#     每個被下降的 stat 各觸發一次，分別 ATK +2 / SPA +2。自我下降與同伴下降不觸發。
#  4. Steadfast：Flinch state 真正新增後 SPE +1；若被 Inner Focus 等阻擋則不觸發。
#  5. Anger Point：受到正式 Critical 後將 ATK stage 直接補到 +6；已 +6 不重複。
#  6. Moody：Ability Core end_turn 觸發。正式戰鬥隨機挑合法 +2 stat，再挑不同的
#     合法 -1 stat；Regression 才可由 Batch J 提供 deterministic pair。
#  7. Regenerator：Ability Core switch_out 觸發，換出前回復 MaxHP 約 1/3，
#     不把 Storage 當 reserve，也不寫回永久 Clone 戰鬥外 HP。
#  8. Ability ID 一律透過 cg_master_ability_id，尊重 Gastro Acid / Skill Swap /
#     Role Play / Transform 的 Battle-only Override / Suppression。
#  9. stage source 直接沿用 v2.5.6 Stat Guard Authority context，不另造敵我判定。
#
# 【可調參數】
#  MOODY_STATS / REGENERATOR_PERCENT。一般事件不應修改。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須呼叫。開發可直接：
#    target.cg_change_stat_stage(:def,-1)
#  若要標明來源，沿用：
#    ALBERT_CG::ABILITY_STAT_GUARD_V256.with_stage_source(user,:move,nil) { ... }
#
# 【實際範例】
#  Sand Attack -> Simple：Accuracy -2；Sand Attack -> Contrary：Accuracy +1。
#  敵方 Screech -> Defiant：Def 下降後 ATK +2；Teleport 換出 Regenerator：回復 1/3。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityStatDynamicsAuthority"] = "2.5.9"

module ALBERT_CG
  module ABILITY_STAT_DYNAMICS_V259
    VERSION = "2.5.9"

    ABILITY_STEADFAST    = 80
    ABILITY_ANGER_POINT = 83
    ABILITY_SIMPLE       = 86
    ABILITY_CONTRARY     = 126
    ABILITY_DEFIANT      = 128
    ABILITY_MOODY        = 141
    ABILITY_REGENERATOR  = 144
    ABILITY_COMPETITIVE  = 172

    MOODY_STATS = [:atk,:def,:spa,:spd,:spe]
    REGENERATOR_PERCENT = 33

    def self.core
      return defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil
    end

    def self.ability_id(battler)
      c = core
      return 0 if c == nil
      return c.ability_id(battler).to_i
    rescue
      return 0
    end

    def self.stage_guard
      return defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) ? ALBERT_CG::ABILITY_STAT_GUARD_V256 : nil
    end

    def self.external_to?(battler)
      sg = stage_guard
      return false if sg == nil
      return sg.external_to?(battler)
    rescue
      return false
    end

    def self.note_activation(battler,aid,kind,ctx=nil)
      c = core
      data = ctx == nil ? {} : ctx
      if c != nil
        c.runtime_log("ABILITY_STAT_DYNAMICS ability=" + aid.to_i.to_s +
          " battler=" + (battler == nil ? "nil" : battler.name.to_s) +
          " kind=" + kind.to_s)
        c.note_trigger(kind,battler,aid,data)
        c.present_trigger(battler,aid,kind,data)
      end
      if defined?(ALBERT_CG::ABILITY_J_V259) && ALBERT_CG::ABILITY_J_V259.respond_to?(:note_external_trigger)
        ALBERT_CG::ABILITY_J_V259.note_external_trigger(aid,battler,kind,data)
      end
      return true
    rescue
      return false
    end

    def self.transform_stage_amount(battler,key,amount)
      aid = ability_id(battler)
      raw = amount.to_i
      if aid == ABILITY_SIMPLE
        return raw * 2
      elsif aid == ABILITY_CONTRARY
        return -raw
      end
      return raw
    rescue
      return amount.to_i
    end

    def self.note_transform_if_needed(battler,aid,key,raw,used,delta)
      return false if delta.to_i == 0
      return false unless aid.to_i == ABILITY_SIMPLE || aid.to_i == ABILITY_CONTRARY
      kind = aid.to_i == ABILITY_SIMPLE ? :simple_stage : :contrary_stage
      return note_activation(battler,aid,kind,
        {:stat=>key.to_sym,:requested=>raw.to_i,:applied_request=>used.to_i,:delta=>delta.to_i})
    end

    def self.react_to_external_drop(battler,key,delta)
      return false if battler == nil || delta.to_i >= 0
      return false unless external_to?(battler)
      aid = ability_id(battler)
      boost_stat = nil
      boost_amount = 0
      if aid == ABILITY_DEFIANT
        boost_stat = :atk
        boost_amount = 2
      elsif aid == ABILITY_COMPETITIVE
        boost_stat = :spa
        boost_amount = 2
      else
        return false
      end
      before = battler.respond_to?(:cg_stat_stage) ? battler.cg_stat_stage(boost_stat).to_i : 0
      changed = battler.respond_to?(:cg_change_stat_stage) ? battler.cg_change_stat_stage(boost_stat,boost_amount).to_i : 0
      after = battler.respond_to?(:cg_stat_stage) ? battler.cg_stat_stage(boost_stat).to_i : before
      return false if changed == 0
      kind = aid == ABILITY_DEFIANT ? :defiant : :competitive
      note_activation(battler,aid,kind,
        {:lowered_stat=>key.to_sym,:lowered_delta=>delta.to_i,:boost_stat=>boost_stat,
         :before=>before,:after=>after})
      return true
    rescue
      return false
    end

    def self.apply_steadfast(battler)
      return false if battler == nil || ability_id(battler) != ABILITY_STEADFAST
      return false unless battler.respond_to?(:cg_change_stat_stage)
      before = battler.cg_stat_stage(:spe).to_i
      delta = battler.cg_change_stat_stage(:spe,1).to_i
      after = battler.cg_stat_stage(:spe).to_i
      return false if delta == 0
      note_activation(battler,ABILITY_STEADFAST,:steadfast,
        {:before=>before,:after=>after,:state=>defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_FLINCH : 48})
      return true
    rescue
      return false
    end

    def self.apply_anger_point(battler,ctx)
      return false if battler == nil
      return false unless battler.instance_variable_get(:@critical) == true
      return false unless battler.respond_to?(:cg_stat_stage) && battler.respond_to?(:cg_change_stat_stage)
      before = battler.cg_stat_stage(:atk).to_i
      return false if before >= 6
      delta = battler.cg_change_stat_stage(:atk,6-before).to_i
      after = battler.cg_stat_stage(:atk).to_i
      return false if delta == 0
      ctx[:anger_point_before] = before
      ctx[:anger_point_after] = after
      return note_activation(battler,ABILITY_ANGER_POINT,:anger_point,
        {:before=>before,:after=>after,:move_id=>ctx[:move_id].to_i,:user=>ctx[:user]})
    rescue
      return false
    end

    def self.moody_pair(battler)
      if defined?(ALBERT_CG::ABILITY_J_V259) && ALBERT_CG::ABILITY_J_V259.respond_to?(:test_moody_pair)
        pair = ALBERT_CG::ABILITY_J_V259.test_moody_pair(battler)
        return pair if pair != nil
      end
      ups = MOODY_STATS.select { |k| battler.cg_stat_stage(k).to_i < 6 }
      return nil if ups.empty?
      up = ups[rand(ups.size)]
      downs = MOODY_STATS.select { |k| k != up && battler.cg_stat_stage(k).to_i > -6 }
      return nil if downs.empty?
      down = downs[rand(downs.size)]
      return [up,down]
    rescue
      return nil
    end

    def self.apply_moody(battler,ctx)
      return false if battler == nil || !battler.respond_to?(:cg_change_stat_stage)
      pair = moody_pair(battler)
      return false if pair == nil
      up = pair[0].to_sym
      down = pair[1].to_sym
      up_before = battler.cg_stat_stage(up).to_i
      down_before = battler.cg_stat_stage(down).to_i
      up_delta = battler.cg_change_stat_stage(up,2).to_i
      down_delta = battler.cg_change_stat_stage(down,-1).to_i
      return false if up_delta == 0 && down_delta == 0
      data = {:up_stat=>up,:up_before=>up_before,:up_after=>battler.cg_stat_stage(up).to_i,
              :down_stat=>down,:down_before=>down_before,:down_after=>battler.cg_stat_stage(down).to_i}
      ctx[:moody] = data
      return note_activation(battler,ABILITY_MOODY,:moody,data)
    rescue
      return false
    end

    def self.apply_regenerator(battler,ctx)
      return false if battler == nil || battler.hp.to_i <= 0
      maxhp = battler.maxhp.to_i
      before = battler.hp.to_i
      return false if before >= maxhp
      heal = [maxhp / 3,1].max
      battler.hp = [before + heal,maxhp].min
      actual = battler.hp.to_i - before
      return false if actual <= 0
      data = {:before=>before,:after=>battler.hp.to_i,:heal=>actual,:maxhp=>maxhp}
      ctx[:regenerator] = data
      return note_activation(battler,ABILITY_REGENERATOR,:regenerator,data)
    rescue
      return false
    end
  end
end

#------------------------------------------------------------------------------
# stage transform + drop reaction：包在已 PASS v2.5.6 Stat Guard 外層。
#------------------------------------------------------------------------------
class Game_Battler
  alias cg_v259_statdynamics_change_stage cg_change_stat_stage
  def cg_change_stat_stage(key,amount)
    unless defined?(ALBERT_CG::ABILITY_STAT_DYNAMICS_V259)
      return cg_v259_statdynamics_change_stage(key,amount)
    end
    auth = ALBERT_CG::ABILITY_STAT_DYNAMICS_V259
    aid = auth.ability_id(self)
    raw = amount.to_i
    used = auth.transform_stage_amount(self,key,raw)
    delta = cg_v259_statdynamics_change_stage(key,used)
    auth.note_transform_if_needed(self,aid,key,raw,used,delta)
    auth.react_to_external_drop(self,key,delta)
    return delta
  end

  alias cg_v259_statdynamics_add_state add_state
  def add_state(state_id)
    flinch_id = defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_FLINCH : 48
    was = state?(flinch_id)
    result = cg_v259_statdynamics_add_state(state_id)
    if state_id.to_i == flinch_id.to_i && !was && state?(flinch_id) &&
       defined?(ALBERT_CG::ABILITY_STAT_DYNAMICS_V259)
      ALBERT_CG::ABILITY_STAT_DYNAMICS_V259.apply_steadfast(self)
    end
    return result
  end
end

#------------------------------------------------------------------------------
# Core lifecycle registration
#------------------------------------------------------------------------------
if defined?(ALBERT_CG::ABILITY_V250)
  ALBERT_CG::ABILITY_V250.register(83,:after_damage,ALBERT_CG::ABILITY_STAT_DYNAMICS_V259,:apply_anger_point)
  ALBERT_CG::ABILITY_V250.register(141,:end_turn,ALBERT_CG::ABILITY_STAT_DYNAMICS_V259,:apply_moody)
  ALBERT_CG::ABILITY_V250.register(144,:switch_out,ALBERT_CG::ABILITY_STAT_DYNAMICS_V259,:apply_regenerator)
end
