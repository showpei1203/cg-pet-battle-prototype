# RMVX_SCRIPT_INDEX: 137
# RMVX_SCRIPT_ID: 98941055
# RMVX_SCRIPT_NAME: CG Pet Storage v0.7.1
# RMVX_SOURCE_SHA256: a98113db4ee4194e662ff2686fa5d3b9e40b5be0069a7d744e587b13d96fb2a7

#==============================================================================
# 【繁體中文說明】ALBERT CG 寵物攜帶／倉庫系統
#------------------------------------------------------------------------------
# 【版本】v0.7.1
# 【用途】
#  將主角捕捉的 Clone 寵物分成「攜帶名冊」與「寵物倉庫」。
#  戰鬥中只能派出攜帶中的寵物；超過攜帶上限的新捕捉個體會自動送入倉庫。
#
# 【重要規則】
#  1. 主角可攜帶寵物上限：PET_CARRY_LIMIT，預設 5 隻。
#  2. 倉庫上限：PET_STORAGE_LIMIT，預設 100 隻。
#  3. 隊友固定普通 Actor 寵物不屬於主角倉庫，也不占主角攜帶上限。
#  4. F5 開啟寵物管理；L／R 切換「攜帶」與「倉庫」。
#  5. 出戰寵物存入倉庫時會先自動收回。
#  6. 攜帶已滿時，從倉庫取出會要求選擇一隻攜帶寵物交換。
#  7. 戰鬥換寵選單只會列出攜帶中的候補寵物。
#  8. 捕捉成功後，若攜帶未滿則加入攜帶；否則自動送入倉庫。
#  9. 捕捉個體名稱直接使用物種 Actor 的資料庫名稱，不加 A／B／C 後綴。
#
# 【事件指令】
#    $scene = Scene_CG_PetLab.new       # 開啟寵物管理
#    cg_store_pet(個體ID)               # 存入倉庫
#    cg_withdraw_pet(個體ID)            # 從倉庫取出
#    cg_swap_pet_storage(攜帶ID, 倉庫ID) # 交換
#
# 【腳本位置】
#  請放在所有 CG 戰鬥／捕捉修正腳本下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PetStorage"] = true

module ALBERT_CG
  PET_STORAGE_VERSION = "0.7.1"
  PET_CARRY_LIMIT = 5 unless const_defined?(:PET_CARRY_LIMIT)
  PET_STORAGE_LIMIT = 100 unless const_defined?(:PET_STORAGE_LIMIT)
end

#==============================================================================
# ■ Game_Party
#==============================================================================
class Game_Party < Game_Unit
  # 新捕捉／事件建立寵物仍先走既有註冊，再由倉庫權威層決定去向。
  alias albert_cg_v07_register_pet cg_register_pet
  def cg_register_pet(actor_id, owner_actor_id = nil, fixed_owner = nil)
    result = albert_cg_v07_register_pet(actor_id, owner_actor_id, fixed_owner)
    return false unless result
    cg_prepare_pet_storage_data
    pet_id = actor_id.to_i
    unless @cg_carried_pet_ids.include?(pet_id) || @cg_storage_pet_ids.include?(pet_id)
      if @cg_carried_pet_ids.size < ALBERT_CG::PET_CARRY_LIMIT
        @cg_carried_pet_ids.push(pet_id)
        @cg_last_pet_destination = :carried
      elsif @cg_storage_pet_ids.size < ALBERT_CG::PET_STORAGE_LIMIT
        @cg_storage_pet_ids.push(pet_id)
        @cg_last_pet_destination = :storage
      else
        @cg_last_pet_destination = :full
        return false
      end
    else
      @cg_last_pet_destination = cg_pet_location(pet_id)
    end
    return true
  end

  alias albert_cg_v07_remove_pet_references cg_remove_pet_references
  def cg_remove_pet_references(actor_id)
    pet_id = actor_id.to_i
    @cg_carried_pet_ids.delete(pet_id) if @cg_carried_pet_ids != nil
    @cg_storage_pet_ids.delete(pet_id) if @cg_storage_pet_ids != nil
    return albert_cg_v07_remove_pet_references(actor_id)
  end

  #--------------------------------------------------------------------------
  # ● 倉庫資料初始化與舊存檔移轉
  #--------------------------------------------------------------------------
  def cg_prepare_pet_storage_data
    return true if @cg_v07_preparing_storage
    @cg_v07_preparing_storage = true

    first_setup = (@cg_carried_pet_ids == nil && @cg_storage_pet_ids == nil)
    @cg_carried_pet_ids = [] if @cg_carried_pet_ids == nil
    @cg_storage_pet_ids = [] if @cg_storage_pet_ids == nil

    all_ids = cg_owned_pet_ids.clone
    all_ids = all_ids.collect { |id| id.to_i }
    all_ids.delete_if { |id| $game_actors.cg_pet(id) == nil }

    @cg_carried_pet_ids.delete_if { |id| !all_ids.include?(id.to_i) }
    @cg_storage_pet_ids.delete_if { |id| !all_ids.include?(id.to_i) }
    @cg_carried_pet_ids = @cg_carried_pet_ids.collect { |id| id.to_i }.uniq
    @cg_storage_pet_ids = @cg_storage_pet_ids.collect { |id| id.to_i }.uniq
    @cg_storage_pet_ids.delete_if { |id| @cg_carried_pet_ids.include?(id) }

    active = respond_to?(:cg_actual_primary_clone_pet) ? cg_actual_primary_clone_pet : nil
    active_id = active == nil ? nil : active.id

    if first_setup
      ordered = all_ids.clone
      if active_id != nil && ordered.include?(active_id)
        ordered.delete(active_id)
        ordered.unshift(active_id)
      end
      # RGSS2 使用 Ruby 1.8，Array#shift 不接受數量參數。
      # 改用區段讀取，避免 New Game 初始化時發生 ArgumentError。
      carry_limit = ALBERT_CG::PET_CARRY_LIMIT
      storage_limit = ALBERT_CG::PET_STORAGE_LIMIT
      @cg_carried_pet_ids = ordered[0, carry_limit] || []
      remaining = ordered[carry_limit, ordered.size] || []
      @cg_storage_pet_ids = remaining[0, storage_limit] || []
    else
      missing = all_ids - @cg_carried_pet_ids - @cg_storage_pet_ids
      for pet_id in missing
        if @cg_carried_pet_ids.size < ALBERT_CG::PET_CARRY_LIMIT
          @cg_carried_pet_ids.push(pet_id)
        elsif @cg_storage_pet_ids.size < ALBERT_CG::PET_STORAGE_LIMIT
          @cg_storage_pet_ids.push(pet_id)
        end
      end
    end

    # 目前出戰寵物必須屬於攜帶名冊。
    if active_id != nil && !@cg_carried_pet_ids.include?(active_id)
      @cg_storage_pet_ids.delete(active_id)
      if @cg_carried_pet_ids.size >= ALBERT_CG::PET_CARRY_LIMIT
        move_id = @cg_carried_pet_ids.reverse.find { |id| id != active_id }
        if move_id != nil
          @cg_carried_pet_ids.delete(move_id)
          @cg_storage_pet_ids.unshift(move_id)
        end
      end
      @cg_carried_pet_ids.unshift(active_id)
    end

    # 超過攜帶上限時，優先保留出戰寵物，其餘送入倉庫。
    while @cg_carried_pet_ids.size > ALBERT_CG::PET_CARRY_LIMIT
      move_id = @cg_carried_pet_ids.reverse.find { |id| id != active_id }
      break if move_id == nil
      @cg_carried_pet_ids.delete(move_id)
      @cg_storage_pet_ids.unshift(move_id) unless @cg_storage_pet_ids.include?(move_id)
    end
    @cg_storage_pet_ids = @cg_storage_pet_ids[0, ALBERT_CG::PET_STORAGE_LIMIT]

    # 倉庫寵物不可留在實際隊伍中。
    if @actors != nil
      changed = false
      for pet_id in @cg_storage_pet_ids
        if @actors.include?(pet_id)
          @actors.delete(pet_id)
          changed = true
        end
      end
      if changed
        cg_v056_refresh_active_cache if respond_to?(:cg_v056_refresh_active_cache)
        cg_v056_party_changed if respond_to?(:cg_v056_party_changed)
      end
    end

    @cg_v07_preparing_storage = false
    return true
  end

  def cg_carried_pet_ids
    cg_prepare_pet_storage_data
    return @cg_carried_pet_ids
  end

  def cg_storage_pet_ids
    cg_prepare_pet_storage_data
    return @cg_storage_pet_ids
  end

  def cg_carried_pets
    result = []
    for pet_id in cg_carried_pet_ids
      pet = $game_actors.cg_pet(pet_id)
      result.push(pet) if pet != nil
    end
    return result
  end

  def cg_storage_pets
    result = []
    for pet_id in cg_storage_pet_ids
      pet = $game_actors.cg_pet(pet_id)
      result.push(pet) if pet != nil
    end
    return result
  end

  def cg_pet_location(actor_id)
    pet_id = actor_id.to_i
    return :carried if cg_carried_pet_ids.include?(pet_id)
    return :storage if cg_storage_pet_ids.include?(pet_id)
    return nil
  end

  def cg_last_pet_destination
    return @cg_last_pet_destination
  end

  def cg_carry_full?
    return cg_carried_pet_ids.size >= ALBERT_CG::PET_CARRY_LIMIT
  end

  def cg_storage_full?
    return cg_storage_pet_ids.size >= ALBERT_CG::PET_STORAGE_LIMIT
  end

  #--------------------------------------------------------------------------
  # ● 存入、取出、交換
  #--------------------------------------------------------------------------
  def cg_store_pet(actor_id)
    cg_prepare_pet_storage_data
    pet_id = actor_id.to_i
    return false unless @cg_carried_pet_ids.include?(pet_id)
    return false if cg_storage_full?

    active = respond_to?(:cg_actual_primary_clone_pet) ? cg_actual_primary_clone_pet : nil
    if active != nil && active.id == pet_id
      return false unless cg_map_recall_pet
    elsif @actors != nil && @actors.include?(pet_id)
      if respond_to?(:cg_v056_raw_remove_actor)
        cg_v056_raw_remove_actor(pet_id, false)
      else
        @actors.delete(pet_id)
      end
    end

    @cg_carried_pet_ids.delete(pet_id)
    @cg_storage_pet_ids.push(pet_id) unless @cg_storage_pet_ids.include?(pet_id)
    cg_v056_refresh_active_cache if respond_to?(:cg_v056_refresh_active_cache)
    cg_v056_party_changed if respond_to?(:cg_v056_party_changed)
    return true
  end

  def cg_withdraw_pet(actor_id)
    cg_prepare_pet_storage_data
    pet_id = actor_id.to_i
    return false unless @cg_storage_pet_ids.include?(pet_id)
    return false if cg_carry_full?
    @cg_storage_pet_ids.delete(pet_id)
    @cg_carried_pet_ids.push(pet_id) unless @cg_carried_pet_ids.include?(pet_id)
    return true
  end

  def cg_swap_pet_storage(carried_actor_id, storage_actor_id)
    cg_prepare_pet_storage_data
    carried_id = carried_actor_id.to_i
    storage_id = storage_actor_id.to_i
    return false unless @cg_carried_pet_ids.include?(carried_id)
    return false unless @cg_storage_pet_ids.include?(storage_id)

    active = respond_to?(:cg_actual_primary_clone_pet) ? cg_actual_primary_clone_pet : nil
    if active != nil && active.id == carried_id
      return false unless cg_map_recall_pet
    end

    carried_index = @cg_carried_pet_ids.index(carried_id)
    storage_index = @cg_storage_pet_ids.index(storage_id)
    @cg_carried_pet_ids[carried_index] = storage_id
    @cg_storage_pet_ids[storage_index] = carried_id
    return true
  end

  #--------------------------------------------------------------------------
  # ● 地圖／戰鬥只允許使用攜帶寵物
  #--------------------------------------------------------------------------
  alias albert_cg_v07_map_deploy_pet cg_map_deploy_pet
  def cg_map_deploy_pet(actor_id)
    return false unless cg_carried_pet_ids.include?(actor_id.to_i)
    return albert_cg_v07_map_deploy_pet(actor_id)
  end

  def cg_primary_pet_pool
    return cg_carried_pets
  end

  def cg_pets_owned_by(owner_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i
    return [] unless owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    return cg_carried_pets
  end

  def cg_battle_reserve_pets(owner_actor_or_id = nil)
    owner_id = owner_actor_or_id == nil ? ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID :
      (owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i)
    return [] unless owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    active = respond_to?(:cg_actual_primary_clone_pet) ? cg_actual_primary_clone_pet : nil
    result = []
    for pet in cg_carried_pets
      next if active != nil && active.id == pet.id
      result.push(pet)
    end
    return result
  end

  def cg_battle_switchable_pet?(actor_id, owner_actor_or_id = nil)
    owner_id = owner_actor_or_id == nil ? ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID :
      (owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i)
    return false unless owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    pet_id = actor_id.to_i
    return false unless cg_carried_pet_ids.include?(pet_id)
    pet = $game_actors.cg_pet(pet_id)
    return false if pet == nil || !pet.exist?
    active = respond_to?(:cg_actual_primary_clone_pet) ? cg_actual_primary_clone_pet : nil
    return false if active != nil && active.id == pet_id
    return true
  end

  def cg_owner_pet_management_available?(owner_actor_or_id)
    owner_id = owner_actor_or_id.respond_to?(:id) ? owner_actor_or_id.id : owner_actor_or_id.to_i
    if owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
      return !cg_carried_pet_ids.empty?
    end
    pet_id = respond_to?(:cg_fixed_partner_pet_actor_id) ?
      cg_fixed_partner_pet_actor_id(owner_id) : nil
    return pet_id != nil
  end
end

#==============================================================================
# ■ 捕捉名稱與去向
#==============================================================================
class Scene_Battle < Scene_Base
  alias albert_cg_v07_create_captured_pet cg_create_captured_pet
  def cg_create_captured_pet(enemy)
    pet = albert_cg_v07_create_captured_pet(enemy)
    if pet != nil
      template = $data_actors[pet.cg_species_id]
      pet.name = template.name.to_s if template != nil
      $game_party.cg_prepare_pet_storage_data
      @cg_v07_capture_destination = $game_party.cg_pet_location(pet.id)
    end
    return pet
  end

  alias albert_cg_v07_show_special_action_text cg_show_special_action_text
  def cg_show_special_action_text(text, duration = 45)
    if @cg_v07_capture_destination != nil && text.to_s.include?("成功捕捉")
      destination_text = @cg_v07_capture_destination == :storage ?
        "　已送入寵物倉庫。" : "　已加入攜帶名冊。"
      text = text.to_s + destination_text
      @cg_v07_capture_destination = nil
    end
    return albert_cg_v07_show_special_action_text(text, duration)
  end
end

#==============================================================================
# ■ 寵物管理視窗
#==============================================================================
class Window_CG_PetList < Window_Selectable
  attr_reader :mode

  def initialize(mode = :carried)
    @mode = mode
    super(0, 56, 240, 360)
    @column_max = 1
    refresh
    self.index = 0
  end

  def mode=(value)
    value = :storage unless value == :carried
    return if @mode == value
    @mode = value
    refresh
    self.index = 0
  end

  def pet
    return nil if @data == nil || @data.empty?
    return @data[self.index]
  end

  def refresh
    @data = @mode == :storage ? $game_party.cg_storage_pets : $game_party.cg_carried_pets
    @item_max = [@data.size, 1].max
    create_contents
    if @data.empty?
      text = @mode == :storage ? "倉庫目前沒有寵物" : "目前沒有攜帶寵物"
      self.contents.draw_text(4, 0, contents.width - 8, WLH, text)
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
    active = false
    if @mode == :carried
      current = $game_party.respond_to?(:cg_actual_primary_clone_pet) ?
        $game_party.cg_actual_primary_clone_pet : nil
      active = current != nil && current.id == pet.id
    end
    prefix = active ? "◆ " : "　"
    self.contents.draw_text(rect.x, rect.y, rect.width - 52, WLH,
                            prefix + pet.name.to_s)
    self.contents.draw_text(rect.x + rect.width - 56, rect.y, 52, WLH,
                            "Lv." + pet.level.to_s, 2)
  end
end

#==============================================================================
# ■ 寵物管理場景
#==============================================================================
class Scene_CG_PetLab < Scene_Base
  def start
    super
    $game_party.cg_prepare_pet_storage_data
    create_menu_background
    @mode = :carried
    @swap_mode = false
    @pending_storage_pet_id = nil
    @title_window = Window_Base.new(0, 0, 544, 56)
    @pet_window = Window_CG_PetList.new(@mode)
    @detail_window = Window_CG_PetDetail.new
    @command_window = nil
    rebuild_command_window
    refresh_title
    refresh_detail
  end

  def terminate
    super
    dispose_menu_background
    @title_window.dispose if @title_window != nil
    @pet_window.dispose if @pet_window != nil
    @detail_window.dispose if @detail_window != nil
    @command_window.dispose if @command_window != nil
  end

  def update
    super
    update_menu_background
    @pet_window.update
    @command_window.update if @command_window != nil
    if @command_window != nil && @command_window.active
      update_command
    else
      update_pet_list
    end
    refresh_detail
  end

  def refresh_title
    @title_window.contents.clear
    @title_window.contents.font.size = 18
    if @swap_mode
      text = "選擇要存入倉庫的攜帶寵物　C：交換　B：取消"
    else
      carry = $game_party.cg_carried_pet_ids.size
      storage = $game_party.cg_storage_pet_ids.size
      tab = @mode == :carried ? "【攜帶】" : "【倉庫】"
      text = tab + " " + carry.to_s + "/" + ALBERT_CG::PET_CARRY_LIMIT.to_s +
        "　倉庫 " + storage.to_s + "/" + ALBERT_CG::PET_STORAGE_LIMIT.to_s +
        "　L/R：切換　C：操作　B：返回"
    end
    @title_window.contents.draw_text(0, 0, 512, Window_Base::WLH, text)
  end

  def refresh_detail
    @detail_window.pet = @pet_window.pet
  end

  def rebuild_command_window
    old_active = @command_window != nil && @command_window.active
    @command_window.dispose if @command_window != nil
    commands = if @mode == :storage
      ["取出／交換至攜帶", "放生", "取消"]
    else
      ["設為出戰", "存入倉庫", "收回目前寵物", "放生", "取消"]
    end
    @command_window = Window_Command.new(304, commands)
    @command_window.x = 240
    @command_window.y = 288
    @command_window.active = old_active
    @command_window.index = old_active ? 0 : -1
  end

  def switch_mode(new_mode)
    return if @swap_mode
    @mode = new_mode
    @pet_window.mode = @mode
    rebuild_command_window
    refresh_title
    refresh_detail
  end

  def update_pet_list
    if @swap_mode
      update_swap_selection
      return
    end
    if Input.trigger?(Input::B)
      Sound.play_cancel
      $scene = Scene_Map.new
    elsif Input.trigger?(Input::L)
      Sound.play_cursor
      switch_mode(:carried)
    elsif Input.trigger?(Input::R)
      Sound.play_cursor
      switch_mode(:storage)
    elsif Input.trigger?(Input::C)
      if @pet_window.pet == nil
        Sound.play_buzzer
      else
        Sound.play_decision
        @pet_window.active = false
        @command_window.active = true
        @command_window.index = 0
      end
    end
  end

  def update_command
    if Input.trigger?(Input::B)
      Sound.play_cancel
      close_command
      return
    end
    return unless Input.trigger?(Input::C)
    pet = @pet_window.pet
    if @mode == :storage
      update_storage_command(pet)
    else
      update_carried_command(pet)
    end
  end

  def update_carried_command(pet)
    case @command_window.index
    when 0
      if pet != nil && $game_party.cg_map_deploy_pet(pet.id)
        Sound.play_equip
        refresh_all
      else
        Sound.play_buzzer
      end
    when 1
      if pet != nil && $game_party.cg_store_pet(pet.id)
        Sound.play_equip
        refresh_all
      else
        Sound.play_buzzer
      end
    when 2
      if $game_party.cg_map_recall_pet
        Sound.play_equip
        refresh_all
      else
        Sound.play_buzzer
      end
    when 3
      if pet != nil && $game_actors.cg_delete_pet(pet.id)
        Sound.play_decision
        refresh_all
      else
        Sound.play_buzzer
      end
    when 4
      Sound.play_cancel
    end
    close_command
  end

  def update_storage_command(pet)
    case @command_window.index
    when 0
      if pet == nil
        Sound.play_buzzer
      elsif !$game_party.cg_carry_full?
        if $game_party.cg_withdraw_pet(pet.id)
          Sound.play_equip
          refresh_all
        else
          Sound.play_buzzer
        end
      else
        @pending_storage_pet_id = pet.id
        @swap_mode = true
        @command_window.active = false
        @command_window.index = -1
        @pet_window.active = true
        @mode = :carried
        @pet_window.mode = :carried
        refresh_title
        refresh_detail
        Sound.play_decision
        return
      end
    when 1
      if pet != nil && $game_actors.cg_delete_pet(pet.id)
        Sound.play_decision
        refresh_all
      else
        Sound.play_buzzer
      end
    when 2
      Sound.play_cancel
    end
    close_command
  end

  def update_swap_selection
    if Input.trigger?(Input::B)
      Sound.play_cancel
      @swap_mode = false
      @pending_storage_pet_id = nil
      @mode = :storage
      @pet_window.mode = :storage
      rebuild_command_window
      refresh_title
      refresh_detail
    elsif Input.trigger?(Input::C)
      carried = @pet_window.pet
      if carried != nil && @pending_storage_pet_id != nil &&
         $game_party.cg_swap_pet_storage(carried.id, @pending_storage_pet_id)
        Sound.play_equip
        @swap_mode = false
        @pending_storage_pet_id = nil
        @mode = :storage
        @pet_window.mode = :storage
        rebuild_command_window
        refresh_title
        refresh_detail
      else
        Sound.play_buzzer
      end
    end
  end

  def close_command
    @command_window.active = false
    @command_window.index = -1
    @pet_window.active = true
  end

  def refresh_all
    $game_party.cg_prepare_pet_storage_data
    @pet_window.refresh
    @pet_window.index = [@pet_window.index, @pet_window.item_max - 1].min
    @pet_window.index = 0 if @pet_window.index < 0
    @detail_window.pet = nil
    refresh_title
    refresh_detail
  end
end

#==============================================================================
# ■ 事件指令
#==============================================================================
class Game_Interpreter
  def cg_store_pet(actor_id)
    return $game_party.cg_store_pet(actor_id)
  end

  def cg_withdraw_pet(actor_id)
    return $game_party.cg_withdraw_pet(actor_id)
  end

  def cg_swap_pet_storage(carried_actor_id, storage_actor_id)
    return $game_party.cg_swap_pet_storage(carried_actor_id, storage_actor_id)
  end
end
