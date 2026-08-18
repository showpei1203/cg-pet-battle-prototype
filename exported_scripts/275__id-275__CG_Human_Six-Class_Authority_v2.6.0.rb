# RMVX_SCRIPT_INDEX: 275
# RMVX_SCRIPT_ID: 275
# RMVX_SCRIPT_NAME: CG Human Six-Class Authority v2.6.0
# RMVX_SOURCE_SHA256: 6e49f9103dff30df2e1dc040adfa230d44dde1cde6a39df795aa31dc257a4f99

#==============================================================================
# ■ CG Human Six-Class Authority v2.6.0
#------------------------------------------------------------------------------
# Formal Human Phase 3 foundation.
# Six canonical jobs:
#   1 劍士   - front physical pressure
#   2 守衛   - front tank / guard support
#   3 弓手   - back ranged physical; Bow only
#   4 法師   - back elemental special damage
#   5 神官   - back heal / cleanse / buff
#   6 格鬥家 - front fast physical / combo / interrupt
#
# This layer intentionally does NOT implement the dedicated trait tree yet.
# It establishes stable class identity, stat profile, equipment authority,
# five-rank progression data, and future Gamebit/AI semantic tags.
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_HumanSixClassAuthority"] = "2.6.0"

module ALBERT_CG
  HUMAN_SIX_CLASS_VERSION = "2.6.0"

  HUMAN_CLASS_ROLE = {
    1 => :swordsman,
    2 => :guardian,
    3 => :archer,
    4 => :mage,
    5 => :cleric,
    6 => :brawler
  }

  HUMAN_CLASS_GRID_ROLE = {
    1 => :front,
    2 => :front,
    3 => :back,
    4 => :back,
    5 => :back,
    6 => :front
  }

  HUMAN_CLASS_TAGS = {
    1 => [:physical, :melee, :single_target, :pressure],
    2 => [:physical, :tank, :guard, :support],
    3 => [:physical, :ranged, :speed, :focus_fire],
    4 => [:special, :ranged, :elemental, :area],
    5 => [:special, :support, :heal, :cleanse, :buff],
    6 => [:physical, :melee, :speed, :combo, :interrupt]
  }

  def self.human_class_role(class_id)
    return HUMAN_CLASS_ROLE[class_id.to_i]
  end

  def self.human_class_grid_role(class_id)
    return HUMAN_CLASS_GRID_ROLE[class_id.to_i]
  end

  def self.human_class_tags(class_id)
    row = HUMAN_CLASS_TAGS[class_id.to_i]
    return row == nil ? [] : row.dup
  end

  # Canonical visible identities.
  JOB_DISPLAY_NAMES.replace({
    1 => "劍士",
    2 => "守衛",
    3 => "弓手",
    4 => "法師",
    5 => "神官",
    6 => "格鬥家"
  })

  JOB_RANK_NAMES.replace({
    1 => ["見習劍士", "劍士", "劍術師", "劍豪", "劍聖"],
    2 => ["守衛見習", "守衛", "重裝守衛", "守護騎士", "聖盾"],
    3 => ["見習弓手", "弓手", "遊俠", "神射手", "鷹眼"],
    4 => ["魔法學徒", "法師", "高階法師", "魔導師", "大魔導士"],
    5 => ["見習神官", "神官", "司祭", "大司祭", "聖者"],
    6 => ["格鬥學徒", "格鬥家", "武術家", "拳聖", "鬥神"]
  })

  JOB_DESCRIPTIONS.replace({
    1 => "前排均衡物理職。以單體壓制、劍技與穩定輸出為核心。",
    2 => "前排防禦職。高耐久，擅長護衛、減傷與防禦型支援。",
    3 => "後排遠程物理職。使用弓，依靠高速度與安全射程集中擊殺。",
    4 => "後排特殊輸出職。擅長元素魔法、範圍傷害與場地控制。",
    5 => "後排支援職。負責回復、淨化、復活與隊伍增益。",
    6 => "前排高速物理職。以連擊、打斷與高行動頻率掌控節奏。"
  })

  JOB_INITIAL_UNLOCKS[1] = [1, 2, 3, 4, 5, 6]
  JOB_DEFAULT_UNLOCKS.replace([1])

  # Existing prototype companions remain useful as fixed examples.
  ACTOR_JOB_SETUP.replace({
    2 => {:job_id=>2, :rank=>2, :skills=>{33=>2,50=>2}, :equipment=>[2,1,8,15,13]},
    3 => {:job_id=>3, :rank=>2, :skills=>{84=>2,85=>2}, :equipment=>[1,2,7,14,13]},
    4 => {:job_id=>4, :rank=>2, :skills=>{59=>2,67=>2}, :equipment=>[4,2,10,14,4]}
  })

  # Foundation caps. Dedicated skill-tree ownership is added in the next phase;
  # these caps already give each job a clear proficiency bias without making
  # unrelated prototype skills unusable while content is still being migrated.
  JOB_SKILL_CAPS.replace({
    1 => {
      1=>{:default=>2,1=>3,85=>3,90=>3},
      2=>{:default=>3,1=>5,85=>5,90=>5},
      3=>{:default=>5,1=>7,85=>7,90=>7},
      4=>{:default=>7,1=>9,85=>9,90=>9},
      5=>{:default=>8,1=>10,85=>10,90=>10}
    },
    2 => {
      1=>{:default=>2,33=>3,49=>3,50=>3},
      2=>{:default=>3,33=>5,49=>5,50=>5},
      3=>{:default=>5,33=>7,49=>7,50=>7},
      4=>{:default=>7,33=>9,49=>9,50=>9},
      5=>{:default=>8,33=>10,49=>10,50=>10}
    },
    3 => {
      1=>{:default=>2,84=>3,85=>3,95=>3},
      2=>{:default=>3,84=>5,85=>5,95=>5},
      3=>{:default=>5,84=>7,85=>7,95=>7},
      4=>{:default=>7,84=>9,85=>9,95=>9},
      5=>{:default=>8,84=>10,85=>10,95=>10}
    },
    4 => {
      1=>{:default=>2,59=>3,63=>3,67=>3,71=>3,73=>3,75=>3},
      2=>{:default=>3,59=>5,63=>5,67=>5,71=>5,73=>5,75=>5},
      3=>{:default=>5,59=>7,63=>7,67=>7,71=>7,73=>7,75=>7},
      4=>{:default=>7,59=>9,63=>9,67=>9,71=>9,73=>9,75=>9},
      5=>{:default=>8,59=>10,63=>10,67=>10,71=>10,73=>10,75=>10}
    },
    5 => {
      1=>{:default=>2,33=>4,39=>4,49=>3,50=>3,51=>3,52=>3},
      2=>{:default=>3,33=>6,39=>6,49=>5,50=>5,51=>5,52=>5},
      3=>{:default=>5,33=>8,39=>8,36=>7,41=>6,49=>7,50=>7,51=>7,52=>7},
      4=>{:default=>7,33=>10,39=>10,36=>9,41=>8,49=>9,50=>9,51=>9,52=>9},
      5=>{:default=>8,33=>10,39=>10,36=>10,41=>10,49=>10,50=>10,51=>10,52=>10}
    },
    6 => {
      1=>{:default=>2,27=>3,86=>3,94=>3},
      2=>{:default=>3,27=>5,86=>5,94=>5},
      3=>{:default=>5,27=>7,86=>7,94=>7},
      4=>{:default=>7,27=>9,86=>9,94=>9},
      5=>{:default=>8,27=>10,86=>10,94=>10}
    }
  })

  JOB_SKILL_PROFICIENCY_RATES.replace({
    1=>{1=>{:default=>100,1=>180,85=>180,90=>180},2=>{:default=>110,1=>200,85=>200,90=>200},3=>{:default=>120,1=>220,85=>220,90=>220},4=>{:default=>130,1=>250,85=>250,90=>250},5=>{:default=>150,1=>300,85=>300,90=>300}},
    2=>{1=>{:default=>100,33=>150,49=>170,50=>170},2=>{:default=>110,33=>170,49=>190,50=>190},3=>{:default=>120,33=>190,49=>220,50=>220},4=>{:default=>130,33=>220,49=>250,50=>250},5=>{:default=>150,33=>250,49=>300,50=>300}},
    3=>{1=>{:default=>105,84=>180,85=>170,95=>170},2=>{:default=>115,84=>200,85=>190,95=>190},3=>{:default=>125,84=>220,85=>220,95=>220},4=>{:default=>140,84=>250,85=>250,95=>250},5=>{:default=>160,84=>300,85=>300,95=>300}},
    4=>{1=>{:default=>100,59=>170,63=>170,67=>170,71=>170,73=>170,75=>170},2=>{:default=>110,59=>190,63=>190,67=>190,71=>190,73=>190,75=>190},3=>{:default=>120,59=>220,63=>220,67=>220,71=>220,73=>220,75=>220},4=>{:default=>130,59=>250,63=>250,67=>250,71=>250,73=>250,75=>250},5=>{:default=>150,59=>300,63=>300,67=>300,71=>300,73=>300,75=>300}},
    5=>{1=>{:default=>100,33=>190,39=>190,49=>170,50=>170,51=>170,52=>170},2=>{:default=>110,33=>210,39=>210,49=>190,50=>190,51=>190,52=>190},3=>{:default=>120,33=>240,39=>240,36=>220,41=>200,49=>220,50=>220,51=>220,52=>220},4=>{:default=>130,33=>270,39=>270,36=>250,41=>230,49=>250,50=>250,51=>250,52=>250},5=>{:default=>150,33=>300,39=>300,36=>300,41=>280,49=>300,50=>300,51=>300,52=>300}},
    6=>{1=>{:default=>105,27=>180,86=>190,94=>180},2=>{:default=>115,27=>200,86=>210,94=>200},3=>{:default=>125,27=>220,86=>240,94=>220},4=>{:default=>140,27=>250,86=>270,94=>250},5=>{:default=>160,27=>300,86=>300,94=>300}}
  })

  JOB_EQUIP_CAPS.replace({
    1=>{
      1=>{:sword=>3,:shield=>1,:head=>2,:body=>3,:accessory=>2},2=>{:sword=>5,:shield=>2,:head=>3,:body=>5,:accessory=>3},3=>{:sword=>7,:shield=>3,:head=>5,:body=>7,:accessory=>5},4=>{:sword=>9,:shield=>4,:head=>7,:body=>9,:accessory=>7},5=>{:sword=>10,:shield=>5,:head=>8,:body=>10,:accessory=>8}},
    2=>{
      1=>{:sword=>3,:shield=>4,:head=>4,:body=>4,:accessory=>2},2=>{:sword=>5,:shield=>6,:head=>6,:body=>6,:accessory=>3},3=>{:sword=>7,:shield=>8,:head=>8,:body=>8,:accessory=>5},4=>{:sword=>9,:shield=>10,:head=>10,:body=>10,:accessory=>7},5=>{:sword=>10,:shield=>10,:head=>10,:body=>10,:accessory=>8}},
    3=>{
      1=>{:bow=>3,:head=>2,:body=>2,:accessory=>3},2=>{:bow=>5,:head=>3,:body=>3,:accessory=>5},3=>{:bow=>7,:head=>5,:body=>5,:accessory=>7},4=>{:bow=>9,:head=>7,:body=>7,:accessory=>9},5=>{:bow=>10,:head=>8,:body=>8,:accessory=>10}},
    4=>{
      1=>{:staff=>3,:head=>2,:body=>2,:accessory=>4},2=>{:staff=>5,:head=>3,:body=>3,:accessory=>6},3=>{:staff=>7,:head=>5,:body=>5,:accessory=>8},4=>{:staff=>9,:head=>7,:body=>7,:accessory=>10},5=>{:staff=>10,:head=>8,:body=>8,:accessory=>10}},
    5=>{
      1=>{:staff=>3,:shield=>2,:head=>3,:body=>3,:accessory=>4},2=>{:staff=>5,:shield=>3,:head=>5,:body=>5,:accessory=>6},3=>{:staff=>7,:shield=>4,:head=>7,:body=>7,:accessory=>8},4=>{:staff=>9,:shield=>5,:head=>9,:body=>9,:accessory=>10},5=>{:staff=>10,:shield=>6,:head=>10,:body=>10,:accessory=>10}},
    6=>{
      1=>{:fist=>3,:head=>2,:body=>3,:accessory=>3},2=>{:fist=>5,:head=>3,:body=>5,:accessory=>5},3=>{:fist=>7,:head=>5,:body=>7,:accessory=>7},4=>{:fist=>9,:head=>7,:body=>9,:accessory=>9},5=>{:fist=>10,:head=>8,:body=>10,:accessory=>10}}
  })

  WEAPON_TYPE_BY_ID.replace({1=>:bow,2=>:sword,3=>:fist,4=>:staff,5=>:sword})
  WEAPON_LEVEL_BY_ID.replace({1=>1,2=>1,3=>1,4=>1,5=>5})

  module SIX_STAT_DAMAGE
    HUMAN_CLASS_PROFILES.replace({
      1 => [96, 110, 82, 45, 72, 88],
      2 => [120, 82, 120, 40, 105, 50],
      3 => [82, 100, 68, 55, 75, 115],
      4 => [76, 42, 60, 120, 102, 82],
      5 => [92, 50, 82, 98, 120, 68],
      6 => [102, 115, 88, 40, 72, 100]
    })
  end
end
