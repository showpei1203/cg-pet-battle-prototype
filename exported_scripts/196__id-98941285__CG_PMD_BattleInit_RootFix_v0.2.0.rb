# RMVX_SCRIPT_INDEX: 196
# RMVX_SCRIPT_ID: 98941285
# RMVX_SCRIPT_NAME: CG PMD BattleInit RootFix v0.2.0
# RMVX_SOURCE_SHA256: 371d1ed32accdc0f92b12d76f1fa9fdf81c2c74500ccd46519746d2887995c88

#==============================================================================
# ■ CG_PMD_BattleInit_RootFix v0.2.0
#------------------------------------------------------------------------------
# 【用途】
#  PMD 正式物種導入後的 Tankentai 戰鬥初始化根因修正與追蹤工具。
#  專門處理進入戰鬥時出現：
#    Unable to find file Graphics/Characters/_1
#  的問題，並把真正的呼叫者、Battler 身分與 PMD 判定寫入 LOG。
#
# 【確認到的根因鏈】
#  1. Tankentai Kaduki 模式在 WALK_ANIME=false 時會讀取：
#       Cache.character(character_name + "_1")
#  2. 正式 PMD Actor / Enemy 的舊 Kaduki 名稱可以是空字串，因為本體應由 PMD 畫。
#  3. PMD Core 雖已攔截 Sprite_Battler#make_battler，但 Enemy 的原版
#     Game_Enemy#base_position 本身也會開舊圖來取得 bitmap.height。
#  4. 此外，單按 F6 原本不保證每次都重新 bootstrap 測試隊伍；若沿用舊存檔，
#     Runtime Game_Actor 可能仍保留先前複製進實例的空 character_name。
#
# 【本補丁規則】
#  1. 每次 ALBERT_CG.start_demo_battle 前強制執行 bootstrap_demo_party。
#  2. 同步刷新 Direct Actor 100 / 103 / 106 的 Runtime character_name 安全底圖。
#  3. PMD Enemy 的 base position 已由 CG_PMD_Core v0.2.2 改用 screen_x / screen_y，
#     不再開 Kaduki / Battler 圖算高度。
#  4. 所有 Sprite_Battler#make_battler 入口都寫入 PMD_BattleInitTrace.log。
#  5. 若仍有任何未知舊路徑要求恰好 "_1"，Cache.character 會攔截並記錄 caller，
#     暫回透明安全 Bitmap，避免遊戲直接關閉。這是診斷安全網，不是正式素材替代。
#
# 【LOG】
#  專案根目錄：PMD_BattleInitTrace.log
#  內容包含：
#    - F6 前的 Party / Troop 成員
#    - Actor character_name / Enemy battler_name
#    - PMD key / cg_pmd_enabled?
#    - Sprite_Battler#make_battler 使用 PMD 或 Legacy
#    - 若命中 _1 安全網，完整 Ruby caller
#
# 【快捷鍵／測試】
#  地圖按 F6：每次先重建 Actor 1 + 100 + 103 + 106，再進 Troop 609。
#  Shift+F6：仍保留 0001～0026 PMD 全動畫巡檢。
#
# 【實際範例】
#  若 LOG 出現：
#    MAKE actor name=妙蛙種子 id=100 pmd=0001 enabled=true
#  表示正式 Actor 已由 PMD 接管。
#
#  若 LOG 出現：
#    EMPTY_1_GUARD ...
#  其後 caller 會直接指出仍是哪一支舊腳本要求 Graphics/Characters/_1。
#==============================================================================

$imported = {} if $imported == nil
$imported["CG_PMD_BattleInit_RootFix"] = "0.2.0"

module CG_PMD_BATTLE_INIT_TRACE
  LOG_FILE = "PMD_BattleInitTrace.log"

  def self.reset
    begin
      File.open(LOG_FILE, "wb") do |file|
        file.write("CG PMD BATTLE INIT TRACE v0.2.0\r\n")
        file.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
        file.write("------------------------------------------------------------\r\n")
      end
    rescue
    end
  end

  def self.log(text)
    begin
      File.open(LOG_FILE, "ab") do |file|
        file.write("[" + Time.now.strftime("%H:%M:%S") + "] " + text.to_s + "\r\n")
      end
    rescue
    end
  end

  def self.safe_call(object, method_name, fallback = "")
    return fallback if object == nil || !object.respond_to?(method_name)
    begin
      value = object.send(method_name)
      return value == nil ? fallback : value
    rescue => error
      return "ERR:" + error.class.to_s
    end
  end

  def self.battler_line(prefix, battler)
    return prefix.to_s + " nil" if battler == nil
    kind = battler.actor? ? "actor" : "enemy"
    id = battler.actor? ? safe_call(battler, :id, 0) : safe_call(battler, :enemy_id, 0)
    graphic = battler.actor? ? safe_call(battler, :character_name, "") : safe_call(battler, :battler_name, "")
    key = safe_call(battler, :cg_pmd_sprite_key, "")
    enabled = safe_call(battler, :cg_pmd_enabled?, false)
    anime = battler.actor? ? true : safe_call(battler, :anime_on, false)
    return prefix.to_s + " " + kind +
      " name=" + safe_call(battler, :name, "").to_s +
      " id=" + id.to_s +
      " graphic=" + graphic.to_s.inspect +
      " pmd=" + key.to_s +
      " enabled=" + enabled.to_s +
      " anime_on=" + anime.to_s
  end

  def self.snapshot(label)
    log("SNAPSHOT_BEGIN " + label.to_s)
    if $game_party != nil
      for battler in $game_party.members
        log(battler_line("ALLY", battler))
      end
    end
    if $game_troop != nil
      for battler in $game_troop.members
        log(battler_line("ENEMY", battler))
      end
    end
    log("SNAPSHOT_END " + label.to_s)
  end

  def self.log_caller(label)
    log(label.to_s)
    begin
      for line in caller
        log("  " + line.to_s)
      end
    rescue
    end
  end
end

#------------------------------------------------------------------------------
# ■ F6／事件進入 Demo Battle：每次都先強制重建直接 Actor 測試隊伍
#------------------------------------------------------------------------------
module ALBERT_CG
  class << self
    alias cg_pmd_rootfix_start_demo_battle start_demo_battle
    def start_demo_battle(troop_id = ALBERT_CG::DEMO_TROOP_ID)
      CG_PMD_BATTLE_INIT_TRACE.reset
      begin
        bootstrap_demo_party if respond_to?(:bootstrap_demo_party)
        cg_install_direct_pmd_safe_graphics if respond_to?(:cg_install_direct_pmd_safe_graphics)
        cg_refresh_direct_pmd_runtime_graphics if respond_to?(:cg_refresh_direct_pmd_runtime_graphics)
      rescue => error
        CG_PMD_BATTLE_INIT_TRACE.log("BOOTSTRAP_ERROR " + error.class.to_s + ": " + error.message.to_s)
      end
      CG_PMD_BATTLE_INIT_TRACE.snapshot("BEFORE_TROOP_SETUP")
      result = cg_pmd_rootfix_start_demo_battle(troop_id)
      CG_PMD_BATTLE_INIT_TRACE.snapshot("AFTER_TROOP_SETUP")
      return result
    end
  end
end

#------------------------------------------------------------------------------
# ■ Sprite_Battler：記錄真正進入 make_battler 時是否已由 PMD 接管
#------------------------------------------------------------------------------
class Sprite_Battler < Sprite_Base
  alias cg_pmd_rootfix_trace_make_battler make_battler
  def make_battler
    CG_PMD_BATTLE_INIT_TRACE.log(
      CG_PMD_BATTLE_INIT_TRACE.battler_line("MAKE", @battler))
    begin
      result = cg_pmd_rootfix_trace_make_battler
      mode = cg_pmd_active? ? "PMD" : "LEGACY"
      CG_PMD_BATTLE_INIT_TRACE.log("MAKE_OK mode=" + mode +
        " bitmap=" + (self.bitmap == nil ? "nil" : self.bitmap.width.to_s + "x" + self.bitmap.height.to_s))
      return result
    rescue => error
      CG_PMD_BATTLE_INIT_TRACE.log("MAKE_ERROR " + error.class.to_s + ": " + error.message.to_s)
      CG_PMD_BATTLE_INIT_TRACE.log_caller("MAKE_CALLER")
      raise
    end
  end
end

#------------------------------------------------------------------------------
# ■ 最後安全網：任何空 battler_name 被拼成的 "_數字"
#------------------------------------------------------------------------------
# 正常 v0.2.3 Native Bridge 下應該一次都不會命中。若未來別的舊 SBS Add-on
# 又直接要求 _1/_2/_3...，只記錄每個檔名第一次 caller，並回透明圖避免關遊戲。
module Cache
  class << self
    alias cg_pmd_rootfix_character character
    def character(filename)
      text = filename.to_s
      if text =~ /^_\d+$/
        @cg_pmd_empty_variant_warned = {} if @cg_pmd_empty_variant_warned == nil
        unless @cg_pmd_empty_variant_warned[text]
          @cg_pmd_empty_variant_warned[text] = true
          CG_PMD_BATTLE_INIT_TRACE.log("EMPTY_VARIANT_GUARD filename=" + text.inspect)
          CG_PMD_BATTLE_INIT_TRACE.log_caller("EMPTY_VARIANT_CALLER")
        end
        @cg_pmd_empty_variant_bitmaps = {} if @cg_pmd_empty_variant_bitmaps == nil
        bitmap = @cg_pmd_empty_variant_bitmaps[text]
        if bitmap == nil || bitmap.disposed?
          bitmap = Bitmap.new(128, 128)
          @cg_pmd_empty_variant_bitmaps[text] = bitmap
        end
        return bitmap
      end
      return cg_pmd_rootfix_character(filename)
    end
  end
end

#------------------------------------------------------------------------------
# ■ Battle HUD：PMD 寶可夢直接使用 Idle Sprite，不再畫暫用 Kaduki 人物頭像
#------------------------------------------------------------------------------
class Window_BattleStatus < Window_Selectable
  alias cg_pmd_hud_draw_small_character cg_draw_small_character
  def cg_draw_small_character(actor, x, y, max_width, max_height)
    if actor != nil && actor.respond_to?(:cg_pmd_enabled?) && actor.cg_pmd_enabled?
      begin
        key = actor.cg_pmd_sprite_key.to_s
        resolved = CG_PMD.resolve_action(key, "Idle")
        if resolved != nil
          meta = resolved[1]
          bitmap = Cache.pmd_sprite(key, meta[:source])
          fw = meta[:frame_width].to_i
          fh = meta[:frame_height].to_i
          dirs = meta[:direction_count].to_i
          # HUD 使用正面，方便辨識物種，不受戰場左右 mirror 影響。
          row = CG_PMD.row_for(key, :front, dirs)
          source = Rect.new(0, row * fh, fw, fh)
          scale_x = max_width.to_f / fw
          scale_y = max_height.to_f / fh
          scale = [scale_x, scale_y, 1.0].min
          draw_width = [(fw * scale).to_i, 1].max
          draw_height = [(fh * scale).to_i, 1].max
          target_x = x + (max_width - draw_width) / 2
          target_y = y + max_height - draw_height
          target = Rect.new(target_x, target_y, draw_width, draw_height)
          opacity = actor.dead? ? 100 : 255
          if defined?(ALBERT_CG::TRGSSXVisual)
            ALBERT_CG::TRGSSXVisual.stretch_blt(
              self.contents, target, bitmap, source, opacity)
          else
            self.contents.stretch_blt(target, bitmap, source, opacity)
          end
          return
        end
      rescue => error
        CG_PMD_BATTLE_INIT_TRACE.log("HUD_PMD_ERROR " + error.class.to_s + ": " + error.message.to_s)
      end
    end
    return cg_pmd_hud_draw_small_character(actor, x, y, max_width, max_height)
  end
end
