# RMVX_SCRIPT_INDEX: 223
# RMVX_SCRIPT_ID: 255000002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch F v2.5.5a
# RMVX_SOURCE_SHA256: d4cd927f6bf7983bbc5b0cbed46e70418bd1a165c1db26f8e2a4806181dfe32e

#==============================================================================
# ■ CG Pokemon Ability Batch F v2.5.5a - Status Interaction End-turn Order Fix
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.4 Ability Batch E PASS 基底上，正式實作第六批 8 個狀態互動 Ability，
#  並提供 Actual Scene_Battle deterministic F11 regression。此批同時驗證 v2.5.5
#  Status Interaction Authority 的 Guard extension、Synchronize 與 Intimidate immunity。
#
# 【v2.5.5a 修正】
#  v2.5.5 實機證明 Shed Skin 正式 end_turn Runtime 已正確解除 Burn，但舊 Regression
#  在 Scene_Battle#turn_end 進入 Ability Core 之前就先 ASSERT，造成「ASSERT FAIL 後才
#  ABILITY_SHED_SKIN removed=43」的假失敗。v2.5.5a 僅修測試生命週期順序：
#  Regression active 時先手動觸發 Ability Core end_turn，再做 round ASSERT，最後以
#  suppress_next_end_turn! 阻止內層 turn_end 重複觸發。正式 Ability Runtime 完全不變。
#
# 【本批 Ability】
#   20  Own Tempo    我行我素：免疫 Confusion；依現代規則免疫 Intimidate。
#   27  Effect Spore 孢子：受接觸攻擊後 30% 對攻擊者造成 Poison/Paralysis/Sleep 之一。
#   28  Synchronize  同步：被對手造成 Poison/Paralysis/Burn 時反射同狀態。
#   38  Poison Point 毒刺：受接觸攻擊後 30% 使攻擊者 Poison。
#   39  Inner Focus  精神力：免疫 Flinch；依現代規則免疫 Intimidate。
#   49  Flame Body   火焰之軀：受接觸攻擊後 30% 使攻擊者 Burn。
#   61  Shed Skin    蛻皮：回合末 1/3 機率解除主要異常狀態。
#   72  Vital Spirit 幹勁：免疫 Sleep。
#
# 【主要設定項】
#  CONTACT_PROC_PERCENT=30 / SHED_SKIN_DENOM=3（精確 1/3）。
#  TEST_TROOP_ID=708：F11 deterministic Scene_Battle 專用 troop。
#
# 【機制規則】
#  1. Effect Spore / Poison Point / Flame Body 走 Ability Core :after_contact，只有敵我接觸
#     傷害成功走到 contact lifecycle 才有機會發動。
#  2. Effect Spore 正式戰鬥隨機選 Poison/Paralysis/Sleep；Regression 固定選 Poison，
#     並尊重 Grass / Overcoat / Safety Goggles 粉末免疫與 Type ailment immunity。
#  3. Synchronize 與 Guard/Intimidate immunity 由 Status Interaction Authority 處理，
#     Batch F 只負責正式 trigger 計數與 deterministic ASSERT，不另造第二套狀態權威。
#  4. Shed Skin 正式戰鬥維持 1/3 RNG；Regression active 時固定觸發，以免回歸測試靠運氣。
#  5. 所有 Ability 一律讀 cg_master_ability_id，尊重 Ability override/suppression。
#  6. F11 固定 hit/evasion/SPE；正式玩家戰鬥 RNG、命中與速度完全不變。
#  7. Round2 使用 Teleport 部署 hidden Vital Spirit reserve，並 ASSERT Storage 不被消耗。
#
# 【可調參數】
#  CONTACT_PROC_PERCENT / SHED_SKIN_DENOM / TEST_TROOP_ID / TEST_SPEEDS。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，自動執行三回合並寫入
#  Pokemon_Ability_F_AutoTest_v2_5_5a.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  例 1：Tackle 接觸 Effect Spore -> Regression 固定 Poison 攻擊者；正式戰鬥 30% proc。
#  例 2：Thunder Wave 命中 Synchronize -> 目標麻痺，攻擊者若可被麻痺則同步麻痺。
#  例 3：Shed Skin Pokémon 帶 Burn -> 回合末 Regression 固定解除；正式戰鬥 1/3。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchF"] = "2.5.5a"

module ALBERT_CG
  module ABILITY_F_V255
    VERSION = "2.5.5a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 708
    VK_F11 = 0x7A

    ABILITY_OWN_TEMPO    = 20
    ABILITY_EFFECT_SPORE = 27
    ABILITY_SYNCHRONIZE  = 28
    ABILITY_POISON_POINT = 38
    ABILITY_INNER_FOCUS  = 39
    ABILITY_FLAME_BODY   = 49
    ABILITY_SHED_SKIN    = 61
    ABILITY_VITAL_SPIRIT = 72

    HANDLED_ABILITY_IDS = [20,27,28,38,39,49,61,72]
    CONTACT_PROC_PERCENT = 30
    SHED_SKIN_DENOM = 3

    TEST_ALLIES = [
      {:dex=>196,:level=>40,:ability=>ABILITY_OWN_TEMPO,   :moves=>[33,150,150,150]},
      {:dex=>47, :level=>40,:ability=>ABILITY_EFFECT_SPORE,:moves=>[33,150,150,150]},
      {:dex=>282,:level=>40,:ability=>ABILITY_SYNCHRONIZE, :moves=>[150,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>133,:level=>40,:ability=>ABILITY_POISON_POINT,:moves=>[33,150,150,150]},
      {:dex=>448,:level=>40,:ability=>ABILITY_INNER_FOCUS, :moves=>[150,150,150,150]},
      {:dex=>143,:level=>40,:ability=>ABILITY_FLAME_BODY,  :moves=>[86,150,150,150]},
      {:dex=>24, :level=>40,:ability=>ABILITY_SHED_SKIN,   :moves=>[100,150,150,150]},
      {:dex=>57, :level=>40,:ability=>ABILITY_VITAL_SPIRIT,:moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"EFFECT_SPORE_SYNCHRONIZE_SHED_SKIN",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>33,:target=>2},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>86,:target=>3},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
      {
        :name=>"POISON_POINT_FLAME_BODY_VITAL_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>0},
          {:kind=>:move,:move_id=>33,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>100,:target=>0},
        }
      },
      {
        :name=>"VITAL_SPIRIT_GUARD_STABILITY",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          4=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,210,200,190, 230,180,220,170,0],
      :r2=>[10,230,220,210, 180,170,160,150,0],
      :r3=>[10,230,220,210, 180,170,160,0,150],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","E0:M33","E2:M86","A1:M150","A2:M150","A3:M150","E1:M150","E3:M150"],
      2=>["A0:Guard","A1:M33","A2:M33","A3:M150","E0:M150","E1:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E4:M150"],
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
    def self.project_root; return Dir.pwd; rescue; return "."; end
    def self.log_path; return File.join(project_root,"Pokemon_Ability_F_AutoTest_v2_5_5a.log"); end
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
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_F_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end
    def self.reset_log
      header = "CG POKEMON ABILITY F STATUS INTERACTION AUTO REGRESSION v2.5.5a\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; status guards + contact status + Synchronize + Shed Skin + reserve switch\r\n" +
        "BASELINE=v2.5.4 Ability Batch E Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_B_C_D_E_PASS=40 BATCH_F=8 PENDING=325\r\n" +
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

    def self.note_ability_trigger(aid,battler,kind,ctx=nil)
      @ability_trigger_counts[aid.to_i] = @ability_trigger_counts[aid.to_i].to_i + 1
      log("ABILITY_F_TRIGGER ability=" + aid.to_i.to_s + " battler=" + battler_token(battler) +
        " kind=" + kind.to_s) if active?
      return true
    rescue
      return false
    end
    def self.note_external_trigger(aid,battler,kind,ctx=nil)
      note_ability_trigger(aid,battler,kind,ctx)
      if kind.to_sym == :status_reflect
        @sync_events.push([aid.to_i,battler,ctx]) if @sync_events != nil
      elsif kind.to_sym == :intimidate_guard
        @guard_events.push([aid.to_i,battler,kind,ctx]) if @guard_events != nil
      end
      return true
    rescue
      return false
    end
    def self.note_guard_event(aid,battler,state_id,source)
      note_ability_trigger(aid,battler,:state_guard,{:state_id=>state_id,:source=>source})
      @guard_events.push([aid.to_i,battler,:state_guard,{:state_id=>state_id,:source=>source}]) if @guard_events != nil
      return true
    rescue
      return false
    end

    def self.proc_contact?
      return true if active?
      return rand(100) < CONTACT_PROC_PERCENT
    end
    def self.proc_shed_skin?
      return true if active?
      return rand(SHED_SKIN_DENOM) == 0
    end

    def self.effect_spore_state
      m = ALBERT_CG::MOVE_EFFECT
      return m::STATE_POISON if active?
      list = [m::STATE_POISON,m::STATE_PARALYSIS,m::STATE_SLEEP]
      return list[rand(list.size)]
    rescue
      return 0
    end

    def self.apply_effect_spore(battler,ctx)
      return false if battler == nil || ctx == nil || !proc_contact?
      attacker = ctx[:user]
      return false if attacker == nil || attacker.actor? == battler.actor? || attacker.hp.to_i <= 0
      return false unless ctx[:contact] == true
      return false if ALBERT_CG::ABILITY_STATUS_V255.powder_immune?(attacker)
      sid = effect_spore_state
      return false if sid <= 0
      ok = ALBERT_CG::ABILITY_STATUS_V255.apply_status_from_ability(attacker,sid,battler,:effect_spore)
      if ok
        note_ability_trigger(ABILITY_EFFECT_SPORE,battler,:after_contact,{:attacker=>attacker,:state_id=>sid})
        log("ABILITY_EFFECT_SPORE target=" + battler_token(battler) + " attacker=" + battler_token(attacker) + " state=" + sid.to_s) if active?
      end
      return ok
    end

    def self.apply_poison_point(battler,ctx)
      return false if battler == nil || ctx == nil || !proc_contact?
      attacker = ctx[:user]
      return false if attacker == nil || attacker.actor? == battler.actor? || attacker.hp.to_i <= 0
      return false unless ctx[:contact] == true
      sid = ALBERT_CG::MOVE_EFFECT::STATE_POISON
      ok = ALBERT_CG::ABILITY_STATUS_V255.apply_status_from_ability(attacker,sid,battler,:poison_point)
      if ok
        note_ability_trigger(ABILITY_POISON_POINT,battler,:after_contact,{:attacker=>attacker,:state_id=>sid})
        log("ABILITY_POISON_POINT target=" + battler_token(battler) + " attacker=" + battler_token(attacker)) if active?
      end
      return ok
    end

    def self.apply_flame_body(battler,ctx)
      return false if battler == nil || ctx == nil || !proc_contact?
      attacker = ctx[:user]
      return false if attacker == nil || attacker.actor? == battler.actor? || attacker.hp.to_i <= 0
      return false unless ctx[:contact] == true
      sid = ALBERT_CG::MOVE_EFFECT::STATE_BURN
      ok = ALBERT_CG::ABILITY_STATUS_V255.apply_status_from_ability(attacker,sid,battler,:flame_body)
      if ok
        note_ability_trigger(ABILITY_FLAME_BODY,battler,:after_contact,{:attacker=>attacker,:state_id=>sid})
        log("ABILITY_FLAME_BODY target=" + battler_token(battler) + " attacker=" + battler_token(attacker)) if active?
      end
      return ok
    end

    def self.apply_shed_skin(battler,ctx)
      return false if battler == nil || !proc_shed_skin?
      removed = 0
      for sid in ALBERT_CG::MOVE_EFFECT::PRIMARY_STATES
        if battler.state?(sid)
          battler.remove_state(sid)
          removed = sid
          break
        end
      end
      return false if removed <= 0
      note_ability_trigger(ABILITY_SHED_SKIN,battler,:end_turn,{:state_id=>removed})
      log("ABILITY_SHED_SKIN battler=" + battler_token(battler) + " removed=" + removed.to_s) if active?
      return true
    end

    def self.register_handlers
      return false unless defined?(ALBERT_CG::ABILITY_V250)
      core = ALBERT_CG::ABILITY_V250
      core.register(ABILITY_EFFECT_SPORE,:after_contact,self,:apply_effect_spore)
      core.register(ABILITY_POISON_POINT,:after_contact,self,:apply_poison_point)
      core.register(ABILITY_FLAME_BODY,:after_contact,self,:apply_flame_body)
      core.register(ABILITY_SHED_SKIN,:end_turn,self,:apply_shed_skin)
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
        TEST_TROOP_ID,"Pokemon Ability F v2.5.5a AutoRegression",members)
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
      if current_round == 2
        @r2_storage_before = storage_size
        e[4].recover_all if e[4] != nil && e[4].respond_to?(:recover_all)
      elsif current_round == 3
        if e[4] != nil
          e[4].add_state(ALBERT_CG::MOVE_EFFECT::STATE_SLEEP)
          @vital_sleep_blocked = !e[4].state?(ALBERT_CG::MOVE_EFFECT::STATE_SLEEP)
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

    def self.reset_stat_stages(list)
      for b in list
        b.cg_reset_stat_stages if b != nil && b.respond_to?(:cg_reset_stat_stages)
      end
    end

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted = true
      a = test_allies
      e = all_enemies
      actual_troop_id = ($game_troop != nil && $game_troop.troop != nil) ? $game_troop.troop.id.to_i : 0
      assert_true("Ability Catalog count=373",defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.catalog_count == 373,
        "actual=" + (defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.catalog_count.to_s : "nil"))
      assert_true("Ability Batch F declares 8 IDs",HANDLED_ABILITY_IDS.size == 8)
      assert_true("Scene_Battle uses Ability F test troop",actual_troop_id == TEST_TROOP_ID,"actual=" + actual_troop_id.to_s)
      assert_true("Ability F ally count=4",a.size == 4,"actual=" + a.size.to_s)
      assert_true("Ability F starts with 4 active enemies",e.select { |b| b != nil && !b.hidden }.size == 4)
      assert_true("Ability F starts with 1 hidden Vital Spirit reserve",e.select { |b| b != nil && b.hidden }.size == 1)

      a[1].add_state(ALBERT_CG::MOVE_EFFECT::STATE_CONFUSION)
      own_ok = !a[1].state?(ALBERT_CG::MOVE_EFFECT::STATE_CONFUSION)
      @guard_checks += 1 if own_ok
      assert_true("Own Tempo blocks Confusion",own_ok)

      e[1].add_state(ALBERT_CG::MOVE_EFFECT::STATE_FLINCH)
      inner_ok = !e[1].state?(ALBERT_CG::MOVE_EFFECT::STATE_FLINCH)
      @guard_checks += 1 if inner_ok
      assert_true("Inner Focus blocks Flinch",inner_ok)

      reset_stat_stages(a + e)
      ALBERT_CG::ABILITY_A_V250.apply_intimidate(e[0],{:reason=>:regression})
      own_intim = a[1].cg_stat_stage(:atk).to_i == 0
      @guard_checks += 1 if own_intim
      assert_true("Own Tempo blocks Intimidate ATK drop",own_intim,"stage=" + a[1].cg_stat_stage(:atk).to_s)
      reset_stat_stages(a + e)
      ALBERT_CG::ABILITY_A_V250.apply_intimidate(a[2],{:reason=>:regression})
      inner_intim = e[1].cg_stat_stage(:atk).to_i == 0
      @guard_checks += 1 if inner_intim
      assert_true("Inner Focus blocks Intimidate ATK drop",inner_intim,"stage=" + e[1].cg_stat_stage(:atk).to_s)
      reset_stat_stages(a + e)

      e[3].add_state(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
      @shed_preburn = e[3].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
      assert_true("Shed Skin regression victim begins Burned",@shed_preburn)
    end

    def self.assert_round
      r = current_round
      a = test_allies
      e = all_enemies
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      if r == 1
        effect_ok = e[0].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON)
        @contact_checks += 1 if effect_ok
        assert_true("Effect Spore contact proc applies deterministic Poison",effect_ok)

        sync_target = a[3].state?(ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS)
        sync_source = e[2].state?(ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS)
        sync_ok = sync_target && sync_source
        @sync_checks += 1 if sync_ok
        assert_true("Synchronize reflects newly inflicted Paralysis to source",sync_ok,
          "target=" + sync_target.to_s + " source=" + sync_source.to_s)

        shed_ok = @shed_preburn && !e[3].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
        @recovery_checks += 1 if shed_ok
        assert_true("Shed Skin cures primary status at end-turn",shed_ok)
        e[2].remove_state(ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS) if e[2] != nil
      elsif r == 2
        poison_ok = a[1].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON)
        @contact_checks += 1 if poison_ok
        assert_true("Poison Point contact proc Poisons attacker",poison_ok)
        flame_ok = a[2].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
        @contact_checks += 1 if flame_ok
        assert_true("Flame Body contact proc Burns attacker",flame_ok)
        switched = e[3] != nil && e[4] != nil && e[3].hidden && !e[4].hidden
        @lifecycle_checks += 1 if switched
        assert_true("Teleport deploys hidden Vital Spirit reserve",switched,
          "E3_hidden=" + (e[3] == nil ? "nil" : e[3].hidden.to_s) + " E4_hidden=" + (e[4] == nil ? "nil" : e[4].hidden.to_s))
        storage_ok = storage_size == @r2_storage_before.to_i
        @lifecycle_checks += 1 if storage_ok
        assert_true("Vital Spirit reserve switch does not consume Storage Pokémon",storage_ok,
          "before=" + @r2_storage_before.to_s + " after=" + storage_size.to_s)
      elsif r == 3
        vital_ok = @vital_sleep_blocked == true && e[4] != nil && !e[4].state?(ALBERT_CG::MOVE_EFFECT::STATE_SLEEP)
        @guard_checks += 1 if vital_ok
        assert_true("Vital Spirit blocks Sleep after real reserve switch-in",vital_ok)
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
        " ability_f=" + ability_covered_count.to_s + "/8" +
        " guard_checks=" + @guard_checks.to_i.to_s +
        " contact_checks=" + @contact_checks.to_i.to_s +
        " sync_checks=" + @sync_checks.to_i.to_s +
        " recovery_checks=" + @recovery_checks.to_i.to_s +
        " lifecycle_checks=" + @lifecycle_checks.to_i.to_s + " pending=325")
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
      @sync_events = []
      @guard_checks = 0
      @contact_checks = 0
      @sync_checks = 0
      @recovery_checks = 0
      @lifecycle_checks = 0
      @actual = []
      @boot_asserted = false
      @shed_preburn = false
      @vital_sleep_blocked = false
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
        ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_F_v2.5.5a")
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

ALBERT_CG::ABILITY_F_V255.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Older Ability regression F11：Batch F 成為唯一最新版
#==============================================================================
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
  alias cg_v255f_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    return 100 if defined?(ALBERT_CG::ABILITY_F_V255) && ALBERT_CG::ABILITY_F_V255.active?
    return cg_v255f_ability_calc_hit(user,obj)
  end
  alias cg_v255f_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_F_V255) && ALBERT_CG::ABILITY_F_V255.active?
    return cg_v255f_ability_calc_eva(user,obj)
  end
  alias cg_v255f_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_F_V255) && ALBERT_CG::ABILITY_F_V255.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v255f_ability_priority_base_speed
  rescue
    return cg_v255f_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v255f_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_F_V255) && ALBERT_CG::ABILITY_F_V255.active?
      action = ALBERT_CG::ABILITY_F_V255.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v255f_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v255f_ability_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::ABILITY_F_V255.record_execution(battler) if defined?(ALBERT_CG::ABILITY_F_V255) && ALBERT_CG::ABILITY_F_V255.active?
    return cg_v255f_ability_execute_action
  end
  alias cg_v255f_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_F_V255) && ALBERT_CG::ABILITY_F_V255.active?
      # v2.5.5a Regression-only ordering fix:
      # Shed Skin lives on Ability Core :end_turn. The v2.5.5 harness asserted
      # before entering the inner Ability Core turn_end wrapper, so the real
      # cure happened one line after the assertion. Trigger it here first,
      # assert against the post-end-turn state, then suppress the inner duplicate.
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_F_V255.finish_round_assertions
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      else
        ALBERT_CG::ABILITY_F_V255.finish_round_assertions
      end
    end
    return cg_v255f_ability_turn_end
  end
  alias cg_v255f_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_F_V255) && ALBERT_CG::ABILITY_F_V255.active?
      return cg_v255f_ability_start_party_command
    end
    cg_v255f_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_F_V255.assert_bootstrap_once
    if ALBERT_CG::ABILITY_F_V255.finished?
      ALBERT_CG::ABILITY_F_V255.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_F_V255.prepare_round_actions
    start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v255f_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v255f_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_F_V255) && ALBERT_CG::ABILITY_F_V255.active?
        for cfg in ALBERT_CG::ABILITY_F_V255::TEST_ALLIES
          ALBERT_CG::ABILITY_F_V255.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_F_V255::TEST_LEVEL,false)
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
  alias cg_v255f_ability_scene_map_update update
  def update
    cg_v255f_ability_scene_map_update
    if !$game_temp.in_battle && !ALBERT_CG::ABILITY_F_V255.active? && ALBERT_CG::ABILITY_F_V255.f11_trigger?
      Sound.play_decision
      ALBERT_CG::ABILITY_F_V255.start_auto_test
    end
  end
end
