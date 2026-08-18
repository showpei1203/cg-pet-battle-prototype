# RMVX_SCRIPT_INDEX: 242
# RMVX_SCRIPT_ID: 251900002
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch T v2.5.19a
# RMVX_SOURCE_SHA256: e5e532ebedf61a0670eb835992f2d2f7eb6f2c7173e8f5169a561d9025e55977

#==============================================================================
# ■ CG Pokemon Ability Batch T v2.5.19a - Global Stat Assertion Timing Fix TEST
#------------------------------------------------------------------------------
# 【用途】
#  以 v2.5.18 Ability Batch S RPG Maker VX 實機 PASS 為唯一基底，實作第二十批
#  8 個 Ability。本批集中處理「場上全域能力值 Aura、屬性傷害修正、狀態防護、
#  屬性吸收」，沿用既有 Ability Core、Field Weather、Stat Query、Damage Role、
#  Guard Authority 與 Before Hit lifecycle；不修改 Move 937/937 封版內容。
#
# 【本批 Ability】
#  122 Flower Gift       花之禮：Sun 下自己與同伴 ATK / SPD x1.50。
#  199 Water Bubble      水泡：Water 招式傷害 x2；受到 Fire 傷害 x0.50；免疫 Burn。
#  272 Purifying Salt    潔淨之鹽：主要異常狀態無效；受到 Ghost 傷害 x0.50。
#  284 Vessel of Ruin    災禍之鼎：除持有者外，場上其他 battler SPA x0.75。
#  285 Sword of Ruin     災禍之劍：除持有者外，場上其他 battler DEF x0.75。
#  286 Tablets of Ruin   災禍之簡：除持有者外，場上其他 battler ATK x0.75。
#  287 Beads of Ruin     災禍之玉：除持有者外，場上其他 battler SPD x0.75。
#  297 Earth Eater       食土：被對手 Ground 傷害招式命中時取消傷害並回復 MaxHP 1/4。
#
# 【主要設定項】
#  TEST_TROOP_ID=722；HANDLED_ABILITY_IDS=8。
#  Coverage：152/373 -> 160/373，pending 221 -> 213。
#  FLOWER_GIFT_PERCENT=150；RUIN_PERCENT=75；WATER_BUBBLE_WATER_PERCENT=200；
#  WATER_BUBBLE_FIRE_PERCENT=50；PURIFYING_GHOST_PERCENT=50；EARTH_EATER_HEAL_DENOM=4。
#
# 【機制規則】
#  1. Flower Gift / 四種 Ruin 使用新增 :global_stat_query trigger。Game_Battler 的正式
#     cg_atk_stat / cg_def_stat / cg_spa / cg_spd 完整算完 Base、Stage、Field、自己 Ability
#     後，才掃描 active holders 套全域 Aura，不重做任何基礎能力值公式。
#  2. Flower Gift 只在 FIELD_V233 的 Sun 有效時作用，且只作用於 holder 同側 active battler。
#  3. 每一種 Ruin 同名效果只取一個 active holder，避免同名 Ability 重複疊乘；不同 Ruin
#     彼此可同時存在。Ruin 不影響該 holder 自身。
#  4. Water Bubble / Purifying Salt 只走既有 :damage_modify；Fixed Damage 不吃倍率。
#  5. Water Bubble 的 Burn immunity 與 Purifying Salt 的主要異常 immunity 透過既有
#     Guard Authority 的 guard_state?/block_state 入口擴充，不新增第二套狀態附加系統。
#  6. Earth Eater 使用既有 :before_hit，依 Ability Modifier Authority 的有效招式 Type 判斷；
#     對手 Ground 正傷害招式命中時直接 cancel 並回復 1/4 MaxHP，與 Water Absorb 相同權威層。
#  7. 有效 Ability 一律由 Ability Core ability_id 取得，持續尊重 Suppression / Override；
#     hidden / KO reserve 不參與 global Aura。
#  8. F11 Regression 使用 Actual Scene_Battle。TEST-only 只固定 Hit/Evasion、Action/SPE、
#     Sun fixture 與測試 HP；正式玩家戰鬥 RNG、傷害公式、Field duration 都不修改。
#  9. Round2 使用正式 Teleport 部署 hidden Purifying Salt reserve；Storage 不是 battle reserve。
# 10. TEST Convenience 僅限 F11；正式 Release 仍須恢復 emerged、BGM/BGS、正常焦點。
# 11. v2.5.19a 僅修 TEST assertion timing：global-stat 六項必須在 Round1 正式 stat query probes 完成後才驗證；Formal handlers / bridges 完全不變。
#
# 【可調參數】
#  FLOWER_GIFT_PERCENT、RUIN_PERCENT、WATER_BUBBLE_WATER_PERCENT、
#  WATER_BUBBLE_FIRE_PERCENT、PURIFYING_GHOST_PERCENT、EARTH_EATER_HEAL_DENOM。
#
# 【事件／腳本呼叫方式】
#  正式戰鬥不需事件呼叫；Ability 由 Stat / Damage / Before Hit / State Guard lifecycle 自動處理。
#  開發測試：地圖按 F11，自動進 troop 722，跑三回合並輸出
#  Pokemon_Ability_T_AutoTest_v2_5_19a.log 與 CG_AutoRegression_LATEST.log。
#
# 【實際範例】
#  Round1：Sun fixture 下查詢正式能力值，驗 Flower Gift ATK/SPD x1.5 與四種 Ruin x0.75；
#          Water Bubble holder 用 Water Gun、再吃 Ember；Earth Eater holder 吃 Mud-Slap。
#  Round2：Beads of Ruin holder 用 Teleport，部署 hidden Purifying Salt reserve，驗 Storage isolation。
#  Round3：Shadow Ball 命中 Purifying Salt 驗 Ghost x0.5；Toxic 嘗試附加 Poison 被 Purifying
#          Salt 擋下；Purifying Salt holder 用 Will-O-Wisp 嘗試燒傷 Water Bubble 亦被擋下。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonAbilityBatchT"] = "2.5.19a"

module ALBERT_CG
  module ABILITY_T_V2519
    VERSION = "2.5.19a"
    TEST_LEVEL = 40
    TEST_TROOP_ID = 722
    VK_F11 = 0x7A
    FIELD_TURNS = 5

    ABILITY_FLOWER_GIFT    = 122
    ABILITY_WATER_BUBBLE   = 199
    ABILITY_PURIFYING_SALT = 272
    ABILITY_VESSEL_RUIN    = 284
    ABILITY_SWORD_RUIN     = 285
    ABILITY_TABLETS_RUIN   = 286
    ABILITY_BEADS_RUIN     = 287
    ABILITY_EARTH_EATER    = 297
    HANDLED_ABILITY_IDS = [122,199,272,284,285,286,287,297]

    FLOWER_GIFT_PERCENT = 150
    RUIN_PERCENT = 75
    WATER_BUBBLE_WATER_PERCENT = 200
    WATER_BUBBLE_FIRE_PERCENT = 50
    PURIFYING_GHOST_PERCENT = 50
    EARTH_EATER_HEAL_DENOM = 4

    TEST_ALLIES = [
      {:dex=>25, :level=>40, :ability=>ABILITY_FLOWER_GIFT,  :moves=>[92,150,150,150]},
      {:dex=>65, :level=>40, :ability=>ABILITY_WATER_BUBBLE, :moves=>[55,150,150,150]},
      {:dex=>128,:level=>40, :ability=>ABILITY_EARTH_EATER,  :moves=>[247,150,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>143,:level=>60,:ability=>ABILITY_VESSEL_RUIN,    :moves=>[52,150,150,150]},
      {:dex=>94, :level=>60,:ability=>ABILITY_SWORD_RUIN,     :moves=>[189,150,150,150]},
      {:dex=>91, :level=>60,:ability=>ABILITY_TABLETS_RUIN,   :moves=>[150,150,150,150]},
      {:dex=>109,:level=>60,:ability=>ABILITY_BEADS_RUIN,     :moves=>[100,150,150,150]},
      {:dex=>197,:level=>60,:ability=>ABILITY_PURIFYING_SALT, :moves=>[261,150,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"GLOBAL_AURA_WATER_BUBBLE_EARTH_EATER",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>55,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>52,:target=>2},
          1=>{:kind=>:move,:move_id=>189,:target=>3},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>1},
        }
      },
      {
        :name=>"PURIFYING_SALT_RESERVE_SWITCH",
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
        :name=>"PURIFYING_GHOST_AND_STATE_GUARDS",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>92,:target=>4},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>247,:target=>4},
        ],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>1},
          1=>{:kind=>:move,:move_id=>150,:target=>1},
          2=>{:kind=>:move,:move_id=>150,:target=>1},
          4=>{:kind=>:move,:move_id=>261,:target=>2},
        }
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,170,200,160, 190,180,150,140,0],
      :r2=>[10,200,190,180, 170,160,150,140,0],
      :r3=>[10,190,150,200, 140,130,120,0,180],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A2:M55","E0:M52","E1:M189","A1:M150","A3:M150","E2:M150","E3:M150"],
      2=>["A0:Guard","A1:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M100"],
      3=>["A0:Guard","A3:M247","A1:M92","E4:M261","A2:M150","E0:M150","E1:M150","E2:M150"],
    }

    begin
      KEY_API = Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API = nil
    end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.field_state; defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233.state : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party==nil ? [] : $game_party.members; end
    def self.all_enemies; $game_troop==nil ? [] : $game_troop.members; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.log_path; File.join(project_root,"Pokemon_Ability_T_AutoTest_v2_5_19a.log"); end
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
      h="CG POKEMON ABILITY T GLOBAL STAT AURA + TYPE GUARD ABSORB AUTO REGRESSION v2.5.19a\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; global stat aura + type damage + before-hit absorb + state guard lifecycle\r\n"+
        "BASELINE=v2.5.18 Ability Batch S Runtime PASS; Move pending=0\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_S_PASS=152 BATCH_T=8 PENDING=213\r\n"+
        "TEST_CONVENIENCE=skip emerged + mute battle BGM/BGS + experimental background keepalive; TEST/F11 only\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(log_path,"wb"){|f|f.write(h)}; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue
    end

    def self.type_id(sym)
      return 0 unless defined?(ALBERT_CG::POKEMON_COMBAT)
      return ALBERT_CG::POKEMON_COMBAT.type_id(sym).to_i if ALBERT_CG::POKEMON_COMBAT.respond_to?(:type_id)
      0
    rescue
      0
    end
    def self.ability_id(b); core==nil || b==nil ? 0 : core.ability_id(b).to_i; rescue; 0; end
    def self.battler_token(b); return "nil" if b==nil; (b.actor? ? "A" : "E")+b.index.to_s; rescue; "?"; end
    def self.same_side?(a,b); a!=nil && b!=nil && a.actor? == b.actor?; rescue; false; end
    def self.sun_active?; st=field_state; st!=nil && st.weather==:sun && st.weather_turns.to_i>0; rescue; false; end
    def self.fixed_damage?(ctx); ctx[:fixed_damage]==true; rescue; false; end
    def self.ratio(v,num,den); x=v.to_i; return x if x<=0; y=x*num.to_i/den.to_i; y=1 if y<1; y; end

    def self.note_local(aid,battler,kind,data=nil)
      return true unless active?
      @ability_trigger_counts[aid]=@ability_trigger_counts[aid].to_i+1
      rec={:ability=>aid,:kind=>kind}
      (data||{}).each{|k,v|rec[k]=v unless k==:battler||k==:user||k==:target||k==:skill}
      @records[aid]=[] if @records[aid]==nil; @records[aid].push(rec)
      parts=rec.keys.sort_by{|k|k.to_s}.map{|k|k.to_s+"="+rec[k].to_s}
      log("ABILITY_T_TRIGGER ability="+aid.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx={"+parts.join(",")+"}")
      true
    rescue
      false
    end

    def self.active_holders
      c=core; return [] if c==nil
      c.active_battlers
    rescue
      []
    end
    def self.first_holder(aid)
      active_holders.each{|b|return b if ability_id(b)==aid.to_i}
      nil
    rescue
      nil
    end

    def self.apply_global_ratio(aid,holder,ctx,kind,num,den)
      before=ctx[:value].to_i; return false if before<=0
      after=ratio(before,num,den); ctx[:value]=after
      note_local(aid,holder,kind,{:target=>battler_token(ctx[:target]),:stat=>ctx[:stat],:before=>before,:after=>after})
      false
    end
    def self.apply_flower_gift(holder,ctx)
      target=ctx[:target]; return false if target==nil || !same_side?(holder,target) || !sun_active?
      return false unless ctx[:stat]==:atk || ctx[:stat]==:spd
      apply_global_ratio(ABILITY_FLOWER_GIFT,holder,ctx,:flower_gift,FLOWER_GIFT_PERCENT,100)
    end
    def self.apply_vessel_ruin(holder,ctx)
      return false if ctx[:target].equal?(holder) || ctx[:stat]!=:spa
      apply_global_ratio(ABILITY_VESSEL_RUIN,holder,ctx,:vessel_of_ruin,RUIN_PERCENT,100)
    end
    def self.apply_sword_ruin(holder,ctx)
      return false if ctx[:target].equal?(holder) || ctx[:stat]!=:def
      apply_global_ratio(ABILITY_SWORD_RUIN,holder,ctx,:sword_of_ruin,RUIN_PERCENT,100)
    end
    def self.apply_tablets_ruin(holder,ctx)
      return false if ctx[:target].equal?(holder) || ctx[:stat]!=:atk
      apply_global_ratio(ABILITY_TABLETS_RUIN,holder,ctx,:tablets_of_ruin,RUIN_PERCENT,100)
    end
    def self.apply_beads_ruin(holder,ctx)
      return false if ctx[:target].equal?(holder) || ctx[:stat]!=:spd
      apply_global_ratio(ABILITY_BEADS_RUIN,holder,ctx,:beads_of_ruin,RUIN_PERCENT,100)
    end

    def self.dispatch_global_stat(target,stat,value)
      return value.to_i if core==nil || target==nil || value.to_i<=0
      ctx={:target=>target,:stat=>stat,:value=>value.to_i,:raw_value=>value.to_i}
      seen={}
      active_holders.each do |holder|
        aid=ability_id(holder)
        next unless [ABILITY_FLOWER_GIFT,ABILITY_VESSEL_RUIN,ABILITY_SWORD_RUIN,ABILITY_TABLETS_RUIN,ABILITY_BEADS_RUIN].include?(aid)
        next if seen[aid]
        seen[aid]=true
        core.dispatch(:global_stat_query,holder,ctx)
      end
      ctx[:value].to_i
    rescue
      value.to_i
    end

    def self.apply_water_bubble(battler,ctx)
      return false if fixed_damage?(ctx)
      before=ctx[:damage].to_i; return false if before<=0
      if ctx[:role]==:attacker && ctx[:type_id].to_i==type_id(:water)
        after=ratio(before,WATER_BUBBLE_WATER_PERCENT,100); ctx[:damage]=after
        note_local(ABILITY_WATER_BUBBLE,battler,:water_bubble_water,{:before=>before,:after=>after,:move_id=>ctx[:move_id].to_i,:role=>ctx[:role],:type_id=>ctx[:type_id].to_i})
        return true
      elsif ctx[:role]==:defender && ctx[:type_id].to_i==type_id(:fire)
        after=ratio(before,WATER_BUBBLE_FIRE_PERCENT,100); ctx[:damage]=after
        note_local(ABILITY_WATER_BUBBLE,battler,:water_bubble_fire_guard,{:before=>before,:after=>after,:move_id=>ctx[:move_id].to_i,:role=>ctx[:role],:type_id=>ctx[:type_id].to_i})
        return true
      end
      false
    rescue
      false
    end

    def self.apply_purifying_salt(battler,ctx)
      return false if fixed_damage?(ctx) || ctx[:role]!=:defender || ctx[:type_id].to_i!=type_id(:ghost)
      before=ctx[:damage].to_i; return false if before<=0
      after=ratio(before,PURIFYING_GHOST_PERCENT,100); ctx[:damage]=after
      note_local(ABILITY_PURIFYING_SALT,battler,:purifying_salt_ghost,{:before=>before,:after=>after,:move_id=>ctx[:move_id].to_i,:role=>ctx[:role],:type_id=>ctx[:type_id].to_i})
      true
    rescue
      false
    end

    def self.action_type_id(user,skill)
      if defined?(ALBERT_CG::ABILITY_MODIFIER_V253) && ALBERT_CG::ABILITY_MODIFIER_V253.respond_to?(:type_id_for_action)
        return ALBERT_CG::ABILITY_MODIFIER_V253.type_id_for_action(user,skill).to_i
      end
      return skill.cg_pokemon_type_id.to_i if skill!=nil && skill.respond_to?(:cg_pokemon_type_id)
      0
    rescue
      0
    end
    def self.apply_earth_eater(battler,ctx)
      return false if battler==nil || ctx==nil
      user=ctx[:user]; skill=ctx[:skill]
      return false if user==nil || skill==nil || same_side?(battler,user)
      return false unless skill.respond_to?(:base_damage) && skill.base_damage.to_i>0
      return false unless action_type_id(user,skill)==type_id(:ground)
      before=battler.hp.to_i; heal=[battler.maxhp.to_i/EARTH_EATER_HEAL_DENOM,1].max
      battler.hp=[before+heal,battler.maxhp.to_i].min; actual=battler.hp.to_i-before
      ctx[:cancel]=true; ctx[:hp_damage]=-actual
      note_local(ABILITY_EARTH_EATER,battler,:earth_eater,{:before=>before,:after=>battler.hp.to_i,:heal=>actual,:move_id=>ctx[:move_id].to_i})
      true
    rescue
      false
    end

    def self.primary_state_ids
      result=[]
      if defined?(ALBERT_CG::MOVE_EFFECT)
        result.concat(ALBERT_CG::MOVE_EFFECT::PRIMARY_STATES) if ALBERT_CG::MOVE_EFFECT.const_defined?(:PRIMARY_STATES)
        result.push(ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON) if ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON)
      end
      result.compact.map{|x|x.to_i}.uniq
    rescue
      []
    end
    def self.state_guard_for?(battler,state_id)
      aid=ability_id(battler); sid=state_id.to_i
      return true if aid==ABILITY_WATER_BUBBLE && defined?(ALBERT_CG::MOVE_EFFECT) && sid==ALBERT_CG::MOVE_EFFECT::STATE_BURN.to_i
      return true if aid==ABILITY_PURIFYING_SALT && primary_state_ids.include?(sid)
      false
    rescue
      false
    end
    def self.note_state_guard(battler,state_id,source)
      aid=ability_id(battler); return false unless aid==ABILITY_WATER_BUBBLE || aid==ABILITY_PURIFYING_SALT
      note_local(aid,battler,:state_guard,{:state_id=>state_id.to_i,:source=>source})
    end

    def self.register_handlers
      c=core; return false if c==nil
      c::TRIGGERS.push(:global_stat_query) unless c::TRIGGERS.include?(:global_stat_query)
      c.register(ABILITY_FLOWER_GIFT,:global_stat_query,self,:apply_flower_gift)
      c.register(ABILITY_VESSEL_RUIN,:global_stat_query,self,:apply_vessel_ruin)
      c.register(ABILITY_SWORD_RUIN,:global_stat_query,self,:apply_sword_ruin)
      c.register(ABILITY_TABLETS_RUIN,:global_stat_query,self,:apply_tablets_ruin)
      c.register(ABILITY_BEADS_RUIN,:global_stat_query,self,:apply_beads_ruin)
      c.register(ABILITY_WATER_BUBBLE,:damage_modify,self,:apply_water_bubble)
      c.register(ABILITY_PURIFYING_SALT,:damage_modify,self,:apply_purifying_salt)
      c.register(ABILITY_EARTH_EATER,:before_hit,self,:apply_earth_eater)
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
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability T v2.5.19a AutoRegression",ms)
    end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; elsif c[:kind]==:move; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); else; a.clear; end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; c=current_plan[:enemies][e.index]; c==nil ? nil : make_action(e,c); end
    def self.apply_test_speeds
      vals=TEST_SPEEDS[("r"+current_round.to_s).to_sym]||TEST_SPEEDS[:r1]||[]
      (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_t,vals[i]) if b}
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
    def self.set_test_sun(active)
      st=field_state; return false if st==nil
      st.weather=(active ? :sun : nil); st.weather_turns=(active ? FIELD_TURNS : 0)
      true
    rescue
      false
    end

    def self.prepare_round_preconditions
      clear_round_states; apply_test_speeds
      a=test_allies; e=all_enemies
      if current_round==1
        set_test_sun(true)
        # 正式 stat query probes：同一次 query 會依 holder 順序留下 Flower/Ruin 個別 before/after。
        a[2].cg_spa if a[2] && a[2].respond_to?(:cg_spa)
        a[2].cg_def_stat if a[2] && a[2].respond_to?(:cg_def_stat)
        a[2].cg_atk_stat if a[2] && a[2].respond_to?(:cg_atk_stat)
        a[2].cg_spd if a[2] && a[2].respond_to?(:cg_spd)
        assert_global_stat_probes_once
        if a[3]
          a[3].hp=[a[3].maxhp.to_i-60,1].max
          @r1_earth_before=a[3].hp.to_i
          @r1_earth_expected=[a[3].maxhp.to_i/EARTH_EATER_HEAL_DENOM,1].max
        end
      elsif current_round==2
        set_test_sun(false)
        @r2_storage_before=storage_size
      elsif current_round==3
        set_test_sun(false)
        @r3_purifying_poison_before=e[4] ? e[4].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON) : false
        @r3_water_burn_before=a[2] ? a[2].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN) : false
      end
    end
    def self.prepare_round_actions
      p=current_plan; return false if p==nil; prepare_round_preconditions; @actual=[]; log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s)
      test_allies.each_with_index do |b,i|; next if b==nil||b.hp.to_i<=0; ac=make_action(b,p[:allies][i]); if b.respond_to?(:cg_round_actions); b.cg_round_actions.clear; b.cg_round_actions.push(ac); end; b.cg_assign_action(ac) if b.respond_to?(:cg_assign_action); b.instance_variable_set(:@action,ac) unless b.respond_to?(:cg_assign_action); end; true
    end
    def self.record_execution(b)
      return unless active?&&b; a=b.action; pre=b.actor? ? "A" : "E"; tok=if a&&a.guard?; pre+b.index.to_s+":Guard" elsif a&&a.skill?; pre+b.index.to_s+":M"+ALBERT_CG::MOVE_EFFECT.move_id(a.skill).to_i.to_s else; pre+b.index.to_s+":Other" end; @actual.push(tok); log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    rescue
    end

    def self.records_for(aid,kind=nil)
      a=@records[aid]||[]; a.select{|r|kind==nil||r[:kind]==kind}
    end
    def self.record_ratio_ok?(aid,kind,num,den)
      records_for(aid,kind).any?{|r|r[:before].to_i>0 && r[:after].to_i==ratio(r[:before],num,den)}
    end

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      tid=($game_troop&&$game_troop.troop) ? $game_troop.troop.id.to_i : 0; ids=core ? core.registered_ability_ids : []
      assert_true("Ability Catalog count=373",core&&core.catalog_count==373,"actual="+(core ? core.catalog_count.to_s : "nil"))
      assert_true("Ability Batch T registers 8 IDs",HANDLED_ABILITY_IDS.all?{|id|ids.include?(id)},"registered="+HANDLED_ABILITY_IDS.select{|id|ids.include?(id)}.size.to_s)
      assert_true("Scene_Battle uses Ability T test troop",tid==TEST_TROOP_ID,"actual="+tid.to_s)
      assert_true("Ability T ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability T starts with 4 active enemies",all_enemies[0,4].all?{|b|b&&!b.hidden},"")
      assert_true("Ability T starts with 1 hidden Purifying Salt reserve",all_enemies[4]&&all_enemies[4].hidden,"E4_hidden="+(all_enemies[4] ? all_enemies[4].hidden.to_s : "nil"))
    end

    def self.assert_global_stat_probes_once
      return if @global_stat_asserted
      @global_stat_asserted=true
      fg_atk=records_for(ABILITY_FLOWER_GIFT,:flower_gift).any?{|r|r[:stat]==:atk && r[:before].to_i>0 && r[:after].to_i==ratio(r[:before],FLOWER_GIFT_PERCENT,100)}
      fg_spd=records_for(ABILITY_FLOWER_GIFT,:flower_gift).any?{|r|r[:stat]==:spd && r[:before].to_i>0 && r[:after].to_i==ratio(r[:before],FLOWER_GIFT_PERCENT,100)}
      @global_stat_checks+=1 if fg_atk; assert_true("Flower Gift raises ally ATK x1.50 in Sun",fg_atk,(records_for(ABILITY_FLOWER_GIFT,:flower_gift).select{|r|r[:stat]==:atk}[-1]||{}).inspect)
      @global_stat_checks+=1 if fg_spd; assert_true("Flower Gift raises ally SPD x1.50 in Sun",fg_spd,(records_for(ABILITY_FLOWER_GIFT,:flower_gift).select{|r|r[:stat]==:spd}[-1]||{}).inspect)
      [[ABILITY_VESSEL_RUIN,:vessel_of_ruin,"Vessel of Ruin lowers other SPA x0.75"],
       [ABILITY_SWORD_RUIN,:sword_of_ruin,"Sword of Ruin lowers other DEF x0.75"],
       [ABILITY_TABLETS_RUIN,:tablets_of_ruin,"Tablets of Ruin lowers other ATK x0.75"],
       [ABILITY_BEADS_RUIN,:beads_of_ruin,"Beads of Ruin lowers other SPD x0.75"]].each do |row|
        ok=record_ratio_ok?(row[0],row[1],RUIN_PERCENT,100)
        @global_stat_checks+=1 if ok
        assert_true(row[2],ok,(records_for(row[0],row[1])[-1]||{}).inspect)
      end
    end

    def self.assert_round
      r=current_round; p=current_plan; a=test_allies; e=all_enemies
      exp=EXPECTED_EXECUTION_TOKENS[r]||[]; order=@actual==exp
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",order,"expected="+exp.inspect+" actual="+@actual.inspect)
      if r==1
        wbw=record_ratio_ok?(ABILITY_WATER_BUBBLE,:water_bubble_water,WATER_BUBBLE_WATER_PERCENT,100)
        @damage_checks+=1 if wbw; assert_true("Water Bubble doubles Water damage x2",wbw,(records_for(ABILITY_WATER_BUBBLE,:water_bubble_water)[-1]||{}).inspect)
        wbf=record_ratio_ok?(ABILITY_WATER_BUBBLE,:water_bubble_fire_guard,WATER_BUBBLE_FIRE_PERCENT,100)
        @damage_checks+=1 if wbf; assert_true("Water Bubble halves incoming Fire damage x0.50",wbf,(records_for(ABILITY_WATER_BUBBLE,:water_bubble_fire_guard)[-1]||{}).inspect)
        expected=[@r1_earth_before.to_i+@r1_earth_expected.to_i,a[3].maxhp.to_i].min
        er=a[3]&&a[3].hp.to_i==expected&&!records_for(ABILITY_EARTH_EATER,:earth_eater).empty?
        @absorb_checks+=1 if er; assert_true("Earth Eater cancels Ground damage and heals 1/4 MaxHP",er,"hp="+@r1_earth_before.to_s+"->"+(a[3] ? a[3].hp.to_i.to_s : "nil")+" expected="+expected.to_s+" record="+(records_for(ABILITY_EARTH_EATER,:earth_eater)[-1]||{}).inspect)
      elsif r==2
        sw=e[3]&&e[4]&&e[3].hidden&&!e[4].hidden; @lifecycle_checks+=1 if sw; assert_true("Teleport deploys hidden Purifying Salt reserve",sw,"E3_hidden="+(e[3] ? e[3].hidden.to_s : "nil")+" E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil"))
        sa=storage_size; stor=sa==@r2_storage_before.to_i; @lifecycle_checks+=1 if stor; assert_true("Purifying Salt reserve switch does not consume Storage Pokemon",stor,"before="+@r2_storage_before.to_s+" after="+sa.to_s)
      elsif r==3
        pg=record_ratio_ok?(ABILITY_PURIFYING_SALT,:purifying_salt_ghost,PURIFYING_GHOST_PERCENT,100)
        @damage_checks+=1 if pg; assert_true("Purifying Salt halves incoming Ghost damage x0.50",pg,(records_for(ABILITY_PURIFYING_SALT,:purifying_salt_ghost)[-1]||{}).inspect)
        bad_sid=(ALBERT_CG::MOVE_EFFECT.const_defined?(:STATE_BAD_POISON) ? ALBERT_CG::MOVE_EFFECT::STATE_BAD_POISON : 0)
        poison_now=e[4] ? e[4].state?(ALBERT_CG::MOVE_EFFECT::STATE_POISON) : false
        bad_now=e[4] && bad_sid.to_i>0 ? e[4].state?(bad_sid) : false
        poison_ok=e[4]&&!poison_now&&!bad_now
        @state_checks+=1 if poison_ok; assert_true("Purifying Salt blocks Toxic poison/bad-poison state",poison_ok,"poison="+poison_now.to_s+" bad_poison="+bad_now.to_s)
        burn_ok=a[2]&&!a[2].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN)
        @state_checks+=1 if burn_ok; assert_true("Water Bubble blocks Will-O-Wisp burn state",burn_ok,"burn="+(a[2] ? a[2].state?(ALBERT_CG::MOVE_EFFECT::STATE_BURN).to_s : "nil"))
        stable=e[4]&&!e[4].hidden&&e[4].hp.to_i>0; assert_true("Purifying Salt reserve remains active through Round3",stable,"E4_hidden="+(e[4] ? e[4].hidden.to_s : "nil")+" hp="+(e[4] ? e[4].hp.to_i.to_s : "nil"))
      end
      log("ROUND "+r.to_s+" END")
    end
    def self.finish_round_assertions; return unless active?; assert_round; @round_index+=1; end
    def self.ability_covered_count; HANDLED_ABILITY_IDS.inject(0){|n,id|n+(@ability_trigger_counts[id].to_i>0 ? 1 : 0)}; end
    def self.cleanup_test_overrides; (test_allies+all_enemies).each{|b|b.instance_variable_set(:@cg_priority_test_speed_override_t,nil) if b}; end
    def self.finish_suite
      HANDLED_ABILITY_IDS.each{|id|assert_true("Ability "+id.to_s+" triggered count>0",@ability_trigger_counts[id].to_i>0,"count="+@ability_trigger_counts[id].to_i.to_s)}
      result=@failures.empty? ? "PASS" : "FAIL"; log("------------------------------------------------------------"); log("RESULT="+result)
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_t="+ability_covered_count.to_s+"/8 global_stat_checks="+@global_stat_checks.to_i.to_s+" damage_checks="+@damage_checks.to_i.to_s+" absorb_checks="+@absorb_checks.to_i.to_s+" state_checks="+@state_checks.to_i.to_s+" lifecycle_checks="+@lifecycle_checks.to_i.to_s+" pending=213")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}; cleanup_test_overrides; @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @global_stat_checks=0; @damage_checks=0; @absorb_checks=0; @state_checks=0; @lifecycle_checks=0; @r1_earth_before=0; @r1_earth_expected=0; @r2_storage_before=0; @global_stat_asserted=false
    end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; ALBERT_CG::UNIQUE_I_V242.install_skill_scopes if defined?(ALBERT_CG::UNIQUE_I_V242)&&ALBERT_CG::UNIQUE_I_V242.respond_to?(:install_skill_scopes); @active=true; ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_T_v2.5.19a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session); log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil; @failures.push("AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s); log(@failures[-1]); @active=false; ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session); false
    end
  end
end

ALBERT_CG::ABILITY_T_V2519.register_handlers if defined?(ALBERT_CG::ABILITY_V250)
if defined?(ALBERT_CG::ABILITY_S_V2518)
  module ALBERT_CG; module ABILITY_S_V2518; def self.f11_trigger?; false; end; end; end
end

#==============================================================================
# ■ Formal Global Stat Aura bridge
#==============================================================================
class Game_Battler
  alias cg_v2519t_global_atk_stat cg_atk_stat
  def cg_atk_stat
    v=cg_v2519t_global_atk_stat
    return defined?(ALBERT_CG::ABILITY_T_V2519) ? ALBERT_CG::ABILITY_T_V2519.dispatch_global_stat(self,:atk,v) : v
  end
  alias cg_v2519t_global_def_stat cg_def_stat
  def cg_def_stat
    v=cg_v2519t_global_def_stat
    return defined?(ALBERT_CG::ABILITY_T_V2519) ? ALBERT_CG::ABILITY_T_V2519.dispatch_global_stat(self,:def,v) : v
  end
  alias cg_v2519t_global_spa cg_spa
  def cg_spa
    v=cg_v2519t_global_spa
    return defined?(ALBERT_CG::ABILITY_T_V2519) ? ALBERT_CG::ABILITY_T_V2519.dispatch_global_stat(self,:spa,v) : v
  end
  alias cg_v2519t_global_spd cg_spd
  def cg_spd
    v=cg_v2519t_global_spd
    return defined?(ALBERT_CG::ABILITY_T_V2519) ? ALBERT_CG::ABILITY_T_V2519.dispatch_global_stat(self,:spd,v) : v
  end
end

#==============================================================================
# ■ Formal State Guard extension: Water Bubble / Purifying Salt
#==============================================================================
if defined?(ALBERT_CG::ABILITY_GUARD_V251)
  module ALBERT_CG
    module ABILITY_GUARD_V251
      class << self
        alias cg_v2519t_guard_state guard_state?
        def guard_state?(battler,state_id)
          return true if defined?(ALBERT_CG::ABILITY_T_V2519) && ALBERT_CG::ABILITY_T_V2519.state_guard_for?(battler,state_id)
          cg_v2519t_guard_state(battler,state_id)
        end
        alias cg_v2519t_block_state block_state
        def block_state(battler,state_id,source=:unknown)
          result=cg_v2519t_block_state(battler,state_id,source)
          if result && defined?(ALBERT_CG::ABILITY_T_V2519) && ALBERT_CG::ABILITY_T_V2519.state_guard_for?(battler,state_id)
            ALBERT_CG::ABILITY_T_V2519.note_state_guard(battler,state_id,source)
          end
          result
        end
      end
    end
  end
end

#==============================================================================
# ■ TEST-only deterministic Scene_Battle harness
#==============================================================================
class Game_Battler
  alias cg_v2519t_ability_calc_hit calc_hit
  def calc_hit(user,obj=nil); return 100 if defined?(ALBERT_CG::ABILITY_T_V2519)&&ALBERT_CG::ABILITY_T_V2519.active?; cg_v2519t_ability_calc_hit(user,obj); end
  alias cg_v2519t_ability_calc_eva calc_eva
  def calc_eva(user,obj=nil); return 0 if defined?(ALBERT_CG::ABILITY_T_V2519)&&ALBERT_CG::ABILITY_T_V2519.active?; cg_v2519t_ability_calc_eva(user,obj); end
  alias cg_v2519t_ability_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_T_V2519)&&ALBERT_CG::ABILITY_T_V2519.active?
      v=@cg_priority_test_speed_override_t; return v.to_i if v!=nil
    end
    cg_v2519t_ability_priority_base_speed
  rescue
    cg_v2519t_ability_priority_base_speed
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2519t_ability_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_T_V2519)&&ALBERT_CG::ABILITY_T_V2519.active?
      a=ALBERT_CG::ABILITY_T_V2519.forced_enemy_action(self)
      if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end
    end
    cg_v2519t_ability_enemy_make_action
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2519t_ability_execute_action execute_action
  def execute_action
    b=@active_battler; ALBERT_CG::ABILITY_T_V2519.record_execution(b) if defined?(ALBERT_CG::ABILITY_T_V2519)&&ALBERT_CG::ABILITY_T_V2519.active?; cg_v2519t_ability_execute_action
  end
  alias cg_v2519t_ability_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_T_V2519)&&ALBERT_CG::ABILITY_T_V2519.active?
      if defined?(ALBERT_CG::ABILITY_V250); ALBERT_CG::ABILITY_V250.trigger_end_turn; ALBERT_CG::ABILITY_T_V2519.finish_round_assertions; ALBERT_CG::ABILITY_V250.suppress_next_end_turn!; else; ALBERT_CG::ABILITY_T_V2519.finish_round_assertions; end
    end
    cg_v2519t_ability_turn_end
  end
  alias cg_v2519t_ability_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_T_V2519)&&ALBERT_CG::ABILITY_T_V2519.active?; return cg_v2519t_ability_start_party_command; end
    cg_v2519t_ability_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_T_V2519.assert_bootstrap_once
    if ALBERT_CG::ABILITY_T_V2519.finished?; ALBERT_CG::ABILITY_T_V2519.finish_suite; battle_end(0); return; end
    ALBERT_CG::ABILITY_T_V2519.prepare_round_actions; start_main
  end
end

module ALBERT_CG
  class << self
    alias cg_v2519t_ability_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2519t_ability_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_T_V2519)&&ALBERT_CG::ABILITY_T_V2519.active?
        ALBERT_CG::ABILITY_T_V2519::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_T_V2519.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_T_V2519::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); h.instance_variable_set(:@cg_master_ability_id,0); end
      end
      r
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v2519t_ability_scene_map_update update
  def update; cg_v2519t_ability_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_T_V2519); ALBERT_CG::ABILITY_T_V2519.start_auto_test if ALBERT_CG::ABILITY_T_V2519.f11_trigger?; end
end
