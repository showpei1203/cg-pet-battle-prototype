# RMVX_SCRIPT_INDEX: 127
# RMVX_SCRIPT_ID: 98941045
# RMVX_SCRIPT_NAME: CG Owner Pet Rules v0.5.10
# RMVX_SOURCE_SHA256: d8098eb67423c35a32b00bb4b6a84d12e0d7178119d65a83aa0329ecc24fc0ba

#==============================================================================
# ** ALBERT CG 主人／寵物配對與戰鬥操作規則
#------------------------------------------------------------------------------
#  版本：v0.5.10
#  引擎：RPG Maker VX／RGSS2
#  前置：CG Pet Clone Core、CG Dual Command Core、CG Battlefield Grid、
#        CG Battle Move Pet Switch、CG Pet Roster Authority
#------------------------------------------------------------------------------
# 【用途】
#  本腳本統一處理「每名人物只能管理自己的寵物」相關規則：
#
#  1. 主角使用 Clone 寵物名冊，可自由收回、派出與更換。
#  2. 隊友使用普通資料庫 Actor 作為固定寵物，不需要 Clone Actor。
#  3. 固定寵物會跟主人一起加入隊伍，並被視為寵物戰鬥者。
#  4. 每名主人只能與自己的寵物交換前後位置。
#  5. 寵物未出戰時，主人只能移到自己同列、另一排的空格。
#  6. 不允許人物自由移到其他欄位，也不能與別人的人物／寵物交換。
#  7. 每名主人都可以收回自己的寵物。
#  8. 同一人物本回合已安排過一次派寵／換寵／收回後，第二個「換寵」
#     指令仍會顯示，但文字改為灰色，按下只播放拒絕音。
#
# 【固定寵物設定】
#  請在 CG Config 設定：
#    FIXED_PARTNER_PET_ACTORS = {2 => 103}
#  代表 Actor 2 的固定寵物是普通資料庫 Actor 103。
#
# 【固定寵物行為】
#  - 主人加入隊伍時，固定寵物預設一起加入。
#  - 主人在戰鬥中收回固定寵物後，不會被 members 刷新偷偷加回。
#  - 重新選擇「換寵」時，只能再次派出同一隻固定寵物。
#  - 固定寵物不會出現在 F5 主角 Clone 名冊。
#
# 【站位規則】
#  - 主人在後排時，自己的寵物預設站同列前排。
#  - 主人在前排時，自己的寵物預設站同列後排。
#  - 有寵物：移動選單只顯示「與自己的寵物交換位置」。
#  - 無寵物：移動選單只顯示同列另一排的空格。
#
# 【腳本位置】
#  請放在「CG Pet Roster Authority」下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_OwnerPetRules"] = true

module ALBERT_CG
  OWNER_PET_RULES_VERSION = "0.5.10"
end

#==============================================================================
# ■ Game_Party
#==============================================================================
class Game_Party < Game_Unit
  #--------------------------------------------------------------------------
  # ● 固定普通 Actor 寵物的出戰旗標
  #--------------------------------------------------------------------------
  def cg_v058_fixed_pet_flags
    @cg_v058_fixed_pet_deployed = {} if @cg_v058_fixed_pet_deployed == nil
    return @cg_v058_fixed_pet_deployed
  end

  def cg_fixed_partner_deployed?(owner_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i
    data = cg_v058_fixed_pet_flags
    unless data.has_key?(owner_id)
      # 第一次看到主人時，預設固定寵物為「出戰」。
      # 舊版用「寵物是否已在 @actors」反推旗標，會形成雞生蛋問題：
      # 寵物尚未加入，所以旗標變 false；旗標 false，又永遠不會加入。
      @actors = [] if @actors == nil
      pet_id = respond_to?(:cg_fixed_partner_pet_actor_id) ?
        cg_fixed_partner_pet_actor_id(owner_id) : nil
      data[owner_id] = pet_id != nil && @actors.include?(owner_id)
    end
    return data[owner_id] == true
  end

  def cg_set_fixed_partner_deployed(owner_actor_or_id, value)
    owner_id = owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i
    cg_v058_fixed_pet_flags[owner_id] = value ? true : false
    return cg_v058_fixed_pet_flags[owner_id]
  end

  #--------------------------------------------------------------------------
  # ● 固定寵物同步
  #  覆寫 v0.5.6 的無條件同步。收回後只有部署旗標重新變成 true 才會加入。
  #--------------------------------------------------------------------------
  def cg_sync_fixed_partner_pets!
    return false if @cg_v0510_syncing_fixed_pets
    @cg_v0510_syncing_fixed_pets = true
    changed = false
    begin
      @actors = [] if @actors == nil

      # 先清除已失效或重複的 Actor ID，避免看不見的舊資料占滿隊伍上限。
      cleaned = []
      for actor_id in @actors
        actor_id = actor_id.to_i
        valid = false
        if $game_actors != nil && $game_actors.respond_to?(:cg_pet) &&
           $game_actors.cg_pet(actor_id) != nil
          valid = true
        elsif $data_actors != nil && $data_actors[actor_id] != nil
          valid = true
        end
        cleaned.push(actor_id) if valid && !cleaned.include?(actor_id)
      end
      if cleaned != @actors
        @actors = cleaned
        changed = true
      end

      map = respond_to?(:cg_v056_fixed_partner_map) ?
        cg_v056_fixed_partner_map : {}
      flags = cg_v058_fixed_pet_flags

      # 舊版可能把「尚未成功加入」錯存成不部署。第一次載入 v0.5.10 時，
      # 只要主人已在隊伍，就把固定寵物恢復為預設出戰；之後玩家主動收回
      # 仍會正常保存 false，不會每次刷新都被強制叫回。
      unless @cg_v0510_fixed_flag_migrated
        for owner_id in map.keys
          owner_id = owner_id.to_i
          flags[owner_id] = true if @actors.include?(owner_id)
        end
        @cg_v0510_fixed_flag_migrated = true
      end

      for owner_id in map.keys
        owner_id = owner_id.to_i
        pet_id = map[owner_id].to_i
        owner_present = @actors.include?(owner_id)
        pet_present = @actors.include?(pet_id)

        # 第一次偵測到這組主人時，預設固定寵物跟隨主人出戰。
        flags[owner_id] = true unless flags.has_key?(owner_id)
        should_deploy = owner_present && flags[owner_id] == true

        if should_deploy && !pet_present
          pet_actor = $game_actors == nil ? nil : $game_actors[pet_id]
          next if pet_actor == nil

          # 直接寫入 @actors，避開舊版多層 add_actor alias 互相覆蓋。
          # 目前原型上限為 4，主角＋主角寵物＋隊友＋固定寵物正好可容納。
          next if @actors.size >= Game_Party::MAX_MEMBERS
          owner_index = @actors.index(owner_id)
          insert_index = owner_index == nil ? @actors.size : owner_index + 1
          @actors.insert(insert_index, pet_id)
          changed = true
        elsif !should_deploy && pet_present
          @actors.delete(pet_id)
          changed = true
        end
      end
    ensure
      @cg_v0510_syncing_fixed_pets = false
    end
    cg_v056_party_changed if changed && respond_to?(:cg_v056_party_changed)
    return changed
  end

  # 主人加入時，固定寵物預設一併出戰。
  alias albert_cg_v058_add_actor add_actor
  def add_actor(actor_id)
    actor_id = actor_id.to_i
    if respond_to?(:cg_fixed_partner_pet_actor_id) &&
       cg_fixed_partner_pet_actor_id(actor_id) != nil
      cg_set_fixed_partner_deployed(actor_id, true)
    end
    result = albert_cg_v058_add_actor(actor_id)
    # 不依賴下層 alias 是否剛好同步成功，最後再以目前 @actors 為準補一次。
    cg_sync_fixed_partner_pets!
    return result
  end

  # 主人離隊時，固定寵物一併離隊。
  alias albert_cg_v058_remove_actor remove_actor
  def remove_actor(actor_id)
    actor_id = actor_id.to_i
    is_owner = respond_to?(:cg_fixed_partner_pet_actor_id) &&
      cg_fixed_partner_pet_actor_id(actor_id) != nil
    cg_set_fixed_partner_deployed(actor_id, false) if is_owner
    result = albert_cg_v058_remove_actor(actor_id)
    cg_sync_fixed_partner_pets!
    return result
  end

  # 動態修改固定寵物配對。
  def cg_set_fixed_partner_pet(owner_actor_id, pet_actor_id, deploy = true)
    owner_id = owner_actor_id.to_i
    pet_id = pet_actor_id.to_i
    return false if owner_id <= 0 || pet_id <= 0 || owner_id == pet_id
    return false if $data_actors == nil
    return false if $data_actors[owner_id] == nil || $data_actors[pet_id] == nil
    @cg_fixed_partner_pet_map = {} if @cg_fixed_partner_pet_map == nil
    old_pet_id = @cg_fixed_partner_pet_map[owner_id]
    if old_pet_id != nil && old_pet_id != pet_id && respond_to?(:cg_v056_raw_remove_actor)
      cg_v056_raw_remove_actor(old_pet_id, false)
    end
    @cg_fixed_partner_pet_map[owner_id] = pet_id
    cg_set_fixed_partner_deployed(owner_id, deploy)
    cg_sync_fixed_partner_pets!
    return true
  end

  #--------------------------------------------------------------------------
  # ● 主人／寵物查詢
  #--------------------------------------------------------------------------
  def cg_owner_pet_manager?(actor_or_id)
    actor_id = actor_or_id.respond_to?(:id) ? actor_or_id.id : actor_or_id.to_i
    return true if actor_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    return false unless respond_to?(:cg_fixed_partner_pet_actor_id)
    return cg_fixed_partner_pet_actor_id(actor_id) != nil
  end

  def cg_actor_by_any_id(actor_id)
    actor_id = actor_id.to_i
    clone = $game_actors.respond_to?(:cg_pet) ? $game_actors.cg_pet(actor_id) : nil
    return clone if clone != nil
    return $game_actors[actor_id]
  end

  alias albert_cg_v058_active_pet_for cg_active_pet_for
  def cg_active_pet_for(human)
    return nil if human == nil
    if human.id != ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID &&
       respond_to?(:cg_fixed_partner_pet_actor_id)
      pet_id = cg_fixed_partner_pet_actor_id(human.id)
      if pet_id != nil
        return nil unless cg_fixed_partner_deployed?(human.id)
        @actors = [] if @actors == nil
        return nil unless @actors.include?(pet_id)
        return $game_actors[pet_id]
      end
    end
    return albert_cg_v058_active_pet_for(human)
  end

  # 指定寵物是否確實屬於該主人。
  def cg_owner_pet_pair?(human, pet)
    return false if human == nil || pet == nil
    if human.id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
      return pet.respond_to?(:cg_pet?) && pet.cg_pet? && cg_owned_pet_ids.include?(pet.id)
    end
    return respond_to?(:cg_fixed_partner_pair?) && cg_fixed_partner_pair?(human, pet)
  end

  #--------------------------------------------------------------------------
  # ● 固定寵物候補、派出與收回
  #--------------------------------------------------------------------------
  alias albert_cg_v058_battle_reserve_pets cg_battle_reserve_pets
  def cg_battle_reserve_pets(owner_actor_or_id = nil)
    owner_id = owner_actor_or_id == nil ? ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID :
      (owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i)
    return albert_cg_v058_battle_reserve_pets(owner_actor_or_id) if
      owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    pet_id = cg_fixed_partner_pet_actor_id(owner_id)
    return [] if pet_id == nil
    return [] if cg_active_pet_for($game_actors[owner_id]) != nil
    pet = $game_actors[pet_id]
    return pet == nil ? [] : [pet]
  end

  alias albert_cg_v058_battle_switchable_pet cg_battle_switchable_pet?
  def cg_battle_switchable_pet?(actor_id, owner_actor_or_id = nil)
    owner_id = owner_actor_or_id == nil ? ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID :
      (owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i)
    return albert_cg_v058_battle_switchable_pet(actor_id, owner_actor_or_id) if
      owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    pet_id = cg_fixed_partner_pet_actor_id(owner_id)
    return false if pet_id == nil || pet_id != actor_id.to_i
    @actors = [] if @actors == nil
    return false unless @actors.include?(owner_id)
    return false if @actors.include?(pet_id)
    pet = $game_actors[pet_id]
    return pet != nil && pet.exist?
  end

  alias albert_cg_v058_battle_switch_pet cg_battle_switch_pet
  def cg_battle_switch_pet(actor_id, owner_actor_or_id = nil)
    owner_id = owner_actor_or_id == nil ? ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID :
      (owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i)
    return albert_cg_v058_battle_switch_pet(actor_id, owner_actor_or_id) if
      owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    return false unless cg_battle_switchable_pet?(actor_id, owner_id)
    owner = $game_actors[owner_id]
    pet = $game_actors[actor_id.to_i]
    return false if owner == nil || pet == nil
    return false unless owner.cg_battle_slot_assigned?
    row = owner.cg_front_row? ? :back : :front
    column = owner.cg_battle_column
    return false if cg_slot_occupied_by_other?(row, column, pet, false)
    cg_set_fixed_partner_deployed(owner_id, true)
    cg_sync_fixed_partner_pets!
    @actors = [] if @actors == nil
    unless @actors.include?(pet.id)
      cg_set_fixed_partner_deployed(owner_id, false)
      return false
    end
    pet.cg_set_battle_slot(row, column, true)
    pet.reset_coordinate if pet.respond_to?(:reset_coordinate)
    pet.base_position if pet.respond_to?(:base_position)
    cg_v056_party_changed if respond_to?(:cg_v056_party_changed)
    return true
  end

  alias albert_cg_v058_battle_recall_pet cg_battle_recall_pet
  def cg_battle_recall_pet(owner_actor_or_id = nil, expected_pet_id = nil)
    owner_id = owner_actor_or_id == nil ? ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID :
      (owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i)
    return albert_cg_v058_battle_recall_pet(owner_actor_or_id, expected_pet_id) if
      owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    pet_id = cg_fixed_partner_pet_actor_id(owner_id)
    return false if pet_id == nil
    return false if expected_pet_id != nil && expected_pet_id.to_i != pet_id
    @actors = [] if @actors == nil
    return false unless @actors.include?(pet_id)
    cg_set_fixed_partner_deployed(owner_id, false)
    removed = respond_to?(:cg_v056_raw_remove_actor) ?
      cg_v056_raw_remove_actor(pet_id, false) : false
    cg_v056_party_changed if removed && respond_to?(:cg_v056_party_changed)
    return removed
  end

  # 目前是否存在至少一項可執行的寵物管理操作。
  def cg_owner_pet_management_available?(owner_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i
    return false unless cg_owner_pet_manager?(owner_id)
    owner = $game_actors[owner_id]
    return false if owner == nil

    # 主角只要名冊中至少有一隻 Clone，就保留「換寵」指令。
    # 是否可派出、是否戰鬥不能，交給下一層換寵名單逐項判定。
    # 這可避免畫面上明明有出戰寵物，卻因快取不同步把整個指令變灰。
    if owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
      pets = respond_to?(:cg_owned_pets) ? cg_owned_pets : []
      return pets != nil && !pets.empty?
    end

    # 隊友只要有設定固定寵物，就可以收回或重新派出該寵物。
    pet_id = respond_to?(:cg_fixed_partner_pet_actor_id) ?
      cg_fixed_partner_pet_actor_id(owner_id) : nil
    return false if pet_id == nil
    return false if $data_actors == nil || $data_actors[pet_id] == nil
    return true
  end

  #--------------------------------------------------------------------------
  # ● 預設站位：寵物固定在主人同列的另一排
  #--------------------------------------------------------------------------
  alias albert_cg_v058_assign_default_slots cg_assign_default_battle_slots
  def cg_assign_default_battle_slots
    result = albert_cg_v058_assign_default_slots
    humans = respond_to?(:cg_human_members) ? cg_human_members : []
    for human in humans
      pet = cg_active_pet_for(human)
      next if pet == nil
      next unless members.include?(pet)
      next unless human.cg_battle_slot_assigned?
      next if pet.respond_to?(:cg_battle_slot_manual?) && pet.cg_battle_slot_manual?
      row = human.cg_front_row? ? :back : :front
      column = human.cg_battle_column
      unless cg_slot_occupied_by_other?(row, column, pet, false)
        pet.cg_set_default_battle_slot(row, column)
      end
    end
    return result
  end
end

#==============================================================================
# ■ Window_ActorCommand
#==============================================================================
class Window_ActorCommand < Window_Command
  alias albert_cg_v058_actor_command_setup setup
  def setup(actor)
    @cg_v058_enabled = {}
    albert_cg_v058_actor_command_setup(actor)
    is_pet = actor != nil && actor.respond_to?(:cg_battle_pet?) && actor.cg_battle_pet?
    if actor != nil && !is_pet && $game_party != nil &&
       $game_party.respond_to?(:cg_owner_pet_manager?) &&
       $game_party.cg_owner_pet_manager?(actor)
      unless @cg_command_types != nil && @cg_command_types.include?(:switch_pet)
        @commands.push("換寵")
        @cg_command_types.push(:switch_pet)
        @item_max = @commands.size
        create_contents
        self.top_row = 0 if respond_to?(:top_row=)
      end
    end
    refresh
    self.index = 0 if self.index == nil || self.index < 0
  end

  def cg_set_command_enabled(command_type, enabled)
    @cg_v058_enabled = {} if @cg_v058_enabled == nil
    @cg_v058_enabled[command_type] = enabled ? true : false
    refresh
  end

  def cg_command_enabled?(index = nil)
    index = self.index if index == nil
    return true if @cg_command_types == nil
    type = @cg_command_types[index]
    @cg_v058_enabled = {} if @cg_v058_enabled == nil
    return true unless @cg_v058_enabled.has_key?(type)
    return @cg_v058_enabled[type] == true
  end

  # 不可使用的指令改用指定色票，不只降低透明度。
  def refresh
    return if self.contents == nil
    self.contents.clear
    return if @commands == nil
    for i in 0...@item_max
      rect = item_rect(i)
      rect.x += 4
      rect.width -= 8
      enabled = cg_command_enabled?(i)
      if enabled
        self.contents.font.color = normal_color
      else
        index = defined?(ALBERT_CG::DISABLED_COMMAND_COLOR_INDEX) ?
          ALBERT_CG::DISABLED_COMMAND_COLOR_INDEX : 7
        self.contents.font.color = text_color(index)
      end
      self.contents.font.color.alpha = 255
      self.contents.draw_text(rect, @commands[i])
    end
  end
end

#==============================================================================
# ■ Scene_Battle
#==============================================================================
class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # ● 只檢查「目前欄位之前」同一人物已保存的寵物管理行動
  #--------------------------------------------------------------------------
  # 第一個人物指令欄位永遠不應因為尚未輸入的空 Action 而被判定為重複。
  # 多人戰鬥時，也只檢查同一人物，不會被其他人物的換寵指令影響。
  def cg_pet_management_already_planned?(battler)
    return false if battler == nil
    return false if @cg_input_slots == nil || @cg_input_slot_index == nil
    current = @cg_input_slot_index.to_i
    return false if current <= 0
    for i in 0...current
      slot = @cg_input_slots[i]
      next if slot == nil || slot.battler != battler
      return true if cg_pet_management_action?(slot.action)
    end
    return false
  end

  # 戰鬥建立人物／寵物指令欄位前，再強制同步一次固定寵物。
  # 即使事件加入人物時漏過某段舊 alias，這裡仍會補齊普通 Actor 固定寵物。
  alias albert_cg_v059_build_input_slots cg_build_input_slots
  def cg_build_input_slots
    $game_party.cg_sync_fixed_partner_pets! if $game_party != nil &&
      $game_party.respond_to?(:cg_sync_fixed_partner_pets!)
    return albert_cg_v059_build_input_slots
  end

  # 更新「換寵」指令是否可用。只在已有較早的寵物管理指令時變灰。
  def cg_v058_refresh_switch_command
    return if @actor_command_window == nil || @active_battler == nil
    return unless @actor_command_window.respond_to?(:cg_set_command_enabled)

    # 第一個人物行動只要是寵物主人，「換寵」就必定可選。
    # 是否真的有候補、是否戰鬥不能，交由換寵名單逐項判定。
    # 只有同一人物較早的行動已安排過寵物管理時，才將本指令改成灰色。
    owner = $game_party != nil &&
      $game_party.respond_to?(:cg_owner_pet_manager?) &&
      $game_party.cg_owner_pet_manager?(@active_battler)
    planned = respond_to?(:cg_pet_management_already_planned?) ?
      cg_pet_management_already_planned?(@active_battler) : false
    @actor_command_window.cg_set_command_enabled(:switch_pet,
      owner && !planned)
  end

  alias albert_cg_v058_start_actor_command_selection start_actor_command_selection
  def start_actor_command_selection
    albert_cg_v058_start_actor_command_selection
    cg_v058_refresh_switch_command
  end

  alias albert_cg_v058_restore_command cg_restore_actor_command_after_popup
  def cg_restore_actor_command_after_popup
    albert_cg_v058_restore_command
    cg_v058_refresh_switch_command
  end

  alias albert_cg_v058_update_actor_command update_actor_command_selection
  def update_actor_command_selection
    if Input.trigger?(Input::C) && @actor_command_window != nil &&
       @actor_command_window.respond_to?(:cg_command_type) &&
       @actor_command_window.cg_command_type == :switch_pet &&
       @actor_command_window.respond_to?(:cg_command_enabled?) &&
       !@actor_command_window.cg_command_enabled?
      Sound.play_buzzer
      return
    end
    albert_cg_v058_update_actor_command
  end

  # 每名主人只能交換自己的寵物；沒有寵物時只能移到同列另一排。
  def cg_move_entries
    entries = []
    human = @active_battler
    return entries if human == nil
    return entries unless $game_party.cg_owner_pet_manager?(human)
    pet = $game_party.cg_active_pet_for(human)
    if pet != nil && $game_party.members.include?(pet)
      if human.exist? && pet.exist?
        entries.push({:type => :swap_pet,
          :text => "與自己的寵物交換位置"})
      end
      return entries
    end
    return entries unless human.cg_battle_slot_assigned?
    row = human.cg_front_row? ? :back : :front
    column = human.cg_battle_column
    unless $game_party.cg_slot_occupied_by_other?(row, column, human, false)
      entries.push({:type => :move,
        :text => "移至自己的寵物空位「" + ALBERT_CG.cg_slot_text(row, column) + "」",
        :row => row, :column => column})
    end
    return entries
  end

  # 主角顯示 Clone 候補；隊友只顯示自己的固定普通 Actor 寵物。
  def cg_pet_switch_entries
    entries = []
    owner = @active_battler
    active_pet = $game_party.cg_active_pet_for(owner)
    if active_pet != nil
      entries.push({:type => :recall, :pet_id => active_pet.id,
        :text => "收回自己的寵物", :enabled => true})
    end
    for pet in $game_party.cg_battle_reserve_pets(owner)
      enabled = pet != nil && pet.exist?
      prefix = active_pet == nil ? "派出 " : "換上 "
      text = prefix + pet.name.to_s + "  Lv." + pet.level.to_s
      text += "（戰鬥不能）" unless enabled
      entries.push({:type => :switch, :pet_id => pet.id,
        :text => text, :enabled => enabled})
    end
    entries.push({:type => :cancel, :pet_id => 0,
      :text => "取消", :enabled => true})
    return entries
  end

  # 已安排過寵物管理時，不顯示說明，只播放拒絕音。
  def cg_start_pet_switch_command
    if cg_pet_management_already_planned?(@active_battler)
      Sound.play_buzzer
      cg_restore_actor_command_after_popup
      return
    end
    unless $game_party.cg_owner_pet_manager?(@active_battler)
      Sound.play_buzzer
      cg_restore_actor_command_after_popup
      return
    end
    entries = cg_pet_switch_entries
    window = Window_CG_BattlePetSwitch.new(entries)
    index = cg_run_battle_popup(window, "選擇要收回或派出的寵物")
    if index < 0
      cg_restore_actor_command_after_popup
      return
    end
    entry = entries[index]
    if entry == nil || entry[:type] == :cancel
      Sound.play_cancel
      cg_restore_actor_command_after_popup
      return
    end
    unless entry[:enabled]
      Sound.play_buzzer
      cg_restore_actor_command_after_popup
      return
    end
    if entry[:type] == :recall
      @active_battler.action.cg_set_recall_pet(entry[:pet_id])
    else
      @active_battler.action.cg_set_switch_pet(entry[:pet_id])
    end
    Sound.play_decision
    next_actor
  end

  # 固定普通 Actor 寵物不能用 cg_pet 查找，因此使用通用解析。
  def cg_execute_swap_pet
    pet = $game_party.cg_actor_by_any_id(@active_battler.action.cg_swap_pet_id)
    if $game_party.cg_owner_pet_pair?(@active_battler, pet) &&
       $game_party.cg_swap_human_and_pet_slots(@active_battler, pet, true)
      cg_play_slot_move_sequence([@active_battler, pet])
      text = @active_battler.name.to_s + "與" + pet.name.to_s + "交換位置。"
    else
      text = "交換位置失敗：只能與自己的寵物交換。"
    end
    cg_show_special_action_text(text)
  end

  def cg_execute_switch_pet
    owner = @active_battler
    return if cg_pet_management_executed_for?(owner)
    pet_id = owner.action.cg_switch_pet_id
    old_pet = $game_party.cg_active_pet_for(owner)
    new_pet = $game_party.cg_actor_by_any_id(pet_id)
    old_name = old_pet == nil ? "" : old_pet.name.to_s
    new_name = new_pet == nil ? "寵物" : new_pet.name.to_s
    cg_play_pet_switch_animation(old_pet, ALBERT_CG::PET_RECALL_ANIMATION_ID) if old_pet != nil
    if $game_party.cg_battle_switch_pet(pet_id, owner)
      cg_mark_pet_management_executed(owner)
      cg_refresh_party_after_switch
      cg_play_pet_switch_animation(new_pet, ALBERT_CG::PET_SUMMON_ANIMATION_ID)
      text = old_pet == nil ? owner.name.to_s + "派出" + new_name + "。" :
        owner.name.to_s + "收回" + old_name + "，派出" + new_name + "。"
    else
      text = owner.name.to_s + "無法派出自己的寵物。"
    end
    cg_show_special_action_text(text)
  end

  def cg_execute_recall_pet
    owner = @active_battler
    return if cg_pet_management_executed_for?(owner)
    expected_id = owner.action.cg_recall_pet_id
    pet = expected_id == nil ? $game_party.cg_active_pet_for(owner) :
      $game_party.cg_actor_by_any_id(expected_id)
    can_animate = pet != nil && $game_party.members.include?(pet)
    cg_play_pet_switch_animation(pet, ALBERT_CG::PET_RECALL_ANIMATION_ID) if can_animate
    if $game_party.cg_battle_recall_pet(owner, expected_id)
      cg_mark_pet_management_executed(owner)
      cg_refresh_party_after_switch
      cg_show_special_action_text(owner.name.to_s + "收回" +
        (pet == nil ? "寵物" : pet.name.to_s) + "。")
    else
      cg_show_special_action_text(owner.name.to_s + "無法收回自己的寵物。")
    end
  end
end

#==============================================================================
# ■ Game_Interpreter
#------------------------------------------------------------------------------
#  VX 的「變更隊伍成員」事件指令會進入 command_129。
#  事件加入固定寵物主人後，這裡再強制同步一次，避免舊版 add_actor alias
#  鏈互相覆蓋，導致主人加入但普通 Actor 固定寵物沒有跟著加入。
#==============================================================================
class Game_Interpreter
  alias albert_cg_v0510_command_129 command_129
  def command_129
    result = albert_cg_v0510_command_129
    if $game_party != nil && $game_party.respond_to?(:cg_sync_fixed_partner_pets!)
      $game_party.cg_sync_fixed_partner_pets!
    end
    return result
  end
end
