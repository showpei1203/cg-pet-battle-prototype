# RMVX_SCRIPT_INDEX: 225
# RMVX_SCRIPT_ID: 256000002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch G v2.5.6
# RMVX_SOURCE_SHA256: 3bee849398dfff9af7f500648463cc1ab37d14eecc6750032aba68307a717508

#==============================================================================
# ■ CG Pokemon Ability Batch G v2.5.6 - Stat Guard + Critical Shield
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.5a Ability Batch F PASS 基底上，正式實作第七批 8 個防護型 Ability，
#  並以 Actual Scene_Battle deterministic F11 regression 驗證 Move stage drop、
#  Critical Guard、Teleport reserve lifecycle 與 Storage isolation。
#
# 【本批 Ability】
#   4   Battle Armor    戰鬥盔甲：不會被 Critical Hit。
#   29  Clear Body      恆淨之軀：阻擋敵方造成的所有能力階級下降。
#   51  Keen Eye        銳利目光：阻擋敵方造成的 Accuracy 階級下降。
#   52  Hyper Cutter    怪力鉗：阻擋敵方造成的 Attack 階級下降。
#   73  White Smoke     白色煙霧：阻擋敵方造成的所有能力階級下降。
#   75  Shell Armor     硬殼盔甲：不會被 Critical Hit。
#   145 Big Pecks       健壯胸肌：阻擋敵方造成的 Defense 階級下降。
#   230 Full Metal Body 金屬防護：阻擋敵方造成的所有能力階級下降。
#
# 【主要設定項】
#  TEST_TROOP_ID=709；TEST_SPEEDS 固定每回合順序。
#
# 【機制規則】
#  1. 正式效果由 Stat Guard Authority v2.5.6 統一攔截，不修改 Move 937 已封版資料。
#  2. Round1 使用 Sand Attack / Screech / Charm 等真正 Move stage effect 驗證五種 Stat Guard，
#     並 test-only 強制一次 Critical candidate 驗 Battle Armor。
#  3. Round2 Tackle Shell Armor，test-only 強制 Critical candidate；Shell Armor 同回合使用
#     Teleport，將 hidden Full Metal Body reserve 正式換入。
#  4. Round3 Screech 換入後的 Full Metal Body，確認 reserve 仍保有 Ability 並阻擋 Defense drop。
#  5. Regression 固定 hit/evasion/SPE/critical candidate；正式玩家 RNG 完全不變。
#  6. 所有 Ability 一律讀 cg_master_ability_id，尊重 Ability override/suppression。
#
# 【可調參數】
#  TEST_TROOP_ID / TEST_SPEEDS / ROUND_PLANS。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，自動跑三回合並輸出
#  Pokemon_Ability_G_AutoTest_v2_5_6.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Sand Attack -> Keen Eye：Accuracy stage 保持 0。
#  Charm -> Hyper Cutter：Atk stage 保持 0。
#  Tackle -> Shell Armor：Regression 強制候選暴擊，但最終 Critical 被取消。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchG"] = "2.5.6"

module ALBERT_CG
  module ABILITY_G_V256
    VERSION = "2.5.6"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 709
    VK_F11 = 0x7A

    ABILITY_BATTLE_ARMOR    = 4
    ABILITY_CLEAR_BODY      = 29
    ABILITY_KEEN_EYE        = 51
    ABILITY_HYPER_CUTTER    = 52
    ABILITY_WHITE_SMOKE     = 73
    ABILITY_SHELL_ARMOR     = 75
    ABILITY_BIG_PECKS       = 145
    ABILITY_FULL_METAL_BODY = 230

    HANDLED_ABILITY_IDS = [4,29,51,52,73,75,145,230]

    TEST_ALLIES = [
      {:dex=>196,:level=>40,:ability=>ABILITY_CLEAR_BODY,  :moves=>[28,33,103,150]},
      {:dex=>143,:level=>40,:ability=>ABILITY_HYPER_CUTTER,:moves=>[103,150,150,150]},
      {:dex=>134,:level=>40,:ability=>ABILITY_BATTLE_ARMOR,:moves=>[103,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>133,:level=>40,:ability=>ABILITY_WHITE_SMOKE,    :moves=>[204,150,150,150]},
      {:dex=>448,:level=>40,:ability=>ABILITY_KEEN_EYE,       :moves=>[28,150,33,150]},
      {:dex=>47, :level=>40,:ability=>ABILITY_BIG_PECKS,      :moves=>[33,150,150,150]},
      {:dex=>24, :level=>40,:ability=>ABILITY_SHELL_ARMOR,    :moves=>[150,100,150,150]},
      {:dex=>57, :level=>40,:ability=>ABILITY_FULL_METAL_BODY,:moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"STAT_GUARD_AND_BATTLE_ARMOR",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>28,:target=>1},
          {:kind=>:move,:move_id=>103,:target=>2},
          {:kind=>:move,:move_id=>103,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>204,:target=>2},
          1=>{:kind=>:move,:move_id=>28,:target=>1},
          2=>{:kind=>:move,:move_id=>33,:target=>3},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"SHELL_ARMOR_AND_FULL_METAL_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>3},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>100,:target=>0},
        }
      },
      {
        :name=>"FULL_METAL_BODY_AFTER_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>103,:target=>4},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>33,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,240,230,220, 210,200,190,180,0],
      :r2=>[10,240,230,220, 210,200,190,180,0],
      :r3=>[10,240,230,220, 210,200,190,0,180],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M28","A2:M103","A3:M103","E0:M204","E1:M28","E2:M33","E3:M150"],
      2=>["A0:Guard","A1:M33","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","A1:M103","A2:M150","A3:M150","E0:M150","E1:M33","E2:M150","E4:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.master; return defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.active?; return @active == true; end
    def self.current_round; return @round_index.to_i + 1; end
    def self.current_plan; return ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; return @round_index.to_i >= ROUND_PLANS.size; end
    def self.test_allies; return $game_party == nil ? [] : $game_party.members; end
    def self.all_enemies; return $game_troop == nil ? [] : $game_troop.members; end
    def self.project_root; return Dir.pwd; rescue; return "."; end
    def self.log_path; return File.join(project_root,"Pokemon_Ability_G_AutoTest_v2_5_6.log"); end
    def self.latest_log_path; return File.join(project_root,"CG_AutoRegression_LATEST.log"); end

    def self.write_line(path,text,mode="ab")
      File.open(path,mode) { |f| f.write(text.to_s + "\r\n") }
      return true
    rescue
      return false
    end
    def self.log(text)
      write_line(log_path,text.to_s)
      write_line(latest_log_path,text.to_s)
      if defined?(ALBERT_CG::PMD_INIT_TRACE) && ALBERT_CG::PMD_INIT_TRACE.respond_to?(:log)
        if text.to_s.index("ASSERT ") == 0 || text.to_s.index("ABILITY_") == 0 ||
           text.to_s.index("ROUND ") == 0 || text.to_s.index("RESULT=") == 0 ||
           text.to_s.index("SUMMARY ") == 0
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_G_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end
    def self.reset_log
      header = "CG POKEMON ABILITY G STAT GUARD + CRITICAL SHIELD AUTO REGRESSION v2.5.6\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; Move stat guards + critical guards + reserve switch\r\n" +
        "BASELINE=v2.5.5a Ability Batch F Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_B_C_D_E_F_PASS=48 BATCH_G=8 PENDING=317\r\n" +
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n" +
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n" +
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb") { |f| f.write(header) }
      File.open(latest_log_path,"wb") { |f| f.write(header) }
    rescue
    end

    def self.key_down?(code)
      return false if KEY_API == nil
      return (KEY_API.call(code) & 0x8000) != 0
    rescue
      return false
    end
    def self.f11_trigger?
      down = key_down?(VK_F11)
      trigger = down && @f11_down != true
      @f11_down = down
      return trigger
    end
    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS " + label.to_s + (detail == nil ? "" : " " + detail.to_s))
      else
        text = label.to_s + (detail == nil ? "" : " " + detail.to_s)
        @failures.push(text)
        log("ASSERT FAIL " + text)
      end
      return condition
    end
    def self.battler_token(b)
      return "nil" if b == nil
      return (b.actor? ? "A" : "E") + b.index.to_i.to_s
    rescue
      return "?"
    end

    def self.note_external_trigger(aid,battler,kind,ctx=nil)
      @ability_trigger_counts[aid.to_i] = @ability_trigger_counts[aid.to_i].to_i + 1
      if kind.to_sym == :stat_guard
        @stat_guard_events.push([aid.to_i,battler,ctx])
      elsif kind.to_sym == :critical_guard
        @critical_guard_events.push([aid.to_i,battler,ctx])
      elsif kind.to_sym == :evasion_ignore
        @keen_eye_ignore_events += 1
      end
      log("ABILITY_G_TRIGGER ability=" + aid.to_i.to_s + " battler=" + battler_token(battler) +
        " kind=" + kind.to_s)
      return true
    rescue
      return false
    end

    def self.force_critical_candidate?(target,user,obj=nil)
      return false unless active? && target != nil && user != nil
      mid = 0
      mid = ALBERT_CG::MOVE_EFFECT.move_id(obj).to_i if obj != nil && defined?(ALBERT_CG::MOVE_EFFECT)
      return true if current_round == 1 && target.actor? && target.index.to_i == 3 &&
        !user.actor? && user.index.to_i == 2 && mid == 33
      return true if current_round == 2 && !target.actor? && target.index.to_i == 3 &&
        user.actor? && user.index.to_i == 1 && mid == 33
      return false
    rescue
      return false
    end

    def self.configure_actor(cfg)
      actor = $game_actors[master.actor_id_for_dex(cfg[:dex])]
      return if actor == nil
      master.configure_actor(actor,cfg)
      actor.recover_all if actor.respond_to?(:recover_all)
      actor.cg_reset_stat_stages if actor.respond_to?(:cg_reset_stat_stages)
      actor.cg_v242_clear_runtime if actor.respond_to?(:cg_v242_clear_runtime)
    end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end

    def self.prepare_test_party
      ids = TEST_ALLIES.collect { |cfg| master.actor_id_for_dex(cfg[:dex]) }
      if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
        ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids)
      end
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      for cfg in TEST_ALLIES; configure_actor(cfg); end
      human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if human != nil
        human.change_level(TEST_LEVEL,false)
        human.recover_all
        human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
        human.instance_variable_set(:@cg_master_ability_id,0)
      end
    end

    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs = [ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],
            ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg,i|
        configure_enemy(cfg)
        m = ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]),xs[i],ys[i])
        m.hidden = (i >= 4)
        members.push(m)
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID,"Pokemon Ability G v2.5.6 AutoRegression",members)
    end

    def self.make_action(battler,cfg)
      action = Game_BattleAction.new(battler)
      if cfg[:kind] == :guard
        action.set_guard
      elsif cfg[:kind] == :move
        action.set_skill(master.skill_id_for_move(cfg[:move_id].to_i))
      else
        action.clear
      end
      action.target_index = cfg[:target].to_i if cfg.has_key?(:target)
      return action
    end
    def self.forced_enemy_action(enemy)
      return nil unless active? && enemy != nil && !enemy.hidden && enemy.hp.to_i > 0
      plan = current_plan
      return nil if plan == nil
      cfg = plan[:enemies][enemy.index]
      return cfg == nil ? nil : make_action(enemy,cfg)
    end

    def self.apply_test_speeds
      vals = TEST_SPEEDS[("r" + current_round.to_s).to_sym] || []
      list = test_allies + all_enemies
      list.each_with_index do |b,i|
        b.instance_variable_set(:@cg_priority_test_speed_override,vals[i]) if b != nil
      end
    end
    def self.storage_size
      return 0 unless defined?(ALBERT_CG::PET_STORAGE) && ALBERT_CG::PET_STORAGE.respond_to?(:size)
      return ALBERT_CG::PET_STORAGE.size.to_i
    rescue
      return 0
    end

    def self.prepare_round_preconditions
      a = test_allies
      e = all_enemies
      if current_round == 1
        (a + e).each { |b| b.cg_reset_stat_stages if b != nil && b.respond_to?(:cg_reset_stat_stages) }
      elsif current_round == 2
        @r2_storage_before = storage_size
        e[4].recover_all if e[4] != nil && e[4].respond_to?(:recover_all)
      elsif current_round == 3
        e[4].cg_reset_stat_stages if e[4] != nil && e[4].respond_to?(:cg_reset_stat_stages)
        if a[1] != nil && a[1].respond_to?(:cg_change_stat_stage)
          ALBERT_CG::ABILITY_STAT_GUARD_V256.with_stage_source(a[1],:regression_self,false) do
            a[1].cg_change_stat_stage(:evasion,2)
          end
        end
      end
    end

    def self.prepare_round_actions
      plan = current_plan
      return false if plan == nil
      apply_test_speeds
      prepare_round_preconditions
      @actual = []
      log("ROUND " + current_round.to_s + " BEGIN " + plan[:name].to_s)
      test_allies.each_with_index do |b,i|
        next if b == nil
        action = make_action(b,plan[:allies][i])
        if b.respond_to?(:cg_round_actions)
          b.cg_round_actions.clear
          b.cg_round_actions.push(action)
        end
        b.cg_assign_action(action) if b.respond_to?(:cg_assign_action)
        b.instance_variable_set(:@action,action) unless b.respond_to?(:cg_assign_action)
      end
      return true
    end

    def self.record_execution(battler)
      return unless active? && battler != nil
      action = battler.action
      prefix = battler.actor? ? "A" : "E"
      token = nil
      if action != nil && action.guard?
        token = prefix + battler.index.to_s + ":Guard"
      elsif action != nil && action.skill?
        mid = ALBERT_CG::MOVE_EFFECT.move_id(action.skill).to_i
        token = prefix + battler.index.to_s + ":M" + mid.to_s
      elsif action != nil && action.attack?
        token = prefix + battler.index.to_s + ":Attack"
      else
        token = prefix + battler.index.to_s + ":Other"
      end
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + battler.name.to_s + " token=" + token)
    rescue
    end

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted = true
      a = test_allies
      e = all_enemies
      actual_troop_id = ($game_troop != nil && $game_troop.troop != nil) ? $game_troop.troop.id.to_i : 0
      assert_true("Ability Catalog count=373",defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.catalog_count == 373,
        "actual=" + (defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.catalog_count.to_s : "nil"))
      assert_true("Ability Batch G declares 8 IDs",HANDLED_ABILITY_IDS.size == 8)
      assert_true("Scene_Battle uses Ability G test troop",actual_troop_id == TEST_TROOP_ID,"actual=" + actual_troop_id.to_s)
      assert_true("Ability G ally count=4",a.size == 4,"actual=" + a.size.to_s)
      assert_true("Ability G starts with 4 active enemies",e.select { |b| b != nil && !b.hidden }.size == 4)
      assert_true("Ability G starts with 1 hidden Full Metal Body reserve",e.select { |b| b != nil && b.hidden }.size == 1)
    end

    def self.stat_stage(b,key)
      return 0 if b == nil || !b.respond_to?(:cg_stat_stage)
      return b.cg_stat_stage(key).to_i
    rescue
      return 0
    end

    def self.assert_round
      r = current_round
      a = test_allies
      e = all_enemies
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      if r == 1
        checks = [
          ["Keen Eye blocks Sand Attack Accuracy drop",stat_stage(e[1],:accuracy) == 0,"stage=" + stat_stage(e[1],:accuracy).to_s],
          ["Big Pecks blocks Screech Defense drop",stat_stage(e[2],:def) == 0,"stage=" + stat_stage(e[2],:def).to_s],
          ["White Smoke blocks Screech Defense drop",stat_stage(e[0],:def) == 0,"stage=" + stat_stage(e[0],:def).to_s],
          ["Hyper Cutter blocks Charm Attack drop",stat_stage(a[2],:atk) == 0,"stage=" + stat_stage(a[2],:atk).to_s],
          ["Clear Body blocks Sand Attack Accuracy drop",stat_stage(a[1],:accuracy) == 0,"stage=" + stat_stage(a[1],:accuracy).to_s],
        ]
        checks.each do |row|
          @stat_guard_checks += 1 if row[1]
          assert_true(row[0],row[1],row[2])
        end
        crit_ok = @ability_trigger_counts[ABILITY_BATTLE_ARMOR].to_i > 0
        @critical_guard_checks += 1 if crit_ok
        assert_true("Battle Armor cancels forced critical candidate",crit_ok,
          "count=" + @ability_trigger_counts[ABILITY_BATTLE_ARMOR].to_i.to_s)
      elsif r == 2
        crit_ok = @ability_trigger_counts[ABILITY_SHELL_ARMOR].to_i > 0
        @critical_guard_checks += 1 if crit_ok
        assert_true("Shell Armor cancels forced critical candidate",crit_ok,
          "count=" + @ability_trigger_counts[ABILITY_SHELL_ARMOR].to_i.to_s)
        switched = e[3] != nil && e[4] != nil && e[3].hidden && !e[4].hidden
        @lifecycle_checks += 1 if switched
        assert_true("Teleport deploys hidden Full Metal Body reserve",switched,
          "E3_hidden=" + (e[3] == nil ? "nil" : e[3].hidden.to_s) + " E4_hidden=" + (e[4] == nil ? "nil" : e[4].hidden.to_s))
        storage_ok = storage_size == @r2_storage_before.to_i
        @lifecycle_checks += 1 if storage_ok
        assert_true("Full Metal Body reserve switch does not consume Storage Pokemon",storage_ok,
          "before=" + @r2_storage_before.to_s + " after=" + storage_size.to_s)
      elsif r == 3
        full_ok = e[4] != nil && !e[4].hidden && stat_stage(e[4],:def) == 0 &&
          @ability_trigger_counts[ABILITY_FULL_METAL_BODY].to_i > 0
        @stat_guard_checks += 1 if full_ok
        assert_true("Full Metal Body blocks Screech after real reserve switch-in",full_ok,
          "stage=" + stat_stage(e[4],:def).to_s + " trigger=" + @ability_trigger_counts[ABILITY_FULL_METAL_BODY].to_i.to_s)
        keen_ok = @keen_eye_ignore_events.to_i > 0 && stat_stage(a[1],:evasion) == 2
        @accuracy_checks += 1 if keen_ok
        assert_true("Keen Eye ignores target positive Evasion while attacking",keen_ok,
          "events=" + @keen_eye_ignore_events.to_i.to_s + " target_evasion=" + stat_stage(a[1],:evasion).to_s)
      end
      log("ROUND " + r.to_s + " END")
    end

    def self.finish_round_assertions
      return unless active?
      assert_round
      @round_index += 1
    end
    def self.ability_covered_count
      count = 0
      HANDLED_ABILITY_IDS.each { |aid| count += 1 if @ability_trigger_counts[aid].to_i > 0 }
      return count
    end
    def self.cleanup_test_overrides
      (test_allies + all_enemies).each do |b|
        b.instance_variable_set(:@cg_priority_test_speed_override,nil) if b != nil
      end
    end
    def self.finish_suite
      for aid in HANDLED_ABILITY_IDS
        assert_true("Ability " + aid.to_s + " triggered",@ability_trigger_counts[aid].to_i > 0,
          "count=" + @ability_trigger_counts[aid].to_i.to_s)
      end
      result = @failures.empty? ? "PASS" : "FAIL"
      log("------------------------------------------------------------")
      log("RESULT=" + result)
      log("SUMMARY rounds=3 failures=" + @failures.size.to_s +
        " ability_g=" + ability_covered_count.to_s + "/8" +
        " stat_guard_checks=" + @stat_guard_checks.to_i.to_s +
        " critical_guard_checks=" + @critical_guard_checks.to_i.to_s +
        " accuracy_checks=" + @accuracy_checks.to_i.to_s +
        " lifecycle_checks=" + @lifecycle_checks.to_i.to_s + " pending=317")
      @failures.each_with_index { |x,i| log("FAILURE " + (i+1).to_s + " " + x.to_s) }
      cleanup_test_overrides
      @active = false
      if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
        ALBERT_CG::TEST_CONVENIENCE.finish_session
      end
    end
    def self.reset_suite
      @round_index = 0
      @failures = []
      @ability_trigger_counts = {}
      @stat_guard_events = []
      @critical_guard_events = []
      @stat_guard_checks = 0
      @critical_guard_checks = 0
      @accuracy_checks = 0
      @keen_eye_ignore_events = 0
      @lifecycle_checks = 0
      @actual = []
      @boot_asserted = false
      @r2_storage_before = 0
    end

    def self.start_auto_test
      return false if active?
      reset_log
      reset_suite
      prepare_test_party
      make_test_troop
      if defined?(ALBERT_CG::UNIQUE_I_V242) && ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes)
        ALBERT_CG::UNIQUE_I_V242.install_skill_scopes
      end
      @active = true
      if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
        ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_G_v2.5.6")
      end
      log("AUTO_TEST_START troop=" + TEST_TROOP_ID.to_s)
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue => e
      @failures = [] if @failures == nil
      @failures.push("AUTO_TEST_START_ERROR " + e.class.to_s + ":" + e.message.to_s)
      log(@failures[-1])
      @active = false
      if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
        ALBERT_CG::TEST_CONVENIENCE.finish_session
      end
      return false
    end
  end
end

#==============================================================================
# ■ Older Ability regression F11：Batch G 成為唯一最新版
#==============================================================================
if defined?(ALBERT_CG::ABILITY_F_V255)
  module ALBERT_CG; module ABILITY_F_V255; def self.f11_trigger?; return false; end; end; end
end
if defined?(ALBERT_CG::ABILITY_E_V254)
  module ALBERT_CG; module ABILITY_E_V254; def self.f11_trigger?; return false; end; end; end
end
if defined?(ALBERT_CG::ABILITY_D_V253)
  module ALBERT_CG; module ABILITY_D_V253; def self.f11_trigger?; return false; end; end; end
end
if defined?(ALBERT_CG::ABILITY_C_V252)
  module ALBERT_CG; module ABILITY_C_V252; def self.f11_trigger?; return false; end; end; end
end
if defined?(ALBERT_CG::ABILITY_B_V251)
  module ALBERT_CG; module ABILITY_B_V251; def self.f11_trigger?; return false; end; end; end
end
if defined?(ALBERT_CG::ABILITY_A_V250)
  module ALBERT_CG; module ABILITY_A_V250; def self.f11_trigger?; return false; end; end; end
end

class Game_Battler
  alias cg_v256g_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    value = cg_v256g_ability_calc_hit(user,obj)
    return 100 if defined?(ALBERT_CG::ABILITY_G_V256) && ALBERT_CG::ABILITY_G_V256.active?
    return value
  end
  alias cg_v256g_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_G_V256) && ALBERT_CG::ABILITY_G_V256.active?
    return cg_v256g_ability_calc_eva(user,obj)
  end
  alias cg_v256g_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_G_V256) && ALBERT_CG::ABILITY_G_V256.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v256g_ability_priority_base_speed
  rescue
    return cg_v256g_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v256g_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_G_V256) && ALBERT_CG::ABILITY_G_V256.active?
      action = ALBERT_CG::ABILITY_G_V256.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v256g_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v256g_ability_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::ABILITY_G_V256.record_execution(battler) if defined?(ALBERT_CG::ABILITY_G_V256) && ALBERT_CG::ABILITY_G_V256.active?
    return cg_v256g_ability_execute_action
  end
  alias cg_v256g_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_G_V256) && ALBERT_CG::ABILITY_G_V256.active?
      ALBERT_CG::ABILITY_G_V256.finish_round_assertions
    end
    return cg_v256g_ability_turn_end
  end
  alias cg_v256g_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_G_V256) && ALBERT_CG::ABILITY_G_V256.active?
      return cg_v256g_ability_start_party_command
    end
    cg_v256g_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_G_V256.assert_bootstrap_once
    if ALBERT_CG::ABILITY_G_V256.finished?
      ALBERT_CG::ABILITY_G_V256.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_G_V256.prepare_round_actions
    start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v256g_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v256g_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_G_V256) && ALBERT_CG::ABILITY_G_V256.active?
        for cfg in ALBERT_CG::ABILITY_G_V256::TEST_ALLIES
          ALBERT_CG::ABILITY_G_V256.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_G_V256::TEST_LEVEL,false)
          human.recover_all
          human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
          human.instance_variable_set(:@cg_master_ability_id,0)
        end
      end
      return result
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v256g_ability_scene_map_update update
  def update
    cg_v256g_ability_scene_map_update
    if !$game_temp.in_battle && !ALBERT_CG::ABILITY_G_V256.active? && ALBERT_CG::ABILITY_G_V256.f11_trigger?
      Sound.play_decision
      ALBERT_CG::ABILITY_G_V256.start_auto_test
    end
  end
end
