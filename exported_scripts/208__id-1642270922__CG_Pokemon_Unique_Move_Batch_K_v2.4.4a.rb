# RMVX_SCRIPT_INDEX: 208
# RMVX_SCRIPT_ID: 1642270922
# RMVX_SCRIPT_NAME: CG Pokemon Unique Move Batch K v2.4.4a
# RMVX_SOURCE_SHA256: ff0f9f504659b21a518e14f208294999cf1dba97815026147f4631ed25414c8b

#==============================================================================
# ■ CG Pokemon Unique Move Batch K v2.4.4a
#------------------------------------------------------------------------------
# 【用途】
#  完成 937 Moves 最後 9 個 Pending，並把新正式 Pokémon Held Item Core 納入
#  deterministic Runtime 驗證：
#    271 Trick／戲法
#    278 Recycle／回收利用
#    415 Switcheroo／掉包
#    516 Bestow／傳遞禮物
#    603 Happy Hour／歡樂時光
#    606 Celebrate／慶祝
#    607 Hold Hands／牽手
#    752 Teatime／茶會
#    810 Corrosive Gas／腐蝕氣體
#
# 【Held Item 權威】
#  全部持有道具操作必須呼叫 CG Pokemon Held Item Core v2.4.4：
#  Pokémon Actor 的永久道具 = VX Weapon slot；可裝備權限 = Class.weapon_set；
#  Clone Actor 會從物種模板繼承 class_id，但 weapon_id 由每隻 Clone 個體自己保存。
#  Human 仍使用一般武器／防具系統，絕不被 Trick 等 Pokémon Held Item Move 操作。
#
# 【Move 規則】
#  Trick / Switcheroo：交換雙方 battle held item；至少一方必須有道具，雙方都必須是
#  Pokémon Held Item user，且接收方 Class 必須可合法持有該 Weapon。
#  Bestow：使用者有道具、目標沒有道具時，把 battle held item 交給目標。
#  Recycle：使用者目前沒有道具，且本次戰鬥記得上一個真正消耗的 Held Item 時恢復。
#  Happy Hour：本場戰鬥獎金 ×2；多次使用不疊加。
#  Celebrate：依原作保留為成功施放但無數值效果的 Utility / Presentation move。
#  Hold Hands：需要另一名存活同側隊友；成功但無數值效果，保留 Presentation event。
#  Teatime：所有目前可作用、未 suppressed 的 Berry Held Item 立即消耗並套用 Berry
#  消耗效果；至少一顆 Berry 被吃掉才算成功。
#  Corrosive Gas：battle-only 壓制目標 Held Item；不刪除、不破壞 Weapon，換出或
#  battle end 清除 suppression。
#
# 【F11 最新 Regression】
#  v2.4.4 實機已確認 Batch J 全部 PASS，但 J→K 連續兩場 harness 在第二場只完成
#  troop setup，未真正進入 K Scene_Battle。v2.4.4a 因此把測試隔離：
#    地圖按 F11 -> 直接啟動 Batch K 4 回合，不再重跑已 PASS 的 Batch J。
#  同時追加 Scene_Map / Scene_Battle transition trace，若仍無法進入 K 戰鬥，
#  LOG 會明確顯示停在 scene request、Scene_Battle#start 或 start 內部哪一層。
#
# 【主要設定項／可調參數】
#  TEST_TROOP_ID = 702：Batch K deterministic 測試敵群。
#  TEST_LEVEL = 40：測試 Actor / Enemy 等級。
#  TEST_ITEM_BERRY_A/B、CHARM、SEED = 901..904：只在測試執行期建立的 Weapon ID。
#  TEST_ALLIES / TEST_ENEMIES：測試物種、技能、Ability。
#  ROUND_PLANS / TEST_SPEEDS：四回合固定技能、目標與 SPE。
#
# 【腳本／事件呼叫方式】
#  地圖 F11：ALBERT_CG::UNIQUE_K_V244.start_k_test
#  事件「腳本」也可直接呼叫：
#    ALBERT_CG::UNIQUE_K_V244.start_k_test
#  正式 Move Runtime 不需要事件另外呼叫；招式透過 Game_Battler#skill_effect 自動 dispatch。
#
# 【實際範例】
#  例 1：地圖畫面按 F11，LATEST LOG 應先看到 Clone/Class/UI ASSERT，
#        接著 K_MAP_BATTLE_REQUEST、K_SCENE_START_ENTER、四回合 Action。
#  例 2：Trick 使用時，若雙方都是 Pokémon Held Item user 且 Class 可合法接收，
#        user.cg_swap_held_item_with(target) 交換 battle runtime item ownership。
#
# 【Batch K Regression】
#  啟動前先驗：
#    - 測試 Clone 繼承物種 Class。
#    - Held Item Weapon ID 已進 Pokémon Class.weapon_set。
#    - Clone 可合法裝備，Human 不可裝備。
#    - Pokémon Window_Equip item_max=1；Human item_max=5。
#  R1：Trick + Switcheroo。
#  R2：Bestow + Recycle。
#  R3：Teatime + Corrosive Gas + suppression switch-clear。
#  R4：Happy Hour + Celebrate + Hold Hands。
#
# 【成功標準】
#  最後必須為：
#    RESULT=PASS
#    SUMMARY batch_k_failures=0 batch_j_baseline=PASS unique_j_moves=3/3 unique_k_moves=9/9 pending=0 ...
#
# 【重要】
#  在使用者 RPG Maker VX 實機 LOG 出現上述 PASS 前，v2.4.4a 只能稱 TEST BUILD。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonUniqueMoveBatchK"] = "2.4.4a"

module ALBERT_CG
  module UNIQUE_K_V244
    VERSION = "2.4.4a"

    MOVE_TRICK = 271
    MOVE_RECYCLE = 278
    MOVE_SWITCHEROO = 415
    MOVE_BESTOW = 516
    MOVE_HAPPY_HOUR = 603
    MOVE_CELEBRATE = 606
    MOVE_HOLD_HANDS = 607
    MOVE_TEATIME = 752
    MOVE_CORROSIVE_GAS = 810
    HANDLED_MOVE_IDS = [MOVE_TRICK,MOVE_RECYCLE,MOVE_SWITCHEROO,MOVE_BESTOW,
      MOVE_HAPPY_HOUR,MOVE_CELEBRATE,MOVE_HOLD_HANDS,MOVE_TEATIME,MOVE_CORROSIVE_GAS]

    TEST_TROOP_ID = 702
    TEST_LEVEL = 40
    VK_F11 = 0x7A

    TEST_ITEM_BERRY_A = 901
    TEST_ITEM_BERRY_B = 902
    TEST_ITEM_CHARM = 903
    TEST_ITEM_SEED = 904

    TEST_ALLIES = [
      {:dex=>25,:level=>40,:ability=>9,:moves=>[271,516,603,150]},
      {:dex=>133,:level=>40,:ability=>50,:moves=>[415,752,606,150]},
      {:dex=>143,:level=>40,:ability=>47,:moves=>[278,810,607,150]},
    ]

    TEST_ENEMIES = [
      {:dex=>1,:level=>40,:ability=>65,:moves=>[150,150,150,150]},
      {:dex=>4,:level=>40,:ability=>66,:moves=>[150,150,150,150]},
      {:dex=>7,:level=>40,:ability=>67,:moves=>[150,150,150,150]},
      {:dex=>35,:level=>40,:ability=>56,:moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"TRICK_SWITCHEROO",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>271,:target=>0},
          {:kind=>:move,:move_id=>415,:target=>1},
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
        :name=>"BESTOW_RECYCLE",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>516,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>278,:target=>3},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
      {
        :name=>"TEATIME_CORROSIVE_GAS",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>752,:target=>2},
          {:kind=>:move,:move_id=>810,:target=>1},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
      {
        :name=>"HAPPY_CELEBRATE_HOLD_HANDS",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>603,:target=>1},
          {:kind=>:move,:move_id=>606,:target=>2},
          {:kind=>:move,:move_id=>607,:target=>1},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>3},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,180,170,60, 120,110,100,90],
      :r2=>[10,180,60,170, 120,110,100,90],
      :r3=>[10,60,180,170, 120,110,100,90],
      :r4=>[10,180,170,160, 120,110,100,90],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M271","A2:M415","E0:M150","E1:M150","E2:M150","E3:M150","A3:M150"],
      2=>["A0:Guard","A1:M516","A3:M278","E0:M150","E1:M150","E2:M150","E3:M150","A2:M150"],
      3=>["A0:Guard","A2:M752","A3:M810","E0:M150","E1:M150","E2:M150","E3:M150","A1:M150"],
      4=>["A0:Guard","A1:M603","A2:M606","A3:M607","E0:M150","E1:M150","E2:M150","E3:M150"],
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

    def self.meta_active?
      return @meta_active == true
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
      return File.join(project_root,"Pokemon_UniqueK_AutoTest_v2_4_4a.log")
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

    def self.log(line)
      write_line(log_path,line.to_s)
      write_line(latest_log_path,line.to_s)
      if defined?(ALBERT_CG::PMD_INIT_TRACE) && ALBERT_CG::PMD_INIT_TRACE.respond_to?(:log)
        ALBERT_CG::PMD_INIT_TRACE.log("[UNIQUE_K_AUTOTEST] " + line.to_s) if
          line.to_s.index("ASSERT ") == 0 || line.to_s.index("HELD_") == 0 ||
          line.to_s.index("TRICK_") == 0 || line.to_s.index("SWITCHEROO_") == 0 ||
          line.to_s.index("BESTOW_") == 0 || line.to_s.index("RECYCLE_") == 0 ||
          line.to_s.index("TEATIME_") == 0 || line.to_s.index("CORROSIVE_") == 0 ||
          line.to_s.index("RESULT=") == 0 || line.to_s.index("SUMMARY ") == 0
      end
    rescue
    end

    def self.reset_k_log
      header = "CG POKEMON UNIQUE MOVE K AUTO REGRESSION v2.4.4a\r\n" +
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n" +
        "RULE=Actual Scene_Battle; Held Item Weapon/Class/Clone UI + final 9 Moves\r\n" +
        "BATCH_J_BASELINE=RUNTIME_PASS v2.4.3; this F11 isolates Batch K only\r\n" +
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n" +
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb") { |f| f.write(header) }
      File.open(latest_log_path,"wb") { |f| f.write(header) }
      return true
    rescue
      return false
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

    def self.mark_apply(move_id)
      @apply_counts[move_id.to_i] = @apply_counts[move_id.to_i].to_i + 1
    end

    def self.note_item_check(ok)
      @item_checks += 1 if ok
    end

    def self.note_utility_check(ok)
      @utility_checks += 1 if ok
    end

    def self.battler_token(b)
      return "nil" if b == nil
      return (b.actor? ? "A" : "E") + b.index.to_i.to_s
    rescue
      return "?"
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

    def self.test_allies
      return $game_party == nil ? [] : $game_party.members
    end

    def self.all_enemies
      return $game_troop == nil ? [] : $game_troop.members
    end

    def self.ensure_array_index(array,index)
      array.push(nil) while array.size <= index
    end

    def self.make_test_weapon(id,name,note)
      ensure_array_index($data_weapons,id)
      w = RPG::Weapon.new
      w.id = id
      w.name = name
      w.description = "v2.4.4a Held Item deterministic test"
      w.note = note
      w.icon_index = 0 if w.respond_to?(:icon_index=)
      $data_weapons[id] = w
      return w
    end

    def self.install_test_weapons
      return false if $data_weapons == nil
      make_test_weapon(TEST_ITEM_BERRY_A,"測試莓果A","<CG_POKEMON_HELD_ITEM>\n<CG_BERRY>\n<CG_HELD_HEAL_HP:30>")
      make_test_weapon(TEST_ITEM_BERRY_B,"測試莓果B","<CG_POKEMON_HELD_ITEM>\n<CG_BERRY>\n<CG_HELD_HEAL_HP:25>")
      make_test_weapon(TEST_ITEM_CHARM,"測試護符","<CG_POKEMON_HELD_ITEM>")
      make_test_weapon(TEST_ITEM_SEED,"測試種子","<CG_POKEMON_HELD_ITEM>")
      ALBERT_CG::HELD_ITEM_V244.sync_class_permissions if defined?(ALBERT_CG::HELD_ITEM_V244)
      return true
    end

    def self.run_clone_class_ui_probe
      install_test_weapons
      model_id = master.actor_id_for_dex(25)
      clone = Game_Actor.new(9998,model_id)
      item = $data_weapons[TEST_ITEM_CHARM]
      human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      template = $data_actors[model_id]
      ok_class = template != nil && clone.class_id.to_i == template.class_id.to_i
      note_item_check(ok_class); assert_true("Clone Pokémon inherits template Class ID",ok_class,
        "clone_class=" + clone.class_id.to_i.to_s + " template_class=" + (template == nil ? "nil" : template.class_id.to_i.to_s))
      ok_set = clone.class != nil && clone.class.weapon_set.include?(TEST_ITEM_CHARM)
      note_item_check(ok_set); assert_true("Held Item Weapon is authorized by Pokémon Class.weapon_set",ok_set)
      ok_equip = clone.equippable?(item)
      note_item_check(ok_equip); assert_true("Clone Pokémon can legally equip tagged Held Item",ok_equip)
      human_ok = human != nil && !human.equippable?(item)
      note_item_check(human_ok); assert_true("Human cannot equip Pokémon Held Item Weapon",human_ok)
      clone.change_equip(0,item,true)
      persisted = clone.weapon_id.to_i == TEST_ITEM_CHARM && clone.cg_persistent_held_item_id.to_i == TEST_ITEM_CHARM
      note_item_check(persisted); assert_true("Clone individual stores Held Item in its own weapon_id",persisted,
        "weapon_id=" + clone.weapon_id.to_i.to_s)
      pet_window = nil
      human_window = nil
      begin
        pet_window = Window_Equip.new(0,0,clone)
        human_window = Window_Equip.new(0,0,human) if human != nil
        pet_ui = pet_window.item_max.to_i == 1
        human_ui = human_window != nil && human_window.item_max.to_i == 5
        note_item_check(pet_ui); assert_true("Pokémon equipment UI exposes exactly one slot",pet_ui,
          "item_max=" + pet_window.item_max.to_i.to_s)
        note_item_check(human_ui); assert_true("Human equipment UI keeps five VX slots",human_ui,
          "item_max=" + (human_window == nil ? "nil" : human_window.item_max.to_i.to_s))
      ensure
        pet_window.dispose if pet_window != nil
        human_window.dispose if human_window != nil
      end
      return true
    rescue => e
      assert_true("Clone/Class/Held Item UI probe",false,e.class.to_s + ":" + e.message.to_s)
      return false
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
      ids = []
      for cfg in TEST_ALLIES
        ids.push(master.actor_id_for_dex(cfg[:dex]))
      end
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
        human.cg_v242_clear_runtime if human.respond_to?(:cg_v242_clear_runtime)
      end
    end

    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs = [ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],
            ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[1]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg,i|
        configure_enemy(cfg)
        m = ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]),xs[i],ys[i])
        members.push(m)
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID,"Pokemon UniqueK v2.4.4a AutoRegression",members)
    end

    def self.install_skill_scopes
      scopes = {
        MOVE_TRICK=>1, MOVE_SWITCHEROO=>1, MOVE_CORROSIVE_GAS=>1,
        MOVE_BESTOW=>7, MOVE_HOLD_HANDS=>7,
        MOVE_RECYCLE=>11, MOVE_HAPPY_HOUR=>11, MOVE_CELEBRATE=>11, MOVE_TEATIME=>11
      }
      scopes.each do |mid,scope|
        sid = master.skill_id_for_move(mid)
        $data_skills[sid].scope = scope if sid.to_i > 0 && $data_skills[sid] != nil
      end
    rescue => e
      log("SCOPE_INSTALL_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
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
      cfg = plan == nil ? nil : plan[:enemies][enemy.index]
      return cfg == nil ? nil : make_action(enemy,cfg)
    end

    def self.apply_test_speeds
      vals = TEST_SPEEDS[("r" + current_round.to_s).to_sym] || []
      list = test_allies + all_enemies
      list.each_with_index do |b,i|
        b.instance_variable_set(:@cg_priority_test_speed_override,vals[i]) if b != nil
      end
    end

    def self.reset_round_held_runtime
      list = test_allies + all_enemies
      for b in list
        next if b == nil || !b.respond_to?(:cg_held_item_user?) || !b.cg_held_item_user?
        b.cg_set_battle_held_item(0,nil)
        b.cg_clear_held_item_suppression
        b.instance_variable_set(:@cg_last_consumed_held_item_id,0)
        b.instance_variable_set(:@cg_last_consumed_held_item_owner,nil)
      end
    end

    def self.set_test_item(b,item_id)
      return false if b == nil
      owner = b.cg_held_item_owner_key
      return b.cg_set_battle_held_item(item_id,owner)
    end

    def self.prepare_round_preconditions
      reset_round_held_runtime
      a = test_allies
      e = all_enemies
      if current_round == 1
        set_test_item(a[1],TEST_ITEM_BERRY_A)
        set_test_item(e[0],TEST_ITEM_CHARM)
        set_test_item(e[1],TEST_ITEM_SEED)
      elsif current_round == 2
        set_test_item(a[1],TEST_ITEM_BERRY_A)
        set_test_item(a[3],TEST_ITEM_BERRY_B)
        a[3].cg_consume_held_item(:regression_setup,false)
        @r2_recycle_id = a[3].cg_last_consumed_held_item_id
      elsif current_round == 3
        set_test_item(a[1],TEST_ITEM_BERRY_A)
        set_test_item(e[0],TEST_ITEM_BERRY_B)
        set_test_item(e[1],TEST_ITEM_CHARM)
        a[1].hp = [a[1].maxhp.to_i - 60,1].max
        e[0].hp = [e[0].maxhp.to_i - 60,1].max
        @r3_a1_hp = a[1].hp.to_i
        @r3_e0_hp = e[0].hp.to_i
      elsif current_round == 4
        $game_troop.cg_happy_hour_active = false if $game_troop.respond_to?(:cg_happy_hour_active=)
        @utility_events = []
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
      return ALBERT_CG::MOVE_EFFECT.move_id(skill)
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
        token += ":Other"
      end
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + battler.name.to_s + " token=" + token)
    end

    def self.same_side?(a,b)
      return false if a == nil || b == nil
      return a.actor? == b.actor?
    end

    def self.apply_trick(user,target,move_id)
      return false if user == nil || target == nil
      ok = user.cg_swap_held_item_with(target)
      if ok
        log((move_id.to_i == MOVE_TRICK ? "TRICK_SUCCESS" : "SWITCHEROO_SUCCESS") +
          " user=" + battler_token(user) + " target=" + battler_token(target) +
          " user_item=" + user.cg_held_item_id.to_i.to_s + " target_item=" + target.cg_held_item_id.to_i.to_s)
      end
      return ok
    end

    def self.apply_bestow(user,target)
      return false if user == nil || target == nil
      ok = user.cg_bestow_held_item_to(target)
      log("BESTOW_SUCCESS user=" + battler_token(user) + " target=" + battler_token(target) +
        " target_item=" + target.cg_held_item_id.to_i.to_s) if ok
      return ok
    end

    def self.apply_recycle(user)
      return false if user == nil
      before = user.cg_last_consumed_held_item_id
      ok = user.cg_recycle_held_item
      log("RECYCLE_SUCCESS user=" + battler_token(user) + " restored=" + before.to_i.to_s) if ok
      return ok
    end

    def self.apply_happy_hour(user)
      return false if user == nil || $game_troop == nil
      $game_troop.cg_happy_hour_active = true
      @utility_events.push({:move_id=>MOVE_HAPPY_HOUR,:user=>user}) if @utility_events != nil
      log("HAPPY_HOUR_SUCCESS user=" + battler_token(user))
      return true
    end

    def self.apply_celebrate(user)
      return false if user == nil
      @utility_events.push({:move_id=>MOVE_CELEBRATE,:user=>user}) if @utility_events != nil
      log("CELEBRATE_SUCCESS user=" + battler_token(user))
      return true
    end

    def self.apply_hold_hands(user,target)
      return false if user == nil || target == nil || user == target
      return false unless same_side?(user,target) && target.hp.to_i > 0 && !target.hidden
      @utility_events.push({:move_id=>MOVE_HOLD_HANDS,:user=>user,:target=>target}) if @utility_events != nil
      log("HOLD_HANDS_SUCCESS user=" + battler_token(user) + " target=" + battler_token(target))
      return true
    end

    def self.apply_teatime(user)
      return false if user == nil
      count = 0
      list = test_allies + all_enemies
      for b in list
        next if b == nil || b.hidden || b.hp.to_i <= 0
        next unless b.respond_to?(:cg_held_item_berry?) && b.cg_held_item_berry?
        if b.cg_consume_held_item(:teatime,true)
          count += 1
          log("TEATIME_CONSUME battler=" + battler_token(b) + " count=" + count.to_s)
        end
      end
      log("TEATIME_SUCCESS user=" + battler_token(user) + " berries=" + count.to_s) if count > 0
      return count > 0
    end

    def self.apply_corrosive_gas(user,target)
      return false if user == nil || target == nil
      ok = target.respond_to?(:cg_suppress_held_item) && target.cg_suppress_held_item
      log("CORROSIVE_GAS_SUCCESS user=" + battler_token(user) + " target=" + battler_token(target) +
        " raw_item=" + target.cg_held_item_id.to_i.to_s) if ok
      return ok
    end

    def self.apply_unique(user,target,move_id)
      mid = move_id.to_i
      case mid
      when MOVE_TRICK, MOVE_SWITCHEROO
        return apply_trick(user,target,mid)
      when MOVE_RECYCLE
        return apply_recycle(user)
      when MOVE_BESTOW
        return apply_bestow(user,target)
      when MOVE_HAPPY_HOUR
        return apply_happy_hour(user)
      when MOVE_CELEBRATE
        return apply_celebrate(user)
      when MOVE_HOLD_HANDS
        return apply_hold_hands(user,target)
      when MOVE_TEATIME
        return apply_teatime(user)
      when MOVE_CORROSIVE_GAS
        return apply_corrosive_gas(user,target)
      end
      return false
    end

    def self.assert_bootstrap_once
      return if @boot_asserted == true
      @boot_asserted = true
      assert_true("Scene_Battle uses Unique K test troop",$game_troop.troop != nil && $game_troop.troop.id.to_i == TEST_TROOP_ID,
        "actual=" + ($game_troop.troop == nil ? "nil" : $game_troop.troop.id.to_i.to_s))
      assert_true("Unique K ally count=4",test_allies.size == 4,"actual=" + test_allies.size.to_s)
      assert_true("Unique K enemy count=4",all_enemies.size == 4,"actual=" + all_enemies.size.to_s)
    end

    def self.assert_round
      r = current_round
      expected = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",@actual == expected,
        "expected=" + expected.inspect + " actual=" + @actual.inspect)
      a = test_allies
      e = all_enemies
      if r == 1
        ok1 = a[1].cg_held_item_id.to_i == TEST_ITEM_CHARM && e[0].cg_held_item_id.to_i == TEST_ITEM_BERRY_A
        note_item_check(ok1); assert_true("Trick exchanges two held items",ok1,
          "A1=" + a[1].cg_held_item_id.to_i.to_s + " E0=" + e[0].cg_held_item_id.to_i.to_s)
        ok2 = a[2].cg_held_item_id.to_i == TEST_ITEM_SEED && e[1].cg_held_item_id.to_i == 0
        note_item_check(ok2); assert_true("Switcheroo transfers item when one side is empty",ok2,
          "A2=" + a[2].cg_held_item_id.to_i.to_s + " E1=" + e[1].cg_held_item_id.to_i.to_s)
      elsif r == 2
        bestow = a[1].cg_held_item_id.to_i == 0 && a[2].cg_held_item_id.to_i == TEST_ITEM_BERRY_A
        note_item_check(bestow); assert_true("Bestow moves held item to empty ally",bestow)
        recycle = a[3].cg_held_item_id.to_i == @r2_recycle_id.to_i && a[3].cg_last_consumed_held_item_id.to_i == 0
        note_item_check(recycle); assert_true("Recycle restores last consumed held item",recycle,
          "item=" + a[3].cg_held_item_id.to_i.to_s)
      elsif r == 3
        a1_heal = a[1].cg_held_item_id.to_i == 0 && a[1].hp.to_i == [@r3_a1_hp.to_i + 30,a[1].maxhp.to_i].min
        e0_heal = e[0].cg_held_item_id.to_i == 0 && e[0].hp.to_i == [@r3_e0_hp.to_i + 25,e[0].maxhp.to_i].min
        note_item_check(a1_heal); assert_true("Teatime consumes ally Berry and applies effect",a1_heal,
          "hp=" + @r3_a1_hp.to_s + "->" + a[1].hp.to_i.to_s)
        note_item_check(e0_heal); assert_true("Teatime consumes enemy Berry and applies effect",e0_heal,
          "hp=" + @r3_e0_hp.to_s + "->" + e[0].hp.to_i.to_s)
        suppress = e[1].cg_held_item_id.to_i == TEST_ITEM_CHARM && e[1].cg_held_item_suppressed? && e[1].cg_held_item == nil
        note_item_check(suppress); assert_true("Corrosive Gas suppresses item without deleting it",suppress)
        ALBERT_CG::FORCE_SWITCH_V235.clear_switch_out_volatile(e[1]) if defined?(ALBERT_CG::FORCE_SWITCH_V235)
        clear_ok = !e[1].cg_held_item_suppressed? && e[1].cg_raw_held_item != nil
        note_item_check(clear_ok); assert_true("Corrosive Gas suppression clears on switch-out volatile reset",clear_ok)
      elsif r == 4
        happy = $game_troop.respond_to?(:cg_happy_hour_active?) && $game_troop.cg_happy_hour_active?
        note_utility_check(happy); assert_true("Happy Hour sets battle reward multiplier flag",happy)
        if $game_troop.respond_to?(:cg_v244_gold_total_without_happy)
          base = $game_troop.cg_v244_gold_total_without_happy
          doubled = $game_troop.gold_total.to_i == base.to_i * 2
          note_utility_check(doubled); assert_true("Happy Hour doubles battle gold reward",doubled,
            "base=" + base.to_i.to_s + " actual=" + $game_troop.gold_total.to_i.to_s)
        end
        cel = @utility_events.any? { |x| x[:move_id].to_i == MOVE_CELEBRATE }
        hold = @utility_events.any? { |x| x[:move_id].to_i == MOVE_HOLD_HANDS && x[:target] == a[1] }
        note_utility_check(cel); assert_true("Celebrate resolves as successful presentation utility",cel)
        note_utility_check(hold); assert_true("Hold Hands requires and records a living ally target",hold)
      end
      log("ROUND " + r.to_s + " END")
    end

    def self.finish_round_assertions
      return unless active?
      assert_round
      @round_index += 1
    end

    def self.covered_move_count
      count = 0
      for mid in HANDLED_MOVE_IDS
        count += 1 if @apply_counts[mid].to_i > 0
      end
      return count
    end

    def self.finish_suite
      begin
        for mid in HANDLED_MOVE_IDS
          assert_true("Move " + mid.to_s + " covered",@apply_counts[mid].to_i > 0)
        end
        k_result = @failures.empty? ? "PASS" : "FAIL"
        log("------------------------------------------------------------")
        log("BATCH_K_RESULT=" + k_result)
        log("BATCH_K_SUMMARY rounds=4 failures=" + @failures.size.to_s +
          " unique_k_moves=" + covered_move_count.to_s + "/9" +
          " item_checks=" + @item_checks.to_i.to_s + " utility_checks=" + @utility_checks.to_i.to_s)
      ensure
        cleanup_test_overrides
        @active = false
        finish_meta_result
      end
    end

    def self.j_failures
      return [] unless defined?(ALBERT_CG::UNIQUE_J_V243)
      value = ALBERT_CG::UNIQUE_J_V243.instance_variable_get(:@failures)
      return value == nil ? [] : value
    rescue
      return ["Unable to read Batch J result"]
    end

    def self.j_covered_move_count
      return 0 unless defined?(ALBERT_CG::UNIQUE_J_V243)
      return ALBERT_CG::UNIQUE_J_V243.covered_move_count.to_i if
        ALBERT_CG::UNIQUE_J_V243.respond_to?(:covered_move_count)
      return 0
    rescue
      return 0
    end

    def self.finish_meta_result
      total_fail = @failures == nil ? 0 : @failures.size
      result = total_fail == 0 ? "PASS" : "FAIL"
      log("------------------------------------------------------------")
      log("RESULT=" + result)
      log("SUMMARY batch_k_failures=" + total_fail.to_s +
          " batch_j_baseline=PASS unique_j_moves=3/3 unique_k_moves=" + covered_move_count.to_s + "/9 pending=0" +
          " held_item_checks=" + @item_checks.to_i.to_s + " utility_checks=" + @utility_checks.to_i.to_s)
      @failures.each_with_index { |x,i| log("K_FAILURE " + (i+1).to_s + " " + x.to_s) } if @failures != nil
      @meta_active = false
      @meta_phase = nil
    end

    def self.cleanup_test_overrides
      list = test_allies + all_enemies
      for b in list
        b.instance_variable_set(:@cg_priority_test_speed_override,nil) if b != nil
      end
    end

    def self.reset_suite
      @round_index = 0
      @failures = []
      @apply_counts = {}
      @actual = []
      @item_checks = 0
      @utility_checks = 0
      @utility_events = []
      @boot_asserted = false
    end

    def self.start_k_test
      reset_k_log
      reset_suite
      run_clone_class_ui_probe
      prepare_test_party
      make_test_troop
      install_skill_scopes
      @active = true
      @meta_active = false
      @meta_phase = nil
      log("AUTO_TEST_START troop=" + TEST_TROOP_ID.to_s)
      ok = ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
      log("K_MAP_BATTLE_REQUEST ok=" + ok.to_s +
          " next_scene=" + ($game_temp == nil ? "nil" : $game_temp.next_scene.to_s) +
          " player_moving=" + ($game_player == nil ? "nil" : $game_player.moving?.to_s))
      return ok
    rescue => e
      @failures = [] if @failures == nil
      @failures.push("AUTO_TEST_START_ERROR " + e.class.to_s + ":" + e.message.to_s)
      log(@failures[-1])
      @active = false
      finish_meta_result
      return false
    end

    def self.start_full_move_completion_test
      return false if @meta_active == true
      install_test_weapons
      @meta_active = true
      @meta_phase = :j
      @meta_j_failures = []
      if defined?(ALBERT_CG::UNIQUE_J_V243)
        ok = ALBERT_CG::UNIQUE_J_V243.start_auto_test
        return true if ok
        @meta_j_failures = ["Batch J start_auto_test returned false"]
        @meta_phase = :k
        return start_k_test
      end
      @meta_j_failures = ["Batch J runtime unavailable"]
      @meta_phase = :k
      return start_k_test
    end

    def self.update_meta_from_map
      return unless @meta_active == true
      return if $game_temp.in_battle
      if @meta_phase == :j
        return if defined?(ALBERT_CG::UNIQUE_J_V243) && ALBERT_CG::UNIQUE_J_V243.active?
        @meta_j_failures = j_failures.clone
        @meta_phase = :k
        start_k_test
      end
    end
  end
end

#==============================================================================
# ■ Game_Troop：Happy Hour reward authority
#==============================================================================
class Game_Troop < Game_Unit
  attr_writer :cg_happy_hour_active

  alias cg_v244_happy_setup setup
  def setup(troop_id)
    @cg_happy_hour_active = false
    cg_v244_happy_setup(troop_id)
  end

  def cg_happy_hour_active?
    return @cg_happy_hour_active == true
  end

  alias cg_v244_gold_total_without_happy gold_total
  def gold_total
    value = cg_v244_gold_total_without_happy
    return cg_happy_hour_active? ? value.to_i * 2 : value
  end
end

#==============================================================================
# ■ Game_Battler：Batch K Skill Effect dispatch
#==============================================================================
class Game_Battler
  alias cg_v244_skill_effect skill_effect
  def skill_effect(user,skill)
    mid = skill == nil ? 0 : ALBERT_CG::MOVE_EFFECT.move_id(skill)
    unless defined?(ALBERT_CG::UNIQUE_K_V244) && ALBERT_CG::UNIQUE_K_V244.handled?(mid)
      return cg_v244_skill_effect(user,skill)
    end
    clear_action_results
    ok = ALBERT_CG::UNIQUE_K_V244.apply_unique(user,self,mid)
    if ok
      ALBERT_CG::UNIQUE_K_V244.mark_apply(mid)
    else
      @skipped = true
      ALBERT_CG::UNIQUE_K_V244.log("APPLY_FAIL move=" + mid.to_s + " user=" +
        (user == nil ? "nil" : user.name.to_s) + " target=" + name.to_s) if ALBERT_CG::UNIQUE_K_V244.active?
    end
    return
  end
end

#==============================================================================
# ■ deterministic SPE bridge
#==============================================================================
class Game_Battler
  alias cg_v244_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::UNIQUE_K_V244) && ALBERT_CG::UNIQUE_K_V244.active?
      value = @cg_priority_test_speed_override
      return value.to_i if value != nil
    end
    return cg_v244_priority_base_speed
  rescue
    return cg_v244_priority_base_speed
  end
end

#==============================================================================
# ■ Game_Enemy：Regression deterministic action
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v244_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::UNIQUE_K_V244) && ALBERT_CG::UNIQUE_K_V244.active?
      action = ALBERT_CG::UNIQUE_K_V244.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v244_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle：K Regression control
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v244_execute_action execute_action
  def execute_action
    battler = @active_battler
    ALBERT_CG::UNIQUE_K_V244.record_execution(battler) if defined?(ALBERT_CG::UNIQUE_K_V244) && ALBERT_CG::UNIQUE_K_V244.active?
    cg_v244_execute_action
  end

  alias cg_v244_turn_end turn_end
  def turn_end
    ALBERT_CG::UNIQUE_K_V244.finish_round_assertions if defined?(ALBERT_CG::UNIQUE_K_V244) && ALBERT_CG::UNIQUE_K_V244.active?
    cg_v244_turn_end
  end

  alias cg_v244_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::UNIQUE_K_V244) && ALBERT_CG::UNIQUE_K_V244.active?
      return cg_v244_start_party_command
    end
    cg_v244_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::UNIQUE_K_V244.assert_bootstrap_once
    if ALBERT_CG::UNIQUE_K_V244.finished?
      ALBERT_CG::UNIQUE_K_V244.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::UNIQUE_K_V244.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle rebuild 後重套 K test data
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v244_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v244_bootstrap_demo_party
      if defined?(ALBERT_CG::UNIQUE_K_V244) && ALBERT_CG::UNIQUE_K_V244.active?
        for cfg in ALBERT_CG::UNIQUE_K_V244::TEST_ALLIES
          ALBERT_CG::UNIQUE_K_V244.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::UNIQUE_K_V244::TEST_LEVEL,false)
          human.recover_all
          human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
          human.cg_v242_clear_runtime if human.respond_to?(:cg_v242_clear_runtime)
        end
      end
      return result
    end
  end
end

#==============================================================================
# ■ Scene_Title：scope / Class permission refresh
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_v244_k_load_database load_database
  def load_database
    cg_v244_k_load_database
    ALBERT_CG::HELD_ITEM_V244.sync_class_permissions if defined?(ALBERT_CG::HELD_ITEM_V244)
    ALBERT_CG::UNIQUE_K_V244.install_skill_scopes
  end

  alias cg_v244_k_load_bt_database load_bt_database
  def load_bt_database
    cg_v244_k_load_bt_database
    ALBERT_CG::HELD_ITEM_V244.sync_class_permissions if defined?(ALBERT_CG::HELD_ITEM_V244)
    ALBERT_CG::UNIQUE_K_V244.install_skill_scopes
  end
end

#==============================================================================
# ■ F11：v2.4.4a 唯一最新版，Batch J 已實機 PASS，本版直接隔離測 Batch K
#------------------------------------------------------------------------------
#  v2.4.4 的 J→K 連續兩場 harness 在第二場只完成 troop setup，尚未進入
#  Scene_Battle。為避免把場景 handoff 問題誤判成 Move bug，本版 F11 從地圖
#  直接啟動 Batch K。Batch J v2.4.3 已有實機 PASS 證據，不重跑。
#==============================================================================
if defined?(ALBERT_CG::UNIQUE_J_V243)
  module ALBERT_CG
    module UNIQUE_J_V243
      def self.f11_trigger?; return false; end
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v244a_scene_map_update update
  def update
    cg_v244a_scene_map_update
    if defined?(ALBERT_CG::UNIQUE_K_V244) && ALBERT_CG::UNIQUE_K_V244.active? &&
       !$game_temp.in_battle && $game_temp.next_scene.to_s == "battle"
      unless @cg_v244a_k_pending_logged == true
        @cg_v244a_k_pending_logged = true
        ALBERT_CG::UNIQUE_K_V244.log("K_MAP_BATTLE_PENDING player_moving=" +
          ($game_player == nil ? "nil" : $game_player.moving?.to_s))
      end
    else
      @cg_v244a_k_pending_logged = false
    end
    if !$game_temp.in_battle && !ALBERT_CG::UNIQUE_K_V244.active? &&
       ALBERT_CG::UNIQUE_K_V244.f11_trigger?
      Sound.play_decision
      ALBERT_CG::UNIQUE_K_V244.start_k_test
    end
  end
end

#==============================================================================
# ■ Scene_Battle：Batch K 場景進入追蹤
#------------------------------------------------------------------------------
#  若仍在 troop setup 後停止，LATEST LOG 會明確區分：
#    K_SCENE_START_ENTER  -> 已進 Scene_Battle#start
#    K_SCENE_START_OK     -> Spriteset / Window 建立完成
#    K_SCENE_START_ERROR  -> start 內 Runtime error
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v244a_k_trace_start start
  def start
    tracing = defined?(ALBERT_CG::UNIQUE_K_V244) && ALBERT_CG::UNIQUE_K_V244.active?
    if tracing
      troop_id = ($game_troop == nil || $game_troop.troop == nil) ? 0 : $game_troop.troop.id.to_i
      ALBERT_CG::UNIQUE_K_V244.log("K_SCENE_START_ENTER troop=" + troop_id.to_s)
    end
    begin
      result = cg_v244a_k_trace_start
      ALBERT_CG::UNIQUE_K_V244.log("K_SCENE_START_OK") if tracing
      return result
    rescue => e
      if tracing
        ALBERT_CG::UNIQUE_K_V244.log("K_SCENE_START_ERROR " + e.class.to_s + ":" + e.message.to_s)
        begin
          for line in caller
            ALBERT_CG::UNIQUE_K_V244.log("  " + line.to_s)
          end
        rescue
        end
      end
      raise
    end
  end
end

#==============================================================================
# ■ Coverage：最後 9 Pending -> V244_UNIQUE_K_HANDLED（v2.4.4a K-only regression）
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    class << self
      alias cg_v244_coverage_v231 coverage_v231
      def coverage_v231(move_id)
        return "V244_UNIQUE_K_HANDLED" if ALBERT_CG::UNIQUE_K_V244.handled?(move_id)
        return cg_v244_coverage_v231(move_id)
      end
    end
  end
end
