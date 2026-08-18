# RMVX_SCRIPT_INDEX: 165
# RMVX_SCRIPT_ID: 98941070
# RMVX_SCRIPT_NAME: CG Solo Trainer System v1.9.0
# RMVX_SOURCE_SHA256: c63f1b0d0aae395067aa333d3c7fe0a552bd0ee1e7aa2a178e280a2e19f54255

#==============================================================================
# ■ CG Solo Trainer System v1.9.0
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【正式隊伍結構】
#   主角 1 名＋可自由替換的 Clone 寵物 3 隻。
#   不再使用隊友，也不再使用隊友固定寵物。
#
# 【戰鬥規則】
#   1. 主角取得 1 次行動。
#   2. 每隻仍在場且可行動的攜帶寵物各取得 1 次行動。
#   3. 寵物欄空缺或寵物戰鬥不能時，該欄改由主角取得額外行動。
#   4. 寵物仍存活但因狀態無法行動時，不補主角行動。
#   5. 三隻攜帶寵物全部直接參戰，因此移除戰鬥中的「換寵」指令。
#
# 【寵物管理】
#   左上：3 個攜帶欄。
#   左下：倉庫名冊。
#   右側：目前寵物詳細資料。
#   選取寵物後可進入能力配點、技能資料、替換、放生等子選單。
#
# 【放置位置】
#   所有 CG 腳本下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_SoloTrainer_1_9_0"] = true

module ALBERT_CG
  SOLO_TRAINER_VERSION = "1.9.0"
  SOLO_HUMAN_ACTOR_ID = 1
  SOLO_PET_SLOTS = 3
  SOLO_PARTY_LIMIT = 4

  # 重新定義舊的隊伍與寵物容量常數。
  [:PARTY_MEMBER_LIMIT, :MAX_ACTIVE_PETS_PER_OWNER, :MAX_ACTIVE_PETS,
   :PET_CARRY_LIMIT].each do |name|
    remove_const(name) if const_defined?(name)
  end
  PARTY_MEMBER_LIMIT = SOLO_PARTY_LIMIT
  MAX_ACTIVE_PETS_PER_OWNER = SOLO_PET_SLOTS
  MAX_ACTIVE_PETS = SOLO_PET_SLOTS
  PET_CARRY_LIMIT = SOLO_PET_SLOTS

  # 隊友固定寵物正式停用。
  remove_const(:FIXED_PARTNER_PET_ACTORS) if const_defined?(:FIXED_PARTNER_PET_ACTORS)
  FIXED_PARTNER_PET_ACTORS = {}

  def self.apply_solo_party_limits
    begin
      Game_Party.send(:remove_const, :MAX_MEMBERS) if
        Game_Party.const_defined?(:MAX_MEMBERS)
      Game_Party.const_set(:MAX_MEMBERS, SOLO_PARTY_LIMIT)
    rescue
    end
    begin
      if defined?(N01)
        N01.send(:remove_const, :MAX_MEMBER) if N01.const_defined?(:MAX_MEMBER)
        N01.const_set(:MAX_MEMBER, SOLO_PARTY_LIMIT)
      end
    rescue
    end
  end

  def self.solo_pet?(actor)
    return false if actor == nil
    return actor.respond_to?(:cg_pet?) && actor.cg_pet?
  rescue
    return false
  end

  def self.apply_solo_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.9.0"
  end

  module SoloBattleStatus
    STATUS_Y = 260
    STATUS_HEIGHT = 156
    HERO_WIDTH = 164
    BLOCK_GAP = 4
    PET_BLOCK_X = HERO_WIDTH + BLOCK_GAP
    PET_BLOCK_WIDTH = 512 - PET_BLOCK_X
    PET_GAP = 3
    PET_CARD_WIDTH = (PET_BLOCK_WIDTH - PET_GAP * 2) / 3

    PANEL_EDGE = Color.new(94, 178, 220, 225)
    PANEL_START = Color.new(17, 47, 63, 230)
    PANEL_END = Color.new(8, 19, 27, 115)
    PET_EDGE = Color.new(102, 185, 130, 220)
    PET_START = Color.new(20, 54, 40, 225)
    PET_END = Color.new(9, 24, 19, 105)
    EMPTY_START = Color.new(36, 45, 50, 170)
    EMPTY_END = Color.new(15, 20, 24, 75)
    GOLD = Color.new(255, 218, 72, 255)
    GOLD_LIGHT = Color.new(255, 248, 170, 255)
    CIRCLE_INNER = Color.new(15, 25, 31, 235)
    NORMAL = Color.new(90, 210, 120, 255)
    BAD = Color.new(245, 95, 95, 255)
  end
end

ALBERT_CG.apply_solo_party_limits

#==============================================================================
# ■ Game_Party：唯一權威隊伍結構
#==============================================================================
class Game_Party < Game_Unit
  alias albert_cg_v190_solo_initialize initialize
  def initialize
    ALBERT_CG.apply_solo_party_limits
    albert_cg_v190_solo_initialize
    cg_solo_prepare_party!
  end

  # 固定夥伴相關 API 保留空殼，避免舊腳本呼叫後報錯。
  def cg_v056_fixed_partner_map
    return {}
  end

  def cg_prepare_fixed_partner_pet_data
    @cg_fixed_partner_pet_map = {}
    return @cg_fixed_partner_pet_map
  end

  def cg_fixed_partner_pet_actor_id(owner_actor_or_id)
    return nil
  end

  def cg_fixed_partner_owner_id_for(pet_actor_or_id)
    return nil
  end

  def cg_fixed_partner_pet_actor?(actor_or_id)
    return false
  end

  def cg_fixed_partner_pair?(owner_actor_or_id, pet_actor_or_id)
    return false
  end

  def cg_fixed_partner_deployed?(owner_actor_or_id)
    return false
  end

  def cg_set_fixed_partner_deployed(owner_actor_or_id, value)
    return false
  end

  def cg_sync_fixed_partner_pets!
    return cg_solo_sync_party!
  end

  def cg_set_fixed_partner_pet(owner_actor_id, pet_actor_id, deploy = true)
    return false
  end

  #--------------------------------------------------------------------------
  # ● 攜帶／倉庫資料整理
  #--------------------------------------------------------------------------
  alias albert_cg_v190_solo_prepare_storage cg_prepare_pet_storage_data
  def cg_prepare_pet_storage_data
    return true if @cg_v190_preparing_storage
    @cg_v190_preparing_storage = true
    begin
      albert_cg_v190_solo_prepare_storage
      @cg_carried_pet_ids = [] if @cg_carried_pet_ids == nil
      @cg_storage_pet_ids = [] if @cg_storage_pet_ids == nil

      valid_ids = cg_owned_pet_ids.collect { |id| id.to_i }
      valid_ids.delete_if { |id| $game_actors.cg_pet(id) == nil }

      # 舊存檔中已經在實際隊伍的 Clone 優先保留於攜帶欄。
      old_active = []
      @actors = [] if @actors == nil
      for actor_id in @actors
        pet = $game_actors.cg_pet(actor_id.to_i)
        old_active.push(pet.id) if pet != nil && !old_active.include?(pet.id)
      end

      ordered = []
      for id in old_active + @cg_carried_pet_ids + valid_ids
        id = id.to_i
        ordered.push(id) if valid_ids.include?(id) && !ordered.include?(id)
      end
      @cg_carried_pet_ids = ordered[0, ALBERT_CG::SOLO_PET_SLOTS] || []

      storage = []
      for id in @cg_storage_pet_ids + valid_ids
        id = id.to_i
        next if @cg_carried_pet_ids.include?(id)
        storage.push(id) if valid_ids.include?(id) && !storage.include?(id)
      end
      @cg_storage_pet_ids = storage[0, ALBERT_CG::PET_STORAGE_LIMIT] || []
    ensure
      @cg_v190_preparing_storage = false
    end
    cg_solo_sync_party! unless @cg_v190_syncing_party
    return true
  end

  def cg_solo_prepare_party!
    return false if @cg_v190_syncing_party
    cg_prepare_pet_storage_data unless @cg_v190_preparing_storage
    return cg_solo_sync_party!
  rescue
    return false
  end

  def cg_solo_sync_party!
    return false if @cg_v190_syncing_party
    if $game_temp != nil && $game_temp.in_battle && @cg_v190_battle_roster_locked
      return false
    end
    @cg_v190_syncing_party = true
    changed = false
    begin
      ALBERT_CG.apply_solo_party_limits
      @actors = [] if @actors == nil
      carried = @cg_carried_pet_ids == nil ? [] : @cg_carried_pet_ids
      valid_pets = []
      for pet_id in carried[0, ALBERT_CG::SOLO_PET_SLOTS] || []
        pet = $game_actors == nil ? nil : $game_actors.cg_pet(pet_id.to_i)
        valid_pets.push(pet.id) if pet != nil && !valid_pets.include?(pet.id)
      end
      desired = [ALBERT_CG::SOLO_HUMAN_ACTOR_ID] + valid_pets
      if @actors != desired
        @actors = desired
        changed = true
      end
      @cg_active_pet_id = valid_pets[0]
      @cg_active_pet_ids_by_owner = {
        ALBERT_CG::SOLO_HUMAN_ACTOR_ID => valid_pets[0]
      }
    ensure
      @cg_v190_syncing_party = false
    end
    if changed
      $game_player.refresh if $game_player != nil
      $party_change = true
    end
    return changed
  rescue
    @cg_v190_syncing_party = false
    return false
  end

  # 使用 v0.5.6 保存的 VX 原始 members，避開舊的固定寵物同步鏈。
  def members
    cg_solo_prepare_party!
    if respond_to?(:albert_cg_v056_base_members)
      return albert_cg_v056_base_members
    end
    result = []
    @actors = [] if @actors == nil
    for actor_id in @actors
      pet = $game_actors.respond_to?(:cg_pet) ? $game_actors.cg_pet(actor_id) : nil
      actor = pet == nil ? $game_actors[actor_id] : pet
      result.push(actor) if actor != nil
    end
    return result
  end

  # 不允許事件或舊測試工具再加入隊友。Clone 只由攜帶欄同步。
  def add_actor(actor_id)
    actor_id = actor_id.to_i
    if actor_id == ALBERT_CG::SOLO_HUMAN_ACTOR_ID
      @actors = [] if @actors == nil
      @actors.unshift(actor_id) unless @actors.include?(actor_id)
      cg_solo_sync_party!
      return
    end
    pet = $game_actors == nil ? nil : $game_actors.cg_pet(actor_id)
    if pet != nil
      cg_prepare_pet_storage_data
      unless @cg_carried_pet_ids.include?(pet.id) || @cg_storage_pet_ids.include?(pet.id)
        if @cg_carried_pet_ids.size < ALBERT_CG::SOLO_PET_SLOTS
          @cg_carried_pet_ids.push(pet.id)
        else
          @cg_storage_pet_ids.push(pet.id)
        end
      end
      cg_solo_sync_party!
    end
  end

  def remove_actor(actor_id)
    actor_id = actor_id.to_i
    return if actor_id == ALBERT_CG::SOLO_HUMAN_ACTOR_ID
    pet = $game_actors == nil ? nil : $game_actors.cg_pet(actor_id)
    return if pet == nil
    cg_store_pet(pet.id)
  end

  alias albert_cg_v190_solo_register_pet cg_register_pet
  def cg_register_pet(actor_id, owner_actor_id = nil, fixed_owner = nil)
    result = albert_cg_v190_solo_register_pet(actor_id,
      ALBERT_CG::SOLO_HUMAN_ACTOR_ID, false)
    return false unless result
    cg_prepare_pet_storage_data
    pet_id = actor_id.to_i

    # 捕捉發生於戰鬥中時，不讓新寵物在同一場戰鬥中突然加入隊伍。
    if $game_temp != nil && $game_temp.in_battle
      @cg_carried_pet_ids.delete(pet_id)
      @cg_storage_pet_ids.push(pet_id) unless @cg_storage_pet_ids.include?(pet_id)
      @cg_last_pet_destination = :storage
    elsif !@cg_carried_pet_ids.include?(pet_id) && !@cg_storage_pet_ids.include?(pet_id)
      if @cg_carried_pet_ids.size < ALBERT_CG::SOLO_PET_SLOTS
        @cg_carried_pet_ids.push(pet_id)
        @cg_last_pet_destination = :carried
      else
        @cg_storage_pet_ids.push(pet_id)
        @cg_last_pet_destination = :storage
      end
    end
    cg_prepare_pet_storage_data
    return true
  end

  alias albert_cg_v190_solo_remove_references cg_remove_pet_references
  def cg_remove_pet_references(actor_id)
    result = albert_cg_v190_solo_remove_references(actor_id)
    cg_prepare_pet_storage_data
    cg_solo_sync_party!
    return result
  end

  #--------------------------------------------------------------------------
  # ● 三隻攜帶寵物就是三隻出戰寵物
  #--------------------------------------------------------------------------
  def cg_carried_pet_slot(index)
    cg_prepare_pet_storage_data
    id = @cg_carried_pet_ids[index.to_i]
    return id == nil ? nil : $game_actors.cg_pet(id)
  end

  def cg_actual_primary_clone_pet
    return cg_carried_pet_slot(0)
  end

  def cg_active_pet_id(owner_actor_id = nil)
    pet = cg_actual_primary_clone_pet
    return pet == nil ? nil : pet.id
  end

  def cg_active_pet(owner_actor_id = nil)
    return cg_actual_primary_clone_pet
  end

  def cg_active_pet_for(human)
    return nil if human == nil
    return nil unless human.id == ALBERT_CG::SOLO_HUMAN_ACTOR_ID
    return cg_actual_primary_clone_pet
  end

  def cg_active_pets
    cg_prepare_pet_storage_data
    result = []
    for pet_id in @cg_carried_pet_ids[0, ALBERT_CG::SOLO_PET_SLOTS] || []
      pet = $game_actors.cg_pet(pet_id)
      result.push(pet) if pet != nil
    end
    return result
  end

  def cg_human_members
    human = $game_actors == nil ? nil : $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
    return human == nil ? [] : [human]
  end

  def cg_owner_pet_pair?(human, pet)
    return false if human == nil || pet == nil
    return false unless human.id == ALBERT_CG::SOLO_HUMAN_ACTOR_ID
    return cg_carried_pet_ids.include?(pet.id)
  end

  def cg_primary_pet_pool
    return cg_carried_pets
  end

  def cg_pets_owned_by(owner_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i
    return [] unless owner_id == ALBERT_CG::SOLO_HUMAN_ACTOR_ID
    return cg_owned_pets
  end

  # 全部攜帶寵物已在場，沒有戰鬥候補。
  def cg_battle_reserve_pets(owner_actor_or_id = nil)
    return []
  end

  def cg_battle_switchable_pet?(actor_id, owner_actor_or_id = nil)
    return false
  end

  def cg_battle_switch_pet(actor_id, owner_actor_or_id = nil)
    return false
  end

  def cg_battle_recall_pet(owner_actor_or_id = nil, expected_pet_id = nil)
    return false
  end

  def cg_free_pet_switch_owner?(actor_or_id)
    return false
  end

  def cg_owner_pet_management_available?(owner_actor_or_id)
    return true
  end

  def cg_map_deploy_pet(actor_id)
    cg_prepare_pet_storage_data
    pet_id = actor_id.to_i
    return false unless cg_owned_pet_ids.include?(pet_id)
    if @cg_storage_pet_ids.include?(pet_id)
      if @cg_carried_pet_ids.size < ALBERT_CG::SOLO_PET_SLOTS
        @cg_storage_pet_ids.delete(pet_id)
        @cg_carried_pet_ids.push(pet_id)
      else
        return false
      end
    end
    if @cg_carried_pet_ids.include?(pet_id)
      @cg_carried_pet_ids.delete(pet_id)
      @cg_carried_pet_ids.unshift(pet_id)
    end
    cg_solo_sync_party!
    return true
  end

  def cg_map_recall_pet
    return false
  end

  def cg_deploy_pet(actor_id, owner_actor_id = nil)
    return cg_map_deploy_pet(actor_id)
  end

  def cg_recall_pet(owner_actor_id = nil)
    return false
  end

  #--------------------------------------------------------------------------
  # ● 倉庫操作：攜帶欄固定上限 3
  #--------------------------------------------------------------------------
  def cg_carry_full?
    return cg_carried_pet_ids.size >= ALBERT_CG::SOLO_PET_SLOTS
  end

  def cg_store_pet(actor_id)
    cg_prepare_pet_storage_data
    pet_id = actor_id.to_i
    return false unless @cg_carried_pet_ids.include?(pet_id)
    return false if cg_storage_full?
    @cg_carried_pet_ids.delete(pet_id)
    @cg_storage_pet_ids.push(pet_id) unless @cg_storage_pet_ids.include?(pet_id)
    cg_solo_sync_party!
    return true
  end

  def cg_withdraw_pet(actor_id)
    cg_prepare_pet_storage_data
    pet_id = actor_id.to_i
    return false unless @cg_storage_pet_ids.include?(pet_id)
    return false if cg_carry_full?
    @cg_storage_pet_ids.delete(pet_id)
    @cg_carried_pet_ids.push(pet_id)
    cg_solo_sync_party!
    return true
  end

  def cg_swap_storage_with_slot(slot_index, storage_actor_id)
    cg_prepare_pet_storage_data
    slot_index = slot_index.to_i
    storage_id = storage_actor_id.to_i
    return false if slot_index < 0 || slot_index >= ALBERT_CG::SOLO_PET_SLOTS
    return false unless @cg_storage_pet_ids.include?(storage_id)

    old_id = @cg_carried_pet_ids[slot_index]
    storage_index = @cg_storage_pet_ids.index(storage_id)
    @cg_storage_pet_ids.delete(storage_id)
    if old_id == nil
      @cg_carried_pet_ids.insert(slot_index, storage_id)
    else
      @cg_carried_pet_ids[slot_index] = storage_id
      @cg_storage_pet_ids.insert(storage_index, old_id)
    end
    @cg_carried_pet_ids = @cg_carried_pet_ids[0, ALBERT_CG::SOLO_PET_SLOTS]
    cg_solo_sync_party!
    return true
  end

  def cg_swap_pet_storage(carried_actor_id, storage_actor_id)
    cg_prepare_pet_storage_data
    slot = @cg_carried_pet_ids.index(carried_actor_id.to_i)
    return false if slot == nil
    return cg_swap_storage_with_slot(slot, storage_actor_id)
  end

  #--------------------------------------------------------------------------
  # ● 戰場預設站位：主角後排中央，三寵物前排左中右
  #--------------------------------------------------------------------------
  def cg_assign_default_battle_slots
    cg_solo_sync_party!
    human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
    if human != nil
      human.cg_set_battle_slot(:back, 1, true)
      human.reset_coordinate if human.respond_to?(:reset_coordinate)
      human.base_position if human.respond_to?(:base_position)
    end
    pets = cg_active_pets
    for i in 0...pets.size
      pet = pets[i]
      pet.cg_set_battle_slot(:front, i, true)
      pet.reset_coordinate if pet.respond_to?(:reset_coordinate)
      pet.base_position if pet.respond_to?(:base_position)
    end
    return true
  end
end

#==============================================================================
# ■ Window_ActorCommand：三寵物全數參戰，移除「換寵」
#==============================================================================
class Window_ActorCommand
  alias albert_cg_v190_solo_command_setup setup
  def setup(actor)
    albert_cg_v190_solo_command_setup(actor)
    if @cg_command_types != nil
      loop do
        index = @cg_command_types.index(:switch_pet)
        break if index == nil
        @cg_command_types.delete_at(index)
        @commands.delete_at(index) if @commands != nil
      end
      @item_max = @commands == nil ? 0 : @commands.size
      create_contents if respond_to?(:create_contents)
      refresh
      self.index = 0 if @item_max > 0
    end
  end
end

#==============================================================================
# ■ Scene_Battle：主角＋三寵物四行動槽
#==============================================================================
class Scene_Battle < Scene_Base
  def cg_build_input_slots
    @cg_input_slots = []
    @cg_input_slot_index = -1
    human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
    return @cg_input_slots if human == nil || !human.exist?

    human_can_input = human.inputable? || human.auto_battle
    human_slots = []
    if human_can_input
      human_slots.push(cg_make_slot(human, 1, "人物行動"))
      @cg_input_slots.push(human_slots[0])
    end

    pets = $game_party.cg_active_pets
    for pet_index in 0...ALBERT_CG::SOLO_PET_SLOTS
      pet = pets[pet_index]
      if pet != nil && pet.exist?
        if pet.inputable? || pet.auto_battle
          @cg_input_slots.push(cg_make_slot(pet, 1,
            "寵物行動 " + (pet_index + 1).to_s))
        end
      elsif human_can_input
        ordinal = human_slots.size + 1
        slot = cg_make_slot(human, ordinal,
          "人物行動 " + ordinal.to_s)
        human_slots.push(slot)
        @cg_input_slots.push(slot)
      end
    end

    if human_slots.size > 1
      for i in 0...human_slots.size
        human_slots[i].label = "人物行動 " + (i + 1).to_s
      end
    end
    return @cg_input_slots
  end

  # 三隻寵物後，人物移動不再出現含糊的「與自己的寵物交換」。
  def cg_move_entries
    entries = []
    human = @active_battler
    for row in [:front, :back]
      for column in 0...ALBERT_CG::BATTLE_COLUMNS
        next if human.cg_battle_slot_assigned? &&
          human.cg_battle_row == row && human.cg_battle_column == column
        next if $game_party.cg_slot_occupied_by_other?(row, column, human, false)
        entries.push({:type => :move,
          :text => "移至" + ALBERT_CG.cg_slot_text(row, column),
          :row => row, :column => column})
      end
    end
    return entries
  end

  alias albert_cg_v190_solo_battle_start start
  def start
    if $game_party != nil
      $game_party.instance_variable_set(:@cg_v190_battle_roster_locked, false)
      $game_party.cg_solo_prepare_party!
      $game_party.cg_assign_default_battle_slots
      $game_party.instance_variable_set(:@cg_v190_battle_roster_locked, true)
    end
    albert_cg_v190_solo_battle_start
  end

  alias albert_cg_v190_solo_battle_terminate terminate
  def terminate
    $game_party.instance_variable_set(:@cg_v190_battle_roster_locked, false) if
      $game_party != nil
    albert_cg_v190_solo_battle_terminate
    $game_party.cg_solo_prepare_party! if $game_party != nil
  end
end

#==============================================================================
# ■ Battle Status：左側主角大區塊＋右側三寵物區塊
#==============================================================================
class Window_BattleStatus < Window_Selectable
  def initialize
    super(0, ALBERT_CG::SoloBattleStatus::STATUS_Y,
      Graphics.width, ALBERT_CG::SoloBattleStatus::STATUS_HEIGHT)
    self.z = 430
    self.opacity = 0
    self.back_opacity = 0
    self.active = false
    self.index = -1
    @item_max = 0
    @cg_last_signature = nil
    @cg_refresh_wait = 0
    refresh
  end

  def item_rect(index)
    index = index.to_i
    if index == 0
      return Rect.new(0, 0, ALBERT_CG::SoloBattleStatus::HERO_WIDTH,
        self.contents.height)
    end
    pet_index = index - 1
    x = ALBERT_CG::SoloBattleStatus::PET_BLOCK_X +
      pet_index * (ALBERT_CG::SoloBattleStatus::PET_CARD_WIDTH +
      ALBERT_CG::SoloBattleStatus::PET_GAP)
    width = ALBERT_CG::SoloBattleStatus::PET_CARD_WIDTH
    if index == 3
      width = self.contents.width - x
    end
    return Rect.new(x, 0, width, self.contents.height)
  end

  def update_cursor
    self.cursor_rect.empty
  end

  def refresh
    return if self.contents == nil || self.contents.disposed?
    self.contents.clear
    members = $game_party == nil ? [] : $game_party.members
    @item_max = [members.size, 4].min

    cg_v190_draw_main_blocks
    hero = members[0]
    cg_v190_draw_hero(item_rect(0), hero, @index == 0)
    for i in 0...3
      pet = members[i + 1]
      cg_v190_draw_pet(item_rect(i + 1), pet, @index == i + 1, i)
    end
    @cg_last_signature = cg_status_signature
  end

  def cg_v190_round_gradient(x, y, width, height, radius, color_a, color_b)
    if defined?(ALBERT_CG::BattleVisualV183b)
      ALBERT_CG::BattleVisualV183b.fill_round_gradient(self.contents,
        x, y, width, height, radius, color_a, color_b)
    else
      self.contents.gradient_fill_rect(x, y, width, height, color_a, color_b)
    end
  rescue
    self.contents.fill_rect(x, y, width, height, color_a)
  end

  def cg_v190_draw_main_blocks
    h = self.contents.height
    cg_v190_round_gradient(1, 1,
      ALBERT_CG::SoloBattleStatus::HERO_WIDTH - 2, h - 2, 10,
      ALBERT_CG::SoloBattleStatus::PANEL_EDGE,
      Color.new(ALBERT_CG::SoloBattleStatus::PANEL_EDGE.red,
        ALBERT_CG::SoloBattleStatus::PANEL_EDGE.green,
        ALBERT_CG::SoloBattleStatus::PANEL_EDGE.blue, 70))
    cg_v190_round_gradient(3, 3,
      ALBERT_CG::SoloBattleStatus::HERO_WIDTH - 6, h - 6, 8,
      ALBERT_CG::SoloBattleStatus::PANEL_START,
      ALBERT_CG::SoloBattleStatus::PANEL_END)

    x = ALBERT_CG::SoloBattleStatus::PET_BLOCK_X
    w = self.contents.width - x
    cg_v190_round_gradient(x + 1, 1, w - 2, h - 2, 10,
      ALBERT_CG::SoloBattleStatus::PET_EDGE,
      Color.new(ALBERT_CG::SoloBattleStatus::PET_EDGE.red,
        ALBERT_CG::SoloBattleStatus::PET_EDGE.green,
        ALBERT_CG::SoloBattleStatus::PET_EDGE.blue, 70))
    cg_v190_round_gradient(x + 3, 3, w - 6, h - 6, 8,
      ALBERT_CG::SoloBattleStatus::PET_START,
      ALBERT_CG::SoloBattleStatus::PET_END)
  end

  def cg_v190_draw_focus(rect, selected)
    return unless selected
    pulse = (Graphics.frame_count / 6) % 2
    color = pulse == 0 ? ALBERT_CG::SoloBattleStatus::GOLD :
      ALBERT_CG::SoloBattleStatus::GOLD_LIGHT
    cg_draw_thick_rect_border(rect.x + 2, rect.y + 2,
      rect.width - 4, rect.height - 4, color, 3) if
      respond_to?(:cg_draw_thick_rect_border)
    self.contents.fill_rect(rect.x + 8, rect.y + 2,
      rect.width - 16, 3, color)
  rescue
  end

  def cg_v190_draw_circle_character(actor, cx, cy, radius, selected)
    edge = selected ? ALBERT_CG::SoloBattleStatus::GOLD :
      Color.new(110, 210, 160, 235)
    if respond_to?(:cg_v183a_fill_circle)
      cg_v183a_fill_circle(cx, cy, radius + 2, edge, edge)
      cg_v183a_fill_circle(cx, cy, radius - 1,
        ALBERT_CG::SoloBattleStatus::CIRCLE_INNER,
        Color.new(28, 46, 52, 235))
    else
      self.contents.fill_rect(cx - radius, cy - radius,
        radius * 2, radius * 2, ALBERT_CG::SoloBattleStatus::CIRCLE_INNER)
    end
    cg_draw_small_character(actor, cx - radius + 5, cy - radius + 3,
      radius * 2 - 10, radius * 2 - 6) if actor != nil
  rescue
  end

  def cg_v190_draw_name(actor, x, y, width, center = false)
    return if actor == nil
    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 12
    self.contents.font.bold = true
    self.contents.font.color = hp_color(actor)
    self.contents.draw_text(x, y, width - 28, 16, actor.name.to_s,
      center ? 1 : 0)
    self.contents.font.size = 9
    self.contents.font.color = system_color
    self.contents.draw_text(x + width - 28, y + 1, 25, 14,
      "L" + actor.level.to_i.to_s, 2)
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  end

  def cg_v190_draw_gauge(actor, rect, kind, y, height = 12)
    return if actor == nil
    x = rect.x + 7
    width = rect.width - 14
    value = kind == :hp ? actor.hp.to_i : actor.mp.to_i
    maximum = kind == :hp ? actor.maxhp.to_i : actor.maxmp.to_i
    label = kind == :hp ? "HP" : "MP"
    text_color = kind == :hp ? hp_color(actor) : mp_color(actor)

    old_size = self.contents.font.size
    old_bold = self.contents.font.bold
    old_color = self.contents.font.color
    self.contents.font.size = 10
    self.contents.font.bold = true
    self.contents.font.color = text_color
    self.contents.draw_text(x, rect.y + y - 12, 20, 12, label)
    self.contents.draw_text(x + 20, rect.y + y - 12,
      width - 20, 12, value.to_s + "/" + maximum.to_s, 2)

    if defined?(ALBERT_CG::GenericGauge) &&
       ALBERT_CG::GenericGauge.respond_to?(:draw_slanted)
      ALBERT_CG::GenericGauge.draw_slanted(self.contents, kind,
        x, rect.y + y, width, height, value, maximum, 4)
    elsif defined?(ALBERT_CG::GenericGauge)
      ALBERT_CG::GenericGauge.draw(self.contents, kind,
        x, rect.y + y, width, height, value, maximum)
    else
      rate = maximum <= 0 ? 0.0 : value.to_f / maximum.to_f
      self.contents.fill_rect(x, rect.y + y, width, height,
        Color.new(0, 0, 0, 190))
      color = kind == :hp ? Color.new(80, 220, 105) :
        Color.new(70, 145, 245)
      self.contents.fill_rect(x + 1, rect.y + y + 1,
        ((width - 2) * rate).to_i, height - 2, color)
    end
    self.contents.font.size = old_size
    self.contents.font.bold = old_bold
    self.contents.font.color = old_color
  rescue
  end

  def cg_v190_state_list(actor)
    result = []
    return result if actor == nil
    for state in actor.states
      result.push(state) if state != nil && state.icon_index.to_i > 0
    end
    return result
  rescue
    return []
  end

  def cg_v190_draw_states(actor, x, y, width, maximum)
    states = cg_v190_state_list(actor)
    if states.empty?
      cg_v190_round_gradient(x, y, 38, 16, 5,
        Color.new(45, 126, 78, 220), Color.new(20, 58, 37, 110))
      old_size = self.contents.font.size
      old_color = self.contents.font.color
      self.contents.font.size = 9
      self.contents.font.color = Color.new(228, 255, 235)
      self.contents.draw_text(x, y, 38, 16, "正常", 1)
      self.contents.font.size = old_size
      self.contents.font.color = old_color
      return
    end
    iconset = Cache.system("IconSet")
    count = [states.size, maximum].min
    for i in 0...count
      state = states[i]
      source = Rect.new(state.icon_index % 16 * 24,
        state.icon_index / 16 * 24, 24, 24)
      target = Rect.new(x + i * 20, y, 18, 18)
      self.contents.stretch_blt(target, iconset, source)
    end
    if states.size > maximum
      old_size = self.contents.font.size
      old_color = self.contents.font.color
      self.contents.font.size = 9
      self.contents.font.color = Color.new(255, 232, 128)
      self.contents.draw_text(x + maximum * 20, y,
        width - maximum * 20, 18,
        "+" + (states.size - maximum).to_s, 0)
      self.contents.font.size = old_size
      self.contents.font.color = old_color
    end
  rescue
  end

  def cg_v190_draw_hero(rect, actor, selected)
    cg_v190_draw_focus(rect, selected)
    if actor == nil
      self.contents.draw_text(rect.x, rect.y + 50, rect.width,
        20, "主角", 1)
      return
    end
    cg_v190_draw_name(actor, rect.x + 7, rect.y + 4,
      rect.width - 14, false)
    cg_v190_draw_circle_character(actor, rect.x + 38,
      rect.y + 52, 26, selected)
    cg_v190_draw_gauge(actor,
      Rect.new(rect.x + 67, rect.y, rect.width - 68, rect.height),
      :hp, 37, 13)
    cg_v190_draw_gauge(actor,
      Rect.new(rect.x + 67, rect.y, rect.width - 68, rect.height),
      :mp, 73, 13)
    cg_v190_draw_states(actor, rect.x + 8,
      rect.y + rect.height - 23, rect.width - 16, 5)
  end

  def cg_v190_draw_pet(rect, actor, selected, slot_index)
    # 三寵物共用大區塊，內部以半透明圓角卡分隔。
    start = actor == nil ? ALBERT_CG::SoloBattleStatus::EMPTY_START :
      Color.new(28, 67, 50, 205)
    finish = actor == nil ? ALBERT_CG::SoloBattleStatus::EMPTY_END :
      Color.new(10, 28, 22, 82)
    cg_v190_round_gradient(rect.x + 1, rect.y + 4,
      rect.width - 2, rect.height - 8, 8, start, finish)
    cg_v190_draw_focus(rect, selected)

    if actor == nil
      cg_v190_draw_circle_character(nil,
        rect.x + rect.width / 2, rect.y + 42, 22, false)
      old_size = self.contents.font.size
      old_color = self.contents.font.color
      self.contents.font.size = 10
      self.contents.font.color = Color.new(150, 166, 158)
      self.contents.draw_text(rect.x, rect.y + 69,
        rect.width, 16, "寵物欄 " + (slot_index + 1).to_s, 1)
      self.contents.font.size = old_size
      self.contents.font.color = old_color
      return
    end

    cg_v190_draw_name(actor, rect.x + 4, rect.y + 5,
      rect.width - 8, true)
    cg_v190_draw_circle_character(actor,
      rect.x + rect.width / 2, rect.y + 43, 22, selected)
    # 狀態放在圓框左右兩側，避免擠壓 HP／MP。
    states = cg_v190_state_list(actor)
    if states.empty?
      cg_v190_round_gradient(rect.x + 5, rect.y + 35, 17, 15, 5,
        Color.new(45, 126, 78, 220), Color.new(20, 58, 37, 105))
      old_size = self.contents.font.size
      old_color = self.contents.font.color
      self.contents.font.size = 8
      self.contents.font.color = Color.new(230, 255, 236)
      self.contents.draw_text(rect.x + 5, rect.y + 34, 17, 16, "正", 1)
      self.contents.font.size = old_size
      self.contents.font.color = old_color
    else
      iconset = Cache.system("IconSet")
      positions = [rect.x + 4, rect.x + rect.width - 22]
      count = [states.size, 2].min
      for state_index in 0...count
        state = states[state_index]
        source = Rect.new(state.icon_index % 16 * 24,
          state.icon_index / 16 * 24, 24, 24)
        target = Rect.new(positions[state_index], rect.y + 34, 18, 18)
        self.contents.stretch_blt(target, iconset, source)
      end
      if states.size > 2
        old_size = self.contents.font.size
        old_color = self.contents.font.color
        self.contents.font.size = 8
        self.contents.font.color = Color.new(255, 232, 128)
        self.contents.draw_text(rect.x + rect.width - 28, rect.y + 51,
          24, 12, "+" + (states.size - 2).to_s, 2)
        self.contents.font.size = old_size
        self.contents.font.color = old_color
      end
    end
    cg_v190_draw_gauge(actor, rect, :hp, 77, 11)
    cg_v190_draw_gauge(actor, rect, :mp, 105, 11)
  end
end

#==============================================================================
# ■ 寵物管理 UI：上方三攜帶欄＋下方倉庫＋右側詳細
#==============================================================================
class Window_CG_SoloCarrySlots < Window_Selectable
  attr_reader :data

  def initialize
    super(0, 56, 224, 130)
    @column_max = 1
    @item_max = ALBERT_CG::SOLO_PET_SLOTS
    refresh
    self.index = 0
  end

  def pet
    return nil if self.index < 0
    return @data[self.index]
  end

  def refresh
    @data = []
    for i in 0...ALBERT_CG::SOLO_PET_SLOTS
      @data.push($game_party.cg_carried_pet_slot(i))
    end
    create_contents
    for i in 0...ALBERT_CG::SOLO_PET_SLOTS
      draw_item(i)
    end
  end

  def item_rect(index)
    return Rect.new(0, index.to_i * 32, contents.width, 32)
  end

  def cg_v190_draw_character(pet, x, y, width = 28, height = 28)
    return if pet == nil
    name = pet.character_name.to_s
    return if name.empty?
    bitmap = Cache.character(name)
    single = name[0, 1] == "$" || name[0, 2] == "!$" ||
      name[0, 2] == "$!"
    cw = bitmap.width / (single ? 3 : 12)
    ch = bitmap.height / (single ? 4 : 8)
    index = pet.character_index.to_i
    sx = single ? cw : (index % 4 * 3 + 1) * cw
    sy = single ? 0 : (index / 4 * 4) * ch
    scale = [width.to_f / cw, height.to_f / ch, 1.0].min
    dw = [(cw * scale).to_i, 1].max
    dh = [(ch * scale).to_i, 1].max
    target = Rect.new(x + (width - dw) / 2, y + height - dh, dw, dh)
    source = Rect.new(sx, sy, cw, ch)
    if defined?(ALBERT_CG::TRGSSXVisual)
      ALBERT_CG::TRGSSXVisual.stretch_blt(self.contents, target, bitmap, source, 255)
    else
      self.contents.stretch_blt(target, bitmap, source)
    end
  rescue
  end

  def draw_item(index)
    rect = item_rect(index)
    self.contents.clear_rect(rect)
    pet = @data[index]
    self.contents.font.color = system_color
    self.contents.draw_text(rect.x + 2, rect.y, 28, 32,
      (index + 1).to_s, 1)
    if pet == nil
      self.contents.font.color = Color.new(140, 150, 160)
      self.contents.draw_text(rect.x + 34, rect.y,
        rect.width - 38, 32, "空的攜帶欄")
      return
    end
    self.contents.font.color = normal_color
    cg_v190_draw_character(pet, rect.x + 32, rect.y + 2, 28, 28)
    self.contents.draw_text(rect.x + 62, rect.y,
      rect.width - 112, 32, pet.name.to_s)
    self.contents.draw_text(rect.x + rect.width - 50, rect.y,
      46, 32, "L" + pet.level.to_i.to_s, 2)
  end
end

class Window_CG_SoloStorageList < Window_Selectable
  attr_reader :data

  def cg_v190_draw_character(pet, x, y, width = 28, height = 24)
    return if pet == nil
    name = pet.character_name.to_s
    return if name.empty?
    bitmap = Cache.character(name)
    single = name[0, 1] == "$" || name[0, 2] == "!$" ||
      name[0, 2] == "$!"
    cw = bitmap.width / (single ? 3 : 12)
    ch = bitmap.height / (single ? 4 : 8)
    index = pet.character_index.to_i
    sx = single ? cw : (index % 4 * 3 + 1) * cw
    sy = single ? 0 : (index / 4 * 4) * ch
    scale = [width.to_f / cw, height.to_f / ch, 1.0].min
    dw = [(cw * scale).to_i, 1].max
    dh = [(ch * scale).to_i, 1].max
    target = Rect.new(x + (width - dw) / 2, y + height - dh, dw, dh)
    source = Rect.new(sx, sy, cw, ch)
    if defined?(ALBERT_CG::TRGSSXVisual)
      ALBERT_CG::TRGSSXVisual.stretch_blt(self.contents, target, bitmap, source, 255)
    else
      self.contents.stretch_blt(target, bitmap, source)
    end
  rescue
  end

  def initialize
    super(0, 186, 224, 230)
    @column_max = 1
    refresh
    self.index = 0
  end

  def pet
    return nil if @data == nil || @data.empty? || self.index < 0
    return @data[self.index]
  end

  def refresh
    @data = $game_party.cg_storage_pets
    @item_max = [@data.size, 1].max
    create_contents
    if @data.empty?
      self.contents.font.color = Color.new(140, 150, 160)
      self.contents.draw_text(4, 0, contents.width - 8, WLH,
        "倉庫目前沒有寵物")
    else
      for i in 0...@data.size
        draw_item(i)
      end
    end
  end

  def draw_item(index)
    pet = @data[index]
    return if pet == nil
    rect = item_rect(index)
    self.contents.clear_rect(rect)
    cg_v190_draw_character(pet, rect.x + 2, rect.y, 28, rect.height)
    self.contents.font.color = normal_color
    self.contents.draw_text(rect.x + 32, rect.y,
      rect.width - 84, rect.height, pet.name.to_s)
    self.contents.draw_text(rect.x + rect.width - 50, rect.y,
      46, rect.height, "L" + pet.level.to_i.to_s, 2)
  end
end

class Window_CG_SoloPetDetail < Window_CG_PetDetail
  def initialize
    super
    self.x = 224
    self.y = 56
    self.width = 320
    self.height = 360
    create_contents
    @pet = nil
    refresh
  end
end

class Scene_CG_PetLab < Scene_Base
  def initialize(initial_mode = :carried, selected_pet_id = nil)
    @cg_v190_initial_mode = initial_mode
    @cg_v190_selected_pet_id = selected_pet_id
  end

  def start
    super
    $game_party.cg_prepare_pet_storage_data
    create_menu_background
    @focus = @cg_v190_initial_mode == :storage ? :storage : :carry
    @swap_origin = nil
    @swap_pet_id = nil
    @swap_slot_index = nil
    @confirm_release = false

    @title_window = Window_Base.new(0, 0, 544, 56)
    @carry_window = Window_CG_SoloCarrySlots.new
    @storage_window = Window_CG_SoloStorageList.new
    @detail_window = Window_CG_SoloPetDetail.new
    @command_window = nil
    @confirm_window = nil

    cg_v190_restore_selection(@cg_v190_selected_pet_id)
    cg_v190_activate_focus(@focus)
    cg_v190_refresh_title
    cg_v190_refresh_detail
  end

  def terminate
    super
    dispose_menu_background
    [@title_window, @carry_window, @storage_window, @detail_window,
     @command_window, @confirm_window].each do |window|
      window.dispose if window != nil && !window.disposed?
    end
  end

  def update
    super
    update_menu_background
    @carry_window.update if @carry_window != nil
    @storage_window.update if @storage_window != nil
    @command_window.update if @command_window != nil
    @confirm_window.update if @confirm_window != nil

    if @confirm_window != nil && @confirm_window.active
      cg_v190_update_confirm
    elsif @command_window != nil && @command_window.active
      cg_v190_update_command
    elsif @swap_origin != nil
      cg_v190_update_swap
    else
      cg_v190_update_lists
    end
    cg_v190_refresh_detail
  end

  def cg_v190_current_window
    return @focus == :storage ? @storage_window : @carry_window
  end

  def cg_v190_current_pet
    return cg_v190_current_window.pet
  end

  def cg_v190_activate_focus(focus)
    @focus = focus == :storage ? :storage : :carry
    @carry_window.active = @focus == :carry
    @storage_window.active = @focus == :storage
  end

  def cg_v190_restore_selection(pet_id)
    return if pet_id == nil
    pet_id = pet_id.to_i
    for i in 0...@carry_window.data.size
      pet = @carry_window.data[i]
      if pet != nil && pet.id == pet_id
        @carry_window.index = i
        @focus = :carry
        return
      end
    end
    for i in 0...@storage_window.data.size
      pet = @storage_window.data[i]
      if pet != nil && pet.id == pet_id
        @storage_window.index = i
        @focus = :storage
        return
      end
    end
  end

  def cg_v190_refresh_title
    @title_window.contents.clear
    @title_window.contents.font.size = 16
    if @swap_origin == :carry
      text = "替換攜帶寵物：請在下方倉庫選擇新寵物　C：交換　B：取消"
    elsif @swap_origin == :storage
      text = "替換倉庫寵物：請在上方選擇要替換的攜帶欄　C：交換　B：取消"
    else
      text = "寵物管理　攜帶 " + $game_party.cg_carried_pet_ids.size.to_s +
        "/3　倉庫 " + $game_party.cg_storage_pet_ids.size.to_s +
        "　L/R：切換區域　C：操作　B：返回"
    end
    @title_window.contents.draw_text(0, 0, 512, Window_Base::WLH, text, 0)
  end

  def cg_v190_refresh_detail
    pet = cg_v190_current_pet
    @detail_window.pet = pet
  end

  def cg_v190_refresh_all(selected_id = nil)
    $game_party.cg_prepare_pet_storage_data
    @carry_window.refresh
    @storage_window.refresh
    cg_v190_restore_selection(selected_id) if selected_id != nil
    cg_v190_activate_focus(@focus)
    @detail_window.pet = nil
    cg_v190_refresh_title
    cg_v190_refresh_detail
  end

  def cg_v190_switch_focus
    if @focus == :carry
      cg_v190_activate_focus(:storage)
      @storage_window.index = 0 if @storage_window.index < 0
    else
      cg_v190_activate_focus(:carry)
      @carry_window.index = 0 if @carry_window.index < 0
    end
    Sound.play_cursor
  end

  def cg_v190_update_lists
    if Input.trigger?(Input::B)
      Sound.play_cancel
      $scene = Scene_Map.new
      return
    elsif Input.trigger?(Input::L) || Input.trigger?(Input::R)
      cg_v190_switch_focus
      return
    end

    # 在上下區塊邊界繼續按方向鍵時，自然切換焦點。
    if @focus == :carry && Input.trigger?(Input::DOWN) &&
       @carry_window.index >= ALBERT_CG::SOLO_PET_SLOTS - 1
      cg_v190_activate_focus(:storage)
      @storage_window.index = 0
      Sound.play_cursor
      return
    elsif @focus == :storage && Input.trigger?(Input::UP) &&
       @storage_window.index <= 0
      cg_v190_activate_focus(:carry)
      @carry_window.index = ALBERT_CG::SOLO_PET_SLOTS - 1
      Sound.play_cursor
      return
    end

    return unless Input.trigger?(Input::C)
    pet = cg_v190_current_pet
    if pet == nil
      if @focus == :carry && !@storage_window.data.empty?
        @swap_origin = :carry
        @swap_slot_index = @carry_window.index
        @swap_pet_id = nil
        cg_v190_activate_focus(:storage)
        @storage_window.index = 0
        Sound.play_decision
        cg_v190_refresh_title
      else
        Sound.play_buzzer
      end
      return
    end
    Sound.play_decision
    cg_v190_open_command(pet)
  end

  def cg_v190_open_command(pet)
    @command_window.dispose if @command_window != nil && !@command_window.disposed?
    commands = ["能力配點", "技能資料", "替換", "放生", "取消"]
    @command_window = Window_Command.new(300, commands, 1, 5)
    @command_window.x = 236
    @command_window.y = 254
    @command_window.z = 600
    @command_window.visible = true
    @command_window.active = true
    @command_window.index = 0
    @carry_window.active = false
    @storage_window.active = false
  end

  def cg_v190_close_command
    if @command_window != nil
      @command_window.active = false
      @command_window.index = -1
      @command_window.visible = false
    end
    cg_v190_activate_focus(@focus)
  end

  def cg_v190_update_command
    if Input.trigger?(Input::B)
      Sound.play_cancel
      cg_v190_close_command
      return
    end
    return unless Input.trigger?(Input::C)
    pet = cg_v190_current_pet
    if pet == nil
      Sound.play_buzzer
      cg_v190_close_command
      return
    end
    case @command_window.index
    when 0
      Sound.play_decision
      $scene = Scene_CG_PetGrowth.new(pet.id,
        @focus == :storage ? :storage : :carried)
    when 1
      Sound.play_decision
      $scene = Scene_CG_SkillManager.new(pet.id, :petlab,
        @focus == :storage ? :storage : :carried)
    when 2
      cg_v190_begin_replace(pet)
    when 3
      cg_v190_open_release_confirm(pet)
    when 4
      Sound.play_cancel
      cg_v190_close_command
    end
  end

  def cg_v190_begin_replace(pet)
    if @focus == :carry
      if @storage_window.data.empty?
        Sound.play_buzzer
        return
      end
      @swap_origin = :carry
      @swap_pet_id = pet.id
      @swap_slot_index = @carry_window.index
      cg_v190_activate_focus(:storage)
      @storage_window.index = 0 if @storage_window.index < 0
    else
      @swap_origin = :storage
      @swap_pet_id = pet.id
      cg_v190_activate_focus(:carry)
      @carry_window.index = 0 if @carry_window.index < 0
    end
    @command_window.active = false
    @command_window.index = -1
    @command_window.visible = false
    Sound.play_decision
    cg_v190_refresh_title
  end

  def cg_v190_cancel_replace
    origin = @swap_origin
    @swap_origin = nil
    @swap_pet_id = nil
    @swap_slot_index = nil
    cg_v190_activate_focus(origin == :storage ? :storage : :carry)
    cg_v190_refresh_title
  end

  def cg_v190_update_swap
    if Input.trigger?(Input::B)
      Sound.play_cancel
      cg_v190_cancel_replace
      return
    end
    return unless Input.trigger?(Input::C)

    success = false
    selected_id = nil
    if @swap_origin == :carry
      storage_pet = @storage_window.pet
      if storage_pet != nil
        selected_id = storage_pet.id
        success = $game_party.cg_swap_storage_with_slot(
          @swap_slot_index, storage_pet.id)
      end
    else
      slot = @carry_window.index
      if slot >= 0 && slot < ALBERT_CG::SOLO_PET_SLOTS
        selected_id = @swap_pet_id
        success = $game_party.cg_swap_storage_with_slot(slot, @swap_pet_id)
      end
    end

    if success
      Sound.play_equip
      @swap_origin = nil
      @swap_pet_id = nil
      @swap_slot_index = nil
      cg_v190_refresh_all(selected_id)
    else
      Sound.play_buzzer
    end
  end

  def cg_v190_open_release_confirm(pet)
    @confirm_window.dispose if @confirm_window != nil && !@confirm_window.disposed?
    @confirm_release_pet_id = pet.id
    @confirm_window = Window_Command.new(300,
      ["確定放生 " + pet.name.to_s, "取消"], 1, 2)
    @confirm_window.x = 236
    @confirm_window.y = 302
    @confirm_window.z = 650
    @confirm_window.visible = true
    @confirm_window.active = true
    @confirm_window.index = 1
    @command_window.active = false
  end

  def cg_v190_update_confirm
    if Input.trigger?(Input::B)
      Sound.play_cancel
      @confirm_window.active = false
      @confirm_window.visible = false
      @command_window.active = true
      return
    end
    return unless Input.trigger?(Input::C)
    if @confirm_window.index == 0
      pet_id = @confirm_release_pet_id
      if $game_actors.cg_delete_pet(pet_id)
        Sound.play_decision
        @confirm_window.active = false
        @confirm_window.visible = false
        @command_window.active = false
        @command_window.visible = false
        cg_v190_refresh_all
        cg_v190_activate_focus(@focus)
      else
        Sound.play_buzzer
      end
    else
      Sound.play_cancel
      @confirm_window.active = false
      @confirm_window.visible = false
      @command_window.active = true
    end
  end
end

#==============================================================================
# ■ Scene_Title／Scene_Map／事件 API
#==============================================================================
class Scene_Title < Scene_Base
  alias albert_cg_v190_solo_load_database load_database
  def load_database
    albert_cg_v190_solo_load_database
    ALBERT_CG.apply_solo_party_limits
    ALBERT_CG.apply_solo_title
  end

  alias albert_cg_v190_solo_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v190_solo_load_bt_database
    ALBERT_CG.apply_solo_party_limits
    ALBERT_CG.apply_solo_title
  end
end

class Scene_Map < Scene_Base
  alias albert_cg_v190_solo_map_start start
  def start
    $game_party.cg_solo_prepare_party! if $game_party != nil
    albert_cg_v190_solo_map_start
  end
end

class Game_Interpreter
  def cg_swap_storage_pet_to_slot(slot_index, storage_actor_id)
    return $game_party.cg_swap_storage_with_slot(slot_index, storage_actor_id)
  end
end
