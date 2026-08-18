# RMVX_SCRIPT_INDEX: 187
# RMVX_SCRIPT_ID: 82110001
# RMVX_SCRIPT_NAME: CG Pokemon Six Stat & 4v4 Damage Core v2.1.0
# RMVX_SOURCE_SHA256: 03cdaf1902a7c3b91183cd36a47fdfd13267aa440cb7e34dc96eb68338583c7a

#==============================================================================
# ■ CG Pokemon Six Stat & 4v4 Damage Core v2.1.0
#------------------------------------------------------------------------------
# 【用途】
#  將 CG Pet Battle Prototype 的寶可夢戰鬥正式改為六維能力值：
#    HP / ATK / DEF / SpA / SpD / SPE
#  並依本作「一名人類＋三隻寶可夢」對抗 1～4 名敵人的節奏，重新校準
#  HP、傷害公式、屬性倍率、技能熟練增傷與個體配點。
#
# 【核心規則】
#  1. 寶可夢 SpA（特攻）與 SpD（特防）完全分離，傷害公式不再使用
#     VX 單一 SPI 同時代表兩者。SPI 僅保留作舊 UI／舊腳本相容顯示，
#     對寶可夢預設顯示 SpA。
#  2. 正式六維 API：
#       battler.cg_hp_stat   / cg_atk_stat / cg_def_stat
#       battler.cg_spa       / cg_spd      / cg_spe
#  3. 寶可夢能力值以原作 Base Stat + 等級為核心，再套：
#       個性 Nature → 掉檔 → BP 配點。
#     HP 為配合 4v4 集火，額外乘 175%。
#  4. 物理：ATK 對 DEF；特殊：SpA 對 SpD。
#     Mixed 不再平均 ATK/SpA 後只算一次，而是分別計算物理／特殊傷害，
#     再依比例合成。預設 50/50，可用 <mixed_physical: 70> 調整。
#  5. 基礎傷害保留 Pokémon 結構：
#       (((2*Lv/5+2) * Power * Offense/Defense) / 50) + 2
#     再乘熟練、STAB、屬性、暴擊、90～100%亂數、Guard。
#  6. 4v4 屬性倍率柔化：
#       弱點 1.60x、雙弱點 2.56x、抗性 0.63x、雙抗約 0.40x、免疫 0。
#     STAB 仍 1.50x，暴擊仍 1.50x。
#  7. Pokémon Move 熟練 Lv1～10 改為 100%～127%（每級 +3%）。
#     人類技能仍沿用原本 Skill Level Profile，待六職業技能階段個別平衡。
#
# 【六項掉檔／BP】
#  正式索引：
#    0 HP、1 ATK、2 DEF、3 SpA、4 SpD、5 SPE
#  舊五項資料會自動遷移：
#    舊「速度」→ SPE；舊「魔法」掉檔同時作為 SpA/SpD 初始品質；
#    舊魔法 BP 則平均拆給 SpA/SpD，避免舊存檔平白增加總配點。
#
# 【人類相容】
#  人類仍使用 Tankentai SBS 與原 VX Actor/Class 成長；本版提供六維 API，
#  並將人類配點同步擴為 HP/ATK/DEF/SpA/SpD/SPE 六項。
#  人類 SpD 具有獨立 BP／Nature 修正；六職業正式 Base Stat 曲線會在
#  後續 Human Job Full Skill/Trait Phase 集中設計。
#
# 【可調參數】
#  HP_SCALE_PERCENT          = 175  # 4v4 HP 曲線
#  STAB_PERCENT              = 150
#  WEAK_PERCENT              = 160
#  RESIST_PERCENT            = 63
#  CRITICAL_PERCENT          = 150
#  RANDOM_MIN_PERCENT        = 90
#  POKEMON_MOVE_MASTERY_STEP = 3
#
# 【測試／LOG】
#  遊戲啟動會重建：CG_DamageCurve_v2_1.log
#  內容包含 Lv5/20/40/60、Power40/60/80/100 的中性/STAB/弱點傷害百分比、
#  4 人集火估算，以及 #0001～#0026 六維資料完整性。
#
# 【事件／腳本呼叫範例】
#  actor.cg_spa                       # 真正特攻
#  actor.cg_spd                       # 真正特防
#  actor.cg_spe                       # 真正速度
#  actor.cg_six_stat(:atk)            # 指定六維能力
#  enemy.cg_six_stat(:spd)
#  ALBERT_CG::SIX_STAT_DAMAGE.write_benchmark_log
#
# 【技能 Mixed 例】
#  <damage_class: mixed>
#  <mixed_physical: 70>   # 70% 物理 + 30% 特殊
#
# 【腳本位置】
#  放在 Species26 Auto Evolution／Battle Content 之後，
#  PMD BattleInit Debug／AutoTest 之前。此頁是 v2.1 傷害最終權威。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_SixStatDamageCore"] = "2.1.0"

module ALBERT_CG
  module SIX_STAT_DAMAGE
    VERSION = "2.1.0"
    LOG_FILE = "CG_DamageCurve_v2_1.log"
    RUNTIME_LOG_FILE = "CG_DamageRuntime_v2_1.log"

    STAT_KEYS = [:hp, :atk, :def, :spa, :spd, :spe]
    STAT_NAMES = ["HP", "ATK", "DEF", "SpA", "SpD", "SPE"]

    HP_SCALE_PERCENT = 175
    BASE_IV = 31
    GRADE_LOSS_PERCENT_PER_STEP = 2
    HP_BP_VALUE = 5
    OTHER_BP_VALUE = 1

    STAB_PERCENT = 150
    WEAK_PERCENT = 160
    RESIST_PERCENT = 63
    CRITICAL_PERCENT = 150
    RANDOM_MIN_PERCENT = 90
    RANDOM_MAX_PERCENT = 100
    DAMAGE_GLOBAL_PERCENT = 100

    POKEMON_MOVE_MASTERY_STEP = 3
    POKEMON_MOVE_MASTERY_MAX = 127

    # 25 種原作個性，正式拆成 ATK/DEF/SpA/SpD/SPE。
    # value = [ATK, DEF, SpA, SpD, SPE] 百分比
    NATURE_RATES = {
       0=>[100,100,100,100,100],  1=>[110, 90,100,100,100],
       2=>[110,100,100,100, 90],  3=>[110,100, 90,100,100],
       4=>[110,100,100, 90,100],  5=>[ 90,110,100,100,100],
       6=>[100,100,100,100,100],  7=>[100,110,100,100, 90],
       8=>[100,110, 90,100,100],  9=>[100,110,100, 90,100],
      10=>[ 90,100,100,100,110], 11=>[100, 90,100,100,110],
      12=>[100,100,100,100,100], 13=>[100,100, 90,100,110],
      14=>[100,100,100, 90,110], 15=>[ 90,100,110,100,100],
      16=>[100, 90,110,100,100], 17=>[100,100,110,100, 90],
      18=>[100,100,100,100,100], 19=>[100,100,110, 90,100],
      20=>[ 90,100,100,110,100], 21=>[100, 90,100,110,100],
      22=>[100,100,100,110, 90], 23=>[100,100, 90,110,100],
      24=>[100,100,100,100,100]
    }

    def self.redefine_constant(owner, name, value)
      owner.send(:remove_const, name) if owner.const_defined?(name)
      owner.const_set(name, value)
    rescue
    end

    # 六項配點正式化。舊腳本皆在 Runtime 查常數，因此可於新遊戲建立前重定義。
    redefine_constant(ALBERT_CG, :GRADE_STAT_COUNT, 6)
    redefine_constant(ALBERT_CG, :PET_BP_STAT_NAMES,
      ["體力", "物攻", "物防", "特攻", "特防", "速度"])
    redefine_constant(ALBERT_CG, :PET_BP_STAT_EFFECTS, [
      "每點最大 HP +5", "每點 ATK +1", "每點 DEF +1",
      "每點 SpA +1", "每點 SpD +1", "每點 SPE +1"
    ])
    redefine_constant(ALBERT_CG, :ACTOR_BP_STAT_NAMES,
      ["體力", "物攻", "物防", "特攻", "特防", "速度"])
    redefine_constant(ALBERT_CG, :ACTOR_BP_STAT_EFFECTS, [
      "每點最大 HP +5", "每點 ATK +1", "每點 DEF +1",
      "每點 SpA +1", "每點 SpD +1", "每點 SPE +1"
    ])

    def self.nature_rate(nature_id, key)
      return 100 if key == :hp
      row = NATURE_RATES[nature_id.to_i] || NATURE_RATES[0]
      index = {:atk=>0, :def=>1, :spa=>2, :spd=>3, :spe=>4}[key]
      return index == nil ? 100 : row[index].to_i
    end

    def self.stat_from_base(base, level, key, nature_percent = 100,
                            grade_loss = 0, bp = 0)
      base = [base.to_i, 1].max
      level = [[level.to_i, 1].max, 100].min
      grade_loss = [[grade_loss.to_i, 0].max, 4].min
      bp = [bp.to_i, 0].max
      grade_percent = 100 - grade_loss * GRADE_LOSS_PERCENT_PER_STEP
      if key == :hp
        raw = (((2 * base + BASE_IV) * level) / 100) + level + 10
        raw = raw * grade_percent / 100
        raw = raw * HP_SCALE_PERCENT / 100
        raw += bp * HP_BP_VALUE
        return [raw.to_i, 1].max
      end
      raw = (((2 * base + BASE_IV) * level) / 100) + 5
      raw = raw * nature_percent.to_i / 100
      raw = raw * grade_percent / 100
      raw += bp * OTHER_BP_VALUE
      return [raw.to_i, 1].max
    end

    def self.species_base_stats(dex)
      dex = dex.to_i
      if defined?(ALBERT_CG::POKEMON_MASTER) &&
         ALBERT_CG::POKEMON_MASTER.respond_to?(:base_stats_for_dex)
        value = ALBERT_CG::POKEMON_MASTER.base_stats_for_dex(dex)
        return value if value != nil
      end
      if defined?(ALBERT_CG::SPECIES26) && ALBERT_CG::SPECIES26.respond_to?(:base_stats_for_dex)
        return ALBERT_CG::SPECIES26.base_stats_for_dex(dex)
      end
      return nil
    rescue
      return nil
    end

    def self.soft_type_rate(raw)
      raw = raw.to_i
      return 0 if raw <= 0
      return 40 if raw == 25
      return RESIST_PERCENT if raw == 50
      return 100 if raw == 100
      return WEAK_PERCENT if raw == 200
      return WEAK_PERCENT * WEAK_PERCENT / 100 if raw == 400
      # 未來若 Ability／特殊規則產生非標準倍率，保留近似比例。
      return [raw, 800].min
    end

    def self.mastery_percent(level)
      level = [[level.to_i, 1].max, 10].min
      value = 100 + (level - 1) * POKEMON_MOVE_MASTERY_STEP
      return [value, POKEMON_MOVE_MASTERY_MAX].min
    end

    def self.pokemon_formula(level, power, offense, defense)
      level = [level.to_i, 1].max
      power = [power.to_i, 1].max
      offense = [offense.to_i, 1].max
      defense = [defense.to_i, 1].max
      value = (((((2.0 * level / 5.0) + 2.0) * power * offense / defense) /
        50.0) + 2.0)
      value = value * DAMAGE_GLOBAL_PERCENT / 100
      return [value.to_i, 1].max
    end

    def self.percent_text(value, hp)
      return "0.0%" if hp.to_i <= 0
      return sprintf("%.1f%%", value.to_f * 100.0 / hp.to_f)
    end

    def self.benchmark_damage(level, power, modifier_percent)
      stat = stat_from_base(80, level, :atk, 100, 0, 0)
      hp = stat_from_base(80, level, :hp, 100, 0, 0)
      damage = pokemon_formula(level, power, stat, stat)
      damage = damage * modifier_percent.to_i / 100
      damage = damage * 95 / 100 # benchmark 使用 90～100% 中間值
      return [damage, hp]
    end

    def self.reset_runtime_log
      File.open(RUNTIME_LOG_FILE, "wb") do |file|
        file.write("CG SIX STAT RUNTIME DAMAGE LOG v2.1.0\r\n")
        file.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
        file.write("------------------------------------------------------------\r\n")
      end
    rescue
    end

    def self.runtime_log(text)
      File.open(RUNTIME_LOG_FILE, "ab") do |file|
        file.write("[" + Time.now.strftime("%H:%M:%S") + "] " + text.to_s + "\r\n")
      end
    rescue
    end

    def self.log_battler_stats(label, battler)
      return if battler == nil
      dex = battler.respond_to?(:cg_national_dex) ? battler.cg_national_dex.to_i : 0
      level = battler.respond_to?(:cg_pokemon_level) ? battler.cg_pokemon_level.to_i : 0
      runtime_log(label.to_s + " name=" + battler.name.to_s +
        " dex=" + dex.to_s + " lv=" + level.to_s +
        " HP=" + (battler.respond_to?(:maxhp) ? battler.maxhp.to_i.to_s : "?") +
        " ATK=" + (battler.respond_to?(:cg_atk_stat) ? battler.cg_atk_stat.to_i.to_s : "?") +
        " DEF=" + (battler.respond_to?(:cg_def_stat) ? battler.cg_def_stat.to_i.to_s : "?") +
        " SpA=" + (battler.respond_to?(:cg_spa) ? battler.cg_spa.to_i.to_s : "?") +
        " SpD=" + (battler.respond_to?(:cg_spd) ? battler.cg_spd.to_i.to_s : "?") +
        " SPE=" + (battler.respond_to?(:cg_spe) ? battler.cg_spe.to_i.to_s : "?"))
    rescue
    end

    def self.write_benchmark_log
      File.open(LOG_FILE, "wb") do |file|
        file.write("CG SIX STAT / 4v4 DAMAGE BENCHMARK v2.1.0\r\n")
        file.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
        file.write("TEAM=1 Human + 3 Pokemon; standard enemy formation=3~4 units\r\n")
        file.write("HP_SCALE=175% STAB=150% WEAK=160% RESIST=63% CRIT=150% RANDOM=90~100%\r\n")
        file.write("TARGET: neutral Power60 STAB ~= 13~18% HP; Power80 STAB+weak ~= 25~35% HP\r\n")
        file.write("------------------------------------------------------------\r\n")
        [5,20,40,60].each do |level|
          file.write("LEVEL=" + level.to_s + "\r\n")
          [40,60,80,100].each do |power|
            neutral, hp = benchmark_damage(level, power, 100)
            stab, dummy = benchmark_damage(level, power, STAB_PERCENT)
            weak, dummy = benchmark_damage(level, power, STAB_PERCENT * WEAK_PERCENT / 100)
            double_weak, dummy = benchmark_damage(level, power,
              STAB_PERCENT * WEAK_PERCENT * WEAK_PERCENT / 10000)
            hits = weak <= 0 ? 99 : ((hp.to_f / weak.to_f).ceil)
            rounds = (hits.to_f / 4.0).ceil
            file.write(sprintf("  P%03d neutral=%s stab=%s stab+weak=%s double=%s weak_hits=%d focus_rounds=%d\r\n",
              power, percent_text(neutral,hp), percent_text(stab,hp),
              percent_text(weak,hp), percent_text(double_weak,hp), hits, rounds))
          end
        end
        ok = 0
        if defined?(ALBERT_CG::SPECIES26)
          (1..26).each do |dex|
            stats = species_base_stats(dex)
            ok += 1 if stats != nil && stats.size >= 6
          end
        end
        file.write("------------------------------------------------------------\r\n")
        file.write("SPECIES26_SIX_STATS=" + ok.to_s + "/26\r\n")
        file.write("BP_INDEX=HP/ATK/DEF/SpA/SpD/SPE\r\n")
        file.write("RESULT=" + (ok == 26 ? "PASS" : "CHECK") + "\r\n")
      end
    rescue
    end
  end
end

#==============================================================================
# ■ Pokemon Combat Core：4v4 屬性倍率柔化
#==============================================================================
if defined?(ALBERT_CG::POKEMON_COMBAT)
  module ALBERT_CG::POKEMON_COMBAT
    class << self
      alias cg_v210_raw_type_chart_percent type_chart_percent unless method_defined?(:cg_v210_raw_type_chart_percent)
      def type_chart_percent(attack_type, defense_types)
        raw = cg_v210_raw_type_chart_percent(attack_type, defense_types)
        return ALBERT_CG::SIX_STAT_DAMAGE.soft_type_rate(raw)
      end
    end
  end
end

#==============================================================================
# ■ Game_Actor：六維資料、舊五項資料遷移、最終能力值
#==============================================================================
class Game_Actor < Game_Battler
  alias cg_v210_prepare_pet_data cg_prepare_pet_data if method_defined?(:cg_prepare_pet_data)
  def cg_prepare_pet_data
    if respond_to?(:cg_pet?) && cg_pet?
      if @cg_grade_loss != nil && @cg_grade_loss.size == 5
        old = @cg_grade_loss.dup
        @cg_grade_loss = [old[0], old[1], old[2], old[4], old[4], old[3]]
      end
      if @cg_bonus_points != nil && @cg_bonus_points.size == 5
        old = @cg_bonus_points.dup
        magic = old[4].to_i
        spa_points = (magic + 1) / 2
        spd_points = magic / 2
        @cg_bonus_points = [old[0], old[1], old[2], spa_points, spd_points, old[3]]
      end
    end
    return cg_v210_prepare_pet_data if defined?(cg_v210_prepare_pet_data)
  end

  alias cg_v210_prepare_actor_growth_data cg_prepare_actor_growth_data if method_defined?(:cg_prepare_actor_growth_data)
  def cg_prepare_actor_growth_data
    if !(respond_to?(:cg_pet?) && cg_pet?) && @cg_actor_bonus_points != nil && @cg_actor_bonus_points.size == 5
      old = @cg_actor_bonus_points.dup
      magic = old[4].to_i
      @cg_actor_bonus_points = [old[0], old[1], old[2], (magic + 1) / 2, magic / 2, old[3]]
    end
    if !(respond_to?(:cg_pet?) && cg_pet?) && @cg_actor_bonus_points == nil
      @cg_actor_bonus_points = Array.new(6, 0)
    end
    # 不呼叫舊版 size!=5 的重置邏輯；在這裡直接維護六項資料。
    return false if respond_to?(:cg_pet?) && cg_pet?
    allocated = 0
    @cg_actor_bonus_points.each { |value| allocated += value.to_i }
    if @cg_actor_bp_awarded_level == nil
      earned = [@level.to_i - 1, 0].max * ALBERT_CG::ACTOR_BP_PER_LEVEL
      @cg_actor_unspent_bp = [earned - allocated, 0].max if @cg_actor_unspent_bp == nil
      @cg_actor_bp_awarded_level = @level.to_i
    else
      @cg_actor_unspent_bp = 0 if @cg_actor_unspent_bp == nil
      if @level.to_i > @cg_actor_bp_awarded_level.to_i
        @cg_actor_unspent_bp += (@level.to_i - @cg_actor_bp_awarded_level.to_i) * ALBERT_CG::ACTOR_BP_PER_LEVEL
      end
      @cg_actor_bp_awarded_level = @level.to_i
    end
    @cg_actor_unspent_bp = [@cg_actor_unspent_bp.to_i, 0].max
    return true
  rescue
    return cg_v210_prepare_actor_growth_data if defined?(cg_v210_prepare_actor_growth_data)
    return false
  end

  def cg_six_stat_pokemon?
    return false unless respond_to?(:cg_national_dex)
    return cg_national_dex.to_i > 0
  rescue
    return false
  end

  def cg_six_stat_dex
    return cg_national_dex.to_i if respond_to?(:cg_national_dex)
    return 0
  rescue
    return 0
  end

  def cg_six_nature_rate(key)
    nature_id = respond_to?(:cg_nature_id) ? cg_nature_id.to_i : 0
    return ALBERT_CG::SIX_STAT_DAMAGE.nature_rate(nature_id, key)
  rescue
    return 100
  end

  def cg_six_grade_loss(index)
    return 0 unless respond_to?(:cg_pet?) && cg_pet?
    cg_prepare_pet_data if respond_to?(:cg_prepare_pet_data)
    return @cg_grade_loss[index.to_i].to_i if @cg_grade_loss != nil && @cg_grade_loss[index.to_i] != nil
    return 0
  rescue
    return 0
  end

  def cg_six_bp(index)
    if respond_to?(:cg_pet?) && cg_pet?
      cg_prepare_pet_data if respond_to?(:cg_prepare_pet_data)
      return @cg_bonus_points[index.to_i].to_i if @cg_bonus_points != nil && @cg_bonus_points[index.to_i] != nil
      return 0
    end
    cg_prepare_actor_growth_data if respond_to?(:cg_prepare_actor_growth_data)
    return @cg_actor_bonus_points[index.to_i].to_i if @cg_actor_bonus_points != nil && @cg_actor_bonus_points[index.to_i] != nil
    return 0
  rescue
    return 0
  end

  def cg_six_stat(key)
    key = key.to_sym rescue key
    if cg_six_stat_pokemon?
      stats = ALBERT_CG::SIX_STAT_DAMAGE.species_base_stats(cg_six_stat_dex)
      return 1 if stats == nil || stats.size < 6
      index = {:hp=>0,:atk=>1,:def=>2,:spa=>3,:spd=>4,:spe=>5}[key]
      return 1 if index == nil
      return ALBERT_CG::SIX_STAT_DAMAGE.stat_from_base(stats[index], level, key,
        cg_six_nature_rate(key), cg_six_grade_loss(index), cg_six_bp(index))
    end
    # 人類沿用 VX 成長，但六維 API 分開讀。SpD 先以 SPI 基底＋獨立配點表示，
    # 六職業 Master Data 階段會再改成職業專屬 Base Stat 曲線。
    case key
    when :hp;  return maxhp
    when :atk; return atk
    when :def; return self.def
    when :spa; return spi
    when :spd
      raw = cg_v210_human_raw(:albert_cg_v09_actor_growth_base_spi, spi)
      raw += cg_six_bp(4)
      raw = raw.to_i * cg_six_nature_rate(:spd) / 100
      # 舊 VX 裝備／狀態的 SPI 額外值暫同時作用於 SpA/SpD。
      extra = spi.to_i - base_spi.to_i
      return [raw + extra, 1].max
    when :spe; return agi
    end
    return 1
  rescue
    return 1
  end

  def cg_hp_stat;  return cg_six_stat(:hp);  end
  def cg_atk_stat; return cg_six_stat(:atk); end
  def cg_def_stat; return cg_six_stat(:def); end
  def cg_spa;      return cg_six_stat(:spa); end
  def cg_spd;      return cg_six_stat(:spd); end
  def cg_spe;      return cg_six_stat(:spe); end

  # 最終 VX 相容能力：寶可夢 UI/舊腳本看到的 ATK/DEF/SPI/AGI 與六維同步。
  alias cg_v210_prev_base_maxhp base_maxhp
  alias cg_v210_prev_base_maxmp base_maxmp
  alias cg_v210_prev_base_atk base_atk
  alias cg_v210_prev_base_def base_def
  alias cg_v210_prev_base_spi base_spi
  alias cg_v210_prev_base_agi base_agi

  # 一般人類 Actor 也改用六項 BP 索引，避免舊 v0.9 將 index3/4 誤當成 SPE/SPI。
  # albert_cg_v09_actor_growth_base_* 是 v0.9 加配點前保存的原始能力入口。
  def cg_v210_human_raw(method_name, fallback)
    return send(method_name) if respond_to?(method_name)
    return fallback.to_i
  rescue
    return fallback.to_i
  end

  def base_maxhp
    return cg_six_stat(:hp) if cg_six_stat_pokemon?
    cg_prepare_actor_growth_data if respond_to?(:cg_prepare_actor_growth_data)
    raw = cg_v210_human_raw(:albert_cg_v09_actor_growth_base_maxhp, cg_v210_prev_base_maxhp)
    return [raw.to_i + cg_six_bp(0) * 5, 1].max
  end

  def base_maxmp
    return cg_v210_prev_base_maxmp if cg_six_stat_pokemon?
    # MP 是技能資源，不再由 SpA/SpD 配點偷渡增加。
    return [cg_v210_human_raw(:albert_cg_v09_actor_growth_base_maxmp, cg_v210_prev_base_maxmp), 0].max
  end

  def base_atk
    return cg_six_stat(:atk) if cg_six_stat_pokemon?
    raw = cg_v210_human_raw(:albert_cg_v09_actor_growth_base_atk, cg_v210_prev_base_atk)
    raw += cg_six_bp(1)
    return [raw.to_i * cg_six_nature_rate(:atk) / 100, 1].max
  end

  def base_def
    return cg_six_stat(:def) if cg_six_stat_pokemon?
    raw = cg_v210_human_raw(:albert_cg_v09_actor_growth_base_def, cg_v210_prev_base_def)
    raw += cg_six_bp(2)
    return [raw.to_i * cg_six_nature_rate(:def) / 100, 1].max
  end

  def base_spi
    return cg_six_stat(:spa) if cg_six_stat_pokemon?
    raw = cg_v210_human_raw(:albert_cg_v09_actor_growth_base_spi, cg_v210_prev_base_spi)
    raw += cg_six_bp(3)
    return [raw.to_i * cg_six_nature_rate(:spa) / 100, 1].max
  end

  def base_agi
    return cg_six_stat(:spe) if cg_six_stat_pokemon?
    raw = cg_v210_human_raw(:albert_cg_v09_actor_growth_base_agi, cg_v210_prev_base_agi)
    raw += cg_six_bp(5)
    return [raw.to_i * cg_six_nature_rate(:spe) / 100, 1].max
  end

  # 六項 Clone BP 顯示／操作。
  def cg_growth_stat_value(index)
    case index.to_i
    when 0; return maxhp
    when 1; return cg_atk_stat
    when 2; return cg_def_stat
    when 3; return cg_spa
    when 4; return cg_spd
    when 5; return cg_spe
    end
    return 0
  end

  def cg_growth_stat_value_text(index)
    return cg_growth_stat_value(index).to_s
  end

  # Universal Growth：一般 Actor 也正式擴成六項。
  def cg_growth_bonus_point(index)
    return cg_bonus_point(index) if respond_to?(:cg_pet?) && cg_pet?
    cg_prepare_actor_growth_data
    return 0 if index.to_i < 0 || index.to_i >= 6
    return @cg_actor_bonus_points[index.to_i].to_i
  end

  def cg_growth_allocate(index, amount = 1)
    return cg_allocate_bp(index, amount) if respond_to?(:cg_pet?) && cg_pet?
    index = index.to_i
    amount = amount.to_i
    return false if index < 0 || index >= 6 || amount <= 0
    cg_prepare_actor_growth_data
    return false if @cg_actor_unspent_bp.to_i < amount
    old_maxhp = maxhp
    old_hp = hp
    @cg_actor_bonus_points[index] += amount
    @cg_actor_unspent_bp -= amount
    hp_gain = maxhp - old_maxhp
    self.hp = old_hp + hp_gain if hp_gain > 0 && old_hp > 0
    return true
  end

  def cg_growth_refund(index, amount = 1)
    return cg_refund_bp(index, amount) if respond_to?(:cg_pet?) && cg_pet?
    index = index.to_i
    amount = amount.to_i
    return false if index < 0 || index >= 6 || amount <= 0
    cg_prepare_actor_growth_data
    return false if @cg_actor_bonus_points[index].to_i < amount
    @cg_actor_bonus_points[index] -= amount
    @cg_actor_unspent_bp += amount
    self.hp = [hp, maxhp].min
    return true
  end
end

#==============================================================================
# ■ Game_Enemy：由 Species Base Stat + Enemy Level 即時計算六維
#==============================================================================
class Game_Enemy < Game_Battler
  def cg_six_stat_pokemon?
    return respond_to?(:cg_national_dex) && cg_national_dex.to_i > 0
  rescue
    return false
  end

  def cg_six_stat(key)
    key = key.to_sym rescue key
    unless cg_six_stat_pokemon?
      case key
      when :hp; return maxhp
      when :atk; return atk
      when :def; return self.def
      when :spa; return spi
      when :spd; return [((spi.to_i * 3 + self.def.to_i) / 4), 1].max
      when :spe; return agi
      end
      return 1
    end
    stats = ALBERT_CG::SIX_STAT_DAMAGE.species_base_stats(cg_national_dex.to_i)
    return 1 if stats == nil || stats.size < 6
    index = {:hp=>0,:atk=>1,:def=>2,:spa=>3,:spd=>4,:spe=>5}[key]
    return 1 if index == nil
    return ALBERT_CG::SIX_STAT_DAMAGE.stat_from_base(stats[index], cg_pokemon_level,
      key, 100, 0, 0)
  rescue
    return 1
  end

  def cg_hp_stat;  return cg_six_stat(:hp);  end
  def cg_atk_stat; return cg_six_stat(:atk); end
  def cg_def_stat; return cg_six_stat(:def); end
  def cg_spa;      return cg_six_stat(:spa); end
  def cg_spd;      return cg_six_stat(:spd); end
  def cg_spe;      return cg_six_stat(:spe); end

  alias cg_v210_enemy_base_maxhp base_maxhp
  def base_maxhp
    return cg_six_stat(:hp) if cg_six_stat_pokemon?
    return cg_v210_enemy_base_maxhp
  end

  alias cg_v210_enemy_base_atk base_atk
  def base_atk
    return cg_six_stat(:atk) if cg_six_stat_pokemon?
    return cg_v210_enemy_base_atk
  end

  alias cg_v210_enemy_base_def base_def
  def base_def
    return cg_six_stat(:def) if cg_six_stat_pokemon?
    return cg_v210_enemy_base_def
  end

  alias cg_v210_enemy_base_spi base_spi
  def base_spi
    return cg_six_stat(:spa) if cg_six_stat_pokemon?
    return cg_v210_enemy_base_spi
  end

  alias cg_v210_enemy_base_agi base_agi
  def base_agi
    return cg_six_stat(:spe) if cg_six_stat_pokemon?
    return cg_v210_enemy_base_agi
  end
end

#==============================================================================
# ■ Game_Battler：六維傷害最終權威
#==============================================================================
class Game_Battler
  def cg_spa
    return spi.to_i
  rescue
    return 1
  end

  def cg_spd
    return [((spi.to_i * 3 + self.def.to_i) / 4), 1].max
  rescue
    return 1
  end

  def cg_spe
    return agi.to_i
  rescue
    return 1
  end

  def cg_atk_stat
    return atk.to_i
  end

  def cg_def_stat
    return self.def.to_i
  end

  def cg_special_defense
    return [cg_spd.to_i, 1].max
  end

  def cg_damage_class_stats(user, damage_class)
    case damage_class
    when :physical
      return [[user.cg_atk_stat.to_i, 1].max, [cg_def_stat.to_i, 1].max]
    when :special
      return [[user.cg_spa.to_i, 1].max, [cg_spd.to_i, 1].max]
    when :mixed
      return [[(user.cg_atk_stat.to_i + user.cg_spa.to_i) / 2, 1].max,
              [(cg_def_stat.to_i + cg_spd.to_i) / 2, 1].max]
    end
    return [1,1]
  end

  def cg_pokemon_formula(level, power, attack, defense)
    return ALBERT_CG::SIX_STAT_DAMAGE.pokemon_formula(level, power, attack, defense)
  end

  def cg_apply_pokemon_random(damage, variance = 0)
    min = ALBERT_CG::SIX_STAT_DAMAGE::RANDOM_MIN_PERCENT
    max = ALBERT_CG::SIX_STAT_DAMAGE::RANDOM_MAX_PERCENT
    percent = min + rand(max - min + 1)
    return damage.to_i * percent / 100
  end

  def cg_skill_level_percent(user, obj)
    return 100 unless user != nil && user.actor? && obj.is_a?(RPG::Skill)
    if defined?(ALBERT_CG::POKEMON_COMBAT_DATA) &&
       ALBERT_CG::POKEMON_COMBAT_DATA::SKILL_COMBAT_TABLE.has_key?(obj.id.to_i)
      level = user.respond_to?(:cg_skill_level) ? user.cg_skill_level(obj.id).to_i : 1
      return ALBERT_CG::SIX_STAT_DAMAGE.mastery_percent(level)
    end
    return 100 unless user.respond_to?(:cg_skill_level)
    return 100 unless defined?(ALBERT_CG) && ALBERT_CG.respond_to?(:skill_power_rate)
    return ALBERT_CG.skill_power_rate(user.cg_skill_level(obj.id), obj.id).to_i
  rescue
    return 100
  end

  def cg_mixed_physical_percent(obj)
    return 50 if obj == nil
    table = nil
    if defined?(ALBERT_CG::POKEMON_COMBAT) && ALBERT_CG::POKEMON_COMBAT.respond_to?(:skill_table_data)
      table = ALBERT_CG::POKEMON_COMBAT.skill_table_data(obj)
    end
    value = table[:physical_ratio].to_i if table != nil && table[:physical_ratio] != nil
    text = obj.respond_to?(:note) ? obj.note.to_s : ""
    value = $1.to_i if (value == nil || value <= 0) && text =~ /<mixed_physical\s*:\s*(\d+)\s*>/i
    value = 50 if value == nil || value <= 0
    return [[value.to_i, 0].max, 100].min
  rescue
    return 50
  end

  def cg_class_base_damage(user, obj, damage_class)
    power = obj.cg_pokemon_power
    level = user.cg_pokemon_level
    case damage_class
    when :physical
      return cg_pokemon_formula(level, power, user.cg_atk_stat, cg_def_stat)
    when :special
      return cg_pokemon_formula(level, power, user.cg_spa, cg_spd)
    when :mixed
      physical = cg_pokemon_formula(level, power, user.cg_atk_stat, cg_def_stat)
      special = cg_pokemon_formula(level, power, user.cg_spa, cg_spd)
      ratio = cg_mixed_physical_percent(obj)
      return (physical * ratio + special * (100 - ratio)) / 100
    end
    return 0
  end

  # 4v4 六維普通攻擊。
  def make_attack_damage_value(attacker)
    type_id = attacker.cg_basic_attack_type_id
    type_rate = cg_pokemon_type_rate_percent(type_id)
    attack = [attacker.cg_atk_stat.to_i, 1].max
    defense = [cg_def_stat.to_i, 1].max
    damage = cg_pokemon_formula(attacker.cg_pokemon_level,
      attacker.cg_basic_attack_power, attack, defense)
    stab = attacker.cg_stab_percent(type_id)
    damage = damage * stab / 100
    damage = damage * type_rate / 100
    @critical = type_rate > 0 && cg_pokemon_critical?(attacker)
    damage = damage * ALBERT_CG::SIX_STAT_DAMAGE::CRITICAL_PERCENT / 100 if @critical
    damage = cg_apply_pokemon_random(damage)
    damage = cg_apply_dual_wield(attacker, damage, false)
    damage = apply_guard(damage)
    damage = 1 if type_rate > 0 && damage < 1
    damage = 0 if type_rate == 0
    @hp_damage = damage
    @cg_last_damage_breakdown = {
      :kind=>:attack, :type_id=>type_id, :type_rate=>type_rate,
      :stab=>stab, :critical=>@critical, :power=>attacker.cg_basic_attack_power,
      :attack=>attack, :defense=>defense, :damage=>damage,
      :formula_version=>"2.1.0"
    }
    ALBERT_CG::POKEMON_COMBAT.audit(
      "ATTACK #{attacker.name} -> #{name}: #{@cg_last_damage_breakdown.inspect}") if defined?(ALBERT_CG::POKEMON_COMBAT)
    ALBERT_CG::SIX_STAT_DAMAGE.runtime_log(
      "ATTACK " + attacker.name.to_s + " -> " + name.to_s + " " + @cg_last_damage_breakdown.inspect)
  end

  # 正傷害 Skill 使用六維；回復／支援／物品保留舊 VX 流程。
  alias cg_v210_old_make_obj_damage_value make_obj_damage_value
  def make_obj_damage_value(user, obj)
    unless obj.is_a?(RPG::Skill) && obj.base_damage.to_i > 0
      return cg_v210_old_make_obj_damage_value(user, obj)
    end
    damage_class = obj.cg_pokemon_damage_class
    if damage_class == :fixed
      damage = obj.base_damage.to_i
      attack_info = 0
      defense_info = 0
    else
      if obj.ignore_defense
        power = obj.cg_pokemon_power
        level = user.cg_pokemon_level
        if damage_class == :physical
          damage = cg_pokemon_formula(level, power, user.cg_atk_stat, 1)
        elsif damage_class == :special
          damage = cg_pokemon_formula(level, power, user.cg_spa, 1)
        else
          physical = cg_pokemon_formula(level, power, user.cg_atk_stat, 1)
          special = cg_pokemon_formula(level, power, user.cg_spa, 1)
          ratio = cg_mixed_physical_percent(obj)
          damage = (physical * ratio + special * (100 - ratio)) / 100
        end
      else
        damage = cg_class_base_damage(user, obj, damage_class)
      end
      if damage_class == :physical
        attack_info = user.cg_atk_stat; defense_info = cg_def_stat
      elsif damage_class == :special
        attack_info = user.cg_spa; defense_info = cg_spd
      else
        attack_info = [user.cg_atk_stat, user.cg_spa]
        defense_info = [cg_def_stat, cg_spd]
      end
    end
    type_id = obj.cg_pokemon_type_id
    if type_id <= 0 && obj.physical_attack
      type_id = ALBERT_CG::POKEMON_COMBAT::TYPE_IDS[:normal]
    end
    type_rate = type_id <= 0 ? 100 : cg_pokemon_type_rate_percent(type_id)
    stab = type_id <= 0 ? 100 : user.cg_stab_percent(type_id)
    mastery = cg_skill_level_percent(user, obj)
    damage = damage * mastery / 100
    damage = damage * stab / 100
    damage = damage * type_rate / 100
    @critical = type_rate > 0 && cg_pokemon_critical?(user, obj)
    damage = damage * ALBERT_CG::SIX_STAT_DAMAGE::CRITICAL_PERCENT / 100 if @critical
    damage = cg_apply_pokemon_random(damage)
    damage = cg_apply_dual_wield(user, damage, true)
    damage = apply_guard(damage)
    damage = 1 if type_rate > 0 && damage < 1
    damage = 0 if type_rate == 0
    if obj.damage_to_mp
      @mp_damage = damage; @hp_damage = 0
    else
      @hp_damage = damage; @mp_damage = 0
    end
    @cg_last_damage_breakdown = {
      :kind=>:skill, :skill_id=>obj.id, :class=>damage_class,
      :type_id=>type_id, :type_rate=>type_rate, :stab=>stab,
      :critical=>@critical, :power=>obj.cg_pokemon_power,
      :attack=>attack_info, :defense=>defense_info, :mastery=>mastery,
      :damage=>damage, :formula_version=>"2.1.0"
    }
    ALBERT_CG::POKEMON_COMBAT.audit(
      "SKILL #{user.name}/#{obj.name} -> #{name}: #{@cg_last_damage_breakdown.inspect}") if defined?(ALBERT_CG::POKEMON_COMBAT)
    ALBERT_CG::SIX_STAT_DAMAGE.runtime_log(
      "SKILL " + user.name.to_s + "/" + obj.name.to_s + " -> " + name.to_s + " " + @cg_last_damage_breakdown.inspect)
  end
end

#==============================================================================
# ■ 六項 Growth UI 最終覆寫
#==============================================================================
if defined?(ALBERT_CG) && ALBERT_CG.respond_to?(:pet_grade_rank_text)
  module ALBERT_CG
    def self.pet_grade_rank_text(pet)
      return "" if pet == nil || !pet.respond_to?(:cg_grade_loss_at)
      labels = []
      ALBERT_CG::GRADE_STAT_COUNT.times do |i|
        labels.push(grade_rank_label(pet.cg_grade_loss_at(i)))
      end
      return labels.join("／")
    end
  end
end

if defined?(Window_CG_GrowthList)
  class Window_CG_GrowthList < Window_Selectable
    def initialize(pet)
      super(0, 80, 280, 336)
      @pet = pet
      @column_max = 1
      @item_max = 6
      refresh
      self.index = 0
    end
    def refresh
      create_contents
      self.contents.clear
      6.times { |i| draw_item(i) }
    end
  end
end

if defined?(Window_CG_GrowthInfo)
  class Window_CG_GrowthInfo < Window_Base
    alias cg_v210_growth_info_initialize initialize
    def initialize(pet)
      cg_v210_growth_info_initialize(pet)
      @session_added = Array.new(6, 0)
      refresh
    end
  end
end

if defined?(Window_CG_UniversalGrowthList)
  class Window_CG_UniversalGrowthList < Window_Selectable
    def initialize(actor)
      super(0, 80, 280, 336)
      @actor = actor
      @column_max = 1
      @item_max = 6
      refresh
      self.index = 0
    end
    def refresh
      create_contents
      self.contents.clear
      6.times { |i| draw_item(i) }
    end
  end
end

if defined?(Window_CG_UniversalGrowthInfo)
  class Window_CG_UniversalGrowthInfo < Window_Base
    alias cg_v210_universal_info_initialize initialize
    def initialize(actor)
      cg_v210_universal_info_initialize(actor)
      @session_added = Array.new(6, 0)
      refresh
    end
  end
end

if defined?(Window_CG_PetDetail)
  class Window_CG_PetDetail < Window_Base
    def refresh
      self.contents.clear
      if @pet == nil
        self.contents.draw_text(0, 0, contents.width, WLH, "選擇一隻寵物")
        return
      end
      @pet.cg_prepare_pet_data if @pet.respond_to?(:cg_prepare_pet_data)
      @pet.cg_prepare_growth_data if @pet.respond_to?(:cg_prepare_growth_data)
      @pet.cg_prepare_identity_data if @pet.respond_to?(:cg_prepare_identity_data)
      self.contents.font.size = 16
      y = 0
      form_id = @pet.respond_to?(:cg_current_form_actor_id) ? @pet.cg_current_form_actor_id : @pet.cg_species_id
      cg_v08_detail_line(y, "個體／型態", @pet.id.to_s + "／" + form_id.to_s); y += 22
      cg_v08_detail_line(y, "性別／個性", @pet.respond_to?(:cg_identity_text) ? @pet.cg_identity_text : ""); y += 22
      bp = @pet.respond_to?(:cg_unspent_bp) ? @pet.cg_unspent_bp : 0
      cg_v08_detail_line(y, "等級／可用BP", @pet.level.to_s + "／" + bp.to_s); y += 22
      cg_v08_detail_line(y, "HP／MP", @pet.hp.to_s + "/" + @pet.maxhp.to_s + "　" + @pet.mp.to_s + "/" + @pet.maxmp.to_s); y += 22
      cg_v08_detail_line(y, "物攻／物防", @pet.cg_atk_stat.to_s + "／" + @pet.cg_def_stat.to_s); y += 22
      cg_v08_detail_line(y, "特攻／特防／速", @pet.cg_spa.to_s + "／" + @pet.cg_spd.to_s + "／" + @pet.cg_spe.to_s); y += 22
      points = []
      6.times { |i| points.push(@pet.cg_bonus_point(i).to_s) }
      cg_v08_detail_line(y, "配點 六維", points.join("／")); y += 22
      grade_text = ALBERT_CG.respond_to?(:pet_grade_rank_text) ? ALBERT_CG.pet_grade_rank_text(@pet) : ""
      cg_v08_detail_line(y, "掉檔 六維", grade_text); y += 22
      names = []
      for skill in @pet.skills
        level = @pet.respond_to?(:cg_skill_level) ? @pet.cg_skill_level(skill.id) : 1
        names.push(skill.name + " Lv." + level.to_s)
      end
      cg_v08_detail_line(y, "技能", names.join("、"))
      self.contents.font.size = Font.default_size
    end
  end
end

if defined?(Window_CG_DevelopmentDetail)
  class Window_CG_DevelopmentDetail < Window_Base
    def refresh
      self.contents.clear
      return self.contents.draw_text(0, 0, contents.width, WLH, "選擇一名角色") if @actor == nil
      @actor.cg_prepare_identity_data if @actor.respond_to?(:cg_prepare_identity_data)
      self.contents.font.size = 16
      draw_actor_graphic(@actor, 264, 52)
      y = 0
      draw_line(y, "類型", @actor.cg_growth_role_name); y += 24
      draw_line(y, "性別／個性", @actor.respond_to?(:cg_identity_text) ? @actor.cg_identity_text : ""); y += 24
      draw_line(y, "等級／BP", @actor.level.to_s + "／" + @actor.cg_growth_unspent_bp.to_s); y += 24
      draw_line(y, "HP／MP", @actor.hp.to_s + "/" + @actor.maxhp.to_s + "　" + @actor.mp.to_s + "/" + @actor.maxmp.to_s); y += 24
      draw_line(y, "物攻／物防", @actor.cg_atk_stat.to_s + "／" + @actor.cg_def_stat.to_s); y += 24
      draw_line(y, "特攻／特防／速", @actor.cg_spa.to_s + "／" + @actor.cg_spd.to_s + "／" + @actor.cg_spe.to_s); y += 24
      values = []
      6.times { |i| values.push(@actor.cg_growth_bonus_point(i).to_s) }
      draw_line(y, "配點 六維", values.join("／"))
      self.contents.font.size = Font.default_size
    end
  end
end

#==============================================================================
# ■ Demo Battle：F6 進戰前記錄實際六維
#==============================================================================
module ALBERT_CG
  class << self
    if method_defined?(:start_demo_battle)
      alias cg_v210_six_stat_start_demo_battle start_demo_battle
      def start_demo_battle(troop_id = ALBERT_CG::DEMO_TROOP_ID)
        if $game_party != nil
          for member in $game_party.members
            ALBERT_CG::SIX_STAT_DAMAGE.log_battler_stats("ALLY", member)
          end
        end
        return cg_v210_six_stat_start_demo_battle(troop_id)
      end
    end
  end
end

#==============================================================================
# ■ Scene_Title：每次啟動輸出傷害曲線報告
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_v210_six_stat_load_database load_database
  def load_database
    cg_v210_six_stat_load_database
    ALBERT_CG::SIX_STAT_DAMAGE.write_benchmark_log
    ALBERT_CG::SIX_STAT_DAMAGE.reset_runtime_log
    $data_system.game_title = "CG Pet Battle Prototype v2.1.0 SixStat 4v4" if $data_system != nil
  end

  alias cg_v210_six_stat_load_bt_database load_bt_database
  def load_bt_database
    cg_v210_six_stat_load_bt_database
    ALBERT_CG::SIX_STAT_DAMAGE.write_benchmark_log
    ALBERT_CG::SIX_STAT_DAMAGE.reset_runtime_log
    $data_system.game_title = "CG Pet Battle Prototype v2.1.0 SixStat 4v4" if $data_system != nil
  end
end
