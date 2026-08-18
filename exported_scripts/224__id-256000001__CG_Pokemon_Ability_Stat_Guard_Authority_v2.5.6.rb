# RMVX_SCRIPT_INDEX: 224
# RMVX_SCRIPT_ID: 256000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Stat Guard Authority v2.5.6
# RMVX_SOURCE_SHA256: 8f2aec200288131fc73e89a1ee6a08f77bfdfb688c7b193a6c595bea2791aeb8

#==============================================================================
# ■ CG Pokemon Ability Stat Guard Authority v2.5.6
#------------------------------------------------------------------------------
# 【用途】
#  建立 Ability Batch G 共用的「能力階級下降防護」與「Critical 防護」權威層，
#  讓 Clear Body / White Smoke / Keen Eye / Hyper Cutter / Big Pecks / Full Metal Body
#  不必各自在每個招式效果中插入特例；Battle Armor / Shell Armor 亦統一包在最終
#  cg_pokemon_critical? Authority 外層。
#
# 【主要設定項】
#  CRITICAL_GUARD_IDS = [4,75]
#  STAT_GUARD_TABLE：
#    29 Clear Body      -> 所有能力階級下降
#    51 Keen Eye        -> accuracy 下降
#    52 Hyper Cutter    -> atk 下降
#    73 White Smoke     -> 所有能力階級下降
#    145 Big Pecks      -> def 下降
#    230 Full Metal Body-> 所有能力階級下降
#
# 【機制規則】
#  1. 只攔截「外部來源」造成的負向 stage change。自己招式的自我 Debuff 不會被
#     Clear Body / White Smoke 等錯誤阻擋。
#  2. skill_effect 外層會記錄目前 user，故一般 Move、Unique Move 內部直接呼叫
#     cg_change_stat_stage 也能辨認敵我來源，不必逐招重寫。
#  3. Intimidate 另包裝 Ability A 的正式 apply_intimidate；Sticky Web 則包裝
#     Field v2.3.3a apply_entry_hazards，確保既有正式入口也走同一個 Stat Guard。
#  4. Critical Guard 先取得原本完整 critical 判定結果，再由 Battle Armor / Shell Armor
#     改為 false。如此 Laser Focus、高暴擊率 Move 與未來 Critical Stage 仍共用同一權威。
#  5. 所有 Ability ID 一律讀 cg_master_ability_id，尊重 Gastro Acid、Skill Swap、
#     Role Play、Transform 等既有 Battle-only Ability Override/Suppression。
#  6. Keen Eye 依現代規則除防 Accuracy drop 外，攻擊時也忽略目標的正向 Evasion stage；
#     以 calc_hit 外層暫時將目標正向 Evasion 視為 0 後呼叫既有命中 Authority。
#  7. v2.5.6 Regression 可 test-only 強制「候選 critical=true」以穩定驗證防護；
#     正式玩家戰鬥完全沿用原 RNG。
#
# 【可調參數】
#  STAT_GUARD_TABLE / CRITICAL_GUARD_IDS。一般不應在事件中修改。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須呼叫。開發或其他 Authority 若要帶來源修改能力階級：
#    ALBERT_CG::ABILITY_STAT_GUARD_V256.with_stage_source(source,:ability) do
#      target.cg_change_stat_stage(:atk,-1)
#    end
#
# 【實際範例】
#  敵方 Charm -> Hyper Cutter：Atk stage 保持不變；自己 Close Combat 類自降不阻擋。
#  敵方 Sand Attack -> Keen Eye：Accuracy stage 保持不變。
#  Laser Focus 攻擊 Battle Armor：原 Critical 判定成立後被 Ability Guard 取消。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityStatGuardAuthority"] = "2.5.6"

module ALBERT_CG
  module ABILITY_STAT_GUARD_V256
    VERSION = "2.5.6"

    ABILITY_BATTLE_ARMOR   = 4
    ABILITY_CLEAR_BODY     = 29
    ABILITY_KEEN_EYE       = 51
    ABILITY_HYPER_CUTTER   = 52
    ABILITY_WHITE_SMOKE    = 73
    ABILITY_SHELL_ARMOR    = 75
    ABILITY_BIG_PECKS      = 145
    ABILITY_FULL_METAL_BODY= 230

    CRITICAL_GUARD_IDS = [ABILITY_BATTLE_ARMOR,ABILITY_SHELL_ARMOR]
    STAT_GUARD_TABLE = {
      ABILITY_CLEAR_BODY      => :all,
      ABILITY_KEEN_EYE        => [:accuracy],
      ABILITY_HYPER_CUTTER    => [:atk],
      ABILITY_WHITE_SMOKE     => :all,
      ABILITY_BIG_PECKS       => [:def],
      ABILITY_FULL_METAL_BODY => :all,
    }

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

    def self.stage_context_stack
      @stage_context_stack = [] if @stage_context_stack == nil
      return @stage_context_stack
    end

    def self.with_stage_source(source,reason=:unknown,external=nil)
      ext = external
      if ext == nil && (source == :field || source == :hazard)
        ext = true
      end
      stage_context_stack.push({:source=>source,:reason=>reason,:external=>ext})
      begin
        return yield
      ensure
        stage_context_stack.pop
      end
    end

    def self.current_stage_context
      stack = stage_context_stack
      return nil if stack.empty?
      return stack[-1]
    rescue
      return nil
    end

    def self.external_to?(target)
      ctx = current_stage_context
      return false if ctx == nil
      return ctx[:external] == true if ctx[:external] != nil
      source = ctx[:source]
      return true if source == :field || source == :hazard
      return false if source == nil || target == nil || source.equal?(target)
      if source.respond_to?(:actor?) && target.respond_to?(:actor?)
        return source.actor? != target.actor?
      end
      return false
    rescue
      return false
    end

    def self.stat_guard_matches?(aid,key)
      spec = STAT_GUARD_TABLE[aid.to_i]
      return false if spec == nil
      return true if spec == :all
      return spec.include?(key.to_sym)
    rescue
      return false
    end

    def self.block_stat_drop?(target,key,amount)
      return false if target == nil || amount.to_i >= 0
      aid = ability_id(target)
      return false unless stat_guard_matches?(aid,key)
      return false unless external_to?(target)
      return true
    rescue
      return false
    end

    def self.critical_guard?(target)
      return CRITICAL_GUARD_IDS.include?(ability_id(target))
    rescue
      return false
    end

  def self.keen_eye_ignore_evasion?(user,target)
    return false if user == nil || target == nil
    return false unless ability_id(user) == ABILITY_KEEN_EYE
    return false unless target.respond_to?(:cg_stat_stage)
    return target.cg_stat_stage(:evasion).to_i > 0
  rescue
    return false
  end

    def self.note_activation(battler,aid,kind,context=nil)
      c = core
      ctx = context == nil ? {} : context
      if c != nil
        c.runtime_log("ABILITY_STAT_GUARD ability=" + aid.to_i.to_s +
          " battler=" + (battler == nil ? "nil" : battler.name.to_s) +
          " kind=" + kind.to_s)
        c.note_trigger(kind,battler,aid,ctx)
        c.present_trigger(battler,aid,kind,ctx)
      end
      if defined?(ALBERT_CG::ABILITY_G_V256) && ALBERT_CG::ABILITY_G_V256.respond_to?(:note_external_trigger)
        ALBERT_CG::ABILITY_G_V256.note_external_trigger(aid,battler,kind,ctx)
      end
      return true
    rescue
      return false
    end

    def self.test_force_critical?(target,user,obj=nil)
      return false unless defined?(ALBERT_CG::ABILITY_G_V256)
      return false unless ALBERT_CG::ABILITY_G_V256.respond_to?(:force_critical_candidate?)
      return ALBERT_CG::ABILITY_G_V256.force_critical_candidate?(target,user,obj)
    rescue
      return false
    end
  end
end

#------------------------------------------------------------------------------
# 所有 Move / Unique Move 的 stage change 共用 source context
#------------------------------------------------------------------------------
class Game_Battler
  alias cg_v256_statguard_skill_effect skill_effect
  def skill_effect(user,skill)
    if defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256)
      return ALBERT_CG::ABILITY_STAT_GUARD_V256.with_stage_source(user,:move,nil) do
        cg_v256_statguard_skill_effect(user,skill)
      end
    end
    return cg_v256_statguard_skill_effect(user,skill)
  end

  alias cg_v256_statguard_change_stage cg_change_stat_stage
  def cg_change_stat_stage(key,amount)
    if defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) &&
       ALBERT_CG::ABILITY_STAT_GUARD_V256.block_stat_drop?(self,key,amount)
      aid = ALBERT_CG::ABILITY_STAT_GUARD_V256.ability_id(self)
      ctx = ALBERT_CG::ABILITY_STAT_GUARD_V256.current_stage_context
      ALBERT_CG::ABILITY_STAT_GUARD_V256.note_activation(self,aid,:stat_guard,
        {:stat=>key.to_sym,:amount=>amount.to_i,:source=>(ctx == nil ? nil : ctx[:source]),
         :reason=>(ctx == nil ? :unknown : ctx[:reason])})
      return 0
    end
    return cg_v256_statguard_change_stage(key,amount)
  end

  alias cg_v256_statguard_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    if defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) &&
       ALBERT_CG::ABILITY_STAT_GUARD_V256.keen_eye_ignore_evasion?(user,self)
      cg_prepare_stat_stages if respond_to?(:cg_prepare_stat_stages)
      stages = instance_variable_get(:@cg_stat_stages)
      old = stages == nil ? 0 : stages[:evasion].to_i
      begin
        stages[:evasion] = 0 if stages != nil
        value = cg_v256_statguard_calc_hit(user,obj)
      ensure
        stages[:evasion] = old if stages != nil
      end
      aid = ALBERT_CG::ABILITY_STAT_GUARD_V256.ability_id(user)
      ALBERT_CG::ABILITY_STAT_GUARD_V256.note_activation(user,aid,:evasion_ignore,
        {:target=>self,:evasion_stage=>old})
      return value
    end
    return cg_v256_statguard_calc_hit(user,obj)
  end

  alias cg_v256_statguard_critical cg_pokemon_critical?
  def cg_pokemon_critical?(user,obj=nil)
    candidate = nil
    if defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) &&
       ALBERT_CG::ABILITY_STAT_GUARD_V256.test_force_critical?(self,user,obj)
      candidate = true
    else
      candidate = cg_v256_statguard_critical(user,obj)
    end
    if candidate && defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) &&
       ALBERT_CG::ABILITY_STAT_GUARD_V256.critical_guard?(self)
      aid = ALBERT_CG::ABILITY_STAT_GUARD_V256.ability_id(self)
      mid = 0
      if obj != nil && defined?(ALBERT_CG::MOVE_EFFECT)
        mid = ALBERT_CG::MOVE_EFFECT.move_id(obj).to_i
      end
      ALBERT_CG::ABILITY_STAT_GUARD_V256.note_activation(self,aid,:critical_guard,
        {:source=>user,:move_id=>mid})
      return false
    end
    return candidate
  end
end

#------------------------------------------------------------------------------
# Intimidate：把來源帶入 Stat Guard Authority
#------------------------------------------------------------------------------
if defined?(ALBERT_CG::ABILITY_A_V250)
  module ALBERT_CG
    module ABILITY_A_V250
      class << self
        alias cg_v256_statguard_apply_intimidate apply_intimidate
        def apply_intimidate(battler,ctx)
          return ALBERT_CG::ABILITY_STAT_GUARD_V256.with_stage_source(battler,:intimidate,nil) do
            cg_v256_statguard_apply_intimidate(battler,ctx)
          end
        end
      end
    end
  end
end

#------------------------------------------------------------------------------
# Sticky Web：Field hazard 視為外部來源
#------------------------------------------------------------------------------
if defined?(ALBERT_CG::FIELD_V233)
  module ALBERT_CG
    module FIELD_V233
      class << self
        alias cg_v256_statguard_apply_entry_hazards apply_entry_hazards
        def apply_entry_hazards(battler)
          return ALBERT_CG::ABILITY_STAT_GUARD_V256.with_stage_source(:field,:hazard,true) do
            cg_v256_statguard_apply_entry_hazards(battler)
          end
        end
      end
    end
  end
end
