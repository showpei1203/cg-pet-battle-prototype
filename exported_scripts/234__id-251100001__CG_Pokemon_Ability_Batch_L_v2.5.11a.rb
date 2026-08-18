# RMVX_SCRIPT_INDEX: 234
# RMVX_SCRIPT_ID: 251100001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch L v2.5.11a
# RMVX_SOURCE_SHA256: 0f138939f605ccc0c53c361cf980eb7cfd19f1bd4c068171c0bf0521a9810962

#==============================================================================
# ■ CG Pokemon Ability Batch L v2.5.11a - Conditional Damage + Defense
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.10a Ability Batch K 實機 PASS 基底上，正式實作第十二批 8 個
#  「條件攻擊倍率／防禦能力值／滿血減傷」Ability，並提供 Actual Scene_Battle
#  deterministic F11 regression。此批完全沿用已 PASS 的 :stat_query 與
#  :damage_modify lifecycle，不修改舊 Ability Authority 原頁。
#
# 【本批 Ability】
#  129 Defeatist    軟弱：HP <= 1/2 時有效 ATK / SPA x0.5。
#  136 Multiscale   多重鱗片：滿 HP 時受到直接 damaging Move 傷害 x0.5。
#  137 Toxic Boost  中毒激升：Poison / Bad Poison 時 Physical Move 傷害 x1.5。
#  138 Flare Boost  受熱激升：Burn 時 Special Move 傷害 x1.5。
#  169 Fur Coat     毛皮大衣：有效 DEF x2。
#  173 Strong Jaw   強壯之顎：咬擊類 damaging Move 傷害 x1.5。
#  181 Tough Claws  硬爪：Contact damaging Move 傷害 x1.3。
#  200 Steelworker  鋼能力者：Steel damaging Move 傷害 x1.5。
#
# 【主要設定項】
#  TEST_TROOP_ID = 714
#  HANDLED_ABILITY_IDS = 8
#  Coverage：88/373 -> 96/373，pending 285 -> 277。
#  BITE_IDENTIFIERS：本專案 937 Move Catalog 中視為「咬擊」的 identifier 白名單。
#
# 【機制規則】
#  1. Defeatist / Fur Coat 只經 Ability Core :stat_query；ATK/DEF 由 v2.5.3，
#     SPA 由 v2.5.8 已 PASS bridge 提供，因此不重做 Stat Stage / Burn / Weather。
#  2. 其餘 6 個 Ability 只經 :damage_modify；Fixed Damage 不吃本批倍率。
#  3. Toxic Boost 只接受 Poison / Bad Poison + Physical Move；Flare Boost 只接受
#     Burn + Special Move。主要異常 State ID 一律沿用 MoveEffect Authority。
#  4. Multiscale 判定 damage lifecycle 當下 target.hp >= target.maxhp；不建立額外
#     「本回合曾滿血」旗標，因此第一擊後的後續多段不再自動享受滿血減傷。
#  5. Tough Claws 使用 Ability Core contact_action?，與既有 Move contact property
#     共用權威；Strong Jaw 只依 BITE_IDENTIFIERS 判斷；Steelworker 讀正式 Steel type id。
#  6. 有效 Ability 一律由 cg_master_ability_id 決定，會尊重 Gastro Acid、Skill Swap、
#     Role Play、Transform 等 Battle-only Ability override/suppression。
#  7. F11 Regression 只固定 hit/evasion/SPE；正式玩家戰鬥 RNG 與傷害 variance 不變。
#  8. v2.5.11 實機唯一 FAIL 分類為 Regression isolation bug：Round 1 的 Poisoned
#     Toxic Boost 使用者同時承受 Strong Jaw 傷害與跨回合毒傷，於 Round 3 前死亡，
#     導致預期 A1:M150 缺席；8 個 Ability Runtime 本身均已觸發並通過各自 ASSERT。
#     v2.5.11a 僅在 Round 2 precondition recover Round 1 條件使用者，正式規則不變。
#  9. TEST Convenience 只限 F11；正式 Release 必須恢復 emerged、Battle BGM/BGS
#     與正常 VX 焦點行為。
#
# 【可調參數】
#  DEFEATIST_PERCENT=50 / MULTISCALE_PERCENT=50 /
#  TOXIC_BOOST_PERCENT=150 / FLARE_BOOST_PERCENT=150 /
#  FUR_COAT_PERCENT=200 / STRONG_JAW_PERCENT=150 /
#  TOUGH_CLAWS_PERCENT=130 / STEELWORKER_PERCENT=150。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，一次跑完三回合，輸出
#  Pokemon_Ability_L_AutoTest_v2_5_11a.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Burned Flare Boost 使用 Ember -> 最終 damage x1.5；滿 HP Multiscale 目標同時
#  將該次 damage x0.5。Tough Claws + Tackle -> x1.3；Steelworker + Metal Claw -> x1.5。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchL"] = "2.5.11a"

module ALBERT_CG
  module ABILITY_L_V2511
    VERSION = "2.5.11a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 714
    VK_F11 = 0x7A

    ABILITY_DEFEATIST   = 129
    ABILITY_MULTISCALE  = 136
    ABILITY_TOXIC_BOOST = 137
    ABILITY_FLARE_BOOST = 138
    ABILITY_FUR_COAT    = 169
    ABILITY_STRONG_JAW  = 173
    ABILITY_TOUGH_CLAWS = 181
    ABILITY_STEELWORKER = 200

    HANDLED_ABILITY_IDS = [129,136,137,138,169,173,181,200]

    DEFEATIST_PERCENT   = 50
    MULTISCALE_PERCENT  = 50
    TOXIC_BOOST_PERCENT = 150
    FLARE_BOOST_PERCENT = 150
    FUR_COAT_PERCENT    = 200
    STRONG_JAW_PERCENT  = 150
    TOUGH_CLAWS_PERCENT = 130
    STEELWORKER_PERCENT = 150

    BITE_IDENTIFIERS = [
      "bite","crunch","fire-fang","ice-fang","thunder-fang","poison-fang",
      "hyper-fang","psychic-fangs","jaw-lock","fishious-rend"
    ]

    TEST_ALLIES = [
      {:dex=>335,:level=>40,:ability=>ABILITY_TOXIC_BOOST,:moves=>[33,150,150,150]},
      {:dex=>426,:level=>40,:ability=>ABILITY_FLARE_BOOST,:moves=>[52,150,150,150]},
      {:dex=>448,:level=>40,:ability=>ABILITY_TOUGH_CLAWS,:moves=>[33,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>289,:level=>40,:ability=>ABILITY_DEFEATIST, :moves=>[33,150,150,150]},
      {:dex=>149,:level=>40,:ability=>ABILITY_MULTISCALE,:moves=>[150,150,150,150]},
      {:dex=>143,:level=>40,:ability=>ABILITY_FUR_COAT,  :moves=>[150,150,150,150]},
      {:dex=>248,:level=>40,:ability=>ABILITY_STRONG_JAW,:moves=>[44,100,150,150]},
      {:dex=>212,:level=>40,:ability=>ABILITY_STEELWORKER,:moves=>[232,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"TOXIC_FLARE_MULTISCALE_FUR_STRONG_TOUGH_DEFEATIST",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>0},
          {:kind=>:move,:move_id=>52,:target=>1},
          {:kind=>:move,:move_id=>33,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>33,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>44,:target=>1},
        }
      },
      {
        :name=>"STEELWORKER_RESERVE_SWITCH",
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
          3=>{:kind=>:move,:move_id=>100,:target=>0},
        }
      },
      {
        :name=>"STEELWORKER_STEEL_DAMAGE",
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
          4=>{:kind=>:move,:move_id=>232,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,260,250,240, 210,200,190,220,0],
      :r2=>[10,230,220,210, 180,170,160,100,0],
      :r3=>[10,180,170,160, 150,140,130,0,260],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M33","A2:M52","A3:M33","E3:M44","E0:M33","E1:M150","E2:M150"],
      2=>["A0:Guard","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","E4:M232","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.master; return defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.active?; return @active == true; end
    def self.current_round; return @round_index.to_i + 1; end
    def self.current_plan; return ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; return @round_index.to_i >= ROUND_PLANS.size; end
    def self.test_allies; return $game_party == nil ? [] : $game_party.members; end
    def self.all_enemies; return $game_troop == nil ? [] : $game_troop.members; end
    def self.project_root; return Dir.pwd; rescue; return "."; end
    def self.log_path; return File.join(project_root,"Pokemon_Ability_L_AutoTest_v2_5_11a.log"); end
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
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_L_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end

    def self.reset_log
      header = "CG POKEMON ABILITY L CONDITIONAL DAMAGE + DEFENSE AUTO REGRESSION v2.5.11a\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; conditional stat/damage modifiers + reserve switch\r\n" +
        "BASELINE=v2.5.10a Ability Batch K Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_TO_K_PASS=88 BATCH_L=8 PENDING=277\r\n" +
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

    def self.move_row(move_id)
      return master == nil ? nil : master.move(move_id.to_i)
    rescue
      return nil
    end

    def self.move_identifier(move_id)
      row = move_row(move_id)
      return row == nil ? "" : row[0].to_s
    end

    def self.type_id(symbol)
      return 0 unless defined?(ALBERT_CG::POKEMON_COMBAT)
      table = ALBERT_CG::POKEMON_COMBAT::TYPE_IDS
      return table[symbol].to_i if table != nil && table.has_key?(symbol)
      return 0
    rescue
      return 0
    end

    def self.physical_move?(ctx)
      skill = ctx[:skill]
      return skill.cg_pokemon_damage_class == :physical if skill != nil && skill.respond_to?(:cg_pokemon_damage_class)
      return skill != nil && skill.respond_to?(:physical_attack) && skill.physical_attack == true
    rescue
      return false
    end

    def self.special_move?(ctx)
      skill = ctx[:skill]
      return skill.cg_pokemon_damage_class == :special if skill != nil && skill.respond_to?(:cg_pokemon_damage_class)
      return false
    rescue
      return false
    end

    def self.poisoned?(battler)
      return false if battler == nil || !defined?(ALBERT_CG::MOVE_EFFECT)
      ids = [ALBERT_CG::MOVE_EFFECT::STATE_POISON]
      if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON)
        ids.push(ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON)
      end
      return ids.any? { |sid| battler.state?(sid) }
    rescue
      return false
    end

    def self.burned?(battler)
      return false if battler == nil || !defined?(ALBERT_CG::MOVE_EFFECT)
      return battler.state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
    rescue
      return false
    end

    def self.note_stat(aid,battler,stat,before,after,kind)
      if active?
        @ability_trigger_counts[aid] = @ability_trigger_counts[aid].to_i + 1
        rec = {:stat=>stat,:before=>before.to_i,:after=>after.to_i,:kind=>kind}
        @stat_records[[aid,stat]] = rec
        log("ABILITY_L_STAT ability=" + aid.to_s + " battler=" + battler.name.to_s +
          " stat=" + stat.to_s + " kind=" + kind.to_s + " before=" + before.to_i.to_s +
          " after=" + after.to_i.to_s)
      end
    rescue
    end

    def self.note_damage(aid,battler,kind,before,after,ctx)
      if active?
        @ability_trigger_counts[aid] = @ability_trigger_counts[aid].to_i + 1
        rec = {:kind=>kind,:before=>before.to_i,:after=>after.to_i,
          :move_id=>ctx[:move_id].to_i,:type_id=>ctx[:type_id].to_i,:role=>ctx[:role]}
        @damage_records[aid] = rec
        log("ABILITY_L_DAMAGE ability=" + aid.to_s + " battler=" + battler.name.to_s +
          " kind=" + kind.to_s + " before=" + before.to_i.to_s + " after=" + after.to_i.to_s +
          " move=" + ctx[:move_id].to_i.to_s + " type_id=" + ctx[:type_id].to_i.to_s +
          " role=" + ctx[:role].to_s)
      end
    rescue
    end

    def self.apply_stat_percent(aid,battler,ctx,kind,percent)
      before = ctx[:value].to_i
      return false if before <= 0
      after = [before * percent.to_i / 100,1].max
      ctx[:value] = after
      note_stat(aid,battler,ctx[:stat],before,after,kind)
      return true
    end

    def self.apply_damage_percent(aid,battler,ctx,kind,percent)
      before = ctx[:damage].to_i
      return false if before <= 0 || ctx[:fixed_damage] == true
      after = [before * percent.to_i / 100,1].max
      ctx[:damage] = after
      note_damage(aid,battler,kind,before,after,ctx)
      return true
    end

    def self.apply_defeatist(battler,ctx)
      return false unless ctx[:stat] == :atk || ctx[:stat] == :spa
      return false if battler == nil || battler.maxhp.to_i <= 0
      return false unless battler.hp.to_i * 2 <= battler.maxhp.to_i
      return apply_stat_percent(ABILITY_DEFEATIST,battler,ctx,:defeatist,DEFEATIST_PERCENT)
    end

    def self.apply_multiscale(battler,ctx)
      return false unless ctx[:role] == :defender
      return false if battler == nil || battler.hp.to_i < battler.maxhp.to_i
      return apply_damage_percent(ABILITY_MULTISCALE,battler,ctx,:multiscale,MULTISCALE_PERCENT)
    end

    def self.apply_toxic_boost(battler,ctx)
      return false unless ctx[:role] == :attacker && poisoned?(battler) && physical_move?(ctx)
      return apply_damage_percent(ABILITY_TOXIC_BOOST,battler,ctx,:toxic_boost,TOXIC_BOOST_PERCENT)
    end

    def self.apply_flare_boost(battler,ctx)
      return false unless ctx[:role] == :attacker && burned?(battler) && special_move?(ctx)
      return apply_damage_percent(ABILITY_FLARE_BOOST,battler,ctx,:flare_boost,FLARE_BOOST_PERCENT)
    end

    def self.apply_fur_coat(battler,ctx)
      return false unless ctx[:stat] == :def
      return apply_stat_percent(ABILITY_FUR_COAT,battler,ctx,:fur_coat,FUR_COAT_PERCENT)
    end

    def self.apply_strong_jaw(battler,ctx)
      return false unless ctx[:role] == :attacker
      return false unless BITE_IDENTIFIERS.include?(move_identifier(ctx[:move_id]))
      return apply_damage_percent(ABILITY_STRONG_JAW,battler,ctx,:strong_jaw,STRONG_JAW_PERCENT)
    end

    def self.apply_tough_claws(battler,ctx)
      return false unless ctx[:role] == :attacker
      return false unless defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.contact_action?(battler)
      return apply_damage_percent(ABILITY_TOUGH_CLAWS,battler,ctx,:tough_claws,TOUGH_CLAWS_PERCENT)
    end

    def self.apply_steelworker(battler,ctx)
      return false unless ctx[:role] == :attacker && ctx[:type_id].to_i == type_id(:steel)
      return apply_damage_percent(ABILITY_STEELWORKER,battler,ctx,:steelworker,STEELWORKER_PERCENT)
    end

    def self.register_handlers
      return false unless defined?(ALBERT_CG::ABILITY_V250)
      core = ALBERT_CG::ABILITY_V250
      core.register(ABILITY_DEFEATIST,:stat_query,self,:apply_defeatist)
      core.register(ABILITY_MULTISCALE,:damage_modify,self,:apply_multiscale)
      core.register(ABILITY_TOXIC_BOOST,:damage_modify,self,:apply_toxic_boost)
      core.register(ABILITY_FLARE_BOOST,:damage_modify,self,:apply_flare_boost)
      core.register(ABILITY_FUR_COAT,:stat_query,self,:apply_fur_coat)
      core.register(ABILITY_STRONG_JAW,:damage_modify,self,:apply_strong_jaw)
      core.register(ABILITY_TOUGH_CLAWS,:damage_modify,self,:apply_tough_claws)
      core.register(ABILITY_STEELWORKER,:damage_modify,self,:apply_steelworker)
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
        TEST_TROOP_ID,"Pokemon Ability L v2.5.11a AutoRegression",members)
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

    def self.install_round1_conditions
      a = test_allies
      e = all_enemies
      if defined?(ALBERT_CG::MOVE_EFFECT)
        a[1].add_state(ALBERT_CG::MOVE_EFFECT::STATE_POISON) if a[1] != nil
        a[2].add_state(ALBERT_CG::MOVE_EFFECT::STATE_BURN) if a[2] != nil
      end
      if e[0] != nil
        e[0].hp = [e[0].maxhp.to_i / 2,1].max
      end
      e[1].recover_all if e[1] != nil && e[1].respond_to?(:recover_all)
      return true
    rescue
      return false
    end

    def self.prepare_round_preconditions
      if current_round == 1
        install_round1_conditions
      elsif current_round == 2
        # TEST-only isolation：Round 1 已完成 Toxic Boost / Flare Boost 實機驗證。
        # 進入後續 reserve / Steelworker 測試前，清除兩名條件使用者的殘留
        # Poison / Burn 與傷害，避免狀態持續傷害把 A1/A2 帶死到 Round 3。
        # 這不修改正式 Ability / 狀態傷害規則，只隔離 Regression round。
        a = test_allies
        a[1].recover_all if a[1] != nil && a[1].respond_to?(:recover_all)
        a[2].recover_all if a[2] != nil && a[2].respond_to?(:recover_all)
        log("TEST_ISOLATION Round2 recover Toxic/Flare users after Round1 verification")
        @r2_storage_before = storage_size
        e = all_enemies
        e[4].recover_all if e[4] != nil && e[4].respond_to?(:recover_all)
      end
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
      install_round1_conditions
      actual_troop_id = ($game_troop != nil && $game_troop.troop != nil) ? $game_troop.troop.id.to_i : 0
      assert_true("Ability Catalog count=373",defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.catalog_count == 373,
        "actual=" + (defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.catalog_count.to_s : "nil"))
      ids = defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.registered_ability_ids : []
      assert_true("Ability Batch L registers 8 IDs",HANDLED_ABILITY_IDS.all? { |id| ids.include?(id) })
      assert_true("Scene_Battle uses Ability L test troop",actual_troop_id == TEST_TROOP_ID,"actual=" + actual_troop_id.to_s)
      assert_true("Ability L ally count=4",test_allies.size == 4,"actual=" + test_allies.size.to_s)
      assert_true("Ability L starts with 4 active enemies",all_enemies.select { |b| b != nil && !b.hidden }.size == 4)
      assert_true("Ability L starts with 1 hidden Steelworker reserve",all_enemies.select { |b| b != nil && b.hidden }.size == 1)

      a = test_allies; e = all_enemies
      poison_ok = defined?(ALBERT_CG::MOVE_EFFECT) && a[1] != nil && a[1].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON)
      burn_ok = defined?(ALBERT_CG::MOVE_EFFECT) && a[2] != nil && a[2].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
      assert_true("Toxic Boost regression user begins Poisoned",poison_ok)
      assert_true("Flare Boost regression user begins Burned",burn_ok)
      assert_true("Defeatist regression user begins at half HP",e[0] != nil && e[0].hp.to_i * 2 <= e[0].maxhp.to_i,
        e[0] == nil ? "nil" : "hp=" + e[0].hp.to_s + "/" + e[0].maxhp.to_s)

      if e[0] != nil
        e[0].cg_atk_stat if e[0].respond_to?(:cg_atk_stat)
        e[0].cg_spa if e[0].respond_to?(:cg_spa)
      end
      e[2].cg_def_stat if e[2] != nil && e[2].respond_to?(:cg_def_stat)

      rec_atk = @stat_records[[ABILITY_DEFEATIST,:atk]]
      ok_atk = ratio_ok?(rec_atk,1,2)
      @stat_checks += 1 if ok_atk
      assert_true("Defeatist halves effective ATK at HP<=1/2",ok_atk,"record=" + rec_atk.inspect)
      rec_spa = @stat_records[[ABILITY_DEFEATIST,:spa]]
      ok_spa = ratio_ok?(rec_spa,1,2)
      @stat_checks += 1 if ok_spa
      assert_true("Defeatist halves effective SPA at HP<=1/2",ok_spa,"record=" + rec_spa.inspect)
      rec_def = @stat_records[[ABILITY_FUR_COAT,:def]]
      ok_def = ratio_ok?(rec_def,2,1)
      @stat_checks += 1 if ok_def
      assert_true("Fur Coat doubles effective DEF",ok_def,"record=" + rec_def.inspect)
    end

    def self.assert_round
      r = current_round
      e = all_enemies
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      if r == 1
        checks = [
          [ABILITY_TOXIC_BOOST,"Toxic Boost raises Poisoned Physical damage x1.5",3,2,33],
          [ABILITY_FLARE_BOOST,"Flare Boost raises Burned Special damage x1.5",3,2,52],
          [ABILITY_MULTISCALE,"Multiscale halves direct damage at full HP",1,2,52],
          [ABILITY_STRONG_JAW,"Strong Jaw raises Bite damage x1.5",3,2,44],
          [ABILITY_TOUGH_CLAWS,"Tough Claws raises Contact damage x1.3",13,10,33],
        ]
        checks.each do |row|
          rec = @damage_records[row[0]]
          ok = ratio_ok?(rec,row[2],row[3]) && rec[:move_id].to_i == row[4].to_i
          @damage_checks += 1 if ok
          assert_true(row[1],ok,"record=" + rec.inspect)
        end
      elsif r == 2
        switched = e[3] != nil && e[4] != nil && e[3].hidden && !e[4].hidden
        @lifecycle_checks += 1 if switched
        assert_true("Teleport deploys hidden Steelworker reserve",switched,
          "E3_hidden=" + (e[3] == nil ? "nil" : e[3].hidden.to_s) + " E4_hidden=" + (e[4] == nil ? "nil" : e[4].hidden.to_s))
        storage_after = storage_size
        storage_ok = storage_after == @r2_storage_before.to_i
        @lifecycle_checks += 1 if storage_ok
        assert_true("Steelworker reserve switch does not consume Storage Pokemon",storage_ok,
          "before=" + @r2_storage_before.to_s + " after=" + storage_after.to_s)
      elsif r == 3
        rec = @damage_records[ABILITY_STEELWORKER]
        ok = ratio_ok?(rec,3,2) && rec[:move_id].to_i == 232 && rec[:type_id].to_i == type_id(:steel)
        @damage_checks += 1 if ok
        assert_true("Steelworker raises Steel Move damage x1.5",ok,"record=" + rec.inspect)
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
        " ability_l=" + ability_covered_count.to_s + "/8" +
        " stat_checks=" + @stat_checks.to_i.to_s +
        " damage_checks=" + @damage_checks.to_i.to_s +
        " lifecycle_checks=" + @lifecycle_checks.to_i.to_s + " pending=277")
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
      @stat_records = {}
      @damage_records = {}
      @stat_checks = 0
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
        ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_L_v2.5.11a")
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

ALBERT_CG::ABILITY_L_V2511.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Older Ability regression F11：Batch L 成為唯一最新版
#==============================================================================
if defined?(ALBERT_CG::ABILITY_K_V2510)
  module ALBERT_CG; module ABILITY_K_V2510; def self.f11_trigger?; return false; end; end; end
end

class Game_Battler
  alias cg_v2511l_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    return 100 if defined?(ALBERT_CG::ABILITY_L_V2511) && ALBERT_CG::ABILITY_L_V2511.active?
    return cg_v2511l_ability_calc_hit(user,obj)
  end

  alias cg_v2511l_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_L_V2511) && ALBERT_CG::ABILITY_L_V2511.active?
    return cg_v2511l_ability_calc_eva(user,obj)
  end

  alias cg_v2511l_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_L_V2511) && ALBERT_CG::ABILITY_L_V2511.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v2511l_ability_priority_base_speed
  rescue
    return cg_v2511l_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2511l_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_L_V2511) && ALBERT_CG::ABILITY_L_V2511.active?
      action = ALBERT_CG::ABILITY_L_V2511.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v2511l_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2511l_ability_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::ABILITY_L_V2511.record_execution(battler) if defined?(ALBERT_CG::ABILITY_L_V2511) && ALBERT_CG::ABILITY_L_V2511.active?
    return cg_v2511l_ability_execute_action
  end

  alias cg_v2511l_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_L_V2511) && ALBERT_CG::ABILITY_L_V2511.active?
      ALBERT_CG::ABILITY_L_V2511.finish_round_assertions
    end
    return cg_v2511l_ability_turn_end
  end

  alias cg_v2511l_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_L_V2511) && ALBERT_CG::ABILITY_L_V2511.active?
      return cg_v2511l_ability_start_party_command
    end
    cg_v2511l_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_L_V2511.assert_bootstrap_once
    if ALBERT_CG::ABILITY_L_V2511.finished?
      ALBERT_CG::ABILITY_L_V2511.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_L_V2511.prepare_round_actions
    start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2511l_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v2511l_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_L_V2511) && ALBERT_CG::ABILITY_L_V2511.active?
        for cfg in ALBERT_CG::ABILITY_L_V2511::TEST_ALLIES
          ALBERT_CG::ABILITY_L_V2511.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_L_V2511::TEST_LEVEL,false)
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
  alias cg_v2511l_ability_scene_map_update update
  def update
    cg_v2511l_ability_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_L_V2511)
    if ALBERT_CG::ABILITY_L_V2511.f11_trigger?
      ALBERT_CG::ABILITY_L_V2511.start_auto_test
    end
  end
end
