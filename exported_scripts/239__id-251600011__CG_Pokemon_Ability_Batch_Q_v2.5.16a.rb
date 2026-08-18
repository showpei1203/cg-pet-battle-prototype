# RMVX_SCRIPT_INDEX: 239
# RMVX_SCRIPT_ID: 251600011
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch Q v2.5.16a
# RMVX_SOURCE_SHA256: c5c3abbc579deff6eb00411e30bf6d5e021518bbe1598fd35db990d857e66ed8

#==============================================================================
# ■ CG Pokemon Ability Batch Q v2.5.16a - Hospitality Regression Assertion Fix
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.15a Ability Batch P RPG Maker VX 實機 PASS 基底上，正式實作第十七批
#  8 個 Ability。本批集中處理「登場建立 Terrain、受擊建立 Terrain、登場清除／複製
#  隊友能力階級、登場治療隊友」，沿用既有 Ability Runtime Core v2.5.0 的
#  :entry / :after_hit / :terrain_changed lifecycle，以及 Field Move Core v2.3.3a
#  的唯一 Terrain state，不另建平行場地狀態。
#
# 【本批 Ability】
#  226 Electric Surge   電氣製造者：entry 時建立 Electric Terrain 5 回合。
#  227 Psychic Surge    精神製造者：entry 時建立 Psychic Terrain 5 回合。
#  228 Misty Surge      薄霧製造者：entry 時建立 Misty Terrain 5 回合。
#  229 Grassy Surge     青草製造者：entry 時建立 Grassy Terrain 5 回合。
#  261 Curious Medicine 怪藥：entry 時清除其他 active 隊友的能力階級變化。
#  269 Seed Sower       掉出種子：受到直接傷害後建立 Grassy Terrain 5 回合。
#  294 Costar           同台共演：entry 時複製一名 active 隊友的能力階級變化。
#  301 Hospitality      款待：entry 時治療一名 active 隊友 1/4 MaxHP。
#
# 【v2.5.16a Regression 修正】
#  v2.5.16 實機已證明 Hospitality 正式 Runtime 確實將唯一受傷 ally A1 由 96 治療至
#  144（+48 = MaxHP/4）。FAIL 原因是 TEST note_local 為避免記錄 battler/target 物件，
#  會過濾 :target key，但 bootstrap assertion 卻又讀取 hrec[:target] == "A1"。
#  本版只改 TEST assertion：直接以 fixture 的 A1 pre-entry HP、MaxHP/4 與實際 A1 HP
#  驗證 Hospitality；Formal apply_hospitality handler、目標選擇與治療公式完全不變。
#
# 【主要設定項】
#  TEST_TROOP_ID = 719；HANDLED_ABILITY_IDS = 8。
#  Coverage：128/373 -> 136/373，pending 245 -> 237。
#  TERRAIN_TURNS 優先讀 Field Move Core 的 TERRAIN_DURATION，否則回退 5。
#
# 【機制規則】
#  1. 四種 Surge 與 Seed Sower 直接寫入既有 ALBERT_CG::FIELD_V233.state.terrain /
#     terrain_turns，並呼叫 Ability Core notify_terrain_changed；Move 與 Ability 因此共用
#     同一 Terrain Authority，禁止另外維護 @ability_terrain。
#  2. Entry Surge 每次正式 entry 都重設對應 Terrain 回合數；多個 Entry Ability 同時
#     發動時依既有 Ability Core Effective SPE entry order 決定最後覆蓋者。
#  3. Seed Sower 僅在 after_hit context 的 damage_done > 0 時發動；miss、immune、0 傷害
#     不建立 Terrain。
#  4. Curious Medicine 只清除「其他 active、存活、非 hidden 隊友」的 7 項 stage：
#     ATK/DEF/SPA/SPD/SPE/Accuracy/Evasion；不清除自己，也不碰永久六維資料。
#  5. Costar 因本專案正式戰場為 1 Human + 3 Pokémon，同側可能有多名隊友；為保留
#     原作「複製一名 ally」語意，選擇 stage 絕對值總和最大的 active 隊友；同分時
#     依 battler index 小者優先。複製仍透過 cg_change_stat_stage，不直接改永久資料。
#  6. Hospitality 同樣在多隊友戰場採單一目標：選 HP 比例最低的 active 隊友；同率時
#     index 小者優先，回復 maxhp/4（至少 1），不超過 MaxHP。
#  7. 有效 Ability 一律由 cg_master_ability_id 判定，尊重既有 Override/Suppression。
#  8. Formal handler 不改 Move 937/937、Field move 規則、Storage 或一般換寵規則。
#  9. F11 Regression 只固定 hit/evasion/SPE、前置 HP/stage/terrain 與行動目標；
#     正式玩家戰鬥 RNG 不受影響。
# 10. TEST Convenience 只限 F11。正式 Release 必須恢復 emerged、BGM/BGS、正常焦點。
#
# 【可調參數】
#  HOSPITALITY_HEAL_DIVISOR = 4。
#  STAGE_KEYS = [:atk,:def,:spa,:spd,:spe,:accuracy,:evasion]。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫；Ability 由 lifecycle 自動觸發。
#  開發測試：地圖按 F11，自動進 Actual Scene_Battle，跑三回合並輸出
#  Pokemon_Ability_Q_AutoTest_v2_5_16a.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  battle start：Electric -> Psychic -> Misty -> Grassy Surge 依 entry order 依序覆蓋；
#  Curious Medicine 清除隊友 +2 ATK；Hospitality 治療受傷隊友；
#  Round2 Tackle 命中 Seed Sower holder -> Grassy Terrain；Teleport 換入 Costar reserve，
#  Costar 複製同側 +2 ATK/-1 DEF；Round3 驗證 reserve 與 PMD lifecycle 穩定。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchQ"] = "2.5.16a"

module ALBERT_CG
  module ABILITY_Q_V2516
    VERSION = "2.5.16a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 719
    VK_F11 = 0x7A

    ABILITY_ELECTRIC_SURGE   = 226
    ABILITY_PSYCHIC_SURGE    = 227
    ABILITY_MISTY_SURGE      = 228
    ABILITY_GRASSY_SURGE     = 229
    ABILITY_CURIOUS_MEDICINE = 261
    ABILITY_SEED_SOWER       = 269
    ABILITY_COSTAR           = 294
    ABILITY_HOSPITALITY      = 301
    HANDLED_ABILITY_IDS = [226,227,228,229,261,269,294,301]

    HOSPITALITY_HEAL_DIVISOR = 4
    STAGE_KEYS = [:atk,:def,:spa,:spd,:spe,:accuracy,:evasion]

    TEST_ALLIES = [
      {:dex=>25, :level=>40,:ability=>ABILITY_ELECTRIC_SURGE,   :moves=>[150,33,150,150]},
      {:dex=>65, :level=>40,:ability=>ABILITY_CURIOUS_MEDICINE, :moves=>[150,150,150,150]},
      {:dex=>128,:level=>40,:ability=>ABILITY_HOSPITALITY,      :moves=>[150,150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>40,:ability=>ABILITY_PSYCHIC_SURGE,:moves=>[150,150,150,150]},
      {:dex=>94, :level=>40,:ability=>ABILITY_MISTY_SURGE,  :moves=>[150,150,150,150]},
      {:dex=>91, :level=>40,:ability=>ABILITY_GRASSY_SURGE, :moves=>[150,150,150,150]},
      {:dex=>109,:level=>40,:ability=>ABILITY_SEED_SOWER,   :moves=>[150,100,150,150]},
      {:dex=>197,:level=>40,:ability=>ABILITY_COSTAR,        :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {:name=>"ENTRY_TERRAIN_AND_SUPPORT",
       :allies=>[{:kind=>:guard},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},2=>{:kind=>:move,:move_id=>150,:target=>2},3=>{:kind=>:move,:move_id=>150,:target=>2}}},
      {:name=>"SEED_SOWER_AND_COSTAR_SWITCH",
       :allies=>[{:kind=>:guard},{:kind=>:move,:move_id=>33,:target=>3},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},2=>{:kind=>:move,:move_id=>150,:target=>2},3=>{:kind=>:move,:move_id=>100,:target=>0}}},
      {:name=>"COSTAR_RESERVE_STABILITY",
       :allies=>[{:kind=>:guard},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},2=>{:kind=>:move,:move_id=>150,:target=>2},4=>{:kind=>:move,:move_id=>150,:target=>2}}},
    ]

    TEST_SPEEDS = {
      :r1=>[10,400,180,160, 350,300,250,100,0],
      :r2=>[10,400,180,160, 350,300,250,100,0],
      :r3=>[10,400,180,160, 350,300,250,0,100],
    }
    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M150","E0:M150","E1:M150","E2:M150","A2:M150","A3:M150","E3:M150"],
      2=>["A0:Guard","A1:M33","E0:M150","E1:M150","E2:M150","A2:M150","A3:M150","E3:M100"],
      3=>["A0:Guard","A1:M150","E0:M150","E1:M150","E2:M150","A2:M150","A3:M150","E4:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.field; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233 : nil; end
    def self.active?; @active == true; end
    def self.current_round; @round_index.to_i + 1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i >= ROUND_PLANS.size; end
    def self.test_allies; $game_party == nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop == nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_Q_AutoTest_v2_5_16a.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end

    def self.write_line(path,text,mode="ab")
      File.open(path,mode) { |f| f.write(text.to_s + "\r\n") }; true
    rescue
      false
    end
    def self.log(text)
      write_line(log_path,text.to_s); write_line(latest_log_path,text.to_s)
    rescue
    end
    def self.reset_log
      h="CG POKEMON ABILITY Q TERRAIN ENTRY + ALLY SUPPORT AUTO REGRESSION v2.5.16a\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; terrain entry/after-hit + ally support entry lifecycle\r\n"+
        "BASELINE=v2.5.15a Ability Batch P Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_P_PASS=128 BATCH_Q=8 PENDING=237\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb") { |f| f.write(h) }; File.open(latest_log_path,"wb") { |f| f.write(h) }
    rescue
    end
    def self.key_down?(code); KEY_API != nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d && @f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else
        text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text)
      end
      condition
    end

    def self.terrain_turns
      return ALBERT_CG::FIELD_V233::TERRAIN_DURATION.to_i if defined?(ALBERT_CG::FIELD_V233::TERRAIN_DURATION)
      return 5
    rescue
      return 5
    end

    def self.note_local(aid,battler,kind,data=nil)
      return true unless active?
      @ability_trigger_counts[aid]=@ability_trigger_counts[aid].to_i+1
      rec={:kind=>kind,:ability=>aid}
      (data||{}).each { |k,v| rec[k]=v unless k==:battler || k==:user || k==:target || k==:skill }
      @records[aid]=rec
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k| k.to_s+"="+rec[k].to_s}
      log("ABILITY_Q_TRIGGER ability="+aid.to_s+" battler="+(battler==nil ? "nil" : battler.name.to_s)+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
      true
    rescue
      false
    end

    def self.set_terrain(battler,aid,key,kind)
      f=field; return false if f==nil || !f.respond_to?(:state)
      st=f.state; before=st.terrain; before_turns=st.terrain_turns.to_i
      st.terrain=key; st.terrain_turns=terrain_turns
      begin
        f.log("ABILITY_Q_TERRAIN ability="+aid.to_s+" battler="+battler.name.to_s+" before="+before.to_s+" terrain="+key.to_s+" turns="+st.terrain_turns.to_s)
      rescue
      end
      core.notify_terrain_changed(battler) if core && core.respond_to?(:notify_terrain_changed)
      note_local(aid,battler,kind,{:before=>before,:before_turns=>before_turns,:terrain=>key,:turns=>st.terrain_turns.to_i})
      true
    rescue
      false
    end

    def self.apply_electric_surge(b,ctx); set_terrain(b,ABILITY_ELECTRIC_SURGE,:electric,:entry); end
    def self.apply_psychic_surge(b,ctx);  set_terrain(b,ABILITY_PSYCHIC_SURGE,:psychic,:entry); end
    def self.apply_misty_surge(b,ctx);    set_terrain(b,ABILITY_MISTY_SURGE,:misty,:entry); end
    def self.apply_grassy_surge(b,ctx);   set_terrain(b,ABILITY_GRASSY_SURGE,:grassy,:entry); end

    def self.stage_snapshot(b)
      h={}; STAGE_KEYS.each { |k| h[k]=b.respond_to?(:cg_stat_stage) ? b.cg_stat_stage(k).to_i : 0 }; h
    rescue
      {}
    end
    def self.stage_score(b)
      s=0; stage_snapshot(b).each_value { |v| s+=v.to_i.abs }; s
    rescue
      0
    end
    def self.active_allies(b)
      list=core ? core.allies_of(b) : []
      list.select { |x| x!=nil && !x.equal?(b) && !x.hidden && x.hp.to_i>0 }
    rescue
      []
    end

    def self.apply_curious_medicine(b,ctx)
      changed=[]
      active_allies(b).each do |ally|
        before=stage_snapshot(ally)
        next unless before.values.any? { |v| v.to_i!=0 }
        ally.cg_reset_stat_stages if ally.respond_to?(:cg_reset_stat_stages)
        changed.push((ally.actor? ? "A" : "E")+ally.index.to_s+":"+before.inspect)
      end
      return false if changed.empty?
      note_local(ABILITY_CURIOUS_MEDICINE,b,:entry,{:changed=>changed.join("|")})
      true
    rescue
      false
    end

    def self.apply_seed_sower(b,ctx)
      return false if ctx[:damage_done].to_i<=0
      set_terrain(b,ABILITY_SEED_SOWER,:grassy,:after_hit)
    end

    def self.apply_costar(b,ctx)
      allies=active_allies(b); return false if allies.empty?
      source=allies.sort_by { |x| [-stage_score(x),x.index.to_i] }[0]
      return false if source==nil || stage_score(source)<=0
      desired=stage_snapshot(source); before=stage_snapshot(b)
      STAGE_KEYS.each do |k|
        now=b.cg_stat_stage(k).to_i
        delta=desired[k].to_i-now
        b.cg_change_stat_stage(k,delta) if delta!=0 && b.respond_to?(:cg_change_stat_stage)
      end
      after=stage_snapshot(b)
      note_local(ABILITY_COSTAR,b,:entry,{:source=>(source.actor? ? "A" : "E")+source.index.to_s,:before=>before.inspect,:after=>after.inspect})
      true
    rescue
      false
    end

    def self.hp_ratio_key(b)
      mh=[b.maxhp.to_i,1].max
      [(b.hp.to_i*100000)/mh,b.index.to_i]
    rescue
      [100000,999]
    end
    def self.apply_hospitality(b,ctx)
      allies=active_allies(b).select { |x| x.hp.to_i<x.maxhp.to_i }
      return false if allies.empty?
      target=allies.sort_by { |x| hp_ratio_key(x) }[0]
      before=target.hp.to_i; heal=[target.maxhp.to_i/HOSPITALITY_HEAL_DIVISOR,1].max
      target.hp=[target.maxhp.to_i,before+heal].min
      after=target.hp.to_i; return false if after<=before
      note_local(ABILITY_HOSPITALITY,b,:entry,{:target=>(target.actor? ? "A" : "E")+target.index.to_s,:before=>before,:after=>after,:heal=>after-before})
      true
    rescue
      false
    end

    def self.register_handlers
      c=core; return false if c==nil
      c.register(ABILITY_ELECTRIC_SURGE,:entry,self,:apply_electric_surge)
      c.register(ABILITY_PSYCHIC_SURGE,:entry,self,:apply_psychic_surge)
      c.register(ABILITY_MISTY_SURGE,:entry,self,:apply_misty_surge)
      c.register(ABILITY_GRASSY_SURGE,:entry,self,:apply_grassy_surge)
      c.register(ABILITY_CURIOUS_MEDICINE,:entry,self,:apply_curious_medicine)
      c.register(ABILITY_SEED_SOWER,:after_hit,self,:apply_seed_sower)
      c.register(ABILITY_COSTAR,:entry,self,:apply_costar)
      c.register(ABILITY_HOSPITALITY,:entry,self,:apply_hospitality)
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
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability Q v2.5.16a AutoRegression",ms)
    end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); else; a.clear; end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active? && e && !e.hidden && e.hp.to_i>0; c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c); end
    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||TEST_SPEEDS[:r1]||[]
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_q,vals[i]) if b}
    end
    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end

    def self.install_entry_test_preconditions
      return true unless active?
      apply_test_speeds
      a=test_allies
      if a[1]
        a[1].recover_all if a[1].respond_to?(:recover_all)
        a[1].cg_reset_stat_stages if a[1].respond_to?(:cg_reset_stat_stages)
        a[1].cg_change_stat_stage(:atk,2) if a[1].respond_to?(:cg_change_stat_stage)
        a[1].hp=[a[1].maxhp.to_i/2,1].max
        @entry_hospitality_before=a[1].hp.to_i
      end
      @entry_curious_before=a[1] ? a[1].cg_stat_stage(:atk).to_i : 0
      true
    rescue=>e
      log("ENTRY_PRECONDITION_ERROR "+e.class.to_s+":"+e.message.to_s); false
    end

    def self.prepare_round_preconditions
      if current_round==2
        f=field
        if f
          f.state.terrain=:electric; f.state.terrain_turns=2
          log("FIXTURE terrain=electric turns=2 before Seed Sower")
        end
        e=all_enemies
        if e[2]
          e[2].cg_reset_stat_stages if e[2].respond_to?(:cg_reset_stat_stages)
          e[2].cg_change_stat_stage(:atk,2) if e[2].respond_to?(:cg_change_stat_stage)
          e[2].cg_change_stat_stage(:def,-1) if e[2].respond_to?(:cg_change_stat_stage)
          @costar_source_expected=stage_snapshot(e[2])
        end
        @r2_storage_before=storage_size
      end
    end
    def self.prepare_round_actions
      p=current_plan; return false if p==nil; apply_test_speeds; prepare_round_preconditions; @actual=[]; log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s)
      test_allies.each_with_index do |b,i|; next if b==nil || b.hp.to_i<=0; a=make_action(b,p[:allies][i]); if b.respond_to?(:cg_round_actions); b.cg_round_actions.clear; b.cg_round_actions.push(a); end; b.cg_assign_action(a) if b.respond_to?(:cg_assign_action); b.instance_variable_set(:@action,a) unless b.respond_to?(:cg_assign_action); end; true
    end
    def self.record_execution(b)
      return unless active?&&b; a=b.action; pre=b.actor? ? "A" : "E"; tok= if a&&a.guard?; pre+b.index.to_s+":Guard" elsif a&&a.skill?; pre+b.index.to_s+":M"+ALBERT_CG::MOVE_EFFECT.move_id(a.skill).to_i.to_s else; pre+b.index.to_s+":Other" end; @actual.push(tok); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    rescue
    end

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      tid=($game_troop&&$game_troop.troop) ? $game_troop.troop.id.to_i : 0; ids=core ? core.registered_ability_ids : []
      assert_true("Ability Catalog count=373",core&&core.catalog_count==373,"actual="+(core ? core.catalog_count.to_s : "nil"))
      assert_true("Ability Batch Q registers 8 IDs",HANDLED_ABILITY_IDS.all?{|id|ids.include?(id)})
      assert_true("Scene_Battle uses Ability Q test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability Q ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability Q starts with 4 active enemies",all_enemies.select{|b|b&&!b.hidden}.size==4)
      assert_true("Ability Q starts with 1 hidden Costar reserve",all_enemies.select{|b|b&&b.hidden}.size==1)

      expected_terrain={ABILITY_ELECTRIC_SURGE=>:electric,ABILITY_PSYCHIC_SURGE=>:psychic,ABILITY_MISTY_SURGE=>:misty,ABILITY_GRASSY_SURGE=>:grassy}
      expected_terrain.each do |aid,key|
        rec=@records[aid]; ok=rec&&rec[:terrain]==key&&rec[:turns].to_i==terrain_turns
        @entry_checks+=1 if ok; @terrain_checks+=1 if ok
        assert_true("Entry Terrain ability "+aid.to_s+" establishes "+key.to_s,ok,rec ? rec.inspect : "record=nil")
      end
      final_grassy=field&&field.state.terrain==:grassy&&field.state.terrain_turns.to_i==terrain_turns
      assert_true("Entry Surge ordering leaves Grassy Terrain active",final_grassy,"terrain="+(field ? field.state.terrain.to_s : "nil")+" turns="+(field ? field.state.terrain_turns.to_i.to_s : "nil"))

      curious=test_allies[1]&&test_allies[1].cg_stat_stage(:atk).to_i==0
      @entry_checks+=1 if curious; @support_checks+=1 if curious
      assert_true("Curious Medicine clears ally pre-entry ATK stage",curious,"before="+@entry_curious_before.to_s+" after="+(test_allies[1] ? test_allies[1].cg_stat_stage(:atk).to_s : "nil"))
      hrec=@records[ABILITY_HOSPITALITY]; htarget=test_allies[1]
      hbefore=@entry_hospitality_before.to_i
      hheal=htarget ? [htarget.maxhp.to_i/HOSPITALITY_HEAL_DIVISOR,1].max : 0
      hafter=htarget ? [htarget.maxhp.to_i,hbefore+hheal].min : 0
      hosp=hrec&&htarget&&hrec[:before].to_i==hbefore&&hrec[:after].to_i==hafter&&hrec[:heal].to_i==(hafter-hbefore)&&htarget.hp.to_i==hafter
      @entry_checks+=1 if hosp; @support_checks+=1 if hosp
      assert_true("Hospitality heals fixture lowest-HP active ally A1 by entry",hosp,"expected_before="+hbefore.to_s+" expected_after="+hafter.to_s+" actual_hp="+(htarget ? htarget.hp.to_i.to_s : "nil")+" record="+(hrec ? hrec.inspect : "nil"))
    end

    def self.assert_round
      r=current_round; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==exp,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==2
        srec=@records[ABILITY_SEED_SOWER]; sok=srec&&srec[:terrain]==:grassy&&field&&field.state.terrain==:grassy
        @terrain_checks+=1 if sok; assert_true("Seed Sower changes Electric fixture to Grassy after direct damage",sok,srec ? srec.inspect : "record=nil")
        sw=e[3]&&e[4]&&e[3].hidden&&!e[4].hidden; @lifecycle_checks+=1 if sw; assert_true("Teleport deploys hidden Costar reserve",sw,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        crec=@records[ABILITY_COSTAR]; expected=@costar_source_expected||{}; actual=e[4] ? stage_snapshot(e[4]) : {}
        cok=crec&&expected==actual&&expected[:atk].to_i==2&&expected[:def].to_i==-1
        @entry_checks+=1 if cok; @support_checks+=1 if cok
        assert_true("Costar copies strongest active ally stage pattern on switch-in",cok,"expected="+expected.inspect+" actual="+actual.inspect+" record="+(crec ? crec.inspect : "nil"))
        sa=storage_size; stor=sa==@r2_storage_before.to_i; @lifecycle_checks+=1 if stor; assert_true("Costar reserve switch does not consume Storage Pokemon",stor,"before="+@r2_storage_before.to_s+" after="+sa.to_s)
      elsif r==3
        stable=e[4]&&!e[4].hidden&&e[4].hp.to_i>0
        assert_true("Costar reserve remains active through Round3",stable,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" hp="+(e[4] ? e[4].hp.to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end
    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_q,nil) if b}; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"; log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_q="+ability_covered_count.to_s+"/8 entry_checks="+@entry_checks.to_i.to_s+" terrain_checks="+@terrain_checks.to_i.to_s+" support_checks="+@support_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=237")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @entry_checks=0; @terrain_checks=0; @support_checks=0; @lifecycle_checks=0; @r2_storage_before=0; @entry_curious_before=0; @entry_hospitality_before=0; @costar_source_expected={}
    end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; ALBERT_CG::UNIQUE_I_V242.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_I_V242)&&ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes); @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_Q_v2.5.16a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

ALBERT_CG::ABILITY_Q_V2516.register_handlers if defined?(ALBERT_CG::ABILITY_V250)
if defined?(ALBERT_CG::ABILITY_P_V2515)
  module ALBERT_CG; module ABILITY_P_V2515; def self.f11_trigger?; false; end; end; end
end

# TEST-only：entry preconditions 必須在 Ability Core 真正 dispatch battle-start entries 前安裝。
if defined?(ALBERT_CG::ABILITY_V250)
  module ALBERT_CG
    module ABILITY_V250
      class << self
        alias cg_v2516q_trigger_battle_start_entries trigger_battle_start_entries
        def trigger_battle_start_entries
          if defined?(ALBERT_CG::ABILITY_Q_V2516) && ALBERT_CG::ABILITY_Q_V2516.active?
            ALBERT_CG::ABILITY_Q_V2516.install_entry_test_preconditions
          end
          cg_v2516q_trigger_battle_start_entries
        end
      end
    end
  end
end

class Game_Battler
  alias cg_v2516q_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil); return 100 if defined?(ALBERT_CG::ABILITY_Q_V2516)&&ALBERT_CG::ABILITY_Q_V2516.active?; cg_v2516q_ability_calc_hit(user,obj); end
  alias cg_v2516q_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil); return 0 if defined?(ALBERT_CG::ABILITY_Q_V2516)&&ALBERT_CG::ABILITY_Q_V2516.active?; cg_v2516q_ability_calc_eva(user,obj); end
  alias cg_v2516q_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_Q_V2516)&&ALBERT_CG::ABILITY_Q_V2516.active?
      v=@cg_priority_test_speed_override_q; return v.to_i if v!=nil
    end
    cg_v2516q_ability_priority_base_speed
  rescue
    cg_v2516q_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2516q_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_Q_V2516)&&ALBERT_CG::ABILITY_Q_V2516.active?
      a=ALBERT_CG::ABILITY_Q_V2516.forced_enemy_action(self)
      if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end
    end
    cg_v2516q_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2516q_ability_execute_action execute_action
  def execute_action
    b=@active_battler; ALBERT_CG::ABILITY_Q_V2516.record_execution(b) if defined?(ALBERT_CG::ABILITY_Q_V2516)&&ALBERT_CG::ABILITY_Q_V2516.active?; cg_v2516q_ability_execute_action
  end
  alias cg_v2516q_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_Q_V2516)&&ALBERT_CG::ABILITY_Q_V2516.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_Q_V2516.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_Q_V2516.finish_round_assertions; end
    end
    cg_v2516q_ability_turn_end
  end
  alias cg_v2516q_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_Q_V2516)&&ALBERT_CG::ABILITY_Q_V2516.active?; return cg_v2516q_ability_start_party_command; end
    cg_v2516q_ability_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_Q_V2516.assert_bootstrap_once
    if ALBERT_CG::ABILITY_Q_V2516.finished?; ALBERT_CG::ABILITY_Q_V2516.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_Q_V2516.prepare_round_actions; start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2516q_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2516q_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_Q_V2516)&&ALBERT_CG::ABILITY_Q_V2516.active?
        ALBERT_CG::ABILITY_Q_V2516::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_Q_V2516.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_Q_V2516::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2516q_ability_scene_map_update update
  def update; cg_v2516q_ability_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_Q_V2516); ALBERT_CG::ABILITY_Q_V2516.start_auto_test if ALBERT_CG::ABILITY_Q_V2516.f11_trigger?; end
end
