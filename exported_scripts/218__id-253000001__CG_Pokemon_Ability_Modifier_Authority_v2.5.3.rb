# RMVX_SCRIPT_INDEX: 218
# RMVX_SCRIPT_ID: 253000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Modifier Authority v2.5.3
# RMVX_SOURCE_SHA256: d289af7bc659f260363b56bf672967496c8a0182e580cc42f492ae7a616de3d8

#==============================================================================
# ■ CG Pokemon Ability Modifier Authority v2.5.3
#------------------------------------------------------------------------------
# 【用途】
#  建立 Ability 的「有效能力值查詢」與「最終傷害倍率」共用 Authority，供 Huge Power、
#  Guts、Marvel Scale、Overgrow 等被動特性共用。此頁不綁死特定 8 個 Ability 效果，
#  只提供 Ability Runtime Core 可註冊的新 lifecycle trigger 與最終數值接點。
#
# 【主要設定項】
#  新增 Ability Core trigger：
#    :stat_query     有效 ATK/DEF 查詢完成後，可修改 context[:value]。
#    :damage_modify  造成正 HP 傷害、真正 execute_damage 前，可修改 context[:damage]。
#
# 【機制規則】
#  1. 不修改 v2.5.0 Ability Runtime Core 原始腳本；本頁在載入時只向既有 TRIGGERS
#     陣列追加兩個 trigger，讓已 PASS 的 Core 原頁保持 exact unchanged。
#  2. cg_atk_stat / cg_def_stat 先完整走既有 Stat Stage、Burn、Field 等 Runtime，
#     再 dispatch :stat_query，因此 Ability 只疊在「有效值」最外層。
#  3. execute_damage 外層只處理 @hp_damage > 0。先讓攻擊者 dispatch :damage_modify，
#     再交回 Ability Core / Substitute / Sturdy / Grudge 等既有 damage lifecycle。
#  4. context 同時帶 user / target / skill / move_id / type_id / damage / role，後續
#     Thick Fat、Filter、Solid Rock、Adaptability 等 Ability 可沿用，不必再 alias 核心。
#  5. 有效 Ability 一律仍由 Ability Runtime Core 的 cg_master_ability_id 判定，因此
#     Gastro Acid / Skill Swap / Role Play / Transform 等 Battle-only Override/Suppression
#     會自然生效。
#
# 【可調參數】
#  本 Authority 無固定倍率；所有倍率由各 Ability Batch handler 決定。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。Ability Batch 可：
#    ALBERT_CG::ABILITY_V250.register(37,:stat_query,MyBatch,:apply_huge_power)
#    ALBERT_CG::ABILITY_V250.register(65,:damage_modify,MyBatch,:apply_overgrow)
#
# 【實際範例】
#  Huge Power handler：ctx[:stat]==:atk 時把 ctx[:value] x2。
#  Overgrow handler：HP<=1/3 且 Move 為 Grass 時把 ctx[:damage] x1.5。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityModifierAuthority"] = "2.5.3"

module ALBERT_CG
  module ABILITY_MODIFIER_V253
    VERSION = "2.5.3"

    def self.ensure_triggers
      return false unless defined?(ALBERT_CG::ABILITY_V250)
      list = ALBERT_CG::ABILITY_V250::TRIGGERS
      list.push(:stat_query) unless list.include?(:stat_query)
      list.push(:damage_modify) unless list.include?(:damage_modify)
      return true
    rescue
      return false
    end

    def self.type_id_for_action(user,skill=nil)
      if skill != nil && skill.respond_to?(:cg_pokemon_type_id)
        return skill.cg_pokemon_type_id.to_i
      end
      if user != nil && user.respond_to?(:cg_basic_attack_type_id)
        return user.cg_basic_attack_type_id.to_i
      end
      return 0
    rescue
      return 0
    end

    def self.skill_fixed_damage?(skill)
      return false if skill == nil
      return skill.cg_pokemon_damage_class == :fixed if skill.respond_to?(:cg_pokemon_damage_class)
      return false
    rescue
      return false
    end
  end
end

ALBERT_CG::ABILITY_MODIFIER_V253.ensure_triggers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Game_Battler：Ability stat query / final damage modifier bridge
#==============================================================================
class Game_Battler
  alias cg_v253_ability_modifier_atk_stat cg_atk_stat
  def cg_atk_stat
    value = cg_v253_ability_modifier_atk_stat
    if defined?(ALBERT_CG::ABILITY_V250)
      ctx = {:stat=>:atk,:value=>value.to_i,:raw_value=>value.to_i,:battler=>self}
      ALBERT_CG::ABILITY_V250.dispatch(:stat_query,self,ctx)
      value = ctx[:value].to_i if ctx.has_key?(:value)
    end
    value = 1 if value.to_i < 1
    return value.to_i
  rescue
    return cg_v253_ability_modifier_atk_stat
  end

  alias cg_v253_ability_modifier_def_stat cg_def_stat
  def cg_def_stat
    value = cg_v253_ability_modifier_def_stat
    if defined?(ALBERT_CG::ABILITY_V250)
      ctx = {:stat=>:def,:value=>value.to_i,:raw_value=>value.to_i,:battler=>self}
      ALBERT_CG::ABILITY_V250.dispatch(:stat_query,self,ctx)
      value = ctx[:value].to_i if ctx.has_key?(:value)
    end
    value = 1 if value.to_i < 1
    return value.to_i
  rescue
    return cg_v253_ability_modifier_def_stat
  end

  alias cg_v253_ability_modifier_execute_damage execute_damage
  def execute_damage(user)
    if defined?(ALBERT_CG::ABILITY_V250) && defined?(ALBERT_CG::ABILITY_MODIFIER_V253) &&
       user != nil && @hp_damage.to_i > 0
      skill = ALBERT_CG::ABILITY_V250.current_skill(user)
      ctx = {
        :user=>user, :target=>self, :skill=>skill,
        :move_id=>ALBERT_CG::ABILITY_V250.current_move_id(user),
        :type_id=>ALBERT_CG::ABILITY_MODIFIER_V253.type_id_for_action(user,skill),
        :damage=>@hp_damage.to_i, :raw_damage=>@hp_damage.to_i,
        :fixed_damage=>ALBERT_CG::ABILITY_MODIFIER_V253.skill_fixed_damage?(skill),
        :role=>:attacker
      }
      ALBERT_CG::ABILITY_V250.dispatch(:damage_modify,user,ctx)
      @hp_damage = ctx[:damage].to_i if ctx.has_key?(:damage)
    end
    return cg_v253_ability_modifier_execute_damage(user)
  end
end
