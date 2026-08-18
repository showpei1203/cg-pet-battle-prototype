# RMVX_SCRIPT_INDEX: 263
# RMVX_SCRIPT_ID: 263000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AM v2.5.38
# RMVX_SOURCE_SHA256: 1729696760dcfda504b4efd6f101492c54796e3467267facc61850615fa14827

#==============================================================================
# ■ CG Pokemon Ability Batch AM v2.5.38 - Conquest Environment + Momentum TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.37a Ability Batch AL RPG Maker VX 實機 PASS 為唯一正式基底，收斂
#  Pokémon Conquest 的環境回復、劣勢強化、先手傷害與 KO 累積能力。全部接入既有
#  Field / :end_turn / :stat_query / :damage_modify / :after_ko Authority，不建立第二套
#  HP、能力值、KO 或行動順序系統。
#
# 【本批 Ability】
#  10017 Gulp：Conquest 水格每回合回復 1/8 MaxHP。
#  10018 Herbivore：Conquest 草格每回合回復 1/8 MaxHP。
#  10019 Sandpit：Conquest soil/sand 格每回合回復 1/8 MaxHP。
#  10022 Life Force：每回合回復 1/8 MaxHP。
#  10028 Hero：軍勢總戰力低於敵方 1/3 時，ATK / DEF +1 stage。
#  10029 Last Bastion：我方其他單位全部倒下時，ATK / DEF +2 stages。
#  10031 Vanguard：本回合第一個實際行動者使用 damaging Move 時，傷害 +50%。
#  10057 Conqueror：每次真實 KO 後，ATK / DEF / SPE 各累積 +20%，整場持續。
#
# 【CG 專案適配】
#  1. 本專案不是 Conquest tile-grid，因此不捏造地圖格資料：
#       Gulp      -> 有效 Rain / Heavy Rain 視為 water environment。
#       Herbivore -> Grassy Terrain 視為 grass environment。
#       Sandpit   -> Sandstorm 視為 sand/soil environment。
#     Cloud Nine / Air Lock 抑制 Weather 時，Gulp / Sandpit 不把被抑制天氣當環境。
#  2. Ability Core 只有正式 :end_turn lifecycle，沒有 Conquest start-turn pulse；四個回復
#     能力統一在每個 battle turn 的 end-turn 觸發一次，頻率維持「每回合一次」。
#  3. CG 沒有 Conquest army Strength 公式；Hero 使用現有 4v4 Active Battler 數量作
#     tactical-strength proxy：己方存活 active 數 * 3 <= 敵方存活 active 數時生效。
#     加成用 stat_query x1.5，不永久寫入 stage；條件消失立即回復。
#  4. Last Bastion 以己方 active battler 只剩 holder 為條件，stat_query x2.0；不寫永久 stage。
#  5. Vanguard 的「回合第一個行動」由既有 AE turn_serial + Scene_Battle 真實 execute_action
#     記錄，不依測試速度猜測，也不改 Priority Runtime。
#  6. Conqueror 的 KO stack 只由正式 :after_ko 增加；每 stack 對 ATK/DEF/SPE 採
#     100% + 20% * KO 數的 additive multiplier，battle-local，跨換位保留、下一戰清零。
#  7. 所有 Ability ID 經 ABILITY_V250.ability_id，尊重 Neutralizing Gas suppression。
#
# 【F11】
#  Troop 741，三回合 Actual Scene_Battle：
#   R1 Rain + Grassy：Vanguard 真正第一動 +50%；Gulp/Herbivore/Life Force 各回 1/8，
#      Sandpit 在非砂環境不回復。
#   R2 Sandstorm：fixture 暫時縮小己方 active 數來查 Hero +1 stage / Last Bastion +2 stages；
#      Conqueror 以真實 Water Gun KO 取得 stack=1；Sandpit/Life Force 回 1/8。
#   R3 Clear：另一人先行後 Vanguard 不加成；Gulp/Herbivore/Sandpit 不回血、Life Force
#      仍回血；Hero/Last Bastion 條件解除；Conqueror 20% stack 持續。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAM"] = "2.5.38"

module ALBERT_CG
  module ABILITY_AM_V2538
    VERSION = "2.5.38"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 741
    VK_F11 = 0x7A

    ABILITY_GULP         = 10017
    ABILITY_HERBIVORE    = 10018
    ABILITY_SANDPIT      = 10019
    ABILITY_LIFE_FORCE   = 10022
    ABILITY_HERO         = 10028
    ABILITY_LAST_BASTION = 10029
    ABILITY_VANGUARD     = 10031
    ABILITY_CONQUEROR    = 10057
    HANDLED_ABILITY_IDS = [10017,10018,10019,10022,10028,10029,10031,10057]

    RECOVERY_DENOM = 8
    HERO_PERCENT = 150
    LAST_BASTION_PERCENT = 200
    VANGUARD_PERCENT = 150
    CONQUEROR_PER_KO_PERCENT = 20

    TEST_ALLIES = [
      {:dex=>143,:level=>40,:ability=>ABILITY_HERO,        :moves=>[150,150,150]},
      {:dex=>65, :level=>40,:ability=>ABILITY_LAST_BASTION,:moves=>[150,150,150]},
      {:dex=>18, :level=>40,:ability=>ABILITY_CONQUEROR,   :moves=>[150,55,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>45,:ability=>ABILITY_GULP,      :moves=>[150,150,150]},
      {:dex=>383,:level=>45,:ability=>ABILITY_HERBIVORE, :moves=>[150,150,150]},
      {:dex=>384,:level=>45,:ability=>ABILITY_SANDPIT,   :moves=>[150,150,150]},
      {:dex=>92, :level=>45,:ability=>ABILITY_LIFE_FORCE,:moves=>[150,150,150]},
    ]

    ROUND_PLANS = [
      {:name=>"RAIN_GRASS_RECOVERY_VANGUARD",
       :allies=>[
         {:kind=>:move,:move_id=>55,:target=>2},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"SAND_HERO_LAST_CONQUEROR",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>1},
         {:kind=>:move,:move_id=>150,:target=>1},
         {:kind=>:move,:move_id=>150,:target=>1},
         {:kind=>:move,:move_id=>55,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"CLEAR_SCOPE_CONQUEROR_PERSIST",
       :allies=>[
         {:kind=>:move,:move_id=>55,:target=>3},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
    ]
    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:M55","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
      2=>["A0:M150","A1:M150","A2:M150","A3:M55","E1:M150","E2:M150","E3:M150"],
      3=>["A1:M150","A0:M55","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
    }
    TEST_SPEEDS = {
      1=>[900,850,800,750,600,550,500,450],
      2=>[900,850,800,750,600,550,500,450],
      3=>[900,950,800,750,600,550,500,450],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.field; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233 : nil; end
    def self.field_state; field && field.respond_to?(:state) ? field.state : nil; rescue; nil; end
    def self.active?; @active == true; end
    def self.current_round; @round_index.to_i + 1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i >= ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AM_AutoTest_v2_5_38.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.ability_id(b); core&&b ? core.ability_id(b).to_i : 0; rescue; 0; end
    def self.turn_serial; defined?(ALBERT_CG::ABILITY_AE_V2530) ? ALBERT_CG::ABILITY_AE_V2530.turn_serial.to_i : @fallback_turn_serial.to_i; rescue; @fallback_turn_serial.to_i; end
    def self.weather_suppressed?; defined?(ALBERT_CG::ABILITY_AG_V2532)&&ALBERT_CG::ABILITY_AG_V2532.weather_suppressed?; rescue; false; end

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
        log("ABILITY_AM_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect)
      end
      rec
    rescue; nil; end
    def self.records_for(aid,kind=nil); a=@records[aid.to_i]||[]; return a if kind==nil; a.select{|x|x[:kind].to_sym==kind.to_sym}; rescue; []; end

    def self.active_members(holder)
      return [] if holder==nil
      unit=holder.actor? ? $game_party : $game_troop
      return [] if unit==nil
      unit.members.select{|b|b!=nil&&!b.hidden&&b.hp.to_i>0}
    rescue; []; end
    def self.opposing_active_members(holder)
      return [] if holder==nil
      unit=holder.actor? ? $game_troop : $game_party
      return [] if unit==nil
      unit.members.select{|b|b!=nil&&!b.hidden&&b.hp.to_i>0}
    rescue; []; end
    def self.hero_active?(holder)
      own=active_members(holder).size; foe=opposing_active_members(holder).size
      own>0 && foe>0 && own*3<=foe
    rescue; false; end
    def self.last_bastion_active?(holder); active_members(holder).size==1; rescue; false; end

    def self.effective_weather
      st=field_state; return nil if st==nil||st.weather_turns.to_i<=0||weather_suppressed?; st.weather
    rescue; nil; end
    def self.effective_terrain
      st=field_state; return nil if st==nil||st.terrain_turns.to_i<=0; st.terrain
    rescue; nil; end
    def self.heal_eighth(holder,aid,kind)
      return false if holder==nil||holder.hp.to_i<=0||holder.hp.to_i>=holder.maxhp.to_i
      before=holder.hp.to_i; heal=[holder.maxhp.to_i/RECOVERY_DENOM,1].max; holder.hp=[before+heal,holder.maxhp.to_i].min; actual=holder.hp.to_i-before
      note_local(aid,holder,kind,{:hp_before=>before,:hp_after=>holder.hp.to_i,:heal=>actual,:weather=>effective_weather,:terrain=>effective_terrain}) if actual>0
      actual>0
    rescue; false; end

    def self.apply_gulp(holder,ctx); [:rain,:heavy_rain].include?(effective_weather) ? heal_eighth(holder,ABILITY_GULP,:gulp) : false; end
    def self.apply_herbivore(holder,ctx); effective_terrain==:grassy ? heal_eighth(holder,ABILITY_HERBIVORE,:herbivore) : false; end
    def self.apply_sandpit(holder,ctx); effective_weather==:sandstorm ? heal_eighth(holder,ABILITY_SANDPIT,:sandpit) : false; end
    def self.apply_life_force(holder,ctx); heal_eighth(holder,ABILITY_LIFE_FORCE,:life_force); end

    def self.apply_hero(holder,ctx)
      return false if holder==nil||ctx==nil||!hero_active?(holder)
      key=(ctx[:stat].to_sym rescue :none); return false unless key==:atk||key==:def
      before=ctx[:value].to_i; return false if before<=0; after=[before*HERO_PERCENT/100,1].max; ctx[:value]=after
      note_local(ABILITY_HERO,holder,:hero,{:stat=>key,:before=>before,:after=>after,:percent=>HERO_PERCENT,:own_active=>active_members(holder).size,:foe_active=>opposing_active_members(holder).size})
      true
    rescue; false; end
    def self.apply_last_bastion(holder,ctx)
      return false if holder==nil||ctx==nil||!last_bastion_active?(holder)
      key=(ctx[:stat].to_sym rescue :none); return false unless key==:atk||key==:def
      before=ctx[:value].to_i; return false if before<=0; after=[before*LAST_BASTION_PERCENT/100,1].max; ctx[:value]=after
      note_local(ABILITY_LAST_BASTION,holder,:last_bastion,{:stat=>key,:before=>before,:after=>after,:percent=>LAST_BASTION_PERCENT})
      true
    rescue; false; end

    def self.reset_battle_runtime
      @battle_serial=@battle_serial.to_i+1; @first_action_turn_serial=nil; @first_actor_oid=nil; @fallback_turn_serial=1
      true
    rescue; false; end
    def self.ensure_conqueror_runtime(holder)
      return if holder==nil
      if holder.instance_variable_get(:@cg_v2538am_conqueror_battle_serial).to_i!=@battle_serial.to_i
        holder.instance_variable_set(:@cg_v2538am_conqueror_battle_serial,@battle_serial.to_i)
        holder.instance_variable_set(:@cg_v2538am_conqueror_kos,0)
      end
    end
    def self.note_action_start(b)
      return if b==nil
      ts=turn_serial
      if @first_action_turn_serial.to_i!=ts
        @first_action_turn_serial=ts; @first_actor_oid=b.object_id
      end
    rescue; end
    def self.first_actor_this_turn?(b); b!=nil&&@first_action_turn_serial.to_i==turn_serial&&@first_actor_oid==b.object_id; rescue; false; end

    def self.apply_vanguard(holder,ctx)
      return false if holder==nil||ctx==nil||ctx[:role]!=:attacker||ctx[:fixed_damage]==true||!first_actor_this_turn?(holder)
      before=ctx[:damage].to_i; return false if before<=0; after=[before*VANGUARD_PERCENT/100,1].max; ctx[:damage]=after
      note_local(ABILITY_VANGUARD,holder,:vanguard,{:move_id=>ctx[:move_id].to_i,:before=>before,:after=>after,:percent=>VANGUARD_PERCENT,:turn_serial=>turn_serial})
      true
    rescue; false; end
    def self.apply_conqueror_ko(holder,ctx)
      return false if holder==nil||ctx==nil||ctx[:target]==nil||ctx[:target].hp.to_i>0
      ensure_conqueror_runtime(holder); before=holder.instance_variable_get(:@cg_v2538am_conqueror_kos).to_i; after=before+1; holder.instance_variable_set(:@cg_v2538am_conqueror_kos,after)
      note_local(ABILITY_CONQUEROR,holder,:conqueror_ko,{:before=>before,:after=>after,:target_index=>ctx[:target].index.to_i})
      true
    rescue; false; end
    def self.apply_conqueror_stat(holder,ctx)
      return false if holder==nil||ctx==nil
      key=(ctx[:stat].to_sym rescue :none); return false unless [:atk,:def,:spe].include?(key)
      ensure_conqueror_runtime(holder); stacks=holder.instance_variable_get(:@cg_v2538am_conqueror_kos).to_i; return false if stacks<=0
      before=ctx[:value].to_i; return false if before<=0; percent=100+CONQUEROR_PER_KO_PERCENT*stacks; after=[before*percent/100,1].max; ctx[:value]=after
      note_local(ABILITY_CONQUEROR,holder,:conqueror_stat,{:stat=>key,:stacks=>stacks,:before=>before,:after=>after,:percent=>percent})
      true
    rescue; false; end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_GULP,:end_turn,self,:apply_gulp)
      core.register(ABILITY_HERBIVORE,:end_turn,self,:apply_herbivore)
      core.register(ABILITY_SANDPIT,:end_turn,self,:apply_sandpit)
      core.register(ABILITY_LIFE_FORCE,:end_turn,self,:apply_life_force)
      core.register(ABILITY_HERO,:stat_query,self,:apply_hero)
      core.register(ABILITY_LAST_BASTION,:stat_query,self,:apply_last_bastion)
      core.register(ABILITY_VANGUARD,:damage_modify,self,:apply_vanguard)
      core.register(ABILITY_CONQUEROR,:after_ko,self,:apply_conqueror_ko)
      core.register(ABILITY_CONQUEROR,:stat_query,self,:apply_conqueror_stat)
      true
    end

    #--------------------------------------------------------------------------
    # Deterministic F11 harness
    #--------------------------------------------------------------------------
    def self.clear_runtime(b); b.instance_variable_set(:@cg_priority_test_speed_override_am,nil) if b; end
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
        h.instance_variable_set(:@cg_master_ability_id,ABILITY_VANGUARD)
        mids=[55,150]; sids=mids.collect{|m|master.skill_id_for_move(m)}; h.instance_variable_set(:@cg_equipped_skill_ids,sids); h.instance_variable_set(:@cg_skill_slot_ids,sids); h.instance_variable_set(:@skills,sids)
      end
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0]]
      ms=[]; TEST_ENEMIES.each_with_index{|c,i|configure_enemy(c); ms.push(ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]))}
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AM v2.5.38 AutoRegression",ms)
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

    def self.set_field(weather_sym,weather_turns,terrain_sym,terrain_turns)
      st=field_state; return false if st==nil; st.weather=weather_sym; st.weather_turns=weather_turns.to_i; st.terrain=terrain_sym; st.terrain_turns=terrain_turns.to_i; true
    rescue; false; end
    def self.with_only_holder_active(holder)
      list=active_members(holder); saved=[]
      list.each{|b|next if b.equal?(holder); saved << [b,b.instance_variable_get(:@hidden)]; b.instance_variable_set(:@hidden,true)}
      result=yield
      saved.each{|pair|pair[0].instance_variable_set(:@hidden,pair[1])}
      result
    ensure
      saved.each{|pair|pair[0].instance_variable_set(:@hidden,pair[1])} if saved
    end

    def self.prepare_round_fixture
      a=test_allies; e=all_enemies; r=current_round
      if r==1
        set_field(:rain,5,:grassy,5); log("ROUND1_FIELD weather=rain terrain=grassy")
        [0,1,3].each{|i|e[i].hp=[e[i].maxhp.to_i/2,1].max if e[i]}; e[2].hp=e[2].maxhp.to_i if e[2]
        @r1_hp=e.collect{|b|b ? b.hp.to_i : 0}; @r1_rec_counts={:g=>records_for(ABILITY_GULP,:gulp).size,:h=>records_for(ABILITY_HERBIVORE,:herbivore).size,:s=>records_for(ABILITY_SANDPIT,:sandpit).size,:l=>records_for(ABILITY_LIFE_FORCE,:life_force).size}
      elsif r==2
        set_field(:sandstorm,5,nil,0); log("ROUND2_FIELD weather=sandstorm terrain=nil")
        e[0].hp=1 if e[0]; e[2].hp=[e[2].maxhp.to_i/2,1].max if e[2]; e[3].hp=[e[3].maxhp.to_i/2,1].max if e[3]
        @r2_e2_hp=e[2] ? e[2].hp.to_i : 0; @r2_e3_hp=e[3] ? e[3].hp.to_i : 0
        # Hero baseline -> one-vs-four probe.
        @r2_hero_base_atk=a[1] ? a[1].cg_atk_stat.to_i : 0; @r2_hero_base_def=a[1] ? a[1].cg_def_stat.to_i : 0
        if a[1]
          vals=with_only_holder_active(a[1]){[a[1].cg_atk_stat.to_i,a[1].cg_def_stat.to_i,active_members(a[1]).size,opposing_active_members(a[1]).size]}; @r2_hero_atk,@r2_hero_def,@r2_hero_own,@r2_hero_foe=vals
        end
        @r2_last_base_atk=a[2] ? a[2].cg_atk_stat.to_i : 0; @r2_last_base_def=a[2] ? a[2].cg_def_stat.to_i : 0
        if a[2]
          vals=with_only_holder_active(a[2]){[a[2].cg_atk_stat.to_i,a[2].cg_def_stat.to_i]}; @r2_last_atk,@r2_last_def=vals
        end
        @r2_conq_base_atk=a[3] ? a[3].cg_atk_stat.to_i : 0; @r2_conq_base_def=a[3] ? a[3].cg_def_stat.to_i : 0; @r2_conq_base_spe=a[3] ? a[3].cg_spe.to_i : 0
      elsif r==3
        set_field(nil,0,nil,0); log("ROUND3_FIELD weather=nil terrain=nil")
        if e[0]; e[0].instance_variable_set(:@hidden,false); e[0].hp=[e[0].maxhp.to_i/2,1].max; end
        [1,2,3].each{|i|e[i].hp=[e[i].maxhp.to_i/2,1].max if e[i]}
        @r3_hp=e.collect{|b|b ? b.hp.to_i : 0}; @r3_vanguard_count=records_for(ABILITY_VANGUARD,:vanguard).size
        @r3_env_counts={:g=>records_for(ABILITY_GULP,:gulp).size,:h=>records_for(ABILITY_HERBIVORE,:herbivore).size,:s=>records_for(ABILITY_SANDPIT,:sandpit).size,:l=>records_for(ABILITY_LIFE_FORCE,:life_force).size}
        @r3_hero_atk=a[1] ? a[1].cg_atk_stat.to_i : 0; @r3_hero_def=a[1] ? a[1].cg_def_stat.to_i : 0
        @r3_last_atk=a[2] ? a[2].cg_atk_stat.to_i : 0; @r3_last_def=a[2] ? a[2].cg_def_stat.to_i : 0
      end
    end
    def self.apply_test_speeds
      speeds=TEST_SPEEDS[current_round]||[]; (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_am,speeds[i]) if b&&speeds[i]!=nil}
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
      assert_true("Ability Batch AM defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability AM test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil"))
      assert_true("Ability AM ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s); assert_true("Ability AM enemy count=4",all_enemies.size==4,"actual="+all_enemies.size.to_s)
    end

    def self.finish_round_assertions
      assert_order; a=test_allies; e=all_enemies; r=current_round
      if r==1
        vr=records_for(ABILITY_VANGUARD,:vanguard)[-1]||{}; vok=!vr.empty?&&vr[:percent].to_i==150&&vr[:after].to_i>vr[:before].to_i; @damage_checks+=1 if vok; assert_true("Vanguard boosts the real first offensive action by 50%",vok,vr.inspect)
        grec=records_for(ABILITY_GULP,:gulp)[-1]||{}; hrec=records_for(ABILITY_HERBIVORE,:herbivore)[-1]||{}; lrec=records_for(ABILITY_LIFE_FORCE,:life_force)[-1]||{}
        [["Gulp Rain environment heals 1/8",e[0],@r1_hp[0],grec,ABILITY_GULP],["Herbivore Grassy Terrain heals 1/8",e[1],@r1_hp[1],hrec,ABILITY_HERBIVORE],["Life Force heals 1/8 every turn",e[3],@r1_hp[3],lrec,ABILITY_LIFE_FORCE]].each do |x|
          exp=x[1] ? [x[1].maxhp.to_i/RECOVERY_DENOM,1].max : 0; ok=x[1]&&x[1].hp.to_i-x[2].to_i==exp&&!x[3].empty?; @recovery_checks+=1 if ok; assert_true(x[0],ok,"heal="+(x[1] ? (x[1].hp.to_i-x[2].to_i).to_s : "nil")+" expected="+exp.to_s)
        end
        soff=records_for(ABILITY_SANDPIT,:sandpit).size==@r1_rec_counts[:s]; @scope_checks+=1 if soff; assert_true("Sandpit does not heal outside Sandstorm",soff,"trigger_count="+records_for(ABILITY_SANDPIT,:sandpit).size.to_s+" hp="+@r1_hp[2].to_s+"->"+(e[2] ? e[2].hp.to_i.to_s : "nil"))
      elsif r==2
        hok=@r2_hero_base_atk>0&&@r2_hero_atk==[@r2_hero_base_atk*HERO_PERCENT/100,1].max&&@r2_hero_def==[@r2_hero_base_def*HERO_PERCENT/100,1].max; @stat_checks+=1 if hok; assert_true("Hero struggling proxy grants ATK/DEF +1-stage equivalent",hok,"atk="+@r2_hero_base_atk.to_s+"->"+@r2_hero_atk.to_s+" def="+@r2_hero_base_def.to_s+"->"+@r2_hero_def.to_s+" active="+@r2_hero_own.to_s+"v"+@r2_hero_foe.to_s)
        lok=@r2_last_base_atk>0&&@r2_last_atk==[@r2_last_base_atk*LAST_BASTION_PERCENT/100,1].max&&@r2_last_def==[@r2_last_base_def*LAST_BASTION_PERCENT/100,1].max; @stat_checks+=1 if lok; assert_true("Last Bastion sole survivor grants ATK/DEF +2-stage equivalent",lok,"atk="+@r2_last_base_atk.to_s+"->"+@r2_last_atk.to_s+" def="+@r2_last_base_def.to_s+"->"+@r2_last_def.to_s)
        crec=records_for(ABILITY_CONQUEROR,:conqueror_ko)[-1]||{}; stacks=a[3] ? a[3].instance_variable_get(:@cg_v2538am_conqueror_kos).to_i : 0; cok=!crec.empty?&&stacks==1; @ko_checks+=1 if cok; assert_true("Conqueror gains one persistent stack after real KO",cok,"stack="+stacks.to_s+" record="+crec.inspect)
        ca=a[3] ? a[3].cg_atk_stat.to_i : 0; cd=a[3] ? a[3].cg_def_stat.to_i : 0; cs=a[3] ? a[3].cg_spe.to_i : 0; cp=120
        csok=@r2_conq_base_atk>0&&ca==[@r2_conq_base_atk*cp/100,1].max&&cd==[@r2_conq_base_def*cp/100,1].max&&cs==[@r2_conq_base_spe*cp/100,1].max; @stat_checks+=1 if csok; assert_true("Conqueror stack boosts ATK/DEF/SPE by additive 20%",csok,"atk="+@r2_conq_base_atk.to_s+"->"+ca.to_s+" def="+@r2_conq_base_def.to_s+"->"+cd.to_s+" spe="+@r2_conq_base_spe.to_s+"->"+cs.to_s)
        [[:sandpit,ABILITY_SANDPIT,e[2],@r2_e2_hp],[:life_force,ABILITY_LIFE_FORCE,e[3],@r2_e3_hp]].each do |kind,aid,b,before|
          rec=records_for(aid,kind)[-1]||{}; exp=b ? [b.maxhp.to_i/RECOVERY_DENOM,1].max : 0; ok=b&&b.hp.to_i-before.to_i==exp&&!rec.empty?; @recovery_checks+=1 if ok; assert_true((kind==:sandpit ? "Sandpit Sandstorm heals 1/8" : "Life Force continues to heal 1/8"),ok,"heal="+(b ? (b.hp.to_i-before.to_i).to_s : "nil")+" expected="+exp.to_s)
        end
      elsif r==3
        vno=records_for(ABILITY_VANGUARD,:vanguard).size==@r3_vanguard_count; @scope_checks+=1 if vno; assert_true("Vanguard does not boost when another battler acted first",vno,"trigger_count="+records_for(ABILITY_VANGUARD,:vanguard).size.to_s)
        [[:g,ABILITY_GULP,:gulp,0],[:h,ABILITY_HERBIVORE,:herbivore,1],[:s,ABILITY_SANDPIT,:sandpit,2]].each do |k,aid,kind,idx|
          ok=records_for(aid,kind).size==@r3_env_counts[k]&&e[idx]&&e[idx].hp.to_i==@r3_hp[idx]; @scope_checks+=1 if ok; assert_true(kind.to_s+" does not heal with clear environment",ok,"hp="+@r3_hp[idx].to_s+"->"+(e[idx] ? e[idx].hp.to_i.to_s : "nil"))
        end
        lrec=records_for(ABILITY_LIFE_FORCE,:life_force)[-1]||{}; lexp=e[3] ? [e[3].maxhp.to_i/RECOVERY_DENOM,1].max : 0; # E3 also takes A0 Water Gun, so validate recorded heal rather than net HP.
        lok=!lrec.empty?&&lrec[:heal].to_i==lexp; @recovery_checks+=1 if lok; assert_true("Life Force still heals 1/8 with no environment",lok,"record="+lrec.inspect+" expected="+lexp.to_s)
        hoff=a[1]&&a[1].cg_atk_stat.to_i==@r3_hero_atk&&a[1].cg_def_stat.to_i==@r3_hero_def; @stat_checks+=1 if hoff; assert_true("Hero deactivates when side is no longer struggling",hoff,"atk="+@r3_hero_atk.to_s+" def="+@r3_hero_def.to_s)
        loff=a[2]&&a[2].cg_atk_stat.to_i==@r3_last_atk&&a[2].cg_def_stat.to_i==@r3_last_def; @stat_checks+=1 if loff; assert_true("Last Bastion deactivates when allies are active",loff,"atk="+@r3_last_atk.to_s+" def="+@r3_last_def.to_s)
        stacks=a[3] ? a[3].instance_variable_get(:@cg_v2538am_conqueror_kos).to_i : 0; base_a=@r2_conq_base_atk; base_d=@r2_conq_base_def; base_s=@r2_conq_base_spe; ca=a[3] ? a[3].cg_atk_stat.to_i : 0; cd=a[3] ? a[3].cg_def_stat.to_i : 0; cs=a[3] ? a[3].cg_spe.to_i : 0
        persist=stacks==1&&ca==[base_a*120/100,1].max&&cd==[base_d*120/100,1].max&&cs==[base_s*120/100,1].max; @stat_checks+=1 if persist; assert_true("Conqueror 20% stack persists across later turns",persist,"stack="+stacks.to_s+" atk="+ca.to_s+" def="+cd.to_s+" spe="+cs.to_s)
      end
      log("ROUND "+r.to_s+" END"); @round_index=@round_index.to_i+1
    end

    def self.cleanup_test_overrides
      (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_am,nil) if b}; set_field(nil,0,nil,0)
    rescue; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|aid|ok=@ability_trigger_counts[aid].to_i>0; assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)}
      log("------------------------------------------------------------"); result=@failures.empty? ? "PASS" : "FAIL"; log("RESULT="+result); passed=0; HANDLED_ABILITY_IDS.each{|x|passed+=1 if @ability_trigger_counts[x].to_i>0}
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_am="+passed.to_s+"/8 recovery_checks="+@recovery_checks.to_s+" stat_checks="+@stat_checks.to_s+" damage_checks="+@damage_checks.to_s+" scope_checks="+@scope_checks.to_s+" ko_checks="+@ko_checks.to_s+" action_checks="+@action_checks.to_s+" pending=61")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @recovery_checks=0; @stat_checks=0; @damage_checks=0; @scope_checks=0; @ko_checks=0; @action_checks=0
    end
    def self.reset_log
      h="CG POKEMON ABILITY AM CONQUEST ENVIRONMENT + MOMENTUM AUTO REGRESSION v2.5.38\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; environment recovery + struggling stat + first action + KO momentum authority\r\n"+
        "BASELINE=v2.5.37a Ability Batch AL RPG Maker VX real-machine PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AL_PASS=304 BATCH_AM=8 PENDING=61\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue; end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; reset_battle_runtime; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AM_v2.5.38") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

ALBERT_CG::ABILITY_AM_V2538.register_handlers if defined?(ALBERT_CG::ABILITY_AM_V2538)

#==============================================================================
# ■ Formal Scene lifecycle + deterministic F11 harness
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2538am_start start
  def start
    ALBERT_CG::ABILITY_AM_V2538.reset_battle_runtime if defined?(ALBERT_CG::ABILITY_AM_V2538)
    cg_v2538am_start
  end
  alias cg_v2538am_execute_action execute_action
  def execute_action
    b=@active_battler
    if defined?(ALBERT_CG::ABILITY_AM_V2538)
      ALBERT_CG::ABILITY_AM_V2538.note_action_start(b)
      ALBERT_CG::ABILITY_AM_V2538.record_execution(b) if ALBERT_CG::ABILITY_AM_V2538.active?
    end
    cg_v2538am_execute_action
  end
  alias cg_v2538am_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AM_V2538)&&ALBERT_CG::ABILITY_AM_V2538.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_AM_V2538.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_AM_V2538.finish_round_assertions; end
    end
    cg_v2538am_turn_end
  end
  alias cg_v2538am_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AM_V2538)&&ALBERT_CG::ABILITY_AM_V2538.active?; return cg_v2538am_start_party_command; end
    cg_v2538am_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_AM_V2538.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AM_V2538.finished?; ALBERT_CG::ABILITY_AM_V2538.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_AM_V2538.prepare_round_actions; start_main
  end
end
class Game_Battler
  alias cg_v2538am_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AM_V2538)&&ALBERT_CG::ABILITY_AM_V2538.active?; v=@cg_priority_test_speed_override_am; return v.to_i if v!=nil; end
    cg_v2538am_priority_base_speed
  rescue; cg_v2538am_priority_base_speed; end
end
class Game_Enemy < Game_Battler
  alias cg_v2538am_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AM_V2538)&&ALBERT_CG::ABILITY_AM_V2538.active?; a=ALBERT_CG::ABILITY_AM_V2538.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end; end
    cg_v2538am_enemy_make_action
  end
end
module ALBERT_CG; class << self
  alias cg_v2538am_bootstrap_demo_party bootstrap_demo_party
  def bootstrap_demo_party
    r=cg_v2538am_bootstrap_demo_party
    if defined?(ALBERT_CG::ABILITY_AM_V2538)&&ALBERT_CG::ABILITY_AM_V2538.active?
      ALBERT_CG::ABILITY_AM_V2538::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AM_V2538.configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_AM_V2538::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,ALBERT_CG::ABILITY_AM_V2538::ABILITY_VANGUARD); end
    end
    r
  end
end; end

# Newest F11 only.
if defined?(ALBERT_CG::ABILITY_AL_V2537)
  module ALBERT_CG; module ABILITY_AL_V2537; def self.f11_trigger?; false; end; end; end
end
class Scene_Map < Scene_Base
  alias cg_v2538am_scene_map_update update
  def update
    cg_v2538am_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_AM_V2538); ALBERT_CG::ABILITY_AM_V2538.start_auto_test if ALBERT_CG::ABILITY_AM_V2538.f11_trigger?
  end
end
