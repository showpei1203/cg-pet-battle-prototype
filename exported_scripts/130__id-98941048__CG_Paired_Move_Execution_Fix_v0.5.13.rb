# RMVX_SCRIPT_INDEX: 130
# RMVX_SCRIPT_ID: 98941048
# RMVX_SCRIPT_NAME: CG Paired Move Execution Fix v0.5.13
# RMVX_SOURCE_SHA256: 78fa8a059ce364fef9f45ab39da1fed9d5a352907039d6f7c78977b45fed23a2

#==============================================================================
# ** ALBERT CG 主人／寵物雙向換位最終修正
#------------------------------------------------------------------------------
#  版本：v0.5.13
#  引擎：RPG Maker VX／RGSS2
#  前置：CG Battle Pair Authority v0.5.12
#------------------------------------------------------------------------------
# 【修正目的】
#  v0.5.12 已能正確建立「主人 Actor ID => 寵物 Actor ID」配對表，
#  但人物指令的「移動」與寵物指令的「移動」仍經過不同的舊 alias 鏈。
#  可能造成：
#  - Actor 2 明明有固定寵物，按下「移動」卻只有拒絕音。
#  - Actor 103 選擇「移動」後，執行階段找不到主人。
#
# 【本版規則】
#  1. 主人與寵物只要存在於戰鬥配對表，就能從「移動」直接安排交換。
#  2. 主人只能與自己的寵物交換；寵物只能與自己的主人交換。
#  3. 執行階段不再只相信舊行動欄位，而會再用配對表確認雙方關係。
#  4. 若下指令後配對已改變，會改用目前仍合法的配對對象。
#  5. 主人沒有寵物時，仍沿用舊版規則，只能移到同列另一排的空格。
#
# 【腳本位置】
#  必須放在「CG Battle Pair Authority v0.5.12」下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PairedMoveExecutionFix"] = true

module ALBERT_CG
  PAIRED_MOVE_EXECUTION_FIX_VERSION = "0.5.13"
end

#==============================================================================
# ■ Game_Party
#------------------------------------------------------------------------------
#  提供單一的「目前配對對象」查詢。輸入主人會回傳寵物，輸入寵物會回傳主人。
#==============================================================================
class Game_Party < Game_Unit
  def cg_battle_pair_partner_for(actor_or_id)
    actor_id = actor_or_id.respond_to?(:id) ? actor_or_id.id.to_i : actor_or_id.to_i
    table = cg_battle_pair_table

    pet_id = table[actor_id]
    return cg_v0512_actor_by_id(pet_id) if pet_id != nil

    for owner_id in table.keys
      if table[owner_id].to_i == actor_id
        return cg_v0512_actor_by_id(owner_id)
      end
    end
    return nil
  end

  # 回傳 [主人, 寵物]；不是目前合法配對時回傳 nil。
  def cg_battle_pair_members(actor_a, actor_b)
    return nil if actor_a == nil || actor_b == nil
    table = cg_battle_pair_table
    a_id = actor_a.id.to_i
    b_id = actor_b.id.to_i

    if table[a_id].to_i == b_id
      return [actor_a, actor_b]
    elsif table[b_id].to_i == a_id
      return [actor_b, actor_a]
    end
    return nil
  end
end

#==============================================================================
# ■ Scene_Battle
#------------------------------------------------------------------------------
#  統一攔截主人與寵物的「移動」，並在執行階段重新驗證配對。
#==============================================================================
class Scene_Battle < Scene_Base
  alias albert_cg_v0513_update_actor_command_selection update_actor_command_selection
  def update_actor_command_selection
    if Input.trigger?(Input::C) && @active_battler != nil &&
       @actor_command_window != nil &&
       @actor_command_window.respond_to?(:cg_command_type) &&
       @actor_command_window.cg_command_type == :move
      partner = $game_party.cg_battle_pair_partner_for(@active_battler)

      # 有目前合法配對時，直接保存交換行動。因為每人只有一個合法對象，
      # 不再多開一個只有一項內容的彈出選單。
      if partner != nil && @active_battler.exist? && partner.exist? &&
         @active_battler.cg_battle_slot_assigned? &&
         partner.cg_battle_slot_assigned?
        Sound.play_decision
        @active_battler.action.cg_set_swap_pet(partner.id)
        next_actor
        return
      end

      # 寵物沒有合法主人時不可自行移到其他格位。
      if @active_battler.respond_to?(:cg_battle_pet?) &&
         @active_battler.cg_battle_pet?
        Sound.play_buzzer
        return
      end

      # 沒有寵物的主人仍交回舊流程，讓他移到同列另一排的空格。
    end
    albert_cg_v0513_update_actor_command_selection
  end

  # 執行主人／寵物交換。行動中保存的 target ID 只作為第一候選，
  # 若配對在行動前已改變，則改用目前權威配對表中的合法對象。
  def cg_execute_swap_pet
    initiator = @active_battler
    saved_target = nil
    if initiator != nil && initiator.action != nil
      target_id = initiator.action.cg_swap_pet_id
      saved_target = $game_party.cg_v0512_actor_by_id(target_id) if target_id != nil
    end

    pair = $game_party.cg_battle_pair_members(initiator, saved_target)
    if pair == nil
      current_partner = $game_party.cg_battle_pair_partner_for(initiator)
      pair = $game_party.cg_battle_pair_members(initiator, current_partner)
    end

    if pair != nil
      owner = pair[0]
      pet = pair[1]
      if owner.exist? && pet.exist? &&
         owner.cg_battle_slot_assigned? && pet.cg_battle_slot_assigned? &&
         $game_party.cg_swap_human_and_pet_slots(owner, pet, true)
        cg_play_slot_move_sequence([owner, pet])
        cg_show_special_action_text(initiator.name.to_s + "與" +
          (initiator == owner ? pet.name.to_s : owner.name.to_s) + "交換位置。")
        return
      end
    end

    cg_show_special_action_text("交換位置失敗：目前沒有可交換的自己的主人或寵物。")
  end
end
