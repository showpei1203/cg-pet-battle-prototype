# RMVX_SCRIPT_INDEX: 235
# RMVX_SCRIPT_ID: 251200001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch M v2.5.12a
# RMVX_SOURCE_SHA256: 51039abb9eb01449eefbb2fc19ac13c15cfe71cfeb2a1b755ecc62072d44b267

#==============================================================================
# ■ CG Pokemon Ability Batch M v2.5.12a - Regression Fixture Range Fix
#------------------------------------------------------------------------------
# 【用途】
#  在 v2.5.11a Ability Batch L RPG Maker VX 實機 PASS 基底上，正式實作第十三批
#  8 個 Ability。此批集中處理「受擊反應、擊倒反應、屬性吸收、接觸反傷、
#  睡眠殘傷與天氣速度」，完全沿用既有 Ability Core lifecycle，不修改已 PASS
#  的 Move 937/937 與 Ability Batch A~L 正式頁。
#
# 【本批 Ability】
#  123 Bad Dreams    夢魘：回合末使所有睡眠中的對手失去 MaxHP 1/8。
#  130 Cursed Body   詛咒之軀：受到 damaging Move 後 30% 定身攻擊者本次 Move。
#  133 Weak Armor    碎裂鎧甲：受到 Physical damaging Move 後 DEF -1 / SPE +2。
#  146 Sand Rush     撥沙：Sandstorm 下有效 SPE x2。
#  153 Moxie         自信過度：以 damaging Move 擊倒目標後 ATK +1。
#  154 Justified     正義之心：受到 Dark damaging Move 後 ATK +1。
#  157 Sap Sipper    食草：Grass Move 對自己無效，並 ATK +1。
#  160 Iron Barbs    鐵刺：受到 Contact damaging Move 後，攻擊者失去 MaxHP 1/8。
#
# 【主要設定項】
#  TEST_TROOP_ID = 715
#  HANDLED_ABILITY_IDS = 8
#  Coverage：96/373 -> 104/373，pending 277 -> 269。
#
# 【機制規則】
#  1. Cursed Body / Weak Armor / Justified 使用 Ability Core :after_hit。
#     只有 damage_done > 0 的真正傷害才反應；Cursed Body 直接使用已 PASS 的
#     cg_v234_disable_move，因此完整沿用 Disable 4-turn lifecycle。
#  2. Moxie 使用 :after_ko，只有真正 execute_damage 將目標由 HP>0 打到 0 時觸發。
#  3. Sap Sipper 使用 :before_hit，Grass Move 直接 cancel，並把 hp_damage 清為 0；
#     Status / Physical / Special Grass Move 都使用同一屬性判定。
#  4. Iron Barbs 使用 :after_contact，沿用 Ability Core contact_action? 權威；
#     反傷為攻擊者 MaxHP 1/8，最低 1。
#  5. Bad Dreams 使用 :end_turn，只掃描有效 Ability 持有者的敵方 active battler；
#     Sleep State ID 沿用 MoveEffect Authority。
#  6. Sand Rush 使用已 PASS 的 SPE :stat_query bridge，直接讀 FIELD_V233 唯一天氣
#     state；不建立第二份 Weather runtime。
#  7. Ability 一律讀 cg_master_ability_id，因此尊重 Gastro Acid、Role Play、
#     Skill Swap、Transform 等 Battle-only override / suppression。
#  8. Regression 的 Cursed Body 30% 僅 TEST-only 固定成功；正式玩家戰鬥仍 rand(100)<30。
#  9. Round2 Bad Dreams 的 Sleep 在所有 Action 執行後、正式 Ability end_turn 前才注入，
#     避免 Sleep 影響 deterministic action order。Round3 進場前清除該 TEST-only Sleep。
# 10. TEST Convenience 只限 F11。正式 Release 必須恢復 emerged 訊息、BGM/BGS
#     與正常 VX 焦點行為。
# 11. v2.5.12a 僅修 Regression fixture：原 TEST dex 598/530 超出本專案正式 #0001~#0494
#     物種 Master 範圍，Troop setup 會略過，導致 E2/E3/E4 index 壓縮。改用 dex 24/28
#     作為 TEST-only Ability container；Ability ID 仍由 cfg[:ability] 明確覆寫，正式 handler 不變。
#
# 【可調參數】
#  CURSED_BODY_CHANCE=30 / BAD_DREAMS_DENOM=8 / IRON_BARBS_DENOM=8 /
#  SAND_RUSH_PERCENT=200 / WEAK_ARMOR_DEF=-1 / WEAK_ARMOR_SPE=2。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫。開發測試：地圖按 F11，自動進入 Actual Scene_Battle，
#  跑完三回合並輸出 Pokemon_Ability_M_AutoTest_v2_5_12a.log 與
#  CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Bite 命中 Justified -> ATK +1；Vine Whip 命中 Sap Sipper -> 0 damage + ATK +1；
#  Sandstorm 中 Sand Rush -> SPE x2；睡眠目標在 Bad Dreams 回合末失去 1/8 MaxHP。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchM"] = "2.5.12a"

module ALBERT_CG
  module ABILITY_M_V2512
    VERSION = "2.5.12a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 715
    VK_F11 = 0x7A

    ABILITY_BAD_DREAMS  = 123
    ABILITY_CURSED_BODY = 130
    ABILITY_WEAK_ARMOR  = 133
    ABILITY_SAND_RUSH   = 146
    ABILITY_MOXIE       = 153
    ABILITY_JUSTIFIED   = 154
    ABILITY_SAP_SIPPER  = 157
    ABILITY_IRON_BARBS  = 160

    HANDLED_ABILITY_IDS = [123,130,133,146,153,154,157,160]

    CURSED_BODY_CHANCE = 30
    BAD_DREAMS_DENOM = 8
    IRON_BARBS_DENOM = 8
    SAND_RUSH_PERCENT = 200
    WEAK_ARMOR_DEF = -1
    WEAK_ARMOR_SPE = 2

    TEST_ALLIES = [
      {:dex=>448,:level=>40,:ability=>ABILITY_CURSED_BODY,:moves=>[44,150,150,150]},
      {:dex=>128,:level=>40,:ability=>ABILITY_MOXIE,:moves=>[33,150,150,150]},
      {:dex=>3,  :level=>40,:ability=>ABILITY_SAP_SIPPER,:moves=>[33,150,150,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>91, :level=>40,:ability=>ABILITY_WEAK_ARMOR,:moves=>[33,150,150,150]},
      {:dex=>448,:level=>40,:ability=>ABILITY_JUSTIFIED,:moves=>[22,150,150,150]},
      {:dex=>24, :level=>40,:ability=>ABILITY_IRON_BARBS,:moves=>[150,100,150,150]},
      {:dex=>491,:level=>40,:ability=>ABILITY_BAD_DREAMS,:moves=>[150,150,150,150]},
      {:dex=>28, :level=>40,:ability=>ABILITY_SAND_RUSH,:moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"CURSED_WEAK_MOXIE_JUSTIFIED_SAP_IRON",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>44,:target=>1},
          {:kind=>:move,:move_id=>33,:target=>0},
          {:kind=>:move,:move_id=>33,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>33,:target=>1},
          1=>{:kind=>:move,:move_id=>22,:target=>3},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"BAD_DREAMS_AND_SAND_RUSH_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>1},
        ],
        :enemies=>{
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>100,:target=>0},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"SAND_RUSH_SPEED_STABILITY",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>1},
        ],
        :enemies=>{
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,270,260,250, 280,240,230,220,0],
      :r2=>[10,260,250,240, 0,230,100,220,0],
      :r3=>[10,240,230,220, 0,210,0,200,300],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","E0:M33","A1:M44","A2:M33","A3:M33","E1:M22","E2:M150","E3:M150"],
      2=>["A0:Guard","A1:M150","A2:M150","A3:M150","E1:M150","E3:M150","E2:M100"],
      3=>["A0:Guard","E4:M150","A1:M150","A2:M150","A3:M150","E1:M150","E3:M150"],
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
    def self.log_path; return File.join(project_root,"Pokemon_Ability_M_AutoTest_v2_5_12a.log"); end
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
          ALBERT_CG::PMD_INIT_TRACE.log("[ABILITY_M_AUTOTEST] " + text.to_s)
        end
      end
    rescue
    end

    def self.reset_log
      header = "CG POKEMON ABILITY M REACTIVE HIT + WEATHER SPEED AUTO REGRESSION v2.5.12a\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; reactive hit/KO + Bad Dreams + Sand Rush + reserve switch\r\n" +
        "BASELINE=v2.5.11a Ability Batch L Runtime PASS; Move pending=0\r\n" +
        "ABILITY_CATALOG=373 BATCH_A_TO_L_PASS=96 BATCH_M=8 PENDING=269\r\n" +
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n" +
        "REGRESSION_FIX=TEST enemy fixture now uses dex<=494 containers for Iron Barbs/Sand Rush; formal Ability handlers unchanged\r\n" +
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

    def self.physical_move?(skill)
      return false if skill == nil
      return skill.cg_pokemon_damage_class == :physical if skill.respond_to?(:cg_pokemon_damage_class)
      return skill.respond_to?(:physical_attack) && skill.physical_attack == true
    rescue
      return false
    end

    def self.weather_active?(symbol)
      return false unless defined?(ALBERT_CG::FIELD_V233)
      st = ALBERT_CG::FIELD_V233.state
      return st != nil && st.weather == symbol && st.weather_turns.to_i > 0
    rescue
      return false
    end

    def self.set_weather(symbol,turns)
      return false unless defined?(ALBERT_CG::FIELD_V233)
      st = ALBERT_CG::FIELD_V233.state
      return false if st == nil
      st.weather = symbol
      st.weather_turns = turns.to_i
      return true
    rescue
      return false
    end

    def self.sleep_state_id
      return defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_SLEEP : 46
    end

    def self.proc_roll?(aid,chance)
      return true if active? && aid.to_i == ABILITY_CURSED_BODY
      return rand(100) < chance.to_i
    rescue
      return false
    end

    def self.note_trigger(aid,battler,kind,data=nil)
      if active?
        @ability_trigger_counts[aid] = @ability_trigger_counts[aid].to_i + 1
        rec = {:ability=>aid,:kind=>kind,:battler=>battler}
        if data != nil
          data.each { |k,v| rec[k] = v }
        end
        @records[aid] = rec
        text = "ABILITY_M_TRIGGER ability=" + aid.to_s + " battler=" +
          (battler == nil ? "nil" : battler.name.to_s) + " kind=" + kind.to_s
        if data != nil
          parts = []
          data.each { |k,v| parts.push(k.to_s + "=" + v.to_s) unless k == :battler || k == :user || k == :target }
          text += " ctx={" + parts.join(",") + "}" unless parts.empty?
        end
        log(text)
      end
      return true
    rescue
      return true
    end

    def self.apply_cursed_body(battler,ctx)
      return false if battler == nil || ctx[:damage_done].to_i <= 0
      user = ctx[:user]
      mid = ctx[:move_id].to_i
      return false if user == nil || mid <= 0 || !user.respond_to?(:cg_v234_disable_move)
      return false unless proc_roll?(ABILITY_CURSED_BODY,CURSED_BODY_CHANCE)
      user.cg_v234_disable_move(mid)
      return note_trigger(ABILITY_CURSED_BODY,battler,:cursed_body,
        {:move_id=>mid,:disabled=>user.respond_to?(:cg_v234_disabled_move_id) ? user.cg_v234_disabled_move_id : 0})
    rescue
      return false
    end

    def self.apply_weak_armor(battler,ctx)
      return false if battler == nil || ctx[:damage_done].to_i <= 0
      return false unless physical_move?(ctx[:skill])
      return false unless battler.respond_to?(:cg_change_stat_stage)
      db = battler.cg_stat_stage(:def).to_i
      sb = battler.cg_stat_stage(:spe).to_i
      battler.cg_change_stat_stage(:def,WEAK_ARMOR_DEF)
      battler.cg_change_stat_stage(:spe,WEAK_ARMOR_SPE)
      da = battler.cg_stat_stage(:def).to_i
      sa = battler.cg_stat_stage(:spe).to_i
      return note_trigger(ABILITY_WEAK_ARMOR,battler,:weak_armor,
        {:def_before=>db,:def_after=>da,:spe_before=>sb,:spe_after=>sa})
    rescue
      return false
    end

    def self.apply_sand_rush(battler,ctx)
      return false unless ctx[:stat] == :spe && weather_active?(:sandstorm)
      before = ctx[:value].to_i
      return false if before <= 0
      after = [before * SAND_RUSH_PERCENT / 100,1].max
      ctx[:value] = after
      return note_trigger(ABILITY_SAND_RUSH,battler,:sand_rush,
        {:before=>before,:after=>after,:weather=>:sandstorm})
    rescue
      return false
    end

    def self.apply_moxie(battler,ctx)
      return false if battler == nil || !battler.respond_to?(:cg_change_stat_stage)
      before = battler.cg_stat_stage(:atk).to_i
      delta = battler.cg_change_stat_stage(:atk,1).to_i
      return false if delta == 0
      return note_trigger(ABILITY_MOXIE,battler,:moxie,
        {:before=>before,:after=>battler.cg_stat_stage(:atk).to_i,:ko_move=>ctx[:move_id].to_i})
    rescue
      return false
    end

    def self.apply_justified(battler,ctx)
      return false if battler == nil || ctx[:damage_done].to_i <= 0
      return false unless skill_type_id(ctx[:skill]) == type_id(:dark)
      return false unless battler.respond_to?(:cg_change_stat_stage)
      before = battler.cg_stat_stage(:atk).to_i
      delta = battler.cg_change_stat_stage(:atk,1).to_i
      return false if delta == 0
      return note_trigger(ABILITY_JUSTIFIED,battler,:justified,
        {:before=>before,:after=>battler.cg_stat_stage(:atk).to_i,:move_id=>ctx[:move_id].to_i})
    rescue
      return false
    end

    def self.apply_sap_sipper(battler,ctx)
      return false if battler == nil || skill_type_id(ctx[:skill]) != type_id(:grass)
      before = battler.respond_to?(:cg_stat_stage) ? battler.cg_stat_stage(:atk).to_i : 0
      if battler.respond_to?(:cg_change_stat_stage)
        battler.cg_change_stat_stage(:atk,1)
      end
      ctx[:cancel] = true
      ctx[:hp_damage] = 0
      after = battler.respond_to?(:cg_stat_stage) ? battler.cg_stat_stage(:atk).to_i : before
      return note_trigger(ABILITY_SAP_SIPPER,battler,:sap_sipper,
        {:before=>before,:after=>after,:move_id=>ctx[:move_id].to_i})
    rescue
      return false
    end

    def self.apply_iron_barbs(battler,ctx)
      return false if battler == nil || ctx[:damage_done].to_i <= 0
      user = ctx[:user]
      return false if user == nil || user.hp.to_i <= 0
      loss = [[user.maxhp.to_i / IRON_BARBS_DENOM,1].max,user.hp.to_i].min
      before = user.hp.to_i
      user.hp -= loss
      user.hp_damage = loss if user.respond_to?(:hp_damage=)
      @iron_barbs_attacker_after = user.hp.to_i if active?
      return note_trigger(ABILITY_IRON_BARBS,battler,:iron_barbs,
        {:before=>before,:after=>user.hp.to_i,:loss=>loss,:move_id=>ctx[:move_id].to_i})
    rescue
      return false
    end

    def self.apply_bad_dreams(battler,ctx)
      return false if battler == nil || core == nil
      sid = sleep_state_id
      total = 0
      count = 0
      core.opponents_of(battler).each do |target|
        next if target == nil || !target.state?(sid)
        dmg = [[target.maxhp.to_i / BAD_DREAMS_DENOM,1].max,target.hp.to_i].min
        next if dmg <= 0
        target.hp -= dmg
        target.hp_damage = dmg if target.respond_to?(:hp_damage=)
        total += dmg
        count += 1
      end
      return false if count <= 0
      return note_trigger(ABILITY_BAD_DREAMS,battler,:bad_dreams,
        {:targets=>count,:damage=>total})
    rescue
      return false
    end

    def self.register_handlers
      return false if core == nil
      core.register(ABILITY_BAD_DREAMS,:end_turn,self,:apply_bad_dreams)
      core.register(ABILITY_CURSED_BODY,:after_hit,self,:apply_cursed_body)
      core.register(ABILITY_WEAK_ARMOR,:after_hit,self,:apply_weak_armor)
      core.register(ABILITY_SAND_RUSH,:stat_query,self,:apply_sand_rush)
      core.register(ABILITY_MOXIE,:after_ko,self,:apply_moxie)
      core.register(ABILITY_JUSTIFIED,:after_hit,self,:apply_justified)
      core.register(ABILITY_SAP_SIPPER,:before_hit,self,:apply_sap_sipper)
      core.register(ABILITY_IRON_BARBS,:after_contact,self,:apply_iron_barbs)
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
        TEST_TROOP_ID,"Pokemon Ability M v2.5.12 AutoRegression",members)
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
      e = all_enemies
      if e[0] != nil
        e[0].recover_all if e[0].respond_to?(:recover_all)
        e[0].hp = 1
      end
      @r1_a3_hp_before = test_allies[3] == nil ? 0 : test_allies[3].hp.to_i
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
        e[4].recover_all if e[4] != nil && e[4].respond_to?(:recover_all)
      elsif current_round == 3
        a = test_allies
        sid = sleep_state_id
        a[1].remove_state(sid) if a[1] != nil && a[1].state?(sid)
        set_weather(:sandstorm,5)
        e = all_enemies
        if e[4] != nil
          old = e[4].instance_variable_get(:@cg_master_ability_id)
          e[4].instance_variable_set(:@cg_master_ability_id,0)
          @r3_sand_base_spe = e[4].cg_spe.to_i
          e[4].instance_variable_set(:@cg_master_ability_id,old)
          @r3_sand_actual_spe = e[4].cg_spe.to_i
        end
      end
    end

    def self.prepare_end_turn_preconditions
      return unless active? && current_round == 2
      a = test_allies
      return if a[1] == nil
      sid = sleep_state_id
      a[1].remove_state(sid) if a[1].state?(sid)
      a[1].add_state(sid)
      @r2_bad_dreams_before = a[1].hp.to_i
      @r2_bad_dreams_expected_loss = [a[1].maxhp.to_i / BAD_DREAMS_DENOM,1].max
      log("TEST_PRE_END Round2 sleep_target=A1 hp=" + @r2_bad_dreams_before.to_s +
        " expected_bad_dreams_loss=" + @r2_bad_dreams_expected_loss.to_s)
    rescue
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
      assert_true("Ability Batch M registers 8 IDs",HANDLED_ABILITY_IDS.all? { |id| ids.include?(id) })
      assert_true("Scene_Battle uses Ability M test troop",actual_troop_id == TEST_TROOP_ID,"actual=" + actual_troop_id.to_s)
      assert_true("Ability M ally count=4",test_allies.size == 4,"actual=" + test_allies.size.to_s)
      assert_true("Ability M starts with 4 active enemies",all_enemies.select { |b| b != nil && !b.hidden }.size == 4)
      assert_true("Ability M starts with 1 hidden Sand Rush reserve",all_enemies.select { |b| b != nil && b.hidden }.size == 1)
      assert_true("Weak Armor regression victim starts at 1 HP",all_enemies[0] != nil && all_enemies[0].hp.to_i == 1,
        all_enemies[0] == nil ? "nil" : "hp=" + all_enemies[0].hp.to_s)
    end

    def self.assert_round
      r = current_round
      a = test_allies
      e = all_enemies
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      if r == 1
        rec = @records[ABILITY_CURSED_BODY]
        ok = rec != nil && rec[:move_id].to_i == 33 && e[0] != nil &&
          e[0].respond_to?(:cg_v234_disabled_move_id) && e[0].cg_v234_disabled_move_id.to_i == 33
        @reactive_checks += 1 if ok
        assert_true("Cursed Body deterministically Disables the damaging Move",ok,
          "record=" + rec.inspect + " disabled=" + (e[0] == nil ? "nil" : e[0].cg_v234_disabled_move_id.to_s))

        rec = @records[ABILITY_WEAK_ARMOR]
        ok = rec != nil && rec[:def_after].to_i == rec[:def_before].to_i - 1 &&
          rec[:spe_after].to_i == rec[:spe_before].to_i + 2
        @reactive_checks += 1 if ok
        assert_true("Weak Armor applies DEF-1 and SPE+2 after Physical damage",ok,"record=" + rec.inspect)

        rec = @records[ABILITY_MOXIE]
        ok = rec != nil && a[2] != nil && a[2].cg_stat_stage(:atk).to_i == 1 && e[0] != nil && e[0].hp.to_i <= 0
        @reactive_checks += 1 if ok
        assert_true("Moxie raises ATK +1 after a real KO",ok,
          "atk=" + (a[2] == nil ? "nil" : a[2].cg_stat_stage(:atk).to_s) +
          " victim_hp=" + (e[0] == nil ? "nil" : e[0].hp.to_s))

        rec = @records[ABILITY_JUSTIFIED]
        ok = rec != nil && rec[:move_id].to_i == 44 && e[1] != nil && e[1].cg_stat_stage(:atk).to_i == 1
        @reactive_checks += 1 if ok
        assert_true("Justified raises ATK +1 after Dark damage",ok,"record=" + rec.inspect)

        rec = @records[ABILITY_IRON_BARBS]
        loss_ok = rec != nil && rec[:loss].to_i == [a[3].maxhp.to_i / IRON_BARBS_DENOM,1].max
        @reactive_checks += 1 if loss_ok
        assert_true("Iron Barbs deals 1/8 MaxHP contact recoil to attacker",loss_ok,"record=" + rec.inspect)

        rec = @records[ABILITY_SAP_SIPPER]
        sap_ok = rec != nil && rec[:move_id].to_i == 22 && a[3] != nil &&
          a[3].cg_stat_stage(:atk).to_i == 1 && @iron_barbs_attacker_after.to_i == a[3].hp.to_i
        @reactive_checks += 1 if sap_ok
        assert_true("Sap Sipper cancels Grass damage and raises ATK +1",sap_ok,
          "record=" + rec.inspect + " hp_after_iron=" + @iron_barbs_attacker_after.to_s +
          " hp_now=" + (a[3] == nil ? "nil" : a[3].hp.to_s))
      elsif r == 2
        before = @r2_bad_dreams_before.to_i
        expected_after = [before - @r2_bad_dreams_expected_loss.to_i,0].max
        bad_ok = a[1] != nil && a[1].hp.to_i == expected_after && @records[ABILITY_BAD_DREAMS] != nil
        @residual_checks += 1 if bad_ok
        assert_true("Bad Dreams removes sleeping opponent MaxHP 1/8 at end-turn",bad_ok,
          "before=" + before.to_s + " after=" + (a[1] == nil ? "nil" : a[1].hp.to_s) +
          " expected=" + expected_after.to_s)

        switched = e[2] != nil && e[4] != nil && e[2].hidden && !e[4].hidden
        @lifecycle_checks += 1 if switched
        assert_true("Teleport deploys hidden Sand Rush reserve",switched,
          "E2_hidden=" + (e[2] == nil ? "nil" : e[2].hidden.to_s) +
          " E4_hidden=" + (e[4] == nil ? "nil" : e[4].hidden.to_s))
        storage_after = storage_size
        storage_ok = storage_after == @r2_storage_before.to_i
        @lifecycle_checks += 1 if storage_ok
        assert_true("Sand Rush reserve switch does not consume Storage Pokemon",storage_ok,
          "before=" + @r2_storage_before.to_s + " after=" + storage_after.to_s)
      elsif r == 3
        expected_spe = [@r3_sand_base_spe.to_i * 2,1].max
        speed_ok = @r3_sand_base_spe.to_i > 0 && @r3_sand_actual_spe.to_i == expected_spe &&
          @records[ABILITY_SAND_RUSH] != nil
        @speed_checks += 1 if speed_ok
        assert_true("Sand Rush doubles effective SPE in Sandstorm",speed_ok,
          "base=" + @r3_sand_base_spe.to_s + " actual=" + @r3_sand_actual_spe.to_s +
          " expected=" + expected_spe.to_s)
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
        " ability_m=" + ability_covered_count.to_s + "/8" +
        " reactive_checks=" + @reactive_checks.to_i.to_s +
        " residual_checks=" + @residual_checks.to_i.to_s +
        " speed_checks=" + @speed_checks.to_i.to_s +
        " lifecycle_checks=" + @lifecycle_checks.to_i.to_s + " pending=269")
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
      @residual_checks = 0
      @speed_checks = 0
      @lifecycle_checks = 0
      @actual = []
      @boot_asserted = false
      @r2_storage_before = 0
      @r2_bad_dreams_before = 0
      @r2_bad_dreams_expected_loss = 0
      @r3_sand_base_spe = 0
      @r3_sand_actual_spe = 0
      @iron_barbs_attacker_after = 0
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
        ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_M_v2.5.12")
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

ALBERT_CG::ABILITY_M_V2512.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Older Ability regression F11：Batch M 成為唯一最新版
#==============================================================================
if defined?(ALBERT_CG::ABILITY_L_V2511)
  module ALBERT_CG; module ABILITY_L_V2511; def self.f11_trigger?; return false; end; end; end
end

class Game_Battler
  alias cg_v2512m_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil)
    return 100 if defined?(ALBERT_CG::ABILITY_M_V2512) && ALBERT_CG::ABILITY_M_V2512.active?
    return cg_v2512m_ability_calc_hit(user,obj)
  end

  alias cg_v2512m_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil)
    return 0 if defined?(ALBERT_CG::ABILITY_M_V2512) && ALBERT_CG::ABILITY_M_V2512.active?
    return cg_v2512m_ability_calc_eva(user,obj)
  end

  alias cg_v2512m_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_M_V2512) && ALBERT_CG::ABILITY_M_V2512.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v2512m_ability_priority_base_speed
  rescue
    return cg_v2512m_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2512m_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_M_V2512) && ALBERT_CG::ABILITY_M_V2512.active?
      action = ALBERT_CG::ABILITY_M_V2512.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v2512m_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2512m_ability_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::ABILITY_M_V2512.record_execution(battler) if defined?(ALBERT_CG::ABILITY_M_V2512) && ALBERT_CG::ABILITY_M_V2512.active?
    return cg_v2512m_ability_execute_action
  end

  alias cg_v2512m_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_M_V2512) && ALBERT_CG::ABILITY_M_V2512.active?
      ALBERT_CG::ABILITY_M_V2512.prepare_end_turn_preconditions
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_M_V2512.finish_round_assertions
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      else
        ALBERT_CG::ABILITY_M_V2512.finish_round_assertions
      end
    end
    return cg_v2512m_ability_turn_end
  end

  alias cg_v2512m_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_M_V2512) && ALBERT_CG::ABILITY_M_V2512.active?
      return cg_v2512m_ability_start_party_command
    end
    cg_v2512m_ability_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_M_V2512.assert_bootstrap_once
    if ALBERT_CG::ABILITY_M_V2512.finished?
      ALBERT_CG::ABILITY_M_V2512.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_M_V2512.prepare_round_actions
    start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2512m_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v2512m_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_M_V2512) && ALBERT_CG::ABILITY_M_V2512.active?
        for cfg in ALBERT_CG::ABILITY_M_V2512::TEST_ALLIES
          ALBERT_CG::ABILITY_M_V2512.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::ABILITY_M_V2512::TEST_LEVEL,false)
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
  alias cg_v2512m_ability_scene_map_update update
  def update
    cg_v2512m_ability_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_M_V2512)
    if ALBERT_CG::ABILITY_M_V2512.f11_trigger?
      ALBERT_CG::ABILITY_M_V2512.start_auto_test
    end
  end
end
