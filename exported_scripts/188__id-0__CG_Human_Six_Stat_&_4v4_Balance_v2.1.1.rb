# RMVX_SCRIPT_INDEX: 188
# RMVX_SCRIPT_ID: 0
# RMVX_SCRIPT_NAME: CG Human Six Stat & 4v4 Balance v2.1.1
# RMVX_SOURCE_SHA256: 2f548da0341f4b2038dd0f7fb5b386ea1756c3c80d8bc349b8c077f6d5901242

#==============================================================================
# ■ CG Human Six Stat & 4v4 Balance Patch v2.1.1
#------------------------------------------------------------------------------
# 【用途】
#  修正 v2.1.0 實機測試後發現的兩個傷害曲線問題：
#  1. Lv.1～15 寶可夢 HP 過低，四人集火與弱點高威力招在前期過度爆發。
#  2. 原測試資料中的人類 Actor（例如 Tom）使用 VX 舊參數，HP=2000、SPE=500，
#     與 Lv.5 寶可夢 HP 約 35、SPE 約 10～12 完全不同尺度，造成寶可夢攻擊
#     人類幾乎不掉血、人類速度永遠壓過所有寶可夢。
#
# 【正式規則】
#  A. Pokémon 與 Human 共用同一個六維尺度：
#       HP / ATK / DEF / SpA / SpD / SPE
#     不再讓人類沿用資料庫內任意放大的 HP／AGI 當正式戰鬥能力。
#
#  B. 前期 HP Scale 改為分段：
#       Lv. 1～ 5 = 220%
#       Lv. 6～10 = 205%
#       Lv.11～15 = 190%
#       Lv.16 以上 = 175%
#     目的：抑制 Pokémon 原公式中低等級固定 +2 傷害對小 HP 池造成的爆發；
#     Lv.20～60 維持 v2.1.0 已驗證的曲線，不改中後期手感。
#
#  C. 人類以「職業 Base Stat Profile」轉入同一條 Pokémon 式等級曲線。
#     Class ID 1～4 對應目前 Prototype 已有職業；5～6 先保留正式六職業擴充槽。
#     這些只是戰鬥數學 Profile，不會改 Tankentai SBS、人類技能動畫或職業 UI。
#
#  D. 人類 HP 額外 ×115%，讓「一名人類＋三寵」中的人類平均比單隻普通寵物
#     稍耐打，但不再出現 2000 HP 對 35 HP 的兩個宇宙。
#
#  E. 人類裝備 ATK / DEF / SPI / AGI 仍加到新的六維 Profile。
#     SPI 裝備暫時同時提供 SpA / SpD；等六大職業與全裝備正式資料完成時再分流。
#
# 【職業 Profile】
#  格式：[HP, ATK, DEF, SpA, SpD, SPE]
#  Class 1：均衡近戰，偏 ATK。
#  Class 2：防禦型，偏 HP/DEF/SpD。
#  Class 3：遠程物理，偏 ATK/SPE。
#  Class 4：施法型，偏 SpA/SpD。
#  Class 5、6：保留給後續六大職業正式內容，目前提供安全測試 Profile。
#
# 【Demo / F6】
#  Direct PMD 測試隊伍建立時，Tom 會與三隻測試寶可夢同步到
#  DIRECT_PMD_TEST_LEVEL（目前 Lv.5），讓 Runtime Damage LOG 可比較同級單位。
#  這只作用於 Prototype Debug bootstrap，不是正式遊戲「人類自動跟寵物等級」規則。
#
# 【可調參數】
#  EARLY_HP_SCALE_TABLE      前期 HP Scale。
#  HUMAN_HP_EXTRA_PERCENT   人類額外耐久倍率。
#  HUMAN_CLASS_PROFILES     六個職業的六維 Base Stat Profile。
#
# 【LOG】
#  CG_DamageCurve_v2_1_1.log
#    - Lv5/20/40/60 Pokémon 基準傷害曲線
#    - 六個 Human Class Profile 的同級六維
#  CG_DamageRuntime_v2_1_1.log
#    - F6 實際隊伍六維與每次傷害 breakdown
#
# 【實際測試範例】
#  1. 地圖按 F6。
#  2. Runtime LOG 應看到 Tom 與三寵都是 Lv.5。
#  3. Tom HP 應約為同級普通寶可夢的 1.2～1.4 倍，而不是 2000。
#  4. Tom SPE 應與同級寶可夢落在相近尺度，而不是 500。
#
# 【腳本位置】
#  必須放在「CG Pokemon Six Stat & 4v4 Damage Core v2.1.0」之後，
#  PMD BattleInit RootFix / AutoTest 之前，作為 v2.1.1 最終平衡權威。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_HumanSixStat4v4Balance"] = "2.1.1"

module ALBERT_CG
  module SIX_STAT_DAMAGE
    remove_const(:VERSION) if const_defined?(:VERSION)
    VERSION = "2.1.1"
    remove_const(:LOG_FILE) if const_defined?(:LOG_FILE)
    LOG_FILE = "CG_DamageCurve_v2_1_1.log"
    remove_const(:RUNTIME_LOG_FILE) if const_defined?(:RUNTIME_LOG_FILE)
    RUNTIME_LOG_FILE = "CG_DamageRuntime_v2_1_1.log"

    EARLY_HP_SCALE_TABLE = [
      [5, 220],
      [10, 205],
      [15, 190],
      [999, 175]
    ]

    HUMAN_HP_EXTRA_PERCENT = 115

    # [HP, ATK, DEF, SpA, SpD, SPE]
    HUMAN_CLASS_PROFILES = {
      1 => [95, 105, 80, 50, 75, 85],
      2 => [115, 80, 115, 45, 100, 50],
      3 => [80, 100, 70, 60, 75, 110],
      4 => [75, 45, 60, 115, 105, 80],
      5 => [85, 55, 75, 100, 115, 70],
      6 => [100, 110, 85, 45, 70, 95]
    }

    def self.hp_scale_percent(level)
      value = level.to_i
      for row in EARLY_HP_SCALE_TABLE
        return row[1].to_i if value <= row[0].to_i
      end
      return 175
    end

    # v2.1.0 同名方法的正式覆寫：只有 HP Scale 改成依等級分段。
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
        raw = raw * hp_scale_percent(level) / 100
        raw += bp * HP_BP_VALUE
        return [raw.to_i, 1].max
      end
      raw = (((2 * base + BASE_IV) * level) / 100) + 5
      raw = raw * nature_percent.to_i / 100
      raw = raw * grade_percent / 100
      raw += bp * OTHER_BP_VALUE
      return [raw.to_i, 1].max
    end

    def self.human_profile(class_id)
      value = HUMAN_CLASS_PROFILES[class_id.to_i]
      value = HUMAN_CLASS_PROFILES[1] if value == nil
      return value
    end

    def self.human_profile_stat(class_id, level, key, nature_percent, bp)
      profile = human_profile(class_id)
      index = {:hp=>0, :atk=>1, :def=>2, :spa=>3, :spd=>4, :spe=>5}[key]
      return 1 if index == nil
      value = stat_from_base(profile[index], level, key, nature_percent, 0, bp)
      if key == :hp
        value = value * HUMAN_HP_EXTRA_PERCENT / 100
      end
      return [value.to_i, 1].max
    end

    # v2.1.0 傷害方法內仍寫入 formula_version 2.1.0；在寫 LOG 時統一修正標籤。
    def self.runtime_log(text)
      text = text.to_s.gsub('"2.1.0"', '"2.1.1"')
      File.open(RUNTIME_LOG_FILE, "ab") do |file|
        file.write("[" + Time.now.strftime("%H:%M:%S") + "] " + text + "\r\n")
      end
    rescue
    end

    def self.reset_runtime_log
      File.open(RUNTIME_LOG_FILE, "wb") do |file|
        file.write("CG SIX STAT RUNTIME DAMAGE LOG v2.1.1\r\n")
        file.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
        file.write("HUMAN_AND_POKEMON_USE_COMMON_SIX_STAT_SCALE=true\r\n")
        file.write("------------------------------------------------------------\r\n")
      end
    rescue
    end

    def self.write_benchmark_log
      File.open(LOG_FILE, "wb") do |file|
        file.write("CG SIX STAT / 4v4 DAMAGE BENCHMARK v2.1.1\r\n")
        file.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
        file.write("TEAM=1 Human + 3 Pokemon; standard enemy formation=3~4 units\r\n")
        file.write("HP_SCALE=Lv1-5:220 / Lv6-10:205 / Lv11-15:190 / Lv16+:175\r\n")
        file.write("STAB=150% WEAK=160% RESIST=63% CRIT=150% RANDOM=90~100%\r\n")
        file.write("TARGET: Lv5 P60 STAB ~= 13~18%; P80 STAB+weak ~= 25~35%\r\n")
        file.write("------------------------------------------------------------\r\n")
        [5,20,40,60].each do |level|
          file.write("LEVEL=" + level.to_s + " HP_SCALE=" + hp_scale_percent(level).to_s + "%\r\n")
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
        file.write("------------------------------------------------------------\r\n")
        file.write("HUMAN_CLASS_PROFILE_REFERENCE (neutral nature / no BP / no equipment)\r\n")
        [5,20,40,60].each do |level|
          (1..6).each do |class_id|
            values = []
            [:hp,:atk,:def,:spa,:spd,:spe].each do |key|
              values.push(human_profile_stat(class_id, level, key, 100, 0))
            end
            file.write("  Lv" + level.to_s + " Class" + class_id.to_s +
              " HP/ATK/DEF/SpA/SpD/SPE=" + values.join("/") + "\r\n")
          end
        end
        file.write("------------------------------------------------------------\r\n")
        file.write("RESULT=PASS_IF_RUNTIME_F6_HUMAN_AND_POKEMON_SAME_SCALE\r\n")
      end
    rescue
    end
  end
end

#==============================================================================
# ■ Game_Actor：Human 六維 Profile 最終權威
#==============================================================================
class Game_Actor < Game_Battler
  alias cg_v211_profile_base_maxhp base_maxhp
  alias cg_v211_profile_base_atk base_atk
  alias cg_v211_profile_base_def base_def
  alias cg_v211_profile_base_spi base_spi
  alias cg_v211_profile_base_agi base_agi
  alias cg_v211_profile_six_stat cg_six_stat

  def cg_v211_human_profile?
    return false if respond_to?(:cg_six_stat_pokemon?) && cg_six_stat_pokemon?
    return true
  rescue
    return true
  end

  def cg_v211_equipment_bonus(key)
    total = 0
    return total unless respond_to?(:equips)
    for item in equips
      next if item == nil
      case key
      when :atk
        total += item.atk.to_i if item.respond_to?(:atk)
      when :def
        total += item.def.to_i if item.respond_to?(:def)
      when :spa, :spd
        total += item.spi.to_i if item.respond_to?(:spi)
      when :spe
        total += item.agi.to_i if item.respond_to?(:agi)
      end
    end
    return total
  rescue
    return 0
  end

  def cg_v211_human_profile_stat(key)
    nature = respond_to?(:cg_six_nature_rate) ? cg_six_nature_rate(key) : 100
    index = {:hp=>0,:atk=>1,:def=>2,:spa=>3,:spd=>4,:spe=>5}[key]
    bp = index == nil ? 0 : cg_six_bp(index)
    value = ALBERT_CG::SIX_STAT_DAMAGE.human_profile_stat(class_id, level,
      key, nature, bp)
    value += cg_v211_equipment_bonus(key) unless key == :hp
    return [value.to_i, 1].max
  rescue
    return 1
  end

  def cg_six_stat(key)
    return cg_v211_profile_six_stat(key) unless cg_v211_human_profile?
    key = key.to_sym rescue key
    return cg_v211_human_profile_stat(key)
  end

  def base_maxhp
    return cg_v211_profile_base_maxhp unless cg_v211_human_profile?
    return cg_v211_human_profile_stat(:hp)
  end

  def base_atk
    return cg_v211_profile_base_atk unless cg_v211_human_profile?
    return cg_v211_human_profile_stat(:atk)
  end

  def base_def
    return cg_v211_profile_base_def unless cg_v211_human_profile?
    return cg_v211_human_profile_stat(:def)
  end

  def base_spi
    return cg_v211_profile_base_spi unless cg_v211_human_profile?
    return cg_v211_human_profile_stat(:spa)
  end

  def base_agi
    return cg_v211_profile_base_agi unless cg_v211_human_profile?
    return cg_v211_human_profile_stat(:spe)
  end
end

#==============================================================================
# ■ Demo Bootstrap：F6 比較時把 Human 與 Direct PMD Pets 同步到同一測試等級
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v211_balance_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v211_balance_bootstrap_demo_party
      if defined?(ALBERT_CG::DIRECT_PMD_TEST_MODE) && ALBERT_CG::DIRECT_PMD_TEST_MODE &&
         defined?(ALBERT_CG::DIRECT_PMD_TEST_LEVEL) && $game_actors != nil
        human_id = defined?(ALBERT_CG::SOLO_HUMAN_ACTOR_ID) ? ALBERT_CG::SOLO_HUMAN_ACTOR_ID : 1
        human = $game_actors[human_id]
        if human != nil && human.respond_to?(:change_level)
          human.change_level(ALBERT_CG::DIRECT_PMD_TEST_LEVEL, false)
          human.recover_all if human.respond_to?(:recover_all)
        end
      end
      return result
    rescue
      return result
    end
  end
end

#==============================================================================
# ■ Scene_Title：v2.1.1 啟動後重建新 Benchmark / Runtime LOG
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_v211_balance_load_database load_database
  def load_database
    cg_v211_balance_load_database
    ALBERT_CG::SIX_STAT_DAMAGE.write_benchmark_log
    ALBERT_CG::SIX_STAT_DAMAGE.reset_runtime_log
    $data_system.game_title = "CG Pet Battle Prototype v2.1.1 SixStat 4v4 Balance" if $data_system != nil
  end

  alias cg_v211_balance_load_bt_database load_bt_database
  def load_bt_database
    cg_v211_balance_load_bt_database
    ALBERT_CG::SIX_STAT_DAMAGE.write_benchmark_log
    ALBERT_CG::SIX_STAT_DAMAGE.reset_runtime_log
    $data_system.game_title = "CG Pet Battle Prototype v2.1.1 SixStat 4v4 Balance" if $data_system != nil
  end
end
