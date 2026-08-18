# RMVX_SCRIPT_INDEX: 268
# RMVX_SCRIPT_ID: 268
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AR v2.5.43a
# RMVX_SOURCE_SHA256: 8a2fa5c767bccbdb3db7fa80fbb2fc044855043836d76e8419fec5783e6d2926

#==============================================================================
# ■ CG Pokemon Ability Batch AR v2.5.43a
#------------------------------------------------------------------------------
# 【用途】
#  Ability 345..352 coverage batch：Conquest Mobility / Position Authority。
#  以既有 CG 前後排三列 Battlefield Grid、Field Weather、Teleport 與 Ability Core
#  為唯一正式 Authority，不建立第二套地圖或戰棋座標系。
#
# 【本批 Ability】
#  10002 Wave Rider / 10003 Skater / 10005 Perception / 10048 Black Hole
#  10049 Shadow Dash / 10050 Sprint / 10052 High-rise / 10053 Climber
#
# 【CG 適配】
#  - Conquest Range +1 => CG SPE ×1.20；Range +2 => CG SPE ×1.40。
#  - Water tile => Rain/Heavy Rain；Ice tile => Hail/Snow。
#  - Shadow Dash「附近無其他 Pokémon」=> CG 三列戰場中，holder 所在 column 無其他 active battler。
#  - CG row elevation：back row = high ground；front row = low ground。
#    High-rise：back -> front damage ×1.20；Climber：front -> back damage ×1.20。
#  - Perception：同側隊友 damaging Move 完全迴避。
#  - Black Hole：CG 沒有 tile movement，因此映射為 active holder 阻止敵方 voluntary Teleport；
#    已封版 Run Away 仍可繞過。
#
# 【v2.5.43a 修正】
#  - 每回合於 Solo Trainer 正式 start 重排後重新套用 deterministic grid fixture。
#  - Round2/3 Teleport expected order 改依正式 Move Priority。
#  - 八個 Ability Runtime 規則不變。
#
# 【LEAN LOG 規則】
#  F11 後只需回傳：CG_AutoRegression_LATEST.log、PMD_BattleInitTrace.log。
#  其他暫時 *.log 在 suite 結束與 launcher 離開時清除。
#==============================================================================
$imported={} if $imported==nil
$imported["ALBERT_CG_PokemonAbilityBatchAR"]="2.5.43a"
module ALBERT_CG
  module ABILITY_AR_V2543
    VERSION="2.5.43a"; TEST_LEVEL=40; TEST_TROOP_ID=746; VK_F11=0x7A
    ABILITY_WAVE_RIDER=10002; ABILITY_SKATER=10003; ABILITY_PERCEPTION=10005
    ABILITY_BLACK_HOLE=10048; ABILITY_SHADOW_DASH=10049; ABILITY_SPRINT=10050
    ABILITY_HIGH_RISE=10052; ABILITY_CLIMBER=10053; ABILITY_RUN_AWAY=50
    HANDLED_ABILITY_IDS=[10002,10003,10005,10048,10049,10050,10052,10053]
    RANGE1_PERCENT=120; RANGE2_PERCENT=140; POSITION_DAMAGE_PERCENT=120
    TEST_ALLIES=[
      {:dex=>134,:level=>40,:ability=>ABILITY_WAVE_RIDER,:moves=>[150,150,150]},
      {:dex=>363,:level=>40,:ability=>ABILITY_SKATER,:moves=>[150,150,150]},
      {:dex=>132,:level=>40,:ability=>ABILITY_BLACK_HOLE,:moves=>[150,150,150]}]
    TEST_ENEMIES=[
      {:dex=>53,:level=>45,:ability=>ABILITY_HIGH_RISE,:moves=>[55,100,100]},
      {:dex=>391,:level=>45,:ability=>ABILITY_CLIMBER,:moves=>[55,150,150]},
      {:dex=>461,:level=>45,:ability=>ABILITY_SHADOW_DASH,:moves=>[150,150,150]},
      {:dex=>442,:level=>45,:ability=>ABILITY_PERCEPTION,:moves=>[150,150,150]},
      {:dex=>65,:level=>45,:ability=>0,:moves=>[150,150,150]}]
    ROUND_PLANS=[
      {:name=>"RAIN_POSITION_PERCEPTION",:allies=>[
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>55,:target=>0},1=>{:kind=>:move,:move_id=>55,:target=>2},2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"SNOW_BLACK_HOLE",:allies=>[
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>100,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"CLEAR_SCOPE_TELEPORT",:allies=>[
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>100,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}}]
    EXPECTED_EXECUTION_TOKENS={
      1=>["A0:M150","A1:M150","A2:M150","A3:M150","E2:M150","E0:M55","E1:M55","E3:M150"],
      2=>["A0:M150","A2:M150","A1:M150","A3:M150","E1:M150","E2:M150","E3:M150","E0:M100"],
      3=>["A0:M150","A1:M150","A2:M150","A3:M150","E2:M150","E1:M150","E3:M150","E0:M100"]}
    TEST_SPEEDS={
      1=>[900,800,700,600, 500,450,400,350,100],
      2=>[900,800,700,600, 500,450,400,350,100],
      3=>[900,800,700,600, 500,450,400,350,100]}
    begin; KEY_API=Win32API.new("user32","GetAsyncKeyState","i","i"); rescue; KEY_API=nil; end
    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.field; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233 : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party ? $game_party.members : []; end
    def self.all_enemies; $game_troop ? $game_troop.members : []; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.log(t); File.open(latest_log_path,"ab"){|f|f.write(t.to_s+"\r\n")}; rescue; end
    def self.key_down?(c); KEY_API && (KEY_API.call(c)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.move_row(mid); master ? master.move(mid.to_i) : nil; rescue; nil; end
    def self.damaging_move?(skill); r=move_row(move_id(skill)); r!=nil&&r[7]!=:status&&r[3].to_i>0; rescue; false; end
    def self.ability_id(b); core&&b ? core.ability_id(b).to_i : 0; rescue; 0; end
    def self.raw_ability_id(b); return 0 unless b; return ALBERT_CG::ABILITY_AG_V2532.raw_ability_id(b).to_i if defined?(ALBERT_CG::ABILITY_AG_V2532); b.respond_to?(:cg_master_ability_id) ? b.cg_master_ability_id.to_i : 0; rescue; 0; end
    def self.same_side?(a,b); a&&b&&(a.actor? == b.actor?); rescue; false; end
    def self.opposing?(a,b); a&&b&&(a.actor? != b.actor?); rescue; false; end
    def self.assert_true(label,cond,detail=nil); if cond; log("ASSERT PASS "+label.to_s+(detail ? " "+detail.to_s : "")); else; x=label.to_s+(detail ? " "+detail.to_s : ""); @failures<<x; log("ASSERT FAIL "+x); end; cond; end
    def self.note_local(aid,b,kind,data=nil)
      rec={:ability=>aid.to_i,:kind=>kind}; (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill,:action].include?(k)}
      if active?; @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1; (@records[aid.to_i]||=[])<<rec; log("ABILITY_AR_TRIGGER ability="+aid.to_s+" battler="+(b ? b.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect); end
      rec
    rescue; nil; end
    def self.records_for(aid,kind=nil); a=@records[aid.to_i]||[]; kind ? a.select{|x|x[:kind].to_sym==kind.to_sym} : a; rescue; []; end
    def self.note_passive_once(aid,b,kind,data=nil)
      return nil unless active?; @passive_noted||={}; key=[@round_index.to_i,aid.to_i,b ? b.object_id : 0,kind]; return nil if @passive_noted[key]; @passive_noted[key]=true; note_local(aid,b,kind,data)
    end
    def self.set_ability(b,aid); return unless b; b.instance_variable_set(:@cg_v237_ability_override,nil); b.instance_variable_set(:@cg_v237_ability_suppressed,false); b.instance_variable_set(:@cg_master_ability_id,aid.to_i); end
    def self.set_weather(w,turns=5); return unless field&&field.state; field.state.weather=w; field.state.weather_turns=(w ? turns.to_i : 0); end
    def self.weather; field&&field.state ? field.state.weather : nil; rescue; nil; end
    def self.set_slot(b,row,col); b.cg_set_battle_slot(row,col,true) if b&&b.respond_to?(:cg_set_battle_slot); end
    def self.raw_speed(b); return 0 unless b; v=b.instance_variable_get(:@cg_priority_test_speed_override_ar); return v.to_i if active?&&v!=nil; return b.cg_v2543ar_priority_base_speed.to_i if b.respond_to?(:cg_v2543ar_priority_base_speed); b.agi.to_i; rescue; 0; end
    def self.isolated_lane?(b)
      return false unless b&&b.respond_to?(:cg_battle_column)&&b.cg_battle_column!=nil; col=b.cg_battle_column.to_i
      list=core ? core.active_battlers : []; list.each{|x|next if x==nil||x==b||x.hidden||x.hp.to_i<=0; return false if x.respond_to?(:cg_battle_column)&&x.cg_battle_column!=nil&&x.cg_battle_column.to_i==col}; true
    rescue; false; end
    def self.apply_mobility_speed(b,base)
      v=base.to_i; aid=ability_id(b); return v if v<=0||aid<=0; pct=100; kind=nil
      if aid==ABILITY_SPRINT; pct=RANGE1_PERCENT; kind=:sprint
      elsif aid==ABILITY_WAVE_RIDER && [:rain,:heavy_rain].include?(weather); pct=RANGE1_PERCENT; kind=:wave_rider
      elsif aid==ABILITY_SKATER && [:hail,:snow].include?(weather); pct=RANGE1_PERCENT; kind=:skater
      elsif aid==ABILITY_SHADOW_DASH && isolated_lane?(b); pct=RANGE2_PERCENT; kind=:shadow_dash
      end
      return v if pct<=100||kind==nil; after=[v*pct/100,1].max; note_passive_once(aid,b,kind,{:before=>v,:after=>after,:percent=>pct,:weather=>weather,:column=>(b.respond_to?(:cg_battle_column) ? b.cg_battle_column : nil)}); after
    rescue; base.to_i; end
    def self.apply_perception(holder,ctx)
      return false unless holder&&ctx; user=ctx[:user]; skill=ctx[:skill]; return false unless user&&skill&&user!=holder&&same_side?(holder,user)&&damaging_move?(skill)
      ctx[:cancel]=true; ctx[:hp_damage]=0; note_local(ABILITY_PERCEPTION,holder,:perception,{:user_index=>user.index.to_i,:move_id=>move_id(skill)}); true
    rescue; false; end
    def self.apply_position_damage(user,target,skill,damage)
      d=damage.to_i; return d unless user&&target&&skill&&d>0&&opposing?(user,target); aid=ability_id(user); kind=nil
      if aid==ABILITY_HIGH_RISE && user.respond_to?(:cg_back_row?)&&target.respond_to?(:cg_front_row?)&&user.cg_back_row?&&target.cg_front_row?; kind=:high_rise
      elsif aid==ABILITY_CLIMBER && user.respond_to?(:cg_front_row?)&&target.respond_to?(:cg_back_row?)&&user.cg_front_row?&&target.cg_back_row?; kind=:climber
      end
      return d unless kind; after=[d*POSITION_DAMAGE_PERCENT/100,1].max; note_local(aid,user,kind,{:move_id=>move_id(skill),:target_index=>target.index.to_i,:before=>d,:after=>after,:percent=>POSITION_DAMAGE_PERCENT,:user_row=>user.cg_battle_row,:target_row=>target.cg_battle_row}); after
    rescue; damage.to_i; end
    def self.black_hole_holder_for(user)
      return nil unless user; list=user.actor? ? ($game_troop ? $game_troop.members : []) : ($game_party ? $game_party.members : []); list.each{|b|next if b==nil||b.hidden||b.hp.to_i<=0; return b if ability_id(b)==ABILITY_BLACK_HOLE}; nil
    rescue; nil; end
    def self.resolve_teleport_block(user,base_reason=nil)
      return base_reason if base_reason!=nil||user==nil; return nil if ability_id(user)==ABILITY_RUN_AWAY
      h=black_hole_holder_for(user); return nil unless h; note_local(ABILITY_BLACK_HOLE,h,:black_hole,{:target_index=>user.index.to_i,:reason=>:black_hole}); :black_hole
    rescue; base_reason; end
    def self.register_handlers; return false unless core; core.register(ABILITY_PERCEPTION,:before_hit,self,:apply_perception); true; end
    def self.clear_test_runtime(b); return unless b; b.instance_variable_set(:@cg_priority_test_speed_override_ar,nil); end
    def self.configure_actor(cfg); a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return unless a; master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); clear_test_runtime(a); end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end
    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}; ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS); $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true); $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!); TEST_ALLIES.each{|c|configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); clear_test_runtime(h); set_ability(h,ABILITY_SPRINT); mids=[150]; sids=mids.collect{|m|master.skill_id_for_move(m)}; h.instance_variable_set(:@cg_equipped_skill_ids,sids); h.instance_variable_set(:@cg_skill_slot_ids,sids); h.instance_variable_set(:@skills,sids); end
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID); xs=[ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X]; ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1]]; ms=[]
      TEST_ENEMIES.each_with_index{|c,i|configure_enemy(c); m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=(i>=4); ms<<m}; $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AR v2.5.43a AutoRegression",ms)
    end
    def self.pre_scene_start
      (test_allies+all_enemies).each{|b|clear_test_runtime(b)}; a=test_allies; e=all_enemies
      set_ability(a[0],ABILITY_SPRINT) if a[0]; set_ability(a[1],ABILITY_WAVE_RIDER) if a[1]; set_ability(a[2],ABILITY_SKATER) if a[2]; set_ability(a[3],ABILITY_BLACK_HOLE) if a[3]
      set_ability(e[0],ABILITY_HIGH_RISE) if e[0]; set_ability(e[1],ABILITY_CLIMBER) if e[1]; set_ability(e[2],ABILITY_SHADOW_DASH) if e[2]; set_ability(e[3],ABILITY_PERCEPTION) if e[3]; set_ability(e[4],0) if e[4]
      set_slot(a[0],:front,0); set_slot(a[1],:front,1); set_slot(a[2],:back,1); set_slot(a[3],:back,0); set_slot(e[0],:back,0); set_slot(e[1],:front,1); set_slot(e[2],:back,2); set_slot(e[3],:front,0); set_slot(e[4],:back,1)
    end
    def self.make_action(b,c); a=Game_BattleAction.new(b); c[:kind]==:guard ? a.set_guard : a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); a.target_index=c[:target].to_i if c.has_key?(:target); a; end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; p=current_plan; return nil unless p&&p[:enemies]; c=p[:enemies][e.index]; c ? make_action(e,c) : nil; end
    def self.action_token(b); return "nil" unless b; s=b.actor? ? "A" : "E"; a=b.action; return s+b.index.to_s+":Guard" if a&&a.guard?; return s+b.index.to_s+":M"+move_id(a.skill).to_s if a&&a.skill?; s+b.index.to_s+":Other"; rescue; "?"; end
    def self.record_execution(b); @actual<<action_token(b) if active?; log("ACTION_EXEC #"+@actual.size.to_s+" "+(b ? b.name.to_s : "nil")+" token="+@actual[-1].to_s) if active?; end
    def self.apply_test_speeds; sp=TEST_SPEEDS[current_round]||[]; (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_ar,sp[i]) if b&&sp[i]!=nil}; end
    def self.restore_base_abilities
      a=test_allies; e=all_enemies; set_ability(a[0],ABILITY_SPRINT) if a[0]; set_ability(a[1],ABILITY_WAVE_RIDER) if a[1]; set_ability(a[2],ABILITY_SKATER) if a[2]; set_ability(a[3],ABILITY_BLACK_HOLE) if a[3]; set_ability(e[0],ABILITY_HIGH_RISE) if e[0]; set_ability(e[1],ABILITY_CLIMBER) if e[1]; set_ability(e[2],ABILITY_SHADOW_DASH) if e[2]; set_ability(e[3],ABILITY_PERCEPTION) if e[3]
    end
    def self.capture_speed_probe
      a=test_allies; e=all_enemies; @speed_probe={}
      [[:sprint,a[0]],[:wave,a[1]],[:skater,a[2]],[:shadow,e[2]]].each{|pair|k=pair[0];b=pair[1]; @speed_probe[k]=[raw_speed(b),b ? b.cg_priority_base_speed.to_i : 0]}; log("SPEED_PROBE "+@speed_probe.inspect)
    end
    def self.run_perception_probe(expect_block)
      e=all_enemies; return false unless e[3]&&e[0]; skill=$data_skills[master.skill_id_for_move(55)]; return false unless skill; e[3].recover_all; before=e[3].hp.to_i; e[3].skill_effect(e[0],skill); after=e[3].hp.to_i; blocked=(before==after); log("PERCEPTION_PROBE same_side=true before="+before.to_s+" after="+after.to_s+" blocked="+blocked.to_s); blocked==expect_block
    rescue=>ex; log("PERCEPTION_PROBE_ERROR "+ex.class.to_s+":"+ex.message.to_s); false; end
    def self.run_perception_enemy_scope_probe
      a=test_allies; e=all_enemies; return false unless e[3]&&a[0]; skill=$data_skills[master.skill_id_for_move(55)]; e[3].recover_all; before=e[3].hp.to_i; e[3].skill_effect(a[0],skill); after=e[3].hp.to_i; ok=after<before; log("PERCEPTION_SCOPE_PROBE opposing=true before="+before.to_s+" after="+after.to_s); e[3].recover_all; ok
    rescue=>ex; log("PERCEPTION_SCOPE_ERROR "+ex.class.to_s+":"+ex.message.to_s); false; end
    def self.slot_snapshot(list)
      list.collect{|b| b&&b.respond_to?(:cg_battle_row) ? [b.cg_battle_row,b.cg_battle_column] : nil}
    rescue; []; end
    def self.apply_round_slots(r)
      a=test_allies; e=all_enemies
      # Solo Trainer v1.9.0 resets party slots inside Scene_Battle#start.
      # Re-apply deterministic AR positions here, after that formal reset.
      set_slot(a[0],:front,1); set_slot(a[1],:front,0); set_slot(a[3],:back,0)
      set_slot(a[2],r==2 ? :front : :back,r==2 ? 2 : 1)
      set_slot(e[0],:back,0); set_slot(e[1],:front,1); set_slot(e[2],:back,2); set_slot(e[3],:front,0); set_slot(e[4],:back,1)
      log("GRID_FIX round="+r.to_s+" allies="+slot_snapshot(a).inspect+" enemies="+slot_snapshot(e).inspect+" shadow_isolated="+isolated_lane?(e[2]).to_s)
    end
    def self.prepare_round_fixture
      a=test_allies; e=all_enemies; r=current_round; restore_base_abilities; @round_counts={}; HANDLED_ABILITY_IDS.each{|id|@round_counts[id]=records_for(id).size}; @passive_noted={}; apply_round_slots(r)
      if r==1
        set_weather(:rain,5); @perception_r1=run_perception_probe(true); e[3].recover_all if e[3]; log("ROUND1_FIX weather=rain shadow_isolated="+isolated_lane?(e[2]).to_s)
      elsif r==2
        set_weather(:snow,5); @r2_black_before=records_for(ABILITY_BLACK_HOLE,:black_hole).size; @perception_scope=run_perception_enemy_scope_probe; log("ROUND2_FIX weather=snow shadow_isolated="+isolated_lane?(e[2]).to_s+" black_hole=true")
      else
        set_weather(nil,0); set_ability(a[3],0); @r3_black_before=records_for(ABILITY_BLACK_HOLE,:black_hole).size; log("ROUND3_FIX weather=nil shadow_isolated="+isolated_lane?(e[2]).to_s+" black_hole=false")
      end
    end
    def self.prepare_round_actions
      prepare_round_fixture; apply_test_speeds; capture_speed_probe; @actual=[]; a=test_allies; p=current_plan; return false unless p
      p[:allies].each_with_index{|cfg,i|next unless a[i]&&a[i].hp.to_i>0; act=make_action(a[i],cfg); if a[i].respond_to?(:cg_round_actions); a[i].cg_round_actions.clear; a[i].cg_round_actions.push(act); end; a[i].cg_assign_action(act) if a[i].respond_to?(:cg_assign_action); a[i].instance_variable_set(:@action,act) unless a[i].respond_to?(:cg_assign_action)}; log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s); true
    end
    def self.assert_order; exp=EXPECTED_EXECUTION_TOKENS[current_round]||[]; ok=@actual==exp; @action_checks+=1 if ok; assert_true("Round"+current_round.to_s+" execution order matches deterministic plan",ok,"expected="+exp.inspect+" actual="+@actual.inspect); end
    def self.assert_speed(label,key,expected)
      pair=@speed_probe[key]||[0,0]; ok=pair[1].to_i==expected.to_i; @mobility_checks+=1 if ok; assert_true(label,ok,"speed="+pair[0].to_s+"->"+pair[1].to_s+" expected="+expected.to_s)
    end
    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true; assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil")); assert_true("Ability Batch AR defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s); assert_true("Scene_Battle uses Ability AR test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil")); assert_true("Ability AR ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s); assert_true("Ability AR enemy count=5",all_enemies.size==5,"actual="+all_enemies.size.to_s)
    end
    def self.finish_round_assertions
      assert_order; a=test_allies; e=all_enemies; r=current_round
      if r==1
        assert_speed("Sprint passive Range+1 proxy is exact SPE +20%",:sprint,1080); assert_speed("Wave Rider Rain water-environment is exact SPE +20%",:wave,960); assert_speed("Skater stays off outside ice weather",:skater,700); assert_speed("Shadow Dash isolated lane Range+2 proxy is exact SPE +40%",:shadow,560)
        pok=@perception_r1==true&&!records_for(ABILITY_PERCEPTION,:perception).empty?; @perception_checks+=1 if pok; assert_true("Perception blocks same-side damaging Move",pok,"record="+(records_for(ABILITY_PERCEPTION,:perception)[-1]||{}).inspect)
        hr=records_for(ABILITY_HIGH_RISE,:high_rise)[-1]||{}; hok=!hr.empty?&&hr[:after].to_i==[hr[:before].to_i*POSITION_DAMAGE_PERCENT/100,1].max; @position_checks+=1 if hok; assert_true("High-rise back/high -> front/low real damage is exact +20%",hok,hr.inspect)
        cr=records_for(ABILITY_CLIMBER,:climber)[-1]||{}; cok=!cr.empty?&&cr[:after].to_i==[cr[:before].to_i*POSITION_DAMAGE_PERCENT/100,1].max; @position_checks+=1 if cok; assert_true("Climber front/low -> back/high real damage is exact +20%",cok,cr.inspect)
      elsif r==2
        assert_speed("Sprint stays exact SPE +20% in Snow",:sprint,1080); assert_speed("Wave Rider deactivates outside Rain",:wave,800); assert_speed("Skater Snow ice-environment is exact SPE +20%",:skater,840); assert_speed("Shadow Dash deactivates when another battler shares its lane",:shadow,400)
        bh=records_for(ABILITY_BLACK_HOLE,:black_hole); bok=bh.size>@r2_black_before.to_i&&e[0]&&!e[0].hidden&&e[4]&&e[4].hidden; @trap_checks+=1 if bok; assert_true("Black Hole blocks real enemy Teleport movement",bok,"record="+(bh[-1]||{}).inspect+" E0_hidden="+(e[0] ? e[0].hidden.to_s : "nil"))
        @perception_checks+=1 if @perception_scope; @scope_checks+=1 if @perception_scope; assert_true("Perception does not block opposing damaging Move",@perception_scope==true)
      else
        assert_speed("Sprint remains exact SPE +20% on clear field",:sprint,1080); assert_speed("Wave Rider clear-field off",:wave,800); assert_speed("Skater clear-field off",:skater,700); assert_speed("Shadow Dash returns when lane is isolated again",:shadow,560)
        bh_same=records_for(ABILITY_BLACK_HOLE,:black_hole).size==@r3_black_before.to_i; sw=e[0]&&e[0].hidden&&e[4]&&!e[4].hidden; tok=bh_same&&sw; @trap_checks+=1 if tok; @scope_checks+=1 if tok; assert_true("Without Black Hole, real Teleport succeeds and deploys reserve",tok,"E0_hidden="+(e[0] ? e[0].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END"); @round_index=@round_index.to_i+1
    end
    def self.cleanup_test_overrides; set_weather(nil,0); (test_allies+all_enemies).each{|b|clear_test_runtime(b)}; rescue; end
    def self.cleanup_output_logs
      keep=["CG_AutoRegression_LATEST.log","PMD_BattleInitTrace.log"]; Dir.glob(File.join(project_root,"*.log")).each{|p|next if keep.include?(File.basename(p)); begin; File.delete(p); rescue; end}; true
    rescue; false; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|aid|ok=@ability_trigger_counts[aid].to_i>0; assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)}
      log("------------------------------------------------------------"); result=@failures.empty? ? "PASS" : "FAIL"; log("RESULT="+result); passed=HANDLED_ABILITY_IDS.select{|x|@ability_trigger_counts[x].to_i>0}.size
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_ar="+passed.to_s+"/8 mobility_checks="+@mobility_checks.to_s+" position_checks="+@position_checks.to_s+" perception_checks="+@perception_checks.to_s+" trap_checks="+@trap_checks.to_s+" scope_checks="+@scope_checks.to_s+" action_checks="+@action_checks.to_s+" pending=21")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; cleanup_output_logs; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite; @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @mobility_checks=0; @position_checks=0; @perception_checks=0; @trap_checks=0; @scope_checks=0; @action_checks=0; @passive_noted={}; end
    def self.reset_log
      cleanup_output_logs; h="CG POKEMON ABILITY AR CONQUEST MOBILITY + POSITION AUTO REGRESSION v2.5.43a\r\n"+"START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+"RULE=Actual Scene_Battle; CG grid position + weather mobility + same-side Perception + Black Hole Teleport\r\n"+"BASELINE=v2.5.42 Ability Batch AQ RPG Maker VX real-machine PASS; Move pending=0\r\n"+"ABILITY_CATALOG=373 BATCH_A_TO_AQ_PASS=344 BATCH_AR=8 PENDING=21\r\n"+"LEAN_LOGS=send CG_AutoRegression_LATEST.log + PMD_BattleInitTrace.log\r\n"+"RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+"------------------------------------------------------------\r\n"; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue; end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AR_v2.5.43a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e; @failures=[] if @failures==nil; @failures<<"AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s; log(@failures[-1]); @active=false; false; end
  end
end
ALBERT_CG::ABILITY_AR_V2543.register_handlers if defined?(ALBERT_CG::ABILITY_AR_V2543)
#==============================================================================
# ■ Formal bridges
#==============================================================================
class Game_Battler
  alias cg_v2543ar_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    base=if defined?(ALBERT_CG::ABILITY_AR_V2543)&&ALBERT_CG::ABILITY_AR_V2543.active?&&@cg_priority_test_speed_override_ar!=nil; @cg_priority_test_speed_override_ar.to_i; else; cg_v2543ar_priority_base_speed; end
    defined?(ALBERT_CG::ABILITY_AR_V2543) ? ALBERT_CG::ABILITY_AR_V2543.apply_mobility_speed(self,base) : base
  rescue; cg_v2543ar_priority_base_speed; end
  alias cg_v2543ar_execute_damage execute_damage
  def execute_damage(user)
    skill=defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.current_skill(user) : nil
    if defined?(ALBERT_CG::ABILITY_AR_V2543)&&user&&@hp_damage.to_i>0; @hp_damage=ALBERT_CG::ABILITY_AR_V2543.apply_position_damage(user,self,skill,@hp_damage.to_i); end
    cg_v2543ar_execute_damage(user)
  end
end
if defined?(ALBERT_CG::UNIQUE_I_V242)
  module ALBERT_CG; module UNIQUE_I_V242; class << self
    alias cg_v2543ar_teleport_block_reason teleport_block_reason
    def teleport_block_reason(user); base=cg_v2543ar_teleport_block_reason(user); defined?(ALBERT_CG::ABILITY_AR_V2543) ? ALBERT_CG::ABILITY_AR_V2543.resolve_teleport_block(user,base) : base; end
  end; end; end
end
class Scene_Battle < Scene_Base
  alias cg_v2543ar_start start
  def start; ALBERT_CG::ABILITY_AR_V2543.pre_scene_start if defined?(ALBERT_CG::ABILITY_AR_V2543)&&ALBERT_CG::ABILITY_AR_V2543.active?; cg_v2543ar_start; end
  alias cg_v2543ar_execute_action execute_action
  def execute_action; ALBERT_CG::ABILITY_AR_V2543.record_execution(@active_battler) if defined?(ALBERT_CG::ABILITY_AR_V2543)&&ALBERT_CG::ABILITY_AR_V2543.active?; cg_v2543ar_execute_action; end
  alias cg_v2543ar_turn_end turn_end
  def turn_end; ALBERT_CG::ABILITY_AR_V2543.finish_round_assertions if defined?(ALBERT_CG::ABILITY_AR_V2543)&&ALBERT_CG::ABILITY_AR_V2543.active?; cg_v2543ar_turn_end; end
  alias cg_v2543ar_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AR_V2543)&&ALBERT_CG::ABILITY_AR_V2543.active?; return cg_v2543ar_start_party_command; end
    cg_v2543ar_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_AR_V2543.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AR_V2543.finished?; ALBERT_CG::ABILITY_AR_V2543.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_AR_V2543.prepare_round_actions; start_main
  end
end
class Game_Enemy < Game_Battler
  alias cg_v2543ar_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AR_V2543)&&ALBERT_CG::ABILITY_AR_V2543.active?; a=ALBERT_CG::ABILITY_AR_V2543.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end; end
    cg_v2543ar_enemy_make_action
  end
end
module ALBERT_CG; class << self
  alias cg_v2543ar_bootstrap_demo_party bootstrap_demo_party
  def bootstrap_demo_party
    r=cg_v2543ar_bootstrap_demo_party
    if defined?(ALBERT_CG::ABILITY_AR_V2543)&&ALBERT_CG::ABILITY_AR_V2543.active?
      ALBERT_CG::ABILITY_AR_V2543::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AR_V2543.configure_actor(c)}; h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_AR_V2543::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); ALBERT_CG::ABILITY_AR_V2543.set_ability(h,ALBERT_CG::ABILITY_AR_V2543::ABILITY_SPRINT); end
    end; r
  end
end; end
if defined?(ALBERT_CG::ABILITY_AQ_V2542); module ALBERT_CG; module ABILITY_AQ_V2542; def self.f11_trigger?; false; end; end; end; end
class Scene_Map < Scene_Base
  alias cg_v2543ar_scene_map_update update
  def update; cg_v2543ar_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_AR_V2543); ALBERT_CG::ABILITY_AR_V2543.start_auto_test if ALBERT_CG::ABILITY_AR_V2543.f11_trigger?; end
end
