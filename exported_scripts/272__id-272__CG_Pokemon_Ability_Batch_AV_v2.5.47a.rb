# RMVX_SCRIPT_INDEX: 272
# RMVX_SCRIPT_ID: 272
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AV v2.5.47a
# RMVX_SOURCE_SHA256: 69a5019c514ee72483d368c31361db0b9a0febe553504719b9b4b36e0dbeb83a

#==============================================================================
# ■ CG Pokemon Ability Batch AV v2.5.47a - Commander + Share FINAL TEST
#------------------------------------------------------------------------------
# 【正式基底】
#  v2.5.46 Batch AU RPG Maker VX real-machine PASS = 371/373。
#  Scripts 0..271 sealed byte-exact，本頁只新增 index272。
#
# 【本批 Ability】
#   279 Commander / 發號施令
# 10047 Share / 共感
#
# 【Commander Adapter Authority】
#  - 本作正式 Species Authority 目前只有 National Dex 1..494，沒有 Dondozo(977) / Tatsugiri(978)。
#  - 不偽造 977/978 資料；改提供 commander_receiver role API。
#  - Ability 279 holder 與同側 active receiver 同場時：holder 進入 hidden inside 狀態，receiver
#    ATK/DEF/SPA/SPD/SPE 各 +2 stage；receiver 在 link 存續期間不可 Teleport / Force Switch。
#  - receiver 倒下或離場後，holder 解除 hidden 並回到戰場。
#  - 未來若 Species Authority 擴張到 Dex977，會自動視為 receiver；亦可由外部資料層呼叫
#    set_commander_receiver_role(battler,true) 或提供 cg_commander_receiver_role?。
#
# 【Share Adapter Authority】
#  - 本作目前沒有 Pokemon Conquest Warrior Skill 子系統，因此不捏造 Warrior Skill 效果。
#  - 提供 warrior_skill_targets(source, skill_key, base_targets) 正式 target-sharing API：
#    同側 active Share holder 會加入可分享 Warrior Skill 的 target list，無視 Grid 距離。
#  - Ambition / Desire / Motivate / Willpower 明確排除，不會被 Share 擴張目標。
#  - 外部未來 Warrior Skill 系統只需先呼叫此 API，再對回傳 targets 套用自己的正式效果。
#
# 【v2.5.47a Regression correction】
#  - v2.5.47 real-machine proved Share Runtime targets=[2,3] and Rally ATK 0->1.
#  - 唯一 FAIL 是 Regression 讀取不存在的 cg_battle_slot getter；正式 Grid API 為
#    cg_battle_slot_assigned? + cg_battle_row + cg_battle_column。47a 僅修測試讀法。
#
# 【F11 Regression】
#  3-round real Scene_Battle：Commander link/+2x5、switch lock、receiver KO release；
#  Share Rally target expansion + excluded Ambition。若 PASS => Ability 373/373，pending 0。
#==============================================================================
$imported={} if $imported==nil
$imported["ALBERT_CG_PokemonAbilityBatchAV"]="2.5.47a"

module ALBERT_CG
  module ABILITY_AV_V2547
    VERSION="2.5.47a"
    TEST_LEVEL=40
    TEST_TROOP_ID=750
    VK_F11=0x7A
    ABILITY_COMMANDER=279
    ABILITY_SHARE=10047
    HANDLED_ABILITY_IDS=[ABILITY_COMMANDER,ABILITY_SHARE]
    COMMANDER_RECEIVER_DEX=977
    COMMANDER_STATS=[:atk,:def,:spa,:spd,:spe]
    SHARE_EXCLUDED_SKILLS=[:ambition,:desire,:motivate,:willpower]
    MOVE_SPLASH=150
    PRIMARY_PENDING=0

    # Test-only species are all inside the sealed 1..494 Species Authority.
    # A1 Abra is only a Commander holder fixture; A2 Snorlax receives an explicit receiver role;
    # A3 Espeon is a Share holder fixture. No species identity is rewritten.
    TEST_ALLIES=[
      {:dex=>63, :level=>40,:ability=>ABILITY_COMMANDER,:moves=>[150]},
      {:dex=>143,:level=>40,:ability=>0,                :moves=>[150]},
      {:dex=>196,:level=>40,:ability=>ABILITY_SHARE,    :moves=>[150]}
    ]
    TEST_ENEMIES=[
      {:dex=>25,:level=>45,:ability=>0,:moves=>[150]},
      {:dex=>53,:level=>45,:ability=>0,:moves=>[150]},
      {:dex=>67,:level=>45,:ability=>0,:moves=>[150]},
      {:dex=>65,:level=>45,:ability=>0,:moves=>[150]},
      {:dex=>66,:level=>45,:ability=>0,:moves=>[150]}
    ]

    ROUND_PLANS=[
      {:name=>"COMMANDER_LINK_SHARE_RALLY",
       :allies=>{0=>{:move_id=>150,:target=>0},2=>{:move_id=>150,:target=>0},3=>{:move_id=>150,:target=>0}}},
      {:name=>"COMMANDER_SWITCH_LOCK_SHARE_EXCLUSION",
       :allies=>{0=>{:move_id=>150,:target=>0},2=>{:move_id=>150,:target=>0},3=>{:move_id=>150,:target=>0}}},
      {:name=>"COMMANDER_RECEIVER_KO_RELEASE",
       :allies=>{0=>{:move_id=>150,:target=>0},1=>{:move_id=>150,:target=>0},3=>{:move_id=>150,:target=>0}}}
    ]
    TEST_SPEEDS={
      1=>[1000,950,900,850,700,650,600,550,500],
      2=>[1000,950,900,850,700,650,600,550,500],
      3=>[1000,950,900,850,700,650,600,550,500]
    }
    EXPECTED_ORDERS={
      1=>["A0:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150","E4:M150"],
      2=>["A0:M150","A2:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150","E4:M150"],
      3=>["A0:M150","A1:M150","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150","E4:M150"]
    }

    begin
      KEY_API=Win32API.new("user32","GetAsyncKeyState","i","i")
    rescue
      KEY_API=nil
    end

    def self.core
      defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil
    end
    def self.master
      defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil
    end
    def self.active?
      @active==true
    end
    def self.current_round
      @round_index.to_i+1
    end
    def self.current_plan
      ROUND_PLANS[@round_index.to_i]
    end
    def self.finished?
      @round_index.to_i>=ROUND_PLANS.size
    end
    def self.test_allies
      $game_party ? $game_party.members : []
    end
    def self.all_enemies
      $game_troop ? $game_troop.members : []
    end
    def self.project_root
      Dir.pwd
    rescue
      "."
    end
    def self.latest_log_path
      File.join(project_root,"CG_AutoRegression_LATEST.log")
    end
    def self.log(text)
      File.open(latest_log_path,"ab") { |f| f.write(text.to_s+"\r\n") }
    rescue
    end
    def self.key_down?(code)
      KEY_API&&(KEY_API.call(code)&0x8000)!=0
    rescue
      false
    end
    def self.f11_trigger?
      down=key_down?(VK_F11)
      trig=down&&@f11_down!=true
      @f11_down=down
      trig
    rescue
      false
    end
    def self.ability_id(battler)
      core&&battler ? core.ability_id(battler).to_i : 0
    rescue
      0
    end
    def self.same_side?(a,b)
      a&&b&&(a.actor? == b.actor?)
    rescue
      false
    end
    def self.move_id(skill)
      defined?(ALBERT_CG::MOVE_EFFECT)&&skill ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0
    rescue
      0
    end
    def self.set_ability(battler,aid)
      return unless battler
      battler.instance_variable_set(:@cg_v237_ability_override,nil)
      battler.instance_variable_set(:@cg_v237_ability_suppressed,false)
      battler.instance_variable_set(:@cg_master_ability_id,aid.to_i)
    end
    def self.assert_true(label,cond,detail=nil)
      if cond
        log("ASSERT PASS "+label.to_s+(detail ? " "+detail.to_s : ""))
      else
        text=label.to_s+(detail ? " "+detail.to_s : "")
        @failures<<text
        log("ASSERT FAIL "+text)
      end
      cond
    end
    def self.note_local(aid,battler,kind,data=nil)
      rec={:ability=>aid.to_i,:kind=>kind}
      (data||{}).each do |k,v|
        rec[k]=v unless [:battler,:user,:target,:skill,:action].include?(k)
      end
      if active?
        @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1
        (@records[aid.to_i]||=[])<<rec
        log("ABILITY_AV_TRIGGER ability="+aid.to_s+" battler="+(battler ? battler.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect)
      end
      rec
    rescue
      nil
    end
    def self.formal_note(aid,battler,kind,data=nil)
      ctx=data||{}
      if core
        core.note_trigger(kind,battler,aid,ctx) if core.respond_to?(:note_trigger)
        core.present_trigger(battler,aid,kind,ctx) if core.respond_to?(:present_trigger)
      end
      note_local(aid,battler,kind,ctx)
      true
    rescue
      false
    end
    def self.records_for(aid,kind=nil)
      ary=@records[aid.to_i]||[]
      return ary if kind==nil
      ary.select { |x| x[:kind].to_sym==kind.to_sym }
    rescue
      []
    end

    #--------------------------------------------------------------------------
    # Commander Adapter Authority
    #--------------------------------------------------------------------------
    def self.set_commander_receiver_role(battler,value=true)
      return false unless battler
      battler.instance_variable_set(:@cg_av_commander_receiver_role,value==true)
      true
    rescue
      false
    end
    def self.commander_receiver?(battler)
      return false unless battler
      if battler.respond_to?(:cg_commander_receiver_role?)
        begin
          return true if battler.cg_commander_receiver_role? == true
        rescue
        end
      end
      return true if battler.instance_variable_get(:@cg_av_commander_receiver_role)==true
      if battler.respond_to?(:cg_national_dex)
        return true if battler.cg_national_dex.to_i==COMMANDER_RECEIVER_DEX
      end
      false
    rescue
      false
    end
    def self.side_members(battler,include_hidden=false)
      return [] unless battler
      unit=battler.actor? ? $game_party : $game_troop
      return [] unless unit
      result=[]
      for b in unit.members
        next if b==nil||b.hp.to_i<=0
        next if !include_hidden&&b.hidden
        result<<b
      end
      result
    rescue
      []
    end
    def self.find_commander_receiver(holder)
      return nil unless holder
      for b in side_members(holder,false)
        next if b==holder
        next unless commander_receiver?(b)
        occupied=b.instance_variable_get(:@cg_av_commander_holder)
        next if occupied!=nil&&occupied!=holder
        return b
      end
      nil
    rescue
      nil
    end
    def self.commander_inside?(holder)
      holder&&holder.instance_variable_get(:@cg_av_commander_inside)==true
    rescue
      false
    end
    def self.commander_partner(holder)
      holder ? holder.instance_variable_get(:@cg_av_commander_partner) : nil
    rescue
      nil
    end
    def self.commander_partner_locked?(partner)
      return false unless partner&&partner.hp.to_i>0
      holder=partner.instance_variable_get(:@cg_av_commander_holder)
      return false unless holder
      commander_inside?(holder)&&commander_partner(holder)==partner
    rescue
      false
    end
    def self.establish_commander_link(holder,partner,via_dispatch=false,ctx=nil)
      return false unless holder&&partner
      return false unless ability_id(holder)==ABILITY_COMMANDER
      return false if holder.hidden||holder.hp.to_i<=0||partner.hidden||partner.hp.to_i<=0
      return false unless same_side?(holder,partner)&&commander_receiver?(partner)
      return false if commander_inside?(holder)
      changes={}
      for stat in COMMANDER_STATS
        before=partner.respond_to?(:cg_stat_stage) ? partner.cg_stat_stage(stat).to_i : 0
        partner.cg_change_stat_stage(stat,2) if partner.respond_to?(:cg_change_stat_stage)
        after=partner.respond_to?(:cg_stat_stage) ? partner.cg_stat_stage(stat).to_i : before
        changes[stat]=[before,after]
      end
      holder.instance_variable_set(:@cg_av_commander_partner,partner)
      holder.instance_variable_set(:@cg_av_commander_inside,true)
      partner.instance_variable_set(:@cg_av_commander_holder,holder)
      holder.action.clear if holder.respond_to?(:action)&&holder.action
      holder.cg_round_actions.clear if holder.respond_to?(:cg_round_actions)
      holder.hidden=true if holder.respond_to?(:hidden=)
      data={:partner_index=>(partner.respond_to?(:index) ? partner.index.to_i : -1),:boosts=>changes,:inside=>true}
      if ctx
        data.each { |k,v| ctx[k]=v }
      end
      if via_dispatch
        note_local(ABILITY_COMMANDER,holder,:commander_link,data)
      else
        formal_note(ABILITY_COMMANDER,holder,:commander_link,data)
      end
      true
    rescue=>e
      log("COMMANDER_LINK_ERROR "+e.class.to_s+":"+e.message.to_s) if active?
      false
    end
    def self.commander_entry(holder,ctx)
      return false unless holder&&ability_id(holder)==ABILITY_COMMANDER
      partner=find_commander_receiver(holder)
      return false unless partner
      establish_commander_link(holder,partner,true,ctx)
    end
    def self.release_commander(holder,reason=:receiver_gone)
      return false unless holder&&commander_inside?(holder)
      partner=commander_partner(holder)
      partner.instance_variable_set(:@cg_av_commander_holder,nil) if partner
      holder.instance_variable_set(:@cg_av_commander_partner,nil)
      holder.instance_variable_set(:@cg_av_commander_inside,false)
      if holder.hp.to_i>0
        holder.hidden=false if holder.respond_to?(:hidden=)
        holder.reset_coordinate if holder.respond_to?(:reset_coordinate)
      end
      formal_note(ABILITY_COMMANDER,holder,:commander_release,{:reason=>reason,:partner_index=>(partner&&partner.respond_to?(:index) ? partner.index.to_i : -1),:inside=>false})
      true
    rescue=>e
      log("COMMANDER_RELEASE_ERROR "+e.class.to_s+":"+e.message.to_s) if active?
      false
    end
    def self.refresh_commander_links(reason=:refresh)
      all=[]
      all += $game_party.members if $game_party
      all += $game_troop.members if $game_troop
      # First release invalid links. The holder may be hidden, so do not use active_battlers.
      for holder in all
        next unless holder&&commander_inside?(holder)
        partner=commander_partner(holder)
        if partner==nil||partner.hp.to_i<=0||partner.hidden
          release_commander(holder,reason)
        end
      end
      # Then allow an unlinked active Commander holder to pair with a receiver that entered later.
      for holder in all
        next unless holder&&holder.hp.to_i>0&&!holder.hidden
        next unless ability_id(holder)==ABILITY_COMMANDER
        next if commander_inside?(holder)
        partner=find_commander_receiver(holder)
        establish_commander_link(holder,partner,false,{:reason=>reason}) if partner
      end
      true
    rescue=>e
      log("COMMANDER_REFRESH_ERROR "+e.class.to_s+":"+e.message.to_s) if active?
      false
    end

    #--------------------------------------------------------------------------
    # Share Adapter Authority
    #--------------------------------------------------------------------------
    def self.share_excluded_skill?(skill_key)
      key=skill_key.to_s.downcase.to_sym
      SHARE_EXCLUDED_SKILLS.include?(key)
    rescue
      false
    end
    def self.warrior_skill_targets(source,skill_key,base_targets)
      result=[]
      for b in (base_targets||[])
        result<<b if b&& !result.include?(b)
      end
      return result if source==nil||share_excluded_skill?(skill_key)
      unit=source.actor? ? $game_party : $game_troop
      return result unless unit
      for holder in unit.members
        next if holder==nil||holder==source||holder.hidden||holder.hp.to_i<=0
        next unless ability_id(holder)==ABILITY_SHARE
        next if result.include?(holder)
        result<<holder
        formal_note(ABILITY_SHARE,holder,:share_warrior_skill,{:source_index=>(source.respond_to?(:index) ? source.index.to_i : -1),:skill=>skill_key.to_s.downcase.to_sym,:holder_index=>(holder.respond_to?(:index) ? holder.index.to_i : -1),:wherever=>true})
      end
      result
    rescue=>e
      log("SHARE_TARGET_ERROR "+e.class.to_s+":"+e.message.to_s) if active?
      base_targets||[]
    end

    def self.register_handlers
      return false unless core
      core.register(ABILITY_COMMANDER,:battle_start,self,:commander_entry)
      core.register(ABILITY_COMMANDER,:entry,self,:commander_entry)
      true
    rescue
      false
    end

    #--------------------------------------------------------------------------
    # Harness helpers
    #--------------------------------------------------------------------------
    def self.clear_runtime(battler)
      return unless battler
      if commander_inside?(battler)
        partner=commander_partner(battler)
        partner.instance_variable_set(:@cg_av_commander_holder,nil) if partner
        battler.hidden=false if battler.respond_to?(:hidden=)&&battler.hp.to_i>0
      end
      battler.instance_variable_set(:@cg_av_commander_partner,nil)
      battler.instance_variable_set(:@cg_av_commander_inside,false)
      battler.instance_variable_set(:@cg_av_commander_holder,nil)
      battler.instance_variable_set(:@cg_av_commander_receiver_role,false)
      battler.instance_variable_set(:@cg_priority_test_speed_override_av,nil)
    rescue
    end
    def self.configure_actor(cfg)
      a=$game_actors[master.actor_id_for_dex(cfg[:dex])]
      return unless a
      master.configure_actor(a,cfg)
      a.recover_all if a.respond_to?(:recover_all)
      a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages)
      clear_runtime(a)
      set_ability(a,cfg[:ability])
    end
    def self.configure_enemy(cfg)
      master.configure_enemy_data(cfg)
    end
    def self.set_actor_moves(battler,mids)
      return unless battler&&battler.actor?
      sids=mids.collect { |m| master.skill_id_for_move(m.to_i) }.select { |x| x.to_i>0 }
      battler.instance_variable_set(:@cg_equipped_skill_ids,sids)
      battler.instance_variable_set(:@cg_skill_slot_ids,sids)
      battler.instance_variable_set(:@skills,sids)
    end
    def self.prepare_test_party
      ids=TEST_ALLIES.collect { |c| master.actor_id_for_dex(c[:dex]) }
      ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      for cfg in TEST_ALLIES
        configure_actor(cfg)
      end
      human=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if human
        human.change_level(TEST_LEVEL,false)
        human.recover_all
        human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
        clear_runtime(human)
        set_ability(human,0)
        set_actor_moves(human,[150])
      end
      a=test_allies
      set_commander_receiver_role(a[2],true) if a[2]
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_BACK_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[2]]
      members=[]
      TEST_ENEMIES.each_with_index do |cfg,i|
        configure_enemy(cfg)
        m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]),xs[i],ys[i])
        m.hidden=false
        members<<m
      end
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AV v2.5.47a AutoRegression",members)
    end
    def self.pre_scene_start
      a=test_allies
      e=all_enemies
      for b in (a+e)
        clear_runtime(b)
        b.hidden=false if b&&b.respond_to?(:hidden=)&&b.hp.to_i>0
      end
      set_ability(a[0],0) if a[0]
      set_ability(a[1],ABILITY_COMMANDER) if a[1]
      set_ability(a[2],0) if a[2]
      set_ability(a[3],ABILITY_SHARE) if a[3]
      set_commander_receiver_role(a[2],true) if a[2]
      for b in e
        set_ability(b,0) if b
      end
    end
    def self.make_action(battler,cfg)
      action=Game_BattleAction.new(battler)
      action.set_skill(master.skill_id_for_move(cfg[:move_id].to_i))
      action.target_index=cfg[:target].to_i if cfg.has_key?(:target)
      action
    end
    def self.forced_enemy_action(enemy)
      return nil unless active?&&enemy&&!enemy.hidden&&enemy.hp.to_i>0
      make_action(enemy,{:move_id=>150,:target=>0})
    rescue
      nil
    end
    def self.action_token(battler)
      return "nil" unless battler
      side=battler.actor? ? "A" : "E"
      action=battler.action
      return side+battler.index.to_s+":M"+move_id(action.skill).to_s if action&&action.skill?
      side+battler.index.to_s+":Other"
    rescue
      "?"
    end
    def self.record_execution(battler)
      return unless active?&&battler&&battler.hp.to_i>0&&!battler.hidden
      @actual<<action_token(battler)
      log("ACTION_EXEC #"+@actual.size.to_s+" "+battler.name.to_s+" token="+@actual[-1].to_s)
    end
    def self.apply_test_speeds
      speeds=TEST_SPEEDS[current_round]||[]
      (test_allies+all_enemies).each_with_index do |b,i|
        b.instance_variable_set(:@cg_priority_test_speed_override_av,speeds[i]) if b&&speeds[i]!=nil
      end
    end
    def self.apply_round_slots
      a=test_allies
      e=all_enemies
      a[0].cg_set_battle_slot(:front,0,true) if a[0]
      a[1].cg_set_battle_slot(:front,1,true) if a[1]
      a[2].cg_set_battle_slot(:front,2,true) if a[2]
      a[3].cg_set_battle_slot(:back,2,true) if a[3]
      e[0].cg_set_battle_slot(:front,0,true) if e[0]
      e[1].cg_set_battle_slot(:front,1,true) if e[1]
      e[2].cg_set_battle_slot(:front,2,true) if e[2]
      e[3].cg_set_battle_slot(:back,0,true) if e[3]
      e[4].cg_set_battle_slot(:back,2,true) if e[4]
    end
    def self.apply_rally_fixture(source,receiver,share_holder)
      @r1_receiver_atk_before=receiver.cg_stat_stage(:atk).to_i
      @r1_share_atk_before=share_holder.cg_stat_stage(:atk).to_i
      @r1_share_targets=warrior_skill_targets(source,:rally,[receiver])
      for b in @r1_share_targets
        b.cg_change_stat_stage(:atk,1) if b.respond_to?(:cg_change_stat_stage)
      end
      @r1_receiver_atk_after=receiver.cg_stat_stage(:atk).to_i
      @r1_share_atk_after=share_holder.cg_stat_stage(:atk).to_i
    end
    def self.prepare_pre_command_fixture
      return unless active?&&current_round==3&&@r3_release_prepared!=true
      a=test_allies
      return unless a[2]
      @r3_receiver_hp_before=a[2].hp.to_i
      a[2].hp=0
      @r3_release_prepared=true
      refresh_commander_links(:receiver_ko)
      log("ROUND3_PRE_COMMAND receiver_hp="+@r3_receiver_hp_before.to_s+"->"+a[2].hp.to_i.to_s+" commander_hidden="+(a[1] ? a[1].hidden.to_s : "nil"))
    end
    def self.prepare_round_fixture
      a=test_allies
      apply_round_slots
      set_actor_moves(a[0],[150]) if a[0]
      set_actor_moves(a[1],[150]) if a[1]
      set_actor_moves(a[2],[150]) if a[2]
      set_actor_moves(a[3],[150]) if a[3]
      if current_round==1
        apply_rally_fixture(a[0],a[2],a[3])
        share_slot=(a[3]&&a[3].respond_to?(:cg_battle_slot_assigned?)&&a[3].cg_battle_slot_assigned?) ? [a[3].cg_battle_row,a[3].cg_battle_column] : nil
        log("ROUND1_FIX commander_inside="+(a[1] ? commander_inside?(a[1]).to_s : "nil")+" share_targets="+(@r1_share_targets||[]).collect { |b| b.index.to_i }.inspect+" receiver_atk="+@r1_receiver_atk_before.to_s+"->"+@r1_receiver_atk_after.to_s+" share_atk="+@r1_share_atk_before.to_s+"->"+@r1_share_atk_after.to_s+" share_slot="+share_slot.inspect)
      elsif current_round==2
        @r2_share_before=a[3] ? a[3].cg_stat_stage(:atk).to_i : 0
        @r2_excluded_targets=warrior_skill_targets(a[0],:ambition,[a[2]])
        @r2_share_after=a[3] ? a[3].cg_stat_stage(:atk).to_i : 0
        @r2_force_reason=defined?(ALBERT_CG::FORCE_SWITCH_V235) ? ALBERT_CG::FORCE_SWITCH_V235.force_switch_block_reason(a[2],46) : :missing
        @r2_tele_reason=defined?(ALBERT_CG::UNIQUE_I_V242) ? ALBERT_CG::UNIQUE_I_V242.teleport_block_reason(a[2]) : :missing
        log("ROUND2_FIX force_reason="+@r2_force_reason.to_s+" teleport_reason="+@r2_tele_reason.to_s+" excluded_targets="+(@r2_excluded_targets||[]).collect { |b| b.index.to_i }.inspect+" share_atk="+@r2_share_before.to_s+"->"+@r2_share_after.to_s)
      else
        log("ROUND3_FIX receiver_dead="+(a[2] ? (a[2].hp.to_i<=0).to_s : "nil")+" commander_hidden="+(a[1] ? a[1].hidden.to_s : "nil")+" commander_inside="+(a[1] ? commander_inside?(a[1]).to_s : "nil"))
      end
    end
    def self.prepare_round_actions
      prepare_round_fixture
      apply_test_speeds
      @actual=[]
      a=test_allies
      plan=current_plan
      return false unless plan
      plan[:allies].each do |idx,cfg|
        battler=a[idx.to_i]
        next unless battler&&battler.hp.to_i>0&&!battler.hidden
        action=make_action(battler,cfg)
        if battler.respond_to?(:cg_round_actions)
          battler.cg_round_actions.clear
          battler.cg_round_actions.push(action)
        end
        if battler.respond_to?(:cg_assign_action)
          battler.cg_assign_action(action)
        else
          battler.instance_variable_set(:@action,action)
        end
      end
      log("ROUND "+current_round.to_s+" BEGIN "+plan[:name].to_s)
      true
    end

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted=true
      assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil"))
      assert_true("Ability Batch AV defines 2 handled IDs",HANDLED_ABILITY_IDS.size==2,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Scene_Battle uses Ability AV test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil"))
      assert_true("Ability AV ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s)
      assert_true("Ability AV enemy count=5",all_enemies.size==5,"actual="+all_enemies.size.to_s)
      a=test_allies
      linked=a[1]&&a[2]&&commander_inside?(a[1])&&a[1].hidden&&commander_partner(a[1])==a[2]&&a[2].instance_variable_get(:@cg_av_commander_holder)==a[1]
      @mechanic_checks+=1 if linked
      assert_true("Commander enters receiver and becomes hidden/inactive",linked,"holder_hidden="+(a[1] ? a[1].hidden.to_s : "nil")+" partner="+(a[1]&&commander_partner(a[1]) ? commander_partner(a[1]).index.to_i.to_s : "nil"))
      stages={}
      stat_ok=true
      if a[2]
        for stat in COMMANDER_STATS
          stages[stat]=a[2].cg_stat_stage(stat).to_i
          stat_ok=false unless stages[stat]==2
        end
      else
        stat_ok=false
      end
      @mechanic_checks+=1 if stat_ok
      assert_true("Commander raises receiver ATK/DEF/SPA/SPD/SPE by exactly +2 stages",stat_ok,"stages="+stages.inspect)
    end

    def self.finish_round_assertions
      a=test_allies
      r=current_round
      expected=EXPECTED_ORDERS[r]||[]
      order_ok=(@actual==expected)
      @action_checks+=1 if order_ok
      assert_true("Round"+r.to_s+" execution order matches deterministic plan",order_ok,"expected="+expected.inspect+" actual="+@actual.inspect)
      if r==1
        share_slot=(a[3]&&a[3].respond_to?(:cg_battle_slot_assigned?)&&a[3].cg_battle_slot_assigned?) ? [a[3].cg_battle_row,a[3].cg_battle_column] : nil
        target_ok=@r1_share_targets&&@r1_share_targets.include?(a[2])&&@r1_share_targets.include?(a[3])&&share_slot==[:back,2]
        @mechanic_checks+=1 if target_ok
        assert_true("Share adds holder to allied Rally targets regardless of Grid distance",target_ok,"targets="+(@r1_share_targets||[]).collect { |b| b.index.to_i }.inspect+" share_slot="+share_slot.inspect)
        effect_ok=@r1_receiver_atk_before.to_i==2&&@r1_receiver_atk_after.to_i==3&&@r1_share_atk_before.to_i==0&&@r1_share_atk_after.to_i==1
        @mechanic_checks+=1 if effect_ok
        assert_true("Share holder receives the real Rally +1 ATK effect through expanded targets",effect_ok,"receiver="+@r1_receiver_atk_before.to_s+"->"+@r1_receiver_atk_after.to_s+" share="+@r1_share_atk_before.to_s+"->"+@r1_share_atk_after.to_s)
      elsif r==2
        lock_ok=@r2_force_reason==:commander&&@r2_tele_reason==:commander
        @mechanic_checks+=1 if lock_ok
        assert_true("Commander receiver is blocked by both Force Switch and Teleport authorities",lock_ok,"force="+@r2_force_reason.to_s+" teleport="+@r2_tele_reason.to_s)
        excluded_ok=@r2_excluded_targets&&@r2_excluded_targets.include?(a[2])&&!@r2_excluded_targets.include?(a[3])&&@r2_share_before.to_i==@r2_share_after.to_i
        @mechanic_checks+=1 if excluded_ok
        assert_true("Share excludes Ambition and does not add the Share holder",excluded_ok,"targets="+(@r2_excluded_targets||[]).collect { |b| b.index.to_i }.inspect+" share_atk="+@r2_share_before.to_s+"->"+@r2_share_after.to_s)
      else
        rel=records_for(ABILITY_COMMANDER,:commander_release)
        released=a[1]&&a[2]&&a[2].hp.to_i<=0&&!a[1].hidden&&!commander_inside?(a[1])&&commander_partner(a[1])==nil&&!rel.empty?&&@actual.include?("A1:M150")
        @mechanic_checks+=1 if released
        assert_true("Receiver KO releases Commander holder and holder returns to the real action queue",released,"record="+(rel[-1]||{}).inspect+" actual="+@actual.inspect)
      end
      log("ROUND "+r.to_s+" END")
      @round_index=@round_index.to_i+1
    end

    def self.cleanup_output_logs
      keep=["CG_AutoRegression_LATEST.log","PMD_BattleInitTrace.log"]
      Dir.glob(File.join(project_root,"*.log")).each do |path|
        next if keep.include?(File.basename(path))
        begin
          File.delete(path)
        rescue
        end
      end
      true
    rescue
      false
    end
    def self.finalize_suite
      HANDLED_ABILITY_IDS.each do |aid|
        ok=@ability_trigger_counts[aid].to_i>0
        assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)
      end
      log("------------------------------------------------------------")
      result=@failures.empty? ? "PASS" : "FAIL"
      log("RESULT="+result)
      passed=HANDLED_ABILITY_IDS.select { |x| @ability_trigger_counts[x].to_i>0 }.size
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_av="+passed.to_s+"/2 mechanic_checks="+@mechanic_checks.to_s+" action_checks="+@action_checks.to_s+" pending=0")
      @failures.each_with_index { |x,i| log("FAILURE "+(i+1).to_s+" "+x.to_s) }
      (test_allies+all_enemies).each { |b| clear_runtime(b) }
      @active=false
      cleanup_output_logs
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.reset_suite
      @round_index=0
      @failures=[]
      @ability_trigger_counts={}
      @records={}
      @actual=[]
      @boot_asserted=false
      @mechanic_checks=0
      @action_checks=0
      @r3_release_prepared=false
    end
    def self.reset_log
      cleanup_output_logs
      header="CG POKEMON ABILITY AV COMMANDER + SHARE FINAL AUTO REGRESSION v2.5.47a\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; sealed AU baseline + Commander partner adapter + Share Warrior Skill target authority\r\n"+
        "BASELINE=v2.5.46 Ability Batch AU RPG Maker VX real-machine PASS; Move=937/937; Full Move Lifecycle=13/13\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AU_PASS=371 BATCH_AV=2 PENDING=0\r\n"+
        "BUILD=AV_v2.5.47a_SHARE_GRID_ASSERT_FIX_TEST\r\n"+
        "LEAN_LOGS=send CG_AutoRegression_LATEST.log + PMD_BattleInitTrace.log\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"
      File.open(latest_log_path,"wb") { |f| f.write(header) }
    rescue
    end
    def self.start_auto_test
      return false if active?
      reset_log
      reset_suite
      prepare_test_party
      make_test_troop
      @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AV_v2.5.47a") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s)
      ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e
      @failures=[] if @failures==nil
      @failures<<"AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s
      log(@failures[-1])
      @active=false
      false
    end
  end
end

ALBERT_CG::ABILITY_AV_V2547.register_handlers if defined?(ALBERT_CG::ABILITY_AV_V2547)

#==============================================================================
# ■ Formal integration bridges
#==============================================================================
class Game_Battler
  def cg_commander_partner_locked?
    return ALBERT_CG::ABILITY_AV_V2547.commander_partner_locked?(self) if defined?(ALBERT_CG::ABILITY_AV_V2547)
    false
  rescue
    false
  end

  alias cg_v2547av_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AV_V2547)&&ALBERT_CG::ABILITY_AV_V2547.active?&&@cg_priority_test_speed_override_av!=nil
      return @cg_priority_test_speed_override_av.to_i
    end
    cg_v2547av_priority_base_speed
  rescue
    cg_v2547av_priority_base_speed
  end
end

if defined?(ALBERT_CG::FORCE_SWITCH_V235)
  module ALBERT_CG
    module FORCE_SWITCH_V235
      class << self
        alias cg_v2547av_force_switch_block_reason force_switch_block_reason
        def force_switch_block_reason(target,move_id)
          if defined?(ALBERT_CG::ABILITY_AV_V2547)&&ALBERT_CG::ABILITY_AV_V2547.commander_partner_locked?(target)
            return :commander
          end
          cg_v2547av_force_switch_block_reason(target,move_id)
        end
      end
    end
  end
end

if defined?(ALBERT_CG::UNIQUE_I_V242)
  module ALBERT_CG
    module UNIQUE_I_V242
      class << self
        alias cg_v2547av_teleport_block_reason teleport_block_reason
        def teleport_block_reason(user)
          if defined?(ALBERT_CG::ABILITY_AV_V2547)&&ALBERT_CG::ABILITY_AV_V2547.commander_partner_locked?(user)
            return :commander
          end
          cg_v2547av_teleport_block_reason(user)
        end
      end
    end
  end
end

#==============================================================================
# ■ Scene_Battle TEST + safe Commander lifecycle refresh
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v2547av_start start
  def start
    ALBERT_CG::ABILITY_AV_V2547.pre_scene_start if defined?(ALBERT_CG::ABILITY_AV_V2547)&&ALBERT_CG::ABILITY_AV_V2547.active?
    cg_v2547av_start
  end

  alias cg_v2547av_execute_action execute_action
  def execute_action
    if defined?(ALBERT_CG::ABILITY_AV_V2547)&&ALBERT_CG::ABILITY_AV_V2547.active?&&@active_battler
      ALBERT_CG::ABILITY_AV_V2547.record_execution(@active_battler)
    end
    cg_v2547av_execute_action
  end

  alias cg_v2547av_turn_end turn_end
  def turn_end
    if defined?(ALBERT_CG::ABILITY_AV_V2547)&&ALBERT_CG::ABILITY_AV_V2547.active?
      ALBERT_CG::ABILITY_AV_V2547.finish_round_assertions
    end
    result=cg_v2547av_turn_end
    ALBERT_CG::ABILITY_AV_V2547.refresh_commander_links(:turn_end) if defined?(ALBERT_CG::ABILITY_AV_V2547)
    result
  end

  alias cg_v2547av_start_party_command start_party_command_selection
  def start_party_command_selection
    if defined?(ALBERT_CG::ABILITY_AV_V2547)
      ALBERT_CG::ABILITY_AV_V2547.prepare_pre_command_fixture if ALBERT_CG::ABILITY_AV_V2547.active?
      ALBERT_CG::ABILITY_AV_V2547.refresh_commander_links(:command_phase)
    end
    unless defined?(ALBERT_CG::ABILITY_AV_V2547)&&ALBERT_CG::ABILITY_AV_V2547.active?
      return cg_v2547av_start_party_command
    end
    cg_v2547av_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::ABILITY_AV_V2547.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AV_V2547.finished?
      ALBERT_CG::ABILITY_AV_V2547.finalize_suite
      battle_end(0)
      return
    end
    ALBERT_CG::ABILITY_AV_V2547.prepare_round_actions
    start_main
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2547av_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AV_V2547)&&ALBERT_CG::ABILITY_AV_V2547.active?
      action=ALBERT_CG::ABILITY_AV_V2547.forced_enemy_action(self)
      if action
        cg_assign_action(action) if respond_to?(:cg_assign_action)
        @action=action unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v2547av_enemy_make_action
  end
end

module ALBERT_CG
  class << self
    alias cg_v2547av_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result=cg_v2547av_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_AV_V2547)&&ALBERT_CG::ABILITY_AV_V2547.active?
        for cfg in ALBERT_CG::ABILITY_AV_V2547::TEST_ALLIES
          ALBERT_CG::ABILITY_AV_V2547.configure_actor(cfg)
        end
        human=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human
          human.change_level(ALBERT_CG::ABILITY_AV_V2547::TEST_LEVEL,false)
          human.recover_all
          human.cg_reset_stat_stages if human.respond_to?(:cg_reset_stat_stages)
          ALBERT_CG::ABILITY_AV_V2547.clear_runtime(human)
          ALBERT_CG::ABILITY_AV_V2547.set_ability(human,0)
          ALBERT_CG::ABILITY_AV_V2547.set_actor_moves(human,[150])
        end
        allies=$game_party ? $game_party.members : []
        ALBERT_CG::ABILITY_AV_V2547.set_commander_receiver_role(allies[2],true) if allies[2]
      end
      result
    end
  end
end

# Disable earlier F11 harnesses. Formal runtimes remain active.
if defined?(ALBERT_CG::ABILITY_AU_V2546)
  module ALBERT_CG; module ABILITY_AU_V2546; def self.f11_trigger?; false; end; end; end
end
if defined?(ALBERT_CG::ABILITY_AT_V2545)
  module ALBERT_CG; module ABILITY_AT_V2545; def self.f11_trigger?; false; end; end; end
end
if defined?(ALBERT_CG::ABILITY_AS_V2544)
  module ALBERT_CG; module ABILITY_AS_V2544; def self.f11_trigger?; false; end; end; end
end

class Scene_Map < Scene_Base
  alias cg_v2547av_scene_map_update update
  def update
    cg_v2547av_scene_map_update
    return unless defined?(ALBERT_CG::ABILITY_AV_V2547)
    ALBERT_CG::ABILITY_AV_V2547.start_auto_test if ALBERT_CG::ABILITY_AV_V2547.f11_trigger?
  end
end
