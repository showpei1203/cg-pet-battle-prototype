# RMVX_SCRIPT_INDEX: 190
# RMVX_SCRIPT_ID: 98941287
# RMVX_SCRIPT_NAME: CG Pokemon Move Effect Core v2.3.0
# RMVX_SOURCE_SHA256: 854e37b9d07cf5629f9e22671d665f25cb2f0f0443f290840f90b7ea1dbf34e9

#==============================================================================
# ■ CG Pokemon Move Effect Core v2.3.0
#------------------------------------------------------------------------------
# 【用途】
#  將 v2.2 已建立的 Pokémon Move Master Data 從「威力／屬性／分類 Stub」
#  推進成可共用的技能效果核心，並同步提供 PMD Native 動作解析資訊。
#
#  本頁負責的第一層正式效果：
#    1. 937 招 Move Metadata 查詢與效果分類。
#    2. 物攻／物防／特攻／特防／速度／命中／閃避能力階級（-6～+6）。
#    3. 麻痺／睡眠／冰凍／灼傷／中毒／混亂／束縛／寄生種子等狀態骨架。
#    4. 多段攻擊次數（2～10 Hit）供 PMD Action Sequence 真正逐段判定。
#    5. Drain／Recoil／自我回復、固定傷害、OHKO 的共用處理。
#    6. Protect 類一回合防護。
#    7. Move 的 PMD Native Action 候選鏈與 Species 專用 Override。
#
# 【重要規則】
#  - Pokémon Move 效果與 PMD 圖像完全解耦。
#  - 動作不存在是正常資料狀況，不得報錯：
#      專用 Native 動作 -> 同類動作 -> Attack/Shoot/Charge/Pose -> Idle。
#  - 正式戰鬥仍由 CG_PMD_Core 鎖定：
#      我方左下 45° / 敵方右下 45°。
#  - Animation ID 目前仍可使用資料庫預設占位 ID；後續視覺 Pass 再逐招替換。
#  - 人類六職業技能不經本頁 PMD Resolver，仍使用 Tankentai SBS 原生分類。
#
# 【可調參數】
#  STATE_*                    ：本作 Pokémon 狀態 State ID。
#  STAGE_MIN / STAGE_MAX      ：能力階級上下限。
#  PROTECT_MOVE_NAMES         ：守住類技能 identifier。
#  SELF_LOWER_DAMAGE_MOVES    ：造成傷害同時降低使用者能力的技能。
#  SPECIES_MOVE_NATIVE_ACTION ：指定物種＋招式的 PMD 特調候選。
#
# 【腳本呼叫範例】
#  ALBERT_CG::MOVE_EFFECT.move_id($data_skills[1041])       # => 41 雙針
#  ALBERT_CG::MOVE_EFFECT.multi_hit_range(41)               # => [2,2]
#  ALBERT_CG::MOVE_EFFECT.effect_summary(202)
#  actor.cg_stat_stage(:spa)
#  actor.cg_change_stat_stage(:spa, 2)
#
# 【測試】
#  F11（Win32API）啟動 Move Effect Scenario。
#  輸出：Pokemon_MoveEffect_v2_3.log
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonMoveEffectCore"] = "2.3.0"

module ALBERT_CG
  module MOVE_EFFECT
    VERSION = "2.3.0"
    LOG_FILE = "Pokemon_MoveEffect_v2_3.log"

    STAGE_MIN = -6
    STAGE_MAX = 6

    STATE_POISON     = 31
    STATE_PARALYSIS  = 37
    STATE_SLEEP      = 39
    STATE_BURN       = 43
    STATE_FREEZE     = 44
    STATE_CONFUSION  = 45
    STATE_TRAP       = 46
    STATE_LEECH_SEED = 47
    STATE_FLINCH     = 48
    STATE_PROTECT    = 49
    STATE_DISABLE    = 50
    STATE_YAWN       = 51
    STATE_HEAL_BLOCK = 52
    STATE_INGRAIN    = 53
    STATE_PERISH     = 54
    STATE_EMBARGO    = 55

    AILMENT_TO_STATE = {
      1  => STATE_PARALYSIS,
      2  => STATE_SLEEP,
      3  => STATE_FREEZE,
      4  => STATE_BURN,
      5  => STATE_POISON,
      6  => STATE_CONFUSION,
      8  => STATE_TRAP,
      13 => STATE_DISABLE,
      14 => STATE_YAWN,
      15 => STATE_HEAL_BLOCK,
      18 => STATE_LEECH_SEED,
      19 => STATE_EMBARGO,
      20 => STATE_PERISH,
      21 => STATE_INGRAIN,
    }

    PRIMARY_STATES = [
      STATE_POISON, STATE_PARALYSIS, STATE_SLEEP, STATE_FREEZE, STATE_BURN
    ]

    STAT_ID_TO_KEY = {
      2 => :atk,
      3 => :def,
      4 => :spa,
      5 => :spd,
      6 => :spe,
      7 => :accuracy,
      8 => :evasion,
    }

    MOVE_STAT_CHANGES = {
      14 => [[2,2]],
      28 => [[7,-1]],
      39 => [[3,-1]],
      43 => [[3,-1]],
      45 => [[2,-1]],
      51 => [[5,-1]],
      61 => [[6,-1]],
      62 => [[2,-1]],
      74 => [[2,1],[4,1]],
      81 => [[6,-2]],
      94 => [[5,-1]],
      96 => [[2,1]],
      97 => [[6,2]],
      103 => [[3,-2]],
      104 => [[8,1]],
      106 => [[3,1]],
      107 => [[8,2]],
      108 => [[7,-1]],
      110 => [[3,1]],
      111 => [[3,1]],
      112 => [[3,2]],
      132 => [[6,-1]],
      133 => [[5,2]],
      134 => [[7,-1]],
      145 => [[6,-1]],
      148 => [[7,-1]],
      151 => [[3,2]],
      159 => [[2,1]],
      178 => [[6,-2]],
      184 => [[6,-2]],
      189 => [[7,-1]],
      190 => [[7,-1]],
      196 => [[6,-1]],
      204 => [[2,-2]],
      207 => [[2,2]],
      211 => [[3,1]],
      229 => [[6,1]],
      230 => [[8,-2]],
      231 => [[3,-1]],
      232 => [[2,1]],
      242 => [[3,-1]],
      246 => [[2,1],[3,1],[4,1],[5,1],[6,1]],
      247 => [[5,-1]],
      249 => [[3,-1]],
      254 => [[3,1],[5,1]],
      260 => [[4,1]],
      262 => [[2,-2],[4,-2]],
      268 => [[5,1]],
      276 => [[2,-1],[3,-1]],
      294 => [[4,3]],
      295 => [[5,-1]],
      296 => [[4,-1]],
      297 => [[2,-2]],
      306 => [[3,-1]],
      309 => [[2,1]],
      313 => [[5,-2]],
      315 => [[4,-2]],
      317 => [[6,-1]],
      318 => [[2,1],[3,1],[4,1],[5,1],[6,1]],
      319 => [[5,-2]],
      321 => [[2,-1],[3,-1]],
      322 => [[3,1],[5,1]],
      330 => [[7,-1]],
      334 => [[3,2]],
      336 => [[2,1]],
      339 => [[2,1],[3,1]],
      341 => [[6,-1]],
      347 => [[4,1],[5,1]],
      349 => [[2,1],[6,1]],
      354 => [[4,-2]],
      359 => [[6,-1]],
      370 => [[3,-1],[5,-1]],
      397 => [[6,2]],
      405 => [[5,-1]],
      411 => [[5,-1]],
      412 => [[5,-1]],
      414 => [[5,-1]],
      417 => [[4,2]],
      426 => [[7,-1]],
      429 => [[7,-1]],
      430 => [[5,-1]],
      432 => [[8,-1]],
      434 => [[4,-2]],
      437 => [[4,-2]],
      445 => [[4,-2]],
      451 => [[4,1]],
      455 => [[3,1],[5,1]],
      465 => [[5,-2]],
      466 => [[2,1],[3,1],[4,1],[5,1],[6,1]],
      468 => [[2,1],[7,1]],
      475 => [[6,2]],
      483 => [[4,1],[5,1],[6,1]],
      488 => [[6,1]],
      489 => [[2,1],[3,1],[7,1]],
      490 => [[6,-1]],
      491 => [[5,-2]],
      504 => [[3,-1],[5,-1],[2,2],[4,2],[6,2]],
      508 => [[2,1],[6,2]],
      522 => [[4,-1]],
      523 => [[6,-1]],
      526 => [[2,1],[4,1]],
      527 => [[6,-1]],
      534 => [[3,-1]],
      536 => [[7,-1]],
      538 => [[3,3]],
      539 => [[7,-1]],
      549 => [[6,-1]],
      552 => [[4,1]],
      555 => [[4,-1]],
      557 => [[3,-1],[5,-1],[6,-1]],
      563 => [[2,1],[4,1]],
      568 => [[2,-1],[4,-1]],
      575 => [[2,-1],[4,-1]],
      579 => [[3,1]],
      583 => [[2,-1]],
      585 => [[4,-1]],
      589 => [[2,-1]],
      590 => [[4,-1]],
      591 => [[3,2]],
      595 => [[4,-1]],
      597 => [[5,1]],
      598 => [[4,-2]],
      599 => [[2,-1],[4,-1],[6,-1]],
      601 => [[4,2],[5,2],[6,2]],
      602 => [[3,1],[5,1]],
      608 => [[2,-1]],
      612 => [[2,1]],
      620 => [[3,-1],[5,-1]],
      621 => [[3,-1]],
      665 => [[6,-1]],
      668 => [[2,-1]],
      672 => [[6,-1]],
      674 => [[2,1],[4,1]],
      679 => [[2,-1]],
      680 => [[3,-1]],
      688 => [[2,-1]],
      691 => [[3,-1]],
      702 => [[2,2],[3,2],[4,2],[5,2],[6,2]],
      705 => [[4,-2]],
      708 => [[3,-1]],
      710 => [[3,-1]],
      715 => [[2,-1],[4,-1]],
      728 => [[2,1],[3,1],[4,1],[5,1],[6,1]],
      729 => [[8,1]],
      747 => [[3,2]],
      748 => [[2,1],[3,1],[4,1],[5,1],[6,1]],
      749 => [[6,-1]],
      775 => [[2,1],[3,1],[4,1],[5,1],[6,1]],
      777 => [[2,2],[4,2]],
      778 => [[6,-1]],
      783 => [[6,1]],
      784 => [[2,-1]],
      787 => [[5,-1]],
      788 => [[3,-1]],
      789 => [[4,-1]],
      806 => [[4,-1]],
      811 => [[2,1],[3,1]],
      823 => [[3,-1]],
      851 => [[2,-1],[4,-1]],
      852 => [[6,-1]],
      855 => [[5,-2]],
      858 => [[2,2],[3,-2]],
      859 => [[6,-2]],
      868 => [[2,2],[4,2],[6,2]],
      871 => [[4,1]],
      872 => [[6,1]],
      874 => [[4,-1]],
      882 => [[2,1],[6,1]],
      884 => [[6,-1]],
      885 => [[6,1]],
      886 => [[2,-1]],
      890 => [[3,-1],[5,-1]],
      903 => [[6,-1]],
      905 => [[4,1]],
    }

    PROTECT_MOVE_NAMES = [
      "protect", "detect", "kings-shield", "spiky-shield",
      "baneful-bunker", "max-guard", "obstruct", "silk-trap", "burning-bulwark"
    ]

    SELF_LOWER_DAMAGE_MOVES = [
      "superpower", "close-combat", "leaf-storm", "overheat", "psycho-boost",
      "draco-meteor", "v-create", "hammer-arm", "ice-hammer",
      "fleur-cannon", "make-it-rain", "spin-out", "headlong-rush",
      "scale-shot"
    ]

    SPECIES_MOVE_NATIVE_ACTION = {
      25 => {
        84 => ["Shock", "Shoot", "Charge"],
        85 => ["Shock", "Shoot", "Charge"],
        86 => ["Shock", "Shoot", "Charge"],
      },
    }

    IDENTIFIER_NATIVE_HINTS = [
      [/punch|hammer/, ["Punch", "Attack", "Strike"]],
      [/kick/, ["Kick", "Attack", "Strike"]],
      [/bite|fang|crunch/, ["Bite", "Attack", "Strike"]],
      [/claw|slash|cut|scratch/, ["Slash", "Attack", "Strike"]],
      [/headbutt|head-charge|skull/, ["Head", "Attack", "Charge"]],
      [/wing|peck|drill-peck/, ["Attack", "Strike"]],
      [/beam|pulse|ball|shot|cannon|bomb|missile|gun/, ["Shoot", "Charge", "Attack"]],
      [/thunder|shock|electric/, ["Shock", "Shoot", "Charge"]],
      [/dance|growth|calm|meditate|plot|focus|protect|detect/, ["Pose", "Charge", "Idle"]],
      [/roar|growl|sing|screech|voice|sound/, ["Charge", "Pose", "Shoot"]],
    ]

    FIXED_DAMAGE = {
      "sonic-boom"      => [:value, 20],
      "dragon-rage"     => [:value, 40],
      "seismic-toss"    => [:level, 1],
      "night-shade"     => [:level, 1],
      "super-fang"      => [:fraction_current, 2],
      "natures-madness" => [:fraction_current, 2],
    }

    def self.reset_log
      begin
        File.open(LOG_FILE, "wb") do |f|
          f.write("CG POKEMON MOVE EFFECT CORE v" + VERSION + "\r\n")
          f.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
          f.write("------------------------------------------------------------\r\n")
        end
      rescue
      end
    end

    def self.log(text)
      begin
        File.open(LOG_FILE, "ab") do |f|
          f.write("[" + Time.now.strftime("%H:%M:%S") + "] " + text.to_s + "\r\n")
        end
      rescue
      end
    end

    def self.master
      return nil unless defined?(ALBERT_CG::POKEMON_MASTER)
      return ALBERT_CG::POKEMON_MASTER
    end

    def self.move_id(skill)
      return 0 if skill == nil || master == nil
      return master.move_id_for_skill(skill.id).to_i
    rescue
      return 0
    end

    def self.row(move_id)
      return nil if master == nil
      return master.move(move_id.to_i)
    rescue
      return nil
    end

    def self.identifier(move_id)
      data = row(move_id)
      return data == nil ? "" : data[0].to_s
    end

    def self.name(move_id)
      data = row(move_id)
      return data == nil ? "" : data[1].to_s
    end

    def self.meta_category(move_id)
      data = row(move_id)
      return data == nil ? 0 : data[11].to_i
    end

    def self.ailment_id(move_id)
      data = row(move_id)
      return data == nil ? 0 : data[12].to_i
    end

    def self.multi_hit_range(move_id)
      data = row(move_id)
      return [0,0] if data == nil
      return [data[13].to_i, data[14].to_i]
    end

    def self.drain_percent(move_id)
      data = row(move_id)
      return data == nil ? 0 : data[17].to_i
    end

    def self.healing_percent(move_id)
      data = row(move_id)
      return data == nil ? 0 : data[18].to_i
    end

    def self.crit_stage(move_id)
      data = row(move_id)
      return data == nil ? 0 : data[19].to_i
    end

    def self.ailment_chance(move_id)
      data = row(move_id)
      return 0 if data == nil
      value = data[20].to_i
      return value if value > 0
      return 100 if data[11].to_i == 1 && data[12].to_i != 0
      return 0
    end

    def self.flinch_chance(move_id)
      data = row(move_id)
      return data == nil ? 0 : data[21].to_i
    end

    def self.stat_chance(move_id)
      data = row(move_id)
      return 0 if data == nil
      value = data[22].to_i
      return value if value > 0
      return 100 if MOVE_STAT_CHANGES.has_key?(move_id.to_i) && data[3].to_i <= 0
      return 100 if data[11].to_i == 2
      return 0
    end

    def self.ohko?(move_id)
      return meta_category(move_id) == 9
    end

    def self.protect_move?(move_id)
      return PROTECT_MOVE_NAMES.include?(identifier(move_id))
    end

    def self.stage_ratio(stage, accuracy = false)
      s = [[stage.to_i, STAGE_MIN].max, STAGE_MAX].min
      base = accuracy ? 3 : 2
      return [base + s, base] if s >= 0
      return [base, base - s]
    end

    def self.apply_stage(value, stage)
      num, den = stage_ratio(stage, false)
      return [[value.to_i * num / den, 1].max, 999999].min
    end

    def self.multi_hit_count(move_id)
      min, max = multi_hit_range(move_id)
      return 1 if min <= 0 || max <= 0
      return min if min == max
      if min == 2 && max == 5
        roll = rand(100)
        return 2 if roll < 35
        return 3 if roll < 70
        return 4 if roll < 85
        return 5
      end
      return min + rand(max - min + 1)
    end

    def self.types_of(battler)
      return [] if battler == nil || !battler.respond_to?(:cg_pokemon_base_types)
      return battler.cg_pokemon_base_types || []
    rescue
      return []
    end

    def self.primary_status?(state_id)
      return PRIMARY_STATES.include?(state_id.to_i)
    end

    def self.has_primary_status?(battler)
      PRIMARY_STATES.each do |id|
        return true if battler.state?(id)
      end
      return false
    rescue
      return false
    end

    def self.ailment_immune?(battler, ailment)
      types = types_of(battler)
      case ailment.to_i
      when 1
        return true if types.include?(:electric)
      when 3
        return true if types.include?(:ice)
      when 4
        return true if types.include?(:fire)
      when 5
        return true if types.include?(:poison) || types.include?(:steel)
      end
      return false
    end

    def self.can_apply_ailment?(battler, ailment)
      state_id = AILMENT_TO_STATE[ailment.to_i]
      return false if state_id == nil
      return false if battler.state?(state_id)
      return false if primary_status?(state_id) && has_primary_status?(battler)
      return false if ailment_immune?(battler, ailment)
      return true
    rescue
      return false
    end

    def self.effect_recipient(user, target, move_id)
      data = row(move_id)
      return target if data == nil
      category = data[11].to_i
      ident = data[0].to_s
      return user if category == 7
      return user if SELF_LOWER_DAMAGE_MOVES.include?(ident)
      return target
    end

    def self.effect_summary(move_id)
      data = row(move_id)
      return "" if data == nil
      parts = []
      parts.push("Power=" + data[3].to_i.to_s) if data[3].to_i > 0
      min, max = multi_hit_range(move_id)
      parts.push("Hits=" + min.to_s + "-" + max.to_s) if min > 0
      drain = drain_percent(move_id)
      parts.push(drain > 0 ? "Drain=" + drain.to_s + "%" : "Recoil=" + (-drain).to_s + "%") if drain != 0
      heal = healing_percent(move_id)
      parts.push("Heal=" + heal.to_s + "%") if heal != 0
      ail = ailment_id(move_id)
      parts.push("Ailment=" + ail.to_s + "@" + ailment_chance(move_id).to_s + "%") if ail != 0
      if MOVE_STAT_CHANGES.has_key?(move_id.to_i)
        parts.push("Stats=" + MOVE_STAT_CHANGES[move_id.to_i].inspect)
      end
      parts.push("OHKO") if ohko?(move_id)
      parts.push("Protect") if protect_move?(move_id)
      return parts.join(" ")
    end

    def self.default_native_chain(skill, motion)
      result = []
      move = move_id(skill)
      ident = identifier(move)
      if move > 0
        IDENTIFIER_NATIVE_HINTS.each do |pair|
          if ident =~ pair[0]
            result.concat(pair[1])
            break
          end
        end
      end
      case motion
      when :melee_attack
        result.concat(["Attack", "Strike", "Kick", "Punch", "Charge", "Pose", "Idle"])
      when :stationary_attack
        result.concat(["Attack", "Strike", "Shoot", "Charge", "Pose", "Idle"])
      when :shoot
        result.concat(["Shoot", "Charge", "Attack", "Pose", "Idle"])
      when :charge
        result.concat(["Charge", "Pose", "Shoot", "Attack", "Idle"])
      when :pose
        result.concat(["Pose", "Charge", "Idle"])
      else
        result.concat(["Charge", "Attack", "Idle"])
      end
      unique = []
      result.each { |item| unique.push(item) unless unique.include?(item) }
      return unique
    end

    def self.species_native_chain(battler, skill)
      return [] if battler == nil || skill == nil
      dex = battler.respond_to?(:cg_national_dex) ? battler.cg_national_dex.to_i : 0
      mid = move_id(skill)
      table = SPECIES_MOVE_NATIVE_ACTION[dex]
      return [] if table == nil
      result = table[mid]
      return result == nil ? [] : result.clone
    rescue
      return []
    end

    def self.native_action_available?(key, action_name)
      return false unless defined?(CG_PMD)
      sprite = CG_PMD.sprite_data(key)
      return false if sprite == nil
      actions = sprite[:actions] || {}
      meta = actions[action_name.to_s]
      return false if meta == nil
      if defined?(CG_PMD::LOCK_BATTLE_VIEW_45) && CG_PMD::LOCK_BATTLE_VIEW_45
        return false if meta[:direction_count].to_i < 8
      end
      return true
    rescue
      return false
    end

    def self.resolve_native_action(battler, skill, motion)
      key = battler.respond_to?(:cg_pmd_sprite_key) ? battler.cg_pmd_sprite_key.to_s : ""
      chain = species_native_chain(battler, skill)
      chain.concat(default_native_chain(skill, motion))
      unique = []
      chain.each { |item| unique.push(item) unless unique.include?(item) }
      unique.each do |action_name|
        if native_action_available?(key, action_name)
          log("PMD_ACTION battler=" + battler.name.to_s +
              " dex=" + (battler.respond_to?(:cg_national_dex) ? battler.cg_national_dex.to_i.to_s : "0") +
              " move=" + move_id(skill).to_s + ":" + skill.name.to_s +
              " key=" + key + " action=" + action_name.to_s +
              " chain=" + unique.inspect)
          return action_name.to_s
        end
      end
      log("PMD_ACTION_FALLBACK battler=" + battler.name.to_s +
          " move=" + move_id(skill).to_s + ":" + skill.name.to_s +
          " key=" + key + " -> Idle")
      return "Idle"
    end

    def self.ensure_index(array, index)
      array.push(nil) while array.size <= index
    end

    def self.make_state(id, name, icon, hold, restriction, slip)
      state = RPG::State.new
      state.id = id.to_i
      state.name = name.to_s
      state.icon_index = icon.to_i
      state.restriction = restriction.to_i
      state.priority = 5
      state.atk_rate = 100
      state.def_rate = 100
      state.spi_rate = 100
      state.agi_rate = 100
      state.nonresistance = true
      state.offset_by_opposite = false
      state.slip_damage = slip == true
      state.reduce_hit_ratio = false
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
      return if $data_states == nil
      rows = {
        STATE_BURN       => make_state(STATE_BURN, "灼傷", 13, 4, 0, true),
        STATE_FREEZE     => make_state(STATE_FREEZE, "冰凍", 14, 2, 4, false),
        STATE_CONFUSION  => make_state(STATE_CONFUSION, "混亂", 15, 3, 0, false),
        STATE_TRAP       => make_state(STATE_TRAP, "束縛", 16, 4, 0, true),
        STATE_LEECH_SEED => make_state(STATE_LEECH_SEED, "寄生種子", 17, 5, 0, true),
        STATE_FLINCH     => make_state(STATE_FLINCH, "畏縮", 18, 0, 4, false),
        STATE_PROTECT    => make_state(STATE_PROTECT, "守住", 19, 0, 0, false),
        STATE_DISABLE    => make_state(STATE_DISABLE, "定身", 20, 3, 0, false),
        STATE_YAWN       => make_state(STATE_YAWN, "哈欠", 21, 1, 0, false),
        STATE_HEAL_BLOCK => make_state(STATE_HEAL_BLOCK, "回復封鎖", 22, 4, 0, false),
        STATE_INGRAIN    => make_state(STATE_INGRAIN, "扎根", 23, 5, 0, false),
        STATE_PERISH     => make_state(STATE_PERISH, "滅亡之歌", 24, 3, 0, false),
        STATE_EMBARGO    => make_state(STATE_EMBARGO, "封印道具", 25, 5, 0, false),
      }
      rows.each do |id, state|
        ensure_index($data_states, id)
        $data_states[id] = state
      end
      if $data_states[STATE_POISON] == nil
        ensure_index($data_states, STATE_POISON)
        $data_states[STATE_POISON] = make_state(STATE_POISON, "中毒", 7, 6, 0, true)
      end
      if $data_states[STATE_PARALYSIS] == nil
        ensure_index($data_states, STATE_PARALYSIS)
        $data_states[STATE_PARALYSIS] = make_state(STATE_PARALYSIS, "麻痺", 8, 4, 0, false)
      end
      if $data_states[STATE_SLEEP] == nil
        ensure_index($data_states, STATE_SLEEP)
        $data_states[STATE_SLEEP] = make_state(STATE_SLEEP, "睡眠", 10, 2, 4, false)
      end
    end

    def self.patch_skill_descriptions
      return if master == nil || $data_skills == nil
      master::MOVE_CATALOG.keys.each do |mid|
        sid = master.skill_id_for_move(mid)
        skill = $data_skills[sid]
        next if skill == nil
        summary = effect_summary(mid)
        skill.description = "Pokémon Move v2.3" + (summary == "" ? "" : "｜" + summary)
      end
    end

    def self.apply
      install_states
      patch_skill_descriptions
      reset_log
      covered = 0
      unique = 0
      multi = 0
      drain = 0
      stat = 0
      ail = 0
      if master != nil
        master::MOVE_CATALOG.keys.each do |mid|
          data = row(mid)
          next if data == nil
          unique += 1 if data[11].to_i == 13
          min, max = multi_hit_range(mid)
          multi += 1 if min > 0
          drain += 1 if drain_percent(mid) != 0 || healing_percent(mid) != 0
          stat += 1 if MOVE_STAT_CHANGES.has_key?(mid)
          ail += 1 if ailment_id(mid) != 0
          covered += 1 if data[11].to_i != 13
        end
      end
      log("APPLY moves=" + (master == nil ? "0" : master::MOVE_CATALOG.size.to_s) +
          " metadata_generic=" + covered.to_s +
          " unique_explicit_next=" + unique.to_s +
          " multi=" + multi.to_s + " drain_heal=" + drain.to_s +
          " stat_moves=" + stat.to_s + " ailment_moves=" + ail.to_s)
      return true
    end
  end
end

class Game_Battler
  def cg_prepare_stat_stages
    if @cg_stat_stages == nil
      @cg_stat_stages = {
        :atk=>0, :def=>0, :spa=>0, :spd=>0, :spe=>0,
        :accuracy=>0, :evasion=>0
      }
    end
  end

  def cg_stat_stage(key)
    cg_prepare_stat_stages
    return @cg_stat_stages[key.to_sym].to_i
  rescue
    return 0
  end

  def cg_change_stat_stage(key, amount)
    cg_prepare_stat_stages
    key = key.to_sym
    return 0 unless @cg_stat_stages.has_key?(key)
    old = @cg_stat_stages[key].to_i
    value = old + amount.to_i
    value = ALBERT_CG::MOVE_EFFECT::STAGE_MIN if value < ALBERT_CG::MOVE_EFFECT::STAGE_MIN
    value = ALBERT_CG::MOVE_EFFECT::STAGE_MAX if value > ALBERT_CG::MOVE_EFFECT::STAGE_MAX
    @cg_stat_stages[key] = value
    ALBERT_CG::MOVE_EFFECT.log("STAT_STAGE battler=" + name.to_s +
      " stat=" + key.to_s + " old=" + old.to_s + " delta=" + amount.to_i.to_s +
      " new=" + value.to_s)
    return value - old
  end

  def cg_reset_stat_stages
    @cg_stat_stages = nil
  end

  alias cg_move_v230_remove_states_battle remove_states_battle
  def remove_states_battle
    cg_move_v230_remove_states_battle
    cg_reset_stat_stages
    @cg_leech_seed_source = nil
    @cg_perish_count = nil
  end

  alias cg_move_v230_atk_stat cg_atk_stat
  def cg_atk_stat
    value = ALBERT_CG::MOVE_EFFECT.apply_stage(cg_move_v230_atk_stat, cg_stat_stage(:atk))
    value = [value / 2, 1].max if state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
    return value
  end

  alias cg_move_v230_def_stat cg_def_stat
  def cg_def_stat
    return ALBERT_CG::MOVE_EFFECT.apply_stage(cg_move_v230_def_stat, cg_stat_stage(:def))
  end

  alias cg_move_v230_spa cg_spa
  def cg_spa
    return ALBERT_CG::MOVE_EFFECT.apply_stage(cg_move_v230_spa, cg_stat_stage(:spa))
  end

  alias cg_move_v230_spd cg_spd
  def cg_spd
    return ALBERT_CG::MOVE_EFFECT.apply_stage(cg_move_v230_spd, cg_stat_stage(:spd))
  end

  alias cg_move_v230_spe cg_spe
  def cg_spe
    value = ALBERT_CG::MOVE_EFFECT.apply_stage(cg_move_v230_spe, cg_stat_stage(:spe))
    value = [value / 2, 1].max if state?(ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS)
    return value
  end

  alias cg_move_v230_calc_hit calc_hit
  def calc_hit(user, obj = nil)
    hit = cg_move_v230_calc_hit(user, obj)
    if user != nil && user.respond_to?(:cg_stat_stage)
      an, ad = ALBERT_CG::MOVE_EFFECT.stage_ratio(user.cg_stat_stage(:accuracy), true)
      en, ed = ALBERT_CG::MOVE_EFFECT.stage_ratio(cg_stat_stage(:evasion), true)
      hit = hit.to_i * an * ed / [ad * en, 1].max
    end
    hit = 100 if hit > 100
    hit = 1 if hit < 1
    return hit
  end

  alias cg_move_v230_slip_damage_effect slip_damage_effect
  def slip_damage_effect
    special = state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON) ||
              state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN) ||
              state?(ALBERT_CG::MOVE_EFFECT::STATE_TRAP) ||
              state?(ALBERT_CG::MOVE_EFFECT::STATE_LEECH_SEED) ||
              state?(ALBERT_CG::MOVE_EFFECT::STATE_INGRAIN) ||
              state?(ALBERT_CG::MOVE_EFFECT::STATE_PERISH)
    return cg_move_v230_slip_damage_effect unless special
    return if hp <= 0

    total = 0
    total += [maxhp / 8, 1].max if state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON)
    total += [maxhp / 8, 1].max if state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
    total += [maxhp / 8, 1].max if state?(ALBERT_CG::MOVE_EFFECT::STATE_TRAP)

    if state?(ALBERT_CG::MOVE_EFFECT::STATE_LEECH_SEED)
      seed = [maxhp / 8, 1].max
      total += seed
      source = @cg_leech_seed_source
      if source != nil && source.hp > 0
        gain = [seed, source.maxhp - source.hp].min
        source.hp += gain
        source.hp_damage = -gain if source.respond_to?(:hp_damage=)
        ALBERT_CG::MOVE_EFFECT.log("LEECH_HEAL source=" + source.name.to_s +
          " target=" + name.to_s + " heal=" + gain.to_s)
      end
    end

    if state?(ALBERT_CG::MOVE_EFFECT::STATE_INGRAIN)
      gain = [[maxhp / 16, 1].max, maxhp - hp].min
      self.hp += gain
      @hp_damage = -gain
      ALBERT_CG::MOVE_EFFECT.log("INGRAIN_HEAL battler=" + name.to_s + " heal=" + gain.to_s)
    end

    if state?(ALBERT_CG::MOVE_EFFECT::STATE_PERISH)
      @cg_perish_count = 3 if @cg_perish_count == nil
      @cg_perish_count -= 1
      if @cg_perish_count <= 0
        total = hp
        ALBERT_CG::MOVE_EFFECT.log("PERISH_KO battler=" + name.to_s)
      else
        ALBERT_CG::MOVE_EFFECT.log("PERISH_COUNT battler=" + name.to_s +
          " count=" + @cg_perish_count.to_s)
      end
    end

    if total > 0
      @hp_damage = [total, hp].min
      self.hp -= @hp_damage
      ALBERT_CG::MOVE_EFFECT.log("PERIODIC battler=" + name.to_s +
        " damage=" + @hp_damage.to_s + " hp=" + hp.to_s + "/" + maxhp.to_s)
    end
  end

  def cg_move_effect_apply_ailment(user, move_id)
    ailment = ALBERT_CG::MOVE_EFFECT.ailment_id(move_id)
    return if ailment == 0
    chance = ALBERT_CG::MOVE_EFFECT.ailment_chance(move_id)
    return if chance <= 0 || rand(100) >= chance
    return unless ALBERT_CG::MOVE_EFFECT.can_apply_ailment?(self, ailment)
    state_id = ALBERT_CG::MOVE_EFFECT::AILMENT_TO_STATE[ailment]
    add_state(state_id)
    @added_states.push(state_id) unless @added_states.include?(state_id)
    @cg_leech_seed_source = user if state_id == ALBERT_CG::MOVE_EFFECT::STATE_LEECH_SEED
    @cg_perish_count = 3 if state_id == ALBERT_CG::MOVE_EFFECT::STATE_PERISH
    ALBERT_CG::MOVE_EFFECT.log("AILMENT user=" + user.name.to_s +
      " target=" + name.to_s + " move=" + move_id.to_s +
      " ailment=" + ailment.to_s + " state=" + state_id.to_s)
  end

  def cg_move_effect_apply_stats(user, move_id)
    list = ALBERT_CG::MOVE_EFFECT::MOVE_STAT_CHANGES[move_id.to_i]
    return if list == nil || list.empty?
    chance = ALBERT_CG::MOVE_EFFECT.stat_chance(move_id)
    return if chance <= 0 || rand(100) >= chance
    target = ALBERT_CG::MOVE_EFFECT.effect_recipient(user, self, move_id)
    list.each do |pair|
      key = ALBERT_CG::MOVE_EFFECT::STAT_ID_TO_KEY[pair[0].to_i]
      next if key == nil
      target.cg_change_stat_stage(key, pair[1].to_i)
    end
  end

  def cg_move_effect_apply_protect(user, move_id)
    return unless ALBERT_CG::MOVE_EFFECT.protect_move?(move_id)
    user.add_state(ALBERT_CG::MOVE_EFFECT::STATE_PROTECT)
    user.added_states.push(ALBERT_CG::MOVE_EFFECT::STATE_PROTECT) unless
      user.added_states.include?(ALBERT_CG::MOVE_EFFECT::STATE_PROTECT)
    ALBERT_CG::MOVE_EFFECT.log("PROTECT user=" + user.name.to_s +
      " move=" + move_id.to_s)
  end

  def cg_move_effect_type_immune?(skill)
    return false unless respond_to?(:cg_pokemon_type_rate_percent)
    return false unless skill.respond_to?(:cg_pokemon_type_id)
    type_id = skill.cg_pokemon_type_id
    return false if type_id.to_i <= 0
    return cg_pokemon_type_rate_percent(type_id).to_i == 0
  rescue
    return false
  end

  def cg_move_effect_apply_special_damage(user, skill, move_id)
    return if cg_move_effect_type_immune?(skill)
    if ALBERT_CG::MOVE_EFFECT.ohko?(move_id)
      return if user.cg_pokemon_level.to_i < cg_pokemon_level.to_i
      @hp_damage = hp
      execute_damage(user)
      ALBERT_CG::MOVE_EFFECT.log("OHKO user=" + user.name.to_s +
        " target=" + name.to_s + " move=" + move_id.to_s +
        " damage=" + @hp_damage.to_s)
      return
    end

    spec = ALBERT_CG::MOVE_EFFECT::FIXED_DAMAGE[
      ALBERT_CG::MOVE_EFFECT.identifier(move_id)]
    return if spec == nil
    damage = 0
    case spec[0]
    when :value
      damage = spec[1].to_i
    when :level
      damage = user.cg_pokemon_level.to_i * spec[1].to_i
    when :fraction_current
      damage = [hp / spec[1].to_i, 1].max
    end
    damage = hp if damage > hp
    @hp_damage = damage
    execute_damage(user)
    ALBERT_CG::MOVE_EFFECT.log("FIXED_DAMAGE user=" + user.name.to_s +
      " target=" + name.to_s + " move=" + move_id.to_s +
      " damage=" + damage.to_s)
  end

  def cg_move_effect_apply_heal_recoil(user, move_id, damage_done)
    heal = ALBERT_CG::MOVE_EFFECT.healing_percent(move_id)
    if heal > 0 && !state?(ALBERT_CG::MOVE_EFFECT::STATE_HEAL_BLOCK)
      amount = [maxhp * heal / 100, maxhp - hp].min
      if amount > 0
        self.hp += amount
        @hp_damage = -amount
        ALBERT_CG::MOVE_EFFECT.log("HEAL target=" + name.to_s +
          " move=" + move_id.to_s + " amount=" + amount.to_s)
      end
    elsif heal < 0
      cost = [user.maxhp * (-heal) / 100, user.hp - 1].min
      if cost > 0
        user.hp -= cost
        user.hp_damage = cost if user.respond_to?(:hp_damage=)
        ALBERT_CG::MOVE_EFFECT.log("HP_COST user=" + user.name.to_s +
          " move=" + move_id.to_s + " amount=" + cost.to_s)
      end
    end

    drain = ALBERT_CG::MOVE_EFFECT.drain_percent(move_id)
    if drain > 0 && damage_done.to_i > 0 &&
       !user.state?(ALBERT_CG::MOVE_EFFECT::STATE_HEAL_BLOCK)
      amount = [damage_done.to_i * drain / 100, user.maxhp - user.hp].min
      if amount > 0
        user.hp += amount
        user.hp_damage = -amount if user.respond_to?(:hp_damage=)
        ALBERT_CG::MOVE_EFFECT.log("DRAIN user=" + user.name.to_s +
          " move=" + move_id.to_s + " amount=" + amount.to_s)
      end
    elsif drain < 0 && damage_done.to_i > 0
      amount = [damage_done.to_i * (-drain) / 100, user.hp - 1].min
      if amount > 0
        user.hp -= amount
        user.hp_damage = amount if user.respond_to?(:hp_damage=)
        ALBERT_CG::MOVE_EFFECT.log("RECOIL user=" + user.name.to_s +
          " move=" + move_id.to_s + " amount=" + amount.to_s)
      end
    end
  end

  alias cg_move_v230_skill_effect skill_effect
  def skill_effect(user, skill)
    move_id = ALBERT_CG::MOVE_EFFECT.move_id(skill)

    if move_id > 0 && state?(ALBERT_CG::MOVE_EFFECT::STATE_PROTECT) &&
       user != self && user.actor? != actor?
      clear_action_results
      @skipped = true
      ALBERT_CG::MOVE_EFFECT.log("PROTECT_BLOCK target=" + name.to_s +
        " user=" + user.name.to_s + " move=" + move_id.to_s)
      return
    end

    cg_move_v230_skill_effect(user, skill)
    return if move_id <= 0
    return if @skipped || @missed || @evaded

    damage_done = @hp_damage.to_i > 0 ? @hp_damage.to_i : 0

    cg_move_effect_apply_special_damage(user, skill, move_id)
    cg_move_effect_apply_ailment(user, move_id)
    cg_move_effect_apply_stats(user, move_id)

    flinch = ALBERT_CG::MOVE_EFFECT.flinch_chance(move_id)
    if flinch > 0 && rand(100) < flinch && !state?(ALBERT_CG::MOVE_EFFECT::STATE_FLINCH)
      add_state(ALBERT_CG::MOVE_EFFECT::STATE_FLINCH)
      @added_states.push(ALBERT_CG::MOVE_EFFECT::STATE_FLINCH) unless
        @added_states.include?(ALBERT_CG::MOVE_EFFECT::STATE_FLINCH)
      ALBERT_CG::MOVE_EFFECT.log("FLINCH target=" + name.to_s +
        " move=" + move_id.to_s)
    end

    cg_move_effect_apply_protect(user, move_id)
    cg_move_effect_apply_heal_recoil(user, move_id, damage_done)

    ALBERT_CG::MOVE_EFFECT.log("EFFECT user=" + user.name.to_s +
      " target=" + name.to_s + " move=" + move_id.to_s + ":" + skill.name.to_s +
      " " + ALBERT_CG::MOVE_EFFECT.effect_summary(move_id))
  end

  alias cg_move_v230_critical cg_pokemon_critical?
  def cg_pokemon_critical?(user, obj = nil)
    if obj != nil
      mid = ALBERT_CG::MOVE_EFFECT.move_id(obj)
      stage = ALBERT_CG::MOVE_EFFECT.crit_stage(mid)
      if stage > 0
        bonus = stage * 12
        return true if rand(100) < bonus
      end
    end
    return cg_move_v230_critical(user, obj)
  end
end

class Scene_Title < Scene_Base
  alias cg_move_v230_load_database load_database
  def load_database
    cg_move_v230_load_database
    ALBERT_CG::MOVE_EFFECT.apply
  end

  alias cg_move_v230_load_bt_database load_bt_database
  def load_bt_database
    cg_move_v230_load_bt_database
    ALBERT_CG::MOVE_EFFECT.apply
  end
end


#==============================================================================
# ■ v2.3 F11 Move Effect Scenario
#------------------------------------------------------------------------------
# 【用途】
#  不修改正式遊戲流程；只在地圖按 F11 時建立指定測試隊伍與 Enemy。
#  用來驗證 Multi-hit / Drain / Status / Stat Stage / Protect / PMD Native fallback。
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    TEST_TROOP_ID = 698
    TEST_LEVEL = 30
    TEST_ALLIES = [
      {:dex=>15, :level=>30, :ability=>68, :moves=>[41,42,14,92]},     # 大針蜂
      {:dex=>3,  :level=>30, :ability=>65, :moves=>[202,79,74,182]},  # 妙蛙花
      {:dex=>25, :level=>30, :ability=>9,  :moves=>[85,86,104,98]},   # 皮卡丘
    ]
    TEST_ENEMIES = [
      {:dex=>9,   :level=>30, :ability=>67,  :moves=>[55,44,110,182]}, # 水箭龜
      {:dex=>143, :level=>30, :ability=>47,  :moves=>[34,44,156,133]}, # 卡比獸
      {:dex=>94,  :level=>30, :ability=>130, :moves=>[247,109,188,94]},# 耿鬼
      {:dex=>376, :level=>30, :ability=>29,  :moves=>[232,428,94,89]}, # 巨金怪
    ]

    begin
      CG_VK_F11 = 0x7A unless const_defined?(:CG_VK_F11)
      CG_GET_ASYNC_KEY_STATE_F11 =
        Win32API.new("user32", "GetAsyncKeyState", "i", "i") unless
        const_defined?(:CG_GET_ASYNC_KEY_STATE_F11)
    rescue
      CG_GET_ASYNC_KEY_STATE_F11 = nil unless
        const_defined?(:CG_GET_ASYNC_KEY_STATE_F11)
    end

    def self.f11_trigger?
      api = CG_GET_ASYNC_KEY_STATE_F11
      return false if api == nil
      down = (api.call(CG_VK_F11) & 0x8000) != 0
      trigger = down && @f11_down != true
      @f11_down = down
      return trigger
    rescue
      return false
    end

    def self.configure_test_actor(cfg)
      return if master == nil
      actor = $game_actors[master.actor_id_for_dex(cfg[:dex])]
      return if actor == nil
      master.configure_actor(actor, cfg)
      actor.cg_reset_stat_stages if actor.respond_to?(:cg_reset_stat_stages)
      log("TEST_ALLY dex=" + cfg[:dex].to_s + " name=" + actor.name.to_s +
        " lv=" + actor.level.to_s + " pmd=" +
        (actor.respond_to?(:cg_pmd_sprite_key) ? actor.cg_pmd_sprite_key.to_s : "") +
        " moves=" + cfg[:moves].collect { |mid| master.move_name(mid) }.inspect)
    end

    def self.configure_test_enemy(cfg)
      return if master == nil
      master.configure_enemy_data(cfg)
      log("TEST_ENEMY dex=" + cfg[:dex].to_s +
        " name=" + master.name_for_dex(cfg[:dex]) +
        " lv=" + cfg[:level].to_s + " pmd=" + master.pmd_key_for_dex(cfg[:dex]) +
        " moves=" + cfg[:moves].collect { |mid| master.move_name(mid) }.inspect)
    end

    def self.make_test_troop
      return if master == nil
      master.ensure_index($data_troops, TEST_TROOP_ID)
      xs = [ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_BACK_X, ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[2],
            ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[2]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg, index|
        configure_test_enemy(cfg)
        members.push(ALBERT_CG::SPECIES26.make_troop_member(
          master.enemy_id_for_dex(cfg[:dex]), xs[index] || 180, ys[index] || 220))
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID, "Pokemon Move Effect v2.3 Scenario", members)
    end

    def self.prepare_test_party
      return false if master == nil || $game_party == nil
      ids = TEST_ALLIES.collect { |cfg| master.actor_id_for_dex(cfg[:dex]) }
      if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
        ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids)
      end
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized, true)
      $game_party.cg_enable_direct_pmd_test_party! if
        $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each { |cfg| configure_test_actor(cfg) }
      human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if human != nil
        human.change_level(TEST_LEVEL, false)
        human.recover_all if human.respond_to?(:recover_all)
      end
      return true
    end

    def self.start_effect_test
      reset_log
      prepare_test_party
      make_test_troop
      @effect_test_active = true
      log("F11_START troop=" + TEST_TROOP_ID.to_s)
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    end

    def self.effect_test_active?
      return @effect_test_active == true
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_move_v230_scene_map_update update
  def update
    cg_move_v230_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::MOVE_EFFECT.f11_trigger?
      Sound.play_decision
      ALBERT_CG::MOVE_EFFECT.start_effect_test
    end
  end
end

module ALBERT_CG
  class << self
    alias cg_move_v230_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_move_v230_bootstrap_demo_party
      if ALBERT_CG::MOVE_EFFECT.effect_test_active?
        ALBERT_CG::MOVE_EFFECT::TEST_ALLIES.each do |cfg|
          ALBERT_CG::MOVE_EFFECT.configure_test_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::MOVE_EFFECT::TEST_LEVEL, false)
          human.recover_all if human.respond_to?(:recover_all)
        end
      end
      return result
    end
  end
end
