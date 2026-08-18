# RMVX_SCRIPT_INDEX: 209
# RMVX_SCRIPT_ID: 245000002
# RMVX_SCRIPT_NAME: CG Pokemon Unique F Regression RNG Isolation v2.4.5a
# RMVX_SOURCE_SHA256: e20df0822cad092219bdcb3bef72db21ee68eb3a9f1b925802c1b3e45992ede3

#==============================================================================
# ■ CG Pokemon Unique F Regression RNG Isolation v2.4.5a
#------------------------------------------------------------------------------
# 【用途】
#  修正 Full Move Lifecycle Release Gate 中，Unique Batch F v2.3.9a 測試仍保留
#  Syrup Bomb（Move 903，命中率 85%）隨機命中的問題。
#  這是一層「只供 deterministic AutoRegression 使用」的隔離橋接；不修改
#  Syrup Bomb 正式戰鬥 Runtime、傷害、持續回合、降速規則或一般玩家命中率。
#
# 【主要設定】
#  TARGET_MOVE_ID = 903：Syrup Bomb／糖漿炸彈。
#  TEST_HIT       = 100：Unique F Regression active 時強制命中率 100。
#  TEST_EVA       = 0：Unique F Regression active 時強制目標閃避率 0。
#
# 【機制規則】
#  1. 只有 ALBERT_CG::UNIQUE_F_V239.active? == true 時才可能生效。
#  2. 只有 obj 對應 Move ID 903 時才覆寫 calc_hit / calc_eva。
#  3. 其他 Unique F 招式、其他 Batch、正式玩家戰鬥全部沿用既有方法鏈。
#  4. 不改 CG_Pokemon_UniqueMove_BatchF_v2_3_9a.rb 原檔，保持正式 Batch F
#     Runtime 與既有封版來源 byte-exact；本腳本只補 regression isolation。
#
# 【可調參數】
#  TARGET_MOVE_ID：若未來 Unique F deterministic 測試改測其他非 100 命中招式，
#                  可另行擴充，但目前只處理已被 Release Gate 證明會造成假 FAIL 的 903。
#  TEST_HIT / TEST_EVA：原則上固定 100 / 0，不建議在正式 regression 中改動。
#
# 【事件／腳本呼叫方式】
#  無須事件呼叫。本腳本由 Data/Scripts.rvdata 載入後自動包裝 Game_Battler。
#  F11 Full Move Lifecycle Master 啟動 Unique F phase 時會自動生效。
#
# 【實際範例】
#  Unique F Regression：耿鬼使用 Move 903 Syrup Bomb → calc_hit=100、calc_eva=0，
#  必定建立 3-turn syrup marker，後續才能穩定 ASSERT 三次回合末 SPE -1。
#  正式遊戲：玩家平常使用 Syrup Bomb → 本腳本不介入，仍使用原始 85% 命中率。
#==============================================================================
module ALBERT_CG
  module UNIQUE_F_RNG_ISO_V245A
    TARGET_MOVE_ID = 903
    TEST_HIT = 100
    TEST_EVA = 0

    def self.active_for?(obj)
      return false unless defined?(ALBERT_CG::UNIQUE_F_V239)
      return false unless ALBERT_CG::UNIQUE_F_V239.active?
      return false if obj == nil
      mid = ALBERT_CG::MOVE_EFFECT.move_id(obj)
      return mid.to_i == TARGET_MOVE_ID
    rescue
      return false
    end
  end
end

class Game_Battler
  alias cg_v245a_unique_f_rng_calc_hit calc_hit
  def calc_hit(user, obj = nil)
    if ALBERT_CG::UNIQUE_F_RNG_ISO_V245A.active_for?(obj)
      return ALBERT_CG::UNIQUE_F_RNG_ISO_V245A::TEST_HIT
    end
    return cg_v245a_unique_f_rng_calc_hit(user, obj)
  end

  alias cg_v245a_unique_f_rng_calc_eva calc_eva
  def calc_eva(user, obj = nil)
    if ALBERT_CG::UNIQUE_F_RNG_ISO_V245A.active_for?(obj)
      return ALBERT_CG::UNIQUE_F_RNG_ISO_V245A::TEST_EVA
    end
    return cg_v245a_unique_f_rng_calc_eva(user, obj)
  end
end
