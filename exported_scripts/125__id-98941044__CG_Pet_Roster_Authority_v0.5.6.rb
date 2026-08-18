# RMVX_SCRIPT_INDEX: 125
# RMVX_SCRIPT_ID: 98941044
# RMVX_SCRIPT_NAME: CG Pet Roster Authority v0.5.6
# RMVX_SOURCE_SHA256: 0b8f2692aebb4433a29d2a47579f321908a6c459c6b88790a7feaca4bb13a5a8

#==============================================================================
# ** ALBERT CG 主角寵物名冊／出戰權威層
#------------------------------------------------------------------------------
#  版本：v0.5.6
#  引擎：RPG Maker VX／RGSS2
#  前置：CG Pet Clone Core、CG Battle Move Pet Switch
#------------------------------------------------------------------------------
# 【修正目的】
#  主角 Clone 寵物曾同時由「名冊、主人欄位、出戰快取、實際隊伍」判定，
#  因此會發生 F5 看得到寵物卻無法設為出戰，或戰鬥畫面有寵物但收回失敗。
#  本頁把資料責任拆成兩層：
#
#    主角持有名冊：$game_actors 中所有有效 Clone 寵物
#    主角目前出戰：Game_Party 的 @actors 中實際存在的第一隻 Clone 寵物
#
#  F5 地圖整備與戰鬥換寵使用不同入口，不再拿戰鬥格位條件限制地圖整備。
#
# 【F5 地圖整備】
#    $game_party.cg_map_deploy_pet(個體ID)
#    $game_party.cg_map_recall_pet
#  設為出戰只會更換隊伍中的 Clone，不計算戰鬥空格與戰鬥射程。
#
# 【戰鬥換寵】
#    $game_party.cg_battle_switch_pet(個體ID, 主人)
#    $game_party.cg_battle_recall_pet(主人, 預期個體ID)
#  戰鬥中才會保留原寵物格位、播放動畫並重建 Tankentai Sprite。
#
# 【隊友固定寵物】
#  - 使用普通資料庫 Actor，不使用 Clone Actor。
#  - 在 CG Config 以 FIXED_PARTNER_PET_ACTORS 設定，例如：
#      FIXED_PARTNER_PET_ACTORS = {2 => 103}
#  - Actor 2 入隊後，Actor 103 會直接寫入 Game_Party @actors。
#  - 每次讀取 party members、加入人物及進入戰鬥前，都會再次同步。
#  - 固定寵物不進入 F5，也不會混入主角換寵名單。
#
# 【事件指令】
#  設定隊友固定普通 Actor 寵物：
#    cg_set_fixed_partner_pet(2, 103, true)
#
#  輸出診斷：
#    ALBERT_CG.print_pet_roster_snapshot
#
# 【腳本位置】
#  請放在「CG Battle Move Pet Switch」下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PetRosterAuthority"] = true

module ALBERT_CG
  PET_ROSTER_AUTHORITY_VERSION = "0.5.6"

  def self.pet_roster_snapshot
    lines = []
    lines.push("CG 寵物名冊診斷 v" + PET_ROSTER_AUTHORITY_VERSION)
    if $game_party == nil or $game_actors == nil
      lines.push("遊戲物件尚未建立")
      return lines
    end
    ids = $game_party.cg_owned_pet_ids
    active = $game_party.cg_actual_primary_clone_pet
    lines.push("Clone 名冊 ID：" + ids.inspect)
    lines.push("主角出戰 Clone：" + (active == nil ? "無" : active.id.to_s + " " + active.name.to_s))
    raw_ids = $game_party.cg_raw_actor_ids
    lines.push("Game_Party @actors：" + raw_ids.inspect)
    party_data = []
    for member in $game_party.members
      type = if member.respond_to?(:cg_pet?) && member.cg_pet?
        "主角Clone"
      elsif member.respond_to?(:cg_fixed_partner_pet?) && member.cg_fixed_partner_pet?
        "隊友固定寵物"
      else
        "人物"
      end
      party_data.push(member.id.to_s + ":" + member.name.to_s + "[" + type + "]")
    end
    lines.push("實際隊伍：" + party_data.join("、"))
    return lines
  end

  def self.print_pet_roster_snapshot
    lines = pet_roster_snapshot
    p lines.join("\n") if DEBUG_MESSAGE
    return lines
  end
end

class Game_Party < Game_Unit
  # 保存原始 members，v0.5.6 會在讀取成員前同步隊友固定寵物。
  alias albert_cg_v056_base_members members

  #--------------------------------------------------------------------------
  # ● 低階隊伍資料
  #--------------------------------------------------------------------------
  def cg_raw_actor_ids
    @actors = [] if @actors == nil
    return @actors.clone
  end

  def cg_v056_party_changed
    $game_player.refresh if $game_player != nil
    $party_change = true
  end

  def cg_v056_valid_actor_id?(actor_id)
    actor_id = actor_id.to_i
    return true if $data_actors != nil && $data_actors[actor_id] != nil
    return true if $game_actors != nil && $game_actors.respond_to?(:cg_pet) &&
                   $game_actors.cg_pet(actor_id) != nil
    return false
  end

  def cg_v056_raw_remove_actor(actor_id, notify = true)
    @actors = [] if @actors == nil
    actor_id = actor_id.to_i
    return false unless @actors.include?(actor_id)
    @actors.delete(actor_id)
    cg_v056_party_changed if notify
    return true
  end

  def cg_v056_raw_insert_actor(actor_id, index = nil, notify = true)
    @actors = [] if @actors == nil
    actor_id = actor_id.to_i
    return true if @actors.include?(actor_id)
    return false unless cg_v056_valid_actor_id?(actor_id)
    return false if @actors.size >= Game_Party::MAX_MEMBERS
    if index == nil || index < 0 || index > @actors.size
      @actors.push(actor_id)
    else
      @actors.insert(index, actor_id)
    end
    cg_v056_party_changed if notify
    return true
  end

  #--------------------------------------------------------------------------
  # ● 隊友固定普通 Actor 寵物
  #--------------------------------------------------------------------------
  def cg_v056_fixed_partner_map
    @cg_fixed_partner_pet_map = {} if @cg_fixed_partner_pet_map == nil
    defaults = defined?(ALBERT_CG::FIXED_PARTNER_PET_ACTORS) ?
      ALBERT_CG::FIXED_PARTNER_PET_ACTORS : {}
    result = {}
    for owner_id in defaults.keys
      result[owner_id.to_i] = defaults[owner_id].to_i
    end
    for owner_id in @cg_fixed_partner_pet_map.keys
      result[owner_id.to_i] = @cg_fixed_partner_pet_map[owner_id].to_i
    end
    return result
  end

  def cg_prepare_fixed_partner_pet_data
    @cg_fixed_partner_pet_map = {} if @cg_fixed_partner_pet_map == nil
    defaults = defined?(ALBERT_CG::FIXED_PARTNER_PET_ACTORS) ?
      ALBERT_CG::FIXED_PARTNER_PET_ACTORS : {}
    for owner_id in defaults.keys
      @cg_fixed_partner_pet_map[owner_id.to_i] = defaults[owner_id].to_i unless
        @cg_fixed_partner_pet_map.has_key?(owner_id.to_i)
    end
    return @cg_fixed_partner_pet_map
  end

  def cg_fixed_partner_pet_actor_id(owner_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i
    return cg_v056_fixed_partner_map[owner_id]
  end

  def cg_fixed_partner_owner_id_for(pet_actor_or_id)
    pet_id = pet_actor_or_id.respond_to?(:id) ? pet_actor_or_id.id : pet_actor_or_id.to_i
    map = cg_v056_fixed_partner_map
    for owner_id in map.keys
      return owner_id if map[owner_id] == pet_id
    end
    return nil
  end

  def cg_fixed_partner_pet_actor?(actor_or_id)
    return cg_fixed_partner_owner_id_for(actor_or_id) != nil
  end

  def cg_fixed_partner_pair?(owner_actor_or_id, pet_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i
    pet_id = pet_actor_or_id.respond_to?(:id) ? pet_actor_or_id.id : pet_actor_or_id.to_i
    return cg_fixed_partner_pet_actor_id(owner_id) == pet_id
  end

  # 只操作 @actors，不呼叫 members／add_actor，避免同步遞迴。
  def cg_sync_fixed_partner_pets!
    return false if @cg_v056_syncing_fixed_pets
    @cg_v056_syncing_fixed_pets = true
    @actors = [] if @actors == nil
    changed = false
    map = cg_v056_fixed_partner_map
    for owner_id in map.keys
      pet_id = map[owner_id]
      owner_present = @actors.include?(owner_id)
      pet_present = @actors.include?(pet_id)
      if owner_present && !pet_present
        owner_index = @actors.index(owner_id)
        inserted = cg_v056_raw_insert_actor(pet_id,
          owner_index == nil ? nil : owner_index + 1, false)
        changed = true if inserted
      elsif !owner_present && pet_present
        @actors.delete(pet_id)
        changed = true
      end
    end
    @cg_v056_syncing_fixed_pets = false
    cg_v056_party_changed if changed
    return changed
  end

  def cg_set_fixed_partner_pet(owner_actor_id, pet_actor_id, deploy = true)
    owner_id = owner_actor_id.to_i
    pet_id = pet_actor_id.to_i
    return false if owner_id <= 0 || pet_id <= 0 || owner_id == pet_id
    return false unless cg_v056_valid_actor_id?(owner_id)
    return false unless cg_v056_valid_actor_id?(pet_id)
    @cg_fixed_partner_pet_map = {} if @cg_fixed_partner_pet_map == nil
    old_pet_id = @cg_fixed_partner_pet_map[owner_id]
    if old_pet_id != nil && old_pet_id != pet_id
      cg_v056_raw_remove_actor(old_pet_id)
    end
    @cg_fixed_partner_pet_map[owner_id] = pet_id
    cg_sync_fixed_partner_pets! if deploy
    return true
  end

  def cg_sync_fixed_partner_pet(owner_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i
    cg_sync_fixed_partner_pets!
    pet_id = cg_fixed_partner_pet_actor_id(owner_id)
    return false if pet_id == nil
    return @actors != nil && @actors.include?(pet_id)
  end

  # 每次 UI／戰鬥讀取成員前，保證固定寵物與主人同步。
  def members
    cg_sync_fixed_partner_pets!
    return albert_cg_v056_base_members
  end

  # 直接呼叫 Pet Clone Core 保存的「VX 原始 add_actor」別名，避免舊同步鏈重入。
  def add_actor(actor_id)
    if respond_to?(:albert_cg_v026_add_actor)
      albert_cg_v026_add_actor(actor_id)
    else
      cg_v056_raw_insert_actor(actor_id)
    end
    cg_sync_fixed_partner_pets!
    cg_v056_refresh_active_cache
  end

  def remove_actor(actor_id)
    fixed_pet_id = cg_fixed_partner_pet_actor_id(actor_id)
    if respond_to?(:albert_cg_v026_remove_actor)
      albert_cg_v026_remove_actor(actor_id)
    else
      cg_v056_raw_remove_actor(actor_id)
    end
    cg_v056_raw_remove_actor(fixed_pet_id) if fixed_pet_id != nil
    cg_sync_fixed_partner_pets!
    cg_v056_refresh_active_cache
  end

  #--------------------------------------------------------------------------
  # ● 主角 Clone 名冊與出戰資料
  #--------------------------------------------------------------------------
  def cg_rebuild_primary_pet_roster!
    @cg_owned_pet_ids = [] if @cg_owned_pet_ids == nil
    if $game_actors != nil && $game_actors.respond_to?(:cg_all_pets)
      for pet in $game_actors.cg_all_pets
        next if pet == nil
        @cg_owned_pet_ids.push(pet.id) unless @cg_owned_pet_ids.include?(pet.id)
        pet.cg_assign_owner(ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID, false) if
          pet.respond_to?(:cg_assign_owner)
      end
    end
    valid = []
    for actor_id in @cg_owned_pet_ids
      pet = $game_actors.cg_pet(actor_id.to_i)
      valid.push(pet.id) if pet != nil && !valid.include?(pet.id)
    end
    @cg_owned_pet_ids = valid
    return @cg_owned_pet_ids
  end

  def cg_owned_pet_ids
    return cg_rebuild_primary_pet_roster!
  end

  def cg_owned_pets
    result = []
    for actor_id in cg_owned_pet_ids
      pet = $game_actors.cg_pet(actor_id)
      result.push(pet) if pet != nil
    end
    return result
  end

  def cg_primary_pet_pool
    return cg_owned_pets
  end

  def cg_pets_owned_by(owner_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i
    return [] unless owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    return cg_owned_pets
  end

  def cg_register_pet(actor_id, owner_actor_id = nil, fixed_owner = nil)
    pet = $game_actors.cg_pet(actor_id.to_i)
    return false if pet == nil
    @cg_owned_pet_ids = [] if @cg_owned_pet_ids == nil
    @cg_owned_pet_ids.push(pet.id) unless @cg_owned_pet_ids.include?(pet.id)
    pet.cg_assign_owner(ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID, false) if
      pet.respond_to?(:cg_assign_owner)
    return true
  end

  def cg_actual_primary_clone_pet
    @actors = [] if @actors == nil
    for actor_id in @actors
      pet = $game_actors.cg_pet(actor_id)
      return pet if pet != nil
    end
    return nil
  end

  def cg_remove_other_primary_clones(keep_id = nil, notify = true)
    @actors = [] if @actors == nil
    changed = false
    for actor_id in @actors.clone
      pet = $game_actors.cg_pet(actor_id)
      next if pet == nil
      next if keep_id != nil && actor_id == keep_id.to_i
      @actors.delete(actor_id)
      changed = true
    end
    cg_v056_party_changed if changed && notify
    return changed
  end

  def cg_v056_refresh_active_cache
    @cg_active_pet_ids_by_owner = {} if @cg_active_pet_ids_by_owner == nil
    primary = ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    active = cg_actual_primary_clone_pet
    if active == nil
      @cg_active_pet_id = nil
      @cg_active_pet_ids_by_owner.delete(primary)
    else
      @cg_active_pet_id = active.id
      @cg_active_pet_ids_by_owner[primary] = active.id
    end
    return active
  end

  def cg_prepare_party_pet_data
    cg_rebuild_primary_pet_roster!
    cg_sync_fixed_partner_pets!
    cg_v056_refresh_active_cache
    return true
  end

  def cg_active_pet_id(owner_actor_id = nil)
    owner_id = owner_actor_id == nil ? ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID :
      (owner_actor_id.respond_to?(:id) ? owner_actor_id.id : owner_actor_id.to_i)
    if owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
      pet = cg_v056_refresh_active_cache
      return pet == nil ? nil : pet.id
    end
    pet_id = cg_fixed_partner_pet_actor_id(owner_id)
    return nil if pet_id == nil
    cg_sync_fixed_partner_pets!
    return @actors.include?(pet_id) ? pet_id : nil
  end

  def cg_active_pet(owner_actor_id = nil)
    pet_id = cg_active_pet_id(owner_actor_id)
    return nil if pet_id == nil
    clone = $game_actors.cg_pet(pet_id)
    return clone if clone != nil
    return $game_actors[pet_id]
  end

  def cg_active_pet_for(human)
    return nil if human == nil
    if human.id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
      return cg_actual_primary_clone_pet
    end
    pet_id = cg_fixed_partner_pet_actor_id(human.id)
    return nil if pet_id == nil
    cg_sync_fixed_partner_pets!
    return nil unless @actors.include?(pet_id)
    return $game_actors[pet_id]
  end

  def cg_active_pets
    result = []
    primary = cg_actual_primary_clone_pet
    result.push(primary) if primary != nil
    map = cg_v056_fixed_partner_map
    for owner_id in map.keys
      pet = cg_active_pet(owner_id)
      result.push(pet) if pet != nil && !result.include?(pet)
    end
    return result
  end

  def cg_primary_pet_handler?(actor_or_id)
    actor_id = actor_or_id.respond_to?(:id) ? actor_or_id.id : actor_or_id.to_i
    return actor_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
  end

  #--------------------------------------------------------------------------
  # ● F5 地圖整備專用
  #--------------------------------------------------------------------------
  def cg_map_deploy_pet(actor_id)
    cg_prepare_party_pet_data
    pet = $game_actors.cg_pet(actor_id.to_i)
    return false if pet == nil
    return false unless cg_owned_pet_ids.include?(pet.id)
    return false unless pet.exist?
    current = cg_actual_primary_clone_pet
    return true if current != nil && current.id == pet.id

    @actors = [] if @actors == nil
    old_index = current == nil ? nil : @actors.index(current.id)
    cg_remove_other_primary_clones(nil, false)
    if old_index == nil
      human_index = @actors.index(ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID)
      old_index = human_index == nil ? @actors.size : human_index + 1
    end
    inserted = cg_v056_raw_insert_actor(pet.id, old_index, false)
    unless inserted
      cg_v056_refresh_active_cache
      return false
    end
    cg_v056_refresh_active_cache
    cg_v056_party_changed
    return true
  end

  def cg_map_recall_pet
    pet = cg_actual_primary_clone_pet
    return false if pet == nil
    removed = cg_v056_raw_remove_actor(pet.id, false)
    cg_v056_refresh_active_cache
    cg_v056_party_changed if removed
    return removed
  end

  #--------------------------------------------------------------------------
  # ● 戰鬥候補、派出、換寵、收回
  #--------------------------------------------------------------------------
  def cg_battle_reserve_pets(owner_actor_or_id = nil)
    owner_id = owner_actor_or_id == nil ? ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID :
      (owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i)
    return [] unless owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    active = cg_actual_primary_clone_pet
    result = []
    for pet in cg_owned_pets
      next if active != nil && active.id == pet.id
      result.push(pet)
    end
    return result
  end

  def cg_battle_switchable_pet?(actor_id, owner_actor_or_id = nil)
    owner_id = owner_actor_or_id == nil ? ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID :
      (owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i)
    return false unless owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    pet = $game_actors.cg_pet(actor_id.to_i)
    return false if pet == nil
    return false unless cg_owned_pet_ids.include?(pet.id)
    active = cg_actual_primary_clone_pet
    return false if active != nil && active.id == pet.id
    return false unless pet.exist?
    return true
  end

  def cg_battle_switch_pet(actor_id, owner_actor_or_id = nil)
    return false unless cg_battle_switchable_pet?(actor_id, owner_actor_or_id)
    new_pet = $game_actors.cg_pet(actor_id.to_i)
    return false if new_pet == nil
    old_pet = cg_actual_primary_clone_pet

    if old_pet != nil && old_pet.respond_to?(:cg_battle_slot_assigned?) &&
       old_pet.cg_battle_slot_assigned?
      row = old_pet.cg_battle_row
      column = old_pet.cg_battle_column
    else
      empty = cg_first_empty_battle_slot(ALBERT_CG::DEFAULT_PET_ROW,
                                         ALBERT_CG::DEFAULT_PET_COLUMN,
                                         new_pet)
      return false if empty == nil
      row = empty[0]
      column = empty[1]
    end

    @actors = [] if @actors == nil
    insert_index = old_pet == nil ? nil : @actors.index(old_pet.id)
    cg_remove_other_primary_clones(nil, false)
    if insert_index == nil
      human_index = @actors.index(ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID)
      insert_index = human_index == nil ? @actors.size : human_index + 1
    end
    return false unless cg_v056_raw_insert_actor(new_pet.id, insert_index, false)

    new_pet.cg_set_battle_slot(row, column, true)
    new_pet.reset_coordinate if new_pet.respond_to?(:reset_coordinate)
    new_pet.base_position if new_pet.respond_to?(:base_position)
    cg_v056_refresh_active_cache
    cg_v056_party_changed
    return true
  end

  def cg_battle_recall_pet(owner_actor_or_id = nil, expected_pet_id = nil)
    owner_id = owner_actor_or_id == nil ? ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID :
      (owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i)
    return false unless owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    pet = nil
    if expected_pet_id != nil && @actors != nil && @actors.include?(expected_pet_id.to_i)
      pet = $game_actors.cg_pet(expected_pet_id.to_i)
    end
    pet = cg_actual_primary_clone_pet if pet == nil
    return false if pet == nil
    removed = cg_v056_raw_remove_actor(pet.id, false)
    cg_v056_refresh_active_cache
    cg_v056_party_changed if removed
    return removed
  end

  # 地圖與戰鬥使用不同入口，避免 F5 被戰鬥格位規則擋住。
  def cg_deploy_pet(actor_id, owner_actor_id = nil)
    if $game_temp != nil && $game_temp.in_battle
      return cg_battle_switch_pet(actor_id, owner_actor_id)
    end
    return cg_map_deploy_pet(actor_id)
  end

  def cg_recall_pet(owner_actor_id = nil)
    if $game_temp != nil && $game_temp.in_battle
      return cg_battle_recall_pet(owner_actor_id, nil)
    end
    return cg_map_recall_pet
  end

  def cg_repair_active_pet_for_owner!(owner_actor_or_id = nil)
    owner_id = owner_actor_or_id == nil ? ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID :
      (owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i)
    return cg_v056_refresh_active_cache if owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    return cg_active_pet(owner_id)
  end

  def cg_remove_pet_references(actor_id)
    actor_id = actor_id.to_i
    @cg_owned_pet_ids = [] if @cg_owned_pet_ids == nil
    @cg_owned_pet_ids.delete(actor_id)
    cg_v056_raw_remove_actor(actor_id)
    cg_v056_refresh_active_cache
    return true
  end

  def cg_human_members
    result = []
    for member in members
      is_pet = member.respond_to?(:cg_battle_pet?) ? member.cg_battle_pet? :
        (member.respond_to?(:cg_pet?) && member.cg_pet?)
      result.push(member) unless is_pet
    end
    return result
  end
end

class Scene_Battle < Scene_Base
  alias albert_cg_v056_authority_start start
  def start
    $game_party.cg_prepare_party_pet_data if $game_party != nil
    albert_cg_v056_authority_start
  end
end

class Game_Interpreter
  def cg_set_fixed_partner_pet(owner_actor_id, pet_actor_id, deploy = true)
    return $game_party.cg_set_fixed_partner_pet(owner_actor_id, pet_actor_id, deploy)
  end

  def cg_assign_fixed_pet(pet_actor_id, owner_actor_id, deploy = true)
    return $game_party.cg_set_fixed_partner_pet(owner_actor_id, pet_actor_id, deploy)
  end
end
