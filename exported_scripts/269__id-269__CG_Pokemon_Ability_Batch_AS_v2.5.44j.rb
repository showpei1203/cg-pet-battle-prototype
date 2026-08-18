# RMVX_SCRIPT_INDEX: 269
# RMVX_SCRIPT_ID: 269
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AS v2.5.44j
# RMVX_SOURCE_SHA256: 453341a3d0b6f4f43188389d3b4690fa00f475c55e0b01efa56ffe4e8a3f7080

#==============================================================================
# ■ CG Pokemon Ability Batch AS v2.5.44j
#------------------------------------------------------------------------------
# 【用途】
#  Ability 353..360 coverage batch：Conquest Grid / Protection / Momentum Authority。
#  以已封版 Battlefield Grid、Ability Core、Damage pipeline、Unique H injected ActionEntry
#  為唯一正式 Authority，不建立第二套座標、傷害或行動佇列。
#
# 【本批 Ability】
#  10004 Thrust / 10027 Bodyguard / 10032 Nomad / 10035 Celebrate
#  10046 Omnipotent / 10051 Disgust / 10056 Run Up / 10060 Shield
#
# 【CG 適配】
#  - Thrust：成功 damaging hit 後，front target 推到同 column 的 back row。
#  - Bodyguard：每回合一次，鄰接 active ally 被敵方 damaging Move 命中前，
#    holder 與 ally 交換格位並承受該 hit。
#  - Nomad：本回合透過正式 cg_set_battle_slot 移動的 Manhattan distance，
#    每 1 格 ATK ×1.20，最多 3 格（×1.60）。
#  - Run Up：同一 movement distance 每 1 格使本次直接傷害 ×1.20，最多 ×1.60。
#  - Celebrate：真正 Move KO 後每回合最多一次，沿用 Unique H ActionEntry 立即追加
#    同 Move 的一次 action，目標改為下一名存活 foe。
#  - Omnipotent：整合 Instinct-like 30% damaging Move evasion、Life Force 1/8 end-turn heal，
#    並使 holder 的 damaging Move 能將原本 0% type immunity 視為 neutral 100%。
#    CG 無 Conquest climb restriction，因此 Mountaineer component 不額外建立假地形規則。
#  - Disgust：成功 damaging hit 後，若 target 有相鄰 active ally，兩者交換 Grid slot。
#  - Shield：front holder 保護同 column back ally，使敵方 damaging Move 對該 rear ally miss。
#
# 【LEAN LOG 規則】
#  F11 後只需回傳：CG_AutoRegression_LATEST.log、PMD_BattleInitTrace.log。
#==============================================================================
$imported={} if $imported==nil
$imported["ALBERT_CG_PokemonAbilityBatchAS"]="2.5.44j"

module ALBERT_CG
  module ABILITY_AS_V2544
    VERSION="2.5.44j"
    TEST_LEVEL=40
    TEST_TROOP_ID=747
    VK_F11=0x7A

    ABILITY_THRUST=10004
    ABILITY_BODYGUARD=10027
    ABILITY_NOMAD=10032
    ABILITY_CELEBRATE=10035
    ABILITY_OMNIPOTENT=10046
    ABILITY_DISGUST=10051
    ABILITY_RUN_UP=10056
    ABILITY_SHIELD=10060
    HANDLED_ABILITY_IDS=[10004,10027,10032,10035,10046,10051,10056,10060]

    MOVE_STEP_PERCENT=20
    MOVE_STEP_CAP=3
    OMNI_EVASION_PERCENT=30
    OMNI_HEAL_DENOM=8

    TEST_ALLIES=[
      {:dex=>134,:level=>40,:ability=>ABILITY_NOMAD,:moves=>[55,150,150]},
      {:dex=>363,:level=>40,:ability=>ABILITY_RUN_UP,:moves=>[55,150,150]},
      {:dex=>132,:level=>40,:ability=>ABILITY_OMNIPOTENT,:moves=>[33,150,150]}]
    TEST_ENEMIES=[
      {:dex=>53, :level=>45,:ability=>ABILITY_THRUST,   :moves=>[55,150,150]},
      {:dex=>391,:level=>45,:ability=>ABILITY_BODYGUARD,:moves=>[150,150,150]},
      {:dex=>442,:level=>45,:ability=>ABILITY_DISGUST,  :moves=>[55,150,150]},
      {:dex=>461,:level=>45,:ability=>ABILITY_SHIELD,   :moves=>[150,150,150]},
      {:dex=>65, :level=>45,:ability=>0,                :moves=>[55,150,150]}]

    ROUND_PLANS=[
      {:name=>"MOTION_DAMAGE_OMNI",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>55,:target=>0},
         {:kind=>:move,:move_id=>55,:target=>0},
         {:kind=>:move,:move_id=>33,:target=>2}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>55,:target=>0},
         1=>{:kind=>:move,:move_id=>150,:target=>0},
         2=>{:kind=>:move,:move_id=>55,:target=>1},
         3=>{:kind=>:move,:move_id=>150,:target=>0},
         4=>{:kind=>:move,:move_id=>55,:target=>3}}},
      {:name=>"BODYGUARD_SHIELD",
       :allies=>[
         {:kind=>:move,:move_id=>55,:target=>2},
         {:kind=>:move,:move_id=>55,:target=>4},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>0},
         1=>{:kind=>:move,:move_id=>150,:target=>0},
         2=>{:kind=>:move,:move_id=>150,:target=>0},
         3=>{:kind=>:move,:move_id=>150,:target=>0},
         4=>{:kind=>:move,:move_id=>150,:target=>0}}},
      {:name=>"CELEBRATE_EXTRA_ACTION",
       :allies=>[
         {:kind=>:move,:move_id=>55,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>0},
         1=>{:kind=>:move,:move_id=>150,:target=>0},
         2=>{:kind=>:move,:move_id=>150,:target=>0},
         3=>{:kind=>:move,:move_id=>150,:target=>0},
         4=>{:kind=>:move,:move_id=>150,:target=>0}}}]

    EXPECTED_EXECUTION_TOKENS={
      1=>["A0:M150","A1:M55","A2:M55","A3:M33","E0:M55","E1:M150","E2:M55","E3:M150","E4:M55"],
      2=>["A0:M55","A1:M55","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150","E4:M150"],
      3=>["A0:M55","A0:M55:CELEBRATE","A1:M150","A2:M150","A3:M150","E1:M150","E2:M150","E3:M150","E4:M150"]}

    TEST_SPEEDS={
      1=>[900,850,800,750,500,450,400,350,300],
      2=>[900,850,800,750,500,450,400,350,300],
      3=>[900,850,800,750,500,450,400,350,300]}

    begin
      KEY_API=Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API=nil
    end

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
    def self.key_down?(c); KEY_API && (KEY_API.call(c)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.move_row(mid); master ? master.move(mid.to_i) : nil; rescue; nil; end
    def self.damaging_move?(skill); r=move_row(move_id(skill)); r!=nil&&r[7]!=:status&&r[3].to_i>0; rescue; false; end
    def self.ability_id(b); core&&b ? core.ability_id(b).to_i : 0; rescue; 0; end
    def self.same_side?(a,b); a&&b&&(a.actor? == b.actor?); rescue; false; end
    def self.opposing?(a,b); a&&b&&(a.actor? != b.actor?); rescue; false; end

    def self.assert_true(label,cond,detail=nil)
      if cond
        log("ASSERT PASS "+label.to_s+(detail ? " "+detail.to_s : ""))
      else
        x=label.to_s+(detail ? " "+detail.to_s : "")
        @failures<<x
        log("ASSERT FAIL "+x)
      end
      cond
    end

    def self.note_local(aid,b,kind,data=nil)
      rec={:ability=>aid.to_i,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill,:action].include?(k)}
      if active?
        @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1
        (@records[aid.to_i]||=[])<<rec
        log("ABILITY_AS_TRIGGER ability="+aid.to_s+" battler="+(b ? b.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect)
      end
      rec
    rescue
      nil
    end

    def self.records_for(aid,kind=nil)
      a=@records[aid.to_i]||[]
      return a unless kind
      a.select{|x|x[:kind].to_sym==kind.to_sym}
    rescue
      []
    end

    def self.note_passive_once(aid,b,kind,data=nil)
      return nil unless active?
      @passive_noted||={}
      key=[@round_index.to_i,aid.to_i,b ? b.object_id : 0,kind]
      return nil if @passive_noted[key]
      @passive_noted[key]=true
      note_local(aid,b,kind,data)
    end

    def self.set_ability(b,aid)
      return unless b
      b.instance_variable_set(:@cg_v237_ability_override,nil)
      b.instance_variable_set(:@cg_v237_ability_suppressed,false)
      b.instance_variable_set(:@cg_master_ability_id,aid.to_i)
    end

    def self.row_value(row); row==:front ? 0 : 1; end
    def self.slot_distance(a,b)
      return 99 unless a&&b&&a.respond_to?(:cg_battle_row)&&b.respond_to?(:cg_battle_row)
      (row_value(a.cg_battle_row)-row_value(b.cg_battle_row)).abs+(a.cg_battle_column.to_i-b.cg_battle_column.to_i).abs
    rescue
      99
    end
    def self.adjacent?(a,b); slot_distance(a,b)<=1; end

    def self.set_slot_quiet(b,row,col)
      return unless b&&b.respond_to?(:cg_set_battle_slot)
      b.instance_variable_set(:@cg_as_ignore_move_track,true)
      b.cg_set_battle_slot(row,col,true)
      b.instance_variable_set(:@cg_as_ignore_move_track,false)
      [:@cg_as_omni_scope_user,:@cg_as_omni_scope_skill_id,:@cg_as_omni_scope_original_types,
       :@cg_as_omni_scope_scoped_types,:@cg_as_omni_scope_original_chart,:@cg_as_omni_scope_before_hp,
       :@cg_as_omni_replay_applied,:@cg_as_omni_force_neutral_rate,:@cg_as_omni_force_user,
       :@cg_as_omni_force_skill_id,:@cg_as_omni_rate_forced].each{|iv| b.instance_variable_set(iv,nil) rescue nil}
    rescue
      b.instance_variable_set(:@cg_as_ignore_move_track,false) if b
    end

    def self.swap_slots(a,b,track=true)
      return false unless a&&b&&a.respond_to?(:cg_battle_row)&&b.respond_to?(:cg_battle_row)
      ar=a.cg_battle_row; ac=a.cg_battle_column
      br=b.cg_battle_row; bc=b.cg_battle_column
      if track
        a.cg_set_battle_slot(br,bc,true); b.cg_set_battle_slot(ar,ac,true)
      else
        set_slot_quiet(a,br,bc); set_slot_quiet(b,ar,ac)
      end
      true
    rescue
      false
    end

    def self.reset_movement(b)
      return unless b
      b.instance_variable_set(:@cg_as_distance_moved,0)
    end
    def self.reset_round_flags
      (test_allies+all_enemies).each do |b|
        next unless b
        reset_movement(b)
        b.instance_variable_set(:@cg_as_bodyguard_used,false)
        b.instance_variable_set(:@cg_as_celebrate_used,false)
        b.instance_variable_set(:@cg_as_celebrate_pending,nil)
      end
    rescue
    end
    def self.movement_distance(b)
      return 0 unless b
      [b.instance_variable_get(:@cg_as_distance_moved).to_i,MOVE_STEP_CAP].min
    rescue
      0
    end
    def self.movement_percent(b)
      100+movement_distance(b)*MOVE_STEP_PERCENT
    end

    def self.apply_nomad_atk(b,base)
      return base.to_i unless b&&ability_id(b)==ABILITY_NOMAD
      dist=movement_distance(b)
      return base.to_i if dist<=0
      pct=movement_percent(b)
      after=[base.to_i*pct/100,1].max
      note_passive_once(ABILITY_NOMAD,b,:nomad,{:distance=>dist,:before=>base.to_i,:after=>after,:percent=>pct})
      after
    rescue
      base.to_i
    end

    def self.apply_run_up_damage(user,target,skill,damage)
      d=damage.to_i
      return d unless user&&target&&skill&&d>0&&opposing?(user,target)&&ability_id(user)==ABILITY_RUN_UP
      dist=movement_distance(user)
      return d if dist<=0
      pct=movement_percent(user)
      after=[d*pct/100,1].max
      note_local(ABILITY_RUN_UP,user,:run_up,{:distance=>dist,:target_index=>target.index.to_i,:move_id=>move_id(skill),:before=>d,:after=>after,:percent=>pct})
      after
    rescue
      damage.to_i
    end

    def self.apply_thrust_or_disgust(user,target,skill,damage_done)
      return false unless user&&target&&skill&&damage_done.to_i>0&&target.hp.to_i>0&&opposing?(user,target)
      aid=ability_id(user)
      if aid==ABILITY_THRUST
        return false unless target.respond_to?(:cg_battle_row)&&target.cg_battle_row==:front
        before=[target.cg_battle_row,target.cg_battle_column]
        target.cg_set_battle_slot(:back,target.cg_battle_column.to_i,true)
        note_local(ABILITY_THRUST,user,:thrust,{:target_index=>target.index.to_i,:move_id=>move_id(skill),:before=>before,:after=>[target.cg_battle_row,target.cg_battle_column],:damage_done=>damage_done.to_i})
        return true
      elsif aid==ABILITY_DISGUST
        allies=core ? core.allies_of(target) : []
        cand=allies.select{|x|x&&x!=target&&adjacent?(target,x)}
        cand.sort!{|x,y| [slot_distance(target,x),x.index.to_i] <=> [slot_distance(target,y),y.index.to_i]}
        other=cand[0]
        return false unless other
        before_t=[target.cg_battle_row,target.cg_battle_column]
        before_o=[other.cg_battle_row,other.cg_battle_column]
        swap_slots(target,other,true)
        note_local(ABILITY_DISGUST,user,:disgust,{:target_index=>target.index.to_i,:swap_index=>other.index.to_i,:move_id=>move_id(skill),:target_before=>before_t,:target_after=>[target.cg_battle_row,target.cg_battle_column],:ally_before=>before_o,:ally_after=>[other.cg_battle_row,other.cg_battle_column],:damage_done=>damage_done.to_i})
        return true
      end
      false
    rescue
      false
    end

    def self.find_bodyguard(target,user)
      return nil unless target&&user&&opposing?(target,user)
      list=core ? core.allies_of(target) : []
      list.each do |b|
        next if b==nil||b==target||b.hidden||b.hp.to_i<=0
        next unless ability_id(b)==ABILITY_BODYGUARD
        next if b.instance_variable_get(:@cg_as_bodyguard_used)==true
        return b if adjacent?(b,target)
      end
      nil
    rescue
      nil
    end

    def self.find_shield(target,user)
      return nil unless target&&user&&opposing?(target,user)
      return nil unless target.respond_to?(:cg_battle_row)&&target.cg_battle_row==:back
      list=core ? core.allies_of(target) : []
      list.each do |b|
        next if b==nil||b==target||b.hidden||b.hp.to_i<=0
        next unless ability_id(b)==ABILITY_SHIELD
        next unless b.respond_to?(:cg_battle_row)&&b.cg_battle_row==:front
        return b if b.cg_battle_column.to_i==target.cg_battle_column.to_i
      end
      nil
    rescue
      nil
    end

    def self.begin_redirect; @redirecting=true; end
    def self.end_redirect; @redirecting=false; end
    def self.redirecting?; @redirecting==true; end

    def self.intercept_bodyguard(target,user,skill)
      return nil if redirecting?||!damaging_move?(skill)
      g=find_bodyguard(target,user)
      return nil unless g
      before_g=[g.cg_battle_row,g.cg_battle_column]
      before_t=[target.cg_battle_row,target.cg_battle_column]
      swap_slots(g,target,true)
      g.instance_variable_set(:@cg_as_bodyguard_used,true)
      note_local(ABILITY_BODYGUARD,g,:bodyguard,{:protected_index=>target.index.to_i,:attacker_index=>user.index.to_i,:move_id=>move_id(skill),:guard_before=>before_g,:guard_after=>[g.cg_battle_row,g.cg_battle_column],:target_before=>before_t,:target_after=>[target.cg_battle_row,target.cg_battle_column]})
      g
    rescue
      nil
    end

    def self.intercept_shield(target,user,skill)
      return nil if redirecting?||!damaging_move?(skill)
      g=find_shield(target,user)
      return nil unless g
      note_local(ABILITY_SHIELD,g,:shield,{:protected_index=>target.index.to_i,:attacker_index=>user.index.to_i,:move_id=>move_id(skill),:shield_row=>g.cg_battle_row,:shield_column=>g.cg_battle_column})
      g
    rescue
      nil
    end

    def self.omni_proc?
      if active?&&@forced_omni_proc!=nil
        return @forced_omni_proc==true
      end
      rand(100)<OMNI_EVASION_PERCENT
    rescue
      false
    end

    def self.apply_omni_evasion(holder,ctx)
      return false unless holder&&ctx&&ability_id(holder)==ABILITY_OMNIPOTENT
      user=ctx[:user]; skill=ctx[:skill]
      return false unless user&&skill&&opposing?(holder,user)&&damaging_move?(skill)
      return false unless omni_proc?
      ctx[:cancel]=true; ctx[:hp_damage]=0
      note_local(ABILITY_OMNIPOTENT,holder,:omni_evasion,{:attacker_index=>user.index.to_i,:move_id=>move_id(skill),:percent=>OMNI_EVASION_PERCENT})
      true
    rescue
      false
    end

    def self.apply_omni_heal(holder,ctx)
      return false unless holder&&ability_id(holder)==ABILITY_OMNIPOTENT&&holder.hp.to_i>0&&holder.hp.to_i<holder.maxhp.to_i
      amount=[holder.maxhp.to_i/OMNI_HEAL_DENOM,1].max
      amount=[amount,holder.maxhp.to_i-holder.hp.to_i].min
      return false if amount<=0
      before=holder.hp.to_i
      holder.hp+=amount
      note_local(ABILITY_OMNIPOTENT,holder,:omni_heal,{:hp_before=>before,:hp_after=>holder.hp.to_i,:heal=>amount})
      true
    rescue
      false
    end

    #--------------------------------------------------------------------------
    # Omnipotent Scene Action type scope
    #--------------------------------------------------------------------------
    # Tankentai's actual PMD action path can bypass higher-level damage/type
    # wrappers.  Scene_Battle#execute_action itself is authoritative, however.
    # For one complete Omnipotent Normal/Fighting damaging Action, temporarily
    # replace each opposing type-immune battler's battle-local type override
    # with the SAME effective type list minus the Type(s) causing 0%. A pure immune target becomes a
    # scoped typeless marker (unknown defense type => neutral 100% in the formal
    # Pokemon type chart).  The original override is restored in ensure.
    # This keeps the original SBS damage popup/reaction/KO pipeline intact.
    OMNI_TYPELESS_SCOPE=:__cg_omni_typeless

    def self.omni_attack_type_key(skill)
      return nil if skill==nil
      tid=skill.respond_to?(:cg_pokemon_type_id) ? skill.cg_pokemon_type_id.to_i : 0
      if tid<=0 && skill.respond_to?(:physical_attack) && skill.physical_attack
        tid=ALBERT_CG::POKEMON_COMBAT::TYPE_IDS[:normal].to_i rescue 0
      end
      defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_key(tid) : nil
    rescue
      nil
    end

    def self.omni_scene_scope_candidate?(user,skill)
      return false if user==nil||skill==nil
      return false unless ability_id(user)==ABILITY_OMNIPOTENT
      return false unless damaging_move?(skill)
      omni_attack_type_key(skill)!=nil
    rescue
      false
    end

    def self.begin_omni_scene_scope(user,skill)
      return [] unless omni_scene_scope_candidate?(user,skill)
      return [] unless core
      key=omni_attack_type_key(skill)
      result=[]
      (core.opponents_of(user)||[]).each do |target|
        next if target==nil||target.hp.to_i<=0
        next unless target.respond_to?(:cg_pokemon_types)
        types=(target.cg_pokemon_types||[]).dup
        chart=defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_chart_percent(key,types).to_i : 100
        next unless chart==0
        blocked=[]
        types.each do |t|
          one=ALBERT_CG::POKEMON_COMBAT.type_chart_percent(key,[t]).to_i rescue 100
          blocked.push(t) if one==0
        end
        next if blocked.empty?
        filtered=types.reject{|t|blocked.include?(t)}
        scoped=filtered.empty? ? [OMNI_TYPELESS_SCOPE] : filtered
        old=target.instance_variable_get(:@cg_v237_type_override)
        before_hp=target.hp.to_i
        target.instance_variable_set(:@cg_v237_type_override,scoped)
        target.instance_variable_set(:@cg_as_omni_scope_user,user)
        target.instance_variable_set(:@cg_as_omni_scope_skill_id,skill.id.to_i)
        target.instance_variable_set(:@cg_as_omni_scope_original_types,types)
        target.instance_variable_set(:@cg_as_omni_scope_scoped_types,scoped)
        target.instance_variable_set(:@cg_as_omni_scope_original_chart,chart.to_i)
        target.instance_variable_set(:@cg_as_omni_scope_before_hp,before_hp.to_i)
        target.instance_variable_set(:@cg_as_omni_replay_applied,nil)
        result.push([target,old,types,scoped,before_hp])
        log("OMNI_SCOPE_BEGIN route=scene_execute_action user="+user.name.to_s+
          " target="+target.name.to_s+" move="+move_id(skill).to_s+
          " type="+key.to_s+" before_types="+types.inspect+
          " scoped_types="+scoped.inspect+" chart="+chart.to_s) if active?
      end
      result
    rescue=>e
      log("OMNI_SCOPE_BEGIN_ERROR "+e.class.to_s+":"+e.message.to_s) if active?
      []
    end

    def self.omni_scope_match?(target,user,skill)
      return false if target==nil||user==nil||skill==nil
      target.instance_variable_get(:@cg_as_omni_scope_user).equal?(user) &&
        target.instance_variable_get(:@cg_as_omni_scope_skill_id).to_i==skill.id.to_i &&
        target.instance_variable_get(:@cg_as_omni_scope_original_chart).to_i==0
    rescue
      false
    end

    def self.omni_trace_hit?(target,user,skill)
      return false unless omni_scope_match?(target,user,skill)
      return false unless ability_id(user)==ABILITY_OMNIPOTENT&&damaging_move?(skill)
      true
    rescue
      false
    end

    def self.omni_manual_rate_components(target,attack_type)
      key=defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_key(attack_type) : nil
      return nil if key==nil||target==nil
      types=target.respond_to?(:cg_pokemon_types) ? (target.cg_pokemon_types||[]) : []
      chart=ALBERT_CG::POKEMON_COMBAT.type_chart_percent(key,types).to_i rescue 100
      intrinsic=target.respond_to?(:cg_intrinsic_type_rate_percent) ? target.cg_intrinsic_type_rate_percent(key).to_i : 100
      notes=100
      if target.respond_to?(:cg_type_rate_sources)&&target.respond_to?(:cg_note_type_rate)
        (target.cg_type_rate_sources||[]).each do |src|
          notes=notes*target.cg_note_type_rate(src,key).to_i/100
        end
      end
      {:key=>key,:types=>types,:chart=>chart,:intrinsic=>intrinsic,:notes=>notes,
       :manual=>chart*intrinsic*notes/10000}
    rescue
      nil
    end

    # Hit-frame fallback.  Called by Scene_Battle#pop_damage AFTER the original
    # target skill_effect attempt but BEFORE Tankentai creates its damage popup.
    # Therefore a recovered damage value still uses the normal popup/reaction/KO
    # presentation instead of becoming a late HP-only correction.
    def self.omni_hitframe_replay(target,user,skill)
      return false unless omni_trace_hit?(target,user,skill)
      before=target.instance_variable_get(:@cg_as_omni_scope_before_hp).to_i
      return false if before<=0||target.hp.to_i<before
      missed=target.instance_variable_get(:@missed)==true
      evaded=target.instance_variable_get(:@evaded)==true
      skipped=target.instance_variable_get(:@skipped)==true
      return false if missed||evaded||skipped
      return false if target.instance_variable_get(:@cg_as_omni_replay_applied)
      mid=move_id(skill)
      comp=omni_manual_rate_components(target,omni_attack_type_key(skill))
      log("OMNI_REPLAY_BEGIN route=pop_damage_hitframe user="+user.name.to_s+
        " target="+target.name.to_s+" move="+mid.to_s+
        " hp="+before.to_s+"->"+target.hp.to_i.to_s+
        " flags=missed:"+missed.to_s+",evaded:"+evaded.to_s+",skipped:"+skipped.to_s+
        " rate_components="+(comp||{}).inspect) if active?
      target.instance_variable_set(:@cg_as_omni_force_neutral_rate,true)
      target.instance_variable_set(:@cg_as_omni_force_user,user)
      target.instance_variable_set(:@cg_as_omni_force_skill_id,skill.id.to_i)
      begin
        target.make_obj_damage_value(user,skill)
        planned=target.instance_variable_get(:@hp_damage).to_i
        breakdown=target.instance_variable_get(:@cg_last_damage_breakdown)
        log("OMNI_REPLAY_PLAN route=pop_damage_hitframe planned="+planned.to_s+
          " breakdown="+(breakdown||{}).inspect) if active?
        return false if planned<=0
        target.make_obj_absorb_effect(user,skill) if target.respond_to?(:make_obj_absorb_effect)
        target.execute_damage(user)
        done=[before-target.hp.to_i,0].max
        if done>0
          rec={:target_index=>(target.respond_to?(:index) ? target.index.to_i : -1),
               :attack_type=>omni_attack_type_key(skill),:before=>0,:after=>100,
               :move_id=>mid,:route=>:pop_damage_hitframe_replay,:damage=>done}
          target.instance_variable_set(:@cg_as_omni_replay_applied,rec)
          note_local(ABILITY_OMNIPOTENT,user,:omni_type_bypass,rec)
          log("OMNI_ROUTE route=pop_damage_hitframe_replay user="+user.name.to_s+
            " target="+target.name.to_s+" move="+mid.to_s+" damage="+done.to_s) if active?
          return true
        end
      ensure
        target.instance_variable_set(:@cg_as_omni_force_neutral_rate,false)
        target.instance_variable_set(:@cg_as_omni_force_user,nil)
        target.instance_variable_set(:@cg_as_omni_force_skill_id,nil)
      end
      false
    rescue=>e
      log("OMNI_REPLAY_ERROR "+e.class.to_s+":"+e.message.to_s) if active?
      false
    end

    def self.clear_omni_scope_meta(target)
      return if target==nil
      [:@cg_as_omni_scope_user,:@cg_as_omni_scope_skill_id,
       :@cg_as_omni_scope_original_types,:@cg_as_omni_scope_scoped_types,
       :@cg_as_omni_scope_original_chart,:@cg_as_omni_scope_before_hp,
       :@cg_as_omni_replay_applied,:@cg_as_omni_force_neutral_rate,
       :@cg_as_omni_force_user,:@cg_as_omni_force_skill_id,
       :@cg_as_omni_rate_forced].each{|iv| target.instance_variable_set(iv,nil) rescue nil}
    end

    def self.end_omni_scene_scope(scope,user,skill)
      return if scope==nil
      key=omni_attack_type_key(skill)
      scope.each do |entry|
        target,old,types,scoped,before_hp=entry
        begin
          after_hp=target.hp.to_i
          replay=target.instance_variable_get(:@cg_as_omni_replay_applied)
          if after_hp<before_hp.to_i
            if replay==nil
              rate=defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_chart_percent(key,scoped).to_i : 100
              rate=100 if scoped==[OMNI_TYPELESS_SCOPE]
              rec={:target_index=>(target.respond_to?(:index) ? target.index.to_i : -1),
                   :attack_type=>key,:before=>0,:after=>rate,:move_id=>move_id(skill),
                   :route=>:scene_execute_action_type_scope,:damage=>before_hp.to_i-after_hp}
              note_local(ABILITY_OMNIPOTENT,user,:omni_type_bypass,rec)
              log("OMNI_ROUTE route=scene_execute_action_type_scope user="+user.name.to_s+
                " target="+target.name.to_s+" move="+move_id(skill).to_s+
                " before_types="+types.inspect+" scoped_types="+scoped.inspect+
                " damage="+(before_hp.to_i-after_hp).to_s) if active?
            else
              log("OMNI_SCOPE_END replay_confirmed=true damage="+(before_hp.to_i-after_hp).to_s) if active?
            end
          else
            log("OMNI_SCOPE_NO_DAMAGE route=scene_execute_action user="+user.name.to_s+
              " target="+target.name.to_s+" move="+move_id(skill).to_s+
              " hp="+before_hp.to_i.to_s+"->"+after_hp.to_s) if active?
          end
        ensure
          target.instance_variable_set(:@cg_v237_type_override,old) if target
          clear_omni_scope_meta(target)
        end
      end
    rescue=>e
      log("OMNI_SCOPE_END_ERROR "+e.class.to_s+":"+e.message.to_s) if active?
      (scope||[]).each do |entry|
        begin
          entry[0].instance_variable_set(:@cg_v237_type_override,entry[1])
          clear_omni_scope_meta(entry[0])
        rescue
        end
      end
    end

    def self.apply_celebrate(holder,ctx)
      return false unless holder&&ctx&&ability_id(holder)==ABILITY_CELEBRATE
      return false if holder.instance_variable_get(:@cg_as_celebrate_used)==true
      target=ctx[:target]
      return false unless target&&target.hp.to_i<=0&&opposing?(holder,target)
      mid=ctx[:move_id].to_i
      return false if mid<=0
      holder.instance_variable_set(:@cg_as_celebrate_pending,{:move_id=>mid,:ko_target_index=>target.index.to_i})
      note_local(ABILITY_CELEBRATE,holder,:celebrate_ko,{:move_id=>mid,:target_index=>target.index.to_i})
      true
    rescue
      false
    end

    def self.queue_celebrate(scene,holder)
      return false unless scene&&holder
      pending=holder.instance_variable_get(:@cg_as_celebrate_pending)
      return false unless pending.is_a?(Hash)
      holder.instance_variable_set(:@cg_as_celebrate_pending,nil)
      return false if holder.instance_variable_get(:@cg_as_celebrate_used)==true
      foes=core ? core.opponents_of(holder) : []
      target=foes[0]
      return false unless target
      return false unless defined?(ALBERT_CG::UNIQUE_H_V241)&&ALBERT_CG::UNIQUE_H_V241.respond_to?(:build_injected_entry)
      entry=ALBERT_CG::UNIQUE_H_V241.build_injected_entry(holder,pending[:move_id].to_i,target.index.to_i,:celebrate)
      return false unless entry
      entries=scene.instance_variable_get(:@action_battlers)
      return false unless entries.is_a?(Array)
      entries.unshift(entry)
      holder.instance_variable_set(:@cg_as_celebrate_used,true)
      note_local(ABILITY_CELEBRATE,holder,:celebrate_queue,{:move_id=>pending[:move_id].to_i,:target_index=>target.index.to_i})
      true
    rescue=>e
      log("CELEBRATE_QUEUE_ERROR "+e.class.to_s+":"+e.message.to_s) if active?
      false
    end

    def self.register_handlers
      return false unless core
      core.register(ABILITY_OMNIPOTENT,:before_hit,self,:apply_omni_evasion)
      core.register(ABILITY_OMNIPOTENT,:end_turn,self,:apply_omni_heal)
      core.register(ABILITY_CELEBRATE,:after_ko,self,:apply_celebrate)
      true
    end

    def self.clear_test_runtime(b)
      return unless b
      b.instance_variable_set(:@cg_priority_test_speed_override_as,nil)
      b.instance_variable_set(:@cg_as_distance_moved,0)
      b.instance_variable_set(:@cg_as_bodyguard_used,false)
      b.instance_variable_set(:@cg_as_celebrate_used,false)
      b.instance_variable_set(:@cg_as_celebrate_pending,nil)
      b.instance_variable_set(:@cg_as_ignore_move_track,false)
    end

    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]
      return unless a
      master.configure_actor(a,cfg)
      a.recover_all if a.respond_to?(:recover_all)
      a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages)
      clear_test_runtime(a)
    end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end

    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}
      ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each{|c|configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if h
        h.change_level(TEST_LEVEL,false); h.recover_all
        h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages)
        clear_test_runtime(h); set_ability(h,ABILITY_CELEBRATE)
        mids=[55,150]; sids=mids.collect{|m|master.skill_id_for_move(m)}
        h.instance_variable_set(:@cg_equipped_skill_ids,sids)
        h.instance_variable_set(:@cg_skill_slot_ids,sids)
        h.instance_variable_set(:@skills,sids)
      end
    end

    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[1]]
      ms=[]
      TEST_ENEMIES.each_with_index do |c,i|
        configure_enemy(c)
        m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i])
        m.hidden=false
        ms<<m
      end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AS v2.5.44j AutoRegression",ms)
    end

    def self.restore_base_abilities
      a=test_allies; e=all_enemies
      set_ability(a[0],ABILITY_CELEBRATE) if a[0]
      set_ability(a[1],ABILITY_NOMAD) if a[1]
      set_ability(a[2],ABILITY_RUN_UP) if a[2]
      set_ability(a[3],ABILITY_OMNIPOTENT) if a[3]
      set_ability(e[0],ABILITY_THRUST) if e[0]
      set_ability(e[1],ABILITY_BODYGUARD) if e[1]
      set_ability(e[2],ABILITY_DISGUST) if e[2]
      set_ability(e[3],ABILITY_SHIELD) if e[3]
      set_ability(e[4],0) if e[4]
    end

    def self.pre_scene_start
      (test_allies+all_enemies).each{|b|clear_test_runtime(b)}
      restore_base_abilities
    end

    def self.make_action(b,c)
      a=Game_BattleAction.new(b)
      c[:kind]==:guard ? a.set_guard : a.set_skill(master.skill_id_for_move(c[:move_id].to_i))
      a.target_index=c[:target].to_i if c.has_key?(:target)
      a
    end
    def self.forced_enemy_action(e)
      return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0
      p=current_plan
      return nil unless p&&p[:enemies]
      c=p[:enemies][e.index]
      c ? make_action(e,c) : nil
    end

    def self.action_token(b)
      return "nil" unless b
      s=b.actor? ? "A" : "E"; a=b.action
      return s+b.index.to_s+":Guard" if a&&a.guard?
      if a&&a.skill?
        token=s+b.index.to_s+":M"+move_id(a.skill).to_s
        tag=a.instance_variable_get(:@cg_v241_injected_tag)
        token+=":CELEBRATE" if tag==:celebrate
        return token
      end
      s+b.index.to_s+":Other"
    rescue
      "?"
    end

    def self.record_execution(b)
      return unless active?
      @actual<<action_token(b)
      log("ACTION_EXEC #"+@actual.size.to_s+" "+(b ? b.name.to_s : "nil")+" token="+@actual[-1].to_s)
    end

    def self.apply_test_speeds
      sp=TEST_SPEEDS[current_round]||[]
      (test_allies+all_enemies).each_with_index do |b,i|
        b.instance_variable_set(:@cg_priority_test_speed_override_as,sp[i]) if b&&sp[i]!=nil
      end
    end

    def self.apply_round_slots(r)
      a=test_allies; e=all_enemies
      # All deterministic placement happens after Solo Trainer start reset.
      set_slot_quiet(a[0],:front,0)
      if r==1
        set_slot_quiet(a[1],:back,0)
        set_slot_quiet(a[2],:back,2)
      else
        set_slot_quiet(a[1],:front,1)
        set_slot_quiet(a[2],:front,2)
      end
      set_slot_quiet(a[3],:back,1)
      set_slot_quiet(e[0],:front,0)
      # v2.5.44j fixture correction: Round1 Ditto is a back-row melee user.
      # Spiritomb (the intended Ghost/Dark immunity target) must therefore be
      # in the enemy front row while any enemy front row is occupied; otherwise
      # sealed Grid Authority legally replaces target_index=2 with the first
      # reachable opponent (E0 Persian), which invalidates the Omnipotent test.
      if r==1
        set_slot_quiet(e[1],:back,2)
        set_slot_quiet(e[2],:front,2)
      else
        set_slot_quiet(e[1],:front,2)
        set_slot_quiet(e[2],:back,2)
      end
      set_slot_quiet(e[3],:front,1)
      set_slot_quiet(e[4],:back,1)
    end

    def self.seed_round1_movement
      a=test_allies
      reset_movement(a[1]); reset_movement(a[2])
      a[1].cg_set_battle_slot(:front,1,true) if a[1]
      a[2].cg_set_battle_slot(:front,2,true) if a[2]
      @r1_nomad_distance=movement_distance(a[1])
      @r1_runup_distance=movement_distance(a[2])
      @r1_nomad_base=a[1] ? a[1].cg_v2544as_atk_stat.to_i : 0
      @r1_nomad_after=a[1] ? a[1].cg_atk_stat.to_i : 0
      log("MOVEMENT_FIX nomad_distance="+@r1_nomad_distance.to_s+" runup_distance="+@r1_runup_distance.to_s+" nomad_atk="+@r1_nomad_base.to_s+"->"+@r1_nomad_after.to_s)
    rescue=>e
      log("MOVEMENT_FIX_ERROR "+e.class.to_s+":"+e.message.to_s)
    end

    def self.prepare_round_fixture
      a=test_allies; e=all_enemies; r=current_round
      restore_base_abilities
      reset_round_flags
      @passive_noted={}
      apply_round_slots(r)
      @forced_omni_proc=false

      if r==1
        # Bodyguard / Shield off so displacement and Omnipotent can be isolated.
        set_ability(e[1],0); set_ability(e[3],0)
        seed_round1_movement
        @forced_omni_proc=true
        if a[3]
          a[3].recover_all
          loss=[a[3].maxhp.to_i/3,40].max
          a[3].hp=[a[3].maxhp.to_i-loss,1].max
          @r1_omni_hp_before=a[3].hp.to_i
        end
        @r1_a0_slot=[a[0].cg_battle_row,a[0].cg_battle_column] if a[0]
        @r1_a1_slot=[a[1].cg_battle_row,a[1].cg_battle_column] if a[1]
        @r1_a2_slot=[a[2].cg_battle_row,a[2].cg_battle_column] if a[2]
        @r1_e2_hp_before=e[2].hp.to_i if e[2]
        begin
          oskill=$data_skills[master.skill_id_for_move(33)]
          okey=omni_attack_type_key(oskill)
          otypes=e[2]&&e[2].respond_to?(:cg_pokemon_types) ? e[2].cg_pokemon_types : []
          ochart=defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_chart_percent(okey,otypes).to_i : -1
          oaction=(a[3] ? make_action(a[3],ROUND_PLANS[0][:allies][3]) : nil)
          @r1_omni_grid_legal=(oaction&&e[2]&&oaction.respond_to?(:cg_target_legal?)) ? oaction.cg_target_legal?(e[2]) : false
          log("OMNI_FIXTURE user_ability="+(a[3] ? ability_id(a[3]).to_s : "nil")+
            " skill_id="+(oskill ? oskill.id.to_i.to_s : "nil")+
            " move="+(oskill ? move_id(oskill).to_s : "nil")+
            " base_damage="+(oskill&&oskill.respond_to?(:base_damage) ? oskill.base_damage.to_i.to_s : "nil")+
            " type="+okey.to_s+" target_types="+otypes.inspect+" chart="+ochart.to_s)
          log("OMNI_GRID_FIXTURE legal="+(@r1_omni_grid_legal==true).to_s+
            " user_slot="+(a[3] ? [a[3].cg_battle_row,a[3].cg_battle_column].inspect : "nil")+
            " target_index=2 target_slot="+(e[2] ? [e[2].cg_battle_row,e[2].cg_battle_column].inspect : "nil"))
        rescue=>oe
          log("OMNI_FIXTURE_ERROR "+oe.class.to_s+":"+oe.message.to_s)
        end
        log("ROUND1_FIX movement=true omni_proc=true")
      elsif r==2
        # Isolate Bodyguard / Shield. Displacement abilities disabled.
        set_ability(e[0],0); set_ability(e[2],0)
        @forced_omni_proc=false
        @r2_e1_hp_before=e[1].hp.to_i if e[1]
        @r2_e2_hp_before=e[2].hp.to_i if e[2]
        @r2_e4_hp_before=e[4].hp.to_i if e[4]
        log("ROUND2_FIX bodyguard=true shield=true")
      else
        # Isolate Celebrate extra action.
        set_ability(e[0],0); set_ability(e[1],0); set_ability(e[2],0); set_ability(e[3],0)
        @forced_omni_proc=false
        if e[0]
          e[0].recover_all
          e[0].hp=1
        end
        @r3_celebrate_before=records_for(ABILITY_CELEBRATE,:celebrate_queue).size
        log("ROUND3_FIX celebrate_target_hp=1")
      end
    end

    def self.prepare_round_actions
      prepare_round_fixture
      apply_test_speeds
      @actual=[]
      a=test_allies; p=current_plan
      return false unless p
      p[:allies].each_with_index do |cfg,i|
        next unless a[i]&&a[i].hp.to_i>0
        act=make_action(a[i],cfg)
        if a[i].respond_to?(:cg_round_actions)
          a[i].cg_round_actions.clear
          a[i].cg_round_actions.push(act)
        end
        a[i].cg_assign_action(act) if a[i].respond_to?(:cg_assign_action)
        a[i].instance_variable_set(:@action,act) unless a[i].respond_to?(:cg_assign_action)
      end
      log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s)
      true
    end

    def self.assert_order
      exp=EXPECTED_EXECUTION_TOKENS[current_round]||[]
      ok=@actual==exp
      @action_checks+=1 if ok
      assert_true("Round"+current_round.to_s+" execution order matches deterministic plan",ok,"expected="+exp.inspect+" actual="+@actual.inspect)
    end

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted=true
      assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil"))
      assert_true("Ability Batch AS defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability AS test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil"))
      assert_true("Ability AS ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability AS enemy count=5",all_enemies.size==5,"actual="+all_enemies.size.to_s)
    end

    def self.finish_round_assertions
      assert_order
      a=test_allies; e=all_enemies; r=current_round
      if r==1
        nrec=records_for(ABILITY_NOMAD,:nomad)[-1]||{}
        nok=!nrec.empty?&&@r1_nomad_distance.to_i==2&&nrec[:percent].to_i==140&&nrec[:after].to_i==[nrec[:before].to_i*140/100,1].max
        @movement_checks+=1 if nok
        assert_true("Nomad two-grid movement gives exact ATK +40%",nok,nrec.inspect)

        rrec=records_for(ABILITY_RUN_UP,:run_up)[-1]||{}
        rok=!rrec.empty?&&@r1_runup_distance.to_i==1&&rrec[:percent].to_i==120&&rrec[:after].to_i==[rrec[:before].to_i*120/100,1].max
        @movement_checks+=1 if rok
        assert_true("Run Up one-grid movement gives exact damage +20%",rok,rrec.inspect)

        trec=records_for(ABILITY_THRUST,:thrust)[-1]||{}
        tok=!trec.empty?&&a[0]&&a[0].cg_battle_row==:back
        @displacement_checks+=1 if tok
        assert_true("Thrust real damaging hit pushes front target to back row",tok,trec.inspect)

        drec=records_for(ABILITY_DISGUST,:disgust)[-1]||{}
        dok=!drec.empty?&&drec[:target_index].to_i==1&&drec[:swap_index].to_i==2
        @displacement_checks+=1 if dok
        assert_true("Disgust real damaging hit swaps target with adjacent ally",dok,drec.inspect)

        assert_true("Omnipotent immunity fixture target is Grid-legal",@r1_omni_grid_legal==true,
          "user_slot="+(a[3] ? [a[3].cg_battle_row,a[3].cg_battle_column].inspect : "nil")+
          " target_slot="+(e[2] ? [e[2].cg_battle_row,e[2].cg_battle_column].inspect : "nil"))

        otype=records_for(ABILITY_OMNIPOTENT,:omni_type_bypass)[-1]||{}
        ook=!otype.empty?&&e[2]&&e[2].hp.to_i<@r1_e2_hp_before.to_i
        @omni_checks+=1 if ook
        assert_true("Omnipotent damaging Normal Move bypasses Ghost 0% immunity",ook,otype.inspect+" hp="+@r1_e2_hp_before.to_s+"->"+(e[2] ? e[2].hp.to_i.to_s : "nil"))

        oe=records_for(ABILITY_OMNIPOTENT,:omni_evasion)[-1]||{}
        eok=!oe.empty?
        @protection_checks+=1 if eok; @omni_checks+=1 if eok
        assert_true("Omnipotent forced proc evades opposing damaging Move",eok,oe.inspect)

        oh=records_for(ABILITY_OMNIPOTENT,:omni_heal)[-1]||{}
        hok=!oh.empty?&&oh[:heal].to_i==[a[3].maxhp.to_i/OMNI_HEAL_DENOM,1].max
        @omni_checks+=1 if hok
        assert_true("Omnipotent Life Force component heals 1/8 at end-turn",hok,oh.inspect)
      elsif r==2
        brec=records_for(ABILITY_BODYGUARD,:bodyguard)[-1]||{}
        bok=!brec.empty?&&brec[:protected_index].to_i==2&&e[1]&&e[1].hp.to_i<@r2_e1_hp_before.to_i&&e[2]&&e[2].hp.to_i==@r2_e2_hp_before.to_i
        @protection_checks+=1 if bok
        assert_true("Bodyguard swaps in and receives ally-targeted damaging Move",bok,brec.inspect+" guard_hp="+@r2_e1_hp_before.to_s+"->"+(e[1] ? e[1].hp.to_i.to_s : "nil"))

        srec=records_for(ABILITY_SHIELD,:shield)[-1]||{}
        sok=!srec.empty?&&e[4]&&e[4].hp.to_i==@r2_e4_hp_before.to_i
        @protection_checks+=1 if sok
        assert_true("Shield front holder blocks damaging Move to same-column rear ally",sok,srec.inspect+" rear_hp="+@r2_e4_hp_before.to_s+"->"+(e[4] ? e[4].hp.to_i.to_s : "nil"))

        nomad_off=records_for(ABILITY_NOMAD,:nomad).select{|x|x[:distance].to_i>0}.size<=1
        runup_off=records_for(ABILITY_RUN_UP,:run_up).size<=1
        if nomad_off&&runup_off; @movement_checks+=2; end
        assert_true("Nomad / Run Up stay off without movement",nomad_off&&runup_off)
      else
        crec=records_for(ABILITY_CELEBRATE,:celebrate_queue)
        immediate=false
        if @actual&&@actual.size>=2
          0.upto(@actual.size-2) do |i|
            if @actual[i]=="A0:M55"&&@actual[i+1]=="A0:M55:CELEBRATE"
              immediate=true; break
            end
          end
        end
        cok=crec.size>@r3_celebrate_before.to_i&&immediate
        @celebrate_checks+=2 if cok
        assert_true("Celebrate real KO injects one immediate extra ActionEntry",cok,"record="+(crec[-1]||{}).inspect+" actual="+@actual.inspect)

        once=@actual.select{|x|x=="A0:M55:CELEBRATE"}.size==1
        @scope_checks+=1 if once
        assert_true("Celebrate is capped to one extra action per round",once)
      end
      log("ROUND "+r.to_s+" END")
      @round_index=@round_index.to_i+1
    end

    def self.cleanup_test_overrides
      (test_allies+all_enemies).each{|b|clear_test_runtime(b)}
      @forced_omni_proc=nil
    rescue
    end

    def self.cleanup_output_logs
      keep=["CG_AutoRegression_LATEST.log","PMD_BattleInitTrace.log"]
      Dir.glob(File.join(project_root,"*.log")).each do |p|
        next if keep.include?(File.basename(p))
        begin; File.delete(p); rescue; end
      end
      true
    rescue
      false
    end

    def self.finish_suite
      HANDLED_ABILITY_IDS.each do |aid|
        ok=@ability_trigger_counts[aid].to_i>0
        assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)
      end
      log("------------------------------------------------------------")
      result=@failures.empty? ? "PASS" : "FAIL"
      log("RESULT="+result)
      passed=HANDLED_ABILITY_IDS.select{|x|@ability_trigger_counts[x].to_i>0}.size
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+
          " ability_as="+passed.to_s+"/8 movement_checks="+@movement_checks.to_s+
          " displacement_checks="+@displacement_checks.to_s+
          " protection_checks="+@protection_checks.to_s+
          " omni_checks="+@omni_checks.to_s+
          " celebrate_checks="+@celebrate_checks.to_s+
          " scope_checks="+@scope_checks.to_s+
          " action_checks="+@action_checks.to_s+" pending=13")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}
      cleanup_test_overrides
      @active=false
      cleanup_output_logs
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end

    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]
      @boot_asserted=false; @movement_checks=0; @displacement_checks=0
      @protection_checks=0; @omni_checks=0; @celebrate_checks=0
      @scope_checks=0; @action_checks=0; @passive_noted={}; @redirecting=false
    end

    def self.reset_log
      cleanup_output_logs
      h="CG POKEMON ABILITY AS CONQUEST GRID + PROTECTION + MOMENTUM AUTO REGRESSION v2.5.44j\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; grid movement + protection redirection + KO extra action authority\r\n"+
        "BASELINE=v2.5.43a Ability Batch AR RPG Maker VX real-machine PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AR_PASS=352 BATCH_AS=8 PENDING=13\r\n"+
        "BUILD=AS_v2.5.44j_OMNI_GRID_LEGAL_TARGET_RETEST\r\n"+
        "LEAN_LOGS=send CG_AutoRegression_LATEST.log + PMD_BattleInitTrace.log\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue
    end

    def self.start_auto_test
      return false if active?
      reset_log; reset_suite; prepare_test_party; make_test_troop
      @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AS_v2.5.44j") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s)
      ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil
      @failures<<"AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s
      log(@failures[-1]); @active=false; false
    end
  end
end

ALBERT_CG::ABILITY_AS_V2544.register_handlers if defined?(ALBERT_CG::ABILITY_AS_V2544)

#==============================================================================
# ■ Formal bridges
#==============================================================================
class Game_Battler
  # Track formal battlefield movement distance for Nomad / Run Up.
  alias cg_v2544as_set_battle_slot cg_set_battle_slot
  def cg_set_battle_slot(row,column,animate=true)
    old_row=respond_to?(:cg_battle_row) ? cg_battle_row : nil
    old_col=respond_to?(:cg_battle_column) ? cg_battle_column : nil
    result=cg_v2544as_set_battle_slot(row,column,animate)
    if @cg_as_ignore_move_track!=true && old_row!=nil && old_col!=nil
      dr=(old_row==row ? 0 : 1)
      dc=(old_col.to_i-column.to_i).abs
      dist=dr+dc
      @cg_as_distance_moved=@cg_as_distance_moved.to_i+dist if dist>0
    end
    result
  rescue
    cg_v2544as_set_battle_slot(row,column,animate)
  end

  # v2.5.44a regression fixture: actually consume TEST_SPEEDS.
  alias cg_v2544a_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AS_V2544) && ALBERT_CG::ABILITY_AS_V2544.active? && @cg_priority_test_speed_override_as!=nil
      return @cg_priority_test_speed_override_as.to_i
    end
    cg_v2544a_priority_base_speed
  rescue
    cg_v2544a_priority_base_speed
  end

  alias cg_v2544as_atk_stat cg_atk_stat
  def cg_atk_stat
    base=cg_v2544as_atk_stat
    return ALBERT_CG::ABILITY_AS_V2544.apply_nomad_atk(self,base) if defined?(ALBERT_CG::ABILITY_AS_V2544)
    base
  rescue
    cg_v2544as_atk_stat
  end

  # v2.5.44j retains the 44g Omnipotent scope/fallback runtime unchanged;
  # only the F11 Round1 target fixture is corrected to obey Grid legality.
  # The force path is active only inside a verified Scene Action immunity scope.
  alias cg_v2544g_type_rate cg_pokemon_type_rate_percent
  def cg_pokemon_type_rate_percent(attack_type)
    v=cg_v2544g_type_rate(attack_type)
    if defined?(ALBERT_CG::ABILITY_AS_V2544) && @cg_as_omni_force_neutral_rate==true && v.to_i==0
      comp=ALBERT_CG::ABILITY_AS_V2544.omni_manual_rate_components(self,attack_type)
      forced=comp&&comp[:manual].to_i>0 ? comp[:manual].to_i : 100
      @cg_as_omni_rate_forced={:before=>v.to_i,:after=>forced,:components=>comp}
      ALBERT_CG::ABILITY_AS_V2544.log("OMNI_TYPE_RATE route=forced_neutral attack="+attack_type.to_s+
        " before="+v.to_i.to_s+" after="+forced.to_s+" components="+(comp||{}).inspect) if ALBERT_CG::ABILITY_AS_V2544.active?
      return forced
    end
    if defined?(ALBERT_CG::ABILITY_AS_V2544) && @cg_as_omni_scope_user!=nil && ALBERT_CG::ABILITY_AS_V2544.active?
      ALBERT_CG::ABILITY_AS_V2544.log("OMNI_TYPE_RATE route=normal_query attack="+attack_type.to_s+
        " rate="+v.to_i.to_s+" types="+(respond_to?(:cg_pokemon_types) ? cg_pokemon_types.inspect : "[]"))
    end
    v
  rescue=>e
    ALBERT_CG::ABILITY_AS_V2544.log("OMNI_TYPE_RATE_ERROR "+e.class.to_s+":"+e.message.to_s) if defined?(ALBERT_CG::ABILITY_AS_V2544)&&ALBERT_CG::ABILITY_AS_V2544.active?
    cg_v2544g_type_rate(attack_type)
  end

  alias cg_v2544g_make_obj_damage_value make_obj_damage_value
  def make_obj_damage_value(user,obj)
    trace=defined?(ALBERT_CG::ABILITY_AS_V2544)&&ALBERT_CG::ABILITY_AS_V2544.omni_trace_hit?(self,user,obj)
    if trace&&ALBERT_CG::ABILITY_AS_V2544.active?
      ALBERT_CG::ABILITY_AS_V2544.log("OMNI_DAMAGE_TRUNK_ENTER user="+user.name.to_s+
        " target="+name.to_s+" move="+ALBERT_CG::ABILITY_AS_V2544.move_id(obj).to_s+
        " types="+(respond_to?(:cg_pokemon_types) ? cg_pokemon_types.inspect : "[]"))
    end
    result=cg_v2544g_make_obj_damage_value(user,obj)
    if trace&&ALBERT_CG::ABILITY_AS_V2544.active?
      ALBERT_CG::ABILITY_AS_V2544.log("OMNI_DAMAGE_TRUNK_EXIT hp_damage="+@hp_damage.to_i.to_s+
        " breakdown="+(@cg_last_damage_breakdown||{}).inspect)
    end
    result
  end

  alias cg_v2544as_skill_effect skill_effect
  def skill_effect(user,skill)
    if defined?(ALBERT_CG::ABILITY_AS_V2544) && user&&skill&&ALBERT_CG::ABILITY_AS_V2544.damaging_move?(skill) &&
       !ALBERT_CG::ABILITY_AS_V2544.redirecting?
      guard=ALBERT_CG::ABILITY_AS_V2544.intercept_bodyguard(self,user,skill)
      if guard
        clear_action_results
        ALBERT_CG::ABILITY_AS_V2544.begin_redirect
        begin
          guard.skill_effect(user,skill)
        ensure
          ALBERT_CG::ABILITY_AS_V2544.end_redirect
        end
        return
      end
      shield=ALBERT_CG::ABILITY_AS_V2544.intercept_shield(self,user,skill)
      if shield
        clear_action_results
        @missed=false; @evaded=true; @skipped=false; @hp_damage=0
        return
      end
    end

    trace=defined?(ALBERT_CG::ABILITY_AS_V2544)&&ALBERT_CG::ABILITY_AS_V2544.omni_trace_hit?(self,user,skill)
    before_hp=hp.to_i
    if trace&&ALBERT_CG::ABILITY_AS_V2544.active?
      states_info=(states||[]).collect{|st| [st.id,st.name,(st.respond_to?(:extension) ? st.extension : [])] rescue [st.id,st.name]}
      ALBERT_CG::ABILITY_AS_V2544.log("OMNI_SKILL_ENTER user="+user.name.to_s+
        " target="+name.to_s+" move="+ALBERT_CG::ABILITY_AS_V2544.move_id(skill).to_s+
        " hp="+before_hp.to_s+" types="+(respond_to?(:cg_pokemon_types) ? cg_pokemon_types.inspect : "[]")+
        " states="+states_info.inspect)
    end
    result=cg_v2544as_skill_effect(user,skill)
    if trace&&ALBERT_CG::ABILITY_AS_V2544.active?
      ALBERT_CG::ABILITY_AS_V2544.log("OMNI_SKILL_EXIT hp="+before_hp.to_s+"->"+hp.to_i.to_s+
        " hp_damage="+@hp_damage.to_i.to_s+" missed="+(@missed==true).to_s+
        " evaded="+(@evaded==true).to_s+" skipped="+(@skipped==true).to_s+
        " breakdown="+(@cg_last_damage_breakdown||{}).inspect)
    end
    result
  end

  alias cg_v2544as_execute_damage execute_damage
  def execute_damage(user)
    skill=defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.current_skill(user) : nil
    if defined?(ALBERT_CG::ABILITY_AS_V2544) && user&&skill&&@hp_damage.to_i>0
      @hp_damage=ALBERT_CG::ABILITY_AS_V2544.apply_run_up_damage(user,self,skill,@hp_damage.to_i)
    end
    before=hp.to_i
    result=cg_v2544as_execute_damage(user)
    done=[before-hp.to_i,0].max
    if defined?(ALBERT_CG::ABILITY_AS_V2544) && user&&skill&&done>0
      ALBERT_CG::ABILITY_AS_V2544.apply_thrust_or_disgust(user,self,skill,done)
    end
    result
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2544as_start start
  def start
    ALBERT_CG::ABILITY_AS_V2544.pre_scene_start if defined?(ALBERT_CG::ABILITY_AS_V2544)&&ALBERT_CG::ABILITY_AS_V2544.active?
    cg_v2544as_start
  end

  alias cg_v2544as_execute_action execute_action
  def execute_action
    b=@active_battler
    ALBERT_CG::ABILITY_AS_V2544.record_execution(b) if defined?(ALBERT_CG::ABILITY_AS_V2544)&&ALBERT_CG::ABILITY_AS_V2544.active?
    skill=(b&&b.action&&b.action.skill?) ? b.action.skill : nil
    omni_scope=[]
    if defined?(ALBERT_CG::ABILITY_AS_V2544)&&b&&skill
      omni_scope=ALBERT_CG::ABILITY_AS_V2544.begin_omni_scene_scope(b,skill)
    end
    begin
      result=cg_v2544as_execute_action
    ensure
      if defined?(ALBERT_CG::ABILITY_AS_V2544)&&b&&skill
        ALBERT_CG::ABILITY_AS_V2544.end_omni_scene_scope(omni_scope,b,skill)
      end
    end
    ALBERT_CG::ABILITY_AS_V2544.queue_celebrate(self,b) if defined?(ALBERT_CG::ABILITY_AS_V2544)&&b
    result
  end

  # Hit-frame fallback runs immediately before Tankentai damage popup.
  alias cg_v2544g_pop_damage pop_damage
  def pop_damage(target,obj,action)
    if defined?(ALBERT_CG::ABILITY_AS_V2544) && @active_battler&&obj &&
       ALBERT_CG::ABILITY_AS_V2544.omni_trace_hit?(target,@active_battler,obj)
      if ALBERT_CG::ABILITY_AS_V2544.active?
        ALBERT_CG::ABILITY_AS_V2544.log("OMNI_POP_CHECK invalid="+(@invalid==true).to_s+
          " reflection="+(@reflection==true).to_s+" hp="+target.hp.to_i.to_s+
          " hp_damage="+target.instance_variable_get(:@hp_damage).to_i.to_s)
      end
      ALBERT_CG::ABILITY_AS_V2544.omni_hitframe_replay(target,@active_battler,obj)
    end
    cg_v2544g_pop_damage(target,obj,action)
  end

  if method_defined?(:physics_reflection)
    alias cg_v2544g_physics_reflection physics_reflection
    def physics_reflection(target,obj)
      trace=defined?(ALBERT_CG::ABILITY_AS_V2544)&&@active_battler&&obj&&
        ALBERT_CG::ABILITY_AS_V2544.omni_trace_hit?(target,@active_battler,obj)
      if trace&&ALBERT_CG::ABILITY_AS_V2544.active?
        ALBERT_CG::ABILITY_AS_V2544.log("OMNI_PHYSICS_REFLECT_BEFORE invalid="+(@invalid==true).to_s+
          " reflection="+(@reflection==true).to_s)
      end
      result=cg_v2544g_physics_reflection(target,obj)
      if trace&&ALBERT_CG::ABILITY_AS_V2544.active?
        ALBERT_CG::ABILITY_AS_V2544.log("OMNI_PHYSICS_REFLECT_AFTER invalid="+(@invalid==true).to_s+
          " reflection="+(@reflection==true).to_s)
      end
      result
    end
  end

  alias cg_v2544as_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AS_V2544)&&ALBERT_CG::ABILITY_AS_V2544.active?
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_AS_V2544.finish_round_assertions
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      else
        ALBERT_CG::ABILITY_AS_V2544.finish_round_assertions
      end
    end
    result=cg_v2544as_turn_end
    unless defined?(ALBERT_CG::ABILITY_AS_V2544)&&ALBERT_CG::ABILITY_AS_V2544.active?
      list=defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.active_battlers : []
      list.each{|b|ALBERT_CG::ABILITY_AS_V2544.reset_movement(b) if defined?(ALBERT_CG::ABILITY_AS_V2544)}
    end
    result
  end

  alias cg_v2544as_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AS_V2544)&&ALBERT_CG::ABILITY_AS_V2544.active?
      return cg_v2544as_start_party_command
    end
    cg_v2544as_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_AS_V2544.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AS_V2544.finished?
      ALBERT_CG::ABILITY_AS_V2544.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_AS_V2544.prepare_round_actions
    start_main
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2544as_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AS_V2544)&&ALBERT_CG::ABILITY_AS_V2544.active?
      a=ALBERT_CG::ABILITY_AS_V2544.forced_enemy_action(self)
      if a
        cg_assign_action(a) if respond_to?(:cg_assign_action)
        @action=a unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v2544as_enemy_make_action
  end
end

module ALBERT_CG
  class << self
    alias cg_v2544as_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2544as_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_AS_V2544)&&ALBERT_CG::ABILITY_AS_V2544.active?
        ALBERT_CG::ABILITY_AS_V2544::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AS_V2544.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if h
          h.change_level(ALBERT_CG::ABILITY_AS_V2544::TEST_LEVEL,false); h.recover_all
          h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages)
          ALBERT_CG::ABILITY_AS_V2544.clear_test_runtime(h)
          ALBERT_CG::ABILITY_AS_V2544.set_ability(h,ALBERT_CG::ABILITY_AS_V2544::ABILITY_CELEBRATE)
        end
      end
      r
    end
  end
end

if defined?(ALBERT_CG::ABILITY_AR_V2543)
  module ALBERT_CG
    module ABILITY_AR_V2543
      def self.f11_trigger?; false; end
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2544as_scene_map_update update
  def update
    cg_v2544as_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_AS_V2544)
    ALBERT_CG::ABILITY_AS_V2544.start_auto_test if ALBERT_CG::ABILITY_AS_V2544.f11_trigger?
  end
end
