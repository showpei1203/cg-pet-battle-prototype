# RMVX_SCRIPT_INDEX: 151
# RMVX_SCRIPT_ID: 98181010
# RMVX_SCRIPT_NAME: CG TRGSSX Visual Bridge v0.1
# RMVX_SOURCE_SHA256: 64fb765c6f0fcef98ff8121f151a466796c4bae31c23d2576f96d456528c7efe

#==============================================================================
# 【繁體中文說明】ALBERT CG TRGSSX 視覺轉接層
#------------------------------------------------------------------------------
# 【版本】v0.1
# 【引擎】RPG Maker VX / RGSS2 / Ruby 1.8
# 【外部檔案】TRGSSX.dll（置於 Game.exe 同一層）
#------------------------------------------------------------------------------
# 【用途】
#  1. 只包裝 CG 正式 UI 目前真正需要的 TRGSSX 功能。
#  2. 使用高品質 stretch_blt_r 縮放行走圖。
#  3. 使用正多邊形繪製 Spin Command 節點與高亮標記。
#  4. DLL 缺少、版本不符或 API 呼叫失敗時，自動退回 RGSS2 原生繪圖。
#
# 【重要】
#  - 本腳本不覆寫 Bitmap#draw_text，不改全遊戲字體。
#  - 不直接導入網站完整 BitmapExtension，避免與既有視窗／文字腳本衝突。
#  - TRGSSX.dll 必須與 Game.exe 放在同一個資料夾。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_TRGSSX_VisualBridge"] = true

module ALBERT_CG
  module TRGSSXVisual
    @available = false
    @version = 0
    @failed = false

    begin
      @dll_get_version = Win32API.new("TRGSSX", "DllGetVersion", "v", "l")
      @set_interpolation = Win32API.new("TRGSSX", "SetInterpolationMode", "l", "v")
      @set_smoothing = Win32API.new("TRGSSX", "SetSmoothingMode", "l", "v")
      @stretch_blt_r = Win32API.new("TRGSSX", "StretchBltR",
        "pllllplllll", "l")
      @draw_regular_polygon = Win32API.new("TRGSSX", "DrawRegularPolygon",
        "pllllll", "l")
      @fill_regular_polygon = Win32API.new("TRGSSX", "FillRegularPolygon",
        "plllllll", "l")
      @version = @dll_get_version.call.to_i
      @available = @version > 0
      if @available
        # GDI+ 常用列舉：3 為 Bilinear，2 為 HighQuality。
        @set_interpolation.call(3)
        @set_smoothing.call(2)
      end
    rescue
      @available = false
      @version = 0
    end

    def self.available?
      return @available && !@failed
    end

    def self.version
      return @version.to_i
    end

    def self.bitmap_pointer(bitmap)
      return nil if bitmap == nil || bitmap.disposed?
      return [bitmap.object_id, bitmap.width, bitmap.height].pack("l3")
    end

    def self.argb(color)
      return 0 if color == nil
      value = ((color.alpha.to_i & 0xFF) << 24) |
        ((color.red.to_i & 0xFF) << 16) |
        ((color.green.to_i & 0xFF) << 8) |
        (color.blue.to_i & 0xFF)
      value -= 0x100000000 if value >= 0x80000000
      return value
    end

    def self.stretch_blt(destination, dest_rect, source, source_rect,
      opacity = 255)
      return false if destination == nil || source == nil
      if available?
        begin
          result = @stretch_blt_r.call(bitmap_pointer(destination),
            dest_rect.x.to_i, dest_rect.y.to_i,
            dest_rect.width.to_i, dest_rect.height.to_i,
            bitmap_pointer(source), source_rect.x.to_i, source_rect.y.to_i,
            source_rect.width.to_i, source_rect.height.to_i,
            opacity.to_i)
          return true if result.to_i != 0
        rescue
          @failed = true
        end
      end
      begin
        destination.stretch_blt(dest_rect, source, source_rect, opacity.to_i)
        return true
      rescue
        return false
      end
    end

    def self.draw_regular_polygon(bitmap, x, y, radius, points, color,
      width = 1)
      return false unless available?
      begin
        result = @draw_regular_polygon.call(bitmap_pointer(bitmap),
          x.to_i, y.to_i, radius.to_i, points.to_i, argb(color), width.to_i)
        return result.to_i != 0
      rescue
        @failed = true
        return false
      end
    end

    def self.fill_regular_polygon(bitmap, x, y, radius, points,
      center_color, edge_color)
      return false unless available?
      begin
        result = @fill_regular_polygon.call(bitmap_pointer(bitmap),
          x.to_i, y.to_i, radius.to_i, points.to_i,
          argb(center_color), argb(edge_color))
        return result.to_i != 0
      rescue
        @failed = true
        return false
      end
    end
  end
end
