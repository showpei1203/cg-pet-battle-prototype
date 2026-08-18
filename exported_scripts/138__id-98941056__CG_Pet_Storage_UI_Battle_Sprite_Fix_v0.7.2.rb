# RMVX_SCRIPT_INDEX: 138
# RMVX_SCRIPT_ID: 98941056
# RMVX_SCRIPT_NAME: CG Pet Storage UI Battle Sprite Fix v0.7.2
# RMVX_SOURCE_SHA256: 12834fc8eb63af23cb4406f3463b00716997adb96abd99438f3b7699178c86a2

#==============================================================================
# 【繁體中文說明】ALBERT CG 倉庫介面與換寵 Sprite 更新修正
#------------------------------------------------------------------------------
# 【版本】v0.7.2
# 【用途】
#  1. 戰鬥中派出、收回或更換寵物時，只更新實際改變的我方 Sprite。
#     不再因 $party_change 而銷毀整隊 Sprite，避免所有人物重播 SBS 進場動作。
#  2. 修正 F5 寵物管理右下角指令視窗超出 544×416 畫面的問題。
#  3. 在寵物名字後方顯示該個體的行走圖中央待機格，方便辨識同名寵物。
#
# 【戰鬥 Sprite 規則】
#  - 尚未改變的隊員會沿用原 Sprite，不重播進場動作。
#  - 被收回的寵物只銷毀自己的 Sprite。
#  - 新派出的寵物只建立自己的 Sprite，直接進入待機動作。
#  - 派出／收回動畫仍由 CG Battle Move Pet Switch 的動畫設定控制。
#
# 【F5 介面配置】
#  - 左側名冊：X=0，Y=56，W=240，H=360。
#  - 右上詳細資料：X=240，Y=56，W=304，H=208。
#  - 右下指令視窗：X=240，Y=264，W=304，H=152。
#  - 右下視窗固定保留五列高度，不會超出遊戲畫面。
#
# 【注意事項】
#  - 本腳本必須放在 CG Pet Storage 下方、Main 上方。
#  - 本腳本只處理畫面 Sprite，不改變隊伍、寵物名冊或戰鬥行動資料。
#  - 行走圖使用角色目前的 character_name／character_index。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PetStorageUIBattleSpriteFix"] = true

module ALBERT_CG
  PET_STORAGE_UI_FIX_VERSION = "0.7.2"
  PET_LIST_CHARACTER_SIZE = 22 unless const_defined?(:PET_LIST_CHARACTER_SIZE)
end

#==============================================================================
# ■ Sprite_Battler
#------------------------------------------------------------------------------
#  新派出的寵物建立 Sprite 時，直接開始待機動作，不播放 first_action 進場序列。
#==============================================================================
class Sprite_Battler < Sprite_Base
  def cg_setup_without_battle_entry
    return false if @battler == nil
    @battler_visible = true
    @anime_flug = true if @battler.actor?
    @anime_flug = true if !@battler.actor? && @battler.anime_on
    make_battler
    make_shadow if N01::SHADOW
    self.visible = true
    self.opacity = 255
    start_action(@battler.normal)
    return true
  end
end

#==============================================================================
# ■ Spriteset_Battle
#------------------------------------------------------------------------------
#  Tankentai 原版偵測 $party_change 時會 dispose_actors／create_actors，並對所有
#  我方角色呼叫 first_action。本段改為依 Battler ID 重用未改變的 Sprite。
#==============================================================================
class Spriteset_Battle
  def cg_v072_sprite_battler_id(sprite)
    return nil if sprite == nil
    battler = sprite.battler
    return nil if battler == nil
    return battler.id
  rescue
    return nil
  end

  def cg_v072_actor_sprite_count
    return N01::MAX_MEMBER if defined?(N01::MAX_MEMBER)
    count = $game_party == nil ? 4 : $game_party.members.size
    return [count, 4].max
  end

  def cg_v072_actor_sprite_order_matches?
    return false if @actor_sprites == nil
    count = cg_v072_actor_sprite_count
    return false unless @actor_sprites.size == count
    members = $game_party.members
    for i in 0...count
      member = members[i]
      sprite = @actor_sprites[i]
      sprite_id = cg_v072_sprite_battler_id(sprite)
      member_id = member == nil ? nil : member.id
      return false unless sprite_id == member_id
    end
    return true
  end

  def cg_v072_dispose_actor_sprite(sprite)
    return if sprite == nil
    return if sprite.respond_to?(:disposed?) && sprite.disposed?
    sprite.dispose
  rescue
  end

  def cg_v072_refresh_actor_sprites_without_entry
    old_sprites = @actor_sprites == nil ? [] : @actor_sprites
    sprite_pool = {}
    empty_sprites = []

    for sprite in old_sprites
      battler_id = cg_v072_sprite_battler_id(sprite)
      if battler_id == nil
        empty_sprites.push(sprite)
      else
        sprite_pool[battler_id] = [] if sprite_pool[battler_id] == nil
        sprite_pool[battler_id].push(sprite)
      end
    end

    count = cg_v072_actor_sprite_count
    members = $game_party.members
    new_sprites = []

    for i in 0...count
      battler = members[i]
      sprite = nil
      if battler != nil
        pool = sprite_pool[battler.id]
        sprite = pool.shift if pool != nil && !pool.empty?
        if sprite == nil
          sprite = Sprite_Battler.new(@viewport1, battler)
          sprite.cg_setup_without_battle_entry
        end
      else
        sprite = empty_sprites.shift unless empty_sprites.empty?
        sprite = Sprite_Battler.new(@viewport1, nil) if sprite == nil
      end
      new_sprites.push(sprite)
    end

    for battler_id in sprite_pool.keys
      pool = sprite_pool[battler_id]
      for sprite in pool
        cg_v072_dispose_actor_sprite(sprite)
      end
    end
    for sprite in empty_sprites
      cg_v072_dispose_actor_sprite(sprite)
    end

    @actor_sprites = new_sprites
    $party_change = false
    return true
  end

  # 完整覆寫 Tankentai 的 update_actors，避免原版整隊重建與重播進場。
  def update_actors
    if $party_change || !cg_v072_actor_sprite_order_matches?
      cg_v072_refresh_actor_sprites_without_entry
    end
    for sprite in @actor_sprites
      sprite.update if sprite != nil
    end
  end
end

#==============================================================================
# ■ Window_CG_PetList
#------------------------------------------------------------------------------
#  名字後方繪製縮小的角色行走圖中央待機格。
#==============================================================================
class Window_CG_PetList < Window_Selectable
  def cg_v072_big_character_name?(name)
    text = name.to_s
    return true if text[0, 1] == "$"
    return true if text[0, 2] == "!$"
    return true if text[0, 2] == "$!"
    return false
  end

  def cg_v072_draw_pet_character(pet, x, y)
    return false if pet == nil
    name = pet.character_name.to_s
    return false if name.empty?
    index = pet.character_index.to_i
    bitmap = Cache.character(name)
    if cg_v072_big_character_name?(name)
      cw = bitmap.width / 3
      ch = bitmap.height / 4
      sx = cw
      sy = 0
    else
      cw = bitmap.width / 12
      ch = bitmap.height / 8
      sx = (index % 4 * 3 + 1) * cw
      sy = (index / 4 * 4) * ch
    end
    return false if cw <= 0 || ch <= 0
    size = ALBERT_CG::PET_LIST_CHARACTER_SIZE
    scale = [size.to_f / cw, size.to_f / ch].min
    dw = [(cw * scale).to_i, 1].max
    dh = [(ch * scale).to_i, 1].max
    dx = x + (size - dw) / 2
    dy = y + (WLH - dh) / 2
    self.contents.stretch_blt(Rect.new(dx, dy, dw, dh), bitmap,
                              Rect.new(sx, sy, cw, ch))
    return true
  rescue
    return false
  end

  def draw_item(index)
    pet = @data[index]
    return if pet == nil
    rect = item_rect(index)
    self.contents.clear_rect(rect)

    active = false
    if @mode == :carried
      current = $game_party.respond_to?(:cg_actual_primary_clone_pet) ?
        $game_party.cg_actual_primary_clone_pet : nil
      active = current != nil && current.id == pet.id
    end

    prefix = active ? "◆ " : "　"
    label = prefix + pet.name.to_s
    level_width = 52
    sprite_size = ALBERT_CG::PET_LIST_CHARACTER_SIZE
    level_x = rect.x + rect.width - level_width
    max_sprite_x = level_x - sprite_size - 2
    measured = self.contents.text_size(label).width + 2
    sprite_x = rect.x + measured
    sprite_x = max_sprite_x if sprite_x > max_sprite_x
    sprite_x = rect.x + 4 if sprite_x < rect.x + 4
    name_width = sprite_x - rect.x - 2
    name_width = 4 if name_width < 4

    self.contents.draw_text(rect.x, rect.y, name_width, WLH, label)
    cg_v072_draw_pet_character(pet, sprite_x, rect.y)
    self.contents.draw_text(level_x, rect.y, level_width, WLH,
                            "Lv." + pet.level.to_s, 2)
  end
end

#==============================================================================
# ■ Window_CG_PetDetail
#------------------------------------------------------------------------------
#  將詳細資料高度縮為 208，騰出右下五列指令視窗的完整空間。
#==============================================================================
class Window_CG_PetDetail < Window_Base
  def initialize
    super(240, 56, 304, 208)
    @pet = nil
  end
end

#==============================================================================
# ■ Scene_CG_PetLab
#------------------------------------------------------------------------------
#  右下指令視窗固定五列高度並放在 Y=264，底部正好落在 416。
#==============================================================================
class Scene_CG_PetLab < Scene_Base
  def rebuild_command_window
    old_active = @command_window != nil && @command_window.active
    @command_window.dispose if @command_window != nil
    commands = if @mode == :storage
      ["取出／交換至攜帶", "放生", "取消"]
    else
      ["設為出戰", "存入倉庫", "收回目前寵物", "放生", "取消"]
    end
    @command_window = Window_Command.new(304, commands, 1, 5)
    @command_window.x = 240
    @command_window.y = 264
    @command_window.active = old_active
    @command_window.index = old_active ? 0 : -1
  end
end
