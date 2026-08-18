# RMVX_SCRIPT_INDEX: 256
# RMVX_SCRIPT_ID: 253100001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AF v2.5.31a
# RMVX_SOURCE_SHA256: f97fddb6bfa5d3588e479d3149260ceeedff46b5eb86b312ca5a4251dd0c3159

#==============================================================================
# ■ CG Pokemon Ability Batch AF v2.5.31a - Battle Utility / Resource Relay REGRESSION FIX TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.30b Ability Batch AE RPG Maker VX 實機 PASS 為唯一正式基底，新增 8 個
#  尚未覆蓋 Ability，集中處理「爆炸行動封鎖、命中視野、共享 MP 壓迫、回合末撿拾、
#  隔回合行動限制、接觸偷取、隊友道具接力、入場清除雙方牆面」。
#  本批沿用既有 Ability Core、Stat Guard Authority、Held Item Core、Batch AB Item Guard、
#  Unique Move Batch I Teleport 與 Field v2.3.3a；不修改已 PASS Move Core、Ability A..AE，
#  亦不重寫已封版 Tankentai / Sideview 流程。
#
# 【本批 Ability】
#    6 Damp / 濕氣：全場阻止 Self-Destruct / Explosion / Mind Blown / Misty Explosion；
#                    同時抑制 Aftermath 造成的反傷。
#   35 Illuminate / 發光：依現代戰鬥規則阻止外部 Accuracy stage 下降；攻擊時忽略目標
#                         正向 Evasion stage。直接重用 Keen Eye 的 Stat Guard / calc_hit Authority。
#   46 Pressure / 壓迫感：本專案 PP 已正式映射為共享 MP；招式把敵方 Pressure holder
#                         列為實際目標時，每名 holder 額外消耗一次該招 calc_mp_cost。
#   53 Pickup / 撿拾：回合末自身沒有 Held Item 時，從本回合仍在場的 Pokémon 已消耗道具
#                     紀錄中取得一件；F11 為 deterministic 取第一筆，正式遊戲隨機。
#   54 Truant / 懶惰：第一次合法 Move 可行動，下一次 Move loaf，之後交替；換出時清除節拍。
#  124 Pickpocket / 順手牽羊：自身無道具、受到敵方接觸實傷後，偷走攻擊者 Held Item；
#                              尊重 Sticky Hold 與 Held Item owner token。
#  180 Symbiosis / 共生：同側隊友成功消耗 Held Item 且變為空手後，持有者把自己的道具交給隊友。
#  251 Screen Cleaner / 除障：入場時移除雙方 Reflect / Light Screen / Aurora Veil。
#
# 【主要設定項】
#  TEST_TROOP_ID=734；HANDLED_ABILITY_IDS=8。
#  Static coverage：248/373 -> 256/373，pending 125 -> 117。
#  EXPLOSIVE_MOVE_IDS=[120,153,720,802]。
#  TEST_ITEM_BERRY_A=915、TEST_ITEM_BERRY_B=916、TEST_ITEM_CHARM_A=917、
#  TEST_ITEM_CHARM_B=918，只在 F11 runtime 建立，不寫回正式資料庫。
#
# 【機制規則】
#  1. Damp 的爆炸封鎖發生在最外層 Scene_Battle#execute_action，且早於 Tankentai 將 battler
#     標為 active，因此被擋 Action 不會建立動畫、傷害或自爆。Aftermath 則只窄包 Batch N
#     已封版 apply_after_math；偵測到任一 active Damp holder 時直接取消 Aftermath 傷害。
#  2. Illuminate 不另寫第二套命中公式。AF 僅把 Ability 35 加入 Stat Guard Authority 的
#     Accuracy drop match 與 Keen Eye-style positive Evasion ignore，再由原 Authority 計算。
#  3. Pressure 不改招式 base MP cost。每次真正 execute_action 建立 action serial；最終
#     make_targets 完成所有 redirect / Grid / Follow Me 後，只針對實際敵方 Pressure 目標
#     額外扣 `user.calc_mp_cost(skill)`。同一 Action 即使 make_targets 被多次讀取也只扣一次。
#  4. Pressure popup 使用 pre-action-safe presentation：短暫 suspend 實際 acting battler 的
#     Tankentai active/play，再顯示 Ability，避免 Batch Y 已證實的 stale Idle "End" 汙染新 Action。
#  5. Pickup / Symbiosis 只監聽既有 `cg_consume_held_item` 成功結果，不製造假 consume。
#     Item ID 與 owner token 皆沿用 Held Item Core。Pickup 取走後同步清除原 consumer 的
#     last-consumed reference，避免 Recycle 對同一 battle-local item 再次回收。
#  6. 本專案正式戰場為 1 Human + 3 Pokémon 同時參戰，沒有 Showdown doubles adjacency 物件；
#     Pickup 因此採「全 active battlefield」作為本專案 adjacency adaptation，只考慮本回合仍在場者。
#  7. Pickpocket 使用 Ability Core :after_contact，要求 positive damage、holder 存活且空手；
#     若攻擊者 Sticky Hold，直接沿用 Batch AB item_removal_blocker / popup，不硬拆道具。
#  8. Symbiosis 只找 active、同側、非 consumer 的 Ability 180 holder；若 consumer 已被其他
#     Symbiosis 補上道具或 holder 無道具，後續 holder 不再重複轉移。
#  9. Truant 只攔截 Move Action，不攔 Human Guard / 空 Action；換出時由
#     FORCE_SWITCH_V235.clear_switch_out_volatile 外層清除 loaf-next marker。
# 10. Screen Cleaner 只刪 Field state.sides 的 :reflect / :light_screen / :aurora_veil，
#     不碰 Safeguard、Tailwind、Hazards 或其他 round flags。
# 11. v2.5.31a 只修 Regression fixture，不改 AF Formal Runtime：Pressure 的 base MP cost 改由真正
#     Action 觸發後的 Pressure record 驗證，避免 action 尚未綁定時預讀 calc_mp_cost 得到 0；
#     Pickpocket 測試把 Normal Tackle 改為 Flying Aerial Ace，避免 Ghost 容器耿鬼屬性免疫造成 0 傷害。
# 12. F11 Regression 使用真正 Scene_Battle：Round1 實測 Pressure MP、Teatime consumption、
#     Symbiosis、Pickpocket、Pickup；Round2 實測 Damp Self-Destruct block、Illuminate、
#     Truant loaf；Round3 以真實 contact KO 驗 Damp suppress Aftermath，並以 Teleport 真正
#     換入 Screen Cleaner 清除雙方 screens。
#
# 【可調參數】
#  TEST_TROOP_ID、TEST_LEVEL、EXPLOSIVE_MOVE_IDS、TEST items、ROUND_PLANS、TEST_SPEEDS。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫。開發測試：地圖按 F11，自動進 troop 734，跑三回合並輸出
#  Pokemon_Ability_AF_AutoTest_v2_5_31a.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：Tom Water Gun -> Pressure E0，正常 base MP 外再扣一次 base cost；
#          E3 Teatime 讓 A1 / E3 真正吃莓果，E1 Symbiosis 把護符交給 E3；
#          E2 Aerial Ace 接觸 A2，Pickpocket 偷走 E2 護符；turn_end A3 Pickup 撿回 A1 的莓果。
#  Round2：Tom Self-Destruct 被 active E2 Damp 直接取消；A2 Sand Attack -> Illuminate E3
#          Accuracy 不降；E3 Water Gun -> +6 Evasion A2 時忽略正向 Evasion；A1 Truant loaf。
#  Round3：E0 test-only 改成已封版 Aftermath 並固定 HP=1；A2 Aerial Ace 真正 KO E0，
#          E2 Damp 抑制 Aftermath，A2 HP 不變；E1 Teleport -> hidden E4 Screen Cleaner，
#          E4 入場清除 ally/enemy 三種 screens；A1 Truant 恢復正常行動。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAF"] = "2.5.31a"

module ALBERT_CG
  module ABILITY_AF_V2531
    VERSION = "2.5.31a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 734
    VK_F11 = 0x7A

    ABILITY_DAMP           = 6
    ABILITY_ILLUMINATE     = 35
    ABILITY_PRESSURE       = 46
    ABILITY_PICKUP         = 53
    ABILITY_TRUANT         = 54
    ABILITY_PICKPOCKET     = 124
    ABILITY_SYMBIOSIS      = 180
    ABILITY_SCREEN_CLEANER = 251
    ABILITY_AFTERMATH      = 106

    HANDLED_ABILITY_IDS = [6,35,46,53,54,124,180,251]
    EXPLOSIVE_MOVE_IDS = [120,153,720,802]

    TEST_ITEM_BERRY_A = 915
    TEST_ITEM_BERRY_B = 916
    TEST_ITEM_CHARM_A = 917
    TEST_ITEM_CHARM_B = 918

    TEST_ALLIES = [
      {:dex=>143,:level=>40,:ability=>ABILITY_TRUANT,    :moves=>[150,150,150,150]},
      {:dex=>94, :level=>40,:ability=>ABILITY_PICKPOCKET,:moves=>[28,332,150,150]},
      {:dex=>128,:level=>40,:ability=>ABILITY_PICKUP,    :moves=>[150,150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>65, :level=>45,:ability=>ABILITY_PRESSURE,      :moves=>[150,150,150,150]},
      {:dex=>1,  :level=>45,:ability=>ABILITY_SYMBIOSIS,     :moves=>[150,100,150,150]},
      {:dex=>110,:level=>45,:ability=>ABILITY_DAMP,          :moves=>[33,150,150,150]},
      {:dex=>92, :level=>45,:ability=>ABILITY_ILLUMINATE,    :moves=>[752,55,150,150]},
      {:dex=>197,:level=>45,:ability=>ABILITY_SCREEN_CLEANER,:moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"PRESSURE_ITEMS_TRUANT_ACT",
        :allies=>[
          {:kind=>:move,:move_id=>55,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>332,:target=>2},
          3=>{:kind=>:move,:move_id=>752,:target=>3},
        }
      },
      {
        :name=>"DAMP_ILLUMINATE_TRUANT_LOAF",
        :allies=>[
          {:kind=>:move,:move_id=>120,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>3},
          {:kind=>:move,:move_id=>28,:target=>3},
          {:kind=>:move,:move_id=>150,:target=>3},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>55,:target=>2},
        }
      },
      {
        :name=>"DAMP_AFTERMATH_SCREEN_CLEANER_TRUANT_ACT",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>332,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>100,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[500,350,300,250, 200,150,400,450,0],
      :r2=>[500,350,450,300, 250,200,150,400,0],
      :r3=>[500,400,450,350, 300,10,250,200,0],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:M55","E3:M752","E2:M332","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150"],
      2=>["A0:DAMP_BLOCK","A2:M28","E3:M55","A1:LOAF","A3:M150","E0:M150","E1:M150","E2:M150"],
      3=>["A0:Guard","A2:M332","A1:M150","A3:M150","E2:M150","E3:M150","E1:M100"],
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
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.active_battlers; core ? core.active_battlers : []; rescue; []; end
    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AF_AutoTest_v2_5_31a.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.ability_id(b); core==nil || b==nil ? 0 : core.ability_id(b).to_i; rescue; 0; end
    def self.same_side?(a,b); a!=nil&&b!=nil&&a.respond_to?(:actor?)&&b.respond_to?(:actor?)&&a.actor? == b.actor?; rescue; false; end
    def self.opposing?(a,b); a!=nil&&b!=nil&&!same_side?(a,b); rescue; false; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill!=nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.raw_item(b); b&&b.respond_to?(:cg_raw_held_item) ? b.cg_raw_held_item : nil; rescue; nil; end
    def self.raw_item_id(b); x=raw_item(b); x ? x.id.to_i : 0; rescue; 0; end

    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else
        text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text)
      end
      condition
    end

    def self.reset_log
      h="CG POKEMON ABILITY AF BATTLE UTILITY + RESOURCE RELAY AUTO REGRESSION v2.5.31a\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; action block + accuracy authority + MP pressure + Held Item relay + screen cleanup\r\n"+
        "BASELINE=v2.5.30b Ability Batch AE Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AE_PASS=248 BATCH_AF=8 PENDING=117\r\n"+
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
      log("ABILITY_AF_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
      true
    rescue
      false
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

    def self.formal_note_targeting_safe(aid,holder,acting,kind,ctx=nil)
      data=ctx||{}
      was_active=acting!=nil&&acting.respond_to?(:active) ? (acting.active ? true : false) : false
      begin
        acting.active=false if acting!=nil&&was_active&&acting.respond_to?(:active=)
        acting.play=0 if acting!=nil&&acting.respond_to?(:play=)
        formal_note(aid,holder,kind,data)
        acting.play=0 if acting!=nil&&acting.respond_to?(:play=)
      ensure
        acting.active=true if acting!=nil&&was_active&&acting.respond_to?(:active=)
      end
      true
    rescue
      true
    end

    def self.note_authority(aid,holder,kind,ctx=nil)
      k=kind.to_sym==:evasion_ignore ? :illuminate_evasion_ignore : :illuminate_accuracy_guard
      note_local(aid,holder,k,ctx||{})
    end

    def self.records_for(aid,kind=nil)
      list=@records[aid.to_i]||[]; return list if kind==nil; list.select{|r|r[:kind]==kind}
    end

    #--------------------------------------------------------------------------
    # Formal: Damp
    #--------------------------------------------------------------------------
    def self.damp_holder
      active_battlers.each do |b|
        next if b==nil||b.hidden||b.hp.to_i<=0
        return b if ability_id(b)==ABILITY_DAMP
      end
      nil
    rescue
      nil
    end

    def self.explosive_skill?(skill)
      EXPLOSIVE_MOVE_IDS.include?(move_id(skill))
    rescue
      false
    end

    def self.block_explosive_action?(user)
      return nil if user==nil||user.action==nil||!user.action.skill?
      skill=$data_skills[user.action.skill_id] rescue nil
      return nil unless explosive_skill?(skill)
      holder=damp_holder
      return nil if holder==nil
      formal_note(ABILITY_DAMP,holder,:damp_explosive,{:user_index=>(user.respond_to?(:index) ? user.index.to_i : -1),:move_id=>move_id(skill)})
      holder
    rescue
      nil
    end

    def self.suppress_aftermath?(battler,ctx)
      holder=damp_holder
      return false if holder==nil
      user=ctx==nil ? nil : ctx[:user]
      formal_note(ABILITY_DAMP,holder,:damp_aftermath,{:aftermath_holder_index=>(battler&&battler.respond_to?(:index) ? battler.index.to_i : -1),:attacker_index=>(user&&user.respond_to?(:index) ? user.index.to_i : -1)})
      true
    rescue
      false
    end

    #--------------------------------------------------------------------------
    # Formal: Truant / Action serial
    #--------------------------------------------------------------------------
    def self.begin_action(user)
      @action_serial=@action_serial.to_i+1
      user.instance_variable_set(:@cg_v2531af_action_serial,@action_serial) if user
      @action_serial
    rescue
      0
    end

    def self.truant_intercept(user)
      return false if user==nil||ability_id(user)!=ABILITY_TRUANT||user.action==nil||!user.action.skill?
      loaf=user.instance_variable_get(:@cg_v2531af_truant_loaf_next)==true
      if loaf
        user.instance_variable_set(:@cg_v2531af_truant_loaf_next,false)
        skill=$data_skills[user.action.skill_id] rescue nil
        formal_note(ABILITY_TRUANT,user,:truant_loaf,{:move_id=>move_id(skill)})
        return true
      end
      user.instance_variable_set(:@cg_v2531af_truant_loaf_next,true)
      false
    rescue
      false
    end

    def self.clear_truant(b)
      b.instance_variable_set(:@cg_v2531af_truant_loaf_next,false) if b
      true
    rescue
      false
    end

    def self.action_intercept(user)
      return :truant if truant_intercept(user)
      return :damp if block_explosive_action?(user)!=nil
      :continue
    rescue
      :continue
    end

    def self.finish_skipped_action(user)
      return if user==nil
      user.active=false if user.respond_to?(:active=)
      user.play=0 if user.respond_to?(:play=)
    rescue
    end

    #--------------------------------------------------------------------------
    # Formal: Pressure (PP -> shared MP adaptation)
    #--------------------------------------------------------------------------
    def self.apply_pressure_to_targets(action,targets)
      return targets if action==nil||targets==nil
      user=action.respond_to?(:battler) ? action.battler : nil
      user=action.instance_variable_get(:@battler) if user==nil
      return targets if user==nil||user.hp.to_i<=0
      serial=user.instance_variable_get(:@cg_v2531af_action_serial).to_i
      return targets if serial<=0
      return targets if action.instance_variable_get(:@cg_v2531af_pressure_serial).to_i==serial
      action.instance_variable_set(:@cg_v2531af_pressure_serial,serial)
      return targets unless action.skill?
      skill=$data_skills[action.skill_id] rescue nil
      return targets if skill==nil||!user.respond_to?(:calc_mp_cost)
      holders=[]
      targets.compact.uniq.each do |t|
        next if t==nil||t.hidden||t.hp.to_i<=0||same_side?(user,t)
        holders.push(t) if ability_id(t)==ABILITY_PRESSURE
      end
      return targets if holders.empty?
      cost=user.calc_mp_cost(skill).to_i
      return targets if cost<=0
      before=user.mp.to_i
      extra=cost*holders.size
      user.mp=[before-extra,0].max
      holders.each do |holder|
        formal_note_targeting_safe(ABILITY_PRESSURE,holder,user,:pressure,
          {:source_index=>(user.respond_to?(:index) ? user.index.to_i : -1),:move_id=>move_id(skill),
           :base_cost=>cost,:holder_count=>holders.size,:extra_cost=>extra,:mp_before=>before,:mp_after=>user.mp.to_i})
      end
      targets
    rescue
      targets
    end

    #--------------------------------------------------------------------------
    # Formal: consumed-item ledger / Symbiosis / Pickup
    #--------------------------------------------------------------------------
    def self.used_items
      @used_items=[] if @used_items==nil
      @used_items
    end

    def self.note_item_used(consumer,item_id,owner,reason)
      return false if consumer==nil||item_id.to_i<=0
      @used_item_seq=@used_item_seq.to_i+1
      used_items.push({:consumer=>consumer,:item_id=>item_id.to_i,:owner=>owner,:reason=>reason,:seq=>@used_item_seq})
      true
    rescue
      false
    end

    def self.symbiosis_holder_for(consumer)
      active_battlers.each do |b|
        next if b==nil||b==consumer||b.hidden||b.hp.to_i<=0||!same_side?(b,consumer)
        return b if ability_id(b)==ABILITY_SYMBIOSIS&&raw_item(b)!=nil
      end
      nil
    rescue
      nil
    end

    def self.apply_symbiosis_after_consume(consumer)
      return false if consumer==nil||raw_item(consumer)!=nil
      holder=symbiosis_holder_for(consumer)
      return false if holder==nil
      item=raw_item(holder); return false if item==nil
      return false unless consumer.respond_to?(:cg_can_hold_item?)&&consumer.cg_can_hold_item?(item)
      id=item.id.to_i
      owner=holder.respond_to?(:cg_held_item_owner) ? holder.cg_held_item_owner : nil
      return false unless holder.respond_to?(:cg_set_battle_held_item)&&consumer.respond_to?(:cg_set_battle_held_item)
      return false unless holder.cg_set_battle_held_item(0,nil)
      unless consumer.cg_set_battle_held_item(id,owner)
        holder.cg_set_battle_held_item(id,owner); return false
      end
      formal_note(ABILITY_SYMBIOSIS,holder,:symbiosis,{:recipient_index=>(consumer.respond_to?(:index) ? consumer.index.to_i : -1),:item_id=>id})
      true
    rescue
      false
    end

    def self.pickup_candidates(holder)
      used_items.select do |ev|
        c=ev[:consumer]
        c!=nil&&c!=holder&&!c.hidden&&c.hp.to_i>0&&ev[:item_id].to_i>0
      end
    rescue
      []
    end

    def self.apply_pickup(holder,ctx=nil)
      return false if holder==nil||holder.hidden||holder.hp.to_i<=0||raw_item(holder)!=nil
      list=pickup_candidates(holder); return false if list.empty?
      ev=active? ? list.sort_by{|x|x[:seq].to_i}[0] : list[rand(list.size)]
      id=ev[:item_id].to_i; item=$data_weapons==nil ? nil : $data_weapons[id]
      return false if item==nil||!holder.respond_to?(:cg_can_hold_item?)||!holder.cg_can_hold_item?(item)
      owner=ev[:owner]
      return false unless holder.respond_to?(:cg_set_battle_held_item)&&holder.cg_set_battle_held_item(id,owner)
      consumer=ev[:consumer]
      if consumer
        if consumer.instance_variable_get(:@cg_last_consumed_held_item_id).to_i==id &&
           consumer.instance_variable_get(:@cg_last_consumed_held_item_owner)==owner
          consumer.instance_variable_set(:@cg_last_consumed_held_item_id,0)
          consumer.instance_variable_set(:@cg_last_consumed_held_item_owner,nil)
        end
      end
      used_items.delete(ev)
      formal_note(ABILITY_PICKUP,holder,:pickup,{:item_id=>id,:source_index=>(consumer&&consumer.respond_to?(:index) ? consumer.index.to_i : -1)})
      true
    rescue
      false
    end

    def self.clear_used_items
      @used_items=[]
      true
    rescue
      false
    end

    #--------------------------------------------------------------------------
    # Formal: Pickpocket
    #--------------------------------------------------------------------------
    def self.apply_pickpocket(holder,ctx)
      return false if holder==nil||holder.hidden||holder.hp.to_i<=0||ctx==nil||ctx[:damage_done].to_i<=0
      attacker=ctx[:user]; return false if attacker==nil||attacker.hp.to_i<=0||!opposing?(holder,attacker)
      return false if raw_item(holder)!=nil
      item=raw_item(attacker); return false if item==nil
      if defined?(ALBERT_CG::ABILITY_AB_V2527)
        blocker=ALBERT_CG::ABILITY_AB_V2527.item_removal_blocker(attacker,holder,:pickpocket)
        if blocker!=nil
          ALBERT_CG::ABILITY_AB_V2527.note_sticky_block(blocker,holder,:pickpocket,item.id.to_i)
          return false
        end
      end
      return false unless holder.respond_to?(:cg_can_hold_item?)&&holder.cg_can_hold_item?(item)
      id=item.id.to_i
      owner=attacker.respond_to?(:cg_held_item_owner) ? attacker.cg_held_item_owner : nil
      return false unless holder.respond_to?(:cg_set_battle_held_item)&&attacker.respond_to?(:cg_set_battle_held_item)
      return false unless attacker.cg_set_battle_held_item(0,nil)
      unless holder.cg_set_battle_held_item(id,owner)
        attacker.cg_set_battle_held_item(id,owner); return false
      end
      formal_note(ABILITY_PICKPOCKET,holder,:pickpocket,{:item_id=>id,:source_index=>(attacker.respond_to?(:index) ? attacker.index.to_i : -1),:damage_done=>ctx[:damage_done].to_i,:move_id=>ctx[:move_id].to_i})
      true
    rescue
      false
    end

    #--------------------------------------------------------------------------
    # Formal: Screen Cleaner
    #--------------------------------------------------------------------------
    def self.apply_screen_cleaner(holder,ctx=nil)
      return false if holder==nil||field==nil||!field.respond_to?(:state)
      st=field.state; return false if st==nil||st.sides==nil
      removed=[]
      [:ally,:enemy].each do |side|
        h=st.sides[side]; next if h==nil
        [:reflect,:light_screen,:aurora_veil].each do |key|
          if h.has_key?(key)&&h[key].to_i>0
            removed.push(side.to_s+":"+key.to_s); h.delete(key)
          end
        end
      end
      return false if removed.empty?
      formal_note(ABILITY_SCREEN_CLEANER,holder,:screen_cleaner,{:removed=>removed})
      true
    rescue
      false
    end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_PICKUP,:end_turn,self,:apply_pickup)
      core.register(ABILITY_PICKPOCKET,:after_contact,self,:apply_pickpocket)
      core.register(ABILITY_SCREEN_CLEANER,:entry,self,:apply_screen_cleaner)
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
      make_test_weapon(TEST_ITEM_BERRY_A,"AF測試莓果A","<CG_POKEMON_HELD_ITEM>\n<CG_BERRY>\n<CG_HELD_HEAL_HP:10>")
      make_test_weapon(TEST_ITEM_BERRY_B,"AF測試莓果B","<CG_POKEMON_HELD_ITEM>\n<CG_BERRY>\n<CG_HELD_HEAL_HP:12>")
      make_test_weapon(TEST_ITEM_CHARM_A,"AF測試護符A","<CG_POKEMON_HELD_ITEM>")
      make_test_weapon(TEST_ITEM_CHARM_B,"AF測試護符B","<CG_POKEMON_HELD_ITEM>")
      held.sync_class_permissions if held&&held.respond_to?(:sync_class_permissions)
      true
    end

    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages)
      a.cg_v237_clear_identity if a.respond_to?(:cg_v237_clear_identity); a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime)
      clear_truant(a); a.instance_variable_set(:@cg_v2531af_action_serial,0)
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
        h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages)
        h.cg_v237_clear_identity if h.respond_to?(:cg_v237_clear_identity); h.instance_variable_set(:@cg_master_ability_id,0)
        clear_truant(h); h.instance_variable_set(:@cg_v2531af_action_serial,0)
      end
    end

    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2]]
      ms=[]
      TEST_ENEMIES.each_with_index do |c,i|
        configure_enemy(c)
        m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=(i>=4); ms.push(m)
      end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AF v2.5.31a AutoRegression",ms)
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
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_af,vals[i]) if b}
    end

    def self.set_test_item(b,id)
      return false if b==nil||!b.respond_to?(:cg_set_battle_held_item)
      owner=b.respond_to?(:cg_held_item_owner_key) ? b.cg_held_item_owner_key : nil
      b.cg_set_battle_held_item(id,owner)
    rescue
      false
    end

    def self.clear_item(b)
      b.cg_set_battle_held_item(0,nil) if b&&b.respond_to?(:cg_set_battle_held_item)
    rescue
    end

    def self.set_effective_ability(b,aid)
      return false if b==nil
      if b.respond_to?(:cg_v237_set_ability)
        b.cg_v237_set_ability(aid.to_i); return ability_id(b)==aid.to_i
      end
      b.instance_variable_set(:@cg_v237_ability_override,aid.to_i)
      b.instance_variable_set(:@cg_v237_ability_suppressed,false)
      ability_id(b)==aid.to_i
    rescue
      false
    end

    def self.prepare_round_preconditions
      a=test_allies; e=all_enemies
      if current_round==1
        clear_used_items
        (a+e).each{|b|clear_item(b) if b}
        set_test_item(a[1],TEST_ITEM_BERRY_A)
        set_test_item(e[1],TEST_ITEM_CHARM_A)
        set_test_item(e[2],TEST_ITEM_CHARM_B)
        set_test_item(e[3],TEST_ITEM_BERRY_B)
        if a[0]
          a[0].mp=a[0].maxmp
          @r1_a0_mp_before=a[0].mp.to_i
        end
        @r1_storage_before=storage_size
      elsif current_round==2
        if a[2]&&a[2].respond_to?(:cg_change_stat_stage)
          a[2].cg_change_stat_stage(:evasion,6)
        end
        @r2_a2_evasion=a[2]&&a[2].respond_to?(:cg_stat_stage) ? a[2].cg_stat_stage(:evasion).to_i : 0
        @r2_e3_acc=e[3]&&e[3].respond_to?(:cg_stat_stage) ? e[3].cg_stat_stage(:accuracy).to_i : 0
        @r2_a2_hp_before=a[2] ? a[2].hp.to_i : 0
        @r2_a0_hp_before=a[0] ? a[0].hp.to_i : 0
      elsif current_round==3
        set_effective_ability(e[0],ABILITY_AFTERMATH) if e[0]
        if e[0]
          e[0].hp=1
          e[0].instance_variable_set(:@collapse,false)
        end
        st=field&&field.respond_to?(:state) ? field.state : nil
        if st&&st.sides
          st.sides[:ally][:reflect]=5
          st.sides[:ally][:light_screen]=5
          st.sides[:enemy][:aurora_veil]=5
        end
        @r3_a2_hp_before=a[2] ? a[2].hp.to_i : 0
        @r3_storage_before=storage_size
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

    def self.record_execution(b,outcome=:continue)
      return unless active?&&b
      tok=(b.actor? ? "A" : "E")+b.index.to_s
      if outcome==:truant
        tok+=":LOAF"
      elsif outcome==:damp
        tok+=":DAMP_BLOCK"
      else
        a=b.action
        if a&&a.guard?; tok+=":Guard"
        elsif a&&a.skill?; sk=$data_skills[a.skill_id]; tok+=":M"+move_id(sk).to_s
        else; tok+=":Other"; end
      end
      @actual.push(tok); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    end

    def self.assert_bootstrap_once
      return if @boot_asserted==true; @boot_asserted=true
      assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil"))
      assert_true("Ability Batch AF defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability AF test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil"))
      assert_true("Ability AF ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability AF starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden&&b.hp.to_i>0})
      assert_true("Ability AF starts with hidden Screen Cleaner reserve",all_enemies[4]&&all_enemies[4].hidden)
      grid_ok=test_allies[2]&&all_enemies[0]&&test_allies[2].respond_to?(:cg_front_row?)&&all_enemies[0].respond_to?(:cg_front_row?)&&test_allies[2].cg_front_row?&&all_enemies[0].cg_front_row?
      assert_true("Aftermath contact fixture is Grid-legal",grid_ok,"A2="+(test_allies[2]&&test_allies[2].respond_to?(:cg_grid_label) ? test_allies[2].cg_grid_label.to_s : "nil")+" E0="+(all_enemies[0]&&all_enemies[0].respond_to?(:cg_grid_label) ? all_enemies[0].cg_grid_label.to_s : "nil"))
    end

    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==exp,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        pr=records_for(ABILITY_PRESSURE,:pressure)[-1]||{}
        pressure_base=pr[:base_cost].to_i
        pressure_ok=!pr.empty?&&pressure_base>0&&pr[:extra_cost].to_i==pressure_base&&a[0]&&a[0].mp.to_i==@r1_a0_mp_before.to_i-pressure_base*2
        @pressure_checks+=1 if pressure_ok
        assert_true("Pressure adds one extra base MP cost when targeting one opposing holder",pressure_ok,"record="+pr.inspect+" mp="+@r1_a0_mp_before.to_s+"->"+(a[0] ? a[0].mp.to_i.to_s : "nil"))

        sy=records_for(ABILITY_SYMBIOSIS,:symbiosis)[-1]||{}
        sy_ok=!sy.empty?&&sy[:recipient_index].to_i==3&&raw_item_id(e[1])==0&&raw_item_id(e[3])==TEST_ITEM_CHARM_A
        @item_checks+=1 if sy_ok; assert_true("Symbiosis transfers holder item after ally consumes Berry",sy_ok,"record="+sy.inspect+" E1_item="+raw_item_id(e[1]).to_s+" E3_item="+raw_item_id(e[3]).to_s)

        pp=records_for(ABILITY_PICKPOCKET,:pickpocket)[-1]||{}
        pp_ok=!pp.empty?&&pp[:item_id].to_i==TEST_ITEM_CHARM_B&&raw_item_id(a[2])==TEST_ITEM_CHARM_B&&raw_item_id(e[2])==0
        @item_checks+=1 if pp_ok; assert_true("Pickpocket steals attacker Held Item after real contact damage",pp_ok,"record="+pp.inspect+" A2_item="+raw_item_id(a[2]).to_s+" E2_item="+raw_item_id(e[2]).to_s)

        pu=records_for(ABILITY_PICKUP,:pickup)[-1]||{}
        pu_ok=!pu.empty?&&pu[:item_id].to_i==TEST_ITEM_BERRY_A&&raw_item_id(a[3])==TEST_ITEM_BERRY_A
        @item_checks+=1 if pu_ok; assert_true("Pickup obtains a same-turn consumed Held Item at end-turn",pu_ok,"record="+pu.inspect+" A3_item="+raw_item_id(a[3]).to_s)

        first_act=a[1]&&a[1].instance_variable_get(:@cg_v2531af_truant_loaf_next)==true
        assert_true("Truant arms loaf-next after first allowed Move",first_act)
      elsif r==2
        de=records_for(ABILITY_DAMP,:damp_explosive)[-1]||{}
        damp_ok=!de.empty?&&de[:move_id].to_i==120&&a[0]&&a[0].hp.to_i==@r2_a0_hp_before.to_i
        @action_checks+=1 if damp_ok; assert_true("Damp blocks Self-Destruct before damage/self-KO",damp_ok,"record="+de.inspect+" A0_hp="+@r2_a0_hp_before.to_s+"->"+(a[0] ? a[0].hp.to_i.to_s : "nil"))

        loaf=records_for(ABILITY_TRUANT,:truant_loaf)[-1]||{}
        loaf_ok=!loaf.empty?&&loaf[:move_id].to_i==150&&a[1]&&a[1].instance_variable_get(:@cg_v2531af_truant_loaf_next)!=true
        @action_checks+=1 if loaf_ok; assert_true("Truant skips the second Move and resets alternating marker",loaf_ok,"record="+loaf.inspect)

        ag=records_for(ABILITY_ILLUMINATE,:illuminate_accuracy_guard)[-1]||{}
        guard_ok=!ag.empty?&&e[3]&&e[3].respond_to?(:cg_stat_stage)&&e[3].cg_stat_stage(:accuracy).to_i==@r2_e3_acc.to_i
        @accuracy_checks+=1 if guard_ok; assert_true("Illuminate blocks external Accuracy drop",guard_ok,"record="+ag.inspect+" stage="+(e[3] ? e[3].cg_stat_stage(:accuracy).to_i.to_s : "nil"))

        ev=records_for(ABILITY_ILLUMINATE,:illuminate_evasion_ignore)[-1]||{}
        ev_ok=!ev.empty?&&ev[:evasion_stage].to_i==6&&a[2]&&a[2].hp.to_i<@r2_a2_hp_before.to_i
        @accuracy_checks+=1 if ev_ok; assert_true("Illuminate ignores target positive Evasion stage on attack",ev_ok,"record="+ev.inspect+" hp="+@r2_a2_hp_before.to_s+"->"+(a[2] ? a[2].hp.to_i.to_s : "nil"))
      elsif r==3
        da=records_for(ABILITY_DAMP,:damp_aftermath)[-1]||{}
        damp_after=!da.empty?&&e[0]&&e[0].hp.to_i<=0&&a[2]&&a[2].hp.to_i==@r3_a2_hp_before.to_i
        @action_checks+=1 if damp_after; assert_true("Damp suppresses sealed Aftermath damage after real contact KO",damp_after,"record="+da.inspect+" A2_hp="+@r3_a2_hp_before.to_s+"->"+(a[2] ? a[2].hp.to_i.to_s : "nil"))

        truant_back=a[1]&&a[1].instance_variable_get(:@cg_v2531af_truant_loaf_next)==true
        @action_checks+=1 if truant_back; assert_true("Truant allows the third Move after loaf turn",truant_back)

        sc=records_for(ABILITY_SCREEN_CLEANER,:screen_cleaner)[-1]||{}
        st=field&&field.respond_to?(:state) ? field.state : nil
        screens_clear=st&&st.sides&&[:ally,:enemy].all?{|side|[:reflect,:light_screen,:aurora_veil].all?{|k|!st.sides[side].has_key?(k)||st.sides[side][k].to_i<=0}}
        field_ok=!sc.empty?&&screens_clear
        @field_checks+=1 if field_ok; assert_true("Screen Cleaner removes Reflect/Light Screen/Aurora Veil from both sides on entry",field_ok,"record="+sc.inspect)

        sw=e[1]&&e[4]&&e[1].hidden&&!e[4].hidden
        @lifecycle_checks+=1 if sw; assert_true("Teleport deploys hidden Screen Cleaner reserve",sw,"E1_hidden="+(e[1] ? e[1].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        iso=storage_size==@r3_storage_before.to_i
        @lifecycle_checks+=1 if iso; assert_true("Screen Cleaner reserve switch does not consume Storage Pokemon",iso,"before="+@r3_storage_before.to_s+" after="+storage_size.to_s)
      end
      log("ROUND "+r.to_s+" END")
    end

    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides
      (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_af,nil) if b}
    end

    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"
      log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_af="+ability_covered_count.to_s+"/8 action_checks="+@action_checks.to_i.to_s+" item_checks="+@item_checks.to_i.to_s+" pressure_checks="+@pressure_checks.to_i.to_s+" accuracy_checks="+@accuracy_checks.to_i.to_s+" field_checks="+@field_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=117")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}
      cleanup_test_overrides; @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end

    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false
      @action_checks=0; @item_checks=0; @pressure_checks=0; @accuracy_checks=0; @field_checks=0; @lifecycle_checks=0
      @used_items=[]; @used_item_seq=0; @action_serial=0
      @r1_pressure_base_cost=0; @r1_a0_mp_before=0; @r1_storage_before=0
      @r2_a2_evasion=0; @r2_e3_acc=0; @r2_a2_hp_before=0; @r2_a0_hp_before=0
      @r3_a2_hp_before=0; @r3_storage_before=0
    end

    def self.begin_battle
      @used_items=[]; @used_item_seq=0; @action_serial=0
      list=[]
      list += $game_party.members if $game_party
      list += $game_troop.members if $game_troop
      list.each{|b|clear_truant(b); b.instance_variable_set(:@cg_v2531af_action_serial,0) if b}
      true
    rescue
      false
    end

    def self.start_auto_test
      return false if active?
      reset_log; reset_suite; install_test_weapons; prepare_test_party; make_test_troop; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AF_v2.5.31a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
      false
    end
  end
end

#==============================================================================
# ■ Formal registration
#==============================================================================
ALBERT_CG::ABILITY_AF_V2531.register_handlers if defined?(ALBERT_CG::ABILITY_AF_V2531)

#==============================================================================
# ■ Illuminate：重用 Stat Guard / Keen Eye hit Authority
#==============================================================================
if defined?(ALBERT_CG::ABILITY_STAT_GUARD_V256)
  module ALBERT_CG
    module ABILITY_STAT_GUARD_V256
      class << self
        alias cg_v2531af_stat_guard_matches stat_guard_matches?
        def stat_guard_matches?(aid,key)
          return true if aid.to_i==ALBERT_CG::ABILITY_AF_V2531::ABILITY_ILLUMINATE&&key.to_sym==:accuracy
          cg_v2531af_stat_guard_matches(aid,key)
        end

        alias cg_v2531af_keen_eye_ignore_evasion keen_eye_ignore_evasion?
        def keen_eye_ignore_evasion?(user,target)
          if defined?(ALBERT_CG::ABILITY_AF_V2531)&&
             ALBERT_CG::ABILITY_AF_V2531.ability_id(user)==ALBERT_CG::ABILITY_AF_V2531::ABILITY_ILLUMINATE&&
             target!=nil&&target.respond_to?(:cg_stat_stage)&&target.cg_stat_stage(:evasion).to_i>0
            return true
          end
          cg_v2531af_keen_eye_ignore_evasion(user,target)
        end

        alias cg_v2531af_note_activation note_activation
        def note_activation(battler,aid,kind,context=nil)
          r=cg_v2531af_note_activation(battler,aid,kind,context)
          if defined?(ALBERT_CG::ABILITY_AF_V2531)&&aid.to_i==ALBERT_CG::ABILITY_AF_V2531::ABILITY_ILLUMINATE&&
             [:stat_guard,:evasion_ignore].include?(kind.to_sym)
            ALBERT_CG::ABILITY_AF_V2531.note_authority(aid,battler,kind,context)
          end
          r
        end
      end
    end
  end
end

#==============================================================================
# ■ Pressure：最終 target list 後額外扣 shared MP
#==============================================================================
class Game_BattleAction
  alias cg_v2531af_pressure_make_targets make_targets
  def make_targets
    targets=cg_v2531af_pressure_make_targets
    if defined?(ALBERT_CG::ABILITY_AF_V2531)
      targets=ALBERT_CG::ABILITY_AF_V2531.apply_pressure_to_targets(self,targets)
    end
    targets
  end
end

#==============================================================================
# ■ Held Item consumption：used-item ledger + Symbiosis
#==============================================================================
class Game_Battler
  alias cg_v2531af_consume_held_item cg_consume_held_item
  def cg_consume_held_item(reason=:consume,apply_effect=true)
    item_before=cg_held_item rescue nil
    id_before=item_before==nil ? 0 : item_before.id.to_i
    owner_before=respond_to?(:cg_held_item_owner) ? cg_held_item_owner : nil
    result=cg_v2531af_consume_held_item(reason,apply_effect)
    if result&&id_before>0&&defined?(ALBERT_CG::ABILITY_AF_V2531)
      ALBERT_CG::ABILITY_AF_V2531.note_item_used(self,id_before,owner_before,reason)
      ALBERT_CG::ABILITY_AF_V2531.apply_symbiosis_after_consume(self)
    end
    result
  end
end

#==============================================================================
# ■ Damp：只窄包已封版 Aftermath handler
#==============================================================================
if defined?(ALBERT_CG::ABILITY_N_V2513)
  module ALBERT_CG
    module ABILITY_N_V2513
      class << self
        alias cg_v2531af_apply_after_math apply_after_math
        def apply_after_math(battler,ctx)
          if defined?(ALBERT_CG::ABILITY_AF_V2531)&&ALBERT_CG::ABILITY_AF_V2531.suppress_aftermath?(battler,ctx)
            return false
          end
          cg_v2531af_apply_after_math(battler,ctx)
        end
      end
    end
  end
end

#==============================================================================
# ■ Truant switch-out cleanup
#==============================================================================
if defined?(ALBERT_CG::FORCE_SWITCH_V235)
  module ALBERT_CG
    module FORCE_SWITCH_V235
      class << self
        alias cg_v2531af_clear_switch_out_volatile clear_switch_out_volatile
        def clear_switch_out_volatile(battler)
          ALBERT_CG::ABILITY_AF_V2531.clear_truant(battler) if defined?(ALBERT_CG::ABILITY_AF_V2531)
          cg_v2531af_clear_switch_out_volatile(battler)
        end
      end
    end
  end
end

#==============================================================================
# ■ End-turn used-item ledger：先讓 Pickup handler 看本回合資料，再清除
#==============================================================================
if defined?(ALBERT_CG::ABILITY_V250)
  module ALBERT_CG
    module ABILITY_V250
      class << self
        alias cg_v2531af_trigger_end_turn trigger_end_turn
        def trigger_end_turn
          r=cg_v2531af_trigger_end_turn
          ALBERT_CG::ABILITY_AF_V2531.clear_used_items if defined?(ALBERT_CG::ABILITY_AF_V2531)
          r
        end
      end
    end
  end
end

#==============================================================================
# ■ Scene lifecycle / action intercept
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2531af_start start
  def start
    ALBERT_CG::ABILITY_AF_V2531.begin_battle if defined?(ALBERT_CG::ABILITY_AF_V2531)
    cg_v2531af_start
  end

  alias cg_v2531af_execute_action execute_action
  def execute_action
    b=@active_battler
    outcome=:continue
    if defined?(ALBERT_CG::ABILITY_AF_V2531)
      ALBERT_CG::ABILITY_AF_V2531.begin_action(b)
      outcome=ALBERT_CG::ABILITY_AF_V2531.action_intercept(b)
      ALBERT_CG::ABILITY_AF_V2531.record_execution(b,outcome) if ALBERT_CG::ABILITY_AF_V2531.active?
      if outcome!=:continue
        ALBERT_CG::ABILITY_AF_V2531.finish_skipped_action(b)
        return
      end
    end
    cg_v2531af_execute_action
  end
end

# Disable previous newest F11 harness.
if defined?(ALBERT_CG::ABILITY_AE_V2530)
  module ALBERT_CG
    module ABILITY_AE_V2530
      def self.f11_trigger?; false; end
    end
  end
end

#==============================================================================
# ■ TEST Scene hooks
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2531af_test_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AF_V2531)&&ALBERT_CG::ABILITY_AF_V2531.active?
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_AF_V2531.finish_round_assertions
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      else
        ALBERT_CG::ABILITY_AF_V2531.finish_round_assertions
      end
    end
    cg_v2531af_test_turn_end
  end

  alias cg_v2531af_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AF_V2531)&&ALBERT_CG::ABILITY_AF_V2531.active?
      return cg_v2531af_start_party_command
    end
    cg_v2531af_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_AF_V2531.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AF_V2531.finished?
      ALBERT_CG::ABILITY_AF_V2531.finish_suite; battle_end(0); return
    end
    ALBERT_CG::ABILITY_AF_V2531.prepare_round_actions; start_main
  end
end

class Game_Battler
  alias cg_v2531af_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AF_V2531)&&ALBERT_CG::ABILITY_AF_V2531.active?
      v=@cg_priority_test_speed_override_af; return v.to_i if v!=nil
    end
    cg_v2531af_priority_base_speed
  rescue
    cg_v2531af_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2531af_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AF_V2531)&&ALBERT_CG::ABILITY_AF_V2531.active?
      a=ALBERT_CG::ABILITY_AF_V2531.forced_enemy_action(self)
      if a
        cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return
      end
    end
    cg_v2531af_enemy_make_action
  end
end

module ALBERT_CG
  class << self
    alias cg_v2531af_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2531af_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_AF_V2531)&&ALBERT_CG::ABILITY_AF_V2531.active?
        ALBERT_CG::ABILITY_AF_V2531::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AF_V2531.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if h
          h.change_level(ALBERT_CG::ABILITY_AF_V2531::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages)
          h.cg_v237_clear_identity if h.respond_to?(:cg_v237_clear_identity); h.instance_variable_set(:@cg_master_ability_id,0)
          ALBERT_CG::ABILITY_AF_V2531.clear_truant(h); h.instance_variable_set(:@cg_v2531af_action_serial,0)
        end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2531af_scene_map_update update
  def update
    cg_v2531af_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_AF_V2531)
    ALBERT_CG::ABILITY_AF_V2531.start_auto_test if ALBERT_CG::ABILITY_AF_V2531.f11_trigger?
  end
end
