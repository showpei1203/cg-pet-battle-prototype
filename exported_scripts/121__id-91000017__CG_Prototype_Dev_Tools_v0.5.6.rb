# RMVX_SCRIPT_INDEX: 121
# RMVX_SCRIPT_ID: 91000017
# RMVX_SCRIPT_NAME: CG Prototype Dev Tools v0.5.6
# RMVX_SOURCE_SHA256: f64f34056fa6e2e707d908138b852adf00018100df733b34281faeb8eed899cf

#==============================================================================
# ** ALBERT CG 原型專案測試工具
#------------------------------------------------------------------------------
#  版本：v0.5.6
#------------------------------------------------------------------------------
# 【用途】
#  新遊戲自動建立三隻測試寵物，並提供地圖快捷鍵與資料自動檢查。
#
# 【地圖快捷鍵】
#  F5：開啟寵物名冊
#  F6：進入人物＋寵物測試戰
#  F7：補齊測試寵物並重新派出妙蛙種子
#  F8：收回寵物並測試人物兩次行動
#  F9：將目前前後排與三列位置輸出到測試主控台
#
# 【事件腳本】
#  ALBERT_CG.bootstrap_demo_party
#  ALBERT_CG.start_demo_battle
#  $scene = Scene_CG_PetLab.new
#==============================================================================

module ALBERT_CG
  def self.create_demo_pet(species_id, level, custom_name = nil, owner_actor_id = ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID)
    $game_party.cg_normalize_pet_owners! if $game_party.respond_to?(:cg_normalize_pet_owners!)
    owned = $game_party.respond_to?(:cg_pets_owned_by) ?
      $game_party.cg_pets_owned_by(owner_actor_id) : $game_party.cg_owned_pets
    for pet in owned
      return pet if pet.cg_species_id == species_id
    end
    pet = $game_actors.cg_create_pet(species_id, level, custom_name, owner_actor_id)
    return nil if pet == nil
    $game_party.cg_register_pet(pet.id, owner_actor_id)
    return pet
  end

  def self.bootstrap_demo_party
    $game_party.cg_normalize_pet_owners! if $game_party.respond_to?(:cg_normalize_pet_owners!)
    pet_a = create_demo_pet(100, 5, "妙蛙種子A")
    create_demo_pet(103, 5, "小火龍A")
    create_demo_pet(106, 5, "傑尼龜A")
    $game_party.cg_deploy_pet(pet_a.id, ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID) if pet_a != nil and $game_party.cg_active_pet == nil
    $game_player.refresh if $game_player != nil
    return $game_party.cg_owned_pet_ids
  end

  def self.start_demo_battle(troop_id = ALBERT_CG::DEMO_TROOP_ID)
    return false if $game_temp.in_battle
    return false if $data_troops[troop_id] == nil
    $game_troop.setup(troop_id)
    $game_troop.can_escape = true
    $game_troop.can_lose = true
    $game_temp.battle_proc = Proc.new { |result| }
    $game_temp.next_scene = "battle"
    return true
  end


  # Starts the mixed test battle after placing the lead human in the front row.
  # Useful for verifying CG-style melee reach from front to enemy back row.
  def self.start_front_human_demo_battle(troop_id = ALBERT_CG::DEMO_TROOP_ID)
    human = $game_party.respond_to?(:cg_human_members) ?
      $game_party.cg_human_members[0] : $game_party.members[0]
    human.cg_set_battle_slot(:front, 1, true) if human != nil
    return start_demo_battle(troop_id)
  end

  def self.start_no_pet_demo_battle(troop_id = ALBERT_CG::DEMO_TROOP_ID)
    $game_party.cg_recall_pet if $game_party.respond_to?(:cg_recall_pet)
    return start_demo_battle(troop_id)
  end


  def self.print_battlefield_slots
    lines = ["CG Battlefield Slots"]
    if $game_party != nil
      $game_party.cg_assign_default_battle_slots if $game_party.respond_to?(:cg_assign_default_battle_slots)
      for member in $game_party.members
        label = member.respond_to?(:cg_grid_label) ? member.cg_grid_label : "?"
        lines.push("ALLY  " + member.name.to_s + " : " + label.to_s)
      end
    end
    if $game_troop != nil
      for enemy in $game_troop.members
        label = enemy.respond_to?(:cg_grid_label) ? enemy.cg_grid_label : "?"
        lines.push("ENEMY " + enemy.name.to_s + " : " + label.to_s)
      end
    end
    p lines.join("\n") if ALBERT_CG::DEBUG_MESSAGE
    return lines
  end

  def self.run_dual_action_data_test(model_actor_id = 1)
    actor = $game_actors[model_actor_id]
    raise "CG TEST: actor not found" if actor == nil
    first = Game_BattleAction.new(actor)
    first.set_attack
    first.target_index = 0
    second = Game_BattleAction.new(actor)
    second.set_guard
    actor.cg_round_actions = [first.cg_copy_for(actor), second.cg_copy_for(actor)]
    raise "CG TEST: round action count" unless actor.cg_round_actions.size == 2
    raise "CG TEST: first action damaged" unless actor.cg_round_actions[0].attack?
    raise "CG TEST: second action damaged" unless actor.cg_round_actions[1].guard?
    p "CG Dual Action Data Test OK" if ALBERT_CG::DEBUG_MESSAGE
    return true
  end

  def self.run_skill_progress_storage_test
    human = $game_actors[1]
    raise "CG TEST: human actor not found" if human == nil
    before = human.cg_skill_exp_for(600)
    after = human.cg_gain_skill_exp(600, 1)
    raise "CG TEST: human skill EXP storage failed" unless after == before + 1
    pet = $game_party.cg_active_pet
    if pet != nil
      pet_before = pet.cg_skill_exp_for(600)
      pet_after = pet.cg_gain_skill_exp(600, 1)
      raise "CG TEST: pet skill EXP storage failed" unless pet_after == pet_before + 1
    end
    p "CG Skill Progress Storage Test OK" if ALBERT_CG::DEBUG_MESSAGE
    return true
  end

  def self.run_clone_smoke_test(model_actor_id = 100)
    pet_a = $game_actors.cg_create_pet(model_actor_id, 5, "Clone A")
    pet_b = $game_actors.cg_create_pet(model_actor_id, 8, "Clone B")
    raise "CG TEST: failed to create pet A" if pet_a == nil
    raise "CG TEST: failed to create pet B" if pet_b == nil
    raise "CG TEST: clone IDs are not unique" if pet_a.id == pet_b.id
    raise "CG TEST: model IDs do not match" if pet_a.cg_species_id != model_actor_id
    raise "CG TEST: model IDs do not match" if pet_b.cg_species_id != model_actor_id
    raise "CG TEST: levels are not independent" if pet_a.level == pet_b.level
    raise "CG TEST: names are not independent" if pet_a.name == pet_b.name
    result = "CG Clone Test OK\n"
    result += "A ID: " + pet_a.id.to_s + " Lv." + pet_a.level.to_s + "\n"
    result += "B ID: " + pet_b.id.to_s + " Lv." + pet_b.level.to_s
    p result if ALBERT_CG::DEBUG_MESSAGE
    return [pet_a.id, pet_b.id]
  end
  # v0.5：檢查戰鬥換寵候選與位置資料，不會直接進入戰鬥。
  def self.run_battle_switch_data_test
    bootstrap_demo_party
    active = $game_party.cg_active_pet
    raise "CG TEST：找不到出戰寵物" if active == nil
    owner = $game_actors[ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID]
    reserves = $game_party.cg_battle_reserve_pets(owner)
    raise "CG TEST：找不到候補寵物" if reserves.empty?
    candidate = nil
    for pet in reserves
      if pet.exist?
        candidate = pet
        break
      end
    end
    raise "CG TEST：沒有可派出的候補寵物" if candidate == nil
    raise "CG TEST：候補判定錯誤" unless $game_party.cg_battle_switchable_pet?(candidate.id, owner)
    p "CG v0.5 換寵資料測試通過" if ALBERT_CG::DEBUG_MESSAGE
    return true
  end

  # v0.5.4：建立「隊友＋固定普通 Actor 寵物」測試組合。
  # 事件腳本：ALBERT_CG.setup_teammate_pet_demo(2, 103)
  def self.setup_teammate_pet_demo(teammate_actor_id = 2, pet_actor_id = 103)
    human = $game_actors[teammate_actor_id]
    pet = $game_actors[pet_actor_id]
    return 0 if human == nil or pet == nil
    $game_party.cg_set_fixed_partner_pet(teammate_actor_id, pet_actor_id, false)
    $game_party.add_actor(teammate_actor_id)
    $game_party.cg_sync_fixed_partner_pet(teammate_actor_id)
    $game_party.cg_assign_default_battle_slots if $game_party.respond_to?(:cg_assign_default_battle_slots)
    $game_player.refresh if $game_player != nil
    return pet_actor_id
  end

  # v0.5.1：檢查主人綁定，不會更動戰鬥。
  def self.run_pet_owner_data_test
    bootstrap_demo_party
    owner = $game_actors[ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID]
    raise "CG TEST：找不到主角" if owner == nil
    for pet in $game_party.cg_owned_pets
      raise "CG TEST：測試寵物主人錯誤" unless pet.cg_owner_actor_id == owner.id
    end
    active = $game_party.cg_active_pet_for(owner)
    raise "CG TEST：主人無法取得自己的出戰寵物" if active == nil
    p "CG v0.5.1 主人綁定資料測試通過" if ALBERT_CG::DEBUG_MESSAGE
    return true
  end


# v0.5.4：保留舊存檔主角 Clone 名冊修復測試。
  # v0.5.2：修復舊版測試寵物主人資料，並檢查三隻寵物都能出現在主角候補名單。
  def self.run_legacy_pet_owner_repair_test
    bootstrap_demo_party
    owner_id = ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    $game_party.cg_normalize_pet_owners!
    pets = $game_party.cg_pets_owned_by(owner_id)
    species = pets.collect { |pet| pet.cg_species_id }
    for required_id in DEMO_ACTOR_IDS
      raise "CG TEST：修復後缺少主角測試寵物" unless species.include?(required_id)
    end
    p "CG v0.5.2 舊寵物主人修復測試通過" if ALBERT_CG::DEBUG_MESSAGE
    return true
  end

  # v0.5.4：檢查主角三隻 Clone 寵物在有／無出戰寵物時的候補數量。
  def self.run_v053_pet_pool_test
    bootstrap_demo_party
    owner = $game_actors[ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID]
    raise "CG TEST：找不到主角" if owner == nil
    active = $game_party.cg_active_pet_for(owner)
    reserves = $game_party.cg_battle_reserve_pets(owner)
    raise "CG TEST：有寵物時候補應為 2" unless active != nil && reserves.size == 2
    $game_party.cg_battle_recall_pet(owner, active.id)
    reserves = $game_party.cg_battle_reserve_pets(owner)
    raise "CG TEST：無寵物時候補應為 3" unless reserves.size == 3
    $game_party.cg_deploy_pet(reserves[0].id, owner.id)
    p "CG v0.5.4 主角 Clone 自由名冊測試通過" if ALBERT_CG::DEBUG_MESSAGE
    return true
  end

  # v0.5.4：檢查主角 Clone 名冊與隊友固定普通 Actor 寵物。
  def self.run_v054_pet_architecture_test(teammate_actor_id = 2, pet_actor_id = 103)
    bootstrap_demo_party
    owner = $game_actors[ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID]
    active = $game_party.cg_active_pet_for(owner)
    reserves = $game_party.cg_battle_reserve_pets(owner)
    raise "CG TEST：主角有寵物時候補應至少為 2" unless active != nil && reserves.size >= 2
    raise "CG TEST：主角候補混入非 Clone" if reserves.any? { |pet| !pet.cg_pet? }
    $game_party.add_actor(teammate_actor_id)
    $game_party.cg_set_fixed_partner_pet(teammate_actor_id, pet_actor_id, true)
    fixed = $game_party.cg_active_pet_for($game_actors[teammate_actor_id])
    raise "CG TEST：隊友固定普通 Actor 寵物未出戰" if fixed == nil || fixed.id != pet_actor_id
    raise "CG TEST：固定寵物被誤判為 Clone" if fixed.respond_to?(:cg_pet?) && fixed.cg_pet?
    raise "CG TEST：固定寵物未被判定為戰鬥寵物" unless fixed.cg_battle_pet?
    p "CG v0.5.4 寵物架構測試通過" if ALBERT_CG::DEBUG_MESSAGE
    return true
  end

  # v0.5.6：檢查 F5 地圖整備與隊友固定寵物同步。
  def self.run_v056_deployment_sync_test
    bootstrap_demo_party
    pets = $game_party.cg_owned_pets
    raise "CG TEST：主角測試寵物不足三隻" unless pets.size >= 3
    for pet in pets
      raise "CG TEST：F5 設為出戰失敗 ID #{pet.id}" unless $game_party.cg_map_deploy_pet(pet.id)
      active = $game_party.cg_actual_primary_clone_pet
      raise "CG TEST：F5 出戰個體不同步" if active == nil || active.id != pet.id
    end
    raise "CG TEST：F5 收回失敗" unless $game_party.cg_map_recall_pet
    raise "CG TEST：F5 收回後仍有出戰 Clone" unless $game_party.cg_actual_primary_clone_pet == nil

    $game_party.add_actor(2)
    ids = $game_party.cg_raw_actor_ids
    raise "CG TEST：Actor 2 未加入" unless ids.include?(2)
    raise "CG TEST：Actor 2 固定寵物 103 未同步" unless ids.include?(103)
    p "CG v0.5.6 地圖出戰／固定寵物同步測試通過" if ALBERT_CG::DEBUG_MESSAGE
    return true
  end

end

class Scene_Title < Scene_Base
  alias albert_cg_v02_command_new_game command_new_game
  def command_new_game
    albert_cg_v02_command_new_game
    ALBERT_CG.bootstrap_demo_party if ALBERT_CG::AUTO_BOOTSTRAP_DEMO
  end
end

class Scene_Map < Scene_Base
  alias albert_cg_v02_scene_map_update update
  def update
    albert_cg_v02_scene_map_update
    return unless $scene == self
    if Input.trigger?(Input::F5)
      Sound.play_decision
      snapshot_for_background
      $scene = Scene_CG_PetLab.new
    elsif Input.trigger?(Input::F6)
      Sound.play_decision if ALBERT_CG.start_demo_battle
    elsif Input.trigger?(Input::F7)
      ALBERT_CG.bootstrap_demo_party
      Sound.play_decision
    elsif Input.trigger?(Input::F8)
      Sound.play_decision if ALBERT_CG.start_no_pet_demo_battle
    elsif Input.trigger?(Input::F9)
      ALBERT_CG.print_battlefield_slots
      Sound.play_decision
    end
  end
end

class Game_Interpreter
  def cg_open_pet_lab
    $scene.snapshot_for_background if $scene.respond_to?(:snapshot_for_background)
    $scene = Scene_CG_PetLab.new
  end

  def cg_demo_battle(troop_id = ALBERT_CG::DEMO_TROOP_ID)
    return ALBERT_CG.start_demo_battle(troop_id)
  end

  def cg_create_demo_pets
    return ALBERT_CG.bootstrap_demo_party
  end


  def cg_front_human_demo_battle(troop_id = ALBERT_CG::DEMO_TROOP_ID)
    return ALBERT_CG.start_front_human_demo_battle(troop_id)
  end
  def cg_no_pet_demo_battle(troop_id = ALBERT_CG::DEMO_TROOP_ID)
    return ALBERT_CG.start_no_pet_demo_battle(troop_id)
  end
end
