# RMVX_SCRIPT_INDEX: 35
# RMVX_SCRIPT_ID: 18621826
# RMVX_SCRIPT_NAME: Sprite_Picture
# RMVX_SOURCE_SHA256: d90816a5b6f79fcfd37f638bea9bb0bd104a8744e2a0facec310f413ffd6a01e

#==============================================================================
# ** Sprite_Picture
#------------------------------------------------------------------------------
#  This sprite is used to display picturea. It observes a instance of the
# Game_Picture class and automatically changes sprite conditions.
#==============================================================================

class Sprite_Picture < Sprite
  #--------------------------------------------------------------------------
  # * Object Initialization
  #     viewport : viewport
  #     picture  : picture (Game_Picture)
  #--------------------------------------------------------------------------
  def initialize(viewport, picture)
    super(viewport)
    @picture = picture
    update
  end
  #--------------------------------------------------------------------------
  # * Dispose
  #--------------------------------------------------------------------------
  def dispose
    if self.bitmap != nil
      self.bitmap.dispose
    end
    super
  end
  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
  def update
    super
    if @picture_name != @picture.name
      @picture_name = @picture.name
      if @picture_name != ""
        self.bitmap = Cache.picture(@picture_name)
      end
    end
    if @picture_name == ""
      self.visible = false
    else
      self.visible = true
      if @picture.origin == 0
        self.ox = 0
        self.oy = 0
      else
        self.ox = self.bitmap.width / 2
        self.oy = self.bitmap.height / 2
      end
      self.x = @picture.x
      self.y = @picture.y
      self.z = 100 + @picture.number
      self.zoom_x = @picture.zoom_x / 100.0
      self.zoom_y = @picture.zoom_y / 100.0
      self.opacity = @picture.opacity
      self.blend_type = @picture.blend_type
      self.angle = @picture.angle
      self.tone = @picture.tone
    end
  end
end
