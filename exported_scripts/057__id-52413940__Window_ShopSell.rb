# RMVX_SCRIPT_INDEX: 57
# RMVX_SCRIPT_ID: 52413940
# RMVX_SCRIPT_NAME: Window_ShopSell
# RMVX_SOURCE_SHA256: 193c5b96fca22a434999096ed8357f6f6079057223aebe1a821deed0d17b89f3

#==============================================================================
# ** Window_ShopSell
#------------------------------------------------------------------------------
#  This window displays items in possession for selling on the shop screen.
#==============================================================================

class Window_ShopSell < Window_Item
  #--------------------------------------------------------------------------
  # * Object Initialization
  #     x      : window x-coordinate
  #     y      : window y-coordinate
  #     width  : window width
  #     height : window height
  #--------------------------------------------------------------------------
  def initialize(x, y, width, height)
    super(x, y, width, height)
  end
  #--------------------------------------------------------------------------
  # * Whether or not to include in item list
  #     item : item
  #--------------------------------------------------------------------------
  def include?(item)
    return item != nil
  end
  #--------------------------------------------------------------------------
  # * Whether or not to display in enabled state
  #     item : item
  #--------------------------------------------------------------------------
  def enable?(item)
    return (item.price > 0)
  end
end
