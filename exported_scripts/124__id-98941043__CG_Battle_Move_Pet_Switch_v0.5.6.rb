# RMVX_SCRIPT_INDEX: 124
# RMVX_SCRIPT_ID: 98941043
# RMVX_SCRIPT_NAME: CG Battle Move Pet Switch v0.5.6
# RMVX_SOURCE_SHA256: 31113fd244fa77a1ced111db177e5ea1209e685fa643ad63ddf9b63c38102176

#==============================================================================
# ** ALBERT CG 戰鬥換位與換寵核心
#------------------------------------------------------------------------------
#  版本：v0.5.6
#  引擎：RPG Maker VX／RGSS2
#  前置：Tankentai SBS 3.3、CG 雙指令核心、CG 三列戰場核心
#------------------------------------------------------------------------------
# 【用途】
#  本腳本負責戰鬥中的位置移動、主人與自己的寵物交換位置，以及收回／更換寵物。
#  所有操作都會消耗「人物」當回合的一次行動，並加入速度排序佇列。
#
# 【人物新增指令】
#  1. 移動
#     - 人物移動到我方任一空格。
#     - 人物與目前出戰寵物交換位置。
#  2. 換寵
#     - 收回目前出戰寵物。
#     - 從名冊派出另一隻可戰鬥寵物。
#
# 【換寵規則】
#  - 戰鬥不能（HP 為 0）的寵物會顯示在名單中，但不能派出。
#  - 更換寵物時，新寵物沿用舊寵物的戰場位置。
#  - 若原本沒有寵物，新寵物優先配置在前排中央；該格被佔用時改用其他空格。
#  - 被換下的寵物若尚有未執行行動，該行動會因離開隊伍而自動略過。
#  - 新派出的寵物要到下一回合才會取得指令。
#
# 【位置規則】
#  - 同一格不能同時存在兩名我方戰鬥者。
#  - 戰鬥不能的成員仍佔據原本位置，不能直接踩在其位置上。
#  - 換位執行後，後續行動會使用最新位置重新判定近戰射程。
#  - 例如前排寵物原先鎖定敵方後排，但行動前被換到後排：
#    敵方仍有前排時，原目標變成非法，系統會改打第一個合法前排目標；
#    若沒有任何合法目標，該行動不會命中任何人。
#
# 【事件腳本】
#  立即更換出戰寵物：
#    $game_party.cg_battle_switch_pet(寵物個體ID)
#
#  立即收回出戰寵物：
#    $game_party.cg_battle_recall_pet
#
#  判斷寵物能否在戰鬥中派出：
#    $game_party.cg_battle_switchable_pet?(寵物個體ID)
#
# 【腳本順序】
#  請放在「CG Battlefield Grid」下方、Main 上方。
#
# 【v0.5.6 架構】
#  - 主角可捕捉寵物使用 Clone Actor，全部直接屬於主角自由名冊。
#  - 換寵候補只依「持有 Clone、不是目前出戰、HP 大於 0」判斷，不再看主人欄位。
#  - 隊友固定寵物使用普通資料庫 Actor，由 FIXED_PARTNER_PET_ACTORS 綁定。
#  - 隊友固定寵物不會進入 F5 名冊，也不會出現在主角換寵選單。
#  - 收回指令以保存的 Clone 個體 ID 直接核對實際隊伍，避免對應表損壞。
#  - 換位會同步 Tankentai Sprite_Battler 位移並播放 RESET_POSITION。
#  - 同一人物的第二動不得超越第一動（由 CG Dual Command v0.4.2 處理）。
#  - 同一人物每回合最多安排一次「派出／換寵／收回」。
#    沒有寵物時，第一動已選擇派寵，第二動再選「換寵」會被拒絕。
#  - 只有 PRIMARY_PET_HANDLER_ACTOR_ID 可以在戰鬥中自由換寵。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattleMovePetSwitch"] = true

module ALBERT_CG
  # 自訂基本行動編號。避開 VX 內建的 0～3。
  CG_BASIC_MOVE_SLOT = 10
  CG_BASIC_SWAP_PET  = 11
  CG_BASIC_SWITCH_PET = 12
  CG_BASIC_RECALL_PET = 13

  # 將 row／column 轉成人類可讀的繁體中文位置名稱。
  def self.cg_slot_text(row, column)
    row_text = GRID_ROW_LABELS[row] || "?"
    column = cg_clamp_grid_column(column)
    column_text = GRID_COLUMN_LABELS[column] || "?"
    return row_text.to_s + column_text.to_s
  end
end

#==============================================================================
# ■ Game_BattleAction
#------------------------------------------------------------------------------
#  儲存換位與換寵所需的額外資料，並確保雙指令複製行動時資料不遺失。
#==============================================================================
class Game_BattleAction
  attr_accessor :cg_move_row
  attr_accessor :cg_move_column
  attr_accessor :cg_switch_pet_id
  attr_accessor :cg_swap_pet_id
  attr_accessor :cg_recall_pet_id

  alias albert_cg_v05_special_clear clear
  def clear
    albert_cg_v05_special_clear
    @cg_move_row = nil
    @cg_move_column = nil
    @cg_switch_pet_id = nil
    @cg_swap_pet_id = nil
    @cg_recall_pet_id = nil
  end

  def cg_set_move_slot(row, column)
    clear
    @kind = 0
    @basic = ALBERT_CG::CG_BASIC_MOVE_SLOT
    @cg_move_row = row.to_sym
    @cg_move_column = ALBERT_CG.cg_clamp_grid_column(column)
  end

  def cg_set_swap_pet(pet_id)
    clear
    @kind = 0
    @basic = ALBERT_CG::CG_BASIC_SWAP_PET
    @cg_swap_pet_id = pet_id.to_i
  end

  def cg_set_switch_pet(pet_id)
    clear
    @kind = 0
    @basic = ALBERT_CG::CG_BASIC_SWITCH_PET
    @cg_switch_pet_id = pet_id.to_i
  end

  def cg_set_recall_pet(pet_id = nil)
    clear
    @kind = 0
    @basic = ALBERT_CG::CG_BASIC_RECALL_PET
    @cg_recall_pet_id = pet_id == nil ? nil : pet_id.to_i
  end

  def cg_special_battle_action?
    return false unless @kind == 0
    return [ALBERT_CG::CG_BASIC_MOVE_SLOT,
            ALBERT_CG::CG_BASIC_SWAP_PET,
            ALBERT_CG::CG_BASIC_SWITCH_PET,
            ALBERT_CG::CG_BASIC_RECALL_PET].include?(@basic)
  end

  # CG 雙指令核心會多次複製 Game_BattleAction，因此在這裡補拷貝自訂欄位。
  alias albert_cg_v05_special_copy_for cg_copy_for
  def cg_copy_for(new_battler = nil)
    copy = albert_cg_v05_special_copy_for(new_battler)
    copy.cg_move_row = @cg_move_row
    copy.cg_move_column = @cg_move_column
    copy.cg_switch_pet_id = @cg_switch_pet_id
    copy.cg_swap_pet_id = @cg_swap_pet_id
    copy.cg_recall_pet_id = @cg_recall_pet_id
    return copy
  end
end

#==============================================================================
# ■ Game_Party
#------------------------------------------------------------------------------
#  管理戰場格位、主角 Clone 換寵，以及隊友固定普通 Actor 寵物。
#  v0.5.4 不再以 Clone 主人欄位篩選主角名冊。
#==============================================================================
class Game_Party < Game_Unit
  def cg_owner_actor_id_from(actor_or_id = nil)
    return ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID if actor_or_id == nil
    return actor_or_id.id if actor_or_id.respond_to?(:id)
    return actor_or_id.to_i
  end

  def cg_free_pet_switch_owner?(actor_or_id)
    owner_id = cg_owner_actor_id_from(actor_or_id)
    return owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
  end

  # 指定位置是否已被其他隊員佔用。
  # living_only=false 時，戰鬥不能成員也算佔位。
  def cg_slot_occupied_by_other?(row, column, battler, living_only = false)
    column = ALBERT_CG.cg_clamp_grid_column(column)
    for member in members
      next if member == battler
      next unless member.respond_to?(:cg_battle_slot_assigned?)
      next unless member.cg_battle_slot_assigned?
      next unless member.cg_battle_row == row
      next unless member.cg_battle_column == column
      next if living_only && !member.exist?
      return true
    end
    return false
  end

  # 改變 base_position 後，以 move_x／move_y 保留畫面上的舊位置。
  # 之後播放 Tankentai RESET_POSITION，角色便會平滑移到新格位。
  def cg_prepare_animated_slot_transition(battler, old_x, old_y)
    return false if battler == nil
    battler.move_x = 0 if battler.respond_to?(:move_x=)
    battler.move_y = 0 if battler.respond_to?(:move_y=)
    battler.jump = 0 if battler.respond_to?(:jump=)
    battler.base_position if battler.respond_to?(:base_position)
    if battler.respond_to?(:position_x) && battler.respond_to?(:move_x=)
      battler.move_x = old_x.to_i - battler.position_x.to_i
    end
    if battler.respond_to?(:position_y) && battler.respond_to?(:move_y=)
      battler.move_y = old_y.to_i - battler.position_y.to_i
    end
    return true
  end

  # 人物移動到指定空格。animated=true 時保留舊畫面位置，交由 SBS 位移。
  def cg_move_battler_to_slot(battler, row, column, animated = false)
    return false if battler == nil
    return false unless members.include?(battler)
    row = row.to_sym if row.respond_to?(:to_sym)
    return false unless ALBERT_CG.cg_valid_grid_row?(row)
    column = ALBERT_CG.cg_clamp_grid_column(column)
    return false if cg_slot_occupied_by_other?(row, column, battler, false)
    old_x = battler.respond_to?(:position_x) ? battler.position_x : 0
    old_y = battler.respond_to?(:position_y) ? battler.position_y : 0
    battler.cg_set_battle_slot(row, column, true)
    if animated
      cg_prepare_animated_slot_transition(battler, old_x, old_y)
    else
      battler.reset_coordinate if battler.respond_to?(:reset_coordinate)
      battler.base_position if battler.respond_to?(:base_position)
    end
    return true
  end

  # 尋找我方第一個可使用的空格。
  def cg_first_empty_battle_slot(preferred_row = :front, preferred_column = 1, battler = nil)
    candidates = [[preferred_row, ALBERT_CG.cg_clamp_grid_column(preferred_column)]]
    for row in [:front, :back]
      for column in 0...ALBERT_CG::BATTLE_COLUMNS
        pair = [row, column]
        candidates.push(pair) unless candidates.include?(pair)
      end
    end
    for pair in candidates
      row = pair[0]
      column = pair[1]
      next if cg_slot_occupied_by_other?(row, column, battler, false)
      return pair
    end
    return nil
  end

  # 人物只可與「綁定給自己」且目前出戰的寵物交換完整位置。
  def cg_swap_human_and_pet_slots(human, pet = nil, animated = false)
    pet = respond_to?(:cg_active_pet_for) ? cg_active_pet_for(human) : cg_active_pet if pet == nil
    return false if human == nil or pet == nil
    return false unless members.include?(human)
    return false unless members.include?(pet)
    return false unless human.exist? and pet.exist?
    return false unless human.cg_battle_slot_assigned?
    return false unless pet.cg_battle_slot_assigned?
    if pet.respond_to?(:cg_pet?) && pet.cg_pet?
      return false unless human.id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    elsif respond_to?(:cg_fixed_partner_pair?)
      return false unless cg_fixed_partner_pair?(human, pet)
    else
      return false
    end

    human_old_x = human.respond_to?(:position_x) ? human.position_x : 0
    human_old_y = human.respond_to?(:position_y) ? human.position_y : 0
    pet_old_x = pet.respond_to?(:position_x) ? pet.position_x : 0
    pet_old_y = pet.respond_to?(:position_y) ? pet.position_y : 0
    human_row = human.cg_battle_row
    human_column = human.cg_battle_column
    pet_row = pet.cg_battle_row
    pet_column = pet.cg_battle_column
    human.cg_set_battle_slot(pet_row, pet_column, true)
    pet.cg_set_battle_slot(human_row, human_column, true)

    if animated
      cg_prepare_animated_slot_transition(human, human_old_x, human_old_y)
      cg_prepare_animated_slot_transition(pet, pet_old_x, pet_old_y)
    else
      human.reset_coordinate if human.respond_to?(:reset_coordinate)
      pet.reset_coordinate if pet.respond_to?(:reset_coordinate)
      human.base_position if human.respond_to?(:base_position)
      pet.base_position if pet.respond_to?(:base_position)
    end
    return true
  end

  # 判斷寵物是否屬於指定人物可操作的名冊。
  # 主角可操作自由名冊；隊友只保留固定綁定資料，不提供自由換寵。
  def cg_pet_available_to_owner?(pet, owner_actor_or_id = nil)
    return false if pet == nil
    owner_id = cg_owner_actor_id_from(owner_actor_or_id)
    primary = ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    if owner_id == primary
      return false if pet.respond_to?(:cg_fixed_owner?) && pet.cg_fixed_owner? &&
                      pet.cg_owner_actor_id != primary
      return true
    end
    return false unless pet.respond_to?(:cg_fixed_owner?) && pet.cg_fixed_owner?
    return pet.cg_owner_actor_id == owner_id
  end

  # 取得指定人物的實際出戰寵物。主角找隊伍中的 Clone；隊友找固定普通 Actor。
  def cg_repair_active_pet_for_owner!(owner_actor_or_id = nil)
    owner_id = cg_owner_actor_id_from(owner_actor_or_id)
    if owner_id != ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
      fixed_id = respond_to?(:cg_fixed_partner_pet_actor_id) ? cg_fixed_partner_pet_actor_id(owner_id) : nil
      fixed_pet = fixed_id == nil ? nil : $game_actors[fixed_id]
      return fixed_pet if fixed_pet != nil && members.include?(fixed_pet)
      return nil
    end
    current = cg_active_pet(owner_id)
    return current if current != nil && members.include?(current)
    for member in members
      next unless member.respond_to?(:cg_pet?) && member.cg_pet?
      next unless cg_owned_pet_ids.include?(member.id)
      @cg_active_pet_ids_by_owner = {} if @cg_active_pet_ids_by_owner == nil
      @cg_active_pet_ids_by_owner[owner_id] = member.id
      @cg_active_pet_id = member.id
      return member
    end
    return nil
  end

  # 主角 Clone 名冊中的寵物是否能在戰鬥中派出。
  # 不再依賴主人欄位，候補判定只看「持有、非目前出戰、仍可戰鬥」。
  def cg_battle_switchable_pet?(actor_id, owner_actor_or_id = nil)
    owner_id = cg_owner_actor_id_from(owner_actor_or_id)
    return false unless cg_free_pet_switch_owner?(owner_id)
    return false unless cg_owned_pet_ids.include?(actor_id.to_i)
    pet = $game_actors.cg_pet(actor_id.to_i)
    return false if pet == nil
    active = cg_repair_active_pet_for_owner!(owner_id)
    return false if active != nil && active.id == pet.id
    return false unless pet.exist?
    return true
  end

  # 主角候補就是所有持有的 Clone 寵物扣掉目前出戰者。
  # 隊友固定普通 Actor 從未進入 cg_owned_pet_ids，因此不可能混入。
  def cg_battle_reserve_pets(owner_actor_or_id = nil)
    owner_id = cg_owner_actor_id_from(owner_actor_or_id)
    return [] unless cg_free_pet_switch_owner?(owner_id)
    active = cg_repair_active_pet_for_owner!(owner_id)
    result = []
    for pet in cg_owned_pets
      next if active != nil && pet.id == active.id
      result.push(pet)
    end
    return result
  end

  # 戰鬥中更換或派出寵物。只有主角主人可自由執行。
  def cg_battle_switch_pet(actor_id, owner_actor_or_id = nil)
    owner_id = cg_owner_actor_id_from(owner_actor_or_id)
    return false unless cg_battle_switchable_pet?(actor_id, owner_id)
    old_pet = cg_repair_active_pet_for_owner!(owner_id)
    new_pet = $game_actors.cg_pet(actor_id)
    return false if new_pet == nil

    if old_pet != nil && old_pet.cg_battle_slot_assigned?
      row = old_pet.cg_battle_row
      column = old_pet.cg_battle_column
    else
      empty_slot = cg_first_empty_battle_slot(ALBERT_CG::DEFAULT_PET_ROW,
                                              ALBERT_CG::DEFAULT_PET_COLUMN,
                                              new_pet)
      return false if empty_slot == nil
      row = empty_slot[0]
      column = empty_slot[1]
    end

    remove_actor(old_pet.id) if old_pet != nil
    add_actor(new_pet.id)
    unless members.include?(new_pet)
      add_actor(old_pet.id) if old_pet != nil
      return false
    end

    cg_prepare_party_pet_data if respond_to?(:cg_prepare_party_pet_data)
    @cg_active_pet_ids_by_owner = {} if @cg_active_pet_ids_by_owner == nil
    @cg_active_pet_ids_by_owner[owner_id] = new_pet.id
    @cg_active_pet_id = new_pet.id if owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    new_pet.cg_set_battle_slot(row, column, true)
    new_pet.reset_coordinate if new_pet.respond_to?(:reset_coordinate)
    new_pet.base_position if new_pet.respond_to?(:base_position)
    $party_change = true
    return true
  end

  # 戰鬥中收回主角目前寵物。隊友固定寵物不提供自由收回指令。
  # expected_pet_id 是下指令時保存的寵物 ID，可避免執行前主人對應變動後誤收另一隻。
  def cg_battle_recall_pet(owner_actor_or_id = nil, expected_pet_id = nil)
    cg_prepare_party_pet_data if respond_to?(:cg_prepare_party_pet_data)
    owner_id = cg_owner_actor_id_from(owner_actor_or_id)
    return false unless cg_free_pet_switch_owner?(owner_id)

    pet = nil
    if expected_pet_id != nil
      candidate = $game_actors.cg_pet(expected_pet_id.to_i)
      if candidate != nil && cg_owned_pet_ids.include?(candidate.id) &&
         members.include?(candidate)
        pet = candidate
      end
    end
    pet = cg_repair_active_pet_for_owner!(owner_id) if pet == nil
    return false if pet == nil

    remove_actor(pet.id)
    if @cg_active_pet_ids_by_owner != nil
      for key in @cg_active_pet_ids_by_owner.keys.clone
        @cg_active_pet_ids_by_owner.delete(key) if @cg_active_pet_ids_by_owner[key] == pet.id
      end
      @cg_active_pet_ids_by_owner.delete(owner_id)
    end
    @cg_active_pet_id = nil if owner_id == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    $party_change = true
    return true
  end
end

#==============================================================================
# ■ Sprite_Battler／Spriteset_Battle
#------------------------------------------------------------------------------
#  Tankentai 的 Sprite_Battler 另存一份 @move_x／@move_y。
#  只改 Game_Battler.move_x 時，RESET_POSITION 會以為位移仍是 0，因此直接交換位置。
#  本段在播放序列前同步兩份位移資料，讓人物與寵物真正滑動至新格位。
#==============================================================================
class Sprite_Battler < Sprite_Base
  def cg_sync_slot_offset_from_battler
    return false if @battler == nil
    @move_x = @battler.move_x.to_i
    @move_y = @battler.move_y.to_i
    @move_speed_x = 0
    @move_speed_y = 0
    @move_speed_plus_x = 0
    @move_speed_plus_y = 0
    @moving_x = 0
    @moving_y = 0
    return true
  end
end

class Spriteset_Battle
  def cg_sync_actor_slot_offset(index)
    return false if @actor_sprites == nil
    sprite = @actor_sprites[index]
    return false if sprite == nil
    return sprite.cg_sync_slot_offset_from_battler
  end
end

#==============================================================================
# ■ Window_ActorCommand
#------------------------------------------------------------------------------
#  人物追加「移動」；只有主角追加「換寵」。
#  v0.5.4 會重建 contents，避免第 5、6 項只有游標、沒有文字。
#==============================================================================
class Window_ActorCommand < Window_Command
  attr_reader :cg_command_types

  alias albert_cg_v051_actor_command_setup setup
  def setup(actor)
    albert_cg_v051_actor_command_setup(actor)
    @cg_command_types = [:attack, :skill, :guard, :item]
    if actor != nil && actor.respond_to?(:cg_battle_pet?) && actor.cg_battle_pet?
      @cg_command_types[3] = :wait
    elsif actor != nil
      @commands.push("移動")
      @cg_command_types.push(:move)
      if $game_party != nil && $game_party.respond_to?(:cg_free_pet_switch_owner?) &&
         $game_party.cg_free_pet_switch_owner?(actor)
        @commands.push("換寵")
        @cg_command_types.push(:switch_pet)
      end
      @item_max = @commands.size
      # Window_ActorCommand 原本只建立四列 Bitmap。新增指令後必須重建。
      create_contents
      self.top_row = 0 if respond_to?(:top_row=)
      refresh
      self.index = 0
    end
  end

  def cg_command_type(index = nil)
    index = self.index if index == nil
    return nil if @cg_command_types == nil
    return @cg_command_types[index]
  end
end

#==============================================================================
# ■ Window_CG_BattlePetSwitch
#------------------------------------------------------------------------------
#  只顯示主角自己的可更換寵物；隊友固定寵物不會混入名冊。
#==============================================================================
class Window_CG_BattlePetSwitch < Window_Command
  attr_reader :entries

  def initialize(entries)
    @entries = entries
    commands = []
    for entry in @entries
      commands.push(entry[:text])
    end
    rows = [commands.size, 8].min
    rows = 1 if rows < 1
    super(304, commands, 1, rows)
  end

  def entry
    return nil if @entries == nil
    return nil if self.index < 0 or self.index >= @entries.size
    return @entries[self.index]
  end

  def refresh
    self.contents.clear
    for i in 0...@item_max
      enabled = @entries[i] == nil ? false : @entries[i][:enabled]
      draw_item(i, enabled)
    end
  end
end

#==============================================================================
# ■ Scene_Battle
#------------------------------------------------------------------------------
#  建立選單、保存自訂行動，並以 SBS 位移／動畫執行換位與換寵。
#==============================================================================
class Scene_Battle < Scene_Base
  alias albert_cg_v051_update_actor_command_selection update_actor_command_selection
  def update_actor_command_selection
    if Input.trigger?(Input::C) && @active_battler != nil &&
       @active_battler.respond_to?(:cg_battle_pet?) && !@active_battler.cg_battle_pet? &&
       @actor_command_window.respond_to?(:cg_command_type)
      case @actor_command_window.cg_command_type
      when :move
        Sound.play_decision
        cg_start_move_command
        return
      when :switch_pet
        Sound.play_decision
        cg_start_pet_switch_command
        return
      end
    end
    albert_cg_v051_update_actor_command_selection
  end

  # 共用彈出選單迴圈。回傳索引；按 B 回傳 -1。
  def cg_run_battle_popup(window, help_text)
    help = Window_Help.new
    help.set_text(help_text, 1)
    help.z = 500
    window.x = (544 - window.width) / 2
    window.y = 72
    window.z = 500
    window.active = true
    @actor_command_window.active = false
    result = -1
    loop do
      update_basic
      window.update
      if Input.trigger?(Input::B)
        Sound.play_cancel
        result = -1
        break
      elsif Input.trigger?(Input::C)
        result = window.index
        break
      end
    end
    window.active = false
    window.dispose
    help.dispose
    return result
  end

  def cg_restore_actor_command_after_popup
    @actor_command_window.active = true
    slot = respond_to?(:cg_current_command_slot) ? cg_current_command_slot : nil
    if @cg_phase_window != nil && slot != nil
      @cg_phase_window.set_slot(slot)
    end
  end

  # 建立可用移動項目。人物只能看見「自己的出戰寵物」交換選項。
  def cg_move_entries
    entries = []
    human = @active_battler
    pet = $game_party.respond_to?(:cg_active_pet_for) ?
      $game_party.cg_active_pet_for(human) : $game_party.cg_active_pet
    if pet != nil && $game_party.members.include?(pet) && human.exist? && pet.exist?
      entries.push({:type => :swap_pet, :text => "與自己的寵物交換位置"})
    end
    for row in [:front, :back]
      for column in 0...ALBERT_CG::BATTLE_COLUMNS
        next if human.cg_battle_slot_assigned? &&
                human.cg_battle_row == row && human.cg_battle_column == column
        next if $game_party.cg_slot_occupied_by_other?(row, column, human, false)
        text = "移至" + ALBERT_CG.cg_slot_text(row, column)
        entries.push({:type => :move, :text => text,
                      :row => row, :column => column})
      end
    end
    return entries
  end

  def cg_start_move_command
    entries = cg_move_entries
    if entries.empty?
      Sound.play_buzzer
      cg_restore_actor_command_after_popup
      return
    end
    commands = entries.collect { |entry| entry[:text] }
    window = Window_Command.new(272, commands, 1, [commands.size, 8].min)
    index = cg_run_battle_popup(window, "選擇人物本回合的移動方式")
    if index < 0
      cg_restore_actor_command_after_popup
      return
    end
    entry = entries[index]
    if entry[:type] == :swap_pet
      pet = $game_party.cg_active_pet_for(@active_battler)
      if pet == nil or !pet.exist?
        Sound.play_buzzer
        cg_restore_actor_command_after_popup
        return
      end
      @active_battler.action.cg_set_swap_pet(pet.id)
    else
      @active_battler.action.cg_set_move_slot(entry[:row], entry[:column])
    end
    Sound.play_decision
    next_actor
  end

  # 建立主角自己的換寵名單。
  def cg_pet_switch_entries
    entries = []
    owner = @active_battler
    active_pet = $game_party.respond_to?(:cg_repair_active_pet_for_owner!) ?
      $game_party.cg_repair_active_pet_for_owner!(owner) : $game_party.cg_active_pet_for(owner)
    if active_pet != nil
      entries.push({:type => :recall, :pet_id => active_pet.id,
                    :text => "收回目前寵物", :enabled => true})
    end
    for pet in $game_party.cg_battle_reserve_pets(owner)
      enabled = pet.exist?
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

  # 判斷同一人物在本回合較早的指令欄位，是否已安排過派寵／換寵／收回。
  def cg_pet_management_action?(action)
    return false if action == nil
    return false unless action.kind == 0
    return [ALBERT_CG::CG_BASIC_SWITCH_PET,
            ALBERT_CG::CG_BASIC_RECALL_PET].include?(action.basic)
  end

  def cg_pet_management_already_planned?(battler)
    return false if battler == nil
    return false if @cg_input_slots == nil || @cg_input_slot_index == nil
    for i in 0...@cg_input_slot_index
      slot = @cg_input_slots[i]
      next if slot == nil || slot.battler != battler
      return true if cg_pet_management_action?(slot.action)
    end
    return false
  end

  def cg_start_pet_switch_command
    if cg_pet_management_already_planned?(@active_battler)
      Sound.play_buzzer
      @help_window.set_text("同一人物每回合只能安排一次派寵、換寵或收回。", 1) if @help_window != nil
      cg_restore_actor_command_after_popup
      return
    end
    unless $game_party.cg_free_pet_switch_owner?(@active_battler)
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
    if entry == nil or entry[:type] == :cancel
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

  def cg_show_special_action_text(text, duration = 45)
    if @help_window != nil
      @help_window.set_text(text, 1)
      @help_window.visible = true
    end
    wait(duration)
    @help_window.visible = false if @help_window != nil
  end

  def cg_refresh_party_after_switch
    $game_party.cg_assign_default_battle_slots if $game_party.respond_to?(:cg_assign_default_battle_slots)
    @status_window.refresh if @status_window != nil
    wait(3) # 讓 Tankentai 依 $party_change 重建角色 Sprite。
  end

  # 播放角色移到新格位的 SBS RESET_POSITION 序列。
  def cg_play_slot_move_sequence(battlers)
    battlers = [battlers] unless battlers.is_a?(Array)
    for battler in battlers
      next if battler == nil
      index = $game_party.members.index(battler)
      next if index == nil
      if @spriteset != nil
        @spriteset.cg_sync_actor_slot_offset(index) if @spriteset.respond_to?(:cg_sync_actor_slot_offset)
        if @spriteset.respond_to?(:set_action)
          @spriteset.set_action(true, index, ALBERT_CG::BATTLE_SLOT_MOVE_ACTION)
        end
      end
    end
    wait(ALBERT_CG::BATTLE_SLOT_MOVE_WAIT)
    for battler in battlers
      next if battler == nil
      battler.reset_coordinate if battler.respond_to?(:reset_coordinate)
      battler.base_position if battler.respond_to?(:base_position)
    end
  end

  # 播放派出／收回動畫。動畫 ID 為 0 時停用。
  def cg_play_pet_switch_animation(pet, animation_id)
    return if pet == nil
    return if animation_id == nil or animation_id.to_i <= 0
    pet.animation_id = animation_id.to_i
    wait(ALBERT_CG::PET_SWITCH_ANIMATION_WAIT)
  end

  alias albert_cg_v056_start_party_command_selection start_party_command_selection
  def start_party_command_selection
    @cg_pet_management_executed = {}
    albert_cg_v056_start_party_command_selection
  end

  def cg_pet_management_executed_for?(battler)
    @cg_pet_management_executed = {} if @cg_pet_management_executed == nil
    return @cg_pet_management_executed[battler.object_id] == true
  end

  def cg_mark_pet_management_executed(battler)
    @cg_pet_management_executed = {} if @cg_pet_management_executed == nil
    @cg_pet_management_executed[battler.object_id] = true
  end

  alias albert_cg_v051_execute_action execute_action
  def execute_action
    action = @active_battler == nil ? nil : @active_battler.action
    if action != nil && action.respond_to?(:cg_special_battle_action?) &&
       action.cg_special_battle_action?
      case action.basic
      when ALBERT_CG::CG_BASIC_MOVE_SLOT
        cg_execute_move_slot
      when ALBERT_CG::CG_BASIC_SWAP_PET
        cg_execute_swap_pet
      when ALBERT_CG::CG_BASIC_SWITCH_PET
        cg_execute_switch_pet
      when ALBERT_CG::CG_BASIC_RECALL_PET
        cg_execute_recall_pet
      end
      return
    end
    albert_cg_v051_execute_action
  end

  def cg_execute_move_slot
    row = @active_battler.action.cg_move_row
    column = @active_battler.action.cg_move_column
    if $game_party.cg_move_battler_to_slot(@active_battler, row, column, true)
      cg_play_slot_move_sequence(@active_battler)
      text = @active_battler.name.to_s + "移動到「" +
             ALBERT_CG.cg_slot_text(row, column) + "」。"
    else
      text = @active_battler.name.to_s + "無法移動，目標位置已被佔用。"
    end
    cg_show_special_action_text(text)
  end

  def cg_execute_swap_pet
    pet = $game_actors.cg_pet(@active_battler.action.cg_swap_pet_id)
    if $game_party.cg_swap_human_and_pet_slots(@active_battler, pet, true)
      cg_play_slot_move_sequence([@active_battler, pet])
      text = @active_battler.name.to_s + "與" + pet.name.to_s + "交換位置。"
    else
      text = "交換位置失敗：只能與自己的出戰寵物交換。"
    end
    cg_show_special_action_text(text)
  end

  def cg_execute_switch_pet
    owner = @active_battler
    if cg_pet_management_executed_for?(owner)
      cg_show_special_action_text("本回合已執行過一次寵物出入場指令，後續指令取消。")
      return
    end
    pet_id = owner.action.cg_switch_pet_id
    old_pet = $game_party.cg_active_pet_for(owner)
    new_pet = $game_actors.cg_pet(pet_id)
    old_name = old_pet == nil ? "" : old_pet.name.to_s
    new_name = new_pet == nil ? "寵物" : new_pet.name.to_s

    cg_play_pet_switch_animation(old_pet, ALBERT_CG::PET_RECALL_ANIMATION_ID) if old_pet != nil
    if $game_party.cg_battle_switch_pet(pet_id, owner)
      cg_mark_pet_management_executed(owner)
      cg_refresh_party_after_switch
      cg_play_pet_switch_animation(new_pet, ALBERT_CG::PET_SUMMON_ANIMATION_ID)
      if old_pet == nil
        text = owner.name.to_s + "派出" + new_name + "。"
      else
        text = owner.name.to_s + "收回" + old_name + "，派出" + new_name + "。"
      end
    else
      text = "換寵失敗：該寵物不在主角名冊、已出戰或目前無法戰鬥。"
    end
    cg_show_special_action_text(text)
  end

  def cg_execute_recall_pet
    owner = @active_battler
    if cg_pet_management_executed_for?(owner)
      cg_show_special_action_text("本回合已執行過一次寵物出入場指令，後續指令取消。")
      return
    end
    expected_id = owner.action.cg_recall_pet_id
    pet = expected_id == nil ? nil : $game_actors.cg_pet(expected_id)
    if pet == nil && $game_party.respond_to?(:cg_repair_active_pet_for_owner!)
      pet = $game_party.cg_repair_active_pet_for_owner!(owner)
    end
    can_animate = pet != nil && $game_party.members.include?(pet)
    cg_play_pet_switch_animation(pet, ALBERT_CG::PET_RECALL_ANIMATION_ID) if can_animate
    if $game_party.cg_battle_recall_pet(owner, expected_id)
      cg_mark_pet_management_executed(owner)
      text = owner.name.to_s + "收回" + pet.name.to_s + "。"
      cg_refresh_party_after_switch
    else
      text = "收回失敗：指定的主角 Clone 寵物已不在戰場。"
    end
    cg_show_special_action_text(text)
  end
end

#==============================================================================
# ■ Game_Interpreter
#------------------------------------------------------------------------------
#  事件 API。
#  主角 Clone 寵物：cg_battle_switch_pet／cg_battle_recall_pet。
#  隊友固定普通 Actor 寵物請使用：cg_set_fixed_partner_pet(主人ID, 寵物ActorID, true)。
#==============================================================================
class Game_Interpreter
  def cg_battle_switch_pet(actor_id, owner_actor_id = nil)
    return $game_party.cg_battle_switch_pet(actor_id, owner_actor_id)
  end

  def cg_battle_recall_pet(owner_actor_id = nil, expected_pet_id = nil)
    return $game_party.cg_battle_recall_pet(owner_actor_id, expected_pet_id)
  end
end
