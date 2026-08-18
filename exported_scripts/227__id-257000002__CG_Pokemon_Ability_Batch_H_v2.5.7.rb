# RMVX_SCRIPT_INDEX: 227
# RMVX_SCRIPT_ID: 257000002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch H v2.5.7
# RMVX_SOURCE_SHA256: 5b412854e2541cc95ab1b24e0e4d7320641d9aac988e68a600f3c148ed3ce1b5

#==============================================================================
# ■ CG Pokemon Ability Batch H v2.5.7 - Accuracy + Element Activation
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.6 Ability Batch G Runtime PASS 基底上，正式實作第八批 8 個 Ability，
#  並以 Actual Scene_Battle deterministic F11 regression 驗證命中／迴避倍率、Hustle
#  有效 ATK、Flash Fire activation + Fire boost、Motor Drive immunity + SPE stage，
#  以及 Teleport reserve / Storage isolation。
#
# 【本批 Ability】
#   8  Sand Veil      沙隱：Sandstorm 時對手命中率 x0.8。
#   14 Compound Eyes  複眼：自身命中率 x1.3。
#   18 Flash Fire     引火：免疫 Fire Move；啟動後 Fire damage x1.5。
#   55 Hustle         活力：ATK x1.5；Physical Move 命中率 x0.8。
#   77 Tangled Feet   蹣跚：Confusion 時對手命中率 x0.5。
#   78 Motor Drive    電氣引擎：免疫 Electric Move並 SPE stage +1。
#   81 Snow Cloak     雪隱：Hail 時對手命中率 x0.8。
#   99 No Guard       無防守：自己或對手的 Move 最終命中率固定 100。
#
# 【主要設定項】
#  TEST_TROOP_ID=710；ROUND_PLANS=2 回合；TEST_SPEEDS 固定同 priority 內順序。
#
# 【機制規則】
#  1. 正式效果由 Accuracy + Activation Authority v2.5.7 統一處理。
#  2. Bootstrap 直接以 Battle 中真正 Game_Battler / Skill 查詢驗 Compound Eyes、Hustle、
#     Sand Veil、Snow Cloak、No Guard，不用假資料重算公式。
#  3. Round1 由 Compound Eyes 使用 Flamethrower 攻擊 Flash Fire，確認 0 damage 並啟動；
#     Hustle 使用者用 Thunderbolt 攻擊 Motor Drive，確認 0 damage 並 Speed +1；
#     Snow Cloak 使用者最後以 Teleport 換入 hidden Tangled Feet reserve。
#  4. Round2 先讓換入的 Tangled Feet 進入 Confusion，以真正 calc_hit 驗證 x0.5；
#     Flash Fire 使用者再以 Ember 出手，確認已啟動的 Fire damage modifier x1.5。
#  5. Regression 僅固定 SPE / calc_eva；正式玩家 hit RNG、Ability 效果與天氣規則不改。
#  6. TEST Convenience 只限 F11；正式 Release 必須恢復 emerged、Battle BGM/BGS 與正常焦點。
#
# 【可調參數】
#  TEST_TROOP_ID / TEST_SPEEDS / ROUND_PLANS。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，一次跑完兩回合並輸出
#  Pokemon_Ability_H_AutoTest_v2_5_7.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Blizzard base 70 + Compound Eyes -> 91。
#  Sandstorm + Sand Veil：Tackle final hit 100 -> 80。
#  Thunderbolt -> Motor Drive：HP 不變、SPE stage +1。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchH"] = "2.5.7"

module ALBERT_CG
  module ABILITY_H_V257
    VERSION = "2.5.7"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 710
    VK_F11 = 0x7A

    ABILITY_SAND_VEIL     = 8
    ABILITY_COMPOUND_EYES = 14
    ABILITY_FLASH_FIRE    = 18
    ABILITY_HUSTLE        = 55
    ABILITY_TANGLED_FEET  = 77
    ABILITY_MOTOR_DRIVE   = 78
    ABILITY_SNOW_CLOAK    = 81
    ABILITY_NO_GUARD      = 99

    HANDLED_ABILITY_IDS = [8,14,18,55,77,78,81,99]

    TEST_ALLIES = [
      {:dex=>12, :level=>40,:ability=>ABILITY_COMPOUND_EYES,:moves=>[53,59,150,150]},
      {:dex=>176,:level=>40,:ability=>ABILITY_HUSTLE,       :moves=>[85,33,150,150]},
      {:dex=>68, :level=>40,:ability=>ABILITY_NO_GUARD,     :moves=>[59,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>38, :level=>40,:ability=>ABILITY_FLASH_FIRE,  :moves=>[52,150,150,150]},
      {:dex=>466,:level=>40,:ability=>ABILITY_MOTOR_DRIVE, :moves=>[150,150,150,150]},
      {:dex=>28, :level=>40,:ability=>ABILITY_SAND_VEIL,   :moves=>[150,150,150,150]},
      {:dex=>471,:level=>40,:ability=>ABILITY_SNOW_CLOAK,  :moves=>[100,150,150,150]},
      {:dex=>327,:level=>40,:ability=>ABILITY_TANGLED_FEET,:moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"FLASH_FIRE_MOTOR_DRIVE_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>53,:target=>0},
          {:kind=>:move,:move_id=>85,:target=>1},
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
        :name=>"TANGLED_FEET_FLASH_FIRE_BOOST",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>52,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,240,230,220, 210,200,190,180,0],
      :r2=>[10,180,170,160, 240,150,140,0,130],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M53","A2:M85","A3:M150","E0:M150","E1:M150","E2:M150","E3:M100"],
      2=>["A0:Guard","E0:M52","A1:M150","A2:M150","A3:M150","E1:M150","E2:M150","E4:M150"],
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
    def self.log_path; return File.join(project_root,"Pokemon_Ability_H_AutoTest_v2_5_7.log"); end
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
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_H_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end

    def self.reset_log
      header = "CG POKEMON ABILITY H ACCURACY + ACTIVATION AUTO REGRESSION v2.5.7\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; accuracy/evasion modifiers + Flash Fire / Motor Drive + reserve switch\r\n" +
        "BASELINE=v2.5.6 Ability Batch G Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_B_C_D_E_F_G_PASS=56 BATCH_H=8 PENDING=309\r\n" +
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
      if [:accuracy_modify,:evasion_modify,:accuracy_no_guard].include?(kind.to_sym)
        @accuracy_events.push([aid.to_i,battler,kind,ctx])
      elsif kind.to_sym == :stat_query
        @stat_events.push([aid.to_i,battler,kind,ctx])
      elsif kind.to_sym == :flash_fire_activate
        @flash_activation_events += 1
      elsif kind.to_sym == :motor_drive
        @motor_drive_events += 1
      end
      log("ABILITY_H_TRIGGER ability=" + aid.to_i.to_s + " battler=" + battler_token(battler) +
        " kind=" + kind.to_s)
      return true
    rescue
      return false
    end

    def self.note_flash_fire_boost(battler,before,after,ctx=nil)
      @ability_trigger_counts[ABILITY_FLASH_FIRE] = @ability_trigger_counts[ABILITY_FLASH_FIRE].to_i + 1
      @flash_boost_records.push({:battler=>battler,:before=>before.to_i,:after=>after.to_i,:ctx=>ctx})
      log("ABILITY_FLASH_FIRE_BOOST battler=" + battler_token(battler) +
        " before=" + before.to_i.to_s + " after=" + after.to_i.to_s)
      return true
    rescue
      return false
    end

    def self.note_motor_drive_stage(battler,before,after,ctx=nil)
      note_external_trigger(ABILITY_MOTOR_DRIVE,battler,:motor_drive,
        {:before=>before.to_i,:after=>after.to_i,:ctx=>ctx})
      @motor_drive_stage_before = before.to_i
      @motor_drive_stage_after = after.to_i
      return true
    rescue
      return false
    end

    def self.note_flash_fire_activation(battler,ctx=nil)
      note_external_trigger(ABILITY_FLASH_FIRE,battler,:flash_fire_activate,ctx)
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
        TEST_TROOP_ID,"Pokemon Ability H v2.5.7 AutoRegression",members)
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

    def self.skill_for_move(mid)
      return nil if master == nil
      sid = master.skill_id_for_move(mid.to_i)
      return $data_skills[sid]
    rescue
      return nil
    end

    def self.with_temp_ability(battler,aid)
      return yield if battler == nil
      old = battler.instance_variable_get(:@cg_master_ability_id)
      battler.instance_variable_set(:@cg_master_ability_id,aid.to_i)
      begin
        return yield
      ensure
        battler.instance_variable_set(:@cg_master_ability_id,old)
      end
    end

    def self.with_weather(kind,turns=5)
      return yield unless defined?(ALBERT_CG::FIELD_V233)
      st = ALBERT_CG::FIELD_V233.state
      old_w = st.weather
      old_t = st.weather_turns.to_i
      st.weather = kind
      st.weather_turns = turns.to_i
      begin
        return yield
      ensure
        st.weather = old_w
        st.weather_turns = old_t
      end
    end

    def self.stat_stage(b,key)
      return 0 if b == nil || !b.respond_to?(:cg_stat_stage)
      return b.cg_stat_stage(key).to_i
    rescue
      return 0
    end

    def self.query_accuracy_bootstrap
      a = test_allies
      e = all_enemies
      tackle = skill_for_move(33)
      blizzard = skill_for_move(59)

      # Compound Eyes
      comp_base = with_temp_ability(a[1],0) { e[0].calc_hit(a[1],blizzard) }
      comp_actual = e[0].calc_hit(a[1],blizzard)
      comp_expected = [comp_base.to_i * 130 / 100,100].min
      ok = comp_actual.to_i == comp_expected.to_i
      @accuracy_checks += 1 if ok
      assert_true("Compound Eyes raises final accuracy x1.3",ok,
        "base=" + comp_base.to_i.to_s + " actual=" + comp_actual.to_i.to_s + " expected=" + comp_expected.to_i.to_s)

      # Hustle ATK + physical accuracy
      hustle_atk_base = with_temp_ability(a[2],0) { a[2].cg_atk_stat }
      hustle_atk = a[2].cg_atk_stat
      hustle_atk_expected = [hustle_atk_base.to_i * 150 / 100,1].max
      ok = hustle_atk.to_i == hustle_atk_expected.to_i
      @stat_checks += 1 if ok
      assert_true("Hustle raises effective ATK x1.5",ok,
        "base=" + hustle_atk_base.to_i.to_s + " actual=" + hustle_atk.to_i.to_s + " expected=" + hustle_atk_expected.to_i.to_s)

      hustle_hit_base = with_temp_ability(a[2],0) { e[0].calc_hit(a[2],tackle) }
      hustle_hit = e[0].calc_hit(a[2],tackle)
      hustle_hit_expected = [[hustle_hit_base.to_i * 80 / 100,1].max,100].min
      ok = hustle_hit.to_i == hustle_hit_expected.to_i
      @accuracy_checks += 1 if ok
      assert_true("Hustle lowers Physical Move accuracy x0.8",ok,
        "base=" + hustle_hit_base.to_i.to_s + " actual=" + hustle_hit.to_i.to_s + " expected=" + hustle_hit_expected.to_i.to_s)

      # Sand Veil
      with_weather(:sandstorm,5) do
        sand_base = with_temp_ability(e[2],0) { with_temp_ability(a[1],0) { e[2].calc_hit(a[1],tackle) } }
        sand_actual = with_temp_ability(a[1],0) { e[2].calc_hit(a[1],tackle) }
        sand_expected = [[sand_base.to_i * 80 / 100,1].max,100].min
        ok2 = sand_actual.to_i == sand_expected.to_i
        @accuracy_checks += 1 if ok2
        assert_true("Sand Veil lowers opponent accuracy x0.8 in Sandstorm",ok2,
          "base=" + sand_base.to_i.to_s + " actual=" + sand_actual.to_i.to_s + " expected=" + sand_expected.to_i.to_s)
      end

      # Snow Cloak
      with_weather(:hail,5) do
        snow_base = with_temp_ability(e[3],0) { with_temp_ability(a[1],0) { e[3].calc_hit(a[1],tackle) } }
        snow_actual = with_temp_ability(a[1],0) { e[3].calc_hit(a[1],tackle) }
        snow_expected = [[snow_base.to_i * 80 / 100,1].max,100].min
        ok2 = snow_actual.to_i == snow_expected.to_i
        @accuracy_checks += 1 if ok2
        assert_true("Snow Cloak lowers opponent accuracy x0.8 in Hail",ok2,
          "base=" + snow_base.to_i.to_s + " actual=" + snow_actual.to_i.to_s + " expected=" + snow_expected.to_i.to_s)
      end

      # No Guard
      ng_base = with_temp_ability(a[3],0) { e[0].calc_hit(a[3],blizzard) }
      ng_actual = e[0].calc_hit(a[3],blizzard)
      ok = ng_actual.to_i == 100 && ng_base.to_i < 100
      @accuracy_checks += 1 if ok
      assert_true("No Guard forces final accuracy 100",ok,
        "base=" + ng_base.to_i.to_s + " actual=" + ng_actual.to_i.to_s)
    end

    def self.prepare_round_preconditions
      a = test_allies
      e = all_enemies
      if current_round == 1
        (a + e).each { |b| b.cg_reset_stat_stages if b != nil && b.respond_to?(:cg_reset_stat_stages) }
        @r1_flash_hp_before = e[0] == nil ? 0 : e[0].hp.to_i
        @r1_motor_hp_before = e[1] == nil ? 0 : e[1].hp.to_i
        @r1_storage_before = storage_size
      elsif current_round == 2
        if e[4] != nil && defined?(ALBERT_CG::MOVE_EFFECT)
          e[4].remove_state(ALBERT_CG::MOVE_EFFECT::STATE_CONFUSION) if e[4].state?(ALBERT_CG::MOVE_EFFECT::STATE_CONFUSION)
          e[4].add_state(ALBERT_CG::MOVE_EFFECT::STATE_CONFUSION)
          tackle = skill_for_move(33)
          base = with_temp_ability(e[4],0) { with_temp_ability(a[1],0) { e[4].calc_hit(a[1],tackle) } }
          actual = with_temp_ability(a[1],0) { e[4].calc_hit(a[1],tackle) }
          expected = [[base.to_i * 50 / 100,1].max,100].min
          ok = actual.to_i == expected.to_i
          @accuracy_checks += 1 if ok
          assert_true("Tangled Feet halves opponent accuracy while Confused",ok,
            "base=" + base.to_i.to_s + " actual=" + actual.to_i.to_s + " expected=" + expected.to_i.to_s)
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
      assert_true("Ability Batch H declares 8 IDs",HANDLED_ABILITY_IDS.size == 8)
      assert_true("Scene_Battle uses Ability H test troop",actual_troop_id == TEST_TROOP_ID,"actual=" + actual_troop_id.to_s)
      assert_true("Ability H ally count=4",a.size == 4,"actual=" + a.size.to_s)
      assert_true("Ability H starts with 4 active enemies",e.select { |b| b != nil && !b.hidden }.size == 4)
      assert_true("Ability H starts with 1 hidden Tangled Feet reserve",e.select { |b| b != nil && b.hidden }.size == 1)
      query_accuracy_bootstrap
    end

    def self.assert_round
      r = current_round
      a = test_allies
      e = all_enemies
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      if r == 1
        ff_cancel = e[0] != nil && e[0].hp.to_i == @r1_flash_hp_before.to_i &&
          defined?(ALBERT_CG::ABILITY_ACCURACY_V257) && ALBERT_CG::ABILITY_ACCURACY_V257.flash_fire_active?(e[0])
        @activation_checks += 1 if ff_cancel
        assert_true("Flash Fire cancels Fire Move and activates",ff_cancel,
          "hp=" + (e[0] == nil ? "nil" : e[0].hp.to_i.to_s) + " before=" + @r1_flash_hp_before.to_i.to_s +
          " active=" + (e[0] == nil ? "nil" : ALBERT_CG::ABILITY_ACCURACY_V257.flash_fire_active?(e[0]).to_s))

        motor_ok = e[1] != nil && e[1].hp.to_i == @r1_motor_hp_before.to_i && stat_stage(e[1],:spe) == 1
        @activation_checks += 1 if motor_ok
        assert_true("Motor Drive cancels Electric Move and raises SPE +1",motor_ok,
          "hp=" + (e[1] == nil ? "nil" : e[1].hp.to_i.to_s) + " spe=" + stat_stage(e[1],:spe).to_s)

        switched = e[3] != nil && e[4] != nil && e[3].hidden && !e[4].hidden
        @lifecycle_checks += 1 if switched
        assert_true("Teleport deploys hidden Tangled Feet reserve",switched,
          "E3_hidden=" + (e[3] == nil ? "nil" : e[3].hidden.to_s) + " E4_hidden=" + (e[4] == nil ? "nil" : e[4].hidden.to_s))
        storage_ok = storage_size == @r1_storage_before.to_i
        @lifecycle_checks += 1 if storage_ok
        assert_true("Tangled Feet reserve switch does not consume Storage Pokemon",storage_ok,
          "before=" + @r1_storage_before.to_i.to_s + " after=" + storage_size.to_s)
      elsif r == 2
        rec = @flash_boost_records[-1]
        boost_ok = rec != nil && rec[:before].to_i > 0 && rec[:after].to_i == rec[:before].to_i * 150 / 100
        @activation_checks += 1 if boost_ok
        assert_true("Activated Flash Fire boosts Fire damage x1.5",boost_ok,
          "record=" + (rec == nil ? "nil" : rec.inspect))
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
      log("SUMMARY rounds=2 failures=" + @failures.size.to_s +
        " ability_h=" + ability_covered_count.to_s + "/8" +
        " accuracy_checks=" + @accuracy_checks.to_i.to_s +
        " stat_checks=" + @stat_checks.to_i.to_s +
        " activation_checks=" + @activation_checks.to_i.to_s +
        " lifecycle_checks=" + @lifecycle_checks.to_i.to_s + " pending=309")
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
      @accuracy_events = []
      @stat_events = []
      @flash_boost_records = []
      @flash_activation_events = 0
      @motor_drive_events = 0
      @motor_drive_stage_before = 0
      @motor_drive_stage_after = 0
      @accuracy_checks = 0
      @stat_checks = 0
      @activation_checks = 0
      @lifecycle_checks = 0
      @actual = []
      @boot_asserted = false
      @r1_storage_before = 0
      @r1_flash_hp_before = 0
      @r1_motor_hp_before = 0
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
        ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_H_v2.5.7")
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

# Flash Fire activation 本身由 before_hit handler 成功時記錄到 Batch H。
if defined?(ALBERT_CG::ABILITY_ACCURACY_V257)
  module ALBERT_CG
    module ABILITY_ACCURACY_V257
      class << self
        alias cg_v257h_flash_fire_before_hit apply_flash_fire_before_hit
        def apply_flash_fire_before_hit(battler,ctx)
          ok = cg_v257h_flash_fire_before_hit(battler,ctx)
          if ok && defined?(ALBERT_CG::ABILITY_H_V257)
            ALBERT_CG::ABILITY_H_V257.note_flash_fire_activation(battler,ctx)
          end
          return ok
        end
      end
    end
  end
  ALBERT_CG::ABILITY_ACCURACY_V257.register_handlers
end

#==============================================================================
# ■ Older Ability regression F11：Batch H 成為唯一最新版
#==============================================================================
if defined?(ALBERT_CG::ABILITY_G_V256)
  module ALBERT_CG; module ABILITY_G_V256; def self.f11_trigger?; return false; end; end; end
end
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
  alias cg_v257h_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_H_V257) && ALBERT_CG::ABILITY_H_V257.active?
    return cg_v257h_ability_calc_eva(user,obj)
  end

  alias cg_v257h_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_H_V257) && ALBERT_CG::ABILITY_H_V257.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v257h_ability_priority_base_speed
  rescue
    return cg_v257h_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v257h_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_H_V257) && ALBERT_CG::ABILITY_H_V257.active?
      action = ALBERT_CG::ABILITY_H_V257.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v257h_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v257h_ability_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::ABILITY_H_V257.record_execution(battler) if defined?(ALBERT_CG::ABILITY_H_V257) && ALBERT_CG::ABILITY_H_V257.active?
    return cg_v257h_ability_execute_action
  end

  alias cg_v257h_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_H_V257) && ALBERT_CG::ABILITY_H_V257.active?
      ALBERT_CG::ABILITY_H_V257.finish_round_assertions
    end
    return cg_v257h_ability_turn_end
  end

  alias cg_v257h_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_H_V257) && ALBERT_CG::ABILITY_H_V257.active?
      return cg_v257h_ability_start_party_command
    end
    cg_v257h_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_H_V257.assert_bootstrap_once
    if ALBERT_CG::ABILITY_H_V257.finished?
      ALBERT_CG::ABILITY_H_V257.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_H_V257.prepare_round_actions
    start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v257h_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v257h_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_H_V257) && ALBERT_CG::ABILITY_H_V257.active?
        for cfg in ALBERT_CG::ABILITY_H_V257::TEST_ALLIES
          ALBERT_CG::ABILITY_H_V257.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_H_V257::TEST_LEVEL,false)
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
  alias cg_v257h_ability_scene_map_update update
  def update
    cg_v257h_ability_scene_map_update
    if !$game_temp.in_battle && !ALBERT_CG::ABILITY_H_V257.active? && ALBERT_CG::ABILITY_H_V257.f11_trigger?
      Sound.play_decision
      ALBERT_CG::ABILITY_H_V257.start_auto_test
    end
  end
end
