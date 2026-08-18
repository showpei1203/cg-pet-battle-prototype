# RMVX_SCRIPT_INDEX: 236
# RMVX_SCRIPT_ID: 251300001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch N v2.5.13
# RMVX_SOURCE_SHA256: 00a88be4697a56b1d0c12bc21fc3b6c45d0faccd0c38bdafb1de7b3b652423b1

#==============================================================================
# ■ CG Pokemon Ability Batch N v2.5.13 - Reactive Defense + Threshold
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.12a Ability Batch M RPG Maker VX 實機 PASS 基底上，正式實作第十四批
#  8 個 Ability。此批集中處理「受擊後能力反應、接觸反應、HP 門檻反應、
#  擊倒接觸反傷與受擊改變天氣」，直接沿用已 PASS 的 Ability Core
#  :after_hit / :after_contact / :ko lifecycle，不另造第二套傷害或回合系統。
#
# 【本批 Ability】
#  106 Aftermath         引爆：被 Contact Move 擊倒時，攻擊者失去 MaxHP 1/4。
#  183 Gooey             黏滑：受到 Contact damaging Move 後，攻擊者 SPE -1。
#  192 Stamina           持久力：受到 damaging Move 後 DEF +1。
#  195 Water Compaction  遇水凝固：被 Water Move 命中後 DEF +2。
#  201 Berserk           怒火沖天：攻擊使 HP 由半血以上跌到半血以下時 SPA +1。
#  221 Tangling Hair     捲髮：受到 Contact damaging Move 後，攻擊者 SPE -1。
#  243 Steam Engine      蒸汽機：被 Fire / Water Move 命中後 SPE +6。
#  245 Sand Spit         吐沙：受到 damaging Move 後建立 Sandstorm 5 turns。
#
# 【主要設定項】
#  TEST_TROOP_ID = 716
#  HANDLED_ABILITY_IDS = 8
#  Coverage：104/373 -> 112/373，pending 269 -> 261。
#
# 【機制規則】
#  1. Gooey / Tangling Hair 使用 :after_contact；只有 damage_done > 0 才降低攻擊者 SPE。
#     stage change 透過 v2.5.6 Stat Guard 的 with_stage_source(holder,:ability)，因此
#     會尊重 Clear Body / White Smoke / Full Metal Body，未來 Defiant 類互動也保留來源。
#  2. Stamina 使用 :after_hit，真正造成 damage_done > 0 後 DEF +1。
#  3. Water Compaction / Steam Engine 依被命中的 Move type 判定；不另建元素表，
#     直接讀既有 MoveEffect / Pokemon Combat type authority。
#  4. Berserk 只在本次傷害造成 hp_before > 1/2 MaxHP 且 hp_after <= 1/2 MaxHP 時 SPA +1；
#     已在半血以下時持續受擊不重複觸發。
#  5. Aftermath 掛在 :ko，只有 holder 被 Contact Move 真正由 HP>0 打到 0 時發動；
#     攻擊者失去 MaxHP 1/4，最低 1。
#  6. Sand Spit 使用已 PASS 的 ABILITY_WEATHER_V252.set_weather(:sandstorm, ..., 5)，
#     共用 FIELD_V233 唯一天氣 state 與 weather_changed 通知。
#  7. Ability 一律透過 Ability Core 讀 cg_master_ability_id，尊重既有 Battle-only
#     override / suppression。
#  8. Regression 只固定命中、行動順序與 HP precondition；正式玩家戰鬥 RNG 不改。
#  9. TEST Convenience 只限 F11。正式 Release 必須恢復 emerged 訊息、BGM/BGS
#     與正常 VX 焦點行為。
#
# 【可調參數】
#  AFTERMATH_DENOM=4 / BERSERK_SPA=1 / STAMINA_DEF=1 /
#  WATER_COMPACTION_DEF=2 / GOOEY_SPE=-1 / TANGLING_HAIR_SPE=-1 /
#  STEAM_ENGINE_SPE=6 / SAND_SPIT_TURNS=5。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫。開發測試：地圖按 F11，自動進入 Actual Scene_Battle，
#  跑完三回合並輸出 Pokemon_Ability_N_AutoTest_v2_5_13.log 與
#  CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Contact KO Aftermath -> attacker MaxHP -1/4；
#  Water Gun -> Water Compaction DEF +2；
#  Water Gun -> Steam Engine SPE +6；
#  Tackle -> Sand Spit -> Sandstorm 5 turns。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchN"] = "2.5.13"

module ALBERT_CG
  module ABILITY_N_V2513
    VERSION = "2.5.13"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 716
    VK_F11 = 0x7A

    ABILITY_AFTERMATH        = 106
    ABILITY_GOOEY            = 183
    ABILITY_STAMINA          = 192
    ABILITY_WATER_COMPACTION = 195
    ABILITY_BERSERK          = 201
    ABILITY_TANGLING_HAIR    = 221
    ABILITY_STEAM_ENGINE     = 243
    ABILITY_SAND_SPIT        = 245

    HANDLED_ABILITY_IDS = [106,183,192,195,201,221,243,245]

    AFTERMATH_DENOM = 4
    GOOEY_SPE = -1
    STAMINA_DEF = 1
    WATER_COMPACTION_DEF = 2
    BERSERK_SPA = 1
    TANGLING_HAIR_SPE = -1
    STEAM_ENGINE_SPE = 6
    SAND_SPIT_TURNS = 5

    TEST_ALLIES = [
      {:dex=>88, :level=>40,:ability=>ABILITY_GOOEY,        :moves=>[33,55,150,150]},
      {:dex=>128,:level=>40,:ability=>ABILITY_STAMINA,      :moves=>[55,150,150,150]},
      {:dex=>3,  :level=>40,:ability=>ABILITY_TANGLING_HAIR,:moves=>[33,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>109,:level=>40,:ability=>ABILITY_AFTERMATH,        :moves=>[150,150,150,150]},
      {:dex=>91, :level=>40,:ability=>ABILITY_WATER_COMPACTION, :moves=>[33,150,150,150]},
      {:dex=>143,:level=>40,:ability=>ABILITY_BERSERK,           :moves=>[33,150,150,150]},
      {:dex=>324,:level=>40,:ability=>ABILITY_STEAM_ENGINE,      :moves=>[33,100,150,150]},
      {:dex=>27, :level=>40,:ability=>ABILITY_SAND_SPIT,         :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"AFTERMATH_GOOEY_STAMINA_WATER_BERSERK_HAIR",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>0},
          {:kind=>:move,:move_id=>55,:target=>1},
          {:kind=>:move,:move_id=>33,:target=>2},
        ],
        :enemies=>{
          1=>{:kind=>:move,:move_id=>33,:target=>1},
          2=>{:kind=>:move,:move_id=>33,:target=>2},
          3=>{:kind=>:move,:move_id=>33,:target=>3},
        }
      },
      {
        :name=>"STEAM_ENGINE_AND_SAND_SPIT_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>55,:target=>3},
          {:kind=>:move,:move_id=>150,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>1},
        ],
        :enemies=>{
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>100,:target=>0},
        }
      },
      {
        :name=>"SAND_SPIT_WEATHER_STABILITY",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>4},
          {:kind=>:move,:move_id=>150,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>1},
        ],
        :enemies=>{
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,300,290,280, 200,270,260,250,0],
      :r2=>[10,300,290,280, 0,250,240,100,0],
      :r3=>[10,300,280,270, 0,240,230,0,220],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M33","A2:M55","A3:M33","E1:M33","E2:M33","E3:M33"],
      2=>["A0:Guard","A1:M55","A2:M150","A3:M150","E1:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","A1:M33","A2:M150","A3:M150","E1:M150","E2:M150","E4:M150"],
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
    def self.log_path; return File.join(project_root,"Pokemon_Ability_N_AutoTest_v2_5_13.log"); end
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
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_N_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end

    def self.reset_log
      header = "CG POKEMON ABILITY N REACTIVE DEFENSE + THRESHOLD AUTO REGRESSION v2.5.13\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; reactive defense/contact + threshold + Sand Spit weather + reserve switch\r\n" +
        "BASELINE=v2.5.12a Ability Batch M Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_TO_M_PASS=104 BATCH_N=8 PENDING=261\r\n" +
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
      return ALBERT_CG::POKEMON_COMBAT.type_id(symbol).to_i if ALBERT_CG::POKEMON_COMBAT.respond_to?(:type_id)
      table = ALBERT_CG::POKEMON_COMBAT::TYPE_IDS
      return table[symbol].to_i if table != nil && table.has_key?(symbol)
      return 0
    rescue
      return 0
    end

    def self.skill_type_id(skill)
      return 0 if skill == nil
      return skill.cg_pokemon_type_id.to_i if skill.respond_to?(:cg_pokemon_type_id)
      return 0
    rescue
      return 0
    end

    def self.note_trigger(aid,battler,kind,data=nil)
      if active?
        @ability_trigger_counts[aid] = @ability_trigger_counts[aid].to_i + 1
        rec = {:ability=>aid,:kind=>kind}
        if data != nil
          data.each { |k,v| rec[k] = v unless k == :battler || k == :user || k == :target }
        end
        @records[aid] = rec
        parts = []
        rec.each { |k,v| parts.push(k.to_s + "=" + v.to_s) unless k == :ability || k == :kind }
        log("ABILITY_N_TRIGGER ability=" + aid.to_s +
          " battler=" + (battler == nil ? "nil" : battler.name.to_s) +
          " kind=" + kind.to_s + (parts.empty? ? "" : " ctx={" + parts.join(",") + "}"))
      end
      return true
    rescue
      return true
    end

    def self.change_stage_from_ability(source,target,key,amount)
      return 0 if target == nil || !target.respond_to?(:cg_change_stat_stage)
      if defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256)
        return ALBERT_CG::ABILITY_STAT_GUARD_V256.with_stage_source(source,:ability,nil) do
          target.cg_change_stat_stage(key,amount)
        end
      end
      return target.cg_change_stat_stage(key,amount)
    rescue
      return 0
    end

    def self.weather_state
      return nil unless defined?(ALBERT_CG::FIELD_V233)
      return ALBERT_CG::FIELD_V233.state
    rescue
      return nil
    end

    def self.clear_weather
      st = weather_state
      return false if st == nil
      st.weather = nil
      st.weather_turns = 0
      return true
    rescue
      return false
    end

    def self.set_sandstorm(battler)
      if defined?(ALBERT_CG::ABILITY_WEATHER_V252)
        return ALBERT_CG::ABILITY_WEATHER_V252.set_weather(:sandstorm,battler,ABILITY_SAND_SPIT,SAND_SPIT_TURNS)
      end
      st = weather_state
      return false if st == nil
      st.weather = :sandstorm
      st.weather_turns = SAND_SPIT_TURNS
      return true
    rescue
      return false
    end

    def self.apply_after_math(battler,ctx)
      return false if battler == nil || ctx[:contact] != true
      user = ctx[:user]
      return false if user == nil || user.hp.to_i <= 0
      loss = [[user.maxhp.to_i / AFTERMATH_DENOM,1].max,user.hp.to_i].min
      before = user.hp.to_i
      user.hp -= loss
      user.hp_damage = loss if user.respond_to?(:hp_damage=)
      return note_trigger(ABILITY_AFTERMATH,battler,:aftermath,
        {:before=>before,:after=>user.hp.to_i,:loss=>loss,:move_id=>ctx[:move_id].to_i})
    rescue
      return false
    end

    def self.apply_gooey(battler,ctx)
      return false if battler == nil || ctx[:damage_done].to_i <= 0
      user = ctx[:user]
      return false if user == nil || user.hp.to_i <= 0
      before = user.respond_to?(:cg_stat_stage) ? user.cg_stat_stage(:spe).to_i : 0
      delta = change_stage_from_ability(battler,user,:spe,GOOEY_SPE).to_i
      after = user.respond_to?(:cg_stat_stage) ? user.cg_stat_stage(:spe).to_i : before
      return false if delta == 0
      return note_trigger(ABILITY_GOOEY,battler,:gooey,
        {:before=>before,:after=>after,:delta=>delta,:move_id=>ctx[:move_id].to_i})
    rescue
      return false
    end

    def self.apply_stamina(battler,ctx)
      return false if battler == nil || ctx[:damage_done].to_i <= 0
      return false unless battler.respond_to?(:cg_change_stat_stage)
      before = battler.cg_stat_stage(:def).to_i
      delta = battler.cg_change_stat_stage(:def,STAMINA_DEF).to_i
      after = battler.cg_stat_stage(:def).to_i
      return false if delta == 0
      return note_trigger(ABILITY_STAMINA,battler,:stamina,
        {:before=>before,:after=>after,:delta=>delta,:move_id=>ctx[:move_id].to_i})
    rescue
      return false
    end

    def self.apply_water_compaction(battler,ctx)
      return false if battler == nil || skill_type_id(ctx[:skill]) != type_id(:water)
      return false unless battler.respond_to?(:cg_change_stat_stage)
      before = battler.cg_stat_stage(:def).to_i
      delta = battler.cg_change_stat_stage(:def,WATER_COMPACTION_DEF).to_i
      after = battler.cg_stat_stage(:def).to_i
      return false if delta == 0
      return note_trigger(ABILITY_WATER_COMPACTION,battler,:water_compaction,
        {:before=>before,:after=>after,:delta=>delta,:move_id=>ctx[:move_id].to_i})
    rescue
      return false
    end

    def self.apply_berserk(battler,ctx)
      return false if battler == nil || ctx[:damage_done].to_i <= 0
      maxhp = battler.maxhp.to_i
      before_hp = ctx[:hp_before].to_i
      after_hp = ctx[:hp_after].to_i
      return false unless before_hp * 2 > maxhp && after_hp * 2 <= maxhp
      return false unless battler.respond_to?(:cg_change_stat_stage)
      before = battler.cg_stat_stage(:spa).to_i
      delta = battler.cg_change_stat_stage(:spa,BERSERK_SPA).to_i
      after = battler.cg_stat_stage(:spa).to_i
      return false if delta == 0
      return note_trigger(ABILITY_BERSERK,battler,:berserk,
        {:hp_before=>before_hp,:hp_after=>after_hp,:before=>before,:after=>after,:delta=>delta})
    rescue
      return false
    end

    def self.apply_tangling_hair(battler,ctx)
      return false if battler == nil || ctx[:damage_done].to_i <= 0
      user = ctx[:user]
      return false if user == nil || user.hp.to_i <= 0
      before = user.respond_to?(:cg_stat_stage) ? user.cg_stat_stage(:spe).to_i : 0
      delta = change_stage_from_ability(battler,user,:spe,TANGLING_HAIR_SPE).to_i
      after = user.respond_to?(:cg_stat_stage) ? user.cg_stat_stage(:spe).to_i : before
      return false if delta == 0
      return note_trigger(ABILITY_TANGLING_HAIR,battler,:tangling_hair,
        {:before=>before,:after=>after,:delta=>delta,:move_id=>ctx[:move_id].to_i})
    rescue
      return false
    end

    def self.apply_steam_engine(battler,ctx)
      return false if battler == nil
      tid = skill_type_id(ctx[:skill])
      return false unless tid == type_id(:fire) || tid == type_id(:water)
      return false unless battler.respond_to?(:cg_change_stat_stage)
      before = battler.cg_stat_stage(:spe).to_i
      delta = battler.cg_change_stat_stage(:spe,STEAM_ENGINE_SPE).to_i
      after = battler.cg_stat_stage(:spe).to_i
      return false if delta == 0
      return note_trigger(ABILITY_STEAM_ENGINE,battler,:steam_engine,
        {:before=>before,:after=>after,:delta=>delta,:move_id=>ctx[:move_id].to_i,:type_id=>tid})
    rescue
      return false
    end

    def self.apply_sand_spit(battler,ctx)
      return false if battler == nil || ctx[:damage_done].to_i <= 0
      return false unless set_sandstorm(battler)
      st = weather_state
      return note_trigger(ABILITY_SAND_SPIT,battler,:sand_spit,
        {:weather=>(st == nil ? nil : st.weather),:turns=>(st == nil ? 0 : st.weather_turns.to_i),
         :move_id=>ctx[:move_id].to_i})
    rescue
      return false
    end

    def self.register_handlers
      return false if core == nil
      core.register(ABILITY_AFTERMATH,:ko,self,:apply_after_math)
      core.register(ABILITY_GOOEY,:after_contact,self,:apply_gooey)
      core.register(ABILITY_STAMINA,:after_hit,self,:apply_stamina)
      core.register(ABILITY_WATER_COMPACTION,:after_hit,self,:apply_water_compaction)
      core.register(ABILITY_BERSERK,:after_hit,self,:apply_berserk)
      core.register(ABILITY_TANGLING_HAIR,:after_contact,self,:apply_tangling_hair)
      core.register(ABILITY_STEAM_ENGINE,:after_hit,self,:apply_steam_engine)
      core.register(ABILITY_SAND_SPIT,:after_hit,self,:apply_sand_spit)
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
        TEST_TROOP_ID,"Pokemon Ability N v2.5.13 AutoRegression",members)
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
      clear_weather
      a = test_allies
      e = all_enemies
      (a + e).each do |b|
        b.cg_reset_stat_stages if b != nil && b.respond_to?(:cg_reset_stat_stages)
      end
      if e[0] != nil
        e[0].recover_all if e[0].respond_to?(:recover_all)
        e[0].hp = 1
      end
      if e[2] != nil
        e[2].recover_all if e[2].respond_to?(:recover_all)
        e[2].hp = e[2].maxhp.to_i / 2 + 1
        @r1_berserk_start_hp = e[2].hp.to_i
      end
      return true
    rescue
      return false
    end

    def self.prepare_round_preconditions
      if current_round == 1
        install_round1_conditions
      elsif current_round == 2
        @r2_storage_before = storage_size
        e = all_enemies
        if e[3] != nil
          e[3].cg_reset_stat_stages if e[3].respond_to?(:cg_reset_stat_stages)
        end
        e[4].recover_all if e[4] != nil && e[4].respond_to?(:recover_all)
      elsif current_round == 3
        clear_weather
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

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted = true
      install_round1_conditions
      actual_troop_id = ($game_troop != nil && $game_troop.troop != nil) ? $game_troop.troop.id.to_i : 0
      assert_true("Ability Catalog count=373",core != nil && core.catalog_count == 373,
        "actual=" + (core == nil ? "nil" : core.catalog_count.to_s))
      ids = core == nil ? [] : core.registered_ability_ids
      assert_true("Ability Batch N registers 8 IDs",HANDLED_ABILITY_IDS.all? { |id| ids.include?(id) })
      assert_true("Scene_Battle uses Ability N test troop",actual_troop_id == TEST_TROOP_ID,"actual=" + actual_troop_id.to_s)
      assert_true("Ability N ally count=4",test_allies.size == 4,"actual=" + test_allies.size.to_s)
      assert_true("Ability N starts with 4 active enemies",all_enemies.select { |b| b != nil && !b.hidden }.size == 4)
      assert_true("Ability N starts with 1 hidden Sand Spit reserve",all_enemies.select { |b| b != nil && b.hidden }.size == 1)
      assert_true("Aftermath regression victim starts at 1 HP",all_enemies[0] != nil && all_enemies[0].hp.to_i == 1,
        all_enemies[0] == nil ? "nil" : "hp=" + all_enemies[0].hp.to_s)
      assert_true("Berserk regression victim starts just above half HP",
        all_enemies[2] != nil && all_enemies[2].hp.to_i * 2 > all_enemies[2].maxhp.to_i,
        all_enemies[2] == nil ? "nil" : "hp=" + all_enemies[2].hp.to_s + "/" + all_enemies[2].maxhp.to_s)
    end

    def self.assert_round
      r = current_round
      a = test_allies
      e = all_enemies
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      if r == 1
        rec = @records[ABILITY_AFTERMATH]
        ok = rec != nil && rec[:loss].to_i == [a[1].maxhp.to_i / AFTERMATH_DENOM,1].max && e[0] != nil && e[0].hp.to_i <= 0
        @reactive_checks += 1 if ok
        assert_true("Aftermath damages contact attacker by MaxHP 1/4 after real KO",ok,
          rec == nil ? "record=nil" : "loss=" + rec[:loss].to_s + " attacker=" + rec[:before].to_s + "->" + rec[:after].to_s)

        rec = @records[ABILITY_WATER_COMPACTION]
        ok = rec != nil && rec[:before].to_i == 0 && rec[:after].to_i == 2
        @reactive_checks += 1 if ok
        assert_true("Water Compaction raises DEF +2 after Water hit",ok,
          rec == nil ? "record=nil" : "def=" + rec[:before].to_s + "->" + rec[:after].to_s)

        rec = @records[ABILITY_BERSERK]
        ok = rec != nil && e[2] != nil && e[2].cg_stat_stage(:spa).to_i == 1 &&
          rec[:hp_before].to_i * 2 > e[2].maxhp.to_i && rec[:hp_after].to_i * 2 <= e[2].maxhp.to_i
        @threshold_checks += 1 if ok
        assert_true("Berserk raises SPA +1 when damage crosses half HP",ok,
          rec == nil ? "record=nil" : "hp=" + rec[:hp_before].to_s + "->" + rec[:hp_after].to_s + " spa=" + rec[:after].to_s)

        rec = @records[ABILITY_GOOEY]
        ok = rec != nil && rec[:before].to_i == 0 && rec[:after].to_i == -1
        @contact_checks += 1 if ok
        assert_true("Gooey lowers contact attacker SPE -1",ok,
          rec == nil ? "record=nil" : "spe=" + rec[:before].to_s + "->" + rec[:after].to_s)

        rec = @records[ABILITY_STAMINA]
        ok = rec != nil && rec[:before].to_i == 0 && rec[:after].to_i == 1
        @reactive_checks += 1 if ok
        assert_true("Stamina raises DEF +1 after damage",ok,
          rec == nil ? "record=nil" : "def=" + rec[:before].to_s + "->" + rec[:after].to_s)

        rec = @records[ABILITY_TANGLING_HAIR]
        ok = rec != nil && rec[:before].to_i == 0 && rec[:after].to_i == -1
        @contact_checks += 1 if ok
        assert_true("Tangling Hair lowers contact attacker SPE -1",ok,
          rec == nil ? "record=nil" : "spe=" + rec[:before].to_s + "->" + rec[:after].to_s)
      elsif r == 2
        rec = @records[ABILITY_STEAM_ENGINE]
        ok = rec != nil && rec[:before].to_i == 0 && rec[:after].to_i == 6
        @reactive_checks += 1 if ok
        assert_true("Steam Engine raises SPE +6 after Water hit",ok,
          rec == nil ? "record=nil" : "spe=" + rec[:before].to_s + "->" + rec[:after].to_s)

        switched = e[3] != nil && e[4] != nil && e[3].hidden && !e[4].hidden
        @lifecycle_checks += 1 if switched
        assert_true("Teleport deploys hidden Sand Spit reserve",switched,
          "E3_hidden=" + (e[3] == nil ? "nil" : e[3].hidden.to_s) +
          " E4_hidden=" + (e[4] == nil ? "nil" : e[4].hidden.to_s))
        storage_after = storage_size
        storage_ok = storage_after == @r2_storage_before.to_i
        @lifecycle_checks += 1 if storage_ok
        assert_true("Sand Spit reserve switch does not consume Storage Pokemon",storage_ok,
          "before=" + @r2_storage_before.to_s + " after=" + storage_after.to_s)
      elsif r == 3
        rec = @records[ABILITY_SAND_SPIT]
        st = weather_state
        ok = rec != nil && rec[:weather] == :sandstorm && st != nil && st.weather == :sandstorm && st.weather_turns.to_i > 0
        @weather_checks += 1 if ok
        assert_true("Sand Spit creates Sandstorm after taking damage",ok,
          "record_weather=" + (rec == nil ? "nil" : rec[:weather].to_s) +
          " field=" + (st == nil ? "nil" : st.weather.to_s) +
          " turns=" + (st == nil ? "nil" : st.weather_turns.to_s))
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
        " ability_n=" + ability_covered_count.to_s + "/8" +
        " reactive_checks=" + @reactive_checks.to_i.to_s +
        " contact_checks=" + @contact_checks.to_i.to_s +
        " threshold_checks=" + @threshold_checks.to_i.to_s +
        " weather_checks=" + @weather_checks.to_i.to_s +
        " lifecycle_checks=" + @lifecycle_checks.to_i.to_s + " pending=261")
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
      @records = {}
      @reactive_checks = 0
      @contact_checks = 0
      @threshold_checks = 0
      @weather_checks = 0
      @lifecycle_checks = 0
      @actual = []
      @boot_asserted = false
      @r2_storage_before = 0
      @r1_berserk_start_hp = 0
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
        ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_N_v2.5.13")
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

ALBERT_CG::ABILITY_N_V2513.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Older Ability regression F11：Batch N 成為唯一最新版
#==============================================================================
if defined?(ALBERT_CG::ABILITY_M_V2512)
  module ALBERT_CG; module ABILITY_M_V2512; def self.f11_trigger?; return false; end; end; end
end

class Game_Battler
  alias cg_v2513n_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    return 100 if defined?(ALBERT_CG::ABILITY_N_V2513) && ALBERT_CG::ABILITY_N_V2513.active?
    return cg_v2513n_ability_calc_hit(user,obj)
  end

  alias cg_v2513n_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_N_V2513) && ALBERT_CG::ABILITY_N_V2513.active?
    return cg_v2513n_ability_calc_eva(user,obj)
  end

  alias cg_v2513n_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_N_V2513) && ALBERT_CG::ABILITY_N_V2513.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v2513n_ability_priority_base_speed
  rescue
    return cg_v2513n_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2513n_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_N_V2513) && ALBERT_CG::ABILITY_N_V2513.active?
      action = ALBERT_CG::ABILITY_N_V2513.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v2513n_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2513n_ability_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::ABILITY_N_V2513.record_execution(battler) if defined?(ALBERT_CG::ABILITY_N_V2513) && ALBERT_CG::ABILITY_N_V2513.active?
    return cg_v2513n_ability_execute_action
  end

  alias cg_v2513n_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_N_V2513) && ALBERT_CG::ABILITY_N_V2513.active?
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_N_V2513.finish_round_assertions
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      else
        ALBERT_CG::ABILITY_N_V2513.finish_round_assertions
      end
    end
    return cg_v2513n_ability_turn_end
  end

  alias cg_v2513n_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_N_V2513) && ALBERT_CG::ABILITY_N_V2513.active?
      return cg_v2513n_ability_start_party_command
    end
    cg_v2513n_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_N_V2513.assert_bootstrap_once
    if ALBERT_CG::ABILITY_N_V2513.finished?
      ALBERT_CG::ABILITY_N_V2513.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_N_V2513.prepare_round_actions
    start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2513n_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v2513n_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_N_V2513) && ALBERT_CG::ABILITY_N_V2513.active?
        for cfg in ALBERT_CG::ABILITY_N_V2513::TEST_ALLIES
          ALBERT_CG::ABILITY_N_V2513.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_N_V2513::TEST_LEVEL,false)
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
  alias cg_v2513n_ability_scene_map_update update
  def update
    cg_v2513n_ability_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_N_V2513)
    if ALBERT_CG::ABILITY_N_V2513.f11_trigger?
      ALBERT_CG::ABILITY_N_V2513.start_auto_test
    end
  end
end
