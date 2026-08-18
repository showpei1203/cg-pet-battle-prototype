# RMVX_SCRIPT_INDEX: 213
# RMVX_SCRIPT_ID: 2041447113
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch A v2.5.0b
# RMVX_SOURCE_SHA256: 397962857c94c87554fde54f45e3901da0ff2140158cccfaffa485c47203b0ea

#==============================================================================
# ■ CG Pokemon Ability Batch A v2.5.0b
#------------------------------------------------------------------------------
# 【用途】
#  在 CG Pokemon Ability Runtime Core v2.5.0 上完成第一批 8 個代表性 Ability，
#  同時用真正 Scene_Battle deterministic F11 Regression 驗證 Entry、Before Hit、
#  Before Damage、After Contact、End Turn、Switch-out 六類 Ability lifecycle。
#
# 【本批 Ability】
#    2 Drizzle／降雨        Entry：入場建立 Rain 5 回合。
#    3 Speed Boost／加速    End Turn：每回合末 SPE Stage +1，最多 +6。
#    5 Sturdy／結實         Before Damage：滿 HP 時遭致死直接傷害，保留 1 HP。
#    9 Static／靜電         After Contact：接觸攻擊後 30% 使攻擊者麻痺。
#   10 Volt Absorb／蓄電    Before Hit：Electric damaging Move 無效並回復 1/4 MaxHP。
#   22 Intimidate／威嚇     Entry：對方所有存活 battler ATK Stage -1。
#   24 Rough Skin／粗糙皮膚 After Contact：接觸攻擊者損失 1/8 MaxHP。
#   30 Natural Cure／自然回復 Switch-out：換出時解除主要異常。
#
# 【設定】
#  TEST_TROOP_ID = 703。
#  TEST_LEVEL = 40。
#  STATIC_PROC_PERCENT = 30；正式戰鬥使用 rand(100)，F11 測試固定觸發。
#  TEST_ALLIES：Static Pikachu、Volt Absorb Jolteon、Speed Boost Blaziken。
#  TEST_ENEMIES：Intimidate Gyarados、Drizzle Pelipper、Sturdy Geodude、
#                Natural Cure Starmie、hidden Rough Skin Carvanha。
#
# 【機制規則】
#  1. 全部 Ability 都只透過 ABILITY_V250.register 註冊，不新增第二套 Ability ID。
#  2. 有效 Ability 仍以 cg_master_ability_id 為權威，因此 Transform / Role Play /
#     Skill Swap / Gastro Acid 等 Battle-only Identity Runtime 可直接作用。
#  3. Static 的 30% RNG 在正式玩家戰鬥保留；只有本 F11 active 時固定觸發，避免
#     deterministic regression 變成抽卡。
#  4. Sturdy 的 F11 使用 test-only lethal damage isolation：只在 Round1、Geodude、
#     指定 Tackle 真正進入 execute_damage 時把 incoming damage 固定成致死值；正式傷害
#     公式完全不改。
#  5. Natural Cure 由 ForceSwitch.clear_switch_out_volatile 的共用 switch-out authority
#     觸發；hidden reserve cleanup 不觸發。
#  6. Rough Skin / Static 依現行 contact_action? 判定；日後 MasterData 補齊 contact flag
#     時只需更新共用 contact authority，不用改兩個 Ability。
#
# 【v2.5.0a Regression expectation 修正】
#  v2.5.0 實機證明 Teleport／瞬間移動保留 Master priority=-6，因此不可能靠 SPE
#  override 在同一回合先於一般 Priority 0 的 Tackle 換入 hidden reserve。舊 Round2
#  expectation 要求 Starmie 先 Teleport、Pikachu 再打新換入 Carvanha，與正式 Priority
#  Authority 衝突，造成 Rough Skin 假 FAIL。v2.5.0a 不修改 Teleport／Rough Skin Runtime：
#    - Round2 只驗 Natural Cure + Teleport，並明確期待 Teleport 最後行動。
#    - Round3 reserve 已在場，再由 Pikachu Tackle Carvanha 驗 Rough Skin；同回合仍驗
#      Volt Absorb + Speed Boost。
#  並加入 Teleport Master priority=-6 前置 ASSERT，避免未來 regression 再寫出不可能順序。
#
# 【v2.5.0b RGSS2 / 測試便利修正】
#  v2.5.0a 在 bootstrap ASSERT 誤呼叫不存在的 ACTION_PRIORITY.priority_for_move，
#  RPG Maker VX / RGSS2 實機因此於行號附近 NoMethodError。v2.5.0b 改為直接讀
#  Pokemon Master Move row[6] 作為 Teleport priority 權威，不修改正式 Priority Runtime。
#  同時接入 TEST_CONVENIENCE：僅 F11 測試期間略過 emerged 訊息、靜音 Battle BGM/BGS，
#  並可啟動外部 Win32 keepalive helper 嘗試讓 VX 失焦後仍繼續跑。正式版必須關閉／移除。
#
# 【F11 deterministic Regression】
#  Battle Start：
#    - Intimidate 實際降低我方 Human + 3 Pokémon ATK。
#    - Drizzle 建立 Rain。
#  Round1：
#    - Gyarados Tackle Pikachu -> Static 麻痺攻擊者。
#    - Jolteon Tackle Sturdy Geodude -> test-only lethal -> Geodude 留 1 HP。
#    - End Turn -> Blaziken Speed Boost SPE +1。
#  Round2：
#    - Starmie 先帶 Poison，依 Teleport Master priority=-6 於本回合最後使用 Teleport。
#    - Natural Cure 在真實 switch-out 清除 Poison，hidden Carvanha 換入。
#    - End Turn -> Speed Boost SPE +2。
#  Round3：
#    - Pikachu Tackle 已在場 Carvanha -> Rough Skin 反傷 1/8 MaxHP。
#    - Pelipper Thunderbolt Jolteon -> Volt Absorb 0 damage + 1/4 MaxHP heal。
#    - End Turn -> Speed Boost SPE +3。
#
# 【腳本／事件呼叫方式】
#  地圖 F11：ALBERT_CG::ABILITY_A_V250.start_auto_test
#  事件 Script 也可直接呼叫同方法。
#
# 【成功標準】
#  RESULT=PASS
#  SUMMARY rounds=3 failures=0 ability_a=8/8 trigger_checks=... lifecycle_checks=... pending=365
#
# 【重要】
#  未取得使用者 RPG Maker VX 實機 LOG 前，本版只能稱 TEST BUILD，不能宣稱 Runtime PASS。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchA"] = "2.5.0b"

module ALBERT_CG
  module ABILITY_A_V250
    VERSION = "2.5.0b"

    ABILITY_DRIZZLE = 2
    ABILITY_SPEED_BOOST = 3
    ABILITY_STURDY = 5
    ABILITY_STATIC = 9
    ABILITY_VOLT_ABSORB = 10
    ABILITY_INTIMIDATE = 22
    ABILITY_ROUGH_SKIN = 24
    ABILITY_NATURAL_CURE = 30

    HANDLED_ABILITY_IDS = [
      ABILITY_DRIZZLE,ABILITY_SPEED_BOOST,ABILITY_STURDY,ABILITY_STATIC,
      ABILITY_VOLT_ABSORB,ABILITY_INTIMIDATE,ABILITY_ROUGH_SKIN,ABILITY_NATURAL_CURE
    ]

    TEST_TROOP_ID = 703
    TEST_LEVEL = 40
    VK_F11 = 0x7A
    STATIC_PROC_PERCENT = 30

    TEST_ALLIES = [
      {:dex=>25, :level=>40, :ability=>ABILITY_STATIC,      :moves=>[33,150,150,150]},
      {:dex=>135,:level=>40, :ability=>ABILITY_VOLT_ABSORB,:moves=>[33,150,150,150]},
      {:dex=>257,:level=>40, :ability=>ABILITY_SPEED_BOOST,:moves=>[150,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>130,:level=>40,:ability=>ABILITY_INTIMIDATE,  :moves=>[33,150,150,150]},
      {:dex=>279,:level=>40,:ability=>ABILITY_DRIZZLE,     :moves=>[85,150,150,150]},
      {:dex=>74, :level=>40,:ability=>ABILITY_STURDY,      :moves=>[150,150,150,150]},
      {:dex=>121,:level=>40,:ability=>ABILITY_NATURAL_CURE,:moves=>[100,150,150,150]},
      {:dex=>318,:level=>40,:ability=>ABILITY_ROUGH_SKIN,  :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"STATIC_STURDY_SPEEDBOOST",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>33,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>33,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>0},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
      {
        :name=>"NATURAL_CURE_ROUGH_SKIN",
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
        :name=>"VOLT_ABSORB_SPEEDBOOST",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>4},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>85,:target=>2},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          4=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,130,190,120, 200,170,160,150,0],
      :r2=>[10,180,140,120, 150,130,110,210,0],
      :r3=>[10,130,120,110, 140,200,120,0,150],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","E0:M33","A2:M33","E1:M150","E2:M150","E3:M150","A1:M150","A3:M150"],
      2=>["A0:Guard","A1:M150","E0:M150","A2:M150","E1:M150","A3:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","E1:M85","E4:M150","E0:M150","A1:M33","A2:M150","E2:M150","A3:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.master
      return defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil
    end

    def self.active?
      return @active == true
    end

    def self.current_round
      return @round_index.to_i + 1
    end

    def self.current_plan
      return ROUND_PLANS[@round_index.to_i]
    end

    def self.finished?
      return @round_index.to_i >= ROUND_PLANS.size
    end

    def self.test_allies
      return $game_party == nil ? [] : $game_party.members
    end

    def self.all_enemies
      return $game_troop == nil ? [] : $game_troop.members
    end

    def self.project_root
      return Dir.pwd
    rescue
      return "."
    end

    def self.log_path
      return File.join(project_root,"Pokemon_Ability_A_AutoTest_v2_5_0b.log")
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
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_A_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end

    def self.reset_log
      header = "CG POKEMON ABILITY CORE + BATCH A AUTO REGRESSION v2.5.0b\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; Ability Runtime Authority; deterministic entry/damage/contact/end-turn/switch checks\r\n" +
        "BASELINE=v2.4.5b Full Move Lifecycle 13/13 PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A=8 PENDING=365\r\n" +
        "REGRESSION_FIX=Teleport priority -6 respected; Rough Skin check moved after reserve deployment; priority precheck reads Pokemon Master directly; formal Ability/Move runtime unchanged\r\n" +
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

    def self.note_trigger_event(event)
      @trigger_events = [] if @trigger_events == nil
      @trigger_events.push(event)
      aid = event[:ability_id].to_i
      @ability_trigger_counts[aid] = @ability_trigger_counts[aid].to_i + 1 if @ability_trigger_counts != nil
      log("ABILITY_EVENT trigger=" + event[:trigger].to_s + " ability=" + aid.to_s +
        " battler=" + (event[:battler] == nil ? "nil" : event[:battler].name.to_s))
    rescue
    end

    def self.note_trigger_check(ok)
      @trigger_checks += 1 if ok
    end

    def self.note_lifecycle_check(ok)
      @lifecycle_checks += 1 if ok
    end

    def self.battler_token(b)
      return "nil" if b == nil
      return (b.actor? ? "A" : "E") + b.index.to_i.to_s
    rescue
      return "?"
    end

    def self.proc_roll(ability_id,percent)
      return true if active?
      return rand(100) < percent.to_i
    rescue
      return false
    end

    def self.add_state_record(battler,state_id)
      return false if battler == nil || state_id.to_i <= 0
      if battler.respond_to?(:cg_v231_add_state_record)
        battler.cg_v231_add_state_record(state_id.to_i)
      else
        battler.add_state(state_id.to_i)
      end
      return battler.state?(state_id.to_i)
    rescue
      return false
    end

    #--------------------------------------------------------------------------
    # Ability handlers
    #--------------------------------------------------------------------------
    def self.apply_drizzle(battler,ctx)
      return false unless defined?(ALBERT_CG::FIELD_V233)
      st = ALBERT_CG::FIELD_V233.state
      st.weather = :rain
      st.weather_turns = ALBERT_CG::ABILITY_V250::ENTRY_WEATHER_TURNS
      log("ABILITY_DRIZZLE user=" + battler_token(battler) + " weather=rain turns=" + st.weather_turns.to_i.to_s) if active?
      ALBERT_CG::ABILITY_V250.notify_weather_changed(battler)
      return true
    end

    def self.apply_speed_boost(battler,ctx)
      return false if battler == nil || !battler.respond_to?(:cg_stat_stage)
      before = battler.cg_stat_stage(:spe).to_i
      return false if before >= 6
      battler.cg_change_stat_stage(:spe,1)
      after = battler.cg_stat_stage(:spe).to_i
      log("ABILITY_SPEED_BOOST user=" + battler_token(battler) + " spe=" + before.to_s + "->" + after.to_s) if active?
      return after > before
    end

    def self.apply_sturdy(battler,ctx)
      return false if battler == nil || ctx == nil
      damage = ctx[:damage].to_i
      return false if damage <= 0
      return false unless battler.hp.to_i == battler.maxhp.to_i
      return false if battler.respond_to?(:cg_v234_substitute_active?) && battler.cg_v234_substitute_active?
      return false if damage < battler.hp.to_i
      ctx[:damage] = [battler.hp.to_i - 1,0].max
      log("ABILITY_STURDY target=" + battler_token(battler) + " incoming=" + damage.to_s +
        " final=" + ctx[:damage].to_i.to_s) if active?
      return true
    end

    def self.apply_static(battler,ctx)
      return false if battler == nil || ctx == nil
      attacker = ctx[:user]
      return false if attacker == nil || attacker.actor? == battler.actor? || attacker.hp.to_i <= 0
      return false unless ctx[:contact] == true
      return false unless proc_roll(ABILITY_STATIC,STATIC_PROC_PERCENT)
      return false unless defined?(ALBERT_CG::MOVE_EFFECT)
      return false unless ALBERT_CG::MOVE_EFFECT.can_apply_ailment?(attacker,1)
      ok = add_state_record(attacker,ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS)
      log("ABILITY_STATIC target=" + battler_token(battler) + " attacker=" + battler_token(attacker) +
        " paralyzed=" + ok.to_s) if active?
      return ok
    end

    def self.apply_volt_absorb(battler,ctx)
      return false if battler == nil || ctx == nil
      user = ctx[:user]
      skill = ctx[:skill]
      return false if user == nil || skill == nil || user.actor? == battler.actor?
      return false unless skill.respond_to?(:cg_pokemon_type_id)
      electric_id = ALBERT_CG::POKEMON_COMBAT.type_id(:electric)
      return false unless skill.cg_pokemon_type_id.to_i == electric_id.to_i
      return false unless skill.base_damage.to_i > 0
      before = battler.hp.to_i
      heal = [battler.maxhp.to_i / 4,1].max
      battler.hp = [before + heal,battler.maxhp.to_i].min
      actual = battler.hp.to_i - before
      ctx[:cancel] = true
      ctx[:hp_damage] = -actual
      log("ABILITY_VOLT_ABSORB target=" + battler_token(battler) + " user=" + battler_token(user) +
        " hp=" + before.to_s + "->" + battler.hp.to_i.to_s + " heal=" + actual.to_s) if active?
      return true
    end

    def self.apply_intimidate(battler,ctx)
      return false if battler == nil
      changed = 0
      for target in ALBERT_CG::ABILITY_V250.opponents_of(battler)
        next unless target.respond_to?(:cg_stat_stage) && target.respond_to?(:cg_change_stat_stage)
        before = target.cg_stat_stage(:atk).to_i
        target.cg_change_stat_stage(:atk,-1)
        after = target.cg_stat_stage(:atk).to_i
        changed += 1 if after < before
      end
      log("ABILITY_INTIMIDATE user=" + battler_token(battler) + " lowered=" + changed.to_s) if active?
      return changed > 0
    end

    def self.apply_rough_skin(battler,ctx)
      return false if battler == nil || ctx == nil
      attacker = ctx[:user]
      return false if attacker == nil || attacker.actor? == battler.actor? || attacker.hp.to_i <= 0
      return false unless ctx[:contact] == true
      damage = [attacker.maxhp.to_i / 8,1].max
      before = attacker.hp.to_i
      attacker.hp = [before - damage,0].max
      attacker.hp_damage = before - attacker.hp.to_i if attacker.respond_to?(:hp_damage=)
      log("ABILITY_ROUGH_SKIN target=" + battler_token(battler) + " attacker=" + battler_token(attacker) +
        " hp=" + before.to_s + "->" + attacker.hp.to_i.to_s) if active?
      return attacker.hp.to_i < before
    end

    def self.apply_natural_cure(battler,ctx)
      return false if battler == nil || !defined?(ALBERT_CG::MOVE_EFFECT)
      removed = []
      for sid in ALBERT_CG::MOVE_EFFECT::PRIMARY_STATES
        if battler.state?(sid)
          battler.remove_state(sid)
          removed.push(sid)
        end
      end
      log("ABILITY_NATURAL_CURE user=" + battler_token(battler) + " removed=" + removed.inspect) if active? && !removed.empty?
      return !removed.empty?
    end

    def self.register_handlers
      core = ALBERT_CG::ABILITY_V250
      core.register(ABILITY_DRIZZLE,:entry,self,:apply_drizzle)
      core.register(ABILITY_SPEED_BOOST,:end_turn,self,:apply_speed_boost)
      core.register(ABILITY_STURDY,:before_damage,self,:apply_sturdy)
      core.register(ABILITY_STATIC,:after_contact,self,:apply_static)
      core.register(ABILITY_VOLT_ABSORB,:before_hit,self,:apply_volt_absorb)
      core.register(ABILITY_INTIMIDATE,:entry,self,:apply_intimidate)
      core.register(ABILITY_ROUGH_SKIN,:after_contact,self,:apply_rough_skin)
      core.register(ABILITY_NATURAL_CURE,:switch_out,self,:apply_natural_cure)
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
        TEST_TROOP_ID,"Pokemon Ability A v2.5.0a AutoRegression",members)
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

    def self.prepare_round_preconditions
      a = test_allies
      e = all_enemies
      if current_round == 1
        @r1_static_attacker = e[0]
        @r1_sturdy_target = e[2]
      elsif current_round == 2
        if defined?(ALBERT_CG::MOVE_EFFECT)
          e[3].add_state(ALBERT_CG::MOVE_EFFECT::STATE_POISON)
        end
        @r2_natural_cure_user = e[3]
      elsif current_round == 3
        @r3_rough_attacker = a[1]
        @r3_rough_hp_before = a[1].hp.to_i
        @r3_rough_expected = [a[1].maxhp.to_i / 8,1].max
        a[2].hp = [a[2].maxhp.to_i - 60,1].max
        @r3_volt_target = a[2]
        @r3_volt_hp_before = a[2].hp.to_i
        @r3_volt_expected = [a[2].maxhp.to_i / 4,1].max
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
    end

    def self.assert_bootstrap_once
      return if @boot_asserted == true
      @boot_asserted = true
      a = test_allies
      e = all_enemies
      assert_true("Ability Catalog count=373",ALBERT_CG::ABILITY_V250.catalog_count.to_i == 373,
        "actual=" + ALBERT_CG::ABILITY_V250.catalog_count.to_i.to_s)
      assert_true("Ability Batch A registers 8 IDs",ALBERT_CG::ABILITY_V250.registered_ability_ids.select { |x| HANDLED_ABILITY_IDS.include?(x) }.size == 8)
      assert_true("Scene_Battle uses Ability A test troop",$game_troop.troop != nil && $game_troop.troop.id.to_i == TEST_TROOP_ID,
        "actual=" + ($game_troop.troop == nil ? "nil" : $game_troop.troop.id.to_i.to_s))
      assert_true("Ability A ally count=4",a.size == 4,"actual=" + a.size.to_s)
      active = e.select { |b| b != nil && !b.hidden && b.hp.to_i > 0 }
      hidden = e.select { |b| b != nil && b.hidden && b.hp.to_i > 0 }
      assert_true("Ability A starts with 4 active enemies",active.size == 4,"actual=" + active.size.to_s)
      assert_true("Ability A starts with 1 hidden reserve",hidden.size == 1,"actual=" + hidden.size.to_s)

      atk_ok = true
      for b in a
        atk_ok = false if b.respond_to?(:cg_stat_stage) && b.cg_stat_stage(:atk).to_i != -1
      end
      note_trigger_check(atk_ok); assert_true("Intimidate Entry lowers all 4 opposing battlers ATK -1",atk_ok,
        "stages=" + a.collect { |b| b.respond_to?(:cg_stat_stage) ? b.cg_stat_stage(:atk).to_i : nil }.inspect)
      st = defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233.state : nil
      rain_ok = st != nil && st.weather == :rain && st.weather_turns.to_i == 5
      note_trigger_check(rain_ok); assert_true("Drizzle Entry establishes Rain 5 turns",rain_ok,
        "weather=" + (st == nil ? "nil" : st.weather.to_s) + " turns=" + (st == nil ? "nil" : st.weather_turns.to_i.to_s))
      teleport_row = master == nil ? nil : master.move(100)
      teleport_priority = teleport_row == nil ? nil : teleport_row[6].to_i
      assert_true("Teleport keeps Master priority -6 for regression ordering",teleport_priority == -6,
        "actual=" + (teleport_priority == nil ? "nil" : teleport_priority.to_s))
    end

    def self.assert_round
      r = current_round
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      a = test_allies
      e = all_enemies
      if r == 1
        static_ok = e[0].state?(ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS)
        note_trigger_check(static_ok); assert_true("Static contact proc paralyzes attacker",static_ok)
        sturdy_ok = e[2].hp.to_i == 1
        note_trigger_check(sturdy_ok); assert_true("Sturdy keeps full-HP target at 1 HP after lethal hit",sturdy_ok,
          "hp=" + e[2].hp.to_i.to_s)
        speed_ok = a[3].cg_stat_stage(:spe).to_i == 1
        note_trigger_check(speed_ok); assert_true("Speed Boost first end-turn tick raises SPE +1",speed_ok,
          "spe=" + a[3].cg_stat_stage(:spe).to_i.to_s)
      elsif r == 2
        cure_ok = e[3].hidden && !e[3].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON)
        note_lifecycle_check(cure_ok); assert_true("Natural Cure clears primary status on real Teleport switch-out",cure_ok)
        incoming_ok = !e[4].hidden
        note_lifecycle_check(incoming_ok); assert_true("Teleport deploys hidden Rough Skin reserve",incoming_ok)
        speed_ok = a[3].cg_stat_stage(:spe).to_i == 2
        note_trigger_check(speed_ok); assert_true("Speed Boost second end-turn tick raises SPE +2",speed_ok,
          "spe=" + a[3].cg_stat_stage(:spe).to_i.to_s)
      elsif r == 3
        rough_expected_hp = [@r3_rough_hp_before.to_i - @r3_rough_expected.to_i,0].max
        rough_ok = a[1].hp.to_i == rough_expected_hp
        note_trigger_check(rough_ok); assert_true("Rough Skin contact recoil damages attacker 1/8 MaxHP",rough_ok,
          "hp=" + @r3_rough_hp_before.to_s + "->" + a[1].hp.to_i.to_s + " expected=" + rough_expected_hp.to_s)
        expected_hp = [@r3_volt_hp_before.to_i + @r3_volt_expected.to_i,a[2].maxhp.to_i].min
        volt_ok = a[2].hp.to_i == expected_hp
        note_trigger_check(volt_ok); assert_true("Volt Absorb cancels Electric damage and heals 1/4 MaxHP",volt_ok,
          "hp=" + @r3_volt_hp_before.to_s + "->" + a[2].hp.to_i.to_s + " expected=" + expected_hp.to_s)
        speed_ok = a[3].cg_stat_stage(:spe).to_i == 3
        note_trigger_check(speed_ok); assert_true("Speed Boost third end-turn tick raises SPE +3",speed_ok,
          "spe=" + a[3].cg_stat_stage(:spe).to_i.to_s)
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
        " ability_a=" + ability_covered_count.to_s + "/8" +
        " trigger_checks=" + @trigger_checks.to_i.to_s +
        " lifecycle_checks=" + @lifecycle_checks.to_i.to_s + " pending=365")
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
      @trigger_events = []
      @ability_trigger_counts = {}
      @trigger_checks = 0
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
        ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_A_v2.5.0b")
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
# ■ Register Batch A into Ability Core
#==============================================================================
ALBERT_CG::ABILITY_A_V250.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Regression deterministic hit/evasion + Sturdy lethal isolation
#==============================================================================
class Game_Battler
  alias cg_v250a_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    return 100 if defined?(ALBERT_CG::ABILITY_A_V250) && ALBERT_CG::ABILITY_A_V250.active?
    return cg_v250a_ability_calc_hit(user,obj)
  end

  alias cg_v250a_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_A_V250) && ALBERT_CG::ABILITY_A_V250.active?
    return cg_v250a_ability_calc_eva(user,obj)
  end

  alias cg_v250a_sturdy_test_execute_damage execute_damage
  def execute_damage(user)
    if defined?(ALBERT_CG::ABILITY_A_V250) && ALBERT_CG::ABILITY_A_V250.active? &&
       ALBERT_CG::ABILITY_A_V250.current_round == 1 && !actor? && index.to_i == 2 &&
       ALBERT_CG::ABILITY_V250.current_move_id(user).to_i == 33 && @hp_damage.to_i > 0
      @hp_damage = hp.to_i + 50
      ALBERT_CG::ABILITY_A_V250.log("ABILITY_STURDY_TEST_FORCE target=" + name.to_s +
        " forced_damage=" + @hp_damage.to_i.to_s)
    end
    return cg_v250a_sturdy_test_execute_damage(user)
  end
end

#==============================================================================
# ■ deterministic SPE bridge
#==============================================================================
class Game_Battler
  alias cg_v250a_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_A_V250) && ALBERT_CG::ABILITY_A_V250.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v250a_ability_priority_base_speed
  rescue
    return cg_v250a_ability_priority_base_speed
  end
end

#==============================================================================
# ■ Game_Enemy deterministic action
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v250a_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_A_V250) && ALBERT_CG::ABILITY_A_V250.active?
      action = ALBERT_CG::ABILITY_A_V250.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v250a_ability_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle Regression control
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v250a_ability_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::ABILITY_A_V250.record_execution(battler) if defined?(ALBERT_CG::ABILITY_A_V250) && ALBERT_CG::ABILITY_A_V250.active?
    return cg_v250a_ability_execute_action
  end

  alias cg_v250a_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_A_V250) && ALBERT_CG::ABILITY_A_V250.active?
      # Batch A assertions 必須看到本回合 Speed Boost 已完成；先手動執行一次，
      # 再要求 Ability Core 內層 turn_end wrapper 跳過重複觸發。
      ALBERT_CG::ABILITY_V250.trigger_end_turn
      ALBERT_CG::ABILITY_A_V250.finish_round_assertions
      ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
    end
    return cg_v250a_ability_turn_end
  end

  alias cg_v250a_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_A_V250) && ALBERT_CG::ABILITY_A_V250.active?
      return cg_v250a_ability_start_party_command
    end
    cg_v250a_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_A_V250.assert_bootstrap_once
    if ALBERT_CG::ABILITY_A_V250.finished?
      ALBERT_CG::ABILITY_A_V250.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_A_V250.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle rebuild 後重套 Ability A test data
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v250a_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v250a_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_A_V250) && ALBERT_CG::ABILITY_A_V250.active?
        for cfg in ALBERT_CG::ABILITY_A_V250::TEST_ALLIES
          ALBERT_CG::ABILITY_A_V250.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_A_V250::TEST_LEVEL,false)
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
# ■ F11：v2.5.0b Ability Batch A 成為唯一最新版 AutoRegression
#==============================================================================
if defined?(ALBERT_CG::FULL_MOVE_LIFECYCLE_V245)
  module ALBERT_CG
    module FULL_MOVE_LIFECYCLE_V245
      def self.f11_trigger?; return false; end
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v250a_ability_scene_map_update update
  def update
    cg_v250a_ability_scene_map_update
    if !$game_temp.in_battle && !ALBERT_CG::ABILITY_A_V250.active? &&
       ALBERT_CG::ABILITY_A_V250.f11_trigger?
      Sound.play_decision
      ALBERT_CG::ABILITY_A_V250.start_auto_test
    end
  end
end
