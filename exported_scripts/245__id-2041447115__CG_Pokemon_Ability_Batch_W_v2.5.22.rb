# RMVX_SCRIPT_INDEX: 245
# RMVX_SCRIPT_ID: 2041447115
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch W v2.5.22
# RMVX_SOURCE_SHA256: 2eb001f7893ec28d36d3b802e66b6e4cfecbc10d55df7189e0511b5b2ff849bb

#==============================================================================
# ■ CG Pokemon Ability Batch W v2.5.22 - Move Type Conversion + Type Shift TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.21 Ability Batch V RPG Maker VX 實機 PASS 為唯一基底，實作第二十三批
#  8 個 Ability。本批集中處理「招式屬性轉換」與「使用招式前自身屬性切換」，沿用
#  既有 Pokémon Type Chart / STAB / Ability Damage Modifier / Battle-only Type Override。
#  不修改 Move 937/937、Combat Core 傷害公式、Action Priority 或既有 PASS Ability。
#
# 【本批 Ability】
#   96 Normalize    一般皮膚：holder 的招式轉為 Normal；傷害招式 x1.20。
#  168 Protean      變幻自如：每次進場一次，出招前自身轉成該招式屬性。
#  174 Refrigerate  冰凍皮膚：Normal 招式轉 Ice；傷害 x1.20。
#  182 Pixilate     妖精皮膚：Normal 招式轉 Fairy；傷害 x1.20。
#  184 Aerilate     飛行皮膚：Normal 招式轉 Flying；傷害 x1.20。
#  204 Liquid Voice 濕潤之聲：Sound Move 轉 Water；不額外增傷。
#  206 Galvanize    電氣皮膚：Normal 招式轉 Electric；傷害 x1.20。
#  236 Libero       自由者：每次進場一次，出招前自身轉成該招式屬性。
#
# 【主要設定項】
#  TEST_TROOP_ID=725；HANDLED_ABILITY_IDS=8。
#  Coverage：176/373 -> 184/373，pending 197 -> 189。
#  CONVERSION_POWER_PERCENT=120。
#
# 【機制規則】
#  1. Move Type Conversion 不永久修改 RPG::Skill / Master Data。:before_action 只在該次
#     Action 對 skill 設定 @cg_v2522_type_override；Scene_Battle action 完成後 ensure 清除。
#  2. Combat Core 原本直接讀 skill.cg_pokemon_type_id，因此 override 會自然流入 STAB、
#     Type Chart、before_hit、damage_modify 等既有正式 Runtime，不平行重算屬性相剋。
#  3. Normalize 對可解析 Pokémon type 的招式轉 Normal；Refrigerate/Pixilate/Aerilate/
#     Galvanize 僅轉原本 Normal；Liquid Voice 只使用已 PASS Soundproof 共用 sound_move?。
#  4. 五個有 power boost 的皮膚類 Ability 只在 :damage_modify attacker role 對正傷害
#     x1.20；Fixed Damage 不吃倍率。Liquid Voice 僅轉 type，不加倍率。
#  5. Protean / Libero 使用既有 cg_v237_set_types，採「每次進場最多一次」token；若
#     holder 已是單一相同屬性則不消耗 token。entry/switch-in 會重置 token。
#  6. Battle-only Type Override 仍會在既有 battle cleanup 清除；本頁不改 Species base type。
#  7. F11 Regression 使用 Actual Scene_Battle；Round2 E3 Teleport 換入 hidden Libero E4，
#     Storage 不可被當 battle reserve 消耗。
#  8. TEST Convenience 僅限 F11；正式 Release 恢復 emerged、BGM/BGS、正常焦點。
#
# 【可調參數】
#  CONVERSION_POWER_PERCENT、TEST_SPEEDS、ROUND_PLANS、TEST_TROOP_ID。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，自動進 troop 725，跑三回合並輸出
#  Pokemon_Ability_W_AutoTest_v2_5_22.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：Water Gun + Normalize -> Normal x1.20；Tackle 分別經 Refrigerate/Pixilate/
#          Aerilate/Galvanize 轉屬性 x1.20；Hyper Voice + Liquid Voice -> Water；
#          Protean + Water Gun -> holder 轉 Water。
#  Round2：Protean holder 使用 Teleport，按正式 priority 最後換入 hidden Libero reserve。
#  Round3：Libero reserve 使用 Ember，出招前 holder 轉 Fire。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchW"] = "2.5.22"

module ALBERT_CG
  module ABILITY_W_V2522
    VERSION = "2.5.22"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 725
    VK_F11 = 0x7A

    ABILITY_NORMALIZE    = 96
    ABILITY_PROTEAN      = 168
    ABILITY_REFRIGERATE  = 174
    ABILITY_PIXILATE     = 182
    ABILITY_AERILATE     = 184
    ABILITY_LIQUID_VOICE = 204
    ABILITY_GALVANIZE    = 206
    ABILITY_LIBERO       = 236
    HANDLED_ABILITY_IDS = [96,168,174,182,184,204,206,236]

    CONVERSION_POWER_PERCENT = 120
    CONVERSION_ABILITIES = [96,174,182,184,204,206]
    BOOST_ABILITIES = [96,174,182,184,206]
    SHIFT_ABILITIES = [168,236]

    TEST_ALLIES = [
      {:dex=>25, :level=>40,:ability=>ABILITY_NORMALIZE,   :moves=>[55,150,150,150]},
      {:dex=>65, :level=>40,:ability=>ABILITY_REFRIGERATE, :moves=>[33,150,150,150]},
      {:dex=>128,:level=>40,:ability=>ABILITY_PIXILATE,    :moves=>[33,150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>60,:ability=>ABILITY_AERILATE,     :moves=>[33,150,150,150]},
      {:dex=>94, :level=>60,:ability=>ABILITY_GALVANIZE,    :moves=>[33,150,150,150]},
      {:dex=>91, :level=>60,:ability=>ABILITY_LIQUID_VOICE, :moves=>[304,150,150,150]},
      {:dex=>109,:level=>60,:ability=>ABILITY_PROTEAN,      :moves=>[55,100,150,150]},
      {:dex=>197,:level=>60,:ability=>ABILITY_LIBERO,       :moves=>[150,150,52,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"TYPE_CONVERSION_AND_PROTEAN",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>55,:target=>0},
          {:kind=>:move,:move_id=>33,:target=>0},
          {:kind=>:move,:move_id=>33,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>33,:target=>1},
          1=>{:kind=>:move,:move_id=>33,:target=>2},
          2=>{:kind=>:move,:move_id=>304,:target=>3},
          3=>{:kind=>:move,:move_id=>55,:target=>1},
        }
      },
      {
        :name=>"PROTEAN_SWITCH_LIBERO_IN",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>100,:target=>3},
        }
      },
      {
        :name=>"LIBERO_FIRE_SHIFT_STABILITY",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>52,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,300,290,280, 270,260,250,240,0],
      :r2=>[10,300,290,280, 270,260,250,240,0],
      :r3=>[10,260,250,240, 230,220,210,0,320],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M55","A2:M33","A3:M33","E0:M33","E1:M33","E2:M304","E3:M55"],
      2=>["A0:Guard","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","E4:M52","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_W_AutoTest_v2_5_22.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end

    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else
        text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text)
      end
      condition
    end

    def self.reset_log
      h="CG POKEMON ABILITY W MOVE TYPE CONVERSION + TYPE SHIFT AUTO REGRESSION v2.5.22\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; action-local move type conversion + Protean/Libero type shift lifecycle\r\n"+
        "BASELINE=v2.5.21 Ability Batch V Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_V_PASS=176 BATCH_W=8 PENDING=189\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue
    end

    def self.ability_id(b); core==nil || b==nil ? 0 : core.ability_id(b).to_i; rescue; 0; end
    def self.ratio(v,num,den); x=v.to_i; return x if x<=0; y=x*num.to_i/den.to_i; y=1 if y<1; y; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill!=nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.type_id(sym); defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_id(sym).to_i : 0; rescue; 0; end
    def self.type_key(id); defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_key(id) : nil; rescue; nil; end
    def self.base_skill_type_id(skill)
      return 0 if skill==nil
      return skill.cg_v2522w_base_type_id.to_i if skill.respond_to?(:cg_v2522w_base_type_id)
      return skill.cg_pokemon_type_id.to_i if skill.respond_to?(:cg_pokemon_type_id)
      0
    rescue
      0
    end
    def self.sound_move?(mid)
      return ALBERT_CG::ABILITY_SECONDARY_V2510.sound_move?(mid.to_i) if defined?(ALBERT_CG::ABILITY_SECONDARY_V2510)&&ALBERT_CG::ABILITY_SECONDARY_V2510.respond_to?(:sound_move?)
      false
    rescue
      false
    end

    def self.resolved_type_for(holder,skill)
      base=base_skill_type_id(skill); aid=ability_id(holder); mid=move_id(skill)
      return type_id(:normal) if aid==ABILITY_NORMALIZE && base>0
      return type_id(:ice) if aid==ABILITY_REFRIGERATE && base==type_id(:normal)
      return type_id(:fairy) if aid==ABILITY_PIXILATE && base==type_id(:normal)
      return type_id(:flying) if aid==ABILITY_AERILATE && base==type_id(:normal)
      return type_id(:water) if aid==ABILITY_LIQUID_VOICE && sound_move?(mid)
      return type_id(:electric) if aid==ABILITY_GALVANIZE && base==type_id(:normal)
      base
    rescue
      base_skill_type_id(skill)
    end

    def self.note_local(aid,battler,kind,data=nil)
      return true unless active?
      @ability_trigger_counts[aid]=@ability_trigger_counts[aid].to_i+1
      rec={:ability=>aid,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless k==:battler||k==:user||k==:target||k==:skill}
      @records[aid]=[] if @records[aid]==nil; @records[aid].push(rec)
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
      log("ABILITY_W_TRIGGER ability="+aid.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
      true
    rescue
      false
    end

    def self.formal_note(aid,holder,kind,ctx=nil)
      data=ctx||{}
      if core
        core.note_trigger(kind,holder,aid,data) if core.respond_to?(:note_trigger)
        core.present_trigger(holder,aid,kind,data) if core.respond_to?(:present_trigger)
      end
      note_local(aid,holder,kind,data)
      true
    rescue
      true
    end

    def self.action_skill(ctx)
      a=ctx==nil ? nil : ctx[:action]
      return nil if a==nil || !a.skill?
      a.skill
    rescue
      nil
    end

    def self.apply_conversion_before_action(holder,ctx)
      skill=action_skill(ctx); return false if holder==nil || skill==nil
      aid=ability_id(holder); return false unless CONVERSION_ABILITIES.include?(aid)
      base=base_skill_type_id(skill); resolved=resolved_type_for(holder,skill)
      return false if base<=0 || resolved<=0 || resolved==base
      skill.instance_variable_set(:@cg_v2522_type_override,resolved)
      holder.instance_variable_set(:@cg_v2522_action_original_type,base)
      holder.instance_variable_set(:@cg_v2522_action_resolved_type,resolved)
      formal_note(aid,holder,:type_convert,{:move_id=>move_id(skill),:before_type=>base,:after_type=>resolved})
      true
    end

    def self.apply_conversion_damage(holder,ctx)
      return false if holder==nil || ctx[:role]!=:attacker || ctx[:fixed_damage]==true
      aid=ability_id(holder); return false unless CONVERSION_ABILITIES.include?(aid)
      base=holder.instance_variable_get(:@cg_v2522_action_original_type).to_i
      resolved=holder.instance_variable_get(:@cg_v2522_action_resolved_type).to_i
      return false if base<=0 || resolved<=0 || ctx[:type_id].to_i!=resolved
      before=ctx[:damage].to_i; return false if before<=0
      after=BOOST_ABILITIES.include?(aid) ? ratio(before,CONVERSION_POWER_PERCENT,100) : before
      ctx[:damage]=after
      formal_note(aid,holder,:type_damage,{:move_id=>ctx[:move_id].to_i,:before_type=>base,:type_id=>resolved,:before=>before,:after=>after,:boosted=>BOOST_ABILITIES.include?(aid)})
      true
    end

    def self.reset_shift_token(holder,ctx)
      return false if holder==nil
      holder.instance_variable_set(:@cg_v2522_shift_used,false)
      false
    rescue
      false
    end

    def self.apply_type_shift(holder,ctx)
      return false if holder==nil || holder.instance_variable_get(:@cg_v2522_shift_used)==true
      skill=action_skill(ctx); return false if skill==nil
      tid=base_skill_type_id(skill); key=type_key(tid); return false if tid<=0 || key==nil
      before=holder.respond_to?(:cg_pokemon_types) ? holder.cg_pokemon_types.clone : []
      return false if before==[key]
      return false unless holder.respond_to?(:cg_v237_set_types)
      holder.cg_v237_set_types([key])
      holder.instance_variable_set(:@cg_v2522_shift_used,true)
      aid=ability_id(holder); kind=(aid==ABILITY_PROTEAN ? :protean_shift : :libero_shift)
      formal_note(aid,holder,kind,{:move_id=>move_id(skill),:type_id=>tid,:before=>before.inspect,:after=>holder.cg_pokemon_types.inspect})
      true
    end

    def self.register_handlers
      return false if core==nil
      CONVERSION_ABILITIES.each do |aid|
        core.register(aid,:before_action,self,:apply_conversion_before_action)
        core.register(aid,:damage_modify,self,:apply_conversion_damage)
      end
      SHIFT_ABILITIES.each do |aid|
        core.register(aid,:entry,self,:reset_shift_token)
        core.register(aid,:before_action,self,:apply_type_shift)
      end
      true
    end

    def self.clear_action_override(battler,skill)
      skill.instance_variable_set(:@cg_v2522_type_override,nil) if skill!=nil
      if battler!=nil
        battler.instance_variable_set(:@cg_v2522_action_original_type,nil)
        battler.instance_variable_set(:@cg_v2522_action_resolved_type,nil)
      end
    rescue
    end

    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime); a.instance_variable_set(:@cg_v2522_shift_used,false)
    end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end
    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}; ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true); $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each{|c|configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); end
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1]]
      ms=[]; TEST_ENEMIES.each_with_index do |c,i|; configure_enemy(c); m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=(i>=4); ms.push(m); end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability W v2.5.22 AutoRegression",ms)
    end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); else; a.clear; end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c); end
    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||TEST_SPEEDS[:r1]||[]
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_w,vals[i]) if b}
    end
    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end
    def self.clear_round_states
      (test_allies+all_enemies).each do |b|
        next if b==nil || b.hp.to_i<=0
        b.recover_all if b.respond_to?(:recover_all)
        b.cg_reset_stat_stages if b.respond_to?(:cg_reset_stat_stages)
      end
    rescue
    end
    def self.prepare_round_preconditions
      clear_round_states; apply_test_speeds; e=all_enemies
      @r2_storage_before=storage_size if current_round==2
    end
    def self.prepare_round_actions
      p=current_plan; return false if p==nil; prepare_round_preconditions; @actual=[]; log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s)
      test_allies.each_with_index do |b,i|; next if b==nil||b.hp.to_i<=0; ac=make_action(b,p[:allies][i]); if b.respond_to?(:cg_round_actions); b.cg_round_actions.clear; b.cg_round_actions.push(ac); end; b.cg_assign_action(ac) if b.respond_to?(:cg_assign_action); b.instance_variable_set(:@action,ac) unless b.respond_to?(:cg_assign_action); end; true
    end
    def self.record_execution(b)
      return unless active?&&b
      a=b.action; pre=b.actor? ? "A" : "E"; tok=if a&&a.guard?; pre+b.index.to_s+":Guard" elsif a&&a.skill?; pre+b.index.to_s+":M"+ALBERT_CG::MOVE_EFFECT.move_id(a.skill).to_i.to_s else; pre+b.index.to_s+":Other" end; @actual.push(tok); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    rescue
    end
    def self.records_for(aid,kind=nil); a=@records[aid]||[]; a.select{|r|kind==nil||r[:kind]==kind}; end
    def self.ratio_record?(aid,num,den)
      records_for(aid,:type_damage).any?{|r|r[:before].to_i>0 && r[:after].to_i==ratio(r[:before],num,den)}
    end
    def self.type_record?(aid,tid)
      records_for(aid,:type_damage).any?{|r|r[:type_id].to_i==tid.to_i}
    end

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      tid=($game_troop&&$game_troop.troop) ? $game_troop.troop.id.to_i : 0
      assert_true("Ability Catalog count=373",core&&core.catalog_count==373,"actual="+(core ? core.catalog_count.to_s : "nil"))
      assert_true("Ability Batch W defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability W test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability W ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability W starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden},"")
      assert_true("Ability W starts with 1 hidden Libero reserve",all_enemies[4]&&all_enemies[4].hidden,"E4_hidden="+(all_enemies[4] ? all_enemies[4].hidden.to_s : "nil"))
    end

    def self.assert_round
      r=current_round; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]; order=@actual==exp
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",order,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        checks=[
          [ABILITY_NORMALIZE,type_id(:normal),"Normalize converts Water Gun to Normal"],
          [ABILITY_REFRIGERATE,type_id(:ice),"Refrigerate converts Tackle to Ice"],
          [ABILITY_PIXILATE,type_id(:fairy),"Pixilate converts Tackle to Fairy"],
          [ABILITY_AERILATE,type_id(:flying),"Aerilate converts Tackle to Flying"],
          [ABILITY_GALVANIZE,type_id(:electric),"Galvanize converts Tackle to Electric"],
          [ABILITY_LIQUID_VOICE,type_id(:water),"Liquid Voice converts Hyper Voice to Water"],
        ]
        checks.each do |x|
          ok=type_record?(x[0],x[1]); @conversion_checks+=1 if ok; assert_true(x[2],ok,(records_for(x[0],:type_damage)[-1]||{}).inspect)
        end
        BOOST_ABILITIES.each do |aid|
          ok=ratio_record?(aid,CONVERSION_POWER_PERCENT,100); @power_checks+=1 if ok; assert_true("Ability "+aid.to_s+" converted damage x1.20",ok,(records_for(aid,:type_damage)[-1]||{}).inspect)
        end
        liq=records_for(ABILITY_LIQUID_VOICE,:type_damage).any?{|q|q[:before].to_i>0&&q[:after].to_i==q[:before].to_i}
        assert_true("Liquid Voice changes type without extra power multiplier",liq,(records_for(ABILITY_LIQUID_VOICE,:type_damage)[-1]||{}).inspect)
        p=e[3]; ptypes=p&&p.respond_to?(:cg_pokemon_types) ? p.cg_pokemon_types : []
        pok=!records_for(ABILITY_PROTEAN,:protean_shift).empty? && ptypes==[:water]
        @shift_checks+=1 if pok; assert_true("Protean changes holder to Water before Water Gun",pok,"types="+ptypes.inspect+" record="+(records_for(ABILITY_PROTEAN,:protean_shift)[-1]||{}).inspect)
      elsif r==2
        switched=e[3]&&e[4]&&e[3].hidden&&!e[4].hidden; @lifecycle_checks+=1 if switched; assert_true("Teleport deploys hidden Libero reserve",switched,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        storage=storage_size==@r2_storage_before.to_i; @lifecycle_checks+=1 if storage; assert_true("Libero reserve switch does not consume Storage Pokemon",storage,"before="+@r2_storage_before.to_s+" after="+storage_size.to_s)
      elsif r==3
        l=e[4]; ltypes=l&&l.respond_to?(:cg_pokemon_types) ? l.cg_pokemon_types : []
        lok=!records_for(ABILITY_LIBERO,:libero_shift).empty? && ltypes==[:fire]
        @shift_checks+=1 if lok; assert_true("Libero changes reserve to Fire before Ember",lok,"types="+ltypes.inspect+" record="+(records_for(ABILITY_LIBERO,:libero_shift)[-1]||{}).inspect)
        stable=l&&!l.hidden&&l.hp.to_i>0; assert_true("Libero reserve remains active through Round3",stable,"E4_hidden="+(l ? l.hidden.to_s : "nil")+" hp="+(l ? l.hp.to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end

    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides
      (test_allies+all_enemies).each do |b|
        next if b==nil
        b.instance_variable_set(:@cg_priority_test_speed_override_w,nil)
        b.instance_variable_set(:@cg_v2522_action_original_type,nil)
        b.instance_variable_set(:@cg_v2522_action_resolved_type,nil)
      end
    end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"; log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_w="+ability_covered_count.to_s+"/8 conversion_checks="+@conversion_checks.to_i.to_s+" power_checks="+@power_checks.to_i.to_s+" shift_checks="+@shift_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=189")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @conversion_checks=0; @power_checks=0; @shift_checks=0; @lifecycle_checks=0; @r2_storage_before=0
    end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; ALBERT_CG::UNIQUE_I_V242.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_I_V242)&&ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes); @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_W_v2.5.22") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

ALBERT_CG::ABILITY_W_V2522.register_handlers if defined?(ALBERT_CG::ABILITY_V250)
if defined?(ALBERT_CG::ABILITY_V_V2521)
  module ALBERT_CG; module ABILITY_V_V2521; def self.f11_trigger?; false; end; end; end
end

#==============================================================================
# ■ Formal Action-local Move Type Override
#==============================================================================
class RPG::Skill
  alias cg_v2522w_base_type_id cg_pokemon_type_id
  def cg_pokemon_type_id
    v=@cg_v2522_type_override
    return v.to_i if v!=nil && v.to_i>0
    cg_v2522w_base_type_id
  end
end

#==============================================================================
# ■ TEST-only deterministic Scene_Battle harness + action override cleanup
#==============================================================================
class Game_Battler
  alias cg_v2522w_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil); return 100 if defined?(ALBERT_CG::ABILITY_W_V2522)&&ALBERT_CG::ABILITY_W_V2522.active?; cg_v2522w_ability_calc_hit(user,obj); end
  alias cg_v2522w_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil); return 0 if defined?(ALBERT_CG::ABILITY_W_V2522)&&ALBERT_CG::ABILITY_W_V2522.active?; cg_v2522w_ability_calc_eva(user,obj); end
  alias cg_v2522w_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_W_V2522)&&ALBERT_CG::ABILITY_W_V2522.active?
      v=@cg_priority_test_speed_override_w; return v.to_i if v!=nil
    end
    cg_v2522w_ability_priority_base_speed
  rescue
    cg_v2522w_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2522w_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_W_V2522)&&ALBERT_CG::ABILITY_W_V2522.active?
      a=ALBERT_CG::ABILITY_W_V2522.forced_enemy_action(self)
      if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end
    end
    cg_v2522w_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2522w_ability_execute_action execute_action
  def execute_action
    b=@active_battler
    skill=(b&&b.action&&b.action.skill?) ? b.action.skill : nil
    ALBERT_CG::ABILITY_W_V2522.record_execution(b) if defined?(ALBERT_CG::ABILITY_W_V2522)&&ALBERT_CG::ABILITY_W_V2522.active?
    begin
      cg_v2522w_ability_execute_action
    ensure
      ALBERT_CG::ABILITY_W_V2522.clear_action_override(b,skill) if defined?(ALBERT_CG::ABILITY_W_V2522)
    end
  end
  alias cg_v2522w_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_W_V2522)&&ALBERT_CG::ABILITY_W_V2522.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_W_V2522.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_W_V2522.finish_round_assertions; end
    end
    cg_v2522w_ability_turn_end
  end
  alias cg_v2522w_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_W_V2522)&&ALBERT_CG::ABILITY_W_V2522.active?; return cg_v2522w_ability_start_party_command; end
    cg_v2522w_ability_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_W_V2522.assert_bootstrap_once
    if ALBERT_CG::ABILITY_W_V2522.finished?; ALBERT_CG::ABILITY_W_V2522.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_W_V2522.prepare_round_actions; start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2522w_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2522w_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_W_V2522)&&ALBERT_CG::ABILITY_W_V2522.active?
        ALBERT_CG::ABILITY_W_V2522::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_W_V2522.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_W_V2522::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2522w_ability_scene_map_update update
  def update; cg_v2522w_ability_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_W_V2522); ALBERT_CG::ABILITY_W_V2522.start_auto_test if ALBERT_CG::ABILITY_W_V2522.f11_trigger?; end
end
