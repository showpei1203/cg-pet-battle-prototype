# RMVX_SCRIPT_INDEX: 240
# RMVX_SCRIPT_ID: 251700002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch R v2.5.17a
# RMVX_SOURCE_SHA256: f6416947b62f19b2223807be7dcd602fe27139a921c24df96f3d81d37178656b

#==============================================================================
# ■ CG Pokemon Ability Batch R v2.5.17a - Teleport Priority Fixture Fix
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.16a Ability Batch Q RPG Maker VX 實機 PASS 為唯一基底，實作第十八批
#  8 個 Ability。本批集中處理「隊友／全場型命中與傷害 Aura」，沿用既有 Ability
#  Runtime Core 的有效 Ability 判定、既有最終傷害鏈與 Accuracy Authority，不建立
#  第二套傷害公式、不改 Move 937/937 已封版內容。
#
# 【本批 Ability】
#  132 Friend Guard    友情防守：其他 active 隊友受到一般傷害 x0.75。
#  162 Victory Star    勝利之星：自己與 active 隊友命中率 x1.10（上限 100）。
#  186 Dark Aura       暗黑氣場：全場 Dark 招式 x4/3；Aura Break 在場時反轉為 x3/4。
#  187 Fairy Aura      妖精氣場：全場 Fairy 招式 x4/3；Aura Break 在場時反轉為 x3/4。
#  188 Aura Break      氣場破壞：只要 active，即讓 Dark/Fairy Aura 使用反轉倍率。
#  217 Battery         蓄電池：其他 active 隊友的 Special 招式 x1.30。
#  249 Power Spot      能量點：其他 active 隊友造成的傷害 x1.30。
#  252 Steely Spirit   鋼之意志：自己與 active 隊友的 Steel 招式 x1.50。
#
# 【主要設定項】
#  TEST_TROOP_ID = 720；HANDLED_ABILITY_IDS = 8。
#  Coverage：136/373 -> 144/373，pending 237 -> 229。
#  Friend Guard=75%；Victory Star=110%；Battery/Power Spot=130%；
#  Steely Spirit=150%；Aura=4/3；Aura Break reversal=3/4。
#
# 【機制規則】
#  1. 本頁向既有 Ability Core TRIGGERS 追加 :team_damage_modify / :team_accuracy_modify。
#     這只是沿用 Core register/dispatch 的新觀察點，不另建 Ability state。
#  2. 最終 HP 傷害 bridge 掛在既有 execute_damage 最外層：先讓 active holder 依隊伍／
#     全場條件修正 @hp_damage，再交回已 PASS 的 defender/attacker damage authority。
#  3. 命中 bridge 掛在既有 calc_hit 最外層：先取得既有 Accuracy Authority 的結果，
#     再讓 Victory Star 修正，最後 clamp 1..100。
#  4. Friend Guard / Battery / Power Spot 僅作用於「其他」同側 active holder；
#     Victory Star / Steely Spirit 包含 holder 自己。
#  5. Dark Aura / Fairy Aura 是全場 Aura。若任一 active battler 的有效 Ability=188，
#     對應 Aura 直接改用 3/4，而不是先 x4/3 再做額外反乘，避免四捨五入雙重誤差。
#  6. Aura holder 多隻時同類 Aura 不重複套用；利用 context flag 只套一次。
#     Friend Guard / Victory Star / Battery / Power Spot / Steely Spirit 則每個有效 holder
#     依序套用，保留多 holder 疊加空間。
#  7. Fixed damage 不受本批 team damage multiplier 影響。
#  8. 有效 Ability 一律透過 cg_master_ability_id + Core dispatch，因此既有 Suppression /
#     Override 規則仍然有效；hidden、KO holder 不參與 team dispatch。
#  9. F11 Regression 使用 Actual Scene_Battle。只在 TEST active 時固定 action、SPE、
#     hit 最終落點與回合前置狀態；正式玩家戰鬥 RNG 不受影響。
# 10. TEST Convenience 僅限 F11；正式 Release 仍須恢復 emerged、BGM/BGS、正常焦點。
#
# 【可調參數】
#  FRIEND_GUARD_PERCENT=75、VICTORY_STAR_PERCENT=110、BATTERY_PERCENT=130、
#  POWER_SPOT_PERCENT=130、STEELY_SPIRIT_PERCENT=150、AURA_NUM/DEN=4/3、
#  AURA_BREAK_NUM/DEN=3/4。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫；Ability 由 damage/accuracy lifecycle 自動掃描 active holders。
#  開發測試：地圖按 F11，自動進 troop 720，跑三回合並輸出
#  Pokemon_Ability_R_AutoTest_v2_5_17a.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：Victory Star 修正 Thunder 命中；Pursuit 命中 Friend Guard 保護的目標，
#  Power Spot 生效，Dark Aura 因 Aura Break 在場改為 x3/4；敵方 Steely Spirit holder
#  使用 Metal Claw 驗證 Steel x1.5。
#  Round2：Aura Break holder 依正式 Action Priority 使用 Teleport（正常位於本回合後段）換入
#  Fairy Aura reserve；本回合只驗 lifecycle，不錯誤要求 Teleport 先於一般招式。
#  Round3：Fairy Aura reserve 已 active 後，再由 Raichu 使用 Fairy Wind，驗 Fairy Aura x4/3，
#  並同時重驗 Battery / Power Spot / Friend Guard 與 reserve stability。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchR"] = "2.5.17a"

module ALBERT_CG
  module ABILITY_R_V2517
    VERSION = "2.5.17a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 720
    VK_F11 = 0x7A

    ABILITY_FRIEND_GUARD   = 132
    ABILITY_VICTORY_STAR   = 162
    ABILITY_DARK_AURA      = 186
    ABILITY_FAIRY_AURA     = 187
    ABILITY_AURA_BREAK     = 188
    ABILITY_BATTERY        = 217
    ABILITY_POWER_SPOT     = 249
    ABILITY_STEELY_SPIRIT  = 252
    HANDLED_ABILITY_IDS = [132,162,186,187,188,217,249,252]

    FRIEND_GUARD_PERCENT  = 75
    VICTORY_STAR_PERCENT  = 110
    BATTERY_PERCENT       = 130
    POWER_SPOT_PERCENT    = 130
    STEELY_SPIRIT_PERCENT = 150
    AURA_NUM = 4
    AURA_DEN = 3
    AURA_BREAK_NUM = 3
    AURA_BREAK_DEN = 4

    TEST_ALLIES = [
      {:dex=>25, :level=>40,:ability=>ABILITY_VICTORY_STAR, :moves=>[87,584,55,150]},
      {:dex=>65, :level=>40,:ability=>ABILITY_BATTERY,      :moves=>[228,150,150,150]},
      {:dex=>128,:level=>40,:ability=>ABILITY_POWER_SPOT,   :moves=>[150,150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>70,:ability=>ABILITY_FRIEND_GUARD,  :moves=>[150,150,150,150]},
      {:dex=>94, :level=>70,:ability=>ABILITY_DARK_AURA,     :moves=>[150,150,150,150]},
      {:dex=>91, :level=>60,:ability=>ABILITY_AURA_BREAK,    :moves=>[150,100,150,150]},
      {:dex=>109,:level=>40,:ability=>ABILITY_STEELY_SPIRIT, :moves=>[232,150,150,150]},
      {:dex=>197,:level=>60,:ability=>ABILITY_FAIRY_AURA,    :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {:name=>"VICTORY_DARK_BREAK_STEEL",
       :allies=>[{:kind=>:guard},{:kind=>:move,:move_id=>87,:target=>0},{:kind=>:move,:move_id=>228,:target=>1},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},2=>{:kind=>:move,:move_id=>150,:target=>2},3=>{:kind=>:move,:move_id=>232,:target=>1}}},
      {:name=>"AURA_BREAK_OUT_FAIRY_AURA_IN",
       :allies=>[{:kind=>:guard},{:kind=>:move,:move_id=>584,:target=>1},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},2=>{:kind=>:move,:move_id=>100,:target=>0},3=>{:kind=>:move,:move_id=>150,:target=>1}}},
      {:name=>"FAIRY_AURA_AND_SUPPORT_RESERVE_STABILITY",
       :allies=>[{:kind=>:guard},{:kind=>:move,:move_id=>584,:target=>1},{:kind=>:move,:move_id=>150,:target=>0},{:kind=>:move,:move_id=>150,:target=>0}],
       :enemies=>{0=>{:kind=>:move,:move_id=>150,:target=>1},1=>{:kind=>:move,:move_id=>150,:target=>1},3=>{:kind=>:move,:move_id=>150,:target=>1},4=>{:kind=>:move,:move_id=>150,:target=>2}}},
    ]

    TEST_SPEEDS = {
      :r1=>[500,400,350,100, 450,200,150,300,0],
      :r2=>[500,400,350,100, 300,250,450,200,0],
      :r3=>[500,400,350,100, 300,250,0,200,450],
    }
    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","E0:M150","A1:M87","A2:M228","E3:M232","E1:M150","E2:M150","A3:M150"],
      2=>["A0:Guard","A1:M584","A2:M150","E0:M150","E1:M150","E3:M150","A3:M150","E2:M100"],
      3=>["A0:Guard","E4:M150","A1:M584","A2:M150","E0:M150","E1:M150","E3:M150","A3:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.active?; @active == true; end
    def self.current_round; @round_index.to_i + 1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i >= ROUND_PLANS.size; end
    def self.test_allies; $game_party == nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop == nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_R_AutoTest_v2_5_17a.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end

    def self.ensure_triggers
      return false if core==nil
      list=core::TRIGGERS
      list.push(:team_damage_modify) unless list.include?(:team_damage_modify)
      list.push(:team_accuracy_modify) unless list.include?(:team_accuracy_modify)
      true
    rescue
      false
    end

    def self.same_side?(a,b)
      return false if a==nil || b==nil
      a.actor? == b.actor?
    rescue
      false
    end
    def self.active_holders
      core ? core.active_battlers : []
    rescue
      []
    end
    def self.ability_id(b); core ? core.ability_id(b).to_i : 0; rescue; 0; end
    def self.aura_active?(aid)
      active_holders.any?{|b| ability_id(b)==aid.to_i}
    rescue
      false
    end
    def self.type_id(sym)
      return 0 unless defined?(ALBERT_CG::POKEMON_COMBAT)
      t=ALBERT_CG::POKEMON_COMBAT::TYPE_IDS
      t && t.has_key?(sym) ? t[sym].to_i : 0
    rescue
      0
    end
    def self.special_move?(skill)
      return false if skill==nil
      return skill.cg_pokemon_damage_class==:special if skill.respond_to?(:cg_pokemon_damage_class)
      false
    rescue
      false
    end
    def self.fixed_damage?(skill)
      return ALBERT_CG::ABILITY_MODIFIER_V253.skill_fixed_damage?(skill) if defined?(ALBERT_CG::ABILITY_MODIFIER_V253)
      false
    rescue
      false
    end
    def self.ratio(value,num,den)
      v=value.to_i; return v if v<=0
      r=v*num.to_i/den.to_i
      r=1 if r<1
      r
    end
    def self.battler_token(b)
      return "nil" if b==nil
      (b.actor? ? "A" : "E")+b.index.to_s
    rescue
      "?"
    end

    def self.write_line(path,text,mode="ab")
      File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true
    rescue
      false
    end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.reset_log
      h="CG POKEMON ABILITY R TEAM AURA + ALLY SUPPORT AUTO REGRESSION v2.5.17\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; team accuracy + ally/global damage aura lifecycle\r\n"+
        "BASELINE=v2.5.16a Ability Batch Q Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_Q_PASS=136 BATCH_R=8 PENDING=229\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue
    end
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

    def self.note_local(aid,holder,kind,ctx,before,after)
      return true unless active?
      @ability_trigger_counts[aid]=@ability_trigger_counts[aid].to_i+1
      rec={:ability=>aid,:kind=>kind,:before=>before.to_i,:after=>after.to_i,
           :move_id=>ctx[:move_id].to_i,:type_id=>ctx[:type_id].to_i,
           :holder=>battler_token(holder),:user=>battler_token(ctx[:user]),:target=>battler_token(ctx[:target])}
      rec[:reversed]=ctx[:aura_break_active] if ctx.has_key?(:aura_break_active)
      @records[aid]=[] if @records[aid]==nil
      @records[aid].push(rec)
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
      log("ABILITY_R_TRIGGER ability="+aid.to_s+" battler="+(holder ? holder.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
      true
    rescue
      false
    end

    def self.apply_friend_guard(holder,ctx)
      return false if ctx[:fixed_damage]
      return false unless same_side?(holder,ctx[:target]) && !holder.equal?(ctx[:target])
      before=ctx[:damage].to_i; return false if before<=0
      after=ratio(before,FRIEND_GUARD_PERCENT,100); ctx[:damage]=after
      note_local(ABILITY_FRIEND_GUARD,holder,:friend_guard,ctx,before,after); true
    end
    def self.apply_battery(holder,ctx)
      return false if ctx[:fixed_damage] || holder.equal?(ctx[:user])
      return false unless same_side?(holder,ctx[:user]) && special_move?(ctx[:skill])
      before=ctx[:damage].to_i; return false if before<=0
      after=ratio(before,BATTERY_PERCENT,100); ctx[:damage]=after
      note_local(ABILITY_BATTERY,holder,:battery,ctx,before,after); true
    end
    def self.apply_power_spot(holder,ctx)
      return false if ctx[:fixed_damage] || holder.equal?(ctx[:user])
      return false unless same_side?(holder,ctx[:user])
      before=ctx[:damage].to_i; return false if before<=0
      after=ratio(before,POWER_SPOT_PERCENT,100); ctx[:damage]=after
      note_local(ABILITY_POWER_SPOT,holder,:power_spot,ctx,before,after); true
    end
    def self.apply_steely_spirit(holder,ctx)
      return false if ctx[:fixed_damage] || ctx[:type_id].to_i!=type_id(:steel)
      return false unless same_side?(holder,ctx[:user])
      before=ctx[:damage].to_i; return false if before<=0
      after=ratio(before,STEELY_SPIRIT_PERCENT,100); ctx[:damage]=after
      note_local(ABILITY_STEELY_SPIRIT,holder,:steely_spirit,ctx,before,after); true
    end
    def self.apply_dark_aura(holder,ctx)
      return false if ctx[:fixed_damage] || ctx[:type_id].to_i!=type_id(:dark) || ctx[:dark_aura_applied]
      before=ctx[:damage].to_i; return false if before<=0
      reversed=aura_active?(ABILITY_AURA_BREAK)
      ctx[:aura_break_active]=reversed
      after=reversed ? ratio(before,AURA_BREAK_NUM,AURA_BREAK_DEN) : ratio(before,AURA_NUM,AURA_DEN)
      ctx[:damage]=after; ctx[:dark_aura_applied]=true
      note_local(ABILITY_DARK_AURA,holder,reversed ? :dark_aura_break : :dark_aura,ctx,before,after); true
    end
    def self.apply_fairy_aura(holder,ctx)
      return false if ctx[:fixed_damage] || ctx[:type_id].to_i!=type_id(:fairy) || ctx[:fairy_aura_applied]
      before=ctx[:damage].to_i; return false if before<=0
      reversed=aura_active?(ABILITY_AURA_BREAK)
      ctx[:aura_break_active]=reversed
      after=reversed ? ratio(before,AURA_BREAK_NUM,AURA_BREAK_DEN) : ratio(before,AURA_NUM,AURA_DEN)
      ctx[:damage]=after; ctx[:fairy_aura_applied]=true
      note_local(ABILITY_FAIRY_AURA,holder,reversed ? :fairy_aura_break : :fairy_aura,ctx,before,after); true
    end
    def self.apply_aura_break(holder,ctx)
      return false if ctx[:fixed_damage]
      matching=(ctx[:type_id].to_i==type_id(:dark) && aura_active?(ABILITY_DARK_AURA)) ||
               (ctx[:type_id].to_i==type_id(:fairy) && aura_active?(ABILITY_FAIRY_AURA))
      return false unless matching
      before=ctx[:damage].to_i
      note_local(ABILITY_AURA_BREAK,holder,:aura_break,ctx,before,before); true
    end
    def self.apply_victory_star(holder,ctx)
      return false unless same_side?(holder,ctx[:user])
      before=ctx[:value].to_i; return false if before<=0
      after=before*VICTORY_STAR_PERCENT/100; after=100 if after>100; after=1 if after<1
      ctx[:value]=after
      note_local(ABILITY_VICTORY_STAR,holder,:victory_star,ctx,before,after); true
    end

    def self.register_handlers
      ensure_triggers
      c=core; return false if c==nil
      c.register(ABILITY_FRIEND_GUARD,:team_damage_modify,self,:apply_friend_guard)
      c.register(ABILITY_DARK_AURA,:team_damage_modify,self,:apply_dark_aura)
      c.register(ABILITY_FAIRY_AURA,:team_damage_modify,self,:apply_fairy_aura)
      c.register(ABILITY_AURA_BREAK,:team_damage_modify,self,:apply_aura_break)
      c.register(ABILITY_BATTERY,:team_damage_modify,self,:apply_battery)
      c.register(ABILITY_POWER_SPOT,:team_damage_modify,self,:apply_power_spot)
      c.register(ABILITY_STEELY_SPIRIT,:team_damage_modify,self,:apply_steely_spirit)
      c.register(ABILITY_VICTORY_STAR,:team_accuracy_modify,self,:apply_victory_star)
      true
    end

    def self.dispatch_team_damage(target,user,damage)
      return damage.to_i if core==nil || target==nil || user==nil || damage.to_i<=0
      skill=core.current_skill(user)
      tid= if defined?(ALBERT_CG::ABILITY_MODIFIER_V253)
        ALBERT_CG::ABILITY_MODIFIER_V253.type_id_for_action(user,skill)
      else
        0
      end
      ctx={:user=>user,:target=>target,:skill=>skill,:move_id=>core.current_move_id(user),
           :type_id=>tid.to_i,:damage=>damage.to_i,:raw_damage=>damage.to_i,
           :fixed_damage=>fixed_damage?(skill)}
      core.dispatch_all(:team_damage_modify,active_holders,ctx)
      ctx[:damage].to_i
    rescue
      damage.to_i
    end
    def self.dispatch_team_accuracy(target,user,obj,value)
      return value.to_i if core==nil || target==nil || user==nil
      tid= if defined?(ALBERT_CG::ABILITY_MODIFIER_V253)
        ALBERT_CG::ABILITY_MODIFIER_V253.type_id_for_action(user,obj)
      else
        0
      end
      mid=defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT.move_id(obj).to_i : 0
      ctx={:user=>user,:target=>target,:skill=>obj,:move_id=>mid,:type_id=>tid.to_i,
           :value=>value.to_i,:raw_value=>value.to_i}
      core.dispatch_all(:team_accuracy_modify,active_holders,ctx)
      v=ctx[:value].to_i; v=100 if v>100; v=1 if v<1; v
    rescue
      value.to_i
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
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability R v2.5.17a AutoRegression",ms)
    end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); else; a.clear; end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c); end
    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||TEST_SPEEDS[:r1]||[]
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_r,vals[i]) if b}
    end
    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end
    def self.clear_round_states
      (test_allies+all_enemies).each do |b|
        next if b==nil || b.hp.to_i<=0
        b.recover_all if b.respond_to?(:recover_all)
      end
    rescue
    end
    def self.prepare_round_preconditions
      clear_round_states
      apply_test_speeds
      @r2_storage_before=storage_size if current_round==2
    end
    def self.prepare_round_actions
      p=current_plan; return false if p==nil; prepare_round_preconditions; @actual=[]; log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s)
      test_allies.each_with_index do |b,i|; next if b==nil||b.hp.to_i<=0; a=make_action(b,p[:allies][i]); if b.respond_to?(:cg_round_actions); b.cg_round_actions.clear; b.cg_round_actions.push(a); end; b.cg_assign_action(a) if b.respond_to?(:cg_assign_action); b.instance_variable_set(:@action,a) unless b.respond_to?(:cg_assign_action); end; true
    end
    def self.record_execution(b)
      return unless active?&&b; a=b.action; pre=b.actor? ? "A" : "E"; tok=if a&&a.guard?; pre+b.index.to_s+":Guard" elsif a&&a.skill?; pre+b.index.to_s+":M"+ALBERT_CG::MOVE_EFFECT.move_id(a.skill).to_i.to_s else; pre+b.index.to_s+":Other" end; @actual.push(tok); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    rescue
    end
    def self.records_for(aid,move_id=nil,kind=nil)
      a=@records[aid]||[]
      a.select{|r|(move_id==nil||r[:move_id].to_i==move_id.to_i)&&(kind==nil||r[:kind]==kind)}
    end
    def self.ratio_record_ok?(aid,move_id,num,den,kind=nil)
      records_for(aid,move_id,kind).any?{|r|r[:before].to_i>0 && r[:after].to_i==ratio(r[:before],num,den)}
    end

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      tid=($game_troop&&$game_troop.troop) ? $game_troop.troop.id.to_i : 0; ids=core ? core.registered_ability_ids : []
      assert_true("Ability Catalog count=373",core&&core.catalog_count==373,"actual="+(core ? core.catalog_count.to_s : "nil"))
      assert_true("Ability Batch R registers 8 IDs",HANDLED_ABILITY_IDS.all?{|id|ids.include?(id)})
      assert_true("Scene_Battle uses Ability R test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability R ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability R starts with 4 active enemies",all_enemies.select{|b|b&&!b.hidden}.size==4)
      assert_true("Ability R starts with 1 hidden Fairy Aura reserve",all_enemies.select{|b|b&&b.hidden}.size==1)
    end

    def self.assert_round
      r=current_round; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==exp,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        v=ratio_record_ok?(ABILITY_VICTORY_STAR,87,VICTORY_STAR_PERCENT,100,:victory_star)
        @accuracy_checks+=1 if v; assert_true("Victory Star raises Thunder accuracy by 10%",v,(records_for(ABILITY_VICTORY_STAR,87)[-1]||{}).inspect)
        b=ratio_record_ok?(ABILITY_BATTERY,87,BATTERY_PERCENT,100,:battery)
        @team_damage_checks+=1 if b; assert_true("Battery boosts ally Special damage x1.30",b,(records_for(ABILITY_BATTERY,87)[-1]||{}).inspect)
        p=ratio_record_ok?(ABILITY_POWER_SPOT,228,POWER_SPOT_PERCENT,100,:power_spot)
        @team_damage_checks+=1 if p; assert_true("Power Spot boosts other ally damage x1.30",p,(records_for(ABILITY_POWER_SPOT,228)[-1]||{}).inspect)
        fg=ratio_record_ok?(ABILITY_FRIEND_GUARD,228,FRIEND_GUARD_PERCENT,100,:friend_guard)
        @team_damage_checks+=1 if fg; assert_true("Friend Guard reduces other ally incoming damage x0.75",fg,(records_for(ABILITY_FRIEND_GUARD,228)[-1]||{}).inspect)
        da=ratio_record_ok?(ABILITY_DARK_AURA,228,AURA_BREAK_NUM,AURA_BREAK_DEN,:dark_aura_break)
        @aura_checks+=1 if da; assert_true("Dark Aura reverses to x0.75 while Aura Break active",da,(records_for(ABILITY_DARK_AURA,228)[-1]||{}).inspect)
        ab=!records_for(ABILITY_AURA_BREAK,228,:aura_break).empty?
        @aura_checks+=1 if ab; assert_true("Aura Break observes active Dark Aura and reverses it",ab,(records_for(ABILITY_AURA_BREAK,228)[-1]||{}).inspect)
        ss=ratio_record_ok?(ABILITY_STEELY_SPIRIT,232,STEELY_SPIRIT_PERCENT,100,:steely_spirit)
        @team_damage_checks+=1 if ss; assert_true("Steely Spirit boosts holder Steel damage x1.50",ss,(records_for(ABILITY_STEELY_SPIRIT,232)[-1]||{}).inspect)
      elsif r==2
        sw=e[2]&&e[4]&&e[2].hidden&&!e[4].hidden; @lifecycle_checks+=1 if sw; assert_true("Teleport deploys hidden Fairy Aura reserve",sw,"E2_hidden="+(e[2] ? e[2].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        sa=storage_size; stor=sa==@r2_storage_before.to_i; @lifecycle_checks+=1 if stor; assert_true("Fairy Aura reserve switch does not consume Storage Pokemon",stor,"before="+@r2_storage_before.to_s+" after="+sa.to_s)
      elsif r==3
        stable=e[4]&&!e[4].hidden&&e[4].hp.to_i>0
        assert_true("Fairy Aura reserve remains active through Round3",stable,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" hp="+(e[4] ? e[4].hp.to_i.to_s : "nil"))
        fa=ratio_record_ok?(ABILITY_FAIRY_AURA,584,AURA_NUM,AURA_DEN,:fairy_aura)
        @aura_checks+=1 if fa; assert_true("Fairy Aura boosts Fairy damage x4/3 after Aura Break has left",fa,(records_for(ABILITY_FAIRY_AURA,584)[-1]||{}).inspect)
        batt=ratio_record_ok?(ABILITY_BATTERY,584,BATTERY_PERCENT,100,:battery)
        pow=ratio_record_ok?(ABILITY_POWER_SPOT,584,POWER_SPOT_PERCENT,100,:power_spot)
        fri=ratio_record_ok?(ABILITY_FRIEND_GUARD,584,FRIEND_GUARD_PERCENT,100,:friend_guard)
        assert_true("Round3 Battery remains effective on ally Special move",batt,(records_for(ABILITY_BATTERY,584)[-1]||{}).inspect)
        assert_true("Round3 Power Spot remains effective",pow,(records_for(ABILITY_POWER_SPOT,584)[-1]||{}).inspect)
        assert_true("Round3 Friend Guard remains effective",fri,(records_for(ABILITY_FRIEND_GUARD,584)[-1]||{}).inspect)
      end
      log("ROUND "+r.to_s+" END")
    end
    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_r,nil) if b}; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"; log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_r="+ability_covered_count.to_s+"/8 accuracy_checks="+@accuracy_checks.to_i.to_s+" team_damage_checks="+@team_damage_checks.to_i.to_s+" aura_checks="+@aura_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=229")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @accuracy_checks=0; @team_damage_checks=0; @aura_checks=0; @lifecycle_checks=0; @r2_storage_before=0
    end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; ALBERT_CG::UNIQUE_I_V242.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_I_V242)&&ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes); @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_R_v2.5.17a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

ALBERT_CG::ABILITY_R_V2517.register_handlers if defined?(ALBERT_CG::ABILITY_V250)
if defined?(ALBERT_CG::ABILITY_Q_V2516)
  module ALBERT_CG; module ABILITY_Q_V2516; def self.f11_trigger?; false; end; end; end
end

# Formal team-damage bridge：只疊在既有 execute_damage chain 外層。
class Game_Battler
  alias cg_v2517r_team_damage_execute_damage execute_damage
  def execute_damage(user)
    if defined?(ALBERT_CG::ABILITY_R_V2517) && user!=nil && @hp_damage.to_i>0
      @hp_damage=ALBERT_CG::ABILITY_R_V2517.dispatch_team_damage(self,user,@hp_damage.to_i)
    end
    cg_v2517r_team_damage_execute_damage(user)
  end

  alias cg_v2517r_team_accuracy_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    value=cg_v2517r_team_accuracy_calc_hit(user,obj)
    if defined?(ALBERT_CG::ABILITY_R_V2517) && user!=nil
      value=ALBERT_CG::ABILITY_R_V2517.dispatch_team_accuracy(self,user,obj,value)
    end
    value
  rescue
    cg_v2517r_team_accuracy_calc_hit(user,obj)
  end
end

# TEST-only：固定實際命中結果，但先完整跑正式 calc_hit，保留 Victory Star 70->77 證據。
class Game_Battler
  alias cg_v2517r_test_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    value=cg_v2517r_test_calc_hit(user,obj)
    if defined?(ALBERT_CG::ABILITY_R_V2517) && ALBERT_CG::ABILITY_R_V2517.active?
      @cg_v2517r_last_computed_hit=value.to_i
      return 100
    end
    value
  end
  alias cg_v2517r_test_calc_eva calc_eva
  def calc_eva(user,obj=nil); return 0 if defined?(ALBERT_CG::ABILITY_R_V2517)&&ALBERT_CG::ABILITY_R_V2517.active?; cg_v2517r_test_calc_eva(user,obj); end
  alias cg_v2517r_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_R_V2517)&&ALBERT_CG::ABILITY_R_V2517.active?
      v=@cg_priority_test_speed_override_r; return v.to_i if v!=nil
    end
    cg_v2517r_ability_priority_base_speed
  rescue
    cg_v2517r_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2517r_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_R_V2517)&&ALBERT_CG::ABILITY_R_V2517.active?
      a=ALBERT_CG::ABILITY_R_V2517.forced_enemy_action(self)
      if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end
    end
    cg_v2517r_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2517r_ability_execute_action execute_action
  def execute_action
    b=@active_battler; ALBERT_CG::ABILITY_R_V2517.record_execution(b) if defined?(ALBERT_CG::ABILITY_R_V2517)&&ALBERT_CG::ABILITY_R_V2517.active?; cg_v2517r_ability_execute_action
  end
  alias cg_v2517r_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_R_V2517)&&ALBERT_CG::ABILITY_R_V2517.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_R_V2517.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_R_V2517.finish_round_assertions; end
    end
    cg_v2517r_ability_turn_end
  end
  alias cg_v2517r_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_R_V2517)&&ALBERT_CG::ABILITY_R_V2517.active?; return cg_v2517r_ability_start_party_command; end
    cg_v2517r_ability_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_R_V2517.assert_bootstrap_once
    if ALBERT_CG::ABILITY_R_V2517.finished?; ALBERT_CG::ABILITY_R_V2517.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_R_V2517.prepare_round_actions; start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2517r_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2517r_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_R_V2517)&&ALBERT_CG::ABILITY_R_V2517.active?
        ALBERT_CG::ABILITY_R_V2517::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_R_V2517.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_R_V2517::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2517r_ability_scene_map_update update
  def update; cg_v2517r_ability_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_R_V2517); ALBERT_CG::ABILITY_R_V2517.start_auto_test if ALBERT_CG::ABILITY_R_V2517.f11_trigger?; end
end
