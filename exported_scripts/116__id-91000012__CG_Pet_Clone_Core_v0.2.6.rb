# RMVX_SCRIPT_INDEX: 116
# RMVX_SCRIPT_ID: 91000012
# RMVX_SCRIPT_NAME: CG Pet Clone Core v0.2.6
# RMVX_SOURCE_SHA256: 1a6496ef1eb603bd0c31fac63ba16c3c0e4ae79650ac62733ea84c58efc36bac

#==============================================================================
# 【繁體中文說明】ALBERT CG 寵物個體複製核心
#------------------------------------------------------------------------------
# 【用途】以資料庫 Actor 作為物種模板，建立可獨立升級、命名、學習技能與保存資料的寵物個體。
# 【使用】事件可使用 cg_capture_pet、cg_deploy_pet、cg_recall_pet、cg_release_pet。
# 【寵物分類】Clone Actor 僅供主角可捕捉、可自由換寵的名冊使用。
#  隊友固定寵物改用普通資料庫 Actor，透過 FIXED_PARTNER_PET_ACTORS 或
#  cg_set_fixed_partner_pet 設定，不再把 Clone 寵物綁給隊友。
# 【相容】舊版 Clone 寵物不論主人欄位為何，都會修復回主角自由名冊。
# 【位置】請放在 CG Config 下方，並依專案腳本索引指定順序排列。
#==============================================================================

#==============================================================================
# ** ALBERT CG Pet Clone Core
#------------------------------------------------------------------------------
#  Version : 0.2.6
#------------------------------------------------------------------------------
#  Database Actor = species template.
#  Clone Game_Actor = one persistent pet individual.
#
#  Script calls:
#    pet_id = cg_capture_pet(100, 5, "妙蛙種子", true)
#    cg_deploy_pet(pet_id)
#    cg_recall_pet
#    cg_release_pet(pet_id)
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PetClone"] = true

class Game_Actor < Game_Battler
  attr_reader :cg_model_actor_id
  attr_reader :cg_pet_uid
  attr_reader :cg_capture_level
  attr_reader :cg_capture_map_id
  attr_reader :cg_growth_seed
  attr_reader :cg_grade_loss
  attr_reader :cg_bonus_points
  attr_reader :cg_loyalty
  attr_reader :cg_injury
  attr_reader :cg_skill_slots
  attr_reader :cg_skill_exp
  attr_reader :cg_owner_actor_id
  attr_reader :cg_fixed_owner

  alias albert_cg_v02_actor_initialize initialize
  def initialize(actor_id, model_actor_id = nil)
    @cg_model_actor_id = model_actor_id
    if model_actor_id == nil
      albert_cg_v02_actor_initialize(actor_id)
    else
      albert_cg_v02_actor_initialize(model_actor_id)
      @actor_id = actor_id
      @cg_model_actor_id = model_actor_id
    end
  end

  alias albert_cg_v02_actor_database actor
  def actor
    if @cg_model_actor_id != nil
      return $data_actors[@cg_model_actor_id]
    end
    return albert_cg_v02_actor_database
  end

  def cg_database_actor_id
    return @cg_model_actor_id if @cg_model_actor_id != nil
    return @actor_id
  end

  def cg_species_id
    return cg_database_actor_id
  end

  def cg_pet?
    return @cg_model_actor_id != nil
  end

  # 戰鬥上的「寵物」包含主角 Clone 寵物，以及隊友的固定普通 Actor。
  # 成長、掉檔與個體資料仍只套用於 cg_pet? 為 true 的 Clone。
  def cg_fixed_partner_pet?
    return false if cg_pet?
    return false if $game_party == nil
    return false unless $game_party.respond_to?(:cg_fixed_partner_pet_actor?)
    return $game_party.cg_fixed_partner_pet_actor?(@actor_id)
  end

  def cg_battle_pet?
    return true if cg_pet?
    return cg_fixed_partner_pet?
  end

  def cg_prepare_pet_data
    return unless cg_pet?
    @cg_pet_uid = @actor_id if @cg_pet_uid == nil
    @cg_capture_level = @level if @cg_capture_level == nil
    @cg_capture_map_id = 0 if @cg_capture_map_id == nil
    @cg_growth_seed = rand(2147483647) if @cg_growth_seed == nil
    if @cg_grade_loss == nil or @cg_grade_loss.size != ALBERT_CG::GRADE_STAT_COUNT
      @cg_grade_loss = []
      ALBERT_CG::GRADE_STAT_COUNT.times do
        @cg_grade_loss.push(rand(ALBERT_CG::GRADE_LOSS_MAX + 1))
      end
    end
    if @cg_bonus_points == nil or @cg_bonus_points.size != ALBERT_CG::GRADE_STAT_COUNT
      @cg_bonus_points = Array.new(ALBERT_CG::GRADE_STAT_COUNT, 0)
    end
    @cg_loyalty = ALBERT_CG::DEFAULT_LOYALTY if @cg_loyalty == nil
    @cg_injury = ALBERT_CG::DEFAULT_INJURY if @cg_injury == nil
    @cg_skill_slots = ALBERT_CG::DEFAULT_SKILL_SLOTS if @cg_skill_slots == nil
    @cg_skill_exp = {} if @cg_skill_exp == nil
    if @cg_owner_actor_id == nil
      @cg_owner_actor_id = ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    end
    @cg_fixed_owner = false if @cg_fixed_owner == nil
  end

  # Skill-use EXP is stored separately from pet-only growth data.
  # Human actors also inherit this class, so this hash must be safe even when
  # cg_prepare_pet_data returns early for a non-pet actor.
  def cg_prepare_skill_exp_data
    @cg_skill_exp = {} if @cg_skill_exp == nil
    return @cg_skill_exp
  end

  def cg_setup_pet_data(level = nil, owner_actor_id = nil)
    return unless cg_pet?
    @cg_pet_uid = @actor_id
    @cg_capture_level = level == nil ? @level : level
    @cg_capture_map_id = $game_map == nil ? 0 : $game_map.map_id
    @cg_growth_seed = rand(2147483647)
    @cg_grade_loss = []
    ALBERT_CG::GRADE_STAT_COUNT.times do
      @cg_grade_loss.push(rand(ALBERT_CG::GRADE_LOSS_MAX + 1))
    end
    @cg_bonus_points = Array.new(ALBERT_CG::GRADE_STAT_COUNT, 0)
    @cg_loyalty = ALBERT_CG::DEFAULT_LOYALTY
    @cg_injury = ALBERT_CG::DEFAULT_INJURY
    @cg_skill_slots = ALBERT_CG::DEFAULT_SKILL_SLOTS
    @cg_skill_exp = {}
    owner_actor_id = ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID if owner_actor_id == nil
    @cg_owner_actor_id = owner_actor_id.to_i
    @cg_fixed_owner = (@cg_owner_actor_id != ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID)
    change_level(level, false) if level != nil
    recover_all
  end

  # 取得寵物主人 Actor ID。舊存檔沒有此資料時，自動歸給主角。
  def cg_owner_actor_id
    cg_prepare_pet_data
    return @cg_owner_actor_id
  end

  # 重新綁定主人。只接受資料庫人物 Actor ID，不接受寵物個體 ID。
  # 此 setter 只改主人 ID；是否為隊友固定寵物由 cg_fixed_owner 另行保存。
  def cg_owner_actor_id=(actor_id)
    return unless cg_pet?
    @cg_owner_actor_id = actor_id.to_i
  end

  # 固定主人=true：此寵物屬於指定隊友，不進入主角自由換寵名冊。
  def cg_fixed_owner?
    cg_prepare_pet_data
    return @cg_fixed_owner == true
  end

  def cg_fixed_owner=(value)
    return unless cg_pet?
    @cg_fixed_owner = (value == true)
  end

  def cg_assign_owner(actor_id, fixed = false)
    return false unless cg_pet?
    @cg_owner_actor_id = actor_id.to_i
    @cg_fixed_owner = (fixed == true)
    return true
  end

  def cg_owned_by_actor?(actor_or_id)
    actor_id = actor_or_id.respond_to?(:id) ? actor_or_id.id : actor_or_id.to_i
    return cg_owner_actor_id == actor_id
  end

  def cg_loyalty
    cg_prepare_pet_data
    return @cg_loyalty
  end

  def cg_loyalty=(value)
    @cg_loyalty = [[value.to_i, 0].max, 100].min
  end

  def cg_injury
    cg_prepare_pet_data
    return @cg_injury
  end

  def cg_injury=(value)
    @cg_injury = [value.to_i, 0].max
  end

  def cg_skill_slots
    cg_prepare_pet_data
    return @cg_skill_slots
  end

  def cg_skill_slots=(value)
    @cg_skill_slots = [value.to_i, 1].max
  end

  def cg_grade_loss_at(index)
    cg_prepare_pet_data
    return 0 if index < 0 or index >= @cg_grade_loss.size
    return @cg_grade_loss[index]
  end

  def cg_bonus_point(index)
    cg_prepare_pet_data
    return 0 if index < 0 or index >= @cg_bonus_points.size
    return @cg_bonus_points[index]
  end

  def cg_add_bonus_point(index, amount = 1)
    return false unless cg_pet?
    return false if index < 0 or index >= ALBERT_CG::GRADE_STAT_COUNT
    cg_prepare_pet_data
    @cg_bonus_points[index] += amount.to_i
    return true
  end

  def cg_adjust_pet_parameter(value, grade_index, bonus_rate)
    return value unless cg_pet?
    cg_prepare_pet_data
    rate = 100 - cg_grade_loss_at(grade_index) * 2
    result = value * rate / 100
    result += cg_bonus_point(grade_index) * bonus_rate
    return [result, 1].max
  end

  alias albert_cg_v02_base_maxhp base_maxhp
  def base_maxhp
    return cg_adjust_pet_parameter(albert_cg_v02_base_maxhp, 0, 5)
  end

  alias albert_cg_v02_base_maxmp base_maxmp
  def base_maxmp
    return cg_adjust_pet_parameter(albert_cg_v02_base_maxmp, 4, 3)
  end

  alias albert_cg_v02_base_atk base_atk
  def base_atk
    return cg_adjust_pet_parameter(albert_cg_v02_base_atk, 1, 1)
  end

  alias albert_cg_v02_base_def base_def
  def base_def
    return cg_adjust_pet_parameter(albert_cg_v02_base_def, 2, 1)
  end

  alias albert_cg_v02_base_spi base_spi
  def base_spi
    return cg_adjust_pet_parameter(albert_cg_v02_base_spi, 4, 1)
  end

  alias albert_cg_v02_base_agi base_agi
  def base_agi
    return cg_adjust_pet_parameter(albert_cg_v02_base_agi, 3, 1)
  end

  def cg_skill_exp_for(skill_id)
    return 0 if skill_id == nil
    cg_prepare_skill_exp_data
    skill_id = skill_id.to_i
    value = @cg_skill_exp[skill_id]
    return value == nil ? 0 : value
  end

  def cg_gain_skill_exp(skill_id, amount)
    return 0 if skill_id == nil
    cg_prepare_skill_exp_data
    skill_id = skill_id.to_i
    @cg_skill_exp[skill_id] = cg_skill_exp_for(skill_id) + amount.to_i
    @cg_skill_exp[skill_id] = 0 if @cg_skill_exp[skill_id] < 0
    return @cg_skill_exp[skill_id]
  end
end

class Game_Actors
  attr_reader :cg_clone_ids

  alias albert_cg_v02_actors_initialize initialize
  def initialize
    albert_cg_v02_actors_initialize
    @cg_next_clone_id = ALBERT_CG::PET_ACTOR_ID_START
    @cg_clone_ids = []
  end

  def cg_prepare_clone_data
    @cg_next_clone_id = ALBERT_CG::PET_ACTOR_ID_START if @cg_next_clone_id == nil
    @cg_clone_ids = [] if @cg_clone_ids == nil
  end

  def cg_next_available_clone_id
    cg_prepare_clone_data
    actor_id = @cg_next_clone_id
    while @data[actor_id] != nil or $data_actors[actor_id] != nil
      actor_id += 1
    end
    return actor_id
  end

  def cg_create_pet(model_actor_id, level = nil, custom_name = nil, owner_actor_id = nil)
    cg_prepare_clone_data
    return nil if model_actor_id == nil
    return nil if $data_actors[model_actor_id] == nil
    clone_id = cg_next_available_clone_id
    pet = Game_Actor.new(clone_id, model_actor_id)
    pet.cg_setup_pet_data(level, owner_actor_id)
    if custom_name != nil and custom_name.to_s != ""
      pet.name = custom_name.to_s
    end
    @data[clone_id] = pet
    @cg_clone_ids.push(clone_id)
    @cg_next_clone_id = clone_id + 1
    return pet
  end

  def cg_pet(actor_id)
    cg_prepare_clone_data
    actor = @data[actor_id]
    return nil if actor == nil
    return nil unless actor.respond_to?(:cg_pet?)
    return nil unless actor.cg_pet?
    actor.cg_prepare_pet_data
    @cg_clone_ids.push(actor_id) unless @cg_clone_ids.include?(actor_id)
    return actor
  end

  def cg_delete_pet(actor_id)
    cg_prepare_clone_data
    pet = cg_pet(actor_id)
    return false if pet == nil
    $game_party.cg_remove_pet_references(actor_id) if $game_party != nil
    @data[actor_id] = nil
    @cg_clone_ids.delete(actor_id)
    return true
  end

  def cg_all_pets
    cg_prepare_clone_data
    result = []
    for actor_id in @cg_clone_ids
      pet = cg_pet(actor_id)
      result.push(pet) if pet != nil
    end
    return result
  end
end

class Game_Party < Game_Unit
  alias albert_cg_v026_party_initialize initialize
  def initialize
    albert_cg_v026_party_initialize
    @cg_owned_pet_ids = []
    @cg_active_pet_id = nil
    @cg_active_pet_ids_by_owner = {}
    @cg_fixed_partner_pet_map = {}
  end

  #--------------------------------------------------------------------------
  # ● 隊友固定寵物資料
  #--------------------------------------------------------------------------
  # 固定寵物是普通資料庫 Actor，不是 Clone，也不會出現在主角換寵名冊。
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
    return cg_prepare_fixed_partner_pet_data[owner_id]
  end

  def cg_fixed_partner_owner_id_for(pet_actor_or_id)
    pet_id = pet_actor_or_id.respond_to?(:id) ? pet_actor_or_id.id : pet_actor_or_id.to_i
    for owner_id in cg_prepare_fixed_partner_pet_data.keys
      return owner_id if cg_prepare_fixed_partner_pet_data[owner_id] == pet_id
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

  # 設定隊友固定寵物。deploy=true 且主人已在隊伍時，立即把普通 Actor 寵物加入。
  def cg_set_fixed_partner_pet(owner_actor_id, pet_actor_id, deploy = true)
    owner_id = owner_actor_id.to_i
    pet_id = pet_actor_id.to_i
    return false if owner_id <= 0 or pet_id <= 0 or owner_id == pet_id
    return false if $data_actors == nil
    return false if $data_actors[owner_id] == nil or $data_actors[pet_id] == nil
    @cg_fixed_partner_pet_map = {} if @cg_fixed_partner_pet_map == nil
    old_pet_id = @cg_fixed_partner_pet_map[owner_id]
    if old_pet_id != nil && old_pet_id != pet_id
      remove_actor(old_pet_id)
    end
    @cg_fixed_partner_pet_map[owner_id] = pet_id
    owner = $game_actors[owner_id]
    if deploy && owner != nil && members.include?(owner)
      add_actor(pet_id)
    end
    return true
  end

  # 讓已在隊伍的人物自動帶入其固定普通 Actor 寵物。
  def cg_sync_fixed_partner_pet(owner_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i
    pet_id = cg_fixed_partner_pet_actor_id(owner_id)
    return false if pet_id == nil
    owner = $game_actors[owner_id]
    pet = $game_actors[pet_id]
    return false if owner == nil or pet == nil
    return false unless members.include?(owner)
    add_actor(pet_id) unless members.include?(pet)
    return members.include?(pet)
  end

  alias albert_cg_v026_add_actor add_actor
  def add_actor(actor_id)
    albert_cg_v026_add_actor(actor_id)
    return if @cg_syncing_fixed_partner
    @cg_syncing_fixed_partner = true
    cg_sync_fixed_partner_pet(actor_id)
    @cg_syncing_fixed_partner = false
  end

  alias albert_cg_v026_remove_actor remove_actor
  def remove_actor(actor_id)
    pet_id = cg_fixed_partner_pet_actor_id(actor_id)
    albert_cg_v026_remove_actor(actor_id)
    if pet_id != nil && !@cg_syncing_fixed_partner
      @cg_syncing_fixed_partner = true
      albert_cg_v026_remove_actor(pet_id)
      @cg_syncing_fixed_partner = false
    end
  end

  #--------------------------------------------------------------------------
  # ● 主角 Clone 寵物名冊
  #--------------------------------------------------------------------------
  # Clone 寵物全部屬於主角自由名冊。舊版主人欄位一律修復回主角，避免
  # 主人資料損壞導致 F5 看得到、戰鬥換寵卻完全找不到候補。
  def cg_normalize_pet_owners!
    @cg_owned_pet_ids = [] if @cg_owned_pet_ids == nil
    primary = ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    for pet_id in @cg_owned_pet_ids
      pet = $game_actors.cg_pet(pet_id)
      next if pet == nil
      pet.cg_assign_owner(primary, false)
    end
    return true
  end

  def cg_prepare_party_pet_data
    @cg_owned_pet_ids = [] if @cg_owned_pet_ids == nil
    @cg_active_pet_ids_by_owner = {} if @cg_active_pet_ids_by_owner == nil
    cg_normalize_pet_owners!
    primary = ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID

    # 舊版單一欄位若有效，先搬回主角對應。
    if @cg_active_pet_id != nil
      pet = $game_actors.cg_pet(@cg_active_pet_id)
      if pet != nil && @cg_owned_pet_ids.include?(pet.id) && members.include?(pet)
        @cg_active_pet_ids_by_owner[primary] = pet.id
      else
        @cg_active_pet_id = nil
      end
    end

    # 主角實際在隊伍中的第一隻 Clone 寵物才是出戰寵物。
    active = nil
    for member in members
      next unless member.respond_to?(:cg_pet?) && member.cg_pet?
      next unless @cg_owned_pet_ids.include?(member.id)
      active = member
      break
    end
    if active == nil
      @cg_active_pet_ids_by_owner.delete(primary)
      @cg_active_pet_id = nil
    else
      @cg_active_pet_ids_by_owner[primary] = active.id
      @cg_active_pet_id = active.id
    end
    return true
  end

  def cg_owned_pet_ids
    cg_prepare_party_pet_data
    return @cg_owned_pet_ids
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
    cg_normalize_pet_owners!
    return cg_owned_pets
  end

  def cg_pets_owned_by(owner_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i
    return [] unless owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    return cg_owned_pets
  end

  def cg_active_pet_id(owner_actor_id = nil)
    cg_prepare_party_pet_data
    owner_actor_id = ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID if owner_actor_id == nil
    owner_id = owner_actor_id.to_i
    if owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
      return @cg_active_pet_id
    end
    pet_id = cg_fixed_partner_pet_actor_id(owner_id)
    pet = pet_id == nil ? nil : $game_actors[pet_id]
    return nil if pet == nil or !members.include?(pet)
    return pet_id
  end

  def cg_active_pet(owner_actor_id = nil)
    pet_id = cg_active_pet_id(owner_actor_id)
    return nil if pet_id == nil
    clone_pet = $game_actors.cg_pet(pet_id)
    return clone_pet if clone_pet != nil
    return $game_actors[pet_id]
  end

  def cg_active_pet_for(human)
    return nil if human == nil
    fixed_id = cg_fixed_partner_pet_actor_id(human.id)
    if fixed_id != nil
      pet = $game_actors[fixed_id]
      return pet if pet != nil && members.include?(pet)
    end
    return cg_active_pet(human.id)
  end

  def cg_active_pets
    cg_prepare_party_pet_data
    result = []
    clone_pet = cg_active_pet(ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID)
    result.push(clone_pet) if clone_pet != nil
    for owner_id in cg_prepare_fixed_partner_pet_data.keys
      pet = cg_active_pet(owner_id)
      result.push(pet) if pet != nil && !result.include?(pet)
    end
    return result
  end

  def cg_primary_pet_handler?(actor_or_id)
    actor_id = actor_or_id.respond_to?(:id) ? actor_or_id.id : actor_or_id.to_i
    return actor_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
  end

  def cg_register_pet(actor_id, owner_actor_id = nil, fixed_owner = nil)
    pet = $game_actors.cg_pet(actor_id)
    return false if pet == nil
    pet.cg_assign_owner(ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID, false)
    @cg_owned_pet_ids = [] if @cg_owned_pet_ids == nil
    @cg_owned_pet_ids.push(actor_id) unless @cg_owned_pet_ids.include?(actor_id)
    return true
  end

  def cg_deploy_pet(actor_id, owner_actor_id = nil)
    cg_prepare_party_pet_data
    return false unless @cg_owned_pet_ids.include?(actor_id)
    pet = $game_actors.cg_pet(actor_id)
    return false if pet == nil
    old_id = @cg_active_pet_id
    remove_actor(old_id) if old_id != nil && old_id != actor_id
    add_actor(actor_id)
    return false unless members.include?(pet)
    @cg_active_pet_id = actor_id
    @cg_active_pet_ids_by_owner[ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID] = actor_id
    return true
  end

  def cg_recall_pet(owner_actor_id = nil)
    cg_prepare_party_pet_data
    owner_id = owner_actor_id == nil ? ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID :
      (owner_actor_id.respond_to?(:id) ? owner_actor_id.id : owner_actor_id.to_i)
    return false unless owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    pet_id = @cg_active_pet_id
    return false if pet_id == nil
    remove_actor(pet_id)
    @cg_active_pet_id = nil
    @cg_active_pet_ids_by_owner.delete(owner_id)
    return true
  end

  def cg_remove_pet_references(actor_id)
    @cg_owned_pet_ids = [] if @cg_owned_pet_ids == nil
    @cg_owned_pet_ids.delete(actor_id)
    remove_actor(actor_id)
    @cg_active_pet_ids_by_owner = {} if @cg_active_pet_ids_by_owner == nil
    for owner_id in @cg_active_pet_ids_by_owner.keys.clone
      @cg_active_pet_ids_by_owner.delete(owner_id) if @cg_active_pet_ids_by_owner[owner_id] == actor_id
    end
    @cg_active_pet_id = nil if @cg_active_pet_id == actor_id
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

class Game_Interpreter
  def cg_capture_pet(model_actor_id, level = nil, custom_name = nil, deploy = false, owner_actor_id = nil)
    owner_actor_id = ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID if owner_actor_id == nil
    pet = $game_actors.cg_create_pet(model_actor_id, level, custom_name, owner_actor_id)
    return 0 if pet == nil
    $game_party.cg_register_pet(pet.id, owner_actor_id)
    $game_party.cg_deploy_pet(pet.id, owner_actor_id) if deploy
    variable_id = ALBERT_CG::LAST_CREATED_PET_VARIABLE
    if variable_id != nil and variable_id > 0
      $game_variables[variable_id] = pet.id
    end
    return pet.id
  end

  def cg_deploy_pet(actor_id, owner_actor_id = nil)
    return $game_party.cg_deploy_pet(actor_id, owner_actor_id)
  end

  def cg_recall_pet(owner_actor_id = nil)
    return $game_party.cg_recall_pet(owner_actor_id)
  end

  # 舊版相容：Clone 寵物只能回到主角自由名冊。
  # 隊友固定寵物請改用 cg_set_fixed_partner_pet。
  def cg_set_pet_owner(actor_id, owner_actor_id, auto_deploy = nil)
    pet = $game_actors.cg_pet(actor_id)
    return false if pet == nil
    pet.cg_assign_owner(ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID, false)
    $game_party.cg_register_pet(pet.id)
    deploy = auto_deploy == true && owner_actor_id.to_i == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    return $game_party.cg_deploy_pet(pet.id) if deploy
    return true
  end

  # 設定隊友固定普通 Actor 寵物。參數順序：主人 Actor ID、寵物 Actor ID。
  # 例：cg_set_fixed_partner_pet(2, 103, true)
  def cg_set_fixed_partner_pet(owner_actor_id, pet_actor_id, deploy = true)
    return $game_party.cg_set_fixed_partner_pet(owner_actor_id, pet_actor_id, deploy)
  end

  def cg_assign_fixed_pet(pet_actor_id, owner_actor_id, deploy = true)
    return cg_set_fixed_partner_pet(owner_actor_id, pet_actor_id, deploy)
  end

  def cg_release_pet(actor_id)
    return $game_actors.cg_delete_pet(actor_id)
  end
end
