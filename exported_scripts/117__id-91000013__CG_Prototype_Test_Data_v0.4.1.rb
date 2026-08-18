# RMVX_SCRIPT_INDEX: 117
# RMVX_SCRIPT_ID: 91000013
# RMVX_SCRIPT_NAME: CG Prototype Test Data v0.4.1
# RMVX_SOURCE_SHA256: 32440db390bb1431751270a1957d15ce16a4f1d8ac786ccc33a8f21a27ba03d4

#==============================================================================
# 【繁體中文說明】ALBERT CG Prototype 測試資料
#------------------------------------------------------------------------------
# 【用途】在遊戲載入時建立妙蛙種子、小火龍、傑尼龜及其技能、敵人與測試隊伍。
# 【使用】本頁只供原型測試；正式製作時應將資料移入 VX 資料庫。
# 【位置】請放在 CG Config 下方，並依專案腳本索引指定順序排列。
#==============================================================================

#==============================================================================
# ** ALBERT CG Prototype Test Data
#------------------------------------------------------------------------------
#  Version : 0.4.1
#------------------------------------------------------------------------------
#  Creates three in-memory prototype species and enemies based on the current
#  Forest Symphony database design. Graphics use Tankentai's bundled Kaduki
#  samples so the prototype has no external image dependency.
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_FS_TestData"] = true
$imported["ALBERT_CG_PrototypeTestData"] = true

module ALBERT_CG
  module TEST_DATA
    SPECIES = {
      100 => ["妙蛙種子", 100, "$Actor12", "Actor12", [45, 46, 49, 49, 65, 45]],
      103 => ["小火龍",   101, "$Actor22", "Actor22", [39, 39, 52, 43, 55, 65]],
      106 => ["傑尼龜",   102, "$Actor26", "Actor26", [44, 42, 48, 65, 57, 43]]
    }

    CLASS_SKILLS = {
      100 => [[1, 600], [1, 601]],
      101 => [[1, 607], [1, 608]],
      102 => [[1, 617], [1, 654]]
    }

    def self.ensure_index(array, index)
      array.push(nil) while array.size <= index
    end

    def self.fill_rank_table(size, rank)
      table = Table.new([size, 1].max)
      for i in 0...[size, 1].max
        table[i] = rank
      end
      return table
    end

    def self.make_parameters(base)
      table = Table.new(6, 100)
      for level in 0...100
        lv = [level, 1].max
        table[0, level] = 140 + base[0] * 2 + (lv - 1) * (8 + base[0] / 10)
        table[1, level] = 25 + base[1] / 2 + (lv - 1) * 3
        table[2, level] = 12 + base[2] / 5 + (lv - 1) * 2
        table[3, level] = 12 + base[3] / 5 + (lv - 1) * 2
        table[4, level] = 12 + base[4] / 5 + (lv - 1) * 2
        table[5, level] = 12 + base[5] / 5 + (lv - 1) * 2
      end
      return table
    end

    def self.make_learning(level, skill_id)
      learning = RPG::Class::Learning.new
      learning.level = level
      learning.skill_id = skill_id
      return learning
    end

    def self.make_class(id, name, learnings)
      klass = RPG::Class.new
      klass.id = id
      klass.name = name
      klass.position = 1
      klass.weapon_set = []
      klass.armor_set = []
      klass.element_ranks = fill_rank_table($data_system.elements.size, 3)
      klass.state_ranks = fill_rank_table($data_states.size, 3)
      klass.learnings = []
      for data in learnings
        klass.learnings.push(make_learning(data[0], data[1]))
      end
      klass.skill_name_valid = true
      klass.skill_name = "技能"
      return klass
    end

    def self.make_actor(id, data)
      actor = RPG::Actor.new
      actor.id = id
      actor.name = data[0]
      actor.class_id = data[1]
      actor.character_name = data[2]
      actor.character_index = 0
      actor.face_name = data[3]
      actor.face_index = 0
      actor.initial_level = 1
      actor.exp_basis = 20
      actor.exp_inflation = 18
      actor.parameters = make_parameters(data[4])
      actor.weapon_id = 0
      actor.armor1_id = 0
      actor.armor2_id = 0
      actor.armor3_id = 0
      actor.armor4_id = 0
      actor.two_swords_style = false
      actor.fix_equipment = true
      actor.auto_battle = false
      actor.super_guard = false
      actor.pharmacology = false
      actor.critical_bonus = false
      return actor
    end

    def self.make_skill(id, name, description, base_damage, atk_f, spi_f,
                        mp_cost, physical, element_id, note = "", scope = 1,
                        hit = 100, variance = 15)
      skill = RPG::Skill.new
      skill.id = id
      skill.name = name
      skill.icon_index = 0
      skill.description = description
      skill.scope = scope
      skill.occasion = 1
      skill.speed = 0
      skill.animation_id = 1
      skill.common_event_id = 0
      skill.base_damage = base_damage
      skill.variance = variance
      skill.atk_f = atk_f
      skill.spi_f = spi_f
      skill.hit = hit
      skill.physical_attack = physical
      skill.damage_to_mp = false
      skill.absorb_damage = false
      skill.ignore_defense = false
      skill.mp_cost = mp_cost
      skill.element_set = element_id == 0 ? [] : [element_id]
      skill.plus_state_set = []
      skill.minus_state_set = []
      skill.message1 = "使用了" + name + "！"
      skill.message2 = ""
      skill.note = note
      return skill
    end

    def self.make_state(id, name, icon, hold, slip, atk_rate, def_rate,
                        spi_rate, agi_rate)
      state = RPG::State.new
      state.id = id
      state.name = name
      state.icon_index = icon
      state.restriction = 0
      state.priority = 5
      state.atk_rate = atk_rate
      state.def_rate = def_rate
      state.spi_rate = spi_rate
      state.agi_rate = agi_rate
      state.nonresistance = true
      state.offset_by_opposite = false
      state.slip_damage = slip
      state.reduce_hit_ratio = false
      state.battle_only = true
      state.release_by_damage = false
      state.hold_turn = hold
      state.auto_release_prob = 100
      state.message1 = "陷入" + name + "。"
      state.message2 = "陷入" + name + "。"
      state.message3 = name + "持續中。"
      state.message4 = name + "解除。"
      state.element_set = []
      state.state_set = []
      state.note = ""
      return state
    end

    def self.make_enemy_action(kind, skill_id, rating)
      action = RPG::Enemy::Action.new
      action.kind = kind
      action.basic = 0
      action.skill_id = skill_id
      action.rating = rating
      action.condition_type = 0
      action.condition_param1 = 0
      action.condition_param2 = 0
      return action
    end

    def self.make_enemy(id, name, battler_name, stats, skills, species_id)
      enemy = RPG::Enemy.new
      enemy.id = id
      enemy.name = name
      enemy.battler_name = battler_name
      enemy.battler_hue = 0
      enemy.maxhp = 180 + stats[0] * 2
      enemy.maxmp = 30 + stats[1]
      enemy.atk = 12 + stats[2] / 5
      enemy.def = 12 + stats[3] / 5
      enemy.spi = 12 + stats[4] / 5
      enemy.agi = 12 + stats[5] / 5
      enemy.hit = 95
      enemy.eva = 5
      enemy.has_critical = true
      enemy.exp = 25
      enemy.gold = 8
      enemy.drop_item1 = RPG::Enemy::DropItem.new
      enemy.drop_item2 = RPG::Enemy::DropItem.new
      enemy.element_ranks = fill_rank_table($data_system.elements.size, 3)
      enemy.state_ranks = fill_rank_table($data_states.size, 3)
      enemy.actions = [make_enemy_action(0, 0, 5)]
      for skill_id in skills
        enemy.actions.push(make_enemy_action(1, skill_id, 6))
      end
      enemy.note = "<cg_species: " + species_id.to_s + ">\n<cg_capture_rank: 1>"
      return enemy
    end

    def self.make_troop_member(enemy_id, x, y)
      member = RPG::Troop::Member.new
      member.enemy_id = enemy_id
      member.x = x
      member.y = y
      member.hidden = false
      member.immortal = false
      return member
    end

    def self.make_troop(id, name, members)
      troop = RPG::Troop.new
      troop.id = id
      troop.name = name
      troop.members = members
      if $data_troops[1] != nil
        troop.pages = $data_troops[1].pages
      else
        troop.pages = []
      end
      return troop
    end

    def self.set_element(id, name)
      $data_system.elements.push("") while $data_system.elements.size <= id
      $data_system.elements[id] = name
    end

    def self.apply
      return if $data_actors == nil
      set_element(4, "一般")
      set_element(7, "毒")
      set_element(8, "地面")
      set_element(13, "火")
      set_element(14, "水")
      set_element(15, "草")

      states = {
        31 => make_state(31, "中毒", 2, 4, true, 100, 100, 100, 100),
        32 => make_state(32, "濕潤", 3, 3, false, 100, 100, 90, 90),
        33 => make_state(33, "遲緩", 4, 3, false, 100, 100, 100, 75),
        34 => make_state(34, "灼燒", 5, 3, false, 85, 100, 100, 100),
        35 => make_state(35, "寄生", 6, 4, false, 100, 90, 100, 100),
        36 => make_state(36, "守住", 7, 1, false, 100, 150, 100, 100)
      }
      for id in states.keys
        ensure_index($data_states, id)
        $data_states[id] = states[id]
      end

      skills = {
        600 => make_skill(600, "藤鞭", "草系遠距物理攻擊。", 20, 110, 0, 5, true, 15,
                          "<cg_range: ranged>"),
        601 => make_skill(601, "毒粉", "有機率使目標中毒。", 0, 0, 0, 6, false, 7,
                          "<cg_state_chance: 31,60>"),
        602 => make_skill(602, "寄生種子", "使用藤鞭與毒粉熟練後習得。", 0, 0, 0, 8, false, 15,
                          "<cg_use_path: 600=3,601=2>\n<cg_state_chance: 35,100>"),
        607 => make_skill(607, "抓", "一般近戰物理攻擊。", 18, 105, 0, 4, true, 4,
                          "<cg_range: melee>"),
        608 => make_skill(608, "火花", "火系魔法攻擊，偶爾灼燒。", 18, 0, 105, 5, false, 13,
                          "<cg_state_chance: 34,18>"),
        612 => make_skill(612, "火焰牙", "抓與火花熟練後習得。", 28, 120, 0, 8, true, 13,
                          "<cg_range: melee>\n<cg_use_path: 607=2,608=4>\n<cg_state_chance: 34,25>"),
        617 => make_skill(617, "水槍", "水系魔法攻擊。", 18, 0, 105, 5, false, 14,
                          "<cg_state_chance: 32,20>"),
        653 => make_skill(653, "泥巴射擊", "地面魔法攻擊，偶爾遲緩。", 22, 0, 110, 7, false, 8,
                          "<cg_state_chance: 33,35>", 1, 95),
        618 => make_skill(618, "守住", "水槍與泥巴射擊熟練後習得。", 0, 0, 0, 6, false, 0,
                          "<cg_use_path: 617=2,653=3>\n<cg_state_chance: 36,100>", 11)
      }
      for id in skills.keys
        ensure_index($data_skills, id)
        $data_skills[id] = skills[id]
      end

      classes = {
        100 => make_class(100, "妙蛙種子系", CLASS_SKILLS[100]),
        101 => make_class(101, "小火龍系", CLASS_SKILLS[101]),
        102 => make_class(102, "傑尼龜系", CLASS_SKILLS[102])
      }
      for id in classes.keys
        ensure_index($data_classes, id)
        $data_classes[id] = classes[id]
      end

      for id in SPECIES.keys
        ensure_index($data_actors, id)
        $data_actors[id] = make_actor(id, SPECIES[id])
      end

      enemies = {
        600 => make_enemy(600, "妙蛙種子", "$Actor12", SPECIES[100][4], [600, 601], 100),
        603 => make_enemy(603, "小火龍", "$Actor22", SPECIES[103][4], [607, 608], 103),
        606 => make_enemy(606, "傑尼龜", "$Actor26", SPECIES[106][4], [617, 654], 106)
      }
      for id in enemies.keys
        ensure_index($data_enemies, id)
        $data_enemies[id] = enemies[id]
      end

      ensure_index($data_troops, 600)
      ensure_index($data_troops, 603)
      ensure_index($data_troops, 606)
      ensure_index($data_troops, 609)
      $data_troops[600] = make_troop(600, "妙蛙種子", [make_troop_member(600, 150, 220)])
      $data_troops[603] = make_troop(603, "小火龍", [make_troop_member(603, 150, 220)])
      $data_troops[606] = make_troop(606, "傑尼龜", [make_troop_member(606, 150, 220)])
      # Formation test:
      #   Front Left   : Bulbasaur
      #   Front Center : Charmander
      #   Back Center  : Squirtle
      #   Back Right   : Bulbasaur
      $data_troops[609] = make_troop(609, "三列站位測試", [
        make_troop_member(600, ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::GRID_COLUMN_Y[0]),
        make_troop_member(603, ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::GRID_COLUMN_Y[1]),
        make_troop_member(606, ALBERT_CG::ENEMY_BACK_X,  ALBERT_CG::GRID_COLUMN_Y[1]),
        make_troop_member(600, ALBERT_CG::ENEMY_BACK_X,  ALBERT_CG::GRID_COLUMN_Y[2])
      ])

      $data_system.party_members = [1]
      $data_system.game_title = "CG Pet Battle Prototype v0.5.10"
      $data_system.test_troop_id = 609
    end
  end
end

class Scene_Title < Scene_Base
  alias albert_cg_v02_load_database load_database
  def load_database
    albert_cg_v02_load_database
    ALBERT_CG::TEST_DATA.apply
  end

  alias albert_cg_v02_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v02_load_bt_database
    ALBERT_CG::TEST_DATA.apply
  end
end
