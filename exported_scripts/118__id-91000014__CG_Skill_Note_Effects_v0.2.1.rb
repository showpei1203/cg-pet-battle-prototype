# RMVX_SCRIPT_INDEX: 118
# RMVX_SCRIPT_ID: 91000014
# RMVX_SCRIPT_NAME: CG Skill Note Effects v0.2.1
# RMVX_SOURCE_SHA256: d1555421701301dade46e27f6788f1318a23c515f27dd07f11036ce742f67a7f

#==============================================================================
# 【繁體中文說明】ALBERT CG 技能 Note 狀態機率
#------------------------------------------------------------------------------
# 【用途】讓技能透過 Note 指定額外狀態與成功機率。
# 【使用】格式：<cg_state_chance: 狀態ID,機率百分比>。
# 【位置】請放在 CG Config 下方，並依專案腳本索引指定順序排列。
#==============================================================================

#==============================================================================
# ** ALBERT CG Skill Note Effects
#------------------------------------------------------------------------------
#  Version : 0.2.1
#------------------------------------------------------------------------------
#  Skill note:
#    <cg_state_chance: state_id,percent>
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_SkillNoteEffects"] = true

class Game_Battler
  alias albert_cg_v02_skill_effect skill_effect
  def skill_effect(user, skill)
    albert_cg_v02_skill_effect(user, skill)
    return if @skipped or @missed or @evaded
    return if dead?
    note = skill.note == nil ? "" : skill.note
    note.scan(/<cg_state_chance\s*:\s*(\d+)\s*,\s*(\d+)\s*>/i) do |data|
      state_id = data[0].to_i
      chance = [[data[1].to_i, 0].max, 100].min
      next if state?(state_id)
      next if state_resist?(state_id)
      if rand(100) < chance
        add_state(state_id)
        @added_states.push(state_id) unless @added_states.include?(state_id)
      end
    end
  end
end
