# RMVX_SCRIPT_INDEX: 257
# RMVX_SCRIPT_ID: 253201001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AG v2.5.32a
# RMVX_SOURCE_SHA256: fc4401f5bcc52cffd6330b84d434c0a4ee5f424bab8751179997119587a77e26

#==============================================================================
# ■ CG Pokemon Ability Batch AG v2.5.32a
#    Rule Suppression / Ability Bypass Authority + Regression Fix
#------------------------------------------------------------------------------
# 【用途】
#  v2.5.32 實機 LOG 將 11 個 FAIL 收斂為 Unaware 正式接線 1 類與 fixture lifecycle/priority 3 類。
#  v2.5.32a 只修 AG index 257，不修改已封版 scripts 0..256。
#  在 v2.5.31a Ability Batch AF RPG Maker VX 實機 PASS 基線之上，正式加入八個
#  「規則抑制／防禦 Ability bypass」型 Ability，並建立之後高階 Ability 可共用的
#  Weather Suppression、Target Ability Bypass、Global Ability Suppression 權威。
#
# 【本批 Ability】
#   13 Cloud Nine / 無關天氣
#   76 Air Lock / 氣閘
#  104 Mold Breaker / 破格
#  109 Unaware / 純樸
#  163 Turboblaze / 渦輪火焰
#  164 Teravolt / 兆級電壓
#  255 Gorilla Tactics / 一猩一意
#  256 Neutralizing Gas / 化學變化氣體
#
# 【機制規則】
#  1. Cloud Nine / Air Lock 不刪除 Field weather，也不停止 weather_turns 倒數；只在
#     active holder 存在時令天氣「效果」失效。Weather 本體仍保留，因此 holder 離場後
#     當下即可恢復效果，避免建立第二套 weather state。
#  2. Weather suppression 會覆蓋 Field damage modifier、weather residual、Weather
#     Ability end-turn、weather-dependent stat / accuracy 查詢；Field weather duration
#     仍由既有 FIELD_V233 唯一 Authority 正常倒數。
#  3. Mold Breaker / Turboblaze / Teravolt 共用 Target Ability Bypass context。只有目前
#     正在承受該 Move 的 opposing target，其有效 Ability 在該次 hit resolution 中視為 0；
#     不會把 target 永久改成無 Ability，也不會抑制場上第三者 Ability。
#  4. Unaware 只在 damage stat resolution 暫時忽略對手相關 Stat Stage：
#     target 持有 Unaware -> 忽略 attacker ATK/SPA stage；user 持有 Unaware ->
#     忽略 target DEF/SPD stage。完成該次計算後立即還原。
#  5. Gorilla Tactics 透過既有 :stat_query 將 ATK x1.5；進場後第一次實際 Move 會鎖定
#     move_id，之後使用不同 Move 時在 Tankentai Action 前攔截。switch-out 會清鎖。
#  6. Neutralizing Gas 不改寫任何 battler 的永久／battle override Ability。Ability Core
#     最外層動態判斷 active Gas holder：除 Gas holder 自身外，其他 active battler 的
#     ability_id 暫時回 0；holder 離場／倒下後立即恢復。未來不可抑制的 form Ability
#     由其正式 Batch 再加入 exemption，不在本批預先替未實作規則猜答案。
#  7. Neutralizing Gas 會連帶抑制 Cloud Nine / Air Lock、Gorilla Tactics、Mold Breaker
#     等本批 Ability；因此「Gas 進場 -> rain 恢復效果；Gas 離場 -> Air Lock 恢復抑制」
#     可由同一個三回合 F11 fixture 驗證。
#  8. 本頁只新增 index 257；sealed v2.5.31a scripts 0..256 必須 byte-exact 不變。
#
# 【可調參數】
#  TEST_TROOP_ID=735、TEST_LEVEL=40、ROUND_PLANS、TEST_SPEEDS。
#  GORILLA_ATK_PERCENT=150。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，自動進 troop 735，跑三回合並輸出
#  Pokemon_Ability_AG_AutoTest_v2_5_32a.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：Rain 已存在，Cloud Nine + Air Lock 同時 active，Water damage weather percent
#          必須維持 100；Gorilla Tactics ATK=base*150%，第一個 Aerial Ace 鎖定；
#          Unaware attacker 對 +6 DEF target 時忽略該 DEF stage。
#  Round2：Gorilla Tactics 嘗試改用 Water Gun，在動畫前被鎖定規則取消；Air Lock
#          Teleport 換入 Neutralizing Gas，Cloud Nine 被 Gas 抑制，因此既有 Rain
#          重新生效，Water damage weather percent 回到 150。
#  Round3：Neutralizing Gas 依正式 Teleport -6 priority 在回合最後離場，Air Lock 回場。
#  Round4：Gas 已離場後，Mold Breaker / Turboblaze / Teravolt 分別以 Water Gun
#          攻擊 Water Absorb target，三次都必須 bypass target Ability 並造成真實傷害。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAG"] = "2.5.32a"

module ALBERT_CG
  module ABILITY_AG_V2532
    VERSION = "2.5.32a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 735
    VK_F11 = 0x7A

    ABILITY_CLOUD_NINE       = 13
    ABILITY_AIR_LOCK         = 76
    ABILITY_MOLD_BREAKER     = 104
    ABILITY_UNAWARE          = 109
    ABILITY_TURBOBLAZE       = 163
    ABILITY_TERAVOLT         = 164
    ABILITY_GORILLA_TACTICS  = 255
    ABILITY_NEUTRALIZING_GAS = 256

    ABILITY_WATER_ABSORB = 11
    BYPASS_IDS = [ABILITY_MOLD_BREAKER,ABILITY_TURBOBLAZE,ABILITY_TERAVOLT]
    WEATHER_SUPPRESS_IDS = [ABILITY_CLOUD_NINE,ABILITY_AIR_LOCK]
    HANDLED_ABILITY_IDS = [13,76,104,109,163,164,255,256]
    GORILLA_ATK_PERCENT = 150

    TEST_ALLIES = [
      {:dex=>143,:level=>40,:ability=>ABILITY_GORILLA_TACTICS,:moves=>[332,55,150,150]},
      {:dex=>94, :level=>40,:ability=>ABILITY_UNAWARE,        :moves=>[332,150,150,150]},
      {:dex=>128,:level=>40,:ability=>ABILITY_CLOUD_NINE,     :moves=>[150,150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>197,:level=>45,:ability=>ABILITY_AIR_LOCK,       :moves=>[150,100,150,150]},
      {:dex=>1,  :level=>45,:ability=>ABILITY_MOLD_BREAKER,   :moves=>[150,150,55,150]},
      {:dex=>110,:level=>45,:ability=>ABILITY_TURBOBLAZE,     :moves=>[150,150,55,150]},
      {:dex=>92, :level=>45,:ability=>ABILITY_TERAVOLT,       :moves=>[150,150,55,150]},
      {:dex=>65, :level=>45,:ability=>ABILITY_NEUTRALIZING_GAS,:moves=>[100,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"WEATHER_UNAWARE_GORILLA_LOCK_ARM",
        :allies=>[
          {:kind=>:move,:move_id=>55,:target=>2},
          {:kind=>:move,:move_id=>332,:target=>2},
          {:kind=>:move,:move_id=>332,:target=>0},
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
        :name=>"GORILLA_LOCK_NEUTRALIZING_GAS",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>55,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>100,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"GAS_EXIT_AIR_LOCK_RESTORE",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:guard},
          {:kind=>:guard},
          {:kind=>:guard},
        ],
        :enemies=>{
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>100,:target=>1},
        }
      },
      {
        :name=>"TARGET_ABILITY_BYPASS",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:guard},
          {:kind=>:guard},
          {:kind=>:guard},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>55,:target=>1},
          2=>{:kind=>:move,:move_id=>55,:target=>2},
          3=>{:kind=>:move,:move_id=>55,:target=>3},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[500,480,460,440, 420,400,380,360,0],
      :r2=>[460,500,440,420, 480,400,380,360,0],
      :r3=>[500,480,460,440, 0,420,400,380,360],
      :r4=>[500,480,460,440, 420,400,380,360,0],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:M55","A1:M332","A2:M332","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
      2=>["A0:Guard","A1:GLOCK","A2:M150","A3:M150","E1:M150","E2:M150","E3:M150","E0:M100"],
      3=>["A0:Guard","A1:Guard","A2:Guard","A3:Guard","E1:M150","E2:M150","E3:M150","E4:M100"],
      4=>["A0:Guard","A1:Guard","A2:Guard","A3:Guard","E0:M150","E1:M55","E2:M55","E3:M55"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.field; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233 : nil; end
    def self.weather; defined?(ALBERT_CG::ABILITY_WEATHER_V252) ? ALBERT_CG::ABILITY_WEATHER_V252 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.active?; @active == true; end
    def self.current_round; @round_index.to_i + 1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i >= ROUND_PLANS.size; end
    def self.test_allies; $game_party == nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop == nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AG_AutoTest_v2_5_32a.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API != nil && (KEY_API.call(code) & 0x8000) != 0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d && @f11_down != true; @f11_down=d; t; rescue; false; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT) && skill != nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.same_side?(a,b); a!=nil && b!=nil && a.respond_to?(:actor?) && b.respond_to?(:actor?) && a.actor? == b.actor?; rescue; false; end
    def self.opposing?(a,b); a!=nil && b!=nil && !same_side?(a,b); rescue; false; end

    def self.raw_ability_id(b)
      return 0 if b == nil
      if core && core.respond_to?(:cg_v2532ag_raw_ability_id)
        return core.cg_v2532ag_raw_ability_id(b).to_i
      end
      return b.respond_to?(:cg_master_ability_id) ? b.cg_master_ability_id.to_i : 0
    rescue
      return 0
    end

    def self.ability_id(b)
      return core == nil || b == nil ? 0 : core.ability_id(b).to_i
    rescue
      return 0
    end

    def self.active_battlers
      return core ? core.active_battlers : []
    rescue
      return []
    end

    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else
        text=label.to_s+(detail==nil ? "" : " "+detail.to_s)
        @failures.push(text)
        log("ASSERT FAIL "+text)
      end
      condition
    end

    def self.note_local(aid,battler,kind,data=nil)
      return true unless active?
      @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1
      rec={:ability=>aid.to_i,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill,:action].include?(k)}
      @records[aid.to_i]=[] if @records[aid.to_i]==nil
      @records[aid.to_i].push(rec)
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
      log("ABILITY_AG_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
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
      a=@records[aid.to_i]||[]
      return a if kind==nil
      a.select{|x|x[:kind].to_sym==kind.to_sym}
    rescue
      []
    end

    #--------------------------------------------------------------------------
    # Formal: Neutralizing Gas / effective Ability authority
    #--------------------------------------------------------------------------
    def self.neutralizing_gas_holder
      active_battlers.each do |b|
        next if b==nil || b.hidden || b.hp.to_i<=0
        return b if raw_ability_id(b)==ABILITY_NEUTRALIZING_GAS
      end
      return nil
    rescue
      return nil
    end

    def self.gas_suppresses?(battler,raw_aid=nil)
      return false if battler==nil
      aid=raw_aid==nil ? raw_ability_id(battler) : raw_aid.to_i
      return false if aid<=0 || aid==ABILITY_NEUTRALIZING_GAS
      holder=neutralizing_gas_holder
      return holder!=nil && holder!=battler
    rescue
      return false
    end

    def self.apply_neutralizing_gas_entry(holder,ctx=nil)
      note_local(ABILITY_NEUTRALIZING_GAS,holder,:neutralizing_gas_entry,
        {:active_count=>active_battlers.size})
      true
    rescue
      false
    end

    #--------------------------------------------------------------------------
    # Formal: target-only Ability bypass
    #--------------------------------------------------------------------------
    def self.bypass_attacker_ability(user)
      aid=ability_id(user)
      return BYPASS_IDS.include?(aid) ? aid : 0
    rescue
      return 0
    end

    def self.begin_target_bypass(user,target,skill=nil)
      aid=bypass_attacker_ability(user)
      return false if aid<=0 || target==nil || !opposing?(user,target)
      target_raw=raw_ability_id(target)
      return false if target_raw<=0
      @bypass_user=user
      @bypass_target=target
      @bypass_ability_id=aid
      @bypass_move_id=move_id(skill)
      formal_note(aid,user,:target_ability_bypass,
        {:target_index=>(target.respond_to?(:index) ? target.index.to_i : -1),
         :target_ability=>target_raw,:move_id=>@bypass_move_id})
      return true
    rescue
      return false
    end

    def self.end_target_bypass
      @bypass_user=nil; @bypass_target=nil; @bypass_ability_id=0; @bypass_move_id=0
      true
    end

    def self.bypass_target?(battler)
      return false if battler==nil || @bypass_target==nil || @bypass_user==nil
      return false unless battler.equal?(@bypass_target)
      return false unless opposing?(@bypass_user,battler)
      aid=ability_id_without_bypass(@bypass_user)
      return BYPASS_IDS.include?(aid)
    rescue
      return false
    end

    def self.ability_id_without_bypass(battler)
      aid=raw_ability_id(battler)
      return 0 if gas_suppresses?(battler,aid)
      return aid
    rescue
      return 0
    end

    #--------------------------------------------------------------------------
    # Formal: Weather suppression
    #--------------------------------------------------------------------------
    def self.weather_suppressors
      result=[]
      active_battlers.each do |b|
        next if b==nil || b.hidden || b.hp.to_i<=0
        # Global weather suppression must remain independent of target-only Mold Breaker context.
        aid=ability_id_without_bypass(b)
        result.push([b,aid]) if WEATHER_SUPPRESS_IDS.include?(aid)
      end
      result
    rescue
      []
    end

    def self.weather_suppressed?
      return !weather_suppressors.empty?
    rescue
      false
    end

    def self.apply_weather_suppressor(holder,ctx=nil)
      st=field && field.respond_to?(:state) ? field.state : nil
      return false if st==nil || st.weather_turns.to_i<=0 || st.weather==nil
      note_local(raw_ability_id(holder),holder,:weather_suppression,{:weather=>st.weather})
      true
    rescue
      false
    end

    def self.with_weather_effects_disabled
      return yield unless field && field.respond_to?(:state)
      st=field.state
      return yield if st==nil || st.weather_turns.to_i<=0 || !weather_suppressed?
      old_turns=st.weather_turns.to_i
      st.weather_turns=0
      begin
        return yield
      ensure
        st.weather_turns=old_turns
      end
    end

    #--------------------------------------------------------------------------
    # Formal: Unaware stage mask
    #--------------------------------------------------------------------------
    def self.stage_keys_for_class(damage_class,role)
      if role==:attack
        return [:atk] if damage_class==:physical
        return [:spa] if damage_class==:special
        return [:atk,:spa] if damage_class==:mixed
      else
        return [:def] if damage_class==:physical
        return [:spd] if damage_class==:special
        return [:def,:spd] if damage_class==:mixed
      end
      []
    end

    def self.zero_stages(battler,keys,saved)
      return false if battler==nil || !battler.respond_to?(:cg_stat_stage)
      changed=false
      battler.send(:cg_prepare_stat_stages) if battler.respond_to?(:cg_prepare_stat_stages,true)
      table=battler.instance_variable_get(:@cg_stat_stages)
      return false if table==nil
      keys.each do |key|
        value=table[key].to_i
        saved.push([battler,key,value])
        if value!=0
          table[key]=0
          changed=true
        end
      end
      changed
    rescue
      false
    end

    def self.restore_stages(saved)
      saved.reverse_each do |row|
        b=row[0]; key=row[1]; value=row[2]
        table=b.instance_variable_get(:@cg_stat_stages) rescue nil
        table[key]=value if table!=nil
      end
      true
    rescue
      false
    end

    def self.with_unaware_mask(user,target,damage_class)
      saved=[]; noted=[]
      target_aid=ability_id(target)
      user_aid=ability_id(user)
      if target_aid==ABILITY_UNAWARE
        keys=stage_keys_for_class(damage_class,:attack)
        if zero_stages(user,keys,saved)
          noted.push([target,keys,:ignore_attacker_stages])
        end
      end
      if user_aid==ABILITY_UNAWARE
        keys=stage_keys_for_class(damage_class,:defense)
        if zero_stages(target,keys,saved)
          noted.push([user,keys,:ignore_target_stages])
        end
      end
      noted.each do |row|
        formal_note(ABILITY_UNAWARE,row[0],:unaware_stage_ignore,
          {:mode=>row[2],:stats=>row[1].join("+")})
      end
      begin
        return yield
      ensure
        restore_stages(saved)
      end
    end

    #--------------------------------------------------------------------------
    # Formal: Gorilla Tactics
    #--------------------------------------------------------------------------
    def self.apply_gorilla_stat(holder,ctx)
      return false if holder==nil || ctx==nil || ctx[:stat].to_sym!=:atk
      before=ctx[:value].to_i
      after=[before*GORILLA_ATK_PERCENT/100,1].max
      ctx[:value]=after
      note_local(ABILITY_GORILLA_TACTICS,holder,:gorilla_atk,
        {:before=>before,:after=>after})
      true
    rescue
      false
    end

    def self.gorilla_lock_id(b)
      return b==nil ? 0 : b.instance_variable_get(:@cg_v2532ag_gorilla_move_id).to_i
    rescue
      0
    end

    def self.clear_gorilla_lock(b)
      b.instance_variable_set(:@cg_v2532ag_gorilla_move_id,0) if b
      true
    rescue
      false
    end

    def self.gorilla_action_intercept(user)
      return false if user==nil || ability_id(user)!=ABILITY_GORILLA_TACTICS
      action=user.action rescue nil
      return false if action==nil || !action.skill?
      skill=$data_skills[action.skill_id] rescue nil
      mid=move_id(skill)
      return false if mid<=0
      locked=gorilla_lock_id(user)
      if locked<=0
        user.instance_variable_set(:@cg_v2532ag_gorilla_move_id,mid)
        formal_note(ABILITY_GORILLA_TACTICS,user,:gorilla_lock_arm,{:move_id=>mid})
        return false
      end
      return false if locked==mid
      formal_note(ABILITY_GORILLA_TACTICS,user,:gorilla_lock_block,
        {:locked_move_id=>locked,:attempted_move_id=>mid})
      return true
    rescue
      false
    end

    def self.finish_skipped_action(user)
      return if user==nil
      user.active=false if user.respond_to?(:active=)
      user.play=0 if user.respond_to?(:play=)
    rescue
    end

    def self.register_handlers
      return false if core==nil
      list=core::TRIGGERS
      list.push(:stat_query) unless list.include?(:stat_query)
      core.register(ABILITY_CLOUD_NINE,:entry,self,:apply_weather_suppressor)
      core.register(ABILITY_CLOUD_NINE,:weather_changed,self,:apply_weather_suppressor)
      core.register(ABILITY_AIR_LOCK,:entry,self,:apply_weather_suppressor)
      core.register(ABILITY_AIR_LOCK,:weather_changed,self,:apply_weather_suppressor)
      core.register(ABILITY_GORILLA_TACTICS,:stat_query,self,:apply_gorilla_stat)
      core.register(ABILITY_NEUTRALIZING_GAS,:entry,self,:apply_neutralizing_gas_entry)
      return true
    rescue
      false
    end

    #--------------------------------------------------------------------------
    # Fixture helpers
    #--------------------------------------------------------------------------
    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg)
      a.recover_all if a.respond_to?(:recover_all)
      a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages)
      a.cg_v237_clear_identity if a.respond_to?(:cg_v237_clear_identity)
      a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime)
      clear_gorilla_lock(a)
    end

    def self.configure_enemy(cfg)
      master.configure_enemy_data(cfg)
    end

    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}
      ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each{|c|configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if h
        h.change_level(TEST_LEVEL,false); h.recover_all
        h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages)
        h.cg_v237_clear_identity if h.respond_to?(:cg_v237_clear_identity)
        h.instance_variable_set(:@cg_master_ability_id,0)
        clear_gorilla_lock(h)
      end
    end

    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2]]
      ms=[]
      TEST_ENEMIES.each_with_index do |c,i|
        configure_enemy(c)
        m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i])
        m.hidden=(i>=4); ms.push(m)
      end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AG v2.5.32a AutoRegression",ms)
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
      return nil unless active? && e && !e.hidden && e.hp.to_i>0
      c=current_plan[:enemies][e.index]
      c==nil ? nil : make_action(e,c)
    end

    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||[]
      (test_allies+all_enemies).each_with_index do |b,i|
        b.instance_variable_set(:@cg_priority_test_speed_override_ag,vals[i]) if b
      end
    end

    def self.set_effective_ability(b,aid)
      return false if b==nil
      if b.respond_to?(:cg_v237_set_ability)
        b.cg_v237_set_ability(aid.to_i)
      else
        b.instance_variable_set(:@cg_v237_ability_override,aid.to_i)
        b.instance_variable_set(:@cg_v237_ability_suppressed,false)
      end
      return raw_ability_id(b)==aid.to_i || ability_id(b)==aid.to_i
    rescue
      false
    end

    def self.with_temp_master_ability(b,aid)
      return yield if b==nil
      old=b.instance_variable_get(:@cg_master_ability_id)
      old_override=b.instance_variable_get(:@cg_v237_ability_override)
      old_supp=b.instance_variable_get(:@cg_v237_ability_suppressed)
      b.instance_variable_set(:@cg_master_ability_id,aid.to_i)
      b.instance_variable_set(:@cg_v237_ability_override,nil)
      b.instance_variable_set(:@cg_v237_ability_suppressed,false)
      begin
        return yield
      ensure
        b.instance_variable_set(:@cg_master_ability_id,old)
        b.instance_variable_set(:@cg_v237_ability_override,old_override)
        b.instance_variable_set(:@cg_v237_ability_suppressed,old_supp)
      end
    end

    def self.water_skill
      sid=master.skill_id_for_move(55)
      return $data_skills[sid]
    rescue
      nil
    end

    def self.water_weather_percent(user,target)
      sk=water_skill
      return 0 if sk==nil || field==nil
      tid=sk.respond_to?(:cg_pokemon_type_id) ? sk.cg_pokemon_type_id.to_i : 0
      klass=sk.respond_to?(:cg_pokemon_damage_class) ? sk.cg_pokemon_damage_class : :special
      field.damage_percent(user,target,sk,tid,klass,55).to_i
    rescue
      0
    end

    def self.prepare_round_preconditions
      a=test_allies; e=all_enemies
      if current_round==1
        if field && field.respond_to?(:state)
          field.state.weather=:rain
          field.state.weather_turns=5
        end
        # Fixture must enter the existing weather lifecycle instead of silently mutating Field only.
        core.notify_weather_changed(:ag_fixture_rain_seed) if core && core.respond_to?(:notify_weather_changed)
        if e[0] && e[0].respond_to?(:cg_change_stat_stage)
          e[0].cg_change_stat_stage(:def,6)
        end
        @r1_weather_active=(weather ? weather.weather_active?(:rain) : false)
        @r1_water_percent=water_weather_percent(a[0],e[0])
        @r1_gorilla_base=with_temp_master_ability(a[1],0){ a[1].cg_atk_stat.to_i }
        @r1_gorilla_atk=a[1].cg_atk_stat.to_i
        @r1_unaware_target_hp=e[0] ? e[0].hp.to_i : 0
      elsif current_round==2
        @r2_weather_turns_before=field&&field.respond_to?(:state) ? field.state.weather_turns.to_i : 0
      elsif current_round==4
        set_effective_ability(a[1],ABILITY_WATER_ABSORB) if a[1]
        set_effective_ability(a[2],ABILITY_WATER_ABSORB) if a[2]
        set_effective_ability(a[3],ABILITY_WATER_ABSORB) if a[3]
        @r4_hp_before=[a[1] ? a[1].hp.to_i : 0,a[2] ? a[2].hp.to_i : 0,a[3] ? a[3].hp.to_i : 0]
      end
    end

    def self.prepare_round_actions
      p=current_plan; return false if p==nil
      apply_test_speeds
      prepare_round_preconditions
      @actual=[]
      log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s)
      test_allies.each_with_index do |b,i|
        next if b==nil
        ac=make_action(b,p[:allies][i])
        if b.respond_to?(:cg_round_actions)
          b.cg_round_actions.clear; b.cg_round_actions.push(ac)
        end
        b.cg_assign_action(ac) if b.respond_to?(:cg_assign_action)
        b.instance_variable_set(:@action,ac) unless b.respond_to?(:cg_assign_action)
      end
      true
    end

    def self.record_execution(b,outcome=:continue)
      return unless active? && b
      tok=(b.actor? ? "A" : "E")+b.index.to_s
      if outcome==:gorilla_lock
        tok+=":GLOCK"
      else
        a=b.action
        if a && a.guard?
          tok+=":Guard"
        elsif a && a.skill?
          sk=$data_skills[a.skill_id]
          tok+=":M"+move_id(sk).to_s
        else
          tok+=":Other"
        end
      end
      @actual.push(tok)
      log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    end

    def self.assert_bootstrap_once
      return if @boot_asserted==true
      @boot_asserted=true
      assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil"))
      assert_true("Ability Batch AG defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability AG test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil"))
      assert_true("Ability AG ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability AG starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden&&b.hp.to_i>0})
      assert_true("Ability AG starts with hidden Neutralizing Gas reserve",all_enemies[4]&&all_enemies[4].hidden)
    end

    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies
      exp=EXPECTED_EXECUTION_TOKENS[r]||[]
      ok_order=@actual==exp
      @action_checks+=1 if ok_order
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",ok_order,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        ok1=(@r1_weather_active==false)
        @weather_checks+=1 if ok1
        assert_true("Cloud Nine/Air Lock suppress central weather_active? without deleting Rain",ok1,"weather_active="+@r1_weather_active.to_s)
        ok2=@r1_water_percent.to_i==100
        @weather_checks+=1 if ok2
        assert_true("Rain Water damage modifier is suppressed to 100%",ok2,"percent="+@r1_water_percent.to_s)
        ok3=@r1_gorilla_base.to_i>0 && @r1_gorilla_atk.to_i==@r1_gorilla_base.to_i*GORILLA_ATK_PERCENT/100
        @stat_checks+=1 if ok3
        assert_true("Gorilla Tactics uses stat_query ATK x1.5",ok3,"base="+@r1_gorilla_base.to_s+" boosted="+@r1_gorilla_atk.to_s)
        lock=gorilla_lock_id(a[1])
        ok4=lock==332
        @action_checks+=1 if ok4
        assert_true("Gorilla Tactics first Move arms lock",ok4,"locked_move="+lock.to_s)
        ur=records_for(ABILITY_UNAWARE,:unaware_stage_ignore)[-1]||{}
        hp_after=e[0] ? e[0].hp.to_i : @r1_unaware_target_hp.to_i
        ok5=!ur.empty? && ur[:mode].to_sym==:ignore_target_stages && hp_after<@r1_unaware_target_hp.to_i
        @stat_checks+=1 if ok5
        assert_true("Unaware ignores target +DEF stage during real damaging Move",ok5,"record="+ur.inspect+" hp="+@r1_unaware_target_hp.to_s+"->"+hp_after.to_s)
      elsif r==2
        gr=records_for(ABILITY_GORILLA_TACTICS,:gorilla_lock_block)[-1]||{}
        ok1=!gr.empty? && gr[:locked_move_id].to_i==332 && gr[:attempted_move_id].to_i==55
        @action_checks+=1 if ok1
        assert_true("Gorilla Tactics blocks different Move before animation",ok1,"record="+gr.inspect)
        switched=e[0]&&e[4]&&e[0].hidden&&!e[4].hidden
        @lifecycle_checks+=1 if switched
        assert_true("Teleport deploys Neutralizing Gas reserve",switched,"E0_hidden="+(e[0] ? e[0].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        gas=neutralizing_gas_holder
        ok2=gas==e[4] && ability_id(a[3])==0
        @suppression_checks+=1 if ok2
        assert_true("Neutralizing Gas dynamically suppresses active Cloud Nine",ok2,"gas="+(gas ? gas.name.to_s : "nil")+" A3_effective="+(a[3] ? ability_id(a[3]).to_s : "nil"))
        pct=water_weather_percent(a[0],e[4])
        ok3=pct==150
        @weather_checks+=1 if ok3
        assert_true("Rain effect resumes while Gas suppresses the only active weather suppressor",ok3,"percent="+pct.to_s)
      elsif r==3
        switched=e[4]&&e[0]&&e[4].hidden&&!e[0].hidden
        @lifecycle_checks+=1 if switched
        assert_true("Neutralizing Gas Teleport exit restores Air Lock battler",switched,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" E0_hidden="+(e[0] ? e[0].hidden.to_s : "nil"))
        gasgone=neutralizing_gas_holder==nil
        @suppression_checks+=1 if gasgone
        assert_true("Neutralizing Gas suppression ends immediately after holder leaves",gasgone)
        pct=water_weather_percent(a[0],e[0])
        okweather=pct==100
        @weather_checks+=1 if okweather
        assert_true("Air Lock immediately suppresses still-existing Rain after Gas leaves",okweather,"percent="+pct.to_s)
      elsif r==4
        ids=[ABILITY_MOLD_BREAKER,ABILITY_TURBOBLAZE,ABILITY_TERAVOLT]
        ids.each_with_index do |aid,i|
          rec=records_for(aid,:target_ability_bypass)[-1]||{}
          target=a[i+1]
          before=@r4_hp_before[i].to_i
          after=target ? target.hp.to_i : before
          ok=!rec.empty? && rec[:target_ability].to_i==ABILITY_WATER_ABSORB && after<before
          @bypass_checks+=1 if ok
          assert_true("Ability "+aid.to_s+" bypasses Water Absorb and deals real Water damage",ok,"record="+rec.inspect+" hp="+before.to_s+"->"+after.to_s)
        end
      end
      log("ROUND "+r.to_s+" END")
    end

    def self.finish_round_assertions
      return unless active?
      assert_round
      @round_index+=1
    end

    def self.ability_covered_count
      HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}
    end

    def self.cleanup_test_overrides
      (test_allies+all_enemies).each do |b|
        next if b==nil
        b.instance_variable_set(:@cg_priority_test_speed_override_ag,nil)
        clear_gorilla_lock(b)
      end
      end_target_bypass
    end

    def self.finish_suite
      HANDLED_ABILITY_IDS.each do |id|
        assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)
      end
      result=@failures.empty? ? "PASS" : "FAIL"
      log("------------------------------------------------------------")
      log("RESULT="+result)
      log("SUMMARY rounds=4 failures="+@failures.size.to_s+" ability_ag="+ability_covered_count.to_s+"/8 weather_checks="+@weather_checks.to_i.to_s+" bypass_checks="+@bypass_checks.to_i.to_s+" suppression_checks="+@suppression_checks.to_i.to_s+" stat_checks="+@stat_checks.to_i.to_s+" action_checks="+@action_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=109")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}
      cleanup_test_overrides
      @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end

    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false
      @weather_checks=0; @bypass_checks=0; @suppression_checks=0; @stat_checks=0; @action_checks=0; @lifecycle_checks=0
      @bypass_user=nil; @bypass_target=nil; @bypass_ability_id=0; @bypass_move_id=0
      @r1_weather_active=nil; @r1_water_percent=0; @r1_gorilla_base=0; @r1_gorilla_atk=0; @r1_unaware_target_hp=0
      @r2_weather_turns_before=0; @r4_hp_before=[]
    end

    def self.reset_log
      h="CG POKEMON ABILITY AG RULE SUPPRESSION + ABILITY BYPASS AUTO REGRESSION v2.5.32a\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; weather suppression + target ability bypass + Unaware + Gorilla lock + Neutralizing Gas\r\n"+
        "BASELINE=v2.5.31a Ability Batch AF RPG Maker VX real-machine PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AF_PASS=256 BATCH_AG=8 PENDING=109\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}
      File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue
    end

    def self.begin_battle
      list=[]
      list += $game_party.members if $game_party
      list += $game_troop.members if $game_troop
      list.each{|b|clear_gorilla_lock(b) if b}
      if active? && field && field.respond_to?(:state)
        field.state.weather=:rain
        field.state.weather_turns=5
      end
      true
    rescue
      false
    end

    def self.start_auto_test
      return false if active?
      reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AG_v2.5.32a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s)
      ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil
      @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s)
      log(@failures[-1]); @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
      false
    end
  end
end

#==============================================================================
# ■ Formal registration
#==============================================================================
ALBERT_CG::ABILITY_AG_V2532.register_handlers if defined?(ALBERT_CG::ABILITY_AG_V2532)

#==============================================================================
# ■ Ability Core：Neutralizing Gas + target-only bypass outer authority
#==============================================================================
if defined?(ALBERT_CG::ABILITY_V250)
  module ALBERT_CG
    module ABILITY_V250
      class << self
        alias cg_v2532ag_raw_ability_id ability_id
        def ability_id(battler)
          aid=cg_v2532ag_raw_ability_id(battler).to_i
          return aid unless defined?(ALBERT_CG::ABILITY_AG_V2532)
          ag=ALBERT_CG::ABILITY_AG_V2532
          return 0 if ag.gas_suppresses?(battler,aid)
          return 0 if ag.bypass_target?(battler)
          return aid
        rescue
          return cg_v2532ag_raw_ability_id(battler).to_i
        end
      end
    end
  end
end

#==============================================================================
# ■ Weather Authority：Cloud Nine / Air Lock
#==============================================================================
if defined?(ALBERT_CG::ABILITY_WEATHER_V252)
  module ALBERT_CG
    module ABILITY_WEATHER_V252
      class << self
        alias cg_v2532ag_weather_active weather_active?
        def weather_active?(kind)
          if defined?(ALBERT_CG::ABILITY_AG_V2532) && ALBERT_CG::ABILITY_AG_V2532.weather_suppressed?
            return false
          end
          cg_v2532ag_weather_active(kind)
        end
      end
    end
  end
end

if defined?(ALBERT_CG::FIELD_V233)
  module ALBERT_CG
    module FIELD_V233
      class << self
        alias cg_v2532ag_damage_percent damage_percent
        def damage_percent(user,target,skill,type_id,damage_class,move_id)
          return ALBERT_CG::ABILITY_AG_V2532.with_weather_effects_disabled do
            cg_v2532ag_damage_percent(user,target,skill,type_id,damage_class,move_id)
          end if defined?(ALBERT_CG::ABILITY_AG_V2532)
          cg_v2532ag_damage_percent(user,target,skill,type_id,damage_class,move_id)
        end

        alias cg_v2532ag_apply_weather_residual apply_weather_residual
        def apply_weather_residual
          if defined?(ALBERT_CG::ABILITY_AG_V2532) && ALBERT_CG::ABILITY_AG_V2532.weather_suppressed?
            return
          end
          cg_v2532ag_apply_weather_residual
        end
      end
    end
  end
end

# Weather-dependent stat / accuracy lookups may belong to older sealed batches and
# may read FIELD state directly. Temporarily exposing weather_turns=0 preserves those
# existing authorities without editing them.
class Game_Battler
  alias cg_v2532ag_atk_stat cg_atk_stat
  def cg_atk_stat
    return ALBERT_CG::ABILITY_AG_V2532.with_weather_effects_disabled{cg_v2532ag_atk_stat} if defined?(ALBERT_CG::ABILITY_AG_V2532)
    cg_v2532ag_atk_stat
  end

  alias cg_v2532ag_def_stat cg_def_stat
  def cg_def_stat
    return ALBERT_CG::ABILITY_AG_V2532.with_weather_effects_disabled{cg_v2532ag_def_stat} if defined?(ALBERT_CG::ABILITY_AG_V2532)
    cg_v2532ag_def_stat
  end

  alias cg_v2532ag_spa cg_spa
  def cg_spa
    return ALBERT_CG::ABILITY_AG_V2532.with_weather_effects_disabled{cg_v2532ag_spa} if defined?(ALBERT_CG::ABILITY_AG_V2532)
    cg_v2532ag_spa
  end

  alias cg_v2532ag_spd cg_spd
  def cg_spd
    return ALBERT_CG::ABILITY_AG_V2532.with_weather_effects_disabled{cg_v2532ag_spd} if defined?(ALBERT_CG::ABILITY_AG_V2532)
    cg_v2532ag_spd
  end

  alias cg_v2532ag_spe cg_spe
  def cg_spe
    return ALBERT_CG::ABILITY_AG_V2532.with_weather_effects_disabled{cg_v2532ag_spe} if defined?(ALBERT_CG::ABILITY_AG_V2532)
    cg_v2532ag_spe
  end

  alias cg_v2532ag_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    return ALBERT_CG::ABILITY_AG_V2532.with_weather_effects_disabled{cg_v2532ag_calc_hit(user,obj)} if defined?(ALBERT_CG::ABILITY_AG_V2532)
    cg_v2532ag_calc_hit(user,obj)
  end
end

if defined?(ALBERT_CG::ABILITY_V250)
  module ALBERT_CG
    module ABILITY_V250
      class << self
        alias cg_v2532ag_trigger_end_turn trigger_end_turn
        def trigger_end_turn
          return ALBERT_CG::ABILITY_AG_V2532.with_weather_effects_disabled{cg_v2532ag_trigger_end_turn} if defined?(ALBERT_CG::ABILITY_AG_V2532)
          cg_v2532ag_trigger_end_turn
        end
      end
    end
  end
end

#==============================================================================
# ■ Game_Battler：target bypass scope + Unaware damage stat mask
#==============================================================================
class Game_Battler
  alias cg_v2532ag_skill_effect skill_effect
  def skill_effect(user,skill)
    ag=defined?(ALBERT_CG::ABILITY_AG_V2532) ? ALBERT_CG::ABILITY_AG_V2532 : nil
    armed=ag ? ag.begin_target_bypass(user,self,skill) : false
    begin
      return cg_v2532ag_skill_effect(user,skill)
    ensure
      ag.end_target_bypass if ag && armed
    end
  end

  alias cg_v2532ag_damage_class_stats cg_damage_class_stats
  def cg_damage_class_stats(user,damage_class)
    if defined?(ALBERT_CG::ABILITY_AG_V2532)
      return ALBERT_CG::ABILITY_AG_V2532.with_unaware_mask(user,self,damage_class) do
        cg_v2532ag_damage_class_stats(user,damage_class)
      end
    end
    cg_v2532ag_damage_class_stats(user,damage_class)
  end
end

# v2.5.32a regression fix: v2.1 Six-Stat damage authority uses cg_class_base_damage,
# not cg_damage_class_stats. Hook the real formula trunk so Unaware masks the relevant
# stage before cg_atk_stat/cg_def_stat/cg_spa/cg_spd are queried.
class Game_Battler
  if method_defined?(:cg_class_base_damage)
    alias cg_v2532a_unaware_class_base_damage cg_class_base_damage
    def cg_class_base_damage(user,obj,damage_class)
      if defined?(ALBERT_CG::ABILITY_AG_V2532)
        return ALBERT_CG::ABILITY_AG_V2532.with_unaware_mask(user,self,damage_class) do
          cg_v2532a_unaware_class_base_damage(user,obj,damage_class)
        end
      end
      cg_v2532a_unaware_class_base_damage(user,obj,damage_class)
    end
  end
end

#==============================================================================
# ■ Gorilla Tactics：switch-out cleanup
#==============================================================================
if defined?(ALBERT_CG::FORCE_SWITCH_V235)
  module ALBERT_CG
    module FORCE_SWITCH_V235
      class << self
        alias cg_v2532ag_clear_switch_out_volatile clear_switch_out_volatile
        def clear_switch_out_volatile(battler)
          ALBERT_CG::ABILITY_AG_V2532.clear_gorilla_lock(battler) if defined?(ALBERT_CG::ABILITY_AG_V2532)
          cg_v2532ag_clear_switch_out_volatile(battler)
        end
      end
    end
  end
end

#==============================================================================
# ■ Scene lifecycle / Gorilla action intercept
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2532ag_start start
  def start
    ALBERT_CG::ABILITY_AG_V2532.begin_battle if defined?(ALBERT_CG::ABILITY_AG_V2532)
    cg_v2532ag_start
  end

  alias cg_v2532ag_execute_action execute_action
  def execute_action
    b=@active_battler
    outcome=:continue
    if defined?(ALBERT_CG::ABILITY_AG_V2532)
      if ALBERT_CG::ABILITY_AG_V2532.gorilla_action_intercept(b)
        outcome=:gorilla_lock
      end
      ALBERT_CG::ABILITY_AG_V2532.record_execution(b,outcome) if ALBERT_CG::ABILITY_AG_V2532.active?
      if outcome!=:continue
        ALBERT_CG::ABILITY_AG_V2532.finish_skipped_action(b)
        return
      end
    end
    cg_v2532ag_execute_action
  end
end

# Disable previous newest F11 harness.
if defined?(ALBERT_CG::ABILITY_AF_V2531)
  module ALBERT_CG
    module ABILITY_AF_V2531
      def self.f11_trigger?; false; end
    end
  end
end

#==============================================================================
# ■ TEST Scene hooks
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2532ag_test_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AG_V2532) && ALBERT_CG::ABILITY_AG_V2532.active?
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_AG_V2532.finish_round_assertions
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      else
        ALBERT_CG::ABILITY_AG_V2532.finish_round_assertions
      end
    end
    cg_v2532ag_test_turn_end
  end

  alias cg_v2532ag_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AG_V2532) && ALBERT_CG::ABILITY_AG_V2532.active?
      return cg_v2532ag_start_party_command
    end
    cg_v2532ag_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_AG_V2532.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AG_V2532.finished?
      ALBERT_CG::ABILITY_AG_V2532.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_AG_V2532.prepare_round_actions
    start_main
  end
end

class Game_Battler
  alias cg_v2532ag_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AG_V2532) && ALBERT_CG::ABILITY_AG_V2532.active?
      v=@cg_priority_test_speed_override_ag
      return v.to_i if v!=nil
    end
    cg_v2532ag_priority_base_speed
  rescue
    cg_v2532ag_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2532ag_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AG_V2532) && ALBERT_CG::ABILITY_AG_V2532.active?
      a=ALBERT_CG::ABILITY_AG_V2532.forced_enemy_action(self)
      if a
        cg_assign_action(a) if respond_to?(:cg_assign_action)
        @action=a unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v2532ag_enemy_make_action
  end
end

module ALBERT_CG
  class << self
    alias cg_v2532ag_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2532ag_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_AG_V2532) && ALBERT_CG::ABILITY_AG_V2532.active?
        ALBERT_CG::ABILITY_AG_V2532::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AG_V2532.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if h
          h.change_level(ALBERT_CG::ABILITY_AG_V2532::TEST_LEVEL,false); h.recover_all
          h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages)
          h.cg_v237_clear_identity if h.respond_to?(:cg_v237_clear_identity)
          h.instance_variable_set(:@cg_master_ability_id,0)
          ALBERT_CG::ABILITY_AG_V2532.clear_gorilla_lock(h)
        end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2532ag_scene_map_update update
  def update
    cg_v2532ag_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_AG_V2532)
    ALBERT_CG::ABILITY_AG_V2532.start_auto_test if ALBERT_CG::ABILITY_AG_V2532.f11_trigger?
  end
end
