# RMVX_SCRIPT_INDEX: 253
# RMVX_SCRIPT_ID: 252900002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AD v2.5.29b
# RMVX_SOURCE_SHA256: a1e6ccfabcf1ab81d478eaadcb5db284d2846b0ac01c254c9d2a52ef0b04089e

#==============================================================================
# ■ CG Pokemon Ability Batch AD v2.5.29b - Identity Copy / Transfer / Mutation TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.28a Ability Batch AC RPG Maker VX 實機 PASS 為唯一正式基底，新增 8 個
#  尚未覆蓋的主系列 Ability，集中處理「型態／Ability 身分變化、入場複製、接觸傳染／交換、
#  隊友倒下後繼承」。沿用 Unique Move Batch D 的 Battle-only Type/Ability Override、
#  Unique Move Batch I 的 Transform Runtime、Ability Core after_damage/after_contact，以及既有
#  Force Switch / Teleport lifecycle；不修改已 PASS Move Core 與 Ability A..AC。
#
# 【本批 Ability】
#   16 Color Change / 變色：受到有傷害招式命中後，Battle-only Type 改成該招式屬性。
#   36 Trace / 複製：入場時從 active 對手中選一個可複製 Ability，Battle-only 取代 Trace。
#  150 Imposter / 變身者：入場時自動沿用既有 Transform Runtime 變成一名 active 對手 Pokémon。
#  152 Mummy / 木乃伊：受到接觸招式命中後，攻擊者的可變 Ability 改為 Mummy。
#  222 Receiver / 接球手：同側 active 隊友因實傷倒下時，複製該隊友可繼承的有效 Ability。
#  223 Power of Alchemy / 化學之力：同 Receiver，同側隊友倒下時複製其有效 Ability。
#  254 Wandering Spirit / 遊魂：受到接觸招式命中後，與攻擊者交換可交換的有效 Ability。
#  268 Lingering Aroma / 甩不掉的氣味：受到接觸招式命中後，攻擊者可變 Ability 改為 Lingering Aroma。
#
# 【主要設定項】
#  TEST_TROOP_ID=732；HANDLED_ABILITY_IDS=8。
#  Static coverage：232/373 -> 240/373，pending 141 -> 133。
#  TRACE_UNCOPYABLE / INHERIT_UNCOPYABLE / ABILITY_UNCHANGEABLE：集中列出不應被本批複製／覆寫
#  的 form-lock / special identity Ability；後續若正式導入新的不可變 Ability，只需擴充常數。
#
# 【機制規則】
#  1. 正式有效 Ability 一律讀 Ability Core ability_id / cg_master_ability_id；所有變化寫入
#     cg_v237_set_ability / cg_v237_set_types，因此換出時仍由既有 v2.3.7a identity cleanup 清掉，
#     不永久改 Species / Actor / Enemy 資料。
#  2. Trace 正式戰鬥從可複製 active 對手中隨機選擇；F11 Regression 為確定性，固定選 index 最小者。
#     Receiver / Power of Alchemy / Imposter / Trace 等不可複製 Ability 依現代規則列入 blacklist。
#  3. Imposter 不重寫 Transform；直接呼叫 UNIQUE_I_V242.apply_transform。Human 不屬於 Pokémon，
#     因此本作 1 Human + 3 Pokémon 格式下 Imposter 只從 opposing Pokémon 中選目標。
#  4. Mummy / Lingering Aroma / Wandering Spirit 只在 opposing contact Action 真正進入 after_contact
#     後處理；Protect／miss／未進 damage chain 不會憑空傳染 Ability。
#  5. Receiver / Power of Alchemy 需要「其他 active ally faint」事件；Ability Core 尚無 ally_ko trigger，
#     因此本批只在最外層 execute_damage 偵測 hp_before>0 -> hp_after<=0，保存倒下前有效 Ability，
#     再通知同側 holder。這是單一 event bridge，不修改 Core TRIGGERS。
#  6. Color Change 只處理 damage_done>0 的招式；Status Move / 未造成實傷不改 Type。
#  7. F11 Regression 使用真正 Scene_Battle、Water Gun、Aerial Ace、Tackle、Aura Sphere、Teleport 與 Transform
#     lifecycle；不以直接呼叫 handler 冒充戰鬥結果。
#  8. v2.5.29a 修正 Pokémon Actor 身分判定：除了 Clone cg_pet?，也接受 cg_battle_pet? 與
#     SPECIES26 dex mapping，因此 Species 對應普通 Actor／固定夥伴不會被 Trace / Imposter 誤排除。
#  9. v2.5.29 的 Lingering Aroma 唯一失敗沒有留下 damage/contact 證據；v2.5.29a 不先改 268
#     Formal handler，而把 Human A0 測試技改為必中接觸技 Aerial Ace 332，並增加目標 HP 實傷檢查。
# 10. v2.5.29a 實機證明 A0 的 Aerial Ace 被 Battlefield Grid 依法 fallback 到 E0：Tom 為後排近戰、
#     原 E3 Lingering Aroma holder 也在後排，target_index=3 並非合法直接目標。v2.5.29b 不繞過 Grid；
#     只交換正式 troop 座標，讓 E3 位於前排、E0 Trace holder 位於後排，並在 bootstrap ASSERT 鎖定此條件。
#
# 【可調參數】
#  TEST_TROOP_ID、TEST_LEVEL、TRACE_UNCOPYABLE、INHERIT_UNCOPYABLE、ABILITY_UNCHANGEABLE。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫。開發測試：地圖按 F11，自動進 troop 732，跑三回合並輸出
#  Pokemon_Ability_AD_AutoTest_v2_5_29b.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  battle-start：E0 Trace 因 A1 Receiver / A2 Power of Alchemy 不可被 Trace 複製，確定複製 A3 Color Change。
#  Round1：E1 Water Gun -> A3 Color Change 變 Water；A3 Tackle -> E1 Mummy，A3 Ability 變 Mummy；
#          Human A0 Aerial Ace -> E3 Lingering Aroma，先確認 E3 實傷，再驗 A0 Battle-only Ability 變 268。
#  Round2：E1 Aura Sphere 將預設 HP=1 的 A3 KO；A1 Receiver、A2 Power of Alchemy 同時繼承 Mummy；
#          E3 Teleport -> hidden E4 Imposter，E4 真正 Transform 成 A1。
#  Round3：A1（Mummy）Tackle -> E2 Wandering Spirit，雙方 Ability 交換為 A1=254、E2=152。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchAD"] = "2.5.29b"

module ALBERT_CG
  module ABILITY_AD_V2529
    VERSION = "2.5.29b"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 732
    VK_F11 = 0x7A

    ABILITY_COLOR_CHANGE      = 16
    ABILITY_TRACE             = 36
    ABILITY_IMPOSTER          = 150
    ABILITY_MUMMY             = 152
    ABILITY_RECEIVER          = 222
    ABILITY_POWER_OF_ALCHEMY  = 223
    ABILITY_WANDERING_SPIRIT  = 254
    ABILITY_LINGERING_AROMA   = 268
    HANDLED_ABILITY_IDS = [16,36,150,152,222,223,254,268]

    # Gen IX-oriented copy restrictions for abilities already represented in this project.
    TRACE_UNCOPYABLE = [36,59,121,149,150,176,189,190,191,197,208,209,210,211,213,
      222,223,225,241,248,256,258,266,267,278,279,281,282,303,304,305,306,307]
    INHERIT_UNCOPYABLE = [36,150,176,189,190,191,197,208,209,210,211,213,222,223,225,
      241,248,256,258,266,267,278,279,281,282,303,304,305,306,307]
    ABILITY_UNCHANGEABLE = [121,176,189,190,191,197,208,209,210,211,213,225,241,248,
      256,258,266,267,279,281,282,303,304,305,306]

    TEST_ALLIES = [
      {:dex=>68, :level=>40,:ability=>ABILITY_RECEIVER,         :moves=>[150,33,150,150]},
      {:dex=>89, :level=>40,:ability=>ABILITY_POWER_OF_ALCHEMY, :moves=>[150,150,150,150]},
      {:dex=>352,:level=>40,:ability=>ABILITY_COLOR_CHANGE,      :moves=>[33,150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>282,:level=>50,:ability=>ABILITY_TRACE,            :moves=>[150,150,150,150]},
      {:dex=>110,:level=>50,:ability=>ABILITY_MUMMY,            :moves=>[55,396,150,150]},
      {:dex=>94, :level=>50,:ability=>ABILITY_WANDERING_SPIRIT, :moves=>[150,150,150,150]},
      {:dex=>88, :level=>50,:ability=>ABILITY_LINGERING_AROMA,  :moves=>[150,100,150,150]},
      {:dex=>132,:level=>50,:ability=>ABILITY_IMPOSTER,         :moves=>[150,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"COLOR_MUMMY_LINGERING_CONTACT",
        :allies=>[
          {:kind=>:move,:move_id=>332,:target=>3},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>33,:target=>1},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>55,:target=>3},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"ALLY_FAINT_INHERIT_AND_IMPOSTER_SWITCH",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>396,:target=>3},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>100,:target=>3},
        }
      },
      {
        :name=>"WANDERING_SPIRIT_SWAP_STABILITY",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>33,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
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
      :r1=>[420,300,290,380, 280,400,270,260,0],
      :r2=>[10,310,300,200, 290,420,280,10,0],
      :r3=>[10,420,300,0, 260,250,240,0,320],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:M332","E1:M55","A3:M33","A1:M150","A2:M150","E0:M150","E2:M150","E3:M150"],
      2=>["A0:Guard","E1:M396","A1:M150","A2:M150","E0:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","A1:M33","E4:M150","A2:M150","E0:M150","E1:M150","E2:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.transform_runtime; defined?(ALBERT_CG::UNIQUE_I_V242) ? ALBERT_CG::UNIQUE_I_V242 : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.storage_size; defined?(ALBERT_CG::PET_STORAGE)&&ALBERT_CG::PET_STORAGE.respond_to?(:size) ? ALBERT_CG::PET_STORAGE.size.to_i : 0; rescue; 0; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_AD_AutoTest_v2_5_29b.log"); end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.write_line(path,text,mode="ab"); File.open(path,mode){|f|f.write(text.to_s+"\r\n")}; true; rescue; false; end
    def self.log(text); write_line(log_path,text); write_line(latest_log_path,text); rescue; end
    def self.key_down?(code); KEY_API!=nil && (KEY_API.call(code)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.ability_id(b); core==nil || b==nil ? 0 : core.ability_id(b).to_i; rescue; 0; end
    def self.same_side?(a,b); a!=nil&&b!=nil&&a.respond_to?(:actor?)&&b.respond_to?(:actor?)&&a.actor? == b.actor?; rescue; false; end
    def self.opposing?(a,b); a!=nil&&b!=nil&&a.respond_to?(:actor?)&&b.respond_to?(:actor?)&&a.actor? != b.actor?; rescue; false; end
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
        core.runtime_log("ABILITY_AD_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect)
        core.note_trigger(kind,battler,aid,rec)
        core.present_trigger(battler,aid,kind,rec) if present
      end
      log("ABILITY_AD_TRIGGER ability="+aid.to_i.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect) if active?
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

    def self.pokemon_battler?(b)
      return false if b==nil
      return true unless b.actor?
      return true if b.respond_to?(:cg_battle_pet?) && b.cg_battle_pet?
      return true if b.respond_to?(:cg_pet?) && b.cg_pet?
      actor_id = b.respond_to?(:cg_database_actor_id) ? b.cg_database_actor_id.to_i :
                 (b.respond_to?(:id) ? b.id.to_i : 0)
      if defined?(ALBERT_CG::SPECIES26) && ALBERT_CG::SPECIES26.respond_to?(:dex_for_actor_id)
        return ALBERT_CG::SPECIES26.dex_for_actor_id(actor_id).to_i > 0
      end
      false
    rescue
      false
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

    def self.set_effective_types(b,types)
      return false if b==nil || !b.respond_to?(:cg_v237_set_types)
      b.cg_v237_set_types(types); true
    rescue
      false
    end

    def self.trace_copyable?(aid)
      x=aid.to_i; x>0 && !TRACE_UNCOPYABLE.include?(x)
    end
    def self.inherit_copyable?(aid)
      x=aid.to_i; x>0 && !INHERIT_UNCOPYABLE.include?(x)
    end
    def self.ability_changeable?(aid)
      x=aid.to_i; !ABILITY_UNCHANGEABLE.include?(x)
    end

    def self.move_type(mid)
      row=master&&master.respond_to?(:move) ? master.move(mid.to_i) : nil
      row==nil ? nil : row[2]
    rescue
      nil
    end

    def self.apply_trace(holder,ctx)
      return false if holder==nil
      candidates=opponents_of(holder).select{|b|b&&pokemon_battler?(b)&&trace_copyable?(ability_id(b))}
      return false if candidates.empty?
      target = active? ? candidates.sort_by{|b|b.index.to_i}[0] : candidates[rand(candidates.size)]
      copied=ability_id(target); return false unless trace_copyable?(copied)
      before=ability_id(holder)
      ok=set_effective_ability(holder,copied)
      if ok
        note_trigger(ABILITY_TRACE,holder,:trace,{:source_index=>target.index.to_i,:before=>before,:copied=>copied,:after=>ability_id(holder)},false)
      end
      ok
    end

    def self.apply_imposter(holder,ctx)
      return false if holder==nil || transform_runtime==nil || !transform_runtime.respond_to?(:apply_transform)
      candidates=opponents_of(holder).select{|b|b&&pokemon_battler?(b)}
      return false if candidates.empty?
      target=candidates.sort_by{|b|b.index.to_i}[0]
      source_ability=ability_id(target)
      ok=transform_runtime.apply_transform(holder,target)
      if ok
        note_trigger(ABILITY_IMPOSTER,holder,:imposter,{:source_index=>target.index.to_i,:copied_ability=>source_ability,:after=>ability_id(holder)},false)
      end
      ok
    end

    def self.apply_color_change(holder,ctx)
      return false if holder==nil || ctx==nil || ctx[:damage_done].to_i<=0
      mid=ctx[:move_id].to_i; typ=move_type(mid); return false if typ==nil
      before=holder.respond_to?(:cg_pokemon_types) ? holder.cg_pokemon_types.clone : []
      return false if before.size==1 && before[0].to_sym==typ.to_sym
      ok=set_effective_types(holder,[typ]); return false unless ok
      after=holder.respond_to?(:cg_pokemon_types) ? holder.cg_pokemon_types.clone : [typ]
      note_trigger(ABILITY_COLOR_CHANGE,holder,:color_change,{:move_id=>mid,:type=>typ,:before=>before,:after=>after},false)
      true
    end

    def self.apply_mummy(holder,ctx)
      return false unless contact_identity_valid?(holder,ctx)
      user=ctx[:user]; before=ability_id(user)
      return false if before==ABILITY_MUMMY || !ability_changeable?(before)
      ok=set_effective_ability(user,ABILITY_MUMMY); return false unless ok
      note_trigger(ABILITY_MUMMY,holder,:mummy,{:attacker_index=>user.index.to_i,:before=>before,:after=>ability_id(user)},false)
      true
    end

    def self.apply_lingering_aroma(holder,ctx)
      return false unless contact_identity_valid?(holder,ctx)
      user=ctx[:user]; before=ability_id(user)
      return false if before==ABILITY_LINGERING_AROMA || !ability_changeable?(before)
      ok=set_effective_ability(user,ABILITY_LINGERING_AROMA); return false unless ok
      note_trigger(ABILITY_LINGERING_AROMA,holder,:lingering_aroma,{:attacker_index=>user.index.to_i,:before=>before,:after=>ability_id(user)},false)
      true
    end

    def self.apply_wandering_spirit(holder,ctx)
      return false unless contact_identity_valid?(holder,ctx)
      user=ctx[:user]; ha=ability_id(holder); ua=ability_id(user)
      return false if ha<=0 || !ability_changeable?(ha) || !ability_changeable?(ua) || ha==ua
      return false unless set_effective_ability(user,ha)
      unless set_effective_ability(holder,ua)
        set_effective_ability(user,ua); return false
      end
      note_trigger(ABILITY_WANDERING_SPIRIT,holder,:wandering_spirit,{:attacker_index=>user.index.to_i,:attacker_before=>ua,:holder_before=>ha,:attacker_after=>ability_id(user),:holder_after=>ability_id(holder)},false)
      true
    end

    def self.contact_identity_valid?(holder,ctx)
      return false if holder==nil || ctx==nil || ctx[:contact]!=true || ctx[:user]==nil
      return false unless opposing?(holder,ctx[:user])
      true
    rescue
      false
    end

    def self.notify_ally_faint(fallen,fallen_ability)
      return false if fallen==nil || !inherit_copyable?(fallen_ability)
      unit=fallen.actor? ? $game_party : $game_troop
      return false if unit==nil
      copied=0
      unit.members.each do |holder|
        next if holder==nil || holder==fallen || holder.hidden || holder.hp.to_i<=0
        aid=ability_id(holder)
        next unless aid==ABILITY_RECEIVER || aid==ABILITY_POWER_OF_ALCHEMY
        kind=aid==ABILITY_RECEIVER ? :receiver : :power_of_alchemy
        before=aid
        note_trigger(aid,holder,kind,{:fallen_index=>fallen.index.to_i,:before=>before,:copied=>fallen_ability.to_i},true)
        copied+=1 if set_effective_ability(holder,fallen_ability.to_i)
      end
      copied>0
    rescue
      false
    end

    def self.register_handlers
      return false if core==nil
      core.register(ABILITY_TRACE,:entry,self,:apply_trace)
      core.register(ABILITY_IMPOSTER,:entry,self,:apply_imposter)
      core.register(ABILITY_COLOR_CHANGE,:after_damage,self,:apply_color_change)
      core.register(ABILITY_MUMMY,:after_contact,self,:apply_mummy)
      core.register(ABILITY_WANDERING_SPIRIT,:after_contact,self,:apply_wandering_spirit)
      core.register(ABILITY_LINGERING_AROMA,:after_contact,self,:apply_lingering_aroma)
      true
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
      h="CG POKEMON ABILITY AD IDENTITY COPY + TRANSFER + MUTATION AUTO REGRESSION v2.5.29b\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; battle-only type/ability identity copy + contact transfer + ally-faint inheritance lifecycle\r\n"+
        "BASELINE=v2.5.28a Ability Batch AC Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AC_PASS=232 BATCH_AD=8 PENDING=133\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    end

    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return if a==nil
      master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages)
      a.cg_v237_clear_identity if a.respond_to?(:cg_v237_clear_identity); a.cg_v242_clear_runtime if a.respond_to?(:cg_v242_clear_runtime)
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
      end
    end

    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      # v2.5.29b：Lingering Aroma regression 必須遵守正式 Battlefield Grid。
      # Tom 預設後排且 Aerial Ace 為近戰接觸；E3 若也在後排，正式 Grid 會將 target_index=3
      # fallback 到第一個合法前排敵人。故只交換 E0 / E3 的前後排座標，不繞過 target legality。
      xs=[ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1]]
      ms=[]
      TEST_ENEMIES.each_with_index do |c,i|
        configure_enemy(c)
        m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=(i>=4); ms.push(m)
      end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AD v2.5.29b AutoRegression",ms)
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
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_ad,vals[i]) if b}
    end

    def self.prepare_round_preconditions
      a=test_allies; e=all_enemies
      if current_round==1
        @r1_a3_types_before=a[3]&&a[3].respond_to?(:cg_pokemon_types) ? a[3].cg_pokemon_types.clone : []
        @r1_e3_hp_before=e[3] ? e[3].hp.to_i : 0
      elsif current_round==2
        @r2_storage_before=storage_size
        a[3].hp=1 if a[3]
        @r2_fallen_ability_before=ability_id(a[3]) if a[3]
      elsif current_round==3
        @r3_a1_before=ability_id(a[1]) if a[1]
        @r3_e2_before=ability_id(e[2]) if e[2]
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
      assert_true("Ability Batch AD defines 8 handled IDs",HANDLED_ABILITY_IDS.size==8,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability AD test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil"))
      assert_true("Ability AD ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability AD starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden&&b.hp.to_i>0})
      assert_true("Ability AD starts with 1 hidden Imposter reserve",all_enemies[4]&&all_enemies[4].hidden,"E4_hidden="+(all_enemies[4] ? all_enemies[4].hidden.to_s : "nil"))
      # v2.5.29b：鎖定 Human A0 -> E3 Aerial Ace 的正式 Grid 合法性。
      a0=test_allies[0]; e3=all_enemies[3]
      grid_ok=a0&&e3&&a0.respond_to?(:cg_back_row?)&&e3.respond_to?(:cg_front_row?)&&a0.cg_back_row?&&e3.cg_front_row?
      assert_true("Lingering Aroma regression target is Grid-legal",grid_ok,
        "A0="+(a0&&a0.respond_to?(:cg_grid_label) ? a0.cg_grid_label.to_s : "nil")+
        " E3="+(e3&&e3.respond_to?(:cg_grid_label) ? e3.cg_grid_label.to_s : "nil"))
    end

    def self.assert_round
      r=current_round; a=test_allies; e=all_enemies; exp=EXPECTED_EXECUTION_TOKENS[r]||[]
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",@actual==exp,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        tr=records_for(ABILITY_TRACE,:trace)[-1]||{}
        ok=!tr.empty?&&tr[:copied].to_i==ABILITY_COLOR_CHANGE&&ability_id(e[0])==ABILITY_COLOR_CHANGE
        @copy_checks+=1 if ok; assert_true("Trace copies the only eligible opposing Ability Color Change",ok,"record="+tr.inspect+" E0_ability="+ability_id(e[0]).to_s)

        cc=records_for(ABILITY_COLOR_CHANGE,:color_change)[-1]||{}
        types=a[3]&&a[3].respond_to?(:cg_pokemon_types) ? a[3].cg_pokemon_types : []
        ok=!cc.empty?&&cc[:move_id].to_i==55&&cc[:type].to_sym==:water&&types.include?(:water)
        @identity_checks+=1 if ok; assert_true("Color Change turns A3 into Water after real Water Gun damage",ok,"before="+@r1_a3_types_before.inspect+" after="+types.inspect+" record="+cc.inspect)

        mm=records_for(ABILITY_MUMMY,:mummy)[-1]||{}
        ok=!mm.empty?&&mm[:attacker_index].to_i==3&&ability_id(a[3])==ABILITY_MUMMY
        @contact_checks+=1 if ok; assert_true("Mummy changes contact attacker A3 Ability to Mummy",ok,"record="+mm.inspect+" A3_ability="+ability_id(a[3]).to_s)

        e3_damage=e[3]&&e[3].hp.to_i<@r1_e3_hp_before.to_i
        assert_true("Lingering Aroma fixture Aerial Ace deals real contact damage",e3_damage,
          "E3_hp="+@r1_e3_hp_before.to_i.to_s+"->"+(e[3] ? e[3].hp.to_i.to_s : "nil"))
        la=records_for(ABILITY_LINGERING_AROMA,:lingering_aroma)[-1]||{}
        ok=e3_damage&&!la.empty?&&la[:attacker_index].to_i==0&&ability_id(a[0])==ABILITY_LINGERING_AROMA
        @contact_checks+=1 if ok; assert_true("Lingering Aroma changes Human contact attacker battle-only Ability",ok,"record="+la.inspect+" A0_ability="+ability_id(a[0]).to_s)
      elsif r==2
        rr=records_for(ABILITY_RECEIVER,:receiver)[-1]||{}
        ok=!rr.empty?&&rr[:fallen_index].to_i==3&&rr[:copied].to_i==ABILITY_MUMMY&&ability_id(a[1])==ABILITY_MUMMY
        @copy_checks+=1 if ok; assert_true("Receiver copies fallen ally Mummy Ability",ok,"record="+rr.inspect+" A1_ability="+ability_id(a[1]).to_s)

        pa=records_for(ABILITY_POWER_OF_ALCHEMY,:power_of_alchemy)[-1]||{}
        ok=!pa.empty?&&pa[:fallen_index].to_i==3&&pa[:copied].to_i==ABILITY_MUMMY&&ability_id(a[2])==ABILITY_MUMMY
        @copy_checks+=1 if ok; assert_true("Power of Alchemy copies fallen ally Mummy Ability",ok,"record="+pa.inspect+" A2_ability="+ability_id(a[2]).to_s)

        imp=records_for(ABILITY_IMPOSTER,:imposter)[-1]||{}
        transformed=e[4]&&e[4].instance_variable_get(:@cg_v242_transformed)==true
        source=e[4] ? e[4].instance_variable_get(:@cg_v242_transform_source) : nil
        ok=!imp.empty?&&imp[:source_index].to_i==1&&transformed&&source==a[1]&&ability_id(e[4])==ABILITY_MUMMY
        @identity_checks+=1 if ok; assert_true("Imposter switch-in uses sealed Transform Runtime on A1",ok,"record="+imp.inspect+" transformed="+transformed.to_s+" E4_ability="+ability_id(e[4]).to_s)

        sw=e[3]&&e[3].hidden&&e[4]&&!e[4].hidden
        @lifecycle_checks+=1 if sw; assert_true("Teleport deploys hidden Imposter reserve",sw,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        iso=storage_size==@r2_storage_before.to_i
        @lifecycle_checks+=1 if iso; assert_true("Imposter reserve switch does not consume Storage Pokemon",iso,"before="+@r2_storage_before.to_s+" after="+storage_size.to_s)
      elsif r==3
        ws=records_for(ABILITY_WANDERING_SPIRIT,:wandering_spirit)[-1]||{}
        ok=!ws.empty?&&ws[:attacker_index].to_i==1&&ws[:attacker_before].to_i==ABILITY_MUMMY&&ws[:holder_before].to_i==ABILITY_WANDERING_SPIRIT&&ability_id(a[1])==ABILITY_WANDERING_SPIRIT&&ability_id(e[2])==ABILITY_MUMMY
        @contact_checks+=1 if ok; assert_true("Wandering Spirit swaps Mummy and Wandering Spirit on contact",ok,"record="+ws.inspect+" A1="+ability_id(a[1]).to_s+" E2="+ability_id(e[2]).to_s)

        stable=e[4]&&!e[4].hidden&&e[4].hp.to_i>0&&e[4].instance_variable_get(:@cg_v242_transformed)==true
        @identity_checks+=1 if stable; assert_true("Imposter transformed reserve remains active through Round3",stable,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" hp="+(e[4] ? e[4].hp.to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end

    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_ad,nil) if b}; end

    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"
      log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_ad="+ability_covered_count.to_s+"/8 identity_checks="+@identity_checks.to_i.to_s+" copy_checks="+@copy_checks.to_i.to_s+" contact_checks="+@contact_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=133")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}
      cleanup_test_overrides; @active=false
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end

    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false
      @identity_checks=0; @copy_checks=0; @contact_checks=0; @lifecycle_checks=0; @r2_storage_before=0; @r1_e3_hp_before=0
    end

    def self.start_auto_test
      return false if active?
      reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AD_v2.5.29b") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
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
ALBERT_CG::ABILITY_AD_V2529.register_handlers if defined?(ALBERT_CG::ABILITY_AD_V2529)

#==============================================================================
# ■ Formal Receiver / Power of Alchemy：ally faint event bridge
#==============================================================================
class Game_Battler
  alias cg_v2529ad_ally_faint_execute_damage execute_damage
  def execute_damage(user)
    hp_before_ad=hp.to_i
    fallen_ability_ad=defined?(ALBERT_CG::ABILITY_AD_V2529) ? ALBERT_CG::ABILITY_AD_V2529.ability_id(self) : 0
    result=cg_v2529ad_ally_faint_execute_damage(user)
    if hp_before_ad>0 && hp.to_i<=0 && defined?(ALBERT_CG::ABILITY_AD_V2529)
      ALBERT_CG::ABILITY_AD_V2529.notify_ally_faint(self,fallen_ability_ad)
    end
    result
  end
end

# Disable previous newest F11 harness.
if defined?(ALBERT_CG::ABILITY_AC_V2528)
  module ALBERT_CG
    module ABILITY_AC_V2528
      def self.f11_trigger?; false; end
    end
  end
end

#==============================================================================
# ■ TEST Scene hooks
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2529ad_execute_action execute_action
  def execute_action
    b=@active_battler
    ALBERT_CG::ABILITY_AD_V2529.record_execution(b) if defined?(ALBERT_CG::ABILITY_AD_V2529)&&ALBERT_CG::ABILITY_AD_V2529.active?
    cg_v2529ad_execute_action
  end

  alias cg_v2529ad_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AD_V2529)&&ALBERT_CG::ABILITY_AD_V2529.active?
      if defined?(ALBERT_CG::ABILITY_V250)
        ALBERT_CG::ABILITY_V250.trigger_end_turn
        ALBERT_CG::ABILITY_AD_V2529.finish_round_assertions
        ALBERT_CG::ABILITY_V250.suppress_next_end_turn!
      else
        ALBERT_CG::ABILITY_AD_V2529.finish_round_assertions
      end
    end
    cg_v2529ad_turn_end
  end

  alias cg_v2529ad_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AD_V2529)&&ALBERT_CG::ABILITY_AD_V2529.active?
      return cg_v2529ad_start_party_command
    end
    cg_v2529ad_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_AD_V2529.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AD_V2529.finished?
      ALBERT_CG::ABILITY_AD_V2529.finish_suite; battle_end(0); return
    end
    ALBERT_CG::ABILITY_AD_V2529.prepare_round_actions; start_main
  end
end

class Game_Battler
  alias cg_v2529ad_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AD_V2529)&&ALBERT_CG::ABILITY_AD_V2529.active?
      v=@cg_priority_test_speed_override_ad; return v.to_i if v!=nil
    end
    cg_v2529ad_priority_base_speed
  rescue
    cg_v2529ad_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2529ad_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AD_V2529)&&ALBERT_CG::ABILITY_AD_V2529.active?
      a=ALBERT_CG::ABILITY_AD_V2529.forced_enemy_action(self)
      if a
        cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return
      end
    end
    cg_v2529ad_enemy_make_action
  end
end

module ALBERT_CG
  class << self
    alias cg_v2529ad_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2529ad_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_AD_V2529)&&ALBERT_CG::ABILITY_AD_V2529.active?
        ALBERT_CG::ABILITY_AD_V2529::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AD_V2529.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if h
          h.change_level(ALBERT_CG::ABILITY_AD_V2529::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages)
          h.cg_v237_clear_identity if h.respond_to?(:cg_v237_clear_identity); h.instance_variable_set(:@cg_master_ability_id,0)
        end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2529ad_scene_map_update update
  def update
    cg_v2529ad_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_AD_V2529)
    ALBERT_CG::ABILITY_AD_V2529.start_auto_test if ALBERT_CG::ABILITY_AD_V2529.f11_trigger?
  end
end
