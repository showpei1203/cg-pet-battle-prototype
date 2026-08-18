# RMVX_SCRIPT_INDEX: 202
# RMVX_SCRIPT_ID: 2390001
# RMVX_SCRIPT_NAME: CG Pokemon Unique Move Batch F v2.3.9a
# RMVX_SOURCE_SHA256: e223592b261eda44e7f887dd27c17c7f56bbf4ce477ab9311b6f4da89a3ae79e

#==============================================================================
# ■ CG Pokemon Unique Move Batch F v2.3.9a
#------------------------------------------------------------------------------
# 【用途】
#  接續 v2.3.8a 已完成的 Battle Base / Final Stat Getter Bridge，正式處理 6 個
#  「反應式防禦／當回合反制／持續能力下降」Unique Move：
#    588 King's Shield／王者盾牌
#    596 Spiky Shield／尖刺防守
#    600 Powder／粉塵
#    661 Baneful Bunker／碉堡
#    792 Obstruct／攔堵
#    903 Syrup Bomb／糖漿炸彈（MasterData 原 zh_name 尚未翻譯）
#
# 【核心設計】
#  1. 四種 Shield 不重做第二套 Protect。統一接入既有 v2.3.2b Protect Action
#     Dedup interception，避免 Tankentai 同一 Action 重入 skill_effect 時重複反制。
#  2. Shield 的「擋招」與「接觸反制」分層：
#       - 先由既有 Protect Layer 決定該 Action 是否真的被擋。
#       - 只有 distinct Action 第一次被擋且判定為接觸時，才觸發 Move-specific 反制。
#  3. 目前專案尚未有完整 Move Contact Flag 表，本版以：
#       普通攻擊 = 接觸
#       PMD move_motion_hint == :melee_attack = 接觸
#     作為正式暫行判定。未來若 MasterData 加入 contact flag，只需替換 contact_action?。
#  4. Powder 是「本回合標記」。目標若在標記期間嘗試使用 Fire-type Skill，該 Action
#     在 Scene_Battle 真正執行前被取消，並受到最大 HP 1/4 傷害。Grass-type 與
#     Overcoat(142) 目前免疫；本專案無持有道具，因此不處理 Safety Goggles。
#  5. Syrup Bomb 的原始資料帶 SPE -1 stat_change，但真正語意是連續 3 個回合末降速。
#     因此本版攔掉 Generic「命中瞬間 -1」，改為建立 3-turn syrup marker；每次回合末
#     SPE -1，最多三次。換出／戰鬥結束清除。
#
# 【Move-specific 規則】
#  King's Shield：啟用本回合 Protect；接觸攻擊被擋時，攻擊者 ATK -1。
#  Spiky Shield ：啟用本回合 Protect；接觸攻擊被擋時，攻擊者失去 MaxHP 1/8。
#  Baneful Bunker：啟用本回合 Protect；接觸攻擊被擋時，攻擊者中毒。
#  Obstruct     ：啟用本回合 Protect；接觸攻擊被擋時，攻擊者 DEF -2。
#  Powder       ：Priority +1；Fire-type Action 觸發爆炸，Action 取消、使用者自傷 1/4 MaxHP。
#  Syrup Bomb   ：正常造成傷害；命中後建立 3-turn syrup，每回合末 SPE -1。
#
# 【與既有系統的關係】
#  - Protect / Priority / Action serial：沿用 v2.3.2b / v2.3.2c。
#  - Stage：沿用 v2.3.0 cg_change_stat_stage。
#  - Ability Runtime：Powder 的 Overcoat 判定優先讀 v2.3.7 effective Ability API。
#  - PMD Motion 2.0：本版只做 Move Logic，不改 Renderer / hitFrame / Rich LOOP。
#  - Battle LOG：只輸出本批實際驗證需要的 marker，不恢復歷史全流水帳。
#
# 【可調參數】
#  SPIKY_DAMAGE_DENOM = 8
#  POWDER_DAMAGE_DENOM = 4
#  SYRUP_TURNS = 3
#  OVERCOAT_ABILITY_ID = 142
#  TEST_TROOP_ID = 690
#  TEST_LEVEL = 40
#
# 【事件／腳本呼叫方式】
#  正常遊戲不需事件呼叫。Debug 可讀：
#    battler.cg_v239_shield_kind
#    battler.cg_v239_powdered?
#    battler.cg_v239_syrup_turns
#
# 【AutoRegression】
#  地圖畫面只按 F11，執行 4 回合真正 Scene_Battle：
#   R1：King's Shield / Spiky Shield / Baneful Bunker，各吃一次真正 Tackle。
#   R2：Obstruct 吃真正 Tackle；Powder 攔 Flamethrower；Syrup Bomb 命中並 tick -1 SPE。
#   R3：Powder 已清除，Flamethrower 真正造成傷害；Obstruct 已清除，Tackle 真正造成傷害；
#       Syrup Bomb 第二次回合末 tick，SPE 累計 -2。
#   R4：不再建立反制，Syrup Bomb 第三次回合末 tick，確認 marker 歸零。
#  v2.3.9a 修正 deterministic SPE bridge：TEST_SPEEDS 在 Unique F Regression 期間
#  會真正進入 Action Priority secondary SPE；正常遊戲完全不讀測試 override。
#  成功標準：
#    RESULT=PASS
#    SUMMARY rounds=4 failures=0 unique_f_moves=6/6 reactive_checks=8 residual_checks=5
#
# 【F11 政策】
#  F11 永遠只啟動目前最新版 AutoRegression；舊 Batch E 仍可 script-call，但鍵盤 F11
#  由本版接管。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonUniqueMoveBatchF"] = "2.3.9a"

module ALBERT_CG
  module UNIQUE_F_V239
    VERSION = "2.3.9a"
    MOVE_KINGS_SHIELD   = 588
    MOVE_SPIKY_SHIELD   = 596
    MOVE_POWDER         = 600
    MOVE_BANEFUL_BUNKER = 661
    MOVE_OBSTRUCT       = 792
    MOVE_SYRUP_BOMB     = 903
    HANDLED_MOVE_IDS = [MOVE_KINGS_SHIELD,MOVE_SPIKY_SHIELD,MOVE_POWDER,
                        MOVE_BANEFUL_BUNKER,MOVE_OBSTRUCT,MOVE_SYRUP_BOMB]

    SPIKY_DAMAGE_DENOM = 8
    POWDER_DAMAGE_DENOM = 4
    SYRUP_TURNS = 3
    OVERCOAT_ABILITY_ID = 142
    TEST_TROOP_ID = 690
    TEST_LEVEL = 40
    VK_F11 = 0x7A

    TEST_ALLIES = [
      {:dex=>25,:level=>40,:ability=>9,  :moves=>[588,792,150,150]},
      {:dex=>3, :level=>40,:ability=>65, :moves=>[596,600,150,150]},
      {:dex=>94,:level=>40,:ability=>130,:moves=>[661,903,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>68,:level=>40,:ability=>62,:moves=>[33,53,53,150]},
      {:dex=>6, :level=>40,:ability=>66,:moves=>[33,150,150,150]},
      {:dex=>9, :level=>40,:ability=>67,:moves=>[33,33,33,150]},
      {:dex=>65,:level=>40,:ability=>28,:moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"REACTIVE_SHIELDS_CONTACT",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>588,:target=>1},
          {:kind=>:move,:move_id=>596,:target=>2},
          {:kind=>:move,:move_id=>661,:target=>3},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>33,:target=>1},
          {:kind=>:move,:move_id=>33,:target=>2},
          {:kind=>:move,:move_id=>33,:target=>3},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
      {
        :name=>"OBSTRUCT_POWDER_SYRUP",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>792,:target=>1},
          {:kind=>:move,:move_id=>600,:target=>0},
          {:kind=>:move,:move_id=>903,:target=>1},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>53,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>33,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
      {
        :name=>"ROUND_FLAG_CLEAR_AND_SYRUP_TICK",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>3},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>53,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>33,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
      {
        :name=>"SYRUP_FINAL_TICK_AND_CLEAR",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>3},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
    ]
    TEST_SPEEDS = {
      :r1=>[140,130,120,110,80,70,60,50],
      :r2=>[140,130,120,110,90,80,70,60],
      :r3=>[140,130,120,110,90,80,70,60],
      :r4=>[140,130,120,110,90,80,70,60],
    }
    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M588","A2:M596","A3:M661","E0:M33","E1:M33","E2:M33","E3:M150"],
      2=>["A0:Guard","A1:M792","A2:M600","A3:M903","E0:M53","E1:M150","E2:M33","E3:M150"],
      3=>["A0:Guard","A1:M150","A2:M150","A3:M150","E0:M53","E1:M150","E2:M33","E3:M150"],
      4=>["A0:Guard","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
    }

    begin
      KEY_API = Win32API.new("user32", "GetAsyncKeyState", "i", "i")
    rescue
      KEY_API = nil
    end

    def self.master; return defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.active?; return @active == true; end
    def self.handled?(mid); return HANDLED_MOVE_IDS.include?(mid.to_i); end
    def self.current_round; return @round_index.to_i + 1; end
    def self.current_plan; return ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; return @round_index.to_i >= ROUND_PLANS.size; end
    def self.project_root
      if defined?(ALBERT_CG::UNIQUE_B_V234) && ALBERT_CG::UNIQUE_B_V234.respond_to?(:project_root)
        return ALBERT_CG::UNIQUE_B_V234.project_root
      end
      return Dir.pwd
    rescue
      return Dir.pwd
    end
    def self.log_path; return File.join(project_root,"Pokemon_UniqueF_AutoTest_v2_3_9a.log"); end
    def self.latest_log_path; return File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.trace_log_path; return File.join(project_root,"PMD_BattleInitTrace.log"); end
    def self.write_line(path,text,mode="ab")
      File.open(path,mode) { |f| f.write(text.to_s + "\r\n") }
      return true
    rescue
      return false
    end
    def self.important_line?(line)
      return true if line.index("AUTO_TEST_START") == 0 || line.index("ASSERT ") == 0
      return true if line.index("SHIELD_") == 0 || line.index("POWDER_") == 0 || line.index("SYRUP_") == 0
      return true if line.index("RESULT=") == 0 || line.index("SUMMARY ") == 0
      return false
    end
    def self.log(line)
      text=line.to_s
      write_line(log_path,text)
      write_line(latest_log_path,text)
      write_line(trace_log_path,"[UNIQUE_F_AUTOTEST] " + text) if important_line?(text)
    end
    def self.reset_log
      header=[
        "CG POKEMON UNIQUE MOVE F AUTO REGRESSION v2.3.9a",
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        "RULE=Actual Scene_Battle; 6 reactive defense/residual Unique Moves",
        "AUTOTEST_LOG_PATH=" + log_path.to_s,
        "AUTOTEST_LATEST_PATH=" + latest_log_path.to_s,
        "------------------------------------------------------------"
      ]
      [log_path,latest_log_path].each do |p|
        begin
          File.open(p,"wb") { |f| header.each { |x| f.write(x + "\r\n") } }
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
      down=key_down?(VK_F11)
      trigger=down && @f11_down != true
      @f11_down=down
      return trigger
    rescue
      return false
    end
    def self.show_text(text)
      scene=$scene
      if scene != nil && scene.respond_to?(:cg_show_special_action_text,true)
        scene.send(:cg_show_special_action_text,text.to_s)
      end
    rescue
    end
    def self.mark_apply(mid)
      @apply_counts={} if @apply_counts == nil
      @apply_counts[mid.to_i]=@apply_counts[mid.to_i].to_i+1
      log("APPLY move=" + mid.to_i.to_s + " count=" + @apply_counts[mid.to_i].to_s)
    end
    def self.effective_ability(b)
      return 0 if b == nil
      if defined?(ALBERT_CG::UNIQUE_D_V237) && ALBERT_CG::UNIQUE_D_V237.respond_to?(:effective_ability)
        return ALBERT_CG::UNIQUE_D_V237.effective_ability(b).to_i
      end
      return b.cg_master_ability_id.to_i if b.respond_to?(:cg_master_ability_id)
      return 0
    rescue
      return 0
    end
    def self.move_row(mid); return master == nil ? nil : master.move(mid.to_i); end
    def self.move_type(mid)
      row=move_row(mid); return row == nil ? :normal : row[2]
    end
    def self.contact_action?(attacker)
      return false if attacker == nil || attacker.action == nil
      return true if attacker.action.attack?
      return false unless attacker.action.skill?
      mid=ALBERT_CG::MOVE_EFFECT.move_id(attacker.action.skill)
      return false if mid <= 0 || master == nil
      return master.move_motion_hint(mid) == :melee_attack
    rescue
      return false
    end
    def self.activate_shield(user,kind,mid)
      return false if user == nil
      user.instance_variable_set(:@cg_protect_v231,true)
      if defined?(ALBERT_CG::MOVE_EFFECT) && ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_PROTECT)
        user.add_state(ALBERT_CG::MOVE_EFFECT::STATE_PROTECT)
      end
      user.instance_variable_set(:@cg_v239_reactive_shield,kind)
      mark_apply(mid)
      log("SHIELD_SET kind=" + kind.to_s + " user=" + user.name.to_s)
      show_text(user.name.to_s + "展開了防禦！")
      return true
    end
    def self.apply_reactive_shield(target,attacker)
      return false if target == nil || attacker == nil
      kind=target.instance_variable_get(:@cg_v239_reactive_shield)
      return false if kind == nil || !contact_action?(attacker)
      case kind
      when :kings_shield
        delta=attacker.respond_to?(:cg_change_stat_stage) ? attacker.cg_change_stat_stage(:atk,-1) : 0
        log("SHIELD_REACT kind=kings_shield target=" + target.name.to_s + " attacker=" + attacker.name.to_s + " atk_delta=" + delta.to_i.to_s + " atk_stage=" + (attacker.respond_to?(:cg_stat_stage) ? attacker.cg_stat_stage(:atk).to_s : "?") )
      when :spiky_shield
        dmg=[[attacker.maxhp.to_i / SPIKY_DAMAGE_DENOM,1].max,attacker.hp.to_i].min
        attacker.hp -= dmg
        attacker.hp_damage=dmg if attacker.respond_to?(:hp_damage=)
        log("SHIELD_REACT kind=spiky_shield target=" + target.name.to_s + " attacker=" + attacker.name.to_s + " damage=" + dmg.to_s)
      when :baneful_bunker
        sid=ALBERT_CG::MOVE_EFFECT::STATE_POISON
        unless attacker.state?(sid)
          attacker.add_state(sid)
          attacker.added_states.push(sid) if attacker.respond_to?(:added_states) && !attacker.added_states.include?(sid)
        end
        log("SHIELD_REACT kind=baneful_bunker target=" + target.name.to_s + " attacker=" + attacker.name.to_s + " poisoned=" + attacker.state?(sid).to_s)
      when :obstruct
        delta=attacker.respond_to?(:cg_change_stat_stage) ? attacker.cg_change_stat_stage(:def,-2) : 0
        log("SHIELD_REACT kind=obstruct target=" + target.name.to_s + " attacker=" + attacker.name.to_s + " def_delta=" + delta.to_i.to_s + " def_stage=" + (attacker.respond_to?(:cg_stat_stage) ? attacker.cg_stat_stage(:def).to_s : "?") )
      else
        return false
      end
      return true
    rescue => e
      log("SHIELD_REACT_ERROR " + e.class.to_s + ":" + e.message.to_s)
      return false
    end
    def self.powder_immune?(target)
      return true if target == nil
      if target.respond_to?(:cg_pokemon_types) && target.cg_pokemon_types.include?(:grass)
        return true
      end
      return true if effective_ability(target) == OVERCOAT_ABILITY_ID
      return false
    rescue
      return false
    end
    def self.apply_powder(user,target)
      return false if target == nil
      if powder_immune?(target)
        log("POWDER_FAIL target=" + target.name.to_s + " reason=immune")
        return false
      end
      target.instance_variable_set(:@cg_v239_powdered,true)
      target.instance_variable_set(:@cg_v239_powder_source,user)
      mark_apply(MOVE_POWDER)
      log("POWDER_SET user=" + (user==nil ? "nil" : user.name.to_s) + " target=" + target.name.to_s)
      show_text(target.name.to_s + "被粉塵包覆了！")
      return true
    end
    def self.powder_trigger?(battler)
      return false if battler == nil || battler.instance_variable_get(:@cg_v239_powdered) != true
      return false if battler.action == nil || !battler.action.skill?
      mid=ALBERT_CG::MOVE_EFFECT.move_id(battler.action.skill)
      return false if mid <= 0
      return move_type(mid) == :fire
    rescue
      return false
    end
    def self.trigger_powder(battler)
      return false unless powder_trigger?(battler)
      mid=ALBERT_CG::MOVE_EFFECT.move_id(battler.action.skill)
      dmg=[[battler.maxhp.to_i / POWDER_DAMAGE_DENOM,1].max,battler.hp.to_i].min
      battler.hp -= dmg
      battler.hp_damage=dmg if battler.respond_to?(:hp_damage=)
      battler.instance_variable_set(:@cg_v239_powdered,false)
      @powder_trigger_count=@powder_trigger_count.to_i+1
      log("POWDER_TRIGGER battler=" + battler.name.to_s + " move=" + mid.to_s + " damage=" + dmg.to_s + " hp=" + battler.hp.to_i.to_s)
      show_text(battler.name.to_s + "身上的粉塵爆炸了！")
      return true
    end
    def self.apply_syrup(user,target)
      return false if target == nil
      target.instance_variable_set(:@cg_v239_syrup_turns,SYRUP_TURNS)
      target.instance_variable_set(:@cg_v239_syrup_source,user)
      mark_apply(MOVE_SYRUP_BOMB)
      log("SYRUP_SET user=" + (user==nil ? "nil" : user.name.to_s) + " target=" + target.name.to_s + " turns=" + SYRUP_TURNS.to_s)
      return true
    end
    def self.tick_end_turn
      list=[]
      list.concat($game_party.members) if $game_party != nil
      list.concat($game_troop.members) if $game_troop != nil
      list.each do |b|
        next if b == nil
        turns=b.instance_variable_get(:@cg_v239_syrup_turns).to_i
        if turns > 0 && b.hp.to_i > 0
          delta=b.respond_to?(:cg_change_stat_stage) ? b.cg_change_stat_stage(:spe,-1) : 0
          turns -= 1
          b.instance_variable_set(:@cg_v239_syrup_turns,turns)
          @syrup_tick_count=@syrup_tick_count.to_i+1 if active?
          log("SYRUP_TICK target=" + b.name.to_s + " spe_delta=" + delta.to_i.to_s + " spe_stage=" + (b.respond_to?(:cg_stat_stage) ? b.cg_stat_stage(:spe).to_s : "?") + " turns_left=" + turns.to_s)
        end
      end
    end

    def self.install_skill_scopes
      return if master == nil || $data_skills == nil
      self_moves=[MOVE_KINGS_SHIELD,MOVE_SPIKY_SHIELD,MOVE_BANEFUL_BUNKER,MOVE_OBSTRUCT]
      HANDLED_MOVE_IDS.each do |mid|
        sid=master.skill_id_for_move(mid)
        next if sid.to_i <= 0 || $data_skills[sid] == nil
        $data_skills[sid].scope=self_moves.include?(mid) ? 11 : 1
      end
    rescue => e
      log("SCOPE_INSTALL_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
    end

    def self.test_allies; return $game_party == nil ? [] : $game_party.members[0,4]; end
    def self.test_enemies; return $game_troop == nil ? [] : $game_troop.members[0,4]; end
    def self.current_troop_id
      return -1 if $game_troop == nil
      return $game_troop.troop_id.to_i if $game_troop.respond_to?(:troop_id)
      return $game_troop.instance_variable_get(:@troop_id).to_i
    rescue
      return -1
    end
    def self.configure_actor(cfg)
      return if master == nil
      actor=$game_actors[master.actor_id_for_dex(cfg[:dex])]
      return if actor == nil
      master.configure_actor(actor,cfg)
      actor.cg_v237_clear_identity if actor.respond_to?(:cg_v237_clear_identity)
      actor.cg_v238_clear_runtime if actor.respond_to?(:cg_v238_clear_runtime)
      actor.cg_v239_clear_runtime if actor.respond_to?(:cg_v239_clear_runtime)
      actor.cg_reset_stat_stages if actor.respond_to?(:cg_reset_stat_stages)
      actor.recover_all if actor.respond_to?(:recover_all)
    end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg) if master != nil; end
    def self.prepare_test_party
      ids=TEST_ALLIES.collect { |cfg| master.actor_id_for_dex(cfg[:dex]) }
      ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each { |cfg| configure_actor(cfg) }
      human=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if human != nil
        human.change_level(TEST_LEVEL,false)
        human.recover_all if human.respond_to?(:recover_all)
        human.cg_v237_clear_identity if human.respond_to?(:cg_v237_clear_identity)
        human.cg_v238_clear_runtime if human.respond_to?(:cg_v238_clear_runtime)
        human.cg_v239_clear_runtime if human.respond_to?(:cg_v239_clear_runtime)
        human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
      end
      return true
    end
    def self.apply_test_grid
      allies=test_allies; enemies=test_enemies
      slots_a=[[:back,1],[:front,0],[:front,1],[:front,2]]
      slots_e=[[:front,0],[:front,1],[:front,2],[:back,1]]
      allies.each_with_index { |b,i| b.cg_set_battle_slot(slots_a[i][0],slots_a[i][1],true) if b != nil && b.respond_to?(:cg_set_battle_slot) }
      enemies.each_with_index { |b,i| b.cg_set_battle_slot(slots_e[i][0],slots_e[i][1],true) if b != nil && b.respond_to?(:cg_set_battle_slot) }
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[1]]
      members=[]
      TEST_ENEMIES.each_with_index do |cfg,i|
        configure_enemy(cfg)
        members.push(ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]),xs[i],ys[i]))
      end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon UniqueF v2.3.9a AutoRegression",members)
    end
    def self.make_action(battler,cfg)
      action=Game_BattleAction.new(battler)
      if cfg[:kind] == :attack
        action.set_attack
      elsif cfg[:kind] == :guard
        action.set_guard
      elsif cfg[:kind] == :move
        action.set_skill(master.skill_id_for_move(cfg[:move_id].to_i))
      else
        action.clear
      end
      action.target_index=cfg[:target].to_i if cfg.has_key?(:target)
      return action
    end
    def self.forced_enemy_action(enemy)
      return nil unless active? && enemy != nil
      cfg=current_plan == nil ? nil : current_plan[:enemies][enemy.index]
      return nil if cfg == nil
      return make_action(enemy,cfg)
    end
    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r" + current_round.to_s).to_sym] || []
      (test_allies+test_enemies).each_with_index { |b,i| b.instance_variable_set(:@cg_priority_test_speed_override,vals[i]) if b != nil }
    end
    def self.record_execution(battler)
      return unless active? && battler != nil
      @actual=[] if @actual == nil
      token=battler.actor? ? "A" + battler.index.to_s : "E" + battler.index.to_s
      if battler.action != nil && battler.action.skill?
        token += ":M" + ALBERT_CG::MOVE_EFFECT.move_id(battler.action.skill).to_s
      elsif battler.action != nil && battler.action.attack?
        token += ":Attack"
      elsif battler.action != nil && battler.action.guard?
        token += ":Guard"
      else
        token += ":Other"
      end
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + battler.name.to_s + " token=" + token)
    end
    def self.assign_action_to(b,action)
      return if b == nil
      if b.respond_to?(:cg_round_actions)
        b.cg_round_actions.clear; b.cg_round_actions.push(action)
      end
      b.cg_assign_action(action) if b.respond_to?(:cg_assign_action)
      b.instance_variable_set(:@action,action) unless b.respond_to?(:cg_assign_action)
    end
    def self.prepare_round_preconditions
      a=test_allies; e=test_enemies
      if current_round == 1
        (a+e).each do |b|
          next if b == nil
          b.cg_v239_clear_runtime if b.respond_to?(:cg_v239_clear_runtime)
          b.cg_reset_stat_stages if b.respond_to?(:cg_reset_stat_stages)
          b.recover_all if b.respond_to?(:recover_all)
        end
        @r1_hp_a=[a[1].hp.to_i,a[2].hp.to_i,a[3].hp.to_i]
        @r1_e1_hp=e[1].hp.to_i
      elsif current_round == 2
        @r2_a1_hp=a[1].hp.to_i
        @r2_a2_hp=a[2].hp.to_i
        @r2_e0_hp=e[0].hp.to_i
        @r2_e1_spe_stage_before=e[1].cg_stat_stage(:spe).to_i
      elsif current_round == 3
        @r3_a1_hp=a[1].hp.to_i
        @r3_a2_hp=a[2].hp.to_i
        @r3_e1_spe_stage_before=e[1].cg_stat_stage(:spe).to_i
        log("ROUND3_PRECHECK powder_e0=" + e[0].cg_v239_powdered?.to_s + " shield_a1=" + a[1].cg_v239_shield_kind.inspect + " syrup_e1=" + e[1].cg_v239_syrup_turns.to_s)
      elsif current_round == 4
        @r4_e1_spe_stage_before=e[1].cg_stat_stage(:spe).to_i
        log("ROUND4_PRECHECK syrup_e1=" + e[1].cg_v239_syrup_turns.to_s + " spe_stage=" + @r4_e1_spe_stage_before.to_s)
      end
    end
    def self.prepare_round_actions
      plan=current_plan
      return false if plan == nil
      apply_test_speeds
      prepare_round_preconditions
      @actual=[]
      log("ROUND " + current_round.to_s + " BEGIN " + plan[:name].to_s)
      allies=test_allies
      plan[:allies].each_with_index do |cfg,i|
        b=allies[i]; next if b == nil
        assign_action_to(b,make_action(b,cfg))
      end
      return true
    end
    def self.assert(condition,text)
      if condition
        log("ASSERT PASS " + text.to_s)
      else
        @failures=@failures.to_i+1
        @failure_lines=[] if @failure_lines == nil
        @failure_lines.push(text.to_s)
        log("ASSERT FAIL " + text.to_s)
      end
      return condition
    end
    def self.note_reactive(ok); @reactive_checks=@reactive_checks.to_i+1 if ok; return ok; end
    def self.note_residual(ok); @residual_checks=@residual_checks.to_i+1 if ok; return ok; end
    def self.finish_round_assertions
      round=current_round
      expected=EXPECTED_EXECUTION_TOKENS[round] || []
      actual=@actual || []
      assert(actual.size==8,"Round"+round.to_s+" executes exactly 8 scripted battler actions actual="+actual.size.to_s)
      assert(actual==expected,"Round"+round.to_s+" execution order matches deterministic plan expected="+expected.inspect+" actual="+actual.inspect)
      a=test_allies; e=test_enemies
      case round
      when 1
        ok=a[1].hp.to_i==@r1_hp_a[0]; note_reactive(ok); assert(ok,"King's Shield blocks contact Tackle damage")
        ok=e[0].cg_stat_stage(:atk).to_i==-1; note_reactive(ok); assert(ok,"King's Shield lowers contact attacker ATK -1")
        expected_loss=[@r1_e1_hp / SPIKY_DAMAGE_DENOM,1].max
        ok=a[2].hp.to_i==@r1_hp_a[1]; note_reactive(ok); assert(ok,"Spiky Shield blocks contact Tackle damage")
        ok=e[1].hp.to_i<=@r1_e1_hp-expected_loss; note_reactive(ok); assert(ok,"Spiky Shield retaliation damages contact attacker")
        ok=a[3].hp.to_i==@r1_hp_a[2]; note_reactive(ok); assert(ok,"Baneful Bunker blocks contact Tackle damage")
        ok=e[2].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON); note_reactive(ok); assert(ok,"Baneful Bunker poisons contact attacker")
      when 2
        ok=a[1].hp.to_i==@r2_a1_hp; note_reactive(ok); assert(ok,"Obstruct blocks contact Tackle damage")
        ok=e[2].cg_stat_stage(:def).to_i==-2; note_reactive(ok); assert(ok,"Obstruct lowers contact attacker DEF -2")
        ok=@powder_trigger_count.to_i==1 && e[0].hp.to_i < @r2_e0_hp && a[2].hp.to_i==@r2_a2_hp; note_residual(ok); assert(ok,"Powder cancels real Fire action, self-damages user, and protects original target")
        ok=e[1].cg_v239_syrup_turns.to_i==2 && e[1].cg_stat_stage(:spe).to_i==@r2_e1_spe_stage_before-1; note_residual(ok); assert(ok,"Syrup Bomb first end-turn tick lowers SPE -1 and leaves 2 turns")
      when 3
        ok=!e[0].cg_v239_powdered? && a[2].hp.to_i < @r3_a2_hp; note_residual(ok); assert(ok,"Powder round flag clears so next-round Flamethrower deals real damage")
        ok=a[1].cg_v239_shield_kind==nil && a[1].hp.to_i < @r3_a1_hp; assert(ok,"Obstruct round flag clears so next-round Tackle deals real damage")
        ok=e[1].cg_stat_stage(:spe).to_i==@r3_e1_spe_stage_before-1 && e[1].cg_v239_syrup_turns.to_i==1; note_residual(ok); assert(ok,"Syrup Bomb second end-turn tick lowers SPE again and leaves 1 turn")
      when 4
        ok=e[1].cg_stat_stage(:spe).to_i==@r4_e1_spe_stage_before-1 && e[1].cg_v239_syrup_turns.to_i==0
        note_residual(ok); assert(ok,"Syrup Bomb third end-turn tick lowers SPE once more and clears marker")
      end
      log("ROUND " + round.to_s + " END")
      @round_index=@round_index.to_i+1
    end
    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted=true
      install_skill_scopes; apply_test_grid
      assert(current_troop_id==TEST_TROOP_ID,"Scene_Battle uses Unique F test troop actual="+current_troop_id.to_s)
      assert(test_allies.size==4,"Unique F ally count=4 actual="+test_allies.size.to_s)
      assert(test_enemies.size==4,"Unique F enemy count=4 actual="+test_enemies.size.to_s)
      assert(test_allies.collect{|b| b.actor? ? b.id : 0}==[1,124,102,193],"Unique F exact ally roster")
      assert(test_enemies.collect{|b| b.enemy_id}==[667,605,608,664],"Unique F exact enemy roster")
    end
    def self.finish_suite
      missing=HANDLED_MOVE_IDS.select{|mid| @apply_counts[mid].to_i<=0}
      assert(missing.empty?,"All 6 Unique Batch F moves executed missing="+missing.inspect)
      log("------------------------------------------------------------")
      log(@failures.to_i<=0 ? "RESULT=PASS" : "RESULT=FAIL")
      log("SUMMARY rounds=4 failures="+@failures.to_i.to_s+" unique_f_moves="+(HANDLED_MOVE_IDS.size-missing.size).to_s+"/6 reactive_checks="+@reactive_checks.to_i.to_s+" residual_checks="+@residual_checks.to_i.to_s)
      if @failure_lines != nil
        @failure_lines.each_with_index{|x,i| log("FAILURE "+(i+1).to_s+" "+x.to_s)}
      end
      (test_allies+test_enemies).each do |b|
        b.instance_variable_set(:@cg_priority_test_speed_override,nil) if b != nil
      end
      @active=false
      return @failures.to_i<=0
    end
    def self.start_auto_test
      return false if active? || $game_temp.in_battle
      install_skill_scopes; prepare_test_party; make_test_troop
      reset_log
      @active=true; @round_index=0; @failures=0; @failure_lines=[]; @apply_counts={}
      @reactive_checks=0; @residual_checks=0; @powder_trigger_count=0; @syrup_tick_count=0; @boot_asserted=false
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s)
      if defined?(ALBERT_CG) && ALBERT_CG.respond_to?(:start_demo_battle)
        ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
      else
        $game_troop.setup(TEST_TROOP_ID); $game_temp.in_battle=true; $game_temp.battle_troop_id=TEST_TROOP_ID; $scene=Scene_Battle.new
      end
      return true
    rescue => e
      log("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s)
      @active=false
      return false
    end
  end
end

#==============================================================================
# ■ Game_Battler：v2.3.9a AutoRegression deterministic SPE Bridge
#------------------------------------------------------------------------------
# 【用途】
#  v2.3.9 實機發現 Unique F 已寫入 @cg_priority_test_speed_override，但 v2.3.2c
#  Priority Core 只在 ACTION_PRIORITY 自己的 Regression active 時才讀該值，導致
#  EXPECTED_EXECUTION_TOKENS 與真正排序來源不同。
# 【規則】
#  只有 Unique F AutoRegression active 且 override 存在時才使用測試 SPE。
#  正常遊戲、舊 Regression、正式能力值與 Priority 規則完全不受影響。
# 【可調參數】
#  速度值由 UNIQUE_F_V239::TEST_SPEEDS 統一設定。
# 【事件／腳本呼叫方式】
#  正常遊戲不需呼叫。Regression 由 apply_test_speeds 自動寫入 override。
# 【實際範例】
#    battler.cg_priority_base_speed   # 測試期間回傳指定 deterministic SPE
#==============================================================================
class Game_Battler
  alias cg_v239a_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::UNIQUE_F_V239) && ALBERT_CG::UNIQUE_F_V239.active?
      override=@cg_priority_test_speed_override
      return override.to_i if override != nil
    end
    return cg_v239a_priority_base_speed
  rescue
    return cg_v239a_priority_base_speed
  end
end

#==============================================================================
# ■ Game_Battler：Shield / Powder / Syrup Runtime
#==============================================================================
class Game_Battler
  def cg_v239_shield_kind; return @cg_v239_reactive_shield; end
  def cg_v239_powdered?; return @cg_v239_powdered == true; end
  def cg_v239_syrup_turns; return @cg_v239_syrup_turns.to_i; end
  def cg_v239_clear_runtime
    @cg_v239_reactive_shield=nil
    @cg_v239_powdered=false
    @cg_v239_powder_source=nil
    @cg_v239_syrup_turns=0
    @cg_v239_syrup_source=nil
  end

  alias cg_v239_clear_v231_round_flags cg_clear_v231_round_flags
  def cg_clear_v231_round_flags
    cg_v239_clear_v231_round_flags
    @cg_v239_reactive_shield=nil
    @cg_v239_powdered=false
    @cg_v239_powder_source=nil
  end

  alias cg_v239_remove_states_battle remove_states_battle
  def remove_states_battle
    cg_v239_remove_states_battle
    cg_v239_clear_runtime
  end

  # Syrup Bomb 不在命中瞬間吃 MasterData stat_change；由回合末 marker 處理。
  alias cg_v239_apply_stats cg_move_effect_apply_stats
  def cg_move_effect_apply_stats(user,move_id)
    return if move_id.to_i == ALBERT_CG::UNIQUE_F_V239::MOVE_SYRUP_BOMB
    cg_v239_apply_stats(user,move_id)
  end

  # 只在 Protect Dedup 判定「新的一個 distinct Action」後做接觸反制。
  alias cg_v239_apply_protect_block cg_apply_protect_block_v232b
  def cg_apply_protect_block_v232b(user,label)
    before=cg_protect_action_block_count_v232b
    result=cg_v239_apply_protect_block(user,label)
    after=cg_protect_action_block_count_v232b
    if after.to_i > before.to_i
      ALBERT_CG::UNIQUE_F_V239.apply_reactive_shield(self,user)
    end
    return result
  end

  alias cg_v239_skill_effect skill_effect
  def skill_effect(user,skill)
    mid=ALBERT_CG::MOVE_EFFECT.move_id(skill)
    case mid
    when ALBERT_CG::UNIQUE_F_V239::MOVE_KINGS_SHIELD
      clear_action_results
      ALBERT_CG::UNIQUE_F_V239.activate_shield(user,:kings_shield,mid)
      return
    when ALBERT_CG::UNIQUE_F_V239::MOVE_SPIKY_SHIELD
      clear_action_results
      ALBERT_CG::UNIQUE_F_V239.activate_shield(user,:spiky_shield,mid)
      return
    when ALBERT_CG::UNIQUE_F_V239::MOVE_BANEFUL_BUNKER
      clear_action_results
      ALBERT_CG::UNIQUE_F_V239.activate_shield(user,:baneful_bunker,mid)
      return
    when ALBERT_CG::UNIQUE_F_V239::MOVE_OBSTRUCT
      clear_action_results
      ALBERT_CG::UNIQUE_F_V239.activate_shield(user,:obstruct,mid)
      return
    when ALBERT_CG::UNIQUE_F_V239::MOVE_POWDER
      clear_action_results
      ALBERT_CG::UNIQUE_F_V239.apply_powder(user,self)
      return
    end

    cg_v239_skill_effect(user,skill)
    return if mid <= 0 || @skipped || @missed || @evaded
    if mid == ALBERT_CG::UNIQUE_F_V239::MOVE_SYRUP_BOMB
      ALBERT_CG::UNIQUE_F_V239.apply_syrup(user,self)
    end
  end
end

#==============================================================================
# ■ Game_Enemy：Regression deterministic action
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v239_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::UNIQUE_F_V239) && ALBERT_CG::UNIQUE_F_V239.active?
      forced=ALBERT_CG::UNIQUE_F_V239.forced_enemy_action(self)
      if forced != nil
        cg_assign_action(forced) if respond_to?(:cg_assign_action)
        @action=forced unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v239_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle：Powder execution intercept + 3-round Regression
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v239_execute_action execute_action
  def execute_action
    ALBERT_CG::UNIQUE_F_V239.record_execution(@active_battler) if defined?(ALBERT_CG::UNIQUE_F_V239) && ALBERT_CG::UNIQUE_F_V239.active?
    if defined?(ALBERT_CG::UNIQUE_F_V239) && ALBERT_CG::UNIQUE_F_V239.powder_trigger?(@active_battler)
      ALBERT_CG::UNIQUE_F_V239.trigger_powder(@active_battler)
      return
    end
    cg_v239_execute_action
  end

  alias cg_v239_turn_end turn_end
  def turn_end
    ALBERT_CG::UNIQUE_F_V239.tick_end_turn if defined?(ALBERT_CG::UNIQUE_F_V239)
    ALBERT_CG::UNIQUE_F_V239.finish_round_assertions if defined?(ALBERT_CG::UNIQUE_F_V239) && ALBERT_CG::UNIQUE_F_V239.active?
    cg_v239_turn_end
  end

  alias cg_v239_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::UNIQUE_F_V239) && ALBERT_CG::UNIQUE_F_V239.active?
      return cg_v239_start_party_command
    end
    cg_v239_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::UNIQUE_F_V239.assert_bootstrap_once
    if ALBERT_CG::UNIQUE_F_V239.finished?
      ALBERT_CG::UNIQUE_F_V239.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::UNIQUE_F_V239.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle 重建 Party 後重套 Batch F 測試資料
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v239_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result=cg_v239_bootstrap_demo_party
      if defined?(ALBERT_CG::UNIQUE_F_V239) && ALBERT_CG::UNIQUE_F_V239.active?
        ALBERT_CG::UNIQUE_F_V239::TEST_ALLIES.each { |cfg| ALBERT_CG::UNIQUE_F_V239.configure_actor(cfg) }
        human=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::UNIQUE_F_V239::TEST_LEVEL,false)
          human.recover_all if human.respond_to?(:recover_all)
          human.cg_v239_clear_runtime if human.respond_to?(:cg_v239_clear_runtime)
          human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
        end
        ALBERT_CG::UNIQUE_F_V239.install_skill_scopes
      end
      return result
    end
  end
end

#==============================================================================
# ■ Scene_Title：Move Stub 建立後校正 Unique F Scope
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_v239_load_database load_database
  def load_database
    cg_v239_load_database
    ALBERT_CG::UNIQUE_F_V239.install_skill_scopes
  end
  alias cg_v239_load_bt_database load_bt_database
  def load_bt_database
    cg_v239_load_bt_database
    ALBERT_CG::UNIQUE_F_V239.install_skill_scopes
  end
end

#==============================================================================
# ■ F11：v2.3.9a 成為唯一最新版 AutoRegression
#==============================================================================
if defined?(ALBERT_CG::UNIQUE_E_V238)
  module ALBERT_CG
    module UNIQUE_E_V238
      def self.f11_trigger?; return false; end
    end
  end
end
class Scene_Map < Scene_Base
  alias cg_v239_scene_map_update update
  def update
    cg_v239_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::UNIQUE_F_V239.f11_trigger?
      Sound.play_decision
      ALBERT_CG::UNIQUE_F_V239.start_auto_test
    end
  end
end

#==============================================================================
# ■ Coverage：6 個 Unique Pending 轉為 V239_UNIQUE_F_HANDLED
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    class << self
      alias cg_v239_coverage_v231 coverage_v231
      def coverage_v231(move_id)
        return "V239_UNIQUE_F_HANDLED" if ALBERT_CG::UNIQUE_F_V239.handled?(move_id)
        return cg_v239_coverage_v231(move_id)
      end
    end
  end
end
