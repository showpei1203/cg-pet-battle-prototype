# RMVX_SCRIPT_INDEX: 176
# RMVX_SCRIPT_ID: 98941080
# RMVX_SCRIPT_NAME: CG Pokemon Combat Core v2.0.1
# RMVX_SOURCE_SHA256: 4ab74b7df6f92fb66a7ccb33ce1d86c73d276a9f98e54a38fbdbce04f3d309b6

#==============================================================================
# ■ CG Pokemon Combat Core v2.0.1
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# Project: CG Pet Battle Prototype
#
# 【Purpose】
#   Formal 18-type Pokemon combat core for the CG project.
#
# 【Rules】
#   1. Keep all 18 Pokemon types. The old four-element plan is retired.
#   2. Human actor body type is Normal.
#   3. Pet types come from current-form tables; enemy notes are fallback only.
#   4. Dual defensive types multiply: 0 / 0.25 / 0.5 / 1 / 2 / 4.
#   5. STAB is 1.5x when the move type matches either user type.
#   6. Positive skill damage uses a Pokemon-style level/power/stat formula.
#   7. Recovery, support skills and damaging items keep the existing VX flow.
#
# 【Data sources】
#   Actor / Class:
#     RPG Maker VX has no Note box for these database types.
#     Body type, inherent rate and basic attack fallback come from
#     CG Pokemon Combat Data v2.0.1 tables.
#
#   Enemy / State:
#     <pokemon_types: grass, poison>      # Enemy fallback only
#     <pokemon_type_set: fire, flying>    # State: temporary type override
#
#   Weapon / Enemy:
#     <basic_attack_type: normal>
#     <basic_attack_power: 40>
#
#   Skill:
#     <pokemon_power: 40>
#     <damage_class: physical>
#     <damage_class: special>
#     <damage_class: mixed>
#     <damage_class: fixed>
#     <no_critical>
#
#   Weapon / Armor / Enemy / State:
#     <type_rate: fire, 50>      # takes 50% of normal Fire damage
#     <type_rate: water, 150>    # takes 150% of normal Water damage
#     <type_immunity: ground>
#
#   Actor / Class inherent rates use central tables, never Note.
#
# 【Reference policy】
#   Architecture was independently adapted after studying:
#   - Yanfly Element Affinity: final-rate authority and note-source layering.
#   - KGC / Yanfly PLUS: UI-data separation and help-window conventions.
#   - Maou Hunting battle formula: Pokemon-style level/power/stat structure.
#   - Maou Hunting Pokemon Statistics: persistent species/individual separation.
#   No reference script is copied wholesale. Their direct overwrites conflict with
#   the CG dual-command and Tankentai pipeline, because naturally every old script
#   believes it is the sole monarch of Game_Battler.
#
# 【Placement】
#   CG Battle Formation Lock v1.9.1a
#   CG Pokemon Combat Data v2.0.1
#   CG Pokemon Combat Core v2.0.1
#   Main
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonCombatCore"] = "2.0.1"

module ALBERT_CG
  module POKEMON_COMBAT
    VERSION = "2.0.1"

    TYPE_IDS = {
      :normal => 4, :fighting => 5, :flying => 6, :poison => 7,
      :ground => 8, :rock => 9, :bug => 10, :ghost => 11,
      :steel => 12, :fire => 13, :water => 14, :grass => 15,
      :electric => 16, :psychic => 17, :ice => 18, :dragon => 19,
      :dark => 20, :fairy => 21
    }

    ID_TYPES = {}
    TYPE_IDS.each { |key, value| ID_TYPES[value] = key }

    TYPE_FULL_NAMES = {
      :normal => "一般", :fighting => "格鬥", :flying => "飛行",
      :poison => "毒", :ground => "地面", :rock => "岩石",
      :bug => "蟲", :ghost => "幽靈", :steel => "鋼",
      :fire => "火", :water => "水", :grass => "草",
      :electric => "電", :psychic => "超能力", :ice => "冰",
      :dragon => "龍", :dark => "惡", :fairy => "妖精"
    }

    TYPE_ALIASES = {
      "normal"=>:normal, "一般"=>:normal, "普"=>:normal,
      "fighting"=>:fighting, "格鬥"=>:fighting, "格斗"=>:fighting,
      "flying"=>:flying, "飛行"=>:flying, "飞行"=>:flying,
      "poison"=>:poison, "毒"=>:poison,
      "ground"=>:ground, "地面"=>:ground,
      "rock"=>:rock, "岩石"=>:rock, "岩"=>:rock,
      "bug"=>:bug, "蟲"=>:bug, "虫"=>:bug,
      "ghost"=>:ghost, "幽靈"=>:ghost, "幽灵"=>:ghost,
      "steel"=>:steel, "鋼"=>:steel, "钢"=>:steel,
      "fire"=>:fire, "火"=>:fire,
      "water"=>:water, "水"=>:water,
      "grass"=>:grass, "草"=>:grass,
      "electric"=>:electric, "電"=>:electric, "电"=>:electric,
      "psychic"=>:psychic, "超能力"=>:psychic, "超"=>:psychic,
      "ice"=>:ice, "冰"=>:ice,
      "dragon"=>:dragon, "龍"=>:dragon, "龙"=>:dragon,
      "dark"=>:dark, "惡"=>:dark, "恶"=>:dark,
      "fairy"=>:fairy, "妖精"=>:fairy, "妖"=>:fairy
    }

    # Attacking type => { defending type => percent }
    TYPE_CHART = {
      :normal => {:rock=>50, :ghost=>0, :steel=>50},
      :fighting => {:normal=>200, :flying=>50, :poison=>50,
        :rock=>200, :bug=>50, :ghost=>0, :steel=>200, :psychic=>50,
        :ice=>200, :dark=>200, :fairy=>50},
      :flying => {:fighting=>200, :rock=>50, :bug=>200,
        :steel=>50, :grass=>200, :electric=>50},
      :poison => {:poison=>50, :ground=>50, :rock=>50, :ghost=>50,
        :steel=>0, :grass=>200, :fairy=>200},
      :ground => {:flying=>0, :poison=>200, :rock=>200, :bug=>50,
        :steel=>200, :fire=>200, :grass=>50, :electric=>200},
      :rock => {:fighting=>50, :flying=>200, :ground=>50, :bug=>200,
        :steel=>50, :fire=>200, :ice=>200},
      :bug => {:fighting=>50, :flying=>50, :poison=>50, :ghost=>50,
        :steel=>50, :fire=>50, :grass=>200, :psychic=>200,
        :dark=>200, :fairy=>50},
      :ghost => {:normal=>0, :ghost=>200, :psychic=>200, :dark=>50},
      :steel => {:rock=>200, :steel=>50, :fire=>50, :water=>50,
        :electric=>50, :ice=>200, :fairy=>200},
      :fire => {:rock=>50, :bug=>200, :steel=>200, :fire=>50,
        :water=>50, :grass=>200, :ice=>200, :dragon=>50},
      :water => {:ground=>200, :rock=>200, :fire=>200, :water=>50,
        :grass=>50, :dragon=>50},
      :grass => {:flying=>50, :poison=>50, :ground=>200, :rock=>200,
        :bug=>50, :steel=>50, :fire=>50, :water=>200, :grass=>50,
        :dragon=>50},
      :electric => {:flying=>200, :ground=>0, :water=>200,
        :grass=>50, :electric=>50, :dragon=>50},
      :psychic => {:fighting=>200, :poison=>200, :steel=>50,
        :psychic=>50, :dark=>0},
      :ice => {:flying=>200, :ground=>200, :steel=>50, :fire=>50,
        :water=>50, :grass=>200, :ice=>50, :dragon=>200},
      :dragon => {:steel=>50, :dragon=>200, :fairy=>0},
      :dark => {:fighting=>50, :ghost=>200, :psychic=>200,
        :dark=>50, :fairy=>50},
      :fairy => {:fighting=>200, :poison=>50, :steel=>50, :fire=>50,
        :dragon=>200, :dark=>200}
    }

    # Compatibility aliases. The editable data lives in the separate registry.
    SPECIES_TYPES = ALBERT_CG::POKEMON_COMBAT_DATA::FORM_TYPE_TABLE
    TEST_SKILL_DATA = ALBERT_CG::POKEMON_COMBAT_DATA::SKILL_COMBAT_TABLE


    NORMAL_ATTACK_POWER = 40
    STAB_PERCENT = 150
    CRITICAL_PERCENT = 150
    DEFAULT_ENEMY_LEVEL = 5
    DAMAGE_AUDIT = false
    AUDIT_FILE = "CG_DamageAudit.log"

    def self.type_key(value)
      return value if value.is_a?(Symbol) && TYPE_IDS[value] != nil
      return ID_TYPES[value.to_i] if value.is_a?(Numeric)
      text = value.to_s.downcase.strip
      return TYPE_ALIASES[text]
    end

    def self.type_id(value)
      key = type_key(value)
      return key == nil ? 0 : TYPE_IDS[key].to_i
    end

    def self.pokemon_type_id?(element_id)
      return ID_TYPES[element_id.to_i] != nil
    end

    def self.combat_data
      return ALBERT_CG::POKEMON_COMBAT_DATA
    end

    def self.skill_table_data(object)
      return nil unless object != nil && object.is_a?(RPG::Skill)
      return combat_data.skill_data(object.id)
    rescue
      return nil
    end

    def self.table_type_rate(table, id, attack_type)
      key = type_key(attack_type)
      return 100 if key == nil
      return combat_data.rate_value(table, id, key)
    rescue
      return 100
    end

    def self.parse_type_list(text)
      result = []
      text.to_s.split(/[,，\/\s]+/).each do |token|
        key = type_key(token)
        result.push(key) if key != nil && !result.include?(key)
      end
      return result[0, 2] || []
    end

    def self.note_text(object)
      return "" if object == nil || !object.respond_to?(:note)
      return object.note.to_s
    rescue
      return ""
    end

    def self.note_type_list(object, tag = "pokemon_types")
      text = note_text(object)
      regexp = /<#{tag}\s*:\s*([^>]+)>/i
      return [] unless text =~ regexp
      return parse_type_list($1)
    rescue
      return []
    end

    def self.note_single_type(object, tag)
      list = note_type_list(object, tag)
      return list.empty? ? nil : list[0]
    end

    def self.note_number(object, tag, default_value)
      text = note_text(object)
      regexp = /<#{tag}\s*:\s*(-?\d+)\s*>/i
      return $1.to_i if text =~ regexp
      return default_value
    rescue
      return default_value
    end

    def self.note_damage_class(object)
      text = note_text(object)
      if text =~ /<damage_class\s*:\s*(physical|special|mixed|fixed|status)\s*>/i
        return $1.downcase.to_sym
      end
      return nil
    rescue
      return nil
    end

    def self.type_chart_percent(attack_type, defense_types)
      attack_type = type_key(attack_type)
      return 100 if attack_type == nil
      defense_types = [:normal] if defense_types == nil || defense_types.empty?
      rate = 100
      for defense_type in defense_types[0, 2]
        defense_type = type_key(defense_type)
        next if defense_type == nil
        table = TYPE_CHART[attack_type]
        value = table == nil ? nil : table[defense_type]
        value = 100 if value == nil
        rate = rate * value / 100
      end
      return rate
    end

    def self.effect_text(percent)
      case percent.to_i
      when 0 then return "無效 ×0"
      when 1...50 then return "效果很差 ×0.25"
      when 50...100 then return "效果不佳 ×0.5"
      when 100 then return "效果普通 ×1"
      when 101...400 then return "效果絕佳 ×2"
      else return "四倍弱點 ×4"
      end
    end

    def self.type_names(keys)
      result = []
      for key in keys || []
        name = TYPE_FULL_NAMES[type_key(key)]
        result.push(name) if name != nil
      end
      return result.join("/")
    end

    def self.ensure_system_elements
      return if $data_system == nil
      TYPE_IDS.each do |key, id|
        $data_system.elements.push("") while $data_system.elements.size <= id
        $data_system.elements[id] = TYPE_FULL_NAMES[key]
      end
    end

    def self.append_note(object, line)
      return if object == nil || !object.respond_to?(:note)
      current = object.note.to_s
      return if current.include?(line)
      object.note = current.empty? ? line : current + "\n" + line
    rescue
    end

    def self.apply_test_data
      ensure_system_elements
      # Actor and Class have no Note in RPG Maker VX.
      # Do not mutate them. Skill metadata is read from the central table first.
      if $data_skills != nil
        TEST_SKILL_DATA.each do |skill_id, data|
          skill = $data_skills[skill_id]
          next if skill == nil
          type = data[:type]
          skill.element_set = [TYPE_IDS[type]] if TYPE_IDS[type] != nil
        end
      end
      $data_system.game_title = "CG Pet Battle Prototype v2.0.1" if $data_system != nil
    end

    def self.audit(line)
      return unless DAMAGE_AUDIT
      File.open(AUDIT_FILE, "ab") { |file| file.write(line.to_s + "\r\n") }
    rescue
    end
  end
end

#==============================================================================
# ■ RPG note helpers
#==============================================================================
class RPG::BaseItem
  def cg_pokemon_types_from_note
    return ALBERT_CG::POKEMON_COMBAT.note_type_list(self)
  end

  def cg_pokemon_type_id
    table_data = ALBERT_CG::POKEMON_COMBAT.skill_table_data(self)
    if table_data != nil && table_data[:type] != nil
      return ALBERT_CG::POKEMON_COMBAT.type_id(table_data[:type])
    end
    keys = cg_pokemon_types_from_note
    if keys.empty? && respond_to?(:element_set)
      for id in element_set || []
        return id.to_i if ALBERT_CG::POKEMON_COMBAT.pokemon_type_id?(id)
      end
    end
    return keys.empty? ? 0 : ALBERT_CG::POKEMON_COMBAT.type_id(keys[0])
  end

  def cg_pokemon_power
    table_data = ALBERT_CG::POKEMON_COMBAT.skill_table_data(self)
    return table_data[:power].to_i if table_data != nil && table_data[:power] != nil
    value = ALBERT_CG::POKEMON_COMBAT.note_number(self, "pokemon_power", -1)
    return value if value >= 0
    return [base_damage.to_i.abs * 2, 1].max if respond_to?(:base_damage)
    return ALBERT_CG::POKEMON_COMBAT::NORMAL_ATTACK_POWER
  end

  def cg_pokemon_damage_class
    table_data = ALBERT_CG::POKEMON_COMBAT.skill_table_data(self)
    return table_data[:class] if table_data != nil && table_data[:class] != nil
    result = ALBERT_CG::POKEMON_COMBAT.note_damage_class(self)
    return result if result != nil
    return :status if respond_to?(:base_damage) && base_damage.to_i == 0
    if respond_to?(:physical_attack) && physical_attack
      return :physical
    end
    attack_factor = respond_to?(:atk_f) ? atk_f.to_i : 0
    spirit_factor = respond_to?(:spi_f) ? spi_f.to_i : 0
    return :mixed if attack_factor > 0 && spirit_factor > 0
    return :special if spirit_factor > attack_factor
    return :physical
  end

  def cg_pokemon_can_critical?
    text = ALBERT_CG::POKEMON_COMBAT.note_text(self)
    return false if text =~ /<no_critical>/i
    return false if cg_pokemon_damage_class == :status
    return true
  end
end

#==============================================================================
# ■ Game_Battler type data
#==============================================================================
class Game_Battler
  attr_reader :cg_last_type_rate
  attr_reader :cg_last_damage_breakdown

  def cg_pokemon_level
    return level.to_i if respond_to?(:level)
    return ALBERT_CG::POKEMON_COMBAT::DEFAULT_ENEMY_LEVEL
  rescue
    return ALBERT_CG::POKEMON_COMBAT::DEFAULT_ENEMY_LEVEL
  end

  def cg_pokemon_base_types
    return [:normal]
  end

  def cg_pokemon_types
    override = nil
    for state in states || []
      list = ALBERT_CG::POKEMON_COMBAT.note_type_list(state,
        "pokemon_type_set")
      override = list unless list.empty?
    end
    return override if override != nil
    result = cg_pokemon_base_types
    return result == nil || result.empty? ? [:normal] : result[0, 2]
  rescue
    return [:normal]
  end

  def cg_type_rate_sources
    return states || []
  rescue
    return []
  end

  def cg_intrinsic_type_rate_percent(attack_type)
    return 100
  end

  def cg_note_type_rate(source, attack_type)
    attack_type = ALBERT_CG::POKEMON_COMBAT.type_key(attack_type)
    return 100 if attack_type == nil
    text = ALBERT_CG::POKEMON_COMBAT.note_text(source)
    text.scan(/<type_immunity\s*:\s*([^>]+)>/i) do |match|
      return 0 if ALBERT_CG::POKEMON_COMBAT.parse_type_list(match[0]).include?(attack_type)
    end
    result = 100
    text.scan(/<type_rate\s*:\s*([^,>]+)\s*[,，]\s*(\d+)\s*>/i) do |match|
      key = ALBERT_CG::POKEMON_COMBAT.type_key(match[0])
      result = result * match[1].to_i / 100 if key == attack_type
    end
    return result
  rescue
    return 100
  end

  def cg_pokemon_type_rate_percent(attack_type)
    attack_type = ALBERT_CG::POKEMON_COMBAT.type_key(attack_type)
    return 100 if attack_type == nil
    rate = ALBERT_CG::POKEMON_COMBAT.type_chart_percent(
      attack_type, cg_pokemon_types)
    intrinsic = cg_intrinsic_type_rate_percent(attack_type)
    rate = rate * intrinsic / 100
    for source in cg_type_rate_sources
      modifier = cg_note_type_rate(source, attack_type)
      rate = rate * modifier / 100
      break if rate == 0
    end
    rate = [[rate, 0].max, 800].min
    @cg_last_type_rate = rate
    return rate
  rescue
    @cg_last_type_rate = 100
    return 100
  end

  def cg_basic_attack_type_key
    return :normal
  end

  def cg_basic_attack_type_id
    return ALBERT_CG::POKEMON_COMBAT.type_id(cg_basic_attack_type_key)
  end

  def cg_basic_attack_power
    return ALBERT_CG::POKEMON_COMBAT::NORMAL_ATTACK_POWER
  end

  def cg_stab_percent(type_id)
    type_key = ALBERT_CG::POKEMON_COMBAT.type_key(type_id)
    return 100 if type_key == nil
    return cg_pokemon_types.include?(type_key) ?
      ALBERT_CG::POKEMON_COMBAT::STAB_PERCENT : 100
  rescue
    return 100
  end

  def cg_special_defense
    return [((spi.to_i * 3 + self.def.to_i) / 4), 1].max
  end

  def cg_damage_class_stats(user, damage_class)
    case damage_class
    when :physical
      return [[user.atk.to_i, 1].max, [self.def.to_i, 1].max]
    when :special
      return [[user.spi.to_i, 1].max, cg_special_defense]
    when :mixed
      attack = (user.atk.to_i + user.spi.to_i) / 2
      defense = (self.def.to_i + cg_special_defense) / 2
      return [[attack, 1].max, [defense, 1].max]
    end
    return [1, 1]
  end

  def cg_pokemon_formula(level, power, attack, defense)
    level = [level.to_i, 1].max
    power = [power.to_i, 1].max
    attack = [attack.to_i, 1].max
    defense = [defense.to_i, 1].max
    value = (((((2.0 * level / 5.0) + 2.0) * power * attack / defense) /
      50.0) + 2.0)
    return [value.to_i, 1].max
  end

  def cg_apply_pokemon_random(damage, variance)
    variance = [[variance.to_i, 0].max, 30].min
    return damage if variance <= 0
    minimum = 100 - variance
    percent = minimum + rand(variance + 1)
    return damage * percent / 100
  end

  def cg_skill_level_percent(user, obj)
    return 100 unless user != nil && user.actor? && obj.is_a?(RPG::Skill)
    return 100 unless user.respond_to?(:cg_skill_level)
    return 100 unless defined?(ALBERT_CG) && ALBERT_CG.respond_to?(:skill_power_rate)
    level = user.cg_skill_level(obj.id)
    return ALBERT_CG.skill_power_rate(level, obj.id).to_i
  rescue
    return 100
  end

  def cg_pokemon_critical?(user, obj = nil)
    return false if user == nil
    return false if obj != nil && obj.respond_to?(:cg_pokemon_can_critical?) &&
      !obj.cg_pokemon_can_critical?
    return rand(100) < user.cri.to_i
  rescue
    return false
  end

  def cg_apply_dual_wield(user, damage, skill_mode)
    return damage unless user != nil && user.actor?
    return damage unless user.respond_to?(:weapons)
    weapons = user.weapons
    return damage if weapons == nil || weapons[0] == nil || weapons[1] == nil
    return damage unless defined?(N01) && N01.const_defined?(:TWO_SWORDS_STYLE)
    index = skill_mode ? 1 : 0
    return damage * N01::TWO_SWORDS_STYLE[index].to_i / 100
  rescue
    return damage
  end

  # Final Pokemon-style normal attack formula.
  def make_attack_damage_value(attacker)
    type_id = attacker.cg_basic_attack_type_id
    type_rate = cg_pokemon_type_rate_percent(type_id)
    attack, defense = cg_damage_class_stats(attacker, :physical)
    damage = cg_pokemon_formula(attacker.cg_pokemon_level,
      attacker.cg_basic_attack_power, attack, defense)
    stab = attacker.cg_stab_percent(type_id)
    damage = damage * stab / 100
    damage = damage * type_rate / 100
    @critical = type_rate > 0 && cg_pokemon_critical?(attacker)
    damage = damage * ALBERT_CG::POKEMON_COMBAT::CRITICAL_PERCENT / 100 if @critical
    damage = cg_apply_pokemon_random(damage, 15)
    damage = cg_apply_dual_wield(attacker, damage, false)
    damage = apply_guard(damage)
    damage = 1 if type_rate > 0 && damage < 1
    damage = 0 if type_rate == 0
    @hp_damage = damage
    @cg_last_damage_breakdown = {
      :kind=>:attack, :type_id=>type_id, :type_rate=>type_rate,
      :stab=>stab, :critical=>@critical, :power=>attacker.cg_basic_attack_power,
      :attack=>attack, :defense=>defense, :damage=>damage
    }
    ALBERT_CG::POKEMON_COMBAT.audit(
      "ATTACK #{attacker.name} -> #{name}: #{@cg_last_damage_breakdown.inspect}")
  end

  alias albert_cg_v200_original_make_obj_damage_value make_obj_damage_value
  def make_obj_damage_value(user, obj)
    unless obj.is_a?(RPG::Skill) && obj.base_damage.to_i > 0
      return albert_cg_v200_original_make_obj_damage_value(user, obj)
    end

    damage_class = obj.cg_pokemon_damage_class
    if damage_class == :fixed
      damage = obj.base_damage.to_i
      attack = 0
      defense = 0
    else
      attack, defense = cg_damage_class_stats(user, damage_class)
      defense = 1 if obj.ignore_defense
      damage = cg_pokemon_formula(user.cg_pokemon_level,
        obj.cg_pokemon_power, attack, defense)
    end

    type_id = obj.cg_pokemon_type_id
    if type_id <= 0 && obj.physical_attack
      type_id = ALBERT_CG::POKEMON_COMBAT::TYPE_IDS[:normal]
    end
    type_rate = type_id <= 0 ? 100 : cg_pokemon_type_rate_percent(type_id)
    stab = type_id <= 0 ? 100 : user.cg_stab_percent(type_id)
    damage = damage * cg_skill_level_percent(user, obj) / 100
    damage = damage * stab / 100
    damage = damage * type_rate / 100
    @critical = type_rate > 0 && cg_pokemon_critical?(user, obj)
    damage = damage * ALBERT_CG::POKEMON_COMBAT::CRITICAL_PERCENT / 100 if @critical
    damage = cg_apply_pokemon_random(damage, obj.variance)
    damage = cg_apply_dual_wield(user, damage, true)
    damage = apply_guard(damage)
    damage = 1 if type_rate > 0 && damage < 1
    damage = 0 if type_rate == 0

    if obj.damage_to_mp
      @mp_damage = damage
      @hp_damage = 0
    else
      @hp_damage = damage
      @mp_damage = 0
    end
    @cg_last_damage_breakdown = {
      :kind=>:skill, :skill_id=>obj.id, :class=>damage_class,
      :type_id=>type_id, :type_rate=>type_rate, :stab=>stab,
      :critical=>@critical, :power=>obj.cg_pokemon_power,
      :attack=>attack, :defense=>defense, :damage=>damage
    }
    ALBERT_CG::POKEMON_COMBAT.audit(
      "SKILL #{user.name}/#{obj.name} -> #{name}: #{@cg_last_damage_breakdown.inspect}")
  end
end

#==============================================================================
# ■ Game_Actor / Game_Enemy final element authority
#==============================================================================
class Game_Actor < Game_Battler
  alias albert_cg_v201_original_actor_element_rate element_rate
  def element_rate(element_id)
    if ALBERT_CG::POKEMON_COMBAT.pokemon_type_id?(element_id)
      return cg_pokemon_type_rate_percent(element_id)
    end
    return albert_cg_v201_original_actor_element_rate(element_id)
  end

  def cg_form_actor_id
    if respond_to?(:cg_current_form_actor_id)
      value = cg_current_form_actor_id.to_i
      return value if value > 0
    end
    if respond_to?(:cg_species_id)
      value = cg_species_id.to_i
      return value if value > 0
    end
    return id.to_i
  rescue
    return id.to_i
  end

  def cg_class_id_value
    return class_id.to_i if respond_to?(:class_id)
    return (@class_id || 0).to_i
  rescue
    return 0
  end

  def cg_pokemon_base_types
    data = ALBERT_CG::POKEMON_COMBAT_DATA
    is_pet = respond_to?(:cg_battle_pet?) && cg_battle_pet?
    if is_pet
      result = data.form_types(cg_form_actor_id)
      if result == nil && respond_to?(:cg_species_id)
        result = data.form_types(cg_species_id.to_i)
      end
      return result == nil || result.empty? ? [:normal] : result
    end
    result = data.actor_types(id.to_i, cg_class_id_value)
    return result == nil || result.empty? ? [:normal] : result
  rescue
    return [:normal]
  end

  def cg_intrinsic_type_rate_percent(attack_type)
    data = ALBERT_CG::POKEMON_COMBAT_DATA
    key = ALBERT_CG::POKEMON_COMBAT.type_key(attack_type)
    return 100 if key == nil
    rate = 100
    rate = rate * data.rate_value(ALBERT_CG::POKEMON_COMBAT_DATA::ACTOR_TYPE_RATE_TABLE, id, key) / 100
    rate = rate * data.rate_value(ALBERT_CG::POKEMON_COMBAT_DATA::CLASS_TYPE_RATE_TABLE,
      cg_class_id_value, key) / 100
    if respond_to?(:cg_battle_pet?) && cg_battle_pet?
      rate = rate * data.rate_value(ALBERT_CG::POKEMON_COMBAT_DATA::FORM_TYPE_RATE_TABLE,
        cg_form_actor_id, key) / 100
    end
    return rate
  rescue
    return 100
  end

  # Actor and Class are intentionally excluded because VX gives them no Note.
  def cg_type_rate_sources
    result = []
    for item in equips || []
      result.push(item) if item != nil
    end
    for state in states || []
      result.push(state) if state != nil
    end
    return result
  rescue
    return states || []
  end

  def cg_basic_attack_table_data
    data = ALBERT_CG::POKEMON_COMBAT_DATA
    if respond_to?(:cg_battle_pet?) && cg_battle_pet?
      value = data.basic_attack_data(:form, cg_form_actor_id)
      return value if value != nil
    end
    value = data.basic_attack_data(:actor, id)
    return value if value != nil
    return data.basic_attack_data(:class, cg_class_id_value)
  rescue
    return nil
  end

  def cg_basic_attack_type_key
    for weapon in weapons || []
      next if weapon == nil
      key = ALBERT_CG::POKEMON_COMBAT.note_single_type(weapon,
        "basic_attack_type")
      return key if key != nil
      for element_id in weapon.element_set || []
        key = ALBERT_CG::POKEMON_COMBAT.type_key(element_id)
        return key if key != nil
      end
    end
    data = cg_basic_attack_table_data
    key = data == nil ? nil : ALBERT_CG::POKEMON_COMBAT.type_key(data[:type])
    return key == nil ? :normal : key
  rescue
    return :normal
  end

  def cg_basic_attack_power
    for weapon in weapons || []
      next if weapon == nil
      value = ALBERT_CG::POKEMON_COMBAT.note_number(weapon,
        "basic_attack_power", -1)
      return value if value > 0
    end
    data = cg_basic_attack_table_data
    value = data == nil ? 0 : data[:power].to_i
    return value > 0 ? value : ALBERT_CG::POKEMON_COMBAT::NORMAL_ATTACK_POWER
  rescue
    return ALBERT_CG::POKEMON_COMBAT::NORMAL_ATTACK_POWER
  end

  def element_set
    return [cg_basic_attack_type_id]
  end
end

class Game_Enemy < Game_Battler
  alias albert_cg_v201_original_enemy_element_rate element_rate
  def element_rate(element_id)
    if ALBERT_CG::POKEMON_COMBAT.pokemon_type_id?(element_id)
      return cg_pokemon_type_rate_percent(element_id)
    end
    return albert_cg_v201_original_enemy_element_rate(element_id)
  end

  def cg_enemy_form_id
    data = ALBERT_CG::POKEMON_COMBAT_DATA
    form_id = data.enemy_form_id(@enemy_id)
    if (form_id == nil || form_id.to_i <= 0) &&
       respond_to?(:cg_capture_species_id)
      form_id = cg_capture_species_id.to_i
    end
    return form_id.to_i
  rescue
    return 0
  end

  def cg_pokemon_level
    data = ALBERT_CG::POKEMON_COMBAT_DATA
    value = ALBERT_CG::POKEMON_COMBAT_DATA::ENEMY_LEVEL_TABLE[@enemy_id.to_i]
    return value.to_i if value != nil && value.to_i > 0
    return ALBERT_CG::POKEMON_COMBAT.note_number(enemy,
      "pokemon_level", ALBERT_CG::POKEMON_COMBAT::DEFAULT_ENEMY_LEVEL)
  rescue
    return ALBERT_CG::POKEMON_COMBAT::DEFAULT_ENEMY_LEVEL
  end

  def cg_pokemon_base_types
    data = ALBERT_CG::POKEMON_COMBAT_DATA
    result = data.enemy_types(@enemy_id)
    return result unless result == nil || result.empty?
    result = data.form_types(cg_enemy_form_id)
    return result unless result == nil || result.empty?
    note_types = ALBERT_CG::POKEMON_COMBAT.note_type_list(enemy)
    return note_types unless note_types.empty?
    return [:normal]
  rescue
    return [:normal]
  end

  def cg_intrinsic_type_rate_percent(attack_type)
    data = ALBERT_CG::POKEMON_COMBAT_DATA
    key = ALBERT_CG::POKEMON_COMBAT.type_key(attack_type)
    return 100 if key == nil
    rate = data.rate_value(ALBERT_CG::POKEMON_COMBAT_DATA::ENEMY_TYPE_RATE_TABLE, @enemy_id, key)
    form_id = cg_enemy_form_id
    rate = rate * data.rate_value(ALBERT_CG::POKEMON_COMBAT_DATA::FORM_TYPE_RATE_TABLE,
      form_id, key) / 100 if form_id > 0
    return rate
  rescue
    return 100
  end

  def cg_type_rate_sources
    result = []
    result.push(enemy) if enemy != nil
    for state in states || []
      result.push(state) if state != nil
    end
    return result
  rescue
    return states || []
  end

  def cg_basic_attack_table_data
    return ALBERT_CG::POKEMON_COMBAT_DATA.basic_attack_data(:enemy, @enemy_id)
  rescue
    return nil
  end

  def cg_basic_attack_type_key
    data = cg_basic_attack_table_data
    key = data == nil ? nil : ALBERT_CG::POKEMON_COMBAT.type_key(data[:type])
    return key if key != nil
    key = ALBERT_CG::POKEMON_COMBAT.note_single_type(enemy,
      "basic_attack_type")
    return key == nil ? :normal : key
  rescue
    return :normal
  end

  def cg_basic_attack_power
    data = cg_basic_attack_table_data
    value = data == nil ? 0 : data[:power].to_i
    return value if value > 0
    value = ALBERT_CG::POKEMON_COMBAT.note_number(enemy,
      "basic_attack_power", -1)
    return value > 0 ? value : ALBERT_CG::POKEMON_COMBAT::NORMAL_ATTACK_POWER
  rescue
    return ALBERT_CG::POKEMON_COMBAT::NORMAL_ATTACK_POWER
  end

  def element_set
    return [cg_basic_attack_type_id]
  end
end

# Final authority for any older script still calling elements_max_rate.
class Game_Battler
  def elements_max_rate(element_set, attacker = nil)
    return 100 if element_set == nil || element_set.empty?
    rates = []
    for element_id in element_set
      if ALBERT_CG::POKEMON_COMBAT.pokemon_type_id?(element_id)
        rates.push(cg_pokemon_type_rate_percent(element_id))
      else
        rates.push(element_rate(element_id))
      end
    end
    return rates.empty? ? 100 : rates.max
  rescue
    return 100
  end
end

#==============================================================================
# ■ Existing CG UI now reads formal combat types
#==============================================================================
module ALBERT_CG
  def self.cg_ui_type_keys(battler)
    return [] if battler == nil
    return battler.cg_pokemon_types if battler.respond_to?(:cg_pokemon_types)
    return []
  rescue
    return []
  end
end

class Scene_Battle < Scene_Base
  alias albert_cg_v200_type_help_text cg_target_help_text
  def cg_target_help_text(enemy)
    text = albert_cg_v200_type_help_text(enemy)
    return text if enemy == nil
    type_keys = enemy.respond_to?(:cg_pokemon_types) ?
      enemy.cg_pokemon_types : []
    type_text = ALBERT_CG::POKEMON_COMBAT.type_names(type_keys)
    text += "　" + type_text unless type_text.empty? || text.include?(type_text)

    type_id = cg_v200_preview_type_id
    capture_mode = defined?(@cg_capture_target_mode) && @cg_capture_target_mode
    if !capture_mode && type_id > 0 && enemy.respond_to?(:cg_pokemon_type_rate_percent)
      rate = enemy.cg_pokemon_type_rate_percent(type_id)
      text += "　" + ALBERT_CG::POKEMON_COMBAT.effect_text(rate)
    end
    return text
  rescue
    return text == nil ? "" : text
  end

  def cg_v200_preview_type_id
    return 0 if @active_battler == nil || @active_battler.action == nil
    action = @active_battler.action
    if action.kind == 0 && action.basic == 0
      return @active_battler.cg_basic_attack_type_id
    elsif action.kind == 1
      skill = action.skill
      return skill == nil ? 0 : skill.cg_pokemon_type_id
    elsif action.kind == 2
      item = action.item
      return item == nil ? 0 : item.cg_pokemon_type_id
    end
    return 0
  rescue
    return 0
  end
end

#==============================================================================
# ■ Database setup and interpreter tests
#==============================================================================
class Scene_Title < Scene_Base
  alias albert_cg_v200_type_load_database load_database
  def load_database
    albert_cg_v200_type_load_database
    ALBERT_CG::POKEMON_COMBAT.apply_test_data
  end

  alias albert_cg_v200_type_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v200_type_load_bt_database
    ALBERT_CG::POKEMON_COMBAT.apply_test_data
  end
end

class Game_Interpreter
  # Prints a compact chart test to the game console/message box.
  def cg_test_pokemon_types
    tests = [
      [:fire, [:grass, :steel], 400],
      [:ground, [:flying, :electric], 0],
      [:ice, [:water, :flying], 100],
      [:normal, [:ghost], 0],
      [:water, [:fire], 200]
    ]
    result = []
    for test in tests
      actual = ALBERT_CG::POKEMON_COMBAT.type_chart_percent(test[0], test[1])
      result.push(test[0].to_s + "=>" + test[1].inspect + ":" +
        actual.to_s + (actual == test[2] ? " OK" : " NG"))
    end
    p result
    return result
  end

  # Confirms the note-free Actor/Class registry and current-form lookup.
  def cg_test_combat_registry
    data = ALBERT_CG::POKEMON_COMBAT_DATA
    result = {
      :actor_1 => data.actor_types(1, 1),
      :form_100 => data.form_types(100),
      :form_105 => data.form_types(105),
      :enemy_600_form => data.enemy_form_id(600),
      :skill_608 => data.skill_data(608)
    }
    p result
    return result
  end
end
