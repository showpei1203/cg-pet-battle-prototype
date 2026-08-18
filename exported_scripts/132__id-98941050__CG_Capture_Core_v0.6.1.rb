# RMVX_SCRIPT_INDEX: 132
# RMVX_SCRIPT_ID: 98941050
# RMVX_SCRIPT_NAME: CG Capture Core v0.6.1
# RMVX_SOURCE_SHA256: cb472a269a457dd280b8f1fb6b0ebc9c8571b7ab318c40b386915827db34677d

#==============================================================================
# ** ALBERT CG 戰鬥捕捉核心
#------------------------------------------------------------------------------
#  版本：v0.6.1
#  引擎：RPG Maker VX／RGSS2
#  前置：Tankentai SBS 3.3、CG Pet Clone Core、CG Battlefield Grid
#------------------------------------------------------------------------------
# 【用途】
#  在戰鬥中以「封印卡」捕捉敵方寵物。捕捉成功後，系統會依敵人的
#  物種 Actor ID 建立一隻新的 Clone 寵物，加入 F5 寵物名冊。
#
# 【指令規則】
#  - 只有 PRIMARY_PET_HANDLER_ACTOR_ID 指定的主角會顯示「捕捉」。
#  - 隊友與所有寵物不會顯示「捕捉」。
#  - 沒有封印卡或場上沒有可捕捉敵人時，指令會以禁用色顯示。
#  - 捕捉不受前後排近戰限制，可選擇任何可捕捉的存活敵人。
#  - 封印卡只在捕捉行動真正執行、且目標仍然有效時消耗。
#  - 捕捉成功的敵人會離開戰場，不提供該敵人的經驗值、金錢或掉落物。
#  - 新寵物只加入名冊，不會在同回合自動出戰。
#  - 從人物的「物品」指令選擇封印卡時，也會進入敵人選擇。
#
# 【敵人 Note】
#  指定捕捉後使用的物種 Actor：
#    <cg_species: 100>
#
#  捕捉難度等級，預設 1：
#    <cg_capture_rank: 1>
#
#  直接指定基礎捕捉率，可省略：
#    <cg_capture_rate: 35>
#
#  指定捕捉後的寵物等級，可省略：
#    <cg_capture_level: 5>
#
#  禁止捕捉：
#    <cg_uncapturable>
#
# 【捕捉率公式】
#  基礎率 + 封印卡加成 + 損失 HP 加成 + 異常狀態加成
#
#  rank 1～4 的預設基礎率分別為 35／25／15／5。
#  HP 越低，最多增加 45%。存在任一非死亡狀態時增加 10%。
#  最終機率限制在 5%～95%。
#
# 【測試封印卡】
#  原型使用 Item 5「初級封印卡」，Note：
#    <cg_capture_card: 10>
#  新遊戲會贈送 12 張。事件也可使用：
#    cg_give_capture_cards(10)
#
# 【腳本位置】
#  請放在所有 CG 戰鬥修正腳本下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_CaptureCore"] = true

module ALBERT_CG
  CAPTURE_CORE_VERSION = "0.6.1"
  CG_BASIC_CAPTURE = 14

  CAPTURE_COMMAND_NAME = "捕捉"
  CAPTURE_ITEM_ID = 5
  CAPTURE_DEMO_CARD_COUNT = 12
  CAPTURE_DEFAULT_LEVEL = 5
  CAPTURE_BASE_RATE_BY_RANK = {1 => 35, 2 => 25, 3 => 15, 4 => 5}
  CAPTURE_HP_BONUS_MAX = 45
  CAPTURE_STATE_BONUS = 10
  CAPTURE_MIN_RATE = 5
  CAPTURE_MAX_RATE = 95
  CAPTURE_ANIMATION_ID = 44
  CAPTURE_FAILURE_ANIMATION_ID = 33
  CAPTURE_ACTION_SPEED = 0

  def self.cg_capture_clamp(value)
    value = value.to_i
    value = CAPTURE_MIN_RATE if value < CAPTURE_MIN_RATE
    value = CAPTURE_MAX_RATE if value > CAPTURE_MAX_RATE
    return value
  end

  def self.cg_make_capture_card
    item = RPG::Item.new
    item.id = CAPTURE_ITEM_ID
    item.name = "初級封印卡"
    item.icon_index = 325
    item.description = "戰鬥中捕捉可封印的寵物。"
    item.scope = 0
    item.occasion = 1
    item.speed = 0
    item.animation_id = CAPTURE_ANIMATION_ID
    item.common_event_id = 0
    item.base_damage = 0
    item.variance = 0
    item.atk_f = 0
    item.spi_f = 0
    item.physical_attack = false
    item.damage_to_mp = false
    item.absorb_damage = false
    item.ignore_defense = false
    item.hp_recovery_rate = 0
    item.hp_recovery = 0
    item.mp_recovery_rate = 0
    item.mp_recovery = 0
    item.parameter_type = 0
    item.parameter_points = 0
    item.consumable = true
    item.price = 100
    item.element_set = []
    item.plus_state_set = []
    item.minus_state_set = []
    item.note = "<cg_capture_card: 10>"
    return item
  end

  def self.capture_card
    return nil if $data_items == nil
    return $data_items[CAPTURE_ITEM_ID]
  end

  def self.give_capture_cards(amount = CAPTURE_DEMO_CARD_COUNT)
    item = capture_card
    return 0 if item == nil || $game_party == nil
    amount = amount.to_i
    return $game_party.item_number(item) if amount <= 0
    $game_party.gain_item(item, amount)
    return $game_party.item_number(item)
  end

  def self.grant_demo_capture_cards_once
    return 0 if $game_party == nil
    unless $game_party.instance_variable_get(:@cg_capture_demo_cards_given)
      give_capture_cards(CAPTURE_DEMO_CARD_COUNT)
      $game_party.instance_variable_set(:@cg_capture_demo_cards_given, true)
    end
    item = capture_card
    return item == nil ? 0 : $game_party.item_number(item)
  end
end

#==============================================================================
# ■ 測試資料補丁
#==============================================================================
module ALBERT_CG
  module TEST_DATA
    class << self
      alias albert_cg_v06_capture_apply apply
      def apply
        albert_cg_v06_capture_apply
        ensure_index($data_items, ALBERT_CG::CAPTURE_ITEM_ID)
        $data_items[ALBERT_CG::CAPTURE_ITEM_ID] = ALBERT_CG.cg_make_capture_card
        for enemy_id in ALBERT_CG::DEMO_ENEMY_IDS
          enemy = $data_enemies[enemy_id]
          next if enemy == nil
          note = enemy.note.to_s
          unless note =~ /<cg_capture_level\s*:/i
            note += "\n<cg_capture_level: 5>"
          end
          enemy.note = note
        end
        $data_system.game_title = "CG Pet Battle Prototype v0.6.1" if $data_system != nil
      end
    end
  end
end

#==============================================================================
# ■ RPG::Item
#==============================================================================
class RPG::Item < RPG::UsableItem
  def cg_capture_card_bonus
    text = note.to_s
    return $1.to_i if text =~ /<cg_capture_card\s*:\s*([+-]?\d+)\s*>/i
    return 0
  end
end

#==============================================================================
# ■ Game_Enemy
#==============================================================================
class Game_Enemy < Game_Battler
  def cg_capture_note
    return enemy == nil ? "" : enemy.note.to_s
  end

  def cg_capture_species_id
    text = cg_capture_note
    return $1.to_i if text =~ /<cg_species\s*:\s*(\d+)\s*>/i
    return $1.to_i if text =~ /<cg_capture_species\s*:\s*(\d+)\s*>/i
    return 0
  end

  def cg_capture_rank
    text = cg_capture_note
    return $1.to_i if text =~ /<cg_capture_rank\s*:\s*(\d+)\s*>/i
    return 1
  end

  def cg_capture_base_rate
    text = cg_capture_note
    return $1.to_i if text =~ /<cg_capture_rate\s*:\s*([+-]?\d+)\s*>/i
    rank = cg_capture_rank
    value = ALBERT_CG::CAPTURE_BASE_RATE_BY_RANK[rank]
    return value == nil ? 5 : value.to_i
  end

  def cg_capture_level
    text = cg_capture_note
    return [$1.to_i, 1].max if text =~ /<cg_capture_level\s*:\s*(\d+)\s*>/i
    return ALBERT_CG::CAPTURE_DEFAULT_LEVEL
  end

  def cg_uncapturable?
    return cg_capture_note =~ /<cg_uncapturable\s*>/i ? true : false
  end

  def cg_capturable?
    return false unless exist?
    return false if cg_uncapturable?
    species_id = cg_capture_species_id
    return false if species_id <= 0
    return false if $data_actors == nil || $data_actors[species_id] == nil
    return true
  end

  def cg_capture_status_bonus
    return 0 unless respond_to?(:states)
    for state in states
      next if state == nil
      next if state.id.to_i == 1
      return ALBERT_CG::CAPTURE_STATE_BONUS
    end
    return 0
  end

  def cg_capture_chance(user = nil, card = nil)
    return 0 unless cg_capturable?
    max_value = maxhp.to_i
    hp_value = hp.to_i
    missing_rate = max_value <= 0 ? 0 : 100 - hp_value * 100 / max_value
    missing_rate = 0 if missing_rate < 0
    missing_rate = 100 if missing_rate > 100
    hp_bonus = missing_rate * ALBERT_CG::CAPTURE_HP_BONUS_MAX / 100
    card_bonus = card != nil && card.respond_to?(:cg_capture_card_bonus) ?
      card.cg_capture_card_bonus : 0
    value = cg_capture_base_rate + hp_bonus + cg_capture_status_bonus + card_bonus
    return ALBERT_CG.cg_capture_clamp(value)
  end
end

#==============================================================================
# ■ Game_BattleAction
#==============================================================================
class Game_BattleAction
  def cg_set_capture
    clear
    @kind = 0
    @basic = ALBERT_CG::CG_BASIC_CAPTURE
  end

  def cg_capture_action?
    return @kind == 0 && @basic == ALBERT_CG::CG_BASIC_CAPTURE
  end

  alias albert_cg_v06_capture_make_speed make_speed
  def make_speed
    albert_cg_v06_capture_make_speed
    @speed += ALBERT_CG::CAPTURE_ACTION_SPEED if cg_capture_action?
  end
end

#==============================================================================
# ■ Window_ActorCommand
#==============================================================================
class Window_ActorCommand < Window_Command
  alias albert_cg_v06_capture_setup setup
  def setup(actor)
    albert_cg_v06_capture_setup(actor)
    return if actor == nil
    is_pet = actor.respond_to?(:cg_battle_pet?) && actor.cg_battle_pet?
    return if is_pet
    return unless actor.id.to_i == ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    @cg_command_types = [] if @cg_command_types == nil
    return if @cg_command_types.include?(:capture)

    insert_at = [4, @commands.size].min
    @commands.insert(insert_at, ALBERT_CG::CAPTURE_COMMAND_NAME)
    @cg_command_types.insert(insert_at, :capture)
    @item_max = @commands.size
    create_contents
    self.top_row = 0 if respond_to?(:top_row=)
    refresh
    self.index = 0 if self.index == nil || self.index < 0
  end
end

#==============================================================================
# ■ Scene_Battle
#==============================================================================
class Scene_Battle < Scene_Base
  def cg_capture_card
    return ALBERT_CG.capture_card
  end

  def cg_capture_card_count
    item = cg_capture_card
    return 0 if item == nil || $game_party == nil
    return $game_party.item_number(item)
  end

  def cg_any_capturable_enemy?
    return false if $game_troop == nil
    for enemy in $game_troop.members
      return true if enemy.respond_to?(:cg_capturable?) && enemy.cg_capturable?
    end
    return false
  end

  def cg_capture_command_available?(actor = nil)
    actor = @active_battler if actor == nil
    return false if actor == nil
    return false if actor.id.to_i != ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
    return false if actor.respond_to?(:cg_battle_pet?) && actor.cg_battle_pet?
    return false if cg_capture_card_count <= 0
    return cg_any_capturable_enemy?
  end

  def cg_refresh_capture_command
    return if @actor_command_window == nil || @active_battler == nil
    return unless @actor_command_window.respond_to?(:cg_set_command_enabled)
    @actor_command_window.cg_set_command_enabled(:capture,
      cg_capture_command_available?(@active_battler))
  end

  alias albert_cg_v06_capture_start_actor_command start_actor_command_selection
  def start_actor_command_selection
    albert_cg_v06_capture_start_actor_command
    cg_refresh_capture_command
  end

  alias albert_cg_v06_capture_update_actor_command update_actor_command_selection
  def update_actor_command_selection
    if Input.trigger?(Input::C) && @active_battler != nil &&
       @actor_command_window != nil &&
       @actor_command_window.respond_to?(:cg_command_type) &&
       @actor_command_window.cg_command_type == :capture
      if @actor_command_window.respond_to?(:cg_command_enabled?) &&
         !@actor_command_window.cg_command_enabled?
        Sound.play_buzzer
        return
      end
      unless cg_capture_command_available?(@active_battler)
        Sound.play_buzzer
        cg_refresh_capture_command
        return
      end
      Sound.play_decision
      @active_battler.action.cg_set_capture
      cg_start_capture_target_selection
      return
    end
    albert_cg_v06_capture_update_actor_command
  end

  #--------------------------------------------------------------------------
  # ● 判定物品
  #--------------------------------------------------------------------------
  # 從「物品」指令選擇封印卡時，原版 VX 因封印卡 scope 為 0，
  # 會直接結束輸入而不開啟敵人游標。這裡將它轉成捕捉行動，並
  # 共用「捕捉」指令的合法目標選擇流程。
  alias albert_cg_v061_capture_determine_item determine_item
  def determine_item
    if @item != nil && @item.id.to_i == ALBERT_CG::CAPTURE_ITEM_ID
      unless cg_capture_command_available?(@active_battler)
        Sound.play_buzzer
        @item_window.active = true if @item_window != nil
        return
      end
      @active_battler.action.cg_set_capture
      @item_window.active = false if @item_window != nil
      @cg_capture_from_item = true
      cg_start_capture_target_selection
      return
    end
    albert_cg_v061_capture_determine_item
  end

  def cg_start_capture_target_selection
    @cg_capture_target_mode = true
    indices = cg_legal_enemy_target_indices
    if indices.empty?
      @cg_capture_target_mode = false
      Sound.play_buzzer
      @actor_command_window.active = true
      return
    end
    cg_start_legal_enemy_target_selection
  end

  alias albert_cg_v06_capture_legal_indices cg_legal_enemy_target_indices
  def cg_legal_enemy_target_indices
    indices = albert_cg_v06_capture_legal_indices
    return indices unless @cg_capture_target_mode
    result = []
    for index in indices
      enemy = $game_troop.members[index]
      next if enemy == nil
      next unless enemy.respond_to?(:cg_capturable?) && enemy.cg_capturable?
      result.push(index)
    end
    return result
  end

  alias albert_cg_v06_capture_help_text cg_target_help_text
  def cg_target_help_text(enemy)
    text = albert_cg_v06_capture_help_text(enemy)
    return text unless @cg_capture_target_mode
    rate = enemy == nil ? 0 : enemy.cg_capture_chance(@active_battler, cg_capture_card)
    text += "　捕捉率 " + rate.to_s + "%"
    text += "　封印卡 " + cg_capture_card_count.to_s
    return text
  end

  alias albert_cg_v061_capture_end_target end_target_selection
  def end_target_selection
    capture_mode = @cg_capture_target_mode == true
    from_item = @cg_capture_from_item == true
    albert_cg_v061_capture_end_target
    if capture_mode
      @cg_capture_target_mode = false
      @cg_capture_from_item = false
      if from_item && @item_window != nil
        # 取消敵人選擇時回到封印卡所在的物品清單。確認目標時，
        # 後續流程會立即呼叫 end_item_selection，因此此恢復不衝突。
        @actor_command_window.active = false if @actor_command_window != nil
        @item_window.visible = true
        @item_window.active = true
        @help_window.visible = true if @help_window != nil
      else
        @actor_command_window.active = true if @actor_command_window != nil
      end
      cg_refresh_capture_command
    end
  end

  alias albert_cg_v06_capture_execute_action execute_action
  def execute_action
    action = @active_battler == nil ? nil : @active_battler.action
    if action != nil && action.respond_to?(:cg_capture_action?) &&
       action.cg_capture_action?
      cg_execute_capture_action
      return
    end
    albert_cg_v06_capture_execute_action
  end

  def cg_capture_target_from_action
    return nil if @active_battler == nil || @active_battler.action == nil
    index = @active_battler.action.target_index.to_i
    return nil if $game_troop == nil
    return nil if index < 0 || index >= $game_troop.members.size
    return $game_troop.members[index]
  end

  def cg_create_captured_pet(enemy)
    return nil if enemy == nil
    species_id = enemy.cg_capture_species_id
    pet = $game_actors.cg_create_pet(species_id, enemy.cg_capture_level, nil,
      ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID)
    return nil if pet == nil
    unless $game_party.cg_register_pet(pet.id,
      ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID)
      $game_actors.cg_delete_pet(pet.id)
      return nil
    end
    return pet
  end

  def cg_execute_capture_action
    user = @active_battler
    target = cg_capture_target_from_action
    card = cg_capture_card

    if user == nil || user.id.to_i != ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
      cg_show_special_action_text("捕捉失敗：只有主角能使用封印卡。")
      return
    end
    if target == nil || !target.exist?
      cg_show_special_action_text("捕捉取消：原本的目標已不在戰場。")
      return
    end
    unless target.respond_to?(:cg_capturable?) && target.cg_capturable?
      cg_show_special_action_text("捕捉失敗：這個目標無法封印。")
      return
    end
    if card == nil || $game_party.item_number(card) <= 0
      cg_show_special_action_text("捕捉失敗：沒有封印卡。")
      return
    end

    rate = target.cg_capture_chance(user, card)
    $game_party.consume_item(card)
    display_animation([target], ALBERT_CG::CAPTURE_ANIMATION_ID)

    if rand(100) < rate
      pet = cg_create_captured_pet(target)
      if pet != nil
        target.escape
        @status_window.refresh if @status_window != nil
        cg_show_special_action_text(user.name.to_s + "成功捕捉" +
          pet.name.to_s + "！　成功率 " + rate.to_s + "%")
      else
        $game_party.gain_item(card, 1)
        cg_show_special_action_text("捕捉資料建立失敗，封印卡已退回。")
      end
    else
      if ALBERT_CG::CAPTURE_FAILURE_ANIMATION_ID.to_i > 0
        display_animation([target], ALBERT_CG::CAPTURE_FAILURE_ANIMATION_ID)
      end
      cg_show_special_action_text(user.name.to_s + "沒有成功封印" +
        target.name.to_s + "。　成功率 " + rate.to_s + "%")
    end
  end
end

#==============================================================================
# ■ 新遊戲測試資源與事件指令
#==============================================================================
module ALBERT_CG
  class << self
    alias albert_cg_v06_capture_bootstrap bootstrap_demo_party
    def bootstrap_demo_party
      result = albert_cg_v06_capture_bootstrap
      grant_demo_capture_cards_once
      return result
    end

    def run_capture_data_test
      item = capture_card
      raise "CG 捕捉測試：找不到封印卡" if item == nil
      raise "CG 捕捉測試：封印卡加成錯誤" unless item.cg_capture_card_bonus == 10
      raise "CG 捕捉測試：妙蛙種子敵人不存在" if $data_enemies[600] == nil
      note = $data_enemies[600].note.to_s
      raise "CG 捕捉測試：缺少物種 Note" unless note =~ /<cg_species\s*:\s*100\s*>/i
      p "CG v0.6.1 捕捉資料測試通過" if ALBERT_CG::DEBUG_MESSAGE
      return true
    end
  end
end

class Game_Interpreter
  def cg_give_capture_cards(amount = ALBERT_CG::CAPTURE_DEMO_CARD_COUNT)
    return ALBERT_CG.give_capture_cards(amount)
  end

  def cg_capture_data_test
    return ALBERT_CG.run_capture_data_test
  end
end
