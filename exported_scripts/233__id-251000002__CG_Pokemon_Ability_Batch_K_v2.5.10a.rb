# RMVX_SCRIPT_INDEX: 233
# RMVX_SCRIPT_ID: 251000002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch K v2.5.10a
# RMVX_SOURCE_SHA256: b639d8ebfb5d324d96697c7626f969cdf101333882c1c9876f2ce03ba108cfd1

#==============================================================================
# ■ CG Pokemon Ability Batch K v2.5.10a - Stench Timing Fix
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.9 Ability Batch J Runtime PASS 基底上，正式實作第十一批 8 個「追加效果／
#  聲音免疫／吸血與反作用力／性別倍率／多段攻擊」Ability，並以 Actual Scene_Battle
#  deterministic F11 regression 驗證 Stench、Shield Dust、Serene Grace、Soundproof、
#  Liquid Ooze、Rock Head、Rivalry、Skill Link。
#
# 【本批 Ability】
#   1 Stench        惡臭：無原生畏縮追加的傷害招式，10% 額外畏縮。
#  19 Shield Dust   鱗粉：阻擋其他 Pokémon 傷害招式的追加效果。
#  32 Serene Grace  天恩：傷害招式追加效果機率 x2，最高 100%。
#  43 Soundproof    隔音：免疫其他 Pokémon 的聲音招式。
#  64 Liquid Ooze   污泥漿：吸血招式原本的回復量改成傷害使用者。
#  69 Rock Head     堅硬腦袋：免除自身 recoil Move 的反作用力傷害。
#  79 Rivalry       鬥爭心：同性目標傷害 x1.25、異性 x0.75，未知性別不變。
#  92 Skill Link    連續攻擊：可變多段 Move 固定最大段數。
#
# 【主要設定項】
#  TEST_TROOP_ID=713；ROUND_PLANS=3；HANDLED_ABILITY_IDS=8；Coverage 293 -> 285。
#
# 【機制規則】
#  1. 正式效果全部由 Secondary + Move Property Authority v2.5.10a 處理；Batch K
#     只負責 deterministic Scene_Battle 測試與 test-only RNG/速度 isolation。
#  2. Round1：Stench Tackle 故意在目標已完成 Action 後命中，驗證「晚到的 Flinch 不建立、
#     不污染下一回合」；Serene Grace + Rock Smash 把 50% DEF drop 提升到 100%；
#     Skill Link + Fury Swipes 建立 5-hit PMD sequence；Rock Head + Double-Edge 驗 recoil=0。
#  3. Round2：Giga Drain -> Liquid Ooze 傷害吸血者，同時讓 Stench 在目標尚未 Action 時
#     deterministic proc，驗證目標當回合真正 Flinch 並跳過 Action；Nuzzle -> Shield Dust、
#     Hyper Voice -> Soundproof、Teleport -> Rivalry reserve 與 Storage isolation。
#  4. Round3：Rivalry reserve 與男性目標實際 Tackle，最終 damage modifier x1.25。
#  5. Regression 中 Round1 指定 Tackle 與 Round2 Giga Drain 都要求 Stench decision=true；
#     Authority 必須自行依「目標是否仍有 pending Action」決定是否真正建立 Flinch。
#     正式玩家戰鬥仍是 10% RNG。
#  6. Regression 固定 hit=100 / eva=0 與 Priority 內速度，不修改正式 Move Accuracy。
#  7. TEST Convenience 只限 F11；正式 Release 必須恢復 emerged、Battle BGM/BGS 與正常焦點。
#
# 【可調參數】
#  TEST_TROOP_ID / TEST_SPEEDS / ROUND_PLANS；正式規則在 Authority v2.5.10a。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，一次跑完 3 回合，輸出
#  Pokemon_Ability_K_AutoTest_v2_5_10a.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Stench 慢於目標 -> 不把 Flinch 帶到下回合；Stench 快於目標 -> 當回合跳過 Action；
#  Rock Smash(50% DEF↓) + Serene Grace -> 100%；Giga Drain -> Liquid Ooze -> 吸血者扣血。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchK"] = "2.5.10a"

module ALBERT_CG
  module ABILITY_K_V2510
    VERSION = "2.5.10a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 713
    VK_F11 = 0x7A

    ABILITY_STENCH       = 1
    ABILITY_SHIELD_DUST  = 19
    ABILITY_SERENE_GRACE = 32
    ABILITY_SOUNDPROOF   = 43
    ABILITY_LIQUID_OOZE  = 64
    ABILITY_ROCK_HEAD    = 69
    ABILITY_RIVALRY      = 79
    ABILITY_SKILL_LINK   = 92

    HANDLED_ABILITY_IDS = [1,19,32,43,64,69,79,92]

    TEST_ALLIES = [
      {:dex=>88, :level=>40,:ability=>ABILITY_STENCH,       :moves=>[33,202,150,150]},
      {:dex=>113,:level=>40,:ability=>ABILITY_SERENE_GRACE, :moves=>[249,609,150,150]},
      {:dex=>91, :level=>40,:ability=>ABILITY_SKILL_LINK,    :moves=>[154,304,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>73, :level=>40,:ability=>ABILITY_LIQUID_OOZE,:moves=>[150,150,150,150]},
      {:dex=>49, :level=>40,:ability=>ABILITY_SHIELD_DUST,:moves=>[150,150,150,150]},
      {:dex=>295,:level=>40,:ability=>ABILITY_SOUNDPROOF, :moves=>[150,150,150,150]},
      {:dex=>112,:level=>40,:ability=>ABILITY_ROCK_HEAD,  :moves=>[38,100,150,150]},
      {:dex=>128,:level=>40,:ability=>ABILITY_RIVALRY,    :moves=>[33,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"STENCH_SERENE_SKILLLINK_ROCKHEAD",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>0},
          {:kind=>:move,:move_id=>249,:target=>0},
          {:kind=>:move,:move_id=>154,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>38,:target=>2},
        }
      },
      {
        :name=>"LIQUID_OOZE_SHIELD_DUST_SOUNDPROOF_RIVALRY_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>202,:target=>0},
          {:kind=>:move,:move_id=>609,:target=>1},
          {:kind=>:move,:move_id=>304,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>100,:target=>0},
        }
      },
      {
        :name=>"RIVALRY_SAME_GENDER_DAMAGE",
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
      :r1=>[10,230,220,210, 260,180,170,200,0],
      :r2=>[10,260,250,240, 220,210,200,100,0],
      :r3=>[10,180,170,160, 150,140,130,0,260],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","E0:M150","A1:M33","A2:M249","A3:M154","E3:M38","E1:M150","E2:M150"],
      2=>["A0:Guard","A1:M202","A2:M609","A3:M304","E1:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","E4:M33","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150"],
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
    def self.log_path; return File.join(project_root,"Pokemon_Ability_K_AutoTest_v2_5_10a.log"); end
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
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_K_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end

    def self.reset_log
      header = "CG POKEMON ABILITY K SECONDARY + MOVE PROPERTY AUTO REGRESSION v2.5.10a\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; secondary chance/guard + sound immunity + drain/recoil + multi-hit + Rivalry\r\n" +
        "BASELINE=v2.5.9 Ability Batch J Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_B_C_D_E_F_G_H_I_J_PASS=80 BATCH_K=8 PENDING=285\r\n" +
        "FORMAL_FIX=Stench only creates Flinch when target still has a pending Action this turn; prevents next-turn carryover\r\n" +
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

    def self.compact_ctx(data)
      return "{}" if data == nil
      parts=[]
      [:move_id,:kind,:before,:after,:amount,:damage_done,:state,:min_hits,:max_hits,:hits,
       :percent,:user_gender,:target_gender].each do |k|
        parts.push(k.to_s + "=" + data[k].to_s) if data.has_key?(k)
      end
      return "{" + parts.join(",") + "}"
    rescue
      return "{}"
    end

    def self.note_external_trigger(aid,battler,kind,ctx=nil)
      return true unless active?
      @ability_trigger_counts[aid.to_i] = @ability_trigger_counts[aid.to_i].to_i + 1
      data = ctx == nil ? {} : ctx
      @last_records[aid.to_i] = {:kind=>kind,:ctx=>data,:battler=>battler}
      log("ABILITY_K_TRIGGER ability=" + aid.to_i.to_s + " battler=" + battler_token(battler) +
        " kind=" + kind.to_s + " ctx=" + compact_ctx(data))
      return true
    rescue
      return true
    end

    def self.note_rivalry_record(data)
      return unless active?
      @rivalry_record = data
      @ability_trigger_counts[ABILITY_RIVALRY] = @ability_trigger_counts[ABILITY_RIVALRY].to_i + 1
      log("ABILITY_K_TRIGGER ability=79 battler=E4 kind=rivalry ctx=" + compact_ctx(data))
    rescue
    end

    def self.stench_test_decision(user,target,move_id)
      return nil unless active?
      valid_pair = user != nil && user.actor? && user.index.to_i == 1 &&
        target != nil && !target.actor? && target.index.to_i == 0
      return true if valid_pair && current_round == 1 && move_id.to_i == 33
      return true if valid_pair && current_round == 2 && move_id.to_i == 202
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
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,
          ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],
          ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1]]
      members=[]
      TEST_ENEMIES.each_with_index do |cfg,i|
        configure_enemy(cfg)
        m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]),xs[i],ys[i])
        m.hidden=(i>=4)
        members.push(m)
      end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID,"Pokemon Ability K v2.5.10a AutoRegression",members)
    end

    def self.make_action(battler,cfg)
      action=Game_BattleAction.new(battler)
      if cfg[:kind]==:guard
        action.set_guard
      elsif cfg[:kind]==:move
        action.set_skill(master.skill_id_for_move(cfg[:move_id].to_i))
      else
        action.clear
      end
      action.target_index=cfg[:target].to_i if cfg.has_key?(:target)
      return action
    end

    def self.forced_enemy_action(enemy)
      return nil unless active? && enemy != nil && !enemy.hidden && enemy.hp.to_i>0
      plan=current_plan
      return nil if plan==nil
      cfg=plan[:enemies][enemy.index]
      return cfg==nil ? nil : make_action(enemy,cfg)
    end

    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym] || []
      list=test_allies+all_enemies
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
      return b==nil || !b.respond_to?(:cg_stat_stage) ? 0 : b.cg_stat_stage(key).to_i
    rescue
      return 0
    end

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted=true
      a=test_allies; e=all_enemies
      assert_true("Ability Catalog count=373",defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.catalog_count.to_i==373,
        "actual="+(defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.catalog_count.to_i.to_s : "0"))
      assert_true("Ability Batch K declares 8 IDs",HANDLED_ABILITY_IDS.size==8)
      troop_id=($game_troop!=nil && $game_troop.troop!=nil) ? $game_troop.troop.id.to_i : 0
      assert_true("Scene_Battle uses Ability K test troop",troop_id==TEST_TROOP_ID,"actual="+troop_id.to_s)
      assert_true("Ability K ally count=4",a.size==4,"actual="+a.size.to_s)
      assert_true("Ability K starts with 4 active enemies",e.select{|b| b!=nil && !b.hidden}.size==4)
      assert_true("Ability K starts with 1 hidden Rivalry reserve",e.select{|b| b!=nil && b.hidden}.size==1)
      a[1].instance_variable_set(:@cg_gender,:male) if a[1] != nil
      a[2].instance_variable_set(:@cg_gender,:female) if a[2] != nil
      e[4].instance_variable_set(:@cg_gender,:male) if e[4] != nil
      @storage_before=storage_size
      @rock_hp_before=e[3] == nil ? 0 : e[3].hp.to_i
    end

    def self.prepare_round_actions
      plan=current_plan
      return if plan==nil
      apply_test_speeds
      a=test_allies
      a.each_with_index do |b,i|
        next if b==nil || b.hidden || b.hp.to_i<=0
        cfg=plan[:allies][i]
        b.instance_variable_set(:@cg_round_actions,[make_action(b,cfg)]) if cfg!=nil
      end
      @actual=[]
      if current_round==2
        e=all_enemies
        @sound_hp_before=e[2] == nil ? 0 : e[2].hp.to_i
      end
      log("ROUND "+current_round.to_s+" BEGIN "+plan[:name].to_s)
    end

    def self.execution_token(battler)
      return "nil" if battler==nil
      prefix=battler.actor? ? "A" : "E"; idx=battler.index.to_i; action=battler.action
      return prefix+idx.to_s+":Guard" if action!=nil && action.guard?
      if action!=nil && action.skill?
        skill=$data_skills[action.skill_id]
        mid=defined?(ALBERT_CG::MOVE_EFFECT) && skill!=nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0
        return prefix+idx.to_s+":M"+mid.to_s
      end
      return prefix+idx.to_s+":Other"
    rescue
      return "?"
    end

    def self.record_execution(battler)
      return unless active?
      token=execution_token(battler); @actual.push(token)
      log("ACTION_EXEC #"+@actual.size.to_s+" "+(battler==nil ? "nil" : battler.name.to_s)+" token="+token)
    end

    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies
      expected=EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==expected,
        "expected="+expected.inspect+" actual="+@actual.inspect)
      if r==1
        sid=defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_FLINCH : 48
        stench_late_ok=e[0]!=nil && !e[0].state?(sid) && @ability_trigger_counts[ABILITY_STENCH].to_i==0
        assert_true("Stench does not create late Flinch after target already acted",stench_late_ok,
          "flinch="+(e[0]==nil ? "nil" : e[0].state?(sid).to_s)+
          " trigger="+@ability_trigger_counts[ABILITY_STENCH].to_i.to_s)
        rec=@last_records[ABILITY_SERENE_GRACE]
        ctx=rec==nil ? nil : rec[:ctx]
        serene_ok=ctx!=nil && ctx[:kind]==:stat && ctx[:before].to_i==50 && ctx[:after].to_i==100 && stat_stage(e[0],:def)==-1
        @secondary_checks+=1 if serene_ok
        assert_true("Serene Grace doubles Rock Smash 50% stat chance to 100%",serene_ok,
          "record="+compact_ctx(ctx)+" def="+stat_stage(e[0],:def).to_s)
        hits=a[3]==nil ? 0 : a[3].instance_variable_get(:@cg_pmd_pending_multi_hits).to_i
        skill_ok=hits==5 && @ability_trigger_counts[ABILITY_SKILL_LINK].to_i>0
        @multi_hit_checks+=1 if skill_ok
        assert_true("Skill Link forces Fury Swipes maximum 5 hits",skill_ok,"hits="+hits.to_s)
        rock_ok=e[3]!=nil && e[3].hp.to_i==@rock_hp_before.to_i && @ability_trigger_counts[ABILITY_ROCK_HEAD].to_i>0
        @recoil_checks+=1 if rock_ok
        assert_true("Rock Head prevents Double-Edge recoil",rock_ok,
          "before="+@rock_hp_before.to_s+" after="+(e[3]==nil ? "nil" : e[3].hp.to_i.to_s))
      elsif r==2
        rec=@last_records[ABILITY_LIQUID_OOZE]; ctx=rec==nil ? nil : rec[:ctx]
        ooze_ok=ctx!=nil && ctx[:amount].to_i>0 && ctx[:after].to_i==ctx[:before].to_i-ctx[:amount].to_i
        @drain_checks+=1 if ooze_ok
        assert_true("Liquid Ooze converts Giga Drain healing into attacker damage",ooze_ok,
          "record="+compact_ctx(ctx))
        flinch_sid=defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_FLINCH : 48
        stench_valid_ok=e[0]!=nil && @ability_trigger_counts[ABILITY_STENCH].to_i==1 &&
          !@actual.include?("E0:M150") && !e[0].state?(flinch_sid)
        @secondary_checks+=1 if stench_valid_ok
        assert_true("Stench flinches pending target this turn and clears before next round",stench_valid_ok,
          "trigger="+@ability_trigger_counts[ABILITY_STENCH].to_i.to_s+
          " E0_acted="+@actual.include?("E0:M150").to_s+
          " flinch_end="+(e[0]==nil ? "nil" : e[0].state?(flinch_sid).to_s))
        par=defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS : 37
        shield_ok=e[1]!=nil && !e[1].state?(par) && @ability_trigger_counts[ABILITY_SHIELD_DUST].to_i>0
        @secondary_checks+=1 if shield_ok
        assert_true("Shield Dust blocks Nuzzle additional Paralysis",shield_ok,
          "paralyzed="+(e[1]==nil ? "nil" : e[1].state?(par).to_s))
        sound_ok=e[2]!=nil && e[2].hp.to_i==@sound_hp_before.to_i && @ability_trigger_counts[ABILITY_SOUNDPROOF].to_i>0
        @sound_checks+=1 if sound_ok
        assert_true("Soundproof blocks Hyper Voice damage/effect",sound_ok,
          "hp="+@sound_hp_before.to_s+"->"+(e[2]==nil ? "nil" : e[2].hp.to_i.to_s))
        switched=e[3]!=nil && e[4]!=nil && e[3].hidden && !e[4].hidden
        @lifecycle_checks+=1 if switched
        assert_true("Teleport deploys hidden Rivalry reserve",switched,
          "E3_hidden="+(e[3]==nil ? "nil" : e[3].hidden.to_s)+" E4_hidden="+(e[4]==nil ? "nil" : e[4].hidden.to_s))
        storage_ok=storage_size==@storage_before.to_i
        @lifecycle_checks+=1 if storage_ok
        assert_true("Rivalry reserve switch does not consume Storage Pokemon",storage_ok,
          "before="+@storage_before.to_s+" after="+storage_size.to_s)
      elsif r==3
        assert_true("Stench target acts normally on the following round after Flinch clears",@actual.include?("E0:M150"),
          "actual="+@actual.inspect)
        rec=@rivalry_record
        rivalry_ok=rec!=nil && rec[:percent].to_i==125 && rec[:user_gender]==:male && rec[:target_gender]==:male &&
          rec[:after].to_i==[rec[:before].to_i*125/100,1].max
        @damage_checks+=1 if rivalry_ok
        assert_true("Rivalry boosts same-gender final damage x1.25",rivalry_ok,
          "record="+compact_ctx(rec))
      end
      log("ROUND "+r.to_s+" END")
    end

    def self.finish_round_assertions
      return unless active?
      assert_round
      @round_index+=1
    end

    def self.ability_covered_count
      count=0
      HANDLED_ABILITY_IDS.each{|aid| count+=1 if @ability_trigger_counts[aid].to_i>0}
      return count
    end

    def self.cleanup_test_overrides
      (test_allies+all_enemies).each{|b| b.instance_variable_set(:@cg_priority_test_speed_override,nil) if b!=nil}
    end

    def self.finish_suite
      HANDLED_ABILITY_IDS.each do |aid|
        assert_true("Ability "+aid.to_s+" triggered",@ability_trigger_counts[aid].to_i>0,
          "count="+@ability_trigger_counts[aid].to_i.to_s)
      end
      result=@failures.empty? ? "PASS" : "FAIL"
      log("------------------------------------------------------------")
      log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+
        " ability_k="+ability_covered_count.to_s+"/8"+
        " secondary_checks="+@secondary_checks.to_i.to_s+
        " sound_checks="+@sound_checks.to_i.to_s+
        " drain_checks="+@drain_checks.to_i.to_s+
        " recoil_checks="+@recoil_checks.to_i.to_s+
        " multi_hit_checks="+@multi_hit_checks.to_i.to_s+
        " damage_checks="+@damage_checks.to_i.to_s+
        " lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=285")
      @failures.each_with_index{|x,i| log("FAILURE "+(i+1).to_s+" "+x.to_s)}
      cleanup_test_overrides
      @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end

    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @last_records={}; @rivalry_record=nil
      @secondary_checks=0; @sound_checks=0; @drain_checks=0; @recoil_checks=0; @multi_hit_checks=0
      @damage_checks=0; @lifecycle_checks=0; @actual=[]; @boot_asserted=false; @storage_before=0
      @rock_hp_before=0; @sound_hp_before=0
    end

    def self.start_auto_test
      return false if active?
      reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_K_v2.5.10a") if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s)
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue => e
      @failures=[] if @failures==nil
      @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s)
      log(@failures[-1]); @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
      return false
    end
  end
end

#------------------------------------------------------------------------------
# Batch K 為唯一最新版 F11
#------------------------------------------------------------------------------
if defined?(ALBERT_CG::ABILITY_J_V259)
  module ALBERT_CG; module ABILITY_J_V259; def self.f11_trigger?; return false; end; end; end
end

#------------------------------------------------------------------------------
# Regression-only deterministic bridges
#------------------------------------------------------------------------------
class Game_Battler
  alias cg_v2510k_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_K_V2510) && ALBERT_CG::ABILITY_K_V2510.active?
    return cg_v2510k_ability_calc_eva(user,obj)
  end

  alias cg_v2510k_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    return 100 if defined?(ALBERT_CG::ABILITY_K_V2510) && ALBERT_CG::ABILITY_K_V2510.active?
    return cg_v2510k_ability_calc_hit(user,obj)
  end

  alias cg_v2510k_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_K_V2510) && ALBERT_CG::ABILITY_K_V2510.active?
      value=@cg_priority_test_speed_override
      return value.to_i if value!=nil
    end
    return cg_v2510k_ability_priority_base_speed
  rescue
    return cg_v2510k_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2510k_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_K_V2510) && ALBERT_CG::ABILITY_K_V2510.active?
      action=ALBERT_CG::ABILITY_K_V2510.forced_enemy_action(self)
      if action!=nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action=action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v2510k_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2510k_ability_execute_action execute_action
  def execute_action
    battler=@active_battler
    ALBERT_CG::ABILITY_K_V2510.record_execution(battler) if defined?(ALBERT_CG::ABILITY_K_V2510) && ALBERT_CG::ABILITY_K_V2510.active?
    return cg_v2510k_ability_execute_action
  end

  alias cg_v2510k_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_K_V2510) && ALBERT_CG::ABILITY_K_V2510.active?
      ALBERT_CG::ABILITY_K_V2510.finish_round_assertions
    end
    return cg_v2510k_ability_turn_end
  end

  alias cg_v2510k_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_K_V2510) && ALBERT_CG::ABILITY_K_V2510.active?
      return cg_v2510k_ability_start_party_command
    end
    cg_v2510k_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_K_V2510.assert_bootstrap_once
    if ALBERT_CG::ABILITY_K_V2510.finished?
      ALBERT_CG::ABILITY_K_V2510.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_K_V2510.prepare_round_actions
    start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2510k_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result=cg_v2510k_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_K_V2510) && ALBERT_CG::ABILITY_K_V2510.active?
        ALBERT_CG::ABILITY_K_V2510::TEST_ALLIES.each{|cfg| ALBERT_CG::ABILITY_K_V2510.configure_actor(cfg)}
        human=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human!=nil
          human.change_level(ALBERT_CG::ABILITY_K_V2510::TEST_LEVEL,false)
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
  alias cg_v2510k_ability_scene_map_update update
  def update
    cg_v2510k_ability_scene_map_update
    if !$game_temp.in_battle && !ALBERT_CG::ABILITY_K_V2510.active? && ALBERT_CG::ABILITY_K_V2510.f11_trigger?
      Sound.play_decision
      ALBERT_CG::ABILITY_K_V2510.start_auto_test
    end
  end
end
