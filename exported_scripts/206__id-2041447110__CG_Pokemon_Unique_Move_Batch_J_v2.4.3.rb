# RMVX_SCRIPT_INDEX: 206
# RMVX_SCRIPT_ID: 2041447110
# RMVX_SCRIPT_NAME: CG Pokemon Unique Move Batch J v2.4.3
# RMVX_SOURCE_SHA256: 4f16ff68d0ace3d59b64e159b9808da09c0cf9b4df67bcd781a97fe9fda4867f

#==============================================================================
# ■ CG Pokemon Unique Move Batch J v2.4.3
#------------------------------------------------------------------------------
# 【用途】
#  接續 v2.4.2c 已取得 RPG Maker VX 實機 PASS 的 Unique Batch I，處理剩餘
#  12 招中的 Switch / Sacrifice Lifecycle Batch J：
#    226 Baton Pass／接棒
#    361 Healing Wish／治癒之願
#    461 Lunar Dance／新月舞
#
#  本頁只重用既有正式 Runtime，不建立第二套隊伍或倉庫規則：
#    - v2.3.5a Force Switch / hidden troop reserve / Grid / Entry Hazard lifecycle
#    - v2.3.4g Substitute runtime
#    - v2.3.0 Stat Stage runtime
#    - v2.3.1 Primary Status / Aqua Ring runtime
#    - v2.3.7a / v2.3.8a / v2.4.2c battle-only identity cleanup chain
#
# 【正式隊伍／候補規則】
#  1. 正式玩家戰鬥仍是 1 Human + 3 Pokémon 同時在場，沒有一般自由換寵 Command。
#  2. 本 Batch 絕不把 Storage Pokémon 自動當 battle reserve。
#  3. 合法 replacement 來源只沿用 Force Switch Runtime：
#     - 敵方：Troop 原生 hidden、存活 Pokémon member。
#     - 我方：只有未來其他正式系統明確提供 cg_force_switch_reserve_pets 時才可使用。
#  4. 沒有合法 reserve 時，Baton Pass / Healing Wish / Lunar Dance 都失敗；
#     Healing Wish / Lunar Dance 不會先自殺再發現沒人可換。
#
# 【Baton Pass／接棒規則】
#  1. 成功時 outgoing 隱藏成 battle reserve，replacement 進入完全相同 Grid slot。
#  2. 傳遞白名單只包含目前專案已具安全 Runtime Authority 的項目：
#     - 7 個 Stat Stage：ATK/DEF/SpA/SpD/SPE/Accuracy/Evasion。
#     - Substitute 的剩餘 shield HP。
#     - Aqua Ring。
#     - Ingrain。
#  3. 不傳遞：Transform / Sketch battle identity、last_move / called_move、Disable、Encore、
#     Taunt、Destiny Bond、Grudge、Protect、Trap、Leech Seed、Yawn、Perish 等個體／行動記憶。
#     這些仍走既有 switch-out clear chain，避免把「誰做過什麼」錯塞給下一隻 Pokémon。
#  4. Baton Pass 是 Move 驅動的 voluntary replacement：個體 Trap / Ingrain 不阻止它；
#     但全場 Fairy Lock 生效時仍視為禁止換位。
#  5. replacement 不取得本回合額外行動；換入後正常套用 Entry Hazard。
#
# 【Healing Wish／治癒之願規則】
#  1. 先確認有合法 reserve，才讓使用者 HP=0 並離場。
#  2. replacement 進入原 Grid slot、套用 Entry Hazard 後，若仍存活：
#     - HP 回滿。
#     - 清除 Primary Status：Poison / Bad Poison / Paralysis / Sleep / Freeze / Burn。
#     - MP 不回復。
#  3. 本專案 PP 已改為共享 MP，因此 Healing Wish 不碰 MP。
#
# 【Lunar Dance／新月舞規則】
#  與 Healing Wish 相同，但 replacement 額外 MP 回滿；這就是本專案對原作 PP 回復的
#  正式 MP adaptation，不另外建立 PP 欄位。
#
# 【可調參數】
#  TEST_TROOP_ID = 701
#  TEST_LEVEL    = 40
#  BATON_TRANSFER_STAGE_KEYS = [:atk,:def,:spa,:spd,:spe,:accuracy,:evasion]
#
# 【事件／腳本呼叫方式】
#  正常戰鬥不需事件呼叫；Move Skill Effect 自動進入本 Runtime。
#  Debug 可直接：
#    ALBERT_CG::UNIQUE_J_V243.apply_baton_pass(user)
#    ALBERT_CG::UNIQUE_J_V243.apply_healing_wish(user, false)
#    ALBERT_CG::UNIQUE_J_V243.apply_healing_wish(user, true)   # Lunar Dance
#
# 【實際範例】
#  E0 有 ATK +2、SPE -1、Substitute 40 HP、Aqua Ring、Ingrain，E4 為 hidden reserve。
#  E0 使用 Baton Pass：E0 隱藏，E4 進入 E0 的 Grid slot；E4 取得上述白名單狀態，
#  E0 自己的 Stage/Substitute/Aqua Ring/Ingrain 被清除，Storage 完全不參與。
#
# 【F11 deterministic AutoRegression】
#  地圖畫面按 F11，執行 4 回合真正 Scene_Battle：
#    R1 Baton Pass：E0 -> hidden E4，驗證 Grid、Stage、Substitute、Aqua Ring、Ingrain。
#    R2 Healing Wish：E1 sacrifice -> E5，驗證 full HP + cure，MP 不回滿。
#    R3 Lunar Dance：E2 sacrifice -> E6，驗證 full HP + cure + full MP。
#    R4 Player no-reserve Baton Pass：A1 必須正常失敗，不能碰 Storage、不能離場。
#  所有行動順序、前置 HP/MP/State/Stage 與 EXPECTED 都由本頁固定。
#
# 【成功標準】
#  RPG Maker VX 實機 LOG 最後必須為：
#    RESULT=PASS
#    SUMMARY rounds=4 failures=0 unique_j_moves=3/3 transfer_checks=... heal_checks=... lifecycle_checks=...
#
# 【重要】
#  v2.4.3 在取得使用者 RPG Maker VX 實機 LOG 前，只能稱 TEST BUILD / static ready，
#  不得宣稱 Runtime PASS。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonUniqueMoveBatchJ"] = "2.4.3"

module ALBERT_CG
  module UNIQUE_J_V243
    VERSION = "2.4.3"

    MOVE_BATON_PASS   = 226
    MOVE_HEALING_WISH = 361
    MOVE_LUNAR_DANCE  = 461
    HANDLED_MOVE_IDS = [MOVE_BATON_PASS, MOVE_HEALING_WISH, MOVE_LUNAR_DANCE]

    BATON_TRANSFER_STAGE_KEYS = [:atk,:def,:spa,:spd,:spe,:accuracy,:evasion]
    TEST_TROOP_ID = 701
    TEST_LEVEL = 40
    VK_F11 = 0x7A

    # A1 deliberately owns Baton Pass so R4 can prove player no-reserve failure.
    TEST_ALLIES = [
      {:dex=>133,:level=>40,:ability=>50,:moves=>[226,150,33,33]},
      {:dex=>25, :level=>40,:ability=>9, :moves=>[150,33,33,33]},
      {:dex=>7,  :level=>40,:ability=>67,:moves=>[150,33,33,33]},
    ]

    # E0-E3 active. E4-E6 are hidden reserves consumed by R1/R2/R3.
    TEST_ENEMIES = [
      {:dex=>133,:level=>40,:ability=>50, :moves=>[226,150,33,33]},
      {:dex=>282,:level=>40,:ability=>28, :moves=>[361,150,33,33]},
      {:dex=>488,:level=>40,:ability=>26, :moves=>[461,150,33,33]},
      {:dex=>143,:level=>40,:ability=>47, :moves=>[150,150,33,33]},
      {:dex=>1,  :level=>40,:ability=>65, :moves=>[150,150,33,33]},
      {:dex=>4,  :level=>40,:ability=>66, :moves=>[150,150,33,33]},
      {:dex=>7,  :level=>40,:ability=>67, :moves=>[150,150,33,33]},
    ]

    ROUND_PLANS = [
      {
        :name=>"BATON_PASS_TRANSFER",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>226,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
      {
        :name=>"HEALING_WISH_SACRIFICE",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          1=>{:kind=>:move,:move_id=>361,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
          4=>{:kind=>:move,:move_id=>150,:target=>4},
        }
      },
      {
        :name=>"LUNAR_DANCE_SACRIFICE",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          2=>{:kind=>:move,:move_id=>461,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
          4=>{:kind=>:move,:move_id=>150,:target=>4},
          5=>{:kind=>:move,:move_id=>150,:target=>5},
        }
      },
      {
        :name=>"PLAYER_NO_RESERVE_BATON_PASS",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>226,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          3=>{:kind=>:move,:move_id=>150,:target=>3},
          4=>{:kind=>:move,:move_id=>150,:target=>4},
          5=>{:kind=>:move,:move_id=>150,:target=>5},
          6=>{:kind=>:move,:move_id=>150,:target=>6},
        }
      },
    ]

    # list order = A0-A3 + E0-E6
    TEST_SPEEDS = {
      :r1=>[10,80,70,60, 160,120,110,100,90,50,40],
      :r2=>[10,80,70,60, 50,160,120,110,100,90,40],
      :r3=>[10,80,70,60, 50,40,160,120,110,100,90],
      :r4=>[10,170,80,70, 50,40,30,120,110,100,90],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","E0:M226","E1:M150","E2:M150","E3:M150","A1:M150","A2:M150","A3:M150"],
      2=>["A0:Guard","E1:M361","E2:M150","E3:M150","E4:M150","A1:M150","A2:M150","A3:M150"],
      3=>["A0:Guard","E2:M461","E3:M150","E4:M150","E5:M150","A1:M150","A2:M150","A3:M150"],
      4=>["A0:Guard","A1:M226","E3:M150","E4:M150","E5:M150","E6:M150","A2:M150","A3:M150"],
    }

    begin
      KEY_API = Win32API.new("user32", "GetAsyncKeyState", "i", "i")
    rescue
      KEY_API = nil
    end

    def self.master
      return defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil
    end

    def self.active?
      return @active == true
    end

    def self.handled?(move_id)
      return HANDLED_MOVE_IDS.include?(move_id.to_i)
    end

    def self.project_root
      if defined?(ALBERT_CG::UNIQUE_B_V234) && ALBERT_CG::UNIQUE_B_V234.respond_to?(:project_root)
        return ALBERT_CG::UNIQUE_B_V234.project_root
      end
      return Dir.pwd
    rescue
      return Dir.pwd
    end

    def self.log_path
      return File.join(project_root, "Pokemon_UniqueJ_AutoTest_v2_4_3.log")
    end

    def self.latest_log_path
      return File.join(project_root, "CG_AutoRegression_LATEST.log")
    end

    def self.trace_log_path
      return File.join(project_root, "PMD_BattleInitTrace.log")
    end

    def self.write_line(path, text, mode="ab")
      File.open(path, mode) { |f| f.write(text.to_s + "\r\n") }
      return true
    rescue
      return false
    end

    def self.important_line?(line)
      return true if line.index("AUTO_TEST_START") == 0
      return true if line.index("ASSERT ") == 0
      return true if line.index("BATON_") == 0
      return true if line.index("HEALING_WISH_") == 0
      return true if line.index("LUNAR_DANCE_") == 0
      return true if line.index("RESULT=") == 0 || line.index("SUMMARY ") == 0
      return false
    end

    def self.log(line)
      text = line.to_s
      write_line(log_path, text)
      write_line(latest_log_path, text)
      write_line(trace_log_path, "[UNIQUE_J_AUTOTEST] " + text) if important_line?(text)
    end

    def self.reset_log
      header = [
        "CG POKEMON UNIQUE MOVE J AUTO REGRESSION v2.4.3",
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        "RULE=Actual Scene_Battle; Baton Pass / Healing Wish / Lunar Dance; deterministic switch-sacrifice lifecycle",
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS",
        "AUTOTEST_LOG_PATH=" + log_path.to_s,
        "AUTOTEST_LATEST_PATH=" + latest_log_path.to_s,
        "------------------------------------------------------------",
      ].join("\r\n") + "\r\n"
      File.open(log_path, "wb") { |f| f.write(header) }
      File.open(latest_log_path, "wb") { |f| f.write(header) }
    rescue
    end

    def self.key_down?(vk)
      return false if KEY_API == nil
      return (KEY_API.call(vk) & 0x8000) != 0
    rescue
      return false
    end

    def self.f11_trigger?
      down = key_down?(VK_F11)
      trigger = down && @f11_down != true
      @f11_down = down
      return trigger
    end

    def self.current_round
      return @round_index.to_i + 1
    end

    def self.current_plan
      return ROUND_PLANS[@round_index.to_i]
    end

    def self.finished?
      return @round_index.to_i >= ROUND_PLANS.size
    end

    def self.move_id_from_action(action)
      return 0 if action == nil || !action.skill? || action.skill == nil
      return ALBERT_CG::MOVE_EFFECT.move_id(action.skill).to_i
    rescue
      return 0
    end

    def self.battler_token(battler)
      return "nil" if battler == nil
      return (battler.actor? ? "A" : "E") + battler.index.to_i.to_s
    end

    def self.assert_true(label, condition, detail=nil)
      if condition
        log("ASSERT PASS " + label.to_s + (detail == nil ? "" : " " + detail.to_s))
        return true
      end
      @failures = [] if @failures == nil
      text = label.to_s + (detail == nil ? "" : " " + detail.to_s)
      @failures.push(text)
      log("ASSERT FAIL " + text)
      return false
    end

    def self.note_transfer(ok)
      @transfer_checks = @transfer_checks.to_i + 1 if ok
    end

    def self.note_heal(ok)
      @heal_checks = @heal_checks.to_i + 1 if ok
    end

    def self.note_lifecycle(ok)
      @lifecycle_checks = @lifecycle_checks.to_i + 1 if ok
    end

    def self.mark_apply(move_id)
      @apply_counts = {} if @apply_counts == nil
      mid = move_id.to_i
      @apply_counts[mid] = @apply_counts[mid].to_i + 1
      log("APPLY move=" + mid.to_s + ":" + (master == nil ? "" : master.move_name(mid).to_s)) if active?
    end

    def self.test_allies
      return $game_party == nil ? [] : $game_party.members[0,4]
    end

    def self.all_enemies
      return $game_troop == nil ? [] : $game_troop.members
    end

    def self.current_troop_id
      return -1 if $game_troop == nil
      return $game_troop.troop_id.to_i if $game_troop.respond_to?(:troop_id)
      return $game_troop.instance_variable_get(:@troop_id).to_i
    rescue
      return -1
    end

    def self.configure_actor(cfg)
      return if master == nil
      actor = $game_actors[master.actor_id_for_dex(cfg[:dex])]
      return if actor == nil
      master.configure_actor(actor, cfg)
      actor.recover_all if actor.respond_to?(:recover_all)
      actor.cg_reset_stat_stages if actor.respond_to?(:cg_reset_stat_stages)
      actor.cg_v242_clear_runtime if actor.respond_to?(:cg_v242_clear_runtime)
    end

    def self.configure_enemy(cfg)
      master.configure_enemy_data(cfg) if master != nil
    end

    def self.prepare_test_party
      ids = TEST_ALLIES.collect { |cfg| master.actor_id_for_dex(cfg[:dex]) }
      if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
        ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids)
      end
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized, true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each { |cfg| configure_actor(cfg) }
      human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if human != nil
        human.change_level(TEST_LEVEL, false)
        human.recover_all if human.respond_to?(:recover_all)
        human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
        human.cg_v242_clear_runtime if human.respond_to?(:cg_v242_clear_runtime)
      end
      return true
    end

    def self.make_test_troop
      master.ensure_index($data_troops, TEST_TROOP_ID)
      xs = [ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::ENEMY_BACK_X,
            ALBERT_CG::ENEMY_BACK_X, ALBERT_CG::ENEMY_BACK_X,
            ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[1],
            ALBERT_CG::GRID_COLUMN_Y[2], ALBERT_CG::GRID_COLUMN_Y[1],
            ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[1],
            ALBERT_CG::GRID_COLUMN_Y[2]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg,i|
        configure_enemy(cfg)
        m = ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]), xs[i], ys[i])
        m.hidden = (i >= 4)
        members.push(m)
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID, "Pokemon UniqueJ v2.4.3 AutoRegression", members)
    end

    def self.apply_test_grid
      allies = test_allies
      enemies = all_enemies
      sa = [[:back,1],[:front,0],[:front,1],[:front,2]]
      se = [[:front,0],[:front,1],[:front,2],[:back,1],[:back,0],[:back,1],[:back,2]]
      allies.each_with_index do |b,i|
        b.cg_set_battle_slot(sa[i][0],sa[i][1],true) if b != nil && b.respond_to?(:cg_set_battle_slot)
      end
      enemies.each_with_index do |b,i|
        b.cg_set_battle_slot(se[i][0],se[i][1],true) if b != nil && b.respond_to?(:cg_set_battle_slot)
      end
    end

    def self.make_action(battler, cfg)
      action = Game_BattleAction.new(battler)
      if cfg[:kind] == :attack
        action.set_attack
      elsif cfg[:kind] == :guard
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
      return nil unless active? && enemy != nil
      return nil if enemy.hidden || enemy.hp.to_i <= 0
      plan = current_plan
      cfg = plan == nil ? nil : plan[:enemies][enemy.index]
      return nil if cfg == nil
      return make_action(enemy,cfg)
    end

    def self.apply_test_speeds
      vals = TEST_SPEEDS[("r" + current_round.to_s).to_sym] || []
      list = test_allies + all_enemies
      list.each_with_index do |b,i|
        b.instance_variable_set(:@cg_priority_test_speed_override, vals[i]) if b != nil
      end
    end

    def self.install_skill_scopes
      return if master == nil || $data_skills == nil
      HANDLED_MOVE_IDS.each do |mid|
        sid = master.skill_id_for_move(mid)
        $data_skills[sid].scope = 11 if sid.to_i > 0 && $data_skills[sid] != nil
      end
    rescue => e
      log("SCOPE_INSTALL_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
    end

    #--------------------------------------------------------------------------
    # Replacement authority
    #--------------------------------------------------------------------------
    def self.reserve_candidates(user)
      return [] if user == nil
      if defined?(ALBERT_CG::FORCE_SWITCH_V235) && ALBERT_CG::FORCE_SWITCH_V235.respond_to?(:reserve_candidates)
        return ALBERT_CG::FORCE_SWITCH_V235.reserve_candidates(user)
      end
      return []
    rescue
      return []
    end

    def self.choose_reserve(user, candidates, move_id)
      return nil if candidates == nil || candidates.empty?
      if active?
        desired = nil
        desired = 4 if current_round == 1 && move_id.to_i == MOVE_BATON_PASS
        desired = 5 if current_round == 2 && move_id.to_i == MOVE_HEALING_WISH
        desired = 6 if current_round == 3 && move_id.to_i == MOVE_LUNAR_DANCE
        if desired != nil
          found = candidates.find { |b| b.respond_to?(:index) && b.index.to_i == desired }
          return found if found != nil
        end
      end
      # 正式 Runtime 依候補列表順序取第一位。玩家若未來有 reserve selector，
      # 應由 cg_force_switch_reserve_pets 提供已排序的合法候補，而不是讀 Storage。
      return candidates[0]
    end

    def self.switch_locked?
      return false unless defined?(ALBERT_CG::FIELD_V233)
      return ALBERT_CG::FIELD_V233.switch_locked? == true
    rescue
      return false
    end

    def self.clear_switch_volatile(battler)
      return if battler == nil
      if defined?(ALBERT_CG::FORCE_SWITCH_V235) && ALBERT_CG::FORCE_SWITCH_V235.respond_to?(:clear_switch_out_volatile)
        ALBERT_CG::FORCE_SWITCH_V235.clear_switch_out_volatile(battler)
      else
        battler.cg_reset_stat_stages if battler.respond_to?(:cg_reset_stat_stages)
        battler.cg_v234_clear_battle_memory if battler.respond_to?(:cg_v234_clear_battle_memory)
        battler.cg_v242_clear_runtime if battler.respond_to?(:cg_v242_clear_runtime)
      end
    rescue => e
      log("SWITCH_CLEAR_ERROR battler=" + (battler == nil ? "nil" : battler.name.to_s) +
          " " + e.class.to_s + ":" + e.message.to_s) if active?
    end

    def self.prepare_incoming(incoming, row, col)
      return {:damage=>0,:states=>[],:spe_delta=>0} if incoming == nil
      # hidden reserve 可能來自較早的 Baton Pass；先確保舊 transient 已清乾淨，
      # 主要異常與 HP/MP 則保留，交給 Healing Wish / Lunar Dance 自己處理。
      clear_switch_volatile(incoming)
      incoming.hidden = false if incoming.respond_to?(:hidden=)
      incoming.cg_set_battle_slot(row,col,true) if incoming.respond_to?(:cg_set_battle_slot)
      incoming.action.clear if incoming.respond_to?(:action) && incoming.action != nil
      incoming.reset_coordinate if incoming.respond_to?(:reset_coordinate)
      incoming.base_position if incoming.respond_to?(:base_position)
      incoming.instance_variable_set(:@collapse,false)
      hazard = {:damage=>0,:states=>[],:spe_delta=>0}
      if defined?(ALBERT_CG::FIELD_V233)
        hazard = ALBERT_CG::FIELD_V233.apply_entry_hazards(incoming)
      end
      return hazard
    end

    def self.hide_outgoing_alive(user)
      return if user == nil
      user.escape if user.respond_to?(:escape)
      user.hidden = true if user.respond_to?(:hidden=)
      user.action.clear if user.respond_to?(:action) && user.action != nil
    end

    def self.sacrifice_outgoing(user)
      return if user == nil
      hp_before = user.hp.to_i
      clear_switch_volatile(user)
      user.hp = 0
      user.hp_damage = hp_before if user.respond_to?(:hp_damage=)
      user.escape if user.respond_to?(:escape)
      user.hidden = true if user.respond_to?(:hidden=)
      user.action.clear if user.respond_to?(:action) && user.action != nil
    end

    #--------------------------------------------------------------------------
    # Baton Pass transfer payload
    #--------------------------------------------------------------------------
    def self.baton_payload(user)
      stages = {}
      BATON_TRANSFER_STAGE_KEYS.each do |key|
        stages[key] = user.respond_to?(:cg_stat_stage) ? user.cg_stat_stage(key).to_i : 0
      end
      sub_hp = user.respond_to?(:cg_v234_substitute_hp) ? user.cg_v234_substitute_hp.to_i : 0
      aqua = false
      ingrain = false
      if defined?(ALBERT_CG::MOVE_EFFECT)
        if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_AQUA_RING)
          aqua = user.state?(ALBERT_CG::MOVE_EFFECT::STATE_AQUA_RING)
        end
        ingrain = user.state?(ALBERT_CG::MOVE_EFFECT::STATE_INGRAIN)
      end
      return {:stages=>stages,:substitute_hp=>sub_hp,:aqua_ring=>aqua,:ingrain=>ingrain}
    end

    def self.remove_baton_transferables(user)
      return if user == nil
      user.cg_reset_stat_stages if user.respond_to?(:cg_reset_stat_stages)
      if user.respond_to?(:cg_v234_break_substitute)
        user.cg_v234_break_substitute
      else
        user.instance_variable_set(:@cg_v234_substitute_hp,0)
      end
      if defined?(ALBERT_CG::MOVE_EFFECT)
        if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_AQUA_RING)
          sid = ALBERT_CG::MOVE_EFFECT::STATE_AQUA_RING
          user.remove_state(sid) if user.state?(sid)
        end
        sid = ALBERT_CG::MOVE_EFFECT::STATE_INGRAIN
        user.remove_state(sid) if user.state?(sid)
      end
    end

    def self.apply_baton_payload(incoming, payload)
      return false if incoming == nil || payload == nil
      incoming.cg_reset_stat_stages if incoming.respond_to?(:cg_reset_stat_stages)
      BATON_TRANSFER_STAGE_KEYS.each do |key|
        value = payload[:stages][key].to_i
        incoming.cg_change_stat_stage(key,value) if value != 0 && incoming.respond_to?(:cg_change_stat_stage)
      end
      sub_hp = payload[:substitute_hp].to_i
      if incoming.respond_to?(:cg_v234_break_substitute)
        incoming.cg_v234_break_substitute
      else
        incoming.instance_variable_set(:@cg_v234_substitute_hp,0)
      end
      if sub_hp > 0
        incoming.instance_variable_set(:@cg_v234_substitute_hp,sub_hp)
        if defined?(ALBERT_CG::UNIQUE_B_V234)
          sid = ALBERT_CG::UNIQUE_B_V234::STATE_SUBSTITUTE
          if incoming.respond_to?(:cg_v231_add_state_record)
            incoming.cg_v231_add_state_record(sid)
          else
            incoming.add_state(sid)
          end
        end
      end
      if defined?(ALBERT_CG::MOVE_EFFECT)
        if payload[:aqua_ring] && ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_AQUA_RING)
          sid = ALBERT_CG::MOVE_EFFECT::STATE_AQUA_RING
          if incoming.respond_to?(:cg_v231_add_state_record)
            incoming.cg_v231_add_state_record(sid)
          else
            incoming.add_state(sid)
          end
        end
        if payload[:ingrain]
          sid = ALBERT_CG::MOVE_EFFECT::STATE_INGRAIN
          if incoming.respond_to?(:cg_v231_add_state_record)
            incoming.cg_v231_add_state_record(sid)
          else
            incoming.add_state(sid)
          end
        end
      end
      return true
    end

    def self.apply_baton_pass(user)
      return false if user == nil || user.hidden || user.hp.to_i <= 0
      if switch_locked?
        @fail_events.push({:move_id=>MOVE_BATON_PASS,:user=>user,:reason=>:fairy_lock}) if @fail_events != nil
        log("BATON_PASS_FAIL user=" + battler_token(user) + " reason=fairy_lock") if active?
        return false
      end
      candidates = reserve_candidates(user)
      if candidates.empty?
        @fail_events.push({:move_id=>MOVE_BATON_PASS,:user=>user,:reason=>:no_battle_reserve}) if @fail_events != nil
        log("BATON_PASS_FAIL user=" + battler_token(user) + " reason=no_battle_reserve storage_not_used=true") if active?
        return false
      end
      incoming = choose_reserve(user,candidates,MOVE_BATON_PASS)
      return false if incoming == nil
      row = user.respond_to?(:cg_battle_row) ? user.cg_battle_row : :front
      col = user.respond_to?(:cg_battle_column) ? user.cg_battle_column.to_i : 1
      payload = baton_payload(user)
      clear_switch_volatile(user)
      remove_baton_transferables(user)
      hide_outgoing_alive(user)
      hazard = prepare_incoming(incoming,row,col)
      applied = apply_baton_payload(incoming,payload)
      event = {:move_id=>MOVE_BATON_PASS,:outgoing=>user,:incoming=>incoming,
               :slot=>[row,col],:payload=>payload,:hazard=>hazard,:applied=>applied}
      @switch_events.push(event) if @switch_events != nil
      log("BATON_PASS_SUCCESS out=" + battler_token(user) + ":" + user.name.to_s +
          " in=" + battler_token(incoming) + ":" + incoming.name.to_s +
          " slot=" + [row,col].inspect + " stages=" + payload[:stages].inspect +
          " sub_hp=" + payload[:substitute_hp].to_i.to_s +
          " aqua=" + payload[:aqua_ring].to_s + " ingrain=" + payload[:ingrain].to_s +
          " storage_used=false") if active?
      return true
    rescue => e
      log("BATON_PASS_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
      return false
    end

    #--------------------------------------------------------------------------
    # Healing Wish / Lunar Dance
    #--------------------------------------------------------------------------
    def self.cure_primary_statuses(battler)
      return 0 if battler == nil
      if battler.respond_to?(:cg_v231_cure_primary_statuses)
        return battler.cg_v231_cure_primary_statuses
      end
      removed = 0
      if defined?(ALBERT_CG::MOVE_EFFECT) && ALBERT_CG::MOVE_EFFECT.respond_to?(:primary_cure_state_ids)
        ALBERT_CG::MOVE_EFFECT.primary_cure_state_ids.each do |sid|
          if battler.state?(sid)
            battler.remove_state(sid)
            removed += 1
          end
        end
      end
      return removed
    end

    def self.apply_healing_wish(user, lunar=false)
      move_id = lunar ? MOVE_LUNAR_DANCE : MOVE_HEALING_WISH
      return false if user == nil || user.hidden || user.hp.to_i <= 0
      candidates = reserve_candidates(user)
      if candidates.empty?
        @fail_events.push({:move_id=>move_id,:user=>user,:reason=>:no_battle_reserve}) if @fail_events != nil
        log((lunar ? "LUNAR_DANCE_FAIL" : "HEALING_WISH_FAIL") +
            " user=" + battler_token(user) + " reason=no_battle_reserve storage_not_used=true") if active?
        return false
      end
      incoming = choose_reserve(user,candidates,move_id)
      return false if incoming == nil
      row = user.respond_to?(:cg_battle_row) ? user.cg_battle_row : :front
      col = user.respond_to?(:cg_battle_column) ? user.cg_battle_column.to_i : 1
      mp_before = incoming.mp.to_i
      hp_before = incoming.hp.to_i
      sacrifice_outgoing(user)
      hazard = prepare_incoming(incoming,row,col)
      cured = 0
      if incoming.hp.to_i > 0
        cured = cure_primary_statuses(incoming)
        incoming.hp = incoming.maxhp
        incoming.mp = incoming.maxmp if lunar
      end
      event = {:move_id=>move_id,:outgoing=>user,:incoming=>incoming,:slot=>[row,col],
               :hp_before=>hp_before,:mp_before=>mp_before,:hazard=>hazard,:cured=>cured,
               :lunar=>lunar}
      @switch_events.push(event) if @switch_events != nil
      prefix = lunar ? "LUNAR_DANCE_SUCCESS" : "HEALING_WISH_SUCCESS"
      log(prefix + " out=" + battler_token(user) + ":" + user.name.to_s +
          " in=" + battler_token(incoming) + ":" + incoming.name.to_s +
          " slot=" + [row,col].inspect + " hp=" + hp_before.to_s + "->" + incoming.hp.to_i.to_s +
          " mp=" + mp_before.to_s + "->" + incoming.mp.to_i.to_s +
          " cured=" + cured.to_i.to_s + " storage_used=false") if active?
      return true
    rescue => e
      log((lunar ? "LUNAR_DANCE_ERROR " : "HEALING_WISH_ERROR ") + e.class.to_s + ":" + e.message.to_s) if active?
      return false
    end

    def self.apply_unique(user, move_id)
      mid = move_id.to_i
      case mid
      when MOVE_BATON_PASS
        return apply_baton_pass(user)
      when MOVE_HEALING_WISH
        return apply_healing_wish(user,false)
      when MOVE_LUNAR_DANCE
        return apply_healing_wish(user,true)
      end
      return false
    end

    #--------------------------------------------------------------------------
    # Regression preparation
    #--------------------------------------------------------------------------
    def self.add_state_for_test(battler, sid)
      return if battler == nil
      if battler.respond_to?(:cg_v231_add_state_record)
        battler.cg_v231_add_state_record(sid)
      else
        battler.add_state(sid)
      end
    end

    def self.prepare_round_preconditions
      a = test_allies
      e = all_enemies
      if current_round == 1
        e[0].cg_reset_stat_stages if e[0] != nil && e[0].respond_to?(:cg_reset_stat_stages)
        e[0].cg_change_stat_stage(:atk,2) if e[0] != nil
        e[0].cg_change_stat_stage(:spe,-1) if e[0] != nil
        e[0].cg_change_stat_stage(:accuracy,1) if e[0] != nil
        e[0].cg_v234_break_substitute if e[0] != nil && e[0].respond_to?(:cg_v234_break_substitute)
        e[0].cg_v234_create_substitute if e[0] != nil && e[0].respond_to?(:cg_v234_create_substitute)
        if defined?(ALBERT_CG::MOVE_EFFECT)
          add_state_for_test(e[0],ALBERT_CG::MOVE_EFFECT::STATE_AQUA_RING) if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_AQUA_RING)
          add_state_for_test(e[0],ALBERT_CG::MOVE_EFFECT::STATE_INGRAIN)
        end
        @r1_slot = [e[0].cg_battle_row,e[0].cg_battle_column]
        @r1_payload = baton_payload(e[0])
        @r1_in_hp = e[4].hp.to_i
        @r1_in_mp = e[4].mp.to_i
      elsif current_round == 2
        # Hidden E5 enters wounded + burned; Healing Wish heals HP/status only.
        e[5].remove_state(1) if e[5] != nil
        e[5].hp = [e[5].maxhp.to_i / 4,1].max if e[5] != nil
        e[5].mp = [e[5].maxmp.to_i / 2,0].max if e[5] != nil
        add_state_for_test(e[5],ALBERT_CG::MOVE_EFFECT::STATE_BURN) if e[5] != nil
        @r2_slot = [e[1].cg_battle_row,e[1].cg_battle_column]
        @r2_mp_before = e[5].mp.to_i
        @r2_storage = ($game_actors.respond_to?(:cg_all_pets) ? $game_actors.cg_all_pets.size : -1) rescue -1
      elsif current_round == 3
        # Hidden E6 enters wounded + poisoned + low MP; Lunar Dance restores all three resources.
        e[6].remove_state(1) if e[6] != nil
        e[6].hp = [e[6].maxhp.to_i / 5,1].max if e[6] != nil
        e[6].mp = [e[6].maxmp.to_i / 5,0].max if e[6] != nil
        add_state_for_test(e[6],ALBERT_CG::MOVE_EFFECT::STATE_POISON) if e[6] != nil
        @r3_slot = [e[2].cg_battle_row,e[2].cg_battle_column]
        @r3_storage = ($game_actors.respond_to?(:cg_all_pets) ? $game_actors.cg_all_pets.size : -1) rescue -1
      elsif current_round == 4
        @r4_actor = a[1]
        @r4_hp = a[1] == nil ? 0 : a[1].hp.to_i
        @r4_storage = ($game_actors.respond_to?(:cg_all_pets) ? $game_actors.cg_all_pets.size : -1) rescue -1
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
      token = battler_token(battler)
      action = battler.action
      if action != nil && action.guard?
        token += ":Guard"
      elsif action != nil && action.attack?
        token += ":Attack"
      elsif action != nil && action.skill?
        token += ":M" + move_id_from_action(action).to_s
      else
        token += ":Other"
      end
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + battler.name.to_s + " token=" + token)
      return token
    end

    def self.assert_bootstrap_once
      return if @boot_asserted == true
      @boot_asserted = true
      a = test_allies
      e = all_enemies
      assert_true("Scene_Battle uses Unique J test troop",current_troop_id == TEST_TROOP_ID,"actual=" + current_troop_id.to_s)
      assert_true("Unique J ally count=4",a.size == 4,"actual=" + a.size.to_s)
      assert_true("Unique J troop member count=7",e.size == 7,"actual=" + e.size.to_s)
      visible = e.select { |b| b != nil && !b.hidden && b.hp.to_i > 0 }
      hidden = e.select { |b| b != nil && b.hidden && b.hp.to_i > 0 }
      assert_true("Unique J starts with 4 active enemies",visible.size == 4,"actual=" + visible.size.to_s)
      assert_true("Unique J starts with exactly 3 hidden reserves",hidden.size == 3,"actual=" + hidden.size.to_s)
      apply_test_grid
    end

    def self.assert_round
      r = current_round
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
                  "expected=" + expected.inspect + " actual=" + @actual.inspect)
      a = test_allies
      e = all_enemies

      if r == 1
        event = @switch_events.find { |x| x[:move_id].to_i == MOVE_BATON_PASS && x[:outgoing] == e[0] }
        ok = event != nil && event[:incoming] == e[4] && e[0].hidden && !e[4].hidden
        note_lifecycle(ok); assert_true("Baton Pass uses legal hidden reserve",ok)
        slot_ok = event != nil && @r1_slot == [e[4].cg_battle_row,e[4].cg_battle_column]
        note_lifecycle(slot_ok); assert_true("Baton Pass replacement inherits exact Grid slot",slot_ok,
                    "expected=" + @r1_slot.inspect + " actual=" + [e[4].cg_battle_row,e[4].cg_battle_column].inspect)

        stage_ok = BATON_TRANSFER_STAGE_KEYS.all? do |key|
          e[4].cg_stat_stage(key).to_i == @r1_payload[:stages][key].to_i
        end
        note_transfer(stage_ok); assert_true("Baton Pass transfers all seven Stat Stages",stage_ok,
                    "actual=" + BATON_TRANSFER_STAGE_KEYS.collect { |k| [k,e[4].cg_stat_stage(k)] }.inspect)
        sub_ok = e[4].respond_to?(:cg_v234_substitute_hp) &&
                 e[4].cg_v234_substitute_hp.to_i == @r1_payload[:substitute_hp].to_i &&
                 e[4].cg_v234_substitute_hp.to_i > 0
        note_transfer(sub_ok); assert_true("Baton Pass transfers Substitute remaining HP",sub_ok,
                    "expected=" + @r1_payload[:substitute_hp].to_i.to_s + " actual=" + e[4].cg_v234_substitute_hp.to_i.to_s)
        aqua_sid = ALBERT_CG::MOVE_EFFECT::STATE_AQUA_RING
        aura_ok = e[4].state?(aqua_sid) && e[4].state?(ALBERT_CG::MOVE_EFFECT::STATE_INGRAIN)
        note_transfer(aura_ok); assert_true("Baton Pass transfers Aqua Ring and Ingrain whitelist",aura_ok)
        outgoing_clear = BATON_TRANSFER_STAGE_KEYS.all? { |key| e[0].cg_stat_stage(key).to_i == 0 } &&
                         (!e[0].respond_to?(:cg_v234_substitute_hp) || e[0].cg_v234_substitute_hp.to_i == 0) &&
                         !e[0].state?(aqua_sid) && !e[0].state?(ALBERT_CG::MOVE_EFFECT::STATE_INGRAIN)
        note_transfer(outgoing_clear); assert_true("Baton Pass clears transferred state from outgoing reserve",outgoing_clear)
        resource_ok = e[4].hp.to_i == @r1_in_hp.to_i && e[4].mp.to_i == @r1_in_mp.to_i
        note_transfer(resource_ok); assert_true("Baton Pass does not heal replacement HP/MP",resource_ok,
                    "hp=" + @r1_in_hp.to_s + "->" + e[4].hp.to_i.to_s + " mp=" + @r1_in_mp.to_s + "->" + e[4].mp.to_i.to_s)
      elsif r == 2
        event = @switch_events.find { |x| x[:move_id].to_i == MOVE_HEALING_WISH && x[:outgoing] == e[1] }
        life_ok = event != nil && event[:incoming] == e[5] && e[1].hp.to_i <= 0 && e[1].hidden && !e[5].hidden
        note_lifecycle(life_ok); assert_true("Healing Wish sacrifices user and deploys hidden reserve",life_ok)
        slot_ok = event != nil && @r2_slot == [e[5].cg_battle_row,e[5].cg_battle_column]
        note_lifecycle(slot_ok); assert_true("Healing Wish replacement inherits exact Grid slot",slot_ok)
        heal_ok = e[5].hp.to_i == e[5].maxhp.to_i && !e[5].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
        note_heal(heal_ok); assert_true("Healing Wish restores HP and cures primary status",heal_ok,
                    "hp=" + e[5].hp.to_i.to_s + "/" + e[5].maxhp.to_i.to_s)
        mp_ok = e[5].mp.to_i == @r2_mp_before.to_i
        note_heal(mp_ok); assert_true("Healing Wish does not restore shared MP",mp_ok,
                    "expected=" + @r2_mp_before.to_s + " actual=" + e[5].mp.to_i.to_s)
        storage_after = ($game_actors.respond_to?(:cg_all_pets) ? $game_actors.cg_all_pets.size : -1) rescue -1
        storage_ok = storage_after.to_i == @r2_storage.to_i
        note_lifecycle(storage_ok); assert_true("Healing Wish does not consume Storage pets",storage_ok,
                    "before=" + @r2_storage.to_s + " after=" + storage_after.to_s)
      elsif r == 3
        event = @switch_events.find { |x| x[:move_id].to_i == MOVE_LUNAR_DANCE && x[:outgoing] == e[2] }
        life_ok = event != nil && event[:incoming] == e[6] && e[2].hp.to_i <= 0 && e[2].hidden && !e[6].hidden
        note_lifecycle(life_ok); assert_true("Lunar Dance sacrifices user and deploys hidden reserve",life_ok)
        slot_ok = event != nil && @r3_slot == [e[6].cg_battle_row,e[6].cg_battle_column]
        note_lifecycle(slot_ok); assert_true("Lunar Dance replacement inherits exact Grid slot",slot_ok)
        heal_ok = e[6].hp.to_i == e[6].maxhp.to_i && e[6].mp.to_i == e[6].maxmp.to_i &&
                  !e[6].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON)
        note_heal(heal_ok); assert_true("Lunar Dance restores HP/status and shared MP",heal_ok,
                    "hp=" + e[6].hp.to_i.to_s + "/" + e[6].maxhp.to_i.to_s +
                    " mp=" + e[6].mp.to_i.to_s + "/" + e[6].maxmp.to_i.to_s)
        storage_after = ($game_actors.respond_to?(:cg_all_pets) ? $game_actors.cg_all_pets.size : -1) rescue -1
        storage_ok = storage_after.to_i == @r3_storage.to_i
        note_lifecycle(storage_ok); assert_true("Lunar Dance does not consume Storage pets",storage_ok,
                    "before=" + @r3_storage.to_s + " after=" + storage_after.to_s)
      elsif r == 4
        fail_event = @fail_events.find { |x| x[:move_id].to_i == MOVE_BATON_PASS && x[:user] == @r4_actor && x[:reason] == :no_battle_reserve }
        fail_ok = fail_event != nil && @r4_actor != nil && !@r4_actor.hidden && @r4_actor.hp.to_i == @r4_hp.to_i
        note_lifecycle(fail_ok); assert_true("Player Baton Pass fails safely when no legal battle reserve exists",fail_ok,
                    "hp=" + @r4_hp.to_s + "->" + (@r4_actor == nil ? "nil" : @r4_actor.hp.to_i.to_s))
        storage_after = ($game_actors.respond_to?(:cg_all_pets) ? $game_actors.cg_all_pets.size : -1) rescue -1
        storage_ok = storage_after.to_i == @r4_storage.to_i
        note_lifecycle(storage_ok); assert_true("Player no-reserve Baton Pass never falls back to Storage",storage_ok,
                    "before=" + @r4_storage.to_s + " after=" + storage_after.to_s)
      end
      log("ROUND " + r.to_s + " END")
    end

    def self.finish_round_assertions
      return unless active?
      assert_round
      @round_index = @round_index.to_i + 1
    end

    def self.covered_move_count
      count = 0
      HANDLED_MOVE_IDS.each { |mid| count += 1 if @apply_counts[mid].to_i > 0 }
      return count
    end

    def self.finish_suite
      begin
        HANDLED_MOVE_IDS.each do |mid|
          assert_true("Move " + mid.to_s + " covered",@apply_counts[mid].to_i > 0)
        end
        result = @failures.empty? ? "PASS" : "FAIL"
        log("------------------------------------------------------------")
        log("RESULT=" + result)
        log("SUMMARY rounds=4 failures=" + @failures.size.to_s +
            " unique_j_moves=" + covered_move_count.to_s + "/3" +
            " transfer_checks=" + @transfer_checks.to_i.to_s +
            " heal_checks=" + @heal_checks.to_i.to_s +
            " lifecycle_checks=" + @lifecycle_checks.to_i.to_s)
        @failures.each_with_index { |x,i| log("FAILURE " + (i+1).to_s + " " + x.to_s) }
      ensure
        cleanup_test_overrides
        @active = false
      end
    end

    def self.cleanup_test_overrides
      (test_allies + all_enemies).each do |b|
        b.instance_variable_set(:@cg_priority_test_speed_override,nil) if b != nil
      end
    end

    def self.reset_suite
      @round_index = 0
      @failures = []
      @actual = []
      @apply_counts = {}
      @switch_events = []
      @fail_events = []
      @transfer_checks = 0
      @heal_checks = 0
      @lifecycle_checks = 0
      @boot_asserted = false
    end

    def self.start_auto_test
      reset_log
      reset_suite
      prepare_test_party
      make_test_troop
      install_skill_scopes
      @active = true
      log("AUTO_TEST_START troop=" + TEST_TROOP_ID.to_s)
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue => e
      log("AUTO_TEST_START_ERROR " + e.class.to_s + ":" + e.message.to_s)
      return false
    end
  end
end

#==============================================================================
# ■ Game_Battler：Batch J Skill Effect dispatch
#==============================================================================
class Game_Battler
  alias cg_v243_skill_effect skill_effect
  def skill_effect(user, skill)
    mid = skill == nil ? 0 : ALBERT_CG::MOVE_EFFECT.move_id(skill)
    unless defined?(ALBERT_CG::UNIQUE_J_V243) && ALBERT_CG::UNIQUE_J_V243.handled?(mid)
      return cg_v243_skill_effect(user,skill)
    end
    clear_action_results
    ok = ALBERT_CG::UNIQUE_J_V243.apply_unique(user,mid)
    if ok
      ALBERT_CG::UNIQUE_J_V243.mark_apply(mid)
    else
      @skipped = true
      ALBERT_CG::UNIQUE_J_V243.log("APPLY_FAIL move=" + mid.to_s + " user=" +
        (user == nil ? "nil" : user.name.to_s) + " target=" + name.to_s) if ALBERT_CG::UNIQUE_J_V243.active?
    end
    return
  end
end

#==============================================================================
# ■ Game_Battler：Batch J deterministic SPE bridge
#==============================================================================
class Game_Battler
  alias cg_v243_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::UNIQUE_J_V243) && ALBERT_CG::UNIQUE_J_V243.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v243_priority_base_speed
  rescue
    return cg_v243_priority_base_speed
  end
end

#==============================================================================
# ■ Game_Enemy：Regression deterministic action
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v243_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::UNIQUE_J_V243) && ALBERT_CG::UNIQUE_J_V243.active?
      action = ALBERT_CG::UNIQUE_J_V243.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v243_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle：Regression control
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v243_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::UNIQUE_J_V243.record_execution(battler) if defined?(ALBERT_CG::UNIQUE_J_V243) && ALBERT_CG::UNIQUE_J_V243.active?
    cg_v243_execute_action
  end

  alias cg_v243_turn_end turn_end
  def turn_end
    ALBERT_CG::UNIQUE_J_V243.finish_round_assertions if defined?(ALBERT_CG::UNIQUE_J_V243) && ALBERT_CG::UNIQUE_J_V243.active?
    cg_v243_turn_end
  end

  alias cg_v243_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::UNIQUE_J_V243) && ALBERT_CG::UNIQUE_J_V243.active?
      return cg_v243_start_party_command
    end
    cg_v243_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::UNIQUE_J_V243.assert_bootstrap_once
    if ALBERT_CG::UNIQUE_J_V243.finished?
      ALBERT_CG::UNIQUE_J_V243.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::UNIQUE_J_V243.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle rebuild 後重套 Batch J test data
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v243_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v243_bootstrap_demo_party
      if defined?(ALBERT_CG::UNIQUE_J_V243) && ALBERT_CG::UNIQUE_J_V243.active?
        ALBERT_CG::UNIQUE_J_V243::TEST_ALLIES.each { |cfg| ALBERT_CG::UNIQUE_J_V243.configure_actor(cfg) }
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::UNIQUE_J_V243::TEST_LEVEL,false)
          human.recover_all if human.respond_to?(:recover_all)
          human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
          human.cg_v242_clear_runtime if human.respond_to?(:cg_v242_clear_runtime)
        end
        ALBERT_CG::UNIQUE_J_V243.install_skill_scopes
      end
      return result
    end
  end
end

#==============================================================================
# ■ Scene_Title：Move Stub 建立後校正 Scope
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_v243_load_database load_database
  def load_database
    cg_v243_load_database
    ALBERT_CG::UNIQUE_J_V243.install_skill_scopes
  end

  alias cg_v243_load_bt_database load_bt_database
  def load_bt_database
    cg_v243_load_bt_database
    ALBERT_CG::UNIQUE_J_V243.install_skill_scopes
  end
end

#==============================================================================
# ■ F11：v2.4.3 成為唯一最新版 deterministic AutoRegression
#==============================================================================
if defined?(ALBERT_CG::UNIQUE_I_V242)
  module ALBERT_CG
    module UNIQUE_I_V242
      def self.f11_trigger?; return false; end
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v243_scene_map_update update
  def update
    cg_v243_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::UNIQUE_J_V243.f11_trigger?
      Sound.play_decision
      ALBERT_CG::UNIQUE_J_V243.start_auto_test
    end
  end
end

#==============================================================================
# ■ Coverage：3 個 Pending -> V243_UNIQUE_J_HANDLED
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    class << self
      alias cg_v243_coverage_v231 coverage_v231
      def coverage_v231(move_id)
        return "V243_UNIQUE_J_HANDLED" if ALBERT_CG::UNIQUE_J_V243.handled?(move_id)
        return cg_v243_coverage_v231(move_id)
      end
    end
  end
end
