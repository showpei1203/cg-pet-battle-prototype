# RMVX_SCRIPT_INDEX: 226
# RMVX_SCRIPT_ID: 257000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Accuracy + Activation Authority v2.5.7
# RMVX_SOURCE_SHA256: a54f768782ae97c2ade609ce8fd158bbe874b3d4d3f6ecb3d5a20b6dc863d78b

#==============================================================================
# ■ CG Pokemon Ability Accuracy + Activation Authority v2.5.7
#------------------------------------------------------------------------------
# 【用途】
#  建立 Ability Batch H 共用的「命中率／迴避率修正」與「受屬性招式後啟動」權威層，
#  供 Sand Veil、Compound Eyes、Hustle、Tangled Feet、Snow Cloak、No Guard、
#  Flash Fire、Motor Drive 共用。此頁只新增 Ability 外層，不修改已封版 Move 937。
#
# 【主要設定項】
#  Accuracy / evasion Ability：
#    8  Sand Veil      Sandstorm 時，對手命中率 x0.8（等價 Evasion x1.25）。
#    14 Compound Eyes  使用者命中率 x1.3。
#    55 Hustle         Physical Move 命中率 x0.8；有效 ATK x1.5。
#    77 Tangled Feet   Confusion 時，對手命中率 x0.5（等價 Evasion x2）。
#    81 Snow Cloak     Hail 時，對手命中率 x0.8。
#    99 No Guard       使用者或目標具有 No Guard 時，最終命中率 100。
#  Element activation Ability：
#    18 Flash Fire     免疫 Fire Move；被 Fire Move 指向後啟動，之後 Fire 傷害 x1.5。
#    78 Motor Drive    免疫 Electric Move，並提升自身 Speed stage +1。
#
# 【機制規則】
#  1. 有效 Ability 一律透過 Ability Runtime Core 的 cg_master_ability_id 取得，
#     尊重 Gastro Acid、Skill Swap、Role Play、Transform 等 Battle-only override/suppression。
#  2. calc_hit 外層只修改既有最終命中率；不重做 Accuracy/Evasion stage 公式。
#     No Guard 擁有最高優先權，直接回傳 100。
#  3. Sand Veil / Snow Cloak 直接讀 Field Core 唯一天氣 state，不建立第二套 weather。
#  4. Hustle 的 ATK x1.5 走既有 :stat_query；Flash Fire 的 Fire x1.5 走既有
#     :damage_modify attacker role，因此可與其他正式傷害 modifier 疊加。
#  5. Flash Fire / Motor Drive 走 Ability Core :before_hit。成功時把 ctx[:cancel]=true，
#     因而不進入原 skill_effect；Flash Fire activation 是 battle-only volatile，換出時清除。
#  6. Motor Drive 以正式 cg_change_stat_stage(:spe,+1) 提升 Speed；能力階級上限仍由既有
#     Move Effect Authority 控制。
#  7. Accuracy 類被動不顯示每次查詢 Popup，避免每次命中計算都洗畫面；只有實際
#     Flash Fire / Motor Drive 啟動時由 Ability Core 正常顯示特性發動提示。
#
# 【可調參數】
#  SAND_VEIL_HIT_PERCENT=80、COMPOUND_EYES_PERCENT=130、HUSTLE_HIT_PERCENT=80、
#  TANGLED_FEET_HIT_PERCENT=50、SNOW_CLOAK_HIT_PERCENT=80、HUSTLE_ATK_PERCENT=150、
#  FLASH_FIRE_DAMAGE_PERCENT=150。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發時可直接查：
#    target.calc_hit(user, skill)
#    user.cg_atk_stat
#  Flash Fire activation flag 僅供除錯：
#    ALBERT_CG::ABILITY_ACCURACY_V257.flash_fire_active?(battler)
#
# 【實際範例】
#  Compound Eyes 使用 Blizzard：原命中 70 -> 91。
#  Sandstorm 中攻擊 Sand Veil：原命中 100 -> 80。
#  Thunderbolt 打 Motor Drive：傷害取消，Motor Drive 使用者 SPE stage +1。
#  Flamethrower 打 Flash Fire：傷害取消並啟動；下一次 Fire damage x1.5。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityAccuracyActivationAuthority"] = "2.5.7"

module ALBERT_CG
  module ABILITY_ACCURACY_V257
    VERSION = "2.5.7"

    ABILITY_SAND_VEIL      = 8
    ABILITY_COMPOUND_EYES  = 14
    ABILITY_FLASH_FIRE     = 18
    ABILITY_HUSTLE         = 55
    ABILITY_TANGLED_FEET   = 77
    ABILITY_MOTOR_DRIVE    = 78
    ABILITY_SNOW_CLOAK     = 81
    ABILITY_NO_GUARD       = 99

    SAND_VEIL_HIT_PERCENT     = 80
    COMPOUND_EYES_PERCENT     = 130
    HUSTLE_HIT_PERCENT        = 80
    TANGLED_FEET_HIT_PERCENT  = 50
    SNOW_CLOAK_HIT_PERCENT    = 80
    HUSTLE_ATK_PERCENT        = 150
    FLASH_FIRE_DAMAGE_PERCENT = 150

    def self.core
      return defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil
    end

    def self.ability_id(battler)
      c = core
      return 0 if c == nil || battler == nil
      return c.ability_id(battler).to_i
    rescue
      return 0
    end

    def self.weather_active?(kind)
      return false unless defined?(ALBERT_CG::ABILITY_WEATHER_V252)
      return ALBERT_CG::ABILITY_WEATHER_V252.weather_active?(kind)
    rescue
      return false
    end

    def self.physical_move?(obj)
      return false if obj == nil
      return obj.cg_pokemon_damage_class == :physical if obj.respond_to?(:cg_pokemon_damage_class)
      return false
    rescue
      return false
    end

    def self.move_type_id(obj)
      return 0 if obj == nil
      return obj.cg_pokemon_type_id.to_i if obj.respond_to?(:cg_pokemon_type_id)
      return 0
    rescue
      return 0
    end

    def self.fire_type_id
      return 0 unless defined?(ALBERT_CG::POKEMON_COMBAT)
      return ALBERT_CG::POKEMON_COMBAT.type_id(:fire).to_i
    rescue
      return 0
    end

    def self.electric_type_id
      return 0 unless defined?(ALBERT_CG::POKEMON_COMBAT)
      return ALBERT_CG::POKEMON_COMBAT.type_id(:electric).to_i
    rescue
      return 0
    end

    def self.hostile?(user,target)
      return false if user == nil || target == nil
      return user.actor? != target.actor?
    rescue
      return false
    end

    def self.flash_fire_active?(battler)
      return battler != nil && battler.instance_variable_get(:@cg_v257_flash_fire_active) == true
    rescue
      return false
    end

    def self.set_flash_fire_active(battler,value)
      return false if battler == nil
      battler.instance_variable_set(:@cg_v257_flash_fire_active,value == true)
      return true
    rescue
      return false
    end

    # Accuracy 查詢是高頻操作，所以只記錄到 Batch H Regression，不走 Popup。
    def self.note_query(aid,battler,kind,ctx=nil)
      if defined?(ALBERT_CG::ABILITY_H_V257) && ALBERT_CG::ABILITY_H_V257.respond_to?(:note_external_trigger)
        ALBERT_CG::ABILITY_H_V257.note_external_trigger(aid,battler,kind,ctx == nil ? {} : ctx)
      end
      return true
    rescue
      return false
    end

    def self.modify_hit(value,target,user,obj=nil)
      base = value.to_i
      base = 1 if base < 1
      return base if target == nil || user == nil

      uaid = ability_id(user)
      taid = ability_id(target)

      # No Guard 優先於所有 Accuracy / Evasion 修正。
      if uaid == ABILITY_NO_GUARD || taid == ABILITY_NO_GUARD
        holder = uaid == ABILITY_NO_GUARD ? user : target
        note_query(ABILITY_NO_GUARD,holder,:accuracy_no_guard,
          {:user=>user,:target=>target,:before=>base,:after=>100})
        return 100
      end

      result = base
      if uaid == ABILITY_COMPOUND_EYES
        before = result
        result = result * COMPOUND_EYES_PERCENT / 100
        note_query(ABILITY_COMPOUND_EYES,user,:accuracy_modify,
          {:kind=>:compound_eyes,:before=>before,:after=>result,:target=>target})
      elsif uaid == ABILITY_HUSTLE && physical_move?(obj)
        before = result
        result = result * HUSTLE_HIT_PERCENT / 100
        note_query(ABILITY_HUSTLE,user,:accuracy_modify,
          {:kind=>:hustle,:before=>before,:after=>result,:target=>target})
      end

      if taid == ABILITY_SAND_VEIL && weather_active?(:sandstorm)
        before = result
        result = result * SAND_VEIL_HIT_PERCENT / 100
        note_query(ABILITY_SAND_VEIL,target,:evasion_modify,
          {:kind=>:sand_veil,:before=>before,:after=>result,:user=>user})
      elsif taid == ABILITY_SNOW_CLOAK && weather_active?(:hail)
        before = result
        result = result * SNOW_CLOAK_HIT_PERCENT / 100
        note_query(ABILITY_SNOW_CLOAK,target,:evasion_modify,
          {:kind=>:snow_cloak,:before=>before,:after=>result,:user=>user})
      elsif taid == ABILITY_TANGLED_FEET && defined?(ALBERT_CG::MOVE_EFFECT) &&
            target.state?(ALBERT_CG::MOVE_EFFECT::STATE_CONFUSION)
        before = result
        result = result * TANGLED_FEET_HIT_PERCENT / 100
        note_query(ABILITY_TANGLED_FEET,target,:evasion_modify,
          {:kind=>:tangled_feet,:before=>before,:after=>result,:user=>user})
      end

      result = 100 if result > 100
      result = 1 if result < 1
      return result.to_i
    rescue
      return value.to_i
    end

    def self.apply_hustle_stat(battler,ctx)
      return false if battler == nil || ctx == nil
      return false unless ctx[:stat] == :atk
      before = ctx[:value].to_i
      after = [before * HUSTLE_ATK_PERCENT / 100,1].max
      ctx[:value] = after
      if defined?(ALBERT_CG::ABILITY_H_V257) && ALBERT_CG::ABILITY_H_V257.respond_to?(:note_external_trigger)
        ALBERT_CG::ABILITY_H_V257.note_external_trigger(ABILITY_HUSTLE,battler,:stat_query,
          {:kind=>:hustle_atk,:before=>before,:after=>after})
      end
      # 被動 stat query 不需要每次計算都跳 Ability Popup；ctx 已完成修改。
      return false
    rescue
      return false
    end

    def self.apply_flash_fire_before_hit(battler,ctx)
      return false if battler == nil || ctx == nil
      user = ctx[:user]
      skill = ctx[:skill]
      return false unless hostile?(user,battler)
      return false unless move_type_id(skill) == fire_type_id
      set_flash_fire_active(battler,true)
      ctx[:cancel] = true
      ctx[:hp_damage] = 0
      return true
    rescue
      return false
    end

    def self.apply_flash_fire_damage(battler,ctx)
      return false if battler == nil || ctx == nil
      return false unless ctx[:role] == :attacker
      return false unless flash_fire_active?(battler)
      return false unless ctx[:type_id].to_i == fire_type_id
      return false if ctx[:fixed_damage] == true
      before = ctx[:damage].to_i
      return false if before <= 0
      after = [before * FLASH_FIRE_DAMAGE_PERCENT / 100,1].max
      ctx[:damage] = after
      if defined?(ALBERT_CG::ABILITY_H_V257) && ALBERT_CG::ABILITY_H_V257.respond_to?(:note_flash_fire_boost)
        ALBERT_CG::ABILITY_H_V257.note_flash_fire_boost(battler,before,after,ctx)
      end
      return true
    rescue
      return false
    end

    def self.apply_motor_drive(battler,ctx)
      return false if battler == nil || ctx == nil
      user = ctx[:user]
      skill = ctx[:skill]
      return false unless hostile?(user,battler)
      return false unless move_type_id(skill) == electric_type_id
      before = battler.respond_to?(:cg_stat_stage) ? battler.cg_stat_stage(:spe).to_i : 0
      battler.cg_change_stat_stage(:spe,1) if battler.respond_to?(:cg_change_stat_stage)
      after = battler.respond_to?(:cg_stat_stage) ? battler.cg_stat_stage(:spe).to_i : before
      ctx[:cancel] = true
      ctx[:hp_damage] = 0
      if defined?(ALBERT_CG::ABILITY_H_V257) && ALBERT_CG::ABILITY_H_V257.respond_to?(:note_motor_drive_stage)
        ALBERT_CG::ABILITY_H_V257.note_motor_drive_stage(battler,before,after,ctx)
      end
      return true
    rescue
      return false
    end

    def self.clear_switch_volatile(battler)
      return false if battler == nil
      set_flash_fire_active(battler,false)
      return true
    rescue
      return false
    end

    def self.register_handlers
      c = core
      return false if c == nil
      c.register(ABILITY_HUSTLE,:stat_query,self,:apply_hustle_stat)
      c.register(ABILITY_FLASH_FIRE,:before_hit,self,:apply_flash_fire_before_hit)
      c.register(ABILITY_FLASH_FIRE,:damage_modify,self,:apply_flash_fire_damage)
      c.register(ABILITY_MOTOR_DRIVE,:before_hit,self,:apply_motor_drive)
      return true
    rescue
      return false
    end
  end
end

ALBERT_CG::ABILITY_ACCURACY_V257.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Game_Battler：最終命中率 Ability modifier
#==============================================================================
class Game_Battler
  alias cg_v257_accuracy_activation_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    value = cg_v257_accuracy_activation_calc_hit(user,obj)
    if defined?(ALBERT_CG::ABILITY_ACCURACY_V257)
      return ALBERT_CG::ABILITY_ACCURACY_V257.modify_hit(value,self,user,obj)
    end
    return value
  rescue
    return cg_v257_accuracy_activation_calc_hit(user,obj)
  end
end

#==============================================================================
# ■ Force Switch：Flash Fire battle-only activation 換出清除
#==============================================================================
if defined?(ALBERT_CG::FORCE_SWITCH_V235)
  module ALBERT_CG
    module FORCE_SWITCH_V235
      class << self
        alias cg_v257_accuracy_clear_switch_out_volatile clear_switch_out_volatile
        def clear_switch_out_volatile(battler)
          result = cg_v257_accuracy_clear_switch_out_volatile(battler)
          if defined?(ALBERT_CG::ABILITY_ACCURACY_V257)
            ALBERT_CG::ABILITY_ACCURACY_V257.clear_switch_volatile(battler)
          end
          return result
        end
      end
    end
  end
end
