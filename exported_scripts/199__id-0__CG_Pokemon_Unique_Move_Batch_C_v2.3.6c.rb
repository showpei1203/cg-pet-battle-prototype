# RMVX_SCRIPT_INDEX: 199
# RMVX_SCRIPT_ID: 0
# RMVX_SCRIPT_NAME: CG Pokemon Unique Move Batch C v2.3.6c
# RMVX_SOURCE_SHA256: 6e583fd80e4ea672bc50973b218e31aef6cbdd6edee87cd51d737a7f1e0d2521

#==============================================================================
# ■ CG Pokemon Unique Move Batch C v2.3.6c
#------------------------------------------------------------------------------
# 【用途】
#  接續 v2.3.5a 已完成的 Field / Force Switch / Unique Batch B，正式處理
#  13 個「鎖定、牽制、導引、站位與隊友支援」Unique Move：
#    169 Spider Web／蛛網         170 Mind Reader／心之眼
#    199 Lock-On／鎖定            212 Mean Look／黑色目光
#    266 Follow Me／看我嘛        270 Helping Hand／幫助
#    335 Block／擋路              367 Acupressure／點穴
#    476 Rage Powder／憤怒粉      502 Ally Switch／交換場地
#    579 Flower Shield／鮮花防守  671 Spotlight／聚光燈
#    673 Laser Focus／磨礪
#
# 【正式機制規則】
#  1. Spider Web / Mean Look / Block：
#     對目標建立「換出封鎖」Volatile。它們不造成束縛傷害，也不阻擋 Roar／
#     Whirlwind 強制換出；只限制一般主動換寵。換出／戰鬥結束後清除。
#  2. Mind Reader / Lock-On：
#     記錄使用者與指定目標。使用者下一次對該目標的單體攻擊 Hit=100、Eva=0，
#     攻擊執行後消耗。兩招共用同一 Guaranteed-Hit 記憶層。
#  3. Laser Focus：
#     使用者下一次造成傷害的 Attack／Skill 必定 Critical，執行後消耗。
#  4. Follow Me / Rage Powder：
#     使用後直到本回合結束，把敵方「單體對手」攻擊導向使用者；仍遵守本專案
#     Battlefield Grid 合法射程。Rage Powder 對 Grass-type 與 Ability 142
#     Overcoat／防塵的攻擊者不生效；本專案沒有持有道具，因此不做 Safety Goggles。
#  5. Spotlight：
#     本作把選定的我方單位設為本回合 Redirector。原作可對 selected Pokémon，
#     但 VX 原生選擇器無法在同一技能同時跨敵我選擇，因此正式 UI 採「一名我方」；
#     核心 API 仍可直接指定任意同側目標。
#  6. Helping Hand：
#     目標隊友本回合下一個傷害行動傷害 ×150%，整個 Action（含多目標／多段）
#     共用同一加成，Action 結束後清除。
#  7. Acupressure：
#     從未滿 +6 的 ATK/DEF/SpA/SpD/SPE/Accuracy/Evasion 隨機選一項 +2；
#     Regression 固定選 SPE，確保 deterministic。
#  8. Ally Switch：
#     使用者與指定隊友交換 Battlefield Grid row/column；不交換 HP、狀態、行動、
#     instance identity。v2.3.6a 改用「安全 XY 座標同步」刷新 Tankentai 位置。
#     特別禁止在 skill_effect 執行途中呼叫 reset_coordinate，因 Tankentai 3.3 的
#     reset_coordinate 會把 @active 設為 false，導致 Sprite_Battler 無法送出 End，
#     Scene_Battle#playing_action 因此永久等待。
#  9. Flower Shield：
#     場上所有仍存活的 Grass-type Pokémon DEF +1（敵我皆含）。因 v2.3.0 Metadata
#     原本只會對單一 recipient +1，本版會移除該 Generic Stage Metadata，避免重複。
#
# 【可調參數】
#  HELPING_HAND_PERCENT = 150
#  OVERCOAT_ABILITY_ID  = 142
#  TEST_TROOP_ID        = 693
#  TEST_LEVEL           = 40
#
# 【事件／腳本呼叫方式】
#  正常戰鬥完全自動，不需事件呼叫。Debug 可使用：
#    battler.cg_v236_switch_locked?                     # 是否被蛛網等封鎖換出
#    ALBERT_CG::UNIQUE_C_V236.set_redirect(battler,:follow_me)
#    ALBERT_CG::UNIQUE_C_V236.swap_grid(user, ally)
#
# 【實際範例】
#  皮卡丘使用「看我嘛」後，敵方怪力原本指定妙蛙花使用單體攻擊：
#    REDIRECT kind=follow_me attacker=怪力 from=妙蛙花 to=皮卡丘
#  若皮卡丘與怪力間的 Grid 射程不合法，則不會繞過 Grid 強制導引。
#
# 【v2.3.6a Runtime 修正】
#  v2.3.6 的 Ally Switch 在 skill_effect 內呼叫 Game_Battler#reset_coordinate。
#  Tankentai 3.3 的該方法同時會執行 @active=false；而 Sprite_Battler#send_action
#  只有 battler.active 時才會把「End」送回 Scene_Battle，造成第一個 Ally Switch
#  後 Scene_Battle#playing_action 無限等待。v2.3.6a 改為只更新 Grid base_position
#  與 move_x/move_y，不碰 @active/@individual/@derivation 等 Action Runtime 狀態。
#
#
# 【v2.3.6c Runtime 修正】
#  v2.3.6a 實機已通過 R1~R3 與 Ally Switch，但敵方卡比獸使用 Rage Powder
#  時只有 PMD 動畫，沒有 REDIRECT_SET。這表示自訂效果在呼叫既有 VX/Tankentai
#  skill_effect 後被結果旗標提前 return。Rage Powder 本質是「使用者自身建立本回合
#  Redirect volatile」，沒有原生 RPG::Skill 傷害／狀態資料，因此 v2.3.6c 改為在
#  進入既有空效果判定前直接 clear_action_results → mark_apply → set_redirect。
#  此處只前置處理 Rage Powder；已實機 PASS 的另外 12 招維持原流程。
#  Regression 另記 RAGE_POWDER_PREHANDLE，便於確認效果確實在技能傷害時點落地。
#
# 【v2.3.6c Runtime／Regression 修正】
#  v2.3.6b 實機已確認 Rage Powder 正常建立 Redirect，13/13 Coverage 與 redirects=3
#  皆 PASS；唯一剩餘 FAIL 是 Round5 的 E2 巨金怪未出手。原因不是 Redirect 殘留，
#  而是 Regression 自己在 Round3 先用 Laser Focus 暴擊暗影球重創 E2，Round5 又在
#  E2 行動前安排我方耿鬼第二發暗影球指定 E2，導致 E2 被擊倒後自然無法執行 Splash。
#  v2.3.6c 僅隔離 Round5 測試干擾：A2/A3 改用 Splash，A0 普攻改打耐久較高的 E1；
#  正式 13 招機制完全不改。另新增 ROUND5_PRECHECK，明確 ASSERT E2 在 Round5 開始時
#  仍存活，避免測試器再把「演員先被打死」誤判成技能系統失敗。
#
# 【AutoRegression】
#  地圖畫面只按 F11，執行 5 回合真正 Scene_Battle：
#    R1：Spider Web / Mean Look / Block + Ally Switch
#    R2：Mind Reader / Lock-On / Laser Focus + Acupressure
#    R3：兩種 Guaranteed Hit 實擊 + Laser Focus Crit + Helping Hand 150%
#    R4：Follow Me / Rage Powder 雙向 Redirect + Flower Shield
#    R5：Spotlight Redirect，並確認前回合 Redirect 已清除
#  成功標準：
#    RESULT=PASS
#    SUMMARY rounds=5 failures=0 unique_c_moves=13/13 redirects=3
#
# 【LOG】
#  版本 LOG：Pokemon_UniqueC_AutoTest_v2_3_6c.log
#  固定最新版：CG_AutoRegression_LATEST.log
#  ASSERT / REDIRECT / HIT_LOCK / LASER_FOCUS / HELPING_HAND 等重要事件亦鏡像到
#  PMD_BattleInitTrace.log。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonUniqueMoveBatchC"] = "2.3.6c"

module ALBERT_CG
  module UNIQUE_C_V236
    VERSION = "2.3.6c"

    MOVE_SPIDER_WEB    = 169
    MOVE_MIND_READER   = 170
    MOVE_LOCK_ON       = 199
    MOVE_MEAN_LOOK     = 212
    MOVE_FOLLOW_ME     = 266
    MOVE_HELPING_HAND  = 270
    MOVE_BLOCK         = 335
    MOVE_ACUPRESSURE   = 367
    MOVE_RAGE_POWDER   = 476
    MOVE_ALLY_SWITCH   = 502
    MOVE_FLOWER_SHIELD = 579
    MOVE_SPOTLIGHT     = 671
    MOVE_LASER_FOCUS   = 673

    HANDLED_MOVE_IDS = [
      MOVE_SPIDER_WEB, MOVE_MIND_READER, MOVE_LOCK_ON, MOVE_MEAN_LOOK,
      MOVE_FOLLOW_ME, MOVE_HELPING_HAND, MOVE_BLOCK, MOVE_ACUPRESSURE,
      MOVE_RAGE_POWDER, MOVE_ALLY_SWITCH, MOVE_FLOWER_SHIELD,
      MOVE_SPOTLIGHT, MOVE_LASER_FOCUS
    ]

    SWITCH_LOCK_MOVES = [MOVE_SPIDER_WEB, MOVE_MEAN_LOOK, MOVE_BLOCK]
    HIT_LOCK_MOVES    = [MOVE_MIND_READER, MOVE_LOCK_ON]
    HELPING_HAND_PERCENT = 150
    OVERCOAT_ABILITY_ID  = 142

    TEST_TROOP_ID = 693
    TEST_LEVEL = 40
    TEST_ALLIES = [
      {:dex=>25, :level=>40, :ability=>9,   :moves=>[169,170,266,671]},
      {:dex=>3,  :level=>40, :ability=>65,  :moves=>[212,199,579,33]},
      {:dex=>94, :level=>40, :ability=>130, :moves=>[335,673,247,33]},
    ]
    TEST_ENEMIES = [
      {:dex=>68,  :level=>40, :ability=>62,  :moves=>[33,150,150,150]},
      {:dex=>143, :level=>40, :ability=>47,  :moves=>[476,150,150,150]},
      {:dex=>376, :level=>40, :ability=>29,  :moves=>[94,150,150,150]},
      {:dex=>94,  :level=>40, :ability=>130, :moves=>[502,367,270,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"TRAP_AND_ALLY_SWITCH",
        :allies=>[
          {:kind=>:attack,:target=>0},
          {:kind=>:move,:move_id=>169,:target=>0},
          {:kind=>:move,:move_id=>212,:target=>1},
          {:kind=>:move,:move_id=>335,:target=>2},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>502,:target=>2},
        ]
      },
      {
        :name=>"LOCK_CRIT_ACUPRESSURE_SETUP",
        :allies=>[
          {:kind=>:attack,:target=>0},
          {:kind=>:move,:move_id=>170,:target=>0},
          {:kind=>:move,:move_id=>199,:target=>1},
          {:kind=>:move,:move_id=>673,:target=>2},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>367,:target=>3},
        ]
      },
      {
        :name=>"LOCK_CRIT_HELPING_HAND_EXECUTION",
        :allies=>[
          {:kind=>:attack,:target=>0},
          {:kind=>:attack,:target=>0},
          {:kind=>:attack,:target=>1},
          {:kind=>:move,:move_id=>247,:target=>2},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>94,:target=>0},
          {:kind=>:move,:move_id=>270,:target=>2},
        ]
      },
      {
        :name=>"FOLLOW_RAGE_FLOWER_REDIRECT",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>266,:target=>1},
          {:kind=>:move,:move_id=>579,:target=>2},
          {:kind=>:move,:move_id=>247,:target=>2},
        ],
        :enemies=>[
          {:kind=>:attack,:target=>3},
          {:kind=>:move,:move_id=>476,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
      {
        :name=>"SPOTLIGHT_REDIRECT_AND_CLEANUP",
        :allies=>[
          {:kind=>:attack,:target=>1},
          {:kind=>:move,:move_id=>671,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>[
          {:kind=>:attack,:target=>3},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
    ]

    TEST_SPEEDS = {
      :r1=>[100,130,120,110, 80,70,60,50],
      :r2=>[100,130,120,110, 80,70,60,50],
      :r3=>[100,130,120,110, 80,70,60,50],
      :r4=>[100,130,120,110, 80,70,60,50],
      :r5=>[100,130,120,110, 80,70,60,50],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["E3:M502","A1:M169","A2:M212","A3:M335","A0:Attack","E0:M150","E1:M150","E2:M150"],
      2=>["A1:M170","A2:M199","A3:M673","A0:Attack","E0:M150","E1:M150","E2:M150","E3:M367"],
      3=>["E3:M270","A1:Attack","A2:Attack","A3:M247","A0:Attack","E0:M150","E1:M150","E2:M94"],
      4=>["A0:Guard","A1:M266","E1:M476","A2:M579","A3:M247","E0:Attack","E2:M150","E3:M150"],
      5=>["A1:M671","A2:M150","A3:M150","A0:Attack","E0:Attack","E1:M150","E2:M150","E3:M150"],
    }

    VK_F11 = 0x7A
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
      return File.join(project_root, "Pokemon_UniqueC_AutoTest_v2_3_6c.log")
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
      return true if line.index("REDIRECT ") == 0
      return true if line.index("HIT_LOCK_") == 0
      return true if line.index("LASER_FOCUS_") == 0
      return true if line.index("HELPING_HAND_") == 0
      return true if line.index("ALLY_SWITCH") == 0
      return true if line.index("RESULT=") == 0 || line.index("SUMMARY ") == 0
      return false
    end

    def self.log(line)
      text = line.to_s
      write_line(log_path, text)
      write_line(latest_log_path, text)
      write_line(trace_log_path, "[UNIQUE_C_AUTOTEST] " + text) if important_line?(text)
    end

    def self.reset_log
      header = [
        "CG POKEMON UNIQUE MOVE C AUTO REGRESSION v2.3.6c",
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        "RULE=Actual Scene_Battle; 13 control/support Unique Moves; deterministic targeting",
        "AUTOTEST_LOG_PATH=" + log_path.to_s,
        "AUTOTEST_LATEST_PATH=" + latest_log_path.to_s,
        "------------------------------------------------------------"
      ]
      [log_path, latest_log_path].each do |p|
        begin
          File.open(p, "wb") { |f| header.each { |x| f.write(x + "\r\n") } }
        rescue
        end
      end
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
    rescue
      return false
    end

    def self.handled?(move_id)
      return HANDLED_MOVE_IDS.include?(move_id.to_i)
    end

    def self.ability_id(battler)
      return 0 if battler == nil || !battler.respond_to?(:cg_master_ability_id)
      return battler.cg_master_ability_id.to_i
    rescue
      return 0
    end

    def self.show_text(text)
      scene = $scene
      if scene != nil && scene.respond_to?(:cg_show_special_action_text, true)
        scene.send(:cg_show_special_action_text, text.to_s)
      end
    rescue
    end

    def self.install_skill_scopes
      return if master == nil || $data_skills == nil
      scopes = {
        MOVE_SPIDER_WEB=>1, MOVE_MIND_READER=>1, MOVE_LOCK_ON=>1,
        MOVE_MEAN_LOOK=>1, MOVE_BLOCK=>1,
        MOVE_FOLLOW_ME=>11, MOVE_RAGE_POWDER=>11,
        MOVE_LASER_FOCUS=>11, MOVE_FLOWER_SHIELD=>11,
        MOVE_HELPING_HAND=>7, MOVE_ACUPRESSURE=>7,
        MOVE_ALLY_SWITCH=>7, MOVE_SPOTLIGHT=>7,
      }
      scopes.each do |mid, scope|
        sid = master.skill_id_for_move(mid)
        $data_skills[sid].scope = scope if sid.to_i > 0 && $data_skills[sid] != nil
      end
      if defined?(ALBERT_CG::MOVE_EFFECT) &&
         ALBERT_CG::MOVE_EFFECT.const_defined?(:MOVE_STAT_CHANGES)
        ALBERT_CG::MOVE_EFFECT::MOVE_STAT_CHANGES.delete(MOVE_FLOWER_SHIELD)
      end
    rescue => e
      log("SCOPE_INSTALL_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
    end

    def self.set_switch_lock(target, user, move_id)
      return if target == nil
      target.instance_variable_set(:@cg_v236_switch_lock, true)
      target.instance_variable_set(:@cg_v236_switch_lock_source, user)
      target.instance_variable_set(:@cg_v236_switch_lock_move, move_id.to_i)
      log("SWITCH_LOCK_SET move=" + move_id.to_i.to_s + " target=" + target.name.to_s)
      show_text(target.name.to_s + "被封鎖了換出路線！")
    end

    def self.set_hit_lock(user, target, move_id)
      return if user == nil || target == nil
      user.instance_variable_set(:@cg_v236_hit_lock_target, target)
      user.instance_variable_set(:@cg_v236_hit_lock_move, move_id.to_i)
      log("HIT_LOCK_SET move=" + move_id.to_i.to_s + " user=" + user.name.to_s +
          " target=" + target.name.to_s)
      show_text(user.name.to_s + "鎖定了" + target.name.to_s + "！")
    end

    def self.set_laser_focus(user)
      return if user == nil
      user.instance_variable_set(:@cg_v236_laser_focus, true)
      log("LASER_FOCUS_SET user=" + user.name.to_s)
      show_text(user.name.to_s + "集中精神，下一擊必定暴擊！")
    end

    def self.set_helping_hand(target, user)
      return if target == nil
      target.instance_variable_set(:@cg_v236_helping_hand, true)
      target.instance_variable_set(:@cg_v236_helping_hand_source, user)
      log("HELPING_HAND_SET user=" + user.name.to_s + " target=" + target.name.to_s)
      show_text(target.name.to_s + "受到幫助，下一擊威力提升！")
    end

    def self.set_redirect(target, kind)
      return if target == nil
      @redirect_seq = @redirect_seq.to_i + 1
      target.instance_variable_set(:@cg_v236_redirect_kind, kind)
      target.instance_variable_set(:@cg_v236_redirect_seq, @redirect_seq)
      side = target.actor? ? :actor : :enemy
      @redirectors = {} if @redirectors == nil
      @redirectors[side] = target
      log("REDIRECT_SET kind=" + kind.to_s + " target=" + target.name.to_s +
          " side=" + side.to_s)
      show_text(target.name.to_s + "吸引了本回合的單體攻擊！")
    end

    def self.clear_redirects
      if @redirectors != nil
        @redirectors.values.each do |b|
          next if b == nil
          b.instance_variable_set(:@cg_v236_redirect_kind, nil)
          b.instance_variable_set(:@cg_v236_redirect_seq, nil)
        end
      end
      @redirectors = {}
    end

    def self.rage_powder_immune?(attacker)
      return false if attacker == nil
      if attacker.respond_to?(:cg_pokemon_types)
        types = attacker.cg_pokemon_types
        return true if types != nil && types.include?(:grass)
      end
      return true if ability_id(attacker) == OVERCOAT_ABILITY_ID
      return false
    rescue
      return false
    end

    def self.redirect_target_for(action, original)
      return nil if action == nil || original == nil || original.empty?
      battler = action.battler
      return nil if battler == nil
      # 僅單體對手行動；全體／隨機多體不改寫。
      one = action.attack?
      if action.skill?
        sk = action.skill
        one = (sk != nil && sk.scope.to_i == 1)
      end
      return nil unless one
      side = battler.actor? ? :enemy : :actor
      redirector = @redirectors == nil ? nil : @redirectors[side]
      return nil if redirector == nil || !redirector.exist?
      kind = redirector.instance_variable_get(:@cg_v236_redirect_kind)
      return nil if kind == :rage_powder && rage_powder_immune?(battler)
      if action.respond_to?(:cg_target_legal?) && !action.cg_target_legal?(redirector)
        return nil
      end
      from = original[0]
      return nil if from == redirector
      action.target_index = redirector.index if action.respond_to?(:target_index=)
      @redirect_events = [] if @redirect_events == nil
      ev = {:round=>current_round,:kind=>kind,:attacker=>battler,:from=>from,:to=>redirector}
      @redirect_events.push(ev)
      log("REDIRECT kind=" + kind.to_s + " attacker=" + battler.name.to_s +
          " from=" + (from == nil ? "nil" : from.name.to_s) + " to=" + redirector.name.to_s)
      return redirector
    end

    # Ally Switch 專用安全座標同步。
    # 注意：不可在技能 Action 尚未結束時呼叫 Tankentai reset_coordinate。
    # reset_coordinate 會把 battler.@active=false，使 Sprite_Battler#send_action
    # 無法送出 End，Scene_Battle#playing_action 便會永遠卡在 loop。
    def self.sync_grid_xy_without_action_reset(battler)
      return false if battler == nil
      battler.move_x = 0 if battler.respond_to?(:move_x=)
      battler.move_y = 0 if battler.respond_to?(:move_y=)
      battler.base_position if battler.respond_to?(:base_position)
      return true
    rescue => e
      log("ALLY_SWITCH_SYNC_ERROR " + e.class.to_s + ":" + e.message.to_s)
      return false
    end

    def self.swap_grid(user, target)
      return false if user == nil || target == nil || user == target
      return false unless user.actor? == target.actor?
      return false unless user.respond_to?(:cg_battle_slot_assigned?) && user.cg_battle_slot_assigned?
      return false unless target.respond_to?(:cg_battle_slot_assigned?) && target.cg_battle_slot_assigned?
      a = [user.cg_battle_row, user.cg_battle_column]
      b = [target.cg_battle_row, target.cg_battle_column]
      active_before = user.instance_variable_get(:@active) == true
      user.cg_set_battle_slot(b[0], b[1], true)
      target.cg_set_battle_slot(a[0], a[1], true)
      sync_grid_xy_without_action_reset(user)
      sync_grid_xy_without_action_reset(target)
      active_after = user.instance_variable_get(:@active) == true
      log("ALLY_SWITCH user=" + user.name.to_s + " target=" + target.name.to_s +
          " user_slot=" + a.inspect + "->" + b.inspect +
          " target_slot=" + b.inspect + "->" + a.inspect)
      log("ALLY_SWITCH_SAFE_SYNC user=" + user.name.to_s +
          " active_before=" + active_before.to_s +
          " active_after=" + active_after.to_s)
      show_text(user.name.to_s + "與" + target.name.to_s + "交換了站位！")
      return true
    rescue => e
      log("ALLY_SWITCH_ERROR " + e.class.to_s + ":" + e.message.to_s)
      return false
    end

    def self.apply_acupressure(target)
      return nil if target == nil || !target.respond_to?(:cg_stat_stage)
      keys = [:atk,:def,:spa,:spd,:spe,:accuracy,:evasion].select do |k|
        target.cg_stat_stage(k) < 6
      end
      return nil if keys.empty?
      key = active? ? :spe : keys[rand(keys.size)]
      key = keys[0] unless keys.include?(key)
      delta = target.cg_change_stat_stage(key, 2)
      log("ACUPRESSURE target=" + target.name.to_s + " stat=" + key.to_s +
          " delta=" + delta.to_i.to_s + " stage=" + target.cg_stat_stage(key).to_s)
      show_text(target.name.to_s + "的" + key.to_s.upcase + "大幅提升！")
      return key
    end

    def self.apply_flower_shield(user)
      list = []
      list.concat($game_party.members) if $game_party != nil
      list.concat($game_troop.members) if $game_troop != nil
      affected = []
      list.each do |b|
        next if b == nil || !b.exist? || !b.respond_to?(:cg_pokemon_types)
        next unless b.cg_pokemon_types.include?(:grass)
        delta = b.cg_change_stat_stage(:def, 1)
        affected.push([b.name.to_s, delta.to_i, b.cg_stat_stage(:def)])
      end
      log("FLOWER_SHIELD user=" + user.name.to_s + " affected=" + affected.inspect)
      show_text("鮮花防守提升了場上草屬性寶可夢的防禦！")
      return affected
    end

    def self.mark_apply(move_id)
      @apply_counts = {} if @apply_counts == nil
      mid = move_id.to_i
      @apply_counts[mid] = @apply_counts[mid].to_i + 1
    end

    def self.note_hit_override(user, target, kind)
      @hit_events = [] if @hit_events == nil
      @hit_events.push({:round=>current_round,:user=>user,:target=>target,:kind=>kind})
      log("HIT_LOCK_OVERRIDE kind=" + kind.to_s + " user=" + user.name.to_s +
          " target=" + target.name.to_s)
    end

    def self.note_laser_crit(user, target)
      @crit_events = [] if @crit_events == nil
      @crit_events.push({:round=>current_round,:user=>user,:target=>target})
      log("LASER_FOCUS_CRIT user=" + user.name.to_s + " target=" + target.name.to_s)
    end

    def self.note_helping_damage(user, target, base, final)
      @help_events = [] if @help_events == nil
      @help_events.push({:round=>current_round,:user=>user,:target=>target,
                         :base=>base.to_i,:final=>final.to_i})
      log("HELPING_HAND_DAMAGE user=" + user.name.to_s + " target=" + target.name.to_s +
          " base=" + base.to_i.to_s + " final=" + final.to_i.to_s)
    end

    def self.action_damaging?(action)
      return false if action == nil
      return true if action.attack?
      if action.skill?
        sk = action.skill
        return sk != nil && sk.base_damage.to_i > 0
      end
      return false
    rescue
      return false
    end

    def self.after_action_cleanup(battler, action)
      return if battler == nil || action == nil
      mid = action.skill? && action.skill != nil ? ALBERT_CG::MOVE_EFFECT.move_id(action.skill) : 0
      damaging = action_damaging?(action)
      if battler.instance_variable_get(:@cg_v236_hit_lock_target) != nil &&
         !HIT_LOCK_MOVES.include?(mid) && damaging
        log("HIT_LOCK_CONSUME user=" + battler.name.to_s + " move=" + mid.to_s)
        battler.instance_variable_set(:@cg_v236_hit_lock_target, nil)
        battler.instance_variable_set(:@cg_v236_hit_lock_move, nil)
      end
      if battler.instance_variable_get(:@cg_v236_laser_focus) == true &&
         mid != MOVE_LASER_FOCUS && damaging
        log("LASER_FOCUS_CONSUME user=" + battler.name.to_s + " move=" + mid.to_s)
        battler.instance_variable_set(:@cg_v236_laser_focus, false)
      end
      if battler.instance_variable_get(:@cg_v236_helping_hand) == true && damaging
        log("HELPING_HAND_CONSUME battler=" + battler.name.to_s + " move=" + mid.to_s)
        battler.instance_variable_set(:@cg_v236_helping_hand, false)
        battler.instance_variable_set(:@cg_v236_helping_hand_source, nil)
      end
    end

    def self.test_allies
      return $game_party == nil ? [] : $game_party.members[0,4]
    end

    def self.test_enemies
      return $game_troop == nil ? [] : $game_troop.members[0,4]
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
      actor.cg_v236_clear_volatile if actor.respond_to?(:cg_v236_clear_volatile)
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
        human.cg_v236_clear_volatile if human.respond_to?(:cg_v236_clear_volatile)
      end
      return true
    end

    def self.apply_test_grid
      allies = test_allies
      enemies = test_enemies
      slots_a = [[:back,1],[:front,0],[:front,1],[:front,2]]
      slots_e = [[:front,0],[:front,1],[:front,2],[:back,1]]
      allies.each_with_index do |b,i|
        b.cg_set_battle_slot(slots_a[i][0], slots_a[i][1], true) if b != nil && b.respond_to?(:cg_set_battle_slot)
      end
      enemies.each_with_index do |b,i|
        b.cg_set_battle_slot(slots_e[i][0], slots_e[i][1], true) if b != nil && b.respond_to?(:cg_set_battle_slot)
      end
    end

    def self.make_test_troop
      master.ensure_index($data_troops, TEST_TROOP_ID)
      xs = [ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[1],
            ALBERT_CG::GRID_COLUMN_Y[2], ALBERT_CG::GRID_COLUMN_Y[1]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg, i|
        configure_enemy(cfg)
        members.push(ALBERT_CG::SPECIES26.make_troop_member(
          master.enemy_id_for_dex(cfg[:dex]), xs[i], ys[i]))
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID, "Pokemon UniqueC v2.3.6 AutoRegression", members)
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
      cfg = current_plan == nil ? nil : current_plan[:enemies][enemy.index]
      return nil if cfg == nil
      return make_action(enemy, cfg)
    end

    def self.apply_test_speeds
      vals = TEST_SPEEDS[("r" + current_round.to_s).to_sym] || []
      list = test_allies + test_enemies
      list.each_with_index do |b,i|
        b.instance_variable_set(:@cg_priority_test_speed_override, vals[i]) if b != nil
      end
    end

    def self.record_execution(battler)
      return unless active? && battler != nil
      @actual = [] if @actual == nil
      token = battler.actor? ? "A" + battler.index.to_s : "E" + battler.index.to_s
      if battler.action != nil && battler.action.skill?
        mid = ALBERT_CG::MOVE_EFFECT.move_id(battler.action.skill)
        token += ":M" + mid.to_s
      elsif battler.action != nil && battler.action.attack?
        token += ":Attack"
      elsif battler.action != nil && battler.action.guard?
        token += ":Guard"
      else
        token += ":Other"
      end
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + battler.name.to_s + " token=" + token)
    end

    def self.prepare_round_preconditions
      allies = test_allies
      enemies = test_enemies
      if current_round == 1
        @r1_e2_slot = enemies[2] == nil ? nil : [enemies[2].cg_battle_row,enemies[2].cg_battle_column]
        @r1_e3_slot = enemies[3] == nil ? nil : [enemies[3].cg_battle_row,enemies[3].cg_battle_column]
      elsif current_round == 3
        enemies[0].cg_change_stat_stage(:evasion, 6) if enemies[0] != nil
        enemies[1].cg_change_stat_stage(:evasion, 6) if enemies[1] != nil
      elsif current_round == 4
        @r4_venusaur_def = allies[2] == nil ? 0 : allies[2].cg_stat_stage(:def)
      elsif current_round == 5
        # 前回合 Redirect 必須已被清掉，Spotlight 才是唯一 actor-side redirector。
        @r5_redirect_before = @redirectors == nil ? nil : @redirectors[:actor]
        @r5_e2_alive_before = enemies[2] != nil && enemies[2].exist?
        @r5_e2_hp_before = enemies[2] == nil ? 0 : enemies[2].hp.to_i
        log("ROUND5_PRECHECK E2=" + (enemies[2] == nil ? "nil" : enemies[2].name.to_s) +
            " alive=" + @r5_e2_alive_before.to_s + " hp=" + @r5_e2_hp_before.to_s)
      end
    end

    def self.assign_action_to(b, action)
      return if b == nil
      if b.respond_to?(:cg_round_actions)
        b.cg_round_actions.clear
        b.cg_round_actions.push(action)
      end
      b.cg_assign_action(action) if b.respond_to?(:cg_assign_action)
      b.instance_variable_set(:@action, action) unless b.respond_to?(:cg_assign_action)
    end

    def self.prepare_round_actions
      plan = current_plan
      return false if plan == nil
      apply_test_speeds
      prepare_round_preconditions
      @actual = []
      log("ROUND " + current_round.to_s + " BEGIN " + plan[:name].to_s)
      allies = test_allies
      plan[:allies].each_with_index do |cfg,i|
        b = allies[i]
        next if b == nil
        assign_action_to(b, make_action(b,cfg))
      end
      return true
    end

    def self.assert(condition, text)
      if condition
        log("ASSERT PASS " + text.to_s)
      else
        @failures = @failures.to_i + 1
        @failure_lines = [] if @failure_lines == nil
        @failure_lines.push(text.to_s)
        log("ASSERT FAIL " + text.to_s)
      end
      return condition
    end

    def self.events_for_round(list, round)
      return [] if list == nil
      return list.select { |e| e[:round].to_i == round.to_i }
    end

    def self.finish_round_assertions
      round = current_round
      expected = EXPECTED_EXECUTION_TOKENS[round] || []
      actual = @actual || []
      assert(actual.size == 8, "Round" + round.to_s + " executes exactly 8 scripted battler actions actual=" + actual.size.to_s)
      assert(actual == expected, "Round" + round.to_s + " execution order matches deterministic plan expected=" + expected.inspect + " actual=" + actual.inspect)
      allies = test_allies
      enemies = test_enemies
      case round
      when 1
        assert(enemies[0].cg_v236_switch_locked?, "Spider Web sets switch lock on E0")
        assert(enemies[1].cg_v236_switch_locked?, "Mean Look sets switch lock on E1")
        assert(enemies[2].cg_v236_switch_locked?, "Block sets switch lock on E2")
        ok = enemies[2] != nil && enemies[3] != nil &&
             [enemies[2].cg_battle_row,enemies[2].cg_battle_column] == @r1_e3_slot &&
             [enemies[3].cg_battle_row,enemies[3].cg_battle_column] == @r1_e2_slot
        assert(ok, "Ally Switch exchanges exact enemy Grid slots")
      when 2
        assert(allies[1].instance_variable_get(:@cg_v236_hit_lock_target) == enemies[0], "Mind Reader stores E0 guaranteed-hit target")
        assert(allies[2].instance_variable_get(:@cg_v236_hit_lock_target) == enemies[1], "Lock-On stores E1 guaranteed-hit target")
        assert(allies[3].instance_variable_get(:@cg_v236_laser_focus) == true, "Laser Focus arms next critical")
        assert(enemies[3].cg_stat_stage(:spe) == 2, "Acupressure deterministic SPE +2 stage=" + enemies[3].cg_stat_stage(:spe).to_s)
      when 3
        hits = events_for_round(@hit_events,3)
        assert(hits.any? { |e| e[:user] == allies[1] && e[:target] == enemies[0] }, "Mind Reader overrides real attack accuracy")
        assert(hits.any? { |e| e[:user] == allies[2] && e[:target] == enemies[1] }, "Lock-On overrides real attack accuracy")
        assert(allies[1].instance_variable_get(:@cg_v236_hit_lock_target) == nil && allies[2].instance_variable_get(:@cg_v236_hit_lock_target) == nil, "Guaranteed-hit locks consume after attack")
        crits = events_for_round(@crit_events,3)
        assert(crits.any? { |e| e[:user] == allies[3] }, "Laser Focus produces guaranteed real critical")
        helps = events_for_round(@help_events,3)
        assert(helps.any? { |e| e[:user] == enemies[2] && e[:final].to_i == [e[:base].to_i * HELPING_HAND_PERCENT / 100, 1].max }, "Helping Hand applies exact 150% damage multiplier")
      when 4
        redirects = events_for_round(@redirect_events,4)
        assert(redirects.any? { |e| e[:kind] == :follow_me && e[:attacker] == enemies[0] && e[:to] == allies[1] }, "Follow Me redirects enemy single-target attack")
        assert(redirects.any? { |e| e[:kind] == :rage_powder && e[:attacker] == allies[3] && e[:to] == enemies[1] }, "Rage Powder redirects opposing single-target attack")
        assert(allies[2].cg_stat_stage(:def) == @r4_venusaur_def.to_i + 1, "Flower Shield raises Grass Venusaur DEF +1")
      when 5
        redirects = events_for_round(@redirect_events,5)
        assert(@r5_e2_alive_before == true, "Round5 E2 enters round alive hp=" + @r5_e2_hp_before.to_i.to_s)
        assert(@r5_redirect_before == nil, "Round4 redirect flags cleared before Round5")
        assert(redirects.any? { |e| e[:kind] == :spotlight && e[:attacker] == enemies[0] && e[:to] == allies[2] }, "Spotlight redirects enemy attack to selected ally")
      end
      log("ROUND " + round.to_s + " END")
      clear_redirects
      @round_index = @round_index.to_i + 1
    end

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted = true
      install_skill_scopes
      apply_test_grid
      assert(current_troop_id == TEST_TROOP_ID, "Scene_Battle uses Unique C test troop actual=" + current_troop_id.to_s)
      assert(test_allies.size == 4, "Unique C ally count=4 actual=" + test_allies.size.to_s)
      assert(test_enemies.size == 4, "Unique C enemy count=4 actual=" + test_enemies.size.to_s)
      assert(test_allies.collect { |b| b.actor? ? b.id : 0 } == [1,124,102,193], "Unique C exact ally roster")
      assert(test_enemies.collect { |b| b.enemy_id } == [667,742,975,693], "Unique C exact enemy roster")
    end

    def self.finish_suite
      missing = HANDLED_MOVE_IDS.select { |mid| @apply_counts[mid].to_i <= 0 }
      assert(missing.empty?, "All 13 Unique Batch C moves executed missing=" + missing.inspect)
      redirects = @redirect_events == nil ? 0 : @redirect_events.size
      log("------------------------------------------------------------")
      if @failures.to_i <= 0
        log("RESULT=PASS")
      else
        log("RESULT=FAIL")
      end
      log("SUMMARY rounds=5 failures=" + @failures.to_i.to_s +
          " unique_c_moves=" + (HANDLED_MOVE_IDS.size - missing.size).to_s + "/13 redirects=" + redirects.to_s)
      if @failure_lines != nil
        @failure_lines.each_with_index { |x,i| log("FAILURE " + (i+1).to_s + " " + x.to_s) }
      end
      @active = false
      return @failures.to_i <= 0
    end

    def self.start_auto_test
      return false if active? || $game_temp.in_battle
      install_skill_scopes
      prepare_test_party
      make_test_troop
      reset_log
      @active = true
      @round_index = 0
      @failures = 0
      @failure_lines = []
      @apply_counts = {}
      @redirect_events = []
      @hit_events = []
      @crit_events = []
      @help_events = []
      @redirectors = {}
      @redirect_seq = 0
      @boot_asserted = false
      log("AUTO_TEST_START troop=" + TEST_TROOP_ID.to_s)
      if defined?(ALBERT_CG) && ALBERT_CG.respond_to?(:start_demo_battle)
        ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
      else
        $game_troop.setup(TEST_TROOP_ID)
        $game_temp.in_battle = true
        $game_temp.battle_troop_id = TEST_TROOP_ID
        $scene = Scene_Battle.new
      end
      return true
    rescue => e
      log("AUTO_TEST_START_ERROR " + e.class.to_s + ":" + e.message.to_s)
      @active = false
      return false
    end
  end
end

#==============================================================================
# ■ Game_Battler：Batch C Volatile / Hit / Critical / Helping Hand
#==============================================================================
class Game_Battler
  def cg_v236_switch_locked?
    return @cg_v236_switch_lock == true
  end

  def cg_v236_clear_volatile
    @cg_v236_switch_lock = false
    @cg_v236_switch_lock_source = nil
    @cg_v236_switch_lock_move = nil
    @cg_v236_hit_lock_target = nil
    @cg_v236_hit_lock_move = nil
    @cg_v236_laser_focus = false
    @cg_v236_helping_hand = false
    @cg_v236_helping_hand_source = nil
    @cg_v236_redirect_kind = nil
    @cg_v236_redirect_seq = nil
  end

  alias cg_v236_remove_states_battle remove_states_battle
  def remove_states_battle
    cg_v236_remove_states_battle
    cg_v236_clear_volatile
  end

  alias cg_v236_skill_effect skill_effect
  def skill_effect(user, skill)
    mid = skill == nil ? 0 : ALBERT_CG::MOVE_EFFECT.move_id(skill)

    # v2.3.6c：Rage Powder 是純自訂 self-volatile。
    # 必須在既有 VX/Tankentai 空效果判定之前落地，否則沒有原生 RPG Effect 的
    # Status Move 可能只播放動畫，卻在下層結果旗標後被提前 return。
    if mid == ALBERT_CG::UNIQUE_C_V236::MOVE_RAGE_POWDER && user == self
      clear_action_results
      ALBERT_CG::UNIQUE_C_V236.mark_apply(mid)
      ALBERT_CG::UNIQUE_C_V236.log("RAGE_POWDER_PREHANDLE user=" + user.name.to_s +
          " hp=" + user.hp.to_i.to_s)
      ALBERT_CG::UNIQUE_C_V236.set_redirect(user, :rage_powder)
      return
    end

    cg_v236_skill_effect(user, skill)
    return if mid <= 0 || !ALBERT_CG::UNIQUE_C_V236.handled?(mid)
    return if @skipped || @missed || @evaded
    ALBERT_CG::UNIQUE_C_V236.mark_apply(mid)
    case mid
    when ALBERT_CG::UNIQUE_C_V236::MOVE_SPIDER_WEB,
         ALBERT_CG::UNIQUE_C_V236::MOVE_MEAN_LOOK,
         ALBERT_CG::UNIQUE_C_V236::MOVE_BLOCK
      ALBERT_CG::UNIQUE_C_V236.set_switch_lock(self, user, mid)
    when ALBERT_CG::UNIQUE_C_V236::MOVE_MIND_READER,
         ALBERT_CG::UNIQUE_C_V236::MOVE_LOCK_ON
      ALBERT_CG::UNIQUE_C_V236.set_hit_lock(user, self, mid)
    when ALBERT_CG::UNIQUE_C_V236::MOVE_LASER_FOCUS
      ALBERT_CG::UNIQUE_C_V236.set_laser_focus(user)
    when ALBERT_CG::UNIQUE_C_V236::MOVE_HELPING_HAND
      ALBERT_CG::UNIQUE_C_V236.set_helping_hand(self, user)
    when ALBERT_CG::UNIQUE_C_V236::MOVE_ACUPRESSURE
      ALBERT_CG::UNIQUE_C_V236.apply_acupressure(self)
    when ALBERT_CG::UNIQUE_C_V236::MOVE_FOLLOW_ME
      ALBERT_CG::UNIQUE_C_V236.set_redirect(user, :follow_me)
    when ALBERT_CG::UNIQUE_C_V236::MOVE_SPOTLIGHT
      ALBERT_CG::UNIQUE_C_V236.set_redirect(self, :spotlight)
    when ALBERT_CG::UNIQUE_C_V236::MOVE_ALLY_SWITCH
      ALBERT_CG::UNIQUE_C_V236.swap_grid(user, self)
    when ALBERT_CG::UNIQUE_C_V236::MOVE_FLOWER_SHIELD
      ALBERT_CG::UNIQUE_C_V236.apply_flower_shield(user)
    end
  end

  alias cg_v236_calc_hit calc_hit
  def calc_hit(user, obj=nil)
    if user != nil && user.instance_variable_get(:@cg_v236_hit_lock_target) == self
      kind = user.instance_variable_get(:@cg_v236_hit_lock_move)
      ALBERT_CG::UNIQUE_C_V236.note_hit_override(user, self, kind)
      return 100
    end
    return cg_v236_calc_hit(user, obj)
  end

  alias cg_v236_calc_eva calc_eva
  def calc_eva(user, obj=nil)
    if user != nil && user.instance_variable_get(:@cg_v236_hit_lock_target) == self
      return 0
    end
    return cg_v236_calc_eva(user, obj)
  end

  alias cg_v236_critical cg_pokemon_critical?
  def cg_pokemon_critical?(user, obj=nil)
    if user != nil && user.instance_variable_get(:@cg_v236_laser_focus) == true
      ALBERT_CG::UNIQUE_C_V236.note_laser_crit(user, self)
      return true
    end
    return cg_v236_critical(user, obj)
  end

  alias cg_v236_attack_damage make_attack_damage_value
  def make_attack_damage_value(attacker)
    cg_v236_attack_damage(attacker)
    if attacker != nil && attacker.instance_variable_get(:@cg_v236_helping_hand) == true && @hp_damage.to_i > 0
      base = @hp_damage.to_i
      @hp_damage = [base * ALBERT_CG::UNIQUE_C_V236::HELPING_HAND_PERCENT / 100, 1].max
      if @cg_last_damage_breakdown.is_a?(Hash)
        @cg_last_damage_breakdown[:damage] = @hp_damage.to_i
        @cg_last_damage_breakdown[:helping_hand] = ALBERT_CG::UNIQUE_C_V236::HELPING_HAND_PERCENT
      end
      ALBERT_CG::UNIQUE_C_V236.note_helping_damage(attacker, self, base, @hp_damage)
    end
  end

  alias cg_v236_obj_damage make_obj_damage_value
  def make_obj_damage_value(user, obj)
    cg_v236_obj_damage(user, obj)
    if user != nil && user.instance_variable_get(:@cg_v236_helping_hand) == true && @hp_damage.to_i > 0
      base = @hp_damage.to_i
      @hp_damage = [base * ALBERT_CG::UNIQUE_C_V236::HELPING_HAND_PERCENT / 100, 1].max
      if @cg_last_damage_breakdown.is_a?(Hash)
        @cg_last_damage_breakdown[:damage] = @hp_damage.to_i
        @cg_last_damage_breakdown[:helping_hand] = ALBERT_CG::UNIQUE_C_V236::HELPING_HAND_PERCENT
      end
      ALBERT_CG::UNIQUE_C_V236.note_helping_damage(user, self, base, @hp_damage)
    end
  end
end

#==============================================================================
# ■ Game_BattleAction：Follow Me / Rage Powder / Spotlight 單體導引
#==============================================================================
class Game_BattleAction
  alias cg_v236_make_targets make_targets
  def make_targets
    targets = cg_v236_make_targets
    if defined?(ALBERT_CG::UNIQUE_C_V236)
      redirect = ALBERT_CG::UNIQUE_C_V236.redirect_target_for(self, targets)
      return [redirect] if redirect != nil
    end
    return targets
  end
end

#==============================================================================
# ■ Game_Party：蛛網／黑色目光／擋路阻止一般主動換寵
#==============================================================================
class Game_Party < Game_Unit
  if method_defined?(:cg_battle_switchable_pet?)
    alias cg_v236_battle_switchable_pet cg_battle_switchable_pet?
    def cg_battle_switchable_pet?(actor_id, owner_actor_or_id=nil)
      owner_id = cg_owner_actor_id_from(owner_actor_or_id) rescue nil
      if owner_id != nil && respond_to?(:cg_repair_active_pet_for_owner!)
        active = cg_repair_active_pet_for_owner!(owner_id)
        if active != nil && active.respond_to?(:cg_v236_switch_locked?) && active.cg_v236_switch_locked?
          return false
        end
      end
      return cg_v236_battle_switchable_pet(actor_id, owner_actor_or_id)
    end
  end
end

#==============================================================================
# ■ Force Switch：真正換出後清除 Batch C Volatile；Trap 本身不擋 Roar/Whirlwind
#==============================================================================
if defined?(ALBERT_CG::FORCE_SWITCH_V235)
  module ALBERT_CG
    module FORCE_SWITCH_V235
      class << self
        alias cg_v236_clear_switch_out_volatile clear_switch_out_volatile
        def clear_switch_out_volatile(battler)
          cg_v236_clear_switch_out_volatile(battler)
          battler.cg_v236_clear_volatile if battler != nil && battler.respond_to?(:cg_v236_clear_volatile)
        end
      end
    end
  end
end

#==============================================================================
# ■ Action Priority Regression：Batch C active 時使用 deterministic SPE
#==============================================================================
class Game_Battler
  alias cg_v236_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    override = @cg_priority_test_speed_override
    if defined?(ALBERT_CG::UNIQUE_C_V236) && ALBERT_CG::UNIQUE_C_V236.active? && override != nil
      return override.to_i
    end
    return cg_v236_priority_base_speed
  end
end

#==============================================================================
# ■ Game_Enemy：Batch C Regression 敵方行動
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v236_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::UNIQUE_C_V236) && ALBERT_CG::UNIQUE_C_V236.active?
      forced = ALBERT_CG::UNIQUE_C_V236.forced_enemy_action(self)
      if forced != nil
        cg_assign_action(forced) if respond_to?(:cg_assign_action)
        @action = forced unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v236_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle：5 回合 deterministic Regression
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v236_execute_action execute_action
  def execute_action
    if defined?(ALBERT_CG::UNIQUE_C_V236) && ALBERT_CG::UNIQUE_C_V236.active?
      ALBERT_CG::UNIQUE_C_V236.record_execution(@active_battler)
      saved_action = @active_battler == nil ? nil : @active_battler.action
      cg_v236_execute_action
      ALBERT_CG::UNIQUE_C_V236.after_action_cleanup(@active_battler, saved_action)
      return
    end
    cg_v236_execute_action
  end

  alias cg_v236_turn_end turn_end
  def turn_end
    ALBERT_CG::UNIQUE_C_V236.finish_round_assertions if
      defined?(ALBERT_CG::UNIQUE_C_V236) && ALBERT_CG::UNIQUE_C_V236.active?
    cg_v236_turn_end
  end

  alias cg_v236_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::UNIQUE_C_V236) && ALBERT_CG::UNIQUE_C_V236.active?
      return cg_v236_start_party_command
    end
    cg_v236_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::UNIQUE_C_V236.assert_bootstrap_once
    if ALBERT_CG::UNIQUE_C_V236.finished?
      ALBERT_CG::UNIQUE_C_V236.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::UNIQUE_C_V236.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle 重建 Party 後重套 Batch C 測試資料與 Grid
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v236_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v236_bootstrap_demo_party
      if defined?(ALBERT_CG::UNIQUE_C_V236) && ALBERT_CG::UNIQUE_C_V236.active?
        ALBERT_CG::UNIQUE_C_V236::TEST_ALLIES.each do |cfg|
          ALBERT_CG::UNIQUE_C_V236.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::UNIQUE_C_V236::TEST_LEVEL, false)
          human.recover_all if human.respond_to?(:recover_all)
        end
        ALBERT_CG::UNIQUE_C_V236.install_skill_scopes
      end
      return result
    end
  end
end

#==============================================================================
# ■ Scene_Title：Move Stub 建立後校正 Unique C Scope
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_v236_load_database load_database
  def load_database
    cg_v236_load_database
    ALBERT_CG::UNIQUE_C_V236.install_skill_scopes
  end

  alias cg_v236_load_bt_database load_bt_database
  def load_bt_database
    cg_v236_load_bt_database
    ALBERT_CG::UNIQUE_C_V236.install_skill_scopes
  end
end

#==============================================================================
# ■ F11：v2.3.6c 成為唯一最新版 AutoRegression
#==============================================================================
if defined?(ALBERT_CG::FORCE_SWITCH_V235)
  module ALBERT_CG
    module FORCE_SWITCH_V235
      def self.f11_trigger?
        return false
      end
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v236_scene_map_update update
  def update
    cg_v236_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::UNIQUE_C_V236.f11_trigger?
      Sound.play_decision
      ALBERT_CG::UNIQUE_C_V236.start_auto_test
    end
  end
end

#==============================================================================
# ■ Coverage：13 個 Unique Pending 轉為 V236_UNIQUE_C_HANDLED
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    class << self
      alias cg_v236_coverage_v231 coverage_v231
    end
    def self.coverage_v231(move_id)
      return "V236_UNIQUE_C_HANDLED" if ALBERT_CG::UNIQUE_C_V236.handled?(move_id)
      return cg_v236_coverage_v231(move_id)
    end
  end
end
