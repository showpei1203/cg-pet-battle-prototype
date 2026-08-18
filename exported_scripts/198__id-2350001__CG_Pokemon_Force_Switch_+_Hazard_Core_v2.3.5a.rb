# RMVX_SCRIPT_INDEX: 198
# RMVX_SCRIPT_ID: 2350001
# RMVX_SCRIPT_NAME: CG Pokemon Force Switch + Hazard Core v2.3.5a
# RMVX_SOURCE_SHA256: a5b5765d04cec0c6df865d6171f81db5cba2dca3adebfd25c43b1779f0f8f896

#==============================================================================
# ■ CG Pokemon Force Switch + Hazard Core v2.3.5a
#------------------------------------------------------------------------------
# 【用途】
#  完成 Pokémon Move Catalog 中最後 2 個 Force Switch 類招式：
#    18 Whirlwind／吹飛
#    46 Roar／吼叫
#  並把 v2.3.3 已完成的 Spikes／Toxic Spikes／Stealth Rock／Sticky Web
#  正式接到「真正換入」生命週期，而不再只靠 Field Regression 直接呼叫
#  apply_entry_hazards 來模擬換入。
#
# 【目前正式隊伍規則】
#  本專案目前為「主角 + 3 隻攜帶 Pokémon 全部同時參戰」，正常玩家戰鬥沒有
#  候補換寵指令。因此本頁絕不把倉庫 Pokémon 擅自當成戰鬥候補。
#  - 我方：只有額外系統明確提供 battle reserve 時才可被 Force Switch。
#  - 敵方：使用 RPG Maker VX Troop 原生 Hidden Member 作為戰鬥候補。
#    Hidden Member 活著且為 Pokémon 時，可被 Roar／Whirlwind 強制換入。
#  - 沒有合法候補：招式正常執行動畫，但 Force Switch 效果失敗。
#
# 【Force Switch 正式規則】
#  1. 目標必須是 Pokémon、仍在場、仍存活。
#  2. Fairy Lock 生效時禁止強制換入。
#  3. Ingrain／扎根中的目標不能被強制換出。
#  4. Ability 21 Suction Cups／吸盤、275 Guard Dog／看門犬免疫強制換出。
#     v2.3.5a 補上 Game_Enemy Ability Bridge：敵方會先讀 <master_ability: N>，
#     若無明示則回退 Master Data 該物種 Ability Pool 第一項。
#  5. Roar 額外受 Ability 43 Soundproof／隔音阻擋；Whirlwind 不受此條影響。
#  6. Substitute 仍依本專案 v2.3.4 的統一規則阻擋敵方 Status Move，因此
#     Roar／Whirlwind 打在仍有 Substitute 的對手時不會進入本 Core。
#  7. 成功換出時：
#     - 保留 HP 與主要異常（中毒／麻痺／睡眠／燒傷／冰凍等）。
#     - 清除能力階級與個體型暫時戰鬥記憶。
#     - 清除 Protect／Trap／Leech Seed／Yawn／Perish／Aqua Ring 等換出即失效狀態。
#     - 原 battler 變為 hidden reserve，Replacement 進入完全相同的 Grid slot。
#     - Replacement 本回合不取得額外行動。
#  8. 換入完成後立即套用 v2.3.3 Entry Hazard：
#     Spikes、Toxic Spikes、Stealth Rock、Sticky Web。
#
# 【敵方候補設定方式】
#  在 RPG Maker VX Troop 內額外加入 Enemy，並勾選「途中から出現／Hidden」。
#  只要該 Hidden Enemy 還活著，即可作為 Roar／Whirlwind 的合法候補。
#  這使用 VX 原生 Troop Member 結構，不另造一份敵方名冊。
#
# 【可調參數】
#  MOVE_WHIRLWIND = 18
#  MOVE_ROAR      = 46
#  SUCTION_CUPS_ABILITY_ID = 21
#  SOUNDPROOF_ABILITY_ID   = 43
#  GUARD_DOG_ABILITY_ID    = 275
#  TEST_TROOP_ID = 694
#
# 【事件／腳本呼叫】
#  正常戰鬥不需事件呼叫，Skill Effect 會自動處理。
#  Debug 可直接：
#    ALBERT_CG::FORCE_SWITCH_V235.force_switch(user, target, 46)
#  回傳 Hash：
#    {:success=>true/false, :reason=>Symbol, :outgoing=>..., :incoming=>...,
#     :hazard=>{:damage=>N,:states=>[],:spe_delta=>N}}
#
# 【AutoRegression】
#  地圖畫面按 F11，只啟動本版最新版 Regression。
#  4 回合真正 Scene_Battle：
#    Round1：Spikes + Stealth Rock -> Roar -> Hidden Reserve #1 真正換入並受傷。
#    Round2：Toxic Spikes + Sticky Web -> Whirlwind -> Hidden Reserve #2，
#            驗證 Poison + SPE -1 + 累積 Hazard 傷害。
#    Round3：Roar 對 Suction Cups 目標，必須被阻擋。
#    Round4：Fairy Lock 先成立，再使用 Whirlwind，必須被阻擋。
#  成功標準：
#    RESULT=PASS
#    SUMMARY rounds=4 failures=0 force_switch_moves=2/2 hazard_entries=2
#
# 【LOG】
#  版本 LOG：Pokemon_ForceSwitch_AutoTest_v2_3_5a.log
#  固定最新版：CG_AutoRegression_LATEST.log
#  重要事件同步鏡像到 PMD_BattleInitTrace.log。
#
# 【實際範例】
#  敵方 E0 在前排，E4 為 Hidden 傑尼龜候補；敵方場上已有 Spikes + Stealth Rock。
#  我方使用 Roar 命中 E0：
#    FORCE_SWITCH_OUT ... out=E0
#    FORCE_SWITCH_IN  ... in=E4 slot=front/0
#    FIELD_ENTRY battler=傑尼龜 ... damage=...
#    FORCE_SWITCH_SUCCESS move=46 ...
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonForceSwitchHazardCore"] = "2.3.5a"

#==============================================================================
# ■ Game_Enemy Master Ability Bridge v2.3.5a
#------------------------------------------------------------------------------
# 【用途】
#  v2.3.5 實機發現 Game_Actor 已有 cg_master_ability_id，但 Game_Enemy 沒有，
#  造成敵方 Suction Cups／Soundproof／Guard Dog 在 Force Switch 判定永遠被視為 0。
# 【規則】
#  1. 優先使用 Runtime 已明示的 @cg_master_ability_id。
#  2. 其次讀 Enemy Note 最後一個 <master_ability: N>。
#  3. 若 Note 未設定，回退該 National Dex 的 Master Data Ability Pool 第一項。
# 【呼叫範例】
#    enemy.cg_master_ability_id   #=> 21
#==============================================================================
class Game_Enemy < Game_Battler
  def cg_master_ability_id
    return @cg_master_ability_id.to_i if @cg_master_ability_id != nil
    text = ""
    begin
      data = respond_to?(:enemy) ? enemy : nil
      text = data.note.to_s if data != nil
    rescue
      text = ""
    end
    matches = text.scan(/<master_ability\s*:\s*(\d+)\s*>/i)
    if matches != nil && !matches.empty?
      @cg_master_ability_id = matches[matches.size - 1][0].to_i
      return @cg_master_ability_id.to_i
    end
    if respond_to?(:cg_national_dex) && defined?(ALBERT_CG::POKEMON_MASTER)
      pool = ALBERT_CG::POKEMON_MASTER.ability_pool(cg_national_dex.to_i)
      if pool != nil && !pool.empty?
        @cg_master_ability_id = pool[0].to_i
        return @cg_master_ability_id.to_i
      end
    end
    return 0
  rescue
    return 0
  end
end

module ALBERT_CG
  module FORCE_SWITCH_V235
    VERSION = "2.3.5a"
    MOVE_WHIRLWIND = 18
    MOVE_ROAR      = 46
    HANDLED_MOVE_IDS = [MOVE_WHIRLWIND, MOVE_ROAR]

    SUCTION_CUPS_ABILITY_ID = 21
    SOUNDPROOF_ABILITY_ID   = 43
    GUARD_DOG_ABILITY_ID    = 275

    TEST_TROOP_ID = 694
    TEST_LEVEL = 40
    TEST_ALLIES = [
      {:dex=>25, :level=>40, :ability=>9,   :moves=>[191,390,33,33]},
      {:dex=>3,  :level=>40, :ability=>65,  :moves=>[446,564,587,33]},
      {:dex=>94, :level=>40, :ability=>130, :moves=>[46,18,46,18]},
    ]
    # E0-E3 active, E4-E5 hidden reserves.
    TEST_ENEMIES = [
      {:dex=>143, :level=>40, :ability=>47, :moves=>[150,150,150,150]},
      {:dex=>94,  :level=>40, :ability=>130,:moves=>[150,150,150,150]},
      {:dex=>376, :level=>40, :ability=>21, :moves=>[150,150,150,150]},
      {:dex=>68,  :level=>40, :ability=>62, :moves=>[150,150,150,150]},
      {:dex=>7,   :level=>40, :ability=>67, :moves=>[150,150,150,150]},
      {:dex=>4,   :level=>40, :ability=>66, :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"ROAR_SPIKES_STEALTH_ROCK_ENTRY",
        :allies=>[
          {:kind=>:attack, :target=>2},
          {:kind=>:move, :move_id=>191, :target=>0},
          {:kind=>:move, :move_id=>446, :target=>0},
          {:kind=>:move, :move_id=>46,  :target=>0},
        ]
      },
      {
        :name=>"WHIRLWIND_TOXIC_SPIKES_STICKY_WEB_ENTRY",
        :allies=>[
          {:kind=>:attack, :target=>2},
          {:kind=>:move, :move_id=>390, :target=>1},
          {:kind=>:move, :move_id=>564, :target=>1},
          {:kind=>:move, :move_id=>18,  :target=>1},
        ]
      },
      {
        :name=>"SUCTION_CUPS_BLOCK",
        :allies=>[
          {:kind=>:attack, :target=>2},
          {:kind=>:move, :move_id=>33, :target=>2},
          {:kind=>:move, :move_id=>33, :target=>2},
          {:kind=>:move, :move_id=>46, :target=>2},
        ]
      },
      {
        :name=>"FAIRY_LOCK_BLOCK",
        :allies=>[
          {:kind=>:attack, :target=>2},
          {:kind=>:move, :move_id=>33,  :target=>2},
          {:kind=>:move, :move_id=>587, :target=>2},
          {:kind=>:move, :move_id=>18,  :target=>3},
        ]
      },
    ]

    # Priority 0 行動的 deterministic SPE；Roar/Whirlwind 原作 Priority -6，
    # 因此無論速度如何都會在普通行動之後執行。
    TEST_SPEEDS = {
      :r1=>[90,130,120,110, 80,70,60,50,40,30],
      :r2=>[90,130,120,110, 80,70,60,50,40,30],
      :r3=>[90,130,120,110, 80,70,60,50,40,30],
      :r4=>[90,130,120,110, 80,70,60,50,40,30],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A1:M191","A2:M446","A0:Attack","E0:M150","E1:M150","E2:M150","E3:M150","A3:M46"],
      2=>["A1:M390","A2:M564","A0:Attack","E1:M150","E2:M150","E3:M150","E4:M150","A3:M18"],
      3=>["A1:M33","A2:M33","A0:Attack","E2:M150","E3:M150","E4:M150","E5:M150","A3:M46"],
      4=>["A1:M33","A2:M587","A0:Attack","E2:M150","E3:M150","E4:M150","E5:M150","A3:M18"],
    }

    VK_F11 = 0x7A
    begin
      KEY_API = Win32API.new("user32", "GetAsyncKeyState", "i", "i")
    rescue
      KEY_API = nil
    end

    def self.master
      return defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil
    end

    def self.project_root
      if defined?(ALBERT_CG::UNIQUE_B_V234) && ALBERT_CG::UNIQUE_B_V234.respond_to?(:project_root)
        return ALBERT_CG::UNIQUE_B_V234.project_root
      end
      return Dir.pwd
    rescue
      return Dir.pwd
    end

    def self.log_path
      return File.join(project_root, "Pokemon_ForceSwitch_AutoTest_v2_3_5a.log")
    end

    def self.latest_log_path
      return File.join(project_root, "CG_AutoRegression_LATEST.log")
    end

    def self.trace_log_path
      return File.join(project_root, "PMD_BattleInitTrace.log")
    end

    def self.write_line(path, text, mode="ab")
      File.open(path, mode) { |f| f.write(text.to_s + "\r\n") }
      return true
    rescue
      return false
    end

    def self.important_line?(line)
      return true if line.index("AUTO_TEST_START") == 0
      return true if line.index("FORCE_SWITCH_") == 0
      return true if line.index("ASSERT PASS") == 0 || line.index("ASSERT FAIL") == 0
      return true if line.index("RESULT=") == 0 || line.index("SUMMARY ") == 0
      return false
    end

    def self.log(line)
      text = line.to_s
      write_line(log_path, text)
      write_line(latest_log_path, text)
      write_line(trace_log_path, "[FORCE_SWITCH_AUTOTEST] " + text) if important_line?(text)
    end

    def self.reset_log
      header = [
        "CG POKEMON FORCE SWITCH + HAZARD AUTO REGRESSION v2.3.5a",
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        "RULE=Actual Scene_Battle; hidden troop reserves; Roar/Whirlwind + real Hazard entry",
        "AUTOTEST_LOG_PATH=" + log_path.to_s,
        "AUTOTEST_LATEST_PATH=" + latest_log_path.to_s,
        "------------------------------------------------------------"
      ]
      [log_path, latest_log_path].each do |p|
        begin
          File.open(p, "wb") { |f| header.each { |x| f.write(x + "\r\n") } }
        rescue
        end
      end
    end

    def self.key_down?(vk)
      return false if KEY_API == nil
      return (KEY_API.call(vk) & 0x8000) != 0
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

    def self.active?
      return @active == true
    end

    def self.current_round
      return @round_index.to_i + 1
    end

    def self.current_plan
      return ROUND_PLANS[@round_index.to_i]
    end

    def self.finished?
      return @round_index.to_i >= ROUND_PLANS.size
    end

    def self.pokemon_battler?(battler)
      return false if battler == nil
      return battler.respond_to?(:cg_national_dex) && battler.cg_national_dex.to_i > 0
    rescue
      return false
    end

    def self.ability_id(battler)
      return 0 if battler == nil || !battler.respond_to?(:cg_master_ability_id)
      return battler.cg_master_ability_id.to_i
    rescue
      return 0
    end

    def self.force_switch_block_reason(target, move_id)
      return :invalid_target if target == nil || !pokemon_battler?(target)
      return :not_present if target.hidden || target.hp.to_i <= 0
      if defined?(ALBERT_CG::FIELD_V233) && ALBERT_CG::FIELD_V233.switch_locked?
        return :fairy_lock
      end
      if defined?(ALBERT_CG::MOVE_EFFECT) &&
         target.state?(ALBERT_CG::MOVE_EFFECT::STATE_INGRAIN)
        return :ingrain
      end
      aid = ability_id(target)
      return :suction_cups if aid == SUCTION_CUPS_ABILITY_ID
      return :guard_dog if aid == GUARD_DOG_ABILITY_ID
      return :soundproof if move_id.to_i == MOVE_ROAR && aid == SOUNDPROOF_ABILITY_ID
      return nil
    end

    def self.enemy_reserve_candidates(target)
      return [] if $game_troop == nil
      list = []
      $game_troop.members.each do |b|
        next if b == nil || b == target
        next unless b.hidden
        next unless b.hp.to_i > 0
        next unless pokemon_battler?(b)
        list.push(b)
      end
      return list
    end

    # 目前正式 1+3 隊伍沒有玩家 battle reserve；保留 API 擴充點，但不把倉庫寵物
    # 自動拉入戰場，避免 Force Switch 偷改正式隊伍規則。
    def self.ally_reserve_candidates(target)
      if $game_party != nil && $game_party.respond_to?(:cg_force_switch_reserve_pets)
        return $game_party.cg_force_switch_reserve_pets(target).select do |b|
          b != nil && b != target && b.hp.to_i > 0 && pokemon_battler?(b)
        end
      end
      return []
    rescue
      return []
    end

    def self.reserve_candidates(target)
      return [] if target == nil
      return target.actor? ? ally_reserve_candidates(target) : enemy_reserve_candidates(target)
    end

    def self.choose_reserve(target, candidates)
      return nil if candidates == nil || candidates.empty?
      # Regression 固定採 index 最小者；正式遊戲使用隨機候補，符合原作強制換入概念。
      if active?
        desired = current_round == 1 ? 4 : (current_round == 2 ? 5 : nil)
        if desired != nil
          exact = candidates.find { |b| b.respond_to?(:index) && b.index.to_i == desired }
          return exact if exact != nil
        end
        return candidates.sort_by { |b| b.respond_to?(:index) ? b.index.to_i : 0 }[0]
      end
      return candidates[rand(candidates.size)]
    end

    def self.clear_switch_out_volatile(battler)
      return if battler == nil
      battler.cg_reset_stat_stages if battler.respond_to?(:cg_reset_stat_stages)
      battler.cg_clear_v231_battle_flags if battler.respond_to?(:cg_clear_v231_battle_flags)
      battler.cg_v234_clear_battle_memory if battler.respond_to?(:cg_v234_clear_battle_memory)
      if defined?(ALBERT_CG::MOVE_EFFECT)
        ids = []
        [:STATE_PROTECT, :STATE_TRAP, :STATE_LEECH_SEED, :STATE_YAWN,
         :STATE_PERISH, :STATE_AQUA_RING].each do |sym|
          ids.push(ALBERT_CG::MOVE_EFFECT.const_get(sym)) if ALBERT_CG::MOVE_EFFECT.const_defined?(sym)
        end
        ids.uniq.each { |sid| battler.remove_state(sid) if battler.state?(sid) }
      end
      battler.instance_variable_set(:@cg_leech_seed_source, nil)
    rescue => e
      log("FORCE_SWITCH_VOLATILE_CLEAR_ERROR battler=" + battler.name.to_s +
          " " + e.class.to_s + ":" + e.message.to_s)
    end

    def self.show_switch_text(text)
      scene = $scene
      if scene != nil && scene.respond_to?(:cg_show_special_action_text, true)
        scene.send(:cg_show_special_action_text, text.to_s)
      end
    rescue
    end

    def self.show_hazard_popup(battler, hazard_result)
      return if battler == nil || hazard_result == nil
      damage = hazard_result[:damage].to_i
      return if damage <= 0
      scene = $scene
      return if scene == nil
      spriteset = scene.instance_variable_get(:@spriteset)
      if spriteset != nil && spriteset.respond_to?(:set_damage_pop)
        spriteset.set_damage_pop(battler.actor?, battler.index, damage)
      end
    rescue
    end

    def self.note_switch_event(move_id, user, outgoing, incoming, result)
      @switch_events = {} if @switch_events == nil
      @switch_events[current_round] = {
        :move_id=>move_id.to_i, :user=>user, :outgoing=>outgoing,
        :incoming=>incoming, :hazard=>result
      }
    end

    def self.note_block_event(move_id, target, reason)
      @block_events = {} if @block_events == nil
      @block_events[current_round] = {:move_id=>move_id.to_i, :target=>target, :reason=>reason}
    end

    def self.mark_apply(move_id, success)
      @apply_counts = {} if @apply_counts == nil
      @success_counts = {} if @success_counts == nil
      mid = move_id.to_i
      @apply_counts[mid] = @apply_counts[mid].to_i + 1
      @success_counts[mid] = @success_counts[mid].to_i + 1 if success
    end

    def self.force_switch(user, target, move_id)
      mid = move_id.to_i
      reason = force_switch_block_reason(target, mid)
      if reason != nil
        mark_apply(mid, false)
        note_block_event(mid, target, reason)
        log("FORCE_SWITCH_BLOCK move=" + mid.to_s + " user=" +
            (user == nil ? "nil" : user.name.to_s) + " target=" +
            (target == nil ? "nil" : target.name.to_s) + " reason=" + reason.to_s)
        show_switch_text((target == nil ? "目標" : target.name.to_s) + "無法被強制換出。")
        return {:success=>false,:reason=>reason,:outgoing=>target,:incoming=>nil,
                :hazard=>{:damage=>0,:states=>[],:spe_delta=>0}}
      end

      candidates = reserve_candidates(target)
      if candidates.empty?
        mark_apply(mid, false)
        note_block_event(mid, target, :no_reserve)
        log("FORCE_SWITCH_FAIL move=" + mid.to_s + " user=" + user.name.to_s +
            " target=" + target.name.to_s + " reason=no_reserve")
        show_switch_text(target.name.to_s + "沒有可被強制換入的候補。")
        return {:success=>false,:reason=>:no_reserve,:outgoing=>target,:incoming=>nil,
                :hazard=>{:damage=>0,:states=>[],:spe_delta=>0}}
      end

      incoming = choose_reserve(target, candidates)
      return {:success=>false,:reason=>:no_reserve,:outgoing=>target,:incoming=>nil,
              :hazard=>{:damage=>0,:states=>[],:spe_delta=>0}} if incoming == nil

      row = target.respond_to?(:cg_battle_row) ? target.cg_battle_row : :front
      col = target.respond_to?(:cg_battle_column) ? target.cg_battle_column.to_i : 1
      out_label = target.respond_to?(:cg_grid_label) ? target.cg_grid_label.to_s : "?"
      log("FORCE_SWITCH_OUT move=" + mid.to_s + " out=" + target.name.to_s +
          " index=" + target.index.to_s + " slot=" + out_label)

      clear_switch_out_volatile(target)
      target.escape if target.respond_to?(:escape)
      target.hidden = true if target.respond_to?(:hidden=)
      target.action.clear if target.respond_to?(:action) && target.action != nil

      incoming.hidden = false if incoming.respond_to?(:hidden=)
      incoming.cg_set_battle_slot(row, col, true) if incoming.respond_to?(:cg_set_battle_slot)
      incoming.action.clear if incoming.respond_to?(:action) && incoming.action != nil
      incoming.reset_coordinate if incoming.respond_to?(:reset_coordinate)
      incoming.base_position if incoming.respond_to?(:base_position)
      incoming.instance_variable_set(:@collapse, false)

      hazard = {:damage=>0,:states=>[],:spe_delta=>0}
      if defined?(ALBERT_CG::FIELD_V233)
        hazard = ALBERT_CG::FIELD_V233.apply_entry_hazards(incoming)
      end
      show_hazard_popup(incoming, hazard)
      mark_apply(mid, true)
      note_switch_event(mid, user, target, incoming, hazard)
      log("FORCE_SWITCH_IN move=" + mid.to_s + " in=" + incoming.name.to_s +
          " index=" + incoming.index.to_s + " slot=" +
          (incoming.respond_to?(:cg_grid_label) ? incoming.cg_grid_label.to_s : "?") +
          " hazard_damage=" + hazard[:damage].to_i.to_s +
          " states=" + hazard[:states].inspect + " spe_delta=" + hazard[:spe_delta].to_i.to_s)
      log("FORCE_SWITCH_SUCCESS move=" + mid.to_s + " user=" + user.name.to_s +
          " out=" + target.name.to_s + " in=" + incoming.name.to_s)
      show_switch_text(target.name.to_s + "被強制換出，" + incoming.name.to_s + "進入戰場。")
      return {:success=>true,:reason=>nil,:outgoing=>target,:incoming=>incoming,:hazard=>hazard}
    end

    def self.handled?(move_id)
      return HANDLED_MOVE_IDS.include?(move_id.to_i)
    end

    def self.test_allies
      return $game_party == nil ? [] : $game_party.members[0,4]
    end

    def self.all_enemies
      return $game_troop == nil ? [] : $game_troop.members
    end

    def self.current_troop_id
      return -1 if $game_troop == nil
      return $game_troop.troop_id.to_i if $game_troop.respond_to?(:troop_id)
      return $game_troop.instance_variable_get(:@troop_id).to_i
    rescue
      return -1
    end

    def self.configure_actor(cfg)
      return if master == nil
      actor = $game_actors[master.actor_id_for_dex(cfg[:dex])]
      return if actor == nil
      master.configure_actor(actor, cfg)
      actor.cg_v234_clear_battle_memory if actor.respond_to?(:cg_v234_clear_battle_memory)
      actor.cg_reset_stat_stages if actor.respond_to?(:cg_reset_stat_stages)
    end

    def self.configure_enemy(cfg)
      master.configure_enemy_data(cfg) if master != nil
    end

    def self.prepare_test_party
      ids = TEST_ALLIES.collect { |cfg| master.actor_id_for_dex(cfg[:dex]) }
      if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
        ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids)
      end
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized, true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each { |cfg| configure_actor(cfg) }
      human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if human != nil
        human.change_level(TEST_LEVEL, false)
        human.recover_all if human.respond_to?(:recover_all)
      end
    end

    def self.make_test_troop
      master.ensure_index($data_troops, TEST_TROOP_ID)
      xs = [ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_BACK_X,  ALBERT_CG::ENEMY_BACK_X,
            ALBERT_CG::ENEMY_BACK_X,  ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[2],
            ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[2],
            ALBERT_CG::GRID_COLUMN_Y[1], ALBERT_CG::GRID_COLUMN_Y[1]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg, i|
        configure_enemy(cfg)
        m = ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]), xs[i], ys[i])
        m.hidden = (i >= 4)
        members.push(m)
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(
        TEST_TROOP_ID, "Pokemon ForceSwitch v2.3.5a AutoRegression", members)
    end

    def self.make_action(battler, cfg)
      action = Game_BattleAction.new(battler)
      if cfg[:kind] == :attack
        action.set_attack
      elsif cfg[:kind] == :move
        action.set_skill(master.skill_id_for_move(cfg[:move_id].to_i))
      else
        action.clear
      end
      action.target_index = cfg[:target].to_i if cfg.has_key?(:target)
      return action
    end

    def self.forced_enemy_action(enemy)
      return nil unless active? && enemy != nil
      # 所有目前可見敵方都固定使用 Splash，避免傷害干擾換入驗證。
      return make_action(enemy, {:kind=>:move,:move_id=>150,:target=>enemy.index})
    end

    def self.apply_test_speeds
      key = ("r" + current_round.to_s).to_sym
      vals = TEST_SPEEDS[key] || []
      list = test_allies + all_enemies
      list.each_with_index do |b, i|
        b.instance_variable_set(:@cg_priority_test_speed_override, vals[i]) if b != nil
      end
    end

    def self.record_execution(battler)
      return unless active? && battler != nil
      @actual = [] if @actual == nil
      token = battler.actor? ? "A" + battler.index.to_s : "E" + battler.index.to_s
      if battler.action != nil && battler.action.skill?
        mid = ALBERT_CG::MOVE_EFFECT.move_id(battler.action.skill)
        token += ":M" + mid.to_s
      elsif battler.action != nil && battler.action.attack?
        token += ":Attack"
      else
        token += ":Other"
      end
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + battler.name.to_s + " token=" + token)
    end

    def self.prepare_round_preconditions
      enemies = all_enemies
      if current_round == 1
        # 強制換出必須清能力階級：先故意給 E0 +2 ATK。
        enemies[0].cg_change_stat_stage(:atk, 2) if enemies[0] != nil && enemies[0].respond_to?(:cg_change_stat_stage)
        @r1_out_slot = enemies[0] == nil ? nil : [enemies[0].cg_battle_row, enemies[0].cg_battle_column]
        @r1_in_hp = enemies[4] == nil ? 0 : enemies[4].hp.to_i
      elsif current_round == 2
        @r2_out_slot = enemies[1] == nil ? nil : [enemies[1].cg_battle_row, enemies[1].cg_battle_column]
        @r2_in_hp = enemies[5] == nil ? 0 : enemies[5].hp.to_i
      end
    end

    def self.prepare_round_actions
      plan = current_plan
      return false if plan == nil
      apply_test_speeds
      prepare_round_preconditions
      @actual = []
      log("ROUND " + current_round.to_s + " BEGIN " + plan[:name].to_s)
      allies = test_allies
      plan[:allies].each_with_index do |cfg, i|
        b = allies[i]
        next if b == nil
        a = make_action(b, cfg)
        if b.respond_to?(:cg_round_actions)
          b.cg_round_actions.clear
          b.cg_round_actions.push(a)
        end
        b.cg_assign_action(a) if b.respond_to?(:cg_assign_action)
        b.instance_variable_set(:@action, a) unless b.respond_to?(:cg_assign_action)
      end
      # 敵方由 Game_Enemy#make_action wrapper 強制 Splash。
      return true
    end

    def self.assert_true(label, condition, detail=nil)
      @failures = [] if @failures == nil
      if condition
        log("ASSERT PASS " + label.to_s + (detail == nil ? "" : " " + detail.to_s))
        return true
      else
        text = label.to_s + (detail == nil ? "" : " " + detail.to_s)
        @failures.push(text)
        log("ASSERT FAIL " + text)
        return false
      end
    end

    def self.assert_bootstrap_once
      return if @boot_asserted == true
      @boot_asserted = true
      allies = test_allies
      enemies = all_enemies
      assert_true("Scene_Battle uses ForceSwitch test troop", current_troop_id == TEST_TROOP_ID,
                  "actual=" + current_troop_id.to_s)
      assert_true("ForceSwitch ally count=4", allies.size == 4, "actual=" + allies.size.to_s)
      assert_true("ForceSwitch troop member count=6", enemies.size == 6, "actual=" + enemies.size.to_s)
      visible = enemies.select { |b| b != nil && b.exist? }
      hidden = enemies.select { |b| b != nil && b.hidden && b.hp.to_i > 0 }
      assert_true("ForceSwitch starts with 4 active enemies", visible.size == 4, "actual=" + visible.size.to_s)
      assert_true("ForceSwitch starts with 2 hidden reserves", hidden.size == 2, "actual=" + hidden.size.to_s)
      # v2.3.5a：先驗證敵方 Ability Bridge，避免 Round3 到最後才知道吸盤根本沒被讀到。
      e2_ability = enemies[2] == nil ? 0 : ability_id(enemies[2])
      assert_true("Enemy E2 Suction Cups ability resolves", e2_ability == SUCTION_CUPS_ABILITY_ID,
                  "actual=" + e2_ability.to_s)
      assert_true("Roar priority is -6",
                  ALBERT_CG::ACTION_PRIORITY.priority_for_move(MOVE_ROAR).to_i == -6,
                  "actual=" + ALBERT_CG::ACTION_PRIORITY.priority_for_move(MOVE_ROAR).to_i.to_s) if
        defined?(ALBERT_CG::ACTION_PRIORITY) && ALBERT_CG::ACTION_PRIORITY.respond_to?(:priority_for_move)
      assert_true("Whirlwind priority is -6",
                  ALBERT_CG::ACTION_PRIORITY.priority_for_move(MOVE_WHIRLWIND).to_i == -6,
                  "actual=" + ALBERT_CG::ACTION_PRIORITY.priority_for_move(MOVE_WHIRLWIND).to_i.to_s) if
        defined?(ALBERT_CG::ACTION_PRIORITY) && ALBERT_CG::ACTION_PRIORITY.respond_to?(:priority_for_move)
    end

    def self.finish_round_assertions
      return unless active?
      r = current_round
      enemies = all_enemies
      event = @switch_events == nil ? nil : @switch_events[r]
      block = @block_events == nil ? nil : @block_events[r]
      expected_tokens = EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round" + r.to_s + " executes exactly 8 scripted battler actions",
                  @actual != nil && @actual.size == 8,
                  "actual=" + (@actual == nil ? "nil" : @actual.size.to_s))
      assert_true("Round" + r.to_s + " execution order matches deterministic plan",
                  @actual == expected_tokens,
                  "expected=" + expected_tokens.inspect + " actual=" + (@actual == nil ? "nil" : @actual.inspect))
      if r == 1
        assert_true("Roar really force-switches E0 to hidden reserve E4",
                    event != nil && event[:move_id].to_i == MOVE_ROAR &&
                    event[:outgoing] == enemies[0] && event[:incoming] == enemies[4])
        assert_true("Round1 outgoing is hidden and incoming is visible",
                    enemies[0] != nil && enemies[0].hidden && enemies[4] != nil && !enemies[4].hidden)
        assert_true("Round1 replacement inherits exact Grid slot",
                    enemies[4] != nil && @r1_out_slot == [enemies[4].cg_battle_row, enemies[4].cg_battle_column],
                    "expected=" + @r1_out_slot.inspect + " actual=" +
                    (enemies[4] == nil ? "nil" : [enemies[4].cg_battle_row,enemies[4].cg_battle_column].inspect))
        assert_true("Force switch clears outgoing stat stages",
                    enemies[0] != nil && enemies[0].cg_stat_stage(:atk).to_i == 0,
                    "atk_stage=" + (enemies[0] == nil ? "nil" : enemies[0].cg_stat_stage(:atk).to_s))
        assert_true("Spikes + Stealth Rock damage real replacement on entry",
                    event != nil && event[:hazard][:damage].to_i > 0 && enemies[4].hp.to_i < @r1_in_hp.to_i,
                    "damage=" + (event == nil ? "nil" : event[:hazard][:damage].to_i.to_s))
      elsif r == 2
        assert_true("Whirlwind really force-switches E1 to hidden reserve E5",
                    event != nil && event[:move_id].to_i == MOVE_WHIRLWIND &&
                    event[:outgoing] == enemies[1] && event[:incoming] == enemies[5])
        assert_true("Round2 replacement inherits exact Grid slot",
                    enemies[5] != nil && @r2_out_slot == [enemies[5].cg_battle_row, enemies[5].cg_battle_column])
        poison_ids = []
        if defined?(ALBERT_CG::MOVE_EFFECT)
          poison_ids.push(ALBERT_CG::MOVE_EFFECT::STATE_POISON) if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_POISON)
          poison_ids.push(ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON) if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON)
        end
        poisoned = enemies[5] != nil && poison_ids.any? { |sid| enemies[5].state?(sid) }
        assert_true("Toxic Spikes poisons real replacement", poisoned)
        assert_true("Sticky Web lowers replacement SPE stage",
                    event != nil && event[:hazard][:spe_delta].to_i == -1 &&
                    enemies[5] != nil && enemies[5].cg_stat_stage(:spe).to_i == -1,
                    "spe_stage=" + (enemies[5] == nil ? "nil" : enemies[5].cg_stat_stage(:spe).to_s))
        assert_true("Persisted Spikes/Stealth Rock still damage second replacement",
                    event != nil && event[:hazard][:damage].to_i > 0 && enemies[5].hp.to_i < @r2_in_hp.to_i)
      elsif r == 3
        assert_true("Suction Cups blocks Roar",
                    block != nil && block[:move_id].to_i == MOVE_ROAR && block[:reason] == :suction_cups)
        assert_true("Suction Cups target stays active",
                    enemies[2] != nil && !enemies[2].hidden)
      elsif r == 4
        assert_true("Fairy Lock blocks Whirlwind",
                    block != nil && block[:move_id].to_i == MOVE_WHIRLWIND && block[:reason] == :fairy_lock)
        assert_true("Fairy Lock target stays active",
                    enemies[3] != nil && !enemies[3].hidden)
      end
      log("ROUND " + r.to_s + " END")
      @round_index = @round_index.to_i + 1
    end

    def self.finish_suite
      covered = HANDLED_MOVE_IDS.select { |mid| @success_counts != nil && @success_counts[mid].to_i > 0 }
      hazard_entries = 0
      if @switch_events != nil
        @switch_events.values.each do |e|
          hazard_entries += 1 if e != nil && e[:hazard] != nil &&
            (e[:hazard][:damage].to_i > 0 || !e[:hazard][:states].empty? || e[:hazard][:spe_delta].to_i != 0)
        end
      end
      assert_true("Both Force Switch moves succeeded at least once",
                  covered.sort == HANDLED_MOVE_IDS.sort, "covered=" + covered.inspect)
      assert_true("Two real Hazard entry events verified", hazard_entries == 2,
                  "actual=" + hazard_entries.to_s)
      log("------------------------------------------------------------")
      if @failures == nil || @failures.empty?
        log("RESULT=PASS")
        log("SUMMARY rounds=4 failures=0 force_switch_moves=2/2 hazard_entries=2")
      else
        log("RESULT=FAIL")
        log("SUMMARY rounds=4 failures=" + @failures.size.to_s +
            " force_switch_moves=" + covered.size.to_s + "/2 hazard_entries=" + hazard_entries.to_s)
        @failures.each_with_index { |x,i| log("FAILURE " + (i+1).to_s + " " + x.to_s) }
      end
      @active = false
    end

    def self.start_auto_test
      # 關閉前一版 suite active flag，避免 Scene_Battle alias 鏈同時控制同一場戰鬥。
      if defined?(ALBERT_CG::UNIQUE_B_V234)
        ALBERT_CG::UNIQUE_B_V234.instance_variable_set(:@active, false)
      end
      reset_log
      prepare_test_party
      make_test_troop
      @active = true
      @round_index = 0
      @failures = []
      @switch_events = {}
      @block_events = {}
      @apply_counts = {}
      @success_counts = {}
      @actual = []
      @boot_asserted = false
      log("AUTO_TEST_START troop=" + TEST_TROOP_ID.to_s)
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    end
  end
end

#==============================================================================
# ■ Game_Battler：Roar / Whirlwind Skill Effect
#==============================================================================
class Game_Battler
  alias cg_v235_force_switch_skill_effect skill_effect
  def skill_effect(user, skill)
    cg_v235_force_switch_skill_effect(user, skill)
    return if skill == nil || @skipped || @missed || @evaded
    mid = ALBERT_CG::MOVE_EFFECT.move_id(skill)
    if ALBERT_CG::FORCE_SWITCH_V235.handled?(mid)
      ALBERT_CG::FORCE_SWITCH_V235.force_switch(user, self, mid)
    end
  end
end

#==============================================================================
# ■ Game_Battler：ForceSwitch Regression deterministic SPE
#==============================================================================
class Game_Battler
  alias cg_v235_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    override = @cg_priority_test_speed_override
    if defined?(ALBERT_CG::FORCE_SWITCH_V235) &&
       ALBERT_CG::FORCE_SWITCH_V235.active? && override != nil
      return override.to_i
    end
    return cg_v235_priority_base_speed
  end
end

#==============================================================================
# ■ Game_Enemy：ForceSwitch Regression 全敵固定 Splash
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v235_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::FORCE_SWITCH_V235) && ALBERT_CG::FORCE_SWITCH_V235.active?
      forced = ALBERT_CG::FORCE_SWITCH_V235.forced_enemy_action(self)
      if forced != nil
        cg_assign_action(forced) if respond_to?(:cg_assign_action)
        @action = forced unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v235_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle：Regression 行動記錄、回合推進、F11 suite 生命周期
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v235_execute_action execute_action
  def execute_action
    ALBERT_CG::FORCE_SWITCH_V235.record_execution(@active_battler) if
      defined?(ALBERT_CG::FORCE_SWITCH_V235) && ALBERT_CG::FORCE_SWITCH_V235.active?
    cg_v235_execute_action
  end

  alias cg_v235_turn_end turn_end
  def turn_end
    ALBERT_CG::FORCE_SWITCH_V235.finish_round_assertions if
      defined?(ALBERT_CG::FORCE_SWITCH_V235) && ALBERT_CG::FORCE_SWITCH_V235.active?
    cg_v235_turn_end
  end

  alias cg_v235_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::FORCE_SWITCH_V235) && ALBERT_CG::FORCE_SWITCH_V235.active?
      return cg_v235_start_party_command
    end
    cg_v235_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::FORCE_SWITCH_V235.assert_bootstrap_once
    if ALBERT_CG::FORCE_SWITCH_V235.finished?
      ALBERT_CG::FORCE_SWITCH_V235.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::FORCE_SWITCH_V235.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Regression 進 Scene_Battle 時重套測試 Actor 資料
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v235_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v235_bootstrap_demo_party
      if defined?(ALBERT_CG::FORCE_SWITCH_V235) && ALBERT_CG::FORCE_SWITCH_V235.active?
        ALBERT_CG::FORCE_SWITCH_V235::TEST_ALLIES.each do |cfg|
          ALBERT_CG::FORCE_SWITCH_V235.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::FORCE_SWITCH_V235::TEST_LEVEL, false)
          human.recover_all if human.respond_to?(:recover_all)
        end
      end
      return result
    end
  end
end

#==============================================================================
# ■ F11：v2.3.5 成為唯一最新版 AutoRegression
#==============================================================================
module ALBERT_CG
  module UNIQUE_B_V234
    def self.f11_trigger?
      return false
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v235_scene_map_update update
  def update
    cg_v235_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::FORCE_SWITCH_V235.f11_trigger?
      Sound.play_decision
      ALBERT_CG::FORCE_SWITCH_V235.start_auto_test
    end
  end
end

#==============================================================================
# ■ v2.3.4 Dynamic Call：Force Switch 已完成後解除 category 12 排除
#==============================================================================
module ALBERT_CG
  module UNIQUE_B_V234
    def self.callable_move?(move_id)
      mid = move_id.to_i
      return false if mid <= 0 || CALL_BLACKLIST.include?(mid)
      return false if master == nil || master.move(mid) == nil
      return true
    rescue
      return false
    end
  end
end

#==============================================================================
# ■ Coverage：最後 2 個 PENDING_FORCE_SWITCH 正式歸零
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    class << self
      alias cg_v235_coverage_v231 coverage_v231
    end
    def self.coverage_v231(move_id)
      return "V235_FORCE_SWITCH_HANDLED" if ALBERT_CG::FORCE_SWITCH_V235.handled?(move_id)
      return cg_v235_coverage_v231(move_id)
    end
  end
end
