# RMVX_SCRIPT_INDEX: 203
# RMVX_SCRIPT_ID: 1153467381
# RMVX_SCRIPT_NAME: CG Pokemon Unique Move Batch G v2.4.0a
# RMVX_SOURCE_SHA256: 12af1c9e7baed0e6ab23e408344cac2002db8b36fef221b51f913acf322cff0a

#==============================================================================
# ■ CG Pokemon Unique Move Batch G v2.4.0a
#------------------------------------------------------------------------------
# 【用途】
#  接續 v2.3.9a 已封版的 Reactive Defense / Residual Core，處理 7 個彼此共享
#  「Move Memory／動態呼叫／持續限制／延遲攻擊」底層的 Unique Move：
#    119 Mirror Move／鸚鵡學舌
#    174 Curse／詛咒
#    254 Stockpile／蓄力
#    267 Nature Power／自然之力
#    274 Assist／借助
#    286 Imprison／封印
#    353 Doom Desire／破滅之願
#
# 【v2.4.0a Runtime 修正】
#  Windows RGSS2 實機已證明 7/7 Move 與五回合核心全部 PASS，但 finish_suite 在
#  輸出 SUMMARY 時使用 Array#count { ... }。RPG Maker VX 的舊 Ruby 不支援該
#  block 形式，造成 NoMethodError 並使 cleanup_test_overrides / @active=false 無法執行。
#  本版改用 RGSS2 相容的 each 累加計數，並以 ensure 保證 AutoRegression finalizer
#  無論 SUMMARY/FAILURE LOG 是否再出現意外，都一定清除測試速度與 forced-call override。
#
# 【主要設定項】
#  TEST_TROOP_ID = 689
#  TEST_LEVEL = 40
#  CURSE_HP_DENOM = 2             Ghost Curse 使用者消耗 MaxHP 1/2
#  CURSE_TICK_DENOM = 4           被詛咒者每回合末失去 MaxHP 1/4
#  STOCKPILE_MAX = 3              蓄力最多三層
#  DOOM_DELAY_ENDS = 3            使用回合末也會計一次，第三次 turn_end 結算
#
# 【機制規則】
#  1. Mirror Move：讀取「指定目標最近真正執行的 Move」並在本 Action 執行前替換為
#     該 Move。沿用 v2.3.4g 的 last_move memory 與 replace_action_with_move，不另造
#     第二套動態技能執行器。
#  2. Nature Power：依目前 Terrain 呼叫真正 Move：
#       Electric -> Thunderbolt(85)
#       Grassy   -> Energy Ball(412)
#       Misty    -> Moonblast(585)
#       Psychic  -> Psychic(94)
#       無 Terrain -> Tri Attack(161)
#     呼叫後由原技能自己的傷害、動畫、PMD motion 與 Type Core 處理。
#  3. Assist：從同側其他存活寶可夢的已知 Move 中隨機挑一個可呼叫 Move；
#     AutoRegression 可用 @cg_v240_forced_called_move_id 固定結果。呼叫系招式與容易
#     遞迴的 Move 會被 blacklist 排除。
#  4. Curse：
#       - Ghost 使用者：自己失去 MaxHP 1/2，目標進入 Curse marker，每回合末失去
#         MaxHP 1/4；目標離場／戰鬥結束會清除；來源離場不解除既有 Curse。
#       - 非 Ghost 使用者：ATK +1、DEF +1、SPE -1。
#  5. Stockpile：最多 3 層；每成功增加一層，同時 DEF +1、SpD +1。第 4 次不再增加。
#     本版先完成 Stockpile 本體；Spit Up / Swallow 的消耗層數語意留到後續 Consumer
#     Integration，不把尚未驗證的相依行為假裝成已完成。
#  6. Imprison：使用者存活且 marker 有效時，對手若準備使用「使用者目前也會的 Move」，
#     在 Scene_Battle 真正執行層阻止該 Action。這是 Runtime authority；未來 Gamebit/UI
#     可直接讀 cg_v240_imprisoned_move? 做選招前預判。
#  7. Doom Desire：沿用 Future Sight 的「位置式延遲命中」理念，但使用獨立 queue。
#     排程時不立即傷害；第三次 turn_end 對原位置目前 battler 施放真正 Doom Desire
#     Skill Effect。避免 raw HP 提前變動，並保留正式 Type/Damage Core。
#
# 【可調參數】
#  NATURE_POWER_MAP、CALL_BLACKLIST、CURSE_HP_DENOM、CURSE_TICK_DENOM、
#  STOCKPILE_MAX、DOOM_DELAY_ENDS。
#
# 【事件／腳本呼叫方式】
#  正常遊戲不需事件呼叫。Debug 可用：
#    battler.cg_v240_stockpile_count
#    battler.cg_v240_cursed?
#    battler.cg_v240_imprison_active?
#    ALBERT_CG::UNIQUE_G_V240.start_auto_test
#
# 【實際範例】
#  Mirror Move：E0 上一次使用 Tackle(33)，A1 對 E0 使用 Mirror Move，執行層會記錄
#    CALL_MOVE parent=119 called=33，之後真正 Action 變成 Tackle。
#  Nature Power：Electric Terrain 下使用，真正執行 Thunderbolt(85)。
#  Imprison：A1 會 Thunderbolt，對手 E0 再選 Thunderbolt 時會輸出
#    IMPRISON_BLOCK attacker=E0 move=85 source=A1，且不造成傷害。
#
# 【AutoRegression】
#  F11 執行 5 回合真正 Scene_Battle：
#   R1：Mirror Move / Nature Power / Assist 三種動態呼叫 + Stockpile 第 1 層。
#   R2：Imprison 阻止共享 Thunderbolt；同時測 Ghost / non-Ghost Curse 雙分支。
#   R3：Stockpile 第 2 層 + Doom Desire 排程，確認無立即傷害。
#   R4：Stockpile 第 3 層，Doom 尚未提早命中。
#   R5：Stockpile 第 3 層成立；Doom Desire 真正延遲命中並造成傷害。
#  成功標準：
#    RESULT=PASS
#    SUMMARY rounds=5 failures=0 unique_g_moves=7/7 call_checks=6 control_checks=8
#
# 【相容與邊界】
#  RPG Maker VX / RGSS2 / Tankentai SBS + PMD Native。
#  本頁只做 Move Logic，不改 PMD Motion 2.0 Renderer；F11 仍只有最新版 Regression。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonUniqueMoveBatchG"] = "2.4.0a"

module ALBERT_CG
  module UNIQUE_G_V240
    VERSION = "2.4.0a"
    MOVE_MIRROR_MOVE  = 119
    MOVE_CURSE        = 174
    MOVE_STOCKPILE    = 254
    MOVE_NATURE_POWER = 267
    MOVE_ASSIST       = 274
    MOVE_IMPRISON     = 286
    MOVE_DOOM_DESIRE  = 353
    HANDLED_MOVE_IDS = [MOVE_MIRROR_MOVE,MOVE_CURSE,MOVE_STOCKPILE,
                        MOVE_NATURE_POWER,MOVE_ASSIST,MOVE_IMPRISON,
                        MOVE_DOOM_DESIRE]

    CURSE_HP_DENOM = 2
    CURSE_TICK_DENOM = 4
    STOCKPILE_MAX = 3
    DOOM_DELAY_ENDS = 3
    TEST_TROOP_ID = 689
    TEST_LEVEL = 40
    VK_F11 = 0x7A

    NATURE_POWER_MAP = {
      :electric=>85,
      :grassy=>412,
      :misty=>585,
      :psychic=>94,
      nil=>161
    }
    CALL_BLACKLIST = [102,118,119,166,214,267,274,383,689]

    TEST_ALLIES = [
      {:dex=>474,:level=>40,:ability=>91, :moves=>[119,254,286,85]},
      {:dex=>3,  :level=>40,:ability=>65, :moves=>[267,174,412,150]},
      {:dex=>94, :level=>40,:ability=>130,:moves=>[274,174,353,94]},
    ]
    TEST_ENEMIES = [
      {:dex=>68,:level=>40,:ability=>62,:moves=>[254,85,33,150]},
      {:dex=>6, :level=>40,:ability=>66,:moves=>[85,150,150,150]},
      {:dex=>9, :level=>40,:ability=>67,:moves=>[150,150,150,150]},
      {:dex=>65,:level=>40,:ability=>28,:moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"CALL_MOVE_CORE_AND_STOCKPILE_1",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>119,:target=>0},
          {:kind=>:move,:move_id=>267,:target=>3},
          {:kind=>:move,:move_id=>274,:target=>0,:called_move_id=>94},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>254,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
      {
        :name=>"IMPRISON_AND_CURSE_BRANCHES",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>286,:target=>1},
          {:kind=>:move,:move_id=>174,:target=>2},
          {:kind=>:move,:move_id=>174,:target=>1},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>85,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
      {
        :name=>"STOCKPILE_2_AND_DOOM_SCHEDULE",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>254,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>2},
          {:kind=>:move,:move_id=>353,:target=>2},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
      {
        :name=>"STOCKPILE_3_DOOM_WAIT",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>254,:target=>1},
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
      {
        :name=>"STOCKPILE_3_AND_DOOM_RESOLVE",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>254,:target=>1},
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
      :r1=>[140,130,120,110,90,80,70,60],
      :r2=>[140,130,120,110,90,80,70,60],
      :r3=>[140,130,120,110,90,80,70,60],
      :r4=>[140,130,120,110,90,80,70,60],
      :r5=>[140,130,120,110,90,80,70,60],
    }
    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M119>33","A2:M267>85","A3:M274>94","E0:M254","E1:M150","E2:M150","E3:M150"],
      2=>["A0:Guard","A1:M286","A2:M174","A3:M174","E0:M85:BLOCK","E1:M150","E2:M150","E3:M150"],
      3=>["A0:Guard","A1:M254","A2:M150","A3:M353","E0:M150","E1:M150","E2:M150","E3:M150"],
      4=>["A0:Guard","A1:M254","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
      5=>["A0:Guard","A1:M254","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
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
    def self.log_path; return File.join(project_root,"Pokemon_UniqueG_AutoTest_v2_4_0a.log"); end
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
      return true if line.index("CALL_MOVE") == 0 || line.index("CURSE_") == 0
      return true if line.index("STOCKPILE_") == 0 || line.index("IMPRISON_") == 0
      return true if line.index("DOOM_") == 0 || line.index("RESULT=") == 0 || line.index("SUMMARY ") == 0
      return false
    end
    def self.log(line)
      text=line.to_s
      write_line(log_path,text)
      write_line(latest_log_path,text)
      write_line(trace_log_path,"[UNIQUE_G_AUTOTEST] " + text) if important_line?(text)
    end
    def self.reset_log
      header=[
        "CG POKEMON UNIQUE MOVE G AUTO REGRESSION v2.4.0a",
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        "RULE=Actual Scene_Battle; 7 call/memory/restriction Unique Moves",
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

    def self.battler_token(b)
      return "nil" if b == nil
      return (b.actor? ? "A" : "E") + b.index.to_i.to_s
    rescue
      return "?"
    end
    def self.move_status?(mid)
      row=master == nil ? nil : master.move(mid.to_i)
      return row != nil && row[7] == :status
    rescue
      return false
    end
    def self.callable_move?(mid)
      id=mid.to_i
      return false if id <= 0 || CALL_BLACKLIST.include?(id)
      return false if master == nil || master.move(id) == nil
      return false if ALBERT_CG::MOVE_EFFECT.meta_category(id) == 12
      return true
    rescue
      return false
    end
    def self.selected_target(user)
      return nil if user == nil || user.action == nil
      idx=user.action.target_index.to_i
      unit=user.actor? ? $game_troop : $game_party
      return unit == nil ? nil : unit.members[idx]
    rescue
      return nil
    end
    def self.terrain
      return nil unless defined?(ALBERT_CG::FIELD_V233)
      st=ALBERT_CG::FIELD_V233.state
      return nil if st == nil || st.terrain_turns.to_i <= 0
      return st.terrain
    rescue
      return nil
    end
    def self.assist_pool(user)
      unit=user.actor? ? $game_party : $game_troop
      result=[]
      return result if unit == nil
      unit.members.each do |b|
        next if b == nil || b == user || b.hp.to_i <= 0
        next unless b.respond_to?(:cg_v234_known_move_ids)
        b.cg_v234_known_move_ids.each do |mid|
          result.push(mid.to_i) if callable_move?(mid)
        end
      end
      return result.uniq
    rescue
      return []
    end
    def self.choose_called_move(user,parent_mid)
      forced=user.instance_variable_get(:@cg_v240_forced_called_move_id)
      user.instance_variable_set(:@cg_v240_forced_called_move_id,nil)
      return forced.to_i if forced != nil && callable_move?(forced.to_i)
      case parent_mid.to_i
      when MOVE_MIRROR_MOVE
        t=selected_target(user)
        mid=t != nil && t.respond_to?(:cg_v234_last_move_id) ? t.cg_v234_last_move_id.to_i : 0
        return callable_move?(mid) ? mid : 0
      when MOVE_NATURE_POWER
        mid=NATURE_POWER_MAP.has_key?(terrain) ? NATURE_POWER_MAP[terrain] : NATURE_POWER_MAP[nil]
        return callable_move?(mid) ? mid.to_i : 0
      when MOVE_ASSIST
        pool=assist_pool(user)
        return pool.empty? ? 0 : pool[rand(pool.size)].to_i
      end
      return 0
    rescue
      return 0
    end
    def self.prepare_call_action(user)
      return if user == nil || user.action == nil || !user.action.skill?
      parent=ALBERT_CG::MOVE_EFFECT.move_id(user.action.skill)
      return unless [MOVE_MIRROR_MOVE,MOVE_NATURE_POWER,MOVE_ASSIST].include?(parent)
      called=choose_called_move(user,parent)
      if called > 0 && defined?(ALBERT_CG::UNIQUE_B_V234) &&
         ALBERT_CG::UNIQUE_B_V234.replace_action_with_move(user,called,parent)
        user.instance_variable_set(:@cg_v240_call_parent_mid,parent)
        user.instance_variable_set(:@cg_v240_call_called_mid,called)
        mark_apply(parent)
        log("CALL_MOVE battler=" + user.name.to_s + " parent=" + parent.to_s +
            " called=" + called.to_s + ":" + master.move_name(called).to_s)
      else
        user.instance_variable_set(:@cg_v240_call_failed_mid,parent)
        log("CALL_MOVE_FAIL battler=" + user.name.to_s + " parent=" + parent.to_s)
      end
    end
    def self.clear_call_context(user)
      return if user == nil
      user.instance_variable_set(:@cg_v240_call_parent_mid,nil)
      user.instance_variable_set(:@cg_v240_call_called_mid,nil)
      user.instance_variable_set(:@cg_v240_call_failed_mid,nil)
    end

    def self.apply_counts; @apply_counts={} if @apply_counts == nil; return @apply_counts; end
    def self.mark_apply(mid)
      id=mid.to_i
      apply_counts[id]=apply_counts[id].to_i + 1
      log("APPLY move=" + id.to_s + ":" + (master == nil ? "" : master.move_name(id).to_s) +
          " count=" + apply_counts[id].to_s)
    end

    def self.ghost?(b)
      return false if b == nil || !b.respond_to?(:cg_pokemon_types)
      return b.cg_pokemon_types.include?(:ghost)
    rescue
      return false
    end
    def self.apply_curse(user,target)
      return false if user == nil
      if ghost?(user)
        return false if target == nil || target == user || target.hp.to_i <= 0
        return false if target.cg_v240_cursed?
        loss=[[user.maxhp.to_i / CURSE_HP_DENOM,1].max,user.hp.to_i].min
        user.hp=[user.hp.to_i-loss,0].max
        user.hp_damage=loss if user.respond_to?(:hp_damage=)
        target.instance_variable_set(:@cg_v240_curse_source,user)
        target.instance_variable_set(:@cg_v240_cursed,true)
        mark_apply(MOVE_CURSE)
        log("CURSE_GHOST user=" + user.name.to_s + " target=" + target.name.to_s +
            " self_loss=" + loss.to_s)
        return true
      end
      user.cg_change_stat_stage(:atk,1) if user.respond_to?(:cg_change_stat_stage)
      user.cg_change_stat_stage(:def,1) if user.respond_to?(:cg_change_stat_stage)
      user.cg_change_stat_stage(:spe,-1) if user.respond_to?(:cg_change_stat_stage)
      mark_apply(MOVE_CURSE)
      log("CURSE_NORMAL user=" + user.name.to_s + " atk=" + user.cg_stat_stage(:atk).to_s +
          " def=" + user.cg_stat_stage(:def).to_s + " spe=" + user.cg_stat_stage(:spe).to_s)
      return true
    end
    def self.apply_stockpile(user)
      return false if user == nil
      count=user.cg_v240_stockpile_count
      if count >= STOCKPILE_MAX
        log("STOCKPILE_CAP user=" + user.name.to_s + " count=" + count.to_s)
        return false
      end
      user.instance_variable_set(:@cg_v240_stockpile_count,count+1)
      user.cg_change_stat_stage(:def,1) if user.respond_to?(:cg_change_stat_stage)
      user.cg_change_stat_stage(:spd,1) if user.respond_to?(:cg_change_stat_stage)
      mark_apply(MOVE_STOCKPILE)
      log("STOCKPILE_SET user=" + user.name.to_s + " count=" + (count+1).to_s +
          " def=" + user.cg_stat_stage(:def).to_s + " spd=" + user.cg_stat_stage(:spd).to_s)
      return true
    end
    def self.apply_imprison(user)
      return false if user == nil
      user.instance_variable_set(:@cg_v240_imprison,true)
      mark_apply(MOVE_IMPRISON)
      log("IMPRISON_SET user=" + user.name.to_s)
      return true
    end
    def self.imprison_source_for(battler,mid)
      return nil if battler == nil || mid.to_i <= 0
      unit=battler.actor? ? $game_troop : $game_party
      return nil if unit == nil
      unit.members.each do |source|
        next if source == nil || source.hp.to_i <= 0 || !source.cg_v240_imprison_active?
        next unless source.respond_to?(:cg_v234_known_move_ids)
        return source if source.cg_v234_known_move_ids.include?(mid.to_i)
      end
      return nil
    rescue
      return nil
    end
    def self.position_of(b)
      side=b != nil && b.actor? ? :ally : :enemy
      h={:side=>side,:index=>(b == nil ? -1 : b.index.to_i)}
      if b != nil && b.respond_to?(:cg_battle_slot_assigned?) && b.cg_battle_slot_assigned?
        h[:row]=b.cg_battle_row; h[:column]=b.cg_battle_column
      end
      return h
    end
    def self.battler_at_position(h)
      return nil if h == nil
      unit=h[:side] == :ally ? $game_party : $game_troop
      return nil if unit == nil
      if h[:row] != nil && h[:column] != nil
        unit.members.each do |b|
          next if b == nil || !b.respond_to?(:cg_battle_slot_assigned?) || !b.cg_battle_slot_assigned?
          return b if b.cg_battle_row == h[:row] && b.cg_battle_column.to_i == h[:column].to_i
        end
      end
      return unit.members[h[:index].to_i]
    rescue
      return nil
    end
    def self.schedule_doom(user,target)
      return false if user == nil || target == nil
      @doom_queue=[] if @doom_queue == nil
      h=position_of(target)
      h[:remaining]=DOOM_DELAY_ENDS
      h[:user]=user
      @doom_queue.push(h)
      mark_apply(MOVE_DOOM_DESIRE)
      log("DOOM_SCHEDULE user=" + user.name.to_s + " target=" + target.name.to_s +
          " remaining=" + DOOM_DELAY_ENDS.to_s)
      return true
    end
    def self.tick_end_turn
      # Ghost Curse residual
      list=[]
      list.concat($game_party.members) if $game_party != nil
      list.concat($game_troop.members) if $game_troop != nil
      list.each do |b|
        next if b == nil || !b.cg_v240_cursed?
        if b.hp.to_i <= 0
          b.cg_v240_clear_curse
          next
        end
        dmg=[[b.maxhp.to_i / CURSE_TICK_DENOM,1].max,b.hp.to_i].min
        b.hp=[b.hp.to_i-dmg,0].max
        b.hp_damage=dmg if b.respond_to?(:hp_damage=)
        log("CURSE_TICK target=" + b.name.to_s + " damage=" + dmg.to_s + " hp=" + b.hp.to_i.to_s)
      end
      # Doom Desire delayed queue
      @doom_queue=[] if @doom_queue == nil
      @doom_queue.each { |h| h[:remaining]=h[:remaining].to_i-1 }
      due=@doom_queue.select { |h| h[:remaining].to_i <= 0 }
      due.each do |h|
        target=battler_at_position(h)
        user=h[:user]
        if target != nil && target.hp.to_i > 0 && user != nil
          sid=master.skill_id_for_move(MOVE_DOOM_DESIRE)
          skill=$data_skills[sid]
          hp0=target.hp.to_i
          @resolving_doom=true
          begin
            target.skill_effect(user,skill) if skill != nil
          ensure
            @resolving_doom=false
          end
          log("DOOM_RESOLVE user=" + user.name.to_s + " target=" + target.name.to_s +
              " damage=" + [hp0-target.hp.to_i,0].max.to_s)
        else
          log("DOOM_RESOLVE target=nil damage=0")
        end
        @doom_queue.delete(h)
      end
    end
    def self.resolving_doom?; return @resolving_doom == true; end

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
      actor.cg_v240_clear_runtime if actor.respond_to?(:cg_v240_clear_runtime)
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
        human.cg_v240_clear_runtime if human.respond_to?(:cg_v240_clear_runtime)
        human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
      end
      return true
    end
    def self.apply_test_grid
      allies=test_allies; enemies=test_enemies
      sa=[[:back,1],[:front,0],[:front,1],[:front,2]]
      se=[[:front,0],[:front,1],[:front,2],[:back,1]]
      allies.each_with_index { |b,i| b.cg_set_battle_slot(sa[i][0],sa[i][1],true) if b != nil && b.respond_to?(:cg_set_battle_slot) }
      enemies.each_with_index { |b,i| b.cg_set_battle_slot(se[i][0],se[i][1],true) if b != nil && b.respond_to?(:cg_set_battle_slot) }
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
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon UniqueG v2.4.0a AutoRegression",members)
    end
    def self.make_action(b,cfg)
      a=Game_BattleAction.new(b)
      if cfg[:kind] == :attack
        a.set_attack
      elsif cfg[:kind] == :guard
        a.set_guard
      elsif cfg[:kind] == :move
        a.set_skill(master.skill_id_for_move(cfg[:move_id].to_i))
      else
        a.clear
      end
      a.target_index=cfg[:target].to_i if cfg.has_key?(:target)
      b.instance_variable_set(:@cg_v240_forced_called_move_id,cfg[:called_move_id].to_i) if cfg[:called_move_id] != nil
      return a
    end
    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym] || []
      (test_allies+test_enemies).each_with_index do |b,i|
        b.instance_variable_set(:@cg_priority_test_speed_override,vals[i]) if b != nil
      end
    end
    def self.prepare_round_preconditions
      a=test_allies; e=test_enemies
      if current_round == 1
        # Mirror Move 的選定目標最近 Move 固定為 Tackle。
        e[0].cg_v234_set_last_move_id(33) if e[0] != nil && e[0].respond_to?(:cg_v234_set_last_move_id)
        if defined?(ALBERT_CG::FIELD_V233)
          st=ALBERT_CG::FIELD_V233.state
          st.terrain=:electric; st.terrain_turns=5 if st != nil
        end
        @r1_e0_stock_def=e[0].cg_stat_stage(:def)
        @r1_e0_stock_spd=e[0].cg_stat_stage(:spd)
      elsif current_round == 2
        if defined?(ALBERT_CG::FIELD_V233)
          st=ALBERT_CG::FIELD_V233.state
          st.terrain=nil; st.terrain_turns=0 if st != nil
        end
        @r2_a2_atk=a[2].cg_stat_stage(:atk); @r2_a2_def=a[2].cg_stat_stage(:def); @r2_a2_spe=a[2].cg_stat_stage(:spe)
        @r2_a3_hp=a[3].hp.to_i; @r2_e1_hp=e[1].hp.to_i; @r2_a2_hp=a[2].hp.to_i
      elsif current_round == 3
        @doom_hp_before=e[2].hp.to_i
      elsif current_round == 4
        @doom_hp_round4=e[2].hp.to_i
      elsif current_round == 5
        @stock_def_before_cap=a[1].cg_stat_stage(:def)
        @stock_spd_before_cap=a[1].cg_stat_stage(:spd)
        @doom_hp_before_resolve=e[2].hp.to_i
      end
    end
    def self.prepare_round_actions
      plan=current_plan; return false if plan == nil
      apply_test_speeds
      prepare_round_preconditions
      @actual=[]; @round_before={}
      HANDLED_MOVE_IDS.each { |mid| @round_before[mid]=apply_counts[mid].to_i }
      log("ROUND " + current_round.to_s + " BEGIN " + plan[:name].to_s)
      a=test_allies
      plan[:allies].each_with_index do |cfg,i|
        b=a[i]; next if b == nil
        ac=make_action(b,cfg)
        if b.respond_to?(:cg_round_actions); b.cg_round_actions.clear; b.cg_round_actions.push(ac); end
        b.cg_assign_action(ac) if b.respond_to?(:cg_assign_action)
      end
      @forced_enemy={}; e=test_enemies
      plan[:enemies].each_with_index { |cfg,i| @forced_enemy[i]=make_action(e[i],cfg) if e[i] != nil }
      return true
    end
    def self.forced_enemy_action(e); return active? && @forced_enemy != nil && e != nil ? @forced_enemy[e.index] : nil; end
    def self.record_execution(b,blocked=false)
      return unless active? && b != nil
      a=b.action
      token=battler_token(b)
      parent=b.instance_variable_get(:@cg_v240_call_parent_mid)
      called=b.instance_variable_get(:@cg_v240_call_called_mid)
      if parent != nil && called != nil
        token += ":M" + parent.to_i.to_s + ">" + called.to_i.to_s
      elsif a != nil && a.skill?
        token += ":M" + ALBERT_CG::MOVE_EFFECT.move_id(a.skill).to_s
      elsif a != nil && a.guard?
        token += ":Guard"
      elsif a != nil && a.attack?
        token += ":Attack"
      else
        token += ":Other"
      end
      token += ":BLOCK" if blocked
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + b.name.to_s + " token=" + token)
    end
    def self.assert_true(label,ok,detail="")
      if ok
        log("ASSERT PASS " + label.to_s + (detail=="" ? "" : " " + detail.to_s))
      else
        msg=label.to_s + (detail=="" ? "" : " " + detail.to_s)
        @failures.push(msg); log("ASSERT FAIL " + msg)
      end
      return ok
    end
    def self.note_call(ok); @call_checks += 1 if ok; end
    def self.note_control(ok); @control_checks += 1 if ok; end
    def self.assert_round
      r=current_round; a=test_allies; e=test_enemies
      exp=EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round"+r.to_s+" executes exactly 8 scripted battler actions",@actual.size==8,"actual="+@actual.size.to_s)
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==exp,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r == 1
        ok=apply_counts[MOVE_MIRROR_MOVE].to_i>@round_before[MOVE_MIRROR_MOVE].to_i; note_call(ok); assert_true("Mirror Move parent executes and calls target last move",ok)
        ok=apply_counts[MOVE_NATURE_POWER].to_i>@round_before[MOVE_NATURE_POWER].to_i; note_call(ok); assert_true("Nature Power parent executes under Electric Terrain",ok)
        ok=apply_counts[MOVE_ASSIST].to_i>@round_before[MOVE_ASSIST].to_i; note_call(ok); assert_true("Assist parent executes deterministic called move",ok)
        ok=e[0].cg_v240_stockpile_count==1 && e[0].cg_stat_stage(:def)==@r1_e0_stock_def+1 && e[0].cg_stat_stage(:spd)==@r1_e0_stock_spd+1; note_control(ok); assert_true("Stockpile layer1 raises DEF/SpD and count=1",ok)
      elsif r == 2
        ok=a[1].cg_v240_imprison_active?; note_control(ok); assert_true("Imprison marker stays active",ok)
        ok=@imprison_blocks.to_i>=1 && a[2].hp.to_i==@r2_a2_hp.to_i; note_control(ok); assert_true("Imprison blocks shared Thunderbolt before damage",ok)
        ok=a[2].cg_stat_stage(:atk)==@r2_a2_atk+1 && a[2].cg_stat_stage(:def)==@r2_a2_def+1 && a[2].cg_stat_stage(:spe)==@r2_a2_spe-1; note_control(ok); assert_true("Non-Ghost Curse applies ATK+1 DEF+1 SPE-1",ok)
        ok=a[3].hp.to_i<@r2_a3_hp.to_i && e[1].cg_v240_cursed? && e[1].hp.to_i<@r2_e1_hp.to_i; note_control(ok); assert_true("Ghost Curse pays HP and target takes end-turn residual",ok)
      elsif r == 3
        ok=a[1].cg_v240_stockpile_count==1; note_control(ok); assert_true("A1 first Stockpile layer established",ok)
        ok=apply_counts[MOVE_DOOM_DESIRE].to_i>@round_before[MOVE_DOOM_DESIRE].to_i && e[2].hp.to_i==@doom_hp_before.to_i; note_call(ok); assert_true("Doom Desire schedules without immediate damage",ok)
      elsif r == 4
        ok=a[1].cg_v240_stockpile_count==2; note_control(ok); assert_true("A1 Stockpile layer2 established",ok)
        ok=e[2].hp.to_i==@doom_hp_round4.to_i; note_call(ok); assert_true("Doom Desire has not resolved one turn early",ok)
      elsif r == 5
        ok=a[1].cg_v240_stockpile_count==3; note_control(ok); assert_true("A1 Stockpile reaches layer3",ok)
        ok=e[2].hp.to_i<@doom_hp_before_resolve.to_i; note_call(ok); assert_true("Doom Desire resolves on delayed turn and deals damage",ok)
      end
      log("ROUND " + r.to_s + " END")
    end
    def self.finish_round_assertions
      assert_round
      @round_index=@round_index.to_i+1
    end
    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted=true
      assert_true("Scene_Battle uses Unique G test troop",current_troop_id==TEST_TROOP_ID,"actual="+current_troop_id.to_s)
      assert_true("Unique G ally count",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Unique G enemy count",test_enemies.size==4,"actual="+test_enemies.size.to_s)
      apply_test_grid
    end
    def self.covered_move_count
      count = 0
      HANDLED_MOVE_IDS.each do |mid|
        count += 1 if apply_counts[mid].to_i > 0
      end
      return count
    end
    def self.finish_suite
      begin
        HANDLED_MOVE_IDS.each do |mid|
          assert_true("Move "+mid.to_s+" covered",apply_counts[mid].to_i>0)
        end
        result=@failures.empty? ? "PASS" : "FAIL"
        log("------------------------------------------------------------")
        log("RESULT="+result)
        log("SUMMARY rounds=5 failures="+@failures.size.to_s+" unique_g_moves="+covered_move_count.to_s+"/7 call_checks="+@call_checks.to_i.to_s+" control_checks="+@control_checks.to_i.to_s)
        @failures.each_with_index { |x,i| log("FAILURE "+(i+1).to_s+" "+x.to_s) }
      ensure
        cleanup_test_overrides
        @active=false
      end
    end
    def self.cleanup_test_overrides
      (test_allies+test_enemies).each do |b|
        next if b == nil
        b.instance_variable_set(:@cg_priority_test_speed_override,nil)
        b.instance_variable_set(:@cg_v240_forced_called_move_id,nil)
      end
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @actual=[]; @apply_counts={}; @doom_queue=[]
      @call_checks=0; @control_checks=0; @boot_asserted=false; @imprison_blocks=0
      @resolving_doom=false
    end
    def self.start_auto_test
      reset_log; reset_suite; prepare_test_party; make_test_troop; install_skill_scopes
      @active=true
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s)
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    end
    def self.install_skill_scopes
      return if master == nil || $data_skills == nil
      self_ids=[MOVE_STOCKPILE,MOVE_IMPRISON]
      HANDLED_MOVE_IDS.each do |mid|
        sid=master.skill_id_for_move(mid); next if sid.to_i<=0 || $data_skills[sid]==nil
        $data_skills[sid].scope=self_ids.include?(mid) ? 11 : 1
      end
    rescue => e
      log("SCOPE_INSTALL_ERROR "+e.class.to_s+":"+e.message.to_s) if active?
    end
    def self.note_imprison_block(attacker,mid,source)
      @imprison_blocks=@imprison_blocks.to_i+1
      log("IMPRISON_BLOCK attacker="+battler_token(attacker)+":"+attacker.name.to_s+
          " move="+mid.to_i.to_s+" source="+battler_token(source)+":"+source.name.to_s)
    end
  end
end

#==============================================================================
# ■ Game_Battler：Batch G Runtime Flags / Skill Effects
#==============================================================================
class Game_Battler
  def cg_v240_stockpile_count; return @cg_v240_stockpile_count.to_i; end
  def cg_v240_cursed?; return @cg_v240_cursed == true; end
  def cg_v240_imprison_active?; return @cg_v240_imprison == true; end
  def cg_v240_imprisoned_move?(move_id)
    return ALBERT_CG::UNIQUE_G_V240.imprison_source_for(self,move_id) != nil
  rescue
    return false
  end
  def cg_v240_clear_curse; @cg_v240_cursed=false; @cg_v240_curse_source=nil; end
  def cg_v240_clear_runtime
    @cg_v240_stockpile_count=0
    @cg_v240_cursed=false; @cg_v240_curse_source=nil
    @cg_v240_imprison=false
    @cg_v240_forced_called_move_id=nil
    @cg_v240_call_parent_mid=nil; @cg_v240_call_called_mid=nil; @cg_v240_call_failed_mid=nil
  end

  alias cg_v240_remove_states_battle remove_states_battle
  def remove_states_battle
    cg_v240_remove_states_battle
    cg_v240_clear_runtime
  end

  if method_defined?(:cg_v236_clear_volatile)
    alias cg_v240_clear_volatile_bridge cg_v236_clear_volatile
    def cg_v236_clear_volatile
      cg_v240_clear_volatile_bridge
      cg_v240_clear_runtime
    end
  end

  alias cg_v240_skill_effect skill_effect
  def skill_effect(user,skill)
    mid=ALBERT_CG::MOVE_EFFECT.move_id(skill)
    case mid
    when ALBERT_CG::UNIQUE_G_V240::MOVE_CURSE
      clear_action_results
      if ALBERT_CG::UNIQUE_G_V240.ghost?(user) && respond_to?(:cg_v234_substitute_active?) &&
         cg_v234_substitute_active? && user != nil && user.actor? != actor?
        @skipped=true
        ALBERT_CG::UNIQUE_G_V240.log("CURSE_BLOCK_SUBSTITUTE target="+name.to_s+" user="+user.name.to_s)
        return
      end
      ALBERT_CG::UNIQUE_G_V240.apply_curse(user,self)
      return
    when ALBERT_CG::UNIQUE_G_V240::MOVE_STOCKPILE
      clear_action_results
      ALBERT_CG::UNIQUE_G_V240.apply_stockpile(user)
      return
    when ALBERT_CG::UNIQUE_G_V240::MOVE_IMPRISON
      clear_action_results
      ALBERT_CG::UNIQUE_G_V240.apply_imprison(user)
      return
    when ALBERT_CG::UNIQUE_G_V240::MOVE_DOOM_DESIRE
      unless ALBERT_CG::UNIQUE_G_V240.resolving_doom?
        clear_action_results
        ALBERT_CG::UNIQUE_G_V240.schedule_doom(user,self)
        return
      end
    when ALBERT_CG::UNIQUE_G_V240::MOVE_MIRROR_MOVE,
         ALBERT_CG::UNIQUE_G_V240::MOVE_NATURE_POWER,
         ALBERT_CG::UNIQUE_G_V240::MOVE_ASSIST
      # 成功時 Scene_Battle 已替換為 called Move；走到這裡代表沒有合法可呼叫 Move。
      clear_action_results
      ALBERT_CG::UNIQUE_G_V240.log("CALL_PARENT_NO_EFFECT user="+user.name.to_s+" move="+mid.to_s)
      return
    end
    cg_v240_skill_effect(user,skill)
  end
end

#==============================================================================
# ■ Game_Battler：v2.4.0a deterministic SPE Bridge
#==============================================================================
class Game_Battler
  alias cg_v240_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::UNIQUE_G_V240) && ALBERT_CG::UNIQUE_G_V240.active?
      x=@cg_priority_test_speed_override
      return x.to_i if x != nil
    end
    return cg_v240_priority_base_speed
  rescue
    return cg_v240_priority_base_speed
  end
end

#==============================================================================
# ■ Game_Enemy：Regression deterministic action
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v240_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::UNIQUE_G_V240) && ALBERT_CG::UNIQUE_G_V240.active?
      a=ALBERT_CG::UNIQUE_G_V240.forced_enemy_action(self)
      if a != nil
        cg_assign_action(a) if respond_to?(:cg_assign_action)
        @action=a unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v240_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle：Dynamic Call / Imprison / delayed queue / Regression
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v240_execute_action execute_action
  def execute_action
    b=@active_battler
    if b != nil
      ALBERT_CG::UNIQUE_G_V240.prepare_call_action(b)
      action=b.action
      mid=action != nil && action.skill? ? ALBERT_CG::MOVE_EFFECT.move_id(action.skill) : 0
      source=ALBERT_CG::UNIQUE_G_V240.imprison_source_for(b,mid)
      if source != nil
        ALBERT_CG::UNIQUE_G_V240.record_execution(b,true) if ALBERT_CG::UNIQUE_G_V240.active?
        ALBERT_CG::UNIQUE_G_V240.note_imprison_block(b,mid,source)
        ALBERT_CG::UNIQUE_G_V240.clear_call_context(b)
        return
      end
      ALBERT_CG::UNIQUE_G_V240.record_execution(b,false) if ALBERT_CG::UNIQUE_G_V240.active?
    end
    begin
      cg_v240_execute_action
    ensure
      ALBERT_CG::UNIQUE_G_V240.clear_call_context(b) if b != nil
    end
  end

  alias cg_v240_turn_end turn_end
  def turn_end
    ALBERT_CG::UNIQUE_G_V240.tick_end_turn if defined?(ALBERT_CG::UNIQUE_G_V240)
    ALBERT_CG::UNIQUE_G_V240.finish_round_assertions if defined?(ALBERT_CG::UNIQUE_G_V240) && ALBERT_CG::UNIQUE_G_V240.active?
    cg_v240_turn_end
  end

  alias cg_v240_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::UNIQUE_G_V240) && ALBERT_CG::UNIQUE_G_V240.active?
      return cg_v240_start_party_command
    end
    cg_v240_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::UNIQUE_G_V240.assert_bootstrap_once
    if ALBERT_CG::UNIQUE_G_V240.finished?
      ALBERT_CG::UNIQUE_G_V240.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::UNIQUE_G_V240.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle 重建 Party 後重套 Batch G 測試資料
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v240_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result=cg_v240_bootstrap_demo_party
      if defined?(ALBERT_CG::UNIQUE_G_V240) && ALBERT_CG::UNIQUE_G_V240.active?
        ALBERT_CG::UNIQUE_G_V240::TEST_ALLIES.each { |cfg| ALBERT_CG::UNIQUE_G_V240.configure_actor(cfg) }
        human=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::UNIQUE_G_V240::TEST_LEVEL,false)
          human.recover_all if human.respond_to?(:recover_all)
          human.cg_v240_clear_runtime if human.respond_to?(:cg_v240_clear_runtime)
          human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
        end
        ALBERT_CG::UNIQUE_G_V240.install_skill_scopes
      end
      return result
    end
  end
end

#==============================================================================
# ■ Scene_Title：Move Stub 建立後校正 Scope
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_v240_load_database load_database
  def load_database
    cg_v240_load_database
    ALBERT_CG::UNIQUE_G_V240.install_skill_scopes
  end
  alias cg_v240_load_bt_database load_bt_database
  def load_bt_database
    cg_v240_load_bt_database
    ALBERT_CG::UNIQUE_G_V240.install_skill_scopes
  end
end

#==============================================================================
# ■ F11：v2.4.0a 成為唯一最新版 AutoRegression
#==============================================================================
if defined?(ALBERT_CG::UNIQUE_F_V239)
  module ALBERT_CG
    module UNIQUE_F_V239
      def self.f11_trigger?; return false; end
    end
  end
end
class Scene_Map < Scene_Base
  alias cg_v240_scene_map_update update
  def update
    cg_v240_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::UNIQUE_G_V240.f11_trigger?
      Sound.play_decision
      ALBERT_CG::UNIQUE_G_V240.start_auto_test
    end
  end
end

#==============================================================================
# ■ Coverage：7 個 Unique Pending 轉為 V240_UNIQUE_G_HANDLED
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    class << self
      alias cg_v240_coverage_v231 coverage_v231
      def coverage_v231(move_id)
        return "V240_UNIQUE_G_HANDLED" if ALBERT_CG::UNIQUE_G_V240.handled?(move_id)
        return cg_v240_coverage_v231(move_id)
      end
    end
  end
end
