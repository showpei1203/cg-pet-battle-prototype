# RMVX_SCRIPT_INDEX: 238
# RMVX_SCRIPT_ID: 251500011
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch P v2.5.15a
# RMVX_SOURCE_SHA256: a7a8d36e2f4be3ab255867f2cf8478d12b4e2f91e610155a68d7ee39127ee610

#==============================================================================
# ■ CG Pokemon Ability Batch P v2.5.15a - Stat Momentum + KO Snowball
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.14a Ability Batch O RPG Maker VX 實機 PASS 基底上，正式實作第十六批
#  8 個 Ability。本批集中處理「登場能力提升、擊倒後能力提升、半血門檻能力重組、
#  受擊後全場速度反應」，全部沿用既有 Ability Core trigger 與
#  Stat Guard Source Context，不修改已封版 Move 937/937 Runtime。
#
# 【本批 Ability】
#  155 Rattled          膽怯：受到 Dark/Ghost/Bug 直接傷害後 SPE +1。
#  224 Beast Boost      異獸提升：自身擊倒目標後，五項非 HP 能力中最高者 stage +1。
#  234 Intrepid Sword   不撓之劍：每次正式 entry 時 ATK +1。
#  235 Dauntless Shield 不屈之盾：每次正式 entry 時 DEF +1。
#  238 Cotton Down      棉絮：自身受到直接傷害後，其他所有在場 battler SPE -1。
#  264 Chilling Neigh   蒼白嘶鳴：自身擊倒目標後 ATK +1。
#  265 Grim Neigh       漆黑嘶鳴：自身擊倒目標後 SPA +1。
#  271 Anger Shell      憤怒甲殼：一次直接傷害讓 HP 由 >1/2 跨到 <=1/2 時，
#                         ATK/SPA/SPE +1、DEF/SPD -1；每次跨線事件只觸發一次。
#
# 【主要設定項】
#  TEST_TROOP_ID = 718；HANDLED_ABILITY_IDS = 8。
#  Coverage：120/373 -> 128/373，pending 253 -> 245。
#
# 【機制規則】
#  1. Entry 類直接使用 Ability Core :entry，因此 battle start 與正式 switch-in 共用。
#  2. KO 類使用 :after_ko，只有真正由該 user 造成 HP>0 -> 0 的 KO 才觸發。
#  3. Beast Boost 比較當下正式 cg_atk_stat/cg_def_stat/cg_spa/cg_spd/cg_spe；同值時
#     依 ATK->DEF->SPA->SPD->SPE 固定順序，避免 Ruby Hash 版本差異造成不確定性。
#  4. Cotton Down 只影響目前 active、存活、非 hidden 的其他 battler；能力下降透過
#     v2.5.6 Stat Guard Source Context 標記來源 holder，因此 Clear Body/White Smoke 等
#     已 PASS 防護可正常攔截，不直接偷改 @cg_stat_stages。
#  5. Anger Shell 以本 hit 的 hp_before/hp_after 判斷跨越半血門檻，不會在已低於半血後
#     每挨一下重複提款。
#  6. Rattled 使用既有 Pokemon Combat type ID，只接受 Dark/Ghost/Bug 且 damage_done>0。
#  7. 所有 stage 變化都走 cg_change_stat_stage，尊重 -6..+6 clamp 與後續 Authority。
#  8. 有效 Ability 仍由 cg_master_ability_id 取得，尊重 Battle-only Override/Suppression。
#  9. Regression 只固定命中、速度、HP 前置與目標；正式玩家 RNG 不改。
# 10. TEST Convenience 只限 F11。正式 Release 必須恢復 emerged、BGM/BGS、正常焦點。
# 11. v2.5.15a Regression Fix：Round1 Chilling Neigh 測試原用 Normal Tackle 攻擊
#     Ghost 容器耿鬼，因屬性免疫無法造成 KO；改用 Bite，僅修 TEST fixture，
#     正式 Chilling Neigh handler 與其餘 Formal Runtime 完全不變。
#
# 【可調參數】
#  ENTRY_STAGE=1 / KO_STAGE=1 / RATTLED_SPE=1 /
#  ANGER_UP=1 / ANGER_DOWN=-1 / COTTON_SPE=-1。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫。開發測試：地圖按 F11，自動進 Actual Scene_Battle，
#  跑完三回合並輸出 Pokemon_Ability_P_AutoTest_v2_5_15a.log 與
#  CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  battle start -> Intrepid Sword / Dauntless Shield；
#  Alakazam KO -> Beast Boost highest stat；Tauros KO -> Chilling Neigh；
#  enemy KO -> Grim Neigh；Round2 Cotton Down + Anger Shell；
#  Teleport -> hidden Rattled reserve；Round3 Bite -> Rattled SPE+1。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchP"] = "2.5.15a"

module ALBERT_CG
  module ABILITY_P_V2515
    VERSION = "2.5.15a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 718
    VK_F11 = 0x7A

    ABILITY_RATTLED          = 155
    ABILITY_BEAST_BOOST      = 224
    ABILITY_INTREPID_SWORD   = 234
    ABILITY_DAUNTLESS_SHIELD = 235
    ABILITY_COTTON_DOWN      = 238
    ABILITY_CHILLING_NEIGH   = 264
    ABILITY_GRIM_NEIGH       = 265
    ABILITY_ANGER_SHELL      = 271
    HANDLED_ABILITY_IDS = [155,224,234,235,238,264,265,271]

    ENTRY_STAGE = 1
    KO_STAGE = 1
    RATTLED_SPE = 1
    COTTON_SPE = -1
    ANGER_UP = 1
    ANGER_DOWN = -1

    TEST_ALLIES = [
      {:dex=>303,:level=>40,:ability=>ABILITY_INTREPID_SWORD,:moves=>[150,150,150,150]},
      {:dex=>65, :level=>40,:ability=>ABILITY_BEAST_BOOST,   :moves=>[33,33,44,150]},
      {:dex=>128,:level=>40,:ability=>ABILITY_CHILLING_NEIGH,:moves=>[44,33,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>40,:ability=>ABILITY_DAUNTLESS_SHIELD,:moves=>[150,150,150,150]},
      {:dex=>94, :level=>40,:ability=>ABILITY_GRIM_NEIGH,      :moves=>[33,150,150,150]},
      {:dex=>91, :level=>40,:ability=>ABILITY_ANGER_SHELL,     :moves=>[150,150,150,150]},
      {:dex=>109,:level=>40,:ability=>ABILITY_COTTON_DOWN,     :moves=>[150,100,150,150]},
      {:dex=>197,:level=>40,:ability=>ABILITY_RATTLED,         :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {:name=>"ENTRY_AND_KO_MOMENTUM",
       :allies=>[{:kind=>:guard},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>33,:target=>0},{:kind=>:move,:move_id=>44,:target=>1}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>33,:target=>1},2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"COTTON_ANGER_AND_RATTLED_SWITCH",
       :allies=>[{:kind=>:guard},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>33,:target=>3},{:kind=>:move,:move_id=>33,:target=>2}],
       :enemies=>{2=>{:kind=>:move,:move_id=>150,:target=>2},3=>{:kind=>:move,:move_id=>100,:target=>0}}},
      {:name=>"RATTLED_DARK_HIT_STABILITY",
       :allies=>[{:kind=>:guard},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>44,:target=>4},{:kind=>:move,:move_id=>150,:target=>4}],
       :enemies=>{2=>{:kind=>:move,:move_id=>150,:target=>2},4=>{:kind=>:move,:move_id=>150,:target=>2}}},
    ]

    TEST_SPEEDS = {
      :r1=>[10,300,250,230, 100,280,180,160,0],
      :r2=>[10,0,300,290, 0,0,180,160,0],
      :r3=>[10,0,300,290, 0,0,180,0,200],
    }
    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M150","E1:M33","A2:M33","A3:M44","E2:M150","E3:M150"],
      2=>["A0:Guard","A2:M33","A3:M33","E2:M150","E3:M100"],
      3=>["A0:Guard","A2:M44","A3:M150","E4:M150","E2:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.active?; @active == true; end
    def self.current_round; @round_index.to_i + 1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i >= ROUND_PLANS.size; end
    def self.test_allies; $game_party == nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop == nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_P_AutoTest_v2_5_15a.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end

    def self.write_line(path,text,mode="ab")
      File.open(path,mode) { |f| f.write(text.to_s + "\r\n") }; true
    rescue; false; end
    def self.log(text)
      write_line(log_path,text.to_s); write_line(latest_log_path,text.to_s)
    rescue; end
    def self.reset_log
      h="CG POKEMON ABILITY P STAT MOMENTUM + KO SNOWBALL AUTO REGRESSION v2.5.15a\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; entry stat boosts + KO snowball + threshold/contact stat reactions\r\n"+
        "BASELINE=v2.5.14a Ability Batch O Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_O_PASS=120 BATCH_P=8 PENDING=245\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb") { |f| f.write(h) }; File.open(latest_log_path,"wb") { |f| f.write(h) }
    rescue; end
    def self.key_down?(code); KEY_API != nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d && @f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.assert_true(label,condition,detail=nil)
      if condition; log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else; text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text); end
      condition
    end
    def self.type_id(symbol)
      return 0 unless defined?(ALBERT_CG::POKEMON_COMBAT)
      t=ALBERT_CG::POKEMON_COMBAT::TYPE_IDS; t && t.has_key?(symbol) ? t[symbol].to_i : 0
    rescue; 0; end
    def self.skill_type_id(skill)
      return 0 if skill==nil
      if defined?(ALBERT_CG::POKEMON_COMBAT) && ALBERT_CG::POKEMON_COMBAT.respond_to?(:skill_type_id)
        return ALBERT_CG::POKEMON_COMBAT.skill_type_id(skill).to_i
      end
      skill.element_set && !skill.element_set.empty? ? skill.element_set[0].to_i : 0
    rescue; 0; end
    def self.note_trigger(aid,battler,kind,data=nil)
      @ability_trigger_counts[aid]=@ability_trigger_counts[aid].to_i+1
      rec={:kind=>kind,:ability=>aid}
      (data||{}).each { |k,v| rec[k]=v unless k==:battler || k==:user || k==:target || k==:skill }
      @records[aid]=rec
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k| k.to_s+"="+rec[k].to_s}
      log("ABILITY_P_TRIGGER ability="+aid.to_s+" battler="+(battler==nil ? "nil" : battler.name.to_s)+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
      true
    rescue; false; end

    def self.change_stage(source,target,key,amount)
      return 0 if target==nil || !target.respond_to?(:cg_change_stat_stage)
      auth=defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) ? ALBERT_CG::ABILITY_STAT_GUARD_V256 : nil
      if auth && auth.respond_to?(:with_stage_source)
        return auth.with_stage_source(source,:ability,false) { target.cg_change_stat_stage(key,amount).to_i }
      end
      target.cg_change_stat_stage(key,amount).to_i
    rescue; 0; end

    def self.apply_intrepid_sword(b,ctx)
      before=b.cg_stat_stage(:atk).to_i; d=change_stage(b,b,:atk,ENTRY_STAGE); after=b.cg_stat_stage(:atk).to_i
      return false if d==0
      note_trigger(ABILITY_INTREPID_SWORD,b,:entry,{:before=>before,:after=>after,:delta=>d}); true
    end
    def self.apply_dauntless_shield(b,ctx)
      before=b.cg_stat_stage(:def).to_i; d=change_stage(b,b,:def,ENTRY_STAGE); after=b.cg_stat_stage(:def).to_i
      return false if d==0
      note_trigger(ABILITY_DAUNTLESS_SHIELD,b,:entry,{:before=>before,:after=>after,:delta=>d}); true
    end
    def self.highest_stat_key(b)
      pairs=[[:atk,b.cg_atk_stat.to_i],[:def,b.cg_def_stat.to_i],[:spa,b.cg_spa.to_i],[:spd,b.cg_spd.to_i],[:spe,b.cg_spe.to_i]]
      best=pairs[0]; pairs.each { |p| best=p if p[1]>best[1] }; best[0]
    rescue; :atk; end
    def self.apply_beast_boost(b,ctx)
      return false if ctx[:target]==nil || ctx[:target].hp.to_i>0
      key=highest_stat_key(b); before=b.cg_stat_stage(key).to_i; d=change_stage(b,b,key,KO_STAGE); after=b.cg_stat_stage(key).to_i
      return false if d==0
      note_trigger(ABILITY_BEAST_BOOST,b,:after_ko,{:stat=>key,:before=>before,:after=>after,:delta=>d}); true
    end
    def self.apply_chilling_neigh(b,ctx)
      return false if ctx[:target]==nil || ctx[:target].hp.to_i>0
      before=b.cg_stat_stage(:atk).to_i; d=change_stage(b,b,:atk,KO_STAGE); after=b.cg_stat_stage(:atk).to_i
      return false if d==0
      note_trigger(ABILITY_CHILLING_NEIGH,b,:after_ko,{:before=>before,:after=>after,:delta=>d}); true
    end
    def self.apply_grim_neigh(b,ctx)
      return false if ctx[:target]==nil || ctx[:target].hp.to_i>0
      before=b.cg_stat_stage(:spa).to_i; d=change_stage(b,b,:spa,KO_STAGE); after=b.cg_stat_stage(:spa).to_i
      return false if d==0
      note_trigger(ABILITY_GRIM_NEIGH,b,:after_ko,{:before=>before,:after=>after,:delta=>d}); true
    end
    def self.apply_cotton_down(b,ctx)
      return false if ctx[:damage_done].to_i<=0
      changed=[]
      core.active_battlers.each do |t|
        next if t.equal?(b)
        before=t.cg_stat_stage(:spe).to_i; d=change_stage(b,t,:spe,COTTON_SPE); after=t.cg_stat_stage(:spe).to_i
        changed.push((t.actor? ? "A" : "E")+t.index.to_s+":"+before.to_s+">"+after.to_s) if d!=0
      end
      return false if changed.empty?
      note_trigger(ABILITY_COTTON_DOWN,b,:after_hit,{:changed=>changed.join("|")}); true
    end
    def self.apply_anger_shell(b,ctx)
      return false if ctx[:damage_done].to_i<=0
      hb=ctx[:hp_before].to_i; ha=ctx[:hp_after].to_i; mh=b.maxhp.to_i
      return false unless hb*2>mh && ha*2<=mh && ha>0
      before={:atk=>b.cg_stat_stage(:atk).to_i,:def=>b.cg_stat_stage(:def).to_i,:spa=>b.cg_stat_stage(:spa).to_i,:spd=>b.cg_stat_stage(:spd).to_i,:spe=>b.cg_stat_stage(:spe).to_i}
      change_stage(b,b,:atk,ANGER_UP); change_stage(b,b,:spa,ANGER_UP); change_stage(b,b,:spe,ANGER_UP)
      change_stage(b,b,:def,ANGER_DOWN); change_stage(b,b,:spd,ANGER_DOWN)
      after={:atk=>b.cg_stat_stage(:atk).to_i,:def=>b.cg_stat_stage(:def).to_i,:spa=>b.cg_stat_stage(:spa).to_i,:spd=>b.cg_stat_stage(:spd).to_i,:spe=>b.cg_stat_stage(:spe).to_i}
      note_trigger(ABILITY_ANGER_SHELL,b,:after_hit,{:hp_before=>hb,:hp_after=>ha,:before=>before.inspect,:after=>after.inspect}); true
    end
    def self.apply_rattled(b,ctx)
      return false if ctx[:damage_done].to_i<=0
      tid=skill_type_id(ctx[:skill]); allowed=[type_id(:dark),type_id(:ghost),type_id(:bug)]
      return false unless allowed.include?(tid)
      before=b.cg_stat_stage(:spe).to_i; d=change_stage(b,b,:spe,RATTLED_SPE); after=b.cg_stat_stage(:spe).to_i
      return false if d==0
      note_trigger(ABILITY_RATTLED,b,:after_hit,{:type_id=>tid,:before=>before,:after=>after,:delta=>d}); true
    end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_INTREPID_SWORD,:entry,self,:apply_intrepid_sword)
      core.register(ABILITY_DAUNTLESS_SHIELD,:entry,self,:apply_dauntless_shield)
      core.register(ABILITY_BEAST_BOOST,:after_ko,self,:apply_beast_boost)
      core.register(ABILITY_CHILLING_NEIGH,:after_ko,self,:apply_chilling_neigh)
      core.register(ABILITY_GRIM_NEIGH,:after_ko,self,:apply_grim_neigh)
      core.register(ABILITY_COTTON_DOWN,:after_hit,self,:apply_cotton_down)
      core.register(ABILITY_ANGER_SHELL,:after_hit,self,:apply_anger_shell)
      core.register(ABILITY_RATTLED,:after_hit,self,:apply_rattled)
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
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability P v2.5.15a AutoRegression",ms)
    end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); else; a.clear; end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active? && e && !e.hidden && e.hp.to_i>0; c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c); end
    def self.apply_test_speeds; vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||[]; (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override,vals[i]) if b}; end
    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end

    def self.install_round1_conditions
      a=test_allies; e=all_enemies
      a[1].hp=1 if a[1]
      if e[0]; e[0].recover_all; e[0].hp=1; end
      if e[1]; e[1].recover_all; e[1].hp=1; end
      true
    rescue; false; end
    def self.prepare_round_preconditions
      if current_round==1
        install_round1_conditions
      elsif current_round==2
        @r2_storage_before=storage_size; e=all_enemies
        if e[2]; e[2].recover_all; e[2].cg_reset_stat_stages if e[2].respond_to?(:cg_reset_stat_stages); e[2].hp=e[2].maxhp.to_i/2+1; @r2_anger_start=e[2].hp.to_i; end
        e[3].recover_all if e[3]&&e[3].respond_to?(:recover_all); e[4].recover_all if e[4]&&e[4].respond_to?(:recover_all)
      elsif current_round==3
        e=all_enemies; e[4].cg_reset_stat_stages if e[4]&&e[4].respond_to?(:cg_reset_stat_stages)
      end
    end
    def self.prepare_round_actions
      p=current_plan; return false if p==nil; apply_test_speeds; prepare_round_preconditions; @actual=[]; log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s)
      test_allies.each_with_index do |b,i|; next if b==nil || b.hp.to_i<=0; a=make_action(b,p[:allies][i]); if b.respond_to?(:cg_round_actions); b.cg_round_actions.clear; b.cg_round_actions.push(a); end; b.cg_assign_action(a) if b.respond_to?(:cg_assign_action); b.instance_variable_set(:@action,a) unless b.respond_to?(:cg_assign_action); end; true
    end
    def self.record_execution(b)
      return unless active?&&b; a=b.action; pre=b.actor? ? "A" : "E"; tok= if a&&a.guard?; pre+b.index.to_s+":Guard" elsif a&&a.skill?; pre+b.index.to_s+":M"+ALBERT_CG::MOVE_EFFECT.move_id(a.skill).to_i.to_s else; pre+b.index.to_s+":Other" end; @actual.push(tok); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    rescue; end
    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true; install_round1_conditions
      tid=($game_troop&&$game_troop.troop) ? $game_troop.troop.id.to_i : 0; ids=core ? core.registered_ability_ids : []
      assert_true("Ability Catalog count=373",core&&core.catalog_count==373,"actual="+(core ? core.catalog_count.to_s : "nil")); assert_true("Ability Batch P registers 8 IDs",HANDLED_ABILITY_IDS.all?{|id|ids.include?(id)})
      assert_true("Scene_Battle uses Ability P test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s); assert_true("Ability P ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability P starts with 4 active enemies",all_enemies.select{|b|b&&!b.hidden}.size==4); assert_true("Ability P starts with 1 hidden Rattled reserve",all_enemies.select{|b|b&&b.hidden}.size==1)
      assert_true("Intrepid Sword entry raises ATK +1",test_allies[1]&&test_allies[1].cg_stat_stage(:atk).to_i==1,"atk="+(test_allies[1] ? test_allies[1].cg_stat_stage(:atk).to_s : "nil"))
      assert_true("Dauntless Shield entry raises DEF +1",all_enemies[0]&&all_enemies[0].cg_stat_stage(:def).to_i==1,"def="+(all_enemies[0] ? all_enemies[0].cg_stat_stage(:def).to_s : "nil"))
    end
    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]; assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==exp,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        rec=@records[ABILITY_GRIM_NEIGH]; ok=rec&&rec[:after].to_i==rec[:before].to_i+1; @ko_checks+=1 if ok; assert_true("Grim Neigh raises SPA +1 after real KO",ok,rec ? rec.inspect : "record=nil")
        rec=@records[ABILITY_BEAST_BOOST]; ok=rec&&rec[:after].to_i==rec[:before].to_i+1; @ko_checks+=1 if ok; assert_true("Beast Boost raises highest current non-HP stat stage +1",ok,rec ? rec.inspect : "record=nil")
        rec=@records[ABILITY_CHILLING_NEIGH]; ok=rec&&rec[:after].to_i==rec[:before].to_i+1; @ko_checks+=1 if ok; assert_true("Chilling Neigh raises ATK +1 after real KO",ok,rec ? rec.inspect : "record=nil")
      elsif r==2
        rec=@records[ABILITY_COTTON_DOWN]; ok=rec&&rec[:changed].to_s.length>0; @reaction_checks+=1 if ok; assert_true("Cotton Down lowers other active battlers SPE after damage",ok,rec ? rec.inspect : "record=nil")
        rec=@records[ABILITY_ANGER_SHELL]; ok=rec&&rec[:hp_before].to_i*2>e[2].maxhp.to_i&&rec[:hp_after].to_i*2<=e[2].maxhp.to_i; @threshold_checks+=1 if ok; assert_true("Anger Shell fires only when damage crosses half HP",ok,rec ? rec.inspect : "record=nil")
        sw=e[3]&&e[4]&&e[3].hidden&&!e[4].hidden; @lifecycle_checks+=1 if sw; assert_true("Teleport deploys hidden Rattled reserve",sw,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        sa=storage_size; sok=sa==@r2_storage_before.to_i; @lifecycle_checks+=1 if sok; assert_true("Rattled reserve switch does not consume Storage Pokemon",sok,"before="+@r2_storage_before.to_s+" after="+sa.to_s)
      elsif r==3
        rec=@records[ABILITY_RATTLED]; ok=rec&&rec[:after].to_i==rec[:before].to_i+1; @reaction_checks+=1 if ok; assert_true("Rattled raises SPE +1 after Dark damage",ok,rec ? rec.inspect : "record=nil")
      end
      log("ROUND "+r.to_s+" END")
    end
    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override,nil) if b}; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"; log("------------------------------------------------------------"); log("RESULT="+result); log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_p="+ability_covered_count.to_s+"/8 entry_checks=2 ko_checks="+@ko_checks.to_i.to_s+" reaction_checks="+@reaction_checks.to_i.to_s+" threshold_checks="+@threshold_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=245"); @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite; @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @ko_checks=0; @reaction_checks=0; @threshold_checks=0; @lifecycle_checks=0; @actual=[]; @boot_asserted=false; @r2_storage_before=0; end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; ALBERT_CG::UNIQUE_I_V242.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_I_V242)&&ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes); @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_P_v2.5.15a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e; @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false; end
  end
end

ALBERT_CG::ABILITY_P_V2515.register_handlers if defined?(ALBERT_CG::ABILITY_V250)
if defined?(ALBERT_CG::ABILITY_O_V2514)
  module ALBERT_CG; module ABILITY_O_V2514; def self.f11_trigger?; false; end; end; end
end

class Game_Battler
  alias cg_v2515p_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil); return 100 if defined?(ALBERT_CG::ABILITY_P_V2515)&&ALBERT_CG::ABILITY_P_V2515.active?; cg_v2515p_ability_calc_hit(user,obj); end
  alias cg_v2515p_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil); return 0 if defined?(ALBERT_CG::ABILITY_P_V2515)&&ALBERT_CG::ABILITY_P_V2515.active?; cg_v2515p_ability_calc_eva(user,obj); end
  alias cg_v2515p_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed; if defined?(ALBERT_CG::ABILITY_P_V2515)&&ALBERT_CG::ABILITY_P_V2515.active?; v=@cg_priority_test_speed_override; return v.to_i if v!=nil; end; cg_v2515p_ability_priority_base_speed; rescue; cg_v2515p_ability_priority_base_speed; end
end
class Game_Enemy < Game_Battler
  alias cg_v2515p_ability_enemy_make_action make_action
  def make_action; if defined?(ALBERT_CG::ABILITY_P_V2515)&&ALBERT_CG::ABILITY_P_V2515.active?; a=ALBERT_CG::ABILITY_P_V2515.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end; end; cg_v2515p_ability_enemy_make_action; end
end
class Scene_Battle < Scene_Base
  alias cg_v2515p_ability_execute_action execute_action
  def execute_action; b=@active_battler; ALBERT_CG::ABILITY_P_V2515.record_execution(b) if defined?(ALBERT_CG::ABILITY_P_V2515)&&ALBERT_CG::ABILITY_P_V2515.active?; cg_v2515p_ability_execute_action; end
  alias cg_v2515p_ability_turn_end turn_end
  def turn_end; if defined?(ALBERT_CG::ABILITY_P_V2515)&&ALBERT_CG::ABILITY_P_V2515.active?; if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_P_V2515.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_P_V2515.finish_round_assertions; end; end; cg_v2515p_ability_turn_end; end
  alias cg_v2515p_ability_start_party_command start_party_command_selection
  def start_party_command_selection; unless defined?(ALBERT_CG::ABILITY_P_V2515)&&ALBERT_CG::ABILITY_P_V2515.active?; return cg_v2515p_ability_start_party_command; end; cg_v2515p_ability_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_P_V2515.assert_bootstrap_once; if ALBERT_CG::ABILITY_P_V2515.finished?; ALBERT_CG::ABILITY_P_V2515.finish_suite; battle_end(0); return; end; ALBERT_CG::ABILITY_P_V2515.prepare_round_actions; start_main; end
end
module ALBERT_CG
  class << self
    alias cg_v2515p_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party; r=cg_v2515p_ability_bootstrap_demo_party; if defined?(ALBERT_CG::ABILITY_P_V2515)&&ALBERT_CG::ABILITY_P_V2515.active?; ALBERT_CG::ABILITY_P_V2515::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_P_V2515.configure_actor(c)}; h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_P_V2515::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); end; end; r; end
  end
end
class Scene_Map < Scene_Base
  alias cg_v2515p_ability_scene_map_update update
  def update; cg_v2515p_ability_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_P_V2515); ALBERT_CG::ABILITY_P_V2515.start_auto_test if ALBERT_CG::ABILITY_P_V2515.f11_trigger?; end
end
