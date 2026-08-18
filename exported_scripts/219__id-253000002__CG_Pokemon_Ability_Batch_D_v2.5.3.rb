# RMVX_SCRIPT_INDEX: 219
# RMVX_SCRIPT_ID: 253000002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch D v2.5.3
# RMVX_SOURCE_SHA256: 8c8caeb050b497968e664e70a0ede45fda349e4c32c2851a1e2425cae1c319cf

#==============================================================================
# ■ CG Pokemon Ability Batch D v2.5.3 - Stat & Threshold Power
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.2a Ability Batch C PASS 基底與 v2.5.3 Modifier Authority 上，正式實作
#  第四批 8 個能力值／HP 閾值火力 Ability，並提供 Actual Scene_Battle deterministic
#  F11 regression。
#
# 【本批 Ability】
#   37 Huge Power    大力士：有效 ATK x2。
#   62 Guts          毅力：有主要異常時有效 ATK x1.5；Burn 時不受原本 ATK x0.5 懲罰。
#   63 Marvel Scale  神奇鱗片：有主要異常時有效 DEF x1.5。
#   65 Overgrow      茂盛：HP<=1/3 時 Grass damaging Move 傷害 x1.5。
#   66 Blaze         猛火：HP<=1/3 時 Fire damaging Move 傷害 x1.5。
#   67 Torrent       激流：HP<=1/3 時 Water damaging Move 傷害 x1.5。
#   68 Swarm         蟲之預感：HP<=1/3 時 Bug damaging Move 傷害 x1.5。
#   74 Pure Power    瑜伽之力：有效 ATK x2。
#
# 【主要設定項】
#  TEST_TROOP_ID = 706；F11 只啟動本 Batch D Regression。
#  HANDLED_ABILITY_IDS：本批 8 ID，Coverage 由 349 pending -> 341 pending。
#  TEST Convenience 為 TEST-only：略過 emerged、Battle BGM/BGS 靜音、背景 helper。
#
# 【機制規則】
#  1. Stat modifier 使用 v2.5.3 :stat_query；不改永久 Base Stats / Species Master。
#  2. Threshold type boost 使用 :damage_modify，在真正 execute_damage 前調整最終正 HP
#     damage；Fixed damage 不吃 Overgrow/Blaze/Torrent/Swarm。
#  3. Guts 的一般 Poison/Paralysis/Sleep/Freeze 狀態為 ATK x1.5；Burn 因既有
#     Move Core 已先做 ATK x0.5，本 handler 對該有效值 x3，使結果回到約原 ATK x1.5。
#  4. Marvel Scale 只檢查主要異常（含 Bad Poison 若該 state 存在），不把 Taunt、
#     Confusion、Trap 等 volatile 當作主要異常。
#  5. HP threshold 判定為 hp*3 <= maxhp；只在真正 damaging action 且 @hp_damage>0 時
#     發動，不把 Heal / Status Move / Fixed damage 誤乘倍率。
#  6. 所有有效 Ability 仍讀 cg_master_ability_id，尊重 Gastro Acid / Skill Swap /
#     Role Play / Transform 等 Battle-only Override/Suppression。
#
# 【可調參數】
#  STAT_DOUBLE_PERCENT = 200；STATUS_STAT_PERCENT = 150；THRESHOLD_POWER_PERCENT = 150。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11 一次，自動跑四回合並回地圖。
#
# 【實際範例】
#  Round1：Huge Power / Guts / Pure Power / Marvel Scale 走真實 Tackle damage formula。
#  Round2：低 HP Heracross / Venusaur / Charizard 分別驗 Swarm / Overgrow / Blaze。
#  Round3：Medicham Teleport -> hidden Blastoise，驗合法 battle reserve / Storage isolation。
#  Round4：低 HP Blastoise 水槍驗 Torrent。
#
# 【正式版要求】
#  Ability runtime 可保留；F11 regression / TEST Convenience 只屬開發版。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchD"] = "2.5.3"

module ALBERT_CG
  module ABILITY_D_V253
    VERSION = "2.5.3"
    TEST_TROOP_ID = 706
    TEST_LEVEL = 40
    VK_F11 = 0x7A
    STAT_DOUBLE_PERCENT = 200
    STATUS_STAT_PERCENT = 150
    THRESHOLD_POWER_PERCENT = 150

    ABILITY_HUGE_POWER   = 37
    ABILITY_GUTS         = 62
    ABILITY_MARVEL_SCALE = 63
    ABILITY_OVERGROW     = 65
    ABILITY_BLAZE        = 66
    ABILITY_TORRENT      = 67
    ABILITY_SWARM        = 68
    ABILITY_PURE_POWER   = 74

    HANDLED_ABILITY_IDS = [
      ABILITY_HUGE_POWER, ABILITY_GUTS, ABILITY_MARVEL_SCALE,
      ABILITY_OVERGROW, ABILITY_BLAZE, ABILITY_TORRENT,
      ABILITY_SWARM, ABILITY_PURE_POWER
    ]

    TEST_ALLIES = [
      {:dex=>184,:level=>40,:ability=>ABILITY_HUGE_POWER,:moves=>[33,150,150,150]},
      {:dex=>217,:level=>40,:ability=>ABILITY_GUTS,:moves=>[33,150,150,150]},
      {:dex=>214,:level=>40,:ability=>ABILITY_SWARM,:moves=>[210,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>308,:level=>40,:ability=>ABILITY_PURE_POWER,:moves=>[33,100,150,150]},
      {:dex=>350,:level=>40,:ability=>ABILITY_MARVEL_SCALE,:moves=>[150,150,150,150]},
      {:dex=>3,  :level=>40,:ability=>ABILITY_OVERGROW,:moves=>[22,150,150,150]},
      {:dex=>6,  :level=>40,:ability=>ABILITY_BLAZE,:moves=>[52,150,150,150]},
      {:dex=>9,  :level=>40,:ability=>ABILITY_TORRENT,:moves=>[55,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"STAT_MODIFIERS",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>1},
          {:kind=>:move,:move_id=>33,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>33,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
      {
        :name=>"THRESHOLD_OVERGROW_BLAZE_SWARM",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>210,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>22,:target=>1},
          3=>{:kind=>:move,:move_id=>52,:target=>2},
        }
      },
      {
        :name=>"TORRENT_RESERVE_SWITCH_IN",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>100,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
      {
        :name=>"TORRENT_WATER_POWER",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
          4=>{:kind=>:move,:move_id=>55,:target=>2},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,220,210,100, 200,180,170,160,0],
      :r2=>[10,100,90,220, 80,70,210,200,0],
      :r3=>[10,180,170,160, 200,190,150,140,0],
      :r4=>[10,180,170,160, 0,190,150,140,220],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M33","A2:M33","E0:M33","E1:M150","E2:M150","E3:M150","A3:M150"],
      2=>["A0:Guard","A3:M210","E2:M22","E3:M52","A1:M150","A2:M150","E0:M150","E1:M150"],
      3=>["A0:Guard","E1:M150","A1:M150","A2:M150","A3:M150","E2:M150","E3:M150","E0:M100"],
      4=>["A0:Guard","E4:M55","E1:M150","A1:M150","A2:M150","A3:M150","E2:M150","E3:M150"],
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

    def self.log_path
      return File.join(project_root,"Pokemon_Ability_D_AutoTest_v2_5_3.log")
    end

    def self.latest_log_path
      return File.join(project_root,"CG_AutoRegression_LATEST.log")
    end

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
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_D_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end

    def self.reset_log
      header = "CG POKEMON ABILITY D STAT + THRESHOLD POWER AUTO REGRESSION v2.5.3\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; stat query modifiers + HP threshold type power + reserve switch\r\n" +
        "BASELINE=v2.5.2a Ability Batch C Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_B_C_PASS=24 BATCH_D=8 PENDING=341\r\n" +
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

    def self.battler_token(b)
      return "nil" if b == nil
      return (b.actor? ? "A" : "E") + b.index.to_i.to_s
    rescue
      return "?"
    end

    def self.primary_status?(battler)
      return false if battler == nil || !defined?(ALBERT_CG::MOVE_EFFECT)
      for sid in ALBERT_CG::MOVE_EFFECT::PRIMARY_STATES
        return true if battler.state?(sid)
      end
      if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON)
        return true if battler.state?(ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON)
      end
      return false
    rescue
      return false
    end

    def self.threshold_active?(battler)
      return false if battler == nil || battler.maxhp.to_i <= 0 || battler.hp.to_i <= 0
      return battler.hp.to_i * 3 <= battler.maxhp.to_i
    rescue
      return false
    end

    def self.type_id(symbol)
      return 0 unless defined?(ALBERT_CG::POKEMON_COMBAT)
      table = ALBERT_CG::POKEMON_COMBAT::TYPE_IDS
      return table[symbol].to_i if table != nil && table.has_key?(symbol)
      return 0
    rescue
      return 0
    end

    def self.note_modifier(aid,battler,kind,before_value,after_value,ctx=nil)
      @ability_trigger_counts[aid.to_i] = @ability_trigger_counts[aid.to_i].to_i + 1
      @last_records[aid.to_i] = {
        :kind=>kind, :before=>before_value.to_i, :after=>after_value.to_i,
        :type_id=>(ctx == nil ? 0 : ctx[:type_id].to_i),
        :hp=>(battler == nil ? 0 : battler.hp.to_i),
        :maxhp=>(battler == nil ? 0 : battler.maxhp.to_i)
      }
      log("ABILITY_D_MOD ability=" + aid.to_i.to_s + " battler=" + battler_token(battler) +
        " kind=" + kind.to_s + " before=" + before_value.to_i.to_s +
        " after=" + after_value.to_i.to_s +
        (ctx == nil ? "" : " type_id=" + ctx[:type_id].to_i.to_s)) if active?
      return true
    rescue
      return true
    end

    #--------------------------------------------------------------------------
    # Ability handlers
    #--------------------------------------------------------------------------
    def self.apply_huge_power(battler,ctx)
      return false unless ctx[:stat] == :atk
      before = ctx[:value].to_i
      after = [before * STAT_DOUBLE_PERCENT / 100,1].max
      ctx[:value] = after
      note_modifier(ABILITY_HUGE_POWER,battler,:atk,before,after,ctx)
      return true
    end

    def self.apply_pure_power(battler,ctx)
      return false unless ctx[:stat] == :atk
      before = ctx[:value].to_i
      after = [before * STAT_DOUBLE_PERCENT / 100,1].max
      ctx[:value] = after
      note_modifier(ABILITY_PURE_POWER,battler,:atk,before,after,ctx)
      return true
    end

    def self.apply_guts(battler,ctx)
      return false unless ctx[:stat] == :atk && primary_status?(battler)
      before = ctx[:value].to_i
      burned = defined?(ALBERT_CG::MOVE_EFFECT) && battler.state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
      after = burned ? [before * 3,1].max : [before * STATUS_STAT_PERCENT / 100,1].max
      ctx[:value] = after
      note_modifier(ABILITY_GUTS,battler,:atk_status,before,after,ctx)
      return true
    end

    def self.apply_marvel_scale(battler,ctx)
      return false unless ctx[:stat] == :def && primary_status?(battler)
      before = ctx[:value].to_i
      after = [before * STATUS_STAT_PERCENT / 100,1].max
      ctx[:value] = after
      note_modifier(ABILITY_MARVEL_SCALE,battler,:def_status,before,after,ctx)
      return true
    end

    def self.apply_threshold_type(battler,ctx,aid,type_symbol)
      return false unless ctx[:role] == :attacker
      return false if ctx[:fixed_damage] == true
      return false unless threshold_active?(battler)
      return false unless ctx[:type_id].to_i == type_id(type_symbol)
      before = ctx[:damage].to_i
      return false if before <= 0
      after = [before * THRESHOLD_POWER_PERCENT / 100,1].max
      ctx[:damage] = after
      note_modifier(aid,battler,:threshold_power,before,after,ctx)
      return true
    end

    def self.apply_overgrow(battler,ctx)
      return apply_threshold_type(battler,ctx,ABILITY_OVERGROW,:grass)
    end
    def self.apply_blaze(battler,ctx)
      return apply_threshold_type(battler,ctx,ABILITY_BLAZE,:fire)
    end
    def self.apply_torrent(battler,ctx)
      return apply_threshold_type(battler,ctx,ABILITY_TORRENT,:water)
    end
    def self.apply_swarm(battler,ctx)
      return apply_threshold_type(battler,ctx,ABILITY_SWARM,:bug)
    end

    def self.register_handlers
      return false unless defined?(ALBERT_CG::ABILITY_V250)
      ALBERT_CG::ABILITY_MODIFIER_V253.ensure_triggers if defined?(ALBERT_CG::ABILITY_MODIFIER_V253)
      core = ALBERT_CG::ABILITY_V250
      core.register(ABILITY_HUGE_POWER,:stat_query,self,:apply_huge_power)
      core.register(ABILITY_GUTS,:stat_query,self,:apply_guts)
      core.register(ABILITY_MARVEL_SCALE,:stat_query,self,:apply_marvel_scale)
      core.register(ABILITY_OVERGROW,:damage_modify,self,:apply_overgrow)
      core.register(ABILITY_BLAZE,:damage_modify,self,:apply_blaze)
      core.register(ABILITY_TORRENT,:damage_modify,self,:apply_torrent)
      core.register(ABILITY_SWARM,:damage_modify,self,:apply_swarm)
      core.register(ABILITY_PURE_POWER,:stat_query,self,:apply_pure_power)
      return true
    end

    #--------------------------------------------------------------------------
    # Regression setup
    #--------------------------------------------------------------------------
    def self.configure_actor(cfg)
      actor = $game_actors[master.actor_id_for_dex(cfg[:dex])]
      return if actor == nil
      master.configure_actor(actor,cfg)
      actor.recover_all if actor.respond_to?(:recover_all)
      actor.cg_reset_stat_stages if actor.respond_to?(:cg_reset_stat_stages)
      actor.cg_v242_clear_runtime if actor.respond_to?(:cg_v242_clear_runtime)
    end

    def self.configure_enemy(cfg)
      master.configure_enemy_data(cfg)
    end

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
      xs = [ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,
            ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],
            ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],
            ALBERT_CG::GRID_COLUMN_Y[1]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg,i|
        configure_enemy(cfg)
        m = ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]),xs[i],ys[i])
        m.hidden = (i >= 4)
        members.push(m)
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID,"Pokemon Ability D v2.5.3 AutoRegression",members)
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
      a = test_allies
      e = all_enemies
      r = current_round
      if r == 1
        poison = ALBERT_CG::MOVE_EFFECT::STATE_POISON
        a[2].remove_state(poison) if a[2] != nil
        e[1].remove_state(poison) if e[1] != nil
        # Capture unmodified clear values before status is applied.
        if a[2] != nil
          aid = a[2].instance_variable_get(:@cg_master_ability_id)
          a[2].instance_variable_set(:@cg_master_ability_id,0)
          @r1_guts_clear_atk = a[2].cg_atk_stat.to_i
          a[2].instance_variable_set(:@cg_master_ability_id,aid)
          a[2].add_state(poison)
        end
        if e[1] != nil
          aid = e[1].instance_variable_get(:@cg_master_ability_id)
          e[1].instance_variable_set(:@cg_master_ability_id,0)
          @r1_marvel_clear_def = e[1].cg_def_stat.to_i
          e[1].instance_variable_set(:@cg_master_ability_id,aid)
          e[1].add_state(poison)
        end
      elsif r == 2
        [a[3],e[2],e[3]].each do |b|
          next if b == nil
          b.hp = [b.maxhp.to_i / 3,1].max
        end
      elsif r == 3
        # Round2 的 Swarm 真實傷害可能把 E0 壓得很低；Round3 的目的為 switch lifecycle，
        # 因此 test-only 回復 E0，避免傷害公式差異把 Teleport 測試誤變成 KO 測試。
        e[0].hp = e[0].maxhp if e[0] != nil && e[0].hp.to_i <= 0
        if e[4] != nil
          e[4].hp = [e[4].maxhp.to_i / 3,1].max
        end
        @r3_storage_before = storage_size
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

    def self.move_id_from_action(action)
      return 0 if action == nil || !action.skill?
      skill = $data_skills[action.skill_id]
      return 0 if skill == nil
      return ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i
    rescue
      return 0
    end

    def self.record_execution(battler)
      return unless active? && battler != nil
      token = battler_token(battler)
      action = battler.action
      if action != nil && action.guard?
        token += ":Guard"
      elsif action != nil && action.skill?
        token += ":M" + move_id_from_action(action).to_s
      else
        token += ":Attack"
      end
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + battler.name.to_s + " token=" + token)
    rescue
    end

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted = true
      a = test_allies
      e = all_enemies
      assert_true("Ability Catalog count=373",ALBERT_CG::ABILITY_V250.catalog_count.to_i == 373,
        "actual=" + ALBERT_CG::ABILITY_V250.catalog_count.to_i.to_s)
      ids = ALBERT_CG::ABILITY_V250.registered_ability_ids
      reg_ok = HANDLED_ABILITY_IDS.all? { |aid| ids.include?(aid) }
      assert_true("Ability Batch D registers 8 IDs",reg_ok)
      actual_troop_id = ($game_troop != nil && $game_troop.troop != nil) ? $game_troop.troop.id.to_i : 0
      assert_true("Scene_Battle uses Ability D test troop",actual_troop_id == TEST_TROOP_ID,
        "actual=" + actual_troop_id.to_s)
      assert_true("Ability D ally count=4",a.size == 4,"actual=" + a.size.to_s)
      assert_true("Ability D starts with 4 active enemies",e.select{|b| b != nil && !b.hidden}.size == 4)
      assert_true("Ability D starts with 1 hidden Torrent reserve",e.select{|b| b != nil && b.hidden}.size == 1)
    end

    def self.record_ok(aid,mult_num,mult_den=1)
      rec = @last_records[aid]
      return false if rec == nil
      return rec[:after].to_i == rec[:before].to_i * mult_num.to_i / mult_den.to_i
    end

    def self.assert_round
      r = current_round
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      a = test_allies
      e = all_enemies
      if r == 1
        huge_ok = record_ok(ABILITY_HUGE_POWER,2,1)
        @stat_checks += 1 if huge_ok
        assert_true("Huge Power doubles effective ATK",huge_ok,"record=" + @last_records[ABILITY_HUGE_POWER].inspect)

        pure_ok = record_ok(ABILITY_PURE_POWER,2,1)
        @stat_checks += 1 if pure_ok
        assert_true("Pure Power doubles effective ATK",pure_ok,"record=" + @last_records[ABILITY_PURE_POWER].inspect)

        guts = @last_records[ABILITY_GUTS]
        guts_expected = @r1_guts_clear_atk.to_i * 3 / 2
        guts_ok = guts != nil && guts[:after].to_i == guts_expected
        @stat_checks += 1 if guts_ok
        assert_true("Guts raises effective ATK x1.5 while statused",guts_ok,
          "clear=" + @r1_guts_clear_atk.to_s + " record=" + guts.inspect + " expected=" + guts_expected.to_s)

        marvel = @last_records[ABILITY_MARVEL_SCALE]
        marvel_expected = @r1_marvel_clear_def.to_i * 3 / 2
        marvel_ok = marvel != nil && marvel[:after].to_i == marvel_expected
        @stat_checks += 1 if marvel_ok
        assert_true("Marvel Scale raises effective DEF x1.5 while statused",marvel_ok,
          "clear=" + @r1_marvel_clear_def.to_s + " record=" + marvel.inspect + " expected=" + marvel_expected.to_s)

        poison = ALBERT_CG::MOVE_EFFECT::STATE_POISON
        a[2].remove_state(poison) if a[2] != nil
        e[1].remove_state(poison) if e[1] != nil
      elsif r == 2
        [[ABILITY_SWARM,a[3],:bug],[ABILITY_OVERGROW,e[2],:grass],[ABILITY_BLAZE,e[3],:fire]].each do |row|
          aid = row[0]; battler = row[1]; sym = row[2]
          rec = @last_records[aid]
          ok = rec != nil && rec[:after].to_i == rec[:before].to_i * 3 / 2 &&
               rec[:type_id].to_i == type_id(sym) && threshold_active?(battler)
          @power_checks += 1 if ok
          assert_true("Ability " + aid.to_s + " boosts low-HP " + sym.to_s + " damage x1.5",ok,
            "record=" + rec.inspect + " hp=" + (battler == nil ? "nil" : battler.hp.to_s + "/" + battler.maxhp.to_s))
        end
      elsif r == 3
        switch_ok = e[0].hidden && !e[4].hidden
        @lifecycle_checks += 1 if switch_ok
        assert_true("Teleport deploys hidden Torrent reserve",switch_ok,
          "E0_hidden=" + e[0].hidden.to_s + " E4_hidden=" + e[4].hidden.to_s)
        storage_after = storage_size
        storage_ok = storage_after == @r3_storage_before.to_i
        @lifecycle_checks += 1 if storage_ok
        assert_true("Torrent reserve switch does not consume Storage Pokémon",storage_ok,
          "before=" + @r3_storage_before.to_s + " after=" + storage_after.to_s)
        threshold_ok = threshold_active?(e[4])
        @lifecycle_checks += 1 if threshold_ok
        assert_true("Torrent reserve preserves low HP threshold on switch-in",threshold_ok,
          "hp=" + e[4].hp.to_i.to_s + "/" + e[4].maxhp.to_i.to_s)
      elsif r == 4
        rec = @last_records[ABILITY_TORRENT]
        ok = rec != nil && rec[:after].to_i == rec[:before].to_i * 3 / 2 &&
             rec[:type_id].to_i == type_id(:water) && threshold_active?(e[4])
        @power_checks += 1 if ok
        assert_true("Torrent boosts low-HP Water damage x1.5",ok,
          "record=" + rec.inspect + " hp=" + e[4].hp.to_i.to_s + "/" + e[4].maxhp.to_i.to_s)
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
      for aid in HANDLED_ABILITY_IDS
        count += 1 if @ability_trigger_counts[aid].to_i > 0
      end
      return count
    end

    def self.cleanup_test_overrides
      list = test_allies + all_enemies
      for b in list
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
        " ability_d=" + ability_covered_count.to_s + "/8" +
        " stat_checks=" + @stat_checks.to_i.to_s +
        " power_checks=" + @power_checks.to_i.to_s +
        " lifecycle_checks=" + @lifecycle_checks.to_i.to_s + " pending=341")
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
      @stat_checks = 0
      @power_checks = 0
      @lifecycle_checks = 0
      @actual = []
      @boot_asserted = false
      @r1_guts_clear_atk = 0
      @r1_marvel_clear_def = 0
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
        ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_D_v2.5.3")
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

ALBERT_CG::ABILITY_D_V253.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Older Ability regression F11：Batch D 成為唯一最新版
#==============================================================================
if defined?(ALBERT_CG::ABILITY_C_V252)
  module ALBERT_CG
    module ABILITY_C_V252
      def self.f11_trigger?; return false; end
    end
  end
end
if defined?(ALBERT_CG::ABILITY_B_V251)
  module ALBERT_CG
    module ABILITY_B_V251
      def self.f11_trigger?; return false; end
    end
  end
end
if defined?(ALBERT_CG::ABILITY_A_V250)
  module ALBERT_CG
    module ABILITY_A_V250
      def self.f11_trigger?; return false; end
    end
  end
end

#==============================================================================
# ■ Regression deterministic hit/evasion/SPE
#==============================================================================
class Game_Battler
  alias cg_v253d_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    return 100 if defined?(ALBERT_CG::ABILITY_D_V253) && ALBERT_CG::ABILITY_D_V253.active?
    return cg_v253d_ability_calc_hit(user,obj)
  end

  alias cg_v253d_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_D_V253) && ALBERT_CG::ABILITY_D_V253.active?
    return cg_v253d_ability_calc_eva(user,obj)
  end

  alias cg_v253d_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_D_V253) && ALBERT_CG::ABILITY_D_V253.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v253d_ability_priority_base_speed
  rescue
    return cg_v253d_ability_priority_base_speed
  end
end

#==============================================================================
# ■ Game_Enemy deterministic action
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v253d_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_D_V253) && ALBERT_CG::ABILITY_D_V253.active?
      action = ALBERT_CG::ABILITY_D_V253.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v253d_ability_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle Regression control
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v253d_ability_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::ABILITY_D_V253.record_execution(battler) if defined?(ALBERT_CG::ABILITY_D_V253) && ALBERT_CG::ABILITY_D_V253.active?
    return cg_v253d_ability_execute_action
  end

  alias cg_v253d_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_D_V253) && ALBERT_CG::ABILITY_D_V253.active?
      ALBERT_CG::ABILITY_D_V253.finish_round_assertions
    end
    return cg_v253d_ability_turn_end
  end

  alias cg_v253d_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_D_V253) && ALBERT_CG::ABILITY_D_V253.active?
      return cg_v253d_ability_start_party_command
    end
    cg_v253d_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_D_V253.assert_bootstrap_once
    if ALBERT_CG::ABILITY_D_V253.finished?
      ALBERT_CG::ABILITY_D_V253.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_D_V253.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle rebuild 後重套 Ability D test data
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v253d_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v253d_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_D_V253) && ALBERT_CG::ABILITY_D_V253.active?
        for cfg in ALBERT_CG::ABILITY_D_V253::TEST_ALLIES
          ALBERT_CG::ABILITY_D_V253.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_D_V253::TEST_LEVEL,false)
          human.recover_all
          human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
          human.instance_variable_set(:@cg_master_ability_id,0)
        end
      end
      return result
    end
  end
end

#==============================================================================
# ■ F11：v2.5.3 Ability Batch D 成為唯一最新版 AutoRegression
#==============================================================================
class Scene_Map < Scene_Base
  alias cg_v253d_ability_scene_map_update update
  def update
    cg_v253d_ability_scene_map_update
    if !$game_temp.in_battle && !ALBERT_CG::ABILITY_D_V253.active? &&
       ALBERT_CG::ABILITY_D_V253.f11_trigger?
      Sound.play_decision
      ALBERT_CG::ABILITY_D_V253.start_auto_test
    end
  end
end
