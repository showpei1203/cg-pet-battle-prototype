# RMVX_SCRIPT_INDEX: 273
# RMVX_SCRIPT_ID: 273
# RMVX_SCRIPT_NAME: CG Ability Weather Signature Compatibility v2.5.48a
# RMVX_SOURCE_SHA256: 8c60d5b4ff9a5f30a9977d966aa0350d2f1ac1ff8e76887ca8dccefe492386b0

#==============================================================================
# ■ CG Ability Weather Signature Compatibility v2.5.48a
#------------------------------------------------------------------------------
# 【用途】
#  修正 Ability Batch AH v2.5.33c 對 ABILITY_WEATHER_V252.set_weather 的包裝器
#  把原本可省略的第 4 參數 turns 變成必填，導致較早已封版的 Batch C Entry
#  Weather 呼叫（3 參數）在目前完整腳本堆疊中拋出 ArgumentError。
#
# 【實機證據】
#  v2.5.48 Full Catalog 實機中：
#    - Batch C 的 Sand Stream / Drought / Snow Warning 三個 Entry Weather 全部失效；
#    - 同一 Batch 以 4 參數呼叫 set_weather(:rain,nil,0,5) 仍正常；
#    - Swift Swim / Rain Dish / Hydration 等非 Entry Weather 行為正常。
#  這與 AH wrapper 的 4-required-args 簽名完全吻合，因此分類為目前完整堆疊的
#  Formal Runtime 相容性缺陷，而非 Batch C fixture 問題。
#
# 【修正規則】
#  1. 不修改已封版 Scripts 0..272；以新 bridge 恢復原 Weather Authority 呼叫契約。
#  2. kind / battler / ability_id / turns 四個參數全部原樣交給 AH 現行 wrapper。
#  3. turns 未提供時傳 nil，讓最底層 v2.5.2 Weather Authority 使用既有 5 回合預設。
#  4. 不改 Weather 強天氣鎖、Cloud Nine/Air Lock、Field state 或任何 Ability 效果。
#
# 【事件／腳本呼叫】
#  無。此腳本為正式 Runtime 相容性 bridge，載入後自動生效。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_AbilityWeatherSignatureCompatibility"] = "2.5.48a"

if defined?(ALBERT_CG::ABILITY_WEATHER_V252)
  module ALBERT_CG
    module ABILITY_WEATHER_V252
      class << self
        unless method_defined?(:cg_v2548a_weather_set_weather_compat)
          alias cg_v2548a_weather_set_weather_compat set_weather
        end

        def set_weather(kind, battler=nil, ability_id=0, turns=nil)
          cg_v2548a_weather_set_weather_compat(kind, battler, ability_id, turns)
        end
      end
    end
  end
end
