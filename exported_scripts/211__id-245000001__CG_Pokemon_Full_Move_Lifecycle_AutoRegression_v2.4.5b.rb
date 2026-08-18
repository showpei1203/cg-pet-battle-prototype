# RMVX_SCRIPT_INDEX: 211
# RMVX_SCRIPT_ID: 245000001
# RMVX_SCRIPT_NAME: CG Pokemon Full Move Lifecycle AutoRegression v2.4.5b
# RMVX_SOURCE_SHA256: eafc6f236684b885a5eceeba5381759ec938e82060a05179b1589b0ed4138278

#==============================================================================
# ■ CG Pokemon Full Move Lifecycle AutoRegression v2.4.5b
#------------------------------------------------------------------------------
# 【用途】
#  在 937 / 937 Move Coverage、UNIQUE_EXPLICIT_PENDING=0 之後，執行正式的
#  Full Move Lifecycle Release Gate。此腳本不新增 Move 規則，也不重新實作任何
#  已封版 Batch；它只負責把既有 deterministic Scene_Battle regression 依序串起來，
#  驗證所有 Move Runtime 在「同一份完整整合基底、連續多場戰鬥、反覆回 Map」的
#  lifecycle 下仍然成立。
#
# 【測試順序】
#   01 Priority / Protect v2.3.2c
#   02 Field Core v2.3.3a
#   03 Force Switch / Hazard v2.3.5a
#   04 Unique Batch B v2.3.4g
#   05 Unique Batch C v2.3.6c
#   06 Unique Batch D v2.3.7a
#   07 Unique Batch E v2.3.8a
#   08 Unique Batch F v2.3.9a
#   09 Unique Batch G v2.4.0a
#   10 Unique Batch H v2.4.1b
#   11 Unique Batch I v2.4.2c
#   12 Unique Batch J v2.4.3
#   13 Unique Batch K v2.4.4a + Held Item
#
# 【機制規則】
#  1. F11 只啟動本最新版 Master Regression；舊 regression 保留 script-callable，
#     但其 F11 / Alt+F11 / Ctrl+F11 快捷觸發在本版停用。
#  2. 每個 Phase 都呼叫原本已封版的 start_auto_test / start / start_k_test，
#     因此仍是真正 Scene_Battle、真正 Action、真正 target / damage / switch lifecycle。
#  3. 每場 battle_end 回到 Scene_Map 後，Master 必須先確認 child harness 已停止，
#     再等待 COOLDOWN_FRAMES，且確認沒有 pending battle scene、玩家沒有移動，才啟動下一場。
#     這是針對 v2.4.4 曾發現的 J -> K 過快 scene handoff stall 所設計的隔離門。
#  4. 任一 Phase 有 ASSERT failure，Master 立即停止，不繼續污染後續 Phase。
#  5. Child harness 會各自保留原始專用 LOG；Master 最後會重建
#     CG_AutoRegression_LATEST.log，只列出 13 Phase 的 Release Gate 總結與失敗細節。
#  6. 本腳本不修改任何正式 Move、Held Item、Field、Priority、Switch、PMD Renderer 規則。
#  7. Unique Batch B v2.3.4g 的 Round1 Substitute 原測試雖固定命中，仍沿用正式
#     傷害亂數；兩次 Tackle 偶爾可能留下少量 shield，造成 Round2 Encore 被替身
#     正確阻擋而形成假 FAIL。v2.4.5b 透過獨立 test-only isolation，固定兩次
#     Substitute 承傷為「第一擊保留、第二擊恰好破裂」，正式 Batch B Runtime 不改。
#  8. Unique Batch F Syrup Bomb（903）維持 v2.4.5a 的 test-only 命中隔離：
#     Unique F Regression active 時 hit=100 / eva=0，正式 85% 命中率不改。
#  9. Batch K 舊 regression 的 Happy Hour 測試 troop 金錢基數為 0，雖可驗 flag，
#     但「0 x 2 = 0」不能證明獎金倍率。Master 在 K PASS 後追加 test-only positive-gold probe：
#     暫時把一名測試 Enemy 設為 KO 並給正數 Gold，確認 base > 0 且 Happy Hour 後恰為 2 倍，
#     隨即恢復 HP / Gold / flag；此 probe 不寫入永久資料。
#
# 【主要設定項／可調參數】
#  COOLDOWN_FRAMES = 120：每兩場 Regression 間至少等待約 2 秒（60fps 假設）。
#  PHASE_KEYS / PHASE_NAMES：Release Gate 執行順序；除非有正式 Roadmap 變更，不應任意刪減。
#  VK_F11 = 0x7A：最新版 F11 啟動鍵。
#
# 【事件／腳本呼叫方式】
#  地圖按 F11：自動呼叫 ALBERT_CG::FULL_MOVE_LIFECYCLE_V245.start_full_test
#  事件「腳本」也可直接呼叫：
#    ALBERT_CG::FULL_MOVE_LIFECYCLE_V245.start_full_test
#
# 【實際範例】
#  例 1：F11 後會從 Priority 開始，第一場結束回 Map，Master 等待 120 frames，
#        再自動啟動 Field；如此一路跑到 Batch K。
#  例 2：若 Batch H 出現 1 個 failure，Master 停在 Phase H，不再啟動 I/J/K，
#        最後 LATEST 會寫 PHASE H RESULT=FAIL 與 child failure detail。
#  例 3：全部通過時最後必須看到：
#        RESULT=PASS
#        SUMMARY phases=13/13 failures=0 transition_checks=13 release_probes=1 pending=0
#
# 【重要】
#  本版只有在使用者的 RPG Maker VX Windows 實機跑出上述 RESULT=PASS 後，
#  才能宣稱 Full Move Lifecycle Release Gate PASS；靜態語法與 Coverage 歸零不等於 Runtime PASS。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_FullMoveLifecycleAutoRegression"] = "2.4.5b"

module ALBERT_CG
  module FULL_MOVE_LIFECYCLE_V245
    VERSION = "2.4.5b"
    VK_F11 = 0x7A
    COOLDOWN_FRAMES = 120
    STATIC_PENDING = 0

    PHASE_KEYS = [
      :priority, :field, :force_switch,
      :batch_b, :batch_c, :batch_d, :batch_e, :batch_f,
      :batch_g, :batch_h, :batch_i, :batch_j, :batch_k
    ]

    PHASE_NAMES = {
      :priority=>"Priority_Protect_v2.3.2c",
      :field=>"Field_Core_v2.3.3a",
      :force_switch=>"ForceSwitch_Hazard_v2.3.5a",
      :batch_b=>"Unique_B_v2.3.4g",
      :batch_c=>"Unique_C_v2.3.6c",
      :batch_d=>"Unique_D_v2.3.7a",
      :batch_e=>"Unique_E_v2.3.8a",
      :batch_f=>"Unique_F_v2.3.9a",
      :batch_g=>"Unique_G_v2.4.0a",
      :batch_h=>"Unique_H_v2.4.1b",
      :batch_i=>"Unique_I_v2.4.2c",
      :batch_j=>"Unique_J_v2.4.3",
      :batch_k=>"Unique_K_HeldItem_v2.4.4a"
    }

    begin
      KEY_API = Win32API.new("user32", "GetAsyncKeyState", "i", "i")
    rescue
      KEY_API = nil
    end

    def self.project_root
      if defined?(ALBERT_CG::UNIQUE_K_V244) && ALBERT_CG::UNIQUE_K_V244.respond_to?(:project_root)
        return ALBERT_CG::UNIQUE_K_V244.project_root
      end
      return Dir.pwd
    rescue
      return Dir.pwd
    end

    def self.log_path
      return File.join(project_root, "Pokemon_FullMoveLifecycle_AutoTest_v2_4_5b.log")
    end

    def self.latest_log_path
      return File.join(project_root, "CG_AutoRegression_LATEST.log")
    end

    def self.write_line(path, text, mode="ab")
      File.open(path, mode) { |f| f.write(text.to_s + "\r\n") }
      return true
    rescue
      return false
    end

    def self.log(text)
      write_line(log_path, text.to_s)
      if defined?(ALBERT_CG::PMD_INIT_TRACE) && ALBERT_CG::PMD_INIT_TRACE.respond_to?(:log)
        line = text.to_s
        if line.index("MASTER_") == 0 || line.index("PHASE ") == 0 ||
           line.index("RESULT=") == 0 || line.index("SUMMARY ") == 0 ||
           line.index("FAILURE ") == 0
          ALBERT_CG::PMD_INIT_TRACE.log("[FULL_MOVE_LIFECYCLE] " + line)
        end
      end
    rescue
    end

    def self.reset_log
      header = [
        "CG POKEMON FULL MOVE LIFECYCLE AUTO REGRESSION v" + VERSION,
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        "RULE=13 accepted deterministic Scene_Battle regressions; serial Map cooldown gate; stop on first failure",
        "BASELINE=v2.4.4a Move 937 PASS; pending=0",
        "REGRESSION_ISOLATION=Unique_B Substitute damage fixed for 2-hit break; Unique_F SyrupBomb(903) hit=100 eva=0; formal Batch B/F runtime unchanged",
        "COOLDOWN_FRAMES=" + COOLDOWN_FRAMES.to_s,
        "------------------------------------------------------------"
      ]
      File.open(log_path, "wb") { |f| header.each { |x| f.write(x + "\r\n") } }
      File.open(latest_log_path, "wb") { |f| header.each { |x| f.write(x + "\r\n") } }
    rescue
    end

    def self.copy_master_to_latest
      data = ""
      File.open(log_path, "rb") { |f| data = f.read }
      File.open(latest_log_path, "wb") { |f| f.write(data) }
      return true
    rescue
      return false
    end

    def self.key_down?
      return false if KEY_API == nil
      return (KEY_API.call(VK_F11) & 0x8000) != 0
    rescue
      return false
    end

    def self.f11_trigger?
      down = key_down?
      trigger = down && @f11_down != true
      @f11_down = down
      return trigger
    rescue
      return false
    end

    def self.active?
      return @active == true
    end

    def self.phase_key
      return PHASE_KEYS[@phase_index.to_i]
    end

    def self.phase_name(key=nil)
      key = phase_key if key == nil
      return key == nil ? "NONE" : PHASE_NAMES[key].to_s
    end

    def self.phase_module(key)
      case key
      when :priority
        return defined?(ALBERT_CG::ACTION_PRIORITY) ? ALBERT_CG::ACTION_PRIORITY : nil
      when :field
        return defined?(ALBERT_CG::FIELD_TEST_V233) ? ALBERT_CG::FIELD_TEST_V233 : nil
      when :force_switch
        return defined?(ALBERT_CG::FORCE_SWITCH_V235) ? ALBERT_CG::FORCE_SWITCH_V235 : nil
      when :batch_b
        return defined?(ALBERT_CG::UNIQUE_B_V234) ? ALBERT_CG::UNIQUE_B_V234 : nil
      when :batch_c
        return defined?(ALBERT_CG::UNIQUE_C_V236) ? ALBERT_CG::UNIQUE_C_V236 : nil
      when :batch_d
        return defined?(ALBERT_CG::UNIQUE_D_V237) ? ALBERT_CG::UNIQUE_D_V237 : nil
      when :batch_e
        return defined?(ALBERT_CG::UNIQUE_E_V238) ? ALBERT_CG::UNIQUE_E_V238 : nil
      when :batch_f
        return defined?(ALBERT_CG::UNIQUE_F_V239) ? ALBERT_CG::UNIQUE_F_V239 : nil
      when :batch_g
        return defined?(ALBERT_CG::UNIQUE_G_V240) ? ALBERT_CG::UNIQUE_G_V240 : nil
      when :batch_h
        return defined?(ALBERT_CG::UNIQUE_H_V241) ? ALBERT_CG::UNIQUE_H_V241 : nil
      when :batch_i
        return defined?(ALBERT_CG::UNIQUE_I_V242) ? ALBERT_CG::UNIQUE_I_V242 : nil
      when :batch_j
        return defined?(ALBERT_CG::UNIQUE_J_V243) ? ALBERT_CG::UNIQUE_J_V243 : nil
      when :batch_k
        return defined?(ALBERT_CG::UNIQUE_K_V244) ? ALBERT_CG::UNIQUE_K_V244 : nil
      end
      return nil
    rescue
      return nil
    end

    def self.child_active?(mod)
      return false if mod == nil
      return mod.active? if mod.respond_to?(:active?)
      return mod.instance_variable_get(:@active) == true
    rescue
      return false
    end

    def self.failure_count(mod)
      return 1 if mod == nil
      value = mod.instance_variable_get(:@failures)
      return value.size if value.is_a?(Array)
      return value.to_i if value != nil
      if mod.respond_to?(:failures)
        value = mod.failures
        return value.size if value.is_a?(Array)
        return value.to_i if value != nil
      end
      return 0
    rescue
      return 1
    end

    def self.failure_details(mod)
      lines = []
      return ["child module missing"] if mod == nil
      value = mod.instance_variable_get(:@failures)
      if value.is_a?(Array)
        for x in value
          lines.push(x.to_s)
        end
      elsif value != nil && value.to_i > 0
        detail = mod.instance_variable_get(:@failure_lines)
        if detail.is_a?(Array) && !detail.empty?
          for x in detail
            lines.push(x.to_s)
          end
        else
          lines.push("child failure_count=" + value.to_i.to_s)
        end
      end
      extra = mod.instance_variable_get(:@failure_lines)
      if extra.is_a?(Array)
        for x in extra
          text = x.to_s
          lines.push(text) unless lines.include?(text)
        end
      end
      return lines
    rescue
      return ["failure detail read error"]
    end

    def self.start_child(key)
      mod = phase_module(key)
      raise "missing module " + phase_name(key) if mod == nil
      case key
      when :priority
        return mod.start_auto_test
      when :field
        return mod.start
      when :force_switch
        return mod.start_auto_test
      when :batch_b, :batch_c, :batch_d, :batch_e, :batch_f,
           :batch_g, :batch_h, :batch_i, :batch_j
        return mod.start_auto_test
      when :batch_k
        return mod.start_k_test
      end
      raise "unknown phase " + key.to_s
    end

    def self.map_stable?
      return false if $game_temp == nil || $game_temp.in_battle
      return false if $game_temp.next_scene.to_s == "battle"
      if $game_player != nil && $game_player.respond_to?(:moving?)
        return false if $game_player.moving?
      end
      return true
    rescue
      return false
    end


    def self.happy_hour_positive_gold_probe_in_battle
      troop = $game_troop
      return [false,"Game_Troop missing"] if troop == nil
      return [false,"Happy Hour authority missing"] unless troop.respond_to?(:cg_v244_gold_total_without_happy) && troop.respond_to?(:cg_happy_hour_active?)
      return [false,"Happy Hour flag not active"] unless troop.cg_happy_hour_active?
      members = troop.members
      enemy = members == nil ? nil : members[0]
      return [false,"test enemy missing"] if enemy == nil || !enemy.respond_to?(:enemy_id)
      data = $data_enemies[enemy.enemy_id]
      return [false,"enemy data missing"] if data == nil
      old_hp = enemy.hp
      old_gold = data.gold
      begin
        data.gold = 123
        enemy.hp = 0
        base = troop.cg_v244_gold_total_without_happy.to_i
        actual = troop.gold_total.to_i
        ok = base > 0 && actual == base * 2
        return [ok,"base=" + base.to_s + " actual=" + actual.to_s]
      rescue => e
        return [false,e.class.to_s + ":" + e.message.to_s]
      ensure
        begin
          enemy.hp = old_hp
          data.gold = old_gold
        rescue
        end
      end
    end

    def self.start_current_phase
      key = phase_key
      return finish_master if key == nil
      @phase_started = true
      @phase_started_at = Time.now
      log("PHASE " + (@phase_index.to_i + 1).to_s + "/" + PHASE_KEYS.size.to_s +
          " START " + phase_name(key))
      begin
        start_child(key)
      rescue => e
        @master_failures.push("START_ERROR " + phase_name(key) + " " + e.class.to_s + ":" + e.message.to_s)
        log("PHASE " + phase_name(key) + " START_ERROR " + e.class.to_s + ":" + e.message.to_s)
        finish_master
      end
    end

    def self.record_phase_result
      key = phase_key
      mod = phase_module(key)
      fail_count = failure_count(mod)
      duration = @phase_started_at == nil ? 0 : (Time.now - @phase_started_at).to_i
      @transition_checks = @transition_checks.to_i + 1
      stable = map_stable?
      unless stable
        fail_count += 1
        @master_failures.push("MAP_TRANSITION_NOT_STABLE " + phase_name(key))
      end
      result = fail_count <= 0 ? "PASS" : "FAIL"
      log("PHASE " + (@phase_index.to_i + 1).to_s + "/" + PHASE_KEYS.size.to_s +
          " RESULT=" + result + " name=" + phase_name(key) +
          " child_failures=" + fail_count.to_s + " duration_s=" + duration.to_s +
          " map_stable=" + stable.to_s)
      if fail_count > 0
        details = failure_details(mod)
        for x in details
          @master_failures.push(phase_name(key) + " :: " + x.to_s)
          log("FAILURE " + phase_name(key) + " :: " + x.to_s)
        end
        finish_master
        return false
      end
      @phase_results.push([key, duration])
      @phase_index = @phase_index.to_i + 1
      @phase_started = false
      @phase_started_at = nil
      @cooldown = COOLDOWN_FRAMES
      if @phase_index.to_i >= PHASE_KEYS.size
        finish_master
      else
        log("MASTER_COOLDOWN next=" + phase_name + " frames=" + COOLDOWN_FRAMES.to_s)
      end
      return true
    end

    def self.finish_master
      return unless @active == true
      passed = @master_failures.empty? && @phase_results.size == PHASE_KEYS.size
      log("------------------------------------------------------------")
      log("RESULT=" + (passed ? "PASS" : "FAIL"))
      log("SUMMARY phases=" + @phase_results.size.to_s + "/" + PHASE_KEYS.size.to_s +
          " failures=" + @master_failures.size.to_s +
          " transition_checks=" + @transition_checks.to_i.to_s +
          " release_probes=" + @release_probe_checks.to_i.to_s +
          " pending=" + STATIC_PENDING.to_s)
      unless @master_failures.empty?
        @master_failures.each_with_index do |x,i|
          log("FAILURE " + (i+1).to_s + " " + x.to_s)
        end
      end
      @active = false
      @phase_started = false
      copy_master_to_latest
      return passed
    rescue
      @active = false
      copy_master_to_latest
      return false
    end

    def self.update_from_map
      return unless @active == true
      return if $game_temp == nil || $game_temp.in_battle
      if @phase_started == true
        mod = phase_module(phase_key)
        return if child_active?(mod)
        # Child 已 finish_suite，但 Scene_Map 剛建立的第一幀仍可能殘留 scene request。
        # 不把這種瞬間狀態誤判為 lifecycle FAIL；等 Map 真正穩定後才結算 Phase。
        return unless map_stable?
        record_phase_result
        return
      end
      return if @phase_index.to_i >= PHASE_KEYS.size
      if @cooldown.to_i > 0
        @cooldown = @cooldown.to_i - 1
        return
      end
      return unless map_stable?
      start_current_phase
    rescue => e
      @master_failures = [] if @master_failures == nil
      @master_failures.push("MASTER_UPDATE_ERROR " + e.class.to_s + ":" + e.message.to_s)
      log("MASTER_UPDATE_ERROR " + e.class.to_s + ":" + e.message.to_s)
      finish_master
    end

    def self.start_full_test
      return false if @active == true
      reset_log
      @active = true
      @phase_index = 0
      @phase_started = false
      @phase_started_at = nil
      @phase_results = []
      @master_failures = []
      @transition_checks = 0
      @release_probe_checks = 0
      @cooldown = 0
      log("MASTER_START phases=" + PHASE_KEYS.size.to_s + " pending=" + STATIC_PENDING.to_s)
      log("MASTER_PHASE_ORDER " + PHASE_KEYS.map { |x| phase_name(x) }.join(" -> "))
      start_current_phase
      return true
    rescue => e
      @active = false
      write_line(latest_log_path, "MASTER_START_ERROR " + e.class.to_s + ":" + e.message.to_s)
      return false
    end
  end
end

#==============================================================================
# ■ 舊 Regression 快捷鍵停用
#------------------------------------------------------------------------------
#  舊 harness 仍可由 start_auto_test / start / start_k_test 直接呼叫；只是它們不再
#  擁有 F11 系列快捷鍵。最新版 F11 永遠只屬於 Full Move Lifecycle v2.4.5。
#==============================================================================
module ALBERT_CG
  if defined?(ACTION_PRIORITY)
    module ACTION_PRIORITY
      def self.ctrl_f11_trigger?; return false; end
    end
  end
  if defined?(FIELD_TEST_V233)
    module FIELD_TEST_V233
      def self.alt_f11_trigger?; return false; end
    end
  end
  if defined?(FORCE_SWITCH_V235)
    module FORCE_SWITCH_V235
      def self.f11_trigger?; return false; end
    end
  end
  if defined?(UNIQUE_B_V234)
    module UNIQUE_B_V234
      def self.f11_trigger?; return false; end
    end
  end
  if defined?(UNIQUE_C_V236)
    module UNIQUE_C_V236
      def self.f11_trigger?; return false; end
    end
  end
  if defined?(UNIQUE_D_V237)
    module UNIQUE_D_V237
      def self.f11_trigger?; return false; end
    end
  end
  if defined?(UNIQUE_E_V238)
    module UNIQUE_E_V238
      def self.f11_trigger?; return false; end
    end
  end
  if defined?(UNIQUE_F_V239)
    module UNIQUE_F_V239
      def self.f11_trigger?; return false; end
    end
  end
  if defined?(UNIQUE_G_V240)
    module UNIQUE_G_V240
      def self.f11_trigger?; return false; end
    end
  end
  if defined?(UNIQUE_H_V241)
    module UNIQUE_H_V241
      def self.f11_trigger?; return false; end
    end
  end
  if defined?(UNIQUE_I_V242)
    module UNIQUE_I_V242
      def self.f11_trigger?; return false; end
    end
  end
  if defined?(UNIQUE_J_V243)
    module UNIQUE_J_V243
      def self.f11_trigger?; return false; end
    end
  end
  if defined?(UNIQUE_K_V244)
    module UNIQUE_K_V244
      def self.f11_trigger?; return false; end
    end
  end
end

#==============================================================================
# ■ Batch K Release Probe：Happy Hour 正數 Gold 實證
#------------------------------------------------------------------------------
#  v2.4.4a 原 regression troop 的實際 Gold base=0，因此 0*2=0 雖通過數學式，
#  不能充分證明倍率。只有 Full Lifecycle Master active 時，在 K Round 4 的所有正式
#  Action/ASSERT 完成後、turn_end/battle_end 前，暫時把一名 Enemy 設為 KO 並給 123 Gold，
#  驗證底層 base > 0 且 Happy Hour gold_total == base*2，隨即恢復測試資料。
#==============================================================================
if defined?(ALBERT_CG::UNIQUE_K_V244)
  module ALBERT_CG
    module UNIQUE_K_V244
      class << self
        alias cg_v245_full_lifecycle_finish_round_assertions finish_round_assertions
        def finish_round_assertions
          round_before = current_round
          result = cg_v245_full_lifecycle_finish_round_assertions
          if round_before.to_i == 4 &&
             defined?(ALBERT_CG::FULL_MOVE_LIFECYCLE_V245) &&
             ALBERT_CG::FULL_MOVE_LIFECYCLE_V245.active?
            probe = ALBERT_CG::FULL_MOVE_LIFECYCLE_V245.happy_hour_positive_gold_probe_in_battle
            ALBERT_CG::FULL_MOVE_LIFECYCLE_V245.instance_variable_set(:@release_probe_checks,
              ALBERT_CG::FULL_MOVE_LIFECYCLE_V245.instance_variable_get(:@release_probe_checks).to_i + 1)
            if probe[0]
              ALBERT_CG::FULL_MOVE_LIFECYCLE_V245.log("MASTER_PROBE PASS HappyHour positive gold " + probe[1].to_s)
            else
              @failures = [] if @failures == nil
              @failures.push("HappyHour positive-gold release probe " + probe[1].to_s)
              ALBERT_CG::FULL_MOVE_LIFECYCLE_V245.log("MASTER_PROBE FAIL HappyHour positive gold " + probe[1].to_s)
            end
          end
          return result
        end
      end
    end
  end
end

#==============================================================================
# ■ Scene_Map：最新版唯一 F11 Master Runner
#==============================================================================
class Scene_Map < Scene_Base
  alias cg_v245_full_move_lifecycle_update update
  def update
    cg_v245_full_move_lifecycle_update
    if defined?(ALBERT_CG::FULL_MOVE_LIFECYCLE_V245)
      master = ALBERT_CG::FULL_MOVE_LIFECYCLE_V245
      if master.active?
        master.update_from_map
      elsif !$game_temp.in_battle && master.f11_trigger?
        Sound.play_decision
        master.start_full_test
      end
    end
  end
end
