# RMVX_SCRIPT_INDEX: 262
# RMVX_SCRIPT_ID: 262000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AL v2.5.37a
# RMVX_SOURCE_SHA256: ab9597bfcc0c113577d2a6da7159971703b80b257ba96798736dc74e699ff9a9

#==============================================================================
# ■ CG Pokemon Ability Batch AL v2.5.37a - Conquest Reactive Defense + Recovery TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.36a Ability Batch AK RPG Maker VX 實機 PASS 為唯一正式基底，開始收斂
#  373-row catalog 中 Pokémon Conquest Ability。這一批集中處理「直接攻擊迴避、接觸
#  反傷／反狀態、異常狀態能力增幅、睡眠回復」到既有 Ability Core / Status / Stage
#  Authority，不建立第二套傷害或狀態系統。
#
# 【本批 Ability】
#  10006 Parry：接觸 damaging Move 有機率完全迴避。
#  10007 Instinct：敵方 damaging Move 有機率完全迴避（不限定接觸）。
#  10008 Dodge：接觸 damaging Move 有機率迴避；成功時攻擊者 DEF / SPE 各 -1 stage。
#  10009 Jagged Edge：受到接觸 Move 實傷後，有機率反傷攻擊者 MaxHP 1/8。
#  10010 Frostbite：受到接觸 Move 實傷後，有機率使攻擊者 Freeze。
#  10012 Pride：自身有主要異常狀態時，ATK / DEF query x1.20。
#  10013 Deep Sleep：end-turn 若處於 Sleep，回復 MaxHP 1/8。
#  10014 Power Nap：end-turn HP <= 1/3 且沒有主要異常時，回復 MaxHP 1/3 並進入 Sleep。
#
# 【CG 專案適配】
#  1. Conquest 的 Parry / Instinct / Dodge 等迴避機率原本與該作 Link / 系統相關；本作沒有
#     Link 系統，因此正式統一採 CG_REACTIVE_PROC_CHANCE=30%。F11 以 forced proc 做確定性驗證。
#  2. 「direct offensive move」在本作沿用既有 move_motion_hint(:melee_attack) 接觸分類；
#     before_hit 優先走 Ability Core contact_action?，after-hit 反應則用保存的 move_id 作同源 fallback。
#     Instinct 例外，依原意可對所有 damaging Move 觸發，所以包含非接觸特殊招式。
#  3. Dodge 成功時沿用正式 cg_change_stat_stage，DEF / SPE 各 -1；不直接寫 @cg_stat_stages。
#  4. Jagged Edge 反傷 1/8 attacker MaxHP，直接屬於 Ability reaction，不重新進入 Move Damage
#     Core，避免造成接觸／反應遞迴。
#  5. Frostbite 使用既有 Ability Status Authority 套 Freeze，尊重主要異常衝突與免疫。
#  6. Pride 不建立永久 stage；只在 stat_query 對 ATK / DEF 乘 120%，狀態解除立即失效。
#  7. Deep Sleep / Power Nap 使用既有 Sleep state。Power Nap 只在沒有其他主要異常時觸發。
#  8. 所有 Ability ID 仍由 ABILITY_V250.ability_id 讀取，尊重 Neutralizing Gas suppression。
#
# 【F11】
#  Troop 740，三回合 Actual Scene_Battle：
#   R1：Parry 擋接觸、Instinct 擋 Water Gun、Dodge 擋接觸並 DEF/SPE -1；Pride Poison 下加成。
#   R2：Jagged Edge 反傷、Frostbite 反凍；end-turn Deep Sleep 回 1/8、Power Nap 回 1/3 + Sleep。
#   R3：關閉 forced proc；Water Gun 驗 Parry/Dodge 不擋非接觸、Instinct 未 proc 會受傷；
#       Pride 清狀態後回正常、Deep Sleep 醒著不回、Power Nap 高於門檻不觸發。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAL"] = "2.5.37a"

module ALBERT_CG
  module ABILITY_AL_V2537
    VERSION = "2.5.37a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 740
    VK_F11 = 0x7A

    ABILITY_PARRY       = 10006
    ABILITY_INSTINCT    = 10007
    ABILITY_DODGE       = 10008
    ABILITY_JAGGED_EDGE = 10009
    ABILITY_FROSTBITE   = 10010
    ABILITY_PRIDE       = 10012
    ABILITY_DEEP_SLEEP  = 10013
    ABILITY_POWER_NAP   = 10014
    HANDLED_ABILITY_IDS = [10006,10007,10008,10009,10010,10012,10013,10014]

    CG_REACTIVE_PROC_CHANCE = 30
    PRIDE_PERCENT = 120
    JAGGED_EDGE_DENOM = 8
    DEEP_SLEEP_DENOM = 8
    POWER_NAP_DENOM = 3

    TEST_ALLIES = [
      {:dex=>143,:level=>40,:ability=>ABILITY_INSTINCT,:moves=>[150,332,150]},
      {:dex=>65, :level=>40,:ability=>ABILITY_DODGE,   :moves=>[150,150,150]},
      {:dex=>18, :level=>40,:ability=>ABILITY_PRIDE,   :moves=>[150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>45,:ability=>ABILITY_JAGGED_EDGE,:moves=>[332,150,55]},
      {:dex=>383,:level=>45,:ability=>ABILITY_FROSTBITE,  :moves=>[55,150,55]},
      {:dex=>384,:level=>45,:ability=>ABILITY_DEEP_SLEEP, :moves=>[332,150,55]},
      {:dex=>92, :level=>45,:ability=>ABILITY_POWER_NAP,  :moves=>[150,150,150]},
    ]

    ROUND_PLANS = [
      {:name=>"EVASION_PRIDE",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>332,:target=>0},
         1=>{:kind=>:move,:move_id=>55,:target=>1},
         2=>{:kind=>:move,:move_id=>332,:target=>2},
         3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"CONTACT_REACTION_SLEEP_RECOVERY",
       :allies=>[
         {:kind=>:move,:move_id=>332,:target=>0},
         {:kind=>:move,:move_id=>332,:target=>1},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},
         1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},
         3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"SCOPE_AND_DEACTIVATION",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>55,:target=>0},
         1=>{:kind=>:move,:move_id=>55,:target=>1},
         2=>{:kind=>:move,:move_id=>55,:target=>2},
         3=>{:kind=>:move,:move_id=>150,:target=>1}}},
    ]

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:M150","A1:M150","A2:M150","A3:M150","E0:M332","E1:M55","E2:M332","E3:M150"],
      2=>["A0:M332","A1:M332","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
      3=>["A0:M150","A1:M150","A2:M150","A3:M150","E0:M55","E1:M55","E2:M55","E3:M150"],
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
    def self.active?; @active == true; end
    def self.current_round; @round_index.to_i + 1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i >= ROUND_PLANS.size; end
    def self.test_allies; $game_party == nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop == nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AL_AutoTest_v2_5_37a.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API != nil && (KEY_API.call(code) & 0x8000) != 0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d && @f11_down != true; @f11_down=d; t; rescue; false; end
    def self.move_id(skill); move_effect && skill ? move_effect.move_id(skill).to_i : 0; rescue; 0; end
    def self.ability_id(b); core && b ? core.ability_id(b).to_i : 0; rescue; 0; end
    def self.opposing?(a,b); a != nil && b != nil && a.actor? != b.actor?; rescue; false; end
    def self.primary_status?(b); move_effect && b ? move_effect.has_primary_status?(b) : false; rescue; false; end
    def self.sleep_state; move_effect ? move_effect::STATE_SLEEP : 39; end
    def self.freeze_state; move_effect ? move_effect::STATE_FREEZE : 40; end
    def self.poison_state; move_effect ? move_effect::STATE_POISON : 31; end

    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else
        text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text)
      end
      condition
    end
    def self.note_local(aid,battler,kind,data=nil)
      rec={:ability=>aid.to_i,:kind=>kind}; (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill,:action].include?(k)}
      if active?
        @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1
        @records[aid.to_i]=[] if @records[aid.to_i]==nil; @records[aid.to_i].push(rec)
        log("ABILITY_AL_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect)
      end
      rec
    rescue; nil; end
    def self.records_for(aid,kind=nil); a=@records[aid.to_i]||[]; return a if kind==nil; a.select{|x|x[:kind].to_sym==kind.to_sym}; rescue; []; end

    def self.proc_success?(kind)
      if active? && @forced_proc != nil && @forced_proc.has_key?(kind.to_sym)
        return @forced_proc[kind.to_sym] == true
      end
      rand(100) < CG_REACTIVE_PROC_CHANCE
    rescue; false; end

    def self.damaging_enemy_move?(holder,ctx)
      return false if holder==nil || ctx==nil || ctx[:user]==nil || ctx[:skill]==nil
      return false unless opposing?(holder,ctx[:user])
      ctx[:skill].base_damage.to_i > 0
    rescue; false; end

    def self.change_stage(source,target,key,amount)
      return 0 if target==nil || !target.respond_to?(:cg_change_stat_stage)
      auth=defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) ? ALBERT_CG::ABILITY_STAT_GUARD_V256 : nil
      return auth.with_stage_source(source,:ability,false){target.cg_change_stat_stage(key,amount).to_i} if auth && auth.respond_to?(:with_stage_source)
      target.cg_change_stat_stage(key,amount).to_i
    rescue; 0; end

    #--------------------------------------------------------------------------
    # Contact / positive-damage evidence
    #--------------------------------------------------------------------------
    # YEM/Tankentai 的 Actor 行動在 execute_damage 後段不保證 user.action 仍可供
    # contact_action? 查詢，因此 AL 不能只依賴 Ability Core 當下的 :contact。
    # ctx 已保存 move_id / skill，故以既有 move_motion_hint(:melee_attack) 作同源 fallback。
    def self.contact_hit_context?(ctx)
      return false if ctx==nil
      return true if ctx[:contact]==true
      mid=ctx[:move_id].to_i
      mid=move_id(ctx[:skill]) if mid<=0 && ctx[:skill]!=nil
      return false if mid<=0 || master==nil || !master.respond_to?(:move_motion_hint)
      master.move_motion_hint(mid)==:melee_attack
    rescue
      false
    end

    # after_hit 的正向傷害證據：優先採真正 HP loss；若 YEM 的 actor->enemy
    # 時序讓 damage_done 尚未反映，則接受 Ability Core 在 hit 中保存的 planned damage。
    # 0 / 負值仍視為無傷害，因此 Protect、免疫、回復不會觸發接觸反應。
    def self.positive_direct_damage?(ctx)
      return false if ctx==nil
      return true if ctx[:damage_done].to_i>0
      return true if ctx[:damage].to_i>0
      false
    rescue
      false
    end

    #--------------------------------------------------------------------------
    # Formal handlers
    #--------------------------------------------------------------------------
    def self.apply_parry(holder,ctx)
      return false unless damaging_enemy_move?(holder,ctx)
      return false unless core && core.contact_action?(ctx[:user])
      return false unless proc_success?(:parry)
      ctx[:cancel]=true; ctx[:hp_damage]=0
      note_local(ABILITY_PARRY,holder,:parry,{:move_id=>ctx[:move_id].to_i,:attacker_index=>ctx[:user].index.to_i})
      true
    rescue; false; end

    def self.apply_instinct(holder,ctx)
      return false unless damaging_enemy_move?(holder,ctx)
      return false unless proc_success?(:instinct)
      ctx[:cancel]=true; ctx[:hp_damage]=0
      note_local(ABILITY_INSTINCT,holder,:instinct,{:move_id=>ctx[:move_id].to_i,:attacker_index=>ctx[:user].index.to_i})
      true
    rescue; false; end

    def self.apply_dodge(holder,ctx)
      return false unless damaging_enemy_move?(holder,ctx)
      return false unless core && core.contact_action?(ctx[:user])
      return false unless proc_success?(:dodge)
      attacker=ctx[:user]; db=attacker.respond_to?(:cg_stat_stage) ? attacker.cg_stat_stage(:def).to_i : 0; sb=attacker.respond_to?(:cg_stat_stage) ? attacker.cg_stat_stage(:spe).to_i : 0
      dd=change_stage(holder,attacker,:def,-1); sd=change_stage(holder,attacker,:spe,-1)
      ctx[:cancel]=true; ctx[:hp_damage]=0
      note_local(ABILITY_DODGE,holder,:dodge,{:move_id=>ctx[:move_id].to_i,:attacker_index=>attacker.index.to_i,:def_before=>db,:def_after=>attacker.cg_stat_stage(:def).to_i,:spe_before=>sb,:spe_after=>attacker.cg_stat_stage(:spe).to_i,:def_delta=>dd,:spe_delta=>sd})
      true
    rescue; false; end

    def self.apply_jagged_edge(holder,ctx)
      return false if holder==nil || ctx==nil || !contact_hit_context?(ctx) || !positive_direct_damage?(ctx)
      attacker=ctx[:user]; return false if attacker==nil || attacker.hp.to_i<=0 || !opposing?(holder,attacker)
      return false unless proc_success?(:jagged_edge)
      before=attacker.hp.to_i; loss=[attacker.maxhp.to_i/JAGGED_EDGE_DENOM,1].max; attacker.hp=[before-loss,0].max; actual=before-attacker.hp.to_i
      note_local(ABILITY_JAGGED_EDGE,holder,:jagged_edge,{:attacker_index=>attacker.index.to_i,:hp_before=>before,:hp_after=>attacker.hp.to_i,:loss=>actual,:damage_done=>ctx[:damage_done].to_i,:planned_damage=>ctx[:damage].to_i,:move_id=>ctx[:move_id].to_i})
      actual>0
    rescue; false; end

    def self.apply_frostbite(holder,ctx)
      return false if holder==nil || ctx==nil || !contact_hit_context?(ctx) || !positive_direct_damage?(ctx)
      attacker=ctx[:user]; return false if attacker==nil || attacker.hp.to_i<=0 || !opposing?(holder,attacker)
      return false unless proc_success?(:frostbite)
      sid=freeze_state; ok=false
      if defined?(ALBERT_CG::ABILITY_STATUS_V255) && ALBERT_CG::ABILITY_STATUS_V255.respond_to?(:apply_status_from_ability)
        ok=ALBERT_CG::ABILITY_STATUS_V255.apply_status_from_ability(attacker,sid,holder,:frostbite)
      else
        attacker.add_state(sid); ok=attacker.state?(sid)
      end
      note_local(ABILITY_FROSTBITE,holder,:frostbite,{:attacker_index=>attacker.index.to_i,:state_id=>sid,:damage_done=>ctx[:damage_done].to_i,:planned_damage=>ctx[:damage].to_i,:move_id=>ctx[:move_id].to_i}) if ok
      ok
    rescue; false; end

    def self.apply_pride(holder,ctx)
      return false if holder==nil || ctx==nil || !primary_status?(holder)
      key=ctx[:stat].to_sym rescue :none; return false unless key==:atk || key==:def
      before=ctx[:value].to_i; return false if before<=0; after=[before*PRIDE_PERCENT/100,1].max; ctx[:value]=after
      note_local(ABILITY_PRIDE,holder,:pride,{:stat=>key,:before=>before,:after=>after,:percent=>PRIDE_PERCENT})
      true
    rescue; false; end

    def self.apply_deep_sleep(holder,ctx)
      return false if holder==nil || holder.hp.to_i<=0 || !holder.state?(sleep_state) || holder.hp.to_i>=holder.maxhp.to_i
      before=holder.hp.to_i; heal=[holder.maxhp.to_i/DEEP_SLEEP_DENOM,1].max; holder.hp=[before+heal,holder.maxhp.to_i].min; actual=holder.hp.to_i-before
      note_local(ABILITY_DEEP_SLEEP,holder,:deep_sleep,{:hp_before=>before,:hp_after=>holder.hp.to_i,:heal=>actual}) if actual>0
      actual>0
    rescue; false; end

    def self.apply_power_nap(holder,ctx)
      return false if holder==nil || holder.hp.to_i<=0 || holder.hp.to_i*3>holder.maxhp.to_i || primary_status?(holder)
      before=holder.hp.to_i; heal=[holder.maxhp.to_i/POWER_NAP_DENOM,1].max; holder.hp=[before+heal,holder.maxhp.to_i].min
      holder.add_state(sleep_state); ok=holder.state?(sleep_state)
      if ok
        note_local(ABILITY_POWER_NAP,holder,:power_nap,{:hp_before=>before,:hp_after=>holder.hp.to_i,:heal=>holder.hp.to_i-before,:state_id=>sleep_state})
      end
      ok
    rescue; false; end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_PARRY,:before_hit,self,:apply_parry)
      core.register(ABILITY_INSTINCT,:before_hit,self,:apply_instinct)
      core.register(ABILITY_DODGE,:before_hit,self,:apply_dodge)
      core.register(ABILITY_JAGGED_EDGE,:after_hit,self,:apply_jagged_edge)
      core.register(ABILITY_FROSTBITE,:after_hit,self,:apply_frostbite)
      core.register(ABILITY_PRIDE,:stat_query,self,:apply_pride)
      core.register(ABILITY_DEEP_SLEEP,:end_turn,self,:apply_deep_sleep)
      core.register(ABILITY_POWER_NAP,:end_turn,self,:apply_power_nap)
      true
    end

    #--------------------------------------------------------------------------
    # Deterministic F11 harness
    #--------------------------------------------------------------------------
    def self.clear_runtime(b)
      return if b==nil
      b.instance_variable_set(:@cg_priority_test_speed_override_al,nil)
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
        h.instance_variable_set(:@cg_master_ability_id,ABILITY_PARRY)
        mids=[150,332]; sids=mids.collect{|m|master.skill_id_for_move(m)}; h.instance_variable_set(:@cg_equipped_skill_ids,sids); h.instance_variable_set(:@cg_skill_slot_ids,sids); h.instance_variable_set(:@skills,sids)
      end
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0]]
      ms=[]; TEST_ENEMIES.each_with_index{|c,i|configure_enemy(c); ms.push(ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]))}
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AL v2.5.37a AutoRegression",ms)
    end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); else; a.clear; end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active? && e && !e.hidden && e.hp.to_i>0; c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c); end
    def self.action_token(b)
      return "nil" if b==nil; side=b.actor? ? "A" : "E"; idx=b.index.to_i; a=b.action
      return side+idx.to_s+":Guard" if a && a.guard?; return side+idx.to_s+":M"+move_id(a.skill).to_s if a && a.skill?; side+idx.to_s+":Other"
    rescue; "?"; end
    def self.record_execution(b); @actual.push(action_token(b)) if active?; log("ACTION_EXEC #"+@actual.size.to_s+" "+(b ? b.name.to_s : "nil")+" token="+@actual[-1].to_s) if active?; end

    def self.prepare_round_fixture
      a=test_allies; e=all_enemies; r=current_round
      if r==1
        @forced_proc={:parry=>true,:instinct=>true,:dodge=>true,:jagged_edge=>false,:frostbite=>false}
        a[3].remove_state(poison_state) if a[3] && a[3].state?(poison_state)
        @r1_pride_base_atk=a[3] ? a[3].cg_atk_stat.to_i : 0; @r1_pride_base_def=a[3] ? a[3].cg_def_stat.to_i : 0
        a[3].add_state(poison_state) if a[3]
        @r1_pride_atk=a[3] ? a[3].cg_atk_stat.to_i : 0; @r1_pride_def=a[3] ? a[3].cg_def_stat.to_i : 0
        @r1_hp=[a[0],a[1],a[2]].collect{|b|b ? b.hp.to_i : 0}
        @r1_dodge_def=e[2] ? e[2].cg_stat_stage(:def).to_i : 0; @r1_dodge_spe=e[2] ? e[2].cg_stat_stage(:spe).to_i : 0
      elsif r==2
        @forced_proc={:parry=>false,:instinct=>false,:dodge=>false,:jagged_edge=>true,:frostbite=>true}
        a[1].remove_state(freeze_state) if a[1] && a[1].state?(freeze_state)
        @r2_a0_hp=a[0] ? a[0].hp.to_i : 0; @r2_a1_frozen=a[1] ? a[1].state?(freeze_state) : false
      elsif r==3
        @forced_proc={:parry=>false,:instinct=>false,:dodge=>false,:jagged_edge=>false,:frostbite=>false}
        a[1].remove_state(freeze_state) if a[1] && a[1].state?(freeze_state)
        a[3].remove_state(poison_state) if a[3] && a[3].state?(poison_state)
        e[2].remove_state(sleep_state) if e[2] && e[2].state?(sleep_state)
        e[3].remove_state(sleep_state) if e[3] && e[3].state?(sleep_state)
        e[2].hp=[e[2].maxhp.to_i/2,1].max if e[2]; e[3].hp=[e[3].maxhp.to_i/2,1].max if e[3]
        @r3_hp=[a[0],a[1],a[2]].collect{|b|b ? b.hp.to_i : 0}
        @r3_pride_base_atk=a[3] ? a[3].cg_atk_stat.to_i : 0; @r3_pride_base_def=a[3] ? a[3].cg_def_stat.to_i : 0
        @r3_e2_hp=e[2] ? e[2].hp.to_i : 0; @r3_e3_hp=e[3] ? e[3].hp.to_i : 0
        @r3_evade_counts={:parry=>records_for(ABILITY_PARRY,:parry).size,:instinct=>records_for(ABILITY_INSTINCT,:instinct).size,:dodge=>records_for(ABILITY_DODGE,:dodge).size}
      end
    end

    def self.prepare_end_turn_fixture
      return unless active? && current_round==2
      e=all_enemies
      if e[2]
        e[2].remove_state(sleep_state) if e[2].state?(sleep_state); e[2].hp=[e[2].maxhp.to_i/2,1].max; e[2].add_state(sleep_state); @r2_e2_hp=e[2].hp.to_i
      end
      if e[3]
        [poison_state,freeze_state,sleep_state].each{|sid|e[3].remove_state(sid) if e[3].state?(sid)}; e[3].hp=[e[3].maxhp.to_i/3,1].max; @r2_e3_hp=e[3].hp.to_i
      end
      log("ROUND2_SLEEP_FIXTURE E2="+(@r2_e2_hp||0).to_s+" E3="+(@r2_e3_hp||0).to_s)
    end

    def self.apply_test_speeds
      speeds=TEST_SPEEDS[current_round]||[]; list=test_allies+all_enemies; list.each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_al,speeds[i]) if b && speeds[i]!=nil}
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
      assert_true("Ability Batch AL defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability AL test troop",$game_troop && $game_troop.troop && $game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil"))
      assert_true("Ability AL ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability AL enemy count=4",all_enemies.size==4,"actual="+all_enemies.size.to_s)
    end

    def self.finish_round_assertions
      assert_order; a=test_allies; e=all_enemies; r=current_round
      if r==1
        p_ok=a[0]&&a[0].hp.to_i==@r1_hp[0]&&!records_for(ABILITY_PARRY,:parry).empty?; @evasion_checks+=1 if p_ok; assert_true("Parry evades real contact damaging Move",p_ok,"hp="+@r1_hp[0].to_s+"->"+(a[0] ? a[0].hp.to_i.to_s : "nil"))
        i_ok=a[1]&&a[1].hp.to_i==@r1_hp[1]&&!records_for(ABILITY_INSTINCT,:instinct).empty?; @evasion_checks+=1 if i_ok; assert_true("Instinct evades real non-contact Water Move",i_ok,"hp="+@r1_hp[1].to_s+"->"+(a[1] ? a[1].hp.to_i.to_s : "nil"))
        drec=records_for(ABILITY_DODGE,:dodge)[-1]||{}; d_ok=a[2]&&a[2].hp.to_i==@r1_hp[2]&&e[2]&&e[2].cg_stat_stage(:def).to_i==@r1_dodge_def-1&&e[2].cg_stat_stage(:spe).to_i==@r1_dodge_spe-1&&!drec.empty?; @evasion_checks+=1 if d_ok; assert_true("Dodge evades contact and lowers attacker DEF/SPE",d_ok,drec.inspect)
        pa=@r1_pride_base_atk>0 && @r1_pride_atk==[@r1_pride_base_atk*PRIDE_PERCENT/100,1].max; pd=@r1_pride_base_def>0 && @r1_pride_def==[@r1_pride_base_def*PRIDE_PERCENT/100,1].max; pr=pa&&pd; @stat_checks+=1 if pr; assert_true("Pride boosts ATK/DEF while holder has primary status",pr,"atk="+@r1_pride_base_atk.to_s+"->"+@r1_pride_atk.to_s+" def="+@r1_pride_base_def.to_s+"->"+@r1_pride_def.to_s)
      elsif r==2
        jr=records_for(ABILITY_JAGGED_EDGE,:jagged_edge)[-1]||{}; expected=[a[0].maxhp.to_i/JAGGED_EDGE_DENOM,1].max; jok=a[0]&&jr[:loss].to_i==expected&&@r2_a0_hp-a[0].hp.to_i==expected; @reaction_checks+=1 if jok; assert_true("Jagged Edge contact reaction deals 1/8 attacker MaxHP",jok,"hp="+@r2_a0_hp.to_s+"->"+(a[0] ? a[0].hp.to_i.to_s : "nil")+" record="+jr.inspect)
        fok=a[1]&&a[1].state?(freeze_state)&&!records_for(ABILITY_FROSTBITE,:frostbite).empty?; @reaction_checks+=1 if fok; assert_true("Frostbite contact reaction freezes attacker",fok,"freeze="+(a[1] ? a[1].state?(freeze_state).to_s : "nil"))
        dr=records_for(ABILITY_DEEP_SLEEP,:deep_sleep)[-1]||{}; dheal=e[2] ? e[2].hp.to_i-@r2_e2_hp.to_i : 0; dexp=e[2] ? [e[2].maxhp.to_i/DEEP_SLEEP_DENOM,1].max : 0; dok=e[2]&&e[2].state?(sleep_state)&&dheal==dexp&&!dr.empty?; @recovery_checks+=1 if dok; assert_true("Deep Sleep heals 1/8 MaxHP at end-turn while asleep",dok,"heal="+dheal.to_s+" expected="+dexp.to_s)
        nr=records_for(ABILITY_POWER_NAP,:power_nap)[-1]||{}; nheal=e[3] ? e[3].hp.to_i-@r2_e3_hp.to_i : 0; nexp=e[3] ? [e[3].maxhp.to_i/POWER_NAP_DENOM,1].max : 0; nok=e[3]&&e[3].state?(sleep_state)&&nheal==nexp&&!nr.empty?; @recovery_checks+=1 if nok; assert_true("Power Nap at <=1/3 heals 1/3 MaxHP and applies Sleep",nok,"heal="+nheal.to_s+" expected="+nexp.to_s+" sleep="+(e[3] ? e[3].state?(sleep_state).to_s : "nil"))
      elsif r==3
        nonp=a[0]&&a[0].hp.to_i<@r3_hp[0]&&records_for(ABILITY_PARRY,:parry).size==@r3_evade_counts[:parry]; @scope_checks+=1 if nonp; assert_true("Parry does not evade non-contact Water Gun",nonp,"hp="+@r3_hp[0].to_s+"->"+(a[0] ? a[0].hp.to_i.to_s : "nil"))
        noni=a[1]&&a[1].hp.to_i<@r3_hp[1]&&records_for(ABILITY_INSTINCT,:instinct).size==@r3_evade_counts[:instinct]; @scope_checks+=1 if noni; assert_true("Instinct failed proc leaves normal damage path intact",noni,"hp="+@r3_hp[1].to_s+"->"+(a[1] ? a[1].hp.to_i.to_s : "nil"))
        nond=a[2]&&a[2].hp.to_i<@r3_hp[2]&&records_for(ABILITY_DODGE,:dodge).size==@r3_evade_counts[:dodge]; @scope_checks+=1 if nond; assert_true("Dodge does not evade non-contact Water Gun",nond,"hp="+@r3_hp[2].to_s+"->"+(a[2] ? a[2].hp.to_i.to_s : "nil"))
        pride_off=a[3]&&!primary_status?(a[3])&&a[3].cg_atk_stat.to_i==@r3_pride_base_atk&&a[3].cg_def_stat.to_i==@r3_pride_base_def; @stat_checks+=1 if pride_off; assert_true("Pride deactivates immediately after status clears",pride_off,"atk="+(a[3] ? a[3].cg_atk_stat.to_i.to_s : "nil")+" def="+(a[3] ? a[3].cg_def_stat.to_i.to_s : "nil"))
        ds_off=e[2]&&e[2].hp.to_i==@r3_e2_hp; @scope_checks+=1 if ds_off; assert_true("Deep Sleep does not heal while awake",ds_off,"hp="+@r3_e2_hp.to_s+"->"+(e[2] ? e[2].hp.to_i.to_s : "nil"))
        pn_off=e[3]&&e[3].hp.to_i==@r3_e3_hp&&!e[3].state?(sleep_state); @scope_checks+=1 if pn_off; assert_true("Power Nap does not trigger above one-third HP",pn_off,"hp="+@r3_e3_hp.to_s+"->"+(e[3] ? e[3].hp.to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END"); @round_index=@round_index.to_i+1
    end

    def self.cleanup_test_overrides
      (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_al,nil) if b}; @forced_proc={}
    rescue; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|aid|ok=@ability_trigger_counts[aid].to_i>0; assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)}
      log("------------------------------------------------------------"); result=@failures.empty? ? "PASS" : "FAIL"; log("RESULT="+result); passed=0; HANDLED_ABILITY_IDS.each{|x|passed+=1 if @ability_trigger_counts[x].to_i>0}
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_al="+passed.to_s+"/8 evasion_checks="+@evasion_checks.to_s+" reaction_checks="+@reaction_checks.to_s+" stat_checks="+@stat_checks.to_s+" recovery_checks="+@recovery_checks.to_s+" scope_checks="+@scope_checks.to_s+" action_checks="+@action_checks.to_s+" pending=69")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @forced_proc={}; @evasion_checks=0; @reaction_checks=0; @stat_checks=0; @recovery_checks=0; @scope_checks=0; @action_checks=0
    end
    def self.reset_log
      h="CG POKEMON ABILITY AL CONQUEST REACTIVE DEFENSE + RECOVERY AUTO REGRESSION v2.5.37a\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; Conquest evasion + contact reaction + status stat + sleep recovery authority\r\n"+
        "BASELINE=v2.5.36a Ability Batch AK RPG Maker VX real-machine PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AK_PASS=296 BATCH_AL=8 PENDING=69\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue; end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AL_v2.5.37a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

ALBERT_CG::ABILITY_AL_V2537.register_handlers if defined?(ALBERT_CG::ABILITY_AL_V2537)

#==============================================================================
# ■ Scene / deterministic F11 harness
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2537al_execute_action execute_action
  def execute_action
    b=@active_battler; ALBERT_CG::ABILITY_AL_V2537.record_execution(b) if defined?(ALBERT_CG::ABILITY_AL_V2537)&&ALBERT_CG::ABILITY_AL_V2537.active?; cg_v2537al_execute_action
  end
  alias cg_v2537al_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AL_V2537)&&ALBERT_CG::ABILITY_AL_V2537.active?
      ALBERT_CG::ABILITY_AL_V2537.prepare_end_turn_fixture
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_AL_V2537.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_AL_V2537.finish_round_assertions; end
    end
    cg_v2537al_turn_end
  end
  alias cg_v2537al_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AL_V2537)&&ALBERT_CG::ABILITY_AL_V2537.active?; return cg_v2537al_start_party_command; end
    cg_v2537al_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_AL_V2537.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AL_V2537.finished?; ALBERT_CG::ABILITY_AL_V2537.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_AL_V2537.prepare_round_actions; start_main
  end
end
class Game_Battler
  alias cg_v2537al_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AL_V2537)&&ALBERT_CG::ABILITY_AL_V2537.active?; v=@cg_priority_test_speed_override_al; return v.to_i if v!=nil; end
    cg_v2537al_priority_base_speed
  rescue; cg_v2537al_priority_base_speed; end
end
class Game_Enemy < Game_Battler
  alias cg_v2537al_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AL_V2537)&&ALBERT_CG::ABILITY_AL_V2537.active?; a=ALBERT_CG::ABILITY_AL_V2537.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end; end
    cg_v2537al_enemy_make_action
  end
end
module ALBERT_CG; class << self
  alias cg_v2537al_bootstrap_demo_party bootstrap_demo_party
  def bootstrap_demo_party
    r=cg_v2537al_bootstrap_demo_party
    if defined?(ALBERT_CG::ABILITY_AL_V2537)&&ALBERT_CG::ABILITY_AL_V2537.active?
      ALBERT_CG::ABILITY_AL_V2537::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AL_V2537.configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_AL_V2537::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,ALBERT_CG::ABILITY_AL_V2537::ABILITY_PARRY); end
    end
    r
  end
end; end

# Newest F11 only.
if defined?(ALBERT_CG::ABILITY_AK_V2536)
  module ALBERT_CG; module ABILITY_AK_V2536; def self.f11_trigger?; false; end; end; end
end
class Scene_Map < Scene_Base
  alias cg_v2537al_scene_map_update update
  def update
    cg_v2537al_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_AL_V2537); ALBERT_CG::ABILITY_AL_V2537.start_auto_test if ALBERT_CG::ABILITY_AL_V2537.f11_trigger?
  end
end
