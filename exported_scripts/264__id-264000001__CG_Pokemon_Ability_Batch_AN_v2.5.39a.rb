# RMVX_SCRIPT_INDEX: 264
# RMVX_SCRIPT_ID: 264000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AN v2.5.39a
# RMVX_SOURCE_SHA256: 3ed939b896264dec4395edaf1668a06eb04c391c4c597d09c5dc46d988e42621

#==============================================================================
# ■ CG Pokemon Ability Batch AN v2.5.39a - Conquest Support + Recovery TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.38 Ability Batch AM RPG Maker VX 實機 PASS 為唯一正式基底，收斂
#  Pokémon Conquest 的低血量恢復、環境恢復、隊友支援、Wait/Guard 回復、狀態治療、
#  鄰近追加傷害與吸血能力。沿用既有 Ability Core :end_turn、Status、Field、
#  Scene_Battle Action lifecycle 與 after-hit damage evidence，不建立第二套 HP/狀態/回合系統。
#
# 【本批 Ability】
#  10015 Spirit：HP <= 1/3 時回復並 ATK +1 stage。
#  10016 Warm Blanket：Conquest magma tile 每回合回復 1/8 MaxHP。
#  10020 Hot Blooded：Conquest magma/soil/sand tile 每回合回復 1/8 MaxHP。
#  10021 Medic：附近隊友每回合回復 1/8 MaxHP。
#  10023 Lunchbox：選擇 Wait 後回復 1/8 MaxHP。
#  10024 Nurse：可能治療附近隊友的主要異常狀態。
#  10025 Melee：附近敵人受到傷害時，追加該敵 MaxHP 1/16 傷害。
#  10026 Sponge：附近敵人每回合各失去 MaxHP 1/16，holder 回復實際總傷害一半。
#
# 【CG 專案適配】
#  1. 本專案不是 Conquest tile-grid：
#       Warm Blanket -> 有效 Sun / Harsh Sun 視為 magma / heat environment。
#       Hot Blooded  -> 有效 Sun / Harsh Sun 或 Sandstorm 視為 magma/soil/sand environment。
#  2. 本專案沒有鄰接格：Medic/Nurse 的「附近隊友」=同側 active battlers；
#     Melee/Sponge 的「附近敵人」=對側 active battlers。
#  3. 本專案沒有 Conquest Wait 指令；Lunchbox 以正式 Guard action 作 Wait/Defend 對應。
#     Scene_Battle#execute_action 記錄該回合真實 Guard，不在 end-turn 猜 action 狀態。
#  4. Spirit 原資料僅寫「restore a portion」；CG 採 1/3 MaxHP 作明確專案適配，
#     ATK +1 走既有 stat-stage Authority。條件可於後續再次跌至 <=1/3 時再觸發。
#  5. Nurse 原作觸發機率未有穩定固定百分比；沿用 AL Conquest 隨機反應慣例 30%。
#     F11 用 forced proc / no-proc，不讓 RNG 決定 Regression 結果。
#  6. Melee / Sponge 直接額外 HP loss 不繞過正式 KO Authority：額外傷害最低保留 1 HP。
#     這是 CG safety adaptation，避免非 Move damage 產生沒有 :after_ko 的幽靈 KO。
#  7. Ability ID 一律經 ABILITY_V250.ability_id；Neutralizing Gas 等 suppression bridge
#     仍由既有正式 Authority 決定，不在本批另造 Ability lookup。
#
# 【F11】
#  Troop 742，三回合 Actual Scene_Battle：
#   R1 Heat + Support + Guard：Spirit 低血回復/ATK+1；Warm/Hot 各回 1/8；Medic 回隊友；
#      Lunchbox 真實 Guard 後回 1/8；Nurse forced proc 治療 Poison；Melee 對真實受傷敵人
#      追加 1/16；Sponge 脈衝全體敵人並回復一半。
#   R2 Sand + Team Melee：Warm 不回、Hot 仍回；Lunchbox 非 Guard 不回；Nurse forced false
#      不治療；由非 Melee 隊友造成傷害，Melee aura 仍追加 1/16；Sponge 持續。
#   R3 Clear Scope：Warm/Hot 不回；Spirit 高於 1/3 不再觸發；Medic 對全滿隊伍不回；
#      Nurse 無異常目標不觸發；status/field/action scope 全部退出，Sponge 仍維持固定 pulse。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAN"] = "2.5.39a"

module ALBERT_CG
  module ABILITY_AN_V2539
    VERSION = "2.5.39a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 742
    VK_F11 = 0x7A

    ABILITY_SPIRIT       = 10015
    ABILITY_WARM_BLANKET = 10016
    ABILITY_HOT_BLOODED  = 10020
    ABILITY_MEDIC        = 10021
    ABILITY_LUNCHBOX     = 10023
    ABILITY_NURSE        = 10024
    ABILITY_MELEE        = 10025
    ABILITY_SPONGE       = 10026
    HANDLED_ABILITY_IDS = [10015,10016,10020,10021,10023,10024,10025,10026]

    RECOVERY_DENOM = 8
    SPIRIT_HEAL_DENOM = 3
    MELEE_DAMAGE_DENOM = 16
    SPONGE_DAMAGE_DENOM = 16
    NURSE_PROC_CHANCE = 30

    TEST_ALLIES = [
      {:dex=>143,:level=>40,:ability=>ABILITY_WARM_BLANKET,:moves=>[150,150,150]},
      {:dex=>65, :level=>40,:ability=>ABILITY_MEDIC,       :moves=>[150,55,150]},
      {:dex=>18, :level=>40,:ability=>ABILITY_MELEE,       :moves=>[55,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>45,:ability=>ABILITY_HOT_BLOODED,:moves=>[150,150,150]},
      {:dex=>383,:level=>45,:ability=>ABILITY_LUNCHBOX,   :moves=>[150,150,150]},
      {:dex=>384,:level=>45,:ability=>ABILITY_NURSE,      :moves=>[150,150,150]},
      {:dex=>92, :level=>45,:ability=>ABILITY_SPONGE,     :moves=>[150,150,150]},
    ]

    ROUND_PLANS = [
      {:name=>"HEAT_SUPPORT_GUARD_MELEE_SPONGE",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>55,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},
         1=>{:kind=>:guard},
         2=>{:kind=>:move,:move_id=>150,:target=>1},
         3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"SAND_TEAM_MELEE_NURSE_FALSE",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>55,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},
         1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},
         3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"CLEAR_SCOPE_SUPPORT_IDLE",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},
         1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},
         3=>{:kind=>:move,:move_id=>150,:target=>1}}},
    ]
    # Formal Action Priority Core: Guard = +4, so E1 Guard must execute before all Priority 0 moves.
    EXPECTED_EXECUTION_TOKENS = {
      1=>["E1:Guard","A0:M150","A1:M150","A2:M150","A3:M55","E0:M150","E2:M150","E3:M150"],
      2=>["A0:M150","A1:M55","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
      3=>["A0:M150","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
    }
    TEST_SPEEDS = {
      1=>[900,850,800,750,600,550,500,450],
      2=>[900,850,800,750,600,550,500,450],
      3=>[900,850,800,750,600,550,500,450],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.move_effect; defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT : nil; end
    def self.field; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233 : nil; end
    def self.field_state; field && field.respond_to?(:state) ? field.state : nil; rescue; nil; end
    def self.active?; @active == true; end
    def self.current_round; @round_index.to_i + 1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i >= ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AN_AutoTest_v2_5_39a.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.move_id(skill); move_effect&&skill ? move_effect.move_id(skill).to_i : 0; rescue; 0; end
    def self.ability_id(b); core&&b ? core.ability_id(b).to_i : 0; rescue; 0; end
    def self.turn_serial; defined?(ALBERT_CG::ABILITY_AE_V2530) ? ALBERT_CG::ABILITY_AE_V2530.turn_serial.to_i : @fallback_turn_serial.to_i; rescue; @fallback_turn_serial.to_i; end
    def self.weather_suppressed?; defined?(ALBERT_CG::ABILITY_AG_V2532)&&ALBERT_CG::ABILITY_AG_V2532.weather_suppressed?; rescue; false; end
    def self.primary_status?(b); move_effect&&b ? move_effect.has_primary_status?(b) : false; rescue; false; end
    def self.poison_state; move_effect ? move_effect::STATE_POISON : 31; end

    def self.assert_true(label,condition,detail=nil)
      if condition; log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else; text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text); end
      condition
    end
    def self.note_local(aid,battler,kind,data=nil)
      rec={:ability=>aid.to_i,:kind=>kind}; (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill,:action].include?(k)}
      if active?
        @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1
        @records[aid.to_i]=[] if @records[aid.to_i]==nil; @records[aid.to_i].push(rec)
        log("ABILITY_AN_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect)
      end
      rec
    rescue; nil; end
    def self.records_for(aid,kind=nil); a=@records[aid.to_i]||[]; return a if kind==nil; a.select{|x|x[:kind].to_sym==kind.to_sym}; rescue; []; end

    def self.active_members(holder)
      return [] if holder==nil; unit=holder.actor? ? $game_party : $game_troop; return [] if unit==nil
      unit.members.select{|b|b!=nil&&!b.hidden&&b.hp.to_i>0}
    rescue; []; end
    def self.opponents_of(holder)
      return [] if holder==nil; unit=holder.actor? ? $game_troop : $game_party; return [] if unit==nil
      unit.members.select{|b|b!=nil&&!b.hidden&&b.hp.to_i>0}
    rescue; []; end
    def self.effective_weather
      st=field_state; return nil if st==nil||st.weather_turns.to_i<=0||weather_suppressed?; st.weather
    rescue; nil; end
    def self.heal_amount(holder,amount,aid,kind,extra=nil)
      return 0 if holder==nil||holder.hp.to_i<=0||holder.hp.to_i>=holder.maxhp.to_i
      before=holder.hp.to_i; holder.hp=[before+amount.to_i,holder.maxhp.to_i].min; actual=holder.hp.to_i-before
      data={:hp_before=>before,:hp_after=>holder.hp.to_i,:heal=>actual}; (extra||{}).each{|k,v|data[k]=v}
      note_local(aid,holder,kind,data) if actual>0; actual
    rescue; 0; end
    def self.heal_eighth(holder,aid,kind,extra=nil); heal_amount(holder,[holder.maxhp.to_i/RECOVERY_DENOM,1].max,aid,kind,extra); rescue; 0; end

    def self.change_stage(source,target,key,amount)
      return 0 if target==nil||!target.respond_to?(:cg_change_stat_stage)
      auth=defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) ? ALBERT_CG::ABILITY_STAT_GUARD_V256 : nil
      return auth.with_stage_source(source,:ability,false){target.cg_change_stat_stage(key,amount).to_i} if auth&&auth.respond_to?(:with_stage_source)
      target.cg_change_stat_stage(key,amount).to_i
    rescue; 0; end

    def self.proc_success?(kind)
      if active?&&@forced_proc!=nil&&@forced_proc.has_key?(kind.to_sym); return @forced_proc[kind.to_sym]==true; end
      rand(100)<NURSE_PROC_CHANCE
    rescue; false; end

    #--------------------------------------------------------------------------
    # Formal Ability handlers
    #--------------------------------------------------------------------------
    def self.apply_spirit(holder,ctx)
      return false if holder==nil||holder.hp.to_i<=0||holder.hp.to_i*3>holder.maxhp.to_i
      before_hp=holder.hp.to_i; before_atk=holder.respond_to?(:cg_stat_stage) ? holder.cg_stat_stage(:atk).to_i : 0
      heal=[holder.maxhp.to_i/SPIRIT_HEAL_DENOM,1].max; holder.hp=[before_hp+heal,holder.maxhp.to_i].min
      delta=change_stage(holder,holder,:atk,1); after_atk=holder.respond_to?(:cg_stat_stage) ? holder.cg_stat_stage(:atk).to_i : before_atk
      note_local(ABILITY_SPIRIT,holder,:spirit,{:hp_before=>before_hp,:hp_after=>holder.hp.to_i,:heal=>holder.hp.to_i-before_hp,:atk_before=>before_atk,:atk_after=>after_atk,:atk_delta=>delta})
      true
    rescue; false; end
    def self.apply_warm_blanket(holder,ctx)
      w=effective_weather; return false unless w==:sun||w==:harsh_sun
      heal_eighth(holder,ABILITY_WARM_BLANKET,:warm_blanket,{:weather=>w})>0
    rescue; false; end
    def self.apply_hot_blooded(holder,ctx)
      w=effective_weather; return false unless w==:sun||w==:harsh_sun||w==:sandstorm
      heal_eighth(holder,ABILITY_HOT_BLOODED,:hot_blooded,{:weather=>w})>0
    rescue; false; end
    def self.apply_medic(holder,ctx)
      return false if holder==nil; healed=[]
      active_members(holder).each do |b|
        next if b.equal?(holder)||b.hp.to_i>=b.maxhp.to_i
        amount=[b.maxhp.to_i/RECOVERY_DENOM,1].max; before=b.hp.to_i; b.hp=[before+amount,b.maxhp.to_i].min; actual=b.hp.to_i-before
        healed << [b.index.to_i,actual] if actual>0
      end
      if !healed.empty?; note_local(ABILITY_MEDIC,holder,:medic,{:targets=>healed.inspect,:total_heal=>healed.inject(0){|s,x|s+x[1].to_i}}); return true; end
      false
    rescue; false; end
    def self.waited_this_turn?(holder)
      holder!=nil&&holder.instance_variable_get(:@cg_v2539an_wait_turn_serial).to_i==turn_serial.to_i
    rescue; false; end
    def self.apply_lunchbox(holder,ctx)
      return false unless waited_this_turn?(holder)
      heal_eighth(holder,ABILITY_LUNCHBOX,:lunchbox,{:turn_serial=>turn_serial})>0
    rescue; false; end
    def self.cure_primary_status(target)
      return 0 if target==nil
      if target.respond_to?(:cg_v231_cure_primary_statuses); return target.cg_v231_cure_primary_statuses.to_i; end
      ids=move_effect ? move_effect::PRIMARY_STATES : [31,37,39,44,43]; n=0; ids.each{|sid|if target.state?(sid);target.remove_state(sid);n+=1;end}; n
    rescue; 0; end
    def self.apply_nurse(holder,ctx)
      return false if holder==nil
      target=active_members(holder).find{|b|!b.equal?(holder)&&primary_status?(b)}; return false if target==nil||!proc_success?(:nurse)
      before=move_effect ? move_effect::PRIMARY_STATES.select{|sid|target.state?(sid)} : []
      removed=cure_primary_status(target); return false if removed<=0
      note_local(ABILITY_NURSE,holder,:nurse,{:target_index=>target.index.to_i,:removed=>removed,:states_before=>before.inspect})
      true
    rescue; false; end

    # Melee is a team aura; Ability Core :after_hit dispatches only to target's own Ability.
    # A thin post-execute_damage bridge therefore scans active holders on the attacker's side.
    def self.melee_after_direct_damage(user,target,damage_done,skill)
      return false if user==nil||target==nil||damage_done.to_i<=0||target.hp.to_i<=1||user.actor? == target.actor?
      holders=active_members(user).select{|b|ability_id(b)==ABILITY_MELEE}; any=false
      holders.each do |holder|
        loss=[target.maxhp.to_i/MELEE_DAMAGE_DENOM,1].max; before=target.hp.to_i; target.hp=[before-loss,1].max; actual=before-target.hp.to_i; next if actual<=0
        note_local(ABILITY_MELEE,holder,:melee,{:source_index=>user.index.to_i,:target_index=>target.index.to_i,:move_id=>move_id(skill),:hp_before=>before,:hp_after=>target.hp.to_i,:loss=>actual,:direct_damage=>damage_done.to_i}); any=true
      end
      any
    rescue; false; end
    def self.apply_sponge(holder,ctx)
      return false if holder==nil||holder.hp.to_i<=0; hits=[]; total=0
      opponents_of(holder).each do |b|
        next if b.hp.to_i<=1
        loss=[b.maxhp.to_i/SPONGE_DAMAGE_DENOM,1].max; before=b.hp.to_i; b.hp=[before-loss,1].max; actual=before-b.hp.to_i; next if actual<=0
        hits << [b.index.to_i,actual]; total+=actual
      end
      return false if total<=0
      before_hp=holder.hp.to_i; heal=total/2; holder.hp=[before_hp+heal,holder.maxhp.to_i].min; actual_heal=holder.hp.to_i-before_hp
      note_local(ABILITY_SPONGE,holder,:sponge,{:targets=>hits.inspect,:total_damage=>total,:hp_before=>before_hp,:hp_after=>holder.hp.to_i,:heal=>actual_heal})
      true
    rescue; false; end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_SPIRIT,:end_turn,self,:apply_spirit)
      core.register(ABILITY_WARM_BLANKET,:end_turn,self,:apply_warm_blanket)
      core.register(ABILITY_HOT_BLOODED,:end_turn,self,:apply_hot_blooded)
      core.register(ABILITY_MEDIC,:end_turn,self,:apply_medic)
      core.register(ABILITY_LUNCHBOX,:end_turn,self,:apply_lunchbox)
      core.register(ABILITY_NURSE,:end_turn,self,:apply_nurse)
      core.register(ABILITY_SPONGE,:end_turn,self,:apply_sponge)
      true
    end

    #--------------------------------------------------------------------------
    # Battle runtime / test harness
    #--------------------------------------------------------------------------
    def self.reset_battle_runtime
      @battle_serial=@battle_serial.to_i+1; @fallback_turn_serial=1
      true
    rescue; false; end
    def self.note_action_start(b)
      return if b==nil||!b.respond_to?(:action); a=b.action
      b.instance_variable_set(:@cg_v2539an_wait_turn_serial,turn_serial.to_i) if a&&a.guard?
    rescue; end
    def self.clear_runtime(b)
      return if b==nil; b.instance_variable_set(:@cg_priority_test_speed_override_an,nil); b.instance_variable_set(:@cg_v2539an_wait_turn_serial,nil)
    end
    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); clear_runtime(a)
    end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end
    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}; ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true); $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each{|c|configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if h
        h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); clear_runtime(h)
        h.instance_variable_set(:@cg_master_ability_id,ABILITY_SPIRIT)
        mids=[150,55]; sids=mids.collect{|m|master.skill_id_for_move(m)}; h.instance_variable_set(:@cg_equipped_skill_ids,sids); h.instance_variable_set(:@cg_skill_slot_ids,sids); h.instance_variable_set(:@skills,sids)
      end
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0]]
      ms=[]; TEST_ENEMIES.each_with_index{|c,i|configure_enemy(c); ms.push(ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]))}
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AN v2.5.39a AutoRegression",ms)
    end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); else; a.clear; end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c); end
    def self.action_token(b)
      return "nil" if b==nil; side=b.actor? ? "A" : "E"; idx=b.index.to_i; a=b.action
      return side+idx.to_s+":Guard" if a&&a.guard?; return side+idx.to_s+":M"+move_id(a.skill).to_s if a&&a.skill?; side+idx.to_s+":Other"
    rescue; "?"; end
    def self.record_execution(b); @actual.push(action_token(b)) if active?; log("ACTION_EXEC #"+@actual.size.to_s+" "+(b ? b.name.to_s : "nil")+" token="+@actual[-1].to_s) if active?; end
    def self.set_field(weather_sym,turns)
      st=field_state; return false if st==nil; st.weather=weather_sym; st.weather_turns=turns.to_i; st.terrain=nil; st.terrain_turns=0; true
    rescue; false; end
    def self.apply_test_speeds
      speeds=TEST_SPEEDS[current_round]||[]; (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_an,speeds[i]) if b&&speeds[i]!=nil}
    end

    def self.prepare_round_fixture
      a=test_allies; e=all_enemies; r=current_round
      @forced_proc={}
      (a+e).each{|b|b.instance_variable_set(:@cg_v2539an_wait_turn_serial,nil) if b}
      if r==1
        set_field(:sun,5); @forced_proc[:nurse]=true; log("ROUND1_FIELD weather=sun nurse=forced_true")
        if a[0]; a[0].hp=[a[0].maxhp.to_i/3,1].max; a[0].cg_reset_stat_stages if a[0].respond_to?(:cg_reset_stat_stages); end
        if a[1]; a[1].hp=[a[1].maxhp.to_i/2,1].max; end
        if a[2]; a[2].hp=a[2].maxhp.to_i; end
        if a[3]; a[3].hp=[a[3].maxhp.to_i/2,1].max; end
        if e[0]; e[0].hp=[e[0].maxhp.to_i/2,1].max; e[0].add_state(poison_state); end
        if e[1]; e[1].hp=[e[1].maxhp.to_i/2,1].max; end
        if e[2]; e[2].hp=e[2].maxhp.to_i; end
        if e[3]; e[3].hp=[e[3].maxhp.to_i/2,1].max; end
        @r1_counts={}; HANDLED_ABILITY_IDS.each{|id|@r1_counts[id]=records_for(id).size}
        @r1_spirit_hp=a[0] ? a[0].hp.to_i : 0; @r1_spirit_atk=a[0]&&a[0].respond_to?(:cg_stat_stage) ? a[0].cg_stat_stage(:atk).to_i : 0
        @r1_melee_target_hp=e[0] ? e[0].hp.to_i : 0; @r1_sponge_hp=e[3] ? e[3].hp.to_i : 0
      elsif r==2
        set_field(:sandstorm,5); @forced_proc[:nurse]=false; log("ROUND2_FIELD weather=sandstorm nurse=forced_false")
        if a[0]; a[0].hp=[a[0].maxhp.to_i/2,1].max; end
        if a[1]; a[1].hp=a[1].maxhp.to_i; end
        if a[2]; a[2].hp=a[2].maxhp.to_i; end
        if a[3]; a[3].hp=a[3].maxhp.to_i; end
        if e[0]; e[0].hp=[e[0].maxhp.to_i/2,1].max; e[0].add_state(poison_state) unless e[0].state?(poison_state); end
        if e[1]; e[1].hp=[e[1].maxhp.to_i/2,1].max; end
        if e[3]; e[3].hp=[e[3].maxhp.to_i/2,1].max; end
        @r2_counts={}; HANDLED_ABILITY_IDS.each{|id|@r2_counts[id]=records_for(id).size}
      elsif r==3
        set_field(nil,0); @forced_proc[:nurse]=true; log("ROUND3_FIELD weather=nil nurse=forced_true")
        # Full HP removes Medic target; clear primary status removes Nurse target; Spirit is safely above threshold.
        a.each{|b|b.hp=b.maxhp.to_i if b}; e.each{|b|b.hp=b.maxhp.to_i if b}
        (a+e).each{|b|b.cg_v231_cure_primary_statuses if b&&b.respond_to?(:cg_v231_cure_primary_statuses)}
        @r3_counts={}; HANDLED_ABILITY_IDS.each{|id|@r3_counts[id]=records_for(id).size}
      end
    end
    def self.prepare_round_actions
      prepare_round_fixture; apply_test_speeds; @actual=[]; plan=current_plan; a=test_allies
      plan[:allies].each_with_index{|cfg,i|next if a[i]==nil; act=make_action(a[i],cfg); a[i].instance_variable_set(:@cg_round_actions,[act]); a[i].cg_assign_action(act) if a[i].respond_to?(:cg_assign_action); a[i].instance_variable_set(:@action,act) unless a[i].respond_to?(:cg_assign_action)}
      log("ROUND "+current_round.to_s+" BEGIN "+plan[:name].to_s); true
    end
    def self.assert_order
      exp=EXPECTED_EXECUTION_TOKENS[current_round]||[]; ok=@actual==exp; @action_checks+=1 if ok; assert_true("Round"+current_round.to_s+" execution order matches deterministic plan",ok,"expected="+exp.inspect+" actual="+@actual.inspect)
    end
    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil"))
      assert_true("Ability Batch AN defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability AN test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil"))
      assert_true("Ability AN ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s); assert_true("Ability AN enemy count=4",all_enemies.size==4,"actual="+all_enemies.size.to_s)
    end

    def self.finish_round_assertions
      assert_order; a=test_allies; e=all_enemies; r=current_round
      if r==1
        srec=records_for(ABILITY_SPIRIT,:spirit)[-1]||{}; sok=!srec.empty?&&srec[:heal].to_i==[a[0].maxhp.to_i/SPIRIT_HEAL_DENOM,1].max&&srec[:atk_after].to_i==@r1_spirit_atk.to_i+1; @recovery_checks+=1 if sok; @stat_checks+=1 if sok; assert_true("Spirit at <=1/3 heals 1/3 and raises ATK +1",sok,srec.inspect)
        wrec=records_for(ABILITY_WARM_BLANKET,:warm_blanket)[-1]||{}; wok=!wrec.empty?&&wrec[:heal].to_i==[a[1].maxhp.to_i/8,1].max; @recovery_checks+=1 if wok; assert_true("Warm Blanket Sun heat environment heals 1/8",wok,wrec.inspect)
        hrec=records_for(ABILITY_HOT_BLOODED,:hot_blooded)[-1]||{}; hok=!hrec.empty?&&hrec[:heal].to_i==[e[0].maxhp.to_i/8,1].max; @recovery_checks+=1 if hok; assert_true("Hot Blooded Sun heat environment heals 1/8",hok,hrec.inspect)
        mrec=records_for(ABILITY_MEDIC,:medic)[-1]||{}; mok=!mrec.empty?&&mrec[:total_heal].to_i>0; @support_checks+=1 if mok; assert_true("Medic heals injured active teammates",mok,mrec.inspect)
        lrec=records_for(ABILITY_LUNCHBOX,:lunchbox)[-1]||{}; lok=!lrec.empty?&&lrec[:heal].to_i==[e[1].maxhp.to_i/8,1].max; @recovery_checks+=1 if lok; assert_true("Lunchbox heals 1/8 after real Guard/Wait action",lok,lrec.inspect)
        nrec=records_for(ABILITY_NURSE,:nurse)[-1]||{}; nok=!nrec.empty?&&e[0]&&!e[0].state?(poison_state); @support_checks+=1 if nok; assert_true("Nurse forced proc cures ally primary status",nok,"record="+nrec.inspect+" poison="+(e[0] ? e[0].state?(poison_state).to_s : "nil"))
        merec=records_for(ABILITY_MELEE,:melee)[-1]||{}; meok=!merec.empty?&&merec[:loss].to_i==[e[0].maxhp.to_i/16,1].max; @damage_checks+=1 if meok; assert_true("Melee adds 1/16 MaxHP after direct foe damage",meok,merec.inspect)
        sprec=records_for(ABILITY_SPONGE,:sponge)[-1]||{}; spok=!sprec.empty?&&sprec[:total_damage].to_i>0&&sprec[:heal].to_i>=0; @damage_checks+=1 if spok; @recovery_checks+=1 if spok; assert_true("Sponge pulses active foes for 1/16 and heals half actual total",spok,sprec.inspect)
      elsif r==2
        woff=records_for(ABILITY_WARM_BLANKET,:warm_blanket).size==@r2_counts[ABILITY_WARM_BLANKET]; @scope_checks+=1 if woff; assert_true("Warm Blanket does not heal in Sandstorm",woff,"count="+records_for(ABILITY_WARM_BLANKET,:warm_blanket).size.to_s)
        hrec=records_for(ABILITY_HOT_BLOODED,:hot_blooded)[-1]||{}; hon=records_for(ABILITY_HOT_BLOODED,:hot_blooded).size>@r2_counts[ABILITY_HOT_BLOODED]&&!hrec.empty?; @recovery_checks+=1 if hon; assert_true("Hot Blooded Sandstorm environment still heals 1/8",hon,hrec.inspect)
        loff=records_for(ABILITY_LUNCHBOX,:lunchbox).size==@r2_counts[ABILITY_LUNCHBOX]; @scope_checks+=1 if loff; assert_true("Lunchbox does not heal without Guard/Wait",loff,"count="+records_for(ABILITY_LUNCHBOX,:lunchbox).size.to_s)
        noff=records_for(ABILITY_NURSE,:nurse).size==@r2_counts[ABILITY_NURSE]&&e[0]&&e[0].state?(poison_state); @scope_checks+=1 if noff; assert_true("Nurse forced no-proc leaves ally status intact",noff,"poison="+(e[0] ? e[0].state?(poison_state).to_s : "nil"))
        me=records_for(ABILITY_MELEE,:melee)[-1]||{}; meok=records_for(ABILITY_MELEE,:melee).size>@r2_counts[ABILITY_MELEE]&&me[:source_index].to_i==1; @damage_checks+=1 if meok; assert_true("Melee aura triggers when a teammate damages the foe",meok,me.inspect)
        sp=records_for(ABILITY_SPONGE,:sponge)[-1]||{}; spok=records_for(ABILITY_SPONGE,:sponge).size>@r2_counts[ABILITY_SPONGE]&&!sp.empty?; @damage_checks+=1 if spok; assert_true("Sponge continues its end-turn pulse",spok,sp.inspect)
      elsif r==3
        [ [ABILITY_WARM_BLANKET,:warm_blanket,"Warm Blanket clear field off"], [ABILITY_HOT_BLOODED,:hot_blooded,"Hot Blooded clear field off"], [ABILITY_SPIRIT,:spirit,"Spirit above one-third off"], [ABILITY_MEDIC,:medic,"Medic full-team no-heal"], [ABILITY_NURSE,:nurse,"Nurse with no status target off"] ].each do |aid,kind,label|
          ok=records_for(aid,kind).size==@r3_counts[aid]; @scope_checks+=1 if ok; assert_true(label,ok,"count="+records_for(aid,kind).size.to_s)
        end
        spok=records_for(ABILITY_SPONGE,:sponge).size>@r3_counts[ABILITY_SPONGE]; @damage_checks+=1 if spok; assert_true("Sponge remains unconditional team-drain support",spok,"count="+records_for(ABILITY_SPONGE,:sponge).size.to_s)
      end
      log("ROUND "+r.to_s+" END"); @round_index=@round_index.to_i+1
    end

    def self.cleanup_test_overrides
      (test_allies+all_enemies).each{|b|clear_runtime(b)}; set_field(nil,0); @forced_proc=nil
    rescue; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|aid|ok=@ability_trigger_counts[aid].to_i>0; assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)}
      log("------------------------------------------------------------"); result=@failures.empty? ? "PASS" : "FAIL"; log("RESULT="+result); passed=0; HANDLED_ABILITY_IDS.each{|x|passed+=1 if @ability_trigger_counts[x].to_i>0}
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_an="+passed.to_s+"/8 recovery_checks="+@recovery_checks.to_s+" support_checks="+@support_checks.to_s+" damage_checks="+@damage_checks.to_s+" stat_checks="+@stat_checks.to_s+" scope_checks="+@scope_checks.to_s+" action_checks="+@action_checks.to_s+" pending=53")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @recovery_checks=0; @support_checks=0; @damage_checks=0; @stat_checks=0; @scope_checks=0; @action_checks=0; @forced_proc={}
    end
    def self.reset_log
      h="CG POKEMON ABILITY AN CONQUEST SUPPORT + RECOVERY AUTO REGRESSION v2.5.39a\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; low-HP/environment recovery + team support + Guard/Wait + status cure + Melee/Sponge\r\n"+
        "BASELINE=v2.5.38 Ability Batch AM RPG Maker VX real-machine PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AM_PASS=312 BATCH_AN=8 PENDING=53\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue; end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; reset_battle_runtime; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AN_v2.5.39a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

ALBERT_CG::ABILITY_AN_V2539.register_handlers if defined?(ALBERT_CG::ABILITY_AN_V2539)

#==============================================================================
# ■ Formal runtime bridges + deterministic F11 harness
#==============================================================================
class Game_Battler
  alias cg_v2539an_execute_damage execute_damage
  def execute_damage(user)
    before_hp=hp.to_i; skill=(defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.current_skill(user) : nil)
    result=cg_v2539an_execute_damage(user)
    if defined?(ALBERT_CG::ABILITY_AN_V2539)
      loss=[before_hp-hp.to_i,0].max
      ALBERT_CG::ABILITY_AN_V2539.melee_after_direct_damage(user,self,loss,skill) if loss>0
    end
    result
  end

  alias cg_v2539an_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AN_V2539)&&ALBERT_CG::ABILITY_AN_V2539.active?; v=@cg_priority_test_speed_override_an; return v.to_i if v!=nil; end
    cg_v2539an_priority_base_speed
  rescue; cg_v2539an_priority_base_speed; end
end

class Scene_Battle < Scene_Base
  alias cg_v2539an_start start
  def start
    ALBERT_CG::ABILITY_AN_V2539.reset_battle_runtime if defined?(ALBERT_CG::ABILITY_AN_V2539)
    cg_v2539an_start
  end
  alias cg_v2539an_execute_action execute_action
  def execute_action
    b=@active_battler
    if defined?(ALBERT_CG::ABILITY_AN_V2539)
      ALBERT_CG::ABILITY_AN_V2539.note_action_start(b)
      ALBERT_CG::ABILITY_AN_V2539.record_execution(b) if ALBERT_CG::ABILITY_AN_V2539.active?
    end
    cg_v2539an_execute_action
  end
  alias cg_v2539an_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AN_V2539)&&ALBERT_CG::ABILITY_AN_V2539.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_AN_V2539.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_AN_V2539.finish_round_assertions; end
    end
    cg_v2539an_turn_end
  end
  alias cg_v2539an_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AN_V2539)&&ALBERT_CG::ABILITY_AN_V2539.active?; return cg_v2539an_start_party_command; end
    cg_v2539an_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_AN_V2539.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AN_V2539.finished?; ALBERT_CG::ABILITY_AN_V2539.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_AN_V2539.prepare_round_actions; start_main
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2539an_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AN_V2539)&&ALBERT_CG::ABILITY_AN_V2539.active?; a=ALBERT_CG::ABILITY_AN_V2539.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end; end
    cg_v2539an_enemy_make_action
  end
end

module ALBERT_CG; class << self
  alias cg_v2539an_bootstrap_demo_party bootstrap_demo_party
  def bootstrap_demo_party
    r=cg_v2539an_bootstrap_demo_party
    if defined?(ALBERT_CG::ABILITY_AN_V2539)&&ALBERT_CG::ABILITY_AN_V2539.active?
      ALBERT_CG::ABILITY_AN_V2539::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AN_V2539.configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_AN_V2539::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,ALBERT_CG::ABILITY_AN_V2539::ABILITY_SPIRIT); end
    end
    r
  end
end; end

# Newest F11 only.
if defined?(ALBERT_CG::ABILITY_AM_V2538)
  module ALBERT_CG; module ABILITY_AM_V2538; def self.f11_trigger?; false; end; end; end
end
class Scene_Map < Scene_Base
  alias cg_v2539an_scene_map_update update
  def update
    cg_v2539an_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_AN_V2539); ALBERT_CG::ABILITY_AN_V2539.start_auto_test if ALBERT_CG::ABILITY_AN_V2539.f11_trigger?
  end
end
