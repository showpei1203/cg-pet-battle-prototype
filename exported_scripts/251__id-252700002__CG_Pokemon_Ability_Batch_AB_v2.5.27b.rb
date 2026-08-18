# RMVX_SCRIPT_INDEX: 251
# RMVX_SCRIPT_ID: 252700002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AB v2.5.27b
# RMVX_SOURCE_SHA256: c1a9bd7d00f9f7bf0dcb635154a63a1fc02792b61d205b87147b3fbf7087dfc9

#==============================================================================
# ■ CG Pokemon Ability Batch AB v2.5.27b - Held Item Guard + Berry Lifecycle BOOTSTRAP ASSERT FIX TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.26c Ability Batch AA RPG Maker VX 實機 PASS 為唯一正式基底，新增 8 個
#  尚未覆蓋的主系列 Ability，集中處理 Pokémon Held Item / Berry 的「持有保護、
#  效果失效、食用封鎖、回收、額外回復、偷取、效果倍增、延遲再觸發」。
#  全部沿用已封版 CG Pokemon Held Item Core v2.4.4 與 Unique K Move Authority；
#  不建立第二套 item_id / berry inventory，也不修改 937 個 Move 的效果規則。v2.5.27b
#  另以獨立 hotfix 隔離 Unique K 的 F11 coverage counter，避免測試 instrumentation 洩漏。
#
#
# 【v2.5.27a 修正】
#  v2.5.27 實機在 AutoRegression bootstrap assertion 呼叫
#  ALBERT_CG::POKEMON_MASTER.ability_count 時發生 NoMethodError。POKEMON_MASTER
#  提供物種／Actor／Enemy／Move 映射，但不擁有 Ability catalog count API；正式
#  Ability catalog 權威為 ALBERT_CG::ABILITY_V250.catalog_count。v2.5.27a 僅修正
#  這個 Regression bootstrap assertion 與版本／LOG 標記，8 個 Ability Formal Runtime
#  handler、Held Item Authority bridge、三回合 fixture 與 expected execution 全部不變。
# 【v2.5.27b 修正】
#  v2.5.27a 已能正常進入 Batch AB Round1，但 Teatime 752 成功套用後，既有已封版
#  Unique Move Batch K v2.4.4a 的 F11 coverage helper `mark_apply` 在 K regression 未啟動時
#  仍無條件存取尚未初始化的 @apply_counts，造成 `undefined method [] for nil:NilClass`。
#  本版新增獨立 `CG Pokemon Unique K Runtime Instrumentation Guard v2.4.4b`，只讓
#  mark_apply 在 UNIQUE_K F11 suite active 時記數，正式遊戲／其他 Regression 使用 Batch K
#  Move 時不再碰測試計數器。Batch AB 8 個 Ability Formal Runtime、Held Item bridge、
#  Teatime 例外與三回合 fixture 均不更動。
#
# 【本批 Ability】
#   60 Sticky Hold / 黏著：對手的 Trick / Switcheroo / Magician 等不得奪走 holder 道具。
#  103 Klutz / 笨拙：holder 仍持有 raw item，但一般戰鬥有效 cg_held_item 視為 nil；Teatime 為強制食用例外。
#  127 Unnerve / 緊張感：active holder 阻止對手一般食用 Berry；Teatime 為原作例外。
#  139 Harvest / 收穫：end-turn 若目前無道具且最後消耗的是 Berry，50% 回收；Sun 下 100%。
#  167 Cheek Pouch / 頰囊：成功吃 Berry 後額外回復 maxHP 1/3。
#  170 Magician / 魔術師：自身無道具且 Move 造成實際傷害後，奪取目標 Held Item；
#                         Sticky Hold 目標可阻擋。
#  247 Ripen / 熟成：Berry 目前由 Held Item Authority 支援的消耗效果執行兩次。
#  291 Cud Chew / 反芻：成功吃 Berry 後記錄該 Berry；下一個完整 turn-end 再執行一次
#                       Berry effect，不恢復實體 item。
#
# 【主要設定項】
#  TEST_TROOP_ID=730；HANDLED_ABILITY_IDS=8。
#  Static coverage：216/373 -> 224/373，pending 157 -> 149。
#  TEST_ITEM_BERRY_A/B、CHARM = 911..913，只在 F11 測試執行期建立。
#
# 【機制規則】
#  1. Held Item 真實擁有權仍以 cg_held_item_id / cg_held_item_owner 為唯一權威。
#  2. Klutz 一般情境只讓 cg_held_item 回 nil，不清除 cg_raw_held_item，因此 Trick / Magician 等仍可
#     正常搬移道具；Teatime 執行期間暫時允許 raw Berry 被強制食用。
#  3. Unnerve 在 cg_consume_held_item 入口阻擋對手一般 Berry 食用，hidden / KO holder 不參與；
#     reason=:teatime 明確 bypass，維持 Teatime 原作例外。
#  4. Sticky Hold 只阻擋「對手導致的移除／交換／偷取」；holder 自己消耗 Berry 不受影響。
#  5. Harvest 直接呼叫 cg_recycle_held_item，保留原 owner token 與 consumed ledger；Sun 僅將
#     回收率提升為 100%，不自行製造新 Berry。
#  6. Cheek Pouch 在原 Berry effect 完成後追加 maxHP/3；若已滿血依正式 HP clamp 處理。
#  7. Ripen 不解析第二套 Berry note；直接讓 HELD_ITEM_V244.apply_consumption_effect 再跑一次，
#     因此目前支援的 flat/% HP、MP、primary cure 都共用同一 Authority。
#  8. Cud Chew 在 consume 時只 arm battle-local token，第一個 end-turn 只倒數，第二個
#     end-turn 才直接重放該 Berry effect；不把 item 放回手上，也不污染 Recycle/Harvest ledger。
#  9. Magician 只在 damage_done>0 後執行，user 已有 raw Held Item 時不觸發；偷取時保留
#     target 原 owner token，Battle 結束仍由 Held Item Core 統一收束。
# 10. Ability 有效性一律讀 Ability Core ability_id，尊重 Battle-only override/suppression。
# 11. F11 Regression 使用真正 Scene_Battle / Teatime / Trick / Aura Sphere / Teleport；
#     正式玩家 RNG 不改。Harvest 以 Sun fixture 取得 deterministic 100% 回收。
#
# 【可調參數】
#  CHEEK_DIVISOR=3；HARVEST_CHANCE=50；CUD_DELAY_END_TURNS=2；TEST_TROOP_ID。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫。開發測試：地圖按 F11，自動進 troop 730，跑三回合並輸出
#  Pokemon_Ability_AB_AutoTest_v2_5_27b.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：先直接 probe 驗 Klutz 一般 Berry consume 被抑制；A3 Teatime 則強制 E0 吃 Berry；
#          Cheek Pouch E1 額外回 1/3 MaxHP、Ripen E2 的 30HP Berry 變 60HP，Harvest E3 /
#          Cud Chew A3 arm；E0 Trick -> Sticky Hold A1 被阻擋；end-turn Sun Harvest 回收。
#  Round2：E0 裝非 Berry Charm；A2 Aura Sphere -> Magician 偷取；E3 Teleport -> hidden E4
#          Unnerve；end-turn Cud Chew 再觸發 Berry effect。
#  Round3：A1 裝 Berry，先 direct probe 驗 Unnerve 阻止一般食用；A3 Teatime 再驗原作例外
#          仍會強制食用，最後確認 E4 active/alive。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAB"] = "2.5.27b"

module ALBERT_CG
  module ABILITY_AB_V2527
    VERSION = "2.5.27b"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 730
    VK_F11 = 0x7A

    ABILITY_STICKY_HOLD = 60
    ABILITY_KLUTZ       = 103
    ABILITY_UNNERVE     = 127
    ABILITY_HARVEST     = 139
    ABILITY_CHEEK_POUCH = 167
    ABILITY_MAGICIAN    = 170
    ABILITY_RIPEN       = 247
    ABILITY_CUD_CHEW    = 291
    HANDLED_ABILITY_IDS = [60,103,127,139,167,170,247,291]

    CHEEK_DIVISOR = 3
    HARVEST_CHANCE = 50
    CUD_DELAY_END_TURNS = 2

    TEST_ITEM_BERRY_A = 911
    TEST_ITEM_BERRY_B = 912
    TEST_ITEM_CHARM   = 913

    TEST_ALLIES = [
      {:dex=>128,:level=>40,:ability=>ABILITY_STICKY_HOLD,:moves=>[150,150,150,150]},
      {:dex=>94, :level=>40,:ability=>ABILITY_MAGICIAN,   :moves=>[396,150,150,150]},
      {:dex=>109,:level=>40,:ability=>ABILITY_CUD_CHEW,   :moves=>[752,150,752,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>50,:ability=>ABILITY_KLUTZ,       :moves=>[271,150,150,150]},
      {:dex=>92, :level=>50,:ability=>ABILITY_CHEEK_POUCH, :moves=>[150,150,150,150]},
      {:dex=>65, :level=>50,:ability=>ABILITY_RIPEN,       :moves=>[150,150,150,150]},
      {:dex=>1,  :level=>50,:ability=>ABILITY_HARVEST,     :moves=>[150,100,150,150]},
      {:dex=>197,:level=>50,:ability=>ABILITY_UNNERVE,     :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"ITEM_GUARD_BERRY_CONSUME_TEATIME",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>752,:target=>3},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>271,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"MAGICIAN_CUD_CHEW_AND_UNNERVE_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>396,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>100,:target=>3},
        }
      },
      {
        :name=>"UNNERVE_NORMAL_BLOCK_TEATIME_EXCEPTION",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>4},
          {:kind=>:move,:move_id=>150,:target=>4},
          {:kind=>:move,:move_id=>752,:target=>3},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,220,300,340, 320,210,200,190,0],
      :r2=>[10,300,290,280, 250,240,230,10,0],
      :r3=>[10,250,240,330, 220,210,200,0,230],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A3:M752","E0:M271","A2:M150","A1:M150","E1:M150","E2:M150","E3:M150"],
      2=>["A0:Guard","A1:M150","A2:M396","A3:M150","E0:M150","E1:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","A3:M752","A1:M150","A2:M150","E4:M150","E0:M150","E1:M150","E2:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.held; defined?(ALBERT_CG::HELD_ITEM_V244) ? ALBERT_CG::HELD_ITEM_V244 : nil; end
    def self.field; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233 : nil; end
    def self.active?; @active==true; end
    def self.teatime_context?; @teatime_context==true; end
    def self.with_teatime_context
      old=@teatime_context; @teatime_context=true
      begin
        return yield
      ensure
        @teatime_context=old
      end
    end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AB_AutoTest_v2_5_27b.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.ability_id(b); core==nil || b==nil ? 0 : core.ability_id(b).to_i; rescue; 0; end
    def self.same_side?(a,b); a!=nil && b!=nil && a.respond_to?(:actor?) && b.respond_to?(:actor?) && a.actor? == b.actor?; rescue; false; end
    def self.opposing?(a,b); a!=nil && b!=nil && !same_side?(a,b); rescue; false; end
    def self.active_battlers; core ? core.active_battlers : []; rescue; []; end
    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill!=nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end

    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else
        text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text)
      end
      condition
    end

    def self.reset_log
      h="CG POKEMON ABILITY AB HELD ITEM GUARD + BERRY LIFECYCLE AUTO REGRESSION v2.5.27b\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; Held Item guard + berry consume/recycle/steal/delayed-effect lifecycle\r\n"+
        "BASELINE=v2.5.26c Ability Batch AA Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AA_PASS=216 BATCH_AB=8 PENDING=149\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue
    end

    def self.note_local(aid,battler,kind,data=nil)
      return true unless active?
      @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1
      rec={:ability=>aid.to_i,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill,:action,:item].include?(k)}
      @records[aid.to_i]=[] if @records[aid.to_i]==nil; @records[aid.to_i].push(rec)
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
      log("ABILITY_AB_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
      true
    rescue
      false
    end

    def self.note_no_popup(aid,holder,kind,ctx=nil)
      data=ctx||{}
      core.note_trigger(kind,holder,aid,data) if core && core.respond_to?(:note_trigger)
      note_local(aid,holder,kind,data)
      true
    rescue
      true
    end

    def self.formal_note(aid,holder,kind,ctx=nil)
      data=ctx||{}
      if core
        core.note_trigger(kind,holder,aid,data) if core.respond_to?(:note_trigger)
        core.present_trigger(holder,aid,kind,data) if core.respond_to?(:present_trigger)
      end
      note_local(aid,holder,kind,data)
      true
    rescue
      true
    end

    def self.records_for(aid,kind=nil)
      list=@records[aid.to_i]||[]; return list if kind==nil; list.select{|r|r[:kind]==kind}
    end

    def self.raw_item(b)
      b!=nil && b.respond_to?(:cg_raw_held_item) ? b.cg_raw_held_item : nil
    rescue
      nil
    end

    def self.raw_item_id(b)
      item=raw_item(b); item==nil ? 0 : item.id.to_i
    rescue
      0
    end

    def self.berry?(item)
      held!=nil && held.respond_to?(:berry?) && held.berry?(item)
    rescue
      false
    end

    def self.klutz?(b); b!=nil && ability_id(b)==ABILITY_KLUTZ; rescue; false; end
    def self.sticky_hold?(b); b!=nil && ability_id(b)==ABILITY_STICKY_HOLD; rescue; false; end

    def self.unnerve_holder_for(battler)
      active_battlers.each do |b|
        next if b==nil || b.hidden || b.hp.to_i<=0
        return b if opposing?(b,battler) && ability_id(b)==ABILITY_UNNERVE
      end
      nil
    rescue
      nil
    end

    def self.item_removal_blocker(target,source,reason=:item_remove)
      return nil if target==nil || source==nil || !opposing?(target,source)
      return nil unless sticky_hold?(target) && raw_item(target)!=nil
      target
    rescue
      nil
    end

    def self.note_sticky_block(holder,source,reason,item_id)
      formal_note(ABILITY_STICKY_HOLD,holder,:sticky_hold,{:source_index=>(source&&source.respond_to?(:index) ? source.index : -1),:reason=>reason,:item_id=>item_id.to_i})
    end

    def self.note_klutz_block(holder,item_id,reason)
      data={:item_id=>item_id.to_i,:reason=>reason}
      return note_no_popup(ABILITY_KLUTZ,holder,:klutz,data) if reason==:klutz_probe
      formal_note(ABILITY_KLUTZ,holder,:klutz,data)
    end

    def self.note_unnerve(holder,target,item_id,reason)
      formal_note(ABILITY_UNNERVE,holder,:unnerve,{:target_index=>(target&&target.respond_to?(:index) ? target.index : -1),:item_id=>item_id.to_i,:reason=>reason})
    end

    def self.after_berry_consumed(holder,item,before_hp,after_base_hp,reason)
      return false if holder==nil || item==nil || !berry?(item)
      aid=ability_id(holder)
      if aid==ABILITY_CHEEK_POUCH
        heal=[holder.maxhp.to_i/CHEEK_DIVISOR,1].max
        before=holder.hp.to_i; holder.hp=[holder.hp.to_i+heal,holder.maxhp.to_i].min; gained=holder.hp.to_i-before
        formal_note(ABILITY_CHEEK_POUCH,holder,:cheek_pouch,{:item_id=>item.id.to_i,:gained=>gained,:hp_before=>before,:hp_after=>holder.hp.to_i,:reason=>reason}) if gained>0
      elsif aid==ABILITY_CUD_CHEW
        holder.instance_variable_set(:@cg_v2527ab_cud_item_id,item.id.to_i)
        holder.instance_variable_set(:@cg_v2527ab_cud_turns,CUD_DELAY_END_TURNS)
        formal_note(ABILITY_CUD_CHEW,holder,:cud_chew_arm,{:item_id=>item.id.to_i,:turns=>CUD_DELAY_END_TURNS,:reason=>reason})
      end
      true
    rescue
      false
    end

    def self.apply_ripen_effect(holder,item)
      return false if holder==nil || item==nil || ability_id(holder)!=ABILITY_RIPEN || !berry?(item)
      formal_note(ABILITY_RIPEN,holder,:ripen,{:item_id=>item.id.to_i})
      true
    rescue
      false
    end

    def self.sun_active?
      st=field&&field.respond_to?(:state) ? field.state : nil
      st!=nil && st.weather==:sun && st.weather_turns.to_i>0
    rescue
      false
    end

    def self.apply_harvest(holder,ctx=nil)
      return false if holder==nil || raw_item(holder)!=nil || !holder.respond_to?(:cg_last_consumed_held_item_id)
      id=holder.cg_last_consumed_held_item_id.to_i; return false if id<=0 || $data_weapons==nil
      item=$data_weapons[id]; return false unless berry?(item)
      ok=sun_active? || rand(100)<HARVEST_CHANCE
      return false unless ok && holder.respond_to?(:cg_recycle_held_item) && holder.cg_recycle_held_item
      formal_note(ABILITY_HARVEST,holder,:harvest,{:item_id=>id,:sun=>sun_active?})
      true
    rescue
      false
    end

    def self.apply_cud_chew(holder,ctx=nil)
      return false if holder==nil
      turns=holder.instance_variable_get(:@cg_v2527ab_cud_turns).to_i
      return false if turns<=0
      turns-=1; holder.instance_variable_set(:@cg_v2527ab_cud_turns,turns)
      return false if turns>0
      id=holder.instance_variable_get(:@cg_v2527ab_cud_item_id).to_i
      holder.instance_variable_set(:@cg_v2527ab_cud_item_id,0)
      return false if id<=0 || $data_weapons==nil || held==nil
      item=$data_weapons[id]; return false unless berry?(item)
      before=holder.hp.to_i
      held.apply_consumption_effect(holder,item)
      after=holder.hp.to_i
      formal_note(ABILITY_CUD_CHEW,holder,:cud_chew_repeat,{:item_id=>id,:hp_before=>before,:hp_after=>after})
      true
    rescue
      false
    end

    def self.apply_magician(user,target,damage_done,skill=nil)
      return false if user==nil || target==nil || damage_done.to_i<=0 || !opposing?(user,target)
      return false unless ability_id(user)==ABILITY_MAGICIAN && raw_item(user)==nil
      item=raw_item(target); return false if item==nil
      blocker=item_removal_blocker(target,user,:magician)
      if blocker!=nil
        note_sticky_block(blocker,user,:magician,item.id.to_i); return false
      end
      return false unless user.respond_to?(:cg_can_hold_item?) && user.cg_can_hold_item?(item)
      id=item.id.to_i; owner=target.respond_to?(:cg_held_item_owner) ? target.cg_held_item_owner : nil
      return false unless user.respond_to?(:cg_set_battle_held_item) && target.respond_to?(:cg_set_battle_held_item)
      return false unless target.cg_set_battle_held_item(0,nil)
      unless user.cg_set_battle_held_item(id,owner)
        target.cg_set_battle_held_item(id,owner); return false
      end
      formal_note(ABILITY_MAGICIAN,user,:magician,{:item_id=>id,:target_index=>(target.respond_to?(:index) ? target.index : -1),:damage_done=>damage_done.to_i,:move_id=>move_id(skill)})
      true
    rescue
      false
    end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_HARVEST,:end_turn,self,:apply_harvest)
      core.register(ABILITY_CUD_CHEW,:end_turn,self,:apply_cud_chew)
      true
    end

    #--------------------------------------------------------------------------
    # F11 fixture
    #--------------------------------------------------------------------------
    def self.make_test_weapon(id,name,note)
      return nil if $data_weapons==nil
      while $data_weapons.size<=id; $data_weapons.push(nil); end
      w=RPG::Weapon.new; w.id=id; w.name=name; w.note=note; w.icon_index=0; w.price=0
      $data_weapons[id]=w; w
    end

    def self.install_test_weapons
      return false if $data_weapons==nil
      make_test_weapon(TEST_ITEM_BERRY_A,"AB測試莓果A","<CG_POKEMON_HELD_ITEM>\n<CG_BERRY>\n<CG_HELD_HEAL_HP:30>")
      make_test_weapon(TEST_ITEM_BERRY_B,"AB測試莓果B","<CG_POKEMON_HELD_ITEM>\n<CG_BERRY>\n<CG_HELD_HEAL_HP:25>")
      make_test_weapon(TEST_ITEM_CHARM,"AB測試護符","<CG_POKEMON_HELD_ITEM>")
      held.sync_class_permissions if held&&held.respond_to?(:sync_class_permissions)
      true
    end

    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime)
      a.instance_variable_set(:@cg_v2527ab_cud_item_id,0); a.instance_variable_set(:@cg_v2527ab_cud_turns,0)
    end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end

    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}
      ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each{|c|configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if h
        h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0)
      end
    end

    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1]]
      ms=[]
      TEST_ENEMIES.each_with_index do |c,i|
        configure_enemy(c)
        m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=(i>=4); ms.push(m)
      end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AB v2.5.27b AutoRegression",ms)
    end

    def self.make_action(b,c)
      a=Game_BattleAction.new(b)
      if c[:kind]==:guard; a.set_guard
      elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i))
      else; a.clear; end
      a.target_index=c[:target].to_i if c.has_key?(:target); a
    end

    def self.forced_enemy_action(e)
      return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0
      c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c)
    end

    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||[]
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_ab,vals[i]) if b}
    end

    def self.set_test_item(b,id)
      return false if b==nil || !b.respond_to?(:cg_set_battle_held_item)
      owner=b.respond_to?(:cg_held_item_owner_key) ? b.cg_held_item_owner_key : nil
      b.cg_set_battle_held_item(id,owner)
    rescue
      false
    end

    def self.clear_item(b)
      b.cg_set_battle_held_item(0,nil) if b&&b.respond_to?(:cg_set_battle_held_item)
    rescue
    end

    def self.prepare_round_preconditions
      a=test_allies; e=all_enemies; st=field&&field.respond_to?(:state) ? field.state : nil
      if current_round==1
        (a+e).each{|b|clear_item(b) if b}
        set_test_item(a[1],TEST_ITEM_CHARM)
        set_test_item(a[3],TEST_ITEM_BERRY_B)
        set_test_item(e[0],TEST_ITEM_BERRY_A)
        set_test_item(e[1],TEST_ITEM_BERRY_A)
        set_test_item(e[2],TEST_ITEM_BERRY_A)
        set_test_item(e[3],TEST_ITEM_BERRY_B)
        a[3].hp=[a[3].maxhp.to_i-100,1].max
        e[1].hp=[e[1].maxhp.to_i-120,1].max
        e[2].hp=[e[2].maxhp.to_i-120,1].max
        e[3].hp=[e[3].maxhp.to_i-100,1].max
        e[0].hp=[e[0].maxhp.to_i-60,1].max
        @r1_a3_hp=a[3].hp.to_i; @r1_e1_hp=e[1].hp.to_i; @r1_e2_hp=e[2].hp.to_i; @r1_e3_hp=e[3].hp.to_i
        @r1_klutz_hp=e[0].hp.to_i; @r1_klutz_item=raw_item_id(e[0])
        klutz_result=e[0].cg_consume_held_item(:klutz_probe,true) if e[0].respond_to?(:cg_consume_held_item)
        @r1_klutz_probe=(klutz_result!=true && e[0].hp.to_i==@r1_klutz_hp.to_i && raw_item_id(e[0])==@r1_klutz_item.to_i && !records_for(ABILITY_KLUTZ,:klutz).empty?)
        if st; st.weather=:sun; st.weather_turns=3; end
      elsif current_round==2
        if st; st.weather=nil; st.weather_turns=0; end
        clear_item(a[2]); set_test_item(e[0],TEST_ITEM_CHARM)
        @r2_a3_hp=a[3] ? a[3].hp.to_i : 0
        @r2_magician_target_item=raw_item_id(e[0])
        @r2_storage_before=storage_size
      elsif current_round==3
        clear_item(a[1]); clear_item(a[2])
        set_test_item(a[1],TEST_ITEM_BERRY_A)
        a[1].hp=[a[1].maxhp.to_i-80,1].max
        @r3_a1_hp=a[1].hp.to_i; @r3_a1_item=raw_item_id(a[1])
        result=a[1].cg_consume_held_item(:unnerve_probe,true) if a[1].respond_to?(:cg_consume_held_item)
        @r3_unnerve_probe=(result!=true && a[1].hp.to_i==@r3_a1_hp.to_i && raw_item_id(a[1])==@r3_a1_item.to_i && !records_for(ABILITY_UNNERVE,:unnerve).empty?)
      end
    end

    def self.prepare_round_actions
      p=current_plan; return false if p==nil
      apply_test_speeds; prepare_round_preconditions; @actual=[]; log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s)
      test_allies.each_with_index do |b,i|
        next if b==nil; ac=make_action(b,p[:allies][i])
        if b.respond_to?(:cg_round_actions); b.cg_round_actions.clear; b.cg_round_actions.push(ac); end
        b.cg_assign_action(ac) if b.respond_to?(:cg_assign_action); b.instance_variable_set(:@action,ac) unless b.respond_to?(:cg_assign_action)
      end
      true
    end

    def self.record_execution(b)
      return unless active?&&b
      tok=(b.actor? ? "A" : "E")+b.index.to_s
      a=b.action
      if a&&a.guard?; tok+=":Guard"
      elsif a&&a.skill?; sk=$data_skills[a.skill_id]; tok+=":M"+move_id(sk).to_s
      else; tok+=":Other"; end
      @actual.push(tok); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    end

    def self.assert_bootstrap_once
      return if @boot_asserted==true; @boot_asserted=true
      assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil"))
      assert_true("Ability Batch AB defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability AB test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil"))
      assert_true("Ability AB ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability AB starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden&&b.hp.to_i>0})
      assert_true("Ability AB starts with 1 hidden Unnerve reserve",all_enemies[4]&&all_enemies[4].hidden,"E4_hidden="+(all_enemies[4] ? all_enemies[4].hidden.to_s : "nil"))
    end

    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==exp,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        @item_guard_checks+=1 if @r1_klutz_probe; assert_true("Klutz suppresses normal Berry consumption while raw item remains",@r1_klutz_probe,"item="+@r1_klutz_item.to_s+" hp="+@r1_klutz_hp.to_s)
        kt=e[0]&&raw_item_id(e[0])==0&&e[0].hp.to_i>@r1_klutz_hp.to_i
        @teatime_checks+=1 if kt; assert_true("Teatime forces Klutz holder to consume Berry despite normal item suppression",kt,"hp="+@r1_klutz_hp.to_s+"->"+(e[0] ? e[0].hp.to_i.to_s : "nil")+" item="+raw_item_id(e[0]).to_s)
        sh=!records_for(ABILITY_STICKY_HOLD,:sticky_hold).empty? && raw_item_id(a[1])==TEST_ITEM_CHARM
        @item_guard_checks+=1 if sh; assert_true("Sticky Hold blocks opposing Trick item swap",sh,"A1_item="+raw_item_id(a[1]).to_s+" record="+(records_for(ABILITY_STICKY_HOLD,:sticky_hold)[-1]||{}).inspect)
        cp_gain=(e[1] ? e[1].hp.to_i-@r1_e1_hp.to_i : 0); cp_expect=30+[e[1].maxhp.to_i/CHEEK_DIVISOR,1].max
        cp=e[1]&&cp_gain==cp_expect&&!records_for(ABILITY_CHEEK_POUCH,:cheek_pouch).empty?
        @berry_checks+=1 if cp; assert_true("Cheek Pouch adds MaxHP 1/3 after Berry effect",cp,"gain="+cp_gain.to_s+" expected="+cp_expect.to_s)
        rp_gain=(e[2] ? e[2].hp.to_i-@r1_e2_hp.to_i : 0); rp=e[2]&&rp_gain==60&&!records_for(ABILITY_RIPEN,:ripen).empty?
        @berry_checks+=1 if rp; assert_true("Ripen doubles 30HP Berry effect to 60HP",rp,"gain="+rp_gain.to_s)
        hv=e[3]&&raw_item_id(e[3])==TEST_ITEM_BERRY_B&&!records_for(ABILITY_HARVEST,:harvest).empty?
        @berry_checks+=1 if hv; assert_true("Harvest restores consumed Berry at end-turn under Sun",hv,"item="+raw_item_id(e[3]).to_s+" record="+(records_for(ABILITY_HARVEST,:harvest)[-1]||{}).inspect)
        cud=a[3]&&raw_item_id(a[3])==0&&a[3].instance_variable_get(:@cg_v2527ab_cud_turns).to_i==1&&!records_for(ABILITY_CUD_CHEW,:cud_chew_arm).empty?
        assert_true("Cud Chew arms Berry and waits through first end-turn",cud,"turns="+(a[3] ? a[3].instance_variable_get(:@cg_v2527ab_cud_turns).to_i.to_s : "nil"))
      elsif r==2
        mg=a[2]&&@r2_magician_target_item.to_i==TEST_ITEM_CHARM&&raw_item_id(a[2])==TEST_ITEM_CHARM&&raw_item_id(e[0])==0&&!records_for(ABILITY_MAGICIAN,:magician).empty?
        @steal_checks+=1 if mg; assert_true("Magician steals target Held Item after real damage",mg,"A2_item="+raw_item_id(a[2]).to_s+" E0_item="+raw_item_id(e[0]).to_s)
        cud_gain=a[3] ? a[3].hp.to_i-@r2_a3_hp.to_i : 0
        cud=a[3]&&cud_gain==25&&raw_item_id(a[3])==0&&!records_for(ABILITY_CUD_CHEW,:cud_chew_repeat).empty?
        @berry_checks+=1 if cud; assert_true("Cud Chew repeats Berry effect on next end-turn without restoring item",cud,"gain="+cud_gain.to_s+" item="+raw_item_id(a[3]).to_s)
        sw=e[3]&&e[4]&&e[3].hidden&&!e[4].hidden
        @lifecycle_checks+=1 if sw; assert_true("Teleport deploys hidden Unnerve reserve",sw,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        iso=storage_size==@r2_storage_before.to_i
        @lifecycle_checks+=1 if iso; assert_true("Unnerve reserve switch does not consume Storage Pokemon",iso,"before="+@r2_storage_before.to_s+" after="+storage_size.to_s)
      elsif r==3
        un=e[4]&&!e[4].hidden&&@r3_unnerve_probe==true&&!records_for(ABILITY_UNNERVE,:unnerve).empty?
        @item_guard_checks+=1 if un; assert_true("Unnerve blocks opposing normal Berry consumption",un,"probe="+@r3_unnerve_probe.to_s)
        expect_hp=[@r3_a1_hp.to_i+30,a[1].maxhp.to_i].min
        tt=a[1]&&a[1].hp.to_i==expect_hp&&raw_item_id(a[1])==0
        @teatime_checks+=1 if tt; assert_true("Teatime bypasses Unnerve and forces opposing Berry consumption",tt,"hp="+@r3_a1_hp.to_s+"->"+(a[1] ? a[1].hp.to_i.to_s : "nil")+" item="+raw_item_id(a[1]).to_s)
        stable=e[4]&&!e[4].hidden&&e[4].hp.to_i>0; assert_true("Unnerve reserve remains active through Round3",stable,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" hp="+(e[4] ? e[4].hp.to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end

    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_ab,nil) if b}; end

    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"
      log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_ab="+ability_covered_count.to_s+"/8 item_guard_checks="+@item_guard_checks.to_i.to_s+" berry_checks="+@berry_checks.to_i.to_s+" teatime_checks="+@teatime_checks.to_i.to_s+" steal_checks="+@steal_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=149")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}
      cleanup_test_overrides; @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end

    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false
      @item_guard_checks=0; @berry_checks=0; @teatime_checks=0; @steal_checks=0; @lifecycle_checks=0
      @r1_klutz_probe=false; @r3_unnerve_probe=false; @r2_storage_before=0
    end

    def self.start_auto_test
      return false if active?
      reset_log; reset_suite; install_test_weapons; prepare_test_party; make_test_troop
      ALBERT_CG::UNIQUE_K_V244.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_K_V244)&&ALBERT_CG::UNIQUE_K_V244.respond_to?(:install_skill_scopes)
      ALBERT_CG::UNIQUE_I_V242.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_I_V242)&&ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes)
      @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AB_v2.5.27b") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
      false
    end
  end
end

# Disable previous newest F11 harness.
if defined?(ALBERT_CG::ABILITY_AA_V2526)
  module ALBERT_CG
    module ABILITY_AA_V2526
      def self.f11_trigger?; false; end
    end
  end
end

ALBERT_CG::ABILITY_AB_V2527.register_handlers if defined?(ALBERT_CG::ABILITY_V250)

#==============================================================================
# ■ Formal Teatime compatibility：Klutz / Unnerve 皆不得阻止 Move 752 強制食用
#==============================================================================
if defined?(ALBERT_CG::UNIQUE_K_V244)
  module ALBERT_CG
    module UNIQUE_K_V244
      class << self
        alias cg_v2527ab_apply_teatime apply_teatime
        def apply_teatime(user)
          return cg_v2527ab_apply_teatime(user) unless defined?(ALBERT_CG::ABILITY_AB_V2527)
          ALBERT_CG::ABILITY_AB_V2527.with_teatime_context do
            cg_v2527ab_apply_teatime(user)
          end
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal Held Item effective-item bridge：Klutz
#==============================================================================
class Game_Battler
  alias cg_v2527ab_held_item cg_held_item
  def cg_held_item
    if defined?(ALBERT_CG::ABILITY_AB_V2527) && ALBERT_CG::ABILITY_AB_V2527.klutz?(self)
      return cg_raw_held_item if ALBERT_CG::ABILITY_AB_V2527.teatime_context?
      return nil
    end
    cg_v2527ab_held_item
  end
end

#==============================================================================
# ■ Formal Berry consume bridge：Klutz / Unnerve / Cheek Pouch / Cud Chew
#==============================================================================
class Game_Battler
  alias cg_v2527ab_consume_held_item cg_consume_held_item
  def cg_consume_held_item(reason=:consume,apply_effect=true)
    if defined?(ALBERT_CG::ABILITY_AB_V2527)
      item=respond_to?(:cg_raw_held_item) ? cg_raw_held_item : nil
      if item!=nil && ALBERT_CG::ABILITY_AB_V2527.berry?(item)
        unless reason==:teatime
          if ALBERT_CG::ABILITY_AB_V2527.klutz?(self)
            ALBERT_CG::ABILITY_AB_V2527.note_klutz_block(self,item.id,reason); return false
          end
          holder=ALBERT_CG::ABILITY_AB_V2527.unnerve_holder_for(self)
          if holder!=nil
            ALBERT_CG::ABILITY_AB_V2527.note_unnerve(holder,self,item.id,reason); return false
          end
        end
        before_hp=hp.to_i
        result=cg_v2527ab_consume_held_item(reason,apply_effect)
        if result
          after_base=hp.to_i
          ALBERT_CG::ABILITY_AB_V2527.after_berry_consumed(self,item,before_hp,after_base,reason)
        end
        return result
      end
    end
    cg_v2527ab_consume_held_item(reason,apply_effect)
  end
end

#==============================================================================
# ■ Formal Ripen：共用 Held Item consumption effect 跑第二次
#==============================================================================
if defined?(ALBERT_CG::HELD_ITEM_V244)
  module ALBERT_CG
    module HELD_ITEM_V244
      class << self
        alias cg_v2527ab_apply_consumption_effect apply_consumption_effect
        def apply_consumption_effect(battler,item)
          result=cg_v2527ab_apply_consumption_effect(battler,item)
          if defined?(ALBERT_CG::ABILITY_AB_V2527) && ALBERT_CG::ABILITY_AB_V2527.apply_ripen_effect(battler,item)
            cg_v2527ab_apply_consumption_effect(battler,item)
          end
          result
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal Sticky Hold：Trick / Switcheroo 共用 swap authority
#==============================================================================
class Game_Battler
  alias cg_v2527ab_swap_held_item_with cg_swap_held_item_with
  def cg_swap_held_item_with(other)
    if defined?(ALBERT_CG::ABILITY_AB_V2527) && other!=nil
      blocker=ALBERT_CG::ABILITY_AB_V2527.item_removal_blocker(other,self,:swap)
      if blocker!=nil
        ALBERT_CG::ABILITY_AB_V2527.note_sticky_block(blocker,self,:swap,ALBERT_CG::ABILITY_AB_V2527.raw_item_id(other)); return false
      end
    end
    cg_v2527ab_swap_held_item_with(other)
  end
end

#==============================================================================
# ■ Formal Magician：positive damage 後偷取 raw Held Item
#==============================================================================
class Game_Battler
  alias cg_v2527ab_execute_damage execute_damage
  def execute_damage(user)
    skill=(defined?(ALBERT_CG::ABILITY_V250) && user!=nil) ? ALBERT_CG::ABILITY_V250.current_skill(user) : nil
    before=hp.to_i
    result=cg_v2527ab_execute_damage(user)
    if defined?(ALBERT_CG::ABILITY_AB_V2527) && user!=nil
      ALBERT_CG::ABILITY_AB_V2527.apply_magician(user,self,[before-hp.to_i,0].max,skill)
    end
    result
  end
end

#==============================================================================
# ■ TEST Scene hooks
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2527ab_execute_action execute_action
  def execute_action
    b=@active_battler
    ALBERT_CG::ABILITY_AB_V2527.record_execution(b) if defined?(ALBERT_CG::ABILITY_AB_V2527)&&ALBERT_CG::ABILITY_AB_V2527.active?
    cg_v2527ab_execute_action
  end

  alias cg_v2527ab_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AB_V2527)&&ALBERT_CG::ABILITY_AB_V2527.active?
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_AB_V2527.finish_round_assertions
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      else
        ALBERT_CG::ABILITY_AB_V2527.finish_round_assertions
      end
    end
    cg_v2527ab_turn_end
  end

  alias cg_v2527ab_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AB_V2527)&&ALBERT_CG::ABILITY_AB_V2527.active?
      return cg_v2527ab_start_party_command
    end
    cg_v2527ab_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_AB_V2527.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AB_V2527.finished?
      ALBERT_CG::ABILITY_AB_V2527.finish_suite; battle_end(0); return
    end
    ALBERT_CG::ABILITY_AB_V2527.prepare_round_actions; start_main
  end
end

class Game_Battler
  alias cg_v2527ab_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AB_V2527)&&ALBERT_CG::ABILITY_AB_V2527.active?
      v=@cg_priority_test_speed_override_ab; return v.to_i if v!=nil
    end
    cg_v2527ab_priority_base_speed
  rescue
    cg_v2527ab_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2527ab_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AB_V2527)&&ALBERT_CG::ABILITY_AB_V2527.active?
      a=ALBERT_CG::ABILITY_AB_V2527.forced_enemy_action(self)
      if a
        cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return
      end
    end
    cg_v2527ab_enemy_make_action
  end
end

module ALBERT_CG
  class << self
    alias cg_v2527ab_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2527ab_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_AB_V2527)&&ALBERT_CG::ABILITY_AB_V2527.active?
        ALBERT_CG::ABILITY_AB_V2527::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AB_V2527.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if h
          h.change_level(ALBERT_CG::ABILITY_AB_V2527::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0)
        end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2527ab_scene_map_update update
  def update
    cg_v2527ab_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_AB_V2527)
    ALBERT_CG::ABILITY_AB_V2527.start_auto_test if ALBERT_CG::ABILITY_AB_V2527.f11_trigger?
  end
end
