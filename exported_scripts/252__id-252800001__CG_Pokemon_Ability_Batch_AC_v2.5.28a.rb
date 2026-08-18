# RMVX_SCRIPT_INDEX: 252
# RMVX_SCRIPT_ID: 252800001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AC v2.5.28a
# RMVX_SOURCE_SHA256: b7c6eb18831bb77b1086ccf6c40050841d8d85bfd8fe031161e4e175a69e8d83

#==============================================================================
# ■ CG Pokemon Ability Batch AC v2.5.28a - Roar Priority Expectation Fix TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.27b Ability Batch AB RPG Maker VX 實機 PASS 為唯一正式基底，新增 8 個
#  尚未覆蓋的主系列 Ability，集中處理「限制免疫、強制換位防護、睡眠縮短、入場資訊、
#  隊友狀態治療、威嚇反應」。沿用既有 Ability Core、Status Guard、Unique B Taunt、
#  Force Switch v2.3.5a、Held Item v2.4.4 與 Stat Stage Authority，不修改已 PASS Move Core。
#
# 【本批 Ability】
#   12 Oblivious / 遲鈍：免疫 Taunt；依現代規則免疫 Intimidate 的 ATK 下降。
#   21 Suction Cups / 吸盤：阻止 Roar / Whirlwind / Dragon Tail / Circle Throw 類強制換出。
#   48 Early Bird / 早起：Sleep 套用後將剩餘睡眠回合約減半，至少保留 1 回合。
#  107 Anticipation / 危險預知：入場時若對手持有超有效或 OHKO 招式則觸發提示。
#  108 Forewarn / 預知夢：入場時找出對手目前已知招式中最高基礎威力者並提示。
#  119 Frisk / 察覺：入場時揭示 active 對手目前 raw Held Item。
#  131 Healer / 治癒之心：end-turn 30% 機率治癒一名同側 active 隊友的主要異常狀態。
#  275 Guard Dog / 看門犬：阻止強制換出；受到 Intimidate 時不降 ATK，反而 ATK +1。
#
# 【主要設定項】
#  TEST_TROOP_ID=731；HANDLED_ABILITY_IDS=8。
#  Static coverage：224/373 -> 232/373，pending 149 -> 141。
#  HEALER_CHANCE=30；TEST_FRISK_ITEM=914，只在 F11 測試建立。
#
# 【機制規則】
#  1. Ability 有效性一律讀 ALBERT_CG::ABILITY_V250.ability_id，尊重 Battle-only override /
#     suppression；Force Switch 舊 core 對 21/275 的 raw ability 判斷由本頁最外層校正。
#  2. Oblivious 不重寫 Taunt Move；只包既有 Game_Battler#cg_v234_set_taunt setter。
#     本專案目前 Attract 仍走 Generic Core、沒有獨立 infatuation lifecycle，因此本版不虛構
#     第二套 attraction state；未來 Attract Authority 正式化時可直接接同一 Oblivious guard。
#  3. Early Bird 不重建 Sleep 系統；在既有 add_state 完成後只縮短 @state_turns[STATE_SLEEP]。
#  4. Anticipation / Forewarn 只讀 battler.cg_v234_known_move_ids 與 Master Move Catalog；
#     不改 AI、不偷看倉庫技能。Anticipation 以本作 cg_pokemon_type_rate_percent >100 判超有效。
#  5. Frisk 只讀 active 對手的 cg_raw_held_item，不搬移或消耗物品。
#  6. Healer 只治療「自己以外」同側 active ally；正式 RNG 30%。F11 Round1 強制 proc 以確定性驗證。
#  7. Guard Dog 與 Oblivious 透過既有 Intimidate target loop 免疫 ATK↓；Guard Dog 再由正式
#     cg_change_stat_stage(:atk,+1) 加一階，不直接改 @cg_stat_stages。
#  8. Suction Cups / Guard Dog 強制換出防護直接沿用 FORCE_SWITCH_V235.force_switch，
#     不建立第二套 reserve；正式 1+3 玩家側仍沒有免費 battle reserve。
#  9. F11 Regression 使用真正 Scene_Battle、Roar、Taunt、Spore、Teleport 與 end-turn；
#     入場資訊 Ability 由 Ability Core :entry lifecycle 真正觸發。
# 10. v2.5.28a 僅修正 Regression execution-order expectation：Roar／吼叫 Move 46 在封版
#     Master Data 的 priority=-6，因此 Round1 / Round3 必須位於所有 priority 0 Action 之後。
#     Formal Ability handler、Force Switch、Sleep、Entry、Healer 與 Intimidate bridge 完全不修改。
#
# 【可調參數】
#  HEALER_CHANCE=30；EARLY_BIRD_DIVISOR=2；TEST_TROOP_ID；TEST_FRISK_ITEM。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫。開發測試：地圖按 F11，自動進 troop 731，跑三回合並輸出
#  Pokemon_Ability_AC_AutoTest_v2_5_28a.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：A1 Roar(priority -6) 正確最後行動，E0 Suction Cups 擋 Roar；E1 Taunt -> A1 Oblivious 被阻擋；E2 Spore ->
#          A2 Early Bird Sleep turns 2->1；battle-start 真正觸發 Anticipation / Forewarn / Frisk；
#          pre-round Intimidate probe 驗 Oblivious 不降 ATK；end-turn Healer 治癒 A1 Poison。
#  Round2：E3 Teleport -> hidden E4 Guard Dog，驗 Storage isolation。
#  Round3：pre-round Intimidate probe 驗 Guard Dog ATK 0->+1；A1 Roar(priority -6) 最後行動 -> E4 被 Guard Dog
#          擋住並保持 active，hidden E3 reserve 不被換回。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAC"] = "2.5.28a"

module ALBERT_CG
  module ABILITY_AC_V2528
    VERSION = "2.5.28a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 731
    VK_F11 = 0x7A

    ABILITY_OBLIVIOUS    = 12
    ABILITY_SUCTION_CUPS = 21
    ABILITY_EARLY_BIRD   = 48
    ABILITY_ANTICIPATION = 107
    ABILITY_FOREWARN     = 108
    ABILITY_FRISK        = 119
    ABILITY_HEALER       = 131
    ABILITY_GUARD_DOG    = 275
    HANDLED_ABILITY_IDS = [12,21,48,107,108,119,131,275]

    HEALER_CHANCE = 30
    EARLY_BIRD_DIVISOR = 2
    TEST_FRISK_ITEM = 914
    OHKO_MOVE_IDS = [12,32,90,329]

    TEST_ALLIES = [
      {:dex=>128,:level=>40,:ability=>ABILITY_OBLIVIOUS, :moves=>[46,89,150,150]},
      {:dex=>85, :level=>40,:ability=>ABILITY_EARLY_BIRD,:moves=>[63,150,150,150]},
      {:dex=>113,:level=>40,:ability=>ABILITY_HEALER,     :moves=>[150,150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>224,:level=>50,:ability=>ABILITY_SUCTION_CUPS,:moves=>[150,150,150,150]},
      {:dex=>92, :level=>50,:ability=>ABILITY_ANTICIPATION,:moves=>[269,150,150,150]},
      {:dex=>96, :level=>50,:ability=>ABILITY_FOREWARN,    :moves=>[147,150,150,150]},
      {:dex=>353,:level=>50,:ability=>ABILITY_FRISK,       :moves=>[150,100,150,150]},
      {:dex=>59, :level=>50,:ability=>ABILITY_GUARD_DOG,   :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"ENTRY_GUARDS_EARLY_BIRD_HEALER",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>46,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>269,:target=>1},
          2=>{:kind=>:move,:move_id=>147,:target=>2},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"GUARD_DOG_RESERVE_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
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
        :name=>"GUARD_DOG_INTIMIDATE_AND_FORCE_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>46,:target=>4},
          {:kind=>:move,:move_id=>150,:target=>4},
          {:kind=>:move,:move_id=>150,:target=>4},
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
      :r1=>[10,350,340,300, 180,330,320,170,0],
      :r2=>[10,300,290,280, 260,250,240,10,0],
      :r3=>[10,340,300,290, 250,240,230,0,330],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A2:M150","E1:M269","E2:M147","A3:M150","E0:M150","E3:M150","A1:M46"],
      2=>["A0:Guard","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","E4:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","A1:M46"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.move_effect; defined?(ALBERT_CG::MOVE_EFFECT) ? ALBERT_CG::MOVE_EFFECT : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.active_battlers; core ? core.active_battlers : []; rescue; []; end
    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AC_AutoTest_v2_5_28a.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.ability_id(b); core==nil || b==nil ? 0 : core.ability_id(b).to_i; rescue; 0; end
    def self.same_side?(a,b); a!=nil && b!=nil && a.respond_to?(:actor?) && b.respond_to?(:actor?) && a.actor? == b.actor?; rescue; false; end
    def self.opponents_of(b); core ? core.opponents_of(b) : []; rescue; []; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill!=nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end

    def self.note_trigger(aid,battler,kind,ctx=nil,present=true)
      context=ctx==nil ? {} : ctx
      @ability_trigger_counts={} if @ability_trigger_counts==nil
      @records={} if @records==nil
      @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1
      @records[aid.to_i]=[] if @records[aid.to_i]==nil
      rec=context.clone rescue context
      rec[:ability]=aid.to_i; rec[:kind]=kind
      @records[aid.to_i].push(rec)
      if core
        core.runtime_log("ABILITY_AC_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect)
        core.note_trigger(kind,battler,aid,rec)
        core.present_trigger(battler,aid,kind,rec) if present
      end
      log("ABILITY_AC_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect) if active?
      true
    rescue
      false
    end

    def self.records_for(aid,kind=nil)
      arr=@records&&@records[aid.to_i] ? @records[aid.to_i] : []
      return arr if kind==nil
      arr.select{|r|r[:kind].to_sym==kind.to_sym}
    rescue
      []
    end

    def self.known_move_ids(battler)
      return [] if battler==nil
      if battler.respond_to?(:cg_v234_known_move_ids)
        ids=battler.cg_v234_known_move_ids
        return ids==nil ? [] : ids.collect{|x|x.to_i}.select{|x|x>0}
      end
      return []
    rescue
      []
    end

    def self.move_row(mid)
      master&&master.respond_to?(:move) ? master.move(mid.to_i) : nil
    rescue
      nil
    end

    def self.apply_anticipation(battler,ctx)
      return false if battler==nil
      threat=nil
      opponents_of(battler).each do |opp|
        known_move_ids(opp).each do |mid|
          row=move_row(mid); next if row==nil
          power=row[3].to_i; type=row[2]
          ohko=OHKO_MOVE_IDS.include?(mid.to_i)
          rate=battler.respond_to?(:cg_pokemon_type_rate_percent) ? battler.cg_pokemon_type_rate_percent(type).to_i : 100
          if ohko || (power>0 && rate>100)
            threat={:move_id=>mid.to_i,:source_index=>opp.index.to_i,:type=>type,:type_rate=>rate,:ohko=>ohko}
            break
          end
        end
        break if threat!=nil
      end
      return false if threat==nil
      note_trigger(ABILITY_ANTICIPATION,battler,:anticipation,threat,true)
      true
    end

    def self.apply_forewarn(battler,ctx)
      return false if battler==nil
      best=nil
      opponents_of(battler).each do |opp|
        known_move_ids(opp).each do |mid|
          row=move_row(mid); next if row==nil
          power=row[3].to_i
          power=160 if OHKO_MOVE_IDS.include?(mid.to_i)
          rec={:move_id=>mid.to_i,:source_index=>opp.index.to_i,:power=>power}
          best=rec if best==nil || rec[:power].to_i>best[:power].to_i || (rec[:power].to_i==best[:power].to_i && rec[:move_id].to_i<best[:move_id].to_i)
        end
      end
      return false if best==nil
      note_trigger(ABILITY_FOREWARN,battler,:forewarn,best,true)
      true
    end

    def self.apply_frisk(battler,ctx)
      return false if battler==nil
      found=[]
      opponents_of(battler).each do |opp|
        item=opp.respond_to?(:cg_raw_held_item) ? opp.cg_raw_held_item : nil
        found.push([opp.index.to_i,item.id.to_i]) if item!=nil
      end
      return false if found.empty?
      note_trigger(ABILITY_FRISK,battler,:frisk,{:items=>found},true)
      true
    end

    def self.apply_healer(battler,ctx)
      return false if battler==nil || battler.hp.to_i<=0 || battler.hidden
      candidates=[]
      active_battlers.each do |b|
        next if b==nil || b==battler || !same_side?(b,battler) || b.hidden || b.hp.to_i<=0
        if move_effect
          move_effect::PRIMARY_STATES.each{|sid| if b.state?(sid); candidates.push([b,sid]); break; end}
        end
      end
      return false if candidates.empty?
      proc_ok=(active? && current_round==1) ? true : (rand(100)<HEALER_CHANCE)
      return false unless proc_ok
      target=candidates[0][0]; sid=candidates[0][1].to_i
      target.remove_state(sid)
      return false if target.state?(sid)
      note_trigger(ABILITY_HEALER,battler,:healer,{:target_index=>target.index.to_i,:state_id=>sid},true)
      true
    end

    def self.apply_early_bird(battler,state_id,before_turns,after_turns)
      note_trigger(ABILITY_EARLY_BIRD,battler,:early_bird,{:state_id=>state_id.to_i,:before=>before_turns.to_i,:after=>after_turns.to_i},true)
    end

    def self.note_oblivious_taunt(battler)
      note_trigger(ABILITY_OBLIVIOUS,battler,:oblivious_taunt,{:effect=>:taunt},true)
    end

    def self.note_force_switch_guard(battler,aid,move_id,reason)
      note_trigger(aid,battler,reason,{:move_id=>move_id.to_i,:reason=>reason},true)
    end

    def self.note_intimidate_guard(battler,aid,source)
      note_trigger(aid,battler,:intimidate_guard,{:source_index=>(source&&source.respond_to?(:index) ? source.index.to_i : -1)},false)
    end

    def self.note_guard_dog_boost(battler,source,before,after)
      note_trigger(ABILITY_GUARD_DOG,battler,:guard_dog_intimidate,{:source_index=>(source&&source.respond_to?(:index) ? source.index.to_i : -1),:before=>before.to_i,:after=>after.to_i},true)
    end

    def self.register_handlers
      return false if core==nil
      # Ability Core trigger_switch_in 會自動再 dispatch :entry，因此只註冊 :entry，
      # 避免 switch-in 時同一個資訊特性重複觸發兩次。
      core.register(ABILITY_ANTICIPATION,:entry,self,:apply_anticipation)
      core.register(ABILITY_FOREWARN,:entry,self,:apply_forewarn)
      core.register(ABILITY_FRISK,:entry,self,:apply_frisk)
      core.register(ABILITY_HEALER,:end_turn,self,:apply_healer)
      true
    rescue
      false
    end

    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else
        text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text)
      end
      condition
    end

    def self.reset_log
      h="CG POKEMON ABILITY AC AWARENESS + GUARD + RECOVERY CONTROL AUTO REGRESSION v2.5.28a\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; entry awareness + restriction/force-switch guard + sleep shortening + healer lifecycle\r\n"+
        "BASELINE=v2.5.27b Ability Batch AB Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AB_PASS=224 BATCH_AC=8 PENDING=141\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    end

    def self.make_test_weapon(id,name,note)
      return nil if $data_weapons==nil
      while $data_weapons.size<=id; $data_weapons.push(nil); end
      w=RPG::Weapon.new; w.id=id; w.name=name; w.note=note; w.icon_index=0; w.price=0
      $data_weapons[id]=w; w
    end

    def self.install_test_item
      make_test_weapon(TEST_FRISK_ITEM,"AC察覺測試護符","<CG_POKEMON_HELD_ITEM>")
      ALBERT_CG::HELD_ITEM_V244.sync_class_permissions if defined?(ALBERT_CG::HELD_ITEM_V244)&&ALBERT_CG::HELD_ITEM_V244.respond_to?(:sync_class_permissions)
      true
    end

    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime)
    end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end

    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}
      ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each{|c|configure_actor(c)}
      a1=$game_actors[master.actor_id_for_dex(TEST_ALLIES[0][:dex])]
      a1.instance_variable_set(:@weapon_id,TEST_FRISK_ITEM) if a1
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
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AC v2.5.28a AutoRegression",ms)
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
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_ac,vals[i]) if b}
    end

    def self.prepare_round_preconditions
      a=test_allies; e=all_enemies
      if current_round==1
        @r1_oblivious_atk_before=a[1]&&a[1].respond_to?(:cg_stat_stage) ? a[1].cg_stat_stage(:atk).to_i : 0
        if defined?(ALBERT_CG::ABILITY_A_V250) && e[0]
          ALBERT_CG::ABILITY_A_V250.apply_intimidate(e[0],{:reason=>:ac_regression})
        end
        @r1_oblivious_atk_after=a[1]&&a[1].respond_to?(:cg_stat_stage) ? a[1].cg_stat_stage(:atk).to_i : 0
        if move_effect && a[1]
          a[1].add_state(move_effect::STATE_POISON)
          @r1_poison_seeded=a[1].state?(move_effect::STATE_POISON)
        end
      elsif current_round==2
        if move_effect && a[2]&&a[2].state?(move_effect::STATE_SLEEP); a[2].remove_state(move_effect::STATE_SLEEP); end
        (a+e).each{|b|b.cg_reset_stat_stages if b&&b.respond_to?(:cg_reset_stat_stages)}
        @r2_storage_before=storage_size
      elsif current_round==3
        (a+e).each{|b|b.cg_reset_stat_stages if b&&b.respond_to?(:cg_reset_stat_stages)}
        @r3_guard_before=e[4]&&e[4].respond_to?(:cg_stat_stage) ? e[4].cg_stat_stage(:atk).to_i : 0
        if defined?(ALBERT_CG::ABILITY_A_V250) && a[1]
          ALBERT_CG::ABILITY_A_V250.apply_intimidate(a[1],{:reason=>:ac_regression})
        end
        @r3_guard_after=e[4]&&e[4].respond_to?(:cg_stat_stage) ? e[4].cg_stat_stage(:atk).to_i : 0
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
      tok=(b.actor? ? "A" : "E")+b.index.to_s; a=b.action
      if a&&a.guard?; tok+=":Guard"
      elsif a&&a.skill?; sk=$data_skills[a.skill_id]; tok+=":M"+move_id(sk).to_s
      else; tok+=":Other"; end
      @actual.push(tok); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    end

    def self.assert_bootstrap_once
      return if @boot_asserted==true; @boot_asserted=true
      assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil"))
      assert_true("Ability Batch AC defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability AC test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil"))
      assert_true("Ability AC ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability AC starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden&&b.hp.to_i>0})
      assert_true("Ability AC starts with 1 hidden Guard Dog reserve",all_enemies[4]&&all_enemies[4].hidden,"E4_hidden="+(all_enemies[4] ? all_enemies[4].hidden.to_s : "nil"))
    end

    def self.sleep_turns(b)
      return -1 if b==nil || move_effect==nil
      h=b.instance_variable_get(:@state_turns); return -1 if h==nil
      h[move_effect::STATE_SLEEP].to_i
    rescue
      -1
    end

    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==exp,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        ant=records_for(ABILITY_ANTICIPATION,:anticipation)[-1]||{}
        ant_ok=!ant.empty?&&ant[:type_rate].to_i>100
        @awareness_checks+=1 if ant_ok; assert_true("Anticipation detects opposing super-effective Move on entry",ant_ok,"record="+ant.inspect)
        fw=records_for(ABILITY_FOREWARN,:forewarn)[-1]||{}
        fw_ok=!fw.empty?&&fw[:move_id].to_i==63&&fw[:power].to_i==150
        @awareness_checks+=1 if fw_ok; assert_true("Forewarn reveals highest-power opposing Move Hyper Beam",fw_ok,"record="+fw.inspect)
        fr=records_for(ABILITY_FRISK,:frisk)[-1]||{}
        frisk_ok=!fr.empty?&&fr[:items].respond_to?(:any?)&&fr[:items].any?{|x|x[1].to_i==TEST_FRISK_ITEM}
        @awareness_checks+=1 if frisk_ok; assert_true("Frisk reveals opposing raw Held Item on entry",frisk_ok,"record="+fr.inspect)

        oi=@r1_oblivious_atk_before.to_i==@r1_oblivious_atk_after.to_i&&!records_for(ABILITY_OBLIVIOUS,:intimidate_guard).empty?
        @guard_checks+=1 if oi; assert_true("Oblivious blocks Intimidate ATK drop",oi,"atk="+@r1_oblivious_atk_before.to_s+"->"+@r1_oblivious_atk_after.to_s)
        ot=a[1]&&(!a[1].respond_to?(:cg_v234_taunt_active?)||!a[1].cg_v234_taunt_active?)&&!records_for(ABILITY_OBLIVIOUS,:oblivious_taunt).empty?
        @guard_checks+=1 if ot; assert_true("Oblivious blocks Taunt",ot,"record="+(records_for(ABILITY_OBLIVIOUS,:oblivious_taunt)[-1]||{}).inspect)
        sc=!records_for(ABILITY_SUCTION_CUPS,:suction_cups).empty?&&e[0]&&!e[0].hidden
        @guard_checks+=1 if sc; assert_true("Suction Cups blocks Roar force switch",sc,"record="+(records_for(ABILITY_SUCTION_CUPS,:suction_cups)[-1]||{}).inspect)
        eb=a[2]&&a[2].state?(move_effect::STATE_SLEEP)&&sleep_turns(a[2])==1&&!records_for(ABILITY_EARLY_BIRD,:early_bird).empty?
        @sleep_checks+=1 if eb; assert_true("Early Bird halves Sleep remaining turns",eb,"turns="+sleep_turns(a[2]).to_s+" record="+(records_for(ABILITY_EARLY_BIRD,:early_bird)[-1]||{}).inspect)
        heal=@r1_poison_seeded==true&&a[1]&&!a[1].state?(move_effect::STATE_POISON)&&!records_for(ABILITY_HEALER,:healer).empty?
        @recovery_checks+=1 if heal; assert_true("Healer cures poisoned active ally at end-turn",heal,"record="+(records_for(ABILITY_HEALER,:healer)[-1]||{}).inspect)
      elsif r==2
        sw=e[3]&&e[4]&&e[3].hidden&&!e[4].hidden
        @lifecycle_checks+=1 if sw; assert_true("Teleport deploys hidden Guard Dog reserve",sw,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        iso=storage_size==@r2_storage_before.to_i
        @lifecycle_checks+=1 if iso; assert_true("Guard Dog reserve switch does not consume Storage Pokemon",iso,"before="+@r2_storage_before.to_s+" after="+storage_size.to_s)
      elsif r==3
        gd=@r3_guard_before.to_i==0&&@r3_guard_after.to_i==1&&!records_for(ABILITY_GUARD_DOG,:guard_dog_intimidate).empty?
        @guard_checks+=1 if gd; assert_true("Guard Dog converts Intimidate into ATK +1",gd,"atk="+@r3_guard_before.to_s+"->"+@r3_guard_after.to_s+" record="+(records_for(ABILITY_GUARD_DOG,:guard_dog_intimidate)[-1]||{}).inspect)
        gf=!records_for(ABILITY_GUARD_DOG,:guard_dog).empty?&&e[4]&&!e[4].hidden
        @guard_checks+=1 if gf; assert_true("Guard Dog blocks Roar force switch",gf,"record="+(records_for(ABILITY_GUARD_DOG,:guard_dog)[-1]||{}).inspect)
        stable=e[4]&&!e[4].hidden&&e[4].hp.to_i>0; assert_true("Guard Dog reserve remains active through Round3",stable,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" hp="+(e[4] ? e[4].hp.to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end

    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_ac,nil) if b}; end

    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"
      log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_ac="+ability_covered_count.to_s+"/8 awareness_checks="+@awareness_checks.to_i.to_s+" guard_checks="+@guard_checks.to_i.to_s+" sleep_checks="+@sleep_checks.to_i.to_s+" recovery_checks="+@recovery_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=141")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}
      cleanup_test_overrides; @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end

    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false
      @awareness_checks=0; @guard_checks=0; @sleep_checks=0; @recovery_checks=0; @lifecycle_checks=0
      @r1_poison_seeded=false; @r2_storage_before=0
    end

    def self.start_auto_test
      return false if active?
      reset_log; reset_suite; install_test_item; prepare_test_party; make_test_troop; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AC_v2.5.28a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
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
ALBERT_CG::ABILITY_AC_V2528.register_handlers if defined?(ALBERT_CG::ABILITY_AC_V2528)

#==============================================================================
# ■ Formal Early Bird：沿用既有 Sleep state turns
#==============================================================================
class Game_Battler
  alias cg_v2528ac_early_bird_add_state add_state
  def add_state(state_id)
    was=state?(state_id)
    result=cg_v2528ac_early_bird_add_state(state_id)
    if !was && state?(state_id) && defined?(ALBERT_CG::ABILITY_AC_V2528) && defined?(ALBERT_CG::MOVE_EFFECT) &&
       state_id.to_i==ALBERT_CG::MOVE_EFFECT::STATE_SLEEP.to_i &&
       ALBERT_CG::ABILITY_AC_V2528.ability_id(self)==ALBERT_CG::ABILITY_AC_V2528::ABILITY_EARLY_BIRD
      turns_hash=instance_variable_get(:@state_turns)
      if turns_hash!=nil
        before=turns_hash[state_id].to_i
        after=(before+ALBERT_CG::ABILITY_AC_V2528::EARLY_BIRD_DIVISOR-1)/ALBERT_CG::ABILITY_AC_V2528::EARLY_BIRD_DIVISOR
        after=1 if after<1
        turns_hash[state_id]=after
        ALBERT_CG::ABILITY_AC_V2528.apply_early_bird(self,state_id,before,after)
      end
    end
    result
  end
end

#==============================================================================
# ■ Formal Oblivious：Taunt setter guard
#==============================================================================
class Game_Battler
  if method_defined?(:cg_v234_set_taunt)
    alias cg_v2528ac_oblivious_set_taunt cg_v234_set_taunt
    def cg_v234_set_taunt
      if defined?(ALBERT_CG::ABILITY_AC_V2528) && ALBERT_CG::ABILITY_AC_V2528.ability_id(self)==ALBERT_CG::ABILITY_AC_V2528::ABILITY_OBLIVIOUS
        ALBERT_CG::ABILITY_AC_V2528.note_oblivious_taunt(self)
        return
      end
      cg_v2528ac_oblivious_set_taunt
    end
  end
end

#==============================================================================
# ■ Formal Oblivious / Guard Dog：Intimidate immune + Guard Dog ATK +1
#==============================================================================
if defined?(ALBERT_CG::ABILITY_STATUS_V255)
  module ALBERT_CG
    module ABILITY_STATUS_V255
      class << self
        alias cg_v2528ac_intimidate_immune intimidate_immune?
        def intimidate_immune?(battler)
          if defined?(ALBERT_CG::ABILITY_AC_V2528)
            aid=ALBERT_CG::ABILITY_AC_V2528.ability_id(battler)
            return true if aid==ALBERT_CG::ABILITY_AC_V2528::ABILITY_OBLIVIOUS || aid==ALBERT_CG::ABILITY_AC_V2528::ABILITY_GUARD_DOG
          end
          cg_v2528ac_intimidate_immune(battler)
        end
        alias cg_v2528ac_note_activation note_activation
        def note_activation(battler,aid,kind,context=nil)
          result=cg_v2528ac_note_activation(battler,aid,kind,context)
          if defined?(ALBERT_CG::ABILITY_AC_V2528) && kind.to_sym==:intimidate_guard &&
             [ALBERT_CG::ABILITY_AC_V2528::ABILITY_OBLIVIOUS,ALBERT_CG::ABILITY_AC_V2528::ABILITY_GUARD_DOG].include?(aid.to_i)
            src=context==nil ? nil : context[:source]
            ALBERT_CG::ABILITY_AC_V2528.note_intimidate_guard(battler,aid,src)
          end
          result
        end
      end
    end
  end
end

if defined?(ALBERT_CG::ABILITY_A_V250)
  module ALBERT_CG
    module ABILITY_A_V250
      class << self
        alias cg_v2528ac_apply_intimidate apply_intimidate
        def apply_intimidate(battler,ctx)
          guards=[]
          if defined?(ALBERT_CG::ABILITY_AC_V2528) && battler!=nil
            ALBERT_CG::ABILITY_V250.opponents_of(battler).each do |t|
              if ALBERT_CG::ABILITY_AC_V2528.ability_id(t)==ALBERT_CG::ABILITY_AC_V2528::ABILITY_GUARD_DOG
                guards.push([t,t.respond_to?(:cg_stat_stage) ? t.cg_stat_stage(:atk).to_i : 0])
              end
            end
          end
          result=cg_v2528ac_apply_intimidate(battler,ctx)
          guards.each do |pair|
            t=pair[0]; before=pair[1].to_i
            if t.respond_to?(:cg_change_stat_stage)
              t.cg_change_stat_stage(:atk,1)
              after=t.respond_to?(:cg_stat_stage) ? t.cg_stat_stage(:atk).to_i : before
              ALBERT_CG::ABILITY_AC_V2528.note_guard_dog_boost(t,battler,before,after) if after>before
            end
          end
          result
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal Suction Cups / Guard Dog：Force Switch effective Ability bridge
#==============================================================================
if defined?(ALBERT_CG::FORCE_SWITCH_V235)
  module ALBERT_CG
    module FORCE_SWITCH_V235
      class << self
        alias cg_v2528ac_block_reason force_switch_block_reason
        def force_switch_block_reason(target,move_id)
          reason=cg_v2528ac_block_reason(target,move_id)
          if defined?(ALBERT_CG::ABILITY_AC_V2528)
            aid=ALBERT_CG::ABILITY_AC_V2528.ability_id(target)
            if reason==:suction_cups && aid!=ALBERT_CG::ABILITY_AC_V2528::ABILITY_SUCTION_CUPS; reason=nil; end
            if reason==:guard_dog && aid!=ALBERT_CG::ABILITY_AC_V2528::ABILITY_GUARD_DOG; reason=nil; end
            return reason if reason!=nil
            return :suction_cups if aid==ALBERT_CG::ABILITY_AC_V2528::ABILITY_SUCTION_CUPS
            return :guard_dog if aid==ALBERT_CG::ABILITY_AC_V2528::ABILITY_GUARD_DOG
          end
          reason
        end
        alias cg_v2528ac_force_switch force_switch
        def force_switch(user,target,move_id)
          reason=force_switch_block_reason(target,move_id)
          if defined?(ALBERT_CG::ABILITY_AC_V2528) && target!=nil
            aid=ALBERT_CG::ABILITY_AC_V2528.ability_id(target)
            if reason==:suction_cups && aid==ALBERT_CG::ABILITY_AC_V2528::ABILITY_SUCTION_CUPS
              ALBERT_CG::ABILITY_AC_V2528.note_force_switch_guard(target,aid,move_id,:suction_cups)
            elsif reason==:guard_dog && aid==ALBERT_CG::ABILITY_AC_V2528::ABILITY_GUARD_DOG
              ALBERT_CG::ABILITY_AC_V2528.note_force_switch_guard(target,aid,move_id,:guard_dog)
            end
          end
          cg_v2528ac_force_switch(user,target,move_id)
        end
      end
    end
  end
end

# Disable previous newest F11 harness.
if defined?(ALBERT_CG::ABILITY_AB_V2527)
  module ALBERT_CG
    module ABILITY_AB_V2527
      def self.f11_trigger?; false; end
    end
  end
end

#==============================================================================
# ■ TEST Scene hooks
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2528ac_execute_action execute_action
  def execute_action
    b=@active_battler
    ALBERT_CG::ABILITY_AC_V2528.record_execution(b) if defined?(ALBERT_CG::ABILITY_AC_V2528)&&ALBERT_CG::ABILITY_AC_V2528.active?
    cg_v2528ac_execute_action
  end

  alias cg_v2528ac_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AC_V2528)&&ALBERT_CG::ABILITY_AC_V2528.active?
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_AC_V2528.finish_round_assertions
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      else
        ALBERT_CG::ABILITY_AC_V2528.finish_round_assertions
      end
    end
    cg_v2528ac_turn_end
  end

  alias cg_v2528ac_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AC_V2528)&&ALBERT_CG::ABILITY_AC_V2528.active?
      return cg_v2528ac_start_party_command
    end
    cg_v2528ac_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_AC_V2528.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AC_V2528.finished?
      ALBERT_CG::ABILITY_AC_V2528.finish_suite; battle_end(0); return
    end
    ALBERT_CG::ABILITY_AC_V2528.prepare_round_actions; start_main
  end
end

class Game_Battler
  alias cg_v2528ac_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AC_V2528)&&ALBERT_CG::ABILITY_AC_V2528.active?
      v=@cg_priority_test_speed_override_ac; return v.to_i if v!=nil
    end
    cg_v2528ac_priority_base_speed
  rescue
    cg_v2528ac_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2528ac_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AC_V2528)&&ALBERT_CG::ABILITY_AC_V2528.active?
      a=ALBERT_CG::ABILITY_AC_V2528.forced_enemy_action(self)
      if a
        cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return
      end
    end
    cg_v2528ac_enemy_make_action
  end
end

module ALBERT_CG
  class << self
    alias cg_v2528ac_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2528ac_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_AC_V2528)&&ALBERT_CG::ABILITY_AC_V2528.active?
        ALBERT_CG::ABILITY_AC_V2528::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AC_V2528.configure_actor(c)}
        a1=$game_actors[ALBERT_CG::ABILITY_AC_V2528.master.actor_id_for_dex(ALBERT_CG::ABILITY_AC_V2528::TEST_ALLIES[0][:dex])]
        a1.instance_variable_set(:@weapon_id,ALBERT_CG::ABILITY_AC_V2528::TEST_FRISK_ITEM) if a1
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if h
          h.change_level(ALBERT_CG::ABILITY_AC_V2528::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0)
        end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2528ac_scene_map_update update
  def update
    cg_v2528ac_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_AC_V2528)
    ALBERT_CG::ABILITY_AC_V2528.start_auto_test if ALBERT_CG::ABILITY_AC_V2528.f11_trigger?
  end
end
