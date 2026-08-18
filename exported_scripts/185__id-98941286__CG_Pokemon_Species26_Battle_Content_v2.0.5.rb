# RMVX_SCRIPT_INDEX: 185
# RMVX_SCRIPT_ID: 98941286
# RMVX_SCRIPT_NAME: CG Pokemon Species26 Battle Content v2.0.5
# RMVX_SOURCE_SHA256: 1d8a93b980fa92b5808976755476148a623a94640eeab4be793b478092971ffc

#==============================================================================
# ■ CG Pokemon Species26 Battle Content v2.0.5
#------------------------------------------------------------------------------
# 【用途】
#  將全國圖鑑 #0001～#0026 從「已建立物種／PMD 顯示」推進成真正可戰鬥內容。
#  本腳本集中處理：
#    1. 0001～0026 共用的正式技能資料。
#    2. 10 條進化系譜的等級技能學習表。
#    3. Clone／固定 Actor／進化後的技能自動同步。
#    4. 所有 26 個 Form 的技能欄容量。
#    5. 26 隻 Enemy 的技能 AI、等級與技能選擇。
#    6. 新技能對 PMD Native Motion 的對應。
#    7. 啟動時自動產生 Species26_BattleContent.log 稽核資料。
#
# 【設計原則】
#  - 以寶可夢原作招式風格為基準，但配合本專案單機 RPG／6～8 技能欄重新整理。
#  - 每條系譜 Lv.60 前不會超過最終型態技能欄容量，避免升級時突然需要人工
#    處理「技能格已滿」而卡住流程。
#  - 低階型態只會學自己的階段技能；沒有進化就不會偷學最終型技能。
#  - 捕捉到已進化型態時，會補齊該型態在目前等級理應已學會的前置技能。
#  - 進化不刪除舊技能，只補上新型態已達條件的技能。
#  - 技能熟練／技能等級仍完全沿用既有 CG Skill Level Core。
#
# 【技能欄容量】
#  三階進化：第一階 6 格、第二階 7 格、最終階 8 格。
#  二階進化：第一階 6 格、第二階 7 格。
#  只有一個 Form 時可維持 6 格（本批 #0001～#0026 無純單階系譜）。
#
# 【學習規則】
#  LINEAGE_LEARNSETS 格式：
#    系譜基底 Dex => [ [需求等級, Skill ID, 最低進化階段], ... ]
#
#  例如妙蛙種子系：
#    [1, 654, 1]  => Lv.1 起可學撞擊，第一階就能學。
#    [16,655, 2]  => 至少進化到妙蛙草，且 Lv.16 後才可學飛葉快刀。
#    [32,656, 3]  => 妙蛙花 Lv.32 後才可學成長。
#
# 【Enemy AI】
#  - 普攻 rating 4。
#  - STAB 傷害技能 rating 7。
#  - 非 STAB 傷害技能 rating 6。
#  - 狀態／強化技能 rating 5。
#  - 守住只在 HP 0～50% 時可選，rating 7。
#  Enemy 仍使用 VX 原生 rating 抽選，先建立穩定的第一階段 AI；更完整的
#  Gamebit／條件 AI 會在後續版本獨立處理，不在本頁塞成巨型 if 地獄。
#
# 【PMD Motion】
#  技能資料會直接寫入 <pmd_motion: ...>，並同步 CG_PMD::SKILL_MOTION_TABLE。
#    melee   ：接近 → Attack → HitFrame → 返回
#    attack  ：原地 Attack → HitFrame
#    shoot   ：Shoot → HitFrame
#    charge  ：Charge → HitFrame
#    pose    ：Pose → 技能效果
#
# 【新增狀態】
#  State 37 麻痺：AGI 50%，4 回合。
#  State 38 防禦提升：DEF 150%，4 回合。
#  State 39 睡眠：無法行動，2 回合。
#  State 41 生長：ATK／SPI 125%，4 回合。
#  State 42 煙幕：降低命中，3 回合。
#  狀態 ID 40 暫時保留，避免和未來既有資料混用。
#
# 【事件／腳本呼叫】
#  actor.cg_refresh_species26_learnset
#    → 依目前 Form、等級補齊應學技能，不刪任何已學技能。
#
#  ALBERT_CG::SPECIES26_CONTENT.eligible_skill_ids(25, 20)
#    → 回傳 Lv.20 皮卡丘目前型態應能使用的技能 ID。
#
#  ALBERT_CG::SPECIES26_CONTENT.refresh_enemy(25)
#    → 重建 #025 皮卡丘 Enemy 的等級與 AI 技能表。
#
# 【測試】
#  F6：沿用正常 PMD 戰鬥，Starter 三隻會依 Lv.5 自動取得新技能表。
#  F10：進化後會立即補上新型態已符合條件的技能。
#  啟動遊戲：專案根目錄產生 Species26_BattleContent.log。
#
# 【腳本位置】
#  必須放在：
#    CG Pokemon Species 0001-0026 Registry
#    CG PMD Direct Actor Party
#  之下，BattleInit RootFix／AutoTest Harness／Main 之前。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_Species26BattleContent"] = "2.0.5"

module ALBERT_CG
  module SPECIES26_CONTENT
    VERSION = "2.0.5"
    LOG_FILE = "Species26_BattleContent.log"

    #--------------------------------------------------------------------------
    # 新增狀態 ID
    #--------------------------------------------------------------------------
    STATE_PARALYSIS = 37
    STATE_DEF_UP    = 38
    STATE_SLEEP     = 39
    STATE_GROWTH    = 41
    STATE_SMOKE     = 42

    #--------------------------------------------------------------------------
    # Skill ID =>
    # [名稱, type, power, class, MP, motion, scope, hit, speed, 狀態ID, 狀態率, 說明]
    # class = :physical / :special / :status
    #--------------------------------------------------------------------------
    SKILLS = {
      655 => ["飛葉快刀", :grass,    55, :physical, 7, :shoot,        1, 100,   0,  0,  0, "放出銳利葉片攻擊敵人。"],
      656 => ["生長",     :grass,     0, :status,   7, :pose,        11, 100,   0, STATE_GROWTH, 100, "提升自身攻擊與特殊能力。"],
      657 => ["煙幕",     :normal,    0, :status,   5, :shoot,        1, 100,   0, STATE_SMOKE,  85, "以煙幕干擾敵人，使攻擊較容易落空。"],
      658 => ["火焰旋渦", :fire,     35, :special,  8, :shoot,        1,  95,   0, 34, 15, "用旋轉火焰攻擊，偶爾造成灼燒。"],
      659 => ["水之波動", :water,    60, :special,  8, :shoot,        1, 100,   0,  0,  0, "以水之波動攻擊敵人。"],
      660 => ["泡沫",     :water,    40, :special,  5, :shoot,        1, 100,   0, 33, 20, "噴出泡沫攻擊，偶爾使敵人遲緩。"],
      661 => ["縮入殼中", :water,     0, :status,   6, :pose,        11, 100,   0, STATE_DEF_UP, 100, "縮入殼中，提高自身防禦。"],
      662 => ["咬住",     :dark,     60, :physical, 7, :melee_attack,1, 100,   0,  0,  0, "用尖牙咬住敵人。"],
      663 => ["吐絲",     :bug,       0, :status,   5, :shoot,        1, 100,   0, 33, 75, "吐出黏絲，大幅妨礙敵人的速度。"],
      664 => ["蟲咬",     :bug,      60, :physical, 6, :melee_attack,1, 100,   0,  0,  0, "以蟲系近身攻擊撕咬敵人。"],
      665 => ["變硬",     :normal,    0, :status,   5, :pose,        11, 100,   0, STATE_DEF_UP, 100, "使身體變硬，提高自身防禦。"],
      666 => ["起風",     :flying,   40, :special,  5, :shoot,        1, 100,   0,  0,  0, "颳起強風攻擊敵人。"],
      667 => ["念力",     :psychic,  50, :special,  7, :charge,       1, 100,   0,  0,  0, "以念力衝擊敵人。"],
      668 => ["睡眠粉",   :grass,     0, :status,   8, :shoot,        1,  75,   0, STATE_SLEEP, 70, "撒出睡眠粉，使敵人暫時無法行動。"],
      669 => ["毒針",     :poison,   30, :physical, 4, :shoot,        1, 100,   0, 31, 30, "射出有毒尖針，偶爾使敵人中毒。"],
      670 => ["雙針",     :bug,      50, :physical, 7, :stationary_attack,1,100,0,31,20,"以連續刺擊造成蟲系傷害；目前以合併傷害呈現。"],
      671 => ["亂擊",     :normal,   60, :physical, 7, :melee_attack,1,  95,   0,  0,  0, "連續突擊敵人；目前以合併傷害呈現。"],
      672 => ["電光一閃", :normal,   40, :physical, 5, :melee_attack,1, 100, 300,  0,  0, "高速接近敵人並發動攻擊。"],
      673 => ["翅膀攻擊", :flying,   60, :physical, 7, :melee_attack,1, 100,   0,  0,  0, "以翅膀近身攻擊敵人。"],
      674 => ["必殺門牙", :normal,   80, :physical, 9, :melee_attack,1,  90,   0,  0,  0, "以鋒利門牙發動強力攻擊。"],
      675 => ["啄",       :flying,   35, :physical, 4, :melee_attack,1, 100,   0,  0,  0, "用尖銳鳥喙啄擊敵人。"],
      676 => ["燕返",     :flying,   60, :physical, 7, :melee_attack,1, 100, 100,  0,  0, "快速切入攻擊敵人。"],
      677 => ["緊束",     :normal,   50, :physical, 6, :melee_attack,1, 100,   0, 33, 20, "纏住敵人攻擊，偶爾使其遲緩。"],
      678 => ["溶解液",   :poison,   40, :special,  6, :shoot,        1, 100,   0, 31, 20, "噴出酸性液體攻擊，偶爾造成中毒。"],
      679 => ["電球",     :electric, 60, :special,  7, :shoot,        1, 100,   0, 37, 10, "釋放電能球攻擊敵人。"],
      680 => ["電擊",     :electric, 40, :special,  5, :shoot,        1, 100,   0, 37, 20, "以電流攻擊，偶爾造成麻痺。"],
      681 => ["電磁波",   :electric,  0, :status,   7, :shoot,        1,  90,   0, 37, 100,"放出電磁波，使敵人麻痺。"],
      682 => ["十萬伏特", :electric, 90, :special, 11, :shoot,        1, 100,   0, 37, 10, "以強烈電流攻擊敵人。"],
      684 => ["咬碎",     :dark,     80, :physical, 9, :melee_attack,1, 100,   0,  0,  0, "以強力尖牙咬碎敵人。"],
    }

    #--------------------------------------------------------------------------
    # 系譜技能表：base dex => [level, skill_id, minimum_stage]
    #--------------------------------------------------------------------------
    LINEAGE_LEARNSETS = {
       1 => [[1,654,1],[1,600,1],[5,601,1],[8,602,1],[16,655,2],[32,656,3]],
       4 => [[1,607,1],[1,608,1],[5,657,1],[10,612,1],[16,672,2],[30,658,3]],
       7 => [[1,654,1],[1,617,1],[5,660,1],[8,618,1],[16,662,2],[20,653,2],[30,659,3]],
      10 => [[1,654,1],[1,663,1],[6,664,1],[7,665,2],[10,666,3],[10,667,3],[15,668,3]],
      13 => [[1,669,1],[1,663,1],[6,664,1],[7,665,2],[10,670,3],[15,671,3]],
      16 => [[1,654,1],[1,666,1],[5,672,1],[18,673,2],[36,676,3]],
      19 => [[1,654,1],[4,672,1],[10,662,1],[20,674,2],[30,684,2]],
      21 => [[1,675,1],[5,672,1],[10,671,1],[20,676,2],[25,673,2]],
      23 => [[1,677,1],[4,669,1],[10,662,1],[18,678,1],[22,684,2]],
      25 => [[1,680,1],[5,681,1],[8,672,1],[15,679,1],[30,682,2]],
    }

    # 各 Form 的野生 Enemy 測試等級。進化型至少達到合理進化門檻。
    WILD_LEVELS = {
       1=>5,  2=>18, 3=>36,
       4=>5,  5=>18, 6=>38,
       7=>5,  8=>18, 9=>38,
      10=>5, 11=>8, 12=>12,
      13=>5, 14=>8, 15=>12,
      16=>5, 17=>20,18=>38,
      19=>5, 20=>22,
      21=>5, 22=>22,
      23=>5, 24=>24,
      25=>5, 26=>32,
    }

    #--------------------------------------------------------------------------
    # 資料輔助
    #--------------------------------------------------------------------------
    def self.ensure_index(array, index)
      array.push(nil) while array.size <= index
    end

    def self.type_id(type_key)
      return 0 unless defined?(ALBERT_CG::POKEMON_COMBAT)
      value = ALBERT_CG::POKEMON_COMBAT::TYPE_IDS[type_key]
      return value == nil ? 0 : value.to_i
    end

    def self.motion_note(motion)
      name = case motion
      when :melee_attack then "melee"
      when :stationary_attack then "attack"
      when :shoot then "shoot"
      when :charge then "charge"
      when :pose then "pose"
      else "charge"
      end
      return "<pmd_motion: " + name + ">"
    end

    def self.range_note(motion)
      return "<cg_range: melee>" if motion == :melee_attack
      return "<cg_range: ranged>" if motion == :shoot || motion == :stationary_attack
      return ""
    end

    def self.make_skill(id, row)
      name, type_key, power, damage_class, mp_cost, motion, scope, hit,
        speed, state_id, state_chance, description = row
      skill = RPG::Skill.new
      skill.id = id.to_i
      skill.name = name.to_s
      skill.icon_index = 0
      skill.description = description.to_s
      skill.scope = scope.to_i
      skill.occasion = 1
      skill.speed = speed.to_i
      skill.animation_id = 1
      skill.common_event_id = 0
      skill.base_damage = power.to_i > 0 ? [power.to_i / 2, 1].max : 0
      skill.variance = damage_class == :status ? 0 : 15
      skill.atk_f = damage_class == :physical ? 100 : 0
      skill.spi_f = damage_class == :special ? 100 : 0
      skill.hit = hit.to_i
      skill.physical_attack = (damage_class == :physical)
      skill.damage_to_mp = false
      skill.absorb_damage = false
      skill.ignore_defense = false
      skill.mp_cost = mp_cost.to_i
      element_id = type_id(type_key)
      skill.element_set = element_id <= 0 ? [] : [element_id]
      skill.plus_state_set = []
      skill.minus_state_set = []
      skill.message1 = "使用了" + name.to_s + "！"
      skill.message2 = ""
      notes = []
      motion_text = motion_note(motion)
      notes.push(motion_text) unless motion_text == ""
      range_text = range_note(motion)
      notes.push(range_text) unless range_text == ""
      if state_id.to_i > 0 && state_chance.to_i > 0
        notes.push("<cg_state_chance: " + state_id.to_i.to_s + "," + state_chance.to_i.to_s + ">")
      end
      skill.note = notes.join("\n")
      return skill
    end

    def self.make_state(id, name, icon, hold, restriction,
                        atk_rate, def_rate, spi_rate, agi_rate,
                        slip, reduce_hit)
      state = RPG::State.new
      state.id = id.to_i
      state.name = name.to_s
      state.icon_index = icon.to_i
      state.restriction = restriction.to_i
      state.priority = 5
      state.atk_rate = atk_rate.to_i
      state.def_rate = def_rate.to_i
      state.spi_rate = spi_rate.to_i
      state.agi_rate = agi_rate.to_i
      state.nonresistance = true
      state.offset_by_opposite = false
      state.slip_damage = slip == true
      state.reduce_hit_ratio = reduce_hit == true
      state.battle_only = true
      state.release_by_damage = false
      state.hold_turn = hold.to_i
      state.auto_release_prob = 100
      state.message1 = "陷入" + name.to_s + "。"
      state.message2 = "陷入" + name.to_s + "。"
      state.message3 = name.to_s + "持續中。"
      state.message4 = name.to_s + "解除。"
      state.element_set = []
      state.state_set = []
      state.note = ""
      return state
    end

    def self.install_states
      rows = {
        STATE_PARALYSIS => make_state(STATE_PARALYSIS, "麻痺", 8, 4, 0, 100,100,100,50, false, false),
        STATE_DEF_UP    => make_state(STATE_DEF_UP, "防禦提升", 9, 4, 0, 100,150,100,100,false,false),
        STATE_SLEEP     => make_state(STATE_SLEEP, "睡眠", 10, 2, 4, 100,100,100,100,false,false),
        STATE_GROWTH    => make_state(STATE_GROWTH, "生長", 11, 4, 0, 125,100,125,100,false,false),
        STATE_SMOKE     => make_state(STATE_SMOKE, "煙幕", 12, 3, 0, 100,100,100,100,false,true),
      }
      rows.each do |id, state|
        ensure_index($data_states, id)
        $data_states[id] = state
      end
    end

    def self.install_skills
      SKILLS.each do |id, row|
        ensure_index($data_skills, id)
        $data_skills[id] = make_skill(id, row)
        if defined?(ALBERT_CG::POKEMON_COMBAT_DATA)
          ALBERT_CG::POKEMON_COMBAT_DATA::SKILL_COMBAT_TABLE[id] = {
            :type=>row[1], :power=>row[2], :class=>row[3]
          }
        end
        if defined?(CG_PMD) && CG_PMD.const_defined?("SKILL_MOTION_TABLE")
          CG_PMD::SKILL_MOTION_TABLE[id] = row[5]
        end
      end
    end

    def self.base_dex_for(dex)
      return 0 unless defined?(ALBERT_CG::SPECIES26)
      return ALBERT_CG::SPECIES26.line_base_dex(dex.to_i)
    end

    def self.stage_for_dex(dex)
      return 1 unless defined?(ALBERT_CG::SPECIES26)
      base = base_dex_for(dex)
      list = ALBERT_CG::SPECIES26::LINEAGES[base] || [dex.to_i]
      index = list.index(dex.to_i)
      return index == nil ? 1 : index + 1
    end

    def self.learnset_for_dex(dex)
      base = base_dex_for(dex)
      return LINEAGE_LEARNSETS[base] || []
    end

    def self.eligible_skill_ids(dex, level)
      dex = dex.to_i
      level = level.to_i
      stage = stage_for_dex(dex)
      result = []
      for row in learnset_for_dex(dex)
        need_level = row[0].to_i
        skill_id = row[1].to_i
        need_stage = row[2].to_i
        next if level < need_level
        next if stage < need_stage
        result.push(skill_id) unless result.include?(skill_id)
      end
      return result
    end

    def self.install_class_learnings
      return unless defined?(ALBERT_CG::SPECIES26)
      ALBERT_CG::SPECIES26::LINE_CLASS.each do |base_dex, class_id|
        klass = $data_classes[class_id]
        next if klass == nil
        klass.learnings = []
        list = LINEAGE_LEARNSETS[base_dex] || []
        for row in list
          learning = RPG::Class::Learning.new
          learning.level = row[0].to_i
          learning.skill_id = row[1].to_i
          klass.learnings.push(learning)
        end
      end
    end

    def self.install_slot_limits
      return unless defined?(ALBERT_CG::SPECIES26)
      return unless defined?(ALBERT_CG::PET_SKILL_SLOT_LIMITS)
      for dex in 1..26
        actor_id = ALBERT_CG::SPECIES26.actor_id_for_dex(dex)
        stage = stage_for_dex(dex)
        limit = stage == 1 ? 6 : (stage == 2 ? 7 : 8)
        ALBERT_CG::PET_SKILL_SLOT_LIMITS[actor_id] = limit
      end
    end

    def self.wild_level_for(dex)
      value = WILD_LEVELS[dex.to_i]
      return value == nil ? 5 : [value.to_i, 1].max
    end

    def self.skill_status?(skill_id)
      row = SKILLS[skill_id.to_i]
      if row != nil
        return row[3] == :status
      end
      if defined?(ALBERT_CG::POKEMON_COMBAT_DATA)
        data = ALBERT_CG::POKEMON_COMBAT_DATA.skill_data(skill_id)
        return data != nil && data[:class] == :status
      end
      return false
    end

    def self.skill_type(skill_id)
      row = SKILLS[skill_id.to_i]
      return row[1] if row != nil
      if defined?(ALBERT_CG::POKEMON_COMBAT_DATA)
        data = ALBERT_CG::POKEMON_COMBAT_DATA.skill_data(skill_id)
        return data[:type] if data != nil
      end
      return nil
    end

    def self.make_enemy_action(kind, skill_id, rating, hp_min = nil, hp_max = nil)
      action = RPG::Enemy::Action.new
      action.kind = kind.to_i
      action.basic = 0
      action.skill_id = skill_id.to_i
      action.rating = rating.to_i
      if hp_min != nil || hp_max != nil
        action.condition_type = 2
        action.condition_param1 = hp_min == nil ? 0 : hp_min.to_i
        action.condition_param2 = hp_max == nil ? 100 : hp_max.to_i
      else
        action.condition_type = 0
        action.condition_param1 = 0
        action.condition_param2 = 0
      end
      return action
    end

    def self.capture_rank_for_dex(dex)
      stage = stage_for_dex(dex)
      return stage == 1 ? 1 : (stage == 2 ? 2 : 3)
    end

    def self.refresh_enemy(dex)
      return false unless defined?(ALBERT_CG::SPECIES26)
      enemy_id = ALBERT_CG::SPECIES26.enemy_id_for_dex(dex)
      actor_id = ALBERT_CG::SPECIES26.actor_id_for_dex(dex)
      enemy = $data_enemies[enemy_id]
      return false if enemy == nil
      level = wild_level_for(dex)
      skills = eligible_skill_ids(dex, level)
      types = ALBERT_CG::SPECIES26.types_for_dex(dex)
      enemy.actions = [make_enemy_action(0, 0, 4)]
      for skill_id in skills
        skill = $data_skills[skill_id]
        next if skill == nil
        status = skill_status?(skill_id)
        rating = 5
        unless status
          rating = types.include?(skill_type(skill_id)) ? 7 : 6
        end
        if skill_id.to_i == 618
          enemy.actions.push(make_enemy_action(1, skill_id, 7, 0, 50))
        else
          enemy.actions.push(make_enemy_action(1, skill_id, rating))
        end
      end
      if defined?(ALBERT_CG::POKEMON_COMBAT_DATA)
        ALBERT_CG::POKEMON_COMBAT_DATA::ENEMY_LEVEL_TABLE[enemy_id] = level
      end
      rank = capture_rank_for_dex(dex)
      enemy.note = "<cg_species: " + actor_id.to_s + ">\n" +
                   "<cg_capture_rank: " + rank.to_s + ">\n" +
                   "<pmd species: " + actor_id.to_s + ">\n" +
                   "<pokemon_level: " + level.to_s + ">"
      return true
    end

    def self.install_enemy_ai
      for dex in 1..26
        refresh_enemy(dex)
      end
    end

    def self.apply
      return false if $data_skills == nil || $data_states == nil
      install_states
      install_skills
      install_class_learnings
      install_slot_limits
      install_enemy_ai
      if $data_system != nil
        $data_system.game_title = "CG Pet Battle Prototype v2.0.5 PMD26 BattleContent"
      end
      write_audit_log
      return true
    end

    def self.write_audit_log
      begin
        File.open(LOG_FILE, "wb") do |file|
          file.write("CG SPECIES26 BATTLE CONTENT LOG v" + VERSION + "\r\n")
          file.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
          file.write("------------------------------------------------------------\r\n")
          skill_ok = 0
          motion_ok = 0
          SKILLS.each do |id, row|
            skill_ok += 1 if $data_skills[id] != nil && $data_skills[id].name.to_s == row[0].to_s
            if defined?(CG_PMD) && CG_PMD.respond_to?(:skill_motion_for)
              motion_ok += 1 if CG_PMD.skill_motion_for($data_skills[id]) == row[5]
            end
          end
          enemy_ok = 0
          overflow = []
          for dex in 1..26
            if defined?(ALBERT_CG::SPECIES26)
              enemy = $data_enemies[ALBERT_CG::SPECIES26.enemy_id_for_dex(dex)]
              enemy_ok += 1 if enemy != nil && enemy.actions != nil && enemy.actions.size >= 2
              skills = eligible_skill_ids(dex, 60)
              actor_id = ALBERT_CG::SPECIES26.actor_id_for_dex(dex)
              limit = ALBERT_CG::PET_SKILL_SLOT_LIMITS[actor_id]
              if limit != nil && skills.size > limit.to_i
                overflow.push(sprintf("%04d=%d/%d", dex, skills.size, limit.to_i))
              end
            end
          end
          file.write("NEW_SKILLS=" + SKILLS.size.to_s + " skill_ok=" + skill_ok.to_s +
            " motion_ok=" + motion_ok.to_s + "\r\n")
          file.write("ENEMY_AI=" + enemy_ok.to_s + "/26\r\n")
          file.write("LEARNSET_OVERFLOW=" + (overflow.empty? ? "NONE" : overflow.join(",")) + "\r\n")
          for base_dex in LINEAGE_LEARNSETS.keys.sort
            rows = LINEAGE_LEARNSETS[base_dex]
            text = []
            for row in rows
              skill = $data_skills[row[1]]
              text.push("Lv" + row[0].to_s + "/S" + row[2].to_s + ":" +
                (skill == nil ? row[1].to_s : skill.name.to_s))
            end
            file.write(sprintf("LINE %04d => %s\r\n", base_dex, text.join(" | ")))
          end
          result = (skill_ok == SKILLS.size && motion_ok == SKILLS.size && enemy_ok == 26 && overflow.empty?) ? "PASS" : "CHECK"
          file.write("RESULT=" + result + "\r\n")
        end
      rescue
      end
    end

    def self.append_log(text)
      begin
        File.open(LOG_FILE, "ab") do |file|
          file.write("[" + Time.now.strftime("%H:%M:%S") + "] " + text.to_s + "\r\n")
        end
      rescue
      end
    end
  end
end

#==============================================================================
# ■ Game_Actor：依目前 Form 正確決定技能欄容量 + 正式等級學習
#==============================================================================
class Game_Actor < Game_Battler
  alias species26_content_slot_limit cg_skill_slot_limit
  def cg_skill_slot_limit
    if respond_to?(:cg_skill_pet?) && cg_skill_pet?
      form_id = 0
      form_id = cg_current_form_actor_id.to_i if respond_to?(:cg_current_form_actor_id)
      form_id = cg_species_id.to_i if form_id <= 0 && respond_to?(:cg_species_id)
      value = ALBERT_CG::PET_SKILL_SLOT_LIMITS[form_id]
      unless value == nil
        @cg_highest_skill_slot_limit = value if @cg_highest_skill_slot_limit == nil
        @cg_highest_skill_slot_limit = value if value > @cg_highest_skill_slot_limit.to_i
        return [@cg_highest_skill_slot_limit.to_i, 1].max
      end
    end
    return species26_content_slot_limit
  end

  def cg_species26_current_dex
    if respond_to?(:cg_national_dex)
      value = cg_national_dex.to_i
      return value if value >= 1 && value <= 26
    end
    form_id = respond_to?(:cg_current_form_actor_id) ? cg_current_form_actor_id.to_i : 0
    return 0 unless defined?(ALBERT_CG::SPECIES26)
    return ALBERT_CG::SPECIES26.dex_for_actor_id(form_id)
  end

  def cg_refresh_species26_learnset
    dex = cg_species26_current_dex
    return [] if dex <= 0
    ids = ALBERT_CG::SPECIES26_CONTENT.eligible_skill_ids(dex, @level.to_i)
    learned = []
    for skill_id in ids
      next if respond_to?(:cg_skill_equipped?) && cg_skill_equipped?(skill_id)
      result = cg_learn_skill_to_slot(skill_id, 1, nil)
      if result == true
        learned.push(skill_id)
        skill = $data_skills[skill_id]
        ALBERT_CG::SPECIES26_CONTENT.append_log(
          "LEARN actor=" + name.to_s + " dex=" + sprintf("%04d", dex) +
          " lv=" + @level.to_i.to_s + " skill=" + skill_id.to_s + ":" +
          (skill == nil ? "?" : skill.name.to_s))
      elsif result == :need_replace
        ALBERT_CG::SPECIES26_CONTENT.append_log(
          "LEARN_BLOCKED_FULL actor=" + name.to_s + " dex=" + sprintf("%04d", dex) +
          " lv=" + @level.to_i.to_s + " skill=" + skill_id.to_s)
      end
    end
    return learned
  end

  alias species26_content_level_up level_up
  def level_up
    species26_content_level_up
    cg_refresh_species26_learnset if respond_to?(:cg_refresh_species26_learnset)
  end

  alias species26_content_evolve_to cg_evolve_to
  def cg_evolve_to(form_actor_id = nil, force = false)
    result = species26_content_evolve_to(form_actor_id, force)
    cg_refresh_species26_learnset if result && respond_to?(:cg_refresh_species26_learnset)
    return result
  end
end

#==============================================================================
# ■ Game_Actors：新捕捉／新建立 Clone 立即同步目前等級技能
#==============================================================================
class Game_Actors
  alias species26_content_create_pet cg_create_pet
  def cg_create_pet(model_actor_id, level = nil, custom_name = nil, owner_actor_id = nil)
    pet = species26_content_create_pet(model_actor_id, level, custom_name, owner_actor_id)
    if pet != nil && pet.respond_to?(:cg_refresh_species26_learnset)
      pet.cg_refresh_species26_learnset
    end
    return pet
  end
end

#==============================================================================
# ■ Demo Party：每次 F6 前都重新同步三隻 Starter 技能
#==============================================================================
module ALBERT_CG
  class << self
    alias species26_content_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = species26_content_bootstrap_demo_party
      if $game_party != nil
        for actor in $game_party.members
          next unless actor.respond_to?(:cg_refresh_species26_learnset)
          actor.cg_refresh_species26_learnset
        end
      end
      return result
    end
  end
end

#==============================================================================
# ■ Scene_Title：Registry／Direct Actor 資料覆寫後，再裝正式戰鬥內容
#==============================================================================
class Scene_Title < Scene_Base
  alias species26_content_load_database load_database
  def load_database
    species26_content_load_database
    ALBERT_CG::SPECIES26_CONTENT.apply
  end

  alias species26_content_load_bt_database load_bt_database
  def load_bt_database
    species26_content_load_bt_database
    ALBERT_CG::SPECIES26_CONTENT.apply
  end
end
