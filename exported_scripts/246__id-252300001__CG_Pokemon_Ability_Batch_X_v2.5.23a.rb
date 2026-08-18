# RMVX_SCRIPT_INDEX: 246
# RMVX_SCRIPT_ID: 252300001
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch X v2.5.23a
# RMVX_SOURCE_SHA256: aa2fe6ce0b2435cee17070e151e787261f9f8857d6eb23074d3bf4ff64aaa889

#==============================================================================
# ■ CG Pokemon Ability Batch X v2.5.23a - Quick Draw Fixture Priority Fix TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.22 Ability Batch W RPG Maker VX 實機 PASS 為唯一基底，實作第二十四批
#  8 個 Ability。本批集中處理「行動優先度修正、同優先度先後、優先招式防護」，沿用
#  已封版 Action Priority v2.3.2c、Move Master priority、Ability Core 與 Actual Scene_Battle。
#  不修改 Move 937/937、既有 Priority Core 排序演算法或 Batch A～W Formal handlers。
#
# 【本批 Ability】
#  100 Stall           慢出：同 priority bracket 內固定最後行動。
#  158 Prankster       惡作劇之心：Status Move priority +1；對 Dark 對手的招式失效。
#  177 Gale Wings      疾風之翼：滿 HP 時 Flying Move priority +1。
#  205 Triage          先行治療：回復類 Move priority +3。
#  214 Queenly Majesty 女王的威嚴：自己與同側 active ally 阻擋對手 priority>0 招式。
#  219 Dazzling        鮮艷之軀：自己與同側 active ally 阻擋對手 priority>0 招式。
#  259 Quick Draw      速擊：30% 機率在相同 priority bracket 內最先行動。
#  296 Armor Tail      尾甲：自己與同側 active ally 阻擋對手 priority>0 招式。
#
# 【主要設定項】
#  TEST_TROOP_ID=726；HANDLED_ABILITY_IDS=8。
#  Coverage：184/373 -> 192/373，pending 189 -> 181。
#  QUICK_DRAW_PERCENT=30。
#
# 【機制規則】
#  1. Prankster / Gale Wings / Triage 只透過既有 Game_Battler#cg_action_priority_modifier
#     回傳額外 priority；Master Move priority 本身完全不改。
#  2. Stall / Quick Draw 不改 priority rank，只改 cg_priority_secondary_speed；因此 Quick Draw
#     不會被 Queenly Majesty / Dazzling / Armor Tail 誤判成「正優先度招式」。
#  3. Quick Draw 正式 Runtime 為每個 Action 快取一次 30% 判定；F11 deterministic 測試只在
#     Round3 強制 proc，避免隨機造成 Regression 漂移。
#  4. 三種 Priority Guard 先看 target 自身 holder，再掃同側 active holder；hidden / KO
#     reserve 不提供保護。只阻擋 opposing user 且 final priority > 0 的招式。
#  5. Prankster 的 Dark immunity 只對 opposing Dark target 生效；自我/同側招式不誤擋。
#  6. Triage 依 Master Move identifier 判定回復類招式；本批 Regression 使用 Recover(105)。
#  7. F11 Round1 由 Dazzling holder 最後使用 Teleport，換入 hidden Quick Draw reserve；
#     Storage 不可被當 battle reserve 消耗。
#  8. TEST Convenience 僅限 F11；正式 Release 恢復 emerged、BGM/BGS、正常焦點。
#  9. v2.5.23a 僅修 Regression fixture：Round3 A1 由 Status Splash 改為 Physical Tackle；
#     Formal Priority / Guard Runtime 行為不變。
#
# 【可調參數】
#  QUICK_DRAW_PERCENT、HEALING_MOVE_IDENTIFIERS、TEST_SPEEDS、ROUND_PLANS、TEST_TROOP_ID。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥無須事件呼叫。開發測試：地圖按 F11，自動進 troop 726，跑三回合並輸出
#  Pokemon_Ability_X_AutoTest_v2_5_23a.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：Triage Recover(+3)；Prankster Toxic(+1) 被 Dazzling 擋；滿血 Gale Wings Gust(+1)
#          被 Queenly Majesty 擋；Stall 在 priority 0 最後；Dazzling holder Teleport 退場。
#  Round2：Quick Attack(+1) 攻擊 enemy ally，被仍在場的 Armor Tail 阻擋。
#  Round3：Prankster holder 改用 priority 0 damaging Tackle，避免 Splash 被 Prankster 提升為 +1；
#          Quick Draw reserve 的 Tackle 保持 priority 0，並在真正相同 bracket 內搶先行動。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchX"] = "2.5.23a"

module ALBERT_CG
  module ABILITY_X_V2523
    VERSION = "2.5.23a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 726
    VK_F11 = 0x7A

    ABILITY_STALL            = 100
    ABILITY_PRANKSTER        = 158
    ABILITY_GALE_WINGS       = 177
    ABILITY_TRIAGE           = 205
    ABILITY_QUEENLY_MAJESTY  = 214
    ABILITY_DAZZLING         = 219
    ABILITY_QUICK_DRAW       = 259
    ABILITY_ARMOR_TAIL       = 296
    HANDLED_ABILITY_IDS = [100,158,177,205,214,219,259,296]

    QUICK_DRAW_PERCENT = 30
    PRIORITY_GUARD_IDS = [ABILITY_QUEENLY_MAJESTY,ABILITY_DAZZLING,ABILITY_ARMOR_TAIL]
    HEALING_MOVE_IDENTIFIERS = [
      "recover","soft-boiled","roost","heal-pulse","synthesis","morning-sun","moonlight",
      "slack-off","milk-drink","shore-up","floral-healing","strength-sap","jungle-healing",
      "lunar-blessing","life-dew","heal-order","wish"
    ]

    TEST_ALLIES = [
      {:dex=>25, :level=>40,:ability=>ABILITY_PRANKSTER,       :moves=>[92,98,33,150]},
      {:dex=>65, :level=>40,:ability=>ABILITY_QUEENLY_MAJESTY,:moves=>[150,150,150,150]},
      {:dex=>128,:level=>40,:ability=>ABILITY_TRIAGE,          :moves=>[105,150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>60,:ability=>ABILITY_DAZZLING,  :moves=>[100,150,150,150]},
      {:dex=>94, :level=>60,:ability=>ABILITY_GALE_WINGS,:moves=>[16,150,150,150]},
      {:dex=>91, :level=>60,:ability=>ABILITY_STALL,     :moves=>[33,150,150,150]},
      {:dex=>109,:level=>60,:ability=>ABILITY_ARMOR_TAIL,:moves=>[150,150,150,150]},
      {:dex=>197,:level=>60,:ability=>ABILITY_QUICK_DRAW,:moves=>[150,150,33,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"PRIORITY_MODIFIERS_GUARDS_AND_DAZZLING_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>92,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>105,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>100,:target=>3},
          1=>{:kind=>:move,:move_id=>16,:target=>2},
          2=>{:kind=>:move,:move_id=>33,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"ARMOR_TAIL_PRIORITY_GUARD",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>98,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"QUICK_DRAW_SAME_BRACKET_STABILITY",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>33,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,300,280,100, 50,290,270,260,0],
      :r2=>[10,300,280,270, 0,260,250,240,230],
      :r3=>[10,300,280,270, 0,260,250,240,100],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A3:M105","A1:M92","E1:M16","A2:M150","E3:M150","E2:M33","E0:M100"],
      2=>["A0:Guard","A1:M98","A2:M150","A3:M150","E1:M150","E3:M150","E4:M150","E2:M150"],
      3=>["A0:Guard","E4:M33","A1:M33","A2:M150","A3:M150","E1:M150","E3:M150","E2:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_X_AutoTest_v2_5_23a.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end

    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else
        text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text)
      end
      condition
    end

    def self.reset_log
      h="CG POKEMON ABILITY X PRIORITY DYNAMICS + PRIORITY GUARD AUTO REGRESSION v2.5.23a\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; priority modifier + same-bracket order + team priority guard lifecycle\r\n"+
        "BASELINE=v2.5.22 Ability Batch W Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_W_PASS=184 BATCH_X=8 PENDING=181\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue
    end

    def self.ability_id(b); core==nil || b==nil ? 0 : core.ability_id(b).to_i; rescue; 0; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill!=nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.move_row(mid); master ? master.move(mid.to_i) : nil; rescue; nil; end
    def self.move_identifier(mid); r=move_row(mid); r==nil ? "" : r[0].to_s; rescue; ""; end
    def self.status_move?(skill); r=move_row(move_id(skill)); r!=nil && r[7]==:status; rescue; false; end
    def self.healing_move?(skill); HEALING_MOVE_IDENTIFIERS.include?(move_identifier(move_id(skill))); rescue; false; end
    def self.type_id(sym); defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_id(sym).to_i : 0; rescue; 0; end
    def self.flying_move?(skill); skill!=nil && skill.respond_to?(:cg_pokemon_type_id) && skill.cg_pokemon_type_id.to_i==type_id(:flying); rescue; false; end
    def self.same_side?(a,b); a!=nil && b!=nil && a.actor? == b.actor?; rescue; false; end
    def self.opposing?(a,b); a!=nil && b!=nil && a.actor? != b.actor?; rescue; false; end
    def self.active_battlers; core ? core.active_battlers : []; rescue; []; end
    def self.full_hp?(b); b!=nil && b.hp.to_i>0 && b.hp.to_i>=b.maxhp.to_i; rescue; false; end
    def self.dark_type?(b); b!=nil && b.respond_to?(:cg_pokemon_types) && b.cg_pokemon_types.include?(:dark); rescue; false; end

    def self.note_local(aid,battler,kind,data=nil)
      return true unless active?
      @ability_trigger_counts[aid]=@ability_trigger_counts[aid].to_i+1
      rec={:ability=>aid,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless k==:battler||k==:user||k==:target||k==:skill||k==:action}
      @records[aid]=[] if @records[aid]==nil; @records[aid].push(rec)
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
      log("ABILITY_X_TRIGGER ability="+aid.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
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

    def self.priority_modifier(holder,action)
      return 0 if holder==nil || action==nil || !action.skill?
      skill=action.skill; aid=ability_id(holder); delta=0; kind=nil
      if aid==ABILITY_PRANKSTER && status_move?(skill)
        delta=1; kind=:prankster_priority
      elsif aid==ABILITY_GALE_WINGS && full_hp?(holder) && flying_move?(skill)
        delta=1; kind=:gale_wings_priority
      elsif aid==ABILITY_TRIAGE && healing_move?(skill)
        delta=3; kind=:triage_priority
      end
      if delta!=0
        key="@cg_v2523_priority_noted_"+aid.to_s
        unless action.instance_variable_get(key)
          action.instance_variable_set(key,true)
          formal_note(aid,holder,kind,{:move_id=>move_id(skill),:delta=>delta})
        end
      end
      delta
    rescue
      0
    end

    def self.quick_draw_speed(action,base)
      return base if action==nil
      holder=action.instance_variable_get(:@battler); return base if holder==nil || ability_id(holder)!=ABILITY_QUICK_DRAW
      decided=action.instance_variable_get(:@cg_v2523_quick_draw_decided)
      unless decided
        proc_flag = active? ? (current_round==3) : (rand(100)<QUICK_DRAW_PERCENT)
        action.instance_variable_set(:@cg_v2523_quick_draw_decided,true)
        action.instance_variable_set(:@cg_v2523_quick_draw_proc,proc_flag)
        formal_note(ABILITY_QUICK_DRAW,holder,:quick_draw,{:move_id=>(action.skill? ? move_id(action.skill) : 0)}) if proc_flag
      end
      action.instance_variable_get(:@cg_v2523_quick_draw_proc)==true ? 999999999 : base
    rescue
      base
    end

    def self.stall_speed(action,base)
      return base if action==nil
      holder=action.instance_variable_get(:@battler); return base if holder==nil || ability_id(holder)!=ABILITY_STALL
      unless action.instance_variable_get(:@cg_v2523_stall_noted)
        action.instance_variable_set(:@cg_v2523_stall_noted,true)
        formal_note(ABILITY_STALL,holder,:stall,{:move_id=>(action.skill? ? move_id(action.skill) : 0)})
      end
      -999999999
    rescue
      base
    end

    def self.action_final_priority(user,skill)
      a=user!=nil ? user.action : nil
      return a.cg_final_priority.to_i if a!=nil && a.respond_to?(:cg_final_priority)
      base=skill!=nil && skill.respond_to?(:cg_action_priority_value) ? skill.cg_action_priority_value.to_i : 0
      mod=user!=nil && user.respond_to?(:cg_action_priority_modifier) ? user.cg_action_priority_modifier(a).to_i : 0
      base+mod
    rescue
      0
    end

    def self.priority_guard_holder(target)
      return nil if target==nil
      aid=ability_id(target); return [aid,target] if PRIORITY_GUARD_IDS.include?(aid)
      active_battlers.each do |b|
        next if b==nil || ((b.respond_to?(:hidden) && b.hidden)) || b.hp.to_i<=0 || !same_side?(b,target)
        bid=ability_id(b); return [bid,b] if PRIORITY_GUARD_IDS.include?(bid)
      end
      nil
    rescue
      nil
    end

    def self.priority_guard_info(target,user,skill)
      return nil if target==nil || user==nil || skill==nil || !opposing?(target,user)
      return nil unless action_final_priority(user,skill)>0
      g=priority_guard_holder(target); return nil if g==nil
      aid,holder=g; kind=(aid==ABILITY_QUEENLY_MAJESTY ? :queenly_majesty : (aid==ABILITY_DAZZLING ? :dazzling : :armor_tail))
      [aid,holder,kind]
    rescue
      nil
    end

    def self.prankster_dark_block?(target,user,skill)
      return false if target==nil || user==nil || skill==nil || !opposing?(target,user)
      return false unless ability_id(user)==ABILITY_PRANKSTER && status_move?(skill) && dark_type?(target)
      true
    rescue
      false
    end

    def self.note_priority_guard(info,target,user,skill)
      aid,holder,kind=info
      formal_note(aid,holder,kind,{:move_id=>move_id(skill),:priority=>action_final_priority(user,skill)})
      true
    rescue
      true
    end

    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime)
    end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end
    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}; ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true); $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each{|c|configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); end
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1]]
      ms=[]; TEST_ENEMIES.each_with_index do |c,i|; configure_enemy(c); m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=(i>=4); ms.push(m); end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability X v2.5.23a AutoRegression",ms)
    end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); else; a.clear; end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c); end
    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||TEST_SPEEDS[:r1]||[]
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_x,vals[i]) if b}
    end
    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end
    def self.clear_round_states
      (test_allies+all_enemies).each do |b|
        next if b==nil || b.hp.to_i<=0
        b.recover_all if b.respond_to?(:recover_all)
        b.cg_reset_stat_stages if b.respond_to?(:cg_reset_stat_stages)
      end
    rescue
    end
    def self.prepare_round_preconditions
      clear_round_states; apply_test_speeds
      @r1_storage_before=storage_size if current_round==1
    end
    def self.prepare_round_actions
      p=current_plan; return false if p==nil; prepare_round_preconditions; @actual=[]; log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s)
      test_allies.each_with_index do |b,i|; next if b==nil||b.hp.to_i<=0; ac=make_action(b,p[:allies][i]); if b.respond_to?(:cg_round_actions); b.cg_round_actions.clear; b.cg_round_actions.push(ac); end; b.cg_assign_action(ac) if b.respond_to?(:cg_assign_action); b.instance_variable_set(:@action,ac) unless b.respond_to?(:cg_assign_action); end; true
    end
    def self.record_execution(b)
      return unless active?&&b
      a=b.action; pre=b.actor? ? "A" : "E"; tok=if a&&a.guard?; pre+b.index.to_s+":Guard" elsif a&&a.skill?; pre+b.index.to_s+":M"+ALBERT_CG::MOVE_EFFECT.move_id(a.skill).to_i.to_s else; pre+b.index.to_s+":Other" end; @actual.push(tok); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    rescue
    end
    def self.records_for(aid,kind=nil); a=@records[aid]||[]; a.select{|r|kind==nil||r[:kind]==kind}; end

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      tid=($game_troop&&$game_troop.troop) ? $game_troop.troop.id.to_i : 0
      assert_true("Ability Catalog count=373",core&&core.catalog_count==373,"actual="+(core ? core.catalog_count.to_s : "nil"))
      assert_true("Ability Batch X defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability X test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability X ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability X starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden},"")
      assert_true("Ability X starts with 1 hidden Quick Draw reserve",all_enemies[4]&&all_enemies[4].hidden,"E4_hidden="+(all_enemies[4] ? all_enemies[4].hidden.to_s : "nil"))
    end

    def self.assert_round
      r=current_round; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]; order=@actual==exp
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",order,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        checks=[
          [ABILITY_TRIAGE,:triage_priority,"Triage raises Recover priority +3"],
          [ABILITY_PRANKSTER,:prankster_priority,"Prankster raises Toxic priority +1"],
          [ABILITY_GALE_WINGS,:gale_wings_priority,"Gale Wings raises Flying priority +1 at full HP"],
          [ABILITY_STALL,:stall,"Stall moves last inside priority 0 bracket"],
        ]
        checks.each do |x|; ok=!records_for(x[0],x[1]).empty?; @priority_checks+=1 if ok; assert_true(x[2],ok,(records_for(x[0],x[1])[-1]||{}).inspect); end
        d=!records_for(ABILITY_DAZZLING,:dazzling).empty?; @guard_checks+=1 if d; assert_true("Dazzling blocks opposing Prankster priority move",d,(records_for(ABILITY_DAZZLING,:dazzling)[-1]||{}).inspect)
        q=!records_for(ABILITY_QUEENLY_MAJESTY,:queenly_majesty).empty?; @guard_checks+=1 if q; assert_true("Queenly Majesty blocks opposing Gale Wings priority move",q,(records_for(ABILITY_QUEENLY_MAJESTY,:queenly_majesty)[-1]||{}).inspect)
        switched=e[0]&&e[4]&&e[0].hidden&&!e[4].hidden; @lifecycle_checks+=1 if switched; assert_true("Teleport deploys hidden Quick Draw reserve",switched,"E0_hidden="+(e[0] ? e[0].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        storage=storage_size==@r1_storage_before.to_i; @lifecycle_checks+=1 if storage; assert_true("Quick Draw reserve switch does not consume Storage Pokemon",storage,"before="+@r1_storage_before.to_s+" after="+storage_size.to_s)
      elsif r==2
        a=!records_for(ABILITY_ARMOR_TAIL,:armor_tail).empty?; @guard_checks+=1 if a; assert_true("Armor Tail blocks priority move aimed at active ally",a,(records_for(ABILITY_ARMOR_TAIL,:armor_tail)[-1]||{}).inspect)
      elsif r==3
        qd=!records_for(ABILITY_QUICK_DRAW,:quick_draw).empty?; @priority_checks+=1 if qd; assert_true("Quick Draw wins same priority bracket without raising priority rank",qd,(records_for(ABILITY_QUICK_DRAW,:quick_draw)[-1]||{}).inspect)
        stable=e[4]&&!e[4].hidden&&e[4].hp.to_i>0; assert_true("Quick Draw reserve remains active through Round3",stable,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" hp="+(e[4] ? e[4].hp.to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end

    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides
      (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_x,nil) if b}
    end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"; log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_x="+ability_covered_count.to_s+"/8 priority_checks="+@priority_checks.to_i.to_s+" guard_checks="+@guard_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=181")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @priority_checks=0; @guard_checks=0; @lifecycle_checks=0; @r1_storage_before=0
    end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; ALBERT_CG::UNIQUE_I_V242.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_I_V242)&&ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes); @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_X_v2.5.23a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

if defined?(ALBERT_CG::ABILITY_W_V2522)
  module ALBERT_CG; module ABILITY_W_V2522; def self.f11_trigger?; false; end; end; end
end

#==============================================================================
# ■ Formal Priority Modifier Bridge
#==============================================================================
class Game_Battler
  alias cg_v2523x_action_priority_modifier cg_action_priority_modifier
  def cg_action_priority_modifier(action=nil)
    base=cg_v2523x_action_priority_modifier(action).to_i
    if defined?(ALBERT_CG::ABILITY_X_V2523)
      base += ALBERT_CG::ABILITY_X_V2523.priority_modifier(self,action).to_i
    end
    base
  rescue
    cg_v2523x_action_priority_modifier(action)
  end
end

class Game_BattleAction
  alias cg_v2523x_priority_secondary_speed cg_priority_secondary_speed
  def cg_priority_secondary_speed
    base=cg_v2523x_priority_secondary_speed.to_i
    if defined?(ALBERT_CG::ABILITY_X_V2523)
      base=ALBERT_CG::ABILITY_X_V2523.quick_draw_speed(self,base)
      base=ALBERT_CG::ABILITY_X_V2523.stall_speed(self,base)
    end
    base
  rescue
    cg_v2523x_priority_secondary_speed
  end
end

#==============================================================================
# ■ Formal Priority Guard + Prankster Dark Immunity Bridge
#==============================================================================
class Game_Battler
  alias cg_v2523x_priority_guard_skill_effect skill_effect
  def skill_effect(user,skill)
    if defined?(ALBERT_CG::ABILITY_X_V2523) && user!=nil && skill!=nil
      if ALBERT_CG::ABILITY_X_V2523.prankster_dark_block?(self,user,skill)
        clear_action_results; @missed=false; @evaded=false; @skipped=false; @hp_damage=0
        ALBERT_CG::ABILITY_X_V2523.formal_note(ALBERT_CG::ABILITY_X_V2523::ABILITY_PRANKSTER,user,:prankster_dark_guard,{:move_id=>ALBERT_CG::ABILITY_X_V2523.move_id(skill)})
        return
      end
      info=ALBERT_CG::ABILITY_X_V2523.priority_guard_info(self,user,skill)
      if info!=nil
        clear_action_results; @missed=false; @evaded=false; @skipped=false; @hp_damage=0
        ALBERT_CG::ABILITY_X_V2523.note_priority_guard(info,self,user,skill)
        return
      end
    end
    cg_v2523x_priority_guard_skill_effect(user,skill)
  end
end

#==============================================================================
# ■ TEST-only deterministic Scene_Battle harness
#==============================================================================
class Game_Battler
  alias cg_v2523x_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil); return 100 if defined?(ALBERT_CG::ABILITY_X_V2523)&&ALBERT_CG::ABILITY_X_V2523.active?; cg_v2523x_ability_calc_hit(user,obj); end
  alias cg_v2523x_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil); return 0 if defined?(ALBERT_CG::ABILITY_X_V2523)&&ALBERT_CG::ABILITY_X_V2523.active?; cg_v2523x_ability_calc_eva(user,obj); end
  alias cg_v2523x_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_X_V2523)&&ALBERT_CG::ABILITY_X_V2523.active?
      v=@cg_priority_test_speed_override_x; return v.to_i if v!=nil
    end
    cg_v2523x_ability_priority_base_speed
  rescue
    cg_v2523x_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2523x_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_X_V2523)&&ALBERT_CG::ABILITY_X_V2523.active?
      a=ALBERT_CG::ABILITY_X_V2523.forced_enemy_action(self)
      if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end
    end
    cg_v2523x_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2523x_ability_execute_action execute_action
  def execute_action
    b=@active_battler; ALBERT_CG::ABILITY_X_V2523.record_execution(b) if defined?(ALBERT_CG::ABILITY_X_V2523)&&ALBERT_CG::ABILITY_X_V2523.active?; cg_v2523x_ability_execute_action
  end
  alias cg_v2523x_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_X_V2523)&&ALBERT_CG::ABILITY_X_V2523.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_X_V2523.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_X_V2523.finish_round_assertions; end
    end
    cg_v2523x_ability_turn_end
  end
  alias cg_v2523x_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_X_V2523)&&ALBERT_CG::ABILITY_X_V2523.active?; return cg_v2523x_ability_start_party_command; end
    cg_v2523x_ability_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_X_V2523.assert_bootstrap_once
    if ALBERT_CG::ABILITY_X_V2523.finished?; ALBERT_CG::ABILITY_X_V2523.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_X_V2523.prepare_round_actions; start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2523x_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2523x_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_X_V2523)&&ALBERT_CG::ABILITY_X_V2523.active?
        ALBERT_CG::ABILITY_X_V2523::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_X_V2523.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_X_V2523::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2523x_ability_scene_map_update update
  def update; cg_v2523x_ability_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_X_V2523); ALBERT_CG::ABILITY_X_V2523.start_auto_test if ALBERT_CG::ABILITY_X_V2523.f11_trigger?; end
end
