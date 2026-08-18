# RMVX_SCRIPT_INDEX: 279
# RMVX_SCRIPT_ID: 279
# RMVX_SCRIPT_NAME: CG Human Phase3C Rank3 AutoRegression v2.6.3a
# RMVX_SOURCE_SHA256: bc76e8c173e778f3a0b90747b46314d707aad4fbb8802713819392b96ce94942

#==============================================================================
# ■ CG Human Phase 3C Rank-3 AutoRegression v2.6.3a
#------------------------------------------------------------------------------
# 【用途】
#  以一場真實 Scene_Battle、六個回合逐職驗證 Human Rank-3 Skill 119..124。
#  本頁只存在 TEST build；不屬於正式 Runtime，也不得合併至 GitHub main。
#
# 【測試範圍】
#  R1 劍士：DEF -1 fixture -> 裂甲追斬真正增傷。
#  R2 守衛：聖盾堡壘 DEF/SpD +1 + 正式 Follow Me Redirect。
#  R3 弓手：Hunter Mark fixture -> 獵殺箭增傷並消耗標記。
#  R4 法師：奧術領域 -> SpA +1 + FIELD_V233 Psychic Terrain 3 回合。
#  R5 神官：聖域祈禱 -> 四名我方真實回復 + Safeguard 3 回合。
#  R6 格鬥家：疾風連拳 -> 真實 multi-hit combo + 同 Action SPE 只提升一次。
#
# 【操作】
#  地圖按 F11 一次。測試器會自動配置隊伍、技能、目標、前置狀態與敵方行動，
#  玩家不需要輸入任何戰鬥指令。完成後輸出 CG_AutoRegression_LATEST.log。
#==============================================================================

module ALBERT_CG
  module HUMAN_V263A_TEST
    VERSION = "2.6.3a"
    LOG_FILE = "CG_AutoRegression_LATEST.log"
    TEST_TROOP_ID = 761
    TEST_LEVEL = 30
    VK_F11 = 0x7A

    ROUND_CLASS = {1=>1, 2=>2, 3=>3, 4=>4, 5=>5, 6=>6}
    ROUND_SKILL = {1=>119, 2=>120, 3=>121, 4=>122, 5=>123, 6=>124}
    ROUND_ROW   = {1=>:front, 2=>:front, 3=>:back, 4=>:back, 5=>:back, 6=>:front}

    def self.active?; return @active == true; end
    def self.finished?; return @round_index.to_i >= 6; end
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
        f.write("CG HUMAN PHASE 3C RANK-3 AUTOREGRESSION v2.6.3a\r\n")
        f.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
        f.write("RULE=Actual Scene_Battle; six canonical Human Rank-3 tactical skills\r\n")
        f.write("BASELINE=Scripts 0..277 sealed; v2.6.3 candidate index278 only\r\n")
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
        TEST_TROOP_ID, "Human Phase3C Rank3", members)
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

    def self.forced_enemy_action(enemy)
      return nil unless active? && enemy != nil && enemy.exist?
      if current_round == 2 && enemy.index.to_i == 0
        return make_skill(enemy, master.skill_id_for_move(33), 1)
      end
      return make_guard(enemy)
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
      b.instance_variable_set(:@cg_v263_momentum_action_id, nil)
      if defined?(ALBERT_CG::MOVE_EFFECT) && b.respond_to?(:remove_state)
        sid = ALBERT_CG::MOVE_EFFECT::STATE_FLINCH
        b.remove_state(sid) if b.state?(sid)
      end
    rescue
    end

    def self.preflight
      assert_true("Human Rank3 runtime imported v2.6.3", $imported["ALBERT_CG_HumanRank3Tactical"].to_s == "2.6.3")
      assert_true("Six Rank3 skills exist", (119..124).all? { |sid| $data_skills[sid] != nil })
      tree_ok = true
      for cid in 1..6
        ids = ALBERT_CG.human_tree_skill_ids(cid, 3)
        tree_ok = false unless ids.include?(ALBERT_CG::HUMAN_STARTER_SKILLS[cid])
        tree_ok = false unless ids.include?(ALBERT_CG::HUMAN_RANK2_SKILLS[cid])
        tree_ok = false unless ids.include?(ALBERT_CG::HUMAN_RANK3_SKILLS[cid])
      end
      assert_true("Six Rank3 tree nodes canonical", tree_ok)
      assert_true("Guardian Rank3 uses self SBS presentation", $data_skills[120].base_action.to_s == "SKILL_USE")
      assert_true("Archer Rank3 uses Bow SBS THROW_WEAPON", $data_skills[121].base_action.to_s == "THROW_WEAPON")
      assert_true("Cleric Rank3 uses SBS SKILL_ALL", $data_skills[123].base_action.to_s == "SKILL_ALL")
      assert_true("Brawler Rank3 uses RAPID_MULTI_ATTACK", $data_skills[124].base_action.to_s == "RAPID_MULTI_ATTACK")
      assert_true("Scripts retain formal Move/Ability catalogs",
        defined?(ALBERT_CG::ABILITY_V250) && ALBERT_CG::ABILITY_V250.catalog_count.to_i == 373)
    end

    def self.prepare_round
      h = human
      return false if h == nil
      cid = ROUND_CLASS[current_round]
      sid = ROUND_SKILL[current_round]
      h.cg_change_job(cid)
      h.cg_set_battle_slot(ROUND_ROW[current_round], 1, true) if h.respond_to?(:cg_set_battle_slot)

      ALBERT_CG::FIELD_V233.reset if defined?(ALBERT_CG::FIELD_V233) && ALBERT_CG::FIELD_V233.respond_to?(:reset)
      $game_party.members.each { |b| clear_battler_runtime(b) }
      $game_troop.members.each { |b| clear_battler_runtime(b) }
      if defined?(ALBERT_CG::UNIQUE_C_V236) && ALBERT_CG::UNIQUE_C_V236.respond_to?(:clear_redirects)
        ALBERT_CG::UNIQUE_C_V236.clear_redirects
      end

      @actual = []
      @round_pre = {}

      if current_round == 1
        target = $game_troop.members[0]
        target.cg_change_stat_stage(:def, -1)
        @round_pre[:target_hp] = target.hp.to_i
        @round_pre[:target_def] = target.cg_stat_stage(:def).to_i
        assign_action(h, make_skill(h, sid, 0))
      elsif current_round == 2
        ally = $game_party.members[1]
        @round_pre[:human_hp] = h.hp.to_i
        @round_pre[:ally_hp] = ally.hp.to_i
        @round_pre[:def] = h.cg_stat_stage(:def).to_i
        @round_pre[:spd] = h.cg_stat_stage(:spd).to_i
        assign_action(h, make_skill(h, sid, 0))
      elsif current_round == 3
        target = $game_troop.members[3]
        ALBERT_CG::HUMAN_RANK2_V262.apply_hunter_mark(h, target)
        @round_pre[:target_hp] = target.hp.to_i
        @round_pre[:mark_turns] = target.instance_variable_get(:@cg_human_v262_mark_turns).to_i
        assign_action(h, make_skill(h, sid, 3))
      elsif current_round == 4
        @round_pre[:spa] = h.cg_stat_stage(:spa).to_i
        assign_action(h, make_skill(h, sid, 0))
      elsif current_round == 5
        before = []
        $game_party.members.each do |b|
          loss = [b.maxhp.to_i / 4, 20].max
          b.hp = [b.maxhp.to_i - loss, 1].max
          before.push(b.hp.to_i)
        end
        @round_pre[:party_hp] = before
        assign_action(h, make_skill(h, sid, 0))
      elsif current_round == 6
        target = $game_troop.members[2]
        h.cg_change_stat_stage(:atk, -6)
        @round_pre[:target_hp] = target.hp.to_i
        @round_pre[:spe] = h.cg_stat_stage(:spe).to_i
        assign_action(h, make_skill(h, sid, 2))
      end

      $game_party.members.each do |b|
        next if b == nil || b == h
        assign_action(b, make_guard(b))
      end

      log("ROUND " + current_round.to_s + " BEGIN class=" + cid.to_s + ":" + ALBERT_CG::JOB_DISPLAY_NAMES[cid].to_s +
          " skill=" + sid.to_s + ":" + $data_skills[sid].name.to_s + " row=" + ROUND_ROW[current_round].to_s)
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
      r = current_round
      if r == 1
        target = $game_troop.members[0]
        rec = records_of(h, :sword_rank3_followup)[-1]
        ok = target.hp.to_i < @round_pre[:target_hp].to_i && rec != nil &&
             rec[:percent].to_i == ALBERT_CG::HUMAN_RANK3_V263::SWORD_BROKEN_DEF_PERCENT &&
             rec[:def_stage].to_i < 0
        @covered[:sword] = true if ok
        assert_true("Swordsman 裂甲追斬 gains real bonus against broken DEF", ok,
          "hp=" + @round_pre[:target_hp].to_s + "->" + target.hp.to_i.to_s + " def=" +
          @round_pre[:target_def].to_s + " record=" + rec.inspect)
      elsif r == 2
        ally = $game_party.members[1]
        rec = records_of(h, :guardian_rank3_bastion)[-1]
        ok = rec != nil && rec[:redirect] == true &&
             h.cg_stat_stage(:def).to_i == @round_pre[:def].to_i + 1 &&
             h.cg_stat_stage(:spd).to_i == @round_pre[:spd].to_i + 1 &&
             h.hp.to_i < @round_pre[:human_hp].to_i && ally.hp.to_i == @round_pre[:ally_hp].to_i
        @covered[:guardian] = true if ok
        assert_true("Guardian 聖盾堡壘 buffs DEF/SpD and redirects real enemy attack", ok,
          "human_hp=" + @round_pre[:human_hp].to_s + "->" + h.hp.to_i.to_s +
          " ally_hp=" + @round_pre[:ally_hp].to_s + "->" + ally.hp.to_i.to_s +
          " def=" + @round_pre[:def].to_s + "->" + h.cg_stat_stage(:def).to_i.to_s +
          " spd=" + @round_pre[:spd].to_s + "->" + h.cg_stat_stage(:spd).to_i.to_s +
          " record=" + rec.inspect)
      elsif r == 3
        target = $game_troop.members[3]
        exec = records_of(h, :archer_rank3_execute)[-1]
        mark_bonus = records_of(h, :hunter_mark_bonus)[-1]
        turns_after = target.instance_variable_get(:@cg_human_v262_mark_turns).to_i
        ok = @round_pre[:mark_turns].to_i > 0 && target.hp.to_i < @round_pre[:target_hp].to_i &&
             exec != nil && exec[:mark_consumed] == true && turns_after == 0 && mark_bonus != nil
        @covered[:archer] = true if ok
        assert_true("Archer 獵殺箭 consumes Hunter Mark after real ranged execute bonus", ok,
          "hp=" + @round_pre[:target_hp].to_s + "->" + target.hp.to_i.to_s +
          " mark=" + @round_pre[:mark_turns].to_s + "->" + turns_after.to_s +
          " execute=" + exec.inspect + " mark_bonus=" + mark_bonus.inspect)
      elsif r == 4
        rec = records_of(h, :mage_rank3_domain)[-1]
        st = ALBERT_CG::FIELD_V233.state
        ok = rec != nil && h.cg_stat_stage(:spa).to_i == @round_pre[:spa].to_i + 1 &&
             st.terrain == :psychic && st.terrain_turns.to_i == ALBERT_CG::HUMAN_RANK3_V263::ARCANE_TERRAIN_TURNS
        @covered[:mage] = true if ok
        assert_true("Mage 奧術領域 raises SpA and writes formal Psychic Terrain", ok,
          "spa=" + @round_pre[:spa].to_s + "->" + h.cg_stat_stage(:spa).to_i.to_s +
          " terrain=" + st.terrain.inspect + " turns=" + st.terrain_turns.to_i.to_s + " record=" + rec.inspect)
      elsif r == 5
        after = $game_party.members.collect { |b| b.hp.to_i }
        healed = 0
        for i in 0...after.size
          healed += 1 if after[i].to_i > @round_pre[:party_hp][i].to_i
        end
        safeguard = ALBERT_CG::FIELD_V233.side_effect?(:ally, :safeguard)
        recs = records_of(h, :cleric_rank3_sanctuary)
        ok = healed == $game_party.members.size && safeguard && recs.size >= $game_party.members.size
        @covered[:cleric] = true if ok
        assert_true("Cleric 聖域祈禱 heals whole party and establishes formal Safeguard", ok,
          "healed=" + healed.to_s + "/" + $game_party.members.size.to_s +
          " before=" + @round_pre[:party_hp].inspect + " after=" + after.inspect +
          " safeguard=" + safeguard.to_s + " records=" + recs.size.to_s)
      elsif r == 6
        target = $game_troop.members[2]
        combo = records_of(h, :combo_rhythm).select { |x| x[:skill_id].to_i == 124 }
        momentum = records_of(h, :brawler_rank3_momentum)
        ok = target.hp.to_i < @round_pre[:target_hp].to_i && combo.size >= 3 && momentum.size == 1 &&
             h.cg_stat_stage(:spe).to_i == @round_pre[:spe].to_i + 1
        @covered[:brawler] = true if ok
        assert_true("Brawler 疾風連拳 keeps multi-hit combo and grants SPE exactly once per Action", ok,
          "hp=" + @round_pre[:target_hp].to_s + "->" + target.hp.to_i.to_s +
          " combo_hits=" + combo.size.to_s + " momentum=" + momentum.inspect +
          " spe=" + @round_pre[:spe].to_s + "->" + h.cg_stat_stage(:spe).to_i.to_s)
      end

      skill_ok = @actual.any? { |x| x == "A0:S" + ROUND_SKILL[r].to_s }
      @skills[ROUND_SKILL[r]] = true if skill_ok
      assert_true("Round " + r.to_s + " Rank3 skill executed", skill_ok, "actual=" + @actual.inspect)
      log("ROUND " + r.to_s + " END human_records=" + h.cg_human_trait_records.inspect)
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
      log("SUMMARY rounds=6 failures=" + @failures.size.to_s +
          " rank3_skills=" + @skills.keys.size.to_s + "/6 tactical_checks=" + @covered.keys.size.to_s + "/6" +
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
      @covered = {}
      @skills = {}
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

# TEST-only：停用 production 中最後一個歷史 F11 harness，避免按鍵競爭。
if defined?(ALBERT_CG::ABILITY_AV_V2547)
  module ALBERT_CG; module ABILITY_AV_V2547; def self.f11_trigger?; return false; end; end; end
end

class Game_Enemy < Game_Battler
  alias cg_v263a_human_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::HUMAN_V263A_TEST) && ALBERT_CG::HUMAN_V263A_TEST.active?
      action = ALBERT_CG::HUMAN_V263A_TEST.forced_enemy_action(self)
      if action != nil
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action = action unless respond_to?(:cg_assign_action)
        return
      end
    end
    return cg_v263a_human_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v263a_human_execute_action execute_action
  def execute_action
    b = @active_battler
    ALBERT_CG::HUMAN_V263A_TEST.record_execution(b) if defined?(ALBERT_CG::HUMAN_V263A_TEST) && ALBERT_CG::HUMAN_V263A_TEST.active?
    return cg_v263a_human_execute_action
  end

  alias cg_v263a_human_turn_end turn_end
  def turn_end
    ALBERT_CG::HUMAN_V263A_TEST.finish_round if defined?(ALBERT_CG::HUMAN_V263A_TEST) && ALBERT_CG::HUMAN_V263A_TEST.active?
    return cg_v263a_human_turn_end
  end

  alias cg_v263a_human_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::HUMAN_V263A_TEST) && ALBERT_CG::HUMAN_V263A_TEST.active?
      return cg_v263a_human_start_party_command
    end
    cg_v263a_human_start_party_command
    return unless $game_temp.in_battle
    if ALBERT_CG::HUMAN_V263A_TEST.finished?
      ALBERT_CG::HUMAN_V263A_TEST.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::HUMAN_V263A_TEST.prepare_round
    start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v263a_human_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v263a_human_bootstrap_demo_party
      if defined?(ALBERT_CG::HUMAN_V263A_TEST) && ALBERT_CG::HUMAN_V263A_TEST.active?
        ALBERT_CG::HUMAN_V263A_TEST.prepare_party
      end
      return result
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v263a_human_scene_map_update update
  def update
    cg_v263a_human_scene_map_update
    if !$game_temp.in_battle && !ALBERT_CG::HUMAN_V263A_TEST.active? && ALBERT_CG::HUMAN_V263A_TEST.f11_trigger?
      Sound.play_decision
      ALBERT_CG::HUMAN_V263A_TEST.start_auto_test
    end
  end
end
