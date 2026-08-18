# RMVX_SCRIPT_INDEX: 244
# RMVX_SCRIPT_ID: 252100002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch V v2.5.21
# RMVX_SOURCE_SHA256: 399784ebffb1dea88414fb3a0781815316d3e52621e3d7dc0a70d588b3734b3c

#==============================================================================
# ■ CG Pokemon Ability Batch V v2.5.21 - Move Property Power + Guard TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.20 Ability Batch U RPG Maker VX 實機 PASS 為唯一基底，實作第二十二批
#  8 個 Ability。本批集中處理「Critical、追加效果移除、球彈/狀態招式防護、接觸性質、
#  pulse/slicing 招式倍率」，優先沿用既有 Critical chain、Secondary + Move Property
#  Authority、Ability Modifier Authority、Before Hit 與 contact_action? 權威；不修改
#  已封版 Move 937/937、Action Priority Core 或既有 PASS Ability handlers。
#
# 【本批 Ability】
#  105 Super Luck       超幸運：Critical 階級 +1；依本專案既有 high-crit convention，
#                       額外提供 12% critical candidate，仍尊重 Battle Armor/Shell Armor
#                       與 Lucky Chant 防護。
#  125 Sheer Force      強行：有可移除追加效果的傷害招式傷害 x1.30，並把該招式的
#                       ailment/flinch/stat secondary chance 降為 0。
#  171 Bulletproof      防彈：免疫 ball/bomb 類招式。
#  178 Mega Launcher    超級發射器：pulse/aura 傷害招式 x1.50；Heal Pulse 回復量由
#                       50% 提升至 75%。
#  196 Merciless        不仁不義：攻擊 Poison / Bad Poison 目標時必定 Critical，仍尊重
#                       Critical Guard / Lucky Chant。
#  203 Long Reach       遠隔：holder 的攻擊不視為 contact，因此不觸發 Rough Skin、
#                       Iron Barbs 等 contact reaction。
#  283 Good as Gold     黃金之軀：阻擋其他 battler 對 holder 使用的 status Move。
#  292 Sharpness        鋒銳：slicing/cutting 類傷害招式 x1.50。
#
# 【主要設定項】
#  TEST_TROOP_ID=724；HANDLED_ABILITY_IDS=8。
#  Coverage：168/373 -> 176/373，pending 205 -> 197。
#  SUPER_LUCK_EXTRA_PERCENT=12；SHEER_FORCE_PERCENT=130；MEGA_LAUNCHER_PERCENT=150；
#  SHARPNESS_PERCENT=150；HEAL_PULSE_PERCENT=75。
#
# 【機制規則】
#  1. Sheer Force / Mega Launcher / Sharpness 走既有 :damage_modify attacker role，
#     Fixed Damage 不吃倍率，不重算原始傷害。
#  2. Sheer Force 的 secondary suppression 只包覆已 PASS Secondary Authority 的
#     adjust_secondary_chance；不另造 ailment/flinch/stat RNG 系統。
#  3. Bulletproof / Good as Gold 使用既有 :before_hit，於正式 skill_effect lifecycle
#     設 ctx[:cancel]=true；miss/immune/0 傷害之外不偷改目標 HP。
#  4. Long Reach 只覆蓋 Ability Core contact_action? 的最外層：holder 時回傳 false，
#     Rough Skin / Iron Barbs / Static 等既有 handler 完全不修改。
#  5. Super Luck / Merciless 只在既有 critical chain 外層提供新的 candidate；若有
#     Battle Armor/Shell Armor 或 Lucky Chant，仍先由既有 Authority 判定阻擋。
#  6. Mega Launcher 的 Heal Pulse 只在既有 cg_move_effect_apply_heal_recoil 完成後補足
#     到 MaxHP 75%，保留 Heal Block 與既有 healing lifecycle。
#  7. F11 Regression 使用 Actual Scene_Battle。Round2 以 test-only human Rough Skin
#     fixture 驗 Long Reach 不觸發 contact recoil；Round2 E3 Teleport 換入 hidden
#     Sharpness reserve，Storage 不可被當 battle reserve 消耗。
#  8. TEST Convenience 僅限 F11；正式 Release 仍須恢復 emerged、BGM/BGS、正常焦點。
#
# 【可調參數】
#  SUPER_LUCK_EXTRA_PERCENT、SHEER_FORCE_PERCENT、MEGA_LAUNCHER_PERCENT、
#  SHARPNESS_PERCENT、HEAL_PULSE_PERCENT、TEST_SPEEDS、ROUND_PLANS。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫；Ability 自動由 critical / damage / before_hit / contact /
#  secondary lifecycle 處理。開發測試：地圖按 F11，自動進 troop 724，跑三回合並輸出
#  Pokemon_Ability_V_AutoTest_v2_5_21.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：Toxic -> Good as Gold；Rock Smash + Sheer Force -> x1.30 且 DEF↓ secondary=0；
#          Aura Sphere + Mega Launcher -> x1.50。
#  Round2：Super Luck Tackle deterministic extra-crit；Poison target -> Merciless critical；
#          Long Reach Tackle human Rough Skin fixture 不受 recoil；E3 Teleport -> Sharpness reserve。
#  Round3：Aura Sphere -> Bulletproof cancel；Sharpness reserve Slash -> x1.50。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchV"] = "2.5.21"

module ALBERT_CG
  module ABILITY_V_V2521
    VERSION = "2.5.21"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 724
    VK_F11 = 0x7A

    ABILITY_SUPER_LUCK    = 105
    ABILITY_SHEER_FORCE   = 125
    ABILITY_BULLETPROOF   = 171
    ABILITY_MEGA_LAUNCHER = 178
    ABILITY_MERCILESS     = 196
    ABILITY_LONG_REACH    = 203
    ABILITY_GOOD_AS_GOLD  = 283
    ABILITY_SHARPNESS     = 292
    HANDLED_ABILITY_IDS = [105,125,171,178,196,203,283,292]

    SUPER_LUCK_EXTRA_PERCENT = 12
    SHEER_FORCE_PERCENT = 130
    MEGA_LAUNCHER_PERCENT = 150
    SHARPNESS_PERCENT = 150
    HEAL_PULSE_PERCENT = 75
    ABILITY_ROUGH_SKIN_FIXTURE = 24

    BULLETPROOF_IDENTIFIERS = [
      "aura-sphere","barrage","bullet-seed","egg-bomb","electro-ball","energy-ball",
      "focus-blast","gyro-ball","ice-ball","magnet-bomb","mist-ball","mud-bomb",
      "octazooka","pollen-puff","pyro-ball","rock-blast","rock-wrecker","searing-shot",
      "seed-bomb","shadow-ball","sludge-bomb","weather-ball","zap-cannon","syrup-bomb"
    ]
    MEGA_LAUNCHER_IDENTIFIERS = [
      "aura-sphere","dark-pulse","dragon-pulse","origin-pulse","water-pulse","terrain-pulse"
    ]
    SHARPNESS_IDENTIFIERS = [
      "aerial-ace","air-cutter","air-slash","aqua-cutter","bitter-blade","ceaseless-edge",
      "cross-poison","cut","fury-cutter","kowtow-cleave","leaf-blade","night-slash",
      "psycho-cut","razor-leaf","razor-shell","sacred-sword","secret-sword","slash",
      "solar-blade","stone-axe","x-scissor","tachyon-cutter"
    ]

    TEST_ALLIES = [
      {:dex=>25, :level=>40, :ability=>ABILITY_SUPER_LUCK,    :moves=>[92,33,150,150]},
      {:dex=>65, :level=>40, :ability=>ABILITY_SHEER_FORCE,   :moves=>[249,150,150,150]},
      {:dex=>128,:level=>40, :ability=>ABILITY_MEGA_LAUNCHER, :moves=>[396,150,396,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>60,:ability=>ABILITY_BULLETPROOF,  :moves=>[150,150,150,150]},
      {:dex=>94, :level=>60,:ability=>ABILITY_MERCILESS,    :moves=>[150,33,150,150]},
      {:dex=>91, :level=>60,:ability=>ABILITY_LONG_REACH,   :moves=>[150,33,150,150]},
      {:dex=>109,:level=>60,:ability=>ABILITY_GOOD_AS_GOLD, :moves=>[150,100,150,150]},
      {:dex=>197,:level=>60,:ability=>ABILITY_SHARPNESS,    :moves=>[150,150,163,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"GOOD_GOLD_SHEER_FORCE_MEGA_LAUNCHER",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>92,:target=>3},
          {:kind=>:move,:move_id=>249,:target=>0},
          {:kind=>:move,:move_id=>396,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"SUPER_LUCK_MERCILESS_LONG_REACH_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>33,:target=>1},
          2=>{:kind=>:move,:move_id=>33,:target=>0},
          3=>{:kind=>:move,:move_id=>100,:target=>3},
        }
      },
      {
        :name=>"BULLETPROOF_AND_SHARPNESS_RESERVE",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>396,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>163,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,260,250,240, 200,190,180,170,0],
      :r2=>[10,260,220,210, 200,250,240,100,0],
      :r3=>[10,220,210,260, 200,190,180,0,280],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M92","A2:M249","A3:M396","E0:M150","E1:M150","E2:M150","E3:M150"],
      2=>["A0:Guard","A1:M33","E1:M33","E2:M33","A2:M150","A3:M150","E0:M150","E3:M100"],
      3=>["A0:Guard","E4:M163","A3:M396","A1:M150","A2:M150","E0:M150","E1:M150","E2:M150"],
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
    def self.log_path; File.join(project_root,"Pokemon_Ability_V_AutoTest_v2_5_21.log"); end
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
      h="CG POKEMON ABILITY V MOVE PROPERTY POWER + GUARD AUTO REGRESSION v2.5.21\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; critical + secondary suppression + move property power/guard + contact lifecycle\r\n"+
        "BASELINE=v2.5.20 Ability Batch U Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_U_PASS=168 BATCH_V=8 PENDING=197\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue
    end

    def self.ability_id(b); core==nil || b==nil ? 0 : core.ability_id(b).to_i; rescue; 0; end
    def self.battler_token(b); return "nil" if b==nil; (b.actor? ? "A" : "E")+b.index.to_s; rescue; "?"; end
    def self.same_side?(a,b); a!=nil && b!=nil && a.actor? == b.actor?; rescue; false; end
    def self.opposing?(a,b); a!=nil && b!=nil && a.actor? != b.actor?; rescue; false; end
    def self.ratio(v,num,den); x=v.to_i; return x if x<=0; y=x*num.to_i/den.to_i; y=1 if y<1; y; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT) && skill!=nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.move_row(mid); master ? master.move(mid.to_i) : nil; rescue; nil; end
    def self.move_identifier(mid); r=move_row(mid); r==nil ? "" : r[0].to_s; rescue; ""; end
    def self.status_move?(skill); r=move_row(move_id(skill)); r!=nil && r[7]==:status; rescue; false; end
    def self.damaging_move_id?(mid); r=move_row(mid); r!=nil && r[3].to_i>0; rescue; false; end
    def self.fixed_damage?(ctx); ctx!=nil && ctx[:fixed_damage]==true; rescue; false; end
    def self.poisoned?(b)
      return false if b==nil || !defined?(ALBERT_CG::MOVE_EFFECT)
      return true if b.state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON)
      return true if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON) && b.state?(ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON)
      false
    rescue
      false
    end

    def self.sheer_force_move?(mid)
      r=move_row(mid); return false if r==nil || r[3].to_i<=0
      return true if r[10].to_i>0
      return true if r[20].to_i>0 || r[21].to_i>0 || r[22].to_i>0
      false
    rescue
      false
    end
    def self.bulletproof_move?(mid); BULLETPROOF_IDENTIFIERS.include?(move_identifier(mid)); rescue; false; end
    def self.mega_launcher_move?(mid); MEGA_LAUNCHER_IDENTIFIERS.include?(move_identifier(mid)); rescue; false; end
    def self.sharpness_move?(mid); SHARPNESS_IDENTIFIERS.include?(move_identifier(mid)); rescue; false; end

    def self.note_local(aid,battler,kind,data=nil)
      return true unless active?
      @ability_trigger_counts[aid]=@ability_trigger_counts[aid].to_i+1
      rec={:ability=>aid,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless k==:battler||k==:user||k==:target||k==:skill}
      @records[aid]=[] if @records[aid]==nil; @records[aid].push(rec)
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
      log("ABILITY_V_TRIGGER ability="+aid.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
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

    def self.apply_sheer_force(holder,ctx)
      return false if holder==nil || ctx[:role]!=:attacker || fixed_damage?(ctx)
      mid=ctx[:move_id].to_i; return false unless sheer_force_move?(mid)
      before=ctx[:damage].to_i; return false if before<=0
      after=ratio(before,SHEER_FORCE_PERCENT,100); ctx[:damage]=after
      formal_note(ABILITY_SHEER_FORCE,holder,:sheer_force,{:move_id=>mid,:before=>before,:after=>after})
      true
    end

    def self.apply_mega_launcher(holder,ctx)
      return false if holder==nil || ctx[:role]!=:attacker || fixed_damage?(ctx)
      mid=ctx[:move_id].to_i; return false unless mega_launcher_move?(mid)
      before=ctx[:damage].to_i; return false if before<=0
      after=ratio(before,MEGA_LAUNCHER_PERCENT,100); ctx[:damage]=after
      formal_note(ABILITY_MEGA_LAUNCHER,holder,:mega_launcher,{:move_id=>mid,:before=>before,:after=>after})
      true
    end

    def self.apply_sharpness(holder,ctx)
      return false if holder==nil || ctx[:role]!=:attacker || fixed_damage?(ctx)
      mid=ctx[:move_id].to_i; return false unless sharpness_move?(mid)
      before=ctx[:damage].to_i; return false if before<=0
      after=ratio(before,SHARPNESS_PERCENT,100); ctx[:damage]=after
      formal_note(ABILITY_SHARPNESS,holder,:sharpness,{:move_id=>mid,:before=>before,:after=>after})
      true
    end

    def self.apply_bulletproof(holder,ctx)
      return false if holder==nil || ctx[:user]==nil || !opposing?(holder,ctx[:user])
      mid=ctx[:move_id].to_i; return false unless bulletproof_move?(mid)
      ctx[:cancel]=true; ctx[:hp_damage]=0
      formal_note(ABILITY_BULLETPROOF,holder,:bulletproof,{:move_id=>mid})
      true
    end

    def self.apply_good_as_gold(holder,ctx)
      return false if holder==nil || ctx[:user]==nil || holder==ctx[:user]
      return false unless status_move?(ctx[:skill])
      ctx[:cancel]=true; ctx[:hp_damage]=0
      formal_note(ABILITY_GOOD_AS_GOLD,holder,:good_as_gold,{:move_id=>ctx[:move_id].to_i})
      true
    end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_SHEER_FORCE,:damage_modify,self,:apply_sheer_force)
      core.register(ABILITY_BULLETPROOF,:before_hit,self,:apply_bulletproof)
      core.register(ABILITY_MEGA_LAUNCHER,:damage_modify,self,:apply_mega_launcher)
      core.register(ABILITY_GOOD_AS_GOLD,:before_hit,self,:apply_good_as_gold)
      core.register(ABILITY_SHARPNESS,:damage_modify,self,:apply_sharpness)
      true
    end

    def self.critical_blocked?(target)
      if defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256) && ALBERT_CG::ABILITY_STAT_GUARD_V256.respond_to?(:critical_guard?)
        return true if ALBERT_CG::ABILITY_STAT_GUARD_V256.critical_guard?(target)
      end
      if defined?(ALBERT_CG::FIELD_V233) && ALBERT_CG::FIELD_V233.respond_to?(:side_effect?) && ALBERT_CG::FIELD_V233.respond_to?(:side_key)
        return true if ALBERT_CG::FIELD_V233.side_effect?(ALBERT_CG::FIELD_V233.side_key(target),:lucky_chant)
      end
      false
    rescue
      false
    end

    def self.can_critical?(obj)
      return true if obj==nil
      return false if obj.respond_to?(:cg_pokemon_can_critical?) && !obj.cg_pokemon_can_critical?
      true
    rescue
      true
    end

    def self.super_luck_candidate?(target,user,obj)
      return false if user==nil || ability_id(user)!=ABILITY_SUPER_LUCK || !can_critical?(obj)
      return false if critical_blocked?(target)
      forced=active? && current_round==2 && user.actor? && user.index.to_i==1 && move_id(obj)==33
      return false unless forced || rand(100)<SUPER_LUCK_EXTRA_PERCENT
      formal_note(ABILITY_SUPER_LUCK,user,:super_luck_crit,{:move_id=>move_id(obj),:extra_percent=>SUPER_LUCK_EXTRA_PERCENT})
      true
    rescue
      false
    end

    def self.merciless_candidate?(target,user,obj)
      return false if user==nil || ability_id(user)!=ABILITY_MERCILESS || !can_critical?(obj)
      return false unless poisoned?(target)
      return false if critical_blocked?(target)
      formal_note(ABILITY_MERCILESS,user,:merciless_crit,{:move_id=>move_id(obj)})
      true
    rescue
      false
    end

    def self.long_reach_contact?(user,lower_value)
      return lower_value unless user!=nil && ability_id(user)==ABILITY_LONG_REACH
      if lower_value==true
        formal_note(ABILITY_LONG_REACH,user,:long_reach,{:move_id=>(core ? core.current_move_id(user) : 0)})
      end
      false
    rescue
      lower_value
    end

    def self.note_sheer_secondary_suppressed(user,mid,base,kind)
      return unless user!=nil && ability_id(user)==ABILITY_SHEER_FORCE && sheer_force_move?(mid) && base.to_i>0
      formal_note(ABILITY_SHEER_FORCE,user,:sheer_force_secondary,{:move_id=>mid.to_i,:secondary_kind=>kind.to_s,:before=>base.to_i,:after=>0})
    rescue
    end

    def self.mega_launcher_heal_pulse_extra(target,user,mid,before_hp)
      return 0 if target==nil || user==nil || ability_id(user)!=ABILITY_MEGA_LAUNCHER || mid.to_i!=505
      return 0 if defined?(ALBERT_CG::MOVE_EFFECT) && target.state?(ALBERT_CG::MOVE_EFFECT::STATE_HEAL_BLOCK)
      desired=[target.maxhp.to_i*HEAL_PULSE_PERCENT/100,target.maxhp.to_i-before_hp.to_i].min
      actual=target.hp.to_i-before_hp.to_i
      extra=desired-actual; return 0 if extra<=0
      target.hp += extra
      target.hp_damage = -(actual+extra) if target.respond_to?(:hp_damage=)
      formal_note(ABILITY_MEGA_LAUNCHER,user,:mega_launcher_heal,{:move_id=>mid.to_i,:before=>before_hp.to_i,:after=>target.hp.to_i,:extra=>extra})
      extra
    rescue
      0
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
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability V v2.5.21 AutoRegression",ms)
    end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); else; a.clear; end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c); end
    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||TEST_SPEEDS[:r1]||[]
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_v,vals[i]) if b}
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
      clear_round_states; apply_test_speeds
      a=test_allies; e=all_enemies; h=a[0]
      h.instance_variable_set(:@cg_master_ability_id,0) if h
      if current_round==1
        @r1_good_gold_state_before=e[3] ? e[3].states.clone : []
        @r1_sheer_def_before=e[0]&&e[0].respond_to?(:cg_stat_stage) ? e[0].cg_stat_stage(:def).to_i : 0
      elsif current_round==2
        if a[1]
          a[1].add_state(ALBERT_CG::MOVE_EFFECT::STATE_POISON)
          @r2_poison_fixture=poisoned?(a[1])
        end
        h.instance_variable_set(:@cg_master_ability_id,ABILITY_ROUGH_SKIN_FIXTURE) if h
        @r2_storage_before=storage_size
        @r2_long_reach_hp_before=0
      elsif current_round==3
        h.instance_variable_set(:@cg_master_ability_id,0) if h
        @r3_bullet_hp_before=e[0] ? e[0].hp.to_i : 0
      end
    end
    def self.prepare_round_actions
      p=current_plan; return false if p==nil; prepare_round_preconditions; @actual=[]; log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s)
      test_allies.each_with_index do |b,i|; next if b==nil||b.hp.to_i<=0; ac=make_action(b,p[:allies][i]); if b.respond_to?(:cg_round_actions); b.cg_round_actions.clear; b.cg_round_actions.push(ac); end; b.cg_assign_action(ac) if b.respond_to?(:cg_assign_action); b.instance_variable_set(:@action,ac) unless b.respond_to?(:cg_assign_action); end; true
    end
    def self.record_execution(b)
      return unless active?&&b
      if current_round==2 && !b.actor? && b.index.to_i==2
        @r2_long_reach_hp_before=b.hp.to_i
      end
      a=b.action; pre=b.actor? ? "A" : "E"; tok=if a&&a.guard?; pre+b.index.to_s+":Guard" elsif a&&a.skill?; pre+b.index.to_s+":M"+ALBERT_CG::MOVE_EFFECT.move_id(a.skill).to_i.to_s else; pre+b.index.to_s+":Other" end; @actual.push(tok); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    rescue
    end
    def self.records_for(aid,kind=nil); a=@records[aid]||[]; a.select{|r|kind==nil||r[:kind]==kind}; end
    def self.record_ratio_ok?(aid,kind,num,den); records_for(aid,kind).any?{|r|r[:before].to_i>0 && r[:after].to_i==ratio(r[:before],num,den)}; end

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      tid=($game_troop&&$game_troop.troop) ? $game_troop.troop.id.to_i : 0
      assert_true("Ability Catalog count=373",core&&core.catalog_count==373,"actual="+(core ? core.catalog_count.to_s : "nil"))
      assert_true("Ability Batch V defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability V test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability V ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability V starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden},"")
      assert_true("Ability V starts with 1 hidden Sharpness reserve",all_enemies[4]&&all_enemies[4].hidden,"E4_hidden="+(all_enemies[4] ? all_enemies[4].hidden.to_s : "nil"))
    end

    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]; order=@actual==exp
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",order,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        good=e[3] && !poisoned?(e[3]) && !records_for(ABILITY_GOOD_AS_GOLD,:good_as_gold).empty?
        @guard_checks+=1 if good; assert_true("Good as Gold blocks Toxic status Move",good,(records_for(ABILITY_GOOD_AS_GOLD,:good_as_gold)[-1]||{}).inspect)
        sheer=record_ratio_ok?(ABILITY_SHEER_FORCE,:sheer_force,SHEER_FORCE_PERCENT,100)
        @damage_checks+=1 if sheer; assert_true("Sheer Force boosts eligible damage x1.30",sheer,(records_for(ABILITY_SHEER_FORCE,:sheer_force)[-1]||{}).inspect)
        secondary=!records_for(ABILITY_SHEER_FORCE,:sheer_force_secondary).empty? && e[0] && e[0].respond_to?(:cg_stat_stage) && e[0].cg_stat_stage(:def).to_i==@r1_sheer_def_before.to_i
        @secondary_checks+=1 if secondary; assert_true("Sheer Force suppresses Rock Smash DEF-drop secondary",secondary,"def_before="+@r1_sheer_def_before.to_s+" def_after="+(e[0] ? e[0].cg_stat_stage(:def).to_s : "nil")+" record="+(records_for(ABILITY_SHEER_FORCE,:sheer_force_secondary)[-1]||{}).inspect)
        mega=record_ratio_ok?(ABILITY_MEGA_LAUNCHER,:mega_launcher,MEGA_LAUNCHER_PERCENT,100)
        @damage_checks+=1 if mega; assert_true("Mega Launcher boosts Aura Sphere damage x1.50",mega,(records_for(ABILITY_MEGA_LAUNCHER,:mega_launcher)[-1]||{}).inspect)
      elsif r==2
        sl=!records_for(ABILITY_SUPER_LUCK,:super_luck_crit).empty?; @critical_checks+=1 if sl; assert_true("Super Luck adds a deterministic critical candidate",sl,(records_for(ABILITY_SUPER_LUCK,:super_luck_crit)[-1]||{}).inspect)
        me=@r2_poison_fixture && !records_for(ABILITY_MERCILESS,:merciless_crit).empty?; @critical_checks+=1 if me; assert_true("Merciless guarantees critical against poisoned target",me,(records_for(ABILITY_MERCILESS,:merciless_crit)[-1]||{}).inspect)
        lr=!records_for(ABILITY_LONG_REACH,:long_reach).empty? && e[2] && @r2_long_reach_hp_before.to_i>0 && e[2].hp.to_i==@r2_long_reach_hp_before.to_i
        @contact_checks+=1 if lr; assert_true("Long Reach suppresses contact recoil against Rough Skin fixture",lr,"hp_before="+@r2_long_reach_hp_before.to_s+" hp_after="+(e[2] ? e[2].hp.to_i.to_s : "nil")+" record="+(records_for(ABILITY_LONG_REACH,:long_reach)[-1]||{}).inspect)
        switched=e[3]&&e[4]&&e[3].hidden&&!e[4].hidden; @lifecycle_checks+=1 if switched; assert_true("Teleport deploys hidden Sharpness reserve",switched,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        storage=storage_size==@r2_storage_before.to_i; @lifecycle_checks+=1 if storage; assert_true("Sharpness reserve switch does not consume Storage Pokemon",storage,"before="+@r2_storage_before.to_s+" after="+storage_size.to_s)
      elsif r==3
        bullet=!records_for(ABILITY_BULLETPROOF,:bulletproof).empty? && e[0] && e[0].hp.to_i==@r3_bullet_hp_before.to_i
        @guard_checks+=1 if bullet; assert_true("Bulletproof cancels Aura Sphere",bullet,"hp_before="+@r3_bullet_hp_before.to_s+" hp_after="+(e[0] ? e[0].hp.to_i.to_s : "nil")+" record="+(records_for(ABILITY_BULLETPROOF,:bulletproof)[-1]||{}).inspect)
        sharp=record_ratio_ok?(ABILITY_SHARPNESS,:sharpness,SHARPNESS_PERCENT,100)
        @damage_checks+=1 if sharp; assert_true("Sharpness boosts Slash damage x1.50",sharp,(records_for(ABILITY_SHARPNESS,:sharpness)[-1]||{}).inspect)
        stable=e[4]&&!e[4].hidden&&e[4].hp.to_i>0; assert_true("Sharpness reserve remains active through Round3",stable,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" hp="+(e[4] ? e[4].hp.to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end
    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides
      (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_v,nil) if b}
      h=test_allies[0]; h.instance_variable_set(:@cg_master_ability_id,0) if h
    end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"; log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_v="+ability_covered_count.to_s+"/8 critical_checks="+@critical_checks.to_i.to_s+" damage_checks="+@damage_checks.to_i.to_s+" guard_checks="+@guard_checks.to_i.to_s+" secondary_checks="+@secondary_checks.to_i.to_s+" contact_checks="+@contact_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=197")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @critical_checks=0; @damage_checks=0; @guard_checks=0; @secondary_checks=0; @contact_checks=0; @lifecycle_checks=0; @r1_sheer_def_before=0; @r2_poison_fixture=false; @r2_storage_before=0; @r2_long_reach_hp_before=0; @r3_bullet_hp_before=0
    end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; ALBERT_CG::UNIQUE_I_V242.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_I_V242)&&ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes); @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_V_v2.5.21") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

ALBERT_CG::ABILITY_V_V2521.register_handlers if defined?(ALBERT_CG::ABILITY_V250)
if defined?(ALBERT_CG::ABILITY_U_V2520)
  module ALBERT_CG; module ABILITY_U_V2520; def self.f11_trigger?; false; end; end; end
end

#==============================================================================
# ■ Formal Sheer Force secondary suppression extension
#==============================================================================
if defined?(ALBERT_CG::ABILITY_SECONDARY_V2510)
  module ALBERT_CG
    module ABILITY_SECONDARY_V2510
      class << self
        alias cg_v2521v_adjust_secondary_chance adjust_secondary_chance
        def adjust_secondary_chance(user,move_id,base,kind)
          if defined?(ALBERT_CG::ABILITY_V_V2521) && user!=nil &&
             ALBERT_CG::ABILITY_V_V2521.ability_id(user)==ALBERT_CG::ABILITY_V_V2521::ABILITY_SHEER_FORCE &&
             ALBERT_CG::ABILITY_V_V2521.sheer_force_move?(move_id) && base.to_i>0
            ALBERT_CG::ABILITY_V_V2521.note_sheer_secondary_suppressed(user,move_id,base,kind)
            return 0
          end
          cg_v2521v_adjust_secondary_chance(user,move_id,base,kind)
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal Critical extension: Super Luck / Merciless
#==============================================================================
class Game_Battler
  alias cg_v2521v_critical cg_pokemon_critical?
  def cg_pokemon_critical?(user,obj=nil)
    if defined?(ALBERT_CG::ABILITY_V_V2521)
      return true if ALBERT_CG::ABILITY_V_V2521.merciless_candidate?(self,user,obj)
      return true if ALBERT_CG::ABILITY_V_V2521.super_luck_candidate?(self,user,obj)
    end
    cg_v2521v_critical(user,obj)
  end
end

#==============================================================================
# ■ Formal Long Reach contact extension
#==============================================================================
if defined?(ALBERT_CG::ABILITY_V250)
  module ALBERT_CG
    module ABILITY_V250
      class << self
        alias cg_v2521v_contact_action contact_action?
        def contact_action?(user)
          lower=cg_v2521v_contact_action(user)
          return ALBERT_CG::ABILITY_V_V2521.long_reach_contact?(user,lower) if defined?(ALBERT_CG::ABILITY_V_V2521)
          lower
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal Mega Launcher Heal Pulse extension
#==============================================================================
class Game_Battler
  alias cg_v2521v_heal_recoil cg_move_effect_apply_heal_recoil
  def cg_move_effect_apply_heal_recoil(user,move_id,damage_done)
    before=hp.to_i
    r=cg_v2521v_heal_recoil(user,move_id,damage_done)
    ALBERT_CG::ABILITY_V_V2521.mega_launcher_heal_pulse_extra(self,user,move_id,before) if defined?(ALBERT_CG::ABILITY_V_V2521)
    r
  end
end

#==============================================================================
# ■ TEST-only deterministic Scene_Battle harness
#==============================================================================
class Game_Battler
  alias cg_v2521v_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil); return 100 if defined?(ALBERT_CG::ABILITY_V_V2521)&&ALBERT_CG::ABILITY_V_V2521.active?; cg_v2521v_ability_calc_hit(user,obj); end
  alias cg_v2521v_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil); return 0 if defined?(ALBERT_CG::ABILITY_V_V2521)&&ALBERT_CG::ABILITY_V_V2521.active?; cg_v2521v_ability_calc_eva(user,obj); end
  alias cg_v2521v_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_V_V2521)&&ALBERT_CG::ABILITY_V_V2521.active?
      v=@cg_priority_test_speed_override_v; return v.to_i if v!=nil
    end
    cg_v2521v_ability_priority_base_speed
  rescue
    cg_v2521v_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2521v_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_V_V2521)&&ALBERT_CG::ABILITY_V_V2521.active?
      a=ALBERT_CG::ABILITY_V_V2521.forced_enemy_action(self)
      if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end
    end
    cg_v2521v_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2521v_ability_execute_action execute_action
  def execute_action
    b=@active_battler; ALBERT_CG::ABILITY_V_V2521.record_execution(b) if defined?(ALBERT_CG::ABILITY_V_V2521)&&ALBERT_CG::ABILITY_V_V2521.active?; cg_v2521v_ability_execute_action
  end
  alias cg_v2521v_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_V_V2521)&&ALBERT_CG::ABILITY_V_V2521.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_V_V2521.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_V_V2521.finish_round_assertions; end
    end
    cg_v2521v_ability_turn_end
  end
  alias cg_v2521v_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_V_V2521)&&ALBERT_CG::ABILITY_V_V2521.active?; return cg_v2521v_ability_start_party_command; end
    cg_v2521v_ability_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_V_V2521.assert_bootstrap_once
    if ALBERT_CG::ABILITY_V_V2521.finished?; ALBERT_CG::ABILITY_V_V2521.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_V_V2521.prepare_round_actions; start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2521v_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2521v_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_V_V2521)&&ALBERT_CG::ABILITY_V_V2521.active?
        ALBERT_CG::ABILITY_V_V2521::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_V_V2521.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_V_V2521::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2521v_ability_scene_map_update update
  def update; cg_v2521v_ability_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_V_V2521); ALBERT_CG::ABILITY_V_V2521.start_auto_test if ALBERT_CG::ABILITY_V_V2521.f11_trigger?; end
end
