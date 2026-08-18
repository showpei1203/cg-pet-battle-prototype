# RMVX_SCRIPT_INDEX: 175
# RMVX_SCRIPT_ID: 98941079
# RMVX_SCRIPT_NAME: CG Pokemon Combat Data v2.0.1
# RMVX_SOURCE_SHA256: 149ab523de9aec26b168ffd57939a6a699cf92892f436243845a54caaa5151b7

#==============================================================================
# ■ CG Pokemon Combat Data v2.0.1
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# Project: CG Pet Battle Prototype
#
# 【用途】
#   寶可夢屬性、敵人物種、普通攻擊與固有抗性的唯一設定入口。
#
# 【重要】
#   RPG Maker VX 的 Actor 與 Class 資料庫沒有 Note 欄位。
#   因此本專案不會從 Actor／Class 讀取 Note。所有對應資料都放在本頁表格。
#
# 【仍可使用 Note 的資料庫類型】
#   Skill、Item、Weapon、Armor、Enemy、State。
#   這些 Note 只作個別覆蓋；正式物種資料仍以本頁表格為準。
#
# 【架構來源】
#   參考 Forest Symphony 的集中設定表與 ElementRate FinalGuard 思路，
#   但只擷取資料分層方式，不帶入該專案角色、召喚、ATB 或職業規則。
#
# 【放置位置】
#   CG Battle Formation Lock v1.9.1a
#   CG Pokemon Combat Data v2.0.1
#   CG Pokemon Combat Core v2.0.1
#   Main
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonCombatData"] = "2.0.1"

module ALBERT_CG
  module POKEMON_COMBAT_DATA
    VERSION = "2.0.1"

    #--------------------------------------------------------------------------
    # Actor／Class 本體屬性
    #--------------------------------------------------------------------------
    # 人類 Actor 直接以 Actor ID 指定。主角固定一般系。
    ACTOR_TYPE_TABLE = {
      1 => [:normal]
    }

    # Class 沒有 Note。此表只作 Actor 表未指定時的後備。
    # 目前人類職業不改變本體屬性，因此留空。
    CLASS_TYPE_TABLE = {
    }

    #--------------------------------------------------------------------------
    # 寵物「目前型態 Actor ID」屬性
    #--------------------------------------------------------------------------
    # 必須使用目前進化型態，不只使用最初捕捉物種。
    FORM_TYPE_TABLE = {
      100 => [:grass, :poison],
      101 => [:grass, :poison],
      102 => [:grass, :poison],
      103 => [:fire],
      104 => [:fire],
      105 => [:fire, :flying],
      106 => [:water],
      107 => [:water],
      108 => [:water]
    }

    #--------------------------------------------------------------------------
    # Enemy 對應
    #--------------------------------------------------------------------------
    # Enemy ID => 對應的寵物型態 Actor ID。
    ENEMY_FORM_TABLE = {
      600 => 100,
      603 => 103,
      606 => 106
    }

    # 不屬於可捕捉物種的敵人，可直接在此指定屬性。
    ENEMY_TYPE_TABLE = {
    }

    # Enemy 等級。若未列出，才讀 Enemy Note <pokemon_level: x>，再回預設值。
    ENEMY_LEVEL_TABLE = {
      600 => 5,
      603 => 5,
      606 => 5
    }

    #--------------------------------------------------------------------------
    # 普通攻擊資料
    #--------------------------------------------------------------------------
    # 格式：ID => { :type => 屬性, :power => 威力 }
    ACTOR_BASIC_ATTACK_TABLE = {
      1 => { :type => :normal, :power => 40 }
    }

    CLASS_BASIC_ATTACK_TABLE = {
    }

    FORM_BASIC_ATTACK_TABLE = {
      # 100 => { :type => :normal, :power => 40 }
    }

    ENEMY_BASIC_ATTACK_TABLE = {
      # 600 => { :type => :normal, :power => 40 }
    }

    #--------------------------------------------------------------------------
    # 固有抗性倍率
    #--------------------------------------------------------------------------
    # 百分比乘算：50 = 半傷、150 = 1.5 倍、0 = 免疫。
    # 裝備與狀態 Note 會在這些固有倍率之後繼續乘算。
    ACTOR_TYPE_RATE_TABLE = {
      # 1 => { :fire => 80 }
    }

    CLASS_TYPE_RATE_TABLE = {
    }

    FORM_TYPE_RATE_TABLE = {
    }

    ENEMY_TYPE_RATE_TABLE = {
    }

    #--------------------------------------------------------------------------
    # 技能戰鬥資料
    #--------------------------------------------------------------------------
    # Skill 有 Note，但正式測試資料集中在本表，避免同一資料散落。
    # 未列出的技能仍可使用 Note 或 VX 原始欄位自動判定。
    SKILL_COMBAT_TABLE = {
      600 => { :type=>:grass,  :power=>45, :class=>:physical },
      601 => { :type=>:poison, :power=>0,  :class=>:status },
      602 => { :type=>:grass,  :power=>0,  :class=>:status },
      607 => { :type=>:normal, :power=>40, :class=>:physical },
      608 => { :type=>:fire,   :power=>40, :class=>:special },
      612 => { :type=>:fire,   :power=>65, :class=>:physical },
      617 => { :type=>:water,  :power=>40, :class=>:special },
      653 => { :type=>:ground, :power=>55, :class=>:special },
      618 => { :type=>:normal, :power=>0,  :class=>:status }
    }

    def self.clone_types(value)
      return nil if value == nil
      result = []
      for key in value
        result.push(key)
      end
      return result
    end

    def self.actor_types(actor_id, class_id)
      value = ACTOR_TYPE_TABLE[actor_id.to_i]
      value = CLASS_TYPE_TABLE[class_id.to_i] if value == nil
      return clone_types(value)
    end

    def self.form_types(form_id)
      return clone_types(FORM_TYPE_TABLE[form_id.to_i])
    end

    def self.enemy_form_id(enemy_id)
      return ENEMY_FORM_TABLE[enemy_id.to_i]
    end

    def self.enemy_types(enemy_id)
      value = ENEMY_TYPE_TABLE[enemy_id.to_i]
      return clone_types(value)
    end

    def self.skill_data(skill_id)
      return SKILL_COMBAT_TABLE[skill_id.to_i]
    end

    def self.basic_attack_data(kind, id)
      table = case kind
      when :actor then ACTOR_BASIC_ATTACK_TABLE
      when :class then CLASS_BASIC_ATTACK_TABLE
      when :form then FORM_BASIC_ATTACK_TABLE
      when :enemy then ENEMY_BASIC_ATTACK_TABLE
      else nil
      end
      return nil if table == nil
      return table[id.to_i]
    end

    def self.rate_value(table, id, type_key)
      row = table[id.to_i]
      return 100 if row == nil
      value = row[type_key]
      return value == nil ? 100 : value.to_i
    end
  end
end
