# RMVX_SCRIPT_INDEX: 186
# RMVX_SCRIPT_ID: 20501
# RMVX_SCRIPT_NAME: CG Pokemon Species26 Auto Evolution v2.0.5a
# RMVX_SOURCE_SHA256: 465123e1469d1154d9f1a2e609fbb10a464ef7c665c9632c18d5b483f00a6d0c

#==============================================================================
# ■ CG Pokemon Species26 Auto Evolution v2.0.5a
#------------------------------------------------------------------------------
# 【用途】
#  將 #0001～#0026 的進化流程由 F10 手動管理改為「自動進化」。
#  寶可夢只要達到目前型態的進化等級，就會自動切換到下一型態；不播放
#  原作式進化動畫，只顯示簡潔訊息。
#
# 【正式規則】
#  1. 每次 Game_Actor#level_up 後立即檢查進化。
#  2. 若一次事件把等級直接拉高很多級，會逐級觸發，因此可以連續進化。
#     例：Lv.5 妙蛙種子事件直接升到 Lv.40：
#       Lv.16 → 妙蛙草
#       Lv.32 → 妙蛙花
#  3. 舊存檔若已經超過進化門檻，進入地圖時會做一次 Catch-up Scan，
#     自動補上所有應發生但尚未執行的進化。
#  4. 同時支援：
#       - 現階段 Direct Actor 測試寵物（Actor 100 / 103 / 106）
#       - 未來正式捕捉 Clone 寵物
#       - 攜帶／倉庫寵物
#       - 既有固定隊友寵物
#  5. 進化仍沿用 CG_Pet_Evolution_v1_5 的「同一個體、只切 Form」架構，
#     不建立新 Actor，不改個體 ID。
#  6. 進化後沿用 v2.0.5 Battle Content：
#       - 自動補上新型態在目前等級應學技能
#       - 更新技能欄容量
#       - PMD 身分改讀新的 cg_current_form_actor_id
#  7. 正式玩法停用 F10 手動進化入口；底層 cg_evolve / cg_evolve_to API
#     仍保留，供事件、除錯與特殊劇情使用。
#
# 【訊息規則】
#  不播放動畫。進化後加入一般遊戲訊息佇列：
#    「妙蛙種子進化成妙蛙草了！」
#  若一次跨過兩個門檻，會依序顯示兩則，不會把兩階進化壓成一則。
#  若進化發生在戰鬥中，訊息先排隊，回到地圖後再顯示，避免與
#  Tankentai BattleMessage / HUD 爭用視窗。
#
# 【可調參數】
#  AUTO_EVOLUTION_ENABLED = true
#    true  ：正式啟用自動進化。
#    false ：完全不自動進化。
#
#  DISABLE_F10_EVOLUTION_UI = true
#    true  ：F10 不再開啟舊進化管理頁。
#    false ：保留 F10 作開發用手動管理。
#
#  SHOW_EVOLUTION_MESSAGE = true
#    true  ：進化後顯示訊息。
#    false ：靜默進化，只寫 LOG。
#
# 【事件／腳本呼叫】
#  actor.cg_auto_evolve_if_ready(:event)
#    → 立即檢查該 Actor，必要時可連續進化。
#
#  ALBERT_CG::AUTO_EVOLUTION.scan_owned_pets(:event)
#    → 掃描目前隊伍、攜帶、倉庫與固定寵物，補齊應發生的進化。
#
#  actor.cg_evolve_to(form_actor_id, true)
#    → 原本強制進化 API 保留，特殊劇情仍可使用。
#
# 【LOG】
#  專案根目錄：Species26_AutoEvolution.log
#  會記錄舊型態、新型態、等級、觸發來源、Dex 與 PMD Key。
#
# 【腳本位置】
#  請放在：
#    CG Pokemon Species26 Battle Content v2.0.5
#  之下，BattleInit RootFix／AutoTest Harness／Main 之前。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_Species26AutoEvolution"] = "2.0.5a"

module ALBERT_CG
  module AUTO_EVOLUTION
    VERSION = "2.0.5a"
    LOG_FILE = "Species26_AutoEvolution.log"

    AUTO_EVOLUTION_ENABLED = true
    DISABLE_F10_EVOLUTION_UI = true
    SHOW_EVOLUTION_MESSAGE = true
    MAX_CHAIN_EVOLUTION = 4

    def self.species26_form_actor_id?(actor_id)
      return false unless defined?(ALBERT_CG::SPECIES26)
      dex = ALBERT_CG::SPECIES26.dex_for_actor_id(actor_id.to_i)
      return dex.to_i >= 1 && dex.to_i <= 26
    rescue
      return false
    end

    def self.reset_log
      begin
        File.open(LOG_FILE, "wb") do |file|
          file.write("CG SPECIES26 AUTO EVOLUTION LOG v" + VERSION + "\r\n")
          file.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
          file.write("AUTO=" + AUTO_EVOLUTION_ENABLED.to_s +
                     " F10_DISABLED=" + DISABLE_F10_EVOLUTION_UI.to_s +
                     " MESSAGE=" + SHOW_EVOLUTION_MESSAGE.to_s + "\r\n")
          file.write("------------------------------------------------------------\r\n")
        end
      rescue
      end
    end

    def self.append_log(text)
      begin
        File.open(LOG_FILE, "ab") do |file|
          file.write("[" + Time.now.strftime("%H:%M:%S") + "] " + text.to_s + "\r\n")
        end
      rescue
      end
    end

    def self.message_queue
      return [] if $game_system == nil
      queue = $game_system.instance_variable_get(:@cg_species26_auto_evolution_messages)
      if queue == nil
        queue = []
        $game_system.instance_variable_set(:@cg_species26_auto_evolution_messages, queue)
      end
      return queue
    end

    def self.queue_message(text)
      return false unless SHOW_EVOLUTION_MESSAGE
      return false if text == nil || text.to_s == ""
      queue = message_queue
      return false if queue == nil
      queue.push(text.to_s)
      return true
    end

    def self.game_message_busy?
      return true if $game_message == nil
      return true if $game_message.respond_to?(:visible) && $game_message.visible
      return true if $game_message.respond_to?(:busy) && $game_message.busy
      if $game_message.respond_to?(:texts)
        return true unless $game_message.texts.empty?
      end
      return false
    rescue
      return true
    end

    # 一次只送一則訊息，讓連續兩階進化分兩個確認頁顯示。
    def self.flush_one_message
      return false if $game_temp != nil && $game_temp.in_battle
      return false if game_message_busy?
      queue = message_queue
      return false if queue == nil || queue.empty?
      text = queue.shift
      return false if text == nil || text.to_s == ""
      begin
        $game_message.face_name = "" if $game_message.respond_to?(:face_name=)
        $game_message.face_index = 0 if $game_message.respond_to?(:face_index=)
        $game_message.background = 0 if $game_message.respond_to?(:background=)
        $game_message.position = 2 if $game_message.respond_to?(:position=)
        $game_message.texts.push(text.to_s)
        return true
      rescue
        return false
      end
    end

    def self.owned_pet_candidates
      result = []
      return result if $game_party == nil

      # Direct Actor 測試寵物／目前隊伍成員。
      if $game_party.respond_to?(:members)
        for actor in $game_party.members
          next if actor == nil
          result.push(actor) unless result.include?(actor)
        end
      end

      # Clone 攜帶、倉庫、固定隊友寵物，沿用既有進化核心的完整列表。
      if $game_party.respond_to?(:cg_evolution_pets)
        for actor in $game_party.cg_evolution_pets
          next if actor == nil
          result.push(actor) unless result.include?(actor)
        end
      end
      return result
    end

    def self.scan_owned_pets(reason = :scan)
      count = 0
      for actor in owned_pet_candidates
        next unless actor.respond_to?(:cg_auto_evolve_if_ready)
        rows = actor.cg_auto_evolve_if_ready(reason)
        count += rows.size if rows.respond_to?(:size)
      end
      append_log("SCAN reason=" + reason.to_s + " evolved=" + count.to_s)
      return count
    end
  end
end

#==============================================================================
# ■ Game_Actor：Direct Actor + Clone 共用自動進化
#==============================================================================
class Game_Actor < Game_Battler
  # 原 v1.5 只承認 Clone／fixed partner。正式 Species26 Direct Actor 也要能進化。
  alias species26_auto_evolution_pet_base cg_evolution_pet?
  def cg_evolution_pet?
    return true if species26_auto_evolution_pet_base
    return true if defined?(ALBERT_CG::AUTO_EVOLUTION) &&
                   ALBERT_CG::AUTO_EVOLUTION.species26_form_actor_id?(@actor_id.to_i)
    return false
  end

  def cg_auto_evolve_if_ready(reason = :unknown)
    result = []
    return result unless ALBERT_CG::AUTO_EVOLUTION::AUTO_EVOLUTION_ENABLED
    return result unless respond_to?(:cg_evolution_ready?)
    return result unless cg_evolution_pet?

    guard = 0
    while guard < ALBERT_CG::AUTO_EVOLUTION::MAX_CHAIN_EVOLUTION && cg_evolution_ready?
      guard += 1
      old_name = name.to_s
      old_form = cg_current_form_actor_id.to_i
      old_dex = respond_to?(:cg_national_dex) ? cg_national_dex.to_i : 0
      next_form = cg_evolution_next_form.to_i
      break if next_form <= 0 || next_form == old_form

      # 自動進化必須保留「本次 gain_exp / change_level 已經給進來的總 EXP」。
      # 原 v1.5 cg_evolve_to 為了避免換經驗曲線造成跳級，會把 @exp 暫時
      # clamp 在目前等級；若不還原，事件一次升到 Lv.40 會在 Lv.16 進化後
      # 被截斷。Species26 同系譜共用 Class，因此保留總 EXP 才符合本專案需求。
      preserved_exp = @exp.to_i
      evolved = cg_evolve
      break unless evolved
      @exp = preserved_exp

      new_name = name.to_s
      new_form = cg_current_form_actor_id.to_i
      new_dex = respond_to?(:cg_national_dex) ? cg_national_dex.to_i : 0
      pmd_key = respond_to?(:cg_pmd_sprite_key) ? cg_pmd_sprite_key.to_s : ""
      text = old_name + "進化成" + new_name + "了！"
      ALBERT_CG::AUTO_EVOLUTION.queue_message(text)
      ALBERT_CG::AUTO_EVOLUTION.append_log(
        "EVOLVE reason=" + reason.to_s +
        " runtime_actor=" + @actor_id.to_i.to_s +
        " level=" + @level.to_i.to_s +
        " exp=" + @exp.to_i.to_s +
        " form=" + old_form.to_s + "->" + new_form.to_s +
        " dex=" + old_dex.to_s + "->" + new_dex.to_s +
        " pmd=" + pmd_key +
        " name=" + old_name + "->" + new_name)
      result.push([old_form, new_form])
    end
    return result
  rescue => error
    ALBERT_CG::AUTO_EVOLUTION.append_log(
      "ERROR actor=" + @actor_id.to_i.to_s +
      " class=" + error.class.to_s + " message=" + error.message.to_s)
    return result
  end

  # v2.0.5 Battle Content 的 level_up 已先補技能；本層最後再做進化。
  alias species26_auto_evolution_level_up level_up
  def level_up
    species26_auto_evolution_level_up
    cg_auto_evolve_if_ready(:level_up)
  end
end

#==============================================================================
# ■ Game_Actors：捕捉／建立新 Clone 後補一次自動進化判定
#==============================================================================
class Game_Actors
  if method_defined?(:cg_create_pet)
    alias species26_auto_evolution_create_pet cg_create_pet
    def cg_create_pet(model_actor_id, level = nil, custom_name = nil, owner_actor_id = nil)
      pet = species26_auto_evolution_create_pet(model_actor_id, level, custom_name, owner_actor_id)
      pet.cg_auto_evolve_if_ready(:create_pet) if pet != nil && pet.respond_to?(:cg_auto_evolve_if_ready)
      return pet
    end
  end
end

#==============================================================================
# ■ Scene_Map：舊存檔補進化 + 顯示訊息
#==============================================================================
class Scene_Map < Scene_Base
  alias species26_auto_evolution_start start
  def start
    species26_auto_evolution_start
    unless @cg_species26_auto_evolution_scanned
      @cg_species26_auto_evolution_scanned = true
      ALBERT_CG::AUTO_EVOLUTION.scan_owned_pets(:map_start)
    end
  end

  alias species26_auto_evolution_update update
  def update
    species26_auto_evolution_update
    return unless $scene == self
    ALBERT_CG::AUTO_EVOLUTION.flush_one_message
  end
end

#==============================================================================
# ■ 正式玩法：停用 F10 手動進化 UI
#==============================================================================
module ALBERT_CG
  class << self
    if method_defined?(:cg_f10_trigger?)
      alias species26_auto_evolution_old_f10_trigger cg_f10_trigger?
      def cg_f10_trigger?
        return false if ALBERT_CG::AUTO_EVOLUTION::DISABLE_F10_EVOLUTION_UI
        return species26_auto_evolution_old_f10_trigger
      end
    end
  end
end

#==============================================================================
# ■ Scene_Title：每次啟動重建 Auto Evolution LOG
#==============================================================================
class Scene_Title < Scene_Base
  alias species26_auto_evolution_load_database load_database
  def load_database
    species26_auto_evolution_load_database
    ALBERT_CG::AUTO_EVOLUTION.reset_log
    $data_system.game_title = "CG Pet Battle Prototype v2.0.5a PMD26 AutoEvolution" if $data_system != nil
  end

  alias species26_auto_evolution_load_bt_database load_bt_database
  def load_bt_database
    species26_auto_evolution_load_bt_database
    ALBERT_CG::AUTO_EVOLUTION.reset_log
    $data_system.game_title = "CG Pet Battle Prototype v2.0.5a PMD26 AutoEvolution" if $data_system != nil
  end
end
