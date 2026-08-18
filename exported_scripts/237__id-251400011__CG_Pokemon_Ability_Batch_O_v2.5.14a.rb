# RMVX_SCRIPT_INDEX: 237
# RMVX_SCRIPT_ID: 251400011
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch O v2.5.14a
# RMVX_SOURCE_SHA256: dfc792292bc15475cb39d32b0f687e7e5ee52ea2e3f563293165f4f9f21e2e7f

#==============================================================================
# ■ CG Pokemon Ability Batch O v2.5.14a - Damage Shields + Type Power
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.13 Ability Batch N RPG Maker VX 實機 PASS 基底上，正式實作第十五批
#  8 個 Ability。本批集中處理「最終直接傷害減免、超有效傷害修正、聲音招式攻防、
#  指定屬性輸出強化」，全部沿用已 PASS 的 :damage_modify Authority，不另造第二套
#  傷害公式，也不修改已封版 Move 937/937 Runtime。
#
# 【本批 Ability】
#  218 Fluffy         毛茸茸：Contact damage x0.5；Fire damage x2.0。
#  231 Shadow Shield  幻影防守：滿 HP 時受到直接傷害 x0.5。
#  232 Prism Armor    稜鏡裝甲：受到超有效直接傷害 x0.75。
#  233 Neuroforce     腦核之力：自身造成超有效直接傷害 x1.25。
#  244 Punk Rock      龐克搖滾：Sound Move 輸出 x1.3；受到 Sound Move 傷害 x0.5。
#  246 Ice Scales     冰鱗粉：受到 Special Move 直接傷害 x0.5。
#  262 Transistor     電晶體：Electric Move 輸出 x1.3（採現代主系列倍率）。
#  263 Dragon's Maw   龍顎：Dragon Move 輸出 x1.5。
#
# 【主要設定項】
#  TEST_TROOP_ID = 717
#  HANDLED_ABILITY_IDS = 8
#  Coverage：112/373 -> 120/373，pending 261 -> 253。
#
# 【機制規則】
#  1. 所有倍率只作用於 @hp_damage > 0 的直接傷害，Fixed Damage 一律不吃本批倍率。
#  2. Fluffy 依既有 Ability Core contact_action? 判定 Contact，不自行維護第二份
#     Contact move 表；Fire 判定直接使用 Pokemon Combat type ID。
#  3. Shadow Shield 只在 holder 進入本次傷害計算時仍為滿 HP 才生效。
#  4. Prism Armor / Neuroforce 以既有 cg_pokemon_type_rate_percent 判定 type_rate>100，
#     不自行重算屬性相剋。
#  5. Punk Rock 的 Sound Move 判定直接沿用 v2.5.10a SecondaryMove Authority 的
#     sound_move?，避免 Soundproof 與 Punk Rock 各自養一張不同聲音招式表。
#  6. Ice Scales 只處理 damage_class=:special；物理／固定傷害不減免。
#  7. Transistor 採現代倍率 130%；Dragon's Maw 採 150%。
#  8. 有效 Ability 仍由 Ability Core ability_id / cg_master_ability_id 取得，尊重既有
#     Battle-only Ability Override / Suppression。
#  9. Shadow Shield / Prism Armor 在未來實作 Mold Breaker / Turboblaze / Teravolt 時，
#     必須保留其主系列「不可被這類 Ability bypass」的特殊性；本批不提前改寫尚未
#     實作的 bypass authority。
# 10. Regression 只固定命中、行動順序與 reserve；正式玩家 RNG 不改。
# 11. TEST Convenience 只限 F11。正式 Release 必須恢復 emerged 訊息、BGM/BGS
#     與正常 VX 焦點行為。
#
# 【可調參數】
#  FLUFFY_CONTACT_PERCENT=50 / FLUFFY_FIRE_PERCENT=200 /
#  SHADOW_SHIELD_PERCENT=50 / PRISM_ARMOR_PERCENT=75 /
#  NEUROFORCE_PERCENT=125 / PUNK_ROCK_ATTACK_PERCENT=130 /
#  PUNK_ROCK_DEFENSE_PERCENT=50 / ICE_SCALES_PERCENT=50 /
#  TRANSISTOR_PERCENT=130 / DRAGONS_MAW_PERCENT=150。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫。開發測試：地圖按 F11，自動進 Actual Scene_Battle，
#  跑完三回合並輸出 Pokemon_Ability_O_AutoTest_v2_5_14a.log 與
#  CG_AutoRegression_LATEST.log。
#
# 【v2.5.14a Regression 修正】
#  v2.5.14 實機證明 Shadow Shield 已在全體巨聲第一次命中時正確由 37→18，
#  但舊 ASSERT 錯把驗證來源限定成稍後的 Dragon Breath。巨聲先讓目標離開滿血，
#  因此 Dragon Breath 不應再次觸發 Shadow Shield。本版只修正 TEST expected source，
#  Formal damage handler、倍率與條件判定完全不變。
#
# 【實際範例】
#  Water Gun (super-effective) -> Prism Armor + Neuroforce 同一 hit 分別生效；
#  Hyper Voice -> Ice Scales / Punk Rock；Tackle / Ember -> Fluffy；
#  Thunderbolt -> Transistor；Dragon Breath -> Dragon's Maw + Shadow Shield。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchO"] = "2.5.14a"

module ALBERT_CG
  module ABILITY_O_V2514
    VERSION = "2.5.14a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 717
    VK_F11 = 0x7A

    ABILITY_FLUFFY        = 218
    ABILITY_SHADOW_SHIELD = 231
    ABILITY_PRISM_ARMOR   = 232
    ABILITY_NEUROFORCE    = 233
    ABILITY_PUNK_ROCK     = 244
    ABILITY_ICE_SCALES    = 246
    ABILITY_TRANSISTOR    = 262
    ABILITY_DRAGONS_MAW   = 263

    HANDLED_ABILITY_IDS = [218,231,232,233,244,246,262,263]

    FLUFFY_CONTACT_PERCENT = 50
    FLUFFY_FIRE_PERCENT = 200
    SHADOW_SHIELD_PERCENT = 50
    PRISM_ARMOR_PERCENT = 75
    NEUROFORCE_PERCENT = 125
    PUNK_ROCK_ATTACK_PERCENT = 130
    PUNK_ROCK_DEFENSE_PERCENT = 50
    ICE_SCALES_PERCENT = 50
    TRANSISTOR_PERCENT = 130
    DRAGONS_MAW_PERCENT = 150

    TEST_ALLIES = [
      {:dex=>121,:level=>40,:ability=>ABILITY_NEUROFORCE, :moves=>[55,33,150,150]},
      {:dex=>295,:level=>40,:ability=>ABILITY_PUNK_ROCK,  :moves=>[304,52,150,150]},
      {:dex=>373,:level=>40,:ability=>ABILITY_DRAGONS_MAW,:moves=>[225,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>197,:level=>40,:ability=>ABILITY_SHADOW_SHIELD,:moves=>[304,150,150,150]},
      {:dex=>6,  :level=>40,:ability=>ABILITY_PRISM_ARMOR,  :moves=>[150,150,150,150]},
      {:dex=>143,:level=>40,:ability=>ABILITY_FLUFFY,       :moves=>[150,150,150,150]},
      {:dex=>131,:level=>40,:ability=>ABILITY_ICE_SCALES,   :moves=>[150,100,150,150]},
      {:dex=>125,:level=>40,:ability=>ABILITY_TRANSISTOR,   :moves=>[150,150,85,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"SUPER_EFFECTIVE_SOUND_DRAGON_SHIELDS",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>55,:target=>1},
          {:kind=>:move,:move_id=>304,:target=>3},
          {:kind=>:move,:move_id=>225,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>304,:target=>2},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"FLUFFY_CONTACT_FIRE_AND_TRANSISTOR_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>2},
          {:kind=>:move,:move_id=>52,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>100,:target=>0},
        }
      },
      {
        :name=>"TRANSISTOR_ELECTRIC_DAMAGE_STABILITY",
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
          4=>{:kind=>:move,:move_id=>85,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,300,290,280, 270,180,170,160,0],
      :r2=>[10,300,290,280, 180,170,160,100,0],
      :r3=>[10,180,170,160, 150,140,130,0,300],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M55","A2:M304","A3:M225","E0:M304","E1:M150","E2:M150","E3:M150"],
      2=>["A0:Guard","A1:M33","A2:M52","A3:M150","E0:M150","E1:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","E4:M85","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.master; return defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.core; return defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.active?; return @active == true; end
    def self.current_round; return @round_index.to_i + 1; end
    def self.current_plan; return ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; return @round_index.to_i >= ROUND_PLANS.size; end
    def self.test_allies; return $game_party == nil ? [] : $game_party.members; end
    def self.all_enemies; return $game_troop == nil ? [] : $game_troop.members; end
    def self.project_root; return Dir.pwd; rescue; return "."; end
    def self.log_path; return File.join(project_root,"Pokemon_Ability_O_AutoTest_v2_5_14a.log"); end
    def self.latest_log_path; return File.join(project_root,"CG_AutoRegression_LATEST.log"); end

    def self.write_line(path,text,mode="ab")
      File.open(path,mode) { |f| f.write(text.to_s + "\r\n") }
      return true
    rescue
      return false
    end

    def self.log(text)
      write_line(log_path,text.to_s)
      write_line(latest_log_path,text.to_s)
      if defined?(ALBERT_CG::PMD_INIT_TRACE) && ALBERT_CG::PMD_INIT_TRACE.respond_to?(:log)
        if text.to_s.index("ASSERT ") == 0 || text.to_s.index("ABILITY_") == 0 ||
           text.to_s.index("ROUND ") == 0 || text.to_s.index("RESULT=") == 0 ||
           text.to_s.index("SUMMARY ") == 0
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_O_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end

    def self.reset_log
      header = "CG POKEMON ABILITY O DAMAGE SHIELDS + TYPE POWER AUTO REGRESSION v2.5.14a\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; final damage shields + super-effective modifiers + Sound/Electric/Dragon power\r\n" +
        "BASELINE=v2.5.13 Ability Batch N Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_TO_N_PASS=112 BATCH_O=8 PENDING=253\r\n" +
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n" +
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n" +
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb") { |f| f.write(header) }
      File.open(latest_log_path,"wb") { |f| f.write(header) }
    rescue
    end

    def self.key_down?(code)
      return false if KEY_API == nil
      return (KEY_API.call(code) & 0x8000) != 0
    rescue
      return false
    end

    def self.f11_trigger?
      down = key_down?(VK_F11)
      trigger = down && @f11_down != true
      @f11_down = down
      return trigger
    rescue
      return false
    end

    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS " + label.to_s + (detail == nil ? "" : " " + detail.to_s))
      else
        text = label.to_s + (detail == nil ? "" : " " + detail.to_s)
        @failures.push(text)
        log("ASSERT FAIL " + text)
      end
      return condition
    end

    def self.type_id(symbol)
      return 0 unless defined?(ALBERT_CG::POKEMON_COMBAT)
      table = ALBERT_CG::POKEMON_COMBAT::TYPE_IDS
      return table[symbol].to_i if table != nil && table.has_key?(symbol)
      return 0
    rescue
      return 0
    end

    def self.special_move?(ctx)
      skill = ctx[:skill]
      return skill.cg_pokemon_damage_class == :special if skill != nil && skill.respond_to?(:cg_pokemon_damage_class)
      return false
    rescue
      return false
    end

    def self.sound_move?(move_id)
      if defined?(ALBERT_CG::ABILITY_SECONDARY_V2510) && ALBERT_CG::ABILITY_SECONDARY_V2510.respond_to?(:sound_move?)
        return ALBERT_CG::ABILITY_SECONDARY_V2510.sound_move?(move_id.to_i)
      end
      return false
    rescue
      return false
    end

    def self.contact_move?(ctx)
      c = core
      return false if c == nil
      return c.contact_action?(ctx[:user])
    rescue
      return false
    end

    def self.type_rate_for(ctx)
      return ctx[:type_rate].to_i if ctx.has_key?(:type_rate) && ctx[:type_rate].to_i > 0
      target = ctx[:target]
      return 100 if target == nil || ctx[:type_id].to_i <= 0
      return target.cg_pokemon_type_rate_percent(ctx[:type_id].to_i).to_i if target.respond_to?(:cg_pokemon_type_rate_percent)
      return 100
    rescue
      return 100
    end

    def self.note_damage(aid,battler,kind,before,after,ctx,extra=nil)
      if active?
        @ability_trigger_counts[aid] = @ability_trigger_counts[aid].to_i + 1
        rec = {:ability=>aid,:kind=>kind,:before=>before.to_i,:after=>after.to_i,
          :move_id=>ctx[:move_id].to_i,:type_id=>ctx[:type_id].to_i,:role=>ctx[:role],
          :type_rate=>type_rate_for(ctx)}
        if extra != nil
          extra.each { |k,v| rec[k] = v }
        end
        @damage_records[[aid,kind]] = rec
        log("ABILITY_O_DAMAGE ability=" + aid.to_s + " battler=" + battler.name.to_s +
          " kind=" + kind.to_s + " before=" + before.to_i.to_s + " after=" + after.to_i.to_s +
          " move=" + ctx[:move_id].to_i.to_s + " type_id=" + ctx[:type_id].to_i.to_s +
          " role=" + ctx[:role].to_s + " type_rate=" + rec[:type_rate].to_i.to_s)
      end
    rescue
    end

    def self.apply_damage_percent(aid,battler,ctx,kind,percent,extra=nil)
      before = ctx[:damage].to_i
      return false if before <= 0 || ctx[:fixed_damage] == true
      after = [before * percent.to_i / 100,1].max
      ctx[:damage] = after
      note_damage(aid,battler,kind,before,after,ctx,extra)
      return true
    end

    def self.apply_fluffy(battler,ctx)
      return false unless ctx[:role] == :defender
      applied = false
      if contact_move?(ctx)
        before = ctx[:damage].to_i
        return false if before <= 0 || ctx[:fixed_damage] == true
        after = [before * FLUFFY_CONTACT_PERCENT / 100,1].max
        ctx[:damage] = after
        note_damage(ABILITY_FLUFFY,battler,:fluffy_contact,before,after,ctx)
        applied = true
      end
      if ctx[:type_id].to_i == type_id(:fire)
        before = ctx[:damage].to_i
        return applied if before <= 0 || ctx[:fixed_damage] == true
        after = [before * FLUFFY_FIRE_PERCENT / 100,1].max
        ctx[:damage] = after
        note_damage(ABILITY_FLUFFY,battler,:fluffy_fire,before,after,ctx)
        applied = true
      end
      return applied
    end

    def self.apply_shadow_shield(battler,ctx)
      return false unless ctx[:role] == :defender && battler != nil
      return false unless battler.maxhp.to_i > 0 && battler.hp.to_i >= battler.maxhp.to_i
      return apply_damage_percent(ABILITY_SHADOW_SHIELD,battler,ctx,:shadow_shield,SHADOW_SHIELD_PERCENT,
        {:full_hp=>true})
    end

    def self.apply_prism_armor(battler,ctx)
      return false unless ctx[:role] == :defender && type_rate_for(ctx) > 100
      return apply_damage_percent(ABILITY_PRISM_ARMOR,battler,ctx,:prism_armor,PRISM_ARMOR_PERCENT)
    end

    def self.apply_neuroforce(battler,ctx)
      return false unless ctx[:role] == :attacker && type_rate_for(ctx) > 100
      return apply_damage_percent(ABILITY_NEUROFORCE,battler,ctx,:neuroforce,NEUROFORCE_PERCENT)
    end

    def self.apply_punk_rock(battler,ctx)
      return false unless sound_move?(ctx[:move_id])
      if ctx[:role] == :attacker
        return apply_damage_percent(ABILITY_PUNK_ROCK,battler,ctx,:punk_rock_attack,PUNK_ROCK_ATTACK_PERCENT)
      elsif ctx[:role] == :defender
        return apply_damage_percent(ABILITY_PUNK_ROCK,battler,ctx,:punk_rock_defense,PUNK_ROCK_DEFENSE_PERCENT)
      end
      return false
    end

    def self.apply_ice_scales(battler,ctx)
      return false unless ctx[:role] == :defender && special_move?(ctx)
      return apply_damage_percent(ABILITY_ICE_SCALES,battler,ctx,:ice_scales,ICE_SCALES_PERCENT)
    end

    def self.apply_transistor(battler,ctx)
      return false unless ctx[:role] == :attacker && ctx[:type_id].to_i == type_id(:electric)
      return apply_damage_percent(ABILITY_TRANSISTOR,battler,ctx,:transistor,TRANSISTOR_PERCENT)
    end

    def self.apply_dragons_maw(battler,ctx)
      return false unless ctx[:role] == :attacker && ctx[:type_id].to_i == type_id(:dragon)
      return apply_damage_percent(ABILITY_DRAGONS_MAW,battler,ctx,:dragons_maw,DRAGONS_MAW_PERCENT)
    end

    def self.register_handlers
      return false unless defined?(ALBERT_CG::ABILITY_V250)
      c = ALBERT_CG::ABILITY_V250
      c.register(ABILITY_FLUFFY,:damage_modify,self,:apply_fluffy)
      c.register(ABILITY_SHADOW_SHIELD,:damage_modify,self,:apply_shadow_shield)
      c.register(ABILITY_PRISM_ARMOR,:damage_modify,self,:apply_prism_armor)
      c.register(ABILITY_NEUROFORCE,:damage_modify,self,:apply_neuroforce)
      c.register(ABILITY_PUNK_ROCK,:damage_modify,self,:apply_punk_rock)
      c.register(ABILITY_ICE_SCALES,:damage_modify,self,:apply_ice_scales)
      c.register(ABILITY_TRANSISTOR,:damage_modify,self,:apply_transistor)
      c.register(ABILITY_DRAGONS_MAW,:damage_modify,self,:apply_dragons_maw)
      return true
    end

    def self.configure_actor(cfg)
      actor = $game_actors[master.actor_id_for_dex(cfg[:dex])]
      return if actor == nil
      master.configure_actor(actor,cfg)
      actor.recover_all if actor.respond_to?(:recover_all)
      actor.cg_reset_stat_stages if actor.respond_to?(:cg_reset_stat_stages)
      actor.cg_v242_clear_runtime if actor.respond_to?(:cg_v242_clear_runtime)
    end

    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end

    def self.prepare_test_party
      ids = TEST_ALLIES.collect { |cfg| master.actor_id_for_dex(cfg[:dex]) }
      if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
        ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids)
      end
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      for cfg in TEST_ALLIES; configure_actor(cfg); end
      human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if human != nil
        human.change_level(TEST_LEVEL,false)
        human.recover_all
        human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
        human.instance_variable_set(:@cg_master_ability_id,0)
      end
    end

    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs = [ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],
            ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg,i|
        configure_enemy(cfg)
        m = ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]),xs[i],ys[i])
        m.hidden = (i >= 4)
        members.push(m)
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID,"Pokemon Ability O v2.5.14a AutoRegression",members)
    end

    def self.make_action(battler,cfg)
      action = Game_BattleAction.new(battler)
      if cfg[:kind] == :guard
        action.set_guard
      elsif cfg[:kind] == :move
        action.set_skill(master.skill_id_for_move(cfg[:move_id].to_i))
      else
        action.clear
      end
      action.target_index = cfg[:target].to_i if cfg.has_key?(:target)
      return action
    end

    def self.forced_enemy_action(enemy)
      return nil unless active? && enemy != nil && !enemy.hidden && enemy.hp.to_i > 0
      plan = current_plan
      return nil if plan == nil
      cfg = plan[:enemies][enemy.index]
      return cfg == nil ? nil : make_action(enemy,cfg)
    end

    def self.apply_test_speeds
      vals = TEST_SPEEDS[("r" + current_round.to_s).to_sym] || []
      list = test_allies + all_enemies
      list.each_with_index do |b,i|
        b.instance_variable_set(:@cg_priority_test_speed_override,vals[i]) if b != nil
      end
    end

    def self.storage_size
      return 0 unless defined?(ALBERT_CG::PET_STORAGE) && ALBERT_CG::PET_STORAGE.respond_to?(:size)
      return ALBERT_CG::PET_STORAGE.size.to_i
    rescue
      return 0
    end

    def self.prepare_round_preconditions
      e = all_enemies
      a = test_allies
      if current_round == 1
        (a + e).each { |b| b.recover_all if b != nil && b.respond_to?(:recover_all) }
      elsif current_round == 2
        e[2].recover_all if e[2] != nil && e[2].respond_to?(:recover_all)
        e[3].recover_all if e[3] != nil && e[3].respond_to?(:recover_all)
        e[4].recover_all if e[4] != nil && e[4].respond_to?(:recover_all)
        @r2_storage_before = storage_size
      elsif current_round == 3
        e[4].recover_all if e[4] != nil && e[4].respond_to?(:recover_all)
      end
      return true
    rescue
      return false
    end

    def self.prepare_round_actions
      plan = current_plan
      return false if plan == nil
      apply_test_speeds
      prepare_round_preconditions
      @actual = []
      log("ROUND " + current_round.to_s + " BEGIN " + plan[:name].to_s)
      test_allies.each_with_index do |b,i|
        next if b == nil
        action = make_action(b,plan[:allies][i])
        if b.respond_to?(:cg_round_actions)
          b.cg_round_actions.clear
          b.cg_round_actions.push(action)
        end
        b.cg_assign_action(action) if b.respond_to?(:cg_assign_action)
        b.instance_variable_set(:@action,action) unless b.respond_to?(:cg_assign_action)
      end
      return true
    end

    def self.record_execution(battler)
      return unless active? && battler != nil
      action = battler.action
      prefix = battler.actor? ? "A" : "E"
      token = nil
      if action != nil && action.guard?
        token = prefix + battler.index.to_s + ":Guard"
      elsif action != nil && action.skill?
        mid = ALBERT_CG::MOVE_EFFECT.move_id(action.skill).to_i
        token = prefix + battler.index.to_s + ":M" + mid.to_s
      elsif action != nil && action.attack?
        token = prefix + battler.index.to_s + ":Attack"
      else
        token = prefix + battler.index.to_s + ":Other"
      end
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + battler.name.to_s + " token=" + token)
    rescue
    end

    def self.ratio_ok?(rec,num,den)
      return false if rec == nil || rec[:before].to_i <= 0
      return rec[:after].to_i == [rec[:before].to_i * num.to_i / den.to_i,1].max
    end

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted = true
      actual_troop_id = ($game_troop != nil && $game_troop.troop != nil) ? $game_troop.troop.id.to_i : 0
      assert_true("Ability Catalog count=373",defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.catalog_count == 373,
        "actual=" + (defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.catalog_count.to_s : "nil"))
      ids = defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.registered_ability_ids : []
      assert_true("Ability Batch O registers 8 IDs",HANDLED_ABILITY_IDS.all? { |id| ids.include?(id) })
      assert_true("Scene_Battle uses Ability O test troop",actual_troop_id == TEST_TROOP_ID,"actual=" + actual_troop_id.to_s)
      assert_true("Ability O ally count=4",test_allies.size == 4,"actual=" + test_allies.size.to_s)
      assert_true("Ability O starts with 4 active enemies",all_enemies.select { |b| b != nil && !b.hidden }.size == 4)
      assert_true("Ability O starts with 1 hidden Transistor reserve",all_enemies.select { |b| b != nil && b.hidden }.size == 1)
    end

    def self.assert_damage(label,aid,kind,num,den,move_id=nil,type_symbol=nil,role=nil,super_effective=nil)
      rec = @damage_records[[aid,kind]]
      ok = ratio_ok?(rec,num,den)
      ok = ok && rec[:move_id].to_i == move_id.to_i if ok && move_id != nil
      ok = ok && rec[:type_id].to_i == type_id(type_symbol) if ok && type_symbol != nil
      ok = ok && rec[:role] == role if ok && role != nil
      ok = ok && rec[:type_rate].to_i > 100 if ok && super_effective == true
      @damage_checks += 1 if ok
      assert_true(label,ok,"record=" + (rec == nil ? "nil" : rec.inspect))
      return ok
    end

    def self.assert_round
      r = current_round
      e = all_enemies
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      if r == 1
        assert_damage("Neuroforce boosts super-effective damage x1.25",ABILITY_NEUROFORCE,:neuroforce,5,4,55,:water,:attacker,true)
        assert_damage("Prism Armor reduces super-effective damage x0.75",ABILITY_PRISM_ARMOR,:prism_armor,3,4,55,:water,:defender,true)
        assert_damage("Punk Rock boosts outgoing Sound damage x1.3",ABILITY_PUNK_ROCK,:punk_rock_attack,13,10,304,nil,:attacker,nil)
        assert_damage("Ice Scales halves incoming Special damage",ABILITY_ICE_SCALES,:ice_scales,1,2,304,nil,:defender,nil)
        assert_damage("Dragon's Maw boosts Dragon damage x1.5",ABILITY_DRAGONS_MAW,:dragons_maw,3,2,225,:dragon,:attacker,nil)
        assert_damage("Shadow Shield halves direct damage at full HP",ABILITY_SHADOW_SHIELD,:shadow_shield,1,2,304,nil,:defender,nil)
        assert_damage("Punk Rock halves incoming Sound damage",ABILITY_PUNK_ROCK,:punk_rock_defense,1,2,304,nil,:defender,nil)
      elsif r == 2
        assert_damage("Fluffy halves Contact damage",ABILITY_FLUFFY,:fluffy_contact,1,2,33,nil,:defender,nil)
        assert_damage("Fluffy doubles incoming Fire damage",ABILITY_FLUFFY,:fluffy_fire,2,1,52,:fire,:defender,nil)
        switched = e[3] != nil && e[4] != nil && e[3].hidden && !e[4].hidden
        @lifecycle_checks += 1 if switched
        assert_true("Teleport deploys hidden Transistor reserve",switched,
          "E3_hidden=" + (e[3] == nil ? "nil" : e[3].hidden.to_s) + " E4_hidden=" + (e[4] == nil ? "nil" : e[4].hidden.to_s))
        storage_after = storage_size
        storage_ok = storage_after == @r2_storage_before.to_i
        @lifecycle_checks += 1 if storage_ok
        assert_true("Transistor reserve switch does not consume Storage Pokemon",storage_ok,
          "before=" + @r2_storage_before.to_s + " after=" + storage_after.to_s)
      elsif r == 3
        assert_damage("Transistor boosts Electric damage x1.3",ABILITY_TRANSISTOR,:transistor,13,10,85,:electric,:attacker,nil)
      end
      log("ROUND " + r.to_s + " END")
    end

    def self.finish_round_assertions
      return unless active?
      assert_round
      @round_index += 1
    end

    def self.ability_covered_count
      count = 0
      HANDLED_ABILITY_IDS.each { |aid| count += 1 if @ability_trigger_counts[aid].to_i > 0 }
      return count
    end

    def self.cleanup_test_overrides
      (test_allies + all_enemies).each do |b|
        b.instance_variable_set(:@cg_priority_test_speed_override,nil) if b != nil
      end
    end

    def self.finish_suite
      for aid in HANDLED_ABILITY_IDS
        assert_true("Ability " + aid.to_s + " triggered",@ability_trigger_counts[aid].to_i > 0,
          "count=" + @ability_trigger_counts[aid].to_i.to_s)
      end
      result = @failures.empty? ? "PASS" : "FAIL"
      log("------------------------------------------------------------")
      log("RESULT=" + result)
      log("SUMMARY rounds=3 failures=" + @failures.size.to_s +
        " ability_o=" + ability_covered_count.to_s + "/8" +
        " damage_checks=" + @damage_checks.to_i.to_s +
        " lifecycle_checks=" + @lifecycle_checks.to_i.to_s + " pending=253")
      @failures.each_with_index { |x,i| log("FAILURE " + (i+1).to_s + " " + x.to_s) }
      cleanup_test_overrides
      @active = false
      if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
        ALBERT_CG::TEST_CONVENIENCE.finish_session
      end
    end

    def self.reset_suite
      @round_index = 0
      @failures = []
      @ability_trigger_counts = {}
      @damage_records = {}
      @damage_checks = 0
      @lifecycle_checks = 0
      @actual = []
      @boot_asserted = false
      @r2_storage_before = 0
    end

    def self.start_auto_test
      return false if active?
      reset_log
      reset_suite
      prepare_test_party
      make_test_troop
      if defined?(ALBERT_CG::UNIQUE_I_V242) && ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes)
        ALBERT_CG::UNIQUE_I_V242.install_skill_scopes
      end
      @active = true
      if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
        ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_O_v2.5.14a")
      end
      log("AUTO_TEST_START troop=" + TEST_TROOP_ID.to_s)
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue => e
      @failures = [] if @failures == nil
      @failures.push("AUTO_TEST_START_ERROR " + e.class.to_s + ":" + e.message.to_s)
      log(@failures[-1])
      @active = false
      if defined?(ALBERT_CG::TEST_CONVENIENCE) && ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
        ALBERT_CG::TEST_CONVENIENCE.finish_session
      end
      return false
    end
  end
end

ALBERT_CG::ABILITY_O_V2514.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Older Ability regression F11：Batch O 成為唯一最新版
#==============================================================================
if defined?(ALBERT_CG::ABILITY_N_V2513)
  module ALBERT_CG; module ABILITY_N_V2513; def self.f11_trigger?; return false; end; end; end
end

class Game_Battler
  alias cg_v2514o_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    return 100 if defined?(ALBERT_CG::ABILITY_O_V2514) && ALBERT_CG::ABILITY_O_V2514.active?
    return cg_v2514o_ability_calc_hit(user,obj)
  end

  alias cg_v2514o_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_O_V2514) && ALBERT_CG::ABILITY_O_V2514.active?
    return cg_v2514o_ability_calc_eva(user,obj)
  end

  alias cg_v2514o_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_O_V2514) && ALBERT_CG::ABILITY_O_V2514.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v2514o_ability_priority_base_speed
  rescue
    return cg_v2514o_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2514o_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_O_V2514) && ALBERT_CG::ABILITY_O_V2514.active?
      action = ALBERT_CG::ABILITY_O_V2514.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v2514o_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2514o_ability_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::ABILITY_O_V2514.record_execution(battler) if defined?(ALBERT_CG::ABILITY_O_V2514) && ALBERT_CG::ABILITY_O_V2514.active?
    return cg_v2514o_ability_execute_action
  end

  alias cg_v2514o_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_O_V2514) && ALBERT_CG::ABILITY_O_V2514.active?
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_O_V2514.finish_round_assertions
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      else
        ALBERT_CG::ABILITY_O_V2514.finish_round_assertions
      end
    end
    return cg_v2514o_ability_turn_end
  end

  alias cg_v2514o_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_O_V2514) && ALBERT_CG::ABILITY_O_V2514.active?
      return cg_v2514o_ability_start_party_command
    end
    cg_v2514o_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_O_V2514.assert_bootstrap_once
    if ALBERT_CG::ABILITY_O_V2514.finished?
      ALBERT_CG::ABILITY_O_V2514.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_O_V2514.prepare_round_actions
    start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2514o_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v2514o_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_O_V2514) && ALBERT_CG::ABILITY_O_V2514.active?
        for cfg in ALBERT_CG::ABILITY_O_V2514::TEST_ALLIES
          ALBERT_CG::ABILITY_O_V2514.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_O_V2514::TEST_LEVEL,false)
          human.recover_all
          human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
          human.instance_variable_set(:@cg_master_ability_id,0)
        end
      end
      return result
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2514o_ability_scene_map_update update
  def update
    cg_v2514o_ability_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_O_V2514)
    if ALBERT_CG::ABILITY_O_V2514.f11_trigger?
      ALBERT_CG::ABILITY_O_V2514.start_auto_test
    end
  end
end
