# RMVX_SCRIPT_INDEX: 154
# RMVX_SCRIPT_ID: 0
# RMVX_SCRIPT_NAME: CG Generic Gauge v0.1
# RMVX_SOURCE_SHA256: 2520b3fd0ea5eed7cadb934d18066c166f9db30380b7a01aac94a16a21d4ae56

#==============================================================================
# ■ CG Generic Gauge v0.1
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2
# 專案：CG Pet Battle Prototype
#
# 【素材】Graphics/System/GaugeHP.png、GaugeMP.png、GaugeEXP.png
#  素材規格：120×48
#  上半部 120×24：左端 24／中央 72／右端 24
#  下半部 72×24：填充值條
#
# 【用途】
#  - Battle Status 使用圖片式 HP／MP。
#  - 敵方浮動 HUD 使用同一套圖片式 HP／MP。
#  - TRGSSX 可用時，縮放由 CG TRGSSX Visual Bridge 處理。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_GenericGauge_0_1"] = true

module ALBERT_CG
  module GenericGauge
    SOURCE_HEIGHT = 24
    SOURCE_CAP = 24
    SOURCE_CENTER = 72
    SOURCE_FILL = 72

    def self.bitmap_name(kind)
      return "GaugeHP" if kind == :hp
      return "GaugeMP" if kind == :mp
      return "GaugeEXP"
    end

    def self.safe_ratio(value, maximum)
      return 0.0 if maximum == nil || maximum.to_f <= 0.0
      rate = value.to_f / maximum.to_f
      rate = 0.0 if rate < 0.0
      rate = 1.0 if rate > 1.0
      return rate
    end

    def self.stretch(target, target_rect, source, source_rect, opacity = 255)
      if defined?(ALBERT_CG::TRGSSXVisual)
        ALBERT_CG::TRGSSXVisual.stretch_blt(
          target, target_rect, source, source_rect, opacity)
      else
        target.stretch_blt(target_rect, source, source_rect, opacity)
      end
    rescue
      target.stretch_blt(target_rect, source, source_rect, opacity)
    end

    def self.draw(target, kind, x, y, width, height, value, maximum,
      opacity = 255)
      return if target == nil || target.disposed?
      width = width.to_i
      height = height.to_i
      return if width <= 0 || height <= 0
      image = Cache.system(bitmap_name(kind))
      return if image == nil || image.disposed?

      cap = [height, width / 3].min
      cap = 1 if cap < 1
      middle_width = width - cap * 2
      middle_width = 1 if middle_width < 1

      # Gauge frame / base.
      stretch(target, Rect.new(x, y, cap, height), image,
        Rect.new(0, 0, SOURCE_CAP, SOURCE_HEIGHT), opacity)
      stretch(target, Rect.new(x + cap, y, middle_width, height), image,
        Rect.new(SOURCE_CAP, 0, SOURCE_CENTER, SOURCE_HEIGHT), opacity)
      stretch(target, Rect.new(x + cap + middle_width, y, cap, height), image,
        Rect.new(SOURCE_CAP + SOURCE_CENTER, 0, SOURCE_CAP, SOURCE_HEIGHT),
        opacity)

      # Fill strip. Keep one-pixel breathing room so the end caps remain clear.
      rate = safe_ratio(value, maximum)
      inner_x = x + cap
      inner_width = middle_width
      fill_width = (inner_width * rate).to_i
      if fill_width > 0
        fill_width = 1 if fill_width < 1
        fill_width = inner_width if fill_width > inner_width
        stretch(target, Rect.new(inner_x, y, fill_width, height), image,
          Rect.new(0, SOURCE_HEIGHT, SOURCE_FILL, SOURCE_HEIGHT), opacity)
      end
    rescue
      # Gauge art is cosmetic; battle must continue even if an asset is missing.
    end
  end
end

class Window_BattleStatus < Window_Selectable
  def cg_draw_status_gauge(actor, x, y, width, kind)
    width = 18 if width < 18
    if kind == :hp
      value = actor.hp.to_i
      maximum = actor.maxhp.to_i
      label = "H"
      text_color = hp_color(actor)
    else
      value = actor.mp.to_i
      maximum = actor.maxmp.to_i
      label = "M"
      text_color = mp_color(actor)
    end

    ALBERT_CG::GenericGauge.draw(self.contents, kind,
      x, y + 7, width, 8, value, maximum)

    old_size = self.contents.font.size
    old_color = self.contents.font.color
    old_bold = self.contents.font.bold
    self.contents.font.size = 9
    self.contents.font.bold = true
    self.contents.font.color = Color.new(0, 0, 0, 230)
    text = label + " " + value.to_s + "/" + maximum.to_s
    self.contents.draw_text(x + 1, y - 2, width, 12, text, 2)
    self.contents.font.color = text_color
    self.contents.draw_text(x, y - 3, width, 12, text, 2)
    self.contents.font.size = old_size
    self.contents.font.color = old_color
    self.contents.font.bold = old_bold
  rescue
  end
end

class Sprite_CG_BattlerHUD
  def cg_draw_gauge_row(bitmap, x, y, width, value, maximum, color1, color2,
      show_value)
    kind = (y <= 1 ? :hp : :mp)
    # v1.7.4 的 HP、MP 為相鄰兩列；以色彩參數作第二層保險。
    if color1 != nil && color1.blue > color1.red
      kind = :mp
    elsif color1 != nil && color1.red > color1.blue
      kind = :hp
    end
    ALBERT_CG::GenericGauge.draw(bitmap, kind,
      x, y, width, 9, value, maximum)
    return unless show_value

    text = value.to_i.to_s
    old_size = bitmap.font.size
    old_bold = bitmap.font.bold
    old_color = bitmap.font.color
    bitmap.font.size = 9
    bitmap.font.bold = true
    bitmap.font.color = Color.new(0, 0, 0, 235)
    bitmap.draw_text(x + 1, y - 2, width - 2, 12, text, 2)
    bitmap.font.color = Color.new(255, 255, 255)
    bitmap.draw_text(x, y - 3, width - 2, 12, text, 2)
    bitmap.font.size = old_size
    bitmap.font.bold = old_bold
    bitmap.font.color = old_color
  rescue
  end
end
