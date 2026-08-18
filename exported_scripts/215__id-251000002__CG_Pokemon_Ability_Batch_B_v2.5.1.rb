# RMVX_SCRIPT_INDEX: 215
# RMVX_SCRIPT_ID: 251000002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch B v2.5.1
# RMVX_SOURCE_SHA256: 3de0e3c04eeb54ce3dc3f316fa3455618e183655b46efad260886912806c7451

#==============================================================================
# ■ CG Pokemon Ability Batch B v2.5.1
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.0b 已實機 PASS 的 Ability Runtime Core + Batch A 基底上，完成第二批
#  「防護／免疫」Ability，集中驗證 State Guard 與 Type-based before_hit immunity。
#
# 【本批 Ability】
#    7 Limber／柔軟          阻止 Paralysis。
#   11 Water Absorb／儲水    Water damaging Move 無效並回復 1/4 MaxHP。
#   15 Insomnia／不眠        阻止 Sleep。
#   17 Immunity／免疫        阻止 Poison / Bad Poison。
#   25 Wonder Guard／神奇守護 只有 Super-effective damaging Move 可造成效果／傷害。
#   26 Levitate／飄浮        Ground damaging Move 無效。
#   40 Magma Armor／熔岩鎧甲  阻止 Freeze。
#   41 Water Veil／水幕      阻止 Burn。
#
# 【主要設定項】
#  HANDLED_ABILITY_IDS：本批 8 個 Ability ID。
#  TEST_TROOP_ID=704：F11 專用 deterministic Scene_Battle。
#  TEST Convenience：沿用 v0.2，F11 測試略過 emerged、Battle BGM/BGS 靜音、
#  背景 keepalive；正式 Release 必須恢復正常。
#
# 【機制規則】
#  1. Limber/Insomnia/Immunity/Magma Armor/Water Veil 由 Ability Guard Authority
#     v2.5.1 攔截所有既有狀態入口，不只 Generic Move Effect。
#  2. Water Absorb / Levitate / Wonder Guard 透過 Ability Core :before_hit dispatch，
#     不修改 Move Master、Type chart 或正式 Move Runtime。
#  3. Water Absorb 只對敵方 Water damaging Move 生效，傷害取消並回 1/4 MaxHP。
#  4. Levitate 只取消敵方 Ground damaging Move；Grounded/Gravity Ability 互動待後續
#     Grounded Ability family 統一接入，避免本批擅自覆蓋既有 Field authority。
#  5. Wonder Guard 對 type_rate <=100 的 damaging Move 取消；type_rate>100 正常通過。
#  6. 所有有效 Ability ID 都讀 cg_master_ability_id，尊重既有 Ability Override/Suppression。
#
# 【可調參數】
#  TEST_LEVEL=40、TEST_TROOP_ID=704。正式 Ability 效果本身無測試專用倍率。
#
# 【事件／腳本呼叫方式】
#  地圖 F11：ALBERT_CG::ABILITY_B_V251.start_auto_test
#  事件 Script：ALBERT_CG::ABILITY_B_V251.start_auto_test
#
# 【實際範例】
#  Round1：直接在真實 Scene_Battle 對五個 Guard Ability 嘗試附加對應狀態，
#          確認全部被拒絕；Magma Armor 使用者再 Teleport 讓 hidden Wonder Guard 入場。
#  Round2：Water Gun -> Water Absorb；Earth Power -> Levitate；Tackle -> Wonder Guard。
#  Round3：Flamethrower -> Parasect + Wonder Guard，因 Fire 超有效而必須正常造成傷害。
#
# 【成功標準】
#  RESULT=PASS
#  SUMMARY rounds=3 failures=0 ability_b=8/8 guard_checks=... immunity_checks=... pending=357
#
# 【重要】
#  未取得使用者 RPG Maker VX 實機 LOG 前，本版只能稱 TEST BUILD。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchB"] = "2.5.1"

module ALBERT_CG
  module ABILITY_B_V251
    VERSION = "2.5.1"

    ABILITY_LIMBER = 7
    ABILITY_WATER_ABSORB = 11
    ABILITY_INSOMNIA = 15
    ABILITY_IMMUNITY = 17
    ABILITY_WONDER_GUARD = 25
    ABILITY_LEVITATE = 26
    ABILITY_MAGMA_ARMOR = 40
    ABILITY_WATER_VEIL = 41

    HANDLED_ABILITY_IDS = [
      ABILITY_LIMBER,ABILITY_WATER_ABSORB,ABILITY_INSOMNIA,ABILITY_IMMUNITY,
      ABILITY_WONDER_GUARD,ABILITY_LEVITATE,ABILITY_MAGMA_ARMOR,ABILITY_WATER_VEIL
    ]

    TEST_TROOP_ID = 704
    TEST_LEVEL = 40
    VK_F11 = 0x7A

    TEST_ALLIES = [
      {:dex=>133,:level=>40,:ability=>ABILITY_LIMBER,   :moves=>[55,53,150,150]},
      {:dex=>143,:level=>40,:ability=>ABILITY_INSOMNIA, :moves=>[414,150,150,150]},
      {:dex=>134,:level=>40,:ability=>ABILITY_IMMUNITY, :moves=>[33,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>36, :level=>40,:ability=>ABILITY_WATER_VEIL,  :moves=>[150,150,150,150]},
      {:dex=>131,:level=>40,:ability=>ABILITY_WATER_ABSORB,:moves=>[150,150,150,150]},
      {:dex=>68, :level=>40,:ability=>ABILITY_LEVITATE,    :moves=>[150,150,150,150]},
      {:dex=>113,:level=>40,:ability=>ABILITY_MAGMA_ARMOR, :moves=>[100,150,150,150]},
      {:dex=>47, :level=>40,:ability=>ABILITY_WONDER_GUARD,:moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"STATE_GUARDS_AND_WONDER_ENTRY",
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
        :name=>"WATER_ABSORB_LEVITATE_WONDER_GUARD",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>55,:target=>1},
          {:kind=>:move,:move_id=>414,:target=>2},
          {:kind=>:move,:move_id=>33,:target=>4},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          4=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
      {
        :name=>"WONDER_GUARD_SUPER_EFFECTIVE_PASS",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>53,:target=>4},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          4=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,140,130,120, 200,180,160,150,0],
      :r2=>[10,210,190,170, 130,120,110,0,150],
      :r3=>[10,210,160,150, 130,120,110,0,140],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","E0:M150","E1:M150","E2:M150","A1:M150","A2:M150","A3:M150","E3:M100"],
      2=>["A0:Guard","A1:M55","A2:M414","A3:M33","E4:M150","E0:M150","E1:M150","E2:M150"],
      3=>["A0:Guard","A1:M53","A2:M150","A3:M150","E4:M150","E0:M150","E1:M150","E2:M150"],
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
      return File.join(project_root,"Pokemon_Ability_B_AutoTest_v2_5_1.log")
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
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_B_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end

    def self.reset_log
      header = "CG POKEMON ABILITY B DEFENSIVE GUARD AUTO REGRESSION v2.5.1\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; state guards + Water Absorb / Levitate / Wonder Guard\r\n" +
        "BASELINE=v2.5.0b Ability Core + Batch A Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_PASS=8 BATCH_B=8 PENDING=357\r\n" +
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
      log("ABILITY_B_TRIGGER ability=" + aid.to_i.to_s + " battler=" + battler_token(battler) +
        " kind=" + label.to_s) if active?
      return true
    rescue
      return false
    end

    def self.note_guard_event(aid,battler,state_id,source)
      note_ability_trigger(aid,battler,:state_guard)
      @guard_events.push([aid.to_i,battler,state_id.to_i,source]) if @guard_events != nil
      log("ABILITY_STATE_GUARD ability=" + aid.to_i.to_s + " battler=" + battler_token(battler) +
        " state=" + state_id.to_i.to_s + " source=" + source.to_s) if active?
      return true
    rescue
      return false
    end

    #--------------------------------------------------------------------------
    # Ability handlers
    #--------------------------------------------------------------------------
    def self.apply_water_absorb(battler,ctx)
      return false if battler == nil || ctx == nil
      user = ctx[:user]
      skill = ctx[:skill]
      return false if user == nil || skill == nil || user.actor? == battler.actor?
      return false unless skill.respond_to?(:cg_pokemon_type_id)
      water_id = ALBERT_CG::POKEMON_COMBAT.type_id(:water)
      return false unless skill.cg_pokemon_type_id.to_i == water_id.to_i
      return false unless skill.base_damage.to_i > 0
      before = battler.hp.to_i
      heal = [battler.maxhp.to_i / 4,1].max
      battler.hp = [before + heal,battler.maxhp.to_i].min
      actual = battler.hp.to_i - before
      ctx[:cancel] = true
      ctx[:hp_damage] = -actual
      log("ABILITY_WATER_ABSORB target=" + battler_token(battler) + " user=" + battler_token(user) +
        " hp=" + before.to_s + "->" + battler.hp.to_i.to_s + " heal=" + actual.to_s) if active?
      note_ability_trigger(ABILITY_WATER_ABSORB,battler,:before_hit)
      return true
    end

    def self.apply_levitate(battler,ctx)
      return false if battler == nil || ctx == nil
      user = ctx[:user]
      skill = ctx[:skill]
      return false if user == nil || skill == nil || user.actor? == battler.actor?
      return false unless skill.respond_to?(:cg_pokemon_type_id)
      ground_id = ALBERT_CG::POKEMON_COMBAT.type_id(:ground)
      return false unless skill.cg_pokemon_type_id.to_i == ground_id.to_i
      return false unless skill.base_damage.to_i > 0
      ctx[:cancel] = true
      ctx[:hp_damage] = 0
      log("ABILITY_LEVITATE target=" + battler_token(battler) + " user=" + battler_token(user) +
        " move=" + ctx[:move_id].to_i.to_s) if active?
      note_ability_trigger(ABILITY_LEVITATE,battler,:before_hit)
      return true
    end

    def self.apply_wonder_guard(battler,ctx)
      return false if battler == nil || ctx == nil
      user = ctx[:user]
      skill = ctx[:skill]
      return false if user == nil || skill == nil || user.actor? == battler.actor?
      return false unless skill.base_damage.to_i > 0
      return false unless skill.respond_to?(:cg_pokemon_type_id)
      type_id = skill.cg_pokemon_type_id.to_i
      return false if type_id <= 0
      return false unless battler.respond_to?(:cg_pokemon_type_rate_percent)
      rate = battler.cg_pokemon_type_rate_percent(type_id).to_i
      return false if rate > 100
      ctx[:cancel] = true
      ctx[:hp_damage] = 0
      log("ABILITY_WONDER_GUARD target=" + battler_token(battler) + " user=" + battler_token(user) +
        " move=" + ctx[:move_id].to_i.to_s + " type_rate=" + rate.to_s) if active?
      note_ability_trigger(ABILITY_WONDER_GUARD,battler,:before_hit)
      return true
    end

    def self.register_handlers
      core = ALBERT_CG::ABILITY_V250
      core.register(ABILITY_WATER_ABSORB,:before_hit,self,:apply_water_absorb)
      core.register(ABILITY_LEVITATE,:before_hit,self,:apply_levitate)
      core.register(ABILITY_WONDER_GUARD,:before_hit,self,:apply_wonder_guard)
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
            ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],
            ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[2]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg,i|
        configure_enemy(cfg)
        m = ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]),xs[i],ys[i])
        m.hidden = (i >= 4)
        members.push(m)
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID,"Pokemon Ability B v2.5.1 AutoRegression",members)
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

    def self.attempt_guard_state(battler,state_id,label)
      return if battler == nil
      before = battler.state?(state_id)
      battler.add_state(state_id)
      after = battler.state?(state_id)
      @state_probe_results[label] = (!before && !after)
    rescue
      @state_probe_results[label] = false
    end

    def self.prepare_round_preconditions
      a = test_allies
      e = all_enemies
      if current_round == 1
        attempt_guard_state(a[1],ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS,:limber)
        attempt_guard_state(a[2],ALBERT_CG::MOVE_EFFECT::STATE_SLEEP,:insomnia)
        attempt_guard_state(a[3],ALBERT_CG::MOVE_EFFECT::STATE_POISON,:immunity_poison)
        if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON)
          attempt_guard_state(a[3],ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON,:immunity_bad_poison)
        end
        attempt_guard_state(e[0],ALBERT_CG::MOVE_EFFECT::STATE_BURN,:water_veil)
        attempt_guard_state(e[3],ALBERT_CG::MOVE_EFFECT::STATE_FREEZE,:magma_armor)
      elsif current_round == 2
        e[1].hp = [e[1].maxhp.to_i - 60,1].max
        @r2_water_before = e[1].hp.to_i
        @r2_water_expected_heal = [e[1].maxhp.to_i / 4,1].max
        @r2_levitate_before = e[2].hp.to_i
        @r2_wonder_before = e[4].hp.to_i
      elsif current_round == 3
        @r3_wonder_before = e[4].hp.to_i
        fire_id = ALBERT_CG::POKEMON_COMBAT.type_id(:fire)
        @r3_wonder_fire_rate = e[4].cg_pokemon_type_rate_percent(fire_id).to_i
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
        token += ":Other"
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
      assert_true("Ability Catalog count=373",ALBERT_CG::ABILITY_V250.catalog_count.to_i == 373,
        "actual=" + ALBERT_CG::ABILITY_V250.catalog_count.to_i.to_s)
      assert_true("Ability Batch A remains registered 8 IDs",
        ALBERT_CG::ABILITY_A_V250::HANDLED_ABILITY_IDS.size == 8)
      assert_true("Ability Batch B registers 8 IDs",HANDLED_ABILITY_IDS.size == 8)
      assert_true("Scene_Battle uses Ability B test troop",$game_troop.troop.id.to_i == TEST_TROOP_ID,
        "actual=" + $game_troop.troop.id.to_i.to_s)
      assert_true("Ability B ally count=4",a.size == 4,"actual=" + a.size.to_s)
      assert_true("Ability B starts with 4 active enemies",e.select{|b| b != nil && !b.hidden}.size == 4)
      assert_true("Ability B starts with 1 hidden Wonder Guard reserve",e.select{|b| b != nil && b.hidden}.size == 1)
    end

    def self.assert_round
      r = current_round
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      a = test_allies
      e = all_enemies
      if r == 1
        checks = [
          [:limber,"Limber blocks Paralysis"],
          [:insomnia,"Insomnia blocks Sleep"],
          [:immunity_poison,"Immunity blocks Poison"],
          [:immunity_bad_poison,"Immunity blocks Bad Poison"],
          [:water_veil,"Water Veil blocks Burn"],
          [:magma_armor,"Magma Armor blocks Freeze"],
        ]
        checks.each do |pair|
          next if pair[0] == :immunity_bad_poison && !ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON)
          ok = @state_probe_results[pair[0]] == true
          @guard_checks += 1 if ok
          assert_true(pair[1],ok)
        end
        switch_ok = e[3].hidden && !e[4].hidden
        @guard_checks += 1 if switch_ok
        assert_true("Teleport deploys hidden Wonder Guard reserve",switch_ok)
      elsif r == 2
        water_expected = [@r2_water_before.to_i + @r2_water_expected_heal.to_i,e[1].maxhp.to_i].min
        water_ok = e[1].hp.to_i == water_expected
        @immunity_checks += 1 if water_ok
        assert_true("Water Absorb cancels Water damage and heals 1/4 MaxHP",water_ok,
          "hp=" + @r2_water_before.to_s + "->" + e[1].hp.to_i.to_s + " expected=" + water_expected.to_s)
        levitate_ok = e[2].hp.to_i == @r2_levitate_before.to_i
        @immunity_checks += 1 if levitate_ok
        assert_true("Levitate cancels Ground damaging Move",levitate_ok,
          "hp=" + @r2_levitate_before.to_s + "->" + e[2].hp.to_i.to_s)
        wonder_ok = e[4].hp.to_i == @r2_wonder_before.to_i
        @immunity_checks += 1 if wonder_ok
        assert_true("Wonder Guard blocks neutral Tackle",wonder_ok,
          "hp=" + @r2_wonder_before.to_s + "->" + e[4].hp.to_i.to_s)
      elsif r == 3
        rate_ok = @r3_wonder_fire_rate.to_i > 100
        @immunity_checks += 1 if rate_ok
        assert_true("Wonder Guard regression Fire Move is super-effective",rate_ok,
          "type_rate=" + @r3_wonder_fire_rate.to_i.to_s)
        damage_ok = e[4].hp.to_i < @r3_wonder_before.to_i
        @immunity_checks += 1 if damage_ok
        assert_true("Wonder Guard allows super-effective Flamethrower damage",damage_ok,
          "hp=" + @r3_wonder_before.to_s + "->" + e[4].hp.to_i.to_s)
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
        " ability_b=" + ability_covered_count.to_s + "/8" +
        " guard_checks=" + @guard_checks.to_i.to_s +
        " immunity_checks=" + @immunity_checks.to_i.to_s + " pending=357")
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
      @guard_events = []
      @guard_checks = 0
      @immunity_checks = 0
      @state_probe_results = {}
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
        ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_B_v2.5.1")
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
# ■ Register Batch B into Ability Core
#==============================================================================
ALBERT_CG::ABILITY_B_V251.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Batch A Regression observer：非 Batch A active 時不得污染最新 LOG
#==============================================================================
if defined?(ALBERT_CG::ABILITY_A_V250)
  module ALBERT_CG
    module ABILITY_A_V250
      class << self
        alias cg_v251b_note_trigger_event_guard note_trigger_event
        def note_trigger_event(event)
          return unless active?
          return cg_v251b_note_trigger_event_guard(event)
        end
      end
      def self.f11_trigger?; return false; end
    end
  end
end

#==============================================================================
# ■ Regression deterministic hit/evasion
#==============================================================================
class Game_Battler
  alias cg_v251b_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    return 100 if defined?(ALBERT_CG::ABILITY_B_V251) && ALBERT_CG::ABILITY_B_V251.active?
    return cg_v251b_ability_calc_hit(user,obj)
  end

  alias cg_v251b_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_B_V251) && ALBERT_CG::ABILITY_B_V251.active?
    return cg_v251b_ability_calc_eva(user,obj)
  end

  alias cg_v251b_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_B_V251) && ALBERT_CG::ABILITY_B_V251.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v251b_ability_priority_base_speed
  rescue
    return cg_v251b_ability_priority_base_speed
  end
end

#==============================================================================
# ■ Game_Enemy deterministic action
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v251b_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_B_V251) && ALBERT_CG::ABILITY_B_V251.active?
      action = ALBERT_CG::ABILITY_B_V251.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v251b_ability_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle Regression control
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v251b_ability_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::ABILITY_B_V251.record_execution(battler) if defined?(ALBERT_CG::ABILITY_B_V251) && ALBERT_CG::ABILITY_B_V251.active?
    return cg_v251b_ability_execute_action
  end

  alias cg_v251b_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_B_V251) && ALBERT_CG::ABILITY_B_V251.active?
      ALBERT_CG::ABILITY_B_V251.finish_round_assertions
    end
    return cg_v251b_ability_turn_end
  end

  alias cg_v251b_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_B_V251) && ALBERT_CG::ABILITY_B_V251.active?
      return cg_v251b_ability_start_party_command
    end
    cg_v251b_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_B_V251.assert_bootstrap_once
    if ALBERT_CG::ABILITY_B_V251.finished?
      ALBERT_CG::ABILITY_B_V251.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_B_V251.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle rebuild 後重套 Ability B test data
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v251b_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v251b_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_B_V251) && ALBERT_CG::ABILITY_B_V251.active?
        for cfg in ALBERT_CG::ABILITY_B_V251::TEST_ALLIES
          ALBERT_CG::ABILITY_B_V251.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_B_V251::TEST_LEVEL,false)
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
# ■ F11：v2.5.1 Ability Batch B 成為唯一最新版 AutoRegression
#==============================================================================
class Scene_Map < Scene_Base
  alias cg_v251b_ability_scene_map_update update
  def update
    cg_v251b_ability_scene_map_update
    if !$game_temp.in_battle && !ALBERT_CG::ABILITY_B_V251.active? &&
       ALBERT_CG::ABILITY_B_V251.f11_trigger?
      Sound.play_decision
      ALBERT_CG::ABILITY_B_V251.start_auto_test
    end
  end
end
