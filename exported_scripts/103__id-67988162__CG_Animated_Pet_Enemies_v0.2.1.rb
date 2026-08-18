# RMVX_SCRIPT_INDEX: 103
# RMVX_SCRIPT_ID: 67988162
# RMVX_SCRIPT_NAME: CG Animated Pet Enemies v0.2.1
# RMVX_SOURCE_SHA256: a21301710fb044b170faf4edf6c0b0982bdc6d72f509eaaea2a1ac1908f36203

#==============================================================================
# 【繁體中文說明】ALBERT CG 敵方 Kaduki 動畫支援
#------------------------------------------------------------------------------
# 【用途】讓敵人使用以 $ 開頭的 Kaduki 角色圖時，只顯示單一角色並播放 Tankentai 動畫。
# 【使用】一般 Battler 圖不受影響。
# 【位置】請放在 CG Config 下方，並依專案腳本索引指定順序排列。
#==============================================================================

#==============================================================================
# ** ALBERT CG Animated Pet Enemies
#------------------------------------------------------------------------------
#  Version : 0.2.1
#------------------------------------------------------------------------------
#  Adapted from Kylock's "Enemy Animated Battlers" add-on for Tankentai SBS.
#
#  Purpose:
#    Treat enemy battlers whose battler filename begins with "$" as Kaduki
#    animated battlers instead of displaying the entire 96x128 sprite sheet.
#
#  Required files for battler name "$Actor12":
#    Graphics/Battlers/$Actor12.png
#    Graphics/Characters/$Actor12_1.png
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_AnimatedPetEnemies"] = true

class Game_Enemy < Game_Battler
  def cg_kaduki_enemy?
    name = @battler_name == nil ? "" : @battler_name.to_s
    return name[0, 1] == "$"
  end

  alias albert_cg_v021_enemy_position_plus position_plus
  def position_plus
    return [0, 0] if cg_kaduki_enemy?
    return albert_cg_v021_enemy_position_plus
  end

  alias albert_cg_v021_enemy_anime_on anime_on
  def anime_on
    return true if cg_kaduki_enemy?
    return albert_cg_v021_enemy_anime_on
  end

  alias albert_cg_v021_enemy_action_mirror action_mirror
  def action_mirror
    return true if cg_kaduki_enemy?
    return albert_cg_v021_enemy_action_mirror
  end
end
