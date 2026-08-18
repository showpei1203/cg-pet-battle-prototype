# RMVX_SCRIPT_INDEX: 250
# RMVX_SCRIPT_ID: 244400002
# RMVX_SCRIPT_NAME: CG Pokemon Unique K Runtime Instrumentation Guard v2.4.4b
# RMVX_SOURCE_SHA256: bb54f881892fb48913b7818a08f4fabfd7634528149f762b54eb248c8fa94883

#==============================================================================
# ■ CG Pokemon Unique K Runtime Instrumentation Guard v2.4.4b
#------------------------------------------------------------------------------
# 【用途】
#  修正既有 `CG Pokemon Unique Move Batch K v2.4.4a` 的測試計數器洩漏到正式 Runtime。
#  Batch K 的正式 `Game_Battler#skill_effect` dispatch 在任何 handled Move 成功後都會呼叫
#  `UNIQUE_K_V244.mark_apply`；原版 mark_apply 假定只有自身 F11 AutoRegression 會呼叫，
#  因而直接存取 @apply_counts。當其他正式系統／Regression（例如 Ability Batch AB 的
#  Teatime 752）使用 Batch K Move，而 Unique K F11 suite 沒啟動時，@apply_counts 為 nil，
#  會在 Move 已成功套用後拋出 NoMethodError。
#
# 【主要機制】
#  1. 不修改 Batch K 的任何 Move effect、target、Held Item、Teatime、Happy Hour 等規則。
#  2. 只重新定義 `ALBERT_CG::UNIQUE_K_V244.mark_apply`。
#  3. 僅在 `UNIQUE_K_V244.active? == true` 時寫入 coverage counter。
#  4. 即使 K suite active 但計數器尚未初始化，也會先建立空 Hash，避免 nil 存取。
#  5. K suite inactive 時直接返回 false；正式 Move Runtime 不受測試 instrumentation 影響。
#
# 【設定／可調參數】
#  無。這是固定的 Runtime instrumentation isolation hotfix。
#
# 【依賴與載入順序】
#  必須載入在 `CG Pokemon Unique Move Batch K v2.4.4a` 之後。
#  本專案正式放在所有已 PASS Ability A~AA 之後、Ability Batch AB 之前；不修改舊 script。
#
# 【事件／腳本呼叫方式】
#  不需事件呼叫。載入後自動生效。
#
# 【實際範例】
#  - Ability Batch AB Round1 使用 Move 752 Teatime：Move 正常消耗 Berry，但不會再因
#    Unique K regression 未啟動而存取 nil @apply_counts。
#  - 單獨執行 Unique K F11 AutoRegression 時：active? 為 true，coverage 計數仍正常累加。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_UniqueKRuntimeInstrumentationGuard"] = "2.4.4b"

if defined?(ALBERT_CG::UNIQUE_K_V244)
  module ALBERT_CG
    module UNIQUE_K_V244
      def self.mark_apply(move_id)
        return false unless active?
        @apply_counts = {} if @apply_counts == nil
        key = move_id.to_i
        @apply_counts[key] = @apply_counts[key].to_i + 1
        return true
      end
    end
  end
end
