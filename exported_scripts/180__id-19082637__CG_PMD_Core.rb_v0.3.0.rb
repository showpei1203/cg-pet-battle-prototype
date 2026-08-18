# RMVX_SCRIPT_INDEX: 180
# RMVX_SCRIPT_ID: 19082637
# RMVX_SCRIPT_NAME: CG_PMD_Core.rb  v0.3.0
# RMVX_SOURCE_SHA256: ee47e48005170c58d6b08c3beb6b9d9e1129f57facbd4241494fd4678dc22090

#==============================================================================
# ■ CG_PMD_Core.rb  v0.3.0
#------------------------------------------------------------------------------
# 【用途】
#  CG Pet Battle 專用 PMD Runtime Renderer。負責載入 PMD Anim PNG、依編譯資料
#  播放逐格動畫、選擇 8 方向列、套用 anchor、固定戰鬥 45°，並橋接 Tankentai
#  Sprite_Battler 的生命週期。
#
# 【主要機制】
#  1. 依 battler.cg_pmd_sprite_key 判定是否啟用 PMD。
#  2. Idle／Attack／Shoot／Charge／Hurt／Faint 等動作依 AnimData durations 播放。
#  3. RushFrame／HitFrame／ReturnFrame 可供 Action Sequence 等待。
#  4. PMD 不載入 Shadow；Offsets 不在 Runtime 使用。
#  5. PMD Battler 在 Tankentai make_battler 階段直接建立 PMD 本體，不先讀 Kaduki。
#  6. PMD Enemy 不再呼叫 Tankentai 原版 Game_Enemy#base_position。
#     原方法會為了估算高度直接開啟 Battler／Character 圖，這正是正式 PMD
#     Enemy 使用空 battler_name 時仍可能要求舊圖的根因。PMD 改以 screen_x/y
#     當腳底基準，配合 PMD anchor 定位，不需要舊圖高度。
#  7. v0.3.0 起正式戰鬥鎖定原生 45°：我方 :front_left、敵方 :front_right；
#     所有動作共用此規則且 mirror=false。缺少 8 方向 Faint 時優先使用 Hurt。
#
# 【可調參數】
#  方向、Fallback、速度與個別位置請在 CG_PMD_Config 調整；本頁不硬編物種。
#
# 【事件／腳本呼叫方式】
#  sprite.cg_pmd_play("Attack", :auto, false, nil)
#  sprite.cg_pmd_wait(:hit)
#  sprite.cg_pmd_set_view(:front_right)
#
# 【實際範例】
#  sprite.cg_pmd_play("Shoot", :auto, false, nil)
#  sprite.cg_pmd_wait(:hit)      # 等 PMD HitFrame 到達後再繼續 SBS sequence
#
# 【載入位置】
#  必須位於 Tankentai SBS 本體與 CG_PMD_PetIdentity_Bridge 之下，
#  CG_PMD_Tankentai_Bridge / Action Setup 之前。
#==============================================================================
$imported = {} if $imported == nil
$imported["CG_PMD_Core"] = CG_PMD::VERSION

module CG_PMD
  TANKENTAI_MAKE_BATTLER_BYPASS = true unless const_defined?(:TANKENTAI_MAKE_BATTLER_BYPASS)
end

module CG_PMD
  @warned = {}

  def self.warn_once(key, text)
    return if @warned[key]
    @warned[key] = true
    p(text) if DEBUG
  end

  def self.normalize_view(view)
    view = :battle if view == nil
    view = view.to_sym if view.respond_to?(:to_sym)
    return VIEW_ALIASES[view] if VIEW_ALIASES.include?(view)
    return view
  end

  def self.logical_action_name(request)
    return "Idle" if request == nil
    if request.is_a?(Symbol)
      return ACTION_ALIASES[request] || request.to_s
    end
    text = request.to_s
    symbol = text.downcase.to_sym
    return ACTION_ALIASES[symbol] || text
  end

  def self.sprite_data(key)
    return nil if key == nil
    return DATA[key.to_s]
  end

  def self.resolve_action(key, request)
    sprite = sprite_data(key)
    return nil if sprite == nil
    actions = sprite[:actions] || {}
    wanted = logical_action_name(request)
    candidates = ACTION_FALLBACKS[wanted] || [wanted, "Idle"]

    # 正式戰鬥要求所有身體動作都維持 45°。PMD 某些 Sleep / EventSleep
    # 只有單方向，因此在鎖定 45° 時，優先從 fallback 候選中找 8 方向動作。
    # 例如缺 Faint 時會優先 Hurt，而不是落回單方向 Sleep。
    if defined?(LOCK_BATTLE_VIEW_45) && LOCK_BATTLE_VIEW_45
      candidates.each do |name|
        meta = actions[name]
        next if meta == nil
        return [name, meta] if meta[:direction_count].to_i >= 8
      end
    end

    candidates.each do |name|
      return [name, actions[name]] if actions[name] != nil
    end
    return nil if actions.empty?
    first = actions.keys.sort[0]
    return [first, actions[first]]
  end

  def self.loop_default?(name)
    return LOOP_ACTIONS.include?(name)
  end

  def self.speed_for(name)
    return ACTION_SPEED[name] || DEFAULT_SPEED
  end

  def self.rows_for(key)
    options = SPRITE_OPTIONS[key.to_s] || {}
    return options[:rows] || DIRECTION_ROWS
  end

  def self.row_for(key, view, direction_count)
    return 0 if direction_count == nil || direction_count <= 1
    view = normalize_view(view)
    rows = rows_for(key)
    row = rows[view]
    row = rows[DEFAULT_BATTLE_SOURCE_VIEW] if row == nil
    row = 0 if row == nil
    return [[row.to_i, 0].max, direction_count - 1].min
  end

  def self.option_for(battler, key)
    result = {}
    sprite = SPRITE_OPTIONS[key.to_s]
    result.merge!(sprite) if sprite
    if battler.actor?
      species_id = actor_species_id(battler)
      extra = SPECIES_OPTIONS[species_id]
    else
      extra = ENEMY_OPTIONS[battler.enemy_id]
    end
    result.merge!(extra) if extra
    return result
  end

  def self.action_view_for(key, action_name)
    return ACTION_VIEWS[[key.to_s, action_name]] if ACTION_VIEWS.include?([key.to_s, action_name])
    return ACTION_VIEWS[action_name]
  end

  def self.position_for(key, action_name, battler)
    if ACTION_POSITION.include?([key.to_s, action_name])
      return ACTION_POSITION[[key.to_s, action_name]]
    end
    option = option_for(battler, key)
    return option[:position] || [0, 0]
  end

  #------------------------------------------------------------------------
  # Tankentai 舊 Battler Pose 名稱反查
  #------------------------------------------------------------------------
  # PMD 已不使用 Kaduki 的 _1/_2/_3 圖，但 Tankentai 既有 Action Sequence
  # 仍會呼叫 WAIT / MOVE_TO / WPN_SWING / SKILL_POSE / DAMAGE 等 Pose。
  # 這裡把「同一個 ANIME Array」反查成名稱，再翻譯成 PMD Native 動作。
  def self.legacy_anime_name(active_action)
    return "" if active_action == nil
    @legacy_anime_name_map = {} if @legacy_anime_name_map == nil
    name = @legacy_anime_name_map[active_action.object_id]
    return name if name != nil
    if defined?(N01) && N01.const_defined?("ANIME")
      N01::ANIME.each do |key, data|
        next unless data.is_a?(Array)
        @legacy_anime_name_map[data.object_id] = key.to_s
      end
    end
    return @legacy_anime_name_map[active_action.object_id] || ""
  end

  def self.legacy_pmd_action(animation_name, active_action, motion_pose = false)
    text = animation_name.to_s.upcase

    # 移動中的 Pose 只負責「身體正在移動」的外觀，不可以自己卡住 Sequence。
    # 受擊位移與勝利跳躍仍保留較符合語意的 Native 動作。
    if motion_pose
      return ["Hurt", nil] if text.include?("DAMAGE")
      return ["Pose", nil] if text.include?("VICTORY")
      return ["Walk", nil]
    end

    return ["Faint", :end] if text.include?("DEATH") || text.include?("DEAD")
    return ["Hurt", :end] if text.include?("DAMAGE") || text.include?("HURT") || text.include?("PAIN")
    return ["Pose", :end] if text.include?("VICTORY") || text.include?("GUARD")
    return ["Charge", :end] if text.include?("SKILL") || text.include?("MAGIC") || text.include?("CAST")
    if text.include?("WPN_") || text.include?("ATTACK") || text.include?("SWING")
      return ["Attack", :hit]
    end
    if text.include?("MOVE") || text.include?("FLEE") || text.include?("EVADE") || text.include?("DASH")
      return ["Walk", :end]
    end
    return ["Idle", :end]
  end
end

module Cache
  def self.pmd_sprite(sprite_key, source_action)
    folder = CG_PMD::ROOT + sprite_key.to_s + "/"
    return load_bitmap(folder, source_action.to_s + "-Anim")
  end
end

module CG_PMD
  class Playback
    attr_reader :key
    attr_reader :logical_name
    attr_reader :action_name
    attr_reader :meta
    attr_reader :frame_index
    attr_reader :view
    attr_reader :mirror_mode
    attr_reader :finished
    attr_reader :hit_reached
    attr_reader :rush_reached
    attr_reader :return_reached

    def initialize(key)
      @key = key.to_s
      @logical_name = "Idle"
      @action_name = "Idle"
      @meta = nil
      @frame_index = 0
      @frame_timer = 1
      @loop = true
      @view = :battle
      @mirror_mode = :sbs
      @finished = false
      @hit_reached = false
      @rush_reached = false
      @return_reached = false
    end

    def start(request, view, loop_value, mirror_mode)
      resolved = CG_PMD.resolve_action(@key, request)
      return false if resolved == nil
      @logical_name = CG_PMD.logical_action_name(request)
      @action_name = resolved[0]
      @meta = resolved[1]
      @view = CG_PMD.normalize_view(view)
      @loop = loop_value == nil ? CG_PMD.loop_default?(@action_name) : loop_value
      @mirror_mode = mirror_mode == nil ? :sbs : mirror_mode
      @frame_index = 0
      @finished = false
      @hit_reached = false
      @rush_reached = false
      @return_reached = false
      mark_events
      @frame_timer = duration_for(0)
      return true
    end

    def set_view(view)
      @view = CG_PMD.normalize_view(view)
    end

    def set_mirror_mode(mode)
      @mirror_mode = mode
    end

    def duration_for(index)
      values = @meta[:durations] || [4]
      raw = values[index] || values[-1] || 4
      fps_rate = Graphics.frame_rate.to_f / 60.0
      speed = CG_PMD.speed_for(@action_name)
      frames = (raw.to_f * fps_rate * speed).round
      return [frames, 1].max
    end

    def tick
      return if @meta == nil || (@finished && !@loop)
      @frame_timer -= 1
      return if @frame_timer > 0
      @frame_index += 1
      frame_count = @meta[:frame_count].to_i
      if @frame_index >= frame_count
        if @loop
          @frame_index = 0
          @hit_reached = false
          @rush_reached = false
          @return_reached = false
        else
          @frame_index = [frame_count - 1, 0].max
          @finished = true
          return
        end
      end
      mark_events
      @frame_timer = duration_for(@frame_index)
    end

    def mark_events
      @rush_reached = true if @meta[:rush_frame] != nil && @frame_index >= @meta[:rush_frame].to_i
      @hit_reached = true if @meta[:hit_frame] != nil && @frame_index >= @meta[:hit_frame].to_i
      @return_reached = true if @meta[:return_frame] != nil && @frame_index >= @meta[:return_frame].to_i
    end

    def reached?(condition)
      case condition
      when :hit
        return @finished if @meta[:hit_frame] == nil
        return @hit_reached
      when :rush
        return @finished if @meta[:rush_frame] == nil
        return @rush_reached
      when :return
        return @finished if @meta[:return_frame] == nil
        return @return_reached
      when :end
        return @finished
      else
        return true
      end
    end
  end
end

#==============================================================================
# ■ Game_Enemy：PMD 專用初始站位
#------------------------------------------------------------------------------
# Tankentai 原版 Game_Enemy#base_position 會先開舊 Battler／Kaduki 圖取得高度，
# 再把 y 往上移 height/3；PMD 已使用 anchor_y 表示腳底，因此正確基準就是
# Troop member 的 screen_y，不需要再依舊圖高度修正。
#==============================================================================
class Game_Enemy < Game_Battler
  def cg_pmd_base_position
    return if self.index == nil
    plus = self.position_plus
    plus = [0, 0] if plus == nil
    @base_position_x = self.screen_x + plus[0].to_i
    @base_position_y = self.screen_y + plus[1].to_i
    if defined?($back_attack) && $back_attack && N01::BACK_ATTACK
      @base_position_x = Graphics.width - self.screen_x - plus[0].to_i
    end
    return [@base_position_x, @base_position_y]
  end
end

class Sprite_Battler < Sprite_Base
  alias cg_pmd_initialize initialize
  def initialize(viewport, battler = nil)
    cg_pmd_initialize(viewport, battler)
    @cg_pmd_playback = nil
    @cg_pmd_key = nil
    @cg_pmd_wait_condition = nil
    @cg_pmd_legacy_wait_condition = nil
    @cg_pmd_motion_pose = false
    cg_pmd_ensure_playback
    cg_pmd_hide_shadow
  end

  alias cg_pmd_update update
  def update
    cg_pmd_ensure_playback
    @cg_pmd_playback.tick if @cg_pmd_playback != nil
    cg_pmd_release_wait
    cg_pmd_release_legacy_anime
    cg_pmd_update
    cg_pmd_apply_frame
    cg_pmd_hide_shadow
  end

  #--------------------------------------------------------------------------
  # ● Tankentai Battler 建立橋接
  #--------------------------------------------------------------------------
  # Tankentai 原版 make_battler 會先讀 Actor#character_name；WALK_ANIME=false
  # 時還會自動補上 "_1"。正式 PMD Actor 的 character_name 刻意留空，因此
  # 若先走原流程就會錯誤要求 Graphics/Characters/_1。
  #
  # PMD Battler 在此完整建立 Tankentai 仍需要的輔助 Sprite，但本體 bitmap
  # 從第一幀開始直接由 PMD Renderer 提供。非 PMD Battler 完全走原流程。
  alias cg_pmd_make_battler make_battler
  def make_battler
    return cg_pmd_make_battler unless cg_pmd_active?

    # Actor 的 Tankentai base_position 只讀設定座標，可以安全沿用。
    # Enemy 原版 base_position 會直接讀 Graphics/Battlers 或 Characters/*_1
    # 取得 bitmap.height，因此 PMD Enemy 必須完全繞過。
    if @battler.actor?
      @battler.base_position
    elsif @battler.respond_to?(:cg_pmd_base_position)
      @battler.cg_pmd_base_position
    else
      @battler.base_position
    end
    @battler_hue = @battler.battler_hue
    @anime_flug = true

    # Tankentai 後續 Action Sequence 仍會操作武器／移動動畫／傷害 Sprite。
    @weapon_R = Sprite_Weapon.new(viewport, @battler)
    @battler_name = ""

    @battler.reset_coordinate
    cg_pmd_ensure_playback
    cg_pmd_apply_frame

    # 正常情況 PMD bitmap 一定存在。若素材意外遺失，至少維持 Sprite 可用，
    # 讓警告與 LOG 能留下來；絕不退回舊 Kaduki _1 路徑。
    if self.bitmap == nil
      self.bitmap = Bitmap.new(1, 1)
      @width = 1
      @height = 1
      self.src_rect.set(0, 0, 1, 1)
      self.ox = 0
      self.oy = 0
      CG_PMD.warn_once([:pmd_make_battler_blank, @cg_pmd_key],
        "CG_PMD：#{@cg_pmd_key} 建立 Battler 時未取得 PMD bitmap，暫用 1x1 安全圖。")
    end

    @sx = 0
    @sy = 0
    update_move
    @move_anime = Sprite_MoveAnime.new(viewport, @battler)
    @picture = Sprite.new
    @damage = Sprite_Damage.new(viewport, @battler)
    return
  end

  #--------------------------------------------------------------------------
  # ● Tankentai Kaduki Pose → PMD Native 動作橋接
  #--------------------------------------------------------------------------
  # 重要：這裡不是「找不到 _n 就塞透明圖」。PMD Battler 根本不再呼叫
  # Cache.character(character_name + "_n")。原 SBS Sequence 可繼續負責位移、
  # OBJ_ANIM、傷害與等待，而身體 Pose 改由 PMD XML 動作播放。
  alias cg_pmd_legacy_battler_anime battler_anime
  def battler_anime
    return cg_pmd_legacy_battler_anime unless cg_pmd_active?

    animation_name = CG_PMD.legacy_anime_name(@active_action)
    request, wait_condition = CG_PMD.legacy_pmd_action(
      animation_name, @active_action, @cg_pmd_motion_pose)

    # 保留 Tankentai 仍會讀取的流程欄位，但不再讓它管理本體 src_rect。
    @anime_kind = 0
    @anime_speed = 1
    @anime_loop = 2
    @unloop_wait = @active_action[4].to_i
    @reverse = false
    @anime_freeze = false
    @pattern = 0
    @pattern_back = false
    @frame = 1
    @battler.move_z = @active_action[6].to_i if @active_action.size > 6

    # 寶可夢沒有 Kaduki 武器 Pose；舊 Weapon Sprite 必須清空，避免第二套圖層。
    if @weapon_R != nil
      begin
        @weapon_R.action_reset
      rescue
      end
    end
    @weapon_action = false
    cg_pmd_hide_shadow

    cg_pmd_play(request, :auto, false, nil)

    fixed = false
    if @active_action.size > 5
      fixed = (@active_action[5] != -1 && @active_action[5] != -2)
    end
    if @cg_pmd_motion_pose || fixed
      @cg_pmd_legacy_wait_condition = nil
      @anime_end = true
    else
      @cg_pmd_legacy_wait_condition = wait_condition || :end
      @anime_end = false
    end
    cg_pmd_apply_frame
    return
  end

  # PMD 的 frame/duration 完全由 Playback 控制；禁止 Tankentai 的 4 格 Kaduki
  # update_anime_pattern 再次改 src_rect 或用舊 Pose 結束條件干擾 PMD。
  alias cg_pmd_legacy_update_anime_pattern update_anime_pattern
  def update_anime_pattern
    return if cg_pmd_active?
    cg_pmd_legacy_update_anime_pattern
  end

  # moving / reseting / floating 會在方法內把「移動時 Pose」改寫成另一個
  # N01::ANIME 並直接呼叫 battler_anime。加旗標後 Native 動作只跟著播放，
  # 不接管移動 Sequence 的等待條件。
  alias cg_pmd_legacy_moving moving
  def moving
    return cg_pmd_legacy_moving unless cg_pmd_active?
    @cg_pmd_motion_pose = true
    begin
      result = cg_pmd_legacy_moving
    ensure
      @cg_pmd_motion_pose = false
      @cg_pmd_legacy_wait_condition = nil
    end
    return result
  end

  alias cg_pmd_legacy_reseting reseting
  def reseting
    return cg_pmd_legacy_reseting unless cg_pmd_active?
    @cg_pmd_motion_pose = true
    begin
      result = cg_pmd_legacy_reseting
    ensure
      @cg_pmd_motion_pose = false
      @cg_pmd_legacy_wait_condition = nil
    end
    return result
  end

  alias cg_pmd_legacy_floating floating
  def floating
    return cg_pmd_legacy_floating unless cg_pmd_active?
    @cg_pmd_motion_pose = true
    begin
      result = cg_pmd_legacy_floating
    ensure
      @cg_pmd_motion_pose = false
      @cg_pmd_legacy_wait_condition = nil
    end
    return result
  end

  # Transform / graphics-change 類舊指令若落到 PMD，不得再打開 Character _1。
  # 身分／Form 若真的變更，cg_pmd_ensure_playback 會在下一次 update 依 key 重建。
  alias cg_pmd_legacy_graphics_change graphics_change
  def graphics_change
    return cg_pmd_legacy_graphics_change unless cg_pmd_active?
    if @battler.actor? && @active_action != nil && @active_action.size > 2
      @before_graphic = @battler.character_name if @active_action[1]
      begin
        @battler.graphic_change(@active_action[2])
      rescue
      end
    end
    @anime_end = true
    return
  end

  def cg_pmd_release_legacy_anime
    return unless cg_pmd_active?
    return if @cg_pmd_legacy_wait_condition == nil
    return if @cg_pmd_playback == nil
    if @cg_pmd_playback.reached?(@cg_pmd_legacy_wait_condition)
      @cg_pmd_legacy_wait_condition = nil
      @anime_end = true
    else
      @anime_end = false
    end
  end

  alias cg_pmd_update_battler_bitmap update_battler_bitmap
  def update_battler_bitmap
    if cg_pmd_active?
      cg_pmd_apply_frame
      return
    end
    cg_pmd_update_battler_bitmap
  end

  alias cg_pmd_make_shadow make_shadow
  def make_shadow
    if cg_pmd_active?
      if @shadow != nil
        @shadow.dispose if @shadow.respond_to?(:disposed?) && !@shadow.disposed?
      end
      if @cg_pmd_shadow_bitmap != nil && !@cg_pmd_shadow_bitmap.disposed?
        @cg_pmd_shadow_bitmap.dispose
      end
      @shadow = Sprite.new(viewport)
      @cg_pmd_shadow_bitmap = Bitmap.new(1, 1)
      @shadow.bitmap = @cg_pmd_shadow_bitmap
      @shadow.visible = false
      @shadow_height = 1
      @shadow_plus_x = 0
      @shadow_plus_y = 0
      return
    end
    cg_pmd_make_shadow
  end

  alias cg_pmd_dispose dispose
  def dispose
    cg_pmd_dispose
    if @cg_pmd_shadow_bitmap != nil && !@cg_pmd_shadow_bitmap.disposed?
      @cg_pmd_shadow_bitmap.dispose
    end
    @cg_pmd_shadow_bitmap = nil
  end

  def cg_pmd_active?
    return false if @battler == nil
    return @battler.cg_pmd_enabled?
  end

  def cg_pmd_ensure_playback
    return unless cg_pmd_active?
    key = @battler.cg_pmd_sprite_key.to_s
    return if @cg_pmd_playback != nil && @cg_pmd_key == key
    @cg_pmd_key = key
    @cg_pmd_playback = CG_PMD::Playback.new(key)
    view = cg_pmd_battle_locked_45? ? :battle : cg_pmd_default_view
    mirror_mode = cg_pmd_battle_locked_45? ? false : :sbs
    @cg_pmd_playback.start("Idle", view, true, mirror_mode)
  end

  # 正式 CG Pet Battle 的 PMD Sprite_Battler 全都在戰鬥場景使用。
  # LOCK_BATTLE_VIEW_45 開啟後，不允許舊 Action Sequence 臨時切成 front/side。
  def cg_pmd_battle_locked_45?
    return false unless defined?(CG_PMD::LOCK_BATTLE_VIEW_45)
    return false unless CG_PMD::LOCK_BATTLE_VIEW_45
    return false if @battler == nil
    return true
  end

  def cg_pmd_battle_side_view
    return CG_PMD::BATTLE_ALLY_VIEW if @battler != nil && @battler.actor?
    return CG_PMD::BATTLE_ENEMY_VIEW
  end

  def cg_pmd_default_view
    note_view = @battler.cg_pmd_note_view
    return note_view if note_view != nil
    option = CG_PMD.option_for(@battler, @cg_pmd_key)
    return option[:view] || CG_PMD::DEFAULT_VIEW
  end

  def cg_pmd_direction_mode
    note_mode = @battler.cg_pmd_note_direction_mode
    return note_mode if note_mode != nil
    option = CG_PMD.option_for(@battler, @cg_pmd_key)
    return option[:direction_mode] || CG_PMD::DEFAULT_DIRECTION_MODE
  end

  def cg_pmd_play(request, view = :auto, loop_value = nil, mirror_mode = nil)
    cg_pmd_ensure_playback
    return false if @cg_pmd_playback == nil
    if cg_pmd_battle_locked_45?
      # 戰鬥中任何 Idle/Attack/Shoot/Charge/Hurt/Faint/舊 Pose 翻譯都固定 45°。
      view = :battle
      mirror_mode = false
    else
      if view == nil || view == :auto
        action_view = CG_PMD.action_view_for(@cg_pmd_key, CG_PMD.logical_action_name(request))
        view = action_view || cg_pmd_default_view
      end
      mode = cg_pmd_direction_mode
      view = :battle if mode == :sbs
      mirror_mode = false if mode == :native && mirror_mode == nil
      mirror_mode = :sbs if mode == :hybrid && mirror_mode == nil
    end
    result = @cg_pmd_playback.start(request, view, loop_value, mirror_mode)
    if !result
      CG_PMD.warn_once(
        [:missing_action, @cg_pmd_key, request.to_s],
        "CG_PMD：#{@cg_pmd_key} 找不到 #{request} 或 fallback 動作。"
      )
    end
    return result
  end

  def cg_pmd_set_view(view)
    cg_pmd_ensure_playback
    return if @cg_pmd_playback == nil
    # 正式戰鬥鎖 45° 後，舊 PMD_VIEW_FRONT / BACK 指令不再改變身體方向。
    @cg_pmd_playback.set_view(cg_pmd_battle_locked_45? ? :battle : view)
  end

  def cg_pmd_set_mirror(mode)
    cg_pmd_ensure_playback
    @cg_pmd_playback.set_mirror_mode(mode) if @cg_pmd_playback
  end

  def cg_pmd_wait(condition)
    @cg_pmd_wait_condition = condition
    @anime_end = false
    cg_pmd_release_wait
  end

  def cg_pmd_release_wait
    return if @cg_pmd_wait_condition == nil || @cg_pmd_playback == nil
    if @cg_pmd_playback.reached?(@cg_pmd_wait_condition)
      @cg_pmd_wait_condition = nil
      @anime_end = true
    end
  end

  def cg_pmd_sbs_mirror?
    # PMD battle source 固定使用 :left。正常戰鬥中右側我方直接朝左，
    # 左側敵方水平反轉後朝右；背襲時兩者交換。不要再依賴 Kaduki 專用
    # action_mirror，否則只要 Enemy 不使用 $Actor 安全圖，方向就會再次顛倒。
    back_attack = defined?($back_attack) && $back_attack
    if back_attack
      return @battler.actor? ? true : false
    end
    return @battler.actor? ? false : true
  end

  def cg_pmd_effective_view
    # 正式規則：我方固定左下 45°、敵方固定右下 45°。
    # 不論 Tankentai 當前是 WAIT / MOVE / ATTACK / SKILL / DAMAGE / DEATH，
    # 身體方向都不應被切回純 Sideview。
    return cg_pmd_battle_side_view if cg_pmd_battle_locked_45?
    view = CG_PMD.normalize_view(@cg_pmd_playback.view)
    return CG_PMD::DEFAULT_BATTLE_SOURCE_VIEW if view == :battle
    return view
  end

  def cg_pmd_effective_mirror
    # 45° 使用 PMD 原生左右斜角列，絕不做水平 mirror。
    return false if cg_pmd_battle_locked_45?
    mode = @cg_pmd_playback.mirror_mode
    return mode if mode == true || mode == false
    view = CG_PMD.normalize_view(@cg_pmd_playback.view)
    return false if cg_pmd_direction_mode == :native
    return cg_pmd_sbs_mirror? if view == :battle || cg_pmd_direction_mode == :sbs
    return false
  end

  def cg_pmd_apply_frame
    return unless cg_pmd_active?
    cg_pmd_ensure_playback
    return if @cg_pmd_playback == nil || @cg_pmd_playback.meta == nil
    meta = @cg_pmd_playback.meta
    bitmap = Cache.pmd_sprite(@cg_pmd_key, meta[:source])
    self.bitmap = bitmap if self.bitmap != bitmap
    @width = meta[:frame_width].to_i
    @height = meta[:frame_height].to_i
    direction_count = meta[:direction_count].to_i
    row = CG_PMD.row_for(@cg_pmd_key, cg_pmd_effective_view, direction_count)
    sx = @cg_pmd_playback.frame_index * @width
    sy = row * @height
    self.src_rect.set(sx, sy, @width, @height)
    position = CG_PMD.position_for(@cg_pmd_key, @cg_pmd_playback.action_name, @battler)
    fix_x = position[0].to_i
    fix_y = position[1].to_i
    self.ox = meta[:anchor_x].to_i - fix_x
    self.oy = meta[:anchor_y].to_i - fix_y
    self.mirror = cg_pmd_effective_mirror
  rescue => error
    CG_PMD.warn_once(
      [:missing_png, @cg_pmd_key, @cg_pmd_playback.meta[:source]],
      "CG_PMD：無法載入 #{@cg_pmd_key}/#{@cg_pmd_playback.meta[:source]}-Anim.png：#{error}"
    )
  end

  def cg_pmd_hide_shadow(dispose = false)
    return if !cg_pmd_active? && !dispose
    if @shadow != nil
      @shadow.visible = false if @shadow.respond_to?(:visible=)
      if dispose && @shadow.respond_to?(:disposed?) && !@shadow.disposed?
        @shadow.dispose
        @shadow = nil
      end
    end
  end
end
