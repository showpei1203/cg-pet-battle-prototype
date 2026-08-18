# RMVX_SCRIPT_INDEX: 231
# RMVX_SCRIPT_ID: 259000002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch J v2.5.9
# RMVX_SOURCE_SHA256: efe8491172125cb884501ae85e0cb24ba9912eac9cb76becf90133bb8df2ba0e

#==============================================================================
# ■ CG Pokemon Ability Batch J v2.5.9 - Stat Dynamics + Switch Recovery
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.8 Ability Batch I Runtime PASS 基底上，正式實作第十批 8 個能力階級動態／
#  反應／換出回復 Ability，並用 Actual Scene_Battle deterministic F11 regression 驗證
#  Steadfast、Anger Point、Simple、Contrary、Defiant、Moody、Regenerator、Competitive。
#
# 【本批 Ability】
#   80 Steadfast    不屈之心：真正畏縮時 SPE +1。
#   83 Anger Point  憤怒穴位：受到 Critical 後 ATK stage 直接到 +6。
#   86 Simple       單純：自身 stage change 數值 x2。
#  126 Contrary     唱反調：自身 stage change 正負反轉。
#  128 Defiant      不服輸：敵方造成任何 stat 下降後 ATK +2。
#  141 Moody        心情不定：end_turn 隨機一項 +2、另一項 -1，現代規則不含命中/閃避。
#  144 Regenerator  再生力：換出時回復 MaxHP 約 1/3。
#  172 Competitive  好勝：敵方造成任何 stat 下降後 SPA +2。
#
# 【主要設定項】
#  TEST_TROOP_ID=712；ROUND_PLANS=2；TEST_SPEEDS 固定 Priority 內順序。
#  HANDLED_ABILITY_IDS 共 8 ID；Coverage 由 pending 301 -> 293。
#
# 【機制規則】
#  1. 正式效果全部由 Stat Dynamics Authority v2.5.9 處理；Batch J 只負責 deterministic 測試。
#  2. Round1 實際用 Sand Attack 驗 Simple / Contrary / Competitive，用 Tackle + test-only
#     forced Critical 驗 Anger Point，再由 Regenerator 使用真正 Teleport 換入 hidden Moody reserve。
#  3. Round2 由對手 Sand Attack 驗 Defiant；Bite 對 Steadfast 目標若正式 RNG 未觸發畏縮，
#     Regression-only bridge 補上一個 Flinch state，正式玩家 RNG 不變。
#  4. Moody 正式仍隨機；Regression-only 第一次固定 ATK+2/DEF-1，第二次固定 SPA+2/SPD-1。
#  5. Regenerator 起始先被測試器壓到半血，Teleport switch_out 後驗實際回復 floor(MaxHP/3)。
#  6. 所有 stage source 使用 v2.5.6 Stat Guard Authority 的敵我 context，驗證 Defiant /
#     Competitive 不會把自我下降誤判為對手觸發。
#  7. TEST Convenience 只限 F11；正式 Release 必須恢復 emerged、Battle BGM/BGS 與正常焦點。
#
# 【可調參數】
#  TEST_TROOP_ID / TEST_SPEEDS / ROUND_PLANS；正式規則在 Authority v2.5.9。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，一次跑完 2 回合，輸出
#  Pokemon_Ability_J_AutoTest_v2_5_9.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Sand Attack -> Simple：Accuracy -2；-> Contrary：Accuracy +1；
#  Critical -> Anger Point：ATK +6；Teleport -> Regenerator heal + hidden Moody 入場。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchJ"] = "2.5.9"

module ALBERT_CG
  module ABILITY_J_V259
    VERSION = "2.5.9"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 712
    VK_F11 = 0x7A

    ABILITY_STEADFAST    = 80
    ABILITY_ANGER_POINT = 83
    ABILITY_SIMPLE       = 86
    ABILITY_CONTRARY     = 126
    ABILITY_DEFIANT      = 128
    ABILITY_MOODY        = 141
    ABILITY_REGENERATOR  = 144
    ABILITY_COMPETITIVE  = 172

    HANDLED_ABILITY_IDS = [80,83,86,126,128,141,144,172]

    TEST_ALLIES = [
      {:dex=>399,:level=>40,:ability=>ABILITY_SIMPLE,   :moves=>[28,150,150,150]},
      {:dex=>213,:level=>40,:ability=>ABILITY_CONTRARY, :moves=>[150,44,150,150]},
      {:dex=>57, :level=>40,:ability=>ABILITY_DEFIANT,  :moves=>[33,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>350,:level=>40,:ability=>ABILITY_COMPETITIVE,:moves=>[150,28,150,150]},
      {:dex=>448,:level=>40,:ability=>ABILITY_STEADFAST,   :moves=>[28,150,150,150]},
      {:dex=>128,:level=>40,:ability=>ABILITY_ANGER_POINT, :moves=>[28,150,150,150]},
      {:dex=>80, :level=>40,:ability=>ABILITY_REGENERATOR, :moves=>[100,150,150,150]},
      {:dex=>235,:level=>40,:ability=>ABILITY_MOODY,       :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"SIMPLE_CONTRARY_COMPETITIVE_ANGER_REGEN_MOODY",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>28,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>33,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>28,:target=>2},
          2=>{:kind=>:move,:move_id=>28,:target=>1},
          3=>{:kind=>:move,:move_id=>100,:target=>0},
        }
      },
      {
        :name=>"DEFIANT_STEADFAST_MOODY_STABILITY",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>44,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>28,:target=>3},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,230,180,200, 190,220,210,100,0],
      :r2=>[10,170,180,160, 230,220,150,0,140],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M28","E1:M28","E2:M28","A3:M33","E0:M150","A2:M150","E3:M100"],
      2=>["A0:Guard","E0:M28","E1:M150","A2:M44","A1:M150","A3:M150","E2:M150","E4:M150"],
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
    def self.log_path; return File.join(project_root,"Pokemon_Ability_J_AutoTest_v2_5_9.log"); end
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
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_J_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end

    def self.reset_log
      header = "CG POKEMON ABILITY J STAT DYNAMICS + SWITCH RECOVERY AUTO REGRESSION v2.5.9\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; stage transform/reaction + flinch/critical + Moody + Regenerator\r\n" +
        "BASELINE=v2.5.8 Ability Batch I Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_B_C_D_E_F_G_H_I_PASS=72 BATCH_J=8 PENDING=293\r\n" +
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
      return true unless active?
      @ability_trigger_counts[aid.to_i] = @ability_trigger_counts[aid.to_i].to_i + 1
      data = ctx == nil ? {} : ctx
      @last_records[aid.to_i] = {:kind=>kind,:ctx=>data,:battler=>battler}
      @moody_records.push(data) if aid.to_i == ABILITY_MOODY && kind.to_sym == :moody
      @regen_records.push(data) if aid.to_i == ABILITY_REGENERATOR && kind.to_sym == :regenerator
      log("ABILITY_J_TRIGGER ability=" + aid.to_i.to_s + " battler=" + battler_token(battler) +
        " kind=" + kind.to_s + " ctx=" + compact_ctx(data))
      return true
    rescue
      return true
    end

    def self.compact_ctx(data)
      return "{}" if data == nil
      parts = []
      [:stat,:requested,:applied_request,:delta,:lowered_stat,:lowered_delta,:boost_stat,
       :before,:after,:up_stat,:up_before,:up_after,:down_stat,:down_before,:down_after,
       :heal,:maxhp,:move_id].each do |k|
        parts.push(k.to_s + "=" + data[k].to_s) if data.has_key?(k)
      end
      return "{" + parts.join(",") + "}"
    rescue
      return "{}"
    end

    def self.test_moody_pair(battler)
      return nil unless active?
      @moody_pair_calls = @moody_pair_calls.to_i + 1
      return [:atk,:def] if @moody_pair_calls == 1
      return [:spa,:spd]
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
      ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each { |cfg| configure_actor(cfg) }
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
        TEST_TROOP_ID,"Pokemon Ability J v2.5.9 AutoRegression",members)
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

    def self.stat_stage(b,key)
      return b == nil || !b.respond_to?(:cg_stat_stage) ? 0 : b.cg_stat_stage(key).to_i
    rescue
      return 0
    end

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted = true
      a = test_allies
      e = all_enemies
      assert_true("Ability Catalog count=373",defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.catalog_count.to_i == 373,
        "actual=" + (defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.catalog_count.to_i.to_s : "0"))
      assert_true("Ability Batch J declares 8 IDs",HANDLED_ABILITY_IDS.size == 8)
      troop_id = ($game_troop != nil && $game_troop.troop != nil) ? $game_troop.troop.id.to_i : 0
      assert_true("Scene_Battle uses Ability J test troop",troop_id == TEST_TROOP_ID,"actual=" + troop_id.to_s)
      assert_true("Ability J ally count=4",a.size == 4,"actual=" + a.size.to_s)
      assert_true("Ability J starts with 4 active enemies",e.select { |b| b != nil && !b.hidden }.size == 4)
      assert_true("Ability J starts with 1 hidden Moody reserve",e.select { |b| b != nil && b.hidden }.size == 1)
      if e[3] != nil
        e[3].hp = [e[3].maxhp.to_i / 2,1].max
        @regen_hp_before = e[3].hp.to_i
        @regen_expected = [@regen_hp_before + [e[3].maxhp.to_i / 3,1].max,e[3].maxhp.to_i].min
      end
      @storage_before = storage_size
    end

    def self.prepare_round_actions
      plan = current_plan
      return if plan == nil
      apply_test_speeds
      a = test_allies
      a.each_with_index do |b,i|
        next if b == nil || b.hidden || b.hp.to_i <= 0
        cfg = plan[:allies][i]
        b.instance_variable_set(:@cg_round_actions,[make_action(b,cfg)]) if cfg != nil
      end
      @actual = []
      log("ROUND " + current_round.to_s + " BEGIN " + plan[:name].to_s)
    end

    def self.execution_token(battler)
      return "nil" if battler == nil
      prefix = battler.actor? ? "A" : "E"
      idx = battler.index.to_i
      action = battler.action
      return prefix + idx.to_s + ":Guard" if action != nil && action.guard?
      if action != nil && action.skill?
        skill = $data_skills[action.skill_id]
        mid = defined?(ALBERT_CG::MOVE_EFFECT) && skill != nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0
        return prefix + idx.to_s + ":M" + mid.to_s
      end
      return prefix + idx.to_s + ":Other"
    rescue
      return "?"
    end

    def self.record_execution(battler)
      return unless active?
      token = execution_token(battler)
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + (battler == nil ? "nil" : battler.name.to_s) + " token=" + token)
    end

    def self.assert_round
      r = current_round
      a = test_allies
      e = all_enemies
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      if r == 1
        checks = []
        checks << ["Simple doubles Sand Attack stage loss",stat_stage(a[1],:accuracy) == -2,"stage=" + stat_stage(a[1],:accuracy).to_s]
        checks << ["Contrary reverses Sand Attack into Accuracy +1",stat_stage(a[2],:accuracy) == 1,"stage=" + stat_stage(a[2],:accuracy).to_s]
        checks << ["Competitive reacts to enemy stat drop with SPA +2",stat_stage(e[0],:accuracy) == -1 && stat_stage(e[0],:spa) == 2,
          "acc=" + stat_stage(e[0],:accuracy).to_s + " spa=" + stat_stage(e[0],:spa).to_s]
        checks << ["Anger Point maxes ATK stage after real critical",stat_stage(e[2],:atk) == 6,"atk=" + stat_stage(e[2],:atk).to_s]
        checks.each do |row|
          ok=row[1]; @stat_checks += 1 if ok; assert_true(row[0],ok,row[2])
        end
        regen_ok = e[3] != nil && e[3].hp.to_i == @regen_expected.to_i
        @recovery_checks += 1 if regen_ok
        assert_true("Regenerator heals about 1/3 MaxHP on real Teleport switch-out",regen_ok,
          "before=" + @regen_hp_before.to_s + " after=" + (e[3] == nil ? "nil" : e[3].hp.to_i.to_s) + " expected=" + @regen_expected.to_s)
        switched = e[3] != nil && e[4] != nil && e[3].hidden && !e[4].hidden
        @lifecycle_checks += 1 if switched
        assert_true("Teleport deploys hidden Moody reserve",switched,
          "E3_hidden=" + (e[3] == nil ? "nil" : e[3].hidden.to_s) + " E4_hidden=" + (e[4] == nil ? "nil" : e[4].hidden.to_s))
        storage_ok = storage_size == @storage_before.to_i
        @lifecycle_checks += 1 if storage_ok
        assert_true("Moody reserve switch does not consume Storage Pokemon",storage_ok,
          "before=" + @storage_before.to_s + " after=" + storage_size.to_s)
        m = @moody_records[0]
        moody_ok = m != nil && m[:up_stat] == :atk && m[:up_after].to_i == 2 &&
          m[:down_stat] == :def && m[:down_after].to_i == -1
        @end_turn_checks += 1 if moody_ok
        assert_true("Moody first end-turn applies deterministic ATK+2 DEF-1",moody_ok,
          "record=" + compact_ctx(m))
      elsif r == 2
        defiant_ok = stat_stage(a[3],:accuracy) == -1 && stat_stage(a[3],:atk) == 2
        @stat_checks += 1 if defiant_ok
        assert_true("Defiant reacts to opponent Sand Attack with ATK +2",defiant_ok,
          "acc=" + stat_stage(a[3],:accuracy).to_s + " atk=" + stat_stage(a[3],:atk).to_s)
        steadfast_ok = stat_stage(e[1],:spe) == 1
        @stat_checks += 1 if steadfast_ok
        assert_true("Steadfast raises SPE +1 when Flinch is really added",steadfast_ok,
          "spe=" + stat_stage(e[1],:spe).to_s)
        m = @moody_records[1]
        moody_ok = m != nil && m[:up_stat] == :spa && m[:up_after].to_i == 2 &&
          m[:down_stat] == :spd && m[:down_after].to_i == -1
        @end_turn_checks += 1 if moody_ok
        assert_true("Moody second end-turn applies deterministic SPA+2 SPD-1",moody_ok,
          "record=" + compact_ctx(m))
      end
      log("ROUND " + r.to_s + " END")
    end

    def self.finish_round_assertions
      return unless active?
      assert_round
      @round_index += 1
    end

    def self.ability_covered_count
      count=0
      HANDLED_ABILITY_IDS.each { |aid| count += 1 if @ability_trigger_counts[aid].to_i > 0 }
      return count
    end

    def self.cleanup_test_overrides
      (test_allies + all_enemies).each do |b|
        b.instance_variable_set(:@cg_priority_test_speed_override,nil) if b != nil
      end
    end

    def self.finish_suite
      HANDLED_ABILITY_IDS.each do |aid|
        assert_true("Ability " + aid.to_s + " triggered",@ability_trigger_counts[aid].to_i > 0,
          "count=" + @ability_trigger_counts[aid].to_i.to_s)
      end
      result = @failures.empty? ? "PASS" : "FAIL"
      log("------------------------------------------------------------")
      log("RESULT=" + result)
      log("SUMMARY rounds=2 failures=" + @failures.size.to_s +
        " ability_j=" + ability_covered_count.to_s + "/8" +
        " stat_checks=" + @stat_checks.to_i.to_s +
        " recovery_checks=" + @recovery_checks.to_i.to_s +
        " end_turn_checks=" + @end_turn_checks.to_i.to_s +
        " lifecycle_checks=" + @lifecycle_checks.to_i.to_s + " pending=293")
      @failures.each_with_index { |x,i| log("FAILURE " + (i+1).to_s + " " + x.to_s) }
      cleanup_test_overrides
      @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end

    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @last_records={}
      @moody_records=[]; @regen_records=[]; @moody_pair_calls=0
      @stat_checks=0; @recovery_checks=0; @end_turn_checks=0; @lifecycle_checks=0
      @actual=[]; @boot_asserted=false; @storage_before=0; @regen_hp_before=0; @regen_expected=0
    end

    def self.start_auto_test
      return false if active?
      reset_log
      reset_suite
      prepare_test_party
      make_test_troop
      @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_J_v2.5.9") if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop=" + TEST_TROOP_ID.to_s)
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue => e
      @failures=[] if @failures==nil
      @failures.push("AUTO_TEST_START_ERROR " + e.class.to_s + ":" + e.message.to_s)
      log(@failures[-1]); @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
      return false
    end
  end
end

#------------------------------------------------------------------------------
# Batch J 為唯一最新版 F11
#------------------------------------------------------------------------------
if defined?(ALBERT_CG::ABILITY_I_V258)
  module ALBERT_CG; module ABILITY_I_V258; def self.f11_trigger?; return false; end; end; end
end

#------------------------------------------------------------------------------
# Regression-only deterministic bridges
#------------------------------------------------------------------------------
class Game_Battler
  alias cg_v259j_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_J_V259) && ALBERT_CG::ABILITY_J_V259.active?
    return cg_v259j_ability_calc_eva(user,obj)
  end

  alias cg_v259j_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    return 100 if defined?(ALBERT_CG::ABILITY_J_V259) && ALBERT_CG::ABILITY_J_V259.active?
    return cg_v259j_ability_calc_hit(user,obj)
  end

  alias cg_v259j_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_J_V259) && ALBERT_CG::ABILITY_J_V259.active?
      value=@cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v259j_ability_priority_base_speed
  rescue
    return cg_v259j_ability_priority_base_speed
  end

  alias cg_v259j_ability_critical cg_pokemon_critical?
  def cg_pokemon_critical?(user,obj=nil)
    if defined?(ALBERT_CG::ABILITY_J_V259) && ALBERT_CG::ABILITY_J_V259.active? &&
       ALBERT_CG::ABILITY_J_V259.current_round == 1 && user != nil && user.actor? &&
       user.index.to_i == 3 && !actor? && index.to_i == 2 &&
       defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.current_move_id(user).to_i == 33
      return true
    end
    return cg_v259j_ability_critical(user,obj)
  end

  alias cg_v259j_ability_skill_effect skill_effect
  def skill_effect(user,skill)
    result = cg_v259j_ability_skill_effect(user,skill)
    if defined?(ALBERT_CG::ABILITY_J_V259) && ALBERT_CG::ABILITY_J_V259.active? &&
       ALBERT_CG::ABILITY_J_V259.current_round == 2 && !actor? && index.to_i == 1 &&
       user != nil && user.actor? && user.index.to_i == 2 && skill != nil &&
       defined?(ALBERT_CG::MOVE_EFFECT) && ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i == 44
      sid = ALBERT_CG::MOVE_EFFECT::STATE_FLINCH
      add_state(sid) unless state?(sid)
    end
    return result
  end
end

class Game_Enemy < Game_Battler
  alias cg_v259j_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_J_V259) && ALBERT_CG::ABILITY_J_V259.active?
      action=ALBERT_CG::ABILITY_J_V259.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action=action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v259j_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v259j_ability_execute_action execute_action
  def execute_action
    battler=@active_battler
    ALBERT_CG::ABILITY_J_V259.record_execution(battler) if defined?(ALBERT_CG::ABILITY_J_V259) && ALBERT_CG::ABILITY_J_V259.active?
    return cg_v259j_ability_execute_action
  end

  alias cg_v259j_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_J_V259) && ALBERT_CG::ABILITY_J_V259.active?
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      end
      ALBERT_CG::ABILITY_J_V259.finish_round_assertions
    end
    return cg_v259j_ability_turn_end
  end

  alias cg_v259j_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_J_V259) && ALBERT_CG::ABILITY_J_V259.active?
      return cg_v259j_ability_start_party_command
    end
    cg_v259j_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_J_V259.assert_bootstrap_once
    if ALBERT_CG::ABILITY_J_V259.finished?
      ALBERT_CG::ABILITY_J_V259.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_J_V259.prepare_round_actions
    start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v259j_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result=cg_v259j_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_J_V259) && ALBERT_CG::ABILITY_J_V259.active?
        ALBERT_CG::ABILITY_J_V259::TEST_ALLIES.each { |cfg| ALBERT_CG::ABILITY_J_V259.configure_actor(cfg) }
        human=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_J_V259::TEST_LEVEL,false)
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
  alias cg_v259j_ability_scene_map_update update
  def update
    cg_v259j_ability_scene_map_update
    if !$game_temp.in_battle && !ALBERT_CG::ABILITY_J_V259.active? && ALBERT_CG::ABILITY_J_V259.f11_trigger?
      Sound.play_decision
      ALBERT_CG::ABILITY_J_V259.start_auto_test
    end
  end
end
