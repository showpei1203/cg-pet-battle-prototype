# RMVX_SCRIPT_INDEX: 183
# RMVX_SCRIPT_ID: 98941284
# RMVX_SCRIPT_NAME: CG Pokemon Species 0001-0026 Registry v2.0.3a
# RMVX_SOURCE_SHA256: fd4055202fca625a5ee3820fb957ea125433819231915e640128cb7fdbe7ce0c

#==============================================================================
# ■ CG Pokemon Species 0001-0026 Registry v2.0.3a
#------------------------------------------------------------------------------
# 【用途】
#  將全國圖鑑 #0001～#0026 正式接入 CG Pet Battle Prototype。
#  本頁是這 26 隻寶可夢的「唯一身分／型態資料入口」，並同步連接：
#    1. 物種模板 Actor（Actor ID 100～125）
#    2. 野生 Enemy（Enemy ID 600～625）
#    3. PMD Sprite（Graphics/PMDSprites/0001～0026）
#    4. Pokemon Combat 屬性表
#    5. 捕捉後 Clone 寵物的物種身分
#    6. 進化型態與進化等級
#
# 【ID 規則】
#  全國圖鑑編號 dex 1～26：
#    Actor/Form ID = dex + 99
#    Enemy ID      = dex + 599
#    PMD key       = 四位數全國圖鑑編號，例如 1 => "0001"
#  因此 #025 皮卡丘：Actor 124 / Enemy 624 / PMD "0025"。
#
# 【重要機制】
#  - 捕捉後的 Clone Actor ID 仍從 1000 起跳，不會和物種模板衝突。
#  - PMD 綁定必須優先讀「目前進化型態」；進化後會自動換到下一個 PMD key。
#  - Actor/Class 在 VX 沒有 Note，因此屬性與型態資料集中在本頁與
#    CG Pokemon Combat Data，不從 Actor Note 解析。
#  - Enemy 仍保留 <cg_species: ActorID> 與 <pmd species: ActorID> Note，
#    讓捕捉與 PMD 敵方顯示能走同一個 Form ID。
#
# 【能力值轉換】
#  REGISTRY 保存原作六項種族值：HP/Atk/Def/SpA/SpD/Spe。
#  VX 只有 HP/MP/ATK/DEF/SPI/AGI，因此目前映射：
#    HP  <- HP
#    ATK <- Atk
#    DEF <- Def
#    SPI <- (SpA + SpD) / 2
#    AGI <- Spe
#    MP  <- (SpA + SpD) * 3 / 8
#  原始 SpA/SpD 不會丟失，後續若拆出真正特攻／特防仍可直接使用。
#
# 【進化規則】
#  本專案採等級進化。原作用雷之石進化的皮卡丘，依本專案既定規則
#  暫改為 Lv.30 進化雷丘。之後若新增進化石系統，只需改 EVOLUTION_LEVEL。
#
# 【目前技能狀態】
#  本版目標是完成「物種／捕捉／進化／PMD／戰鬥資料」骨架。
#  妙蛙種子、小火龍、傑尼龜三系保留既有原型技能，其他 17 個型態
#  先以普通攻擊作為最低可戰鬥保證；正式技能池會在下一階段逐批加入。
#
# 【測試】
#  F6：正常人物＋寵物戰鬥。這次不覆寫 PMD key，用來驗證正式身分鏈。
#  Shift + F6：執行 0001～0026 PMD 全動作自動巡檢。
#  F10：既有進化管理，可直接補等級並測試進化後 PMD 是否換型態。
#  啟動遊戲會產生 Species26_Integration.log，可回傳供反查。
#
# 【事件／腳本呼叫】
#  ALBERT_CG::SPECIES26.entry_by_dex(25)
#  ALBERT_CG::SPECIES26.actor_id_for_dex(25)        # => 124
#  ALBERT_CG::SPECIES26.enemy_id_for_dex(25)        # => 624
#  ALBERT_CG::SPECIES26.pmd_key_for_dex(25)         # => "0025"
#  actor.cg_national_dex                            # Clone／進化型皆可
#  enemy.cg_national_dex
#
# 【腳本位置】
#  放在 CG_PMD_Action_Setup 之下、PMD AutoTest Harness 之上、Main 之前。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_Species26Registry"] = "2.0.3"

module ALBERT_CG
  module SPECIES26
    VERSION = "2.0.3a"
    LOG_FILE = "Species26_Integration.log"
    ACTOR_OFFSET = 99
    ENEMY_OFFSET = 599

    # dex => [名稱, [type1, type2], [HP, Atk, Def, SpA, SpD, Spe], 系譜基底 dex]
    REGISTRY = {
       1 => ["妙蛙種子", [:grass, :poison], [45,49,49,65,65,45], 1],
       2 => ["妙蛙草",   [:grass, :poison], [60,62,63,80,80,60], 1],
       3 => ["妙蛙花",   [:grass, :poison], [80,82,83,100,100,80], 1],
       4 => ["小火龍",   [:fire], [39,52,43,60,50,65], 4],
       5 => ["火恐龍",   [:fire], [58,64,58,80,65,80], 4],
       6 => ["噴火龍",   [:fire, :flying], [78,84,78,109,85,100], 4],
       7 => ["傑尼龜",   [:water], [44,48,65,50,64,43], 7],
       8 => ["卡咪龜",   [:water], [59,63,80,65,80,58], 7],
       9 => ["水箭龜",   [:water], [79,83,100,85,105,78], 7],
      10 => ["綠毛蟲",   [:bug], [45,30,35,20,20,45], 10],
      11 => ["鐵甲蛹",   [:bug], [50,20,55,25,25,30], 10],
      12 => ["巴大蝶",   [:bug, :flying], [60,45,50,90,80,70], 10],
      13 => ["獨角蟲",   [:bug, :poison], [40,35,30,20,20,50], 13],
      14 => ["鐵殼蛹",   [:bug, :poison], [45,25,50,25,25,35], 13],
      15 => ["大針蜂",   [:bug, :poison], [65,90,40,45,80,75], 13],
      16 => ["波波",     [:normal, :flying], [40,45,40,35,35,56], 16],
      17 => ["比比鳥",   [:normal, :flying], [63,60,55,50,50,71], 16],
      18 => ["大比鳥",   [:normal, :flying], [83,80,75,70,70,101], 16],
      19 => ["小拉達",   [:normal], [30,56,35,25,35,72], 19],
      20 => ["拉達",     [:normal], [55,81,60,50,70,97], 19],
      21 => ["烈雀",     [:normal, :flying], [40,60,30,31,31,70], 21],
      22 => ["大嘴雀",   [:normal, :flying], [65,90,65,61,61,100], 21],
      23 => ["阿柏蛇",   [:poison], [35,60,44,40,54,55], 23],
      24 => ["阿柏怪",   [:poison], [60,95,69,65,79,80], 23],
      25 => ["皮卡丘",   [:electric], [35,55,40,50,50,90], 25],
      26 => ["雷丘",     [:electric], [60,90,55,90,80,110], 25]
    }

    # 目前 dex => [下一階 dex, 所需等級]
    EVOLUTION_LEVEL = {
       1 => [2, 16],  2 => [3, 32],
       4 => [5, 16],  5 => [6, 36],
       7 => [8, 16],  8 => [9, 36],
      10 => [11, 7], 11 => [12, 10],
      13 => [14, 7], 14 => [15, 10],
      16 => [17, 18], 17 => [18, 36],
      19 => [20, 20],
      21 => [22, 20],
      23 => [24, 22],
      25 => [26, 30]
    }

    LINEAGES = {
       1 => [1,2,3], 4 => [4,5,6], 7 => [7,8,9],
      10 => [10,11,12], 13 => [13,14,15], 16 => [16,17,18],
      19 => [19,20], 21 => [21,22], 23 => [23,24], 25 => [25,26]
    }

    # 系譜基底 dex => Class ID。前三條沿用舊原型 Class ID，降低相容風險。
    LINE_CLASS = {
       1=>100, 4=>101, 7=>102, 10=>103, 13=>104,
      16=>105, 19=>106, 21=>107, 23=>108, 25=>109
    }

    CLASS_SKILLS = {
      100 => [[1,600],[1,601]],
      101 => [[1,607],[1,608]],
      102 => [[1,617],[1,654]],
      103 => [], 104 => [], 105 => [], 106 => [], 107 => [], 108 => [], 109 => []
    }

    def self.actor_id_for_dex(dex)
      id = dex.to_i
      return 0 unless REGISTRY.has_key?(id)
      return id + ACTOR_OFFSET
    end

    def self.enemy_id_for_dex(dex)
      id = dex.to_i
      return 0 unless REGISTRY.has_key?(id)
      return id + ENEMY_OFFSET
    end

    def self.dex_for_actor_id(actor_id)
      dex = actor_id.to_i - ACTOR_OFFSET
      return REGISTRY.has_key?(dex) ? dex : 0
    end

    def self.dex_for_enemy_id(enemy_id)
      dex = enemy_id.to_i - ENEMY_OFFSET
      return REGISTRY.has_key?(dex) ? dex : 0
    end

    def self.pmd_key_for_dex(dex)
      return nil unless REGISTRY.has_key?(dex.to_i)
      return sprintf("%04d", dex.to_i)
    end

    def self.entry_by_dex(dex)
      return REGISTRY[dex.to_i]
    end

    def self.entry_by_actor_id(actor_id)
      return entry_by_dex(dex_for_actor_id(actor_id))
    end

    def self.name_for_dex(dex)
      data = entry_by_dex(dex)
      return data == nil ? "未知" : data[0].to_s
    end

    def self.types_for_dex(dex)
      data = entry_by_dex(dex)
      return [] if data == nil
      result = []
      data[1].each { |key| result.push(key) }
      return result
    end

    def self.base_stats_for_dex(dex)
      data = entry_by_dex(dex)
      return nil if data == nil
      result = []
      data[2].each { |value| result.push(value.to_i) }
      return result
    end

    def self.line_base_dex(dex)
      data = entry_by_dex(dex)
      return 0 if data == nil
      return data[3].to_i
    end

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

    def self.make_learning(level, skill_id)
      learning = RPG::Class::Learning.new
      learning.level = level.to_i
      learning.skill_id = skill_id.to_i
      return learning
    end

    def self.make_class(class_id, base_dex)
      klass = RPG::Class.new
      klass.id = class_id.to_i
      klass.name = name_for_dex(base_dex) + "系"
      klass.position = 1
      klass.weapon_set = []
      klass.armor_set = []
      klass.element_ranks = fill_rank_table($data_system.elements.size, 3)
      klass.state_ranks = fill_rank_table($data_states.size, 3)
      klass.learnings = []
      learnings = CLASS_SKILLS[class_id.to_i] || []
      for pair in learnings
        klass.learnings.push(make_learning(pair[0], pair[1]))
      end
      klass.skill_name_valid = true
      klass.skill_name = "技能"
      return klass
    end

    # 將原作六項種族值轉成 VX 六參數用基底。
    # 回傳 [HP, MP基底, ATK, DEF, SPI, AGI]
    def self.vx_base_stats(dex)
      stats = base_stats_for_dex(dex)
      return [40,30,40,40,40,40] if stats == nil
      hp, atk, defense, spa, spd, speed = stats
      special = (spa.to_i + spd.to_i) / 2
      mp_base = (spa.to_i + spd.to_i) * 3 / 8
      mp_base = 20 if mp_base < 20
      return [hp.to_i, mp_base.to_i, atk.to_i, defense.to_i, special.to_i, speed.to_i]
    end

    def self.make_parameters(dex)
      base = vx_base_stats(dex)
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

    def self.make_actor(dex)
      data = REGISTRY[dex]
      actor = RPG::Actor.new
      actor.id = actor_id_for_dex(dex)
      actor.name = data[0]
      actor.class_id = LINE_CLASS[data[3].to_i]
      # PMD 目前只負責戰鬥圖。地圖／Face 將在後續 UI 素材階段補齊。
      actor.character_name = ""
      actor.character_index = 0
      actor.face_name = ""
      actor.face_index = 0
      actor.initial_level = 1
      actor.exp_basis = 20
      actor.exp_inflation = 18
      actor.parameters = make_parameters(dex)
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
                        mp_cost, physical, element_id, note = "")
      skill = RPG::Skill.new
      skill.id = id.to_i
      skill.name = name.to_s
      skill.icon_index = 0
      skill.description = description.to_s
      skill.scope = 1
      skill.occasion = 1
      skill.speed = 0
      skill.animation_id = 1
      skill.common_event_id = 0
      skill.base_damage = base_damage.to_i
      skill.variance = 15
      skill.atk_f = atk_f.to_i
      skill.spi_f = spi_f.to_i
      skill.hit = 100
      skill.physical_attack = physical ? true : false
      skill.damage_to_mp = false
      skill.absorb_damage = false
      skill.ignore_defense = false
      skill.mp_cost = mp_cost.to_i
      skill.element_set = element_id.to_i <= 0 ? [] : [element_id.to_i]
      skill.plus_state_set = []
      skill.minus_state_set = []
      skill.message1 = "使用了" + name.to_s + "！"
      skill.message2 = ""
      skill.note = note.to_s
      return skill
    end

    def self.install_support_skills
      # 654 僅作第一階段正式資料的通用正常系近戰技能；後續技能池會再細分。
      ensure_index($data_skills, 654)
      $data_skills[654] = make_skill(654, "撞擊", "一般系近戰物理攻擊。",
        18, 105, 0, 4, true, 4, "<cg_range: melee>")
      if defined?(ALBERT_CG::POKEMON_COMBAT_DATA)
        ALBERT_CG::POKEMON_COMBAT_DATA::SKILL_COMBAT_TABLE[654] =
          {:type=>:normal, :power=>40, :class=>:physical}
      end
    end

    def self.make_enemy_action(kind, skill_id, rating)
      action = RPG::Enemy::Action.new
      action.kind = kind
      action.basic = 0
      action.skill_id = skill_id.to_i
      action.rating = rating.to_i
      action.condition_type = 0
      action.condition_param1 = 0
      action.condition_param2 = 0
      return action
    end

    def self.make_enemy(dex)
      enemy_id = enemy_id_for_dex(dex)
      actor_id = actor_id_for_dex(dex)
      base = vx_base_stats(dex)
      enemy = RPG::Enemy.new
      enemy.id = enemy_id
      enemy.name = name_for_dex(dex)
      enemy.battler_name = ""
      enemy.battler_hue = 0
      enemy.maxhp = 180 + base[0] * 2
      enemy.maxmp = 30 + base[1]
      enemy.atk = 12 + base[2] / 5
      enemy.def = 12 + base[3] / 5
      enemy.spi = 12 + base[4] / 5
      enemy.agi = 12 + base[5] / 5
      enemy.hit = 95
      enemy.eva = 5
      enemy.has_critical = true
      enemy.exp = 20 + dex.to_i * 2
      enemy.gold = 5 + dex.to_i
      enemy.drop_item1 = RPG::Enemy::DropItem.new
      enemy.drop_item2 = RPG::Enemy::DropItem.new
      enemy.element_ranks = fill_rank_table($data_system.elements.size, 3)
      enemy.state_ranks = fill_rank_table($data_states.size, 3)
      enemy.actions = [make_enemy_action(0, 0, 5)]
      # 三條 starter 系保留現有技能，其他先以普通攻擊保底。
      line_class = LINE_CLASS[line_base_dex(dex)]
      learnings = CLASS_SKILLS[line_class] || []
      for pair in learnings
        skill_id = pair[1].to_i
        enemy.actions.push(make_enemy_action(1, skill_id, 6)) if skill_id > 0
      end
      enemy.note = "<cg_species: " + actor_id.to_s + ">\n" +
                   "<cg_capture_rank: 1>\n" +
                   "<pmd species: " + actor_id.to_s + ">\n" +
                   "<pokemon_level: 5>"
      return enemy
    end

    def self.make_troop_member(enemy_id, x, y)
      member = RPG::Troop::Member.new
      member.enemy_id = enemy_id.to_i
      member.x = x.to_i
      member.y = y.to_i
      member.hidden = false
      member.immortal = false
      return member
    end

    def self.make_troop(id, name, members)
      troop = RPG::Troop.new
      troop.id = id.to_i
      troop.name = name.to_s
      troop.members = members
      troop.pages = ($data_troops[1] == nil ? [] : $data_troops[1].pages)
      return troop
    end

    def self.install_classes
      LINE_CLASS.each do |base_dex, class_id|
        ensure_index($data_classes, class_id)
        $data_classes[class_id] = make_class(class_id, base_dex)
      end
    end

    def self.install_actors
      for dex in 1..26
        actor_id = actor_id_for_dex(dex)
        ensure_index($data_actors, actor_id)
        $data_actors[actor_id] = make_actor(dex)
      end
    end

    def self.install_enemies
      for dex in 1..26
        enemy_id = enemy_id_for_dex(dex)
        ensure_index($data_enemies, enemy_id)
        $data_enemies[enemy_id] = make_enemy(dex)
      end
    end

    def self.install_demo_troops
      # 保留既有 609 測試入口，但內容正式改為 #001/#004/#007。
      ensure_index($data_troops, 609)
      $data_troops[609] = make_troop(609, "PMD 正式身分整合測試", [
        make_troop_member(enemy_id_for_dex(1), ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::GRID_COLUMN_Y[0]),
        make_troop_member(enemy_id_for_dex(4), ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::GRID_COLUMN_Y[1]),
        make_troop_member(enemy_id_for_dex(7), ALBERT_CG::ENEMY_BACK_X,  ALBERT_CG::GRID_COLUMN_Y[1]),
        make_troop_member(enemy_id_for_dex(1), ALBERT_CG::ENEMY_BACK_X,  ALBERT_CG::GRID_COLUMN_Y[2])
      ])

      # 650～675：每隻一個單體野生測試 Troop，方便事件或後續快捷鍵直接叫出。
      for dex in 1..26
        troop_id = 649 + dex
        ensure_index($data_troops, troop_id)
        $data_troops[troop_id] = make_troop(troop_id,
          sprintf("#%04d %s", dex, name_for_dex(dex)),
          [make_troop_member(enemy_id_for_dex(dex), 180, 220)])
      end
    end

    def self.install_pmd_tables
      return unless defined?(CG_PMD)
      # Actor/Form -> PMD key
      for dex in 1..26
        actor_id = actor_id_for_dex(dex)
        enemy_id = enemy_id_for_dex(dex)
        key = pmd_key_for_dex(dex)
        CG_PMD::SPECIES_SPRITES[actor_id] = key
        CG_PMD::ENEMY_SPECIES[enemy_id] = actor_id
      end

      # 修正原 Adapter 與本專案 Clone／進化 API 的名稱差異。
      wanted = [:cg_current_form_actor_id, :cg_species_id, :cg_model_actor_id]
      wanted.reverse_each do |method_name|
        CG_PMD::SPECIES_READER_METHODS.delete(method_name)
        CG_PMD::SPECIES_READER_METHODS.unshift(method_name)
      end
    end

    def self.install_combat_tables
      return unless defined?(ALBERT_CG::POKEMON_COMBAT_DATA)
      data = ALBERT_CG::POKEMON_COMBAT_DATA
      for dex in 1..26
        actor_id = actor_id_for_dex(dex)
        enemy_id = enemy_id_for_dex(dex)
        types = types_for_dex(dex)
        data::FORM_TYPE_TABLE[actor_id] = types
        data::ENEMY_FORM_TABLE[enemy_id] = actor_id
        data::ENEMY_LEVEL_TABLE[enemy_id] = 5
      end
    end

    def self.install_evolution_tables
      return unless defined?(ALBERT_CG::EVOLUTION_RULES)
      ALBERT_CG::EVOLUTION_RULES.clear
      EVOLUTION_LEVEL.each do |dex, rule|
        from_id = actor_id_for_dex(dex)
        to_id = actor_id_for_dex(rule[0])
        ALBERT_CG::EVOLUTION_RULES[from_id] = {:to=>to_id, :level=>rule[1].to_i}
      end
      if defined?(ALBERT_CG::EVOLUTION_LINEAGES)
        ALBERT_CG::EVOLUTION_LINEAGES.clear
        LINEAGES.each do |base_dex, dex_list|
          forms = []
          dex_list.each { |dex| forms.push(actor_id_for_dex(dex)) }
          ALBERT_CG::EVOLUTION_LINEAGES[actor_id_for_dex(base_dex)] = forms
        end
      end
      # 舊原型 Evolution Test Forms 不再是資料來源，避免未來誤讀水躍魚資料。
      ALBERT_CG::EVOLUTION_TEST_FORMS.clear if defined?(ALBERT_CG::EVOLUTION_TEST_FORMS)
    end

    def self.apply
      return if $data_actors == nil || $data_enemies == nil || $data_classes == nil
      install_pmd_tables
      install_combat_tables
      install_evolution_tables
      install_support_skills
      install_classes
      install_actors
      install_enemies
      install_demo_troops
      $data_system.game_title = "CG Pet Battle Prototype v2.0.3a PMD26"
      $data_system.test_troop_id = 609
      write_preflight_log
    end

    def self.write_preflight_log
      begin
        File.open(LOG_FILE, "wb") do |file|
          file.write("CG SPECIES26 INTEGRATION LOG v" + VERSION + "\r\n")
          file.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
          file.write("RANGE=0001-0026\r\n")
          file.write("------------------------------------------------------------\r\n")
          actors_ok = 0
          enemies_ok = 0
          pmd_ok = 0
          combat_ok = 0
          for dex in 1..26
            actor_id = actor_id_for_dex(dex)
            enemy_id = enemy_id_for_dex(dex)
            key = pmd_key_for_dex(dex)
            actors_ok += 1 if $data_actors[actor_id] != nil && $data_actors[actor_id].name == name_for_dex(dex)
            enemies_ok += 1 if $data_enemies[enemy_id] != nil && $data_enemies[enemy_id].name == name_for_dex(dex)
            if defined?(CG_PMD)
              pmd_ok += 1 if CG_PMD::SPECIES_SPRITES[actor_id].to_s == key && CG_PMD.sprite_data(key) != nil
            end
            if defined?(ALBERT_CG::POKEMON_COMBAT_DATA)
              value = ALBERT_CG::POKEMON_COMBAT_DATA::FORM_TYPE_TABLE[actor_id]
              combat_ok += 1 if value != nil && !value.empty?
            end
          end
          file.write("PREFLIGHT actors=" + actors_ok.to_s + "/26 enemies=" + enemies_ok.to_s +
            "/26 pmd=" + pmd_ok.to_s + "/26 combat=" + combat_ok.to_s + "/26\r\n")
          file.write("PMD_READERS=" + (defined?(CG_PMD) ? CG_PMD::SPECIES_READER_METHODS.inspect : "N/A") + "\r\n")
          bypass = defined?(CG_PMD::TANKENTAI_MAKE_BATTLER_BYPASS) ?
            CG_PMD::TANKENTAI_MAKE_BATTLER_BYPASS : false
          file.write("PMD_TANKENTAI_MAKE_BATTLER_BYPASS=" + bypass.to_s + "\r\n")
          file.write("EVOLUTION_RULES=" + (defined?(ALBERT_CG::EVOLUTION_RULES) ? ALBERT_CG::EVOLUTION_RULES.size.to_s : "0") + "\r\n")
          file.write("RESULT=" + ((actors_ok == 26 && enemies_ok == 26 && pmd_ok == 26 && combat_ok == 26) ? "PASS" : "CHECK") + "\r\n")
        end
      rescue
      end
    end

    def self.append_runtime_log(text)
      begin
        File.open(LOG_FILE, "ab") do |file|
          file.write("[" + Time.now.strftime("%H:%M:%S") + "] " + text.to_s + "\r\n")
        end
      rescue
      end
    end

    def self.log_demo_identity
      return if $game_party == nil
      append_runtime_log("NORMAL_DEMO_BATTLE_BEGIN")
      for member in $game_party.members
        next unless member.respond_to?(:cg_pmd_sprite_key)
        form_id = member.respond_to?(:cg_current_form_actor_id) ? member.cg_current_form_actor_id.to_i : 0
        species_id = member.respond_to?(:cg_species_id) ? member.cg_species_id.to_i : 0
        dex = member.respond_to?(:cg_national_dex) ? member.cg_national_dex.to_i : 0
        append_runtime_log("ALLY name=" + member.name.to_s + " actor=" + member.id.to_s +
          " species=" + species_id.to_s + " form=" + form_id.to_s +
          " dex=" + dex.to_s + " pmd=" + member.cg_pmd_sprite_key.to_s)
      end
    end
  end
end

# 安裝不依賴資料庫物件的表格。Scene_Title 載入後會再執行一次以確保一致。
ALBERT_CG::SPECIES26.install_pmd_tables
ALBERT_CG::SPECIES26.install_combat_tables
ALBERT_CG::SPECIES26.install_evolution_tables

#------------------------------------------------------------------------------
# ■ Game_Actor / Game_Enemy：提供全國圖鑑編號查詢
#------------------------------------------------------------------------------
class Game_Actor < Game_Battler
  def cg_national_dex
    form_id = respond_to?(:cg_current_form_actor_id) ? cg_current_form_actor_id.to_i : 0
    form_id = cg_species_id.to_i if form_id <= 0 && respond_to?(:cg_species_id)
    return ALBERT_CG::SPECIES26.dex_for_actor_id(form_id)
  end
end

class Game_Enemy < Game_Battler
  def cg_national_dex
    form_id = respond_to?(:cg_capture_species_id) ? cg_capture_species_id.to_i : 0
    form_id = CG_PMD.enemy_species_id(self).to_i if form_id <= 0 && defined?(CG_PMD)
    return ALBERT_CG::SPECIES26.dex_for_actor_id(form_id)
  end
end

#------------------------------------------------------------------------------
# ■ 正式 Demo Party：#001 妙蛙種子 / #004 小火龍 / #007 傑尼龜
#------------------------------------------------------------------------------
module ALBERT_CG
  def self.bootstrap_demo_party
    $game_party.cg_normalize_pet_owners! if $game_party.respond_to?(:cg_normalize_pet_owners!)
    pet_a = create_demo_pet(100, 5, "妙蛙種子A")
    pet_b = create_demo_pet(103, 5, "小火龍A")
    pet_c = create_demo_pet(106, 5, "傑尼龜A")
    # 若沿用先前測試存檔，把舊的水躍魚測試名稱修正，但不碰玩家自行改名的其他個體。
    if pet_c != nil && pet_c.name.to_s == "水躍魚A"
      pet_c.name = "傑尼龜A"
    end
    if pet_a != nil && $game_party.cg_active_pet == nil
      $game_party.cg_deploy_pet(pet_a.id, ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID)
    end
    $game_player.refresh if $game_player != nil
    return $game_party.cg_owned_pet_ids
  end

  class << self
    alias species26_registry_start_demo_battle start_demo_battle
    def start_demo_battle(troop_id = ALBERT_CG::DEMO_TROOP_ID)
      ALBERT_CG::SPECIES26.log_demo_identity
      return species26_registry_start_demo_battle(troop_id)
    end
  end
end

#------------------------------------------------------------------------------
# ■ Scene_Title：所有舊原型測試資料載入後，以正式 0001～0026 覆寫
#------------------------------------------------------------------------------
class Scene_Title < Scene_Base
  alias species26_registry_load_database load_database
  def load_database
    species26_registry_load_database
    ALBERT_CG::SPECIES26.apply
  end

  alias species26_registry_load_bt_database load_bt_database
  def load_bt_database
    species26_registry_load_bt_database
    ALBERT_CG::SPECIES26.apply
  end
end
