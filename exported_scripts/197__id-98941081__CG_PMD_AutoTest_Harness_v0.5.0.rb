# RMVX_SCRIPT_INDEX: 197
# RMVX_SCRIPT_ID: 98941081
# RMVX_SCRIPT_NAME: CG PMD AutoTest Harness v0.5.0
# RMVX_SOURCE_SHA256: 6039e8116d014b160b135566d8a1473ee893c32e9883b186284871e4454431c8

#==============================================================================
# ■ CG_PMD_AutoTest_Harness_v0_4_0
#------------------------------------------------------------------------------
# 【用途】
#  PMD 0001～0026 專用自動測試／LOG 記錄工具。
#  本腳本只服務開發測試，不改動正式物種、捕捉、配種、進化資料。
#
# 【放置位置】
#  必須放在：
#    CG_PMD_Config / AnimData / Identity / Core / Tankentai Bridge / Action Setup
#  以及其他 CG 戰鬥補丁之下，Main 之前。
#
# 【地圖快捷鍵】
#  F6：維持既有正常 DEMO_TROOP_ID 戰鬥，不啟動 Sprite key 覆寫。
#      用來驗證正式 Species/Clone/Enemy/進化身分鏈是否真的能取得 PMD。
#  Shift + F6：進入同一場戰鬥，但武裝 PMD 0001～0026 自動巡檢。
#      系統會把戰場上的「3 隻我方寵物＋4 隻敵人」暫時換成 0001～0026，
#      分批播放核心動作；只供素材與 Renderer 壓力測試。
#
# 【戰鬥中快捷鍵】
#  F6：從 0001 重新執行整套自動測試。
#  F8：結束測試戰並回到地圖。
#  F9：立即把目前所有測試 Sprite 的狀態寫入 LOG。
#
# 【自動測試內容】
#  1. 確認 CG_PMD::DATA 內含 0001～0026。
#  2. 確認每隻所有編譯動作所引用的 *-Anim.png 都存在。
#  3. 確認 Idle / Attack / Shoot / Charge / Hurt / Faint 可直接取得或 fallback。
#  4. 確認 PMD Tankentai Bridge 的 N01::ANIME / N01::ACTION 測試設定存在。
#  5. 真正進入 Scene_Battle，使用 Sprite_Battler / CG_PMD::Playback 播放：
#       Idle → Attack → Shoot → Charge → Hurt → Faint → Idle
#  6. 同時覆蓋 Actor side 與 Enemy side，以驗證方向、mirror、anchor 與逐格播放。
#  7. 記錄每次播放的 source、frame 數、方向列、anchor、Rush/Hit/Return frame。
#  8. CG_PMD.warn_once 發出的缺檔／缺動作警告也會同步寫入 LOG。
#
# 【LOG】
#  遊戲根目錄：PMD_AutoTest.log
#  每次由地圖按 Shift+F6 或自動測試戰中按 F6 都會重建 LOG。
#
# 【判讀】
#  PREFLIGHT_FATAL > 0：結構性錯誤，通常是資料或 PNG 缺失。
#  FALLBACK：不一定是錯誤，代表該寶可夢沒有指定動作，使用既定替代動作。
#  RUNTIME_ERROR：執行期錯誤，LOG 會附 exception 與 backtrace。
#  AUTO TEST COMPLETE：自動流程跑完；視覺位置／方向仍需人工目視確認。
#
# 【注意】
#  - 測試覆寫只存在於目前戰鬥的 Game_Battler instance variable。
#  - 結束測試時會清掉覆寫，不會把 0001～0026 寫回正式物種資料。
#  - 不使用 Shadow；Offsets 仍只屬於編譯期定位參考。
#==============================================================================

$imported = {} if $imported == nil
$imported["CG_PMD_AutoTest_Harness"] = "0.4.0"

module CG_PMD_TEST
  VERSION = "0.4.0"
  LOG_FILE = "PMD_AutoTest.log"
  FIRST_SPECIES = 1
  LAST_SPECIES = 26
  CORE_ACTIONS = ["Idle", "Attack", "Shoot", "Charge", "Hurt", "Faint"]
  VISUAL_ACTIONS = ["Idle", "Attack", "Shoot", "Charge", "Hurt", "Faint"]
  IDLE_PREVIEW_FRAMES = 48
  ACTION_TIMEOUT_FRAMES = 360
  BATCH_SETTLE_FRAMES = 18

  @armed = false
  @active = false
  @log_ready = false
  @fatal_count = 0
  @warning_count = 0
  @fallback_count = 0
  @runtime_error_count = 0
  @session_started_at = nil

  def self.armed?
    return @armed ? true : false
  end

  def self.active?
    return @active ? true : false
  end

  def self.logging?
    return @log_ready ? true : false
  end

  def self.arm!
    @armed = true
  end

  def self.consume_arm!
    value = @armed
    @armed = false
    return value
  end

  def self.reset_counters
    @fatal_count = 0
    @warning_count = 0
    @fallback_count = 0
    @runtime_error_count = 0
  end

  def self.start_log
    reset_counters
    @session_started_at = Time.now
    begin
      File.open(LOG_FILE, "wb") do |file|
        file.write("PMD AUTO TEST LOG v" + VERSION + "\r\n")
        file.write("START=" + @session_started_at.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
        file.write("PROJECT=" + ($data_system == nil ? "?" : $data_system.game_title.to_s) + "\r\n")
        file.write("RANGE=0001-0026\r\n")
        file.write("------------------------------------------------------------\r\n")
      end
      @log_ready = true
    rescue
      @log_ready = false
    end
  end

  def self.log(text)
    return unless @log_ready
    line = "[" + Time.now.strftime("%H:%M:%S") + "] " + text.to_s
    begin
      File.open(LOG_FILE, "ab") { |file| file.write(line + "\r\n") }
    rescue
    end
  end

  def self.fatal(text)
    @fatal_count += 1
    log("FATAL " + text.to_s)
  end

  def self.warning(text)
    @warning_count += 1
    log("WARN " + text.to_s)
  end

  def self.fallback(text)
    @fallback_count += 1
    log("FALLBACK " + text.to_s)
  end

  def self.runtime_error(error, where = "runtime")
    @runtime_error_count += 1
    log("RUNTIME_ERROR where=" + where.to_s + " class=" + error.class.to_s + " msg=" + error.message.to_s)
    if error.respond_to?(:backtrace) && error.backtrace != nil
      error.backtrace[0, 12].each { |line| log("  " + line.to_s) }
    end
  end

  def self.key_for(number)
    return sprintf("%04d", number.to_i)
  end

  def self.png_path(key, source)
    return CG_PMD::ROOT + key.to_s + "/" + source.to_s + "-Anim.png"
  end

  def self.preflight
    log("PREFLIGHT_BEGIN")
    unless defined?(CG_PMD) && defined?(CG_PMD::DATA)
      fatal("CG_PMD::DATA not loaded")
      return false
    end

    total_sources = 0
    missing_sources = 0
    species_ok = 0

    for number in FIRST_SPECIES..LAST_SPECIES
      key = key_for(number)
      sprite = CG_PMD.sprite_data(key)
      if sprite == nil
        fatal("missing DATA key=" + key)
        next
      end
      actions = sprite[:actions] || {}
      if actions.empty?
        fatal("no actions key=" + key)
        next
      end
      species_ok += 1

      sources = {}
      actions.each_value do |meta|
        source = meta[:source]
        next if source == nil || source.to_s.empty?
        sources[source.to_s] = true
        if meta[:frame_width].to_i <= 0 || meta[:frame_height].to_i <= 0 ||
           meta[:frame_count].to_i <= 0 || meta[:direction_count].to_i <= 0
          fatal("invalid geometry key=" + key + " source=" + source.to_s)
        end
      end

      sources.keys.each do |source|
        total_sources += 1
        path = png_path(key, source)
        unless FileTest.exist?(path)
          missing_sources += 1
          fatal("missing PNG " + path)
        end
      end

      CORE_ACTIONS.each do |wanted|
        resolved = CG_PMD.resolve_action(key, wanted)
        if resolved == nil
          fatal("cannot resolve key=" + key + " action=" + wanted)
          next
        end
        actual = resolved[0].to_s
        meta = resolved[1]
        if actual != wanted
          fallback("key=" + key + " wanted=" + wanted + " actual=" + actual)
        end
        source = meta[:source].to_s
        unless FileTest.exist?(png_path(key, source))
          fatal("core action PNG missing key=" + key + " wanted=" + wanted + " source=" + source)
        end
      end
    end

    if defined?(N01)
      anime_ok = defined?(N01::ANIME) && N01::ANIME["PMD_ATTACK_HIT"] != nil
      action_ok = defined?(N01::ACTION) && N01::ACTION["CG_PMD_TEST_ATTACK"] != nil
      fatal("N01::ANIME PMD_ATTACK_HIT missing") unless anime_ok
      fatal("N01::ACTION CG_PMD_TEST_ATTACK missing") unless action_ok
      log("SBS_BRIDGE anime=" + anime_ok.to_s + " action=" + action_ok.to_s)
    if defined?(CG_PMD::LOCK_BATTLE_VIEW_45)
      ally_view = CG_PMD::BATTLE_ALLY_VIEW
      enemy_view = CG_PMD::BATTLE_ENEMY_VIEW
      log("BATTLE_45 lock=" + CG_PMD::LOCK_BATTLE_VIEW_45.to_s +
          " ally=" + ally_view.to_s +
          " ally_row=" + CG_PMD.row_for("0001", ally_view, 8).to_s +
          " enemy=" + enemy_view.to_s +
          " enemy_row=" + CG_PMD.row_for("0001", enemy_view, 8).to_s +
          " mirror=false")
      fatal("battle 45 degree config invalid") unless CG_PMD::LOCK_BATTLE_VIEW_45 &&
        ally_view == :front_left && enemy_view == :front_right
    end
    else
      fatal("N01 not loaded")
    end

    if defined?(ALBERT_CG::SPECIES26)
      formal_ok = 0
      for number in FIRST_SPECIES..LAST_SPECIES
        actor_id = ALBERT_CG::SPECIES26.actor_id_for_dex(number)
        key = ALBERT_CG::SPECIES26.pmd_key_for_dex(number)
        if actor_id > 0 && CG_PMD::SPECIES_SPRITES[actor_id].to_s == key.to_s
          formal_ok += 1
        else
          fatal("formal species mapping mismatch dex=" + number.to_s + " actor=" + actor_id.to_s + " key=" + key.to_s)
        end
      end
      log("FORMAL_SPECIES_MAP ok=" + formal_ok.to_s + "/26")
    else
      warning("ALBERT_CG::SPECIES26 not loaded; visual-only test mode")
    end

    log("PREFLIGHT_SUMMARY species_ok=" + species_ok.to_s + "/26" +
        " sources=" + total_sources.to_s +
        " missing_sources=" + missing_sources.to_s +
        " fatal=" + @fatal_count.to_s +
        " fallback=" + @fallback_count.to_s)
    log("PREFLIGHT_END")
    return @fatal_count == 0
  rescue => error
    runtime_error(error, "preflight")
    return false
  end

  def self.begin_session
    start_log
    @active = true
    log("AUTO_TEST_SESSION_BEGIN")
    ok = preflight
    log("PREFLIGHT_RESULT=" + (ok ? "PASS" : "FAIL"))
    return ok
  end

  def self.finish_session
    log("AUTO TEST COMPLETE fatal=" + @fatal_count.to_s +
        " warn=" + @warning_count.to_s +
        " fallback=" + @fallback_count.to_s +
        " runtime_error=" + @runtime_error_count.to_s)
    @active = false
  end

  def self.summary_text
    return "fatal #{ @fatal_count } / warn #{ @warning_count } / fallback #{ @fallback_count } / runtime #{ @runtime_error_count }"
  end

  def self.slot_label(sprite)
    return "nil" if sprite == nil || sprite.battler == nil
    battler = sprite.battler
    side = battler.actor? ? "ALLY" : "ENEMY"
    name = battler.respond_to?(:name) ? battler.name.to_s : "?"
    return side + ":" + name
  end

  def self.log_sprite(sprite, prefix = "SPRITE")
    return if sprite == nil
    battler = sprite.battler
    key = battler == nil ? nil : battler.cg_pmd_sprite_key
    playback = sprite.instance_variable_get(:@cg_pmd_playback)
    if playback == nil
      log(prefix + " slot=" + slot_label(sprite) + " key=" + key.to_s + " playback=nil")
      return
    end
    meta = playback.meta || {}
    effective_view = playback.view
    begin
      effective_view = sprite.cg_pmd_effective_view if sprite.respond_to?(:cg_pmd_effective_view)
    rescue
    end
    row = CG_PMD.row_for(key, effective_view, meta[:direction_count].to_i)
    log(prefix + " slot=" + slot_label(sprite) +
        " key=" + key.to_s +
        " action=" + playback.action_name.to_s +
        " frame=" + playback.frame_index.to_s + "/" + meta[:frame_count].to_i.to_s +
        " requested_view=" + playback.view.to_s +
        " effective_view=" + effective_view.to_s +
        " row=" + row.to_i.to_s +
        " mirror=" + sprite.mirror.to_s +
        " xy=" + sprite.x.to_i.to_s + "," + sprite.y.to_i.to_s +
        " anchor=" + meta[:anchor_x].to_i.to_s + "," + meta[:anchor_y].to_i.to_s +
        " src=" + meta[:source].to_s)
  end
end

#------------------------------------------------------------------------------
# ■ 測試期 PMD key 覆寫
#------------------------------------------------------------------------------
class Game_Battler
  attr_accessor :cg_pmd_test_sprite_key_override
end

class Game_Actor < Game_Battler
  alias cg_pmd_autotest_original_sprite_key cg_pmd_sprite_key
  def cg_pmd_sprite_key
    key = @cg_pmd_test_sprite_key_override
    return key.to_s unless key == nil || key.to_s.empty?
    return cg_pmd_autotest_original_sprite_key
  end
end

class Game_Enemy < Game_Battler
  alias cg_pmd_autotest_original_sprite_key cg_pmd_sprite_key
  def cg_pmd_sprite_key
    key = @cg_pmd_test_sprite_key_override
    return key.to_s unless key == nil || key.to_s.empty?
    return cg_pmd_autotest_original_sprite_key
  end
end

#------------------------------------------------------------------------------
# ■ 把 CG_PMD 警告同步寫入測試 LOG
#------------------------------------------------------------------------------
module CG_PMD
  class << self
    alias cg_pmd_autotest_original_warn_once warn_once
    def warn_once(key, text)
      CG_PMD_TEST.warning("CG_PMD_WARN key=" + key.inspect + " text=" + text.to_s) if CG_PMD_TEST.logging?
      cg_pmd_autotest_original_warn_once(key, text)
    end
  end
end

#------------------------------------------------------------------------------
# ■ Playback 里程碑 LOG
#------------------------------------------------------------------------------
class CG_PMD::Playback
  alias cg_pmd_autotest_original_start start
  def start(request, view, loop_value, mirror_mode)
    result = cg_pmd_autotest_original_start(request, view, loop_value, mirror_mode)
    @cg_pmd_autotest_seen_rush = false
    @cg_pmd_autotest_seen_hit = false
    @cg_pmd_autotest_seen_return = false
    @cg_pmd_autotest_seen_end = false
    if CG_PMD_TEST.active?
      if result && @meta != nil
        CG_PMD_TEST.log("PLAY key=" + @key.to_s +
          " request=" + request.to_s +
          " actual=" + @action_name.to_s +
          " source=" + @meta[:source].to_s +
          " frames=" + @meta[:frame_count].to_i.to_s +
          " dirs=" + @meta[:direction_count].to_i.to_s +
          " anchor=" + @meta[:anchor_x].to_i.to_s + "," + @meta[:anchor_y].to_i.to_s +
          " rush=" + @meta[:rush_frame].to_s +
          " hit=" + @meta[:hit_frame].to_s +
          " return=" + @meta[:return_frame].to_s +
          " view=" + @view.to_s +
          " loop=" + @loop.to_s)
      else
        CG_PMD_TEST.warning("PLAY_FAILED key=" + @key.to_s + " request=" + request.to_s)
      end
    end
    return result
  end

  alias cg_pmd_autotest_original_tick tick
  def tick
    cg_pmd_autotest_original_tick
    return unless CG_PMD_TEST.active?
    if @rush_reached && !@cg_pmd_autotest_seen_rush
      @cg_pmd_autotest_seen_rush = true
      CG_PMD_TEST.log("MILESTONE key=" + @key.to_s + " action=" + @action_name.to_s + " event=RUSH frame=" + @frame_index.to_s)
    end
    if @hit_reached && !@cg_pmd_autotest_seen_hit
      @cg_pmd_autotest_seen_hit = true
      CG_PMD_TEST.log("MILESTONE key=" + @key.to_s + " action=" + @action_name.to_s + " event=HIT frame=" + @frame_index.to_s)
    end
    if @return_reached && !@cg_pmd_autotest_seen_return
      @cg_pmd_autotest_seen_return = true
      CG_PMD_TEST.log("MILESTONE key=" + @key.to_s + " action=" + @action_name.to_s + " event=RETURN frame=" + @frame_index.to_s)
    end
    if @finished && !@cg_pmd_autotest_seen_end
      @cg_pmd_autotest_seen_end = true
      CG_PMD_TEST.log("MILESTONE key=" + @key.to_s + " action=" + @action_name.to_s + " event=END frame=" + @frame_index.to_s)
    end
  end
end

#------------------------------------------------------------------------------
# ■ Scene_Map：只有 Shift+F6 才武裝 PMD 自動測試；單按 F6 保持正常戰鬥
#------------------------------------------------------------------------------
class Scene_Map < Scene_Base
  alias cg_pmd_autotest_scene_map_update update
  def update
    if Input.trigger?(Input::F6) && Input.press?(Input::A)
      begin
        ALBERT_CG.bootstrap_demo_party if defined?(ALBERT_CG) && ALBERT_CG.respond_to?(:bootstrap_demo_party)
      rescue => error
        CG_PMD_TEST.start_log
        CG_PMD_TEST.runtime_error(error, "map_bootstrap")
      end
      CG_PMD_TEST.arm!
    end
    cg_pmd_autotest_scene_map_update
  end
end

#------------------------------------------------------------------------------
# ■ Scene_Battle：真正執行視覺自動測試
#------------------------------------------------------------------------------
class Scene_Battle < Scene_Base
  alias cg_pmd_autotest_scene_battle_start start
  def start
    cg_pmd_autotest_scene_battle_start
    cg_pmd_autotest_setup if CG_PMD_TEST.consume_arm!
  end

  alias cg_pmd_autotest_scene_battle_update update
  def update
    cg_pmd_autotest_scene_battle_update
    if @cg_pmd_autotest_running
      begin
        cg_pmd_autotest_update
      rescue => error
        CG_PMD_TEST.runtime_error(error, "scene_battle_update")
        @cg_pmd_autotest_running = false
        cg_pmd_autotest_overlay("PMD AUTO TEST ERROR", error.message.to_s)
      end
    end

    if CG_PMD_TEST.logging?
      if Input.trigger?(Input::F6)
        cg_pmd_autotest_setup
      elsif Input.trigger?(Input::F9)
        cg_pmd_autotest_dump_snapshot
        Sound.play_decision
      elsif Input.trigger?(Input::F8)
        cg_pmd_autotest_cleanup_overrides
        CG_PMD_TEST.log("TEST_BATTLE_EXIT_BY_F8")
        CG_PMD_TEST.finish_session if CG_PMD_TEST.active?
        battle_end(1)
      end
    end
  end

  alias cg_pmd_autotest_scene_battle_terminate terminate
  def terminate
    cg_pmd_autotest_cleanup_overrides
    cg_pmd_autotest_dispose_overlay
    cg_pmd_autotest_scene_battle_terminate
  end

  def cg_pmd_autotest_setup
    CG_PMD_TEST.begin_session
    @cg_pmd_autotest_running = true
    @cg_pmd_autotest_slots = cg_pmd_autotest_collect_slots
    @cg_pmd_autotest_next_species = CG_PMD_TEST::FIRST_SPECIES
    @cg_pmd_autotest_action_index = 0
    @cg_pmd_autotest_phase = :load_batch
    @cg_pmd_autotest_timer = 0
    @cg_pmd_autotest_timeout = 0
    CG_PMD_TEST.log("BATTLE_SLOTS count=" + @cg_pmd_autotest_slots.size.to_s)
    @cg_pmd_autotest_slots.each_with_index do |sprite, index|
      CG_PMD_TEST.log("BATTLE_SLOT index=" + index.to_s + " " + CG_PMD_TEST.slot_label(sprite))
    end
    if @cg_pmd_autotest_slots.empty?
      CG_PMD_TEST.fatal("no Sprite_Battler slots found")
      @cg_pmd_autotest_running = false
      cg_pmd_autotest_overlay("PMD AUTO TEST FAILED", "找不到可測試 Battler")
    else
      cg_pmd_autotest_overlay("PMD AUTO TEST", "準備測試 0001-0026")
    end
  end

  def cg_pmd_autotest_collect_slots
    result = []
    return result if @spriteset == nil
    actor_sprites = @spriteset.instance_variable_get(:@actor_sprites) || []
    enemy_sprites = @spriteset.instance_variable_get(:@enemy_sprites) || []

    # Actor 0 是人類主角。只取後面的寵物，以免測試覆寫人類 Battler。
    for i in 1...actor_sprites.size
      sprite = actor_sprites[i]
      result.push(sprite) if sprite != nil && sprite.battler != nil
    end
    for sprite in enemy_sprites
      result.push(sprite) if sprite != nil && sprite.battler != nil
    end
    return result
  end

  def cg_pmd_autotest_cleanup_overrides
    slots = @cg_pmd_autotest_slots || cg_pmd_autotest_collect_slots
    for sprite in slots
      next if sprite == nil || sprite.battler == nil
      sprite.battler.cg_pmd_test_sprite_key_override = nil
      sprite.instance_variable_set(:@cg_pmd_key, nil)
      sprite.instance_variable_set(:@cg_pmd_playback, nil)
      sprite.instance_variable_set(:@battler_name, nil)
    end
  rescue => error
    CG_PMD_TEST.runtime_error(error, "cleanup") if CG_PMD_TEST.logging?
  end

  def cg_pmd_autotest_load_batch
    active = []
    keys = []
    for sprite in @cg_pmd_autotest_slots
      if @cg_pmd_autotest_next_species <= CG_PMD_TEST::LAST_SPECIES
        key = CG_PMD_TEST.key_for(@cg_pmd_autotest_next_species)
        @cg_pmd_autotest_next_species += 1
        sprite.battler.cg_pmd_test_sprite_key_override = key
        sprite.instance_variable_set(:@cg_pmd_key, nil)
        sprite.instance_variable_set(:@cg_pmd_playback, nil)
        sprite.cg_pmd_ensure_playback
        active.push(sprite)
        keys.push(key)
        CG_PMD_TEST.log("ASSIGN slot=" + CG_PMD_TEST.slot_label(sprite) + " key=" + key)
      else
        sprite.battler.cg_pmd_test_sprite_key_override = nil
        sprite.instance_variable_set(:@cg_pmd_key, nil)
        sprite.instance_variable_set(:@cg_pmd_playback, nil)
        sprite.instance_variable_set(:@battler_name, nil)
      end
    end
    @cg_pmd_autotest_active_slots = active
    @cg_pmd_autotest_batch_keys = keys
    @cg_pmd_autotest_action_index = 0
    @cg_pmd_autotest_timer = CG_PMD_TEST::BATCH_SETTLE_FRAMES
    @cg_pmd_autotest_phase = :settle
    CG_PMD_TEST.log("BATCH_BEGIN keys=" + keys.join(","))
    cg_pmd_autotest_overlay("PMD " + keys.join(" / "), "載入 Sprite...")
  end

  def cg_pmd_autotest_start_action(action_name)
    CG_PMD_TEST.log("ACTION_BEGIN action=" + action_name.to_s + " keys=" + @cg_pmd_autotest_batch_keys.join(","))
    for sprite in @cg_pmd_autotest_active_slots
      sprite.cg_pmd_play(action_name, :auto, action_name == "Idle" ? true : false, nil)
    end
    @cg_pmd_autotest_timeout = CG_PMD_TEST::ACTION_TIMEOUT_FRAMES
    if action_name == "Idle"
      @cg_pmd_autotest_timer = CG_PMD_TEST::IDLE_PREVIEW_FRAMES
      @cg_pmd_autotest_phase = :wait_idle
    else
      @cg_pmd_autotest_phase = :wait_action
    end
    cg_pmd_autotest_overlay("PMD " + @cg_pmd_autotest_batch_keys.join(" / "), "ACTION: " + action_name)
  end

  def cg_pmd_autotest_all_finished?
    for sprite in @cg_pmd_autotest_active_slots
      playback = sprite.instance_variable_get(:@cg_pmd_playback)
      return false if playback == nil || !playback.finished
    end
    return true
  end

  def cg_pmd_autotest_next_action_or_batch
    @cg_pmd_autotest_action_index += 1
    if @cg_pmd_autotest_action_index >= CG_PMD_TEST::VISUAL_ACTIONS.size
      CG_PMD_TEST.log("BATCH_END keys=" + @cg_pmd_autotest_batch_keys.join(","))
      if @cg_pmd_autotest_next_species > CG_PMD_TEST::LAST_SPECIES
        for sprite in @cg_pmd_autotest_active_slots
          sprite.cg_pmd_play("Idle", :auto, true, nil)
        end
        @cg_pmd_autotest_running = false
        CG_PMD_TEST.finish_session
        cg_pmd_autotest_overlay("AUTO TEST COMPLETE", CG_PMD_TEST.summary_text + "  F9=LOG快照  F8=返回")
      else
        @cg_pmd_autotest_phase = :load_batch
      end
    else
      action_name = CG_PMD_TEST::VISUAL_ACTIONS[@cg_pmd_autotest_action_index]
      cg_pmd_autotest_start_action(action_name)
    end
  end

  def cg_pmd_autotest_update
    case @cg_pmd_autotest_phase
    when :load_batch
      cg_pmd_autotest_load_batch
    when :settle
      @cg_pmd_autotest_timer -= 1
      if @cg_pmd_autotest_timer <= 0
        action_name = CG_PMD_TEST::VISUAL_ACTIONS[@cg_pmd_autotest_action_index]
        cg_pmd_autotest_start_action(action_name)
      end
    when :wait_idle
      @cg_pmd_autotest_timer -= 1
      cg_pmd_autotest_next_action_or_batch if @cg_pmd_autotest_timer <= 0
    when :wait_action
      @cg_pmd_autotest_timeout -= 1
      if cg_pmd_autotest_all_finished?
        cg_pmd_autotest_next_action_or_batch
      elsif @cg_pmd_autotest_timeout <= 0
        CG_PMD_TEST.warning("ACTION_TIMEOUT action=" + CG_PMD_TEST::VISUAL_ACTIONS[@cg_pmd_autotest_action_index].to_s +
          " keys=" + @cg_pmd_autotest_batch_keys.join(","))
        cg_pmd_autotest_dump_snapshot
        cg_pmd_autotest_next_action_or_batch
      end
    end
  end

  def cg_pmd_autotest_dump_snapshot
    CG_PMD_TEST.log("SNAPSHOT_BEGIN")
    slots = @cg_pmd_autotest_slots || []
    slots.each_with_index do |sprite, index|
      CG_PMD_TEST.log_sprite(sprite, "SNAPSHOT[" + index.to_s + "]")
    end
    CG_PMD_TEST.log("SNAPSHOT_END")
  end

  def cg_pmd_autotest_overlay(line1, line2 = "")
    if @cg_pmd_autotest_overlay == nil || @cg_pmd_autotest_overlay.disposed?
      @cg_pmd_autotest_overlay = Sprite.new
      @cg_pmd_autotest_overlay.z = 9999
      @cg_pmd_autotest_overlay.bitmap = Bitmap.new(544, 58)
    end
    bitmap = @cg_pmd_autotest_overlay.bitmap
    bitmap.clear
    bitmap.fill_rect(0, 0, 544, 58, Color.new(0, 0, 0, 180))
    bitmap.font.size = 18
    bitmap.draw_text(8, 2, 528, 24, line1.to_s, 0)
    bitmap.font.size = 14
    bitmap.draw_text(8, 28, 528, 22, line2.to_s, 0)
  rescue => error
    CG_PMD_TEST.runtime_error(error, "overlay")
  end

  def cg_pmd_autotest_dispose_overlay
    return if @cg_pmd_autotest_overlay == nil
    if @cg_pmd_autotest_overlay.bitmap != nil && !@cg_pmd_autotest_overlay.bitmap.disposed?
      @cg_pmd_autotest_overlay.bitmap.dispose
    end
    @cg_pmd_autotest_overlay.dispose unless @cg_pmd_autotest_overlay.disposed?
    @cg_pmd_autotest_overlay = nil
  end
end
