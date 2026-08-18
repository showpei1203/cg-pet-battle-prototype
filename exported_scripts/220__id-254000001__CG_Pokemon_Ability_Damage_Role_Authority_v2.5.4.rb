# RMVX_SCRIPT_INDEX: 220
# RMVX_SCRIPT_ID: 254000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Damage Role Authority v2.5.4
# RMVX_SOURCE_SHA256: 9d07c224bd48254a4154385e5cefcb0f52bb4a3ef00c7931316632de3d310c46

#==============================================================================
# ■ CG Pokemon Ability Damage Role Authority v2.5.4
#------------------------------------------------------------------------------
# 【用途】
#  擴充 v2.5.3 Ability Modifier Authority 的 :damage_modify lifecycle，讓「防守方」也能
#  在最終 HP 傷害真正套用前取得一次正式 Ability modifier 查詢。v2.5.3 原 Authority
#  已負責攻擊方 role=:attacker；本頁只補 defender role，不修改已 PASS 原頁。
#
# 【主要設定項】
#  無固定倍率。實際 Thick Fat / Heatproof / Filter / Solid Rock 等倍率由 Ability Batch
#  handler 決定。
#
# 【機制規則】
#  1. 只處理 @hp_damage > 0 的直接 HP 傷害。
#  2. 建立 context：user / target / skill / move_id / type_id / type_rate / damage /
#     raw_damage / fixed_damage / role=:defender。
#  3. 先讓 target 的有效 Ability dispatch :damage_modify，再交回 v2.5.3 攻擊方 modifier
#     與既有 Ability Core before_damage / Substitute / Sturdy / Grudge 等 chain。
#  4. 有效 Ability 仍由 cg_master_ability_id 決定，尊重 Gastro Acid / Skill Swap /
#     Role Play / Transform 等 Battle-only override/suppression。
#  5. Fixed Damage 仍會提供 context，但各 Ability handler 應自行排除不該吃倍率者。
#
# 【可調參數】
#  無。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。Batch handler 可註冊：
#    ALBERT_CG::ABILITY_V250.register(47,:damage_modify,MyBatch,:apply_thick_fat)
#
# 【實際範例】
#  Flamethrower 命中 Thick Fat 目標：defender context 先將 damage x0.5，再交回既有
#  damage lifecycle；正式傷害仍由同一個 execute_damage chain 完成。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityDamageRoleAuthority"] = "2.5.4"

module ALBERT_CG
  module ABILITY_DAMAGE_ROLE_V254
    VERSION = "2.5.4"

    def self.type_rate_for(target,type_id)
      return 100 if target == nil || type_id.to_i <= 0
      return target.cg_pokemon_type_rate_percent(type_id.to_i).to_i if
        target.respond_to?(:cg_pokemon_type_rate_percent)
      return 100
    rescue
      return 100
    end
  end
end

class Game_Battler
  alias cg_v254_ability_defender_damage_modify execute_damage
  def execute_damage(user)
    if defined?(ALBERT_CG::ABILITY_V250) && defined?(ALBERT_CG::ABILITY_MODIFIER_V253) &&
       defined?(ALBERT_CG::ABILITY_DAMAGE_ROLE_V254) && user != nil && @hp_damage.to_i > 0
      skill = ALBERT_CG::ABILITY_V250.current_skill(user)
      type_id = ALBERT_CG::ABILITY_MODIFIER_V253.type_id_for_action(user,skill)
      ctx = {
        :user=>user, :target=>self, :skill=>skill,
        :move_id=>ALBERT_CG::ABILITY_V250.current_move_id(user),
        :type_id=>type_id.to_i,
        :type_rate=>ALBERT_CG::ABILITY_DAMAGE_ROLE_V254.type_rate_for(self,type_id),
        :damage=>@hp_damage.to_i, :raw_damage=>@hp_damage.to_i,
        :fixed_damage=>ALBERT_CG::ABILITY_MODIFIER_V253.skill_fixed_damage?(skill),
        :role=>:defender
      }
      ALBERT_CG::ABILITY_V250.dispatch(:damage_modify,self,ctx)
      @hp_damage = ctx[:damage].to_i if ctx.has_key?(:damage)
    end
    return cg_v254_ability_defender_damage_modify(user)
  end
end
