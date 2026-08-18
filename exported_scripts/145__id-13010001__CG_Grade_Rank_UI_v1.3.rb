# RMVX_SCRIPT_INDEX: 145
# RMVX_SCRIPT_ID: 13010001
# RMVX_SCRIPT_NAME: CG Grade Rank UI v1.3
# RMVX_SOURCE_SHA256: aa7eb39c18567ebb4bc2cf37fda89f8bf924d4a167e619a51c8b57edb3993eb6

#==============================================================================
# 【繁體中文說明】ALBERT CG 掉檔評價文字 UI
#------------------------------------------------------------------------------
# 【版本】v1.3
# 【用途】
#  將玩家可見的掉檔 0／1／2／3／4 統一顯示為 S／A／B／C／D。
#  內部仍保留數字，能力計算、配種繼承與存檔資料完全不變。
#
# 【對照】
#    0 = S　最佳
#    1 = A
#    2 = B
#    3 = C
#    4 = D　最差
#
# 【修改畫面】
#  - F5 寵物詳細資料
#  - F3 配種親本詳細資料
#
# 【腳本位置】
#  放在 CG Pet Breeding 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_GradeRankUI"] = true

module ALBERT_CG
  GRADE_RANK_UI_VERSION = "1.3"
  GRADE_RANK_LABELS = ["S", "A", "B", "C", "D"]

  def self.grade_rank_label(value)
    value = value.to_i
    value = 0 if value < 0
    value = GRADE_RANK_LABELS.size - 1 if value >= GRADE_RANK_LABELS.size
    return GRADE_RANK_LABELS[value]
  end

  def self.pet_grade_rank_text(pet)
    return "" if pet == nil || !pet.respond_to?(:cg_grade_loss_at)
    count = defined?(GRADE_STAT_COUNT) ? GRADE_STAT_COUNT : 5
    labels = []
    count.times { |i| labels.push(grade_rank_label(pet.cg_grade_loss_at(i))) }
    return labels.join("／")
  end
end

class Window_CG_PetDetail < Window_Base
  def refresh
    self.contents.clear
    if @pet == nil
      self.contents.draw_text(0, 0, contents.width, WLH, "選擇一隻寵物")
      return
    end
    @pet.cg_prepare_pet_data
    @pet.cg_prepare_growth_data if @pet.respond_to?(:cg_prepare_growth_data)
    self.contents.font.size = 16
    y = 0
    cg_v08_detail_line(y, "個體／物種", @pet.id.to_s + "／" + @pet.cg_species_id.to_s); y += 22
    cg_v08_detail_line(y, "等級／可用BP", @pet.level.to_s + "／" + @pet.cg_unspent_bp.to_s); y += 22
    cg_v08_detail_line(y, "HP／MP", @pet.hp.to_s + "/" + @pet.maxhp.to_s + "　" + @pet.mp.to_s + "/" + @pet.maxmp.to_s); y += 22
    cg_v08_detail_line(y, "攻／防／精／敏", @pet.atk.to_s + "／" + @pet.def.to_s + "／" + @pet.spi.to_s + "／" + @pet.agi.to_s); y += 22
    points = []
    5.times { |i| points.push(@pet.cg_bonus_point(i).to_s) }
    cg_v08_detail_line(y, "配點 體力起", points.join("／")); y += 22
    cg_v08_detail_line(y, "掉檔 體力起", ALBERT_CG.pet_grade_rank_text(@pet)); y += 22
    names = []
    for skill in @pet.skills
      level = @pet.respond_to?(:cg_skill_level) ? @pet.cg_skill_level(skill.id) : 1
      names.push(skill.name + " Lv." + level.to_s)
    end
    cg_v08_detail_line(y, "技能", names.join("、"))
    self.contents.font.size = Font.default_size
  end
end

class Window_CG_BreedDetail < Window_Base
  def refresh
    self.contents.clear
    return if @pet == nil
    self.contents.font.size = 16
    y = 0
    draw_line("個體 ID", @pet.id.to_s, y); y += 24
    draw_line("物種", @pet.actor.name, y); y += 24
    draw_line("等級／世代", @pet.level.to_s + "／G" + @pet.cg_generation.to_s, y); y += 24
    draw_line("配種次數", @pet.cg_breed_count.to_s + "／" + ALBERT_CG::PET_BREED_MAX_COUNT.to_s, y); y += 24
    group = @pet.cg_breed_group
    draw_line("配種群組", group == nil ? "不可配種" : group, y); y += 24
    draw_line("掉檔", ALBERT_CG.pet_grade_rank_text(@pet), y); y += 24
    location = $game_party.respond_to?(:cg_pet_location) ? $game_party.cg_pet_location(@pet.id) : nil
    location_text = location == :storage ? "倉庫" : "攜帶"
    draw_line("位置", location_text, y); y += 24
    if @parent_a != nil
      self.contents.font.color = system_color
      self.contents.draw_text(0, y, contents.width, 24, "第一親本：" + @parent_a.name + " #" + @parent_a.id.to_s)
    end
    self.contents.font.size = Font.default_size
  end
end
