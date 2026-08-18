# RMVX_SCRIPT_INDEX: 265
# RMVX_SCRIPT_ID: 265000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AO v2.5.40a
# RMVX_SOURCE_SHA256: 2f8fc2a34899a54257aeb57174246514c507a02cf1d745e6eeafebc8ff5d79fa

#==============================================================================
# ■ CG Pokemon Ability Batch AO v2.5.40a - Conquest Aura + Control TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.39a Ability Batch AN RPG Maker VX 實機 PASS 為唯一正式基底，收斂
#  Pokémon Conquest 的 Electric 隊伍增幅、草地防禦、地形閃避、三種睡眠光環與
#  Speed / Accuracy 干擾。沿用 Ability Core :stat_query / :before_hit / :end_turn、
#  Field、Status 與正式 stat-stage Authority，不建立第二套命中/狀態/能力階級系統。
#
# 【本批 Ability】
#  10030 Stealth：在「適性地形」提高迴避機率。
#  10033 Sequence：附近有 Electric-type 隊友時提升 Attack。
#  10034 Grass Cloak：草地提升 Defense。
#  10036 Lullaby：每回合對附近敵人嘗試 Sleep（歌唱型）。
#  10037 Calming：每回合對附近敵人嘗試 Sleep。
#  10038 Daze：每回合對附近敵人嘗試較長 Sleep。
#  10039 Frighten：每回合令附近敵人 Speed -1 stage；Conquest Range 降低不適用 CG。
#  10040 Interference：每回合令附近敵人 Accuracy -1 stage。
#
# 【CG 專案適配】
#  1. Conquest 的 Range/adjacent tile -> 同一場 active battle group。
#  2. Sequence / Grass Cloak 原資料沒有穩定固定倍率；CG 採 20% passive boost。
#  3. Lullaby / Calming / Daze / Stealth 的「may」沿用 AL/AN Conquest 慣例 30%；
#     F11 使用 forced proc / no-proc，Regression 不依 RNG。
#  4. Stealth 的 favorite terrain 原作判定資料不完整；CG 以任何有效 Terrain 作
#     terrain-cover proxy。Weather 本身不算適性地形。
#  5. Daze 在成功 Sleep 後把現有 Sleep turns 至少提升至 3；若底層狀態沒有
#     @state_turns，則仍以正式 Sleep state 為權威，不另造 duration system。
#  6. Frighten 的 Conquest movement Range 沒有 CG 對應，不虛構移動系統；只實作
#     原作同時存在的 Speed -1 stage。Interference 直接走 Accuracy stage Authority。
#
# 【F11】Troop 743，三回合 Actual Scene_Battle：
#  R1 Grassy：Sequence +20%、Grass Cloak +20%、Stealth forced evade；Lullaby forced
#     proc；Calming/Daze forced false；Frighten / Interference 各 -1 stage。
#  R2 Clear：Sequence ally Electric proxy 移除、Grass Cloak 關閉、Stealth 即使 forced
#     true 也不能閃；Calming forced proc；其他睡眠 aura false；干擾仍正常。
#  R3 Grassy：Sequence/Grass Cloak 恢復；Stealth forced false 留正常傷害；Daze forced
#     proc 並留下 long-sleep evidence；scope/no-proc 同時驗證。
#==============================================================================
$imported={} if $imported==nil
$imported["ALBERT_CG_PokemonAbilityBatchAO"]="2.5.40a"
module ALBERT_CG
  module ABILITY_AO_V2540
    VERSION="2.5.40a"; TEST_LEVEL=40; TEST_TROOP_ID=743; VK_F11=0x7A
    ABILITY_STEALTH=10030; ABILITY_SEQUENCE=10033; ABILITY_GRASS_CLOAK=10034
    ABILITY_LULLABY=10036; ABILITY_CALMING=10037; ABILITY_DAZE=10038
    ABILITY_FRIGHTEN=10039; ABILITY_INTERFERENCE=10040
    HANDLED_ABILITY_IDS=[10030,10033,10034,10036,10037,10038,10039,10040]
    BOOST_PERCENT=120; PROC_CHANCE=30
    TEST_ALLIES=[
      {:dex=>143,:level=>40,:ability=>ABILITY_GRASS_CLOAK,:moves=>[150,150,150]},
      {:dex=>65,:level=>40,:ability=>ABILITY_LULLABY,:moves=>[150,150,150]},
      {:dex=>18,:level=>40,:ability=>ABILITY_STEALTH,:moves=>[150,150,150]}]
    TEST_ENEMIES=[
      {:dex=>143,:level=>45,:ability=>ABILITY_CALMING,:moves=>[55,55,55]},
      {:dex=>383,:level=>45,:ability=>ABILITY_DAZE,:moves=>[150,150,150]},
      {:dex=>384,:level=>45,:ability=>ABILITY_FRIGHTEN,:moves=>[150,150,150]},
      {:dex=>92,:level=>45,:ability=>ABILITY_INTERFERENCE,:moves=>[150,150,150]}]
    ROUND_PLANS=[
      {:name=>"GRASS_SEQUENCE_STEALTH_LULLABY",:allies=>[
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>55,:target=>3},1=>{:kind=>:move,:move_id=>150,:target=>1},2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"CLEAR_CALMING_SCOPE",:allies=>[
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>55,:target=>3},1=>{:kind=>:move,:move_id=>150,:target=>1},2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"GRASS_DAZE_NO_STEALTH",:allies=>[
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>55,:target=>3},1=>{:kind=>:move,:move_id=>150,:target=>1},2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}}]
    EXPECTED_EXECUTION_TOKENS={
      1=>["A0:M150","A1:M150","A2:M150","A3:M150","E0:M55","E1:M150","E2:M150","E3:M150"],
      2=>["A0:M150","A1:M150","A2:M150","A3:M150","E0:M55","E1:M150","E2:M150","E3:M150"],
      3=>["A0:M150","A1:M150","A2:M150","A3:M150","E0:M55","E1:M150","E2:M150","E3:M150"]}
    TEST_SPEEDS={1=>[900,850,800,750,600,550,500,450],2=>[900,850,800,750,600,550,500,450],3=>[900,850,800,750,600,550,500,450]}
    begin; KEY_API=Win32API.new("user32","GetAsyncKeyState","i","i"); rescue; KEY_API=nil; end
    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.move_effect; defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT : nil; end
    def self.field; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233 : nil; end
    def self.field_state; field&&field.respond_to?(:state) ? field.state : nil; rescue; nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party ? $game_party.members : []; end
    def self.all_enemies; $game_troop ? $game_troop.members : []; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AO_AutoTest_v2_5_40a.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(p,t,m="ab"); File.open(p,m){|f|f.write(t.to_s+"\r\n")}; true; rescue; false; end
    def self.log(t); write_line(log_path,t); write_line(latest_log_path,t); rescue; end
    def self.key_down?(c); KEY_API && (KEY_API.call(c)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.ability_id(b); core&&b ? core.ability_id(b).to_i : 0; rescue; 0; end
    def self.sleep_state; move_effect ? move_effect::STATE_SLEEP : 39; end
    def self.assert_true(label,cond,detail=nil); if cond; log("ASSERT PASS "+label.to_s+(detail ? " "+detail.to_s : "")); else; x=label.to_s+(detail ? " "+detail.to_s : ""); @failures<<x; log("ASSERT FAIL "+x); end; cond; end
    def self.note_local(aid,b,kind,data=nil); rec={:ability=>aid.to_i,:kind=>kind}; (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill,:action].include?(k)}; if active?; @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1; (@records[aid.to_i]||=[])<<rec; log("ABILITY_AO_TRIGGER ability="+aid.to_s+" battler="+(b ? b.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect); end; rec; rescue; nil; end
    def self.records_for(aid,kind=nil); a=@records[aid.to_i]||[]; kind ? a.select{|x|x[:kind].to_sym==kind.to_sym} : a; rescue; []; end
    def self.active_members(holder); u=holder&&holder.actor? ? $game_party : $game_troop; u ? u.members.select{|b|b&&!b.hidden&&b.hp.to_i>0} : []; rescue; []; end
    def self.opponents_of(holder); u=holder&&holder.actor? ? $game_troop : $game_party; u ? u.members.select{|b|b&&!b.hidden&&b.hp.to_i>0} : []; rescue; []; end
    def self.terrain; st=field_state; st&&st.terrain_turns.to_i>0 ? st.terrain : nil; rescue; nil; end
    def self.set_terrain(sym,turns); st=field_state; return false unless st; st.weather=nil; st.weather_turns=0; st.terrain=sym; st.terrain_turns=turns.to_i; true; rescue; false; end
    def self.proc_success?(aid); return @forced_proc[aid.to_i] if active?&&@forced_proc&&@forced_proc.has_key?(aid.to_i); rand(100)<PROC_CHANCE; rescue; false; end
    def self.change_stage(source,target,key,amount); return 0 unless target&&target.respond_to?(:cg_change_stat_stage); auth=defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) ? ALBERT_CG::ABILITY_STAT_GUARD_V256 : nil; return auth.with_stage_source(source,:ability,false){target.cg_change_stat_stage(key,amount).to_i} if auth&&auth.respond_to?(:with_stage_source); target.cg_change_stat_stage(key,amount).to_i; rescue; 0; end
    def self.types_of(b); b&&b.respond_to?(:cg_pokemon_types) ? b.cg_pokemon_types : []; rescue; []; end
    def self.electric_ally?(holder); active_members(holder).any?{|b|!b.equal?(holder)&&types_of(b).include?(:electric)}; rescue; false; end
    def self.opposing?(a,b); a&&b&&a.actor?!=b.actor?; rescue; false; end
    def self.damaging_enemy_move?(holder,ctx); return false unless holder&&ctx&&ctx[:user]&&ctx[:skill]; return false unless opposing?(holder,ctx[:user]); ctx[:skill].base_damage.to_i>0; rescue; false; end
    def self.apply_sequence(holder,ctx); return false unless holder&&ctx&&ctx[:stat].to_sym==:atk&&electric_ally?(holder); before=ctx[:value].to_i; return false if before<=0; after=[before*BOOST_PERCENT/100,1].max; ctx[:value]=after; note_local(ABILITY_SEQUENCE,holder,:sequence,{:before=>before,:after=>after,:percent=>BOOST_PERCENT}); true; rescue; false; end
    def self.apply_grass_cloak(holder,ctx); return false unless holder&&ctx&&ctx[:stat].to_sym==:def&&terrain==:grassy; before=ctx[:value].to_i; return false if before<=0; after=[before*BOOST_PERCENT/100,1].max; ctx[:value]=after; note_local(ABILITY_GRASS_CLOAK,holder,:grass_cloak,{:before=>before,:after=>after,:percent=>BOOST_PERCENT,:terrain=>terrain}); true; rescue; false; end
    def self.apply_stealth(holder,ctx); return false unless holder&&ctx&&damaging_enemy_move?(holder,ctx)&&terrain!=nil&&proc_success?(ABILITY_STEALTH); ctx[:cancel]=true; ctx[:hp_damage]=0; note_local(ABILITY_STEALTH,holder,:stealth,{:move_id=>ctx[:move_id].to_i,:terrain=>terrain,:attacker_index=>ctx[:user].index.to_i}); true; rescue; false; end
    def self.sleep_aura(holder,aid,kind,long=false); hits=[]; durations=[]; opponents_of(holder).each{|t|next if t.state?(sleep_state); next unless proc_success?(aid); t.add_state(sleep_state); next unless t.state?(sleep_state); turns=nil; if long; h=t.instance_variable_get(:@state_turns); if h.is_a?(Hash); h[sleep_state]=[h[sleep_state].to_i,3].max; turns=h[sleep_state].to_i; end; end; hits<<t.index.to_i; durations<<[t.index.to_i,turns]}; return false if hits.empty?; vals=durations.collect{|x|x[1]}.compact; note_local(aid,holder,kind,{:targets=>hits.inspect,:long_sleep=>long,:durations=>durations.inspect,:min_turns=>(vals.empty? ? nil : vals.min)}); true; rescue; false; end
    def self.apply_lullaby(h,c); sleep_aura(h,ABILITY_LULLABY,:lullaby,false); end
    def self.apply_calming(h,c); sleep_aura(h,ABILITY_CALMING,:calming,false); end
    def self.apply_daze(h,c); sleep_aura(h,ABILITY_DAZE,:daze,true); end
    def self.apply_frighten(holder,ctx); hits=[]; opponents_of(holder).each{|t|before=t.respond_to?(:cg_stat_stage) ? t.cg_stat_stage(:spe).to_i : 0; d=change_stage(holder,t,:spe,-1); after=t.respond_to?(:cg_stat_stage) ? t.cg_stat_stage(:spe).to_i : before; hits<<[t.index.to_i,before,after] if d!=0}; return false if hits.empty?; note_local(ABILITY_FRIGHTEN,holder,:frighten,{:targets=>hits.inspect}); true; rescue; false; end
    def self.apply_interference(holder,ctx); hits=[]; opponents_of(holder).each{|t|before=t.respond_to?(:cg_stat_stage) ? t.cg_stat_stage(:accuracy).to_i : 0; d=change_stage(holder,t,:accuracy,-1); after=t.respond_to?(:cg_stat_stage) ? t.cg_stat_stage(:accuracy).to_i : before; hits<<[t.index.to_i,before,after] if d!=0}; return false if hits.empty?; note_local(ABILITY_INTERFERENCE,holder,:interference,{:targets=>hits.inspect}); true; rescue; false; end
    def self.register_handlers; return false unless core; core.register(ABILITY_STEALTH,:before_hit,self,:apply_stealth); core.register(ABILITY_SEQUENCE,:stat_query,self,:apply_sequence); core.register(ABILITY_GRASS_CLOAK,:stat_query,self,:apply_grass_cloak); core.register(ABILITY_LULLABY,:end_turn,self,:apply_lullaby); core.register(ABILITY_CALMING,:end_turn,self,:apply_calming); core.register(ABILITY_DAZE,:end_turn,self,:apply_daze); core.register(ABILITY_FRIGHTEN,:end_turn,self,:apply_frighten); core.register(ABILITY_INTERFERENCE,:end_turn,self,:apply_interference); true; end
    def self.clear_runtime(b); return unless b; b.instance_variable_set(:@cg_priority_test_speed_override_ao,nil); b.instance_variable_set(:@cg_v237_type_override,nil) if b.respond_to?(:cg_v237_set_types); end
    def self.configure_actor(cfg); a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return unless a; master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); clear_runtime(a); end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end
    def self.prepare_test_party; ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}; ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS); $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true); $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!); TEST_ALLIES.each{|c|configure_actor(c)}; h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); clear_runtime(h); h.instance_variable_set(:@cg_master_ability_id,ABILITY_SEQUENCE); mids=[150]; sids=mids.collect{|m|master.skill_id_for_move(m)}; h.instance_variable_set(:@cg_equipped_skill_ids,sids); h.instance_variable_set(:@cg_skill_slot_ids,sids); h.instance_variable_set(:@skills,sids); end; end
    def self.make_test_troop; master.ensure_index($data_troops,TEST_TROOP_ID); xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X]; ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0]]; ms=[]; TEST_ENEMIES.each_with_index{|c,i|configure_enemy(c); ms<<ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i])}; $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AO v2.5.40a AutoRegression",ms); end
    def self.make_action(b,c); a=Game_BattleAction.new(b); c[:kind]==:guard ? a.set_guard : a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); a.target_index=c[:target].to_i if c.has_key?(:target); a; end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; p=current_plan; return nil unless p&&p[:enemies]; c=p[:enemies][e.index]; c ? make_action(e,c) : nil; end
    def self.action_token(b); return "nil" unless b; s=b.actor? ? "A" : "E"; a=b.action; return s+b.index.to_s+":Guard" if a&&a.guard?; return s+b.index.to_s+":M"+move_id(a.skill).to_s if a&&a.skill?; s+b.index.to_s+":Other"; rescue; "?"; end
    def self.record_execution(b); @actual<<action_token(b) if active?; log("ACTION_EXEC #"+@actual.size.to_s+" "+(b ? b.name.to_s : "nil")+" token="+@actual[-1].to_s) if active?; end
    def self.apply_test_speeds; sp=TEST_SPEEDS[current_round]||[]; (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_ao,sp[i]) if b&&sp[i]!=nil}; end
    def self.clear_sleep_and_stages; (test_allies+all_enemies).each{|b|next unless b; b.remove_state(sleep_state) if b.state?(sleep_state); b.cg_reset_stat_stages if b.respond_to?(:cg_reset_stat_stages)}; end
    def self.prepare_round_fixture; a=test_allies; e=all_enemies; r=current_round; clear_sleep_and_stages; @forced_proc={}; if r==1; set_terrain(:grassy,5); a[1].cg_v237_set_types([:electric]) if a[1]&&a[1].respond_to?(:cg_v237_set_types); @forced_proc[ABILITY_STEALTH]=true; @forced_proc[ABILITY_LULLABY]=true; @forced_proc[ABILITY_CALMING]=false; @forced_proc[ABILITY_DAZE]=false; log("ROUND1_FIELD terrain=grassy sleep=lullaby stealth=true"); elsif r==2; set_terrain(nil,0); a[1].instance_variable_set(:@cg_v237_type_override,nil) if a[1]; @forced_proc[ABILITY_STEALTH]=true; @forced_proc[ABILITY_LULLABY]=false; @forced_proc[ABILITY_CALMING]=true; @forced_proc[ABILITY_DAZE]=false; log("ROUND2_FIELD terrain=nil sleep=calming stealth=true_but_no_terrain"); else; set_terrain(:grassy,5); a[1].cg_v237_set_types([:electric]) if a[1]&&a[1].respond_to?(:cg_v237_set_types); @forced_proc[ABILITY_STEALTH]=false; @forced_proc[ABILITY_LULLABY]=false; @forced_proc[ABILITY_CALMING]=false; @forced_proc[ABILITY_DAZE]=true; log("ROUND3_FIELD terrain=grassy sleep=daze stealth=false"); end; @round_counts={}; HANDLED_ABILITY_IDS.each{|id|@round_counts[id]=records_for(id).size}; @seq_value=a[0] ? a[0].cg_atk_stat.to_i : 0; @grass_value=a[1] ? a[1].cg_def_stat.to_i : 0; @stealth_hp=a[3] ? a[3].hp.to_i : 0; end
    def self.prepare_round_actions; prepare_round_fixture; apply_test_speeds; @actual=[]; a=test_allies; current_plan[:allies].each_with_index{|cfg,i|next unless a[i]; act=make_action(a[i],cfg); a[i].instance_variable_set(:@cg_round_actions,[act]); a[i].cg_assign_action(act) if a[i].respond_to?(:cg_assign_action); a[i].instance_variable_set(:@action,act) unless a[i].respond_to?(:cg_assign_action)}; log("ROUND "+current_round.to_s+" BEGIN "+current_plan[:name]); true; end
    def self.assert_order; exp=EXPECTED_EXECUTION_TOKENS[current_round]||[]; ok=@actual==exp; @action_checks+=1 if ok; assert_true("Round"+current_round.to_s+" execution order matches deterministic plan",ok,"expected="+exp.inspect+" actual="+@actual.inspect); end
    def self.assert_bootstrap_once; return if @boot_asserted; @boot_asserted=true; assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil")); assert_true("Ability Batch AO defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s); assert_true("Scene_Battle uses Ability AO test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil")); assert_true("Ability AO ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s); assert_true("Ability AO enemy count=4",all_enemies.size==4,"actual="+all_enemies.size.to_s); end
    def self.exact_boost_record?(aid,kind,offset,value)
      rec=records_for(aid,kind)[offset.to_i]
      return false unless rec
      expected=[rec[:before].to_i*BOOST_PERCENT/100,1].max
      rec[:after].to_i==expected && value.to_i==expected
    rescue; false; end
    def self.finish_round_assertions
      assert_order; a=test_allies; e=all_enemies; r=current_round
      seq_recs=records_for(ABILITY_SEQUENCE,:sequence); grass_recs=records_for(ABILITY_GRASS_CLOAK,:grass_cloak)
      seq_on=seq_recs.size>@round_counts[ABILITY_SEQUENCE]; grass_on=grass_recs.size>@round_counts[ABILITY_GRASS_CLOAK]
      if r==1
        seq_exact=seq_on&&exact_boost_record?(ABILITY_SEQUENCE,:sequence,@round_counts[ABILITY_SEQUENCE],@seq_value); @stat_checks+=1 if seq_exact; assert_true("Sequence boosts ATK exactly 20% with active Electric ally",seq_exact,(seq_recs[@round_counts[ABILITY_SEQUENCE]]||{}).inspect+" value="+@seq_value.to_s)
        grass_exact=grass_on&&exact_boost_record?(ABILITY_GRASS_CLOAK,:grass_cloak,@round_counts[ABILITY_GRASS_CLOAK],@grass_value); @stat_checks+=1 if grass_exact; assert_true("Grass Cloak boosts DEF exactly 20% in Grassy Terrain",grass_exact,(grass_recs[@round_counts[ABILITY_GRASS_CLOAK]]||{}).inspect+" value="+@grass_value.to_s)
        st=records_for(ABILITY_STEALTH,:stealth).size>@round_counts[ABILITY_STEALTH]&&a[3]&&a[3].hp.to_i==@stealth_hp; @evasion_checks+=1 if st; assert_true("Stealth forced proc evades real damaging Water Gun on active Terrain",st,"hp="+@stealth_hp.to_s+"->"+(a[3] ? a[3].hp.to_i.to_s : "nil"))
        sl=records_for(ABILITY_LULLABY,:lullaby).size>@round_counts[ABILITY_LULLABY]; @sleep_checks+=1 if sl; assert_true("Lullaby forced proc applies Sleep aura",sl,(records_for(ABILITY_LULLABY,:lullaby)[-1]||{}).inspect)
        cf=records_for(ABILITY_CALMING,:calming).size==@round_counts[ABILITY_CALMING]&&records_for(ABILITY_DAZE,:daze).size==@round_counts[ABILITY_DAZE]; @scope_checks+=1 if cf; assert_true("Calming and Daze forced false stay off",cf)
      elsif r==2
        off=!seq_on&&!grass_on; @scope_checks+=1 if off; assert_true("Sequence and Grass Cloak deactivate without Electric ally / Terrain",off)
        st=records_for(ABILITY_STEALTH,:stealth).size==@round_counts[ABILITY_STEALTH]&&a[3]&&a[3].hp.to_i<@stealth_hp; @evasion_checks+=1 if st; assert_true("Stealth cannot evade with no Terrain even when proc forced true",st,"hp="+@stealth_hp.to_s+"->"+(a[3] ? a[3].hp.to_i.to_s : "nil"))
        ca=records_for(ABILITY_CALMING,:calming).size>@round_counts[ABILITY_CALMING]; @sleep_checks+=1 if ca; assert_true("Calming forced proc applies Sleep aura",ca,(records_for(ABILITY_CALMING,:calming)[-1]||{}).inspect)
        no=records_for(ABILITY_LULLABY,:lullaby).size==@round_counts[ABILITY_LULLABY]&&records_for(ABILITY_DAZE,:daze).size==@round_counts[ABILITY_DAZE]; @scope_checks+=1 if no; assert_true("Lullaby and Daze forced false stay off",no)
      else
        seq_exact=seq_on&&exact_boost_record?(ABILITY_SEQUENCE,:sequence,@round_counts[ABILITY_SEQUENCE],@seq_value); @stat_checks+=1 if seq_exact; assert_true("Sequence returns at exact 20% when Electric ally returns",seq_exact,(seq_recs[@round_counts[ABILITY_SEQUENCE]]||{}).inspect+" value="+@seq_value.to_s)
        grass_exact=grass_on&&exact_boost_record?(ABILITY_GRASS_CLOAK,:grass_cloak,@round_counts[ABILITY_GRASS_CLOAK],@grass_value); @stat_checks+=1 if grass_exact; assert_true("Grass Cloak returns at exact 20% with Grassy Terrain",grass_exact,(grass_recs[@round_counts[ABILITY_GRASS_CLOAK]]||{}).inspect+" value="+@grass_value.to_s)
        st=records_for(ABILITY_STEALTH,:stealth).size==@round_counts[ABILITY_STEALTH]&&a[3]&&a[3].hp.to_i<@stealth_hp; @evasion_checks+=1 if st; assert_true("Stealth forced no-proc leaves normal damage path",st,"hp="+@stealth_hp.to_s+"->"+(a[3] ? a[3].hp.to_i.to_s : "nil"))
        dzrec=records_for(ABILITY_DAZE,:daze)[-1]; dz=records_for(ABILITY_DAZE,:daze).size>@round_counts[ABILITY_DAZE]&&dzrec&&dzrec[:long_sleep]==true&&dzrec[:min_turns].to_i>=3; @sleep_checks+=1 if dz; assert_true("Daze forced proc applies long Sleep aura with >=3-turn evidence",dz,(dzrec||{}).inspect)
      end
      fr=records_for(ABILITY_FRIGHTEN,:frighten).size>@round_counts[ABILITY_FRIGHTEN]&&a.all?{|b|!b||b.cg_stat_stage(:spe).to_i==-1}; @debuff_checks+=1 if fr; assert_true("Frighten lowers active foe Speed -1 stage",fr,"stages="+a.collect{|b|b ? b.cg_stat_stage(:spe).to_i : nil}.inspect)
      it=records_for(ABILITY_INTERFERENCE,:interference).size>@round_counts[ABILITY_INTERFERENCE]&&a.all?{|b|!b||b.cg_stat_stage(:accuracy).to_i==-1}; @debuff_checks+=1 if it; assert_true("Interference lowers active foe Accuracy -1 stage",it,"stages="+a.collect{|b|b ? b.cg_stat_stage(:accuracy).to_i : nil}.inspect)
      log("ROUND "+r.to_s+" END"); @round_index+=1
    end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|clear_runtime(b)}; set_terrain(nil,0); @forced_proc=nil; rescue; end
    def self.finish_suite; HANDLED_ABILITY_IDS.each{|aid|ok=@ability_trigger_counts[aid].to_i>0; assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)}; log("------------------------------------------------------------"); result=@failures.empty? ? "PASS" : "FAIL"; log("RESULT="+result); passed=HANDLED_ABILITY_IDS.select{|x|@ability_trigger_counts[x].to_i>0}.size; log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_ao="+passed.to_s+"/8 stat_checks="+@stat_checks.to_s+" evasion_checks="+@evasion_checks.to_s+" sleep_checks="+@sleep_checks.to_s+" debuff_checks="+@debuff_checks.to_s+" scope_checks="+@scope_checks.to_s+" action_checks="+@action_checks.to_s+" pending=45"); @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); end
    def self.reset_suite; @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @stat_checks=0; @evasion_checks=0; @sleep_checks=0; @debuff_checks=0; @scope_checks=0; @action_checks=0; @forced_proc={}; end
    def self.reset_log; h="CG POKEMON ABILITY AO CONQUEST AURA + CONTROL AUTO REGRESSION v2.5.40a\r\n"+"START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+"RULE=Actual Scene_Battle; terrain stat/evasion + sleep aura + Speed/Accuracy debuff authority\r\n"+"BASELINE=v2.5.39a Ability Batch AN RPG Maker VX real-machine PASS; Move pending=0\r\n"+"ABILITY_CATALOG=373 BATCH_A_TO_AN_PASS=320 BATCH_AO=8 PENDING=45\r\n"+"RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+"------------------------------------------------------------\r\n"; File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}; rescue; end
    def self.start_auto_test; return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AO_v2.5.40a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID); rescue=>e; @failures||=[]; @failures<<"AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s; log(@failures[-1]); @active=false; false; end
  end
end
ALBERT_CG::ABILITY_AO_V2540.register_handlers if defined?(ALBERT_CG::ABILITY_AO_V2540)
class Game_Battler
  alias cg_v2540ao_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed; if defined?(ALBERT_CG::ABILITY_AO_V2540)&&ALBERT_CG::ABILITY_AO_V2540.active?&&@cg_priority_test_speed_override_ao!=nil; return @cg_priority_test_speed_override_ao.to_i; end; cg_v2540ao_priority_base_speed; rescue; cg_v2540ao_priority_base_speed; end
end
class Scene_Battle < Scene_Base
  alias cg_v2540ao_execute_action execute_action
  def execute_action; ALBERT_CG::ABILITY_AO_V2540.record_execution(@active_battler) if defined?(ALBERT_CG::ABILITY_AO_V2540)&&ALBERT_CG::ABILITY_AO_V2540.active?; cg_v2540ao_execute_action; end
  alias cg_v2540ao_turn_end turn_end
  def turn_end; if defined?(ALBERT_CG::ABILITY_AO_V2540)&&ALBERT_CG::ABILITY_AO_V2540.active?; if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_AO_V2540.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_AO_V2540.finish_round_assertions; end; end; cg_v2540ao_turn_end; end
  alias cg_v2540ao_start_party_command start_party_command_selection
  def start_party_command_selection; unless defined?(ALBERT_CG::ABILITY_AO_V2540)&&ALBERT_CG::ABILITY_AO_V2540.active?; return cg_v2540ao_start_party_command; end; cg_v2540ao_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_AO_V2540.assert_bootstrap_once; if ALBERT_CG::ABILITY_AO_V2540.finished?; ALBERT_CG::ABILITY_AO_V2540.finish_suite; battle_end(0); return; end; ALBERT_CG::ABILITY_AO_V2540.prepare_round_actions; start_main; end
end
class Game_Enemy < Game_Battler
  alias cg_v2540ao_enemy_make_action make_action
  def make_action; if defined?(ALBERT_CG::ABILITY_AO_V2540)&&ALBERT_CG::ABILITY_AO_V2540.active?; a=ALBERT_CG::ABILITY_AO_V2540.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end; end; cg_v2540ao_enemy_make_action; end
end
module ALBERT_CG; class << self
  alias cg_v2540ao_bootstrap_demo_party bootstrap_demo_party
  def bootstrap_demo_party; r=cg_v2540ao_bootstrap_demo_party; if defined?(ALBERT_CG::ABILITY_AO_V2540)&&ALBERT_CG::ABILITY_AO_V2540.active?; ALBERT_CG::ABILITY_AO_V2540::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AO_V2540.configure_actor(c)}; h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_AO_V2540::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,ALBERT_CG::ABILITY_AO_V2540::ABILITY_SEQUENCE); end; end; r; end
end; end
if defined?(ALBERT_CG::ABILITY_AN_V2539); module ALBERT_CG; module ABILITY_AN_V2539; def self.f11_trigger?; false; end; end; end; end
class Scene_Map < Scene_Base
  alias cg_v2540ao_scene_map_update update
  def update; cg_v2540ao_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_AO_V2540); ALBERT_CG::ABILITY_AO_V2540.start_auto_test if ALBERT_CG::ABILITY_AO_V2540.f11_trigger?; end
end
