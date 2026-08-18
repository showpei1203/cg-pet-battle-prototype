# RMVX_SCRIPT_INDEX: 193
# RMVX_SCRIPT_ID: 98941289
# RMVX_SCRIPT_NAME: CG Pokemon Action Priority + Auto Regression v2.3.2c
# RMVX_SOURCE_SHA256: 9658d3dbac92dab9dbfe3163bc0958488e03740d82e66556f1ca9b228bc73fd8

#==============================================================================
# ■ CG Pokemon Action Priority + Deterministic Auto Regression v2.3.2c
#==============================================================================
# 【用途】
#  本腳本為 CG Pet Battle Prototype 的正式「技能優先度」核心，以及可重複、可自動
#  完成的戰鬥 Regression Test。它解決 RPG Maker VX 原生只用 AGI＋隨機值排序，
#  無法正確表現 Pokémon 的 Protect／Extreme Speed／Quick Attack／負優先度招式等問題。
#
# 【正式排序規則】
#  1. 先比較 Final Priority；數值越高越先行動。
#  2. Priority 相同時，比較有效 SPE（含既有 cg_order_rate / cg_order_speed 修正）。
#  3. Priority 與 SPE 都相同時，以本回合建立 ActionEntry 的 sequence 穩定排序。
#  4. 同一 Battler 若一回合有多次行動，後一動不得超越自己的前一動。
#
# 【Pokémon Move Priority】
#  Pokémon Move 直接讀 v2.2 Master Data 的原作 priority 欄位：
#    守住 Protect            +4
#    神速 Extreme Speed      +2
#    電光一閃 Quick Attack    +1
#    一般招式                  0
#    借力摔 Vital Throw       -1
#    真氣拳 Focus Punch       -3
#    鏡面反射 Mirror Coat     -5
#  因此不再把 Master Move priority 當作 RPG::Skill#speed 的微小加值來碰運氣。
#
# 【人類技能 Priority】
#  人類一律維持 Tankentai SBS 原生動作，只新增排序資料。技能 Note 可寫：
#      <cg_priority: 1>
#  或：
#      <cg_priority: -2>
#  未設定時預設 0。之後六職業完整技能會直接使用這個欄位。
#
# 【未來 Ability / State / Field 修正介面】
#  Battler 可透過：
#      cg_action_priority_modifier(action)
#  提供額外 Priority 修正。目前預設讀 Actor / Enemy / 裝備 / State Note 中：
#      <cg_priority_mod: 1>
#  後續 Ability Trigger Engine 可 alias 此方法，不必改 Turn Order Core。
#
# 【有效速度】
#  次排序不再使用 VX 原生 rand(AGI)；正式改為穩定的有效 SPE。
#  Pokémon／六維人類優先讀 cg_spe，其他 Battler 回退 agi。
#  仍保留既有：
#      <cg_order_rate: 120>
#      <cg_order_speed: 20>
#  人類技能原本資料庫 Skill#speed 也仍會作為同 Priority 內的次要速度修正。
#  Pokémon Master Move 的 Skill#speed 不採用，因 v2.2 Stub 曾把 priority 暫存於該欄。
#
# 【Debug：Ctrl + F11 確定性自動戰鬥】
#  在地圖按 Ctrl+F11 啟動。玩家不需要輸入任何指令，包括人類 Tom 也由測試器控制。
#  測試器會：
#    - 指定我方／敵方 Pokémon、人類技能、目標、速度覆寫與每回合行動。
#    - 每回合自動恢復 HP/MP，避免前一回合傷害污染排序測試。
#    - 自動記錄 ACTION_ORDER_PLAN 與 ACTION_EXEC。
#    - 自動 ASSERT Priority > SPE、同 Priority 比 SPE、同速 stable tie。
#    - 實測「守住 +4 先於神速 +2，且神速無法造成傷害」。
#    - Protect gameplay ASSERT 只要求 HP 不變、攔截器至少執行一次、下一回合旗標清除。
#    - Tankentai 內部可能讓同一技能進入 effect interceptor 多次，因此「內部重入次數」只記錄診斷，不再錯當成玩家 Action 數。
#    - 實測人類 Note <cg_priority: 1> 能壓過更高速的 Priority 0 Pokémon。
#    - 全部測完後自動 battle_end(0) 回到地圖，輸出 PASS / FAIL。
#
# 【輸出 LOG】
#      Pokemon_Priority_AutoTest_v2_3_2c.log
#  PASS 範例：
#      ASSERT PASS Protect before ExtremeSpeed
#      ASSERT PASS HumanPriority+1 before MewtwoPriority0
#      RESULT=PASS
#  FAIL 時會列出 Expected / Actual 或具體 HP 差異。
#
# 【測試技能】
#  Debug 僅複製既有 Skill 1（Dual Attack）的 SBS 動作，建立兩個不會出現在正式學習表的
#  測試 Skill：
#      1950 AUTO測試・先制技  <cg_priority: 1>
#      1951 AUTO測試・延遲技  <cg_priority: -2>
#  只用來證明人類也走同一 Priority Core；不改六職業正式技能設計。
#
# 【與 PMD 的關係】
#  本腳本只決定「誰先行動」，不修改 v2.3 的 PMD Motion Resolver。
#  Pokémon 行動後仍由 PMD Native / fallback chain 決定 Attack、Shoot、Shock、Pose 等。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_ActionPriority"] = "2.3.2b"

module ALBERT_CG
  module ACTION_PRIORITY
    VERSION = "2.3.2b"
    LOG_FILE = "Pokemon_Priority_AutoTest_v2_3_2c.log"
    TEST_TROOP_ID = 697
    TEST_LEVEL = 30
    DEBUG_HUMAN_FAST_SKILL_ID = 1950
    DEBUG_HUMAN_SLOW_SKILL_ID = 1951

    TEST_ALLIES = [
      {:dex=>25,  :level=>30, :ability=>9,  :moves=>[98,85,86,104]},       # 皮卡丘
      {:dex=>448, :level=>30, :ability=>39, :moves=>[245,396,399,406]},    # 路卡利歐
      {:dex=>3,   :level=>30, :ability=>65, :moves=>[33,75,74,182]},       # 妙蛙花
    ]
    TEST_ENEMIES = [
      {:dex=>9,   :level=>30, :ability=>67,  :moves=>[182,55,44,110]},     # 水箭龜
      {:dex=>150, :level=>30, :ability=>46,  :moves=>[94,247,129,105]},    # 超夢
      {:dex=>143, :level=>30, :ability=>47,  :moves=>[233,34,44,133]},     # 卡比獸
      {:dex=>25,  :level=>30, :ability=>9,   :moves=>[98,85,86,104]},      # 敵方皮卡丘
    ]

    # 測試用有效速度覆寫。正式遊戲不使用這些值。
    # Actor：Tom=50、Pikachu=80、Lucario=60、Venusaur=70
    # Enemy：Blastoise=40、Mewtwo=100、Snorlax=20、Pikachu=80
    TEST_SPEEDS = {
      :human=>50,
      :ally_0=>80,
      :ally_1=>60,
      :ally_2=>70,
      :enemy_0=>40,
      :enemy_1=>100,
      :enemy_2=>20,
      :enemy_3=>80,
    }

    # 每回合一個 Action／Battler。target 為對方陣營 index；self scope 技能忽略 target。
    # Round 1 同時驗證 +4/+2/+1/0/-1、同 Priority 同 SPE stable tie、Protect block、
    # 以及人類 +1 技能壓過更高速的 Mewtwo Priority 0。
    ROUND_PLANS = [
      {
        :name=>"PRIORITY_LADDER_AND_PROTECT",
        :allies=>[
          {:kind=>:skill, :skill_id=>DEBUG_HUMAN_FAST_SKILL_ID, :target=>2}, # Tom +1
          {:kind=>:move,  :move_id=>98,  :target=>2},                       # Quick Attack +1
          {:kind=>:move,  :move_id=>245, :target=>0},                       # Extreme Speed +2 -> Protect
          {:kind=>:move,  :move_id=>33,  :target=>2},                       # Tackle 0
        ],
        :enemies=>[
          {:kind=>:move,  :move_id=>182, :target=>0},                       # Protect +4
          {:kind=>:move,  :move_id=>94,  :target=>0},                       # Psychic 0 -> Tom
          {:kind=>:move,  :move_id=>233, :target=>2},                       # Vital Throw -1 -> Lucario
          {:kind=>:move,  :move_id=>98,  :target=>3},                       # Quick Attack +1 -> Venusaur
        ],
      },
      {
        :name=>"SAME_PRIORITY_SPEED_ORDER",
        :allies=>[
          {:kind=>:attack, :target=>2},                                     # Tom 0 S50
          {:kind=>:move, :move_id=>104, :target=>1},                        # Pikachu Double Team 0 S80
          {:kind=>:move, :move_id=>14,  :target=>2},                        # Lucario Swords Dance 0 S60
          {:kind=>:move, :move_id=>74,  :target=>3},                        # Venusaur Growth 0 S70
        ],
        :enemies=>[
          {:kind=>:move, :move_id=>110, :target=>0},                        # Blastoise Withdraw 0 S40
          {:kind=>:move, :move_id=>133, :target=>1},                        # Mewtwo Amnesia 0 S100
          {:kind=>:move, :move_id=>116, :target=>2},                        # Snorlax Focus Energy 0 S20
          {:kind=>:move, :move_id=>104, :target=>3},                        # Pikachu Double Team 0 S80
        ],
      },
      {
        :name=>"NEGATIVE_PRIORITY",
        :allies=>[
          {:kind=>:skill, :skill_id=>DEBUG_HUMAN_SLOW_SKILL_ID, :target=>0},# Tom -2
          {:kind=>:move, :move_id=>104, :target=>1},                        # Double Team 0
          {:kind=>:move, :move_id=>14,  :target=>2},                        # Swords Dance 0
          {:kind=>:move, :move_id=>74,  :target=>3},                        # Growth 0
        ],
        :enemies=>[
          {:kind=>:move, :move_id=>110, :target=>0},                        # Withdraw 0
          {:kind=>:move, :move_id=>133, :target=>1},                        # Amnesia 0
          {:kind=>:move, :move_id=>233, :target=>2},                        # Vital Throw -1
          {:kind=>:move, :move_id=>104, :target=>3},                        # Double Team 0
        ],
      },
    ]

    def self.master
      return nil unless defined?(ALBERT_CG::POKEMON_MASTER)
      return ALBERT_CG::POKEMON_MASTER
    end

    def self.reset_log
      @failures = []
      @round_index = 0
      @round_actual = []
      @round_expected_entries = []
      @protect_hp_before = nil
      @protect_block_before = nil
      @protect_raw_before = nil
      @protect_cleared_before_round2 = nil
      @active = false
      begin
        File.open(LOG_FILE, "wb") do |f|
          f.write("CG ACTION PRIORITY AUTO REGRESSION v" + VERSION + "\r\n")
          f.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
          f.write("RULE=Priority > EffectiveSPE > StableSequence\r\n")
          f.write("------------------------------------------------------------\r\n")
        end
      rescue
      end
    end

    def self.log(text)
      begin
        File.open(LOG_FILE, "ab") { |f| f.write(text.to_s + "\r\n") }
      rescue
      end
    end

    def self.fail(message)
      @failures = [] if @failures == nil
      @failures.push(message.to_s)
      log("ASSERT FAIL " + message.to_s)
      return false
    end

    def self.pass(message)
      log("ASSERT PASS " + message.to_s)
      return true
    end

    def self.assert(condition, message)
      return condition ? pass(message) : fail(message)
    end

    def self.active?
      return @active == true
    end

    def self.finished?
      return @round_index.to_i >= ROUND_PLANS.size
    end

    def self.current_round_number
      return @round_index.to_i + 1
    end

    def self.current_plan
      return nil if finished?
      return ROUND_PLANS[@round_index.to_i]
    end

    def self.human_actor
      return nil if $game_actors == nil
      return $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
    rescue
      return nil
    end

    def self.test_allies
      return [] if $game_party == nil
      return $game_party.members
    end

    def self.test_enemies
      return [] if $game_troop == nil
      return $game_troop.members
    end

    def self.install_debug_human_skills
      return if $data_skills == nil || $data_skills[1] == nil
      maximum = [DEBUG_HUMAN_FAST_SKILL_ID, DEBUG_HUMAN_SLOW_SKILL_ID].max
      $data_skills.push(nil) while $data_skills.size <= maximum
      base = $data_skills[1]
      begin
        fast = Marshal.load(Marshal.dump(base))
        slow = Marshal.load(Marshal.dump(base))
      rescue
        fast = RPG::Skill.new
        slow = RPG::Skill.new
        fast.base_damage = slow.base_damage = 1
        fast.scope = slow.scope = 1
        fast.hit = slow.hit = 100
      end
      fast.id = DEBUG_HUMAN_FAST_SKILL_ID
      fast.name = "AUTO測試・先制技"
      fast.description = "Debug：人類 Priority +1；沿用 SBS 技能動作。"
      fast.note = fast.note.to_s + "\n<cg_priority: 1>\n<cg_priority_debug>"
      fast.mp_cost = 0
      slow.id = DEBUG_HUMAN_SLOW_SKILL_ID
      slow.name = "AUTO測試・延遲技"
      slow.description = "Debug：人類 Priority -2；沿用 SBS 技能動作。"
      slow.note = slow.note.to_s + "\n<cg_priority: -2>\n<cg_priority_debug>"
      slow.mp_cost = 0
      $data_skills[DEBUG_HUMAN_FAST_SKILL_ID] = fast
      $data_skills[DEBUG_HUMAN_SLOW_SKILL_ID] = slow
    end

    def self.configure_test_actor(cfg)
      m = master
      return nil if m == nil
      actor = $game_actors[m.actor_id_for_dex(cfg[:dex])]
      return nil if actor == nil
      m.configure_actor(actor, cfg)
      actor.cg_reset_stat_stages if actor.respond_to?(:cg_reset_stat_stages)
      actor.cg_clear_v231_battle_flags if actor.respond_to?(:cg_clear_v231_battle_flags)
      return actor
    end

    def self.configure_test_enemy(cfg)
      m = master
      return if m == nil
      m.configure_enemy_data(cfg)
    end

    def self.make_test_troop
      m = master
      return if m == nil
      m.ensure_index($data_troops, TEST_TROOP_ID)
      xs = [ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_BACK_X, ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[2],
            ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[2]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg, index|
        configure_test_enemy(cfg)
        members.push(ALBERT_CG::SPECIES26.make_troop_member(
          m.enemy_id_for_dex(cfg[:dex]), xs[index] || 180, ys[index] || 220))
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID, "Priority Auto Regression v2.3.2", members)
    end

    def self.prepare_test_party
      m = master
      return false if m == nil || $game_party == nil
      ids = TEST_ALLIES.collect { |cfg| m.actor_id_for_dex(cfg[:dex]) }
      if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
        ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids)
      end
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized, true)
      $game_party.cg_enable_direct_pmd_test_party! if
        $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each { |cfg| configure_test_actor(cfg) }
      human = human_actor
      if human != nil
        human.change_level(TEST_LEVEL, false)
        human.recover_all if human.respond_to?(:recover_all)
      end
      return true
    end

    def self.apply_speed_overrides
      allies = test_allies
      enemies = test_enemies
      allies.each_with_index do |battler, index|
        next if battler == nil
        key = index == 0 ? :human : ("ally_" + (index - 1).to_s).to_sym
        battler.instance_variable_set(:@cg_priority_test_speed_override, TEST_SPEEDS[key])
      end
      enemies.each_with_index do |battler, index|
        next if battler == nil
        key = ("enemy_" + index.to_s).to_sym
        battler.instance_variable_set(:@cg_priority_test_speed_override, TEST_SPEEDS[key])
      end
    end

    def self.clear_speed_overrides
      (test_allies + test_enemies).each do |battler|
        next if battler == nil
        battler.instance_variable_set(:@cg_priority_test_speed_override, nil)
      end
    end

    def self.recover_test_battlers
      (test_allies + test_enemies).each do |battler|
        next if battler == nil
        begin
          battler.recover_all
        rescue
          battler.hp = battler.maxhp if battler.respond_to?(:hp=)
          battler.mp = battler.maxmp if battler.respond_to?(:mp=)
        end
        battler.cg_reset_stat_stages if battler.respond_to?(:cg_reset_stat_stages)
        battler.cg_clear_v231_battle_flags if battler.respond_to?(:cg_clear_v231_battle_flags)
      end
    end

    def self.make_action(battler, cfg)
      action = Game_BattleAction.new(battler)
      kind = cfg[:kind]
      if kind == :attack
        action.set_attack
      elsif kind == :guard
        action.set_guard
      elsif kind == :skill
        action.set_skill(cfg[:skill_id].to_i)
      elsif kind == :move
        action.set_skill(master.skill_id_for_move(cfg[:move_id].to_i))
      else
        action.clear
      end
      action.target_index = cfg[:target].to_i if cfg.has_key?(:target)
      return action
    end

    def self.prepare_round_actions
      plan = current_plan
      return false if plan == nil
      recover_test_battlers
      apply_speed_overrides
      @round_actual = []
      @round_expected_entries = []
      @forced_enemy_actions = {}
      log("ROUND " + current_round_number.to_s + " BEGIN " + plan[:name].to_s)

      allies = test_allies
      plan[:allies].each_with_index do |cfg, index|
        battler = allies[index]
        next if battler == nil
        action = make_action(battler, cfg)
        if battler.respond_to?(:cg_round_actions)
          battler.cg_round_actions.clear
          battler.cg_round_actions.push(action)
        end
        battler.cg_assign_action(action) if battler.respond_to?(:cg_assign_action)
        @round_expected_entries.push([battler, action, index])
      end

      enemies = test_enemies
      plan[:enemies].each_with_index do |cfg, index|
        battler = enemies[index]
        next if battler == nil
        action = make_action(battler, cfg)
        @forced_enemy_actions[index] = action
        @round_expected_entries.push([battler, action, allies.size + index])
      end

      # Round 1 Protect 目標 HP 記錄。Extreme Speed 只打 Enemy[0]。
      if current_round_number == 1 && enemies[0] != nil
        @protect_hp_before = enemies[0].hp
        if enemies[0].respond_to?(:cg_protect_action_block_count_v232b)
          @protect_block_before = enemies[0].cg_protect_action_block_count_v232b
        elsif enemies[0].respond_to?(:cg_protect_block_count_v232a)
          @protect_block_before = enemies[0].cg_protect_block_count_v232a
        else
          @protect_block_before = 0
        end
        if enemies[0].respond_to?(:cg_protect_raw_intercept_count_v232b)
          @protect_raw_before = enemies[0].cg_protect_raw_intercept_count_v232b
        else
          @protect_raw_before = 0
        end
      elsif current_round_number == 2 && enemies[0] != nil
        if enemies[0].respond_to?(:cg_protect_active_v232b?)
          @protect_cleared_before_round2 = !enemies[0].cg_protect_active_v232b?
        else
          @protect_cleared_before_round2 = false
        end
      end
      return true
    end

    def self.forced_enemy_action(enemy)
      return nil unless active?
      return nil if @forced_enemy_actions == nil || enemy == nil
      return @forced_enemy_actions[enemy.index]
    end

    def self.action_label(action)
      return "nil" if action == nil
      return "Attack" if action.attack?
      return "Guard" if action.guard?
      if action.skill?
        skill = action.skill
        return skill == nil ? ("Skill#" + action.skill_id.to_s) : skill.name.to_s
      end
      if action.item?
        item = action.item
        return item == nil ? ("Item#" + action.item_id.to_s) : item.name.to_s
      end
      return "Wait"
    end

    def self.battler_label(battler)
      return "nil" if battler == nil
      side = battler.actor? ? "A" : "E"
      idx = battler.respond_to?(:index) ? battler.index.to_i : -1
      return side + idx.to_s + ":" + battler.name.to_s
    end

    def self.record_order_plan(entries)
      return unless active?
      names = []
      entries.each_with_index do |entry, index|
        battler = entry.respond_to?(:battler) ? entry.battler : entry
        action = entry.respond_to?(:action) ? entry.action : (battler == nil ? nil : battler.action)
        next if battler == nil
        p = action == nil ? 0 : action.cg_final_priority
        s = action == nil ? 0 : action.cg_priority_secondary_speed
        seq = entry.respond_to?(:sequence) ? entry.sequence.to_i : index
        label = battler_label(battler)
        names.push(label)
        log("ORDER_PLAN #" + (index + 1).to_s + " " + label +
            " action=" + action_label(action) + " P=" + p.to_s +
            " SPE=" + s.to_s + " seq=" + seq.to_s)
      end
      @planned_names = names
    end

    def self.record_execution(battler, action)
      return unless active?
      return if battler == nil
      @round_actual = [] if @round_actual == nil
      label = battler_label(battler)
      @round_actual.push(label)
      log("ACTION_EXEC #" + @round_actual.size.to_s + " " + label +
          " action=" + action_label(action) + " P=" + action.cg_final_priority.to_s +
          " SPE=" + action.cg_priority_secondary_speed.to_s)
    end

    def self.index_of(list, name)
      return list.index(name)
    end

    def self.assert_before(list, first, second, label)
      a = index_of(list, first)
      b = index_of(list, second)
      return fail(label + " missing=" + [first, second].inspect + " actual=" + list.inspect) if a == nil || b == nil
      return assert(a < b, label + " actual=" + list.inspect)
    end

    def self.finish_round_assertions
      round = current_round_number
      actual = @round_actual == nil ? [] : @round_actual
      planned = @planned_names == nil ? [] : @planned_names
      assert(actual == planned, "Round" + round.to_s + " execution matches planned order expected=" + planned.inspect + " actual=" + actual.inspect)

      if round == 1
        assert_before(actual, "E0:水箭龜", "A2:路卡利歐", "Protect(+4) before ExtremeSpeed(+2)")
        assert_before(actual, "A2:路卡利歐", "A1:皮卡丘", "ExtremeSpeed(+2) before QuickAttack(+1)")
        assert_before(actual, "A1:皮卡丘", "E3:皮卡丘", "Stable tie: ally Pikachu before enemy Pikachu")
        assert_before(actual, "A0:Tom", "E1:超夢", "HumanPriority+1 before MewtwoPriority0")
        assert(actual[-1] == "E2:卡比獸", "VitalThrow(-1) is last")
        enemy0 = test_enemies[0]
        if enemy0 != nil && @protect_hp_before != nil
          assert(enemy0.hp.to_i == @protect_hp_before.to_i,
                 "Protect blocks ExtremeSpeed HP before=" + @protect_hp_before.to_s + " after=" + enemy0.hp.to_s)
          after_blocks = @protect_block_before.to_i
          if enemy0.respond_to?(:cg_protect_action_block_count_v232b)
            after_blocks = enemy0.cg_protect_action_block_count_v232b
            assert(after_blocks.to_i > @protect_block_before.to_i,
                   "Protect gameplay block recorded before=" + @protect_block_before.to_s + " after=" + after_blocks.to_s)
          else
            fail("Protect block API missing")
          end
          if enemy0.respond_to?(:cg_protect_raw_intercept_count_v232b)
            after_raw = enemy0.cg_protect_raw_intercept_count_v232b
            assert(after_raw.to_i > @protect_raw_before.to_i,
                   "Protect raw interceptor executed at least once before=" + @protect_raw_before.to_s + " after=" + after_raw.to_s)
            log("DIAG Protect raw_reentry_delta=" + (after_raw.to_i - @protect_raw_before.to_i).to_s +
                " block_counter_delta=" + (after_blocks.to_i - @protect_block_before.to_i).to_s +
                " note=Tankentai_internal_reentry_is_not_gameplay_action_count")
          else
            fail("Protect raw interceptor API missing")
          end
        else
          fail("Protect HP assertion target missing")
        end
      elsif round == 2
        assert(@protect_cleared_before_round2 == true,
               "Protect round flag cleared before Round2")
        assert_before(actual, "E1:超夢", "A3:妙蛙花", "SamePriority: Mewtwo SPE100 before Venusaur SPE70")
        assert_before(actual, "A3:妙蛙花", "A2:路卡利歐", "SamePriority: Venusaur SPE70 before Lucario SPE60")
        assert_before(actual, "A2:路卡利歐", "A0:Tom", "SamePriority: Lucario SPE60 before Tom SPE50")
        assert(actual[-1] == "E2:卡比獸", "SamePriority: Snorlax SPE20 last")
      elsif round == 3
        assert_before(actual, "E2:卡比獸", "A0:Tom", "Negative priority: VitalThrow(-1) before HumanDelay(-2)")
        assert(actual[-1] == "A0:Tom", "HumanDelay(-2) is last")
      end
      log("ROUND " + round.to_s + " END")
      @round_index = @round_index.to_i + 1
    end

    def self.finish_suite
      clear_speed_overrides
      failures = @failures == nil ? [] : @failures
      if failures.empty?
        log("------------------------------------------------------------")
        log("RESULT=PASS")
        log("SUMMARY rounds=" + ROUND_PLANS.size.to_s + " failures=0")
      else
        log("------------------------------------------------------------")
        log("RESULT=FAIL")
        log("SUMMARY rounds=" + ROUND_PLANS.size.to_s + " failures=" + failures.size.to_s)
        failures.each_with_index { |msg, i| log("FAILURE " + (i + 1).to_s + " " + msg.to_s) }
      end
      @active = false
      return failures.empty?
    end

    begin
      CG_VK_F11 = 0x7A unless const_defined?(:CG_VK_F11)
      CG_VK_CTRL = 0x11 unless const_defined?(:CG_VK_CTRL)
      CG_GET_ASYNC_KEY_STATE = Win32API.new("user32", "GetAsyncKeyState", "i", "i") unless
        const_defined?(:CG_GET_ASYNC_KEY_STATE)
    rescue
      CG_GET_ASYNC_KEY_STATE = nil unless const_defined?(:CG_GET_ASYNC_KEY_STATE)
    end

    def self.ctrl_down?
      api = CG_GET_ASYNC_KEY_STATE
      return false if api == nil
      return (api.call(CG_VK_CTRL) & 0x8000) != 0
    rescue
      return false
    end

    def self.ctrl_f11_trigger?
      api = CG_GET_ASYNC_KEY_STATE
      return false if api == nil
      down = ((api.call(CG_VK_F11) & 0x8000) != 0) && ctrl_down?
      trigger = down && @ctrl_f11_down != true
      @ctrl_f11_down = down
      return trigger
    rescue
      return false
    end

    def self.start_auto_test
      reset_log
      install_debug_human_skills
      if defined?(ALBERT_CG::MOVE_EFFECT)
        ALBERT_CG::MOVE_EFFECT.instance_variable_set(:@effect_test_active, false)
        ALBERT_CG::MOVE_EFFECT.instance_variable_set(:@v231_unique_test_active, false)
      end
      prepare_test_party
      make_test_troop
      @active = true
      log("AUTO_TEST_START troop=" + TEST_TROOP_ID.to_s)
      log("MOVE_PRIORITY Protect=" + master.move(182)[6].to_s +
          " ExtremeSpeed=" + master.move(245)[6].to_s +
          " QuickAttack=" + master.move(98)[6].to_s +
          " VitalThrow=" + master.move(233)[6].to_s)
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    end
  end
end

#==============================================================================
# ■ RPG::BaseItem / Skill：Priority Note 與 Pokémon Master Move Priority
#==============================================================================
class RPG::BaseItem
  def cg_priority_note_value
    return 0 if @note == nil
    return $1.to_i if @note.to_s =~ /<cg_priority\s*:\s*([+-]?\d+)\s*>/i
    return 0
  end

  def cg_priority_mod_note_value
    return 0 if @note == nil
    return $1.to_i if @note.to_s =~ /<cg_priority_mod\s*:\s*([+-]?\d+)\s*>/i
    return 0
  end
end

class RPG::Skill < RPG::UsableItem
  def cg_pokemon_master_move_id
    return $1.to_i if @note.to_s =~ /<pokemon_master_move\s*:\s*(\d+)\s*>/i
    if @id.to_i >= 1001 && @id.to_i <= 1937 && defined?(ALBERT_CG::POKEMON_MASTER)
      mid = @id.to_i - 1000
      return mid if ALBERT_CG::POKEMON_MASTER.move(mid) != nil
    end
    return 0
  rescue
    return 0
  end

  def cg_action_priority_value
    # 顯式 Note 永遠優先，供人類技能或特殊 RPG 技能使用。
    if @note.to_s =~ /<cg_priority\s*:\s*([+-]?\d+)\s*>/i
      return $1.to_i
    end
    mid = cg_pokemon_master_move_id
    if mid > 0 && defined?(ALBERT_CG::POKEMON_MASTER)
      row = ALBERT_CG::POKEMON_MASTER.move(mid)
      return row[6].to_i if row != nil
    end
    return 0
  rescue
    return 0
  end
end

#==============================================================================
# ■ Game_Battler：有效 SPE 與未來 Priority Modifier Hook
#==============================================================================
class Game_Battler
  def cg_priority_base_speed
    override = @cg_priority_test_speed_override
    return override.to_i if ALBERT_CG::ACTION_PRIORITY.active? && override != nil
    if respond_to?(:cg_spe)
      value = cg_spe.to_i
      return value if value > 0
    end
    return agi.to_i
  rescue
    return agi.to_i
  end

  def cg_action_priority_modifier(action = nil)
    total = 0
    sources = []
    if respond_to?(:cg_order_note_sources)
      sources.concat(cg_order_note_sources)
    end
    if respond_to?(:states)
      states.each { |state| sources.push(state) if state != nil }
    end
    sources.each do |source|
      next unless source.respond_to?(:cg_priority_mod_note_value)
      total += source.cg_priority_mod_note_value.to_i
    end
    return total
  rescue
    return 0
  end
end

#==============================================================================
# ■ Game_BattleAction：Final Priority 與 deterministic secondary SPE
#==============================================================================
class Game_BattleAction
  attr_accessor :cg_priority_rank
  attr_accessor :cg_priority_speed_rank

  def cg_base_priority
    return 4 if guard?
    if skill?
      obj = skill
      return obj == nil ? 0 : obj.cg_action_priority_value.to_i
    end
    if item?
      obj = item
      return obj.respond_to?(:cg_priority_note_value) ? obj.cg_priority_note_value.to_i : 0
    end
    if attack? && @battler != nil && @battler.respond_to?(:fast_attack) && @battler.fast_attack
      return 1
    end
    return 0
  rescue
    return 0
  end

  def cg_final_priority
    base = cg_base_priority
    mod = @battler != nil && @battler.respond_to?(:cg_action_priority_modifier) ?
      @battler.cg_action_priority_modifier(self).to_i : 0
    return base + mod
  end

  def cg_pokemon_master_skill?
    return false unless skill?
    obj = skill
    return obj != nil && obj.respond_to?(:cg_pokemon_master_move_id) && obj.cg_pokemon_master_move_id.to_i > 0
  end

  def cg_priority_secondary_speed
    return @cg_priority_speed_rank.to_i if @cg_priority_speed_rank != nil
    battler = @battler
    return 0 if battler == nil
    speed = battler.respond_to?(:cg_priority_base_speed) ? battler.cg_priority_base_speed.to_i : battler.agi.to_i
    rate = battler.respond_to?(:cg_order_speed_rate) ? battler.cg_order_speed_rate.to_i : 100
    speed = speed * rate / 100
    object = nil
    object = skill if skill?
    object = item if item?
    if object != nil && object.respond_to?(:cg_order_speed_bonus)
      speed += object.cg_order_speed_bonus.to_i
    end
    # Pokémon Master Stub 的 RPG::Skill#speed 曾暫存原作 priority，這裡不可重複加。
    if object != nil && object.respond_to?(:speed) && !cg_pokemon_master_skill?
      speed += object.speed.to_i
    end
    return speed
  rescue
    return 0
  end

  # v2.3.2 起取消 VX 原生 AGI 隨機浮動，讓同 Priority 真的按有效 SPE 排序。
  # @speed 仍保留給既有 Action Order UI / Dual Action rapidity 使用。
  def make_speed
    @cg_priority_speed_rank = nil
    @speed = cg_priority_secondary_speed
  end
end

#==============================================================================
# ■ Game_Enemy：Auto Regression 時強制指定 Enemy Action
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_priority_v232_enemy_make_action make_action
  def make_action
    if ALBERT_CG::ACTION_PRIORITY.active?
      forced = ALBERT_CG::ACTION_PRIORITY.forced_enemy_action(self)
      if forced != nil
        cg_assign_action(forced.cg_copy_for(self)) if respond_to?(:cg_assign_action)
        @action = forced.cg_copy_for(self) unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_priority_v232_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle：全局 Priority Sort + Auto Regression 控制
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_priority_v232_make_action_orders make_action_orders
  def make_action_orders
    cg_priority_v232_make_action_orders
    return if @action_battlers == nil

    # 先按原始 sequence 取得同 Battler 多行動限制，再做 Priority sort。
    ordered = @action_battlers.select { |entry| entry.is_a?(ALBERT_CG::ActionEntry) }
    ordered.sort! { |a,b| a.sequence.to_i <=> b.sequence.to_i }
    previous = {}
    ordered.each do |entry|
      action = entry.action
      next if action == nil
      p = action.cg_final_priority.to_i
      s = action.speed.to_i
      key = entry.battler.object_id
      if previous.has_key?(key)
        pp, ps = previous[key]
        if p > pp
          p = pp
          s = ps if s > ps
        elsif p == pp && s > ps
          s = ps
        end
      end
      action.cg_priority_rank = p
      action.cg_priority_speed_rank = s
      previous[key] = [p, s]
    end

    @action_battlers.sort! do |a, b|
      aa = a.is_a?(ALBERT_CG::ActionEntry) ? a.action : a.action
      ba = b.is_a?(ALBERT_CG::ActionEntry) ? b.action : b.action
      ap = aa == nil ? 0 : (aa.cg_priority_rank == nil ? aa.cg_final_priority : aa.cg_priority_rank).to_i
      bp = ba == nil ? 0 : (ba.cg_priority_rank == nil ? ba.cg_final_priority : ba.cg_priority_rank).to_i
      if ap != bp
        bp <=> ap
      else
        as = aa == nil ? 0 : aa.cg_priority_secondary_speed.to_i
        bs = ba == nil ? 0 : ba.cg_priority_secondary_speed.to_i
        if as != bs
          bs <=> as
        else
          aseq = a.respond_to?(:sequence) ? a.sequence.to_i : 999999
          bseq = b.respond_to?(:sequence) ? b.sequence.to_i : 999999
          aseq <=> bseq
        end
      end
    end

    ALBERT_CG::ACTION_PRIORITY.record_order_plan(@action_battlers) if
      ALBERT_CG::ACTION_PRIORITY.active?
    if @cg_action_order_window != nil
      @cg_action_order_window.set_order(nil, nil, @action_battlers)
    end
  end

  alias cg_priority_v232_start_party_command start_party_command_selection
  def start_party_command_selection
    unless ALBERT_CG::ACTION_PRIORITY.active?
      return cg_priority_v232_start_party_command
    end

    cg_priority_v232_start_party_command
    return unless $game_temp.in_battle
    if ALBERT_CG::ACTION_PRIORITY.finished?
      ALBERT_CG::ACTION_PRIORITY.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ACTION_PRIORITY.prepare_round_actions
    start_main
  end

  alias cg_priority_v232_execute_action execute_action
  def execute_action
    if ALBERT_CG::ACTION_PRIORITY.active? && @active_battler != nil
      ALBERT_CG::ACTION_PRIORITY.record_execution(@active_battler, @active_battler.action)
    end
    cg_priority_v232_execute_action
  end

  alias cg_priority_v232_turn_end turn_end
  def turn_end
    ALBERT_CG::ACTION_PRIORITY.finish_round_assertions if
      ALBERT_CG::ACTION_PRIORITY.active?
    cg_priority_v232_turn_end
  end
end

#==============================================================================
# ■ Scene_Title：Debug Human Priority Skill 安裝
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_priority_v232_load_database load_database
  def load_database
    cg_priority_v232_load_database
    ALBERT_CG::ACTION_PRIORITY.install_debug_human_skills
  end

  alias cg_priority_v232_load_bt_database load_bt_database
  def load_bt_database
    cg_priority_v232_load_bt_database
    ALBERT_CG::ACTION_PRIORITY.install_debug_human_skills
  end
end

#==============================================================================
# ■ Scene_Map：Ctrl+F11 Auto Regression；避免與 F11 / Shift+F11 撞鍵
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    class << self
      alias cg_priority_v232_old_f11_trigger f11_trigger?
    end
    def self.f11_trigger?
      return false if ALBERT_CG::ACTION_PRIORITY.ctrl_down?
      return cg_priority_v232_old_f11_trigger
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_priority_v232_scene_map_update update
  def update
    cg_priority_v232_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::ACTION_PRIORITY.ctrl_f11_trigger?
      Sound.play_decision
      ALBERT_CG::ACTION_PRIORITY.start_auto_test
    end
  end
end

#==============================================================================
# ■ bootstrap_demo_party：Battle Scene 重建隊伍後再次套用測試組成
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_priority_v232_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_priority_v232_bootstrap_demo_party
      if ALBERT_CG::ACTION_PRIORITY.active?
        ALBERT_CG::ACTION_PRIORITY::TEST_ALLIES.each do |cfg|
          ALBERT_CG::ACTION_PRIORITY.configure_test_actor(cfg)
        end
        human = ALBERT_CG::ACTION_PRIORITY.human_actor
        if human != nil
          human.change_level(ALBERT_CG::ACTION_PRIORITY::TEST_LEVEL, false)
          human.recover_all if human.respond_to?(:recover_all)
        end
      end
      return result
    end
  end
end
