# RMVX_SCRIPT_INDEX: 254
# RMVX_SCRIPT_ID: 230000001
# RMVX_SCRIPT_NAME: CG Pokemon Sideview Perish Lifecycle Bridge v2.3.0a
# RMVX_SOURCE_SHA256: 86e0a85006dac49ec2c6e15e3d0ba2cc47e0814498b561f60c6cc60a54594a81

#==============================================================================
# ■ CG Pokemon Sideview Perish Lifecycle Bridge v2.3.0a
#------------------------------------------------------------------------------
# 【用途】
#  修正 RPG Maker VX + Tankentai Sideview 3.3 正式戰鬥中，既有 Pokémon Move Core
#  的 Perish／滅亡倒數沒有被 Scene_Battle#turn_end 執行的相容性問題。
#
# 【主要設定項】
#  本腳本沒有需要事件端調整的常數。正式狀態 ID、倒數欄位與 KO 規則全部沿用：
#    ALBERT_CG::MOVE_EFFECT::STATE_PERISH
#    battler 的 @cg_perish_count
#
# 【機制規則】
#  1. 原 VX Scene_Battle#turn_end 會呼叫 Game_Unit#slip_damage_effect；Move Core 因此把
#     Perish count 3→2→1→0，0 時令該 battler 戰鬥不能。
#  2. Tankentai Sideview 3.3 重新定義 Scene_Battle#turn_end，改成直接解析 State 的
#     SLIPDAMAGE extension，因此完全繞過 Game_Unit#slip_damage_effect。
#  3. 本 Bridge 只補「Perish 倒數」這一條被 Sideview 漏掉的正式 lifecycle；不處理
#     Poison／Burn／Trap／Leech Seed／Ingrain，避免和 Sideview 自己的 residual 流程重複傷害。
#  4. 僅處理仍在場、存活且持有 STATE_PERISH 的 battler。count 若為 nil，沿用 Move Core
#     的既有規則先初始化為 3，再於本回合結束時減 1。
#  5. count 歸零時，傷害等於當前 HP，使用既有 hp_damage / hp=0；若 Sideview spriteset
#     可用則顯示傷害 POP 並執行 collapse。
#  6. 若目前版本存在 Ability AE 的 residual KO listener，Perish KO 後只通知該既有 listener，
#     讓 Soul-Heart 等「其他 Pokémon 倒下」效果收到真正的 KO transition；Bridge 本身不實作 Ability。
#  7. 不修改既有 Move Core、Sideview、Ability A～AD 已 PASS scripts；這是一個獨立相容層。
#
# 【可調參數】
#  無。Perish 初始值固定沿用既有 Move Core 的 3；若未來正式 Move Core 改規則，應同步
#  調整本 Bridge，而不是在事件中覆寫。
#
# 【依賴與載入順序】
#  - 必須位於 CG Pokemon Move Effect Core v2.3.0 之後。
#  - 必須位於 Tankentai Sideview 3.3 之後，因為本腳本包覆其 Scene_Battle#turn_end。
#  - v2.5.30b 專案中放在所有 v2.5.29b PASS scripts 之後、Ability Batch AE 之前；
#    這樣 AE F11 assertion 先讀取「turn_end 前」count，再由本 Bridge 執行正式倒數。
#
# 【事件／腳本呼叫方式】
#  正式遊戲不需任何事件呼叫。只要 battler 已持有 STATE_PERISH，回合結束自動處理。
#
# 【實際範例】
#  Perish Body 於 Round1 讓 E2 取得 STATE_PERISH 並設 @cg_perish_count=3：
#    Round1 turn_end：3 -> 2
#    Round2 turn_end：2 -> 1
#    Round3 turn_end：1 -> 0，E2 HP -> 0
#
# 【v2.3.0a 修正理由】
#  v2.5.30a RPG Maker VX 實機 LOG 已證明 STATE_PERISH 與 count=3 建立成功，但經過
#  Round1／Round2 正式 Scene_Battle#turn_end 後 count 仍維持 3。Source audit 確認
#  Sideview 3.3 的 turn_end 沒有呼叫 Game_Unit#slip_damage_effect，因此這是正式 SBS
#  lifecycle 相容性缺口，不是 Regression expectation 問題。
#==============================================================================

module ALBERT_CG
  module SIDEVIEW_PERISH_V230A
    VERSION = "2.3.0a"

    def self.state_id
      return 0 unless defined?(ALBERT_CG::MOVE_EFFECT)
      return 0 unless ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_PERISH)
      ALBERT_CG::MOVE_EFFECT::STATE_PERISH.to_i
    rescue
      0
    end

    def self.active_battle_members
      list = []
      list.concat($game_party.members) if $game_party != nil
      list.concat($game_troop.members) if $game_troop != nil
      list
    rescue
      []
    end

    def self.tick_one(battler)
      sid = state_id
      return nil if sid <= 0 || battler == nil
      return nil if battler.respond_to?(:exist?) && !battler.exist?
      return nil if battler.hp.to_i <= 0
      return nil unless battler.state?(sid)

      count = battler.instance_variable_get(:@cg_perish_count)
      count = 3 if count == nil
      count = count.to_i - 1
      battler.instance_variable_set(:@cg_perish_count, count)

      if count <= 0
        hp_before = battler.hp.to_i
        battler.hp_damage = hp_before if battler.respond_to?(:hp_damage=)
        battler.hp = 0
        ALBERT_CG::MOVE_EFFECT.log("PERISH_KO battler=" + battler.name.to_s) if defined?(ALBERT_CG::MOVE_EFFECT)
        return {:battler=>battler, :count=>0, :hp_before=>hp_before, :ko=>true}
      end

      ALBERT_CG::MOVE_EFFECT.log("PERISH_COUNT battler=" + battler.name.to_s + " count=" + count.to_s) if defined?(ALBERT_CG::MOVE_EFFECT)
      {:battler=>battler, :count=>count, :hp_before=>battler.hp.to_i, :ko=>false}
    rescue
      nil
    end

    def self.tick_all
      result = []
      active_battle_members.each do |battler|
        rec = tick_one(battler)
        result.push(rec) if rec != nil
      end
      result
    rescue
      []
    end

    def self.notify_residual_ko(rec)
      return false if rec == nil || rec[:ko] != true
      return false unless defined?(ALBERT_CG::ABILITY_AE_V2530)
      return false unless ALBERT_CG::ABILITY_AE_V2530.respond_to?(:handle_residual_ko)
      ALBERT_CG::ABILITY_AE_V2530.handle_residual_ko(rec[:battler], rec[:hp_before].to_i)
    rescue
      false
    end
  end
end

class Scene_Battle < Scene_Base
  alias cg_v230a_sideview_perish_turn_end turn_end
  def turn_end
    records = ALBERT_CG::SIDEVIEW_PERISH_V230A.tick_all
    records.each do |rec|
      next if rec == nil || rec[:ko] != true
      b = rec[:battler]
      if @spriteset != nil && @spriteset.respond_to?(:set_damage_pop) && b != nil
        @spriteset.set_damage_pop(b.actor?, b.index, rec[:hp_before].to_i)
      end
      b.perform_collapse if b != nil && b.respond_to?(:perform_collapse)
      ALBERT_CG::SIDEVIEW_PERISH_V230A.notify_residual_ko(rec)
    end
    cg_v230a_sideview_perish_turn_end
  end
end
