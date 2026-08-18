# RMVX_SCRIPT_INDEX: 160
# RMVX_SCRIPT_ID: 98941065
# RMVX_SCRIPT_NAME: CG Battle Window & Link Polish v1.8.3d
# RMVX_SOURCE_SHA256: 97a6a6ac72799abd59ed4395d274c4e6a995d76496c57a2d8682dc9f5f8080c3

#==============================================================================
# ■ CG Battle Window & Link Polish v1.8.3d
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【本版修正】
#  1. 修正 v1.8.3c 圓角漸變背景未繪製，造成選項只剩文字的問題。
#  2. 修正目前選中選項與 battler 高光圈之間的折線未顯示。
#  3. Command／Fight／Skill／Item／移動／換寵等維持同一張卡片規格。
#  4. 只繪製目前選中選項的連線；路徑固定為水平→垂直→水平。
#
# 【原因】
#  v1.8.3b 的圓角 helper 對 RGSS2 Bitmap#gradient_fill_rect 使用了
#  不相容的額外參數，錯誤又被 rescue 吞掉，因此背景完全沒畫出來。
#  本版改用 RGSS2 可用的 6 參數呼叫，並保留逐像素備援。
#
# 【腳本位置】
#  放在 CG Battle Visual Polish v1.8.3b 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_BattleWindowLinkPolish_1_8_3d"] = true

module ALBERT_CG
  if const_defined?(:BATTLE_UI_VERSION)
    remove_const(:BATTLE_UI_VERSION)
  end
  BATTLE_UI_VERSION = "1.8.3d"

  module BattleVisualV183d
    CARD_RADIUS = 7
    BORDER_ALPHA = 235
    NORMAL_LEFT_ALPHA = 225
    NORMAL_RIGHT_ALPHA = 132
    SELECT_LEFT_ALPHA = 252
    SELECT_RIGHT_ALPHA = 188
    DISABLED_LEFT_ALPHA = 150
    DISABLED_RIGHT_ALPHA = 82

    def self.apply_title
      return if $data_system == nil
      $data_system.game_title = "CG Pet Battle Prototype v1.8.3d"
    end

    def self.interpolate_color(color1, color2, rate)
      rate = [[rate.to_f, 0.0].max, 1.0].min
      red = (color1.red + (color2.red - color1.red) * rate).round
      green = (color1.green + (color2.green - color1.green) * rate).round
      blue = (color1.blue + (color2.blue - color1.blue) * rate).round
      alpha = (color1.alpha + (color2.alpha - color1.alpha) * rate).round
      return Color.new(red, green, blue, alpha)
    end

    # RGSS2-safe rounded horizontal gradient.
    def self.fill_round_gradient(bitmap, x, y, width, height, radius,
      color1, color2)
      return if bitmap == nil || bitmap.disposed?
      x = x.to_i
      y = y.to_i
      width = width.to_i
      height = height.to_i
      return if width <= 0 || height <= 0
      radius = [radius.to_i, width / 2, height / 2].min
      radius = 1 if radius < 1

      for row in 0...height
        inset = ALBERT_CG::BattleVisualV183b.round_inset(row, height, radius)
        line_width = width - inset * 2
        next if line_width <= 0
        line_x = x + inset
        line_y = y + row
        begin
          # VX / RGSS2 uses this 6-argument form. Do not append `false`.
          bitmap.gradient_fill_rect(line_x, line_y, line_width, 1,
            color1, color2)
        rescue
          # Defensive fallback for modified Bitmap implementations.
          denominator = [line_width - 1, 1].max.to_f
          for column in 0...line_width
            rate = column.to_f / denominator
            color = interpolate_color(color1, color2, rate)
            bitmap.fill_rect(line_x + column, line_y, 1, 1, color)
          end
        end
      end
    end

    def self.axis_line(bitmap, x1, y1, x2, y2, color, thickness = 1)
      return if bitmap == nil || bitmap.disposed?
      x1 = x1.to_i
      y1 = y1.to_i
      x2 = x2.to_i
      y2 = y2.to_i
      thickness = [thickness.to_i, 1].max
      if y1 == y2
        left = [x1, x2].min
        width = (x2 - x1).abs + 1
        bitmap.fill_rect(left, y1 - thickness / 2,
          width, thickness, color)
      elsif x1 == x2
        top = [y1, y2].min
        height = (y2 - y1).abs + 1
        bitmap.fill_rect(x1 - thickness / 2, top,
          thickness, height, color)
      end
    end

    def self.orthogonal_line(bitmap, start_x, start_y, finish_x, finish_y,
      color, thickness = 3, shadow = nil)
      return if bitmap == nil || bitmap.disposed?
      start_x = start_x.to_i
      start_y = start_y.to_i
      finish_x = finish_x.to_i
      finish_y = finish_y.to_i
      elbow_x = ((start_x + finish_x) / 2.0).round

      if shadow != nil
        axis_line(bitmap, start_x, start_y + 1,
          elbow_x, start_y + 1, shadow, thickness + 2)
        axis_line(bitmap, elbow_x + 1, start_y,
          elbow_x + 1, finish_y, shadow, thickness + 2)
        axis_line(bitmap, elbow_x, finish_y + 1,
          finish_x, finish_y + 1, shadow, thickness + 2)
      end

      axis_line(bitmap, start_x, start_y,
        elbow_x, start_y, color, thickness)
      axis_line(bitmap, elbow_x, start_y,
        elbow_x, finish_y, color, thickness)
      axis_line(bitmap, elbow_x, finish_y,
        finish_x, finish_y, color, thickness)

      # Make both elbows and the endpoint unmistakable on busy battlebacks.
      bitmap.fill_rect(elbow_x - 2, start_y - 2, 5, 5, color)
      bitmap.fill_rect(elbow_x - 2, finish_y - 2, 5, 5, color)
      bitmap.fill_rect(finish_x - 2, finish_y - 2, 5, 5, color)
    end
  end
end

# Replace the broken helper globally so Battle Status rounded panels also work.
module ALBERT_CG
  module BattleVisualV183b
    def self.fill_round_gradient(bitmap, x, y, width, height, radius,
      color1, color2)
      ALBERT_CG::BattleVisualV183d.fill_round_gradient(bitmap,
        x, y, width, height, radius, color1, color2)
    end
  end
end

#==============================================================================
# ■ Battler Sidecar cards
#==============================================================================
module ALBERT_CG
  module BattlerSidecarUI
    def self.fixed_card(text, type, selected, enabled, icon_index = nil,
      quantity = nil)
      @card_cache = {} if @card_cache == nil
      key = [:round_v183d, text.to_s, type, selected ? 1 : 0,
        enabled ? 1 : 0, icon_index.to_i, quantity]
      bitmap = @card_cache[key]
      return bitmap if bitmap != nil && !bitmap.disposed?

      width = VERTICAL_CARD_WIDTH
      height = VERTICAL_CARD_HEIGHT
      bitmap = Bitmap.new(width, height)
      colors = selected && enabled ? command_type_color(type) : gray_colors

      if !enabled
        left_alpha = ALBERT_CG::BattleVisualV183d::DISABLED_LEFT_ALPHA
        right_alpha = ALBERT_CG::BattleVisualV183d::DISABLED_RIGHT_ALPHA
      elsif selected
        left_alpha = ALBERT_CG::BattleVisualV183d::SELECT_LEFT_ALPHA
        right_alpha = ALBERT_CG::BattleVisualV183d::SELECT_RIGHT_ALPHA
      else
        left_alpha = ALBERT_CG::BattleVisualV183d::NORMAL_LEFT_ALPHA
        right_alpha = ALBERT_CG::BattleVisualV183d::NORMAL_RIGHT_ALPHA
      end

      c1 = Color.new(colors[0].red, colors[0].green, colors[0].blue,
        left_alpha)
      c2 = Color.new(colors[1].red, colors[1].green, colors[1].blue,
        right_alpha)
      border_base = selected ? FOCUS_GOLD :
        Color.new(82, 92, 108, ALBERT_CG::BattleVisualV183d::BORDER_ALPHA)
      border_end = Color.new(border_base.red, border_base.green,
        border_base.blue, selected ? 170 : 110)

      ALBERT_CG::BattleVisualV183d.fill_round_gradient(bitmap,
        0, 0, width, height, ALBERT_CG::BattleVisualV183d::CARD_RADIUS,
        border_base, border_end)
      ALBERT_CG::BattleVisualV183d.fill_round_gradient(bitmap,
        1, 1, width - 2, height - 2,
        ALBERT_CG::BattleVisualV183d::CARD_RADIUS - 1, c1, c2)

      accent = command_type_color(type)[0] rescue FOCUS_CYAN
      accent_alpha = selected ? 255 : (enabled ? 215 : 105)
      ALBERT_CG::BattleVisualV183d.fill_round_gradient(bitmap,
        3, 4, 4, height - 8, 2,
        Color.new(accent.red, accent.green, accent.blue, accent_alpha),
        Color.new(accent.red, accent.green, accent.blue,
          [accent_alpha - 45, 40].max))

      if selected
        bitmap.fill_rect(10, 2, width - 20, 1,
          Color.new(255, 252, 216, 235))
        bitmap.fill_rect(10, height - 3, width - 20, 1,
          Color.new(255, 224, 104, 195))
      end

      text_x = 10
      if icon_index != nil && icon_index.to_i > 0
        icon_index = icon_index.to_i
        if selected && enabled
          iconset = Cache.system("IconSet")
          source = Rect.new(icon_index % 16 * 24,
            icon_index / 16 * 24, 24, 24)
          target = Rect.new(7, 2, 18, 18)
          if defined?(ALBERT_CG::TRGSSXVisual)
            ALBERT_CG::TRGSSXVisual.stretch_blt(
              bitmap, target, iconset, source, left_alpha)
          else
            bitmap.stretch_blt(target, iconset, source, left_alpha)
          end
        else
          gray = gray_icon(icon_index)
          if gray != nil
            target = Rect.new(7, 2, 18, 18)
            if defined?(ALBERT_CG::TRGSSXVisual)
              ALBERT_CG::TRGSSXVisual.stretch_blt(
                bitmap, target, gray, gray.rect, left_alpha)
            else
              bitmap.stretch_blt(target, gray, gray.rect, left_alpha)
            end
          end
        end
        text_x = 28
      end

      right_space = quantity == nil ? 6 : 25
      old_size = bitmap.font.size
      old_bold = bitmap.font.bold
      old_color = bitmap.font.color
      bitmap.font.bold = selected
      fit_font(bitmap, text.to_s, width - text_x - right_space,
        FONT_SIZE, 9)
      bitmap.font.color = Color.new(0, 0, 0, enabled ? 235 : 165)
      bitmap.draw_text(text_x + 1, 1, width - text_x - right_space,
        height - 2, text.to_s, 0)
      bitmap.font.color = enabled ? Color.new(255, 255, 255) :
        Color.new(190, 190, 196)
      bitmap.draw_text(text_x, 0, width - text_x - right_space,
        height - 2, text.to_s, 0)

      if quantity != nil
        bitmap.font.size = 9
        bitmap.font.bold = true
        qtext = quantity.to_i.to_s
        bitmap.font.color = Color.new(0, 0, 0, 225)
        bitmap.draw_text(width - 23, 2, 19, height - 3, qtext, 2)
        bitmap.font.color = Color.new(255, 255, 255)
        bitmap.draw_text(width - 24, 1, 19, height - 3, qtext, 2)
      end
      bitmap.font.size = old_size
      bitmap.font.bold = old_bold
      bitmap.font.color = old_color
      @card_cache[key] = bitmap
      return bitmap
    end
  end
end

#==============================================================================
# ■ Sprite_CG_BattlerFocus
#------------------------------------------------------------------------------
# Only the selected row is connected. The route is axis-aligned and targets
# the nearest edge of that row's actual animated card position.
#==============================================================================
class Sprite_CG_BattlerFocus
  def update(anchor, window, type = nil, battler_z = nil)
    if anchor == nil || window == nil || !window.visible
      hide
      return
    end
    type = :attack if type == nil
    cg_v183_draw_ring(type) if @cg_v183_ring_type != type
    center_x = anchor[4].to_i
    foot_y = anchor[3].to_i - 2
    @ring.x = center_x
    @ring.y = foot_y
    @ring.z = battler_z == nil ? 80 : [battler_z.to_i - 1, 1].max
    @ring.opacity = 180 + ((Graphics.frame_count / 3) % 2) * 55
    @ring.visible = true

    bitmap = @line_layer.bitmap
    bitmap.clear
    specs = window.respond_to?(:cg_v183b_line_specs) ?
      window.cg_v183b_line_specs : []
    specs = [] if specs == nil
    selected_spec = nil
    for spec in specs
      if spec[2]
        selected_spec = spec
        break
      end
    end
    selected_spec = specs[0] if selected_spec == nil && !specs.empty?
    selected_spec = [0, type, true, true, 0, 255] if selected_spec == nil

    row, row_type, selected, enabled, slide_x, row_opacity = selected_spec
    card_width = ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_WIDTH
    card_height = ALBERT_CG::BattlerSidecarUI::VERTICAL_CARD_HEIGHT
    card_gap = ALBERT_CG::BattlerSidecarUI::VERTICAL_GAP
    card_x = window.x.to_i + 16 + slide_x.to_i
    card_y = window.y.to_i + 16 + row.to_i * (card_height + card_gap)
    card_center_x = card_x + card_width / 2
    finish_y = card_y + card_height / 2

    if card_center_x >= center_x
      ring_x = center_x + 29
      finish_x = card_x
    else
      ring_x = center_x - 29
      finish_x = card_x + card_width
    end
    ring_y = foot_y

    color = ALBERT_CG::BattleVisualV183b.line_color(
      row_type, true, enabled)
    opacity = row_opacity == nil ? 255 : row_opacity.to_i
    opacity = 255 if opacity > 255
    opacity = 90 if opacity < 90
    alpha = color.alpha * opacity / 255
    alpha = 215 if alpha < 215 && enabled
    color = Color.new(color.red, color.green, color.blue, alpha)
    shadow = Color.new(0, 0, 0, 150)

    @line_layer.x = 0
    @line_layer.y = 0
    @line_layer.z = 539
    @line_layer.opacity = 255
    @line_layer.blend_type = 0
    ALBERT_CG::BattleVisualV183d.orthogonal_line(bitmap,
      ring_x, ring_y, finish_x, finish_y, color, 3, shadow)
    @line_layer.visible = true
  rescue
    # Keep the battler ring even if an unexpected custom window lacks geometry.
    if @line_layer != nil
      @line_layer.bitmap.clear if @line_layer.bitmap != nil &&
        !@line_layer.bitmap.disposed?
      @line_layer.visible = false
    end
  end
end

#==============================================================================
# ■ Scene_Title
#==============================================================================
class Scene_Title < Scene_Base
  unless method_defined?(:albert_cg_v183d_load_database)
    alias albert_cg_v183d_load_database load_database
  end

  def load_database
    albert_cg_v183d_load_database
    ALBERT_CG::BattleVisualV183d.apply_title
  end
end
