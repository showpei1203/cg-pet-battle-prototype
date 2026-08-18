# RMVX_SCRIPT_INDEX: 98
# RMVX_SCRIPT_ID: 85954847
# RMVX_SCRIPT_NAME: Sideview 1 (3.3)
# RMVX_SOURCE_SHA256: fdb2bb237199187aa90d8ce01d30a602687a13034f06151765ae5e68d068e12e

#==============================================================================
# ■ Sprite_Battler  for Sideview Ver3.3
#------------------------------------------------------------------------------
# 　バトラー表示用のスプライトです。
#==============================================================================
class Sprite_Battler < Sprite_Base
  #--------------------------------------------------------------------------
  # ● オブジェクト初期化
  #--------------------------------------------------------------------------
  def initialize(viewport, battler = nil)
    super(viewport)
    @battler = battler
    @battler_visible = false
    @effect_type = 0                   # エフェクトの種類
    @effect_duration = 0               # エフェクトの残り時間
    @move_x = 0                        # 変化したX座標の累計
    @move_y = 0                        # 変化したY座標の累計
    @move_z = 0                        # 変化したZ座標の累計
    @distanse_x = 0                    # X座標の移動距離
    @distanse_y = 0                    # Y座標の移動距離
    @moving_x = 0                      #１フレームあたりのX座標移動距離
    @moving_y = 0                      #１フレームあたりのY座標移動距離
    @move_speed_x = 0                  # X座標の移動速度
    @move_speed_y = 0                  # Y座標の移動速度
    @move_speed_plus_x = 0             # X座標の加減速時の補足移動速度
    @move_speed_plus_y = 0             # Y座標の加減速時の補足移動速度
    @move_boost_x = 0                  # X座標加速度
    @move_boost_y = 0                  # Y座標加速度
    @jump_time = 0                     # ジャンプ時間
    @jump_time_plus = 0                # ジャンプ時間補足
    @jump_up = 0                       # ジャンプ上昇
    @jump_down = 0                     # ジャンプ下降
    @jump_size = 0                     # ジャンプ高度
    @float_time = 0                    # 浮遊時間
    @float_up = 0                      # １フレームあたりの浮遊高度
    @jump_plus = 0                     # ジャンプに対する影位置補正
    @angle = 0                         # 回転角度
    @angling = 0                       # １フレームあたりの回転角度
    @angle_time = 0                    # 回転時間
    @angle_reset = 0                   # 角度をリセットするか
    @zoom_x = 0                        # 横の拡大率
    @zoom_y = 0                        # 縦の拡大率
    @zooming_x = 0                     # １フレームあたりの横拡大率
    @zooming_y = 0                     # １フレームあたりの縦拡大率
    @zoom_time = 0                     # 拡大時間
    @zoom_reset = 0                    # 拡大をリセットするか
    @target_battler = []               # ターゲットバトラー情報
    @now_targets = []                  # ターゲットバトラー記憶
    @pattern = 0                       # セル横位置（更新位置）
    @pattern_back = false              # リピートフラグ
    @wait = 0                          # 次の動作待ち時間
    @unloop_wait = 0                   # 非ループ系アニメ終了時の待ち時間
    @action = []                       # 行動
    @anime_kind = 0                    # セル縦位置（アニメ種類位置）
    @anime_speed = 0                   # セル更新速度
    @frame = 0                         # 消費されるセル更新時間
    @anime_loop = 0                    # ループ方式
    @anime_end = false                 # バトラーのアニメが終わったか
    @anime_freeze = false              # 固定アニメか
    @anime_freeze_kind = false         # 固定するパターン位置
    @anime_moving = false              # 飛ばしアニメ中か
    @base_width = N01::ANIME_PATTERN   # セルの横分割数
    @base_height = N01::ANIME_KIND     # セルの縦分割数
    @width = 0                         # 横矩形
    @height = 0                        # 縦矩形
    @picture_time = 0                  # ピクチャー表示時間
    @individual_targets = []           # 個別処理の保持ターゲット
    @balloon_duration = 65             # ふきだしアニメ時間
    @reverse = false                   # アニメ逆転再生フラグ
    # バトラーがいない場合は処理を中断
    return @battler_visible = false if @battler == nil
    # バトラーがアクターの場合、またはエネミーアニメがオンの場合
    @anime_flug = true if @battler.actor?
    @anime_flug = true if !@battler.actor? && @battler.anime_on
  end
  #--------------------------------------------------------------------------
  # ● バトラー作成
  #--------------------------------------------------------------------------
  def make_battler
    # 初期配置の取得
    @battler.base_position
    # 色相はバトラーとして認識
    @battler_hue = @battler.battler_hue
    # バトラーがアクターの場合、またはエネミーアニメがオンの場合
    if @anime_flug
      # メイン武器を用意
      @weapon_R = Sprite_Weapon.new(viewport,@battler)
      # 味方はキャラクター名、エネミーはバトラー名を取得
      @battler_name = @battler.character_name if @battler.actor?
      @battler_name = @battler.battler_name unless @battler.actor?
      # エネミー反転がオンの場合、画像を反転させる
      self.mirror = true if !@battler.actor? && @battler.action_mirror
      # 歩行グラフィックを利用するかどうかで転送元の矩形サイズの認識先を変える
      self.bitmap = Cache.character(@battler_name) if N01::WALK_ANIME
      self.bitmap = Cache.character(@battler_name + "_1") unless N01::WALK_ANIME
      # 転送元の矩形を取得
      @width = self.bitmap.width / @base_width
      @height = self.bitmap.height / @base_height
      # 矩形を設定
      @sx = @pattern * @width
      @sy = @anime_kind * @height
      # バトラー本体を描画
      self.src_rect.set(@sx, @sy, @width, @height)
    # アニメしないバトラーの場合
    else
      # ビットマップを取得、設定
      @battler_name = @battler.battler_name
      self.bitmap = Cache.battler(@battler_name, @battler_hue)
      @width = bitmap.width
      @height = bitmap.height
    end
    # バックアタック時には画像を反転させる
    if $back_attack && @battler.actor?
      self.mirror = true
    elsif $back_attack && !@battler.actor? 
      self.mirror = true
      self.mirror = false if @battler.action_mirror
    else
      self.mirror = false
      self.mirror = true if !@battler.actor? && @battler.action_mirror
    end
    # 武器画像に反映
    @weapon_R.mirroring if self.mirror && @weapon_R != nil
    # 位置を初期化
    @battler.reset_coordinate
    # 原点を決定
    self.ox = @width / 2
    self.oy = @height * 2 / 3
    # スプライトの座標を設定
    update_move
    # アニメ飛ばし用スプライトを用意
    @move_anime = Sprite_MoveAnime.new(viewport,battler)
    # ピクチャ用スプライトを用意
    @picture = Sprite.new
    # ダメージスプライト作成
    @damage = Sprite_Damage.new(viewport,battler)
  end
  #--------------------------------------------------------------------------
  # ● 影作成
  #--------------------------------------------------------------------------
  def make_shadow
    @shadow.dispose if @shadow != nil
    @battler_hue = @battler.battler_hue
    @shadow = Sprite.new(viewport)
    @shadow.z = self.z - 4
    @shadow.visible = false
    # バトラーに当てられた影グラフィックを用意
    @shadow.bitmap = Cache.character(@battler.shadow)
    @shadow_height = @shadow.bitmap.height
    # 影位置の微調整用インスタンス
    @shadow_plus_x = @battler.shadow_plus[0] - @width / 2
    @shadow_plus_y = @battler.shadow_plus[1]
    # バトラー画像のサイズに合わせて影画像をリサイズ
    @shadow.zoom_x = @width * 1.0 / @shadow.bitmap.width
    # 更新
    update_shadow
  end
  #--------------------------------------------------------------------------
  # ● 解放
  #--------------------------------------------------------------------------
  def dispose
    self.bitmap.dispose if self.bitmap != nil
    @weapon_R.dispose if @weapon_R != nil
    @move_anime.dispose if @move_anime != nil
    @picture.dispose if @picture != nil
    @shadow.dispose if @shadow != nil
    @damage.dispose if @damage != nil
    @balloon.dispose if @balloon != nil
    mirage_off
    # 画像変更リセット
    @battler.graphic_change(@before_graphic) if @before_graphic != nil
    super
  end  
  #--------------------------------------------------------------------------
  # ● ダメージアクション  action = [アニメID,反転フラグ,リアクション許可]
  #--------------------------------------------------------------------------
  def damage_action(action)
    damage = @battler.hp_damage
    damage = @battler.mp_damage if @battler.mp_damage != 0
    # HPとMP両方同時にダメージがあるなら
    if @battler.hp_damage != 0 && @battler.mp_damage != 0
      @battler.double_damage = true
      damage = @battler.hp_damage
    end  
    # 吸収攻撃でHP0の処理
    if action[0] == "absorb"
      absorb = true
      action[0] = nil
    end
    # ヒットしている時のみアニメ実行
    unless @battler.evaded or @battler.missed or action[0] == nil
      @battler.animation_id = action[0] 
      @battler.animation_mirror = action[1]
    end
    # ダメージアクション実行
    start_action(@battler.damage_hit) if damage > 0 && action[2]
    # 攻撃が当たっていない場合は回避アクション実行
    if @battler.evaded or @battler.missed
      start_action(@battler.evasion) if action[2]
      Sound.play_evasion
    end
    @damage.damage_pop unless absorb or action[3] != nil
  end
  #--------------------------------------------------------------------------
  # ● ダメージ数値POP
  #--------------------------------------------------------------------------
  def damage_pop(damage)
    @damage.damage_pop(damage)
  end  
  #--------------------------------------------------------------------------
  # ● 戦闘開始行動 
  #--------------------------------------------------------------------------
  def first_action
    # 行動できるかチェックし、できなければそのステートのアクション開始
    action = @battler.first_action unless @battler.restriction >= 4
    action = $data_states[@battler.state_id].base_action if @battler.states[0] != nil && @battler.restriction >= 4
    start_action(action)
    # 影スプライトを用意
    make_shadow if N01::SHADOW
  end
  #--------------------------------------------------------------------------
  # ● アクション開始
  #--------------------------------------------------------------------------
  def start_action(kind)
    # 各種動作を初期化
    reset
    # 現在取っている待機アクションを記憶
    stand_by
    # 新しいアクション内容の決定
    @action = N01::ACTION[kind].dup
    # 行動配列の先頭からシフト
    active = @action.shift
    # 自動で終了を付ける
    @action.push("End")
    # 現在のアクションを決定
    @active_action = N01::ANIME[active]
    # ウエイト設定
    @wait = active.to_i if @active_action == nil
    # 単発アクション開始
    action
  end
  #--------------------------------------------------------------------------
  # ● 強制単発アクション開始
  #--------------------------------------------------------------------------
  def start_one_action(kind,back)
    # 各種動作を初期化
    reset
    # 現在取っている待機アクションを記憶
    stand_by
    # 座標リセットアクションをセッティング
    @action = [back]
    # 自動で終了を付ける
    @action.push("End")
    # 現在のアクションを決定
    @active_action = N01::ANIME[kind]
    # 単発アクション開始
    action
  end
  #--------------------------------------------------------------------------
  # ● 次のアクションへ
  #--------------------------------------------------------------------------
  def next_action
    # ウェイト中の場合キャンセル
    return @wait -= 1 if @wait > 0
    # まだ全アニメセルが終了していない場合キャンセル
    return if @anime_end == false
    # 最後のアニメセル表示待ち
    return @unloop_wait -= 1 if @unloop_wait > 0
    # 行動配列の先頭からシフト
    active = @action.shift
    # 現在のアクションを決定
    @active_action = N01::ANIME[active]
    # ウエイト設定
    @wait = active.to_i if @active_action == nil
    # 単発アクション開始
    action
  end
  #--------------------------------------------------------------------------
  # ● 待機アクション
  #--------------------------------------------------------------------------
  def stand_by
    # 通常待機に
    @repeat_action = @battler.normal
    # HPが1/4でピンチモーションに
    @repeat_action = @battler.pinch if @battler.hp <= @battler.maxhp / 4
    # 防御中
    @repeat_action = @battler.defence if @battler.guarding?
    # 何もステートがなければ終了
    return if @battler.state_id == nil
    for state in @battler.states.reverse
      # アクション禁止のステートだったらスキップ
      next if state.extension.include?("NOSTATEANIME")
      # エネミーで禁止されているステートアクションだったらスキップ
      next if @battler.is_a?(Game_Enemy) && state.extension.include?("EXCEPTENEMY")
      # ステートのモーションに
      @repeat_action = state.base_action
    end 
  end 
  #--------------------------------------------------------------------------
  # ● 待機アクションの割り込み
  #--------------------------------------------------------------------------
  def push_stand_by
    action = @battler.normal
    action = @battler.pinch if @battler.hp <= @battler.maxhp / 4
    action = @battler.defence if @battler.guarding?
    for state in @battler.states.reverse
      # アクション禁止のステートだったらスキップ
      next if state.extension.include?("NOSTATEANIME")
      # エネミーで禁止されているステートアクションだったらスキップ
      next if @battler.is_a?(Game_Enemy) && state.extension.include?("EXCEPTENEMY")
      # ステートのモーションに
      action = state.base_action
    end
    @repeat_action = action
    # 割り込み
    @action.delete("End")
    act = N01::ACTION[action].dup
    for i in 0...act.size
      @action.push(act[i])
    end  
    @action.push("End")
    @anime_end = true
  end 
  #--------------------------------------------------------------------------
  # ● 各種変化を初期化
  #--------------------------------------------------------------------------
  def reset
    self.zoom_x = self.zoom_y = 1
    self.oy = @height * 2 / 3
    @angle = self.angle = 0
    @anime_end = true
    @non_repeat = false
    @anime_freeze = false
    @unloop_wait = 0
  end  
  #--------------------------------------------------------------------------
  # ● ジャンプを初期化
  #--------------------------------------------------------------------------
  def jump_reset
    @battler.jump = @jump_time = @jump_time_plus = @jump_up = @jump_down = 0 
    @jump_size = @jump_plus = @float_time = @float_up = 0 
  end
  #--------------------------------------------------------------------------
  # ● ターゲット情報を受け取る 
  #--------------------------------------------------------------------------
  def get_target(target)
    # 個別処理中は中止(全域で自分が巻き込まれた時ターゲット情報が狂わないように)
    return if @battler.individual
    @target_battler = target
  end
  #--------------------------------------------------------------------------
  # ● アクション情報をバトラーに格納
  #--------------------------------------------------------------------------
  def send_action(action)
    @battler.play = 0
    @battler.play = action if @battler.active
  end
  #--------------------------------------------------------------------------
  # ● バトラー追加
  #--------------------------------------------------------------------------
  def battler_join
    if @battler.exist? && !@battler_visible
      # 戦闘不能からの復活なら処理をスキップ
      if @battler.revival && @anime_flug
        return @battler.revival = false 
      elsif @battler.revival && !@anime_flug
        @battler.revival = false
        self.visible = true
        return 
      end
      @anime_flug = true if @battler.actor?
      @anime_flug = true if !@battler.actor? && @battler.anime_on
      make_battler
      first_action
    end
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新　※再定義
  #--------------------------------------------------------------------------
  def update
    super
    # バトラーがいない場合スキップ
    return self.bitmap = nil if @battler == nil
    # バトラー追加
    battler_join
    # 次のアクションへ
    next_action
    # アニメパターン更新
    update_anime_pattern
    # ターゲット更新
    update_target
    # 強制アクション更新
    update_force_action
    # 座標更新
    update_move
    # 影更新
    update_shadow if @shadow != nil
    # 武器更新
    @weapon_R.update if @weapon_action
    # 浮遊更新
    update_float if @float_time > 0
    # 回転更新
    update_angle if @angle_time > 0
    # 拡大縮小更新
    update_zoom if @zoom_time > 0
    # 残像更新
    update_mirage if @mirage_flug
    # ピクチャ更新
    update_picture if @picture_time > 0
    # アニメ飛ばし更新
    update_move_anime if @anime_moving
    # ふきだしアニメ更新
    update_balloon if @balloon_duration <= 64
    # ダメージスプライト更新
    @damage.update if @damage != nil
    setup_new_effect
    update_effect
    update_battler_bitmap
  end
  #--------------------------------------------------------------------------
  # ● アニメパターン更新
  #--------------------------------------------------------------------------
  def update_anime_pattern
    # 更新時間がくるまでスキップ
    return @frame -= 1 if @frame != 0
    # 必要な時だけ武器アニメ更新
    @weapon_R.action if @weapon_action && @weapon_R != nil
    # アニメのコマが最後まで到達したらリピート方法をチェック
    if @pattern_back
      # 往復ループ
      if @anime_loop == 0
        # 逆転再生
        if @reverse
          @pattern += 1
          if @pattern == @base_width - 1
            @pattern_back = false 
            @anime_end = true
          end
        # 通常再生
        else  
          @pattern -= 1
          if @pattern == 0
            @pattern_back = false 
            @anime_end = true
          end  
        end  
      # 片道ループもしくはループしない
      else
        @anime_end = true
        if @anime_loop == 1
          @pattern = 0 if !@reverse
          @pattern = @base_width - 1 if @reverse
          @pattern_back = false
        end  
      end  
    # アニメのコマを進める    
    else
      if @reverse
        @pattern -= 1
        @pattern_back = true if @pattern == 0
      else  
        @pattern += 1
        @pattern_back = true if @pattern == @base_width - 1
      end  
    end
    # 更新時間を初期化
    @frame = @anime_speed
    # アニメ固定の場合は横矩形を固定
    return if @anime_freeze
    # 転送元の矩形を設定
    return unless @anime_flug
    @sx = @pattern * @width
    @sy = @anime_kind * @height
    self.src_rect.set(@sx, @sy, @width, @height)
  end
  #--------------------------------------------------------------------------
  # ● ターゲット更新 action = ["N01target_change",ターゲット情報]
  #--------------------------------------------------------------------------
  def update_target
    # ターゲットチェック 
    return if @battler.force_target == 0
    # 個別処理中は中止(全域で自分が巻き込まれた時ターゲット情報が狂わないように)
    return if @battler.individual
    @target_battler = @battler.force_target[1]
    @battler.force_target = 0
  end  
  #--------------------------------------------------------------------------
  # ● 強制アクション更新 action = [識別,復帰,実行するアクション]
  #--------------------------------------------------------------------------
  def update_force_action
    # 強制アクションチェック 
    action = @battler.force_action
    return if action == 0
    @battler.force_action = 0
    # アクティブ中は割り込ませない
    return if @battler.active
    # コラプスならそのまま行動に直結
    return collapse_action if action[0] == "N01collapse"
    # 単発ならそのまま行動に直結
    return start_one_action(action[2],action[1]) if action[0] == "SINGLE"
    # 通しはアクションとして扱う
    start_action(action[2])
    # 座標復帰の有無
    return if action[1] == ""
    # 終了位置を入れ替えて復帰アクションを入れる
    @action.delete("End")
    @action.push(action[1])
    @action.push("End")
  end   
  #--------------------------------------------------------------------------
  # ● 座標更新
  #--------------------------------------------------------------------------
  def update_move
    # 加減速で出る距離の増減を補完
    if @move_speed_plus_x > 0
      # 移動計算
      @move_x += @moving_x
      # 移動を実行
      @battler.move_x = @move_x
      @move_speed_plus_x -= 1
    elsif @move_speed_x > 0
      # 加速の場合
      if @move_boost_x != 0
        @moving_x += @move_boost_x
      end  
      # 移動計算
      @move_x += @moving_x
      # 移動を実行
      @battler.move_x = @move_x
      @move_speed_x -= 1
    end
    # 加減速で出る距離の増減を補完
    if @move_speed_plus_y > 0
      # 移動計算
      @move_y += @moving_y
      # 移動を実行
      @battler.move_y = @move_y
      @move_speed_plus_y -= 1
    elsif @move_speed_y > 0
      # 加速の場合
      if @move_boost_y != 0
        @moving_y += @move_boost_y 
      end  
      # 移動計算
      @move_y += @moving_y
      # 移動を実行
      @battler.move_y = @move_y
      @move_speed_y -= 1
    end
    # ジャンプ上昇
    if @jump_up != 0
      # 移動計算
      @jump_plus += @jump_up
      # 移動を実行
      @battler.jump = @jump_plus
      @jump_up = @jump_up / 2
      @jump_time -= 1
      # ジャンプが頂点に達したら
      if @jump_time == 0 or @jump_up == @jump_sign
        @jump_down = @jump_up * 2 * @jump_sign * @jump_sign2
        @jump_time_plus += @jump_time * 2
        @jump_up = 0
        return
      end  
    end  
    # ジャンプ下降
    if @jump_down != 0 
      if @jump_time_plus != 0
        @jump_time_plus -= 1
      elsif @jump_down != @jump_size
        # 移動計算
        @jump_plus += @jump_down 
        # 移動を実行
        @battler.jump = @jump_plus
        @jump_down = @jump_down * 2
        if @jump_down == @jump_size
          if @jump_flug
            @jump_flug = false
          else
            # 移動計算
            @jump_plus += @jump_down 
            # 移動を実行
            @battler.jump = @jump_plus
            @jump_down = @jump_size = 0
          end
        end  
      end
    end
    # スプライトの座標を設定
    self.x = @battler.position_x
    self.y = @battler.position_y
    self.z = @battler.position_z
  end
  #--------------------------------------------------------------------------
  # ● 影更新
  #--------------------------------------------------------------------------
  def update_shadow
    @shadow.opacity = self.opacity
    @shadow.x = @battler.position_x + @shadow_plus_x
    @shadow.y = @battler.position_y + @shadow_plus_y - @jump_plus
    @shadow.z = @battler.position_z - 4
  end
  #--------------------------------------------------------------------------
  # ● 浮遊更新
  #--------------------------------------------------------------------------
  def update_float
    @float_time -= 1
    @jump_plus += @float_up
    @battler.jump = @jump_plus
  end   
  #--------------------------------------------------------------------------
  # ● 回転更新
  #--------------------------------------------------------------------------
  def update_angle
    # 回転実行
    @angle += @angling
    self.angle = @angle
    @angle_time -= 1
    # 回転時間がなくなったら項目をリセット
    return @angle = 0 if @angle_time == 0
    # 復帰フラグがあれば角度を0に戻す
    self.angle = 0 if @angle_reset
  end  
  #--------------------------------------------------------------------------
  # ● 拡大縮小更新
  #--------------------------------------------------------------------------
  def update_zoom
    # 拡大縮小実行
    @zoom_x += @zooming_x
    @zoom_y += @zooming_y
    self.zoom_x = @zoom_x
    self.zoom_y = @zoom_y
    @zoom_time -= 1
    # 拡大縮小時間がなくなったら項目をリセット
    return if @zoom_time != 0
    @zoom_x = @zoom_y = 0
    self.oy = @height * 2 / 3
    # 復帰フラグがあれば戻す
    self.zoom_x = self.zoom_y = 1 if @zoom_reset
  end  
  #--------------------------------------------------------------------------
  # ● 残像更新
  #--------------------------------------------------------------------------
  def update_mirage
    # 残像は最大3つまで表示し、２フレームごとに更新
    mirage(@mirage0) if @mirage_count == 1
    mirage(@mirage1) if @mirage_count == 3
    mirage(@mirage2) if @mirage_count == 5
    @mirage_count += 1
    @mirage_count = 0 if @mirage_count == 6
  end
  #--------------------------------------------------------------------------
  # ● ピクチャ更新
  #--------------------------------------------------------------------------
  def update_picture
    @picture_time -= 1
    @picture.x += @moving_pic_x
    @picture.y += @moving_pic_y
  end  
  #--------------------------------------------------------------------------
  # ● アニメ飛ばし更新
  #--------------------------------------------------------------------------
  def update_move_anime
    @move_anime.update
    @anime_moving = false if @move_anime.finish?
    @move_anime.action_reset if @move_anime.finish?
  end  
  #--------------------------------------------------------------------------
  # ● 崩壊エフェクトの更新　※再定義
  #--------------------------------------------------------------------------
  def update_collapse
    normal_collapse if @collapse_type == 2
    boss_collapse1 if @collapse_type == 3
  end
  #--------------------------------------------------------------------------
  # ● ふきだしアニメ更新
  #--------------------------------------------------------------------------
  def update_balloon
    @balloon_duration -= 1 if @balloon_duration > 0 && !@balloon_back
    @balloon_duration += 1 if @balloon_back
    if @balloon_duration == 64
      @balloon_back = false
      @balloon.visible = false
    elsif @balloon_duration == 0
      @balloon.visible = false if @balloon_loop == 0
      @balloon_back = true if @balloon_loop == 1
    end    
    @balloon.x = self.x
    @balloon.y = self.y
    @balloon.z = 10
    @balloon.opacity = self.opacity
    sx = 7 * 32 if @balloon_duration < 12
    sx = (7 - (@balloon_duration - 12) / 8) * 32 unless @balloon_duration < 12
    @balloon.src_rect.set(sx, @balloon_id * 32, 32, 32)
  end
  #--------------------------------------------------------------------------
  # ● 転送元ビットマップの更新 ※再定義
  #--------------------------------------------------------------------------
  def update_battler_bitmap
    if @battler.actor?
      if @battler.character_name != @battler_name or @battler.battler_hue != @battler_hue
        @battler_name = @battler.character_name
        @battler_hue = @battler.battler_hue
      end
    else
      if @battler.battler_name != @battler_name or @battler.battler_hue != @battler_hue
        @battler_name = @battler.battler_name
        @battler_hue = @battler.battler_hue
      end
      if !@battler.exist?
        self.opacity = 0 if @effect_duration == 0 && @battler.collapse_type != 1
      end  
    end  
  end
  #--------------------------------------------------------------------------
  # ● アクション実行
  #--------------------------------------------------------------------------
  def action 
    return if @active_action == nil
    action = @active_action[0]
    # 反転の場合
    return mirroring if action == "Invert"
    # 回転の場合  
    return angling if action == "angle"
    # 拡大縮小の場合  
    return zooming if action == "zoom"
    # 残像ONの場合
    return mirage_on if action == "Afterimage ON"
    # 残像OFFの場合
    return mirage_off if action == "Afterimage OFF"
    # ピクチャ表示の場合
    return picture if action == "pic"
    # ピクチャ消去の場合
    return @picture.visible = false && @picture_time = 0 if action == "Clear image" 
    # グラフィックファイル変更の場合  
    return graphics_change if action == "change"
    # 戦闘アニメ表示の場合  
    return battle_anime if action == "anime"
    # ふきだしアニメ表示の場合  
    return balloon_anime if action == "balloon"
    # BGM/BGS/SE演奏の場合  
    return sound if action == "sound"
    # ゲームスイッチ操作の場合  
    return $game_switches[@active_action[1]] = @active_action[2] if action == "switch"
    # ゲーム変数操作の場合  
    return variable if action == "variable"
    # 二刀限定の場合
    return two_swords if action == "Two Wpn Only"
    # 非二刀限定の場合
    return non_two_swords if action == "One Wpn Only"
    # アクション条件の場合
    return necessary if action == "nece"
    # スキル派生の場合  
    return derivating if action == "der"
    # 個別処理開始の場合
    return individual_action if action == "Process Skill"
    # 個別処理終了の場合
    return individual_action_end if action == "Process Skill End"
    # 待機に移行しない場合
    return non_repeat if action == "Don't Wait"
    # 初期位置変更の場合
    return @battler.change_base_position(self.x, self.y) if action == "Start Pos Change"
    # 初期位置変更解除の場合
    return @battler.base_position if action == "Start Pos Return"
    # ターゲット変更の場合  
    return change_target if action == "target"
    # ターゲットのコラプス許可
    return send_action(action) if action == "Can Collapse"
    # アクティブ解除
    return send_action(action) if action == "Cancel Action"
    # ステート付与の場合  
    return state_on if action == "sta+"
    # ステート解除の場合  
    return state_off if action == "sta-"
    # ゲーム全体のスピード変更の場合
    return Graphics.frame_rate = @active_action[1] if action == "fps"
    # 浮遊の場合  
    return floating if action == "float"
    # スクリプト操作の場合   
    return eval(@active_action[1]) if action == "script"
    # 強制アクションの場合  
    return force_action if @active_action.size == 4
    # 座標リセットの場合  
    return reseting if @active_action.size == 5
    # 移動の場合
    return moving if @active_action.size == 7
    # バトラーアニメの場合
    return battler_anime if @active_action.size == 9
    # アニメ飛ばしの場合
    return moving_anime if @active_action.size == 11
    # 終了の場合 
    return anime_finish if action == "End"
  end
  #--------------------------------------------------------------------------
  # ● 反転実行
  #--------------------------------------------------------------------------
  def mirroring  
    # すでに反転されていれば元に戻す
    if self.mirror
      self.mirror = false
      # 武器アニメも反映
      @weapon_R.mirroring if @anime_flug
    else
      self.mirror = true
      # 武器アニメも反映
      @weapon_R.mirroring if @anime_flug
    end
  end  
  #--------------------------------------------------------------------------
  # ● 回転実行
  #--------------------------------------------------------------------------
  def angling  
    # ジャンプを初期化
    jump_reset
    # 情報確認
    @angle_time = @active_action[1]
    start_angle = @active_action[2]
    end_angle = @active_action[3]
    @angle_reset = @active_action[4]
    # バックアタック時には逆に
    start_angle *= -1 if $back_attack
    end_angle *= -1 if $back_attack
    # エネミーは逆に
    start_angle *= -1 if @battler.is_a?(Game_Enemy)
    end_angle *= -1 if @battler.is_a?(Game_Enemy)
    # 時間が0以下なら即座に最終角度へ
    if @angle_time <= 0
      self.angle = end_angle
      return  @angle_time = 0
    end  
    # 回転時間から1フレームあたりの角度を出す
    @angling = (end_angle - start_angle) / @angle_time
    # 割り切れない余りを初期角度に
    @angle = (end_angle - start_angle) % @angle_time + start_angle
  end
  #--------------------------------------------------------------------------
  # ● 拡大縮小実行
  #--------------------------------------------------------------------------
  def zooming  
    # ジャンプを初期化
    jump_reset
    # 情報確認
    @zoom_time = @active_action[1]
    zoom_x = @active_action[2] - 1
    zoom_y = @active_action[3] - 1
    @zoom_reset = @active_action[4]
    @zoom_x = @zoom_y = 1
    # 時間が0以下ならスキップ
    return @zoom_time = 0 if @zoom_time <= 0
    # 拡大時間から1フレームあたりの拡大率を出す
    @zooming_x = zoom_x / @zoom_time
    @zooming_y = zoom_y / @zoom_time
  end  
  #--------------------------------------------------------------------------
  # ● 残像開始
  #--------------------------------------------------------------------------
  def mirage_on
    # 戦闘不能時には残像させない
    return if @battler.dead?
    @mirage0 = Sprite.new(self.viewport)
    @mirage1 = Sprite.new(self.viewport)
    @mirage2 = Sprite.new(self.viewport)
    @mirage_flug = true
    @mirage_count = 0
  end  
  #--------------------------------------------------------------------------
  # ● 残像表示
  #--------------------------------------------------------------------------
  def mirage(body)
    body.bitmap = self.bitmap.dup
    body.x = self.x
    body.y = self.y
    body.ox = self.ox
    body.oy = self.oy
    body.z = self.z
    body.mirror = self.mirror
    body.angle = @angle
    body.opacity = 160
    body.zoom_x = self.zoom_x
    body.zoom_y = self.zoom_y   
    body.src_rect.set(@sx, @sy, @width, @height) if @anime_flug
    body.src_rect.set(0, 0, @width, @height) unless @anime_flug
  end   
  #--------------------------------------------------------------------------
  # ● 残像終了
  #--------------------------------------------------------------------------
  def mirage_off
    @mirage_flug = false
    @mirage0.dispose if @mirage0 != nil
    @mirage1.dispose if @mirage1 != nil
    @mirage2.dispose if @mirage2 != nil
  end   
  #--------------------------------------------------------------------------
  # ● ピクチャ表示
  #--------------------------------------------------------------------------
  def picture 
    # 移動開始位置を確認
    pic_x = @active_action[1]
    pic_y = @active_action[2]
    # 移動終了位置を確認
    pic_end_x = @active_action[3]
    pic_end_y = @active_action[4]
    @picture_time = @active_action[5]
    # 時間で割り、1フレーム当たりの移動速度を計算
    @moving_pic_x = (pic_end_x - pic_x)/ @picture_time
    @moving_pic_y = (pic_end_y - pic_y)/ @picture_time
    # 割り切れない場合最初に加算
    plus_x = (pic_end_x - pic_x)% @picture_time
    plus_y = (pic_end_y - pic_y)% @picture_time
    # ピクチャ表示
    @picture.bitmap = Cache.picture(@active_action[7])
    @picture.x = pic_x + plus_x
    @picture.y = pic_y + plus_y
    # Z座標調整
    @picture.z = 1
    @picture.z = 1000 if @active_action[6]
    @picture.visible = true
  end 
  #--------------------------------------------------------------------------
  # ● グラフィックファイル変更
  #--------------------------------------------------------------------------
  def graphics_change  
    # アクター限定
    return if @battler.is_a?(Game_Enemy)
    # グラフィック変更
    @battler_name = @active_action[2]
    # 歩行グラフィックを利用するかどうかで転送元の矩形サイズの認識先を変える
    self.bitmap = Cache.character(@battler_name) if N01::WALK_ANIME
    self.bitmap = Cache.character(@battler_name + "_1") unless N01::WALK_ANIME
    # 転送元の矩形を取得
    @width = self.bitmap.width / @base_width
    @height = self.bitmap.height / @base_height
    # 戦闘後リセットする場合キャラチップ名を記憶
    @before_graphic = @battler.character_name if @active_action[1]
    @battler.graphic_change(@active_action[2])
  end  
  #--------------------------------------------------------------------------
  # ● 戦闘アニメ表示 [判別,ID,対象,反転,ウエイト,二刀フラグ]
  #--------------------------------------------------------------------------
  def battle_anime
    # エネミーの二刀フラグアニメ処理はキャンセル
    return if @active_action[5] && !@battler.actor?
    # 二刀ではないアクターの二刀フラグアニメ処理はキャンセル
    return if @active_action[5] && @battler.weapons[1] == nil
    # 二刀で右(上に配置された)武器がなく左(下に配置)だけ持ってる場合
    if @battler.actor?
      return if !@active_action[5] && @battler.weapons[0] == nil && @battler.weapons[1] != nil
    end
    anime_id = @active_action[1]
    # バックアタック時にアニメ画像を反転
    if $back_attack
      mirror = true if @active_action[3] == false
      mirror = false if @active_action[3]
    end
    # 武器とスキルアニメの場合
    if anime_id < 0
      # 行動の種類でアニメ先を分岐
      if @battler.action.skill? && anime_id != -2
        anime_id = @battler.action.skill.animation_id 
      elsif @battler.action.item? && anime_id != -2
        anime_id = @battler.action.item.animation_id
      else
        # 武器がなければ素手アニメを使用
        anime_id = N01::NO_WEAPON
        if @battler.actor?
          weapon_id = @battler.weapon_id
          anime_id = $data_weapons[weapon_id].animation_id if weapon_id != 0
          # 二刀アニメの場合
          anime_id = @battler.atk_animation_id2 if @active_action[5]
        else
          weapon_id = @battler.weapon
          anime_id = $data_weapons[weapon_id].animation_id if weapon_id != 0
        end
      end
      # ウエイト設定
      @wait = $data_animations[anime_id].frame_max * 4 if $data_animations[anime_id] != nil && @active_action[4]
      waitflug = true
      # ダメージ表示のアニメなら、ダメージ計算を先に済ませるため処理を中断
      damage_action = [anime_id, mirror, true]
      return @battler.play = ["OBJ_ANIM",damage_action] if @battler.active
    end
    # アニメ実行
    if @active_action[2] == 0 && $data_animations[anime_id] != nil
      @battler.animation_id = anime_id
      @battler.animation_mirror = mirror
    elsif $data_animations[anime_id] != nil
      for target in @target_battler
        target.animation_id = anime_id
        target.animation_mirror = mirror
      end  
    end
    # ウエイト設定
    @wait = $data_animations[anime_id].frame_max * 4 if $data_animations[anime_id] != nil && @active_action[4] && !waitflug
  end
  #--------------------------------------------------------------------------
  # ● ふきだしアニメ表示 
  #--------------------------------------------------------------------------
  def balloon_anime
    return if self.opacity == 0
    if @balloon == nil
      @balloon = Sprite.new 
      @balloon.bitmap = Cache.system("Balloon")
      @balloon.ox = @width / 16
      @balloon.oy = @balloon.height / 10 + @height / 3 
    end
    @balloon_id = @active_action[1]
    @balloon_loop = @active_action[2]
    @balloon_duration = 64
    @balloon_back = false
    update_balloon
    @balloon.visible = true
  end  
  #--------------------------------------------------------------------------
  # ● BGM/BGS/SE演奏
  #--------------------------------------------------------------------------
  def sound   
    # 情報を取得
    pitch = @active_action[2] 
    vol =  @active_action[3]
    name = @active_action[4] 
    # 実行
    case @active_action[1]
    when "se"
      Audio.se_play("Audio/SE/" + name, vol, pitch)
    when "bgm"
      # 名前指定のない場合、現在のBGMを変えないように
      if @active_action[4] == ""
        now_bgm = RPG::BGM.last
        name = now_bgm.name
      end
      Audio.bgm_play("Audio/BGM/" + name, vol, pitch)
    when "bgs"
      # 名前指定のない場合、現在のBGSを変えないように
      if @active_action[4] == ""
        now_bgs = RPG::BGS.last
        name = now_bgs.name
      end
      Audio.bgs_play("Audio/BGS/" + name, vol, pitch)
    end
  end
  #--------------------------------------------------------------------------
  # ● ゲーム変数操作
  #--------------------------------------------------------------------------
  def variable
    # オペランドチェック
    operand = @active_action[3]
    # 変数操作で分岐
    case @active_action[2]
    when 0 # 代入
      $game_variables[@active_action[1]] = operand
    when 1 # 加算
      $game_variables[@active_action[1]] += operand
    when 2 # 減算
      $game_variables[@active_action[1]] -= operand
    when 3 # 乗算
      $game_variables[@active_action[1]] *= operand
    when 4 # 除算
      $game_variables[@active_action[1]] /= operand
    when 5 # 剰余
      $game_variables[@active_action[1]] %= operand
    end
  end  
  #--------------------------------------------------------------------------
  # ● 二刀限定
  #--------------------------------------------------------------------------
  def two_swords
    # エネミーは処理させない
    return @action.shift unless @battler.actor?
    # 左(下部表示)に武器がなかったら次のアクションを除く
    return @action.shift if @battler.weapons[1] == nil
    # 行動配列の先頭からシフト
    active = @action.shift
    # 現在のアクションを決定
    @active_action = N01::ANIME[active]
    # ウエイト設定
    @wait = active.to_i if @active_action == nil
    # 単発アクション開始
    action
  end
  #--------------------------------------------------------------------------
  # ● 非二刀限定
  #--------------------------------------------------------------------------
  def non_two_swords
    # エネミーは処理させない
    return unless @battler.actor?
    # 左(下部表示)に武器があったら次のアクションを除く
    return @action.shift if @battler.weapons[1] != nil
    # 行動配列の先頭からシフト
    active = @action.shift
    # 現在のアクションを決定
    @active_action = N01::ANIME[active]
    # ウエイト設定
    @wait = active.to_i if @active_action == nil
    # 単発アクション開始
    action
  end
  #--------------------------------------------------------------------------
  # ● アクション条件
  #--------------------------------------------------------------------------
  def necessary
    nece1 = @active_action[3]
    nece2 = @active_action[4]
    # ターゲットチェック
    case @active_action[1]
    # 0自身 1ターゲット 2敵全体 3味方全体
    when 0
      target = [$game_party.members[@battler.index]] if @battler.is_a?(Game_Actor)
      target = [$game_troop.members[@battler.index]] if @battler.is_a?(Game_Enemy)
    when 1
      target = @target_battler
    when 2
      target = $game_troop.members
    when 3
      target = $game_party.members
    end 
    # ターゲットが空の場合は失敗とみなす
    return start_action(@battler.recover_action) if target.size == 0
    # 内容チェック
    case @active_action[2]
    # ステートID指定だった場合
    when 0
      # 補足が正で「ステートにかかっている」、負は「かかっていない」が条件に
      state_on = true if nece2 > 0
      # 条件人数を出す
      state_member = nece2.abs
      # 0は仲間数を出す
      if nece2 == 0
        state_member = $game_party.members.size if @battler.is_a?(Game_Actor)
        state_member = $game_troop.members.size if @battler.is_a?(Game_Enemy)
      end  
      # ターゲットのステートチェックし人数をカウント
      for member in target
        state_member -= 1 if member.state?(nece1)
      end
      # 条件が満たされていればアクション続行
      if state_member == 0 && state_on
        return
      elsif state_member == nece2.abs
        return if state_on == nil
      end  
    # パラメータ指定だった場合
    when 1  
      # 補足が正で「数値以上」、負は「数値以下」が条件に
      num_over = true if nece2 > 0
      # 参照数値
      num = 0
      # ターゲットのパラメータチェック
      for member in target
        # 参照パラメータで分岐
        case  nece1
        when 0 # 現HP
          num += member.hp
        when 1 # 現MP
          num += member.mp
        when 2 # 攻撃力
          num += member.atk
        when 3 # 防御力
          num += member.def
        when 4 # 精神力
          num += member.spi
        when 5 # 敏捷性
          num += member.agi
        end
      end
      # 平均を出す
      num = num / target.size
      # 条件が満たされていればアクション続行
      if num > nece2.abs && num_over
        return
      elsif num < nece2.abs
        return if num_over == nil
      end
    # スイッチ指定だった場合
    when 2
      # 条件が満たされていればアクション続行
      if $game_switches[nece1]
        # 補足がtrueで「スイッチON」、falseは「スイッチOFF」が条件に
        return if nece2
      # スイッチがOFFの場合はON時とは逆に  
      else
        return unless nece2
      end  
    # 変数指定だった場合
    when 3
      # 補足が正で「数値以上」、負は「数値以下」が条件に
      if nece2 > 0
        return if $game_variables[nece1] > nece2
      else
        return unless $game_variables[nece1] > nece2.abs
      end
    # 習得スキル指定だった場合
    when 4
      # スキル条件人数を出す
      skill_member = nece2.abs
      for member in target
        skill_member -= 1 if member.skill_learn?(nece1)
        # 条件確認
        return if skill_member == 0
      end  
    end 
    # 条件を満たせなければ以降のアクションを中断
    return @action = ["End"] if @non_repeat
    # 防御中は不自然に見えないように座標復帰させない
    action = @battler.recover_action
    action = @battler.defence if @battler.guarding?
    return start_action(action)
  end  
  #--------------------------------------------------------------------------
  # ● スキル派生
  #--------------------------------------------------------------------------
  def derivating
    # 未修得スキルは派生不可なら
    return if !@active_action[2] && !@battler.skill_id_learn?(@active_action[3])
    # 確率分岐
    return if rand(100) > @active_action[1]
    # 派生成功
    @battler.derivation = @active_action[3]
    # 以降のアクションを中断
    @action = ["End"]
  end
  #--------------------------------------------------------------------------
  # ● 個別処理開始
  #--------------------------------------------------------------------------
  def individual_action
    # リピートフラグオン
    @battler.individual = true
    # リピートアクションを保持
    @individual_act = @action.dup
    # ターゲットを保持し、行動ターゲットをひとつずつ抜き出す
    send_action(["個別処理"])
    @individual_targets = @target_battler.dup
    @target_battler = [@individual_targets.shift]
  end
  #--------------------------------------------------------------------------
  # ● 個別処理終了
  #--------------------------------------------------------------------------
  def individual_action_end
    # ターゲットが残っていないなら行動終了
    return @battler.individual = false if @individual_targets.size == 0
    @action = @individual_act.dup
    @target_battler = [@individual_targets.shift]
  end  
  #--------------------------------------------------------------------------
  # ● 待機に移行しない
  #--------------------------------------------------------------------------
  def non_repeat
    @repeat_action = []
    @non_repeat = true
    anime_finish
  end  
  #--------------------------------------------------------------------------
  # ● ターゲット変更 action = [判別, 変更する対象, 変更先]
  #--------------------------------------------------------------------------
  def change_target
    # 自身の変更したターゲットを元に戻す
    return @target_battler = @now_targets.dup if @active_action[2] == 3
    # 送るターゲット情報
    target = [@battler] if @active_action[2] == 0
    target = @target_battler.dup if @active_action[2] != 0
    # 自身のターゲットを送った相手にする場合、現在のターゲットを記憶 
    if @active_action[2] == 2
      @now_targets = @target_battler.dup
      @target_battler = []
    end  
    # 送るターゲットがインデックス指定の場合
    if @active_action[1] >= 1000
      members = $game_party.members if @battler.actor?
      members = $game_troop.members unless @battler.actor?
      index = @active_action[1] - 1000
      if index < members.size
        if members[index].exist? && @battler.index != index
          # ターゲット変更
          members[index].force_target = ["N01target_change", target]
          # 自身のターゲットを送った相手にする場合
          @target_battler = [members[index]] if @active_action[2] == 2
          change = true
        else
          for member in members
            next if @battler.index == member.index
            next unless member.exist?
            member.force_target = ["N01target_change", target]
            @target_battler = [member] if @active_action[2] == 2
            break change = true
          end
        end
      end
    # 送るターゲットがステートID指定だった場合
    elsif @active_action[1] > 0
      for member in $game_party.members + $game_troop.members
        if member.state?(@active_action[1])
          member.force_target = ["N01target_change", target]
          @target_battler.push(member) if @active_action[2] == 2
          change = true
        end  
      end  
    # 送るターゲットが習得スキル指定だった場合
    elsif @active_action[1] < 0
      skill_id = @active_action[1].abs
      for actor in $game_party.members
        if actor.skill_id_learn?(skill_id)
          actor.force_target = ["N01target_change", target]
          @target_battler.push(target) if @active_action[2] == 2
          change = true
        end  
      end
    # 送るターゲットがターゲットだった場合
    else
      for member in @target_battler
        member.force_target = ["N01target_change", target]
        @target_battler.push(member) if @active_action[2] == 2
        change = true
      end
    end
    # 条件を満たせなければ以降のアクションを中断
    return if change
    return @action = ["End"] if @non_repeat
    return start_action(@battler.recover_action)
  end    
  #--------------------------------------------------------------------------
  # ● ステート付与
  #--------------------------------------------------------------------------
  def state_on  
    state_id = @active_action[2]
    # 対象で分岐
    case @active_action[1]
    when 0
      @battler.add_state(state_id) if rand(100) < @battler.state_probability(state_id)
    when 1
      if @target_battler != nil
        for target in @target_battler
          target.add_state(state_id) if rand(100) < target.state_probability(state_id)
        end
      end
    when 2
      for target in $game_troop.members
        target.add_state(state_id) if rand(100) < target.state_probability(state_id)
      end
    when 3
      for target in $game_party.members
        target.add_state(state_id) if rand(100) < target.state_probability(state_id)
      end
    when 4
      for target in $game_party.members
        if target.index != @battler.index
          target.add_state(state_id) if rand(100) < target.state_probability(state_id)
        end  
      end
    end
  end 
  #--------------------------------------------------------------------------
  # ● ステート解除
  #--------------------------------------------------------------------------
  def state_off  
    state_id = @active_action[2]
    # 対象で分岐
    case @active_action[1]
    when 0
      @battler.remove_state(state_id)
    when 1
      if @target_battler != nil
        for target in @target_battler
          target.remove_state(state_id)
        end
      end
    when 2
      for target in $game_troop.members
        target.remove_state(state_id)
      end
    when 3
      for target in $game_party.members
        target.remove_state(state_id)
      end
    when 4
      for target in $game_party.members
        if target.index != @battler.index
          target.remove_state(state_id)
        end  
      end
    end
  end  
  #--------------------------------------------------------------------------
  # ● 浮遊実行
  #--------------------------------------------------------------------------
  def floating  
    # ジャンプを初期化
    jump_reset
    # 情報確認
    @jump_plus = @active_action[1]
    float_end = @active_action[2]
    @float_time = @active_action[3]
    # １フレーム当たりの移動高度を計算
    @float_up = (float_end - @jump_plus)/ @float_time
    # 浮遊が完了するまで次のアクションに行かない
    @wait = @float_time
    # 浮遊アニメ設定を反映
    if @anime_flug
      move_anime = N01::ANIME[@active_action[4]]
      # グラフィック指定がない場合はスキップ
      if move_anime != nil
        # 現在のアクションを上書き
        @active_action = move_anime
        # バトラーアニメ開始
        battler_anime
        # 浮遊が完了したら即アニメが終わるように
        @anime_end = true
      end 
    end
    # 初期高度に浮遊
    @battler.jump = @jump_plus
  end      
  #--------------------------------------------------------------------------
  # ● 強制アクション
  #--------------------------------------------------------------------------
  def force_action
    # アクションが単発か通しか判別
    kind = @active_action[0]
    # 復帰の有無をチェック
    rebirth = @active_action[2]
    # 強制アクション内容を取得
    play = @active_action[3]
    # 上3つの情報をまとめて格納
    action = [kind,rebirth,play]
    # ターゲットがインデックス指定の場合
    if @active_action[1] >= 1000
      members = $game_party.members if @battler.actor?
      members = $game_troop.members unless @battler.actor?
      index = @active_action[1] - 1000
      if index < members.size
        if members[index].exist? && @battler.index != index
          # バトラー情報に渡す
          return members[index].force_action = action
        else
          for target in members
            next if @battler.index == target.index
            next unless target.exist?
            force = true
            break target.force_action = action
          end
        end
      end
      # 条件を満たせなければ以降のアクションを中断
      return if force
      return @action = ["End"] if @non_repeat
      return start_action(@battler.recover_action)
    # ターゲット指定の場合  
    elsif @active_action[1] == 0
      for target in @target_battler
        target.force_action = action if target != nil
      end
    # ステートID指定だった場合  
    elsif @active_action[1] > 0
      for target in $game_party.members + $game_troop.members
        target.force_action = action if target.state?(@active_action[1])
      end
    # 習得スキル指定だった場合  
    elsif @active_action[1] < 0  
      # エネミーは処理させない
      return if @battler.is_a?(Game_Enemy)
      for actor in $game_party.members
        # 自分は除く
        unless actor.id == @battler.id
          # バトラー情報に渡す
          actor.force_action = action if actor.skill_id_learn?(@active_action[1].abs)
        end
      end
    end 
  end
  #--------------------------------------------------------------------------
  # ● 座標リセット実行
  #--------------------------------------------------------------------------
  def reseting
    # ジャンプを初期化
    jump_reset
    # 回転を元に戻す
    self.angle = 0
    # 情報確認
    @distanse_x   = @move_x * -1
    @distanse_y   = @move_y * -1
    @move_speed_x = @active_action[1]
    @move_speed_y = @move_speed_x
    @move_boost_x = @active_action[2]
    @move_boost_y = @move_boost_x
    @jump         = @active_action[3]
    # 移動計算
    move_distance
    # 移動アニメ設定を反映
    if @anime_flug
      move_anime = N01::ANIME[@active_action[4]]
      # グラフィック指定がない場合はスキップ
      if move_anime != nil 
        # 現在のアクションを上書き
        @active_action = move_anime
        # バトラーアニメ開始
        battler_anime
      end 
      # 移動が完了したら即アニメが終わるように
      @anime_end = true
    end
  end
  #--------------------------------------------------------------------------
  # ● 移動実行
  #--------------------------------------------------------------------------
  def moving  
    # ジャンプを初期化
    jump_reset
    # X軸移動を便宜上抜き出す
    xx = @active_action[1]
    # バックアタック時にはX軸を逆に
    xx *= -1 if $back_attack
    # 移動目標のターゲットを確認
    case @active_action[0]
    when 0 # 自身
      @distanse_x = xx
      @distanse_y = @active_action[2]
    when 1 # ターゲット
      # ターゲットが決まってない場合、自身に変換
      if @target_battler == nil
        @distanse_x = xx
        @distanse_y = @active_action[2]
      else
        # ターゲット対象をひとつずつチェック
        target_x = 0
        target_y = 0
        time = 0
        for i in 0...@target_battler.size
          if @target_battler[i] != nil
            time += 1
            target_x += @target_battler[i].position_x
            target_y += @target_battler[i].position_y
          end  
        end 
        # ターゲットが空だった場合、自身に変換
        if time == 0
          @distanse_x = xx
          @distanse_y = @active_action[2]
        else  
          # 複数ターゲットの中心を計算
          target_x = target_x / time
          target_y = target_y / time
          # 最終的な移動距離を算出 
          @distanse_y = target_y - self.y + @active_action[2]
          # X座標はアクターとエネミーで逆計算
          if @battler.is_a?(Game_Actor)
            @distanse_x = target_x - self.x + xx
          else
            @distanse_x = self.x - target_x + xx
          end  
        end  
      end  
    when 2 # 画面
      # X座標はアクターとエネミーで逆計算
      if @battler.is_a?(Game_Actor)
        @distanse_x = xx - self.x
        @distanse_x = Graphics.width + xx - self.x if $back_attack
      else
        @distanse_x = self.x - xx
        @distanse_x = self.x - (Graphics.width + xx) if $back_attack
      end 
      @distanse_y = @active_action[2] - self.y
    when 3 # 初期位置
      # X座標はアクターとエネミーで逆計算
      if @battler.is_a?(Game_Actor)
        @distanse_x = xx + @battler.base_position_x - self.x 
      else
        @distanse_x = xx + self.x - @battler.base_position_x
      end 
      @distanse_y = @active_action[2] + @battler.base_position_y - @battler.position_y
    end
    @move_speed_x = @active_action[3]
    @move_speed_y = @active_action[3]
    @move_boost_x = @active_action[4]
    @move_boost_y = @active_action[4]
    @jump         = @active_action[5]
    @jump_plus = 0
    # 移動計算
    move_distance
    # 移動アニメ設定を反映
    if @anime_flug
      move_anime = N01::ANIME[@active_action[6]]
      # グラフィック指定がない場合はスキップ
      if move_anime != nil 
        # 現在のアクションを上書き
        @active_action = move_anime
        # バトラーアニメ開始
        battler_anime
      end  
      # 移動が完了したら即アニメが終わるように
      @anime_end = true
    end
  end
  #--------------------------------------------------------------------------
  # ● 移動計算
  #--------------------------------------------------------------------------
  def move_distance
    # 速度が0の場合、その場に留まる
    if @move_speed_x == 0
      @moving_x = 0
      @moving_y = 0
    else  
      # １フレームあたりの移動距離を計算
      @moving_x = @distanse_x / @move_speed_x
      @moving_y = @distanse_y / @move_speed_y
      # 余った距離はこの時点で移動し消化
      over_x = @distanse_x % @move_speed_x
      over_y = @distanse_y % @move_speed_y
      @move_x += over_x
      @move_y += over_y
      @battler.move_x = @move_x
      @battler.move_y = @move_y
      @distanse_x -= over_x
      @distanse_y -= over_y
    end  
    # 移動があるかどうかの判定
    if @distanse_x == 0
      @move_speed_x = 0
    end
    if @distanse_y == 0
      @move_speed_y = 0
    end
    # X座標移動計算
    # 加減速による移動フレーム数の修正
    boost_x = @moving_x
    move_x = 0
    # 加速がある場合
    if @move_boost_x > 0 && @distanse_x != 0
      # 加減速の正負を左右移動に合わせて変換
      if @distanse_x == 0
        @move_boost_x = 0
      elsif @distanse_x < 0
        @move_boost_x *= -1
      end
      # 距離の変化を事前計算
      for i in 0...@move_speed_x
        boost_x += @move_boost_x
        move_x += boost_x
        # オーバー距離を記録
        over_distance = @distanse_x - move_x
        # 右移動で距離オーバーする直前が何フレーム目だったか記録
        if @distanse_x > 0 && over_distance < 0
          @move_speed_x = i 
          break
        # 左移動で距離オーバーする直前が何フレーム目だったか記録
        elsif @distanse_x < 0 && over_distance > 0
          @move_speed_x = i 
          break
        end 
      end
      # オーバー距離を一回前に戻す
      before = over_distance + boost_x
      # 余った距離を等速移動させるフレーム数を加算
      @move_speed_plus_x = (before / @moving_x).abs
      # それでも余った距離はこの時点で移動し消化
      @move_x += before % @moving_x
      @battler.move_x = @move_x
    # 減速がある場合  
    elsif @move_boost_x < 0 && @distanse_x != 0
      # 加減速の正負を左右移動に合わせて変換
      if @distanse_x == 0
        @move_boost_x = 0
      elsif @distanse_x < 0
        @move_boost_x *= -1
      end
      # 距離の変化を事前計算
      for i in 0...@move_speed_x
        boost_x += @move_boost_x
        move_x += boost_x
        # 足りない距離を記録
        lost_distance = @distanse_x - move_x
        before = lost_distance
        # 右移動で速度が0になる直前が何フレーム目だったか記録
        if @distanse_x > 0 && boost_x < 0
          @move_speed_x = i - 1
          # 足りない距離を一回前に戻す
          before = lost_distance + boost_x
          break
        # 左移動で速度が0になる直前が何フレーム目だったか記録
        elsif @distanse_x < 0 && boost_x > 0
          @move_speed_x= i - 1
          # 足りない距離を一回前に戻す
          before = lost_distance + boost_x
          break
        end
      end
      # 足りない距離を等速移動させるフレーム数を加算
      plus = before / @moving_x
      @move_speed_plus_x = plus.abs
      # それでも余った距離はこの時点で移動し消化
      @move_x += before % @moving_x
      @battler.move_x = @move_x
    end
    # Y座標移動計算
    # 加減速による移動フレーム数の修正
    boost_y = @moving_y
    move_y = 0
    # 加速がある場合
    if @move_boost_y > 0 && @distanse_y != 0
      # 加減速の正負を左右移動に合わせて変換
      if @distanse_y == 0
        @move_boost_y = 0
      elsif @distanse_y < 0
        @move_boost_y *= -1
      end
      # 距離の変化を事前計算
      for i in 0...@move_speed_y
        boost_y += @move_boost_y
        move_y += boost_y
        # オーバー距離を記録
        over_distance = @distanse_y - move_y
        # 右移動で距離オーバーする直前が何フレーム目だったか記録
        if @distanse_y > 0 && over_distance < 0
          @move_speed_y = i 
          break
        # 左移動で距離オーバーする直前が何フレーム目だったか記録
        elsif @distanse_y < 0 && over_distance > 0
          @move_speed_y = i 
          break
        end 
      end
      # オーバー距離を一回前に戻す
      before = over_distance + boost_y
      # 余った距離を等速移動させるフレーム数を加算
      @move_speed_plus_y = (before / @moving_y).abs
      # それでも余った距離はこの時点で移動し消化
      @move_y += before % @moving_y
      @battler.move_y = @move_y
    # 減速がある場合  
    elsif @move_boost_y < 0 && @distanse_y != 0
      # 加減速の正負を左右移動に合わせて変換
      if @distanse_y == 0
        @move_boost_y = 0
      elsif @distanse_y < 0
        @move_boost_y *= -1
      end
      # 距離の変化を事前計算
      for i in 0...@move_speed_y
        boost_y += @move_boost_y
        move_y += boost_y
        # 足りない距離を記録
        lost_distance = @distanse_y - move_y
        before = lost_distance
        # 右移動で速度が0になる直前が何フレーム目だったか記録
        if @distanse_y > 0 && boost_y < 0
          @move_speed_y = i 
          # 足りない距離を一回前に戻す
          before = lost_distance + boost_y
          break
        # 左移動で速度が0になる直前が何フレーム目だったか記録
        elsif @distanse_y < 0 && boost_y > 0
          @move_speed_y = i 
          # 足りない距離を一回前に戻す
          before = lost_distance + boost_y
          break
        end
      end
      # 足りない距離を等速移動させるフレーム数を加算
      plus = before / @moving_y
      @move_speed_plus_y = plus.abs
      # それでも余った距離はこの時点で移動し消化
      @move_y += before % @moving_y
      @battler.move_y = @move_y
    end
    # 移動完了時間を算出
    x = @move_speed_plus_x + @move_speed_x
    y = @move_speed_plus_y + @move_speed_y
    if x > y
      end_time = x
    else
      end_time = y
    end
    # 移動が完了するまで次のアクションに行かない
    @wait = end_time
    # ジャンプ計算
    if @jump != 0
      # 移動がなくジャンプのみの場合
      if @wait == 0
        # 時間に計上
        @wait = @active_action[3]
      end  
      # 移動完了時間からジャンプ時間を算出
      @jump_time = @wait / 2
      # 割り切れない場合の余り時間
      @jump_time_plus = @wait % 2
      # ジャンプの正負を判別
      @jump_sign = 0
      @jump_sign2 = 0
      if @jump < 0
        @jump_sign = -1
        @jump_sign2 = 1
        @jump = @jump * -1
      else
        @jump_sign = 1
        @jump_sign2 = -1
      end
      # ジャンプ初速度を決定
      @jump_up = 2 ** @jump * @jump_sign
      # ジャンプ時間の端数を微調整
      if @jump_time == 0
        @jump_up = 0
      elsif @jump_time != 1
        @jump_size = @jump_up * @jump_sign * @jump_sign2
      else
        @jump_size = @jump_up * 2 * @jump_sign * @jump_sign2
        @jump_flug = true
      end  
    end
  end
  #--------------------------------------------------------------------------
  # ● バトラーアニメ開始
  #--------------------------------------------------------------------------
  def battler_anime
    # アニメ設定を反映
    @anime_kind  = @active_action[1]
    @anime_speed = @active_action[2]
    @anime_loop  = @active_action[3]
    # ウエイト時間があれば加算
    @unloop_wait = @active_action[4]
    @anime_end = true
    @reverse = false
    # 武器アクションがある場合だけ更新する
    if @weapon_R != nil && @active_action[8] != ""
      # 武器の設定をチェック
      weapon_kind = N01::ANIME[@active_action[8]]
      # エネミーと二刀ではないアクターの二刀フラグアニメ処理はキャンセル
      two_swords_flug = weapon_kind[11]
      return if two_swords_flug && !@battler.actor?
      return if two_swords_flug && @battler.weapons[1] == nil && @battler.actor?
      if @battler.actor? && @battler.weapons[0] == nil && !two_swords_flug
        @weapon_R.action_reset
      elsif @battler.actor? && @battler.weapons[1] == nil && two_swords_flug
        @weapon_R.action_reset
      elsif !@battler.actor? && @battler.weapon == 0
        @weapon_R.action_reset
      else
        # 初期化
        @weapon_R.action_reset
        # アニメパターンが固定だった場合の武器位置を取得
        if @active_action[5] != -1
          @weapon_R.freeze(@active_action[5])
        end
        # 武器画像を設定
        @weapon_R.weapon_graphics unless two_swords_flug
        @weapon_R.weapon_graphics(true) if two_swords_flug
        # 武器アクションを渡す
        @weapon_R.weapon_action(@active_action[8],@anime_loop)
        @weapon_action = true
        # 最初の武器アクションを更新
        @weapon_R.action 
      end
    elsif @weapon_R != nil
      @weapon_R.action_reset
    end  
    @anime_end = false
    # アニメパターンが固定だった場合
    if @active_action[5] != -1 && @active_action[5] != -2
      # フラグオン
      @anime_freeze = true
      # アニメが常に終了しているとみなす
      @anime_end = true
    # 片道逆転再生だった場合
    elsif @active_action[5] == -2
      @anime_freeze = false
      # フラグオン
      @reverse = true
      # 最初のアニメパターンを更新
      @pattern = @base_width - 1
      # 武器アニメがある時だけフレーム更新
      if @weapon_action && @weapon_R != nil
        @weapon_R.action 
        @weapon_R.update
      end
    # 通常のアニメ更新の場合  
    else  
      @anime_freeze = false
      # 最初のアニメパターンを更新
      @pattern = 0
      # 武器アニメがある時だけフレーム更新
      if @weapon_action && @weapon_R != nil
        @weapon_R.action 
        @weapon_R.update
      end
    end  
    @pattern_back = false
    @frame = @anime_speed
    # Z座標設定
    @battler.move_z = @active_action[6]
    # 影の有無
    if @shadow != nil
      @shadow.visible = true if @active_action[7]
      @shadow.visible = false unless @active_action[7]
    end
    # ナンバリングから読み取るファイル名を分岐
    if @active_action[0] == 0
      file_name = @battler_name
    else
      file_name = @battler_name + "_" + @active_action[0].to_s
    end  
    # アニメしないバトラーなら処理終了
    return unless @anime_flug
    self.bitmap = Cache.character(file_name)
    # 転送元の矩形を設定
    @sx = @pattern * @width
    @sy = @anime_kind * @height
    @sx = @active_action[5] * @width if @anime_freeze
    self.src_rect.set(@sx, @sy, @width, @height)
  end
  #--------------------------------------------------------------------------
  # ● アニメ飛ばし
  #--------------------------------------------------------------------------
  def moving_anime
    # まだ前のアニメ飛ばしが残っているなら初期化
    @move_anime.action_reset if @anime_moving
    @anime_moving = true
    # バックアタック中はアニメ、武器画像反転
    mirror = false
    mirror = true if $back_attack
    # アニメID
    id = @active_action[1]
    # 対象
    target = @active_action[2]
    x = y = mem = 0
    # 対象が単体の場合
    if target == 0
      # ターゲットが決まってない場合、自身に変換
      if @target_battler == nil
        x = self.x
        y = self.y
      else
        # ターゲットが空の場合、自身に変換
        if @target_battler[0] == nil
          x = self.x
          y = self.y
        else  
          # 最初に入っているターゲットに対象決定
          x = @target_battler[0].position_x
          y = @target_battler[0].position_y
        end  
      end  
    # 対象が敵の中心の場合  
    elsif target == 1
      # 自身がアクターの場合はエネミーの中心を計算
      if @battler.is_a?(Game_Actor)
        for target in $game_troop.members
          x += target.position_x
          y += target.position_y
          mem += 1
        end
        x = x / mem
        y = y / mem
      # 自身がエネミーの場合はアクターの中心を計算
      else
        for target in $game_party.members
          x += target.position_x
          y += target.position_y
          mem += 1
        end
        x = x / mem
        y = y / mem
      end
    # 対象が味方の中心の場合  
    elsif target == 2
      # 自身がアクターの場合はアクターの中心を計算
      if @battler.is_a?(Game_Actor)
        for target in $game_party.members
          x += target.position_x
          y += target.position_y
          mem += 1
        end
        x = x / mem
        y = y / mem
      # 自身がエネミーの場合はエネミーの中心を計算
      else
        for target in $game_troop.members
          x += target.position_x
          y += target.position_y
          mem += 1
        end
        x = x / mem
        y = y / mem
      end
    # 対象が自身の場合  
    else
      x = self.x
      y = self.y
    end  
    # 開始位置の微調整
    plus_x = @active_action[6]
    plus_y = @active_action[7]
    # エネミーはX軸を逆に
    plus_x *= -1 if @battler.is_a?(Game_Enemy)
    # 最終的な移動距離を算出
    distanse_x = x - self.x - plus_x
    distanse_y = y - self.y - plus_y
    # 飛ばしタイプ
    type = @active_action[3]
    # 速度
    speed = @active_action[4]
    # 軌道
    orbit = @active_action[5]
    # 自身が開始位置なら
    if @active_action[8] == 0
      @move_anime.base_x = self.x + plus_x
      @move_anime.base_y = self.y + plus_y
    # 対象が開始位置なら
    elsif @active_action[8] == 1 
      @move_anime.base_x = x + plus_x
      @move_anime.base_y = y + plus_y
      # 距離を反対に
      distanse_y = distanse_y * -1
      distanse_x = distanse_x * -1
    # 動かさないなら
    else 
      @move_anime.base_x = x
      @move_anime.base_y = y
      distanse_x = distanse_y = 0
    end
    # 武器アクションなしは武器表示しない
    if @active_action[10] == ""
      weapon = ""  
    # アニメなしエネミーは武器表示しない
    elsif @anime_flug != true
      weapon = ""  
    # 武器アクションがある場合
    else
      # 飛ばす武器グラフィックが指定されているかチェック
      if @battler.is_a?(Game_Actor)
        battler = $game_party.members[@battler.index] 
        weapon_id = battler.weapon_id
      else  
        battler = $game_troop.members[@battler.index]
        weapon_id = battler.weapon
      end  
      # スキル画像利用か武器画像利用か判別
      weapon_act = N01::ANIME[@active_action[10]].dup if @active_action[10] != ""
      # 武器画像利用で素手でなければ
      if weapon_id != 0 && weapon_act.size == 3
        weapon_file = $data_weapons[weapon_id].flying_graphic
        # 別画像が指定されていなければ既存の武器グラフィックを取得
        if weapon_file == ""
          weapon_name = $data_weapons[weapon_id].graphic
          icon_weapon = false
          # さらに指定がなければアイコングラフィックを利用
          if weapon_name == ""
            weapon_name = $data_weapons[weapon_id].icon_index
            icon_weapon = true
          end  
        # 指定されていればそのグラフィック名を取得  
        else
          icon_weapon = false
          weapon_name = weapon_file
        end
        # 武器アクション情報を取得
        weapon = @active_action[10]
      # 武器画像利用で素手なら表示しない
      elsif weapon_act.size == 3
        weapon = ""
      # スキル画像利用
      elsif weapon_act != nil && @battler.action.skill != nil
        icon_weapon = false
        weapon_name = $data_skills[@battler.action.skill.id].flying_graphic
        weapon = @active_action[10]
      end
    end
    # Z座標を決定
    @move_anime.z = 1
    @move_anime.z = 1000 if @active_action[9]
    # 以上の情報を全てアニメ飛ばしスプライトに送る
    @move_anime.anime_action(id,mirror,distanse_x,distanse_y,type,speed,orbit,weapon,weapon_name,icon_weapon)
  end  
  #--------------------------------------------------------------------------
  # ● アクション終了 
  #--------------------------------------------------------------------------
  def anime_finish
    # 個別処理終了が省略された場合リピートさせる
    return individual_action_end if @individual_targets.size != 0
    # アクティブバトラーにアクション情報を格納
    send_action(@active_action[0]) if @battler.active
    # 残像があれば開放
    mirage_off if @mirage_flug
    # 待機アクションを繰り返す
    start_action(@repeat_action) unless @non_repeat
  end   
  #--------------------------------------------------------------------------
  # ● コラプスアクション
  #--------------------------------------------------------------------------
  def collapse_action
    @non_repeat = true
    @effect_type = COLLAPSE
    @collapse_type = @battler.collapse_type unless @battler.actor?
    @battler_visible = false unless @battler.actor?
    @effect_duration = N01::COLLAPSE_WAIT + 48 if @collapse_type == 2
    @effect_duration = 401 if @collapse_type == 3
  end  
  #--------------------------------------------------------------------------
  # ● ノーマルコラプス
  #--------------------------------------------------------------------------
  def normal_collapse
    if @effect_duration == 47
      Sound.play_enemy_collapse
      self.blend_type = 1
      self.color.set(255, 128, 128, 128)
    end
    self.opacity = 256 - (48 - @effect_duration) * 6 if @effect_duration <= 47
  end  
  #--------------------------------------------------------------------------
  # ● ボスコラプス
  #--------------------------------------------------------------------------
  def boss_collapse1
    if @effect_duration == 320
      Audio.se_play("Audio/SE/Absorb1", 100, 80)
      self.flash(Color.new(255, 255, 255), 60)
      viewport.flash(Color.new(255, 255, 255), 20)
    end
    if @effect_duration == 280
      Audio.se_play("Audio/SE/Absorb1", 100, 80)
      self.flash(Color.new(255, 255, 255), 60)
      viewport.flash(Color.new(255, 255, 255), 20)
    end
    if @effect_duration == 220
      Audio.se_play("Audio/SE/Earth4", 100, 80)
      reset
      self.blend_type = 1
      self.color.set(255, 128, 128, 128)
      self.wave_amp = 6
    end
    if @effect_duration < 220
      self.src_rect.set(0, @effect_duration / 2 - 110, @width, @height)
      self.x += 8 if @effect_duration % 4 == 0
      self.x -= 8 if @effect_duration % 4 == 2
      self.wave_amp += 1 if @effect_duration % 10 == 0
      self.opacity = @effect_duration
      return if @effect_duration < 50
      Audio.se_play("Audio/SE/Earth4", 100, 50) if @effect_duration % 50 == 0
    end
  end
end