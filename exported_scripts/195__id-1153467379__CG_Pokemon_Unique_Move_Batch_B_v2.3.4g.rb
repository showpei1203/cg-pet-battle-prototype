# RMVX_SCRIPT_INDEX: 195
# RMVX_SCRIPT_ID: 1153467379
# RMVX_SCRIPT_NAME: CG Pokemon Unique Move Batch B v2.3.4g
# RMVX_SOURCE_SHA256: 6d6f67fff4fa459ca9356cb0bd3350864f998673a0ee47230541087722253d19

#==============================================================================
# ■ CG Pokemon Unique Move Batch B v2.3.4g
#------------------------------------------------------------------------------
# 【用途】
#  接續 v2.3.3a Field Move Core，正式完成第二批需要「跨行動／跨回合記憶」的
#  Pokémon Unique Move。這一頁同時建立後續 Gamebit AI、換寵與完整生命週期測試
#  都會共用的 Battle Memory 層，避免每一招各自保存一套互相打架的暫存資料。
#
# 【本版正式完成的 11 招】
#  1. Substitute 替身（164）
#     - 消耗使用者 1/4 MaxHP，建立等量替身 HP。
#     - 對手直接傷害先由替身承受；替身存在時阻擋對手的狀態招式。
#     - 被替身吸收的傷害段不再套用該次攻擊的追加異常／能力下降。
#  2. Destiny Bond 同命（194）
#     - 使用後生效，直到使用者下一次行動開始前。
#     - 若期間被敵方「直接傷害」擊倒，造成致死傷害的攻擊者一併倒下。
#  3. Sleep Talk 夢話（214）
#     - 僅在睡眠時可用；從目前已知招式中抽取可呼叫招式並真正執行。
#     - 測試場可指定 deterministic called move；正式遊戲仍採隨機。
#  4. Metronome 揮指（118）
#     - 從 937 Move Catalog 的可呼叫集合隨機抽取並真正執行。
#     - 排除會造成遞迴／複製循環的呼叫控制招，以及尚未完成的 Force Switch 類。
#  5. Copycat 仿效（383）
#     - 呼叫全場最近一次真正執行的可複製 Pokémon Move。
#  6. Mimic 模仿（102）
#     - 複製目標最近一次真正執行的可複製 Move，直到換寵／戰鬥結束。
#     - Actor 技能欄中的「模仿」會暫時顯示並使用被複製招式，不永久改寫技能欄。
#  7. Disable 定身法（50）
#     - 封鎖目標最近使用的 Move 4 個完整後續回合。
#  8. Encore 再來一次（227）
#     - 鎖定目標最近使用的 Move 3 個完整後續回合。
#     - 不只 UI 反灰；執行層也會把其他行動改回被鎖定 Move，敵方 AI 同樣適用。
#  9. Taunt 挑釁（269）
#     - 3 個完整後續回合內不能使用 Status 類 Pokémon Move。
# 10. Wish 祈願（273）
#     - 記住施放位置；下一個回合結束時，該位置目前的友方回復施放者 MaxHP 的 1/2。
#     - 因此換寵後可由同位置的新成員接到祈願。
# 11. Future Sight 預知未來（248）
#     - 使用當下不造成傷害；記住敵方位置與施放者。
#     - 兩個完整回合後的回合末，對該位置目前成員套用真正的 Future Sight 傷害判定。
#
# 【Battle Memory 規則】
#  - 每位 Battler 記錄 last_move_id；全場另記 last_global_move_id。
#  - 只有實際進入執行層的 Pokémon Move 才會成為「最後招式」。
#  - 揮指／夢話／仿效成功呼叫後，記錄的是「真正被呼叫的 Move」。
#  - 換寵會清除 Substitute / Destiny Bond / Mimic / Disable / Encore / Taunt 等
#    個體型暫時效果；Wish / Future Sight 則綁定戰場位置，會保留。
#
# 【可調參數】
#  SUBSTITUTE_HP_DIVISOR = 4       替身 HP / HP 消耗分母。
#  DISABLE_TURNS         = 4       定身法完整後續回合數。
#  ENCORE_TURNS          = 3       再來一次完整後續回合數。
#  TAUNT_TURNS           = 3       挑釁完整後續回合數。
#  WISH_DELAY_ENDS       = 2       使用回合末 + 下一回合末後結算祈願。
#  FUTURE_SIGHT_ENDS     = 3       使用回合末起計，第三次 turn_end 結算。
#  CALL_BLACKLIST        = [...]   夢話／揮指／仿效／模仿共用禁止遞迴集合。
#
# 【腳本呼叫】
#  ALBERT_CG::UNIQUE_B_V234.start_auto_test
#    直接啟動 deterministic Unique Batch B Scene_Battle 回歸測試；等同地圖按 F11。
#
#  battler.cg_v234_last_move_id
#    查詢該 Battler 最近真正執行的 Pokémon Move ID。
#
#  ALBERT_CG::UNIQUE_B_V234.last_global_move_id
#    查詢全場最近真正執行的 Pokémon Move ID。
#
# 【Debug / AutoRegression】
#  F11：啟動「目前最新版」v2.3.4g Unique Batch B AutoRegression。
#  - 從 v2.3.4f 起，F11 固定作為最新版 AutoRegression 的唯一實機快捷鍵。
#  - 舊版 F11 / Shift+F11 / Ctrl+F11 / Alt+F11 快捷鍵會被本頁停用；
#    舊測試器本體仍保留，可用其模組 start 方法由事件／腳本直接呼叫。
#  - 真正 Scene_Battle。
#  - 4 回合 deterministic action plan。
#  - Unique B 專用 SPE override：只有測試 active 時才覆蓋有效 SPE，
#    正式遊戲完全不受影響；確保同回合記憶招式的先後順序可重現。
#  - v2.3.4f 再補 deterministic 命中規則：測試 active 時 Evasion 固定為 0，
#    避免 Destiny Bond 的致死攻擊被 VX 原生閃避亂數破壞。
#  - v2.3.4f 正式加入 Tankentai SBS damage_action Destiny Bond Bridge：
#    Tankentai 的普通攻擊真正傷害入口位於 Scene_Battle#damage_action，而不是 VX 原生
#    execute_action_attack 單一路徑。本橋接會在 damage_action 前快照實際攻擊目標、HP 與
#    Destiny Bond 狀態，原傷害處理完成後再判定「由存活變為倒下」，讓致死攻擊者一併倒下。
#  - 既有 execute_damage / attack_effect 判定仍保留作為技能與非標準流程相容層；
#    damage_action Bridge 以攻擊者仍存活、同命仍有效作去重，不會同一擊重複觸發。
#  - Regression 新增 TANKENTAI_ATTACK_TARGET / TANKENTAI_DESTINY_DAMAGE_CHECK 診斷，
#    可直接確認 SBS 此次普通攻擊真正採用的目標與傷害前後 HP，不再從演出結果反推。
#  - v2.3.4g 修正 AutoRegression 的「目標合法性前提」：Tom 預設為後排近戰，
#    v2.3.4f 測試 troop 又把同命怪力 E3 放在後排，因此 Battlefield Grid 會正確
#    阻止 Tom 穿過存活前排直接打 E3，並 fallback 到第一個合法前排目標卡比獸。
#    本版不繞過 Grid，而是把 E3 怪力移到前排、E0 卡比獸移到後排，保留 enemy index
#    與所有 Round Plan 不變，讓 Round1 Tom 的 target_index=3 在正式規則下真正合法。
#    Bootstrap 另 ASSERT Tom=back / 怪力=front，避免未來測試編成改動又產生假 FAIL。
#  - Round3 不再用與本批 Unique 驗證無關的地震擊倒皮卡丘，改用弱撞擊攻擊 Tom；
#    讓皮卡丘活到 Round4，再驗證 Encore 連續兩回合都真正強制十萬伏特。
#  - 強制指定 Metronome / Sleep Talk 的 called move，避免亂數讓測試失去意義。
#  - Substitute 改在 Round1 完成「建立→兩次承傷→破裂」；如此 Round2 Encore
#    可獨立驗證，不再被仍存活的 Substitute 正確阻擋而造成假失敗。
#  - Mimic 複製 Encore 後，Round3 對敵方使用 Encore 所造成的後續 AI 強制行動
#    也正式列入 Round3 / Round4 expected execution token。
#  - Encore 的 Priority 排序也正式改用「被鎖定 Move」本身的 Priority，避免
#    先選高優先度招式、執行時被 Encore 換招卻偷吃原招優先度。
#  - 對「被 Disable / Taunt 正確阻止而未進 execute_action」的行動以 BLOCK ASSERT
#    驗證，不錯誤要求每回合固定 8 次 execute_action。
#  - 每回合 ASSERT 執行序列、11 招 apply、Substitute、Destiny Bond、Wish、
#    Future Sight、Encore、Disable、Taunt、Mimic、Copycat 與 Sleep Talk。
#  - LOG：Pokemon_UniqueB_AutoTest_v2_3_4g.log
#  - v2.3.4f 將 AutoRegression LOG 路徑固定到 Game.exe 所在的專案根目錄，
#    不再依賴啟動時的 current working directory。
#  - 同步輸出 CG_AutoRegression_LATEST.log，之後測試只需要找這一個固定檔名。
#  - RESULT / SUMMARY / Destiny Bond 關鍵診斷亦鏡像追加到 PMD_BattleInitTrace.log；
#    即使版本 LOG 因 Windows 路徑／權限問題沒有出現，PMD Trace 仍能直接判讀結果。
#  - 所有 File I/O 失敗不再完全靜默：會嘗試在 PMD Trace 留下 AUTOTEST_LOG_ERROR。
#
# 【事件／實際使用範例】
#  地圖快捷鍵：F11
#  事件腳本：ALBERT_CG::UNIQUE_B_V234.start_auto_test
#  完成時應得到：
#    RESULT=PASS
#    SUMMARY rounds=4 failures=0 unique_moves=11/11
#
# 【相容性】
#  RPG Maker VX / RGSS2 / Tankentai SBS + PMD Native。
#  本頁必須放在 v2.3.3a Field Move Core 之後；不依賴外部 .rb 執行。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonUniqueMoveBatchB"] = "2.3.4g"

module ALBERT_CG
  module UNIQUE_B_V234
    VERSION = "2.3.4g"
    LOG_FILE = "Pokemon_UniqueB_AutoTest_v2_3_4g.log"
    LATEST_LOG_FILE = "CG_AutoRegression_LATEST.log"
    TRACE_LOG_FILE = "PMD_BattleInitTrace.log"

    begin
      GET_MODULE_FILENAME_API = Win32API.new("kernel32", "GetModuleFileNameA", "lpl", "l")
    rescue
      GET_MODULE_FILENAME_API = nil
    end

    MOVE_DISABLE       = 50
    MOVE_MIMIC         = 102
    MOVE_METRONOME     = 118
    MOVE_SUBSTITUTE    = 164
    MOVE_DESTINY_BOND  = 194
    MOVE_SLEEP_TALK    = 214
    MOVE_ENCORE        = 227
    MOVE_FUTURE_SIGHT  = 248
    MOVE_TAUNT         = 269
    MOVE_WISH          = 273
    MOVE_COPYCAT       = 383

    HANDLED_MOVE_IDS = [
      MOVE_DISABLE, MOVE_MIMIC, MOVE_METRONOME, MOVE_SUBSTITUTE,
      MOVE_DESTINY_BOND, MOVE_SLEEP_TALK, MOVE_ENCORE, MOVE_FUTURE_SIGHT,
      MOVE_TAUNT, MOVE_WISH, MOVE_COPYCAT
    ]

    SUBSTITUTE_HP_DIVISOR = 4
    DISABLE_TURNS = 4
    ENCORE_TURNS = 3
    TAUNT_TURNS = 3
    WISH_DELAY_ENDS = 2
    FUTURE_SIGHT_ENDS = 3

    STATE_ENCORE       = 58
    STATE_TAUNT        = 59
    STATE_SUBSTITUTE   = 60
    STATE_DESTINY_BOND = 61

    # 會呼叫其他 Move 的控制招式不可互相無限遞迴。
    # 165 Struggle、166 Sketch、274 Assist 等也不應成為本階段的動態呼叫來源。
    CALL_BLACKLIST = [102, 118, 165, 166, 214, 274, 383]

    TEST_TROOP_ID = 695
    TEST_LEVEL = 35

    TEST_ALLIES = [
      {:dex=>25, :level=>35, :ability=>9,   :moves=>[164,214,85,98]},
      {:dex=>3,  :level=>35, :ability=>65,  :moves=>[273,383,14,33]},
      {:dex=>94, :level=>35, :ability=>130, :moves=>[248,102,247,109]},
    ]
    TEST_ENEMIES = [
      {:dex=>143, :level=>35, :ability=>47, :moves=>[118,227,89,34]},
      {:dex=>94,  :level=>35, :ability=>130,:moves=>[269,247,109,94]},
      {:dex=>376, :level=>35, :ability=>29, :moves=>[14,89,232,33]},
      {:dex=>68,  :level=>35, :ability=>62, :moves=>[194,50,2,69]},
    ]

    # 0=Tom, 1=皮卡丘, 2=妙蛙花, 3=耿鬼
    ROUND_PLANS = [
      {
        :name=>"SETUP_SUB_WISH_FUTURE_METRONOME_DESTINY",
        :allies=>[
          {:kind=>:attack, :target=>3},
          {:kind=>:move, :move_id=>164, :target=>1},
          {:kind=>:move, :move_id=>273, :target=>2},
          {:kind=>:move, :move_id=>248, :target=>3},
        ],
        :enemies=>[
          {:kind=>:move, :move_id=>118, :target=>0, :called_move_id=>14},
          {:kind=>:move, :move_id=>33, :target=>1},
          {:kind=>:move, :move_id=>33, :target=>1},
          {:kind=>:move, :move_id=>194, :target=>3},
        ]
      },
      {
        :name=>"MEMORY_SLEEP_ENCORE_MIMIC_COPYCAT_TAUNT_DISABLE",
        :allies=>[
          {:kind=>:attack, :target=>1},
          {:kind=>:move, :move_id=>214, :target=>0, :called_move_id=>85},
          {:kind=>:move, :move_id=>383, :target=>2},
          {:kind=>:move, :move_id=>102, :target=>0},
        ],
        :enemies=>[
          {:kind=>:move, :move_id=>227, :target=>1},
          {:kind=>:move, :move_id=>269, :target=>2},
          {:kind=>:move, :move_id=>14, :target=>2},
          {:kind=>:move, :move_id=>50, :target=>2},
        ]
      },
      {
        :name=>"ENFORCEMENT_AND_DELAYED_HIT",
        :allies=>[
          {:kind=>:attack, :target=>1},
          {:kind=>:move, :move_id=>98, :target=>0},
          {:kind=>:move, :move_id=>14, :target=>2},
          {:kind=>:move, :move_id=>102, :target=>1},
        ],
        :enemies=>[
          {:kind=>:move, :move_id=>33, :target=>0},
          {:kind=>:move, :move_id=>247, :target=>0},
          {:kind=>:move, :move_id=>14, :target=>2},
          {:kind=>:move, :move_id=>2, :target=>0},
        ]
      },
      {
        :name=>"PERSISTENCE_AND_CLEAN_FINISH",
        :allies=>[
          {:kind=>:attack, :target=>0},
          {:kind=>:move, :move_id=>98, :target=>0},
          {:kind=>:move, :move_id=>14, :target=>0},
          {:kind=>:move, :move_id=>247, :target=>0},
        ],
        :enemies=>[
          {:kind=>:move, :move_id=>34, :target=>1},
          {:kind=>:move, :move_id=>94, :target=>0},
          {:kind=>:move, :move_id=>232, :target=>0},
          {:kind=>:move, :move_id=>69, :target=>0},
        ]
      }
    ]

    TEST_SPEEDS = {
      :r1=>[30,120,110,100, 90,70,60,80],
      :r2=>[20,120,80,100, 110,60,90,50],
      :r3=>[20,120,80,100, 110,60,90,50],
      :r4=>[90,100,80,70, 60,50,40,30],
    }

    # Disable / Taunt 正確阻擋時，被阻擋者不會進 Scene_Battle#execute_action。
    # 因此 Round3 / Round4 正式預期為 7 個「實際執行」行動，而不是硬湊 8 個。
    EXPECTED_EXECUTION_COUNTS = {1=>8, 2=>8, 3=>7, 4=>7}

    # 這些 token 驗證真正的 Priority -> SPE -> Stable Sequence 結果，也同時證明
    # Metronome / Sleep Talk / Copycat / Mimic slot 已在執行前被轉成正確 Move。
    EXPECTED_EXECUTION_TOKENS = {
      1=>["A1:M164","A2:M273","A3:M248","E0:M14","E3:M194","E1:M33","E2:M33","A0:Attack"],
      2=>["A1:M85","E0:M227","A3:M102","E2:M14","A2:M14","E1:M269","E3:M50","A0:Attack"],
      3=>["A1:M85","E0:M33","A3:M227","E2:M14","E1:M269","E3:M2","A0:Attack"],
      4=>["A1:M85","A0:Attack","A3:M247","E0:M34","E1:M269","E2:M232","E3:M69"],
    }

    begin
      VK_F11  = 0x7A
      KEY_API = Win32API.new("user32", "GetAsyncKeyState", "i", "i")
    rescue
      KEY_API = nil
    end

    def self.master
      return nil unless defined?(ALBERT_CG::POKEMON_MASTER)
      return ALBERT_CG::POKEMON_MASTER
    end

    def self.project_root
      begin
        if GET_MODULE_FILENAME_API != nil
          buf = "\0" * 1024
          len = GET_MODULE_FILENAME_API.call(0, buf, 1023)
          if len.to_i > 0
            exe = buf[0, len.to_i]
            return File.dirname(exe)
          end
        end
      rescue
      end
      begin
        return Dir.pwd
      rescue
        return "."
      end
    end

    def self.log_path(name)
      begin
        return File.join(project_root, name.to_s)
      rescue
        return name.to_s
      end
    end

    def self.version_log_path
      return log_path(LOG_FILE)
    end

    def self.latest_log_path
      return log_path(LATEST_LOG_FILE)
    end

    def self.trace_log_path
      return log_path(TRACE_LOG_FILE)
    end

    def self.append_raw(path, text)
      File.open(path, "ab") { |f| f.write(text.to_s + "\r\n") }
      return true
    rescue
      return false
    end

    def self.trace_mirror(text)
      line = text.to_s
      important = line.index("AUTO_TEST_START") == 0 ||
                  line.index("AUTOTEST_LOG_PATH") == 0 ||
                  line.index("TANKENTAI_") == 0 ||
                  line.index("DESTINY_BOND_KO") == 0 ||
                  line.index("ASSERT PASS Destiny Bond") == 0 ||
                  line.index("ASSERT FAIL Destiny Bond") == 0 ||
                  line.index("RESULT=") == 0 ||
                  line.index("SUMMARY ") == 0 ||
                  line.index("FAILURE ") == 0
      return false unless important
      return append_raw(trace_log_path, "[UNIQUE_B_AUTOTEST] " + line)
    rescue
      return false
    end

    def self.log(text)
      line = text.to_s
      ok1 = append_raw(version_log_path, line)
      ok2 = append_raw(latest_log_path, line)
      trace_mirror(line)
      if !ok1 || !ok2
        append_raw(trace_log_path, "[UNIQUE_B_AUTOTEST] AUTOTEST_LOG_ERROR version=" +
                   ok1.to_s + " latest=" + ok2.to_s + " root=" + project_root.to_s)
      end
    rescue
    end

    def self.reset_one_log(path)
      File.open(path, "wb") do |f|
        f.write("CG POKEMON UNIQUE MOVE B AUTO REGRESSION v" + VERSION + "\r\n")
        f.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
        f.write("RULE=Actual Scene_Battle; deterministic called moves; 11 Unique Moves\r\n")
        f.write("AUTOTEST_LOG_PATH=" + version_log_path.to_s + "\r\n")
        f.write("AUTOTEST_LATEST_PATH=" + latest_log_path.to_s + "\r\n")
        f.write("------------------------------------------------------------\r\n")
      end
      return true
    rescue
      return false
    end

    def self.reset_log
      ok1 = reset_one_log(version_log_path)
      ok2 = reset_one_log(latest_log_path)
      append_raw(trace_log_path, "[UNIQUE_B_AUTOTEST] AUTOTEST_LOG_PATH=" + version_log_path.to_s)
      append_raw(trace_log_path, "[UNIQUE_B_AUTOTEST] AUTOTEST_LATEST_PATH=" + latest_log_path.to_s)
      if !ok1 || !ok2
        append_raw(trace_log_path, "[UNIQUE_B_AUTOTEST] AUTOTEST_LOG_ERROR reset version=" +
                   ok1.to_s + " latest=" + ok2.to_s + " root=" + project_root.to_s)
      end
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
    rescue
      return false
    end

    def self.handled?(move_id)
      return HANDLED_MOVE_IDS.include?(move_id.to_i)
    end

    def self.move_status?(move_id)
      row = master == nil ? nil : master.move(move_id.to_i)
      return row != nil && row[7] == :status
    rescue
      return false
    end

    def self.callable_move?(move_id)
      mid = move_id.to_i
      return false if mid <= 0 || CALL_BLACKLIST.include?(mid)
      return false if master == nil || master.move(mid) == nil
      # Force Switch 會在下一版與 Hazard 一起正式完成；本版先排除動態呼叫。
      return false if ALBERT_CG::MOVE_EFFECT.meta_category(mid) == 12
      return true
    rescue
      return false
    end

    def self.callable_pool
      return [] if master == nil
      result = []
      master::MOVE_CATALOG.keys.each do |mid|
        result.push(mid) if callable_move?(mid)
      end
      return result
    end

    def self.last_global_move_id
      return @last_global_move_id.to_i
    end

    def self.record_global_move(battler, move_id)
      mid = move_id.to_i
      return if mid <= 0
      @last_global_move_id = mid
      battler.cg_v234_set_last_move_id(mid) if battler != nil &&
        battler.respond_to?(:cg_v234_set_last_move_id)
      log("LAST_MOVE battler=" + (battler == nil ? "nil" : battler.name.to_s) +
          " move=" + mid.to_s + ":" + (master == nil ? "" : master.move_name(mid).to_s))
    end

    def self.reset_battle_memory
      @last_global_move_id = 0
      @wish_queue = []
      @future_queue = []
      @resolving_future_sight = false
      @apply_counts = {}
      @blocked_events = {}
      @substitute_create_events = {}
      @substitute_absorb_events = {}
      @substitute_absorb_counts = {}
      @destiny_ko_events = {}
      @future_schedule_events = {}
    end

    def self.apply_counts
      @apply_counts = {} if @apply_counts == nil
      return @apply_counts
    end

    def self.mark_apply(move_id)
      mid = move_id.to_i
      apply_counts[mid] = apply_counts[mid].to_i + 1
      log("APPLY move=" + mid.to_s + ":" + (master == nil ? "" : master.move_name(mid).to_s) +
          " count=" + apply_counts[mid].to_s)
    end

    def self.battler_token(battler)
      return "nil" if battler == nil
      return (battler.actor? ? "A" : "E") + battler.index.to_i.to_s
    rescue
      return "?"
    end

    def self.note_block(battler, move_id, reason)
      return unless active? && battler != nil
      @blocked_events = {} if @blocked_events == nil
      key = [current_round, battler_token(battler), move_id.to_i, reason.to_sym]
      unless @blocked_events[key]
        @blocked_events[key] = true
        log("BLOCK round=" + current_round.to_s + " battler=" + battler_token(battler) +
            ":" + battler.name.to_s + " move=" + move_id.to_i.to_s +
            " reason=" + reason.to_s)
      end
    end

    def self.blocked?(round, battler_token_value, move_id, reason)
      return false if @blocked_events == nil
      return @blocked_events[[round.to_i, battler_token_value.to_s, move_id.to_i, reason.to_sym]] == true
    end

    def self.note_substitute_create(battler, shield)
      return unless active? && battler != nil
      @substitute_create_events = {} if @substitute_create_events == nil
      @substitute_create_events[[current_round, battler_token(battler)]] = shield.to_i
      log("TEST_EVENT SUBSTITUTE_CREATE round=" + current_round.to_s +
          " battler=" + battler_token(battler) + " shield=" + shield.to_i.to_s)
    end

    def self.substitute_created?(round, battler_token_value)
      return false if @substitute_create_events == nil
      return @substitute_create_events[[round.to_i, battler_token_value.to_s]].to_i > 0
    end

    def self.note_substitute_absorb(battler, incoming, absorbed, shield_left, hp_before, hp_after)
      return unless active? && battler != nil
      @substitute_absorb_events = {} if @substitute_absorb_events == nil
      key = [current_round, battler_token(battler)]
      @substitute_absorb_events[key] = {
        :incoming=>incoming.to_i, :absorbed=>absorbed.to_i, :shield_left=>shield_left.to_i,
        :hp_before=>hp_before.to_i, :hp_after=>hp_after.to_i
      }
      @substitute_absorb_counts = {} if @substitute_absorb_counts == nil
      @substitute_absorb_counts[key] = @substitute_absorb_counts[key].to_i + 1
      log("TEST_EVENT SUBSTITUTE_ABSORB round=" + current_round.to_s +
          " battler=" + battler_token(battler) + " hp_before=" + hp_before.to_i.to_s +
          " hp_after=" + hp_after.to_i.to_s + " shield_left=" + shield_left.to_i.to_s)
    end

    def self.substitute_absorb_event(round, battler_token_value)
      return nil if @substitute_absorb_events == nil
      return @substitute_absorb_events[[round.to_i, battler_token_value.to_s]]
    end

    def self.substitute_absorb_count(round, battler_token_value)
      return 0 if @substitute_absorb_counts == nil
      return @substitute_absorb_counts[[round.to_i, battler_token_value.to_s]].to_i
    end

    def self.note_destiny_ko(target, attacker)
      return unless active?
      @destiny_ko_events = {} if @destiny_ko_events == nil
      @destiny_ko_events[current_round] = [battler_token(target), battler_token(attacker)]
      log("TEST_EVENT DESTINY_BOND_KO round=" + current_round.to_s +
          " target=" + battler_token(target) + " attacker=" + battler_token(attacker))
    end

    def self.destiny_ko?(round, target_token, attacker_token)
      return false if @destiny_ko_events == nil
      return @destiny_ko_events[round.to_i] == [target_token.to_s, attacker_token.to_s]
    end

    def self.note_future_schedule(user, target, hp_before, hp_after)
      return unless active?
      @future_schedule_events = {} if @future_schedule_events == nil
      @future_schedule_events[current_round] = {
        :user=>battler_token(user), :target=>battler_token(target),
        :hp_before=>hp_before.to_i, :hp_after=>hp_after.to_i
      }
      log("TEST_EVENT FUTURE_SIGHT_SCHEDULE round=" + current_round.to_s +
          " source=" + battler_token(user) + " target=" + battler_token(target) +
          " hp_before=" + hp_before.to_i.to_s + " hp_after=" + hp_after.to_i.to_s)
    end

    def self.future_schedule_no_immediate_damage?(round)
      return false if @future_schedule_events == nil
      event = @future_schedule_events[round.to_i]
      return event != nil && event[:hp_before].to_i == event[:hp_after].to_i
    end

    def self.position_of(battler)
      side = battler != nil && battler.actor? ? :ally : :enemy
      result = {:side=>side, :index=>(battler == nil ? -1 : battler.index.to_i)}
      if battler != nil && battler.respond_to?(:cg_battle_slot_assigned?) &&
         battler.cg_battle_slot_assigned?
        result[:row] = battler.cg_battle_row
        result[:column] = battler.cg_battle_column
      end
      return result
    end

    def self.battler_at_position(entry)
      return nil if entry == nil
      unit = entry[:side] == :ally ? $game_party : $game_troop
      return nil if unit == nil
      if entry[:row] != nil && entry[:column] != nil
        unit.members.each do |b|
          next if b == nil || !b.respond_to?(:cg_battle_slot_assigned?) || !b.cg_battle_slot_assigned?
          return b if b.cg_battle_row == entry[:row] && b.cg_battle_column.to_i == entry[:column].to_i
        end
      end
      return unit.members[entry[:index].to_i]
    rescue
      return nil
    end

    def self.schedule_wish(user)
      pos = position_of(user)
      amount = [[user.maxhp.to_i / 2, 1].max, user.maxhp.to_i].min
      @wish_queue = [] if @wish_queue == nil
      entry = pos.clone
      entry[:amount] = amount
      entry[:remaining] = WISH_DELAY_ENDS
      entry[:source] = user.name.to_s
      @wish_queue.push(entry)
      log("WISH_SCHEDULE source=" + user.name.to_s + " side=" + pos[:side].to_s +
          " index=" + pos[:index].to_s + " row=" + pos[:row].to_s +
          " column=" + pos[:column].to_s + " amount=" + amount.to_s)
    end

    def self.schedule_future_sight(user, target)
      pos = position_of(target)
      @future_queue = [] if @future_queue == nil
      entry = pos.clone
      entry[:remaining] = FUTURE_SIGHT_ENDS
      entry[:user] = user
      @future_queue.push(entry)
      log("FUTURE_SIGHT_SCHEDULE source=" + user.name.to_s + " side=" + pos[:side].to_s +
          " index=" + pos[:index].to_s + " row=" + pos[:row].to_s +
          " column=" + pos[:column].to_s)
    end

    def self.tick_delayed_events
      if @wish_queue != nil
        @wish_queue.clone.each do |entry|
          entry[:remaining] = entry[:remaining].to_i - 1
          next if entry[:remaining] > 0
          target = battler_at_position(entry)
          if target != nil && target.hp.to_i > 0
            gain = [entry[:amount].to_i, target.maxhp.to_i - target.hp.to_i].min
            if gain > 0
              target.hp += gain
              target.hp_damage = -gain if target.respond_to?(:hp_damage=)
            end
            log("WISH_RESOLVE target=" + target.name.to_s + " heal=" + gain.to_i.to_s)
          else
            log("WISH_RESOLVE target=nil heal=0")
          end
          @wish_queue.delete(entry)
        end
      end

      if @future_queue != nil
        @future_queue.clone.each do |entry|
          entry[:remaining] = entry[:remaining].to_i - 1
          next if entry[:remaining] > 0
          target = battler_at_position(entry)
          user = entry[:user]
          if target != nil && target.hp.to_i > 0 && user != nil
            skill = master == nil ? nil : $data_skills[master.skill_id_for_move(MOVE_FUTURE_SIGHT)]
            if skill != nil
              hp_before = target.hp.to_i
              @resolving_future_sight = true
              begin
                target.skill_effect(user, skill)
              ensure
                @resolving_future_sight = false
              end
              log("FUTURE_SIGHT_RESOLVE source=" + user.name.to_s +
                  " target=" + target.name.to_s + " damage=" +
                  [hp_before - target.hp.to_i, 0].max.to_s)
            end
          else
            log("FUTURE_SIGHT_RESOLVE target=nil damage=0")
          end
          @future_queue.delete(entry)
        end
      end
    end

    def self.resolving_future_sight?
      return @resolving_future_sight == true
    end

    def self.choose_called_move(battler, parent_mid)
      forced = battler.instance_variable_get(:@cg_v234_forced_called_move_id)
      battler.instance_variable_set(:@cg_v234_forced_called_move_id, nil)
      if forced != nil && callable_move?(forced.to_i)
        return forced.to_i
      end

      case parent_mid.to_i
      when MOVE_SLEEP_TALK
        return 0 unless battler.state?(ALBERT_CG::MOVE_EFFECT::STATE_SLEEP)
        pool = battler.cg_v234_known_move_ids.select { |mid| callable_move?(mid) && mid.to_i != MOVE_SLEEP_TALK }
        return pool.empty? ? 0 : pool[rand(pool.size)].to_i
      when MOVE_METRONOME
        pool = callable_pool
        return pool.empty? ? 0 : pool[rand(pool.size)].to_i
      when MOVE_COPYCAT
        mid = last_global_move_id
        return callable_move?(mid) ? mid : 0
      end
      return 0
    rescue
      return 0
    end

    def self.replace_action_with_move(battler, move_id, parent_mid = nil)
      return false if battler == nil || master == nil
      sid = master.skill_id_for_move(move_id.to_i)
      skill = $data_skills[sid]
      return false if sid <= 0 || skill == nil
      old = battler.action
      target_index = old == nil ? 0 : old.target_index.to_i
      action = Game_BattleAction.new(battler)
      action.set_skill(sid)
      action.target_index = target_index
      battler.cg_assign_action(action) if battler.respond_to?(:cg_assign_action)
      battler.instance_variable_set(:@action, action) unless battler.respond_to?(:cg_assign_action)
      if parent_mid != nil
        battler.instance_variable_set(:@cg_v234_call_parent_mid, parent_mid.to_i)
        battler.instance_variable_set(:@cg_v234_call_skill_id, sid.to_i)
      end
      return true
    rescue => e
      log("REPLACE_ACTION_ERROR " + e.class.to_s + ":" + e.message.to_s)
      return false
    end

    def self.prepare_runtime_action(battler)
      return if battler == nil || battler.action == nil

      # Destiny Bond 只維持到自己下一次行動開始前。
      current_mid = battler.action.skill? ? ALBERT_CG::MOVE_EFFECT.move_id(battler.action.skill) : 0
      if battler.cg_v234_destiny_bond? && current_mid != MOVE_DESTINY_BOND
        battler.cg_v234_clear_destiny_bond
        log("DESTINY_BOND_EXPIRE_ON_ACTION battler=" + battler.name.to_s)
      end

      # Encore 為執行層規則。即使 UI / AI 選了其他行動，也在真正執行前鎖回指定 Move。
      if battler.cg_v234_encore_active?
        encore_mid = battler.cg_v234_encore_move_id
        if encore_mid > 0 && (current_mid != encore_mid || !battler.action.skill?)
          replace_action_with_move(battler, encore_mid, nil)
          current_mid = encore_mid
          log("ENCORE_FORCE battler=" + battler.name.to_s + " move=" + encore_mid.to_s)
        end
      end

      return unless battler.action.skill?
      current_mid = ALBERT_CG::MOVE_EFFECT.move_id(battler.action.skill)

      # 先尊重原始選擇 Move 的 Disable / Taunt，再做 Metronome / Copycat / Mimic 轉換。
      # 否則「先轉成別招」會把本來應被封鎖的控制招偷偷繞過限制。
      if battler.cg_v234_disabled_move_id > 0 && current_mid == battler.cg_v234_disabled_move_id
        return
      end
      if battler.cg_v234_taunt_active? && move_status?(current_mid)
        return
      end

      # Mimic 成功後，原 Mimic slot 在本場戰鬥中視為被複製 Move。
      if current_mid == MOVE_MIMIC && battler.cg_v234_mimic_move_id > 0
        copied = battler.cg_v234_mimic_move_id
        if replace_action_with_move(battler, copied, MOVE_MIMIC)
          log("MIMIC_SLOT_EXECUTE battler=" + battler.name.to_s + " copied=" + copied.to_s)
        end
        return
      end

      if current_mid == MOVE_SLEEP_TALK || current_mid == MOVE_METRONOME || current_mid == MOVE_COPYCAT
        called = choose_called_move(battler, current_mid)
        if called > 0 && replace_action_with_move(battler, called, current_mid)
          mark_apply(current_mid)
          log("CALL_MOVE battler=" + battler.name.to_s + " parent=" + current_mid.to_s +
              " called=" + called.to_s + ":" + master.move_name(called).to_s)
        else
          battler.instance_variable_set(:@cg_v234_call_failed_mid, current_mid)
          log("CALL_MOVE_FAIL battler=" + battler.name.to_s + " parent=" + current_mid.to_s)
        end
      end
    end

    def self.finish_runtime_action(battler, executed_mid, valid_before)
      return if battler == nil
      if valid_before && executed_mid.to_i > 0
        record_global_move(battler, executed_mid)
      end
      battler.instance_variable_set(:@cg_v234_call_parent_mid, nil)
      battler.instance_variable_set(:@cg_v234_call_skill_id, nil)
      battler.instance_variable_set(:@cg_v234_call_failed_mid, nil)
    end

    def self.install_states
      return if $data_states == nil || !defined?(ALBERT_CG::MOVE_EFFECT)
      begin
        rows = {
          STATE_ENCORE       => ALBERT_CG::MOVE_EFFECT.make_state(STATE_ENCORE, "再來一次", 20, 99, 0, false),
          STATE_TAUNT        => ALBERT_CG::MOVE_EFFECT.make_state(STATE_TAUNT, "挑釁", 20, 99, 0, false),
          STATE_SUBSTITUTE   => ALBERT_CG::MOVE_EFFECT.make_state(STATE_SUBSTITUTE, "替身", 19, 99, 0, false),
          STATE_DESTINY_BOND => ALBERT_CG::MOVE_EFFECT.make_state(STATE_DESTINY_BOND, "同命", 24, 99, 0, false),
        }
        rows.each do |id, state|
          ALBERT_CG::MOVE_EFFECT.ensure_index($data_states, id)
          state.auto_release_prob = 0
          $data_states[id] = state
        end
        # Disable 由本頁自行管理 4 個完整後續回合，不交給 VX state_turn 自動解除。
        if $data_states[ALBERT_CG::MOVE_EFFECT::STATE_DISABLE] != nil
          $data_states[ALBERT_CG::MOVE_EFFECT::STATE_DISABLE].hold_turn = 99
          $data_states[ALBERT_CG::MOVE_EFFECT::STATE_DISABLE].auto_release_prob = 0
        end
      rescue => e
        log("STATE_INSTALL_ERROR " + e.class.to_s + ":" + e.message.to_s)
      end
    end

    #------------------------------------------------------------------------
    # AutoRegression helpers
    #------------------------------------------------------------------------
    def self.test_allies
      return $game_party == nil ? [] : $game_party.members[0,4]
    end

    def self.test_enemies
      return $game_troop == nil ? [] : $game_troop.members[0,4]
    end

    # VX 的 Game_Troop 沒有正式公開 troop_id getter。
    # 優先相容未來可能存在的 getter；目前 VX 以 @troop_id 為正式 runtime 來源。
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
      actor.cg_v234_clear_battle_memory if actor.respond_to?(:cg_v234_clear_battle_memory)
    end

    def self.configure_enemy(cfg)
      return if master == nil
      master.configure_enemy_data(cfg)
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
      end
      return true
    end

    def self.make_test_troop
      master.ensure_index($data_troops, TEST_TROOP_ID)
      # v2.3.4g：同命測試目標 E3 怪力必須是 Tom 後排近戰的合法目標。
      # 不繞過 Battlefield Grid；改以正式 troop 座標交換 E0 / E3 的前後排位置。
      # E0 卡比獸=後排右、E1 耿鬼=前排右、E2 巨金怪=後排左、E3 怪力=前排左。
      xs = [ALBERT_CG::ENEMY_BACK_X, ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_BACK_X, ALBERT_CG::ENEMY_FRONT_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[2], ALBERT_CG::GRID_COLUMN_Y[2],
            ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[0]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg, i|
        configure_enemy(cfg)
        members.push(ALBERT_CG::SPECIES26.make_troop_member(
          master.enemy_id_for_dex(cfg[:dex]), xs[i], ys[i]))
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID, "Pokemon Unique Batch B v2.3.4g AutoRegression", members)
    end

    def self.start_auto_test
      reset_log
      reset_battle_memory
      prepare_test_party
      make_test_troop
      @active = true
      @round_index = 0
      @failures = []
      @actual = []
      @round_before_counts = {}
      @boot_asserted = false
      @blocked_events = {}
      @substitute_create_events = {}
      @substitute_absorb_events = {}
      @substitute_absorb_counts = {}
      @destiny_ko_events = {}
      @future_schedule_events = {}
      log("AUTO_TEST_START troop=" + TEST_TROOP_ID.to_s)
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    end

    def self.active?
      return @active == true
    end

    def self.finished?
      return @round_index.to_i >= ROUND_PLANS.size
    end

    def self.current_plan
      return ROUND_PLANS[@round_index.to_i]
    end

    def self.current_round
      return @round_index.to_i + 1
    end

    def self.assert_true(label, condition, detail = "")
      if condition
        log("ASSERT PASS " + label.to_s + (detail == "" ? "" : " " + detail.to_s))
      else
        msg = label.to_s + (detail == "" ? "" : " " + detail.to_s)
        @failures = [] if @failures == nil
        @failures.push(msg)
        log("ASSERT FAIL " + msg)
      end
      return condition
    end

    def self.make_action(battler, cfg)
      action = Game_BattleAction.new(battler)
      if cfg[:kind] == :attack
        action.set_attack
      elsif cfg[:kind] == :move
        action.set_skill(master.skill_id_for_move(cfg[:move_id].to_i))
      else
        action.clear
      end
      action.target_index = cfg[:target].to_i if cfg.has_key?(:target)
      if cfg[:called_move_id] != nil
        battler.instance_variable_set(:@cg_v234_forced_called_move_id, cfg[:called_move_id].to_i)
      end
      return action
    end

    def self.apply_test_speeds
      key = ("r" + current_round.to_s).to_sym
      values = TEST_SPEEDS[key] || []
      list = test_allies + test_enemies
      list.each_with_index do |b, i|
        next if b == nil
        b.instance_variable_set(:@cg_priority_test_speed_override, values[i])
      end
    end

    def self.prepare_round_preconditions
      allies = test_allies
      enemies = test_enemies
      if current_round == 1
        # Wish 必須真的有可回復 HP；Destiny Bond 目標壓到 1 HP 確保 Tom 能致死。
        allies[2].hp = [allies[2].maxhp / 2, 1].max if allies[2] != nil
        @wish_hp_before = allies[2] == nil ? 0 : allies[2].hp.to_i
        enemies[3].hp = 1 if enemies[3] != nil
        @destiny_tom_hp_before = allies[0] == nil ? 0 : allies[0].hp.to_i
      elsif current_round == 2
        # Round1 Destiny Bond 會讓 Tom / Enemy3 倒下；只復活這兩位，不動 Wish/Future 狀態。
        # Round1 Substitute 已經由兩次 Tackle 完成破裂，因此 Encore 可在本回合獨立命中。
        [allies[0], enemies[3]].each do |b|
          next if b == nil
          b.hp = b.maxhp
          b.mp = b.maxmp if b.respond_to?(:mp=)
        end
        # Sleep Talk 真正於睡眠中執行。
        if allies[1] != nil
          allies[1].add_state(ALBERT_CG::MOVE_EFFECT::STATE_SLEEP)
          @sub_hp_after_cost = allies[1].hp.to_i
          @sub_shield_before_hit = allies[1].cg_v234_substitute_hp
        end
      elsif current_round == 3
        allies[1].remove_state(ALBERT_CG::MOVE_EFFECT::STATE_SLEEP) if allies[1] != nil && allies[1].state?(ALBERT_CG::MOVE_EFFECT::STATE_SLEEP)
        @wish_hp_after_expected = allies[2] == nil ? 0 : allies[2].hp.to_i
        @future_hp_before = enemies[3] == nil ? 0 : enemies[3].hp.to_i
        @taunt_stage_before = allies[2] == nil ? 0 : allies[2].cg_stat_stage(:atk)
        @disable_stage_before = allies[2] == nil ? 0 : allies[2].cg_stat_stage(:atk)
      elsif current_round == 4
        if allies[2] != nil
          @taunt_stage_before_r4 = allies[2].cg_stat_stage(:atk)
          allies[2].instance_variable_set(:@cg_v234_disabled_move_id, 0)
          allies[2].instance_variable_set(:@cg_v234_disable_turns, 0)
          allies[2].remove_state(ALBERT_CG::MOVE_EFFECT::STATE_DISABLE) if allies[2].state?(ALBERT_CG::MOVE_EFFECT::STATE_DISABLE)
        end
      end
    end

    def self.prepare_round_actions
      plan = current_plan
      return false if plan == nil
      apply_test_speeds
      prepare_round_preconditions
      @actual = []
      @round_before_counts = {}
      HANDLED_MOVE_IDS.each { |mid| @round_before_counts[mid] = apply_counts[mid].to_i }
      log("ROUND " + current_round.to_s + " BEGIN " + plan[:name].to_s)

      allies = test_allies
      plan[:allies].each_with_index do |cfg, i|
        b = allies[i]
        next if b == nil
        a = make_action(b, cfg)
        if b.respond_to?(:cg_round_actions)
          b.cg_round_actions.clear
          b.cg_round_actions.push(a)
        end
        b.cg_assign_action(a) if b.respond_to?(:cg_assign_action)
      end

      @forced_enemy = {}
      enemies = test_enemies
      plan[:enemies].each_with_index do |cfg, i|
        b = enemies[i]
        next if b == nil
        @forced_enemy[i] = make_action(b, cfg)
      end
      return true
    end

    def self.forced_enemy_action(enemy)
      return nil unless active? && @forced_enemy != nil && enemy != nil
      return @forced_enemy[enemy.index]
    end

    def self.record_execution(battler)
      return unless active? && battler != nil
      action = battler.action
      token = battler.actor? ? "A" + battler.index.to_s : "E" + battler.index.to_s
      if action != nil && action.skill?
        mid = ALBERT_CG::MOVE_EFFECT.move_id(action.skill)
        token += ":M" + mid.to_s
      elsif action != nil && action.attack?
        token += ":Attack"
      else
        token += ":Other"
      end
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + battler.name.to_s + " token=" + token)
    end

    def self.finish_round_assertions
      return unless active?
      round = current_round
      expected_count = EXPECTED_EXECUTION_COUNTS[round].to_i
      expected_tokens = EXPECTED_EXECUTION_TOKENS[round] || []
      assert_true("Round" + round.to_s + " executes expected scripted battler actions",
                  @actual.size == expected_count,
                  "expected=" + expected_count.to_s + " actual=" + @actual.size.to_s)
      assert_true("Round" + round.to_s + " execution order matches deterministic plan",
                  @actual == expected_tokens,
                  "expected=" + expected_tokens.inspect + " actual=" + @actual.inspect)

      if round == 1
        allies = test_allies
        enemies = test_enemies
        sub_event = substitute_absorb_event(1, "A1")
        assert_true("Substitute was really created during action", substitute_created?(1, "A1"))
        assert_true("Substitute absorbed Round1 direct hits without owner HP loss",
                    sub_event != nil && sub_event[:hp_before].to_i == sub_event[:hp_after].to_i &&
                    sub_event[:absorbed].to_i > 0,
                    sub_event == nil ? "event=nil" : sub_event.inspect)
        assert_true("Substitute received exactly two Round1 direct hits",
                    substitute_absorb_count(1, "A1") == 2,
                    "count=" + substitute_absorb_count(1, "A1").to_s)
        assert_true("Substitute is broken before Round2 Encore",
                    allies[1] != nil && allies[1].cg_v234_substitute_hp == 0,
                    "shield=" + (allies[1] == nil ? "nil" : allies[1].cg_v234_substitute_hp.to_s))
        assert_true("Destiny Bond direct KO also KOs attacker",
                    destiny_ko?(1, "E3", "A0") &&
                    allies[0] != nil && allies[0].hp.to_i <= 0 &&
                    enemies[3] != nil && enemies[3].hp.to_i <= 0)
        assert_true("Future Sight schedules with zero immediate damage",
                    future_schedule_no_immediate_damage?(1))
      elsif round == 2
        allies = test_allies
        assert_true("Sleep Talk called Thunderbolt", allies[1] != nil && allies[1].cg_v234_last_move_id == 85,
                    "last=" + (allies[1] == nil ? "nil" : allies[1].cg_v234_last_move_id.to_s))
        assert_true("Encore locked called Thunderbolt", allies[1] != nil && allies[1].cg_v234_encore_move_id == 85)
        assert_true("Mimic copied Encore from target same-round last move", allies[3] != nil && allies[3].cg_v234_mimic_move_id == 227,
                    "copied=" + (allies[3] == nil ? "nil" : allies[3].cg_v234_mimic_move_id.to_s))
        assert_true("Copycat executed latest Swords Dance before Taunt",
                    apply_counts[MOVE_COPYCAT].to_i > @round_before_counts[MOVE_COPYCAT].to_i &&
                    allies[2] != nil && allies[2].cg_v234_last_move_id == 14)
        assert_true("Taunt active on Copycat user", allies[2] != nil && allies[2].cg_v234_taunt_active?)
        assert_true("Disable bound Copycat user's latest Swords Dance",
                    allies[2] != nil && allies[2].cg_v234_disabled_move_id == 14,
                    "disabled=" + (allies[2] == nil ? "nil" : allies[2].cg_v234_disabled_move_id.to_s))
        assert_true("Wish resolved on next turn end", allies[2] != nil && allies[2].hp.to_i > @wish_hp_before.to_i,
                    "before=" + @wish_hp_before.to_i.to_s + " after=" + (allies[2] == nil ? "nil" : allies[2].hp.to_i.to_s))
      elsif round == 3
        allies = test_allies
        enemies = test_enemies
        assert_true("Encore execution layer forced Thunderbolt", allies[1] != nil && allies[1].cg_v234_last_move_id == 85)
        assert_true("Disable blocked Swords Dance before execute_action",
                    blocked?(3, "A2", 14, :disable))
        assert_true("Disable blocked Swords Dance stage change",
                    allies[2] != nil && allies[2].cg_stat_stage(:atk) == @disable_stage_before.to_i)
        assert_true("Mimic slot executes copied Encore", allies[3] != nil && allies[3].cg_v234_last_move_id == 227)
        assert_true("Mimic-copied Encore controls enemy AI",
                    enemies[1] != nil && enemies[1].cg_v234_encore_move_id == 269 &&
                    enemies[1].cg_v234_last_move_id == 269,
                    "encore=" + (enemies[1] == nil ? "nil" : enemies[1].cg_v234_encore_move_id.to_s) +
                    " last=" + (enemies[1] == nil ? "nil" : enemies[1].cg_v234_last_move_id.to_s))
        assert_true("Future Sight resolved after two full turns", enemies[3] != nil && enemies[3].hp.to_i < @future_hp_before.to_i,
                    "before=" + @future_hp_before.to_i.to_s + " after=" + (enemies[3] == nil ? "nil" : enemies[3].hp.to_i.to_s))
      elsif round == 4
        allies = test_allies
        assert_true("Encore remains active and forces Thunderbolt again in Round4",
                    allies[1] != nil && @actual.include?("A1:M85") &&
                    allies[1].cg_v234_encore_move_id == 85 &&
                    allies[1].cg_v234_last_move_id == 85,
                    "hp=" + (allies[1] == nil ? "nil" : allies[1].hp.to_i.to_s) +
                    " encore=" + (allies[1] == nil ? "nil" : allies[1].cg_v234_encore_move_id.to_s) +
                    " last=" + (allies[1] == nil ? "nil" : allies[1].cg_v234_last_move_id.to_s))
        assert_true("Taunt independently blocks Status Move after Disable cleared",
                    blocked?(4, "A2", 14, :taunt) &&
                    allies[2] != nil && allies[2].cg_stat_stage(:atk) == @taunt_stage_before_r4.to_i)
      end

      log("ROUND " + round.to_s + " END")
      @round_index = @round_index.to_i + 1
    end

    def self.assert_bootstrap_once
      return if @boot_asserted == true
      @boot_asserted = true
      troop_id = current_troop_id
      assert_true("Scene_Battle uses Unique B test troop", troop_id == TEST_TROOP_ID,
                  "actual=" + troop_id.to_s)
      allies = test_allies
      enemies = test_enemies
      expected_allies = [ALBERT_CG::SOLO_HUMAN_ACTOR_ID] + TEST_ALLIES.collect { |cfg| master.actor_id_for_dex(cfg[:dex]) }
      actual_allies = allies.collect { |b| b == nil ? -1 : b.id.to_i }
      expected_enemies = TEST_ENEMIES.collect { |cfg| master.enemy_id_for_dex(cfg[:dex]) }
      actual_enemies = enemies.collect { |b| b == nil ? -1 : b.enemy_id.to_i }
      assert_true("Unique B ally count=4", allies.size == 4, "actual=" + allies.size.to_s)
      assert_true("Unique B enemy count=4", enemies.size == 4, "actual=" + enemies.size.to_s)
      assert_true("Unique B exact ally roster", actual_allies == expected_allies,
                  "expected=" + expected_allies.inspect + " actual=" + actual_allies.inspect)
      assert_true("Unique B exact enemy roster", actual_enemies == expected_enemies,
                  "expected=" + expected_enemies.inspect + " actual=" + actual_enemies.inspect)
      # v2.3.4g：Destiny Bond regression 必須遵守正式 Battlefield Grid。
      # Tom 預設後排近戰；E3 怪力改放前排後，target_index=3 才是合法直接目標。
      if allies[0] != nil && enemies[3] != nil &&
         allies[0].respond_to?(:cg_back_row?) && enemies[3].respond_to?(:cg_front_row?)
        assert_true("Destiny Bond regression target is Grid-legal",
                    allies[0].cg_back_row? && enemies[3].cg_front_row?,
                    "Tom=" + allies[0].cg_grid_label.to_s +
                    " E3=" + enemies[3].cg_grid_label.to_s)
      end
    end

    def self.finish_suite
      covered = HANDLED_MOVE_IDS.select { |mid| apply_counts[mid].to_i > 0 }
      missing = HANDLED_MOVE_IDS - covered
      assert_true("All 11 Unique Batch B moves executed", missing.empty?, "missing=" + missing.inspect)
      failures = @failures || []
      log("------------------------------------------------------------")
      if failures.empty?
        log("RESULT=PASS")
        log("SUMMARY rounds=" + ROUND_PLANS.size.to_s + " failures=0 unique_moves=" + covered.size.to_s + "/11")
      else
        log("RESULT=FAIL")
        log("SUMMARY rounds=" + ROUND_PLANS.size.to_s + " failures=" + failures.size.to_s +
            " unique_moves=" + covered.size.to_s + "/11")
        failures.each_with_index { |msg, i| log("FAILURE " + (i+1).to_s + " " + msg.to_s) }
      end
      @active = false
      return failures.empty?
    end
  end
end

#==============================================================================
# ■ Game_Battler：Unique Batch B Battle Memory / 限制 / Substitute
#==============================================================================
class Game_Battler
  def cg_v234_set_last_move_id(move_id)
    @cg_v234_last_move_id = move_id.to_i
  end

  def cg_v234_last_move_id
    return @cg_v234_last_move_id.to_i
  end

  def cg_v234_known_move_ids
    result = []
    if actor? && respond_to?(:cg_skill_slot_ids)
      cg_skill_slot_ids.each do |sid|
        mid = ALBERT_CG::POKEMON_MASTER.move_id_for_skill(sid)
        if mid == ALBERT_CG::UNIQUE_B_V234::MOVE_MIMIC && cg_v234_mimic_move_id > 0
          mid = cg_v234_mimic_move_id
        end
        result.push(mid) if mid > 0 && !result.include?(mid)
      end
    elsif !actor? && respond_to?(:enemy) && enemy != nil
      enemy.actions.each do |action|
        next unless action.kind.to_i == 1
        mid = ALBERT_CG::POKEMON_MASTER.move_id_for_skill(action.skill_id)
        result.push(mid) if mid > 0 && !result.include?(mid)
      end
    end
    return result
  rescue
    return []
  end

  def cg_v234_substitute_hp
    return @cg_v234_substitute_hp.to_i
  end

  def cg_v234_substitute_active?
    return cg_v234_substitute_hp > 0
  end

  def cg_v234_create_substitute
    cost = [maxhp.to_i / ALBERT_CG::UNIQUE_B_V234::SUBSTITUTE_HP_DIVISOR, 1].max
    return false if hp.to_i <= cost || cg_v234_substitute_active?
    self.hp -= cost
    self.hp_damage = cost if respond_to?(:hp_damage=)
    @cg_v234_substitute_hp = cost
    cg_v231_add_state_record(ALBERT_CG::UNIQUE_B_V234::STATE_SUBSTITUTE) if respond_to?(:cg_v231_add_state_record)
    return true
  end

  def cg_v234_break_substitute
    @cg_v234_substitute_hp = 0
    remove_state(ALBERT_CG::UNIQUE_B_V234::STATE_SUBSTITUTE) if state?(ALBERT_CG::UNIQUE_B_V234::STATE_SUBSTITUTE)
  end

  def cg_v234_destiny_bond?
    return @cg_v234_destiny_bond == true
  end

  def cg_v234_set_destiny_bond
    @cg_v234_destiny_bond = true
    cg_v231_add_state_record(ALBERT_CG::UNIQUE_B_V234::STATE_DESTINY_BOND) if respond_to?(:cg_v231_add_state_record)
  end

  def cg_v234_clear_destiny_bond
    @cg_v234_destiny_bond = false
    remove_state(ALBERT_CG::UNIQUE_B_V234::STATE_DESTINY_BOND) if state?(ALBERT_CG::UNIQUE_B_V234::STATE_DESTINY_BOND)
  end

  def cg_v234_mimic_move_id
    return @cg_v234_mimic_move_id.to_i
  end

  def cg_v234_set_mimic_move(move_id)
    @cg_v234_mimic_move_id = move_id.to_i
  end

  def cg_v234_disabled_move_id
    return @cg_v234_disabled_move_id.to_i
  end

  def cg_v234_disable_move(move_id)
    @cg_v234_disabled_move_id = move_id.to_i
    @cg_v234_disable_turns = ALBERT_CG::UNIQUE_B_V234::DISABLE_TURNS
    @cg_v234_disable_fresh = true
    cg_v231_add_state_record(ALBERT_CG::MOVE_EFFECT::STATE_DISABLE) if respond_to?(:cg_v231_add_state_record)
  end

  def cg_v234_encore_move_id
    return @cg_v234_encore_move_id.to_i
  end

  def cg_v234_encore_active?
    return @cg_v234_encore_turns.to_i > 0 && cg_v234_encore_move_id > 0
  end

  def cg_v234_set_encore(move_id)
    @cg_v234_encore_move_id = move_id.to_i
    @cg_v234_encore_turns = ALBERT_CG::UNIQUE_B_V234::ENCORE_TURNS
    @cg_v234_encore_fresh = true
    cg_v231_add_state_record(ALBERT_CG::UNIQUE_B_V234::STATE_ENCORE) if respond_to?(:cg_v231_add_state_record)
  end

  def cg_v234_taunt_active?
    return @cg_v234_taunt_turns.to_i > 0
  end

  def cg_v234_set_taunt
    @cg_v234_taunt_turns = ALBERT_CG::UNIQUE_B_V234::TAUNT_TURNS
    @cg_v234_taunt_fresh = true
    cg_v231_add_state_record(ALBERT_CG::UNIQUE_B_V234::STATE_TAUNT) if respond_to?(:cg_v231_add_state_record)
  end

  def cg_v234_tick_restrictions
    if @cg_v234_disable_turns.to_i > 0
      if @cg_v234_disable_fresh
        @cg_v234_disable_fresh = false
      else
        @cg_v234_disable_turns -= 1
        if @cg_v234_disable_turns <= 0
          @cg_v234_disabled_move_id = 0
          remove_state(ALBERT_CG::MOVE_EFFECT::STATE_DISABLE) if state?(ALBERT_CG::MOVE_EFFECT::STATE_DISABLE)
          ALBERT_CG::UNIQUE_B_V234.log("DISABLE_EXPIRE battler=" + name.to_s)
        end
      end
    end
    if @cg_v234_encore_turns.to_i > 0
      if @cg_v234_encore_fresh
        @cg_v234_encore_fresh = false
      else
        @cg_v234_encore_turns -= 1
        if @cg_v234_encore_turns <= 0
          @cg_v234_encore_move_id = 0
          remove_state(ALBERT_CG::UNIQUE_B_V234::STATE_ENCORE) if state?(ALBERT_CG::UNIQUE_B_V234::STATE_ENCORE)
          ALBERT_CG::UNIQUE_B_V234.log("ENCORE_EXPIRE battler=" + name.to_s)
        end
      end
    end
    if @cg_v234_taunt_turns.to_i > 0
      if @cg_v234_taunt_fresh
        @cg_v234_taunt_fresh = false
      else
        @cg_v234_taunt_turns -= 1
        if @cg_v234_taunt_turns <= 0
          remove_state(ALBERT_CG::UNIQUE_B_V234::STATE_TAUNT) if state?(ALBERT_CG::UNIQUE_B_V234::STATE_TAUNT)
          ALBERT_CG::UNIQUE_B_V234.log("TAUNT_EXPIRE battler=" + name.to_s)
        end
      end
    end
  end

  def cg_v234_clear_battle_memory
    @cg_v234_last_move_id = 0
    @cg_v234_mimic_move_id = 0
    @cg_v234_disabled_move_id = 0
    @cg_v234_disable_turns = 0
    @cg_v234_disable_fresh = false
    @cg_v234_encore_move_id = 0
    @cg_v234_encore_turns = 0
    @cg_v234_encore_fresh = false
    @cg_v234_taunt_turns = 0
    @cg_v234_taunt_fresh = false
    @cg_v234_substitute_hp = 0
    @cg_v234_substitute_absorbed_this_hit = false
    cg_v234_clear_destiny_bond
    [ALBERT_CG::UNIQUE_B_V234::STATE_ENCORE,
     ALBERT_CG::UNIQUE_B_V234::STATE_TAUNT,
     ALBERT_CG::UNIQUE_B_V234::STATE_SUBSTITUTE,
     ALBERT_CG::MOVE_EFFECT::STATE_DISABLE].each do |sid|
      remove_state(sid) if state?(sid)
    end
  end

  alias cg_v234_remove_states_battle remove_states_battle
  def remove_states_battle
    cg_v234_remove_states_battle
    cg_v234_clear_battle_memory
  end

  # Actor 動態呼叫 Move／Mimic 被複製 Move 不應被「未學習」檢查擋掉。
  def cg_v234_virtual_skill_allowed?(skill)
    return false if skill == nil
    call_sid = @cg_v234_call_skill_id.to_i
    return true if call_sid > 0 && skill.id.to_i == call_sid
    if actor? && cg_v234_mimic_move_id > 0
      sid = ALBERT_CG::POKEMON_MASTER.skill_id_for_move(cg_v234_mimic_move_id)
      return true if skill.id.to_i == sid.to_i
    end
    return false
  end

  def cg_v234_skill_can_use_without_learning(skill)
    return false unless skill.is_a?(RPG::Skill)
    allow_sleep_call = @cg_v234_call_parent_mid.to_i == ALBERT_CG::UNIQUE_B_V234::MOVE_SLEEP_TALK
    return false unless movable? || allow_sleep_call
    return false if silent? && skill.spi_f > 0
    return false if calc_mp_cost(skill) > mp
    return false unless $game_temp.in_battle ? skill.battle_ok? : skill.menu_ok?
    mid = ALBERT_CG::MOVE_EFFECT.move_id(skill)
    return false if cg_v234_disabled_move_id > 0 && mid == cg_v234_disabled_move_id
    return false if cg_v234_taunt_active? && ALBERT_CG::UNIQUE_B_V234.move_status?(mid)
    return true
  end

  alias cg_v234_base_skill_can_use skill_can_use?
  def skill_can_use?(skill)
    mid = skill == nil ? 0 : ALBERT_CG::MOVE_EFFECT.move_id(skill)
    if cg_v234_disabled_move_id > 0 && mid == cg_v234_disabled_move_id
      ALBERT_CG::UNIQUE_B_V234.note_block(self, mid, :disable)
      ALBERT_CG::UNIQUE_B_V234.log("DISABLE_BLOCK battler=" + name.to_s + " move=" + mid.to_s)
      return false
    end
    if cg_v234_taunt_active? && mid > 0 && ALBERT_CG::UNIQUE_B_V234.move_status?(mid)
      ALBERT_CG::UNIQUE_B_V234.note_block(self, mid, :taunt)
      ALBERT_CG::UNIQUE_B_V234.log("TAUNT_BLOCK battler=" + name.to_s + " move=" + mid.to_s)
      return false
    end
    return cg_v234_skill_can_use_without_learning(skill) if cg_v234_virtual_skill_allowed?(skill)
    return cg_v234_base_skill_can_use(skill)
  end

  alias cg_v234_calc_hit calc_hit
  def calc_hit(user, obj = nil)
    return 100 if defined?(ALBERT_CG::UNIQUE_B_V234) && ALBERT_CG::UNIQUE_B_V234.active?
    return cg_v234_calc_hit(user, obj)
  end

  alias cg_v234_calc_eva calc_eva
  def calc_eva(user, obj = nil)
    return 0 if defined?(ALBERT_CG::UNIQUE_B_V234) && ALBERT_CG::UNIQUE_B_V234.active?
    return cg_v234_calc_eva(user, obj)
  end

  # Substitute 必須在真正扣 HP 前攔截，所以包在 v2.3.1 Endure execute_damage 外層。
  alias cg_v234_execute_damage execute_damage
  def execute_damage(user)
    if @hp_damage.to_i > 0 && cg_v234_substitute_active? && user != nil &&
       user.actor? != actor?
      incoming = @hp_damage.to_i
      owner_hp_before = hp.to_i
      absorbed = [incoming, @cg_v234_substitute_hp.to_i].min
      @cg_v234_substitute_hp -= absorbed
      @cg_v234_substitute_absorbed_this_hit = true
      @hp_damage = 0
      ALBERT_CG::UNIQUE_B_V234.note_substitute_absorb(
        self, incoming, absorbed, @cg_v234_substitute_hp.to_i, owner_hp_before, hp.to_i)
      ALBERT_CG::UNIQUE_B_V234.log("SUBSTITUTE_ABSORB target=" + name.to_s +
        " incoming=" + incoming.to_s + " absorbed=" + absorbed.to_s +
        " shield_left=" + @cg_v234_substitute_hp.to_i.to_s)
      cg_v234_break_substitute if @cg_v234_substitute_hp.to_i <= 0
      return
    end

    destiny_before = cg_v234_destiny_bond?
    lethal = destiny_before && user != nil && user.actor? != actor? &&
             @hp_damage.to_i > 0 && @hp_damage.to_i >= hp.to_i
    if destiny_before && defined?(ALBERT_CG::UNIQUE_B_V234) &&
       ALBERT_CG::UNIQUE_B_V234.active?
      ALBERT_CG::UNIQUE_B_V234.log("DESTINY_BOND_DAMAGE_CHECK target=" + name.to_s +
        " attacker=" + (user == nil ? "nil" : user.name.to_s) +
        " hp=" + hp.to_i.to_s + " damage=" + @hp_damage.to_i.to_s +
        " lethal=" + lethal.to_s)
    end
    cg_v234_execute_damage(user)
    if lethal && hp.to_i <= 0 && user.hp.to_i > 0
      loss = user.hp.to_i
      user.hp = 0
      user.hp_damage = loss if user.respond_to?(:hp_damage=)
      ALBERT_CG::UNIQUE_B_V234.note_destiny_ko(self, user)
      ALBERT_CG::UNIQUE_B_V234.log("DESTINY_BOND_KO target=" + name.to_s +
        " attacker=" + user.name.to_s)
      cg_v234_clear_destiny_bond
    end
  end

  #--------------------------------------------------------------------------
  # * Destiny Bond：普通攻擊致死 fallback
  #--------------------------------------------------------------------------
  # Tankentai SBS 的普通攻擊演出路徑在部分 Action Sequence 下，可能不會讓
  # Unique B 的 execute_damage 外層取得同一個觀測點。為避免「技能可觸發同命、
  # 普攻卻漏掉」的規則裂縫，這裡再從 attack_effect 的正式入口做結果型判定。
  # 若 execute_damage 已經先處理同命，攻擊者 HP 已為 0，本 fallback 不會重複觸發。
  alias cg_v234_attack_effect_destiny_fallback attack_effect
  def attack_effect(attacker)
    destiny_before = cg_v234_destiny_bond?
    hp_before = hp.to_i
    attacker_hp_before = attacker == nil ? 0 : attacker.hp.to_i
    if destiny_before && defined?(ALBERT_CG::UNIQUE_B_V234) &&
       ALBERT_CG::UNIQUE_B_V234.active?
      ALBERT_CG::UNIQUE_B_V234.log("DESTINY_BOND_ATTACK_BEGIN target=" + name.to_s +
        " attacker=" + (attacker == nil ? "nil" : attacker.name.to_s) +
        " target_hp=" + hp_before.to_s + " attacker_hp=" + attacker_hp_before.to_s)
    end

    cg_v234_attack_effect_destiny_fallback(attacker)

    if destiny_before && attacker != nil && attacker.actor? != actor? &&
       hp_before > 0 && hp.to_i <= 0 && attacker.hp.to_i > 0
      loss = attacker.hp.to_i
      attacker.hp = 0
      attacker.hp_damage = loss if attacker.respond_to?(:hp_damage=)
      ALBERT_CG::UNIQUE_B_V234.note_destiny_ko(self, attacker)
      ALBERT_CG::UNIQUE_B_V234.log("DESTINY_BOND_KO_ATTACK_FALLBACK target=" + name.to_s +
        " attacker=" + attacker.name.to_s + " target_hp_before=" + hp_before.to_s)
      cg_v234_clear_destiny_bond
    elsif destiny_before && defined?(ALBERT_CG::UNIQUE_B_V234) &&
          ALBERT_CG::UNIQUE_B_V234.active?
      ALBERT_CG::UNIQUE_B_V234.log("DESTINY_BOND_ATTACK_END target=" + name.to_s +
        " attacker=" + (attacker == nil ? "nil" : attacker.name.to_s) +
        " target_hp=" + hp.to_i.to_s +
        " attacker_hp=" + (attacker == nil ? "nil" : attacker.hp.to_i.to_s))
    end
  end

  alias cg_v234_apply_ailment cg_move_effect_apply_ailment
  def cg_move_effect_apply_ailment(user, move_id)
    if @cg_v234_substitute_absorbed_this_hit == true && user != nil && user.actor? != actor?
      ALBERT_CG::UNIQUE_B_V234.log("SUBSTITUTE_BLOCK_SECONDARY_AILMENT target=" + name.to_s +
        " move=" + move_id.to_i.to_s)
      return
    end
    cg_v234_apply_ailment(user, move_id)
  end

  alias cg_v234_apply_stats cg_move_effect_apply_stats
  def cg_move_effect_apply_stats(user, move_id)
    if @cg_v234_substitute_absorbed_this_hit == true && user != nil && user.actor? != actor?
      ALBERT_CG::UNIQUE_B_V234.log("SUBSTITUTE_BLOCK_SECONDARY_STAGE target=" + name.to_s +
        " move=" + move_id.to_i.to_s)
      return
    end
    cg_v234_apply_stats(user, move_id)
  end

  alias cg_v234_skill_effect skill_effect
  def skill_effect(user, skill)
    mid = ALBERT_CG::MOVE_EFFECT.move_id(skill)
    @cg_v234_substitute_absorbed_this_hit = false

    # 對手 Status Move 遇到 Substitute，整招阻擋。
    if mid > 0 && cg_v234_substitute_active? && user != nil && user.actor? != actor? &&
       ALBERT_CG::UNIQUE_B_V234.move_status?(mid)
      clear_action_results
      @skipped = true
      ALBERT_CG::UNIQUE_B_V234.log("SUBSTITUTE_BLOCK_STATUS target=" + name.to_s +
        " user=" + user.name.to_s + " move=" + mid.to_s)
      return
    end

    case mid
    when ALBERT_CG::UNIQUE_B_V234::MOVE_SUBSTITUTE
      clear_action_results
      if user.cg_v234_create_substitute
        ALBERT_CG::UNIQUE_B_V234.mark_apply(mid)
        ALBERT_CG::UNIQUE_B_V234.note_substitute_create(user, user.cg_v234_substitute_hp)
        ALBERT_CG::UNIQUE_B_V234.log("SUBSTITUTE_CREATE user=" + user.name.to_s +
          " shield=" + user.cg_v234_substitute_hp.to_s)
      else
        ALBERT_CG::UNIQUE_B_V234.log("SUBSTITUTE_FAIL user=" + user.name.to_s)
      end
      return

    when ALBERT_CG::UNIQUE_B_V234::MOVE_DESTINY_BOND
      clear_action_results
      user.cg_v234_set_destiny_bond
      ALBERT_CG::UNIQUE_B_V234.mark_apply(mid)
      ALBERT_CG::UNIQUE_B_V234.log("DESTINY_BOND_ACTIVE user=" + user.name.to_s)
      return

    when ALBERT_CG::UNIQUE_B_V234::MOVE_WISH
      clear_action_results
      ALBERT_CG::UNIQUE_B_V234.schedule_wish(user)
      ALBERT_CG::UNIQUE_B_V234.mark_apply(mid)
      return

    when ALBERT_CG::UNIQUE_B_V234::MOVE_FUTURE_SIGHT
      unless ALBERT_CG::UNIQUE_B_V234.resolving_future_sight?
        clear_action_results
        hp_before_schedule = hp.to_i
        ALBERT_CG::UNIQUE_B_V234.schedule_future_sight(user, self)
        ALBERT_CG::UNIQUE_B_V234.note_future_schedule(user, self, hp_before_schedule, hp.to_i)
        ALBERT_CG::UNIQUE_B_V234.mark_apply(mid)
        return
      end

    when ALBERT_CG::UNIQUE_B_V234::MOVE_DISABLE
      clear_action_results
      target_mid = cg_v234_last_move_id
      if target_mid > 0 && ALBERT_CG::UNIQUE_B_V234.master != nil && ALBERT_CG::UNIQUE_B_V234.master.move(target_mid) != nil
        cg_v234_disable_move(target_mid)
        ALBERT_CG::UNIQUE_B_V234.mark_apply(mid)
        ALBERT_CG::UNIQUE_B_V234.log("DISABLE_SET target=" + name.to_s + " move=" + target_mid.to_s)
      else
        ALBERT_CG::UNIQUE_B_V234.log("DISABLE_FAIL target=" + name.to_s + " last=" + target_mid.to_s)
      end
      return

    when ALBERT_CG::UNIQUE_B_V234::MOVE_ENCORE
      clear_action_results
      target_mid = cg_v234_last_move_id
      if target_mid > 0 && cg_v234_known_move_ids.include?(target_mid)
        cg_v234_set_encore(target_mid)
        ALBERT_CG::UNIQUE_B_V234.mark_apply(mid)
        ALBERT_CG::UNIQUE_B_V234.log("ENCORE_SET target=" + name.to_s + " move=" + target_mid.to_s)
      else
        ALBERT_CG::UNIQUE_B_V234.log("ENCORE_FAIL target=" + name.to_s + " last=" + target_mid.to_s)
      end
      return

    when ALBERT_CG::UNIQUE_B_V234::MOVE_TAUNT
      clear_action_results
      cg_v234_set_taunt
      ALBERT_CG::UNIQUE_B_V234.mark_apply(mid)
      ALBERT_CG::UNIQUE_B_V234.log("TAUNT_SET target=" + name.to_s)
      return

    when ALBERT_CG::UNIQUE_B_V234::MOVE_MIMIC
      clear_action_results
      target_mid = cg_v234_last_move_id
      if target_mid > 0 && ALBERT_CG::UNIQUE_B_V234.callable_move?(target_mid)
        user.cg_v234_set_mimic_move(target_mid)
        ALBERT_CG::UNIQUE_B_V234.mark_apply(mid)
        ALBERT_CG::UNIQUE_B_V234.log("MIMIC_SET user=" + user.name.to_s +
          " target=" + name.to_s + " copied=" + target_mid.to_s)
      else
        ALBERT_CG::UNIQUE_B_V234.log("MIMIC_FAIL user=" + user.name.to_s + " target=" + name.to_s)
      end
      return

    when ALBERT_CG::UNIQUE_B_V234::MOVE_SLEEP_TALK,
         ALBERT_CG::UNIQUE_B_V234::MOVE_METRONOME,
         ALBERT_CG::UNIQUE_B_V234::MOVE_COPYCAT
      # 成功時 Scene_Battle 已把 action 換成 called Move，不會進到這裡。
      # 進到這裡代表沒有合法 called move。
      clear_action_results
      ALBERT_CG::UNIQUE_B_V234.log("CALL_PARENT_NO_EFFECT user=" + user.name.to_s + " move=" + mid.to_s)
      return
    end

    begin
      cg_v234_skill_effect(user, skill)
    ensure
      @cg_v234_substitute_absorbed_this_hit = false
    end
  end
end

#==============================================================================
# ■ Game_Actor：Mimic 暫時技能欄顯示 + 動態呼叫使用權
#==============================================================================
class Game_Actor < Game_Battler
  alias cg_v234_actor_slot_skills cg_skill_slot_skills
  def cg_skill_slot_skills
    list = cg_v234_actor_slot_skills
    return list if cg_v234_mimic_move_id <= 0
    copied_sid = ALBERT_CG::POKEMON_MASTER.skill_id_for_move(cg_v234_mimic_move_id)
    copied = $data_skills[copied_sid]
    return list if copied == nil
    result = []
    list.each do |skill|
      mid = skill == nil ? 0 : ALBERT_CG::POKEMON_MASTER.move_id_for_skill(skill.id)
      result.push(mid == ALBERT_CG::UNIQUE_B_V234::MOVE_MIMIC ? copied : skill)
    end
    return result
  end

  alias cg_v234_actor_skill_can_use skill_can_use?
  def skill_can_use?(skill)
    return cg_v234_skill_can_use_without_learning(skill) if cg_v234_virtual_skill_allowed?(skill)
    return cg_v234_actor_skill_can_use(skill)
  end
end

#==============================================================================
# ■ Game_Battler：Unique B deterministic SPE override
#------------------------------------------------------------------------------
# 【用途】
#  Action Priority v2.3.2 原本只有自己的 Priority Regression active 時才讀取
#  @cg_priority_test_speed_override。Unique B 雖有填 TEST_SPEEDS，實際卻被忽略，
#  導致 Mimic / Copycat / Disable / Destiny Bond 這類依賴同回合先後順序的測試漂移。
#  本覆寫只在 Unique B AutoRegression active 時生效，正式遊戲完全不改速度。
#==============================================================================
class Game_Battler
  alias cg_v234b_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    override = @cg_priority_test_speed_override
    if defined?(ALBERT_CG::UNIQUE_B_V234) &&
       ALBERT_CG::UNIQUE_B_V234.active? && override != nil
      return override.to_i
    end
    return cg_v234b_priority_base_speed
  end
end

#==============================================================================
# ■ Game_BattleAction：Encore 必須在 Priority 排序階段就使用被鎖定 Move 的優先度
#------------------------------------------------------------------------------
# 【用途】
#  Encore 的真正 action 轉換發生在 Scene_Battle#execute_action 前；若排序階段仍讀
#  玩家／AI 原本選擇的 Move，便可能出現「選 Quick Attack(+1)，執行時變 Thunderbolt(0)，
#  但仍偷用 +1 排序」的錯誤。本覆寫讓 Priority Core 在排序時直接採用 Encore Move。
#  不改寫 action 本體，因此仍由既有執行層統一處理技能替換與 LOG。
#==============================================================================
class Game_BattleAction
  alias cg_v234c_base_priority cg_base_priority
  def cg_base_priority
    b = @battler
    if b != nil && b.respond_to?(:cg_v234_encore_active?) && b.cg_v234_encore_active?
      mid = b.cg_v234_encore_move_id
      if mid.to_i > 0 && defined?(ALBERT_CG::POKEMON_MASTER)
        sid = ALBERT_CG::POKEMON_MASTER.skill_id_for_move(mid.to_i)
        obj = $data_skills[sid]
        return obj.cg_action_priority_value.to_i if obj != nil &&
          obj.respond_to?(:cg_action_priority_value)
      end
    end
    return cg_v234c_base_priority
  rescue
    return cg_v234c_base_priority
  end
end

#==============================================================================
# ■ Game_BattleAction：Sleep Talk 睡眠中仍可進入真正執行層
#==============================================================================
class Game_BattleAction
  alias cg_v234_valid valid?
  def valid?
    if skill? && skill != nil && battler != nil
      mid = ALBERT_CG::MOVE_EFFECT.move_id(skill)
      if (mid == ALBERT_CG::UNIQUE_B_V234::MOVE_SLEEP_TALK &&
          battler.state?(ALBERT_CG::MOVE_EFFECT::STATE_SLEEP)) ||
         (battler.instance_variable_get(:@cg_v234_call_parent_mid).to_i == ALBERT_CG::UNIQUE_B_V234::MOVE_SLEEP_TALK &&
          battler.instance_variable_get(:@cg_v234_call_skill_id).to_i == skill.id.to_i)
        return false if nothing?
        return false if battler.dead?
        return true
      end
    end
    return cg_v234_valid
  end
end

#==============================================================================
# ■ Game_Enemy：AutoRegression 強制行動
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v234_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::UNIQUE_B_V234) && ALBERT_CG::UNIQUE_B_V234.active?
      forced = ALBERT_CG::UNIQUE_B_V234.forced_enemy_action(self)
      if forced != nil
        cg_assign_action(forced.cg_copy_for(self)) if respond_to?(:cg_assign_action)
        @action = forced.cg_copy_for(self) unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v234_enemy_make_action
  end
end

#==============================================================================
# ■ Game_Party：換寵清除個體型 Unique 狀態；位置型 Wish/Future Sight 保留
#==============================================================================
class Game_Party < Game_Unit
  if method_defined?(:cg_battle_switch_pet)
    alias cg_v234_battle_switch_pet cg_battle_switch_pet
    def cg_battle_switch_pet(actor_id, owner_actor_or_id = nil)
      old_pet = cg_repair_active_pet_for_owner!(cg_owner_actor_id_from(owner_actor_or_id)) rescue nil
      result = cg_v234_battle_switch_pet(actor_id, owner_actor_or_id)
      old_pet.cg_v234_clear_battle_memory if result && old_pet != nil &&
        old_pet.respond_to?(:cg_v234_clear_battle_memory)
      return result
    end
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle 重新 bootstrap 時重套 Unique B 測試隊伍
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v234_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v234_bootstrap_demo_party
      if defined?(ALBERT_CG::UNIQUE_B_V234) && ALBERT_CG::UNIQUE_B_V234.active?
        ALBERT_CG::UNIQUE_B_V234::TEST_ALLIES.each do |cfg|
          ALBERT_CG::UNIQUE_B_V234.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::UNIQUE_B_V234::TEST_LEVEL, false)
          human.recover_all if human.respond_to?(:recover_all)
        end
      end
      return result
    end
  end
end

#==============================================================================
# ■ Scene_Title：安裝 v2.3.4 Runtime State
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_v234_load_database load_database
  def load_database
    cg_v234_load_database
    ALBERT_CG::UNIQUE_B_V234.install_states
  end

  alias cg_v234_load_bt_database load_bt_database
  def load_bt_database
    cg_v234_load_bt_database
    ALBERT_CG::UNIQUE_B_V234.install_states
  end
end

#==============================================================================
# ■ Scene_Battle：Action transform / last move / turn tick / AutoRegression
#==============================================================================
class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # * v2.3.4f Tankentai SBS 普通攻擊同命橋接
  #--------------------------------------------------------------------------
  # 【用途】
  #  Tankentai Sideview 會在 Scene_Battle#damage_action 內才真正執行普通攻擊傷害。
  #  這層是 SBS 的實際傷害落點，因此在原 damage_action 前保存本次普通攻擊的
  #  真正目標、目標 HP 與 Destiny Bond 狀態，原處理完成後再檢查是否由存活變倒下。
  #
  # 【規則】
  #  - 只監看普通攻擊，不攔截技能／道具。
  #  - 只有敵我不同側、攻擊前目標 HP > 0、攻擊後 HP <= 0、攻擊者仍存活、
  #    且該目標的 Destiny Bond 仍有效時才觸發。
  #  - 若 execute_damage / attack_effect 已先觸發同命，攻擊者會已倒下或狀態已清除，
  #    本層自然略過，避免雙重處理。
  #  - individual action 時不 shift @individual_target，只讀取第一個實際目標快照，
  #    讓 Tankentai 原流程仍自行消耗其佇列。
  #
  # 【參數／呼叫】
  #  無需事件呼叫；由 Tankentai 每次 damage_action 自動工作。
  #  Regression active 時會寫入：
  #    TANKENTAI_ATTACK_TARGET
  #    TANKENTAI_DESTINY_DAMAGE_CHECK
  #    DESTINY_BOND_KO_TANKENTAI
  #
  # 【實例】
  #  怪力先用同命，Tom 普攻把 HP=1 的怪力擊倒：原 damage_action 結束後，
  #  若怪力由 HP>0 變成 HP=0，Tom 也會 HP=0，並記錄 TEST_EVENT DESTINY_BOND_KO。
  #--------------------------------------------------------------------------
  alias cg_v234e_damage_action_destiny_bridge damage_action
  def damage_action(action)
    attacker = @active_battler
    normal_attack = false
    if attacker != nil && attacker.action != nil
      normal_attack = attacker.action.attack?
    end

    bridge_targets = []
    if normal_attack
      if attacker.respond_to?(:individual) && attacker.individual &&
         @individual_target != nil && @individual_target.size > 0
        bridge_targets = [@individual_target[0]]
      elsif @targets != nil
        bridge_targets = @targets.dup
      end
    end

    if ALBERT_CG::UNIQUE_B_V234.active? && attacker != nil
      ALBERT_CG::UNIQUE_B_V234.log(
        "TANKENTAI_DAMAGE_ACTION attacker=" + attacker.name.to_s +
        " normal_attack=" + normal_attack.to_s +
        " target_count=" + bridge_targets.size.to_s)
    end

    watchers = []
    if normal_attack && attacker != nil
      bridge_targets.each do |target|
        next if target == nil
        destiny = target.respond_to?(:cg_v234_destiny_bond?) &&
                  target.cg_v234_destiny_bond?
        if ALBERT_CG::UNIQUE_B_V234.active?
          ALBERT_CG::UNIQUE_B_V234.log(
            "TANKENTAI_ATTACK_TARGET attacker=" + attacker.name.to_s +
            " target=" + target.name.to_s +
            " hp=" + target.hp.to_i.to_s +
            " destiny=" + destiny.to_s)
        end
        watchers.push([target, target.hp.to_i]) if destiny
      end
    end

    result = cg_v234e_damage_action_destiny_bridge(action)

    if normal_attack && attacker != nil
      watchers.each do |entry|
        target = entry[0]
        hp_before = entry[1].to_i
        next if target == nil
        hp_after = target.hp.to_i
        destiny_after = target.respond_to?(:cg_v234_destiny_bond?) &&
                        target.cg_v234_destiny_bond?
        if ALBERT_CG::UNIQUE_B_V234.active?
          ALBERT_CG::UNIQUE_B_V234.log(
            "TANKENTAI_DESTINY_DAMAGE_CHECK target=" + target.name.to_s +
            " attacker=" + attacker.name.to_s +
            " hp_before=" + hp_before.to_s +
            " hp_after=" + hp_after.to_s +
            " attacker_hp=" + attacker.hp.to_i.to_s +
            " destiny=" + destiny_after.to_s)
        end
        if hp_before > 0 && hp_after <= 0 &&
           attacker.actor? != target.actor? &&
           attacker.hp.to_i > 0
          loss = attacker.hp.to_i
          attacker.hp = 0
          attacker.hp_damage = loss if attacker.respond_to?(:hp_damage=)
          ALBERT_CG::UNIQUE_B_V234.note_destiny_ko(target, attacker)
          ALBERT_CG::UNIQUE_B_V234.log(
            "DESTINY_BOND_KO_TANKENTAI target=" + target.name.to_s +
            " attacker=" + attacker.name.to_s +
            " attacker_loss=" + loss.to_s)
          target.cg_v234_clear_destiny_bond if target.respond_to?(:cg_v234_clear_destiny_bond)
        end
      end
    end
    return result
  end

  alias cg_v234_start start
  def start
    ALBERT_CG::UNIQUE_B_V234.reset_battle_memory unless ALBERT_CG::UNIQUE_B_V234.active?
    cg_v234_start
  end

  alias cg_v234_execute_action execute_action
  def execute_action
    battler = @active_battler
    if battler != nil
      ALBERT_CG::UNIQUE_B_V234.prepare_runtime_action(battler)
      ALBERT_CG::UNIQUE_B_V234.record_execution(battler) if ALBERT_CG::UNIQUE_B_V234.active?
    end
    action = battler == nil ? nil : battler.action
    executed_mid = action != nil && action.skill? ? ALBERT_CG::MOVE_EFFECT.move_id(action.skill) : 0
    valid_before = action != nil && action.valid?
    begin
      cg_v234_execute_action
    ensure
      ALBERT_CG::UNIQUE_B_V234.finish_runtime_action(battler, executed_mid, valid_before) if battler != nil
    end
  end

  alias cg_v234_turn_end turn_end
  def turn_end
    list = []
    list.concat($game_party.members) if $game_party != nil
    list.concat($game_troop.members) if $game_troop != nil
    list.each { |b| b.cg_v234_tick_restrictions if b != nil && b.respond_to?(:cg_v234_tick_restrictions) }
    ALBERT_CG::UNIQUE_B_V234.tick_delayed_events
    ALBERT_CG::UNIQUE_B_V234.finish_round_assertions if ALBERT_CG::UNIQUE_B_V234.active?
    cg_v234_turn_end
  end

  alias cg_v234_start_party_command start_party_command_selection
  def start_party_command_selection
    unless ALBERT_CG::UNIQUE_B_V234.active?
      return cg_v234_start_party_command
    end
    cg_v234_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::UNIQUE_B_V234.assert_bootstrap_once
    if ALBERT_CG::UNIQUE_B_V234.finished?
      ALBERT_CG::UNIQUE_B_V234.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::UNIQUE_B_V234.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ F11：最新版 AutoRegression 唯一快捷鍵
#------------------------------------------------------------------------------
# 【機制】
#  v2.3.4f 延續不再堆疊 Shift/Ctrl/Alt 組合鍵的政策。此頁載入在舊測試器之後，
#  因此直接關閉舊測試器的 F11 family trigger；舊 harness 本體與 start 方法仍保留。
#  Scene_Map 最外層只偵測一次 F11 邊緣，啟動目前最新版 Unique Batch B。
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    def self.f11_trigger?
      return false
    end
    def self.shift_f11_trigger?
      return false
    end
  end

  module ACTION_PRIORITY
    def self.ctrl_f11_trigger?
      return false
    end
  end

  module FIELD_TEST_V233
    def self.alt_f11_trigger?
      return false
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v234b_scene_map_update update
  def update
    cg_v234b_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::UNIQUE_B_V234.f11_trigger?
      Sound.play_decision
      ALBERT_CG::UNIQUE_B_V234.start_auto_test
    end
  end
end

#==============================================================================
# ■ Coverage：v2.3.4 Batch B 正式分類
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    class << self
      alias cg_v234_coverage_v231 coverage_v231
    end
    def self.coverage_v231(move_id)
      return "V234_UNIQUE_B_HANDLED" if ALBERT_CG::UNIQUE_B_V234.handled?(move_id)
      return cg_v234_coverage_v231(move_id)
    end
  end
end
