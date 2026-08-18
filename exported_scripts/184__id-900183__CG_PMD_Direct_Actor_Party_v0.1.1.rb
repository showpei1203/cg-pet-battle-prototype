# RMVX_SCRIPT_INDEX: 184
# RMVX_SCRIPT_ID: 900183
# RMVX_SCRIPT_NAME: CG PMD Direct Actor Party v0.1.1
# RMVX_SOURCE_SHA256: 25e15d5822dec0a3a7e5e84e0501659cf842cc0aa7554fb011bae01d1a4877a8

#==============================================================================
# ■ CG_PMD_DirectActorParty v0.1.1
#------------------------------------------------------------------------------
# 【用途】
#  PMD 0001～0026 正式導入期間的「直接 Actor 隔離測試」補丁。
#  本版暫時不經過 Clone 1000+ 寵物實例，讓初始戰鬥隊伍直接使用正式物種 Actor：
#    Actor 1   = Tom / 主角
#    Actor 100 = #0001 妙蛙種子
#    Actor 103 = #0004 小火龍
#    Actor 106 = #0007 傑尼龜
#
# 【為什麼需要此補丁】
#  先前正常 F6 戰鬥仍在 Tankentai 初始化階段要求 Graphics/Characters/_1，
#  表示 Clone → PMD 身分橋接與 SBS 建立 Battler 的時機尚未完全對接。
#  本補丁先把 Clone 層完全排除，直接驗證：
#    正式 Actor → PMD key → Tankentai Sprite → 正常戰鬥
#  若此路徑正常，再回頭只修 Clone 橋接，不再同時猜兩個問題。
#
# 【安全底圖】
#  Tankentai 若在 PMD Renderer 接手前仍短暫讀取 Kaduki 圖，本補丁會把三隻測試 Actor
#  與對應 Enemy 暫時指向專案既有素材：
#    妙蛙種子：$Actor12
#    小火龍  ：$Actor22
#    傑尼龜  ：$Actor26
#  對應的 Graphics/Characters/$ActorXX_1.png 與 Graphics/Battlers/$ActorXX.png
#  已存在，因此即使 PMD 判定晚一幀也不會再嘗試讀取 _1.png。
#
# 【機制規則】
#  1. 新遊戲自動把實際 @actors 固定為 [1, 100, 103, 106]。
#  2. F6 使用相同直接 Actor 隊伍進入 DEMO_TROOP_ID。
#  3. 100 / 103 / 106 在戰鬥規則中視為「battle pet」，但不偽裝成 Clone；
#     因此 cg_pet? 仍為 false，不會誤套掉檔、配種、Clone UID 等個體資料。
#  4. cg_active_pets 直接回傳三個正式 Actor，讓 Solo Trainer 的四行動槽能正常建立。
#  5. Shift+F6 原 0001～0026 PMD 全動畫巡檢仍保留。
#
# 【可調參數】
#  DIRECT_PMD_TEST_PET_ACTOR_IDS：直接出戰的正式寵物 Actor ID。
#  DIRECT_PMD_TEST_LEVEL：三隻測試 Actor 的測試等級。
#  DIRECT_PMD_SAFE_GRAPHICS：Tankentai 初始化安全底圖。
#
# 【事件／腳本呼叫】
#  ALBERT_CG.bootstrap_demo_party
#    → 重新套用 Actor 1 + 100 + 103 + 106 直接測試隊伍。
#
#  $game_party.cg_enable_direct_pmd_test_party!
#    → 不進戰鬥，只重建目前直接測試隊伍。
#
# 【實際範例】
#  事件腳本：
#    $game_party.cg_enable_direct_pmd_test_party!
#    ALBERT_CG.start_demo_battle
#==============================================================================

$imported = {} if $imported == nil
$imported["CG_PMD_DirectActorParty"] = "0.1.1"

module ALBERT_CG
  DIRECT_PMD_TEST_MODE = true
  DIRECT_PMD_TEST_PET_ACTOR_IDS = [100, 103, 106]
  DIRECT_PMD_TEST_LEVEL = 5
  DIRECT_PMD_SAFE_GRAPHICS = {
    100 => "$Actor12",
    103 => "$Actor22",
    106 => "$Actor26",
  }
  DIRECT_PMD_SAFE_ENEMIES = {
    600 => "$Actor12",
    603 => "$Actor22",
    606 => "$Actor26",
  }

  # 已存在於 $game_actors 的 Actor 會把 character_name 複製到實例 ivar；
  # 單改 $data_actors 無法修復舊存檔／先前已實例化的 Actor，因此需同步刷新。
  def self.cg_refresh_direct_pmd_runtime_graphics
    return false if $game_actors == nil
    DIRECT_PMD_SAFE_GRAPHICS.each do |actor_id, character_name|
      actor = $game_actors[actor_id]
      next if actor == nil
      actor.instance_variable_set(:@character_name, character_name.to_s)
      actor.instance_variable_set(:@character_index, 0)
    end
    return true
  end

  def self.cg_install_direct_pmd_safe_graphics
    if $data_actors != nil
      DIRECT_PMD_SAFE_GRAPHICS.each do |actor_id, character_name|
        actor = $data_actors[actor_id]
        next if actor == nil
        actor.character_name = character_name
        actor.character_index = 0 if actor.respond_to?(:character_index=)
      end
    end
    if $data_enemies != nil
      DIRECT_PMD_SAFE_ENEMIES.each do |enemy_id, battler_name|
        enemy = $data_enemies[enemy_id]
        next if enemy == nil
        enemy.battler_name = battler_name
        enemy.battler_hue = 0
      end
    end
    return true
  end

  # 正式把 Demo bootstrap 改為「直接 Actor」，本版不建立 Clone 1000+。
  def self.bootstrap_demo_party
    return [] if $game_party == nil
    cg_install_direct_pmd_safe_graphics
    $game_party.cg_enable_direct_pmd_test_party!
    cg_refresh_direct_pmd_runtime_graphics
    return DIRECT_PMD_TEST_PET_ACTOR_IDS.clone
  end
end

class Game_Actor < Game_Battler
  alias cg_pmd_direct_party_battle_pet cg_battle_pet?
  def cg_battle_pet?
    if ALBERT_CG::DIRECT_PMD_TEST_MODE &&
       ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.include?(@actor_id.to_i)
      return true
    end
    return cg_pmd_direct_party_battle_pet
  end
end

class Game_Party < Game_Unit
  def cg_direct_pmd_test_actor_ids
    return [ALBERT_CG::SOLO_HUMAN_ACTOR_ID] +
      ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS
  end

  def cg_enable_direct_pmd_test_party!
    return false if @cg_direct_pmd_syncing
    @cg_direct_pmd_syncing = true
    changed = false
    begin
      ids = cg_direct_pmd_test_actor_ids
      if @actors != ids
        @actors = ids.clone
        changed = true
      end

      # 暫時把 Clone 攜帶資料清空，避免 Solo Trainer 下一次同步又把 1000+ 塞回隊伍。
      @cg_carried_pet_ids = []
      @cg_active_pet_id = ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS[0]
      @cg_active_pet_ids_by_owner = {
        ALBERT_CG::SOLO_HUMAN_ACTOR_ID => ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS[0]
      }

      # 等級與回復只在第一次建立直接測試隊伍時做，避免每次 members 查詢都重設 HP/MP。
      unless @cg_direct_pmd_initialized
        for actor_id in ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS
          actor = $game_actors == nil ? nil : $game_actors[actor_id]
          next if actor == nil
          if actor.respond_to?(:change_level)
            actor.change_level(ALBERT_CG::DIRECT_PMD_TEST_LEVEL, false)
          end
          actor.recover_all if actor.respond_to?(:recover_all)
        end
        @cg_direct_pmd_initialized = true
      end
    ensure
      @cg_direct_pmd_syncing = false
    end

    # 只有實際改變隊伍時才 refresh，避免 Game_Player#refresh → members → sync 的遞迴。
    if changed
      $game_player.refresh if $game_player != nil
      $party_change = true
    end
    return changed
  end

  alias cg_pmd_direct_party_solo_prepare cg_solo_prepare_party!
  def cg_solo_prepare_party!
    if ALBERT_CG::DIRECT_PMD_TEST_MODE
      return cg_enable_direct_pmd_test_party!
    end
    return cg_pmd_direct_party_solo_prepare
  end

  alias cg_pmd_direct_party_solo_sync cg_solo_sync_party!
  def cg_solo_sync_party!
    if ALBERT_CG::DIRECT_PMD_TEST_MODE
      return cg_enable_direct_pmd_test_party!
    end
    return cg_pmd_direct_party_solo_sync
  end

  alias cg_pmd_direct_party_active_pets cg_active_pets
  def cg_active_pets
    unless ALBERT_CG::DIRECT_PMD_TEST_MODE
      return cg_pmd_direct_party_active_pets
    end
    result = []
    for actor_id in ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS
      actor = $game_actors == nil ? nil : $game_actors[actor_id]
      result.push(actor) if actor != nil
    end
    return result
  end

  alias cg_pmd_direct_party_active_pet cg_active_pet
  def cg_active_pet(owner_actor_id = nil)
    unless ALBERT_CG::DIRECT_PMD_TEST_MODE
      return cg_pmd_direct_party_active_pet(owner_actor_id)
    end
    return $game_actors[ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS[0]]
  end

  alias cg_pmd_direct_party_active_pet_id cg_active_pet_id
  def cg_active_pet_id(owner_actor_id = nil)
    unless ALBERT_CG::DIRECT_PMD_TEST_MODE
      return cg_pmd_direct_party_active_pet_id(owner_actor_id)
    end
    return ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS[0]
  end

  alias cg_pmd_direct_party_active_pet_for cg_active_pet_for
  def cg_active_pet_for(human)
    unless ALBERT_CG::DIRECT_PMD_TEST_MODE
      return cg_pmd_direct_party_active_pet_for(human)
    end
    return nil if human == nil
    return nil unless human.id.to_i == ALBERT_CG::SOLO_HUMAN_ACTOR_ID
    return cg_active_pet
  end

  alias cg_pmd_direct_party_owner_pair cg_owner_pet_pair?
  def cg_owner_pet_pair?(human, pet)
    unless ALBERT_CG::DIRECT_PMD_TEST_MODE
      return cg_pmd_direct_party_owner_pair(human, pet)
    end
    return false if human == nil || pet == nil
    return false unless human.id.to_i == ALBERT_CG::SOLO_HUMAN_ACTOR_ID
    return ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.include?(pet.id.to_i)
  end
end

# 資料庫載入完成後，Registry 會重建 Actor/Enemy；因此安全底圖必須在 Registry 後再補一次。
class Scene_Title < Scene_Base
  alias cg_pmd_direct_party_load_database load_database
  def load_database
    cg_pmd_direct_party_load_database
    ALBERT_CG.cg_install_direct_pmd_safe_graphics
  end

  alias cg_pmd_direct_party_load_bt_database load_bt_database
  def load_bt_database
    cg_pmd_direct_party_load_bt_database
    ALBERT_CG.cg_install_direct_pmd_safe_graphics
  end
end
