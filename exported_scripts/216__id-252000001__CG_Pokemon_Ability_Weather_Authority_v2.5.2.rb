# RMVX_SCRIPT_INDEX: 216
# RMVX_SCRIPT_ID: 252000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Weather Authority v2.5.2
# RMVX_SOURCE_SHA256: cd58e44a1e807fc89346b4ee6849c39b7e99b941ed24e7975530435ce9258ad8

#==============================================================================
# ■ CG Pokemon Ability Weather Authority v2.5.2
#------------------------------------------------------------------------------
# 【用途】
#  在已實機封版的 Ability Runtime Core v2.5.0 與 Field Core v2.3.3a 之上，
#  建立天氣型 Ability 的共用正式權威。此頁負責「由 Ability 設定天氣」以及
#  「依有效 Ability + 當前天氣修正 SPE」兩項跨 Batch 共用機制，避免後續每個
#  Weather Ability 都各自 alias Field / Speed 核心。
#
# 【主要設定項】
#  WEATHER_TURNS = 5
#    Ability 建立的標準天氣回合數，與 Ability Core ENTRY_WEATHER_TURNS 一致。
#  SPEED_WEATHER_TABLE
#    33 Swift Swim   -> Rain 時 SPE x2
#    34 Chlorophyll  -> Sun  時 SPE x2
#
# 【機制規則】
#  1. 有效 Ability 一律透過 ALBERT_CG::ABILITY_V250.ability_id(battler) 取得，
#     因此會尊重 Gastro Acid / Skill Swap / Role Play / Transform 等既有
#     Battle-only Ability Override / Suppression。
#  2. set_weather 直接寫入 Field Core 唯一的 state.weather / weather_turns，
#     不建立第二套 Weather state；完成後呼叫 Ability Core notify_weather_changed，
#     讓 Swift Swim / Chlorophyll 等被動 Ability 能在天氣切換當下收到事件。
#  3. SPE 修正掛在 Game_Battler#cg_spe 外層，只在對應天氣有效且 Ability 正常時 x2。
#     正式 Action Priority 本來就以 cg_priority_base_speed -> cg_spe 為權威，因此
#     不需另改 Action Priority 核心。
#  4. 本頁只提供共用天氣權威，不負責 Rain Dish / Hydration / Ice Body 等
#     End-turn 效果；這些由 Ability Batch C handler 執行。
#
# 【可調參數】
#  WEATHER_TURNS、SPEED_WEATHER_TABLE。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發時可：
#    ALBERT_CG::ABILITY_WEATHER_V252.set_weather(:sun, battler, 70)
#    ALBERT_CG::ABILITY_WEATHER_V252.speed_multiplier_percent(battler)
#
# 【實際範例】
#  Drought Pokémon 進場：
#    set_weather(:sun, user, 70) -> Field weather=:sun turns=5
#    -> notify_weather_changed -> Chlorophyll handler 可發動提示
#    -> Chlorophyll Pokémon 的 cg_spe 自動變為原值 x2。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityWeatherAuthority"] = "2.5.2"

module ALBERT_CG
  module ABILITY_WEATHER_V252
    VERSION = "2.5.2"
    WEATHER_TURNS = 5
    SPEED_WEATHER_TABLE = {
      33 => :rain,
      34 => :sun,
    }

    def self.field_state
      return nil unless defined?(ALBERT_CG::FIELD_V233)
      return ALBERT_CG::FIELD_V233.state
    rescue
      return nil
    end

    def self.ability_id(battler)
      return 0 unless defined?(ALBERT_CG::ABILITY_V250)
      return ALBERT_CG::ABILITY_V250.ability_id(battler).to_i
    rescue
      return 0
    end

    def self.weather_active?(kind)
      st = field_state
      return false if st == nil
      return st.weather == kind && st.weather_turns.to_i > 0
    rescue
      return false
    end

    def self.set_weather(kind,battler=nil,ability_id=0,turns=nil)
      st = field_state
      return false if st == nil
      duration = turns == nil ? WEATHER_TURNS : turns.to_i
      duration = WEATHER_TURNS if duration <= 0
      before = st.weather
      before_turns = st.weather_turns.to_i
      st.weather = kind
      st.weather_turns = duration
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.runtime_log(
          "ABILITY_WEATHER_SET ability=" + ability_id.to_i.to_s +
          " battler=" + (battler == nil ? "nil" : battler.name.to_s) +
          " weather=" + kind.to_s + " turns=" + duration.to_s +
          " before=" + before.to_s + ":" + before_turns.to_s)
        ALBERT_CG::ABILITY_V250.notify_weather_changed(battler)
      end
      return true
    rescue => e
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.runtime_log("ABILITY_WEATHER_SET_ERROR " + e.class.to_s + ":" + e.message.to_s)
      end
      return false
    end

    def self.speed_multiplier_percent(battler)
      aid = ability_id(battler)
      kind = SPEED_WEATHER_TABLE[aid]
      return 100 if kind == nil
      return weather_active?(kind) ? 200 : 100
    rescue
      return 100
    end

    def self.apply_speed(value,battler)
      pct = speed_multiplier_percent(battler)
      return value.to_i if pct == 100
      result = value.to_i * pct / 100
      return [result,1].max
    rescue
      return value.to_i
    end
  end
end

#==============================================================================
# ■ Game_Battler：Weather Ability SPE modifier
#==============================================================================
class Game_Battler
  alias cg_v252_weather_ability_spe cg_spe
  def cg_spe
    value = cg_v252_weather_ability_spe
    if defined?(ALBERT_CG::ABILITY_WEATHER_V252)
      value = ALBERT_CG::ABILITY_WEATHER_V252.apply_speed(value,self)
    end
    return [value.to_i,1].max
  rescue
    return cg_v252_weather_ability_spe
  end
end
