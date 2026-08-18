# RMVX_SCRIPT_INDEX: 217
# RMVX_SCRIPT_ID: 252000002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch C v2.5.2a
# RMVX_SOURCE_SHA256: 7186b09e5838257b87879a2237db63c0d9531fa2677af469d78f73a83ae04673

#==============================================================================
# ■ CG Pokemon Ability Batch C v2.5.2a - Weather & Recovery RGSS2 Troop Fix
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.0 Ability Runtime Core、v2.5.1 Batch B PASS 基底與 v2.5.2 Weather
#  Authority 上，正式實作第三批 8 個天氣／回合末 Ability，並提供 Actual
#  Scene_Battle deterministic F11 regression。
#
# 【本批 Ability】
#   33 Swift Swim    悠游自如：Rain 時 SPE x2。
#   34 Chlorophyll   葉綠素：Sun 時 SPE x2。
#   44 Rain Dish     雨盤：Rain 回合末回復 MaxHP 1/16。
#   45 Sand Stream   揚沙：進場建立 Sandstorm 5 turns。
#   70 Drought       日照：進場建立 Sun 5 turns。
#   93 Hydration     濕潤之軀：Rain 回合末解除主要異常狀態。
#  115 Ice Body      冰凍之軀：Hail 回合末回復 MaxHP 1/16。
#  117 Snow Warning  降雪：進場建立 Hail 5 turns（配合本專案既有 Field :hail）。
#
# 【主要設定項】
#  TEST_TROOP_ID = 705；F11 只啟動本 Batch C Regression。
#  HANDLED_ABILITY_IDS：本批 8 ID，Coverage 由 357 pending -> 349 pending。
#  TEST Convenience 仍為 TEST-only：略過 emerged、Battle BGM/BGS 靜音、背景 helper。
#
# 【機制規則】
#  1. 天氣唯一權威仍是 ALBERT_CG::FIELD_V233.state；不建立第二套 Weather state。
#  2. Entry Weather 透過 ABILITY_WEATHER_V252.set_weather 設定並通知
#     :weather_changed；Swift Swim / Chlorophyll 的提示事件在真正對應天氣啟動時產生。
#  3. Swift Swim / Chlorophyll 的實際 SPE x2 由 Weather Authority 的 cg_spe 外層完成；
#     本 Batch 不另改 Action Priority 正式核心。
#  4. Rain Dish / Hydration / Ice Body 使用 Ability Core :end_turn；Regression 為了在
#     Field turn decrement 前 ASSERT，會先手動 trigger_end_turn，再 suppress Core 內層
#     的重複 end-turn dispatch。正式玩家戰鬥仍只有一次正常 dispatch。
#  5. Snow Warning 使用本專案現有 :hail，因 Field Core v2.3.3a 的冰雹 residual、
#     Weather Move 258 與既有資料均以 :hail 為正式 runtime symbol。
#  6. 所有有效 Ability 讀 cg_master_ability_id，繼續尊重 Gastro Acid / Skill Swap /
#     Role Play / Transform 等 Battle-only Ability Override / Suppression。
#
# 【可調參數】
#  HEAL_DIVISOR = 16；Entry Weather duration 由 Weather Authority WEATHER_TURNS 控制。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11 一次，自動跑三回合並回地圖。
#
# 【實際範例】
#  Round1：先驗 Sand Stream entry，再由 regression 設 Rain；Swift Swim x2、Rain Dish
#          heal、Hydration cure。
#  Round2：Teleport 讓 hidden Drought 進場，驗 Sun 5 turns。
#  Round3：Sun 下驗 Chlorophyll x2；Drought Teleport -> hidden Snow Warning，驗 Hail
#          5 turns + Ice Body heal。
#
# 【v2.5.2a 修正】
#  Regression bootstrap 不再呼叫 RGSS2 Game_Troop 不存在的 troop_id；改由
#  $game_troop.troop.id 讀取實際 Troop ID。此修正只影響測試 ASSERT，不修改任何
#  Weather / Ability 正式 Runtime。
#
# 【正式版要求】
#  本頁 Ability runtime 可保留；F11 regression / TEST Convenience 只屬開發版。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchC"] = "2.5.2a"

module ALBERT_CG
  module ABILITY_C_V252
    VERSION = "2.5.2a"
    TEST_TROOP_ID = 705
    TEST_LEVEL = 40
    VK_F11 = 0x7A
    HEAL_DIVISOR = 16

    ABILITY_SWIFT_SWIM   = 33
    ABILITY_CHLOROPHYLL  = 34
    ABILITY_RAIN_DISH    = 44
    ABILITY_SAND_STREAM  = 45
    ABILITY_DROUGHT      = 70
    ABILITY_HYDRATION    = 93
    ABILITY_ICE_BODY     = 115
    ABILITY_SNOW_WARNING = 117

    HANDLED_ABILITY_IDS = [
      ABILITY_SWIFT_SWIM, ABILITY_CHLOROPHYLL, ABILITY_RAIN_DISH,
      ABILITY_SAND_STREAM, ABILITY_DROUGHT, ABILITY_HYDRATION,
      ABILITY_ICE_BODY, ABILITY_SNOW_WARNING
    ]

    TEST_ALLIES = [
      {:dex=>134,:level=>40,:ability=>ABILITY_SWIFT_SWIM, :moves=>[150,150,150,150]},
      {:dex=>131,:level=>40,:ability=>ABILITY_RAIN_DISH,  :moves=>[150,150,150,150]},
      {:dex=>121,:level=>40,:ability=>ABILITY_HYDRATION,  :moves=>[150,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>248,:level=>40,:ability=>ABILITY_SAND_STREAM,  :moves=>[150,150,150,150]},
      {:dex=>3,  :level=>40,:ability=>ABILITY_CHLOROPHYLL,  :moves=>[150,150,150,150]},
      {:dex=>131,:level=>40,:ability=>ABILITY_ICE_BODY,     :moves=>[150,150,150,150]},
      {:dex=>113,:level=>40,:ability=>0,                    :moves=>[100,150,150,150]},
      {:dex=>6,  :level=>40,:ability=>ABILITY_DROUGHT,      :moves=>[100,150,150,150]},
      {:dex=>144,:level=>40,:ability=>ABILITY_SNOW_WARNING, :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"RAIN_SWIFT_RAIN_DISH_HYDRATION",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
      {
        :name=>"DROUGHT_SWITCH_IN",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>100,:target=>3},
        }
      },
      {
        :name=>"SUN_CHLOROPHYLL_SNOW_WARNING_ICE_BODY",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          4=>{:kind=>:move,:move_id=>100,:target=>4},
        }
      },
    ]

    # Raw deterministic SPE overrides. Batch C's wrapper applies weather speed x2
    # to the override itself, so Swift Swim / Chlorophyll are exercised in real ordering.
    TEST_SPEEDS = {
      :r1=>[10,100,140,130, 180,170,160,150,0,0],
      :r2=>[10,100,140,130, 180,170,160,150,0,0],
      :r3=>[10,190,140,130, 180,100,160,0,150,0],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M150","E0:M150","E1:M150","E2:M150","E3:M150","A2:M150","A3:M150"],
      2=>["A0:Guard","A1:M150","E0:M150","E1:M150","E2:M150","A2:M150","A3:M150","E3:M100"],
      3=>["A0:Guard","E1:M150","A1:M150","E0:M150","E2:M150","A2:M150","A3:M150","E4:M100"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.master
      return defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil
    end

    def self.active?; return @active == true; end
    def self.current_round; return @round_index.to_i + 1; end
    def self.current_plan; return ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; return @round_index.to_i >= ROUND_PLANS.size; end
    def self.test_allies; return $game_party == nil ? [] : $game_party.members; end
    def self.all_enemies; return $game_troop == nil ? [] : $game_troop.members; end

    def self.project_root
      return Dir.pwd
    rescue
      return "."
    end

    def self.log_path
      return File.join(project_root,"Pokemon_Ability_C_AutoTest_v2_5_2a.log")
    end

    def self.latest_log_path
      return File.join(project_root,"CG_AutoRegression_LATEST.log")
    end

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
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_C_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end

    def self.reset_log
      header = "CG POKEMON ABILITY C WEATHER + RECOVERY AUTO REGRESSION v2.5.2a\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; Weather Entry / Weather Speed / End-turn heal+cure\r\n" +
        "BASELINE=v2.5.1 Ability Batch B Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_PASS=8 BATCH_B_PASS=8 BATCH_C=8 PENDING=349\r\n" +
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

    def self.note_ability_trigger(aid,battler,label)
      @ability_trigger_counts[aid.to_i] = @ability_trigger_counts[aid.to_i].to_i + 1
      log("ABILITY_C_TRIGGER ability=" + aid.to_i.to_s + " battler=" + battler_token(battler) +
        " kind=" + label.to_s) if active?
      return true
    rescue
      return false
    end

    def self.weather_state
      return nil unless defined?(ALBERT_CG::FIELD_V233)
      return ALBERT_CG::FIELD_V233.state
    rescue
      return nil
    end

    def self.weather_active?(kind)
      return false unless defined?(ALBERT_CG::ABILITY_WEATHER_V252)
      return ALBERT_CG::ABILITY_WEATHER_V252.weather_active?(kind)
    rescue
      return false
    end

    #--------------------------------------------------------------------------
    # Ability handlers
    #--------------------------------------------------------------------------
    def self.apply_swift_swim_weather(battler,ctx)
      return false unless weather_active?(:rain)
      note_ability_trigger(ABILITY_SWIFT_SWIM,battler,:weather_changed)
      return true
    end

    def self.apply_chlorophyll_weather(battler,ctx)
      return false unless weather_active?(:sun)
      note_ability_trigger(ABILITY_CHLOROPHYLL,battler,:weather_changed)
      return true
    end

    def self.set_entry_weather(battler,aid,kind)
      return false if battler == nil || !defined?(ALBERT_CG::ABILITY_WEATHER_V252)
      ok = ALBERT_CG::ABILITY_WEATHER_V252.set_weather(kind,battler,aid)
      if ok
        log("ABILITY_ENTRY_WEATHER ability=" + aid.to_s + " battler=" + battler_token(battler) +
          " weather=" + kind.to_s + " turns=" + weather_state.weather_turns.to_i.to_s) if active?
        note_ability_trigger(aid,battler,:entry)
      end
      return ok
    end

    def self.apply_sand_stream(battler,ctx)
      return set_entry_weather(battler,ABILITY_SAND_STREAM,:sandstorm)
    end

    def self.apply_drought(battler,ctx)
      return set_entry_weather(battler,ABILITY_DROUGHT,:sun)
    end

    def self.apply_snow_warning(battler,ctx)
      return set_entry_weather(battler,ABILITY_SNOW_WARNING,:hail)
    end

    def self.heal_weather(battler,kind,aid,label)
      return false if battler == nil || battler.hp.to_i <= 0 || !weather_active?(kind)
      return false if battler.hp.to_i >= battler.maxhp.to_i
      gain = [battler.maxhp.to_i / HEAL_DIVISOR,1].max
      before = battler.hp.to_i
      battler.hp = [before + gain,battler.maxhp.to_i].min
      actual = battler.hp.to_i - before
      return false if actual <= 0
      battler.hp_damage = -actual if battler.respond_to?(:hp_damage=)
      log("ABILITY_" + label + " battler=" + battler_token(battler) +
        " hp=" + before.to_s + "->" + battler.hp.to_i.to_s + " heal=" + actual.to_s) if active?
      note_ability_trigger(aid,battler,:end_turn)
      return true
    end

    def self.apply_rain_dish(battler,ctx)
      return heal_weather(battler,:rain,ABILITY_RAIN_DISH,"RAIN_DISH")
    end

    def self.apply_ice_body(battler,ctx)
      return heal_weather(battler,:hail,ABILITY_ICE_BODY,"ICE_BODY")
    end

    def self.apply_hydration(battler,ctx)
      return false if battler == nil || !weather_active?(:rain) || !defined?(ALBERT_CG::MOVE_EFFECT)
      removed = []
      for sid in ALBERT_CG::MOVE_EFFECT::PRIMARY_STATES
        if battler.state?(sid)
          battler.remove_state(sid)
          removed.push(sid)
        end
      end
      return false if removed.empty?
      log("ABILITY_HYDRATION battler=" + battler_token(battler) + " removed=" + removed.inspect) if active?
      note_ability_trigger(ABILITY_HYDRATION,battler,:end_turn)
      return true
    end

    def self.register_handlers
      core = ALBERT_CG::ABILITY_V250
      core.register(ABILITY_SWIFT_SWIM,:weather_changed,self,:apply_swift_swim_weather)
      core.register(ABILITY_CHLOROPHYLL,:weather_changed,self,:apply_chlorophyll_weather)
      core.register(ABILITY_RAIN_DISH,:end_turn,self,:apply_rain_dish)
      core.register(ABILITY_SAND_STREAM,:entry,self,:apply_sand_stream)
      core.register(ABILITY_DROUGHT,:entry,self,:apply_drought)
      core.register(ABILITY_HYDRATION,:end_turn,self,:apply_hydration)
      core.register(ABILITY_ICE_BODY,:end_turn,self,:apply_ice_body)
      core.register(ABILITY_SNOW_WARNING,:entry,self,:apply_snow_warning)
    end

    #--------------------------------------------------------------------------
    # Regression setup
    #--------------------------------------------------------------------------
    def self.configure_actor(cfg)
      actor = $game_actors[master.actor_id_for_dex(cfg[:dex])]
      return if actor == nil
      master.configure_actor(actor,cfg)
      actor.recover_all if actor.respond_to?(:recover_all)
      actor.cg_reset_stat_stages if actor.respond_to?(:cg_reset_stat_stages)
      actor.cg_v242_clear_runtime if actor.respond_to?(:cg_v242_clear_runtime)
    end

    def self.configure_enemy(cfg)
      master.configure_enemy_data(cfg)
    end

    def self.prepare_test_party
      ids = TEST_ALLIES.collect { |cfg| master.actor_id_for_dex(cfg[:dex]) }
      if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
        ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids)
      end
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      for cfg in TEST_ALLIES
        configure_actor(cfg)
      end
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
      xs = [ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,
            ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],
            ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],
            ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg,i|
        configure_enemy(cfg)
        m = ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]),xs[i],ys[i])
        m.hidden = (i >= 4)
        members.push(m)
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID,"Pokemon Ability C v2.5.2a AutoRegression",members)
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

    def self.set_test_weather(kind,turns=5)
      return false unless defined?(ALBERT_CG::ABILITY_WEATHER_V252)
      return ALBERT_CG::ABILITY_WEATHER_V252.set_weather(kind,nil,0,turns)
    end

    def self.prepare_round_preconditions
      a = test_allies
      e = all_enemies
      st = weather_state
      if current_round == 1
        # Battle start has already proven Sand Stream. Regression now establishes Rain
        # to exercise the rain-dependent passive family in the same real Scene_Battle.
        set_test_weather(:rain,5)
        a[2].hp = [a[2].maxhp.to_i - 48,1].max
        @r1_rain_dish_before = a[2].hp.to_i
        @r1_rain_dish_heal = [a[2].maxhp.to_i / HEAL_DIVISOR,1].max
        a[3].add_state(ALBERT_CG::MOVE_EFFECT::STATE_POISON)
        @r1_hydration_poisoned = a[3].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON)
        # Direct functional speed probe without triggering a second weather change.
        saved_weather = st.weather
        saved_turns = st.weather_turns
        st.weather = nil
        st.weather_turns = 0
        @r1_swift_clear_spe = a[1].cg_spe.to_i
        st.weather = saved_weather
        st.weather_turns = saved_turns
        @r1_swift_rain_spe = a[1].cg_spe.to_i
      elsif current_round == 2
        @r2_storage_before = defined?(ALBERT_CG::PET_STORAGE) && ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0
      elsif current_round == 3
        # Drought from Round2 should still be active (5 -> 4 after Field turn-end).
        saved_weather = st.weather
        saved_turns = st.weather_turns
        @r3_sun_before = [saved_weather,saved_turns.to_i]
        st.weather = nil
        st.weather_turns = 0
        @r3_chloro_clear_spe = e[1].cg_spe.to_i
        st.weather = saved_weather
        st.weather_turns = saved_turns
        @r3_chloro_sun_spe = e[1].cg_spe.to_i
        e[2].hp = [e[2].maxhp.to_i - 48,1].max
        @r3_ice_body_before = e[2].hp.to_i
        @r3_ice_body_heal = [e[2].maxhp.to_i / HEAL_DIVISOR,1].max
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

    def self.move_id_from_action(action)
      return 0 if action == nil || !action.skill?
      skill = $data_skills[action.skill_id]
      return 0 if skill == nil
      return ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i
    rescue
      return 0
    end

    def self.record_execution(battler)
      return unless active? && battler != nil
      token = battler_token(battler)
      action = battler.action
      if action != nil && action.guard?
        token += ":Guard"
      elsif action != nil && action.skill?
        token += ":M" + move_id_from_action(action).to_s
      else
        token += ":Attack"
      end
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + battler.name.to_s + " token=" + token)
    rescue
    end

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted = true
      st = weather_state
      assert_true("Ability Catalog count=373",ALBERT_CG::ABILITY_V250.catalog_count.to_i == 373,
        "actual=" + ALBERT_CG::ABILITY_V250.catalog_count.to_i.to_s)
      ids = ALBERT_CG::ABILITY_V250.registered_ability_ids
      reg_ok = HANDLED_ABILITY_IDS.all? { |aid| ids.include?(aid) }
      assert_true("Ability Batch C registers 8 IDs",reg_ok)
      actual_troop_id = ($game_troop != nil && $game_troop.troop != nil) ? $game_troop.troop.id.to_i : 0
      assert_true("Scene_Battle uses Ability C test troop",actual_troop_id == TEST_TROOP_ID,
        "actual=" + actual_troop_id.to_s)
      assert_true("Ability C ally count=4",test_allies.size == 4,"actual=" + test_allies.size.to_s)
      active_enemy_count = all_enemies.select { |b| b != nil && !b.hidden }.size
      hidden_enemy_count = all_enemies.select { |b| b != nil && b.hidden }.size
      assert_true("Ability C starts with 4 active enemies",active_enemy_count == 4,"actual=" + active_enemy_count.to_s)
      assert_true("Ability C starts with 2 hidden weather reserves",hidden_enemy_count == 2,"actual=" + hidden_enemy_count.to_s)
      sand_ok = st != nil && st.weather == :sandstorm && st.weather_turns.to_i == 5
      @weather_checks += 1 if sand_ok
      assert_true("Sand Stream Entry establishes Sandstorm 5 turns",sand_ok,
        "weather=" + (st == nil ? "nil" : st.weather.to_s) + " turns=" + (st == nil ? "0" : st.weather_turns.to_i.to_s))
    end

    def self.assert_round
      r = current_round
      expected = EXPECTED_EXECUTION_TOKENS[r]
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      a = test_allies
      e = all_enemies
      st = weather_state
      if r == 1
        swift_ok = @r1_swift_clear_spe.to_i > 0 && @r1_swift_rain_spe.to_i == @r1_swift_clear_spe.to_i * 2
        @speed_checks += 1 if swift_ok
        assert_true("Swift Swim doubles effective SPE in Rain",swift_ok,
          "clear=" + @r1_swift_clear_spe.to_s + " rain=" + @r1_swift_rain_spe.to_s)
        expected_hp = [@r1_rain_dish_before.to_i + @r1_rain_dish_heal.to_i,a[2].maxhp.to_i].min
        rain_ok = a[2].hp.to_i == expected_hp
        @recovery_checks += 1 if rain_ok
        assert_true("Rain Dish heals 1/16 MaxHP at Rain end-turn",rain_ok,
          "hp=" + @r1_rain_dish_before.to_s + "->" + a[2].hp.to_i.to_s + " expected=" + expected_hp.to_s)
        hyd_ok = @r1_hydration_poisoned == true && !a[3].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON)
        @recovery_checks += 1 if hyd_ok
        assert_true("Hydration cures primary status at Rain end-turn",hyd_ok)
        rain_state_ok = st != nil && st.weather == :rain && st.weather_turns.to_i == 5
        @weather_checks += 1 if rain_state_ok
        assert_true("Rain remains active before Field decrement",rain_state_ok,
          "weather=" + st.weather.to_s + " turns=" + st.weather_turns.to_i.to_s)
      elsif r == 2
        drought_ok = e[3].hidden && !e[4].hidden && st != nil && st.weather == :sun && st.weather_turns.to_i == 5
        @weather_checks += 1 if drought_ok
        assert_true("Teleport deploys Drought reserve and establishes Sun 5 turns",drought_ok,
          "E3_hidden=" + e[3].hidden.to_s + " E4_hidden=" + e[4].hidden.to_s +
          " weather=" + (st == nil ? "nil" : st.weather.to_s) + " turns=" + (st == nil ? "0" : st.weather_turns.to_i.to_s))
        storage_after = defined?(ALBERT_CG::PET_STORAGE) && ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0
        storage_ok = storage_after == @r2_storage_before.to_i
        @lifecycle_checks += 1 if storage_ok
        assert_true("Weather reserve switch does not consume Storage Pokémon",storage_ok,
          "before=" + @r2_storage_before.to_s + " after=" + storage_after.to_s)
        # Ensure Round3 Teleport has only Snow Warning as a legal hidden living reserve.
        e[3].hp = 0 if e[3] != nil && e[3].hidden
      elsif r == 3
        sun_pre_ok = @r3_sun_before != nil && @r3_sun_before[0] == :sun && @r3_sun_before[1].to_i == 4
        @weather_checks += 1 if sun_pre_ok
        assert_true("Drought Sun survives into Round3 with 4 turns",sun_pre_ok,
          "before=" + @r3_sun_before.inspect)
        chloro_ok = @r3_chloro_clear_spe.to_i > 0 && @r3_chloro_sun_spe.to_i == @r3_chloro_clear_spe.to_i * 2
        @speed_checks += 1 if chloro_ok
        assert_true("Chlorophyll doubles effective SPE in Sun",chloro_ok,
          "clear=" + @r3_chloro_clear_spe.to_s + " sun=" + @r3_chloro_sun_spe.to_s)
        snow_ok = e[4].hidden && !e[5].hidden && st != nil && st.weather == :hail && st.weather_turns.to_i == 5
        @weather_checks += 1 if snow_ok
        assert_true("Drought Teleport deploys Snow Warning reserve and establishes Hail 5 turns",snow_ok,
          "E4_hidden=" + e[4].hidden.to_s + " E5_hidden=" + e[5].hidden.to_s +
          " weather=" + (st == nil ? "nil" : st.weather.to_s) + " turns=" + (st == nil ? "0" : st.weather_turns.to_i.to_s))
        expected_hp = [@r3_ice_body_before.to_i + @r3_ice_body_heal.to_i,e[2].maxhp.to_i].min
        ice_ok = e[2].hp.to_i == expected_hp
        @recovery_checks += 1 if ice_ok
        assert_true("Ice Body heals 1/16 MaxHP at Hail end-turn",ice_ok,
          "hp=" + @r3_ice_body_before.to_s + "->" + e[2].hp.to_i.to_s + " expected=" + expected_hp.to_s)
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
      for aid in HANDLED_ABILITY_IDS
        count += 1 if @ability_trigger_counts[aid].to_i > 0
      end
      return count
    end

    def self.cleanup_test_overrides
      list = test_allies + all_enemies
      for b in list
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
        " ability_c=" + ability_covered_count.to_s + "/8" +
        " weather_checks=" + @weather_checks.to_i.to_s +
        " speed_checks=" + @speed_checks.to_i.to_s +
        " recovery_checks=" + @recovery_checks.to_i.to_s +
        " lifecycle_checks=" + @lifecycle_checks.to_i.to_s + " pending=349")
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
      @weather_checks = 0
      @speed_checks = 0
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
      @active = true
      if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
        ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_C_v2.5.2a")
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
# ■ Register Batch C into Ability Core
#==============================================================================
ALBERT_CG::ABILITY_C_V252.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Older Ability regression observers/F11：Batch C 成為唯一最新版
#==============================================================================
if defined?(ALBERT_CG::ABILITY_B_V251)
  module ALBERT_CG
    module ABILITY_B_V251
      def self.f11_trigger?; return false; end
    end
  end
end
if defined?(ALBERT_CG::ABILITY_A_V250)
  module ALBERT_CG
    module ABILITY_A_V250
      def self.f11_trigger?; return false; end
    end
  end
end

#==============================================================================
# ■ Regression deterministic hit/evasion + weather-aware SPE override
#==============================================================================
class Game_Battler
  alias cg_v252c_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    return 100 if defined?(ALBERT_CG::ABILITY_C_V252) && ALBERT_CG::ABILITY_C_V252.active?
    return cg_v252c_ability_calc_hit(user,obj)
  end

  alias cg_v252c_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_C_V252) && ALBERT_CG::ABILITY_C_V252.active?
    return cg_v252c_ability_calc_eva(user,obj)
  end

  alias cg_v252c_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_C_V252) && ALBERT_CG::ABILITY_C_V252.active?
      value = @cg_priority_test_speed_override
      if value != nil && defined?(ALBERT_CG::ABILITY_WEATHER_V252)
        return ALBERT_CG::ABILITY_WEATHER_V252.apply_speed(value.to_i,self)
      elsif value != nil
        return value.to_i
      end
    end
    return cg_v252c_ability_priority_base_speed
  rescue
    return cg_v252c_ability_priority_base_speed
  end
end

#==============================================================================
# ■ Game_Enemy deterministic action
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v252c_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_C_V252) && ALBERT_CG::ABILITY_C_V252.active?
      action = ALBERT_CG::ABILITY_C_V252.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v252c_ability_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle Regression control
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v252c_ability_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::ABILITY_C_V252.record_execution(battler) if defined?(ALBERT_CG::ABILITY_C_V252) && ALBERT_CG::ABILITY_C_V252.active?
    return cg_v252c_ability_execute_action
  end

  alias cg_v252c_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_C_V252) && ALBERT_CG::ABILITY_C_V252.active?
      # Assertions must observe Rain Dish/Hydration/Ice Body before Field decrements weather.
      ALBERT_CG::ABILITY_V250.trigger_end_turn
      ALBERT_CG::ABILITY_C_V252.finish_round_assertions
      ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
    end
    return cg_v252c_ability_turn_end
  end

  alias cg_v252c_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_C_V252) && ALBERT_CG::ABILITY_C_V252.active?
      return cg_v252c_ability_start_party_command
    end
    cg_v252c_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_C_V252.assert_bootstrap_once
    if ALBERT_CG::ABILITY_C_V252.finished?
      ALBERT_CG::ABILITY_C_V252.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_C_V252.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle rebuild 後重套 Ability C test data
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v252c_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v252c_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_C_V252) && ALBERT_CG::ABILITY_C_V252.active?
        for cfg in ALBERT_CG::ABILITY_C_V252::TEST_ALLIES
          ALBERT_CG::ABILITY_C_V252.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_C_V252::TEST_LEVEL,false)
          human.recover_all
          human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
          human.instance_variable_set(:@cg_master_ability_id,0)
        end
      end
      return result
    end
  end
end

#==============================================================================
# ■ F11：v2.5.2a Ability Batch C 成為唯一最新版 AutoRegression
#==============================================================================
class Scene_Map < Scene_Base
  alias cg_v252c_ability_scene_map_update update
  def update
    cg_v252c_ability_scene_map_update
    if !$game_temp.in_battle && !ALBERT_CG::ABILITY_C_V252.active? &&
       ALBERT_CG::ABILITY_C_V252.f11_trigger?
      Sound.play_decision
      ALBERT_CG::ABILITY_C_V252.start_auto_test
    end
  end
end
