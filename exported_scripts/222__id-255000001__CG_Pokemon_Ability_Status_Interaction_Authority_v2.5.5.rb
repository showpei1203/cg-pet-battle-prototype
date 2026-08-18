# RMVX_SCRIPT_INDEX: 222
# RMVX_SCRIPT_ID: 255000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Status Interaction Authority v2.5.5
# RMVX_SOURCE_SHA256: dccf24d5b720eb5ea85390c6d2b1efbc105f74a128e39f7215ec2b6f70e46594

#==============================================================================
# ■ CG Pokemon Ability Status Interaction Authority v2.5.5
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.4 Ability Batch E PASS 基底上建立「狀態互動」共用權威，提供
#  Own Tempo / Inner Focus / Vital Spirit 的狀態防護擴充、Synchronize 狀態反射，
#  以及 Own Tempo / Inner Focus 對 Intimidate 的現代規則免疫。此頁不修改已 PASS
#  Ability Core v2.5.0、Guard Authority v2.5.1 或 Batch A 原始頁。
#
# 【主要設定項】
#  GUARD_EXTENSION：
#    20 Own Tempo   -> Confusion
#    39 Inner Focus -> Flinch
#    72 Vital Spirit-> Sleep
#  SYNCHRONIZE_STATES：Poison / Bad Poison / Paralysis / Burn。
#
# 【機制規則】
#  1. 有效 Ability 一律讀 ALBERT_CG::ABILITY_V250.ability_id，尊重 Gastro Acid、
#     Skill Swap、Role Play、Transform 等 Battle-only Ability Override/Suppression。
#  2. 不改 Guard Authority 原頁，而以 method wrapper 擴充 state_guard_table；既有
#     add_state / state-record / generic ailment 三條入口因此自動吃到新 Guard。
#  3. Synchronize 在完整 skill_effect 結束後比較主要狀態 before/after，只反射
#     「本次技能新造成」的 Poison/Paralysis/Burn，不會因為舊狀態在後續每次受擊重複觸發。
#  4. Ability 主動造成狀態（Effect Spore / Poison Point / Flame Body）統一走
#     apply_status_from_ability，會先尊重 Type/status immunity，再讓 Synchronize 有機會反射。
#  5. Own Tempo / Inner Focus 依現代主系列規則免疫 Intimidate；以 wrapper 重寫
#     Batch A apply_intimidate 的 target loop，但其餘 Intimidate 行為保持一致。
#  6. Effect Spore 的粉末免疫預留 Grass / Overcoat(142) / Safety Goggles note tag；
#     Safety Goggles 日後只需讓 Held Item Weapon note 包含 <CG_SAFETY_GOGGLES>。
#
# 【可調參數】
#  無。狀態 ID 沿用 MOVE_EFFECT；Ability ID 沿用 Master Ability Catalog。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫。開發時可：
#    ALBERT_CG::ABILITY_STATUS_V255.apply_status_from_ability(target,state_id,source,:debug)
#
# 【實際範例】
#  Thunder Wave -> Synchronize Pokémon：目標新獲得 Paralysis 後，若攻擊者可被麻痺，
#  同一狀態反射給攻擊者並顯示 Ability trigger；之後普通攻擊不會再次反射舊麻痺。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityStatusInteractionAuthority"] = "2.5.5"

module ALBERT_CG
  module ABILITY_STATUS_V255
    VERSION = "2.5.5"
    ABILITY_OWN_TEMPO   = 20
    ABILITY_SYNCHRONIZE = 28
    ABILITY_INNER_FOCUS = 39
    ABILITY_VITAL_SPIRIT= 72
    ABILITY_OVERCOAT    = 142

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

    def self.move_effect
      return defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT : nil
    end

    def self.guard_extension
      m = move_effect
      return {} if m == nil
      return {
        ABILITY_OWN_TEMPO    => [m::STATE_CONFUSION],
        ABILITY_INNER_FOCUS  => [m::STATE_FLINCH],
        ABILITY_VITAL_SPIRIT => [m::STATE_SLEEP],
      }
    rescue
      return {}
    end

    def self.sync_state_ids
      m = move_effect
      return [] if m == nil
      ids = [m::STATE_POISON,m::STATE_PARALYSIS,m::STATE_BURN]
      ids.push(m::STATE_BAD_POISON) if m.const_defined?(:STATE_BAD_POISON)
      return ids
    rescue
      return []
    end

    def self.primary_state_ids
      m = move_effect
      return [] if m == nil
      return m::PRIMARY_STATES
    rescue
      return []
    end

    def self.current_sync_states(battler)
      result = []
      return result if battler == nil
      for sid in sync_state_ids
        result.push(sid) if battler.state?(sid)
      end
      return result
    rescue
      return []
    end

    def self.ailment_for_state(state_id)
      m = move_effect
      return 0 if m == nil
      sid = state_id.to_i
      return 1 if sid == m::STATE_PARALYSIS
      return 2 if sid == m::STATE_SLEEP
      return 3 if sid == m::STATE_FREEZE
      return 4 if sid == m::STATE_BURN
      return 5 if sid == m::STATE_POISON
      if m.const_defined?(:STATE_BAD_POISON) && sid == m::STATE_BAD_POISON
        return 5
      end
      return 6 if sid == m::STATE_CONFUSION
      return 0
    rescue
      return 0
    end

    def self.can_apply_state?(battler,state_id)
      return false if battler == nil || battler.hp.to_i <= 0
      return false if battler.state?(state_id.to_i)
      m = move_effect
      return true if m == nil
      ailment = ailment_for_state(state_id)
      if ailment > 0 && m.respond_to?(:can_apply_ailment?)
        return m.can_apply_ailment?(battler,ailment)
      end
      return true
    rescue
      return false
    end

    def self.push_added_state(battler,state_id)
      return if battler == nil
      arr = battler.instance_variable_get(:@added_states)
      if arr != nil && arr.respond_to?(:include?) && arr.respond_to?(:push)
        arr.push(state_id.to_i) unless arr.include?(state_id.to_i)
      end
    rescue
    end

    def self.note_activation(battler,aid,kind,context=nil)
      c = core
      ctx = context == nil ? {} : context
      if c != nil
        c.runtime_log("ABILITY_STATUS_INTERACTION ability=" + aid.to_i.to_s +
          " battler=" + (battler == nil ? "nil" : battler.name.to_s) +
          " kind=" + kind.to_s)
        c.note_trigger(kind,battler,aid,ctx)
        c.present_trigger(battler,aid,kind,ctx)
      end
      if defined?(ALBERT_CG::ABILITY_F_V255) && ALBERT_CG::ABILITY_F_V255.respond_to?(:note_external_trigger)
        ALBERT_CG::ABILITY_F_V255.note_external_trigger(aid,battler,kind,ctx)
      end
      return true
    rescue
      return false
    end

    def self.reflect_synchronize(target,source,state_id,reason=:move)
      return false if target == nil || source == nil
      return false if target.actor? == source.actor?
      return false unless ability_id(target) == ABILITY_SYNCHRONIZE
      return false unless sync_state_ids.include?(state_id.to_i)
      return false unless can_apply_state?(source,state_id)
      source.add_state(state_id.to_i)
      return false unless source.state?(state_id.to_i)
      push_added_state(source,state_id)
      ctx = {:source=>source,:target=>target,:state_id=>state_id.to_i,:reason=>reason}
      note_activation(target,ABILITY_SYNCHRONIZE,:status_reflect,ctx)
      return true
    rescue
      return false
    end

    def self.apply_status_from_ability(target,state_id,source,reason=:ability)
      return false unless can_apply_state?(target,state_id)
      target.add_state(state_id.to_i)
      return false unless target.state?(state_id.to_i)
      push_added_state(target,state_id)
      reflect_synchronize(target,source,state_id,reason)
      return true
    rescue
      return false
    end

    def self.powder_immune?(battler)
      return true if battler == nil
      m = move_effect
      if m != nil && m.respond_to?(:types_of)
        types = m.types_of(battler)
        return true if types.include?(:grass)
      end
      return true if ability_id(battler) == ABILITY_OVERCOAT
      if battler.respond_to?(:cg_held_item)
        item = battler.cg_held_item
        if item != nil && item.respond_to?(:note)
          return true if item.note.to_s.index("<CG_SAFETY_GOGGLES>") != nil
        end
      end
      return false
    rescue
      return false
    end

    def self.intimidate_immune?(battler)
      aid = ability_id(battler)
      return aid == ABILITY_OWN_TEMPO || aid == ABILITY_INNER_FOCUS
    end
  end
end

#------------------------------------------------------------------------------
# Guard Authority extension + Batch F callback
#------------------------------------------------------------------------------
if defined?(ALBERT_CG::ABILITY_GUARD_V251)
  module ALBERT_CG
    module ABILITY_GUARD_V251
      class << self
        alias cg_v255_status_state_guard_table state_guard_table
        def state_guard_table
          table = cg_v255_status_state_guard_table
          ext = ALBERT_CG::ABILITY_STATUS_V255.guard_extension
          ext.each { |aid,ids| table[aid] = ids }
          return table
        end

        alias cg_v255_status_block_state block_state
        def block_state(battler,state_id,source=:unknown)
          aid = ability_id(battler).to_i
          result = cg_v255_status_block_state(battler,state_id,source)
          if result && [20,39,72].include?(aid) && defined?(ALBERT_CG::ABILITY_F_V255) &&
             ALBERT_CG::ABILITY_F_V255.respond_to?(:note_guard_event)
            ALBERT_CG::ABILITY_F_V255.note_guard_event(aid,battler,state_id,source)
          end
          return result
        end
      end
    end
  end
end

#------------------------------------------------------------------------------
# Synchronize：只反射本次 skill_effect 新造成的合法主要狀態
#------------------------------------------------------------------------------
class Game_Battler
  alias cg_v255_status_sync_skill_effect skill_effect
  def skill_effect(user,skill)
    before = []
    if defined?(ALBERT_CG::ABILITY_STATUS_V255) &&
       ALBERT_CG::ABILITY_STATUS_V255.ability_id(self) == ALBERT_CG::ABILITY_STATUS_V255::ABILITY_SYNCHRONIZE
      before = ALBERT_CG::ABILITY_STATUS_V255.current_sync_states(self)
    end
    result = cg_v255_status_sync_skill_effect(user,skill)
    if (user != nil && !before.empty?) || (defined?(ALBERT_CG::ABILITY_STATUS_V255) &&
       ALBERT_CG::ABILITY_STATUS_V255.ability_id(self) == ALBERT_CG::ABILITY_STATUS_V255::ABILITY_SYNCHRONIZE)
      after = ALBERT_CG::ABILITY_STATUS_V255.current_sync_states(self)
      for sid in after
        next if before.include?(sid)
        ALBERT_CG::ABILITY_STATUS_V255.reflect_synchronize(self,user,sid,:move)
        break
      end
    end
    return result
  end
end

#------------------------------------------------------------------------------
# Own Tempo / Inner Focus：現代規則下免疫 Intimidate
#------------------------------------------------------------------------------
if defined?(ALBERT_CG::ABILITY_A_V250)
  module ALBERT_CG
    module ABILITY_A_V250
      class << self
        alias cg_v255_status_apply_intimidate apply_intimidate
        def apply_intimidate(battler,ctx)
          return false if battler == nil
          changed = 0
          for target in ALBERT_CG::ABILITY_V250.opponents_of(battler)
            if ALBERT_CG::ABILITY_STATUS_V255.intimidate_immune?(target)
              aid = ALBERT_CG::ABILITY_STATUS_V255.ability_id(target)
              ALBERT_CG::ABILITY_STATUS_V255.note_activation(target,aid,:intimidate_guard,
                {:source=>battler,:target=>target})
              next
            end
            next unless target.respond_to?(:cg_stat_stage) && target.respond_to?(:cg_change_stat_stage)
            before = target.cg_stat_stage(:atk).to_i
            target.cg_change_stat_stage(:atk,-1)
            after = target.cg_stat_stage(:atk).to_i
            changed += 1 if after < before
          end
          log("ABILITY_INTIMIDATE user=" + battler_token(battler) + " lowered=" + changed.to_s) if active?
          return changed > 0
        end
      end
    end
  end
end
