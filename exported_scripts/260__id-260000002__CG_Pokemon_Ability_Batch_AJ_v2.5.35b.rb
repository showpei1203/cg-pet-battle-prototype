# RMVX_SCRIPT_INDEX: 260
# RMVX_SCRIPT_ID: 260000002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AJ v2.5.35b
# RMVX_SOURCE_SHA256: 748d7c6946c5fccf5e385b2474e099b080eae07f5ffc8fe440d0fd140a95eb3f

#==============================================================================
# ■ CG Pokemon Ability Batch AJ v2.5.35b
#------------------------------------------------------------------------------
# 【用途】
#  Ability Batch AJ：Dynamic Form / Reactive Identity Authority。
#  從 v2.5.34a Ability Batch AI RPG Maker VX 實機 PASS baseline 往後追加，
#  不修改已封版 Scripts 0..259。
#  v2.5.35b：Schooling 等級判定改接正式 cg_pokemon_level Authority，修正
#  v2.5.35b：Round 3 fixture 將已完成 Schooling 門檻驗證的 E1 中性 dummy
#  明確恢復 HP/MP，避免 Round 1 的 25% HP 測試狀態洩漏到後續 deterministic order。
#  Game_Enemy 被誤判成 Lv.1、開場錯進 Solo 的實機問題。
#
# 【本批正式處理 Ability】
#  161 Zen Mode        達摩模式
#  176 Stance Change   戰鬥切換
#  197 Shields Down    界限盾殼
#  208 Schooling       魚群
#  210 Battle Bond     牽絆變身（本專案採現行 KO 後能力提升規則）
#  241 Gulp Missile    一口飛彈
#  258 Hunger Switch   飽了又餓
#  278 Zero to Hero    全能變身
#
# 【機制規則】
#  1. FORM 仍不要求 PMD 圖像換裝；本批只建立 battle-local Form state、Type 與
#     Battle Base Stat Identity。視覺 Form 待未來 PMD Form 素材層再接，不讓素材阻塞規則。
#  2. Zen Mode：HP <= 50% 時切 Zen；>50% 回 Standard。Unovan profile：
#     Standard ATK/DEF/SPA/SPD/SPE=140/55/30/55/95、Fire；
#     Zen=30/105/140/105/55、Fire/Psychic。於 entry / end_turn 評估。
#  3. Stance Change：entry 為 Shield；使用 damaging Move 前切 Blade；使用 King's Shield
#     (Move 588) 前切回 Shield。Shield=50/140/50/140/60、Blade=140/50/140/50/60，
#     Type 均 Steel/Ghost。
#  4. Shields Down：HP > 50% 為 Meteor，<=50% 為 Core；entry / end_turn 評估。
#     Meteor=60/100/60/100/60、Core=100/60/100/60/120（ATK/DEF/SPA/SPD/SPE），
#     Type Rock/Flying。Meteor 另外阻擋主要異常與 Yawn。
#  5. Schooling：Lv>=20 且 HP >25% 為 School，否則 Solo；entry/end_turn 評估。
#     School=140/130/140/135/30、Solo=20/20/25/25/40，Type Water。
#  6. Battle Bond：每場戰鬥第一次由自己的 Move 真正擊倒對手後 ATK/SPA/SPE 各 +1；
#     不建立已退役的 Ash-Greninja PMD Form。
#  7. Gulp Missile：Surf(57)/Dive(291) 出手時依目前 HP 武裝；>50%=Gulping，<=50%=Gorging。
#     下一次受到 real damage 後，攻擊者失去 MaxHP 1/4；Gulping 額外 DEF -1，
#     Gorging 額外 Paralysis，然後解除武裝。
#  8. Hunger Switch：entry 為 Full Belly，每個 end_turn 在 Full Belly/Hangry 間切換。
#     Aura Wheel(783) 於 Full Belly 為 Electric、Hangry 為 Dark；只用既有 Action-local
#     move type override，不永久修改 RPG::Skill。
#  9. Zero to Hero：battle_start/entry 初始 Zero；第一次 switch_out 後 battle-local unlock，
#     再次 entry 進 Hero。Zero=70/72/53/62/100、Hero=160/97/106/87/100，Type Water。
# 10. 上述 Form/Identity Ability 皆沿用 Batch AD 的不可複製／不可改寫規則，且在本批
#     正式補入 Neutralizing Gas protected bridge，避免動態 Form Authority 被暫時清空。
#
# 【可調參數】
#  TEST_TROOP_ID=738、TEST_LEVEL=40、ZEN_THRESHOLD=50、SHIELDS_THRESHOLD=50、
#  SCHOOL_THRESHOLD=25、GULP_DAMAGE_DENOM=4。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫。開發測試：地圖按 F11，自動進 troop 738，跑三回合
#  Actual Scene_Battle，輸出 Pokemon_Ability_AJ_AutoTest_v2_5_35b.log 與
#  CG_AutoRegression_LATEST.log。
#
# 【F11 實際範例】
#  R1：Zen/Shields/Schooling 跨 HP 門檻；Stance->Blade；Gulp Missile 由 Dive 武裝；
#      Zero to Hero 用 Teleport 真實 switch_out 解鎖；Hunger end-turn -> Hangry。
#  R2：King's Shield -> Shield；Hangry Aura Wheel -> Dark 並觸發 Gulp Missile 反擊；
#      reserve Teleport 讓 Zero to Hero 真實再入場 -> Hero；Zen 回 Standard。
#  R3：Battle Bond 真實 KO -> ATK/SPA/SPE +1；Full Belly Aura Wheel -> Electric；Hero 保持。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAJ"] = "2.5.35a"

module ALBERT_CG
  module ABILITY_AJ_V2535
    VERSION = "2.5.35a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 738
    VK_F11 = 0x7A

    ABILITY_ZEN_MODE      = 161
    ABILITY_STANCE_CHANGE = 176
    ABILITY_SHIELDS_DOWN  = 197
    ABILITY_SCHOOLING     = 208
    ABILITY_BATTLE_BOND   = 210
    ABILITY_GULP_MISSILE  = 241
    ABILITY_HUNGER_SWITCH = 258
    ABILITY_ZERO_TO_HERO  = 278
    HANDLED_ABILITY_IDS = [161,176,197,208,210,241,258,278]

    MOVE_SURF = 57
    MOVE_DIVE = 291
    MOVE_KINGS_SHIELD = 588
    MOVE_AURA_WHEEL = 783
    GULP_DAMAGE_DENOM = 4

    PROFILE_ZEN_STANDARD = {:atk=>140,:def=>55,:spa=>30,:spd=>55,:spe=>95}
    PROFILE_ZEN          = {:atk=>30,:def=>105,:spa=>140,:spd=>105,:spe=>55}
    PROFILE_STANCE_SHIELD= {:atk=>50,:def=>140,:spa=>50,:spd=>140,:spe=>60}
    PROFILE_STANCE_BLADE = {:atk=>140,:def=>50,:spa=>140,:spd=>50,:spe=>60}
    PROFILE_MINIOR_METEOR= {:atk=>60,:def=>100,:spa=>60,:spd=>100,:spe=>60}
    PROFILE_MINIOR_CORE  = {:atk=>100,:def=>60,:spa=>100,:spd=>60,:spe=>120}
    PROFILE_WISHI_SOLO   = {:atk=>20,:def=>20,:spa=>25,:spd=>25,:spe=>40}
    PROFILE_WISHI_SCHOOL = {:atk=>140,:def=>130,:spa=>140,:spd=>135,:spe=>30}
    PROFILE_PALAFIN_ZERO = {:atk=>70,:def=>72,:spa=>53,:spd=>62,:spe=>100}
    PROFILE_PALAFIN_HERO = {:atk=>160,:def=>97,:spa=>106,:spd=>87,:spe=>100}

    TEST_ALLIES = [
      {:dex=>143,:level=>40,:ability=>ABILITY_STANCE_CHANGE,:moves=>[332,588,150]},
      {:dex=>65, :level=>40,:ability=>ABILITY_BATTLE_BOND,  :moves=>[150,150,55]},
      {:dex=>18, :level=>40,:ability=>ABILITY_HUNGER_SWITCH,:moves=>[150,783,783]},
    ]
    TEST_ENEMIES = [
      {:dex=>382,:level=>45,:ability=>ABILITY_SHIELDS_DOWN,:moves=>[150,150,150]},
      {:dex=>383,:level=>45,:ability=>ABILITY_SCHOOLING,   :moves=>[150,150,150]},
      {:dex=>384,:level=>45,:ability=>ABILITY_GULP_MISSILE,:moves=>[291,150,150]},
      {:dex=>92, :level=>45,:ability=>ABILITY_ZERO_TO_HERO,:moves=>[100,150,150]},
      {:dex=>197,:level=>45,:ability=>0,                   :moves=>[150,100,150]},
    ]

    ROUND_PLANS = [
      {:name=>"FORM_THRESHOLDS_STANCE_GULP_ZERO_OUT",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>332,:target=>3},
         {:kind=>:move,:move_id=>150,:target=>1},
         {:kind=>:move,:move_id=>150,:target=>1}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},
         1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>291,:target=>1},
         3=>{:kind=>:move,:move_id=>100,:target=>1}}},
      {:name=>"STANCE_SHIELD_HANGRY_GULP_ZERO_RETURN",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>0},
         {:kind=>:move,:move_id=>588,:target=>0},
         {:kind=>:move,:move_id=>150,:target=>1},
         {:kind=>:move,:move_id=>783,:target=>2}],
       :enemies=>{
         0=>{:kind=>:move,:move_id=>150,:target=>1},
         1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},
         4=>{:kind=>:move,:move_id=>100,:target=>1}}},
      {:name=>"BATTLE_BOND_FULL_BELLY_HERO_PERSIST",
       :allies=>[
         {:kind=>:move,:move_id=>150,:target=>1},
         {:kind=>:move,:move_id=>150,:target=>1},
         {:kind=>:move,:move_id=>55,:target=>0},
         {:kind=>:move,:move_id=>783,:target=>1}],
       :enemies=>{
         1=>{:kind=>:move,:move_id=>150,:target=>1},
         2=>{:kind=>:move,:move_id=>150,:target=>1},
         3=>{:kind=>:move,:move_id=>150,:target=>1}}},
    ]

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:M150","A1:M332","A2:M150","A3:M150","E0:M150","E1:M150","E2:M291","E3:M100"],
      2=>["A1:M588","A0:M150","A2:M150","A3:M783","E0:M150","E1:M150","E2:M150","E4:M100"],
      3=>["A0:M150","A1:M150","A2:M55","A3:M783","E1:M150","E2:M150","E3:M150"],
    }

    TEST_SPEEDS = {
      1=>[850,800,750,700, 550,500,450,400,0],
      2=>[850,800,750,700, 550,500,450,0,400],
      3=>[850,800,750,700, 100,500,450,400,0],
    }

    begin
      KEY_API=Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API=nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.active_battlers; (test_allies+all_enemies).select{|b|b!=nil&&!b.hidden&&b.hp.to_i>0}; rescue; []; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AJ_AutoTest_v2_5_35b.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.move_id(skill); return 0 if skill==nil; return ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i if defined?(ALBERT_CG::MOVE_EFFECT); 0; rescue; 0; end
    def self.raw_ability_id(b); return 0 if b==nil; return ALBERT_CG::ABILITY_AG_V2532.raw_ability_id(b).to_i if defined?(ALBERT_CG::ABILITY_AG_V2532); b.respond_to?(:cg_master_ability_id) ? b.cg_master_ability_id.to_i : 0; rescue; 0; end
    def self.ability_id(b); core ? core.ability_id(b).to_i : raw_ability_id(b); rescue; raw_ability_id(b); end
    def self.type_id(key); defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_id(key).to_i : 0; rescue; 0; end
    def self.form(b); b==nil ? nil : b.instance_variable_get(:@cg_v2535aj_form); end

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
        log("ABILITY_AJ_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect)
      end
      rec
    rescue
      nil
    end
    def self.formal_note(aid,battler,kind,data=nil); note_local(aid,battler,kind,data); true; rescue; false; end
    def self.records_for(aid,kind=nil); a=@records[aid.to_i]||[]; return a if kind==nil; a.select{|x|x[:kind].to_sym==kind.to_sym}; rescue; []; end

    def self.set_form_profile(holder,aid,new_form,profile,types,kind=:form_change)
      return false if holder==nil
      old=form(holder)
      if holder.respond_to?(:cg_v238_set_base_stat)
        profile.each{|k,v|holder.cg_v238_set_base_stat(k,v)}
      end
      holder.cg_v237_set_types(types) if types!=nil && holder.respond_to?(:cg_v237_set_types)
      holder.instance_variable_set(:@cg_v2535aj_form,new_form)
      formal_note(aid,holder,kind,{:before=>old,:after=>new_form,:types=>(holder.respond_to?(:cg_pokemon_types) ? holder.cg_pokemon_types.inspect : "")}) if old!=new_form || active?
      true
    rescue
      false
    end

    def self.update_zen(holder,ctx=nil)
      f=(holder.hp.to_i*2<=holder.maxhp.to_i) ? :zen : :standard
      return set_form_profile(holder,ABILITY_ZEN_MODE,f,f==:zen ? PROFILE_ZEN : PROFILE_ZEN_STANDARD,f==:zen ? [:fire,:psychic] : [:fire],:zen_mode)
    end
    def self.stance_entry(holder,ctx=nil); set_form_profile(holder,ABILITY_STANCE_CHANGE,:shield,PROFILE_STANCE_SHIELD,[:steel,:ghost],:stance_change); end
    def self.stance_before_action(holder,ctx)
      a=ctx==nil ? nil : ctx[:action]; return false if a==nil || !a.skill?
      s=a.skill; mid=move_id(s)
      if mid==MOVE_KINGS_SHIELD
        return set_form_profile(holder,ABILITY_STANCE_CHANGE,:shield,PROFILE_STANCE_SHIELD,[:steel,:ghost],:stance_change)
      end
      power=s.respond_to?(:cg_pokemon_power) ? s.cg_pokemon_power.to_i : 0
      return false if power<=0
      set_form_profile(holder,ABILITY_STANCE_CHANGE,:blade,PROFILE_STANCE_BLADE,[:steel,:ghost],:stance_change)
    end
    def self.update_shields(holder,ctx=nil)
      f=(holder.hp.to_i*2<=holder.maxhp.to_i) ? :core : :meteor
      set_form_profile(holder,ABILITY_SHIELDS_DOWN,f,f==:core ? PROFILE_MINIOR_CORE : PROFILE_MINIOR_METEOR,[:rock,:flying],:shields_down)
    end
    def self.update_schooling(holder,ctx=nil)
      # 正式等級 Authority 必須同時支援 Game_Actor 與 Game_Enemy。
      # Game_Enemy 沒有一般的 #level；本專案敵方等級由 cg_pokemon_level
      # 讀取 ENEMY_LEVEL_TABLE / <pokemon_level>，不能回退成 Lv.1。
      level = if holder.respond_to?(:cg_pokemon_level)
                holder.cg_pokemon_level.to_i
              elsif holder.respond_to?(:level)
                holder.level.to_i
              else
                1
              end
      school=(level>=20 && holder.hp.to_i*4>holder.maxhp.to_i)
      f=school ? :school : :solo
      set_form_profile(holder,ABILITY_SCHOOLING,f,school ? PROFILE_WISHI_SCHOOL : PROFILE_WISHI_SOLO,[:water],:schooling)
    end
    def self.apply_battle_bond(holder,ctx=nil)
      return false if holder==nil || holder.instance_variable_get(:@cg_v2535aj_battle_bond_used)==true
      holder.instance_variable_set(:@cg_v2535aj_battle_bond_used,true)
      before={:atk=>holder.cg_stat_stage(:atk).to_i,:spa=>holder.cg_stat_stage(:spa).to_i,:spe=>holder.cg_stat_stage(:spe).to_i}
      [:atk,:spa,:spe].each{|k|holder.cg_change_stat_stage(k,1) if holder.respond_to?(:cg_change_stat_stage)}
      after={:atk=>holder.cg_stat_stage(:atk).to_i,:spa=>holder.cg_stat_stage(:spa).to_i,:spe=>holder.cg_stat_stage(:spe).to_i}
      formal_note(ABILITY_BATTLE_BOND,holder,:battle_bond,{:before=>before.inspect,:after=>after.inspect,:move_id=>(ctx ? ctx[:move_id].to_i : 0)})
    end
    def self.reset_gulp_entry(holder,ctx=nil)
      holder.instance_variable_set(:@cg_v2535aj_gulp_mode,nil) if holder
      false
    end
    def self.arm_gulp(holder,ctx)
      a=ctx==nil ? nil : ctx[:action]; return false if a==nil || !a.skill?
      mid=move_id(a.skill); return false unless mid==MOVE_SURF || mid==MOVE_DIVE
      mode=(holder.hp.to_i*2>holder.maxhp.to_i) ? :gulping : :gorging
      holder.instance_variable_set(:@cg_v2535aj_gulp_mode,mode)
      formal_note(ABILITY_GULP_MISSILE,holder,:gulp_arm,{:mode=>mode,:move_id=>mid,:hp=>holder.hp.to_i,:maxhp=>holder.maxhp.to_i})
    end
    def self.apply_gulp_missile(holder,ctx)
      return false if holder==nil || ctx==nil || ctx[:damage_done].to_i<=0
      mode=holder.instance_variable_get(:@cg_v2535aj_gulp_mode); return false if mode==nil
      user=ctx[:user]; return false if user==nil || user.hp.to_i<=0
      loss=[[user.maxhp.to_i/GULP_DAMAGE_DENOM,1].max,user.hp.to_i].min
      before=user.hp.to_i; user.hp-=loss; user.hp_damage=loss if user.respond_to?(:hp_damage=)
      detail={:mode=>mode,:loss=>loss,:hp_before=>before,:hp_after=>user.hp.to_i,:move_id=>ctx[:move_id].to_i}
      if mode==:gulping && user.respond_to?(:cg_change_stat_stage)
        b=user.cg_stat_stage(:def).to_i; user.cg_change_stat_stage(:def,-1); detail[:def_before]=b; detail[:def_after]=user.cg_stat_stage(:def).to_i
      elsif mode==:gorging
        sid=defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS : 37
        user.add_state(sid); detail[:paralysis]=user.state?(sid)
      end
      holder.instance_variable_set(:@cg_v2535aj_gulp_mode,nil)
      formal_note(ABILITY_GULP_MISSILE,holder,:gulp_missile,detail)
    end
    def self.hunger_entry(holder,ctx=nil)
      old=form(holder); holder.instance_variable_set(:@cg_v2535aj_form,:full_belly)
      formal_note(ABILITY_HUNGER_SWITCH,holder,:hunger_switch,{:before=>old,:after=>:full_belly})
    end
    def self.hunger_end_turn(holder,ctx=nil)
      old=form(holder); newf=(old==:hangry ? :full_belly : :hangry); holder.instance_variable_set(:@cg_v2535aj_form,newf)
      formal_note(ABILITY_HUNGER_SWITCH,holder,:hunger_switch,{:before=>old,:after=>newf})
    end
    def self.hunger_before_action(holder,ctx)
      a=ctx==nil ? nil : ctx[:action]; return false if a==nil || !a.skill? || move_id(a.skill)!=MOVE_AURA_WHEEL
      key=(form(holder)==:hangry ? :dark : :electric); tid=type_id(key); return false if tid<=0
      a.skill.instance_variable_set(:@cg_v2522_type_override,tid)
      holder.instance_variable_set(:@cg_v2535aj_last_aura_type,key)
      formal_note(ABILITY_HUNGER_SWITCH,holder,:aura_wheel_type,{:form=>form(holder),:type=>key,:type_id=>tid})
    end
    def self.zero_entry(holder,ctx=nil)
      hero=holder.instance_variable_get(:@cg_v2535aj_zero_unlocked)==true
      set_form_profile(holder,ABILITY_ZERO_TO_HERO,hero ? :hero : :zero,hero ? PROFILE_PALAFIN_HERO : PROFILE_PALAFIN_ZERO,[:water],:zero_to_hero)
    end
    def self.zero_switch_out(holder,ctx=nil)
      holder.instance_variable_set(:@cg_v2535aj_zero_unlocked,true)
      formal_note(ABILITY_ZERO_TO_HERO,holder,:zero_to_hero_unlock,{:unlocked=>true})
    end

    def self.major_status_ids
      if defined?(ALBERT_CG::MOVE_EFFECT)
        [ALBERT_CG::MOVE_EFFECT::STATE_POISON,ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS,
         ALBERT_CG::MOVE_EFFECT::STATE_SLEEP,ALBERT_CG::MOVE_EFFECT::STATE_FREEZE,
         ALBERT_CG::MOVE_EFFECT::STATE_BURN,ALBERT_CG::MOVE_EFFECT::STATE_YAWN]
      else
        [31,37,39,44,43,51]
      end
    end
    def self.shields_blocks_state?(holder,state_id)
      return false if holder==nil || ability_id(holder)!=ABILITY_SHIELDS_DOWN || form(holder)!=:meteor
      major_status_ids.include?(state_id.to_i)
    rescue
      false
    end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_ZEN_MODE,:battle_start,self,:update_zen)
      core.register(ABILITY_ZEN_MODE,:entry,self,:update_zen)
      core.register(ABILITY_ZEN_MODE,:end_turn,self,:update_zen)
      core.register(ABILITY_STANCE_CHANGE,:entry,self,:stance_entry)
      core.register(ABILITY_STANCE_CHANGE,:before_action,self,:stance_before_action)
      core.register(ABILITY_SHIELDS_DOWN,:battle_start,self,:update_shields)
      core.register(ABILITY_SHIELDS_DOWN,:entry,self,:update_shields)
      core.register(ABILITY_SHIELDS_DOWN,:end_turn,self,:update_shields)
      core.register(ABILITY_SCHOOLING,:battle_start,self,:update_schooling)
      core.register(ABILITY_SCHOOLING,:entry,self,:update_schooling)
      core.register(ABILITY_SCHOOLING,:end_turn,self,:update_schooling)
      core.register(ABILITY_BATTLE_BOND,:after_ko,self,:apply_battle_bond)
      core.register(ABILITY_GULP_MISSILE,:entry,self,:reset_gulp_entry)
      core.register(ABILITY_GULP_MISSILE,:before_action,self,:arm_gulp)
      core.register(ABILITY_GULP_MISSILE,:after_damage,self,:apply_gulp_missile)
      core.register(ABILITY_HUNGER_SWITCH,:entry,self,:hunger_entry)
      core.register(ABILITY_HUNGER_SWITCH,:before_action,self,:hunger_before_action)
      core.register(ABILITY_HUNGER_SWITCH,:end_turn,self,:hunger_end_turn)
      core.register(ABILITY_ZERO_TO_HERO,:battle_start,self,:zero_entry)
      core.register(ABILITY_ZERO_TO_HERO,:entry,self,:zero_entry)
      core.register(ABILITY_ZERO_TO_HERO,:switch_out,self,:zero_switch_out)
      true
    end

    #--------------------------------------------------------------------------
    # Test harness
    #--------------------------------------------------------------------------
    def self.clear_runtime(b)
      return if b==nil
      b.instance_variable_set(:@cg_v2535aj_form,nil)
      b.instance_variable_set(:@cg_v2535aj_battle_bond_used,false)
      b.instance_variable_set(:@cg_v2535aj_gulp_mode,nil)
      b.instance_variable_set(:@cg_v2535aj_zero_unlocked,false)
      b.instance_variable_set(:@cg_v2535aj_last_aura_type,nil)
      b.instance_variable_set(:@cg_priority_test_speed_override_aj,nil)
      b.instance_variable_set(:@cg_v238_base_stat_override,nil)
      b.instance_variable_set(:@cg_v237_type_override,nil)
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
        h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); clear_runtime(h); h.instance_variable_set(:@cg_master_ability_id,ABILITY_ZEN_MODE)
      end
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1]]
      ms=[]; TEST_ENEMIES.each_with_index do |c,i|; configure_enemy(c); m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=(i>=4); ms.push(m); end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AJ v2.5.35b AutoRegression",ms)
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

    def self.begin_battle
      list=[]; list += $game_party.members if $game_party; list += $game_troop.members if $game_troop
      list.each{|b|clear_runtime(b) if b}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID] rescue nil
      h.instance_variable_set(:@cg_master_ability_id,ABILITY_ZEN_MODE) if h
      true
    rescue=>ex
      log("BEGIN_BATTLE_ERROR "+ex.class.to_s+":"+ex.message.to_s); false
    end

    def self.prepare_round_fixture
      a=test_allies; e=all_enemies; r=current_round
      if r==1
        @r1_initial={:zen=>form(a[0]),:stance=>form(a[1]),:shields=>form(e[0]),:school=>form(e[1]),:hunger=>form(a[3]),:zero=>form(e[3])}
        a[0].hp=[a[0].maxhp.to_i/2,1].max if a[0]
        e[0].hp=[e[0].maxhp.to_i/2,1].max if e[0]
        e[1].hp=[e[1].maxhp.to_i/4,1].max if e[1]
      elsif r==2
        a[0].hp=a[0].maxhp if a[0]
        @r2_a3_hp=a[3] ? a[3].hp.to_i : 0; @r2_a3_def=a[3] ? a[3].cg_stat_stage(:def).to_i : 0
      elsif r==3
        e[0].hp=1 if e[0]
        # E1 的 Schooling 門檻已在 Round 1 完成驗證。Round 3 僅把它當中性
        # deterministic dummy；不得讓 Round 1 故意留下的 25% HP／資源狀態
        # 污染第三回合的 action-order fixture。
        if e[1]
          e[1].hp=e[1].maxhp.to_i
          e[1].mp=e[1].maxmp.to_i if e[1].respond_to?(:mp=) && e[1].respond_to?(:maxmp)
          @r3_e1_ready=(!e[1].hidden && e[1].hp.to_i>0)
          log("ROUND3_NEUTRAL_DUMMY_RESET E1 hp="+e[1].hp.to_i.to_s+"/"+e[1].maxhp.to_i.to_s+" mp="+(e[1].respond_to?(:mp) ? e[1].mp.to_i.to_s : "n/a")+" hidden="+e[1].hidden.to_s)
        else
          @r3_e1_ready=false
        end
        @r3_bond_before={:atk=>(a[2] ? a[2].cg_stat_stage(:atk).to_i : 0),:spa=>(a[2] ? a[2].cg_stat_stage(:spa).to_i : 0),:spe=>(a[2] ? a[2].cg_stat_stage(:spe).to_i : 0)}
      end
    end
    def self.apply_test_speeds
      speeds=TEST_SPEEDS[current_round]||[]; list=test_allies+all_enemies
      list.each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_aj,speeds[i]) if b&&speeds[i]!=nil}
    end
    def self.prepare_round_actions
      @actual=[]; prepare_round_fixture; a=test_allies; plan=current_plan; apply_test_speeds
      plan[:allies].each_with_index do |c,i|
        next if a[i]==nil||a[i].hp.to_i<=0
        act=make_action(a[i],c)
        if a[i].respond_to?(:cg_round_actions); a[i].cg_round_actions.clear; a[i].cg_round_actions.push(act); end
        a[i].cg_assign_action(act) if a[i].respond_to?(:cg_assign_action); a[i].instance_variable_set(:@action,act) unless a[i].respond_to?(:cg_assign_action)
      end
      log("ROUND "+current_round.to_s+" BEGIN "+plan[:name].to_s)
    end

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil"))
      assert_true("Ability Batch AJ defines 8 handled IDs",HANDLED_ABILITY_IDS.uniq.size==8,"actual="+HANDLED_ABILITY_IDS.uniq.size.to_s)
      tid=($game_troop&&$game_troop.respond_to?(:troop)&&$game_troop.troop ? $game_troop.troop.id.to_i : 0); assert_true("Scene_Battle uses Ability AJ test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability AJ ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability AJ starts with 4 active enemies",all_enemies.select{|x|x&&!x.hidden}.size==4)
      assert_true("Ability AJ starts with hidden swap reserve",all_enemies[4]&&all_enemies[4].hidden)
    end
    def self.assert_execution
      exp=EXPECTED_EXECUTION_TOKENS[current_round]||[]; ok=(@actual==exp); @action_checks+=1 if ok; assert_true("Round"+current_round.to_s+" execution order matches deterministic plan",ok,"expected="+exp.inspect+" actual="+@actual.inspect)
    end
    def self.assert_round
      a=test_allies; e=all_enemies; r=current_round; assert_execution
      if r==1
        init=@r1_initial||{}
        ok=init[:zen]==:standard && init[:stance]==:shield && init[:shields]==:meteor && init[:school]==:school && init[:hunger]==:full_belly && init[:zero]==:zero
        @form_checks+=1 if ok; assert_true("Initial dynamic forms are canonical battle-start states",ok,"forms="+init.inspect)
        z=form(a[0])==:zen; @form_checks+=1 if z; assert_true("Zen Mode crosses <=50% into Zen at end-turn",z,"form="+form(a[0]).to_s)
        st=form(a[1])==:blade; @form_checks+=1 if st; assert_true("Stance Change damaging Move enters Blade",st,"form="+form(a[1]).to_s)
        sh=form(e[0])==:core; @form_checks+=1 if sh; assert_true("Shields Down crosses <=50% into Core",sh,"form="+form(e[0]).to_s)
        sc=form(e[1])==:solo; @form_checks+=1 if sc; assert_true("Schooling crosses <=25% into Solo",sc,"form="+form(e[1]).to_s)
        hu=form(a[3])==:hangry; @form_checks+=1 if hu; assert_true("Hunger Switch toggles to Hangry at end-turn",hu,"form="+form(a[3]).to_s)
        ga=e[2]&&e[2].instance_variable_get(:@cg_v2535aj_gulp_mode)==:gulping&&!records_for(ABILITY_GULP_MISSILE,:gulp_arm).empty?; @reaction_checks+=1 if ga; assert_true("Gulp Missile arms Gulping after real Dive above half HP",ga,"mode="+(e[2] ? e[2].instance_variable_get(:@cg_v2535aj_gulp_mode).to_s : "nil"))
        zo=e[3]&&e[3].hidden&&e[4]&&!e[4].hidden&&e[3].instance_variable_get(:@cg_v2535aj_zero_unlocked)==true; @lifecycle_checks+=1 if zo; assert_true("Zero to Hero unlocks on real Teleport switch-out",zo,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" unlocked="+(e[3] ? e[3].instance_variable_get(:@cg_v2535aj_zero_unlocked).to_s : "nil"))
      elsif r==2
        z=form(a[0])==:standard; @form_checks+=1 if z; assert_true("Zen Mode returns Standard above half HP",z,"form="+form(a[0]).to_s)
        st=form(a[1])==:shield; @form_checks+=1 if st; assert_true("King's Shield returns Stance Change to Shield",st,"form="+form(a[1]).to_s)
        dark=!records_for(ABILITY_HUNGER_SWITCH,:aura_wheel_type).select{|x|x[:type]==:dark}.empty?; @form_checks+=1 if dark; assert_true("Hangry Aura Wheel resolves as Dark",dark)
        missile=records_for(ABILITY_GULP_MISSILE,:gulp_missile)[-1]; rok=missile!=nil&&a[3]&&a[3].hp.to_i<@r2_a3_hp&&a[3].cg_stat_stage(:def).to_i==@r2_a3_def-1&&e[2].instance_variable_get(:@cg_v2535aj_gulp_mode)==nil
        @reaction_checks+=1 if rok; assert_true("Gulping missile retaliates 1/4 HP and DEF -1 then disarms",rok,"A3_hp="+@r2_a3_hp.to_s+"->"+(a[3] ? a[3].hp.to_i.to_s : "nil")+" def="+@r2_a3_def.to_s+"->"+(a[3] ? a[3].cg_stat_stage(:def).to_i.to_s : "nil"))
        hero=e[3]&&!e[3].hidden&&e[4]&&e[4].hidden&&form(e[3])==:hero; @lifecycle_checks+=1 if hero; @form_checks+=1 if hero; assert_true("Zero to Hero re-entry applies Hero form",hero,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" form="+form(e[3]).to_s)
        full=form(a[3])==:full_belly; @form_checks+=1 if full; assert_true("Hunger Switch toggles back Full Belly at end-turn",full,"form="+form(a[3]).to_s)
      elsif r==3
        assert_true("Round3 neutral Schooling dummy is active after fixture reset",@r3_e1_ready==true,"ready="+@r3_e1_ready.to_s+" hp="+(e[1] ? e[1].hp.to_i.to_s : "nil")+" hidden="+(e[1] ? e[1].hidden.to_s : "nil"))
        b=records_for(ABILITY_BATTLE_BOND,:battle_bond)[-1]
        bond=a[2]&&b&&a[2].cg_stat_stage(:atk).to_i==@r3_bond_before[:atk]+1&&a[2].cg_stat_stage(:spa).to_i==@r3_bond_before[:spa]+1&&a[2].cg_stat_stage(:spe).to_i==@r3_bond_before[:spe]+1
        @reaction_checks+=1 if bond; assert_true("Battle Bond first real KO grants ATK/SPA/SPE +1",bond,"before="+@r3_bond_before.inspect+" after={:atk=>"+(a[2] ? a[2].cg_stat_stage(:atk).to_i.to_s : "nil")+",:spa=>"+(a[2] ? a[2].cg_stat_stage(:spa).to_i.to_s : "nil")+",:spe=>"+(a[2] ? a[2].cg_stat_stage(:spe).to_i.to_s : "nil")+"}")
        elec=!records_for(ABILITY_HUNGER_SWITCH,:aura_wheel_type).select{|x|x[:type]==:electric}.empty?; @form_checks+=1 if elec; assert_true("Full Belly Aura Wheel resolves as Electric",elec)
        hero=e[3]&&!e[3].hidden&&form(e[3])==:hero&&e[3].cg_v238_base_stat(:atk).to_i==160; @form_checks+=1 if hero; assert_true("Zero to Hero Hero profile persists after re-entry",hero,"form="+form(e[3]).to_s+" atk="+(e[3] ? e[3].cg_v238_base_stat(:atk).to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end

    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_aj,nil) if b}; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|aid|ok=@ability_trigger_counts[aid].to_i>0; assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)}
      log("------------------------------------------------------------"); result=@failures.empty? ? "PASS" : "FAIL"; log("RESULT="+result)
      passed=0; HANDLED_ABILITY_IDS.each{|x|passed+=1 if @ability_trigger_counts[x].to_i>0}
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_aj="+passed.to_s+"/8 form_checks="+@form_checks.to_s+" reaction_checks="+@reaction_checks.to_s+" action_checks="+@action_checks.to_s+" lifecycle_checks="+@lifecycle_checks.to_s+" pending=85")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @form_checks=0; @reaction_checks=0; @action_checks=0; @lifecycle_checks=0; @r1_initial={}; @r2_a3_hp=0; @r2_a3_def=0; @r3_bond_before={:atk=>0,:spa=>0,:spe=>0}; @r3_e1_ready=false
    end
    def self.reset_log
      h="CG POKEMON ABILITY AJ DYNAMIC FORM + REACTIVE IDENTITY AUTO REGRESSION v2.5.35b\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; form thresholds + stance + gulp + hunger + zero hero + battle bond\r\n"+
        "BASELINE=v2.5.34a Ability Batch AI RPG Maker VX real-machine PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AI_PASS=280 BATCH_AJ=8 PENDING=85\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue; end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AJ_v2.5.35b") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

ALBERT_CG::ABILITY_AJ_V2535.register_handlers if defined?(ALBERT_CG::ABILITY_AJ_V2535)

#==============================================================================
# ■ Formal Shields Down major-status guard
#==============================================================================
class Game_Battler
  alias cg_v2535aj_add_state add_state
  def add_state(state_id)
    if defined?(ALBERT_CG::ABILITY_AJ_V2535) && ALBERT_CG::ABILITY_AJ_V2535.shields_blocks_state?(self,state_id)
      ALBERT_CG::ABILITY_AJ_V2535.formal_note(ALBERT_CG::ABILITY_AJ_V2535::ABILITY_SHIELDS_DOWN,self,:shields_down_status_guard,{:state_id=>state_id.to_i})
      return
    end
    cg_v2535aj_add_state(state_id)
  end
end

#==============================================================================
# ■ Formal Neutralizing Gas protected-form bridge
#==============================================================================
if defined?(ALBERT_CG::ABILITY_AG_V2532)
  module ALBERT_CG; module ABILITY_AG_V2532; class << self
    alias cg_v2535aj_gas_suppresses gas_suppresses?
    def gas_suppresses?(battler,raw_aid=nil)
      aid=raw_aid==nil ? raw_ability_id(battler) : raw_aid.to_i
      return false if defined?(ALBERT_CG::ABILITY_AJ_V2535) && ALBERT_CG::ABILITY_AJ_V2535::HANDLED_ABILITY_IDS.include?(aid)
      cg_v2535aj_gas_suppresses(battler,raw_aid)
    end
  end; end; end
end

#==============================================================================
# ■ Scene / deterministic F11 harness
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2535aj_start start
  def start
    ALBERT_CG::ABILITY_AJ_V2535.begin_battle if defined?(ALBERT_CG::ABILITY_AJ_V2535)&&ALBERT_CG::ABILITY_AJ_V2535.active?
    cg_v2535aj_start
  end
  alias cg_v2535aj_execute_action execute_action
  def execute_action
    ALBERT_CG::ABILITY_AJ_V2535.record_execution(@active_battler) if defined?(ALBERT_CG::ABILITY_AJ_V2535)&&ALBERT_CG::ABILITY_AJ_V2535.active?
    cg_v2535aj_execute_action
  end
  alias cg_v2535aj_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AJ_V2535)&&ALBERT_CG::ABILITY_AJ_V2535.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_AJ_V2535.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_AJ_V2535.finish_round_assertions; end
    end
    cg_v2535aj_turn_end
  end
  alias cg_v2535aj_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AJ_V2535)&&ALBERT_CG::ABILITY_AJ_V2535.active?; return cg_v2535aj_start_party_command; end
    cg_v2535aj_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_AJ_V2535.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AJ_V2535.finished?; ALBERT_CG::ABILITY_AJ_V2535.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_AJ_V2535.prepare_round_actions; start_main
  end
end

class Game_Battler
  alias cg_v2535aj_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AJ_V2535)&&ALBERT_CG::ABILITY_AJ_V2535.active?; v=@cg_priority_test_speed_override_aj; return v.to_i if v!=nil; end
    cg_v2535aj_priority_base_speed
  rescue; cg_v2535aj_priority_base_speed; end
end

class Game_Enemy < Game_Battler
  alias cg_v2535aj_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AJ_V2535)&&ALBERT_CG::ABILITY_AJ_V2535.active?; a=ALBERT_CG::ABILITY_AJ_V2535.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end; end
    cg_v2535aj_enemy_make_action
  end
end

module ALBERT_CG; class << self
  alias cg_v2535aj_bootstrap_demo_party bootstrap_demo_party
  def bootstrap_demo_party
    r=cg_v2535aj_bootstrap_demo_party
    if defined?(ALBERT_CG::ABILITY_AJ_V2535)&&ALBERT_CG::ABILITY_AJ_V2535.active?
      ALBERT_CG::ABILITY_AJ_V2535::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AJ_V2535.configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if h; h.change_level(ALBERT_CG::ABILITY_AJ_V2535::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); ALBERT_CG::ABILITY_AJ_V2535.clear_runtime(h); h.instance_variable_set(:@cg_master_ability_id,ALBERT_CG::ABILITY_AJ_V2535::ABILITY_ZEN_MODE); end
    end
    r
  end
end; end

# Newest F11 only.
if defined?(ALBERT_CG::ABILITY_AI_V2534)
  module ALBERT_CG; module ABILITY_AI_V2534; def self.f11_trigger?; false; end; end; end
end
class Scene_Map < Scene_Base
  alias cg_v2535aj_scene_map_update update
  def update
    cg_v2535aj_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_AJ_V2535); ALBERT_CG::ABILITY_AJ_V2535.start_auto_test if ALBERT_CG::ABILITY_AJ_V2535.f11_trigger?
  end
end
