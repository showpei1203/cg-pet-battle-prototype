# RMVX_SCRIPT_INDEX: 131
# RMVX_SCRIPT_ID: 98941049
# RMVX_SCRIPT_NAME: CG Paired Move Runtime Fix v0.5.14
# RMVX_SOURCE_SHA256: 90c326bb985cc5dad8851a896ffbb0a66ff7672ab1e6fcbf6015c94ce950cdb4

#==============================================================================
# ** ALBERT CG 主人／寵物換位執行期最終修正
#------------------------------------------------------------------------------
#  版本：v0.5.14
#  引擎：RPG Maker VX／RGSS2
#  前置：CG Battle Pair Authority v0.5.12
#        CG Paired Move Execution Fix v0.5.13
#------------------------------------------------------------------------------
# 【修正目的】
#  v0.5.13 已能在指令階段找到正確的主人／寵物配對，但執行階段仍呼叫
#  舊版 cg_swap_human_and_pet_slots。該方法內含多層舊主人判定與 members
#  物件比對，普通 Actor 固定寵物可能在其中被拒絕，於是畫面顯示：
#    「交換位置失敗：目前沒有可交換的自己的主人或寵物。」
#
# 【本版作法】
#  1. 執行換位時，只承認 CG Battle Pair Authority 的權威配對表。
#  2. 不再呼叫舊版 cg_swap_human_and_pet_slots。
#  3. 直接以 Actor ID 確認主人與寵物都在實際隊伍 @actors 中。
#  4. 直接交換雙方的戰場 row／column，再同步 Tankentai 位移資料。
#  5. 主人與寵物任一方主動使用「移動」，都會執行完全相同的流程。
#
# 【正式規則】
#  - Tom 只能與目前出戰的主角 Clone 寵物交換。
#  - Actor 2 只能與固定寵物 Actor 103 交換。
#  - 寵物也能主動與自己的主人交換。
#  - 行動執行前若配對已改變，改用目前仍合法的配對對象。
#  - 任一方離場、死亡或沒有有效站位時，才取消換位。
#
# 【腳本位置】
#  必須放在「CG Paired Move Execution Fix v0.5.13」下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PairedMoveRuntimeFix"] = true

module ALBERT_CG
  PAIRED_MOVE_RUNTIME_FIX_VERSION = "0.5.14"
end

#==============================================================================
# ■ Game_Party
#------------------------------------------------------------------------------
#  以權威配對表直接交換格位，不經過舊版主人欄位與物件身分判定。
#==============================================================================
class Game_Party < Game_Unit
  # 回傳 [主人, 寵物]。actor_a／actor_b 任一方可先傳。
  def cg_v0514_pair_members(actor_a, actor_b = nil)
    return nil if actor_a == nil
    table = cg_battle_pair_table
    a_id = actor_a.respond_to?(:id) ? actor_a.id.to_i : actor_a.to_i
    b_id = actor_b == nil ? nil :
      (actor_b.respond_to?(:id) ? actor_b.id.to_i : actor_b.to_i)

    if table.has_key?(a_id)
      pet_id = table[a_id].to_i
      return nil if b_id != nil && b_id != pet_id
      owner = cg_v0512_actor_by_id(a_id)
      pet = cg_v0512_actor_by_id(pet_id)
      return owner == nil || pet == nil ? nil : [owner, pet]
    end

    for owner_id in table.keys
      pet_id = table[owner_id].to_i
      next unless pet_id == a_id
      return nil if b_id != nil && b_id != owner_id.to_i
      owner = cg_v0512_actor_by_id(owner_id)
      pet = cg_v0512_actor_by_id(pet_id)
      return owner == nil || pet == nil ? nil : [owner, pet]
    end
    return nil
  end

  # Actor 是否確實位於底層實際隊伍中。
  def cg_v0514_actor_in_raw_party?(actor)
    return false if actor == nil
    ids = if respond_to?(:cg_v0512_raw_party_ids)
      cg_v0512_raw_party_ids
    else
      @actors = [] if @actors == nil
      @actors.clone
    end
    return ids.include?(actor.id.to_i)
  end

  # 直接交換權威配對雙方的格位。
  def cg_v0514_swap_authoritative_pair(actor_a, actor_b = nil, animated = true)
    pair = cg_v0514_pair_members(actor_a, actor_b)
    return false if pair == nil
    owner = pair[0]
    pet = pair[1]

    return false unless cg_v0514_actor_in_raw_party?(owner)
    return false unless cg_v0514_actor_in_raw_party?(pet)
    return false unless owner.exist? && pet.exist?
    return false unless owner.respond_to?(:cg_battle_slot_assigned?)
    return false unless pet.respond_to?(:cg_battle_slot_assigned?)
    return false unless owner.cg_battle_slot_assigned?
    return false unless pet.cg_battle_slot_assigned?

    owner_old_x = owner.respond_to?(:position_x) ? owner.position_x : 0
    owner_old_y = owner.respond_to?(:position_y) ? owner.position_y : 0
    pet_old_x = pet.respond_to?(:position_x) ? pet.position_x : 0
    pet_old_y = pet.respond_to?(:position_y) ? pet.position_y : 0

    owner_row = owner.cg_battle_row
    owner_column = owner.cg_battle_column
    pet_row = pet.cg_battle_row
    pet_column = pet.cg_battle_column

    owner.cg_set_battle_slot(pet_row, pet_column, true)
    pet.cg_set_battle_slot(owner_row, owner_column, true)

    if animated
      cg_prepare_animated_slot_transition(owner, owner_old_x, owner_old_y)
      cg_prepare_animated_slot_transition(pet, pet_old_x, pet_old_y)
    else
      owner.reset_coordinate if owner.respond_to?(:reset_coordinate)
      pet.reset_coordinate if pet.respond_to?(:reset_coordinate)
      owner.base_position if owner.respond_to?(:base_position)
      pet.base_position if pet.respond_to?(:base_position)
    end
    return true
  end
end

#==============================================================================
# ■ Scene_Battle
#------------------------------------------------------------------------------
#  覆寫最後的換位執行方法。主人與寵物雙方完全共用此流程。
#==============================================================================
class Scene_Battle < Scene_Base
  def cg_execute_swap_pet
    initiator = @active_battler
    if initiator == nil
      cg_show_special_action_text("交換位置失敗：找不到行動者。")
      return
    end

    saved_target = nil
    if initiator.action != nil && initiator.action.respond_to?(:cg_swap_pet_id)
      target_id = initiator.action.cg_swap_pet_id
      saved_target = $game_party.cg_v0512_actor_by_id(target_id) if target_id != nil
    end

    pair = $game_party.cg_v0514_pair_members(initiator, saved_target)
    if pair == nil
      partner = $game_party.cg_battle_pair_partner_for(initiator)
      pair = $game_party.cg_v0514_pair_members(initiator, partner)
    end

    if pair != nil
      owner = pair[0]
      pet = pair[1]
      partner = initiator.id.to_i == owner.id.to_i ? pet : owner
      if $game_party.cg_v0514_swap_authoritative_pair(owner, pet, true)
        cg_play_slot_move_sequence([owner, pet])
        cg_show_special_action_text(initiator.name.to_s + "與" +
          partner.name.to_s + "交換位置。")
        return
      end
    end

    cg_show_special_action_text("交換位置失敗：配對成員已離場、戰鬥不能或站位無效。")
  end
end
