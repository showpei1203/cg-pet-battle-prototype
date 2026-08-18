# RMVX_SCRIPT_INDEX: 212
# RMVX_SCRIPT_ID: 2041447112
# RMVX_SCRIPT_NAME: CG Pokemon Ability Runtime Core v2.5.0
# RMVX_SOURCE_SHA256: 9cc490cbdbe35b68419f408e31d344acbefe6b93e3f48c258b6d6ace9b321fd9

#==============================================================================
# ■ CG Pokemon Ability Runtime Core v2.5.0
#------------------------------------------------------------------------------
# 【用途】
#  建立 373 Ability 正式共用 Runtime Authority。此頁不把每個 Ability 的效果硬塞
#  進單一巨大 case，而提供共用註冊、觸發、Battle-only Ability Override/Suppression、
#  Popup/LOG 與 Scene_Battle / Game_Battler / Switch / Field lifecycle 接點。
#  後續 Ability Batch 只需向本 Core 註冊 handler，不必再各自 alias 戰鬥核心。
#
# 【主要設定項】
#  ABILITY_CATALOG_COUNT = 373：以 Pokémon Master Data 的 ABILITY_CATALOG 為權威。
#  TRIGGERS：目前正式保留的 Ability lifecycle 接點：
#    battle_start / entry / switch_in / switch_out
#    before_action / targeting / before_hit / before_damage
#    after_damage / after_contact / after_hit / ko / after_ko
#    end_turn / weather_changed / terrain_changed
#
# 【機制規則】
#  1. 有效 Ability 一律讀 battler.cg_master_ability_id，因此會自動尊重 v2.3.7a 的
#     Battle-only Ability Override / Gastro Acid suppression；不讀永久 Species Pool 來繞過它。
#  2. Ability handler 透過 register(ability_id, trigger, receiver, method_name) 註冊。
#     Core dispatch 時只執行目前有效 Ability 對應 handler。
#  3. 任何 handler 真正發動時都建立 Ability trigger event，並呼叫 Presentation Hook。
#     現階段 Presentation Hook 使用既有 Scene_Battle special-action text；之後正式動畫／
#     Ability Popup 階段可只替換 present_trigger，不必改 Ability 邏輯。
#  4. Switch-out Authority 掛在 ForceSwitch.clear_switch_out_volatile；hidden reserve 的
#     transient cleanup 不視為 switch-out，避免 Natural Cure 等錯誤發動。
#  5. Switch-in Authority 掛在 Field.apply_entry_hazards 前；所有既有 Force Switch、
#     Teleport、Baton Pass、Healing Wish、Lunar Dance 都會經過這條 entry lifecycle。
#  6. Entry Ability 在 Scene_Battle start 對所有 active battler 依 Effective SPE 由高到低
#     穩定執行；同速以 ally 先、index 小者先，後續可在 Ability Metadata 再擴充例外。
#  7. before_damage / after_contact 掛在最終 execute_damage 外層，必須尊重既有
#     Substitute / Endure / Grudge 等正式 Move Runtime；handler 不直接改 Master Data。
#
# 【可調參數】
#  ENTRY_WEATHER_TURNS = 5：Drizzle 等 Entry Weather 的標準回合數，Ability Batch 可共用。
#  PRESENTATION_ENABLED = true：是否呼叫戰鬥中的 Ability 文字提示；LOG 永遠保留。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫；Ability 會由 lifecycle 自動 dispatch。
#  開發時可直接：
#    ALBERT_CG::ABILITY_V250.dispatch(:entry, battler, {:reason=>:debug})
#    ALBERT_CG::ABILITY_V250.register(22,:entry,MyAbilityBatch,:apply_intimidate)
#
# 【實際範例】
#  例 1：Gastro Acid 後 cg_master_ability_id=0，Core 不會執行任何原 Ability handler。
#  例 2：Teleport 換入一隻 Drizzle Pokémon，apply_entry_hazards 前會先 dispatch :switch_in
#        與 :entry，因此雨天會在入場當下建立，而不是等下一回合。
#  例 3：Sturdy handler 在 :before_damage 將 context[:damage] 改為 hp-1，Core 再把結果
#        寫回 @hp_damage 後交給既有 execute_damage chain。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityRuntimeCore"] = "2.5.0"

module ALBERT_CG
  module ABILITY_V250
    VERSION = "2.5.0"
    ABILITY_CATALOG_COUNT = 373
    ENTRY_WEATHER_TURNS = 5
    PRESENTATION_ENABLED = true

    TRIGGERS = [
      :battle_start, :entry, :switch_in, :switch_out,
      :before_action, :targeting, :before_hit, :before_damage,
      :after_damage, :after_contact, :after_hit, :ko, :after_ko,
      :end_turn, :weather_changed, :terrain_changed
    ]

    @handlers = {}
    @metadata = {}
    @entry_scene_token = nil

    def self.project_root
      return Dir.pwd
    rescue
      return "."
    end

    def self.runtime_log_path
      return File.join(project_root,"Pokemon_AbilityRuntime_v2_5_0.log")
    end

    def self.runtime_log(text)
      begin
        File.open(runtime_log_path,"ab") { |f| f.write(text.to_s + "\r\n") }
      rescue
      end
    end

    def self.master
      return defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil
    end

    def self.catalog_count
      m = master
      return 0 if m == nil || !m.const_defined?(:ABILITY_CATALOG)
      return m::ABILITY_CATALOG.size
    rescue
      return 0
    end

    def self.ability_id(battler)
      return 0 if battler == nil || !battler.respond_to?(:cg_master_ability_id)
      return battler.cg_master_ability_id.to_i
    rescue
      return 0
    end

    def self.ability_name(ability_id)
      m = master
      return "未知特性" if m == nil
      return m.ability_name(ability_id).to_s
    rescue
      return "未知特性"
    end

    def self.register(ability_id, trigger, receiver, method_name, metadata=nil)
      aid = ability_id.to_i
      trig = trigger.to_sym
      return false unless TRIGGERS.include?(trig)
      @handlers[trig] = {} if @handlers[trig] == nil
      @handlers[trig][aid] = [receiver,method_name.to_sym]
      @metadata[aid] = {} if @metadata[aid] == nil
      @metadata[aid][:triggers] = [] if @metadata[aid][:triggers] == nil
      @metadata[aid][:triggers].push(trig) unless @metadata[aid][:triggers].include?(trig)
      if metadata != nil
        metadata.each { |k,v| @metadata[aid][k] = v }
      end
      return true
    rescue => e
      runtime_log("ABILITY_REGISTER_ERROR id=" + ability_id.to_s + " trigger=" + trigger.to_s +
        " " + e.class.to_s + ":" + e.message.to_s)
      return false
    end

    def self.metadata(ability_id)
      value = @metadata[ability_id.to_i]
      return value == nil ? {} : value
    end

    def self.registered_ability_ids
      ids = []
      @handlers.each_value do |table|
        next if table == nil
        table.keys.each { |id| ids.push(id) unless ids.include?(id) }
      end
      return ids.sort
    end

    def self.opponents_of(battler)
      return [] if battler == nil
      unit = battler.actor? ? $game_troop : $game_party
      return [] if unit == nil
      return unit.members.select { |b| b != nil && !b.hidden && b.hp.to_i > 0 }
    rescue
      return []
    end

    def self.allies_of(battler)
      return [] if battler == nil
      unit = battler.actor? ? $game_party : $game_troop
      return [] if unit == nil
      return unit.members.select { |b| b != nil && !b.hidden && b.hp.to_i > 0 }
    rescue
      return []
    end

    def self.current_move_id(user)
      return 0 if user == nil || !user.respond_to?(:action)
      action = user.action
      return 0 if action == nil || !action.skill?
      skill = $data_skills[action.skill_id]
      return 0 if skill == nil || !defined?(ALBERT_CG::MOVE_EFFECT)
      return ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i
    rescue
      return 0
    end

    def self.current_skill(user)
      return nil if user == nil || !user.respond_to?(:action)
      action = user.action
      return nil if action == nil || !action.skill?
      return $data_skills[action.skill_id]
    rescue
      return nil
    end

    def self.contact_action?(user)
      return false if user == nil
      if defined?(ALBERT_CG::UNIQUE_F_V239) && ALBERT_CG::UNIQUE_F_V239.respond_to?(:contact_action?)
        return ALBERT_CG::UNIQUE_F_V239.contact_action?(user)
      end
      skill = current_skill(user)
      return false if skill == nil
      return skill.physical_attack == true
    rescue
      return false
    end

    def self.note_trigger(trigger,battler,ability_id,context)
      event = {
        :trigger=>trigger, :battler=>battler, :ability_id=>ability_id.to_i,
        :context=>context
      }
      runtime_log("ABILITY_TRIGGER trigger=" + trigger.to_s +
        " ability=" + ability_id.to_i.to_s + ":" + ability_name(ability_id) +
        " battler=" + (battler == nil ? "nil" : battler.name.to_s))
      if defined?(ALBERT_CG::ABILITY_A_V250) && ALBERT_CG::ABILITY_A_V250.respond_to?(:note_trigger_event)
        ALBERT_CG::ABILITY_A_V250.note_trigger_event(event)
      end
      return event
    rescue
      return nil
    end

    def self.present_trigger(battler,ability_id,trigger,context=nil)
      return unless PRESENTATION_ENABLED
      scene = $scene
      return if scene == nil
      text = (battler == nil ? "" : battler.name.to_s + "的") + ability_name(ability_id) + "發動！"
      if scene.respond_to?(:cg_show_special_action_text,true)
        scene.send(:cg_show_special_action_text,text)
      end
    rescue
    end

    def self.dispatch(trigger,battler,context=nil)
      trig = trigger.to_sym
      aid = ability_id(battler)
      return false if aid <= 0
      table = @handlers[trig]
      return false if table == nil
      handler = table[aid]
      return false if handler == nil
      ctx = context == nil ? {} : context
      receiver = handler[0]
      method_name = handler[1]
      return false if receiver == nil || !receiver.respond_to?(method_name)
      result = receiver.send(method_name,battler,ctx)
      if result
        note_trigger(trig,battler,aid,ctx)
        present_trigger(battler,aid,trig,ctx)
      end
      return result == true
    rescue => e
      runtime_log("ABILITY_DISPATCH_ERROR trigger=" + trigger.to_s + " battler=" +
        (battler == nil ? "nil" : battler.name.to_s) + " " + e.class.to_s + ":" + e.message.to_s)
      return false
    end

    def self.dispatch_all(trigger,list,context=nil)
      count = 0
      for battler in (list || [])
        next if battler == nil || battler.hidden || battler.hp.to_i <= 0
        count += 1 if dispatch(trigger,battler,context)
      end
      return count
    end

    def self.active_battlers
      result = []
      if $game_party != nil
        $game_party.members.each { |b| result.push(b) if b != nil && !b.hidden && b.hp.to_i > 0 }
      end
      if $game_troop != nil
        $game_troop.members.each { |b| result.push(b) if b != nil && !b.hidden && b.hp.to_i > 0 }
      end
      return result
    rescue
      return []
    end

    def self.effective_speed(battler)
      return 0 if battler == nil
      return battler.cg_priority_base_speed.to_i if battler.respond_to?(:cg_priority_base_speed)
      return battler.agi.to_i if battler.respond_to?(:agi)
      return 0
    rescue
      return 0
    end

    def self.entry_order(list)
      return (list || []).sort_by do |b|
        side = b.actor? ? 0 : 1
        [-effective_speed(b),side,b.index.to_i]
      end
    rescue
      return list || []
    end

    def self.trigger_battle_start_entries
      list = entry_order(active_battlers)
      dispatch_all(:battle_start,list,{:reason=>:battle_start})
      for b in list
        dispatch(:entry,b,{:reason=>:battle_start})
      end
      return true
    end

    def self.trigger_switch_in(battler)
      return false if battler == nil || battler.hidden || battler.hp.to_i <= 0
      dispatch(:switch_in,battler,{:reason=>:switch_in})
      dispatch(:entry,battler,{:reason=>:switch_in})
      return true
    end

    def self.trigger_switch_out(battler)
      return false if battler == nil || battler.hidden
      return dispatch(:switch_out,battler,{:reason=>:switch_out})
    end

    def self.trigger_end_turn
      list = entry_order(active_battlers)
      dispatch_all(:end_turn,list,{:reason=>:turn_end})
      return true
    end

    def self.suppress_next_end_turn!
      @suppress_next_end_turn = true
    end

    def self.consume_suppress_next_end_turn?
      if @suppress_next_end_turn == true
        @suppress_next_end_turn = false
        return true
      end
      return false
    end

    def self.notify_weather_changed(source=nil)
      st = defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233.state : nil
      ctx = {:source=>source,:weather=>(st == nil ? nil : st.weather),
             :turns=>(st == nil ? 0 : st.weather_turns.to_i)}
      dispatch_all(:weather_changed,active_battlers,ctx)
    end

    def self.notify_terrain_changed(source=nil)
      st = defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233.state : nil
      ctx = {:source=>source,:terrain=>(st == nil ? nil : st.terrain),
             :turns=>(st == nil ? 0 : st.terrain_turns.to_i)}
      dispatch_all(:terrain_changed,active_battlers,ctx)
    end
  end
end

#==============================================================================
# ■ Game_BattleAction：Targeting trigger authority
#==============================================================================
class Game_BattleAction
  alias cg_v250_ability_make_targets make_targets
  def make_targets
    targets = cg_v250_ability_make_targets
    if defined?(ALBERT_CG::ABILITY_V250) && battler != nil
      ctx = {:action=>self,:targets=>targets}
      ALBERT_CG::ABILITY_V250.dispatch(:targeting,battler,ctx)
      targets = ctx[:targets] if ctx[:targets].is_a?(Array)
    end
    return targets
  end
end

#==============================================================================
# ■ Game_Battler：Before Hit / Damage / Contact / KO trigger authority
#==============================================================================
class Game_Battler
  alias cg_v250_ability_skill_effect skill_effect
  def skill_effect(user,skill)
    if defined?(ALBERT_CG::ABILITY_V250) && user != nil && skill != nil
      ctx = {:user=>user,:target=>self,:skill=>skill,
             :move_id=>(defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0),
             :cancel=>false}
      ALBERT_CG::ABILITY_V250.dispatch(:before_hit,self,ctx)
      if ctx[:cancel] == true
        clear_action_results
        @missed = false
        @evaded = false
        @skipped = false
        @hp_damage = ctx[:hp_damage].to_i if ctx.has_key?(:hp_damage)
        return
      end
    end
    return cg_v250_ability_skill_effect(user,skill)
  end

  alias cg_v250_ability_execute_damage execute_damage
  def execute_damage(user)
    ability_ctx = nil
    if defined?(ALBERT_CG::ABILITY_V250)
      skill = ALBERT_CG::ABILITY_V250.current_skill(user)
      ability_ctx = {
        :user=>user,:target=>self,:skill=>skill,
        :move_id=>ALBERT_CG::ABILITY_V250.current_move_id(user),
        :damage=>@hp_damage.to_i,:hp_before=>hp.to_i,
        :contact=>ALBERT_CG::ABILITY_V250.contact_action?(user)
      }
      ALBERT_CG::ABILITY_V250.dispatch(:before_damage,self,ability_ctx)
      @hp_damage = ability_ctx[:damage].to_i if ability_ctx.has_key?(:damage)
    end
    hp_before = hp.to_i
    result = cg_v250_ability_execute_damage(user)
    if defined?(ALBERT_CG::ABILITY_V250) && ability_ctx != nil
      ability_ctx[:hp_after] = hp.to_i
      ability_ctx[:damage_done] = [hp_before - hp.to_i,0].max
      ALBERT_CG::ABILITY_V250.dispatch(:after_damage,self,ability_ctx)
      if ability_ctx[:contact] == true && user != nil && user.actor? != actor?
        ALBERT_CG::ABILITY_V250.dispatch(:after_contact,self,ability_ctx)
      end
      ALBERT_CG::ABILITY_V250.dispatch(:after_hit,self,ability_ctx)
      if hp_before > 0 && hp.to_i <= 0
        ALBERT_CG::ABILITY_V250.dispatch(:ko,self,ability_ctx)
        ALBERT_CG::ABILITY_V250.dispatch(:after_ko,user,ability_ctx) if user != nil
      end
    end
    return result
  end
end

#==============================================================================
# ■ Scene_Battle：Battle Start / Before Action / End Turn
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v250_ability_start start
  def start
    result = cg_v250_ability_start
    if defined?(ALBERT_CG::ABILITY_V250)
      ALBERT_CG::ABILITY_V250.trigger_battle_start_entries
    end
    return result
  end

  alias cg_v250_ability_execute_action execute_action
  def execute_action
    if defined?(ALBERT_CG::ABILITY_V250) && @active_battler != nil
      ALBERT_CG::ABILITY_V250.dispatch(:before_action,@active_battler,
        {:action=>@active_battler.action})
    end
    return cg_v250_ability_execute_action
  end

  alias cg_v250_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_V250)
      unless ALBERT_CG::ABILITY_V250.consume_suppress_next_end_turn?
        ALBERT_CG::ABILITY_V250.trigger_end_turn
      end
    end
    return cg_v250_ability_turn_end
  end
end

#==============================================================================
# ■ Force Switch：Switch-out trigger
#==============================================================================
if defined?(ALBERT_CG::FORCE_SWITCH_V235)
  module ALBERT_CG
    module FORCE_SWITCH_V235
      class << self
        alias cg_v250_ability_clear_switch_out_volatile clear_switch_out_volatile
        def clear_switch_out_volatile(battler)
          ALBERT_CG::ABILITY_V250.trigger_switch_out(battler) if defined?(ALBERT_CG::ABILITY_V250)
          return cg_v250_ability_clear_switch_out_volatile(battler)
        end
      end
    end
  end
end

#==============================================================================
# ■ Field：Switch-in / Weather / Terrain trigger
#==============================================================================
if defined?(ALBERT_CG::FIELD_V233)
  module ALBERT_CG
    module FIELD_V233
      class << self
        alias cg_v250_ability_apply_entry_hazards apply_entry_hazards
        def apply_entry_hazards(battler)
          ALBERT_CG::ABILITY_V250.trigger_switch_in(battler) if defined?(ALBERT_CG::ABILITY_V250)
          return cg_v250_ability_apply_entry_hazards(battler)
        end

        alias cg_v250_ability_apply_move apply_move
        def apply_move(user,target,move_id)
          before_weather = state.weather
          before_weather_turns = state.weather_turns.to_i
          before_terrain = state.terrain
          before_terrain_turns = state.terrain_turns.to_i
          result = cg_v250_ability_apply_move(user,target,move_id)
          if defined?(ALBERT_CG::ABILITY_V250)
            if before_weather != state.weather || before_weather_turns != state.weather_turns.to_i
              ALBERT_CG::ABILITY_V250.notify_weather_changed(user)
            end
            if before_terrain != state.terrain || before_terrain_turns != state.terrain_turns.to_i
              ALBERT_CG::ABILITY_V250.notify_terrain_changed(user)
            end
          end
          return result
        end
      end
    end
  end
end
