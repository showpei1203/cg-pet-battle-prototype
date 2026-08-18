# RMVX_SCRIPT_INDEX: 207
# RMVX_SCRIPT_ID: 592387554
# RMVX_SCRIPT_NAME: CG Pokemon Held Item Core v2.4.4
# RMVX_SOURCE_SHA256: 32305b8f3fcdcd99f388ec04bcda617af7c7348109931fad982941883875c54b

#==============================================================================
# ■ CG Pokemon Held Item Core v2.4.4
#------------------------------------------------------------------------------
# 【用途】
#  為 CG Pet Battle Prototype 建立正式 Pokémon「持有道具」Runtime。
#  本專案直接重用 RPG Maker VX 原生 Weapon / Class / Game_Actor 裝備資料：
#    - Pokémon 的唯一持有道具槽 = Weapon slot（equip_type 0）。
#    - Pokémon 裝備 UI 只顯示一列，名稱固定為「道具」。
#    - Human 保留 VX 原本完整 Weapon / Shield / Head / Body / Accessory UI 與名稱。
#
# 【Clone Actor / Class 權威規則】
#  1. Clone Pokémon 建立時會從物種模板 Actor 初始化，因此 @class_id 與 @weapon_id
#     都自然繼承；之後每一隻 Clone 的 @weapon_id 又各自獨立保存。
#  2. VX 原生 Game_Actor#equippable? 仍以 Class.weapon_set 為底層合法性權威。
#  3. 本頁只會把標記為 Pokémon Held Item 的 Weapon ID 加入 Pokémon Class.weapon_set；
#     Human Class 不加入，因此人類仍照自己的職業武器限制。
#  4. 即使 Human Class 被資料庫誤勾到 Pokémon Held Item，本頁仍會阻擋 Human 裝備，
#     避免「持有道具」混成一般武器。
#
# 【資料庫設定】
#  在 RPG Maker VX 的「武器」Note 中加入：
#    <CG_POKEMON_HELD_ITEM>        # 正式 Pokémon 持有道具
#  若是 Berry 類再加入：
#    <CG_BERRY>
#  可選消耗效果：
#    <CG_HELD_HEAL_HP:30>          # 固定回復 30 HP
#    <CG_HELD_HEAL_HP_PERCENT:25>  # 回復 MaxHP 25%
#    <CG_HELD_HEAL_MP:20>          # 固定回復 20 MP
#    <CG_HELD_HEAL_MP_PERCENT:25>  # 回復 MaxMP 25%
#    <CG_HELD_CURE_PRIMARY>        # 清除主要異常
#
# 【Enemy Pokémon】
#  Enemy 沒有 VX 裝備欄，因此可在 Enemy Note 指定：
#    <CG_HELD_ITEM:123>
#  戰鬥中仍透過和 Actor 完全相同的 cg_held_item API 存取。
#
# 【戰鬥中 Item Ownership】
#  1. Actor 的平時持有道具仍以真實 @weapon_id 保存，Clone 因而天然個體持久化。
#  2. Trick / Switcheroo / Bestow 等戰鬥交換使用 battle runtime ownership，
#     不會把敵人的 Weapon 寫進玩家永久裝備，也不會讓 Bestow 永久丟失裝備。
#  3. 消耗型 Held Item 會記錄「原持有人」。若玩家 Pokémon 自己原本持有的道具在
#     戰鬥中真正被吃掉，battle end 才把該 Actor 的 @weapon_id 清成 0。
#  4. Recycle 若在戰鬥中把該道具恢復，會取消這次消耗，因此 battle end 仍保留裝備。
#  5. Corrosive Gas 只做 battle-only suppression；道具仍存在，換出／battle end 清除。
#
# 【主要 API】
#    battler.cg_held_item_user?                 # 是否使用 Pokémon Held Item 系統
#    battler.cg_held_item_id                    # 目前戰鬥有效道具 ID（含 suppression 前原 ID）
#    battler.cg_raw_held_item                   # 忽略 suppression 的 Weapon
#    battler.cg_held_item                       # suppression 時回 nil
#    battler.cg_held_item_suppressed?
#    battler.cg_can_hold_item?(weapon)
#    battler.cg_swap_held_item_with(other)
#    battler.cg_bestow_held_item_to(other)
#    battler.cg_consume_held_item(reason)
#    battler.cg_recycle_held_item
#
# 【UI】
#  Pokémon：Window_Equip 只有 1 列「道具」。候選列表只顯示
#  <CG_POKEMON_HELD_ITEM> Weapon，且仍必須通過 Class.weapon_set。
#  Human：完全呼叫 VX 原本 Window_Equip / Window_EquipItem 行為。
#
# 【實例】
#  皮卡丘 Clone 使用妙蛙種子模板 Class 以外的自己的物種 Class；若 Weapon 901 標記
#  <CG_POKEMON_HELD_ITEM>，資料庫載入後 901 會加入所有 Pokémon Class.weapon_set。
#  該 Clone 在裝備畫面選「道具 -> Weapon 901」，真正保存的是這隻 Clone 的 weapon_id。
#
# 【重要】
#  本頁是最後 9 Moves 與未來 373 Ability 共用的 Held Item Authority。
#  不得在 Trick / Recycle 等 Move 裡另造第二套 item_id 欄位。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonHeldItem"] = "2.4.4"

module ALBERT_CG
  module HELD_ITEM_V244
    VERSION = "2.4.4"
    HELD_TAG = /<CG_POKEMON_HELD_ITEM>/i
    BERRY_TAG = /<CG_BERRY>/i
    ENEMY_ITEM_TAG = /<CG_HELD_ITEM\s*:\s*(\d+)>/i
    HP_FLAT_TAG = /<CG_HELD_HEAL_HP\s*:\s*(\d+)>/i
    HP_RATE_TAG = /<CG_HELD_HEAL_HP_PERCENT\s*:\s*(\d+)>/i
    MP_FLAT_TAG = /<CG_HELD_HEAL_MP\s*:\s*(\d+)>/i
    MP_RATE_TAG = /<CG_HELD_HEAL_MP_PERCENT\s*:\s*(\d+)>/i
    CURE_PRIMARY_TAG = /<CG_HELD_CURE_PRIMARY>/i

    @consumed_tokens = {}
    @participants = []

    def self.weapon_note(item)
      return "" if item == nil
      return item.note.to_s if item.respond_to?(:note)
      return ""
    end

    def self.held_item?(item)
      return false unless item.is_a?(RPG::Weapon)
      return weapon_note(item) =~ HELD_TAG ? true : false
    end

    def self.berry?(item)
      return false unless held_item?(item)
      return weapon_note(item) =~ BERRY_TAG ? true : false
    end

    def self.held_item_ids
      result = []
      return result if $data_weapons == nil
      for item in $data_weapons
        next unless held_item?(item)
        result.push(item.id.to_i)
      end
      return result.uniq
    end

    def self.pokemon_class_ids
      ids = []
      if defined?(ALBERT_CG::SPECIES26) && ALBERT_CG::SPECIES26.const_defined?(:LINE_CLASS)
        ALBERT_CG::SPECIES26::LINE_CLASS.each_value { |cid| ids.push(cid.to_i) }
      end
      if defined?(ALBERT_CG::POKEMON_MASTER) && ALBERT_CG::POKEMON_MASTER.const_defined?(:GENERIC_CLASS_ID)
        ids.push(ALBERT_CG::POKEMON_MASTER::GENERIC_CLASS_ID.to_i)
      end
      # 最終再從正式 494 Actor 模板反查，避免未來 Class 表重構後漏掉。
      if defined?(ALBERT_CG::POKEMON_MASTER) && $data_actors != nil
        master = ALBERT_CG::POKEMON_MASTER
        for dex in 1..494
          aid = master.actor_id_for_dex(dex)
          actor = aid.to_i <= 0 ? nil : $data_actors[aid]
          ids.push(actor.class_id.to_i) if actor != nil
        end
      end
      return ids.uniq
    rescue
      return ids.uniq
    end

    def self.sync_class_permissions
      ids = held_item_ids
      for class_id in pokemon_class_ids
        klass = $data_classes == nil ? nil : $data_classes[class_id]
        next if klass == nil
        klass.weapon_set = [] if klass.weapon_set == nil
        for wid in ids
          klass.weapon_set.push(wid) unless klass.weapon_set.include?(wid)
        end
      end
      return true
    rescue
      return false
    end

    def self.owner_token_key(owner_key, item_id)
      return [owner_key, item_id.to_i]
    end

    def self.reset_battle_ledger
      @consumed_tokens = {}
      @participants = []
    end

    def self.mark_consumed(owner_key, item_id)
      return if owner_key == nil || item_id.to_i <= 0
      @consumed_tokens[owner_token_key(owner_key,item_id)] = true
    end

    def self.restore_consumed(owner_key, item_id)
      return if owner_key == nil || item_id.to_i <= 0
      @consumed_tokens.delete(owner_token_key(owner_key,item_id))
    end

    def self.consumed?(owner_key, item_id)
      return @consumed_tokens[owner_token_key(owner_key,item_id)] == true
    end

    def self.register_participant(battler)
      return if battler == nil
      @participants.push(battler) unless @participants.include?(battler)
    end

    def self.begin_battle
      reset_battle_ledger
      if $game_party != nil
        for battler in $game_party.members
          next unless battler.respond_to?(:cg_held_item_user?) && battler.cg_held_item_user?
          battler.cg_begin_held_item_battle
          register_participant(battler)
        end
      end
      if $game_troop != nil
        for battler in $game_troop.members
          next unless battler.respond_to?(:cg_held_item_user?) && battler.cg_held_item_user?
          battler.cg_begin_held_item_battle
          register_participant(battler)
        end
      end
      return true
    end

    def self.finish_battle
      list = @participants == nil ? [] : @participants.clone
      for battler in list
        battler.cg_finish_held_item_battle if battler != nil && battler.respond_to?(:cg_finish_held_item_battle)
      end
      @participants = []
      @consumed_tokens = {}
      return true
    end

    def self.parse_number(note, regex)
      data = regex.match(note.to_s)
      return data == nil ? 0 : data[1].to_i
    end

    def self.cure_primary(battler)
      return 0 if battler == nil
      if battler.respond_to?(:cg_v231_cure_primary_statuses)
        return battler.cg_v231_cure_primary_statuses
      end
      count = 0
      if defined?(ALBERT_CG::MOVE_EFFECT) && ALBERT_CG::MOVE_EFFECT.respond_to?(:primary_cure_state_ids)
        for sid in ALBERT_CG::MOVE_EFFECT.primary_cure_state_ids
          if battler.state?(sid)
            battler.remove_state(sid)
            count += 1
          end
        end
      end
      return count
    end

    def self.apply_consumption_effect(battler, item)
      return false if battler == nil || item == nil
      note = weapon_note(item)
      hp_gain = parse_number(note,HP_FLAT_TAG)
      hp_rate = parse_number(note,HP_RATE_TAG)
      mp_gain = parse_number(note,MP_FLAT_TAG)
      mp_rate = parse_number(note,MP_RATE_TAG)
      hp_gain += battler.maxhp.to_i * hp_rate / 100 if hp_rate > 0
      mp_gain += battler.maxmp.to_i * mp_rate / 100 if mp_rate > 0
      battler.hp = [battler.hp.to_i + hp_gain, battler.maxhp.to_i].min if hp_gain > 0
      battler.mp = [battler.mp.to_i + mp_gain, battler.maxmp.to_i].min if mp_gain > 0
      cure_primary(battler) if note =~ CURE_PRIMARY_TAG
      return true
    rescue
      return false
    end
  end
end

#==============================================================================
# ■ Game_Battler：共用 Held Item battle runtime
#==============================================================================
class Game_Battler
  def cg_held_item_user?
    return false
  end

  def cg_persistent_held_item_id
    return 0
  end

  def cg_held_item_owner_key
    return nil
  end

  def cg_begin_held_item_battle
    @cg_held_item_runtime_active = true
    @cg_held_item_runtime_id = cg_persistent_held_item_id.to_i
    @cg_held_item_runtime_owner = cg_held_item_owner_key
    @cg_held_item_original_id = @cg_held_item_runtime_id
    @cg_held_item_original_owner = @cg_held_item_runtime_owner
    @cg_held_item_suppressed = false
    @cg_last_consumed_held_item_id = 0
    @cg_last_consumed_held_item_owner = nil
    return true
  end

  def cg_finish_held_item_battle
    @cg_held_item_runtime_active = false
    @cg_held_item_runtime_id = nil
    @cg_held_item_runtime_owner = nil
    @cg_held_item_original_id = nil
    @cg_held_item_original_owner = nil
    @cg_held_item_suppressed = false
    @cg_last_consumed_held_item_id = 0
    @cg_last_consumed_held_item_owner = nil
    return true
  end

  def cg_held_item_runtime_active?
    return @cg_held_item_runtime_active == true
  end

  def cg_held_item_id
    return @cg_held_item_runtime_id.to_i if cg_held_item_runtime_active?
    return cg_persistent_held_item_id.to_i
  end

  def cg_held_item_owner
    return @cg_held_item_runtime_owner if cg_held_item_runtime_active?
    return cg_held_item_owner_key
  end

  def cg_raw_held_item
    id = cg_held_item_id
    return nil if id <= 0 || $data_weapons == nil
    item = $data_weapons[id]
    return nil unless defined?(ALBERT_CG::HELD_ITEM_V244) && ALBERT_CG::HELD_ITEM_V244.held_item?(item)
    return item
  end

  def cg_held_item_suppressed?
    return @cg_held_item_suppressed == true
  end

  def cg_held_item
    return nil if cg_held_item_suppressed?
    return cg_raw_held_item
  end

  def cg_has_raw_held_item?
    return cg_raw_held_item != nil
  end

  def cg_held_item_berry?
    return false unless defined?(ALBERT_CG::HELD_ITEM_V244)
    return ALBERT_CG::HELD_ITEM_V244.berry?(cg_held_item)
  end

  def cg_can_hold_item?(item)
    return false unless cg_held_item_user?
    return false unless defined?(ALBERT_CG::HELD_ITEM_V244) && ALBERT_CG::HELD_ITEM_V244.held_item?(item)
    return true
  end

  def cg_set_battle_held_item(item_id, owner_key=nil)
    return false unless cg_held_item_user?
    id = item_id.to_i
    if id > 0
      item = $data_weapons == nil ? nil : $data_weapons[id]
      return false unless cg_can_hold_item?(item)
    end
    cg_begin_held_item_battle unless cg_held_item_runtime_active?
    @cg_held_item_runtime_id = id
    @cg_held_item_runtime_owner = (id <= 0 ? nil : owner_key)
    @cg_held_item_suppressed = false if id <= 0
    return true
  end

  def cg_clear_held_item_suppression
    @cg_held_item_suppressed = false
    return true
  end

  def cg_suppress_held_item
    return false unless cg_has_raw_held_item?
    @cg_held_item_suppressed = true
    return true
  end

  def cg_swap_held_item_with(other)
    return false if other == nil
    return false unless cg_held_item_user? && other.respond_to?(:cg_held_item_user?) && other.cg_held_item_user?
    item_a = cg_raw_held_item
    item_b = other.cg_raw_held_item
    return false if item_a == nil && item_b == nil
    return false if item_b != nil && !cg_can_hold_item?(item_b)
    return false if item_a != nil && !other.cg_can_hold_item?(item_a)
    id_a = cg_held_item_id
    id_b = other.cg_held_item_id
    owner_a = cg_held_item_owner
    owner_b = other.cg_held_item_owner
    cg_set_battle_held_item(id_b,owner_b)
    other.cg_set_battle_held_item(id_a,owner_a)
    cg_clear_held_item_suppression
    other.cg_clear_held_item_suppression
    return true
  end

  def cg_bestow_held_item_to(other)
    return false if other == nil
    return false unless cg_held_item_user? && other.respond_to?(:cg_held_item_user?) && other.cg_held_item_user?
    item = cg_raw_held_item
    return false if item == nil || other.cg_has_raw_held_item?
    return false unless other.cg_can_hold_item?(item)
    id = cg_held_item_id
    owner = cg_held_item_owner
    return false unless other.cg_set_battle_held_item(id,owner)
    cg_set_battle_held_item(0,nil)
    return true
  end

  def cg_consume_held_item(reason=:consume, apply_effect=true)
    item = cg_held_item
    return false if item == nil
    id = item.id.to_i
    owner = cg_held_item_owner
    @cg_last_consumed_held_item_id = id
    @cg_last_consumed_held_item_owner = owner
    ALBERT_CG::HELD_ITEM_V244.mark_consumed(owner,id) if defined?(ALBERT_CG::HELD_ITEM_V244)
    cg_set_battle_held_item(0,nil)
    if apply_effect && defined?(ALBERT_CG::HELD_ITEM_V244)
      ALBERT_CG::HELD_ITEM_V244.apply_consumption_effect(self,item)
    end
    return true
  end

  def cg_last_consumed_held_item_id
    return @cg_last_consumed_held_item_id.to_i
  end

  def cg_recycle_held_item
    return false if cg_has_raw_held_item?
    id = @cg_last_consumed_held_item_id.to_i
    owner = @cg_last_consumed_held_item_owner
    return false if id <= 0 || owner == nil
    item = $data_weapons == nil ? nil : $data_weapons[id]
    return false unless cg_can_hold_item?(item)
    return false unless cg_set_battle_held_item(id,owner)
    ALBERT_CG::HELD_ITEM_V244.restore_consumed(owner,id) if defined?(ALBERT_CG::HELD_ITEM_V244)
    @cg_last_consumed_held_item_id = 0
    @cg_last_consumed_held_item_owner = nil
    return true
  end
end

#==============================================================================
# ■ Game_Actor：Weapon slot = Pokémon persistent Held Item
#==============================================================================
class Game_Actor < Game_Battler
  def cg_held_item_user?
    return cg_battle_pet? if respond_to?(:cg_battle_pet?)
    return cg_pet? if respond_to?(:cg_pet?)
    return false
  end

  def cg_persistent_held_item_id
    return 0 unless cg_held_item_user?
    id = @weapon_id.to_i
    return 0 if id <= 0 || $data_weapons == nil
    item = $data_weapons[id]
    return 0 unless defined?(ALBERT_CG::HELD_ITEM_V244) && ALBERT_CG::HELD_ITEM_V244.held_item?(item)
    return id
  end

  def cg_held_item_owner_key
    return [:actor,id.to_i]
  end

  def cg_can_hold_item?(item)
    return false unless cg_held_item_user?
    return false unless defined?(ALBERT_CG::HELD_ITEM_V244) && ALBERT_CG::HELD_ITEM_V244.held_item?(item)
    return self.class != nil && self.class.weapon_set.include?(item.id.to_i)
  end

  alias cg_v244_held_equippable equippable?
  def equippable?(item)
    if item.is_a?(RPG::Weapon) && defined?(ALBERT_CG::HELD_ITEM_V244) && ALBERT_CG::HELD_ITEM_V244.held_item?(item)
      return false unless cg_held_item_user?
      return cg_v244_held_equippable(item)
    end
    if cg_held_item_user?
      return false if item.is_a?(RPG::Weapon)
      return false if item.is_a?(RPG::Armor)
    end
    return cg_v244_held_equippable(item)
  end

  alias cg_v244_held_finish_battle cg_finish_held_item_battle
  def cg_finish_held_item_battle
    if cg_held_item_user? && defined?(ALBERT_CG::HELD_ITEM_V244)
      original_id = @cg_held_item_original_id.to_i
      original_owner = @cg_held_item_original_owner
      if original_id > 0 && original_owner != nil &&
         ALBERT_CG::HELD_ITEM_V244.consumed?(original_owner,original_id)
        @weapon_id = 0
      end
    end
    return cg_v244_held_finish_battle
  end
end

#==============================================================================
# ■ Game_Enemy：Enemy Note / test runtime Held Item
#==============================================================================
class Game_Enemy < Game_Battler
  def cg_held_item_user?
    if defined?(ALBERT_CG::POKEMON_MASTER) && respond_to?(:enemy_id)
      return ALBERT_CG::POKEMON_MASTER.dex_for_enemy_id(enemy_id.to_i).to_i > 0 if
        ALBERT_CG::POKEMON_MASTER.respond_to?(:dex_for_enemy_id)
    end
    return true if respond_to?(:cg_pmd_enabled?) && cg_pmd_enabled?
    return false
  rescue
    return false
  end

  def cg_persistent_held_item_id
    test_id = @cg_test_held_item_id.to_i
    return test_id if test_id > 0
    obj = respond_to?(:enemy) ? enemy : nil
    note = obj != nil && obj.respond_to?(:note) ? obj.note.to_s : ""
    data = defined?(ALBERT_CG::HELD_ITEM_V244) ? ALBERT_CG::HELD_ITEM_V244::ENEMY_ITEM_TAG.match(note) : nil
    return data == nil ? 0 : data[1].to_i
  rescue
    return 0
  end

  def cg_held_item_owner_key
    return [:enemy,index.to_i]
  end
end

#==============================================================================
# ■ Scene_Title：Master Data 建置完成後，同步 Pokémon Class.weapon_set
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_v244_held_load_database load_database
  def load_database
    cg_v244_held_load_database
    ALBERT_CG::HELD_ITEM_V244.sync_class_permissions
  end

  alias cg_v244_held_load_bt_database load_bt_database
  def load_bt_database
    cg_v244_held_load_bt_database
    ALBERT_CG::HELD_ITEM_V244.sync_class_permissions
  end
end

#==============================================================================
# ■ Window_Equip：Pokémon 只顯示「道具」一欄；Human 保持原介面
#==============================================================================
class Window_Equip < Window_Selectable
  alias cg_v244_held_initialize initialize
  def initialize(x,y,actor)
    @cg_v244_held_actor = actor
    if actor != nil && actor.respond_to?(:cg_held_item_user?) && actor.cg_held_item_user?
      super(x,y,336,WLH + 32)
      @actor = actor
      refresh
      self.index = 0
    else
      cg_v244_held_initialize(x,y,actor)
    end
  end

  alias cg_v244_held_refresh refresh
  def refresh
    unless @actor != nil && @actor.respond_to?(:cg_held_item_user?) && @actor.cg_held_item_user?
      return cg_v244_held_refresh
    end
    self.contents.clear
    @data = []
    item = @actor.cg_persistent_held_item_id.to_i > 0 ? $data_weapons[@actor.cg_persistent_held_item_id] : nil
    @data.push(item)
    @item_max = 1
    self.contents.font.color = system_color
    self.contents.draw_text(4,0,92,WLH,"道具")
    draw_item_name(@data[0],92,0)
  end
end

#==============================================================================
# ■ Window_EquipItem：Pokémon 候選只列 Held Item Weapon
#==============================================================================
class Window_EquipItem < Window_Item
  alias cg_v244_held_include include?
  def include?(item)
    if @actor != nil && @actor.respond_to?(:cg_held_item_user?) && @actor.cg_held_item_user?
      return true if item == nil
      return false unless @equip_type == 0
      return false unless item.is_a?(RPG::Weapon)
      return false unless defined?(ALBERT_CG::HELD_ITEM_V244) && ALBERT_CG::HELD_ITEM_V244.held_item?(item)
      return @actor.equippable?(item)
    end
    return cg_v244_held_include(item)
  end
end

#==============================================================================
# ■ Force Switch：Corrosive Gas suppression 換出即清除
#==============================================================================
if defined?(ALBERT_CG::FORCE_SWITCH_V235) && ALBERT_CG::FORCE_SWITCH_V235.respond_to?(:clear_switch_out_volatile)
  module ALBERT_CG
    module FORCE_SWITCH_V235
      class << self
        alias cg_v244_held_clear_switch_out_volatile clear_switch_out_volatile
        def clear_switch_out_volatile(battler)
          cg_v244_held_clear_switch_out_volatile(battler)
          battler.cg_clear_held_item_suppression if battler != nil && battler.respond_to?(:cg_clear_held_item_suppression)
        end
      end
    end
  end
end

#==============================================================================
# ■ Scene_Battle：Held Item battle ledger lifecycle
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v244_held_start start
  def start
    cg_v244_held_start
    ALBERT_CG::HELD_ITEM_V244.begin_battle if defined?(ALBERT_CG::HELD_ITEM_V244)
  end

  alias cg_v244_held_battle_end battle_end
  def battle_end(result)
    ALBERT_CG::HELD_ITEM_V244.finish_battle if defined?(ALBERT_CG::HELD_ITEM_V244)
    cg_v244_held_battle_end(result)
  end
end

#==============================================================================
# ■ Scene_Equip：Human 切換到 Pokémon 時強制回到唯一的道具欄 index 0
#==============================================================================
class Scene_Equip < Scene_Base
  alias cg_v244_held_scene_equip_start start
  def start
    cg_v244_held_scene_equip_start
    if @actor != nil && @actor.respond_to?(:cg_held_item_user?) && @actor.cg_held_item_user?
      @equip_index = 0
      @equip_window.index = 0 if @equip_window != nil
      if @item_windows != nil
        @item_windows.each_with_index do |window,i|
          window.visible = (i == 0) if window != nil
        end
      end
    end
  end
end
