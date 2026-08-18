# RMVX_SCRIPT_INDEX: 177
# RMVX_SCRIPT_ID: 45556864
# RMVX_SCRIPT_NAME: CG_PMD_Config.rb  v0.3.0
# RMVX_SOURCE_SHA256: e8298d9e685c46073df8e2d10301c09de42dc93bdadfffd8368efb5cfa129342

#==============================================================================
# ■ CG_PMD_Config.rb  v0.3.0
#------------------------------------------------------------------------------
# 【用途】
#  PMD Collab 戰鬥 Sprite Adapter 的全域設定。統一管理素材根目錄、方向列、
#  動作名稱／Fallback、播放速度、物種 Actor／Enemy 對 PMD key 的綁定。
#
# 【主要設定項】
#  ROOT                    ：PMD Anim PNG 根目錄。
#  DEFAULT_DIRECTION_MODE  ：:hybrid / :native / :sbs。
#  DIRECTION_ROWS          ：PMD 8 方向對應列。
#  ACTION_ALIASES          ：遊戲邏輯動作 → PMD 動作名稱。
#  ACTION_FALLBACKS        ：缺少指定動作時的安全替代順序。
#  ACTION_SPEED            ：個別動作播放速度倍率。
#  SPECIES_SPRITES         ：物種／Form Actor ID → 四位數 PMD key。
#  ENEMY_SPECIES           ：Enemy ID → 物種／Form Actor ID。
#
# 【機制規則】
#  1. PMD key 綁定的是「物種／目前 Form」，不是捕捉後的動態 Clone Actor ID。
#  2. PMD 寶可夢在戰鬥中不使用 Kaduki character_name 作為本體圖。
#  3. Offsets 僅編譯期參考；Shadow 不顯示。
#  4. 正式戰鬥鎖定 PMD 原生 45°：我方 :front_left、敵方 :front_right，且不 mirror。
#
# 【可調參數範例】
#  ACTION_SPEED["Attack"] = 0.9       # 攻擊稍快
#  SPRITE_OPTIONS["0025"] = { :position => [0, -3] }
#
# 【腳本呼叫範例】
#  CG_PMD.sprite_data("0025")          # 取得皮卡丘編譯資料
#  CG_PMD.resolve_action("0025", "Attack")
#
# 【專案邊界】
#  僅適配 CG Pet Battle Prototype / RPG Maker VX / RGSS2 / Tankentai SBS。
#  不混用 Forest Symphony 的 ActorProfile、ArmorMapping、召喚、ATB 或魂刻。
#==============================================================================
module CG_PMD
  VERSION = "0.3.0"
  ROOT = "Graphics/PMDSprites/"

  # :hybrid  = 舊相容模式；battle 視角可搭配 SBS mirror。
  # :native  = 一律使用 PMD 原生方向列，不使用 SBS mirror（正式預設）。
  # :sbs     = 舊 Sideview 相容模式。
  #
  # 正式規則：LOCK_BATTLE_VIEW_45=true 時，不論 Idle / Walk / Attack / Shoot /
  # Charge / Hurt / Faint / Pose，戰鬥 Sprite 都固定使用：
  #   我方 :front_left（左下 45°）
  #   敵方 :front_right（右下 45°）
  # 正式戰鬥一律採 PMD 原生 45 度方向，不再以 Sideview + mirror 模擬。
  # 我方在畫面右側，固定朝左下；敵方在畫面左側，固定朝右下。
  DEFAULT_DIRECTION_MODE = :native
  DEFAULT_VIEW = :battle
  LOCK_BATTLE_VIEW_45 = true
  BATTLE_ALLY_VIEW = :front_left
  BATTLE_ENEMY_VIEW = :front_right
  # 僅供非戰鬥或舊 API 缺省回退，不再作正式 Sideview 基準。
  DEFAULT_BATTLE_SOURCE_VIEW = :front_left

  DIRECTION_ROWS = {
    :front       => 0,
    :front_right => 1,
    :right       => 2,
    :back_right  => 3,
    :back        => 4,
    :back_left   => 5,
    :left        => 6,
    :front_left  => 7,
  }

  VIEW_ALIASES = {
    :down       => :front,
    :down_right => :front_right,
    :up         => :back,
    :up_right   => :back_right,
    :up_left    => :back_left,
    :down_left  => :front_left,
  }

  ACTION_ALIASES = {
    :idle     => "Idle",
    :walk     => "Walk",
    :move     => "Walk",
    :attack   => "Attack",
    :physical => "Attack",
    :shoot    => "Shoot",
    :magic    => "Charge",
    :skill    => "Charge",
    :hurt     => "Hurt",
    :pain     => "Pain",
    :guard    => "Pose",
    :sleep    => "Sleep",
    :faint    => "Faint",
    :victory  => "Pose",
    :item     => "Eat",
  }

  ACTION_FALLBACKS = {
    "Idle"   => ["Idle", "Walk", "Pose"],
    "Walk"   => ["Walk", "Idle"],
    "Attack" => ["Attack", "Strike", "Swing", "Double", "Charge", "Idle"],
    "Shoot"  => ["Shoot", "Attack", "Strike", "Idle"],
    "Charge" => ["Charge", "DeepBreath", "Pose", "Attack", "Idle"],
    "Hurt"   => ["Hurt", "Pain", "Shake", "Idle"],
    "Pain"   => ["Pain", "Hurt", "Shake", "Idle"],
    "Pose"   => ["Pose", "Charge", "Idle"],
    "Sleep"  => ["Sleep", "EventSleep", "Idle"],
    # 為維持 45°，缺 Faint 時優先使用具有 8 方向的 Hurt；Sleep 很多只有 1 方向。
    "Faint"  => ["Faint", "Hurt", "Sleep", "Idle"],
    "Eat"    => ["Eat", "Pose", "Idle"],
  }

  LOOP_ACTIONS = ["Idle", "Walk", "Sleep", "EventSleep", "Float"]

  ACTION_SPEED = {
    "Idle"   => 1.0,
    "Walk"   => 1.0,
    "Attack" => 1.0,
    "Hurt"   => 1.0,
    "Faint"  => 1.0,
  }
  DEFAULT_SPEED = 1.0

  #--------------------------------------------------------------------------
  # 物種 Actor ID → PMD 資料夾 key
  #--------------------------------------------------------------------------
  # 這裡填的是「物種模板 Actor ID」，不是捕捉後動態產生的 Clone Actor ID。
  # 主角沒有列在這裡，就會繼續使用原本的人類 Battler 圖。
  SPECIES_SPRITES = {
    # 101 => "0001",  # 妙蛙種子模板 Actor ID
    # 102 => "0002",  # 妙蛙草模板 Actor ID
  }

  # Enemy ID → 物種 Actor ID。野生敵人由此找到與寵物實例相同的 PMD key。
  # Enemy 本身也可在 Note 使用 <pmd sprite:0001> 直接覆蓋。
  ENEMY_SPECIES = {
    # 201 => 101,
  }

  # Enemy ID → PMD key 的直接覆蓋。優先於 ENEMY_SPECIES。
  ENEMY_SPRITES = {
    # 201 => "0001",
  }

  # Clone／寵物系統可能已經保存物種來源。Adapter 會依序嘗試讀取這些方法。
  # 只有回傳值存在於 SPECIES_SPRITES 時才採用，不會因同名方法誤判人類角色。
  SPECIES_READER_METHODS = [
    :pet_species_id,
    :species_actor_id,
    :species_id,
    :base_actor_id,
    :original_actor_id,
    :source_actor_id,
    :clone_source_id,
    :template_actor_id,
  ]

  # 每個 PMD key 的視角、方向與位置設定。
  SPRITE_OPTIONS = {
    # "0001" => { :view => :battle, :position => [0, 0] },
  }

  # 以物種模板 Actor ID 覆蓋設定，不使用動態 Clone Actor ID。
  SPECIES_OPTIONS = {
    # 101 => { :view => :back, :direction_mode => :hybrid },
  }

  ENEMY_OPTIONS = {
    # 201 => { :view => :front },
  }

  ACTION_VIEWS = {
    # ["0001", "Charge"] => :front,
    # "Roar" => :front,
  }

  ACTION_POSITION = {
    # ["0001", "Attack"] => [0, -4],
  }

  DEBUG = true
end
