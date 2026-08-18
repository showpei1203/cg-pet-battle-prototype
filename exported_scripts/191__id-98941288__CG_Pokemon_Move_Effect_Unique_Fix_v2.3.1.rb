# RMVX_SCRIPT_INDEX: 191
# RMVX_SCRIPT_ID: 98941288
# RMVX_SCRIPT_NAME: CG Pokemon Move Effect Unique Fix v2.3.1
# RMVX_SOURCE_SHA256: 8e17c85da00e596b8280f5bde2b777e1d146e5a6f833291ebd05d0527a545c30

#==============================================================================
# ■ CG Pokemon Move Effect Unique Fix v2.3.1
#------------------------------------------------------------------------------
# 【用途】
#  接續 v2.3.0 的 Pokémon Move Effect Core，處理實機 F11 測試抓出的共通問題，
#  並完成第一批需要專用規則的 Unique Move。此頁不是把特殊技能塞成大量 if/else
#  的臨時補丁，而是建立「Unique Move 後處理／回合型防護／特殊狀態」共用層，
#  後續 v2.3.x 可直接擴充。
#
# 【本版正式修正】
#  1. Protect / Detect / Max Guard：修正 v2.3.0 中守住狀態在使用者行動後立刻被
#     remove_states_auto 移除，導致同回合後續攻擊仍能命中的問題。
#     新規則：成功使用後持續到本回合 turn_end，再統一解除。
#  2. Endure：本回合受到致死傷害時保留 1 HP，turn_end 後解除。
#  3. Toxic / Poison Fang：新增「劇毒」獨立 State，回合末傷害由 1/16 MaxHP
#     逐回合增加，最高 15/16；切換／戰鬥結束時重置累積。
#  4. Aqua Ring：新增獨立 State，每回合回復 1/16 MaxHP，可與扎根並存。
#  5. Focus Energy：設定本場持續的暴擊專注旗標；本作以額外約 24% 暴擊判定
#     表現 +2 critical stage，避免直接照搬不同世代曾變更過的原作機率。
#
# 【第一批 Unique Move】
#  - 聚氣 Focus Energy
#  - 睡覺 Rest
#  - 守住 Protect / 看穿 Detect / 極巨防壁 Max Guard
#  - 腹鼓 Belly Drum
#  - 挺住 Endure
#  - 治癒鈴聲 Heal Bell / 芳香治療 Aromatherapy
#  - 分擔痛楚 Pain Split
#  - 自我暗示 Psych Up
#  - 臨別禮物 Memento
#  - 煥然一新 Refresh
#  - 水流環 Aqua Ring
#  - 破殼 Shell Smash（v2.3.0 已有完整 Stage Metadata，本版正式列為完成）
#  - 顛倒 Topsy-Turvy
#  - 吸取力量 Strength Sap
#  - 淨化 Purify
#  - 叢林治療 Jungle Healing
#  - 黑霧 Haze / 清除之煙 Clear Smog 的能力階級重置
#
# 【技能動作與 PMD】
#  本頁不改動 v2.3.0 Motion Resolver。所有 Pokémon 技能仍先由：
#    Species 專用 Override -> Move 動作提示 -> Motion Family -> fallback chain
#  尋找實際存在且至少 8 方向的 Native Action；找不到時最終回退 Idle。
#  因此本頁新增的 Unique 效果不會要求某個 Pokémon 一定具備特定 PMD 動作。
#
# 【Animation】
#  仍沿用 Master Data 的資料庫 Animation ID 占位值。正式動畫／SE 於後續
#  Visual Pass 統一替換，不讓視覺素材阻塞技能機制完成。
#
# 【人類技能】
#  不經本頁。六大人類職業維持 Tankentai SBS 原生近戰／遠程／施法分類。
#
# 【可調參數】
#  STATE_BAD_POISON        ：劇毒 State ID。
#  STATE_AQUA_RING         ：水流環 State ID。
#  FOCUS_ENERGY_CRIT_RATE  ：聚氣額外暴擊率（百分比）。
#  HANDLED_UNIQUE_MOVE_IDS ：本版已完成的 Unique Move ID 清單。
#
# 【Debug】
#  F11       ：保留 v2.3.0 Multi-hit / Drain / Stage / Status / Protect 測試場。
#  Shift+F11 ：v2.3.1 Unique Move Lab，集中測試 Rest / Belly Drum / Endure /
#              Heal Bell / Pain Split / Aqua Ring / Strength Sap 等。
#
# 【LOG】
#  延續 Pokemon_MoveEffect_v2_3.log，新增 V231_* 記錄。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonMoveEffectUniqueFix"] = "2.3.1"

module ALBERT_CG
  module MOVE_EFFECT
    V231_VERSION = "2.3.1"
    STATE_BAD_POISON = 56
    STATE_AQUA_RING  = 57
    FOCUS_ENERGY_CRIT_RATE = 24

    BAD_POISON_MOVE_IDS = [92, 305]
    BASE_PROTECT_MOVE_IDS = [182, 197, 743]

    HANDLED_UNIQUE_MOVE_IDS = [
      116, 150, 156, 182, 187, 197, 203, 215, 220, 244,
      262, 287, 312, 392, 504, 576, 668, 685, 743, 816
    ]

    # Category 10/11/12 在 v2.3.0 Coverage 中原本被過度樂觀地算成 Generic。
    # 本版先明確標示：只有下列已做完，其他 Field/Force Switch 後續實作。
    HANDLED_NON_UNIQUE_SPECIAL_IDS = [114, 499]

    def self.install_v231_states
      return if $data_states == nil
      begin
        ensure_index($data_states, STATE_BAD_POISON)
        bad = make_state(STATE_BAD_POISON, "劇毒", 7, 99, 0, true)
        bad.auto_release_prob = 0
        $data_states[STATE_BAD_POISON] = bad

        ensure_index($data_states, STATE_AQUA_RING)
        ring = make_state(STATE_AQUA_RING, "水流環", 23, 99, 0, false)
        ring.auto_release_prob = 0
        $data_states[STATE_AQUA_RING] = ring

        # v2.3.0 的 hold_turn=0 會在「使用守住者自己的行動結束」立即移除。
        # 改成至少撐過該次 remove_states_auto，真正生命週期由 turn_end 清理。
        if $data_states[STATE_PROTECT] != nil
          $data_states[STATE_PROTECT].hold_turn = 1
          $data_states[STATE_PROTECT].auto_release_prob = 100
        end

        PRIMARY_STATES.push(STATE_BAD_POISON) unless PRIMARY_STATES.include?(STATE_BAD_POISON)
      rescue => e
        log("V231_STATE_INSTALL_ERROR " + e.class.to_s + ":" + e.message.to_s)
      end
    end

    def self.primary_cure_state_ids
      return [STATE_POISON, STATE_BAD_POISON, STATE_PARALYSIS,
              STATE_SLEEP, STATE_FREEZE, STATE_BURN]
    end

    def self.bad_poison_move?(move_id)
      return BAD_POISON_MOVE_IDS.include?(move_id.to_i)
    end

    def self.unique_v231_handled?(move_id)
      return HANDLED_UNIQUE_MOVE_IDS.include?(move_id.to_i)
    end

    def self.coverage_v231(move_id)
      mid = move_id.to_i
      return "V231_UNIQUE_HANDLED" if unique_v231_handled?(mid)
      return "V231_SPECIAL_HANDLED" if HANDLED_NON_UNIQUE_SPECIAL_IDS.include?(mid)
      cat = meta_category(mid)
      return "PENDING_FIELD_CORE" if cat == 10 || cat == 11
      return "PENDING_FORCE_SWITCH" if cat == 12
      return "UNIQUE_EXPLICIT_PENDING" if cat == 13
      return "GENERIC_CORE" 
    end

    def self.reset_log
      begin
        File.open(LOG_FILE, "wb") do |f|
          f.write("CG POKEMON MOVE EFFECT CORE v2.3.0 + UNIQUE FIX v" + V231_VERSION + "\r\n")
          f.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
          f.write("------------------------------------------------------------\r\n")
        end
      rescue
      end
    end

    #------------------------------------------------------------------------
    # Shift+F11 Unique Move Lab
    #------------------------------------------------------------------------
    UNIQUE_TEST_TROOP_ID = 699
    UNIQUE_TEST_LEVEL = 30
    UNIQUE_TEST_ALLIES = [
      {:dex=>143, :level=>30, :ability=>47, :moves=>[156,187,203,116]}, # 卡比獸
      {:dex=>113, :level=>30, :ability=>30, :moves=>[215,220,287,182]}, # 吉利蛋
      {:dex=>3,   :level=>30, :ability=>65, :moves=>[312,392,685,816]},# 妙蛙花
    ]
    UNIQUE_TEST_ENEMIES = [
      {:dex=>68,  :level=>30, :ability=>62, :moves=>[2,69,89,116]},    # 怪力
      {:dex=>94,  :level=>30, :ability=>130,:moves=>[247,109,92,94]}, # 耿鬼
      {:dex=>376, :level=>30, :ability=>29, :moves=>[232,428,94,89]}, # 巨金怪
      {:dex=>143, :level=>30, :ability=>47, :moves=>[34,44,133,182]}, # 卡比獸
    ]

    begin
      CG_VK_SHIFT_V231 = 0x10 unless const_defined?(:CG_VK_SHIFT_V231)
      CG_GET_ASYNC_KEY_STATE_V231 =
        Win32API.new("user32", "GetAsyncKeyState", "i", "i") unless
        const_defined?(:CG_GET_ASYNC_KEY_STATE_V231)
    rescue
      CG_GET_ASYNC_KEY_STATE_V231 = nil unless const_defined?(:CG_GET_ASYNC_KEY_STATE_V231)
    end

    def self.v231_shift_down?
      api = CG_GET_ASYNC_KEY_STATE_V231
      return false if api == nil
      return (api.call(CG_VK_SHIFT_V231) & 0x8000) != 0
    rescue
      return false
    end

    class << self
      alias cg_move_v231_old_f11_trigger f11_trigger?
    end
    def self.f11_trigger?
      if v231_shift_down?
        api = CG_GET_ASYNC_KEY_STATE_F11
        @f11_down = ((api.call(CG_VK_F11) & 0x8000) != 0) if api != nil
        return false
      end
      return cg_move_v231_old_f11_trigger
    end

    def self.shift_f11_trigger?
      api = CG_GET_ASYNC_KEY_STATE_F11
      return false if api == nil
      down = ((api.call(CG_VK_F11) & 0x8000) != 0) && v231_shift_down?
      trigger = down && @v231_shift_f11_down != true
      @v231_shift_f11_down = down
      return trigger
    rescue
      return false
    end

    def self.configure_unique_test_actor(cfg)
      return if master == nil
      actor = $game_actors[master.actor_id_for_dex(cfg[:dex])]
      return if actor == nil
      master.configure_actor(actor, cfg)
      actor.cg_reset_stat_stages if actor.respond_to?(:cg_reset_stat_stages)
      actor.cg_clear_v231_battle_flags if actor.respond_to?(:cg_clear_v231_battle_flags)
      log("V231_TEST_ALLY dex=" + cfg[:dex].to_s + " name=" + actor.name.to_s +
          " moves=" + cfg[:moves].collect { |mid| master.move_name(mid) }.inspect)
    end

    def self.configure_unique_test_enemy(cfg)
      return if master == nil
      master.configure_enemy_data(cfg)
      log("V231_TEST_ENEMY dex=" + cfg[:dex].to_s +
          " name=" + master.name_for_dex(cfg[:dex]) +
          " moves=" + cfg[:moves].collect { |mid| master.move_name(mid) }.inspect)
    end

    def self.make_unique_test_troop
      return if master == nil
      master.ensure_index($data_troops, UNIQUE_TEST_TROOP_ID)
      xs = [ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_BACK_X, ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[2],
            ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[2]]
      members = []
      UNIQUE_TEST_ENEMIES.each_with_index do |cfg, index|
        configure_unique_test_enemy(cfg)
        members.push(ALBERT_CG::SPECIES26.make_troop_member(
          master.enemy_id_for_dex(cfg[:dex]), xs[index] || 180, ys[index] || 220))
      end
      $data_troops[UNIQUE_TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        UNIQUE_TEST_TROOP_ID, "Pokemon Unique Effect v2.3.1 Lab", members)
    end

    def self.prepare_unique_test_party
      return false if master == nil || $game_party == nil
      ids = UNIQUE_TEST_ALLIES.collect { |cfg| master.actor_id_for_dex(cfg[:dex]) }
      if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
        ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids)
      end
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized, true)
      $game_party.cg_enable_direct_pmd_test_party! if
        $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      UNIQUE_TEST_ALLIES.each { |cfg| configure_unique_test_actor(cfg) }
      human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if human != nil
        human.change_level(UNIQUE_TEST_LEVEL, false)
        human.recover_all if human.respond_to?(:recover_all)
      end
      return true
    end

    def self.start_unique_test
      reset_log
      prepare_unique_test_party
      make_unique_test_troop
      @effect_test_active = false
      @v231_unique_test_active = true
      log("V231_SHIFT_F11_START troop=" + UNIQUE_TEST_TROOP_ID.to_s)
      return ALBERT_CG.start_demo_battle(UNIQUE_TEST_TROOP_ID)
    end

    def self.unique_test_active?
      return @v231_unique_test_active == true
    end
  end
end

#==============================================================================
# ■ Game_Battler：Unique Effect 共用 Runtime
#==============================================================================
class Game_Battler
  def cg_v231_add_state_record(state_id)
    add_state(state_id)
    @added_states = [] if @added_states == nil
    @added_states.push(state_id) unless @added_states.include?(state_id)
  end

  def cg_v231_remove_state_record(state_id)
    return false unless state?(state_id)
    remove_state(state_id)
    @removed_states = [] if @removed_states == nil
    @removed_states.push(state_id) unless @removed_states.include?(state_id)
    @cg_bad_poison_count = nil if state_id.to_i == ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON
    return true
  end

  def cg_v231_cure_primary_statuses(only_ids = nil)
    ids = only_ids || ALBERT_CG::MOVE_EFFECT.primary_cure_state_ids
    removed = 0
    ids.each do |id|
      removed += 1 if cg_v231_remove_state_record(id)
    end
    return removed
  end

  def cg_v231_set_stage_exact(key, value)
    current = cg_stat_stage(key)
    return cg_change_stat_stage(key, value.to_i - current.to_i)
  end

  def cg_v231_copy_stages_from(other)
    return if other == nil
    [:atk,:def,:spa,:spd,:spe,:accuracy,:evasion].each do |key|
      cg_v231_set_stage_exact(key, other.cg_stat_stage(key))
    end
  end

  def cg_v231_invert_stages
    [:atk,:def,:spa,:spd,:spe,:accuracy,:evasion].each do |key|
      cg_v231_set_stage_exact(key, -cg_stat_stage(key))
    end
  end

  def cg_clear_v231_round_flags
    @cg_protect_v231 = false
    @cg_endure_v231 = false
    if state?(ALBERT_CG::MOVE_EFFECT::STATE_PROTECT)
      remove_state(ALBERT_CG::MOVE_EFFECT::STATE_PROTECT)
    end
  end

  def cg_clear_v231_battle_flags
    cg_clear_v231_round_flags
    @cg_focus_energy_v231 = false
    @cg_bad_poison_count = nil
  end

  alias cg_move_v231_remove_states_battle remove_states_battle
  def remove_states_battle
    cg_move_v231_remove_states_battle
    cg_clear_v231_battle_flags
  end

  alias cg_move_v231_execute_damage execute_damage
  def execute_damage(user)
    if @cg_endure_v231 == true && @hp_damage.to_i > 0 && hp.to_i > 1 &&
       @hp_damage.to_i >= hp.to_i
      old = @hp_damage.to_i
      @hp_damage = hp.to_i - 1
      ALBERT_CG::MOVE_EFFECT.log("V231_ENDURE_BLOCK target=" + name.to_s +
        " incoming=" + old.to_s + " final=" + @hp_damage.to_s)
    end
    cg_move_v231_execute_damage(user)
  end

  alias cg_move_v231_apply_ailment cg_move_effect_apply_ailment
  def cg_move_effect_apply_ailment(user, move_id)
    if ALBERT_CG::MOVE_EFFECT.bad_poison_move?(move_id)
      ailment = ALBERT_CG::MOVE_EFFECT.ailment_id(move_id)
      chance = ALBERT_CG::MOVE_EFFECT.ailment_chance(move_id)
      return if chance <= 0 || rand(100) >= chance
      return unless ALBERT_CG::MOVE_EFFECT.can_apply_ailment?(self, ailment)
      cg_v231_add_state_record(ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON)
      @cg_bad_poison_count = 1
      ALBERT_CG::MOVE_EFFECT.log("V231_BAD_POISON user=" + user.name.to_s +
        " target=" + name.to_s + " move=" + move_id.to_s)
      return
    end
    cg_move_v231_apply_ailment(user, move_id)
  end

  # Purify 的 PokeAPI healing=50 是「回復使用者」，而 v2.3.0 Generic Heal
  # 會回復 skill_effect 的 target。此招必須跳過 Generic Heal，由 Unique Handler 處理。
  alias cg_move_v231_heal_recoil cg_move_effect_apply_heal_recoil
  def cg_move_effect_apply_heal_recoil(user, move_id, damage_done)
    return if move_id.to_i == 685
    cg_move_v231_heal_recoil(user, move_id, damage_done)
  end

  alias cg_move_v231_apply_protect cg_move_effect_apply_protect
  def cg_move_effect_apply_protect(user, move_id)
    cg_move_v231_apply_protect(user, move_id)
    if ALBERT_CG::MOVE_EFFECT.protect_move?(move_id)
      user.instance_variable_set(:@cg_protect_v231, true)
      ALBERT_CG::MOVE_EFFECT.log("V231_PROTECT_ACTIVE user=" + user.name.to_s)
    end
  end

  alias cg_move_v231_slip_damage_effect slip_damage_effect
  def slip_damage_effect
    cg_move_v231_slip_damage_effect
    return if hp <= 0

    if state?(ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON)
      @cg_bad_poison_count = 1 if @cg_bad_poison_count == nil || @cg_bad_poison_count < 1
      count = [@cg_bad_poison_count.to_i, 15].min
      damage = [maxhp.to_i * count / 16, 1].max
      damage = hp if damage > hp
      self.hp -= damage
      @hp_damage = damage
      @cg_bad_poison_count = [count + 1, 15].min
      ALBERT_CG::MOVE_EFFECT.log("V231_TOXIC_TICK battler=" + name.to_s +
        " stage=" + count.to_s + " damage=" + damage.to_s)
    end

    if hp > 0 && state?(ALBERT_CG::MOVE_EFFECT::STATE_AQUA_RING)
      gain = [[maxhp.to_i / 16, 1].max, maxhp.to_i - hp.to_i].min
      if gain > 0
        self.hp += gain
        @hp_damage = -gain
        ALBERT_CG::MOVE_EFFECT.log("V231_AQUA_RING_HEAL battler=" + name.to_s +
          " heal=" + gain.to_s)
      end
    end
  end

  alias cg_move_v231_skill_effect skill_effect
  def skill_effect(user, skill)
    move_id = ALBERT_CG::MOVE_EFFECT.move_id(skill)
    pre_atk = cg_atk_stat if move_id == 668
    cg_move_v231_skill_effect(user, skill)
    return if move_id <= 0
    return if @skipped || @missed || @evaded

    case move_id
    when 116 # Focus Energy
      user.instance_variable_set(:@cg_focus_energy_v231, true)
      ALBERT_CG::MOVE_EFFECT.log("V231_FOCUS_ENERGY user=" + user.name.to_s)

    when 150 # Splash: intentional no-op
      ALBERT_CG::MOVE_EFFECT.log("V231_SPLASH user=" + user.name.to_s + " no_effect=true")

    when 156 # Rest
      gained = user.maxhp.to_i - user.hp.to_i
      user.cg_v231_cure_primary_statuses
      user.hp = user.maxhp
      user.hp_damage = -gained if user.respond_to?(:hp_damage=)
      user.cg_v231_add_state_record(ALBERT_CG::MOVE_EFFECT::STATE_SLEEP)
      ALBERT_CG::MOVE_EFFECT.log("V231_REST user=" + user.name.to_s +
        " heal=" + gained.to_s + " sleep=true")

    when 182, 197, 743 # Protect / Detect / Max Guard
      user.instance_variable_set(:@cg_protect_v231, true)

    when 187 # Belly Drum
      cost = [user.maxhp.to_i / 2, 1].max
      if user.hp.to_i > cost && user.cg_stat_stage(:atk) < 6
        user.hp -= cost
        user.hp_damage = cost if user.respond_to?(:hp_damage=)
        user.cg_v231_set_stage_exact(:atk, 6)
        ALBERT_CG::MOVE_EFFECT.log("V231_BELLY_DRUM user=" + user.name.to_s +
          " cost=" + cost.to_s + " atk_stage=6")
      else
        ALBERT_CG::MOVE_EFFECT.log("V231_BELLY_DRUM_FAIL user=" + user.name.to_s)
      end

    when 203 # Endure
      user.instance_variable_set(:@cg_endure_v231, true)
      ALBERT_CG::MOVE_EFFECT.log("V231_ENDURE_ACTIVE user=" + user.name.to_s)

    when 215, 312 # Heal Bell / Aromatherapy: scope=all allies, each target cures itself
      removed = cg_v231_cure_primary_statuses
      ALBERT_CG::MOVE_EFFECT.log("V231_TEAM_CURE move=" + move_id.to_s +
        " target=" + name.to_s + " removed=" + removed.to_s)

    when 220 # Pain Split
      total = user.hp.to_i + hp.to_i
      avg = total / 2
      user_old = user.hp.to_i
      target_old = hp.to_i
      user.hp = [avg, user.maxhp.to_i].min
      self.hp = [avg, maxhp.to_i].min
      user.hp_damage = user_old - user.hp.to_i if user.respond_to?(:hp_damage=)
      @hp_damage = target_old - hp.to_i
      ALBERT_CG::MOVE_EFFECT.log("V231_PAIN_SPLIT user=" + user.name.to_s +
        " target=" + name.to_s + " avg=" + avg.to_s)

    when 244 # Psych Up
      user.cg_v231_copy_stages_from(self)
      ALBERT_CG::MOVE_EFFECT.log("V231_PSYCH_UP user=" + user.name.to_s +
        " source=" + name.to_s)

    when 262 # Memento: v2.3.0 metadata already lowers target ATK/SpA by 2
      loss = user.hp.to_i
      user.hp = 0
      user.hp_damage = loss if user.respond_to?(:hp_damage=)
      ALBERT_CG::MOVE_EFFECT.log("V231_MEMENTO user=" + user.name.to_s +
        " self_ko=true")

    when 287 # Refresh
      ids = [ALBERT_CG::MOVE_EFFECT::STATE_POISON,
             ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON,
             ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS,
             ALBERT_CG::MOVE_EFFECT::STATE_BURN]
      removed = user.cg_v231_cure_primary_statuses(ids)
      ALBERT_CG::MOVE_EFFECT.log("V231_REFRESH user=" + user.name.to_s +
        " removed=" + removed.to_s)

    when 392 # Aqua Ring
      user.cg_v231_add_state_record(ALBERT_CG::MOVE_EFFECT::STATE_AQUA_RING)
      ALBERT_CG::MOVE_EFFECT.log("V231_AQUA_RING user=" + user.name.to_s)

    when 504 # Shell Smash: stage changes are already processed by v2.3.0
      ALBERT_CG::MOVE_EFFECT.log("V231_SHELL_SMASH user=" + user.name.to_s +
        " handled_by_stage_core=true")

    when 576 # Topsy-Turvy
      cg_v231_invert_stages
      ALBERT_CG::MOVE_EFFECT.log("V231_TOPSY_TURVY target=" + name.to_s)

    when 668 # Strength Sap: metadata lowers target ATK; heal user by pre-drop Attack
      gain = [pre_atk.to_i, user.maxhp.to_i - user.hp.to_i].min
      if gain > 0 && !user.state?(ALBERT_CG::MOVE_EFFECT::STATE_HEAL_BLOCK)
        user.hp += gain
        user.hp_damage = -gain if user.respond_to?(:hp_damage=)
      end
      ALBERT_CG::MOVE_EFFECT.log("V231_STRENGTH_SAP user=" + user.name.to_s +
        " target=" + name.to_s + " heal=" + gain.to_s)

    when 685 # Purify
      removed = cg_v231_cure_primary_statuses
      if removed > 0 && !user.state?(ALBERT_CG::MOVE_EFFECT::STATE_HEAL_BLOCK)
        gain = [[user.maxhp.to_i / 2, 1].max, user.maxhp.to_i - user.hp.to_i].min
        user.hp += gain
        user.hp_damage = -gain if user.respond_to?(:hp_damage=)
        ALBERT_CG::MOVE_EFFECT.log("V231_PURIFY user=" + user.name.to_s +
          " target=" + name.to_s + " heal=" + gain.to_s)
      else
        ALBERT_CG::MOVE_EFFECT.log("V231_PURIFY_FAIL user=" + user.name.to_s +
          " target=" + name.to_s)
      end

    when 816 # Jungle Healing: v2.3.0 Generic Heal 已依 scope 對每位盟友回復 25%
      # 本版只補上「解除主要異常」，避免重複回復成 50%。
      removed = cg_v231_cure_primary_statuses
      ALBERT_CG::MOVE_EFFECT.log("V231_JUNGLE_HEAL target=" + name.to_s +
        " generic_heal=25% cured=" + removed.to_s)

    when 114 # Haze
      all = []
      all.concat($game_party.members) if defined?($game_party) && $game_party != nil
      all.concat($game_troop.members) if defined?($game_troop) && $game_troop != nil
      all.each { |b| b.cg_reset_stat_stages if b != nil && b.respond_to?(:cg_reset_stat_stages) }
      ALBERT_CG::MOVE_EFFECT.log("V231_HAZE reset_all_stages=" + all.size.to_s)

    when 499 # Clear Smog
      cg_reset_stat_stages
      ALBERT_CG::MOVE_EFFECT.log("V231_CLEAR_SMOG target=" + name.to_s)
    end
  end

  alias cg_move_v231_critical cg_pokemon_critical?
  def cg_pokemon_critical?(user, obj = nil)
    if user != nil && user.instance_variable_get(:@cg_focus_energy_v231) == true
      if rand(100) < ALBERT_CG::MOVE_EFFECT::FOCUS_ENERGY_CRIT_RATE
        ALBERT_CG::MOVE_EFFECT.log("V231_FOCUS_CRIT user=" + user.name.to_s)
        return true
      end
    end
    return cg_move_v231_critical(user, obj)
  end
end

#==============================================================================
# ■ Scene_Battle：回合結束時清除 Protect / Endure
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_move_v231_turn_end turn_end
  def turn_end
    list = []
    list.concat($game_party.members) if $game_party != nil
    list.concat($game_troop.members) if $game_troop != nil
    list.each do |battler|
      battler.cg_clear_v231_round_flags if battler != nil &&
        battler.respond_to?(:cg_clear_v231_round_flags)
    end
    ALBERT_CG::MOVE_EFFECT.log("V231_TURN_END clear_round_guards=" + list.size.to_s)
    cg_move_v231_turn_end
  end
end

#==============================================================================
# ■ Scene_Title：資料庫載入後安裝 v2.3.1 State
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_move_v231_load_database load_database
  def load_database
    cg_move_v231_load_database
    ALBERT_CG::MOVE_EFFECT.install_v231_states
  end

  alias cg_move_v231_load_bt_database load_bt_database
  def load_bt_database
    cg_move_v231_load_bt_database
    ALBERT_CG::MOVE_EFFECT.install_v231_states
  end
end

#==============================================================================
# ■ Shift+F11 Debug Scenario
#==============================================================================
class Scene_Map < Scene_Base
  alias cg_move_v231_scene_map_update update
  def update
    cg_move_v231_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::MOVE_EFFECT.shift_f11_trigger?
      Sound.play_decision
      ALBERT_CG::MOVE_EFFECT.start_unique_test
    end
  end
end

module ALBERT_CG
  class << self
    alias cg_move_v231_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_move_v231_bootstrap_demo_party
      if ALBERT_CG::MOVE_EFFECT.unique_test_active?
        ALBERT_CG::MOVE_EFFECT::UNIQUE_TEST_ALLIES.each do |cfg|
          ALBERT_CG::MOVE_EFFECT.configure_unique_test_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::MOVE_EFFECT::UNIQUE_TEST_LEVEL, false)
          human.recover_all if human.respond_to?(:recover_all)
        end
      end
      return result
    end
  end
end
