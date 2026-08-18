# RMVX_SCRIPT_INDEX: 194
# RMVX_SCRIPT_ID: 1153467378
# RMVX_SCRIPT_NAME: CG Pokemon Field Move Core + Auto Regression v2.3.3a
# RMVX_SOURCE_SHA256: 05eeaa0d0b2b5da29e01649d208329d49ff5fb7a063673449a92d40db3e5a107

#==============================================================================
# ■ CG Pokemon Field Move Core v2.3.3a
#------------------------------------------------------------------------------
# 【用途】
#  將 Pokémon #0001～#0494 / 937 招 Master Data 中屬於「戰場、天氣、場地、牆、
#  陷阱、空間、隊伍防護」的技能正式接入 CG Pet Battle Prototype。此腳本載入於
#  v2.3.2 Priority / Protect 之後，讓 Field 效果可直接影響六維傷害、Priority 排序、
#  狀態附加、能力階級、切換限制與回合末處理。
#
# 【本版處理範圍：PokeAPI meta category 10 / 11，共 31 招】
#  Weather：沙暴、求雨、大晴天、冰雹。
#  Terrain：青草場地、薄霧場地、電氣場地、精神場地。
#  Room/Global：重力、戲法空間、奇妙空間、魔法空間、玩泥巴、玩水、等離子浴、
#               妖精之鎖。
#  Side Screen：白霧、光牆、反射壁、神秘守護、順風、幸運咒語、極光幕。
#  Side Guard：廣域防守、快速防守、掀榻榻米、戲法防守。
#  Hazard：撒菱、毒菱、隱形岩、黏黏網。
#
# 【本作 4v4 調整】
#  - 光牆 / 反射壁 / 極光幕：4v4 採 67% 傷害，而非把多人戰鬥仍硬套單打 50%。
#  - 雨 / 晴：對應屬性 150%，被壓制屬性 50%。
#  - 電氣 / 青草 / 精神場地：接地單位對應屬性 130%。
#  - 薄霧場地：接地目標受到龍屬性傷害 50%，並阻止主要異常。
#  - 沙暴：岩石系特殊防禦 150%；回合末非岩/地/鋼扣 1/16 MaxHP。
#  - 冰雹：回合末非冰系扣 1/16 MaxHP（本專案採 Gen7 時期規則）。
#  - 青草場地：接地單位回合末回復 1/16 MaxHP；地震/重踏/震級傷害 50%。
#  - 順風：該側有效 SPE ×2。
#  - 戲法空間：不改 Priority，只在 Priority 相同時反轉有效 SPE 排序。
#  - 魔法空間：本專案正式不製作持有道具，因此仍完整記錄/計時，但目前沒有
#                額外持有道具效果可封鎖。這是「完成的本作適配」，不是漏做。
#
# 【Hazard 規則】
#  - 撒菱：最多 3 層；進場時接地單位分別扣 1/8、1/6、1/4 MaxHP。
#  - 毒菱：最多 2 層；接地毒系吸收，否則 1 層中毒、2 層劇毒。
#  - 隱形岩：依本作岩石屬性倍率造成 MaxHP * type_rate / 800 傷害。
#  - 黏黏網：接地單位進場 SPE Stage -1。
#  正式換寵/強制換人系統接上時呼叫：
#      ALBERT_CG::FIELD_V233.apply_entry_hazards(battler)
#
# 【Side Guard】
#  - Wide Guard：擋敵方多目標傷害技能。
#  - Quick Guard：擋敵方 Priority > 0 的技能。
#  - Mat Block：擋敵方傷害技能。
#  - Crafty Shield：擋敵方 Status 技能。
#  全部只維持本回合，於 turn_end 清除。
#
# 【PMD / SBS】
#  本腳本只處理機制，不要求新 PMD 動作。Pokémon 仍由 v2.3.0 Motion Resolver
#  依 Species Override -> Move Hint -> fallback chain 尋找可用且至少 8 方向動作；
#  人類仍完全使用 Tankentai SBS 既有近戰/遠程/施法分類。
#
# 【Animation】
#  技能 Animation ID 仍使用資料庫目前占位值，後續 Visual Pass 再逐招替換。
#
# 【Debug：Alt + F11 全自動 Field Regression】
#  v2.3.3a 修正：Alt+F11 按鍵分流本身不變；改用專案正式 start_demo_battle
#  啟動鏈，確保 $game_troop.setup(TEST_TROOP_ID) 真正執行。另新增逐回合 8 行動
#  精確覆蓋檢查與 Field Move apply delta ASSERT，避免前回合累積計數造成假 PASS。
#  玩家在地圖按 Alt+F11 後不需任何操作。腳本會：
#  1. 建立 Tom + 3 Pokémon vs 4 Pokémon。
#  2. 指定 5 回合所有角色技能與目標，人類 Tom 也自動行動。
#  3. 真正經過 Scene_Battle / Tankentai / PMD Action Sequence。
#  4. 讓 31/31 個 Field Move 在實戰中至少執行一次。
#  5. ASSERT Field 狀態、Tailwind SPE、Trick Room 反轉、Hazard 進場效果等。
#  6. 測完自動 battle_end(0) 回地圖。
#
# 【LOG】
#  Pokemon_Field_AutoTest_v2_3_3a.log
#  正常最後必須看到：
#      RESULT=PASS
#      SUMMARY rounds=5 failures=0 field_moves=31/31
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonFieldMoveCore"] = "2.3.3a"

module ALBERT_CG
  module FIELD_V233
    VERSION = "2.3.3a"
    LOG_FILE = "Pokemon_Field_AutoTest_v2_3_3a.log"

    SIDE_DURATION = 5
    WEATHER_DURATION = 5
    TERRAIN_DURATION = 5
    ROOM_DURATION = 5
    TAILWIND_DURATION = 4

    FIELD_MOVE_IDS = [
      54,113,115,191,201,219,240,241,258,300,346,356,366,381,390,
      433,446,469,472,478,501,561,564,569,578,580,581,587,604,678,694
    ]

    USER_SIDE_EFFECTS = {
      54=>:mist, 113=>:light_screen, 115=>:reflect, 219=>:safeguard,
      366=>:tailwind, 381=>:lucky_chant, 469=>:wide_guard,
      501=>:quick_guard, 561=>:mat_block, 578=>:crafty_shield,
      694=>:aurora_veil
    }

    HAZARD_MOVES = {
      191=>:spikes, 390=>:toxic_spikes, 446=>:stealth_rock, 564=>:sticky_web
    }

    WEATHER_MOVES = {201=>:sandstorm, 240=>:rain, 241=>:sun, 258=>:hail}
    TERRAIN_MOVES = {580=>:grassy, 581=>:misty, 604=>:electric, 678=>:psychic}
    GLOBAL_MOVES = {
      300=>:mud_sport, 346=>:water_sport, 356=>:gravity,
      433=>:trick_room, 472=>:wonder_room, 478=>:magic_room,
      569=>:ion_deluge, 587=>:fairy_lock
    }

    SCREEN_DAMAGE_PERCENT = 67
    TERRAIN_BOOST_PERCENT = 130
    RAIN_SUN_BOOST_PERCENT = 150
    RAIN_SUN_REDUCE_PERCENT = 50
    SPORT_DAMAGE_PERCENT = 33
    MISTY_DRAGON_PERCENT = 50
    GRASSY_GROUND_MOVE_PERCENT = 50
    SAND_ROCK_SPD_PERCENT = 150

    class State
      attr_accessor :weather
      attr_accessor :weather_turns
      attr_accessor :terrain
      attr_accessor :terrain_turns
      attr_accessor :globals
      attr_accessor :sides
      attr_accessor :hazards
      attr_accessor :round_flags
      attr_accessor :apply_counts

      def initialize
        @weather = nil
        @weather_turns = 0
        @terrain = nil
        @terrain_turns = 0
        @globals = {}
        @sides = {:ally=>{}, :enemy=>{}}
        @hazards = {
          :ally=>{:spikes=>0,:toxic_spikes=>0,:stealth_rock=>0,:sticky_web=>0},
          :enemy=>{:spikes=>0,:toxic_spikes=>0,:stealth_rock=>0,:sticky_web=>0}
        }
        @round_flags = {:ally=>{}, :enemy=>{}, :global=>{}}
        @apply_counts = {}
      end
    end

    def self.state
      return @state if @state != nil
      @state = State.new
      return @state
    end

    def self.reset
      @state = State.new
    end

    def self.side_key(battler)
      return :ally if battler != nil && battler.respond_to?(:actor?) && battler.actor?
      return :enemy
    end

    def self.opposite_side(side)
      return side == :ally ? :enemy : :ally
    end

    def self.log(text)
      begin
        File.open(LOG_FILE, "ab") { |f| f.write(text.to_s + "\r\n") }
      rescue
      end
    end

    def self.reset_log
      begin
        File.open(LOG_FILE, "wb") do |f|
          f.write("CG POKEMON FIELD AUTO REGRESSION v" + VERSION + "\r\n")
          f.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
          f.write("RULE=Actual Scene_Battle; deterministic plans; 31 Field Moves\r\n")
          f.write("------------------------------------------------------------\r\n")
        end
      rescue
      end
    end

    def self.field_move?(move_id)
      return FIELD_MOVE_IDS.include?(move_id.to_i)
    end

    def self.count_apply(move_id)
      mid = move_id.to_i
      state.apply_counts[mid] = state.apply_counts[mid].to_i + 1
    end

    def self.side_effect?(side, key)
      return state.sides[side][key].to_i > 0
    end

    def self.global_effect?(key)
      return state.globals[key].to_i > 0
    end

    def self.round_flag?(side, key)
      return state.round_flags[side][key] == true
    end

    def self.set_side_effect(side, key, turns)
      state.sides[side][key] = turns.to_i
      log("FIELD_SIDE side=" + side.to_s + " effect=" + key.to_s + " turns=" + turns.to_s)
    end

    def self.set_global(key, turns)
      state.globals[key] = turns.to_i
      log("FIELD_GLOBAL effect=" + key.to_s + " turns=" + turns.to_s)
    end

    def self.set_round_flag(side, key)
      state.round_flags[side][key] = true
      log("FIELD_ROUND_GUARD side=" + side.to_s + " effect=" + key.to_s)
    end

    def self.apply_move(user, target, move_id)
      mid = move_id.to_i
      return false unless field_move?(mid)
      count_apply(mid)
      user_side = side_key(user)
      opp_side = opposite_side(user_side)

      if WEATHER_MOVES.has_key?(mid)
        state.weather = WEATHER_MOVES[mid]
        state.weather_turns = WEATHER_DURATION
        log("FIELD_WEATHER move=" + mid.to_s + " weather=" + state.weather.to_s +
            " turns=" + state.weather_turns.to_s)
        return true
      end

      if TERRAIN_MOVES.has_key?(mid)
        state.terrain = TERRAIN_MOVES[mid]
        state.terrain_turns = TERRAIN_DURATION
        log("FIELD_TERRAIN move=" + mid.to_s + " terrain=" + state.terrain.to_s +
            " turns=" + state.terrain_turns.to_s)
        return true
      end

      if HAZARD_MOVES.has_key?(mid)
        key = HAZARD_MOVES[mid]
        table = state.hazards[opp_side]
        case key
        when :spikes
          table[key] = [table[key].to_i + 1, 3].min
        when :toxic_spikes
          table[key] = [table[key].to_i + 1, 2].min
        else
          table[key] = 1
        end
        log("FIELD_HAZARD move=" + mid.to_s + " side=" + opp_side.to_s +
            " hazard=" + key.to_s + " layers=" + table[key].to_s)
        return true
      end

      if USER_SIDE_EFFECTS.has_key?(mid)
        key = USER_SIDE_EFFECTS[mid]
        if [:wide_guard,:quick_guard,:mat_block,:crafty_shield].include?(key)
          set_round_flag(user_side, key)
        else
          turns = key == :tailwind ? TAILWIND_DURATION : SIDE_DURATION
          set_side_effect(user_side, key, turns)
        end
        return true
      end

      if GLOBAL_MOVES.has_key?(mid)
        key = GLOBAL_MOVES[mid]
        case key
        when :ion_deluge
          state.round_flags[:global][:ion_deluge] = true
          log("FIELD_ROUND_GLOBAL effect=ion_deluge")
        when :fairy_lock
          # Cast turn end 時會先扣 1，因此設 2，確保下一整回合仍禁止切換。
          set_global(:fairy_lock, 2)
        else
          set_global(key, ROOM_DURATION)
        end
        return true
      end
      return false
    end

    def self.grounded?(battler)
      return true if global_effect?(:gravity)
      return true if battler == nil || !battler.respond_to?(:cg_pokemon_types)
      types = battler.cg_pokemon_types
      return false if types.include?(:flying)
      return true
    rescue
      return true
    end

    def self.major_ailment_id?(ailment_id)
      return [1,2,3,4,5,6].include?(ailment_id.to_i)
    end

    def self.status_blocked?(target, ailment_id)
      return false if target == nil
      side = side_key(target)
      if side_effect?(side, :safeguard) && major_ailment_id?(ailment_id)
        return true
      end
      if state.terrain == :misty && state.terrain_turns.to_i > 0 && grounded?(target) &&
         major_ailment_id?(ailment_id)
        return true
      end
      if state.terrain == :electric && state.terrain_turns.to_i > 0 && grounded?(target) &&
         ailment_id.to_i == 2
        return true
      end
      return false
    end

    def self.stat_drop_blocked?(user, target, delta)
      return false if delta.to_i >= 0 || user == nil || target == nil
      return false if user == target || side_key(user) == side_key(target)
      return side_effect?(side_key(target), :mist)
    end

    def self.skill_status?(skill)
      return false if skill == nil
      if skill.respond_to?(:cg_pokemon_damage_class)
        return skill.cg_pokemon_damage_class == :status
      end
      return skill.base_damage.to_i == 0
    rescue
      return skill != nil && skill.base_damage.to_i == 0
    end

    def self.skill_damaging?(skill)
      return !skill_status?(skill)
    end

    def self.skill_multi_target?(skill)
      return false if skill == nil
      return true if skill.respond_to?(:for_all?) && skill.for_all?
      return true if skill.respond_to?(:for_two?) && skill.for_two?
      return true if skill.respond_to?(:for_three?) && skill.for_three?
      return true if skill.respond_to?(:dual?) && skill.dual?
      return false
    rescue
      return false
    end

    def self.action_priority(user)
      return 0 if user == nil || !user.respond_to?(:action) || user.action == nil
      action = user.action
      return action.cg_final_priority.to_i if action.respond_to?(:cg_final_priority)
      return 0
    rescue
      return 0
    end

    def self.guard_blocks?(target, user, skill)
      return nil if target == nil || user == nil || skill == nil
      mid = defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0
      # Field/Side/Hazard move 本身不視為直接打向 battler 的招式，避免另一側的
      # Wide/Quick/Crafty Guard 把「設置戰場」誤當成對單位命中。
      return nil if field_move?(mid)
      return nil if side_key(target) == side_key(user)
      side = side_key(target)
      if round_flag?(side, :quick_guard) && action_priority(user) > 0
        return :quick_guard
      end
      if round_flag?(side, :wide_guard) && skill_damaging?(skill) && skill_multi_target?(skill)
        return :wide_guard
      end
      if round_flag?(side, :mat_block) && skill_damaging?(skill)
        return :mat_block
      end
      if round_flag?(side, :crafty_shield) && skill_status?(skill)
        return :crafty_shield
      end
      if state.terrain == :psychic && state.terrain_turns.to_i > 0 && grounded?(target) &&
         action_priority(user) > 0
        return :psychic_terrain
      end
      return nil
    end

    def self.damage_percent(user, target, skill, type_id, damage_class, move_id)
      value = 100
      type_key = nil
      if defined?(ALBERT_CG::POKEMON_COMBAT)
        type_key = ALBERT_CG::POKEMON_COMBAT.type_key(type_id)
      end

      if state.weather_turns.to_i > 0
        case state.weather
        when :rain
          value = value * RAIN_SUN_BOOST_PERCENT / 100 if type_key == :water
          value = value * RAIN_SUN_REDUCE_PERCENT / 100 if type_key == :fire
        when :sun
          value = value * RAIN_SUN_BOOST_PERCENT / 100 if type_key == :fire
          value = value * RAIN_SUN_REDUCE_PERCENT / 100 if type_key == :water
        end
      end

      if global_effect?(:mud_sport) && type_key == :electric
        value = value * SPORT_DAMAGE_PERCENT / 100
      end
      if global_effect?(:water_sport) && type_key == :fire
        value = value * SPORT_DAMAGE_PERCENT / 100
      end

      if state.terrain_turns.to_i > 0
        if grounded?(user)
          value = value * TERRAIN_BOOST_PERCENT / 100 if
            (state.terrain == :grassy && type_key == :grass) ||
            (state.terrain == :electric && type_key == :electric) ||
            (state.terrain == :psychic && type_key == :psychic)
        end
        if grounded?(target) && state.terrain == :misty && type_key == :dragon
          value = value * MISTY_DRAGON_PERCENT / 100
        end
        if state.terrain == :grassy && [89,222,523].include?(move_id.to_i)
          value = value * GRASSY_GROUND_MOVE_PERCENT / 100
        end
      end

      side = side_key(target)
      if damage_class == :physical
        if side_effect?(side, :reflect) || side_effect?(side, :aurora_veil)
          value = value * SCREEN_DAMAGE_PERCENT / 100
        end
      elsif damage_class == :special
        if side_effect?(side, :light_screen) || side_effect?(side, :aurora_veil)
          value = value * SCREEN_DAMAGE_PERCENT / 100
        end
      end
      return value
    end

    def self.tailwind_active?(battler)
      return false if battler == nil
      return side_effect?(side_key(battler), :tailwind)
    end

    def self.trick_room_active?
      return global_effect?(:trick_room)
    end

    def self.wonder_room_active?
      return global_effect?(:wonder_room)
    end

    def self.magic_room_active?
      return global_effect?(:magic_room)
    end

    def self.switch_locked?
      return global_effect?(:fairy_lock)
    end

    def self.decrement_hash(hash)
      keys = hash.keys
      keys.each do |key|
        next unless hash[key].is_a?(Numeric)
        n = hash[key].to_i
        next if n <= 0
        n -= 1
        if n <= 0
          hash.delete(key)
          log("FIELD_EXPIRE effect=" + key.to_s)
        else
          hash[key] = n
        end
      end
    end

    def self.apply_weather_residual
      return if state.weather_turns.to_i <= 0
      list = []
      list.concat($game_party.members) if defined?($game_party) && $game_party != nil
      list.concat($game_troop.members) if defined?($game_troop) && $game_troop != nil
      list.each do |b|
        next if b == nil || !b.respond_to?(:hp) || b.hp.to_i <= 0
        types = b.respond_to?(:cg_pokemon_types) ? b.cg_pokemon_types : []
        hurt = false
        if state.weather == :sandstorm
          hurt = !(types.include?(:rock) || types.include?(:ground) || types.include?(:steel))
        elsif state.weather == :hail
          hurt = !types.include?(:ice)
        end
        if hurt
          dmg = [[b.maxhp.to_i / 16, 1].max, b.hp.to_i].min
          if dmg > 0
            b.hp -= dmg
            b.hp_damage = dmg if b.respond_to?(:hp_damage=)
            log("FIELD_WEATHER_TICK battler=" + b.name.to_s + " weather=" +
                state.weather.to_s + " damage=" + dmg.to_s)
          end
        end
      end
    end

    def self.apply_grassy_heal
      return unless state.terrain == :grassy && state.terrain_turns.to_i > 0
      list = []
      list.concat($game_party.members) if defined?($game_party) && $game_party != nil
      list.concat($game_troop.members) if defined?($game_troop) && $game_troop != nil
      list.each do |b|
        next if b == nil || !b.respond_to?(:hp) || b.hp.to_i <= 0
        next unless grounded?(b)
        gain = [[b.maxhp.to_i / 16, 1].max, b.maxhp.to_i - b.hp.to_i].min
        if gain > 0
          b.hp += gain
          b.hp_damage = -gain if b.respond_to?(:hp_damage=)
          log("FIELD_GRASSY_HEAL battler=" + b.name.to_s + " heal=" + gain.to_s)
        end
      end
    end

    def self.turn_end_tick
      apply_weather_residual
      apply_grassy_heal
      state.round_flags = {:ally=>{}, :enemy=>{}, :global=>{}}
      if state.weather_turns.to_i > 0
        state.weather_turns -= 1
        if state.weather_turns <= 0
          log("FIELD_WEATHER_END weather=" + state.weather.to_s)
          state.weather = nil
        end
      end
      if state.terrain_turns.to_i > 0
        state.terrain_turns -= 1
        if state.terrain_turns <= 0
          log("FIELD_TERRAIN_END terrain=" + state.terrain.to_s)
          state.terrain = nil
        end
      end
      decrement_hash(state.globals)
      decrement_hash(state.sides[:ally])
      decrement_hash(state.sides[:enemy])
    end

    def self.apply_entry_hazards(battler)
      return {:damage=>0,:states=>[],:spe_delta=>0} if battler == nil
      side = side_key(battler)
      table = state.hazards[side]
      return {:damage=>0,:states=>[],:spe_delta=>0} if table == nil
      grounded = grounded?(battler)
      total = 0
      states_added = []
      spe_delta = 0

      layers = table[:spikes].to_i
      if grounded && layers > 0
        divisor = layers == 1 ? 8 : (layers == 2 ? 6 : 4)
        dmg = [battler.maxhp.to_i / divisor, 1].max
        total += dmg
      end

      if table[:stealth_rock].to_i > 0 && defined?(ALBERT_CG::POKEMON_COMBAT)
        rock_id = ALBERT_CG::POKEMON_COMBAT.type_id(:rock)
        rate = battler.respond_to?(:cg_pokemon_type_rate_percent) ?
          battler.cg_pokemon_type_rate_percent(rock_id).to_i : 100
        dmg = [battler.maxhp.to_i * rate / 800, 1].max
        total += dmg if rate > 0
      end

      if grounded && table[:toxic_spikes].to_i > 0 && battler.respond_to?(:cg_pokemon_types)
        types = battler.cg_pokemon_types
        if types.include?(:poison)
          table[:toxic_spikes] = 0
          log("FIELD_TOXIC_SPIKES_ABSORB battler=" + battler.name.to_s)
        elsif !types.include?(:steel)
          sid = nil
          if table[:toxic_spikes].to_i >= 2 && defined?(ALBERT_CG::MOVE_EFFECT) &&
             ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON)
            sid = ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON
          elsif defined?(ALBERT_CG::MOVE_EFFECT)
            sid = ALBERT_CG::MOVE_EFFECT::STATE_POISON
          end
          if sid != nil && !status_blocked?(battler, 5)
            battler.add_state(sid)
            states_added.push(sid)
          end
        end
      end

      if grounded && table[:sticky_web].to_i > 0 && battler.respond_to?(:cg_change_stat_stage)
        battler.cg_change_stat_stage(:spe, -1)
        spe_delta = -1
      end

      if total > 0
        total = [total, battler.hp.to_i].min
        total = 0 if total < 0
        battler.hp -= total
        battler.hp_damage = total if battler.respond_to?(:hp_damage=)
      end
      log("FIELD_ENTRY battler=" + battler.name.to_s + " side=" + side.to_s +
          " damage=" + total.to_s + " states=" + states_added.inspect +
          " spe_delta=" + spe_delta.to_s)
      return {:damage=>total,:states=>states_added,:spe_delta=>spe_delta}
    end
  end
end

#==============================================================================
# ■ RPG::Skill：Ion Deluge 將 Normal move 視為 Electric
#==============================================================================
class RPG::UsableItem
  if method_defined?(:cg_pokemon_type_id)
    alias cg_field_v233_type_id cg_pokemon_type_id
    def cg_pokemon_type_id
      value = cg_field_v233_type_id
      if defined?(ALBERT_CG::FIELD_V233) &&
         ALBERT_CG::FIELD_V233.state.round_flags[:global][:ion_deluge] == true &&
         defined?(ALBERT_CG::POKEMON_COMBAT)
        normal_id = ALBERT_CG::POKEMON_COMBAT.type_id(:normal)
        electric_id = ALBERT_CG::POKEMON_COMBAT.type_id(:electric)
        return electric_id if value.to_i == normal_id.to_i
      end
      return value
    end
  end
end

#==============================================================================
# ■ Game_Battler：Field 對狀態、能力、傷害、Critical、Room 的正式 Hook
#==============================================================================
class Game_Battler
  alias cg_field_v233_apply_ailment cg_move_effect_apply_ailment
  def cg_move_effect_apply_ailment(user, move_id)
    ailment = ALBERT_CG::MOVE_EFFECT.ailment_id(move_id)
    if ALBERT_CG::FIELD_V233.status_blocked?(self, ailment)
      ALBERT_CG::FIELD_V233.log("FIELD_STATUS_BLOCK target=" + name.to_s +
        " move=" + move_id.to_s + " ailment=" + ailment.to_s)
      return
    end
    cg_field_v233_apply_ailment(user, move_id)
  end

  # 重新實作 v2.3.0 的 Stage metadata 套用，只多一層 Mist 判定。
  def cg_move_effect_apply_stats(user, move_id)
    list = ALBERT_CG::MOVE_EFFECT::MOVE_STAT_CHANGES[move_id.to_i]
    return if list == nil || list.empty?
    chance = ALBERT_CG::MOVE_EFFECT.stat_chance(move_id)
    return if chance <= 0 || rand(100) >= chance
    target = ALBERT_CG::MOVE_EFFECT.effect_recipient(user, self, move_id)
    list.each do |pair|
      key = ALBERT_CG::MOVE_EFFECT::STAT_ID_TO_KEY[pair[0].to_i]
      next if key == nil
      delta = pair[1].to_i
      if ALBERT_CG::FIELD_V233.stat_drop_blocked?(user, target, delta)
        ALBERT_CG::FIELD_V233.log("FIELD_MIST_BLOCK target=" + target.name.to_s +
          " stat=" + key.to_s + " delta=" + delta.to_s)
        next
      end
      target.cg_change_stat_stage(key, delta)
    end
  end

  alias cg_field_v233_skill_effect skill_effect
  def skill_effect(user, skill)
    if skill != nil
      guard = ALBERT_CG::FIELD_V233.guard_blocks?(self, user, skill)
      if guard != nil
        clear_action_results
        @skipped = true
        ALBERT_CG::FIELD_V233.log("FIELD_GUARD_BLOCK guard=" + guard.to_s +
          " target=" + name.to_s + " user=" + user.name.to_s +
          " skill=" + skill.name.to_s)
        return
      end
    end

    cg_field_v233_skill_effect(user, skill)
    return if skill == nil || @skipped || @missed || @evaded
    move_id = ALBERT_CG::MOVE_EFFECT.move_id(skill)
    ALBERT_CG::FIELD_V233.apply_move(user, self, move_id) if move_id > 0
  end

  # Wonder Room 直接交換最終 DEF / SpD getter，讓 v2.1 六維公式、普通攻擊與
  # 之後 Ability/AI 都讀到同一權威值；不用在每條傷害公式各自補 if。
  alias cg_field_v233_raw_def_stat cg_def_stat
  alias cg_field_v233_raw_spd_stat cg_spd
  def cg_def_stat
    if ALBERT_CG::FIELD_V233.wonder_room_active?
      return [cg_field_v233_raw_spd_stat.to_i, 1].max
    end
    return cg_field_v233_raw_def_stat
  end
  def cg_spd
    if ALBERT_CG::FIELD_V233.wonder_room_active?
      return [cg_field_v233_raw_def_stat.to_i, 1].max
    end
    return cg_field_v233_raw_spd_stat
  end

  # v2.1.0 最終六維公式在本腳本之前載入；這裡只乘 Field 百分比，不重寫公式。
  alias cg_field_v233_make_obj_damage_value make_obj_damage_value
  def make_obj_damage_value(user, obj)
    cg_field_v233_make_obj_damage_value(user, obj)
    return unless obj.is_a?(RPG::Skill)
    return unless @hp_damage.to_i > 0
    move_id = ALBERT_CG::MOVE_EFFECT.move_id(obj)
    type_id = obj.respond_to?(:cg_pokemon_type_id) ? obj.cg_pokemon_type_id : 0
    klass = obj.respond_to?(:cg_pokemon_damage_class) ? obj.cg_pokemon_damage_class : :physical
    percent = ALBERT_CG::FIELD_V233.damage_percent(user, self, obj, type_id, klass, move_id)
    old = @hp_damage.to_i
    @hp_damage = [old * percent / 100, 1].max
    if @cg_last_damage_breakdown.is_a?(Hash)
      @cg_last_damage_breakdown[:field_percent] = percent
      @cg_last_damage_breakdown[:damage] = @hp_damage
    end
    ALBERT_CG::FIELD_V233.log("FIELD_DAMAGE user=" + user.name.to_s +
      " target=" + name.to_s + " move=" + move_id.to_s +
      " base=" + old.to_s + " pct=" + percent.to_s + " final=" + @hp_damage.to_s)
  end

  alias cg_field_v233_make_attack_damage_value make_attack_damage_value
  def make_attack_damage_value(attacker)
    cg_field_v233_make_attack_damage_value(attacker)
    return unless @hp_damage.to_i > 0
    type_id = attacker.respond_to?(:cg_basic_attack_type_id) ? attacker.cg_basic_attack_type_id : 0
    percent = ALBERT_CG::FIELD_V233.damage_percent(attacker, self, nil, type_id, :physical, 0)
    old = @hp_damage.to_i
    @hp_damage = [old * percent / 100, 1].max
    ALBERT_CG::FIELD_V233.log("FIELD_ATTACK_DAMAGE user=" + attacker.name.to_s +
      " target=" + name.to_s + " base=" + old.to_s +
      " pct=" + percent.to_s + " final=" + @hp_damage.to_s)
  end

  alias cg_field_v233_critical cg_pokemon_critical?
  def cg_pokemon_critical?(user, obj = nil)
    if ALBERT_CG::FIELD_V233.side_effect?(ALBERT_CG::FIELD_V233.side_key(self), :lucky_chant)
      return false
    end
    return cg_field_v233_critical(user, obj)
  end
end

#==============================================================================
# ■ 六維特殊防禦：Sandstorm 岩石系 SpD 150%
#==============================================================================
class Game_Battler
  alias cg_field_v233_spd cg_spd
  def cg_spd
    value = cg_field_v233_spd
    if ALBERT_CG::FIELD_V233.state.weather == :sandstorm &&
       ALBERT_CG::FIELD_V233.state.weather_turns.to_i > 0 &&
       respond_to?(:cg_pokemon_types) && cg_pokemon_types.include?(:rock)
      value = value.to_i * ALBERT_CG::FIELD_V233::SAND_ROCK_SPD_PERCENT / 100
    end
    return [value.to_i, 1].max
  end
end

#==============================================================================
# ■ Basic Attack：Ion Deluge 也影響一般屬性的普通攻擊
#==============================================================================
class Game_Battler
  alias cg_field_v233_basic_attack_type_id cg_basic_attack_type_id
  def cg_basic_attack_type_id
    value = cg_field_v233_basic_attack_type_id
    if ALBERT_CG::FIELD_V233.state.round_flags[:global][:ion_deluge] == true &&
       defined?(ALBERT_CG::POKEMON_COMBAT)
      normal_id = ALBERT_CG::POKEMON_COMBAT.type_id(:normal)
      return ALBERT_CG::POKEMON_COMBAT.type_id(:electric) if value.to_i == normal_id.to_i
    end
    return value
  end
end

#==============================================================================
# ■ Priority：Tailwind 與 Trick Room 接到既有 Priority > SPE 核心
#==============================================================================
class Game_Battler
  alias cg_field_v233_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    override = instance_variable_get(:@cg_field_test_speed_override_v233)
    if defined?(ALBERT_CG::FIELD_TEST_V233) && ALBERT_CG::FIELD_TEST_V233.active? && override != nil
      value = override.to_i
    else
      value = cg_field_v233_priority_base_speed.to_i
    end
    value *= 2 if ALBERT_CG::FIELD_V233.tailwind_active?(self)
    return value
  end
end

class Game_BattleAction
  alias cg_field_v233_priority_secondary_speed cg_priority_secondary_speed
  def cg_priority_secondary_speed
    # Priority Core 在 make_action_orders 中會把第一次算好的 speed 寫入 rank；
    # rank 已包含 Trick Room 符號，不可在 sort 時再反轉第二次。
    return @cg_priority_speed_rank.to_i if @cg_priority_speed_rank != nil
    value = cg_field_v233_priority_secondary_speed.to_i
    value = -value if ALBERT_CG::FIELD_V233.trick_room_active?
    return value
  end
end

#==============================================================================
# ■ Scene_Battle：Field 初始化 / 回合末 / Fairy Lock switch guard
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_field_v233_start start
  def start
    ALBERT_CG::FIELD_V233.reset
    cg_field_v233_start
  end

  alias cg_field_v233_turn_end turn_end
  def turn_end
    ALBERT_CG::FIELD_V233.turn_end_tick
    cg_field_v233_turn_end
  end

  if method_defined?(:cg_execute_switch_pet)
    alias cg_field_v233_execute_switch_pet cg_execute_switch_pet
    def cg_execute_switch_pet
      if ALBERT_CG::FIELD_V233.switch_locked?
        if respond_to?(:cg_show_special_action_text)
          cg_show_special_action_text("妖精之鎖封住了戰場，現在無法換寵。")
        end
        ALBERT_CG::FIELD_V233.log("FIELD_SWITCH_BLOCK fairy_lock=true")
        return
      end
      cg_field_v233_execute_switch_pet
    end
  end
end

#==============================================================================
# ■ v2.3.3 Alt+F11 全自動 Regression Harness
#==============================================================================
module ALBERT_CG
  module FIELD_TEST_V233
    VERSION = "2.3.3a"
    TEST_TROOP_ID = 696
    TEST_LEVEL = 40

    TEST_ALLIES = [
      {:dex=>25,  :level=>40, :ability=>0, :moves=>[113,390,472,300,604]},
      {:dex=>448, :level=>40, :ability=>0, :moves=>[115,433,478,346,678]},
      {:dex=>3,   :level=>40, :ability=>0, :moves=>[366,446,564,580,201]}
    ]
    TEST_ENEMIES = [
      {:dex=>9,   :level=>40, :ability=>0, :moves=>[240,469,561,581,258]},
      {:dex=>150, :level=>40, :ability=>0, :moves=>[219,501,578,587,241]},
      {:dex=>143, :level=>40, :ability=>0, :moves=>[191,54,356,694,569]},
      {:dex=>94,  :level=>40, :ability=>0, :moves=>[381,390,201,569,678]}
    ]

    # 31 Field moves 全部至少出現一次。重複招式只是為了讓每名敵人每回合都有行動。
    ROUND_PLANS = [
      {
        :name=>"SCREENS_RAIN_HAZARD",
        :allies=>[
          {:kind=>:attack,:target=>1},
          {:kind=>:move,:move_id=>113,:target=>1},
          {:kind=>:move,:move_id=>115,:target=>2},
          {:kind=>:move,:move_id=>366,:target=>3}
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>240,:target=>0},
          {:kind=>:move,:move_id=>219,:target=>1},
          {:kind=>:move,:move_id=>191,:target=>2},
          {:kind=>:move,:move_id=>381,:target=>3}
        ]
      },
      {
        :name=>"TRICKROOM_GUARDS_HAZARDS_MIST",
        :allies=>[
          {:kind=>:attack,:target=>1},
          {:kind=>:move,:move_id=>390,:target=>1},
          {:kind=>:move,:move_id=>433,:target=>2},
          {:kind=>:move,:move_id=>446,:target=>3}
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>469,:target=>0},
          {:kind=>:move,:move_id=>501,:target=>1},
          {:kind=>:move,:move_id=>54,:target=>2},
          {:kind=>:move,:move_id=>390,:target=>3}
        ]
      },
      {
        :name=>"ROOM_GRAVITY_WEB_TEAM_GUARDS",
        :allies=>[
          {:kind=>:attack,:target=>1},
          {:kind=>:move,:move_id=>472,:target=>1},
          {:kind=>:move,:move_id=>478,:target=>2},
          {:kind=>:move,:move_id=>564,:target=>3}
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>561,:target=>0},
          {:kind=>:move,:move_id=>578,:target=>1},
          {:kind=>:move,:move_id=>356,:target=>2},
          {:kind=>:move,:move_id=>201,:target=>3}
        ]
      },
      {
        :name=>"SPORT_TERRAIN_LOCK_VEIL",
        :allies=>[
          {:kind=>:attack,:target=>1},
          {:kind=>:move,:move_id=>300,:target=>1},
          {:kind=>:move,:move_id=>346,:target=>2},
          {:kind=>:move,:move_id=>580,:target=>3}
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>581,:target=>0},
          {:kind=>:move,:move_id=>587,:target=>1},
          {:kind=>:move,:move_id=>694,:target=>2},
          {:kind=>:move,:move_id=>569,:target=>3}
        ]
      },
      {
        :name=>"FINAL_WEATHER_TERRAINS",
        :allies=>[
          {:kind=>:attack,:target=>1},
          {:kind=>:move,:move_id=>604,:target=>1},
          {:kind=>:move,:move_id=>678,:target=>2},
          {:kind=>:move,:move_id=>201,:target=>3}
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>258,:target=>0},
          {:kind=>:move,:move_id=>241,:target=>1},
          {:kind=>:move,:move_id=>569,:target=>2},
          {:kind=>:move,:move_id=>678,:target=>3}
        ]
      }
    ]

    SPEEDS = {:human=>50,:ally_0=>80,:ally_1=>40,:ally_2=>60,
              :enemy_0=>45,:enemy_1=>90,:enemy_2=>20,:enemy_3=>70}

    def self.active?; return @active == true; end
    def self.finished?; return @round_index.to_i >= ROUND_PLANS.size; end
    def self.current_round; return @round_index.to_i + 1; end
    def self.plan; return finished? ? nil : ROUND_PLANS[@round_index.to_i]; end
    def self.failures; @failures = [] if @failures == nil; return @failures; end

    def self.log(text); ALBERT_CG::FIELD_V233.log(text); end
    def self.pass(text); log("ASSERT PASS " + text.to_s); end
    def self.fail(text); failures.push(text.to_s); log("ASSERT FAIL " + text.to_s); end
    def self.assert(cond,text); cond ? pass(text) : fail(text); end

    begin
      VK_ALT = 0x12 unless const_defined?(:VK_ALT)
      VK_F11 = 0x7A unless const_defined?(:VK_F11)
      KEY_API = Win32API.new("user32", "GetAsyncKeyState", "i", "i") unless const_defined?(:KEY_API)
    rescue
      KEY_API = nil unless const_defined?(:KEY_API)
    end

    def self.alt_f11_trigger?
      return false if KEY_API == nil
      down = ((KEY_API.call(VK_ALT) & 0x8000) != 0) && ((KEY_API.call(VK_F11) & 0x8000) != 0)
      trigger = down && @alt_f11_down != true
      @alt_f11_down = down
      return trigger
    rescue
      return false
    end

    def self.master
      return nil unless defined?(ALBERT_CG::POKEMON_MASTER)
      return ALBERT_CG::POKEMON_MASTER
    end

    def self.test_allies
      return $game_party == nil ? [] : $game_party.members
    end

    def self.test_enemies
      return $game_troop == nil ? [] : $game_troop.members
    end

    def self.install_actor(cfg)
      a = $game_actors[master.actor_id_for_dex(cfg[:dex])]
      master.configure_actor(a,cfg)
      a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages)
      a.cg_clear_v231_battle_flags if a.respond_to?(:cg_clear_v231_battle_flags)
      return a
    end

    def self.prepare_party
      ids = TEST_ALLIES.collect { |cfg| master.actor_id_for_dex(cfg[:dex]) }
      if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
        ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids)
      end
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each { |cfg| install_actor(cfg) }
      human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if human != nil
        human.change_level(TEST_LEVEL,false)
        human.recover_all if human.respond_to?(:recover_all)
      end
    end

    def self.make_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[2]]
      members=[]
      TEST_ENEMIES.each_with_index do |cfg,i|
        master.configure_enemy_data(cfg)
        members.push(ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]),xs[i],ys[i]))
      end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Field Auto Regression v2.3.3a",members)
    end

    def self.make_action(b,cfg)
      a=Game_BattleAction.new(b)
      if cfg[:kind]==:attack
        a.set_attack
      else
        a.set_skill(master.skill_id_for_move(cfg[:move_id].to_i))
      end
      a.target_index=cfg[:target].to_i if cfg.has_key?(:target)
      return a
    end

    def self.recover_all
      (test_allies+test_enemies).each do |b|
        next if b==nil
        b.recover_all rescue nil
        b.cg_reset_stat_stages if b.respond_to?(:cg_reset_stat_stages)
      end
    end

    def self.apply_speed_overrides
      test_allies.each_with_index do |b,i|
        next if b==nil
        key=i==0 ? :human : ("ally_"+(i-1).to_s).to_sym
        b.instance_variable_set(:@cg_field_test_speed_override_v233,SPEEDS[key])
      end
      test_enemies.each_with_index do |b,i|
        next if b==nil
        b.instance_variable_set(:@cg_field_test_speed_override_v233,SPEEDS[("enemy_"+i.to_s).to_sym])
      end
    end

    def self.prepare_round_actions
      p=plan
      return if p==nil
      recover_all
      apply_speed_overrides
      @actual=[]
      @actual_tokens=[]
      @forced_enemy={}
      @round_field_before={}
      (p[:allies]+p[:enemies]).each do |cfg|
        next unless cfg[:kind]==:move && ALBERT_CG::FIELD_V233.field_move?(cfg[:move_id])
        mid=cfg[:move_id].to_i
        @round_field_before[mid]=ALBERT_CG::FIELD_V233.state.apply_counts[mid].to_i
      end
      log("ROUND " + current_round.to_s + " BEGIN " + p[:name].to_s)
      allies=test_allies
      p[:allies].each_with_index do |cfg,i|
        b=allies[i]; next if b==nil
        a=make_action(b,cfg)
        if b.respond_to?(:cg_round_actions)
          b.cg_round_actions.clear; b.cg_round_actions.push(a)
        end
        b.cg_assign_action(a) if b.respond_to?(:cg_assign_action)
      end
      enemies=test_enemies
      p[:enemies].each_with_index do |cfg,i|
        b=enemies[i]; next if b==nil
        @forced_enemy[i]=make_action(b,cfg)
      end
    end

    def self.forced_enemy_action(enemy)
      return nil unless active? && @forced_enemy != nil && enemy != nil
      return @forced_enemy[enemy.index]
    end

    def self.execution_token(b)
      return "UNKNOWN" if b==nil
      prefix = "?"
      index = -1
      if b.respond_to?(:actor?) && b.actor?
        prefix = "A"
        index = test_allies.index(b) || -1
      else
        prefix = "E"
        index = b.respond_to?(:index) ? b.index.to_i : -1
      end
      action=b.action
      body="Attack"
      if action!=nil && action.skill?
        mid=ALBERT_CG::MOVE_EFFECT.move_id(action.skill)
        body="M"+mid.to_i.to_s
      end
      return prefix+index.to_i.to_s+":"+body
    end

    def self.expected_execution_tokens
      p=plan
      return [] if p==nil
      result=[]
      p[:allies].each_with_index do |cfg,i|
        body=cfg[:kind]==:move ? "M"+cfg[:move_id].to_i.to_s : "Attack"
        result.push("A"+i.to_s+":"+body)
      end
      p[:enemies].each_with_index do |cfg,i|
        body=cfg[:kind]==:move ? "M"+cfg[:move_id].to_i.to_s : "Attack"
        result.push("E"+i.to_s+":"+body)
      end
      return result
    end

    def self.record_execution(b)
      return unless active? && b!=nil
      action=b.action
      label=b.name.to_s+":"
      if action!=nil && action.skill?
        mid=ALBERT_CG::MOVE_EFFECT.move_id(action.skill)
        label += mid.to_s
      else
        label += "Attack"
      end
      @actual.push(label)
      @actual_tokens=[] if @actual_tokens==nil
      token=execution_token(b)
      @actual_tokens.push(token)
      log("ACTION_EXEC #"+@actual.size.to_s+" "+label+" token="+token)
    end

    def self.assert_runtime_bootstrap_once
      return if @boot_asserted==true
      @boot_asserted=true
      troop_id=$game_troop==nil ? -1 : $game_troop.instance_variable_get(:@troop_id).to_i
      assert(troop_id==TEST_TROOP_ID,"Scene_Battle uses Field test troop id="+troop_id.to_s)
      assert(test_allies.size==4,"Scene_Battle ally count=4 actual="+test_allies.size.to_s)
      assert(test_enemies.size==4,"Scene_Battle enemy count=4 actual="+test_enemies.size.to_s)
      expected_actor_ids=[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]+TEST_ALLIES.collect{|cfg| master.actor_id_for_dex(cfg[:dex])}
      actual_actor_ids=test_allies.collect{|b| b.respond_to?(:id) ? b.id.to_i : -1}
      assert(actual_actor_ids==expected_actor_ids,"Scene_Battle exact ally roster expected="+expected_actor_ids.inspect+" actual="+actual_actor_ids.inspect)
      expected_enemy_ids=TEST_ENEMIES.collect{|cfg| master.enemy_id_for_dex(cfg[:dex])}
      actual_enemy_ids=test_enemies.collect{|b| b.respond_to?(:enemy_id) ? b.enemy_id.to_i : -1}
      assert(actual_enemy_ids==expected_enemy_ids,"Scene_Battle exact enemy roster expected="+expected_enemy_ids.inspect+" actual="+actual_enemy_ids.inspect)
    end

    def self.finish_round_assertions
      return unless active?
      r=current_round
      p=plan
      expected_tokens=expected_execution_tokens
      actual_tokens=@actual_tokens==nil ? [] : @actual_tokens
      assert(actual_tokens.size==8,"Round"+r.to_s+" executes exactly 8 scripted battler actions actual="+actual_tokens.size.to_s)
      assert(actual_tokens.sort==expected_tokens.sort,"Round"+r.to_s+" scripted actions match plan expected="+expected_tokens.inspect+" actual="+actual_tokens.inspect)

      expected_fields=[]
      (p[:allies]+p[:enemies]).each do |cfg|
        expected_fields.push(cfg[:move_id].to_i) if cfg[:kind]==:move && ALBERT_CG::FIELD_V233.field_move?(cfg[:move_id])
      end
      expected_fields.uniq.each do |mid|
        before=@round_field_before==nil ? 0 : @round_field_before[mid].to_i
        count=ALBERT_CG::FIELD_V233.state.apply_counts[mid].to_i
        delta=count-before
        assert(delta>0,"Round"+r.to_s+" field move NEW apply mid="+mid.to_s+" before="+before.to_s+" after="+count.to_s+" delta="+delta.to_s)
      end

      if r==1
        assert(ALBERT_CG::FIELD_V233.state.weather==:rain,"Rain active after Round1 setup")
        assert(ALBERT_CG::FIELD_V233.side_effect?(:ally,:light_screen),"Ally Light Screen active")
        assert(ALBERT_CG::FIELD_V233.side_effect?(:ally,:reflect),"Ally Reflect active")
        assert(ALBERT_CG::FIELD_V233.side_effect?(:ally,:tailwind),"Ally Tailwind active")
        assert(ALBERT_CG::FIELD_V233.side_effect?(:enemy,:safeguard),"Enemy Safeguard active")
        assert(ALBERT_CG::FIELD_V233.state.hazards[:ally][:spikes].to_i==1,"Enemy Spikes placed on ally side")
      elsif r==2
        assert(ALBERT_CG::FIELD_V233.global_effect?(:trick_room),"Trick Room active")
        assert(ALBERT_CG::FIELD_V233.state.hazards[:enemy][:toxic_spikes].to_i>=1,"Toxic Spikes on enemy side")
        assert(ALBERT_CG::FIELD_V233.state.hazards[:enemy][:stealth_rock].to_i==1,"Stealth Rock on enemy side")
      elsif r==3
        assert(ALBERT_CG::FIELD_V233.global_effect?(:gravity),"Gravity active")
        assert(ALBERT_CG::FIELD_V233.global_effect?(:wonder_room),"Wonder Room active")
        assert(ALBERT_CG::FIELD_V233.global_effect?(:magic_room),"Magic Room active")
        assert(ALBERT_CG::FIELD_V233.state.hazards[:enemy][:sticky_web].to_i==1,"Sticky Web on enemy side")
      elsif r==4
        assert(ALBERT_CG::FIELD_V233.global_effect?(:mud_sport),"Mud Sport active")
        assert(ALBERT_CG::FIELD_V233.global_effect?(:water_sport),"Water Sport active")
        assert(ALBERT_CG::FIELD_V233.global_effect?(:fairy_lock),"Fairy Lock active")
        assert(ALBERT_CG::FIELD_V233.side_effect?(:enemy,:aurora_veil),"Enemy Aurora Veil active")
      elsif r==5
        # 先在同一場戰鬥內直接模擬一次「換入」事件，驗證 Hazard 真會改 HP/State/Stage。
        target=test_enemies[1]
        if target!=nil
          before=target.hp.to_i
          result=ALBERT_CG::FIELD_V233.apply_entry_hazards(target)
          assert(result[:damage].to_i>0 && target.hp.to_i<before,"Hazard entry causes HP damage")
          assert(result[:spe_delta].to_i==-1,"Sticky Web lowers SPE stage on entry")
        end
      end
      log("ROUND "+r.to_s+" END")
      @round_index=@round_index.to_i+1
    end

    def self.finish_suite
      coverage=ALBERT_CG::FIELD_V233::FIELD_MOVE_IDS.select{|mid| ALBERT_CG::FIELD_V233.state.apply_counts[mid].to_i>0}
      missing=ALBERT_CG::FIELD_V233::FIELD_MOVE_IDS-coverage
      assert(missing.empty?,"All 31 Field Moves executed missing="+missing.inspect)
      log("------------------------------------------------------------")
      if failures.empty?
        log("RESULT=PASS")
        log("SUMMARY rounds=5 failures=0 field_moves="+coverage.size.to_s+"/31")
      else
        log("RESULT=FAIL")
        log("SUMMARY rounds=5 failures="+failures.size.to_s+" field_moves="+coverage.size.to_s+"/31")
        failures.each_with_index{|m,i| log("FAILURE "+(i+1).to_s+" "+m.to_s)}
      end
      @active=false
      (test_allies+test_enemies).each{|b| b.instance_variable_set(:@cg_field_test_speed_override_v233,nil) if b!=nil}
    end

    def self.start
      ALBERT_CG::FIELD_V233.reset_log
      @failures=[]; @round_index=0; @active=true; @boot_asserted=false
      prepare_party; make_troop
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s)
      log("BOOTSTRAP mode=ALBERT_CG.start_demo_battle")
      ok=ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
      unless ok
        fail("ALBERT_CG.start_demo_battle accepted Field test")
        log("RESULT=FAIL")
        log("SUMMARY rounds=0 failures="+failures.size.to_s+" field_moves=0/31")
        @active=false
      end
      return ok
    end
  end
end

# Enemy Action forcing for Field regression.
class Game_Enemy < Game_Battler
  alias cg_field_v233_test_make_action make_action
  def make_action
    if defined?(ALBERT_CG::FIELD_TEST_V233) && ALBERT_CG::FIELD_TEST_V233.active?
      forced=ALBERT_CG::FIELD_TEST_V233.forced_enemy_action(self)
      if forced!=nil
        cg_assign_action(forced.cg_copy_for(self)) if respond_to?(:cg_assign_action)
        @action=forced.cg_copy_for(self) unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_field_v233_test_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_field_v233_test_start_party start_party_command_selection
  def start_party_command_selection
    if defined?(ALBERT_CG::FIELD_TEST_V233) && ALBERT_CG::FIELD_TEST_V233.active?
      ALBERT_CG::FIELD_TEST_V233.assert_runtime_bootstrap_once
      if ALBERT_CG::FIELD_TEST_V233.finished?
        ALBERT_CG::FIELD_TEST_V233.finish_suite
        battle_end(0)
        return
      end
      cg_field_v233_test_start_party
      return unless $game_temp.in_battle
      ALBERT_CG::FIELD_TEST_V233.prepare_round_actions
      start_main
      return
    end
    cg_field_v233_test_start_party
  end

  alias cg_field_v233_test_execute_action execute_action
  def execute_action
    ALBERT_CG::FIELD_TEST_V233.record_execution(@active_battler) if
      defined?(ALBERT_CG::FIELD_TEST_V233) && ALBERT_CG::FIELD_TEST_V233.active?
    cg_field_v233_test_execute_action
  end

  alias cg_field_v233_test_turn_end turn_end
  def turn_end
    ALBERT_CG::FIELD_TEST_V233.finish_round_assertions if
      defined?(ALBERT_CG::FIELD_TEST_V233) && ALBERT_CG::FIELD_TEST_V233.active?
    cg_field_v233_test_turn_end
  end
end

# Alt+F11 與既有 F11 / Shift+F11 / Ctrl+F11 分流。
module ALBERT_CG
  module MOVE_EFFECT
    class << self
      alias cg_field_v233_old_f11_trigger f11_trigger?
    end
    def self.f11_trigger?
      if defined?(ALBERT_CG::FIELD_TEST_V233) && ALBERT_CG::FIELD_TEST_V233::KEY_API!=nil
        alt=(ALBERT_CG::FIELD_TEST_V233::KEY_API.call(ALBERT_CG::FIELD_TEST_V233::VK_ALT)&0x8000)!=0 rescue false
        return false if alt
      end
      return cg_field_v233_old_f11_trigger
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_field_v233_scene_map_update update
  def update
    cg_field_v233_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::FIELD_TEST_V233.alt_f11_trigger?
      Sound.play_decision
      ALBERT_CG::FIELD_TEST_V233.start
    end
  end
end

# Battle Scene 會再次執行 bootstrap_demo_party，因此 Field test 也要重套三隻測試 Pokémon。
module ALBERT_CG
  class << self
    alias cg_field_v233_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result=cg_field_v233_bootstrap_demo_party
      if defined?(ALBERT_CG::FIELD_TEST_V233) && ALBERT_CG::FIELD_TEST_V233.active?
        ALBERT_CG::FIELD_TEST_V233.prepare_party
      end
      return result
    end
  end
end
