# RMVX_SCRIPT_INDEX: 192
# RMVX_SCRIPT_ID: 98941290
# RMVX_SCRIPT_NAME: CG Pokemon Protect Guard Action Dedup v2.3.2b
# RMVX_SOURCE_SHA256: 336d105a4316fb0205cfa9f939810dda188d1ddb04b84c40445baa2c26e82dd3

#==============================================================================
# ■ CG Pokemon Protect Guard Action Dedup v2.3.2b
#==============================================================================
# 【用途】
#  延續 v2.3.2a 的 Protect 根修正，進一步處理 Tankentai SBS 在同一個實際 Action
#  內可能多次進入 Game_Battler#skill_effect / attack_effect 的情況。
#
#  v2.3.2a 已證明「守住真的能把傷害擋成 0」，但自動測試觀察到一個神速 Action
#  會讓 Protect 攔截器被呼叫兩次。這不是兩次真正的攻擊，也沒有造成兩次傷害，
#  而是 SBS 內部傷害流程對同一 Action 有重入。若把每次方法呼叫都當成一個
#  「被擋下的技能」，Regression Test 會誤判，也會讓未來多段攻擊／特性觸發的
#  統計失真。
#
# 【正式規則】
#  1. Protect 有效性仍以 @cg_protect_v231 回合旗標為主，State 僅做 UI／相容。
#  2. attack_effect / skill_effect 每次進入都必須阻止 HP、MP、狀態穿透。
#  3. 額外區分兩種計數：
#       Raw Intercept Count ＝ 引擎實際進入攔截器的次數。
#       Action Block Count  ＝ 玩家視角真正被 Protect 擋下的「獨立 Action」次數。
#  4. Scene_Battle 每開始一個實際 Action 都給使用者一個遞增 serial。
#     同一 serial 即使 SBS 重入兩次、或多段技能重複進 skill_effect，Action Block
#     只計一次；但每次重入仍然會 return，確保任何 Hit 都無法穿透 Protect。
#  5. 多目標技能：每個受 Protect 保護的 Target 自己各計一個 blocked action。
#  6. 多段技能：同一 Target 對同一 Action 只計一個 blocked action，但所有 Hit
#     仍逐一被攔截，不會因去重而讓第二 Hit 之後漏傷害。
#  7. Protect 仍由 v2.3.1 Scene_Battle#turn_end 清除；下一回合不殘留。
#
# 【主要設定／除錯 API】
#  battler.cg_protect_active_v232b?
#      本回合是否受 Protect 保護。
#  battler.cg_protect_raw_intercept_count_v232b
#      低階攔截器實際被叫幾次，只供診斷。
#  battler.cg_protect_action_block_count_v232b
#      真正被擋下幾個獨立 Action，Regression Test 應以此為準。
#
# 【事件／腳本呼叫】
#  正式遊戲不需事件呼叫。使用 Protect / Detect / Max Guard 後自動生效。
#
# 【實際範例】
#  水箭龜：守住（Priority +4）
#  路卡利歐：神速（Priority +2）
#
#  Tankentai 若對神速同一 Action 內部進 skill_effect 兩次：
#      raw_intercept  : 0 -> 2
#      action_block   : 0 -> 1
#      水箭龜 HP      : 完全不變
#
#  下一回合：
#      @cg_protect_v231 清除，普通傷害重新正常生效。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_ProtectGuardHotfix"] = "2.3.2b"

class Game_Battler
  #--------------------------------------------------------------------------
  # * Protect 本回合是否有效
  #--------------------------------------------------------------------------
  def cg_protect_active_v232b?
    return true if instance_variable_get(:@cg_protect_v231) == true
    if defined?(ALBERT_CG::MOVE_EFFECT) &&
       ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_PROTECT)
      return true if state?(ALBERT_CG::MOVE_EFFECT::STATE_PROTECT)
    end
    return false
  end

  # v2.3.2a 相容 API
  def cg_protect_active_v232a?
    return cg_protect_active_v232b?
  end

  #--------------------------------------------------------------------------
  # * 是否為應被 Protect 擋下的敵對 Action
  #--------------------------------------------------------------------------
  def cg_protect_blocks_v232b?(user)
    return false unless cg_protect_active_v232b?
    return false if user == nil || user == self
    return false unless user.respond_to?(:actor?) && respond_to?(:actor?)
    return false if user.actor? == actor?
    return true
  end

  #--------------------------------------------------------------------------
  # * 取得目前 Action 的穩定 token
  #--------------------------------------------------------------------------
  def cg_protect_action_token_v232b(user)
    return nil if user == nil
    serial = user.instance_variable_get(:@cg_current_action_serial_v232b).to_i
    if serial > 0
      side = user.actor? ? 1 : 0
      idx = user.respond_to?(:index) ? user.index.to_i : -1
      return [side, idx, serial]
    end

    # 非 Scene_Battle 單元測試／特殊腳本呼叫時的 fallback。
    # action.object_id 可在同一呼叫鏈內辨識同一 Game_BattleAction。
    action_id = 0
    begin
      action_id = user.action.object_id if user.respond_to?(:action) && user.action != nil
    rescue
      action_id = 0
    end
    return [user.object_id, action_id]
  end

  #--------------------------------------------------------------------------
  # * Protect 擋下 Action：每次重入都清理 Result，但 Action 計數去重
  #--------------------------------------------------------------------------
  def cg_apply_protect_block_v232b(user, label)
    clear_action_results
    @skipped = true
    @hp_damage = 0 if respond_to?(:hp_damage=)
    @mp_damage = 0 if respond_to?(:mp_damage=)

    raw = instance_variable_get(:@cg_protect_raw_intercept_count_v232b).to_i + 1
    instance_variable_set(:@cg_protect_raw_intercept_count_v232b, raw)

    token = cg_protect_action_token_v232b(user)
    last_token = instance_variable_get(:@cg_last_protect_action_token_v232b)
    distinct = instance_variable_get(:@cg_protect_action_block_count_v232b).to_i
    new_action = (token == nil || token != last_token)
    if new_action
      distinct += 1
      instance_variable_set(:@cg_protect_action_block_count_v232b, distinct)
      instance_variable_set(:@cg_last_protect_action_token_v232b, token)
    end

    if defined?(ALBERT_CG::MOVE_EFFECT)
      kind = new_action ? "ACTION" : "RAW_DUP"
      ALBERT_CG::MOVE_EFFECT.log("V232B_PROTECT_BLOCK_" + kind.to_s +
        " target=" + name.to_s + " user=" + user.name.to_s +
        " action=" + label.to_s + " raw=" + raw.to_s +
        " distinct=" + distinct.to_s + " token=" + token.inspect)
    end
    return true
  end

  def cg_protect_raw_intercept_count_v232b
    return instance_variable_get(:@cg_protect_raw_intercept_count_v232b).to_i
  end

  def cg_protect_action_block_count_v232b
    return instance_variable_get(:@cg_protect_action_block_count_v232b).to_i
  end

  # v2.3.2a 舊測試 API 仍回傳「獨立 Action 數」，避免其他 Debug 腳本壞掉。
  def cg_protect_block_count_v232a
    return cg_protect_action_block_count_v232b
  end

  #--------------------------------------------------------------------------
  # * 普通攻擊 Protect 攔截
  #--------------------------------------------------------------------------
  alias cg_v232b_attack_effect attack_effect
  def attack_effect(attacker)
    if cg_protect_blocks_v232b?(attacker)
      cg_apply_protect_block_v232b(attacker, "Attack")
      return
    end
    cg_v232b_attack_effect(attacker)
  end

  #--------------------------------------------------------------------------
  # * 技能 Protect 攔截
  #--------------------------------------------------------------------------
  alias cg_v232b_skill_effect skill_effect
  def skill_effect(user, skill)
    if cg_protect_blocks_v232b?(user)
      mid = 0
      if defined?(ALBERT_CG::MOVE_EFFECT)
        mid = ALBERT_CG::MOVE_EFFECT.move_id(skill)
      end
      cg_apply_protect_block_v232b(user,
        "Skill#" + mid.to_s + ":" + skill.name.to_s)
      return
    end
    cg_v232b_skill_effect(user, skill)
  end
end

#==============================================================================
# ■ Scene_Battle：每個實際 Action 配發唯一 serial
#------------------------------------------------------------------------------
# Priority 自動測試腳本載入在本腳本之後，會再包一層 execute_action；最終呼叫鏈仍
# 會進到這裡，因此正式戰鬥與 Debug 自動戰鬥都能取得 serial。
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v232b_protect_execute_action execute_action
  def execute_action
    @cg_action_serial_counter_v232b = @cg_action_serial_counter_v232b.to_i + 1
    if @active_battler != nil
      @active_battler.instance_variable_set(:@cg_current_action_serial_v232b,
        @cg_action_serial_counter_v232b)
    end
    cg_v232b_protect_execute_action
  end
end
