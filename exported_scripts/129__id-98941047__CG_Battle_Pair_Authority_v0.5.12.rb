# RMVX_SCRIPT_INDEX: 129
# RMVX_SCRIPT_ID: 98941047
# RMVX_SCRIPT_NAME: CG Battle Pair Authority v0.5.12
# RMVX_SOURCE_SHA256: d13b7b59313c8105cf2a3b2310cdbae25cf9b87bfc30f5f12bcfd44d2669b15e

#==============================================================================
# ** ALBERT CG 戰鬥主人／寵物配對權威表
#------------------------------------------------------------------------------
#  版本：v0.5.12
#  引擎：RPG Maker VX／RGSS2
#  前置：CG Fixed Pet Battle Role v0.5.11
#------------------------------------------------------------------------------
# 【修正目的】
#  舊版雖然能把普通 Actor 103 畫在 Actor 2 前方，人物／寵物指令建立、
#  二動判定與移動選單卻可能讀取不同的出戰快取，造成以下問題：
#  - Actor 2 被誤判為沒有寵物，因此取得兩次人物行動。
#  - Actor 103 雖在戰場上，卻沒有建立自己的寵物指令欄位。
#  - Actor 2 的「移動」有文字，但找不到可交換的自己的寵物。
#
# 【本版核心】
#  每次建立戰鬥指令前，依 Game_Party 實際 @actors 重建唯一配對表：
#    主人 Actor ID => 目前實際出戰的寵物 Actor ID
#
#  主角：配對目前位於隊伍中的 Clone 寵物。
#  隊友：依 FIXED_PARTNER_PET_ACTORS 配對普通資料庫 Actor 固定寵物。
#
# 【正式規則】
#  1. 配對表存在且寵物存活：主人一動、寵物一動。
#  2. 寵物不存在或戰鬥不能：主人取得第二動。
#  3. 寵物存活但因狀態無法輸入：主人不會因此多得到一動。
#  4. 主人只能與配對表中的自己的寵物交換位置。
#  5. 寵物只能與配對表中的自己的主人交換位置。
#  6. 普通 Actor 固定寵物也使用寵物指令，包含「移動」。
#
# 【腳本位置】
#  請放在「CG Fixed Pet Battle Role」下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattlePairAuthority"] = true

module ALBERT_CG
  BATTLE_PAIR_AUTHORITY_VERSION = "0.5.12"
end

#==============================================================================
# ■ Game_Party
#------------------------------------------------------------------------------
#  所有戰鬥配對、人物清單與目前寵物查詢都改讀同一張權威表。
#==============================================================================
class Game_Party < Game_Unit
  # 不經 members，直接從底層 @actors 取得實際隊伍 ID，避免同步遞迴。
  def cg_v0512_raw_party_ids
    @actors = [] if @actors == nil
    return @actors.clone
  end

  # 同時支援普通 Actor 與 Clone Actor 的查詢。
  def cg_v0512_actor_by_id(actor_id)
    actor_id = actor_id.to_i
    if $game_actors != nil && $game_actors.respond_to?(:cg_pet)
      pet = $game_actors.cg_pet(actor_id)
      return pet if pet != nil
    end
    return $game_actors == nil ? nil : $game_actors[actor_id]
  end

  # 依目前實際隊伍重建「主人 ID => 寵物 ID」。
  def cg_rebuild_battle_pair_table!
    cg_sync_fixed_partner_pets! if respond_to?(:cg_sync_fixed_partner_pets!)
    ids = cg_v0512_raw_party_ids
    table = {}

    # 主角的自由 Clone 寵物：實際位於隊伍中的那一隻才算出戰。
    primary_id = ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID.to_i
    if ids.include?(primary_id)
      for actor_id in ids
        actor = cg_v0512_actor_by_id(actor_id)
        next if actor == nil
        next unless actor.respond_to?(:cg_pet?) && actor.cg_pet?
        if respond_to?(:cg_owned_pet_ids)
          next unless cg_owned_pet_ids.include?(actor.id)
        end
        table[primary_id] = actor.id
        break
      end
    end

    # 隊友固定普通 Actor 寵物：主人與寵物都實際在隊伍中才成立。
    fixed_map = if respond_to?(:cg_v0511_fixed_partner_map)
      cg_v0511_fixed_partner_map
    elsif respond_to?(:cg_v056_fixed_partner_map)
      cg_v056_fixed_partner_map
    else
      defined?(ALBERT_CG::FIXED_PARTNER_PET_ACTORS) ?
        ALBERT_CG::FIXED_PARTNER_PET_ACTORS : {}
    end
    for owner_id in fixed_map.keys
      owner_id = owner_id.to_i
      pet_id = fixed_map[owner_id].to_i
      next unless ids.include?(owner_id)
      next unless ids.include?(pet_id)
      next if cg_v0512_actor_by_id(owner_id) == nil
      next if cg_v0512_actor_by_id(pet_id) == nil
      table[owner_id] = pet_id
    end

    @cg_battle_pair_table = table
    return @cg_battle_pair_table
  end

  # 每次查詢都重建。隊伍最多四人，這比維護另一份容易腐敗的快取便宜得多。
  def cg_battle_pair_table
    return cg_rebuild_battle_pair_table!
  end

  def cg_battle_pair_pet_for(owner_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ?
      owner_actor_or_id.id.to_i : owner_actor_or_id.to_i
    pet_id = cg_battle_pair_table[owner_id]
    return pet_id == nil ? nil : cg_v0512_actor_by_id(pet_id)
  end

  def cg_battle_pair_owner_for(pet_actor_or_id)
    pet_id = pet_actor_or_id.respond_to?(:id) ?
      pet_actor_or_id.id.to_i : pet_actor_or_id.to_i
    table = cg_battle_pair_table
    for owner_id in table.keys
      return cg_v0512_actor_by_id(owner_id) if table[owner_id].to_i == pet_id
    end
    return nil
  end

  def cg_battle_pair?(owner, pet)
    return false if owner == nil || pet == nil
    return cg_battle_pair_table[owner.id.to_i].to_i == pet.id.to_i
  end

  # 舊腳本所用的查詢名稱全部導向權威表。
  def cg_active_pet_for(human)
    return nil if human == nil
    return cg_battle_pair_pet_for(human)
  end

  def cg_battle_owner_for_pet(pet)
    return nil if pet == nil
    return cg_battle_pair_owner_for(pet)
  end

  def cg_owner_pet_pair?(owner, pet)
    return cg_battle_pair?(owner, pet)
  end

  # 人物清單直接由實際隊伍扣除所有 Clone 與固定寵物，不再依舊快取判斷。
  def cg_human_members
    result = []
    pair_pet_ids = cg_battle_pair_table.values.collect { |id| id.to_i }
    for actor_id in cg_v0512_raw_party_ids
      actor = cg_v0512_actor_by_id(actor_id)
      next if actor == nil
      is_clone_pet = actor.respond_to?(:cg_pet?) && actor.cg_pet?
      is_pair_pet = pair_pet_ids.include?(actor.id.to_i)
      is_fixed_pet = respond_to?(:cg_fixed_partner_pet_actor?) &&
        cg_fixed_partner_pet_actor?(actor.id)
      next if is_clone_pet || is_pair_pet || is_fixed_pet
      result.push(actor)
    end
    return result
  end

  # 既有預設站位完成後，再以權威配對表把每隻寵物放到主人同列另一排。
  alias albert_cg_v0512_assign_default_slots cg_assign_default_battle_slots
  def cg_assign_default_battle_slots
    result = albert_cg_v0512_assign_default_slots
    table = cg_battle_pair_table
    for owner_id in table.keys
      owner = cg_v0512_actor_by_id(owner_id)
      pet = cg_v0512_actor_by_id(table[owner_id])
      next if owner == nil || pet == nil
      next unless owner.respond_to?(:cg_battle_slot_assigned?)
      next unless owner.cg_battle_slot_assigned?
      desired_row = owner.cg_front_row? ? :back : :front
      desired_column = owner.cg_battle_column
      next if cg_slot_occupied_by_other?(desired_row, desired_column, pet, false)
      pet.cg_set_default_battle_slot(desired_row, desired_column)
    end
    return result
  end
end

#==============================================================================
# ■ Scene_Battle
#------------------------------------------------------------------------------
#  直接重建人物／寵物指令欄位，避免舊 alias 鏈再次把固定寵物跳過。
#==============================================================================
class Scene_Battle < Scene_Base
  def cg_build_input_slots
    @cg_input_slots = []
    @cg_input_slot_index = -1
    $game_party.cg_rebuild_battle_pair_table! if
      $game_party.respond_to?(:cg_rebuild_battle_pair_table!)
    humans = $game_party.cg_human_members

    for human in humans
      next unless human.exist?
      human_can_input = human.inputable? || human.auto_battle
      first_slot = nil
      if human_can_input
        first_slot = cg_make_slot(human, 1, "人物行動")
        @cg_input_slots.push(first_slot)
      end

      pet = $game_party.cg_battle_pair_pet_for(human)
      pet_in_party = pet != nil &&
        $game_party.cg_v0512_raw_party_ids.include?(pet.id.to_i)
      living_pet = pet_in_party && pet.exist?

      if living_pet
        # 寵物存活但因狀態不能輸入時，主人也不會白拿第二動。
        if pet.inputable? || pet.auto_battle
          @cg_input_slots.push(cg_make_slot(pet, 1, "寵物行動"))
        end
      elsif human_can_input
        first_slot.label = "人物行動 1" if first_slot != nil
        @cg_input_slots.push(cg_make_slot(human, 2, "人物行動 2"))
      end
    end
    return @cg_input_slots
  end

  # 主人與寵物的移動選單全部改讀同一份配對表。
  def cg_move_entries
    entries = []
    battler = @active_battler
    return entries if battler == nil

    is_pet = battler.respond_to?(:cg_battle_pet?) && battler.cg_battle_pet?
    if is_pet
      owner = $game_party.cg_battle_pair_owner_for(battler)
      if owner != nil && owner.exist? && battler.exist? &&
         owner.cg_battle_slot_assigned? && battler.cg_battle_slot_assigned?
        entries.push({:type => :swap_pair,
          :target_id => owner.id,
          :text => "與自己的主人交換位置"})
      end
      return entries
    end

    return entries unless $game_party.cg_owner_pet_manager?(battler)
    pet = $game_party.cg_battle_pair_pet_for(battler)
    if pet != nil
      if battler.exist? && pet.exist? &&
         battler.cg_battle_slot_assigned? && pet.cg_battle_slot_assigned?
        entries.push({:type => :swap_pair,
          :target_id => pet.id,
          :text => "與自己的寵物交換位置"})
      end
      return entries
    end

    # 寵物未出戰時，只能移到自己同列另一排的寵物空格。
    return entries unless battler.cg_battle_slot_assigned?
    row = battler.cg_front_row? ? :back : :front
    column = battler.cg_battle_column
    unless $game_party.cg_slot_occupied_by_other?(row, column, battler, false)
      entries.push({:type => :move,
        :text => "移至自己的寵物空位「" +
                 ALBERT_CG.cg_slot_text(row, column) + "」",
        :row => row, :column => column})
    end
    return entries
  end
end
