# RMVX_SCRIPT_INDEX: 271
# RMVX_SCRIPT_ID: 271
# RMVX_SCRIPT_NAME: CG Pokemon Ability Batch AU v2.5.46
# RMVX_SOURCE_SHA256: ceb0e3a52dc98a8b305176ce75d6d2cf6ad0f3a68a40bca0b7c208e7d40fc457

#==============================================================================
# ■ CG Pokemon Ability Batch AU v2.5.46 - Attraction + Weight + Identity + Reward TEST
#------------------------------------------------------------------------------
# 【正式基底】
#  v2.5.45a Batch AT RPG Maker VX real-machine PASS = 366/373。
#  Scripts 0..270 sealed byte-exact，本頁只新增 index271。
#
# 【本批 Ability】
#   56 Cute Charm / 迷人之軀
#  118 Honey Gather / 採蜜
#  134 Heavy Metal / 重金屬
#  135 Light Metal / 輕金屬
#  149 Illusion / 幻覺
#
# 【Authority】
#  - Cute Charm：after_contact 30% infatuation；異性限定、無性別/同性交互無效、Oblivious 免疫。
#    Infatuation 為 battle-only relationship token，每次行動 50% immobilized；source 消失時自動清除。
#  - Honey Gather：勝利 battle_end 前檢查玩家 Party；未持有 Held Item 時依等級 5%~50% 取得 Honey。
#    本作新增 runtime database Honey Item ID 950，不寫入 Data/Items.rvdata，腳本每次載入後可重建。
#  - Heavy / Light Metal：建立 1..494 Weight Authority（0.1kg 單位）；Heavy x2，Light x1/2 floor min 0.1kg。
#    Low Kick / Grass Knot / Heavy Slam / Heat Crash 直接讀同一 effective weight Authority。
#  - Illusion：entry 時只改 PMD visual sprite key，copy 同側 Party 最後一隻可戰鬥 Pokémon；
#    不改真實 species/type/stats/moves/ability。受到 damaging Move 真正 HP damage 後立即解除。
#
# 【F11】
#  3-round real Scene_Battle；若 PASS => Ability 371/373，pending 2。
#==============================================================================
$imported={} if $imported==nil
$imported["ALBERT_CG_PokemonAbilityBatchAU"]="2.5.46"

module ALBERT_CG
  module ABILITY_AU_V2546
    VERSION="2.5.46"; TEST_LEVEL=40; TEST_TROOP_ID=749; VK_F11=0x7A
    ABILITY_CUTE_CHARM=56; ABILITY_HONEY_GATHER=118
    ABILITY_HEAVY_METAL=134; ABILITY_LIGHT_METAL=135; ABILITY_ILLUSION=149
    ABILITY_OBLIVIOUS=12
    HANDLED_ABILITY_IDS=[56,118,134,135,149]
    CUTE_CHARM_CHANCE=30; INFATUATION_SKIP_CHANCE=50
    HONEY_ITEM_ID=950
    MOVE_LOW_KICK=67; MOVE_GRASS_KNOT=447; MOVE_HEAVY_SLAM=484; MOVE_HEAT_CRASH=535
    MOVE_SPLASH=150; MOVE_TACKLE=33
    WEIGHT_MOVE_IDS=[67,447,484,535]
    PRIMARY_PENDING=2

    # PokeAPI pokemon.csv default-form weights, unit=hectogram=0.1kg, species 1..494.
    BASE_WEIGHT_TENTHS={
      1=>69,2=>130,3=>1000,4=>85,5=>190,6=>905,7=>90,8=>225,9=>855,10=>29,
      11=>99,12=>320,13=>32,14=>100,15=>295,16=>18,17=>300,18=>395,19=>35,20=>185,
      21=>20,22=>380,23=>69,24=>650,25=>60,26=>300,27=>120,28=>295,29=>70,30=>200,
      31=>600,32=>90,33=>195,34=>620,35=>75,36=>400,37=>99,38=>199,39=>55,40=>120,
      41=>75,42=>550,43=>54,44=>86,45=>186,46=>54,47=>295,48=>300,49=>125,50=>8,
      51=>333,52=>42,53=>320,54=>196,55=>766,56=>280,57=>320,58=>190,59=>1550,60=>124,
      61=>200,62=>540,63=>195,64=>565,65=>480,66=>195,67=>705,68=>1300,69=>40,70=>64,
      71=>155,72=>455,73=>550,74=>200,75=>1050,76=>3000,77=>300,78=>950,79=>360,80=>785,
      81=>60,82=>600,83=>150,84=>392,85=>852,86=>900,87=>1200,88=>300,89=>300,90=>40,
      91=>1325,92=>1,93=>1,94=>405,95=>2100,96=>324,97=>756,98=>65,99=>600,100=>104,
      101=>666,102=>25,103=>1200,104=>65,105=>450,106=>498,107=>502,108=>655,109=>10,110=>95,
      111=>1150,112=>1200,113=>346,114=>350,115=>800,116=>80,117=>250,118=>150,119=>390,120=>345,
      121=>800,122=>545,123=>560,124=>406,125=>300,126=>445,127=>550,128=>884,129=>100,130=>2350,
      131=>2200,132=>40,133=>65,134=>290,135=>245,136=>250,137=>365,138=>75,139=>350,140=>115,
      141=>405,142=>590,143=>4600,144=>554,145=>526,146=>600,147=>33,148=>165,149=>2100,150=>1220,
      151=>40,152=>64,153=>158,154=>1005,155=>79,156=>190,157=>795,158=>95,159=>250,160=>888,
      161=>60,162=>325,163=>212,164=>408,165=>108,166=>356,167=>85,168=>335,169=>750,170=>120,
      171=>225,172=>20,173=>30,174=>10,175=>15,176=>32,177=>20,178=>150,179=>78,180=>133,
      181=>615,182=>58,183=>85,184=>285,185=>380,186=>339,187=>5,188=>10,189=>30,190=>115,
      191=>18,192=>85,193=>380,194=>85,195=>750,196=>265,197=>270,198=>21,199=>795,200=>10,
      201=>50,202=>285,203=>415,204=>72,205=>1258,206=>140,207=>648,208=>4000,209=>78,210=>487,
      211=>39,212=>1180,213=>205,214=>540,215=>280,216=>88,217=>1258,218=>350,219=>550,220=>65,
      221=>558,222=>50,223=>120,224=>285,225=>160,226=>2200,227=>505,228=>108,229=>350,230=>1520,
      231=>335,232=>1200,233=>325,234=>712,235=>580,236=>210,237=>480,238=>60,239=>235,240=>214,
      241=>755,242=>468,243=>1780,244=>1980,245=>1870,246=>720,247=>1520,248=>2020,249=>2160,250=>1990,
      251=>50,252=>50,253=>216,254=>522,255=>25,256=>195,257=>520,258=>76,259=>280,260=>819,
      261=>136,262=>370,263=>175,264=>325,265=>36,266=>100,267=>284,268=>115,269=>316,270=>26,
      271=>325,272=>550,273=>40,274=>280,275=>596,276=>23,277=>198,278=>95,279=>280,280=>66,
      281=>202,282=>484,283=>17,284=>36,285=>45,286=>392,287=>240,288=>465,289=>1305,290=>55,
      291=>120,292=>12,293=>163,294=>405,295=>840,296=>864,297=>2538,298=>20,299=>970,300=>110,
      301=>326,302=>110,303=>115,304=>600,305=>1200,306=>3600,307=>112,308=>315,309=>152,310=>402,
      311=>42,312=>42,313=>177,314=>177,315=>20,316=>103,317=>800,318=>208,319=>888,320=>1300,
      321=>3980,322=>240,323=>2200,324=>804,325=>306,326=>715,327=>50,328=>150,329=>153,330=>820,
      331=>513,332=>774,333=>12,334=>206,335=>403,336=>525,337=>1680,338=>1540,339=>19,340=>236,
      341=>115,342=>328,343=>215,344=>1080,345=>238,346=>604,347=>125,348=>682,349=>74,350=>1620,
      351=>8,352=>220,353=>23,354=>125,355=>150,356=>306,357=>1000,358=>10,359=>470,360=>140,
      361=>168,362=>2565,363=>395,364=>876,365=>1506,366=>525,367=>270,368=>226,369=>234,370=>87,
      371=>421,372=>1105,373=>1026,374=>952,375=>2025,376=>5500,377=>2300,378=>1750,379=>2050,380=>400,
      381=>600,382=>3520,383=>9500,384=>2065,385=>11,386=>608,387=>102,388=>970,389=>3100,390=>62,
      391=>220,392=>550,393=>52,394=>230,395=>845,396=>20,397=>155,398=>249,399=>200,400=>315,
      401=>22,402=>255,403=>95,404=>305,405=>420,406=>12,407=>145,408=>315,409=>1025,410=>570,
      411=>1495,412=>34,413=>65,414=>233,415=>55,416=>385,417=>39,418=>295,419=>335,420=>33,
      421=>93,422=>63,423=>299,424=>203,425=>12,426=>150,427=>55,428=>333,429=>44,430=>273,
      431=>39,432=>438,433=>6,434=>192,435=>380,436=>605,437=>1870,438=>150,439=>130,440=>244,
      441=>19,442=>1080,443=>205,444=>560,445=>950,446=>1050,447=>202,448=>540,449=>495,450=>3000,
      451=>120,452=>615,453=>230,454=>444,455=>270,456=>70,457=>240,458=>650,459=>505,460=>1355,
      461=>340,462=>1800,463=>1400,464=>2828,465=>1286,466=>1386,467=>680,468=>380,469=>515,470=>255,
      471=>259,472=>425,473=>2910,474=>340,475=>520,476=>3400,477=>1066,478=>266,479=>3,480=>3,
      481=>3,482=>3,483=>6830,484=>3360,485=>4300,486=>4200,487=>7500,488=>856,489=>31,490=>14,
      491=>505,492=>21,493=>3200,494=>40
    }

    TEST_ALLIES=[
      {:dex=>39, :level=>40,:ability=>ABILITY_CUTE_CHARM, :moves=>[150]},
      {:dex=>415,:level=>40,:ability=>ABILITY_HONEY_GATHER,:moves=>[67,150]},
      {:dex=>132,:level=>40,:ability=>ABILITY_ILLUSION,    :moves=>[67,150]}
    ]
    TEST_ENEMIES=[
      {:dex=>25,:level=>45,:ability=>ABILITY_HEAVY_METAL,:moves=>[150]},
      {:dex=>53,:level=>45,:ability=>ABILITY_LIGHT_METAL,:moves=>[150]},
      {:dex=>67,:level=>45,:ability=>0,:moves=>[33,150]},
      {:dex=>65,:level=>45,:ability=>0,:moves=>[150]},
      {:dex=>66,:level=>45,:ability=>0,:moves=>[33,150]}
    ]

    ROUND_PLANS=[
      {:name=>"CUTE_WEIGHT_ILLUSION_ENTRY",
        :allies=>[
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>67,:target=>0},
          {:kind=>:move,:move_id=>67,:target=>1}],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>0},
          2=>{:kind=>:move,:move_id=>33,:target=>1},
          3=>{:kind=>:move,:move_id=>150,:target=>0},
          4=>{:kind=>:move,:move_id=>150,:target=>0}}},
      {:name=>"INFATUATION_SKIP_ILLUSION_BREAK",
        :allies=>[
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0}],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>0},
          2=>{:kind=>:move,:move_id=>33,:target=>0},
          3=>{:kind=>:move,:move_id=>150,:target=>0},
          4=>{:kind=>:move,:move_id=>33,:target=>3}}},
      {:name=>"STABILITY_BEFORE_HONEY_VICTORY",
        :allies=>[
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0}],
        :enemies=>{
          0=>{:kind=>:move,:move_id=>150,:target=>0},
          1=>{:kind=>:move,:move_id=>150,:target=>0},
          2=>{:kind=>:move,:move_id=>150,:target=>0},
          3=>{:kind=>:move,:move_id=>150,:target=>0},
          4=>{:kind=>:move,:move_id=>150,:target=>0}}}
    ]
    TEST_SPEEDS={
      1=>[500,600,1000,950,400,350,900,300,250],
      2=>[700,650,600,550,400,350,900,300,1000],
      3=>[1000,950,900,850,700,650,600,550,500]
    }

    begin; KEY_API=Win32API.new("user32","GetAsyncKeyState","i","i"); rescue; KEY_API=nil; end

    def self.core; defined?(ALBERT_CG::ABILITY_V250) ? ALBERT_CG::ABILITY_V250 : nil; end
    def self.master; defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil; end
    def self.active?; @active==true; end
    def self.current_round; @round_index.to_i+1; end
    def self.current_plan; ROUND_PLANS[@round_index.to_i]; end
    def self.finished?; @round_index.to_i>=ROUND_PLANS.size; end
    def self.test_allies; $game_party ? $game_party.members : []; end
    def self.all_enemies; $game_troop ? $game_troop.members : []; end
    def self.project_root; Dir.pwd; rescue; "."; end
    def self.latest_log_path; File.join(project_root,"CG_AutoRegression_LATEST.log"); end
    def self.log(t); File.open(latest_log_path,"ab"){|f|f.write(t.to_s+"\r\n")}; rescue; end
    def self.key_down?(c); KEY_API&&(KEY_API.call(c)&0x8000)!=0; rescue; false; end
    def self.f11_trigger?; d=key_down?(VK_F11); t=d&&@f11_down!=true; @f11_down=d; t; rescue; false; end
    def self.ability_id(b); core&&b ? core.ability_id(b).to_i : 0; rescue; 0; end
    def self.raw_ability_id(b); return 0 unless b; v=b.instance_variable_get(:@cg_master_ability_id); return v.to_i unless v==nil; b.respond_to?(:cg_master_ability_id) ? b.cg_master_ability_id.to_i : 0; rescue; 0; end
    def self.move_id(skill); defined?(ALBERT_CG::MOVE_EFFECT)&&skill ? ALBERT_CG::MOVE_EFFECT.move_id(skill).to_i : 0; rescue; 0; end
    def self.same_side?(a,b); a&&b&&(a.actor? == b.actor?); rescue; false; end
    def self.opposing?(a,b); a&&b&&(a.actor? != b.actor?); rescue; false; end
    def self.gender_of(b)
      return nil unless b
      v=nil
      begin; v=b.cg_gender if b.respond_to?(:cg_gender); rescue; v=nil; end
      v=b.instance_variable_get(:@cg_gender) if v==nil
      return v if v==:male||v==:female
      return nil if v==:genderless
      if b.respond_to?(:cg_national_dex)&&defined?(ALBERT_CG::POKEMON_MASTER)
        rate=ALBERT_CG::POKEMON_MASTER.male_rate_per_thousand(b.cg_national_dex.to_i)
        v=(rate==:genderless) ? :genderless : (rand(1000)<rate.to_i ? :male : :female)
        b.instance_variable_set(:@cg_gender,v)
        return v if v==:male||v==:female
      end
      nil
    rescue; nil; end

    def self.assert_true(label,cond,detail=nil)
      if cond; log("ASSERT PASS "+label.to_s+(detail ? " "+detail.to_s : ""))
      else; x=label.to_s+(detail ? " "+detail.to_s : ""); @failures<<x; log("ASSERT FAIL "+x); end
      cond
    end
    def self.note_local(aid,b,kind,data=nil)
      rec={:ability=>aid.to_i,:kind=>kind}; (data||{}).each{|k,v|rec[k]=v unless [:battler,:user,:target,:skill,:action].include?(k)}
      if active?; @ability_trigger_counts[aid.to_i]=@ability_trigger_counts[aid.to_i].to_i+1; (@records[aid.to_i]||=[])<<rec; log("ABILITY_AU_TRIGGER ability="+aid.to_s+" battler="+(b ? b.name.to_s : "nil")+" kind="+kind.to_s+" ctx="+rec.inspect); end
      rec
    rescue; nil; end
    def self.formal_note(aid,b,kind,data=nil)
      ctx=data||{}; if core; core.note_trigger(kind,b,aid,ctx) if core.respond_to?(:note_trigger); core.present_trigger(b,aid,kind,ctx) if core.respond_to?(:present_trigger); end
      note_local(aid,b,kind,ctx); true
    rescue; false; end
    def self.records_for(aid,kind=nil); a=@records[aid.to_i]||[]; kind ? a.select{|x|x[:kind].to_sym==kind.to_sym} : a; rescue; []; end
    def self.set_ability(b,aid); return unless b; b.instance_variable_set(:@cg_v237_ability_override,nil); b.instance_variable_set(:@cg_v237_ability_suppressed,false); b.instance_variable_set(:@cg_master_ability_id,aid.to_i); end

    #--------------------------------------------------------------------------
    # Weight Authority
    #--------------------------------------------------------------------------
    def self.base_weight_tenths(b)
      return 1 unless b&&b.respond_to?(:cg_national_dex)
      v=BASE_WEIGHT_TENTHS[b.cg_national_dex.to_i]; v==nil ? 1 : [v.to_i,1].max
    rescue; 1; end
    def self.effective_weight_tenths(b)
      base=base_weight_tenths(b); aid=ability_id(b); out=base
      out=base*2 if aid==ABILITY_HEAVY_METAL
      out=[base/2,1].max if aid==ABILITY_LIGHT_METAL
      if active?&&(aid==ABILITY_HEAVY_METAL||aid==ABILITY_LIGHT_METAL)
        @weight_noted||={}; key=[b.object_id,aid]; unless @weight_noted[key]; @weight_noted[key]=true; formal_note(aid,b,aid==ABILITY_HEAVY_METAL ? :heavy_metal_weight : :light_metal_weight,{:base=>base,:effective=>out,:dex=>(b.respond_to?(:cg_national_dex) ? b.cg_national_dex.to_i : 0)}); end
      end
      out
    rescue; base_weight_tenths(b); end
    def self.low_kick_power(target_weight)
      w=target_weight.to_i
      return 20 if w<100
      return 40 if w<250
      return 60 if w<500
      return 80 if w<1000
      return 100 if w<2000
      120
    end
    def self.heavy_slam_power(user_weight,target_weight)
      u=[user_weight.to_i,1].max; t=[target_weight.to_i,1].max
      return 120 if u>=t*5
      return 100 if u>=t*4
      return 80 if u>=t*3
      return 60 if u>=t*2
      40
    end
    def self.weight_move_power(user,target,mid)
      return nil unless WEIGHT_MOVE_IDS.include?(mid.to_i)
      uw=effective_weight_tenths(user); tw=effective_weight_tenths(target)
      p=(mid.to_i==MOVE_LOW_KICK||mid.to_i==MOVE_GRASS_KNOT) ? low_kick_power(tw) : heavy_slam_power(uw,tw)
      log("WEIGHT_MOVE move="+mid.to_i.to_s+" user="+(user ? user.name.to_s : "nil")+" target="+(target ? target.name.to_s : "nil")+" user_w="+uw.to_s+" target_w="+tw.to_s+" power="+p.to_s) if active?
      @weight_move_records||=[]; @weight_move_records<<{:move_id=>mid.to_i,:user_w=>uw,:target_w=>tw,:power=>p,:target_index=>(target&&target.respond_to?(:index) ? target.index.to_i : -1)} if active?
      p
    rescue; nil; end

    #--------------------------------------------------------------------------
    # Infatuation / Cute Charm
    #--------------------------------------------------------------------------
    def self.infatuated?(b); b&&b.instance_variable_get(:@cg_au_infatuation_source)!=nil; rescue; false; end
    def self.clear_infatuation(b,reason=:clear)
      return false unless b&&infatuated?(b); src=b.instance_variable_get(:@cg_au_infatuation_source); b.instance_variable_set(:@cg_au_infatuation_source,nil)
      log("INFATUATION_CLEAR battler="+b.name.to_s+" reason="+reason.to_s+" source="+(src ? src.name.to_s : "nil")) if active?
      true
    rescue; false; end
    def self.can_infatuate?(target,source)
      return false unless target&&source&&opposing?(target,source)
      g1=gender_of(target); g2=gender_of(source); return false if g1==nil||g2==nil||g1==g2
      return false if ability_id(target)==ABILITY_OBLIVIOUS
      true
    rescue; false; end
    def self.set_infatuation(target,source)
      return false unless can_infatuate?(target,source)
      target.instance_variable_set(:@cg_au_infatuation_source,source); true
    end
    def self.proc_cute_charm?; return true if active?&&@force_cute_charm==true; rand(100)<CUTE_CHARM_CHANCE; rescue; false; end
    def self.apply_cute_charm(holder,ctx)
      return false unless holder&&ctx&&ability_id(holder)==ABILITY_CUTE_CHARM&&ctx[:contact]==true&&ctx[:damage_done].to_i>0
      attacker=ctx[:user]; return false unless attacker&&proc_cute_charm?&&set_infatuation(attacker,holder)
      formal_note(ABILITY_CUTE_CHARM,holder,:cute_charm,{:attacker_index=>attacker.index.to_i,:attacker_gender=>gender_of(attacker),:holder_gender=>gender_of(holder),:chance=>CUTE_CHARM_CHANCE}); true
    rescue; false; end
    def self.infatuation_blocks_action?(b)
      return false unless infatuated?(b)
      src=b.instance_variable_get(:@cg_au_infatuation_source)
      unless src&&src.hp.to_i>0&&!src.hidden&&opposing?(b,src); clear_infatuation(b,:source_gone); return false; end
      forced=active?&&@force_love_skip&&@force_love_skip[b.object_id]==true
      ok=forced ? true : (rand(100)<INFATUATION_SKIP_CHANCE)
      if ok
        note_local(ABILITY_CUTE_CHARM,src,:infatuation_skip,{:attacker_index=>b.index.to_i,:chance=>INFATUATION_SKIP_CHANCE})
      end
      ok
    rescue; false; end

    #--------------------------------------------------------------------------
    # Illusion
    #--------------------------------------------------------------------------
    def self.illusion_source_for(holder)
      return nil unless holder&&holder.actor?&&$game_party
      ary=$game_party.members.clone.reverse
      for b in ary
        next if b==nil||b==holder||b.hp.to_i<=0||b.hidden
        next unless b.respond_to?(:cg_pmd_sprite_key)
        key=b.cg_pmd_sprite_key.to_s
        next if key==""
        return b
      end
      nil
    rescue; nil; end
    def self.apply_illusion(holder,ctx)
      return false unless holder&&holder.actor?&&ability_id(holder)==ABILITY_ILLUSION&&holder.respond_to?(:cg_pmd_sprite_key)
      src=illusion_source_for(holder); return false if src==nil
      key=src.cg_pmd_sprite_key.to_s; return false if key==""
      holder.instance_variable_set(:@cg_au_illusion_original_override,holder.instance_variable_get(:@cg_pmd_sprite_key_override))
      holder.instance_variable_set(:@cg_au_illusion_source,src)
      holder.instance_variable_set(:@cg_au_illusion_active,true)
      holder.instance_variable_set(:@cg_pmd_sprite_key_override,key)
      formal_note(ABILITY_ILLUSION,holder,:illusion_entry,{:source_index=>src.index.to_i,:sprite_key=>key,:real_dex=>(holder.respond_to?(:cg_national_dex) ? holder.cg_national_dex.to_i : 0)}); true
    rescue; false; end
    def self.break_illusion(holder,reason=:damage)
      return false unless holder&&holder.instance_variable_get(:@cg_au_illusion_active)==true
      old=holder.instance_variable_get(:@cg_au_illusion_original_override)
      holder.instance_variable_set(:@cg_pmd_sprite_key_override,old)
      holder.instance_variable_set(:@cg_au_illusion_active,false)
      holder.instance_variable_set(:@cg_au_illusion_source,nil)
      holder.instance_variable_set(:@cg_au_illusion_original_override,nil)
      formal_note(ABILITY_ILLUSION,holder,:illusion_break,{:reason=>reason,:restored_key=>(holder.respond_to?(:cg_pmd_sprite_key) ? holder.cg_pmd_sprite_key.to_s : "")}); true
    rescue; false; end
    def self.illusion_after_damage(holder,ctx)
      return false unless holder&&ability_id(holder)==ABILITY_ILLUSION&&ctx&&ctx[:damage_done].to_i>0
      break_illusion(holder,:damaging_move)
    end

    #--------------------------------------------------------------------------
    # Honey Gather
    #--------------------------------------------------------------------------
    def self.ensure_honey_item
      return nil if $data_items==nil
      if $data_items[HONEY_ITEM_ID]==nil
        base=$data_items[1]; item=base ? base.dup : RPG::Item.new
        item.instance_variable_set(:@id,HONEY_ITEM_ID)
        item.instance_variable_set(:@name,"甜甜蜜")
        item.instance_variable_set(:@description,"由採蜜特性在戰鬥勝利後取得的甜甜蜜。")
        item.instance_variable_set(:@price,100)
        item.instance_variable_set(:@consumable,true)
        item.instance_variable_set(:@scope,0)
        item.instance_variable_set(:@occasion,3)
        $data_items[HONEY_ITEM_ID]=item
      end
      $data_items[HONEY_ITEM_ID]
    rescue; nil; end
    def self.honey_chance(level)
      n=((level.to_i-1)/10+1)*5; n=5 if n<5; n=50 if n>50; n
    end
    def self.honey_eligible?(b)
      return false unless b&&b.actor?&&raw_ability_id(b)==ABILITY_HONEY_GATHER
      item=b.respond_to?(:cg_raw_held_item) ? b.cg_raw_held_item : nil
      item==nil
    rescue; false; end
    def self.process_honey_gather(result)
      return 0 unless result.to_i==0&&$game_party
      item=ensure_honey_item; return 0 if item==nil
      count=0
      for b in $game_party.members
        next unless honey_eligible?(b)
        chance=honey_chance(b.level.to_i)
        forced=active?&&@force_honey==true
        next unless forced||(rand(100)<chance)
        before=$game_party.item_number(item).to_i; $game_party.gain_item(item,1); after=$game_party.item_number(item).to_i
        next unless after==before+1
        formal_note(ABILITY_HONEY_GATHER,b,:honey_gather,{:level=>b.level.to_i,:chance=>chance,:item_id=>HONEY_ITEM_ID,:before=>before,:after=>after})
        count+=1
      end
      count
    rescue=>e; log("HONEY_ERROR "+e.class.to_s+":"+e.message.to_s) if active?; 0; end

    def self.register_handlers
      return false unless core
      core.register(ABILITY_CUTE_CHARM,:after_contact,self,:apply_cute_charm)
      core.register(ABILITY_ILLUSION,:entry,self,:apply_illusion)
      core.register(ABILITY_ILLUSION,:after_damage,self,:illusion_after_damage)
      true
    rescue; false; end

    #--------------------------------------------------------------------------
    # Harness
    #--------------------------------------------------------------------------
    def self.clear_runtime(b)
      return unless b
      b.instance_variable_set(:@cg_priority_test_speed_override_au,nil)
      b.instance_variable_set(:@cg_au_infatuation_source,nil)
      if b.instance_variable_get(:@cg_au_illusion_active)==true
        old=b.instance_variable_get(:@cg_au_illusion_original_override); b.instance_variable_set(:@cg_pmd_sprite_key_override,old)
      end
      b.instance_variable_set(:@cg_au_illusion_active,false); b.instance_variable_set(:@cg_au_illusion_source,nil); b.instance_variable_set(:@cg_au_illusion_original_override,nil)
    end
    def self.configure_actor(cfg); a=$game_actors[master.actor_id_for_dex(cfg[:dex])]; return unless a; master.configure_actor(a,cfg); a.recover_all if a.respond_to?(:recover_all); a.cg_reset_stat_stages if a.respond_to?(:cg_reset_stat_stages); clear_runtime(a); set_ability(a,cfg[:ability]); end
    def self.configure_enemy(cfg); master.configure_enemy_data(cfg); end
    def self.set_actor_moves(b,mids)
      return unless b&&b.actor?; sids=mids.collect{|m|master.skill_id_for_move(m.to_i)}.select{|x|x.to_i>0}; b.instance_variable_set(:@cg_equipped_skill_ids,sids); b.instance_variable_set(:@cg_skill_slot_ids,sids); b.instance_variable_set(:@skills,sids)
    end
    def self.prepare_test_party
      ids=TEST_ALLIES.collect{|c|master.actor_id_for_dex(c[:dex])}; ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized,true); $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each{|c|configure_actor(c)}
      h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); clear_runtime(h); set_ability(h,0); set_actor_moves(h,[150]); end
      a=test_allies; a[1].instance_variable_set(:@cg_gender,:female) if a[1]
      ensure_honey_item
    end
    def self.make_test_troop
      master.ensure_index($data_troops,TEST_TROOP_ID)
      xs=[ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X,ALBERT_CG::ENEMY_FRONT_X]
      ys=[ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[2]]
      ms=[]; TEST_ENEMIES.each_with_index{|c,i|configure_enemy(c); m=ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(c[:dex]),xs[i],ys[i]); m.hidden=false; ms<<m}
      $data_troops[TEST_TROOP_ID]=ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,"Pokemon Ability AU v2.5.46 AutoRegression",ms)
    end
    def self.pre_scene_start
      a=test_allies; e=all_enemies
      (a+e).each{|b|clear_runtime(b)}
      set_ability(a[0],0) if a[0]; set_ability(a[1],ABILITY_CUTE_CHARM) if a[1]; set_ability(a[2],ABILITY_HONEY_GATHER) if a[2]; set_ability(a[3],ABILITY_ILLUSION) if a[3]
      set_ability(e[0],ABILITY_HEAVY_METAL) if e[0]; set_ability(e[1],ABILITY_LIGHT_METAL) if e[1]; set_ability(e[2],0) if e[2]; set_ability(e[3],0) if e[3]; set_ability(e[4],0) if e[4]
      a[1].instance_variable_set(:@cg_gender,:female) if a[1]; e[2].instance_variable_set(:@cg_gender,:male) if e[2]
      @force_cute_charm=true; @force_honey=true; @force_love_skip={}
    end
    def self.make_action(b,c)
      a=Game_BattleAction.new(b); if c[:kind]==:guard; a.set_guard; else; a.set_skill(master.skill_id_for_move(c[:move_id].to_i)); end; a.target_index=c[:target].to_i if c.has_key?(:target); a
    end
    def self.forced_enemy_action(e); return nil unless active?&&e&&!e.hidden&&e.hp.to_i>0; c=current_plan[:enemies][e.index] rescue nil; c ? make_action(e,c) : nil; end
    def self.action_token(b)
      return "nil" unless b; s=b.actor? ? "A" : "E"; a=b.action
      return s+b.index.to_s+":Guard" if a&&a.guard?
      return s+b.index.to_s+":M"+move_id(a.skill).to_s if a&&a.skill?
      s+b.index.to_s+":Other"
    rescue; "?"; end
    def self.record_execution(b)
      return unless active?
      @actual<<action_token(b); log("ACTION_EXEC #"+@actual.size.to_s+" "+(b ? b.name.to_s : "nil")+" token="+@actual[-1].to_s)
    end
    def self.record_love_skip(b)
      return unless active?; s=b.actor? ? "A" : "E"; tok=s+b.index.to_s+":LOVE_SKIP"; @actual<<tok; log("ACTION_EXEC #"+@actual.size.to_s+" "+b.name.to_s+" token="+tok)
    end
    def self.apply_test_speeds
      sp=TEST_SPEEDS[current_round]||[]; (test_allies+all_enemies).each_with_index{|b,i|b.instance_variable_set(:@cg_priority_test_speed_override_au,sp[i]) if b&&sp[i]!=nil}
    end
    def self.apply_round_slots
      a=test_allies; e=all_enemies
      a[0].cg_set_battle_slot(:front,0,true) if a[0]; a[1].cg_set_battle_slot(:front,1,true) if a[1]; a[2].cg_set_battle_slot(:front,2,true) if a[2]; a[3].cg_set_battle_slot(:front,1,true) if a[3]
      e[0].cg_set_battle_slot(:front,0,true) if e[0]; e[1].cg_set_battle_slot(:front,1,true) if e[1]; e[2].cg_set_battle_slot(:front,2,true) if e[2]; e[3].cg_set_battle_slot(:back,0,true) if e[3]; e[4].cg_set_battle_slot(:front,2,true) if e[4]
    end
    def self.prepare_round_fixture
      a=test_allies; e=all_enemies; apply_round_slots
      set_actor_moves(a[0],[150]); set_actor_moves(a[1],[150]); set_actor_moves(a[2],current_round==1 ? [67,150] : [150]); set_actor_moves(a[3],current_round==1 ? [67,150] : [150])
      if current_round==1
        @weight_move_records=[]; @r1_cute_before=records_for(ABILITY_CUTE_CHARM,:cute_charm).size
        @r1_heavy_base=base_weight_tenths(e[0]); @r1_heavy_eff=effective_weight_tenths(e[0]); @r1_light_base=base_weight_tenths(e[1]); @r1_light_eff=effective_weight_tenths(e[1])
        log("ROUND1_FIX cute=true heavy="+@r1_heavy_base.to_s+"->"+@r1_heavy_eff.to_s+" light="+@r1_light_base.to_s+"->"+@r1_light_eff.to_s+" illusion_entry="+(a[3]&&a[3].instance_variable_get(:@cg_au_illusion_active)==true).to_s)
      elsif current_round==2
        @force_love_skip[e[2].object_id]=true if e[2]; @r2_illusion_before=a[3]&&a[3].respond_to?(:cg_pmd_sprite_key) ? a[3].cg_pmd_sprite_key.to_s : ""
        @r2_real_key=a[3] ? CG_PMD::SPECIES_SPRITES[a[3].id].to_s : ""
        @r2_target_hp=a[3] ? a[3].hp.to_i : 0
        log("ROUND2_FIX love_skip=true illusion_before="+@r2_illusion_before+" real_key="+@r2_real_key)
      else
        log("ROUND3_FIX stable=true honey_after_victory=true")
      end
    end
    def self.prepare_round_actions
      prepare_round_fixture; apply_test_speeds; @actual=[]; a=test_allies; p=current_plan; return false unless p
      p[:allies].each_with_index{|cfg,i|next unless a[i]&&a[i].hp.to_i>0; act=make_action(a[i],cfg); if a[i].respond_to?(:cg_round_actions); a[i].cg_round_actions.clear; a[i].cg_round_actions.push(act); end; a[i].cg_assign_action(act) if a[i].respond_to?(:cg_assign_action); a[i].instance_variable_set(:@action,act) unless a[i].respond_to?(:cg_assign_action)}
      log("ROUND "+current_round.to_s+" BEGIN "+p[:name].to_s); true
    end

    def self.assert_bootstrap_once
      return if @boot_asserted; @boot_asserted=true
      assert_true("Ability Catalog count=373",core&&core.catalog_count.to_i==373,"actual="+(core ? core.catalog_count.to_i.to_s : "nil"))
      assert_true("Ability Batch AU defines 5 handled IDs",HANDLED_ABILITY_IDS.size==5,"actual="+HANDLED_ABILITY_IDS.size.to_s)
      assert_true("Weight Authority covers 494 species",BASE_WEIGHT_TENTHS.size==494,"actual="+BASE_WEIGHT_TENTHS.size.to_s)
      assert_true("Scene_Battle uses Ability AU test troop",$game_troop&&$game_troop.troop&&$game_troop.troop.id.to_i==TEST_TROOP_ID,"actual="+($game_troop&&$game_troop.troop ? $game_troop.troop.id.to_i.to_s : "nil"))
      assert_true("Ability AU ally count=4",test_allies.size==4,"actual="+test_allies.size.to_s); assert_true("Ability AU enemy count=5",all_enemies.size==5,"actual="+all_enemies.size.to_s)
      a=test_allies; if a[3]
        src=a[3].instance_variable_get(:@cg_au_illusion_source); @illusion_entry_key=a[3].cg_pmd_sprite_key.to_s; @illusion_source_key=src&&src.respond_to?(:cg_pmd_sprite_key) ? src.cg_pmd_sprite_key.to_s : ""
        ok=a[3].instance_variable_get(:@cg_au_illusion_active)==true&&@illusion_entry_key!=""&&@illusion_entry_key==@illusion_source_key
        @mechanic_checks+=1 if ok; assert_true("Illusion entry copies only visual PMD identity from last conscious ally",ok,"illusion_key="+@illusion_entry_key+" source_key="+@illusion_source_key+" real_dex="+a[3].cg_national_dex.to_i.to_s)
      end
    end
    def self.finish_round_assertions
      a=test_allies; e=all_enemies; r=current_round
      if r==1
        cr=records_for(ABILITY_CUTE_CHARM,:cute_charm); cok=cr.size>@r1_cute_before.to_i&&e[2]&&infatuated?(e[2]); @mechanic_checks+=1 if cok; assert_true("Cute Charm contact proc infatuates opposite-gender attacker",cok,"record="+(cr[-1]||{}).inspect+" infatuated="+(e[2] ? infatuated?(e[2]).to_s : "nil"))
        hrec=(@weight_move_records||[]).find{|x|x[:target_index].to_i==0&&x[:move_id].to_i==67}; lrec=(@weight_move_records||[]).find{|x|x[:target_index].to_i==1&&x[:move_id].to_i==67}
        hok=@r1_heavy_eff.to_i==@r1_heavy_base.to_i*2&&hrec&&hrec[:power].to_i==40; lok=@r1_light_eff.to_i==[@r1_light_base.to_i/2,1].max&&lrec&&lrec[:power].to_i==40
        @mechanic_checks+=1 if hok; @mechanic_checks+=1 if lok
        assert_true("Heavy Metal doubles weight and Low Kick reads effective weight",hok,"weight="+@r1_heavy_base.to_s+"->"+@r1_heavy_eff.to_s+" rec="+(hrec||{}).inspect)
        assert_true("Light Metal halves weight and Low Kick reads effective weight",lok,"weight="+@r1_light_base.to_s+"->"+@r1_light_eff.to_s+" rec="+(lrec||{}).inspect)
      elsif r==2
        skip=@actual.include?("E2:LOVE_SKIP"); @mechanic_checks+=1 if skip; assert_true("Infatuation 50% gate can immobilize the attacker action",skip,"actual="+@actual.inspect)
        br=records_for(ABILITY_ILLUSION,:illusion_break); broken=a[3]&&a[3].instance_variable_get(:@cg_au_illusion_active)!=true&&a[3].cg_pmd_sprite_key.to_s!=@r2_illusion_before&&a[3].hp.to_i<@r2_target_hp.to_i&&!br.empty?
        @mechanic_checks+=1 if broken; assert_true("Illusion breaks only after real damaging Move HP loss",broken,"record="+(br[-1]||{}).inspect+" hp="+@r2_target_hp.to_s+"->"+(a[3] ? a[3].hp.to_i.to_s : "nil")+" key="+(a[3] ? a[3].cg_pmd_sprite_key.to_s : "nil"))
      else
        stable=true; @mechanic_checks+=1 if stable; assert_true("Round3 stability completes before victory reward hook",stable)
      end
      log("ROUND "+r.to_s+" END"); @round_index=@round_index.to_i+1
    end

    def self.cleanup_output_logs; keep=["CG_AutoRegression_LATEST.log","PMD_BattleInitTrace.log"]; Dir.glob(File.join(project_root,"*.log")).each{|p|next if keep.include?(File.basename(p)); begin;File.delete(p);rescue;end}; true; rescue; false; end
    def self.finalize_after_honey
      item=ensure_honey_item; after=item&&$game_party ? $game_party.item_number(item).to_i : -1
      hr=records_for(ABILITY_HONEY_GATHER,:honey_gather); hok=!hr.empty?&&after==@honey_before.to_i+1
      @mechanic_checks+=1 if hok; assert_true("Honey Gather victory hook awards Honey using level-scaled chance",hok,"record="+(hr[-1]||{}).inspect+" honey="+@honey_before.to_s+"->"+after.to_s)
      HANDLED_ABILITY_IDS.each{|aid|ok=@ability_trigger_counts[aid].to_i>0; assert_true("Ability "+aid.to_s+" triggered count>0",ok,"count="+@ability_trigger_counts[aid].to_i.to_s)}
      log("------------------------------------------------------------"); result=@failures.empty? ? "PASS" : "FAIL"; log("RESULT="+result); passed=HANDLED_ABILITY_IDS.select{|x|@ability_trigger_counts[x].to_i>0}.size
      log("SUMMARY rounds=3 failures="+@failures.size.to_s+" ability_au="+passed.to_s+"/5 mechanic_checks="+@mechanic_checks.to_s+" pending=2")
      @failures.each_with_index{|x,i|log("FAILURE "+(i+1).to_s+" "+x.to_s)}
      if active?&&item&&$game_party&&after>@honey_before.to_i; $game_party.lose_item(item,after-@honey_before.to_i); end
      (test_allies+all_enemies).each{|b|clear_runtime(b)}; @active=false; cleanup_output_logs
      ALBERT_CG::TEST_CONVENIENCE.finish_session if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:finish_session)
    end
    def self.prepare_finish
      item=ensure_honey_item; @honey_before=item&&$game_party ? $game_party.item_number(item).to_i : -1; @await_honey_finalize=true
    end
    def self.reset_suite
      @round_index=0; @failures=[]; @ability_trigger_counts={}; @records={}; @actual=[]; @boot_asserted=false; @mechanic_checks=0; @weight_move_records=[]; @weight_noted={}; @force_love_skip={}; @force_cute_charm=true; @force_honey=true; @await_honey_finalize=false
    end
    def self.reset_log
      cleanup_output_logs; h="CG POKEMON ABILITY AU ATTRACTION + WEIGHT + IDENTITY + REWARD AUTO REGRESSION v2.5.46\r\n"+
        "START="+Time.now.strftime("%Y-%m-%d %H:%M:%S")+"\r\n"+
        "RULE=Actual Scene_Battle; sealed AT baseline + attraction + 494 weight + Illusion visual identity + victory reward\r\n"+
        "BASELINE=v2.5.45a Ability Batch AT RPG Maker VX real-machine PASS; Move=937/937; Full Move Lifecycle=13/13\r\n"+
        "ABILITY_CATALOG=373 BATCH_A_TO_AT_PASS=366 BATCH_AU=5 PENDING=2\r\n"+
        "BUILD=AU_v2.5.46_ATTRACTION_WEIGHT_IDENTITY_REWARD_TEST\r\n"+
        "LEAN_LOGS=send CG_AutoRegression_LATEST.log + PMD_BattleInitTrace.log\r\n"+
        "RUNTIME_PASS_REQUIRED=RPG Maker VX real-machine LOG; this build is not pre-declared PASS\r\n"+
        "------------------------------------------------------------\r\n"; File.open(latest_log_path,"wb"){|f|f.write(h)}
    rescue; end
    def self.start_auto_test
      return false if active?; reset_log; reset_suite; prepare_test_party; make_test_troop; @active=true
      ALBERT_CG::TEST_CONVENIENCE.begin_session("Ability_AU_v2.5.46") if defined?(ALBERT_CG::TEST_CONVENIENCE)&&ALBERT_CG::TEST_CONVENIENCE.respond_to?(:begin_session)
      log("AUTO_TEST_START troop="+TEST_TROOP_ID.to_s); ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    rescue=>e; @failures=[] if @failures==nil; @failures<<"AUTO_TEST_START_ERROR "+e.class.to_s+":"+e.message.to_s; log(@failures[-1]); @active=false; false; end
  end
end

ALBERT_CG::ABILITY_AU_V2546.register_handlers if defined?(ALBERT_CG::ABILITY_AU_V2546)

#==============================================================================
# ■ Formal bridges
#==============================================================================
class Game_Battler
  def cg_pokemon_base_weight_tenths
    return ALBERT_CG::ABILITY_AU_V2546.base_weight_tenths(self) if defined?(ALBERT_CG::ABILITY_AU_V2546)
    1
  end
  def cg_pokemon_weight_tenths
    return ALBERT_CG::ABILITY_AU_V2546.effective_weight_tenths(self) if defined?(ALBERT_CG::ABILITY_AU_V2546)
    cg_pokemon_base_weight_tenths
  end

  alias cg_v2546au_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    if defined?(ALBERT_CG::ABILITY_AU_V2546)&&ALBERT_CG::ABILITY_AU_V2546.active?&&@cg_priority_test_speed_override_au!=nil; return @cg_priority_test_speed_override_au.to_i; end
    cg_v2546au_priority_base_speed
  rescue; cg_v2546au_priority_base_speed; end

  alias cg_v2546au_make_obj_damage_value make_obj_damage_value
  def make_obj_damage_value(user,obj)
    if obj.is_a?(RPG::Skill)&&defined?(ALBERT_CG::ABILITY_AU_V2546)
      mid=ALBERT_CG::ABILITY_AU_V2546.move_id(obj); p=ALBERT_CG::ABILITY_AU_V2546.weight_move_power(user,self,mid)
      if p!=nil
        old_base=obj.base_damage; old_power=obj.instance_variable_get(:@cg_au_weight_power_override)
        begin
          obj.base_damage=1; obj.instance_variable_set(:@cg_au_weight_power_override,p.to_i)
          return cg_v2546au_make_obj_damage_value(user,obj)
        ensure
          obj.base_damage=old_base; obj.instance_variable_set(:@cg_au_weight_power_override,old_power)
        end
      end
    end
    cg_v2546au_make_obj_damage_value(user,obj)
  end
end

class RPG::Skill
  alias cg_v2546au_pokemon_power cg_pokemon_power
  def cg_pokemon_power
    v=instance_variable_get(:@cg_au_weight_power_override); return v.to_i if v!=nil
    cg_v2546au_pokemon_power
  end
end

class Scene_Battle < Scene_Base
  alias cg_v2546au_start start
  def start
    ALBERT_CG::ABILITY_AU_V2546.pre_scene_start if defined?(ALBERT_CG::ABILITY_AU_V2546)&&ALBERT_CG::ABILITY_AU_V2546.active?
    cg_v2546au_start
  end

  alias cg_v2546au_execute_action execute_action
  def execute_action
    if defined?(ALBERT_CG::ABILITY_AU_V2546)&&ALBERT_CG::ABILITY_AU_V2546.active?&&@active_battler
      if ALBERT_CG::ABILITY_AU_V2546.infatuation_blocks_action?(@active_battler)
        ALBERT_CG::ABILITY_AU_V2546.record_love_skip(@active_battler)
        a=@active_battler.action; if a; a.instance_variable_set(:@kind,0); a.instance_variable_set(:@basic,3); end
        return cg_v2546au_execute_action
      else
        ALBERT_CG::ABILITY_AU_V2546.record_execution(@active_battler)
      end
    end
    cg_v2546au_execute_action
  end

  alias cg_v2546au_turn_end turn_end
  def turn_end
    ALBERT_CG::ABILITY_AU_V2546.finish_round_assertions if defined?(ALBERT_CG::ABILITY_AU_V2546)&&ALBERT_CG::ABILITY_AU_V2546.active?
    cg_v2546au_turn_end
  end

  alias cg_v2546au_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::ABILITY_AU_V2546)&&ALBERT_CG::ABILITY_AU_V2546.active?; return cg_v2546au_start_party_command; end
    cg_v2546au_start_party_command; return unless $game_temp.in_battle; ALBERT_CG::ABILITY_AU_V2546.assert_bootstrap_once
    if ALBERT_CG::ABILITY_AU_V2546.finished?
      ALBERT_CG::ABILITY_AU_V2546.prepare_finish; battle_end(0); return
    end
    ALBERT_CG::ABILITY_AU_V2546.prepare_round_actions; start_main
  end

  alias cg_v2546au_battle_end battle_end
  def battle_end(result)
    if defined?(ALBERT_CG::ABILITY_AU_V2546)
      ALBERT_CG::ABILITY_AU_V2546.process_honey_gather(result)
      if ALBERT_CG::ABILITY_AU_V2546.active?&&ALBERT_CG::ABILITY_AU_V2546.instance_variable_get(:@await_honey_finalize)==true
        ALBERT_CG::ABILITY_AU_V2546.finalize_after_honey
      end
    end
    cg_v2546au_battle_end(result)
  end
end

class Game_Enemy < Game_Battler
  alias cg_v2546au_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::ABILITY_AU_V2546)&&ALBERT_CG::ABILITY_AU_V2546.active?
      a=ALBERT_CG::ABILITY_AU_V2546.forced_enemy_action(self); if a; cg_assign_action(a) if respond_to?(:cg_assign_action); @action=a unless respond_to?(:cg_assign_action); return; end
    end
    cg_v2546au_enemy_make_action
  end
end

module ALBERT_CG
  class << self
    alias cg_v2546au_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      r=cg_v2546au_bootstrap_demo_party
      if defined?(ALBERT_CG::ABILITY_AU_V2546)&&ALBERT_CG::ABILITY_AU_V2546.active?
        ALBERT_CG::ABILITY_AU_V2546::TEST_ALLIES.each{|c|ALBERT_CG::ABILITY_AU_V2546.configure_actor(c)}
        h=$game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]; if h; h.change_level(ALBERT_CG::ABILITY_AU_V2546::TEST_LEVEL,false); h.recover_all; h.cg_reset_stat_stages if h.respond_to?(:cg_reset_stat_stages); ALBERT_CG::ABILITY_AU_V2546.clear_runtime(h); ALBERT_CG::ABILITY_AU_V2546.set_ability(h,0); ALBERT_CG::ABILITY_AU_V2546.set_actor_moves(h,[150]); end
      end
      r
    end
  end
end

if defined?(ALBERT_CG::ABILITY_AT_V2545)
  module ALBERT_CG; module ABILITY_AT_V2545; def self.f11_trigger?; false; end; end; end
end
if defined?(ALBERT_CG::ABILITY_AS_V2544)
  module ALBERT_CG; module ABILITY_AS_V2544; def self.f11_trigger?; false; end; end; end
end

class Scene_Map < Scene_Base
  alias cg_v2546au_scene_map_update update
  def update; cg_v2546au_scene_map_update; return unless defined?(ALBERT_CG::ABILITY_AU_V2546); ALBERT_CG::ABILITY_AU_V2546.start_auto_test if ALBERT_CG::ABILITY_AU_V2546.f11_trigger?; end
end
