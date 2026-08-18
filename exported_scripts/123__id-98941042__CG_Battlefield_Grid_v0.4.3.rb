# RMVX_SCRIPT_INDEX: 123
# RMVX_SCRIPT_ID: 98941042
# RMVX_SCRIPT_NAME: CG Battlefield Grid v0.4.3
# RMVX_SOURCE_SHA256: a83081646887bcd6d977fe039d0a1c2b967dc97224e606f5fa0910a99f6cb66c

#==============================================================================
# 【繁體中文說明】ALBERT CG 前後排三列戰場核心
#------------------------------------------------------------------------------
# 【用途】建立前後兩排、左中右三列座標、主人與寵物成對位置，以及魔力寶貝式射程判定。
# 【使用】技能／武器／敵人 Note：<cg_range: melee> 或 <cg_range: ranged>。
# 【位置】請放在 CG Config 下方，並依專案腳本索引指定順序排列。
#==============================================================================

#==============================================================================
# ** ALBERT CG Battlefield Grid
#------------------------------------------------------------------------------
#  Version : 0.4.3
#  Engine  : RPG Maker VX / RGSS2
#  Requires: Tankentai SBS 3.3 + ALBERT CG Config + Dual Command Core
#------------------------------------------------------------------------------
#  Battlefield layout per side:
#
#       Back row : Left / Center / Right
#       Front row: Left / Center / Right
#
#  Default player formation:
#       Human = Back Center
#       Pet   = Front Center
#
#  CG-style melee target rule:
#       * A front-row attacker may use melee against enemy front or back row.
#       * A back-row attacker may use melee against enemy front row.
#       * A back-row attacker may use melee against enemy back row only when
#         the enemy has no living front-row battler anywhere.
#       * Magic, bows and ranged skills may target enemy back row directly.
#
#  Skill / weapon / enemy note tags:
#       <cg_range: melee>
#       <cg_range: ranged>
#
#  Put <cg_range: ranged> on a bow weapon to make normal attacks ranged.
#  Put the same tag on an enemy note to make that enemy's normal attack ranged.
#
#  Event / script calls:
#       actor.cg_set_battle_slot(:front, 0)
#       actor.cg_set_battle_slot(:back,  2)
#       $game_party.cg_assign_default_battle_slots
#       $game_troop.members[0].cg_set_battle_slot(:front, 1)
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattlefieldGrid"] = true

module ALBERT_CG
  GRID_ROWS = [:front, :back]
  GRID_COLUMN_LABELS = ["左", "中", "右"]
  GRID_ROW_LABELS = {:front => "前", :back => "後"}

  def self.cg_valid_grid_row?(row)
    return GRID_ROWS.include?(row)
  end

  def self.cg_clamp_grid_column(column)
    value = column.to_i
    value = 0 if value < 0
    value = BATTLE_COLUMNS - 1 if value >= BATTLE_COLUMNS
    return value
  end

  def self.cg_grid_x(actor_side, row)
    if actor_side
      return row == :front ? ACTOR_FRONT_X : ACTOR_BACK_X
    else
      return row == :front ? ENEMY_FRONT_X : ENEMY_BACK_X
    end
  end

  def self.cg_grid_y(column)
    index = cg_clamp_grid_column(column)
    return GRID_COLUMN_Y[index]
  end

  def self.cg_grid_position(actor_side, row, column)
    return [cg_grid_x(actor_side, row), cg_grid_y(column)]
  end

  def self.cg_nearest_column(y)
    best_index = 0
    best_distance = nil
    for i in 0...GRID_COLUMN_Y.size
      distance = (GRID_COLUMN_Y[i] - y.to_i).abs
      if best_distance == nil or distance < best_distance
        best_distance = distance
        best_index = i
      end
    end
    return best_index
  end
end

class RPG::BaseItem
  def cg_range_type
    text = self.note == nil ? "" : self.note.to_s
    return :melee if text =~ /<cg_range\s*:\s*melee\s*>/i
    return :ranged if text =~ /<cg_range\s*:\s*ranged\s*>/i
    return nil
  end
end

class Game_Battler
  attr_reader :cg_battle_row
  attr_reader :cg_battle_column

  def cg_set_battle_slot(row, column, manual = true)
    row = row.to_sym if row.respond_to?(:to_sym)
    row = :front unless ALBERT_CG.cg_valid_grid_row?(row)
    @cg_battle_row = row
    @cg_battle_column = ALBERT_CG.cg_clamp_grid_column(column)
    @cg_battle_slot_manual = manual ? true : false
    return self
  end

  def cg_set_default_battle_slot(row, column)
    return cg_set_battle_slot(row, column, false)
  end

  def cg_battle_slot_manual?
    return @cg_battle_slot_manual == true
  end

  def cg_clear_battle_slot
    @cg_battle_row = nil
    @cg_battle_column = nil
    @cg_battle_slot_manual = false
  end

  def cg_battle_slot_assigned?
    return false unless ALBERT_CG.cg_valid_grid_row?(@cg_battle_row)
    return false if @cg_battle_column == nil
    return true
  end

  def cg_grid_label
    return "未配置" unless cg_battle_slot_assigned?
    row = ALBERT_CG::GRID_ROW_LABELS[@cg_battle_row]
    column = ALBERT_CG::GRID_COLUMN_LABELS[@cg_battle_column]
    return row.to_s + column.to_s
  end

  def cg_grid_position
    return nil unless cg_battle_slot_assigned?
    return ALBERT_CG.cg_grid_position(actor?, @cg_battle_row,
                                      @cg_battle_column)
  end

  def cg_front_row?
    return @cg_battle_row == :front
  end

  def cg_back_row?
    return @cg_battle_row == :back
  end
end

class Game_Unit
  def cg_living_front_members
    result = []
    for member in members
      next unless member.exist?
      next unless member.respond_to?(:cg_front_row?)
      result.push(member) if member.cg_front_row?
    end
    return result
  end

  def cg_front_row_occupied?
    return !cg_living_front_members.empty?
  end
end

class Game_Party < Game_Unit
  def cg_assign_default_battle_slots
    humans = respond_to?(:cg_human_members) ? cg_human_members : members
    human_columns = [1, 0, 2]
    human_index = 0
    for human in humans
      column = human_columns[human_index] || (human_index % ALBERT_CG::BATTLE_COLUMNS)
      unless human.cg_battle_slot_manual?
        human.cg_set_default_battle_slot(ALBERT_CG::DEFAULT_HUMAN_ROW, column)
      end
      human_index += 1
    end

    pets = if respond_to?(:cg_active_pets)
      cg_active_pets
    else
      pet = respond_to?(:cg_active_pet) ? cg_active_pet : nil
      pet == nil ? [] : [pet]
    end
    for pet in pets
      next unless members.include?(pet)
      next if pet.cg_battle_slot_manual?
      owner = nil
      owner_id = nil
      if pet.respond_to?(:cg_pet?) && pet.cg_pet? && pet.respond_to?(:cg_owner_actor_id)
        owner_id = pet.cg_owner_actor_id
      elsif respond_to?(:cg_fixed_partner_owner_id_for)
        owner_id = cg_fixed_partner_owner_id_for(pet)
      end
      if owner_id != nil
        for human in humans
          if human.id == owner_id
            owner = human
            break
          end
        end
      end
      column = if owner != nil && owner.cg_battle_slot_assigned?
        owner.cg_battle_column
      else
        ALBERT_CG::DEFAULT_PET_COLUMN
      end
      # 主人與寵物預設站同一列、不同排。主人若在前排，寵物改站後排。
      pet_row = if owner != nil && owner.cg_battle_slot_assigned? && owner.cg_front_row?
        :back
      else
        ALBERT_CG::DEFAULT_PET_ROW
      end
      # 若該格已被其他成員占用，依前排／後排、左中右尋找第一個空格。
      occupied = false
      for member in members
        next if member == pet
        next unless member.cg_battle_slot_assigned?
        if member.cg_battle_row == pet_row && member.cg_battle_column == column
          occupied = true
          break
        end
      end
      if occupied
        found = nil
        for row in [pet_row, pet_row == :front ? :back : :front]
          for try_column in 0...ALBERT_CG::BATTLE_COLUMNS
            used = false
            for member in members
              next if member == pet
              next unless member.cg_battle_slot_assigned?
              if member.cg_battle_row == row && member.cg_battle_column == try_column
                used = true
                break
              end
            end
            unless used
              found = [row, try_column]
              break
            end
          end
          break if found != nil
        end
        pet_row, column = found if found != nil
      end
      pet.cg_set_default_battle_slot(pet_row, column)
    end
    return true
  end

  def cg_battler_at(row, column, living_only = true)
    column = ALBERT_CG.cg_clamp_grid_column(column)
    for member in members
      next unless member.cg_battle_slot_assigned?
      next unless member.cg_battle_row == row
      next unless member.cg_battle_column == column
      next if living_only && !member.exist?
      return member
    end
    return nil
  end
end

class Game_Troop < Game_Unit
  alias albert_cg_v04_grid_troop_setup setup
  def setup(troop_id)
    albert_cg_v04_grid_troop_setup(troop_id)
    cg_assign_default_battle_slots
  end

  def cg_assign_default_battle_slots
    for enemy in members
      row = enemy.screen_x >= ALBERT_CG::ENEMY_ROW_MID_X ? :front : :back
      column = ALBERT_CG.cg_nearest_column(enemy.screen_y)
      enemy.cg_set_default_battle_slot(row, column)
    end
    return true
  end

  def cg_battler_at(row, column, living_only = true)
    column = ALBERT_CG.cg_clamp_grid_column(column)
    for member in members
      next unless member.cg_battle_slot_assigned?
      next unless member.cg_battle_row == row
      next unless member.cg_battle_column == column
      next if living_only && !member.exist?
      return member
    end
    return nil
  end
end

class Game_Actor < Game_Battler
  alias albert_cg_v04_grid_actor_base_position base_position
  def base_position
    $game_party.cg_assign_default_battle_slots unless cg_battle_slot_assigned?
    point = cg_grid_position
    return albert_cg_v04_grid_actor_base_position if point == nil
    @base_position_x = point[0]
    @base_position_y = point[1]
    if $back_attack && N01::BACK_ATTACK
      @base_position_x = Graphics.width - @base_position_x
    end
  end

  alias albert_cg_v04_grid_actor_position_z position_z
  def position_z
    value = albert_cg_v04_grid_actor_position_z
    value += 8 if cg_front_row?
    return value
  end
end

class Game_Enemy < Game_Battler
  alias albert_cg_v04_grid_enemy_base_position base_position
  def base_position
    $game_troop.cg_assign_default_battle_slots unless cg_battle_slot_assigned?
    point = cg_grid_position
    return albert_cg_v04_grid_enemy_base_position if point == nil
    @base_position_x = point[0]
    @base_position_y = point[1]
    if $back_attack && N01::BACK_ATTACK
      @base_position_x = Graphics.width - @base_position_x
    end
  end

  alias albert_cg_v04_grid_enemy_position_z position_z
  def position_z
    value = albert_cg_v04_grid_enemy_position_z
    value += 8 if cg_front_row?
    return value
  end
end

class Game_Battler
  def cg_basic_attack_range_type
    return :melee
  end
end

class Game_Actor < Game_Battler
  def cg_basic_attack_range_type
    if respond_to?(:weapons)
      for weapon in weapons.compact
        next unless weapon.respond_to?(:cg_range_type)
        range = weapon.cg_range_type
        return :ranged if range == :ranged
        return :melee if range == :melee
      end
    end
    return :melee
  end
end

class Game_Enemy < Game_Battler
  def cg_basic_attack_range_type
    if respond_to?(:enemy) && enemy != nil && enemy.respond_to?(:cg_range_type)
      range = enemy.cg_range_type
      return range unless range == nil
    end
    return :melee
  end
end

class Game_BattleAction
  def cg_action_object
    return skill if skill?
    return item if item?
    return nil
  end

  def cg_melee_action?
    if attack?
      range = battler.respond_to?(:cg_basic_attack_range_type) ?
        battler.cg_basic_attack_range_type : :melee
      return range != :ranged
    end
    obj = cg_action_object
    return false if obj == nil
    range = obj.respond_to?(:cg_range_type) ? obj.cg_range_type : nil
    return true if range == :melee
    return false if range == :ranged
    return obj.physical_attack if obj.respond_to?(:physical_attack)
    return false
  end

  def cg_targets_opponents?
    return true if attack?
    obj = cg_action_object
    return false if obj == nil
    return obj.for_opponent?
  end

  # CG rule: front-row melee attackers can reach either enemy row.
  # Back-row melee attackers cannot reach enemy back row while any living
  # enemy remains in the front row. Columns do not create protection.
  def cg_target_legal?(target)
    return false if target == nil
    return false unless target.exist?
    return true unless cg_targets_opponents?
    return true unless target.actor? != battler.actor?
    return true unless cg_melee_action?
    return true if battler.respond_to?(:cg_front_row?) && battler.cg_front_row?
    return true if target.respond_to?(:cg_front_row?) && target.cg_front_row?
    unit = opponents_unit
    return true unless unit.respond_to?(:cg_front_row_occupied?)
    return !unit.cg_front_row_occupied?
  end

  def cg_legal_opponent_targets
    result = []
    for target in opponents_unit.existing_members
      result.push(target) if cg_target_legal?(target)
    end
    return result
  end

  def cg_random_legal_opponent
    candidates = cg_legal_opponent_targets
    roulette = []
    for target in candidates
      weight = target.odds.to_i
      weight = 1 if weight < 1
      weight.times { roulette.push(target) }
    end
    return nil if roulette.empty?
    return roulette[rand(roulette.size)]
  end

  alias albert_cg_v04_grid_decide_random_target decide_random_target
  def decide_random_target
    if !for_friend? && !for_dead_friend?
      target = cg_random_legal_opponent
      if target == nil
        clear
      else
        @target_index = target.index
      end
      return
    end
    albert_cg_v04_grid_decide_random_target
  end

  alias albert_cg_v04_grid_make_targets make_targets
  def make_targets
    targets = albert_cg_v04_grid_make_targets
    return [] if targets == nil
    return targets unless cg_targets_opponents?

    filtered = []
    for target in targets
      if target.actor? == battler.actor? || cg_target_legal?(target)
        filtered.push(target)
      end
    end

    opponent_found = false
    for target in filtered
      opponent_found = true if target.actor? != battler.actor?
    end
    unless opponent_found
      fallback = cg_legal_opponent_targets[0]
      filtered.push(fallback) if fallback != nil
    end
    return filtered.compact
  end

  alias albert_cg_v04_grid_evaluate_attack evaluate_attack
  def evaluate_attack
    @value = 0
    for target in cg_legal_opponent_targets
      value = evaluate_attack_with_target(target)
      if value > @value
        @value = value
        @target_index = target.index
      end
    end
  end

  alias albert_cg_v04_grid_evaluate_skill evaluate_skill
  def evaluate_skill
    if skill != nil && skill.for_opponent?
      @value = 0
      return unless battler.skill_can_use?(skill)
      targets = cg_legal_opponent_targets
      for target in targets
        value = evaluate_skill_with_target(target)
        if skill.for_all?
          @value += value
        elsif value > @value
          @value = value
          @target_index = target.index
        end
      end
      return
    end
    albert_cg_v04_grid_evaluate_skill
  end
end

class Window_CG_CommandPhase < Window_Base
  def set_slot(slot)
    self.contents.clear
    if slot == nil or slot.battler == nil
      self.visible = false
      return
    end
    text = slot.label.to_s + "：" + slot.battler.name.to_s
    if ALBERT_CG::SHOW_GRID_LABELS && slot.battler.respond_to?(:cg_grid_label)
      text += " [" + slot.battler.cg_grid_label + "]"
    end
    self.contents.draw_text(0, 0, contents.width, WLH, text, 1)
    self.visible = true
  end
end

class Scene_Battle < Scene_Base
  alias albert_cg_v04_grid_scene_start start
  def start
    $game_party.cg_assign_default_battle_slots if $game_party != nil
    $game_troop.cg_assign_default_battle_slots if $game_troop != nil
    albert_cg_v04_grid_scene_start
  end

  alias albert_cg_v04_grid_start_target_selection start_target_selection
  def start_target_selection(actor = false)
    return albert_cg_v04_grid_start_target_selection(actor) if actor
    cg_hide_phase_window if respond_to?(:cg_hide_phase_window)
    cg_start_legal_enemy_target_selection
  end

  def cg_legal_enemy_target_indices
    result = []
    members = $game_troop.members
    for i in 0...members.size
      enemy = members[i]
      next unless enemy.exist?
      next unless @active_battler.action.cg_target_legal?(enemy)
      result.push(i)
    end
    result.sort! do |a, b|
      enemy_a = members[a]
      enemy_b = members[b]
      key_a = enemy_a.cg_battle_column * 2 + (enemy_a.cg_front_row? ? 0 : 1)
      key_b = enemy_b.cg_battle_column * 2 + (enemy_b.cg_front_row? ? 0 : 1)
      key_a <=> key_b
    end
    return result
  end

  def cg_target_help_text(enemy)
    return "" if enemy == nil
    text = enemy.name.to_s
    if ALBERT_CG::SHOW_GRID_LABELS && enemy.respond_to?(:cg_grid_label)
      text += " [" + enemy.cg_grid_label + "]"
    end
    return text
  end

  def cg_start_legal_enemy_target_selection
    @cg_enemy_target_indices = cg_legal_enemy_target_indices
    if @cg_enemy_target_indices.empty?
      Sound.play_buzzer
      @actor_command_window.active = true
      return
    end

    @cursor = Sprite.new
    @cursor.bitmap = Cache.character("cursor")
    @cursor.src_rect.set(0, 0, 32, 32)
    @cursor_flame = 0
    @cursor.x = -200
    @cursor.y = -200
    @cursor.ox = @cursor.width
    @cursor.oy = @cursor.height

    @help_window.visible = false if @help_window != nil
    @help_window2 = Window_Help.new if @help_window2 == nil
    @actor_command_window.active = false
    @skill_window.visible = false if @skill_window != nil
    @item_window.visible = false if @item_window != nil

    @cg_enemy_target_pos = 0
    @index = @cg_enemy_target_indices[@cg_enemy_target_pos]
    enemy = $game_troop.members[@index]
    @help_window2.set_text(cg_target_help_text(enemy), 1)
    cg_select_legal_enemy_member
  end

  def cg_select_legal_enemy_member
    loop do
      update_basic
      @cursor_flame = 0 if @cursor_flame == 30
      @cursor.src_rect.set(0, 0, 32, 32) if @cursor_flame == 29
      @cursor.src_rect.set(0, 32, 32, 32) if @cursor_flame == 15
      point = @spriteset.set_cursor(false, @index)
      @cursor.x = point[0]
      @cursor.y = point[1]
      @cursor_flame += 1

      if Input.trigger?(Input::B)
        Sound.play_cancel
        end_target_selection
        break
      elsif Input.trigger?(Input::C)
        Sound.play_decision
        @active_battler.action.target_index = @index
        end_target_selection
        end_skill_selection
        end_item_selection
        next_actor
        break
      end

      if Input.repeat?(Input::LEFT) || Input.repeat?(Input::UP)
        cg_move_legal_enemy_cursor(-1)
      elsif Input.repeat?(Input::RIGHT) || Input.repeat?(Input::DOWN)
        cg_move_legal_enemy_cursor(1)
      end
    end
  end

  def cg_move_legal_enemy_cursor(direction)
    return if @cg_enemy_target_indices == nil
    return if @cg_enemy_target_indices.empty?
    Sound.play_cursor
    @cg_enemy_target_pos += direction
    @cg_enemy_target_pos %= @cg_enemy_target_indices.size
    @index = @cg_enemy_target_indices[@cg_enemy_target_pos]
    enemy = $game_troop.members[@index]
    @help_window2.set_text(cg_target_help_text(enemy), 1)
  end

  alias albert_cg_v04_grid_end_target_selection end_target_selection
  def end_target_selection
    albert_cg_v04_grid_end_target_selection
    @cg_enemy_target_indices = nil
    @cg_enemy_target_pos = nil
  end
end

class Game_Interpreter
  def cg_set_actor_battle_slot(actor_id, row, column)
    actor = $game_actors[actor_id]
    return false if actor == nil
    actor.cg_set_battle_slot(row, column, true)
    actor.base_position if $game_temp.in_battle
    return true
  end

  def cg_set_enemy_battle_slot(enemy_index, row, column)
    enemy = $game_troop.members[enemy_index]
    return false if enemy == nil
    enemy.cg_set_battle_slot(row, column, true)
    enemy.base_position if $game_temp.in_battle
    return true
  end
end
