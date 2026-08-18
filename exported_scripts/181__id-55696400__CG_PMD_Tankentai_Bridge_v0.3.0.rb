# RMVX_SCRIPT_INDEX: 181
# RMVX_SCRIPT_ID: 55696400
# RMVX_SCRIPT_NAME: CG PMD Tankentai Bridge v0.3.0
# RMVX_SOURCE_SHA256: 0f8b2ba7e2bb45ae23b3a508dddaeb8083ac7e00e5a93b0708fe7b6cca53b959

#==============================================================================
# ■ CG_PMD_Tankentai_Bridge.rb  v0.3.0
#------------------------------------------------------------------------------
# 【用途】
#  把 Tankentai N01::ANIME 的 PMD 指令接到 Sprite_Battler。
#  v0.3.0 新增 pmd_skill_native：讓每一招 Pokémon Move 在 Action Sequence
#  執行時讀取「目前使用者＋目前技能」解析出的 PMD Native 動作。
#
# 【規則】
#  - 人類角色不走本橋接，仍使用 Tankentai SBS 圖。
#  - PMD 技能可以要求 Shock／Kick／Punch／Bite 等專用動作。
#  - 指定 Native 動作不存在時，Move Effect Resolver 會在進入此橋接前完成 fallback。
#  - 所有 PMD 動作方向仍由 CG_PMD_Core 鎖定 45°。
#
# 【事件／腳本呼叫】
#  一般不需事件呼叫；Action Setup 會設定 battler 的 @cg_pmd_pending_native_action。
#==============================================================================
$imported = {} if $imported == nil
$imported["CG_PMD_Tankentai_Bridge"] = "0.3.0"

class Sprite_Battler < Sprite_Base
  alias cg_pmd_tankentai_action action
  def action
    if @active_action != nil
      command = @active_action[0]
      case command
      when "pmd"
        return cg_pmd_command_play
      when "pmd_wait"
        return cg_pmd_command_wait
      when "pmd_view"
        return cg_pmd_command_view
      when "pmd_mirror"
        return cg_pmd_command_mirror
      when "pmd_idle"
        return cg_pmd_command_idle
      when "pmd_skill_native"
        return cg_pmd_command_skill_native
      end
    end
    cg_pmd_tankentai_action
  end

  def cg_pmd_command_play
    request = @active_action[1]
    view = @active_action[2] || :auto
    loop_value = @active_action[3]
    wait_condition = @active_action[4]
    mirror_mode = @active_action[5]
    cg_pmd_play(request, view, loop_value, mirror_mode)
    @anime_end = true
    cg_pmd_wait(wait_condition) if wait_condition != nil && wait_condition != false
  end

  def cg_pmd_command_wait
    cg_pmd_wait(@active_action[1] || :end)
  end

  def cg_pmd_command_view
    cg_pmd_set_view(@active_action[1] || :battle)
    @anime_end = true
  end

  def cg_pmd_command_mirror
    cg_pmd_set_mirror(@active_action[1])
    @anime_end = true
  end

  def cg_pmd_command_idle
    cg_pmd_play("Idle", @active_action[1] || :auto, true, nil)
    @anime_end = true
  end

  # ["pmd_skill_native", :hit/:end]
  def cg_pmd_command_skill_native
    request = @battler.instance_variable_get(:@cg_pmd_pending_native_action)
    request = "Attack" if request == nil || request.to_s == ""
    wait_condition = @active_action[1] || :hit
    cg_pmd_play(request, :auto, false, nil)
    @anime_end = true
    cg_pmd_wait(wait_condition)
  end
end
