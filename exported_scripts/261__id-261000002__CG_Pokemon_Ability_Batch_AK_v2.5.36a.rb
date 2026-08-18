# RMVX_SCRIPT_INDEX: 261
# RMVX_SCRIPT_ID: 261000002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AK v2.5.36a
# RMVX_SOURCE_SHA256: 5ed583f7f1519a48e3e37418253e3bb2be102af73f7dfc73cd2479fc84dc0ff9

#==============================================================================
# ■ CG Pokemon Ability Batch AK v2.5.36a - Threshold / Champions Passive Authority TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.35b Ability Batch AJ RPG Maker VX 實機 PASS 為唯一正式基底，新增 8 個
#  尚未覆蓋的主系列 Ability。集中收斂「莓果門檻、滿血防護、Protect 穿透、招式屬性
#  轉換、使用者局部日照、受擊反應、浮空 + KO 成長、屬性火力」到既有 Authority。
#
# 【本批 Ability】
#   82 Gluttony / 貪吃鬼：HP <= 50% 且持有 Berry 時，在真正受傷後自動食用。
#  305 Tera Shell / 太晶甲殼：滿 HP 時，直接傷害的有效屬性倍率最多視為本作 NVE=62%。
#  308 Piercing Drill / 貫穿鑽：接觸招式可穿過 Protect，但只造成原傷害 25%。
#  309 Dragonize / 龍皮膚：Normal damaging Move -> Dragon，傷害 x1.20。
#  310 Mega Sol / 超級日光：只有 holder 自己的招式按 Sun damage semantics 結算；不改 Field。
#  311 Spicy Spray / 辣椒噴發：受到敵方 Move 實傷後，對攻擊者施加 Burn。
#  312 Eelevate：視為浮空，Ground damaging Move 無效；自己真實 KO 後最高能力階級 +1。
#  313 Fire Mane：holder 的 Fire damaging Move 傷害 x1.50。
#
# 【專案適配】
#  1. Dragonize 沿用 Batch W 的 action-local @cg_v2522_type_override，不建立第二套 Move type。
#  2. Mega Sol 不建立假天氣；包既有 FIELD_V233.damage_percent，忽略場上 Rain/Sun 的
#     weather damage 段後只對 holder 自己套 Sun 的 Fire 150% / Water 50%。本專案目前
#     Solar Beam / Solar Blade 沒有獨立兩回合 charge runtime，因此沒有額外 charge bypass。
#  3. Tera Shell 不改永久 Type Chart；只在 defender :damage_modify 將本次直接傷害校正到
#     type_rate<=62 的等價傷害，滿血第一擊後自然失效，多段技能後續 hit 也會重新讀 HP。
#  4. Piercing Drill 沿用 Unseen Fist 已證實可行的 full-chain Protect 隱藏方式；只在本次
#     skill_effect 暫時移除 Protect flag/state，Action 結束立刻還原，傷害再由 attacker
#     :damage_modify 乘 25%。
#  5. Eelevate 同時延伸 FIELD_V233.grounded?；Spikes / Toxic Spikes / Sticky Web 因此自然
#     跳過，Ground Move 則仍由 Ability Core :before_hit 正式取消。
#  6. Gluttony 不建立第二套 inventory；直接呼叫 Held Item Core cg_consume_held_item。
#  7. Spicy Spray 使用既有 Ability Status Authority，尊重 Fire immunity / 主要異常衝突。
#  8. 本批所有 Ability effective ID 都走 Ability Core，尊重 Neutralizing Gas / suppression。
#
# 【F11】
#  Troop 739，三回合 Actual Scene_Battle：
#   R1：Fire Mane -> Tera Shell；Mega Sol Ember -> Gluttony 跨半血食 Berry；Dragonize
#       Tackle -> Spicy Spray holder，驗 Dragon +20% 與受傷反燒。
#   R2：Eelevate holder 先 Protect，Piercing Drill Aerial Ace 真正穿盾並只造成 25%。
#   R3：Earth Power -> Eelevate 0 damage；Eelevate Water Gun 真實 KO -> highest stat +1。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAK"] = "2.5.36a"

module ALBERT_CG
  module ABILITY_AK_V2536
    VERSION = "2.5.36a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 739
    VK_F11 = 0x7A

    ABILITY_GLUTTONY       = 82
    ABILITY_TERA_SHELL     = 305
    ABILITY_PIERCING_DRILL = 308
    ABILITY_DRAGONIZE      = 309
    ABILITY_MEGA_SOL       = 310
    ABILITY_SPICY_SPRAY    = 311
    ABILITY_EELEVATE       = 312
    ABILITY_FIRE_MANE      = 313
    HANDLED_ABILITY_IDS = [82,305,308,309,310,311,312,313]

    TEST_BERRY = 922
    TERA_SHELL_RATE = 62
    PIERCING_PERCENT = 25
    DRAGONIZE_PERCENT = 120
    SUN_FIRE_PERCENT = 150
    SUN_WATER_PERCENT = 50
    FIRE_MANE_PERCENT = 150

    TEST_ALLIES = [
      {:dex=>143,:level=>40,:ability=>ABILITY_GLUTTONY,       :moves=>[150,150,150]},
      {:dex=>65, :level=>40,:ability=>ABILITY_DRAGONIZE,      :moves=>[33,150,414]},
      {:dex=>18, :level=>40,:ability=>ABILITY_PIERCING_DRILL, :moves=>[150,332,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>45,:ability=>ABILITY_TERA_SHELL, :moves=>[150,150,150]},
      {:dex=>383,:level=>45,:ability=>ABILITY_MEGA_SOL,   :moves=>[52,150,150]},
      {:dex=>384,:level=>45,:ability=>ABILITY_SPICY_SPRAY,:moves=>[150,150,150]},
      {:dex=>92, :level=>45,:ability=>ABILITY_EELEVATE,   :moves=>[150,182,55]},
    ]

    ROUND_PLANS = [
      {:name=>"THRESHOLD_TYPE_REACTIVE",
       :allies=>[
         {:kind=>:move,:move_id=>52,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>33,:target=>2},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},
         1=>{:kind=>:move,:move_id=>52,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},
         3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"PIERCING_PROTECT",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>332,:target=>3}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},
         1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},
         3=>{:kind=>:move,:move_id=>182,:target=>3}}},
      {:name=>"EELEVATE_GROUND_KO",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>414,:target=>3},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},
         1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},
         3=>{:kind=>:move,:move_id=>55,:target=>0}}},
    ]

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:M52","A1:M150","A2:M33","A3:M150","E0:M150","E1:M52","E2:M150","E3:M150"],
      2=>["E3:M182","A0:M150","A1:M150","A2:M150","A3:M332","E0:M150","E1:M150","E2:M150"],
      3=>["A2:M414","A0:M150","A1:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M55"],
    }
    TEST_SPEEDS = {
      1=>[850,800,750,700,550,500,450,400],
      2=>[850,800,750,700,550,500,450,400],
      3=>[850,800,900,700,550,500,450,400],
    }

    begin
      KEY_API=Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API=nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.field; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233 : nil; end
    def self.held; defined?(ALBERT_CG::HELD_ITEM_V244) ? ALBERT_CG::HELD_ITEM_V244 : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AK_AutoTest_v2_5_36a.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill!=nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.ability_id(b); core&&b ? core.ability_id(b).to_i : 0; rescue; 0; end
    def self.type_id(key); defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_id(key).to_i : 0; rescue; 0; end
    def self.opposing?(a,b); a!=nil&&b!=nil&&a.actor?!=b.actor?; rescue; false; end
    def self.action_skill(ctx); a=ctx==nil ? nil : ctx[:action]; a!=nil&&a.skill? ? a.skill : nil; rescue; nil; end
    def self.base_skill_type_id(skill)
      return 0 if skill==nil
      return skill.cg_v2522w_base_type_id.to_i if skill.respond_to?(:cg_v2522w_base_type_id)
      return skill.cg_pokemon_type_id.to_i if skill.respond_to?(:cg_pokemon_type_id)
      0
    rescue; 0; end

    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else
        text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text)
      end
      condition
    end
    def self.note_local(aid,battler,kind,data=nil)
      rec={:ability=>aid.to_i,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill,:action].include?(k)}
      if active?
        @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1
        @records[aid.to_i]=[] if @records[aid.to_i]==nil; @records[aid.to_i].push(rec)
        log("ABILITY_AK_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect)
      end
      if core
        core.note_trigger(kind,battler,aid,data||{}) if core.respond_to?(:note_trigger)
        core.present_trigger(battler,aid,kind,data||{}) if core.respond_to?(:present_trigger)
      end
      rec
    rescue; nil; end
    def self.records_for(aid,kind=nil); a=@records[aid.to_i]||[]; return a if kind==nil; a.select{|x|x[:kind].to_sym==kind.to_sym}; rescue; []; end

    #--------------------------------------------------------------------------
    # Formal Ability handlers
    #--------------------------------------------------------------------------
    def self.apply_gluttony(holder,ctx)
      return false if holder==nil||ctx==nil||ctx[:damage_done].to_i<=0||holder.hp.to_i<=0
      return false unless holder.hp.to_i*2<=holder.maxhp.to_i
      item=holder.respond_to?(:cg_held_item) ? holder.cg_held_item : nil
      return false if item==nil||held==nil||!held.berry?(item)
      before_hp=holder.hp.to_i; item_id=item.id.to_i
      ok=holder.respond_to?(:cg_consume_held_item) ? holder.cg_consume_held_item(:gluttony_threshold,true) : false
      if ok
        note_local(ABILITY_GLUTTONY,holder,:gluttony,{:item_id=>item_id,:hp_before=>before_hp,:hp_after=>holder.hp.to_i,:threshold=>50})
      end
      ok
    rescue; false; end

    def self.apply_tera_shell(holder,ctx)
      return false if holder==nil||ctx==nil||ctx[:role]!=:defender||ctx[:fixed_damage]==true
      return false unless holder.hp.to_i>=holder.maxhp.to_i
      before=ctx[:damage].to_i; rate=ctx[:type_rate].to_i
      return false if before<=0||rate<=0||rate<=TERA_SHELL_RATE
      after=[before*TERA_SHELL_RATE/rate,1].max; ctx[:damage]=after
      note_local(ABILITY_TERA_SHELL,holder,:tera_shell,{:type_rate=>rate,:effective_rate=>TERA_SHELL_RATE,:before=>before,:after=>after})
      true
    rescue; false; end

    def self.apply_dragonize_before(holder,ctx)
      skill=action_skill(ctx); return false if holder==nil||skill==nil||skill.base_damage.to_i<=0
      base=base_skill_type_id(skill); return false unless base==type_id(:normal)
      skill.instance_variable_set(:@cg_v2522_type_override,type_id(:dragon))
      holder.instance_variable_set(:@cg_v2536ak_dragonize,true)
      note_local(ABILITY_DRAGONIZE,holder,:dragonize_type,{:move_id=>move_id(skill),:before_type=>base,:after_type=>type_id(:dragon)})
      true
    rescue; false; end
    def self.apply_dragonize_damage(holder,ctx)
      return false if holder==nil||ctx==nil||ctx[:role]!=:attacker||ctx[:fixed_damage]==true
      return false unless holder.instance_variable_get(:@cg_v2536ak_dragonize)==true
      before=ctx[:damage].to_i; return false if before<=0
      after=[before*DRAGONIZE_PERCENT/100,1].max; ctx[:damage]=after
      note_local(ABILITY_DRAGONIZE,holder,:dragonize_power,{:move_id=>ctx[:move_id].to_i,:before=>before,:after=>after,:percent=>DRAGONIZE_PERCENT})
      true
    rescue; false; end

    def self.apply_piercing_damage(holder,ctx)
      return false if holder==nil||ctx==nil||ctx[:role]!=:attacker||ctx[:fixed_damage]==true
      a=holder.respond_to?(:action) ? holder.action : nil; marks=a==nil ? nil : a.instance_variable_get(:@cg_v2536ak_piercing_targets)
      t=ctx[:target]; return false if marks==nil||t==nil||marks[t.object_id]!=true
      before=ctx[:damage].to_i; return false if before<=0
      after=[before*PIERCING_PERCENT/100,1].max; ctx[:damage]=after
      note_local(ABILITY_PIERCING_DRILL,holder,:piercing_damage,{:move_id=>ctx[:move_id].to_i,:before=>before,:after=>after,:percent=>PIERCING_PERCENT,:target_index=>t.index.to_i})
      true
    rescue; false; end

    def self.with_piercing_protect(target,user,skill)
      return yield if target==nil||user==nil||ability_id(user)!=ABILITY_PIERCING_DRILL||!opposing?(target,user)
      return yield unless core&&core.contact_action?(user)
      active=target.respond_to?(:cg_protect_active_v232b?) ? target.cg_protect_active_v232b? : false
      return yield unless active
      old_flag=target.instance_variable_get(:@cg_protect_v231); sid=nil; had_state=false
      if defined?(ALBERT_CG::MOVE_EFFECT)&&ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_PROTECT)
        sid=ALBERT_CG::MOVE_EFFECT::STATE_PROTECT; had_state=target.state?(sid)
      end
      target.instance_variable_set(:@cg_protect_v231,false); target.remove_state(sid) if sid!=nil&&had_state
      a=user.respond_to?(:action) ? user.action : nil
      if a!=nil
        marks=a.instance_variable_get(:@cg_v2536ak_piercing_targets); marks={} if marks==nil; marks[target.object_id]=true; a.instance_variable_set(:@cg_v2536ak_piercing_targets,marks)
      end
      note_local(ABILITY_PIERCING_DRILL,user,:piercing_drill,{:move_id=>move_id(skill),:target_index=>target.index.to_i,:protect=>true})
      result=nil
      begin
        result=yield
      ensure
        target.instance_variable_set(:@cg_protect_v231,old_flag)
        target.add_state(sid) if sid!=nil&&had_state&&!target.state?(sid)
      end
      result
    rescue
      yield
    end

    def self.apply_spicy_spray(holder,ctx)
      return false if holder==nil||ctx==nil||ctx[:damage_done].to_i<=0
      attacker=ctx[:user]; return false if attacker==nil||attacker.hp.to_i<=0||!opposing?(holder,attacker)
      sid=defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_BURN : 0; return false if sid.to_i<=0
      ok=false
      if defined?(ALBERT_CG::ABILITY_STATUS_V255)&&ALBERT_CG::ABILITY_STATUS_V255.respond_to?(:apply_status_from_ability)
        ok=ALBERT_CG::ABILITY_STATUS_V255.apply_status_from_ability(attacker,sid,holder,:spicy_spray)
      else
        attacker.add_state(sid); ok=attacker.state?(sid)
      end
      note_local(ABILITY_SPICY_SPRAY,holder,:spicy_spray,{:attacker_index=>attacker.index.to_i,:state_id=>sid}) if ok
      ok
    rescue; false; end

    def self.apply_eelevate_ground(holder,ctx)
      return false if holder==nil||ctx==nil||ctx[:skill]==nil||ctx[:user]==nil||!opposing?(holder,ctx[:user])
      skill=ctx[:skill]; return false unless skill.base_damage.to_i>0
      tid=skill.respond_to?(:cg_pokemon_type_id) ? skill.cg_pokemon_type_id.to_i : 0; return false unless tid==type_id(:ground)
      ctx[:cancel]=true; ctx[:hp_damage]=0
      note_local(ABILITY_EELEVATE,holder,:eelevate_ground,{:move_id=>ctx[:move_id].to_i})
      true
    rescue; false; end
    def self.highest_stat_key(b)
      pairs=[[:atk,b.cg_atk_stat.to_i],[:def,b.cg_def_stat.to_i],[:spa,b.cg_spa.to_i],[:spd,b.cg_spd.to_i],[:spe,b.cg_spe.to_i]]
      best=pairs[0]; pairs.each{|p|best=p if p[1]>best[1]}; best[0]
    rescue; :atk; end
    def self.change_stage(source,target,key,amount)
      return 0 if target==nil||!target.respond_to?(:cg_change_stat_stage)
      auth=defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) ? ALBERT_CG::ABILITY_STAT_GUARD_V256 : nil
      return auth.with_stage_source(source,:ability,false){target.cg_change_stat_stage(key,amount).to_i} if auth&&auth.respond_to?(:with_stage_source)
      target.cg_change_stat_stage(key,amount).to_i
    rescue; 0; end
    def self.apply_eelevate_ko(holder,ctx)
      return false if holder==nil||ctx==nil||ctx[:target]==nil||ctx[:target].hp.to_i>0
      key=highest_stat_key(holder); before=holder.cg_stat_stage(key).to_i; d=change_stage(holder,holder,key,1); after=holder.cg_stat_stage(key).to_i
      return false if d==0
      note_local(ABILITY_EELEVATE,holder,:eelevate_ko,{:stat=>key,:before=>before,:after=>after,:delta=>d})
      true
    rescue; false; end

    def self.apply_fire_mane(holder,ctx)
      return false if holder==nil||ctx==nil||ctx[:role]!=:attacker||ctx[:fixed_damage]==true||ctx[:type_id].to_i!=type_id(:fire)
      before=ctx[:damage].to_i; return false if before<=0; after=[before*FIRE_MANE_PERCENT/100,1].max; ctx[:damage]=after
      note_local(ABILITY_FIRE_MANE,holder,:fire_mane,{:move_id=>ctx[:move_id].to_i,:before=>before,:after=>after,:percent=>FIRE_MANE_PERCENT})
      true
    rescue; false; end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_GLUTTONY,:after_damage,self,:apply_gluttony)
      core.register(ABILITY_TERA_SHELL,:damage_modify,self,:apply_tera_shell)
      core.register(ABILITY_PIERCING_DRILL,:damage_modify,self,:apply_piercing_damage)
      core.register(ABILITY_DRAGONIZE,:before_action,self,:apply_dragonize_before)
      core.register(ABILITY_DRAGONIZE,:damage_modify,self,:apply_dragonize_damage)
      core.register(ABILITY_SPICY_SPRAY,:after_damage,self,:apply_spicy_spray)
      core.register(ABILITY_EELEVATE,:before_hit,self,:apply_eelevate_ground)
      core.register(ABILITY_EELEVATE,:after_ko,self,:apply_eelevate_ko)
      core.register(ABILITY_FIRE_MANE,:damage_modify,self,:apply_fire_mane)
      true
    end

    #--------------------------------------------------------------------------
    # TEST Harness
    #--------------------------------------------------------------------------
    def self.make_test_weapon(id,name,note)
      return nil if $data_weapons==nil; while $data_weapons.size<=id; $data_weapons.push(nil); end
      w=RPG::Weapon.new; w.id=id; w.name=name; w.note=note; w.icon_index=0; w.price=0; $data_weapons[id]=w; w
    end
    def self.install_test_item
      make_test_weapon(TEST_BERRY,"AK測試莓果","<CG_POKEMON_HELD_ITEM>\n<CG_BERRY>\n<CG_HELD_HEAL_HP:30>")
      held.sync_class_permissions if held&&held.respond_to?(:sync_class_permissions); true
    rescue; false; end
    def self.set_item(b,id)
      return false if b==nil||!b.respond_to?(:cg_set_battle_held_item); owner=b.respond_to?(:cg_held_item_owner_key) ? b.cg_held_item_owner_key : nil; b.cg_set_battle_held_item(id,owner)
    rescue; false; end
    def self.clear_runtime(b)
      return if b==nil; b.instance_variable_set(:@cg_v2536ak_dragonize,false); b.instance_variable_set(:@cg_priority_test_speed_override_ak,nil)
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
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); clear_runtime(h); h.instance_variable_set(:@cg_master_ability_id,ABILITY_FIRE_MANE); h.instance_variable_set(:@cg_equipped_skill_ids,[master.skill_id_for_move(52),master.skill_id_for_move(150)]); h.instance_variable_set(:@cg_skill_slot_ids,[master.skill_id_for_move(52),master.skill_id_for_move(150)]); h.instance_variable_set(:@skills,[master.skill_id_for_move(52),master.skill_id_for_move(150)]); end
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0]]
      ms=[]; TEST_ENEMIES.each_with_index{|c,i|configure_enemy(c); ms.push(ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]))}
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AK v2.5.36a AutoRegression",ms)
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
    def self.prepare_round_fixture
      a=test_allies; e=all_enemies; r=current_round
      if r==1
        install_test_item; set_item(a[1],TEST_BERRY) if a[1]
        if field
          st=field.state; st.weather=:rain; st.weather_turns=5
          @r1_field_weather=st.weather; @r1_field_weather_turns=st.weather_turns.to_i
          log("ROUND1_FIELD_SEED weather="+st.weather.to_s+" turns="+st.weather_turns.to_s)
        end
        if a[1]; a[1].hp=[a[1].maxhp.to_i/2+1,1].max; @r1_gluttony_hp=a[1].hp.to_i; @r1_gluttony_item=a[1].respond_to?(:cg_held_item_id) ? a[1].cg_held_item_id.to_i : 0; end
        e[0].hp=e[0].maxhp if e[0]; @r1_tera_hp=e[0] ? e[0].hp.to_i : 0
        if a[2]&&defined?(ALBERT_CG::MOVE_EFFECT); a[2].remove_state(ALBERT_CG::MOVE_EFFECT::STATE_BURN) if a[2].respond_to?(:remove_state); end
      elsif r==2
        e[3].recover_all if e[3]&&e[3].respond_to?(:recover_all); @r2_e3_hp=e[3] ? e[3].hp.to_i : 0; @r2_protect_blocks=e[3]&&e[3].respond_to?(:cg_protect_action_block_count_v232b) ? e[3].cg_protect_action_block_count_v232b.to_i : 0
      elsif r==3
        a[0].hp=1 if a[0]; e[3].recover_all if e[3]&&e[3].respond_to?(:recover_all); e[3].cg_reset_stat_stages if e[3]&&e[3].respond_to?(:cg_reset_stat_stages)
        @r3_e3_hp=e[3] ? e[3].hp.to_i : 0; @r3_key=e[3] ? highest_stat_key(e[3]) : :atk; @r3_stage=e[3] ? e[3].cg_stat_stage(@r3_key).to_i : 0
      end
    end
    def self.apply_test_speeds
      speeds=TEST_SPEEDS[current_round]||[]; list=test_allies+all_enemies; list.each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_ak,speeds[i]) if b&&speeds[i]!=nil}
    end
    def self.prepare_round_actions
      prepare_round_fixture; apply_test_speeds; @actual=[]; plan=current_plan; a=test_allies
      plan[:allies].each_with_index{|cfg,i|next if a[i]==nil; act=make_action(a[i],cfg); a[i].instance_variable_set(:@cg_round_actions,[act]); a[i].cg_assign_action(act) if a[i].respond_to?(:cg_assign_action); a[i].instance_variable_set(:@action,act) unless a[i].respond_to?(:cg_assign_action)}
      log("ROUND "+current_round.to_s+" BEGIN "+plan[:name].to_s)
    end
    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil"))
      assert_true("Ability Batch AK defines 8 handled IDs",HANDLED_ABILITY_IDS.uniq.size==8,"actual="+HANDLED_ABILITY_IDS.uniq.size.to_s)
      tid=($game_troop&&$game_troop.respond_to?(:troop)&&$game_troop.troop ? $game_troop.troop.id.to_i : 0); assert_true("Scene_Battle uses Ability AK test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability AK ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s); assert_true("Ability AK starts with 4 active enemies",all_enemies.select{|x|x&&!x.hidden}.size==4)
    end
    def self.assert_execution
      exp=EXPECTED_EXECUTION_TOKENS[current_round]||[]; ok=(@actual==exp); @action_checks+=1 if ok; assert_true("Round"+current_round.to_s+" execution order matches deterministic plan",ok,"expected="+exp.inspect+" actual="+@actual.inspect)
    end
    def self.assert_round
      a=test_allies; e=all_enemies; r=current_round; assert_execution
      if r==1
        fm=!records_for(ABILITY_FIRE_MANE,:fire_mane).empty?; @damage_checks+=1 if fm; assert_true("Fire Mane boosts real Fire Move",fm,(records_for(ABILITY_FIRE_MANE,:fire_mane)[-1]||{}).inspect)
        ts=!records_for(ABILITY_TERA_SHELL,:tera_shell).empty?&&e[0]&&e[0].hp.to_i<@r1_tera_hp; @defense_checks+=1 if ts; assert_true("Tera Shell caps full-HP direct hit to NVE-equivalent",ts,"hp="+@r1_tera_hp.to_s+"->"+(e[0] ? e[0].hp.to_i.to_s : "nil")+" record="+(records_for(ABILITY_TERA_SHELL,:tera_shell)[-1]||{}).inspect)
        grec=records_for(ABILITY_GLUTTONY,:gluttony)[-1]; gl=grec!=nil&&a[1]&&a[1].respond_to?(:cg_held_item_id)&&a[1].cg_held_item_id.to_i==0&&grec[:hp_after].to_i>grec[:hp_before].to_i; @item_checks+=1 if gl; assert_true("Gluttony consumes Berry after real damage at <=50% HP",gl,"record="+(grec||{}).inspect+" item="+(a[1]&&a[1].respond_to?(:cg_held_item_id) ? a[1].cg_held_item_id.to_i.to_s : "nil"))
        mrec=records_for(ABILITY_MEGA_SOL,:mega_sol)[-1]; field_ok=field&&field.state.weather==@r1_field_weather&&field.state.weather_turns.to_i==@r1_field_weather_turns.to_i; ms=mrec!=nil&&mrec[:type]==:fire&&mrec[:after].to_i>mrec[:before].to_i&&field_ok; @damage_checks+=1 if ms; assert_true("Mega Sol applies user-local Sun damage semantics while Rain Field remains unchanged",ms,"record="+(mrec||{}).inspect+" field="+(field ? field.state.weather.to_s+":"+field.state.weather_turns.to_s : "nil"))
        dz=!records_for(ABILITY_DRAGONIZE,:dragonize_type).empty?&&!records_for(ABILITY_DRAGONIZE,:dragonize_power).empty?; @type_checks+=1 if dz; assert_true("Dragonize converts real Normal Move to Dragon and boosts 20%",dz,"type="+(records_for(ABILITY_DRAGONIZE,:dragonize_type)[-1]||{}).inspect+" power="+(records_for(ABILITY_DRAGONIZE,:dragonize_power)[-1]||{}).inspect)
        burn=defined?(ALBERT_CG::MOVE_EFFECT)&&a[2]&&a[2].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN)&&!records_for(ABILITY_SPICY_SPRAY,:spicy_spray).empty?; @status_checks+=1 if burn; assert_true("Spicy Spray burns attacker after taking real Move damage",burn,"burn="+(a[2]&&defined?(ALBERT_CG::MOVE_EFFECT) ? a[2].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN).to_s : "nil"))
      elsif r==2
        pd=!records_for(ABILITY_PIERCING_DRILL,:piercing_drill).empty?&&!records_for(ABILITY_PIERCING_DRILL,:piercing_damage).empty?&&e[3]&&e[3].hp.to_i<@r2_e3_hp
        blocks=e[3]&&e[3].respond_to?(:cg_protect_action_block_count_v232b) ? e[3].cg_protect_action_block_count_v232b.to_i : @r2_protect_blocks
        pd=pd&&blocks==@r2_protect_blocks.to_i; @bypass_checks+=1 if pd; assert_true("Piercing Drill contact Move bypasses Protect at 25% damage",pd,"hp="+@r2_e3_hp.to_s+"->"+(e[3] ? e[3].hp.to_i.to_s : "nil")+" blocks="+@r2_protect_blocks.to_s+"->"+blocks.to_s)
      elsif r==3
        gi=!records_for(ABILITY_EELEVATE,:eelevate_ground).empty?&&e[3]&&e[3].hp.to_i<=@r3_e3_hp.to_i; @immunity_checks+=1 if gi; assert_true("Eelevate cancels Ground damaging Move",gi,(records_for(ABILITY_EELEVATE,:eelevate_ground)[-1]||{}).inspect)
        grounded=(field&&field.respond_to?(:grounded?)&&e[3]) ? field.grounded?(e[3]) : true; fl=!grounded; @immunity_checks+=1 if fl; assert_true("Eelevate holder is ungrounded for Field hazards/terrain",fl,"grounded="+grounded.to_s)
        ko=records_for(ABILITY_EELEVATE,:eelevate_ko)[-1]; kk=ko!=nil&&e[3]&&e[3].cg_stat_stage(@r3_key).to_i==@r3_stage.to_i+1; @ko_checks+=1 if kk; assert_true("Eelevate real KO raises highest stat stage +1",kk,"key="+@r3_key.to_s+" stage="+@r3_stage.to_s+"->"+(e[3] ? e[3].cg_stat_stage(@r3_key).to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end
    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_ak,nil) if b}; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|aid|ok=@ability_trigger_counts[aid].to_i>0; assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)}
      log("------------------------------------------------------------"); result=@failures.empty? ? "PASS" : "FAIL"; log("RESULT="+result); passed=0; HANDLED_ABILITY_IDS.each{|x|passed+=1 if @ability_trigger_counts[x].to_i>0}
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_ak="+passed.to_s+"/8 damage_checks="+@damage_checks.to_s+" defense_checks="+@defense_checks.to_s+" item_checks="+@item_checks.to_s+" type_checks="+@type_checks.to_s+" status_checks="+@status_checks.to_s+" bypass_checks="+@bypass_checks.to_s+" immunity_checks="+@immunity_checks.to_s+" ko_checks="+@ko_checks.to_s+" action_checks="+@action_checks.to_s+" pending=77")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite; @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @damage_checks=0; @defense_checks=0; @item_checks=0; @type_checks=0; @status_checks=0; @bypass_checks=0; @immunity_checks=0; @ko_checks=0; @action_checks=0; @r1_gluttony_hp=0; @r1_tera_hp=0; @r1_field_weather=nil; @r1_field_weather_turns=0; @r2_e3_hp=0; @r2_protect_blocks=0; @r3_e3_hp=0; @r3_key=:atk; @r3_stage=0; end
    def self.reset_log
      h="CG POKEMON ABILITY AK THRESHOLD + CHAMPIONS PASSIVE AUTO REGRESSION v2.5.36a\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; berry threshold + full-HP shell + protect pierce + type/weather/reactive/float/KO authority\r\n"+
        "BASELINE=v2.5.35b Ability Batch AJ RPG Maker VX real-machine PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AJ_PASS=288 BATCH_AK=8 PENDING=77\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue; end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AK_v2.5.36a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

ALBERT_CG::ABILITY_AK_V2536.register_handlers if defined?(ALBERT_CG::ABILITY_AK_V2536)

#==============================================================================
# ■ Formal Piercing Drill full-chain Protect bypass
#==============================================================================
class Game_Battler
  alias cg_v2536ak_skill_effect skill_effect
  def skill_effect(user,skill)
    if defined?(ALBERT_CG::ABILITY_AK_V2536)&&user!=nil&&ALBERT_CG::ABILITY_AK_V2536.ability_id(user)==ALBERT_CG::ABILITY_AK_V2536::ABILITY_PIERCING_DRILL
      return ALBERT_CG::ABILITY_AK_V2536.with_piercing_protect(self,user,skill){cg_v2536ak_skill_effect(user,skill)}
    end
    cg_v2536ak_skill_effect(user,skill)
  end
end

#==============================================================================
# ■ Formal Mega Sol: user-local Sun damage semantics, without Field mutation
#==============================================================================
if defined?(ALBERT_CG::FIELD_V233)
  module ALBERT_CG
    module FIELD_V233
      class << self
        alias cg_v2536ak_damage_percent damage_percent
        def damage_percent(user,target,skill,type_id,damage_class,move_id)
          ak=defined?(ALBERT_CG::ABILITY_AK_V2536) ? ALBERT_CG::ABILITY_AK_V2536 : nil
          if ak&&user!=nil&&ak.ability_id(user)==ak::ABILITY_MEGA_SOL
            st=state; sw=st.weather; sturn=st.weather_turns.to_i
            st.weather_turns=0
            base=cg_v2536ak_damage_percent(user,target,skill,type_id,damage_class,move_id)
            st.weather=sw; st.weather_turns=sturn
            key=defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_key(type_id) : nil
            after=base.to_i
            after=after*ak::SUN_FIRE_PERCENT/100 if key==:fire
            after=after*ak::SUN_WATER_PERCENT/100 if key==:water
            if key==:fire||key==:water
              a=user.respond_to?(:action) ? user.action : nil
              unless a!=nil&&a.instance_variable_get(:@cg_v2536ak_mega_sol_noted)==true
                a.instance_variable_set(:@cg_v2536ak_mega_sol_noted,true) if a!=nil
                ak.note_local(ak::ABILITY_MEGA_SOL,user,:mega_sol,{:move_id=>move_id.to_i,:type=>key,:before=>base.to_i,:after=>after})
              end
            end
            return after
          end
          cg_v2536ak_damage_percent(user,target,skill,type_id,damage_class,move_id)
        rescue
          begin; st.weather=sw; st.weather_turns=sturn if st!=nil; rescue; end
          cg_v2536ak_damage_percent(user,target,skill,type_id,damage_class,move_id)
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal Eelevate: Field grounded bridge
#==============================================================================
if defined?(ALBERT_CG::FIELD_V233)
  module ALBERT_CG
    module FIELD_V233
      class << self
        alias cg_v2536ak_grounded grounded?
        def grounded?(battler)
          if defined?(ALBERT_CG::ABILITY_AK_V2536)&&battler!=nil&&ALBERT_CG::ABILITY_AK_V2536.ability_id(battler)==ALBERT_CG::ABILITY_AK_V2536::ABILITY_EELEVATE
            return false
          end
          cg_v2536ak_grounded(battler)
        rescue; cg_v2536ak_grounded(battler); end
      end
    end
  end
end

#==============================================================================
# ■ Scene / deterministic F11 harness
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2536ak_execute_action execute_action
  def execute_action
    b=@active_battler
    a=(b&&b.respond_to?(:action)) ? b.action : nil
    ALBERT_CG::ABILITY_AK_V2536.record_execution(b) if defined?(ALBERT_CG::ABILITY_AK_V2536)&&ALBERT_CG::ABILITY_AK_V2536.active?
    begin
      cg_v2536ak_execute_action
    ensure
      if b!=nil
        b.instance_variable_set(:@cg_v2536ak_dragonize,false)
        a.instance_variable_set(:@cg_v2536ak_piercing_targets,nil) if a!=nil
        a.instance_variable_set(:@cg_v2536ak_mega_sol_noted,nil) if a!=nil
      end
    end
  end
  alias cg_v2536ak_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AK_V2536)&&ALBERT_CG::ABILITY_AK_V2536.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_AK_V2536.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_AK_V2536.finish_round_assertions; end
    end
    cg_v2536ak_turn_end
  end
  alias cg_v2536ak_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AK_V2536)&&ALBERT_CG::ABILITY_AK_V2536.active?; return cg_v2536ak_start_party_command; end
    cg_v2536ak_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_AK_V2536.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AK_V2536.finished?; ALBERT_CG::ABILITY_AK_V2536.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_AK_V2536.prepare_round_actions; start_main
  end
end
class Game_Battler
  alias cg_v2536ak_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AK_V2536)&&ALBERT_CG::ABILITY_AK_V2536.active?; v=@cg_priority_test_speed_override_ak; return v.to_i if v!=nil; end
    cg_v2536ak_priority_base_speed
  rescue; cg_v2536ak_priority_base_speed; end
end
class Game_Enemy < Game_Battler
  alias cg_v2536ak_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AK_V2536)&&ALBERT_CG::ABILITY_AK_V2536.active?; a=ALBERT_CG::ABILITY_AK_V2536.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end; end
    cg_v2536ak_enemy_make_action
  end
end
module ALBERT_CG; class << self
  alias cg_v2536ak_bootstrap_demo_party bootstrap_demo_party
  def bootstrap_demo_party
    r=cg_v2536ak_bootstrap_demo_party
    if defined?(ALBERT_CG::ABILITY_AK_V2536)&&ALBERT_CG::ABILITY_AK_V2536.active?
      ALBERT_CG::ABILITY_AK_V2536::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AK_V2536.configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_AK_V2536::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,ALBERT_CG::ABILITY_AK_V2536::ABILITY_FIRE_MANE); end
    end
    r
  end
end; end

# Newest F11 only.
if defined?(ALBERT_CG::ABILITY_AJ_V2535)
  module ALBERT_CG; module ABILITY_AJ_V2535; def self.f11_trigger?; false; end; end; end
end
class Scene_Map < Scene_Base
  alias cg_v2536ak_scene_map_update update
  def update
    cg_v2536ak_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_AK_V2536); ALBERT_CG::ABILITY_AK_V2536.start_auto_test if ALBERT_CG::ABILITY_AK_V2536.f11_trigger?
  end
end
