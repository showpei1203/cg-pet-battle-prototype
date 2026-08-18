# RMVX_SCRIPT_INDEX: 255
# RMVX_SCRIPT_ID: 253000004
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AE v2.5.30b
# RMVX_SOURCE_SHA256: ceecd0118db8e203e410386749ad41c48cf39e8d2ca0d6a1d4a1dc8e7cb7c8e8

#==============================================================================
# ■ CG Pokemon Ability Batch AE v2.5.30b - Threshold / KO Momentum TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.29b Ability Batch AD RPG Maker VX 實機 PASS 為唯一正式基底，新增 8 個
#  尚未覆蓋 Ability，集中處理「半血自動撤退、換入回合增傷、接觸滅亡、擊倒反傷、
#  全場倒下觸發、已倒下隊友增傷、命中後毒鎖鏈」。沿用既有 Ability Core、
#  Modifier Authority、Force Switch reserve/slot/hazard lifecycle、Move Effect Perish／Bad Poison
#  與 Stat Stage Authority；不修改已 PASS Move Core 與 Ability A..AD。
#
# 【本批 Ability】
#  193 Wimp Out / 躍躍欲逃：被敵方實傷由 >1/2 HP 打到 <=1/2 HP 且仍存活時，自動撤退。
#  194 Emergency Exit / 危險迴避：同上；沿用 battle reserve，不取用 Storage Pokémon。
#  198 Stakeout / 監視：攻擊本回合剛換入的目標時，正規非固定傷害 x2。
#  215 Innards Out / 飛出的內在物：因實傷倒下時，攻擊者受到等同持有者倒下前 HP 的反傷。
#  220 Soul-Heart / 魂心：其他 Pokémon 倒下時，自身 SpA +1；涵蓋直接傷害與 residual/Perish KO。
#  253 Perish Body / 滅亡之軀：受到敵方接觸實傷後，自己與攻擊者進入既有 Perish lifecycle。
#  293 Supreme Overlord / 大將：入場時記錄同側已倒下 Pokémon 數（最多 5），傷害每隻 +10%。
#  302 Toxic Chain / 毒鎖鏈：造成實傷後 30% 使目標 Bad Poison；F11 只固定 proc 以消除 RNG。
#
# 【主要設定項】
#  TEST_TROOP_ID=733；HANDLED_ABILITY_IDS=8。
#  Static coverage：240/373 -> 248/373，pending 133 -> 125。
#  TOXIC_CHAIN_CHANCE=30；SUPREME_MAX_FAINTED=5；SUPREME_PER_FAINT_PERCENT=10。
#
# 【機制規則】
#  1. Wimp Out / Emergency Exit 只在「本次敵方 positive damage」使 HP 從半血以上跨到半血以下
#     且仍存活時觸發；若沒有 battle reserve 則不觸發。自動撤退刻意不呼叫 Roar 類
#     force_switch_block_reason，因此不會被 trapping / Suction Cups 等「阻止被強制換出」規則誤擋。
#  2. 自動撤退仍完整重用 FORCE_SWITCH_V235.reserve_candidates、clear_switch_out_volatile、
#     battle slot transfer 與 FIELD_V233.apply_entry_hazards；Storage 不會成為敵方 reserve。
#  3. Stakeout 不永久改 target；AE 只為真正 switch-in battler 寫入 battle-local turn serial，
#     :damage_modify 僅在 target 的 switch serial 等於目前 turn serial 時 x2，下一回合自動失效。
#  4. Supreme Overlord 在 :entry 當下 snapshot 同側已倒下 Pokémon 數，之後以 snapshot 計算，
#     不因本回合後續 KO 動態增加；最多 5 層，每層 +10%。Human 不計入 Pokémon faint count。
#  5. Perish Body 直接沿用 MOVE_EFFECT::STATE_PERISH；因 Ability 不是 Move ailment pipeline，
#     新增狀態成功時同步初始化既有 @cg_perish_count=3，再由既有 Move Core 每回合倒數／歸零 KO；
#     不另寫第二套 Perish timer，也不重設已經存在的 Perish countdown。
#  6. Toxic Chain 由最外層 execute_damage 在 real damage 後檢查攻擊者 Ability；狀態施加優先走
#     ABILITY_STATUS_V255.apply_status_from_ability，尊重既有主狀態／屬性免疫／Synchronize Authority。
#  7. Innards Out 於真正 damage KO 後使用 battle-only direct ability damage；若反傷也造成 Pokémon KO，
#     同樣通知 Soul-Heart。固定反傷不再送回一般 move damage modifier，避免遞迴與錯誤增傷。
#  8. Soul-Heart 的 damage KO 由 execute_damage transition bridge 通知；Perish／Poison 等 residual KO
#     由 slip_damage_effect transition bridge 通知。正式通知掃描「全戰場 active Pokémon」，不是 fallen
#     的同側隊伍；每次 faint transition 只通知一次，復活後可再次觸發。
#  9. F11 Regression 使用真正 Scene_Battle、Water Gun、Aerial Ace、Dragon Rage、Splash 與既有
#     Perish residual lifecycle；v2.5.30b 由獨立 Sideview Bridge 補回正式 turn_end tick，不直接呼叫 Ability handler 冒充戰鬥結果。
# 10. F11 E6 是「已倒下且不會換入」的 hidden Pokémon，只用來證明 Supreme Overlord 入場 snapshot=1；
#     E0/E1 半血 Ability 則分別固定撤退到 hidden E4/E5，完全不動 Storage。
# 11. Round1 已驗證 Perish Body 同時套用 holder/attacker；Round2 bootstrap 會只移除 A3 的 Perish，
#     將三回合 residual lifecycle 隔離給 E2，避免 Round3 兩隻同時 Perish 讓 Soul-Heart KO 計數混線。
#
# 【v2.5.30b 實機修正】
#  1. v2.5.30 實機證明 Perish Body 有成功加入 STATE_PERISH，但 Ability 路徑沒有經過 Move ailment
#     initializer，因此 @cg_perish_count 為 nil；本版只在「新加入 Perish」時初始化既有 count=3。
#  2. v2.5.30 的 Soul-Heart helper 錯把通知範圍限制在 fallen 的同側；本版改為掃描全戰場 active
#     Pokémon，符合「任一其他 Pokémon 倒下」語意。
#  3. Stakeout / Supreme Overlord 補上 :damage_modify role=:attacker 限制。v2.5.30 實機 LOG 已顯示
#     Supreme Overlord 會在自己作為受擊目標時被 defender role 誤 dispatch；本版阻止此錯誤增傷。
#  4. Innards Out F11 fixture 由不保證 KO 的 Aura Sphere 改成已 PASS 的 Dragon Rage 固定 40 傷害，
#     E3 HP 固定 40，讓「真 KO -> Innards Out 40 反傷 -> Soul-Heart」成為 deterministic chain。
#  5. v2.5.30b 實機證明上述 count=3 初始化已成功，但正式回合結束後 count 仍維持 3。
#     Source audit 確認 Tankentai Sideview 3.3 的 Scene_Battle#turn_end 不呼叫 Game_Unit#slip_damage_effect；
#     因此本版搭配獨立 Sideview Perish Lifecycle Bridge v2.3.0a，只補回既有 Perish 倒數與 KO。
#
# 【可調參數】
#  TEST_TROOP_ID、TEST_LEVEL、TOXIC_CHAIN_CHANCE、SUPREME_MAX_FAINTED、
#  SUPREME_PER_FAINT_PERCENT、ROUND_PLANS、TEST_SPEEDS。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫。開發測試：地圖按 F11，自動進 troop 733，跑三回合並輸出
#  Pokemon_Ability_AE_AutoTest_v2_5_30b.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：A1 Water Gun 將 E0 打過半血 -> Wimp Out 撤退到 E4；E4 Supreme Overlord 入場 snapshot=1；
#          A2 Stakeout Water Gun 對「本回合剛換入」E4 x2；A3 Aerial Ace -> E2，Perish Body 對雙方
#          建立 Perish、Toxic Chain 同時讓 E2 Bad Poison；A0 Water Gun -> E1 Emergency Exit -> E5。
#  Round2：A0 Dragon Rage 固定 40 傷害 KO 預設 HP=40 的 E3 Innards Out，A0 精確承受 40 反傷；
#          A1 Soul-Heart 由「敵方 Pokémon 倒下」正確 +1；
#          E4 Supreme Overlord Water Gun 以 entry snapshot 1 層 x1.10；A2 再打 E4 時 Stakeout 不再增傷。
#  Round3：E2 Perish count 在 turn_end 前為 1；既有 Move Core turn_end 將 E2 Perish KO，
#          Soul-Heart 再 +1，最終 A1 SpA stage=+2。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAE"] = "2.5.30b"

module ALBERT_CG
  module ABILITY_AE_V2530
    VERSION = "2.5.30b"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 733
    VK_F11 = 0x7A

    ABILITY_WIMP_OUT          = 193
    ABILITY_EMERGENCY_EXIT    = 194
    ABILITY_STAKEOUT          = 198
    ABILITY_INNARDS_OUT       = 215
    ABILITY_SOUL_HEART        = 220
    ABILITY_PERISH_BODY       = 253
    ABILITY_SUPREME_OVERLORD  = 293
    ABILITY_TOXIC_CHAIN       = 302
    HANDLED_ABILITY_IDS = [193,194,198,215,220,253,293,302]

    TOXIC_CHAIN_CHANCE = 30
    SUPREME_MAX_FAINTED = 5
    SUPREME_PER_FAINT_PERCENT = 10

    TEST_ALLIES = [
      {:dex=>94, :level=>40,:ability=>ABILITY_SOUL_HEART, :moves=>[55,150,150,150]},
      {:dex=>128,:level=>40,:ability=>ABILITY_STAKEOUT,   :moves=>[55,150,150,150]},
      {:dex=>110,:level=>40,:ability=>ABILITY_TOXIC_CHAIN,:moves=>[332,150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>65, :level=>50,:ability=>ABILITY_WIMP_OUT,         :moves=>[150,150,150,150]},
      {:dex=>26, :level=>50,:ability=>ABILITY_EMERGENCY_EXIT,   :moves=>[150,150,150,150]},
      {:dex=>143,:level=>50,:ability=>ABILITY_PERISH_BODY,      :moves=>[150,150,150,150]},
      {:dex=>1,  :level=>50,:ability=>ABILITY_INNARDS_OUT,      :moves=>[150,150,150,150]},
      {:dex=>197,:level=>50,:ability=>ABILITY_SUPREME_OVERLORD, :moves=>[55,150,150,150]},
      {:dex=>25, :level=>50,:ability=>0,                         :moves=>[150,150,150,150]},
      {:dex=>92, :level=>50,:ability=>0,                         :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"THRESHOLD_SWITCH_STAKEOUT_PERISH_TOXIC",
        :allies=>[
          {:kind=>:move,:move_id=>55,:target=>1},
          {:kind=>:move,:move_id=>55,:target=>0},
          {:kind=>:move,:move_id=>55,:target=>4},
          {:kind=>:move,:move_id=>332,:target=>2},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"INNARDS_SOUL_HEART_SUPREME_STAKEOUT_EXPIRY",
        :allies=>[
          {:kind=>:move,:move_id=>82,:target=>3},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>55,:target=>4},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>55,:target=>1},
          5=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"PERISH_RESIDUAL_SOUL_HEART",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>2},
        ],
        :enemies=>{
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>150,:target=>1},
          5=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[350,500,450,400, 100,90,300,250,0,0,0],
      :r2=>[500,350,400,300, 0,0,250,0,450,200,0],
      :r3=>[10,500,450,400, 0,0,300,0,350,250,0],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A1:M55","A2:M55","A3:M332","A0:M55","E2:M150","E3:M150"],
      2=>["A0:M82","E4:M55","A2:M55","A1:M150","A3:M150","E2:M150","E5:M150"],
      3=>["A0:Guard","A1:M150","A2:M150","A3:M150","E4:M150","E2:M150","E5:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.force_runtime; defined?(ALBERT_CG::FORCE_SWITCH_V235) ? ALBERT_CG::FORCE_SWITCH_V235 : nil; end
    def self.field; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233 : nil; end
    def self.status_runtime; defined?(ALBERT_CG::ABILITY_STATUS_V255) ? ALBERT_CG::ABILITY_STATUS_V255 : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AE_AutoTest_v2_5_30b.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.ability_id(b); core==nil || b==nil ? 0 : core.ability_id(b).to_i; rescue; 0; end
    def self.opposing?(a,b); a!=nil&&b!=nil&&a.respond_to?(:actor?)&&b.respond_to?(:actor?)&&a.actor? != b.actor?; rescue; false; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill!=nil ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end

    def self.pokemon_battler?(b)
      return false if b==nil
      if defined?(ALBERT_CG::ABILITY_AD_V2529) && ALBERT_CG::ABILITY_AD_V2529.respond_to?(:pokemon_battler?)
        return ALBERT_CG::ABILITY_AD_V2529.pokemon_battler?(b)
      end
      return true unless b.actor?
      return true if b.respond_to?(:cg_battle_pet?) && b.cg_battle_pet?
      return true if b.respond_to?(:cg_pet?) && b.cg_pet?
      false
    rescue
      false
    end

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
        core.runtime_log("ABILITY_AE_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect)
        core.note_trigger(kind,battler,aid,rec)
        core.present_trigger(battler,aid,kind,rec) if present
      end
      log("ABILITY_AE_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect) if active?
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

    #--------------------------------------------------------------------------
    # Formal battle-local switch turn stamp / Supreme snapshot
    #--------------------------------------------------------------------------
    def self.begin_battle_cycle
      @battle_turn_serial=1
      list=[]
      list.concat($game_party.members) if $game_party!=nil
      list.concat($game_troop.members) if $game_troop!=nil
      list.each do |b|
        next if b==nil
        b.instance_variable_set(:@cg_v2530ae_switch_serial,nil)
        b.instance_variable_set(:@cg_v2530ae_supreme_count,nil)
        b.instance_variable_set(:@cg_v2530ae_faint_notified,false)
      end
      true
    rescue
      @battle_turn_serial=1; false
    end

    def self.turn_serial; @battle_turn_serial.to_i<=0 ? 1 : @battle_turn_serial.to_i; end
    def self.advance_turn_serial!; @battle_turn_serial=turn_serial+1; end
    def self.mark_switch_in(b)
      return false if b==nil
      b.instance_variable_set(:@cg_v2530ae_switch_serial,turn_serial)
      true
    rescue
      false
    end
    def self.switched_in_this_turn?(b)
      return false if b==nil
      b.instance_variable_get(:@cg_v2530ae_switch_serial).to_i==turn_serial
    rescue
      false
    end

    def self.same_side_members(b)
      return [] if b==nil
      unit=b.actor? ? $game_party : $game_troop
      unit==nil ? [] : unit.members
    rescue
      []
    end

    def self.fainted_pokemon_count(holder)
      n=0
      same_side_members(holder).each do |b|
        next if b==nil || b==holder
        next unless pokemon_battler?(b)
        n+=1 if b.hp.to_i<=0
      end
      n=SUPREME_MAX_FAINTED if n>SUPREME_MAX_FAINTED
      n
    rescue
      0
    end

    def self.apply_supreme_entry(holder,ctx)
      return false if holder==nil
      count=fainted_pokemon_count(holder)
      holder.instance_variable_set(:@cg_v2530ae_supreme_count,count)
      note_trigger(ABILITY_SUPREME_OVERLORD,holder,:supreme_overlord_entry,{:fainted=>count},false)
      # Switch-in 可能發生在另一個 Action 的 after_damage 中；不讓 Core 再同步 popup/wait。
      false
    rescue
      false
    end

    #--------------------------------------------------------------------------
    # Formal threshold self-retreat
    #--------------------------------------------------------------------------
    def self.threshold_crossed?(holder,ctx)
      return false if holder==nil || ctx==nil || ctx[:damage_done].to_i<=0
      user=ctx[:user]; return false if user==nil || !opposing?(holder,user)
      before=ctx[:hp_before].to_i; after=ctx[:hp_after].to_i
      half=holder.maxhp.to_i/2
      before>half && after>0 && after<=half
    rescue
      false
    end

    def self.choose_self_retreat_reserve(holder,candidates)
      return nil if candidates==nil || candidates.empty?
      if active? && holder!=nil && !holder.actor?
        desired = holder.index.to_i==0 ? 4 : (holder.index.to_i==1 ? 5 : nil)
        if desired!=nil
          exact=candidates.find{|b|b.respond_to?(:index)&&b.index.to_i==desired}
          return exact if exact!=nil
        end
        return candidates.sort_by{|b|b.respond_to?(:index) ? b.index.to_i : 0}[0]
      end
      candidates[rand(candidates.size)]
    rescue
      nil
    end

    def self.self_retreat(holder,aid,kind,ctx)
      fr=force_runtime; return false if holder==nil || fr==nil || !fr.respond_to?(:reserve_candidates)
      candidates=fr.reserve_candidates(holder); return false if candidates==nil || candidates.empty?
      incoming=choose_self_retreat_reserve(holder,candidates); return false if incoming==nil
      row=holder.respond_to?(:cg_battle_row) ? holder.cg_battle_row : :front
      col=holder.respond_to?(:cg_battle_column) ? holder.cg_battle_column.to_i : 1
      out_index=holder.respond_to?(:index) ? holder.index.to_i : -1
      in_index=incoming.respond_to?(:index) ? incoming.index.to_i : -1
      before=ctx[:hp_before].to_i; after=ctx[:hp_after].to_i

      fr.clear_switch_out_volatile(holder) if fr.respond_to?(:clear_switch_out_volatile)
      holder.escape if holder.respond_to?(:escape)
      holder.hidden=true if holder.respond_to?(:hidden=)
      holder.action.clear if holder.respond_to?(:action)&&holder.action!=nil

      incoming.hidden=false if incoming.respond_to?(:hidden=)
      incoming.cg_set_battle_slot(row,col,true) if incoming.respond_to?(:cg_set_battle_slot)
      incoming.action.clear if incoming.respond_to?(:action)&&incoming.action!=nil
      incoming.reset_coordinate if incoming.respond_to?(:reset_coordinate)
      incoming.base_position if incoming.respond_to?(:base_position)
      incoming.instance_variable_set(:@collapse,false)

      hazard={:damage=>0,:states=>[],:spe_delta=>0}
      hazard=field.apply_entry_hazards(incoming) if field!=nil && field.respond_to?(:apply_entry_hazards)
      fr.show_hazard_popup(incoming,hazard) if fr.respond_to?(:show_hazard_popup)
      note_trigger(aid,holder,kind,{:hp_before=>before,:hp_after=>after,:outgoing_index=>out_index,:incoming_index=>in_index,:turn_serial=>turn_serial},true)
      fr.show_switch_text(holder.name.to_s+"因特性撤退，"+incoming.name.to_s+"進入戰場。") if fr.respond_to?(:show_switch_text)
      true
    rescue=>e
      log("SELF_RETREAT_ERROR ability="+aid.to_i.to_s+" "+e.class.to_s+":"+e.message.to_s) if active?
      false
    end

    def self.apply_wimp_out(holder,ctx)
      return false unless threshold_crossed?(holder,ctx)
      self_retreat(holder,ABILITY_WIMP_OUT,:wimp_out,ctx)
    end

    def self.apply_emergency_exit(holder,ctx)
      return false unless threshold_crossed?(holder,ctx)
      self_retreat(holder,ABILITY_EMERGENCY_EXIT,:emergency_exit,ctx)
    end

    #--------------------------------------------------------------------------
    # Formal damage modifiers
    #--------------------------------------------------------------------------
    def self.apply_stakeout(user,ctx)
      return false if user==nil || ctx==nil || ctx[:target]==nil || ctx[:damage].to_i<=0
      return false unless ctx[:role]==:attacker
      return false if ctx[:fixed_damage]==true
      target=ctx[:target]
      eligible=switched_in_this_turn?(target)
      @stakeout_probes=[] if @stakeout_probes==nil
      probe={:target_index=>(target.respond_to?(:index) ? target.index.to_i : -1),:eligible=>eligible,:turn_serial=>turn_serial,:switch_serial=>target.instance_variable_get(:@cg_v2530ae_switch_serial)}
      @stakeout_probes.push(probe)
      return false unless eligible
      before=ctx[:damage].to_i; after=before*2; ctx[:damage]=after
      note_trigger(ABILITY_STAKEOUT,user,:stakeout,{:target_index=>probe[:target_index],:before=>before,:after=>after,:turn_serial=>turn_serial},false)
      true
    rescue
      false
    end

    def self.apply_supreme_damage(user,ctx)
      return false if user==nil || ctx==nil || ctx[:damage].to_i<=0 || ctx[:fixed_damage]==true
      return false unless ctx[:role]==:attacker
      count=user.instance_variable_get(:@cg_v2530ae_supreme_count).to_i
      return false if count<=0
      count=SUPREME_MAX_FAINTED if count>SUPREME_MAX_FAINTED
      before=ctx[:damage].to_i; percent=100+count*SUPREME_PER_FAINT_PERCENT
      after=[before*percent/100,1].max; ctx[:damage]=after
      note_trigger(ABILITY_SUPREME_OVERLORD,user,:supreme_overlord_damage,{:fainted=>count,:before=>before,:after=>after,:percent=>percent},false)
      true
    rescue
      false
    end

    #--------------------------------------------------------------------------
    # Formal Perish Body / Toxic Chain
    #--------------------------------------------------------------------------
    def self.add_state_record(target,state_id)
      return false if target==nil || state_id.to_i<=0 || target.state?(state_id.to_i)
      if target.respond_to?(:cg_v231_add_state_record)
        target.cg_v231_add_state_record(state_id.to_i)
      else
        target.add_state(state_id.to_i)
      end
      target.state?(state_id.to_i)
    rescue
      false
    end

    def self.apply_perish_body(holder,ctx)
      return false if holder==nil || ctx==nil || ctx[:user]==nil || ctx[:damage_done].to_i<=0 || ctx[:contact]!=true
      user=ctx[:user]; return false unless opposing?(holder,user)
      return false unless defined?(ALBERT_CG::MOVE_EFFECT) && ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_PERISH)
      sid=ALBERT_CG::MOVE_EFFECT::STATE_PERISH
      h_added=add_state_record(holder,sid); u_added=add_state_record(user,sid)
      holder.instance_variable_set(:@cg_perish_count,3) if h_added
      user.instance_variable_set(:@cg_perish_count,3) if u_added
      return false unless h_added || u_added
      note_trigger(ABILITY_PERISH_BODY,holder,:perish_body,{:attacker_index=>(user.respond_to?(:index) ? user.index.to_i : -1),:state_id=>sid,:holder_added=>h_added,:attacker_added=>u_added,:holder_count=>holder.instance_variable_get(:@cg_perish_count).to_i,:attacker_count=>user.instance_variable_get(:@cg_perish_count).to_i},false)
      true
    rescue
      false
    end

    def self.bad_poison_state_id
      return 0 unless defined?(ALBERT_CG::MOVE_EFFECT)
      return ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON)
      return ALBERT_CG::MOVE_EFFECT::STATE_POISON if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_POISON)
      0
    rescue
      0
    end

    def self.apply_toxic_chain_after_damage(user,target,damage_done,skill=nil)
      return false if user==nil || target==nil || damage_done.to_i<=0 || !opposing?(user,target)
      return false unless ability_id(user)==ABILITY_TOXIC_CHAIN
      proc_ok=active? ? true : (rand(100)<TOXIC_CHAIN_CHANCE)
      return false unless proc_ok
      sid=bad_poison_state_id; return false if sid<=0
      ok=false
      if status_runtime!=nil && status_runtime.respond_to?(:apply_status_from_ability)
        ok=status_runtime.apply_status_from_ability(target,sid,user,:toxic_chain)
      else
        ok=add_state_record(target,sid)
      end
      return false unless ok
      note_trigger(ABILITY_TOXIC_CHAIN,user,:toxic_chain,{:target_index=>(target.respond_to?(:index) ? target.index.to_i : -1),:state_id=>sid,:damage_done=>damage_done.to_i,:move_id=>move_id(skill)},true)
      true
    rescue
      false
    end

    #--------------------------------------------------------------------------
    # Formal KO event：Innards Out + Soul-Heart
    #--------------------------------------------------------------------------
    def self.direct_ability_damage(target,amount)
      return 0 if target==nil || target.hp.to_i<=0 || amount.to_i<=0
      before=target.hp.to_i
      target.hp=[before-amount.to_i,0].max
      dealt=before-target.hp.to_i
      begin
        scene=$scene; spriteset=scene==nil ? nil : scene.instance_variable_get(:@spriteset)
        spriteset.set_damage_pop(target.actor?,target.index,dealt) if dealt>0 && spriteset!=nil && spriteset.respond_to?(:set_damage_pop)
      rescue
      end
      dealt
    rescue
      0
    end

    def self.battle_members
      list=[]
      list.concat($game_party.members) if $game_party!=nil
      list.concat($game_troop.members) if $game_troop!=nil
      list
    rescue
      []
    end

    def self.notify_soul_heart_faint(fallen,reason=:damage)
      return false if fallen==nil || !pokemon_battler?(fallen)
      return false if fallen.instance_variable_get(:@cg_v2530ae_faint_notified)==true
      fallen.instance_variable_set(:@cg_v2530ae_faint_notified,true)
      count=0
      battle_members.each do |holder|
        next if holder==nil || holder==fallen || holder.hidden || holder.hp.to_i<=0
        next unless ability_id(holder)==ABILITY_SOUL_HEART
        before=holder.respond_to?(:cg_stat_stage) ? holder.cg_stat_stage(:spa).to_i : 0
        delta=holder.respond_to?(:cg_change_stat_stage) ? holder.cg_change_stat_stage(:spa,1).to_i : 0
        after=holder.respond_to?(:cg_stat_stage) ? holder.cg_stat_stage(:spa).to_i : before+delta
        note_trigger(ABILITY_SOUL_HEART,holder,:soul_heart,{:fallen_index=>(fallen.respond_to?(:index) ? fallen.index.to_i : -1),:reason=>reason,:before=>before,:delta=>delta,:after=>after},true)
        count+=1
      end
      count>0
    rescue
      false
    end

    def self.handle_damage_ko(target,user,hp_before,holder_ability,user_hp_before)
      return false if target==nil || hp_before.to_i<=0 || target.hp.to_i>0
      if holder_ability.to_i==ABILITY_INNARDS_OUT && user!=nil && opposing?(target,user)
        dealt=direct_ability_damage(user,hp_before.to_i)
        note_trigger(ABILITY_INNARDS_OUT,target,:innards_out,{:attacker_index=>(user.respond_to?(:index) ? user.index.to_i : -1),:holder_hp_before=>hp_before.to_i,:damage=>dealt,:attacker_hp_before=>user_hp_before.to_i,:attacker_hp_after=>user.hp.to_i},true)
        if user_hp_before.to_i>0 && user.hp.to_i<=0 && pokemon_battler?(user)
          notify_soul_heart_faint(user,:innards_out)
        end
      end
      notify_soul_heart_faint(target,:damage)
      true
    rescue
      false
    end

    def self.handle_residual_ko(target,hp_before)
      return false if target==nil || hp_before.to_i<=0 || target.hp.to_i>0
      notify_soul_heart_faint(target,:residual)
    rescue
      false
    end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_WIMP_OUT,:after_damage,self,:apply_wimp_out)
      core.register(ABILITY_EMERGENCY_EXIT,:after_damage,self,:apply_emergency_exit)
      core.register(ABILITY_STAKEOUT,:damage_modify,self,:apply_stakeout)
      core.register(ABILITY_PERISH_BODY,:after_contact,self,:apply_perish_body)
      core.register(ABILITY_SUPREME_OVERLORD,:entry,self,:apply_supreme_entry)
      core.register(ABILITY_SUPREME_OVERLORD,:damage_modify,self,:apply_supreme_damage)
      true
    end

    #--------------------------------------------------------------------------
    # F11 fixture / logging
    #--------------------------------------------------------------------------
    def self.assert_true(label,condition,detail=nil)
      if condition
        log("ASSERT PASS "+label.to_s+(detail==nil ? "" : " "+detail.to_s))
      else
        text=label.to_s+(detail==nil ? "" : " "+detail.to_s); @failures.push(text); log("ASSERT FAIL "+text)
      end
      condition
    end

    def self.reset_log
      h="CG POKEMON ABILITY AE THRESHOLD + KO MOMENTUM AUTO REGRESSION v2.5.30b\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; threshold self-retreat + switch-turn damage + contact status + KO momentum lifecycle\r\n"+
        "BASELINE=v2.5.29b Ability Batch AD Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AD_PASS=240 BATCH_AE=8 PENDING=125\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    end

    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages)
      a.cg_v237_clear_identity if a.respond_to?(:cg_v237_clear_identity); a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime)
      a.instance_variable_set(:@cg_v2530ae_switch_serial,nil); a.instance_variable_set(:@cg_v2530ae_supreme_count,nil); a.instance_variable_set(:@cg_v2530ae_faint_notified,false)
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
        h.instance_variable_set(:@cg_v2530ae_switch_serial,nil); h.instance_variable_set(:@cg_v2530ae_faint_notified,false)
      end
    end

    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0]]
      ms=[]
      TEST_ENEMIES.each_with_index do |c,i|
        configure_enemy(c)
        m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=(i>=4); ms.push(m)
      end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AE v2.5.30b AutoRegression",ms)
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
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_ae,vals[i]) if b}
    end

    def self.prepare_round_preconditions
      a=test_allies; e=all_enemies
      if current_round==1
        @r1_storage_before=storage_size
        e[6].hp=0 if e[6]
        e[6].instance_variable_set(:@cg_v2530ae_faint_notified,true) if e[6]
        [0,1].each do |idx|
          next if e[idx]==nil
          e[idx].hp=e[idx].maxhp.to_i/2+1
        end
        @r1_e0_before=e[0] ? e[0].hp.to_i : 0
        @r1_e1_before=e[1] ? e[1].hp.to_i : 0
      elsif current_round==2
        # Round1 已證明 Perish Body 對 attacker/holder 都成立；後續只保留 E2 的 countdown，
        # 避免 Round3 A3 與 E2 同時 Perish 造成 Soul-Heart residual fixture 混線。
        if a[3] && defined?(ALBERT_CG::MOVE_EFFECT) && ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_PERISH)
          sid=ALBERT_CG::MOVE_EFFECT::STATE_PERISH
          a[3].remove_state(sid) if a[3].state?(sid)
          a[3].instance_variable_set(:@cg_perish_count,nil)
        end
        if e[3]
          e[3].hp=40; e[3].instance_variable_set(:@cg_v2530ae_faint_notified,false)
        end
        @r2_e3_hp_before=e[3] ? e[3].hp.to_i : 0
        @r2_a0_hp_before=a[0] ? a[0].hp.to_i : 0
        @r2_a1_spa_before=a[1]&&a[1].respond_to?(:cg_stat_stage) ? a[1].cg_stat_stage(:spa).to_i : 0
        @stakeout_probes=[]
      elsif current_round==3
        @r3_e2_perish_before=e[2] ? e[2].instance_variable_get(:@cg_perish_count).to_i : 0
        @r3_a1_spa_before=a[1]&&a[1].respond_to?(:cg_stat_stage) ? a[1].cg_stat_stage(:spa).to_i : 0
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
      assert_true("Ability Batch AE defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability AE test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil"))
      assert_true("Ability AE ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability AE starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden&&b.hp.to_i>0})
      assert_true("Ability AE starts with 3 hidden reserve/profile enemies",all_enemies[4,3].all?{|b|b&&b.hidden})
      grid_ok=test_allies[3]&&all_enemies[2]&&test_allies[3].respond_to?(:cg_front_row?)&&all_enemies[2].respond_to?(:cg_front_row?)&&test_allies[3].cg_front_row?&&all_enemies[2].cg_front_row?
      assert_true("Perish Body contact fixture is Grid-legal",grid_ok,"A3="+(test_allies[3]&&test_allies[3].respond_to?(:cg_grid_label) ? test_allies[3].cg_grid_label.to_s : "nil")+" E2="+(all_enemies[2]&&all_enemies[2].respond_to?(:cg_grid_label) ? all_enemies[2].cg_grid_label.to_s : "nil"))
    end

    def self.last_stakeout_probe; @stakeout_probes&& !@stakeout_probes.empty? ? @stakeout_probes[-1] : {}; end

    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==exp,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        wo=records_for(ABILITY_WIMP_OUT,:wimp_out)[-1]||{}
        ok=!wo.empty?&&wo[:hp_before].to_i>e[0].maxhp.to_i/2&&wo[:hp_after].to_i>0&&wo[:hp_after].to_i<=e[0].maxhp.to_i/2&&wo[:incoming_index].to_i==4
        @threshold_checks+=1 if ok; assert_true("Wimp Out crosses half HP and selects E4 reserve",ok,"record="+wo.inspect)

        ee=records_for(ABILITY_EMERGENCY_EXIT,:emergency_exit)[-1]||{}
        ok=!ee.empty?&&ee[:hp_after].to_i>0&&ee[:hp_after].to_i<=e[1].maxhp.to_i/2&&ee[:incoming_index].to_i==5
        @threshold_checks+=1 if ok; assert_true("Emergency Exit crosses half HP and selects E5 reserve",ok,"record="+ee.inspect)

        w_alive=e[0]&&e[0].hidden&&e[0].hp.to_i>0&&e[4]&&!e[4].hidden
        @threshold_checks+=1 if w_alive; assert_true("Wimp Out outgoing survives hidden while E4 becomes active",w_alive,"E0_hp="+(e[0] ? e[0].hp.to_i.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        x_alive=e[1]&&e[1].hidden&&e[1].hp.to_i>0&&e[5]&&!e[5].hidden
        @threshold_checks+=1 if x_alive; assert_true("Emergency Exit outgoing survives hidden while E5 becomes active",x_alive,"E1_hp="+(e[1] ? e[1].hp.to_i.to_s : "nil")+" E5_hidden="+(e[5] ? e[5].hidden.to_s : "nil"))

        st=records_for(ABILITY_STAKEOUT,:stakeout)[-1]||{}
        ok=!st.empty?&&st[:target_index].to_i==4&&st[:after].to_i==st[:before].to_i*2
        @damage_checks+=1 if ok; assert_true("Stakeout doubles damage to E4 switched in this turn",ok,"record="+st.inspect)

        pb=records_for(ABILITY_PERISH_BODY,:perish_body)[-1]||{}
        sid=defined?(ALBERT_CG::MOVE_EFFECT)&&ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_PERISH) ? ALBERT_CG::MOVE_EFFECT::STATE_PERISH : 0
        ok=!pb.empty?&&sid>0&&e[2]&&a[3]&&e[2].state?(sid)&&a[3].state?(sid)&&e[2].instance_variable_get(:@cg_perish_count).to_i==3
        @status_checks+=1 if ok; assert_true("Perish Body applies existing Perish state/count to holder and contact attacker",ok,"record="+pb.inspect+" E2_count="+(e[2] ? e[2].instance_variable_get(:@cg_perish_count).to_i.to_s : "nil"))

        tc=records_for(ABILITY_TOXIC_CHAIN,:toxic_chain)[-1]||{}
        bad=bad_poison_state_id
        ok=!tc.empty?&&bad>0&&e[2]&&e[2].state?(bad)
        @status_checks+=1 if ok; assert_true("Toxic Chain F11 deterministic proc applies Bad Poison after real hit",ok,"record="+tc.inspect+" state="+bad.to_s)

        se=records_for(ABILITY_SUPREME_OVERLORD,:supreme_overlord_entry)[-1]||{}
        assert_true("Supreme Overlord snapshots one pre-fainted same-side Pokemon on E4 entry",!se.empty?&&se[:fainted].to_i==1,"record="+se.inspect)

        life=e[0]&&e[0].hidden&&e[1]&&e[1].hidden&&e[4]&&!e[4].hidden&&e[5]&&!e[5].hidden
        @lifecycle_checks+=1 if life; assert_true("Both threshold self-retreats use battle reserves",life)
        iso=storage_size==@r1_storage_before.to_i
        @lifecycle_checks+=1 if iso; assert_true("Threshold self-retreats do not consume Storage Pokemon",iso,"before="+@r1_storage_before.to_s+" after="+storage_size.to_s)
      elsif r==2
        io=records_for(ABILITY_INNARDS_OUT,:innards_out)[-1]||{}
        io_ok=!io.empty?&&io[:holder_hp_before].to_i==40&&io[:damage].to_i==40&&e[3]&&e[3].hp.to_i<=0&&a[0]&&a[0].hp.to_i==@r2_a0_hp_before.to_i-40
        @damage_checks+=1 if io_ok; assert_true("Innards Out deals exactly fallen holder pre-hit HP to attacker",io_ok,"record="+io.inspect+" E3_hp="+(e[3] ? e[3].hp.to_i.to_s : "nil")+" A0_hp="+@r2_a0_hp_before.to_s+"->"+(a[0] ? a[0].hp.to_i.to_s : "nil"))

        sh=records_for(ABILITY_SOUL_HEART,:soul_heart).select{|x|x[:reason].to_sym==:damage}[-1]||{}
        sh_ok=!sh.empty?&&sh[:fallen_index].to_i==3&&sh[:after].to_i==@r2_a1_spa_before.to_i+1
        @ko_checks+=1 if sh_ok; assert_true("Soul-Heart gains +1 SpA from direct-damage Pokemon KO",sh_ok,"record="+sh.inspect)

        so_records=records_for(ABILITY_SUPREME_OVERLORD,:supreme_overlord_damage)
        so=so_records[-1]||{}
        so_ok=!so.empty?&&so[:fainted].to_i==1&&so[:percent].to_i==110&&so[:after].to_i==so[:before].to_i*110/100
        @damage_checks+=1 if so_ok; assert_true("Supreme Overlord uses entry snapshot one layer for x1.10 damage",so_ok,"record="+so.inspect)
        assert_true("Supreme Overlord never modifies incoming defender-role damage",so_records.size==1,"damage_trigger_count="+so_records.size.to_s)

        probe=last_stakeout_probe
        no_boost=probe!=nil&&!probe.empty?&&probe[:target_index].to_i==4&&probe[:eligible]==false&&records_for(ABILITY_STAKEOUT,:stakeout).size==1
        @damage_checks+=1 if no_boost; assert_true("Stakeout no longer boosts E4 on the following turn",no_boost,"probe="+probe.inspect+" trigger_count="+records_for(ABILITY_STAKEOUT,:stakeout).size.to_s)

        per_count=e[2] ? e[2].instance_variable_get(:@cg_perish_count).to_i : 0
        assert_true("Perish Body lifecycle reaches count=2 before Round2 turn_end",per_count==2,"count="+per_count.to_s)
      elsif r==3
        no_extra=records_for(ABILITY_STAKEOUT,:stakeout).size==1
        assert_true("Stakeout remains single-trigger after switch turn",no_extra,"count="+records_for(ABILITY_STAKEOUT,:stakeout).size.to_s)
        assert_true("Perish Body lifecycle reaches count=1 before Round3 turn_end",@r3_e2_perish_before.to_i==1,"count="+@r3_e2_perish_before.to_i.to_s)
      end
      log("ROUND "+r.to_s+" END")
    end

    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_ae,nil) if b}; end

    def self.finish_suite
      a=test_allies; e=all_enemies
      perished=e[2]&&e[2].hp.to_i<=0
      sh_res=records_for(ABILITY_SOUL_HEART,:soul_heart).select{|x|x[:reason].to_sym==:residual}[-1]||{}
      spa=a[1]&&a[1].respond_to?(:cg_stat_stage) ? a[1].cg_stat_stage(:spa).to_i : -99
      ko_ok=perished&&!sh_res.empty?&&sh_res[:fallen_index].to_i==2&&spa==2
      @ko_checks+=1 if ko_ok; assert_true("Perish residual KO triggers second Soul-Heart and reaches SpA +2",ko_ok,"E2_hp="+(e[2] ? e[2].hp.to_i.to_s : "nil")+" record="+sh_res.inspect+" A1_spa="+spa.to_s)

      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"
      log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_ae="+ability_covered_count.to_s+"/8 threshold_checks="+@threshold_checks.to_i.to_s+" damage_checks="+@damage_checks.to_i.to_s+" status_checks="+@status_checks.to_i.to_s+" ko_checks="+@ko_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=125")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}
      cleanup_test_overrides; @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end

    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false
      @threshold_checks=0; @damage_checks=0; @status_checks=0; @ko_checks=0; @lifecycle_checks=0; @stakeout_probes=[]
      @r1_storage_before=0; @r2_a0_hp_before=0; @r2_a1_spa_before=0; @r3_e2_perish_before=0
    end

    def self.start_auto_test
      return false if active?
      reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AE_v2.5.30b") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
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
ALBERT_CG::ABILITY_AE_V2530.register_handlers if defined?(ALBERT_CG::ABILITY_AE_V2530)

#==============================================================================
# ■ Ability Core switch-in stamp：Stakeout battle-local turn ownership
#==============================================================================
if defined?(ALBERT_CG::ABILITY_V250)
  module ALBERT_CG
    module ABILITY_V250
      class << self
        alias cg_v2530ae_trigger_switch_in trigger_switch_in
        def trigger_switch_in(battler)
          ALBERT_CG::ABILITY_AE_V2530.mark_switch_in(battler) if defined?(ALBERT_CG::ABILITY_AE_V2530)
          cg_v2530ae_trigger_switch_in(battler)
        end
      end
    end
  end
end

#==============================================================================
# ■ Formal damage bridge：Toxic Chain / Innards Out / Soul-Heart direct KO
#==============================================================================
class Game_Battler
  alias cg_v2530ae_execute_damage execute_damage
  def execute_damage(user)
    hp_before_ae=hp.to_i
    holder_ability_ae=defined?(ALBERT_CG::ABILITY_AE_V2530) ? ALBERT_CG::ABILITY_AE_V2530.ability_id(self) : 0
    user_hp_before_ae=user==nil ? 0 : user.hp.to_i
    self.instance_variable_set(:@cg_v2530ae_faint_notified,false) if hp_before_ae>0
    skill_ae=(defined?(ALBERT_CG::ABILITY_V250)&&user!=nil) ? ALBERT_CG::ABILITY_V250.current_skill(user) : nil
    result=cg_v2530ae_execute_damage(user)
    if defined?(ALBERT_CG::ABILITY_AE_V2530)
      damage_done_ae=[hp_before_ae-hp.to_i,0].max
      ALBERT_CG::ABILITY_AE_V2530.apply_toxic_chain_after_damage(user,self,damage_done_ae,skill_ae) if user!=nil
      if hp_before_ae>0 && hp.to_i<=0
        ALBERT_CG::ABILITY_AE_V2530.handle_damage_ko(self,user,hp_before_ae,holder_ability_ae,user_hp_before_ae)
      end
    end
    result
  end

  alias cg_v2530ae_slip_damage_effect slip_damage_effect
  def slip_damage_effect
    hp_before_ae=hp.to_i
    self.instance_variable_set(:@cg_v2530ae_faint_notified,false) if hp_before_ae>0
    result=cg_v2530ae_slip_damage_effect
    if defined?(ALBERT_CG::ABILITY_AE_V2530) && hp_before_ae>0 && hp.to_i<=0
      ALBERT_CG::ABILITY_AE_V2530.handle_residual_ko(self,hp_before_ae)
    end
    result
  end
end

#==============================================================================
# ■ Formal Scene lifecycle：Stakeout turn serial
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2530ae_cycle_start start
  def start
    ALBERT_CG::ABILITY_AE_V2530.begin_battle_cycle if defined?(ALBERT_CG::ABILITY_AE_V2530)
    cg_v2530ae_cycle_start
  end

  alias cg_v2530ae_cycle_turn_end turn_end
  def turn_end
    ALBERT_CG::ABILITY_AE_V2530.advance_turn_serial! if defined?(ALBERT_CG::ABILITY_AE_V2530)
    cg_v2530ae_cycle_turn_end
  end
end

# Disable previous newest F11 harness.
if defined?(ALBERT_CG::ABILITY_AD_V2529)
  module ALBERT_CG
    module ABILITY_AD_V2529
      def self.f11_trigger?; false; end
    end
  end
end

#==============================================================================
# ■ TEST Scene hooks
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2530ae_execute_action execute_action
  def execute_action
    b=@active_battler
    ALBERT_CG::ABILITY_AE_V2530.record_execution(b) if defined?(ALBERT_CG::ABILITY_AE_V2530)&&ALBERT_CG::ABILITY_AE_V2530.active?
    cg_v2530ae_execute_action
  end

  alias cg_v2530ae_test_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AE_V2530)&&ALBERT_CG::ABILITY_AE_V2530.active?
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_AE_V2530.finish_round_assertions
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      else
        ALBERT_CG::ABILITY_AE_V2530.finish_round_assertions
      end
    end
    cg_v2530ae_test_turn_end
  end

  alias cg_v2530ae_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AE_V2530)&&ALBERT_CG::ABILITY_AE_V2530.active?
      return cg_v2530ae_start_party_command
    end
    cg_v2530ae_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_AE_V2530.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AE_V2530.finished?
      ALBERT_CG::ABILITY_AE_V2530.finish_suite; battle_end(0); return
    end
    ALBERT_CG::ABILITY_AE_V2530.prepare_round_actions; start_main
  end
end

class Game_Battler
  alias cg_v2530ae_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AE_V2530)&&ALBERT_CG::ABILITY_AE_V2530.active?
      v=@cg_priority_test_speed_override_ae; return v.to_i if v!=nil
    end
    cg_v2530ae_priority_base_speed
  rescue
    cg_v2530ae_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2530ae_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AE_V2530)&&ALBERT_CG::ABILITY_AE_V2530.active?
      a=ALBERT_CG::ABILITY_AE_V2530.forced_enemy_action(self)
      if a
        cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return
      end
    end
    cg_v2530ae_enemy_make_action
  end
end

module ALBERT_CG
  class << self
    alias cg_v2530ae_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2530ae_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_AE_V2530)&&ALBERT_CG::ABILITY_AE_V2530.active?
        ALBERT_CG::ABILITY_AE_V2530::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AE_V2530.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if h
          h.change_level(ALBERT_CG::ABILITY_AE_V2530::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages)
          h.cg_v237_clear_identity if h.respond_to?(:cg_v237_clear_identity); h.instance_variable_set(:@cg_master_ability_id,0)
          h.instance_variable_set(:@cg_v2530ae_switch_serial,nil); h.instance_variable_set(:@cg_v2530ae_faint_notified,false)
        end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2530ae_scene_map_update update
  def update
    cg_v2530ae_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_AE_V2530)
    ALBERT_CG::ABILITY_AE_V2530.start_auto_test if ALBERT_CG::ABILITY_AE_V2530.f11_trigger?
  end
end
