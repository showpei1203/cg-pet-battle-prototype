# RMVX_SCRIPT_INDEX: 249
# RMVX_SCRIPT_ID: 252600002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AA v2.5.26c
# RMVX_SOURCE_SHA256: 7dc5815a322d080627582bd39f31c121a6507a14225a06df9ed1cde24804b5e2

#==============================================================================
# ■ CG Pokemon Ability Batch AA v2.5.26c - RGSS2 Boot-Safe Deterministic Fixture TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.25 Ability Batch Z RPG Maker VX 實機 PASS 為唯一正式基底，新增 8 個
#  尚未覆蓋的主系列 Ability，集中處理「Ghost immunity bypass」、「Status Move 反射」、
#  「Poison type immunity bypass」、「能力下降反射」、「Charge 反應」與「對手能力提升複製」。
#  不修改已 PASS Move Runtime 937/937，也不重開 Move Phase。
#  v2.5.26a 已修正 Opportunist lifecycle assertion：觸發當下 -1→+1，Teleport 換出後 stage=0。
#  v2.5.26c 的 Electromorphosis fixture 已改為必中 Aura Sphere 396。
#  v2.5.26c 不改 Formal Runtime，只將新增 Regression 判定改寫為 RGSS2 / Ruby 1.8
#  保守語法，並以短專案路徑封裝，排除 v2.5.26c 啟動時「載入腳本失敗」的
#  啟動層相容性／路徑因素；實際戰鬥規則與 Round2 fixture 維持 26b 設計。
#
# 【本批 Ability】
#  113 Scrappy / 膽量：Normal / Fighting Move 可命中 Ghost；依現代規則免疫 Intimidate。
#  156 Magic Bounce / 魔法鏡：沿用既有 Magic Coat reflectability，把可反射的單體 Status Move
#                            反射回原使用者；不反射已被 Magic Coat / Magic Bounce 反射的 Action。
#  212 Corrosion / 腐蝕：使用者的 Poison ailment Move 可繞過 Poison / Steel 的屬性免疫；
#                        仍尊重既有主要異常、Ability Guard、命中與 ailment chance。
#  240 Mirror Armor / 鏡甲：外部 Move / Ability 造成的負向 stage change 反射回來源。
#  277 Wind Power / 風力發電：成功受到 Wind Move，或同側 Tailwind 生效時取得 Charge；
#                             下一次造成正傷害的 Electric Move x2，然後消耗 Charge。
#  280 Electromorphosis / 電力轉換：受到實際攻擊傷害後取得 Charge；下一次造成正傷害的
#                                   Electric Move x2，然後消耗 Charge。
#  290 Opportunist / 跟風：active 對手能力階級上升時，複製相同 stat 與實際上升量。
#  299 Mind's Eye / 心眼：Normal / Fighting Move 可命中 Ghost；Accuracy 不會被外部降低；
#                         命中判定忽略目標正向 Evasion stage。
#
# 【主要設定項】
#  TEST_TROOP_ID=729；HANDLED_ABILITY_IDS=8。
#  Static coverage：208/373 -> 216/373，pending 165 -> 157。
#  CHARGE_PERCENT=200。
#
# 【機制規則】
#  1. Scrappy / Mind's Eye 不修改永久 Type；只在該次 skill_effect 的 user/target/skill context
#     內重算 Normal/Fighting 對 Ghost 的 Type Chart，保留第二屬性、State type modifier 與
#     其他既有 type-rate source。
#  2. Magic Bounce 直接重用 UNIQUE_H_V241.magic_coat_reflectable?。targeting 階段只改
#     Game_BattleAction targets；Ability Popup 使用 Batch Y 已證實安全的 pre-action presentation
#     方式，避免 wait(45) 讓 stale Tankentai Idle End 結束尚未 set_action 的新技能。
#  3. Corrosion 不重寫 Toxic / Poison；只在本次 ailment application context 將 Poison/Steel
#     的 ailment type immunity 視為 false，之後仍走既有 v2.3.1 Bad Poison、Guard Authority、
#     add_state / state record 正式入口。
#  4. Mirror Armor 只處理 Stat Guard Authority 判定為 external 的負向 stage change；反射時
#     以 guard flag 阻止 Mirror Armor 無限互彈，反射後仍讓來源自己的 Clear Body 等 Guard 生效。
#  5. Wind Power / Electromorphosis 共用 battle-local Charge token；Charge 只在真正 positive
#     Electric damage 的 :damage_modify attacker role 消耗，不會因 miss / immune / Status Move 浪費。
#  6. Wind Power 的 Wind Move mapping 沿用 Batch Z 已封版 WIND_IDENTIFIERS；Tailwind 仍沿用
#     FIELD_V233.apply_move 成功結果，不自行建立第二套 Field。
#  7. Opportunist 只監看實際 positive stage delta；hidden / KO holder 不參與，copy guard 防止
#     Opportunist 複製出的提升再反向觸發另一輪。
#  8. Mind's Eye 的 Accuracy guard / Evasion ignore 直接延伸 v2.5.6 Stat Guard / Keen Eye Authority，
#     不另寫命中公式。Scrappy 的 Intimidate immunity 直接延伸 v2.5.5 Status Interaction Authority。
#
# 【可調參數】
#  TEST_TROOP_ID、TEST_SPEEDS、ROUND_PLANS、CHARGE_PERCENT。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，自動進 troop 729，跑三回合並輸出
#  Pokemon_Ability_AA_AutoTest_v2_5_26b.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：A2 Gust -> Wind Power E1 取得 Charge；A1 Scrappy Tackle 真正命中 Ghost E1；
#          A3 Toxic -> Poison-type E3 由 Corrosion 允許劇毒；E0 Taunt -> Magic Bounce A2 反射；
#          E1 Thunderbolt 使用 Charge x2。
#  Round2：A3 Growl -> Mirror Armor E0 反射 ATK drop；A1 Swords Dance -> Opportunist E3 複製 +2；
#          A2 Aura Sphere(必中) -> Electromorphosis E2 取得 Charge，E2 Thunderbolt x2；E3 Teleport -> E4。
#  Round3：先把 A2 Evasion 設為 +6；A3 Sand Attack -> Mind's Eye E4 的 Accuracy 不下降；
#          E4 Tackle 仍忽略 +6 Evasion 並穿過 A2 Ghost immunity；回合後正式 Tailwind probe
#          再驗 Wind Power 取得 Charge。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAA"] = "2.5.26c"

module ALBERT_CG
  module ABILITY_AA_V2526
    VERSION = "2.5.26c"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 729
    VK_F11 = 0x7A

    ABILITY_SCRAPPY          = 113
    ABILITY_MAGIC_BOUNCE     = 156
    ABILITY_CORROSION        = 212
    ABILITY_MIRROR_ARMOR     = 240
    ABILITY_WIND_POWER       = 277
    ABILITY_ELECTROMORPHOSIS = 280
    ABILITY_OPPORTUNIST      = 290
    ABILITY_MINDS_EYE        = 299
    HANDLED_ABILITY_IDS = [113,156,212,240,277,280,290,299]

    CHARGE_PERCENT = 200

    TEST_ALLIES = [
      {:dex=>128,:level=>40,:ability=>ABILITY_SCRAPPY,      :moves=>[33,14,150,150]},
      {:dex=>94, :level=>40,:ability=>ABILITY_MAGIC_BOUNCE, :moves=>[16,396,150,150]},
      {:dex=>109,:level=>40,:ability=>ABILITY_CORROSION,     :moves=>[92,45,28,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>50,:ability=>ABILITY_MIRROR_ARMOR,     :moves=>[269,150,150,150]},
      {:dex=>92, :level=>50,:ability=>ABILITY_WIND_POWER,       :moves=>[85,150,150,150]},
      {:dex=>65, :level=>50,:ability=>ABILITY_ELECTROMORPHOSIS, :moves=>[150,85,150,150]},
      {:dex=>1,  :level=>50,:ability=>ABILITY_OPPORTUNIST,      :moves=>[150,100,150,150]},
      {:dex=>197,:level=>50,:ability=>ABILITY_MINDS_EYE,        :moves=>[150,150,33,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"SCRAPPY_MAGIC_BOUNCE_CORROSION_WIND_POWER",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>1},
          {:kind=>:move,:move_id=>16,:target=>1},
          {:kind=>:move,:move_id=>92,:target=>3},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>269,:target=>2},
          1=>{:kind=>:move,:move_id=>85,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"MIRROR_OPPORTUNIST_ELECTROMORPHOSIS_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>14,:target=>1},
          {:kind=>:move,:move_id=>396,:target=>2},
          {:kind=>:move,:move_id=>45,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>85,:target=>2},
          3=>{:kind=>:move,:move_id=>100,:target=>3},
        }
      },
      {
        :name=>"MINDS_EYE_ACCURACY_EVASION_GHOST",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>28,:target=>4},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>33,:target=>2},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,320,330,310, 300,290,280,270,0],
      :r2=>[10,320,310,330, 260,250,300,10,0],
      :r3=>[10,250,240,330, 230,220,210,0,320],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A2:M16","A1:M33","A3:M92","E0:M269","E1:M85","E2:M150","E3:M150"],
      2=>["A0:Guard","A3:M45","A1:M14","A2:M396","E2:M85","E0:M150","E1:M150","E3:M100"],
      3=>["A0:Guard","A3:M28","E4:M33","A1:M150","A2:M150","E0:M150","E1:M150","E2:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.field; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233 : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AA_AutoTest_v2_5_26b.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.ability_id(b); core==nil || b==nil ? 0 : core.ability_id(b).to_i; rescue; 0; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill!=nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.move_row(mid); master ? master.move(mid.to_i) : nil; rescue; nil; end
    def self.move_identifier(mid); r=move_row(mid); r==nil ? "" : r[0].to_s; rescue; ""; end
    def self.same_side?(a,b); a!=nil && b!=nil && a.respond_to?(:actor?) && b.respond_to?(:actor?) && a.actor? == b.actor?; rescue; false; end
    def self.opposing?(a,b); a!=nil && b!=nil && !same_side?(a,b); rescue; false; end
    def self.active_battlers; core ? core.active_battlers : []; rescue; []; end
    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end
    def self.ratio(v,num,den); x=v.to_i; return 0 if x<=0; y=x*num.to_i/den.to_i; y=1 if y<1; y; rescue; v.to_i; end
    def self.ghost_type?(b); b!=nil && b.respond_to?(:cg_pokemon_types) && b.cg_pokemon_types.include?(:ghost); rescue; false; end
    def self.poison_or_steel_type?(b); b!=nil && b.respond_to?(:cg_pokemon_types) && (b.cg_pokemon_types.include?(:poison)||b.cg_pokemon_types.include?(:steel)); rescue; false; end
    def self.type_key(value); defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_key(value) : nil; rescue; nil; end
    def self.skill_type_key(skill); skill!=nil && skill.respond_to?(:cg_pokemon_type_id) ? type_key(skill.cg_pokemon_type_id) : nil; rescue; nil; end
    def self.wind_identifiers
      return ALBERT_CG::ABILITY_Z_V2525::WIND_IDENTIFIERS if defined?(ALBERT_CG::ABILITY_Z_V2525)
      ["air-cutter","bleakwind-storm","blizzard","fairy-wind","gust","heat-wave","hurricane","icy-wind","petal-blizzard","sandsear-storm","sandstorm","springtide-storm","tailwind","twister","whirlwind","wildbolt-storm"]
    end
    def self.wind_move?(skill); wind_identifiers.include?(move_identifier(move_id(skill))); rescue; false; end

    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else
        text=label.to_s+(detail==nil ? "" : " "+detail.to_s)
        @failures.push(text); log("ASSERT FAIL "+text)
      end
      condition
    end

    def self.reset_log
      h="CG POKEMON ABILITY AA REFLECT + BYPASS + CHARGE REACTION AUTO REGRESSION v2.5.26c\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; reflect/bypass + shared Charge token + reactive stat lifecycle\r\n"+
        "BASELINE=v2.5.25 Ability Batch Z Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_Z_PASS=208 BATCH_AA=8 PENDING=157\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}
      File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue
    end

    def self.note_local(aid,battler,kind,data=nil)
      return true unless active?
      @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1
      rec={:ability=>aid.to_i,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless k==:battler||k==:user||k==:target||k==:skill||k==:action}
      @records[aid.to_i]=[] if @records[aid.to_i]==nil; @records[aid.to_i].push(rec)
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
      log("ABILITY_AA_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
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

    def self.formal_note_pre_action_safe(aid,holder,kind,ctx=nil,acting_battler=nil)
      return formal_note(aid,holder,kind,ctx) if holder==nil
      suspended=acting_battler==nil ? holder : acting_battler
      was_active=suspended!=nil && suspended.respond_to?(:active) ? (suspended.active ? true : false) : false
      begin
        suspended.active=false if suspended!=nil && was_active && suspended.respond_to?(:active=)
        suspended.play=0 if suspended!=nil && suspended.respond_to?(:play=)
        result=formal_note(aid,holder,kind,ctx)
        suspended.play=0 if suspended!=nil && suspended.respond_to?(:play=)
        result
      ensure
        suspended.active=true if suspended!=nil && was_active && suspended.respond_to?(:active=)
      end
    rescue
      begin
        suspended.active=true if suspended!=nil && was_active && suspended.respond_to?(:active=)
      rescue
      end
      true
    end

    #--------------------------------------------------------------------------
    # Scrappy / Mind's Eye type bypass context
    #--------------------------------------------------------------------------
    def self.hit_context_stack; @hit_context_stack=[] if @hit_context_stack==nil; @hit_context_stack; end
    def self.with_hit_context(user,target,skill)
      hit_context_stack.push({:user=>user,:target=>target,:skill=>skill})
      begin
        yield
      ensure
        hit_context_stack.pop
      end
    end
    def self.current_hit_context; s=hit_context_stack; s.empty? ? nil : s[-1]; rescue; nil; end

    def self.ghost_bypass_info(target,attack_type)
      ctx=current_hit_context; return nil if ctx==nil || target==nil || !target.equal?(ctx[:target])
      user=ctx[:user]; skill=ctx[:skill]; return nil if user==nil || skill==nil || !ghost_type?(target)
      aid=ability_id(user); return nil unless aid==ABILITY_SCRAPPY || aid==ABILITY_MINDS_EYE
      key=type_key(attack_type); return nil unless key==:normal || key==:fighting
      [aid,user,skill,key]
    rescue
      nil
    end

    def self.filtered_ghost_rate(target,attack_type)
      key=type_key(attack_type); return nil if key==nil || target==nil
      types=target.respond_to?(:cg_pokemon_types) ? (target.cg_pokemon_types||[]) : []
      filtered=types.reject{|t|type_key(t)==:ghost}
      rate=filtered.empty? ? 100 : ALBERT_CG::POKEMON_COMBAT.type_chart_percent(key,filtered)
      intrinsic=target.respond_to?(:cg_intrinsic_type_rate_percent) ? target.cg_intrinsic_type_rate_percent(key).to_i : 100
      rate=rate*intrinsic/100
      if target.respond_to?(:cg_type_rate_sources) && target.respond_to?(:cg_note_type_rate)
        for source in target.cg_type_rate_sources
          rate=rate*target.cg_note_type_rate(source,key).to_i/100
          break if rate==0
        end
      end
      rate=[[rate,0].max,800].min
      target.instance_variable_set(:@cg_last_type_rate,rate) if target!=nil
      rate
    rescue
      nil
    end

    def self.note_ghost_damage(holder,ctx)
      return false if holder==nil || ctx[:target]==nil || ctx[:damage].to_i<=0
      return false unless ghost_type?(ctx[:target])
      key=type_key(ctx[:type_id]); return false unless key==:normal || key==:fighting
      kind=ability_id(holder)==ABILITY_SCRAPPY ? :scrappy_ghost_bypass : :minds_eye_ghost_bypass
      formal_note(ability_id(holder),holder,kind,{:move_id=>ctx[:move_id].to_i,:type=>key,:damage=>ctx[:damage].to_i,:target_index=>ctx[:target].index.to_i})
      true
    rescue
      false
    end

    #--------------------------------------------------------------------------
    # Magic Bounce
    #--------------------------------------------------------------------------
    def self.magic_bounce_reflectable?(action)
      if defined?(ALBERT_CG::UNIQUE_H_V241) && ALBERT_CG::UNIQUE_H_V241.respond_to?(:magic_coat_reflectable?)
        return ALBERT_CG::UNIQUE_H_V241.magic_coat_reflectable?(action)
      end
      return false if action==nil || !action.skill?
      skill=action.skill; return false if skill==nil || skill.scope.to_i!=1
      row=move_row(move_id(skill)); row!=nil && row[7]==:status
    rescue
      false
    end

    def self.magic_bounce_holder(action,targets)
      return nil if action==nil || action.battler==nil || action.instance_variable_get(:@cg_v2526aa_magic_bounced)==true
      return nil unless magic_bounce_reflectable?(action)
      (targets||[]).each do |t|
        return t if t!=nil && opposing?(t,action.battler) && ability_id(t)==ABILITY_MAGIC_BOUNCE
      end
      nil
    rescue
      nil
    end

    def self.note_magic_bounce(action,holder)
      mid=action!=nil && action.skill? ? move_id(action.skill) : 0
      formal_note_pre_action_safe(ABILITY_MAGIC_BOUNCE,holder,:magic_bounce,{:move_id=>mid,:attacker_index=>(action&&action.battler ? action.battler.index.to_i : -1)},action==nil ? nil : action.battler)
    end

    #--------------------------------------------------------------------------
    # Corrosion context
    #--------------------------------------------------------------------------
    def self.corrosion_stack; @corrosion_stack=[] if @corrosion_stack==nil; @corrosion_stack; end
    def self.with_corrosion_context(user,target,move_id)
      mid=move_id.to_i
      ail=defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT.ailment_id(mid).to_i : 0
      enabled=user!=nil && target!=nil && ability_id(user)==ABILITY_CORROSION && ail==5
      corrosion_stack.push(enabled ? {:user=>user,:target=>target,:move_id=>mid} : nil)
      begin
        yield
      ensure
        corrosion_stack.pop
      end
    end
    def self.corrosion_context; s=corrosion_stack; s.empty? ? nil : s[-1]; rescue; nil; end
    def self.corrosion_ignores_ailment_immunity?(target,ailment)
      c=corrosion_context; c!=nil && target!=nil && target.equal?(c[:target]) && ailment.to_i==5 && poison_or_steel_type?(target)
    rescue
      false
    end
    def self.poison_states
      return [] unless defined?(ALBERT_CG::MOVE_EFFECT)
      ids=[ALBERT_CG::MOVE_EFFECT::STATE_POISON]
      ids.push(ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON) if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON)
      ids
    rescue
      []
    end
    def self.current_poison_states(target); poison_states.select{|sid|target!=nil&&target.state?(sid)}; rescue; []; end
    def self.note_corrosion_result(user,target,mid,before_states)
      return false if user==nil || target==nil || ability_id(user)!=ABILITY_CORROSION || !poison_or_steel_type?(target)
      after=current_poison_states(target); newly=after.reject{|sid|(before_states||[]).include?(sid)}
      return false if newly.empty?
      formal_note(ABILITY_CORROSION,user,:corrosion,{:move_id=>mid.to_i,:target_index=>target.index.to_i,:state_id=>newly[0].to_i})
      true
    rescue
      false
    end

    #--------------------------------------------------------------------------
    # Mirror Armor / Opportunist
    #--------------------------------------------------------------------------
    def self.stat_authority; defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) ? ALBERT_CG::ABILITY_STAT_GUARD_V256 : nil; end
    def self.mirror_info(target,key,amount)
      s=stat_authority; return nil if s==nil || target==nil || amount.to_i>=0 || ability_id(target)!=ABILITY_MIRROR_ARMOR
      return nil unless s.external_to?(target)
      ctx=s.current_stage_context; source=ctx==nil ? nil : ctx[:source]
      return nil if source==nil || !source.respond_to?(:cg_change_stat_stage) || source.equal?(target)
      return nil if @mirror_reflecting==true
      [source,key.to_sym,amount.to_i]
    rescue
      nil
    end

    def self.reflect_mirror(target,info)
      source,key,amount=info; @mirror_reflecting=true
      begin
        formal_note(ABILITY_MIRROR_ARMOR,target,:mirror_armor,{:stat=>key,:amount=>amount,:source_index=>(source.respond_to?(:index) ? source.index.to_i : -1)})
        if stat_authority
          stat_authority.with_stage_source(target,:mirror_armor,nil){source.cg_change_stat_stage(key,amount)}
        else
          source.cg_change_stat_stage(key,amount)
        end
      ensure
        @mirror_reflecting=false
      end
      0
    rescue
      @mirror_reflecting=false
      0
    end

    def self.opportunist_copy(boosted,key,delta)
      return if boosted==nil || delta.to_i<=0 || @opportunist_copying==true
      holders=active_battlers.select{|b|b!=nil && opposing?(b,boosted) && ability_id(b)==ABILITY_OPPORTUNIST && b.hp.to_i>0 && (!b.respond_to?(:hidden)||!b.hidden)}
      return if holders.empty?
      @opportunist_copying=true
      begin
        holders.each do |h|
          before=h.cg_stat_stage(key).to_i
          h.cg_change_stat_stage(key,delta.to_i)
          after=h.cg_stat_stage(key).to_i
          gained=after-before
          if gained>0
            formal_note(ABILITY_OPPORTUNIST,h,:opportunist,{:stat=>key.to_sym,:copied=>gained,:source_index=>boosted.index.to_i,:before=>before,:after=>after})
          end
        end
      ensure
        @opportunist_copying=false
      end
    rescue
      @opportunist_copying=false
    end

    #--------------------------------------------------------------------------
    # Shared Charge token
    #--------------------------------------------------------------------------
    def self.charged?(b); b!=nil && b.instance_variable_get(:@cg_v2526aa_charged)==true; rescue; false; end
    def self.clear_charge(b); b.instance_variable_set(:@cg_v2526aa_charged,false) if b!=nil; true; rescue; false; end
    def self.set_charge(holder,aid,kind,data=nil)
      return false if holder==nil
      holder.instance_variable_set(:@cg_v2526aa_charged,true)
      formal_note(aid,holder,kind,data||{})
      true
    rescue
      false
    end
    def self.reset_charge_entry(holder,ctx); clear_charge(holder); false; end

    def self.apply_charge_damage(holder,ctx)
      return false if holder==nil || !charged?(holder) || ctx[:damage].to_i<=0 || ctx[:fixed_damage]==true
      return false unless type_key(ctx[:type_id])==:electric
      aid=ability_id(holder); return false unless aid==ABILITY_WIND_POWER || aid==ABILITY_ELECTROMORPHOSIS
      before=ctx[:damage].to_i; after=ratio(before,CHARGE_PERCENT,100); ctx[:damage]=after; clear_charge(holder)
      kind=aid==ABILITY_WIND_POWER ? :wind_power_boost : :electromorphosis_boost
      formal_note(aid,holder,kind,{:move_id=>ctx[:move_id].to_i,:before=>before,:after=>after,:type=>:electric})
      true
    rescue
      false
    end

    def self.apply_electromorphosis(holder,ctx)
      return false if holder==nil || ctx[:user]==nil || ctx[:damage_done].to_i<=0 || !opposing?(holder,ctx[:user])
      set_charge(holder,ABILITY_ELECTROMORPHOSIS,:electromorphosis_charge,{:move_id=>ctx[:move_id].to_i,:damage_done=>ctx[:damage_done].to_i})
    end

    def self.apply_wind_hit_result(holder,user,skill)
      return false if holder==nil || user==nil || skill==nil || ability_id(holder)!=ABILITY_WIND_POWER || !opposing?(holder,user)
      return false unless wind_move?(skill)
      return false if holder.respond_to?(:missed) && holder.missed
      return false if holder.respond_to?(:evaded) && holder.evaded
      return false if holder.respond_to?(:skipped) && holder.skipped
      set_charge(holder,ABILITY_WIND_POWER,:wind_power_charge,{:move_id=>move_id(skill)})
    rescue
      false
    end

    def self.apply_tailwind_wind_power(user)
      return false if user==nil
      count=0
      active_battlers.each do |b|
        next if b==nil || !same_side?(b,user) || ability_id(b)!=ABILITY_WIND_POWER
        count+=1 if set_charge(b,ABILITY_WIND_POWER,:wind_power_tailwind,{:source_index=>user.index.to_i})
      end
      count>0
    rescue
      false
    end

    # Existing authority callbacks only need to feed TEST records; presentation is already done there.
    def self.note_scrappy_intimidate(holder,kind,ctx); note_local(ABILITY_SCRAPPY,holder,:scrappy_intimidate,ctx||{}); end
    def self.note_minds_eye_authority(holder,kind,ctx)
      k=kind.to_sym==:evasion_ignore ? :minds_eye_evasion_ignore : :minds_eye_accuracy_guard
      note_local(ABILITY_MINDS_EYE,holder,k,ctx||{})
    end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_SCRAPPY,:damage_modify,self,:note_ghost_damage)
      core.register(ABILITY_MINDS_EYE,:damage_modify,self,:note_ghost_damage)
      core.register(ABILITY_WIND_POWER,:entry,self,:reset_charge_entry)
      core.register(ABILITY_WIND_POWER,:damage_modify,self,:apply_charge_damage)
      core.register(ABILITY_ELECTROMORPHOSIS,:entry,self,:reset_charge_entry)
      core.register(ABILITY_ELECTROMORPHOSIS,:after_damage,self,:apply_electromorphosis)
      core.register(ABILITY_ELECTROMORPHOSIS,:damage_modify,self,:apply_charge_damage)
      true
    end

    #--------------------------------------------------------------------------
    # F11 fixture
    #--------------------------------------------------------------------------
    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime); clear_charge(a)
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
        h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); clear_charge(h)
      end
    end

    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1]]
      ms=[]
      TEST_ENEMIES.each_with_index do |c,i|
        configure_enemy(c)
        m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=(i>=4); ms.push(m)
      end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AA v2.5.26 AutoRegression",ms)
    end

    def self.make_action(b,c)
      a=Game_BattleAction.new(b)
      if c[:kind]==:guard
        a.set_guard
      elsif c[:kind]==:move
        a.set_skill(master.skill_id_for_move(c[:move_id].to_i))
      else
        a.clear
      end
      a.target_index=c[:target].to_i if c.has_key?(:target)
      a
    end

    def self.forced_enemy_action(e)
      return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0
      c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c)
    end

    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||TEST_SPEEDS[:r1]||[]
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_aa,vals[i]) if b}
    end

    def self.clear_round_states
      (test_allies+all_enemies).each do |b|
        next if b==nil
        b.recover_all if b.respond_to?(:recover_all)
        b.cg_reset_stat_stages if b.respond_to?(:cg_reset_stat_stages)
        b.cg_v234_clear_battle_memory if b.respond_to?(:cg_v234_clear_battle_memory)
        clear_charge(b)
      end
    rescue
    end

    def self.prepare_scrappy_intimidate_probe
      a=test_allies; e=all_enemies; @r1_scrappy_before=a[1] ? a[1].cg_stat_stage(:atk).to_i : 0
      if defined?(ALBERT_CG::ABILITY_A_V250) && e[0]
        ALBERT_CG::ABILITY_A_V250.apply_intimidate(e[0],{})
      end
      @r1_scrappy_after=a[1] ? a[1].cg_stat_stage(:atk).to_i : 0
      a.each{|b|b.cg_reset_stat_stages if b&&b.respond_to?(:cg_reset_stat_stages)}
    rescue
    end

    def self.prepare_round_preconditions
      clear_round_states; apply_test_speeds
      a=test_allies; e=all_enemies
      if current_round==1
        prepare_scrappy_intimidate_probe
      elsif current_round==2
        @r2_storage_before=storage_size
        @r2_e0_atk_before=e[0] ? e[0].cg_stat_stage(:atk).to_i : 0
        @r2_a3_atk_before=a[3] ? a[3].cg_stat_stage(:atk).to_i : 0
        @r2_e3_atk_before=e[3] ? e[3].cg_stat_stage(:atk).to_i : 0
        @r2_e2_hp_before=e[2] ? e[2].hp.to_i : 0
      elsif current_round==3
        if a[2]
          a[2].cg_change_stat_stage(:evasion,6)
          @r3_a2_evasion=a[2].cg_stat_stage(:evasion).to_i
          @r3_a2_hp_before=a[2].hp.to_i
        end
        @r3_e4_acc_before=e[4] ? e[4].cg_stat_stage(:accuracy).to_i : 0
      end
    end

    def self.prepare_round_actions
      p=current_plan; return false if p==nil
      prepare_round_preconditions; @actual=[]; log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s)
      test_allies.each_with_index do |b,i|
        next if b==nil||b.hp.to_i<=0
        ac=make_action(b,p[:allies][i])
        if b.respond_to?(:cg_round_actions); b.cg_round_actions.clear; b.cg_round_actions.push(ac); end
        b.cg_assign_action(ac) if b.respond_to?(:cg_assign_action)
        b.instance_variable_set(:@action,ac) unless b.respond_to?(:cg_assign_action)
      end
      true
    end

    def self.record_execution(b)
      return unless active?&&b
      a=b.action; pre=b.actor? ? "A" : "E"
      tok=if a&&a.guard?; pre+b.index.to_s+":Guard" elsif a&&a.skill?; pre+b.index.to_s+":M"+ALBERT_CG::MOVE_EFFECT.move_id(a.skill).to_i.to_s else; pre+b.index.to_s+":Other" end
      @actual.push(tok); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    rescue
    end

    def self.records_for(aid,kind=nil); a=@records[aid]||[]; a.select{|r|kind==nil||r[:kind]==kind}; end

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      tid=($game_troop&&$game_troop.troop) ? $game_troop.troop.id.to_i : 0
      assert_true("Ability Catalog count=373",core&&core.catalog_count==373,"actual="+(core ? core.catalog_count.to_s : "nil"))
      assert_true("Ability Batch AA defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability AA test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability AA ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability AA starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden},"")
      assert_true("Ability AA starts with 1 hidden Mind's Eye reserve",all_enemies[4]&&all_enemies[4].hidden,"E4_hidden="+(all_enemies[4] ? all_enemies[4].hidden.to_s : "nil"))
      assert_true("Scrappy test target E1 is Ghost type",all_enemies[1]&&ghost_type?(all_enemies[1]),"types="+(all_enemies[1]&&all_enemies[1].respond_to?(:cg_pokemon_types) ? all_enemies[1].cg_pokemon_types.inspect : "nil"))
      assert_true("Corrosion test target E3 is Poison/Steel type",all_enemies[3]&&poison_or_steel_type?(all_enemies[3]),"types="+(all_enemies[3]&&all_enemies[3].respond_to?(:cg_pokemon_types) ? all_enemies[3].cg_pokemon_types.inspect : "nil"))
      assert_true("Mind's Eye test target A2 is Ghost type",test_allies[2]&&ghost_type?(test_allies[2]),"types="+(test_allies[2]&&test_allies[2].respond_to?(:cg_pokemon_types) ? test_allies[2].cg_pokemon_types.inspect : "nil"))
    end

    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==exp,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        sg=@r1_scrappy_before.to_i==0 && @r1_scrappy_after.to_i==0 && !records_for(ABILITY_SCRAPPY,:scrappy_intimidate).empty?
        @guard_checks+=1 if sg; assert_true("Scrappy blocks Intimidate ATK drop",sg,"before="+@r1_scrappy_before.to_s+" after="+@r1_scrappy_after.to_s)
        scr=!records_for(ABILITY_SCRAPPY,:scrappy_ghost_bypass).empty?
        @bypass_checks+=1 if scr; assert_true("Scrappy Normal Move damages Ghost target",scr,(records_for(ABILITY_SCRAPPY,:scrappy_ghost_bypass)[-1]||{}).inspect)
        mb=e[0]&&e[0].respond_to?(:cg_v234_taunt_active?)&&e[0].cg_v234_taunt_active?&&a[2]&&(!a[2].respond_to?(:cg_v234_taunt_active?)||!a[2].cg_v234_taunt_active?)&&!records_for(ABILITY_MAGIC_BOUNCE,:magic_bounce).empty?
        @reflect_checks+=1 if mb; assert_true("Magic Bounce reflects Taunt to original user",mb,(records_for(ABILITY_MAGIC_BOUNCE,:magic_bounce)[-1]||{}).inspect)
        bad=defined?(ALBERT_CG::MOVE_EFFECT)&&ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON) ? ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON : 0
        cor=e[3]&&((bad>0&&e[3].state?(bad))||e[3].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON))&&!records_for(ABILITY_CORROSION,:corrosion).empty?
        @bypass_checks+=1 if cor; assert_true("Corrosion poisons Poison-type target",cor,(records_for(ABILITY_CORROSION,:corrosion)[-1]||{}).inspect)
        set=!records_for(ABILITY_WIND_POWER,:wind_power_charge).empty?; @charge_checks+=1 if set; assert_true("Wind Power gains Charge from Gust",set,(records_for(ABILITY_WIND_POWER,:wind_power_charge)[-1]||{}).inspect)
        rec=records_for(ABILITY_WIND_POWER,:wind_power_boost)[-1]||{}; boost=rec[:before].to_i>0&&rec[:after].to_i==ratio(rec[:before],CHARGE_PERCENT,100)&&!charged?(e[1])
        @charge_checks+=1 if boost; assert_true("Wind Power Charge doubles next Electric damage and is consumed",boost,rec.inspect)
      elsif r==2
        mir=records_for(ABILITY_MIRROR_ARMOR,:mirror_armor)[-1]||{}; mok=e[0]&&a[3]&&e[0].cg_stat_stage(:atk).to_i==0&&a[3].cg_stat_stage(:atk).to_i==-1&&!mir.empty?
        @reflect_checks+=1 if mok; assert_true("Mirror Armor reflects Growl ATK drop to source",mok,"E0_atk="+(e[0] ? e[0].cg_stat_stage(:atk).to_i.to_s : "nil")+" A3_atk="+(a[3] ? a[3].cg_stat_stage(:atk).to_i.to_s : "nil")+" record="+mir.inspect)
        opp=records_for(ABILITY_OPPORTUNIST,:opportunist)[-1]||{}
        ook=e[3]&&opp[:copied].to_i==2&&opp[:before].to_i==-1&&opp[:after].to_i==1
        @reactive_checks+=1 if ook; assert_true("Opportunist copies Swords Dance +2 after prior Growl -1 before switch-out",ook,"record="+opp.inspect+" post_switch_stage="+(e[3] ? e[3].cg_stat_stage(:atk).to_i.to_s : "nil"))
        reset_ok=e[3]&&e[3].hidden&&e[3].cg_stat_stage(:atk).to_i==0
        assert_true("Teleport switch-out clears Opportunist temporary ATK stage",reset_ok,"hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" stage="+(e[3] ? e[3].cg_stat_stage(:atk).to_i.to_s : "nil"))
        ecr = records_for(ABILITY_ELECTROMORPHOSIS, :electromorphosis_charge)[-1] || {}
        hp_after = e[2] ? e[2].hp.to_i : @r2_e2_hp_before.to_i
        hp_dropped = hp_after < @r2_e2_hp_before.to_i
        damage_positive = (!ecr.empty? && ecr[:damage_done].to_i > 0)
        ec = (e[2] != nil && hp_dropped && damage_positive)
        @charge_checks += 1 if ec
        assert_true("Electromorphosis gains Charge after deterministic Aura Sphere damage", ec,
          "hp=" + @r2_e2_hp_before.to_s + "->" + hp_after.to_s + " record=" + ecr.inspect)
        er=records_for(ABILITY_ELECTROMORPHOSIS,:electromorphosis_boost)[-1]||{}; eb=er[:before].to_i>0&&er[:after].to_i==ratio(er[:before],CHARGE_PERCENT,100)&&!charged?(e[2])
        @charge_checks+=1 if eb; assert_true("Electromorphosis Charge doubles next Electric damage and is consumed",eb,er.inspect)
        sw=e[3]&&e[4]&&e[3].hidden&&!e[4].hidden; @lifecycle_checks+=1 if sw; assert_true("Teleport deploys hidden Mind's Eye reserve",sw,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        sa=storage_size; stor=sa==@r2_storage_before.to_i; @lifecycle_checks+=1 if stor; assert_true("Mind's Eye reserve switch does not consume Storage Pokemon",stor,"before="+@r2_storage_before.to_s+" after="+sa.to_s)
      elsif r==3
        acc=e[4]&&e[4].cg_stat_stage(:accuracy).to_i==@r3_e4_acc_before.to_i&&!records_for(ABILITY_MINDS_EYE,:minds_eye_accuracy_guard).empty?
        @guard_checks+=1 if acc; assert_true("Mind's Eye blocks external Accuracy drop",acc,"before="+@r3_e4_acc_before.to_s+" after="+(e[4] ? e[4].cg_stat_stage(:accuracy).to_i.to_s : "nil"))
        ev=@r3_a2_evasion.to_i==6&&!records_for(ABILITY_MINDS_EYE,:minds_eye_evasion_ignore).empty?
        @accuracy_checks+=1 if ev; assert_true("Mind's Eye ignores target +6 Evasion",ev,"target_evasion="+@r3_a2_evasion.to_s+" record="+(records_for(ABILITY_MINDS_EYE,:minds_eye_evasion_ignore)[-1]||{}).inspect)
        me=!records_for(ABILITY_MINDS_EYE,:minds_eye_ghost_bypass).empty? && a[2] && a[2].hp.to_i<@r3_a2_hp_before.to_i
        @bypass_checks+=1 if me; assert_true("Mind's Eye Normal Move hits Ghost target and deals damage",me,"hp="+@r3_a2_hp_before.to_s+"->"+(a[2] ? a[2].hp.to_i.to_s : "nil")+" record="+(records_for(ABILITY_MINDS_EYE,:minds_eye_ghost_bypass)[-1]||{}).inspect)
        clear_charge(e[1]) if e[1]
        tail=false
        if field&&e[1]
          tail=field.apply_move(e[1],e[1],366) ? true : false
        end
        wp=tail&&charged?(e[1])&&!records_for(ABILITY_WIND_POWER,:wind_power_tailwind).empty?
        @charge_checks+=1 if wp; assert_true("Wind Power gains Charge when same-side Tailwind takes effect",wp,(records_for(ABILITY_WIND_POWER,:wind_power_tailwind)[-1]||{}).inspect)
        stable=e[4]&&!e[4].hidden&&e[4].hp.to_i>0; assert_true("Mind's Eye reserve remains active through Round3",stable,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" hp="+(e[4] ? e[4].hp.to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end

    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_aa,nil) if b}; end

    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"
      log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_aa="+ability_covered_count.to_s+"/8 bypass_checks="+@bypass_checks.to_i.to_s+" reflect_checks="+@reflect_checks.to_i.to_s+" charge_checks="+@charge_checks.to_i.to_s+" reactive_checks="+@reactive_checks.to_i.to_s+" guard_checks="+@guard_checks.to_i.to_s+" accuracy_checks="+@accuracy_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=157")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}
      cleanup_test_overrides; @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end

    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false
      @bypass_checks=0; @reflect_checks=0; @charge_checks=0; @reactive_checks=0; @guard_checks=0; @accuracy_checks=0; @lifecycle_checks=0
      @r1_scrappy_before=0; @r1_scrappy_after=0; @r2_storage_before=0; @r2_e2_hp_before=0; @r3_a2_evasion=0; @r3_a2_hp_before=0; @r3_e4_acc_before=0
    end

    def self.start_auto_test
      return false if active?
      reset_log; reset_suite; prepare_test_party; make_test_troop
      ALBERT_CG::UNIQUE_I_V242.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_I_V242)&&ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes)
      @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AA_v2.5.26c") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
      false
    end
  end
end

# Disable previous newest F11 harness.
if defined?(ALBERT_CG::ABILITY_Z_V2525)
  module ALBERT_CG
    module ABILITY_Z_V2525
      def self.f11_trigger?; false; end
    end
  end
end

ALBERT_CG::ABILITY_AA_V2526.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Formal Magic Bounce target reflection
#==============================================================================
class Game_BattleAction
  alias cg_v2526aa_make_targets make_targets
  def make_targets
    targets=cg_v2526aa_make_targets
    return targets unless defined?(ALBERT_CG::ABILITY_AA_V2526)
    holder=ALBERT_CG::ABILITY_AA_V2526.magic_bounce_holder(self,targets)
    return targets if holder==nil
    @cg_v2526aa_magic_bounced=true
    ALBERT_CG::ABILITY_AA_V2526.note_magic_bounce(self,holder)
    return @battler==nil ? targets : [@battler]
  end
end

#==============================================================================
# ■ Formal skill context：Ghost bypass / Corrosion / Wind Power successful hit
#==============================================================================
class Game_Battler
  alias cg_v2526aa_skill_effect skill_effect
  def skill_effect(user,skill)
    mid=defined?(ALBERT_CG::ABILITY_AA_V2526) ? ALBERT_CG::ABILITY_AA_V2526.move_id(skill) : 0
    before_poison=defined?(ALBERT_CG::ABILITY_AA_V2526) ? ALBERT_CG::ABILITY_AA_V2526.current_poison_states(self) : []
    result=nil
    if defined?(ALBERT_CG::ABILITY_AA_V2526)
      result=ALBERT_CG::ABILITY_AA_V2526.with_hit_context(user,self,skill) do
        ALBERT_CG::ABILITY_AA_V2526.with_corrosion_context(user,self,mid) do
          cg_v2526aa_skill_effect(user,skill)
        end
      end
      ALBERT_CG::ABILITY_AA_V2526.note_corrosion_result(user,self,mid,before_poison)
      ALBERT_CG::ABILITY_AA_V2526.apply_wind_hit_result(self,user,skill)
      return result
    end
    cg_v2526aa_skill_effect(user,skill)
  end

  alias cg_v2526aa_type_rate cg_pokemon_type_rate_percent
  def cg_pokemon_type_rate_percent(attack_type)
    if defined?(ALBERT_CG::ABILITY_AA_V2526)
      info=ALBERT_CG::ABILITY_AA_V2526.ghost_bypass_info(self,attack_type)
      if info!=nil
        rate=ALBERT_CG::ABILITY_AA_V2526.filtered_ghost_rate(self,attack_type)
        return rate.to_i if rate!=nil
      end
    end
    cg_v2526aa_type_rate(attack_type)
  end
end

#==============================================================================
# ■ Formal Corrosion：只覆寫 ailment type immunity query in scoped context
#==============================================================================
if defined?(ALBERT_CG::MOVE_EFFECT)
  module ALBERT_CG
    module MOVE_EFFECT
      class << self
        alias cg_v2526aa_ailment_immune ailment_immune?
        def ailment_immune?(battler,ailment)
          if defined?(ALBERT_CG::ABILITY_AA_V2526) && ALBERT_CG::ABILITY_AA_V2526.corrosion_ignores_ailment_immunity?(battler,ailment)
            return false
          end
          cg_v2526aa_ailment_immune(battler,ailment)
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal Mirror Armor + Opportunist stage bridge
#==============================================================================
class Game_Battler
  alias cg_v2526aa_change_stage cg_change_stat_stage
  def cg_change_stat_stage(key,amount)
    if defined?(ALBERT_CG::ABILITY_AA_V2526)
      info=ALBERT_CG::ABILITY_AA_V2526.mirror_info(self,key,amount)
      return ALBERT_CG::ABILITY_AA_V2526.reflect_mirror(self,info) if info!=nil
    end
    before=respond_to?(:cg_stat_stage) ? cg_stat_stage(key).to_i : 0
    result=cg_v2526aa_change_stage(key,amount)
    after=respond_to?(:cg_stat_stage) ? cg_stat_stage(key).to_i : before
    if defined?(ALBERT_CG::ABILITY_AA_V2526) && after>before
      ALBERT_CG::ABILITY_AA_V2526.opportunist_copy(self,key,after-before)
    end
    result
  end
end

#==============================================================================
# ■ Formal Scrappy Intimidate extension + callback
#==============================================================================
if defined?(ALBERT_CG::ABILITY_STATUS_V255)
  module ALBERT_CG
    module ABILITY_STATUS_V255
      class << self
        alias cg_v2526aa_intimidate_immune intimidate_immune?
        def intimidate_immune?(battler)
          return true if defined?(ALBERT_CG::ABILITY_AA_V2526) && ALBERT_CG::ABILITY_AA_V2526.ability_id(battler)==ALBERT_CG::ABILITY_AA_V2526::ABILITY_SCRAPPY
          cg_v2526aa_intimidate_immune(battler)
        end
        alias cg_v2526aa_status_note_activation note_activation
        def note_activation(battler,aid,kind,context=nil)
          result=cg_v2526aa_status_note_activation(battler,aid,kind,context)
          if defined?(ALBERT_CG::ABILITY_AA_V2526) && aid.to_i==ALBERT_CG::ABILITY_AA_V2526::ABILITY_SCRAPPY && kind.to_sym==:intimidate_guard
            ALBERT_CG::ABILITY_AA_V2526.note_scrappy_intimidate(battler,kind,context)
          end
          result
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal Mind's Eye extends Stat Guard / Keen Eye authority
#==============================================================================
if defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256)
  module ALBERT_CG
    module ABILITY_STAT_GUARD_V256
      class << self
        alias cg_v2526aa_stat_guard_matches stat_guard_matches?
        def stat_guard_matches?(aid,key)
          return true if defined?(ALBERT_CG::ABILITY_AA_V2526) && aid.to_i==ALBERT_CG::ABILITY_AA_V2526::ABILITY_MINDS_EYE && key.to_sym==:accuracy
          cg_v2526aa_stat_guard_matches(aid,key)
        end
        alias cg_v2526aa_ignore_evasion keen_eye_ignore_evasion?
        def keen_eye_ignore_evasion?(user,target)
          if defined?(ALBERT_CG::ABILITY_AA_V2526) && user!=nil && target!=nil && ALBERT_CG::ABILITY_AA_V2526.ability_id(user)==ALBERT_CG::ABILITY_AA_V2526::ABILITY_MINDS_EYE
            return target.respond_to?(:cg_stat_stage) && target.cg_stat_stage(:evasion).to_i>0
          end
          cg_v2526aa_ignore_evasion(user,target)
        end
        alias cg_v2526aa_stat_note_activation note_activation
        def note_activation(battler,aid,kind,context=nil)
          result=cg_v2526aa_stat_note_activation(battler,aid,kind,context)
          if defined?(ALBERT_CG::ABILITY_AA_V2526) && aid.to_i==ALBERT_CG::ABILITY_AA_V2526::ABILITY_MINDS_EYE && (kind.to_sym==:stat_guard || kind.to_sym==:evasion_ignore)
            ALBERT_CG::ABILITY_AA_V2526.note_minds_eye_authority(battler,kind,context)
          end
          result
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal Wind Power Tailwind bridge
#==============================================================================
if defined?(ALBERT_CG::FIELD_V233)
  module ALBERT_CG
    module FIELD_V233
      class << self
        alias cg_v2526aa_apply_move apply_move
        def apply_move(user,target,move_id)
          result=cg_v2526aa_apply_move(user,target,move_id)
          if result && move_id.to_i==366 && defined?(ALBERT_CG::ABILITY_AA_V2526)
            ALBERT_CG::ABILITY_AA_V2526.apply_tailwind_wind_power(user)
          end
          result
        end
      end
    end
  end
end

#==============================================================================
# ■ TEST Scene hooks
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2526aa_execute_action execute_action
  def execute_action
    b=@active_battler
    ALBERT_CG::ABILITY_AA_V2526.record_execution(b) if defined?(ALBERT_CG::ABILITY_AA_V2526)&&ALBERT_CG::ABILITY_AA_V2526.active?
    cg_v2526aa_execute_action
  end

  alias cg_v2526aa_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AA_V2526)&&ALBERT_CG::ABILITY_AA_V2526.active?
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_AA_V2526.finish_round_assertions
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      else
        ALBERT_CG::ABILITY_AA_V2526.finish_round_assertions
      end
    end
    cg_v2526aa_turn_end
  end

  alias cg_v2526aa_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AA_V2526)&&ALBERT_CG::ABILITY_AA_V2526.active?
      return cg_v2526aa_start_party_command
    end
    cg_v2526aa_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_AA_V2526.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AA_V2526.finished?
      ALBERT_CG::ABILITY_AA_V2526.finish_suite; battle_end(0); return
    end
    ALBERT_CG::ABILITY_AA_V2526.prepare_round_actions; start_main
  end
end

class Game_Battler
  alias cg_v2526aa_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AA_V2526)&&ALBERT_CG::ABILITY_AA_V2526.active?
      v=@cg_priority_test_speed_override_aa; return v.to_i if v!=nil
    end
    cg_v2526aa_priority_base_speed
  rescue
    cg_v2526aa_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2526aa_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AA_V2526)&&ALBERT_CG::ABILITY_AA_V2526.active?
      a=ALBERT_CG::ABILITY_AA_V2526.forced_enemy_action(self)
      if a
        cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return
      end
    end
    cg_v2526aa_enemy_make_action
  end
end

module ALBERT_CG
  class << self
    alias cg_v2526aa_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2526aa_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_AA_V2526)&&ALBERT_CG::ABILITY_AA_V2526.active?
        ALBERT_CG::ABILITY_AA_V2526::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AA_V2526.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if h
          h.change_level(ALBERT_CG::ABILITY_AA_V2526::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); ALBERT_CG::ABILITY_AA_V2526.clear_charge(h)
        end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2526aa_scene_map_update update
  def update
    cg_v2526aa_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_AA_V2526)
    ALBERT_CG::ABILITY_AA_V2526.start_auto_test if ALBERT_CG::ABILITY_AA_V2526.f11_trigger?
  end
end
