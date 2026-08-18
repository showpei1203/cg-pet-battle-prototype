# RMVX_SCRIPT_INDEX: 201
# RMVX_SCRIPT_ID: 1153467380
# RMVX_SCRIPT_NAME: CG Pokemon Unique Move Batch E v2.3.8a
# RMVX_SOURCE_SHA256: fd079594db327a8f302058bbf95c25897ce2017347b1b7878682705b709aa9fd

#==============================================================================
# ■ CG Pokemon Unique Move Batch E v2.3.8a
#------------------------------------------------------------------------------
# 【用途】
#  接續 v2.3.7a 已實機 PASS 的 Unique Batch D，正式處理 12 個「能力／狀態／場地
#  交換與暫時改寫」招式，並建立 Battle-only Base Stat Override 層：
#    375 Psycho Shift／精神轉移       379 Power Trick／力量戲法
#    384 Power Swap／力量互換         385 Guard Swap／防守互換
#    391 Heart Swap／心靈互換         393 Magnet Rise／電磁飄浮
#    432 Defog／清除濃霧              470 Guard Split／防守平分
#    471 Power Split／力量平分        683 Speed Swap／速度互換
#    753 Octolock／蛸固               756 Court Change／換場
#
# 【v2.3.8a Runtime 修正：Final Stat Getter Bridge】
#  v2.3.8 實機發現：Power Split 已把 Battle Base ATK 74→78，但 Game_Actor 的
#  cg_atk_stat 仍回 74。根因不是 Power Split，而是 v2.1.0 曾在 Game_Actor /
#  Game_Enemy 各自定義 cg_atk_stat/cg_def_stat/cg_spa/cg_spd/cg_spe；Ruby
#  的 subclass method 會蓋過 v2.3.0 之後放在 Game_Battler 的 Stage / Field
#  wrapper，因此 Pokémon Actor/Enemy 沒有完整走同一條最終能力 getter。
#
#  v2.3.8a 正式修正：
#   - 先保存 Actor / Enemy 自己的六維 Native Base getter。
#   - 將 cg_move_v230_* raw hook 在 subclass 重新接回正確六維 Base。
#   - Actor / Enemy 最終 cg_* getter 改為 super，統一走 Game_Battler 的
#     Stage、Burn/Paralysis、Wonder Room、Sandstorm 與本版 Battle Base Override。
#   - 不改 Species/Actor 永久資料，也不改傷害公式本身。
#
# 【正式機制規則】
#  1. Battle-only Base Stat Override：
#     - 只改本次戰鬥的 ATK/DEF/SpA/SpD/SPE「基礎值來源」，不寫回 Species/Actor。
#     - 原本能力階級仍在 Override 後正常套用；Sandstorm / Wonder Room 等既有 Field
#       修正仍由既有 getter 接續處理。
#     - 換出與戰鬥結束清除。
#  2. Power Trick：交換使用者目前 Battle Base ATK / DEF；能力階級不跟著交換。
#  3. Power Swap：交換雙方 ATK / SpA 能力階級。
#  4. Guard Swap：交換雙方 DEF / SpD 能力階級。
#  5. Heart Swap：交換雙方 ATK/DEF/SpA/SpD/SPE/Accuracy/Evasion 全部能力階級。
#  6. Guard Split：雙方 Battle Base DEF 與 SpD 各自取整數平均後套給雙方。
#  7. Power Split：雙方 Battle Base ATK 與 SpA 各自取整數平均後套給雙方。
#  8. Speed Swap：交換雙方 Battle Base SPE。
#  9. Psycho Shift：將使用者目前第一個主要異常狀態轉移給目標；成功後使用者解除。
#     劇毒轉移後目標 toxic counter 從 1 開始，避免把舊 target 的累進計數混入。
# 10. Magnet Rise：5 回合內視為非 Grounded；Gravity 開啟時立即失效。
#     同時讓 Ground-type 傷害倍率變成 0%，並接入 Field grounded? API。
# 11. Defog：目標 Evasion -1；清除雙方 Entry Hazards，並清除目標方
#     Reflect / Light Screen / Aurora Veil / Safeguard / Mist。Weather/Terrain 不清除。
# 12. Court Change：交換 ally/enemy 的 Side Effects 與 Entry Hazards；不交換 Weather、
#     Terrain、Room、當回合 Wide/Quick Guard 類 round flags。
# 13. Octolock：目標進入不能主動換出的 lock；每回合末 DEF/SpD 各 -1。
#     使用者離場／倒下或目標被真正換出時解除；不阻擋 Roar/Whirlwind 強制換出。
#
# 【設計邊界】
#  - 本專案不做持有道具，因此本批不處理任何 item dependent 變體。
#  - Court Change / Defog 以本專案既有 Field Core 的 side/hazard 資料為唯一權威。
#  - PMD Motion 2.0 仍維持「身體演技層」獨立路線；本版不大改 Renderer，避免 Move
#    Logic 與 Presentation 同時拆屋頂。
#
# 【可調參數】
#  MAGNET_RISE_TURNS = 5
#  TEST_TROOP_ID = 691
#  TEST_LEVEL = 40
#
# 【事件／腳本呼叫方式】
#  正常戰鬥不需事件呼叫。Debug 可用：
#    battler.cg_v238_set_base_stat(:atk, 200)
#    battler.cg_v238_base_stat(:atk)
#    battler.cg_v238_clear_stat_identity
#    battler.cg_v238_magnet_rise?
#
# 【實際範例】
#  Power Split：
#    A ATK=120、B ATK=200 -> 兩者 Battle Base ATK 都變成 160；各自 ATK stage 照舊。
#  Magnet Rise：
#    target.cg_pokemon_type_rate_percent(:ground) -> 0（Gravity 時回復正常）。
#
# 【AutoRegression】
#  地圖畫面只按 F11，執行 3 回合真正 Scene_Battle：
#    R1：Power Trick / Power Swap / Guard Swap / Heart Swap
#    R2：Guard Split / Power Split / Speed Swap / Psycho Shift
#    R3：Court Change / Defog / Magnet Rise / Octolock + 真正 Ground 攻擊免疫
#  成功標準：
#    RESULT=PASS
#    SUMMARY rounds=3 failures=0 unique_e_moves=12/12 stat_checks=13 field_checks=8
#
# 【F11 政策】
#  F11 永遠只啟動目前最新版 AutoRegression；v2.3.7a 舊測試保留 script-call，
#  但鍵盤 F11 由本版接管。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonUniqueMoveBatchE"] = "2.3.8a"

module ALBERT_CG
  module UNIQUE_E_V238
    VERSION = "2.3.8a"
    MOVE_PSYCHO_SHIFT  = 375
    MOVE_POWER_TRICK   = 379
    MOVE_POWER_SWAP    = 384
    MOVE_GUARD_SWAP    = 385
    MOVE_HEART_SWAP    = 391
    MOVE_MAGNET_RISE   = 393
    MOVE_DEFOG         = 432
    MOVE_GUARD_SPLIT   = 470
    MOVE_POWER_SPLIT   = 471
    MOVE_SPEED_SWAP    = 683
    MOVE_OCTOLOCK      = 753
    MOVE_COURT_CHANGE  = 756

    HANDLED_MOVE_IDS = [
      MOVE_PSYCHO_SHIFT, MOVE_POWER_TRICK, MOVE_POWER_SWAP, MOVE_GUARD_SWAP,
      MOVE_HEART_SWAP, MOVE_MAGNET_RISE, MOVE_DEFOG, MOVE_GUARD_SPLIT,
      MOVE_POWER_SPLIT, MOVE_SPEED_SWAP, MOVE_OCTOLOCK, MOVE_COURT_CHANGE
    ]

    STAGE_KEYS = [:atk,:def,:spa,:spd,:spe,:accuracy,:evasion]
    MAGNET_RISE_TURNS = 5
    TEST_TROOP_ID = 691
    TEST_LEVEL = 40
    VK_F11 = 0x7A

    TEST_ALLIES = [
      {:dex=>137,:level=>40,:ability=>36,:moves=>[384,470,393,150]},
      {:dex=>3,  :level=>40,:ability=>65,:moves=>[385,471,432,150]},
      {:dex=>94, :level=>40,:ability=>130,:moves=>[391,683,756,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>6, :level=>40,:ability=>66,:moves=>[150,150,189,150]},
      {:dex=>9, :level=>40,:ability=>67,:moves=>[150,150,150,150]},
      {:dex=>65,:level=>40,:ability=>28,:moves=>[150,150,150,150]},
      {:dex=>68,:level=>40,:ability=>62,:moves=>[379,375,753,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"STAGE_SWAP_AND_POWER_TRICK",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>384,:target=>0},
          {:kind=>:move,:move_id=>385,:target=>1},
          {:kind=>:move,:move_id=>391,:target=>2},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>379,:target=>3},
        ]
      },
      {
        :name=>"BASE_STAT_SPLIT_SWAP_AND_PSYCHO_SHIFT",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>470,:target=>0},
          {:kind=>:move,:move_id=>471,:target=>1},
          {:kind=>:move,:move_id=>683,:target=>2},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>375,:target=>0},
        ]
      },
      {
        :name=>"FIELD_SUPPORT_DEFOG_MAGNET_OCTOLOCK",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>393,:target=>1},
          {:kind=>:move,:move_id=>432,:target=>0},
          {:kind=>:move,:move_id=>756,:target=>3},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>189,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>753,:target=>0},
        ]
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,110,100,90,50,40,30,120],
      :r2=>[10,110,100,90,50,40,30,120],
      :r3=>[10,100,110,120,80,60,50,90],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","E3:M379","A1:M384","A2:M385","A3:M391","E0:M150","E1:M150","E2:M150"],
      2=>["A0:Guard","E3:M375","A1:M470","A2:M471","A3:M683","E0:M150","E1:M150","E2:M150"],
      3=>["A0:Guard","A3:M756","A2:M432","A1:M393","E3:M753","E0:M189","E1:M150","E2:M150"],
    }

    begin
      KEY_API = Win32API.new("user32", "GetAsyncKeyState", "i", "i")
    rescue
      KEY_API = nil
    end

    def self.master
      return defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil
    end
    def self.active?; return @active == true; end
    def self.handled?(move_id); return HANDLED_MOVE_IDS.include?(move_id.to_i); end
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
    def self.log_path; return File.join(project_root,"Pokemon_UniqueE_AutoTest_v2_3_8a.log"); end
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
      return true if line.index("STAT_") == 0 || line.index("BASE_") == 0 || line.index("FINAL_STAT_BRIDGE") == 0
      return true if line.index("PSYCHO_") == 0 || line.index("MAGNET_") == 0
      return true if line.index("DEFOG") == 0 || line.index("COURT_CHANGE") == 0 || line.index("OCTOLOCK") == 0
      return true if line.index("RESULT=") == 0 || line.index("SUMMARY ") == 0
      return false
    end
    def self.log(line)
      text=line.to_s
      write_line(log_path,text)
      write_line(latest_log_path,text)
      write_line(trace_log_path,"[UNIQUE_E_AUTOTEST] " + text) if important_line?(text)
    end
    def self.reset_log
      header=[
        "CG POKEMON UNIQUE MOVE E AUTO REGRESSION v2.3.8a",
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        "RULE=Actual Scene_Battle; 12 stat/state/field exchange Unique Moves",
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
    def self.mark_apply(move_id)
      @apply_counts={} if @apply_counts == nil
      mid=move_id.to_i
      @apply_counts[mid]=@apply_counts[mid].to_i+1
      log("APPLY move=" + mid.to_s + ":" + (master == nil ? "" : master.move_name(mid).to_s) + " count=" + @apply_counts[mid].to_i.to_s) if active?
    end

    def self.install_skill_scopes
      return if master == nil || $data_skills == nil
      self_moves=[MOVE_POWER_TRICK,MOVE_MAGNET_RISE,MOVE_COURT_CHANGE]
      HANDLED_MOVE_IDS.each do |mid|
        sid=master.skill_id_for_move(mid)
        next if sid.to_i <= 0 || $data_skills[sid] == nil
        $data_skills[sid].scope = self_moves.include?(mid) ? 11 : 1
      end
    rescue => e
      log("SCOPE_INSTALL_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
    end

    def self.set_stage_exact(b,key,value)
      return false if b == nil || !b.respond_to?(:cg_stat_stage)
      cur=b.cg_stat_stage(key).to_i
      b.cg_change_stat_stage(key,value.to_i-cur)
      return true
    end
    def self.swap_stages(user,target,keys,label)
      return false if user == nil || target == nil
      before_u={}; before_t={}
      keys.each { |k| before_u[k]=user.cg_stat_stage(k); before_t[k]=target.cg_stat_stage(k) }
      keys.each { |k| set_stage_exact(user,k,before_t[k]); set_stage_exact(target,k,before_u[k]) }
      log("STAT_SWAP kind=" + label.to_s + " user=" + user.name.to_s + " target=" + target.name.to_s + " user_before=" + before_u.inspect + " target_before=" + before_t.inspect)
      show_text(user.name.to_s + "與" + target.name.to_s + "交換了能力變化！")
      return true
    end

    def self.apply_power_trick(user)
      return false if user == nil || !user.respond_to?(:cg_v238_base_stat)
      atk=user.cg_v238_base_stat(:atk); dfn=user.cg_v238_base_stat(:def)
      user.cg_v238_set_base_stat(:atk,dfn); user.cg_v238_set_base_stat(:def,atk)
      log("BASE_POWER_TRICK user=" + user.name.to_s + " atk=" + atk.to_s + "->" + user.cg_v238_base_stat(:atk).to_s + " def=" + dfn.to_s + "->" + user.cg_v238_base_stat(:def).to_s)
      show_text(user.name.to_s + "交換了攻擊與防禦！")
      return true
    end

    def self.apply_split(user,target,keys,label)
      return false if user == nil || target == nil
      result={}
      keys.each do |k|
        a=user.cg_v238_base_stat(k).to_i; b=target.cg_v238_base_stat(k).to_i
        avg=(a+b)/2
        user.cg_v238_set_base_stat(k,avg); target.cg_v238_set_base_stat(k,avg)
        result[k]=[a,b,avg]
      end
      log("BASE_SPLIT kind=" + label.to_s + " user=" + user.name.to_s + " target=" + target.name.to_s + " values=" + result.inspect)
      show_text(user.name.to_s + "與" + target.name.to_s + "平分了能力！")
      return true
    end

    def self.apply_speed_swap(user,target)
      return false if user == nil || target == nil
      a=user.cg_v238_base_stat(:spe); b=target.cg_v238_base_stat(:spe)
      user.cg_v238_set_base_stat(:spe,b); target.cg_v238_set_base_stat(:spe,a)
      log("BASE_SPEED_SWAP user=" + user.name.to_s + " target=" + target.name.to_s + " user=" + a.to_s + "->" + b.to_s + " target=" + b.to_s + "->" + a.to_s)
      show_text(user.name.to_s + "與" + target.name.to_s + "交換了速度！")
      return true
    end

    def self.major_status_ids
      ids=[ALBERT_CG::MOVE_EFFECT::STATE_POISON,ALBERT_CG::MOVE_EFFECT::STATE_PARALYSIS,
           ALBERT_CG::MOVE_EFFECT::STATE_SLEEP,ALBERT_CG::MOVE_EFFECT::STATE_FREEZE,
           ALBERT_CG::MOVE_EFFECT::STATE_BURN]
      ids.push(ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON) if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON)
      return ids
    end
    def self.apply_psycho_shift(user,target)
      return false if user == nil || target == nil
      sid=major_status_ids.find { |id| user.state?(id) }
      return false if sid == nil
      return false if ALBERT_CG::MOVE_EFFECT.has_primary_status?(target)
      if target.respond_to?(:state_resist?) && target.state_resist?(sid)
        return false
      end
      target.add_state(sid)
      return false unless target.state?(sid)
      user.remove_state(sid)
      if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON) && sid == ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON
        target.instance_variable_set(:@cg_bad_poison_count,1)
        user.instance_variable_set(:@cg_bad_poison_count,nil)
      end
      log("PSYCHO_SHIFT user=" + user.name.to_s + " target=" + target.name.to_s + " state=" + sid.to_s)
      show_text(user.name.to_s + "把異常狀態轉移給" + target.name.to_s + "！")
      return true
    end

    def self.apply_magnet_rise(user)
      return false if user == nil
      user.cg_v238_set_magnet_rise(MAGNET_RISE_TURNS)
      log("MAGNET_RISE user=" + user.name.to_s + " turns=" + user.cg_v238_magnet_rise_turns.to_s)
      show_text(user.name.to_s + "用電磁力浮了起來！")
      return true
    end

    def self.apply_defog(user,target)
      return false if target == nil || !defined?(ALBERT_CG::FIELD_V233)
      delta=target.cg_change_stat_stage(:evasion,-1)
      st=ALBERT_CG::FIELD_V233.state
      before_h={:ally=>st.hazards[:ally].dup,:enemy=>st.hazards[:enemy].dup}
      [:ally,:enemy].each do |side|
        st.hazards[side].keys.each { |k| st.hazards[side][k]=0 }
      end
      side=ALBERT_CG::FIELD_V233.side_key(target)
      cleared={}
      [:reflect,:light_screen,:aurora_veil,:safeguard,:mist].each do |k|
        cleared[k]=st.sides[side][k].to_i
        st.sides[side][k]=0
      end
      log("DEFOG user=" + user.name.to_s + " target=" + target.name.to_s + " evasion_delta=" + delta.to_s + " target_side=" + side.to_s + " hazards_before=" + before_h.inspect + " screens_cleared=" + cleared.inspect)
      show_text("濃霧散去，場上的障礙被清除了！")
      return true
    end

    def self.apply_court_change(user)
      return false unless defined?(ALBERT_CG::FIELD_V233)
      st=ALBERT_CG::FIELD_V233.state
      before={:sides=>{:ally=>st.sides[:ally].dup,:enemy=>st.sides[:enemy].dup},
              :hazards=>{:ally=>st.hazards[:ally].dup,:enemy=>st.hazards[:enemy].dup}}
      a_side=st.sides[:ally].dup; e_side=st.sides[:enemy].dup
      a_h=st.hazards[:ally].dup; e_h=st.hazards[:enemy].dup
      st.sides[:ally]=e_side; st.sides[:enemy]=a_side
      st.hazards[:ally]=e_h; st.hazards[:enemy]=a_h
      @court_change_snapshot={:before=>before,
        :after=>{:sides=>{:ally=>st.sides[:ally].dup,:enemy=>st.sides[:enemy].dup},
                 :hazards=>{:ally=>st.hazards[:ally].dup,:enemy=>st.hazards[:enemy].dup}}}
      log("COURT_CHANGE user=" + (user == nil ? "nil" : user.name.to_s) + " before=" + before.inspect + " after=" + @court_change_snapshot[:after].inspect)
      show_text("雙方的場地效果互換了！")
      return true
    end

    def self.apply_octolock(user,target)
      return false if user == nil || target == nil
      target.instance_variable_set(:@cg_v238_octolock_source,user)
      target.instance_variable_set(:@cg_v236_switch_lock,true)
      target.instance_variable_set(:@cg_v236_switch_lock_source,user)
      target.instance_variable_set(:@cg_v236_switch_lock_move,MOVE_OCTOLOCK)
      log("OCTOLOCK_SET user=" + user.name.to_s + " target=" + target.name.to_s)
      show_text(target.name.to_s + "被蛸固困住了！")
      return true
    end

    def self.release_octolock(target,reason="clear")
      return if target == nil
      src=target.instance_variable_get(:@cg_v238_octolock_source)
      return if src == nil
      target.instance_variable_set(:@cg_v238_octolock_source,nil)
      if target.instance_variable_get(:@cg_v236_switch_lock_move).to_i == MOVE_OCTOLOCK
        target.instance_variable_set(:@cg_v236_switch_lock,false)
        target.instance_variable_set(:@cg_v236_switch_lock_source,nil)
        target.instance_variable_set(:@cg_v236_switch_lock_move,nil)
      end
      log("OCTOLOCK_RELEASE target=" + target.name.to_s + " reason=" + reason.to_s) if active?
    end
    def self.release_octolocks_by_source(source)
      return if source == nil
      all=[]
      all += $game_party.members if $game_party != nil
      all += $game_troop.members if $game_troop != nil
      all.each do |b|
        release_octolock(b,"source_left") if b != nil && b.instance_variable_get(:@cg_v238_octolock_source) == source
      end
    end

    def self.tick_end_turn
      all=[]
      all += $game_party.members if $game_party != nil
      all += $game_troop.members if $game_troop != nil
      all.each do |b|
        next if b == nil
        b.cg_v238_tick_magnet_rise if b.respond_to?(:cg_v238_tick_magnet_rise)
        src=b.instance_variable_get(:@cg_v238_octolock_source)
        next if src == nil
        gone=src.dead?
        gone=true if src.respond_to?(:hidden) && src.hidden
        if gone
          release_octolock(b,"source_inactive")
          next
        end
        next if b.dead?
        d1=b.cg_change_stat_stage(:def,-1)
        d2=b.cg_change_stat_stage(:spd,-1)
        log("OCTOLOCK_TICK target=" + b.name.to_s + " def_delta=" + d1.to_s + " spd_delta=" + d2.to_s + " def=" + b.cg_stat_stage(:def).to_s + " spd=" + b.cg_stat_stage(:spd).to_s)
      end
    end

    def self.apply_unique(user,target,mid)
      case mid.to_i
      when MOVE_POWER_TRICK
        return apply_power_trick(user)
      when MOVE_POWER_SWAP
        return swap_stages(user,target,[:atk,:spa],:power_swap)
      when MOVE_GUARD_SWAP
        return swap_stages(user,target,[:def,:spd],:guard_swap)
      when MOVE_HEART_SWAP
        return swap_stages(user,target,STAGE_KEYS,:heart_swap)
      when MOVE_GUARD_SPLIT
        return apply_split(user,target,[:def,:spd],:guard_split)
      when MOVE_POWER_SPLIT
        return apply_split(user,target,[:atk,:spa],:power_split)
      when MOVE_SPEED_SWAP
        return apply_speed_swap(user,target)
      when MOVE_PSYCHO_SHIFT
        return apply_psycho_shift(user,target)
      when MOVE_MAGNET_RISE
        return apply_magnet_rise(user)
      when MOVE_DEFOG
        return apply_defog(user,target)
      when MOVE_COURT_CHANGE
        return apply_court_change(user)
      when MOVE_OCTOLOCK
        return apply_octolock(user,target)
      end
      return false
    rescue => e
      log("APPLY_ERROR move=" + mid.to_i.to_s + " " + e.class.to_s + ":" + e.message.to_s) if active?
      return false
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
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon UniqueE v2.3.8a AutoRegression",members)
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

    def self.clear_major_statuses(b)
      return if b == nil
      major_status_ids.each { |sid| b.remove_state(sid) if b.state?(sid) }
      b.instance_variable_set(:@cg_bad_poison_count,nil)
    end
    def self.prepare_round_preconditions
      a=test_allies; e=test_enemies
      (a+e).each do |b|
        next if b == nil
        b.cg_reset_stat_stages if b.respond_to?(:cg_reset_stat_stages)
        clear_major_statuses(b)
        b.cg_v238_clear_runtime if b.respond_to?(:cg_v238_clear_runtime)
      end
      if current_round == 1
        set_stage_exact(a[1],:atk,2); set_stage_exact(a[1],:spa,-1)
        set_stage_exact(e[0],:atk,-2); set_stage_exact(e[0],:spa,3)
        set_stage_exact(a[2],:def,2); set_stage_exact(a[2],:spd,-2)
        set_stage_exact(e[1],:def,-3); set_stage_exact(e[1],:spd,1)
        vals_a={:atk=>1,:def=>-1,:spa=>2,:spd=>0,:spe=>-2,:accuracy=>3,:evasion=>-3}
        vals_e={:atk=>-2,:def=>2,:spa=>-1,:spd=>3,:spe=>1,:accuracy=>-2,:evasion=>2}
        vals_a.each { |k,v| set_stage_exact(a[3],k,v) }
        vals_e.each { |k,v| set_stage_exact(e[2],k,v) }
        @r1_power_trick_before=[e[3].cg_v238_base_stat(:atk),e[3].cg_v238_base_stat(:def)]
      elsif current_round == 2
        @r2_guard_expected={}
        [:def,:spd].each { |k| @r2_guard_expected[k]=(a[1].cg_v238_base_stat(k)+e[0].cg_v238_base_stat(k))/2 }
        @r2_power_expected={}
        [:atk,:spa].each { |k| @r2_power_expected[k]=(a[2].cg_v238_base_stat(k)+e[1].cg_v238_base_stat(k))/2 }
        @r2_speed_before=[a[3].cg_v238_base_stat(:spe),e[2].cg_v238_base_stat(:spe)]
        e[3].add_state(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
        log("PSYCHO_SHIFT_SETUP user=" + e[3].name.to_s + " burn=" + e[3].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN).to_s)
      elsif current_round == 3
        if defined?(ALBERT_CG::FIELD_V233)
          st=ALBERT_CG::FIELD_V233.state
          st.sides[:ally]={:reflect=>3}
          st.sides[:enemy]={:light_screen=>4}
          st.hazards[:ally]={:spikes=>2,:toxic_spikes=>0,:stealth_rock=>0,:sticky_web=>0}
          st.hazards[:enemy]={:spikes=>0,:toxic_spikes=>0,:stealth_rock=>1,:sticky_web=>0}
        end
        set_stage_exact(e[0],:evasion,2)
        @r3_a1_hp_before=a[1].hp.to_i
        @court_change_snapshot=nil
        log("FIELD_SETUP ally_reflect=3 enemy_light_screen=4 ally_spikes=2 enemy_stealth_rock=1")
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
    def self.note_stat(ok); @stat_checks=@stat_checks.to_i+1 if ok; return ok; end
    def self.note_field(ok); @field_checks=@field_checks.to_i+1 if ok; return ok; end

    def self.finish_round_assertions
      round=current_round
      expected=EXPECTED_EXECUTION_TOKENS[round] || []
      actual=@actual || []
      assert(actual.size == 8,"Round" + round.to_s + " executes exactly 8 scripted battler actions actual=" + actual.size.to_s)
      assert(actual == expected,"Round" + round.to_s + " execution order matches deterministic plan expected=" + expected.inspect + " actual=" + actual.inspect)
      a=test_allies; e=test_enemies
      case round
      when 1
        ok=a[1].cg_stat_stage(:atk)==-2 && a[1].cg_stat_stage(:spa)==3 && e[0].cg_stat_stage(:atk)==2 && e[0].cg_stat_stage(:spa)==-1; note_stat(ok); assert(ok,"Power Swap exchanges ATK/SpA stages")
        ok=a[2].cg_stat_stage(:def)==-3 && a[2].cg_stat_stage(:spd)==1 && e[1].cg_stat_stage(:def)==2 && e[1].cg_stat_stage(:spd)==-2; note_stat(ok); assert(ok,"Guard Swap exchanges DEF/SpD stages")
        ok=STAGE_KEYS.all? { |k| a[3].cg_stat_stage(k)==({:atk=>-2,:def=>2,:spa=>-1,:spd=>3,:spe=>1,:accuracy=>-2,:evasion=>2}[k]) }; note_stat(ok); assert(ok,"Heart Swap gives A3 exact E2 seven-stage set")
        ok=STAGE_KEYS.all? { |k| e[2].cg_stat_stage(k)==({:atk=>1,:def=>-1,:spa=>2,:spd=>0,:spe=>-2,:accuracy=>3,:evasion=>-3}[k]) }; note_stat(ok); assert(ok,"Heart Swap gives E2 exact A3 seven-stage set")
        ok=e[3].cg_v238_base_stat(:atk)==@r1_power_trick_before[1] && e[3].cg_v238_base_stat(:def)==@r1_power_trick_before[0]; note_stat(ok); assert(ok,"Power Trick swaps Battle Base ATK/DEF")
        stage_expected=ALBERT_CG::MOVE_EFFECT.apply_stage(a[1].cg_v238_base_stat(:atk),a[1].cg_stat_stage(:atk))
        ok=a[1].cg_atk_stat.to_i==stage_expected.to_i; note_stat(ok); assert(ok,"Power Swap Stage feeds Actor final ATK getter expected=" + stage_expected.to_s + " actual=" + a[1].cg_atk_stat.to_i.to_s)
      when 2
        ok=[:def,:spd].all? { |k| a[1].cg_v238_base_stat(k)==@r2_guard_expected[k] && e[0].cg_v238_base_stat(k)==@r2_guard_expected[k] }; note_stat(ok); assert(ok,"Guard Split averages both DEF/SpD base stats expected=" + @r2_guard_expected.inspect)
        ok=[:atk,:spa].all? { |k| a[2].cg_v238_base_stat(k)==@r2_power_expected[k] && e[1].cg_v238_base_stat(k)==@r2_power_expected[k] }; note_stat(ok); assert(ok,"Power Split averages both ATK/SpA base stats expected=" + @r2_power_expected.inspect)
        ok=a[3].cg_v238_base_stat(:spe)==@r2_speed_before[1] && e[2].cg_v238_base_stat(:spe)==@r2_speed_before[0]; note_stat(ok); assert(ok,"Speed Swap exchanges Battle Base SPE")
        ok=a[0].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN) && !e[3].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN); note_stat(ok); assert(ok,"Psycho Shift transfers Burn from E3 to human A0")
        ok=a[1].cg_def_stat.to_i==@r2_guard_expected[:def].to_i && a[1].cg_spd.to_i==@r2_guard_expected[:spd].to_i; note_stat(ok); assert(ok,"Guard Split Battle Base override feeds final DEF/SpD getters expected=" + @r2_guard_expected.inspect + " actual={:def=>" + a[1].cg_def_stat.to_i.to_s + ", :spd=>" + a[1].cg_spd.to_i.to_s + "}")
        ok=a[2].cg_atk_stat.to_i==@r2_power_expected[:atk].to_i && a[2].cg_spa.to_i==@r2_power_expected[:spa].to_i; note_stat(ok); assert(ok,"Power Split Battle Base override feeds final ATK/SpA getters expected=" + @r2_power_expected.inspect + " actual={:atk=>" + a[2].cg_atk_stat.to_i.to_s + ", :spa=>" + a[2].cg_spa.to_i.to_s + "}")
        ok=a[3].cg_spe.to_i==@r2_speed_before[1].to_i && e[2].cg_spe.to_i==@r2_speed_before[0].to_i; note_stat(ok); assert(ok,"Speed Swap Battle Base override feeds final SPE getters user=" + a[3].cg_spe.to_i.to_s + " target=" + e[2].cg_spe.to_i.to_s)
        log("FINAL_STAT_BRIDGE guard={:def=>" + a[1].cg_def_stat.to_i.to_s + ",:spd=>" + a[1].cg_spd.to_i.to_s + "} power={:atk=>" + a[2].cg_atk_stat.to_i.to_s + ",:spa=>" + a[2].cg_spa.to_i.to_s + "} speed={:user=>" + a[3].cg_spe.to_i.to_s + ",:target=>" + e[2].cg_spe.to_i.to_s + "}")
      when 3
        if defined?(ALBERT_CG::FIELD_V233)
          st=ALBERT_CG::FIELD_V233.state
          snap=@court_change_snapshot
          ok=snap != nil && snap[:after][:sides][:ally][:light_screen].to_i==4 && snap[:after][:sides][:enemy][:reflect].to_i==3; note_field(ok); assert(ok,"Court Change swaps side screens before Defog")
          ok=snap != nil && snap[:after][:hazards][:ally][:stealth_rock].to_i==1 && snap[:after][:hazards][:enemy][:spikes].to_i==2; note_field(ok); assert(ok,"Court Change swaps entry hazards before Defog")
          ok=st.hazards[:ally].values.all? { |v| v.to_i==0 } && st.hazards[:enemy].values.all? { |v| v.to_i==0 }; note_field(ok); assert(ok,"Defog clears hazards on both sides")
          ok=st.sides[:enemy][:reflect].to_i==0 && st.sides[:ally][:light_screen].to_i==4; note_field(ok); assert(ok,"Defog clears target-side screen without deleting opposite screen")
        end
        ok=e[0].cg_stat_stage(:evasion)==1; note_field(ok); assert(ok,"Defog lowers target Evasion by exactly 1")
        ok=a[1].cg_v238_magnet_rise? && a[1].cg_pokemon_type_rate_percent(:ground).to_i==0; note_field(ok); assert(ok,"Magnet Rise makes A1 Ground rate 0")
        ok=a[1].hp.to_i==@r3_a1_hp_before.to_i; note_field(ok); assert(ok,"Real Mud-Slap deals zero HP damage into Magnet Rise before=" + @r3_a1_hp_before.to_s + " after=" + a[1].hp.to_i.to_s)
        ok=a[0].instance_variable_get(:@cg_v238_octolock_source)==e[3] && a[0].cg_v236_switch_locked? && a[0].cg_stat_stage(:def)==-1 && a[0].cg_stat_stage(:spd)==-1; note_field(ok); assert(ok,"Octolock traps target and applies end-turn DEF/SpD -1")
      end
      log("ROUND " + round.to_s + " END")
      @round_index=@round_index.to_i+1
    end

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted=true
      install_skill_scopes; apply_test_grid
      assert(current_troop_id==TEST_TROOP_ID,"Scene_Battle uses Unique E test troop actual=" + current_troop_id.to_s)
      assert(test_allies.size==4,"Unique E ally count=4 actual=" + test_allies.size.to_s)
      assert(test_enemies.size==4,"Unique E enemy count=4 actual=" + test_enemies.size.to_s)
      assert(test_allies.collect { |b| b.actor? ? b.id : 0 } == [1,236,102,193],"Unique E exact ally roster")
      assert(test_enemies.collect { |b| b.enemy_id } == [605,608,664,667],"Unique E exact enemy roster")
    end
    def self.finish_suite
      missing=HANDLED_MOVE_IDS.select { |mid| @apply_counts[mid].to_i <= 0 }
      assert(missing.empty?,"All 12 Unique Batch E moves executed missing=" + missing.inspect)
      log("------------------------------------------------------------")
      log(@failures.to_i <= 0 ? "RESULT=PASS" : "RESULT=FAIL")
      log("SUMMARY rounds=3 failures=" + @failures.to_i.to_s + " unique_e_moves=" + (HANDLED_MOVE_IDS.size-missing.size).to_s + "/12 stat_checks=" + @stat_checks.to_i.to_s + " field_checks=" + @field_checks.to_i.to_s)
      if @failure_lines != nil
        @failure_lines.each_with_index { |x,i| log("FAILURE " + (i+1).to_s + " " + x.to_s) }
      end
      @active=false
      return @failures.to_i <= 0
    end
    def self.start_auto_test
      return false if active? || $game_temp.in_battle
      install_skill_scopes; prepare_test_party; make_test_troop
      ALBERT_CG::FIELD_V233.reset if defined?(ALBERT_CG::FIELD_V233) && ALBERT_CG::FIELD_V233.respond_to?(:reset)
      reset_log
      @active=true; @round_index=0; @failures=0; @failure_lines=[]; @apply_counts={}; @stat_checks=0; @field_checks=0; @boot_asserted=false
      log("AUTO_TEST_START troop=" + TEST_TROOP_ID.to_s)
      if defined?(ALBERT_CG) && ALBERT_CG.respond_to?(:start_demo_battle)
        ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
      else
        $game_troop.setup(TEST_TROOP_ID); $game_temp.in_battle=true; $game_temp.battle_troop_id=TEST_TROOP_ID; $scene=Scene_Battle.new
      end
      return true
    rescue => e
      log("AUTO_TEST_START_ERROR " + e.class.to_s + ":" + e.message.to_s)
      @active=false
      return false
    end
  end
end

#==============================================================================
# ■ Game_Battler：Battle-only Base Stat Override / Magnet Rise / Unique Effects
#==============================================================================
class Game_Battler
  def cg_v238_stat_override_table
    @cg_v238_base_stat_override={} if @cg_v238_base_stat_override == nil
    return @cg_v238_base_stat_override
  end
  def cg_v238_set_base_stat(key,value)
    cg_v238_stat_override_table[key.to_sym]=[value.to_i,1].max
    return cg_v238_stat_override_table[key.to_sym]
  end
  def cg_v238_base_stat(key)
    key=key.to_sym
    table=cg_v238_stat_override_table
    return table[key].to_i if table.has_key?(key)
    # v2.3.8a：一定透過 dynamic raw hook，讓 Game_Actor / Game_Enemy
    # 可以提供自己的真正六維 Base Stat；不要固定綁 Game_Battler 舊 alias。
    case key
    when :atk; return [cg_move_v230_atk_stat.to_i,1].max
    when :def; return [cg_move_v230_def_stat.to_i,1].max
    when :spa; return [cg_move_v230_spa.to_i,1].max
    when :spd; return [cg_move_v230_spd.to_i,1].max
    when :spe; return [cg_move_v230_spe.to_i,1].max
    end
    return 1
  end
  def cg_v238_clear_stat_identity; @cg_v238_base_stat_override=nil; end
  def cg_v238_set_magnet_rise(turns); @cg_v238_magnet_rise_turns=[turns.to_i,0].max; end
  def cg_v238_magnet_rise_turns; return @cg_v238_magnet_rise_turns.to_i; end
  def cg_v238_magnet_rise?
    return false if @cg_v238_magnet_rise_turns.to_i <= 0
    if defined?(ALBERT_CG::FIELD_V233) && ALBERT_CG::FIELD_V233.global_effect?(:gravity)
      return false
    end
    return true
  rescue
    return @cg_v238_magnet_rise_turns.to_i > 0
  end
  def cg_v238_tick_magnet_rise
    return if @cg_v238_magnet_rise_turns.to_i <= 0
    @cg_v238_magnet_rise_turns=[@cg_v238_magnet_rise_turns.to_i-1,0].max
  end
  def cg_v238_clear_runtime
    cg_v238_clear_stat_identity
    @cg_v238_magnet_rise_turns=0
    ALBERT_CG::UNIQUE_E_V238.release_octolock(self,"target_clear") if defined?(ALBERT_CG::UNIQUE_E_V238)
  end

  alias cg_v238_raw_atk_base cg_move_v230_atk_stat
  def cg_move_v230_atk_stat
    t=@cg_v238_base_stat_override
    return [t[:atk].to_i,1].max if t != nil && t.has_key?(:atk)
    return cg_v238_raw_atk_base
  end
  alias cg_v238_raw_def_base cg_move_v230_def_stat
  def cg_move_v230_def_stat
    t=@cg_v238_base_stat_override
    return [t[:def].to_i,1].max if t != nil && t.has_key?(:def)
    return cg_v238_raw_def_base
  end
  alias cg_v238_raw_spa_base cg_move_v230_spa
  def cg_move_v230_spa
    t=@cg_v238_base_stat_override
    return [t[:spa].to_i,1].max if t != nil && t.has_key?(:spa)
    return cg_v238_raw_spa_base
  end
  alias cg_v238_raw_spd_base cg_move_v230_spd
  def cg_move_v230_spd
    t=@cg_v238_base_stat_override
    return [t[:spd].to_i,1].max if t != nil && t.has_key?(:spd)
    return cg_v238_raw_spd_base
  end
  alias cg_v238_raw_spe_base cg_move_v230_spe
  def cg_move_v230_spe
    t=@cg_v238_base_stat_override
    return [t[:spe].to_i,1].max if t != nil && t.has_key?(:spe)
    return cg_v238_raw_spe_base
  end

  alias cg_v238_type_rate cg_pokemon_type_rate_percent
  def cg_pokemon_type_rate_percent(attack_type)
    key=defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_key(attack_type) : attack_type
    return 0 if key == :ground && cg_v238_magnet_rise?
    return cg_v238_type_rate(attack_type)
  end

  alias cg_v238_remove_states_battle remove_states_battle
  def remove_states_battle
    cg_v238_remove_states_battle
    cg_v238_clear_runtime
  end

  alias cg_v238_skill_effect skill_effect
  def skill_effect(user,skill)
    mid=skill == nil ? 0 : ALBERT_CG::MOVE_EFFECT.move_id(skill)
    unless defined?(ALBERT_CG::UNIQUE_E_V238) && ALBERT_CG::UNIQUE_E_V238.handled?(mid)
      return cg_v238_skill_effect(user,skill)
    end
    clear_action_results
    ok=ALBERT_CG::UNIQUE_E_V238.apply_unique(user,self,mid)
    if ok
      ALBERT_CG::UNIQUE_E_V238.mark_apply(mid)
    else
      @skipped=true if instance_variable_defined?(:@skipped)
      ALBERT_CG::UNIQUE_E_V238.log("APPLY_FAIL move=" + mid.to_s + " user=" + (user == nil ? "nil" : user.name.to_s) + " target=" + name.to_s) if ALBERT_CG::UNIQUE_E_V238.active?
    end
    return
  end
end

#==============================================================================
# ■ v2.3.8a Final Stat Getter Bridge
#------------------------------------------------------------------------------
# v2.1.0 的 Game_Actor / Game_Enemy 自己有 cg_* 六維 getter，會優先於
# Game_Battler 的 v2.3.0 Stage / v2.3.3 Field wrapper。這裡保存 subclass 的
# Native Base，再把 raw hook 供 Game_Battler wrapper 使用；最終 getter 用 super。
#==============================================================================
class Game_Actor < Game_Battler
  alias cg_v238a_native_atk_stat cg_atk_stat
  alias cg_v238a_native_def_stat cg_def_stat
  alias cg_v238a_native_spa_stat cg_spa
  alias cg_v238a_native_spd_stat cg_spd
  alias cg_v238a_native_spe_stat cg_spe

  def cg_move_v230_atk_stat
    t=@cg_v238_base_stat_override
    return [t[:atk].to_i,1].max if t != nil && t.has_key?(:atk)
    return [cg_v238a_native_atk_stat.to_i,1].max
  end
  def cg_move_v230_def_stat
    t=@cg_v238_base_stat_override
    return [t[:def].to_i,1].max if t != nil && t.has_key?(:def)
    return [cg_v238a_native_def_stat.to_i,1].max
  end
  def cg_move_v230_spa
    t=@cg_v238_base_stat_override
    return [t[:spa].to_i,1].max if t != nil && t.has_key?(:spa)
    return [cg_v238a_native_spa_stat.to_i,1].max
  end
  def cg_move_v230_spd
    t=@cg_v238_base_stat_override
    return [t[:spd].to_i,1].max if t != nil && t.has_key?(:spd)
    return [cg_v238a_native_spd_stat.to_i,1].max
  end
  def cg_move_v230_spe
    t=@cg_v238_base_stat_override
    return [t[:spe].to_i,1].max if t != nil && t.has_key?(:spe)
    return [cg_v238a_native_spe_stat.to_i,1].max
  end

  # super 會進入 Game_Battler 現行 wrapper chain：
  # Stage -> Burn/Paralysis -> Wonder Room/Sandstorm 等 Field 修正。
  def cg_atk_stat; return super; end
  def cg_def_stat; return super; end
  def cg_spa; return super; end
  def cg_spd; return super; end
  def cg_spe; return super; end
end

class Game_Enemy < Game_Battler
  alias cg_v238a_native_atk_stat cg_atk_stat
  alias cg_v238a_native_def_stat cg_def_stat
  alias cg_v238a_native_spa_stat cg_spa
  alias cg_v238a_native_spd_stat cg_spd
  alias cg_v238a_native_spe_stat cg_spe

  def cg_move_v230_atk_stat
    t=@cg_v238_base_stat_override
    return [t[:atk].to_i,1].max if t != nil && t.has_key?(:atk)
    return [cg_v238a_native_atk_stat.to_i,1].max
  end
  def cg_move_v230_def_stat
    t=@cg_v238_base_stat_override
    return [t[:def].to_i,1].max if t != nil && t.has_key?(:def)
    return [cg_v238a_native_def_stat.to_i,1].max
  end
  def cg_move_v230_spa
    t=@cg_v238_base_stat_override
    return [t[:spa].to_i,1].max if t != nil && t.has_key?(:spa)
    return [cg_v238a_native_spa_stat.to_i,1].max
  end
  def cg_move_v230_spd
    t=@cg_v238_base_stat_override
    return [t[:spd].to_i,1].max if t != nil && t.has_key?(:spd)
    return [cg_v238a_native_spd_stat.to_i,1].max
  end
  def cg_move_v230_spe
    t=@cg_v238_base_stat_override
    return [t[:spe].to_i,1].max if t != nil && t.has_key?(:spe)
    return [cg_v238a_native_spe_stat.to_i,1].max
  end

  def cg_atk_stat; return super; end
  def cg_def_stat; return super; end
  def cg_spa; return super; end
  def cg_spd; return super; end
  def cg_spe; return super; end
end

#==============================================================================
# ■ Field grounded?：Magnet Rise 正式接入 Terrain/Hazard Ground 判定
#==============================================================================
if defined?(ALBERT_CG::FIELD_V233)
  module ALBERT_CG
    module FIELD_V233
      class << self
        alias cg_v238_grounded_without_magnet grounded?
        def grounded?(battler)
          return true if global_effect?(:gravity)
          if battler != nil && battler.respond_to?(:cg_v238_magnet_rise?) && battler.cg_v238_magnet_rise?
            return false
          end
          return cg_v238_grounded_without_magnet(battler)
        end
      end
    end
  end
end

#==============================================================================
# ■ Force Switch：換出清除 Batch E Runtime，並解除以該 Battler 為來源的 Octolock
#==============================================================================
if defined?(ALBERT_CG::FORCE_SWITCH_V235)
  module ALBERT_CG
    module FORCE_SWITCH_V235
      class << self
        alias cg_v238_clear_switch_out_volatile clear_switch_out_volatile
        def clear_switch_out_volatile(battler)
          ALBERT_CG::UNIQUE_E_V238.release_octolocks_by_source(battler) if battler != nil
          cg_v238_clear_switch_out_volatile(battler)
          battler.cg_v238_clear_runtime if battler != nil && battler.respond_to?(:cg_v238_clear_runtime)
        end
      end
    end
  end
end

#==============================================================================
# ■ Regression deterministic speed / enemy action
#==============================================================================
class Game_Battler
  alias cg_v238_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    override=@cg_priority_test_speed_override
    if defined?(ALBERT_CG::UNIQUE_E_V238) && ALBERT_CG::UNIQUE_E_V238.active? && override != nil
      return override.to_i
    end
    return cg_v238_priority_base_speed
  end
end
class Game_Enemy < Game_Battler
  alias cg_v238_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::UNIQUE_E_V238) && ALBERT_CG::UNIQUE_E_V238.active?
      forced=ALBERT_CG::UNIQUE_E_V238.forced_enemy_action(self)
      if forced != nil
        cg_assign_action(forced) if respond_to?(:cg_assign_action)
        @action=forced unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v238_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle：3 回合 deterministic Regression + Octolock/Magnet turn tick
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v238_execute_action execute_action
  def execute_action
    ALBERT_CG::UNIQUE_E_V238.record_execution(@active_battler) if defined?(ALBERT_CG::UNIQUE_E_V238) && ALBERT_CG::UNIQUE_E_V238.active?
    cg_v238_execute_action
  end
  alias cg_v238_turn_end turn_end
  def turn_end
    ALBERT_CG::UNIQUE_E_V238.tick_end_turn if defined?(ALBERT_CG::UNIQUE_E_V238)
    ALBERT_CG::UNIQUE_E_V238.finish_round_assertions if defined?(ALBERT_CG::UNIQUE_E_V238) && ALBERT_CG::UNIQUE_E_V238.active?
    cg_v238_turn_end
  end
  alias cg_v238_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::UNIQUE_E_V238) && ALBERT_CG::UNIQUE_E_V238.active?
      return cg_v238_start_party_command
    end
    cg_v238_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::UNIQUE_E_V238.assert_bootstrap_once
    if ALBERT_CG::UNIQUE_E_V238.finished?
      ALBERT_CG::UNIQUE_E_V238.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::UNIQUE_E_V238.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle 重建 Party 後重套 Batch E 測試資料
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v238_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result=cg_v238_bootstrap_demo_party
      if defined?(ALBERT_CG::UNIQUE_E_V238) && ALBERT_CG::UNIQUE_E_V238.active?
        ALBERT_CG::UNIQUE_E_V238::TEST_ALLIES.each { |cfg| ALBERT_CG::UNIQUE_E_V238.configure_actor(cfg) }
        human=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::UNIQUE_E_V238::TEST_LEVEL,false)
          human.recover_all if human.respond_to?(:recover_all)
          human.cg_v238_clear_runtime if human.respond_to?(:cg_v238_clear_runtime)
        end
        ALBERT_CG::UNIQUE_E_V238.install_skill_scopes
      end
      return result
    end
  end
end

#==============================================================================
# ■ Scene_Title：Move Stub 建立後校正 Unique E Scope
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_v238_load_database load_database
  def load_database
    cg_v238_load_database
    ALBERT_CG::UNIQUE_E_V238.install_skill_scopes
  end
  alias cg_v238_load_bt_database load_bt_database
  def load_bt_database
    cg_v238_load_bt_database
    ALBERT_CG::UNIQUE_E_V238.install_skill_scopes
  end
end

#==============================================================================
# ■ F11：v2.3.8a 成為唯一最新版 AutoRegression
#==============================================================================
if defined?(ALBERT_CG::UNIQUE_D_V237)
  module ALBERT_CG
    module UNIQUE_D_V237
      def self.f11_trigger?; return false; end
    end
  end
end
class Scene_Map < Scene_Base
  alias cg_v238_scene_map_update update
  def update
    cg_v238_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::UNIQUE_E_V238.f11_trigger?
      Sound.play_decision
      ALBERT_CG::UNIQUE_E_V238.start_auto_test
    end
  end
end

#==============================================================================
# ■ Coverage：12 個 Unique Pending 轉為 V238_UNIQUE_E_HANDLED
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    class << self
      alias cg_v238_coverage_v231 coverage_v231
      def coverage_v231(move_id)
        return "V238_UNIQUE_E_HANDLED" if ALBERT_CG::UNIQUE_E_V238.handled?(move_id)
        return cg_v238_coverage_v231(move_id)
      end
    end
  end
end
