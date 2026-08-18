# RMVX_SCRIPT_INDEX: 204
# RMVX_SCRIPT_ID: 1153467382
# RMVX_SCRIPT_NAME: CG Pokemon Unique Move Batch H v2.4.1b
# RMVX_SOURCE_SHA256: 9ca73874aeb06db3a4ed06e770bda978e11178eb36d258d3d21b909656b4e7e6

#==============================================================================
# ■ CG Pokemon Unique Move Batch H v2.4.1b
#------------------------------------------------------------------------------
# 【用途】
#  接續 v2.4.0a 已封版的 Call / Memory / Restriction Core，處理 6 個共享
#  「反射／搶奪／行動佇列重排／即時追加行動／當回合屬性改寫」底層的 Unique Move：
#    277 Magic Coat／魔法反射
#    289 Snatch／搶奪
#    495 After You／您先請
#    511 Quash／延後
#    582 Electrify／輸電
#    689 Instruct／號令
#
# 【v2.4.1b 修正重點】
#  v2.4.1a 已證明 Player Action Queue、Magic Coat、Snatch、After You、Quash、
#  Instruct 的正式 Runtime 均能進入真正 Scene_Battle；實機只剩兩類問題：
#
#  A. Quash Regression 隔離：
#     R1 Magic Coat 成功把 Taunt 反射給 E0 怪力，Taunt 會跨回合持續。舊 R2 又讓 E0
#     使用 Status Move Splash(150)，所以 Quash 雖已把 E0 pending entry 成功移到隊尾，
#     E0 到隊尾後仍被 TAUNT_BLOCK，造成「Quash target actually acts last」假失敗。
#     本版 R2 改讓 E0 使用 damaging Tackle(33)，保留 R1 Taunt 真實持續性，同時讓
#     Quash 能獨立驗證「真的移到最後且真的執行」。正式 Quash Core 不變。
#
#  B. Electrify Type Authority：
#     v2.4.1a 把 temporary type override 寫在 RPG::BaseItem#cg_pokemon_type_id，
#     但 v2.3.3 Field Core 已在子類 RPG::UsableItem 定義自己的 cg_pokemon_type_id
#     （Ion Deluge authority）。RPG::Skill 繼承 RPG::UsableItem，因此 Ruby method lookup
#     會先命中子類方法，BaseItem override 永遠沒有機會執行。結果 LOG 雖有
#     ELECTRIFY_APPLY，真正 Damage Breakdown 仍讀到 Flamethrower 的 Fire type=13。
#     本版把 temporary override 掛在真正權威的 RPG::UsableItem，並在該層先讀
#     @cg_v241_temp_type_override，再 fallback 到 Field Core alias chain。如此 STAB、
#     Type Chart、Field、Damage Breakdown 都會看到同一個 Electric type；Action ensure
#     後仍立即清除，不污染 $data_skills。
#
#  v2.4.1a 的 Player Action Queue Fix 仍完整保留：Regression 將 Actor action 寫入
#  cg_round_actions + cg_assign_action，且每回合 audit 真正 @action_battlers 的 4+4 entries。
#
# 【主要設定項】
#  TEST_TROOP_ID = 688
#  TEST_LEVEL = 40
#  MAGIC_COAT_BLACKLIST：不允許被 Magic Coat 反射的控制招式。
#  SNATCH_BLACKLIST：不允許被 Snatch 搶奪的遞迴／呼叫類招式。
#  INSTRUCT_BLACKLIST：不允許 Instruct 再次呼叫的遞迴／呼叫類招式。
#
# 【機制規則】
#  1. Magic Coat：使用者本回合取得 reflect marker。對手之後使用「單體敵方、Status、
#     非 blacklist」Move 指向該使用者時，在 Game_BattleAction#make_targets 的真正目標
#     解決層改回攻擊者本人。Action 仍是原攻擊者的 Action，因此 Taunt / Thunder Wave 等
#     原技能自己的 Effect Core、動畫與狀態流程照常工作，只是目標被反射。
#  2. Snatch：使用者本回合取得 snatch marker。對手之後使用「自身、Status、非 blacklist」
#     Move 時，原 Action 在 Scene_Battle 執行層取消，並把同一 Move 以新的 ActionEntry
#     插到佇列最前方，由 Snatch 使用者立即真正施放。這樣技能 FX、PMD Motion、Stage Core
#     都走原 Move，不用手動複製效果。
#  3. After You：本次技能演出完成後，把指定友軍「尚未執行的第一個 ActionEntry」移到
#     @action_battlers 最前方；若目標已經行動完畢則不建立額外行動。
#  4. Quash：本次技能演出完成後，把指定敵軍「尚未執行的第一個 ActionEntry」移到
#     @action_battlers 最後方；不建立額外行動。
#  5. Electrify：目標下一個真正執行的 Skill 在本次 Action 期間暫時把 Pokémon Type
#     改為 Electric。透過 RPG::UsableItem#cg_pokemon_type_id 的 per-action temporary override
#     讓 STAB / Type Chart / Damage Breakdown 都讀到 Electric；ensure 後立即清除，不改資料庫。
#  6. Instruct：指定友軍最近真正執行的 Move 若合法，建立一個新的 ActionEntry 插到佇列
#     最前方，立即再執行一次。會記住該 battler 最近一次 Action 的 target_index，讓重複行動
#     優先沿用同一目標；遞迴／呼叫類 Move 由 blacklist 阻止。
#
# 【可調參數】
#  MAGIC_COAT_BLACKLIST、SNATCH_BLACKLIST、INSTRUCT_BLACKLIST。
#  若未來增加更多特殊 Move，只需擴充 blacklist，不必改 Action Queue 核心。
#
# 【事件／腳本呼叫方式】
#  正常遊戲不需事件呼叫。Debug 可用：
#    battler.cg_v241_magic_coat?
#    battler.cg_v241_snatch?
#    battler.cg_v241_electrify?
#    ALBERT_CG::UNIQUE_H_V241.start_auto_test
#
# 【實際範例】
#  Magic Coat：A1 先使用 Magic Coat，E0 對 A1 使用 Taunt，make_targets 會改成 [E0]，
#    LOG：MAGIC_COAT_REFLECT attacker=E0 move=269 reflector=A1。
#  Snatch：A2 先使用 Snatch，E1 使用 Swords Dance，E1 Action 取消並立刻插入 A2 的
#    Swords Dance ActionEntry，LOG：SNATCH_TRIGGER thief=A2 source=E1 move=14。
#  After You：A1 使用後，把 A3 pending entry 移到最前，A3 立即成為下一位行動者。
#  Quash：A2 使用後，把 E0 pending entry 移到隊尾。
#  Electrify：A2 對 E0 使用後，E0 Flamethrower(53) 本次 type_id 讀 Electric。
#  Instruct：A1 對剛使用 Tackle(33) 的 A3 使用後，A3 立即再執行一次 Tackle。
#
# 【AutoRegression】
#  F11 執行 4 回合真正 Scene_Battle：
#   R1：Magic Coat 反射 Taunt；Snatch 搶奪 Swords Dance 並讓搶奪者真正 ATK +2。
#   R2：After You 把慢速友軍移到下一位；Quash 把指定敵軍延到隊尾。
#   R3：Instruct 讓已行動友軍立即多執行一次 Tackle；Electrify 讓 Flamethrower 的
#       真正 Damage Breakdown type_id 變成 Electric。
#   R4：確認 round flags / Electrify temporary override 全部清除，Flamethrower 恢復 Fire。
#  成功標準：
#    RESULT=PASS
#    SUMMARY rounds=4 failures=0 unique_h_moves=6/6 reflection_checks=5 queue_checks=9
#
# 【相容與邊界】
#  RPG Maker VX / RGSS2 / Tankentai SBS + PMD Native。
#  本頁只處理 Move Logic / Action Queue，不修改 PMD Motion 2.0 Renderer。
#  F11 仍只保留最新版 AutoRegression；v2.4.0a 的 F11 會被本頁停用。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonUniqueMoveBatchH"] = "2.4.1b"

module ALBERT_CG
  module UNIQUE_H_V241
    VERSION = "2.4.1b"
    MOVE_MAGIC_COAT = 277
    MOVE_SNATCH     = 289
    MOVE_AFTER_YOU  = 495
    MOVE_QUASH      = 511
    MOVE_ELECTRIFY  = 582
    MOVE_INSTRUCT   = 689
    HANDLED_MOVE_IDS = [MOVE_MAGIC_COAT, MOVE_SNATCH, MOVE_AFTER_YOU,
                        MOVE_QUASH, MOVE_ELECTRIFY, MOVE_INSTRUCT]

    TEST_TROOP_ID = 688
    TEST_LEVEL = 40
    VK_F11 = 0x7A

    MAGIC_COAT_BLACKLIST = [277,289,495,511,582,689]
    SNATCH_BLACKLIST = [102,118,119,166,214,267,274,277,289,383,689]
    INSTRUCT_BLACKLIST = [102,118,119,166,214,267,274,383,689]

    TEST_ALLIES = [
      {:dex=>26,:level=>40,:ability=>9,  :moves=>[277,689,150,33]},
      {:dex=>3, :level=>40,:ability=>65, :moves=>[289,511,582,150]},
      {:dex=>94,:level=>40,:ability=>130,:moves=>[495,33,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>68,:level=>40,:ability=>62,:moves=>[269,33,53,150]},
      {:dex=>6, :level=>40,:ability=>66,:moves=>[14,150,150,150]},
      {:dex=>9, :level=>40,:ability=>67,:moves=>[150,150,150,150]},
      {:dex=>65,:level=>40,:ability=>28,:moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"MAGIC_COAT_AND_SNATCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>277,:target=>1},
          {:kind=>:move,:move_id=>289,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>3},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>269,:target=>1},
          {:kind=>:move,:move_id=>14,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
      {
        :name=>"AFTER_YOU_AND_QUASH_QUEUE",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>495,:target=>3},
          {:kind=>:move,:move_id=>511,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>3},
        ],
        :enemies=>[
          # E0 在 R1 已被 Magic Coat 反射 Taunt；此處用 damaging Tackle 避免
          # Taunt 合法地阻止 Splash，讓 Quash 的 queue-tail 行為獨立驗證。
          {:kind=>:move,:move_id=>33,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
      {
        :name=>"INSTRUCT_AND_ELECTRIFY",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>689,:target=>3},
          {:kind=>:move,:move_id=>582,:target=>0},
          {:kind=>:move,:move_id=>33,:target=>1},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>53,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
      {
        :name=>"ROUND_FLAG_AND_TYPE_OVERRIDE_CLEAR",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>3},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>53,:target=>1},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
    ]

    TEST_SPEEDS = {
      :r1=>[150,140,130,120,110,100,90,80],
      :r2=>[150,140,130,40,120,110,100,90],
      :r3=>[150,130,120,140,110,100,90,80],
      :r4=>[150,140,130,120,110,100,90,80],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M277","A2:M289","A3:M150","E0:M269","E1:M14:SNATCHED","A2:M14:STOLEN","E2:M150","E3:M150"],
      2=>["A0:Guard","A1:M495","A3:M150","A2:M511","E1:M150","E2:M150","E3:M150","E0:M33"],
      3=>["A0:Guard","A3:M33","A1:M689","A3:M33:INSTRUCT","A2:M582","E0:M53:ELECTRIC","E1:M150","E2:M150","E3:M150"],
      4=>["A0:Guard","A1:M150","A2:M150","A3:M150","E0:M53","E1:M150","E2:M150","E3:M150"],
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
    def self.log_path; return File.join(project_root,"Pokemon_UniqueH_AutoTest_v2_4_1b.log"); end
    def self.latest_log_path; return File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab")
      File.open(path,mode) { |f| f.write(text.to_s + "\r\n") }
      return true
    rescue
      return false
    end
    def self.important_line?(line)
      return true if line.index("AUTO_TEST_START") == 0 || line.index("ASSERT ") == 0
      return true if line.index("MAGIC_COAT_") == 0 || line.index("SNATCH_") == 0
      return true if line.index("AFTER_YOU_") == 0 || line.index("QUASH_") == 0
      return true if line.index("ELECTRIFY_") == 0 || line.index("INSTRUCT_") == 0
      return true if line.index("RESULT=") == 0 || line.index("SUMMARY ") == 0
      return false
    end
    def self.log(text)
      line=text.to_s
      write_line(log_path,line)
      write_line(latest_log_path,line) if important_line?(line)
      if defined?(ALBERT_CG::PMD_INIT_TRACE) && ALBERT_CG::PMD_INIT_TRACE.respond_to?(:log)
        ALBERT_CG::PMD_INIT_TRACE.log("[UNIQUE_H_AUTOTEST] " + line) if active? && important_line?(line)
      end
    rescue
    end
    def self.reset_log
      header=[
        "CG POKEMON UNIQUE MOVE H AUTO REGRESSION v2.4.1b",
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        "RULE=Actual Scene_Battle; 6 reflection/action-queue Unique Moves",
        "AUTOTEST_LOG_PATH="+log_path,
        "AUTOTEST_LATEST_PATH="+latest_log_path,
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
    def self.move_id_from_action(action)
      return 0 if action == nil || !action.skill?
      return ALBERT_CG::MOVE_EFFECT.move_id(action.skill).to_i
    rescue
      return 0
    end
    def self.move_status?(mid)
      row=master == nil ? nil : master.move(mid.to_i)
      return row != nil && row[7] == :status
    rescue
      return false
    end
    def self.mark_apply(mid)
      @apply_counts={} if @apply_counts == nil
      id=mid.to_i
      @apply_counts[id]=@apply_counts[id].to_i + 1
      log("APPLY move="+id.to_s+":"+(master==nil ? "" : master.move_name(id).to_s)+" count="+@apply_counts[id].to_s)
    end
    def self.apply_counts; @apply_counts={} if @apply_counts == nil; return @apply_counts; end

    def self.magic_coat_reflectable?(action)
      return false if action == nil || !action.skill?
      mid=move_id_from_action(action)
      return false if mid <= 0 || MAGIC_COAT_BLACKLIST.include?(mid)
      skill=action.skill
      return false if skill == nil || !move_status?(mid)
      return false unless skill.scope.to_i == 1
      return true
    rescue
      return false
    end
    def self.note_magic_reflect(attacker,mid,reflector)
      @magic_reflects=@magic_reflects.to_i+1
      log("MAGIC_COAT_REFLECT attacker="+battler_token(attacker)+" move="+mid.to_i.to_s+
          " reflector="+battler_token(reflector))
    end

    def self.snatchable?(action)
      return false if action == nil || !action.skill?
      mid=move_id_from_action(action)
      return false if mid <= 0 || SNATCH_BLACKLIST.include?(mid)
      skill=action.skill
      return false if skill == nil || !move_status?(mid)
      return false unless skill.scope.to_i == 11
      return true
    rescue
      return false
    end
    def self.find_snatcher(attacker)
      return nil if attacker == nil
      unit=attacker.actor? ? $game_troop : $game_party
      return nil if unit == nil
      candidates=[]
      unit.members.each do |b|
        next if b == nil || b.hp.to_i <= 0 || !b.cg_v241_snatch?
        candidates.push(b)
      end
      candidates.sort! do |a,b|
        ao=a.instance_variable_get(:@cg_v241_snatch_order).to_i
        bo=b.instance_variable_get(:@cg_v241_snatch_order).to_i
        ao <=> bo
      end
      return candidates[0]
    rescue
      return nil
    end
    def self.activate_magic_coat(user)
      return false if user == nil
      user.instance_variable_set(:@cg_v241_magic_coat,true)
      mark_apply(MOVE_MAGIC_COAT)
      log("MAGIC_COAT_SET user="+battler_token(user)+":"+user.name.to_s)
      return true
    end
    def self.activate_snatch(user)
      return false if user == nil
      @snatch_serial=@snatch_serial.to_i+1
      user.instance_variable_set(:@cg_v241_snatch,true)
      user.instance_variable_set(:@cg_v241_snatch_order,@snatch_serial)
      mark_apply(MOVE_SNATCH)
      log("SNATCH_SET user="+battler_token(user)+":"+user.name.to_s)
      return true
    end
    def self.set_after_you(user,target)
      return false if user == nil || target == nil
      user.instance_variable_set(:@cg_v241_after_you_target,target)
      mark_apply(MOVE_AFTER_YOU)
      log("AFTER_YOU_SET user="+battler_token(user)+" target="+battler_token(target))
      return true
    end
    def self.set_quash(user,target)
      return false if user == nil || target == nil
      user.instance_variable_set(:@cg_v241_quash_target,target)
      mark_apply(MOVE_QUASH)
      log("QUASH_SET user="+battler_token(user)+" target="+battler_token(target))
      return true
    end
    def self.set_electrify(user,target)
      return false if user == nil || target == nil
      target.instance_variable_set(:@cg_v241_electrify,true)
      mark_apply(MOVE_ELECTRIFY)
      log("ELECTRIFY_SET user="+battler_token(user)+" target="+battler_token(target))
      return true
    end
    def self.set_instruct(user,target)
      return false if user == nil || target == nil
      user.instance_variable_set(:@cg_v241_instruct_target,target)
      mark_apply(MOVE_INSTRUCT)
      log("INSTRUCT_SET user="+battler_token(user)+" target="+battler_token(target))
      return true
    end

    def self.pending_entry_index(entries,target)
      return -1 if entries == nil || target == nil
      entries.each_with_index do |entry,i|
        b=entry.is_a?(ALBERT_CG::ActionEntry) ? entry.battler : entry
        return i if b == target
      end
      return -1
    end
    def self.apply_after_you(scene,user)
      target=user.instance_variable_get(:@cg_v241_after_you_target)
      user.instance_variable_set(:@cg_v241_after_you_target,nil)
      return false if target == nil
      entries=scene.instance_variable_get(:@action_battlers)
      i=pending_entry_index(entries,target)
      if i < 0
        log("AFTER_YOU_FAIL target="+battler_token(target)+" reason=no_pending_action")
        return false
      end
      entry=entries.delete_at(i)
      entries.unshift(entry)
      @after_you_moves=@after_you_moves.to_i+1
      log("AFTER_YOU_REORDER target="+battler_token(target)+" from="+i.to_s+" to=0")
      return true
    rescue => e
      log("AFTER_YOU_ERROR "+e.class.to_s+":"+e.message.to_s)
      return false
    end
    def self.apply_quash(scene,user)
      target=user.instance_variable_get(:@cg_v241_quash_target)
      user.instance_variable_set(:@cg_v241_quash_target,nil)
      return false if target == nil
      entries=scene.instance_variable_get(:@action_battlers)
      i=pending_entry_index(entries,target)
      if i < 0
        log("QUASH_FAIL target="+battler_token(target)+" reason=no_pending_action")
        return false
      end
      entry=entries.delete_at(i)
      entries.push(entry)
      @quash_moves=@quash_moves.to_i+1
      log("QUASH_REORDER target="+battler_token(target)+" from="+i.to_s+" to="+(entries.size-1).to_s)
      return true
    rescue => e
      log("QUASH_ERROR "+e.class.to_s+":"+e.message.to_s)
      return false
    end

    def self.build_injected_entry(battler,mid,target_index,tag)
      return nil if battler == nil || master == nil
      sid=master.skill_id_for_move(mid.to_i)
      return nil if sid.to_i <= 0 || $data_skills[sid] == nil
      action=Game_BattleAction.new(battler)
      action.set_skill(sid)
      action.target_index=target_index.to_i
      action.make_speed
      action.instance_variable_set(:@cg_v241_injected_tag,tag)
      return ALBERT_CG::ActionEntry.new(battler,action,-100000)
    rescue
      return nil
    end
    def self.queue_snatched_action(scene,source,thief)
      return false if source == nil || thief == nil || source.action == nil
      mid=move_id_from_action(source.action)
      return false unless snatchable?(source.action)
      entry=build_injected_entry(thief,mid,thief.index,:stolen)
      return false if entry == nil
      thief.instance_variable_set(:@cg_v241_snatch,false)
      entries=scene.instance_variable_get(:@action_battlers)
      entries.unshift(entry)
      @snatch_triggers=@snatch_triggers.to_i+1
      log("SNATCH_TRIGGER thief="+battler_token(thief)+" source="+battler_token(source)+" move="+mid.to_s)
      return true
    rescue => e
      log("SNATCH_ERROR "+e.class.to_s+":"+e.message.to_s)
      return false
    end
    def self.instructable_move?(mid)
      id=mid.to_i
      return false if id <= 0 || INSTRUCT_BLACKLIST.include?(id)
      return false if master == nil || master.move(id) == nil
      return true
    rescue
      return false
    end
    def self.queue_instruct_action(scene,user)
      target=user.instance_variable_get(:@cg_v241_instruct_target)
      user.instance_variable_set(:@cg_v241_instruct_target,nil)
      return false if target == nil || target.hp.to_i <= 0
      mid=target.respond_to?(:cg_v234_last_move_id) ? target.cg_v234_last_move_id.to_i : 0
      unless instructable_move?(mid)
        log("INSTRUCT_FAIL target="+battler_token(target)+" last_move="+mid.to_s)
        return false
      end
      tidx=target.instance_variable_get(:@cg_v241_last_target_index)
      tidx=0 if tidx == nil
      row=master.move(mid)
      sid=master.skill_id_for_move(mid)
      skill=$data_skills[sid]
      tidx=target.index if skill != nil && skill.scope.to_i == 11
      entry=build_injected_entry(target,mid,tidx,:instruct)
      return false if entry == nil
      entries=scene.instance_variable_get(:@action_battlers)
      entries.unshift(entry)
      @instruct_triggers=@instruct_triggers.to_i+1
      log("INSTRUCT_QUEUE user="+battler_token(user)+" target="+battler_token(target)+" move="+mid.to_s+" target_index="+tidx.to_i.to_s)
      return true
    rescue => e
      log("INSTRUCT_ERROR "+e.class.to_s+":"+e.message.to_s)
      return false
    end

    def self.electric_type_id
      return ALBERT_CG::POKEMON_COMBAT::TYPE_IDS[:electric] if defined?(ALBERT_CG::POKEMON_COMBAT)
      return 0
    rescue
      return 0
    end
    def self.fire_type_id
      return ALBERT_CG::POKEMON_COMBAT::TYPE_IDS[:fire] if defined?(ALBERT_CG::POKEMON_COMBAT)
      return 0
    rescue
      return 0
    end

    def self.clear_round_flags
      list=[]
      list.concat($game_party.members) if $game_party != nil
      list.concat($game_troop.members) if $game_troop != nil
      list.each do |b|
        next if b == nil
        b.instance_variable_set(:@cg_v241_magic_coat,false)
        b.instance_variable_set(:@cg_v241_snatch,false)
        b.instance_variable_set(:@cg_v241_snatch_order,nil)
        b.instance_variable_set(:@cg_v241_electrify,false)
        b.instance_variable_set(:@cg_v241_after_you_target,nil)
        b.instance_variable_set(:@cg_v241_quash_target,nil)
        b.instance_variable_set(:@cg_v241_instruct_target,nil)
      end
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
      actor.cg_v241_clear_runtime if actor.respond_to?(:cg_v241_clear_runtime)
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
        human.cg_v241_clear_runtime if human.respond_to?(:cg_v241_clear_runtime)
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
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon UniqueH v2.4.1b AutoRegression",members)
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
        a[2].cg_reset_stat_stages if a[2] != nil && a[2].respond_to?(:cg_reset_stat_stages)
        e[1].cg_reset_stat_stages if e[1] != nil && e[1].respond_to?(:cg_reset_stat_stages)
        @r1_a2_atk=a[2].cg_stat_stage(:atk)
        @r1_e1_atk=e[1].cg_stat_stage(:atk)
      elsif current_round == 3
        @r3_a3_hp_before=a[3].hp.to_i
        @r3_e1_hp_before=e[1].hp.to_i
        @r3_a1_hp_before=a[1].hp.to_i
      elsif current_round == 4
        @r4_a1_hp_before=a[1].hp.to_i
      end
    end
    def self.prepare_round_actions
      plan=current_plan
      return false if plan == nil
      apply_test_speeds
      prepare_round_preconditions
      @forced_enemy={}
      test_allies.each_with_index do |b,i|
        next if b == nil
        ac=make_action(b,plan[:allies][i])
        if b.respond_to?(:cg_round_actions)
          b.cg_round_actions.clear
          b.cg_round_actions.push(ac)
        end
        b.cg_assign_action(ac) if b.respond_to?(:cg_assign_action)
      end
      test_enemies.each_with_index do |b,i|
        next if b == nil
        @forced_enemy[i]=make_action(b,plan[:enemies][i])
      end
      @actual=[]
      log("ROUND "+current_round.to_s+" BEGIN "+plan[:name].to_s)
      return true
    end
    def self.audit_built_action_queue(scene)
      return true unless active?
      entries=scene.instance_variable_get(:@action_battlers)
      entries=[] if entries == nil
      ally_count=0
      enemy_count=0
      entries.each do |entry|
        b=entry.is_a?(ALBERT_CG::ActionEntry) ? entry.battler : entry
        next if b == nil
        if b.actor?
          ally_count += 1
        else
          enemy_count += 1
        end
      end
      ok=(ally_count >= 4 && enemy_count >= 4)
      log("QUEUE_BUILD round="+current_round.to_s+" allies="+ally_count.to_s+" enemies="+enemy_count.to_s+" entries="+entries.size.to_s)
      assert_true("Round"+current_round.to_s+" Action Queue contains all four allies and enemies",ok,"allies="+ally_count.to_s+" enemies="+enemy_count.to_s)
      return ok
    rescue => e
      assert_true("Round"+current_round.to_s+" Action Queue audit executes",false,e.class.to_s+":"+e.message.to_s)
      return false
    end

    def self.forced_enemy_action(e)
      return active? && @forced_enemy != nil && e != nil ? @forced_enemy[e.index] : nil
    end
    def self.record_execution(b,extra=nil)
      return unless active? || extra != nil
      token=battler_token(b)
      if b != nil && b.action != nil
        if b.action.guard?
          token += ":Guard"
        elsif b.action.attack?
          token += ":Attack"
        elsif b.action.skill?
          mid=move_id_from_action(b.action)
          token += ":M"+mid.to_s
        else
          token += ":None"
        end
        tag=b.action.instance_variable_get(:@cg_v241_injected_tag)
        token += ":STOLEN" if tag == :stolen
        token += ":INSTRUCT" if tag == :instruct
        token += ":REFLECT" if b.action.instance_variable_get(:@cg_v241_magic_reflected) == true
        token += ":ELECTRIC" if b.action.instance_variable_get(:@cg_v241_electrify_applied) == true
      end
      token += ":"+extra.to_s if extra != nil && extra.to_s != ""
      @actual.push(token) if active?
      log("ACTION_EXEC #"+@actual.size.to_s+" "+(b==nil ? "nil" : b.name.to_s)+" token="+token) if active?
      return token
    end
    def self.assert_true(label,ok,detail="")
      if ok
        log("ASSERT PASS "+label+(detail.to_s=="" ? "" : " "+detail.to_s))
      else
        text=label+(detail.to_s=="" ? "" : " "+detail.to_s)
        @failures.push(text)
        log("ASSERT FAIL "+text)
      end
      return ok
    end
    def self.note_reflection(ok); @reflection_checks=@reflection_checks.to_i+1 if ok; end
    def self.note_queue(ok); @queue_checks=@queue_checks.to_i+1 if ok; end
    def self.assert_round
      r=current_round
      expected=EXPECTED_EXECUTION_TOKENS[r] || []
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==expected,"expected="+expected.inspect+" actual="+@actual.inspect)
      a=test_allies; e=test_enemies
      if r == 1
        ok=e[0].respond_to?(:cg_v234_taunt_active?) && e[0].cg_v234_taunt_active? && !(a[1].respond_to?(:cg_v234_taunt_active?) && a[1].cg_v234_taunt_active?)
        note_reflection(ok); assert_true("Magic Coat reflects real Taunt back to attacker",ok)
        ok=@magic_reflects.to_i == 1
        note_reflection(ok); assert_true("Magic Coat reflection hook executes exactly on real target resolution",ok,"count="+@magic_reflects.to_i.to_s)
        ok=a[2].cg_stat_stage(:atk).to_i == @r1_a2_atk.to_i + 2
        note_reflection(ok); assert_true("Snatch makes thief receive real Swords Dance ATK +2",ok,"actual="+a[2].cg_stat_stage(:atk).to_i.to_s)
        ok=e[1].cg_stat_stage(:atk).to_i == @r1_e1_atk.to_i
        note_reflection(ok); assert_true("Snatched source does not receive Swords Dance buff",ok,"actual="+e[1].cg_stat_stage(:atk).to_i.to_s)
        ok=@snatch_triggers.to_i == 1
        note_reflection(ok); assert_true("Snatch inserts one stolen ActionEntry",ok,"count="+@snatch_triggers.to_i.to_s)
      elsif r == 2
        ok=@after_you_moves.to_i >= 1
        note_queue(ok); assert_true("After You reorders pending ally to next action",ok)
        ok=@quash_moves.to_i >= 1
        note_queue(ok); assert_true("Quash moves pending enemy action to queue tail",ok)
        ok=@actual[2] == "A3:M150"
        note_queue(ok); assert_true("After You target actually acts immediately after user",ok)
        ok=@actual[@actual.size-1] == "E0:M33"
        note_queue(ok); assert_true("Quash target actually acts last",ok)
      elsif r == 3
        ok=@instruct_triggers.to_i >= 1
        note_queue(ok); assert_true("Instruct inserts immediate repeat ActionEntry",ok)
        hits=@actual.select { |x| x.index("A3:M33") == 0 }
        ok=hits.size == 2
        note_queue(ok); assert_true("Instruct target executes Tackle exactly twice this round",ok,"count="+hits.size.to_s)
        breakdown=a[1].instance_variable_get(:@cg_last_damage_breakdown)
        type_id=breakdown.is_a?(Hash) ? breakdown[:type_id].to_i : -1
        ok=type_id == electric_type_id.to_i
        note_queue(ok); assert_true("Electrify feeds Electric type into real Damage Breakdown",ok,"expected="+electric_type_id.to_s+" actual="+type_id.to_s)
      elsif r == 4
        breakdown=a[1].instance_variable_get(:@cg_last_damage_breakdown)
        type_id=breakdown.is_a?(Hash) ? breakdown[:type_id].to_i : -1
        ok=type_id == fire_type_id.to_i
        note_queue(ok); assert_true("Electrify temporary override clears before next-round Flamethrower",ok,"expected="+fire_type_id.to_s+" actual="+type_id.to_s)
        flags=(a+e).all? { |b| b != nil && !b.cg_v241_magic_coat? && !b.cg_v241_snatch? && !b.cg_v241_electrify? }
        note_queue(flags); assert_true("Magic Coat / Snatch / Electrify round flags are cleared",flags)
      end
      log("ROUND "+r.to_s+" END")
    end
    def self.finish_round_assertions
      assert_round
      clear_round_flags
      @round_index=@round_index.to_i+1
    end
    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted=true
      assert_true("Scene_Battle uses Unique H test troop",current_troop_id==TEST_TROOP_ID,"actual="+current_troop_id.to_s)
      assert_true("Unique H ally count",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Unique H enemy count",test_enemies.size==4,"actual="+test_enemies.size.to_s)
      apply_test_grid
    end
    def self.covered_move_count
      n=0
      HANDLED_MOVE_IDS.each { |mid| n+=1 if apply_counts[mid].to_i > 0 }
      return n
    end
    def self.finish_suite
      begin
        HANDLED_MOVE_IDS.each { |mid| assert_true("Move "+mid.to_s+" covered",apply_counts[mid].to_i>0) }
        result=@failures.empty? ? "PASS" : "FAIL"
        log("------------------------------------------------------------")
        log("RESULT="+result)
        log("SUMMARY rounds=4 failures="+@failures.size.to_s+" unique_h_moves="+covered_move_count.to_s+"/6 reflection_checks="+@reflection_checks.to_i.to_s+" queue_checks="+@queue_checks.to_i.to_s)
        @failures.each_with_index { |x,i| log("FAILURE "+(i+1).to_s+" "+x.to_s) }
      ensure
        cleanup_test_overrides
        @active=false
      end
    end
    def self.cleanup_test_overrides
      clear_round_flags
      (test_allies+test_enemies).each do |b|
        next if b == nil
        b.instance_variable_set(:@cg_priority_test_speed_override,nil)
      end
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @actual=[]; @apply_counts={}
      @reflection_checks=0; @queue_checks=0; @boot_asserted=false
      @magic_reflects=0; @snatch_triggers=0; @after_you_moves=0; @quash_moves=0; @instruct_triggers=0
      @snatch_serial=0
    end
    def self.start_auto_test
      reset_log; reset_suite; prepare_test_party; make_test_troop; install_skill_scopes
      @active=true
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s)
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    end
    def self.install_skill_scopes
      return if master == nil || $data_skills == nil
      scopes={
        MOVE_MAGIC_COAT=>11, MOVE_SNATCH=>11,
        MOVE_AFTER_YOU=>7, MOVE_INSTRUCT=>7,
        MOVE_QUASH=>1, MOVE_ELECTRIFY=>1
      }
      scopes.each do |mid,scope|
        sid=master.skill_id_for_move(mid)
        $data_skills[sid].scope=scope if sid.to_i>0 && $data_skills[sid]!=nil
      end
    rescue => e
      log("SCOPE_INSTALL_ERROR "+e.class.to_s+":"+e.message.to_s) if active?
    end
  end
end

#==============================================================================
# ■ Game_Battler：Batch H volatile flags / effects
#==============================================================================
class Game_Battler
  def cg_v241_magic_coat?; return @cg_v241_magic_coat == true; end
  def cg_v241_snatch?; return @cg_v241_snatch == true; end
  def cg_v241_electrify?; return @cg_v241_electrify == true; end
  def cg_v241_clear_runtime
    @cg_v241_magic_coat=false
    @cg_v241_snatch=false
    @cg_v241_snatch_order=nil
    @cg_v241_electrify=false
    @cg_v241_after_you_target=nil
    @cg_v241_quash_target=nil
    @cg_v241_instruct_target=nil
    @cg_v241_last_target_index=nil
  end

  alias cg_v241_remove_states_battle remove_states_battle
  def remove_states_battle
    cg_v241_remove_states_battle
    cg_v241_clear_runtime
  end

  if method_defined?(:cg_v236_clear_volatile)
    alias cg_v241_clear_volatile_bridge cg_v236_clear_volatile
    def cg_v236_clear_volatile
      cg_v241_clear_volatile_bridge
      cg_v241_clear_runtime
    end
  end

  alias cg_v241_skill_effect skill_effect
  def skill_effect(user,skill)
    mid=ALBERT_CG::MOVE_EFFECT.move_id(skill)
    case mid
    when ALBERT_CG::UNIQUE_H_V241::MOVE_MAGIC_COAT
      clear_action_results
      ALBERT_CG::UNIQUE_H_V241.activate_magic_coat(user)
      return
    when ALBERT_CG::UNIQUE_H_V241::MOVE_SNATCH
      clear_action_results
      ALBERT_CG::UNIQUE_H_V241.activate_snatch(user)
      return
    when ALBERT_CG::UNIQUE_H_V241::MOVE_AFTER_YOU
      clear_action_results
      ALBERT_CG::UNIQUE_H_V241.set_after_you(user,self)
      return
    when ALBERT_CG::UNIQUE_H_V241::MOVE_QUASH
      clear_action_results
      ALBERT_CG::UNIQUE_H_V241.set_quash(user,self)
      return
    when ALBERT_CG::UNIQUE_H_V241::MOVE_ELECTRIFY
      clear_action_results
      ALBERT_CG::UNIQUE_H_V241.set_electrify(user,self)
      return
    when ALBERT_CG::UNIQUE_H_V241::MOVE_INSTRUCT
      clear_action_results
      ALBERT_CG::UNIQUE_H_V241.set_instruct(user,self)
      return
    end
    cg_v241_skill_effect(user,skill)
  end
end

#==============================================================================
# ■ RPG::UsableItem：Electrify per-action type override（v2.4.1b）
#------------------------------------------------------------------------------
# Field Core 已在 RPG::UsableItem 定義 cg_pokemon_type_id，因此 Electrify 必須在
# 同一個／更下游的 method authority 層包裝；寫在父類 RPG::BaseItem 會被子類遮蔽。
#==============================================================================
class RPG::UsableItem
  alias cg_v241b_pokemon_type_id cg_pokemon_type_id
  def cg_pokemon_type_id
    x=@cg_v241_temp_type_override
    return x.to_i if x != nil
    return cg_v241b_pokemon_type_id
  end
end

#==============================================================================
# ■ Game_BattleAction：Magic Coat target reflection
#==============================================================================
class Game_BattleAction
  alias cg_v241_make_targets make_targets
  def make_targets
    if @cg_v241_magic_reflected == true
      return @battler == nil ? [] : [@battler]
    end
    targets=cg_v241_make_targets
    return targets unless ALBERT_CG::UNIQUE_H_V241.magic_coat_reflectable?(self)
    reflector=nil
    targets.each do |t|
      if t != nil && t.cg_v241_magic_coat? && @battler != nil && t.actor? != @battler.actor?
        reflector=t
        break
      end
    end
    return targets if reflector == nil
    @cg_v241_magic_reflected=true
    @cg_v241_magic_reflector=reflector
    ALBERT_CG::UNIQUE_H_V241.note_magic_reflect(@battler,ALBERT_CG::UNIQUE_H_V241.move_id_from_action(self),reflector)
    return @battler == nil ? targets : [@battler]
  end
end

#==============================================================================
# ■ Game_Battler：v2.4.1b deterministic SPE Bridge
#==============================================================================
class Game_Battler
  alias cg_v241_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::UNIQUE_H_V241) && ALBERT_CG::UNIQUE_H_V241.active?
      x=@cg_priority_test_speed_override
      return x.to_i if x != nil
    end
    return cg_v241_priority_base_speed
  rescue
    return cg_v241_priority_base_speed
  end
end

#==============================================================================
# ■ Game_Enemy：Regression deterministic action
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v241_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::UNIQUE_H_V241) && ALBERT_CG::UNIQUE_H_V241.active?
      a=ALBERT_CG::UNIQUE_H_V241.forced_enemy_action(self)
      if a != nil
        cg_assign_action(a) if respond_to?(:cg_assign_action)
        @action=a unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v241_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle：Snatch / Queue reorder / Instruct / Electrify / Regression
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v241_make_action_orders make_action_orders
  def make_action_orders
    cg_v241_make_action_orders
    if defined?(ALBERT_CG::UNIQUE_H_V241) && ALBERT_CG::UNIQUE_H_V241.active?
      ALBERT_CG::UNIQUE_H_V241.audit_built_action_queue(self)
    end
  end

  alias cg_v241_execute_action execute_action
  def execute_action
    b=@active_battler
    action=b == nil ? nil : b.action
    mid=ALBERT_CG::UNIQUE_H_V241.move_id_from_action(action)

    # Snatch 必須在原自我強化技能真正執行前取消來源 Action。
    if b != nil && ALBERT_CG::UNIQUE_H_V241.snatchable?(action)
      thief=ALBERT_CG::UNIQUE_H_V241.find_snatcher(b)
      if thief != nil && ALBERT_CG::UNIQUE_H_V241.queue_snatched_action(self,b,thief)
        ALBERT_CG::UNIQUE_H_V241.record_execution(b,"SNATCHED") if ALBERT_CG::UNIQUE_H_V241.active?
        return
      end
    end

    # Electrify 只在目標下一個真正 Skill Action 的同步區間覆寫 Type。
    electrified=false
    skill=nil
    if b != nil && action != nil && action.skill? && b.cg_v241_electrify?
      skill=action.skill
      if skill != nil
        skill.instance_variable_set(:@cg_v241_temp_type_override,ALBERT_CG::UNIQUE_H_V241.electric_type_id)
        action.instance_variable_set(:@cg_v241_electrify_applied,true)
        electrified=true
        resolved_type=skill.respond_to?(:cg_pokemon_type_id) ? skill.cg_pokemon_type_id.to_i : -1
        ALBERT_CG::UNIQUE_H_V241.log("ELECTRIFY_APPLY battler="+ALBERT_CG::UNIQUE_H_V241.battler_token(b)+" move="+mid.to_s+" type=electric resolved_type="+resolved_type.to_s)
      end
    end

    ALBERT_CG::UNIQUE_H_V241.record_execution(b) if ALBERT_CG::UNIQUE_H_V241.active?
    begin
      cg_v241_execute_action
      if b != nil && action != nil && action.skill?
        b.instance_variable_set(:@cg_v241_last_target_index,action.target_index.to_i)
      end
      ALBERT_CG::UNIQUE_H_V241.apply_after_you(self,b) if b != nil && mid == ALBERT_CG::UNIQUE_H_V241::MOVE_AFTER_YOU
      ALBERT_CG::UNIQUE_H_V241.apply_quash(self,b) if b != nil && mid == ALBERT_CG::UNIQUE_H_V241::MOVE_QUASH
      ALBERT_CG::UNIQUE_H_V241.queue_instruct_action(self,b) if b != nil && mid == ALBERT_CG::UNIQUE_H_V241::MOVE_INSTRUCT
    ensure
      if electrified
        skill.instance_variable_set(:@cg_v241_temp_type_override,nil) if skill != nil
        b.instance_variable_set(:@cg_v241_electrify,false) if b != nil
      end
    end
  end

  alias cg_v241_turn_end turn_end
  def turn_end
    ALBERT_CG::UNIQUE_H_V241.finish_round_assertions if defined?(ALBERT_CG::UNIQUE_H_V241) && ALBERT_CG::UNIQUE_H_V241.active?
    ALBERT_CG::UNIQUE_H_V241.clear_round_flags if defined?(ALBERT_CG::UNIQUE_H_V241) && !ALBERT_CG::UNIQUE_H_V241.active?
    cg_v241_turn_end
  end

  alias cg_v241_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::UNIQUE_H_V241) && ALBERT_CG::UNIQUE_H_V241.active?
      return cg_v241_start_party_command
    end
    cg_v241_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::UNIQUE_H_V241.assert_bootstrap_once
    if ALBERT_CG::UNIQUE_H_V241.finished?
      ALBERT_CG::UNIQUE_H_V241.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::UNIQUE_H_V241.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle 重建 Party 後重套 Batch H 測試資料
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v241_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result=cg_v241_bootstrap_demo_party
      if defined?(ALBERT_CG::UNIQUE_H_V241) && ALBERT_CG::UNIQUE_H_V241.active?
        ALBERT_CG::UNIQUE_H_V241::TEST_ALLIES.each { |cfg| ALBERT_CG::UNIQUE_H_V241.configure_actor(cfg) }
        human=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::UNIQUE_H_V241::TEST_LEVEL,false)
          human.recover_all if human.respond_to?(:recover_all)
          human.cg_v241_clear_runtime if human.respond_to?(:cg_v241_clear_runtime)
          human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
        end
        ALBERT_CG::UNIQUE_H_V241.install_skill_scopes
      end
      return result
    end
  end
end

#==============================================================================
# ■ Scene_Title：Move Stub 建立後校正 Scope
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_v241_load_database load_database
  def load_database
    cg_v241_load_database
    ALBERT_CG::UNIQUE_H_V241.install_skill_scopes
  end
  alias cg_v241_load_bt_database load_bt_database
  def load_bt_database
    cg_v241_load_bt_database
    ALBERT_CG::UNIQUE_H_V241.install_skill_scopes
  end
end

#==============================================================================
# ■ F11：v2.4.1b 成為唯一最新版 AutoRegression
#==============================================================================
if defined?(ALBERT_CG::UNIQUE_G_V240)
  module ALBERT_CG
    module UNIQUE_G_V240
      def self.f11_trigger?; return false; end
    end
  end
end
class Scene_Map < Scene_Base
  alias cg_v241_scene_map_update update
  def update
    cg_v241_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::UNIQUE_H_V241.f11_trigger?
      Sound.play_decision
      ALBERT_CG::UNIQUE_H_V241.start_auto_test
    end
  end
end

#==============================================================================
# ■ Coverage：6 個 Unique Pending 轉為 V241_UNIQUE_H_HANDLED
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    class << self
      alias cg_v241_coverage_v231 coverage_v231
      def coverage_v231(move_id)
        return "V241_UNIQUE_H_HANDLED" if ALBERT_CG::UNIQUE_H_V241.handled?(move_id)
        return cg_v241_coverage_v231(move_id)
      end
    end
  end
end
