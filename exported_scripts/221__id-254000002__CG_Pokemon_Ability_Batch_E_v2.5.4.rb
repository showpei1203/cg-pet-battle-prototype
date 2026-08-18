# RMVX_SCRIPT_INDEX: 221
# RMVX_SCRIPT_ID: 254000002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch E v2.5.4
# RMVX_SOURCE_SHA256: 2fd5a9bbe48b25d1ff33e713662654f350a116576a59a8517f220541950a464b

#==============================================================================
# ■ CG Pokemon Ability Batch E v2.5.4 - Damage Modifier Family
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.3 Ability Batch D PASS 基底上，正式實作第五批 8 個攻防傷害倍率 Ability，
#  並提供 Actual Scene_Battle deterministic F11 regression。此批同時驗證 v2.5.4
#  Damage Role Authority 的 defender :damage_modify lifecycle。
#
# 【本批 Ability】
#   47  Thick Fat   厚脂肪：受到 Fire / Ice 直接傷害 x0.5。
#   89  Iron Fist   鐵拳：拳類 damaging Move 傷害 x1.2。
#   91  Adaptability 適應力：同屬性 STAB 由 x1.5 提升至 x2（最終傷害再 x4/3）。
#   101 Technician  技術高手：基礎威力 1..60 的 damaging Move 傷害 x1.5。
#   110 Tinted Lens 有色眼鏡：對 type_rate 1..99 的不利屬性傷害 x2。
#   111 Filter      過濾：受到 type_rate >100 的超有效直接傷害 x0.75。
#   116 Solid Rock  堅硬岩石：受到 type_rate >100 的超有效直接傷害 x0.75。
#   120 Reckless    捨身：有 recoil 的 damaging Move 傷害 x1.2。
#
# 【主要設定項】
#  PUNCH_IDENTIFIERS：本專案 937 Move Catalog 中視為拳類的 identifier 白名單。
#  TEST_TROOP_ID=707：F11 deterministic Scene_Battle 專用 troop。
#
# 【機制規則】
#  1. 全部 Ability 都走 Ability Core 的 :damage_modify；攻擊方由 v2.5.3 Modifier
#     Authority dispatch，防守方由 v2.5.4 Damage Role Authority dispatch。
#  2. Fixed Damage 不吃本批倍率。
#  3. Technician 讀 Master Move Catalog 的 base power，不以最終 damage 反推。
#  4. Tinted Lens / Filter / Solid Rock 以 target.cg_pokemon_type_rate_percent 為唯一
#     屬性倍率權威，不另造 Type Chart。
#  5. Reckless 以 MoveEffect drain_percent < 0 判定 recoil Move；未來若新增 crash-only
#     Move，可擴充 RECKLESS_EXTRA_IDENTIFIERS。
#  6. 所有有效 Ability 仍讀 cg_master_ability_id，尊重 Ability override/suppression。
#  7. F11 測試固定 hit/evasion/SPE，只在 Regression active 生效；正式戰鬥 RNG 不變。
#
# 【可調參數】
#  THICK_FAT_PERCENT=50 / IRON_FIST_PERCENT=120 / ADAPTABILITY_PERCENT=133(實際用4/3) /
#  TECHNICIAN_PERCENT=150 / TINTED_LENS_PERCENT=200 /
#  FILTER_PERCENT=75 / SOLID_ROCK_PERCENT=75 / RECKLESS_PERCENT=120。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，自動執行四回合並寫入
#  Pokemon_Ability_E_AutoTest_v2_5_4.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Fire Punch -> Thick Fat：Iron Fist 先/後與 Thick Fat 皆經同一最終傷害 chain，
#  Regression 只 ASSERT 各 Ability context 的 before/after 比率，不依賴 damage variance。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchE"] = "2.5.4"

module ALBERT_CG
  module ABILITY_E_V254
    VERSION = "2.5.4"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 707
    VK_F11 = 0x7A

    ABILITY_THICK_FAT   = 47
    ABILITY_IRON_FIST   = 89
    ABILITY_ADAPTABILITY = 91
    ABILITY_TECHNICIAN  = 101
    ABILITY_TINTED_LENS = 110
    ABILITY_FILTER      = 111
    ABILITY_SOLID_ROCK  = 116
    ABILITY_RECKLESS    = 120

    HANDLED_ABILITY_IDS = [47,89,91,101,110,111,116,120]

    THICK_FAT_PERCENT = 50
    IRON_FIST_PERCENT = 120
    TECHNICIAN_PERCENT = 150
    TINTED_LENS_PERCENT = 200
    FILTER_PERCENT = 75
    SOLID_ROCK_PERCENT = 75
    RECKLESS_PERCENT = 120

    PUNCH_IDENTIFIERS = [
      "comet-punch","mega-punch","fire-punch","ice-punch","thunder-punch",
      "dizzy-punch","mach-punch","dynamic-punch","focus-punch","sky-uppercut",
      "hammer-arm","bullet-punch","drain-punch","shadow-punch","power-up-punch",
      "ice-hammer","plasma-fists","double-iron-bash","wicked-blow","surging-strikes",
      "jet-punch","rage-fist"
    ]
    RECKLESS_EXTRA_IDENTIFIERS = ["jump-kick","high-jump-kick"]

    TEST_ALLIES = [
      {:dex=>107,:level=>40,:ability=>ABILITY_IRON_FIST,:moves=>[7,150,150,150]},
      {:dex=>212,:level=>40,:ability=>ABILITY_TECHNICIAN,:moves=>[52,55,150,150]},
      {:dex=>49, :level=>40,:ability=>ABILITY_TINTED_LENS,:moves=>[55,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>143,:level=>40,:ability=>ABILITY_THICK_FAT,:moves=>[150,150,150,150]},
      {:dex=>133,:level=>40,:ability=>ABILITY_ADAPTABILITY,:moves=>[33,150,150,150]},
      {:dex=>3,  :level=>40,:ability=>ABILITY_FILTER,:moves=>[150,150,150,150]},
      {:dex=>464,:level=>40,:ability=>ABILITY_SOLID_ROCK,:moves=>[100,150,150,150]},
      {:dex=>398,:level=>40,:ability=>ABILITY_RECKLESS,:moves=>[38,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"IRON_TECH_TINTED_THICK_ADAPT",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>7,:target=>0},
          {:kind=>:move,:move_id=>52,:target=>1},
          {:kind=>:move,:move_id=>55,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>33,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
      {
        :name=>"FILTER_SOLID_ROCK",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>7,:target=>2},
          {:kind=>:move,:move_id=>55,:target=>3},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
      {
        :name=>"RECKLESS_RESERVE_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>100,:target=>0},
        }
      },
      {
        :name=>"RECKLESS_RECOIL_POWER",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          4=>{:kind=>:move,:move_id=>38,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,230,220,210, 180,170,160,150,0],
      :r2=>[10,230,220,100, 180,170,160,150,0],
      :r3=>[10,180,170,160, 150,140,130,120,0],
      :r4=>[10,180,170,160, 150,140,130,0,230],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M7","A2:M52","A3:M55","E0:M150","E1:M33","E2:M150","E3:M150"],
      2=>["A0:Guard","A1:M7","A2:M55","E0:M150","E1:M150","E2:M150","E3:M150","A3:M150"],
      3=>["A0:Guard","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M100"],
      4=>["A0:Guard","E4:M38","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.master
      return defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil
    end
    def self.active?; return @active == true; end
    def self.current_round; return @round_index.to_i + 1; end
    def self.current_plan; return ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; return @round_index.to_i >= ROUND_PLANS.size; end
    def self.test_allies; return $game_party == nil ? [] : $game_party.members; end
    def self.all_enemies; return $game_troop == nil ? [] : $game_troop.members; end

    def self.project_root
      return Dir.pwd
    rescue
      return "."
    end
    def self.log_path; return File.join(project_root,"Pokemon_Ability_E_AutoTest_v2_5_4.log"); end
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
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_E_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end
    def self.reset_log
      header = "CG POKEMON ABILITY E DAMAGE MODIFIER AUTO REGRESSION v2.5.4\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; attacker/defender damage modifiers + reserve switch\r\n" +
        "BASELINE=v2.5.3 Ability Batch D Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_B_C_D_PASS=32 BATCH_E=8 PENDING=333\r\n" +
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

    def self.type_id(symbol)
      return 0 unless defined?(ALBERT_CG::POKEMON_COMBAT)
      table = ALBERT_CG::POKEMON_COMBAT::TYPE_IDS
      return table[symbol].to_i if table != nil && table.has_key?(symbol)
      return 0
    rescue
      return 0
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
    def self.move_power(move_id)
      row = move_row(move_id)
      return row == nil ? 0 : row[3].to_i
    end
    def self.type_rate(ctx)
      return ctx[:type_rate].to_i if ctx.has_key?(:type_rate)
      target = ctx[:target]
      type_id = ctx[:type_id].to_i
      return 100 if target == nil || type_id <= 0
      return target.cg_pokemon_type_rate_percent(type_id).to_i if target.respond_to?(:cg_pokemon_type_rate_percent)
      return 100
    rescue
      return 100
    end
    def self.recoil_move?(move_id)
      if defined?(ALBERT_CG::MOVE_EFFECT)
        return true if ALBERT_CG::MOVE_EFFECT.drain_percent(move_id.to_i).to_i < 0
      end
      return RECKLESS_EXTRA_IDENTIFIERS.include?(move_identifier(move_id))
    rescue
      return false
    end

    def self.note_modifier(aid,battler,kind,before,after,ctx)
      @ability_trigger_counts[aid] = @ability_trigger_counts[aid].to_i + 1
      rec = {
        :kind=>kind,:before=>before.to_i,:after=>after.to_i,
        :move_id=>ctx[:move_id].to_i,:type_id=>ctx[:type_id].to_i,
        :type_rate=>type_rate(ctx),:role=>ctx[:role]
      }
      @last_records[aid] = rec
      log("ABILITY_E_MOD ability=" + aid.to_s + " battler=" + battler.name.to_s +
        " kind=" + kind.to_s + " before=" + before.to_i.to_s + " after=" + after.to_i.to_s +
        " move=" + ctx[:move_id].to_i.to_s + " type_rate=" + rec[:type_rate].to_s +
        " role=" + ctx[:role].to_s)
    end

    def self.apply_percent(aid,battler,ctx,kind,percent)
      before = ctx[:damage].to_i
      return false if before <= 0 || ctx[:fixed_damage] == true
      after = [before * percent.to_i / 100,1].max
      ctx[:damage] = after
      note_modifier(aid,battler,kind,before,after,ctx)
      return true
    end

    def self.apply_thick_fat(battler,ctx)
      return false unless ctx[:role] == :defender
      tid = ctx[:type_id].to_i
      return false unless tid == type_id(:fire) || tid == type_id(:ice)
      return apply_percent(ABILITY_THICK_FAT,battler,ctx,:thick_fat,THICK_FAT_PERCENT)
    end
    def self.apply_adaptability(battler,ctx)
      return false unless ctx[:role] == :attacker && battler.respond_to?(:cg_pokemon_types)
      return false unless defined?(ALBERT_CG::POKEMON_COMBAT)
      key = ALBERT_CG::POKEMON_COMBAT.type_key(ctx[:type_id])
      return false if key == nil || !battler.cg_pokemon_types.include?(key)
      before = ctx[:damage].to_i
      return false if before <= 0 || ctx[:fixed_damage] == true
      after = [before * 4 / 3,1].max
      ctx[:damage] = after
      note_modifier(ABILITY_ADAPTABILITY,battler,:adaptability,before,after,ctx)
      return true
    end
    def self.apply_iron_fist(battler,ctx)
      return false unless ctx[:role] == :attacker
      return false unless PUNCH_IDENTIFIERS.include?(move_identifier(ctx[:move_id]))
      return apply_percent(ABILITY_IRON_FIST,battler,ctx,:iron_fist,IRON_FIST_PERCENT)
    end
    def self.apply_technician(battler,ctx)
      return false unless ctx[:role] == :attacker
      power = move_power(ctx[:move_id])
      return false unless power > 0 && power <= 60
      return apply_percent(ABILITY_TECHNICIAN,battler,ctx,:technician,TECHNICIAN_PERCENT)
    end
    def self.apply_tinted_lens(battler,ctx)
      return false unless ctx[:role] == :attacker
      rate = type_rate(ctx)
      return false unless rate > 0 && rate < 100
      return apply_percent(ABILITY_TINTED_LENS,battler,ctx,:tinted_lens,TINTED_LENS_PERCENT)
    end
    def self.apply_filter(battler,ctx)
      return false unless ctx[:role] == :defender && type_rate(ctx) > 100
      return apply_percent(ABILITY_FILTER,battler,ctx,:filter,FILTER_PERCENT)
    end
    def self.apply_solid_rock(battler,ctx)
      return false unless ctx[:role] == :defender && type_rate(ctx) > 100
      return apply_percent(ABILITY_SOLID_ROCK,battler,ctx,:solid_rock,SOLID_ROCK_PERCENT)
    end
    def self.apply_reckless(battler,ctx)
      return false unless ctx[:role] == :attacker && recoil_move?(ctx[:move_id])
      return apply_percent(ABILITY_RECKLESS,battler,ctx,:reckless,RECKLESS_PERCENT)
    end

    def self.register_handlers
      return false unless defined?(ALBERT_CG::ABILITY_V250)
      core = ALBERT_CG::ABILITY_V250
      core.register(ABILITY_THICK_FAT,:damage_modify,self,:apply_thick_fat)
      core.register(ABILITY_IRON_FIST,:damage_modify,self,:apply_iron_fist)
      core.register(ABILITY_ADAPTABILITY,:damage_modify,self,:apply_adaptability)
      core.register(ABILITY_TECHNICIAN,:damage_modify,self,:apply_technician)
      core.register(ABILITY_TINTED_LENS,:damage_modify,self,:apply_tinted_lens)
      core.register(ABILITY_FILTER,:damage_modify,self,:apply_filter)
      core.register(ABILITY_SOLID_ROCK,:damage_modify,self,:apply_solid_rock)
      core.register(ABILITY_RECKLESS,:damage_modify,self,:apply_reckless)
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
      for cfg in TEST_ALLIES
        configure_actor(cfg)
      end
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
        TEST_TROOP_ID,"Pokemon Ability E v2.5.4 AutoRegression",members)
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
      if current_round == 3
        @r3_storage_before = storage_size
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
      token = nil
      action = battler.action
      prefix = battler.actor? ? "A" : "E"
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

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted = true
      actual_troop_id = ($game_troop != nil && $game_troop.troop != nil) ? $game_troop.troop.id.to_i : 0
      assert_true("Ability Catalog count=373",defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.catalog_count == 373,
        "actual=" + (defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.catalog_count.to_s : "nil"))
      ids = defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.registered_ability_ids : []
      assert_true("Ability Batch E registers 8 IDs",HANDLED_ABILITY_IDS.all? { |id| ids.include?(id) })
      assert_true("Scene_Battle uses Ability E test troop",actual_troop_id == TEST_TROOP_ID,"actual=" + actual_troop_id.to_s)
      assert_true("Ability E ally count=4",test_allies.size == 4,"actual=" + test_allies.size.to_s)
      assert_true("Ability E starts with 4 active enemies",all_enemies.select { |b| b != nil && !b.hidden }.size == 4)
      assert_true("Ability E starts with 1 hidden Reckless reserve",all_enemies.select { |b| b != nil && b.hidden }.size == 1)
    end

    def self.ratio_ok?(rec,num,den)
      return false if rec == nil || rec[:before].to_i <= 0
      return rec[:after].to_i == [rec[:before].to_i * num.to_i / den.to_i,1].max
    end

    def self.assert_round
      r = current_round
      a = test_allies
      e = all_enemies
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      if r == 1
        checks = [
          [ABILITY_IRON_FIST,"Iron Fist boosts punching Move damage x1.2",6,5],
          [ABILITY_TECHNICIAN,"Technician boosts <=60 power damage x1.5",3,2],
          [ABILITY_TINTED_LENS,"Tinted Lens doubles resisted damage",2,1],
          [ABILITY_THICK_FAT,"Thick Fat halves Fire/Ice direct damage",1,2],
          [ABILITY_ADAPTABILITY,"Adaptability upgrades STAB final damage by x4/3",4,3],
        ]
        checks.each do |row|
          rec = @last_records[row[0]]
          ok = ratio_ok?(rec,row[2],row[3])
          @modifier_checks += 1 if ok
          assert_true(row[1],ok,"record=" + rec.inspect)
        end
        tint = @last_records[ABILITY_TINTED_LENS]
        assert_true("Tinted Lens regression target is actually resisted",tint != nil && tint[:type_rate].to_i > 0 && tint[:type_rate].to_i < 100,
          "record=" + tint.inspect)
      elsif r == 2
        rec = @last_records[ABILITY_FILTER]
        ok = ratio_ok?(rec,3,4) && rec[:type_rate].to_i > 100
        @modifier_checks += 1 if ok
        assert_true("Filter reduces super-effective damage to x0.75",ok,"record=" + rec.inspect)
        rec2 = @last_records[ABILITY_SOLID_ROCK]
        ok2 = ratio_ok?(rec2,3,4) && rec2[:type_rate].to_i > 100
        @modifier_checks += 1 if ok2
        assert_true("Solid Rock reduces super-effective damage to x0.75",ok2,"record=" + rec2.inspect)
      elsif r == 3
        switched = e[3] != nil && e[4] != nil && e[3].hidden && !e[4].hidden
        @lifecycle_checks += 1 if switched
        assert_true("Teleport deploys hidden Reckless reserve",switched,
          "E3_hidden=" + (e[3] == nil ? "nil" : e[3].hidden.to_s) + " E4_hidden=" + (e[4] == nil ? "nil" : e[4].hidden.to_s))
        storage_after = storage_size
        storage_ok = storage_after == @r3_storage_before.to_i
        @lifecycle_checks += 1 if storage_ok
        assert_true("Reckless reserve switch does not consume Storage Pokémon",storage_ok,
          "before=" + @r3_storage_before.to_s + " after=" + storage_after.to_s)
      elsif r == 4
        rec = @last_records[ABILITY_RECKLESS]
        ok = ratio_ok?(rec,6,5) && rec[:move_id].to_i == 38
        @modifier_checks += 1 if ok
        assert_true("Reckless boosts recoil Move damage x1.2",ok,"record=" + rec.inspect)
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
      log("SUMMARY rounds=4 failures=" + @failures.size.to_s +
        " ability_e=" + ability_covered_count.to_s + "/8" +
        " modifier_checks=" + @modifier_checks.to_i.to_s +
        " lifecycle_checks=" + @lifecycle_checks.to_i.to_s + " pending=333")
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
      @last_records = {}
      @modifier_checks = 0
      @lifecycle_checks = 0
      @actual = []
      @boot_asserted = false
      @r3_storage_before = 0
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
        ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_E_v2.5.4")
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

ALBERT_CG::ABILITY_E_V254.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Older Ability regression F11：Batch E 成為唯一最新版
#==============================================================================
if defined?(ALBERT_CG::ABILITY_D_V253)
  module ALBERT_CG; module ABILITY_D_V253; def self.f11_trigger?; return false; end; end; end
end
if defined?(ALBERT_CG::ABILITY_C_V252)
  module ALBERT_CG; module ABILITY_C_V252; def self.f11_trigger?; return false; end; end; end
end
if defined?(ALBERT_CG::ABILITY_B_V251)
  module ALBERT_CG; module ABILITY_B_V251; def self.f11_trigger?; return false; end; end; end
end
if defined?(ALBERT_CG::ABILITY_A_V250)
  module ALBERT_CG; module ABILITY_A_V250; def self.f11_trigger?; return false; end; end; end
end

class Game_Battler
  alias cg_v254e_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    return 100 if defined?(ALBERT_CG::ABILITY_E_V254) && ALBERT_CG::ABILITY_E_V254.active?
    return cg_v254e_ability_calc_hit(user,obj)
  end
  alias cg_v254e_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_E_V254) && ALBERT_CG::ABILITY_E_V254.active?
    return cg_v254e_ability_calc_eva(user,obj)
  end
  alias cg_v254e_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_E_V254) && ALBERT_CG::ABILITY_E_V254.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v254e_ability_priority_base_speed
  rescue
    return cg_v254e_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v254e_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_E_V254) && ALBERT_CG::ABILITY_E_V254.active?
      action = ALBERT_CG::ABILITY_E_V254.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v254e_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v254e_ability_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::ABILITY_E_V254.record_execution(battler) if defined?(ALBERT_CG::ABILITY_E_V254) && ALBERT_CG::ABILITY_E_V254.active?
    return cg_v254e_ability_execute_action
  end
  alias cg_v254e_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_E_V254) && ALBERT_CG::ABILITY_E_V254.active?
      ALBERT_CG::ABILITY_E_V254.finish_round_assertions
    end
    return cg_v254e_ability_turn_end
  end
  alias cg_v254e_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_E_V254) && ALBERT_CG::ABILITY_E_V254.active?
      return cg_v254e_ability_start_party_command
    end
    cg_v254e_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_E_V254.assert_bootstrap_once
    if ALBERT_CG::ABILITY_E_V254.finished?
      ALBERT_CG::ABILITY_E_V254.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_E_V254.prepare_round_actions
    start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v254e_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v254e_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_E_V254) && ALBERT_CG::ABILITY_E_V254.active?
        for cfg in ALBERT_CG::ABILITY_E_V254::TEST_ALLIES
          ALBERT_CG::ABILITY_E_V254.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_E_V254::TEST_LEVEL,false)
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
  alias cg_v254e_ability_scene_map_update update
  def update
    cg_v254e_ability_scene_map_update
    if !$game_temp.in_battle && !ALBERT_CG::ABILITY_E_V254.active? && ALBERT_CG::ABILITY_E_V254.f11_trigger?
      Sound.play_decision
      ALBERT_CG::ABILITY_E_V254.start_auto_test
    end
  end
end
