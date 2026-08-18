# RMVX_SCRIPT_INDEX: 259
# RMVX_SCRIPT_ID: 259000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AI v2.5.34a
# RMVX_SOURCE_SHA256: 937fbb13774c3f70f2b7e6ee9630d38faa3ebdf90c2641b1c7d1fb2d004703f4

#==============================================================================
# ■ CG Pokemon Ability Batch AI v2.5.34a
#------------------------------------------------------------------------------
# 【用途】
#  Ability Batch AI：Battle Identity / Composite / Reactive Guard。
#  本頁從 v2.5.33c Ability Batch AH RPG Maker VX 實機 PASS baseline 往後追加，
#  不修改已封版 Scripts 0..258。
#  v2.5.34a 僅修正 F11 fixture：Actor cg_round_actions 排程，以及 Round1 Weather / Held Item
#  配置時機；不改 8 個 Ability 的正式規則定義。
#
# 【本批正式處理 Ability】
#   59 Forecast          陰晴不定
#  121 Multitype         多屬性
#  209 Disguise          畫皮
#  225 RKS System        ＡＲ系統
#  248 Ice Face          結凍頭
#  266 As One (Glastrier) 人馬一體：Unnerve + Chilling Neigh
#  267 As One (Spectrier) 人馬一體：Unnerve + Grim Neigh
#  307 Poison Puppeteer  毒傀儡
#
# 【機制規則】
#  1. Forecast：沿用既有唯一 Weather state。Rain/Heavy Rain=Water、Sun/Harsh Sun=Fire、
#     Hail/Snow=Ice，無有效天氣=Normal；Cloud Nine/Air Lock 抑制天氣效果時視為 Normal。
#     本專案目前 FORM 僅 NORMAL，因此只改 battle-local type，不換圖／Form。
#  2. Multitype / RKS System：沿用 Held Item Runtime。Plate / Memory 由武器 note tag
#     <CG_PLATE_TYPE: electric> / <CG_MEMORY_TYPE: fire> 指定 battle-local type；無合法
#     對應道具時清除 type override。既有 Batch AD 已把 121 / 225 列為不可覆寫 Ability。
#  3. Disguise：每場戰鬥第一次成功命中的敵方 damaging Move 完整擋下，之後扣自身
#     MaxHP 1/8；同一場戰鬥換出不重置。Status Move 與 type-immune 路徑不消耗。
#  4. Ice Face：每次 Ice Face 有效時完整擋下一次 Physical damaging Move；Hail/Snow
#     weather_changed 會恢復 Ice Face。Special Move 不觸發。
#  5. As One 266/267：正式視為 Unnerve 複合 Ability；266 真實 KO 後 ATK +1，267 真實
#     KO 後 SPA +1。沿用 Ability Core :after_ko 與 Batch AB Berry consume Authority。
#  6. Poison Puppeteer：持有者自己的 Move 新增 Poison 後，在同一成功 ailment resolution
#     追加 Confusion；若未成功中毒、目標已中毒或 Ability 被抑制則不觸發。
#
# 【可調參數】
#  TEST_TROOP_ID=737、TEST_LEVEL=40、TEST_ITEM_PLATE=919、TEST_ITEM_MEMORY=920、
#  TEST_ITEM_BERRY=921、DISGUISE_CHIP_DIVISOR=8。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫。開發測試：地圖按 F11，自動進 troop 737，跑三回合 Actual
#  Scene_Battle，輸出 Pokemon_Ability_AI_AutoTest_v2_5_34a.log 與
#  CG_AutoRegression_LATEST.log。
#
# 【F11 實際範例】
#  Round1 Rain：Forecast->Water；Multitype Plate->Electric；RKS Memory->Fire；As One
#     阻止 Berry 一般食用；Disguise 擋第一下並自損 1/8；Ice Face 擋 Physical 第一擊。
#  Round2 Hail：Forecast->Ice；Ice Face weather_changed 復原並再擋 Physical；Disguise
#     第二次不再擋；E0 Teleport 換入 hidden Poison Puppeteer reserve。
#  Round3 Clear Weather：Forecast->Normal；As One 266/267 各自以真實 KO 觸發 ATK/SPA+1；
#     Poison Puppeteer 使用 Toxic Thread，目標必須同時得到 Poison + Confusion。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAI"] = "2.5.34a"

module ALBERT_CG
  module ABILITY_AI_V2534
    VERSION = "2.5.34a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 737
    VK_F11 = 0x7A

    ABILITY_FORECAST = 59
    ABILITY_MULTITYPE = 121
    ABILITY_DISGUISE = 209
    ABILITY_RKS_SYSTEM = 225
    ABILITY_ICE_FACE = 248
    ABILITY_AS_ONE_GLASTRIER = 266
    ABILITY_AS_ONE_SPECTRIER = 267
    ABILITY_POISON_PUPPETEER = 307
    HANDLED_ABILITY_IDS = [59,121,209,225,248,266,267,307]
    AS_ONE_IDS = [266,267]

    TEST_ITEM_PLATE = 919
    TEST_ITEM_MEMORY = 920
    TEST_ITEM_BERRY = 921
    DISGUISE_CHIP_DIVISOR = 8

    TEST_ALLIES = [
      {:dex=>143,:level=>40,:ability=>ABILITY_FORECAST,:moves=>[150,150,150]},
      {:dex=>65, :level=>40,:ability=>ABILITY_MULTITYPE,:moves=>[332,332,150]},
      {:dex=>18, :level=>40,:ability=>ABILITY_RKS_SYSTEM,:moves=>[150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>382,:level=>45,:ability=>ABILITY_DISGUISE,:moves=>[150,100,150]},
      {:dex=>383,:level=>45,:ability=>ABILITY_ICE_FACE,:moves=>[150,150,150]},
      {:dex=>384,:level=>45,:ability=>ABILITY_AS_ONE_GLASTRIER,:moves=>[150,150,55]},
      {:dex=>92, :level=>45,:ability=>ABILITY_AS_ONE_SPECTRIER,:moves=>[150,150,55]},
      {:dex=>197,:level=>45,:ability=>ABILITY_POISON_PUPPETEER,:moves=>[150,150,672]},
    ]

    ROUND_PLANS = [
      {:name=>"RAIN_IDENTITY_COMPOSITE_SHIELDS",
       :allies=>[
         {:kind=>:move,:move_id=>332,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>332,:target=>1},
         {:kind=>:move,:move_id=>150,:target=>1}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"HAIL_ICE_FACE_RESTORE_DISGUISE_BREAK_SWITCH",
       :allies=>[
         {:kind=>:move,:move_id=>332,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>332,:target=>1},
         {:kind=>:move,:move_id=>150,:target=>1}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>100,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"AS_ONE_KO_POISON_PUPPETEER",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>1},
         {:kind=>:move,:move_id=>150,:target=>1},
         {:kind=>:move,:move_id=>150,:target=>1},
         {:kind=>:move,:move_id=>150,:target=>1}],
       :enemies=>{
         1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>55,:target=>2},
         3=>{:kind=>:move,:move_id=>55,:target=>3},
         4=>{:kind=>:move,:move_id=>672,:target=>1}}},
    ]

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:M332","A1:M150","A2:M332","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
      2=>["A0:M332","A1:M150","A2:M332","A3:M150","E1:M150","E2:M150","E3:M150","E0:M100"],
      3=>["A0:M150","A1:M150","E2:M55","E3:M55","E4:M672","E1:M150"],
    }

    TEST_SPEEDS = {
      1=>[800,750,700,650, 500,450,400,350,0],
      2=>[800,750,700,650, 500,450,400,350,0],
      3=>[800,750,100,50, 0,300,600,550,500],
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
    def self.active_battlers; (test_allies+all_enemies).select{|b|b!=nil&&!b.hidden&&b.hp.to_i>0}; rescue; []; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AI_AutoTest_v2_5_34a.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.move_id(skill); return 0 if skill==nil; return ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i if defined?(ALBERT_CG::MOVE_EFFECT); 0; rescue; 0; end
    def self.raw_ability_id(b); return 0 if b==nil; return ALBERT_CG::ABILITY_AG_V2532.raw_ability_id(b).to_i if defined?(ALBERT_CG::ABILITY_AG_V2532); b.respond_to?(:cg_master_ability_id) ? b.cg_master_ability_id.to_i : 0; rescue; 0; end
    def self.ability_id(b); core ? core.ability_id(b).to_i : raw_ability_id(b); rescue; raw_ability_id(b); end
    def self.opposing?(a,b); return false if a==nil||b==nil; a.actor? != b.actor?; rescue; false; end

    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else
        text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text)
      end
      condition
    end

    def self.note_local(aid,battler,kind,data=nil)
      @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1 if active?
      rec={:ability=>aid.to_i,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill,:action].include?(k)}
      if active?
        @records[aid.to_i]=[] if @records[aid.to_i]==nil; @records[aid.to_i].push(rec)
        parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
        log("ABILITY_AI_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
      end
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
      false
    end

    def self.records_for(aid,kind=nil)
      a=@records[aid.to_i]||[]; return a if kind==nil
      a.select{|x|x[:kind].to_sym==kind.to_sym}
    rescue; []; end

    #--------------------------------------------------------------------------
    # Formal identity authority
    #--------------------------------------------------------------------------
    def self.effective_weather
      return nil if defined?(ALBERT_CG::ABILITY_AG_V2532) && ALBERT_CG::ABILITY_AG_V2532.weather_suppressed?
      st=field && field.respond_to?(:state) ? field.state : nil
      return nil if st==nil || st.weather_turns.to_i<=0
      st.weather
    rescue; nil; end

    def self.forecast_type(weather_symbol)
      case weather_symbol
      when :rain,:heavy_rain; :water
      when :sun,:harsh_sun; :fire
      when :hail,:snow; :ice
      else; :normal
      end
    end

    def self.apply_forecast(holder,ctx=nil)
      return false if holder==nil || ability_id(holder)!=ABILITY_FORECAST || !holder.respond_to?(:cg_v237_set_types)
      w=effective_weather; type=forecast_type(w)
      before=holder.respond_to?(:cg_pokemon_types) ? holder.cg_pokemon_types : []
      holder.cg_v237_set_types([type])
      after=holder.respond_to?(:cg_pokemon_types) ? holder.cg_pokemon_types : [type]
      formal_note(ABILITY_FORECAST,holder,:forecast_type,{:weather=>w,:type=>type,:before=>before.inspect,:after=>after.inspect})
      true
    rescue; false; end

    PLATE_RE=/<CG_PLATE_TYPE\s*:\s*([A-Za-z_\-]+)\s*>/i
    MEMORY_RE=/<CG_MEMORY_TYPE\s*:\s*([A-Za-z_\-]+)\s*>/i
    def self.item_note(item); held&&held.respond_to?(:weapon_note) ? held.weapon_note(item).to_s : (item&&item.respond_to?(:note) ? item.note.to_s : ""); rescue; ""; end
    def self.type_key(s); defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_key(s) : s.to_s.downcase.to_sym; rescue; s.to_s.downcase.to_sym; end
    def self.type_from_item(holder,kind)
      item=holder&&holder.respond_to?(:cg_held_item) ? holder.cg_held_item : nil; return nil if item==nil
      re=(kind==:plate ? PLATE_RE : MEMORY_RE); m=item_note(item).match(re); return nil if m==nil
      type_key(m[1])
    rescue; nil; end
    def self.clear_type_override(holder); holder.instance_variable_set(:@cg_v237_type_override,nil) if holder; true; rescue; false; end
    def self.apply_item_identity(holder,kind,aid)
      return false if holder==nil || ability_id(holder)!=aid
      type=type_from_item(holder,kind)
      if type!=nil && holder.respond_to?(:cg_v237_set_types); holder.cg_v237_set_types([type]); else; clear_type_override(holder); end
      formal_note(aid,holder,(kind==:plate ? :multitype_type : :rks_type),{:type=>type,:item_id=>(holder.respond_to?(:cg_held_item_id) ? holder.cg_held_item_id.to_i : 0)})
      true
    rescue; false; end
    def self.apply_multitype(holder,ctx=nil); apply_item_identity(holder,:plate,ABILITY_MULTITYPE); end
    def self.apply_rks(holder,ctx=nil); apply_item_identity(holder,:memory,ABILITY_RKS_SYSTEM); end

    #--------------------------------------------------------------------------
    # Formal reactive guard authority
    #--------------------------------------------------------------------------
    def self.skill_status?(skill); return false if skill==nil; return skill.cg_pokemon_damage_class==:status if skill.respond_to?(:cg_pokemon_damage_class); skill.base_damage.to_i==0; rescue; false; end
    def self.skill_physical?(skill); return false if skill==nil; return skill.cg_pokemon_damage_class==:physical if skill.respond_to?(:cg_pokemon_damage_class); false; rescue; false; end
    def self.damaging_skill?(skill); !skill_status?(skill); rescue; false; end
    def self.disguise_broken?(b); b&&b.instance_variable_get(:@cg_v2534ai_disguise_broken)==true; end
    def self.ice_face_broken?(b); b&&b.instance_variable_get(:@cg_v2534ai_ice_face_broken)==true; end
    def self.reset_disguise(b,ctx=nil); b.instance_variable_set(:@cg_v2534ai_disguise_broken,false) if b; true; end
    def self.reset_ice_face(b,ctx=nil); b.instance_variable_set(:@cg_v2534ai_ice_face_broken,false) if b; true; end
    def self.restore_ice_face_weather(b,ctx=nil)
      return false if b==nil || ability_id(b)!=ABILITY_ICE_FACE || !ice_face_broken?(b)
      w=effective_weather; return false unless [:hail,:snow].include?(w)
      b.instance_variable_set(:@cg_v2534ai_ice_face_broken,false)
      formal_note(ABILITY_ICE_FACE,b,:ice_face_restore,{:weather=>w}); true
    rescue; false; end
    def self.shield_kind(target,user,skill)
      return nil if target==nil||user==nil||!opposing?(target,user)||!damaging_skill?(skill)
      return nil if target.respond_to?(:cg_move_effect_type_immune?) && target.cg_move_effect_type_immune?(skill)
      aid=ability_id(target)
      return :disguise if aid==ABILITY_DISGUISE && !disguise_broken?(target)
      return :ice_face if aid==ABILITY_ICE_FACE && !ice_face_broken?(target) && skill_physical?(skill)
      nil
    rescue; nil; end
    def self.apply_shield_block(target,user,skill,kind)
      mid=move_id(skill)
      if kind==:disguise
        target.instance_variable_set(:@cg_v2534ai_disguise_broken,true)
        chip=[target.maxhp.to_i/DISGUISE_CHIP_DIVISOR,1].max
        before=target.hp.to_i; target.hp=[target.hp.to_i-chip,0].max
        formal_note(ABILITY_DISGUISE,target,:disguise_block,{:move_id=>mid,:chip=>before-target.hp.to_i,:hp_before=>before,:hp_after=>target.hp.to_i})
      elsif kind==:ice_face
        target.instance_variable_set(:@cg_v2534ai_ice_face_broken,true)
        formal_note(ABILITY_ICE_FACE,target,:ice_face_block,{:move_id=>mid,:class=>:physical})
      end
      target.clear_action_results if target.respond_to?(:clear_action_results)
      target.instance_variable_set(:@hp_damage,0); target.instance_variable_set(:@mp_damage,0)
      target.instance_variable_set(:@missed,false); target.instance_variable_set(:@evaded,false); target.instance_variable_set(:@skipped,false)
      true
    rescue; false; end

    #--------------------------------------------------------------------------
    # Formal As One composite authority
    #--------------------------------------------------------------------------
    def self.change_stage(source,target,key,amount)
      return 0 if target==nil || !target.respond_to?(:cg_change_stat_stage)
      auth=defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) ? ALBERT_CG::ABILITY_STAT_GUARD_V256 : nil
      return auth.with_stage_source(source,:ability,false){target.cg_change_stat_stage(key,amount).to_i} if auth&&auth.respond_to?(:with_stage_source)
      target.cg_change_stat_stage(key,amount).to_i
    rescue; 0; end
    def self.apply_as_one_glastrier(holder,ctx)
      return false if ctx==nil||ctx[:target]==nil||ctx[:target].hp.to_i>0
      before=holder.cg_stat_stage(:atk).to_i; d=change_stage(holder,holder,:atk,1); after=holder.cg_stat_stage(:atk).to_i; return false if d==0
      formal_note(ABILITY_AS_ONE_GLASTRIER,holder,:as_one_chilling_neigh,{:before=>before,:after=>after,:delta=>d}); true
    rescue; false; end
    def self.apply_as_one_spectrier(holder,ctx)
      return false if ctx==nil||ctx[:target]==nil||ctx[:target].hp.to_i>0
      before=holder.cg_stat_stage(:spa).to_i; d=change_stage(holder,holder,:spa,1); after=holder.cg_stat_stage(:spa).to_i; return false if d==0
      formal_note(ABILITY_AS_ONE_SPECTRIER,holder,:as_one_grim_neigh,{:before=>before,:after=>after,:delta=>d}); true
    rescue; false; end

    #--------------------------------------------------------------------------
    # Formal Poison Puppeteer authority
    #--------------------------------------------------------------------------
    def self.poison_state_id; defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_POISON : 31; end
    def self.confusion_state_id; defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_CONFUSION : 45; end
    def self.after_ailment(user,target,move_id,poison_before)
      return false if user==nil||target==nil||ability_id(user)!=ABILITY_POISON_PUPPETEER||!opposing?(user,target)
      return false if poison_before || !target.state?(poison_state_id)
      cid=confusion_state_id; return false if target.state?(cid)
      target.add_state(cid); target.added_states.push(cid) if target.respond_to?(:added_states)&&!target.added_states.include?(cid)
      formal_note(ABILITY_POISON_PUPPETEER,user,:poison_puppeteer,{:move_id=>move_id.to_i,:target_index=>(target.respond_to?(:index) ? target.index.to_i : -1),:poison_state=>poison_state_id,:confusion_state=>cid})
      true
    rescue; false; end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_FORECAST,:battle_start,self,:apply_forecast)
      core.register(ABILITY_FORECAST,:entry,self,:apply_forecast)
      core.register(ABILITY_FORECAST,:weather_changed,self,:apply_forecast)
      core.register(ABILITY_MULTITYPE,:entry,self,:apply_multitype)
      core.register(ABILITY_RKS_SYSTEM,:entry,self,:apply_rks)
      core.register(ABILITY_DISGUISE,:battle_start,self,:reset_disguise)
      core.register(ABILITY_ICE_FACE,:battle_start,self,:reset_ice_face)
      core.register(ABILITY_ICE_FACE,:weather_changed,self,:restore_ice_face_weather)
      core.register(ABILITY_AS_ONE_GLASTRIER,:after_ko,self,:apply_as_one_glastrier)
      core.register(ABILITY_AS_ONE_SPECTRIER,:after_ko,self,:apply_as_one_spectrier)
      true
    end

    #--------------------------------------------------------------------------
    # F11 fixture helpers
    #--------------------------------------------------------------------------
    def self.make_test_weapon(id,name,note)
      return nil if $data_weapons==nil; while $data_weapons.size<=id; $data_weapons.push(nil); end
      w=RPG::Weapon.new; w.id=id; w.name=name; w.note=note; w.icon_index=0; w.price=0; $data_weapons[id]=w; w
    end
    def self.install_test_weapons
      make_test_weapon(TEST_ITEM_PLATE,"AI測試雷電石板","<CG_POKEMON_HELD_ITEM>\n<CG_PLATE_TYPE: electric>")
      make_test_weapon(TEST_ITEM_MEMORY,"AI測試火焰記憶體","<CG_POKEMON_HELD_ITEM>\n<CG_MEMORY_TYPE: fire>")
      make_test_weapon(TEST_ITEM_BERRY,"AI測試莓果","<CG_POKEMON_HELD_ITEM>\n<CG_BERRY>\n<CG_HELD_HEAL_HP:20>")
      held.sync_class_permissions if held&&held.respond_to?(:sync_class_permissions); true
    rescue; false; end
    def self.set_item(b,id)
      return false if b==nil||!b.respond_to?(:cg_set_battle_held_item)
      owner=b.respond_to?(:cg_held_item_owner_key) ? b.cg_held_item_owner_key : nil
      b.cg_set_battle_held_item(id,owner)
    rescue
      false
    end
    def self.clear_runtime(b)
      return if b==nil; b.instance_variable_set(:@cg_v2534ai_disguise_broken,false); b.instance_variable_set(:@cg_v2534ai_ice_face_broken,false); b.instance_variable_set(:@cg_priority_test_speed_override_ai,nil)
    end
    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); a.cg_v237_clear_identity if a.respond_to?(:cg_v237_clear_identity); a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime); clear_runtime(a)
    end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end
    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}; ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true); $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each{|c|configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.cg_v237_clear_identity if h.respond_to?(:cg_v237_clear_identity); h.instance_variable_set(:@cg_master_ability_id,0); clear_runtime(h); end
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1]]
      ms=[]; TEST_ENEMIES.each_with_index do |c,i|; configure_enemy(c); m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=(i>=4); ms.push(m); end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AI v2.5.34a AutoRegression",ms)
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

    def self.seed_weather(kind,turns=5)
      return false unless field&&field.respond_to?(:state); st=field.state; st.weather=kind; st.weather_turns=turns.to_i
      core.notify_weather_changed(:ai_fixture) if core&&core.respond_to?(:notify_weather_changed); true
    rescue; false; end

    def self.begin_battle
      # v2.5.34a：这里只清除 AI 自有 battle-local runtime。
      # Weather / Held Item fixture 必須等正式 Scene_Battle 初始化完成後，
      # 在 prepare_round_fixture 內配置，避免被既有 battle_start 初始化覆寫。
      list=[]; list += $game_party.members if $game_party; list += $game_troop.members if $game_troop
      list.each{|b|clear_runtime(b) if b}
      true
    rescue=>ex
      log("BEGIN_BATTLE_ERROR "+ex.class.to_s+":"+ex.message.to_s); false
    end

    def self.prepare_round_fixture
      a=test_allies; e=all_enemies; r=current_round
      if r==1
        # v2.5.34a：正式 battle_start 完成後才配置 Round1 環境與 battle-local Held Item。
        # v2.5.34 在 Scene_Battle#start 前置配置，會被既有初始化清回 nil/0。
        seed_weather(:rain,5)
        set_item(a[2],TEST_ITEM_PLATE) if a[2]
        set_item(a[3],TEST_ITEM_MEMORY) if a[3]
        set_item(a[1],TEST_ITEM_BERRY) if a[1]
        @r1_disguise_hp=e[0] ? e[0].hp.to_i : 0; @r1_ice_hp=e[1] ? e[1].hp.to_i : 0
        if a[1]
          @r1_berry_before=(a[1].respond_to?(:cg_held_item_id) ? a[1].cg_held_item_id.to_i : 0)
          res=a[1].respond_to?(:cg_consume_held_item) ? a[1].cg_consume_held_item(:ai_unnerve_probe,true) : nil
          @r1_unnerve_block=(res!=true && a[1].respond_to?(:cg_held_item_id) && a[1].cg_held_item_id.to_i==TEST_ITEM_BERRY)
        end
      elsif r==2
        seed_weather(:hail,5); @r2_disguise_hp=e[0] ? e[0].hp.to_i : 0; @r2_ice_hp=e[1] ? e[1].hp.to_i : 0
      elsif r==3
        seed_weather(nil,0)
        a[2].hp=1 if a[2]; a[3].hp=1 if a[3]
        @r3_e2_atk=e[2] ? e[2].cg_stat_stage(:atk).to_i : 0; @r3_e3_spa=e[3] ? e[3].cg_stat_stage(:spa).to_i : 0
        if a[1]
          a[1].remove_state(poison_state_id) if a[1].respond_to?(:remove_state)
          a[1].remove_state(confusion_state_id) if a[1].respond_to?(:remove_state)
        end
      end
    end

    def self.apply_test_speeds
      speeds=TEST_SPEEDS[current_round]||[]; list=test_allies+all_enemies
      list.each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_ai,speeds[i]) if b&&speeds[i]!=nil}
    end

    def self.prepare_round_actions
      @actual=[]; prepare_round_fixture; a=test_allies; plan=current_plan; apply_test_speeds
      plan[:allies].each_with_index do |c,i|
        next if a[i]==nil||a[i].hp.to_i<=0
        act=make_action(a[i],c)
        # 正式 deterministic actor scheduler 讀 cg_round_actions。
        # 同時同步 current @action，與已 PASS 的 AB fixture 作法一致。
        if a[i].respond_to?(:cg_round_actions)
          a[i].cg_round_actions.clear
          a[i].cg_round_actions.push(act)
        end
        a[i].cg_assign_action(act) if a[i].respond_to?(:cg_assign_action)
        a[i].instance_variable_set(:@action,act) unless a[i].respond_to?(:cg_assign_action)
      end
      log("ROUND "+current_round.to_s+" BEGIN "+plan[:name].to_s)
    end

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil"))
      assert_true("Ability Batch AI defines 8 handled IDs",HANDLED_ABILITY_IDS.uniq.size==8,"actual="+HANDLED_ABILITY_IDS.uniq.size.to_s)
      tid=($game_troop&&$game_troop.respond_to?(:troop)&&$game_troop.troop ? $game_troop.troop.id.to_i : 0); assert_true("Scene_Battle uses Ability AI test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability AI ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability AI starts with 4 active enemies",all_enemies.select{|x|x&&!x.hidden}.size==4)
      assert_true("Ability AI starts with hidden Poison Puppeteer reserve",all_enemies[4]&&all_enemies[4].hidden)
    end

    def self.assert_execution
      exp=EXPECTED_EXECUTION_TOKENS[current_round]||[]; ok=(@actual==exp); @action_checks+=1 if ok; assert_true("Round"+current_round.to_s+" execution order matches deterministic plan",ok,"expected="+exp.inspect+" actual="+@actual.inspect)
    end

    def self.assert_round
      a=test_allies; e=all_enemies; r=current_round; assert_execution
      if r==1
        f=a[1]&&a[1].cg_pokemon_types==[:water]; @identity_checks+=1 if f; assert_true("Forecast becomes Water in Rain",f,"types="+(a[1] ? a[1].cg_pokemon_types.inspect : "nil"))
        mt=a[2]&&a[2].cg_pokemon_types==[:electric]; @identity_checks+=1 if mt; @item_checks+=1 if mt; assert_true("Multitype follows Electric Plate tag",mt,"types="+(a[2] ? a[2].cg_pokemon_types.inspect : "nil"))
        rk=a[3]&&a[3].cg_pokemon_types==[:fire]; @identity_checks+=1 if rk; @item_checks+=1 if rk; assert_true("RKS System follows Fire Memory tag",rk,"types="+(a[3] ? a[3].cg_pokemon_types.inspect : "nil"))
        un=@r1_unnerve_block==true && !records_for(ABILITY_AS_ONE_GLASTRIER,:as_one_unnerve).empty?; @composite_checks+=1 if un; @item_checks+=1 if un; assert_true("As One Glastrier includes Unnerve and blocks Berry",un,"berry_before="+@r1_berry_before.to_s+" item_now="+(a[1]&&a[1].respond_to?(:cg_held_item_id) ? a[1].cg_held_item_id.to_i.to_s : "nil"))
        rec=records_for(ABILITY_DISGUISE,:disguise_block)[-1]; chip=e[0] ? [e[0].maxhp.to_i/DISGUISE_CHIP_DIVISOR,1].max : 0; dg=e[0]&&rec&&e[0].hp.to_i==@r1_disguise_hp-chip; @shield_checks+=1 if dg; assert_true("Disguise blocks first damaging Move and pays 1/8 chip",dg,"hp="+@r1_disguise_hp.to_s+"->"+(e[0] ? e[0].hp.to_i.to_s : "nil")+" chip="+chip.to_s)
        ic=e[1]&&!records_for(ABILITY_ICE_FACE,:ice_face_block).empty?&&e[1].hp.to_i==@r1_ice_hp; @shield_checks+=1 if ic; assert_true("Ice Face blocks first Physical damaging Move",ic,"hp="+@r1_ice_hp.to_s+"->"+(e[1] ? e[1].hp.to_i.to_s : "nil"))
      elsif r==2
        f=a[1]&&a[1].cg_pokemon_types==[:ice]; @identity_checks+=1 if f; assert_true("Forecast becomes Ice in Hail",f,"types="+(a[1] ? a[1].cg_pokemon_types.inspect : "nil"))
        dg=e[0]&&e[0].hp.to_i<@r2_disguise_hp; @shield_checks+=1 if dg; assert_true("Disguise does not block the second damaging Move",dg,"hp="+@r2_disguise_hp.to_s+"->"+(e[0] ? e[0].hp.to_i.to_s : "nil"))
        rs=!records_for(ABILITY_ICE_FACE,:ice_face_restore).empty?; @shield_checks+=1 if rs; assert_true("Hail weather_changed restores Ice Face",rs)
        blocks=records_for(ABILITY_ICE_FACE,:ice_face_block); ic=e[1]&&blocks.size>=2&&e[1].hp.to_i==@r2_ice_hp; @shield_checks+=1 if ic; assert_true("Restored Ice Face blocks another Physical Move",ic,"blocks="+blocks.size.to_s+" hp="+@r2_ice_hp.to_s+"->"+(e[1] ? e[1].hp.to_i.to_s : "nil"))
        sw=e[0]&&e[0].hidden&&e[4]&&!e[4].hidden; @lifecycle_checks+=1 if sw; assert_true("Teleport deploys hidden Poison Puppeteer reserve",sw,"E0_hidden="+(e[0] ? e[0].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
      elsif r==3
        f=a[1]&&a[1].cg_pokemon_types==[:normal]; @identity_checks+=1 if f; assert_true("Forecast restores Normal when weather clears",f,"types="+(a[1] ? a[1].cg_pokemon_types.inspect : "nil"))
        ko1=e[2]&&e[2].cg_stat_stage(:atk).to_i==@r3_e2_atk+1&&!records_for(ABILITY_AS_ONE_GLASTRIER,:as_one_chilling_neigh).empty?; @composite_checks+=1 if ko1; assert_true("As One Glastrier includes Chilling Neigh after real KO",ko1,"atk="+@r3_e2_atk.to_s+"->"+(e[2] ? e[2].cg_stat_stage(:atk).to_i.to_s : "nil"))
        ko2=e[3]&&e[3].cg_stat_stage(:spa).to_i==@r3_e3_spa+1&&!records_for(ABILITY_AS_ONE_SPECTRIER,:as_one_grim_neigh).empty?; @composite_checks+=1 if ko2; assert_true("As One Spectrier includes Grim Neigh after real KO",ko2,"spa="+@r3_e3_spa.to_s+"->"+(e[3] ? e[3].cg_stat_stage(:spa).to_i.to_s : "nil"))
        pp=a[1]&&a[1].state?(poison_state_id)&&a[1].state?(confusion_state_id)&&!records_for(ABILITY_POISON_PUPPETEER,:poison_puppeteer).empty?; @status_checks+=1 if pp; assert_true("Poison Puppeteer adds Confusion after its Move poisons target",pp,"poison="+(a[1] ? a[1].state?(poison_state_id).to_s : "nil")+" confusion="+(a[1] ? a[1].state?(confusion_state_id).to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end

    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_ai,nil) if b}; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|aid|ok=@ability_trigger_counts[aid].to_i>0; assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)}
      log("------------------------------------------------------------")
      result=@failures.empty? ? "PASS" : "FAIL"; log("RESULT="+result)
      passed=0; HANDLED_ABILITY_IDS.each{|x|passed+=1 if @ability_trigger_counts[x].to_i>0}
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_ai="+passed.to_s+"/8 identity_checks="+@identity_checks.to_s+" shield_checks="+@shield_checks.to_s+" composite_checks="+@composite_checks.to_s+" item_checks="+@item_checks.to_s+" status_checks="+@status_checks.to_s+" action_checks="+@action_checks.to_s+" lifecycle_checks="+@lifecycle_checks.to_s+" pending=93")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}
      cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end

    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false
      @identity_checks=0; @shield_checks=0; @composite_checks=0; @item_checks=0; @status_checks=0; @action_checks=0; @lifecycle_checks=0
      @r1_unnerve_block=false; @r1_berry_before=0; @r1_disguise_hp=0; @r1_ice_hp=0; @r2_disguise_hp=0; @r2_ice_hp=0; @r3_e2_atk=0; @r3_e3_spa=0
    end
    def self.reset_log
      h="CG POKEMON ABILITY AI BATTLE IDENTITY + COMPOSITE + REACTIVE GUARD AUTO REGRESSION v2.5.34a\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; Forecast/Plate/Memory identity + Disguise/Ice Face + As One + Poison Puppeteer\r\n"+
        "BASELINE=v2.5.33c Ability Batch AH RPG Maker VX real-machine PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AH_PASS=272 BATCH_AI=8 PENDING=93\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue; end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; install_test_weapons; prepare_test_party; make_test_troop; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AI_v2.5.34a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

ALBERT_CG::ABILITY_AI_V2534.register_handlers if defined?(ALBERT_CG::ABILITY_AI_V2534)

#==============================================================================
# ■ Formal Held Item identity bridge：Multitype / RKS System
#==============================================================================
class Game_Battler
  alias cg_v2534ai_set_battle_held_item cg_set_battle_held_item
  def cg_set_battle_held_item(item_id,owner_key=nil)
    result=cg_v2534ai_set_battle_held_item(item_id,owner_key)
    if result && defined?(ALBERT_CG::ABILITY_AI_V2534)
      aid=ALBERT_CG::ABILITY_AI_V2534.ability_id(self)
      ALBERT_CG::ABILITY_AI_V2534.apply_multitype(self,nil) if aid==ALBERT_CG::ABILITY_AI_V2534::ABILITY_MULTITYPE
      ALBERT_CG::ABILITY_AI_V2534.apply_rks(self,nil) if aid==ALBERT_CG::ABILITY_AI_V2534::ABILITY_RKS_SYSTEM
    end
    result
  end
end

#==============================================================================
# ■ Formal Disguise / Ice Face pre-resolution guard + Poison Puppeteer ailment bridge
#==============================================================================
class Game_Battler
  alias cg_v2534ai_skill_effect skill_effect
  def skill_effect(user,skill)
    if defined?(ALBERT_CG::ABILITY_AI_V2534)
      kind=ALBERT_CG::ABILITY_AI_V2534.shield_kind(self,user,skill)
      return ALBERT_CG::ABILITY_AI_V2534.apply_shield_block(self,user,skill,kind) if kind!=nil
    end
    cg_v2534ai_skill_effect(user,skill)
  end

  alias cg_v2534ai_apply_ailment cg_move_effect_apply_ailment
  def cg_move_effect_apply_ailment(user,move_id)
    before=(defined?(ALBERT_CG::ABILITY_AI_V2534) ? state?(ALBERT_CG::ABILITY_AI_V2534.poison_state_id) : false)
    result=cg_v2534ai_apply_ailment(user,move_id)
    ALBERT_CG::ABILITY_AI_V2534.after_ailment(user,self,move_id,before) if defined?(ALBERT_CG::ABILITY_AI_V2534)
    result
  end
end

#==============================================================================
# ■ Formal As One -> Batch AB Unnerve bridge
#==============================================================================
if defined?(ALBERT_CG::ABILITY_AB_V2527)
  module ALBERT_CG; module ABILITY_AB_V2527; class << self
    alias cg_v2534ai_unnerve_holder_for unnerve_holder_for
    def unnerve_holder_for(battler)
      active_battlers.each do |b|
        next if b==nil||b.hidden||b.hp.to_i<=0
        aid=ability_id(b)
        return b if opposing?(b,battler) && [266,267].include?(aid)
      end
      cg_v2534ai_unnerve_holder_for(battler)
    rescue; cg_v2534ai_unnerve_holder_for(battler); end

    alias cg_v2534ai_note_unnerve note_unnerve
    def note_unnerve(holder,target,item_id,reason)
      aid=ability_id(holder)
      if defined?(ALBERT_CG::ABILITY_AI_V2534) && [266,267].include?(aid)
        return ALBERT_CG::ABILITY_AI_V2534.formal_note(aid,holder,:as_one_unnerve,{:target_index=>(target&&target.respond_to?(:index) ? target.index : -1),:item_id=>item_id.to_i,:reason=>reason})
      end
      cg_v2534ai_note_unnerve(holder,target,item_id,reason)
    end
  end; end; end
end

#==============================================================================
# ■ Scene / deterministic F11 test harness
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2534ai_start start
  def start
    ALBERT_CG::ABILITY_AI_V2534.begin_battle if defined?(ALBERT_CG::ABILITY_AI_V2534)&&ALBERT_CG::ABILITY_AI_V2534.active?
    cg_v2534ai_start
  end
  alias cg_v2534ai_execute_action execute_action
  def execute_action
    ALBERT_CG::ABILITY_AI_V2534.record_execution(@active_battler) if defined?(ALBERT_CG::ABILITY_AI_V2534)&&ALBERT_CG::ABILITY_AI_V2534.active?
    cg_v2534ai_execute_action
  end
  alias cg_v2534ai_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AI_V2534)&&ALBERT_CG::ABILITY_AI_V2534.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_AI_V2534.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_AI_V2534.finish_round_assertions; end
    end
    cg_v2534ai_turn_end
  end
  alias cg_v2534ai_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AI_V2534)&&ALBERT_CG::ABILITY_AI_V2534.active?; return cg_v2534ai_start_party_command; end
    cg_v2534ai_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_AI_V2534.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AI_V2534.finished?; ALBERT_CG::ABILITY_AI_V2534.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_AI_V2534.prepare_round_actions; start_main
  end
end

class Game_Battler
  alias cg_v2534ai_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AI_V2534)&&ALBERT_CG::ABILITY_AI_V2534.active?; v=@cg_priority_test_speed_override_ai; return v.to_i if v!=nil; end
    cg_v2534ai_priority_base_speed
  rescue; cg_v2534ai_priority_base_speed; end
end

class Game_Enemy < Game_Battler
  alias cg_v2534ai_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AI_V2534)&&ALBERT_CG::ABILITY_AI_V2534.active?; a=ALBERT_CG::ABILITY_AI_V2534.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end; end
    cg_v2534ai_enemy_make_action
  end
end

module ALBERT_CG; class << self
  alias cg_v2534ai_bootstrap_demo_party bootstrap_demo_party
  def bootstrap_demo_party
    r=cg_v2534ai_bootstrap_demo_party
    if defined?(ALBERT_CG::ABILITY_AI_V2534)&&ALBERT_CG::ABILITY_AI_V2534.active?
      ALBERT_CG::ABILITY_AI_V2534::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AI_V2534.configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_AI_V2534::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.cg_v237_clear_identity if h.respond_to?(:cg_v237_clear_identity); h.instance_variable_set(:@cg_master_ability_id,0); ALBERT_CG::ABILITY_AI_V2534.clear_runtime(h); end
    end
    r
  end
end; end

# Newest F11 only.
if defined?(ALBERT_CG::ABILITY_AH_V2533)
  module ALBERT_CG; module ABILITY_AH_V2533; def self.f11_trigger?; false; end; end; end
end
class Scene_Map < Scene_Base
  alias cg_v2534ai_scene_map_update update
  def update
    cg_v2534ai_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_AI_V2534); ALBERT_CG::ABILITY_AI_V2534.start_auto_test if ALBERT_CG::ABILITY_AI_V2534.f11_trigger?
  end
end
