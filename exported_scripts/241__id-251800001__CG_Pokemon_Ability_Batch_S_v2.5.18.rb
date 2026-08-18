# RMVX_SCRIPT_INDEX: 241
# RMVX_SCRIPT_ID: 251800001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch S v2.5.18
# RMVX_SOURCE_SHA256: da0ffea9fff168dcfcad6c8ed020de286b9d93cc4916ea3f874b2a0691f98511

#==============================================================================
# ■ CG Pokemon Ability Batch S v2.5.18 - Field Conditional Stat + Power
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.17a Ability Batch R RPG Maker VX 實機 PASS 為唯一基底，實作第十九批
#  8 個 Ability。本批集中處理「天氣／場地下的能力值與傷害倍率、場地建立、一次性
#  Entry Debuff」，完全沿用既有 Weather Authority、FIELD_V233 唯一天氣／場地 state、
#  Ability Core :entry、既有 :stat_query / :damage_modify Authority，不重開 Move Phase。
#
# 【本批 Ability】
#  159 Sand Force       沙之力：Sandstorm 下 Rock/Ground/Steel 傷害 x1.30，且免疫沙暴 residual。
#  179 Grass Pelt       草之毛皮：Grassy Terrain 下 DEF x1.50。
#  202 Slush Rush       撥雪：本專案 snow/hail Authority 啟動時 SPE x2。
#  207 Surge Surfer     衝浪之尾：Electric Terrain 下 SPE x2。
#  276 Rocky Payload    搬岩：Rock 招式傷害 x1.50。
#  288 Orichalcum Pulse 緋紅脈動：Entry 建立 Sun 5 turns；Sun 下 ATK x4/3。
#  289 Hadron Engine    強子引擎：Entry 建立 Electric Terrain 5 turns；該 Terrain 下 SPA x4/3。
#  300 Supersweet Syrup 甘露之蜜：每場戰鬥第一次 Entry，所有 active 對手 Evasion -1。
#
# 【主要設定項】
#  TEST_TROOP_ID=721；HANDLED_ABILITY_IDS=8。
#  Coverage：144/373 -> 152/373，pending 229 -> 221。
#  FIELD_TURNS=5；Sand Force=130%；Grass Pelt/Rocky Payload=150%；
#  Slush Rush/Surge Surfer=200%；Orichalcum/Hadron=4/3。
#
# 【機制規則】
#  1. Orichalcum Pulse 使用既有 ABILITY_WEATHER_V252.set_weather(:sun, ..., 5)，因此
#     仍只有 FIELD_V233 一份正式 Weather state，並照常發出 weather_changed。
#  2. Hadron Engine 直接寫入 FIELD_V233 唯一 Terrain state 並呼叫 Core
#     notify_terrain_changed；不建立第二套 Electric Terrain。
#  3. Grass Pelt / Slush Rush / Surge Surfer / Orichalcum / Hadron 都只走既有
#     :stat_query；正式 Base Stats、Stat Stage、Field bonus 先完成，再在最外層套 Ability。
#  4. Sand Force / Rocky Payload 只走既有 :damage_modify，Fixed Damage 不吃倍率。
#  5. Sand Force 的沙暴 residual immunity 只在 FIELD_V233.apply_weather_residual 的
#     Sandstorm 分支加入 Ability 159 skip；Rock/Ground/Steel 原生免疫規則保持原樣，
#     Hail 與其他 Field turn-end 行為完全交回既有 Field Core。
#  6. Supersweet Syrup 用目前 Scene_Battle object_id 作 battle token：同一場戰鬥的
#     holder 即使再次 Entry 也不會重複觸發；下一場 Scene_Battle 會自然取得新 token。
#  7. 所有有效 Ability ID 均由 Ability Core ability_id/cg_master_ability_id 取得，持續
#     尊重既有 Suppression / Override；hidden、KO reserve 不參與 active 行為。
#  8. F11 Regression 使用 Actual Scene_Battle。TEST-only 可固定 Action/SPE/命中並改
#     Weather/Terrain fixture；正式玩家戰鬥 RNG、Priority、Field duration 不受影響。
#  9. Round2 由 Hadron Engine holder 正式使用 Teleport，部署 hidden Supersweet Syrup
#     reserve；Storage 仍不是 battle reserve，不得消耗 Storage Pokemon。
# 10. TEST Convenience 僅限 F11；正式 Release 需恢復 emerged、BGM/BGS、正常焦點。
#
# 【可調參數】
#  SAND_FORCE_PERCENT=130、GRASS_PELT_PERCENT=150、SLUSH_RUSH_PERCENT=200、
#  SURGE_SURFER_PERCENT=200、ROCKY_PAYLOAD_PERCENT=150、ENGINE_NUM/DEN=4/3、
#  FIELD_TURNS=5。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫；Ability 由 Entry / Stat / Damage / Field lifecycle 自動處理。
#  開發測試：地圖按 F11，自動進 troop 721，跑三回合並輸出
#  Pokemon_Ability_S_AutoTest_v2_5_18.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Battle Entry：Orichalcum Pulse 建 Sun、Hadron Engine 建 Electric Terrain，隨即以正式
#  stat query 驗 ATK/SPA x4/3。
#  Round1：TEST fixture 改 Sandstorm；Sand Force 的 Rock Throw x1.30、Rocky Payload
#  的 Rock Throw x1.50，並另外實際呼叫 Field residual 驗 Sand Force 不吃沙暴傷害。
#  Round2：Grassy Terrain 下驗 Grass Pelt DEF x1.50；Hadron holder 使用 Teleport，
#  換入 Supersweet Syrup reserve，驗對手 Evasion -1 與 Storage isolation。
#  Round3：Hail + Electric Terrain 並存，驗 Slush Rush / Surge Surfer SPE x2，並確認
#  Supersweet Syrup reserve 穩定且同場不重複 Entry trigger。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchS"] = "2.5.18"

module ALBERT_CG
  module ABILITY_S_V2518
    VERSION = "2.5.18"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 721
    VK_F11 = 0x7A
    FIELD_TURNS = 5

    ABILITY_SAND_FORCE       = 159
    ABILITY_GRASS_PELT       = 179
    ABILITY_SLUSH_RUSH       = 202
    ABILITY_SURGE_SURFER     = 207
    ABILITY_ROCKY_PAYLOAD    = 276
    ABILITY_ORICHALCUM_PULSE = 288
    ABILITY_HADRON_ENGINE    = 289
    ABILITY_SUPERSWEET_SYRUP = 300
    HANDLED_ABILITY_IDS = [159,179,202,207,276,288,289,300]

    SAND_FORCE_PERCENT = 130
    GRASS_PELT_PERCENT = 150
    SLUSH_RUSH_PERCENT = 200
    SURGE_SURFER_PERCENT = 200
    ROCKY_PAYLOAD_PERCENT = 150
    ENGINE_NUM = 4
    ENGINE_DEN = 3

    TEST_ALLIES = [
      {:dex=>25, :level=>40, :ability=>ABILITY_SAND_FORCE,    :moves=>[88,150,150,150]},
      {:dex=>65, :level=>40, :ability=>ABILITY_SURGE_SURFER,  :moves=>[150,150,150,150]},
      {:dex=>128,:level=>40, :ability=>ABILITY_ROCKY_PAYLOAD, :moves=>[88,150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>70,:ability=>ABILITY_GRASS_PELT,       :moves=>[150,150,150,150]},
      {:dex=>94, :level=>60,:ability=>ABILITY_SLUSH_RUSH,       :moves=>[150,150,150,150]},
      {:dex=>91, :level=>60,:ability=>ABILITY_ORICHALCUM_PULSE, :moves=>[150,150,150,150]},
      {:dex=>109,:level=>50,:ability=>ABILITY_HADRON_ENGINE,    :moves=>[150,100,150,150]},
      {:dex=>197,:level=>60,:ability=>ABILITY_SUPERSWEET_SYRUP, :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {:name=>"SAND_FORCE_AND_ROCKY_PAYLOAD",
       :allies=>[{:kind=>:guard},{:kind=>:move,:move_id=>88,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>88,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>2},2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>2}}},
      {:name=>"GRASS_PELT_AND_SUPERSWEET_SWITCH",
       :allies=>[{:kind=>:guard},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>2},2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>100,:target=>0}}},
      {:name=>"SLUSH_SURGE_AND_RESERVE_STABILITY",
       :allies=>[{:kind=>:guard},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>2},2=>{:kind=>:move,:move_id=>150,:target=>1},4=>{:kind=>:move,:move_id=>150,:target=>2}}},
    ]

    TEST_SPEEDS = {
      :r1=>[500,450,300,400, 350,250,200,150,0],
      :r2=>[500,450,300,400, 350,250,200,150,0],
      :r3=>[500,450,300,400, 350,250,200,0,425],
    }
    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M88","A3:M88","E0:M150","A2:M150","E1:M150","E2:M150","E3:M150"],
      2=>["A0:Guard","A1:M150","A3:M150","E0:M150","A2:M150","E1:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","A1:M150","E4:M150","A3:M150","E0:M150","A2:M150","E1:M150","E2:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.field; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233 : nil; end
    def self.field_state; f=field; f && f.respond_to?(:state) ? f.state : nil; rescue; nil; end
    def self.active?; @active == true; end
    def self.current_round; @round_index.to_i + 1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i >= ROUND_PLANS.size; end
    def self.test_allies; $game_party == nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop == nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_S_AutoTest_v2_5_18.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else
        text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text)
      end
      condition
    end
    def self.reset_log
      h="CG POKEMON ABILITY S FIELD CONDITIONAL STAT + POWER AUTO REGRESSION v2.5.18\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; weather/terrain stat + damage + entry + residual lifecycle\r\n"+
        "BASELINE=v2.5.17a Ability Batch R Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_R_PASS=144 BATCH_S=8 PENDING=221\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue
    end

    def self.type_id(sym)
      return 0 unless defined?(ALBERT_CG::POKEMON_COMBAT)
      return ALBERT_CG::POKEMON_COMBAT.type_id(sym).to_i if ALBERT_CG::POKEMON_COMBAT.respond_to?(:type_id)
      t=ALBERT_CG::POKEMON_COMBAT::TYPE_IDS; t && t.has_key?(sym) ? t[sym].to_i : 0
    rescue
      0
    end
    def self.weather_active?(sym); st=field_state; st!=nil && st.weather==sym && st.weather_turns.to_i>0; rescue; false; end
    def self.terrain_active?(sym); st=field_state; st!=nil && st.terrain==sym && st.terrain_turns.to_i>0; rescue; false; end
    def self.ratio(v,num,den); x=v.to_i; return x if x<=0; y=x*num.to_i/den.to_i; y=1 if y<1; y; end
    def self.fixed_damage?(ctx); ctx[:fixed_damage]==true; rescue; false; end
    def self.battler_token(b); return "nil" if b==nil; (b.actor? ? "A" : "E")+b.index.to_s; rescue; "?"; end

    def self.note_local(aid,battler,kind,data=nil)
      return true unless active?
      @ability_trigger_counts[aid]=@ability_trigger_counts[aid].to_i+1
      rec={:ability=>aid,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless k==:battler||k==:user||k==:target||k==:skill}
      @records[aid]=[] if @records[aid]==nil; @records[aid].push(rec)
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
      log("ABILITY_S_TRIGGER ability="+aid.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
      true
    rescue
      false
    end
    def self.note_residual_guard(battler)
      return false if battler==nil
      ctx={:weather=>:sandstorm,:hp=>battler.hp.to_i}
      if core
        core.note_trigger(:weather_residual_guard,battler,ABILITY_SAND_FORCE,ctx) if core.respond_to?(:note_trigger)
        core.present_trigger(battler,ABILITY_SAND_FORCE,:weather_residual_guard,ctx) if core.respond_to?(:present_trigger)
      end
      note_local(ABILITY_SAND_FORCE,battler,:sandstorm_residual_guard,ctx)
    end

    def self.apply_stat_ratio(aid,battler,ctx,kind,num,den)
      before=ctx[:value].to_i; return false if before<=0
      after=ratio(before,num,den); ctx[:value]=after
      note_local(aid,battler,kind,{:stat=>ctx[:stat],:before=>before,:after=>after})
    end
    def self.apply_damage_ratio(aid,battler,ctx,kind,num,den)
      before=ctx[:damage].to_i; return false if before<=0 || fixed_damage?(ctx)
      after=ratio(before,num,den); ctx[:damage]=after
      note_local(aid,battler,kind,{:before=>before,:after=>after,:move_id=>ctx[:move_id].to_i,:type_id=>ctx[:type_id].to_i,:role=>ctx[:role]})
    end

    def self.apply_sand_force(battler,ctx)
      return false unless ctx[:role]==:attacker && weather_active?(:sandstorm)
      allowed=[type_id(:rock),type_id(:ground),type_id(:steel)]
      return false unless allowed.include?(ctx[:type_id].to_i)
      apply_damage_ratio(ABILITY_SAND_FORCE,battler,ctx,:sand_force,SAND_FORCE_PERCENT,100)
    end
    def self.apply_grass_pelt(battler,ctx)
      return false unless ctx[:stat]==:def && terrain_active?(:grassy)
      apply_stat_ratio(ABILITY_GRASS_PELT,battler,ctx,:grass_pelt,GRASS_PELT_PERCENT,100)
    end
    def self.apply_slush_rush(battler,ctx)
      return false unless ctx[:stat]==:spe && weather_active?(:hail)
      apply_stat_ratio(ABILITY_SLUSH_RUSH,battler,ctx,:slush_rush,SLUSH_RUSH_PERCENT,100)
    end
    def self.apply_surge_surfer(battler,ctx)
      return false unless ctx[:stat]==:spe && terrain_active?(:electric)
      apply_stat_ratio(ABILITY_SURGE_SURFER,battler,ctx,:surge_surfer,SURGE_SURFER_PERCENT,100)
    end
    def self.apply_rocky_payload(battler,ctx)
      return false unless ctx[:role]==:attacker && ctx[:type_id].to_i==type_id(:rock)
      apply_damage_ratio(ABILITY_ROCKY_PAYLOAD,battler,ctx,:rocky_payload,ROCKY_PAYLOAD_PERCENT,100)
    end
    def self.apply_orichalcum_entry(battler,ctx)
      return false unless defined?(ALBERT_CG::ABILITY_WEATHER_V252)
      st=field_state; before=st ? st.weather : nil; before_turns=st ? st.weather_turns.to_i : 0
      ok=ALBERT_CG::ABILITY_WEATHER_V252.set_weather(:sun,battler,ABILITY_ORICHALCUM_PULSE,FIELD_TURNS)
      return false unless ok
      note_local(ABILITY_ORICHALCUM_PULSE,battler,:entry,{:before=>before,:before_turns=>before_turns,:weather=>:sun,:turns=>FIELD_TURNS})
    rescue
      false
    end
    def self.apply_orichalcum_stat(battler,ctx)
      return false unless ctx[:stat]==:atk && weather_active?(:sun)
      apply_stat_ratio(ABILITY_ORICHALCUM_PULSE,battler,ctx,:orichalcum_atk,ENGINE_NUM,ENGINE_DEN)
    end
    def self.set_electric_terrain(battler)
      st=field_state; return false if st==nil
      before=st.terrain; before_turns=st.terrain_turns.to_i
      st.terrain=:electric; st.terrain_turns=FIELD_TURNS
      core.notify_terrain_changed(battler) if core && core.respond_to?(:notify_terrain_changed)
      note_local(ABILITY_HADRON_ENGINE,battler,:entry,{:before=>before,:before_turns=>before_turns,:terrain=>:electric,:turns=>FIELD_TURNS})
      true
    rescue
      false
    end
    def self.apply_hadron_entry(battler,ctx); set_electric_terrain(battler); end
    def self.apply_hadron_stat(battler,ctx)
      return false unless ctx[:stat]==:spa && terrain_active?(:electric)
      apply_stat_ratio(ABILITY_HADRON_ENGINE,battler,ctx,:hadron_spa,ENGINE_NUM,ENGINE_DEN)
    end
    def self.apply_supersweet_syrup(battler,ctx)
      return false if battler==nil || core==nil
      token=($scene==nil ? 0 : $scene.object_id)
      old=battler.instance_variable_get(:@cg_v2518s_supersweet_battle_token)
      return false if token!=0 && old==token
      battler.instance_variable_set(:@cg_v2518s_supersweet_battle_token,token)
      changed=[]
      core.opponents_of(battler).each do |target|
        next if target==nil || !target.respond_to?(:cg_change_stat_stage) || !target.respond_to?(:cg_stat_stage)
        before=target.cg_stat_stage(:evasion).to_i
        target.cg_change_stat_stage(:evasion,-1)
        after=target.cg_stat_stage(:evasion).to_i
        changed.push(battler_token(target)+":"+before.to_s+">"+after.to_s) if after<before
      end
      return false if changed.empty?
      note_local(ABILITY_SUPERSWEET_SYRUP,battler,:entry,{:changed=>changed.join("|")})
    rescue
      false
    end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_SAND_FORCE,:damage_modify,self,:apply_sand_force)
      core.register(ABILITY_GRASS_PELT,:stat_query,self,:apply_grass_pelt)
      core.register(ABILITY_SLUSH_RUSH,:stat_query,self,:apply_slush_rush)
      core.register(ABILITY_SURGE_SURFER,:stat_query,self,:apply_surge_surfer)
      core.register(ABILITY_ROCKY_PAYLOAD,:damage_modify,self,:apply_rocky_payload)
      core.register(ABILITY_ORICHALCUM_PULSE,:entry,self,:apply_orichalcum_entry)
      core.register(ABILITY_ORICHALCUM_PULSE,:stat_query,self,:apply_orichalcum_stat)
      core.register(ABILITY_HADRON_ENGINE,:entry,self,:apply_hadron_entry)
      core.register(ABILITY_HADRON_ENGINE,:stat_query,self,:apply_hadron_stat)
      core.register(ABILITY_SUPERSWEET_SYRUP,:entry,self,:apply_supersweet_syrup)
      true
    end

    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime)
    end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end
    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}; ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true); $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each{|c|configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); end
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1]]
      ms=[]; TEST_ENEMIES.each_with_index do |c,i|; configure_enemy(c); m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=(i>=4); ms.push(m); end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability S v2.5.18 AutoRegression",ms)
    end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); else; a.clear; end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c); end
    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||TEST_SPEEDS[:r1]||[]
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_s,vals[i]) if b}
    end
    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end
    def self.clear_round_states
      (test_allies+all_enemies).each do |b|
        next if b==nil || b.hp.to_i<=0
        b.recover_all if b.respond_to?(:recover_all)
        b.cg_reset_stat_stages if b.respond_to?(:cg_reset_stat_stages)
      end
    rescue
    end
    def self.set_test_field(weather,terrain)
      st=field_state; return false if st==nil
      st.weather=weather; st.weather_turns=(weather==nil ? 0 : FIELD_TURNS)
      st.terrain=terrain; st.terrain_turns=(terrain==nil ? 0 : FIELD_TURNS)
      true
    rescue
      false
    end
    def self.prepare_round_preconditions
      clear_round_states; apply_test_speeds
      if current_round==1
        set_test_field(:sandstorm,:electric)
      elsif current_round==2
        set_test_field(nil,:grassy)
        e=all_enemies; e[0].cg_def_stat if e[0] && e[0].respond_to?(:cg_def_stat)
        @r2_storage_before=storage_size
        @r2_evasion_before={}
        test_allies.each{|b|@r2_evasion_before[battler_token(b)]=b.cg_stat_stage(:evasion).to_i if b&&b.respond_to?(:cg_stat_stage)}
      elsif current_round==3
        set_test_field(:hail,:electric)
        a=test_allies; e=all_enemies
        a[2].cg_spe if a[2] && a[2].respond_to?(:cg_spe)
        e[1].cg_spe if e[1] && e[1].respond_to?(:cg_spe)
      end
    end
    def self.prepare_round_actions
      p=current_plan; return false if p==nil; prepare_round_preconditions; @actual=[]; log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s)
      test_allies.each_with_index do |b,i|; next if b==nil||b.hp.to_i<=0; a=make_action(b,p[:allies][i]); if b.respond_to?(:cg_round_actions); b.cg_round_actions.clear; b.cg_round_actions.push(a); end; b.cg_assign_action(a) if b.respond_to?(:cg_assign_action); b.instance_variable_set(:@action,a) unless b.respond_to?(:cg_assign_action); end; true
    end
    def self.record_execution(b)
      return unless active?&&b; a=b.action; pre=b.actor? ? "A" : "E"; tok=if a&&a.guard?; pre+b.index.to_s+":Guard" elsif a&&a.skill?; pre+b.index.to_s+":M"+ALBERT_CG::MOVE_EFFECT.move_id(a.skill).to_i.to_s else; pre+b.index.to_s+":Other" end; @actual.push(tok); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    rescue
    end
    def self.records_for(aid,kind=nil)
      a=@records[aid]||[]; a.select{|r|kind==nil||r[:kind]==kind}
    end
    def self.record_ratio_ok?(aid,kind,num,den,move_id=nil)
      records_for(aid,kind).any? do |r|
        ok=r[:before].to_i>0 && r[:after].to_i==ratio(r[:before],num,den)
        ok=ok && r[:move_id].to_i==move_id.to_i if move_id!=nil
        ok
      end
    end

    def self.probe_entry_stats_and_residual
      a=test_allies; e=all_enemies; st=field_state
      sun_ok=st!=nil && st.weather==:sun && st.weather_turns.to_i==FIELD_TURNS
      @entry_checks+=1 if sun_ok; assert_true("Orichalcum Pulse entry establishes Sun",sun_ok,"weather="+(st ? st.weather.to_s : "nil")+" turns="+(st ? st.weather_turns.to_i.to_s : "nil"))
      elec_ok=st!=nil && st.terrain==:electric && st.terrain_turns.to_i==FIELD_TURNS
      @entry_checks+=1 if elec_ok; assert_true("Hadron Engine entry establishes Electric Terrain",elec_ok,"terrain="+(st ? st.terrain.to_s : "nil")+" turns="+(st ? st.terrain_turns.to_i.to_s : "nil"))
      e[2].cg_atk_stat if e[2] && e[2].respond_to?(:cg_atk_stat)
      e[3].cg_spa if e[3] && e[3].respond_to?(:cg_spa)
      o=record_ratio_ok?(ABILITY_ORICHALCUM_PULSE,:orichalcum_atk,ENGINE_NUM,ENGINE_DEN)
      @stat_checks+=1 if o; assert_true("Orichalcum Pulse raises ATK x4/3 in Sun",o,(records_for(ABILITY_ORICHALCUM_PULSE,:orichalcum_atk)[-1]||{}).inspect)
      h=record_ratio_ok?(ABILITY_HADRON_ENGINE,:hadron_spa,ENGINE_NUM,ENGINE_DEN)
      @stat_checks+=1 if h; assert_true("Hadron Engine raises SPA x4/3 in Electric Terrain",h,(records_for(ABILITY_HADRON_ENGINE,:hadron_spa)[-1]||{}).inspect)

      if field && st && a[1]
        old_w=st.weather; old_wt=st.weather_turns.to_i; old_t=st.terrain; old_tt=st.terrain_turns.to_i
        hp={}; (test_allies+all_enemies).each{|b|hp[b.object_id]=b.hp.to_i if b}
        st.weather=:sandstorm; st.weather_turns=FIELD_TURNS
        before=a[1].hp.to_i; field.apply_weather_residual; after=a[1].hp.to_i
        ok=before==after
        @residual_checks+=1 if ok; assert_true("Sand Force ignores Sandstorm residual damage",ok,"before="+before.to_s+" after="+after.to_s)
        (test_allies+all_enemies).each{|b|if b&&hp.has_key?(b.object_id); b.hp=hp[b.object_id]; b.hp_damage=0 if b.respond_to?(:hp_damage=); end}
        st.weather=old_w; st.weather_turns=old_wt; st.terrain=old_t; st.terrain_turns=old_tt
      end
    rescue=>e
      assert_true("Entry stat/residual probe completes",false,e.class.to_s+":"+e.message.to_s)
    end

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      tid=($game_troop&&$game_troop.troop) ? $game_troop.troop.id.to_i : 0; ids=core ? core.registered_ability_ids : []
      assert_true("Ability Catalog count=373",core&&core.catalog_count==373,"actual="+(core ? core.catalog_count.to_s : "nil"))
      assert_true("Ability Batch S registers 8 IDs",HANDLED_ABILITY_IDS.all?{|id|ids.include?(id)})
      assert_true("Scene_Battle uses Ability S test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability S ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability S starts with 4 active enemies",all_enemies.select{|b|b&&!b.hidden}.size==4)
      assert_true("Ability S starts with 1 hidden Supersweet Syrup reserve",all_enemies.select{|b|b&&b.hidden}.size==1)
      probe_entry_stats_and_residual
    end

    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==exp,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        sf=record_ratio_ok?(ABILITY_SAND_FORCE,:sand_force,SAND_FORCE_PERCENT,100,88)
        @damage_checks+=1 if sf; assert_true("Sand Force raises Rock damage x1.30 in Sandstorm",sf,(records_for(ABILITY_SAND_FORCE,:sand_force)[-1]||{}).inspect)
        rp=record_ratio_ok?(ABILITY_ROCKY_PAYLOAD,:rocky_payload,ROCKY_PAYLOAD_PERCENT,100,88)
        @damage_checks+=1 if rp; assert_true("Rocky Payload raises Rock damage x1.50",rp,(records_for(ABILITY_ROCKY_PAYLOAD,:rocky_payload)[-1]||{}).inspect)
      elsif r==2
        gp=record_ratio_ok?(ABILITY_GRASS_PELT,:grass_pelt,GRASS_PELT_PERCENT,100)
        @stat_checks+=1 if gp; assert_true("Grass Pelt raises DEF x1.50 on Grassy Terrain",gp,(records_for(ABILITY_GRASS_PELT,:grass_pelt)[-1]||{}).inspect)
        sw=e[3]&&e[4]&&e[3].hidden&&!e[4].hidden; @lifecycle_checks+=1 if sw; assert_true("Teleport deploys hidden Supersweet Syrup reserve",sw,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        syrup=records_for(ABILITY_SUPERSWEET_SYRUP,:entry)[-1]
        stages_ok=test_allies.all?{|b|b&&b.respond_to?(:cg_stat_stage)&&b.cg_stat_stage(:evasion).to_i==-1}
        @entry_checks+=1 if syrup!=nil&&stages_ok
        assert_true("Supersweet Syrup lowers all active opposing battlers Evasion -1 on first entry",syrup!=nil&&stages_ok,"record="+(syrup||{}).inspect+" stages="+test_allies.map{|b|b ? battler_token(b)+":"+b.cg_stat_stage(:evasion).to_i.to_s : "nil"}.join("|"))
        sa=storage_size; stor=sa==@r2_storage_before.to_i; @lifecycle_checks+=1 if stor; assert_true("Supersweet reserve switch does not consume Storage Pokemon",stor,"before="+@r2_storage_before.to_s+" after="+sa.to_s)
      elsif r==3
        sr=record_ratio_ok?(ABILITY_SLUSH_RUSH,:slush_rush,SLUSH_RUSH_PERCENT,100)
        @stat_checks+=1 if sr; assert_true("Slush Rush doubles SPE in Hail/Snow authority",sr,(records_for(ABILITY_SLUSH_RUSH,:slush_rush)[-1]||{}).inspect)
        ss=record_ratio_ok?(ABILITY_SURGE_SURFER,:surge_surfer,SURGE_SURFER_PERCENT,100)
        @stat_checks+=1 if ss; assert_true("Surge Surfer doubles SPE on Electric Terrain",ss,(records_for(ABILITY_SURGE_SURFER,:surge_surfer)[-1]||{}).inspect)
        stable=e[4]&&!e[4].hidden&&e[4].hp.to_i>0; assert_true("Supersweet Syrup reserve remains active through Round3",stable,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" hp="+(e[4] ? e[4].hp.to_i.to_s : "nil"))
        once=records_for(ABILITY_SUPERSWEET_SYRUP,:entry).size==1; assert_true("Supersweet Syrup entry effect remains once-per-battle",once,"trigger_records="+records_for(ABILITY_SUPERSWEET_SYRUP,:entry).size.to_s)
      end
      log("ROUND "+r.to_s+" END")
    end
    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_s,nil) if b}; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"; log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_s="+ability_covered_count.to_s+"/8 entry_checks="+@entry_checks.to_i.to_s+" stat_checks="+@stat_checks.to_i.to_s+" damage_checks="+@damage_checks.to_i.to_s+" residual_checks="+@residual_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=221")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @entry_checks=0; @stat_checks=0; @damage_checks=0; @residual_checks=0; @lifecycle_checks=0; @r2_storage_before=0; @r2_evasion_before={}
    end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; ALBERT_CG::UNIQUE_I_V242.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_I_V242)&&ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes); @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_S_v2.5.18") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

ALBERT_CG::ABILITY_S_V2518.register_handlers if defined?(ALBERT_CG::ABILITY_V250)
if defined?(ALBERT_CG::ABILITY_R_V2517)
  module ALBERT_CG; module ABILITY_R_V2517; def self.f11_trigger?; false; end; end; end
end

#==============================================================================
# ■ Formal Sand Force Sandstorm residual guard
#==============================================================================
if defined?(ALBERT_CG::FIELD_V233)
  module ALBERT_CG
    module FIELD_V233
      class << self
        alias cg_v2518s_apply_weather_residual apply_weather_residual
        def apply_weather_residual
          st=state
          return cg_v2518s_apply_weather_residual unless st && st.weather==:sandstorm && st.weather_turns.to_i>0
          list=[]
          list.concat($game_party.members) if defined?($game_party)&&$game_party!=nil
          list.concat($game_troop.members) if defined?($game_troop)&&$game_troop!=nil
          list.each do |b|
            next if b==nil || !b.respond_to?(:hp) || b.hp.to_i<=0
            if defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.ability_id(b).to_i==ALBERT_CG::ABILITY_S_V2518::ABILITY_SAND_FORCE
              ALBERT_CG::ABILITY_S_V2518.note_residual_guard(b)
              next
            end
            types=b.respond_to?(:cg_pokemon_types) ? b.cg_pokemon_types : []
            next if types.include?(:rock)||types.include?(:ground)||types.include?(:steel)
            dmg=[[b.maxhp.to_i/16,1].max,b.hp.to_i].min
            if dmg>0
              b.hp-=dmg; b.hp_damage=dmg if b.respond_to?(:hp_damage=)
              log("FIELD_WEATHER_TICK battler="+b.name.to_s+" weather=sandstorm damage="+dmg.to_s)
            end
          end
          nil
        end
      end
    end
  end
end

#==============================================================================
# ■ TEST-only deterministic Scene_Battle harness
#==============================================================================
class Game_Battler
  alias cg_v2518s_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil); return 100 if defined?(ALBERT_CG::ABILITY_S_V2518)&&ALBERT_CG::ABILITY_S_V2518.active?; cg_v2518s_ability_calc_hit(user,obj); end
  alias cg_v2518s_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil); return 0 if defined?(ALBERT_CG::ABILITY_S_V2518)&&ALBERT_CG::ABILITY_S_V2518.active?; cg_v2518s_ability_calc_eva(user,obj); end
  alias cg_v2518s_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_S_V2518)&&ALBERT_CG::ABILITY_S_V2518.active?
      v=@cg_priority_test_speed_override_s; return v.to_i if v!=nil
    end
    cg_v2518s_ability_priority_base_speed
  rescue
    cg_v2518s_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2518s_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_S_V2518)&&ALBERT_CG::ABILITY_S_V2518.active?
      a=ALBERT_CG::ABILITY_S_V2518.forced_enemy_action(self)
      if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end
    end
    cg_v2518s_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2518s_ability_execute_action execute_action
  def execute_action
    b=@active_battler; ALBERT_CG::ABILITY_S_V2518.record_execution(b) if defined?(ALBERT_CG::ABILITY_S_V2518)&&ALBERT_CG::ABILITY_S_V2518.active?; cg_v2518s_ability_execute_action
  end
  alias cg_v2518s_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_S_V2518)&&ALBERT_CG::ABILITY_S_V2518.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_S_V2518.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_S_V2518.finish_round_assertions; end
    end
    cg_v2518s_ability_turn_end
  end
  alias cg_v2518s_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_S_V2518)&&ALBERT_CG::ABILITY_S_V2518.active?; return cg_v2518s_ability_start_party_command; end
    cg_v2518s_ability_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_S_V2518.assert_bootstrap_once
    if ALBERT_CG::ABILITY_S_V2518.finished?; ALBERT_CG::ABILITY_S_V2518.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_S_V2518.prepare_round_actions; start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2518s_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2518s_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_S_V2518)&&ALBERT_CG::ABILITY_S_V2518.active?
        ALBERT_CG::ABILITY_S_V2518::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_S_V2518.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_S_V2518::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2518s_ability_scene_map_update update
  def update; cg_v2518s_ability_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_S_V2518); ALBERT_CG::ABILITY_S_V2518.start_auto_test if ALBERT_CG::ABILITY_S_V2518.f11_trigger?; end
end
