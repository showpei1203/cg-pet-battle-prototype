# RMVX_SCRIPT_INDEX: 258
# RMVX_SCRIPT_ID: 253300002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AH v2.5.33c
# RMVX_SOURCE_SHA256: 1fbdbaedc7c6d73e1c578edbc87b86349a179fd609897436c0219dea31905a78

#==============================================================================
# ■ CG Pokemon Ability Batch AH v2.5.33c
#    Primal Weather / Adaptive Environment Authority
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.32a Ability Batch AG RPG Maker VX 實機 PASS 為唯一基線，新增八個
#  強天氣／環境適應類 Ability。此頁只新增 index 258，不修改 sealed scripts 0..257。
#
# 【本批 Ability】
#  189 Primordial Sea / 始源之海
#  190 Desolate Land / 終結之地
#  191 Delta Stream / 德爾塔氣流
#  250 Mimicry / 擬態
#  281 Protosynthesis / 古代活性
#  282 Quark Drive / 夸克充能
#  298 Mycelium Might / 菌絲之力
#  306 Teraform Zero / 歸零化境
#
# 【機制規則】
#  1. 三種強天氣沿用 FIELD_V233 單一 weather state，不建立第二套天氣資料：
#     :heavy_rain / :harsh_sun / :strong_winds。普通 Weather Move 或 Drizzle/Drought
#     類 set_weather 不可覆蓋強天氣；另一個強天氣 Ability 進場則可以取代。
#  2. Heavy Rain：Water 仍吃既有 Rain 150%，Fire Move 直接 0%；Harsh Sun：
#     Fire 150%，Water Move 直接 0%。v2.5.33c 另外在最終 skill_effect 前攔截
#     被強天氣完全無效化的招式，避免 FIELD_V233 的既有「最低 1 傷害」clamp
#     把 0% 又抬回 1。Cloud Nine / Air Lock 存在時只抑制效果，不刪除強天氣本體。
#  3. Delta Stream：Strong Winds 存在時，Flying target 對 Electric/Ice/Rock 的
#     Flying 弱點倍率被中和一層；雙屬性另一個弱點／抗性照常保留。
#  4. Mimicry：Grassy/Electric/Misty/Psychic Terrain active 時暫時變為
#     Grass/Electric/Fairy/Psychic 單屬性；Terrain 消失或 switch-out 時還原進場前 type override。
#  5. Protosynthesis / Quark Drive：分別在有效 Sun/Harsh Sun、Electric Terrain 下
#     強化目前最高有效能力值。ATK/DEF/SPA/SPD x1.3，SPE x1.5。最高值選擇期間
#     會抑制自身 boost，避免遞迴。支援帶 <CG_BOOSTER_ENERGY> 的 battle held item 作為
#     未來 Booster Energy 接點，但本 F11 不依賴額外物品資料。
#  6. Mycelium Might：Status Move 保持原本 Move priority bracket，但 secondary speed
#     固定為最低，因此只在同 priority 中最後行動；其 target-only Ability bypass
#     延伸既有 AG scoped bypass，不永久改寫 target Ability，也不影響第三者。
#  7. Teraform Zero：holder entry 時若有 Weather/Terrain，兩者同時清除並走既有
#     weather_changed / terrain_changed lifecycle。專案沒有 Terapagos form runtime，故 Ability
#     只會在資料層真正配置給應觸發的形態時生效，不另外猜測 form state。
#  8. 所有正式效果使用既有 Ability Core / Field / Six-Stat / Priority / Identity Authority；
#     F11 fixture 只負責 deterministic setup 與 ASSERT，不用測試捷徑替正式 Runtime 扣血。
#
# 【可調參數】
#  TEST_TROOP_ID=736、TEST_LEVEL=40、STRONG_WEATHER_TURNS=9999、
#  ENV_STAT_PERCENT=130、ENV_SPEED_PERCENT=150、MYCELIUM_LAST_SPEED=-1000000。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，自動進 troop 736，跑四回合並輸出
#  Pokemon_Ability_AH_AutoTest_v2_5_33c.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  R1 Heavy Rain：Ember 0 damage、Sunny Day 無法覆蓋；Electric Terrain 讓 Quark Drive
#     boost；Mimicry 變 Electric；Mycelium Might Sand Attack 穿透 Clear Body 且同 priority 最後。
#  R2 Harsh Sun：Water Gun 0 damage、Rain Dance 無法覆蓋；Protosynthesis boost。
#  R3 Strong Winds：Electric 對 Dragon/Flying 的 Flying 弱點被中和；Mimicry 隨 Grassy
#     Terrain 變 Grass。
#  R4 Teraform Zero reserve 由 Teleport 換入，清除 Strong Winds + Grassy Terrain，
#     Mimicry 同 lifecycle 還原原始 Flying type。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAH"] = "2.5.33"

module ALBERT_CG
  module ABILITY_AH_V2533
    VERSION="2.5.33c"
    TEST_LEVEL=40
    TEST_TROOP_ID=736
    VK_F11=0x7A
    STRONG_WEATHER_TURNS=9999
    ENV_STAT_PERCENT=130
    ENV_SPEED_PERCENT=150
    MYCELIUM_LAST_SPEED=-1000000

    ABILITY_PRIMORDIAL_SEA=189
    ABILITY_DESOLATE_LAND=190
    ABILITY_DELTA_STREAM=191
    ABILITY_MIMICRY=250
    ABILITY_PROTOSYNTHESIS=281
    ABILITY_QUARK_DRIVE=282
    ABILITY_MYCELIUM_MIGHT=298
    ABILITY_TERAFORM_ZERO=306
    ABILITY_CLEAR_BODY=29
    HANDLED_ABILITY_IDS=[189,190,191,250,281,282,298,306]
    PRIMAL_IDS=[189,190,191]
    PRIMAL_WEATHERS={189=>:heavy_rain,190=>:harsh_sun,191=>:strong_winds}
    TERRAIN_TYPES={:grassy=>:grass,:electric=>:electric,:misty=>:fairy,:psychic=>:psychic}

    TEST_ALLIES=[
      {:dex=>143,:level=>40,:ability=>ABILITY_PROTOSYNTHESIS,:moves=>[241,240,150,150]},
      {:dex=>65, :level=>40,:ability=>ABILITY_QUARK_DRIVE,   :moves=>[150,150,150,150]},
      {:dex=>18, :level=>40,:ability=>ABILITY_MIMICRY,       :moves=>[150,150,150,150]},
    ]
    TEST_ENEMIES=[
      {:dex=>382,:level=>45,:ability=>ABILITY_PRIMORDIAL_SEA,:moves=>[150,100,150,150]},
      {:dex=>383,:level=>45,:ability=>ABILITY_DESOLATE_LAND, :moves=>[150,150,150,150]},
      {:dex=>384,:level=>45,:ability=>ABILITY_DELTA_STREAM,  :moves=>[150,150,150,150]},
      {:dex=>92, :level=>45,:ability=>ABILITY_MYCELIUM_MIGHT,:moves=>[28,150,150,150]},
      {:dex=>197,:level=>45,:ability=>ABILITY_TERAFORM_ZERO, :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS=[
      {:name=>"HEAVY_RAIN_QUARK_MIMICRY_MYCELIUM",
       :allies=>[
         {:kind=>:move,:move_id=>52,:target=>0},
         {:kind=>:move,:move_id=>241,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>28,:target=>3}}},
      {:name=>"HARSH_SUN_PROTO_REPLACEMENT_GUARD",
       :allies=>[
         {:kind=>:move,:move_id=>55,:target=>1},
         {:kind=>:move,:move_id=>240,:target=>1},
         {:kind=>:move,:move_id=>150,:target=>1},
         {:kind=>:move,:move_id=>150,:target=>1}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"STRONG_WINDS_MIMICRY_GRASS",
       :allies=>[
         {:kind=>:move,:move_id=>84,:target=>2},
         {:kind=>:move,:move_id=>150,:target=>2},
         {:kind=>:move,:move_id=>150,:target=>2},
         {:kind=>:move,:move_id=>150,:target=>2}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"TERAFORM_ZERO_CLEAR_ENVIRONMENT",
       :allies=>[{:kind=>:guard},{:kind=>:guard},{:kind=>:guard},{:kind=>:guard}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>100,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
    ]
    TEST_SPEEDS={
      :r1=>[500,450,400,350, 300,250,200,600,0],
      :r2=>[500,450,400,350, 300,250,200,150,0],
      :r3=>[500,450,400,350, 300,250,200,150,0],
      :r4=>[500,450,400,350, 300,250,200,150,0],
    }
    EXPECTED_EXECUTION_TOKENS={
      1=>["A0:M52","A1:M241","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M28"],
      2=>["A0:M55","A1:M240","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
      3=>["A0:M84","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
      4=>["A0:Guard","A1:Guard","A2:Guard","A3:Guard","E1:M150","E2:M150","E3:M150","E0:M100"],
    }

    begin
      KEY_API=Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API=nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.field; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233 : nil; end
    def self.weather; defined?(ALBERT_CG::ABILITY_WEATHER_V252) ? ALBERT_CG::ABILITY_WEATHER_V252 : nil; end
    def self.field_state; f=field; f && f.respond_to?(:state) ? f.state : nil; rescue; nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.active_battlers; (test_allies+all_enemies).select{|b|b!=nil&&!b.hidden&&b.hp.to_i>0}; rescue; []; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AH_AutoTest_v2_5_33c.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.move_id(skill); return 0 if skill==nil; return ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i if defined?(ALBERT_CG::MOVE_EFFECT); 0; rescue; 0; end
    def self.skill_status?(skill); return false if skill==nil; return skill.cg_pokemon_damage_class==:status if skill.respond_to?(:cg_pokemon_damage_class); skill.base_damage.to_i==0; rescue; false; end
    def self.type_key(x); defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_key(x) : x; rescue; x; end
    def self.raw_ability_id(b); return 0 if b==nil; return ALBERT_CG::ABILITY_AG_V2532.raw_ability_id(b).to_i if defined?(ALBERT_CG::ABILITY_AG_V2532); b.respond_to?(:cg_master_ability_id) ? b.cg_master_ability_id.to_i : 0; rescue; 0; end
    def self.ability_id(b); core ? core.ability_id(b).to_i : raw_ability_id(b); rescue; raw_ability_id(b); end
    def self.opposing?(a,b); return false if a==nil||b==nil; a.actor? != b.actor?; rescue; false; end
    def self.assert_true(label,condition,detail=nil)
      if condition; log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else; text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text); end
      condition
    end
    def self.note_local(aid,battler,kind,data=nil)
      return true unless active?
      @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1
      rec={:ability=>aid.to_i,:kind=>kind}; (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill].include?(k)}
      @records[aid.to_i]=[] if @records[aid.to_i]==nil; @records[aid.to_i].push(rec)
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
      log("ABILITY_AH_TRIGGER ability="+aid.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
      true
    rescue; false; end
    def self.formal_note(aid,battler,kind,data=nil)
      ctx=data||{}; if core; core.note_trigger(kind,battler,aid,ctx) if core.respond_to?(:note_trigger); core.present_trigger(battler,aid,kind,ctx) if core.respond_to?(:present_trigger); end
      note_local(aid,battler,kind,ctx); true
    rescue; false; end
    def self.records_for(aid,kind=nil); a=@records[aid.to_i]||[]; return a if kind==nil; a.select{|x|x[:kind].to_sym==kind.to_sym}; rescue; []; end

    #---------------------------- Formal: strong weather -----------------------
    def self.weather_suppressed?; defined?(ALBERT_CG::ABILITY_AG_V2532) && ALBERT_CG::ABILITY_AG_V2532.weather_suppressed?; rescue; false; end
    def self.strong_weather?; st=field_state; st!=nil && st.weather_turns.to_i>0 && [:heavy_rain,:harsh_sun,:strong_winds].include?(st.weather); rescue; false; end
    def self.strong_weather_symbol; strong_weather? ? field_state.weather : nil; rescue; nil; end
    def self.strong_weather_nullifies_type?(type_id)
      return false unless strong_weather? && !weather_suppressed?
      key=type_key(type_id); kind=strong_weather_symbol
      return true if kind==:heavy_rain && key==:fire
      return true if kind==:harsh_sun && key==:water
      false
    rescue; false; end
    def self.strong_weather_nullifies_skill?(skill)
      return false if skill==nil || skill_status?(skill)
      tid=skill.respond_to?(:cg_pokemon_type_id) ? skill.cg_pokemon_type_id : 0
      strong_weather_nullifies_type?(tid)
    rescue; false; end
    def self.note_strong_weather_null(skill)
      return false if skill==nil
      tid=skill.respond_to?(:cg_pokemon_type_id) ? skill.cg_pokemon_type_id : 0
      key=type_key(tid); kind=strong_weather_symbol; mid=move_id(skill)
      if kind==:heavy_rain && key==:fire
        note_local(189,primal_holder_for(:heavy_rain),:heavy_rain_fire_null,{:move_id=>mid}); return true
      elsif kind==:harsh_sun && key==:water
        note_local(190,primal_holder_for(:harsh_sun),:harsh_sun_water_null,{:move_id=>mid}); return true
      end
      false
    rescue; false; end
    def self.weather_for_ability(aid); PRIMAL_WEATHERS[aid.to_i]; end
    def self.set_primal_weather(holder,aid)
      st=field_state; kind=weather_for_ability(aid); return false if st==nil||kind==nil
      changed=st.weather!=kind || st.weather_turns.to_i<=0
      st.weather=kind; st.weather_turns=STRONG_WEATHER_TURNS
      note_local(aid,holder,:primal_weather,{:weather=>kind,:changed=>changed})
      core.notify_weather_changed(holder) if core && core.respond_to?(:notify_weather_changed)
      true
    rescue; false; end
    def self.apply_primal_entry(holder,ctx=nil); set_primal_weather(holder,raw_ability_id(holder)); end
    def self.primal_holder_for(kind)
      active_battlers.each{|b|return b if PRIMAL_WEATHERS[ability_id(b)]==kind}; nil
    rescue; nil; end
    def self.handle_primal_departure(holder,ctx=nil)
      return false if holder==nil; aid=raw_ability_id(holder); kind=PRIMAL_WEATHERS[aid]; return false if kind==nil
      st=field_state; return false if st==nil || st.weather!=kind
      replacement=nil; active_battlers.each{|b|next if b.equal?(holder); a=ability_id(b); if PRIMAL_IDS.include?(a); replacement=b; break; end}
      if replacement; set_primal_weather(replacement,ability_id(replacement))
      else; st.weather=nil; st.weather_turns=0; core.notify_weather_changed(holder) if core&&core.respond_to?(:notify_weather_changed); end
      true
    rescue; false; end
    def self.normal_weather_blocked?(kind); strong_weather? && [:rain,:sun,:sandstorm,:hail].include?(kind); rescue; false; end
    def self.strong_weather_damage_percent(original,user,target,skill,type_id,damage_class,move_id)
      return original.call unless strong_weather? && !weather_suppressed?
      st=field_state; key=type_key(type_id); old=st.weather
      if old==:heavy_rain
        if key==:fire; note_local(189,primal_holder_for(:heavy_rain),:heavy_rain_fire_null,{:move_id=>move_id}); return 0; end
        st.weather=:rain
      elsif old==:harsh_sun
        if key==:water; note_local(190,primal_holder_for(:harsh_sun),:harsh_sun_water_null,{:move_id=>move_id}); return 0; end
        st.weather=:sun
      end
      begin; original.call; ensure; st.weather=old; end
    rescue; original.call; end

    #---------------------------- Formal: Delta Stream -------------------------
    def self.delta_adjust_rate(target,attack_type,rate)
      return rate unless strong_weather_symbol==:strong_winds && !weather_suppressed?
      return rate unless target && target.respond_to?(:cg_pokemon_types) && target.cg_pokemon_types.include?(:flying)
      key=type_key(attack_type); return rate unless [:electric,:ice,:rock].include?(key)
      return rate unless defined?(ALBERT_CG::POKEMON_COMBAT)
      component=ALBERT_CG::POKEMON_COMBAT.type_chart_percent(key,[:flying]).to_i
      return rate if component<=100 || rate.to_i<=0
      adjusted=rate.to_i*100/component; adjusted=1 if adjusted<1
      note_local(191,primal_holder_for(:strong_winds),:delta_stream_type_guard,{:attack_type=>key,:before=>rate.to_i,:after=>adjusted})
      adjusted
    rescue; rate; end

    #---------------------------- Formal: Mimicry ------------------------------
    def self.terrain_type
      st=field_state; return nil if st==nil||st.terrain_turns.to_i<=0; TERRAIN_TYPES[st.terrain]
    rescue; nil; end
    def self.apply_mimicry(holder,ctx=nil)
      return false if holder==nil; t=terrain_type
      saved_flag=holder.instance_variable_get(:@cg_v2533ah_mimicry_saved_flag)==true
      current=holder.instance_variable_get(:@cg_v237_type_override)
      if t!=nil
        unless saved_flag
          holder.instance_variable_set(:@cg_v2533ah_mimicry_saved_flag,true)
          holder.instance_variable_set(:@cg_v2533ah_mimicry_saved_override,current==nil ? nil : current.dup)
        end
        desired=[t]
        changed=current!=desired
        holder.instance_variable_set(:@cg_v237_type_override,desired)
        note_local(250,holder,:mimicry_type,{:terrain=>field_state.terrain,:type=>t}) if changed
        return changed
      elsif saved_flag
        old=holder.instance_variable_get(:@cg_v2533ah_mimicry_saved_override)
        holder.instance_variable_set(:@cg_v237_type_override,old)
        holder.instance_variable_set(:@cg_v2533ah_mimicry_saved_override,nil)
        holder.instance_variable_set(:@cg_v2533ah_mimicry_saved_flag,false)
        note_local(250,holder,:mimicry_restore,{:type=>(holder.respond_to?(:cg_pokemon_types) ? holder.cg_pokemon_types.join("+") : "")})
        return true
      end
      false
    rescue; false; end
    def self.clear_mimicry(holder,ctx=nil); return false if holder==nil; old=holder.instance_variable_get(:@cg_v2533ah_mimicry_saved_override); flag=holder.instance_variable_get(:@cg_v2533ah_mimicry_saved_flag)==true; if flag; holder.instance_variable_set(:@cg_v237_type_override,old); end; holder.instance_variable_set(:@cg_v2533ah_mimicry_saved_override,nil); holder.instance_variable_set(:@cg_v2533ah_mimicry_saved_flag,false); flag; rescue; false; end

    #---------------------------- Formal: Proto / Quark ------------------------
    def self.booster_active?(b); b!=nil && b.instance_variable_get(:@cg_v2533ah_booster_active)==true; rescue; false; end
    def self.try_booster_energy(b)
      return false if b==nil||booster_active?(b)||!b.respond_to?(:cg_held_item_id); iid=b.cg_held_item_id.to_i; return false if iid<=0||$data_items==nil
      item=$data_items[iid]; return false if item==nil; text=(item.name.to_s+" "+item.note.to_s).downcase
      return false unless text.include?("cg_booster_energy")||text.include?("booster energy")||item.name.to_s.include?("驅勁能量")
      if b.respond_to?(:cg_consume_held_item); ok=b.cg_consume_held_item(:booster_energy,false); return false unless ok; end
      b.instance_variable_set(:@cg_v2533ah_booster_active,true); true
    rescue; false; end
    def self.proto_condition?(b); return true if booster_active?(b); st=field_state; st!=nil&&st.weather_turns.to_i>0&&[:sun,:harsh_sun].include?(st.weather)&&!weather_suppressed?; rescue; false; end
    def self.quark_condition?(b); return true if booster_active?(b); st=field_state; st!=nil&&st.terrain==:electric&&st.terrain_turns.to_i>0; rescue; false; end
    def self.stat_value(b,key)
      case key; when :atk; b.cg_atk_stat.to_i; when :def; b.cg_def_stat.to_i; when :spa; b.cg_spa.to_i; when :spd; b.cg_spd.to_i; when :spe; b.cg_spe.to_i; else 0; end
    rescue; 0; end
    def self.highest_stat_key(b)
      return nil if b==nil; b.instance_variable_set(:@cg_v2533ah_selecting_stat,true)
      begin
        vals={}; [:atk,:def,:spa,:spd,:spe].each{|k|vals[k]=stat_value(b,k)}
        best=:atk; [:def,:spa,:spd,:spe].each{|k|best=k if vals[k].to_i>vals[best].to_i}; best
      ensure; b.instance_variable_set(:@cg_v2533ah_selecting_stat,false); end
    rescue; b.instance_variable_set(:@cg_v2533ah_selecting_stat,false) if b; nil; end
    def self.apply_environment_stat(aid,b,ctx,condition,kind)
      return false if b==nil||ctx==nil||b.instance_variable_get(:@cg_v2533ah_selecting_stat)==true||!condition
      key=highest_stat_key(b); return false if key==nil||ctx[:stat].to_sym!=key
      before=ctx[:value].to_i; pct=(key==:spe ? ENV_SPEED_PERCENT : ENV_STAT_PERCENT); after=before*pct/100; after=1 if after<1
      ctx[:value]=after; note_local(aid,b,kind,{:stat=>key,:before=>before,:after=>after,:percent=>pct}); true
    rescue; false; end
    def self.apply_protosynthesis(b,ctx); apply_environment_stat(281,b,ctx,proto_condition?(b),:protosynthesis_boost); end
    def self.apply_quark_drive(b,ctx); apply_environment_stat(282,b,ctx,quark_condition?(b),:quark_drive_boost); end
    def self.apply_environment_entry(b,ctx=nil); try_booster_energy(b); false; end
    def self.apply_environment_switch_out(b,ctx=nil); return false if b==nil; had=booster_active?(b); b.instance_variable_set(:@cg_v2533ah_booster_active,false); had; rescue; false; end

    #---------------------------- Formal: Mycelium Might -----------------------
    def self.mycelium_status_user?(user,skill=nil); return false if user==nil||ability_id(user)!=298; sk=skill; sk=core.current_skill(user) if sk==nil&&core; skill_status?(sk); rescue; false; end
    def self.mycelium_priority_speed(action,normal)
      return normal if action==nil; b=action.instance_variable_get(:@battler); return normal if b==nil||ability_id(b)!=298||!action.skill?
      sk=action.skill; return normal unless skill_status?(sk)
      note_local(298,b,:mycelium_late,{:move_id=>move_id(sk),:normal_speed=>normal.to_i,:forced_speed=>MYCELIUM_LAST_SPEED})
      MYCELIUM_LAST_SPEED
    rescue; normal; end

    #---------------------------- Formal: Teraform Zero ------------------------
    def self.apply_teraform_zero(holder,ctx=nil)
      st=field_state; return false if st==nil
      oldw=st.weather; oldwt=st.weather_turns.to_i; oldt=st.terrain; oldtt=st.terrain_turns.to_i
      changed=(oldwt>0&&oldw!=nil)||(oldtt>0&&oldt!=nil); return false unless changed
      st.weather=nil; st.weather_turns=0; st.terrain=nil; st.terrain_turns=0
      note_local(306,holder,:teraform_zero,{:weather=>oldw,:terrain=>oldt})
      core.notify_weather_changed(holder) if core&&core.respond_to?(:notify_weather_changed)
      core.notify_terrain_changed(holder) if core&&core.respond_to?(:notify_terrain_changed)
      true
    rescue; false; end

    def self.register_handlers
      return false if core==nil; list=core::TRIGGERS; list.push(:stat_query) unless list.include?(:stat_query)
      PRIMAL_IDS.each{|aid|core.register(aid,:entry,self,:apply_primal_entry); core.register(aid,:switch_out,self,:handle_primal_departure)}
      core.register(250,:entry,self,:apply_mimicry); core.register(250,:terrain_changed,self,:apply_mimicry); core.register(250,:switch_out,self,:clear_mimicry)
      core.register(281,:entry,self,:apply_environment_entry); core.register(281,:stat_query,self,:apply_protosynthesis); core.register(281,:switch_out,self,:apply_environment_switch_out)
      core.register(282,:entry,self,:apply_environment_entry); core.register(282,:stat_query,self,:apply_quark_drive); core.register(282,:switch_out,self,:apply_environment_switch_out)
      core.register(306,:entry,self,:apply_teraform_zero)
      true
    rescue; false; end

    #---------------------------- Fixture helpers -------------------------------
    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil; master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); a.cg_v237_clear_identity if a.respond_to?(:cg_v237_clear_identity); a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime); clear_runtime(a)
    end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end
    def self.clear_runtime(b); return if b==nil; clear_mimicry(b); b.instance_variable_set(:@cg_v2533ah_booster_active,false); b.instance_variable_set(:@cg_priority_test_speed_override_ah,nil); end
    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}; ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true); $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!); TEST_ALLIES.each{|c|configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.cg_v237_clear_identity if h.respond_to?(:cg_v237_clear_identity); h.instance_variable_set(:@cg_master_ability_id,0); clear_runtime(h); end
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID); xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]; ys=[ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2]]; ms=[]
      TEST_ENEMIES.each_with_index{|c,i|configure_enemy(c); m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=(i>=4); ms.push(m)}
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AH v2.5.33c AutoRegression",ms)
    end
    def self.make_action(b,c); a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); else; a.clear; end; a.target_index=c[:target].to_i if c.has_key?(:target); a; end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c); end
    def self.apply_test_speeds; vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||[]; (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_ah,vals[i]) if b}; end
    def self.set_effective_ability(b,aid); return false if b==nil; if b.respond_to?(:cg_v237_set_ability); b.cg_v237_set_ability(aid.to_i); else; b.instance_variable_set(:@cg_v237_ability_override,aid.to_i); b.instance_variable_set(:@cg_v237_ability_suppressed,false); end; true; rescue; false; end
    def self.stat_stage(b,key); b&&b.respond_to?(:cg_stat_stage) ? b.cg_stat_stage(key).to_i : 0; rescue; 0; end
    def self.set_terrain(kind,turns=5,source=nil); st=field_state; return false if st==nil; st.terrain=kind; st.terrain_turns=turns; core.notify_terrain_changed(source||:ah_fixture) if core&&core.respond_to?(:notify_terrain_changed); true; rescue; false; end
    def self.clear_terrain(source=nil); st=field_state; return false if st==nil; st.terrain=nil; st.terrain_turns=0; core.notify_terrain_changed(source||:ah_fixture) if core&&core.respond_to?(:notify_terrain_changed); true; rescue; false; end
    def self.query_with_ability_disabled(b,key); old=b.instance_variable_get(:@cg_v237_ability_override); olds=b.instance_variable_get(:@cg_v237_ability_suppressed); b.instance_variable_set(:@cg_v237_ability_override,0); b.instance_variable_set(:@cg_v237_ability_suppressed,false); v=stat_value(b,key); b.instance_variable_set(:@cg_v237_ability_override,old); b.instance_variable_set(:@cg_v237_ability_suppressed,olds); v; rescue; 0; end

    def self.prepare_round_preconditions
      a=test_allies; e=all_enemies; st=field_state
      if current_round==1
        set_primal_weather(e[0],189); set_terrain(:electric,5,:ah_r1)
        @r1_e0_hp=e[0] ? e[0].hp.to_i : 0; @r1_quark_key=highest_stat_key(a[2]); @r1_quark_base=query_with_ability_disabled(a[2],@r1_quark_key); @r1_quark_boost=stat_value(a[2],@r1_quark_key)
        @r1_mimic_types=a[3]&&a[3].respond_to?(:cg_pokemon_types) ? a[3].cg_pokemon_types.dup : []
        set_effective_ability(a[3],ABILITY_CLEAR_BODY); @r1_accuracy_before=stat_stage(a[3],:accuracy)
      elsif current_round==2
        set_effective_ability(a[3],250); set_primal_weather(e[1],190); clear_terrain(:ah_r2)
        @r2_e1_hp=e[1] ? e[1].hp.to_i : 0; @r2_proto_key=highest_stat_key(a[1]); @r2_proto_base=query_with_ability_disabled(a[1],@r2_proto_key); @r2_proto_boost=stat_value(a[1],@r2_proto_key)
      elsif current_round==3
        set_primal_weather(e[2],191); set_terrain(:grassy,5,:ah_r3)
        @r3_mimic_types=a[3]&&a[3].respond_to?(:cg_pokemon_types) ? a[3].cg_pokemon_types.dup : []
        if e[2]&&e[2].respond_to?(:cg_pokemon_type_rate_percent)
          oldt=st.weather_turns; st.weather_turns=0; @r3_rate_without=e[2].cg_pokemon_type_rate_percent(:electric).to_i; st.weather_turns=oldt; @r3_rate_with=e[2].cg_pokemon_type_rate_percent(:electric).to_i
        end
      elsif current_round==4
        set_primal_weather(e[2],191); set_terrain(:grassy,5,:ah_r4); @r4_before_weather=st.weather; @r4_before_terrain=st.terrain
      end
    end

    def self.prepare_round_actions
      @actual=[]; prepare_round_preconditions; apply_test_speeds; a=test_allies; plan=current_plan; plan[:allies].each_with_index{|c,i|next if a[i]==nil; a[i].cg_round_actions=[make_action(a[i],c)]}
      log("ROUND "+current_round.to_s+" BEGIN "+plan[:name].to_s)
    end
    def self.record_execution(b)
      return unless active?||b; token="?"; if b.action&&b.action.guard?; token=(b.actor? ? "A" : "E")+b.index.to_s+":Guard"; elsif b.action&&b.action.skill?; sk=b.action.skill; token=(b.actor? ? "A" : "E")+b.index.to_s+":M"+move_id(sk).to_s; end; @actual.push(token); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+token)
    rescue; end
    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true; assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_s : "nil")); assert_true("Ability Batch AH defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s); assert_true("Scene_Battle uses Ability AH test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil")); assert_true("Ability AH ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s); assert_true("Ability AH starts with 4 active enemies",all_enemies.select{|x|x&&!x.hidden}.size==4); assert_true("Ability AH starts with hidden Teraform Zero reserve",all_enemies[4]&&all_enemies[4].hidden)
    end
    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies; st=field_state; exp=EXPECTED_EXECUTION_TOKENS[r]||[]; okorder=@actual==exp; @action_checks+=1 if okorder; assert_true("Round"+r.to_s+" execution order matches deterministic plan",okorder,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        hp=e[0] ? e[0].hp.to_i : @r1_e0_hp; ok1=hp==@r1_e0_hp.to_i; @weather_checks+=1 if ok1; assert_true("Primordial Sea nullifies real Fire Move damage",ok1,"hp="+@r1_e0_hp.to_s+"->"+hp.to_s)
        ok2=st&&st.weather==:heavy_rain; @weather_checks+=1 if ok2; assert_true("Heavy Rain rejects normal Sunny Day replacement",ok2,"weather="+(st ? st.weather.to_s : "nil"))
        pct=(@r1_quark_key==:spe ? ENV_SPEED_PERCENT : ENV_STAT_PERCENT); ok3=@r1_quark_base.to_i>0&&@r1_quark_boost.to_i==@r1_quark_base.to_i*pct/100; @stat_checks+=1 if ok3; assert_true("Quark Drive boosts highest stat on Electric Terrain",ok3,"stat="+@r1_quark_key.to_s+" base="+@r1_quark_base.to_s+" boosted="+@r1_quark_boost.to_s)
        ok4=@r1_mimic_types==[:electric]; @terrain_checks+=1 if ok4; assert_true("Mimicry changes holder to Electric on Electric Terrain",ok4,"types="+@r1_mimic_types.inspect)
        after=stat_stage(a[3],:accuracy); rec=records_for(298,:mycelium_bypass)[-1]||{}; ok5=after<@r1_accuracy_before.to_i&&!rec.empty?; @bypass_checks+=1 if ok5; assert_true("Mycelium Might status Move bypasses Clear Body",ok5,"record="+rec.inspect+" accuracy="+@r1_accuracy_before.to_s+"->"+after.to_s)
        ok6=@actual[-1]=="E3:M28"; @action_checks+=1 if ok6; assert_true("Mycelium Might acts last inside same priority bracket",ok6,"last="+@actual[-1].to_s)
        set_effective_ability(a[3],250)
      elsif r==2
        hp=e[1] ? e[1].hp.to_i : @r2_e1_hp; ok1=hp==@r2_e1_hp.to_i; @weather_checks+=1 if ok1; assert_true("Desolate Land nullifies real Water Move damage",ok1,"hp="+@r2_e1_hp.to_s+"->"+hp.to_s)
        ok2=st&&st.weather==:harsh_sun; @weather_checks+=1 if ok2; assert_true("Harsh Sun rejects normal Rain Dance replacement",ok2,"weather="+(st ? st.weather.to_s : "nil"))
        pct=(@r2_proto_key==:spe ? ENV_SPEED_PERCENT : ENV_STAT_PERCENT); ok3=@r2_proto_base.to_i>0&&@r2_proto_boost.to_i==@r2_proto_base.to_i*pct/100; @stat_checks+=1 if ok3; assert_true("Protosynthesis boosts highest stat under Harsh Sun",ok3,"stat="+@r2_proto_key.to_s+" base="+@r2_proto_base.to_s+" boosted="+@r2_proto_boost.to_s)
      elsif r==3
        component=ALBERT_CG::POKEMON_COMBAT.type_chart_percent(:electric,[:flying]).to_i; expected=component>0 ? (@r3_rate_without.to_i*100/component) : @r3_rate_without.to_i; expected=1 if expected<1; ok1=component>100&&@r3_rate_without.to_i>0&&@r3_rate_with.to_i==expected; @weather_checks+=1 if ok1; assert_true("Delta Stream removes one Flying weakness component",ok1,"rate="+@r3_rate_without.to_s+"->"+@r3_rate_with.to_s+" component="+component.to_s+" expected="+expected.to_s)
        ok2=@r3_mimic_types==[:grass]; @terrain_checks+=1 if ok2; assert_true("Mimicry follows Grassy Terrain as Grass type",ok2,"types="+@r3_mimic_types.inspect)
      elsif r==4
        switched=e[0]&&e[4]&&e[0].hidden&&!e[4].hidden; @lifecycle_checks+=1 if switched; assert_true("Teleport deploys hidden Teraform Zero reserve",switched,"E0_hidden="+(e[0] ? e[0].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        ok1=st&&st.weather==nil&&st.weather_turns.to_i==0; @weather_checks+=1 if ok1; assert_true("Teraform Zero clears strong weather on entry",ok1,"weather="+(st ? st.weather.to_s : "nil"))
        ok2=st&&st.terrain==nil&&st.terrain_turns.to_i==0; @terrain_checks+=1 if ok2; assert_true("Teraform Zero clears terrain on entry",ok2,"terrain="+(st ? st.terrain.to_s : "nil"))
        types=a[3]&&a[3].respond_to?(:cg_pokemon_types) ? a[3].cg_pokemon_types : []; ok3=types.include?(:flying)&&types!=[:grass]; @lifecycle_checks+=1 if ok3; assert_true("Mimicry restores original type when Teraform Zero clears terrain",ok3,"types="+types.inspect)
      end
      log("ROUND "+r.to_s+" END")
    end
    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|clear_runtime(b) if b}; end_target_context; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"; log("------------------------------------------------------------"); log("RESULT="+result); log("SUMMARY rounds=4 failures="+@failures.size.to_s+" ability_ah="+ability_covered_count.to_s+"/8 weather_checks="+@weather_checks.to_i.to_s+" terrain_checks="+@terrain_checks.to_i.to_s+" stat_checks="+@stat_checks.to_i.to_s+" bypass_checks="+@bypass_checks.to_i.to_s+" action_checks="+@action_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=101"); @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.end_target_context; if defined?(ALBERT_CG::ABILITY_AG_V2532); ALBERT_CG::ABILITY_AG_V2532.end_target_bypass; end; rescue; end
    def self.reset_suite; @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @weather_checks=0; @terrain_checks=0; @stat_checks=0; @bypass_checks=0; @action_checks=0; @lifecycle_checks=0; end
    def self.reset_log
      h="CG POKEMON ABILITY AH PRIMAL WEATHER + ADAPTIVE ENVIRONMENT AUTO REGRESSION v2.5.33c\r\n"+"START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+"RULE=Actual Scene_Battle; primal weather + Mimicry + Proto/Quark + Mycelium + Teraform Zero\r\n"+"BASELINE=v2.5.32a Ability Batch AG RPG Maker VX real-machine PASS; Move pending=0\r\n"+"ABILITY_CATALOG=373 BATCH_A_TO_AG_PASS=264 BATCH_AH=8 PENDING=101\r\n"+"RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+"------------------------------------------------------------\r\n"; File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue; end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AH_v2.5.33c") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e; @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; false; end
  end
end

ALBERT_CG::ABILITY_AH_V2533.register_handlers if defined?(ALBERT_CG::ABILITY_AH_V2533)

# Strong weather extends existing Weather Authority without replacing it.
if defined?(ALBERT_CG::ABILITY_WEATHER_V252)
  module ALBERT_CG; module ABILITY_WEATHER_V252; class << self
    alias cg_v2533ah_weather_active weather_active?
    def weather_active?(kind)
      if defined?(ALBERT_CG::ABILITY_AH_V2533) && !ALBERT_CG::ABILITY_AH_V2533.weather_suppressed?
        st=ALBERT_CG::ABILITY_AH_V2533.field_state
        return true if st&&st.weather_turns.to_i>0&&kind==:rain&&st.weather==:heavy_rain
        return true if st&&st.weather_turns.to_i>0&&kind==:sun&&st.weather==:harsh_sun
      end
      cg_v2533ah_weather_active(kind)
    end
    alias cg_v2533ah_set_weather set_weather
    def set_weather(kind,battler,ability_id,turns)
      if defined?(ALBERT_CG::ABILITY_AH_V2533)&&ALBERT_CG::ABILITY_AH_V2533.normal_weather_blocked?(kind)
        ALBERT_CG::ABILITY_AH_V2533.note_local(ALBERT_CG::ABILITY_AH_V2533.raw_ability_id(ALBERT_CG::ABILITY_AH_V2533.primal_holder_for(ALBERT_CG::ABILITY_AH_V2533.strong_weather_symbol)),ALBERT_CG::ABILITY_AH_V2533.primal_holder_for(ALBERT_CG::ABILITY_AH_V2533.strong_weather_symbol),:primal_weather_lock,{:blocked_weather=>kind})
        return false
      end
      cg_v2533ah_set_weather(kind,battler,ability_id,turns)
    end
  end; end; end
end

if defined?(ALBERT_CG::FIELD_V233)
  module ALBERT_CG; module FIELD_V233; class << self
    alias cg_v2533ah_damage_percent damage_percent
    def damage_percent(user,target,skill,type_id,damage_class,move_id)
      return ALBERT_CG::ABILITY_AH_V2533.strong_weather_damage_percent(lambda{cg_v2533ah_damage_percent(user,target,skill,type_id,damage_class,move_id)},user,target,skill,type_id,damage_class,move_id) if defined?(ALBERT_CG::ABILITY_AH_V2533)
      cg_v2533ah_damage_percent(user,target,skill,type_id,damage_class,move_id)
    end
    alias cg_v2533ah_apply_move apply_move
    def apply_move(user,target,move_id)
      if defined?(ALBERT_CG::ABILITY_AH_V2533)&&WEATHER_MOVES.has_key?(move_id.to_i)&&ALBERT_CG::ABILITY_AH_V2533.strong_weather?
        kind=WEATHER_MOVES[move_id.to_i]; if ALBERT_CG::ABILITY_AH_V2533.normal_weather_blocked?(kind); count_apply(move_id); ALBERT_CG::ABILITY_AH_V2533.note_local(ALBERT_CG::ABILITY_AH_V2533.raw_ability_id(ALBERT_CG::ABILITY_AH_V2533.primal_holder_for(ALBERT_CG::ABILITY_AH_V2533.strong_weather_symbol)),ALBERT_CG::ABILITY_AH_V2533.primal_holder_for(ALBERT_CG::ABILITY_AH_V2533.strong_weather_symbol),:primal_weather_lock,{:blocked_weather=>kind,:move_id=>move_id.to_i}); return true; end
      end
      cg_v2533ah_apply_move(user,target,move_id)
    end
    alias cg_v2533ah_turn_end_tick turn_end_tick
    def turn_end_tick
      cg_v2533ah_turn_end_tick
      if defined?(ALBERT_CG::ABILITY_AH_V2533) && ALBERT_CG::ABILITY_AH_V2533.strong_weather?
        kind=ALBERT_CG::ABILITY_AH_V2533.strong_weather_symbol
        holder=ALBERT_CG::ABILITY_AH_V2533.primal_holder_for(kind)
        state.weather_turns=ALBERT_CG::ABILITY_AH_V2533::STRONG_WEATHER_TURNS if holder!=nil
      end
    end
  end; end; end
end

class Game_Battler
  # v2.5.33c: FIELD_V233 對 damage_percent=0 仍會套用最低 1 傷害 clamp。
  # 強天氣的 Fire/Water nullification 是「招式無效」，所以在真正 skill_effect
  # 進入傷害／接觸 lifecycle 前直接取消該次 hit，保證 0 HP damage 且不誤觸 contact。
  alias cg_v2533c_primal_skill_effect skill_effect
  def skill_effect(user,skill)
    if defined?(ALBERT_CG::ABILITY_AH_V2533) && ALBERT_CG::ABILITY_AH_V2533.strong_weather_nullifies_skill?(skill)
      ALBERT_CG::ABILITY_AH_V2533.note_strong_weather_null(skill)
      clear_action_results
      @missed=false; @evaded=false; @skipped=false; @hp_damage=0; @mp_damage=0
      if @cg_last_damage_breakdown.is_a?(Hash)
        @cg_last_damage_breakdown[:field_percent]=0
        @cg_last_damage_breakdown[:damage]=0
      end
      return
    end
    cg_v2533c_primal_skill_effect(user,skill)
  end

  alias cg_v2533ah_primal_execute_damage execute_damage
  def execute_damage(user)
    before_hp=hp.to_i
    result=cg_v2533ah_primal_execute_damage(user)
    if before_hp>0 && hp.to_i<=0 && defined?(ALBERT_CG::ABILITY_AH_V2533)
      ALBERT_CG::ABILITY_AH_V2533.handle_primal_departure(self)
      ALBERT_CG::ABILITY_AH_V2533.clear_mimicry(self)
      self.instance_variable_set(:@cg_v2533ah_booster_active,false)
    end
    result
  end

  alias cg_v2533ah_type_rate cg_pokemon_type_rate_percent
  def cg_pokemon_type_rate_percent(attack_type)
    v=cg_v2533ah_type_rate(attack_type); return ALBERT_CG::ABILITY_AH_V2533.delta_adjust_rate(self,attack_type,v) if defined?(ALBERT_CG::ABILITY_AH_V2533); v
  rescue; cg_v2533ah_type_rate(attack_type); end

  # SPD did not previously own a generic :stat_query bridge. To avoid changing sealed Ability
  # behavior globally, this outer hook calls only Batch AH Proto/Quark handlers.
  alias cg_v2533ah_spd_env cg_spd
  def cg_spd
    value=cg_v2533ah_spd_env
    if defined?(ALBERT_CG::ABILITY_AH_V2533)
      aid=ALBERT_CG::ABILITY_AH_V2533.ability_id(self)
      ctx={:stat=>:spd,:value=>value.to_i,:raw_value=>value.to_i,:battler=>self}
      if aid==ALBERT_CG::ABILITY_AH_V2533::ABILITY_PROTOSYNTHESIS
        ALBERT_CG::ABILITY_AH_V2533.apply_protosynthesis(self,ctx)
      elsif aid==ALBERT_CG::ABILITY_AH_V2533::ABILITY_QUARK_DRIVE
        ALBERT_CG::ABILITY_AH_V2533.apply_quark_drive(self,ctx)
      end
      value=ctx[:value].to_i
    end
    value=1 if value.to_i<1; value.to_i
  rescue; cg_v2533ah_spd_env; end
end

# Mycelium Might extends AG target-only bypass only for Status Moves.
if defined?(ALBERT_CG::ABILITY_AG_V2532)
  module ALBERT_CG; module ABILITY_AG_V2532; class << self
    alias cg_v2533ah_begin_target_bypass begin_target_bypass
    def begin_target_bypass(user,target,skill=nil)
      if defined?(ALBERT_CG::ABILITY_AH_V2533)&&ALBERT_CG::ABILITY_AH_V2533.mycelium_status_user?(user,skill)&&target!=nil&&ALBERT_CG::ABILITY_AH_V2533.opposing?(user,target)
        raw=raw_ability_id(target); if raw.to_i>0
          @bypass_user=user; @bypass_target=target; @bypass_ability_id=ALBERT_CG::ABILITY_AH_V2533::ABILITY_MYCELIUM_MIGHT; @bypass_move_id=ALBERT_CG::ABILITY_AH_V2533.move_id(skill)
          ALBERT_CG::ABILITY_AH_V2533.formal_note(ALBERT_CG::ABILITY_AH_V2533::ABILITY_MYCELIUM_MIGHT,user,:mycelium_bypass,{:target_index=>(target.respond_to?(:index) ? target.index.to_i : -1),:target_ability=>raw,:move_id=>@bypass_move_id})
          return true
        end
      end
      cg_v2533ah_begin_target_bypass(user,target,skill)
    end
    alias cg_v2533ah_bypass_target bypass_target?
    def bypass_target?(battler)
      if @bypass_ability_id.to_i==ALBERT_CG::ABILITY_AH_V2533::ABILITY_MYCELIUM_MIGHT && @bypass_target!=nil && @bypass_user!=nil
        return true if battler.equal?(@bypass_target) && ALBERT_CG::ABILITY_AH_V2533.opposing?(@bypass_user,battler)
      end
      cg_v2533ah_bypass_target(battler)
    end
  end; end; end
end

class Game_BattleAction
  alias cg_v2533ah_priority_secondary_speed cg_priority_secondary_speed
  def cg_priority_secondary_speed
    normal=cg_v2533ah_priority_secondary_speed; return ALBERT_CG::ABILITY_AH_V2533.mycelium_priority_speed(self,normal) if defined?(ALBERT_CG::ABILITY_AH_V2533); normal
  rescue; cg_v2533ah_priority_secondary_speed; end
end

# Primal weather ends if its actual holder leaves by a path that fires switch-out lifecycle.
if defined?(ALBERT_CG::FORCE_SWITCH_V235)
  module ALBERT_CG; module FORCE_SWITCH_V235; class << self
    alias cg_v2533ah_clear_switch_out_volatile clear_switch_out_volatile
    def clear_switch_out_volatile(battler)
      ALBERT_CG::ABILITY_AH_V2533.handle_primal_departure(battler) if defined?(ALBERT_CG::ABILITY_AH_V2533)
      ALBERT_CG::ABILITY_AH_V2533.clear_mimicry(battler) if defined?(ALBERT_CG::ABILITY_AH_V2533)
      cg_v2533ah_clear_switch_out_volatile(battler)
    end
  end; end; end
end

# TEST-only harness. Formal hooks above remain active in ordinary battles.
class Scene_Battle < Scene_Base
  alias cg_v2533ah_execute_action execute_action
  def execute_action
    ALBERT_CG::ABILITY_AH_V2533.record_execution(@active_battler) if defined?(ALBERT_CG::ABILITY_AH_V2533)&&ALBERT_CG::ABILITY_AH_V2533.active?
    cg_v2533ah_execute_action
  end
  alias cg_v2533ah_test_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AH_V2533)&&ALBERT_CG::ABILITY_AH_V2533.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_AH_V2533.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_AH_V2533.finish_round_assertions; end
    end
    cg_v2533ah_test_turn_end
  end
  alias cg_v2533ah_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AH_V2533)&&ALBERT_CG::ABILITY_AH_V2533.active?; return cg_v2533ah_start_party_command; end
    cg_v2533ah_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_AH_V2533.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AH_V2533.finished?; ALBERT_CG::ABILITY_AH_V2533.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_AH_V2533.prepare_round_actions; start_main
  end
end

class Game_Battler
  alias cg_v2533ah_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AH_V2533)&&ALBERT_CG::ABILITY_AH_V2533.active?; v=@cg_priority_test_speed_override_ah; return v.to_i if v!=nil; end
    cg_v2533ah_priority_base_speed
  rescue; cg_v2533ah_priority_base_speed; end
end

class Game_Enemy < Game_Battler
  alias cg_v2533ah_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AH_V2533)&&ALBERT_CG::ABILITY_AH_V2533.active?; a=ALBERT_CG::ABILITY_AH_V2533.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end; end
    cg_v2533ah_enemy_make_action
  end
end

module ALBERT_CG; class << self
  alias cg_v2533ah_bootstrap_demo_party bootstrap_demo_party
  def bootstrap_demo_party
    r=cg_v2533ah_bootstrap_demo_party
    if defined?(ALBERT_CG::ABILITY_AH_V2533)&&ALBERT_CG::ABILITY_AH_V2533.active?
      ALBERT_CG::ABILITY_AH_V2533::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AH_V2533.configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_AH_V2533::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.cg_v237_clear_identity if h.respond_to?(:cg_v237_clear_identity); h.instance_variable_set(:@cg_master_ability_id,0); ALBERT_CG::ABILITY_AH_V2533.clear_runtime(h); end
    end
    r
  end
end; end

# Newest F11 only.
if defined?(ALBERT_CG::ABILITY_AG_V2532)
  module ALBERT_CG; module ABILITY_AG_V2532; def self.f11_trigger?; false; end; end; end
end
class Scene_Map < Scene_Base
  alias cg_v2533ah_scene_map_update update
  def update
    cg_v2533ah_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_AH_V2533); ALBERT_CG::ABILITY_AH_V2533.start_auto_test if ALBERT_CG::ABILITY_AH_V2533.f11_trigger?
  end
end
