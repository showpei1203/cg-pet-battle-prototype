# RMVX_SCRIPT_INDEX: 270
# RMVX_SCRIPT_ID: 270
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AT v2.5.45a
# RMVX_SOURCE_SHA256: ae6c83518be24f59fe58aa47cfe258e910ebec5a0f89e4c448cd8abd26cade3c

#==============================================================================
# ■ CG Pokemon Ability Batch AT v2.5.45a
#------------------------------------------------------------------------------
# 【用途】
#  Ability 361..366 coverage batch：Action / Status / Utility Authority。
#  基底為 v2.5.44j Batch AS RPG Maker VX real-machine PASS；Scripts 0..269
#  皆視為 sealed byte-exact，本頁只透過既有公開 runtime authority 延伸。
#
# 【本批 Ability】
#  185 Parental Bond / 213 Comatose / 216 Dancer / 237 Ball Fetch
#  10001 Mountaineer / 10011 Tenacity
#
# 【CG 適配】
#  - Parental Bond：單體、單段、damaging Pokémon Move 使用既有 PMD multi-hit sequence
#    執行 2 hit；第 2 hit 為原 formal damage 的 25%。既有 multi-hit / spread / status 不重複套用。
#  - Comatose：不掛真正 Sleep state（避免 sealed VX restriction 禁止行動），而由 Guard
#    Authority 阻擋所有 primary status；Sleep Talk Authority 將 holder 視為可睡眠呼叫。
#  - Dancer：偵測本作 Master catalog 內的 Dance moves，於原 Dance action 完成後以既有
#    Unique H injected ActionEntry 立即複製；:dancer injected action 不再次觸發 recursion。
#  - Ball Fetch：本作 Poké Ball 對應 Capture Core「封印卡」。holder 空手且本場尚未發動時，
#    同側主角第一次真正消耗封印卡但捕捉失敗後，立即取回該 1 張封印卡。
#  - Mountaineer：沿用 sealed Grid 對 back row=high ground 的既有映射；holder 可由 back row
#    使用 melee 攻擊 enemy back row，不受敵方 front-row screen 阻擋，其餘 target legality 不變。
#  - Tenacity：受 opposing contact damaging hit 後 30% 使 attacker Flinch；因反應發生於攻擊者
#    本次 action 結束前，Flinch hold 設為 1，使其在本次 remove_states_auto 後保留並跳過下一次 action。
#
# 【F11】
#  3 rounds deterministic real Scene_Battle，驗證 6/6 ability、PB two-hit、Dancer injected action、
#  Mountaineer legal target、Comatose primary-status/Sleep Talk、Tenacity next-action flinch、Ball Fetch。
#==============================================================================
$imported={} if $imported==nil
$imported["ALBERT_CG_PokemonAbilityBatchAT"]="2.5.45"

module ALBERT_CG
  module ABILITY_AT_V2545
    VERSION="2.5.45"; TEST_LEVEL=40; TEST_TROOP_ID=748; VK_F11=0x7A
    ABILITY_PARENTAL_BOND=185; ABILITY_COMATOSE=213; ABILITY_DANCER=216
    ABILITY_BALL_FETCH=237; ABILITY_MOUNTAINEER=10001; ABILITY_TENACITY=10011
    HANDLED_ABILITY_IDS=[ABILITY_PARENTAL_BOND,ABILITY_COMATOSE,ABILITY_DANCER,
      ABILITY_BALL_FETCH,ABILITY_MOUNTAINEER,ABILITY_TENACITY]
    PB_SECOND_PERCENT=25; PROC_CHANCE=30
    MOVE_TACKLE=33; MOVE_BOUNCE=150; MOVE_THUNDERBOLT=85; MOVE_SLEEP_TALK=214
    MOVE_DRAGON_DANCE=349
    DANCE_MOVE_IDS=[14,80,240,297,298,349,461,483,552,686,837]
    PRIMARY_PENDING=7

    TEST_ALLIES=[
      {:dex=>134,:level=>40,:ability=>0,:moves=>[33,150]},
      {:dex=>363,:level=>40,:ability=>0,:moves=>[349,150,214,85]},
      {:dex=>132,:level=>40,:ability=>0,:moves=>[150,349]}]
    TEST_ENEMIES=[
      {:dex=>53, :level=>45,:ability=>0,:moves=>[33,150]},
      {:dex=>391,:level=>45,:ability=>0,:moves=>[150,150]},
      {:dex=>442,:level=>45,:ability=>0,:moves=>[150,150]},
      {:dex=>461,:level=>45,:ability=>0,:moves=>[150,150]},
      {:dex=>65, :level=>45,:ability=>0,:moves=>[150,150]}]

    ROUND_PLANS=[
      {:name=>"PARENTAL_DANCER_MOUNTAINEER",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>33,:target=>1},
         {:kind=>:move,:move_id=>349,:target=>2},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>33,:target=>2},1=>{:kind=>:move,:move_id=>150,:target=>0},
         2=>{:kind=>:move,:move_id=>150,:target=>0},3=>{:kind=>:move,:move_id=>150,:target=>0},
         4=>{:kind=>:move,:move_id=>150,:target=>0}}},
      {:name=>"COMATOSE_TENACITY",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>33,:target=>1},
         {:kind=>:move,:move_id=>214,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>0},1=>{:kind=>:move,:move_id=>150,:target=>0},
         2=>{:kind=>:move,:move_id=>150,:target=>0},3=>{:kind=>:move,:move_id=>150,:target=>0},
         4=>{:kind=>:move,:move_id=>150,:target=>0}}},
      {:name=>"BALL_FETCH_TENACITY_CARRY",
       :allies=>[
         {:kind=>:capture,:target=>4},
         {:kind=>:move,:move_id=>33,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>0},1=>{:kind=>:move,:move_id=>150,:target=>0},
         2=>{:kind=>:move,:move_id=>150,:target=>0},3=>{:kind=>:move,:move_id=>150,:target=>0},
         4=>{:kind=>:move,:move_id=>150,:target=>0}}}
    ]

    EXPECTED_EXECUTION_TOKENS={
      1=>["A2:M349","A3:M349:DANCER","A1:M33","A3:M150","A0:M150","E0:M33","E1:M150","E2:M150","E3:M150","E4:M150"],
      2=>["A1:M33","A2:M214","A0:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150","E4:M150"],
      3=>["A0:CAPTURE","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150","E4:M150"]}
    TEST_SPEEDS={
      1=>[800,900,1000,850,700,650,600,550,500],
      2=>[800,1000,900,700,650,600,550,500,450],
      3=>[1000,950,900,850,700,650,600,550,500]}

    begin; KEY_API=Win32API.new("user32","GetAsyncKeyState","i","i"); rescue; KEY_API=nil; end
    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party ? $game_party.members : []; end
    def self.all_enemies; $game_troop ? $game_troop.members : []; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.log(t); File.open(latest_log_path,"ab"){|f|f.write(t.to_s+"\r\n")}; rescue; end
    def self.key_down?(c); KEY_API&&(KEY_API.call(c)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.ability_id(b); core&&b ? core.ability_id(b).to_i : 0; rescue; 0; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.move_row(mid); master ? master.move(mid.to_i) : nil; rescue; nil; end
    def self.damaging_move?(skill); r=move_row(move_id(skill)); r&&r[7]!=:status&&r[3].to_i>0; rescue; false; end
    def self.same_side?(a,b); a&&b&&(a.actor? == b.actor?); rescue; false; end
    def self.opposing?(a,b); a&&b&&(a.actor? != b.actor?); rescue; false; end
    def self.sleep_state; defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_SLEEP : 39; end
    def self.flinch_state; defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_FLINCH : 48; end
    def self.primary_states; defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::PRIMARY_STATES : []; end

    def self.assert_true(label,cond,detail=nil)
      if cond; log("ASSERT PASS "+label.to_s+(detail ? " "+detail.to_s : ""))
      else; x=label.to_s+(detail ? " "+detail.to_s : ""); @failures<<x; log("ASSERT FAIL "+x); end
      cond
    end
    def self.note_local(aid,b,kind,data=nil)
      rec={:ability=>aid.to_i,:kind=>kind}; (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill,:action].include?(k)}
      if active?; @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1; (@records[aid.to_i]||=[])<<rec; log("ABILITY_AT_TRIGGER ability="+aid.to_s+" battler="+(b ? b.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect); end
      rec
    rescue; nil; end
    def self.formal_note(aid,b,kind,data=nil)
      ctx=data||{}; if core; core.note_trigger(kind,b,aid,ctx) if core.respond_to?(:note_trigger); core.present_trigger(b,aid,kind,ctx) if core.respond_to?(:present_trigger); end
      note_local(aid,b,kind,ctx); true
    rescue; false; end
    def self.records_for(aid,kind=nil); a=@records[aid.to_i]||[]; kind ? a.select{|x|x[:kind].to_sym==kind.to_sym} : a; rescue; []; end
    def self.set_ability(b,aid); return unless b; b.instance_variable_set(:@cg_v237_ability_override,nil); b.instance_variable_set(:@cg_v237_ability_suppressed,false); b.instance_variable_set(:@cg_master_ability_id,aid.to_i); end
    def self.set_slot(b,row,col); b.cg_set_battle_slot(row,col,true) if b&&b.respond_to?(:cg_set_battle_slot); end
    def self.set_slot_quiet(b,row,col); return unless b; old=b.instance_variable_get(:@cg_as_ignore_move_track); b.instance_variable_set(:@cg_as_ignore_move_track,true); set_slot(b,row,col); b.instance_variable_set(:@cg_as_ignore_move_track,old); end

    #--------------------------------------------------------------------------
    # Parental Bond
    #--------------------------------------------------------------------------
    def self.parental_eligible?(user,skill)
      return false unless user&&skill&&ability_id(user)==ABILITY_PARENTAL_BOND&&damaging_move?(skill)
      return false if skill.respond_to?(:for_all?)&&skill.for_all?
      return false if skill.respond_to?(:for_one?)&&!skill.for_one?
      return false if skill.respond_to?(:for_opponent?)&&!skill.for_opponent?
      mid=move_id(skill); return false if mid<=0
      hits=defined?(ALBERT_CG::MOVE_EFFECT)&&ALBERT_CG::MOVE_EFFECT.respond_to?(:multi_hit_count) ? ALBERT_CG::MOVE_EFFECT.multi_hit_count(mid).to_i : 1
      hits<=1
    rescue; false; end
    def self.pb_begin(user,skill); return false unless parental_eligible?(user,skill); user.instance_variable_set(:@cg_at_pb_scope_skill_id,skill.id.to_i); user.instance_variable_set(:@cg_at_pb_hit_index,0); true; end
    def self.pb_end(user); return unless user; user.instance_variable_set(:@cg_at_pb_scope_skill_id,nil); user.instance_variable_set(:@cg_at_pb_hit_index,0); end
    def self.pb_scope?(user,obj); user&&obj&&ability_id(user)==ABILITY_PARENTAL_BOND&&user.instance_variable_get(:@cg_at_pb_scope_skill_id).to_i==obj.id.to_i; rescue; false; end
    def self.pb_next_hit(user,obj); return 0 unless pb_scope?(user,obj); i=user.instance_variable_get(:@cg_at_pb_hit_index).to_i+1; user.instance_variable_set(:@cg_at_pb_hit_index,i); i; end
    def self.pb_scale_damage(target,user,obj)
      return false unless target&&pb_scope?(user,obj)&&user.instance_variable_get(:@cg_at_pb_hit_index).to_i==2
      raw=target.instance_variable_get(:@hp_damage).to_i; return false if raw<=0
      scaled=[raw*PB_SECOND_PERCENT/100,1].max; target.instance_variable_set(:@cg_at_pb_pre_scale_damage,raw); target.instance_variable_set(:@hp_damage,scaled)
      bd=target.instance_variable_get(:@cg_last_damage_breakdown); if bd.is_a?(Hash); bd=bd.dup; bd[:damage]=scaled; bd[:parental_bond_percent]=PB_SECOND_PERCENT; target.instance_variable_set(:@cg_last_damage_breakdown,bd); end
      formal_note(ABILITY_PARENTAL_BOND,user,:parental_bond,{:move_id=>move_id(obj),:hit=>2,:before=>raw,:after=>scaled,:percent=>PB_SECOND_PERCENT,:target_index=>target.index.to_i})
      true
    rescue; false; end
    def self.pb_record_hit(target,user,obj,before_hp)
      return unless active?&&pb_scope?(user,obj); i=user.instance_variable_get(:@cg_at_pb_hit_index).to_i; (@pb_hits||=[])<<{:hit=>i,:move_id=>move_id(obj),:target_index=>target.index.to_i,:hp_before=>before_hp.to_i,:hp_after=>target.hp.to_i,:loss=>[before_hp.to_i-target.hp.to_i,0].max,:pre_scale=>target.instance_variable_get(:@cg_at_pb_pre_scale_damage)}; target.instance_variable_set(:@cg_at_pb_pre_scale_damage,nil)
      log("PB_HIT hit="+i.to_s+" target="+target.name.to_s+" hp="+before_hp.to_i.to_s+"->"+target.hp.to_i.to_s+" rec="+@pb_hits[-1].inspect)
    rescue; end

    #--------------------------------------------------------------------------
    # Comatose
    #--------------------------------------------------------------------------
    def self.comatose?(b); ability_id(b)==ABILITY_COMATOSE; rescue; false; end
    def self.comatose_called_move(b)
      return 0 unless b&&comatose?(b)&&defined?(ALBERT_CG::UNIQUE_B_V234)
      pool=b.cg_v234_known_move_ids.select{|mid|mid.to_i!=MOVE_SLEEP_TALK&&ALBERT_CG::UNIQUE_B_V234.callable_move?(mid)} rescue []
      return 0 if pool.empty?; mid=pool[0].to_i; formal_note(ABILITY_COMATOSE,b,:comatose_sleep_talk,{:called_move_id=>mid,:state_sleep=>b.state?(sleep_state)}); mid
    rescue; 0; end
    def self.note_comatose_guard(b,state_id,source); note_local(ABILITY_COMATOSE,b,:comatose_guard,{:state_id=>state_id.to_i,:source=>source}) if active?; end

    #--------------------------------------------------------------------------
    # Dancer
    #--------------------------------------------------------------------------
    def self.dance_move?(mid); DANCE_MOVE_IDS.include?(mid.to_i); end
    def self.dancer_target_index(holder,skill,source_index)
      return holder.index.to_i if skill&&skill.respond_to?(:scope)&&skill.scope.to_i==11
      source_index.to_i
    end
    def self.queue_dancers(scene,source,skill,target_index)
      return 0 unless scene&&source&&skill&&dance_move?(move_id(skill))&&defined?(ALBERT_CG::UNIQUE_H_V241)
      entries=scene.instance_variable_get(:@action_battlers); return 0 unless entries.is_a?(Array)
      holders=(core ? core.active_battlers : []).select{|b|b&&b!=source&&ability_id(b)==ABILITY_DANCER&&b.hp.to_i>0}
      count=0
      holders.reverse_each do |h|
        tidx=dancer_target_index(h,skill,target_index)
        entry=ALBERT_CG::UNIQUE_H_V241.build_injected_entry(h,move_id(skill),tidx,:dancer); next unless entry
        entries.unshift(entry); formal_note(ABILITY_DANCER,h,:dancer_queue,{:source_index=>source.index.to_i,:move_id=>move_id(skill),:target_index=>tidx}); count+=1
      end
      count
    rescue=>e; log("DANCER_QUEUE_ERROR "+e.class.to_s+":"+e.message.to_s) if active?; 0; end

    #--------------------------------------------------------------------------
    # Ball Fetch
    #--------------------------------------------------------------------------
    def self.ball_fetch_start(holder,ctx); holder.instance_variable_set(:@cg_at_ball_fetch_used,false) if holder; false; end
    def self.ball_fetch_holder_for(user)
      return nil unless user&&core
      core.active_battlers.find{|b|b&&same_side?(b,user)&&ability_id(b)==ABILITY_BALL_FETCH&&b.instance_variable_get(:@cg_at_ball_fetch_used)!=true&&(!b.respond_to?(:cg_held_item)||b.cg_held_item==nil)}
    rescue; nil; end
    def self.try_ball_fetch(user,target,card,before_count)
      return false unless user&&target&&card&&$game_party&&target.exist?
      after=$game_party.item_number(card).to_i; return false unless after==before_count.to_i-1
      holder=ball_fetch_holder_for(user); return false unless holder
      $game_party.gain_item(card,1); holder.instance_variable_set(:@cg_at_ball_fetch_used,true)
      formal_note(ABILITY_BALL_FETCH,holder,:ball_fetch,{:user_index=>user.index.to_i,:target_index=>target.index.to_i,:item_id=>card.id.to_i,:before=>before_count.to_i,:after=>$game_party.item_number(card).to_i}); true
    rescue; false; end

    #--------------------------------------------------------------------------
    # Mountaineer / Tenacity
    #--------------------------------------------------------------------------
    def self.mountaineer_override?(action,target)
      b=action.respond_to?(:battler) ? action.battler : nil; return false unless b&&target&&ability_id(b)==ABILITY_MOUNTAINEER&&target.exist?
      return false unless b.actor? != target.actor?&&action.respond_to?(:cg_melee_action?)&&action.cg_melee_action?
      return false if b.respond_to?(:cg_front_row?)&&b.cg_front_row?
      return false if target.respond_to?(:cg_front_row?)&&target.cg_front_row?
      unit=action.respond_to?(:opponents_unit) ? action.opponents_unit : nil; return false unless unit&&unit.respond_to?(:cg_front_row_occupied?)&&unit.cg_front_row_occupied?
      if active?; key=[current_round,b.object_id,target.object_id]; @mount_notes||={}; unless @mount_notes[key]; @mount_notes[key]=true; formal_note(ABILITY_MOUNTAINEER,b,:mountaineer,{:target_index=>target.index.to_i,:user_row=>b.cg_battle_row,:target_row=>target.cg_battle_row}); end; end
      true
    rescue; false; end
    def self.proc_success?(aid); return @forced_proc[aid.to_i] if active?&&@forced_proc&&@forced_proc.has_key?(aid.to_i); rand(100)<PROC_CHANCE; rescue; false; end
    def self.apply_tenacity(holder,ctx)
      return false unless holder&&ctx&&ability_id(holder)==ABILITY_TENACITY&&ctx[:contact]==true&&ctx[:damage_done].to_i>0
      a=ctx[:user]; return false unless a&&opposing?(holder,a)&&a.hp.to_i>0&&proc_success?(ABILITY_TENACITY)
      sid=flinch_state; return false if a.state?(sid); a.add_state(sid); return false unless a.state?(sid)
      h=a.instance_variable_get(:@state_turns); h[sid]=[h[sid].to_i,1].max if h.is_a?(Hash)
      note_local(ABILITY_TENACITY,holder,:tenacity,{:attacker_index=>a.index.to_i,:move_id=>ctx[:move_id].to_i,:state_id=>sid,:hold=>(h.is_a?(Hash) ? h[sid].to_i : nil)}); true
    rescue; false; end
    def self.register_handlers
      return false unless core; core.register(ABILITY_BALL_FETCH,:battle_start,self,:ball_fetch_start); core.register(ABILITY_TENACITY,:after_contact,self,:apply_tenacity); true
    end

    #--------------------------------------------------------------------------
    # Harness helpers
    #--------------------------------------------------------------------------
    def self.clear_runtime(b)
      return unless b; b.instance_variable_set(:@cg_priority_test_speed_override_at,nil); b.instance_variable_set(:@cg_at_pb_scope_skill_id,nil); b.instance_variable_set(:@cg_at_pb_hit_index,0); b.instance_variable_set(:@cg_at_capture_rate_override,nil)
    end
    def self.configure_actor(cfg); a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return unless a; master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); clear_runtime(a); end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end
    def self.set_actor_moves(b,mids)
      return unless b&&b.actor?; sids=mids.collect{|m|master.skill_id_for_move(m.to_i)}.select{|x|x.to_i>0}; b.instance_variable_set(:@cg_equipped_skill_ids,sids); b.instance_variable_set(:@cg_skill_slot_ids,sids); b.instance_variable_set(:@skills,sids)
    end
    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}; ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true); $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!); TEST_ALLIES.each{|c|configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); clear_runtime(h); set_ability(h,0); set_actor_moves(h,[150]); end
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID); xs=[ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X]; ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[2]]; ms=[]
      TEST_ENEMIES.each_with_index{|c,i|configure_enemy(c); m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=false; ms<<m}
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AT v2.5.45a AutoRegression",ms)
    end
    def self.restore_no_abilities; (test_allies+all_enemies).each{|b|set_ability(b,0) if b}; end
    def self.pre_scene_start; (test_allies+all_enemies).each{|b|clear_runtime(b)}; restore_no_abilities; end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:capture&&a.respond_to?(:cg_set_capture); a.cg_set_capture; elsif c[:kind]==:guard; a.set_guard; else; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; c=current_plan[:enemies][e.index] rescue nil; c ? make_action(e,c) : nil; end
    def self.action_token(b)
      return "nil" unless b; s=b.actor? ? "A" : "E"; a=b.action; return s+b.index.to_s+":CAPTURE" if a&&a.respond_to?(:cg_capture_action?)&&a.cg_capture_action?; return s+b.index.to_s+":Guard" if a&&a.guard?
      if a&&a.skill?; t=s+b.index.to_s+":M"+move_id(a.skill).to_s; tag=a.instance_variable_get(:@cg_v241_injected_tag); t+=":DANCER" if tag==:dancer; return t; end; s+b.index.to_s+":Other"
    rescue; "?"; end
    def self.record_execution(b); return unless active?; @actual<<action_token(b); log("ACTION_EXEC #"+@actual.size.to_s+" "+(b ? b.name.to_s : "nil")+" token="+@actual[-1].to_s); end
    def self.apply_test_speeds; sp=TEST_SPEEDS[current_round]||[]; (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_at,sp[i]) if b&&sp[i]!=nil}; end
    def self.apply_round_slots
      a=test_allies; e=all_enemies; set_slot_quiet(a[0],:front,0); set_slot_quiet(a[1],:front,1); set_slot_quiet(a[2],:back,2); set_slot_quiet(a[3],:back,1)
      set_slot_quiet(e[0],:back,0); set_slot_quiet(e[1],:front,1); set_slot_quiet(e[2],:front,2); set_slot_quiet(e[3],:front,0); set_slot_quiet(e[4],:back,2)
    end
    def self.prepare_round_fixture
      a=test_allies; e=all_enemies; r=current_round; restore_no_abilities; apply_round_slots; @forced_proc={}; @mount_notes={}
      if r==1
        set_ability(a[1],ABILITY_PARENTAL_BOND); set_ability(a[3],ABILITY_DANCER); set_ability(e[0],ABILITY_MOUNTAINEER)
        set_actor_moves(a[1],[33,150]); set_actor_moves(a[2],[349,150]); set_actor_moves(a[3],[150]); set_actor_moves(a[0],[150])
        @pb_hits=[]; @r1_mount_target_hp=e[0]&&a[2] ? a[2].hp.to_i : 0; @r1_pb_target_hp=e[1] ? e[1].hp.to_i : 0
        pb_probe=make_action(a[1],{:kind=>:move,:move_id=>33,:target=>1}); @r1_pb_target_legal=pb_probe.respond_to?(:cg_target_legal?)&&pb_probe.cg_target_legal?(e[1]); normal_id=defined?(ALBERT_CG::POKEMON_COMBAT)&&ALBERT_CG::POKEMON_COMBAT.respond_to?(:type_id) ? ALBERT_CG::POKEMON_COMBAT.type_id(:normal).to_i : 0; @r1_pb_type_rate=e[1]&&normal_id>0&&e[1].respond_to?(:cg_pokemon_type_rate_percent) ? e[1].cg_pokemon_type_rate_percent(normal_id).to_i : -1
        probe=make_action(e[0],{:kind=>:move,:move_id=>33,:target=>2}); @r1_mount_legal=probe.respond_to?(:cg_target_legal?)&&probe.cg_target_legal?(a[2])
        log("ROUND1_FIX parental=true pb_target="+(e[1] ? e[1].name.to_s : "nil")+" pb_target_legal="+@r1_pb_target_legal.to_s+" pb_normal_rate="+@r1_pb_type_rate.to_i.to_s+" dancer=true mountaineer_legal="+@r1_mount_legal.to_s+" mount_target_slot="+(a[2] ? [a[2].cg_battle_row,a[2].cg_battle_column].inspect : "nil"))
      elsif r==2
        set_ability(a[2],ABILITY_COMATOSE); set_ability(e[1],ABILITY_TENACITY); @forced_proc[ABILITY_TENACITY]=true
        set_actor_moves(a[1],[33,150]); set_actor_moves(a[2],[214,85,214]); set_actor_moves(a[3],[150]); set_actor_moves(a[0],[150])
        ps=defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_POISON : 0; a[2].add_state(ps) if ps>0; a[2].add_state(sleep_state)
        @r2_comatose_no_primary=(ps<=0||!a[2].state?(ps))&&!a[2].state?(sleep_state); @r2_tenacity_before=records_for(ABILITY_TENACITY,:tenacity).size
        log("ROUND2_FIX comatose_primary_block="+@r2_comatose_no_primary.to_s+" tenacity_proc=true")
      else
        set_ability(a[3],ABILITY_BALL_FETCH); set_actor_moves(a[1],[33,150]); set_actor_moves(a[2],[150]); set_actor_moves(a[3],[150]); set_actor_moves(a[0],[150])
        a[3].cg_set_battle_held_item(0,nil) if a[3]&&a[3].respond_to?(:cg_set_battle_held_item); e[4].instance_variable_set(:@cg_at_capture_rate_override,0) if e[4]
        card=defined?(ALBERT_CG)&&ALBERT_CG.respond_to?(:capture_card) ? ALBERT_CG.capture_card : nil; if card&&$game_party; $game_party.gain_item(card,2); @r3_card_before=$game_party.item_number(card).to_i; @r3_card_added=2; end
        @r3_tenacity_flinch_pre=a[1] ? a[1].state?(flinch_state) : false; @r3_skip_target_hp=e[0] ? e[0].hp.to_i : 0
        log("ROUND3_FIX ball_fetch=true card_before="+@r3_card_before.to_i.to_s+" tenacity_flinch_pre="+@r3_tenacity_flinch_pre.to_s)
      end
    end
    def self.prepare_round_actions
      prepare_round_fixture; apply_test_speeds; @actual=[]; a=test_allies; p=current_plan; return false unless p
      p[:allies].each_with_index{|cfg,i|next unless a[i]&&a[i].hp.to_i>0; act=make_action(a[i],cfg); if a[i].respond_to?(:cg_round_actions); a[i].cg_round_actions.clear; a[i].cg_round_actions.push(act); end; a[i].cg_assign_action(act) if a[i].respond_to?(:cg_assign_action); a[i].instance_variable_set(:@action,act) unless a[i].respond_to?(:cg_assign_action)}
      log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s); true
    end
    def self.consecutive_tokens?(left,right)
      ary=@actual||[]; i=0; while i+1<ary.size; return true if ary[i]==left&&ary[i+1]==right; i+=1; end; false
    end
    def self.assert_order; exp=EXPECTED_EXECUTION_TOKENS[current_round]||[]; ok=@actual==exp; @action_checks+=1 if ok; assert_true("Round"+current_round.to_s+" execution order matches deterministic plan",ok,"expected="+exp.inspect+" actual="+@actual.inspect); end
    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true; assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil")); assert_true("Ability Batch AT defines 6 handled IDs",HANDLED_ABILITY_IDS.size==6,"actual="+HANDLED_ABILITY_IDS.size.to_s); assert_true("Scene_Battle uses Ability AT test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil")); assert_true("Ability AT ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s); assert_true("Ability AT enemy count=5",all_enemies.size==5,"actual="+all_enemies.size.to_s)
    end
    def self.finish_round_assertions
      assert_order; a=test_allies; e=all_enemies; r=current_round
      if r==1
        hits=@pb_hits||[]; h2=hits.find{|x|x[:hit].to_i==2}||{}; pbok=@r1_pb_target_legal==true&&@r1_pb_type_rate.to_i>0&&hits.size==2&&h2[:target_index].to_i==1&&h2[:loss].to_i>0&&h2[:pre_scale].to_i>0&&h2[:loss].to_i==[h2[:pre_scale].to_i*PB_SECOND_PERCENT/100,1].max; @mechanic_checks+=1 if pbok; assert_true("Parental Bond uses exactly two real hits and second hit is 25% formal damage",pbok,"target_legal="+@r1_pb_target_legal.to_s+" normal_rate="+@r1_pb_type_rate.to_i.to_s+" hits="+hits.inspect)
        dr=records_for(ABILITY_DANCER,:dancer_queue)[-1]||{}; di=consecutive_tokens?("A2:M349","A3:M349:DANCER"); dok=!dr.empty?&&di; @mechanic_checks+=1 if dok; assert_true("Dancer immediately injects copied Dragon Dance",dok,"record="+dr.inspect+" actual="+@actual.inspect)
        mr=records_for(ABILITY_MOUNTAINEER,:mountaineer)[-1]||{}; mok=@r1_mount_legal==true&&!mr.empty?&&a[2]&&a[2].hp.to_i<@r1_mount_target_hp.to_i; @mechanic_checks+=1 if mok; assert_true("Mountaineer back-row melee reaches enemy back row through front-row screen",mok,"record="+mr.inspect+" hp="+@r1_mount_target_hp.to_s+"->"+(a[2] ? a[2].hp.to_i.to_s : "nil"))
      elsif r==2
        cg=records_for(ABILITY_COMATOSE,:comatose_guard); cs=records_for(ABILITY_COMATOSE,:comatose_sleep_talk); cok=@r2_comatose_no_primary==true&&cg.size>=2&&!cs.empty?&&a[2]&&a[2].respond_to?(:cg_v234_last_move_id)&&a[2].cg_v234_last_move_id.to_i==MOVE_THUNDERBOLT; @mechanic_checks+=2 if cok; assert_true("Comatose blocks primary status without real Sleep and Sleep Talk calls a move",cok,"guards="+cg.size.to_s+" sleep_call="+(cs[-1]||{}).inspect+" last_move="+(a[2]&&a[2].respond_to?(:cg_v234_last_move_id) ? a[2].cg_v234_last_move_id.to_i.to_s : "nil"))
        tr=records_for(ABILITY_TENACITY,:tenacity); tok=tr.size>@r2_tenacity_before.to_i&&a[1]&&a[1].state?(flinch_state); @mechanic_checks+=1 if tok; assert_true("Tenacity contact proc carries Flinch into attacker's next action",tok,"record="+(tr[-1]||{}).inspect+" flinch="+(a[1] ? a[1].state?(flinch_state).to_s : "nil"))
      else
        card=ALBERT_CG.respond_to?(:capture_card) ? ALBERT_CG.capture_card : nil; cr=records_for(ABILITY_BALL_FETCH,:ball_fetch)[-1]||{}; card_after=card&&$game_party ? $game_party.item_number(card).to_i : -1; bfok=!cr.empty?&&card_after==@r3_card_before.to_i; @mechanic_checks+=1 if bfok; assert_true("Ball Fetch returns first actually consumed failed capture card",bfok,"record="+cr.inspect+" cards="+@r3_card_before.to_i.to_s+"->"+card_after.to_s)
        skip=!@actual.include?("A1:M33")&&e[0]&&e[0].hp.to_i==@r3_skip_target_hp.to_i&&!a[1].state?(flinch_state); @mechanic_checks+=1 if skip; assert_true("Tenacity Flinch skips exactly the next action then clears",skip,"actual="+@actual.inspect+" target_hp="+@r3_skip_target_hp.to_s+"->"+(e[0] ? e[0].hp.to_i.to_s : "nil")+" flinch_end="+(a[1] ? a[1].state?(flinch_state).to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END"); @round_index=@round_index.to_i+1
    end
    def self.cleanup_output_logs; keep=["CG_AutoRegression_LATEST.log","PMD_BattleInitTrace.log"]; Dir.glob(File.join(project_root,"*.log")).each{|p|next if keep.include?(File.basename(p)); begin;File.delete(p);rescue;end}; true; rescue; false; end
    def self.cleanup_test_overrides
      card=ALBERT_CG.respond_to?(:capture_card) ? ALBERT_CG.capture_card : nil; if card&&$game_party&&@r3_card_added.to_i>0; n=[$game_party.item_number(card).to_i,@r3_card_added.to_i].min; $game_party.lose_item(card,n) if n>0; end
      (test_allies+all_enemies).each{|b|clear_runtime(b)}; @forced_proc={}; rescue; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|aid|ok=@ability_trigger_counts[aid].to_i>0; assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)}
      log("------------------------------------------------------------"); result=@failures.empty? ? "PASS" : "FAIL"; log("RESULT="+result); passed=HANDLED_ABILITY_IDS.select{|x|@ability_trigger_counts[x].to_i>0}.size
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_at="+passed.to_s+"/6 mechanic_checks="+@mechanic_checks.to_s+" action_checks="+@action_checks.to_s+" pending=7")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; cleanup_output_logs; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite; @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @mechanic_checks=0; @action_checks=0; @pb_hits=[]; @forced_proc={}; @mount_notes={}; @r3_card_added=0; end
    def self.reset_log
      cleanup_output_logs; h="CG POKEMON ABILITY AT ACTION + STATUS + UTILITY AUTO REGRESSION v2.5.45a\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; sealed AS baseline + PMD multi-hit + injected action + status/capture/grid/contact authorities\r\n"+
        "BASELINE=v2.5.44j Ability Batch AS RPG Maker VX real-machine PASS; Move=937/937; Full Move Lifecycle=13/13\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AS_PASS=360 BATCH_AT=6 PENDING=7\r\n"+
        "BUILD=AT_v2.5.45a_PB_FIXTURE_RGSS2_COMPAT_TEST\r\n"+
        "LEAN_LOGS=send CG_AutoRegression_LATEST.log + PMD_BattleInitTrace.log\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue; end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AT_v2.5.45a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e; @failures=[] if @failures==nil; @failures<<"AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s; log(@failures[-1]); @active=false; false; end
  end
end

ALBERT_CG::ABILITY_AT_V2545.register_handlers if defined?(ALBERT_CG::ABILITY_AT_V2545)

#==============================================================================
# ■ Formal bridges
#==============================================================================
# Parental Bond: choose existing PMD 2-hit sequence.
if defined?(CG_PMD)
  module CG_PMD
    class << self
      alias cg_v2545at_skill_sequence_for skill_sequence_for
      def skill_sequence_for(skill,battler=nil)
        base=cg_v2545at_skill_sequence_for(skill,battler)
        if battler&&defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.parental_eligible?(battler,skill)
          battler.instance_variable_set(:@cg_pmd_pending_multi_hits,2)
          seq=multi_sequence_name(skill_motion_for(skill),2)
          return seq unless seq==nil
        end
        base
      end
    end
  end
end

class Game_Battler
  alias cg_v2545at_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.active?&&@cg_priority_test_speed_override_at!=nil; return @cg_priority_test_speed_override_at.to_i; end
    cg_v2545at_priority_base_speed
  rescue; cg_v2545at_priority_base_speed; end

  alias cg_v2545at_skill_effect skill_effect
  def skill_effect(user,skill)
    pb=defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.pb_scope?(user,skill); ALBERT_CG::ABILITY_AT_V2545.pb_next_hit(user,skill) if pb; before=hp.to_i
    result=cg_v2545at_skill_effect(user,skill)
    ALBERT_CG::ABILITY_AT_V2545.pb_record_hit(self,user,skill,before) if pb
    result
  end

  alias cg_v2545at_make_obj_damage_value make_obj_damage_value
  def make_obj_damage_value(user,obj)
    result=cg_v2545at_make_obj_damage_value(user,obj)
    ALBERT_CG::ABILITY_AT_V2545.pb_scale_damage(self,user,obj) if defined?(ALBERT_CG::ABILITY_AT_V2545)
    result
  end

  # Dancer-injected action is virtual: it need not be in holder's learned slots.
  alias cg_v2545at_skill_can_use skill_can_use?
  def skill_can_use?(skill)
    if defined?(ALBERT_CG::ABILITY_AT_V2545)&&action&&action.instance_variable_get(:@cg_v241_injected_tag)==:dancer&&action.skill?&&action.skill_id.to_i==skill.id.to_i
      return cg_v234_skill_can_use_without_learning(skill) if respond_to?(:cg_v234_skill_can_use_without_learning)
    end
    cg_v2545at_skill_can_use(skill)
  end
end

# Comatose extends sealed Guard Authority rather than inventing a second state system.
if defined?(ALBERT_CG::ABILITY_GUARD_V251)
  module ALBERT_CG
    module ABILITY_GUARD_V251
      class << self
        alias cg_v2545at_state_guard_table state_guard_table
        def state_guard_table
          t=cg_v2545at_state_guard_table; t[ALBERT_CG::ABILITY_AT_V2545::ABILITY_COMATOSE]=ALBERT_CG::ABILITY_AT_V2545.primary_states.clone if defined?(ALBERT_CG::ABILITY_AT_V2545); t
        end
        alias cg_v2545at_block_state block_state
        def block_state(battler,state_id,source=:unknown)
          r=cg_v2545at_block_state(battler,state_id,source)
          if r&&defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.comatose?(battler)&&ALBERT_CG::ABILITY_AT_V2545.primary_states.include?(state_id.to_i); ALBERT_CG::ABILITY_AT_V2545.note_comatose_guard(battler,state_id,source); end
          r
        end
      end
    end
  end
end

# Comatose lets sealed Sleep Talk choose from known callable moves without real Sleep state.
if defined?(ALBERT_CG::UNIQUE_B_V234)
  module ALBERT_CG
    module UNIQUE_B_V234
      class << self
        alias cg_v2545at_choose_called_move choose_called_move
        def choose_called_move(battler,parent_mid)
          v=cg_v2545at_choose_called_move(battler,parent_mid)
          if v.to_i<=0&&parent_mid.to_i==ALBERT_CG::ABILITY_AT_V2545::MOVE_SLEEP_TALK&&ALBERT_CG::ABILITY_AT_V2545.comatose?(battler); return ALBERT_CG::ABILITY_AT_V2545.comatose_called_move(battler); end
          v
        end
      end
    end
  end
end

# Mountaineer extends only the sealed Grid's row-elevation legality failure.
class Game_BattleAction
  alias cg_v2545at_target_legal cg_target_legal?
  def cg_target_legal?(target)
    r=cg_v2545at_target_legal(target); return true if r
    return true if defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.mountaineer_override?(self,target)
    r
  end
end

# Ball Fetch: observe actual Capture Core consumption + failed target persistence.
class Scene_Battle < Scene_Base
  alias cg_v2545at_capture_action cg_execute_capture_action if method_defined?(:cg_execute_capture_action)
  if method_defined?(:cg_v2545at_capture_action)
    def cg_execute_capture_action
      user=@active_battler; target=respond_to?(:cg_capture_target_from_action) ? cg_capture_target_from_action : nil; card=respond_to?(:cg_capture_card) ? cg_capture_card : nil; before=(card&&$game_party ? $game_party.item_number(card).to_i : -1)
      result=cg_v2545at_capture_action
      ALBERT_CG::ABILITY_AT_V2545.try_ball_fetch(user,target,card,before) if defined?(ALBERT_CG::ABILITY_AT_V2545)&&before>=0
      result
    end
  end

  alias cg_v2545at_start start
  def start
    ALBERT_CG::ABILITY_AT_V2545.pre_scene_start if defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.active?
    cg_v2545at_start
  end

  alias cg_v2545at_execute_action execute_action
  def execute_action
    b=@active_battler; action=b ? b.action : nil; skill=(action&&action.skill?) ? action.skill : nil; mid=skill ? ALBERT_CG::ABILITY_AT_V2545.move_id(skill) : 0; target_index=action ? action.target_index.to_i : 0; tag=action ? action.instance_variable_get(:@cg_v241_injected_tag) : nil
    ALBERT_CG::ABILITY_AT_V2545.record_execution(b) if defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.active?
    pb=defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.pb_begin(b,skill)
    ALBERT_CG::ABILITY_AT_V2545.note_local(ALBERT_CG::ABILITY_AT_V2545::ABILITY_DANCER,b,:dancer_execute,{:move_id=>mid}) if defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.active?&&tag==:dancer
    begin
      result=cg_v2545at_execute_action
      if skill&&tag!=:dancer&&defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.dance_move?(mid); ALBERT_CG::ABILITY_AT_V2545.queue_dancers(self,b,skill,target_index); end
      result
    ensure
      ALBERT_CG::ABILITY_AT_V2545.pb_end(b) if pb&&defined?(ALBERT_CG::ABILITY_AT_V2545)
    end
  end

  alias cg_v2545at_turn_end turn_end
  def turn_end
    ALBERT_CG::ABILITY_AT_V2545.finish_round_assertions if defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.active?
    cg_v2545at_turn_end
  end

  alias cg_v2545at_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.active?; return cg_v2545at_start_party_command; end
    cg_v2545at_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_AT_V2545.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AT_V2545.finished?; ALBERT_CG::ABILITY_AT_V2545.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_AT_V2545.prepare_round_actions; start_main
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2545at_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.active?; a=ALBERT_CG::ABILITY_AT_V2545.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end; end
    cg_v2545at_enemy_make_action
  end
  alias cg_v2545at_capture_chance cg_capture_chance if method_defined?(:cg_capture_chance)
  if method_defined?(:cg_v2545at_capture_chance)
    def cg_capture_chance(user=nil,card=nil); v=@cg_at_capture_rate_override; return v.to_i if defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.active?&&v!=nil; cg_v2545at_capture_chance(user,card); end
  end
end

module ALBERT_CG
  class << self
    alias cg_v2545at_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2545at_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_AT_V2545)&&ALBERT_CG::ABILITY_AT_V2545.active?; ALBERT_CG::ABILITY_AT_V2545::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AT_V2545.configure_actor(c)}; h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_AT_V2545::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); ALBERT_CG::ABILITY_AT_V2545.clear_runtime(h); ALBERT_CG::ABILITY_AT_V2545.set_ability(h,0); ALBERT_CG::ABILITY_AT_V2545.set_actor_moves(h,[150]); end; end
      r
    end
  end
end

if defined?(ALBERT_CG::ABILITY_AS_V2544)
  module ALBERT_CG; module ABILITY_AS_V2544; def self.f11_trigger?; false; end; end; end
end

class Scene_Map < Scene_Base
  alias cg_v2545at_scene_map_update update
  def update; cg_v2545at_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_AT_V2545); ALBERT_CG::ABILITY_AT_V2545.start_auto_test if ALBERT_CG::ABILITY_AT_V2545.f11_trigger?; end
end
