# RMVX_SCRIPT_INDEX: 229
# RMVX_SCRIPT_ID: 258000002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch I v2.5.8
# RMVX_SOURCE_SHA256: 6022763d82040bce5b9d8e300b02e19756e0e695d1b29ab648ef56dd02e28ab7

#==============================================================================
# ■ CG Pokemon Ability Batch I v2.5.8 - Conditional Stats + Tempo
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.7 Ability Batch H Runtime PASS 基底上，正式實作第九批 8 個條件能力值／
#  節奏 Ability，並以 Actual Scene_Battle deterministic F11 regression 驗證 Plus/Minus、
#  Unburden、Download、Solar Power、Quick Feet、Sniper、Slow Start，以及 Teleport reserve
#  / Storage isolation。
#
# 【本批 Ability】
#   57 Plus         正電：場上同伴具有 Plus / Minus 時 SPA x1.5。
#   58 Minus        負電：場上同伴具有 Plus / Minus 時 SPA x1.5。
#   84 Unburden     輕裝：戰鬥中失去持有物後 SPE x2，換出清除。
#   88 Download     下載：進場比較敵方 DEF/SPD 總和，ATK 或 SPA stage +1。
#   94 Solar Power  太陽之力：Sun 時 SPA x1.5；回合末 MaxHP 1/8 傷害。
#   95 Quick Feet   飛毛腿：主要異常時 SPE x1.5，Paralysis 不再造成 Speed x0.5。
#   97 Sniper       狙擊手：Critical 最終正傷害再 x1.5。
#  112 Slow Start   慢啟動：進場 5 回合 ATK/SPE x0.5，換出清除。
#
# 【主要設定項】
#  TEST_TROOP_ID=711；ROUND_PLANS=2 回合；TEST_SPEEDS 固定同 Priority 內執行順序。
#  HANDLED_ABILITY_IDS 共 8 ID，Coverage 由 309 pending -> 301 pending。
#
# 【機制規則】
#  1. 正式效果由 Conditional Stat + Tempo Authority v2.5.8 統一處理。
#  2. Bootstrap 直接使用 Battle 中真正 Game_Battler 查詢 Plus/Minus SPA、Quick Feet SPE、
#     Solar Power SPA、Unburden Held Item loss、Download entry stage，不用假資料重算。
#  3. Unburden 使用 Held Item Core 的測試護符 Weapon 903；先真正裝備，再經
#     cg_consume_held_item 失去，驗 :held_item_changed -> SPE x2。
#  4. Round1 由 Sniper 使用 Tackle；Regression test-only 強制該一次 candidate Critical，
#     正式 Critical RNG 不變。Unburden 使用者最後 Teleport 換入 hidden Slow Start reserve。
#  5. Solar Power 在 Sun 下由 Ability Core end_turn 先扣 MaxHP 1/8，再做 Round ASSERT。
#  6. Round2 先驗 Slow Start ATK/SPE x0.5，再 test-only 將 counter 調到 1，使該回合
#     結束後可 deterministic 驗證 counter=0 與 ATK/SPE 恢復；正式規則仍是 5 回合。
#  7. TEST Convenience 只限 F11；正式 Release 必須恢復 emerged、Battle BGM/BGS 與正常焦點。
#
# 【可調參數】
#  TEST_TROOP_ID / TEST_SPEEDS / ROUND_PLANS；正式 Ability 倍率在 Authority v2.5.8。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，一次跑完兩回合並輸出
#  Pokemon_Ability_I_AutoTest_v2_5_8.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Plus + Minus 同場：SPA x1.5；Paralyzed Quick Feet：Speed 約正常值 x1.5；
#  Held Item 消耗：Unburden active=true、SPE x2；Slow Start reserve 進場 turns=5。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchI"] = "2.5.8"

module ALBERT_CG
  module ABILITY_I_V258
    VERSION = "2.5.8"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 711
    VK_F11 = 0x7A

    ABILITY_PLUS        = 57
    ABILITY_MINUS       = 58
    ABILITY_UNBURDEN    = 84
    ABILITY_DOWNLOAD    = 88
    ABILITY_SOLAR_POWER = 94
    ABILITY_QUICK_FEET  = 95
    ABILITY_SNIPER      = 97
    ABILITY_SLOW_START  = 112

    HANDLED_ABILITY_IDS = [57,58,84,88,94,95,97,112]

    TEST_ALLIES = [
      {:dex=>311,:level=>40,:ability=>ABILITY_PLUS,       :moves=>[150,150,150,150]},
      {:dex=>312,:level=>40,:ability=>ABILITY_MINUS,      :moves=>[150,150,150,150]},
      {:dex=>335,:level=>40,:ability=>ABILITY_QUICK_FEET, :moves=>[150,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>233,:level=>40,:ability=>ABILITY_DOWNLOAD,   :moves=>[150,150,150,150]},
      {:dex=>6,  :level=>40,:ability=>ABILITY_SOLAR_POWER,:moves=>[52,150,150,150]},
      {:dex=>230,:level=>40,:ability=>ABILITY_SNIPER,     :moves=>[33,150,150,150]},
      {:dex=>254,:level=>40,:ability=>ABILITY_UNBURDEN,   :moves=>[100,150,150,150]},
      {:dex=>486,:level=>40,:ability=>ABILITY_SLOW_START, :moves=>[33,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"SNIPER_SOLAR_UNBURDEN_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>52,:target=>1},
          2=>{:kind=>:move,:move_id=>33,:target=>2},
          3=>{:kind=>:move,:move_id=>100,:target=>0},
        }
      },
      {
        :name=>"SLOW_START_COUNTDOWN_RELEASE",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>33,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,170,160,150, 140,230,220,100,0],
      :r2=>[10,170,160,150, 140,130,120,0,230],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","E1:M52","E2:M33","A1:M150","A2:M150","A3:M150","E0:M150","E3:M100"],
      2=>["A0:Guard","E4:M33","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150"],
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
    def self.log_path; return File.join(project_root,"Pokemon_Ability_I_AutoTest_v2_5_8.log"); end
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
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_I_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end

    def self.reset_log
      header = "CG POKEMON ABILITY I CONDITIONAL STATS + TEMPO AUTO REGRESSION v2.5.8\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; Plus/Minus + Held Item Unburden + conditional stat/damage + Slow Start\r\n" +
        "BASELINE=v2.5.7 Ability Batch H Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_B_C_D_E_F_G_H_PASS=64 BATCH_I=8 PENDING=301\r\n" +
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
      if aid.to_i == ABILITY_SNIPER && kind.to_sym == :damage_modify
        @sniper_records.push(data)
      elsif aid.to_i == ABILITY_SOLAR_POWER && kind.to_sym == :end_turn
        @solar_end_records.push(data)
      elsif aid.to_i == ABILITY_DOWNLOAD && kind.to_sym == :entry
        @download_records.push(data)
      elsif aid.to_i == ABILITY_UNBURDEN && kind.to_sym == :held_item_lost
        @unburden_loss_events += 1
      elsif aid.to_i == ABILITY_SLOW_START && kind.to_sym == :entry
        @slow_entry_events += 1
        @slow_entry_record = data
      end
      log("ABILITY_I_TRIGGER ability=" + aid.to_i.to_s + " battler=" + battler_token(battler) +
        " kind=" + kind.to_s + " ctx=" + data.inspect)
      return true
    rescue
      return true
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
        TEST_TROOP_ID,"Pokemon Ability I v2.5.8 AutoRegression",members)
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

    def self.set_weather(kind,turns=5)
      return false unless defined?(ALBERT_CG::FIELD_V233)
      ALBERT_CG::FIELD_V233.state.weather = kind
      ALBERT_CG::FIELD_V233.state.weather_turns = turns.to_i
      ALBERT_CG::ABILITY_V250.notify_weather_changed(nil) if defined?(ALBERT_CG::ABILITY_V250)
      return true
    rescue
      return false
    end

    def self.stat_stage(b,key)
      return b == nil || !b.respond_to?(:cg_stat_stage) ? 0 : b.cg_stat_stage(key).to_i
    rescue
      return 0
    end

    def self.install_unburden_test_item(battler)
      return false if battler == nil
      if defined?(ALBERT_CG::UNIQUE_K_V244) && ALBERT_CG::UNIQUE_K_V244.respond_to?(:install_test_weapons)
        ALBERT_CG::UNIQUE_K_V244.install_test_weapons
      end
      return false unless battler.respond_to?(:cg_set_battle_held_item)
      return battler.cg_set_battle_held_item(903,[:ability_i,ABILITY_UNBURDEN])
    rescue
      return false
    end

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted = true
      a = test_allies
      e = all_enemies
      assert_true("Ability Catalog count=373",defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.catalog_count.to_i == 373,
        "actual=" + (defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.catalog_count.to_i.to_s : "0"))
      ids = defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.registered_ability_ids : []
      reg_ok = HANDLED_ABILITY_IDS.all? { |id| ids.include?(id) }
      assert_true("Ability Batch I registers 8 IDs",reg_ok)
      troop_id = ($game_troop != nil && $game_troop.troop != nil) ? $game_troop.troop.id.to_i : 0
      assert_true("Scene_Battle uses Ability I test troop",troop_id == TEST_TROOP_ID,"actual=" + troop_id.to_s)
      assert_true("Ability I ally count=4",a.size == 4,"actual=" + a.size.to_s)
      active_enemy_count = e.select { |b| b != nil && !b.hidden }.size
      hidden_enemy_count = e.select { |b| b != nil && b.hidden }.size
      assert_true("Ability I starts with 4 active enemies",active_enemy_count == 4,"actual=" + active_enemy_count.to_s)
      assert_true("Ability I starts with 1 hidden Slow Start reserve",hidden_enemy_count == 1,"actual=" + hidden_enemy_count.to_s)

      # Plus / Minus：直接查正式 cg_spa。
      plus_base = with_temp_ability(a[1],0) { a[1].cg_spa.to_i }
      plus_actual = a[1].cg_spa.to_i
      plus_expected = plus_base * 150 / 100
      ok = plus_actual == plus_expected
      @stat_checks += 1 if ok
      assert_true("Plus raises SPA x1.5 with Plus/Minus partner",ok,
        "base=" + plus_base.to_s + " actual=" + plus_actual.to_s + " expected=" + plus_expected.to_s)

      minus_base = with_temp_ability(a[2],0) { a[2].cg_spa.to_i }
      minus_actual = a[2].cg_spa.to_i
      minus_expected = minus_base * 150 / 100
      ok = minus_actual == minus_expected
      @stat_checks += 1 if ok
      assert_true("Minus raises SPA x1.5 with Plus/Minus partner",ok,
        "base=" + minus_base.to_s + " actual=" + minus_actual.to_s + " expected=" + minus_expected.to_s)

      # Quick Feet：用 Paralysis 驗「抵銷 x0.5 並成為正常值 x1.5」。
      if defined?(ALBERT_CG::MOVE_EFFECT)
        a[3].remove_state(ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS)
        clear_speed = with_temp_ability(a[3],0) { a[3].cg_spe.to_i }
        a[3].add_state(ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS)
        penalized = with_temp_ability(a[3],0) { a[3].cg_spe.to_i }
        qf_speed = a[3].cg_spe.to_i
        expected = [penalized * 3,1].max
        ok = qf_speed == expected && qf_speed > clear_speed
        @stat_checks += 1 if ok
        assert_true("Quick Feet ignores Paralysis speed penalty and reaches x1.5",ok,
          "clear=" + clear_speed.to_s + " paralyzed_base=" + penalized.to_s +
          " actual=" + qf_speed.to_s + " expected=" + expected.to_s)
        a[3].remove_state(ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS)
      end

      # Download 已在 Scene_Battle start Entry 時發動。
      drec = @download_records[-1]
      download_ok = drec != nil && [:atk,:spa].include?(drec[:stat]) && drec[:after].to_i == drec[:before].to_i + 1
      @activation_checks += 1 if download_ok
      assert_true("Download Entry raises exactly one offensive stage +1",download_ok,
        "record=" + (drec == nil ? "nil" : drec.inspect))

      # Sun + Solar Power SPA。
      set_weather(:sun,5)
      solar_base = with_temp_ability(e[1],0) { e[1].cg_spa.to_i }
      solar_actual = e[1].cg_spa.to_i
      solar_expected = solar_base * 150 / 100
      ok = solar_actual == solar_expected
      @stat_checks += 1 if ok
      assert_true("Solar Power raises SPA x1.5 in Sun",ok,
        "base=" + solar_base.to_s + " actual=" + solar_actual.to_s + " expected=" + solar_expected.to_s)

      # Unburden：真實 Held Item runtime -> consume -> held_item_changed。
      install_ok = install_unburden_test_item(e[3])
      before_speed = e[3].cg_spe.to_i
      consumed = install_ok && e[3].respond_to?(:cg_consume_held_item) && e[3].cg_consume_held_item(:ability_i_regression,false)
      after_speed = e[3].cg_spe.to_i
      expected = before_speed * 2
      unburden_ok = consumed && ALBERT_CG::ABILITY_CONDITIONAL_V258.unburden_active?(e[3]) &&
        e[3].cg_held_item_id.to_i == 0 && after_speed == expected
      @activation_checks += 1 if unburden_ok
      @stat_checks += 1 if unburden_ok
      assert_true("Unburden activates on real Held Item loss and doubles SPE",unburden_ok,
        "install=" + install_ok.to_s + " consumed=" + consumed.to_s +
        " before=" + before_speed.to_s + " after=" + after_speed.to_s + " expected=" + expected.to_s)
    end

    def self.prepare_round_context
      a = test_allies
      e = all_enemies
      r = current_round
      if r == 1
        set_weather(:sun,5)
        @r1_solar_hp_before = e[1] == nil ? 0 : e[1].hp.to_i
        @r1_solar_loss = e[1] == nil ? 0 : [e[1].maxhp.to_i / 8,1].max
        @r1_storage_before = storage_size
      elsif r == 2
        if e[4] != nil
          @r2_slow_turns_before = ALBERT_CG::ABILITY_CONDITIONAL_V258.slow_start_turns(e[4])
          @r2_base_atk = with_temp_ability(e[4],0) { e[4].cg_atk_stat.to_i }
          @r2_base_spe = with_temp_ability(e[4],0) { e[4].cg_spe.to_i }
          @r2_slow_atk = e[4].cg_atk_stat.to_i
          @r2_slow_spe = e[4].cg_spe.to_i
          # TEST-only：縮短 countdown，讓本回合結束可驗 release；正式仍為 5 turns。
          ALBERT_CG::ABILITY_CONDITIONAL_V258.set_slow_start_turns(e[4],1)
        end
      end
    end

    def self.prepare_round_actions
      plan = current_plan
      return if plan == nil
      apply_test_speeds
      prepare_round_context
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
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      a = test_allies
      e = all_enemies
      if r == 1
        srec = @sniper_records[-1]
        sniper_ok = srec != nil && srec[:before].to_i > 0 && srec[:after].to_i == srec[:before].to_i * 150 / 100 && srec[:critical] == true
        @damage_checks += 1 if sniper_ok
        assert_true("Sniper boosts real Critical final damage x1.5",sniper_ok,
          "record=" + (srec == nil ? "nil" : srec.inspect))

        expected_hp = [@r1_solar_hp_before.to_i - @r1_solar_loss.to_i,0].max
        solar_ok = e[1] != nil && e[1].hp.to_i == expected_hp
        @recovery_checks += 1 if solar_ok
        assert_true("Solar Power loses MaxHP 1/8 at Sun end-turn",solar_ok,
          "hp=" + (e[1] == nil ? "nil" : e[1].hp.to_i.to_s) + " before=" + @r1_solar_hp_before.to_s +
          " loss=" + @r1_solar_loss.to_s + " expected=" + expected_hp.to_s)

        switched = e[3] != nil && e[4] != nil && e[3].hidden && !e[4].hidden
        @lifecycle_checks += 1 if switched
        assert_true("Teleport deploys hidden Slow Start reserve",switched,
          "E3_hidden=" + (e[3] == nil ? "nil" : e[3].hidden.to_s) + " E4_hidden=" + (e[4] == nil ? "nil" : e[4].hidden.to_s))
        storage_ok = storage_size == @r1_storage_before.to_i
        @lifecycle_checks += 1 if storage_ok
        assert_true("Slow Start reserve switch does not consume Storage Pokemon",storage_ok,
          "before=" + @r1_storage_before.to_s + " after=" + storage_size.to_s)
        clear_ok = e[3] != nil && !ALBERT_CG::ABILITY_CONDITIONAL_V258.unburden_active?(e[3])
        @lifecycle_checks += 1 if clear_ok
        assert_true("Unburden volatile clears on switch-out",clear_ok)
        counter_now = e[4] == nil ? -1 : ALBERT_CG::ABILITY_CONDITIONAL_V258.slow_start_turns(e[4])
        entry_ok = @slow_entry_events.to_i > 0 && @slow_entry_record != nil &&
          @slow_entry_record[:turns].to_i == 5 && counter_now == 4
        @lifecycle_checks += 1 if entry_ok
        assert_true("Slow Start reserve enters at 5 turns then ticks to 4 at same end-turn",entry_ok,
          "entry_turns=" + (@slow_entry_record == nil ? "nil" : @slow_entry_record[:turns].to_i.to_s) +
          " counter_after_end=" + counter_now.to_s)
      elsif r == 2
        atk_ok = @r2_slow_atk.to_i == [@r2_base_atk.to_i * 50 / 100,1].max
        spe_ok = @r2_slow_spe.to_i == [@r2_base_spe.to_i * 50 / 100,1].max
        @stat_checks += 1 if atk_ok
        @stat_checks += 1 if spe_ok
        assert_true("Slow Start halves effective ATK while counter active",atk_ok,
          "base=" + @r2_base_atk.to_s + " actual=" + @r2_slow_atk.to_s + " entry_turns=" + @r2_slow_turns_before.to_s)
        assert_true("Slow Start halves effective SPE while counter active",spe_ok,
          "base=" + @r2_base_spe.to_s + " actual=" + @r2_slow_spe.to_s + " entry_turns=" + @r2_slow_turns_before.to_s)
        turns_after = e[4] == nil ? -1 : ALBERT_CG::ABILITY_CONDITIONAL_V258.slow_start_turns(e[4])
        release_atk = e[4] == nil ? 0 : e[4].cg_atk_stat.to_i
        release_spe = e[4] == nil ? 0 : e[4].cg_spe.to_i
        release_ok = turns_after == 0 && release_atk == @r2_base_atk.to_i && release_spe == @r2_base_spe.to_i
        @lifecycle_checks += 1 if release_ok
        assert_true("Slow Start releases after countdown reaches 0",release_ok,
          "turns=" + turns_after.to_s + " atk=" + release_atk.to_s + "/" + @r2_base_atk.to_s +
          " spe=" + release_spe.to_s + "/" + @r2_base_spe.to_s)
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
        " ability_i=" + ability_covered_count.to_s + "/8" +
        " stat_checks=" + @stat_checks.to_i.to_s +
        " damage_checks=" + @damage_checks.to_i.to_s +
        " activation_checks=" + @activation_checks.to_i.to_s +
        " recovery_checks=" + @recovery_checks.to_i.to_s +
        " lifecycle_checks=" + @lifecycle_checks.to_i.to_s + " pending=301")
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
      @last_records = {}
      @sniper_records = []
      @solar_end_records = []
      @download_records = []
      @unburden_loss_events = 0
      @slow_entry_events = 0
      @slow_entry_record = nil
      @stat_checks = 0
      @damage_checks = 0
      @activation_checks = 0
      @recovery_checks = 0
      @lifecycle_checks = 0
      @actual = []
      @boot_asserted = false
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
      if defined?(ALBERT_CG::UNIQUE_K_V244) && ALBERT_CG::UNIQUE_K_V244.respond_to?(:install_test_weapons)
        ALBERT_CG::UNIQUE_K_V244.install_test_weapons
      end
      @active = true
      if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
        ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_I_v2.5.8")
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
# ■ Older Ability regression F11：Batch I 成為唯一最新版
#==============================================================================
if defined?(ALBERT_CG::ABILITY_H_V257)
  module ALBERT_CG; module ABILITY_H_V257; def self.f11_trigger?; return false; end; end; end
end

#==============================================================================
# ■ Regression-only deterministic bridges
#==============================================================================
class Game_Battler
  alias cg_v258i_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_I_V258) && ALBERT_CG::ABILITY_I_V258.active?
    return cg_v258i_ability_calc_eva(user,obj)
  end

  alias cg_v258i_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_I_V258) && ALBERT_CG::ABILITY_I_V258.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v258i_ability_priority_base_speed
  rescue
    return cg_v258i_ability_priority_base_speed
  end

  alias cg_v258i_ability_critical cg_pokemon_critical?
  def cg_pokemon_critical?(user,obj=nil)
    if defined?(ALBERT_CG::ABILITY_I_V258) && ALBERT_CG::ABILITY_I_V258.active? &&
       ALBERT_CG::ABILITY_I_V258.current_round == 1 && user != nil && !user.actor? &&
       user.index.to_i == 2 && defined?(ALBERT_CG::ABILITY_V250) &&
       ALBERT_CG::ABILITY_V250.current_move_id(user).to_i == 33
      return true
    end
    return cg_v258i_ability_critical(user,obj)
  end
end

class Game_Enemy < Game_Battler
  alias cg_v258i_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_I_V258) && ALBERT_CG::ABILITY_I_V258.active?
      action = ALBERT_CG::ABILITY_I_V258.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v258i_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v258i_ability_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::ABILITY_I_V258.record_execution(battler) if defined?(ALBERT_CG::ABILITY_I_V258) && ALBERT_CG::ABILITY_I_V258.active?
    return cg_v258i_ability_execute_action
  end

  alias cg_v258i_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_I_V258) && ALBERT_CG::ABILITY_I_V258.active?
      # 先執行正式 Ability end_turn，ASSERT 才能觀察 Solar Power / Slow Start 後狀態。
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      end
      ALBERT_CG::ABILITY_I_V258.finish_round_assertions
    end
    return cg_v258i_ability_turn_end
  end

  alias cg_v258i_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_I_V258) && ALBERT_CG::ABILITY_I_V258.active?
      return cg_v258i_ability_start_party_command
    end
    cg_v258i_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_I_V258.assert_bootstrap_once
    if ALBERT_CG::ABILITY_I_V258.finished?
      ALBERT_CG::ABILITY_I_V258.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_I_V258.prepare_round_actions
    start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v258i_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v258i_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_I_V258) && ALBERT_CG::ABILITY_I_V258.active?
        for cfg in ALBERT_CG::ABILITY_I_V258::TEST_ALLIES
          ALBERT_CG::ABILITY_I_V258.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_I_V258::TEST_LEVEL,false)
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
  alias cg_v258i_ability_scene_map_update update
  def update
    cg_v258i_ability_scene_map_update
    if !$game_temp.in_battle && !ALBERT_CG::ABILITY_I_V258.active? && ALBERT_CG::ABILITY_I_V258.f11_trigger?
      Sound.play_decision
      ALBERT_CG::ABILITY_I_V258.start_auto_test
    end
  end
end
