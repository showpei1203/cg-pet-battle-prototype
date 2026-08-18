# RMVX_SCRIPT_INDEX: 228
# RMVX_SCRIPT_ID: 258000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Conditional Stat + Tempo Authority v2.5.8
# RMVX_SOURCE_SHA256: 494d83563d0c55325ed426c2a7ebadff656b54c55d5149f78de138c867db77f4

#==============================================================================
# ■ CG Pokemon Ability Conditional Stat + Tempo Authority v2.5.8
#------------------------------------------------------------------------------
# 【用途】
#  建立 Ability Batch I 共用的「特殊能力值查詢、持有物失去事件、條件火力與節奏」
#  Authority，供 Plus / Minus / Unburden / Download / Solar Power / Quick Feet /
#  Sniper / Slow Start 使用。此頁只新增 Ability 外層，不修改已封版 Move 937 與
#  Ability Batch A-H 正式腳本。
#
# 【主要設定項】
#  新增／延伸接點：
#    :stat_query         既有共用 trigger，現在正式涵蓋 SPA / SPE 查詢。
#    :held_item_changed  Battle Held Item runtime ID 發生變化時 dispatch。
#  Ability：
#    57 Plus        場上同伴具有 Plus / Minus 時 SPA x1.5。
#    58 Minus       場上同伴具有 Plus / Minus 時 SPA x1.5。
#    84 Unburden    戰鬥中真正失去原本持有物後 SPE x2，換出清除。
#    88 Download    進場比較敵方 DEF / SPD 總和，提升 ATK 或 SPA stage +1。
#    94 Solar Power Sun 時 SPA x1.5；回合末損失 MaxHP 1/8。
#    95 Quick Feet  主要異常時 SPE x1.5；Paralysis 時抵銷既有 x0.5 後再 x1.5。
#    97 Sniper      已成立 Critical 的最終正傷害再 x1.5。
#   112 Slow Start  進場 5 回合內 ATK / SPE x0.5，回合末倒數，換出清除。
#
# 【機制規則】
#  1. 有效 Ability 一律由 Ability Runtime Core 的 cg_master_ability_id 判定，尊重
#     Gastro Acid、Skill Swap、Role Play、Transform 等 Battle-only override/suppression。
#  2. 本頁只在既有 cg_spa / cg_spe 完整跑完 Stat Stage、Paralysis、Weather Ability
#     等正式規則後 dispatch :stat_query，因此不重做 Base Stat 公式。
#  3. Unburden 只在 Battle Held Item 從「有物品」變成「無物品」時啟動；單純
#     Corrosive Gas suppression 不視為失去物品。Trick 若直接換成另一件物品也不啟動。
#  4. Download 使用目前所有 active opponents 的有效 DEF / SPD 總和；DEF < SPD 時
#     ATK +1，否則 SPA +1。能力階級仍走 cg_change_stat_stage 舊 Authority。
#  5. Solar Power / Slow Start 的 battle-only counter / flag 會在換出時清理，不寫回
#     Clone 永久資料。
#  6. Sniper 只在 target 已由正式 Critical Authority 判定 @critical=true 時加乘，
#     不自行製造 Critical，也不影響 Fixed Damage 的 Critical 禁止規則。
#  7. 若 Battle-only Ability Override 直接切換成 Slow Start，本頁會初始化 5 回合；
#     切離 Slow Start / Unburden 時會清除其 volatile，避免交換 Ability 後殘留。
#
# 【可調參數】
#  PARTNER_SPA_PERCENT=150、UNBURDEN_SPE_PERCENT=200、SOLAR_POWER_SPA_PERCENT=150、
#  QUICK_FEET_SPE_PERCENT=150、SNIPER_DAMAGE_PERCENT=150、SLOW_START_PERCENT=50、
#  SLOW_START_TURNS=5、SOLAR_POWER_HP_DENOM=8。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發可查：
#    battler.cg_spa
#    battler.cg_spe
#    ALBERT_CG::ABILITY_CONDITIONAL_V258.unburden_active?(battler)
#    ALBERT_CG::ABILITY_CONDITIONAL_V258.slow_start_turns(battler)
#
# 【實際範例】
#  Plus 與 Minus 同時在場：兩者 SPA 都 x1.5。
#  Quick Feet Pokémon 麻痺：不吃原本 Speed x0.5，最後為正常 Speed x1.5。
#  Sniper Critical：既有 Critical 傷害完成後再 x1.5。
#  Regigigas 進場：Slow Start counter=5，前 5 回合 ATK/SPE x0.5。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityConditionalStatTempoAuthority"] = "2.5.8"

module ALBERT_CG
  module ABILITY_CONDITIONAL_V258
    VERSION = "2.5.8"

    ABILITY_PLUS        = 57
    ABILITY_MINUS       = 58
    ABILITY_UNBURDEN    = 84
    ABILITY_DOWNLOAD    = 88
    ABILITY_SOLAR_POWER = 94
    ABILITY_QUICK_FEET  = 95
    ABILITY_SNIPER      = 97
    ABILITY_SLOW_START  = 112

    PARTNER_SPA_PERCENT     = 150
    UNBURDEN_SPE_PERCENT    = 200
    SOLAR_POWER_SPA_PERCENT = 150
    QUICK_FEET_SPE_PERCENT  = 150
    SNIPER_DAMAGE_PERCENT   = 150
    SLOW_START_PERCENT      = 50
    SLOW_START_TURNS        = 5
    SOLAR_POWER_HP_DENOM    = 8

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

    def self.ensure_triggers
      c = core
      return false if c == nil
      list = c::TRIGGERS
      list.push(:held_item_changed) unless list.include?(:held_item_changed)
      return true
    rescue
      return false
    end

    def self.weather_active?(kind)
      return false unless defined?(ALBERT_CG::ABILITY_WEATHER_V252)
      return ALBERT_CG::ABILITY_WEATHER_V252.weather_active?(kind)
    rescue
      return false
    end

    def self.primary_status?(battler)
      return false if battler == nil || !defined?(ALBERT_CG::MOVE_EFFECT)
      for sid in ALBERT_CG::MOVE_EFFECT::PRIMARY_STATES
        return true if battler.state?(sid)
      end
      if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON)
        return true if battler.state?(ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON)
      end
      return false
    rescue
      return false
    end

    def self.paralyzed?(battler)
      return false if battler == nil || !defined?(ALBERT_CG::MOVE_EFFECT)
      return battler.state?(ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS)
    rescue
      return false
    end

    def self.partner_plus_minus?(battler)
      c = core
      return false if c == nil || battler == nil
      for ally in c.allies_of(battler)
        next if ally == battler
        aid = ability_id(ally)
        return true if aid == ABILITY_PLUS || aid == ABILITY_MINUS
      end
      return false
    rescue
      return false
    end

    def self.unburden_active?(battler)
      return battler != nil && battler.instance_variable_get(:@cg_v258_unburden_active) == true
    rescue
      return false
    end

    def self.set_unburden_active(battler,value)
      return false if battler == nil
      battler.instance_variable_set(:@cg_v258_unburden_active,value == true)
      return true
    rescue
      return false
    end

    def self.slow_start_turns(battler)
      return 0 if battler == nil
      value = battler.instance_variable_get(:@cg_v258_slow_start_turns)
      if value == nil && ability_id(battler) == ABILITY_SLOW_START
        value = SLOW_START_TURNS
        battler.instance_variable_set(:@cg_v258_slow_start_turns,value)
      end
      return value.to_i
    rescue
      return 0
    end

    def self.set_slow_start_turns(battler,value)
      return false if battler == nil
      battler.instance_variable_set(:@cg_v258_slow_start_turns,[value.to_i,0].max)
      return true
    rescue
      return false
    end

    def self.clear_volatiles(battler)
      return false if battler == nil
      battler.instance_variable_set(:@cg_v258_unburden_active,false)
      battler.instance_variable_set(:@cg_v258_slow_start_turns,nil)
      return true
    rescue
      return false
    end

    def self.note_external(aid,battler,kind,ctx=nil)
      if defined?(ALBERT_CG::ABILITY_I_V258) && ALBERT_CG::ABILITY_I_V258.respond_to?(:note_external_trigger)
        ALBERT_CG::ABILITY_I_V258.note_external_trigger(aid,battler,kind,ctx == nil ? {} : ctx)
      end
      return true
    rescue
      return false
    end

    def self.apply_plus_minus(battler,ctx,aid)
      return false unless ctx[:stat] == :spa
      return false unless partner_plus_minus?(battler)
      before = ctx[:value].to_i
      after = [before * PARTNER_SPA_PERCENT / 100,1].max
      ctx[:value] = after
      note_external(aid,battler,:stat_query,{:kind=>:plus_minus,:before=>before,:after=>after})
      return false
    rescue
      return false
    end

    def self.apply_plus(battler,ctx); return apply_plus_minus(battler,ctx,ABILITY_PLUS); end
    def self.apply_minus(battler,ctx); return apply_plus_minus(battler,ctx,ABILITY_MINUS); end

    def self.apply_unburden_item_change(battler,ctx)
      old_id = ctx[:old_id].to_i
      new_id = ctx[:new_id].to_i
      return false unless old_id > 0 && new_id <= 0
      return false if unburden_active?(battler)
      set_unburden_active(battler,true)
      note_external(ABILITY_UNBURDEN,battler,:held_item_lost,ctx)
      return true
    rescue
      return false
    end

    def self.apply_unburden_stat(battler,ctx)
      return false unless ctx[:stat] == :spe && unburden_active?(battler)
      before = ctx[:value].to_i
      after = [before * UNBURDEN_SPE_PERCENT / 100,1].max
      ctx[:value] = after
      note_external(ABILITY_UNBURDEN,battler,:stat_query,{:kind=>:unburden,:before=>before,:after=>after})
      return false
    rescue
      return false
    end

    def self.apply_unburden_switch_out(battler,ctx)
      set_unburden_active(battler,false)
      return false
    end

    def self.apply_download(battler,ctx)
      c = core
      return false if c == nil || battler == nil
      opponents = c.opponents_of(battler)
      return false if opponents.empty?
      total_def = 0
      total_spd = 0
      for foe in opponents
        total_def += foe.respond_to?(:cg_def_stat) ? foe.cg_def_stat.to_i : foe.def.to_i
        total_spd += foe.respond_to?(:cg_spd) ? foe.cg_spd.to_i : foe.spi.to_i
      end
      stat = total_def < total_spd ? :atk : :spa
      before = battler.respond_to?(:cg_stat_stage) ? battler.cg_stat_stage(stat).to_i : 0
      changed = battler.respond_to?(:cg_change_stat_stage) ? battler.cg_change_stat_stage(stat,1).to_i : 0
      after = battler.respond_to?(:cg_stat_stage) ? battler.cg_stat_stage(stat).to_i : before
      note_external(ABILITY_DOWNLOAD,battler,:entry,
        {:stat=>stat,:def_total=>total_def,:spd_total=>total_spd,:before=>before,:after=>after})
      return changed != 0
    rescue
      return false
    end

    def self.apply_solar_power_stat(battler,ctx)
      return false unless ctx[:stat] == :spa && weather_active?(:sun)
      before = ctx[:value].to_i
      after = [before * SOLAR_POWER_SPA_PERCENT / 100,1].max
      ctx[:value] = after
      note_external(ABILITY_SOLAR_POWER,battler,:stat_query,{:kind=>:solar_power,:before=>before,:after=>after})
      return false
    rescue
      return false
    end

    def self.apply_solar_power_end_turn(battler,ctx)
      return false unless weather_active?(:sun)
      return false if battler == nil || battler.hp.to_i <= 0 || battler.maxhp.to_i <= 0
      loss = [battler.maxhp.to_i / SOLAR_POWER_HP_DENOM,1].max
      before = battler.hp.to_i
      battler.hp = [before - loss,0].max
      note_external(ABILITY_SOLAR_POWER,battler,:end_turn,
        {:kind=>:solar_power_residual,:before=>before,:after=>battler.hp.to_i,:loss=>loss})
      return true
    rescue
      return false
    end

    def self.apply_quick_feet_stat(battler,ctx)
      return false unless ctx[:stat] == :spe && primary_status?(battler)
      before = ctx[:value].to_i
      # Move Core 已對 Paralysis x0.5；Quick Feet 應忽略該懲罰並成為正常值 x1.5。
      after = paralyzed?(battler) ? [before * 3,1].max : [before * QUICK_FEET_SPE_PERCENT / 100,1].max
      ctx[:value] = after
      note_external(ABILITY_QUICK_FEET,battler,:stat_query,
        {:kind=>:quick_feet,:before=>before,:after=>after,:paralyzed=>paralyzed?(battler)})
      return false
    rescue
      return false
    end

    def self.apply_sniper(battler,ctx)
      return false unless ctx[:role] == :attacker
      target = ctx[:target]
      return false if target == nil || target.instance_variable_get(:@critical) != true
      return false if ctx[:fixed_damage] == true
      before = ctx[:damage].to_i
      return false if before <= 0
      after = [before * SNIPER_DAMAGE_PERCENT / 100,1].max
      ctx[:damage] = after
      note_external(ABILITY_SNIPER,battler,:damage_modify,
        {:kind=>:sniper,:before=>before,:after=>after,:critical=>true})
      return true
    rescue
      return false
    end

    def self.apply_slow_start_entry(battler,ctx)
      set_slow_start_turns(battler,SLOW_START_TURNS)
      note_external(ABILITY_SLOW_START,battler,:entry,{:turns=>SLOW_START_TURNS})
      return true
    rescue
      return false
    end

    def self.apply_slow_start_stat(battler,ctx)
      stat = ctx[:stat]
      return false unless stat == :atk || stat == :spe
      turns = slow_start_turns(battler)
      return false if turns <= 0
      before = ctx[:value].to_i
      after = [before * SLOW_START_PERCENT / 100,1].max
      ctx[:value] = after
      note_external(ABILITY_SLOW_START,battler,:stat_query,
        {:kind=>:slow_start,:stat=>stat,:before=>before,:after=>after,:turns=>turns})
      return false
    rescue
      return false
    end

    def self.apply_slow_start_end_turn(battler,ctx)
      turns = slow_start_turns(battler)
      return false if turns <= 0
      set_slow_start_turns(battler,turns - 1)
      note_external(ABILITY_SLOW_START,battler,:end_turn,
        {:kind=>:slow_start_tick,:before=>turns,:after=>turns-1})
      return false
    rescue
      return false
    end

    def self.apply_slow_start_switch_out(battler,ctx)
      battler.instance_variable_set(:@cg_v258_slow_start_turns,nil) if battler != nil
      return false
    end

    def self.on_ability_changed(battler,old_id,new_id)
      return false if battler == nil
      old_id = old_id.to_i
      new_id = new_id.to_i
      if old_id == ABILITY_UNBURDEN && new_id != ABILITY_UNBURDEN
        set_unburden_active(battler,false)
      end
      if old_id == ABILITY_SLOW_START && new_id != ABILITY_SLOW_START
        battler.instance_variable_set(:@cg_v258_slow_start_turns,nil)
      elsif new_id == ABILITY_SLOW_START && old_id != ABILITY_SLOW_START
        set_slow_start_turns(battler,SLOW_START_TURNS)
      end
      return true
    rescue
      return false
    end

    def self.register_handlers
      ensure_triggers
      c = core
      return false if c == nil
      c.register(ABILITY_PLUS,:stat_query,self,:apply_plus)
      c.register(ABILITY_MINUS,:stat_query,self,:apply_minus)
      c.register(ABILITY_UNBURDEN,:held_item_changed,self,:apply_unburden_item_change)
      c.register(ABILITY_UNBURDEN,:stat_query,self,:apply_unburden_stat)
      c.register(ABILITY_UNBURDEN,:switch_out,self,:apply_unburden_switch_out)
      c.register(ABILITY_DOWNLOAD,:entry,self,:apply_download)
      c.register(ABILITY_SOLAR_POWER,:stat_query,self,:apply_solar_power_stat)
      c.register(ABILITY_SOLAR_POWER,:end_turn,self,:apply_solar_power_end_turn)
      c.register(ABILITY_QUICK_FEET,:stat_query,self,:apply_quick_feet_stat)
      c.register(ABILITY_SNIPER,:damage_modify,self,:apply_sniper)
      c.register(ABILITY_SLOW_START,:entry,self,:apply_slow_start_entry)
      c.register(ABILITY_SLOW_START,:stat_query,self,:apply_slow_start_stat)
      c.register(ABILITY_SLOW_START,:end_turn,self,:apply_slow_start_end_turn)
      c.register(ABILITY_SLOW_START,:switch_out,self,:apply_slow_start_switch_out)
      return true
    rescue
      return false
    end
  end
end

ALBERT_CG::ABILITY_CONDITIONAL_V258.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Game_Battler：SPA / SPE stat_query bridge
#==============================================================================
class Game_Battler
  alias cg_v258_conditional_spa cg_spa
  def cg_spa
    value = cg_v258_conditional_spa
    if defined?(ALBERT_CG::ABILITY_V250)
      ctx = {:stat=>:spa,:value=>value.to_i,:raw_value=>value.to_i,:battler=>self}
      ALBERT_CG::ABILITY_V250.dispatch(:stat_query,self,ctx)
      value = ctx[:value].to_i if ctx.has_key?(:value)
    end
    value = 1 if value.to_i < 1
    return value.to_i
  rescue
    return cg_v258_conditional_spa
  end

  alias cg_v258_conditional_spe cg_spe
  def cg_spe
    value = cg_v258_conditional_spe
    if defined?(ALBERT_CG::ABILITY_V250)
      ctx = {:stat=>:spe,:value=>value.to_i,:raw_value=>value.to_i,:battler=>self}
      ALBERT_CG::ABILITY_V250.dispatch(:stat_query,self,ctx)
      value = ctx[:value].to_i if ctx.has_key?(:value)
    end
    value = 1 if value.to_i < 1
    return value.to_i
  rescue
    return cg_v258_conditional_spe
  end

  if method_defined?(:cg_set_battle_held_item)
    alias cg_v258_conditional_set_battle_held_item cg_set_battle_held_item
    def cg_set_battle_held_item(item_id,owner_key=nil)
      old_id = respond_to?(:cg_held_item_id) ? cg_held_item_id.to_i : 0
      result = cg_v258_conditional_set_battle_held_item(item_id,owner_key)
      new_id = respond_to?(:cg_held_item_id) ? cg_held_item_id.to_i : item_id.to_i
      if result && old_id != new_id && defined?(ALBERT_CG::ABILITY_V250)
        ctx = {:old_id=>old_id,:new_id=>new_id,:owner=>owner_key}
        ALBERT_CG::ABILITY_V250.dispatch(:held_item_changed,self,ctx)
      end
      return result
    end
  end

  if method_defined?(:cg_v237_set_ability)
    alias cg_v258_conditional_set_ability cg_v237_set_ability
    def cg_v237_set_ability(id)
      old_id = respond_to?(:cg_master_ability_id) ? cg_master_ability_id.to_i : 0
      result = cg_v258_conditional_set_ability(id)
      new_id = respond_to?(:cg_master_ability_id) ? cg_master_ability_id.to_i : id.to_i
      if defined?(ALBERT_CG::ABILITY_CONDITIONAL_V258)
        ALBERT_CG::ABILITY_CONDITIONAL_V258.on_ability_changed(self,old_id,new_id)
      end
      return result
    end
  end
end

#==============================================================================
# ■ Force Switch：保險性清除 Conditional volatile
#==============================================================================
if defined?(ALBERT_CG::FORCE_SWITCH_V235)
  module ALBERT_CG
    module FORCE_SWITCH_V235
      class << self
        alias cg_v258_conditional_clear_switch_out_volatile clear_switch_out_volatile
        def clear_switch_out_volatile(battler)
          result = cg_v258_conditional_clear_switch_out_volatile(battler)
          ALBERT_CG::ABILITY_CONDITIONAL_V258.clear_volatiles(battler) if defined?(ALBERT_CG::ABILITY_CONDITIONAL_V258)
          return result
        end
      end
    end
  end
end
