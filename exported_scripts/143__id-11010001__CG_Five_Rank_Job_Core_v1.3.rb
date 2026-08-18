# RMVX_SCRIPT_INDEX: 143
# RMVX_SCRIPT_ID: 11010001
# RMVX_SCRIPT_NAME: CG Five Rank Job Core v1.3
# RMVX_SOURCE_SHA256: e6eb58956161875710d06209270dea650c7eb03db4831bd250b2b67c714c96be

#==============================================================================
# 【繁體中文說明】ALBERT CG 魔力寶貝式五階職業核心
#------------------------------------------------------------------------------
# 【版本】v1.3
# 【用途】
#  1. 移除副職業，每名人類只有一個目前職業。
#  2. 每個職業分為五個階級，且每階稱號可分職業獨立設定。
#  3. 職業＋階級共同決定每一招技能的等級上限與熟練倍率。
#  4. 職業＋階級共同決定各裝備類型的裝備等級上限。
#  5. 主角可轉職及晉階；隊友職業固定、不能轉職，但可以晉階。
#  6. 轉職後若技能超過新上限，技能等級會永久降到新上限。
#  7. 轉職或階級調整後，超過裝備上限的裝備會自動卸下。
#
# 【重要規則】
#  - 不存在副職業。
#  - 技能與裝備等級皆為 Lv.1～Lv.10。
#  - 技能上限為 0 時，技能仍占技能欄，但目前職業不能使用。
#  - 階級不會因戰鬥勝利自動提升，必須由事件或晉階介面觸發。
#
# 【主要設定】
#  JOB_RANK_NAMES              各職業五階稱號
#  JOB_SKILL_CAPS              各職業／階級／技能上限
#  JOB_SKILL_PROFICIENCY_RATES 各職業／階級／技能熟練倍率
#  JOB_EQUIP_CAPS              各職業／階級／裝備類型上限
#  ACTOR_JOB_SETUP             隊友固定職業、階級、初始技能等級
#  JOB_CHANGEABLE_ACTOR_IDS    可以轉職的人物 Actor ID
#
# 【裝備設定】
#  VX 的 Weapon／Armor 有 Note，可使用：
#    <cg_equip_type: sword>
#    <cg_equip_level: 5>
#  若未寫 Note，會使用 WEAPON_TYPE_BY_ID／ARMOR_TYPE_BY_KIND 與預設 Lv.1。
#
# 【事件指令】
#  cg_open_job_manager(actor_id)
#  cg_unlock_job(actor_id, class_id)
#  cg_change_job(actor_id, class_id)
#  cg_advance_job(actor_id)
#  cg_set_job_rank(actor_id, rank)
#
# 【腳本位置】
#  取代舊 CG Job Subclass Core，放在 CG Action Order Preview 下方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_FiveRankJobCore"] = true

module ALBERT_CG
  FIVE_RANK_JOB_VERSION = "1.3"
  JOB_MAX_RANK = 5

  JOB_DISPLAY_NAMES = {
    1 => "劍士",
    2 => "守衛",
    3 => "弓手",
    4 => "法師"
  }

  JOB_RANK_NAMES = {
    1 => ["見習劍士", "正式劍士", "資深劍士", "劍術師範", "劍聖"],
    2 => ["守衛學徒", "城鎮守衛", "王室守衛", "守護騎士", "聖盾"],
    3 => ["見習弓手", "獵弓手", "神射手", "鷹眼", "天弓"],
    4 => ["魔法學徒", "元素法師", "高階法師", "魔導師", "大魔導士"]
  }

  JOB_DESCRIPTIONS = {
    1 => "擅長一般系近戰技能，技能熟練速度較快。",
    2 => "重視防禦、護衛與回復，裝備上限較均衡。",
    3 => "擅長遠距物理技能與速度型裝備。",
    4 => "擅長地、水、火、風四系公共魔法。"
  }

  JOB_CHANGEABLE_ACTOR_IDS = [1]
  JOB_INITIAL_UNLOCKS = {
    1 => [1, 2, 3, 4]
  }
  JOB_DEFAULT_UNLOCKS = [1]

  # 隊友初始資料。隊友不能轉職，但能升階。
  ACTOR_JOB_SETUP = {
    2 => {
      :job_id => 2,
      :rank => 2,
      :skills => {33 => 2},
      # [武器, 盾牌, 頭部, 身體, 飾品]。nil 表示沿用資料庫設定。
      :equipment => [1, 3, 10, 15, 4]
    }
  }

  # 每一階都可使用 :default，再用技能 ID 個別覆寫。
  JOB_SKILL_CAPS = {
    1 => {
      1 => {:default => 2, 1 => 3, 2 => 2, 85 => 3, 93 => 1},
      2 => {:default => 3, 1 => 5, 2 => 4, 85 => 5, 93 => 2},
      3 => {:default => 5, 1 => 7, 2 => 6, 85 => 7, 93 => 3},
      4 => {:default => 7, 1 => 9, 2 => 8, 85 => 9, 93 => 4},
      5 => {:default => 8, 1 => 10, 2 => 10, 85 => 10, 93 => 5}
    },
    2 => {
      1 => {:default => 2, 33 => 3},
      2 => {:default => 3, 33 => 5},
      3 => {:default => 5, 33 => 7},
      4 => {:default => 7, 33 => 9},
      5 => {:default => 8, 33 => 10}
    },
    3 => {
      1 => {:default => 3}, 2 => {:default => 5}, 3 => {:default => 7},
      4 => {:default => 9}, 5 => {:default => 10}
    },
    4 => {
      1 => {:default => 3, 59 => 4, 67 => 2},
      2 => {:default => 5, 59 => 6, 67 => 4},
      3 => {:default => 7, 59 => 8, 67 => 6},
      4 => {:default => 9, 59 => 10, 67 => 8},
      5 => {:default => 10, 59 => 10, 67 => 10}
    }
  }

  # 100 = 正常；200 = 每次使用取得雙倍熟練度。
  JOB_SKILL_PROFICIENCY_RATES = {
    1 => {
      1 => {:default => 100, 1 => 200, 2 => 150, 85 => 200},
      2 => {:default => 110, 1 => 220, 2 => 170, 85 => 220},
      3 => {:default => 120, 1 => 240, 2 => 190, 85 => 240},
      4 => {:default => 130, 1 => 270, 2 => 220, 85 => 270},
      5 => {:default => 150, 1 => 300, 2 => 250, 85 => 300}
    },
    2 => {
      1 => {:default => 100, 33 => 150},
      2 => {:default => 110, 33 => 175},
      3 => {:default => 120, 33 => 200},
      4 => {:default => 130, 33 => 225},
      5 => {:default => 150, 33 => 250}
    },
    3 => {
      1 => {:default => 120}, 2 => {:default => 140}, 3 => {:default => 170},
      4 => {:default => 200}, 5 => {:default => 240}
    },
    4 => {
      1 => {:default => 100, 59 => 180, 67 => 150},
      2 => {:default => 110, 59 => 200, 67 => 175},
      3 => {:default => 120, 59 => 225, 67 => 200},
      4 => {:default => 130, 59 => 250, 67 => 225},
      5 => {:default => 150, 59 => 300, 67 => 275}
    }
  }

  # 裝備類型：:sword :bow :gun :staff :shield :head :body :accessory
  JOB_EQUIP_CAPS = {
    1 => {
      1 => {:sword=>3, :shield=>2, :head=>2, :body=>3, :accessory=>2},
      2 => {:sword=>5, :shield=>3, :head=>3, :body=>5, :accessory=>3},
      3 => {:sword=>7, :shield=>4, :head=>5, :body=>7, :accessory=>5},
      4 => {:sword=>9, :shield=>5, :head=>7, :body=>9, :accessory=>7},
      5 => {:sword=>10, :shield=>6, :head=>8, :body=>10, :accessory=>8}
    },
    2 => {
      1 => {:bow=>3, :shield=>2, :head=>2, :body=>2, :accessory=>2},
      2 => {:bow=>5, :shield=>3, :head=>3, :body=>3, :accessory=>3},
      3 => {:bow=>7, :shield=>4, :head=>5, :body=>5, :accessory=>5},
      4 => {:bow=>9, :shield=>5, :head=>7, :body=>7, :accessory=>7},
      5 => {:bow=>10, :shield=>6, :head=>8, :body=>8, :accessory=>8}
    },
    3 => {
      1 => {:gun=>3, :head=>2, :body=>2, :accessory=>2},
      2 => {:gun=>5, :head=>3, :body=>3, :accessory=>3},
      3 => {:gun=>7, :head=>5, :body=>5, :accessory=>5},
      4 => {:gun=>9, :head=>7, :body=>7, :accessory=>7},
      5 => {:gun=>10, :head=>8, :body=>8, :accessory=>8}
    },
    4 => {
      1 => {:staff=>3, :shield=>2, :head=>2, :body=>2, :accessory=>3},
      2 => {:staff=>5, :shield=>3, :head=>4, :body=>3, :accessory=>5},
      3 => {:staff=>7, :shield=>4, :head=>6, :body=>5, :accessory=>7},
      4 => {:staff=>9, :shield=>5, :head=>8, :body=>7, :accessory=>9},
      5 => {:staff=>10, :shield=>6, :head=>10, :body=>8, :accessory=>10}
    }
  }

  WEAPON_TYPE_BY_ID = {1=>:bow, 2=>:sword, 3=>:gun, 4=>:staff, 5=>:sword}
  WEAPON_LEVEL_BY_ID = {1=>1, 2=>1, 3=>1, 4=>1, 5=>5}
  ARMOR_TYPE_BY_KIND = {0=>:shield, 1=>:head, 2=>:body, 3=>:accessory}
  ARMOR_LEVEL_BY_ID = {}

  def self.job_name(class_id)
    id = class_id.to_i
    return JOB_DISPLAY_NAMES[id] if JOB_DISPLAY_NAMES.has_key?(id)
    data = $data_classes[id]
    return data == nil ? ("職業" + id.to_s) : data.name
  end

  def self.job_rank_name(class_id, rank)
    names = JOB_RANK_NAMES[class_id.to_i]
    rank = [[rank.to_i, 1].max, JOB_MAX_RANK].min
    return "第" + rank.to_s + "階" if names == nil || names[rank - 1] == nil
    return names[rank - 1]
  end

  def self.job_skill_cap(class_id, rank, skill_id)
    by_job = JOB_SKILL_CAPS[class_id.to_i]
    return 0 if by_job == nil
    data = by_job[[rank.to_i, 1].max]
    return 0 if data == nil
    value = data[skill_id.to_i]
    value = data[:default] if value == nil
    return [[value.to_i, 0].max, MAX_SKILL_LEVEL].min
  end

  def self.job_skill_rate(class_id, rank, skill_id)
    by_job = JOB_SKILL_PROFICIENCY_RATES[class_id.to_i]
    return 100 if by_job == nil
    data = by_job[[rank.to_i, 1].max]
    return 100 if data == nil
    value = data[skill_id.to_i]
    value = data[:default] if value == nil
    return value == nil ? 100 : [value.to_i, 0].max
  end

  def self.item_equip_type(item)
    return nil if item == nil
    note = item.respond_to?(:note) && item.note != nil ? item.note : ""
    return $1.downcase.to_sym if note =~ /<cg_equip_type\s*:\s*([a-z_]+)\s*>/i
    return WEAPON_TYPE_BY_ID[item.id] if item.is_a?(RPG::Weapon)
    return ARMOR_TYPE_BY_KIND[item.kind] if item.is_a?(RPG::Armor)
    return nil
  end

  def self.item_equip_level(item)
    return 0 if item == nil
    note = item.respond_to?(:note) && item.note != nil ? item.note : ""
    return [[$1.to_i, 1].max, 10].min if note =~ /<cg_equip_level\s*:\s*(\d+)\s*>/i
    value = item.is_a?(RPG::Weapon) ? WEAPON_LEVEL_BY_ID[item.id] : ARMOR_LEVEL_BY_ID[item.id]
    return value == nil ? 1 : [[value.to_i, 1].max, 10].min
  end

  def self.job_equip_cap(class_id, rank, equip_type)
    by_job = JOB_EQUIP_CAPS[class_id.to_i]
    return 0 if by_job == nil
    data = by_job[[rank.to_i, 1].max]
    return 0 if data == nil
    return data[equip_type].to_i
  end
end

class Game_Actor < Game_Battler
  def cg_job_human?
    return false if respond_to?(:cg_skill_pet?) && cg_skill_pet?
    return true
  end

  def cg_job_changeable?
    return cg_job_human? && ALBERT_CG::JOB_CHANGEABLE_ACTOR_IDS.include?(id)
  end

  def cg_prepare_job_data
    return false unless cg_job_human?
    @cg_unlocked_job_ids = [] if @cg_unlocked_job_ids == nil
    @cg_job_ranks = {} if @cg_job_ranks == nil
    initial = ALBERT_CG::JOB_INITIAL_UNLOCKS[id]
    initial = ALBERT_CG::JOB_DEFAULT_UNLOCKS if initial == nil
    for class_id in initial
      @cg_unlocked_job_ids.push(class_id.to_i) unless @cg_unlocked_job_ids.include?(class_id.to_i)
      @cg_job_ranks[class_id.to_i] = 1 if @cg_job_ranks[class_id.to_i] == nil
    end
    @cg_unlocked_job_ids.push(@class_id.to_i) unless @cg_unlocked_job_ids.include?(@class_id.to_i)
    @cg_job_ranks[@class_id.to_i] = 1 if @cg_job_ranks[@class_id.to_i] == nil

    setup = ALBERT_CG::ACTOR_JOB_SETUP[id]
    if @cg_v13_job_setup_done != true && setup != nil
      target_job = setup[:job_id].to_i
      @class_id = target_job if target_job > 0 && $data_classes[target_job] != nil
      @cg_unlocked_job_ids = [target_job]
      @cg_job_ranks[target_job] = [[setup[:rank].to_i, 1].max, ALBERT_CG::JOB_MAX_RANK].min
      if setup[:skills] != nil
        for skill_id in setup[:skills].keys
          level = setup[:skills][skill_id].to_i
          cg_learn_skill_to_slot(skill_id, level, nil) if respond_to?(:cg_learn_skill_to_slot)
        end
      end
      equipment = setup[:equipment]
      if equipment != nil
        @weapon_id = equipment[0].to_i unless equipment[0] == nil
        @armor1_id = equipment[1].to_i unless equipment[1] == nil
        @armor2_id = equipment[2].to_i unless equipment[2] == nil
        @armor3_id = equipment[3].to_i unless equipment[3] == nil
        @armor4_id = equipment[4].to_i unless equipment[4] == nil
      end
      @cg_v13_job_setup_done = true
    end
    @cg_unlocked_job_ids.delete_if { |class_id| class_id <= 0 || $data_classes[class_id] == nil }
    @cg_unlocked_job_ids.sort!
    return true
  end

  def cg_unlocked_job_ids
    cg_prepare_job_data
    return @cg_unlocked_job_ids == nil ? [] : @cg_unlocked_job_ids
  end

  def cg_unlock_job(class_id)
    return false unless cg_job_changeable?
    class_id = class_id.to_i
    return false if class_id <= 0 || $data_classes[class_id] == nil
    cg_prepare_job_data
    @cg_unlocked_job_ids.push(class_id) unless @cg_unlocked_job_ids.include?(class_id)
    @cg_unlocked_job_ids.sort!
    @cg_job_ranks[class_id] = 1 if @cg_job_ranks[class_id] == nil
    return true
  end

  def cg_job_rank(class_id = nil)
    return 0 unless cg_job_human?
    cg_prepare_job_data
    class_id = @class_id if class_id == nil
    rank = @cg_job_ranks[class_id.to_i]
    rank = 1 if rank == nil
    return [[rank.to_i, 1].max, ALBERT_CG::JOB_MAX_RANK].min
  end

  def cg_current_job_rank
    cg_prepare_job_data
    return cg_job_rank(@class_id)
  end

  def cg_job_rank_name
    return ALBERT_CG.job_rank_name(@class_id, cg_current_job_rank)
  end

  def cg_set_job_rank(rank)
    return false unless cg_job_human?
    cg_prepare_job_data
    rank = [[rank.to_i, 1].max, ALBERT_CG::JOB_MAX_RANK].min
    @cg_job_ranks[@class_id] = rank
    cg_enforce_job_limits
    return true
  end

  def cg_advance_job
    return false unless cg_job_human?
    rank = cg_current_job_rank
    return false if rank >= ALBERT_CG::JOB_MAX_RANK
    return cg_set_job_rank(rank + 1)
  end

  # 舊 v1.1 主職 API 相容層。副職已正式取消。
  def cg_change_main_job(class_id)
    return cg_change_job(class_id)
  end

  def cg_change_sub_job(class_id)
    return false
  end

  def cg_subclass_id
    return 0
  end

  def cg_change_job(class_id)
    return false unless cg_job_changeable?
    class_id = class_id.to_i
    return false unless cg_unlocked_job_ids.include?(class_id)
    return true if class_id == @class_id.to_i
    old_maxhp = [maxhp, 1].max
    old_maxmp = [maxmp, 1].max
    old_hp = hp
    old_mp = mp
    self.class_id = class_id
    @cg_job_ranks[class_id] = 1 if @cg_job_ranks[class_id] == nil
    cg_enforce_job_limits
    self.hp = old_hp <= 0 ? 0 : [[old_hp * maxhp / old_maxhp, 1].max, maxhp].min
    self.mp = [[old_mp * maxmp / old_maxmp, 0].max, maxmp].min
    return true
  end

  def cg_human_skill_level_cap(skill_id)
    return ALBERT_CG::MAX_SKILL_LEVEL unless cg_job_human?
    return ALBERT_CG.job_skill_cap(@class_id, cg_current_job_rank, skill_id)
  end

  def cg_human_skill_proficiency_rate(skill_id)
    return 0 unless cg_job_human?
    return ALBERT_CG.job_skill_rate(@class_id, cg_current_job_rank, skill_id)
  end

  def cg_equip_level_cap(equip_type)
    return 10 unless cg_job_human?
    return ALBERT_CG.job_equip_cap(@class_id, cg_current_job_rank, equip_type)
  end

  def cg_enforce_job_limits
    if respond_to?(:cg_skill_slot_ids)
      for skill_id in cg_skill_slot_ids
        cap = cg_human_skill_level_cap(skill_id)
        current = cg_skill_level(skill_id)
        cg_set_skill_level(skill_id, cap) if cap > 0 && current > cap
      end
    end
    for i in 0..4
      item = equips[i]
      change_equip(i, nil) if item != nil && !equippable?(item)
    end
    return true
  end

  alias albert_cg_v13_job_skill_can_use skill_can_use?
  def skill_can_use?(skill)
    if skill != nil && cg_job_human? && cg_human_skill_level_cap(skill.id) <= 0
      return false
    end
    return albert_cg_v13_job_skill_can_use(skill)
  end

  alias albert_cg_v13_job_equippable equippable?
  def equippable?(item)
    return albert_cg_v13_job_equippable(item) unless cg_job_human?
    return false unless albert_cg_v13_job_equippable(item)
    equip_type = ALBERT_CG.item_equip_type(item)
    return true if equip_type == nil
    level = ALBERT_CG.item_equip_level(item)
    return level <= cg_equip_level_cap(equip_type)
  end
end

#==============================================================================
# ■ F4 指令與職業管理 UI
#==============================================================================
class Window_CG_DevelopmentCommand < Window_Command
  attr_reader :actor
  def initialize
    @actor = nil
    super(304, ["能力配點", "技能資料", "職業管理", "取消"], 1, 4)
  end

  def actor=(actor)
    return if @actor == actor
    @actor = actor
    refresh
  end

  def refresh
    create_contents
    for i in 0...@item_max
      enabled = !(i == 2 && (@actor == nil || !@actor.cg_job_human?))
      draw_item(i, enabled)
    end
  end
end

class Window_CG_JobMode < Window_Command
  attr_reader :actor
  def initialize(actor)
    @actor = actor
    super(544, ["轉職", "職業晉階", "返回"], 3, 1)
  end

  def refresh
    create_contents
    draw_item(0, @actor != nil && @actor.cg_job_changeable?)
    draw_item(1, @actor != nil && @actor.cg_job_human? && @actor.cg_current_job_rank < ALBERT_CG::JOB_MAX_RANK)
    draw_item(2, true)
  end
end

class Window_CG_JobList < Window_Selectable
  def initialize(actor)
    super(0, 112, 220, 304)
    @actor = actor
    @data = actor.cg_unlocked_job_ids
    @column_max = 1
    @item_max = [@data.size, 1].max
    refresh
    self.index = 0
  end

  def class_id
    return nil if @data == nil || @data.empty?
    return @data[self.index]
  end

  def refresh
    @data = @actor.cg_unlocked_job_ids
    @item_max = [@data.size, 1].max
    create_contents
    for i in 0...@data.size
      rect = item_rect(i)
      marker = @data[i] == @actor.class_id ? "◆" : "　"
      self.contents.draw_text(rect.x + 4, rect.y, 24, rect.height, marker)
      self.contents.draw_text(rect.x + 28, rect.y, rect.width - 32, rect.height, ALBERT_CG.job_name(@data[i]))
    end
  end
end

class Window_CG_JobDetail < Window_Base
  def initialize(actor)
    super(220, 112, 324, 304)
    @actor = actor
    @class_id = actor.class_id
    refresh
  end

  def class_id=(value)
    value = @actor.class_id if value == nil
    return if @class_id == value
    @class_id = value
    refresh
  end

  def refresh
    self.contents.clear
    class_id = @class_id.to_i
    rank = @actor.cg_job_rank(class_id)
    self.contents.font.size = 16
    draw_line(0, "職業", ALBERT_CG.job_name(class_id))
    draw_line(24, "目前階級", ALBERT_CG.job_rank_name(class_id, rank))
    self.contents.font.color = system_color
    self.contents.draw_text(0, 56, contents.width, 22, "技能上限／熟練倍率")
    self.contents.font.color = normal_color
    y = 80
    shown = 0
    for skill in @actor.cg_skill_slot_skills
      cap = ALBERT_CG.job_skill_cap(class_id, rank, skill.id)
      rate = ALBERT_CG.job_skill_rate(class_id, rank, skill.id)
      self.contents.draw_text(0, y, contents.width, 22, skill.name + "　Lv." + cap.to_s + "　" + rate.to_s + "%")
      y += 22
      shown += 1
      break if shown >= 5
    end
    if shown == 0
      self.contents.draw_text(0, y, contents.width, 22, "目前技能欄為空")
      y += 22
    end
    self.contents.font.color = system_color
    self.contents.draw_text(0, 198, contents.width, 22, "裝備上限")
    self.contents.font.color = normal_color
    caps = ALBERT_CG::JOB_EQUIP_CAPS[class_id]
    caps = caps == nil ? nil : caps[rank]
    text = []
    if caps != nil
      for key in caps.keys
        text.push(key.to_s + " " + caps[key].to_s)
      end
    end
    self.contents.draw_text(0, 222, contents.width, 40, text.empty? ? "無" : text.join("／"))
    self.contents.font.size = Font.default_size
  end

  def draw_line(y, label, value)
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 88, 22, label)
    self.contents.font.color = normal_color
    self.contents.draw_text(88, y, contents.width - 88, 22, value.to_s)
  end
end

class Scene_CG_JobManager < Scene_Base
  def initialize(actor_id)
    @actor_id = actor_id.to_i
    @selecting_job = false
  end

  def main
    start
    perform_transition
    Input.update
    loop do
      Graphics.update
      Input.update
      update
      break if $scene != self
    end
    Graphics.update
    pre_terminate
    Graphics.freeze
    terminate
  end

  def start
    super
    @actor = $game_actors[@actor_id]
    unless @actor != nil && @actor.cg_job_human?
      $scene = Scene_CG_PartyDevelopment.new(@actor_id)
      return
    end
    @actor.cg_prepare_job_data
    create_menu_background
    @title_window = Window_Base.new(0, 0, 544, 56)
    @title_window.contents.draw_text(0, 0, 512, Window_Base::WLH,
      @actor.name + "　職業管理　C：決定　B：返回")
    @mode_window = Window_CG_JobMode.new(@actor)
    @mode_window.y = 56
    @job_window = Window_CG_JobList.new(@actor)
    @job_window.active = false
    @job_window.index = -1
    @detail_window = Window_CG_JobDetail.new(@actor)
  end

  def terminate
    super
    dispose_menu_background
    @title_window.dispose if @title_window != nil
    @mode_window.dispose if @mode_window != nil
    @job_window.dispose if @job_window != nil
    @detail_window.dispose if @detail_window != nil
  end

  def update
    super
    update_menu_background
    @mode_window.update
    @job_window.update
    if @selecting_job
      @detail_window.class_id = @job_window.class_id
      update_job_list
    else
      @detail_window.class_id = @actor.class_id
      update_mode
    end
  end

  def update_mode
    if Input.trigger?(Input::B)
      Sound.play_cancel
      $scene = Scene_CG_PartyDevelopment.new(@actor.id)
      return
    end
    return unless Input.trigger?(Input::C)
    case @mode_window.index
    when 0
      unless @actor.cg_job_changeable?
        Sound.play_buzzer
        return
      end
      Sound.play_decision
      @selecting_job = true
      @mode_window.active = false
      @job_window.active = true
      @job_window.index = 0
    when 1
      if @actor.cg_advance_job
        Sound.play_equip
        @mode_window.refresh
        @detail_window.refresh
      else
        Sound.play_buzzer
      end
    when 2
      Sound.play_cancel
      $scene = Scene_CG_PartyDevelopment.new(@actor.id)
    end
  end

  def update_job_list
    if Input.trigger?(Input::B)
      Sound.play_cancel
      @selecting_job = false
      @job_window.active = false
      @job_window.index = -1
      @mode_window.active = true
      return
    end
    return unless Input.trigger?(Input::C)
    if @actor.cg_change_job(@job_window.class_id)
      Sound.play_equip
      @job_window.refresh
      @mode_window.refresh
      @detail_window.class_id = @actor.class_id
      @detail_window.refresh
    else
      Sound.play_buzzer
    end
  end
end

class Window_CG_DevelopmentDetail < Window_Base
  alias albert_cg_v13_job_detail_refresh refresh
  def refresh
    albert_cg_v13_job_detail_refresh
    return if @actor == nil || !@actor.respond_to?(:cg_job_human?) || !@actor.cg_job_human?
    draw_line(120, "職業", ALBERT_CG.job_name(@actor.class_id))
    draw_line(144, "階級", @actor.cg_job_rank_name)
  end
end

class Scene_CG_PartyDevelopment < Scene_Base
  alias albert_cg_v13_job_development_start start
  def start
    albert_cg_v13_job_development_start
    return if @command_window == nil
    @command_window.dispose
    @command_window = Window_CG_DevelopmentCommand.new
    @command_window.x = 240
    @command_window.y = 264
    @command_window.active = false
    @command_window.index = -1
    @command_window.actor = @actor_window.actor
  end

  alias albert_cg_v13_job_refresh_detail refresh_detail
  def refresh_detail
    albert_cg_v13_job_refresh_detail
    @command_window.actor = @actor_window.actor if @command_window != nil && @command_window.respond_to?(:actor=)
  end

  def update_command
    if Input.trigger?(Input::B)
      Sound.play_cancel
      close_command
      return
    end
    actor = @actor_window.actor
    @command_window.actor = actor
    return unless Input.trigger?(Input::C)
    case @command_window.index
    when 0
      Sound.play_decision
      $scene = Scene_CG_UniversalGrowth.new(actor.id, actor.id)
    when 1
      Sound.play_decision
      $scene = Scene_CG_SkillManager.new(actor.id, :party)
    when 2
      if actor != nil && actor.cg_job_human?
        Sound.play_decision
        $scene = Scene_CG_JobManager.new(actor.id)
      else
        Sound.play_buzzer
      end
    when 3
      Sound.play_cancel
      close_command
    end
  end
end

class Game_Interpreter
  def cg_open_job_manager(actor_id)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil || !actor.cg_job_human?
    $scene = Scene_CG_JobManager.new(actor.id)
    return true
  end

  def cg_unlock_job(actor_id, class_id)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil
    return actor.cg_unlock_job(class_id)
  end

  def cg_change_job(actor_id, class_id)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil
    return actor.cg_change_job(class_id)
  end

  # 舊版事件指令相容。主職改名為職業；副職與職業熟練度已取消。
  def cg_change_main_job(actor_id, class_id)
    return cg_change_job(actor_id, class_id)
  end

  def cg_change_sub_job(actor_id, class_id)
    return false
  end

  def cg_give_job_exp(actor_id, class_id, amount)
    return false
  end

  def cg_advance_job(actor_id)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil
    return actor.cg_advance_job
  end

  def cg_set_job_rank(actor_id, rank)
    actor = $game_actors[actor_id.to_i]
    return false if actor == nil
    return actor.cg_set_job_rank(rank)
  end
end

module ALBERT_CG
  def self.apply_v13_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.3"
  end
end

class Scene_Title < Scene_Base
  alias albert_cg_v13_job_load_database load_database
  def load_database
    albert_cg_v13_job_load_database
    ALBERT_CG.apply_v13_title
  end

  alias albert_cg_v13_job_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v13_job_load_bt_database
    ALBERT_CG.apply_v13_title
  end
end
