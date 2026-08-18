# RMVX_SCRIPT_INDEX: 267
# RMVX_SCRIPT_ID: 267000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AQ v2.5.42
# RMVX_SOURCE_SHA256: e81635f24b1020bcb2cf605f99d0d13605babb46dcf2390af9beb9a914471f76

#==============================================================================
# ■ CG Pokemon Ability Batch AQ v2.5.42 - Retreat Trap + Form Identity + Decoy TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.41a Ability Batch AP RPG Maker VX 實機 PASS 為唯一正式基底，收斂
#  Shadow Tag / Magnet Pull / Run Away / Arena Trap 的撤退權威，以及 Power Construct /
#  Embody Aspect / Tera Shift 的 battle-local 形態身份與 Conquest Decoy 迴避。
#
# 【本批 Ability】
#   23 Shadow Tag：敵方非 Ghost、非 Shadow Tag holder 的 Teleport 會被攔截。
#   42 Magnet Pull：敵方 Steel 且非 Ghost 的 Teleport 會被攔截。
#   50 Run Away：正式逃跑必定成功，並可繞過 trapping Move / Ability 的 Teleport 封鎖。
#   71 Arena Trap：敵方 grounded、非 Ghost 的 Teleport 會被攔截；Flying / Levitate /
#      Eelevate / Magnet Rise 依既有 Grounded Authority 豁免。
#  211 Power Construct：回合結束時 HP<=1/2 且尚未 Complete，切 Complete profile。
#      Complete 五維 Base Stat=100/121/91/95/85；MaxHP 依 Zygarde 50%→Complete
#      Base HP 108→216 做 battle-local x2，並保存「已損失 HP」而非視為治療。
#  303 Embody Aspect：本專案目前沒有 Terastallization UI；因此持有此 Ability 的 battler
#      被明確視為「已完成 Terastallization」，第一次 entry 依 battle-local mask marker
#      Teal/Wellspring/Hearthflame/Cornerstone 分別 SPE/SPD/ATK/DEF +1 stage。
#  304 Tera Shift：第一次入場切 Terastal profile，五維=95/110/105/110/85，
#      MaxHP 依 90→95 ratio 增加且保存已損失 HP；形態持續到 battle end。
# 10059 Decoy：Pokémon Conquest「may cause opponent to miss」採既有 Conquest 30% proc
#      convention；只攔 opposing damaging Move，F11 以 forced true/false 驗正反路徑。
#
# 【正式 Authority 映射】
#  1. Trapping 不另造撤退系統，直接 alias 已 PASS Unique I Teleport `teleport_block_reason`。
#  2. Run Away 另外 alias Scene_Battle#process_escape，把正式逃跑 ratio 提升到 100；F11
#     不真的結束戰鬥，而以 actual Teleport bypass 驗 Runtime。
#  3. Form 五維沿用 cg_v238_set_base_stat；Type 沿用 cg_v237_set_types；HP 只新增 AQ
#     battle-local maxhp ratio wrapper。Battle end remove_states_battle 清 AQ form/HP runtime。
#  4. Power Construct / Tera Shift 對 Neutralizing Gas 加入正式 exemption，沿用 AG effective
#     Ability bridge；不修改 sealed AG source。
#  5. Trap Ability 對 ally 不生效；Ghost immunity 採 Gen VI+；Run Away 只繞過 flee/Teleport，
#     不把 forced switch / U-turn 類效果誤判為 voluntary retreat。
#
# 【F11】Troop 745，三回合 Actual Scene_Battle：
#  R1：只開 Shadow Tag；E2 Embody Aspect Teleport 被擋，E1 Run Away Teleport 繞過並換入 E4；
#      E0 Water Gun 打 A3 Decoy forced proc=true；end-turn E0 Power Construct -> Complete。
#  R2：Shadow Tag 關閉，Magnet Pull + Arena Trap 開啟；E2 設 Steel/Flying，Teleport 只被
#      Magnet Pull 擋；E4 Normal grounded Teleport 被 Arena Trap 擋。
#  R3：Shadow/Magnet/Arena 同時 active，E2 改 Steel/Ghost，因此三種 trap 全豁免並真實
#      Teleport 換入 E5；Decoy forced false 讓 E0 Water Gun 正常造成傷害；驗 Complete /
#      Terastal / Embody one-shot persistence。
#==============================================================================
$imported={} if $imported==nil
$imported["ALBERT_CG_PokemonAbilityBatchAQ"]="2.5.42"
module ALBERT_CG
  module ABILITY_AQ_V2542
    VERSION="2.5.42"; TEST_LEVEL=40; TEST_TROOP_ID=745; VK_F11=0x7A
    ABILITY_SHADOW_TAG=23; ABILITY_MAGNET_PULL=42; ABILITY_RUN_AWAY=50; ABILITY_ARENA_TRAP=71
    ABILITY_POWER_CONSTRUCT=211; ABILITY_EMBODY_ASPECT=303; ABILITY_TERA_SHIFT=304; ABILITY_DECOY=10059
    ABILITY_LEVITATE=26; ABILITY_EELEVATE=312
    HANDLED_ABILITY_IDS=[23,42,50,71,211,303,304,10059]
    PROC_CHANCE=30
    POWER_PROFILE={:atk=>100,:def=>121,:spa=>91,:spd=>95,:spe=>85}
    TERA_PROFILE={:atk=>95,:def=>110,:spa=>105,:spd=>110,:spe=>85}
    EMBODY_STAGE={:teal=>:spe,:wellspring=>:spd,:hearthflame=>:atk,:cornerstone=>:def}
    RUN_AWAY_BASE_BYPASS=[:switch_lock,:fairy_lock,:ingrain]
    TEST_ALLIES=[
      {:dex=>82,:level=>40,:ability=>ABILITY_MAGNET_PULL,:moves=>[150,150,150]},
      {:dex=>50,:level=>40,:ability=>ABILITY_ARENA_TRAP,:moves=>[150,150,150]},
      {:dex=>132,:level=>40,:ability=>ABILITY_DECOY,:moves=>[150,150,150]}]
    TEST_ENEMIES=[
      {:dex=>384,:level=>45,:ability=>ABILITY_POWER_CONSTRUCT,:moves=>[55,150,55]},
      {:dex=>19,:level=>45,:ability=>ABILITY_RUN_AWAY,:moves=>[100,150,150]},
      {:dex=>303,:level=>45,:ability=>ABILITY_EMBODY_ASPECT,:moves=>[100,100,100]},
      {:dex=>304,:level=>45,:ability=>ABILITY_TERA_SHIFT,:moves=>[150,150,150]},
      {:dex=>65,:level=>45,:ability=>0,:moves=>[150,100,150]},
      {:dex=>197,:level=>45,:ability=>0,:moves=>[150,150,150]}]
    ROUND_PLANS=[
      {:name=>"SHADOW_RUNAWAY_DECOY_POWER_CONSTRUCT",:allies=>[
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>55,:target=>3},1=>{:kind=>:move,:move_id=>100,:target=>1},2=>{:kind=>:move,:move_id=>100,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"MAGNET_ARENA_TRAP",:allies=>[
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>1},2=>{:kind=>:move,:move_id=>100,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1},4=>{:kind=>:move,:move_id=>100,:target=>1}}},
      {:name=>"GHOST_ESCAPE_DECOY_FALSE_FORM_PERSIST",:allies=>[
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0},
        {:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>55,:target=>3},2=>{:kind=>:move,:move_id=>100,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1},4=>{:kind=>:move,:move_id=>150,:target=>1}}}]
    EXPECTED_EXECUTION_TOKENS={
      1=>["A0:M150","A1:M150","A2:M150","A3:M150","E0:M55","E3:M150","E2:M100","E1:M100"],
      2=>["A0:M150","A1:M150","A2:M150","A3:M150","E0:M150","E3:M150","E2:M100","E4:M100"],
      3=>["A0:M150","A1:M150","A2:M150","A3:M150","E0:M55","E3:M150","E4:M150","E2:M100"]}
    TEST_SPEEDS={
      1=>[900,850,800,750, 600,500,550,450,100,50],
      2=>[900,850,800,750, 600,0,550,450,400,50],
      3=>[900,850,800,750, 600,0,550,450,400,50]}
    begin; KEY_API=Win32API.new("user32","GetAsyncKeyState","i","i"); rescue; KEY_API=nil; end
    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.field; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233 : nil; end
    def self.unique_i; defined?(ALBERT_CG::UNIQUE_I_V242) ? ALBERT_CG::UNIQUE_I_V242 : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party ? $game_party.members : []; end
    def self.all_enemies; $game_troop ? $game_troop.members : []; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AQ_AutoTest_v2_5_42.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(p,t,m="ab"); File.open(p,m){|f|f.write(t.to_s+"\r\n")}; true; rescue; false; end
    def self.log(t); write_line(log_path,t); write_line(latest_log_path,t); rescue; end
    def self.key_down?(c); KEY_API && (KEY_API.call(c)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.ability_id(b); core&&b ? core.ability_id(b).to_i : 0; rescue; 0; end
    def self.raw_ability_id(b); return 0 unless b; return ALBERT_CG::ABILITY_AG_V2532.raw_ability_id(b).to_i if defined?(ALBERT_CG::ABILITY_AG_V2532); b.respond_to?(:cg_master_ability_id) ? b.cg_master_ability_id.to_i : 0; rescue; 0; end
    def self.types_of(b); b&&b.respond_to?(:cg_pokemon_types) ? b.cg_pokemon_types : []; rescue; []; end
    def self.ghost?(b); types_of(b).include?(:ghost); rescue; false; end
    def self.set_types(b,types); b.cg_v237_set_types(types) if b&&b.respond_to?(:cg_v237_set_types); end
    def self.form(b); b ? b.instance_variable_get(:@cg_v2542aq_form) : nil; end
    def self.assert_true(label,cond,detail=nil); if cond; log("ASSERT PASS "+label.to_s+(detail ? " "+detail.to_s : "")); else; x=label.to_s+(detail ? " "+detail.to_s : ""); @failures<<x; log("ASSERT FAIL "+x); end; cond; end
    def self.note_local(aid,b,kind,data=nil)
      rec={:ability=>aid.to_i,:kind=>kind}; (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill,:action].include?(k)}
      if active?; @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1; (@records[aid.to_i]||=[])<<rec; log("ABILITY_AQ_TRIGGER ability="+aid.to_s+" battler="+(b ? b.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect); end
      rec
    rescue; nil; end
    def self.records_for(aid,kind=nil); a=@records[aid.to_i]||[]; kind ? a.select{|x|x[:kind].to_sym==kind.to_sym} : a; rescue; []; end
    def self.present_external_trigger(aid,b,kind,data=nil)
      core.note_trigger(kind,b,aid,data||{}) if core&&core.respond_to?(:note_trigger)
      core.present_trigger(b,aid,kind,data||{}) if core&&core.respond_to?(:present_trigger)
      note_local(aid,b,kind,data)
      true
    rescue; false; end
    def self.proc_success?(aid); return @forced_proc[aid.to_i] if active?&&@forced_proc&&@forced_proc.has_key?(aid.to_i); rand(100)<PROC_CHANCE; rescue; false; end
    def self.change_stage(source,target,key,amount)
      return 0 unless target&&target.respond_to?(:cg_change_stat_stage)
      auth=defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) ? ALBERT_CG::ABILITY_STAT_GUARD_V256 : nil
      return auth.with_stage_source(source,:ability,false){target.cg_change_stat_stage(key,amount).to_i} if auth&&auth.respond_to?(:with_stage_source)
      target.cg_change_stat_stage(key,amount).to_i
    rescue; 0; end
    #--------------------------------------------------------------------------
    # Formal retreat trap authority
    #--------------------------------------------------------------------------
    def self.gravity_active?; field&&field.respond_to?(:global_effect?) ? field.global_effect?(:gravity) : false; rescue; false; end
    def self.grounded_for_arena?(b)
      return false unless b
      return true if gravity_active?
      return false if ghost?(b)
      return false if types_of(b).include?(:flying)
      aid=ability_id(b); return false if aid==ABILITY_LEVITATE || aid==ABILITY_EELEVATE
      return false if b.respond_to?(:cg_v238_magnet_rise?)&&b.cg_v238_magnet_rise?
      return field.grounded?(b) if field&&field.respond_to?(:grounded?)
      true
    rescue; true; end
    def self.potential_trap(user)
      return nil unless user&&core
      return nil if ghost?(user)
      core.opponents_of(user).each do |h|
        next unless h&&!h.hidden&&h.hp.to_i>0
        aid=ability_id(h)
        if aid==ABILITY_SHADOW_TAG && ability_id(user)!=ABILITY_SHADOW_TAG
          return [:shadow_tag,h,ABILITY_SHADOW_TAG]
        end
        if aid==ABILITY_MAGNET_PULL && types_of(user).include?(:steel) && !ghost?(user)
          return [:magnet_pull,h,ABILITY_MAGNET_PULL]
        end
        if aid==ABILITY_ARENA_TRAP && grounded_for_arena?(user) && !ghost?(user)
          return [:arena_trap,h,ABILITY_ARENA_TRAP]
        end
      end
      nil
    rescue; nil; end
    def self.resolve_teleport_block(user,base_reason=nil)
      return base_reason if user==nil
      runaway=(ability_id(user)==ABILITY_RUN_AWAY)
      if base_reason!=nil
        if runaway && RUN_AWAY_BASE_BYPASS.include?(base_reason.to_sym)
          present_external_trigger(ABILITY_RUN_AWAY,user,:run_away_bypass,{:blocked_reason=>base_reason,:source=>:base_retreat_lock})
          return nil
        end
        return base_reason
      end
      trap=potential_trap(user); return nil if trap==nil
      reason,holder,aid=trap
      if runaway
        present_external_trigger(ABILITY_RUN_AWAY,user,:run_away_bypass,{:blocked_reason=>reason,:trap_ability=>aid,:trap_holder_index=>holder.index.to_i})
        return nil
      end
      present_external_trigger(aid,holder,:trap_block,{:target_index=>user.index.to_i,:reason=>reason,:target_types=>types_of(user).inspect})
      reason
    rescue; base_reason; end
    def self.run_away_party_holder
      return nil unless $game_party
      $game_party.members.find{|b|b&&!b.hidden&&b.hp.to_i>0&&ability_id(b)==ABILITY_RUN_AWAY}
    rescue; nil; end
    #--------------------------------------------------------------------------
    # Formal form identity authority
    #--------------------------------------------------------------------------
    def self.clear_form_runtime(b)
      return unless b
      b.instance_variable_set(:@cg_v2542aq_form,nil)
      b.instance_variable_set(:@cg_v2542aq_hp_ratio,nil)
      b.instance_variable_set(:@cg_v2542aq_power_done,false)
      b.instance_variable_set(:@cg_v2542aq_tera_done,false)
      b.instance_variable_set(:@cg_v2542aq_embody_done,false)
      b.instance_variable_set(:@cg_v238_base_stat_override,nil)
    end
    def self.apply_profile(holder,aid,new_form,profile,types,hp_num,hp_den,kind)
      return false unless holder
      old_form=form(holder); old_max=holder.maxhp.to_i; old_hp=holder.hp.to_i; lost=[old_max-old_hp,0].max
      holder.instance_variable_set(:@cg_v2542aq_hp_ratio,[hp_num.to_i,hp_den.to_i]) if hp_num&&hp_den&&hp_den.to_i>0
      profile.each{|k,v|holder.cg_v238_set_base_stat(k,v) if holder.respond_to?(:cg_v238_set_base_stat)}
      set_types(holder,types) if types
      holder.instance_variable_set(:@cg_v2542aq_form,new_form)
      new_max=holder.maxhp.to_i; new_hp=[new_max-lost,1].max; new_hp=new_max if new_hp>new_max; holder.hp=new_hp
      note_local(aid,holder,kind,{:before=>old_form,:after=>new_form,:maxhp_before=>old_max,:maxhp_after=>new_max,:hp_before=>old_hp,:hp_after=>holder.hp.to_i,:lost_before=>lost,:lost_after=>[new_max-holder.hp.to_i,0].max,:types=>types_of(holder).inspect})
      true
    rescue; false; end
    def self.power_start(holder,ctx=nil)
      clear_form_runtime(holder); set_types(holder,[:dragon,:ground]); false
    end
    def self.power_end_turn(holder,ctx=nil)
      return false if holder==nil||holder.instance_variable_get(:@cg_v2542aq_power_done)==true
      return false unless holder.hp.to_i*2<=holder.maxhp.to_i
      holder.instance_variable_set(:@cg_v2542aq_power_done,true)
      apply_profile(holder,ABILITY_POWER_CONSTRUCT,:complete,POWER_PROFILE,[:dragon,:ground],216,108,:power_construct)
    end
    def self.tera_start(holder,ctx=nil); clear_form_runtime(holder); false; end
    def self.tera_entry(holder,ctx=nil)
      return false if holder==nil||holder.instance_variable_get(:@cg_v2542aq_tera_done)==true
      holder.instance_variable_set(:@cg_v2542aq_tera_done,true)
      apply_profile(holder,ABILITY_TERA_SHIFT,:terastal,TERA_PROFILE,[:normal],95,90,:tera_shift)
    end
    def self.embody_start(holder,ctx=nil); holder.instance_variable_set(:@cg_v2542aq_embody_done,false) if holder; false; end
    def self.embody_entry(holder,ctx=nil)
      return false if holder==nil||holder.instance_variable_get(:@cg_v2542aq_embody_done)==true
      mask=holder.instance_variable_get(:@cg_v2542aq_embody_mask); mask=:teal if mask==nil; key=EMBODY_STAGE[mask.to_sym]||:spe
      before=holder.respond_to?(:cg_stat_stage) ? holder.cg_stat_stage(key).to_i : 0; delta=change_stage(holder,holder,key,1); after=holder.respond_to?(:cg_stat_stage) ? holder.cg_stat_stage(key).to_i : before
      return false if delta==0
      holder.instance_variable_set(:@cg_v2542aq_embody_done,true); holder.instance_variable_set(:@cg_v2542aq_form,mask.to_sym)
      note_local(ABILITY_EMBODY_ASPECT,holder,:embody_aspect,{:mask=>mask.to_sym,:stat=>key,:before=>before,:after=>after,:delta=>delta}); true
    rescue; false; end
    def self.apply_decoy(holder,ctx)
      return false unless holder&&ctx&&ctx[:user]&&ctx[:skill]&&ctx[:user].actor? != holder.actor?
      return false unless ctx[:skill].base_damage.to_i>0&&proc_success?(ABILITY_DECOY)
      ctx[:cancel]=true; ctx[:hp_damage]=0
      note_local(ABILITY_DECOY,holder,:decoy,{:attacker_index=>ctx[:user].index.to_i,:move_id=>ctx[:move_id].to_i}); true
    rescue; false; end
    def self.register_handlers
      return false unless core
      core.register(ABILITY_POWER_CONSTRUCT,:battle_start,self,:power_start)
      core.register(ABILITY_POWER_CONSTRUCT,:end_turn,self,:power_end_turn)
      core.register(ABILITY_EMBODY_ASPECT,:battle_start,self,:embody_start)
      core.register(ABILITY_EMBODY_ASPECT,:entry,self,:embody_entry)
      core.register(ABILITY_TERA_SHIFT,:battle_start,self,:tera_start)
      core.register(ABILITY_TERA_SHIFT,:entry,self,:tera_entry)
      core.register(ABILITY_DECOY,:before_hit,self,:apply_decoy)
      true
    end
    #--------------------------------------------------------------------------
    # Test harness
    #--------------------------------------------------------------------------
    def self.set_ability(b,aid); return unless b; b.instance_variable_set(:@cg_v237_ability_override,nil); b.instance_variable_set(:@cg_v237_ability_suppressed,false); b.instance_variable_set(:@cg_master_ability_id,aid.to_i); end
    def self.clear_test_runtime(b); return unless b; b.instance_variable_set(:@cg_priority_test_speed_override_aq,nil); end
    def self.configure_actor(cfg); a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return unless a; master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); clear_test_runtime(a); end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end
    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}; ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true); $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each{|c|configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if h; h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); clear_test_runtime(h); set_ability(h,ABILITY_SHADOW_TAG); mids=[150]; sids=mids.collect{|m|master.skill_id_for_move(m)}; h.instance_variable_set(:@cg_equipped_skill_ids,sids); h.instance_variable_set(:@cg_skill_slot_ids,sids); h.instance_variable_set(:@skills,sids); end
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2]]
      ms=[]; TEST_ENEMIES.each_with_index do |c,i|; configure_enemy(c); m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=(i>=4); ms<<m; end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AQ v2.5.42 AutoRegression",ms)
    end
    def self.pre_scene_start
      (test_allies+all_enemies).each{|b|clear_test_runtime(b)}
      a=test_allies; e=all_enemies
      set_ability(a[0],ABILITY_SHADOW_TAG) if a[0]; set_ability(a[1],ABILITY_MAGNET_PULL) if a[1]; set_ability(a[2],ABILITY_ARENA_TRAP) if a[2]; set_ability(a[3],ABILITY_DECOY) if a[3]
      if e[0]; set_ability(e[0],ABILITY_POWER_CONSTRUCT); set_types(e[0],[:dragon,:ground]); end
      if e[1]; set_ability(e[1],ABILITY_RUN_AWAY); set_types(e[1],[:normal]); end
      if e[2]; set_ability(e[2],ABILITY_EMBODY_ASPECT); e[2].instance_variable_set(:@cg_v2542aq_embody_mask,:hearthflame); set_types(e[2],[:steel,:flying]); @embody_pre=e[2].respond_to?(:cg_stat_stage) ? e[2].cg_stat_stage(:atk).to_i : 0; end
      if e[3]; set_ability(e[3],ABILITY_TERA_SHIFT); set_types(e[3],[:normal]); @tera_pre={:maxhp=>e[3].maxhp.to_i,:hp=>e[3].hp.to_i}; end
      if e[4]; set_ability(e[4],0); set_types(e[4],[:normal]); end
      if e[5]; set_ability(e[5],0); set_types(e[5],[:normal]); end
    end
    def self.capture_entry_snapshot
      e=all_enemies
      @entry_snapshot={:embody_stage=>(e[2]&&e[2].respond_to?(:cg_stat_stage) ? e[2].cg_stat_stage(:atk).to_i : nil),:embody_form=>(e[2] ? form(e[2]) : nil),:tera_form=>(e[3] ? form(e[3]) : nil),:tera_max=>(e[3] ? e[3].maxhp.to_i : nil),:tera_hp=>(e[3] ? e[3].hp.to_i : nil),:tera_atk=>(e[3] ? e[3].cg_atk_stat.to_i : nil)}
      log("ENTRY_SNAPSHOT "+@entry_snapshot.inspect) if active?
    end
    def self.make_action(b,c); a=Game_BattleAction.new(b); c[:kind]==:guard ? a.set_guard : a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); a.target_index=c[:target].to_i if c.has_key?(:target); a; end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; p=current_plan; return nil unless p&&p[:enemies]; c=p[:enemies][e.index]; c ? make_action(e,c) : nil; end
    def self.action_token(b); return "nil" unless b; s=b.actor? ? "A" : "E"; a=b.action; return s+b.index.to_s+":Guard" if a&&a.guard?; return s+b.index.to_s+":M"+move_id(a.skill).to_s if a&&a.skill?; s+b.index.to_s+":Other"; rescue; "?"; end
    def self.record_execution(b); @actual<<action_token(b) if active?; log("ACTION_EXEC #"+@actual.size.to_s+" "+(b ? b.name.to_s : "nil")+" token="+@actual[-1].to_s) if active?; end
    def self.apply_test_speeds; sp=TEST_SPEEDS[current_round]||[]; (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_aq,sp[i]) if b&&sp[i]!=nil}; end
    def self.restore_base_abilities
      a=test_allies; e=all_enemies
      set_ability(a[0],ABILITY_SHADOW_TAG) if a[0]; set_ability(a[1],ABILITY_MAGNET_PULL) if a[1]; set_ability(a[2],ABILITY_ARENA_TRAP) if a[2]; set_ability(a[3],ABILITY_DECOY) if a[3]
      set_ability(e[0],ABILITY_POWER_CONSTRUCT) if e[0]; set_ability(e[1],ABILITY_RUN_AWAY) if e[1]; set_ability(e[2],ABILITY_EMBODY_ASPECT) if e[2]; set_ability(e[3],ABILITY_TERA_SHIFT) if e[3]
      set_ability(e[4],0) if e[4]; set_ability(e[5],0) if e[5]
    end
    def self.prepare_round_fixture
      a=test_allies; e=all_enemies; r=current_round; restore_base_abilities; @forced_proc={}; HANDLED_ABILITY_IDS.each{|id|(@round_counts||={})[id]=records_for(id).size}
      if r==1
        set_ability(a[1],0); set_ability(a[2],0); @forced_proc[ABILITY_DECOY]=true
        if e[0]; e[0].hp=[e[0].maxhp.to_i/2,1].max; @r1_power_before={:max=>e[0].maxhp.to_i,:hp=>e[0].hp.to_i,:lost=>e[0].maxhp.to_i-e[0].hp.to_i}; end
        set_types(e[2],[:steel,:flying]) if e[2]; @r1_decoy_hp=a[3] ? a[3].hp.to_i : 0
        log("ROUND1_FIX power="+@r1_power_before.inspect+" E1_runaway=true E2_types="+(e[2] ? types_of(e[2]).inspect : "nil"))
      elsif r==2
        set_ability(a[0],0); @forced_proc[ABILITY_DECOY]=false; set_types(e[2],[:steel,:flying]) if e[2]; set_types(e[4],[:normal]) if e[4]
        log("ROUND2_FIX magnet=true arena=true E2="+(e[2] ? types_of(e[2]).inspect : "nil")+" E4="+(e[4] ? types_of(e[4]).inspect : "nil"))
      else
        @forced_proc[ABILITY_DECOY]=false; set_types(e[2],[:steel,:ghost]) if e[2]; @r3_decoy_hp=a[3] ? a[3].hp.to_i : 0
        @r3_trap_counts={:shadow=>records_for(ABILITY_SHADOW_TAG,:trap_block).size,:magnet=>records_for(ABILITY_MAGNET_PULL,:trap_block).size,:arena=>records_for(ABILITY_ARENA_TRAP,:trap_block).size}
        log("ROUND3_FIX all_traps=true E2_types="+(e[2] ? types_of(e[2]).inspect : "nil")+" decoy=false")
      end
    end
    def self.prepare_round_actions
      prepare_round_fixture; apply_test_speeds; @actual=[]; a=test_allies; p=current_plan; return false unless p
      p[:allies].each_with_index do |cfg,i|; next unless a[i]&&a[i].hp.to_i>0; act=make_action(a[i],cfg); if a[i].respond_to?(:cg_round_actions); a[i].cg_round_actions.clear; a[i].cg_round_actions.push(act); end; a[i].cg_assign_action(act) if a[i].respond_to?(:cg_assign_action); a[i].instance_variable_set(:@action,act) unless a[i].respond_to?(:cg_assign_action); end
      log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s); true
    end
    def self.assert_order
      exp=EXPECTED_EXECUTION_TOKENS[current_round]||[]; ok=@actual==exp; @action_checks+=1 if ok; assert_true("Round"+current_round.to_s+" execution order matches deterministic plan",ok,"expected="+exp.inspect+" actual="+@actual.inspect)
    end
    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true; e=all_enemies
      assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil"))
      assert_true("Ability Batch AQ defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability AQ test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil"))
      assert_true("Ability AQ ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s); assert_true("Ability AQ enemy count=6",all_enemies.size==6,"actual="+all_enemies.size.to_s)
      emb=@entry_snapshot||{}; eok=emb[:embody_stage].to_i==@embody_pre.to_i+1&&emb[:embody_form]==:hearthflame; @form_checks+=1 if eok; assert_true("Embody Aspect Hearthflame entry raises ATK +1 once",eok,emb.inspect)
      tok=emb[:tera_form]==:terastal&&emb[:tera_max].to_i>@tera_pre[:maxhp].to_i&&emb[:tera_hp].to_i==emb[:tera_max].to_i&&emb[:tera_atk].to_i==95; @form_checks+=1 if tok; assert_true("Tera Shift entry applies Terastal profile and HP ratio",tok,"pre="+@tera_pre.inspect+" after="+emb.inspect)
    end
    def self.finish_round_assertions
      assert_order; a=test_allies; e=all_enemies; r=current_round
      if r==1
        srec=records_for(ABILITY_SHADOW_TAG,:trap_block)[-1]||{}; sok=!srec.empty?&&srec[:target_index].to_i==2&&!e[2].hidden; @trap_checks+=1 if sok; assert_true("Shadow Tag blocks real Teleport",sok,srec.inspect+" hidden="+(e[2] ? e[2].hidden.to_s : "nil"))
        rrec=records_for(ABILITY_RUN_AWAY,:run_away_bypass)[-1]||{}; rok=!rrec.empty?&&e[1]&&e[1].hidden&&e[4]&&!e[4].hidden; @trap_checks+=1 if rok; assert_true("Run Away bypasses Shadow Tag and real Teleport succeeds",rok,rrec.inspect+" E1_hidden="+(e[1] ? e[1].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        drec=records_for(ABILITY_DECOY,:decoy)[-1]||{}; dok=!drec.empty?&&a[3]&&a[3].hp.to_i==@r1_decoy_hp.to_i; @evasion_checks+=1 if dok; assert_true("Decoy forced proc evades real damaging Water Gun",dok,"hp="+@r1_decoy_hp.to_s+"->"+(a[3] ? a[3].hp.to_i.to_s : "nil")+" rec="+drec.inspect)
        prec=records_for(ABILITY_POWER_CONSTRUCT,:power_construct)[-1]||{}; pok=!prec.empty?&&form(e[0])==:complete&&prec[:lost_before].to_i==prec[:lost_after].to_i&&e[0].cg_atk_stat.to_i==100&&e[0].cg_def_stat.to_i==121; @form_checks+=1 if pok; @lifecycle_checks+=1 if pok; assert_true("Power Construct end-turn Complete preserves lost HP and profile",pok,prec.inspect)
      elsif r==2
        mrec=records_for(ABILITY_MAGNET_PULL,:trap_block)[-1]||{}; mok=!mrec.empty?&&mrec[:target_index].to_i==2&&e[2]&&!e[2].hidden; @trap_checks+=1 if mok; assert_true("Magnet Pull blocks Steel/Flying real Teleport",mok,mrec.inspect)
        arec=records_for(ABILITY_ARENA_TRAP,:trap_block)[-1]||{}; aok=!arec.empty?&&arec[:target_index].to_i==4&&e[4]&&!e[4].hidden; @trap_checks+=1 if aok; assert_true("Arena Trap blocks grounded Normal real Teleport",aok,arec.inspect)
      elsif r==3
        ghost_ok=e[2]&&e[2].hidden&&e[5]&&!e[5].hidden&&records_for(ABILITY_SHADOW_TAG,:trap_block).size==@r3_trap_counts[:shadow]&&records_for(ABILITY_MAGNET_PULL,:trap_block).size==@r3_trap_counts[:magnet]&&records_for(ABILITY_ARENA_TRAP,:trap_block).size==@r3_trap_counts[:arena]; @trap_checks+=1 if ghost_ok; @scope_checks+=1 if ghost_ok; assert_true("Ghost Steel target bypasses Shadow/Magnet/Arena and real Teleport succeeds",ghost_ok,"E2_hidden="+(e[2] ? e[2].hidden.to_s : "nil")+" E5_hidden="+(e[5] ? e[5].hidden.to_s : "nil"))
        decoy_off=records_for(ABILITY_DECOY,:decoy).size==@round_counts[ABILITY_DECOY]&&a[3]&&a[3].hp.to_i<@r3_decoy_hp.to_i; @evasion_checks+=1 if decoy_off; assert_true("Decoy forced no-proc leaves normal damage path",decoy_off,"hp="+@r3_decoy_hp.to_s+"->"+(a[3] ? a[3].hp.to_i.to_s : "nil"))
        pkeep=e[0]&&form(e[0])==:complete&&e[0].cg_atk_stat.to_i==100; @lifecycle_checks+=1 if pkeep; assert_true("Power Construct Complete profile persists",pkeep,"form="+(e[0] ? form(e[0]).inspect : "nil"))
        tkeep=e[3]&&form(e[3])==:terastal&&e[3].cg_atk_stat.to_i==95; @lifecycle_checks+=1 if tkeep; assert_true("Tera Shift Terastal profile persists until battle end",tkeep,"form="+(e[3] ? form(e[3]).inspect : "nil"))
        ekeep=records_for(ABILITY_EMBODY_ASPECT,:embody_aspect).size==1; @lifecycle_checks+=1 if ekeep; assert_true("Embody Aspect entry boost is one-shot",ekeep,"count="+records_for(ABILITY_EMBODY_ASPECT,:embody_aspect).size.to_s)
      end
      log("ROUND "+r.to_s+" END"); @round_index=@round_index.to_i+1
    end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|clear_test_runtime(b)}; @forced_proc=nil; rescue; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|aid|ok=@ability_trigger_counts[aid].to_i>0; assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)}
      log("------------------------------------------------------------"); result=@failures.empty? ? "PASS" : "FAIL"; log("RESULT="+result); passed=HANDLED_ABILITY_IDS.select{|x|@ability_trigger_counts[x].to_i>0}.size
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_aq="+passed.to_s+"/8 trap_checks="+@trap_checks.to_s+" form_checks="+@form_checks.to_s+" evasion_checks="+@evasion_checks.to_s+" lifecycle_checks="+@lifecycle_checks.to_s+" scope_checks="+@scope_checks.to_s+" action_checks="+@action_checks.to_s+" pending=29")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite; @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @trap_checks=0; @form_checks=0; @evasion_checks=0; @lifecycle_checks=0; @scope_checks=0; @action_checks=0; @forced_proc={}; @round_counts={}; end
    def self.reset_log
      h="CG POKEMON ABILITY AQ RETREAT TRAP + FORM IDENTITY + DECOY AUTO REGRESSION v2.5.42\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; Teleport trap/bypass + battle-local form identity + Decoy evasion\r\n"+
        "BASELINE=v2.5.41a Ability Batch AP RPG Maker VX real-machine PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AP_PASS=336 BATCH_AQ=8 PENDING=29\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue; end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AQ_v2.5.42") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e; @failures=[] if @failures==nil; @failures<<"AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s; log(@failures[-1]); @active=false; false; end
  end
end
ALBERT_CG::ABILITY_AQ_V2542.register_handlers if defined?(ALBERT_CG::ABILITY_AQ_V2542)
#==============================================================================
# ■ Formal bridges
#==============================================================================
class Game_Battler
  alias cg_v2542aq_maxhp maxhp
  def maxhp
    base=cg_v2542aq_maxhp; r=@cg_v2542aq_hp_ratio; return base if r==nil||!r.is_a?(Array)||r[1].to_i<=0
    [[base.to_i*r[0].to_i/r[1].to_i,1].max,maxhp_limit].min
  rescue; cg_v2542aq_maxhp; end
  alias cg_v2542aq_remove_states_battle remove_states_battle
  def remove_states_battle
    result=cg_v2542aq_remove_states_battle
    if defined?(ALBERT_CG::ABILITY_AQ_V2542); ALBERT_CG::ABILITY_AQ_V2542.clear_form_runtime(self); @cg_v2542aq_embody_mask=nil; end
    result
  end
  alias cg_v2542aq_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AQ_V2542)&&ALBERT_CG::ABILITY_AQ_V2542.active?; v=@cg_priority_test_speed_override_aq; return v.to_i if v!=nil; end
    cg_v2542aq_priority_base_speed
  rescue; cg_v2542aq_priority_base_speed; end
end
if defined?(ALBERT_CG::UNIQUE_I_V242)
  module ALBERT_CG; module UNIQUE_I_V242; class << self
    alias cg_v2542aq_teleport_block_reason teleport_block_reason
    def teleport_block_reason(user); base=cg_v2542aq_teleport_block_reason(user); defined?(ALBERT_CG::ABILITY_AQ_V2542) ? ALBERT_CG::ABILITY_AQ_V2542.resolve_teleport_block(user,base) : base; end
  end; end; end
end
# Power Construct / Tera Shift are Neutralizing Gas exemptions.
if defined?(ALBERT_CG::ABILITY_AG_V2532)
  module ALBERT_CG; module ABILITY_AG_V2532; class << self
    alias cg_v2542aq_gas_suppresses gas_suppresses?
    def gas_suppresses?(battler,raw_aid=nil)
      aid=raw_aid==nil ? raw_ability_id(battler).to_i : raw_aid.to_i
      return false if aid==ALBERT_CG::ABILITY_AQ_V2542::ABILITY_POWER_CONSTRUCT || aid==ALBERT_CG::ABILITY_AQ_V2542::ABILITY_TERA_SHIFT
      cg_v2542aq_gas_suppresses(battler,raw_aid)
    end
  end; end; end
end
class Scene_Battle < Scene_Base
  alias cg_v2542aq_start start
  def start
    ALBERT_CG::ABILITY_AQ_V2542.pre_scene_start if defined?(ALBERT_CG::ABILITY_AQ_V2542)&&ALBERT_CG::ABILITY_AQ_V2542.active?
    r=cg_v2542aq_start
    ALBERT_CG::ABILITY_AQ_V2542.capture_entry_snapshot if defined?(ALBERT_CG::ABILITY_AQ_V2542)&&ALBERT_CG::ABILITY_AQ_V2542.active?
    r
  end
  alias cg_v2542aq_execute_action execute_action
  def execute_action; ALBERT_CG::ABILITY_AQ_V2542.record_execution(@active_battler) if defined?(ALBERT_CG::ABILITY_AQ_V2542)&&ALBERT_CG::ABILITY_AQ_V2542.active?; cg_v2542aq_execute_action; end
  alias cg_v2542aq_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AQ_V2542)&&ALBERT_CG::ABILITY_AQ_V2542.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_AQ_V2542.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_AQ_V2542.finish_round_assertions; end
    end
    cg_v2542aq_turn_end
  end
  alias cg_v2542aq_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AQ_V2542)&&ALBERT_CG::ABILITY_AQ_V2542.active?; return cg_v2542aq_start_party_command; end
    cg_v2542aq_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_AQ_V2542.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AQ_V2542.finished?; ALBERT_CG::ABILITY_AQ_V2542.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_AQ_V2542.prepare_round_actions; start_main
  end
  alias cg_v2542aq_process_escape process_escape
  def process_escape
    if defined?(ALBERT_CG::ABILITY_AQ_V2542)
      h=ALBERT_CG::ABILITY_AQ_V2542.run_away_party_holder
      if h
        ALBERT_CG::ABILITY_AQ_V2542.present_external_trigger(ALBERT_CG::ABILITY_AQ_V2542::ABILITY_RUN_AWAY,h,:run_away_escape,{:escape=>true})
        old=@escape_ratio; @escape_ratio=100; r=cg_v2542aq_process_escape; @escape_ratio=old if $game_temp&&$game_temp.in_battle; return r
      end
    end
    cg_v2542aq_process_escape
  end
end
class Game_Enemy < Game_Battler
  alias cg_v2542aq_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AQ_V2542)&&ALBERT_CG::ABILITY_AQ_V2542.active?; a=ALBERT_CG::ABILITY_AQ_V2542.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end; end
    cg_v2542aq_enemy_make_action
  end
end
module ALBERT_CG; class << self
  alias cg_v2542aq_bootstrap_demo_party bootstrap_demo_party
  def bootstrap_demo_party
    r=cg_v2542aq_bootstrap_demo_party
    if defined?(ALBERT_CG::ABILITY_AQ_V2542)&&ALBERT_CG::ABILITY_AQ_V2542.active?
      ALBERT_CG::ABILITY_AQ_V2542::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AQ_V2542.configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_AQ_V2542::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); ALBERT_CG::ABILITY_AQ_V2542.set_ability(h,ALBERT_CG::ABILITY_AQ_V2542::ABILITY_SHADOW_TAG); end
    end
    r
  end
end; end
if defined?(ALBERT_CG::ABILITY_AP_V2541); module ALBERT_CG; module ABILITY_AP_V2541; def self.f11_trigger?; false; end; end; end; end
class Scene_Map < Scene_Base
  alias cg_v2542aq_scene_map_update update
  def update; cg_v2542aq_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_AQ_V2542); ALBERT_CG::ABILITY_AQ_V2542.start_auto_test if ALBERT_CG::ABILITY_AQ_V2542.f11_trigger?; end
end
