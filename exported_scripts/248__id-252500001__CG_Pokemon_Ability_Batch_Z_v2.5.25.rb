# RMVX_SCRIPT_INDEX: 248
# RMVX_SCRIPT_ID: 252500001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch Z v2.5.25
# RMVX_SOURCE_SHA256: 727d31406cef8eb1f512cc91b44bf9d9d057a29914da4e1ee21410ebe22d7175

#==============================================================================
# ■ CG Pokemon Ability Batch Z v2.5.25 - Redirect / Team Guard / Reactive Field TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.24f Ability Batch Y RPG Maker VX 實機 PASS 為唯一正式基底，新增 8 個
#  尚未覆蓋的主系列 Ability，集中處理「單體屬性重定向＋吸收」、「接觸追加狀態」、
#  「後手增傷」、「隊伍限制／狀態／能力下降防護」、「Wind Move 免疫反應」與
#  「受物理攻擊後鋪設 Toxic Spikes」。不修改已 PASS Move Runtime 0..937。
#
# 【本批 Ability】
#   31 Lightning Rod  避雷針：單體 Electric Move 在無 Follow Me/Rage Powder 等 center-of-attention
#                     優先重定向時吸向 holder；命中 holder 時無效並使 SpA +1。
#  114 Storm Drain    引水：同上，但針對 Water Move；無效並使 SpA +1。
#  143 Poison Touch   毒手：使用者造成接觸傷害後 30% 使目標中毒；F11 只對該測試 Action 強制成功。
#  148 Analytic       分析：攻擊目標本回合已完成 Action 時，直接傷害 x1.30。
#  165 Aroma Veil     芳香幕：holder 與同側 active allies 免疫本專案已正式支援的 Disable / Encore / Taunt。
#  166 Flower Veil    花幕：同側 active Grass Pokémon 免疫主要異常狀態與敵方造成的能力階級下降。
#  274 Wind Rider     乘風：Wind Move 對 holder 無效並 ATK +1；同側 Tailwind 生效時 ATK +1。
#  295 Toxic Debris   毒滿地：受到造成實際傷害的 Physical Move 後，在攻擊者一側鋪 1 層 Toxic Spikes，最多 2 層。
#
# 【主要設定項】
#  TEST_TROOP_ID=728；HANDLED_ABILITY_IDS=8。
#  Static coverage：200/373 -> 208/373，pending 173 -> 165。
#  ANALYTIC_PERCENT=130；POISON_TOUCH_CHANCE=30。
#
# 【機制規則】
#  1. Lightning Rod / Storm Drain 只重定向 scope=1 的單體對手 Move。若 Unique C 已用
#     Follow Me / Rage Powder / Spotlight 把該 Action 導向 center-of-attention，保持既有結果，
#     不由 Ability 二次搶走。若同側有多個相同 redirect Ability，依 Effective SPE 高者優先，
#     同速沿既有 entry_order 穩定排序。
#  2. Electric / Water immunity 與 SpA +1 由 Ability Core :before_hit 完成；targeting 階段只改
#     Game_BattleAction target，不直接補傷害、不顯示 blocking Popup，避免 pre-action wait 污染 Tankentai。
#  3. Poison Touch 使用最終 execute_damage 外層，只在實際 HP damage>0 且為 contact Action 時判定；
#     狀態仍走既有 add_state / Ability Guard Authority，因此 Immunity / Flower Veil 等可正常擋下。
#  4. Analytic 使用正式 :damage_modify attacker role；以本回合 target 是否已完成 Scene_Battle
#     execute_action 判定，回合結束清除 acted flag，不改 Priority Core。
#  5. Aroma Veil 只包裝本專案已存在的 cg_v234_disable_move / cg_v234_set_encore /
#     cg_v234_set_taunt setter；未實作的原作限制狀態不虛構第二套系統。
#  6. Flower Veil 的主要異常狀態走 Ability Guard Authority 最外層；能力下降走既有
#     Stat Guard Authority source context，只擋 external negative stage change，不擋自我 Debuff。
#  7. Wind Rider 的 Wind Move 判定以 Master Move identifier 名單為正式 mapping；包含 Gust、
#     Whirlwind、Twister、Icy Wind、Air Cutter、Tailwind、Hurricane 等已知 Wind Move。
#     Field.apply_move 成功建立同側 Tailwind 時，active Wind Rider holder 額外 ATK +1。
#  8. Toxic Debris 只在 Physical Move 造成實際 HP damage 後鋪 hazard，直接沿用 Field v2.3.3a
#     hazards state，攻擊者 actor? 決定鋪在 :ally / :enemy 一側，最多 2 層。
#  9. Batch Y v2.5.24f 的 pre-action presentation safety 原樣保留；本頁不重寫其 Formal methods。
#
# 【可調參數】
#  TEST_TROOP_ID、TEST_SPEEDS、ROUND_PLANS、ANALYTIC_PERCENT、POISON_TOUCH_CHANCE、WIND_IDENTIFIERS。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，自動進 troop 728，跑三回合並輸出
#  Pokemon_Ability_Z_AutoTest_v2_5_25.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：E0 Thunderbolt 指向 A3 -> Lightning Rod A1；E1 Water Gun 指向 A3 -> Storm Drain A2；
#          E2 Tackle -> A3 觸發 Poison Touch；A3 後手 Tackle -> 已行動 E2 觸發 Analytic；
#          A1 Tackle -> Toxic Debris E3，在 actor side 建立 Toxic Spikes。
#  Round2：E3 Teleport，換入 hidden Wind Rider E4，Storage 不變。
#  Round3：A2 Taunt -> E2 由 Aroma Veil E0 擋；A3 Toxic -> Grass E2 由 Flower Veil E1 擋；
#          Tailwind formal probe + A1 Gust -> E4，Wind Rider 兩次 ATK +1 且 Gust 不造成傷害。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchZ"] = "2.5.25"

module ALBERT_CG
  module ABILITY_Z_V2525
    VERSION = "2.5.25"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 728
    VK_F11 = 0x7A

    ABILITY_LIGHTNING_ROD = 31
    ABILITY_STORM_DRAIN   = 114
    ABILITY_POISON_TOUCH  = 143
    ABILITY_ANALYTIC      = 148
    ABILITY_AROMA_VEIL    = 165
    ABILITY_FLOWER_VEIL   = 166
    ABILITY_WIND_RIDER    = 274
    ABILITY_TOXIC_DEBRIS  = 295
    HANDLED_ABILITY_IDS = [31,114,143,148,165,166,274,295]

    ANALYTIC_PERCENT = 130
    POISON_TOUCH_CHANCE = 30

    WIND_IDENTIFIERS = [
      "air-cutter","bleakwind-storm","blizzard","fairy-wind","gust","heat-wave",
      "hurricane","icy-wind","petal-blizzard","sandsear-storm","sandstorm",
      "springtide-storm","tailwind","twister","whirlwind","wildbolt-storm"
    ]

    TEST_ALLIES = [
      {:dex=>25, :level=>40, :ability=>ABILITY_LIGHTNING_ROD, :moves=>[33,150,16,150]},
      {:dex=>65, :level=>40, :ability=>ABILITY_STORM_DRAIN,   :moves=>[150,150,269,150]},
      {:dex=>128,:level=>40, :ability=>ABILITY_ANALYTIC,      :moves=>[33,150,92,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>60,:ability=>ABILITY_AROMA_VEIL,   :moves=>[85,150,150,150]},
      {:dex=>94, :level=>60,:ability=>ABILITY_FLOWER_VEIL,  :moves=>[55,150,150,150]},
      {:dex=>1,  :level=>60,:ability=>ABILITY_POISON_TOUCH, :moves=>[33,150,150,150]},
      {:dex=>109,:level=>60,:ability=>ABILITY_TOXIC_DEBRIS, :moves=>[150,100,150,150]},
      {:dex=>197,:level=>60,:ability=>ABILITY_WIND_RIDER,   :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"REDIRECT_ABSORB_CONTACT_ANALYTIC_DEBRIS",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>3},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>33,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>85,:target=>3},
          1=>{:kind=>:move,:move_id=>55,:target=>3},
          2=>{:kind=>:move,:move_id=>33,:target=>3},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"WIND_RIDER_RESERVE_SWITCH",
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
        :name=>"AROMA_FLOWER_WIND_RIDER",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>16,:target=>4},
          {:kind=>:move,:move_id=>269,:target=>2},
          {:kind=>:move,:move_id=>92,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,240,230,250, 330,320,310,220,0],
      :r2=>[10,300,290,280, 270,260,250,10,0],
      :r3=>[10,330,320,310, 270,260,250,0,240],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","E0:M85","E1:M55","E2:M33","A3:M33","A1:M33","A2:M150","E3:M150"],
      2=>["A0:Guard","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","A1:M16","A2:M269","A3:M92","E0:M150","E1:M150","E2:M150","E4:M150"],
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
    def self.log_path; File.join(project_root,"Pokemon_Ability_Z_AutoTest_v2_5_25.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end

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
      h="CG POKEMON ABILITY Z REDIRECT TEAM GUARD + REACTIVE FIELD AUTO REGRESSION v2.5.25\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; typed redirect/absorb + contact/status/stat guard + analytic + wind + toxic debris lifecycle\r\n"+
        "BASELINE=v2.5.24f Ability Batch Y Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_Y_PASS=200 BATCH_Z=8 PENDING=165\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}
      File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue
    end

    def self.ability_id(b); core==nil || b==nil ? 0 : core.ability_id(b).to_i; rescue; 0; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill!=nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.move_row(mid); master ? master.move(mid.to_i) : nil; rescue; nil; end
    def self.move_identifier(mid); r=move_row(mid); r==nil ? "" : r[0].to_s; rescue; ""; end
    def self.type_id(symbol)
      return 0 unless defined?(ALBERT_CG::POKEMON_COMBAT)
      return ALBERT_CG::POKEMON_COMBAT.type_id(symbol).to_i if ALBERT_CG::POKEMON_COMBAT.respond_to?(:type_id)
      t=ALBERT_CG::POKEMON_COMBAT::TYPE_IDS; t!=nil && t.has_key?(symbol) ? t[symbol].to_i : 0
    rescue
      0
    end
    def self.skill_type_id(skill); skill!=nil && skill.respond_to?(:cg_pokemon_type_id) ? skill.cg_pokemon_type_id.to_i : 0; rescue; 0; end
    def self.physical_move?(skill); skill!=nil && skill.respond_to?(:cg_pokemon_damage_class) ? skill.cg_pokemon_damage_class==:physical : (skill!=nil && skill.respond_to?(:physical_attack) && skill.physical_attack==true); rescue; false; end
    def self.same_side?(a,b); a!=nil && b!=nil && (a.actor? == b.actor?); rescue; false; end
    def self.active_battlers; core ? core.active_battlers : []; rescue; []; end
    def self.grass_type?(b); b!=nil && b.respond_to?(:cg_pokemon_types) && b.cg_pokemon_types.include?(:grass); rescue; false; end
    def self.wind_move?(skill); WIND_IDENTIFIERS.include?(move_identifier(move_id(skill))); rescue; false; end
    def self.ratio(v,num,den); x=v.to_i; return 0 if x<=0; y=x*num.to_i/den.to_i; y=1 if y<1; y; rescue; v.to_i; end

    def self.note_local(aid,battler,kind,data=nil)
      return true unless active?
      @ability_trigger_counts[aid]=@ability_trigger_counts[aid].to_i+1
      rec={:ability=>aid,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless k==:battler||k==:user||k==:target||k==:skill||k==:action}
      @records[aid]=[] if @records[aid]==nil; @records[aid].push(rec)
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
      log("ABILITY_Z_TRIGGER ability="+aid.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
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

    def self.change_stage(source,target,key,amount)
      return 0 if target==nil || !target.respond_to?(:cg_change_stat_stage)
      if defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256)
        return ALBERT_CG::ABILITY_STAT_GUARD_V256.with_stage_source(source,:ability,nil){target.cg_change_stat_stage(key,amount)}
      end
      target.cg_change_stat_stage(key,amount)
    rescue
      0
    end

    def self.redirect_ability_for_type(tid)
      return ABILITY_LIGHTNING_ROD if tid.to_i==type_id(:electric)
      return ABILITY_STORM_DRAIN if tid.to_i==type_id(:water)
      0
    rescue
      0
    end

    def self.center_of_attention_keeps_target?(action,targets)
      return false unless defined?(ALBERT_CG::UNIQUE_C_V236)
      return false if action==nil || targets==nil || targets.empty?
      redirects=ALBERT_CG::UNIQUE_C_V236.instance_variable_get(:@redirectors)
      return false if redirects==nil
      b=action.battler; return false if b==nil
      side=b.actor? ? :enemy : :actor
      red=redirects[side]
      red!=nil && red.exist? && targets[0].equal?(red)
    rescue
      false
    end

    def self.redirect_holder_for(action,targets)
      return nil if action==nil || action.battler==nil || targets==nil || targets.empty?
      return nil unless action.skill?
      skill=action.skill; return nil if skill==nil || skill.scope.to_i!=1
      return nil if center_of_attention_keeps_target?(action,targets)
      aid=redirect_ability_for_type(skill_type_id(skill)); return nil if aid<=0
      candidates=core ? core.opponents_of(action.battler) : []
      candidates=candidates.select{|b|ability_id(b)==aid && ( !action.respond_to?(:cg_target_legal?) || action.cg_target_legal?(b) )}
      return nil if candidates.empty?
      ordered=core.respond_to?(:entry_order) ? core.entry_order(candidates) : candidates
      ordered[0]
    rescue
      nil
    end

    def self.apply_type_redirect(action,targets)
      holder=redirect_holder_for(action,targets); return targets if holder==nil || targets[0].equal?(holder)
      from=targets[0]
      action.target_index=holder.index if action.respond_to?(:target_index=)
      aid=ability_id(holder)
      rec={:ability=>aid,:move_id=>move_id(action.skill),:from=>(from ? from.index.to_i : -1),:to=>holder.index.to_i}
      if active?
        @redirect_records.push(rec)
        log("ABILITY_Z_REDIRECT ability="+aid.to_s+" move_id="+rec[:move_id].to_s+" from="+rec[:from].to_s+" to="+rec[:to].to_s)
      end
      core.runtime_log("ABILITY_REDIRECT ability="+aid.to_s+" move="+rec[:move_id].to_s+" from="+rec[:from].to_s+" to="+rec[:to].to_s) if core
      [holder]
    rescue
      targets
    end

    def self.apply_typed_absorb(holder,ctx,aid,tid,kind)
      return false if holder==nil || ctx[:user]==nil || same_side?(holder,ctx[:user])
      return false unless skill_type_id(ctx[:skill])==tid.to_i
      before=holder.respond_to?(:cg_stat_stage) ? holder.cg_stat_stage(:spa).to_i : 0
      holder.cg_change_stat_stage(:spa,1) if holder.respond_to?(:cg_change_stat_stage)
      after=holder.respond_to?(:cg_stat_stage) ? holder.cg_stat_stage(:spa).to_i : before
      ctx[:cancel]=true; ctx[:hp_damage]=0
      note_local(aid,holder,kind,{:move_id=>ctx[:move_id].to_i,:before=>before,:after=>after,:type_id=>tid.to_i})
      true
    rescue
      false
    end
    def self.apply_lightning_rod(holder,ctx); apply_typed_absorb(holder,ctx,ABILITY_LIGHTNING_ROD,type_id(:electric),:lightning_rod_absorb); end
    def self.apply_storm_drain(holder,ctx); apply_typed_absorb(holder,ctx,ABILITY_STORM_DRAIN,type_id(:water),:storm_drain_absorb); end

    def self.apply_analytic(holder,ctx)
      return false if holder==nil || ctx[:role]!=:attacker || ctx[:fixed_damage]==true || ctx[:damage].to_i<=0
      target=ctx[:target]; return false if target==nil || target.instance_variable_get(:@cg_v2525z_acted)!=true
      before=ctx[:damage].to_i; after=ratio(before,ANALYTIC_PERCENT,100); ctx[:damage]=after
      note_local(ABILITY_ANALYTIC,holder,:analytic,{:move_id=>ctx[:move_id].to_i,:before=>before,:after=>after,:target_index=>target.index.to_i})
      true
    rescue
      false
    end

    def self.poison_touch_proc?
      return true if active? && current_round==1
      rand(100)<POISON_TOUCH_CHANCE
    rescue
      false
    end

    def self.major_status?(target)
      return false if target==nil || !defined?(ALBERT_CG::MOVE_EFFECT)
      ALBERT_CG::MOVE_EFFECT::PRIMARY_STATES.any?{|sid|target.state?(sid)}
    rescue
      false
    end

    def self.apply_poison_touch_after_damage(target,user,skill,damage_done)
      return false if target==nil || user==nil || skill==nil || damage_done.to_i<=0
      return false unless ability_id(user)==ABILITY_POISON_TOUCH
      return false unless core && core.contact_action?(user)
      return false if major_status?(target) || !poison_touch_proc?
      sid=ALBERT_CG::MOVE_EFFECT::STATE_POISON
      if target.respond_to?(:cg_v231_add_state_record)
        target.cg_v231_add_state_record(sid)
      else
        target.add_state(sid)
      end
      return false unless target.state?(sid)
      formal_note(ABILITY_POISON_TOUCH,user,:poison_touch,{:move_id=>move_id(skill),:state_id=>sid,:target_index=>target.index.to_i})
      true
    rescue
      false
    end

    def self.aroma_holder_for(target)
      active_battlers.each{|b|return b if same_side?(b,target)&&ability_id(b)==ABILITY_AROMA_VEIL}
      nil
    rescue
      nil
    end

    def self.aroma_guard?(target,kind)
      h=aroma_holder_for(target); return false if h==nil
      formal_note(ABILITY_AROMA_VEIL,h,:aroma_veil,{:target_index=>target.index.to_i,:effect=>kind})
      true
    rescue
      false
    end

    def self.flower_holder_for(target)
      return nil unless grass_type?(target)
      active_battlers.each{|b|return b if same_side?(b,target)&&ability_id(b)==ABILITY_FLOWER_VEIL}
      nil
    rescue
      nil
    end

    def self.flower_state_guard_info(target,state_id)
      return nil if target==nil || !defined?(ALBERT_CG::MOVE_EFFECT)
      return nil unless ALBERT_CG::MOVE_EFFECT::PRIMARY_STATES.include?(state_id.to_i)
      h=flower_holder_for(target); h==nil ? nil : [h,:flower_veil_state]
    rescue
      nil
    end

    def self.note_flower_state_guard(info,target,state_id,source)
      return false if info==nil
      holder,kind=info
      formal_note(ABILITY_FLOWER_VEIL,holder,kind,{:target_index=>target.index.to_i,:state_id=>state_id.to_i,:source=>source})
      true
    rescue
      true
    end

    def self.flower_stat_guard_info(target,key,amount)
      return nil if target==nil || amount.to_i>=0 || !defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256)
      return nil unless ALBERT_CG::ABILITY_STAT_GUARD_V256.external_to?(target)
      h=flower_holder_for(target); h==nil ? nil : [h,key.to_sym,amount.to_i]
    rescue
      nil
    end

    def self.note_flower_stat_guard(info,target)
      holder,key,amount=info
      formal_note(ABILITY_FLOWER_VEIL,holder,:flower_veil_stat,{:target_index=>target.index.to_i,:stat=>key,:amount=>amount})
      true
    rescue
      true
    end

    def self.apply_wind_rider(holder,ctx)
      return false if holder==nil || ctx[:user]==nil || same_side?(holder,ctx[:user]) || !wind_move?(ctx[:skill])
      before=holder.respond_to?(:cg_stat_stage) ? holder.cg_stat_stage(:atk).to_i : 0
      holder.cg_change_stat_stage(:atk,1) if holder.respond_to?(:cg_change_stat_stage)
      after=holder.respond_to?(:cg_stat_stage) ? holder.cg_stat_stage(:atk).to_i : before
      ctx[:cancel]=true; ctx[:hp_damage]=0
      note_local(ABILITY_WIND_RIDER,holder,:wind_rider_hit,{:move_id=>ctx[:move_id].to_i,:before=>before,:after=>after})
      true
    rescue
      false
    end

    def self.apply_tailwind_wind_rider(user)
      return false if user==nil
      changed=0
      active_battlers.each do |b|
        next unless same_side?(b,user) && ability_id(b)==ABILITY_WIND_RIDER
        before=b.respond_to?(:cg_stat_stage) ? b.cg_stat_stage(:atk).to_i : 0
        b.cg_change_stat_stage(:atk,1) if b.respond_to?(:cg_change_stat_stage)
        after=b.respond_to?(:cg_stat_stage) ? b.cg_stat_stage(:atk).to_i : before
        next if after==before
        formal_note(ABILITY_WIND_RIDER,b,:wind_rider_tailwind,{:before=>before,:after=>after})
        changed+=1
      end
      changed>0
    rescue
      false
    end

    def self.apply_toxic_debris(holder,ctx)
      return false if holder==nil || ctx[:user]==nil || ctx[:damage_done].to_i<=0 || !physical_move?(ctx[:skill]) || field==nil
      side=field.side_key(ctx[:user]); table=field.state.hazards[side]; return false if table==nil
      before=table[:toxic_spikes].to_i; after=[before+1,2].min; return false if after==before
      table[:toxic_spikes]=after
      note_local(ABILITY_TOXIC_DEBRIS,holder,:toxic_debris,{:move_id=>ctx[:move_id].to_i,:side=>side,:before=>before,:after=>after})
      true
    rescue
      false
    end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_LIGHTNING_ROD,:before_hit,self,:apply_lightning_rod)
      core.register(ABILITY_STORM_DRAIN,:before_hit,self,:apply_storm_drain)
      core.register(ABILITY_ANALYTIC,:damage_modify,self,:apply_analytic)
      core.register(ABILITY_WIND_RIDER,:before_hit,self,:apply_wind_rider)
      core.register(ABILITY_TOXIC_DEBRIS,:after_hit,self,:apply_toxic_debris)
      true
    end

    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime)
      a.instance_variable_set(:@cg_v2525z_acted,false)
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
        h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); h.instance_variable_set(:@cg_v2525z_acted,false)
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
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability Z v2.5.25 AutoRegression",ms)
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
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_z,vals[i]) if b}
    end

    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end

    def self.reset_field
      return if field==nil
      st=field.state
      if st.respond_to?(:hazards) && st.hazards
        [:ally,:enemy].each do |side|
          h=st.hazards[side]; next if h==nil
          h[:spikes]=0; h[:toxic_spikes]=0; h[:stealth_rock]=0; h[:sticky_web]=0
        end
      end
      if st.respond_to?(:sides) && st.sides
        [:ally,:enemy].each{|side|st.sides[side]={} if st.sides.has_key?(side)}
      end
    rescue
    end

    def self.clear_acted_flags
      (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_v2525z_acted,false) if b}
    rescue
    end

    def self.clear_round_states
      (test_allies+all_enemies).each do |b|
        next if b==nil || b.hp.to_i<=0
        b.recover_all if b.respond_to?(:recover_all)
        b.cg_reset_stat_stages if b.respond_to?(:cg_reset_stat_stages)
        b.cg_v234_clear_battle_memory if b.respond_to?(:cg_v234_clear_battle_memory)
      end
      clear_acted_flags
      reset_field
    rescue
    end

    def self.prepare_round1_flower_stat_probe
      a=test_allies; e=all_enemies; t=e[2]; return if t==nil
      @r1_flower_grass=grass_type?(t)
      @r1_flower_stage_before=t.respond_to?(:cg_stat_stage) ? t.cg_stat_stage(:atk).to_i : 0
      if defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256)
        ALBERT_CG::ABILITY_STAT_GUARD_V256.with_stage_source(a[1],:ability,true){t.cg_change_stat_stage(:atk,-1)}
      else
        t.cg_change_stat_stage(:atk,-1)
      end
      @r1_flower_stage_after=t.respond_to?(:cg_stat_stage) ? t.cg_stat_stage(:atk).to_i : 0
    rescue
    end

    def self.prepare_round3_tailwind_probe
      e=all_enemies; b=e[4]; return if b==nil || b.hidden || field==nil
      @r3_wind_hp_before=b.hp.to_i
      @r3_tailwind_before=b.respond_to?(:cg_stat_stage) ? b.cg_stat_stage(:atk).to_i : 0
      field.apply_move(b,b,366)
      @r3_tailwind_after=b.respond_to?(:cg_stat_stage) ? b.cg_stat_stage(:atk).to_i : @r3_tailwind_before
    rescue
    end

    def self.prepare_round_preconditions
      clear_round_states; apply_test_speeds
      if current_round==1
        prepare_round1_flower_stat_probe
        @r1_a1_hp=test_allies[1] ? test_allies[1].hp.to_i : 0
        @r1_a2_hp=test_allies[2] ? test_allies[2].hp.to_i : 0
      elsif current_round==2
        @r2_storage_before=storage_size
      elsif current_round==3
        prepare_round3_tailwind_probe
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
    def self.redirect_for?(aid,mid,from,to); @redirect_records.any?{|r|r[:ability].to_i==aid&&r[:move_id].to_i==mid&&r[:from].to_i==from&&r[:to].to_i==to}; end

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      tid=($game_troop&&$game_troop.troop) ? $game_troop.troop.id.to_i : 0
      assert_true("Ability Catalog count=373",core&&core.catalog_count==373,"actual="+(core ? core.catalog_count.to_s : "nil"))
      assert_true("Ability Batch Z defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability Z test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability Z ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability Z starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden},"")
      assert_true("Ability Z starts with 1 hidden Wind Rider reserve",all_enemies[4]&&all_enemies[4].hidden,"E4_hidden="+(all_enemies[4] ? all_enemies[4].hidden.to_s : "nil"))
      assert_true("Flower Veil test target E2 is Grass type",all_enemies[2]&&grass_type?(all_enemies[2]),"types="+(all_enemies[2]&&all_enemies[2].respond_to?(:cg_pokemon_types) ? all_enemies[2].cg_pokemon_types.inspect : "nil"))
    end

    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==exp,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        lr=redirect_for?(ABILITY_LIGHTNING_ROD,85,3,1) && a[1] && a[1].hp.to_i==@r1_a1_hp.to_i && a[1].cg_stat_stage(:spa).to_i==1 && !records_for(ABILITY_LIGHTNING_ROD,:lightning_rod_absorb).empty?
        @redirect_checks+=1 if lr; @absorb_checks+=1 if lr
        assert_true("Lightning Rod redirects Thunderbolt to A1, cancels it and raises SpA +1",lr,"redirects="+@redirect_records.inspect+" hp="+(a[1] ? a[1].hp.to_i.to_s : "nil")+" spa="+(a[1] ? a[1].cg_stat_stage(:spa).to_i.to_s : "nil"))
        sd=redirect_for?(ABILITY_STORM_DRAIN,55,3,2) && a[2] && a[2].hp.to_i==@r1_a2_hp.to_i && a[2].cg_stat_stage(:spa).to_i==1 && !records_for(ABILITY_STORM_DRAIN,:storm_drain_absorb).empty?
        @redirect_checks+=1 if sd; @absorb_checks+=1 if sd
        assert_true("Storm Drain redirects Water Gun to A2, cancels it and raises SpA +1",sd,"redirects="+@redirect_records.inspect+" hp="+(a[2] ? a[2].hp.to_i.to_s : "nil")+" spa="+(a[2] ? a[2].cg_stat_stage(:spa).to_i.to_s : "nil"))
        pt=a[3]&&a[3].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON)&&!records_for(ABILITY_POISON_TOUCH,:poison_touch).empty?
        @contact_checks+=1 if pt; assert_true("Poison Touch poisons target after real contact damage",pt,(records_for(ABILITY_POISON_TOUCH,:poison_touch)[-1]||{}).inspect)
        an=records_for(ABILITY_ANALYTIC,:analytic)[-1]||{}; anok=an[:before].to_i>0&&an[:after].to_i==ratio(an[:before],ANALYTIC_PERCENT,100)
        @damage_checks+=1 if anok; assert_true("Analytic boosts damage x1.30 when target already acted",anok,an.inspect)
        fv=@r1_flower_grass==true && @r1_flower_stage_before.to_i==@r1_flower_stage_after.to_i && !records_for(ABILITY_FLOWER_VEIL,:flower_veil_stat).empty?
        @team_guard_checks+=1 if fv; assert_true("Flower Veil blocks external ATK drop on Grass ally",fv,"before="+@r1_flower_stage_before.to_s+" after="+@r1_flower_stage_after.to_s+" record="+(records_for(ABILITY_FLOWER_VEIL,:flower_veil_stat)[-1]||{}).inspect)
        layers=field ? field.state.hazards[:ally][:toxic_spikes].to_i : 0; td=layers==1&&!records_for(ABILITY_TOXIC_DEBRIS,:toxic_debris).empty?
        @field_checks+=1 if td; assert_true("Toxic Debris places one Toxic Spikes layer on attacker side",td,"layers="+layers.to_s+" record="+(records_for(ABILITY_TOXIC_DEBRIS,:toxic_debris)[-1]||{}).inspect)
      elsif r==2
        sw=e[3]&&e[4]&&e[3].hidden&&!e[4].hidden; @lifecycle_checks+=1 if sw; assert_true("Teleport deploys hidden Wind Rider reserve",sw,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        sa=storage_size; stor=sa==@r2_storage_before.to_i; @lifecycle_checks+=1 if stor; assert_true("Wind Rider reserve switch does not consume Storage Pokemon",stor,"before="+@r2_storage_before.to_s+" after="+sa.to_s)
      elsif r==3
        av=e[2]&&e[2].respond_to?(:cg_v234_taunt_active?)&&!e[2].cg_v234_taunt_active?&&!records_for(ABILITY_AROMA_VEIL,:aroma_veil).empty?
        @team_guard_checks+=1 if av; assert_true("Aroma Veil blocks Taunt on active ally",av,(records_for(ABILITY_AROMA_VEIL,:aroma_veil)[-1]||{}).inspect)
        bad=(ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON) ? ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON : 0)
        fs=e[2]&&!e[2].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON)&&(bad<=0||!e[2].state?(bad))&&!records_for(ABILITY_FLOWER_VEIL,:flower_veil_state).empty?
        @team_guard_checks+=1 if fs; assert_true("Flower Veil blocks Toxic on Grass ally",fs,(records_for(ABILITY_FLOWER_VEIL,:flower_veil_state)[-1]||{}).inspect)
        tw=@r3_tailwind_after.to_i==@r3_tailwind_before.to_i+1 && !records_for(ABILITY_WIND_RIDER,:wind_rider_tailwind).empty?
        @wind_checks+=1 if tw; assert_true("Wind Rider gains ATK +1 when same-side Tailwind takes effect",tw,"before="+@r3_tailwind_before.to_s+" after="+@r3_tailwind_after.to_s)
        hit=records_for(ABILITY_WIND_RIDER,:wind_rider_hit)[-1]||{}; wh=e[4]&&e[4].hp.to_i==@r3_wind_hp_before.to_i&&hit[:after].to_i==hit[:before].to_i+1
        @wind_checks+=1 if wh; assert_true("Wind Rider cancels Gust and raises ATK +1",wh,"hp="+(e[4] ? e[4].hp.to_i.to_s : "nil")+" record="+hit.inspect)
        stable=e[4]&&!e[4].hidden&&e[4].hp.to_i>0; assert_true("Wind Rider reserve remains active through Round3",stable,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" hp="+(e[4] ? e[4].hp.to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end

    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_z,nil) if b}; end

    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"
      log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_z="+ability_covered_count.to_s+"/8 redirect_checks="+@redirect_checks.to_i.to_s+" absorb_checks="+@absorb_checks.to_i.to_s+" contact_checks="+@contact_checks.to_i.to_s+" damage_checks="+@damage_checks.to_i.to_s+" team_guard_checks="+@team_guard_checks.to_i.to_s+" field_checks="+@field_checks.to_i.to_s+" wind_checks="+@wind_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=165")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}
      cleanup_test_overrides; @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end

    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @redirect_records=[]; @actual=[]; @boot_asserted=false
      @redirect_checks=0; @absorb_checks=0; @contact_checks=0; @damage_checks=0; @team_guard_checks=0; @field_checks=0; @wind_checks=0; @lifecycle_checks=0
      @r1_flower_grass=false; @r1_flower_stage_before=0; @r1_flower_stage_after=0; @r1_a1_hp=0; @r1_a2_hp=0; @r2_storage_before=0; @r3_wind_hp_before=0; @r3_tailwind_before=0; @r3_tailwind_after=0
    end

    def self.start_auto_test
      return false if active?
      reset_log; reset_suite; prepare_test_party; make_test_troop
      ALBERT_CG::UNIQUE_I_V242.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_I_V242)&&ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes)
      @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_Z_v2.5.25") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
      false
    end
  end
end

ALBERT_CG::ABILITY_Z_V2525.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ F11 ownership：只保留最新 Batch Z
#==============================================================================
if defined?(ALBERT_CG::ABILITY_Y_V2524)
  module ALBERT_CG; module ABILITY_Y_V2524; def self.f11_trigger?; false; end; end; end
end

#==============================================================================
# ■ Formal Lightning Rod / Storm Drain typed redirection
#==============================================================================
class Game_BattleAction
  alias cg_v2525z_typed_redirect_make_targets make_targets
  def make_targets
    targets=cg_v2525z_typed_redirect_make_targets
    if defined?(ALBERT_CG::ABILITY_Z_V2525)
      targets=ALBERT_CG::ABILITY_Z_V2525.apply_type_redirect(self,targets)
    end
    targets
  end
end

#==============================================================================
# ■ Formal Poison Touch / Analytic acted-state lifecycle
#==============================================================================
class Game_Battler
  alias cg_v2525z_poison_touch_execute_damage execute_damage
  def execute_damage(user)
    before=hp.to_i
    skill=(defined?(ALBERT_CG::ABILITY_V250)&&user!=nil ? ALBERT_CG::ABILITY_V250.current_skill(user) : nil)
    result=cg_v2525z_poison_touch_execute_damage(user)
    if defined?(ALBERT_CG::ABILITY_Z_V2525) && user!=nil && skill!=nil
      ALBERT_CG::ABILITY_Z_V2525.apply_poison_touch_after_damage(self,user,skill,[before-hp.to_i,0].max)
    end
    result
  end
end

#==============================================================================
# ■ Formal Aroma Veil：沿用 Unique B restriction setter
#==============================================================================
class Game_Battler
  if method_defined?(:cg_v234_disable_move)
    alias cg_v2525z_aroma_disable_move cg_v234_disable_move
    def cg_v234_disable_move(move_id)
      if defined?(ALBERT_CG::ABILITY_Z_V2525) && ALBERT_CG::ABILITY_Z_V2525.aroma_guard?(self,:disable)
        return
      end
      cg_v2525z_aroma_disable_move(move_id)
    end
  end
  if method_defined?(:cg_v234_set_encore)
    alias cg_v2525z_aroma_set_encore cg_v234_set_encore
    def cg_v234_set_encore(move_id)
      if defined?(ALBERT_CG::ABILITY_Z_V2525) && ALBERT_CG::ABILITY_Z_V2525.aroma_guard?(self,:encore)
        return
      end
      cg_v2525z_aroma_set_encore(move_id)
    end
  end
  if method_defined?(:cg_v234_set_taunt)
    alias cg_v2525z_aroma_set_taunt cg_v234_set_taunt
    def cg_v234_set_taunt
      if defined?(ALBERT_CG::ABILITY_Z_V2525) && ALBERT_CG::ABILITY_Z_V2525.aroma_guard?(self,:taunt)
        return
      end
      cg_v2525z_aroma_set_taunt
    end
  end
end

#==============================================================================
# ■ Formal Flower Veil：State Guard Authority 擴充
#==============================================================================
if defined?(ALBERT_CG::ABILITY_GUARD_V251)
  module ALBERT_CG
    module ABILITY_GUARD_V251
      class << self
        alias cg_v2525z_guard_state guard_state?
        def guard_state?(battler,state_id)
          if defined?(ALBERT_CG::ABILITY_Z_V2525) && ALBERT_CG::ABILITY_Z_V2525.flower_state_guard_info(battler,state_id)!=nil
            return true
          end
          cg_v2525z_guard_state(battler,state_id)
        end
        alias cg_v2525z_block_state block_state
        def block_state(battler,state_id,source=:unknown)
          if defined?(ALBERT_CG::ABILITY_Z_V2525)
            info=ALBERT_CG::ABILITY_Z_V2525.flower_state_guard_info(battler,state_id)
            if info!=nil
              ALBERT_CG::ABILITY_Z_V2525.note_flower_state_guard(info,battler,state_id,source)
              return true
            end
          end
          cg_v2525z_block_state(battler,state_id,source)
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal Flower Veil：external negative stat stage guard
#==============================================================================
class Game_Battler
  alias cg_v2525z_flower_change_stage cg_change_stat_stage
  def cg_change_stat_stage(key,amount)
    if defined?(ALBERT_CG::ABILITY_Z_V2525)
      info=ALBERT_CG::ABILITY_Z_V2525.flower_stat_guard_info(self,key,amount)
      if info!=nil
        ALBERT_CG::ABILITY_Z_V2525.note_flower_stat_guard(info,self)
        return 0
      end
    end
    cg_v2525z_flower_change_stage(key,amount)
  end
end

#==============================================================================
# ■ Formal Wind Rider：Tailwind activation bridge
#==============================================================================
if defined?(ALBERT_CG::FIELD_V233)
  module ALBERT_CG
    module FIELD_V233
      class << self
        alias cg_v2525z_apply_move apply_move
        def apply_move(user,target,move_id)
          result=cg_v2525z_apply_move(user,target,move_id)
          if result && move_id.to_i==366 && defined?(ALBERT_CG::ABILITY_Z_V2525)
            ALBERT_CG::ABILITY_Z_V2525.apply_tailwind_wind_rider(user)
          end
          result
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal Analytic acted flag + TEST execution record
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2525z_execute_action execute_action
  def execute_action
    b=@active_battler
    ALBERT_CG::ABILITY_Z_V2525.record_execution(b) if defined?(ALBERT_CG::ABILITY_Z_V2525)&&ALBERT_CG::ABILITY_Z_V2525.active?
    result=cg_v2525z_execute_action
    b.instance_variable_set(:@cg_v2525z_acted,true) if b!=nil
    result
  end

  alias cg_v2525z_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_Z_V2525)&&ALBERT_CG::ABILITY_Z_V2525.active?
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_Z_V2525.finish_round_assertions
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      else
        ALBERT_CG::ABILITY_Z_V2525.finish_round_assertions
      end
    end
    result=cg_v2525z_turn_end
    ALBERT_CG::ABILITY_Z_V2525.clear_acted_flags if defined?(ALBERT_CG::ABILITY_Z_V2525)
    result
  end

  alias cg_v2525z_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_Z_V2525)&&ALBERT_CG::ABILITY_Z_V2525.active?
      return cg_v2525z_start_party_command
    end
    cg_v2525z_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_Z_V2525.assert_bootstrap_once
    if ALBERT_CG::ABILITY_Z_V2525.finished?
      ALBERT_CG::ABILITY_Z_V2525.finish_suite; battle_end(0); return
    end
    ALBERT_CG::ABILITY_Z_V2525.prepare_round_actions; start_main
  end
end

#==============================================================================
# ■ TEST-only deterministic speeds / enemy actions / demo party / F11
#==============================================================================
class Game_Battler
  alias cg_v2525z_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_Z_V2525)&&ALBERT_CG::ABILITY_Z_V2525.active?
      v=@cg_priority_test_speed_override_z; return v.to_i if v!=nil
    end
    cg_v2525z_priority_base_speed
  rescue
    cg_v2525z_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2525z_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_Z_V2525)&&ALBERT_CG::ABILITY_Z_V2525.active?
      a=ALBERT_CG::ABILITY_Z_V2525.forced_enemy_action(self)
      if a
        cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return
      end
    end
    cg_v2525z_enemy_make_action
  end
end

module ALBERT_CG
  class << self
    alias cg_v2525z_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2525z_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_Z_V2525)&&ALBERT_CG::ABILITY_Z_V2525.active?
        ALBERT_CG::ABILITY_Z_V2525::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_Z_V2525.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if h
          h.change_level(ALBERT_CG::ABILITY_Z_V2525::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); h.instance_variable_set(:@cg_v2525z_acted,false)
        end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2525z_scene_map_update update
  def update
    cg_v2525z_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_Z_V2525)
    ALBERT_CG::ABILITY_Z_V2525.start_auto_test if ALBERT_CG::ABILITY_Z_V2525.f11_trigger?
  end
end
