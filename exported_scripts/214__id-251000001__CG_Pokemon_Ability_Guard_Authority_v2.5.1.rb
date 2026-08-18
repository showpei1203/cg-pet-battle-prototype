# RMVX_SCRIPT_INDEX: 214
# RMVX_SCRIPT_ID: 251000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Guard Authority v2.5.1
# RMVX_SOURCE_SHA256: 8fa70c71f6ba84a6a2584d322b67c79ae7fa2dd2d0b42ffbc76f5cef43b42d83

#==============================================================================
# ■ CG Pokemon Ability Guard Authority v2.5.1
#------------------------------------------------------------------------------
# 【用途】
#  在已實機封版的 Ability Runtime Core v2.5.0 之上補上「狀態附加防護」共用權威，
#  供 Limber / Insomnia / Immunity / Magma Armor / Water Veil 等 Ability 使用。
#  本頁不修改 Ability Core v2.5.0，避免已 PASS 的 Entry/Damage/Contact/Switch authority
#  被後續 Ability Batch 反覆重寫。
#
# 【主要設定項】
#  STATE_GUARD_TABLE：Ability ID => 禁止附加的 State ID 清單。
#    7  Limber      -> Paralysis
#    15 Insomnia    -> Sleep
#    17 Immunity    -> Poison + Bad Poison
#    40 Magma Armor -> Freeze
#    41 Water Veil  -> Burn
#
# 【機制規則】
#  1. 有效 Ability 一律由 ALBERT_CG::ABILITY_V250.ability_id(battler) 取得，因此自動
#     尊重 Gastro Acid / Skill Swap / Role Play / Transform 等既有 Battle-only Ability
#     Override/Suppression，不直接讀物種永久 Ability。
#  2. 同時守住三條既有狀態入口：Game_Battler#add_state、v2.3.1 的
#     cg_v231_add_state_record、v2.3.0 generic cg_move_effect_apply_ailment。
#     這是為了避免「實際沒中狀態，但 @added_states 仍被寫入」造成假 Popup。
#  3. 成功擋下狀態時會寫 Ability Runtime LOG 並走 Ability Presentation Hook。
#  4. 本頁只處理狀態 Guard，不處理 Type immunity / heal；後者由 Batch B handler
#     透過 Ability Core :before_hit 正式 dispatch。
#
# 【可調參數】
#  無。State ID 直接沿用 MOVE_EFFECT 權威常數；Bad Poison 若未定義則自動略過。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須呼叫。開發時可：
#    ALBERT_CG::ABILITY_GUARD_V251.guard_state?(battler, state_id)
#
# 【實際範例】
#  Limber Pokémon 被 Thunder Wave 嘗試附加 STATE_PARALYSIS 時：
#    guard_state? => true -> 不呼叫原 add_state -> Ability 發動 LOG/Popup。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityGuardAuthority"] = "2.5.1"

module ALBERT_CG
  module ABILITY_GUARD_V251
    VERSION = "2.5.1"

    def self.state_guard_table
      return {} unless defined?(ALBERT_CG::MOVE_EFFECT)
      table = {
        7  => [ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS],
        15 => [ALBERT_CG::MOVE_EFFECT::STATE_SLEEP],
        17 => [ALBERT_CG::MOVE_EFFECT::STATE_POISON],
        40 => [ALBERT_CG::MOVE_EFFECT::STATE_FREEZE],
        41 => [ALBERT_CG::MOVE_EFFECT::STATE_BURN],
      }
      if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON)
        table[17].push(ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON)
      end
      return table
    rescue
      return {}
    end

    def self.ability_id(battler)
      return 0 unless defined?(ALBERT_CG::ABILITY_V250)
      return ALBERT_CG::ABILITY_V250.ability_id(battler).to_i
    rescue
      return 0
    end

    def self.guard_state?(battler,state_id)
      return false if battler == nil
      ids = state_guard_table[ability_id(battler)]
      return false if ids == nil
      return ids.include?(state_id.to_i)
    rescue
      return false
    end

    def self.block_state(battler,state_id,source=:unknown)
      return false unless guard_state?(battler,state_id)
      aid = ability_id(battler)
      ctx = {:state_id=>state_id.to_i,:source=>source}
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.runtime_log("ABILITY_STATE_GUARD ability=" + aid.to_s +
          " battler=" + battler.name.to_s + " state=" + state_id.to_i.to_s +
          " source=" + source.to_s)
        ALBERT_CG::ABILITY_V250.note_trigger(:state_guard,battler,aid,ctx)
        ALBERT_CG::ABILITY_V250.present_trigger(battler,aid,:state_guard,ctx)
      end
      if defined?(ALBERT_CG::ABILITY_B_V251) && ALBERT_CG::ABILITY_B_V251.respond_to?(:note_guard_event)
        ALBERT_CG::ABILITY_B_V251.note_guard_event(aid,battler,state_id,source)
      end
      return true
    rescue
      return true
    end
  end
end

class Game_Battler
  alias cg_v251_ability_guard_add_state add_state
  def add_state(state_id)
    if defined?(ALBERT_CG::ABILITY_GUARD_V251) &&
       ALBERT_CG::ABILITY_GUARD_V251.block_state(self,state_id,:add_state)
      return
    end
    return cg_v251_ability_guard_add_state(state_id)
  end

  if method_defined?(:cg_v231_add_state_record)
    alias cg_v251_ability_guard_add_state_record cg_v231_add_state_record
    def cg_v231_add_state_record(state_id)
      if defined?(ALBERT_CG::ABILITY_GUARD_V251) &&
         ALBERT_CG::ABILITY_GUARD_V251.block_state(self,state_id,:state_record)
        return false
      end
      return cg_v251_ability_guard_add_state_record(state_id)
    end
  end

  if method_defined?(:cg_move_effect_apply_ailment)
    alias cg_v251_ability_guard_apply_ailment cg_move_effect_apply_ailment
    def cg_move_effect_apply_ailment(user,move_id)
      if defined?(ALBERT_CG::MOVE_EFFECT) && defined?(ALBERT_CG::ABILITY_GUARD_V251)
        ailment = ALBERT_CG::MOVE_EFFECT.ailment_id(move_id)
        state_id = ALBERT_CG::MOVE_EFFECT::AILMENT_TO_STATE[ailment.to_i]
        if state_id != nil && ALBERT_CG::ABILITY_GUARD_V251.block_state(self,state_id,:move_ailment)
          return
        end
      end
      return cg_v251_ability_guard_apply_ailment(user,move_id)
    end
  end
end
