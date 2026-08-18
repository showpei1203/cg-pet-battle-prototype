# RMVX_SCRIPT_INDEX: 210
# RMVX_SCRIPT_ID: 2041447111
# RMVX_SCRIPT_NAME: CG Pokemon Unique B Regression Damage Isolation v2.4.5b
# RMVX_SOURCE_SHA256: c99ed7c847cba0cc69eff18e9ba78feb952a55f94c534dcad00d689b04212f35

#==============================================================================
# ■ CG Pokemon Unique B Regression Damage Isolation v2.4.5b
#------------------------------------------------------------------------------
# 【用途】
#  修正 Full Move Lifecycle Release Gate 中，Unique Batch B v2.3.4g 的替身測試
#  仍受正式傷害隨機值影響，導致 Round1 兩次 Tackle 偶爾只把 Substitute 削到
#  少量殘餘 HP（例如 shield=2），使 Round2 Encore 正確地被仍存在的 Substitute
#  阻擋，進而產生一連串假 FAIL。
#  本腳本只固定「Unique B deterministic regression 的 Round1 替身兩次承傷」，
#  不修改 Substitute、Encore、Tackle 或正式傷害公式的玩家 Runtime。
#
# 【主要設定】
#  TARGET_MOVE_ID = 33：Round1 兩次用來打 Substitute 的 Tackle／撞擊。
#  TARGET_ACTOR_INDEX = 1：Unique B 測試中的 A1（雷丘／皮卡丘測試位）。
#
# 【機制規則】
#  1. 只有 ALBERT_CG::UNIQUE_B_V234.active? == true 且 current_round == 1 時生效。
#  2. 只有敵對 battler 使用 Move 33 打到 A1 且 A1 Substitute 仍存在時介入。
#  3. 第一次命中固定只削掉約一半 Substitute，確保替身仍存活。
#  4. 第二次命中固定削掉剩餘 Substitute HP，確保恰好在 Round1 第二次承傷後破裂。
#  5. 不改正式 Batch B v2.3.4g 原檔；不影響玩家一般戰鬥、其他 Batch、其他招式。
#
# 【可調參數】
#  TARGET_MOVE_ID／TARGET_ACTOR_INDEX 僅供 Regression 測試配置變更時調整。
#  正式遊戲不應依賴本腳本的測試傷害值。
#
# 【事件／腳本呼叫方式】
#  無需事件呼叫。F11 Full Move Lifecycle Master 啟動 Unique B phase 時自動生效。
#  舊 Unique B regression 若由 script-callable 方式單獨啟動，也同樣只在其 active
#  測試期間生效；正式 Scene_Battle 不會觸發。
#
# 【實際範例】
#  Round1：A1 Substitute shield=35。
#    第一次 Tackle → test-only damage=18，shield 35→17。
#    第二次 Tackle → test-only damage=17，shield 17→0。
#  因此 Round2 Encore 不會再因傷害隨機值而被殘存 Substitute 阻擋。
#==============================================================================
module ALBERT_CG
  module UNIQUE_B_DAMAGE_ISO_V245B
    TARGET_MOVE_ID = 33
    TARGET_ACTOR_INDEX = 1

    def self.active_for?(target, user)
      return false unless defined?(ALBERT_CG::UNIQUE_B_V234)
      return false unless ALBERT_CG::UNIQUE_B_V234.active?
      return false unless ALBERT_CG::UNIQUE_B_V234.current_round.to_i == 1
      return false if target == nil || user == nil
      return false unless target.actor?
      return false unless target.index.to_i == TARGET_ACTOR_INDEX
      return false unless target.respond_to?(:cg_v234_substitute_active?) && target.cg_v234_substitute_active?
      return false if user.actor? == target.actor?
      action = user.action
      return false if action == nil || !action.skill?
      mid = ALBERT_CG::MOVE_EFFECT.move_id(action.skill)
      return mid.to_i == TARGET_MOVE_ID
    rescue
      return false
    end

    def self.fixed_damage(target)
      shield = target.cg_v234_substitute_hp.to_i
      return 0 if shield <= 0
      count = ALBERT_CG::UNIQUE_B_V234.substitute_absorb_count(1, "A1").to_i
      if count <= 0
        # 第一擊保證替身仍存活；ceil(shield / 2)。
        value = (shield + 1) / 2
        value = shield - 1 if value >= shield && shield > 1
        value = 1 if value <= 0
        return value
      end
      # 第二擊直接清掉剩餘 shield，確保「兩次承傷後破裂」。
      return shield
    rescue
      return 0
    end
  end
end

class Game_Battler
  alias cg_v245b_unique_b_damage_execute_damage execute_damage
  def execute_damage(user)
    if ALBERT_CG::UNIQUE_B_DAMAGE_ISO_V245B.active_for?(self, user) && @hp_damage.to_i > 0
      original = @hp_damage.to_i
      forced = ALBERT_CG::UNIQUE_B_DAMAGE_ISO_V245B.fixed_damage(self)
      if forced.to_i > 0
        @hp_damage = forced.to_i
        ALBERT_CG::UNIQUE_B_V234.log(
          "REGRESSION_DAMAGE_ISO target=" + name.to_s +
          " move=33 original=" + original.to_s +
          " forced=" + forced.to_i.to_s +
          " shield_before=" + cg_v234_substitute_hp.to_i.to_s)
      end
    end
    return cg_v245b_unique_b_damage_execute_damage(user)
  end
end
