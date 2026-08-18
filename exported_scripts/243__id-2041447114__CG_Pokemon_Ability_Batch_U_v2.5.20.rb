# RMVX_SCRIPT_INDEX: 243
# RMVX_SCRIPT_ID: 2041447114
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch U v2.5.20
# RMVX_SOURCE_SHA256: 2e1e382fb2181916b38c7e327646cb016f5e8c861b32b5e17ebc721d98c70f26

#==============================================================================
# ■ CG Pokemon Ability Batch U v2.5.20 - Weather / Status Guard + Fire Response TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.19a Ability Batch T RPG Maker VX 實機 PASS 為唯一基底，實作第二十一批
#  8 個 Ability。本批集中處理「天氣 residual、狀態防護、屬性吸收、Fire hit reaction」，
#  優先沿用既有 Ability Core、Damage Role Authority、Before/After Hit、Guard Authority
#  與 FIELD_V233 Weather Authority；不修改已封版 Move 937/937 與 Action Priority Core。
#
# 【本批 Ability】
#   85 Heatproof          耐熱：受到 Fire 直接傷害 x0.50；Burn residual 傷害減半。
#   87 Dry Skin           乾燥皮膚：Water 正傷害招式無效並回復 MaxHP 1/4；受到 Fire
#                         直接傷害 x1.25；Rain 每回合回復 1/8；Sun 每回合失去 1/8。
#   90 Poison Heal        毒療：Poison / Bad Poison residual 改為回復 MaxHP 1/8。
#  102 Leaf Guard         葉子防守：Sun 下阻止主要異常狀態。
#  175 Sweet Veil         甜幕：自己與同側 active ally 無法進入 Sleep。
#  257 Pastel Veil        粉彩護幕：自己與同側 active ally 無法中 Poison/Bad Poison；
#                         holder 進場時清除同側 active battler 的 Poison/Bad Poison。
#  270 Thermal Exchange   熱交換：被 Fire 正傷害命中後 ATK +1；Burn 無效。
#  273 Well-Baked Body    焦香之軀：Fire 正傷害招式無效，並 DEF +2。
#
# 【主要設定項】
#  TEST_TROOP_ID=723；HANDLED_ABILITY_IDS=8。
#  Coverage：160/373 -> 168/373，pending 213 -> 205。
#  HEATPROOF_FIRE_PERCENT=50；DRY_SKIN_FIRE_PERCENT=125；
#  DRY_SKIN_HEAL_DENOM=4；DRY_SKIN_WEATHER_DENOM=8；POISON_HEAL_DENOM=8。
#
# 【機制規則】
#  1. Heatproof / Dry Skin Fire modifier 走既有 :damage_modify defender role，不重算傷害。
#  2. Dry Skin Water absorb / Well-Baked Body 走既有 :before_hit，直接在正式 hit lifecycle
#     cancel 正傷害；Dry Skin 回復 1/4 MaxHP，Well-Baked Body DEF +2。
#  3. Thermal Exchange 走既有 :after_hit，只有真正造成 damage_done>0 的 Fire hit 才 ATK +1；
#     Burn immunity 走 Guard extension，與傷害 reaction 分離。
#  4. Leaf Guard / Sweet Veil / Pastel Veil / Thermal Exchange 的狀態防護都從既有
#     Guard Authority 的 block_state 入口擴充，不另造第二套狀態附加系統。
#  5. Sweet Veil / Pastel Veil 的 team guard 只掃同側 active holders；hidden / KO reserve
#     不提供隊伍防護，持續尊重 Ability suppression/override。
#  6. Pastel Veil 另註冊 :entry；真正進場時清除同側 active Pokémon 的 Poison/Bad Poison。
#  7. Heatproof / Poison Heal residual 只包覆現有 slip_damage_effect：測試對應 state 時暫時
#     從 lower residual chain 隔離該 state，再套正式 Ability residual，不重寫其他 Leech Seed、
#     Ingrain、Perish、Aqua Ring 等已 PASS 行為。
#  8. Dry Skin Rain/Sun residual 只在 FIELD_V233 既有 apply_weather_residual 完成後追加；
#     不改 Sand Force、Sandstorm/Hail 既有分支。
#  9. F11 Regression 使用 Actual Scene_Battle。Round2 使用正式 Teleport 部署 hidden
#     Pastel Veil reserve，Storage 不可被當 battle reserve 消耗。
# 10. TEST Convenience 僅限 F11；正式 Release 仍須恢復 emerged、BGM/BGS、正常焦點。
#
# 【可調參數】
#  HEATPROOF_FIRE_PERCENT、DRY_SKIN_FIRE_PERCENT、DRY_SKIN_HEAL_DENOM、
#  DRY_SKIN_WEATHER_DENOM、POISON_HEAL_DENOM、FIELD_TURNS。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫；Ability 自動由 damage / hit / state / weather lifecycle 處理。
#  開發測試：地圖按 F11，自動進 troop 723，跑三回合並輸出
#  Pokemon_Ability_U_AutoTest_v2_5_20.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：Sun 下 Toxic -> Leaf Guard、Hypnosis -> Sweet Veil；Ember 命中 Thermal Exchange；
#          Heatproof 吃 Ember、Dry Skin 吃 Water Gun。另以正式 residual probe 驗 Heatproof、
#          Poison Heal、Dry Skin Sun。
#  Round2：Rain residual 驗 Dry Skin；Ember 命中 Well-Baked Body，之後 E3 Teleport 換入
#          hidden Pastel Veil，進場立即治療已預先 Poison 的 E0，並驗 Storage isolation。
#  Round3：Pastel Veil team guard 擋 Toxic、Sweet Veil team guard 擋 Hypnosis、Thermal
#          Exchange 擋 Will-O-Wisp；Dry Skin 受到 Ember 驗 Fire x1.25。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchU"] = "2.5.20"

module ALBERT_CG
  module ABILITY_U_V2520
    VERSION = "2.5.20"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 723
    VK_F11 = 0x7A
    FIELD_TURNS = 5

    ABILITY_HEATPROOF        = 85
    ABILITY_DRY_SKIN         = 87
    ABILITY_POISON_HEAL      = 90
    ABILITY_LEAF_GUARD       = 102
    ABILITY_SWEET_VEIL       = 175
    ABILITY_PASTEL_VEIL      = 257
    ABILITY_THERMAL_EXCHANGE = 270
    ABILITY_WELL_BAKED_BODY  = 273
    HANDLED_ABILITY_IDS = [85,87,90,102,175,257,270,273]

    HEATPROOF_FIRE_PERCENT = 50
    DRY_SKIN_FIRE_PERCENT = 125
    DRY_SKIN_HEAL_DENOM = 4
    DRY_SKIN_WEATHER_DENOM = 8
    POISON_HEAL_DENOM = 8

    TEST_ALLIES = [
      {:dex=>25, :level=>40, :ability=>ABILITY_HEATPROOF,   :moves=>[92,52,92,150]},
      {:dex=>65, :level=>40, :ability=>ABILITY_DRY_SKIN,    :moves=>[95,150,95,150]},
      {:dex=>128,:level=>40, :ability=>ABILITY_POISON_HEAL, :moves=>[52,150,261,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>60,:ability=>ABILITY_LEAF_GUARD,       :moves=>[52,150,150,150]},
      {:dex=>94, :level=>60,:ability=>ABILITY_SWEET_VEIL,       :moves=>[55,150,52,150]},
      {:dex=>91, :level=>60,:ability=>ABILITY_THERMAL_EXCHANGE, :moves=>[150,150,150,150]},
      {:dex=>109,:level=>60,:ability=>ABILITY_WELL_BAKED_BODY,  :moves=>[150,100,150,150]},
      {:dex=>197,:level=>60,:ability=>ABILITY_PASTEL_VEIL,      :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"SUN_GUARDS_FIRE_REACTION_AND_WATER_ABSORB",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>92,:target=>0},
          {:kind=>:move,:move_id=>95,:target=>1},
          {:kind=>:move,:move_id=>52,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>52,:target=>1},
          1=>{:kind=>:move,:move_id=>55,:target=>2},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"RAIN_WELL_BAKED_AND_PASTEL_ENTRY",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>52,:target=>3},
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
        :name=>"TEAM_GUARDS_THERMAL_BURN_AND_DRY_FIRE",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>92,:target=>0},
          {:kind=>:move,:move_id=>95,:target=>0},
          {:kind=>:move,:move_id=>261,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>52,:target=>2},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,220,210,200, 190,180,170,160,0],
      :r2=>[10,220,210,200, 190,180,170,160,0],
      :r3=>[10,220,210,200, 180,190,170,0,160],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M92","A2:M95","A3:M52","E0:M52","E1:M55","E2:M150","E3:M150"],
      2=>["A0:Guard","A1:M52","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","A1:M92","A2:M95","A3:M261","E1:M52","E0:M150","E2:M150","E4:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.field_state; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233.state : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_U_AutoTest_v2_5_20.log"); end
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
      h="CG POKEMON ABILITY U WEATHER STATUS GUARD + FIRE RESPONSE AUTO REGRESSION v2.5.20\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; weather residual + state/team guard + fire response lifecycle\r\n"+
        "BASELINE=v2.5.19a Ability Batch T Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_T_PASS=160 BATCH_U=8 PENDING=205\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue
    end

    def self.type_id(sym)
      return 0 unless defined?(ALBERT_CG::POKEMON_COMBAT)
      return ALBERT_CG::POKEMON_COMBAT.type_id(sym).to_i if ALBERT_CG::POKEMON_COMBAT.respond_to?(:type_id)
      0
    rescue
      0
    end
    def self.ability_id(b); core==nil || b==nil ? 0 : core.ability_id(b).to_i; rescue; 0; end
    def self.battler_token(b); return "nil" if b==nil; (b.actor? ? "A" : "E")+b.index.to_s; rescue; "?"; end
    def self.same_side?(a,b); a!=nil && b!=nil && a.actor? == b.actor?; rescue; false; end
    def self.ratio(v,num,den); x=v.to_i; return x if x<=0; y=x*num.to_i/den.to_i; y=1 if y<1; y; end
    def self.weather_active?(sym); st=field_state; st!=nil && st.weather==sym && st.weather_turns.to_i>0; rescue; false; end
    def self.fire_type?(ctx); ctx!=nil && ctx[:type_id].to_i==type_id(:fire); rescue; false; end
    def self.skill_type_id(skill); skill!=nil && skill.respond_to?(:cg_pokemon_type_id) ? skill.cg_pokemon_type_id.to_i : 0; rescue; 0; end
    def self.damaging_skill?(skill); skill!=nil && skill.respond_to?(:base_damage) && skill.base_damage.to_i>0; rescue; false; end

    def self.note_local(aid,battler,kind,data=nil)
      return true unless active?
      @ability_trigger_counts[aid]=@ability_trigger_counts[aid].to_i+1
      rec={:ability=>aid,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless k==:battler||k==:user||k==:target||k==:skill}
      @records[aid]=[] if @records[aid]==nil; @records[aid].push(rec)
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
      log("ABILITY_U_TRIGGER ability="+aid.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
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

    def self.active_battlers
      core ? core.active_battlers : []
    rescue
      []
    end
    def self.same_side_holder(target,aid)
      active_battlers.each{|b|return b if same_side?(b,target) && ability_id(b)==aid.to_i}
      nil
    rescue
      nil
    end

    def self.primary_state_ids
      return [] unless defined?(ALBERT_CG::MOVE_EFFECT)
      m=ALBERT_CG::MOVE_EFFECT
      ids=[m::STATE_POISON,m::STATE_PARALYSIS,m::STATE_SLEEP,m::STATE_FREEZE,m::STATE_BURN]
      ids.push(m::STATE_BAD_POISON) if m.const_defined?(:STATE_BAD_POISON)
      ids
    rescue
      []
    end
    def self.poison_state_ids
      return [] unless defined?(ALBERT_CG::MOVE_EFFECT)
      m=ALBERT_CG::MOVE_EFFECT; ids=[m::STATE_POISON]; ids.push(m::STATE_BAD_POISON) if m.const_defined?(:STATE_BAD_POISON); ids
    rescue
      []
    end

    def self.custom_state_guard_info(target,state_id)
      return nil if target==nil || !defined?(ALBERT_CG::MOVE_EFFECT)
      sid=state_id.to_i; m=ALBERT_CG::MOVE_EFFECT; aid=ability_id(target)
      if aid==ABILITY_LEAF_GUARD && weather_active?(:sun) && primary_state_ids.include?(sid)
        return [ABILITY_LEAF_GUARD,target,:leaf_guard]
      end
      if sid==m::STATE_SLEEP
        h=same_side_holder(target,ABILITY_SWEET_VEIL); return [ABILITY_SWEET_VEIL,h,:sweet_veil] if h
      end
      if poison_state_ids.include?(sid)
        h=same_side_holder(target,ABILITY_PASTEL_VEIL); return [ABILITY_PASTEL_VEIL,h,:pastel_veil] if h
      end
      if sid==m::STATE_BURN && aid==ABILITY_THERMAL_EXCHANGE
        return [ABILITY_THERMAL_EXCHANGE,target,:thermal_burn_guard]
      end
      nil
    rescue
      nil
    end

    def self.note_custom_state_guard(info,target,state_id,source)
      return false if info==nil
      aid,holder,kind=info
      ctx={:target=>battler_token(target),:state_id=>state_id.to_i,:source=>source}
      formal_note(aid,holder,kind,ctx)
      true
    rescue
      true
    end

    def self.apply_heatproof(battler,ctx)
      return false unless ctx[:role]==:defender && fire_type?(ctx) && ctx[:damage].to_i>0 && ctx[:fixed_damage]!=true
      before=ctx[:damage].to_i; after=ratio(before,HEATPROOF_FIRE_PERCENT,100); ctx[:damage]=after
      note_local(ABILITY_HEATPROOF,battler,:heatproof_fire,{:before=>before,:after=>after,:move_id=>ctx[:move_id].to_i,:type_id=>ctx[:type_id].to_i})
      true
    rescue
      false
    end

    def self.apply_dry_skin_damage(battler,ctx)
      return false unless ctx[:role]==:defender && fire_type?(ctx) && ctx[:damage].to_i>0 && ctx[:fixed_damage]!=true
      before=ctx[:damage].to_i; after=ratio(before,DRY_SKIN_FIRE_PERCENT,100); ctx[:damage]=after
      note_local(ABILITY_DRY_SKIN,battler,:dry_skin_fire,{:before=>before,:after=>after,:move_id=>ctx[:move_id].to_i,:type_id=>ctx[:type_id].to_i})
      true
    rescue
      false
    end

    def self.apply_dry_skin_water(battler,ctx)
      skill=ctx[:skill]; user=ctx[:user]
      return false if battler==nil || user==nil || same_side?(battler,user) || !damaging_skill?(skill)
      return false unless skill_type_id(skill)==type_id(:water)
      before=battler.hp.to_i; heal=[battler.maxhp.to_i/DRY_SKIN_HEAL_DENOM,1].max
      battler.hp=[before+heal,battler.maxhp.to_i].min; actual=battler.hp.to_i-before
      ctx[:cancel]=true; ctx[:hp_damage]=-actual
      note_local(ABILITY_DRY_SKIN,battler,:dry_skin_water,{:before=>before,:after=>battler.hp.to_i,:heal=>actual,:move_id=>ctx[:move_id].to_i})
      true
    rescue
      false
    end

    def self.apply_thermal_exchange(battler,ctx)
      return false if battler==nil || ctx[:damage_done].to_i<=0 || skill_type_id(ctx[:skill])!=type_id(:fire)
      return false unless battler.respond_to?(:cg_change_stat_stage)
      before=battler.cg_stat_stage(:atk).to_i; delta=battler.cg_change_stat_stage(:atk,1).to_i; after=battler.cg_stat_stage(:atk).to_i
      return false if delta==0
      note_local(ABILITY_THERMAL_EXCHANGE,battler,:thermal_exchange,{:before=>before,:after=>after,:move_id=>ctx[:move_id].to_i})
      true
    rescue
      false
    end

    def self.apply_well_baked_body(battler,ctx)
      skill=ctx[:skill]; user=ctx[:user]
      return false if battler==nil || user==nil || same_side?(battler,user) || !damaging_skill?(skill)
      return false unless skill_type_id(skill)==type_id(:fire)
      before=battler.respond_to?(:cg_stat_stage) ? battler.cg_stat_stage(:def).to_i : 0
      battler.cg_change_stat_stage(:def,2) if battler.respond_to?(:cg_change_stat_stage)
      after=battler.respond_to?(:cg_stat_stage) ? battler.cg_stat_stage(:def).to_i : before
      ctx[:cancel]=true; ctx[:hp_damage]=0
      note_local(ABILITY_WELL_BAKED_BODY,battler,:well_baked_body,{:before=>before,:after=>after,:move_id=>ctx[:move_id].to_i})
      true
    rescue
      false
    end

    def self.apply_pastel_entry(holder,ctx)
      changed=[]
      active_battlers.each do |b|
        next unless same_side?(holder,b)
        poison_state_ids.each do |sid|
          if b.state?(sid)
            b.remove_state(sid); changed.push(battler_token(b)+":"+sid.to_s)
          end
        end
      end
      return false if changed.empty?
      note_local(ABILITY_PASTEL_VEIL,holder,:pastel_entry_cure,{:changed=>changed.join("|")})
      true
    rescue
      false
    end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_HEATPROOF,:damage_modify,self,:apply_heatproof)
      core.register(ABILITY_DRY_SKIN,:damage_modify,self,:apply_dry_skin_damage)
      core.register(ABILITY_DRY_SKIN,:before_hit,self,:apply_dry_skin_water)
      core.register(ABILITY_PASTEL_VEIL,:entry,self,:apply_pastel_entry)
      core.register(ABILITY_THERMAL_EXCHANGE,:after_hit,self,:apply_thermal_exchange)
      core.register(ABILITY_WELL_BAKED_BODY,:before_hit,self,:apply_well_baked_body)
      true
    end

    def self.with_states_suppressed(battler,ids)
      arr=battler.instance_variable_get(:@states)
      return yield if arr==nil
      removed=[]
      ids.each do |sid|
        if arr.include?(sid.to_i)
          arr.delete(sid.to_i); removed.push(sid.to_i)
        end
      end
      begin
        return yield
      ensure
        removed.each{|sid|arr.push(sid) unless arr.include?(sid)}
      end
    end

    def self.handle_slip_damage(battler)
      aid=ability_id(battler)
      if aid==ABILITY_HEATPROOF && defined?(ALBERT_CG::MOVE_EFFECT) && battler.state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
        result=nil; with_states_suppressed(battler,[ALBERT_CG::MOVE_EFFECT::STATE_BURN]){result=yield}
        if battler.hp.to_i>0
          dmg=[[battler.maxhp.to_i/16,1].max,battler.hp.to_i].min
          battler.hp-=dmg; battler.hp_damage=dmg if battler.respond_to?(:hp_damage=)
          formal_note(ABILITY_HEATPROOF,battler,:heatproof_burn_residual,{:damage=>dmg,:hp=>battler.hp.to_i})
        end
        return result
      elsif aid==ABILITY_POISON_HEAL && poison_state_ids.any?{|sid|battler.state?(sid)}
        result=nil; with_states_suppressed(battler,poison_state_ids){result=yield}
        if battler.hp.to_i>0
          gain=[[battler.maxhp.to_i/POISON_HEAL_DENOM,1].max,battler.maxhp.to_i-battler.hp.to_i].min
          battler.hp+=gain; battler.hp_damage=-gain if battler.respond_to?(:hp_damage=)
          formal_note(ABILITY_POISON_HEAL,battler,:poison_heal_residual,{:heal=>gain,:hp=>battler.hp.to_i})
        end
        return result
      end
      yield
    end

    def self.apply_dry_skin_weather_all
      st=field_state; return false if st==nil || st.weather_turns.to_i<=0
      return false unless st.weather==:rain || st.weather==:sun
      active_battlers.each do |b|
        next unless ability_id(b)==ABILITY_DRY_SKIN
        next if b.hp.to_i<=0
        if st.weather==:rain
          gain=[[b.maxhp.to_i/DRY_SKIN_WEATHER_DENOM,1].max,b.maxhp.to_i-b.hp.to_i].min
          if gain>0
            b.hp+=gain; b.hp_damage=-gain if b.respond_to?(:hp_damage=)
            formal_note(ABILITY_DRY_SKIN,b,:dry_skin_rain,{:heal=>gain,:hp=>b.hp.to_i,:weather=>:rain})
          end
        else
          dmg=[[b.maxhp.to_i/DRY_SKIN_WEATHER_DENOM,1].max,b.hp.to_i].min
          if dmg>0
            b.hp-=dmg; b.hp_damage=dmg if b.respond_to?(:hp_damage=)
            formal_note(ABILITY_DRY_SKIN,b,:dry_skin_sun,{:damage=>dmg,:hp=>b.hp.to_i,:weather=>:sun})
          end
        end
      end
      true
    rescue
      false
    end

    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime)
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
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability U v2.5.20 AutoRegression",ms)
    end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); else; a.clear; end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c); end
    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||TEST_SPEEDS[:r1]||[]
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_u,vals[i]) if b}
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
    def self.set_weather(sym)
      st=field_state; return false if st==nil
      st.weather=sym; st.weather_turns=(sym==nil ? 0 : FIELD_TURNS); true
    rescue
      false
    end

    def self.run_round1_residual_probes
      return if @r1_residual_probed
      @r1_residual_probed=true; a=test_allies
      if a[1]
        a[1].recover_all; a[1].add_state(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
        before=a[1].hp.to_i; expected=[[a[1].maxhp.to_i/16,1].max,before].min; a[1].slip_damage_effect; after=a[1].hp.to_i
        ok=after==before-expected; @residual_checks+=1 if ok; assert_true("Heatproof halves Burn residual to 1/16 MaxHP",ok,"before="+before.to_s+" after="+after.to_s+" expected_damage="+expected.to_s)
        a[1].remove_state(ALBERT_CG::MOVE_EFFECT::STATE_BURN); a[1].recover_all
      end
      if a[3]
        a[3].recover_all; a[3].hp=[a[3].maxhp.to_i/2,1].max; a[3].add_state(ALBERT_CG::MOVE_EFFECT::STATE_POISON)
        before=a[3].hp.to_i; expected=[[a[3].maxhp.to_i/POISON_HEAL_DENOM,1].max,a[3].maxhp.to_i-before].min; a[3].slip_damage_effect; after=a[3].hp.to_i
        ok=after==before+expected; @residual_checks+=1 if ok; assert_true("Poison Heal converts Poison residual to 1/8 MaxHP heal",ok,"before="+before.to_s+" after="+after.to_s+" expected_heal="+expected.to_s)
        a[3].remove_state(ALBERT_CG::MOVE_EFFECT::STATE_POISON); a[3].recover_all
      end
      if a[2] && defined?(ALBERT_CG::FIELD_V233)
        a[2].recover_all; set_weather(:sun); before=a[2].hp.to_i; expected=[[a[2].maxhp.to_i/DRY_SKIN_WEATHER_DENOM,1].max,before].min; ALBERT_CG::FIELD_V233.apply_weather_residual; after=a[2].hp.to_i
        ok=after==before-expected; @residual_checks+=1 if ok; assert_true("Dry Skin loses 1/8 MaxHP in Sun",ok,"before="+before.to_s+" after="+after.to_s+" expected_damage="+expected.to_s)
        a[2].recover_all
      end
    end

    def self.run_round2_rain_probe
      return if @r2_rain_probed
      @r2_rain_probed=true; a=test_allies; return unless a[2] && defined?(ALBERT_CG::FIELD_V233)
      set_weather(:rain); a[2].hp=[a[2].maxhp.to_i/2,1].max; before=a[2].hp.to_i; expected=[[a[2].maxhp.to_i/DRY_SKIN_WEATHER_DENOM,1].max,a[2].maxhp.to_i-before].min; ALBERT_CG::FIELD_V233.apply_weather_residual; after=a[2].hp.to_i
      ok=after==before+expected; @residual_checks+=1 if ok; assert_true("Dry Skin heals 1/8 MaxHP in Rain",ok,"before="+before.to_s+" after="+after.to_s+" expected_heal="+expected.to_s)
    end

    def self.prepare_round_preconditions
      clear_round_states; apply_test_speeds
      a=test_allies; e=all_enemies
      if current_round==1
        set_weather(:sun); run_round1_residual_probes; set_weather(:sun)
        if a[2]; a[2].hp=[a[2].maxhp.to_i-60,1].max; @r1_dry_water_before=a[2].hp.to_i; @r1_dry_water_expected=[a[2].maxhp.to_i/DRY_SKIN_HEAL_DENOM,1].max; end
      elsif current_round==2
        set_weather(:rain); run_round2_rain_probe
        if e[0]; e[0].add_state(ALBERT_CG::MOVE_EFFECT::STATE_POISON); @r2_poison_fixture=e[0].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON); end
        @r2_storage_before=storage_size
        @r2_well_hp_before=e[3] ? e[3].hp.to_i : 0
      elsif current_round==3
        set_weather(nil)
      end
    end
    def self.prepare_round_actions
      p=current_plan; return false if p==nil; prepare_round_preconditions; @actual=[]; log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s)
      test_allies.each_with_index do |b,i|; next if b==nil||b.hp.to_i<=0; ac=make_action(b,p[:allies][i]); if b.respond_to?(:cg_round_actions); b.cg_round_actions.clear; b.cg_round_actions.push(ac); end; b.cg_assign_action(ac) if b.respond_to?(:cg_assign_action); b.instance_variable_set(:@action,ac) unless b.respond_to?(:cg_assign_action); end; true
    end
    def self.record_execution(b)
      return unless active?&&b; a=b.action; pre=b.actor? ? "A" : "E"; tok=if a&&a.guard?; pre+b.index.to_s+":Guard" elsif a&&a.skill?; pre+b.index.to_s+":M"+ALBERT_CG::MOVE_EFFECT.move_id(a.skill).to_i.to_s else; pre+b.index.to_s+":Other" end; @actual.push(tok); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    rescue
    end
    def self.records_for(aid,kind=nil); a=@records[aid]||[]; a.select{|r|kind==nil||r[:kind]==kind}; end
    def self.record_ratio_ok?(aid,kind,num,den); records_for(aid,kind).any?{|r|r[:before].to_i>0 && r[:after].to_i==ratio(r[:before],num,den)}; end

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      tid=($game_troop&&$game_troop.troop) ? $game_troop.troop.id.to_i : 0
      assert_true("Ability Catalog count=373",core&&core.catalog_count==373,"actual="+(core ? core.catalog_count.to_s : "nil"))
      assert_true("Ability Batch U defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability U test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability U ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability U starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden},"")
      assert_true("Ability U starts with 1 hidden Pastel Veil reserve",all_enemies[4]&&all_enemies[4].hidden,"E4_hidden="+(all_enemies[4] ? all_enemies[4].hidden.to_s : "nil"))
    end

    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]; order=@actual==exp
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",order,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        hp=record_ratio_ok?(ABILITY_HEATPROOF,:heatproof_fire,HEATPROOF_FIRE_PERCENT,100); @damage_checks+=1 if hp; assert_true("Heatproof halves incoming Fire direct damage",hp,(records_for(ABILITY_HEATPROOF,:heatproof_fire)[-1]||{}).inspect)
        dsrec=records_for(ABILITY_DRY_SKIN,:dry_skin_water)[-1]||{}; expected=[@r1_dry_water_before.to_i+@r1_dry_water_expected.to_i,a[2].maxhp.to_i].min; dsw=a[2]&&a[2].hp.to_i==expected&&!dsrec.empty?; @absorb_checks+=1 if dsw; assert_true("Dry Skin cancels Water damage and heals 1/4 MaxHP",dsw,"expected_hp="+expected.to_s+" actual_hp="+(a[2] ? a[2].hp.to_i.to_s : "nil")+" record="+dsrec.inspect)
        lg=e[0]&&!e[0].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON) && ( !ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON) || !e[0].state?(ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON) ) && !records_for(ABILITY_LEAF_GUARD,:leaf_guard).empty?; @state_checks+=1 if lg; assert_true("Leaf Guard blocks Toxic in Sun",lg,(records_for(ABILITY_LEAF_GUARD,:leaf_guard)[-1]||{}).inspect)
        sv=e[1]&&!e[1].state?(ALBERT_CG::MOVE_EFFECT::STATE_SLEEP)&&!records_for(ABILITY_SWEET_VEIL,:sweet_veil).empty?; @state_checks+=1 if sv; assert_true("Sweet Veil blocks Sleep on holder",sv,(records_for(ABILITY_SWEET_VEIL,:sweet_veil)[-1]||{}).inspect)
        tr=records_for(ABILITY_THERMAL_EXCHANGE,:thermal_exchange)[-1]||{}; trok=tr[:before].to_i==0&&tr[:after].to_i==1; @reaction_checks+=1 if trok; assert_true("Thermal Exchange raises ATK +1 after real Fire damage",trok,tr.inspect)
      elsif r==2
        wb=records_for(ABILITY_WELL_BAKED_BODY,:well_baked_body)[-1]||{}; wbok=e[3]&&e[3].hp.to_i==@r2_well_hp_before.to_i&&wb[:after].to_i-wb[:before].to_i==2; @absorb_checks+=1 if wbok; @reaction_checks+=1 if wbok; assert_true("Well-Baked Body cancels Fire and raises DEF +2",wbok,"hp_before="+@r2_well_hp_before.to_s+" hp_after="+(e[3] ? e[3].hp.to_i.to_s : "nil")+" record="+wb.inspect)
        sw=e[3]&&e[4]&&e[3].hidden&&!e[4].hidden; @lifecycle_checks+=1 if sw; assert_true("Teleport deploys hidden Pastel Veil reserve",sw,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        cure=@r2_poison_fixture==true && e[0] && !e[0].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON) && !records_for(ABILITY_PASTEL_VEIL,:pastel_entry_cure).empty?; @entry_checks+=1 if cure; assert_true("Pastel Veil entry cures poisoned active ally",cure,(records_for(ABILITY_PASTEL_VEIL,:pastel_entry_cure)[-1]||{}).inspect)
        sa=storage_size; stor=sa==@r2_storage_before.to_i; @lifecycle_checks+=1 if stor; assert_true("Pastel Veil reserve switch does not consume Storage Pokemon",stor,"before="+@r2_storage_before.to_s+" after="+sa.to_s)
      elsif r==3
        bad_sid=(ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON) ? ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON : 0)
        poison_ok=e[0]&&!e[0].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON)&&(bad_sid<=0||!e[0].state?(bad_sid))&&!records_for(ABILITY_PASTEL_VEIL,:pastel_veil).empty?; @state_checks+=1 if poison_ok; assert_true("Pastel Veil team guard blocks Toxic on ally",poison_ok,(records_for(ABILITY_PASTEL_VEIL,:pastel_veil)[-1]||{}).inspect)
        sleep_ok=e[0]&&!e[0].state?(ALBERT_CG::MOVE_EFFECT::STATE_SLEEP)&&records_for(ABILITY_SWEET_VEIL,:sweet_veil).size>=2; @state_checks+=1 if sleep_ok; assert_true("Sweet Veil team guard blocks Sleep on ally",sleep_ok,(records_for(ABILITY_SWEET_VEIL,:sweet_veil)[-1]||{}).inspect)
        burn_ok=e[2]&&!e[2].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN)&&!records_for(ABILITY_THERMAL_EXCHANGE,:thermal_burn_guard).empty?; @state_checks+=1 if burn_ok; assert_true("Thermal Exchange blocks Burn",burn_ok,(records_for(ABILITY_THERMAL_EXCHANGE,:thermal_burn_guard)[-1]||{}).inspect)
        df=record_ratio_ok?(ABILITY_DRY_SKIN,:dry_skin_fire,DRY_SKIN_FIRE_PERCENT,100); @damage_checks+=1 if df; assert_true("Dry Skin increases incoming Fire damage x1.25",df,(records_for(ABILITY_DRY_SKIN,:dry_skin_fire)[-1]||{}).inspect)
        stable=e[4]&&!e[4].hidden&&e[4].hp.to_i>0; assert_true("Pastel Veil reserve remains active through Round3",stable,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" hp="+(e[4] ? e[4].hp.to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end
    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_u,nil) if b}; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"; log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_u="+ability_covered_count.to_s+"/8 state_checks="+@state_checks.to_i.to_s+" damage_checks="+@damage_checks.to_i.to_s+" absorb_checks="+@absorb_checks.to_i.to_s+" residual_checks="+@residual_checks.to_i.to_s+" reaction_checks="+@reaction_checks.to_i.to_s+" entry_checks="+@entry_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=205")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @state_checks=0; @damage_checks=0; @absorb_checks=0; @residual_checks=0; @reaction_checks=0; @entry_checks=0; @lifecycle_checks=0; @r1_residual_probed=false; @r2_rain_probed=false; @r1_dry_water_before=0; @r1_dry_water_expected=0; @r2_storage_before=0; @r2_poison_fixture=false; @r2_well_hp_before=0
    end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; ALBERT_CG::UNIQUE_I_V242.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_I_V242)&&ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes); @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_U_v2.5.20") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

ALBERT_CG::ABILITY_U_V2520.register_handlers if defined?(ALBERT_CG::ABILITY_V250)
if defined?(ALBERT_CG::ABILITY_T_V2519)
  module ALBERT_CG; module ABILITY_T_V2519; def self.f11_trigger?; false; end; end; end
end

#==============================================================================
# ■ Formal State Guard extension
#==============================================================================
if defined?(ALBERT_CG::ABILITY_GUARD_V251)
  module ALBERT_CG
    module ABILITY_GUARD_V251
      class << self
        alias cg_v2520u_guard_state guard_state?
        def guard_state?(battler,state_id)
          return true if defined?(ALBERT_CG::ABILITY_U_V2520) && ALBERT_CG::ABILITY_U_V2520.custom_state_guard_info(battler,state_id)!=nil
          cg_v2520u_guard_state(battler,state_id)
        end
        alias cg_v2520u_block_state block_state
        def block_state(battler,state_id,source=:unknown)
          if defined?(ALBERT_CG::ABILITY_U_V2520)
            info=ALBERT_CG::ABILITY_U_V2520.custom_state_guard_info(battler,state_id)
            if info!=nil
              ALBERT_CG::ABILITY_U_V2520.note_custom_state_guard(info,battler,state_id,source)
              return true
            end
          end
          cg_v2520u_block_state(battler,state_id,source)
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal residual extension: Heatproof / Poison Heal
#==============================================================================
class Game_Battler
  alias cg_v2520u_slip_damage_effect slip_damage_effect
  def slip_damage_effect
    if defined?(ALBERT_CG::ABILITY_U_V2520)
      return ALBERT_CG::ABILITY_U_V2520.handle_slip_damage(self){cg_v2520u_slip_damage_effect}
    end
    cg_v2520u_slip_damage_effect
  end
end

#==============================================================================
# ■ Formal weather residual extension: Dry Skin
#==============================================================================
if defined?(ALBERT_CG::FIELD_V233)
  module ALBERT_CG
    module FIELD_V233
      class << self
        alias cg_v2520u_apply_weather_residual apply_weather_residual
        def apply_weather_residual
          r=cg_v2520u_apply_weather_residual
          ALBERT_CG::ABILITY_U_V2520.apply_dry_skin_weather_all if defined?(ALBERT_CG::ABILITY_U_V2520)
          r
        end
      end
    end
  end
end

#==============================================================================
# ■ TEST-only deterministic Scene_Battle harness
#==============================================================================
class Game_Battler
  alias cg_v2520u_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil); return 100 if defined?(ALBERT_CG::ABILITY_U_V2520)&&ALBERT_CG::ABILITY_U_V2520.active?; cg_v2520u_ability_calc_hit(user,obj); end
  alias cg_v2520u_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil); return 0 if defined?(ALBERT_CG::ABILITY_U_V2520)&&ALBERT_CG::ABILITY_U_V2520.active?; cg_v2520u_ability_calc_eva(user,obj); end
  alias cg_v2520u_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_U_V2520)&&ALBERT_CG::ABILITY_U_V2520.active?
      v=@cg_priority_test_speed_override_u; return v.to_i if v!=nil
    end
    cg_v2520u_ability_priority_base_speed
  rescue
    cg_v2520u_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2520u_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_U_V2520)&&ALBERT_CG::ABILITY_U_V2520.active?
      a=ALBERT_CG::ABILITY_U_V2520.forced_enemy_action(self)
      if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end
    end
    cg_v2520u_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2520u_ability_execute_action execute_action
  def execute_action
    b=@active_battler; ALBERT_CG::ABILITY_U_V2520.record_execution(b) if defined?(ALBERT_CG::ABILITY_U_V2520)&&ALBERT_CG::ABILITY_U_V2520.active?; cg_v2520u_ability_execute_action
  end
  alias cg_v2520u_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_U_V2520)&&ALBERT_CG::ABILITY_U_V2520.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_U_V2520.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_U_V2520.finish_round_assertions; end
    end
    cg_v2520u_ability_turn_end
  end
  alias cg_v2520u_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_U_V2520)&&ALBERT_CG::ABILITY_U_V2520.active?; return cg_v2520u_ability_start_party_command; end
    cg_v2520u_ability_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_U_V2520.assert_bootstrap_once
    if ALBERT_CG::ABILITY_U_V2520.finished?; ALBERT_CG::ABILITY_U_V2520.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_U_V2520.prepare_round_actions; start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2520u_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2520u_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_U_V2520)&&ALBERT_CG::ABILITY_U_V2520.active?
        ALBERT_CG::ABILITY_U_V2520::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_U_V2520.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_U_V2520::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2520u_ability_scene_map_update update
  def update; cg_v2520u_ability_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_U_V2520); ALBERT_CG::ABILITY_U_V2520.start_auto_test if ALBERT_CG::ABILITY_U_V2520.f11_trigger?; end
end
