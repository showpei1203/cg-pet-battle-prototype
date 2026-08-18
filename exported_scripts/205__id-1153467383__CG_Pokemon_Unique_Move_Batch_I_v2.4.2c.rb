# RMVX_SCRIPT_INDEX: 205
# RMVX_SCRIPT_ID: 1153467383
# RMVX_SCRIPT_NAME: CG Pokemon Unique Move Batch I v2.4.2c
# RMVX_SOURCE_SHA256: b0da2cb5fd73becc3e3633095eae18cad198dc429ef2016ac621e7ff8447c865

#==============================================================================
# ■ CG Pokemon Unique Move Batch I v2.4.2c
#------------------------------------------------------------------------------
# 【用途】
#  接續 v2.4.1b 已實機 PASS 的 Unique Batch H，處理最後 17 招中的 Batch I：
#    100 Teleport／瞬間移動
#    144 Transform／變身
#    166 Sketch／寫生
#    180 Spite／怨恨
#    288 Grudge／怨念
#
#  本頁重用既有正式 Runtime，不建立平行系統：
#    - v2.3.7a Battle-only Type / Ability Identity Override
#    - v2.3.8a Battle Base Stat Override / Final Stat Getter Bridge
#    - v2.4.0a last_move / called_move memory
#    - v2.4.1b Action Queue / inserted action 相容執行鏈
#    - VX / Tankentai 現行 MP cost 與 consum_skill_cost 流程
#    - CG Pet Clone + Fixed Skill Slots 個體技能持久化
#    - v2.3.5a Force Switch / hidden reserve / Grid / Hazard lifecycle
#
# 【正式機制規則】
#  1. Transform 必須是 Battle-only：
#     - 複製目標目前有效 Type、Ability、ATK/DEF/SpA/SpD/SPE Battle Base、
#       六能力 Stage 與目前 Move Set。
#     - 不複製 HP / MaxHP / MP / MaxMP；共享 MP 是本專案 Move 資源，仍使用變身者自己的 MP。
#     - 不寫回 Species Master、Database Actor、Clone 的永久 species / PMD identity。
#     - 換出與 battle end 透過既有 volatile clear / remove_states_battle 清除。
#     - 本版只完成 Runtime 邏輯身分；PMD Renderer 的外觀換皮留給 PMD Motion / Presentation Phase，
#       避免 937 Moves 歸零前大改 Renderer。
#
#  2. Sketch 不得改 Species Master：
#     - 先讀目標 cg_v234_last_move_id；Struggle(165)、Sketch(166)、不存在 Move、
#       或使用者已經會的 Move 視為失敗。
#     - 若使用者是 Clone Pokémon（Game_Actor#cg_pet? == true），使用既有
#       cg_skill_slot_ids / @skills / skill-level 同一套個體持久化欄位，把「Sketch 所在欄位」永久替換為
#       被寫生 Move。這些欄位本來就隨 Clone Game_Actor Marshal 存檔，因此只污染該個體，
#       不污染 Database Actor / Species Master。
#     - 非 Clone Actor 與 Enemy 不做永久資料修改，只建立 battle-only Sketch slot override；
#       下次選／執行 Sketch slot 時視為被複製 Move，battle end / switch 清除。
#
#  3. Spite 的 PP→MP 專案轉譯：
#     - 本專案已取消 PP，Move 使用共享 MP。
#     - 原作削減 4 PP 改為「上一個 Move 的 calc_mp_cost × 4」扣除共享 MP，
#       最多扣到 0。這代表直接削掉該招約四次使用量，而不是建立不存在的 PP 欄位。
#
#  4. Grudge 的 PP→MP 專案轉譯：
#     - 使用 Grudge 後建立 battle-only marker。
#     - 若使用者在 marker 有效期間被敵對方的真正 Move 直接造成 KO，造成 KO 的 Battler
#       目前共享 MP 歸 0；不建立 per-move PP。
#     - residual / self damage / 同陣營傷害不觸發；使用者下一次執行非 Grudge 行動前清除 marker。
#
#  5. Teleport：
#     - 視為「自願換出」並重用 v2.3.5a reserve / Grid / Hazard lifecycle。
#     - 玩家正式 1 Human + 3 Pokémon 沒有一般 battle reserve，因此預設會失敗。
#     - 絕對不從 Storage 自動抓候補，也不新增 Storage reserve。
#     - Enemy 若 troop 本來就有 hidden reserve，才可成功 Teleport；換入者承接 Grid slot 並吃 entry hazard。
#     - Mean Look / Spider Web / Block 類 switch lock、Fairy Lock、Ingrain 會阻止 Teleport。
#
# 【設定／可調參數】
#  SPITE_USE_EQUIVALENT = 4     # Spite 視為削掉上一招 4 次 MP 使用量
#  TEST_TROOP_ID        = 700   # v2.4.2c F11 deterministic regression troop
#  TEST_LEVEL           = 40
#
# 【事件／腳本呼叫方式】
#  正常戰鬥不需事件呼叫；Move 由資料庫 Skill -> Pokemon Move Runtime 自動處理。
#  Debug 可直接讀：
#    battler.cg_v242_transformed?
#    battler.cg_v242_transform_move_ids
#    battler.cg_v242_sketch_move_id
#    battler.cg_v242_grudge?
#    battler.cg_v242_clear_runtime
#
# 【實際範例】
#  - Ditto 對 Machamp 使用 Transform：Type / Ability / 五項非 HP Base Stat / Stage /
#    Move Set 立即改走 Machamp 的 battle runtime；Ditto 自己的永久 species 與技能欄不變。
#  - Clone Smeargle 的 Sketch 在第 2 格，成功寫生 Thunderbolt：只把該 Clone 第 2 格永久
#    改成 Thunderbolt；同物種其他個體與 Species Master 完全不變。
#  - 目標上一招 Flamethrower calc_mp_cost=10，Spite 會額外扣 40 MP（不足則扣到 0）。
#  - Grudge 使用者被可造成有效傷害的直接 Move KO，造成 KO 者共享 MP 歸 0。
#
# 【F11 AutoRegression】
#  地圖畫面按 F11，執行 3 回合真正 Scene_Battle：
#    R1 Identity / Memory / Resource：
#       Transform、Sketch、Spite，並由敵方先實際使用 Thunderbolt / Flamethrower 建立 last_move。
#    R2 Runtime Move Authorization：
#       變身者真正執行 copied Tackle；非 Clone Sketch runtime 真正執行 copied Thunderbolt。
#    R3 Grudge + Teleport lifecycle：
#       Grudge 使用者被 Shadow Ball (247) KO -> attacker MP=0；玩家 Teleport 因無 reserve 失敗；
#       Enemy Teleport 使用唯一 hidden reserve 成功並繼承 Grid slot。
#  另在開戰前做 Clone Sketch isolation probe：建立暫時 Clone、在個體欄位永久替換 Sketch，
#  ASSERT Database Actor / Species Master 未被修改後立即刪除該測試 Clone。
#
# 【成功標準】
#  RPG Maker VX 實機 LOG 最後必須為：
#    RESULT=PASS
#    SUMMARY rounds=3 failures=0 unique_i_moves=5/5 identity_checks=... resource_checks=... lifecycle_checks=...
#
# 【v2.4.2a RGSS2 相容修正】
#  v2.4.2 實機 Round 3 在 Teleport no-reserve 正常失敗分支進入 APPLY_FAIL 後，
#  因呼叫 RGSS2 不保證存在的 instance_variable_defined? 而 NoMethodError。
#  v2.4.2a 改為在 clear_action_results 後直接設定 @skipped=true；不更動 Move 規則、
#  Transform / Sketch / Spite / Grudge / Teleport 行為或既有 Batch H。
#
# 【v2.4.2c Regression expectation / isolation 修正】
#  v2.4.2b 實機 LOG 首次直接記錄 Grudge 目標傷害前後 HP：
#    hp_before=1 hp_after=1
#  靜態核對 Master Data 後確認受害者 Banette / 詛咒娃娃為 Ghost，而 regression
#  使用的 Tackle (33) 為 Normal，因此正式 Type Runtime 正確給予免疫，該招不可能 KO。
#  故 v2.4.2a / v2.4.2b 的 Grudge FAIL 應重新分類為 Regression expectation bug；
#  v2.4.2b 為此加入的 Scene_Battle#damage_action Grudge bridge 不再保留，避免因錯誤
#  測試前提擴張正式 Runtime。v2.4.2c 回到既有 Game_Battler#execute_damage 權威 hook，
#  regression 改用 Shadow Ball (247, Ghost) 對 Ghost 受害者造成有效直接傷害。
#  同時依 deterministic 規格，在 Unique I F11 active 期間固定 calc_hit=100 / calc_eva=0，
#  並新增 type_rate > 0 的前置 ASSERT，防止未來再用「免疫攻擊」驗證 KO lifecycle。
#  Transform / Sketch / Spite / Teleport 與 Batch H 正式 Runtime 均不修改。
#
# 【重要】
#  本檔在未取得使用者 RPG Maker VX 實機 LOG 前，只能稱「v2.4.2c TEST BUILD / static ready」，
#  不得宣稱 Runtime PASS。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonUniqueMoveBatchI"] = "2.4.2c"

module ALBERT_CG
  module UNIQUE_I_V242
    VERSION = "2.4.2c"

    MOVE_TELEPORT  = 100
    MOVE_TRANSFORM = 144
    MOVE_SKETCH    = 166
    MOVE_SPITE     = 180
    MOVE_GRUDGE    = 288
    MOVE_STRUGGLE  = 165

    HANDLED_MOVE_IDS = [MOVE_TELEPORT, MOVE_TRANSFORM, MOVE_SKETCH,
                        MOVE_SPITE, MOVE_GRUDGE]
    SKETCH_BLACKLIST = [MOVE_STRUGGLE, MOVE_SKETCH]

    SPITE_USE_EQUIVALENT = 4
    TEST_TROOP_ID = 700
    TEST_LEVEL = 40
    VK_F11 = 0x7A

    TEST_ALLIES = [
      {:dex=>132,:level=>40,:ability=>7,   :moves=>[144,100,53,85]},
      {:dex=>235,:level=>40,:ability=>20,  :moves=>[166,100,150,33]},
      {:dex=>354,:level=>40,:ability=>15,  :moves=>[180,288,150,33]},
    ]
    # E0-E3 active, E4 hidden reserve for Teleport lifecycle.
    TEST_ENEMIES = [
      {:dex=>68,:level=>40,:ability=>62, :moves=>[33,247,150,150]},
      {:dex=>26,:level=>40,:ability=>9,  :moves=>[85,100,150,150]},
      {:dex=>6, :level=>40,:ability=>66, :moves=>[53,150,150,150]},
      {:dex=>9, :level=>40,:ability=>67, :moves=>[150,150,150,150]},
      {:dex=>1, :level=>40,:ability=>65, :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"TRANSFORM_SKETCH_SPITE",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>144,:target=>0},
          {:kind=>:move,:move_id=>166,:target=>1},
          {:kind=>:move,:move_id=>180,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>85, :target=>1},
          2=>{:kind=>:move,:move_id=>53, :target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>0},
        }
      },
      {
        :name=>"COPIED_MOVE_EXECUTION",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>3},
          {:kind=>:move,:move_id=>85,:target=>3},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>0},
          2=>{:kind=>:move,:move_id=>150,:target=>0},
          3=>{:kind=>:move,:move_id=>150,:target=>0},
        }
      },
      {
        :name=>"GRUDGE_AND_TELEPORT_LIFECYCLE",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>100,:target=>2},
          {:kind=>:move,:move_id=>288,:target=>3},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>247,:target=>3},
          1=>{:kind=>:move,:move_id=>100,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>0},
          3=>{:kind=>:move,:move_id=>150,:target=>0},
        }
      },
    ]

    # Guard +4；Teleport Master priority=-6。其餘使用 deterministic SPE。
    TEST_SPEEDS = {
      :r1=>[10,90,120,110, 100,140,130,80,70],
      :r2=>[10,140,130,120, 110,100,90,80,70],
      :r3=>[10,110,140,150, 130,120,100,90,80],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","E1:M85","E2:M53","A2:M166","A3:M180","E0:M150","A1:M144","E3:M150"],
      2=>["A0:Guard","A1:M33","A2:M85","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
      3=>["A0:Guard","A3:M288","E0:M247","A1:M150","E2:M150","E3:M150","A2:M100","E1:M100"],
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

    def self.current_round
      return @round_index.to_i + 1
    end

    def self.current_plan
      return ROUND_PLANS[@round_index.to_i]
    end

    def self.finished?
      return @round_index.to_i >= ROUND_PLANS.size
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
      return File.join(project_root, "Pokemon_UniqueI_AutoTest_v2_4_2c.log")
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
      return true if line.index("TRANSFORM") == 0 || line.index("SKETCH") == 0
      return true if line.index("SPITE") == 0 || line.index("GRUDGE") == 0
      return true if line.index("TELEPORT") == 0
      return true if line.index("RESULT=") == 0 || line.index("SUMMARY ") == 0
      return false
    end

    def self.log(line)
      text = line.to_s
      write_line(log_path, text)
      write_line(latest_log_path, text)
      write_line(trace_log_path, "[UNIQUE_I_AUTOTEST] " + text) if important_line?(text)
    end

    def self.reset_log
      header = [
        "CG POKEMON UNIQUE MOVE I AUTO REGRESSION v2.4.2c",
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        "RULE=Actual Scene_Battle; Transform/Sketch/Spite/Grudge/Teleport; deterministic identity/resource/lifecycle checks",
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

    def self.mark_apply(move_id)
      @apply_counts = {} if @apply_counts == nil
      mid = move_id.to_i
      @apply_counts[mid] = @apply_counts[mid].to_i + 1
      log("APPLY move=" + mid.to_s + ":" + (master == nil ? "" : master.move_name(mid).to_s) +
          " count=" + @apply_counts[mid].to_s) if active?
    end

    def self.apply_counts
      @apply_counts = {} if @apply_counts == nil
      return @apply_counts
    end

    def self.assert_true(label, ok, detail="")
      if ok
        log("ASSERT PASS " + label.to_s + (detail.to_s == "" ? "" : " " + detail.to_s))
      else
        text = label.to_s + (detail.to_s == "" ? "" : " " + detail.to_s)
        @failures.push(text)
        log("ASSERT FAIL " + text)
      end
      return ok
    end

    def self.note_identity(ok)
      @identity_checks = @identity_checks.to_i + 1 if ok
    end

    def self.note_resource(ok)
      @resource_checks = @resource_checks.to_i + 1 if ok
    end

    def self.note_lifecycle(ok)
      @lifecycle_checks = @lifecycle_checks.to_i + 1 if ok
    end

    def self.test_allies
      return $game_party == nil ? [] : $game_party.members[0,4]
    end

    def self.all_enemies
      return $game_troop == nil ? [] : $game_troop.members
    end

    def self.visible_enemies
      result = []
      all_enemies.each do |b|
        next if b == nil || b.hidden || b.hp.to_i <= 0
        result.push(b)
      end
      return result
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
      actor.cg_v242_clear_runtime if actor.respond_to?(:cg_v242_clear_runtime)
      actor.cg_reset_stat_stages if actor.respond_to?(:cg_reset_stat_stages)
      actor.recover_all if actor.respond_to?(:recover_all)
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
        human.cg_v242_clear_runtime if human.respond_to?(:cg_v242_clear_runtime)
        human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
      end
      return true
    end

    def self.make_test_troop
      master.ensure_index($data_troops, TEST_TROOP_ID)
      xs = [ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::ENEMY_BACK_X,
            ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[1],
            ALBERT_CG::GRID_COLUMN_Y[2], ALBERT_CG::GRID_COLUMN_Y[1],
            ALBERT_CG::GRID_COLUMN_Y[2]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg, i|
        configure_enemy(cfg)
        m = ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]), xs[i], ys[i])
        m.hidden = (i >= 4)
        members.push(m)
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID, "Pokemon UniqueI v2.4.2c AutoRegression", members)
    end

    def self.apply_test_grid
      allies = test_allies
      enemies = all_enemies
      sa = [[:back,1],[:front,0],[:front,1],[:front,2]]
      se = [[:front,0],[:front,1],[:front,2],[:back,1],[:back,2]]
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
      cfg = current_plan == nil ? nil : current_plan[:enemies][enemy.index]
      return nil if cfg == nil
      return make_action(enemy, cfg)
    end

    def self.apply_test_speeds
      vals = TEST_SPEEDS[("r" + current_round.to_s).to_sym] || []
      list = test_allies + all_enemies
      list.each_with_index do |b,i|
        b.instance_variable_set(:@cg_priority_test_speed_override, vals[i]) if b != nil
      end
    end

    def self.prepare_round_preconditions
      a = test_allies
      e = all_enemies
      if current_round == 1
        # Transform stage copy evidence.
        e[0].cg_reset_stat_stages if e[0] != nil && e[0].respond_to?(:cg_reset_stat_stages)
        e[0].cg_change_stat_stage(:atk, 2) if e[0] != nil && e[0].respond_to?(:cg_change_stat_stage)
        e[0].cg_change_stat_stage(:def, -1) if e[0] != nil && e[0].respond_to?(:cg_change_stat_stage)

        @r1_a1_database_id = a[1].respond_to?(:cg_database_actor_id) ? a[1].cg_database_actor_id.to_i : a[1].id.to_i
        @r1_a1_species = a[1].respond_to?(:cg_pmd_species_id) ? a[1].cg_pmd_species_id : nil
        @r1_a1_slots = a[1].respond_to?(:cg_skill_slot_ids) ? a[1].cg_skill_slot_ids.clone : []
        @r1_a1_hp = a[1].hp.to_i
        @r1_a1_maxhp = a[1].maxhp.to_i
        @r1_a2_slots = a[2].respond_to?(:cg_skill_slot_ids) ? a[2].cg_skill_slot_ids.clone : []

        fire_sid = master.skill_id_for_move(53)
        @r1_e2_mp_before = e[2].mp.to_i
        @r1_e2_fire_cost = e[2].calc_mp_cost($data_skills[fire_sid]).to_i
      elsif current_round == 2
        @r2_a1_mp_before = a[1].mp.to_i
        @r2_a2_mp_before = a[2].mp.to_i
      elsif current_round == 3
        # Grudge must be a real lethal direct Move event.
        if a[3] != nil
          a[3].remove_state(1) if a[3].respond_to?(:remove_state)
          a[3].hp = 1
          a[3].instance_variable_set(:@immortal, false)
        end
        # v2.4.2c Regression expectation fix:
        # Banette 是 Ghost；舊測試用 Normal Tackle (33) 因屬性免疫必定 0 傷害，
        # 無法形成 Grudge 的「直接 Move KO」前提。改用 Ghost Shadow Ball (247)，
        # 並在真正戰鬥開始前 ASSERT 該招對受害者 type_rate > 0。
        grudge_sid = master == nil ? 0 : master.skill_id_for_move(247)
        grudge_skill = grudge_sid.to_i <= 0 ? nil : $data_skills[grudge_sid]
        grudge_type = grudge_skill == nil ? 0 : grudge_skill.cg_pokemon_type_id.to_i
        grudge_rate = (a[3] != nil && a[3].respond_to?(:cg_pokemon_type_rate_percent)) ?
                      a[3].cg_pokemon_type_rate_percent(grudge_type).to_i : 0
        grudge_pre_ok = grudge_skill != nil && grudge_type > 0 && grudge_rate > 0
        assert_true("Grudge regression KO Move can damage Ghost victim", grudge_pre_ok,
                    "move=247 type_id="+grudge_type.to_s+
                    " type_rate="+grudge_rate.to_s+
                    " victim_types="+(a[3] != nil && a[3].respond_to?(:cg_pokemon_types) ? a[3].cg_pokemon_types.inspect : "nil"))
        log("GRUDGE_TEST_PRECONDITION victim="+(a[3] == nil ? "nil" : a[3].name.to_s)+
            " hp="+(a[3] == nil ? "nil" : a[3].hp.to_i.to_s)+
            " ko_move=247 type_rate="+grudge_rate.to_s)
        e[0].mp = e[0].maxmp if e[0] != nil
        @r3_e0_mp_before = e[0] == nil ? 0 : e[0].mp.to_i
        @r3_e1_slot = e[1] == nil ? nil : [e[1].cg_battle_row,e[1].cg_battle_column]
        @r3_storage_count = ($game_actors.respond_to?(:cg_all_pets) ? $game_actors.cg_all_pets.size : -1) rescue -1
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
        action = make_action(b, plan[:allies][i])
        if b.respond_to?(:cg_round_actions)
          b.cg_round_actions.clear
          b.cg_round_actions.push(action)
        end
        b.cg_assign_action(action) if b.respond_to?(:cg_assign_action)
        b.instance_variable_set(:@action, action) unless b.respond_to?(:cg_assign_action)
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

    def self.install_skill_scopes
      return if master == nil || $data_skills == nil
      scopes = {
        MOVE_TELEPORT=>11,
        MOVE_TRANSFORM=>1,
        MOVE_SKETCH=>1,
        MOVE_SPITE=>1,
        MOVE_GRUDGE=>11,
      }
      scopes.each do |mid,scope|
        sid = master.skill_id_for_move(mid)
        $data_skills[sid].scope = scope if sid.to_i > 0 && $data_skills[sid] != nil
      end
    rescue => e
      log("SCOPE_INSTALL_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
    end

    #--------------------------------------------------------------------------
    # Transform
    #--------------------------------------------------------------------------
    def self.copy_stat_stages(user, target)
      return if user == nil || target == nil
      return unless user.respond_to?(:cg_reset_stat_stages) && target.respond_to?(:cg_stat_stage)
      user.cg_reset_stat_stages
      [:atk,:def,:spa,:spd,:spe,:acc,:eva].each do |key|
        value = target.cg_stat_stage(key).to_i
        user.cg_change_stat_stage(key, value) if value != 0 && user.respond_to?(:cg_change_stat_stage)
      end
    end

    def self.apply_transform(user, target)
      return false if user == nil || target == nil || user == target
      return false unless user.respond_to?(:cg_v237_set_types) && user.respond_to?(:cg_v238_set_base_stat)

      types = target.respond_to?(:cg_pokemon_types) ? target.cg_pokemon_types.clone : []
      ability = target.respond_to?(:cg_master_ability_id) ? target.cg_master_ability_id.to_i : 0
      moves = target.respond_to?(:cg_v234_known_move_ids) ? target.cg_v234_known_move_ids.clone : []
      moves = moves.select { |mid| mid.to_i > 0 && master != nil && master.move(mid.to_i) != nil }
      return false if types == nil || types.empty? || moves.empty?

      user.cg_v237_set_types(types)
      user.cg_v237_set_ability(ability) if user.respond_to?(:cg_v237_set_ability)
      [:atk,:def,:spa,:spd,:spe].each do |key|
        value = target.respond_to?(:cg_v238_base_stat) ? target.cg_v238_base_stat(key).to_i : 1
        user.cg_v238_set_base_stat(key, [value,1].max)
      end
      copy_stat_stages(user, target)
      user.instance_variable_set(:@cg_v242_transformed, true)
      user.instance_variable_set(:@cg_v242_transform_move_ids, moves[0,8])
      user.instance_variable_set(:@cg_v242_transform_source, target)
      user.instance_variable_set(:@cg_v242_transform_pmd_key,
        target.respond_to?(:cg_pmd_sprite_key) ? target.cg_pmd_sprite_key.to_s : nil)
      log("TRANSFORM_SET user=" + battler_token(user) + ":" + user.name.to_s +
          " target=" + battler_token(target) + ":" + target.name.to_s +
          " types=" + types.inspect + " ability=" + ability.to_s + " moves=" + moves.inspect) if active?
      return true
    rescue => e
      log("TRANSFORM_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
      return false
    end

    #--------------------------------------------------------------------------
    # Sketch
    #--------------------------------------------------------------------------
    def self.sketchable_move?(user, move_id)
      mid = move_id.to_i
      return false if mid <= 0 || SKETCH_BLACKLIST.include?(mid)
      return false if master == nil || master.move(mid) == nil
      known = user != nil && user.respond_to?(:cg_v234_known_move_ids) ? user.cg_v234_known_move_ids : []
      return false if known.include?(mid)
      return true
    rescue
      return false
    end

    # Fixed Skill Slots 的 replace_index 只有在欄位已滿時才會進入 replace branch。
    # Sketch 語意必須「原位取代」且與欄位是否已滿無關，因此在 Clone 個體上沿用
    # Fixed Skill Slots 相同的 instance fields 做原位 swap；不碰 $data_actors / Species Master。
    def self.replace_clone_sketch_slot(user, index, old_sid, new_sid)
      return false if user == nil || index == nil
      ids = user.cg_skill_slot_ids
      idx = index.to_i
      return false if idx < 0 || idx >= ids.size || ids[idx].to_i != old_sid.to_i
      return false if new_sid.to_i <= 0 || $data_skills[new_sid.to_i] == nil

      ids[idx] = new_sid.to_i
      skills = user.instance_variable_get(:@skills)
      skills = [] if skills == nil
      skills.delete(old_sid.to_i)
      skills.push(new_sid.to_i) unless skills.include?(new_sid.to_i)
      user.instance_variable_set(:@skills, skills)
      user.instance_variable_set(:@cg_equipped_skill_ids, ids.dup)

      levels = user.instance_variable_get(:@cg_skill_levels)
      levels.delete(old_sid.to_i) if levels != nil
      prof = user.instance_variable_get(:@cg_skill_proficiency)
      prof.delete(old_sid.to_i) if prof != nil
      user.cg_set_skill_level(new_sid.to_i, 1) if user.respond_to?(:cg_set_skill_level)
      return true
    rescue => e
      log("SKETCH_SLOT_REPLACE_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
      return false
    end

    def self.apply_sketch_copy(user, copied_mid)
      return false if user == nil || !sketchable_move?(user, copied_mid)
      mid = copied_mid.to_i
      sid = master.skill_id_for_move(mid)
      return false if sid.to_i <= 0 || $data_skills[sid] == nil

      # Clone Pokémon：真正安全的 per-individual persistent slot replacement。
      if user.actor? && user.respond_to?(:cg_pet?) && user.cg_pet? &&
         user.respond_to?(:cg_skill_slot_ids)
        sketch_sid = master.skill_id_for_move(MOVE_SKETCH)
        index = user.cg_skill_slot_ids.index(sketch_sid)
        return false if index == nil
        result = replace_clone_sketch_slot(user, index, sketch_sid, sid)
        if result == true
          log("SKETCH_PERSIST clone=" + user.id.to_i.to_s + " copied=" + mid.to_s +
              " slot=" + index.to_i.to_s) if active?
          return true
        end
        return false
      end

      # Direct DB Actor / Enemy：battle-only，不碰共享資料。
      user.instance_variable_set(:@cg_v242_sketch_move_id, mid)
      log("SKETCH_RUNTIME user=" + battler_token(user) + ":" + user.name.to_s +
          " copied=" + mid.to_s) if active?
      return true
    rescue => e
      log("SKETCH_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
      return false
    end

    def self.apply_sketch(user, target)
      return false if user == nil || target == nil
      copied = target.respond_to?(:cg_v234_last_move_id) ? target.cg_v234_last_move_id.to_i : 0
      unless sketchable_move?(user, copied)
        log("SKETCH_FAIL user=" + battler_token(user) + " target=" + battler_token(target) +
            " last_move=" + copied.to_s) if active?
        return false
      end
      return apply_sketch_copy(user, copied)
    end

    #--------------------------------------------------------------------------
    # Spite / Grudge MP adaptation
    #--------------------------------------------------------------------------
    def self.apply_spite(user, target)
      return false if user == nil || target == nil
      mid = target.respond_to?(:cg_v234_last_move_id) ? target.cg_v234_last_move_id.to_i : 0
      return false if mid <= 0 || master == nil || master.move(mid) == nil
      sid = master.skill_id_for_move(mid)
      skill = sid.to_i <= 0 ? nil : $data_skills[sid]
      return false if skill == nil
      per_use = target.calc_mp_cost(skill).to_i
      drain = [per_use * SPITE_USE_EQUIVALENT, target.mp.to_i].min
      before = target.mp.to_i
      target.mp = [before - drain, 0].max
      log("SPITE_DRAIN user=" + battler_token(user) + " target=" + battler_token(target) +
          " last_move=" + mid.to_s + " per_use=" + per_use.to_s +
          " drain=" + drain.to_s + " mp=" + before.to_s + "->" + target.mp.to_i.to_s) if active?
      return true
    rescue => e
      log("SPITE_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
      return false
    end

    def self.apply_grudge(user)
      return false if user == nil
      user.instance_variable_set(:@cg_v242_grudge, true)
      log("GRUDGE_SET user=" + battler_token(user) + ":" + user.name.to_s) if active?
      return true
    end

    def self.trigger_grudge(victim, attacker, move_id)
      return false if victim == nil || attacker == nil
      return false unless victim.respond_to?(:cg_v242_grudge?) && victim.cg_v242_grudge?
      return false if attacker.actor? == victim.actor?
      mid = move_id.to_i
      return false if mid <= 0 || master == nil || master.move(mid) == nil
      before = attacker.mp.to_i
      attacker.mp = 0
      victim.instance_variable_set(:@cg_v242_grudge, false)
      @grudge_triggers = @grudge_triggers.to_i + 1
      @last_grudge_event = {:victim=>victim,:attacker=>attacker,:move_id=>mid,:mp_before=>before,:mp_after=>attacker.mp.to_i}
      log("GRUDGE_TRIGGER victim=" + battler_token(victim) + " attacker=" + battler_token(attacker) +
          " move=" + mid.to_s + " mp=" + before.to_s + "->0") if active?
      return true
    rescue => e
      log("GRUDGE_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
      return false
    end

    #--------------------------------------------------------------------------
    # Teleport：合法 battle reserve only，禁止 Storage fallback
    #--------------------------------------------------------------------------
    def self.teleport_block_reason(user)
      return :invalid_user if user == nil || user.hp.to_i <= 0 || user.hidden
      if user.respond_to?(:cg_v236_switch_locked?) && user.cg_v236_switch_locked?
        return :switch_lock
      end
      if defined?(ALBERT_CG::FIELD_V233) && ALBERT_CG::FIELD_V233.switch_locked?
        return :fairy_lock
      end
      if defined?(ALBERT_CG::MOVE_EFFECT) &&
         user.state?(ALBERT_CG::MOVE_EFFECT::STATE_INGRAIN)
        return :ingrain
      end
      return nil
    rescue
      return :runtime_error
    end

    def self.teleport_reserves(user)
      return [] if user == nil || !defined?(ALBERT_CG::FORCE_SWITCH_V235)
      return ALBERT_CG::FORCE_SWITCH_V235.reserve_candidates(user)
    rescue
      return []
    end

    def self.choose_teleport_reserve(user, candidates)
      return nil if candidates == nil || candidates.empty?
      if active?
        return candidates.sort_by { |b| b.respond_to?(:index) ? b.index.to_i : 0 }[0]
      end
      return candidates[rand(candidates.size)]
    rescue
      return candidates[0]
    end

    def self.apply_teleport(user)
      reason = teleport_block_reason(user)
      if reason != nil
        @teleport_fail_events = [] if @teleport_fail_events == nil
        @teleport_fail_events.push({:user=>user,:reason=>reason})
        log("TELEPORT_FAIL user=" + battler_token(user) + " reason=" + reason.to_s) if active?
        return false
      end
      candidates = teleport_reserves(user)
      if candidates.empty?
        @teleport_fail_events = [] if @teleport_fail_events == nil
        @teleport_fail_events.push({:user=>user,:reason=>:no_battle_reserve})
        log("TELEPORT_FAIL user=" + battler_token(user) + " reason=no_battle_reserve storage_not_used=true") if active?
        return false
      end
      incoming = choose_teleport_reserve(user, candidates)
      return false if incoming == nil

      row = user.respond_to?(:cg_battle_row) ? user.cg_battle_row : :front
      col = user.respond_to?(:cg_battle_column) ? user.cg_battle_column.to_i : 1
      out_slot = [row,col]

      if defined?(ALBERT_CG::FORCE_SWITCH_V235)
        ALBERT_CG::FORCE_SWITCH_V235.clear_switch_out_volatile(user)
      elsif user.respond_to?(:cg_v242_clear_runtime)
        user.cg_v242_clear_runtime
      end
      user.escape if user.respond_to?(:escape)
      user.hidden = true if user.respond_to?(:hidden=)
      user.action.clear if user.respond_to?(:action) && user.action != nil

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
      @teleport_events = [] if @teleport_events == nil
      @teleport_events.push({:outgoing=>user,:incoming=>incoming,:slot=>out_slot,:hazard=>hazard})
      log("TELEPORT_SUCCESS out=" + battler_token(user) + ":" + user.name.to_s +
          " in=" + battler_token(incoming) + ":" + incoming.name.to_s +
          " slot=" + out_slot.inspect + " storage_used=false") if active?
      return true
    rescue => e
      log("TELEPORT_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
      return false
    end

    #--------------------------------------------------------------------------
    # Shared dispatch
    #--------------------------------------------------------------------------
    def self.apply_unique(user, target, move_id)
      mid = move_id.to_i
      case mid
      when MOVE_TELEPORT
        return apply_teleport(user)
      when MOVE_TRANSFORM
        return apply_transform(user,target)
      when MOVE_SKETCH
        return apply_sketch(user,target)
      when MOVE_SPITE
        return apply_spite(user,target)
      when MOVE_GRUDGE
        return apply_grudge(user)
      end
      return false
    end

    # Sketch battle-only slot / Transform copied move execution.
    def self.prepare_runtime_action(battler)
      return if battler == nil || battler.action == nil || !battler.action.skill?
      mid = move_id_from_action(battler.action)

      # Grudge 與 Destiny Bond 同類：自己下一次非 Grudge 行動開始前失效。
      if battler.respond_to?(:cg_v242_grudge?) && battler.cg_v242_grudge? && mid != MOVE_GRUDGE
        battler.instance_variable_set(:@cg_v242_grudge,false)
        log("GRUDGE_EXPIRE_ON_ACTION battler=" + battler_token(battler) + " move=" + mid.to_s) if active?
      end

      copied = battler.respond_to?(:cg_v242_sketch_move_id) ? battler.cg_v242_sketch_move_id.to_i : 0
      if mid == MOVE_SKETCH && copied > 0 && defined?(ALBERT_CG::UNIQUE_B_V234)
        if ALBERT_CG::UNIQUE_B_V234.replace_action_with_move(battler,copied,MOVE_SKETCH)
          log("SKETCH_SLOT_EXECUTE battler=" + battler_token(battler) + " copied=" + copied.to_s) if active?
        end
      end
    end

    #--------------------------------------------------------------------------
    # Clone isolation probe
    #--------------------------------------------------------------------------
    def self.run_clone_sketch_probe
      return assert_true("Clone Sketch probe prerequisites exist",false,"missing clone/fixed-slot runtime") unless
        $game_actors.respond_to?(:cg_create_pet) && $game_actors.respond_to?(:cg_delete_pet)
      model_id = master.actor_id_for_dex(235)
      next_clone_id_before = $game_actors.instance_variable_get(:@cg_next_clone_id)
      template_actor = $game_actors[model_id]
      template_before = template_actor.respond_to?(:cg_skill_slot_ids) ? template_actor.cg_skill_slot_ids.clone : []
      master_before = master.move(MOVE_SKETCH).inspect
      clone = $game_actors.cg_create_pet(model_id,TEST_LEVEL,"SketchProbe",ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID)
      return assert_true("Clone Sketch probe creates temporary Clone",false) if clone == nil
      ok = false
      begin
        clone.cg_skill_slot_ids.clone.each { |sid| clone.forget_skill(sid) }
        sketch_sid = master.skill_id_for_move(MOVE_SKETCH)
        tackle_sid = master.skill_id_for_move(33)
        thunder_sid = master.skill_id_for_move(85)
        clone.cg_learn_skill_to_slot(sketch_sid,1,nil)
        clone.cg_learn_skill_to_slot(tackle_sid,1,nil)
        result = apply_sketch_copy(clone,85)
        ids = clone.cg_skill_slot_ids.clone
        ok = result == true && ids.include?(thunder_sid) && !ids.include?(sketch_sid)
        note_identity(ok)
        assert_true("Clone Sketch permanently replaces only the Clone's Sketch slot",ok,"slots="+ids.inspect)
        unchanged = template_actor.cg_skill_slot_ids == template_before && master.move(MOVE_SKETCH).inspect == master_before
        note_identity(unchanged)
        assert_true("Clone Sketch does not mutate Database Actor / Species Master",unchanged)
      ensure
        $game_actors.cg_delete_pet(clone.id) if clone != nil
        $game_actors.instance_variable_set(:@cg_next_clone_id,next_clone_id_before)
      end
      return ok
    rescue => e
      assert_true("Clone Sketch isolation probe executes",false,e.class.to_s+":"+e.message.to_s)
      return false
    end

    #--------------------------------------------------------------------------
    # Regression assertions
    #--------------------------------------------------------------------------
    def self.assert_bootstrap_once
      return if @boot_asserted == true
      @boot_asserted = true
      a = test_allies
      e = all_enemies
      assert_true("Scene_Battle uses Unique I test troop",current_troop_id == TEST_TROOP_ID,"actual="+current_troop_id.to_s)
      assert_true("Unique I ally count=4",a.size == 4,"actual="+a.size.to_s)
      assert_true("Unique I troop member count=5",e.size == 5,"actual="+e.size.to_s)
      hidden = e.select { |b| b != nil && b.hidden && b.hp.to_i > 0 }
      visible = e.select { |b| b != nil && !b.hidden && b.hp.to_i > 0 }
      assert_true("Unique I starts with 4 active enemies",visible.size == 4,"actual="+visible.size.to_s)
      assert_true("Unique I starts with exactly 1 hidden enemy reserve",hidden.size == 1,"actual="+hidden.size.to_s)
      if defined?(ALBERT_CG::ACTION_PRIORITY) && ALBERT_CG::ACTION_PRIORITY.respond_to?(:priority_for_move)
        assert_true("Teleport priority remains Master -6",ALBERT_CG::ACTION_PRIORITY.priority_for_move(MOVE_TELEPORT).to_i == -6,
                    "actual="+ALBERT_CG::ACTION_PRIORITY.priority_for_move(MOVE_TELEPORT).to_i.to_s)
      end
      apply_test_grid
    end

    def self.assert_round
      r = current_round
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual == expected,
                  "expected="+expected.inspect+" actual="+@actual.inspect)
      a = test_allies
      e = all_enemies

      if r == 1
        target_types = e[0].cg_pokemon_types
        ok = a[1].cg_v242_transformed? && a[1].cg_pokemon_types == target_types
        note_identity(ok); assert_true("Transform copies effective Type battle-only",ok,"actual="+a[1].cg_pokemon_types.inspect)

        ok = a[1].cg_master_ability_id.to_i == e[0].cg_master_ability_id.to_i
        note_identity(ok); assert_true("Transform copies effective Ability",ok,"actual="+a[1].cg_master_ability_id.to_i.to_s)

        stat_ok = [:atk,:def,:spa,:spd,:spe].all? { |k| a[1].cg_v238_base_stat(k).to_i == e[0].cg_v238_base_stat(k).to_i }
        note_identity(stat_ok); assert_true("Transform copies five non-HP Battle Base Stats",stat_ok)

        stage_ok = a[1].cg_stat_stage(:atk).to_i == e[0].cg_stat_stage(:atk).to_i &&
                   a[1].cg_stat_stage(:def).to_i == e[0].cg_stat_stage(:def).to_i
        note_identity(stage_ok); assert_true("Transform copies current Stat Stages",stage_ok,
                    "atk="+a[1].cg_stat_stage(:atk).to_s+" def="+a[1].cg_stat_stage(:def).to_s)

        move_ok = a[1].cg_v242_transform_move_ids == e[0].cg_v234_known_move_ids[0,8]
        note_identity(move_ok); assert_true("Transform copies current Move Set",move_ok,"moves="+a[1].cg_v242_transform_move_ids.inspect)

        permanent_ok = (a[1].respond_to?(:cg_database_actor_id) ? a[1].cg_database_actor_id.to_i : a[1].id.to_i) == @r1_a1_database_id.to_i &&
                       (a[1].respond_to?(:cg_pmd_species_id) ? a[1].cg_pmd_species_id : nil) == @r1_a1_species &&
                       a[1].cg_skill_slot_ids == @r1_a1_slots && a[1].maxhp.to_i == @r1_a1_maxhp.to_i
        note_identity(permanent_ok); assert_true("Transform does not mutate permanent Species / skill slots / MaxHP",permanent_ok)

        sketch_ok = a[2].cg_v242_sketch_move_id.to_i == 85 && a[2].cg_skill_slot_ids == @r1_a2_slots
        note_identity(sketch_ok); assert_true("Non-Clone Sketch is battle-only and preserves permanent skill slots",sketch_ok,
                    "copied="+a[2].cg_v242_sketch_move_id.to_i.to_s)

        expected_mp = [@r1_e2_mp_before.to_i - @r1_e2_fire_cost.to_i - @r1_e2_fire_cost.to_i * SPITE_USE_EQUIVALENT,0].max
        spite_ok = e[2].mp.to_i == expected_mp
        note_resource(spite_ok); assert_true("Spite drains four uses of last Move from shared MP",spite_ok,
                    "cost="+@r1_e2_fire_cost.to_s+" expected="+expected_mp.to_s+" actual="+e[2].mp.to_i.to_s)
      elsif r == 2
        ok = a[1].cg_v234_last_move_id.to_i == 33
        note_identity(ok); assert_true("Transformed Actor truly executes copied Tackle through skill authorization",ok,
                    "last="+a[1].cg_v234_last_move_id.to_i.to_s)
        ok = a[2].cg_v234_last_move_id.to_i == 85
        note_identity(ok); assert_true("Battle-only Sketch slot truly executes copied Thunderbolt",ok,
                    "last="+a[2].cg_v234_last_move_id.to_i.to_s)
        ok = a[1].mp.to_i < @r2_a1_mp_before.to_i && a[2].mp.to_i < @r2_a2_mp_before.to_i
        note_resource(ok); assert_true("Copied Transform / Sketch Moves consume the users' real shared MP",ok,
                    "transform_mp="+@r2_a1_mp_before.to_s+"->"+a[1].mp.to_i.to_s+
                    " sketch_mp="+@r2_a2_mp_before.to_s+"->"+a[2].mp.to_i.to_s)
      elsif r == 3
        event = @last_grudge_event
        grudge_ok = event != nil && event[:victim] == a[3] && event[:attacker] == e[0] &&
                    event[:move_id].to_i == 247 && e[0].mp.to_i == 0 && a[3].hp.to_i <= 0
        note_resource(grudge_ok); assert_true("Grudge drains KO-causing Move user's shared MP to zero",grudge_ok,
                    "attacker_mp="+(e[0] == nil ? "nil" : e[0].mp.to_i.to_s)+
                    " victim_hp="+(a[3] == nil ? "nil" : a[3].hp.to_i.to_s)+
                    " event_move="+(event == nil ? "nil" : event[:move_id].to_i.to_s))
        ok = @grudge_triggers.to_i == 1 && !a[3].cg_v242_grudge?
        note_resource(ok); assert_true("Grudge triggers exactly once and clears its marker",ok,"count="+@grudge_triggers.to_i.to_s)

        ally_fail = @teleport_fail_events != nil && @teleport_fail_events.any? { |x| x[:user] == a[2] && x[:reason] == :no_battle_reserve }
        note_lifecycle(ally_fail); assert_true("Player-side Teleport fails without legal battle reserve",ally_fail)

        tele = @teleport_events == nil ? nil : @teleport_events.find { |x| x[:outgoing] == e[1] }
        success = tele != nil && tele[:incoming] == e[4] && e[1].hidden && !e[4].hidden
        note_lifecycle(success); assert_true("Enemy Teleport uses existing hidden troop reserve",success)
        slot_ok = tele != nil && @r3_e1_slot == [e[4].cg_battle_row,e[4].cg_battle_column]
        note_lifecycle(slot_ok); assert_true("Teleport replacement inherits exact Grid slot",slot_ok,
                    "expected="+@r3_e1_slot.inspect+" actual="+[e[4].cg_battle_row,e[4].cg_battle_column].inspect)
        storage_after = ($game_actors.respond_to?(:cg_all_pets) ? $game_actors.cg_all_pets.size : -1) rescue -1
        storage_ok = @r3_storage_count.to_i == storage_after.to_i
        note_lifecycle(storage_ok); assert_true("Teleport does not consume or auto-deploy Storage pets",storage_ok,
                    "before="+@r3_storage_count.to_s+" after="+storage_after.to_s)
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
      HANDLED_MOVE_IDS.each { |mid| count += 1 if apply_counts[mid].to_i > 0 }
      return count
    end

    def self.finish_suite
      begin
        HANDLED_MOVE_IDS.each do |mid|
          assert_true("Move "+mid.to_s+" covered",apply_counts[mid].to_i > 0)
        end
        result = @failures.empty? ? "PASS" : "FAIL"
        log("------------------------------------------------------------")
        log("RESULT=" + result)
        log("SUMMARY rounds=3 failures=" + @failures.size.to_s +
            " unique_i_moves=" + covered_move_count.to_s + "/5" +
            " identity_checks=" + @identity_checks.to_i.to_s +
            " resource_checks=" + @resource_checks.to_i.to_s +
            " lifecycle_checks=" + @lifecycle_checks.to_i.to_s)
        @failures.each_with_index { |x,i| log("FAILURE "+(i+1).to_s+" "+x.to_s) }
      ensure
        cleanup_test_overrides
        @active = false
      end
    end

    def self.cleanup_test_overrides
      list = test_allies + all_enemies
      list.each do |b|
        next if b == nil
        b.instance_variable_set(:@cg_priority_test_speed_override,nil)
      end
    end

    def self.reset_suite
      @round_index = 0
      @failures = []
      @actual = []
      @apply_counts = {}
      @identity_checks = 0
      @resource_checks = 0
      @lifecycle_checks = 0
      @boot_asserted = false
      @teleport_events = []
      @teleport_fail_events = []
      @grudge_triggers = 0
      @last_grudge_event = nil
    end

    def self.start_auto_test
      reset_log
      reset_suite
      prepare_test_party
      make_test_troop
      install_skill_scopes
      @active = true
      log("AUTO_TEST_START troop=" + TEST_TROOP_ID.to_s)
      run_clone_sketch_probe
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue => e
      log("AUTO_TEST_START_ERROR " + e.class.to_s + ":" + e.message.to_s)
      return false
    end
  end
end

#==============================================================================
# ■ Game_Battler：Batch I Runtime / authorization / effects
#==============================================================================
class Game_Battler
  def cg_v242_transformed?
    return @cg_v242_transformed == true
  end

  def cg_v242_transform_move_ids
    value = @cg_v242_transform_move_ids
    return value == nil ? [] : value.clone
  end

  def cg_v242_sketch_move_id
    return @cg_v242_sketch_move_id.to_i
  end

  def cg_v242_grudge?
    return @cg_v242_grudge == true
  end

  def cg_v242_clear_runtime
    @cg_v242_transformed = false
    @cg_v242_transform_move_ids = nil
    @cg_v242_transform_source = nil
    @cg_v242_transform_pmd_key = nil
    @cg_v242_sketch_move_id = 0
    @cg_v242_grudge = false
    cg_v237_clear_identity if respond_to?(:cg_v237_clear_identity)
    cg_v238_clear_stat_identity if respond_to?(:cg_v238_clear_stat_identity)
  end

  # Transform / runtime Sketch 必須被 Move Memory、Assist、Imprison 等讀成真正目前 Move Set。
  alias cg_v242_known_move_ids cg_v234_known_move_ids
  def cg_v234_known_move_ids
    if cg_v242_transformed?
      ids = cg_v242_transform_move_ids
      return ids unless ids.empty?
    end
    ids = cg_v242_known_move_ids
    copied = cg_v242_sketch_move_id
    return ids if copied <= 0
    result = []
    ids.each do |mid|
      result.push(mid.to_i == ALBERT_CG::UNIQUE_I_V242::MOVE_SKETCH ? copied : mid.to_i)
    end
    return result
  rescue
    return cg_v242_known_move_ids
  end

  # 允許 Transform / battle-only Sketch 使用未永久學習的 copied Skill。
  alias cg_v242_virtual_skill_allowed cg_v234_virtual_skill_allowed?
  def cg_v234_virtual_skill_allowed?(skill)
    return true if cg_v242_virtual_skill_allowed(skill)
    return false if skill == nil || !defined?(ALBERT_CG::POKEMON_MASTER)
    mid = ALBERT_CG::POKEMON_MASTER.move_id_for_skill(skill.id)
    return true if cg_v242_transformed? && cg_v242_transform_move_ids.include?(mid)
    return true if cg_v242_sketch_move_id > 0 && mid.to_i == cg_v242_sketch_move_id
    return false
  rescue
    return cg_v242_virtual_skill_allowed(skill)
  end

  alias cg_v242_remove_states_battle remove_states_battle
  def remove_states_battle
    cg_v242_remove_states_battle
    cg_v242_clear_runtime
  end

  alias cg_v242_skill_effect skill_effect
  def skill_effect(user, skill)
    mid = skill == nil ? 0 : ALBERT_CG::MOVE_EFFECT.move_id(skill)
    unless defined?(ALBERT_CG::UNIQUE_I_V242) && ALBERT_CG::UNIQUE_I_V242.handled?(mid)
      return cg_v242_skill_effect(user,skill)
    end
    clear_action_results
    ok = ALBERT_CG::UNIQUE_I_V242.apply_unique(user,self,mid)
    if ok
      ALBERT_CG::UNIQUE_I_V242.mark_apply(mid)
    else
      # RGSS2 / Ruby 1.8 相容：Game_Battler#clear_action_results 已建立 @skipped；
      # 不使用 VX 環境不保證存在的 Object#instance_variable_defined?。
      @skipped = true
      ALBERT_CG::UNIQUE_I_V242.log("APPLY_FAIL move="+mid.to_s+" user="+
        (user == nil ? "nil" : user.name.to_s)+" target="+name.to_s) if ALBERT_CG::UNIQUE_I_V242.active?
    end
    return
  end

  # Grudge 必須掛在真正 execute_damage 後判定 KO，不能只看技能宣告。
  alias cg_v242_execute_damage execute_damage
  def execute_damage(user)
    grudge_before = cg_v242_grudge?
    hp_before = hp.to_i
    pending_damage = @hp_damage.to_i
    action = user == nil ? nil : user.action
    move_id = action != nil && action.skill? ? ALBERT_CG::MOVE_EFFECT.move_id(action.skill).to_i : 0
    cg_v242_execute_damage(user)
    if grudge_before && defined?(ALBERT_CG::UNIQUE_I_V242) && ALBERT_CG::UNIQUE_I_V242.active?
      ALBERT_CG::UNIQUE_I_V242.log(
        "GRUDGE_EXECUTE_DAMAGE_CHECK target="+name.to_s+
        " attacker="+(user == nil ? "nil" : user.name.to_s)+
        " move="+move_id.to_s+
        " hp_before="+hp_before.to_s+
        " pending_damage="+pending_damage.to_s+
        " hp_after="+hp.to_i.to_s)
    end
    if grudge_before && hp_before > 0 && hp.to_i <= 0 && user != nil &&
       user.actor? != actor? && move_id > 0
      ALBERT_CG::UNIQUE_I_V242.trigger_grudge(self,user,move_id)
    end
  end
end

#==============================================================================
# ■ Game_Actor：Transform / Sketch battle move window
#==============================================================================
class Game_Actor < Game_Battler
  alias cg_v242_actor_slot_skills cg_skill_slot_skills
  def cg_skill_slot_skills
    if cg_v242_transformed?
      result = []
      cg_v242_transform_move_ids.each do |mid|
        sid = ALBERT_CG::POKEMON_MASTER.skill_id_for_move(mid)
        skill = $data_skills[sid]
        result.push(skill) if skill != nil
      end
      return result unless result.empty?
    end
    list = cg_v242_actor_slot_skills
    copied = cg_v242_sketch_move_id
    return list if copied <= 0
    copied_sid = ALBERT_CG::POKEMON_MASTER.skill_id_for_move(copied)
    copied_skill = $data_skills[copied_sid]
    return list if copied_skill == nil
    result = []
    list.each do |skill|
      mid = skill == nil ? 0 : ALBERT_CG::POKEMON_MASTER.move_id_for_skill(skill.id)
      result.push(mid == ALBERT_CG::UNIQUE_I_V242::MOVE_SKETCH ? copied_skill : skill)
    end
    return result
  end
end

#==============================================================================
# ■ Force Switch lifecycle：換出時清除 Batch I battle-only runtime
#==============================================================================
if defined?(ALBERT_CG::FORCE_SWITCH_V235)
  module ALBERT_CG
    module FORCE_SWITCH_V235
      class << self
        alias cg_v242_clear_switch_out_volatile clear_switch_out_volatile
        def clear_switch_out_volatile(battler)
          cg_v242_clear_switch_out_volatile(battler)
          battler.cg_v242_clear_runtime if battler != nil && battler.respond_to?(:cg_v242_clear_runtime)
        end
      end
    end
  end
end

#==============================================================================
# ■ Game_Battler：Batch I deterministic SPE bridge
#==============================================================================
class Game_Battler
  alias cg_v242_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::UNIQUE_I_V242) && ALBERT_CG::UNIQUE_I_V242.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v242_priority_base_speed
  rescue
    return cg_v242_priority_base_speed
  end

  # v2.4.2c deterministic RNG isolation：
  # F11 regression 必須固定必要 RNG，否則 100 命中招式仍可能被 Evasion 等 runtime
  # 造成不穩定結果。僅 UNIQUE_I test active 時命中=100、閃避=0；正式遊戲完全不改。
  alias cg_v242c_calc_hit calc_hit
  def calc_hit(user, obj = nil)
    return 100 if defined?(ALBERT_CG::UNIQUE_I_V242) && ALBERT_CG::UNIQUE_I_V242.active?
    return cg_v242c_calc_hit(user, obj)
  end

  alias cg_v242c_calc_eva calc_eva
  def calc_eva(user, obj = nil)
    return 0 if defined?(ALBERT_CG::UNIQUE_I_V242) && ALBERT_CG::UNIQUE_I_V242.active?
    return cg_v242c_calc_eva(user, obj)
  end
end

#==============================================================================
# ■ Game_Enemy：Regression deterministic action + transformed AI bridge
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v242_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::UNIQUE_I_V242) && ALBERT_CG::UNIQUE_I_V242.active?
      action = ALBERT_CG::UNIQUE_I_V242.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end

    cg_v242_enemy_make_action

    # 正式敵方 Transform 後不能繼續只從原 Enemy.actions 挑招。
    if cg_v242_transformed? && !cg_v242_transform_move_ids.empty?
      usable = []
      cg_v242_transform_move_ids.each do |mid|
        sid = ALBERT_CG::POKEMON_MASTER.skill_id_for_move(mid)
        skill = $data_skills[sid]
        usable.push(mid) if skill != nil && skill_can_use?(skill)
      end
      unless usable.empty?
        chosen = usable[rand(usable.size)]
        old_action = self.action
        old_target = old_action == nil ? 0 : old_action.target_index.to_i
        a = Game_BattleAction.new(self)
        a.set_skill(ALBERT_CG::POKEMON_MASTER.skill_id_for_move(chosen))
        a.target_index = old_target
        cg_assign_action(a) if respond_to?(:cg_assign_action)
        @action = a unless respond_to?(:cg_assign_action)
      end
    end
  end
end

#==============================================================================
# ■ Scene_Battle：runtime slot replacement / regression control
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v242_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::UNIQUE_I_V242.prepare_runtime_action(battler) if battler != nil
    ALBERT_CG::UNIQUE_I_V242.record_execution(battler) if ALBERT_CG::UNIQUE_I_V242.active?
    cg_v242_execute_action
  end

  alias cg_v242_turn_end turn_end
  def turn_end
    ALBERT_CG::UNIQUE_I_V242.finish_round_assertions if defined?(ALBERT_CG::UNIQUE_I_V242) && ALBERT_CG::UNIQUE_I_V242.active?
    cg_v242_turn_end
  end

  alias cg_v242_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::UNIQUE_I_V242) && ALBERT_CG::UNIQUE_I_V242.active?
      return cg_v242_start_party_command
    end
    cg_v242_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::UNIQUE_I_V242.assert_bootstrap_once
    if ALBERT_CG::UNIQUE_I_V242.finished?
      ALBERT_CG::UNIQUE_I_V242.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::UNIQUE_I_V242.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle rebuild 後重套 Batch I test data
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v242_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v242_bootstrap_demo_party
      if defined?(ALBERT_CG::UNIQUE_I_V242) && ALBERT_CG::UNIQUE_I_V242.active?
        ALBERT_CG::UNIQUE_I_V242::TEST_ALLIES.each { |cfg| ALBERT_CG::UNIQUE_I_V242.configure_actor(cfg) }
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::UNIQUE_I_V242::TEST_LEVEL,false)
          human.recover_all if human.respond_to?(:recover_all)
          human.cg_v242_clear_runtime if human.respond_to?(:cg_v242_clear_runtime)
          human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
        end
        ALBERT_CG::UNIQUE_I_V242.install_skill_scopes
      end
      return result
    end
  end
end

#==============================================================================
# ■ Scene_Title：Move Stub 建立後校正 Scope
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_v242_load_database load_database
  def load_database
    cg_v242_load_database
    ALBERT_CG::UNIQUE_I_V242.install_skill_scopes
  end

  alias cg_v242_load_bt_database load_bt_database
  def load_bt_database
    cg_v242_load_bt_database
    ALBERT_CG::UNIQUE_I_V242.install_skill_scopes
  end
end

#==============================================================================
# ■ F11：v2.4.2c 成為唯一最新版 deterministic AutoRegression
#==============================================================================
if defined?(ALBERT_CG::UNIQUE_H_V241)
  module ALBERT_CG
    module UNIQUE_H_V241
      def self.f11_trigger?; return false; end
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v242_scene_map_update update
  def update
    cg_v242_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::UNIQUE_I_V242.f11_trigger?
      Sound.play_decision
      ALBERT_CG::UNIQUE_I_V242.start_auto_test
    end
  end
end

#==============================================================================
# ■ Coverage：5 個 Pending -> V242_UNIQUE_I_HANDLED
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    class << self
      alias cg_v242_coverage_v231 coverage_v231
      def coverage_v231(move_id)
        return "V242_UNIQUE_I_HANDLED" if ALBERT_CG::UNIQUE_I_V242.handled?(move_id)
        return cg_v242_coverage_v231(move_id)
      end
    end
  end
end
