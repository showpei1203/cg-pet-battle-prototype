# RMVX_SCRIPT_INDEX: 232
# RMVX_SCRIPT_ID: 251000001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Secondary + Move Property Authority v2.5.10a
# RMVX_SOURCE_SHA256: f725910008687a8fd5fc41f5b019d3288ade13666d805d3546962e927d243b6a

#==============================================================================
# ■ CG Pokemon Ability Secondary + Move Property Authority v2.5.10a
#------------------------------------------------------------------------------
# 【用途】
#  建立 Ability Batch K 共用的「追加效果機率／追加效果防護／聲音招式免疫／
#  吸血反轉／反作用力免疫／性別傷害倍率／多段攻擊最大段數」權威層，正式支援
#  Stench、Shield Dust、Serene Grace、Soundproof、Liquid Ooze、Rock Head、
#  Rivalry、Skill Link。
#
# 【主要設定項】
#  STENCH_CHANCE = 10：無原生畏縮追加效果的傷害招式，Stench 額外 10% 畏縮。
#  SERENE_GRACE_PERCENT = 200：傷害招式的 ailment / flinch / stat additional chance x2。
#  RIVALRY_SAME_PERCENT = 125 / RIVALRY_OPPOSITE_PERCENT = 75。
#  SOUND_MOVE_IDENTIFIERS：主系列聲音招式 identifier 清單；以 Pokémon Master move
#  identifier 比對，不依 VX Skill ID，避免資料庫 Skill ID 與原作 Move ID 混淆。
#
# 【機制規則】
#  1. 有效 Ability 一律讀 Ability Core 的 cg_master_ability_id，尊重 Gastro Acid、
#     Skill Swap、Role Play、Transform 等 Battle-only Override / Suppression。
#  2. Serene Grace 只倍增「傷害招式」的追加 ailment / flinch / stat chance，最高 100%。
#     Status Move 不吃倍率。
#  3. Shield Dust 只擋「其他 Pokémon 的傷害招式」追加效果：主要異常、Confusion、
#     Flinch 與對目標的追加能力階級變化；不會擋招式本身的直接 HP 傷害。
#  4. Stench 只在招式確實造成正 HP 傷害、該 Move 本身沒有原生 flinch chance，且
#     目標「本回合仍有待執行 Action」時才額外判定。若目標已完成本回合行動，Stench
#     不建立 Flinch，避免 VX hold_turn=0 的 Flinch 被帶到下一回合。Shield Dust 仍會擋掉。
#  5. Soundproof 在 skill_effect 最外層阻擋其他 Pokémon 的聲音招式，傷害與效果都不進入。
#  6. Liquid Ooze：HP-draining Move 對此 Ability 目標造成傷害時，原本應回復使用者的
#     數值改為傷害使用者；仍使用既有 MoveEffect drain_percent 作為唯一權威。
#  7. Rock Head：只免除 drain_percent < 0 的 recoil；不處理 Jump Kick crash 類失敗傷害。
#  8. Rivalry：攻擊者與目標性別皆為 male/female 時，同性最終傷害 x1.25、異性 x0.75；
#     任一性別未知則不變。
#  9. Skill Link：PMD Action Setup 建立多段 sequence 時，若 Move range 為可變多段，
#     直接選 max hits；本次 Action 的 @cg_pmd_pending_multi_hits 也寫入相同最大值。
# 10. Flinch timing 以 Scene_Battle 的 @action_battlers 為權威：目標尚在剩餘 Action queue
#     才可於本回合畏縮；queue 無法取得時保守回退原行為，不影響非標準戰鬥呼叫。
# 11. Regression deterministic bridge 只由 Batch K active? 查詢，不改正式玩家 RNG。
#
# 【可調參數】
#  STENCH_CHANCE / SERENE_GRACE_PERCENT / RIVALRY_* / SOUND_MOVE_IDENTIFIERS。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發可查：
#    ALBERT_CG::ABILITY_SECONDARY_V2510.adjust_secondary_chance(user,249,50,:stat)
#    ALBERT_CG::ABILITY_SECONDARY_V2510.sound_move?(304)  # Hyper Voice
#
# 【實際範例】
#  Serene Grace + Rock Smash：50% DEF下降 -> 100%；Nuzzle -> Shield Dust：傷害保留、
#  Paralysis 被擋；Giga Drain -> Liquid Ooze：使用者受原吸血量傷害；Skill Link +
#  Fury Swipes：固定 5 hits。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilitySecondaryMoveAuthority"] = "2.5.10a"

module ALBERT_CG
  module ABILITY_SECONDARY_V2510
    VERSION = "2.5.10a"

    ABILITY_STENCH       = 1
    ABILITY_SHIELD_DUST  = 19
    ABILITY_SERENE_GRACE = 32
    ABILITY_SOUNDPROOF   = 43
    ABILITY_LIQUID_OOZE  = 64
    ABILITY_ROCK_HEAD    = 69
    ABILITY_RIVALRY      = 79
    ABILITY_SKILL_LINK   = 92

    STENCH_CHANCE = 10
    SERENE_GRACE_PERCENT = 200
    RIVALRY_SAME_PERCENT = 125
    RIVALRY_OPPOSITE_PERCENT = 75

    SOUND_MOVE_IDENTIFIERS = [
      "growl","roar","sing","supersonic","screech","snore","perish-song",
      "heal-bell","uproar","hyper-voice","metal-sound","grass-whistle","howl",
      "bug-buzz","chatter","round","echoed-voice","relic-song","snarl",
      "noble-roar","disarming-voice","parting-shot","boomburst","confide",
      "sparkling-aria","clanging-scales","clangorous-soulblaze","clangorous-soul",
      "overdrive","eerie-spell","torch-song","dragon-cheer","alluring-voice",
      "psychic-noise"
    ]

    def self.core
      return defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil
    end

    def self.ability_id(battler)
      c = core
      return 0 if c == nil
      return c.ability_id(battler).to_i
    rescue
      return 0
    end

    def self.master
      return defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil
    end

    def self.move_row(move_id)
      m = master
      return nil if m == nil || !m.respond_to?(:move)
      return m.move(move_id.to_i)
    rescue
      return nil
    end

    def self.move_identifier(move_id)
      row = move_row(move_id)
      return row == nil ? "" : row[0].to_s
    end

    def self.move_power(move_id)
      row = move_row(move_id)
      return row == nil ? 0 : row[3].to_i
    end

    def self.base_flinch_chance(move_id)
      row = move_row(move_id)
      return row == nil ? 0 : row[21].to_i
    end

    def self.sound_move?(move_id)
      return SOUND_MOVE_IDENTIFIERS.include?(move_identifier(move_id))
    rescue
      return false
    end

    def self.opposing?(a,b)
      return false if a == nil || b == nil
      return a.actor? != b.actor?
    rescue
      return false
    end

    def self.note_activation(battler,aid,kind,data=nil)
      c = core
      ctx = data == nil ? {} : data
      if c != nil
        c.runtime_log("ABILITY_SECONDARY ability=" + aid.to_i.to_s +
          " battler=" + (battler == nil ? "nil" : battler.name.to_s) +
          " kind=" + kind.to_s)
        c.note_trigger(kind,battler,aid,ctx)
        c.present_trigger(battler,aid,kind,ctx)
      end
      if defined?(ALBERT_CG::ABILITY_K_V2510) && ALBERT_CG::ABILITY_K_V2510.respond_to?(:note_external_trigger)
        ALBERT_CG::ABILITY_K_V2510.note_external_trigger(aid,battler,kind,ctx)
      end
      return true
    rescue
      return false
    end

    def self.begin_context(user,target,move_id)
      @context_stack = [] if @context_stack == nil
      @context_stack.push([@current_user,@current_target,@current_move_id,@shield_noted,@serene_noted])
      @current_user = user
      @current_target = target
      @current_move_id = move_id.to_i
      @shield_noted = false
      @serene_noted = {}
      return true
    end

    def self.end_context
      if @context_stack != nil && !@context_stack.empty?
        row = @context_stack.pop
        @current_user,@current_target,@current_move_id,@shield_noted,@serene_noted = row
      else
        @current_user = @current_target = nil
        @current_move_id = 0
        @shield_noted = false
        @serene_noted = {}
      end
      return true
    rescue
      return false
    end

    def self.current_user; return @current_user; end
    def self.current_target; return @current_target; end
    def self.current_move_id; return @current_move_id.to_i; end

    def self.adjust_secondary_chance(user,move_id,base,kind)
      value = base.to_i
      return value if value <= 0
      return value unless move_power(move_id) > 0
      return value unless ability_id(user) == ABILITY_SERENE_GRACE
      after = [value * SERENE_GRACE_PERCENT / 100,100].min
      if after != value
        @serene_noted = {} if @serene_noted == nil
        key = kind.to_sym
        unless @serene_noted[key]
          @serene_noted[key] = true
          note_activation(user,ABILITY_SERENE_GRACE,:serene_grace,
            {:move_id=>move_id.to_i,:kind=>key,:before=>value,:after=>after})
        end
      end
      return after
    rescue
      return base.to_i
    end

    def self.shield_dust_block?(target,user,move_id,kind)
      return false if target == nil || user == nil || target == user
      return false unless opposing?(target,user)
      return false unless ability_id(target) == ABILITY_SHIELD_DUST
      return false unless move_power(move_id) > 0
      unless @shield_noted == true
        @shield_noted = true
        note_activation(target,ABILITY_SHIELD_DUST,:shield_dust,
          {:user=>user,:move_id=>move_id.to_i,:kind=>kind.to_sym})
      end
      return true
    rescue
      return false
    end

    def self.secondary_flinch_state?(state_id)
      return false unless defined?(ALBERT_CG::MOVE_EFFECT)
      return state_id.to_i == ALBERT_CG::MOVE_EFFECT::STATE_FLINCH.to_i
    rescue
      return false
    end

    # Stench／追加 Flinch 只有在目標本回合尚有待執行 Action 時才有意義。
    # DualCommand Core 的 @action_battlers 是目前唯一正式的剩餘 Action queue；
    # 若目標已不在 queue，代表已完成本回合行動，不能把 hold_turn=0 Flinch 留到下回合。
    def self.target_has_pending_action?(target)
      return false if target == nil
      scene = $scene
      return true if scene == nil
      entries = scene.instance_variable_get(:@action_battlers)
      return true if entries == nil
      entries.each do |entry|
        battler = entry.is_a?(ALBERT_CG::ActionEntry) ? entry.battler : entry
        return true if battler == target
      end
      return false
    rescue
      return true
    end

    def self.test_stench_decision(user,target,move_id)
      if defined?(ALBERT_CG::ABILITY_K_V2510) && ALBERT_CG::ABILITY_K_V2510.respond_to?(:stench_test_decision)
        return ALBERT_CG::ABILITY_K_V2510.stench_test_decision(user,target,move_id)
      end
      return nil
    rescue
      return nil
    end

    def self.apply_stench(user,target,move_id)
      return false if user == nil || target == nil
      return false unless ability_id(user) == ABILITY_STENCH
      return false unless move_power(move_id) > 0
      return false unless base_flinch_chance(move_id) <= 0
      return false if target.hp.to_i <= 0
      return false if target.instance_variable_get(:@hp_damage).to_i <= 0
      return false if shield_dust_block?(target,user,move_id,:stench)
      sid = defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT::STATE_FLINCH : 48
      return false if target.state?(sid)
      return false unless target_has_pending_action?(target)
      decision = test_stench_decision(user,target,move_id)
      proc_ok = decision == nil ? (rand(100) < STENCH_CHANCE) : (decision == true)
      return false unless proc_ok
      target.add_state(sid)
      return false unless target.state?(sid)
      if target.respond_to?(:added_states) && !target.added_states.include?(sid)
        target.added_states.push(sid)
      end
      note_activation(user,ABILITY_STENCH,:stench,
        {:target=>target,:move_id=>move_id.to_i,:state=>sid})
      return true
    rescue
      return false
    end

    def self.gender_of(battler)
      return nil if battler == nil
      value = battler.instance_variable_get(:@cg_gender)
      return value if value == :male || value == :female
      return nil
    rescue
      return nil
    end

    def self.apply_rivalry(battler,ctx)
      return false unless ctx[:role] == :attacker
      target = ctx[:target]
      g1 = gender_of(battler)
      g2 = gender_of(target)
      return false if g1 == nil || g2 == nil
      before = ctx[:damage].to_i
      return false if before <= 0 || ctx[:fixed_damage] == true
      percent = (g1 == g2) ? RIVALRY_SAME_PERCENT : RIVALRY_OPPOSITE_PERCENT
      after = [before * percent / 100,1].max
      ctx[:damage] = after
      data = {:target=>target,:move_id=>ctx[:move_id].to_i,:before=>before,:after=>after,
              :user_gender=>g1,:target_gender=>g2,:percent=>percent,:role=>:attacker}
      if defined?(ALBERT_CG::ABILITY_K_V2510) && ALBERT_CG::ABILITY_K_V2510.respond_to?(:note_rivalry_record)
        ALBERT_CG::ABILITY_K_V2510.note_rivalry_record(data)
      end
      return true
    rescue
      return false
    end

    def self.register_handlers
      return false unless defined?(ALBERT_CG::ABILITY_V250)
      c = ALBERT_CG::ABILITY_V250
      c.register(ABILITY_RIVALRY,:damage_modify,self,:apply_rivalry)
      return true
    rescue
      return false
    end
  end
end

ALBERT_CG::ABILITY_SECONDARY_V2510.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ MoveEffect additional chance：Serene Grace
#==============================================================================
if defined?(ALBERT_CG::MOVE_EFFECT)
  module ALBERT_CG
    module MOVE_EFFECT
      class << self
        alias cg_v2510_secondary_ailment_chance ailment_chance
        def ailment_chance(move_id)
          base = cg_v2510_secondary_ailment_chance(move_id)
          return ALBERT_CG::ABILITY_SECONDARY_V2510.adjust_secondary_chance(
            ALBERT_CG::ABILITY_SECONDARY_V2510.current_user,move_id,base,:ailment)
        end

        alias cg_v2510_secondary_flinch_chance flinch_chance
        def flinch_chance(move_id)
          base = cg_v2510_secondary_flinch_chance(move_id)
          return ALBERT_CG::ABILITY_SECONDARY_V2510.adjust_secondary_chance(
            ALBERT_CG::ABILITY_SECONDARY_V2510.current_user,move_id,base,:flinch)
        end

        alias cg_v2510_secondary_stat_chance stat_chance
        def stat_chance(move_id)
          base = cg_v2510_secondary_stat_chance(move_id)
          return ALBERT_CG::ABILITY_SECONDARY_V2510.adjust_secondary_chance(
            ALBERT_CG::ABILITY_SECONDARY_V2510.current_user,move_id,base,:stat)
        end
      end
    end
  end
end

#==============================================================================
# ■ Game_Battler：Soundproof / Shield Dust / Stench context
#==============================================================================
class Game_Battler
  alias cg_v2510_secondary_skill_effect skill_effect
  def skill_effect(user,skill)
    mid = 0
    if skill != nil && defined?(ALBERT_CG::MOVE_EFFECT)
      mid = ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i
    end
    if mid > 0 && defined?(ALBERT_CG::ABILITY_SECONDARY_V2510) &&
       ALBERT_CG::ABILITY_SECONDARY_V2510.ability_id(self) == ALBERT_CG::ABILITY_SECONDARY_V2510::ABILITY_SOUNDPROOF &&
       user != nil && user != self && ALBERT_CG::ABILITY_SECONDARY_V2510.sound_move?(mid)
      clear_action_results if respond_to?(:clear_action_results)
      @skipped = true
      ALBERT_CG::ABILITY_SECONDARY_V2510.note_activation(self,
        ALBERT_CG::ABILITY_SECONDARY_V2510::ABILITY_SOUNDPROOF,:soundproof,
        {:user=>user,:move_id=>mid})
      return false
    end

    if mid > 0 && defined?(ALBERT_CG::ABILITY_SECONDARY_V2510)
      ALBERT_CG::ABILITY_SECONDARY_V2510.begin_context(user,self,mid)
      begin
        result = cg_v2510_secondary_skill_effect(user,skill)
        if user != nil && !@skipped && !@missed && !@evaded
          ALBERT_CG::ABILITY_SECONDARY_V2510.apply_stench(user,self,mid)
        end
        return result
      ensure
        ALBERT_CG::ABILITY_SECONDARY_V2510.end_context
      end
    end
    return cg_v2510_secondary_skill_effect(user,skill)
  end

  alias cg_v2510_secondary_apply_ailment cg_move_effect_apply_ailment
  def cg_move_effect_apply_ailment(user,move_id)
    if defined?(ALBERT_CG::ABILITY_SECONDARY_V2510) &&
       ALBERT_CG::ABILITY_SECONDARY_V2510.shield_dust_block?(self,user,move_id,:ailment)
      return
    end
    return cg_v2510_secondary_apply_ailment(user,move_id)
  end

  alias cg_v2510_secondary_apply_stats cg_move_effect_apply_stats
  def cg_move_effect_apply_stats(user,move_id)
    if defined?(ALBERT_CG::ABILITY_SECONDARY_V2510) && defined?(ALBERT_CG::MOVE_EFFECT)
      target = ALBERT_CG::MOVE_EFFECT.effect_recipient(user,self,move_id)
      if target == self && ALBERT_CG::ABILITY_SECONDARY_V2510.shield_dust_block?(self,user,move_id,:stat)
        return
      end
    end
    return cg_v2510_secondary_apply_stats(user,move_id)
  end

  alias cg_v2510_secondary_add_state add_state
  def add_state(state_id)
    if defined?(ALBERT_CG::ABILITY_SECONDARY_V2510) &&
       ALBERT_CG::ABILITY_SECONDARY_V2510.current_target == self &&
       ALBERT_CG::ABILITY_SECONDARY_V2510.secondary_flinch_state?(state_id) &&
       ALBERT_CG::ABILITY_SECONDARY_V2510.shield_dust_block?(self,
         ALBERT_CG::ABILITY_SECONDARY_V2510.current_user,
         ALBERT_CG::ABILITY_SECONDARY_V2510.current_move_id,:flinch)
      return
    end
    return cg_v2510_secondary_add_state(state_id)
  end

  alias cg_v2510_secondary_heal_recoil cg_move_effect_apply_heal_recoil
  def cg_move_effect_apply_heal_recoil(user,move_id,damage_done)
    if defined?(ALBERT_CG::ABILITY_SECONDARY_V2510) && defined?(ALBERT_CG::MOVE_EFFECT) && user != nil
      drain = ALBERT_CG::MOVE_EFFECT.drain_percent(move_id).to_i
      aid_target = ALBERT_CG::ABILITY_SECONDARY_V2510.ability_id(self)
      aid_user = ALBERT_CG::ABILITY_SECONDARY_V2510.ability_id(user)
      if drain > 0 && damage_done.to_i > 0 && aid_target == ALBERT_CG::ABILITY_SECONDARY_V2510::ABILITY_LIQUID_OOZE
        # 保留 healing_percent 等舊邏輯，但把 damage_done=0 傳給舊鏈，阻止原 drain heal。
        cg_v2510_secondary_heal_recoil(user,move_id,0)
        amount = [damage_done.to_i * drain / 100,1].max
        amount = user.hp.to_i if amount > user.hp.to_i
        before = user.hp.to_i
        user.hp -= amount
        user.hp_damage = amount if user.respond_to?(:hp_damage=)
        ALBERT_CG::ABILITY_SECONDARY_V2510.note_activation(self,
          ALBERT_CG::ABILITY_SECONDARY_V2510::ABILITY_LIQUID_OOZE,:liquid_ooze,
          {:user=>user,:move_id=>move_id.to_i,:damage_done=>damage_done.to_i,
           :amount=>amount,:before=>before,:after=>user.hp.to_i})
        return
      elsif drain < 0 && damage_done.to_i > 0 && aid_user == ALBERT_CG::ABILITY_SECONDARY_V2510::ABILITY_ROCK_HEAD
        cg_v2510_secondary_heal_recoil(user,move_id,0)
        ALBERT_CG::ABILITY_SECONDARY_V2510.note_activation(user,
          ALBERT_CG::ABILITY_SECONDARY_V2510::ABILITY_ROCK_HEAD,:rock_head,
          {:move_id=>move_id.to_i,:damage_done=>damage_done.to_i,:recoil_percent=>-drain})
        return
      end
    end
    return cg_v2510_secondary_heal_recoil(user,move_id,damage_done)
  end
end

#==============================================================================
# ■ PMD Action Setup：Skill Link maximum hits
#==============================================================================
if defined?(CG_PMD)
  module CG_PMD
    class << self
      alias cg_v2510_secondary_skill_sequence_for skill_sequence_for
      def skill_sequence_for(skill,battler=nil)
        if battler != nil && defined?(ALBERT_CG::ABILITY_SECONDARY_V2510) &&
           defined?(ALBERT_CG::MOVE_EFFECT) &&
           ALBERT_CG::ABILITY_SECONDARY_V2510.ability_id(battler) == ALBERT_CG::ABILITY_SECONDARY_V2510::ABILITY_SKILL_LINK
          mid = ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i
          min,max = ALBERT_CG::MOVE_EFFECT.multi_hit_range(mid)
          if min.to_i > 0 && max.to_i > min.to_i
            motion = skill_motion_for(skill)
            native = ALBERT_CG::MOVE_EFFECT.resolve_native_action(battler,skill,motion)
            battler.instance_variable_set(:@cg_pmd_pending_native_action,native)
            battler.instance_variable_set(:@cg_pmd_pending_multi_hits,max.to_i)
            sequence = multi_sequence_name(motion,max.to_i)
            ALBERT_CG::ABILITY_SECONDARY_V2510.note_activation(battler,
              ALBERT_CG::ABILITY_SECONDARY_V2510::ABILITY_SKILL_LINK,:skill_link,
              {:move_id=>mid,:min_hits=>min.to_i,:max_hits=>max.to_i,:hits=>max.to_i})
            return sequence unless sequence == nil
          end
        end
        return cg_v2510_secondary_skill_sequence_for(skill,battler)
      end
    end
  end
end
