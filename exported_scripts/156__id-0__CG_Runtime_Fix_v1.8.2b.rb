# RMVX_SCRIPT_INDEX: 156
# RMVX_SCRIPT_ID: 0
# RMVX_SCRIPT_NAME: CG Runtime Fix v1.8.2b
# RMVX_SOURCE_SHA256: d26c94e91395eed38867e04933a58723c42a0356fcd789f35a1a5e08c96f78b8

#==============================================================================
# ■ CG Runtime Fix v1.8.2b
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2
#
# 修正：
#  1. Sprite_CG_BattlerHUD 的兩參數建構式遭後續腳本誤覆寫。
#  2. Window_MenuStatus 仍使用 VX 原版 24px 捲動單位，無法正確顯示
#     第 5、6 名隊員。
#
# 放置：CG Battler Sidecar UI v1.8.2 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_RuntimeFix_1_8_2b"] = true

module ALBERT_CG
  MENU_STATUS_ITEM_HEIGHT = 96 unless const_defined?(:MENU_STATUS_ITEM_HEIGHT)
end

#------------------------------------------------------------------------------
# 保險：明確恢復 HUD 的兩參數建構式。
#------------------------------------------------------------------------------
class Sprite_CG_BattlerHUD
  def initialize(viewport, battler)
    @battler = battler
    @last_signature = nil

    @bar_sprite = Sprite.new(viewport)
    @bar_sprite.bitmap = Bitmap.new(ALBERT_CG::BATTLE_HUD_BAR_SPRITE_WIDTH,
      ALBERT_CG::BATTLE_HUD_BAR_SPRITE_HEIGHT)
    @bar_sprite.z = 260
    @bar_sprite.visible = false

    @label_sprite = Sprite.new(viewport)
    @label_sprite.bitmap = Bitmap.new(ALBERT_CG::BATTLE_HUD_LABEL_WIDTH,
      ALBERT_CG::BATTLE_HUD_LABEL_HEIGHT)
    @label_sprite.z = 261
    @label_sprite.visible = false
  end
end

#------------------------------------------------------------------------------
# 六人主選單捲動。
#------------------------------------------------------------------------------
class Window_MenuStatus < Window_Selectable
  def cg_menu_item_height
    return ALBERT_CG::MENU_STATUS_ITEM_HEIGHT
  end

  def refresh
    @item_max = $game_party.members.size
    old_oy = self.oy
    self.contents.dispose if self.contents != nil && !self.contents.disposed?
    content_height = [height - 32, @item_max * cg_menu_item_height].max
    self.contents = Bitmap.new(width - 32, content_height)

    for actor in $game_party.members
      index = actor.index
      draw_actor_face(actor, 2, index * cg_menu_item_height + 2, 92)
      x = 104
      y = index * cg_menu_item_height + WLH / 2
      draw_actor_name(actor, x, y)
      draw_actor_class(actor, x + 120, y)
      draw_actor_level(actor, x, y + WLH * 1)
      draw_actor_state(actor, x, y + WLH * 2)
      draw_actor_hp(actor, x + 120, y + WLH * 1)
      draw_actor_mp(actor, x + 120, y + WLH * 2)
    end

    max_oy = [self.contents.height - (height - 32), 0].max
    self.oy = [[old_oy, 0].max, max_oy].min
    update_cursor
  end

  def top_row
    return self.oy / cg_menu_item_height
  end

  def top_row=(row)
    max_top = [row_max - page_row_max, 0].max
    row = 0 if row < 0
    row = max_top if row > max_top
    self.oy = row * cg_menu_item_height
  end

  def page_row_max
    rows = (self.height - 32) / cg_menu_item_height
    return [rows, 1].max
  end

  def page_item_max
    return page_row_max * @column_max
  end

  def bottom_row
    return top_row + page_row_max - 1
  end

  def bottom_row=(row)
    self.top_row = row - page_row_max + 1
  end

  def item_rect(index)
    rect = Rect.new(0, 0, contents.width, cg_menu_item_height)
    rect.y = index * cg_menu_item_height
    return rect
  end

  def update_cursor
    if @index < 0
      self.cursor_rect.empty
      return
    end

    real_index = @index >= 100 ? @index - 100 : @index
    if @index < @item_max || @index >= 100
      row = real_index
      self.top_row = row if row < top_row
      self.bottom_row = row if row > bottom_row
      rect = item_rect(real_index)
      rect.y -= self.oy
      self.cursor_rect = rect
    else
      self.top_row = 0
      height_value = [@item_max * cg_menu_item_height,
        self.height - 32].min
      self.cursor_rect.set(0, 0, contents.width, height_value)
    end
  end
end

#------------------------------------------------------------------------------
# 友方目標視窗若沿用 Window_MenuStatus，也會自動取得相同捲動規則。
#------------------------------------------------------------------------------

module ALBERT_CG
  def self.apply_v182b_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.8.2b"
  end
end

class Scene_Title < Scene_Base
  unless method_defined?(:cg_v182b_load_database)
    alias cg_v182b_load_database load_database
  end

  def load_database
    cg_v182b_load_database
    ALBERT_CG.apply_v182b_title
  end
end
