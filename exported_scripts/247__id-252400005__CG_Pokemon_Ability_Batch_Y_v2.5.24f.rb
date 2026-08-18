# RMVX_SCRIPT_INDEX: 247
# RMVX_SCRIPT_ID: 252400005
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch Y v2.5.24f
# RMVX_SOURCE_SHA256: aaa7ffcc26da49c3596d3ecc1cd1f336c84e0cbc19f643ea61107c737c10d9d4

#==============================================================================
# ■ CG Pokemon Ability Batch Y v2.5.24f - Indirect Guard + Targeting Bypass PRE-ACTION PRESENTATION END FIX TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.23a Ability Batch X RPG Maker VX 實機 PASS 為唯一正式基底，保留 v2.5.24a
#  已完成的 Infiltrator／Unseen Fist Formal bypass 修正，並修正 v2.5.24e 實機 trace
#  確認的 Tankentai pre-action presentation 時序問題。
#
#  v2.5.24e 已證明 Stalwart 242 在 Unique C redirect Authority 中真正保留原目標：
#  make_targets 明確回傳 Human A0 / Tom#0；但在 target_decision 之後沒有進入
#  Sprite_Battler OBJ_ANIM -> Scene_Battle#damage_action -> skill_effect。
#
#  根因不是 Stalwart targeting，而是 Ability Core 的同步特性提示：
#  Scene_Battle#execute_action 已先把使用者 active=true，Stalwart 在 target_decision
#  內觸發 formal_note -> present_trigger -> cg_show_special_action_text -> wait(45)；
#  此時技能 Action 尚未 set_action。等待期間使用者舊待機 Action 若剛好跑到 End，
#  Sideview 會因 active=true 把舊 "End" 寫入 battler.play。之後 set_action 雖已開始
#  新技能，playing_action 卻先讀到舊 End，立刻 action_end，使新技能的 OBJ_ANIM
#  永遠無法送出。Propeller Tail 239 使用相同 targeting hook，僅因 Sprite Idle 時序
#  不同而未穩定重現，因此本版兩者一併套用 pre-action presentation safety。
#
# 【本批 Ability】
#   98 Magic Guard     魔法防守：防止本專案間接傷害（主要 residual、天氣、entry hazard damage、Powder 爆炸）。
#  140 Telepathy       心靈感應：免疫同側隊友造成的 damaging Move。
#  142 Overcoat        防塵：免疫 Sandstorm/Hail damage；沿用既有 Powder / Rage Powder / Effect Spore immunity。
#  147 Wonder Skin     奇跡皮膚：對手 Status Move 對 holder 的最終命中率上限 50%。
#  151 Infiltrator     穿透：無視 Reflect/Light Screen/Aurora Veil、Safeguard/Mist 與 Substitute。
#  239 Propeller Tail  螺旋尾鰭：單體招式無視 Follow Me / Rage Powder / Spotlight redirect。
#  242 Stalwart        堅毅：同 Propeller Tail，單體招式無視 redirect。
#  260 Unseen Fist     無形拳：接觸招式無視 Protect 與共用 Protect Authority 的反應盾。
#
# 【主要設定項】
#  TEST_TROOP_ID=727；HANDLED_ABILITY_IDS=8。
#  Coverage：192/373 -> 200/373，pending 181 -> 173。
#
# 【機制規則】
#  1. Magic Guard 不直接重寫 slip_damage_effect：只暫時隔離 Poison/Bad Poison/Burn/Trap/
#     Leech Seed 等傷害型 residual state，再交回既有 chain。
#  2. Telepathy 僅阻擋 same-side damaging Move；Status Move、自我招式與敵方攻擊不阻擋。
#  3. Overcoat 的 Powder immunity 沿用既有 Authority；本頁補 weather residual guard 與 trigger note。
#  4. Wonder Skin 包在既有 calc_hit 最外層，對 opposing Status Move 將最終命中率 cap 50%。
#  5. Infiltrator 沿用 v2.5.24a：screen / Substitute / Safeguard / Mist 都只在該次 Action
#     暫時隱藏後呼叫既有 Authority，再原樣還原。
#  6. Propeller Tail / Stalwart 的 redirect 判定本身不改：仍包覆 Unique C redirect_target_for，
#     偵測合法單體招式與 active redirector，保留原 target。
#  7. v2.5.24f 新增 targeting presentation safety：在 239/242 的 blocking Ability 提示
#     顯示期間，暫時把「正在準備 Action、但尚未 set_action」的使用者 active=false，
#     並在提示前後把 battler.play 清為 0；提示結束後恢復原 active。此處只防止舊 Idle End
#     污染下一個新 Action，不直接補傷害、不修改 target、不繞過 Tankentai。
#  8. Unseen Fist 保留 v2.5.24a full-chain Protect bypass：只在合法 contact skill_effect
#     期間暫時隱藏 Protect flag/state，結束後原樣還原。
#  9. F11 Regression 仍使用 Human A0 作為 Stalwart 原目標，Follow Me redirector=A3；
#     Aura Sphere 必須先留下 242 bypass trigger，再正常進入 OBJ_ANIM / damage_action 並使 A0 HP 下降。
#
# 【可調參數】
#  TEST_TROOP_ID、TEST_SPEEDS、ROUND_PLANS。正式 Ability 倍率／規則無額外可調參數。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，自動進 troop 727，跑三回合並輸出
#  Pokemon_Ability_Y_AutoTest_v2_5_24f.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：Magic Guard residual/weather、Telepathy、Wonder Skin、Overcoat Powder。
#  Round2：Follow Me=A3；Infiltrator E1 Water Gun 穿 Substitute；Propeller Tail E2 Water Gun
#          保留 A1；Stalwart E3 Aura Sphere 保留 Human A0。239/242 Ability 提示不得再讓
#          舊 Idle End 提前終止 Action；E0 最後 Teleport。
#  Round3：Unseen Fist reserve E4 用 contact Tackle 穿真正 Protect。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchY"] = "2.5.24f"

module ALBERT_CG
  module ABILITY_Y_V2524
    VERSION = "2.5.24f"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 727
    VK_F11 = 0x7A

    ABILITY_MAGIC_GUARD     = 98
    ABILITY_TELEPATHY       = 140
    ABILITY_OVERCOAT        = 142
    ABILITY_WONDER_SKIN     = 147
    ABILITY_INFILTRATOR     = 151
    ABILITY_PROPELLER_TAIL  = 239
    ABILITY_STALWART        = 242
    ABILITY_UNSEEN_FIST     = 260
    HANDLED_ABILITY_IDS = [98,140,142,147,151,239,242,260]

    TEST_ALLIES = [
      {:dex=>25, :level=>40,:ability=>ABILITY_MAGIC_GUARD,:moves=>[600,150,150,150]},
      {:dex=>65, :level=>40,:ability=>ABILITY_TELEPATHY,  :moves=>[150,150,150,150]},
      {:dex=>128,:level=>40,:ability=>ABILITY_WONDER_SKIN,:moves=>[150,150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>60,:ability=>ABILITY_OVERCOAT,      :moves=>[150,100,150,150]},
      {:dex=>94, :level=>60,:ability=>ABILITY_INFILTRATOR,   :moves=>[150,55,150,150]},
      {:dex=>91, :level=>60,:ability=>ABILITY_PROPELLER_TAIL,:moves=>[150,55,150,150]},
      {:dex=>109,:level=>60,:ability=>ABILITY_STALWART,       :moves=>[150,396,150,150]},
      {:dex=>197,:level=>60,:ability=>ABILITY_UNSEEN_FIST,    :moves=>[150,150,33,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"INDIRECT_GUARDS_OVERCOAT_POWDER",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>600,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"INFILTRATOR_REDIRECT_BYPASS_AND_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>100,:target=>3},
          1=>{:kind=>:move,:move_id=>55,:target=>3},
          2=>{:kind=>:move,:move_id=>55,:target=>1},
          3=>{:kind=>:move,:move_id=>396,:target=>0},
        }
      },
      {
        :name=>"UNSEEN_FIST_PROTECT_BYPASS_STABILITY",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>33,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,310,260,250, 240,230,220,210,0],
      :r2=>[10,270,260,250, 10,300,290,280,0],
      :r3=>[10,270,260,250, 0,240,230,220,300],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M600","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
      2=>["A0:Guard","E1:M55","E2:M55","E3:M396","A1:M150","A2:M150","A3:M150","E0:M100"],
      3=>["A0:Guard","E4:M33","A1:M150","A2:M150","A3:M150","E1:M150","E2:M150","E3:M150"],
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
    def self.log_path; File.join(project_root,"Pokemon_Ability_Y_AutoTest_v2_5_24f.log"); end
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
      h="CG POKEMON ABILITY Y INDIRECT GUARD + TARGETING BYPASS AUTO REGRESSION v2.5.24f\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; indirect guard + telepathy + powder/weather + screen/substitute/redirect/protect bypass lifecycle\r\n"+
        "BASELINE=v2.5.23a Ability Batch X Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_X_PASS=192 BATCH_Y=8 PENDING=173\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue
    end

    def self.ability_id(b); core==nil || b==nil ? 0 : core.ability_id(b).to_i; rescue; 0; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill!=nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.move_row(mid); master ? master.move(mid.to_i) : nil; rescue; nil; end
    def self.status_move?(skill); r=move_row(move_id(skill)); r!=nil && r[7]==:status; rescue; false; end
    def self.damaging_move?(skill); r=move_row(move_id(skill)); r!=nil && r[7]!=:status && r[3].to_i>0; rescue; false; end
    def self.same_side?(a,b); a!=nil && b!=nil && (a.actor? == b.actor?); rescue; false; end
    def self.opposing?(a,b); a!=nil && b!=nil && (a.actor? != b.actor?); rescue; false; end
    def self.active_battlers; core ? core.active_battlers : []; rescue; []; end

    def self.note_local(aid,battler,kind,data=nil)
      return true unless active?
      @ability_trigger_counts[aid]=@ability_trigger_counts[aid].to_i+1
      rec={:ability=>aid,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless k==:battler||k==:user||k==:target||k==:skill||k==:action}
      @records[aid]=[] if @records[aid]==nil; @records[aid].push(rec)
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
      log("ABILITY_Y_TRIGGER ability="+aid.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
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

    # targeting / make_targets 期間專用：阻止同步 Ability 提示的 wait(45)
    # 讓舊 Idle Action 在使用者已 active=true、但新 skill 尚未 set_action 時送出 stale End。
    # 僅用於使用者本人的 239/242 redirect bypass presentation。
    def self.formal_note_pre_action_safe(aid,holder,kind,ctx=nil)
      return formal_note(aid,holder,kind,ctx) if holder==nil
      was_active = holder.respond_to?(:active) ? (holder.active ? true : false) : false
      begin
        holder.active = false if was_active && holder.respond_to?(:active=)
        holder.play = 0 if holder.respond_to?(:play=)
        result = formal_note(aid,holder,kind,ctx)
        holder.play = 0 if holder.respond_to?(:play=)
        return result
      ensure
        holder.active = true if was_active && holder.respond_to?(:active=)
      end
    rescue
      begin
        holder.active = true if holder!=nil && was_active && holder.respond_to?(:active=)
      rescue
      end
      true
    end

    def self.magic_guard_damage_states
      return [] unless defined?(ALBERT_CG::MOVE_EFFECT)
      m=ALBERT_CG::MOVE_EFFECT
      ids=[]
      [:STATE_POISON,:STATE_BAD_POISON,:STATE_BURN,:STATE_TRAP,:STATE_LEECH_SEED].each do |c|
        ids.push(m.const_get(c)) if m.const_defined?(c)
      end
      ids
    rescue
      []
    end

    def self.handle_magic_guard_slip(holder)
      return yield unless holder!=nil && ability_id(holder)==ABILITY_MAGIC_GUARD
      removed=[]
      magic_guard_damage_states.each do |sid|
        if holder.state?(sid)
          removed.push(sid); holder.remove_state(sid)
        end
      end
      return yield if removed.empty?
      before=holder.hp.to_i; result=nil
      begin
        result=yield
      ensure
        removed.each{|sid|holder.add_state(sid) unless holder.state?(sid)}
      end
      formal_note(ABILITY_MAGIC_GUARD,holder,:magic_guard_residual,{:states=>removed.inspect,:before=>before,:after=>holder.hp.to_i})
      result
    rescue
      yield
    end

    def self.weather_hurt?(b,weather)
      return false if b==nil || !b.respond_to?(:cg_pokemon_types)
      types=b.cg_pokemon_types||[]
      return !(types.include?(:rock)||types.include?(:ground)||types.include?(:steel)) if weather==:sandstorm
      return !types.include?(:ice) if weather==:hail
      false
    rescue
      false
    end

    def self.with_weather_guards
      f=field; return yield if f==nil || f.state==nil
      weather=f.state.weather; return yield unless [:sandstorm,:hail].include?(weather) && f.state.weather_turns.to_i>0
      saved={}; noted=[]; immune_type=(weather==:sandstorm ? :rock : :ice)
      active_battlers.each do |b|
        next if b==nil || b.hp.to_i<=0
        aid=ability_id(b); next unless [ABILITY_MAGIC_GUARD,ABILITY_OVERCOAT].include?(aid)
        next unless weather_hurt?(b,weather)
        raw=b.instance_variable_get(:@cg_v237_type_override)
        saved[b]=(raw==nil ? nil : raw.dup)
        b.instance_variable_set(:@cg_v237_type_override,[immune_type])
        noted.push([aid,b])
      end
      result=nil
      begin
        result=yield
      ensure
        saved.each{|b,raw|b.instance_variable_set(:@cg_v237_type_override,raw)}
      end
      noted.each do |pair|
        aid,b=pair
        kind=(aid==ABILITY_MAGIC_GUARD ? :magic_guard_weather : :overcoat_weather)
        formal_note(aid,b,kind,{:weather=>weather,:hp=>b.hp.to_i})
      end
      result
    rescue
      yield
    end

    def self.magic_guard_hazard?(b); b!=nil && ability_id(b)==ABILITY_MAGIC_GUARD; rescue; false; end
    def self.with_magic_guard_hazards(b)
      f=field; return yield unless magic_guard_hazard?(b) && f!=nil
      side=f.side_key(b); table=f.state.hazards[side]; return yield if table==nil
      spikes=table[:spikes]; rock=table[:stealth_rock]
      had=spikes.to_i>0 || rock.to_i>0
      table[:spikes]=0; table[:stealth_rock]=0
      result=nil
      begin
        result=yield
      ensure
        table[:spikes]=spikes; table[:stealth_rock]=rock
      end
      formal_note(ABILITY_MAGIC_GUARD,b,:magic_guard_hazard,{:side=>side}) if had
      result
    rescue
      yield
    end

    def self.telepathy_block?(target,user,skill)
      target!=nil && user!=nil && skill!=nil && ability_id(target)==ABILITY_TELEPATHY && same_side?(target,user) && target!=user && damaging_move?(skill)
    rescue
      false
    end

    def self.wonder_skin_hit(target,user,skill,base)
      return base unless target!=nil && user!=nil && skill!=nil && ability_id(target)==ABILITY_WONDER_SKIN && opposing?(target,user) && status_move?(skill)
      value=[base.to_i,50].min
      formal_note(ABILITY_WONDER_SKIN,target,:wonder_skin,{:move_id=>move_id(skill),:before=>base.to_i,:after=>value}) if value<base.to_i
      value
    rescue
      base
    end

    def self.infiltrator?(user,target=nil)
      user!=nil && ability_id(user)==ABILITY_INFILTRATOR && (target==nil || opposing?(user,target))
    rescue
      false
    end

    def self.with_infiltrator_screens(user,target,skill,type_id,damage_class,move_id_value)
      f=field; return yield unless infiltrator?(user,target) && f!=nil
      side=f.side_key(target); h=f.state.sides[side]; return yield if h==nil
      keys=[:reflect,:light_screen,:aurora_veil]; saved={}; active=[]
      keys.each do |k|
        if h[k].to_i>0
          saved[k]=h[k]; active.push(k); h.delete(k)
        end
      end
      return yield if active.empty?
      result=nil
      begin
        result=yield
      ensure
        saved.each{|k,v|h[k]=v}
      end
      formal_note(ABILITY_INFILTRATOR,user,:infiltrator_screen,{:move_id=>move_id_value.to_i,:screens=>active.inspect,:value=>result.to_i})
      result
    rescue
      yield
    end

    def self.with_infiltrator_substitute(target,user,skill)
      return yield unless infiltrator?(user,target) && target.respond_to?(:cg_v234_substitute_active?) && target.cg_v234_substitute_active?
      shield=target.respond_to?(:cg_v234_substitute_hp) ? target.cg_v234_substitute_hp.to_i : 0
      before=target.hp.to_i
      target.instance_variable_set(:@cg_v234_substitute_hp,0)
      result=nil
      begin
        result=yield
      ensure
        target.instance_variable_set(:@cg_v234_substitute_hp,shield) if target.hp.to_i>0
      end
      formal_note(ABILITY_INFILTRATOR,user,:infiltrator_substitute,{:move_id=>move_id(skill),:shield=>shield,:before=>before,:after=>target.hp.to_i})
      result
    rescue
      yield
    end

    def self.with_infiltrator_side_effect(user,target,key)
      f=field; return yield unless infiltrator?(user,target) && f!=nil
      side=f.side_key(target); h=f.state.sides[side]; return yield if h==nil || h[key].to_i<=0
      saved=h[key]; h.delete(key)
      result=nil
      begin
        result=yield
      ensure
        h[key]=saved
      end
      formal_note(ABILITY_INFILTRATOR,user,(key==:safeguard ? :infiltrator_safeguard : :infiltrator_mist),{:effect=>key})
      result
    rescue
      yield
    end

    def self.redirect_bypass_info(action,original)
      return nil if action==nil || original==nil || original.empty? || !defined?(ALBERT_CG::UNIQUE_C_V236)
      b=action.battler; return nil if b==nil
      aid=ability_id(b); return nil unless [ABILITY_PROPELLER_TAIL,ABILITY_STALWART].include?(aid)
      one=action.attack?
      if action.skill?
        sk=action.skill; one=(sk!=nil && sk.scope.to_i==1)
      end
      return nil unless one
      redirects=ALBERT_CG::UNIQUE_C_V236.instance_variable_get(:@redirectors)
      side=b.actor? ? :enemy : :actor
      red=redirects==nil ? nil : redirects[side]
      return nil if red==nil || !red.exist? || original[0]==red
      [aid,b,red]
    rescue
      nil
    end

    def self.note_redirect_bypass(info,action,original)
      aid,b,red=info
      kind=(aid==ABILITY_PROPELLER_TAIL ? :propeller_tail : :stalwart)
      data={:move_id=>(action.skill? ? move_id(action.skill) : 0),:from=>(original[0] ? original[0].index.to_i : -1),:redirector=>red.index.to_i}
      if active?
        log("TARGET_PRESENT_SAFE before ability="+aid.to_s+" battler="+b.name.to_s+" active="+(b.active ? "true" : "false")+" play="+b.play.inspect)
      end
      formal_note_pre_action_safe(aid,b,kind,data)
      if active?
        log("TARGET_PRESENT_SAFE after ability="+aid.to_s+" battler="+b.name.to_s+" active="+(b.active ? "true" : "false")+" play="+b.play.inspect)
      end
      true
    rescue
      true
    end

    # TEST-only：v2.5.24f Stalwart 最終 target / damage trace。
    # 僅在本批 F11 suite Round2、Ability 242 holder 行動時寫 LOG，不參與正式判定與傷害。
    def self.stalwart_trace?(user=nil)
      return false unless active? && current_round==2
      return true if user==nil
      ability_id(user)==ABILITY_STALWART
    rescue
      false
    end

    def self.trace_stalwart_targets(action,targets)
      return unless stalwart_trace?(action==nil ? nil : action.battler)
      names=(targets||[]).map{|t| t==nil ? "nil" : t.name.to_s+"#"+t.index.to_i.to_s}
      log("STALWART_TRACE make_targets target_index="+(action ? action.target_index.to_i.to_s : "nil")+" targets="+names.inspect)
    rescue
    end

    def self.trace_stalwart_skill(stage,target,user,skill,extra="")
      return unless stalwart_trace?(user)
      mid=skill==nil ? 0 : move_id(skill)
      log("STALWART_TRACE "+stage.to_s+" user="+(user ? user.name.to_s : "nil")+" target="+(target ? target.name.to_s : "nil")+"#"+(target ? target.index.to_i.to_s : "nil")+" move="+mid.to_s+" hp="+(target ? target.hp.to_i.to_s : "nil")+" "+extra.to_s)
    rescue
    end

    def self.unseen_fist_bypass?(target,user,lower)
      return false unless lower && target!=nil && user!=nil && ability_id(user)==ABILITY_UNSEEN_FIST && opposing?(target,user)
      return false unless core && core.contact_action?(user)
      a=user.respond_to?(:action) ? user.action : nil
      unless a!=nil && a.instance_variable_get(:@cg_v2524_unseen_noted)==true
        a.instance_variable_set(:@cg_v2524_unseen_noted,true) if a!=nil
        formal_note(ABILITY_UNSEEN_FIST,user,:unseen_fist,{:move_id=>(a&&a.skill? ? move_id(a.skill) : 0),:target=>target.index.to_i})
      end
      true
    rescue
      false
    end

    # v2.5.24a：完整 Protect chain bypass。
    # v2.5.24 只覆寫 cg_protect_blocks_v232b?，但更底層 MoveEffect Core 仍直接檢查
    # STATE_PROTECT，形成「Ability 已觸發但傷害仍被舊層擋下」的正式 Runtime 漏洞。
    def self.with_unseen_fist_protect(target,user,skill)
      return yield if target==nil || user==nil || ability_id(user)!=ABILITY_UNSEEN_FIST || !opposing?(target,user)
      return yield unless core && core.contact_action?(user)
      active = target.respond_to?(:cg_protect_active_v232b?) ? target.cg_protect_active_v232b? : false
      return yield unless active
      old_flag=target.instance_variable_get(:@cg_protect_v231)
      sid=nil; had_state=false
      if defined?(ALBERT_CG::MOVE_EFFECT) && ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_PROTECT)
        sid=ALBERT_CG::MOVE_EFFECT::STATE_PROTECT
        had_state=target.state?(sid)
      end
      target.instance_variable_set(:@cg_protect_v231,false)
      target.remove_state(sid) if sid!=nil && had_state
      a=user.respond_to?(:action) ? user.action : nil
      unless a!=nil && a.instance_variable_get(:@cg_v2524_unseen_noted)==true
        a.instance_variable_set(:@cg_v2524_unseen_noted,true) if a!=nil
        formal_note(ABILITY_UNSEEN_FIST,user,:unseen_fist,{:move_id=>move_id(skill),:target=>target.index.to_i,:full_chain=>true})
      end
      result=nil
      begin
        result=yield
      ensure
        target.instance_variable_set(:@cg_protect_v231,old_flag)
        target.add_state(sid) if sid!=nil && had_state && !target.state?(sid)
      end
      result
    rescue
      yield
    end

    def self.note_overcoat_powder(target)
      return false unless target!=nil && ability_id(target)==ABILITY_OVERCOAT
      formal_note(ABILITY_OVERCOAT,target,:overcoat_powder,{})
      true
    rescue
      false
    end

    def self.magic_guard_powder?(b)
      return false unless b!=nil && ability_id(b)==ABILITY_MAGIC_GUARD
      return false unless b.instance_variable_get(:@cg_v239_powdered)==true
      b.instance_variable_set(:@cg_v239_powdered,false)
      formal_note(ABILITY_MAGIC_GUARD,b,:magic_guard_powder,{:hp=>b.hp.to_i})
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
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability Y v2.5.24f AutoRegression",ms)
    end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); else; a.clear; end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c); end
    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||TEST_SPEEDS[:r1]||[]
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_y,vals[i]) if b}
    end
    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end
    def self.clear_runtime_flags(b)
      return if b==nil
      b.recover_all if b.respond_to?(:recover_all)
      b.cg_reset_stat_stages if b.respond_to?(:cg_reset_stat_stages)
      b.cg_v234_clear_battle_memory if b.respond_to?(:cg_v234_clear_battle_memory)
      b.instance_variable_set(:@cg_protect_v231,false)
      if defined?(ALBERT_CG::MOVE_EFFECT) && ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_PROTECT)
        sid=ALBERT_CG::MOVE_EFFECT::STATE_PROTECT; b.remove_state(sid) if b.state?(sid)
      end
    rescue
    end
    def self.clear_round_states
      (test_allies+all_enemies).each{|b|clear_runtime_flags(b)}
      field.reset if field
      ALBERT_CG::UNIQUE_C_V236.clear_redirects if defined?(ALBERT_CG::UNIQUE_C_V236)&&ALBERT_CG::UNIQUE_C_V236.respond_to?(:clear_redirects)
    rescue
    end
    def self.records_for(aid,kind=nil); a=@records[aid]||[]; a.select{|r|kind==nil||r[:kind]==kind}; end

    def self.run_round1_probes
      a=test_allies; e=all_enemies; return unless a[1]&&a[2]&&a[3]&&e[0]&&e[1]
      m=ALBERT_CG::MOVE_EFFECT
      # Magic Guard poison residual
      a[1].recover_all; a[1].add_state(m::STATE_POISON); before=a[1].hp.to_i; a[1].slip_damage_effect; after=a[1].hp.to_i
      ok=(before==after)&&!records_for(ABILITY_MAGIC_GUARD,:magic_guard_residual).empty?; @residual_checks+=1 if ok; assert_true("Magic Guard blocks Poison residual",ok,"before="+before.to_s+" after="+after.to_s)
      a[1].remove_state(m::STATE_POISON) if a[1].state?(m::STATE_POISON)
      # Magic Guard + Overcoat weather residual
      field.state.weather=:sandstorm; field.state.weather_turns=2
      m1=a[1].hp.to_i; o1=e[0].hp.to_i; field.apply_weather_residual; m2=a[1].hp.to_i; o2=e[0].hp.to_i
      mg=(m1==m2)&&!records_for(ABILITY_MAGIC_GUARD,:magic_guard_weather).empty?; @residual_checks+=1 if mg; assert_true("Magic Guard blocks Sandstorm weather damage",mg,"hp="+m1.to_s+"->"+m2.to_s)
      ov=(o1==o2)&&!records_for(ABILITY_OVERCOAT,:overcoat_weather).empty?; @residual_checks+=1 if ov; assert_true("Overcoat blocks Sandstorm weather damage",ov,"hp="+o1.to_s+"->"+o2.to_s)
      # Telepathy direct same-side damaging Move probe
      a[2].recover_all; tskill=$data_skills[master.skill_id_for_move(33)]; tb=a[2].hp.to_i; a[2].skill_effect(a[1],tskill); ta=a[2].hp.to_i
      tele=(tb==ta)&&!records_for(ABILITY_TELEPATHY,:telepathy).empty?; @guard_checks+=1 if tele; assert_true("Telepathy blocks same-side damaging Move",tele,"hp="+tb.to_s+"->"+ta.to_s)
      # Wonder Skin hit cap
      toxic=$data_skills[master.skill_id_for_move(92)]; hit=a[3].calc_hit(e[1],toxic).to_i
      ws=(hit<=50)&&!records_for(ABILITY_WONDER_SKIN,:wonder_skin).empty?; @guard_checks+=1 if ws; assert_true("Wonder Skin caps opposing Status Move accuracy at 50",ws,"hit="+hit.to_s)
      (a+e).each{|b|b.recover_all if b&&b.respond_to?(:recover_all)}
      field.reset
    rescue=>ex
      assert_true("Round1 formal probes execute",false,ex.class.to_s+":"+ex.message.to_s)
    end

    def self.prepare_round_preconditions
      clear_round_states; apply_test_speeds
      if current_round==1
        run_round1_probes
      elsif current_round==2
        a=test_allies; e=all_enemies
        field.state.sides[:ally][:reflect]=5 if field
        a[3].recover_all; a[3].cg_v234_create_substitute if a[3].respond_to?(:cg_v234_create_substitute)
        @r2_a0_hp=a[0].hp.to_i; @r2_a1_hp=a[1].hp.to_i; @r2_a2_hp=a[2].hp.to_i; @r2_a3_hp=a[3].hp.to_i; @r2_a3_sub=a[3].cg_v234_substitute_hp.to_i
        if defined?(ALBERT_CG::UNIQUE_C_V236)
          ALBERT_CG::UNIQUE_C_V236.set_redirect(a[3],:follow_me)
        end
        # direct screen probe: same move under Reflect, Infiltrator must receive larger percent than normal attacker
        sk=$data_skills[master.skill_id_for_move(33)]; tid=sk.respond_to?(:cg_pokemon_type_id) ? sk.cg_pokemon_type_id : 0
        inf=field.damage_percent(e[1],a[3],sk,tid,:physical,33).to_i
        normal=field.damage_percent(e[2],a[3],sk,tid,:physical,33).to_i
        ok=inf>normal && !records_for(ABILITY_INFILTRATOR,:infiltrator_screen).empty?; @bypass_checks+=1 if ok
        assert_true("Infiltrator ignores Reflect damage reduction",ok,"infiltrator="+inf.to_s+" normal="+normal.to_s)
        @r2_storage_before=storage_size
      elsif current_round==3
        a=test_allies
        a[1].recover_all
        a[1].instance_variable_set(:@cg_protect_v231,true)
        if defined?(ALBERT_CG::MOVE_EFFECT)&&ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_PROTECT)
          a[1].add_state(ALBERT_CG::MOVE_EFFECT::STATE_PROTECT)
        end
        @r3_a1_hp=a[1].hp.to_i
        @r3_protect_blocks=a[1].respond_to?(:cg_protect_action_block_count_v232b) ? a[1].cg_protect_action_block_count_v232b.to_i : 0
      end
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

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      tid=($game_troop&&$game_troop.troop) ? $game_troop.troop.id.to_i : 0
      assert_true("Ability Catalog count=373",core&&core.catalog_count==373,"actual="+(core ? core.catalog_count.to_s : "nil"))
      assert_true("Ability Batch Y defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability Y test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability Y ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability Y starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden},"")
      assert_true("Ability Y starts with 1 hidden Unseen Fist reserve",all_enemies[4]&&all_enemies[4].hidden,"E4_hidden="+(all_enemies[4] ? all_enemies[4].hidden.to_s : "nil"))
    end

    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]; order=@actual==exp
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",order,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        ov=!records_for(ABILITY_OVERCOAT,:overcoat_powder).empty?; @guard_checks+=1 if ov; assert_true("Overcoat blocks real Powder Move",ov,(records_for(ABILITY_OVERCOAT,:overcoat_powder)[-1]||{}).inspect)
      elsif r==2
        sub=!records_for(ABILITY_INFILTRATOR,:infiltrator_substitute).empty? && a[3].hp.to_i<@r2_a3_hp.to_i && a[3].cg_v234_substitute_hp.to_i==@r2_a3_sub.to_i
        @bypass_checks+=1 if sub; assert_true("Infiltrator bypasses Substitute without consuming shield",sub,"hp="+@r2_a3_hp.to_s+"->"+a[3].hp.to_i.to_s+" shield="+@r2_a3_sub.to_s+"->"+a[3].cg_v234_substitute_hp.to_i.to_s)
        pt=!records_for(ABILITY_PROPELLER_TAIL,:propeller_tail).empty? && a[1].hp.to_i<@r2_a1_hp.to_i; @bypass_checks+=1 if pt; assert_true("Propeller Tail ignores Follow Me redirect",pt,(records_for(ABILITY_PROPELLER_TAIL,:propeller_tail)[-1]||{}).inspect+" hp="+@r2_a1_hp.to_s+"->"+a[1].hp.to_i.to_s)
        st=!records_for(ABILITY_STALWART,:stalwart).empty? && a[0].hp.to_i<@r2_a0_hp.to_i; @bypass_checks+=1 if st; assert_true("Stalwart ignores Follow Me redirect",st,(records_for(ABILITY_STALWART,:stalwart)[-1]||{}).inspect+" human_hp="+@r2_a0_hp.to_s+"->"+a[0].hp.to_i.to_s)
        switched=e[0]&&e[4]&&e[0].hidden&&!e[4].hidden; @lifecycle_checks+=1 if switched; assert_true("Teleport deploys hidden Unseen Fist reserve",switched,"E0_hidden="+(e[0] ? e[0].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        storage=storage_size==@r2_storage_before.to_i; @lifecycle_checks+=1 if storage; assert_true("Unseen Fist reserve switch does not consume Storage Pokemon",storage,"before="+@r2_storage_before.to_s+" after="+storage_size.to_s)
      elsif r==3
        blocks=a[1].respond_to?(:cg_protect_action_block_count_v232b) ? a[1].cg_protect_action_block_count_v232b.to_i : 0
        uf=!records_for(ABILITY_UNSEEN_FIST,:unseen_fist).empty? && a[1].hp.to_i<@r3_a1_hp.to_i && blocks==@r3_protect_blocks.to_i
        @bypass_checks+=1 if uf; assert_true("Unseen Fist contact Move bypasses Protect",uf,"hp="+@r3_a1_hp.to_s+"->"+a[1].hp.to_i.to_s+" protect_blocks="+@r3_protect_blocks.to_s+"->"+blocks.to_s)
        stable=e[4]&&!e[4].hidden&&e[4].hp.to_i>0; assert_true("Unseen Fist reserve remains active through Round3",stable,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" hp="+(e[4] ? e[4].hp.to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
      ALBERT_CG::UNIQUE_C_V236.clear_redirects if defined?(ALBERT_CG::UNIQUE_C_V236)&&ALBERT_CG::UNIQUE_C_V236.respond_to?(:clear_redirects)
    end

    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides
      (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_y,nil) if b}
    end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"; log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_y="+ability_covered_count.to_s+"/8 guard_checks="+@guard_checks.to_i.to_s+" bypass_checks="+@bypass_checks.to_i.to_s+" residual_checks="+@residual_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=173")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @guard_checks=0; @bypass_checks=0; @residual_checks=0; @lifecycle_checks=0; @r2_storage_before=0; @r2_a0_hp=0
    end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; ALBERT_CG::UNIQUE_I_V242.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_I_V242)&&ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes); @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_Y_v2.5.24f") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

if defined?(ALBERT_CG::ABILITY_X_V2523)
  module ALBERT_CG; module ABILITY_X_V2523; def self.f11_trigger?; false; end; end; end
end

#==============================================================================
# ■ Formal Magic Guard residual + Telepathy + Infiltrator Substitute bridge
#==============================================================================
class Game_Battler
  alias cg_v2524y_slip_damage_effect slip_damage_effect
  def slip_damage_effect
    if defined?(ALBERT_CG::ABILITY_Y_V2524)
      return ALBERT_CG::ABILITY_Y_V2524.handle_magic_guard_slip(self){cg_v2524y_slip_damage_effect}
    end
    cg_v2524y_slip_damage_effect
  end

  alias cg_v2524y_skill_effect skill_effect
  def skill_effect(user,skill)
    if defined?(ALBERT_CG::ABILITY_Y_V2524)
      if ALBERT_CG::ABILITY_Y_V2524.telepathy_block?(self,user,skill)
        clear_action_results; @skipped=true; @hp_damage=0
        ALBERT_CG::ABILITY_Y_V2524.formal_note(ALBERT_CG::ABILITY_Y_V2524::ABILITY_TELEPATHY,self,:telepathy,{:move_id=>ALBERT_CG::ABILITY_Y_V2524.move_id(skill)})
        return
      end
      if user!=nil && ALBERT_CG::ABILITY_Y_V2524.ability_id(user)==ALBERT_CG::ABILITY_Y_V2524::ABILITY_UNSEEN_FIST
        return ALBERT_CG::ABILITY_Y_V2524.with_unseen_fist_protect(self,user,skill){cg_v2524y_skill_effect(user,skill)}
      end
      if ALBERT_CG::ABILITY_Y_V2524.infiltrator?(user,self) && respond_to?(:cg_v234_substitute_active?) && cg_v234_substitute_active?
        return ALBERT_CG::ABILITY_Y_V2524.with_infiltrator_substitute(self,user,skill){cg_v2524y_skill_effect(user,skill)}
      end
    end
    cg_v2524y_skill_effect(user,skill)
  end

  # v2.5.24a：若側視 Action 將真正 execute_damage 延後到 skill_effect 外，
  # 仍在最後扣傷層暫時隱藏 Substitute shield，確保 Infiltrator 不被時序重新攔截。
  alias cg_v2524a_y_execute_damage execute_damage
  def execute_damage(user)
    if defined?(ALBERT_CG::ABILITY_Y_V2524) && @hp_damage.to_i>0 &&
       ALBERT_CG::ABILITY_Y_V2524.infiltrator?(user,self) &&
       respond_to?(:cg_v234_substitute_active?) && cg_v234_substitute_active?
      shield=respond_to?(:cg_v234_substitute_hp) ? cg_v234_substitute_hp.to_i : 0
      before=hp.to_i
      instance_variable_set(:@cg_v234_substitute_hp,0)
      result=nil
      begin
        result=cg_v2524a_y_execute_damage(user)
      ensure
        instance_variable_set(:@cg_v234_substitute_hp,shield) if hp.to_i>0
      end
      ALBERT_CG::ABILITY_Y_V2524.formal_note(
        ALBERT_CG::ABILITY_Y_V2524::ABILITY_INFILTRATOR,user,:infiltrator_substitute,
        {:move_id=>(user&&user.action&&user.action.skill? ? ALBERT_CG::ABILITY_Y_V2524.move_id(user.action.skill) : 0),
         :shield=>shield,:before=>before,:after=>hp.to_i,:execute_layer=>true})
      return result
    end
    cg_v2524a_y_execute_damage(user)
  end

  alias cg_v2524y_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    base=cg_v2524y_calc_hit(user,obj)
    if defined?(ALBERT_CG::ABILITY_Y_V2524)
      return ALBERT_CG::ABILITY_Y_V2524.wonder_skin_hit(self,user,obj,base)
    end
    base
  end

  alias cg_v2524y_apply_ailment cg_move_effect_apply_ailment
  def cg_move_effect_apply_ailment(user,move_id)
    if defined?(ALBERT_CG::ABILITY_Y_V2524) && ALBERT_CG::ABILITY_Y_V2524.infiltrator?(user,self)
      return ALBERT_CG::ABILITY_Y_V2524.with_infiltrator_side_effect(user,self,:safeguard){cg_v2524y_apply_ailment(user,move_id)}
    end
    cg_v2524y_apply_ailment(user,move_id)
  end

  alias cg_v2524y_apply_stats cg_move_effect_apply_stats
  def cg_move_effect_apply_stats(user,move_id)
    if defined?(ALBERT_CG::ABILITY_Y_V2524) && ALBERT_CG::ABILITY_Y_V2524.infiltrator?(user,self)
      return ALBERT_CG::ABILITY_Y_V2524.with_infiltrator_side_effect(user,self,:mist){cg_v2524y_apply_stats(user,move_id)}
    end
    cg_v2524y_apply_stats(user,move_id)
  end
end

#==============================================================================
# ■ Formal Weather / Hazard guard + Infiltrator Screen bridge
#==============================================================================
if defined?(ALBERT_CG::FIELD_V233)
  module ALBERT_CG
    module FIELD_V233
      class << self
        alias cg_v2524y_apply_weather_residual apply_weather_residual
        def apply_weather_residual
          if defined?(ALBERT_CG::ABILITY_Y_V2524)
            return ALBERT_CG::ABILITY_Y_V2524.with_weather_guards{cg_v2524y_apply_weather_residual}
          end
          cg_v2524y_apply_weather_residual
        end

        alias cg_v2524y_apply_entry_hazards apply_entry_hazards
        def apply_entry_hazards(battler)
          if defined?(ALBERT_CG::ABILITY_Y_V2524)
            return ALBERT_CG::ABILITY_Y_V2524.with_magic_guard_hazards(battler){cg_v2524y_apply_entry_hazards(battler)}
          end
          cg_v2524y_apply_entry_hazards(battler)
        end

        alias cg_v2524y_damage_percent damage_percent
        def damage_percent(user,target,skill,type_id,damage_class,move_id)
          if defined?(ALBERT_CG::ABILITY_Y_V2524)
            return ALBERT_CG::ABILITY_Y_V2524.with_infiltrator_screens(user,target,skill,type_id,damage_class,move_id){cg_v2524y_damage_percent(user,target,skill,type_id,damage_class,move_id)}
          end
          cg_v2524y_damage_percent(user,target,skill,type_id,damage_class,move_id)
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal Overcoat Powder + Magic Guard Powder bridge
#==============================================================================
if defined?(ALBERT_CG::UNIQUE_F_V239)
  module ALBERT_CG
    module UNIQUE_F_V239
      class << self
        alias cg_v2524y_apply_powder apply_powder
        def apply_powder(user,target)
          ALBERT_CG::ABILITY_Y_V2524.note_overcoat_powder(target) if defined?(ALBERT_CG::ABILITY_Y_V2524)
          cg_v2524y_apply_powder(user,target)
        end

        alias cg_v2524y_trigger_powder trigger_powder
        def trigger_powder(battler)
          if defined?(ALBERT_CG::ABILITY_Y_V2524) && ALBERT_CG::ABILITY_Y_V2524.magic_guard_powder?(battler)
            return true
          end
          cg_v2524y_trigger_powder(battler)
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal Propeller Tail / Stalwart Redirect bypass
#==============================================================================
if defined?(ALBERT_CG::UNIQUE_C_V236)
  module ALBERT_CG
    module UNIQUE_C_V236
      class << self
        alias cg_v2524y_redirect_target_for redirect_target_for
        def redirect_target_for(action,original)
          if defined?(ALBERT_CG::ABILITY_Y_V2524)
            info=ALBERT_CG::ABILITY_Y_V2524.redirect_bypass_info(action,original)
            if info!=nil
              ALBERT_CG::ABILITY_Y_V2524.note_redirect_bypass(info,action,original)
              return nil
            end
          end
          cg_v2524y_redirect_target_for(action,original)
        end
      end
    end
  end
end

#==============================================================================
# ■ TEST-only Stalwart target trace（不改 targets）
#==============================================================================
class Game_BattleAction
  alias cg_v2524d_y_trace_make_targets make_targets
  def make_targets
    targets=cg_v2524d_y_trace_make_targets
    if defined?(ALBERT_CG::ABILITY_Y_V2524)
      ALBERT_CG::ABILITY_Y_V2524.trace_stalwart_targets(self,targets)
    end
    targets
  end
end

#==============================================================================
# ■ TEST-only Stalwart skill / execute_damage trace（不改傷害）
#==============================================================================
class Game_Battler
  alias cg_v2524d_y_trace_skill_effect skill_effect
  def skill_effect(user,skill)
    if defined?(ALBERT_CG::ABILITY_Y_V2524)
      ALBERT_CG::ABILITY_Y_V2524.trace_stalwart_skill(:skill_before,self,user,skill,
        "skipped="+@skipped.to_s+" missed="+@missed.to_s+" evaded="+@evaded.to_s)
    end
    result=cg_v2524d_y_trace_skill_effect(user,skill)
    if defined?(ALBERT_CG::ABILITY_Y_V2524)
      ALBERT_CG::ABILITY_Y_V2524.trace_stalwart_skill(:skill_after,self,user,skill,
        "hp_damage="+@hp_damage.to_i.to_s+" skipped="+@skipped.to_s+" missed="+@missed.to_s+" evaded="+@evaded.to_s)
    end
    result
  end

  alias cg_v2524d_y_trace_execute_damage execute_damage
  def execute_damage(user)
    if defined?(ALBERT_CG::ABILITY_Y_V2524) && ALBERT_CG::ABILITY_Y_V2524.stalwart_trace?(user)
      before=hp.to_i; pending=@hp_damage.to_i
      ALBERT_CG::ABILITY_Y_V2524.log("STALWART_TRACE damage_before user="+user.name.to_s+" target="+name.to_s+"#"+index.to_i.to_s+" pending="+pending.to_s+" hp="+before.to_s)
      result=cg_v2524d_y_trace_execute_damage(user)
      ALBERT_CG::ABILITY_Y_V2524.log("STALWART_TRACE damage_after user="+user.name.to_s+" target="+name.to_s+"#"+index.to_i.to_s+" pending="+pending.to_s+" hp="+hp.to_i.to_s)
      return result
    end
    cg_v2524d_y_trace_execute_damage(user)
  end
end

#==============================================================================
# ■ Formal Unseen Fist Protect bypass
#==============================================================================
class Game_Battler
  alias cg_v2524y_protect_blocks_v232b cg_protect_blocks_v232b?
  def cg_protect_blocks_v232b?(user)
    lower=cg_v2524y_protect_blocks_v232b(user)
    if defined?(ALBERT_CG::ABILITY_Y_V2524) && ALBERT_CG::ABILITY_Y_V2524.unseen_fist_bypass?(self,user,lower)
      return false
    end
    lower
  end
end

#==============================================================================
# ■ TEST-only deterministic Scene_Battle harness
#==============================================================================
class Game_Battler
  alias cg_v2524y_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_Y_V2524)&&ALBERT_CG::ABILITY_Y_V2524.active?
      v=@cg_priority_test_speed_override_y; return v.to_i if v!=nil
    end
    cg_v2524y_ability_priority_base_speed
  rescue
    cg_v2524y_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2524y_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_Y_V2524)&&ALBERT_CG::ABILITY_Y_V2524.active?
      a=ALBERT_CG::ABILITY_Y_V2524.forced_enemy_action(self)
      if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end
    end
    cg_v2524y_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2524y_ability_execute_action execute_action
  def execute_action
    b=@active_battler; ALBERT_CG::ABILITY_Y_V2524.record_execution(b) if defined?(ALBERT_CG::ABILITY_Y_V2524)&&ALBERT_CG::ABILITY_Y_V2524.active?; cg_v2524y_ability_execute_action
  end
  alias cg_v2524y_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_Y_V2524)&&ALBERT_CG::ABILITY_Y_V2524.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_Y_V2524.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_Y_V2524.finish_round_assertions; end
    end
    cg_v2524y_ability_turn_end
  end
  alias cg_v2524y_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_Y_V2524)&&ALBERT_CG::ABILITY_Y_V2524.active?; return cg_v2524y_ability_start_party_command; end
    cg_v2524y_ability_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_Y_V2524.assert_bootstrap_once
    if ALBERT_CG::ABILITY_Y_V2524.finished?; ALBERT_CG::ABILITY_Y_V2524.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_Y_V2524.prepare_round_actions; start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2524y_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2524y_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_Y_V2524)&&ALBERT_CG::ABILITY_Y_V2524.active?
        ALBERT_CG::ABILITY_Y_V2524::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_Y_V2524.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_Y_V2524::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2524y_ability_scene_map_update update
  def update; cg_v2524y_ability_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_Y_V2524); ALBERT_CG::ABILITY_Y_V2524.start_auto_test if ALBERT_CG::ABILITY_Y_V2524.f11_trigger?; end
end


#==============================================================================
# ■ TEST-only Stalwart Tankentai / Scene damage gate trace（v2.5.24f）
#------------------------------------------------------------------------------
# 【用途】
#  僅供 Ability Y F11 Regression Round2 診斷 Stalwart。v2.5.24d 已證明
#  Game_BattleAction#make_targets 最終為原目標，但未進入 skill_effect / execute_damage。
#  本段只記錄 Tankentai battle_anime 是否送出 OBJ_ANIM、Scene_Battle#damage_action
#  是否收到事件，以及 reflection/invalid/targets 狀態；不改目標、不改命中、不改傷害。
#
# 【主要設定項】
#  無。僅當 ABILITY_Y_V2524.active?、Round2、使用者 Ability=242 時生效。
#
# 【機制規則】
#  1. Sprite_Battler#battle_anime 前後記錄 battler.active / battler.play / active_action。
#  2. Scene_Battle#damage_action 前後記錄 @targets / @reflection / @invalid。
#  3. magic_reflection / physics_reflection 記錄 target states 與 flag 前後值。
#  4. Game_Battler#perfect_skill_effect 補記必中／特殊 SBS 路徑。
#  5. 所有 wrapper 只寫 LOG，原方法一定完整執行。
#
# 【可調參數】
#  無。正式封版前可整段移除，不影響 Formal Runtime。
#
# 【事件／腳本呼叫方式】
#  無需事件呼叫；F11 Ability Y AutoRegression 自動啟用。
#
# 【實際範例】
#  STALWART_TRACE battle_anime_before active=true ...
#  STALWART_TRACE damage_action_before targets=["Tom#0"] invalid=false reflection=false
#==============================================================================
class Sprite_Battler < Sprite_Base
  if method_defined?(:battle_anime)
    alias cg_v2524e_y_trace_battle_anime battle_anime
    def battle_anime
      trace = false
      begin
        trace = defined?(ALBERT_CG::ABILITY_Y_V2524) &&
                ALBERT_CG::ABILITY_Y_V2524.stalwart_trace?(@battler)
      rescue
        trace = false
      end
      if trace
        ALBERT_CG::ABILITY_Y_V2524.log(
          "STALWART_TRACE battle_anime_before active=" + (@battler.active ? "true" : "false") +
          " play=" + @battler.play.inspect + " active_action=" + @active_action.inspect)
      end
      result = cg_v2524e_y_trace_battle_anime
      if trace
        ALBERT_CG::ABILITY_Y_V2524.log(
          "STALWART_TRACE battle_anime_after active=" + (@battler.active ? "true" : "false") +
          " play=" + @battler.play.inspect)
      end
      result
    end
  end
end

class Scene_Battle < Scene_Base
  if method_defined?(:damage_action)
    alias cg_v2524e_y_trace_damage_action damage_action
    def damage_action(action)
      trace = false
      begin
        trace = defined?(ALBERT_CG::ABILITY_Y_V2524) && @active_battler != nil &&
                ALBERT_CG::ABILITY_Y_V2524.stalwart_trace?(@active_battler)
      rescue
        trace = false
      end
      if trace
        names = (@targets || []).map{|t| t == nil ? "nil" : t.name.to_s+"#"+t.index.to_i.to_s}
        ALBERT_CG::ABILITY_Y_V2524.log(
          "STALWART_TRACE damage_action_before targets=" + names.inspect +
          " invalid=" + (@invalid == true ? "true" : "false") +
          " reflection=" + (@reflection == true ? "true" : "false") +
          " action=" + action.inspect)
      end
      result = cg_v2524e_y_trace_damage_action(action)
      if trace
        names = (@targets || []).map{|t| t == nil ? "nil" : t.name.to_s+"#"+t.index.to_i.to_s}
        ALBERT_CG::ABILITY_Y_V2524.log(
          "STALWART_TRACE damage_action_after targets=" + names.inspect +
          " invalid=" + (@invalid == true ? "true" : "false") +
          " reflection=" + (@reflection == true ? "true" : "false"))
      end
      result
    end
  end

  if method_defined?(:magic_reflection)
    alias cg_v2524e_y_trace_magic_reflection magic_reflection
    def magic_reflection(target,obj)
      trace = false
      begin
        trace = defined?(ALBERT_CG::ABILITY_Y_V2524) && @active_battler != nil &&
                ALBERT_CG::ABILITY_Y_V2524.stalwart_trace?(@active_battler)
      rescue
        trace = false
      end
      if trace
        states = target.states.map{|st| [st.id,st.name,(st.respond_to?(:extension) ? st.extension : [])]}
        ALBERT_CG::ABILITY_Y_V2524.log(
          "STALWART_TRACE magic_reflection_before target="+target.name.to_s+"#"+target.index.to_i.to_s+
          " states="+states.inspect+" invalid="+(@invalid==true ? "true" : "false")+
          " reflection="+(@reflection==true ? "true" : "false"))
      end
      result = cg_v2524e_y_trace_magic_reflection(target,obj)
      if trace
        ALBERT_CG::ABILITY_Y_V2524.log(
          "STALWART_TRACE magic_reflection_after invalid="+(@invalid==true ? "true" : "false")+
          " reflection="+(@reflection==true ? "true" : "false"))
      end
      result
    end
  end

  if method_defined?(:physics_reflection)
    alias cg_v2524e_y_trace_physics_reflection physics_reflection
    def physics_reflection(target,obj)
      trace = false
      begin
        trace = defined?(ALBERT_CG::ABILITY_Y_V2524) && @active_battler != nil &&
                ALBERT_CG::ABILITY_Y_V2524.stalwart_trace?(@active_battler)
      rescue
        trace = false
      end
      if trace
        ALBERT_CG::ABILITY_Y_V2524.log(
          "STALWART_TRACE physics_reflection_before target="+target.name.to_s+"#"+target.index.to_i.to_s+
          " invalid="+(@invalid==true ? "true" : "false")+
          " reflection="+(@reflection==true ? "true" : "false"))
      end
      result = cg_v2524e_y_trace_physics_reflection(target,obj)
      if trace
        ALBERT_CG::ABILITY_Y_V2524.log(
          "STALWART_TRACE physics_reflection_after invalid="+(@invalid==true ? "true" : "false")+
          " reflection="+(@reflection==true ? "true" : "false"))
      end
      result
    end
  end
end

class Game_Battler
  if method_defined?(:perfect_skill_effect)
    alias cg_v2524e_y_trace_perfect_skill_effect perfect_skill_effect
    def perfect_skill_effect(user,skill)
      trace = false
      begin
        trace = defined?(ALBERT_CG::ABILITY_Y_V2524) && ALBERT_CG::ABILITY_Y_V2524.stalwart_trace?(user)
      rescue
        trace = false
      end
      if trace
        ALBERT_CG::ABILITY_Y_V2524.trace_stalwart_skill(:perfect_before,self,user,skill,
          "hp_damage="+@hp_damage.to_i.to_s)
      end
      result = cg_v2524e_y_trace_perfect_skill_effect(user,skill)
      if trace
        ALBERT_CG::ABILITY_Y_V2524.trace_stalwart_skill(:perfect_after,self,user,skill,
          "hp_damage="+@hp_damage.to_i.to_s)
      end
      result
    end
  end
end
