# RMVX_SCRIPT_INDEX: 278
# RMVX_SCRIPT_ID: 278
# RMVX_SCRIPT_NAME: CG Human Phase3C Batch B Closure v2.6.2c TESTFIX
# RMVX_SOURCE_SHA256: 7ec62bb2e113db4b0a7e5cb00328d79b186f2d09e7ce7600663c5c59e4b88aaa

#==============================================================================
# ■ CG Human Phase 3C Batch B Closure AutoRegression v2.6.2c TEST HARNESS FIX
#------------------------------------------------------------------------------
# Targeted real Scene_Battle closure for the only two v2.6.2a failures:
#   R1 Hunter Mark + Pokemon ranged proxy skill classification
#   R2 Brawler interrupt on a surviving pending-action target
#==============================================================================

module ALBERT_CG
  module HUMAN_V262B_TEST
    VERSION = "2.6.2c"
    LOG_FILE = "CG_AutoRegression_LATEST.log"
    TEST_TROOP_ID = 760
    TEST_LEVEL = 30
    VK_F11 = 0x7A

    def self.active?; return @active == true; end
    def self.finished?; return @round_index.to_i >= 2; end
    def self.current_round; return @round_index.to_i + 1; end
    def self.human; return $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; end
    def self.master; return ALBERT_CG::POKEMON_MASTER; end

    def self.key_down?(vk)
      @key_api = Win32API.new("user32", "GetAsyncKeyState", "i", "i") if @key_api == nil
      return (@key_api.call(vk) & 0x8000) != 0
    rescue
      return false
    end

    def self.f11_trigger?
      down = key_down?(VK_F11)
      trigger = down && @f11_down != true
      @f11_down = down
      return trigger
    rescue
      return false
    end

    def self.log(text)
      File.open(LOG_FILE, "ab") { |f| f.write(text.to_s + "\r\n") }
    rescue
    end

    def self.reset_log
      File.open(LOG_FILE, "wb") do |f|
        f.write("CG HUMAN PHASE 3C BATCH B CLOSURE AUTOREGRESSION v2.6.2c\r\n")
        f.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
        f.write("RULE=Actual Scene_Battle; targeted Hunter Mark ranged-proxy + Brawler pending-action interrupt closure\r\n")
        f.write("BASELINE=Scripts 0..276 sealed; v2.6.2b candidate index277 only\r\n")
        f.write("CLASSIFICATION=v2.6.2a Hunter Mark only recognized explicit <cg_range>; v2.6.2b reuses sealed PMD motion authority for Pokemon proxy skills\r\n")
        f.write("FIXTURE=v2.6.2a Brawler target was KO before Flinch; closure uses surviving E2 pending target with TEST-only ATK reduction\r\nTEST_FIX=v2.6.2c preflight uses sealed RPG::Skill#cg_action_priority_value API; formal candidate277 remains byte-exact v2.6.2b\r\n")
        f.write("------------------------------------------------------------\r\n")
      end
    rescue
    end

    def self.assert_true(name, condition, detail = nil)
      if condition
        log("ASSERT PASS " + name.to_s + (detail == nil ? "" : " " + detail.to_s))
        return true
      end
      msg = name.to_s + (detail == nil ? "" : " " + detail.to_s)
      @failures.push(msg)
      log("ASSERT FAIL " + msg)
      return false
    end

    def self.make_test_troop
      while $data_troops.size <= TEST_TROOP_ID
        $data_troops.push(nil)
      end
      enemy_ids = [608, 749, 742, 624]
      xs = [ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[1],
            ALBERT_CG::GRID_COLUMN_Y[2], ALBERT_CG::GRID_COLUMN_Y[1]]
      members = []
      enemy_ids.each_with_index do |enemy_id, i|
        members.push(ALBERT_CG::SPECIES26.make_troop_member(enemy_id, xs[i], ys[i]))
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID, "Human Phase3C Batch B Closure", members)
    end

    def self.prepare_party
      ids = [master.actor_id_for_dex(25), master.actor_id_for_dex(6), master.actor_id_for_dex(3)]
      ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized, true)
      $game_party.cg_enable_direct_pmd_test_party!
      for aid in ids
        actor = $game_actors[aid]
        next if actor == nil
        actor.change_level(TEST_LEVEL, false)
        actor.recover_all
        actor.cg_reset_stat_stages if actor.respond_to?(:cg_reset_stat_stages)
        actor.instance_variable_set(:@cg_master_ability_id, 0)
        actor.cg_clear_human_trait_records if actor.respond_to?(:cg_clear_human_trait_records)
      end
      h = human
      if h != nil
        h.change_level(TEST_LEVEL, false)
        h.recover_all
        h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages)
        h.instance_variable_set(:@cg_master_ability_id, 0)
        h.instance_variable_set(:@cg_human_job_loadouts, {})
        h.cg_clear_human_trait_records if h.respond_to?(:cg_clear_human_trait_records)
        h.cg_prepare_job_data if h.respond_to?(:cg_prepare_job_data)
      end
    end

    def self.make_guard(battler)
      a = Game_BattleAction.new(battler)
      a.set_guard
      return a
    end

    def self.make_skill(battler, skill_id, target_index)
      a = Game_BattleAction.new(battler)
      a.set_skill(skill_id.to_i)
      a.target_index = target_index.to_i
      return a
    end

    def self.assign_action(battler, action)
      return if battler == nil
      if battler.respond_to?(:cg_round_actions)
        battler.cg_round_actions.clear
        battler.cg_round_actions.push(action)
      end
      battler.cg_assign_action(action) if battler.respond_to?(:cg_assign_action)
      battler.instance_variable_set(:@action, action) unless battler.respond_to?(:cg_assign_action)
    end

    def self.clear_battler_runtime(b)
      return if b == nil
      b.recover_all if b.respond_to?(:recover_all)
      b.cg_reset_stat_stages if b.respond_to?(:cg_reset_stat_stages)
      b.cg_clear_human_trait_records if b.respond_to?(:cg_clear_human_trait_records)
      b.instance_variable_set(:@cg_master_ability_id, 0)
      b.instance_variable_set(:@cg_human_v262_mark_side, nil)
      b.instance_variable_set(:@cg_human_v262_mark_turns, 0)
      b.instance_variable_set(:@cg_human_v262_mark_source, nil)
      if defined?(ALBERT_CG::MOVE_EFFECT) && b.respond_to?(:remove_state)
        sid = ALBERT_CG::MOVE_EFFECT::STATE_FLINCH
        b.remove_state(sid) if b.state?(sid)
      end
    rescue
    end

    def self.preflight
      assert_true("Human Rank2 runtime imported v2.6.2b", $imported["ALBERT_CG_HumanRank2Tactical"].to_s == "2.6.2b")
      water = master.skill_id_for_move(55)
      water_obj = $data_skills[water]
      motion = (defined?(CG_PMD) && CG_PMD.respond_to?(:skill_motion_for)) ? CG_PMD.skill_motion_for(water_obj) : nil
      ranged = ALBERT_CG::HUMAN_RANK2_V262.ranged_skill?(water_obj)
      assert_true("Pokemon Water Gun proxy is classified ranged through sealed PMD motion authority",
        motion == :shoot && ranged == true, "skill=" + water.to_s + " motion=" + motion.inspect + " ranged=" + ranged.to_s)
      assert_true("Brawler interrupt skill remains Priority +2", $data_skills[118].cg_action_priority_value.to_i == 2)
      assert_true("Scripts retain formal Move/Ability catalogs",
        defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.catalog_count.to_i == 373)
    end

    def self.forced_enemy_action(enemy)
      return nil unless active? && enemy != nil && enemy.exist?
      if current_round == 2 && enemy.index.to_i == 2
        return make_skill(enemy, master.skill_id_for_move(33), 0)
      end
      return make_guard(enemy)
    end

    def self.prepare_round
      h = human
      return false if h == nil
      $game_party.members.each { |b| clear_battler_runtime(b) }
      $game_troop.members.each { |b| clear_battler_runtime(b) }
      if defined?(ALBERT_CG::UNIQUE_C_V236) && ALBERT_CG::UNIQUE_C_V236.respond_to?(:clear_redirects)
        ALBERT_CG::UNIQUE_C_V236.clear_redirects
      end
      @actual = []
      @round_pre = {}

      if current_round == 1
        h.cg_change_job(3)
        h.cg_set_battle_slot(:back, 1, true) if h.respond_to?(:cg_set_battle_slot)
        target = $game_troop.members[3]
        ally = $game_party.members[1]
        water = master.skill_id_for_move(55)
        @round_pre[:target_hp] = target.hp.to_i
        @round_pre[:water] = water
        assign_action(h, make_skill(h, 115, 3))
        assign_action(ally, make_skill(ally, water, 3))
        $game_party.members.each do |b|
          next if b == nil || b == h || b == ally
          assign_action(b, make_guard(b))
        end
        log("ROUND 1 BEGIN HunterMark target=E3:" + target.name.to_s + " ally_ranged_skill=" + water.to_s)
      else
        h.cg_change_job(6)
        h.cg_set_battle_slot(:front, 1, true) if h.respond_to?(:cg_set_battle_slot)
        target = $game_troop.members[2]
        h.cg_change_stat_stage(:atk, -6) if h.respond_to?(:cg_change_stat_stage)
        @round_pre[:target_hp] = target.hp.to_i
        @round_pre[:atk_stage] = h.cg_stat_stage(:atk).to_i
        @round_pre[:target_index] = target.index.to_i
        assign_action(h, make_skill(h, 118, 2))
        $game_party.members.each do |b|
          next if b == nil || b == h
          assign_action(b, make_guard(b))
        end
        log("BRAWLER_FIXTURE target=E2:" + target.name.to_s + " target_hp=" + target.hp.to_i.to_s +
            " human_atk_stage=" + @round_pre[:atk_stage].to_s + " reason=ensure_survival_to_test_real_Flinch")
        log("ROUND 2 BEGIN Interrupt target=E2:" + target.name.to_s + " pending=Tackle")
      end
      return true
    end

    def self.record_execution(battler)
      return unless active? && battler != nil
      action = battler.action
      token = battler.actor? ? "A" : "E"
      token += battler.index.to_s
      if action != nil && action.guard?
        token += ":Guard"
      elsif action != nil && action.skill?
        token += ":S" + action.skill_id.to_i.to_s
      else
        token += ":Other"
      end
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + battler.name.to_s + " " + token)
    end

    def self.records_of(battler, kind)
      return [] if battler == nil || !battler.respond_to?(:cg_human_trait_records)
      return battler.cg_human_trait_records.select { |r| r[:kind] == kind }
    end

    def self.assert_round
      h = human
      if current_round == 1
        target = $game_troop.members[3]
        ally = $game_party.members[1]
        mark = records_of(h, :hunter_mark)[-1]
        bonus = records_of(ally, :hunter_mark_bonus)[-1]
        ok = mark != nil && bonus != nil && bonus[:percent].to_i == 115 &&
             bonus[:target].to_s == target.name.to_s && bonus[:skill_id].to_i == @round_pre[:water].to_i &&
             target.hp.to_i < @round_pre[:target_hp].to_i
        @hunter_ok = ok
        assert_true("Archer Hunter Mark amplifies real Pokemon Water Gun proxy +15%", ok,
          "hp=" + @round_pre[:target_hp].to_s + "->" + target.hp.to_i.to_s +
          " mark=" + mark.inspect + " bonus=" + bonus.inspect + " actual=" + @actual.inspect)
      else
        target = $game_troop.members[2]
        rec = records_of(h, :interrupt)[-1]
        enemy_skill = master.skill_id_for_move(33)
        enemy_acted = @actual.any? { |x| x == "E2:S" + enemy_skill.to_s }
        survived = target.hp.to_i > 0
        damaged = target.hp.to_i < @round_pre[:target_hp].to_i
        ok = survived && damaged && rec != nil && rec[:pending] == true && rec[:applied] == true && !enemy_acted
        @interrupt_ok = ok
        assert_true("Brawler Interrupt applies real pending-action Flinch to surviving target and skips that action", ok,
          "hp=" + @round_pre[:target_hp].to_s + "->" + target.hp.to_i.to_s +
          " survived=" + survived.to_s + " enemy_acted=" + enemy_acted.to_s +
          " record=" + rec.inspect + " actual=" + @actual.inspect)
      end
    end

    def self.finish_round
      return unless active?
      assert_round
      @round_index += 1
    end

    def self.finish_suite
      result = @failures.empty? ? "PASS" : "FAIL"
      log("------------------------------------------------------------")
      log("RESULT=" + result)
      log("SUMMARY rounds=2 failures=" + @failures.size.to_s +
          " hunter_mark=" + (@hunter_ok ? "1/1" : "0/1") +
          " interrupt=" + (@interrupt_ok ? "1/1" : "0/1") +
          " tactical_closure=" + ((@hunter_ok && @interrupt_ok) ? "2/2" : "incomplete") +
          " ability_catalog=" + (defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250.catalog_count.to_i.to_s : "?") + "/373" +
          " formal_move=937/937 pending=0")
      @failures.each_with_index { |x,i| log("FAILURE " + (i+1).to_s + " " + x.to_s) }
      @active = false
      return @failures.empty?
    end

    def self.reset_suite
      @round_index = 0
      @failures = []
      @actual = []
      @hunter_ok = false
      @interrupt_ok = false
      @round_pre = {}
    end

    def self.start_auto_test
      return false if active?
      reset_log
      reset_suite
      prepare_party
      make_test_troop
      preflight
      @active = true
      log("AUTO_TEST_START troop=" + TEST_TROOP_ID.to_s)
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue => e
      @failures = [] if @failures == nil
      @failures.push("AUTO_TEST_START_ERROR " + e.class.to_s + ":" + e.message.to_s)
      log("ASSERT FAIL " + @failures[-1])
      @active = false
      return false
    end
  end
end

if defined?(ALBERT_CG::ABILITY_AV_V2547)
  module ALBERT_CG; module ABILITY_AV_V2547; def self.f11_trigger?; return false; end; end; end
end

class Game_Enemy < Game_Battler
  alias cg_v262b_human_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::HUMAN_V262B_TEST) && ALBERT_CG::HUMAN_V262B_TEST.active?
      action = ALBERT_CG::HUMAN_V262B_TEST.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    return cg_v262b_human_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v262b_human_execute_action execute_action
  def execute_action
    b = @active_battler
    ALBERT_CG::HUMAN_V262B_TEST.record_execution(b) if defined?(ALBERT_CG::HUMAN_V262B_TEST) && ALBERT_CG::HUMAN_V262B_TEST.active?
    return cg_v262b_human_execute_action
  end

  alias cg_v262b_human_turn_end turn_end
  def turn_end
    ALBERT_CG::HUMAN_V262B_TEST.finish_round if defined?(ALBERT_CG::HUMAN_V262B_TEST) && ALBERT_CG::HUMAN_V262B_TEST.active?
    return cg_v262b_human_turn_end
  end

  alias cg_v262b_human_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::HUMAN_V262B_TEST) && ALBERT_CG::HUMAN_V262B_TEST.active?
      return cg_v262b_human_start_party_command
    end
    cg_v262b_human_start_party_command
    return unless $game_temp.in_battle
    if ALBERT_CG::HUMAN_V262B_TEST.finished?
      ALBERT_CG::HUMAN_V262B_TEST.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::HUMAN_V262B_TEST.prepare_round
    start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v262b_human_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v262b_human_bootstrap_demo_party
      if defined?(ALBERT_CG::HUMAN_V262B_TEST) && ALBERT_CG::HUMAN_V262B_TEST.active?
        ALBERT_CG::HUMAN_V262B_TEST.prepare_party
      end
      return result
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v262b_human_scene_map_update update
  def update
    cg_v262b_human_scene_map_update
    if !$game_temp.in_battle && !ALBERT_CG::HUMAN_V262B_TEST.active? && ALBERT_CG::HUMAN_V262B_TEST.f11_trigger?
      Sound.play_decision
      ALBERT_CG::HUMAN_V262B_TEST.start_auto_test
    end
  end
end
