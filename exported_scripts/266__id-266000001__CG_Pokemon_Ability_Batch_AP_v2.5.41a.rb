# RMVX_SCRIPT_INDEX: 266
# RMVX_SCRIPT_ID: 266000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AP v2.5.41a
# RMVX_SOURCE_SHA256: 94811d0e55d8ac0fde91e8d534f7d8b31ee95fee914604e15977c5eb94613bfe

#==============================================================================
# ■ CG Pokemon Ability Batch AP v2.5.41a - Conquest Team Aura + Economy + Disruption TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.40a Ability Batch AO RPG Maker VX 實機 PASS 為唯一正式基底，收斂
#  Pokémon Conquest 的隊伍 Energy/Defense Aura、Fire/Water team boost、金錢型能力、
#  KO 爆炸與命中後干擾。沿用既有六維能力值、final damage、gold_total、KO/stat-stage
#  Authority，不另造平行傷害或能力階級系統。
#
# 【本批 Ability】
#  10041 Mood Maker：附近隊友 Energy +1 turn。CG 以 Conquest High Energy 1.05 倍
#    映射為 active allies ATK/DEF/SPA/SPD/SPE x105%，holder 自己不吃自己的 aura。
#  10042 Confidence：附近隊友 Defense 提升。CG 沿 Conquest passive-aura 慣例採 DEF x120%。
#  10043 Fortune：Conquest 增加 treasure gold；CG 映射 battle gold +25%。
#  10044 Bonanza：更強 treasure gold；CG 映射 battle gold +50%。同側多來源不相乘，取最高。
#  10045 Explode：holder 被 KO 後可能爆炸。CG 沿 Conquest proc 慣例 30%，
#    以 active opposing battle group 為周圍區域，每個目標 loss=floor(holder MaxHP/4)。
#  10054 Flame Boost：active ally 的 Fire damaging Move final damage x120%，holder 自己不吃。
#  10055 Aqua Boost：active ally 的 Water damaging Move final damage x120%，holder 自己不吃。
#  10058 Shackle：原作降低被命中敵人的 movement Range；CG 無 tile Range，明確映射為
#    successful damaging hit 後 target SPE -1 stage（只做 mobility/tempo proxy）。
#
# 【F11】Troop 744，三回合 Actual Scene_Battle：
#  R1：Mood/Confidence stat query；Bonanza gold +50%；enemy teammate Fire/Water 分別吃
#      Flame/Aqua Boost；Shackle 真實 Water Gun 後 SPE -1。
#  R2：Fortune gold +25%；A0 Water Gun 真實 KO Explode holder，forced proc=true，
#      爆炸傷害 active allies。
#  R3：Fortune+Bonanza 同時存在只取最高 +50%；Mood/Confidence holder 暫停後 aura 關閉；
#      再次 KO Explode holder但 forced proc=false，確認無爆炸。
#==============================================================================
$imported={} if $imported==nil
$imported["ALBERT_CG_PokemonAbilityBatchAP"]="2.5.41a"
module ALBERT_CG
  module ABILITY_AP_V2541
    VERSION="2.5.41a"; TEST_LEVEL=40; TEST_TROOP_ID=744; VK_F11=0x7A
    ABILITY_MOOD_MAKER=10041; ABILITY_CONFIDENCE=10042; ABILITY_FORTUNE=10043; ABILITY_BONANZA=10044
    ABILITY_EXPLODE=10045; ABILITY_FLAME_BOOST=10054; ABILITY_AQUA_BOOST=10055; ABILITY_SHACKLE=10058
    HANDLED_ABILITY_IDS=[10041,10042,10043,10044,10045,10054,10055,10058]
    MOOD_PERCENT=105; CONFIDENCE_PERCENT=120; TEAM_DAMAGE_PERCENT=120
    FORTUNE_PERCENT=125; BONANZA_PERCENT=150; EXPLODE_DENOM=4; PROC_CHANCE=30; TEST_GOLD_REWARD=120
    TEST_ALLIES=[
      {:dex=>143,:level=>40,:ability=>ABILITY_CONFIDENCE,:moves=>[150,150,150]},
      {:dex=>65,:level=>40,:ability=>ABILITY_FORTUNE,:moves=>[150,150,150]},
      {:dex=>18,:level=>40,:ability=>ABILITY_BONANZA,:moves=>[150,150,150]}]
    TEST_ENEMIES=[
      {:dex=>143,:level=>45,:ability=>ABILITY_FLAME_BOOST,:moves=>[150,150,150]},
      {:dex=>383,:level=>45,:ability=>ABILITY_AQUA_BOOST,:moves=>[150,150,150]},
      {:dex=>384,:level=>45,:ability=>ABILITY_EXPLODE,:moves=>[52,150,150]},
      {:dex=>92,:level=>45,:ability=>ABILITY_SHACKLE,:moves=>[55,55,55]}]
    ROUND_PLANS=[
      {:name=>"AURA_BONANZA_TEAM_DAMAGE_SHACKLE",:allies=>[
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>0},1=>{:kind=>:move,:move_id=>150,:target=>0},2=>{:kind=>:move,:move_id=>52,:target=>0},3=>{:kind=>:move,:move_id=>55,:target=>1}}},
      {:name=>"FORTUNE_EXPLODE_PROC",:allies=>[
        {:kind=>:move,:move_id=>55,:target=>2},{:kind=>:move,:move_id=>150,:target=>0},
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>0},1=>{:kind=>:move,:move_id=>150,:target=>0},2=>{:kind=>:move,:move_id=>150,:target=>0},3=>{:kind=>:move,:move_id=>55,:target=>1}}},
      {:name=>"STRONGEST_GOLD_AURA_OFF_EXPLODE_FALSE",:allies=>[
        {:kind=>:move,:move_id=>55,:target=>2},{:kind=>:move,:move_id=>150,:target=>0},
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>0},1=>{:kind=>:move,:move_id=>150,:target=>0},2=>{:kind=>:move,:move_id=>150,:target=>0},3=>{:kind=>:move,:move_id=>55,:target=>1}}}]
    EXPECTED_EXECUTION_TOKENS={
      1=>["A0:M150","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M52","E3:M55"],
      2=>["A0:M55","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E3:M55"],
      3=>["A0:M55","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E3:M55"]}
    TEST_SPEEDS={1=>[900,850,800,750,600,550,500,450],2=>[900,850,800,750,600,550,500,450],3=>[900,850,800,750,600,550,500,450]}
    begin; KEY_API=Win32API.new("user32","GetAsyncKeyState","i","i"); rescue; KEY_API=nil; end
    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.modifier; defined?(ALBERT_CG::ABILITY_MODIFIER_V253) ? ALBERT_CG::ABILITY_MODIFIER_V253 : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party ? $game_party.members : []; end
    def self.all_enemies; $game_troop ? $game_troop.members : []; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AP_AutoTest_v2_5_41a.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(p,t,m="ab"); File.open(p,m){|f|f.write(t.to_s+"\r\n")}; true; rescue; false; end
    def self.log(t); write_line(log_path,t); write_line(latest_log_path,t); rescue; end
    def self.key_down?(c); KEY_API && (KEY_API.call(c)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.ability_id(b); core&&b ? core.ability_id(b).to_i : 0; rescue; 0; end
    def self.type_id(sym); defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_id(sym).to_i : 0; rescue; 0; end
    def self.action_type_id(user,skill); modifier&&modifier.respond_to?(:type_id_for_action) ? modifier.type_id_for_action(user,skill).to_i : 0; rescue; 0; end
    def self.assert_true(label,cond,detail=nil); if cond; log("ASSERT PASS "+label.to_s+(detail ? " "+detail.to_s : "")); else; x=label.to_s+(detail ? " "+detail.to_s : ""); @failures<<x; log("ASSERT FAIL "+x); end; cond; end
    def self.note_local(aid,b,kind,data=nil); rec={:ability=>aid.to_i,:kind=>kind}; (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill,:action].include?(k)}; if active?; @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1; (@records[aid.to_i]||=[])<<rec; log("ABILITY_AP_TRIGGER ability="+aid.to_s+" battler="+(b ? b.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect); end; rec; rescue; nil; end
    def self.records_for(aid,kind=nil); a=@records[aid.to_i]||[]; kind ? a.select{|x|x[:kind].to_sym==kind.to_sym} : a; rescue; []; end
    def self.active_members_for(b); u=b&&b.actor? ? $game_party : $game_troop; u ? u.members.select{|x|x&&!x.hidden&&x.hp.to_i>0} : []; rescue; []; end
    def self.same_side?(a,b); a && b && a.actor? == b.actor?; rescue; false; end
    def self.set_ability(b,aid); b.instance_variable_set(:@cg_master_ability_id,aid.to_i) if b; end
    def self.holder_for(target,aid); active_members_for(target).find{|h|!h.equal?(target)&&ability_id(h)==aid.to_i}; rescue; nil; end
    def self.apply_team_stat_aura(target,stat,value)
      v=value.to_i; return v if target==nil||v<=0
      mood=holder_for(target,ABILITY_MOOD_MAKER)
      if mood
        before=v; v=[v*MOOD_PERCENT/100,1].max; note_local(ABILITY_MOOD_MAKER,mood,:mood_maker,{:target_index=>target.index.to_i,:stat=>stat,:before=>before,:after=>v,:percent=>MOOD_PERCENT})
      end
      conf=holder_for(target,ABILITY_CONFIDENCE)
      if conf&&stat.to_sym==:def
        before=v; v=[v*CONFIDENCE_PERCENT/100,1].max; note_local(ABILITY_CONFIDENCE,conf,:confidence,{:target_index=>target.index.to_i,:stat=>stat,:before=>before,:after=>v,:percent=>CONFIDENCE_PERCENT})
      end
      v
    rescue; value.to_i; end
    def self.apply_team_damage_aura(user,target,skill,damage)
      d=damage.to_i; return d if user==nil||target==nil||skill==nil||d<=0
      tid=action_type_id(user,skill); aid=nil; holder=nil
      if tid==type_id(:fire); aid=ABILITY_FLAME_BOOST; holder=holder_for(user,aid)
      elsif tid==type_id(:water); aid=ABILITY_AQUA_BOOST; holder=holder_for(user,aid)
      end
      return d unless holder
      after=[d*TEAM_DAMAGE_PERCENT/100,1].max
      note_local(aid,holder,(aid==ABILITY_FLAME_BOOST ? :flame_boost : :aqua_boost),{:source_index=>user.index.to_i,:target_index=>target.index.to_i,:move_id=>move_id(skill),:before=>d,:after=>after,:percent=>TEAM_DAMAGE_PERCENT})
      after
    rescue; damage.to_i; end
    def self.change_stage(source,target,key,amount); return 0 unless target&&target.respond_to?(:cg_change_stat_stage); auth=defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) ? ALBERT_CG::ABILITY_STAT_GUARD_V256 : nil; return auth.with_stage_source(source,:ability,false){target.cg_change_stat_stage(key,amount).to_i} if auth&&auth.respond_to?(:with_stage_source); target.cg_change_stat_stage(key,amount).to_i; rescue; 0; end
    def self.apply_shackle(user,target,skill,damage_done)
      return false unless user&&target&&skill&&damage_done.to_i>0&&ability_id(user)==ABILITY_SHACKLE&&user.actor?!=target.actor?
      before=target.respond_to?(:cg_stat_stage) ? target.cg_stat_stage(:spe).to_i : 0; delta=change_stage(user,target,:spe,-1); after=target.respond_to?(:cg_stat_stage) ? target.cg_stat_stage(:spe).to_i : before
      return false if delta==0; note_local(ABILITY_SHACKLE,user,:shackle,{:target_index=>target.index.to_i,:move_id=>move_id(skill),:before=>before,:after=>after,:delta=>delta}); true
    rescue; false; end
    def self.proc_success?(aid); return @forced_proc[aid.to_i] if active?&&@forced_proc&&@forced_proc.has_key?(aid.to_i); rand(100)<PROC_CHANCE; rescue; false; end
    def self.apply_explode(holder)
      return false unless holder&&ability_id(holder)==ABILITY_EXPLODE&&proc_success?(ABILITY_EXPLODE)
      foes=holder.actor? ? ($game_troop ? $game_troop.members : []) : ($game_party ? $game_party.members : [])
      hits=[]; foes.each{|t|next if t==nil||t.hidden||t.hp.to_i<=0; before=t.hp.to_i; loss=[holder.maxhp.to_i/EXPLODE_DENOM,1].max; t.hp=[before-loss,0].max; actual=before-t.hp.to_i; hits<<[t.index.to_i,actual]; if before>0&&t.hp.to_i<=0&&core; core.dispatch(:ko,t,{:user=>holder,:target=>t,:reason=>:ability_explode,:damage_done=>actual}); end}
      return false if hits.empty?; note_local(ABILITY_EXPLODE,holder,:explode,{:targets=>hits.inspect,:loss_each=>[holder.maxhp.to_i/EXPLODE_DENOM,1].max,:total_damage=>hits.inject(0){|n,x|n+x[1].to_i}}); true
    rescue; false; end
    def self.gold_bonus_percent
      return [100,nil,0] unless $game_party
      best=100; holder=nil; aid=0
      $game_party.members.each{|b|next if b==nil||b.hidden||b.hp.to_i<=0; x=ability_id(b); if x==ABILITY_BONANZA&&BONANZA_PERCENT>best; best=BONANZA_PERCENT; holder=b; aid=x; elsif x==ABILITY_FORTUNE&&FORTUNE_PERCENT>best; best=FORTUNE_PERCENT; holder=b; aid=x; end}
      [best,holder,aid]
    rescue; [100,nil,0]; end
    def self.apply_gold_bonus(base)
      p,h,aid=gold_bonus_percent; return base.to_i if p.to_i<=100||h==nil; after=base.to_i*p.to_i/100; note_local(aid,h,(aid==ABILITY_BONANZA ? :bonanza : :fortune),{:before=>base.to_i,:after=>after,:percent=>p.to_i}); after
    rescue; base.to_i; end
    def self.clear_runtime(b); b.instance_variable_set(:@cg_priority_test_speed_override_ap,nil) if b; end
    def self.configure_actor(cfg); a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return unless a; master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); clear_runtime(a); end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end
    def self.prepare_test_party; ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}; ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS); $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true); $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!); TEST_ALLIES.each{|c|configure_actor(c)}; h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); clear_runtime(h); set_ability(h,ABILITY_MOOD_MAKER); mids=[150,55]; sids=mids.collect{|m|master.skill_id_for_move(m)}; h.instance_variable_set(:@cg_equipped_skill_ids,sids); h.instance_variable_set(:@cg_skill_slot_ids,sids); h.instance_variable_set(:@skills,sids); end; end
    def self.make_test_troop; master.ensure_index($data_troops,TEST_TROOP_ID); xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X]; ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0]]; ms=[]; TEST_ENEMIES.each_with_index{|c,i|configure_enemy(c); ms<<ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i])}; $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AP v2.5.41 AutoRegression",ms); end
    def self.make_action(b,c); a=Game_BattleAction.new(b); c[:kind]==:guard ? a.set_guard : a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); a.target_index=c[:target].to_i if c.has_key?(:target); a; end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; p=current_plan; return nil unless p&&p[:enemies]; c=p[:enemies][e.index]; c ? make_action(e,c) : nil; end
    def self.action_token(b); return "nil" unless b; s=b.actor? ? "A" : "E"; a=b.action; return s+b.index.to_s+":Guard" if a&&a.guard?; return s+b.index.to_s+":M"+move_id(a.skill).to_s if a&&a.skill?; s+b.index.to_s+":Other"; rescue; "?"; end
    def self.record_execution(b); @actual<<action_token(b) if active?; log("ACTION_EXEC #"+@actual.size.to_s+" "+(b ? b.name.to_s : "nil")+" token="+@actual[-1].to_s) if active?; end
    def self.apply_test_speeds; sp=TEST_SPEEDS[current_round]||[]; (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_ap,sp[i]) if b&&sp[i]!=nil}; end
    def self.restore_base_abilities; a=test_allies; e=all_enemies; set_ability(a[0],ABILITY_MOOD_MAKER); set_ability(a[1],ABILITY_CONFIDENCE); set_ability(a[2],ABILITY_FORTUNE); set_ability(a[3],ABILITY_BONANZA); set_ability(e[0],ABILITY_FLAME_BOOST); set_ability(e[1],ABILITY_AQUA_BOOST); set_ability(e[2],ABILITY_EXPLODE); set_ability(e[3],ABILITY_SHACKLE); end
    def self.base_gold; $game_troop&&$game_troop.respond_to?(:cg_v2541ap_gold_total_base) ? $game_troop.cg_v2541ap_gold_total_base.to_i : 0; rescue; 0; end
    # Economy regression must probe the real VX reward chain with a defeated enemy.
    # Game_Troop#gold_total is zero while every enemy is still alive, so temporarily
    # mark a neutral fixture enemy defeated and give its database reward a deterministic
    # positive value. Restore both fields immediately; this does not dispatch KO hooks.
    def self.gold_probe
      troop=$game_troop; enemy=all_enemies[0]
      return [0,0] unless troop&&enemy&&enemy.respond_to?(:enemy_id)
      data=$data_enemies ? $data_enemies[enemy.enemy_id] : nil
      return [0,0] unless data
      old_hp=enemy.hp.to_i; old_gold=data.gold.to_i
      begin
        data.gold=TEST_GOLD_REWARD
        enemy.hp=0
        base=base_gold
        actual=troop.gold_total.to_i
        log("GOLD_PROBE enemy="+enemy.index.to_i.to_s+" reward="+TEST_GOLD_REWARD.to_s+" base="+base.to_s+" actual="+actual.to_s)
        [base,actual]
      rescue=>ex
        log("GOLD_PROBE_ERROR "+ex.class.to_s+":"+ex.message.to_s)
        [0,0]
      ensure
        begin; enemy.hp=old_hp; data.gold=old_gold; rescue; end
      end
    end
    def self.prepare_round_fixture
      a=test_allies; e=all_enemies; r=current_round; restore_base_abilities; (a+e).each{|b|b.cg_reset_stat_stages if b&&b.respond_to?(:cg_reset_stat_stages)}; @forced_proc={}; @round_counts={}; HANDLED_ABILITY_IDS.each{|id|@round_counts[id]=records_for(id).size}
      if r==1
        set_ability(a[2],0); @forced_proc[ABILITY_EXPLODE]=false
        set_ability(a[0],0); set_ability(a[1],0); @r1_base_atk=a[2].cg_atk_stat.to_i; @r1_base_def=a[2].cg_def_stat.to_i
        set_ability(a[0],ABILITY_MOOD_MAKER); @r1_mood_atk=a[2].cg_atk_stat.to_i
        set_ability(a[0],0); set_ability(a[1],ABILITY_CONFIDENCE); @r1_conf_def=a[2].cg_def_stat.to_i
        set_ability(a[0],ABILITY_MOOD_MAKER); set_ability(a[1],ABILITY_CONFIDENCE)
        @gold_base,@gold_actual=gold_probe; log("ROUND1_PROBE mood="+@r1_base_atk.to_s+"->"+@r1_mood_atk.to_s+" confidence="+@r1_base_def.to_s+"->"+@r1_conf_def.to_s+" gold="+@gold_base.to_s+"->"+@gold_actual.to_s)
      elsif r==2
        set_ability(a[3],0); @forced_proc[ABILITY_EXPLODE]=true; e[2].hp=1 if e[2]; @gold_base,@gold_actual=gold_probe; @explode_before=records_for(ABILITY_EXPLODE,:explode).size; log("ROUND2_PROBE fortune_gold="+@gold_base.to_s+"->"+@gold_actual.to_s+" E2_hp=1 explode=true")
      else
        @forced_proc[ABILITY_EXPLODE]=false; e[2].hp=1 if e[2]; @gold_base,@gold_actual=gold_probe; @explode_before=records_for(ABILITY_EXPLODE,:explode).size
        set_ability(a[0],0); set_ability(a[1],0); @r3_atk=a[2].cg_atk_stat.to_i; @r3_def=a[2].cg_def_stat.to_i; log("ROUND3_PROBE strongest_gold="+@gold_base.to_s+"->"+@gold_actual.to_s+" aura_off atk="+@r3_atk.to_s+" def="+@r3_def.to_s+" explode=false")
      end
    end
    def self.prepare_round_actions; prepare_round_fixture; apply_test_speeds; @actual=[]; a=test_allies; p=current_plan; return false unless p; p[:allies].each_with_index{|cfg,i|next unless a[i]&&a[i].hp.to_i>0; act=make_action(a[i],cfg); a[i].instance_variable_set(:@cg_round_actions,[act]); a[i].cg_assign_action(act) if a[i].respond_to?(:cg_assign_action); a[i].instance_variable_set(:@action,act) unless a[i].respond_to?(:cg_assign_action)}; log("ROUND "+current_round.to_s+" BEGIN "+p[:name]); true; end
    def self.assert_order; exp=EXPECTED_EXECUTION_TOKENS[current_round]||[]; ok=@actual==exp; @action_checks+=1 if ok; assert_true("Round"+current_round.to_s+" execution order matches deterministic plan",ok,"expected="+exp.inspect+" actual="+@actual.inspect); end
    def self.assert_bootstrap_once; return if @boot_asserted; @boot_asserted=true; assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil")); assert_true("Ability Batch AP defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s); assert_true("Scene_Battle uses Ability AP test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil")); assert_true("Ability AP ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s); assert_true("Ability AP enemy count=4",all_enemies.size==4,"actual="+all_enemies.size.to_s); end
    def self.finish_round_assertions
      assert_order; a=test_allies; e=all_enemies; r=current_round
      if r==1
        mood=@r1_mood_atk==[@r1_base_atk*MOOD_PERCENT/100,1].max; @aura_checks+=1 if mood; assert_true("Mood Maker gives ally exact +5% Energy proxy",mood,"atk="+@r1_base_atk.to_s+"->"+@r1_mood_atk.to_s)
        conf=@r1_conf_def==[@r1_base_def*CONFIDENCE_PERCENT/100,1].max; @aura_checks+=1 if conf; assert_true("Confidence gives ally exact +20% DEF proxy",conf,"def="+@r1_base_def.to_s+"->"+@r1_conf_def.to_s)
        frec=records_for(ABILITY_FLAME_BOOST,:flame_boost)[-1]||{}; fb=records_for(ABILITY_FLAME_BOOST,:flame_boost).size>@round_counts[ABILITY_FLAME_BOOST]&&frec[:before].to_i>0&&frec[:after].to_i==[frec[:before].to_i*TEAM_DAMAGE_PERCENT/100,1].max; @damage_checks+=1 if fb; assert_true("Flame Boost powers teammate real Fire Move exactly +20%",fb,frec.inspect)
        arec=records_for(ABILITY_AQUA_BOOST,:aqua_boost)[-1]||{}; ab=records_for(ABILITY_AQUA_BOOST,:aqua_boost).size>@round_counts[ABILITY_AQUA_BOOST]&&arec[:before].to_i>0&&arec[:after].to_i==[arec[:before].to_i*TEAM_DAMAGE_PERCENT/100,1].max; @damage_checks+=1 if ab; assert_true("Aqua Boost powers teammate real Water Move exactly +20%",ab,arec.inspect)
        sh=records_for(ABILITY_SHACKLE,:shackle).size>@round_counts[ABILITY_SHACKLE]&&a[1]&&a[1].cg_stat_stage(:spe).to_i==-1; @reaction_checks+=1 if sh; assert_true("Shackle damaging hit applies CG mobility proxy SPE -1",sh,(records_for(ABILITY_SHACKLE,:shackle)[-1]||{}).inspect)
        gold=@gold_base>0&&@gold_actual==@gold_base*BONANZA_PERCENT/100; @economy_checks+=1 if gold; assert_true("Bonanza maps to battle gold +50%",gold,"base="+@gold_base.to_s+" actual="+@gold_actual.to_s)
      elsif r==2
        gold=@gold_base>0&&@gold_actual==@gold_base*FORTUNE_PERCENT/100; @economy_checks+=1 if gold; assert_true("Fortune maps to battle gold +25%",gold,"base="+@gold_base.to_s+" actual="+@gold_actual.to_s)
        xrec=records_for(ABILITY_EXPLODE,:explode)[-1]||{}; expected_loss=e[2] ? [e[2].maxhp.to_i/EXPLODE_DENOM,1].max : 0; ex=records_for(ABILITY_EXPLODE,:explode).size>@explode_before&&xrec[:loss_each].to_i==expected_loss&&xrec[:total_damage].to_i>0; @reaction_checks+=1 if ex; assert_true("Explode forced proc fires after holder real KO at MaxHP/4 blast",ex,xrec.inspect)
      else
        gold=@gold_base>0&&@gold_actual==@gold_base*BONANZA_PERCENT/100; @economy_checks+=1 if gold; assert_true("Fortune + Bonanza do not stack; strongest +50% wins",gold,"base="+@gold_base.to_s+" actual="+@gold_actual.to_s)
        aura=@r3_atk>0&&@r3_def>0&&records_for(ABILITY_MOOD_MAKER,:mood_maker).size==@round_counts[ABILITY_MOOD_MAKER]&&records_for(ABILITY_CONFIDENCE,:confidence).size==@round_counts[ABILITY_CONFIDENCE]; @scope_checks+=1 if aura; assert_true("Mood Maker / Confidence turn off when holders are disabled",aura,"atk="+@r3_atk.to_s+" def="+@r3_def.to_s)
        noex=records_for(ABILITY_EXPLODE,:explode).size==@explode_before; @scope_checks+=1 if noex; assert_true("Explode forced no-proc leaves KO without blast",noex,"count="+records_for(ABILITY_EXPLODE,:explode).size.to_s)
      end
      log("ROUND "+r.to_s+" END"); @round_index+=1
    end
    def self.finish_suite; HANDLED_ABILITY_IDS.each{|aid|ok=@ability_trigger_counts[aid].to_i>0; assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)}; log("------------------------------------------------------------"); result=@failures.empty? ? "PASS" : "FAIL"; log("RESULT="+result); passed=HANDLED_ABILITY_IDS.select{|x|@ability_trigger_counts[x].to_i>0}.size; log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_ap="+passed.to_s+"/8 aura_checks="+@aura_checks.to_s+" damage_checks="+@damage_checks.to_s+" economy_checks="+@economy_checks.to_s+" reaction_checks="+@reaction_checks.to_s+" scope_checks="+@scope_checks.to_s+" action_checks="+@action_checks.to_s+" pending=37"); @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x)}; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); end
    def self.reset_suite; @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @aura_checks=0; @damage_checks=0; @economy_checks=0; @reaction_checks=0; @scope_checks=0; @action_checks=0; @forced_proc={}; end
    def self.reset_log; h="CG POKEMON ABILITY AP CONQUEST TEAM AURA + ECONOMY + DISRUPTION AUTO REGRESSION v2.5.41a\r\n"+"START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+"RULE=Actual Scene_Battle; team stat/damage aura + battle gold + KO explosion + hit disruption authority\r\n"+"BASELINE=v2.5.40a Ability Batch AO RPG Maker VX real-machine PASS; Move pending=0\r\n"+"ABILITY_CATALOG=373 BATCH_A_TO_AO_PASS=328 BATCH_AP=8 PENDING=37\r\n"+"RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+"------------------------------------------------------------\r\n"; File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}; rescue; end
    def self.start_auto_test; return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AP_v2.5.41a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID); rescue=>e; @failures||=[]; @failures<<"AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s; log(@failures[-1]); @active=false; false; end
  end
end

class Game_Battler
  alias cg_v2541ap_team_atk cg_atk_stat
  def cg_atk_stat; v=cg_v2541ap_team_atk; defined?(ALBERT_CG::ABILITY_AP_V2541) ? ALBERT_CG::ABILITY_AP_V2541.apply_team_stat_aura(self,:atk,v) : v; end
  alias cg_v2541ap_team_def cg_def_stat
  def cg_def_stat; v=cg_v2541ap_team_def; defined?(ALBERT_CG::ABILITY_AP_V2541) ? ALBERT_CG::ABILITY_AP_V2541.apply_team_stat_aura(self,:def,v) : v; end
  alias cg_v2541ap_team_spa cg_spa
  def cg_spa; v=cg_v2541ap_team_spa; defined?(ALBERT_CG::ABILITY_AP_V2541) ? ALBERT_CG::ABILITY_AP_V2541.apply_team_stat_aura(self,:spa,v) : v; end
  alias cg_v2541ap_team_spd cg_spd
  def cg_spd; v=cg_v2541ap_team_spd; defined?(ALBERT_CG::ABILITY_AP_V2541) ? ALBERT_CG::ABILITY_AP_V2541.apply_team_stat_aura(self,:spd,v) : v; end
  alias cg_v2541ap_team_speed cg_priority_base_speed
  def cg_priority_base_speed; v=(@cg_priority_test_speed_override_ap!=nil && defined?(ALBERT_CG::ABILITY_AP_V2541)&&ALBERT_CG::ABILITY_AP_V2541.active?) ? @cg_priority_test_speed_override_ap.to_i : cg_v2541ap_team_speed; defined?(ALBERT_CG::ABILITY_AP_V2541) ? ALBERT_CG::ABILITY_AP_V2541.apply_team_stat_aura(self,:spe,v) : v; rescue; cg_v2541ap_team_speed; end
  alias cg_v2541ap_execute_damage execute_damage
  def execute_damage(user)
    skill=defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.current_skill(user) : nil
    if defined?(ALBERT_CG::ABILITY_AP_V2541)&&user&&@hp_damage.to_i>0; @hp_damage=ALBERT_CG::ABILITY_AP_V2541.apply_team_damage_aura(user,self,skill,@hp_damage.to_i); end
    hp_before=hp.to_i; aid_before=defined?(ALBERT_CG::ABILITY_AP_V2541) ? ALBERT_CG::ABILITY_AP_V2541.ability_id(self) : 0
    result=cg_v2541ap_execute_damage(user)
    if defined?(ALBERT_CG::ABILITY_AP_V2541)
      done=[hp_before-hp.to_i,0].max; ALBERT_CG::ABILITY_AP_V2541.apply_shackle(user,self,skill,done) if done>0
      ALBERT_CG::ABILITY_AP_V2541.apply_explode(self) if hp_before>0&&hp.to_i<=0&&aid_before==ALBERT_CG::ABILITY_AP_V2541::ABILITY_EXPLODE
    end
    result
  end
end
class Game_Troop < Game_Unit
  alias cg_v2541ap_gold_total_base gold_total
  def gold_total; v=cg_v2541ap_gold_total_base; defined?(ALBERT_CG::ABILITY_AP_V2541) ? ALBERT_CG::ABILITY_AP_V2541.apply_gold_bonus(v) : v; end
end
class Scene_Battle < Scene_Base
  alias cg_v2541ap_execute_action execute_action
  def execute_action; ALBERT_CG::ABILITY_AP_V2541.record_execution(@active_battler) if defined?(ALBERT_CG::ABILITY_AP_V2541)&&ALBERT_CG::ABILITY_AP_V2541.active?; cg_v2541ap_execute_action; end
  alias cg_v2541ap_turn_end turn_end
  def turn_end; if defined?(ALBERT_CG::ABILITY_AP_V2541)&&ALBERT_CG::ABILITY_AP_V2541.active?; ALBERT_CG::ABILITY_AP_V2541.finish_round_assertions; end; cg_v2541ap_turn_end; end
  alias cg_v2541ap_start_party_command start_party_command_selection
  def start_party_command_selection; unless defined?(ALBERT_CG::ABILITY_AP_V2541)&&ALBERT_CG::ABILITY_AP_V2541.active?; return cg_v2541ap_start_party_command; end; cg_v2541ap_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_AP_V2541.assert_bootstrap_once; if ALBERT_CG::ABILITY_AP_V2541.finished?; ALBERT_CG::ABILITY_AP_V2541.finish_suite; battle_end(0); return; end; ALBERT_CG::ABILITY_AP_V2541.prepare_round_actions; start_main; end
end
class Game_Enemy < Game_Battler
  alias cg_v2541ap_enemy_make_action make_action
  def make_action; if defined?(ALBERT_CG::ABILITY_AP_V2541)&&ALBERT_CG::ABILITY_AP_V2541.active?; a=ALBERT_CG::ABILITY_AP_V2541.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end; end; cg_v2541ap_enemy_make_action; end
end
module ALBERT_CG; class << self
  alias cg_v2541ap_bootstrap_demo_party bootstrap_demo_party
  def bootstrap_demo_party; r=cg_v2541ap_bootstrap_demo_party; if defined?(ALBERT_CG::ABILITY_AP_V2541)&&ALBERT_CG::ABILITY_AP_V2541.active?; ALBERT_CG::ABILITY_AP_V2541::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AP_V2541.configure_actor(c)}; h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_AP_V2541::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); ALBERT_CG::ABILITY_AP_V2541.set_ability(h,ALBERT_CG::ABILITY_AP_V2541::ABILITY_MOOD_MAKER); end; end; r; end
end; end
if defined?(ALBERT_CG::ABILITY_AO_V2540); module ALBERT_CG; module ABILITY_AO_V2540; def self.f11_trigger?; false; end; end; end; end
class Scene_Map < Scene_Base
  alias cg_v2541ap_scene_map_update update
  def update; cg_v2541ap_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_AP_V2541); ALBERT_CG::ABILITY_AP_V2541.start_auto_test if ALBERT_CG::ABILITY_AP_V2541.f11_trigger?; end
end
