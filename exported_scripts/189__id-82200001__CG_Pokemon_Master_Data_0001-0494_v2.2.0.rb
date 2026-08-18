# RMVX_SCRIPT_INDEX: 189
# RMVX_SCRIPT_ID: 82200001
# RMVX_SCRIPT_NAME: CG Pokemon Master Data 0001-0494 v2.2.0
# RMVX_SOURCE_SHA256: 5242f600aee3866c4b75bd317be76c6c459d4915ac679894856dbb3e0640215c

#==============================================================================
# ■ CG Pokemon Master Data 0001-0494 v2.2.0
#------------------------------------------------------------------------------
# 【用途】
#  將全國圖鑑 #0001～#0494 的物種資料一次整合進 CG Pet Battle Prototype。
#  本頁不等待 PMD 0027～0494 圖像完成，而先讓「資料、數值、技能池、特性池、
#  進化、性別、蛋群、AI 傾向與測試入口」全部可被遊戲查詢與驗證。
#
# 【資料基準】
#  - 物種名稱：繁體中文（PokeAPI zh-hant）。
#  - 種族值／屬性／性別率／捕捉率／成長率／蛋群／特性：PokeAPI Master Data。
#  - 等級技能與可學技能池：Ultra Sun / Ultra Moon（version_group_id = 18）。
#    原因：#0001～#0494 全數有完整資料，且已是 18 屬性環境，適合本專案基底。
#  - MOVE_CATALOG / ABILITY_CATALOG 同時保留完整資料索引，後續 v2.3 / v2.4
#    會把效果、PMD 專用動作與 Ability Trigger 逐項正式化。
#
# 【ID 規則】
#    Actor/Form ID = Dex + 99     (#0494 => Actor 593)
#    Enemy ID      = Dex + 599    (#0494 => Enemy 1093)
#    Pokémon Move Skill ID = Move ID + 1000
#  Skill 1001～1937 為 Pokémon Move 正式保留區；目前 v2.2 建立「可戰鬥 Stub」，
#  傷害類已能使用六維公式，但特殊效果仍由 v2.3 完成。
#
# 【PMD 素材缺圖規則】
#  正式資料永遠維持真正 Dex，不因測試圖像改變。
#  PMD 圖像：
#    1. 若 Graphics/PMDSprites/XXXX 存在，使用自己的 XXXX。
#    2. 若不存在，使用循環 fallback：
#         fallback = ((Dex - 1) % 26) + 1
#       例如 #0027 暫用 0001、#0052 暫用 0026、#0053 再用 0001。
#  因此 #0150 仍是超夢的種族值／屬性／技能／特性，只是測試 Sprite 暫借別隻。
#
# 【進化規則】
#  本專案正式採自動進化。
#  - 原作等級進化保留原等級。
#  - 道具／交換／親密度／地點／招式條件轉成自動等級門檻。
#  - 分支進化使用「個體隨機分支」，同一個體一旦選定便固定。
#  - 性別限定分支仍會先過濾性別。
#  - Nincada → Shedinja 保存為 BONUS_EVOLUTION，暫不當成主分支；後續生命週期
#    Phase 再實作「進化成 Ninjask 時額外生成 Shedinja」。
#
# 【天性／Nature】
#  每隻物種依六維定位產生 Nature Bias（偏物攻、偏特攻、坦克、速度等）。
#  新建立個體若沒有指定 Nature，會優先從該物種 Bias 抽選；仍保留 25 Nature。
#
# 【AI Profile】
#  每隻物種保存：
#    preferred_class  : physical / special / mixed
#    role             : attacker / sweeper / tank / support / balanced...
#    aggression       : 1～5
#    range_bias       : melee / ranged / hybrid
#  v2.6 Gamebit AI 會直接讀這些資料。
#
# 【技能與 PMD 連動】
#  v2.2 Skill Stub 已先保存 motion hint：
#    physical 預設 melee；special 預設 shoot；
#    自我／隊伍 Status 預設 pose；敵方 Status 預設 shoot。
#  v2.3 會逐招完成正式 Effect + PMD Motion + fallback chain + Species Override。
#  任何 PMD 動作缺失都必須由 CG_PMD::ACTION_FALLBACKS 解決，不允許報錯。
#
# 【Animation】
#  所有 v2.2 Move Stub 先使用 Animation ID 1。
#  後續可逐招替換，不影響技能機制。
#
# 【測試】
#  F10：啟動 Master Scenario。
#  TEST_ALLIES / TEST_ENEMIES 可直接指定：
#    :dex、:level、:ability（Ability ID）、:moves（原作 Move ID）。
#  F10 會自動換成 Actor/Enemy、套六維、指定技能與特性，缺 PMD 就 fallback。
#  測試結果輸出 Pokemon_MasterTest_v2_2.log。
#
# 【常用腳本呼叫】
#  ALBERT_CG::POKEMON_MASTER.entry(150)
#  ALBERT_CG::POKEMON_MASTER.base_stats_for_dex(150)
#  ALBERT_CG::POKEMON_MASTER.level_learnset(150)
#  ALBERT_CG::POKEMON_MASTER.move_pool(150)
#  ALBERT_CG::POKEMON_MASTER.ability_pool(150)
#  ALBERT_CG::POKEMON_MASTER.pmd_key_for_dex(150)
#  ALBERT_CG::POKEMON_MASTER.skill_id_for_move(94)  # Psychic
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonMasterData"] = "2.2.0"

module ALBERT_CG
  module POKEMON_MASTER
    VERSION = "2.2.0"
    DATA_SOURCE = "PokeAPI master / USUM version_group 18"
    LOG_FILE = "Pokemon_MasterData_v2_2.log"
    TEST_LOG_FILE = "Pokemon_MasterTest_v2_2.log"
    MAX_DEX = 494
    ACTOR_OFFSET = 99
    ENEMY_OFFSET = 599
    MOVE_SKILL_OFFSET = 1000
    GENERIC_CLASS_ID = 110
    TEST_TROOP_ID = 699
    PLACEHOLDER_ANIMATION_ID = 1
    FALLBACK_PMD_COUNT = 26

    # dex => [name, identifier, types, stats, root, depth, gender_rate, capture_rate, growth_rate, flags, egg_groups, abilities, hidden, nature_bias, ai, base_exp]
    SPECIES = {
      1=>["妙蛙種子","bulbasaur",[:grass,:poison],[45,49,49,65,65,45],1,0,1,45,4,0,[1,7],[65],[34],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],64],
      2=>["妙蛙草","ivysaur",[:grass,:poison],[60,62,63,80,80,60],1,1,1,45,4,0,[1,7],[65],[34],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],142],
      3=>["妙蛙花","venusaur",[:grass,:poison],[80,82,83,100,100,80],1,2,1,45,4,0,[1,7],[65],[34],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],236],
      4=>["小火龍","charmander",[:fire],[39,52,43,60,50,65],4,0,1,45,4,0,[1,14],[66],[94],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],62],
      5=>["火恐龍","charmeleon",[:fire],[58,64,58,80,65,80],4,1,1,45,4,0,[1,14],[66],[94],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],142],
      6=>["噴火龍","charizard",[:fire,:flying],[78,84,78,109,85,100],4,2,1,45,4,0,[1,14],[66],[94],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],240],
      7=>["傑尼龜","squirtle",[:water],[44,48,65,50,64,43],7,0,1,45,4,0,[1,2],[67],[44],[8,5,7,23,12],[:mixed,:tank,4,:hybrid],63],
      8=>["卡咪龜","wartortle",[:water],[59,63,80,65,80,58],7,1,1,45,4,0,[1,2],[67],[44],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],142],
      9=>["水箭龜","blastoise",[:water],[79,83,100,85,105,78],7,2,1,45,4,0,[1,2],[67],[44],[23,20,8,5,12],[:mixed,:balanced_mixed,5,:hybrid],239],
      10=>["綠毛蟲","caterpie",[:bug],[45,30,35,20,20,45],10,0,4,255,2,0,[3],[19],[50],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],39],
      11=>["鐵甲蛹","metapod",[:bug],[50,20,55,25,25,30],10,1,4,120,2,0,[3],[61],[],[8,5,7,23,12],[:special,:physical_tank,3,:ranged],72],
      12=>["巴大蝶","butterfree",[:bug,:flying],[60,45,50,90,80,70],10,2,4,45,2,0,[3],[14],[110],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],178],
      13=>["獨角蟲","weedle",[:bug,:poison],[40,35,30,20,20,50],13,0,4,255,2,0,[3],[19],[50],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],39],
      14=>["鐵殼蛹","kakuna",[:bug,:poison],[45,25,50,25,25,35],13,1,4,120,2,0,[3],[61],[],[8,5,7,23,12],[:mixed,:physical_tank,4,:hybrid],72],
      15=>["大針蜂","beedrill",[:bug,:poison],[65,90,40,45,80,75],13,2,4,45,2,0,[3],[68],[97],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],178],
      16=>["波波","pidgey",[:normal,:flying],[40,45,40,35,35,56],16,0,4,255,4,0,[4],[51,77],[145],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],50],
      17=>["比比鳥","pidgeotto",[:normal,:flying],[63,60,55,50,50,71],16,1,4,120,4,0,[4],[51,77],[145],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],122],
      18=>["大比鳥","pidgeot",[:normal,:flying],[83,80,75,70,70,101],16,2,4,45,4,0,[4],[51,77],[145],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],216],
      19=>["小拉達","rattata",[:normal],[30,56,35,25,35,72],19,0,4,255,2,0,[5],[50,62],[55],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],51],
      20=>["拉達","raticate",[:normal],[55,81,60,50,70,97],19,1,4,127,2,0,[5],[50,62],[55],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],145],
      21=>["烈雀","spearow",[:normal,:flying],[40,60,30,31,31,70],21,0,4,255,2,0,[4],[51],[97],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],52],
      22=>["大嘴雀","fearow",[:normal,:flying],[65,90,65,61,61,100],21,1,4,90,2,0,[4],[51],[97],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],155],
      23=>["阿柏蛇","ekans",[:poison],[35,60,44,40,54,55],23,0,4,255,2,0,[5,14],[22,61],[127],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],58],
      24=>["阿柏怪","arbok",[:poison],[60,95,69,65,79,80],23,1,4,90,2,0,[5,14],[22,61],[127],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],157],
      25=>["皮卡丘","pikachu",[:electric],[35,55,40,50,50,90],172,1,4,190,2,0,[5,6],[9],[31],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],112],
      26=>["雷丘","raichu",[:electric],[60,90,55,90,80,110],172,2,4,75,2,0,[5,6],[9],[31],[11,14,4,19,12],[:mixed,:mixed_sweeper,5,:hybrid],218],
      27=>["穿山鼠","sandshrew",[:ground],[50,75,85,20,30,40],27,0,4,255,2,0,[5],[8],[146],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],60],
      28=>["穿山王","sandslash",[:ground],[75,100,110,45,55,65],27,1,4,90,2,0,[5],[8],[146],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],158],
      29=>["尼多蘭","nidoran-f",[:poison],[55,47,52,40,40,41],29,0,8,235,4,0,[1,5],[38,79],[55],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],55],
      30=>["尼多娜","nidorina",[:poison],[70,62,67,55,55,56],29,1,8,120,4,0,[15],[38,79],[55],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],128],
      31=>["尼多后","nidoqueen",[:poison,:ground],[90,92,87,75,85,76],29,2,8,45,4,0,[15],[38,79],[125],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],227],
      32=>["尼多朗","nidoran-m",[:poison],[46,57,40,40,40,50],32,0,0,235,4,0,[1,5],[38,79],[55],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],55],
      33=>["尼多力諾","nidorino",[:poison],[61,72,57,55,55,65],32,1,0,120,4,0,[1,5],[38,79],[55],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],128],
      34=>["尼多王","nidoking",[:poison,:ground],[81,102,77,85,75,85],32,2,0,45,4,0,[1,5],[38,79],[125],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],227],
      35=>["皮皮","clefairy",[:fairy],[70,45,48,60,65,35],173,1,6,150,3,0,[6],[56,98],[132],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],113],
      36=>["皮可西","clefable",[:fairy],[95,70,73,95,90,60],173,2,6,25,3,0,[6],[56,98],[109],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],217],
      37=>["六尾","vulpix",[:fire],[38,41,40,50,65,65],37,0,6,190,2,0,[5],[18],[70],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],60],
      38=>["九尾","ninetales",[:fire],[73,76,75,81,100,100],37,1,6,75,2,0,[5],[18],[70],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],177],
      39=>["胖丁","jigglypuff",[:normal,:fairy],[115,45,20,45,25,20],174,1,6,170,3,0,[6],[56,172],[132],[23,20,22,5,12],[:mixed,:special_tank,3,:hybrid],95],
      40=>["胖可丁","wigglytuff",[:normal,:fairy],[140,70,45,85,50,45],174,2,6,50,3,0,[6],[56,172],[119],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],196],
      41=>["超音蝠","zubat",[:poison,:flying],[40,45,35,30,40,55],41,0,4,255,2,0,[4],[39],[151],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],49],
      42=>["大嘴蝠","golbat",[:poison,:flying],[75,80,70,65,75,90],41,1,4,90,2,0,[4],[39],[151],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],159],
      43=>["走路草","oddish",[:grass,:poison],[45,50,55,75,65,30],43,0,4,255,4,0,[7],[34],[50],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],64],
      44=>["臭臭花","gloom",[:grass,:poison],[60,65,70,85,75,40],43,1,4,120,4,0,[7],[34],[1],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],138],
      45=>["霸王花","vileplume",[:grass,:poison],[75,80,85,110,90,50],43,2,4,45,4,0,[7],[34],[27],[15,17,10,19,0],[:special,:special_attacker,5,:ranged],221],
      46=>["派拉斯","paras",[:bug,:grass],[35,70,55,45,55,25],46,0,4,190,2,0,[3,7],[27,87],[6],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],57],
      47=>["派拉斯特","parasect",[:bug,:grass],[60,95,80,60,80,30],46,1,4,75,2,0,[3,7],[27,87],[6],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],142],
      48=>["毛球","venonat",[:bug,:poison],[60,55,50,40,55,45],48,0,4,190,2,0,[3],[14,110],[50],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],61],
      49=>["摩魯蛾","venomoth",[:bug,:poison],[70,65,60,90,75,90],48,1,4,75,2,0,[3],[19,110],[147],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],158],
      50=>["地鼠","diglett",[:ground],[10,55,25,35,45,95],50,0,4,255,2,0,[5],[8,71],[159],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],53],
      51=>["三地鼠","dugtrio",[:ground],[35,100,50,50,70,120],50,1,4,50,2,0,[5],[8,71],[159],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],149],
      52=>["喵喵","meowth",[:normal],[40,45,35,40,40,90],52,0,4,255,2,0,[5],[53,101],[127],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],58],
      53=>["貓老大","persian",[:normal],[65,70,60,65,65,115],52,1,4,90,2,0,[5],[7,101],[127],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],154],
      54=>["可達鴨","psyduck",[:water],[50,52,48,65,50,55],54,0,4,190,2,0,[2,5],[6,13],[33],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],64],
      55=>["哥達鴨","golduck",[:water],[80,82,78,95,80,85],54,1,4,75,2,0,[2,5],[6,13],[33],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],175],
      56=>["猴怪","mankey",[:fighting],[40,80,35,35,45,70],56,0,4,190,2,0,[5],[72,83],[128],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],61],
      57=>["火爆猴","primeape",[:fighting],[65,105,60,60,70,95],56,1,4,75,2,0,[5],[72,83],[128],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],159],
      58=>["卡蒂狗","growlithe",[:fire],[55,70,45,70,50,60],58,0,2,190,1,0,[5],[22,18],[154],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],70],
      59=>["風速狗","arcanine",[:fire],[90,110,80,100,80,95],58,1,2,75,1,0,[5],[22,18],[154],[11,14,4,19,12],[:mixed,:mixed_sweeper,5,:hybrid],194],
      60=>["蚊香蝌蚪","poliwag",[:water],[40,50,40,40,40,90],60,0,4,255,4,0,[2],[11,6],[33],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],60],
      61=>["蚊香君","poliwhirl",[:water],[65,65,65,50,50,90],60,1,4,120,4,0,[2],[11,6],[33],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],135],
      62=>["蚊香泳士","poliwrath",[:water,:fighting],[90,95,95,70,90,70],60,2,4,45,4,0,[2],[11,6],[33],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],230],
      63=>["凱西","abra",[:psychic],[25,20,15,105,55,90],63,0,2,200,4,0,[8],[28,39],[98],[15,10,17,19,0],[:special,:special_attacker,5,:ranged],62],
      64=>["勇基拉","kadabra",[:psychic],[40,35,30,120,70,105],63,1,2,100,4,0,[8],[28,39],[98],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],140],
      65=>["胡地","alakazam",[:psychic],[55,50,45,135,95,120],63,2,2,50,4,0,[8],[28,39],[98],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],225],
      66=>["腕力","machop",[:fighting],[70,80,50,35,35,35],66,0,2,180,4,0,[8],[62,99],[80],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],61],
      67=>["豪力","machoke",[:fighting],[80,100,70,50,60,45],66,1,2,90,4,0,[8],[62,99],[80],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],142],
      68=>["怪力","machamp",[:fighting],[90,130,80,65,85,55],66,2,2,45,4,0,[8],[62,99],[80],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],227],
      69=>["喇叭芽","bellsprout",[:grass,:poison],[50,75,35,70,30,40],69,0,4,255,4,0,[7],[34],[82],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],60],
      70=>["口呆花","weepinbell",[:grass,:poison],[65,90,50,85,45,55],69,1,4,120,4,0,[7],[34],[82],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],137],
      71=>["大食花","victreebel",[:grass,:poison],[80,105,65,100,70,70],69,2,4,45,4,0,[7],[34],[82],[11,14,4,19,12],[:mixed,:mixed_attacker,5,:hybrid],221],
      72=>["瑪瑙水母","tentacool",[:water,:poison],[40,40,35,50,100,70],72,0,4,190,1,0,[9],[29,64],[44],[23,20,22,5,12],[:special,:special_tank,5,:ranged],67],
      73=>["毒刺水母","tentacruel",[:water,:poison],[80,70,65,80,120,100],72,1,4,60,1,0,[9],[29,64],[44],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],180],
      74=>["小拳石","geodude",[:rock,:ground],[40,80,100,30,30,20],74,0,4,255,4,0,[10],[69,5],[8],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],60],
      75=>["隆隆石","graveler",[:rock,:ground],[55,95,115,45,45,35],74,1,4,120,4,0,[10],[69,5],[8],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],137],
      76=>["隆隆岩","golem",[:rock,:ground],[80,120,130,55,65,45],74,2,4,45,4,0,[10],[69,5],[8],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],223],
      77=>["小火馬","ponyta",[:fire],[50,85,55,65,65,90],77,0,4,190,2,0,[5],[50,18],[49],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],82],
      78=>["烈焰馬","rapidash",[:fire],[65,100,70,80,80,105],77,1,4,60,2,0,[5],[50,18],[49],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],175],
      79=>["呆呆獸","slowpoke",[:water,:psychic],[90,65,65,40,40,15],79,0,4,190,2,0,[1,2],[12,20],[144],[3,2,13,4,0],[:physical,:balanced_physical,3,:melee],63],
      80=>["呆殼獸","slowbro",[:water,:psychic],[95,75,110,100,80,30],79,1,4,75,2,0,[1,2],[12,20],[144],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],172],
      81=>["小磁怪","magnemite",[:electric,:steel],[25,35,70,95,55,45],81,0,-1,190,2,0,[10],[42,5],[148],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],65],
      82=>["三合一磁怪","magneton",[:electric,:steel],[50,60,95,120,70,70],81,1,-1,60,2,0,[10],[42,5],[148],[15,17,10,19,0],[:special,:special_attacker,5,:ranged],163],
      83=>["大蔥鴨","farfetchd",[:normal,:flying],[52,90,55,58,62,60],83,0,4,45,2,0,[4,5],[51,39],[128],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],132],
      84=>["嘟嘟","doduo",[:normal,:flying],[35,85,45,35,35,75],84,0,4,190,2,0,[4],[50,48],[77],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],62],
      85=>["嘟嘟利","dodrio",[:normal,:flying],[60,110,70,60,60,110],84,1,4,45,2,0,[4],[50,48],[77],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],165],
      86=>["小海獅","seel",[:water],[65,45,55,45,70,45],86,0,4,190,2,0,[2,5],[47,93],[115],[23,20,22,5,12],[:mixed,:special_tank,4,:hybrid],65],
      87=>["白海獅","dewgong",[:water,:ice],[90,70,80,70,95,70],86,1,4,75,2,0,[2,5],[47,93],[115],[23,20,22,5,12],[:mixed,:special_tank,4,:hybrid],166],
      88=>["臭泥","grimer",[:poison],[80,80,50,40,50,25],88,0,4,190,2,0,[11],[1,60],[143],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],65],
      89=>["臭臭泥","muk",[:poison],[105,105,75,65,100,50],88,1,4,75,2,0,[11],[1,60],[143],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],175],
      90=>["大舌貝","shellder",[:water],[30,65,100,45,25,40],90,0,4,190,1,0,[9],[75,92],[142],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],61],
      91=>["刺甲貝","cloyster",[:water,:ice],[50,95,180,85,45,70],90,1,4,60,1,0,[9],[75,92],[142],[23,20,8,5,12],[:mixed,:balanced_mixed,5,:hybrid],184],
      92=>["鬼斯","gastly",[:ghost,:poison],[30,35,30,100,35,80],92,0,4,190,4,0,[11],[26],[],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],62],
      93=>["鬼斯通","haunter",[:ghost,:poison],[45,50,45,115,55,95],92,1,4,90,4,0,[11],[26],[],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],142],
      94=>["耿鬼","gengar",[:ghost,:poison],[60,65,60,130,75,110],92,2,4,45,4,0,[11],[130],[],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],225],
      95=>["大岩蛇","onix",[:rock,:ground],[35,45,160,30,45,70],95,0,4,45,2,0,[10],[69,5],[133],[8,5,7,23,12],[:physical,:physical_tank,4,:melee],77],
      96=>["催眠貘","drowzee",[:psychic],[60,48,45,43,90,42],96,0,4,190,2,0,[8],[15,108],[39],[23,20,22,5,12],[:mixed,:special_tank,4,:hybrid],66],
      97=>["引夢貘人","hypno",[:psychic],[85,73,70,73,115,67],96,1,4,75,2,0,[8],[15,108],[39],[23,20,22,5,12],[:mixed,:special_tank,4,:hybrid],169],
      98=>["大鉗蟹","krabby",[:water],[30,105,90,25,25,50],98,0,4,225,2,0,[9],[52,75],[125],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],65],
      99=>["巨鉗蟹","kingler",[:water],[55,130,115,50,50,75],98,1,4,60,2,0,[9],[52,75],[125],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],166],
      100=>["霹靂電球","voltorb",[:electric],[40,30,50,55,55,100],100,0,-1,190,2,0,[10],[43,9],[106],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],66],
      101=>["頑皮雷彈","electrode",[:electric],[60,50,70,80,80,150],100,1,-1,60,2,0,[10],[43,9],[106],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],172],
      102=>["蛋蛋","exeggcute",[:grass,:psychic],[60,40,80,60,45,40],102,0,4,90,1,0,[7],[34],[139],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],65],
      103=>["椰蛋樹","exeggutor",[:grass,:psychic],[95,95,85,125,75,55],102,1,4,45,1,0,[7],[34],[139],[15,17,10,19,0],[:special,:special_attacker,5,:ranged],186],
      104=>["卡拉卡拉","cubone",[:ground],[50,50,95,40,50,35],104,0,4,190,2,0,[1],[69,31],[4],[8,5,7,23,12],[:physical,:physical_tank,4,:melee],64],
      105=>["嘎啦嘎啦","marowak",[:ground],[60,80,110,50,80,45],104,1,4,75,2,0,[1],[69,31],[4],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],149],
      106=>["飛腿郎","hitmonlee",[:fighting],[50,120,53,35,110,87],236,1,0,45,2,0,[8],[7,120],[84],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],159],
      107=>["快拳郎","hitmonchan",[:fighting],[50,105,79,35,110,76],236,1,0,45,2,0,[8],[51,89],[39],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],159],
      108=>["大舌頭","lickitung",[:normal],[90,55,75,60,75,30],108,0,4,45,2,0,[1],[20,12],[13],[8,5,7,23,12],[:mixed,:tank,3,:hybrid],77],
      109=>["瓦斯彈","koffing",[:poison],[40,65,95,60,45,35],109,0,4,190,2,0,[11],[26,256],[1],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],68],
      110=>["雙彈瓦斯","weezing",[:poison],[65,90,120,85,70,60],109,1,4,60,2,0,[11],[26,256],[1],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],172],
      111=>["獨角犀牛","rhyhorn",[:ground,:rock],[80,85,95,30,30,25],111,0,4,120,1,0,[1,5],[31,69],[120],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],69],
      112=>["鑽角犀獸","rhydon",[:ground,:rock],[105,130,120,45,45,40],111,1,4,60,1,0,[1,5],[31,69],[120],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],170],
      113=>["吉利蛋","chansey",[:normal],[250,5,5,35,105,50],440,1,8,30,3,0,[6],[30,32],[131],[23,20,22,5,12],[:special,:special_tank,2,:ranged],395],
      114=>["蔓藤怪","tangela",[:grass],[65,55,115,100,40,60],114,0,4,45,2,0,[7],[34,102],[144],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],87],
      115=>["袋獸","kangaskhan",[:normal],[105,95,80,40,80,90],115,0,8,45,2,0,[1],[48,113],[39],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],172],
      116=>["墨海馬","horsea",[:water],[30,40,70,70,25,60],116,0,4,225,2,0,[2,14],[33,97],[6],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],59],
      117=>["海刺龍","seadra",[:water],[55,65,95,95,45,85],116,1,4,75,2,0,[2,14],[38,97],[6],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],154],
      118=>["角金魚","goldeen",[:water],[45,67,60,35,50,63],118,0,4,225,2,0,[12],[33,41],[31],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],64],
      119=>["金魚王","seaking",[:water],[80,92,65,65,80,68],118,1,4,60,2,0,[12],[33,41],[31],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],158],
      120=>["海星星","staryu",[:water],[30,45,55,70,55,85],120,0,-1,225,1,0,[9],[35,30],[148],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],68],
      121=>["寶石海星","starmie",[:water,:psychic],[60,75,85,100,85,115],120,1,-1,60,1,0,[9],[35,30],[148],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],182],
      122=>["魔牆人偶","mr-mime",[:psychic,:fairy],[40,45,65,100,120,90],439,1,4,45,2,0,[8],[43,111],[101],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],161],
      123=>["飛天螳螂","scyther",[:bug,:flying],[70,110,80,55,80,105],123,0,4,45,2,0,[3],[68,101],[80],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],100],
      124=>["迷唇姐","jynx",[:ice,:psychic],[65,50,35,115,95,95],238,1,8,45,2,0,[8],[12,108],[87],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],159],
      125=>["電擊獸","electabuzz",[:electric],[65,83,57,95,85,105],239,1,2,45,2,0,[8],[9],[72],[11,14,4,19,12],[:mixed,:mixed_sweeper,5,:hybrid],172],
      126=>["鴨嘴火獸","magmar",[:fire],[65,95,57,100,85,93],240,1,2,45,2,0,[8],[49],[72],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],173],
      127=>["凱羅斯","pinsir",[:bug],[65,125,100,55,70,85],127,0,4,45,1,0,[3],[52,104],[153],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],175],
      128=>["肯泰羅","tauros",[:normal],[75,100,95,40,70,110],128,0,0,45,1,0,[5],[22,83],[125],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],172],
      129=>["鯉魚王","magikarp",[:water],[20,10,55,15,20,80],129,0,4,255,1,0,[12,14],[33],[155],[8,5,7,23,12],[:special,:physical_tank,5,:ranged],40],
      130=>["暴鯉龍","gyarados",[:water,:flying],[95,125,79,60,100,81],129,1,4,45,1,0,[12,14],[22],[153],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],189],
      131=>["拉普拉斯","lapras",[:water,:ice],[130,85,80,85,95,60],131,0,4,45,1,0,[1,2],[11,75],[93],[23,20,22,5,12],[:mixed,:special_tank,4,:hybrid],187],
      132=>["百變怪","ditto",[:normal],[48,48,48,48,48,48],132,0,-1,35,2,0,[13],[7],[150],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],101],
      133=>["伊布","eevee",[:normal],[55,55,50,45,65,55],133,0,1,45,2,0,[5],[50,91],[107],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],65],
      134=>["水伊布","vaporeon",[:water],[130,65,60,110,95,65],133,1,1,45,2,0,[5],[11],[93],[15,17,10,19,0],[:special,:special_attacker,5,:ranged],184],
      135=>["雷伊布","jolteon",[:electric],[65,65,60,110,95,130],133,1,1,45,2,0,[5],[10],[95],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],184],
      136=>["火伊布","flareon",[:fire],[65,130,60,95,110,65],133,1,1,45,2,0,[5],[18],[62],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],184],
      137=>["多邊獸","porygon",[:normal],[65,60,70,85,75,40],137,0,-1,45,2,0,[10],[36,88],[148],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],79],
      138=>["菊石獸","omanyte",[:rock,:water],[35,40,100,90,55,35],138,0,1,45,2,0,[2,9],[33,75],[133],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],71],
      139=>["多刺菊石獸","omastar",[:rock,:water],[70,60,125,115,70,55],138,1,1,45,2,0,[2,9],[33,75],[133],[15,17,10,19,0],[:special,:special_attacker,5,:ranged],173],
      140=>["化石盔","kabuto",[:rock,:water],[30,80,90,55,45,55],140,0,1,45,2,0,[2,9],[33,4],[133],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],71],
      141=>["鐮刀盔","kabutops",[:rock,:water],[60,115,105,65,70,80],140,1,1,45,2,0,[2,9],[33,4],[133],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],173],
      142=>["化石翼龍","aerodactyl",[:rock,:flying],[80,105,65,60,75,130],142,0,1,45,1,0,[4],[69,46],[127],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],180],
      143=>["卡比獸","snorlax",[:normal],[160,110,65,65,110,30],446,1,1,25,1,0,[1],[17,47],[82],[3,2,13,4,0],[:physical,:physical_attacker,4,:melee],189],
      144=>["急凍鳥","articuno",[:ice,:flying],[90,85,100,95,125,85],144,0,-1,3,1,2,[15],[46],[81],[23,20,8,5,12],[:mixed,:balanced_mixed,5,:hybrid],261],
      145=>["閃電鳥","zapdos",[:electric,:flying],[90,90,85,125,90,100],145,0,-1,3,1,2,[15],[46],[9],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],261],
      146=>["火焰鳥","moltres",[:fire,:flying],[90,100,90,125,85,90],146,0,-1,3,1,2,[15],[46],[49],[15,10,17,19,0],[:special,:special_attacker,5,:ranged],261],
      147=>["迷你龍","dratini",[:dragon],[41,64,45,50,50,50],147,0,4,45,1,0,[2,14],[61],[63],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],60],
      148=>["哈克龍","dragonair",[:dragon],[61,84,65,70,70,70],147,1,4,45,1,0,[2,14],[61],[63],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],147],
      149=>["快龍","dragonite",[:dragon,:flying],[91,134,95,100,100,80],147,2,4,45,1,0,[2,14],[39],[136],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],270],
      150=>["超夢","mewtwo",[:psychic],[106,110,90,154,90,130],150,0,-1,3,1,2,[15],[46],[127],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],306],
      151=>["夢幻","mew",[:psychic],[100,100,100,100,100,100],151,0,-1,45,4,4,[15],[28],[],[23,20,8,5,12],[:mixed,:mixed_sweeper,5,:hybrid],270],
      152=>["菊草葉","chikorita",[:grass],[45,49,65,49,65,45],152,0,1,45,4,0,[1,7],[65],[102],[8,5,7,23,12],[:mixed,:tank,4,:hybrid],64],
      153=>["月桂葉","bayleef",[:grass],[60,62,80,63,80,60],152,1,1,45,4,0,[1,7],[65],[102],[8,5,7,23,12],[:mixed,:tank,4,:hybrid],142],
      154=>["大竺葵","meganium",[:grass],[80,82,100,83,100,80],152,2,1,45,4,0,[1,7],[65],[102],[23,20,8,5,12],[:mixed,:balanced_mixed,5,:hybrid],236],
      155=>["火球鼠","cyndaquil",[:fire],[39,52,43,60,50,65],155,0,1,45,4,0,[5],[66],[18],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],62],
      156=>["火岩鼠","quilava",[:fire],[58,64,58,80,65,80],155,1,1,45,4,0,[5],[66],[18],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],142],
      157=>["火爆獸","typhlosion",[:fire],[78,84,78,109,85,100],155,2,1,45,4,0,[5],[66],[18],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],240],
      158=>["小鋸鱷","totodile",[:water],[50,65,64,44,48,43],158,0,1,45,4,0,[1,2],[67],[125],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],63],
      159=>["藍鱷","croconaw",[:water],[65,80,80,59,63,58],158,1,1,45,4,0,[1,2],[67],[125],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],142],
      160=>["大力鱷","feraligatr",[:water],[85,105,100,79,83,78],158,2,1,45,4,0,[1,2],[67],[125],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],239],
      161=>["尾立","sentret",[:normal],[35,46,34,35,45,20],161,0,4,255,2,0,[5],[50,51],[119],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],43],
      162=>["大尾立","furret",[:normal],[85,76,64,45,55,90],161,1,4,90,2,0,[5],[50,51],[119],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],145],
      163=>["咕咕","hoothoot",[:normal,:flying],[60,30,30,36,56,50],163,0,4,255,2,0,[4],[15,51],[110],[23,20,22,5,12],[:special,:special_tank,4,:ranged],52],
      164=>["貓頭夜鷹","noctowl",[:normal,:flying],[100,50,50,86,96,70],163,1,4,90,2,0,[4],[15,51],[110],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],158],
      165=>["芭瓢蟲","ledyba",[:bug,:flying],[40,20,30,40,80,55],165,0,4,255,3,0,[3],[68,48],[155],[23,20,22,5,12],[:special,:special_tank,4,:ranged],53],
      166=>["安瓢蟲","ledian",[:bug,:flying],[55,35,50,55,110,85],165,1,4,90,3,0,[3],[68,48],[89],[23,20,22,5,12],[:special,:special_tank,5,:ranged],137],
      167=>["圓絲蛛","spinarak",[:bug,:poison],[40,60,40,40,40,30],167,0,4,255,3,0,[3],[68,15],[97],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],50],
      168=>["阿利多斯","ariados",[:bug,:poison],[70,90,70,60,70,40],167,1,4,90,3,0,[3],[68,15],[97],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],140],
      169=>["叉字蝠","crobat",[:poison,:flying],[85,90,80,70,80,130],41,2,4,90,2,0,[4],[39],[151],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],241],
      170=>["燈籠魚","chinchou",[:water,:electric],[75,38,38,56,56,67],170,0,4,190,1,0,[12],[10,35],[11],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],66],
      171=>["電燈怪","lanturn",[:water,:electric],[125,58,58,76,76,67],170,1,4,75,1,0,[12],[10,35],[11],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],161],
      172=>["皮丘","pichu",[:electric],[20,40,15,35,35,60],172,0,4,190,2,1,[15],[9],[31],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],41],
      173=>["皮寶寶","cleffa",[:fairy],[50,25,28,45,55,15],173,0,6,150,3,1,[15],[56,98],[132],[15,17,10,19,0],[:special,:balanced_special,3,:ranged],44],
      174=>["寶寶丁","igglybuff",[:normal,:fairy],[90,30,15,40,20,15],174,0,6,170,3,1,[15],[56,172],[132],[15,17,10,19,0],[:special,:balanced_special,3,:ranged],42],
      175=>["波克比","togepi",[:fairy],[35,20,65,40,65,20],175,0,1,190,3,1,[15],[55,32],[105],[8,5,7,23,12],[:special,:tank,3,:ranged],49],
      176=>["波克基古","togetic",[:fairy,:flying],[55,40,85,80,105,40],175,1,1,75,3,0,[4,6],[55,32],[105],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],142],
      177=>["天然雀","natu",[:psychic,:flying],[40,50,45,70,45,70],177,0,4,190,2,0,[4],[28,48],[156],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],64],
      178=>["天然鳥","xatu",[:psychic,:flying],[65,75,70,95,70,95],177,1,4,75,2,0,[4],[28,48],[156],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],165],
      179=>["咩利羊","mareep",[:electric],[55,40,40,65,45,35],179,0,4,235,4,0,[1,5],[9],[57],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],56],
      180=>["茸茸羊","flaaffy",[:electric],[70,55,55,80,60,45],179,1,4,120,4,0,[1,5],[9],[57],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],128],
      181=>["電龍","ampharos",[:electric],[90,75,85,115,90,55],179,2,4,45,4,0,[1,5],[9],[57],[15,17,10,19,0],[:special,:special_attacker,5,:ranged],230],
      182=>["美麗花","bellossom",[:grass],[75,80,95,90,100,50],43,2,4,45,4,0,[7],[34],[131],[23,20,8,5,12],[:mixed,:balanced_mixed,4,:hybrid],221],
      183=>["瑪力露","marill",[:water,:fairy],[70,20,50,20,50,40],298,1,4,190,3,0,[2,6],[47,37],[157],[8,5,7,23,12],[:mixed,:tank,3,:hybrid],88],
      184=>["瑪力露麗","azumarill",[:water,:fairy],[100,50,80,60,80,50],298,2,4,75,3,0,[2,6],[47,37],[157],[8,5,7,23,12],[:special,:tank,4,:ranged],189],
      185=>["樹才怪","sudowoodo",[:rock],[70,100,115,30,65,30],438,1,4,65,2,0,[10],[5,69],[155],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],144],
      186=>["蚊香蛙皇","politoed",[:water],[90,75,75,90,100,70],60,2,4,45,4,0,[2],[11,6],[2],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],225],
      187=>["毽子草","hoppip",[:grass,:flying],[35,35,40,35,55,50],187,0,4,255,4,0,[6,7],[34,102],[151],[23,20,22,5,12],[:mixed,:special_tank,4,:hybrid],50],
      188=>["毽子花","skiploom",[:grass,:flying],[55,45,50,45,65,80],187,1,4,120,4,0,[6,7],[34,102],[151],[23,20,22,5,12],[:mixed,:special_tank,5,:hybrid],119],
      189=>["毽子棉","jumpluff",[:grass,:flying],[75,55,70,55,95,110],187,2,4,45,4,0,[6,7],[34,102],[151],[23,20,22,5,12],[:mixed,:special_tank,5,:hybrid],207],
      190=>["長尾怪手","aipom",[:normal],[55,70,55,40,55,85],190,0,4,45,3,0,[5],[50,53],[92],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],72],
      191=>["向日種子","sunkern",[:grass],[30,30,30,30,30,30],191,0,4,235,4,0,[7],[34,94],[48],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],36],
      192=>["向日花怪","sunflora",[:grass],[75,75,55,105,85,30],191,1,4,120,4,0,[7],[34,94],[48],[15,17,10,19,0],[:special,:special_attacker,5,:ranged],149],
      193=>["蜻蜻蜓","yanma",[:bug,:flying],[65,65,45,75,45,95],193,0,4,75,2,0,[3],[3,14],[119],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],78],
      194=>["烏波","wooper",[:water,:ground],[55,45,45,25,25,15],194,0,4,255,2,0,[2,5],[6,11],[109],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],42],
      195=>["沼王","quagsire",[:water,:ground],[95,85,85,65,65,35],194,1,4,90,2,0,[2,5],[6,11],[109],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],151],
      196=>["太陽伊布","espeon",[:psychic],[65,65,60,130,95,110],133,1,1,45,2,0,[5],[28],[156],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],184],
      197=>["月亮伊布","umbreon",[:dark],[95,65,110,60,130,65],133,1,1,45,2,0,[5],[28],[39],[23,20,22,5,12],[:mixed,:special_tank,4,:hybrid],184],
      198=>["黑暗鴉","murkrow",[:dark,:flying],[60,85,42,85,42,91],198,0,4,30,4,0,[4],[15,105],[158],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],81],
      199=>["呆呆王","slowking",[:water,:psychic],[95,75,80,100,110,30],79,1,4,70,2,0,[1,2],[12,20],[144],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],172],
      200=>["夢妖","misdreavus",[:ghost],[60,60,60,85,85,85],200,0,4,45,3,0,[11],[26],[],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],87],
      201=>["未知圖騰","unown",[:psychic],[48,72,48,72,48,48],201,0,-1,225,2,0,[15],[26],[],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],118],
      202=>["果然翁","wobbuffet",[:psychic],[190,33,58,33,58,33],360,1,4,45,2,0,[11],[23],[140],[8,5,7,23,12],[:mixed,:tank,2,:hybrid],142],
      203=>["麒麟奇","girafarig",[:normal,:psychic],[70,80,65,90,65,85],203,0,4,60,2,0,[5],[39,48],[157],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],159],
      204=>["榛果球","pineco",[:bug],[50,65,90,35,35,15],204,0,4,190,2,0,[3],[5],[142],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],58],
      205=>["佛烈托斯","forretress",[:bug,:steel],[75,90,140,60,60,40],204,1,4,75,2,0,[3],[5],[142],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],163],
      206=>["土龍弟弟","dunsparce",[:normal],[100,70,70,65,65,45],206,0,4,190,2,0,[5],[32,50],[155],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],145],
      207=>["天蠍","gligar",[:ground,:flying],[65,75,105,35,65,85],207,0,4,60,4,0,[3],[52,8],[17],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],86],
      208=>["大鋼蛇","steelix",[:steel,:ground],[75,85,200,55,65,30],95,1,4,25,2,0,[10],[69,5],[125],[8,5,7,23,12],[:physical,:physical_tank,3,:melee],179],
      209=>["布魯","snubbull",[:fairy],[60,80,50,40,40,30],209,0,6,190,3,0,[5,6],[22,50],[155],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],60],
      210=>["布魯皇","granbull",[:fairy],[90,120,75,60,60,45],209,1,6,75,3,0,[5,6],[22,95],[155],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],158],
      211=>["千針魚","qwilfish",[:water,:poison],[65,95,85,55,55,85],211,0,4,45,2,0,[12],[38,33],[22],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],88],
      212=>["巨鉗螳螂","scizor",[:bug,:steel],[70,130,100,55,80,65],123,1,4,25,2,0,[3],[68,101],[135],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],175],
      213=>["壺壺","shuckle",[:bug,:rock],[20,10,230,10,230,5],213,0,4,190,4,0,[3],[5,82],[126],[8,5,7,23,12],[:mixed,:tank,1,:hybrid],177],
      214=>["赫拉克羅斯","heracross",[:bug,:fighting],[80,125,75,40,95,85],214,0,4,45,1,0,[3],[68,62],[153],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],175],
      215=>["狃拉","sneasel",[:dark,:ice],[55,95,55,35,75,115],215,0,4,60,4,0,[5],[39,51],[124],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],86],
      216=>["熊寶寶","teddiursa",[:normal],[60,80,50,50,50,40],216,0,4,120,2,0,[5],[53,95],[118],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],66],
      217=>["圈圈熊","ursaring",[:normal],[90,130,75,75,75,55],216,1,4,60,2,0,[5],[62,95],[127],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],175],
      218=>["熔岩蟲","slugma",[:fire],[40,40,40,70,40,20],218,0,4,190,2,0,[11],[40,49],[133],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],50],
      219=>["熔岩蝸牛","magcargo",[:fire,:rock],[60,50,120,90,80,30],218,1,4,75,2,0,[11],[40,49],[133],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],151],
      220=>["小山豬","swinub",[:ice,:ground],[50,50,40,30,30,50],220,0,4,225,1,0,[5],[12,81],[47],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],50],
      221=>["長毛豬","piloswine",[:ice,:ground],[100,100,80,60,60,50],220,1,4,75,1,0,[5],[12,81],[47],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],158],
      222=>["太陽珊瑚","corsola",[:water,:rock],[65,55,95,65,95,35],222,0,6,60,3,0,[2,9],[55,30],[144],[8,5,7,23,12],[:special,:tank,3,:ranged],144],
      223=>["鐵炮魚","remoraid",[:water],[35,65,35,65,35,65],223,0,4,190,2,0,[2,12],[55,97],[141],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],60],
      224=>["章魚桶","octillery",[:water],[75,105,75,105,75,45],223,1,4,75,2,0,[2,12],[21,97],[141],[11,14,4,19,12],[:mixed,:mixed_attacker,5,:hybrid],168],
      225=>["信使鳥","delibird",[:ice,:flying],[45,55,45,65,45,75],225,0,4,45,3,0,[2,5],[72,55],[15],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],116],
      226=>["巨翅飛魚","mantine",[:water,:flying],[85,40,70,80,140,70],458,1,4,25,1,0,[2],[33,11],[41],[23,20,22,5,12],[:special,:special_tank,4,:ranged],170],
      227=>["盔甲鳥","skarmory",[:steel,:flying],[65,80,140,40,70,70],227,0,4,25,1,0,[4],[51,5],[133],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],163],
      228=>["戴魯比","houndour",[:dark,:fire],[45,60,30,80,50,65],228,0,4,120,1,0,[5],[48,18],[127],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],66],
      229=>["黑魯加","houndoom",[:dark,:fire],[75,90,50,110,80,95],228,1,4,45,1,0,[5],[48,18],[127],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],175],
      230=>["刺龍王","kingdra",[:water,:dragon],[75,95,95,95,95,85],116,2,4,45,2,0,[2,14],[33,97],[6],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],243],
      231=>["小小象","phanpy",[:ground],[90,60,60,40,40,40],231,0,4,120,2,0,[5],[53],[8],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],66],
      232=>["頓甲","donphan",[:ground],[90,120,120,60,60,50],231,1,4,60,2,0,[5],[5],[8],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],175],
      233=>["多邊獸Ⅱ","porygon2",[:normal],[85,80,90,105,95,60],137,1,-1,45,2,0,[10],[36,88],[148],[15,17,10,19,0],[:special,:special_attacker,5,:ranged],180],
      234=>["驚角鹿","stantler",[:normal],[73,95,62,85,65,85],234,0,4,45,1,0,[5],[22,119],[157],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],163],
      235=>["圖圖犬","smeargle",[:normal],[55,20,35,20,45,75],235,0,4,45,3,0,[5],[20,101],[141],[23,20,22,5,12],[:mixed,:special_tank,4,:hybrid],88],
      236=>["無畏小子","tyrogue",[:fighting],[35,35,35,35,35,35],236,0,0,75,2,1,[15],[62,80],[72],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],42],
      237=>["戰舞郎","hitmontop",[:fighting],[50,95,95,35,110,70],236,1,0,45,2,0,[8],[22,101],[80],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],159],
      238=>["迷唇娃","smoochum",[:ice,:psychic],[45,30,15,85,65,65],238,0,8,45,2,1,[15],[12,108],[93],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],61],
      239=>["電擊怪","elekid",[:electric],[45,63,37,65,55,95],239,0,2,45,2,1,[15],[9],[72],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],72],
      240=>["鴨嘴寶寶","magby",[:fire],[45,75,37,70,55,83],240,0,2,45,2,1,[15],[49],[72],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],73],
      241=>["大奶罐","miltank",[:normal],[95,80,105,40,70,100],241,0,8,45,1,0,[5],[47,113],[157],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],172],
      242=>["幸福蛋","blissey",[:normal],[255,10,10,75,135,55],440,2,8,30,3,0,[6],[30,32],[131],[23,20,22,5,12],[:special,:special_tank,3,:ranged],608],
      243=>["雷公","raikou",[:electric],[90,85,75,115,100,115],243,0,-1,3,1,2,[15],[46],[39],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],261],
      244=>["炎帝","entei",[:fire],[115,115,85,90,75,100],244,0,-1,3,1,2,[15],[46],[39],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],261],
      245=>["水君","suicune",[:water],[100,75,115,90,115,85],245,0,-1,3,1,2,[15],[46],[39],[8,5,7,23,12],[:special,:tank,5,:ranged],261],
      246=>["幼基拉斯","larvitar",[:rock,:ground],[50,64,50,45,50,41],246,0,4,45,1,0,[1],[62],[8],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],60],
      247=>["沙基拉斯","pupitar",[:rock,:ground],[70,84,70,65,70,51],246,1,4,45,1,0,[1],[61],[],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],144],
      248=>["班基拉斯","tyranitar",[:rock,:dark],[100,134,110,95,100,61],246,2,4,45,1,0,[1],[45],[127],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],270],
      249=>["洛奇亞","lugia",[:psychic,:flying],[106,90,130,90,154,110],249,0,-1,3,1,2,[15],[46],[136],[23,20,22,5,12],[:mixed,:special_tank,5,:hybrid],306],
      250=>["鳳王","ho-oh",[:fire,:flying],[106,130,90,110,154,90],250,0,-1,3,1,2,[15],[46],[144],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],306],
      251=>["時拉比","celebi",[:psychic,:grass],[100,100,100,100,100,100],251,0,-1,45,4,4,[15],[30],[],[23,20,8,5,12],[:mixed,:mixed_sweeper,5,:hybrid],270],
      252=>["木守宮","treecko",[:grass],[40,45,35,65,55,70],252,0,1,45,4,0,[1,14],[65],[84],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],62],
      253=>["森林蜥蜴","grovyle",[:grass],[50,65,45,85,65,95],252,1,1,45,4,0,[1,14],[65],[84],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],142],
      254=>["蜥蜴王","sceptile",[:grass],[70,85,65,105,85,120],252,2,1,45,4,0,[1,14],[65],[84],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],239],
      255=>["火稚雞","torchic",[:fire],[45,60,40,70,50,45],255,0,1,45,4,0,[5],[66],[3],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],62],
      256=>["力壯雞","combusken",[:fire,:fighting],[60,85,60,85,60,55],255,1,1,45,4,0,[5],[66],[3],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],142],
      257=>["火焰雞","blaziken",[:fire,:fighting],[80,120,70,110,70,80],255,2,1,45,4,0,[5],[66],[3],[11,14,4,19,12],[:mixed,:mixed_attacker,5,:hybrid],239],
      258=>["水躍魚","mudkip",[:water],[50,70,50,50,50,40],258,0,1,45,4,0,[1,2],[67],[6],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],62],
      259=>["沼躍魚","marshtomp",[:water,:ground],[70,85,70,60,70,50],258,1,1,45,4,0,[1,2],[67],[6],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],142],
      260=>["巨沼怪","swampert",[:water,:ground],[100,110,90,85,90,60],258,2,1,45,4,0,[1,2],[67],[6],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],241],
      261=>["土狼犬","poochyena",[:dark],[35,55,35,30,30,35],261,0,4,255,2,0,[5],[50,95],[155],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],56],
      262=>["大狼犬","mightyena",[:dark],[70,90,70,60,60,70],261,1,4,127,2,0,[5],[22,95],[153],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],147],
      263=>["蛇紋熊","zigzagoon",[:normal],[38,30,41,30,41,60],263,0,4,255,2,0,[5],[53,82],[95],[8,5,7,23,12],[:mixed,:tank,4,:hybrid],56],
      264=>["直衝熊","linoone",[:normal],[78,70,61,50,61,100],263,1,4,90,2,0,[5],[53,82],[95],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],147],
      265=>["刺尾蟲","wurmple",[:bug],[45,45,35,20,30,20],265,0,4,255,2,0,[3],[19],[50],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],56],
      266=>["甲殼繭","silcoon",[:bug],[50,35,55,25,25,15],265,1,4,120,2,0,[3],[61],[],[8,5,7,23,12],[:physical,:physical_tank,3,:melee],72],
      267=>["狩獵鳳蝶","beautifly",[:bug,:flying],[60,70,50,100,50,65],265,2,4,45,2,0,[3],[68],[79],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],178],
      268=>["盾甲繭","cascoon",[:bug],[50,35,55,25,25,15],265,1,4,120,2,0,[3],[61],[],[8,5,7,23,12],[:physical,:physical_tank,3,:melee],72],
      269=>["毒粉蛾","dustox",[:bug,:poison],[60,50,70,50,90,65],265,2,4,45,2,0,[3],[19],[14],[23,20,22,5,12],[:mixed,:special_tank,4,:hybrid],173],
      270=>["蓮葉童子","lotad",[:water,:grass],[40,30,30,40,50,30],270,0,4,255,4,0,[2,7],[33,44],[20],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],44],
      271=>["蓮帽小童","lombre",[:water,:grass],[60,50,50,60,70,50],270,1,4,120,4,0,[2,7],[33,44],[20],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],119],
      272=>["樂天河童","ludicolo",[:water,:grass],[80,70,70,90,100,70],270,2,4,45,4,0,[2,7],[33,44],[20],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],216],
      273=>["橡實果","seedot",[:grass],[40,40,50,30,30,30],273,0,4,255,4,0,[5,7],[34,48],[124],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],44],
      274=>["長鼻葉","nuzleaf",[:grass,:dark],[70,70,40,60,40,60],273,1,4,120,4,0,[5,7],[34,48],[124],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],119],
      275=>["狡猾天狗","shiftry",[:grass,:dark],[90,100,60,90,60,80],273,2,4,45,4,0,[5,7],[34,274],[124],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],216],
      276=>["傲骨燕","taillow",[:normal,:flying],[40,55,30,30,30,85],276,0,4,200,4,0,[4],[62],[113],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],54],
      277=>["大王燕","swellow",[:normal,:flying],[60,85,60,75,50,125],276,1,4,45,4,0,[4],[62],[113],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],159],
      278=>["長翅鷗","wingull",[:water,:flying],[40,30,30,55,30,85],278,0,4,190,2,0,[2,4],[51,93],[44],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],54],
      279=>["大嘴鷗","pelipper",[:water,:flying],[60,50,100,95,70,65],278,1,4,45,2,0,[2,4],[51,2],[44],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],154],
      280=>["拉魯拉絲","ralts",[:psychic,:fairy],[28,25,25,45,35,40],280,0,4,235,1,0,[8,11],[28,36],[140],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],40],
      281=>["奇魯莉安","kirlia",[:psychic,:fairy],[38,35,35,65,55,50],280,1,4,120,1,0,[8,11],[28,36],[140],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],97],
      282=>["沙奈朵","gardevoir",[:psychic,:fairy],[68,65,65,125,115,80],280,2,4,45,1,0,[8,11],[28,36],[140],[15,10,17,19,0],[:special,:special_attacker,5,:ranged],233],
      283=>["溜溜糖球","surskit",[:bug,:water],[40,30,32,50,52,65],283,0,4,200,2,0,[2,3],[33],[44],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],54],
      284=>["雨翅蛾","masquerain",[:bug,:flying],[70,60,62,100,82,80],283,1,4,75,2,0,[2,3],[22],[127],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],159],
      285=>["蘑蘑菇","shroomish",[:grass],[60,40,60,40,60,35],285,0,4,255,6,0,[6,7],[27,90],[95],[8,5,7,23,12],[:mixed,:tank,3,:hybrid],59],
      286=>["斗笠菇","breloom",[:grass,:fighting],[60,130,80,60,60,70],285,1,4,90,6,0,[6,7],[27,90],[101],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],161],
      287=>["懶人獺","slakoth",[:normal],[60,60,60,35,35,30],287,0,4,255,1,0,[5],[54],[],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],56],
      288=>["過動猿","vigoroth",[:normal],[80,80,80,55,55,90],287,1,4,120,1,0,[5],[72],[],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],154],
      289=>["請假王","slaking",[:normal],[150,160,100,95,65,100],287,2,4,45,1,0,[5],[54],[],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],252],
      290=>["土居忍士","nincada",[:bug,:ground],[31,45,90,30,30,40],290,0,4,255,5,0,[3],[14],[50],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],53],
      291=>["鐵面忍者","ninjask",[:bug,:flying],[61,90,45,50,50,160],290,1,4,120,5,0,[3],[3],[151],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],160],
      292=>["脫殼忍者","shedinja",[:bug,:ghost],[1,90,45,30,30,40],290,1,-1,45,5,0,[10],[25],[],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],83],
      293=>["咕妞妞","whismur",[:normal],[64,51,23,51,23,28],293,0,4,190,4,0,[1,5],[43],[155],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],48],
      294=>["吼爆彈","loudred",[:normal],[84,71,43,71,43,48],293,1,4,120,4,0,[1,5],[43],[113],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],126],
      295=>["爆音怪","exploud",[:normal],[104,91,63,91,73,68],293,2,4,45,4,0,[1,5],[43],[113],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],221],
      296=>["幕下力士","makuhita",[:fighting],[72,60,30,20,30,25],296,0,2,180,6,0,[8],[47,62],[125],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],47],
      297=>["鐵掌力士","hariyama",[:fighting],[144,120,60,40,60,50],296,1,2,200,6,0,[8],[47,62],[125],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],166],
      298=>["露力麗","azurill",[:normal,:fairy],[50,20,40,20,40,20],298,0,6,150,3,1,[15],[47,37],[157],[8,5,7,23,12],[:mixed,:tank,3,:hybrid],38],
      299=>["朝北鼻","nosepass",[:rock],[30,45,135,45,90,30],299,0,4,255,2,0,[10],[5,42],[159],[8,5,7,23,12],[:mixed,:physical_tank,3,:hybrid],75],
      300=>["向尾喵","skitty",[:normal],[50,45,45,35,35,50],300,0,6,255,3,0,[5,6],[56,96],[147],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],52],
      301=>["優雅貓","delcatty",[:normal],[70,65,65,55,55,90],300,1,6,60,3,0,[5,6],[56,96],[147],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],140],
      302=>["勾魂眼","sableye",[:dark,:ghost],[50,75,75,65,65,50],302,0,4,45,4,0,[8],[51,100],[158],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],133],
      303=>["大嘴娃","mawile",[:steel,:fairy],[50,85,85,55,55,50],303,0,4,45,3,0,[5,6],[52,22],[125],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],133],
      304=>["可可多拉","aron",[:steel,:rock],[50,70,100,40,40,30],304,0,4,180,1,0,[1],[5,69],[134],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],66],
      305=>["可多拉","lairon",[:steel,:rock],[60,90,140,50,50,40],304,1,4,90,1,0,[1],[5,69],[134],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],151],
      306=>["波士可多拉","aggron",[:steel,:rock],[70,110,180,60,60,50],304,2,4,45,1,0,[1],[5,69],[134],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],239],
      307=>["瑪沙那","meditite",[:fighting,:psychic],[30,40,55,40,55,60],307,0,4,180,2,0,[8],[74],[140],[8,5,7,23,12],[:mixed,:tank,5,:hybrid],56],
      308=>["恰雷姆","medicham",[:fighting,:psychic],[60,60,75,60,75,80],307,1,4,90,2,0,[8],[74],[140],[8,5,7,23,12],[:mixed,:tank,5,:hybrid],144],
      309=>["落雷獸","electrike",[:electric],[40,45,40,65,40,65],309,0,4,120,1,0,[5],[9,31],[58],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],59],
      310=>["雷電獸","manectric",[:electric],[70,75,60,105,60,105],309,1,4,45,1,0,[5],[9,31],[58],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],166],
      311=>["正電拍拍","plusle",[:electric],[60,50,40,85,75,95],311,0,4,200,2,0,[6],[57],[31],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],142],
      312=>["負電拍拍","minun",[:electric],[60,40,50,75,85,95],312,0,4,200,2,0,[6],[58],[10],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],142],
      313=>["電螢蟲","volbeat",[:bug],[65,73,75,47,85,85],313,0,0,150,5,0,[3,8],[35,68],[158],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],151],
      314=>["甜甜螢","illumise",[:bug],[65,47,75,73,85,85],314,0,8,150,6,0,[3,8],[12,110],[158],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],151],
      315=>["毒薔薇","roselia",[:grass,:poison],[50,60,45,100,80,65],406,1,4,150,4,0,[6,7],[30,38],[102],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],140],
      316=>["溶食獸","gulpin",[:poison],[70,43,53,43,53,40],316,0,4,225,6,0,[11],[64,60],[82],[8,5,7,23,12],[:mixed,:tank,4,:hybrid],60],
      317=>["吞食獸","swalot",[:poison],[100,73,83,73,83,55],316,1,4,75,6,0,[11],[64,60],[82],[8,5,7,23,12],[:mixed,:tank,4,:hybrid],163],
      318=>["利牙魚","carvanha",[:water,:dark],[45,90,20,65,20,65],318,0,4,225,1,0,[12],[24],[3],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],61],
      319=>["巨牙鯊","sharpedo",[:water,:dark],[70,120,40,95,40,95],318,1,4,60,1,0,[12],[24],[3],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],161],
      320=>["吼吼鯨","wailmer",[:water],[130,70,35,70,35,60],320,0,4,125,6,0,[5,12],[41,12],[46],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],80],
      321=>["吼鯨王","wailord",[:water],[170,90,45,90,45,60],320,1,4,60,6,0,[5,12],[41,12],[46],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],175],
      322=>["呆火駝","numel",[:fire,:ground],[60,60,40,65,45,35],322,0,4,255,2,0,[5],[12,86],[20],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],61],
      323=>["噴火駝","camerupt",[:fire,:ground],[70,100,70,105,75,40],322,1,4,150,2,0,[5],[40,116],[83],[11,14,4,19,12],[:mixed,:mixed_attacker,5,:hybrid],161],
      324=>["煤炭龜","torkoal",[:fire],[70,85,140,85,70,20],324,0,4,90,2,0,[5],[73,70],[75],[23,20,8,5,12],[:mixed,:balanced_mixed,3,:hybrid],165],
      325=>["跳跳豬","spoink",[:psychic],[60,25,35,70,80,60],325,0,4,255,3,0,[5],[47,20],[82],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],66],
      326=>["噗噗豬","grumpig",[:psychic],[80,45,65,90,110,80],325,1,4,60,3,0,[5],[47,20],[82],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],165],
      327=>["晃晃斑","spinda",[:normal],[60,60,60,60,60,60],327,0,4,255,3,0,[5,8],[20,77],[126],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],126],
      328=>["大顎蟻","trapinch",[:ground],[45,100,45,45,45,10],328,0,4,255,4,0,[3,14],[52,71],[125],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],58],
      329=>["超音波幼蟲","vibrava",[:ground,:dragon],[50,70,50,50,50,70],328,1,4,120,4,0,[3,14],[26],[],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],119],
      330=>["沙漠蜻蜓","flygon",[:ground,:dragon],[80,100,80,80,80,100],328,2,4,45,4,0,[3,14],[26],[],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],234],
      331=>["刺球仙人掌","cacnea",[:grass],[50,85,40,85,40,35],331,0,4,190,4,0,[7,8],[8],[11],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],67],
      332=>["夢歌仙人掌","cacturne",[:grass,:dark],[70,115,60,115,60,55],331,1,4,60,4,0,[7,8],[8],[11],[11,14,4,19,12],[:mixed,:mixed_attacker,5,:hybrid],166],
      333=>["青綿鳥","swablu",[:normal,:flying],[45,40,60,40,75,50],333,0,4,255,5,0,[4,14],[30],[13],[23,20,22,5,12],[:mixed,:special_tank,4,:hybrid],62],
      334=>["七夕青鳥","altaria",[:dragon,:flying],[75,70,90,70,105,80],333,1,4,45,5,0,[4,14],[30],[13],[23,20,22,5,12],[:mixed,:special_tank,5,:hybrid],172],
      335=>["貓鼬斬","zangoose",[:normal],[73,115,60,60,60,90],335,0,4,90,5,0,[5],[17],[137],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],160],
      336=>["飯匙蛇","seviper",[:poison],[73,100,60,100,60,65],336,0,4,90,6,0,[5,14],[61],[151],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],160],
      337=>["月石","lunatone",[:rock,:psychic],[90,55,65,95,85,70],337,0,-1,45,3,0,[10],[26],[],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],161],
      338=>["太陽岩","solrock",[:rock,:psychic],[90,95,85,55,65,70],338,0,-1,45,3,0,[10],[26],[],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],161],
      339=>["泥泥鰍","barboach",[:water,:ground],[50,48,43,46,41,60],339,0,4,190,2,0,[12],[12,107],[93],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],58],
      340=>["鯰魚王","whiscash",[:water,:ground],[110,78,73,76,71,60],339,1,4,75,2,0,[12],[12,107],[93],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],164],
      341=>["龍蝦小兵","corphish",[:water],[43,80,65,50,35,35],341,0,4,205,6,0,[2,9],[52,75],[91],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],62],
      342=>["鐵螯龍蝦","crawdaunt",[:water,:dark],[63,120,85,90,55,55],341,1,4,155,6,0,[2,9],[52,75],[91],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],164],
      343=>["天秤偶","baltoy",[:ground,:psychic],[40,40,55,40,70,55],343,0,-1,255,2,0,[10],[26],[],[23,20,22,5,12],[:mixed,:special_tank,4,:hybrid],60],
      344=>["念力土偶","claydol",[:ground,:psychic],[60,70,105,70,120,75],343,1,-1,90,2,0,[10],[26],[],[8,5,7,23,12],[:mixed,:tank,4,:hybrid],175],
      345=>["觸手百合","lileep",[:rock,:grass],[66,41,77,61,87,23],345,0,1,45,5,0,[9],[21],[114],[8,5,7,23,12],[:special,:tank,3,:ranged],71],
      346=>["搖籃百合","cradily",[:rock,:grass],[86,81,97,81,107,43],345,1,1,45,5,0,[9],[21],[114],[8,5,7,23,12],[:mixed,:tank,4,:hybrid],173],
      347=>["太古羽蟲","anorith",[:rock,:bug],[45,95,50,40,50,75],347,0,1,45,5,0,[9],[4],[33],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],71],
      348=>["太古盔甲","armaldo",[:rock,:bug],[75,125,100,70,80,45],347,1,1,45,5,0,[9],[4],[33],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],173],
      349=>["醜醜魚","feebas",[:water],[20,15,20,10,55,80],349,0,4,255,5,0,[2,14],[33,12],[91],[23,20,22,5,12],[:physical,:special_tank,5,:melee],40],
      350=>["美納斯","milotic",[:water],[95,60,79,100,125,81],349,1,4,60,5,0,[2,14],[63,172],[56],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],189],
      351=>["飄浮泡泡","castform",[:normal],[70,70,70,70,70,70],351,0,4,45,2,0,[6,11],[59],[],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],147],
      352=>["變隱龍","kecleon",[:normal],[60,90,70,60,120,40],352,0,4,200,4,0,[5],[16],[168],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],154],
      353=>["怨影娃娃","shuppet",[:ghost],[44,75,35,63,33,45],353,0,4,225,3,0,[11],[15,119],[130],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],59],
      354=>["詛咒娃娃","banette",[:ghost],[64,115,65,83,63,65],353,1,4,45,3,0,[11],[15,119],[130],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],159],
      355=>["夜巡靈","duskull",[:ghost],[20,40,90,30,90,25],355,0,4,190,3,0,[11],[26],[119],[8,5,7,23,12],[:physical,:tank,3,:melee],59],
      356=>["彷徨夜靈","dusclops",[:ghost],[40,70,130,60,130,25],355,1,4,90,3,0,[11],[46],[119],[8,5,7,23,12],[:mixed,:tank,3,:hybrid],159],
      357=>["熱帶龍","tropius",[:grass,:flying],[99,68,83,72,87,51],357,0,4,200,1,0,[1,7],[34,94],[139],[8,5,7,23,12],[:mixed,:tank,4,:hybrid],161],
      358=>["風鈴鈴","chimecho",[:psychic],[75,50,80,95,90,65],433,1,4,45,3,0,[11],[26],[],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],159],
      359=>["阿勃梭魯","absol",[:dark],[65,130,60,75,60,75],359,0,4,30,4,0,[5],[46,105],[154],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],163],
      360=>["小果然","wynaut",[:psychic],[95,23,48,23,48,23],360,0,4,125,2,1,[15],[23],[140],[8,5,7,23,12],[:mixed,:tank,2,:hybrid],52],
      361=>["雪童子","snorunt",[:ice],[50,50,50,50,50,50],361,0,4,190,2,0,[6,10],[39,115],[141],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],60],
      362=>["冰鬼護","glalie",[:ice],[80,80,80,80,80,80],361,1,4,75,2,0,[6,10],[39,115],[141],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],168],
      363=>["海豹球","spheal",[:ice,:water],[70,40,50,55,50,25],363,0,4,255,4,0,[2,5],[47,115],[12],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],58],
      364=>["海魔獅","sealeo",[:ice,:water],[90,60,70,75,70,45],363,1,4,120,4,0,[2,5],[47,115],[12],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],144],
      365=>["帝牙海獅","walrein",[:ice,:water],[110,80,90,95,90,65],363,2,4,45,4,0,[2,5],[47,115],[12],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],239],
      366=>["珍珠貝","clamperl",[:water],[35,64,85,74,55,32],366,0,4,255,5,0,[2],[75],[155],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],69],
      367=>["獵斑魚","huntail",[:water],[55,104,105,94,75,52],366,1,4,60,5,0,[2],[33],[41],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],170],
      368=>["櫻花魚","gorebyss",[:water],[55,84,105,114,75,52],366,1,4,60,5,0,[2],[33],[93],[15,17,10,19,0],[:special,:special_attacker,5,:ranged],170],
      369=>["古空棘魚","relicanth",[:water,:rock],[100,90,130,45,65,55],369,0,1,25,1,0,[2,12],[33,69],[5],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],170],
      370=>["愛心魚","luvdisc",[:water],[43,30,55,40,65,97],370,0,6,225,3,0,[12],[33],[93],[23,20,22,5,12],[:special,:special_tank,5,:ranged],116],
      371=>["寶貝龍","bagon",[:dragon],[45,75,60,40,30,50],371,0,4,45,1,0,[14],[69],[125],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],60],
      372=>["甲殼龍","shelgon",[:dragon],[65,95,100,60,50,50],371,1,4,45,1,0,[14],[69],[142],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],147],
      373=>["暴飛龍","salamence",[:dragon,:flying],[95,135,80,110,80,100],371,2,4,45,1,0,[14],[22],[153],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],270],
      374=>["鐵啞鈴","beldum",[:steel,:psychic],[40,55,80,35,60,30],374,0,-1,3,1,0,[10],[29],[135],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],60],
      375=>["金屬怪","metang",[:steel,:psychic],[60,75,100,55,80,50],374,1,-1,3,1,0,[10],[29],[135],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],147],
      376=>["巨金怪","metagross",[:steel,:psychic],[80,135,130,95,90,70],374,2,-1,3,1,0,[10],[29],[135],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],270],
      377=>["雷吉洛克","regirock",[:rock],[80,100,200,50,100,50],377,0,-1,3,1,2,[15],[29],[5],[8,5,7,23,12],[:physical,:physical_tank,4,:melee],261],
      378=>["雷吉艾斯","regice",[:ice],[80,50,100,100,200,50],378,0,-1,3,1,2,[15],[29],[115],[23,20,22,5,12],[:special,:special_tank,4,:ranged],261],
      379=>["雷吉斯奇魯","registeel",[:steel],[80,75,150,75,150,50],379,0,-1,3,1,2,[15],[29],[135],[8,5,7,23,12],[:mixed,:tank,3,:hybrid],261],
      380=>["拉帝亞斯","latias",[:dragon,:psychic],[80,80,90,110,130,110],380,0,8,3,1,2,[15],[26],[],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],270],
      381=>["拉帝歐斯","latios",[:dragon,:psychic],[80,90,80,130,110,110],381,0,0,3,1,2,[15],[26],[],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],270],
      382=>["蓋歐卡","kyogre",[:water],[100,100,90,150,140,90],382,0,-1,3,1,2,[15],[2],[],[15,10,17,19,0],[:special,:special_attacker,5,:ranged],302],
      383=>["固拉多","groudon",[:ground],[100,150,140,100,90,90],383,0,-1,3,1,2,[15],[70],[],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],302],
      384=>["烈空坐","rayquaza",[:dragon,:flying],[105,150,90,150,90,95],384,0,-1,45,1,2,[15],[76],[],[23,20,8,5,12],[:mixed,:mixed_sweeper,5,:hybrid],306],
      385=>["基拉祈","jirachi",[:steel,:psychic],[100,100,100,100,100,100],385,0,-1,3,1,4,[15],[32],[],[23,20,8,5,12],[:mixed,:mixed_sweeper,5,:hybrid],270],
      386=>["代歐奇希斯","deoxys",[:psychic],[50,150,50,150,50,150],386,0,-1,3,1,4,[15],[46],[],[11,14,4,19,12],[:mixed,:mixed_sweeper,5,:hybrid],270],
      387=>["草苗龜","turtwig",[:grass],[55,68,64,45,55,31],387,0,1,45,4,0,[1,7],[65],[75],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],64],
      388=>["樹林龜","grotle",[:grass],[75,89,85,55,65,36],387,1,1,45,4,0,[1,7],[65],[75],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],142],
      389=>["土台龜","torterra",[:grass,:ground],[95,109,105,75,85,56],387,2,1,45,4,0,[1,7],[65],[75],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],236],
      390=>["小火焰猴","chimchar",[:fire],[44,58,44,58,44,61],390,0,1,45,4,0,[5,8],[66],[89],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],62],
      391=>["猛火猴","monferno",[:fire,:fighting],[64,78,52,78,52,81],390,1,1,45,4,0,[5,8],[66],[89],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],142],
      392=>["烈焰猴","infernape",[:fire,:fighting],[76,104,71,104,71,108],390,2,1,45,4,0,[5,8],[66],[89],[11,14,4,19,12],[:mixed,:mixed_sweeper,5,:hybrid],240],
      393=>["波加曼","piplup",[:water],[53,51,53,61,56,40],393,0,1,45,4,0,[2,5],[67],[172],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],63],
      394=>["波皇子","prinplup",[:water],[64,66,68,81,76,50],393,1,1,45,4,0,[2,5],[67],[172],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],142],
      395=>["帝王拿波","empoleon",[:water,:steel],[84,86,88,111,101,60],393,2,1,45,4,0,[2,5],[67],[172],[15,17,10,19,0],[:special,:special_attacker,5,:ranged],239],
      396=>["姆克兒","starly",[:normal,:flying],[40,55,30,30,30,60],396,0,4,255,4,0,[4],[51],[120],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],49],
      397=>["姆克鳥","staravia",[:normal,:flying],[55,75,50,40,40,80],396,1,4,120,4,0,[4],[22],[120],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],119],
      398=>["姆克鷹","staraptor",[:normal,:flying],[85,120,70,50,60,100],396,2,4,45,4,0,[4],[22],[120],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],218],
      399=>["大牙狸","bidoof",[:normal],[59,45,40,35,40,31],399,0,4,255,2,0,[2,5],[86,109],[141],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],50],
      400=>["大尾狸","bibarel",[:normal,:water],[79,85,60,55,60,71],399,1,4,127,2,0,[2,5],[86,109],[141],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],144],
      401=>["圓法師","kricketot",[:bug],[37,25,41,25,41,25],401,0,4,255,4,0,[3],[61],[50],[8,5,7,23,12],[:mixed,:tank,3,:hybrid],39],
      402=>["音箱蟀","kricketune",[:bug],[77,85,51,55,51,65],401,1,4,45,4,0,[3],[68],[101],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],134],
      403=>["小貓怪","shinx",[:electric],[45,65,34,40,34,45],403,0,4,235,4,0,[5],[79,22],[62],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],53],
      404=>["勒克貓","luxio",[:electric],[60,85,49,60,49,60],403,1,4,120,4,0,[5],[79,22],[62],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],127],
      405=>["倫琴貓","luxray",[:electric],[80,120,79,95,79,70],403,2,4,45,4,0,[5],[79,22],[62],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],235],
      406=>["含羞苞","budew",[:grass,:poison],[40,30,35,50,70,55],406,0,4,255,4,1,[15],[30,38],[102],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],56],
      407=>["羅絲雷朵","roserade",[:grass,:poison],[60,70,65,125,105,90],406,2,4,75,4,0,[6,7],[30,38],[101],[15,10,17,19,0],[:special,:special_attacker,5,:ranged],232],
      408=>["頭蓋龍","cranidos",[:rock],[67,125,40,30,30,58],408,0,1,45,5,0,[1],[104],[125],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],70],
      409=>["戰槌龍","rampardos",[:rock],[97,165,60,65,50,58],408,1,1,45,5,0,[1],[104],[125],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],173],
      410=>["盾甲龍","shieldon",[:rock,:steel],[30,42,118,42,88,30],410,0,1,45,5,0,[1],[5],[43],[8,5,7,23,12],[:mixed,:physical_tank,3,:hybrid],70],
      411=>["護城龍","bastiodon",[:rock,:steel],[60,52,168,47,138,30],410,1,1,45,5,0,[1],[5],[43],[8,5,7,23,12],[:mixed,:physical_tank,2,:hybrid],173],
      412=>["結草兒","burmy",[:bug],[40,29,45,29,45,36],412,0,4,120,2,0,[3],[61],[142],[8,5,7,23,12],[:mixed,:tank,4,:hybrid],45],
      413=>["結草貴婦","wormadam",[:bug,:grass],[60,59,85,79,105,36],412,1,8,45,2,0,[3],[107],[142],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],148],
      414=>["紳士蛾","mothim",[:bug,:flying],[70,94,50,94,50,66],412,1,0,45,2,0,[3],[68],[110],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],148],
      415=>["三蜜蜂","combee",[:bug,:flying],[30,30,42,30,42,70],415,0,1,120,4,0,[3],[118],[55],[8,5,7,23,12],[:mixed,:tank,5,:hybrid],49],
      416=>["蜂女王","vespiquen",[:bug,:flying],[70,80,102,80,102,40],415,1,8,45,4,0,[3],[46],[127],[23,20,8,5,12],[:mixed,:balanced_mixed,4,:hybrid],166],
      417=>["帕奇利茲","pachirisu",[:electric],[60,45,70,45,90,95],417,0,4,200,2,0,[5,6],[50,53],[10],[23,20,22,5,12],[:mixed,:special_tank,5,:hybrid],142],
      418=>["泳圈鼬","buizel",[:water],[55,65,35,60,30,85],418,0,4,190,2,0,[2,5],[33],[41],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],66],
      419=>["浮潛鼬","floatzel",[:water],[85,105,55,85,50,115],418,1,4,75,2,0,[2,5],[33],[41],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],173],
      420=>["櫻花寶","cherubi",[:grass],[45,35,45,62,53,35],420,0,4,190,2,0,[6,7],[34],[],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],55],
      421=>["櫻花兒","cherrim",[:grass],[70,60,70,87,78,85],420,1,4,75,2,0,[6,7],[122],[],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],158],
      422=>["無殼海兔","shellos",[:water],[76,48,48,57,62,34],422,0,4,190,2,0,[2,11],[60,114],[159],[15,17,10,19,0],[:special,:balanced_special,4,:ranged],65],
      423=>["海兔獸","gastrodon",[:water,:ground],[111,83,68,92,82,39],422,1,4,75,2,0,[2,11],[60,114],[159],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],166],
      424=>["雙尾怪手","ambipom",[:normal],[75,100,66,60,66,115],190,1,4,45,3,0,[5],[101,53],[92],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],169],
      425=>["飄飄球","drifloon",[:ghost,:flying],[90,50,34,60,44,70],425,0,4,125,6,0,[11],[106,84],[138],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],70],
      426=>["隨風球","drifblim",[:ghost,:flying],[150,80,44,90,54,80],425,1,4,60,6,0,[11],[106,84],[138],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],174],
      427=>["捲捲耳","buneary",[:normal],[55,66,44,44,56,85],427,0,4,190,2,0,[5,8],[50,103],[7],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],70],
      428=>["長耳兔","lopunny",[:normal],[65,76,84,54,96,105],427,1,4,60,2,0,[5,8],[56,103],[7],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],168],
      429=>["夢妖魔","mismagius",[:ghost],[60,60,60,105,105,105],200,1,4,45,3,0,[11],[26],[],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],173],
      430=>["烏鴉頭頭","honchkrow",[:dark,:flying],[100,125,52,105,52,71],198,1,4,30,4,0,[4],[15,105],[153],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],177],
      431=>["魅力喵","glameow",[:normal],[49,55,42,42,37,85],431,0,6,190,3,0,[5],[7,20],[51],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],62],
      432=>["東施喵","purugly",[:normal],[71,82,64,64,59,112],431,1,6,75,3,0,[5],[47,20],[128],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],158],
      433=>["鈴鐺響","chingling",[:psychic],[45,30,50,65,50,45],433,0,4,120,3,1,[15],[26],[],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],57],
      434=>["臭鼬噗","stunky",[:poison,:dark],[63,63,47,41,41,74],434,0,4,225,2,0,[5],[1,106],[51],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],66],
      435=>["坦克臭鼬","skuntank",[:poison,:dark],[103,93,67,71,61,84],434,1,4,60,2,0,[5],[1,106],[51],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],168],
      436=>["銅鏡怪","bronzor",[:steel,:psychic],[57,24,86,24,86,23],436,0,-1,255,2,0,[10],[26,85],[134],[8,5,7,23,12],[:mixed,:tank,2,:hybrid],60],
      437=>["青銅鐘","bronzong",[:steel,:psychic],[67,89,116,79,116,33],436,1,-1,90,2,0,[10],[26,85],[134],[23,20,8,5,12],[:mixed,:balanced_mixed,4,:hybrid],175],
      438=>["盆才怪","bonsly",[:rock],[50,80,95,10,45,10],438,0,4,255,2,1,[15],[5,69],[155],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],58],
      439=>["魔尼尼","mime-jr",[:psychic,:fairy],[20,25,45,70,90,60],439,0,4,145,2,1,[15],[43,111],[101],[15,17,10,19,0],[:special,:balanced_special,5,:ranged],62],
      440=>["小福蛋","happiny",[:normal],[100,5,5,15,65,30],440,0,8,130,3,1,[15],[30,32],[132],[23,20,22,5,12],[:special,:special_tank,3,:ranged],110],
      441=>["聒噪鳥","chatot",[:normal,:flying],[76,65,45,92,42,91],441,0,4,30,4,0,[4],[51,77],[145],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],144],
      442=>["花岩怪","spiritomb",[:ghost,:dark],[50,92,108,92,108,35],442,0,4,100,2,0,[11],[46],[151],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],170],
      443=>["圓陸鯊","gible",[:dragon,:ground],[58,70,45,40,45,42],443,0,4,45,1,0,[1,14],[8],[24],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],60],
      444=>["尖牙陸鯊","gabite",[:dragon,:ground],[68,90,65,50,55,82],443,1,4,45,1,0,[1,14],[8],[24],[3,13,2,4,0],[:physical,:balanced_physical,5,:melee],144],
      445=>["烈咬陸鯊","garchomp",[:dragon,:ground],[108,130,95,80,85,102],443,2,4,45,1,0,[1,14],[8],[24],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],270],
      446=>["小卡比獸","munchlax",[:normal],[135,85,40,40,85,5],446,0,1,50,1,1,[15],[53,47],[82],[3,2,13,4,0],[:physical,:balanced_physical,3,:melee],78],
      447=>["利歐路","riolu",[:fighting],[40,70,40,35,40,60],447,0,1,75,4,1,[15],[80,39],[158],[3,2,13,4,0],[:physical,:balanced_physical,5,:melee],57],
      448=>["路卡利歐","lucario",[:fighting,:steel],[70,110,70,115,70,90],447,1,1,45,4,0,[5,8],[80,39],[154],[11,14,4,19,12],[:mixed,:mixed_attacker,5,:hybrid],184],
      449=>["沙河馬","hippopotas",[:ground],[68,72,78,38,42,32],449,0,4,140,1,0,[5],[45],[159],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],66],
      450=>["河馬獸","hippowdon",[:ground],[108,112,118,68,72,47],449,1,4,60,1,0,[5],[45],[159],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],184],
      451=>["鉗尾蠍","skorupi",[:poison,:bug],[40,50,90,30,55,65],451,0,4,120,1,0,[3,9],[4,97],[51],[8,5,7,23,12],[:physical,:physical_tank,5,:melee],66],
      452=>["龍王蠍","drapion",[:poison,:dark],[70,90,110,60,75,95],451,1,4,45,1,0,[3,9],[4,97],[51],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],175],
      453=>["不良蛙","croagunk",[:poison,:fighting],[48,61,40,61,40,50],453,0,4,140,2,0,[8],[107,87],[143],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],60],
      454=>["毒骷蛙","toxicroak",[:poison,:fighting],[83,106,65,86,65,85],453,1,4,75,2,0,[8],[107,87],[143],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],172],
      455=>["尖牙籠","carnivine",[:grass],[74,100,72,90,72,46],455,0,4,200,1,0,[7],[26],[],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],159],
      456=>["螢光魚","finneon",[:water],[49,49,56,49,61,66],456,0,4,190,5,0,[12],[33,114],[41],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],66],
      457=>["霓虹魚","lumineon",[:water],[69,69,76,69,86,91],456,1,4,75,5,0,[12],[33,114],[41],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],161],
      458=>["小球飛魚","mantyke",[:water,:flying],[45,20,50,60,120,50],458,0,4,25,1,1,[15],[33,11],[41],[23,20,22,5,12],[:special,:special_tank,4,:ranged],69],
      459=>["雪笠怪","snover",[:grass,:ice],[60,62,50,62,60,40],459,0,4,120,1,0,[1,7],[117],[43],[11,14,4,19,12],[:mixed,:balanced_mixed,4,:hybrid],67],
      460=>["暴雪王","abomasnow",[:grass,:ice],[90,92,75,92,85,60],459,1,4,60,1,0,[1,7],[117],[43],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],173],
      461=>["瑪狃拉","weavile",[:dark,:ice],[70,120,65,45,85,125],215,1,4,45,4,0,[5],[46],[124],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],179],
      462=>["自爆磁怪","magnezone",[:electric,:steel],[70,70,115,130,90,60],81,2,-1,30,2,0,[10],[42,5],[148],[15,17,10,19,0],[:special,:special_attacker,5,:ranged],241],
      463=>["大舌舔","lickilicky",[:normal],[110,85,95,80,95,50],108,1,4,30,2,0,[1],[20,12],[13],[8,5,7,23,12],[:mixed,:tank,4,:hybrid],180],
      464=>["超甲狂犀","rhyperior",[:ground,:rock],[115,140,130,55,55,40],111,2,4,30,1,0,[1,5],[31,116],[120],[3,2,13,4,0],[:physical,:physical_attacker,5,:melee],241],
      465=>["巨蔓藤","tangrowth",[:grass],[100,100,125,110,50,50],114,1,4,30,2,0,[7],[34,102],[144],[23,20,8,5,12],[:mixed,:mixed_attacker,5,:hybrid],187],
      466=>["電擊魔獸","electivire",[:electric],[75,123,67,95,85,95],239,2,2,30,2,0,[8],[78],[72],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],243],
      467=>["鴨嘴炎獸","magmortar",[:fire],[75,95,67,125,95,83],240,2,2,30,2,0,[8],[49],[72],[15,10,17,19,0],[:special,:special_attacker,5,:ranged],243],
      468=>["波克基斯","togekiss",[:fairy,:flying],[85,50,95,120,115,80],175,2,1,30,3,0,[4,6],[55,32],[105],[15,10,17,19,0],[:special,:special_attacker,5,:ranged],245],
      469=>["遠古巨蜓","yanmega",[:bug,:flying],[86,76,86,116,56,95],193,1,4,30,2,0,[3],[3,110],[119],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],180],
      470=>["葉伊布","leafeon",[:grass],[65,110,130,60,65,95],133,1,1,45,2,0,[5],[102],[34],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],184],
      471=>["冰伊布","glaceon",[:ice],[65,60,110,130,95,65],133,1,1,45,2,0,[5],[81],[115],[15,17,10,19,0],[:special,:special_attacker,5,:ranged],184],
      472=>["天蠍王","gliscor",[:ground,:flying],[75,95,125,45,75,95],207,1,4,30,4,0,[3],[52,8],[90],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],179],
      473=>["象牙豬","mamoswine",[:ice,:ground],[110,130,80,70,60,80],220,2,4,50,1,0,[5],[12,81],[47],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],239],
      474=>["多邊獸Ｚ","porygon-z",[:normal],[85,80,70,135,75,90],137,2,-1,30,2,0,[10],[91,88],[148],[15,10,17,19,0],[:special,:special_attacker,5,:ranged],241],
      475=>["艾路雷朵","gallade",[:psychic,:fighting],[68,125,65,65,115,80],280,2,0,45,1,0,[8,11],[80,292],[154],[3,13,2,4,0],[:physical,:physical_attacker,5,:melee],233],
      476=>["大朝北鼻","probopass",[:rock,:steel],[60,55,145,75,150,40],299,1,4,60,2,0,[10],[5,42],[159],[8,5,7,23,12],[:special,:tank,3,:ranged],184],
      477=>["黑夜魔靈","dusknoir",[:ghost],[45,100,135,65,135,45],355,2,4,45,3,0,[11],[46],[119],[3,2,13,4,0],[:physical,:balanced_physical,4,:melee],236],
      478=>["雪妖女","froslass",[:ice,:ghost],[70,80,70,80,70,110],361,1,8,75,2,0,[6,10],[81],[130],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],168],
      479=>["洛托姆","rotom",[:electric,:ghost],[50,50,77,95,77,91],479,0,-1,45,2,0,[11],[26],[],[15,10,17,19,0],[:special,:balanced_special,5,:ranged],154],
      480=>["由克希","uxie",[:psychic],[75,75,130,75,130,95],480,0,-1,3,1,2,[15],[26],[],[8,5,7,23,12],[:mixed,:tank,5,:hybrid],261],
      481=>["艾姆利多","mesprit",[:psychic],[80,105,105,105,105,80],481,0,-1,3,1,2,[15],[26],[],[23,20,8,5,12],[:mixed,:mixed_attacker,5,:hybrid],261],
      482=>["亞克諾姆","azelf",[:psychic],[75,125,70,125,70,115],482,0,-1,3,1,2,[15],[26],[],[11,14,4,19,12],[:mixed,:mixed_sweeper,5,:hybrid],261],
      483=>["帝牙盧卡","dialga",[:steel,:dragon],[100,120,120,150,100,90],483,0,-1,3,1,2,[15],[46],[140],[15,10,17,19,0],[:special,:special_attacker,5,:ranged],306],
      484=>["帕路奇亞","palkia",[:water,:dragon],[90,120,100,150,120,100],484,0,-1,3,1,2,[15],[46],[140],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],306],
      485=>["席多藍恩","heatran",[:fire,:steel],[91,90,106,130,106,77],485,0,4,3,1,2,[15],[18],[49],[15,10,17,19,0],[:special,:special_attacker,5,:ranged],270],
      486=>["雷吉奇卡斯","regigigas",[:normal],[110,160,110,80,110,100],486,0,-1,3,1,2,[15],[112],[],[3,13,2,4,0],[:physical,:physical_sweeper,5,:melee],302],
      487=>["騎拉帝納","giratina",[:ghost,:dragon],[150,100,120,100,120,90],487,0,-1,3,1,2,[15],[46],[140],[8,5,7,23,12],[:mixed,:tank,5,:hybrid],306],
      488=>["克雷色利亞","cresselia",[:psychic],[120,70,110,75,120,85],488,0,8,3,1,2,[15],[26],[],[8,5,7,23,12],[:mixed,:tank,4,:hybrid],270],
      489=>["霏歐納","phione",[:water],[80,80,80,80,80,80],489,0,-1,30,1,4,[2,6],[93],[],[11,14,4,19,12],[:mixed,:balanced_mixed,5,:hybrid],216],
      490=>["瑪納霏","manaphy",[:water],[100,100,100,100,100,100],490,0,-1,3,1,4,[2,6],[93],[],[23,20,8,5,12],[:mixed,:mixed_sweeper,5,:hybrid],270],
      491=>["達克萊伊","darkrai",[:dark],[70,90,90,135,90,125],491,0,-1,3,1,4,[15],[123],[],[15,10,17,19,0],[:special,:special_sweeper,5,:ranged],270],
      492=>["謝米","shaymin",[:grass],[100,100,100,100,100,100],492,0,-1,45,4,4,[15],[30],[],[23,20,8,5,12],[:mixed,:mixed_sweeper,5,:hybrid],270],
      493=>["阿爾宙斯","arceus",[:normal],[120,120,120,120,120,120],493,0,-1,3,1,4,[15],[121],[],[23,20,8,5,12],[:mixed,:mixed_sweeper,5,:hybrid],324],
      494=>["比克提尼","victini",[:psychic,:fire],[100,100,100,100,100,100],494,0,-1,3,1,4,[15],[162],[],[23,20,8,5,12],[:mixed,:mixed_sweeper,5,:hybrid],270],
    }
    # Ultra Sun / Ultra Moon 等級學習表：dex => [[level, move_id], ...]
    LEVEL_LEARNSETS = {
      1=>[[1,33],[3,45],[7,73],[9,22],[13,77],[13,79],[15,36],[19,75],[21,230],[25,74],[27,38],[31,388],[33,235],[37,402]],
      2=>[[1,33],[1,45],[1,73],[3,45],[7,73],[9,22],[13,77],[13,79],[15,36],[20,75],[23,230],[28,74],[31,38],[36,388],[39,235],[44,76]],
      3=>[[0,80],[1,80],[1,33],[1,45],[1,73],[1,22],[3,45],[7,73],[9,22],[13,77],[13,79],[15,36],[20,75],[23,230],[28,74],[31,38],[39,388],[45,235],[50,572],[53,76]],
      4=>[[1,10],[1,45],[7,52],[10,108],[16,82],[19,184],[25,424],[28,481],[34,163],[37,53],[43,83],[46,517]],
      5=>[[1,10],[1,45],[1,52],[7,52],[10,108],[17,82],[21,184],[28,424],[32,481],[39,163],[43,53],[50,83],[54,517]],
      6=>[[0,17],[1,17],[1,394],[1,257],[1,337],[1,421],[1,403],[1,10],[1,45],[1,52],[7,52],[10,108],[17,82],[21,184],[28,424],[32,481],[41,163],[47,53],[56,83],[62,517],[71,257],[77,394]],
      7=>[[1,33],[4,39],[7,55],[10,110],[13,145],[16,44],[19,229],[22,182],[25,352],[28,401],[31,130],[34,334],[37,240],[40,56]],
      8=>[[1,33],[1,39],[1,55],[4,39],[7,55],[10,110],[13,145],[17,44],[21,229],[25,182],[29,352],[33,401],[37,130],[41,334],[45,240],[49,56]],
      9=>[[1,430],[1,33],[1,39],[1,55],[1,110],[4,39],[7,55],[10,110],[13,145],[17,44],[21,229],[25,182],[29,352],[33,401],[40,130],[47,334],[54,240],[60,56]],
      10=>[[1,33],[1,81],[9,450]],
      11=>[[0,106],[1,106]],
      12=>[[0,16],[1,16],[1,93],[11,93],[13,77],[13,78],[13,79],[17,60],[19,318],[23,48],[25,219],[29,18],[31,405],[35,476],[37,445],[41,366],[43,403],[47,483]],
      13=>[[1,40],[1,81],[9,450]],
      14=>[[0,106],[1,106]],
      15=>[[0,41],[1,41],[1,31],[11,31],[14,99],[17,228],[20,116],[23,474],[26,372],[29,390],[32,42],[35,398],[38,97],[41,283],[44,565]],
      16=>[[1,33],[5,28],[9,16],[13,98],[17,18],[21,239],[25,297],[29,97],[33,17],[37,355],[41,366],[45,119],[49,403],[53,542]],
      17=>[[1,33],[1,28],[1,16],[5,28],[9,16],[13,98],[17,18],[22,239],[27,297],[32,97],[37,17],[42,355],[47,366],[52,119],[57,403],[62,542]],
      18=>[[1,542],[1,33],[1,28],[1,16],[1,98],[5,28],[9,16],[13,98],[17,18],[22,239],[27,297],[32,97],[38,17],[44,355],[50,366],[56,119],[62,403],[68,542]],
      19=>[[1,33],[1,39],[4,98],[7,116],[10,44],[13,228],[16,158],[19,372],[22,242],[25,389],[28,162],[31,38],[34,283]],
      20=>[[0,184],[1,184],[1,14],[1,33],[1,39],[1,98],[1,116],[4,98],[7,116],[10,44],[13,228],[16,158],[19,372],[24,242],[29,389],[34,162],[39,38],[44,283]],
      21=>[[1,64],[1,45],[4,43],[8,228],[11,31],[15,332],[18,119],[22,372],[25,97],[29,116],[32,355],[36,65]],
      22=>[[1,529],[1,365],[1,64],[1,45],[1,43],[1,228],[4,43],[8,228],[11,31],[15,332],[18,119],[23,372],[27,97],[32,116],[36,355],[41,65],[45,529]],
      23=>[[1,35],[1,43],[4,40],[9,44],[12,137],[17,103],[20,51],[25,254],[25,256],[25,255],[28,491],[33,426],[36,380],[38,562],[41,114],[44,489],[49,441]],
      24=>[[0,242],[1,242],[1,423],[1,422],[1,424],[1,35],[1,43],[1,40],[1,44],[4,40],[9,44],[12,137],[17,103],[20,51],[27,254],[27,256],[27,255],[32,491],[39,426],[44,380],[48,562],[51,114],[56,489],[63,441]],
      25=>[[1,39],[1,84],[5,45],[7,589],[10,98],[13,486],[18,86],[21,364],[23,104],[26,209],[29,609],[34,435],[37,21],[42,85],[45,97],[50,528],[53,113],[58,87]],
      26=>[[1,84],[1,39],[1,98],[1,85]],
      27=>[[1,10],[1,111],[3,28],[5,40],[7,205],[9,229],[11,210],[14,222],[17,129],[20,154],[23,328],[26,163],[30,91],[34,360],[38,14],[42,201],[46,89]],
      28=>[[0,306],[1,306],[1,10],[1,111],[1,28],[1,40],[3,28],[5,40],[7,205],[9,229],[11,210],[14,222],[17,129],[20,154],[24,328],[28,163],[33,91],[38,360],[43,14],[48,201],[53,89]],
      29=>[[1,45],[1,10],[7,39],[9,24],[13,40],[19,154],[21,44],[25,270],[31,390],[33,260],[37,242],[43,445],[45,305]],
      30=>[[1,45],[1,10],[7,39],[9,24],[13,40],[20,154],[23,44],[28,270],[35,390],[38,260],[43,242],[50,445],[58,305]],
      31=>[[1,276],[1,10],[1,39],[1,24],[1,40],[23,498],[35,34],[43,414],[58,276]],
      32=>[[1,43],[1,64],[7,116],[9,24],[13,40],[19,31],[21,30],[25,270],[31,390],[33,260],[37,398],[43,445],[45,32]],
      33=>[[1,43],[1,64],[7,116],[9,24],[13,40],[20,31],[23,30],[28,270],[35,390],[38,260],[43,398],[50,445],[58,32]],
      34=>[[1,224],[1,64],[1,116],[1,24],[1,40],[23,498],[35,37],[43,414],[58,224]],
      35=>[[1,671],[1,574],[1,1],[1,45],[1,227],[7,47],[10,3],[13,111],[16,266],[19,516],[22,358],[25,107],[28,500],[31,118],[34,322],[37,381],[40,34],[43,236],[46,585],[49,356],[50,309],[55,361],[58,495]],
      36=>[[1,671],[1,574],[1,47],[1,3],[1,107],[1,118]],
      37=>[[1,52],[4,39],[7,46],[9,608],[10,98],[12,109],[15,83],[18,371],[20,261],[23,185],[26,506],[28,481],[31,326],[34,219],[36,53],[39,286],[42,126],[44,288],[47,445],[50,517]],
      38=>[[1,286],[1,417],[1,53],[1,98],[1,109],[1,219]],
      39=>[[1,47],[3,111],[5,1],[9,589],[11,574],[14,50],[17,3],[20,205],[22,496],[25,254],[25,256],[25,255],[27,358],[30,156],[32,34],[35,360],[38,102],[41,304],[45,38]],
      40=>[[1,38],[1,583],[1,47],[1,111],[1,50],[1,3]],
      41=>[[1,71],[5,48],[7,310],[11,44],[13,17],[17,109],[19,314],[23,129],[25,305],[29,212],[31,141],[35,114],[37,474],[41,403],[43,501]],
      42=>[[1,103],[1,71],[1,48],[1,310],[1,44],[5,48],[7,310],[11,44],[13,17],[17,109],[19,314],[24,129],[27,305],[32,212],[35,141],[40,114],[43,474],[48,403],[51,501]],
      43=>[[1,71],[1,74],[5,230],[9,51],[13,77],[14,78],[15,79],[19,72],[23,381],[27,236],[31,202],[35,92],[39,363],[43,585],[47,580],[51,80]],
      44=>[[1,71],[1,74],[1,230],[1,51],[5,230],[9,51],[13,77],[14,78],[15,79],[19,72],[24,381],[29,236],[34,202],[39,92],[44,363],[49,572],[54,580],[59,80]],
      45=>[[1,72],[1,312],[1,77],[1,78],[49,572],[59,80],[69,76]],
      46=>[[1,10],[6,78],[6,77],[11,71],[17,210],[22,147],[27,163],[33,74],[38,202],[43,312],[49,476],[54,404]],
      47=>[[1,440],[1,10],[1,78],[1,77],[1,71],[6,78],[6,77],[11,71],[17,210],[22,147],[29,163],[37,74],[44,202],[51,312],[59,476],[66,404]],
      48=>[[1,33],[1,50],[1,193],[5,48],[11,93],[13,77],[17,60],[23,78],[25,324],[29,79],[35,141],[37,428],[41,305],[47,94]],
      49=>[[0,16],[1,16],[1,483],[1,405],[1,318],[1,33],[1,50],[1,193],[1,48],[5,48],[11,93],[13,77],[17,60],[23,78],[25,324],[29,79],[37,141],[41,428],[47,305],[55,94],[59,405],[63,483]],
      50=>[[1,28],[1,10],[4,45],[7,310],[10,189],[14,222],[18,523],[22,389],[25,426],[28,414],[31,91],[35,163],[39,89],[43,90]],
      51=>[[0,328],[1,328],[1,563],[1,400],[1,161],[1,10],[1,28],[1,45],[4,45],[7,310],[10,189],[14,222],[18,523],[22,389],[25,426],[30,414],[35,91],[41,163],[47,89],[53,90]],
      52=>[[1,10],[1,45],[6,44],[9,252],[14,154],[17,103],[22,185],[25,269],[30,6],[33,163],[38,417],[41,372],[46,445],[49,400],[50,364]],
      53=>[[0,129],[1,129],[1,583],[1,415],[1,10],[1,45],[1,44],[1,252],[6,44],[9,252],[14,154],[17,103],[22,185],[25,269],[32,408],[37,163],[44,417],[49,372],[56,445],[61,400],[65,364]],
      54=>[[1,346],[1,10],[4,39],[7,55],[10,93],[13,154],[16,352],[19,50],[22,103],[25,428],[28,401],[31,487],[34,244],[37,133],[40,56],[43,472]],
      55=>[[1,382],[1,453],[1,346],[1,10],[1,39],[1,55],[4,39],[7,55],[10,93],[13,154],[16,352],[19,50],[22,103],[25,428],[28,401],[31,487],[36,244],[41,133],[46,56],[51,472]],
      56=>[[1,343],[1,10],[1,67],[1,43],[1,116],[5,154],[8,2],[12,228],[15,69],[19,207],[22,238],[26,372],[29,386],[33,37],[36,370],[40,103],[43,707],[47,200],[50,515]],
      57=>[[0,99],[1,99],[1,515],[1,374],[1,10],[1,67],[1,43],[1,116],[5,154],[8,2],[12,228],[15,69],[19,207],[22,238],[26,372],[30,386],[35,37],[39,370],[44,103],[48,707],[53,200],[57,515]],
      58=>[[1,44],[1,46],[6,52],[8,43],[10,316],[12,270],[17,172],[19,179],[21,424],[23,36],[28,481],[30,97],[32,514],[34,53],[39,242],[41,257],[43,200],[45,394]],
      59=>[[1,422],[1,44],[1,46],[1,316],[1,424],[34,245]],
      60=>[[1,346],[5,55],[8,95],[11,145],[15,3],[18,240],[21,34],[25,61],[28,341],[31,187],[35,358],[38,56],[41,426]],
      61=>[[1,346],[1,55],[1,95],[5,55],[8,95],[11,145],[15,3],[18,240],[21,34],[27,61],[32,341],[37,187],[43,358],[48,56],[53,426]],
      62=>[[0,66],[1,66],[1,509],[1,61],[1,95],[1,3],[32,223],[43,170],[53,509]],
      63=>[[1,100]],
      64=>[[0,134],[1,134],[1,100],[1,93],[16,93],[18,50],[21,60],[23,357],[26,115],[28,427],[31,105],[33,477],[36,502],[38,94],[41,272],[43,248],[46,271]],
      65=>[[0,134],[1,134],[1,100],[1,93],[16,93],[18,50],[21,60],[23,357],[26,115],[28,427],[31,105],[33,477],[36,502],[38,94],[41,347],[43,248],[46,271]],
      66=>[[1,67],[1,43],[3,116],[7,2],[9,193],[13,490],[15,69],[19,279],[21,282],[25,233],[27,358],[31,530],[33,66],[37,339],[39,238],[43,184],[45,223]],
      67=>[[1,67],[1,43],[1,116],[1,2],[3,116],[7,2],[9,193],[13,490],[15,69],[19,279],[21,282],[25,233],[27,358],[33,530],[37,66],[43,339],[47,238],[53,184],[57,223]],
      68=>[[0,70],[1,70],[1,469],[1,67],[1,43],[1,116],[1,2],[3,116],[7,2],[9,193],[13,490],[15,69],[19,279],[21,282],[25,233],[27,358],[33,530],[37,66],[43,339],[47,238],[53,184],[57,223]],
      69=>[[1,22],[7,74],[11,35],[13,79],[15,77],[17,78],[23,51],[27,282],[29,230],[35,380],[39,75],[41,398],[47,21],[50,378]],
      70=>[[1,22],[1,74],[1,35],[7,74],[11,35],[13,79],[15,77],[17,78],[24,51],[29,282],[32,230],[39,380],[44,75],[47,398],[54,21],[58,378]],
      71=>[[0,536],[1,536],[1,254],[1,256],[1,255],[1,22],[1,79],[1,230],[1,75],[32,437],[44,348]],
      72=>[[1,40],[4,48],[7,132],[10,51],[13,390],[16,352],[19,35],[22,491],[25,61],[28,112],[31,398],[34,362],[37,103],[40,506],[43,482],[46,56],[49,378]],
      73=>[[1,513],[1,378],[1,40],[1,48],[1,132],[1,51],[4,48],[7,132],[10,51],[13,390],[16,352],[19,35],[22,491],[25,61],[28,112],[32,398],[36,362],[40,103],[44,506],[48,482],[52,56],[56,378]],
      74=>[[1,33],[1,111],[4,300],[6,397],[10,205],[12,222],[16,88],[18,479],[22,523],[24,120],[28,446],[30,350],[34,89],[36,153],[40,38],[42,444]],
      75=>[[1,33],[1,111],[1,300],[1,397],[4,300],[6,397],[10,205],[12,222],[16,88],[18,479],[22,523],[24,120],[30,446],[34,350],[40,89],[44,153],[50,38],[54,444]],
      76=>[[1,484],[1,33],[1,111],[1,300],[1,397],[4,300],[6,397],[10,537],[12,222],[16,88],[18,479],[22,523],[24,120],[30,446],[34,350],[40,89],[44,153],[50,38],[54,444],[60,484]],
      77=>[[1,45],[1,33],[4,39],[9,52],[13,172],[17,23],[21,488],[25,83],[29,36],[33,517],[37,97],[41,126],[45,340],[49,394]],
      78=>[[0,31],[1,31],[1,398],[1,224],[1,45],[1,98],[1,39],[1,52],[4,39],[9,52],[13,172],[17,23],[21,488],[25,83],[29,36],[33,517],[37,97],[41,126],[45,340],[49,394]],
      79=>[[1,174],[1,281],[1,33],[5,45],[9,55],[14,93],[19,50],[23,29],[28,352],[32,428],[36,303],[41,133],[45,94],[49,240],[54,244],[58,505]],
      80=>[[0,110],[1,110],[1,505],[1,174],[1,281],[1,33],[1,45],[5,45],[9,55],[14,93],[19,50],[23,29],[28,352],[32,428],[36,303],[43,133],[49,94],[55,240],[62,244],[68,505]],
      81=>[[1,33],[1,48],[5,84],[7,86],[11,443],[13,113],[17,49],[19,209],[23,429],[25,319],[29,486],[31,430],[35,103],[37,435],[41,199],[43,393],[47,360],[49,192]],
      82=>[[0,161],[1,161],[1,192],[1,604],[1,33],[1,48],[1,84],[1,86],[5,84],[7,86],[11,443],[13,113],[17,49],[19,209],[23,429],[25,319],[29,486],[33,430],[39,103],[43,435],[49,199],[53,393],[59,360],[63,192]],
      83=>[[1,413],[1,398],[1,64],[1,28],[1,43],[1,210],[7,31],[9,332],[13,282],[19,163],[21,314],[25,14],[31,97],[33,400],[37,512],[43,364],[45,206],[49,403],[55,413]],
      84=>[[1,64],[1,45],[5,98],[8,99],[12,31],[15,228],[19,365],[22,458],[26,97],[29,253],[33,367],[36,14],[40,26],[43,65],[47,283],[50,37]],
      85=>[[0,161],[1,161],[1,64],[1,45],[1,98],[1,99],[5,98],[8,99],[12,31],[15,228],[19,365],[22,458],[26,97],[29,253],[34,367],[38,14],[43,26],[47,65],[52,283],[56,37]],
      86=>[[1,29],[3,45],[7,346],[11,196],[13,227],[17,420],[21,156],[23,392],[27,62],[31,453],[33,362],[37,36],[41,291],[43,401],[47,58],[51,219],[53,258]],
      87=>[[0,329],[1,329],[1,29],[1,45],[1,324],[1,196],[3,45],[7,324],[11,196],[13,227],[17,420],[21,156],[23,392],[27,62],[31,453],[33,362],[39,36],[45,291],[49,401],[55,58],[61,219],[65,258]],
      88=>[[1,1],[1,139],[4,106],[7,189],[12,50],[15,124],[18,426],[21,107],[26,374],[29,188],[32,482],[37,103],[40,441],[43,151],[46,562],[48,262]],
      89=>[[0,599],[1,599],[1,1],[1,139],[1,106],[1,189],[4,106],[7,189],[12,50],[15,124],[18,426],[21,107],[26,374],[29,188],[32,482],[37,103],[40,441],[46,151],[52,562],[57,262]],
      90=>[[1,33],[1,55],[4,110],[8,48],[13,333],[16,182],[20,43],[25,128],[28,420],[32,534],[37,62],[40,250],[44,362],[49,334],[52,58],[56,504],[61,56]],
      91=>[[1,56],[1,504],[1,390],[1,110],[1,48],[1,182],[1,62],[13,131],[28,191],[50,556]],
      92=>[[1,95],[1,122],[5,180],[8,212],[12,174],[15,101],[19,109],[22,389],[26,371],[29,247],[33,138],[36,399],[40,194],[43,506],[47,171]],
      93=>[[0,325],[1,325],[1,95],[1,122],[1,180],[5,180],[8,212],[12,174],[15,101],[19,109],[22,389],[28,371],[33,247],[39,138],[44,399],[50,194],[55,506],[61,171]],
      94=>[[0,325],[1,325],[1,95],[1,122],[1,180],[5,180],[8,212],[12,174],[15,101],[19,109],[22,389],[28,371],[33,247],[39,138],[44,399],[50,194],[55,506],[61,171]],
      95=>[[1,300],[1,33],[1,106],[1,20],[4,174],[7,88],[10,317],[13,99],[16,446],[19,397],[20,360],[22,479],[25,225],[28,21],[31,103],[34,157],[37,328],[40,231],[43,91],[46,444],[49,38],[52,201]],
      96=>[[1,1],[1,95],[5,50],[9,93],[13,29],[17,139],[21,96],[25,60],[29,358],[33,244],[37,485],[41,428],[45,207],[49,94],[53,417],[57,473],[61,248]],
      97=>[[1,248],[1,417],[1,171],[1,415],[1,1],[1,95],[1,50],[1,93],[5,50],[9,93],[13,29],[17,139],[21,96],[25,60],[29,358],[33,244],[37,485],[41,428],[45,207],[49,94],[53,417],[57,473],[61,248]],
      98=>[[1,300],[1,145],[5,11],[9,43],[11,106],[15,61],[19,341],[21,232],[25,23],[29,182],[31,12],[35,21],[39,362],[41,152],[45,175]],
      99=>[[1,469],[1,300],[1,145],[1,11],[1,43],[5,11],[9,43],[11,106],[15,61],[19,341],[21,232],[25,23],[32,182],[37,12],[44,21],[51,362],[56,152],[63,175]],
      100=>[[1,268],[1,33],[4,49],[6,598],[9,209],[11,205],[13,103],[16,451],[20,129],[22,486],[26,120],[29,113],[34,393],[37,435],[41,153],[46,360],[48,243]],
      101=>[[1,602],[1,268],[1,33],[1,49],[1,598],[4,49],[6,598],[9,209],[11,205],[13,103],[16,451],[20,129],[22,486],[26,120],[29,113],[36,393],[41,435],[47,153],[54,360],[58,243]],
      102=>[[1,140],[1,253],[1,95],[7,115],[11,73],[17,331],[19,78],[21,77],[23,79],[27,93],[33,388],[37,363],[43,76],[47,326],[50,516]],
      103=>[[0,23],[1,23],[1,402],[1,140],[1,95],[1,93],[17,473],[27,121],[37,452],[47,437]],
      104=>[[1,45],[3,39],[7,125],[11,29],[13,43],[17,116],[21,155],[23,99],[27,206],[31,37],[33,374],[37,707],[41,283],[43,38],[47,514],[51,198]],
      105=>[[1,45],[1,39],[1,125],[1,29],[3,39],[7,125],[11,29],[13,43],[17,116],[21,155],[23,99],[27,206],[33,37],[37,374],[43,707],[49,283],[53,38],[59,514],[65,198]],
      106=>[[0,24],[1,24],[1,179],[1,370],[1,25],[1,279],[1,96],[1,27],[1,26],[5,96],[9,27],[13,26],[17,280],[21,116],[25,364],[29,136],[33,170],[37,193],[41,469],[45,299],[49,203],[53,25],[57,370],[61,179]],
      107=>[[0,4],[1,4],[1,370],[1,68],[1,264],[1,279],[1,97],[1,228],[1,183],[6,97],[11,228],[16,183],[16,418],[21,364],[26,410],[31,501],[36,9],[36,8],[36,7],[41,327],[46,5],[50,197],[56,264],[61,68],[66,370]],
      108=>[[1,122],[5,48],[9,111],[13,282],[17,35],[21,23],[25,50],[29,21],[33,205],[37,498],[41,382],[45,287],[49,103],[53,438],[57,378]],
      109=>[[1,139],[1,33],[4,123],[7,108],[12,372],[15,499],[18,124],[23,120],[26,114],[29,360],[34,188],[37,153],[40,194],[42,562],[45,262]],
      110=>[[0,458],[1,458],[1,139],[1,33],[1,123],[1,108],[4,123],[7,108],[12,372],[15,499],[18,124],[23,120],[26,114],[29,360],[34,188],[40,153],[46,194],[51,562],[57,262]],
      111=>[[1,30],[1,39],[5,31],[9,184],[13,479],[17,23],[21,523],[25,498],[29,350],[33,529],[37,36],[41,444],[45,89],[49,224],[53,32]],
      112=>[[0,359],[1,359],[1,32],[1,30],[1,39],[1,31],[1,184],[5,31],[9,184],[13,479],[17,23],[21,523],[25,498],[29,350],[33,529],[37,36],[41,444],[48,89],[55,224],[62,32]],
      113=>[[1,38],[1,111],[1,1],[1,45],[5,39],[9,287],[12,3],[16,135],[20,516],[23,107],[27,36],[31,47],[35,374],[39,505],[44,121],[50,113],[57,361],[65,38]],
      114=>[[1,275],[1,132],[4,79],[7,22],[10,71],[14,77],[17,20],[20,74],[23,72],[27,282],[30,78],[33,363],[36,202],[38,246],[41,21],[44,321],[46,378],[48,580],[50,438]],
      115=>[[1,4],[1,43],[7,252],[10,39],[13,44],[19,458],[22,99],[25,5],[31,498],[34,146],[37,242],[43,203],[46,200],[49,389],[50,179]],
      116=>[[1,145],[5,108],[9,43],[13,55],[17,239],[21,61],[26,116],[31,362],[36,97],[41,406],[46,349],[52,56]],
      117=>[[1,56],[1,145],[1,108],[1,43],[1,55],[5,108],[9,43],[13,55],[17,239],[21,61],[26,116],[31,362],[38,97],[45,406],[52,349],[60,56]],
      118=>[[1,64],[1,39],[1,346],[5,48],[8,30],[13,175],[16,352],[21,392],[24,31],[29,97],[32,127],[37,32],[40,487],[45,224]],
      119=>[[1,224],[1,398],[1,64],[1,39],[1,346],[1,48],[5,48],[8,30],[13,175],[16,352],[21,392],[24,31],[29,97],[32,127],[40,32],[46,487],[54,224]],
      120=>[[1,33],[1,106],[4,55],[7,229],[10,105],[13,149],[16,129],[18,61],[22,293],[24,360],[28,362],[31,107],[35,513],[37,408],[40,109],[42,94],[46,113],[49,322],[53,56]],
      121=>[[1,56],[1,671],[1,55],[1,229],[1,105],[1,129],[40,109]],
      122=>[[1,581],[1,345],[1,501],[1,469],[1,384],[1,385],[1,112],[1,1],[1,93],[4,383],[8,96],[11,3],[15,102],[15,149],[18,227],[22,113],[22,115],[25,60],[29,164],[32,278],[36,271],[39,94],[43,272],[46,226],[50,219]],
      123=>[[1,410],[1,98],[1,43],[5,116],[9,228],[13,206],[17,97],[21,17],[25,210],[29,163],[33,13],[37,104],[41,404],[45,400],[49,458],[50,403],[57,14],[61,364]],
      124=>[[1,577],[1,195],[1,1],[1,122],[1,142],[1,181],[5,122],[8,142],[11,181],[15,3],[18,8],[21,531],[25,212],[28,313],[33,358],[39,419],[44,34],[49,378],[55,195],[60,59]],
      125=>[[1,98],[1,43],[1,84],[5,84],[8,67],[12,129],[15,351],[19,86],[22,486],[26,113],[29,9],[36,435],[42,103],[49,85],[55,87]],
      126=>[[1,123],[1,43],[1,52],[5,52],[8,108],[12,185],[15,83],[19,499],[22,481],[26,109],[29,7],[36,436],[42,241],[49,53],[55,126]],
      127=>[[1,11],[1,116],[4,20],[8,69],[11,106],[15,279],[18,233],[22,458],[26,280],[29,404],[33,66],[36,480],[40,14],[43,37],[47,276],[50,12]],
      128=>[[1,33],[3,39],[5,99],[8,30],[11,184],[15,228],[19,156],[24,371],[29,526],[35,36],[41,428],[48,207],[55,37],[63,38],[71,416]],
      129=>[[1,150],[15,33],[30,175]],
      130=>[[0,44],[1,44],[1,37],[21,43],[24,239],[27,423],[30,401],[33,184],[36,82],[39,242],[42,56],[45,349],[48,542],[51,240],[54,63]],
      131=>[[1,47],[1,45],[1,55],[4,54],[7,109],[10,420],[14,352],[18,34],[22,240],[27,195],[32,58],[37,362],[43,219],[47,56],[50,329]],
      132=>[[1,144]],
      133=>[[1,343],[1,270],[1,45],[1,33],[1,39],[5,28],[9,608],[13,98],[17,44],[17,129],[20,287],[25,36],[29,204],[33,226],[37,38],[41,387],[45,376]],
      134=>[[0,55],[1,55],[1,270],[1,33],[1,39],[5,28],[9,608],[13,98],[17,352],[20,62],[25,392],[29,151],[33,114],[37,330],[41,387],[45,56]],
      135=>[[0,84],[1,84],[1,270],[1,33],[1,39],[5,28],[9,608],[13,98],[17,24],[20,422],[25,42],[29,97],[33,86],[37,435],[41,387],[45,87]],
      136=>[[0,52],[1,52],[1,270],[1,33],[1,39],[5,28],[9,608],[13,98],[17,44],[20,424],[25,83],[29,184],[33,123],[37,436],[41,387],[45,394]],
      137=>[[1,176],[1,33],[1,160],[1,159],[7,60],[12,97],[18,105],[23,393],[29,324],[34,278],[40,435],[45,199],[50,161],[56,277],[62,192]],
      138=>[[1,132],[1,110],[7,44],[10,55],[16,205],[19,43],[25,341],[28,362],[34,182],[37,246],[43,321],[46,350],[50,504],[55,56]],
      139=>[[0,131],[1,131],[1,56],[1,132],[1,110],[1,44],[7,44],[10,55],[16,205],[19,43],[25,341],[28,362],[34,182],[37,246],[48,321],[56,350],[67,504],[75,56]],
      140=>[[1,10],[1,106],[6,71],[11,43],[16,341],[21,28],[26,203],[31,453],[36,72],[41,319],[46,246],[50,378]],
      141=>[[0,163],[1,163],[1,400],[1,364],[1,10],[1,106],[1,71],[1,43],[6,71],[11,43],[16,341],[21,28],[26,203],[31,453],[36,72],[45,319],[54,246],[63,378],[72,400]],
      142=>[[1,442],[1,423],[1,424],[1,422],[1,17],[1,48],[1,44],[1,184],[9,46],[17,97],[25,246],[33,242],[41,36],[49,507],[57,442],[65,63],[73,157],[81,416]],
      143=>[[1,33],[4,111],[9,133],[12,122],[17,498],[20,281],[25,34],[28,156],[28,173],[33,214],[35,416],[36,205],[41,335],[44,187],[49,242],[50,484],[57,667]],
      144=>[[1,16],[1,181],[8,54],[15,420],[22,170],[29,246],[36,97],[43,573],[50,115],[57,258],[64,366],[71,58],[78,59],[85,355],[92,542],[99,329]],
      145=>[[1,64],[1,84],[8,86],[15,197],[22,365],[29,246],[36,268],[43,97],[50,435],[57,240],[64,113],[71,65],[78,87],[85,355],[92,602],[99,192]],
      146=>[[1,17],[1,52],[8,83],[15,97],[22,203],[29,246],[36,53],[43,219],[50,403],[57,241],[64,257],[71,76],[78,143],[85,355],[92,542],[99,682]],
      147=>[[1,35],[1,43],[5,86],[11,239],[15,82],[21,21],[25,97],[31,525],[35,401],[41,407],[45,219],[51,349],[55,200],[61,63]],
      148=>[[1,35],[1,43],[1,86],[1,239],[5,86],[11,239],[15,82],[21,21],[25,97],[33,525],[39,401],[47,407],[53,219],[61,349],[67,200],[75,63]],
      149=>[[0,17],[1,17],[1,542],[1,7],[1,9],[1,355],[1,35],[1,43],[1,86],[1,239],[5,86],[11,239],[15,82],[21,21],[25,97],[33,525],[39,401],[47,407],[53,219],[61,349],[67,200],[75,63],[81,542]],
      150=>[[1,673],[1,149],[1,93],[1,50],[1,219],[8,129],[15,248],[22,244],[29,357],[36,427],[43,384],[43,385],[50,105],[57,94],[64,112],[70,396],[79,133],[86,54],[93,382],[100,540]],
      151=>[[1,1],[1,513],[1,144],[10,5],[20,118],[30,94],[40,112],[50,246],[60,133],[70,382],[80,226],[90,417],[100,396]],
      152=>[[1,33],[1,45],[6,75],[9,77],[12,235],[17,115],[20,345],[23,363],[28,230],[31,113],[34,34],[39,219],[42,312],[45,76]],
      153=>[[1,33],[1,45],[1,75],[1,77],[6,75],[9,77],[12,235],[18,115],[22,345],[26,363],[32,230],[36,113],[40,34],[46,219],[50,312],[54,76]],
      154=>[[0,80],[1,80],[1,572],[1,33],[1,45],[1,75],[1,77],[6,75],[9,77],[12,235],[18,115],[22,345],[26,363],[34,230],[40,113],[46,34],[54,219],[60,312],[66,76],[70,572]],
      155=>[[1,33],[1,43],[6,108],[10,52],[13,98],[19,172],[22,111],[28,488],[31,129],[37,436],[40,53],[46,517],[49,205],[55,38],[58,682],[64,284]],
      156=>[[1,33],[1,43],[1,108],[6,108],[10,52],[13,98],[20,172],[24,111],[31,129],[35,488],[42,436],[46,53],[53,517],[57,205],[64,38],[68,682],[75,284]],
      157=>[[1,284],[1,38],[1,360],[1,33],[1,43],[1,108],[1,52],[6,108],[10,52],[13,98],[20,172],[24,111],[31,129],[35,488],[43,436],[48,53],[56,517],[61,205],[69,38],[74,682],[82,284]],
      158=>[[1,10],[1,43],[6,55],[8,99],[13,44],[15,184],[20,423],[22,175],[27,242],[29,498],[34,163],[36,103],[41,37],[43,401],[48,276],[50,56]],
      159=>[[1,10],[1,43],[1,55],[6,55],[8,99],[13,44],[15,184],[21,423],[24,175],[30,242],[33,498],[39,163],[42,103],[48,37],[51,401],[57,276],[60,56]],
      160=>[[1,97],[1,10],[1,43],[1,55],[1,99],[6,55],[8,99],[13,44],[15,184],[21,423],[24,175],[32,242],[37,498],[45,163],[50,103],[58,37],[63,401],[71,276],[76,56]],
      161=>[[1,10],[1,193],[4,111],[7,98],[13,154],[16,270],[19,266],[25,21],[28,156],[31,389],[36,133],[39,226],[42,382],[47,304]],
      162=>[[0,97],[1,97],[1,489],[1,10],[1,193],[1,111],[1,98],[4,111],[7,98],[13,154],[17,270],[21,266],[28,21],[32,156],[36,389],[42,133],[46,226],[50,382],[56,304]],
      163=>[[1,33],[1,45],[1,193],[4,95],[7,64],[10,93],[13,497],[16,428],[19,375],[22,326],[25,36],[28,115],[31,403],[34,253],[37,355],[40,585],[43,485],[46,138]],
      164=>[[1,138],[1,143],[1,33],[1,45],[1,193],[1,95],[4,95],[7,64],[10,93],[13,497],[16,428],[19,375],[23,326],[27,36],[31,115],[35,403],[39,253],[43,355],[47,585],[51,485],[55,138]],
      165=>[[1,33],[5,48],[8,129],[12,113],[12,115],[12,219],[15,183],[19,318],[22,4],[26,226],[29,97],[33,405],[36,403],[40,38]],
      166=>[[1,33],[1,48],[1,129],[5,48],[8,129],[12,113],[12,115],[12,219],[15,183],[20,318],[24,4],[29,226],[33,97],[38,405],[42,403],[47,38]],
      167=>[[1,40],[1,81],[1,132],[5,71],[8,611],[12,184],[15,101],[19,425],[22,154],[26,389],[29,169],[33,97],[36,42],[40,94],[43,398],[47,440],[50,564],[54,672]],
      168=>[[0,14],[1,14],[1,116],[1,599],[1,565],[1,450],[1,40],[1,81],[1,132],[1,71],[5,71],[8,611],[12,184],[15,101],[19,425],[23,154],[28,389],[32,169],[37,97],[41,42],[46,94],[50,398],[55,440],[58,564],[63,672]],
      169=>[[0,440],[1,440],[1,103],[1,71],[1,48],[1,310],[1,44],[5,48],[7,310],[11,44],[13,17],[17,109],[19,314],[24,129],[27,305],[32,212],[35,141],[40,114],[43,474],[48,403],[51,501]],
      170=>[[1,145],[1,48],[6,86],[9,486],[12,55],[17,109],[20,61],[23,209],[28,324],[31,175],[34,435],[39,36],[42,392],[45,56],[47,569],[50,268]],
      171=>[[0,254],[0,256],[0,255],[1,254],[1,256],[1,255],[1,598],[1,671],[1,145],[1,48],[1,86],[1,486],[6,86],[9,486],[12,55],[17,109],[20,61],[23,209],[29,324],[33,175],[37,435],[43,36],[47,392],[51,56],[54,569],[58,268]],
      172=>[[1,84],[1,204],[5,39],[10,186],[13,417],[18,86]],
      173=>[[1,1],[1,204],[4,227],[7,47],[10,186],[13,383],[16,345]],
      174=>[[1,47],[1,204],[3,111],[5,1],[9,186],[11,383]],
      175=>[[1,45],[1,204],[5,118],[9,186],[13,281],[17,227],[21,266],[25,516],[29,273],[33,246],[37,219],[41,226],[45,38],[49,387],[53,495]],
      176=>[[1,345],[1,45],[1,204],[1,118],[1,186],[5,118],[9,186],[13,281],[14,584],[17,227],[21,266],[25,516],[29,273],[33,246],[37,219],[41,226],[45,38],[49,387],[53,495]],
      177=>[[1,64],[1,43],[6,101],[9,100],[12,381],[17,500],[20,466],[23,109],[28,273],[33,94],[36,357],[39,375],[44,248],[47,384],[47,385],[50,382]],
      178=>[[0,403],[1,403],[1,366],[1,64],[1,43],[1,101],[1,100],[6,101],[9,100],[12,381],[17,500],[20,466],[23,109],[29,273],[35,94],[39,357],[43,375],[49,248],[53,384],[53,385],[57,382]],
      179=>[[1,33],[1,45],[4,86],[8,84],[11,178],[15,268],[18,36],[22,486],[25,109],[29,408],[32,435],[36,538],[39,324],[43,113],[46,87]],
      180=>[[1,33],[1,45],[1,86],[1,84],[4,86],[8,84],[11,178],[16,268],[20,36],[25,486],[29,109],[34,408],[38,435],[43,538],[47,324],[52,113],[56,87]],
      181=>[[0,9],[1,9],[1,192],[1,602],[1,569],[1,406],[1,7],[1,33],[1,45],[1,86],[1,84],[4,86],[8,84],[11,178],[16,268],[20,36],[25,486],[29,109],[35,408],[40,435],[46,538],[51,324],[57,113],[62,87],[65,406]],
      182=>[[0,345],[1,345],[1,437],[1,348],[1,72],[1,230],[1,78],[1,241],[39,483],[49,572],[59,80],[69,437]],
      183=>[[1,33],[1,55],[2,39],[5,346],[7,145],[10,111],[10,205],[13,61],[16,270],[20,401],[23,583],[28,392],[31,240],[37,38],[40,276],[47,56]],
      184=>[[1,33],[1,55],[1,39],[1,346],[2,39],[5,346],[7,145],[10,111],[10,205],[13,61],[16,270],[21,401],[25,583],[31,392],[35,240],[42,38],[46,276],[55,56]],
      185=>[[0,21],[1,21],[1,452],[1,383],[1,175],[1,67],[1,88],[5,175],[8,67],[12,88],[15,102],[19,185],[22,715],[26,317],[29,335],[33,157],[36,68],[40,389],[43,38],[47,444],[50,359],[54,457]],
      186=>[[1,61],[1,95],[1,3],[1,195],[27,207],[37,340],[48,304]],
      187=>[[1,150],[1,71],[4,235],[6,39],[8,33],[10,584],[12,77],[14,78],[16,79],[19,331],[22,73],[25,72],[28,512],[31,476],[34,178],[37,369],[40,388],[43,202],[46,340],[49,262]],
      188=>[[1,150],[1,71],[1,235],[1,39],[4,235],[6,39],[8,33],[10,584],[12,77],[14,78],[16,79],[20,331],[24,73],[28,72],[32,512],[36,476],[40,178],[44,369],[48,388],[52,202],[56,340],[60,262]],
      189=>[[1,150],[1,71],[1,235],[1,39],[4,235],[6,39],[8,33],[10,584],[12,77],[14,78],[16,79],[20,331],[24,73],[29,72],[34,512],[39,476],[44,178],[49,369],[54,388],[59,202],[64,340],[69,262]],
      190=>[[1,10],[1,39],[4,28],[8,310],[11,226],[15,321],[18,154],[22,129],[25,103],[29,97],[32,458],[36,374],[39,417],[43,387]],
      191=>[[1,71],[1,74],[4,275],[7,320],[10,72],[13,73],[16,75],[19,388],[22,202],[25,283],[28,235],[31,363],[34,76],[37,38],[40,241],[43,402]],
      192=>[[1,579],[1,71],[1,1],[1,74],[4,275],[7,320],[10,72],[13,73],[16,75],[19,388],[22,202],[25,331],[28,80],[31,363],[34,76],[37,38],[40,241],[43,437],[50,572]],
      193=>[[1,33],[1,193],[6,98],[11,104],[14,49],[17,197],[22,48],[27,253],[30,228],[33,246],[38,95],[43,17],[46,103],[49,369],[54,403],[57,405]],
      194=>[[1,55],[1,39],[5,300],[9,341],[15,21],[19,426],[23,133],[29,281],[33,89],[37,240],[43,54],[43,114],[47,330]],
      195=>[[1,55],[1,39],[1,300],[5,300],[9,341],[15,21],[19,426],[24,133],[31,281],[36,89],[41,240],[48,54],[48,114],[53,330]],
      196=>[[0,93],[1,93],[1,270],[1,33],[1,39],[5,28],[9,608],[13,98],[17,129],[20,60],[25,248],[29,244],[33,234],[37,94],[41,387],[45,384]],
      197=>[[0,228],[1,228],[1,270],[1,33],[1,39],[5,28],[9,608],[13,98],[17,109],[20,185],[25,372],[29,103],[33,236],[37,212],[41,387],[45,385]],
      198=>[[1,64],[1,310],[5,228],[11,114],[15,17],[21,101],[25,372],[31,269],[35,185],[41,212],[45,492],[50,366],[55,389],[61,259],[65,511]],
      199=>[[1,505],[1,408],[1,237],[1,174],[1,281],[1,33],[5,45],[9,55],[14,93],[19,50],[23,29],[28,352],[32,428],[36,417],[41,207],[45,94],[49,376],[54,244],[58,505]],
      200=>[[1,45],[1,149],[5,180],[10,310],[14,109],[19,212],[23,506],[28,60],[32,220],[37,371],[41,247],[46,195],[50,288],[55,408]],
      201=>[[1,237]],
      202=>[[1,68],[1,243],[1,219],[1,194]],
      203=>[[1,384],[1,385],[1,310],[1,33],[1,45],[1,93],[5,316],[10,372],[14,23],[19,60],[23,97],[28,458],[32,428],[37,242],[41,226],[46,417],[50,94]],
      204=>[[1,33],[1,182],[6,120],[9,450],[12,36],[17,229],[20,117],[23,363],[28,191],[31,371],[34,153],[39,334],[42,360],[45,38]],
      205=>[[0,429],[0,475],[1,429],[1,475],[1,484],[1,192],[1,393],[1,390],[1,33],[1,182],[1,120],[1,450],[6,120],[9,450],[12,36],[17,229],[20,117],[23,363],[28,191],[32,371],[36,153],[42,334],[46,360],[50,38],[56,393],[60,192],[64,484]],
      206=>[[1,99],[1,111],[3,205],[6,180],[8,228],[11,103],[13,189],[16,281],[18,246],[21,34],[23,529],[26,355],[28,36],[31,489],[33,91],[36,137],[38,38],[41,283],[43,403],[46,407],[48,203],[51,175]],
      207=>[[1,40],[4,28],[7,106],[10,282],[13,98],[16,210],[19,185],[22,512],[27,163],[30,369],[35,103],[40,404],[45,327],[50,14],[55,12]],
      208=>[[1,422],[1,423],[1,424],[1,300],[1,33],[1,106],[1,20],[4,174],[7,88],[10,317],[13,99],[16,446],[19,475],[20,360],[22,479],[25,225],[28,21],[31,103],[34,157],[37,242],[40,231],[43,91],[46,444],[49,38],[52,201]],
      209=>[[1,423],[1,424],[1,422],[1,33],[1,184],[1,39],[1,204],[7,44],[13,122],[19,29],[25,46],[31,99],[37,583],[43,371],[49,242]],
      210=>[[1,200],[1,423],[1,424],[1,422],[1,33],[1,184],[1,39],[1,204],[7,44],[13,122],[19,29],[27,46],[35,99],[43,583],[51,371],[59,242],[67,200]],
      211=>[[1,565],[1,56],[1,194],[1,55],[1,191],[1,33],[1,40],[9,106],[9,107],[13,145],[17,205],[21,390],[25,254],[25,255],[29,279],[33,362],[37,42],[41,36],[45,401],[49,398],[53,194],[57,56],[60,565]],
      212=>[[1,364],[1,418],[1,98],[1,43],[5,116],[9,228],[13,206],[17,97],[21,232],[25,210],[29,163],[33,13],[37,334],[41,404],[45,400],[49,458],[50,442],[57,14],[61,364]],
      213=>[[1,564],[1,110],[1,132],[1,117],[1,205],[5,227],[9,35],[12,522],[16,219],[20,156],[23,88],[27,380],[31,379],[34,504],[38,157],[42,450],[45,471],[45,470],[49,444],[53,564]],
      214=>[[1,292],[1,331],[1,400],[1,33],[1,43],[1,30],[1,203],[7,364],[10,332],[16,498],[19,68],[25,31],[28,280],[31,42],[34,36],[37,224],[43,370],[46,179]],
      215=>[[1,10],[1,43],[1,269],[8,98],[10,185],[14,196],[16,154],[20,97],[22,232],[25,468],[28,251],[32,103],[35,163],[40,289],[44,386],[47,420]],
      216=>[[1,374],[1,343],[1,10],[1,608],[1,122],[1,313],[8,154],[15,185],[22,230],[25,589],[29,163],[36,204],[43,156],[43,173],[50,37],[57,374]],
      217=>[[1,359],[1,343],[1,10],[1,43],[1,122],[1,313],[8,154],[15,185],[22,230],[25,589],[29,163],[38,184],[47,156],[49,173],[58,37],[67,359]],
      218=>[[1,281],[1,123],[6,52],[8,88],[13,106],[15,510],[20,499],[22,246],[27,481],[29,157],[34,436],[36,133],[41,34],[43,105],[48,53],[50,414]],
      219=>[[0,504],[1,504],[1,414],[1,281],[1,123],[1,52],[1,88],[6,52],[8,88],[13,106],[15,510],[20,499],[22,246],[27,481],[29,157],[34,436],[36,133],[43,34],[47,105],[54,53],[58,414]],
      220=>[[1,33],[1,316],[5,300],[8,181],[11,189],[14,203],[18,426],[21,196],[24,420],[28,36],[35,54],[37,89],[40,175],[44,59],[48,133]],
      221=>[[0,31],[1,31],[1,246],[1,64],[1,316],[1,300],[1,181],[5,300],[8,181],[11,189],[14,203],[18,426],[21,196],[24,423],[28,36],[37,54],[41,37],[46,89],[52,59],[58,133]],
      222=>[[1,33],[1,106],[4,145],[8,105],[10,61],[13,287],[17,246],[20,131],[23,381],[27,362],[29,334],[31,350],[35,203],[38,392],[41,408],[45,243],[47,414],[50,175]],
      223=>[[1,55],[6,199],[10,60],[14,62],[18,61],[22,116],[26,352],[30,324],[34,58],[38,331],[42,56],[46,63],[50,487]],
      224=>[[0,190],[1,190],[1,441],[1,350],[1,55],[1,132],[1,60],[1,62],[6,132],[10,60],[14,62],[18,61],[22,116],[28,378],[34,324],[40,58],[46,331],[52,56],[58,63],[64,487]],
      225=>[[1,217],[25,65]],
      226=>[[1,60],[1,331],[1,324],[1,355],[1,33],[1,145],[1,48],[1,61],[3,48],[7,61],[11,109],[14,17],[16,29],[19,352],[23,469],[27,36],[32,97],[36,403],[39,392],[46,340],[49,56]],
      227=>[[1,43],[1,64],[6,28],[9,232],[12,314],[17,31],[20,364],[23,129],[28,191],[31,97],[34,211],[39,163],[42,319],[45,403],[50,475],[53,400]],
      228=>[[1,43],[1,52],[4,336],[8,123],[13,46],[16,44],[20,316],[25,251],[28,424],[32,185],[37,373],[40,492],[44,53],[49,242],[52,417],[56,517]],
      229=>[[1,517],[1,417],[1,422],[1,43],[1,52],[1,336],[1,123],[4,336],[8,123],[13,46],[16,44],[20,316],[26,251],[30,424],[35,185],[41,373],[45,492],[50,53],[56,242],[60,417],[65,517]],
      230=>[[1,56],[1,281],[1,145],[1,108],[1,43],[1,55],[5,108],[9,43],[13,55],[17,239],[21,61],[26,116],[31,362],[38,97],[45,406],[52,349],[60,56]],
      231=>[[1,316],[1,33],[1,45],[1,111],[6,175],[10,205],[15,363],[19,203],[24,21],[28,36],[33,204],[37,387],[42,38]],
      232=>[[0,31],[1,31],[1,424],[1,422],[1,30],[1,523],[1,45],[1,111],[6,229],[10,205],[15,372],[19,282],[24,21],[30,222],[37,184],[43,89],[50,416]],
      233=>[[1,192],[1,277],[1,176],[1,33],[1,160],[1,111],[7,60],[12,97],[18,105],[23,393],[29,324],[34,278],[40,435],[45,199],[50,161],[56,277],[62,192],[67,63]],
      234=>[[1,382],[1,33],[3,43],[7,310],[10,95],[13,23],[16,28],[21,36],[23,109],[27,347],[33,272],[38,428],[43,26],[49,286],[50,445],[55,382]],
      235=>[[1,166],[11,166],[21,166],[31,166],[41,166],[51,166],[61,166],[71,166],[81,166],[91,166]],
      236=>[[1,33],[1,270],[1,252],[1,193]],
      237=>[[0,27],[1,27],[1,283],[1,370],[1,197],[1,279],[1,116],[1,228],[1,98],[6,116],[10,228],[15,98],[19,229],[24,364],[28,68],[33,167],[37,97],[42,360],[46,469],[46,501],[50,197],[55,370],[60,283]],
      238=>[[1,1],[5,122],[8,186],[11,181],[15,93],[18,47],[21,531],[25,212],[28,313],[31,381],[35,419],[38,94],[41,383],[45,195],[48,59]],
      239=>[[1,98],[1,43],[5,84],[8,67],[12,129],[15,351],[19,86],[22,486],[26,113],[29,9],[33,435],[36,103],[40,85],[43,87]],
      240=>[[1,123],[1,43],[5,52],[8,108],[12,185],[15,83],[19,499],[22,481],[26,109],[29,7],[33,436],[36,241],[40,53],[43,126]],
      241=>[[1,33],[3,45],[5,111],[8,23],[11,208],[15,117],[19,205],[24,34],[29,428],[35,445],[41,360],[48,215],[50,358]],
      242=>[[1,38],[1,111],[1,1],[1,45],[5,39],[9,287],[12,3],[16,135],[20,516],[23,107],[27,36],[31,47],[34,374],[39,505],[44,121],[50,113],[57,361],[65,38]],
      243=>[[1,326],[1,435],[1,44],[1,43],[8,84],[15,46],[22,98],[29,209],[36,115],[43,242],[50,422],[57,435],[64,326],[71,240],[78,347],[85,87]],
      244=>[[1,221],[1,284],[1,326],[1,436],[1,44],[1,43],[8,52],[15,46],[22,83],[29,23],[36,53],[43,207],[50,424],[57,436],[64,326],[71,126],[78,347],[85,284]],
      245=>[[1,329],[1,44],[1,43],[1,61],[1,240],[8,61],[15,240],[22,16],[29,62],[36,54],[43,243],[50,423],[57,366],[64,326],[71,56],[78,347],[85,59]],
      246=>[[1,44],[1,43],[5,201],[10,103],[14,498],[19,157],[23,184],[28,37],[32,399],[37,371],[41,242],[46,89],[50,444],[55,63]],
      247=>[[1,44],[1,43],[1,201],[1,103],[5,201],[10,103],[14,498],[19,157],[23,184],[28,37],[34,399],[41,371],[47,242],[54,89],[60,444],[67,63]],
      248=>[[1,422],[1,423],[1,424],[1,44],[1,43],[1,201],[1,103],[5,201],[10,103],[14,498],[19,157],[23,184],[28,37],[34,399],[41,371],[47,242],[54,89],[63,444],[73,63],[82,416]],
      249=>[[1,18],[1,311],[9,16],[15,407],[23,326],[29,240],[37,56],[43,177],[50,386],[57,246],[65,219],[71,105],[79,248],[85,363],[93,347],[99,143]],
      250=>[[1,18],[1,311],[9,16],[15,413],[23,326],[29,241],[37,126],[43,221],[50,386],[57,246],[65,219],[71,105],[79,248],[85,363],[93,347],[99,143]],
      251=>[[1,73],[1,93],[1,105],[1,215],[10,219],[19,345],[28,246],[37,226],[46,363],[55,377],[64,248],[73,361],[82,437],[91,195]],
      252=>[[1,1],[1,43],[5,71],[9,98],[13,72],[17,228],[21,202],[25,97],[29,21],[33,197],[37,412],[41,501],[45,283],[49,103]],
      253=>[[0,210],[1,210],[1,1],[1,43],[1,71],[1,98],[5,71],[9,98],[13,72],[18,228],[23,348],[28,97],[33,21],[38,197],[43,404],[48,206],[53,501],[58,437],[63,103]],
      254=>[[0,530],[1,530],[1,210],[1,437],[1,400],[1,1],[1,43],[1,71],[1,98],[5,71],[9,98],[13,72],[18,228],[23,348],[28,97],[33,21],[39,197],[45,404],[51,206],[57,501],[63,437],[69,103]],
      255=>[[1,10],[1,45],[5,52],[10,28],[14,64],[19,83],[23,98],[28,481],[32,116],[37,163],[41,119],[46,53]],
      256=>[[0,24],[1,24],[1,10],[1,45],[1,52],[1,28],[5,52],[10,28],[14,64],[20,488],[25,98],[31,339],[36,116],[42,163],[47,119],[53,327],[58,394]],
      257=>[[0,299],[1,299],[1,24],[1,394],[1,7],[1,136],[1,10],[1,45],[1,52],[1,28],[5,52],[10,28],[14,64],[20,488],[25,98],[31,339],[37,116],[44,163],[50,413],[57,327],[63,394]],
      258=>[[1,33],[1,45],[4,55],[9,189],[12,193],[17,117],[20,300],[25,88],[28,182],[33,250],[36,36],[41,56],[44,283]],
      259=>[[0,341],[1,341],[1,33],[1,45],[1,55],[1,189],[4,55],[9,189],[12,193],[18,117],[22,426],[28,157],[32,182],[38,330],[42,36],[48,89],[52,283]],
      260=>[[1,341],[1,359],[1,33],[1,45],[1,55],[1,189],[4,55],[9,189],[12,193],[18,117],[22,426],[28,157],[32,182],[39,330],[44,36],[51,89],[56,283],[63,359]],
      261=>[[1,33],[4,336],[7,28],[10,44],[13,316],[16,46],[19,207],[22,372],[25,184],[28,373],[31,269],[34,242],[37,281],[40,36],[43,389],[46,583]],
      262=>[[0,555],[1,555],[1,424],[1,422],[1,423],[1,242],[1,168],[1,33],[1,336],[1,28],[1,44],[4,336],[7,28],[10,44],[13,316],[16,46],[20,207],[24,372],[28,184],[32,373],[36,269],[40,242],[44,281],[48,36],[52,389],[56,583]],
      263=>[[1,33],[1,45],[5,39],[7,28],[11,29],[12,608],[13,316],[17,300],[19,42],[23,343],[25,516],[29,175],[31,36],[35,156],[37,187],[41,374]],
      264=>[[1,583],[1,563],[1,415],[1,33],[1,45],[1,39],[1,28],[5,39],[7,28],[11,29],[13,316],[17,300],[19,154],[24,343],[27,516],[32,163],[35,38],[40,156],[43,187],[48,374]],
      265=>[[1,33],[1,81],[5,40],[15,450]],
      266=>[[0,106],[1,106]],
      267=>[[0,16],[1,16],[12,71],[15,78],[17,234],[20,314],[22,72],[25,318],[27,213],[30,18],[32,202],[35,405],[37,99],[40,483]],
      268=>[[0,106],[1,106]],
      269=>[[0,16],[1,16],[12,93],[15,77],[17,236],[20,474],[22,60],[25,318],[27,113],[30,18],[32,92],[35,405],[37,182],[40,483]],
      270=>[[1,310],[3,45],[6,71],[9,145],[12,363],[15,54],[18,72],[21,61],[24,267],[27,240],[30,202],[33,428],[36,412]],
      271=>[[1,310],[3,45],[6,71],[9,145],[12,154],[16,252],[20,346],[24,61],[28,267],[32,253],[36,282],[40,428],[44,56]],
      272=>[[1,310],[1,45],[1,72],[1,267]],
      273=>[[1,117],[3,106],[9,74],[15,267],[21,235],[27,241],[33,153]],
      274=>[[0,75],[1,75],[1,1],[3,106],[6,74],[9,259],[12,252],[16,267],[20,13],[24,185],[28,348],[32,207],[36,326]],
      275=>[[1,75],[1,185],[1,18],[1,417],[20,536],[32,542],[44,437]],
      276=>[[1,64],[1,45],[5,116],[9,98],[13,17],[17,104],[21,332],[25,501],[29,97],[33,403],[37,283],[41,413],[45,179]],
      277=>[[1,413],[1,403],[1,365],[1,64],[1,45],[1,116],[1,98],[5,116],[9,98],[13,17],[17,104],[21,332],[27,501],[33,97],[39,403],[45,283],[51,413],[57,179]],
      278=>[[1,45],[1,55],[5,48],[8,17],[12,54],[15,352],[19,98],[22,314],[26,228],[29,332],[33,355],[36,97],[40,403],[43,542]],
      279=>[[0,182],[1,182],[1,542],[1,56],[1,366],[1,487],[1,45],[1,55],[1,346],[1,17],[5,48],[8,17],[12,54],[15,352],[19,371],[22,362],[28,374],[33,254],[33,256],[33,255],[39,355],[44,366],[50,56],[55,542]],
      280=>[[1,45],[4,93],[6,104],[9,100],[11,574],[14,381],[17,345],[19,505],[22,577],[24,347],[27,94],[29,286],[32,248],[34,204],[37,95],[39,138],[42,500]],
      281=>[[1,45],[1,93],[1,104],[1,100],[4,93],[6,104],[9,100],[11,574],[14,381],[17,345],[19,505],[23,577],[26,347],[30,94],[33,286],[37,248],[40,204],[44,95],[47,138],[51,500]],
      282=>[[1,585],[1,500],[1,581],[1,361],[1,45],[1,93],[1,104],[1,100],[4,93],[6,104],[9,100],[11,574],[14,273],[17,345],[19,505],[23,577],[26,347],[31,94],[35,286],[40,248],[44,445],[49,95],[53,138],[58,500],[62,585]],
      283=>[[1,145],[6,98],[9,230],[14,346],[17,61],[22,97],[25,54],[25,114],[30,453],[35,226],[38,564]],
      284=>[[1,483],[1,18],[1,405],[1,466],[1,145],[1,98],[1,230],[1,346],[6,98],[9,230],[14,346],[17,16],[22,184],[22,314],[26,78],[32,318],[38,403],[42,405],[48,18],[52,483]],
      285=>[[1,71],[1,33],[5,78],[8,73],[12,72],[15,29],[19,77],[22,388],[26,202],[29,74],[33,92],[36,402],[40,147]],
      286=>[[0,183],[1,183],[1,71],[1,33],[1,78],[1,73],[5,78],[8,73],[12,72],[15,29],[19,364],[22,68],[28,395],[33,170],[39,327],[44,402],[50,223]],
      287=>[[1,10],[1,281],[6,227],[9,303],[14,185],[17,133],[22,343],[25,498],[30,68],[33,175],[38,583]],
      288=>[[1,179],[1,10],[1,116],[1,227],[1,253],[6,227],[9,253],[14,154],[17,203],[23,163],[27,498],[33,68],[37,264],[43,179]],
      289=>[[0,207],[1,207],[1,359],[1,386],[1,374],[1,10],[1,281],[1,227],[1,303],[6,227],[9,303],[14,185],[17,133],[23,343],[27,498],[33,68],[39,175],[47,374],[53,386],[61,359]],
      290=>[[1,10],[1,106],[5,71],[9,28],[13,154],[17,189],[21,232],[25,170],[29,117],[33,206],[37,91]],
      291=>[[0,104],[0,103],[0,210],[1,104],[1,103],[1,210],[1,450],[1,10],[1,106],[1,71],[1,28],[5,71],[9,28],[13,154],[17,97],[23,163],[29,170],[35,226],[41,14],[47,404]],
      292=>[[1,10],[1,106],[1,71],[1,28],[5,71],[9,28],[13,154],[17,180],[21,425],[25,170],[29,109],[33,247],[37,288],[41,377],[45,566]],
      293=>[[1,1],[4,497],[8,310],[11,336],[15,103],[18,48],[22,23],[25,253],[29,46],[32,156],[36,214],[39,304],[43,485]],
      294=>[[0,44],[1,44],[1,1],[1,497],[1,310],[1,336],[4,497],[9,310],[11,336],[15,103],[18,48],[23,23],[27,253],[32,46],[36,156],[41,214],[45,304],[50,485]],
      295=>[[0,242],[1,242],[1,44],[1,586],[1,423],[1,424],[1,422],[1,1],[1,497],[1,310],[1,336],[4,497],[9,310],[11,336],[15,103],[18,48],[23,23],[27,253],[32,46],[36,156],[42,214],[47,304],[53,485],[58,586],[64,63]],
      296=>[[1,33],[1,116],[4,28],[7,292],[10,252],[13,395],[16,18],[19,282],[22,233],[25,187],[28,265],[31,69],[34,358],[37,203],[40,370],[43,179],[46,484]],
      297=>[[1,362],[1,33],[1,116],[1,28],[1,292],[4,28],[7,292],[10,252],[13,395],[16,18],[19,282],[22,233],[26,187],[30,265],[34,69],[38,358],[42,203],[46,370],[50,179],[54,484]],
      298=>[[1,150],[1,55],[2,39],[5,346],[7,145],[10,204],[13,61],[16,270],[20,21],[23,340]],
      299=>[[1,33],[4,106],[7,335],[10,88],[13,86],[16,156],[19,209],[22,157],[25,408],[28,350],[31,435],[34,201],[37,414],[40,444],[43,199],[43,192]],
      300=>[[1,252],[1,45],[1,39],[1,33],[4,193],[7,47],[10,213],[13,574],[16,3],[19,383],[22,185],[25,204],[28,358],[31,274],[34,343],[37,215],[40,38],[43,445],[46,583]],
      301=>[[1,252],[1,47],[1,213],[1,3]],
      302=>[[1,43],[1,10],[4,193],[6,101],[9,310],[11,154],[14,197],[16,425],[19,185],[21,252],[24,386],[26,282],[29,421],[31,109],[34,428],[36,408],[39,247],[41,492],[44,511],[46,212]],
      303=>[[1,583],[1,442],[1,269],[1,45],[1,584],[1,310],[5,313],[9,44],[13,230],[17,11],[21,185],[25,226],[29,242],[33,334],[37,389],[41,254],[41,256],[41,255],[45,442],[49,583]],
      304=>[[1,33],[1,106],[4,189],[7,29],[10,232],[13,317],[16,182],[19,46],[22,442],[25,157],[28,36],[31,319],[34,231],[37,334],[40,38],[43,475],[46,484],[49,368]],
      305=>[[1,33],[1,106],[1,189],[1,29],[4,189],[7,29],[10,232],[13,317],[16,182],[19,46],[22,442],[25,157],[28,36],[31,319],[35,231],[39,334],[43,38],[47,475],[51,484],[55,368]],
      306=>[[1,33],[1,106],[1,189],[1,29],[4,189],[7,29],[10,232],[13,317],[16,182],[19,46],[22,442],[25,157],[28,36],[31,319],[35,231],[39,334],[45,38],[51,475],[57,484],[63,368]],
      307=>[[1,117],[4,96],[7,93],[9,197],[12,203],[15,364],[17,395],[20,237],[23,347],[25,170],[28,136],[31,244],[33,367],[36,379],[39,179],[41,105],[44,68]],
      308=>[[1,428],[1,7],[1,9],[1,8],[1,117],[1,96],[1,93],[1,197],[4,96],[7,93],[9,197],[12,203],[15,364],[17,395],[20,237],[23,347],[25,170],[28,136],[31,244],[33,367],[36,379],[42,179],[47,105],[53,68]],
      309=>[[1,33],[1,86],[4,43],[7,336],[10,98],[13,209],[16,316],[19,422],[24,44],[29,435],[34,46],[39,528],[44,268],[49,87]],
      310=>[[1,604],[1,424],[1,33],[1,86],[1,43],[1,336],[4,43],[7,336],[10,98],[13,209],[16,316],[19,422],[24,44],[30,435],[36,46],[42,528],[48,268],[54,87],[60,604]],
      311=>[[1,609],[1,589],[1,45],[1,86],[1,98],[4,270],[7,209],[10,227],[13,516],[16,129],[19,486],[22,383],[25,204],[28,268],[31,435],[34,226],[37,97],[40,387],[43,87],[46,417],[49,494]],
      312=>[[1,609],[1,589],[1,45],[1,86],[1,98],[4,270],[7,209],[10,227],[13,415],[16,129],[19,486],[22,383],[25,313],[28,268],[31,435],[34,226],[37,97],[40,376],[43,87],[46,417],[49,494]],
      313=>[[1,148],[1,33],[5,104],[8,109],[12,98],[15,522],[19,236],[22,294],[26,324],[29,182],[33,428],[36,270],[40,405],[43,583],[47,38],[50,611]],
      314=>[[1,589],[1,33],[5,230],[9,204],[12,98],[15,522],[19,236],[22,273],[26,227],[29,260],[33,428],[36,270],[40,405],[43,583],[47,343],[50,611]],
      315=>[[1,71],[4,74],[7,40],[10,78],[13,72],[16,73],[19,345],[22,320],[25,202],[28,390],[31,230],[34,275],[37,572],[40,92],[43,312],[46,235],[50,80]],
      316=>[[1,1],[5,281],[8,139],[10,124],[12,133],[17,491],[20,227],[25,92],[28,254],[28,255],[28,256],[33,188],[36,380],[41,562],[44,378],[49,441]],
      317=>[[0,34],[1,34],[1,599],[1,441],[1,378],[1,1],[1,281],[1,139],[1,124],[5,281],[8,139],[10,124],[12,133],[17,491],[20,227],[25,92],[30,254],[30,255],[30,256],[37,188],[42,380],[49,562],[54,378],[61,441]],
      318=>[[1,43],[1,44],[4,99],[8,116],[11,453],[15,372],[18,103],[22,207],[25,423],[29,184],[32,305],[36,242],[39,97],[43,36]],
      319=>[[0,163],[1,163],[1,400],[1,364],[1,43],[1,44],[1,99],[1,116],[4,99],[8,116],[11,453],[15,372],[18,103],[22,207],[25,423],[29,184],[34,305],[40,242],[45,97],[51,130],[56,269],[62,400]],
      320=>[[1,150],[4,45],[7,55],[10,205],[13,250],[16,310],[19,352],[22,54],[25,362],[29,156],[33,323],[37,133],[41,291],[45,340],[49,56],[53,484]],
      321=>[[1,487],[1,568],[1,484],[1,150],[1,45],[1,55],[1,205],[4,45],[7,55],[10,205],[13,250],[16,310],[19,352],[22,54],[25,362],[29,156],[33,323],[37,133],[44,291],[51,340],[58,56],[65,484]],
      322=>[[1,45],[1,33],[5,52],[8,116],[12,222],[15,481],[19,133],[22,436],[26,414],[29,174],[31,36],[36,281],[40,89],[43,53],[47,38]],
      323=>[[0,157],[1,157],[1,90],[1,284],[1,45],[1,33],[1,52],[1,116],[8,52],[8,116],[12,222],[15,481],[19,133],[22,436],[26,414],[29,174],[31,36],[39,281],[46,89],[52,284],[59,90]],
      324=>[[1,52],[4,123],[7,110],[10,229],[13,83],[15,108],[18,172],[22,174],[25,436],[27,34],[30,182],[34,53],[38,334],[40,133],[42,175],[45,257],[47,504],[50,517]],
      325=>[[1,150],[7,149],[10,316],[14,60],[15,244],[18,109],[21,277],[26,428],[29,408],[29,156],[33,173],[38,473],[40,371],[44,94],[50,340]],
      326=>[[0,298],[1,298],[1,562],[1,150],[1,149],[1,316],[1,60],[7,149],[10,316],[14,60],[15,244],[18,109],[21,277],[26,428],[29,408],[35,156],[35,173],[42,473],[46,371],[52,94],[60,340]],
      327=>[[1,33],[5,383],[10,185],[14,60],[19,95],[23,146],[28,389],[32,298],[37,253],[41,244],[46,38],[50,175],[55,37]],
      328=>[[1,28],[1,44],[1,185],[1,117],[5,189],[8,523],[12,328],[15,157],[19,91],[22,242],[26,414],[29,364],[33,89],[36,201],[40,276],[43,63],[47,90]],
      329=>[[0,225],[1,225],[1,28],[1,49],[1,185],[1,117],[5,189],[8,523],[12,328],[15,157],[19,48],[22,103],[26,414],[29,405],[33,89],[36,201],[40,253],[43,63],[47,586]],
      330=>[[0,337],[1,337],[1,225],[1,349],[1,28],[1,49],[1,185],[1,117],[5,189],[8,523],[12,328],[15,157],[19,48],[22,103],[26,414],[29,525],[33,89],[36,201],[40,253],[43,63],[47,407]],
      331=>[[1,40],[1,43],[4,71],[7,74],[10,73],[13,28],[16,302],[19,185],[22,275],[26,371],[30,191],[34,389],[38,42],[42,412],[46,178],[50,201],[54,194]],
      332=>[[0,596],[1,596],[1,194],[1,279],[1,40],[1,43],[1,71],[1,74],[4,71],[7,74],[10,73],[13,28],[16,302],[19,185],[22,275],[26,371],[30,191],[35,389],[38,42],[44,412],[49,178],[54,201],[59,194]],
      333=>[[1,64],[1,45],[3,310],[5,47],[7,31],[9,219],[11,574],[14,54],[17,496],[20,363],[23,36],[26,287],[30,119],[34,538],[38,406],[42,195],[46,585]],
      334=>[[0,225],[1,225],[1,143],[1,365],[1,64],[1,45],[1,310],[1,47],[3,310],[5,47],[7,31],[9,219],[11,574],[14,54],[17,496],[20,363],[23,36],[26,287],[30,349],[34,538],[40,406],[46,195],[52,585],[59,143]],
      335=>[[1,10],[1,43],[5,98],[8,210],[12,228],[15,468],[19,163],[22,279],[26,306],[29,206],[33,373],[36,197],[40,404],[43,269],[47,14],[50,370]],
      336=>[[1,35],[1,207],[4,44],[6,122],[9,342],[11,364],[14,103],[16,474],[19,137],[21,305],[24,599],[26,400],[29,380],[31,398],[34,114],[36,14],[39,242],[41,562],[44,489],[46,378]],
      337=>[[1,408],[1,473],[1,585],[1,33],[1,106],[1,93],[1,88],[5,95],[9,397],[13,149],[17,373],[21,157],[25,322],[29,94],[33,377],[37,444],[41,248],[45,153],[49,478]],
      338=>[[1,394],[1,33],[1,106],[1,93],[1,88],[5,83],[9,397],[13,149],[17,373],[21,157],[25,322],[29,94],[33,377],[37,444],[41,76],[45,153],[49,472]],
      339=>[[1,189],[6,300],[6,346],[9,55],[13,426],[15,133],[17,352],[20,222],[25,156],[25,173],[28,401],[32,89],[35,330],[39,248],[44,90]],
      340=>[[0,37],[1,37],[1,562],[1,428],[1,321],[1,189],[1,300],[1,346],[1,55],[6,300],[6,346],[9,55],[13,426],[15,133],[17,352],[20,222],[25,156],[25,173],[28,401],[34,89],[39,330],[45,248],[52,90]],
      341=>[[1,145],[5,106],[7,11],[10,43],[14,61],[17,182],[20,458],[23,282],[26,400],[31,534],[34,269],[37,14],[39,242],[43,152],[48,12]],
      342=>[[0,129],[1,129],[1,145],[1,106],[1,11],[1,43],[5,106],[7,11],[10,43],[14,61],[17,182],[20,458],[23,282],[26,400],[32,534],[36,269],[40,14],[43,242],[48,152],[54,12]],
      343=>[[1,106],[1,93],[4,229],[7,189],[10,377],[13,317],[16,60],[19,246],[22,322],[25,379],[28,120],[31,326],[34,470],[34,471],[37,414],[40,201],[43,286],[46,153]],
      344=>[[0,63],[1,63],[1,100],[1,106],[1,93],[1,229],[4,229],[7,189],[10,377],[13,317],[16,60],[19,246],[22,322],[25,379],[28,120],[31,326],[34,470],[34,471],[40,414],[46,201],[52,286],[58,153]],
      345=>[[1,310],[1,132],[5,51],[9,275],[13,109],[17,246],[21,362],[26,202],[31,380],[36,133],[41,412],[46,254],[46,255],[46,256],[52,378]],
      346=>[[1,378],[1,310],[1,132],[1,51],[1,275],[5,51],[9,275],[13,109],[17,246],[21,362],[26,202],[31,380],[36,133],[44,412],[52,254],[52,255],[52,256],[61,378]],
      347=>[[1,10],[1,106],[4,300],[7,55],[10,210],[13,479],[17,232],[21,246],[25,450],[29,362],[34,163],[39,306],[44,404],[49,182],[55,350]],
      348=>[[1,10],[1,106],[1,300],[1,55],[4,300],[7,55],[10,210],[13,479],[17,232],[21,246],[25,450],[29,362],[34,163],[39,306],[46,404],[53,182],[61,350]],
      349=>[[1,150],[15,33],[30,175]],
      350=>[[0,352],[1,352],[1,35],[1,55],[1,346],[1,287],[4,346],[7,287],[11,574],[14,239],[17,392],[21,445],[24,525],[27,105],[31,401],[34,213],[37,219],[41,489],[44,56],[47,240]],
      351=>[[1,33],[10,55],[10,52],[10,181],[15,29],[20,240],[20,241],[20,258],[25,311],[35,56],[35,126],[35,59],[45,542]],
      352=>[[1,168],[1,39],[1,310],[1,122],[1,10],[4,20],[7,425],[10,364],[13,154],[16,185],[18,60],[21,246],[25,163],[30,293],[33,421],[38,103],[42,164],[46,389],[50,485]],
      353=>[[1,282],[4,103],[7,101],[10,180],[13,425],[16,261],[19,185],[22,506],[26,174],[30,247],[34,373],[38,389],[42,289],[46,288],[50,271],[54,566]],
      354=>[[1,566],[1,282],[1,103],[1,101],[1,180],[4,103],[7,101],[10,180],[13,425],[16,261],[19,185],[22,506],[26,174],[30,247],[34,373],[40,389],[46,289],[52,288],[58,271],[64,566]],
      355=>[[1,43],[1,101],[6,50],[9,310],[14,193],[17,425],[22,228],[25,261],[30,109],[33,174],[38,506],[41,247],[46,212],[49,371],[54,248]],
      356=>[[0,325],[1,325],[1,248],[1,7],[1,8],[1,9],[1,356],[1,20],[1,43],[1,101],[1,50],[1,310],[6,50],[9,310],[14,193],[17,425],[22,228],[25,261],[30,109],[33,174],[40,506],[45,247],[52,212],[57,371],[64,248]],
      357=>[[1,437],[1,43],[1,16],[1,74],[1,75],[6,230],[10,23],[16,345],[21,18],[26,536],[30,363],[36,403],[41,34],[46,516],[50,235],[56,76],[61,437]],
      358=>[[1,361],[1,485],[1,35],[1,45],[1,310],[1,93],[4,45],[7,310],[10,93],[13,281],[16,149],[19,36],[22,326],[27,215],[32,253],[37,219],[42,38],[47,505],[52,485],[57,361]],
      359=>[[1,195],[1,248],[1,10],[1,364],[1,43],[1,98],[4,43],[7,98],[10,228],[13,269],[16,44],[19,104],[22,163],[25,14],[29,400],[33,197],[37,427],[41,382],[45,389],[49,13],[53,248],[57,195]],
      360=>[[1,150],[1,204],[1,227],[15,68],[15,243],[15,219],[15,194]],
      361=>[[1,181],[1,43],[5,104],[10,420],[14,196],[19,44],[23,423],[28,29],[32,182],[37,524],[41,242],[46,59],[50,258]],
      362=>[[0,573],[1,573],[1,329],[1,181],[1,43],[1,104],[1,420],[5,104],[10,420],[14,196],[19,44],[23,423],[28,29],[32,182],[37,524],[41,242],[48,59],[54,258],[61,329]],
      363=>[[1,111],[1,181],[1,45],[1,55],[5,205],[9,227],[13,301],[17,362],[21,62],[26,34],[31,156],[31,173],[36,258],[41,59],[46,329]],
      364=>[[0,207],[1,207],[1,111],[1,181],[1,45],[1,55],[5,205],[9,227],[13,301],[17,362],[21,62],[26,34],[31,156],[31,173],[38,258],[45,59],[52,329]],
      365=>[[0,423],[1,423],[1,207],[1,242],[1,111],[1,181],[1,45],[1,55],[7,205],[7,227],[13,301],[19,362],[19,62],[25,34],[31,156],[31,173],[38,258],[49,59],[60,329]],
      366=>[[1,128],[1,55],[1,250],[1,334],[50,504]],
      367=>[[1,250],[1,44],[5,103],[9,184],[11,185],[14,352],[16,423],[19,362],[23,389],[26,291],[29,226],[34,242],[39,401],[45,489],[50,56]],
      368=>[[1,250],[1,93],[5,346],[9,97],[11,577],[14,352],[16,133],[19,392],[23,445],[26,291],[29,226],[34,94],[39,401],[45,489],[50,56]],
      369=>[[1,175],[1,457],[1,33],[1,106],[1,300],[1,55],[6,300],[10,55],[15,317],[21,246],[26,291],[31,36],[35,281],[41,156],[46,56],[50,38],[56,457]],
      370=>[[1,33],[1,204],[4,55],[7,97],[9,577],[13,381],[17,352],[20,213],[22,531],[26,175],[31,186],[34,36],[37,445],[40,392],[42,487],[46,56],[49,219]],
      371=>[[1,99],[4,52],[7,43],[10,44],[13,225],[17,29],[21,116],[25,242],[29,337],[34,428],[39,184],[44,53],[49,38]],
      372=>[[0,182],[1,182],[1,99],[1,52],[1,43],[1,44],[4,52],[7,43],[10,44],[13,225],[17,29],[21,116],[25,242],[29,337],[35,428],[42,184],[49,53],[56,38]],
      373=>[[0,19],[1,19],[1,182],[1,525],[1,424],[1,422],[1,99],[1,52],[1,43],[1,44],[4,52],[7,43],[10,44],[13,225],[17,29],[21,116],[25,242],[29,337],[35,428],[42,184],[49,53],[63,38]],
      374=>[[1,36]],
      375=>[[0,93],[0,232],[1,93],[1,232],[1,393],[1,36],[23,228],[26,418],[29,357],[32,428],[35,184],[38,94],[41,97],[44,309],[47,334],[50,63]],
      376=>[[0,359],[1,359],[1,93],[1,232],[1,393],[1,36],[23,228],[26,418],[29,357],[32,428],[35,184],[38,94],[41,97],[44,309],[52,334],[60,63]],
      377=>[[1,153],[1,23],[1,88],[1,451],[1,523],[7,88],[13,451],[19,523],[25,174],[31,246],[37,334],[43,444],[49,359],[55,199],[55,192],[61,276],[67,63]],
      378=>[[1,153],[1,23],[1,196],[1,451],[1,523],[7,196],[13,451],[19,523],[25,174],[31,246],[37,133],[43,58],[49,359],[55,199],[55,192],[61,276],[67,63]],
      379=>[[1,153],[1,23],[1,232],[1,451],[1,523],[7,232],[13,451],[19,523],[25,174],[31,246],[37,334],[37,133],[43,442],[43,430],[49,359],[55,199],[55,192],[61,276],[67,63]],
      380=>[[1,361],[1,270],[1,273],[1,149],[1,219],[4,346],[7,204],[10,500],[13,287],[16,505],[20,225],[24,296],[28,375],[32,105],[36,513],[41,428],[46,470],[51,94],[56,406],[61,361]],
      381=>[[1,262],[1,270],[1,377],[1,149],[1,219],[4,182],[7,349],[10,500],[13,287],[16,505],[20,225],[24,295],[28,375],[32,105],[36,477],[41,428],[46,471],[51,94],[56,406],[61,262]],
      382=>[[1,246],[1,352],[5,184],[15,401],[20,34],[30,392],[35,58],[45,618],[50,347],[60,330],[65,329],[75,56],[80,38],[90,323]],
      383=>[[1,246],[1,341],[5,184],[15,414],[20,436],[30,156],[35,89],[45,619],[50,339],[60,76],[65,90],[75,126],[80,359],[90,284]],
      384=>[[1,239],[5,184],[15,246],[20,242],[30,403],[35,156],[45,245],[50,406],[60,349],[65,19],[75,304],[80,200],[90,63]],
      385=>[[1,273],[1,93],[5,156],[10,129],[15,270],[20,94],[25,287],[30,381],[35,428],[40,38],[45,356],[50,361],[55,248],[60,322],[65,387],[70,353]],
      386=>[[1,43],[1,35],[7,101],[13,100],[19,282],[25,228],[31,94],[37,289],[43,375],[49,428],[55,322],[61,105],[67,354],[73,63]],
      387=>[[1,33],[5,110],[9,71],[13,75],[17,174],[21,44],[25,72],[29,73],[33,235],[37,242],[41,202],[45,437]],
      388=>[[1,33],[1,110],[1,71],[5,110],[9,71],[13,75],[17,174],[22,44],[27,72],[32,73],[37,235],[42,242],[47,202],[52,437]],
      389=>[[0,89],[1,89],[1,452],[1,33],[1,110],[1,71],[1,75],[5,110],[9,71],[13,75],[17,174],[22,44],[27,72],[33,73],[39,235],[45,242],[51,202],[57,437]],
      390=>[[1,10],[1,43],[7,52],[9,269],[15,154],[17,172],[23,417],[25,259],[31,263],[33,83],[39,512],[41,303],[47,53]],
      391=>[[0,183],[1,183],[1,10],[1,43],[1,52],[7,52],[9,269],[16,154],[19,172],[26,364],[29,259],[36,370],[39,83],[46,512],[49,303],[56,394]],
      392=>[[0,370],[1,370],[1,183],[1,394],[1,10],[1,43],[1,52],[1,269],[7,52],[9,269],[16,154],[19,172],[26,364],[29,386],[42,83],[52,512],[58,347],[68,394]],
      393=>[[1,1],[4,45],[8,145],[11,346],[15,64],[18,61],[22,117],[25,31],[29,362],[32,250],[36,54],[39,65],[43,56]],
      394=>[[0,232],[1,232],[1,33],[1,45],[1,145],[4,45],[8,145],[11,346],[15,64],[19,61],[24,117],[28,31],[33,362],[37,250],[42,54],[46,65],[50,56]],
      395=>[[0,453],[1,453],[1,232],[1,33],[1,45],[1,145],[4,45],[8,145],[11,14],[15,64],[19,61],[24,207],[28,31],[33,362],[39,250],[46,54],[52,65],[59,56]],
      396=>[[1,33],[1,45],[5,98],[9,17],[13,104],[17,283],[21,18],[25,332],[29,36],[33,97],[37,413],[41,515]],
      397=>[[1,33],[1,45],[1,98],[5,98],[9,17],[13,104],[18,283],[23,18],[28,332],[33,36],[38,97],[43,413],[48,515]],
      398=>[[0,370],[1,370],[1,33],[1,45],[1,98],[1,17],[5,98],[9,17],[13,104],[18,283],[23,18],[28,332],[33,36],[41,97],[49,413],[57,515]],
      399=>[[1,33],[1,45],[5,111],[9,205],[13,29],[17,158],[21,281],[25,242],[29,36],[33,162],[37,14],[41,133],[45,276],[49,174]],
      400=>[[0,55],[1,55],[1,453],[1,563],[1,33],[1,45],[5,111],[9,205],[13,29],[18,158],[23,281],[28,242],[33,36],[38,162],[43,14],[48,133],[53,276],[58,174]],
      401=>[[1,45],[1,117],[6,522],[16,450]],
      402=>[[0,210],[1,210],[1,45],[1,117],[14,71],[18,47],[22,116],[26,163],[30,404],[34,103],[36,565],[38,269],[42,400],[44,564],[46,405],[50,195]],
      403=>[[1,33],[5,43],[9,268],[11,608],[13,209],[17,44],[21,46],[25,207],[29,422],[33,242],[37,184],[41,435],[45,528]],
      404=>[[1,33],[1,43],[5,43],[9,268],[13,209],[18,44],[23,46],[28,207],[33,422],[38,242],[43,184],[48,435],[53,528]],
      405=>[[1,604],[1,33],[1,43],[1,268],[5,43],[9,268],[13,209],[18,44],[23,46],[28,207],[35,422],[42,242],[49,184],[56,435],[63,528],[67,604]],
      406=>[[1,71],[4,74],[7,346],[10,78],[13,72],[16,388]],
      407=>[[1,599],[1,580],[1,311],[1,40],[1,72],[1,345],[1,230]],
      408=>[[1,29],[1,43],[6,116],[10,228],[15,36],[19,184],[24,372],[28,498],[33,246],[37,428],[42,103],[46,457]],
      409=>[[0,283],[1,283],[1,29],[1,43],[1,116],[1,228],[6,116],[10,228],[15,36],[19,184],[24,372],[28,498],[36,246],[43,428],[51,103],[58,457]],
      410=>[[1,33],[1,182],[6,269],[10,319],[15,36],[19,334],[24,207],[28,246],[33,203],[37,368],[42,442],[46,484]],
      411=>[[0,335],[1,335],[1,33],[1,182],[1,269],[1,319],[6,269],[10,319],[15,36],[19,334],[24,207],[28,246],[36,203],[43,368],[51,442],[58,484]],
      412=>[[1,182],[10,33],[15,450],[20,237]],
      413=>[[0,483],[1,483],[1,389],[1,33],[1,182],[1,450],[10,182],[15,450],[20,237],[23,93],[26,75],[29,74],[32,60],[35,445],[38,175],[41,213],[44,94],[47,437],[50,405]],
      414=>[[0,483],[1,483],[1,33],[1,182],[1,450],[10,182],[15,450],[20,237],[23,93],[26,16],[29,77],[32,60],[35,293],[38,318],[41,403],[44,94],[47,679],[50,405]],
      415=>[[1,230],[1,16],[13,450],[29,405]],
      416=>[[0,163],[1,163],[1,565],[1,194],[1,230],[1,16],[1,40],[1,109],[5,210],[9,228],[13,154],[17,455],[25,408],[29,456],[33,92],[37,403],[41,445],[45,454],[49,207],[53,194],[57,565]],
      417=>[[1,45],[1,117],[5,98],[9,204],[13,209],[17,203],[19,609],[21,129],[25,486],[29,186],[33,86],[37,162],[41,435],[45,387],[49,158]],
      418=>[[1,49],[4,45],[7,346],[11,98],[15,55],[18,228],[21,129],[24,453],[27,458],[31,250],[35,13],[38,401],[41,97],[45,56]],
      419=>[[1,423],[1,242],[1,49],[1,45],[1,346],[1,98],[4,45],[7,346],[11,98],[15,55],[18,228],[21,129],[24,453],[29,458],[35,250],[41,13],[46,401],[51,97],[57,56]],
      420=>[[1,234],[1,33],[7,74],[10,73],[13,270],[19,345],[22,241],[28,388],[31,36],[37,76],[40,381],[47,572]],
      421=>[[0,80],[1,80],[1,234],[1,33],[1,74],[1,73],[7,74],[10,73],[13,270],[19,345],[22,241],[30,388],[35,36],[43,76],[48,381],[50,572]],
      422=>[[1,189],[2,300],[4,106],[7,352],[11,426],[16,237],[22,240],[29,34],[37,330],[46,105]],
      423=>[[1,189],[1,300],[1,106],[1,352],[2,300],[4,106],[7,352],[11,426],[16,237],[22,240],[29,34],[41,330],[54,105]],
      424=>[[1,530],[1,10],[1,39],[1,28],[1,310],[4,28],[8,310],[11,226],[15,321],[18,154],[22,129],[25,103],[29,97],[32,458],[36,374],[39,417],[43,387]],
      425=>[[1,132],[1,107],[4,310],[8,16],[13,116],[16,371],[20,466],[25,254],[27,506],[32,256],[32,255],[36,247],[40,133],[44,226],[50,153]],
      426=>[[1,566],[1,132],[1,107],[1,310],[1,16],[4,310],[8,16],[13,116],[16,371],[20,466],[25,254],[27,506],[34,256],[34,255],[40,247],[46,133],[52,226],[60,153],[65,566]],
      427=>[[1,218],[1,111],[1,150],[1,1],[1,193],[6,203],[13,608],[16,98],[23,26],[26,226],[33,97],[36,146],[43,495],[46,204],[50,494],[56,340],[63,361]],
      428=>[[0,216],[1,216],[1,361],[1,340],[1,563],[1,243],[1,277],[1,111],[1,150],[1,1],[1,193],[6,203],[13,608],[16,98],[23,26],[26,226],[33,97],[36,146],[43,495],[46,204],[53,494],[56,340],[63,361],[66,136]],
      429=>[[1,595],[1,408],[1,566],[1,381],[1,345],[1,45],[1,149],[1,180],[1,310]],
      430=>[[1,400],[1,389],[1,310],[1,228],[1,114],[1,17],[25,207],[35,417],[45,492],[55,400],[65,511],[75,399]],
      431=>[[1,252],[5,10],[8,45],[13,95],[17,185],[20,154],[25,204],[29,274],[32,445],[37,163],[41,389],[44,213],[48,468],[50,583]],
      432=>[[0,207],[1,207],[1,252],[1,10],[1,45],[5,10],[8,45],[13,95],[17,185],[20,154],[25,204],[29,274],[32,445],[37,163],[45,34],[52,213],[60,468]],
      433=>[[1,35],[4,45],[7,310],[10,93],[13,281],[16,387],[19,494],[32,253]],
      434=>[[1,10],[1,116],[3,139],[7,103],[9,154],[13,108],[15,364],[19,491],[21,44],[25,163],[27,92],[31,400],[33,262],[37,599],[39,389],[43,562],[45,153]],
      435=>[[0,53],[1,53],[1,10],[1,116],[1,139],[1,103],[3,139],[7,103],[9,154],[13,108],[15,364],[19,491],[21,44],[25,163],[27,92],[31,400],[33,262],[37,599],[39,389],[43,562],[45,153]],
      436=>[[1,33],[1,93],[5,95],[9,286],[11,109],[15,149],[19,334],[21,185],[25,219],[29,248],[31,319],[35,360],[39,326],[41,371],[45,377],[49,484]],
      437=>[[0,335],[1,335],[1,241],[1,240],[1,33],[1,93],[1,95],[1,286],[5,95],[9,286],[11,109],[15,149],[19,334],[21,185],[25,219],[29,248],[31,319],[36,360],[42,326],[46,371],[52,377],[58,484]],
      438=>[[1,313],[1,383],[5,175],[8,67],[12,88],[15,102],[19,185],[22,715],[26,317],[29,335],[33,157],[36,68],[40,389],[43,38]],
      439=>[[1,321],[1,112],[1,1],[1,93],[4,383],[8,96],[11,3],[15,102],[18,227],[22,113],[22,115],[25,60],[29,164],[32,278],[36,271],[39,94],[43,272],[46,226],[50,219]],
      440=>[[1,1],[1,204],[5,383],[9,287],[12,186]],
      441=>[[1,304],[1,448],[1,590],[1,269],[1,64],[5,45],[9,119],[13,47],[17,31],[21,448],[25,269],[29,496],[33,102],[37,497],[41,355],[45,253],[49,485],[50,297],[57,304]],
      442=>[[1,174],[1,228],[1,109],[1,180],[1,425],[7,185],[13,95],[19,138],[25,466],[31,389],[37,417],[43,262],[49,399]],
      443=>[[1,33],[3,28],[7,82],[13,201],[15,36],[19,328],[25,163],[27,337],[31,91],[37,407]],
      444=>[[0,530],[1,530],[1,33],[1,28],[1,82],[3,28],[7,82],[13,201],[15,36],[19,328],[28,163],[33,337],[40,91],[49,407]],
      445=>[[0,242],[1,242],[1,530],[1,424],[1,33],[1,28],[1,82],[1,201],[3,28],[7,82],[13,201],[15,36],[19,328],[28,163],[33,337],[40,91],[55,407]],
      446=>[[1,387],[1,278],[1,122],[1,118],[1,316],[1,33],[4,111],[9,133],[12,122],[17,498],[20,103],[25,34],[28,254],[33,256],[36,205],[41,374],[44,187],[49,363],[50,289],[57,387]],
      447=>[[1,193],[1,98],[1,203],[6,68],[11,364],[15,395],[19,383],[24,103],[29,179],[47,417],[50,515]],
      448=>[[0,396],[1,396],[1,673],[1,193],[1,98],[1,197],[1,232],[6,68],[11,364],[15,612],[19,14],[24,319],[29,198],[33,501],[37,382],[42,526],[47,347],[51,505],[55,370],[60,406],[65,245]],
      449=>[[1,33],[1,28],[7,44],[13,281],[19,36],[19,91],[25,328],[31,242],[37,89],[44,38],[50,90]],
      450=>[[1,423],[1,424],[1,422],[1,33],[1,28],[1,44],[1,281],[7,44],[13,281],[19,36],[19,91],[25,328],[31,242],[40,89],[50,38],[60,90]],
      451=>[[1,44],[1,40],[1,43],[5,282],[9,42],[13,367],[16,228],[20,450],[23,305],[27,474],[30,468],[34,390],[38,400],[41,184],[45,242],[47,565],[49,440]],
      452=>[[1,422],[1,423],[1,424],[1,44],[1,40],[1,43],[1,282],[5,282],[9,42],[13,367],[16,228],[20,450],[23,305],[27,474],[30,468],[34,390],[38,400],[43,184],[49,242],[53,565],[57,440]],
      453=>[[1,310],[3,189],[8,40],[10,269],[15,228],[17,185],[22,279],[24,207],[29,426],[31,389],[36,474],[38,417],[43,398],[45,188],[47,562],[50,260]],
      454=>[[1,310],[1,189],[1,40],[3,189],[8,40],[10,269],[15,228],[17,185],[22,279],[24,207],[29,426],[31,389],[36,474],[41,417],[49,398],[54,188],[58,562],[62,260]],
      455=>[[1,20],[1,74],[7,44],[11,22],[17,230],[21,275],[27,185],[31,536],[37,254],[37,255],[37,256],[41,242],[47,378],[50,438]],
      456=>[[1,1],[6,55],[10,213],[13,240],[17,16],[22,352],[26,445],[29,219],[33,392],[38,250],[42,369],[45,340],[49,318],[54,487]],
      457=>[[1,487],[1,16],[1,1],[1,55],[1,213],[6,55],[10,213],[13,240],[17,16],[22,352],[26,445],[29,219],[35,392],[42,250],[48,369],[53,340],[59,318],[66,487]],
      458=>[[1,33],[1,145],[3,48],[7,61],[11,109],[14,17],[16,29],[19,352],[23,469],[27,36],[32,97],[36,403],[39,392],[46,340],[49,56]],
      459=>[[1,181],[1,43],[5,75],[9,196],[13,320],[17,207],[21,54],[26,420],[31,275],[36,452],[41,59],[46,329]],
      460=>[[1,8],[1,181],[1,43],[1,75],[1,196],[5,75],[9,196],[13,320],[17,207],[21,54],[26,420],[31,275],[36,452],[47,59],[58,329]],
      461=>[[1,373],[1,279],[1,372],[1,10],[1,43],[1,269],[1,98],[8,98],[10,185],[14,196],[16,154],[20,417],[22,232],[25,468],[28,374],[32,103],[35,400],[40,289],[44,386],[47,399]],
      462=>[[1,161],[1,192],[1,602],[1,243],[1,112],[1,604],[1,33],[1,48],[1,84],[1,86],[5,84],[7,86],[11,443],[13,113],[17,49],[19,209],[23,429],[25,319],[29,486],[33,430],[39,103],[43,435],[49,199],[53,393],[59,360],[63,192]],
      463=>[[1,378],[1,438],[1,122],[5,48],[9,111],[13,282],[17,35],[21,23],[25,50],[29,21],[33,205],[37,498],[41,382],[45,287],[49,103],[53,438],[57,378],[61,360]],
      464=>[[1,359],[1,439],[1,32],[1,398],[1,30],[1,39],[1,31],[1,184],[5,31],[9,184],[13,479],[17,23],[21,523],[25,498],[29,350],[33,529],[37,36],[41,444],[48,89],[55,224],[62,32],[69,439]],
      465=>[[1,335],[1,275],[1,132],[4,79],[7,22],[10,71],[14,77],[17,20],[20,74],[23,72],[27,282],[30,78],[33,363],[36,202],[40,246],[43,21],[46,321],[49,378],[50,580],[53,438],[56,335]],
      466=>[[1,604],[1,569],[1,7],[1,98],[1,43],[1,84],[1,67],[5,84],[8,67],[12,129],[15,351],[19,86],[22,486],[26,113],[29,9],[36,435],[42,103],[49,85],[55,87],[62,416],[65,604]],
      467=>[[1,9],[1,123],[1,43],[1,52],[1,108],[5,52],[8,108],[12,185],[15,83],[19,499],[22,481],[26,109],[29,7],[36,436],[42,241],[49,53],[55,126],[62,63]],
      468=>[[1,495],[1,143],[1,245],[1,396],[1,403]],
      469=>[[1,405],[1,403],[1,400],[1,450],[1,33],[1,193],[1,98],[1,104],[6,98],[11,104],[14,49],[17,197],[22,48],[27,253],[30,228],[33,246],[38,364],[43,163],[46,103],[49,369],[54,403],[57,405]],
      470=>[[0,75],[1,75],[1,270],[1,33],[1,39],[5,28],[9,608],[13,98],[17,320],[20,345],[25,202],[29,14],[33,235],[37,241],[41,387],[45,348]],
      471=>[[0,196],[1,196],[1,270],[1,33],[1,39],[5,28],[9,608],[13,98],[17,44],[20,423],[25,420],[29,112],[33,243],[37,258],[41,387],[45,59]],
      472=>[[1,12],[1,422],[1,423],[1,424],[1,398],[1,28],[1,106],[1,282],[4,28],[7,106],[10,282],[13,98],[16,210],[19,185],[22,512],[27,400],[30,369],[35,103],[40,404],[45,327],[50,14],[55,12]],
      473=>[[1,31],[1,184],[1,246],[1,64],[1,316],[1,300],[1,181],[5,300],[8,181],[11,189],[14,203],[18,426],[21,258],[24,423],[28,36],[33,458],[37,54],[41,37],[46,89],[52,59],[58,184]],
      474=>[[1,433],[1,192],[1,277],[1,176],[1,33],[1,160],[1,417],[7,60],[12,97],[18,105],[23,393],[29,324],[34,373],[40,435],[45,199],[50,161],[56,277],[62,192],[67,63]],
      475=>[[0,163],[1,163],[1,500],[1,370],[1,348],[1,400],[1,43],[1,93],[1,104],[1,100],[4,93],[6,104],[9,100],[11,501],[14,210],[17,332],[19,505],[23,469],[26,14],[31,427],[35,270],[40,364],[44,206],[49,182],[53,370],[58,500]],
      476=>[[0,161],[1,161],[1,602],[1,393],[1,356],[1,469],[1,33],[1,334],[1,335],[1,443],[4,334],[7,335],[10,443],[13,86],[16,156],[19,209],[22,157],[25,408],[28,350],[31,435],[34,201],[37,414],[40,444],[43,199],[43,192]],
      477=>[[1,325],[1,248],[1,7],[1,8],[1,9],[1,356],[1,20],[1,43],[1,101],[1,50],[1,310],[6,50],[9,310],[14,193],[17,425],[22,228],[25,261],[30,109],[33,174],[40,506],[45,247],[52,212],[57,371],[64,248]],
      478=>[[0,466],[1,466],[1,194],[1,181],[1,43],[1,104],[1,420],[5,104],[10,420],[14,196],[19,310],[23,577],[28,261],[32,109],[37,358],[41,445],[42,247],[48,59],[54,258],[61,194]],
      479=>[[1,435],[1,268],[1,271],[1,310],[1,86],[1,84],[1,109],[8,253],[15,104],[22,351],[29,466],[36,164],[43,486],[50,506],[57,268],[64,435]],
      480=>[[1,262],[1,363],[1,175],[1,156],[1,93],[6,286],[16,203],[21,129],[31,281],[36,248],[46,133],[50,326],[61,175],[66,363],[76,262]],
      481=>[[1,361],[1,363],[1,383],[1,156],[1,93],[6,286],[16,182],[21,129],[31,381],[36,248],[46,204],[50,326],[61,383],[66,363],[76,361]],
      482=>[[1,363],[1,387],[1,156],[1,93],[6,286],[16,197],[21,129],[31,253],[36,248],[46,417],[50,326],[61,387],[66,363],[76,153]],
      483=>[[1,225],[1,184],[6,232],[10,246],[15,163],[19,408],[24,368],[28,337],[33,414],[37,396],[42,231],[46,459],[50,430]],
      484=>[[1,225],[1,184],[6,352],[10,246],[15,163],[19,408],[24,392],[28,337],[33,414],[37,396],[42,401],[46,460],[50,56]],
      485=>[[1,463],[1,257],[1,414],[1,442],[1,83],[1,246],[9,43],[17,424],[25,319],[33,242],[41,184],[49,436],[57,83],[65,442],[73,414],[81,257],[88,444],[96,463]],
      486=>[[1,484],[1,462],[1,7],[1,8],[1,9],[1,146],[1,282],[1,109],[1,193],[25,279],[40,469],[50,428],[65,371],[75,462],[90,484],[100,416]],
      487=>[[1,225],[1,184],[6,466],[10,246],[15,163],[19,425],[24,194],[28,337],[33,414],[37,396],[42,421],[46,467],[50,506]],
      488=>[[1,461],[1,375],[1,427],[1,236],[1,93],[1,104],[11,219],[20,54],[29,62],[38,248],[47,163],[57,236],[66,427],[75,375],[84,461],[93,94],[99,585]],
      489=>[[1,145],[1,346],[9,204],[16,48],[24,61],[31,151],[39,250],[46,352],[54,392],[61,291],[69,240]],
      490=>[[1,294],[1,145],[1,346],[9,204],[16,48],[24,61],[31,151],[39,250],[46,352],[54,392],[61,291],[69,240],[76,391]],
      491=>[[1,466],[1,50],[11,98],[20,95],[29,185],[38,171],[47,104],[57,114],[66,464],[75,417],[84,138],[93,399]],
      492=>[[1,74],[10,345],[19,73],[28,235],[37,230],[46,363],[55,388],[64,312],[73,412],[82,186],[91,361],[100,465]],
      493=>[[1,69],[1,322],[1,363],[1,386],[10,356],[20,414],[30,304],[40,245],[50,287],[60,248],[70,105],[80,63],[90,195],[100,449]],
      494=>[[1,545],[1,116],[1,93],[1,510],[1,98],[9,203],[17,29],[25,488],[33,179],[41,481],[49,428],[57,517],[65,38],[73,394],[81,515],[89,500],[97,315]],
    }
    # USUM 全可學技能池（level / egg / tutor / machine）：dex => [move_id...]
    MOVE_POOLS = {
      1=>[14,20,22,33,36,38,45,73,74,75,76,77,79,80,92,104,113,124,130,133,156,164,173,174,182,188,202,203,204,207,213,214,216,218,219,230,235,237,241,263,267,275,282,320,345,388,402,412,437,438,447,474,496,497,520,526,580,590],
      2=>[14,20,22,33,36,38,45,73,74,75,76,77,79,92,104,113,156,164,173,182,188,202,207,213,214,216,218,219,230,235,237,241,263,267,282,388,402,412,447,474,496,497,520,526,590],
      3=>[14,20,22,33,36,38,45,46,63,73,74,75,76,77,79,80,89,92,104,113,156,164,173,182,188,200,202,207,213,214,216,218,219,230,235,237,241,263,267,282,335,338,388,402,412,416,447,474,496,497,520,523,526,572,590,707],
      4=>[7,9,10,14,44,45,52,53,68,82,83,92,104,108,126,156,157,163,164,173,182,184,187,200,207,213,214,216,218,231,232,237,241,242,246,251,257,261,263,264,280,314,315,317,332,337,349,374,394,406,407,421,424,481,488,496,497,517,519,526,590],
      5=>[7,9,10,14,45,52,53,82,83,92,104,108,126,156,157,163,164,173,182,184,207,213,214,216,218,231,237,241,257,261,263,264,280,315,317,332,337,374,406,421,424,481,488,496,497,517,519,526,590],
      6=>[7,9,10,14,17,19,45,46,52,53,63,76,82,83,89,92,104,108,126,156,157,163,164,173,182,184,200,207,211,213,214,216,218,231,237,241,257,261,263,264,280,307,315,317,332,337,355,366,374,394,403,406,411,416,421,424,432,481,488,496,497,507,517,519,523,525,526,590,693],
      7=>[8,33,39,44,54,55,56,57,58,59,92,104,110,114,127,130,145,156,164,173,175,182,193,196,207,213,214,216,218,229,231,237,240,243,252,258,263,264,280,281,287,300,317,323,330,334,352,360,362,374,392,396,401,406,428,453,496,503,518,526,590],
      8=>[8,33,39,44,55,56,57,58,59,92,104,110,127,130,145,156,164,173,182,196,207,213,214,216,218,229,231,237,240,258,263,264,280,317,334,352,360,374,401,406,428,496,503,518,526,590],
      9=>[8,33,39,44,46,55,56,57,58,59,63,89,92,104,110,127,130,145,156,157,164,173,182,196,200,207,213,214,216,218,229,231,237,240,258,263,264,280,308,317,324,334,352,360,374,399,401,406,411,416,428,430,479,496,503,518,523,525,526,590,710],
      10=>[33,81,173,450,527],
      11=>[106,334,450,527],
      12=>[16,18,48,60,63,76,77,78,79,92,93,94,104,138,156,164,168,173,182,202,207,213,214,216,218,219,237,240,241,244,247,263,285,318,324,332,355,366,369,403,405,412,416,432,445,450,474,476,483,496,512,527,590,611],
      13=>[40,81,450,527],
      14=>[106,334,450,527],
      15=>[14,31,41,42,63,76,92,97,99,104,116,156,164,168,173,182,188,202,206,207,213,214,216,218,228,237,241,263,280,282,283,332,355,366,369,371,372,390,398,404,416,432,450,474,496,512,527,529,565,590,611,673,675,693],
      16=>[16,17,18,19,28,33,92,97,98,104,119,143,156,164,168,173,182,185,193,207,211,213,214,216,218,228,237,239,240,241,253,257,263,297,314,332,355,366,369,403,413,432,496,526,542,590],
      17=>[16,17,18,19,28,33,92,97,98,104,119,143,156,164,168,173,182,207,211,213,214,216,218,237,239,240,241,253,257,263,297,332,355,366,369,403,432,496,526,542,590],
      18=>[16,17,18,19,28,33,63,92,97,98,104,119,143,156,164,168,173,182,207,211,213,214,216,218,237,239,240,241,253,257,263,297,332,355,366,369,403,416,432,496,526,542,590,673],
      19=>[33,38,39,44,58,59,68,85,86,87,92,98,103,104,116,154,156,158,162,164,168,172,173,179,182,196,207,213,214,216,218,228,231,237,240,241,242,247,253,263,269,279,283,343,351,369,372,382,387,389,428,447,451,496,515,526,528,590],
      20=>[14,33,38,39,44,46,58,59,63,85,86,87,92,98,104,116,156,158,162,164,168,173,182,184,196,207,213,214,216,218,228,231,237,240,241,242,247,253,263,269,283,343,351,369,372,387,389,416,428,447,451,496,526,528,590,675,707],
      21=>[13,18,19,31,43,45,64,65,92,97,98,104,116,119,143,156,161,164,168,173,182,184,185,206,207,211,213,214,216,218,228,237,240,241,253,257,263,297,310,332,355,366,369,372,432,496,497,526,529,590],
      22=>[19,31,43,45,63,64,65,92,97,104,116,119,143,156,164,168,173,182,206,207,211,213,214,216,218,228,237,240,241,253,257,263,332,355,365,366,369,372,416,432,496,497,526,529,590,673,675],
      23=>[20,21,35,40,43,44,50,51,89,92,103,104,114,137,156,157,164,168,173,180,182,184,188,202,207,213,214,216,218,228,231,237,240,241,251,254,255,256,259,263,289,305,317,342,371,380,389,398,399,401,402,415,426,441,474,482,489,491,496,523,562,590,611,693],
      24=>[20,35,40,43,44,51,63,89,92,103,104,114,137,156,157,164,168,173,180,182,188,202,207,213,214,216,218,231,237,240,241,242,254,255,256,259,263,289,317,371,380,398,399,401,402,416,422,423,424,426,441,474,482,489,491,496,523,525,562,590,611,675,693,707],
      25=>[9,21,39,45,84,85,86,87,92,97,98,104,113,156,164,173,182,207,209,213,214,216,218,231,237,240,263,264,270,280,282,324,343,344,351,364,374,393,435,447,451,486,496,497,521,527,528,589,590,609,673],
      26=>[9,39,63,84,85,86,87,92,98,104,113,156,164,168,173,182,207,213,214,216,218,231,237,240,263,264,270,280,282,324,343,351,374,393,411,416,447,451,496,497,521,527,528,590,673],
      27=>[10,14,28,40,68,89,91,92,104,111,129,154,156,157,162,163,164,168,173,175,182,201,203,205,207,210,213,214,216,218,219,222,229,231,232,237,241,263,264,280,282,306,317,328,332,341,343,360,374,398,400,404,414,421,431,446,468,496,498,523,563,590,707],
      28=>[10,14,28,40,63,89,91,92,104,111,129,154,156,157,162,163,164,168,173,182,201,205,207,210,213,214,216,218,219,222,229,231,237,241,263,264,280,282,306,317,328,332,343,360,374,398,404,411,414,416,421,444,446,496,523,590,707],
      29=>[10,24,36,39,40,44,45,48,50,58,59,68,85,87,92,104,116,130,154,156,162,164,168,173,182,188,203,204,207,213,214,216,218,228,231,237,240,241,242,251,260,263,270,305,332,342,351,352,390,398,421,445,474,496,497,498,590,599],
      30=>[10,24,39,40,44,45,58,59,85,87,92,104,154,156,162,164,168,173,182,188,207,213,214,216,218,231,237,240,241,242,260,263,270,305,332,351,352,390,398,421,445,474,496,497,590,707],
      31=>[7,8,9,10,24,34,39,40,46,53,57,58,59,63,85,87,89,92,104,126,156,157,162,164,168,173,182,188,196,200,201,207,213,214,216,218,231,237,240,241,247,253,259,263,264,269,270,276,280,317,332,351,352,374,398,401,406,411,414,416,421,444,446,474,479,482,496,497,498,511,523,525,529,590,675,707],
      32=>[24,30,31,32,36,40,43,48,50,58,59,64,68,85,87,92,93,104,116,133,156,162,164,168,173,182,188,203,207,213,214,216,218,231,237,240,241,251,260,263,270,342,351,352,389,390,398,421,445,457,474,496,497,498,529,590,599,684],
      33=>[24,30,31,32,40,43,58,59,64,85,87,92,104,116,156,162,164,168,173,182,188,207,213,214,216,218,231,237,240,241,260,263,270,351,352,390,398,421,445,474,496,497,529,590,684,707],
      34=>[7,8,9,24,37,40,46,53,57,58,59,63,64,85,87,89,92,104,116,126,156,157,162,164,168,173,182,188,196,200,201,207,213,214,216,218,224,231,237,240,241,247,253,259,263,264,269,270,276,280,317,351,352,374,398,401,406,411,414,416,421,444,446,474,479,482,496,497,498,511,523,525,529,590,675,684,707],
      35=>[1,3,7,8,9,34,45,47,53,58,59,76,85,86,87,92,94,104,107,111,113,115,118,126,138,156,164,173,182,196,207,213,214,215,216,218,219,227,231,236,237,240,241,244,247,263,264,266,270,271,272,277,278,280,282,283,289,304,309,322,324,340,343,347,351,352,356,358,361,374,381,387,409,428,446,447,451,472,473,477,495,496,497,500,516,526,574,585,590,605,671],
      36=>[3,7,8,9,47,53,58,59,63,76,85,86,87,92,94,104,107,113,115,118,126,138,156,164,173,182,196,207,213,214,215,216,218,219,231,237,240,241,244,247,263,264,270,271,272,277,278,280,282,283,289,304,324,340,343,347,351,352,356,374,387,409,411,416,428,446,447,451,472,473,477,495,496,497,526,574,590,605,671,673],
      37=>[39,46,50,52,53,83,92,95,98,104,109,126,156,164,173,175,180,182,185,207,213,214,216,218,219,220,231,237,241,244,257,261,263,272,286,288,290,315,326,336,343,371,384,394,399,412,428,445,481,488,492,496,506,517,541,590,608],
      38=>[46,53,63,76,92,98,104,109,126,138,156,164,173,180,182,207,213,214,216,218,219,220,231,237,241,244,257,261,263,272,286,315,343,347,371,399,412,416,417,428,473,488,492,496,590,673],
      39=>[1,3,7,8,9,34,38,47,50,53,58,59,76,85,86,87,92,94,102,104,111,113,115,126,138,156,164,173,182,196,205,207,213,214,215,216,218,219,220,237,240,241,244,247,254,255,256,263,264,270,272,277,278,280,282,283,289,304,340,343,351,352,356,358,360,374,387,409,446,447,451,477,496,497,502,526,528,574,589,590,605],
      40=>[3,7,8,9,38,47,50,53,58,59,63,76,85,86,87,92,94,104,111,113,115,126,138,156,164,173,182,196,207,213,214,215,216,218,219,220,237,240,241,244,247,263,264,270,272,277,278,280,282,283,289,304,340,343,351,352,356,360,374,387,409,411,416,446,447,451,477,478,496,497,502,526,528,583,590,605,673],
      41=>[16,17,18,19,44,48,71,92,95,98,104,109,114,129,141,156,162,164,168,173,174,182,185,188,202,207,211,212,213,214,216,218,228,237,240,241,247,253,257,259,263,269,289,305,310,314,332,355,366,369,371,403,413,417,428,432,474,496,501,512,590,599],
      42=>[17,19,44,48,63,71,92,103,104,109,114,129,141,156,162,164,168,173,182,188,202,207,211,212,213,214,216,218,237,240,241,247,253,257,259,263,269,289,305,310,314,332,355,366,369,371,403,416,428,432,474,496,501,512,590],
      43=>[14,51,71,72,74,75,76,77,78,79,80,92,104,156,164,173,175,182,188,202,204,207,213,214,216,218,230,235,236,237,241,263,267,275,290,298,321,363,380,381,388,402,412,447,474,495,496,580,585,590,605,611,668],
      44=>[14,51,71,72,74,76,77,78,79,80,92,104,156,164,173,182,188,202,207,213,214,216,218,230,235,236,237,241,263,267,363,374,380,381,388,402,409,412,447,474,495,496,572,580,590,605,611],
      45=>[14,63,72,76,77,78,80,92,104,156,164,173,182,188,202,207,213,214,216,218,219,235,237,241,263,267,312,374,380,388,402,409,412,416,447,474,495,496,572,590,605,611],
      46=>[10,14,60,68,71,73,74,76,77,78,92,97,103,104,113,141,147,156,163,164,168,173,175,182,188,202,203,206,207,210,213,214,216,218,228,230,232,235,237,241,263,267,280,282,312,332,363,388,402,404,412,440,447,450,469,474,476,495,496,563,565,580,590],
      47=>[10,14,63,71,74,76,77,78,92,104,113,141,147,156,163,164,168,173,182,188,202,206,207,210,213,214,216,218,235,237,241,263,267,280,282,312,332,388,402,404,412,416,440,447,450,474,476,495,496,590,675],
      48=>[33,48,50,60,76,77,78,79,92,93,94,97,103,104,141,156,164,168,173,182,188,193,202,207,213,214,216,218,226,234,237,241,263,285,290,305,324,390,428,450,474,476,496,590,611],
      49=>[16,33,48,50,60,63,76,77,78,79,92,93,94,104,141,156,164,168,173,182,188,193,202,207,213,214,216,218,237,241,263,285,305,318,324,332,355,366,369,405,412,416,428,432,450,474,483,496,512,590,611],
      50=>[10,28,29,45,89,90,91,92,103,104,156,157,163,164,168,173,179,182,185,188,189,201,203,207,213,214,216,218,222,228,237,241,246,251,253,262,263,310,317,332,389,414,421,426,446,496,497,515,523,590,707],
      51=>[10,28,45,63,89,90,91,92,104,156,157,161,163,164,168,173,182,188,189,201,207,213,214,216,218,222,237,241,263,310,317,328,332,389,400,414,416,421,426,444,446,482,496,497,523,563,590,707],
      52=>[6,10,39,44,45,85,87,92,95,103,104,133,138,154,156,163,164,168,173,175,180,182,185,196,204,207,213,214,216,218,231,237,240,241,244,247,252,253,259,263,269,274,282,289,304,316,332,343,351,352,364,369,371,372,386,387,399,400,402,417,421,441,445,492,496,497,526,590,675],
      53=>[10,44,45,46,63,85,87,92,103,104,129,138,154,156,163,164,168,173,180,182,185,196,207,213,214,216,218,231,237,240,241,244,247,252,253,259,263,269,282,289,304,332,343,351,352,364,369,371,372,373,387,399,400,402,408,415,416,417,421,441,445,492,496,497,526,583,590,675],
      54=>[8,10,39,50,55,56,57,58,59,60,92,93,94,95,103,104,109,113,127,133,154,156,164,173,182,193,196,207,213,214,216,218,227,231,237,238,240,244,248,258,263,264,272,280,281,287,290,324,332,346,347,352,374,388,401,421,426,428,472,473,477,485,487,493,496,499,503,590],
      55=>[8,10,39,50,55,56,57,58,59,63,67,92,93,94,103,104,113,127,133,154,156,164,173,182,196,207,213,214,216,218,231,237,240,244,258,263,264,272,280,324,332,346,347,352,374,382,388,401,411,416,421,428,453,472,473,477,487,490,496,503,590,673,710],
      56=>[2,7,8,9,10,37,43,67,68,69,85,87,89,92,96,103,104,116,154,156,157,164,168,173,179,180,182,193,200,207,213,214,216,218,227,228,231,237,238,240,241,251,253,263,264,265,269,270,272,279,280,283,315,317,332,339,343,369,370,371,372,374,386,398,400,402,411,441,479,490,496,512,515,523,526,530,590,681,707],
      57=>[2,7,8,9,10,37,43,63,67,69,85,87,89,92,99,103,104,116,154,156,157,164,168,173,180,182,200,207,213,214,216,218,228,231,237,238,240,241,253,263,264,269,270,272,280,283,315,317,332,339,343,369,370,371,372,374,386,398,402,411,416,441,444,479,490,496,512,515,523,526,530,590,675,707],
      58=>[24,34,36,37,38,43,44,46,52,53,83,92,97,104,126,156,164,168,172,173,179,182,200,207,213,214,216,218,219,231,234,237,241,242,257,261,263,270,315,316,332,336,343,370,394,424,481,488,496,514,528,555,590,682],
      59=>[44,46,53,63,76,92,104,126,156,164,168,173,182,200,207,213,214,216,218,219,231,237,241,245,257,261,263,270,315,316,332,343,406,416,422,424,442,488,496,523,528,555,590,673],
      60=>[3,34,54,55,56,57,58,59,61,92,94,95,104,114,127,145,150,156,164,168,170,173,182,187,196,203,207,213,214,216,218,227,237,240,258,263,270,283,287,301,341,346,352,358,426,496,503,590],
      61=>[3,8,34,55,56,57,58,59,61,89,92,94,95,104,127,145,156,164,168,173,182,187,196,207,213,214,216,218,237,240,258,263,264,270,280,283,341,346,352,358,374,426,496,503,523,590],
      62=>[3,8,57,58,59,61,63,66,89,92,94,95,104,127,156,157,164,168,170,173,182,196,207,213,214,216,218,223,237,240,258,263,264,270,280,283,317,339,352,371,374,398,411,416,490,496,503,509,523,526,530,590,675],
      63=>[7,8,9,86,92,94,100,104,112,113,115,138,156,164,168,173,182,207,213,214,216,218,219,227,231,237,240,241,244,247,259,263,264,269,271,272,277,278,282,285,289,324,347,351,356,373,374,375,379,385,409,412,428,433,447,451,470,472,473,477,478,492,496,502,590,605,678],
      64=>[7,8,9,50,60,86,92,93,94,100,104,105,113,115,134,138,156,164,168,173,182,207,213,214,216,218,219,231,237,240,241,244,247,248,259,263,264,269,271,272,277,278,282,285,289,324,347,351,356,357,373,374,409,412,427,428,433,447,451,472,473,477,478,492,496,502,590,605],
      65=>[7,8,9,50,60,63,86,92,93,94,100,104,105,113,115,134,138,156,164,168,173,182,207,213,214,216,218,219,231,237,240,241,244,247,248,259,263,264,269,271,272,277,278,282,285,289,324,347,351,356,357,373,374,409,411,412,416,427,428,433,447,451,472,473,477,478,492,496,502,590,605,673],
      66=>[2,7,8,9,27,43,53,66,67,68,69,89,92,96,104,113,116,126,156,157,164,168,173,182,184,193,207,213,214,216,218,223,227,233,237,238,240,241,263,264,265,270,272,276,279,280,282,317,321,339,358,370,371,374,379,398,411,418,479,484,490,496,501,523,526,530,590],
      67=>[2,7,8,9,43,53,66,67,69,89,92,104,113,116,126,156,157,164,168,173,182,184,193,207,213,214,216,218,223,233,237,238,240,241,263,264,270,272,276,279,280,282,317,339,358,371,374,398,411,479,490,496,523,526,530,590,707],
      68=>[2,7,8,9,43,53,63,66,67,69,70,89,92,104,113,116,126,156,157,164,168,173,182,184,193,207,213,214,216,218,223,233,237,238,240,241,263,264,270,272,276,279,280,282,317,339,358,371,374,398,411,416,444,469,479,490,496,523,526,530,590,675,707],
      69=>[14,20,21,22,35,51,74,75,76,77,78,79,92,104,115,141,156,164,168,173,182,188,202,207,213,214,216,218,227,230,235,237,241,263,267,275,282,311,321,331,345,363,378,380,388,398,402,412,438,447,474,491,496,499,562,590,611,668],
      70=>[14,20,21,22,35,51,74,75,76,77,78,79,92,104,115,156,164,168,173,182,188,202,207,213,214,216,218,230,235,237,241,263,267,282,378,380,388,398,402,412,447,474,496,590,611],
      71=>[14,20,22,63,75,76,79,92,104,115,156,164,168,173,182,188,202,207,213,214,216,218,230,235,237,241,254,255,256,263,267,282,348,380,388,398,402,412,416,437,447,474,496,536,590,611],
      72=>[14,20,35,40,48,51,56,57,58,59,61,62,92,103,104,109,112,114,127,132,145,156,164,168,173,182,188,196,202,207,213,214,216,218,219,229,237,240,243,258,263,277,282,321,330,352,362,367,371,378,390,392,398,474,482,491,496,503,506,590,605,611],
      73=>[14,20,35,40,48,51,56,57,58,59,61,63,92,103,104,112,127,132,156,164,168,173,182,188,196,202,207,213,214,216,218,219,237,240,258,263,277,282,352,362,371,378,390,398,416,474,482,491,496,503,506,513,590,605,611],
      74=>[5,7,9,33,38,53,88,89,92,104,111,120,126,153,156,157,164,173,174,175,182,201,203,205,207,213,214,216,218,222,237,241,263,264,267,276,280,300,317,334,335,350,359,360,374,397,414,431,444,446,469,475,479,496,523,590],
      75=>[7,9,33,38,53,88,89,92,104,111,120,126,153,156,157,164,173,182,201,205,207,213,214,216,218,222,237,241,263,264,267,276,280,300,317,334,335,350,360,374,397,414,444,446,479,496,523,590,707],
      76=>[7,9,33,38,46,53,63,88,89,92,104,111,120,126,153,156,157,164,173,182,201,207,213,214,216,218,222,237,241,263,264,267,276,280,300,317,334,335,350,360,374,397,411,414,416,442,444,446,479,484,496,523,537,590,707],
      77=>[23,24,32,33,36,37,38,39,45,52,53,67,76,83,92,95,97,104,126,156,164,172,173,182,204,207,213,214,216,218,231,234,237,241,257,261,263,315,340,394,445,488,496,497,502,517,528,590,667],
      78=>[23,31,36,39,45,52,53,63,67,76,83,92,97,98,104,126,156,164,172,173,182,207,213,214,216,218,224,231,237,241,257,261,263,315,340,394,398,416,488,496,497,502,517,528,529,590,675,684],
      79=>[23,29,33,45,50,53,55,57,58,59,86,89,92,93,94,104,113,126,133,138,156,164,173,174,182,187,196,207,213,214,216,218,219,231,237,240,241,244,247,248,258,263,271,277,278,281,285,300,303,324,335,347,352,382,401,428,433,447,472,473,477,495,496,497,503,505,523,562,590],
      80=>[8,29,33,45,50,53,55,57,58,59,63,86,89,92,93,94,104,110,113,126,133,138,156,164,173,174,182,196,207,213,214,216,218,219,231,237,240,241,244,247,258,263,264,271,277,278,280,281,285,303,324,332,334,335,347,352,374,401,409,411,416,428,433,447,472,473,477,492,495,496,497,503,505,523,590],
      81=>[33,48,49,84,85,86,87,92,103,104,113,115,153,156,164,173,182,192,199,207,209,214,216,218,237,240,241,244,263,277,278,319,324,334,351,356,360,393,429,430,435,443,451,486,496,521,527,528,590],
      82=>[33,48,49,63,84,85,86,87,92,103,104,113,115,153,156,161,164,173,182,192,199,207,209,214,216,218,237,240,241,244,263,277,278,319,324,334,351,356,360,393,416,429,430,435,443,451,486,496,521,527,528,590,604],
      83=>[14,16,19,28,31,43,64,92,97,98,104,119,143,156,163,164,168,173,174,175,182,189,193,206,207,210,211,213,214,216,218,231,237,241,244,253,257,263,270,279,282,297,314,332,343,348,355,364,366,369,376,387,398,400,403,413,432,493,496,512,515,526,590,660,673,675,693],
      84=>[14,19,26,31,37,45,48,64,65,92,97,98,99,104,114,119,156,164,168,173,175,182,185,207,211,213,214,216,218,228,237,241,253,263,282,283,332,355,363,365,367,372,413,458,496,497,526,590],
      85=>[14,19,26,31,37,45,63,64,65,92,97,98,99,104,143,156,161,164,168,173,182,207,211,213,214,216,218,228,237,241,253,259,263,269,282,283,332,355,365,367,371,416,458,496,497,526,590,707],
      86=>[21,29,32,36,45,50,57,58,59,62,92,104,122,127,156,164,168,173,182,195,196,207,213,214,216,218,219,227,231,237,240,252,254,255,256,258,263,291,324,333,346,352,362,374,392,401,420,453,494,496,497,529,562,590,684],
      87=>[29,36,45,57,58,59,62,63,92,104,127,156,164,168,173,182,196,207,213,214,216,218,219,227,231,237,240,258,263,291,324,329,352,362,374,392,401,416,420,453,496,497,524,529,590,684,710],
      88=>[1,7,8,9,50,53,85,87,92,103,104,106,107,114,122,124,126,139,151,153,156,157,164,168,173,174,182,184,188,189,202,207,212,213,214,216,218,220,237,240,241,247,254,255,256,259,262,263,269,286,317,325,351,371,374,398,425,426,441,474,482,491,496,562,590,611,612],
      89=>[1,7,8,9,50,53,63,85,87,92,103,104,106,107,124,126,139,151,153,156,157,164,168,173,182,188,189,202,207,213,214,216,218,220,237,240,241,247,259,262,263,264,269,280,317,335,351,371,374,398,399,411,416,426,441,474,482,496,562,590,599,611],
      90=>[33,36,41,43,48,55,56,57,58,59,61,62,92,103,104,110,112,128,153,156,164,173,182,196,207,213,214,216,218,229,237,240,250,258,263,333,334,341,350,352,362,371,392,419,420,496,504,534,590,710],
      91=>[48,56,57,58,59,62,63,92,104,110,131,153,156,164,173,182,191,196,207,213,214,216,218,237,240,258,259,263,324,334,352,371,390,398,416,496,504,524,556,590,684,710],
      92=>[7,8,9,50,85,92,94,95,101,104,109,114,122,123,138,149,153,156,164,168,171,173,174,180,182,184,188,194,195,196,202,207,212,213,214,216,218,220,237,240,241,244,247,253,259,261,263,269,271,282,285,288,289,310,371,373,389,399,412,433,472,474,477,492,496,499,502,506,513,590,605,611],
      93=>[7,8,9,85,92,94,95,101,104,109,122,138,153,156,164,168,171,173,174,180,182,188,194,196,202,207,212,213,214,216,218,220,237,240,241,244,247,253,259,261,263,269,271,282,285,289,325,371,373,374,389,398,399,412,421,433,472,474,477,492,496,502,506,590,605,611],
      94=>[7,8,9,63,85,87,92,94,95,101,104,109,122,138,153,156,164,168,171,173,174,180,182,188,194,196,202,207,212,213,214,216,218,220,237,240,241,244,247,253,259,261,263,264,269,271,272,280,282,285,289,325,371,373,374,389,398,399,409,411,412,416,421,433,472,474,477,492,496,502,506,590,605,611,673],
      95=>[20,21,33,38,46,88,89,91,92,99,103,104,106,111,153,156,157,164,173,174,175,182,201,205,207,213,214,216,218,225,231,237,241,244,259,263,267,269,300,317,328,335,350,360,371,397,406,414,430,431,442,444,446,469,479,484,496,523,525,563,590,693,707],
      96=>[1,7,8,9,29,50,60,67,86,92,93,94,95,96,104,112,113,115,138,139,156,164,168,173,182,207,213,214,216,218,219,237,240,241,244,247,248,259,260,263,264,269,271,272,274,277,278,280,285,289,290,324,347,358,374,385,409,417,427,428,433,447,471,473,477,478,485,490,492,496,502,590,605,678],
      97=>[1,7,8,9,29,50,60,63,67,86,92,93,94,95,96,104,113,115,138,139,156,164,168,171,173,182,207,213,214,216,218,219,237,240,241,244,247,248,259,263,264,269,271,272,277,278,280,285,289,324,347,358,374,409,411,415,416,417,428,433,447,473,477,478,485,490,492,496,502,590,605],
      98=>[11,12,14,21,23,43,57,58,59,61,92,97,104,106,114,117,133,145,152,156,157,164,168,173,175,182,196,203,206,207,213,214,216,218,232,237,240,246,258,263,276,280,282,300,317,321,334,341,352,362,374,404,496,498,502,503,590,710],
      99=>[11,12,14,21,23,43,57,58,59,61,63,92,104,106,145,152,156,157,164,168,173,175,182,196,206,207,213,214,216,218,232,237,240,258,263,276,280,282,300,317,334,341,352,362,374,404,416,469,496,502,503,511,590,707,710],
      100=>[33,49,85,86,87,92,103,104,113,120,129,153,156,164,168,173,182,205,207,209,214,216,218,237,240,243,259,263,268,269,277,324,351,360,393,435,451,486,492,496,521,528,590,598],
      101=>[33,49,63,85,86,87,92,103,104,113,120,129,153,156,164,168,173,182,205,207,209,214,216,218,237,240,243,259,263,268,269,277,324,351,360,393,416,435,451,477,486,492,496,521,528,590,598,602],
      102=>[14,73,76,77,78,79,92,93,94,95,104,113,115,138,140,153,156,164,168,173,174,182,188,202,207,213,214,216,218,235,236,237,241,244,246,253,263,267,275,285,326,331,335,356,363,381,384,388,402,412,433,437,447,477,496,516,580,590,611],
      103=>[14,23,63,67,76,92,93,94,95,104,113,115,121,138,140,153,156,164,168,173,182,188,202,207,213,214,216,218,235,237,241,244,263,267,285,335,356,388,402,412,416,428,433,437,447,452,473,477,496,590,611,707],
      104=>[7,9,14,24,29,37,38,39,43,45,53,58,59,67,89,92,99,103,104,116,125,126,130,155,156,157,164,168,173,174,182,187,195,196,197,198,201,203,206,207,213,214,216,218,231,237,241,246,253,263,264,280,282,283,317,332,334,374,414,442,446,479,496,497,498,514,523,590,693,707],
      105=>[7,9,14,29,37,38,39,43,45,53,58,59,63,67,89,92,99,104,116,125,126,155,156,157,164,168,173,182,196,198,200,201,206,207,213,214,216,218,231,237,241,253,263,264,280,282,283,317,332,334,374,411,414,416,442,444,446,479,496,497,514,523,590,673,675,693,707],
      106=>[24,25,26,27,67,89,92,96,104,116,136,156,157,164,168,170,173,179,182,193,203,207,213,214,216,218,237,240,241,263,264,270,272,276,279,280,282,299,317,339,340,343,364,370,374,398,411,444,469,490,496,523,526,590,673,707],
      107=>[4,5,7,8,9,67,68,89,92,97,104,156,157,164,168,173,182,183,197,207,213,214,216,218,228,237,240,241,263,264,270,272,279,280,317,327,339,343,364,370,374,409,410,411,418,444,490,496,501,523,526,590,673,675],
      108=>[7,8,9,14,20,21,23,34,35,37,48,50,53,57,58,59,63,76,85,87,89,92,103,104,111,122,126,133,138,156,157,164,168,173,174,182,187,196,201,205,207,213,214,216,218,222,231,237,240,241,244,247,263,264,265,280,282,287,317,330,351,352,359,374,378,382,401,416,428,438,496,498,523,525,526,562,590,693,707],
      109=>[33,53,60,85,87,92,103,104,108,114,120,123,124,126,139,149,153,156,164,168,173,174,180,182,188,194,207,213,214,216,218,220,237,240,241,247,253,254,255,256,259,261,262,263,269,288,351,360,371,372,390,399,474,496,499,562,590,599,611],
      110=>[33,53,63,85,87,92,104,108,114,120,123,124,126,139,153,156,164,168,173,180,182,188,194,207,213,214,216,218,220,237,240,241,247,253,259,261,262,263,269,351,360,371,372,399,416,458,474,496,499,562,590,611],
      111=>[14,23,30,31,32,36,39,46,53,58,59,68,85,87,89,92,104,126,130,156,157,164,168,173,174,179,180,182,184,196,201,207,213,214,216,218,222,224,231,237,240,241,242,253,263,276,283,306,317,350,351,368,371,397,398,401,406,407,414,422,423,424,431,444,446,470,479,496,498,523,529,563,590,684,707],
      112=>[7,8,9,14,23,30,31,32,36,39,46,53,57,58,59,63,85,87,89,92,104,126,156,157,164,168,173,180,182,184,196,200,201,207,213,214,216,218,224,231,237,240,241,253,263,264,276,280,283,317,335,350,351,359,371,374,397,398,401,406,411,414,416,421,444,446,479,496,498,523,525,529,590,684,693,707],
      113=>[1,3,7,8,9,36,38,39,45,47,53,58,59,63,68,69,76,85,86,87,89,92,94,104,107,111,113,118,121,126,135,138,156,157,164,173,182,196,201,203,207,213,214,215,216,217,218,219,231,237,240,241,244,247,258,263,264,270,278,280,283,285,287,289,304,312,317,343,347,351,352,356,361,363,374,387,409,416,426,428,446,447,451,477,496,497,502,505,516,523,526,528,590,605,673,707],
      114=>[14,20,21,22,63,71,72,73,74,76,77,78,79,92,93,104,115,132,133,156,164,168,173,175,182,188,202,207,213,214,216,218,220,235,237,241,244,246,263,267,275,282,283,321,351,358,363,378,384,388,402,412,416,437,438,447,476,496,580,590,611],
      115=>[4,5,7,8,9,23,38,39,43,44,46,50,53,57,58,59,63,67,68,76,85,87,89,92,99,104,116,126,146,156,157,164,168,173,179,180,182,193,196,200,201,203,207,213,214,216,218,219,231,237,240,241,242,247,252,253,258,263,264,270,280,283,306,317,332,343,351,352,359,374,376,389,401,409,411,416,421,458,496,498,509,523,526,590],
      116=>[13,43,50,55,56,57,58,59,61,62,82,92,97,104,108,116,127,145,150,156,164,173,175,182,190,196,200,207,213,214,216,218,225,237,239,240,258,263,324,330,340,349,352,362,406,430,496,499,503,590],
      117=>[43,55,56,57,58,59,61,63,92,97,104,108,116,127,145,156,164,173,182,196,200,207,213,214,216,218,237,239,240,258,263,324,340,349,352,362,406,416,430,496,503,590,673],
      118=>[30,31,32,34,39,48,56,57,58,59,60,64,92,97,104,114,127,130,156,164,173,175,182,189,196,207,213,214,216,218,224,237,240,258,263,282,300,324,340,341,346,352,392,398,401,487,496,503,529,590,675,684],
      119=>[30,31,32,39,48,57,58,59,63,64,92,97,104,127,156,164,173,175,182,196,207,213,214,216,218,224,237,240,258,263,282,324,340,346,352,392,398,401,416,487,496,503,529,590,675,684],
      120=>[33,55,56,57,58,59,61,85,86,87,92,94,104,105,106,107,109,113,115,127,129,149,156,164,173,182,196,207,214,216,218,220,229,237,240,244,258,263,277,278,293,322,324,352,356,360,362,408,430,496,503,513,590,605],
      121=>[55,56,57,58,59,63,85,86,87,92,94,104,105,109,113,115,127,129,138,156,164,173,182,196,207,214,216,218,220,229,237,240,244,258,263,271,277,278,285,324,352,356,360,416,430,433,447,472,473,477,496,502,503,590,605,671],
      122=>[1,3,7,8,9,60,63,76,85,86,87,92,93,94,95,96,102,104,109,112,113,115,138,149,156,164,168,173,182,196,207,213,214,216,218,219,226,227,237,240,241,244,247,248,252,259,263,264,269,270,271,272,277,278,280,285,289,298,324,332,334,343,345,347,351,358,371,374,383,384,385,409,411,412,416,417,428,433,447,451,469,471,472,473,477,478,492,496,501,502,581,590,605,611,678],
      123=>[13,14,17,43,63,68,92,97,98,104,113,116,156,163,164,168,173,179,182,203,206,207,210,211,213,214,216,218,219,226,228,237,240,241,263,280,282,318,332,355,364,366,369,400,403,404,405,410,416,432,450,458,496,501,590,673,693],
      124=>[1,3,8,34,58,59,63,92,94,104,113,115,122,138,142,156,164,168,173,181,182,195,196,207,212,213,214,215,216,218,237,240,244,247,258,259,263,264,269,270,271,272,277,278,280,285,304,313,324,343,347,352,358,371,374,378,409,411,412,416,419,428,433,447,472,473,477,478,496,497,502,524,531,577,590,694],
      125=>[7,8,9,43,63,67,84,85,86,87,92,94,98,103,104,113,129,156,164,168,173,182,207,213,214,216,218,231,237,240,263,264,270,280,324,343,351,374,393,411,416,435,451,486,490,496,521,527,528,530,590],
      126=>[7,9,43,52,53,63,67,83,92,94,104,108,109,123,126,156,164,168,173,182,185,207,213,214,216,218,231,237,241,257,261,263,264,270,280,315,343,374,411,416,436,481,488,490,496,499,530,590],
      127=>[11,12,14,20,31,37,63,66,69,89,92,98,104,106,116,156,157,164,168,173,175,182,185,206,207,213,214,216,218,233,237,240,241,263,264,276,279,280,282,317,334,339,364,370,374,382,404,411,416,444,446,450,458,479,480,496,523,590,675,693],
      128=>[30,33,36,37,38,39,53,57,58,59,63,76,85,87,89,92,99,104,126,156,157,164,173,180,182,184,196,200,201,207,213,214,216,218,228,231,237,240,241,253,263,270,272,283,317,351,352,371,416,428,442,444,496,523,526,528,590,684,707],
      129=>[33,150,175,340],
      130=>[37,43,44,46,53,56,57,58,59,63,82,85,86,87,89,92,104,126,127,156,164,173,180,182,184,196,200,201,207,213,214,216,218,231,237,239,240,242,253,258,259,263,269,340,349,352,371,399,401,406,416,423,442,444,496,503,523,525,542,590,693],
      131=>[32,34,45,46,47,54,55,56,57,58,59,63,85,87,90,92,94,104,109,127,138,156,164,173,174,182,193,195,196,200,207,213,214,215,216,218,219,231,237,240,246,248,250,258,263,287,304,321,324,329,335,349,351,352,362,401,406,416,419,420,428,442,496,497,523,524,529,573,590,684],
      132=>[144],
      133=>[28,33,36,38,39,44,45,92,98,104,129,156,164,173,174,175,182,197,203,204,207,213,214,215,216,218,226,231,237,240,241,247,263,270,273,281,287,304,313,321,343,363,376,387,445,485,496,497,500,526,590,608,673],
      134=>[28,33,39,46,55,56,57,58,59,62,63,92,98,104,114,127,151,156,164,173,182,196,207,213,214,215,216,218,231,237,240,241,247,258,263,270,304,324,330,343,352,387,392,401,416,496,497,503,526,590,608,673],
      135=>[24,28,33,39,42,46,63,84,85,86,87,92,97,98,104,113,156,164,173,182,207,213,214,215,216,218,231,237,240,241,247,263,270,304,324,343,351,387,393,416,422,435,451,496,497,521,526,528,590,608,673],
      136=>[28,33,39,44,46,52,53,63,83,92,98,104,123,126,156,164,173,182,184,207,213,214,215,216,218,231,237,240,241,247,257,261,263,270,276,304,315,343,387,394,416,424,436,488,496,497,526,590,608,673],
      137=>[33,58,59,60,63,76,85,86,87,92,94,97,104,105,138,156,159,160,161,164,168,173,176,182,192,196,199,207,214,216,218,220,231,237,240,241,244,247,263,271,277,278,324,332,351,356,387,393,416,428,433,435,451,472,473,477,492,496,502,527,590],
      138=>[20,21,43,44,48,55,56,57,58,59,61,62,92,104,110,114,117,127,132,156,157,164,168,173,182,191,196,201,205,207,213,214,216,218,237,240,246,250,258,263,282,317,321,330,334,341,350,352,360,362,378,390,397,414,446,479,496,503,504,513,590],
      139=>[20,43,44,55,56,57,58,59,63,92,104,110,127,131,132,156,157,164,168,173,182,196,201,205,207,213,214,216,218,237,240,246,258,263,282,317,321,334,341,350,352,360,362,397,414,416,444,446,479,496,503,504,590],
      140=>[10,28,36,43,57,58,59,61,62,71,72,92,103,104,106,109,127,156,157,164,168,173,175,182,193,196,201,202,203,207,213,214,216,218,229,237,240,246,258,263,282,317,319,332,334,341,352,378,397,414,446,453,479,496,503,590],
      141=>[10,14,28,43,57,58,59,63,67,71,72,92,104,106,127,156,157,163,164,168,173,182,196,201,202,203,207,213,214,216,218,237,240,246,258,263,267,276,280,282,317,319,332,334,341,352,364,378,397,400,401,404,414,416,444,446,453,479,496,503,590,710],
      142=>[17,18,19,36,44,46,48,53,63,89,92,97,104,126,143,156,157,164,168,173,174,182,184,193,201,207,211,213,214,216,218,225,228,231,237,240,241,242,246,257,259,263,269,317,332,337,355,366,371,372,397,401,406,414,416,422,423,424,432,442,444,446,469,479,496,507,523,590,673,693],
      143=>[7,8,9,18,33,34,38,53,57,58,59,63,68,76,85,87,89,90,92,94,104,111,122,126,133,156,157,164,173,174,182,187,196,200,201,204,205,207,213,214,216,218,228,237,240,241,242,247,263,264,276,278,280,281,289,304,317,335,343,351,352,363,374,387,402,411,416,428,441,442,479,484,495,496,498,523,526,528,562,590,612,667,707],
      144=>[16,19,46,54,58,59,63,92,97,104,115,143,156,164,170,173,181,182,196,201,207,211,214,216,218,237,240,241,246,258,263,324,329,332,352,355,366,369,416,420,432,496,507,524,542,573,590,673,694],
      145=>[19,46,63,64,65,84,85,86,87,92,97,104,113,143,156,164,173,182,192,197,201,207,211,214,216,218,237,240,241,246,257,263,268,324,332,351,355,365,366,369,416,432,435,451,496,507,521,528,590,602,673],
      146=>[17,19,46,52,53,63,76,83,92,97,104,126,143,156,164,173,182,201,203,207,211,214,216,218,219,237,240,241,246,257,261,263,315,332,355,366,369,403,416,432,488,496,507,542,590,673,682],
      147=>[20,21,35,43,48,53,54,57,58,59,63,82,85,86,87,92,97,104,113,114,126,127,156,164,173,182,196,200,207,213,214,216,218,219,225,231,237,239,240,241,245,258,263,349,351,352,401,406,407,434,453,496,525,590,693],
      148=>[20,21,35,43,53,57,58,59,63,82,85,86,87,92,97,104,113,126,127,156,164,173,182,196,200,207,213,214,216,218,219,231,237,239,240,241,258,263,349,351,352,401,406,407,434,496,525,590,693],
      149=>[7,8,9,17,19,20,21,35,43,46,53,57,58,59,63,82,85,86,87,89,92,97,104,113,126,127,156,157,164,173,182,196,200,201,207,211,213,214,216,218,219,231,237,239,240,241,257,258,263,264,276,280,317,332,337,349,351,352,355,366,374,401,406,407,411,416,432,434,442,444,496,507,523,525,542,590,693],
      150=>[7,8,9,50,53,54,58,59,63,67,76,85,86,87,89,92,93,94,104,105,112,113,115,126,129,133,138,149,156,157,164,173,182,196,201,207,214,216,218,219,231,237,240,241,244,247,248,258,259,261,263,264,269,271,272,277,278,280,285,289,317,324,332,339,347,351,352,356,357,373,374,382,384,385,396,398,401,409,411,412,416,427,428,433,444,447,451,472,473,477,478,490,492,496,523,540,590,673,693],
      151=>[1,5,7,8,9,14,19,20,46,53,57,58,59,63,67,76,85,86,87,89,92,94,104,112,113,115,118,126,127,133,138,141,143,144,153,156,157,162,164,168,173,180,182,188,196,200,201,202,206,207,211,213,214,215,216,218,219,220,226,231,235,237,240,241,244,246,247,253,257,258,259,261,263,264,267,269,270,271,272,276,277,278,280,282,283,285,289,304,315,317,324,332,334,335,337,339,340,343,347,351,352,355,356,360,366,369,371,373,374,380,382,387,388,393,396,397,398,399,401,402,404,406,409,411,412,414,416,417,421,428,430,432,433,441,442,444,446,447,450,451,472,473,474,477,478,479,482,488,490,492,495,496,497,502,503,507,511,512,513,521,523,524,525,526,527,528,529,530,555,590,605,611,673,675,684,693,694,707,710],
      152=>[14,22,33,34,45,68,73,75,76,77,92,104,113,115,156,164,173,175,182,202,207,213,214,216,218,219,230,231,235,237,241,246,263,267,275,277,287,312,320,345,363,378,388,402,412,437,447,496,497,505,520,526,580,590],
      153=>[14,33,34,45,75,76,77,92,104,113,115,156,164,173,182,202,207,213,214,216,218,219,230,231,235,237,241,263,267,277,312,345,363,388,402,412,447,496,497,520,526,590,673],
      154=>[14,33,34,45,63,75,76,77,80,89,92,104,113,115,156,164,173,182,200,202,207,213,214,216,218,219,230,231,235,237,241,263,267,277,312,338,345,363,388,402,412,416,447,496,497,520,523,525,526,572,590,673,707],
      155=>[24,33,37,38,43,52,53,92,98,104,108,111,126,129,154,156,164,172,173,179,182,193,205,207,213,214,216,218,237,241,257,261,263,267,284,306,315,326,332,336,343,394,436,481,488,496,517,519,526,528,590,682],
      156=>[33,38,43,46,52,53,92,98,104,108,111,126,129,156,164,172,173,182,205,207,213,214,216,218,237,241,257,261,263,264,267,280,284,315,332,343,436,488,496,517,519,526,528,590,682],
      157=>[7,9,33,38,43,46,52,53,63,67,76,89,92,98,104,108,111,126,129,156,157,164,172,173,182,205,207,213,214,216,218,237,241,257,261,263,264,267,280,284,307,315,317,332,343,360,374,411,416,421,436,488,496,517,519,523,526,528,590,673,675,682,707],
      158=>[8,10,14,37,43,44,55,56,57,58,59,67,92,99,103,104,127,156,157,163,164,173,175,180,182,184,196,207,213,214,216,218,231,232,237,240,242,246,253,258,260,263,264,276,280,300,313,317,332,335,337,346,349,352,374,401,421,423,453,496,498,503,518,526,590],
      159=>[8,10,14,37,43,44,46,55,56,57,58,59,67,92,99,103,104,127,156,157,163,164,173,175,180,182,184,196,207,213,214,216,218,231,237,240,242,253,258,263,264,276,280,317,332,335,337,352,374,401,421,423,496,498,503,518,526,590],
      160=>[8,10,14,37,43,44,46,55,56,57,58,59,63,67,89,92,97,99,103,104,127,156,157,163,164,173,175,180,182,184,196,200,207,213,214,216,218,231,237,240,242,253,258,263,264,276,280,308,317,332,335,337,352,374,401,406,411,416,421,423,496,498,503,518,523,525,526,590,710],
      161=>[7,8,9,10,21,38,53,57,58,76,85,92,98,104,111,116,133,154,156,162,163,164,168,173,179,182,193,204,207,213,214,216,218,226,228,231,237,240,241,247,253,263,264,266,270,271,274,280,282,304,343,351,352,363,369,374,382,387,389,401,421,445,447,451,496,497,526,590,608,693],
      162=>[7,8,9,10,21,53,57,58,59,63,76,85,87,92,97,98,104,111,133,154,156,162,164,168,173,182,193,207,213,214,216,218,226,231,237,240,241,247,253,263,264,266,270,271,280,282,304,343,351,352,369,374,382,387,389,401,411,416,421,447,451,489,496,497,526,590,693],
      163=>[17,18,19,33,36,45,48,64,92,93,94,95,97,101,104,115,119,138,143,156,164,168,173,182,185,193,207,211,212,213,214,216,218,237,240,241,244,247,253,257,263,277,278,297,304,326,332,355,366,375,403,428,432,485,496,497,526,542,585,590],
      164=>[19,33,36,45,63,64,92,93,94,95,104,115,138,143,156,164,168,173,182,193,207,211,213,214,216,218,237,240,241,244,247,253,257,263,277,278,304,326,332,355,366,375,403,416,428,432,485,496,497,526,585,590,673],
      165=>[4,8,9,14,33,38,48,60,68,76,92,97,103,104,113,115,117,129,146,156,164,168,173,182,183,202,203,207,213,214,216,218,219,226,227,237,241,253,263,264,280,282,318,332,355,366,369,374,403,405,409,450,496,512,590,611],
      166=>[4,8,9,14,33,38,48,63,76,92,97,104,113,115,129,156,164,168,173,182,183,202,207,213,214,216,218,219,226,237,241,253,263,264,280,282,318,332,355,366,369,374,403,405,409,411,416,432,450,496,512,590,611],
      167=>[40,41,42,49,50,60,71,76,81,92,94,97,101,104,132,141,154,156,164,168,169,173,182,184,188,202,207,213,214,216,218,224,226,228,237,241,263,324,340,389,390,398,400,404,425,440,450,474,476,492,496,527,564,590,611,672,679],
      168=>[14,40,42,63,71,76,81,92,94,97,101,104,116,132,141,154,156,164,168,169,173,182,184,188,202,207,213,214,216,218,237,241,263,324,340,389,398,404,416,425,440,450,474,492,496,527,564,565,590,599,611,672,675,684,707],
      169=>[17,19,44,48,63,71,92,103,104,109,114,129,141,143,156,162,164,168,173,182,188,202,207,211,212,213,214,216,218,237,240,241,247,253,257,259,263,269,289,305,310,314,332,355,366,369,371,399,403,404,416,428,432,440,474,496,501,512,590],
      170=>[36,48,54,55,56,57,58,59,60,61,85,86,87,92,97,103,104,109,127,133,145,156,164,173,175,182,196,207,209,213,214,215,216,218,237,240,250,258,263,268,324,340,351,352,362,392,435,451,486,487,496,503,521,528,569,590,605],
      171=>[36,48,55,56,57,58,59,61,63,85,86,87,92,104,109,127,145,156,164,173,175,182,196,207,209,213,214,215,216,218,237,240,254,255,256,258,263,268,324,340,351,352,392,401,416,435,451,486,496,503,521,528,569,590,598,605,671],
      172=>[3,9,39,84,85,86,87,92,104,113,117,156,164,173,175,179,182,186,203,204,207,213,214,216,217,218,227,231,237,240,252,253,263,268,270,273,321,324,343,344,351,374,381,393,417,447,451,496,497,516,521,527,528,574,590,604],
      173=>[1,47,53,76,86,92,94,102,104,113,115,118,126,133,138,150,156,164,173,182,186,187,196,204,207,213,214,216,217,218,219,227,231,237,240,241,244,247,253,263,270,271,272,273,277,278,283,304,312,313,321,324,343,345,351,352,356,374,383,387,428,447,472,473,477,495,496,497,500,505,526,581,590],
      174=>[1,47,53,76,86,92,94,104,111,113,115,126,138,156,164,173,182,185,186,195,196,204,207,213,214,215,216,217,218,219,220,237,240,241,244,247,253,263,270,272,273,277,278,283,304,313,340,343,351,352,356,374,383,386,387,445,447,496,497,505,526,528,581,590],
      175=>[38,45,53,64,76,86,92,94,104,113,115,118,119,126,138,156,164,173,182,186,193,204,207,213,214,215,216,217,218,219,226,227,234,237,240,241,244,246,247,248,253,263,266,271,273,277,281,283,290,304,324,326,343,351,352,374,375,381,387,417,428,447,473,477,495,496,497,500,516,526,590,605],
      176=>[19,38,45,53,63,76,86,92,94,104,113,115,118,126,138,156,164,173,182,186,204,207,211,213,214,215,216,218,219,226,227,237,240,241,244,246,247,257,263,264,266,271,273,277,280,281,283,304,324,332,343,345,351,352,355,366,374,387,409,416,428,432,447,473,477,495,496,497,516,526,584,590,605,684],
      177=>[43,64,65,76,86,92,94,98,100,101,104,109,113,114,115,138,143,156,164,168,173,182,185,202,207,211,213,214,216,218,220,237,240,241,244,247,248,257,263,271,273,277,285,287,297,324,332,347,355,357,366,369,375,381,382,384,385,389,428,433,447,466,473,477,478,485,493,496,500,502,590,605],
      178=>[19,43,63,64,76,86,92,94,100,101,104,109,113,115,138,143,156,164,168,173,182,202,207,211,213,214,216,218,220,237,240,241,244,247,248,257,263,271,273,277,285,324,332,347,355,357,366,369,375,381,382,384,385,403,416,428,432,433,447,466,473,477,478,492,496,500,502,590,605,673],
      179=>[28,33,34,36,45,84,85,86,87,92,97,103,104,109,113,156,164,173,178,182,207,213,214,215,216,218,219,231,237,240,260,263,268,316,324,351,393,408,435,451,486,495,496,497,527,528,538,590,598,604],
      180=>[7,9,33,36,45,84,85,86,87,92,104,109,113,156,164,173,178,182,207,213,214,215,216,218,219,231,237,240,263,264,268,280,324,351,374,393,408,435,451,486,495,496,497,521,527,528,538,590],
      181=>[7,9,33,36,45,63,84,85,86,87,92,104,109,113,156,164,173,178,182,192,200,207,213,214,215,216,218,219,231,237,240,263,264,268,280,324,351,374,393,406,408,411,416,435,451,486,495,496,497,521,523,527,528,538,569,590,602,673,693],
      182=>[14,63,72,76,78,80,92,104,156,164,173,182,188,202,207,213,214,216,218,219,230,235,237,241,253,263,267,345,348,374,380,388,402,409,412,416,437,447,474,483,495,496,572,590,605,611,673],
      183=>[8,33,34,38,39,48,55,56,57,58,59,61,92,104,111,113,127,133,145,156,164,173,182,187,195,196,205,207,213,214,216,217,218,231,237,240,248,258,263,264,270,276,280,282,287,293,304,330,340,343,346,352,374,392,401,447,453,496,503,526,583,590],
      184=>[8,33,38,39,55,56,57,58,59,61,63,92,104,111,113,127,145,156,164,173,182,196,205,207,213,214,216,218,231,237,240,258,263,264,270,276,280,282,304,340,343,346,352,374,392,401,411,416,447,496,503,523,526,583,590,710],
      185=>[7,8,9,21,29,38,67,68,88,89,92,102,104,106,111,120,153,156,157,164,168,173,174,175,182,185,201,203,205,207,213,214,216,218,237,241,244,259,263,264,267,269,270,272,280,317,328,335,343,347,359,374,383,389,397,414,444,446,452,457,479,492,495,496,523,590,707,715],
      186=>[3,8,57,58,59,61,63,89,92,94,95,104,127,156,164,168,173,182,195,196,207,213,214,216,218,237,240,258,263,264,270,280,283,304,340,352,371,374,411,416,496,497,503,523,590],
      187=>[14,33,38,39,71,72,73,76,77,78,79,92,93,104,115,133,150,156,164,173,178,182,202,203,207,213,214,216,218,227,235,237,241,244,262,263,270,312,331,332,340,369,388,402,412,447,476,496,512,538,580,584,590,605,611,668],
      188=>[14,33,39,71,72,73,76,77,78,79,92,104,115,150,156,164,173,178,182,202,207,213,214,216,218,235,237,241,244,262,263,270,331,332,340,369,388,402,412,447,476,496,512,584,590,605,611],
      189=>[14,33,39,63,71,72,73,76,77,78,79,92,104,115,150,156,164,173,178,182,202,207,213,214,216,218,235,237,241,244,262,263,270,331,332,340,369,388,402,412,416,447,476,496,512,584,590,605,611],
      190=>[3,7,8,9,10,21,28,39,67,68,76,85,86,87,92,97,103,104,129,138,154,156,164,168,173,180,182,207,213,214,216,218,226,228,231,237,240,241,247,251,252,253,263,264,269,272,279,280,282,289,310,321,332,340,343,351,352,369,371,374,387,402,415,417,421,441,447,458,490,492,496,501,512,526,541,590],
      191=>[14,38,71,72,73,74,75,76,92,104,113,117,156,164,173,174,182,188,202,203,207,213,214,216,218,219,227,230,234,235,237,241,253,263,267,270,275,283,320,363,388,402,412,414,447,495,496,580,590],
      192=>[1,14,38,63,71,72,73,74,75,76,80,92,104,113,156,164,173,182,188,202,207,213,214,216,218,219,235,237,241,253,263,267,270,275,283,320,331,363,388,402,412,414,416,437,447,495,496,572,579,590],
      193=>[17,18,33,38,48,49,76,92,94,95,98,103,104,138,141,156,164,168,173,179,182,185,193,197,202,207,211,213,214,216,218,228,237,241,246,247,253,263,290,318,324,332,355,364,366,369,403,405,432,450,496,590],
      194=>[8,21,24,34,39,54,55,57,58,59,68,89,92,104,105,114,127,133,156,164,173,174,182,188,196,201,207,213,214,216,218,219,227,231,237,240,246,254,255,256,258,263,281,300,330,341,352,385,401,414,426,482,491,495,496,503,523,590,598,611,612,707],
      195=>[8,21,39,54,55,57,58,59,63,89,92,104,114,127,133,156,157,164,168,173,182,188,196,201,207,213,214,216,218,219,231,237,240,258,263,264,280,281,300,317,330,341,352,374,401,411,414,416,426,444,482,495,496,503,523,590,611,707],
      196=>[28,33,39,60,63,92,93,94,98,104,113,115,129,138,156,164,173,182,207,213,214,215,216,218,231,234,237,240,241,244,247,248,263,270,271,277,285,304,324,343,347,384,387,416,428,433,447,473,477,478,496,497,502,526,590,605,608,673],
      197=>[28,33,39,63,92,94,98,103,104,109,138,156,164,173,180,182,185,207,212,213,214,215,216,218,228,231,236,237,240,241,244,247,259,263,269,270,289,304,343,371,372,385,387,399,416,472,492,496,497,526,555,590,608,673,675],
      198=>[17,18,19,64,65,86,92,94,101,103,104,109,114,119,138,143,156,164,168,173,180,182,185,195,196,207,211,212,213,214,216,218,228,237,240,241,244,247,253,257,259,260,263,269,289,297,310,332,347,355,366,371,372,373,375,386,389,399,413,432,492,496,511,555,590],
      199=>[8,29,33,45,50,53,55,57,58,59,63,86,89,92,93,94,104,113,126,138,156,164,173,174,182,196,207,213,214,216,218,219,231,237,240,241,244,247,258,263,264,271,277,278,280,281,285,324,334,335,347,352,374,376,401,408,409,411,416,417,428,433,447,472,473,477,492,495,496,497,502,503,505,511,523,525,590,673],
      200=>[45,60,85,86,87,92,94,103,104,109,138,149,156,164,168,173,174,180,182,194,195,196,207,212,213,214,215,216,218,220,237,240,241,244,247,253,259,261,262,263,269,271,277,285,286,288,289,304,310,332,347,351,371,373,382,389,399,408,417,425,433,451,466,472,477,478,492,496,497,502,506,590,605],
      201=>[237],
      202=>[68,194,219,243],
      203=>[13,23,24,33,36,45,60,85,86,87,89,92,93,94,97,104,113,115,133,138,156,164,168,173,182,193,207,212,213,214,216,218,226,231,237,240,241,242,243,244,247,248,251,253,263,271,273,277,278,285,290,304,310,316,324,347,351,356,372,384,385,412,417,428,433,447,451,458,473,477,492,496,497,502,523,526,590,605,678,706,707],
      204=>[33,36,38,42,68,76,89,92,104,113,115,117,120,129,153,156,157,164,173,175,182,191,201,202,203,207,213,214,216,218,220,229,237,241,263,279,317,328,334,356,360,363,371,379,390,446,450,474,496,523,529,590],
      205=>[33,36,38,63,76,89,92,104,113,115,117,120,153,156,157,164,173,182,191,192,201,202,207,213,214,216,218,220,229,237,241,263,317,324,334,335,356,360,363,371,390,393,397,416,429,430,446,450,474,475,477,484,496,502,521,523,529,590,673],
      206=>[20,29,34,36,38,44,53,58,59,76,85,86,87,89,91,92,97,99,103,104,111,117,126,137,138,156,157,164,168,173,174,175,180,182,189,203,205,207,213,214,216,218,220,228,231,237,240,241,244,246,247,263,277,281,283,290,310,317,347,351,352,355,360,376,387,398,401,403,407,428,446,451,489,496,506,523,528,529,590,707],
      207=>[12,13,14,17,28,38,40,68,89,92,97,98,103,104,106,156,157,163,164,168,173,182,185,188,201,206,207,210,211,213,214,216,218,226,231,232,237,240,241,259,263,269,280,282,317,327,328,332,342,355,364,366,369,371,374,379,397,398,399,400,401,404,414,431,432,440,444,446,450,474,496,512,523,590,675],
      208=>[20,21,33,38,46,63,88,89,91,92,99,103,104,106,153,156,157,164,173,174,182,201,207,213,214,216,218,225,231,237,241,242,244,259,263,267,269,300,317,335,360,371,393,397,399,401,406,414,416,422,423,424,430,442,444,446,475,479,496,523,525,590,693,707],
      209=>[7,8,9,29,33,38,39,44,46,53,67,76,85,86,87,89,92,99,102,104,115,118,122,126,156,162,164,168,173,182,184,185,188,204,207,213,214,215,216,217,218,237,240,241,242,247,259,263,264,265,269,276,280,304,313,315,339,343,351,352,370,371,374,387,422,423,424,496,523,526,528,555,583,590,605],
      210=>[7,8,9,29,33,39,44,46,53,63,67,76,85,86,87,89,92,99,104,115,122,126,156,157,162,164,168,173,182,184,188,200,204,207,213,214,215,216,218,231,237,240,241,242,247,259,263,264,269,276,280,304,315,317,339,343,351,352,371,374,387,411,416,422,423,424,444,496,523,526,528,555,583,590,605,707],
      211=>[33,36,40,42,48,55,56,57,58,59,61,86,92,104,106,107,114,127,145,153,156,164,173,175,182,188,191,194,196,205,207,213,214,216,218,220,237,240,247,254,255,258,263,269,279,310,324,340,351,352,360,362,371,390,398,401,453,474,482,491,496,503,565,590,675,710],
      212=>[13,14,43,63,92,97,98,104,113,116,156,163,164,168,173,182,201,206,207,210,211,213,214,216,218,219,228,232,237,240,241,263,276,280,282,332,334,355,364,366,369,374,400,404,416,418,430,432,442,450,458,474,496,512,590,673,693],
      213=>[20,35,51,88,89,92,104,110,117,132,156,157,164,173,182,188,189,201,205,207,213,214,216,218,219,227,230,237,241,263,270,282,317,328,350,360,367,379,380,397,414,444,446,450,470,471,474,479,482,495,496,504,515,522,523,564,590,611],
      214=>[14,30,31,33,36,38,42,43,63,67,68,69,89,92,104,106,117,156,157,164,168,173,175,179,182,203,206,207,213,214,216,218,224,228,237,240,241,263,264,270,279,280,282,292,317,331,332,334,339,350,364,370,374,400,411,416,421,444,450,474,479,496,498,523,526,590,675,693],
      215=>[8,10,14,43,44,57,58,59,67,68,92,97,98,103,104,115,138,154,156,163,164,168,173,180,182,185,193,196,206,207,213,214,216,218,228,231,232,237,240,241,244,247,251,252,258,259,263,264,269,274,280,282,289,306,332,347,364,371,373,374,386,398,399,404,419,420,421,458,468,490,492,496,555,556,590,673,675],
      216=>[7,8,9,10,14,36,37,38,46,68,69,89,92,104,122,154,156,157,163,164,168,173,182,185,187,204,207,213,214,216,218,230,232,237,238,240,241,242,259,263,264,269,276,280,281,304,313,317,332,339,343,370,371,374,387,400,402,421,441,496,498,523,526,583,589,590,608],
      217=>[7,8,9,10,14,37,43,46,63,67,89,92,104,122,154,156,157,163,164,168,173,182,184,185,207,213,214,216,218,230,237,240,241,253,259,263,264,269,276,280,304,313,317,332,339,343,359,371,374,387,402,411,416,421,441,444,479,496,523,526,589,590,673,675,707],
      218=>[34,52,53,88,92,104,105,106,108,113,115,123,126,133,151,156,157,164,173,174,182,205,207,213,214,216,218,220,237,241,246,254,255,256,257,261,262,263,267,281,315,317,334,385,414,436,481,488,495,496,499,510,517,590,611],
      219=>[34,52,53,63,76,88,89,92,104,105,106,113,115,123,126,133,153,156,157,164,173,182,201,207,213,214,216,218,220,237,241,246,257,261,263,267,281,315,317,334,360,397,414,416,436,444,446,479,481,488,495,496,499,504,510,523,590,611,707],
      220=>[33,34,36,38,44,46,54,58,59,89,90,92,104,113,115,133,156,157,164,173,174,175,181,182,189,196,201,203,207,213,214,216,218,237,240,246,258,263,276,283,300,316,317,333,341,414,419,420,426,446,496,523,556,573,590],
      221=>[31,36,37,46,54,58,59,63,64,89,92,104,113,115,133,156,157,164,173,181,182,189,196,201,203,207,213,214,216,218,237,240,246,258,263,276,283,300,316,317,414,416,423,426,444,446,496,523,590,707],
      222=>[33,54,57,58,59,61,89,92,94,103,104,105,106,109,112,113,115,117,131,133,145,153,156,157,164,173,174,175,182,196,201,203,207,213,214,216,218,219,237,240,241,243,246,247,258,263,267,275,277,283,287,293,317,333,334,347,350,352,362,381,392,397,408,414,444,446,457,496,503,523,590,675,707,710],
      223=>[48,53,55,56,57,58,59,60,61,62,63,86,92,94,103,104,114,116,126,127,129,156,164,168,173,175,182,190,196,199,207,213,214,216,218,237,240,241,263,323,324,331,340,341,350,352,402,441,451,479,487,491,494,496,503,590],
      224=>[20,53,55,56,57,58,59,60,61,62,63,86,92,94,104,116,126,127,132,156,164,168,173,182,188,190,196,207,213,214,216,218,237,240,241,263,324,331,340,350,352,371,378,402,412,416,430,441,451,479,482,487,496,503,590],
      225=>[8,19,58,59,62,65,68,92,98,104,143,150,156,164,168,173,182,191,194,196,207,213,214,216,217,218,229,237,240,248,252,258,263,264,278,280,301,324,332,340,352,374,402,420,432,441,496,516,524,573,590,693,694],
      226=>[17,21,29,33,36,48,56,57,58,59,60,61,63,89,92,97,104,109,114,127,133,145,150,156,157,164,173,182,196,207,213,214,216,218,237,239,240,243,258,263,270,300,317,324,331,332,340,346,352,355,366,392,401,402,403,416,432,441,442,469,496,503,512,523,590,710],
      227=>[14,18,19,28,31,43,46,64,65,92,97,104,129,143,156,157,163,164,168,173,174,182,191,196,201,203,207,211,213,214,216,218,228,232,237,241,259,263,269,314,317,319,332,334,355,364,366,371,372,385,399,400,403,404,413,430,432,442,446,475,496,507,590],
      228=>[43,44,46,52,53,68,76,83,92,99,104,123,126,138,156,162,164,168,173,179,180,182,185,188,194,207,213,214,216,218,228,231,237,241,242,247,251,253,257,259,261,263,269,272,289,304,315,316,336,364,371,373,386,389,399,417,422,424,488,492,496,517,555,590],
      229=>[43,44,46,52,53,63,76,92,104,123,126,138,156,162,164,168,173,180,182,185,188,207,213,214,216,218,231,237,241,242,247,251,253,257,259,261,263,269,272,289,304,315,316,336,371,373,399,416,417,422,424,488,492,496,517,555,590,673,675],
      230=>[43,55,56,57,58,59,61,63,92,97,104,108,116,127,145,156,164,173,182,196,200,207,213,214,216,218,237,239,240,258,263,281,324,340,349,352,362,406,416,430,434,442,496,503,511,590,673],
      231=>[21,33,34,36,38,45,46,68,89,90,92,104,111,116,156,157,164,173,175,182,189,201,203,204,205,207,213,214,216,218,231,237,241,246,263,276,282,283,304,316,317,363,387,402,414,420,441,446,457,484,496,497,523,583,590,667],
      232=>[21,30,31,45,46,63,89,92,104,111,156,157,164,173,182,184,201,205,207,213,214,216,218,222,229,231,237,241,263,276,282,283,304,317,334,335,340,360,372,387,397,398,402,414,416,422,424,441,444,446,496,497,523,590,693,707],
      233=>[33,58,59,60,63,76,85,86,87,92,94,97,104,105,111,138,156,160,161,164,168,173,176,182,192,196,199,207,214,216,218,220,231,237,240,241,244,247,263,271,277,278,324,332,351,356,387,393,416,428,433,435,451,472,473,477,492,496,502,527,590],
      234=>[23,24,26,28,33,36,37,43,44,46,50,76,85,86,87,89,92,94,95,99,104,109,113,115,138,156,164,168,173,180,182,207,213,214,216,218,224,231,237,240,241,244,247,253,263,272,285,286,300,310,324,326,340,347,351,356,382,387,412,416,428,433,445,451,473,478,496,523,526,528,590,675],
      235=>[166],
      236=>[33,67,68,89,92,104,136,156,157,164,168,170,173,182,183,193,203,207,213,214,216,218,228,229,237,240,241,252,253,263,270,272,280,339,343,364,410,418,490,496,523,526,590,673],
      237=>[27,67,68,89,92,97,98,104,116,156,157,164,167,168,173,182,197,201,207,213,214,216,218,228,229,237,240,241,263,270,272,279,280,283,332,339,343,360,364,370,444,469,490,496,501,523,526,590,673],
      238=>[1,8,47,58,59,92,93,94,96,104,113,115,122,138,156,164,168,173,181,182,186,195,196,207,212,213,214,215,216,218,237,240,244,247,252,253,258,263,270,271,272,273,277,278,285,313,324,343,347,352,357,358,371,374,381,383,417,419,428,433,445,447,472,473,478,496,497,524,531,590,694],
      239=>[2,7,8,9,27,43,67,84,85,86,87,92,94,96,98,103,104,112,113,129,156,164,168,173,182,207,213,214,216,218,223,237,238,240,253,263,264,270,280,324,343,351,359,364,374,393,435,451,486,496,521,527,528,530,590],
      240=>[2,5,7,9,43,52,53,83,92,94,103,104,108,109,112,116,123,126,156,164,168,173,182,183,185,187,207,213,214,216,218,223,231,237,238,241,253,257,261,263,264,270,280,315,343,374,384,394,436,481,488,496,499,530,562,590],
      241=>[7,8,9,23,33,34,38,45,57,58,59,63,69,76,85,86,87,89,92,104,111,117,146,156,157,164,173,174,179,182,196,201,203,205,207,208,213,214,215,216,217,218,231,237,240,241,244,247,263,264,270,280,317,335,351,352,358,359,360,363,374,386,411,416,428,442,445,446,495,496,497,523,526,531,562,590,707],
      242=>[1,3,7,8,9,36,38,39,45,47,53,58,59,63,76,85,86,87,89,92,94,104,107,111,113,121,126,135,138,156,157,164,173,182,196,201,207,213,214,215,216,218,219,231,237,240,241,244,247,258,263,264,270,278,280,283,285,287,289,304,317,335,343,347,351,352,356,361,374,387,409,411,416,428,446,447,451,477,496,497,502,505,516,523,526,528,590,605,673,707],
      243=>[43,44,46,63,84,85,86,87,92,98,104,113,115,156,164,173,182,201,207,209,214,216,218,231,237,240,241,242,244,247,263,324,326,347,351,393,416,422,435,442,451,496,511,521,523,528,555,590,673,675],
      244=>[23,43,44,46,52,53,63,76,83,92,104,115,126,156,164,173,182,201,207,214,216,218,221,231,237,240,241,244,247,257,261,263,284,315,326,347,416,424,436,442,444,488,496,511,523,555,590,673,707],
      245=>[16,43,44,46,54,56,57,58,59,61,62,63,92,104,115,127,156,164,173,182,196,201,207,214,216,218,231,237,240,241,243,244,247,258,263,324,326,329,347,352,366,416,423,442,496,503,511,523,555,590,673],
      246=>[23,37,43,44,63,89,92,103,104,116,156,157,164,173,174,180,182,184,200,201,207,213,214,216,218,228,231,237,240,241,242,246,253,259,263,269,276,280,317,334,349,371,372,397,399,414,442,444,446,479,496,498,523,555,590],
      247=>[37,43,44,63,89,92,103,104,156,157,164,173,180,182,184,200,201,207,213,214,216,218,231,237,240,241,242,253,259,263,269,276,280,317,334,371,397,399,414,442,444,446,479,496,498,523,555,590],
      248=>[7,8,9,37,43,44,46,53,57,58,59,63,67,85,86,87,89,92,103,104,126,156,157,164,173,180,182,184,200,201,207,213,214,216,218,231,237,240,241,242,253,259,263,264,269,276,280,317,332,334,335,337,351,352,371,374,397,399,401,406,411,414,416,421,422,423,424,442,444,446,479,492,496,498,523,525,555,590,693,707],
      249=>[16,18,19,46,56,57,58,59,63,85,86,87,89,92,94,104,105,113,115,127,138,143,156,164,173,177,182,196,201,202,207,211,214,216,218,219,231,237,240,241,244,246,247,248,258,263,271,285,304,311,324,326,332,347,351,352,355,363,366,386,401,406,407,414,416,428,432,442,451,472,473,477,496,497,507,523,525,590,673],
      250=>[16,18,19,46,53,63,76,85,86,87,89,92,94,104,105,113,115,126,138,143,156,164,173,182,201,202,207,211,214,216,218,219,221,237,240,241,244,246,247,248,257,261,263,304,311,315,324,326,332,347,351,355,363,366,386,413,414,416,428,432,442,451,488,496,497,507,523,590,673],
      251=>[14,63,73,76,86,92,93,94,104,105,113,115,138,156,164,173,182,195,201,202,207,214,215,216,218,219,226,235,237,240,241,244,246,247,248,253,263,267,270,271,277,285,324,332,345,347,351,352,361,363,369,374,377,387,388,402,412,414,416,428,433,437,446,447,451,472,477,478,496,497,502,590,605,673],
      252=>[1,9,13,14,21,24,43,67,71,72,73,76,92,97,98,103,104,156,157,164,173,182,197,202,207,213,214,216,218,219,225,228,231,235,237,241,242,263,264,267,280,283,300,306,317,320,331,332,345,363,374,388,402,409,412,437,447,496,501,512,520,526,580,590],
      253=>[1,9,14,21,43,67,71,72,76,92,97,98,103,104,156,157,164,173,182,197,202,206,207,210,213,214,216,218,219,228,231,235,237,241,263,264,267,280,283,317,332,348,374,388,402,404,409,412,437,447,490,496,501,512,520,526,590],
      254=>[1,9,14,21,43,46,63,67,71,72,76,89,92,97,98,103,104,156,157,164,173,182,197,200,202,206,207,210,213,214,216,218,219,228,231,235,237,241,263,264,267,280,283,317,332,337,338,348,374,388,400,402,404,406,409,411,412,416,437,447,490,496,501,512,520,523,526,530,590,673,675,693],
      255=>[10,14,28,45,52,53,64,67,68,83,92,97,98,104,116,119,126,156,157,163,164,173,174,179,182,203,207,213,214,216,218,226,237,241,257,261,263,265,270,297,306,315,317,332,340,364,387,400,421,432,481,488,496,497,519,526,590],
      256=>[7,9,10,14,24,28,45,52,53,64,67,92,98,104,116,119,126,156,157,163,164,173,182,207,213,214,216,218,237,241,257,261,263,264,270,280,315,317,327,332,339,340,374,387,394,398,411,421,432,488,490,496,497,519,526,530,590],
      257=>[7,9,10,14,24,28,45,46,52,53,63,64,67,76,89,92,98,104,116,126,136,156,157,163,164,173,182,207,213,214,216,218,237,241,257,261,263,264,270,272,276,280,282,299,307,315,317,327,332,339,340,374,387,394,398,411,413,416,421,432,444,488,490,496,497,512,519,523,526,530,590,673],
      258=>[23,33,36,38,44,45,55,56,57,58,59,67,68,88,92,104,112,117,124,127,156,157,164,173,174,182,189,193,196,207,213,214,216,218,231,237,240,243,246,250,253,258,263,276,281,283,287,300,301,317,352,401,414,419,426,469,482,496,497,503,518,526,590],
      259=>[8,33,36,45,55,57,58,59,67,89,92,104,117,127,156,157,164,173,182,189,193,196,207,213,214,216,218,231,237,240,253,258,263,276,280,283,317,330,341,352,374,401,414,426,446,482,496,497,503,518,523,526,590],
      260=>[8,33,36,45,46,55,57,58,59,63,67,89,92,104,117,127,156,157,164,173,182,189,193,196,200,207,213,214,216,218,231,237,240,253,258,263,264,276,280,283,308,317,330,341,352,359,374,401,411,414,416,426,444,446,482,496,497,503,518,523,526,590,707],
      261=>[28,33,36,43,44,46,92,104,156,162,164,168,173,180,182,184,207,213,214,216,218,231,237,240,241,242,247,253,259,263,269,281,289,304,305,310,316,336,343,371,372,373,382,389,399,422,423,424,492,496,555,583,590],
      262=>[28,33,36,44,46,63,92,104,156,162,164,168,173,180,182,184,207,213,214,216,218,231,237,240,241,242,247,253,259,263,269,281,289,304,316,336,343,371,372,373,389,399,416,422,423,424,492,496,555,583,590,673,675],
      263=>[28,29,33,36,39,42,45,57,58,59,85,86,87,92,104,156,162,164,168,173,175,182,187,189,196,204,207,213,214,216,218,228,231,237,240,241,245,247,263,270,271,300,304,316,321,343,351,352,374,387,402,431,441,447,451,493,496,497,516,526,590,608],
      264=>[28,29,33,38,39,45,46,57,58,59,63,85,86,87,92,104,154,156,162,163,164,168,173,182,187,196,207,213,214,216,218,231,237,240,241,247,263,270,271,300,304,316,343,351,352,374,387,402,415,416,421,441,447,451,496,497,516,526,563,583,590,675,707],
      265=>[33,40,81,173,450,527],
      266=>[106,334,450,527],
      267=>[16,18,63,71,72,76,78,92,94,99,104,156,164,168,173,182,202,207,213,214,216,218,219,234,237,241,247,263,314,318,324,332,355,366,369,405,412,416,432,450,474,483,496,512,527,590,611,673],
      268=>[106,334,450,527],
      269=>[16,18,60,63,76,77,92,93,94,104,113,156,164,168,173,182,188,202,207,213,214,216,218,236,237,241,247,263,318,324,332,355,366,369,405,412,416,432,450,474,483,496,512,527,590,611,673],
      270=>[14,45,54,55,57,58,59,61,68,71,72,73,75,76,92,104,145,156,164,168,173,175,182,196,202,207,213,214,216,218,230,235,237,240,241,253,258,263,267,298,310,321,352,363,402,412,428,447,496,497,503,590],
      271=>[7,8,9,14,45,56,57,58,59,61,71,76,92,104,127,145,154,156,164,168,173,182,196,202,207,213,214,216,218,235,237,240,241,252,253,258,263,267,280,282,304,310,346,352,374,402,409,412,428,447,496,497,503,590],
      272=>[7,8,9,14,45,57,58,59,63,72,76,92,104,127,156,164,168,173,182,196,202,207,213,214,216,218,235,237,240,241,253,258,263,264,267,280,282,304,310,352,374,402,409,411,412,416,428,447,496,497,503,590],
      273=>[13,14,36,73,74,76,92,98,104,106,117,133,153,156,164,173,180,182,202,206,207,213,214,216,218,235,237,241,247,251,263,267,331,384,388,402,412,417,432,447,492,496,580,590],
      274=>[1,13,14,63,67,74,75,76,92,104,106,153,156,157,164,168,173,180,182,185,202,206,207,213,214,216,218,235,237,241,244,247,252,259,263,267,280,317,326,348,371,373,374,388,399,402,412,432,447,490,492,496,555,590],
      275=>[14,18,63,67,75,76,92,104,153,156,157,164,168,173,180,182,185,196,202,206,207,213,214,216,218,235,237,241,244,247,259,263,267,280,282,317,332,340,366,371,373,374,388,399,402,404,411,412,416,417,432,437,447,490,492,496,536,542,555,590,675,693],
      276=>[17,18,19,45,48,64,92,97,98,99,104,116,119,143,156,164,168,173,179,182,207,211,213,214,216,218,228,237,240,241,257,263,283,287,332,355,366,369,403,413,432,496,497,501,526,542,586,590],
      277=>[17,19,45,63,64,92,97,98,104,116,143,156,164,168,173,179,182,207,211,213,214,216,218,237,240,241,257,263,283,332,355,365,366,369,403,413,416,432,496,497,501,526,590,673],
      278=>[16,17,19,45,48,54,55,58,59,92,97,98,104,143,156,164,168,173,182,196,207,211,213,214,216,218,228,237,239,240,253,258,263,282,314,332,346,351,352,355,362,366,369,392,403,432,469,487,496,497,503,542,590,710],
      279=>[17,19,45,48,54,55,56,57,58,59,63,92,104,143,156,164,168,173,182,196,207,211,213,214,216,218,237,240,253,254,255,256,258,263,282,332,346,351,352,355,362,366,369,371,374,402,416,432,441,487,496,497,503,507,542,590,710],
      280=>[7,8,9,45,50,85,86,92,93,94,95,100,104,109,113,115,138,156,164,168,173,182,194,196,204,207,212,213,214,216,218,219,220,227,237,240,241,244,247,248,259,261,262,263,269,270,271,277,278,285,286,288,289,304,324,345,347,351,374,381,425,428,433,447,451,472,473,477,478,485,496,497,500,502,505,574,577,581,590,605],
      281=>[7,8,9,45,85,86,92,93,94,95,100,104,113,115,138,156,164,168,173,182,196,204,207,213,214,216,218,219,220,237,240,241,244,247,248,259,261,263,269,270,271,277,278,285,286,289,304,324,345,347,351,374,381,428,433,447,451,472,473,477,478,496,497,500,502,505,574,577,590,605],
      282=>[7,8,9,45,63,85,86,92,93,94,95,100,104,113,115,138,156,164,168,173,182,196,207,213,214,215,216,218,219,220,237,240,241,244,247,248,259,261,263,269,270,271,273,277,278,285,286,289,304,324,345,347,351,361,374,411,412,416,428,433,445,447,451,472,473,477,478,496,497,500,502,505,574,577,581,585,590,605,673],
      283=>[54,56,58,59,60,61,76,92,97,98,104,114,145,156,164,168,170,173,182,193,196,202,203,207,213,214,216,218,226,230,237,240,241,244,247,263,324,341,346,352,450,453,471,496,503,564,565,590,611,679,710],
      284=>[16,18,58,59,63,76,78,92,98,104,145,156,164,168,173,182,184,196,202,207,213,214,216,218,230,237,240,241,244,247,263,314,318,324,332,346,352,355,366,369,403,405,412,416,432,450,466,483,496,503,590,611,710],
      285=>[14,29,33,71,72,73,74,76,77,78,92,104,147,156,164,173,182,188,202,204,206,207,213,214,216,218,219,235,237,241,263,264,270,289,313,331,358,363,388,402,409,412,447,474,496,590],
      286=>[9,14,29,33,63,68,71,72,73,76,78,92,104,156,157,164,170,173,182,183,188,202,206,207,213,214,216,218,219,223,231,235,237,241,263,264,270,276,280,289,317,327,339,364,374,388,395,402,409,411,412,416,444,447,474,490,496,526,590,673],
      287=>[7,8,9,10,34,53,58,59,68,76,85,87,92,104,126,133,156,157,163,164,173,174,175,182,185,196,207,213,214,216,218,227,228,237,240,241,247,263,264,280,281,303,306,317,321,332,339,343,351,352,359,374,400,421,441,495,496,498,526,583,590],
      288=>[7,8,9,10,46,53,58,59,67,68,76,85,87,89,92,104,116,126,154,156,157,163,164,173,179,182,196,203,207,213,214,216,218,227,237,240,241,247,253,263,264,269,280,317,332,339,343,351,352,374,411,421,441,490,495,496,498,523,526,590],
      289=>[7,8,9,10,46,53,58,59,63,67,68,76,85,87,89,92,104,126,133,156,157,164,173,175,182,185,196,207,213,214,216,218,227,237,240,241,247,263,264,269,280,281,303,317,332,335,339,343,351,352,359,374,386,411,416,421,441,479,490,495,496,498,511,523,526,590,707],
      290=>[10,16,28,71,76,91,92,104,106,117,141,154,156,164,170,173,180,182,185,189,201,202,203,206,207,214,216,218,232,237,241,247,263,318,332,400,404,405,450,496,515,590],
      291=>[10,14,28,63,71,76,92,97,103,104,106,141,154,156,163,164,168,170,173,180,182,201,202,206,207,210,213,214,216,218,226,237,241,247,253,263,332,355,369,404,416,432,450,496,590,673],
      292=>[10,28,63,71,76,92,104,106,109,138,141,154,156,164,168,170,173,180,182,201,202,206,207,214,216,218,237,241,247,261,263,271,288,332,377,404,416,421,425,450,477,496,502,566,590],
      293=>[1,7,8,9,18,23,36,46,48,53,58,59,76,92,103,104,108,126,156,164,173,182,196,207,213,214,216,218,237,240,241,247,253,263,265,283,304,310,313,326,336,351,352,359,374,428,485,496,497,509,526,574,590],
      294=>[1,7,8,9,23,44,46,48,53,58,59,67,76,89,92,103,104,126,156,157,164,173,182,196,207,213,214,216,218,237,240,241,247,253,259,263,269,280,283,304,310,315,317,336,351,352,374,428,479,485,496,497,523,526,590,707],
      295=>[1,7,8,9,23,44,46,48,53,57,58,59,63,67,76,89,92,103,104,126,156,157,164,173,182,196,200,207,213,214,216,218,237,240,241,242,247,253,259,263,269,280,283,304,310,315,317,336,351,352,374,411,416,422,423,424,428,479,485,496,497,523,526,586,590,707],
      296=>[7,8,9,18,28,33,57,67,68,69,89,92,104,116,156,157,164,173,179,182,185,187,193,197,203,207,213,214,216,218,223,233,237,238,240,241,252,263,264,265,270,272,276,279,280,282,292,317,339,358,364,370,374,395,398,411,418,469,479,484,490,496,498,523,526,590],
      297=>[7,8,9,18,28,33,57,63,67,69,89,92,104,116,156,157,164,173,179,182,187,203,207,213,214,216,218,233,237,240,241,252,263,264,265,270,272,276,280,282,292,317,339,358,362,370,371,374,395,398,411,416,442,444,479,484,490,496,523,526,590,675,707],
      298=>[21,34,39,47,55,57,58,59,61,92,104,113,127,145,150,156,164,173,182,196,204,207,213,214,216,218,227,231,237,240,253,258,263,270,282,287,293,304,313,321,330,340,343,346,352,383,487,496,503,526,590],
      299=>[7,8,9,33,38,85,86,87,88,89,92,104,106,153,156,157,164,173,182,192,199,201,203,205,207,209,213,214,216,218,220,222,237,241,259,263,269,277,317,334,335,350,351,356,393,397,408,414,435,444,446,469,479,496,521,523,590,605,707],
      300=>[3,33,38,39,45,47,58,59,76,85,86,87,92,104,138,156,164,173,182,185,193,196,204,207,213,214,215,216,218,219,226,231,237,240,241,244,247,252,253,263,270,273,274,304,313,321,322,343,347,351,352,358,371,383,387,389,426,428,445,447,451,493,496,497,526,528,574,583,590],
      301=>[3,47,58,59,63,76,85,86,87,92,104,138,156,164,173,182,196,207,213,214,215,216,218,219,231,237,240,241,244,247,252,253,263,270,304,343,347,351,352,371,387,416,428,447,451,496,497,526,528,590,673,707],
      302=>[7,8,9,10,43,67,92,94,101,104,105,109,138,154,156,164,168,173,180,182,185,193,196,197,207,212,213,214,216,218,220,236,237,240,241,244,247,252,259,260,261,263,264,269,271,272,277,280,282,286,289,310,317,324,332,347,351,352,356,364,368,371,373,374,386,389,398,399,408,417,421,425,428,445,472,477,490,492,496,502,511,555,590,605],
      303=>[8,9,11,14,21,44,45,53,58,63,69,76,92,104,126,156,157,162,164,173,182,185,188,196,201,206,207,213,214,216,218,220,226,230,237,240,241,242,244,246,247,254,255,256,259,263,264,269,280,282,289,305,310,313,317,321,334,368,371,373,374,385,386,387,389,393,399,411,416,422,423,424,430,442,444,445,446,447,451,492,496,581,583,584,590,612,673],
      304=>[23,29,33,34,36,38,46,89,92,103,104,106,156,157,164,173,174,179,180,182,189,201,207,213,214,216,218,231,232,237,240,241,253,263,265,276,283,317,319,332,334,351,352,368,393,397,407,414,421,442,446,457,475,484,496,523,590],
      305=>[29,33,36,38,46,89,92,104,106,156,157,164,173,180,182,189,201,207,213,214,216,218,231,232,237,240,241,253,263,276,283,317,319,332,334,351,352,368,393,397,414,421,442,444,446,475,484,496,523,590,707],
      306=>[7,8,9,29,33,36,38,46,53,57,58,59,63,67,76,85,86,87,89,92,104,106,126,156,157,164,173,180,182,189,196,200,201,207,213,214,216,218,231,232,237,240,241,253,263,264,269,276,280,283,317,319,332,334,335,337,351,352,368,371,374,393,397,399,401,406,411,414,416,421,430,442,444,446,475,479,484,496,523,525,590,684,693,707],
      307=>[7,8,9,67,68,92,93,94,96,104,105,113,115,117,136,138,156,157,164,170,173,179,182,193,197,203,207,213,214,216,218,220,223,226,237,240,241,244,247,252,263,264,270,271,272,277,278,280,290,317,324,339,347,356,364,367,374,379,384,385,395,398,409,411,418,427,428,447,473,477,490,496,501,526,590],
      308=>[7,8,9,63,67,68,92,93,94,96,104,105,113,115,117,136,138,156,157,164,170,173,179,182,197,203,207,213,214,216,218,220,237,240,241,244,247,263,264,270,271,272,277,278,280,317,324,339,347,356,364,367,374,379,395,398,409,411,412,416,428,447,473,477,490,496,526,590,673],
      309=>[29,33,43,44,46,53,85,86,87,92,98,104,113,129,156,164,168,173,174,182,207,209,213,214,216,218,231,237,240,242,253,263,268,316,324,336,351,393,415,422,423,424,435,451,481,486,496,521,528,555,590,598],
      310=>[33,43,44,46,53,63,85,86,87,92,98,104,113,156,164,168,173,182,207,209,213,214,216,218,231,237,240,253,263,268,315,316,324,336,351,393,416,422,424,435,451,496,521,528,555,590,604,673],
      311=>[9,45,47,85,86,87,92,97,98,104,113,129,156,164,173,182,186,204,207,209,213,214,216,218,226,227,231,237,240,253,263,268,270,273,313,324,343,351,374,381,383,387,393,417,435,447,451,486,494,496,497,516,521,527,528,589,590,609,715],
      312=>[9,45,47,85,86,87,92,97,98,104,113,129,156,164,173,182,186,204,207,209,213,214,216,218,226,227,231,237,240,253,263,268,270,273,313,324,343,351,374,376,381,383,387,393,415,417,435,447,451,486,494,496,497,521,527,528,589,590,609,715],
      313=>[8,9,33,38,69,76,85,86,87,92,98,104,109,113,146,148,156,164,168,173,182,202,207,213,214,216,218,226,227,236,237,240,241,244,247,263,264,270,271,280,294,318,324,332,351,352,355,366,369,374,405,428,432,450,451,496,512,522,583,590,605,611,679],
      314=>[8,9,33,74,76,85,86,87,92,98,104,109,113,156,164,168,173,182,202,204,207,213,214,216,218,226,227,230,236,237,240,241,244,247,260,263,264,270,273,280,312,313,318,332,343,351,352,355,366,369,374,405,428,432,445,450,451,496,512,522,583,589,590,605,611],
      315=>[14,40,42,71,72,73,74,75,76,78,79,80,92,104,156,164,170,173,178,182,188,191,202,207,213,214,216,218,230,235,237,240,241,244,247,263,267,275,312,320,331,343,345,363,388,390,398,402,412,437,438,447,474,496,572,590,605],
      316=>[1,7,8,9,58,76,92,104,123,124,133,138,139,151,153,156,164,173,174,182,188,189,194,202,207,213,214,216,218,220,227,237,240,241,247,254,255,256,263,281,289,351,352,378,380,402,441,474,482,491,496,562,590,599,611],
      317=>[1,7,8,9,34,58,63,76,89,92,104,124,133,138,139,153,156,164,173,182,188,202,207,213,214,216,218,220,227,237,240,241,247,254,255,256,263,281,289,335,351,352,378,380,402,416,441,474,482,491,496,523,562,590,599,611],
      318=>[36,37,38,43,44,56,57,58,59,92,97,99,103,104,116,127,129,156,162,164,168,173,180,182,184,194,196,207,213,214,216,218,237,240,242,246,253,258,259,263,269,305,340,352,362,371,372,399,423,428,453,496,503,555,590,706],
      319=>[43,44,46,57,58,59,63,89,92,97,99,103,104,116,127,130,156,162,163,164,168,173,180,182,184,196,207,213,214,216,218,237,240,242,253,258,259,263,269,305,317,340,352,364,371,372,398,399,400,416,423,428,453,496,503,523,555,590,710],
      320=>[34,37,38,45,46,54,55,56,57,58,59,89,90,92,104,111,127,133,150,156,164,173,174,182,196,205,207,213,214,216,218,237,240,250,258,263,291,304,310,317,321,323,340,352,362,392,428,484,487,496,497,499,503,523,590],
      321=>[45,46,54,55,56,57,58,59,63,89,92,104,127,133,150,156,164,173,182,196,205,207,213,214,216,218,237,240,250,258,263,291,304,310,317,323,335,340,352,362,416,428,442,484,487,496,497,503,523,568,590,710],
      322=>[23,33,34,36,38,45,52,53,74,89,92,104,111,116,126,133,156,157,164,173,174,182,184,201,203,205,207,213,214,216,218,222,237,241,246,254,255,256,257,261,263,267,281,315,317,336,414,426,436,442,446,481,484,488,495,496,497,523,590],
      323=>[33,36,45,46,52,53,63,76,89,90,92,104,116,126,133,153,156,157,164,173,174,182,201,207,213,214,216,218,222,237,241,257,261,263,267,281,284,315,317,397,414,416,430,436,442,444,446,481,488,495,496,497,523,590,707],
      324=>[34,52,53,63,76,83,89,90,92,104,108,110,123,126,130,133,153,156,157,164,172,173,174,175,182,188,203,207,213,214,216,218,229,231,237,241,257,261,263,267,276,281,284,315,317,334,360,414,416,436,444,446,481,488,495,496,499,504,517,523,590,707],
      325=>[18,60,86,92,94,104,109,113,115,133,138,149,150,156,164,168,173,182,196,203,207,213,214,215,216,218,231,237,240,241,243,244,247,248,259,263,269,271,272,277,278,285,289,316,324,326,340,343,347,351,371,381,408,428,433,447,451,473,477,493,496,502,590],
      326=>[7,8,9,60,63,86,92,94,104,109,113,115,138,149,150,156,164,168,173,182,196,207,213,214,215,216,218,231,237,240,241,244,247,259,263,264,269,271,272,277,278,280,285,289,298,316,324,340,343,347,351,371,374,408,409,411,412,416,428,433,447,451,473,477,496,502,523,562,590,673],
      327=>[7,8,9,33,37,38,50,60,67,92,94,95,104,138,146,156,157,164,168,173,175,182,185,196,207,213,214,216,218,219,226,227,229,237,240,241,244,247,252,253,263,264,265,270,271,272,273,274,278,280,285,289,298,304,313,317,343,347,351,352,374,375,383,387,389,409,427,428,433,470,496,526,528,590,671,707],
      328=>[16,28,44,63,76,89,90,91,92,98,104,116,117,156,157,164,173,175,182,185,189,201,202,203,207,210,213,214,216,218,237,241,242,263,276,317,324,328,341,364,414,450,496,523,590],
      329=>[19,28,48,49,63,76,89,92,103,104,117,156,157,164,173,182,185,189,200,201,202,207,211,213,214,216,218,225,237,241,253,257,263,276,317,324,328,355,366,369,405,406,414,432,434,450,496,523,586,590,675],
      330=>[7,9,19,28,48,49,53,63,76,89,92,103,104,117,126,156,157,164,173,182,185,189,200,201,202,207,211,213,214,216,218,225,231,237,241,253,257,263,276,317,324,328,332,337,349,355,366,369,406,407,414,416,432,434,444,450,496,523,525,590,673,675,693],
      331=>[9,14,28,40,42,43,50,51,67,68,71,73,74,76,92,104,156,164,173,178,180,182,185,191,194,201,202,207,213,214,216,218,223,235,237,241,263,264,265,267,272,275,280,298,302,320,335,345,371,374,388,389,398,399,402,409,412,415,417,447,474,496,562,563,565,590,612],
      332=>[9,14,28,40,42,43,63,67,71,73,74,76,92,104,156,164,173,178,180,182,185,191,194,201,202,207,213,214,216,218,235,237,241,263,264,267,272,275,276,279,280,302,335,371,373,374,388,389,398,399,402,409,411,412,416,447,474,492,496,590,596,707],
      333=>[19,31,36,45,47,54,58,64,76,92,97,99,104,114,119,138,143,156,164,168,173,182,195,200,207,211,213,214,215,216,218,219,228,237,240,241,244,253,257,263,287,297,304,310,332,355,363,366,384,406,407,432,496,497,538,574,583,585,590,605],
      334=>[19,31,36,45,46,47,53,54,58,63,64,76,89,92,104,126,138,143,156,164,168,173,182,195,200,207,211,213,214,215,216,218,219,225,231,237,240,241,244,253,257,263,287,304,310,332,337,349,355,363,365,366,406,416,432,434,472,496,497,523,538,574,585,590,605],
      335=>[7,8,9,10,13,14,24,43,46,50,53,58,59,67,68,76,85,87,92,98,104,126,154,156,157,163,164,168,173,174,175,182,187,196,197,202,206,207,210,213,214,216,218,228,231,232,237,240,241,247,263,264,269,279,280,282,283,306,317,332,351,352,364,370,371,373,374,387,398,400,404,411,421,458,468,496,501,515,526,590,675],
      336=>[14,20,34,35,44,53,89,92,103,104,114,122,137,156,164,168,173,182,184,188,202,207,213,214,216,218,231,237,240,241,242,254,255,256,263,269,282,289,305,342,364,371,372,378,380,386,398,399,400,401,404,415,474,482,489,496,515,523,525,562,590,599,611,675,693],
      337=>[33,58,59,63,88,89,92,93,94,95,104,106,113,115,138,149,153,156,157,164,173,182,196,201,207,214,216,218,219,220,237,240,244,247,248,263,270,277,278,285,317,322,324,347,356,360,373,377,397,408,414,416,428,433,442,444,446,447,451,473,477,478,479,496,502,512,523,585,590,673,707],
      338=>[33,53,63,76,83,88,89,92,93,94,104,106,113,115,126,138,149,153,156,157,164,173,182,201,207,214,216,218,219,220,237,241,244,247,257,261,263,270,277,278,285,315,317,322,324,334,347,356,360,373,377,394,397,414,416,428,433,442,444,446,447,451,472,473,477,479,496,502,512,523,590,673,707],
      339=>[36,37,55,56,57,58,59,89,90,92,104,127,133,156,164,173,175,182,189,196,201,207,209,213,214,216,218,222,237,240,248,250,258,263,300,317,330,340,341,346,349,352,401,414,426,496,503,523,590],
      340=>[37,55,57,58,59,63,89,90,92,104,127,133,156,157,164,173,182,189,196,201,207,213,214,216,218,222,237,240,248,258,263,300,317,321,330,340,346,352,401,414,416,426,428,444,496,503,523,562,590,707],
      341=>[11,12,14,34,38,43,57,58,59,61,92,104,106,127,145,152,156,157,164,173,180,182,188,196,206,207,213,214,216,218,232,237,240,242,246,258,263,269,276,280,282,283,300,317,332,334,349,352,371,374,376,400,404,415,453,458,496,498,503,534,590],
      342=>[11,12,14,43,57,58,59,61,63,92,104,106,127,129,145,152,156,157,164,173,180,182,188,196,206,207,213,214,216,218,237,240,242,258,263,267,269,276,280,282,283,317,332,334,352,371,374,399,400,404,416,458,482,496,503,534,555,590,710],
      343=>[58,60,76,89,92,93,94,104,106,113,115,120,138,153,156,157,164,173,182,189,201,207,214,216,218,219,229,237,240,241,244,246,247,263,271,277,278,285,286,317,322,324,326,347,356,360,377,379,397,414,428,433,446,447,451,470,471,472,473,477,479,496,502,523,529,590,605],
      344=>[58,60,63,76,89,92,93,94,100,104,106,113,115,120,138,153,156,157,164,173,182,189,201,207,214,216,218,219,229,237,240,241,244,246,247,263,271,277,278,285,286,317,322,324,326,347,356,360,377,379,397,414,416,428,433,444,446,447,451,470,471,472,473,477,479,496,502,523,529,590,605],
      345=>[14,20,51,72,76,92,104,105,109,112,132,133,156,157,164,173,174,182,188,201,202,203,207,213,214,216,218,220,235,237,241,243,246,254,255,256,263,275,310,317,321,362,378,380,388,397,402,412,414,446,447,479,496,590,611],
      346=>[14,20,51,63,76,89,92,104,109,132,133,156,157,164,173,182,188,201,202,207,213,214,216,218,220,235,237,241,246,254,255,256,263,275,310,317,335,362,378,380,388,397,402,412,414,416,444,446,447,479,482,496,523,590,611],
      347=>[10,14,28,55,92,103,104,106,156,157,163,164,173,174,182,201,206,207,210,213,214,216,218,229,232,237,241,246,263,280,282,300,306,317,332,334,350,352,362,397,404,414,440,446,450,453,479,496,590],
      348=>[10,14,55,63,67,89,92,104,106,156,157,163,164,173,182,201,206,207,210,213,214,216,218,231,232,237,241,246,263,276,280,282,300,306,317,332,334,335,350,352,362,397,401,404,414,416,430,444,446,450,479,496,523,590,693,707,710],
      349=>[33,54,57,58,59,92,95,104,109,113,114,127,150,156,164,173,175,182,196,207,213,214,216,218,225,231,237,240,243,258,263,300,321,352,362,406,445,496,503,590],
      350=>[20,35,55,56,57,58,59,63,92,104,105,113,127,156,164,173,182,196,207,213,214,216,218,219,231,237,239,240,244,258,263,277,287,346,352,392,401,406,416,442,445,489,496,503,523,525,574,590,673,693],
      351=>[29,33,50,52,53,55,56,58,59,76,85,86,87,92,104,126,133,156,164,168,173,181,182,196,201,207,213,214,216,218,237,240,241,244,247,248,258,263,311,322,351,352,366,381,385,387,412,432,466,496,499,503,506,513,526,542,590],
      352=>[7,8,9,10,20,39,50,53,58,59,60,67,76,85,86,87,92,103,104,105,122,126,146,154,156,157,163,164,168,173,182,185,196,207,213,214,216,218,231,237,240,241,244,246,247,252,263,264,271,272,277,278,280,282,285,289,293,310,317,332,351,352,364,374,387,389,401,409,417,421,425,433,446,447,451,472,485,492,495,496,526,590,612],
      353=>[50,85,86,87,92,94,101,103,104,109,138,156,164,168,173,174,180,182,185,193,194,196,207,213,214,216,218,220,228,237,240,241,244,247,259,261,263,269,271,272,277,282,285,286,288,289,310,347,351,371,373,389,399,425,433,441,451,466,477,478,492,496,502,506,566,590,605],
      354=>[63,85,86,87,92,94,101,103,104,138,156,164,168,173,174,180,182,185,196,207,213,214,216,218,220,237,240,241,244,247,259,261,263,269,271,272,277,282,285,288,289,347,351,371,373,374,389,399,416,421,425,433,441,451,477,478,492,496,502,506,566,590,605,611,675],
      355=>[43,50,58,59,92,94,101,104,109,114,138,156,164,168,173,174,180,182,185,193,194,196,207,212,213,214,216,218,220,228,237,240,241,244,247,248,259,261,262,263,269,271,285,286,288,289,310,347,356,371,373,374,399,425,433,451,466,472,477,496,502,506,590,611],
      356=>[7,8,9,20,43,50,58,59,63,89,92,94,101,104,109,138,156,157,164,168,173,174,180,182,193,196,207,212,213,214,216,218,220,228,237,240,241,244,247,248,259,261,263,264,269,271,280,285,289,310,317,325,347,356,371,373,374,399,416,425,433,451,472,477,496,502,506,523,590,611],
      357=>[13,14,16,18,19,21,23,29,34,43,46,63,73,74,75,76,89,92,104,156,164,173,174,182,200,202,207,211,213,214,216,218,219,230,235,237,241,263,267,331,332,345,348,349,355,363,366,388,402,403,406,412,416,432,437,447,496,516,523,536,590,692,693,707],
      358=>[20,35,36,38,45,50,86,92,93,94,95,104,105,113,115,138,149,156,164,173,174,182,195,196,207,213,214,215,216,218,219,237,240,241,244,247,248,253,259,263,269,270,271,273,277,278,281,282,285,289,304,310,322,324,326,347,351,356,361,387,412,428,432,433,447,451,473,477,485,496,497,500,502,505,578,590,605,673],
      359=>[10,13,14,38,43,44,53,58,59,63,85,86,87,92,98,104,126,138,156,157,163,164,168,173,174,180,182,185,195,196,197,201,206,207,212,213,214,216,218,224,226,228,231,237,240,241,244,247,248,258,259,261,263,269,272,276,277,282,289,317,332,340,347,351,352,364,371,372,382,386,389,399,400,404,416,421,427,428,444,451,492,496,497,506,555,583,590,673,675,693],
      360=>[68,150,194,204,219,227,243],
      361=>[29,43,44,50,58,59,92,104,113,117,156,164,173,180,181,182,191,196,205,207,213,214,216,218,219,237,240,242,247,258,263,311,313,335,352,415,419,420,423,496,506,524,590],
      362=>[29,43,44,58,59,63,89,92,104,113,153,156,162,164,173,180,181,182,196,207,213,214,216,218,219,237,240,242,247,258,259,263,269,324,329,335,352,360,371,399,416,420,423,442,496,523,524,573,590,673],
      363=>[34,45,55,57,58,59,62,89,90,92,104,111,127,156,157,162,164,173,174,181,182,187,196,205,207,213,214,216,218,227,231,237,240,254,255,256,258,263,281,301,317,324,329,346,352,362,392,401,496,497,523,524,590],
      364=>[34,45,46,55,57,58,59,62,89,92,104,111,127,156,157,162,164,173,181,182,196,205,207,213,214,216,218,227,231,237,240,258,263,301,317,324,329,352,362,401,496,497,523,524,590],
      365=>[34,45,46,55,57,58,59,62,63,89,92,104,111,127,156,157,162,164,173,181,182,196,205,207,213,214,216,218,227,231,237,240,242,258,263,301,317,324,329,335,352,362,401,416,423,442,496,497,523,524,590,707],
      366=>[34,48,55,57,58,59,92,104,109,112,127,128,156,164,173,182,196,203,207,213,214,216,218,237,240,250,258,263,287,300,330,334,352,362,392,496,503,504,590],
      367=>[20,44,56,57,58,59,63,92,103,104,127,156,162,164,173,182,184,185,196,207,213,214,216,218,226,237,240,242,250,258,263,289,291,317,340,352,362,389,401,416,423,489,496,503,590,611],
      368=>[20,56,57,58,59,63,92,93,94,97,104,127,133,156,164,173,182,196,207,213,214,216,218,219,226,237,240,244,247,250,258,263,291,324,340,346,352,392,401,416,445,489,496,503,577,590,611],
      369=>[33,36,38,55,56,57,58,59,63,89,92,104,106,127,130,133,156,157,164,173,175,182,189,196,201,207,213,214,216,218,219,222,237,240,244,246,258,263,281,291,300,317,330,340,341,346,347,352,362,397,401,414,416,428,444,446,457,479,496,503,523,590,707],
      370=>[33,36,48,55,56,57,58,59,92,97,104,127,150,156,164,173,175,182,186,196,204,207,213,214,216,218,219,237,240,244,258,263,300,340,346,352,362,381,392,445,453,487,494,496,503,505,531,577,590,710],
      371=>[29,37,38,43,44,46,52,53,56,82,92,99,104,111,116,126,156,157,164,173,182,184,200,203,207,213,214,216,218,225,237,239,240,241,242,263,280,304,317,332,337,349,406,407,421,424,428,434,496,590],
      372=>[29,38,43,44,46,52,53,92,99,104,116,126,156,157,164,173,182,184,200,207,213,214,216,218,225,237,240,241,242,263,280,304,317,332,334,337,406,421,428,434,496,590],
      373=>[19,29,38,43,44,46,52,53,63,89,92,99,104,116,126,156,157,164,173,182,184,200,207,211,213,214,216,218,225,231,237,240,241,242,257,263,280,304,317,332,337,355,366,401,406,416,421,422,424,428,432,434,444,496,523,525,590,673,693],
      374=>[36,334,428,442],
      375=>[8,9,36,63,89,92,93,94,97,104,113,115,153,156,157,164,173,182,184,188,196,201,207,214,216,218,228,232,237,240,241,244,247,263,271,280,309,317,324,332,334,356,357,360,393,397,418,428,430,442,446,447,473,477,496,502,523,590],
      376=>[8,9,36,63,89,92,93,94,97,104,113,115,153,156,157,164,173,182,184,188,196,201,207,214,216,218,228,232,237,240,241,244,247,263,271,280,309,317,324,332,334,335,356,357,359,360,393,397,416,418,428,430,442,446,447,473,477,496,502,523,590,673,707],
      377=>[7,8,9,23,63,85,86,87,88,89,92,104,153,156,157,164,173,174,182,192,199,201,207,214,216,218,219,237,241,244,246,263,264,276,280,317,334,335,351,356,359,374,397,409,411,414,416,442,444,446,451,479,496,523,590,707],
      378=>[8,9,23,58,59,63,85,86,87,89,92,104,133,153,156,157,164,173,174,182,192,196,199,207,214,216,218,219,237,240,244,246,258,263,264,276,280,317,324,335,351,356,359,374,397,411,416,430,442,451,496,523,524,590,694,707],
      379=>[8,9,23,63,85,86,87,89,92,104,133,153,156,157,164,173,174,182,192,199,201,207,214,216,218,219,232,237,240,241,244,246,263,264,276,280,317,332,334,335,351,356,359,374,393,397,411,416,421,430,442,446,451,496,523,590,707],
      380=>[19,46,57,58,63,76,85,86,87,89,92,94,104,105,113,115,127,138,149,156,164,173,182,196,200,201,204,207,211,213,214,216,218,219,225,237,240,241,244,247,263,270,271,272,273,277,287,296,332,337,343,346,347,351,352,355,361,366,375,387,406,412,416,421,428,432,434,447,451,470,473,477,478,496,500,502,505,513,523,590,673],
      381=>[19,46,57,58,63,76,85,86,87,89,92,94,104,105,113,115,127,138,149,156,164,173,182,196,200,201,207,211,213,214,216,218,219,225,237,240,241,244,247,262,263,270,271,277,287,295,332,337,347,349,351,352,355,366,375,377,387,406,412,416,421,428,432,434,447,451,471,472,473,477,496,500,502,505,523,590,673],
      382=>[34,38,46,56,57,58,59,63,85,86,87,89,92,104,127,156,157,164,173,182,184,196,207,214,216,218,219,237,240,244,246,253,258,263,280,317,323,324,329,330,335,347,351,352,392,401,416,442,496,503,523,590,618,710],
      383=>[7,9,14,46,53,63,76,85,86,87,89,90,92,104,126,156,157,164,173,182,184,201,207,214,216,218,219,231,237,241,244,246,253,263,280,284,315,317,332,335,337,339,341,351,359,374,397,406,411,414,416,421,436,442,444,446,479,496,523,525,590,619,693,707],
      384=>[14,19,20,46,53,57,58,59,63,76,85,86,87,89,92,104,126,127,156,157,164,173,182,184,196,200,201,207,214,216,218,231,237,239,240,241,242,244,245,246,253,263,280,304,315,317,332,337,339,349,351,352,360,366,374,401,403,406,411,412,414,416,421,432,434,442,444,496,497,507,523,525,590,620,693],
      385=>[7,8,9,38,63,85,86,87,92,93,94,104,113,115,129,138,156,164,173,182,196,201,207,214,216,218,219,237,240,241,244,247,248,253,263,270,271,273,277,278,285,287,322,324,332,334,347,351,352,353,356,361,369,374,381,387,409,412,416,428,430,433,442,446,447,451,473,477,478,496,590,605],
      386=>[7,8,9,20,35,43,58,63,67,76,85,86,87,92,94,100,101,104,105,113,115,138,156,157,164,173,182,196,207,214,216,218,219,228,237,240,241,244,247,259,263,264,269,271,272,277,278,280,282,285,289,317,322,324,332,347,351,352,354,356,374,375,398,399,409,411,412,416,428,430,433,446,447,451,472,473,477,490,496,502,590,673,675,693,707],
      387=>[14,33,34,37,38,44,71,72,73,74,75,76,92,104,110,113,115,133,156,164,173,174,182,202,207,213,214,216,218,219,231,235,237,241,242,254,255,256,263,267,276,321,328,388,402,412,414,437,446,447,469,484,496,520,526,580,590],
      388=>[14,33,44,71,72,73,75,76,92,104,110,113,115,156,164,173,174,182,202,207,213,214,216,218,219,231,235,237,241,242,263,267,276,388,402,412,414,437,446,447,496,520,526,590],
      389=>[14,33,44,46,63,71,72,73,75,76,89,92,104,110,113,115,156,157,164,173,174,182,200,201,202,207,213,214,216,218,219,231,235,237,241,242,263,267,276,317,335,338,388,397,402,412,414,416,437,442,444,446,447,452,496,520,523,526,590,707],
      390=>[7,9,10,14,24,43,52,53,66,67,68,83,92,104,116,126,154,156,164,172,173,182,207,213,214,216,218,227,231,237,241,252,253,257,259,261,263,264,269,270,272,274,280,283,299,303,315,332,339,343,369,374,417,421,441,446,447,488,490,496,501,512,519,526,590,612],
      391=>[7,9,10,14,43,52,53,67,83,92,104,126,154,156,157,164,172,173,182,183,207,213,214,216,218,231,237,241,257,259,261,263,264,269,270,272,280,283,303,315,317,332,339,343,364,369,370,374,394,398,411,421,441,446,447,488,490,496,512,519,526,530,590],
      392=>[7,9,10,14,43,46,52,53,63,67,76,83,89,92,104,126,154,156,157,164,172,173,182,183,207,213,214,216,218,231,237,241,257,259,261,263,264,269,270,272,280,283,307,315,317,332,339,343,347,364,369,370,374,386,394,398,411,416,421,441,444,446,447,488,490,496,512,519,523,526,530,590,673],
      393=>[1,31,45,48,54,56,57,58,59,61,64,65,92,97,104,117,127,145,156,164,173,175,182,189,196,207,213,214,216,218,237,240,250,258,263,280,281,297,300,317,324,332,343,346,352,362,374,392,432,446,447,458,496,497,503,511,518,526,590,681],
      394=>[31,33,45,54,56,57,58,59,61,64,65,92,104,117,127,145,156,164,173,182,196,207,213,214,216,218,232,237,240,250,258,263,280,317,324,332,343,346,352,362,374,421,432,446,447,496,497,503,511,518,526,590],
      395=>[14,31,33,45,46,54,56,57,58,59,61,63,64,65,89,92,104,127,145,156,157,164,173,182,196,207,211,213,214,216,218,232,237,240,250,258,263,280,282,308,317,324,332,334,343,352,362,374,416,421,430,432,446,447,453,496,497,503,511,518,523,526,590,673,675,710],
      396=>[17,18,19,28,31,33,36,38,45,92,97,98,104,119,156,164,168,173,182,193,197,207,211,213,214,216,218,228,237,240,241,253,257,263,279,283,297,310,332,355,366,369,413,432,496,497,515,526,590],
      397=>[17,18,19,33,36,45,92,97,98,104,156,164,168,173,182,207,211,213,214,216,218,237,240,241,253,257,263,283,332,355,366,369,413,432,496,497,515,526,590],
      398=>[17,18,19,33,36,45,63,92,97,98,104,143,156,164,168,173,182,207,211,213,214,216,218,237,240,241,253,257,263,283,332,355,366,369,370,413,416,432,496,497,515,526,590,673],
      399=>[14,29,33,36,38,45,58,59,85,86,87,92,98,104,111,130,133,154,156,158,162,164,168,173,174,182,196,203,205,207,213,214,216,218,231,237,240,241,242,247,263,269,276,281,300,316,343,346,351,387,401,431,446,447,451,496,497,526,590],
      400=>[14,29,33,36,45,55,57,58,59,63,85,86,87,92,104,111,127,133,156,158,162,164,168,173,174,182,196,205,207,213,214,216,218,231,237,240,241,242,247,263,264,269,276,281,343,351,352,374,387,401,416,446,447,451,453,496,497,503,523,526,563,590,707,710],
      401=>[45,117,173,253,283,450,522],
      402=>[14,45,47,63,71,92,103,104,116,117,141,156,163,164,173,182,195,206,207,210,213,214,215,216,218,237,240,241,253,263,269,280,282,283,304,332,400,404,405,416,450,496,497,564,565,590,611,673,675],
      403=>[24,33,36,43,44,46,85,86,87,92,98,104,113,129,156,164,168,173,182,184,207,209,213,214,216,218,231,237,240,242,263,268,270,313,324,336,351,393,400,422,423,424,435,451,496,521,528,555,590,598,608],
      404=>[33,43,44,46,85,86,87,92,104,113,156,164,168,173,182,184,207,209,213,214,216,218,231,237,240,242,263,268,270,324,351,393,422,435,451,496,521,528,555,590],
      405=>[33,43,44,46,63,85,86,87,92,104,113,156,164,168,173,182,184,207,209,213,214,216,218,231,237,240,242,263,268,270,276,324,351,393,416,422,435,451,496,521,528,555,590,604,673,675],
      406=>[14,42,71,72,74,75,76,78,79,92,104,156,164,170,173,178,182,188,191,202,207,213,214,216,218,235,237,240,241,244,247,253,263,267,320,326,343,346,363,388,402,412,437,447,474,496,590,605],
      407=>[14,40,63,72,76,92,104,156,164,173,182,188,202,207,213,214,216,218,230,235,237,240,241,244,247,263,267,311,343,345,388,398,402,412,416,447,474,496,580,590,599,605,673],
      408=>[7,9,14,18,21,23,29,36,37,38,43,46,53,58,59,85,87,89,92,103,104,116,126,156,157,164,168,173,174,180,182,184,201,207,213,214,216,218,228,231,237,240,241,242,246,253,263,276,283,317,351,359,371,372,374,397,406,414,428,442,444,446,457,479,496,498,523,590],
      409=>[7,9,14,29,36,43,46,53,57,58,59,63,85,87,89,92,103,104,116,126,156,157,164,168,173,180,182,184,200,201,207,213,214,216,218,220,228,231,237,240,241,246,253,263,264,276,280,283,317,351,371,372,374,397,406,411,414,416,428,442,444,446,457,479,496,498,523,525,590,673,707],
      410=>[29,33,34,36,38,46,53,58,59,68,85,87,89,90,92,103,104,116,126,156,157,164,173,174,182,184,201,203,207,213,214,216,218,231,237,240,241,246,259,263,269,317,319,334,350,351,368,393,397,414,430,442,444,446,469,470,479,484,496,523,590],
      411=>[33,36,46,53,58,59,63,85,87,89,92,104,126,156,157,164,173,182,200,201,203,207,213,214,216,218,231,237,240,241,246,259,263,269,277,317,319,334,335,351,368,393,397,414,416,430,442,444,446,479,484,496,523,590,707],
      412=>[33,173,182,237,450,527],
      413=>[33,60,63,74,75,76,92,93,94,104,138,156,164,168,173,175,182,202,207,213,214,216,218,219,235,237,240,241,244,247,253,263,283,285,324,388,389,402,405,412,416,437,445,447,450,474,477,483,496,502,527,590,611],
      414=>[16,33,60,63,76,77,92,93,94,104,138,156,164,168,173,182,202,207,213,214,216,218,219,237,240,241,244,247,263,285,293,318,324,332,355,366,369,403,405,412,416,432,450,474,483,496,512,527,590,611,679],
      415=>[16,173,230,283,366,405,450],
      416=>[16,40,63,92,104,109,154,156,163,164,168,173,182,188,194,207,210,213,214,216,218,228,230,237,240,241,263,283,324,332,355,366,369,374,403,404,408,416,432,445,450,454,455,456,474,496,511,512,565,590,611,673],
      417=>[9,39,44,45,85,86,87,92,98,104,111,113,117,129,156,158,162,164,173,175,182,186,203,204,205,207,209,213,214,216,218,231,237,240,253,260,263,266,268,270,313,343,351,369,374,387,393,402,435,441,447,451,486,496,497,516,521,527,569,590,608,609,673],
      418=>[3,8,13,29,45,49,55,56,57,58,59,92,97,98,104,127,129,154,156,163,164,173,182,189,196,207,210,213,214,216,218,226,228,231,237,240,250,258,263,264,270,280,316,317,339,346,352,382,392,401,415,453,458,487,496,497,503,541,590],
      419=>[8,13,45,46,49,55,56,57,58,59,63,67,92,97,98,104,127,129,156,164,173,182,196,207,213,214,216,218,228,231,237,240,242,250,258,259,263,264,269,270,280,317,339,346,352,371,401,411,416,423,453,458,496,497,503,590,710],
      420=>[14,33,36,73,74,75,76,92,104,111,156,164,173,182,202,205,207,213,214,216,218,219,230,234,235,237,241,263,267,270,311,312,320,321,345,361,363,381,388,402,412,447,496,505,572,579,580,590,605],
      421=>[14,33,36,63,73,74,76,80,92,104,156,164,173,182,202,207,213,214,216,218,219,234,235,237,241,263,267,270,345,381,388,402,412,416,447,496,572,590,605,673],
      422=>[34,54,57,58,59,68,90,92,104,105,106,124,133,151,156,164,173,174,182,189,196,207,213,214,216,218,220,237,240,243,254,255,256,258,262,263,281,300,330,352,362,376,414,426,496,499,503,590,611],
      423=>[34,57,58,59,63,89,92,104,105,106,127,156,157,164,173,182,188,189,196,201,207,213,214,216,218,220,237,240,258,263,300,317,330,335,352,414,416,426,444,482,496,503,523,590,611,707],
      424=>[7,8,9,10,28,39,63,67,76,85,86,87,92,97,103,104,129,138,154,156,164,168,173,180,182,207,213,214,216,218,226,231,237,240,241,247,253,263,264,269,272,280,282,289,310,321,332,340,343,351,352,369,371,374,387,402,416,417,421,441,447,458,490,492,496,512,526,530,590,673],
      425=>[16,20,34,50,85,86,87,92,94,95,104,107,114,116,132,133,138,153,156,164,168,173,180,182,194,196,207,213,214,216,218,220,226,237,240,241,244,247,254,255,256,261,262,263,271,277,278,282,285,310,311,347,351,360,366,371,373,432,451,466,477,496,499,502,506,512,590],
      426=>[16,19,20,63,85,86,87,92,94,104,107,116,132,133,138,153,156,164,168,173,180,182,196,207,213,214,216,218,220,226,237,240,241,244,247,254,255,256,261,263,271,277,278,282,285,310,347,351,360,366,371,373,416,432,451,466,477,496,502,506,512,566,590],
      427=>[1,7,8,9,26,58,67,76,85,86,92,97,98,104,111,146,150,156,164,173,175,182,186,193,203,204,207,213,214,215,216,218,226,227,231,237,240,241,247,252,253,263,264,270,277,283,298,300,304,313,322,327,340,343,351,352,361,374,383,387,409,415,447,451,458,494,495,496,509,526,590,608,612],
      428=>[1,7,8,9,26,58,59,63,67,76,85,86,87,92,97,98,104,111,136,146,150,156,164,173,182,193,203,204,207,213,214,215,216,218,226,231,237,240,241,243,247,253,263,264,270,277,283,304,340,343,351,352,361,374,387,409,411,416,447,451,490,494,495,496,526,563,590,608,673,693],
      429=>[45,63,85,86,87,92,94,104,138,149,156,164,168,173,180,182,196,207,213,214,215,216,218,220,237,240,241,244,247,253,259,261,263,269,271,277,285,289,304,310,332,345,347,351,371,373,381,399,408,412,416,433,451,472,477,478,492,496,497,502,566,590,595,605,673],
      430=>[17,19,63,86,92,94,104,114,138,143,156,164,168,173,180,182,196,207,211,213,214,216,218,228,237,240,241,244,247,253,257,259,263,269,276,289,310,332,347,355,366,371,373,389,399,400,416,417,432,492,496,511,555,590],
      431=>[10,28,39,44,45,85,87,92,95,98,104,138,154,156,162,163,164,168,173,175,182,185,204,207,213,214,216,218,231,237,240,241,244,247,252,259,263,269,274,282,289,304,313,332,343,351,352,358,369,371,372,387,389,421,445,468,492,496,497,526,583,590],
      432=>[10,34,45,46,63,85,87,92,95,104,138,154,156,162,163,164,168,173,182,185,204,207,213,214,216,218,231,237,240,241,244,247,252,259,263,269,274,282,289,304,332,343,351,352,369,371,387,416,421,445,468,492,496,497,523,526,590,675,707],
      433=>[20,35,45,50,86,92,93,94,95,104,105,113,115,138,156,164,173,174,182,196,207,213,214,215,216,218,219,237,240,241,244,247,248,253,259,263,269,270,271,273,277,278,281,282,285,289,304,310,322,324,347,351,356,387,428,433,447,451,473,477,494,496,497,500,502,590,605],
      434=>[10,38,43,44,46,53,92,103,104,108,114,116,123,126,139,153,154,156,163,164,168,173,182,184,188,207,213,214,216,218,228,231,237,240,241,242,247,259,262,263,269,289,310,364,371,386,389,399,400,421,432,474,481,491,492,496,555,562,583,590,599,675],
      435=>[10,44,46,53,63,92,103,104,108,116,126,139,153,154,156,163,164,168,173,182,188,207,213,214,216,218,231,237,240,241,247,259,262,263,269,289,364,371,389,398,399,400,416,421,432,474,491,492,496,555,562,590,599,675],
      436=>[33,76,89,92,93,94,95,104,109,113,115,138,149,156,157,164,173,182,185,201,207,214,216,218,219,237,240,241,244,247,248,263,271,278,285,286,317,319,324,326,334,347,356,360,371,377,397,430,433,446,447,451,472,473,477,484,496,502,523,590],
      437=>[33,63,76,89,92,93,94,95,104,109,113,115,138,149,153,156,157,164,173,182,185,201,207,214,216,218,219,237,240,241,244,247,248,263,271,278,285,286,317,319,324,326,334,335,347,356,360,371,377,397,416,428,430,433,442,446,447,451,472,473,477,484,496,502,523,590],
      438=>[29,38,67,68,88,92,102,104,106,111,120,153,156,157,164,168,173,174,175,182,185,201,203,205,207,213,214,216,218,237,241,244,253,263,267,270,272,280,313,317,328,335,343,347,383,389,397,414,446,479,492,495,496,590,707,715],
      439=>[1,3,60,76,85,86,87,92,93,94,95,96,102,104,109,112,113,115,138,156,164,168,173,182,196,204,207,213,214,216,218,219,226,227,237,240,241,244,247,248,252,253,259,263,264,269,270,271,272,277,278,280,285,289,298,321,324,343,347,351,358,361,374,383,409,417,433,447,451,471,472,473,477,478,496,502,590,611,678],
      440=>[1,53,68,76,86,92,94,104,113,118,126,138,156,164,173,182,186,196,203,204,207,213,214,215,216,217,218,219,237,240,241,244,247,253,258,263,270,278,283,287,304,312,343,351,352,356,363,374,383,387,409,426,428,447,496,497,526,590],
      441=>[19,31,45,47,48,64,92,97,101,102,104,119,143,156,164,168,173,182,207,211,213,214,216,218,227,237,240,241,253,257,259,263,269,272,297,304,314,332,355,366,369,417,432,448,485,496,497,526,586,590],
      442=>[50,63,92,94,95,104,108,109,138,156,164,168,171,173,174,180,182,185,194,196,207,213,214,216,218,220,228,237,240,241,244,247,253,259,261,262,263,269,271,286,288,289,317,347,351,352,373,389,399,416,417,425,445,466,472,477,492,496,502,511,555,590,611],
      443=>[28,33,34,36,37,38,46,53,82,89,91,92,104,126,156,157,163,164,173,182,184,200,201,207,213,214,216,218,225,231,232,237,239,240,241,263,317,328,332,337,341,406,407,414,421,431,434,442,444,446,496,523,590],
      444=>[28,33,36,46,53,82,89,91,92,104,126,156,157,163,164,173,182,200,201,207,213,214,216,218,231,237,240,241,263,317,328,332,337,406,407,414,421,434,442,444,446,496,523,530,590,673],
      445=>[14,28,33,36,46,53,57,63,82,89,91,92,104,126,156,157,163,164,173,182,200,201,206,207,213,214,216,218,231,237,240,241,242,263,280,317,328,332,337,374,398,401,406,407,414,416,421,424,434,442,444,446,496,523,525,530,590,673,693,707],
      446=>[7,8,9,18,33,34,38,53,57,58,59,68,76,85,87,89,92,94,103,104,111,118,120,122,126,133,156,157,164,173,174,182,187,196,201,204,205,207,213,214,216,218,228,237,240,241,247,253,254,256,263,264,276,278,280,289,304,316,317,343,351,352,363,374,387,402,428,441,495,496,498,523,526,562,590,707],
      447=>[8,9,14,44,46,67,68,89,92,97,98,103,104,136,156,157,164,170,173,179,182,193,197,203,207,213,214,216,218,231,237,238,240,241,242,263,264,266,270,272,280,299,309,317,327,334,339,364,371,374,383,393,395,398,409,410,411,417,418,421,428,490,496,509,515,523,526,530,590,673],
      448=>[8,9,14,46,63,67,68,89,92,94,98,104,156,157,164,173,182,193,197,198,207,213,214,216,218,231,232,237,240,241,245,247,263,264,270,272,280,317,319,334,339,347,352,364,370,371,374,382,393,396,398,399,406,409,411,416,421,428,430,444,490,496,501,505,523,526,530,590,612,673],
      449=>[18,28,33,34,36,38,44,46,89,90,91,92,104,156,157,164,173,174,182,201,207,213,214,216,218,231,237,241,242,254,255,256,263,276,279,281,303,317,328,352,414,446,496,523,590,707],
      450=>[28,33,36,38,44,46,63,89,90,91,92,104,156,157,164,173,182,201,207,213,214,216,218,231,237,241,242,263,276,281,317,328,352,414,416,422,423,424,442,444,446,496,523,590,707],
      451=>[14,18,28,40,41,42,43,44,92,97,103,104,109,156,163,164,168,173,182,184,185,188,206,207,213,214,216,218,228,231,237,240,241,242,247,259,263,269,280,282,305,317,332,342,367,371,374,390,398,399,400,401,404,440,450,468,474,496,565,590,611],
      452=>[14,40,42,43,44,46,63,89,92,104,156,157,164,168,173,182,184,188,206,207,213,214,216,218,228,231,237,240,241,242,247,259,263,269,280,282,305,317,332,367,371,374,390,398,399,400,401,404,416,422,423,424,440,450,468,474,496,523,555,565,590,611,675,693,707],
      453=>[8,9,29,40,67,68,89,92,96,104,156,157,162,164,168,173,180,182,185,188,189,196,207,213,214,216,218,223,228,237,238,240,241,247,252,259,260,263,264,265,269,270,272,279,280,282,289,310,317,339,340,358,364,367,371,373,374,382,389,398,399,404,409,410,411,417,418,426,441,474,482,490,492,496,501,523,526,530,562,590],
      454=>[8,9,14,40,63,67,89,92,104,156,157,162,164,168,173,180,182,185,188,189,196,207,213,214,216,218,228,237,240,241,247,259,260,263,264,269,270,272,279,280,282,289,310,317,339,340,371,373,374,389,398,399,404,409,411,416,417,426,441,444,474,482,490,492,496,523,526,530,562,590,675],
      455=>[14,20,21,22,44,63,73,74,75,76,78,79,92,104,156,164,168,173,182,185,188,202,207,213,214,216,218,230,235,237,241,242,254,255,256,263,267,275,282,320,345,371,374,378,380,388,402,412,416,432,438,447,450,476,491,496,536,590,611,675],
      456=>[1,16,55,57,58,59,60,62,92,97,104,109,127,150,156,164,173,175,182,186,196,204,207,213,214,216,218,219,237,240,244,250,258,263,267,318,321,324,340,352,362,366,369,371,392,401,432,445,487,496,503,590],
      457=>[1,16,55,57,58,59,63,92,104,127,156,164,173,182,196,207,213,214,216,218,219,237,240,244,250,258,263,318,324,340,352,366,369,371,392,401,416,432,445,487,496,503,590],
      458=>[17,21,29,33,36,48,56,57,58,59,61,89,92,97,104,109,114,127,133,145,150,156,157,164,173,182,196,207,213,214,216,218,237,239,240,243,258,263,270,300,324,332,340,346,352,366,392,403,469,496,503,512,523,590],
      459=>[8,14,23,38,43,54,58,59,73,74,75,76,92,104,113,130,156,164,173,181,182,196,202,207,213,214,216,218,219,231,235,237,240,247,258,263,272,275,320,329,331,345,352,363,388,402,412,419,420,447,452,496,524,590],
      460=>[8,14,43,54,58,59,63,75,76,89,92,104,113,156,157,164,173,181,182,196,200,202,207,213,214,216,218,219,231,235,237,240,247,258,263,264,272,275,280,317,320,329,335,352,374,388,402,411,412,416,420,447,452,496,523,524,590,707],
      461=>[8,10,14,43,57,58,59,63,67,92,98,103,104,115,138,154,156,164,168,173,180,182,185,196,206,207,213,214,216,218,231,232,237,240,241,244,247,258,259,263,264,269,279,280,282,289,332,347,371,372,373,374,386,398,399,400,404,411,416,417,421,468,490,492,496,555,590,673,675],
      462=>[33,48,49,63,84,85,86,87,92,103,104,112,113,115,153,156,161,164,173,182,192,199,207,209,214,216,218,237,240,241,243,244,263,277,278,319,324,334,351,356,360,393,416,429,430,435,442,443,451,486,496,502,521,527,528,590,602,604],
      463=>[7,8,9,14,20,21,23,35,48,50,53,57,58,59,63,76,85,87,89,92,103,104,111,122,126,138,153,156,157,164,168,173,182,196,201,205,207,213,214,216,218,231,237,240,241,244,247,263,264,280,282,287,317,335,351,352,360,374,378,382,401,411,416,428,438,496,498,523,525,526,590,693,707],
      464=>[7,8,9,14,23,30,31,32,36,39,46,53,57,58,59,63,85,87,89,92,104,126,156,157,164,168,173,180,182,184,196,200,201,207,213,214,216,218,224,231,237,240,241,253,263,264,276,280,283,317,335,350,351,359,371,374,397,398,401,406,411,414,416,421,430,439,442,444,446,479,496,498,523,525,529,590,684,693,707],
      465=>[14,20,21,22,63,71,72,74,76,77,78,79,89,92,104,115,132,156,157,164,168,173,182,188,202,207,213,214,216,218,220,235,237,241,244,246,263,267,275,280,282,283,317,321,332,335,351,363,371,374,378,388,398,402,411,412,416,438,447,496,523,580,590,611,707],
      466=>[7,8,9,43,53,63,67,84,85,86,87,89,92,94,98,103,104,113,129,156,157,164,168,173,182,207,213,214,216,218,231,237,240,259,263,264,269,270,280,317,324,343,351,374,393,411,416,435,451,486,490,496,521,523,527,528,530,569,590,604,707],
      467=>[7,9,43,52,53,63,67,76,83,85,89,92,94,104,108,109,123,126,156,157,164,168,173,182,185,207,213,214,216,218,231,237,241,257,259,261,263,264,269,270,280,315,317,343,374,411,416,436,481,488,490,496,499,523,530,590,707],
      468=>[19,53,63,76,86,92,94,104,113,115,126,138,143,156,164,173,182,207,211,213,214,215,216,218,219,237,240,241,244,245,247,257,263,264,271,277,280,283,304,324,332,343,351,352,355,366,374,387,396,403,409,416,428,432,447,473,477,495,496,497,526,590,605,673],
      469=>[33,48,49,63,76,92,94,98,103,104,138,141,156,163,164,168,173,182,193,197,202,207,211,213,214,216,218,228,237,241,244,246,247,253,263,324,332,355,364,366,369,400,403,405,416,432,450,496,590,673],
      470=>[14,28,33,39,46,63,75,76,92,98,104,156,164,173,182,202,207,213,214,215,216,218,231,235,237,240,241,247,263,267,270,282,304,320,332,343,345,348,387,388,402,404,412,416,447,496,497,526,590,608,673],
      471=>[28,33,39,44,46,58,59,63,92,98,104,112,156,164,173,182,196,207,213,214,215,216,218,231,237,240,241,243,247,258,263,270,304,324,343,352,387,401,416,420,423,496,497,524,526,590,608,673,694],
      472=>[12,14,28,63,89,92,98,103,104,106,143,156,157,164,168,173,182,185,188,201,206,207,210,211,213,214,216,218,231,237,240,241,259,263,269,280,282,317,327,332,355,366,369,371,374,397,398,399,400,401,404,414,416,422,423,424,432,444,446,450,474,496,512,523,590,675,693],
      473=>[31,36,37,46,54,58,59,63,64,89,92,104,113,115,156,157,164,173,181,182,184,189,196,201,203,207,213,214,216,218,237,240,246,258,263,276,282,283,300,316,317,335,414,416,423,426,442,444,446,458,496,523,590,707],
      474=>[33,58,59,60,63,76,85,86,87,92,94,97,104,105,138,156,160,161,164,168,173,176,182,192,196,199,207,214,216,218,220,231,237,240,241,244,247,253,263,271,277,278,324,332,351,356,373,387,393,399,416,417,428,433,435,451,472,473,477,492,496,502,527,590],
      475=>[7,8,9,14,43,63,67,85,86,89,92,93,94,100,104,113,115,138,156,157,163,164,168,173,182,206,207,210,213,214,216,218,219,220,237,240,241,244,247,259,261,263,264,269,270,271,277,278,280,282,285,289,304,317,324,332,339,347,348,351,364,370,374,398,400,404,409,411,416,427,428,433,444,447,451,469,472,473,477,478,490,496,497,500,501,502,505,523,526,530,590,605,673,675],
      476=>[7,8,9,33,63,85,86,87,89,92,104,153,156,157,161,164,173,182,192,199,201,207,209,213,214,216,218,220,237,241,259,263,269,277,317,334,335,350,351,356,393,397,408,414,416,430,435,442,443,444,446,469,477,479,496,502,521,523,590,602,605,707],
      477=>[7,8,9,20,43,50,58,59,63,89,92,94,101,104,109,138,156,157,164,168,173,174,180,182,193,196,207,212,213,214,216,218,220,228,237,240,241,244,247,248,259,261,263,264,269,271,280,285,289,310,317,325,347,356,371,373,374,399,411,416,425,433,451,472,477,496,502,506,523,590,611,673],
      478=>[8,43,58,59,63,85,86,87,92,94,104,109,113,138,156,164,173,180,181,182,194,196,207,213,214,216,218,219,220,237,240,244,247,258,259,261,263,269,271,289,310,324,335,351,352,358,371,373,374,416,420,445,466,477,496,502,524,577,590,673,694],
      479=>[84,85,86,87,92,104,109,113,115,138,156,164,168,173,180,182,207,214,216,218,220,237,240,241,244,247,253,261,263,268,271,289,310,324,351,399,432,435,451,466,477,486,492,496,502,506,521,527,590],
      480=>[7,8,9,63,76,85,86,87,92,93,94,104,113,115,129,133,138,156,164,173,175,182,201,202,203,207,214,215,216,218,219,231,237,240,241,244,247,248,262,263,270,271,272,277,278,281,282,285,286,324,326,347,351,352,363,369,374,412,416,428,433,446,447,451,472,473,477,478,492,496,502,512,590,605,673],
      481=>[7,8,9,58,59,63,85,86,87,92,93,94,104,113,115,129,138,156,164,173,182,201,204,207,214,216,218,219,231,237,240,241,244,247,248,263,270,271,272,277,278,282,285,286,324,326,347,351,352,361,363,369,374,381,383,412,416,428,433,446,447,451,472,473,477,478,496,502,512,590,605,673],
      482=>[7,8,9,53,63,85,86,87,92,93,94,104,113,115,126,129,138,153,156,164,173,182,197,201,207,214,216,218,219,231,237,240,241,244,247,248,253,259,263,269,270,271,272,277,278,282,285,286,324,326,347,351,352,363,369,371,374,387,412,416,417,428,433,446,447,451,472,473,477,478,496,502,512,590,605,673],
      483=>[46,53,58,59,63,85,86,87,89,92,104,126,156,157,163,164,173,182,184,200,201,207,214,216,218,219,225,231,232,237,240,241,244,246,263,280,304,315,317,332,334,337,339,351,356,368,393,396,406,408,414,416,421,430,433,434,442,444,446,459,496,497,523,525,590,707],
      484=>[46,53,56,57,58,59,63,85,86,87,89,92,104,126,156,157,163,164,173,182,184,200,201,207,214,216,218,219,225,237,240,241,244,246,258,263,264,280,304,317,332,337,339,351,352,356,374,392,396,401,406,408,411,414,416,421,433,434,444,460,496,497,523,525,590,707,710],
      485=>[43,46,53,63,76,83,89,92,104,126,153,156,157,164,173,182,184,207,213,214,216,218,237,241,242,246,253,257,259,261,263,267,269,315,317,319,334,371,399,406,414,416,424,430,436,442,444,446,450,463,488,496,523,590,707],
      486=>[7,8,9,63,85,86,87,89,92,104,109,146,157,164,173,193,196,207,214,216,218,219,237,240,241,244,263,264,267,276,279,280,282,317,332,335,351,356,371,374,397,409,411,414,416,428,442,444,462,469,479,484,496,523,590,707],
      487=>[19,46,63,85,86,87,89,92,94,104,138,156,163,164,173,180,182,184,194,196,200,207,211,214,216,218,219,220,225,231,237,240,241,244,246,247,261,263,304,332,337,347,351,356,371,396,399,401,406,412,414,416,421,425,432,434,442,444,451,466,467,477,496,497,506,523,525,590,693],
      488=>[54,58,62,63,76,86,92,93,94,104,113,115,138,156,163,164,173,182,196,207,213,214,216,218,219,236,237,240,241,244,247,248,263,270,271,277,278,285,324,347,356,375,412,416,427,428,433,447,451,461,473,477,478,496,502,585,590],
      489=>[48,57,58,59,61,92,104,127,145,151,156,164,173,182,196,204,207,214,215,216,218,219,237,240,244,250,253,258,263,270,282,291,324,340,343,346,352,369,374,387,392,447,496,503,590,605,710],
      490=>[48,57,58,59,61,63,92,94,104,113,115,127,145,151,156,164,173,182,196,204,207,214,215,216,218,219,237,240,244,247,250,253,258,263,270,282,285,291,294,324,340,343,346,347,352,369,374,387,391,392,412,416,447,496,503,590,605,710],
      491=>[14,50,58,59,63,85,86,87,92,94,95,98,104,114,138,156,157,164,168,171,173,180,182,185,188,196,207,214,216,218,237,240,241,244,247,259,261,263,264,269,271,280,282,289,317,332,347,351,371,373,374,387,398,399,404,409,411,416,417,421,451,464,466,472,492,496,555,590,675],
      492=>[14,63,73,74,76,92,94,104,156,164,173,182,186,202,207,214,216,218,219,230,235,237,241,244,263,267,283,312,343,345,361,363,387,388,402,412,414,416,428,447,465,496,590,605,673],
      493=>[14,19,46,53,57,58,59,63,69,76,85,86,87,89,92,94,104,105,113,115,126,127,138,156,157,164,173,182,188,195,196,200,201,202,207,214,216,218,219,231,237,240,241,244,245,247,248,257,258,261,263,271,277,278,280,287,304,315,317,322,324,332,334,337,347,351,352,356,363,366,371,386,387,398,399,401,404,406,411,412,414,416,421,428,430,432,433,434,442,444,446,447,449,451,473,477,496,497,511,523,526,555,590,673,710],
      494=>[7,9,29,38,53,63,76,85,86,87,92,93,94,98,104,113,116,126,156,164,173,179,182,203,207,214,216,218,219,237,241,244,247,253,257,261,263,269,270,271,272,277,280,285,315,324,340,351,369,373,374,387,394,411,412,416,428,433,447,451,473,477,481,488,496,500,510,515,517,526,528,545,590,605,673],
    }
    # dex => [[target_dex, auto_level, trigger, original_condition_hash], ...]
    EVOLUTION_OPTIONS = {
      1=>[[2,16,:level,{}]],
      2=>[[3,32,:level,{}]],
      4=>[[5,16,:level,{}]],
      5=>[[6,36,:level,{}]],
      7=>[[8,16,:level,{}]],
      8=>[[9,36,:level,{}]],
      10=>[[11,7,:level,{}]],
      11=>[[12,10,:level,{}]],
      13=>[[14,7,:level,{}]],
      14=>[[15,10,:level,{}]],
      16=>[[17,18,:level,{}]],
      17=>[[18,36,:level,{}]],
      19=>[[20,20,:level,{}]],
      21=>[[22,20,:level,{}]],
      23=>[[24,22,:level,{}]],
      25=>[[26,36,:item,{:item=>"thunder-stone"}]],
      27=>[[28,22,:level,{}]],
      29=>[[30,16,:level,{}]],
      30=>[[31,36,:item,{:item=>"moon-stone"}]],
      32=>[[33,16,:level,{}]],
      33=>[[34,36,:item,{:item=>"moon-stone"}]],
      35=>[[36,36,:item,{:item=>"moon-stone"}]],
      37=>[[38,30,:item,{:item=>"fire-stone"}]],
      39=>[[40,36,:item,{:item=>"moon-stone"}]],
      41=>[[42,22,:level,{}]],
      42=>[[169,30,:level,{:happiness=>160}]],
      43=>[[44,21,:level,{}]],
      44=>[[45,36,:item,{:item=>"leaf-stone"}],[182,36,:item,{:item=>"sun-stone"}]],
      46=>[[47,24,:level,{}]],
      48=>[[49,31,:level,{}]],
      50=>[[51,26,:level,{}]],
      52=>[[53,28,:level,{}]],
      54=>[[55,33,:level,{}]],
      56=>[[57,28,:level,{}]],
      58=>[[59,30,:item,{:item=>"fire-stone"}]],
      60=>[[61,25,:level,{}]],
      61=>[[62,36,:item,{:item=>"water-stone"}],[186,36,:trade,{:held_item=>"kings-rock"}]],
      63=>[[64,16,:level,{}]],
      64=>[[65,36,:trade,{}]],
      66=>[[67,28,:level,{}]],
      67=>[[68,36,:trade,{}]],
      69=>[[70,21,:level,{}]],
      70=>[[71,36,:item,{:item=>"leaf-stone"}]],
      72=>[[73,30,:level,{}]],
      74=>[[75,25,:level,{}]],
      75=>[[76,36,:trade,{}]],
      77=>[[78,40,:level,{}]],
      79=>[[80,37,:level,{}],[199,37,:trade,{:held_item=>"kings-rock"}]],
      81=>[[82,30,:level,{}]],
      82=>[[462,36,:level,{:location_id=>10}]],
      84=>[[85,31,:level,{}]],
      86=>[[87,34,:level,{}]],
      88=>[[89,38,:level,{}]],
      90=>[[91,30,:item,{:item=>"water-stone"}]],
      92=>[[93,25,:level,{}]],
      93=>[[94,36,:trade,{}]],
      95=>[[208,30,:trade,{:held_item=>"metal-coat"}]],
      96=>[[97,26,:level,{}]],
      98=>[[99,28,:level,{}]],
      100=>[[101,30,:level,{}]],
      102=>[[103,30,:item,{:item=>"leaf-stone"}]],
      104=>[[105,28,:level,{}]],
      108=>[[463,30,:level,{:known_move_id=>205}]],
      109=>[[110,35,:level,{}]],
      111=>[[112,42,:level,{}]],
      112=>[[464,36,:trade,{:held_item=>"protector"}]],
      113=>[[242,30,:level,{:happiness=>160}]],
      114=>[[465,30,:level,{:known_move_id=>246}]],
      116=>[[117,32,:level,{}]],
      117=>[[230,36,:trade,{:held_item=>"dragon-scale"}]],
      118=>[[119,33,:level,{}]],
      120=>[[121,30,:item,{:item=>"water-stone"}]],
      123=>[[212,30,:trade,{:held_item=>"metal-coat"}]],
      125=>[[466,36,:trade,{:held_item=>"electirizer"}]],
      126=>[[467,36,:trade,{:held_item=>"magmarizer"}]],
      129=>[[130,20,:level,{}]],
      133=>[[134,30,:item,{:item=>"water-stone"}],[135,30,:item,{:item=>"thunder-stone"}],[136,30,:item,{:item=>"fire-stone"}],[196,30,:level,{:happiness=>160,:time=>"day"}],[197,30,:level,{:happiness=>160,:time=>"night"}],[470,30,:level,{:location_id=>8}],[471,30,:level,{:location_id=>48}]],
      137=>[[233,30,:trade,{:held_item=>"up-grade"}]],
      138=>[[139,40,:level,{}]],
      140=>[[141,40,:level,{}]],
      147=>[[148,30,:level,{}]],
      148=>[[149,55,:level,{}]],
      152=>[[153,16,:level,{}]],
      153=>[[154,32,:level,{}]],
      155=>[[156,14,:level,{}]],
      156=>[[157,36,:level,{}]],
      158=>[[159,18,:level,{}]],
      159=>[[160,30,:level,{}]],
      161=>[[162,15,:level,{}]],
      163=>[[164,20,:level,{}]],
      165=>[[166,18,:level,{}]],
      167=>[[168,22,:level,{}]],
      170=>[[171,27,:level,{}]],
      172=>[[25,20,:level,{:happiness=>220}]],
      173=>[[35,20,:level,{:happiness=>160}]],
      174=>[[39,20,:level,{:happiness=>160}]],
      175=>[[176,20,:level,{:happiness=>160}]],
      176=>[[468,36,:item,{:item=>"shiny-stone"}]],
      177=>[[178,25,:level,{}]],
      179=>[[180,15,:level,{}]],
      180=>[[181,30,:level,{}]],
      183=>[[184,18,:level,{}]],
      187=>[[188,18,:level,{}]],
      188=>[[189,27,:level,{}]],
      190=>[[424,30,:level,{:known_move_id=>458}]],
      191=>[[192,30,:item,{:item=>"sun-stone"}]],
      193=>[[469,30,:level,{:known_move_id=>246}]],
      194=>[[195,20,:level,{}]],
      198=>[[430,30,:item,{:item=>"dusk-stone"}]],
      200=>[[429,30,:item,{:item=>"dusk-stone"}]],
      204=>[[205,31,:level,{}]],
      207=>[[472,30,:level,{:held_item=>"razor-fang",:time=>"night"}]],
      209=>[[210,23,:level,{}]],
      215=>[[461,30,:level,{:held_item=>"razor-claw",:time=>"night"}]],
      216=>[[217,30,:level,{}]],
      218=>[[219,38,:level,{}]],
      220=>[[221,33,:level,{}]],
      221=>[[473,36,:level,{:known_move_id=>246}]],
      223=>[[224,25,:level,{}]],
      228=>[[229,24,:level,{}]],
      231=>[[232,25,:level,{}]],
      233=>[[474,36,:trade,{:held_item=>"dubious-disc"}]],
      236=>[[106,20,:level,{:relative_stats=>1}],[107,20,:level,{:relative_stats=>-1}],[237,20,:level,{:relative_stats=>0}]],
      238=>[[124,30,:level,{}]],
      239=>[[125,30,:level,{}]],
      240=>[[126,30,:level,{}]],
      246=>[[247,30,:level,{}]],
      247=>[[248,55,:level,{}]],
      252=>[[253,16,:level,{}]],
      253=>[[254,36,:level,{}]],
      255=>[[256,16,:level,{}]],
      256=>[[257,36,:level,{}]],
      258=>[[259,16,:level,{}]],
      259=>[[260,36,:level,{}]],
      261=>[[262,18,:level,{}]],
      263=>[[264,20,:level,{}]],
      265=>[[266,7,:level,{}],[268,7,:level,{}]],
      266=>[[267,10,:level,{}]],
      268=>[[269,10,:level,{}]],
      270=>[[271,14,:level,{}]],
      271=>[[272,36,:item,{:item=>"water-stone"}]],
      273=>[[274,14,:level,{}]],
      274=>[[275,36,:item,{:item=>"leaf-stone"}]],
      276=>[[277,22,:level,{}]],
      278=>[[279,25,:level,{}]],
      280=>[[281,20,:level,{}]],
      281=>[[282,36,:level,{}],[475,36,:item,{:item=>"dawn-stone",:gender_id=>2}]],
      283=>[[284,22,:level,{}]],
      285=>[[286,23,:level,{}]],
      287=>[[288,18,:level,{}]],
      288=>[[289,36,:level,{}]],
      290=>[[291,20,:level,{}]],
      293=>[[294,20,:level,{}]],
      294=>[[295,40,:level,{}]],
      296=>[[297,24,:level,{}]],
      298=>[[183,20,:level,{:happiness=>160}]],
      299=>[[476,30,:level,{:location_id=>10}]],
      300=>[[301,30,:item,{:item=>"moon-stone"}]],
      304=>[[305,32,:level,{}]],
      305=>[[306,42,:level,{}]],
      307=>[[308,37,:level,{}]],
      309=>[[310,26,:level,{}]],
      315=>[[407,36,:item,{:item=>"shiny-stone"}]],
      316=>[[317,26,:level,{}]],
      318=>[[319,30,:level,{}]],
      320=>[[321,40,:level,{}]],
      322=>[[323,33,:level,{}]],
      325=>[[326,32,:level,{}]],
      328=>[[329,35,:level,{}]],
      329=>[[330,45,:level,{}]],
      331=>[[332,32,:level,{}]],
      333=>[[334,35,:level,{}]],
      339=>[[340,30,:level,{}]],
      341=>[[342,30,:level,{}]],
      343=>[[344,36,:level,{}]],
      345=>[[346,40,:level,{}]],
      347=>[[348,40,:level,{}]],
      349=>[[350,20,:level,{:beauty=>170}]],
      353=>[[354,37,:level,{}]],
      355=>[[356,37,:level,{}]],
      356=>[[477,36,:trade,{:held_item=>"reaper-cloth"}]],
      360=>[[202,15,:level,{}]],
      361=>[[362,42,:level,{}],[478,42,:item,{:item=>"dawn-stone",:gender_id=>1}]],
      363=>[[364,32,:level,{}]],
      364=>[[365,44,:level,{}]],
      366=>[[367,30,:trade,{:held_item=>"deep-sea-tooth"}],[368,30,:trade,{:held_item=>"deep-sea-scale"}]],
      371=>[[372,30,:level,{}]],
      372=>[[373,50,:level,{}]],
      374=>[[375,20,:level,{}]],
      375=>[[376,45,:level,{}]],
      387=>[[388,18,:level,{}]],
      388=>[[389,32,:level,{}]],
      390=>[[391,14,:level,{}]],
      391=>[[392,36,:level,{}]],
      393=>[[394,16,:level,{}]],
      394=>[[395,36,:level,{}]],
      396=>[[397,14,:level,{}]],
      397=>[[398,34,:level,{}]],
      399=>[[400,15,:level,{}]],
      401=>[[402,10,:level,{}]],
      403=>[[404,15,:level,{}]],
      404=>[[405,30,:level,{}]],
      406=>[[315,20,:level,{:happiness=>160,:time=>"day"}]],
      408=>[[409,30,:level,{}]],
      410=>[[411,30,:level,{}]],
      412=>[[413,20,:level,{:gender_id=>1}],[414,20,:level,{:gender_id=>2}]],
      415=>[[416,21,:level,{:gender_id=>1}]],
      418=>[[419,26,:level,{}]],
      420=>[[421,25,:level,{}]],
      422=>[[423,30,:level,{}]],
      425=>[[426,28,:level,{}]],
      427=>[[428,20,:level,{:happiness=>160}]],
      431=>[[432,38,:level,{}]],
      433=>[[358,20,:level,{:happiness=>220,:time=>"night"}]],
      434=>[[435,34,:level,{}]],
      436=>[[437,33,:level,{}]],
      438=>[[185,30,:level,{:known_move_id=>102}]],
      439=>[[122,30,:level,{:known_move_id=>102}]],
      440=>[[113,30,:level,{:held_item=>"oval-stone",:time=>"day"}]],
      443=>[[444,24,:level,{}]],
      444=>[[445,48,:level,{}]],
      446=>[[143,20,:level,{:happiness=>160}]],
      447=>[[448,20,:level,{:happiness=>160,:time=>"day"}]],
      449=>[[450,34,:level,{}]],
      451=>[[452,40,:level,{}]],
      453=>[[454,37,:level,{}]],
      456=>[[457,31,:level,{}]],
      458=>[[226,30,:level,{}]],
      459=>[[460,40,:level,{}]],
    }
    BONUS_EVOLUTION = {
      290=>[[292,20,:shed,{}]],
    }
    LINEAGES = {
      1=>[1,2,3],
      4=>[4,5,6],
      7=>[7,8,9],
      10=>[10,11,12],
      13=>[13,14,15],
      16=>[16,17,18],
      19=>[19,20],
      21=>[21,22],
      23=>[23,24],
      27=>[27,28],
      29=>[29,30,31],
      32=>[32,33,34],
      37=>[37,38],
      41=>[41,42,169],
      43=>[43,44,45,182],
      46=>[46,47],
      48=>[48,49],
      50=>[50,51],
      52=>[52,53],
      54=>[54,55],
      56=>[56,57],
      58=>[58,59],
      60=>[60,61,62,186],
      63=>[63,64,65],
      66=>[66,67,68],
      69=>[69,70,71],
      72=>[72,73],
      74=>[74,75,76],
      77=>[77,78],
      79=>[79,80,199],
      81=>[81,82,462],
      83=>[83],
      84=>[84,85],
      86=>[86,87],
      88=>[88,89],
      90=>[90,91],
      92=>[92,93,94],
      95=>[95,208],
      96=>[96,97],
      98=>[98,99],
      100=>[100,101],
      102=>[102,103],
      104=>[104,105],
      108=>[108,463],
      109=>[109,110],
      111=>[111,112,464],
      114=>[114,465],
      115=>[115],
      116=>[116,117,230],
      118=>[118,119],
      120=>[120,121],
      123=>[123,212],
      127=>[127],
      128=>[128],
      129=>[129,130],
      131=>[131],
      132=>[132],
      133=>[133,134,135,136,196,197,470,471],
      137=>[137,233,474],
      138=>[138,139],
      140=>[140,141],
      142=>[142],
      144=>[144],
      145=>[145],
      146=>[146],
      147=>[147,148,149],
      150=>[150],
      151=>[151],
      152=>[152,153,154],
      155=>[155,156,157],
      158=>[158,159,160],
      161=>[161,162],
      163=>[163,164],
      165=>[165,166],
      167=>[167,168],
      170=>[170,171],
      172=>[172,25,26],
      173=>[173,35,36],
      174=>[174,39,40],
      175=>[175,176,468],
      177=>[177,178],
      179=>[179,180,181],
      187=>[187,188,189],
      190=>[190,424],
      191=>[191,192],
      193=>[193,469],
      194=>[194,195],
      198=>[198,430],
      200=>[200,429],
      201=>[201],
      203=>[203],
      204=>[204,205],
      206=>[206],
      207=>[207,472],
      209=>[209,210],
      211=>[211],
      213=>[213],
      214=>[214],
      215=>[215,461],
      216=>[216,217],
      218=>[218,219],
      220=>[220,221,473],
      222=>[222],
      223=>[223,224],
      225=>[225],
      227=>[227],
      228=>[228,229],
      231=>[231,232],
      234=>[234],
      235=>[235],
      236=>[236,106,107,237],
      238=>[238,124],
      239=>[239,125,466],
      240=>[240,126,467],
      241=>[241],
      243=>[243],
      244=>[244],
      245=>[245],
      246=>[246,247,248],
      249=>[249],
      250=>[250],
      251=>[251],
      252=>[252,253,254],
      255=>[255,256,257],
      258=>[258,259,260],
      261=>[261,262],
      263=>[263,264],
      265=>[265,266,267,268,269],
      270=>[270,271,272],
      273=>[273,274,275],
      276=>[276,277],
      278=>[278,279],
      280=>[280,281,282,475],
      283=>[283,284],
      285=>[285,286],
      287=>[287,288,289],
      290=>[290,291,292],
      293=>[293,294,295],
      296=>[296,297],
      298=>[298,183,184],
      299=>[299,476],
      300=>[300,301],
      302=>[302],
      303=>[303],
      304=>[304,305,306],
      307=>[307,308],
      309=>[309,310],
      311=>[311],
      312=>[312],
      313=>[313],
      314=>[314],
      316=>[316,317],
      318=>[318,319],
      320=>[320,321],
      322=>[322,323],
      324=>[324],
      325=>[325,326],
      327=>[327],
      328=>[328,329,330],
      331=>[331,332],
      333=>[333,334],
      335=>[335],
      336=>[336],
      337=>[337],
      338=>[338],
      339=>[339,340],
      341=>[341,342],
      343=>[343,344],
      345=>[345,346],
      347=>[347,348],
      349=>[349,350],
      351=>[351],
      352=>[352],
      353=>[353,354],
      355=>[355,356,477],
      357=>[357],
      359=>[359],
      360=>[360,202],
      361=>[361,362,478],
      363=>[363,364,365],
      366=>[366,367,368],
      369=>[369],
      370=>[370],
      371=>[371,372,373],
      374=>[374,375,376],
      377=>[377],
      378=>[378],
      379=>[379],
      380=>[380],
      381=>[381],
      382=>[382],
      383=>[383],
      384=>[384],
      385=>[385],
      386=>[386],
      387=>[387,388,389],
      390=>[390,391,392],
      393=>[393,394,395],
      396=>[396,397,398],
      399=>[399,400],
      401=>[401,402],
      403=>[403,404,405],
      406=>[406,315,407],
      408=>[408,409],
      410=>[410,411],
      412=>[412,413,414],
      415=>[415,416],
      417=>[417],
      418=>[418,419],
      420=>[420,421],
      422=>[422,423],
      425=>[425,426],
      427=>[427,428],
      431=>[431,432],
      433=>[433,358],
      434=>[434,435],
      436=>[436,437],
      438=>[438,185],
      439=>[439,122],
      440=>[440,113,242],
      441=>[441],
      442=>[442],
      443=>[443,444,445],
      446=>[446,143],
      447=>[447,448],
      449=>[449,450],
      451=>[451,452],
      453=>[453,454],
      455=>[455],
      456=>[456,457],
      458=>[458,226],
      459=>[459,460],
      479=>[479],
      480=>[480],
      481=>[481],
      482=>[482],
      483=>[483],
      484=>[484],
      485=>[485],
      486=>[486],
      487=>[487],
      488=>[488],
      489=>[489],
      490=>[490],
      491=>[491],
      492=>[492],
      493=>[493],
      494=>[494],
    }
    # move_id => [identifier,name,type,power,pp,accuracy,priority,class,target,effect,effect_chance,meta_cat,ailment,min_hits,max_hits,min_turns,max_turns,drain,healing,crit_rate,ailment_chance,flinch_chance,stat_chance]
    MOVE_CATALOG = {
      1=>["pound","拍擊",:normal,40,35,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      2=>["karate-chop","空手劈",:fighting,50,25,100,0,:physical,10,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      3=>["double-slap","連環巴掌",:normal,15,10,85,0,:physical,10,30,0,0,0,2,5,0,0,0,0,0,0,0,0],
      4=>["comet-punch","連續拳",:normal,18,15,85,0,:physical,10,30,0,0,0,2,5,0,0,0,0,0,0,0,0],
      5=>["mega-punch","百萬噸重拳",:normal,80,20,85,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      6=>["pay-day","聚寶功",:normal,40,20,100,0,:physical,10,35,0,0,0,0,0,0,0,0,0,0,0,0,0],
      7=>["fire-punch","火焰拳",:fire,75,15,100,0,:physical,10,5,10,4,4,0,0,0,0,0,0,0,10,0,0],
      8=>["ice-punch","冰凍拳",:ice,75,15,100,0,:physical,10,6,10,4,3,0,0,0,0,0,0,0,10,0,0],
      9=>["thunder-punch","雷電拳",:electric,75,15,100,0,:physical,10,7,10,4,1,0,0,0,0,0,0,0,10,0,0],
      10=>["scratch","抓",:normal,40,35,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      11=>["vice-grip","夾住",:normal,55,30,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      12=>["guillotine","斷頭鉗",:normal,0,5,30,0,:physical,10,39,0,9,0,0,0,0,0,0,0,0,0,0,0],
      13=>["razor-wind","旋風刀",:normal,80,10,100,0,:special,11,40,0,0,0,0,0,0,0,0,0,1,0,0,0],
      14=>["swords-dance","劍舞",:normal,0,20,0,0,:status,7,51,0,2,0,0,0,0,0,0,0,0,0,0,0],
      15=>["cut","居合斬",:normal,50,30,95,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      16=>["gust","起風",:flying,40,35,100,0,:special,10,150,0,0,0,0,0,0,0,0,0,0,0,0,0],
      17=>["wing-attack","翅膀攻擊",:flying,60,35,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      18=>["whirlwind","吹飛",:normal,0,20,0,-6,:status,10,29,0,12,0,0,0,0,0,0,0,0,0,0,0],
      19=>["fly","飛翔",:flying,90,15,95,0,:physical,10,156,0,0,0,0,0,0,0,0,0,0,0,0,0],
      20=>["bind","綁緊",:normal,15,20,85,0,:physical,10,43,100,4,8,0,0,5,6,0,0,0,100,0,0],
      21=>["slam","摔打",:normal,80,20,75,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      22=>["vine-whip","藤鞭",:grass,45,25,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      23=>["stomp","踩踏",:normal,65,20,100,0,:physical,10,151,30,0,0,0,0,0,0,0,0,0,0,30,0],
      24=>["double-kick","二連踢",:fighting,30,30,100,0,:physical,10,45,0,0,0,2,2,0,0,0,0,0,0,0,0],
      25=>["mega-kick","百萬噸重踢",:normal,120,5,75,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      26=>["jump-kick","飛踢",:fighting,100,10,95,0,:physical,10,46,0,0,0,0,0,0,0,0,0,0,0,0,0],
      27=>["rolling-kick","迴旋踢",:fighting,60,15,85,0,:physical,10,32,30,0,0,0,0,0,0,0,0,0,0,30,0],
      28=>["sand-attack","潑沙",:ground,0,15,100,0,:status,10,24,0,2,0,0,0,0,0,0,0,0,0,0,0],
      29=>["headbutt","頭錘",:normal,70,15,100,0,:physical,10,32,30,0,0,0,0,0,0,0,0,0,0,30,0],
      30=>["horn-attack","角撞",:normal,65,25,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      31=>["fury-attack","亂擊",:normal,15,20,85,0,:physical,10,30,0,0,0,2,5,0,0,0,0,0,0,0,0],
      32=>["horn-drill","角鑽",:normal,0,5,30,0,:physical,10,39,0,9,0,0,0,0,0,0,0,0,0,0,0],
      33=>["tackle","撞擊",:normal,40,35,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      34=>["body-slam","泰山壓頂",:normal,85,15,100,0,:physical,10,7,30,4,1,0,0,0,0,0,0,0,30,0,0],
      35=>["wrap","緊束",:normal,15,20,90,0,:physical,10,43,100,4,8,0,0,2,4,0,0,0,100,0,0],
      36=>["take-down","猛撞",:normal,90,20,85,0,:physical,10,49,0,0,0,0,0,0,0,-25,0,0,0,0,0],
      37=>["thrash","大鬧一番",:normal,120,10,100,0,:physical,8,28,0,0,0,0,0,0,0,0,0,0,0,0,0],
      38=>["double-edge","捨身衝撞",:normal,120,15,100,0,:physical,10,199,0,0,0,0,0,0,0,-33,0,0,0,0,0],
      39=>["tail-whip","搖尾巴",:normal,0,30,100,0,:status,11,20,0,2,0,0,0,0,0,0,0,0,0,0,0],
      40=>["poison-sting","毒針",:poison,15,35,100,0,:physical,10,3,30,4,5,0,0,0,0,0,0,0,30,0,0],
      41=>["twineedle","雙針",:bug,25,20,100,0,:physical,10,78,20,4,5,2,2,0,0,0,0,0,20,0,0],
      42=>["pin-missile","飛彈針",:bug,25,20,95,0,:physical,10,30,0,0,0,2,5,0,0,0,0,0,0,0,0],
      43=>["leer","瞪眼",:normal,0,30,100,0,:status,11,20,100,2,0,0,0,0,0,0,0,0,0,0,100],
      44=>["bite","咬住",:dark,60,25,100,0,:physical,10,32,30,0,0,0,0,0,0,0,0,0,0,30,0],
      45=>["growl","叫聲",:normal,0,40,100,0,:status,11,19,0,2,0,0,0,0,0,0,0,0,0,0,0],
      46=>["roar","吼叫",:normal,0,20,0,-6,:status,10,29,0,12,0,0,0,0,0,0,0,0,0,0,0],
      47=>["sing","唱歌",:normal,0,15,55,0,:status,10,2,0,1,2,0,0,2,4,0,0,0,0,0,0],
      48=>["supersonic","超音波",:normal,0,20,55,0,:status,10,50,0,1,6,0,0,2,5,0,0,0,0,0,0],
      49=>["sonic-boom","音爆",:normal,0,20,90,0,:special,10,131,0,0,0,0,0,0,0,0,0,0,0,0,0],
      50=>["disable","定身法",:normal,0,20,100,0,:status,10,87,0,13,13,0,0,4,4,0,0,0,0,0,0],
      51=>["acid","溶解液",:poison,40,30,100,0,:special,11,73,10,6,0,0,0,0,0,0,0,0,0,0,10],
      52=>["ember","火花",:fire,40,25,100,0,:special,10,5,10,4,4,0,0,0,0,0,0,0,10,0,0],
      53=>["flamethrower","噴射火焰",:fire,90,15,100,0,:special,10,5,10,4,4,0,0,0,0,0,0,0,10,0,0],
      54=>["mist","白霧",:ice,0,30,0,0,:status,4,47,0,11,0,0,0,0,0,0,0,0,0,0,0],
      55=>["water-gun","水槍",:water,40,25,100,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      56=>["hydro-pump","水炮",:water,110,5,80,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      57=>["surf","衝浪",:water,90,15,100,0,:special,9,258,0,0,0,0,0,0,0,0,0,0,0,0,0],
      58=>["ice-beam","冰凍光束",:ice,90,10,100,0,:special,10,6,10,4,3,0,0,0,0,0,0,0,10,0,0],
      59=>["blizzard","暴風雪",:ice,110,5,70,0,:special,11,261,10,4,3,0,0,0,0,0,0,0,10,0,0],
      60=>["psybeam","幻象光線",:psychic,65,20,100,0,:special,10,77,10,4,6,0,0,2,5,0,0,0,10,0,0],
      61=>["bubble-beam","泡沫光線",:water,65,20,100,0,:special,10,71,10,6,0,0,0,0,0,0,0,0,0,0,10],
      62=>["aurora-beam","極光束",:ice,65,20,100,0,:special,10,69,10,6,0,0,0,0,0,0,0,0,0,0,10],
      63=>["hyper-beam","破壞光線",:normal,150,5,90,0,:special,10,81,0,0,0,0,0,0,0,0,0,0,0,0,0],
      64=>["peck","啄",:flying,35,35,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      65=>["drill-peck","啄鑽",:flying,80,20,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      66=>["submission","地獄翻滾",:fighting,80,20,80,0,:physical,10,49,0,0,0,0,0,0,0,-25,0,0,0,0,0],
      67=>["low-kick","踢倒",:fighting,0,20,100,0,:physical,10,197,0,0,0,0,0,0,0,0,0,0,0,0,0],
      68=>["counter","雙倍奉還",:fighting,0,20,100,-5,:physical,1,90,0,0,0,0,0,0,0,0,0,0,0,0,0],
      69=>["seismic-toss","地球上投",:fighting,0,20,100,0,:physical,10,88,0,0,0,0,0,0,0,0,0,0,0,0,0],
      70=>["strength","怪力",:normal,80,15,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      71=>["absorb","吸取",:grass,20,25,100,0,:special,10,4,0,8,0,0,0,0,0,50,0,0,0,0,0],
      72=>["mega-drain","超級吸取",:grass,40,15,100,0,:special,10,4,0,8,0,0,0,0,0,50,0,0,0,0,0],
      73=>["leech-seed","寄生種子",:grass,0,10,90,0,:status,10,85,0,1,18,0,0,0,0,0,0,0,0,0,0],
      74=>["growth","生長",:normal,0,20,0,0,:status,7,317,0,2,0,0,0,0,0,0,0,0,0,0,0],
      75=>["razor-leaf","飛葉快刀",:grass,55,25,95,0,:physical,11,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      76=>["solar-beam","日光束",:grass,120,10,100,0,:special,10,152,0,0,0,0,0,0,0,0,0,0,0,0,0],
      77=>["poison-powder","毒粉",:poison,0,35,75,0,:status,10,67,0,1,5,0,0,0,0,0,0,0,0,0,0],
      78=>["stun-spore","麻痺粉",:grass,0,30,75,0,:status,10,68,0,1,1,0,0,0,0,0,0,0,0,0,0],
      79=>["sleep-powder","催眠粉",:grass,0,15,75,0,:status,10,2,0,1,2,0,0,2,4,0,0,0,0,0,0],
      80=>["petal-dance","花瓣舞",:grass,120,10,100,0,:special,8,28,0,0,0,0,0,0,0,0,0,0,0,0,0],
      81=>["string-shot","吐絲",:bug,0,40,95,0,:status,11,61,0,2,0,0,0,0,0,0,0,0,0,0,0],
      82=>["dragon-rage","龍之怒",:dragon,0,10,100,0,:special,10,42,0,0,0,0,0,0,0,0,0,0,0,0,0],
      83=>["fire-spin","火焰旋渦",:fire,35,15,85,0,:special,10,43,100,4,8,0,0,5,6,0,0,0,100,0,0],
      84=>["thunder-shock","電擊",:electric,40,30,100,0,:special,10,7,10,4,1,0,0,0,0,0,0,0,10,0,0],
      85=>["thunderbolt","十萬伏特",:electric,90,15,100,0,:special,10,7,10,4,1,0,0,0,0,0,0,0,10,0,0],
      86=>["thunder-wave","電磁波",:electric,0,20,90,0,:status,10,68,0,1,1,0,0,0,0,0,0,0,0,0,0],
      87=>["thunder","打雷",:electric,110,10,70,0,:special,10,153,30,4,1,0,0,0,0,0,0,0,30,0,0],
      88=>["rock-throw","落石",:rock,50,15,90,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      89=>["earthquake","地震",:ground,100,10,100,0,:physical,9,148,0,0,0,0,0,0,0,0,0,0,0,0,0],
      90=>["fissure","地裂",:ground,0,5,30,0,:physical,10,39,0,9,0,0,0,0,0,0,0,0,0,0,0],
      91=>["dig","挖洞",:ground,80,10,100,0,:physical,10,257,0,0,0,0,0,0,0,0,0,0,0,0,0],
      92=>["toxic","劇毒",:poison,0,10,90,0,:status,10,34,0,1,5,0,0,15,15,0,0,0,0,0,0],
      93=>["confusion","念力",:psychic,50,25,100,0,:special,10,77,10,4,6,0,0,2,5,0,0,0,10,0,0],
      94=>["psychic","精神強念",:psychic,90,10,100,0,:special,10,73,10,6,0,0,0,0,0,0,0,0,0,0,10],
      95=>["hypnosis","催眠術",:psychic,0,20,60,0,:status,10,2,0,1,2,0,0,2,4,0,0,0,0,0,0],
      96=>["meditate","瑜伽姿勢",:psychic,0,40,0,0,:status,7,11,0,2,0,0,0,0,0,0,0,0,0,0,0],
      97=>["agility","高速移動",:psychic,0,30,0,0,:status,7,53,0,2,0,0,0,0,0,0,0,0,0,0,0],
      98=>["quick-attack","電光一閃",:normal,40,30,100,1,:physical,10,104,0,0,0,0,0,0,0,0,0,0,0,0,0],
      99=>["rage","憤怒",:normal,20,20,100,0,:physical,10,82,0,0,0,0,0,0,0,0,0,0,0,0,0],
      100=>["teleport","瞬間移動",:psychic,0,20,0,-6,:status,7,154,0,13,0,0,0,0,0,0,0,0,0,0,0],
      101=>["night-shade","黑夜魔影",:ghost,0,15,100,0,:special,10,88,0,0,0,0,0,0,0,0,0,0,0,0,0],
      102=>["mimic","模仿",:normal,0,10,0,0,:status,10,83,0,13,0,0,0,0,0,0,0,0,0,0,0],
      103=>["screech","刺耳聲",:normal,0,40,85,0,:status,10,60,0,2,0,0,0,0,0,0,0,0,0,0,0],
      104=>["double-team","影子分身",:normal,0,15,0,0,:status,7,17,0,2,0,0,0,0,0,0,0,0,0,0,0],
      105=>["recover","自我再生",:normal,0,5,0,0,:status,7,33,0,3,0,0,0,0,0,0,50,0,0,0,0],
      106=>["harden","變硬",:normal,0,30,0,0,:status,7,12,0,2,0,0,0,0,0,0,0,0,0,0,0],
      107=>["minimize","變小",:normal,0,10,0,0,:status,7,109,0,2,0,0,0,0,0,0,0,0,0,0,0],
      108=>["smokescreen","煙幕",:normal,0,20,100,0,:status,10,24,0,2,0,0,0,0,0,0,0,0,0,0,0],
      109=>["confuse-ray","奇異之光",:ghost,0,10,100,0,:status,10,50,0,1,6,0,0,2,5,0,0,0,0,0,0],
      110=>["withdraw","縮入殼中",:water,0,40,0,0,:status,7,12,0,2,0,0,0,0,0,0,0,0,0,0,0],
      111=>["defense-curl","變圓",:normal,0,40,0,0,:status,7,157,0,2,0,0,0,0,0,0,0,0,0,0,0],
      112=>["barrier","屏障",:psychic,0,20,0,0,:status,7,52,0,2,0,0,0,0,0,0,0,0,0,0,0],
      113=>["light-screen","光牆",:psychic,0,30,0,0,:status,4,36,0,11,0,0,0,0,0,0,0,0,0,0,0],
      114=>["haze","黑霧",:ice,0,30,0,0,:status,12,26,0,10,0,0,0,0,0,0,0,0,0,0,0],
      115=>["reflect","反射壁",:psychic,0,20,0,0,:status,4,66,0,11,0,0,0,0,0,0,0,0,0,0,0],
      116=>["focus-energy","聚氣",:normal,0,30,0,0,:status,7,48,0,13,0,0,0,0,0,0,0,0,0,0,0],
      117=>["bide","忍耐",:normal,0,10,0,1,:physical,7,27,0,0,0,0,0,0,0,0,0,0,0,0,0],
      118=>["metronome","揮指",:normal,0,10,0,0,:status,7,84,0,13,0,0,0,0,0,0,0,0,0,0,0],
      119=>["mirror-move","鸚鵡學舌",:flying,0,20,0,0,:status,10,10,0,13,0,0,0,0,0,0,0,0,0,0,0],
      120=>["self-destruct","自爆",:normal,200,5,100,0,:physical,9,8,0,0,0,0,0,0,0,0,0,0,0,0,0],
      121=>["egg-bomb","炸蛋",:normal,100,10,75,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      122=>["lick","舌舔",:ghost,30,30,100,0,:physical,10,7,30,4,1,0,0,0,0,0,0,0,30,0,0],
      123=>["smog","濁霧",:poison,30,20,70,0,:special,10,3,40,4,5,0,0,0,0,0,0,0,40,0,0],
      124=>["sludge","污泥攻擊",:poison,65,20,100,0,:special,10,3,30,4,5,0,0,0,0,0,0,0,30,0,0],
      125=>["bone-club","骨棒",:ground,65,20,85,0,:physical,10,32,10,0,0,0,0,0,0,0,0,0,0,10,0],
      126=>["fire-blast","大字爆炎",:fire,110,5,85,0,:special,10,5,10,4,4,0,0,0,0,0,0,0,10,0,0],
      127=>["waterfall","攀瀑",:water,80,15,100,0,:physical,10,32,20,0,0,0,0,0,0,0,0,0,0,20,0],
      128=>["clamp","貝殼夾擊",:water,35,15,85,0,:physical,10,43,100,4,8,0,0,5,6,0,0,0,100,0,0],
      129=>["swift","高速星星",:normal,60,20,0,0,:special,11,18,0,0,0,0,0,0,0,0,0,0,0,0,0],
      130=>["skull-bash","火箭頭錘",:normal,130,10,100,0,:physical,10,146,100,0,0,0,0,0,0,0,0,0,100,0,0],
      131=>["spike-cannon","尖刺加農炮",:normal,20,15,100,0,:physical,10,30,0,0,0,2,5,0,0,0,0,0,0,0,0],
      132=>["constrict","纏繞",:normal,10,35,100,0,:physical,10,71,10,6,0,0,0,0,0,0,0,0,0,0,10],
      133=>["amnesia","瞬間失憶",:psychic,0,20,0,0,:status,7,55,0,2,0,0,0,0,0,0,0,0,0,0,0],
      134=>["kinesis","折彎湯匙",:psychic,0,15,80,0,:status,10,24,0,2,0,0,0,0,0,0,0,0,0,0,0],
      135=>["soft-boiled","生蛋",:normal,0,5,0,0,:status,7,33,0,3,0,0,0,0,0,0,50,0,0,0,0],
      136=>["high-jump-kick","飛膝踢",:fighting,130,10,90,0,:physical,10,46,0,0,0,0,0,0,0,0,0,0,0,0,0],
      137=>["glare","大蛇瞪眼",:normal,0,30,100,0,:status,10,68,0,1,1,0,0,0,0,0,0,0,0,0,0],
      138=>["dream-eater","食夢",:psychic,100,15,100,0,:special,10,9,0,8,0,0,0,0,0,50,0,0,0,0,0],
      139=>["poison-gas","毒瓦斯",:poison,0,40,90,0,:status,11,67,0,1,5,0,0,0,0,0,0,0,0,0,0],
      140=>["barrage","投球",:normal,15,20,85,0,:physical,10,30,0,0,0,2,5,0,0,0,0,0,0,0,0],
      141=>["leech-life","吸血",:bug,80,10,100,0,:physical,10,4,0,8,0,0,0,0,0,50,0,0,0,0,0],
      142=>["lovely-kiss","惡魔之吻",:normal,0,10,75,0,:status,10,2,0,1,2,0,0,2,4,0,0,0,0,0,0],
      143=>["sky-attack","神鳥猛擊",:flying,140,5,90,0,:physical,10,76,30,0,0,0,0,0,0,0,0,1,0,30,0],
      144=>["transform","變身",:normal,0,10,0,0,:status,10,58,0,13,0,0,0,0,0,0,0,0,0,0,0],
      145=>["bubble","泡沫",:water,40,30,100,0,:special,11,71,10,6,0,0,0,0,0,0,0,0,0,0,10],
      146=>["dizzy-punch","迷昏拳",:normal,70,10,100,0,:physical,10,77,20,4,6,0,0,2,5,0,0,0,20,0,0],
      147=>["spore","蘑菇孢子",:grass,0,15,100,0,:status,10,2,0,1,2,0,0,2,4,0,0,0,0,0,0],
      148=>["flash","閃光",:normal,0,20,100,0,:status,10,24,0,2,0,0,0,0,0,0,0,0,0,0,0],
      149=>["psywave","精神波",:psychic,0,15,100,0,:special,10,89,0,0,0,0,0,0,0,0,0,0,0,0,0],
      150=>["splash","躍起",:normal,0,40,0,0,:status,7,86,0,13,0,0,0,0,0,0,0,0,0,0,0],
      151=>["acid-armor","溶化",:poison,0,20,0,0,:status,7,52,0,2,0,0,0,0,0,0,0,0,0,0,0],
      152=>["crabhammer","蟹鉗錘",:water,100,10,90,0,:physical,10,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      153=>["explosion","大爆炸",:normal,250,5,100,0,:physical,9,8,0,0,0,0,0,0,0,0,0,0,0,0,0],
      154=>["fury-swipes","亂抓",:normal,18,15,80,0,:physical,10,30,0,0,0,2,5,0,0,0,0,0,0,0,0],
      155=>["bonemerang","骨頭回力鏢",:ground,50,10,90,0,:physical,10,45,0,0,0,2,2,0,0,0,0,0,0,0,0],
      156=>["rest","睡覺",:psychic,0,5,0,0,:status,7,38,0,13,0,0,0,0,0,0,0,0,0,0,0],
      157=>["rock-slide","岩崩",:rock,75,10,90,0,:physical,11,32,30,0,0,0,0,0,0,0,0,0,0,30,0],
      158=>["hyper-fang","必殺門牙",:normal,80,15,90,0,:physical,10,32,10,0,0,0,0,0,0,0,0,0,0,10,0],
      159=>["sharpen","稜角化",:normal,0,30,0,0,:status,7,11,0,2,0,0,0,0,0,0,0,0,0,0,0],
      160=>["conversion","紋理",:normal,0,30,0,0,:status,7,31,0,13,0,0,0,0,0,0,0,0,0,0,0],
      161=>["tri-attack","三重攻擊",:normal,80,10,100,0,:special,10,37,20,4,-1,0,0,0,0,0,0,0,20,0,0],
      162=>["super-fang","憤怒門牙",:normal,0,10,90,0,:physical,10,41,0,0,0,0,0,0,0,0,0,0,0,0,0],
      163=>["slash","劈開",:normal,70,20,100,0,:physical,10,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      164=>["substitute","替身",:normal,0,10,0,0,:status,7,80,0,13,0,0,0,0,0,0,0,0,0,0,0],
      165=>["struggle","掙扎",:normal,50,1,0,0,:physical,8,255,0,0,0,0,0,0,0,0,-25,0,0,0,0],
      166=>["sketch","寫生",:normal,0,1,0,0,:status,10,96,0,13,0,0,0,0,0,0,0,0,0,0,0],
      167=>["triple-kick","三連踢",:fighting,10,10,90,0,:physical,10,105,0,0,0,3,3,0,0,0,0,0,0,0,0],
      168=>["thief","小偷",:dark,60,25,100,0,:physical,10,106,0,0,0,0,0,0,0,0,0,0,0,0,0],
      169=>["spider-web","蛛網",:bug,0,10,0,0,:status,10,107,0,13,0,0,0,0,0,0,0,0,0,0,0],
      170=>["mind-reader","心之眼",:normal,0,5,0,0,:status,10,95,0,13,0,0,0,0,0,0,0,0,0,0,0],
      171=>["nightmare","惡夢",:ghost,0,15,100,0,:status,10,108,0,1,9,0,0,0,0,0,0,0,0,0,0],
      172=>["flame-wheel","火焰輪",:fire,60,25,100,0,:physical,10,126,10,4,4,0,0,0,0,0,0,0,10,0,0],
      173=>["snore","打鼾",:normal,50,15,100,0,:special,10,93,30,0,0,0,0,0,0,0,0,0,0,30,0],
      174=>["curse","詛咒",:ghost,0,10,0,0,:status,1,110,0,13,0,0,0,0,0,0,0,0,0,0,0],
      175=>["flail","抓狂",:normal,0,15,100,0,:physical,10,100,0,0,0,0,0,0,0,0,0,0,0,0,0],
      176=>["conversion-2","紋理２",:normal,0,30,0,0,:status,10,94,0,13,0,0,0,0,0,0,0,0,0,0,0],
      177=>["aeroblast","氣旋攻擊",:flying,100,5,95,0,:special,10,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      178=>["cotton-spore","棉孢子",:grass,0,40,100,0,:status,11,61,0,2,0,0,0,0,0,0,0,0,0,0,0],
      179=>["reversal","起死回生",:fighting,0,15,100,0,:physical,10,100,0,0,0,0,0,0,0,0,0,0,0,0,0],
      180=>["spite","怨恨",:ghost,0,10,100,0,:status,10,101,0,13,0,0,0,0,0,0,0,0,0,0,0],
      181=>["powder-snow","細雪",:ice,40,25,100,0,:special,11,6,10,4,3,0,0,0,0,0,0,0,10,0,0],
      182=>["protect","守住",:normal,0,10,0,4,:status,7,112,0,13,0,0,0,0,0,0,0,0,0,0,0],
      183=>["mach-punch","音速拳",:fighting,40,30,100,1,:physical,10,104,0,0,0,0,0,0,0,0,0,0,0,0,0],
      184=>["scary-face","鬼面",:normal,0,10,100,0,:status,10,61,0,2,0,0,0,0,0,0,0,0,0,0,0],
      185=>["feint-attack","出奇一擊",:dark,60,20,0,0,:physical,10,18,0,0,0,0,0,0,0,0,0,0,0,0,0],
      186=>["sweet-kiss","天使之吻",:fairy,0,10,75,0,:status,10,50,0,1,6,0,0,2,5,0,0,0,0,0,0],
      187=>["belly-drum","腹鼓",:normal,0,10,0,0,:status,7,143,0,13,0,0,0,0,0,0,0,0,0,0,0],
      188=>["sludge-bomb","污泥炸彈",:poison,90,10,100,0,:special,10,3,30,4,5,0,0,0,0,0,0,0,30,0,0],
      189=>["mud-slap","擲泥",:ground,20,10,100,0,:special,10,74,100,6,0,0,0,0,0,0,0,0,0,0,100],
      190=>["octazooka","章魚桶炮",:water,65,10,85,0,:special,10,74,50,6,0,0,0,0,0,0,0,0,0,0,50],
      191=>["spikes","撒菱",:ground,0,20,0,0,:status,6,113,0,11,0,0,0,0,0,0,0,0,0,0,0],
      192=>["zap-cannon","電磁炮",:electric,120,5,50,0,:special,10,7,100,4,1,0,0,0,0,0,0,0,100,0,0],
      193=>["foresight","識破",:normal,0,40,0,0,:status,10,114,0,1,17,0,0,0,0,0,0,0,0,0,0],
      194=>["destiny-bond","同命",:ghost,0,5,0,0,:status,7,99,0,13,0,0,0,0,0,0,0,0,0,0,0],
      195=>["perish-song","滅亡之歌",:normal,0,5,0,0,:status,14,115,0,1,20,0,0,4,4,0,0,0,0,0,0],
      196=>["icy-wind","冰凍之風",:ice,55,15,95,0,:special,11,71,100,6,0,0,0,0,0,0,0,0,0,0,100],
      197=>["detect","看穿",:fighting,0,5,0,4,:status,7,112,0,13,0,0,0,0,0,0,0,0,0,0,0],
      198=>["bone-rush","骨棒亂打",:ground,25,10,90,0,:physical,10,30,0,0,0,2,5,0,0,0,0,0,0,0,0],
      199=>["lock-on","鎖定",:normal,0,5,0,0,:status,10,95,0,13,0,0,0,0,0,0,0,0,0,0,0],
      200=>["outrage","逆鱗",:dragon,120,10,100,0,:physical,8,28,0,0,0,0,0,0,0,0,0,0,0,0,0],
      201=>["sandstorm","沙暴",:rock,0,10,0,0,:status,12,116,0,10,0,0,0,0,0,0,0,0,0,0,0],
      202=>["giga-drain","終極吸取",:grass,75,10,100,0,:special,10,4,0,8,0,0,0,0,0,50,0,0,0,0,0],
      203=>["endure","挺住",:normal,0,10,0,4,:status,7,117,0,13,0,0,0,0,0,0,0,0,0,0,0],
      204=>["charm","撒嬌",:fairy,0,20,100,0,:status,10,59,0,2,0,0,0,0,0,0,0,0,0,0,0],
      205=>["rollout","滾動",:rock,30,20,90,0,:physical,10,118,0,0,0,0,0,0,0,0,0,0,0,0,0],
      206=>["false-swipe","點到為止",:normal,40,40,100,0,:physical,10,102,0,0,0,0,0,0,0,0,0,0,0,0,0],
      207=>["swagger","虛張聲勢",:normal,0,15,85,0,:status,10,119,0,5,6,0,0,2,5,0,0,0,0,0,0],
      208=>["milk-drink","喝牛奶",:normal,0,5,0,0,:status,7,33,0,3,0,0,0,0,0,0,50,0,0,0,0],
      209=>["spark","電光",:electric,65,20,100,0,:physical,10,7,30,4,1,0,0,0,0,0,0,0,30,0,0],
      210=>["fury-cutter","連斬",:bug,40,20,95,0,:physical,10,120,0,0,0,0,0,0,0,0,0,0,0,0,0],
      211=>["steel-wing","鋼翼",:steel,70,25,90,0,:physical,10,139,10,7,0,0,0,0,0,0,0,0,0,0,10],
      212=>["mean-look","黑色目光",:normal,0,5,0,0,:status,10,107,0,13,0,0,0,0,0,0,0,0,0,0,0],
      213=>["attract","迷人",:normal,0,15,100,0,:status,10,121,0,1,7,0,0,0,0,0,0,0,0,0,0],
      214=>["sleep-talk","夢話",:normal,0,10,0,0,:status,7,98,0,13,0,0,0,0,0,0,0,0,0,0,0],
      215=>["heal-bell","治癒鈴聲",:normal,0,5,0,0,:status,13,103,0,13,0,0,0,0,0,0,0,0,0,0,0],
      216=>["return","報恩",:normal,0,20,100,0,:physical,10,122,0,0,0,0,0,0,0,0,0,0,0,0,0],
      217=>["present","禮物",:normal,0,15,90,0,:physical,10,123,0,0,0,0,0,0,0,0,0,0,0,0,0],
      218=>["frustration","遷怒",:normal,0,20,100,0,:physical,10,124,0,0,0,0,0,0,0,0,0,0,0,0,0],
      219=>["safeguard","神秘守護",:normal,0,25,0,0,:status,4,125,0,11,0,0,0,0,0,0,0,0,0,0,0],
      220=>["pain-split","分擔痛楚",:normal,0,20,0,0,:status,10,92,0,13,0,0,0,0,0,0,0,0,0,0,0],
      221=>["sacred-fire","神聖之火",:fire,100,5,95,0,:physical,10,126,50,4,4,0,0,0,0,0,0,0,50,0,0],
      222=>["magnitude","震級",:ground,0,30,100,0,:physical,9,127,0,0,0,0,0,0,0,0,0,0,0,0,0],
      223=>["dynamic-punch","爆裂拳",:fighting,100,5,50,0,:physical,10,77,100,4,6,0,0,2,5,0,0,0,100,0,0],
      224=>["megahorn","超級角擊",:bug,120,10,85,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      225=>["dragon-breath","龍息",:dragon,60,20,100,0,:special,10,7,30,4,1,0,0,0,0,0,0,0,30,0,0],
      226=>["baton-pass","接棒",:normal,0,40,0,0,:status,7,128,0,13,0,0,0,0,0,0,0,0,0,0,0],
      227=>["encore","再來一次",:normal,0,5,100,0,:status,10,91,0,13,0,0,0,0,0,0,0,0,0,0,0],
      228=>["pursuit","追打",:dark,40,20,100,0,:physical,10,129,0,0,0,0,0,0,0,0,0,0,0,0,0],
      229=>["rapid-spin","高速旋轉",:normal,50,40,100,0,:physical,10,130,100,7,0,0,0,0,0,0,0,0,0,0,100],
      230=>["sweet-scent","甜甜香氣",:normal,0,20,100,0,:status,11,25,0,2,0,0,0,0,0,0,0,0,0,0,0],
      231=>["iron-tail","鐵尾",:steel,100,15,75,0,:physical,10,70,30,6,0,0,0,0,0,0,0,0,0,0,30],
      232=>["metal-claw","金屬爪",:steel,50,35,95,0,:physical,10,140,10,7,0,0,0,0,0,0,0,0,0,0,10],
      233=>["vital-throw","借力摔",:fighting,70,10,0,-1,:physical,10,79,0,0,0,0,0,0,0,0,0,0,0,0,0],
      234=>["morning-sun","晨光",:normal,0,5,0,0,:status,7,133,0,3,0,0,0,0,0,0,50,0,0,0,0],
      235=>["synthesis","光合作用",:grass,0,5,0,0,:status,7,133,0,3,0,0,0,0,0,0,50,0,0,0,0],
      236=>["moonlight","月光",:fairy,0,5,0,0,:status,7,133,0,3,0,0,0,0,0,0,50,0,0,0,0],
      237=>["hidden-power","覺醒力量",:normal,60,15,100,0,:special,10,136,0,0,0,0,0,0,0,0,0,0,0,0,0],
      238=>["cross-chop","十字劈",:fighting,100,5,80,0,:physical,10,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      239=>["twister","龍捲風",:dragon,40,20,100,0,:special,11,147,20,0,0,0,0,0,0,0,0,0,0,20,0],
      240=>["rain-dance","求雨",:water,0,5,0,0,:status,12,137,0,10,0,0,0,0,0,0,0,0,0,0,0],
      241=>["sunny-day","大晴天",:fire,0,5,0,0,:status,12,138,0,10,0,0,0,0,0,0,0,0,0,0,0],
      242=>["crunch","咬碎",:dark,80,15,100,0,:physical,10,70,20,6,0,0,0,0,0,0,0,0,0,0,20],
      243=>["mirror-coat","鏡面反射",:psychic,0,20,100,-5,:special,1,145,0,0,0,0,0,0,0,0,0,0,0,0,0],
      244=>["psych-up","自我暗示",:normal,0,10,0,0,:status,10,144,0,13,0,0,0,0,0,0,0,0,0,0,0],
      245=>["extreme-speed","神速",:normal,80,5,100,2,:physical,10,104,0,0,0,0,0,0,0,0,0,0,0,0,0],
      246=>["ancient-power","原始之力",:rock,60,5,100,0,:special,10,141,10,7,0,0,0,0,0,0,0,0,0,0,10],
      247=>["shadow-ball","暗影球",:ghost,80,15,100,0,:special,10,73,20,6,0,0,0,0,0,0,0,0,0,0,20],
      248=>["future-sight","預知未來",:psychic,120,10,100,0,:special,10,149,0,13,0,0,0,0,0,0,0,0,0,0,0],
      249=>["rock-smash","碎岩",:fighting,40,15,100,0,:physical,10,70,50,6,0,0,0,0,0,0,0,0,0,0,50],
      250=>["whirlpool","潮旋",:water,35,15,85,0,:special,10,262,100,4,8,0,0,5,6,0,0,0,100,0,0],
      251=>["beat-up","圍攻",:dark,0,10,100,0,:physical,10,155,0,0,0,6,6,0,0,0,0,0,0,0,0],
      252=>["fake-out","擊掌奇襲",:normal,40,10,100,3,:physical,10,159,100,0,0,0,0,0,0,0,0,0,0,100,0],
      253=>["uproar","吵鬧",:normal,90,10,100,0,:special,8,160,0,0,0,0,0,3,3,0,0,0,0,0,0],
      254=>["stockpile","蓄力",:normal,0,20,0,0,:status,7,161,0,13,0,0,0,0,0,0,0,0,0,0,0],
      255=>["spit-up","噴出",:normal,0,10,100,0,:special,10,162,0,0,0,0,0,0,0,0,0,0,0,0,0],
      256=>["swallow","吞下",:normal,0,10,0,0,:status,7,163,0,3,0,0,0,0,0,0,25,0,0,0,0],
      257=>["heat-wave","熱風",:fire,95,10,90,0,:special,11,5,10,4,4,0,0,0,0,0,0,0,10,0,0],
      258=>["hail","冰雹",:ice,0,10,0,0,:status,12,165,0,10,0,0,0,0,0,0,0,0,0,0,0],
      259=>["torment","無理取鬧",:dark,0,15,100,0,:status,10,166,0,1,12,0,0,0,0,0,0,0,0,0,0],
      260=>["flatter","吹捧",:dark,0,15,100,0,:status,10,167,0,5,6,0,0,2,5,0,0,0,0,0,0],
      261=>["will-o-wisp","鬼火",:fire,0,15,85,0,:status,10,168,0,1,4,0,0,0,0,0,0,0,0,0,0],
      262=>["memento","臨別禮物",:dark,0,10,100,0,:status,10,169,0,13,0,0,0,0,0,0,0,0,0,0,0],
      263=>["facade","硬撐",:normal,70,20,100,0,:physical,10,170,0,0,0,0,0,0,0,0,0,0,0,0,0],
      264=>["focus-punch","真氣拳",:fighting,150,20,100,-3,:physical,10,171,0,0,0,0,0,0,0,0,0,0,0,0,0],
      265=>["smelling-salts","清醒",:normal,70,10,100,0,:physical,10,172,0,0,0,0,0,0,0,0,0,0,0,0,0],
      266=>["follow-me","看我嘛",:normal,0,20,0,2,:status,7,173,0,13,0,0,0,0,0,0,0,0,0,0,0],
      267=>["nature-power","自然之力",:normal,0,20,0,0,:status,10,174,0,13,0,0,0,0,0,0,0,0,0,0,0],
      268=>["charge","充電",:electric,0,20,0,0,:status,7,175,0,2,0,0,0,0,0,0,0,0,0,0,0],
      269=>["taunt","挑釁",:dark,0,20,100,0,:status,10,176,0,13,0,0,0,0,0,0,0,0,0,0,0],
      270=>["helping-hand","幫助",:normal,0,20,0,5,:status,3,177,0,13,0,0,0,0,0,0,0,0,0,0,0],
      271=>["trick","戲法",:psychic,0,10,100,0,:status,10,178,0,13,0,0,0,0,0,0,0,0,0,0,0],
      272=>["role-play","扮演",:psychic,0,10,0,0,:status,10,179,0,13,0,0,0,0,0,0,0,0,0,0,0],
      273=>["wish","祈願",:normal,0,10,0,0,:status,7,180,0,13,0,0,0,0,0,0,0,0,0,0,0],
      274=>["assist","借助",:normal,0,20,0,0,:status,7,181,0,13,0,0,0,0,0,0,0,0,0,0,0],
      275=>["ingrain","扎根",:grass,0,20,0,0,:status,7,182,0,1,21,0,0,0,0,0,0,0,0,0,0],
      276=>["superpower","蠻力",:fighting,120,5,100,0,:physical,10,183,100,7,0,0,0,0,0,0,0,0,0,0,100],
      277=>["magic-coat","魔法反射",:psychic,0,15,0,4,:status,7,184,0,13,0,0,0,0,0,0,0,0,0,0,0],
      278=>["recycle","回收利用",:normal,0,10,0,0,:status,7,185,0,13,0,0,0,0,0,0,0,0,0,0,0],
      279=>["revenge","報復",:fighting,60,10,100,-4,:physical,10,186,0,0,0,0,0,0,0,0,0,0,0,0,0],
      280=>["brick-break","劈瓦",:fighting,75,15,100,0,:physical,10,187,0,0,0,0,0,0,0,0,0,0,0,0,0],
      281=>["yawn","哈欠",:normal,0,10,0,0,:status,10,188,0,1,14,0,0,2,2,0,0,0,0,0,0],
      282=>["knock-off","拍落",:dark,65,20,100,0,:physical,10,189,0,0,0,0,0,0,0,0,0,0,0,0,0],
      283=>["endeavor","蠻幹",:normal,0,5,100,0,:physical,10,190,0,0,0,0,0,0,0,0,0,0,0,0,0],
      284=>["eruption","噴火",:fire,150,5,100,0,:special,11,191,0,0,0,0,0,0,0,0,0,0,0,0,0],
      285=>["skill-swap","特性互換",:psychic,0,10,0,0,:status,10,192,0,13,0,0,0,0,0,0,0,0,0,0,0],
      286=>["imprison","封印",:psychic,0,10,0,0,:status,7,193,0,13,0,0,0,0,0,0,0,0,0,0,0],
      287=>["refresh","煥然一新",:normal,0,20,0,0,:status,7,194,0,13,0,0,0,0,0,0,0,0,0,0,0],
      288=>["grudge","怨念",:ghost,0,5,0,0,:status,7,195,0,13,0,0,0,0,0,0,0,0,0,0,0],
      289=>["snatch","搶奪",:dark,0,10,0,4,:status,7,196,0,13,0,0,0,0,0,0,0,0,0,0,0],
      290=>["secret-power","秘密之力",:normal,70,20,100,0,:physical,10,198,30,0,0,0,0,0,0,0,0,0,30,0,0],
      291=>["dive","潛水",:water,80,10,100,0,:physical,10,256,0,0,0,0,0,0,0,0,0,0,0,0,0],
      292=>["arm-thrust","猛推",:fighting,15,20,100,0,:physical,10,30,0,0,0,2,5,0,0,0,0,0,0,0,0],
      293=>["camouflage","保護色",:normal,0,20,0,0,:status,7,214,0,13,0,0,0,0,0,0,0,0,0,0,0],
      294=>["tail-glow","螢火",:bug,0,20,0,0,:status,7,322,0,2,0,0,0,0,0,0,0,0,0,0,0],
      295=>["luster-purge","潔淨光芒",:psychic,95,5,100,0,:special,10,73,50,6,0,0,0,0,0,0,0,0,0,0,50],
      296=>["mist-ball","薄霧球",:psychic,95,5,100,0,:special,10,72,50,6,0,0,0,0,0,0,0,0,0,0,50],
      297=>["feather-dance","羽毛舞",:flying,0,15,100,0,:status,10,59,0,2,0,0,0,0,0,0,0,0,0,0,0],
      298=>["teeter-dance","搖晃舞",:normal,0,20,100,0,:status,9,200,0,1,6,0,0,2,5,0,0,0,0,0,0],
      299=>["blaze-kick","火焰踢",:fire,85,10,90,0,:physical,10,201,10,4,4,0,0,0,0,0,0,1,10,0,0],
      300=>["mud-sport","玩泥巴",:ground,0,15,0,0,:status,12,202,0,10,0,0,0,0,0,0,0,0,0,0,0],
      301=>["ice-ball","冰球",:ice,30,20,90,0,:physical,10,118,0,0,0,0,0,0,0,0,0,0,0,0,0],
      302=>["needle-arm","尖刺臂",:grass,60,15,100,0,:physical,10,32,30,0,0,0,0,0,0,0,0,0,0,30,0],
      303=>["slack-off","偷懶",:normal,0,5,0,0,:status,7,33,0,3,0,0,0,0,0,0,50,0,0,0,0],
      304=>["hyper-voice","巨聲",:normal,90,10,100,0,:special,11,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      305=>["poison-fang","劇毒牙",:poison,50,15,100,0,:physical,10,203,50,4,5,0,0,0,0,0,0,0,50,0,0],
      306=>["crush-claw","撕裂爪",:normal,75,10,95,0,:physical,10,70,50,6,0,0,0,0,0,0,0,0,0,0,50],
      307=>["blast-burn","爆炸烈焰",:fire,150,5,90,0,:special,10,81,0,0,0,0,0,0,0,0,0,0,0,0,0],
      308=>["hydro-cannon","加農水炮",:water,150,5,90,0,:special,10,81,0,0,0,0,0,0,0,0,0,0,0,0,0],
      309=>["meteor-mash","彗星拳",:steel,90,10,90,0,:physical,10,140,20,7,0,0,0,0,0,0,0,0,0,0,20],
      310=>["astonish","驚嚇",:ghost,30,15,100,0,:physical,10,32,30,0,0,0,0,0,0,0,0,0,0,30,0],
      311=>["weather-ball","氣象球",:normal,50,10,100,0,:special,10,204,0,0,0,0,0,0,0,0,0,0,0,0,0],
      312=>["aromatherapy","芳香治療",:grass,0,5,0,0,:status,13,103,0,13,0,0,0,0,0,0,0,0,0,0,0],
      313=>["fake-tears","假哭",:dark,0,20,100,0,:status,10,63,0,2,0,0,0,0,0,0,0,0,0,0,0],
      314=>["air-cutter","空氣利刃",:flying,60,25,95,0,:special,11,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      315=>["overheat","過熱",:fire,130,5,90,0,:special,10,205,100,7,0,0,0,0,0,0,0,0,0,0,100],
      316=>["odor-sleuth","氣味偵測",:normal,0,40,0,0,:status,10,114,0,1,17,0,0,0,0,0,0,0,0,0,0],
      317=>["rock-tomb","岩石封鎖",:rock,60,15,95,0,:physical,10,71,100,6,0,0,0,0,0,0,0,0,0,0,100],
      318=>["silver-wind","銀色旋風",:bug,60,5,100,0,:special,10,141,10,7,0,0,0,0,0,0,0,0,0,0,10],
      319=>["metal-sound","金屬音",:steel,0,40,85,0,:status,10,63,0,2,0,0,0,0,0,0,0,0,0,0,0],
      320=>["grass-whistle","草笛",:grass,0,15,55,0,:status,10,2,0,1,2,0,0,2,4,0,0,0,0,0,0],
      321=>["tickle","搔癢",:normal,0,20,100,0,:status,10,206,0,2,0,0,0,0,0,0,0,0,0,0,0],
      322=>["cosmic-power","宇宙力量",:psychic,0,20,0,0,:status,7,207,0,2,0,0,0,0,0,0,0,0,0,0,0],
      323=>["water-spout","噴水",:water,150,5,100,0,:special,11,191,0,0,0,0,0,0,0,0,0,0,0,0,0],
      324=>["signal-beam","信號光束",:bug,75,15,100,0,:special,10,77,10,4,6,0,0,2,5,0,0,0,10,0,0],
      325=>["shadow-punch","暗影拳",:ghost,60,20,0,0,:physical,10,18,0,0,0,0,0,0,0,0,0,0,0,0,0],
      326=>["extrasensory","神通力",:psychic,80,20,100,0,:special,10,32,10,0,0,0,0,0,0,0,0,0,0,10,0],
      327=>["sky-uppercut","衝天拳",:fighting,85,15,90,0,:physical,10,208,0,0,0,0,0,0,0,0,0,0,0,0,0],
      328=>["sand-tomb","流沙地獄",:ground,35,15,85,0,:physical,10,43,100,4,8,0,0,5,6,0,0,0,100,0,0],
      329=>["sheer-cold","絕對零度",:ice,0,5,30,0,:special,10,39,0,9,0,0,0,0,0,0,0,0,0,0,0],
      330=>["muddy-water","濁流",:water,90,10,85,0,:special,11,74,30,6,0,0,0,0,0,0,0,0,0,0,30],
      331=>["bullet-seed","種子機關槍",:grass,25,30,100,0,:physical,10,30,0,0,0,2,5,0,0,0,0,0,0,0,0],
      332=>["aerial-ace","燕返",:flying,60,20,0,0,:physical,10,18,0,0,0,0,0,0,0,0,0,0,0,0,0],
      333=>["icicle-spear","冰錐",:ice,25,30,100,0,:physical,10,30,0,0,0,2,5,0,0,0,0,0,0,0,0],
      334=>["iron-defense","鐵壁",:steel,0,15,0,0,:status,7,52,0,2,0,0,0,0,0,0,0,0,0,0,0],
      335=>["block","擋路",:normal,0,5,0,0,:status,10,107,0,13,0,0,0,0,0,0,0,0,0,0,0],
      336=>["howl","長嚎",:normal,0,40,0,0,:status,13,11,0,2,0,0,0,0,0,0,0,0,0,0,0],
      337=>["dragon-claw","龍爪",:dragon,80,15,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      338=>["frenzy-plant","瘋狂植物",:grass,150,5,90,0,:special,10,81,0,0,0,0,0,0,0,0,0,0,0,0,0],
      339=>["bulk-up","健美",:fighting,0,20,0,0,:status,7,209,0,2,0,0,0,0,0,0,0,0,0,0,0],
      340=>["bounce","彈跳",:flying,85,5,85,0,:physical,10,264,30,4,1,0,0,0,0,0,0,0,30,0,0],
      341=>["mud-shot","泥巴射擊",:ground,55,15,95,0,:special,10,71,100,6,0,0,0,0,0,0,0,0,0,0,100],
      342=>["poison-tail","毒尾",:poison,50,25,100,0,:physical,10,210,10,4,5,0,0,0,0,0,0,1,10,0,0],
      343=>["covet","渴望",:normal,60,25,100,0,:physical,10,106,0,0,0,0,0,0,0,0,0,0,0,0,0],
      344=>["volt-tackle","伏特攻擊",:electric,120,15,100,0,:physical,10,263,10,4,1,0,0,0,0,-33,0,0,10,0,0],
      345=>["magical-leaf","魔法葉",:grass,60,20,0,0,:special,10,18,0,0,0,0,0,0,0,0,0,0,0,0,0],
      346=>["water-sport","玩水",:water,0,15,0,0,:status,12,211,0,10,0,0,0,0,0,0,0,0,0,0,0],
      347=>["calm-mind","冥想",:psychic,0,20,0,0,:status,7,212,0,2,0,0,0,0,0,0,0,0,0,0,0],
      348=>["leaf-blade","葉刃",:grass,90,15,100,0,:physical,10,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      349=>["dragon-dance","龍之舞",:dragon,0,20,0,0,:status,7,213,0,2,0,0,0,0,0,0,0,0,0,0,0],
      350=>["rock-blast","岩石爆擊",:rock,25,10,90,0,:physical,10,30,0,0,0,2,5,0,0,0,0,0,0,0,0],
      351=>["shock-wave","電擊波",:electric,60,20,0,0,:special,10,18,0,0,0,0,0,0,0,0,0,0,0,0,0],
      352=>["water-pulse","水之波動",:water,60,20,100,0,:special,10,77,20,4,6,0,0,2,5,0,0,0,20,0,0],
      353=>["doom-desire","破滅之願",:steel,140,5,100,0,:special,10,149,0,13,0,0,0,0,0,0,0,0,0,0,0],
      354=>["psycho-boost","精神突進",:psychic,140,5,90,0,:special,10,205,100,7,0,0,0,0,0,0,0,0,0,0,100],
      355=>["roost","羽棲",:flying,0,5,0,0,:status,7,215,0,3,0,0,0,0,0,0,50,0,0,0,0],
      356=>["gravity","重力",:psychic,0,5,0,0,:status,12,216,0,10,0,0,0,0,0,0,0,0,0,0,0],
      357=>["miracle-eye","奇跡之眼",:psychic,0,40,0,0,:status,10,217,0,1,17,0,0,0,0,0,0,0,0,0,0],
      358=>["wake-up-slap","喚醒巴掌",:fighting,70,10,100,0,:physical,10,218,0,0,0,0,0,0,0,0,0,0,0,0,0],
      359=>["hammer-arm","臂錘",:fighting,100,10,90,0,:physical,10,219,100,7,0,0,0,0,0,0,0,0,0,0,100],
      360=>["gyro-ball","陀螺球",:steel,0,5,100,0,:physical,10,220,0,0,0,0,0,0,0,0,0,0,0,0,0],
      361=>["healing-wish","治癒之願",:psychic,0,10,0,0,:status,7,221,0,13,0,0,0,0,0,0,0,0,0,0,0],
      362=>["brine","鹽水",:water,65,10,100,0,:special,10,222,0,0,0,0,0,0,0,0,0,0,0,0,0],
      363=>["natural-gift","自然之恩",:normal,0,15,100,0,:physical,10,223,0,0,0,0,0,0,0,0,0,0,0,0,0],
      364=>["feint","佯攻",:normal,30,10,100,2,:physical,10,224,0,0,0,0,0,0,0,0,0,0,0,0,0],
      365=>["pluck","啄食",:flying,60,20,100,0,:physical,10,225,0,0,0,0,0,0,0,0,0,0,0,0,0],
      366=>["tailwind","順風",:flying,0,15,0,0,:status,4,226,0,11,0,0,0,0,0,0,0,0,0,0,0],
      367=>["acupressure","點穴",:normal,0,30,0,0,:status,5,227,0,13,0,0,0,0,0,0,0,0,0,0,0],
      368=>["metal-burst","金屬爆炸",:steel,0,10,100,0,:physical,1,228,0,0,0,0,0,0,0,0,0,0,0,0,0],
      369=>["u-turn","急速折返",:bug,70,20,100,0,:physical,10,229,0,0,0,0,0,0,0,0,0,0,0,0,0],
      370=>["close-combat","近身戰",:fighting,120,5,100,0,:physical,10,230,100,7,0,0,0,0,0,0,0,0,0,0,100],
      371=>["payback","以牙還牙",:dark,50,10,100,0,:physical,10,231,0,0,0,0,0,0,0,0,0,0,0,0,0],
      372=>["assurance","惡意追擊",:dark,60,10,100,0,:physical,10,232,0,0,0,0,0,0,0,0,0,0,0,0,0],
      373=>["embargo","查封",:dark,0,15,100,0,:status,10,233,0,1,19,0,0,5,5,0,0,0,0,0,0],
      374=>["fling","投擲",:dark,0,10,100,0,:physical,10,234,0,0,0,0,0,0,0,0,0,0,0,0,0],
      375=>["psycho-shift","精神轉移",:psychic,0,10,100,0,:status,10,235,0,13,0,0,0,0,0,0,0,0,0,0,0],
      376=>["trump-card","王牌",:normal,0,5,0,0,:special,10,236,0,0,0,0,0,0,0,0,0,0,0,0,0],
      377=>["heal-block","回復封鎖",:psychic,0,15,100,0,:status,11,237,0,1,15,0,0,5,5,0,0,0,0,0,0],
      378=>["wring-out","絞緊",:normal,0,5,100,0,:special,10,238,0,0,0,0,0,0,0,0,0,0,0,0,0],
      379=>["power-trick","力量戲法",:psychic,0,10,0,0,:status,7,239,0,13,0,0,0,0,0,0,0,0,0,0,0],
      380=>["gastro-acid","胃液",:poison,0,10,100,0,:status,10,240,0,13,0,0,0,0,0,0,0,0,0,0,0],
      381=>["lucky-chant","幸運咒語",:normal,0,30,0,0,:status,4,241,0,11,0,0,0,0,0,0,0,0,0,0,0],
      382=>["me-first","搶先一步",:normal,0,20,0,0,:status,2,242,0,0,0,0,0,0,0,0,0,0,0,0,0],
      383=>["copycat","仿效",:normal,0,20,0,0,:status,7,243,0,13,0,0,0,0,0,0,0,0,0,0,0],
      384=>["power-swap","力量互換",:psychic,0,10,0,0,:status,10,244,0,13,0,0,0,0,0,0,0,0,0,0,0],
      385=>["guard-swap","防守互換",:psychic,0,10,0,0,:status,10,245,0,13,0,0,0,0,0,0,0,0,0,0,0],
      386=>["punishment","懲罰",:dark,0,5,100,0,:physical,10,246,0,0,0,0,0,0,0,0,0,0,0,0,0],
      387=>["last-resort","珍藏",:normal,140,5,100,0,:physical,10,247,0,0,0,0,0,0,0,0,0,0,0,0,0],
      388=>["worry-seed","煩惱種子",:grass,0,10,100,0,:status,10,248,0,13,0,0,0,0,0,0,0,0,0,0,0],
      389=>["sucker-punch","突襲",:dark,70,5,100,1,:physical,10,249,0,0,0,0,0,0,0,0,0,0,0,0,0],
      390=>["toxic-spikes","毒菱",:poison,0,20,0,0,:status,6,250,0,11,0,0,0,0,0,0,0,0,0,0,0],
      391=>["heart-swap","心靈互換",:psychic,0,10,0,0,:status,10,251,0,13,0,0,0,0,0,0,0,0,0,0,0],
      392=>["aqua-ring","水流環",:water,0,20,0,0,:status,7,252,0,13,0,0,0,0,0,0,0,0,0,0,0],
      393=>["magnet-rise","電磁飄浮",:electric,0,10,0,0,:status,7,253,0,13,0,0,0,0,0,0,0,0,0,0,0],
      394=>["flare-blitz","閃焰衝鋒",:fire,120,15,100,0,:physical,10,254,10,4,4,0,0,0,0,-33,0,0,10,0,0],
      395=>["force-palm","發勁",:fighting,60,10,100,0,:physical,10,7,30,4,1,0,0,0,0,0,0,0,30,0,0],
      396=>["aura-sphere","波導彈",:fighting,80,20,0,0,:special,10,18,0,0,0,0,0,0,0,0,0,0,0,0,0],
      397=>["rock-polish","岩石打磨",:rock,0,20,0,0,:status,7,53,0,2,0,0,0,0,0,0,0,0,0,0,0],
      398=>["poison-jab","毒擊",:poison,80,20,100,0,:physical,10,3,30,4,5,0,0,0,0,0,0,0,30,0,0],
      399=>["dark-pulse","惡之波動",:dark,80,15,100,0,:special,10,32,20,0,0,0,0,0,0,0,0,0,0,20,0],
      400=>["night-slash","暗襲要害",:dark,70,15,100,0,:physical,10,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      401=>["aqua-tail","水流尾",:water,90,10,90,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      402=>["seed-bomb","種子炸彈",:grass,80,15,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      403=>["air-slash","空氣斬",:flying,75,15,95,0,:special,10,32,30,0,0,0,0,0,0,0,0,0,0,30,0],
      404=>["x-scissor","十字剪",:bug,80,15,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      405=>["bug-buzz","蟲鳴",:bug,90,10,100,0,:special,10,73,10,6,0,0,0,0,0,0,0,0,0,0,10],
      406=>["dragon-pulse","龍之波動",:dragon,85,10,100,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      407=>["dragon-rush","龍之俯衝",:dragon,100,10,75,0,:physical,10,32,20,0,0,0,0,0,0,0,0,0,0,20,0],
      408=>["power-gem","力量寶石",:rock,80,20,100,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      409=>["drain-punch","吸取拳",:fighting,75,10,100,0,:physical,10,4,0,8,0,0,0,0,0,50,0,0,0,0,0],
      410=>["vacuum-wave","真空波",:fighting,40,30,100,1,:special,10,104,0,0,0,0,0,0,0,0,0,0,0,0,0],
      411=>["focus-blast","真氣彈",:fighting,120,5,70,0,:special,10,73,10,6,0,0,0,0,0,0,0,0,0,0,10],
      412=>["energy-ball","能量球",:grass,90,10,100,0,:special,10,73,10,6,0,0,0,0,0,0,0,0,0,0,10],
      413=>["brave-bird","勇鳥猛攻",:flying,120,15,100,0,:physical,10,199,0,0,0,0,0,0,0,-33,0,0,0,0,0],
      414=>["earth-power","大地之力",:ground,90,10,100,0,:special,10,73,10,6,0,0,0,0,0,0,0,0,0,0,10],
      415=>["switcheroo","掉包",:dark,0,10,100,0,:status,10,178,0,13,0,0,0,0,0,0,0,0,0,0,0],
      416=>["giga-impact","終極衝擊",:normal,150,5,90,0,:physical,10,81,0,0,0,0,0,0,0,0,0,0,0,0,0],
      417=>["nasty-plot","詭計",:dark,0,20,0,0,:status,7,54,0,2,0,0,0,0,0,0,0,0,0,0,0],
      418=>["bullet-punch","子彈拳",:steel,40,30,100,1,:physical,10,104,0,0,0,0,0,0,0,0,0,0,0,0,0],
      419=>["avalanche","雪崩",:ice,60,10,100,-4,:physical,10,186,0,0,0,0,0,0,0,0,0,0,0,0,0],
      420=>["ice-shard","冰礫",:ice,40,30,100,1,:physical,10,104,0,0,0,0,0,0,0,0,0,0,0,0,0],
      421=>["shadow-claw","暗影爪",:ghost,70,15,100,0,:physical,10,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      422=>["thunder-fang","雷電牙",:electric,65,15,95,0,:physical,10,276,10,4,1,0,0,0,0,0,0,0,10,10,0],
      423=>["ice-fang","冰凍牙",:ice,65,15,95,0,:physical,10,275,10,4,3,0,0,0,0,0,0,0,10,10,0],
      424=>["fire-fang","火焰牙",:fire,65,15,95,0,:physical,10,274,10,4,4,0,0,0,0,0,0,0,10,10,0],
      425=>["shadow-sneak","影子偷襲",:ghost,40,30,100,1,:physical,10,104,0,0,0,0,0,0,0,0,0,0,0,0,0],
      426=>["mud-bomb","泥巴炸彈",:ground,65,10,85,0,:special,10,74,30,6,0,0,0,0,0,0,0,0,0,0,30],
      427=>["psycho-cut","精神利刃",:psychic,70,20,100,0,:physical,10,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      428=>["zen-headbutt","意念頭錘",:psychic,80,15,90,0,:physical,10,32,20,0,0,0,0,0,0,0,0,0,0,20,0],
      429=>["mirror-shot","鏡光射擊",:steel,65,10,85,0,:special,10,74,30,6,0,0,0,0,0,0,0,0,0,0,30],
      430=>["flash-cannon","加農光炮",:steel,80,10,100,0,:special,10,73,10,6,0,0,0,0,0,0,0,0,0,0,10],
      431=>["rock-climb","攀岩",:normal,90,20,85,0,:physical,10,77,20,4,6,0,0,2,5,0,0,0,20,0,0],
      432=>["defog","清除濃霧",:flying,0,15,0,0,:status,10,259,0,13,0,0,0,0,0,0,0,0,0,0,0],
      433=>["trick-room","戲法空間",:psychic,0,5,0,-7,:status,12,260,0,10,0,0,0,0,0,0,0,0,0,0,0],
      434=>["draco-meteor","流星群",:dragon,130,5,90,0,:special,10,205,100,7,0,0,0,0,0,0,0,0,0,0,100],
      435=>["discharge","放電",:electric,80,15,100,0,:special,9,7,30,4,1,0,0,0,0,0,0,0,30,0,0],
      436=>["lava-plume","噴煙",:fire,80,15,100,0,:special,9,5,30,4,4,0,0,0,0,0,0,0,30,0,0],
      437=>["leaf-storm","飛葉風暴",:grass,130,5,90,0,:special,10,205,100,7,0,0,0,0,0,0,0,0,0,0,100],
      438=>["power-whip","強力鞭打",:grass,120,10,85,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      439=>["rock-wrecker","岩石炮",:rock,150,5,90,0,:physical,10,81,0,0,0,0,0,0,0,0,0,0,0,0,0],
      440=>["cross-poison","十字毒刃",:poison,70,20,100,0,:physical,10,210,10,4,5,0,0,0,0,0,0,1,10,0,0],
      441=>["gunk-shot","垃圾射擊",:poison,120,5,80,0,:physical,10,3,30,4,5,0,0,0,0,0,0,0,30,0,0],
      442=>["iron-head","鐵頭",:steel,80,15,100,0,:physical,10,32,30,0,0,0,0,0,0,0,0,0,0,30,0],
      443=>["magnet-bomb","磁鐵炸彈",:steel,60,20,0,0,:physical,10,18,0,0,0,0,0,0,0,0,0,0,0,0,0],
      444=>["stone-edge","尖石攻擊",:rock,100,5,80,0,:physical,10,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      445=>["captivate","誘惑",:normal,0,20,100,0,:status,11,266,0,2,0,0,0,0,0,0,0,0,0,0,0],
      446=>["stealth-rock","隱形岩",:rock,0,20,0,0,:status,6,267,0,11,0,0,0,0,0,0,0,0,0,0,0],
      447=>["grass-knot","打草結",:grass,0,20,100,0,:special,10,197,0,0,0,0,0,0,0,0,0,0,0,0,0],
      448=>["chatter","喋喋不休",:flying,65,20,100,0,:special,10,268,100,4,6,0,0,2,5,0,0,0,100,0,0],
      449=>["judgment","制裁光礫",:normal,100,10,100,0,:special,10,269,0,0,0,0,0,0,0,0,0,0,0,0,0],
      450=>["bug-bite","蟲咬",:bug,60,20,100,0,:physical,10,225,0,0,0,0,0,0,0,0,0,0,0,0,0],
      451=>["charge-beam","充電光束",:electric,50,10,90,0,:special,10,277,70,7,0,0,0,0,0,0,0,0,0,0,70],
      452=>["wood-hammer","木槌",:grass,120,15,100,0,:physical,10,199,0,0,0,0,0,0,0,-33,0,0,0,0,0],
      453=>["aqua-jet","水流噴射",:water,40,20,100,1,:physical,10,104,0,0,0,0,0,0,0,0,0,0,0,0,0],
      454=>["attack-order","攻擊指令",:bug,90,15,100,0,:physical,10,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      455=>["defend-order","防禦指令",:bug,0,10,0,0,:status,7,207,0,2,0,0,0,0,0,0,0,0,0,0,0],
      456=>["heal-order","回復指令",:bug,0,10,0,0,:status,7,33,0,3,0,0,0,0,0,0,50,0,0,0,0],
      457=>["head-smash","雙刃頭錘",:rock,150,5,80,0,:physical,10,270,0,0,0,0,0,0,0,-50,0,0,0,0,0],
      458=>["double-hit","二連擊",:normal,35,10,90,0,:physical,10,45,0,0,0,2,2,0,0,0,0,0,0,0,0],
      459=>["roar-of-time","時光咆哮",:dragon,150,5,90,0,:special,10,81,0,0,0,0,0,0,0,0,0,0,0,0,0],
      460=>["spacial-rend","亞空裂斬",:dragon,100,5,95,0,:special,10,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      461=>["lunar-dance","新月舞",:psychic,0,10,0,0,:status,7,271,0,13,0,0,0,0,0,0,0,0,0,0,0],
      462=>["crush-grip","捏碎",:normal,0,5,100,0,:physical,10,238,0,0,0,0,0,0,0,0,0,0,0,0,0],
      463=>["magma-storm","熔岩風暴",:fire,100,5,75,0,:special,10,43,100,4,8,0,0,5,6,0,0,0,100,0,0],
      464=>["dark-void","暗黑洞",:dark,0,10,50,0,:status,11,2,0,1,2,0,0,2,4,0,0,0,0,0,0],
      465=>["seed-flare","種子閃光",:grass,120,5,85,0,:special,10,272,40,6,0,0,0,0,0,0,0,0,0,0,40],
      466=>["ominous-wind","奇異之風",:ghost,60,5,100,0,:special,10,141,10,7,0,0,0,0,0,0,0,0,10,0,10],
      467=>["shadow-force","暗影潛襲",:ghost,120,5,100,0,:physical,10,273,0,0,0,0,0,0,0,0,0,0,0,0,0],
      468=>["hone-claws","磨爪",:dark,0,15,0,0,:status,7,278,0,2,0,0,0,0,0,0,0,0,0,0,0],
      469=>["wide-guard","廣域防守",:rock,0,10,0,3,:status,4,279,0,11,0,0,0,0,0,0,0,0,0,0,0],
      470=>["guard-split","防守平分",:psychic,0,10,0,0,:status,10,280,0,13,0,0,0,0,0,0,0,0,0,0,0],
      471=>["power-split","力量平分",:psychic,0,10,0,0,:status,10,281,0,13,0,0,0,0,0,0,0,0,0,0,0],
      472=>["wonder-room","奇妙空間",:psychic,0,10,0,0,:status,12,282,0,10,0,0,0,0,0,0,0,0,0,0,0],
      473=>["psyshock","精神衝擊",:psychic,80,10,100,0,:special,10,283,0,0,0,0,0,0,0,0,0,0,0,0,0],
      474=>["venoshock","毒液衝擊",:poison,65,10,100,0,:special,10,284,0,0,0,0,0,0,0,0,0,0,0,0,0],
      475=>["autotomize","身體輕量化",:steel,0,15,0,0,:status,7,285,0,2,0,0,0,0,0,0,0,0,0,0,0],
      476=>["rage-powder","憤怒粉",:bug,0,20,0,2,:status,7,173,0,13,0,0,0,0,0,0,0,0,0,0,0],
      477=>["telekinesis","意念移物",:psychic,0,15,0,0,:status,10,286,0,1,-1,0,0,3,3,0,0,0,0,0,0],
      478=>["magic-room","魔法空間",:psychic,0,10,0,0,:status,12,287,0,10,0,0,0,0,0,0,0,0,0,0,0],
      479=>["smack-down","擊落",:rock,50,15,100,0,:physical,10,288,100,0,-1,0,0,0,0,0,0,0,100,0,0],
      480=>["storm-throw","山嵐摔",:fighting,60,10,100,0,:physical,10,289,0,0,0,0,0,0,0,0,0,6,0,0,0],
      481=>["flame-burst","烈焰濺射",:fire,70,15,100,0,:special,10,290,0,0,0,0,0,0,0,0,0,0,0,0,0],
      482=>["sludge-wave","污泥波",:poison,95,10,100,0,:special,9,3,10,4,5,0,0,0,0,0,0,0,10,0,0],
      483=>["quiver-dance","蝶舞",:bug,0,20,0,0,:status,7,291,0,2,0,0,0,0,0,0,0,0,0,0,0],
      484=>["heavy-slam","重磅衝撞",:steel,0,10,100,0,:physical,10,292,0,0,0,0,0,0,0,0,0,0,0,0,0],
      485=>["synchronoise","同步干擾",:psychic,120,10,100,0,:special,9,293,0,0,0,0,0,0,0,0,0,0,0,0,0],
      486=>["electro-ball","電球",:electric,0,10,100,0,:special,10,294,0,0,0,0,0,0,0,0,0,0,0,0,0],
      487=>["soak","浸水",:water,0,20,100,0,:status,10,295,0,13,0,0,0,0,0,0,0,0,0,0,0],
      488=>["flame-charge","蓄能焰襲",:fire,50,20,100,0,:physical,10,296,100,7,0,0,0,0,0,0,0,0,0,0,100],
      489=>["coil","盤蜷",:poison,0,20,0,0,:status,7,323,0,2,0,0,0,0,0,0,0,0,0,0,0],
      490=>["low-sweep","下盤踢",:fighting,65,20,100,0,:physical,10,21,100,6,0,0,0,0,0,0,0,0,0,0,100],
      491=>["acid-spray","酸液炸彈",:poison,40,20,100,0,:special,10,297,100,6,0,0,0,0,0,0,0,0,0,0,100],
      492=>["foul-play","欺詐",:dark,95,15,100,0,:physical,10,298,0,0,0,0,0,0,0,0,0,0,0,0,0],
      493=>["simple-beam","單純光束",:normal,0,15,100,0,:status,10,299,0,13,0,0,0,0,0,0,0,0,0,0,0],
      494=>["entrainment","找夥伴",:normal,0,15,100,0,:status,10,300,0,13,0,0,0,0,0,0,0,0,0,0,0],
      495=>["after-you","您先請",:normal,0,15,0,0,:status,10,301,0,13,0,0,0,0,0,0,0,0,0,0,0],
      496=>["round","輪唱",:normal,60,15,100,0,:special,10,302,0,0,0,0,0,0,0,0,0,0,0,0,0],
      497=>["echoed-voice","回聲",:normal,40,15,100,0,:special,10,303,0,0,0,0,0,0,0,0,0,0,0,0,0],
      498=>["chip-away","逐步擊破",:normal,70,20,100,0,:physical,10,304,0,0,0,0,0,0,0,0,0,0,0,0,0],
      499=>["clear-smog","清除之煙",:poison,50,15,0,0,:special,10,305,0,0,0,0,0,0,0,0,0,0,0,0,0],
      500=>["stored-power","輔助力量",:psychic,20,10,100,0,:special,10,306,0,0,0,0,0,0,0,0,0,0,0,0,0],
      501=>["quick-guard","快速防守",:fighting,0,15,0,3,:status,4,307,0,11,0,0,0,0,0,0,0,0,0,0,0],
      502=>["ally-switch","交換場地",:psychic,0,15,0,2,:status,7,308,0,13,0,0,0,0,0,0,0,0,0,0,0],
      503=>["scald","熱水",:water,80,15,100,0,:special,10,5,30,4,4,0,0,0,0,0,0,0,30,0,0],
      504=>["shell-smash","破殼",:normal,0,15,0,0,:status,7,309,0,13,0,0,0,0,0,0,0,0,0,0,0],
      505=>["heal-pulse","治癒波動",:psychic,0,10,0,0,:status,10,310,0,3,0,0,0,0,0,0,50,0,0,0,0],
      506=>["hex","禍不單行",:ghost,65,10,100,0,:special,10,311,0,0,0,0,0,0,0,0,0,0,0,0,0],
      507=>["sky-drop","自由落體",:flying,60,10,100,0,:physical,10,312,0,0,0,0,0,0,0,0,0,0,0,0,0],
      508=>["shift-gear","換檔",:steel,0,10,0,0,:status,7,313,0,2,0,0,0,0,0,0,0,0,0,0,0],
      509=>["circle-throw","巴投",:fighting,60,10,90,-6,:physical,10,314,0,0,0,0,0,0,0,0,0,0,0,0,0],
      510=>["incinerate","燒盡",:fire,60,15,100,0,:special,11,315,0,0,0,0,0,0,0,0,0,0,0,0,0],
      511=>["quash","延後",:dark,0,15,100,0,:status,10,316,0,13,0,0,0,0,0,0,0,0,0,0,0],
      512=>["acrobatics","雜技",:flying,55,15,100,0,:physical,10,318,0,0,0,0,0,0,0,0,0,0,0,0,0],
      513=>["reflect-type","鏡面屬性",:normal,0,15,0,0,:status,10,319,0,13,0,0,0,0,0,0,0,0,0,0,0],
      514=>["retaliate","報仇",:normal,70,5,100,0,:physical,10,320,0,0,0,0,0,0,0,0,0,0,0,0,0],
      515=>["final-gambit","搏命",:fighting,0,5,100,0,:special,10,321,0,0,0,0,0,0,0,0,0,0,0,0,0],
      516=>["bestow","傳遞禮物",:normal,0,15,0,0,:status,10,324,0,13,0,0,0,0,0,0,0,0,0,0,0],
      517=>["inferno","煉獄",:fire,100,5,50,0,:special,10,5,100,4,4,0,0,0,0,0,0,0,100,0,0],
      518=>["water-pledge","水之誓約",:water,80,10,100,0,:special,10,325,0,0,0,0,0,0,0,0,0,0,0,0,0],
      519=>["fire-pledge","火之誓約",:fire,80,10,100,0,:special,10,326,0,0,0,0,0,0,0,0,0,0,0,0,0],
      520=>["grass-pledge","草之誓約",:grass,80,10,100,0,:special,10,327,0,0,0,0,0,0,0,0,0,0,0,0,0],
      521=>["volt-switch","伏特替換",:electric,70,20,100,0,:special,10,229,0,0,0,0,0,0,0,0,0,0,0,0,0],
      522=>["struggle-bug","蟲之抵抗",:bug,50,20,100,0,:special,11,72,100,6,0,0,0,0,0,0,0,0,0,0,100],
      523=>["bulldoze","重踏",:ground,60,20,100,0,:physical,9,71,100,6,0,0,0,0,0,0,0,0,0,0,100],
      524=>["frost-breath","冰息",:ice,60,10,90,0,:special,10,289,100,0,0,0,0,0,0,0,0,6,100,0,0],
      525=>["dragon-tail","龍尾",:dragon,60,10,90,-6,:physical,10,314,0,0,0,0,0,0,0,0,0,0,0,0,0],
      526=>["work-up","自我激勵",:normal,0,30,0,0,:status,7,328,0,2,0,0,0,0,0,0,0,0,0,0,0],
      527=>["electroweb","電網",:electric,55,15,95,0,:special,11,21,100,6,0,0,0,0,0,0,0,0,0,0,100],
      528=>["wild-charge","瘋狂伏特",:electric,90,15,100,0,:physical,10,49,0,0,0,0,0,0,0,-25,0,0,0,0,0],
      529=>["drill-run","直衝鑽",:ground,80,10,95,0,:physical,10,44,0,0,0,0,0,0,0,0,0,1,0,0,0],
      530=>["dual-chop","二連劈",:dragon,40,15,90,0,:physical,10,45,0,0,0,2,2,0,0,0,0,0,0,0,0],
      531=>["heart-stamp","愛心印章",:psychic,60,25,100,0,:physical,10,32,30,0,0,0,0,0,0,0,0,0,0,30,0],
      532=>["horn-leech","木角",:grass,75,10,100,0,:physical,10,4,0,8,0,0,0,0,0,50,0,0,0,0,0],
      533=>["sacred-sword","聖劍",:fighting,90,15,100,0,:physical,10,304,0,0,0,0,0,0,0,0,0,0,0,0,0],
      534=>["razor-shell","貝殼刃",:water,75,10,95,0,:physical,10,70,50,6,0,0,0,0,0,0,0,0,0,0,50],
      535=>["heat-crash","高溫重壓",:fire,0,10,100,0,:physical,10,292,0,0,0,0,0,0,0,0,0,0,0,0,0],
      536=>["leaf-tornado","青草攪拌器",:grass,65,10,90,0,:special,10,74,50,6,0,0,0,0,0,0,0,0,0,0,50],
      537=>["steamroller","瘋狂滾壓",:bug,65,20,100,0,:physical,10,151,30,0,0,0,0,0,0,0,0,0,0,30,0],
      538=>["cotton-guard","棉花防守",:grass,0,10,0,0,:status,7,329,0,2,0,0,0,0,0,0,0,0,0,0,0],
      539=>["night-daze","暗黑爆破",:dark,85,10,95,0,:special,10,74,40,6,0,0,0,0,0,0,0,0,0,0,40],
      540=>["psystrike","精神擊破",:psychic,100,10,100,0,:special,10,283,0,0,0,0,0,0,0,0,0,0,0,0,0],
      541=>["tail-slap","掃尾拍打",:normal,25,10,85,0,:physical,10,30,0,0,0,2,5,0,0,0,0,0,0,0,0],
      542=>["hurricane","暴風",:flying,110,10,70,0,:special,10,334,30,4,6,0,0,2,5,0,0,0,30,0,0],
      543=>["head-charge","爆炸頭突擊",:normal,120,15,100,0,:physical,10,49,0,0,0,0,0,0,0,-25,0,0,0,0,0],
      544=>["gear-grind","齒輪飛盤",:steel,50,15,85,0,:physical,10,45,0,0,0,2,2,0,0,0,0,0,0,0,0],
      545=>["searing-shot","火焰彈",:fire,100,5,100,0,:special,9,5,30,4,4,0,0,0,0,0,0,0,30,0,0],
      546=>["techno-blast","高科技光炮",:normal,120,5,100,0,:special,10,269,0,0,0,0,0,0,0,0,0,0,0,0,0],
      547=>["relic-song","古老之歌",:normal,75,10,100,0,:special,11,330,10,4,2,0,0,2,4,0,0,0,10,0,0],
      548=>["secret-sword","神秘之劍",:fighting,85,10,100,0,:special,10,283,0,0,0,0,0,0,0,0,0,0,0,0,0],
      549=>["glaciate","冰封世界",:ice,65,10,95,0,:special,11,331,100,6,0,0,0,0,0,0,0,0,0,0,100],
      550=>["bolt-strike","雷擊",:electric,130,5,85,0,:physical,10,7,20,4,1,0,0,0,0,0,0,0,20,0,0],
      551=>["blue-flare","青焰",:fire,130,5,85,0,:special,10,5,20,4,4,0,0,0,0,0,0,0,20,0,0],
      552=>["fiery-dance","火之舞",:fire,80,10,100,0,:special,10,277,50,7,0,0,0,0,0,0,0,0,0,0,50],
      553=>["freeze-shock","冰凍伏特",:ice,140,5,90,0,:physical,10,332,30,4,1,0,0,0,0,0,0,0,30,0,0],
      554=>["ice-burn","極寒冷焰",:ice,140,5,90,0,:special,10,333,30,4,4,0,0,0,0,0,0,0,30,0,0],
      555=>["snarl","大聲咆哮",:dark,55,15,95,0,:special,11,72,100,6,0,0,0,0,0,0,0,0,0,0,100],
      556=>["icicle-crash","冰柱墜擊",:ice,85,10,90,0,:physical,10,32,30,0,0,0,0,0,0,0,0,0,0,30,0],
      557=>["v-create","Ｖ熱焰",:fire,180,5,95,0,:physical,10,335,100,7,0,0,0,0,0,0,0,0,0,0,100],
      558=>["fusion-flare","交錯火焰",:fire,100,5,100,0,:special,10,336,0,0,0,0,0,0,0,0,0,0,0,0,0],
      559=>["fusion-bolt","交錯閃電",:electric,100,5,100,0,:physical,10,337,0,0,0,0,0,0,0,0,0,0,0,0,0],
      560=>["flying-press","飛身重壓",:fighting,100,10,95,0,:physical,10,338,0,0,0,0,0,0,0,0,0,0,0,0,0],
      561=>["mat-block","掀榻榻米",:fighting,0,10,0,0,:status,4,377,0,11,0,0,0,0,0,0,0,0,0,0,0],
      562=>["belch","打嗝",:poison,120,10,90,0,:special,10,339,0,0,0,0,0,0,0,0,0,0,0,0,0],
      563=>["rototiller","耕地",:ground,0,10,0,0,:status,14,340,100,2,0,0,0,0,0,0,0,0,0,0,100],
      564=>["sticky-web","黏黏網",:bug,0,20,0,0,:status,6,341,0,11,0,0,0,0,0,0,0,0,0,0,0],
      565=>["fell-stinger","致命針刺",:bug,50,25,100,0,:physical,10,342,0,0,0,0,0,0,0,0,0,0,0,0,0],
      566=>["phantom-force","潛靈奇襲",:ghost,90,10,100,0,:physical,10,273,0,0,0,0,0,0,0,0,0,0,0,0,0],
      567=>["trick-or-treat","萬聖夜",:ghost,0,20,100,0,:status,10,343,0,13,0,0,0,0,0,0,0,0,0,0,0],
      568=>["noble-roar","戰吼",:normal,0,30,100,0,:status,10,344,100,2,0,0,0,0,0,0,0,0,0,0,100],
      569=>["ion-deluge","等離子浴",:electric,0,25,0,1,:status,12,345,0,10,0,0,0,0,0,0,0,0,0,0,0],
      570=>["parabolic-charge","拋物面充電",:electric,65,20,100,0,:special,9,346,0,8,0,0,0,0,0,50,0,0,0,0,0],
      571=>["forests-curse","森林詛咒",:grass,0,20,100,0,:status,10,376,0,13,0,0,0,0,0,0,0,0,0,0,0],
      572=>["petal-blizzard","落英繽紛",:grass,90,15,100,0,:physical,9,379,0,0,0,0,0,0,0,0,0,0,0,0,0],
      573=>["freeze-dry","冷凍乾燥",:ice,70,20,100,0,:special,10,380,10,4,3,0,0,0,0,0,0,0,10,0,0],
      574=>["disarming-voice","魅惑之聲",:fairy,40,15,0,0,:special,11,381,0,0,0,0,0,0,0,0,0,0,0,0,0],
      575=>["parting-shot","拋下狠話",:dark,0,20,100,0,:status,10,347,100,2,0,0,0,0,0,0,0,0,0,0,100],
      576=>["topsy-turvy","顛倒",:dark,0,20,0,0,:status,10,348,0,13,0,0,0,0,0,0,0,0,0,0,0],
      577=>["draining-kiss","吸取之吻",:fairy,50,10,100,0,:special,10,349,0,8,0,0,0,0,0,75,0,0,0,0,0],
      578=>["crafty-shield","戲法防守",:fairy,0,10,0,3,:status,4,350,0,11,0,0,0,0,0,0,0,0,0,0,0],
      579=>["flower-shield","鮮花防守",:fairy,0,10,0,0,:status,14,351,100,13,0,0,0,0,0,0,0,0,0,0,100],
      580=>["grassy-terrain","青草場地",:grass,0,10,0,0,:status,12,352,0,10,0,0,0,0,0,0,0,0,0,0,0],
      581=>["misty-terrain","薄霧場地",:fairy,0,10,0,0,:status,12,353,0,10,0,0,0,0,0,0,0,0,0,0,0],
      582=>["electrify","輸電",:electric,0,20,0,0,:status,10,354,0,13,0,0,0,0,0,0,0,0,0,0,0],
      583=>["play-rough","嬉鬧",:fairy,90,10,90,0,:physical,10,69,10,6,0,0,0,0,0,0,0,0,0,0,10],
      584=>["fairy-wind","妖精之風",:fairy,40,30,100,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      585=>["moonblast","月亮之力",:fairy,95,15,100,0,:special,10,72,30,6,0,0,0,0,0,0,0,0,0,0,30],
      586=>["boomburst","爆音波",:normal,140,10,100,0,:special,9,379,0,0,0,0,0,0,0,0,0,0,0,0,0],
      587=>["fairy-lock","妖精之鎖",:fairy,0,10,0,0,:status,12,355,0,10,0,0,0,0,0,0,0,0,0,0,0],
      588=>["kings-shield","王者盾牌",:steel,0,10,0,4,:status,7,356,0,13,0,0,0,0,0,0,0,0,0,0,0],
      589=>["play-nice","和睦相處",:normal,0,20,0,0,:status,10,357,100,2,0,0,0,0,0,0,0,0,0,0,100],
      590=>["confide","密語",:normal,0,20,0,0,:status,10,358,100,2,0,0,0,0,0,0,0,0,0,0,100],
      591=>["diamond-storm","鑽石風暴",:rock,100,5,95,0,:physical,11,359,50,7,0,0,0,0,0,0,0,0,0,0,50],
      592=>["steam-eruption","蒸汽爆炸",:water,110,5,95,0,:special,10,5,30,4,4,0,0,0,0,0,0,0,30,0,0],
      593=>["hyperspace-hole","異次元洞",:psychic,80,5,0,0,:special,10,360,0,0,0,0,0,0,0,0,0,0,0,0,0],
      594=>["water-shuriken","飛水手裡劍",:water,15,20,100,1,:special,10,361,0,0,0,2,5,0,0,0,0,0,0,0,0],
      595=>["mystical-fire","魔法火焰",:fire,75,10,100,0,:special,10,72,100,6,0,0,0,0,0,0,0,0,0,0,100],
      596=>["spiky-shield","尖刺防守",:grass,0,10,0,4,:status,7,362,0,13,0,0,0,0,0,0,0,0,0,0,0],
      597=>["aromatic-mist","芳香薄霧",:fairy,0,20,0,0,:status,3,363,0,2,0,0,0,0,0,0,0,0,0,0,0],
      598=>["eerie-impulse","怪異電波",:electric,0,15,100,0,:status,10,62,0,2,0,0,0,0,0,0,0,0,0,0,0],
      599=>["venom-drench","毒液陷阱",:poison,0,20,100,0,:status,11,364,100,2,0,0,0,0,0,0,0,0,0,0,100],
      600=>["powder","粉塵",:bug,0,20,100,1,:status,10,378,0,13,0,0,0,0,0,0,0,0,0,0,0],
      601=>["geomancy","大地掌控",:fairy,0,10,0,0,:status,7,366,0,2,0,0,0,0,0,0,0,0,0,0,0],
      602=>["magnetic-flux","磁場操控",:electric,0,20,0,0,:status,13,367,0,2,0,0,0,0,0,0,0,0,0,0,0],
      603=>["happy-hour","歡樂時光",:normal,0,30,0,0,:status,4,368,0,13,0,0,0,0,0,0,0,0,0,0,0],
      604=>["electric-terrain","電氣場地",:electric,0,10,0,0,:status,12,369,0,10,0,0,0,0,0,0,0,0,0,0,0],
      605=>["dazzling-gleam","魔法閃耀",:fairy,80,10,100,0,:special,11,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      606=>["celebrate","慶祝",:normal,0,40,0,0,:status,7,370,0,13,0,0,0,0,0,0,0,0,0,0,0],
      607=>["hold-hands","牽手",:normal,0,40,0,0,:status,3,371,0,13,0,0,0,0,0,0,0,0,0,0,0],
      608=>["baby-doll-eyes","圓瞳",:fairy,0,30,100,1,:status,10,365,0,2,0,0,0,0,0,0,0,0,0,0,0],
      609=>["nuzzle","蹭蹭臉頰",:electric,20,20,100,0,:physical,10,372,100,4,1,0,0,0,0,0,0,0,100,0,0],
      610=>["hold-back","手下留情",:normal,40,40,100,0,:physical,10,102,0,0,0,0,0,0,0,0,0,0,0,0,0],
      611=>["infestation","死纏爛打",:bug,20,20,100,0,:special,10,43,100,4,8,0,0,4,5,0,0,0,100,0,0],
      612=>["power-up-punch","增強拳",:fighting,40,20,100,0,:physical,10,375,100,7,0,0,0,0,0,0,0,0,0,0,100],
      613=>["oblivion-wing","死亡之翼",:flying,80,10,100,0,:special,10,349,0,8,0,0,0,0,0,75,0,0,0,0,0],
      614=>["thousand-arrows","千箭齊發",:ground,90,10,100,0,:physical,11,373,100,0,-1,0,0,0,0,0,0,0,100,0,0],
      615=>["thousand-waves","千波激盪",:ground,90,10,100,0,:physical,11,374,0,0,0,0,0,0,0,0,0,0,0,0,0],
      616=>["lands-wrath","大地神力",:ground,90,10,100,0,:physical,11,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      617=>["light-of-ruin","破滅之光",:fairy,140,5,90,0,:special,10,270,0,0,0,0,0,0,0,-50,0,0,0,0,0],
      618=>["origin-pulse","根源波動",:water,110,10,85,0,:special,11,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      619=>["precipice-blades","斷崖之劍",:ground,120,10,85,0,:physical,11,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      620=>["dragon-ascent","畫龍點睛",:flying,120,5,100,0,:physical,10,230,100,7,0,0,0,0,0,0,0,0,0,0,100],
      621=>["hyperspace-fury","異次元猛攻",:dark,100,5,0,0,:physical,10,360,100,7,0,0,0,0,0,0,0,0,0,0,100],
      622=>["breakneck-blitz--physical","究極無敵大衝撞",:normal,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      623=>["breakneck-blitz--special","究極無敵大衝撞",:normal,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      624=>["all-out-pummeling--physical","全力無雙激烈拳",:fighting,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      625=>["all-out-pummeling--special","全力無雙激烈拳",:fighting,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      626=>["supersonic-skystrike--physical","極速俯衝轟烈撞",:flying,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      627=>["supersonic-skystrike--special","極速俯衝轟烈撞",:flying,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      628=>["acid-downpour--physical","強酸劇毒滅絕雨",:poison,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      629=>["acid-downpour--special","強酸劇毒滅絕雨",:poison,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      630=>["tectonic-rage--physical","地隆嘯天大終結",:ground,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      631=>["tectonic-rage--special","地隆嘯天大終結",:ground,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      632=>["continental-crush--physical","毀天滅地巨岩墜",:rock,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      633=>["continental-crush--special","毀天滅地巨岩墜",:rock,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      634=>["savage-spin-out--physical","絕對捕食迴旋斬",:bug,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      635=>["savage-spin-out--special","絕對捕食迴旋斬",:bug,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      636=>["never-ending-nightmare--physical","無盡暗夜之誘惑",:ghost,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      637=>["never-ending-nightmare--special","無盡暗夜之誘惑",:ghost,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      638=>["corkscrew-crash--physical","超絕螺旋連擊",:steel,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      639=>["corkscrew-crash--special","超絕螺旋連擊",:steel,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      640=>["inferno-overdrive--physical","超強極限爆焰彈",:fire,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      641=>["inferno-overdrive--special","超強極限爆焰彈",:fire,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      642=>["hydro-vortex--physical","超級水流大漩渦",:water,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      643=>["hydro-vortex--special","超級水流大漩渦",:water,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      644=>["bloom-doom--physical","絢爛繽紛花怒放",:grass,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      645=>["bloom-doom--special","絢爛繽紛花怒放",:grass,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      646=>["gigavolt-havoc--physical","終極伏特狂雷閃",:electric,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      647=>["gigavolt-havoc--special","終極伏特狂雷閃",:electric,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      648=>["shattered-psyche--physical","至高精神破壞波",:psychic,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      649=>["shattered-psyche--special","至高精神破壞波",:psychic,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      650=>["subzero-slammer--physical","激狂大地萬里冰",:ice,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      651=>["subzero-slammer--special","激狂大地萬里冰",:ice,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      652=>["devastating-drake--physical","究極巨龍震天地",:dragon,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      653=>["devastating-drake--special","究極巨龍震天地",:dragon,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      654=>["black-hole-eclipse--physical","黑洞吞噬萬物滅",:dark,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      655=>["black-hole-eclipse--special","黑洞吞噬萬物滅",:dark,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      656=>["twinkle-tackle--physical","可愛星星飛天撞",:fairy,0,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      657=>["twinkle-tackle--special","可愛星星飛天撞",:fairy,0,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      658=>["catastropika","皮卡皮卡必殺擊",:electric,210,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      659=>["shore-up","集沙",:ground,0,5,0,0,:status,7,382,0,3,0,0,0,0,0,0,50,0,0,0,0],
      660=>["first-impression","迎頭一擊",:bug,90,10,100,2,:physical,10,383,0,0,0,0,0,0,0,0,0,0,0,0,0],
      661=>["baneful-bunker","碉堡",:poison,0,10,0,4,:status,7,384,0,13,0,0,0,0,0,0,0,0,0,0,0],
      662=>["spirit-shackle","縫影",:ghost,80,10,100,0,:physical,10,385,0,0,0,0,0,0,0,0,0,0,0,0,0],
      663=>["darkest-lariat","ＤＤ金勾臂",:dark,85,10,100,0,:physical,10,304,0,0,0,0,0,0,0,0,0,0,0,0,0],
      664=>["sparkling-aria","泡影的詠歎調",:water,90,10,100,0,:special,9,386,0,0,0,0,0,0,0,0,0,0,0,0,0],
      665=>["ice-hammer","冰錘",:ice,100,10,90,0,:physical,10,219,100,7,0,0,0,0,0,0,0,0,0,0,100],
      666=>["floral-healing","花療",:fairy,0,10,0,0,:status,10,387,0,3,0,0,0,0,0,0,50,0,0,0,0],
      667=>["high-horsepower","十萬馬力",:ground,95,10,95,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      668=>["strength-sap","吸取力量",:grass,0,10,100,0,:status,10,388,100,13,0,0,0,0,0,0,0,0,0,0,100],
      669=>["solar-blade","日光刃",:grass,125,10,100,0,:physical,10,152,0,0,0,0,0,0,0,0,0,0,0,0,0],
      670=>["leafage","樹葉",:grass,40,40,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      671=>["spotlight","聚光燈",:normal,0,15,0,3,:status,10,389,0,13,0,0,0,0,0,0,0,0,0,0,0],
      672=>["toxic-thread","毒絲",:poison,0,20,100,0,:status,10,390,100,5,5,0,0,0,0,0,0,0,100,0,100],
      673=>["laser-focus","磨礪",:normal,0,30,0,0,:status,7,391,0,13,0,0,0,0,0,0,0,0,0,0,0],
      674=>["gear-up","輔助齒輪",:steel,0,20,0,0,:status,13,392,0,2,0,0,0,0,0,0,0,0,0,0,0],
      675=>["throat-chop","地獄突刺",:dark,80,15,100,0,:physical,10,393,100,4,24,0,0,2,2,0,0,0,100,0,0],
      676=>["pollen-puff","花粉團",:bug,90,15,100,0,:special,10,394,0,0,0,0,0,0,0,0,0,0,0,0,0],
      677=>["anchor-shot","擲錨",:steel,80,20,100,0,:physical,10,385,0,0,0,0,0,0,0,0,0,0,0,0,0],
      678=>["psychic-terrain","精神場地",:psychic,0,10,0,0,:status,12,395,0,10,0,0,0,0,0,0,0,0,0,0,0],
      679=>["lunge","猛撲",:bug,80,15,100,0,:physical,10,396,100,6,0,0,0,0,0,0,0,0,0,0,100],
      680=>["fire-lash","火焰鞭",:fire,80,15,100,0,:physical,10,397,100,6,0,0,0,0,0,0,0,0,0,0,100],
      681=>["power-trip","囂張",:dark,20,10,100,0,:physical,10,306,0,0,0,0,0,0,0,0,0,0,0,0,0],
      682=>["burn-up","燃盡",:fire,130,5,100,0,:special,10,398,0,0,0,0,0,0,0,0,0,0,0,0,0],
      683=>["speed-swap","速度互換",:psychic,0,10,0,0,:status,10,399,0,13,0,0,0,0,0,0,0,0,0,0,0],
      684=>["smart-strike","修長之角",:steel,70,10,0,0,:physical,10,18,0,0,0,0,0,0,0,0,0,0,0,0,0],
      685=>["purify","淨化",:poison,0,20,0,0,:status,10,400,0,13,0,0,0,0,0,0,50,0,0,0,0],
      686=>["revelation-dance","覺醒之舞",:normal,90,15,100,0,:special,10,401,0,0,0,0,0,0,0,0,0,0,0,0,0],
      687=>["core-enforcer","核心懲罰者",:dragon,100,10,100,0,:special,11,402,0,0,0,0,0,0,0,0,0,0,0,0,0],
      688=>["trop-kick","熱帶踢",:grass,70,15,100,0,:physical,10,396,100,6,0,0,0,0,0,0,0,0,0,0,100],
      689=>["instruct","號令",:psychic,0,15,0,0,:status,10,403,0,13,0,0,0,0,0,0,0,0,0,0,0],
      690=>["beak-blast","鳥嘴加農炮",:flying,100,15,100,-3,:physical,10,404,0,0,0,0,0,0,0,0,0,0,0,0,0],
      691=>["clanging-scales","鱗片噪音",:dragon,110,5,100,0,:special,11,405,100,7,0,0,0,0,0,0,0,0,0,0,100],
      692=>["dragon-hammer","龍錘",:dragon,90,15,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      693=>["brutal-swing","狂舞揮打",:dark,60,20,100,0,:physical,9,406,0,0,0,0,0,0,0,0,0,0,0,0,0],
      694=>["aurora-veil","極光幕",:ice,0,20,0,0,:status,4,407,0,11,0,0,0,0,0,0,0,0,0,0,0],
      695=>["sinister-arrow-raid","遮天蔽日暗影箭",:ghost,180,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      696=>["malicious-moonsault","極惡飛躍粉碎擊",:dark,180,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      697=>["oceanic-operetta","海神莊嚴交響樂",:water,195,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      698=>["guardian-of-alola","巨人衛士・阿羅拉",:fairy,0,1,0,0,:special,10,413,0,0,0,0,0,0,0,0,0,0,0,0,0],
      699=>["soul-stealing-7-star-strike","七星奪魂腿",:ghost,195,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      700=>["stoked-sparksurfer","駕雷馭電戲衝浪",:electric,175,1,0,0,:special,10,7,100,4,1,0,0,0,0,0,0,0,100,0,0],
      701=>["pulverizing-pancake","認真起來大爆擊",:normal,210,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      702=>["extreme-evoboost","九彩昇華齊聚頂",:normal,0,1,0,0,:status,7,414,100,2,0,0,0,0,0,0,0,0,0,0,100],
      703=>["genesis-supernova","起源超新星大爆炸",:psychic,185,1,0,0,:special,10,415,0,0,0,0,0,0,0,0,0,0,0,0,0],
      704=>["shell-trap","陷阱甲殼",:fire,150,5,100,-3,:special,11,408,0,0,0,0,0,0,0,0,0,0,0,0,0],
      705=>["fleur-cannon","花朵加農炮",:fairy,130,5,90,0,:special,10,205,100,7,0,0,0,0,0,0,0,0,0,0,100],
      706=>["psychic-fangs","精神之牙",:psychic,85,10,100,0,:physical,10,187,0,0,0,0,0,0,0,0,0,0,0,0,0],
      707=>["stomping-tantrum","跺腳",:ground,75,10,100,0,:physical,10,409,0,0,0,0,0,0,0,0,0,0,0,0,0],
      708=>["shadow-bone","暗影之骨",:ghost,85,10,100,0,:physical,10,70,20,6,0,0,0,0,0,0,0,0,0,0,20],
      709=>["accelerock","衝岩",:rock,40,20,100,1,:physical,10,104,0,0,0,0,0,0,0,0,0,0,0,0,0],
      710=>["liquidation","水流裂破",:water,85,10,100,0,:physical,10,70,20,6,0,0,0,0,0,0,0,0,0,0,20],
      711=>["prismatic-laser","稜鏡鐳射",:psychic,160,10,100,0,:special,10,81,0,0,0,0,0,0,0,0,0,0,0,0,0],
      712=>["spectral-thief","暗影偷盜",:ghost,90,10,100,0,:physical,10,410,0,0,0,0,0,0,0,0,0,0,0,0,0],
      713=>["sunsteel-strike","流星閃衝",:steel,100,5,100,0,:physical,10,411,0,0,0,0,0,0,0,0,0,0,0,0,0],
      714=>["moongeist-beam","暗影之光",:ghost,100,5,100,0,:special,10,411,0,0,0,0,0,0,0,0,0,0,0,0,0],
      715=>["tearful-look","淚眼汪汪",:normal,0,20,0,0,:status,10,412,100,2,0,0,0,0,0,0,0,0,0,0,100],
      716=>["zing-zap","麻麻刺刺",:electric,80,10,100,0,:physical,10,32,30,0,0,0,0,0,0,0,0,0,0,30,0],
      717=>["natures-madness","自然之怒",:fairy,0,10,90,0,:special,10,41,0,0,0,0,0,0,0,0,0,0,0,0,0],
      718=>["multi-attack","多屬性攻擊",:normal,120,10,100,0,:physical,10,269,0,0,0,0,0,0,0,0,0,0,0,0,0],
      719=>["10-000-000-volt-thunderbolt","千萬伏特",:electric,195,1,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,2,0,0,0],
      720=>["mind-blown","驚爆大頭",:fire,150,5,100,0,:special,9,420,0,0,0,0,0,0,0,0,0,0,0,0,0],
      721=>["plasma-fists","等離子閃電拳",:electric,100,15,100,0,:physical,10,417,0,0,0,0,0,0,0,0,0,0,0,0,0],
      722=>["photon-geyser","光子噴湧",:psychic,100,5,100,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      723=>["light-that-burns-the-sky","焚天滅世熾光爆",:psychic,200,1,0,0,:special,10,416,0,0,0,0,0,0,0,0,0,0,0,0,0],
      724=>["searing-sunraze-smash","日光迴旋下蒼穹",:steel,200,1,0,0,:physical,10,411,0,0,0,0,0,0,0,0,0,0,0,0,0],
      725=>["menacing-moonraze-maelstrom","月華飛濺落靈霄",:ghost,200,1,0,0,:special,10,411,0,0,0,0,0,0,0,0,0,0,0,0,0],
      726=>["lets-snuggle-forever","親密無間大亂揍",:fairy,190,1,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      727=>["splintered-stormshards","狼嘯石牙颶風暴",:rock,190,1,0,0,:physical,10,418,0,0,0,0,0,0,0,0,0,0,0,0,0],
      728=>["clangorous-soulblaze","熾魂熱舞烈音爆",:dragon,185,1,0,0,:special,11,419,100,7,0,0,0,0,0,0,0,0,0,0,100],
      729=>["zippy-zap","電電加速",:electric,80,10,100,2,:physical,10,1,100,7,0,0,0,0,0,0,0,0,0,0,100],
      730=>["splishy-splash","滔滔衝浪",:water,90,15,100,0,:special,11,1,30,4,1,0,0,0,0,0,0,0,30,0,0],
      731=>["floaty-fall","飄飄墜落",:flying,90,15,95,0,:physical,10,1,30,0,0,0,0,0,0,0,0,0,0,30,0],
      732=>["pika-papow","閃閃雷光",:electric,0,20,0,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      733=>["bouncy-bubble","活活氣泡",:water,60,20,100,0,:special,10,1,0,8,0,0,0,0,0,100,0,0,0,0,0],
      734=>["buzzy-buzz","麻麻電擊",:electric,60,20,100,0,:special,10,1,100,4,1,0,0,0,0,0,0,0,100,0,0],
      735=>["sizzly-slide","熊熊火爆",:fire,60,20,100,0,:physical,10,1,100,4,4,0,0,0,0,0,0,0,100,0,0],
      736=>["glitzy-glow","嘩嘩氣場",:psychic,80,15,95,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      737=>["baddy-bad","壞壞領域",:dark,80,15,95,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      738=>["sappy-seed","茁茁轟炸",:grass,100,10,90,0,:physical,10,1,100,4,18,0,0,0,0,0,0,0,100,0,0],
      739=>["freezy-frost","冰冰霜凍",:ice,100,10,90,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      740=>["sparkly-swirl","亮亮風暴",:fairy,120,5,85,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      741=>["veevee-volley","砰砰擊破",:normal,0,20,0,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      742=>["double-iron-bash","鋼拳雙擊",:steel,60,5,100,0,:physical,10,45,30,0,0,2,2,0,0,0,0,0,0,30,0],
      743=>["max-guard","極巨防壁",:normal,0,10,0,4,:status,7,112,0,13,0,0,0,0,0,0,0,0,0,0,0],
      744=>["dynamax-cannon","極巨炮",:dragon,100,5,100,0,:special,10,421,0,0,0,0,0,0,0,0,0,0,0,0,0],
      745=>["snipe-shot","狙擊",:water,80,15,100,0,:special,10,422,0,0,0,0,0,0,0,0,0,1,0,0,0],
      746=>["jaw-lock","緊咬不放",:dark,80,10,100,0,:physical,10,423,0,0,0,0,0,0,0,0,0,0,0,0,0],
      747=>["stuff-cheeks","大快朵頤",:normal,0,10,0,0,:status,7,424,100,2,0,0,0,0,0,0,0,0,0,0,100],
      748=>["no-retreat","背水一戰",:fighting,0,5,0,0,:status,7,425,100,2,0,0,0,0,0,0,0,0,0,0,100],
      749=>["tar-shot","瀝青射擊",:rock,0,15,100,0,:status,10,426,100,5,42,0,0,0,0,0,0,0,100,0,100],
      750=>["magic-powder","魔法粉",:psychic,0,20,100,0,:status,10,427,0,13,0,0,0,0,0,0,0,0,0,0,0],
      751=>["dragon-darts","龍箭",:dragon,50,10,100,0,:physical,10,428,0,0,0,2,2,0,0,0,0,0,0,0,0],
      752=>["teatime","茶會",:normal,0,10,0,0,:status,14,429,0,13,0,0,0,0,0,0,0,0,0,0,0],
      753=>["octolock","蛸固",:fighting,0,15,100,0,:status,10,430,0,13,0,0,0,0,0,0,0,0,0,0,0],
      754=>["bolt-beak","電喙",:electric,85,10,100,0,:physical,10,431,0,0,0,0,0,0,0,0,0,0,0,0,0],
      755=>["fishious-rend","鰓咬",:water,85,10,100,0,:physical,10,431,0,0,0,0,0,0,0,0,0,0,0,0,0],
      756=>["court-change","換場",:normal,0,10,100,0,:status,12,432,0,13,0,0,0,0,0,0,0,0,0,0,0],
      757=>["max-flare","極巨火爆",:fire,100,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      758=>["max-flutterby","極巨蟲蠱",:bug,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      759=>["max-lightning","極巨閃電",:electric,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      760=>["max-strike","極巨攻擊",:normal,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      761=>["max-knuckle","極巨拳鬥",:fighting,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      762=>["max-phantasm","極巨幽魂",:ghost,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      763=>["max-hailstorm","極巨寒冰",:ice,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      764=>["max-ooze","極巨酸毒",:poison,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      765=>["max-geyser","極巨水流",:water,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      766=>["max-airstream","極巨飛衝",:flying,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      767=>["max-starfall","極巨妖精",:fairy,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      768=>["max-wyrmwind","極巨龍騎",:dragon,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      769=>["max-mindstorm","極巨超能",:psychic,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      770=>["max-rockfall","極巨岩石",:rock,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      771=>["max-quake","極巨大地",:ground,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      772=>["max-darkness","極巨惡霸",:dark,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      773=>["max-overgrowth","極巨草原",:grass,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      774=>["max-steelspike","極巨鋼鐵",:steel,10,10,0,0,:physical,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      775=>["clangorous-soul","魂舞烈音爆",:dragon,0,5,100,0,:status,7,433,100,2,0,0,0,0,0,0,-33,0,0,0,100],
      776=>["body-press","撲擊",:fighting,80,10,100,0,:physical,10,434,0,0,0,0,0,0,0,0,0,0,0,0,0],
      777=>["decorate","裝飾",:fairy,0,15,0,0,:status,10,435,100,2,0,0,0,0,0,0,0,0,0,0,100],
      778=>["drum-beating","鼓擊",:grass,80,10,100,0,:physical,10,71,100,6,0,0,0,0,0,0,0,0,0,0,100],
      779=>["snap-trap","捕獸夾",:grass,35,15,100,0,:physical,10,43,100,4,8,0,0,5,6,0,0,0,100,0,0],
      780=>["pyro-ball","火焰球",:fire,120,5,90,0,:physical,10,5,10,4,4,0,0,0,0,0,0,0,10,0,0],
      781=>["behemoth-blade","巨獸斬",:steel,100,5,100,0,:physical,10,436,0,0,0,0,0,0,0,0,0,0,0,0,0],
      782=>["behemoth-bash","巨獸彈",:steel,100,5,100,0,:physical,10,436,0,0,0,0,0,0,0,0,0,0,0,0,0],
      783=>["aura-wheel","氣場輪",:electric,110,10,100,0,:physical,10,437,100,7,0,0,0,0,0,0,0,0,0,0,100],
      784=>["breaking-swipe","廣域破壞",:dragon,60,15,100,0,:physical,11,396,100,6,0,0,0,0,0,0,0,0,0,0,100],
      785=>["branch-poke","木枝突刺",:grass,40,40,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      786=>["overdrive","破音",:electric,80,10,100,0,:special,11,439,0,0,0,0,0,0,0,0,0,0,0,0,0],
      787=>["apple-acid","蘋果酸",:grass,80,10,100,0,:special,10,440,100,6,0,0,0,0,0,0,0,0,0,0,100],
      788=>["grav-apple","萬有引力",:grass,80,10,100,0,:physical,10,397,100,6,0,0,0,0,0,0,0,0,0,0,100],
      789=>["spirit-break","靈魂衝擊",:fairy,75,15,100,0,:physical,10,72,100,6,0,0,0,0,0,0,0,0,0,0,100],
      790=>["strange-steam","神奇蒸汽",:fairy,90,10,95,0,:special,10,77,20,4,6,0,0,2,5,0,0,0,20,0,0],
      791=>["life-dew","生命水滴",:water,0,10,0,0,:status,13,441,0,3,0,0,0,0,0,0,25,0,0,0,0],
      792=>["obstruct","攔堵",:dark,0,10,100,4,:status,7,442,0,13,0,0,0,0,0,0,0,0,0,0,0],
      793=>["false-surrender","假跪真撞",:dark,80,10,0,0,:physical,10,18,0,0,0,0,0,0,0,0,0,0,0,0,0],
      794=>["meteor-assault","流星突擊",:fighting,150,5,100,0,:physical,10,81,0,0,0,0,0,0,0,0,0,0,0,0,0],
      795=>["eternabeam","無極光束",:dragon,160,5,90,0,:special,10,81,0,0,0,0,0,0,0,0,0,0,0,0,0],
      796=>["steel-beam","鐵蹄光線",:steel,140,5,95,0,:special,10,420,0,0,0,0,0,0,0,0,0,0,0,0,0],
      797=>["expanding-force","廣域戰力",:psychic,80,10,100,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      798=>["steel-roller","鐵滾輪",:steel,130,5,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      799=>["scale-shot","鱗射",:dragon,25,20,90,0,:physical,10,443,0,0,0,2,5,0,0,0,0,0,0,0,0],
      800=>["meteor-beam","流星光束",:rock,120,10,90,0,:special,10,1,100,0,0,0,0,0,0,0,0,0,100,0,0],
      801=>["shell-side-arm","臂貝武器",:poison,90,10,100,0,:special,10,1,20,4,5,0,0,0,0,0,0,0,20,0,0],
      802=>["misty-explosion","薄霧炸裂",:fairy,100,5,100,0,:special,9,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      803=>["grassy-glide","青草滑梯",:grass,55,20,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      804=>["rising-voltage","電力上升",:electric,70,20,100,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      805=>["terrain-pulse","大地波動",:normal,50,10,100,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      806=>["skitter-smack","爬擊",:bug,70,10,90,0,:physical,10,1,100,6,0,0,0,0,0,0,0,0,0,0,100],
      807=>["burning-jealousy","妒火",:fire,70,5,100,0,:special,11,1,100,4,4,0,0,0,0,0,0,0,100,0,0],
      808=>["lash-out","洩憤",:dark,75,5,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      809=>["poltergeist","靈騷",:ghost,110,5,90,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      810=>["corrosive-gas","腐蝕氣體",:poison,0,40,100,0,:status,9,1,0,13,0,0,0,0,0,0,0,0,0,0,0],
      811=>["coaching","指導",:fighting,0,10,0,0,:status,13,1,100,2,0,0,0,0,0,0,0,0,0,0,100],
      812=>["flip-turn","快速折返",:water,60,20,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      813=>["triple-axel","三旋擊",:ice,20,10,90,0,:physical,10,1,0,0,0,3,3,0,0,0,0,0,0,0,0],
      814=>["dual-wingbeat","雙翼",:flying,40,10,90,0,:physical,10,1,0,0,0,2,2,0,0,0,0,0,0,0,0],
      815=>["scorching-sands","熱沙大地",:ground,70,10,100,0,:special,10,5,30,4,4,0,0,0,0,0,0,0,30,0,0],
      816=>["jungle-healing","叢林治療",:grass,0,10,0,0,:status,13,1,0,13,0,0,0,0,0,0,25,0,0,0,0],
      817=>["wicked-blow","暗冥強擊",:dark,75,5,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,6,0,0,0],
      818=>["surging-strikes","水流連打",:water,25,5,100,0,:physical,10,1,0,0,0,3,3,0,0,0,0,6,0,0,0],
      819=>["thunder-cage","雷電囚籠",:electric,80,15,90,0,:special,10,1,100,4,8,0,0,5,6,0,0,0,100,0,0],
      820=>["dragon-energy","巨龍威能",:dragon,150,5,100,0,:special,11,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      821=>["freezing-glare","冰冷視線",:psychic,90,10,100,0,:special,10,1,10,4,3,0,0,0,0,0,0,0,10,0,0],
      822=>["fiery-wrath","怒火中燒",:dark,90,10,100,0,:special,11,1,20,0,0,0,0,0,0,0,0,0,0,20,0],
      823=>["thunderous-kick","雷鳴蹴擊",:fighting,90,10,100,0,:physical,10,1,100,6,0,0,0,0,0,0,0,0,0,0,100],
      824=>["glacial-lance","雪矛",:ice,120,5,100,0,:physical,11,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      825=>["astral-barrage","星碎",:ghost,120,5,100,0,:special,11,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      826=>["eerie-spell","詭異咒語",:psychic,80,5,100,0,:special,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      827=>["dire-claw","克命爪",:poison,80,15,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      828=>["psyshield-bash","屏障猛攻",:psychic,70,10,90,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      829=>["power-shift","力量转换",:normal,0,10,0,0,:status,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      830=>["stone-axe","岩斧",:rock,65,15,90,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      831=>["springtide-storm","阳春风暴",:fairy,100,5,80,0,:special,11,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      832=>["mystical-power","神秘之力",:psychic,70,10,90,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      833=>["raging-fury","大愤慨",:fire,120,10,100,0,:physical,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      834=>["wave-crash","波动冲",:water,120,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      835=>["chloroblast","叶绿爆震",:grass,150,5,95,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      836=>["mountain-gale","冰山风",:ice,100,10,85,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      837=>["victory-dance","胜利之舞",:fighting,0,10,0,0,:status,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      838=>["headlong-rush","突飞猛扑",:ground,120,5,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      839=>["barb-barrage","毒千针",:poison,60,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      840=>["esper-wing","气场之翼",:psychic,80,10,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      841=>["bitter-malice","冤冤相报",:ghost,75,10,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      842=>["shelter","闭关",:steel,0,10,0,0,:status,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      843=>["triple-arrows","三连箭",:fighting,90,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      844=>["infernal-parade","群魔乱舞",:ghost,60,15,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      845=>["ceaseless-edge","秘剑・千重涛",:dark,65,15,90,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      846=>["bleakwind-storm","枯叶风暴",:flying,100,10,80,0,:special,11,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      847=>["wildbolt-storm","鸣雷风暴",:electric,100,10,80,0,:special,11,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      848=>["sandsear-storm","热沙风暴",:ground,100,10,80,0,:special,11,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      849=>["lunar-blessing","新月祈祷",:psychic,0,5,0,0,:status,15,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      850=>["take-heart","勇气填充",:psychic,0,10,0,0,:status,15,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      851=>["tera-blast","太晶爆发",:normal,80,10,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      852=>["silk-trap","线阱",:bug,0,10,0,4,:status,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      853=>["axe-kick","下压踢",:fighting,120,10,90,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      854=>["last-respects","扫墓",:ghost,50,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      855=>["lumina-crash","琉光冲激",:psychic,80,10,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      856=>["order-up","上菜",:dragon,80,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      857=>["jet-punch","喷射拳",:water,60,15,100,1,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      858=>["spicy-extract","辣椒精华",:grass,0,15,0,0,:status,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      859=>["spin-out","疾速转轮",:steel,100,5,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      860=>["population-bomb","鼠数儿",:normal,20,10,90,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      861=>["ice-spinner","冰旋",:ice,80,15,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      862=>["glaive-rush","巨剑突击",:dragon,120,5,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      863=>["revival-blessing","复生祈祷",:normal,0,1,0,0,:status,16,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      864=>["salt-cure","盐腌",:rock,40,15,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      865=>["triple-dive","三连钻",:water,30,10,95,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      866=>["mortal-spin","晶光转转",:poison,30,15,100,0,:physical,11,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      867=>["doodle","描绘",:normal,0,10,100,0,:status,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      868=>["fillet-away","甩肉",:normal,0,10,0,0,:status,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      869=>["kowtow-cleave","仆刀",:dark,85,10,0,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      870=>["flower-trick","千变万花",:grass,70,10,0,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      871=>["torch-song","闪焰高歌",:fire,80,10,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      872=>["aqua-step","流水旋舞",:water,80,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      873=>["raging-bull","怒牛",:normal,90,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      874=>["make-it-rain","淘金潮",:steel,120,5,100,0,:special,11,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      875=>["psyblade","精神劍",:psychic,80,15,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      876=>["hydro-steam","水蒸氣",:water,80,15,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      877=>["ruination","大灾难",:dark,1,10,90,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      878=>["collision-course","全开猛撞",:fighting,100,5,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      879=>["electro-drift","闪电猛冲",:electric,100,5,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      880=>["shed-tail","断尾",:normal,0,10,0,0,:status,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      881=>["chilly-reception","冷笑话",:ice,0,10,0,0,:status,12,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      882=>["tidy-up","大扫除",:normal,0,10,0,0,:status,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      883=>["snowscape","雪景",:ice,0,10,0,0,:status,12,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      884=>["pounce","虫扑",:bug,50,20,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      885=>["trailblaze","起草",:grass,50,20,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      886=>["chilling-water","泼冷水",:water,50,20,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      887=>["hyper-drill","强力钻",:normal,100,5,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      888=>["twin-beam","双光束",:psychic,40,10,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      889=>["rage-fist","愤怒之拳",:ghost,50,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      890=>["armor-cannon","铠农炮",:fire,120,5,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      891=>["bitter-blade","悔念剑",:fire,90,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      892=>["double-shock","电光双击",:electric,120,5,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      893=>["gigaton-hammer","巨力锤",:steel,160,5,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      894=>["comeuppance","复仇",:dark,1,10,100,0,:physical,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      895=>["aqua-cutter","水波刀",:water,70,20,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      896=>["blazing-torque","灼热暴冲",:fire,80,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      897=>["wicked-torque","黑暗暴冲",:dark,80,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      898=>["noxious-torque","剧毒暴冲",:poison,100,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      899=>["combat-torque","格斗暴冲",:fighting,100,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      900=>["magical-torque","魔法暴冲",:fairy,100,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      901=>["blood-moon","blood-moon",:normal,140,5,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      902=>["matcha-gotcha","matcha-gotcha",:grass,80,15,90,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      903=>["syrup-bomb","syrup-bomb",:grass,60,10,85,0,:special,10,0,0,13,0,0,0,3,3,0,0,0,0,0,100],
      904=>["ivy-cudgel","ivy-cudgel",:grass,100,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      905=>["electro-shot","電光束",:electric,130,10,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      906=>["tera-starstorm","晶光星群",:normal,120,5,100,0,:special,11,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      907=>["fickle-beam","隨機光",:dragon,80,5,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      908=>["burning-bulwark","火焰守護",:fire,0,10,0,4,:status,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      909=>["thunderclap","迅雷",:electric,70,5,100,1,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      910=>["mighty-cleave","強刃攻擊",:rock,95,5,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      911=>["tachyon-cutter","迅子利刃",:steel,50,10,0,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      912=>["hard-press","硬壓",:steel,0,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      913=>["dragon-cheer","龍聲鼓舞",:dragon,0,15,0,0,:status,15,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      914=>["alluring-voice","魅誘之聲",:fairy,80,10,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      915=>["temper-flare","豁出去",:fire,75,10,100,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      916=>["supercell-slam","閃電強襲",:electric,100,15,95,0,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      917=>["psychic-noise","精神噪音",:psychic,75,10,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      918=>["upper-hand","快手還擊",:fighting,65,15,100,3,:physical,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      919=>["malignant-chain","邪毒鎖鏈",:poison,100,5,100,0,:special,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10001=>["shadow-rush","shadow-rush",:shadow,55,0,100,0,:physical,10,10001,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10002=>["shadow-blast","shadow-blast",:shadow,80,0,100,0,:physical,10,44,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10003=>["shadow-blitz","shadow-blitz",:shadow,40,0,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10004=>["shadow-bolt","shadow-bolt",:shadow,75,0,100,0,:special,10,7,10,0,0,0,0,0,0,0,0,0,0,0,0],
      10005=>["shadow-break","shadow-break",:shadow,75,0,100,0,:physical,10,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10006=>["shadow-chill","shadow-chill",:shadow,75,0,100,0,:special,10,6,10,0,0,0,0,0,0,0,0,0,0,0,0],
      10007=>["shadow-end","shadow-end",:shadow,120,0,60,0,:physical,10,10002,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10008=>["shadow-fire","shadow-fire",:shadow,75,0,100,0,:special,10,5,10,0,0,0,0,0,0,0,0,0,0,0,0],
      10009=>["shadow-rave","shadow-rave",:shadow,70,0,100,0,:special,6,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10010=>["shadow-storm","shadow-storm",:shadow,95,0,100,0,:special,6,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10011=>["shadow-wave","shadow-wave",:shadow,50,0,100,0,:special,6,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10012=>["shadow-down","shadow-down",:shadow,0,0,100,0,:status,6,60,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10013=>["shadow-half","shadow-half",:shadow,0,0,100,0,:special,12,10003,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10014=>["shadow-hold","shadow-hold",:shadow,0,0,0,0,:status,6,107,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10015=>["shadow-mist","shadow-mist",:shadow,0,0,100,0,:status,6,10004,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10016=>["shadow-panic","shadow-panic",:shadow,0,0,90,0,:status,6,50,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10017=>["shadow-shed","shadow-shed",:shadow,0,0,0,0,:status,12,10005,0,0,0,0,0,0,0,0,0,0,0,0,0],
      10018=>["shadow-sky","shadow-sky",:shadow,0,0,0,0,:status,12,10006,0,0,0,0,0,0,0,0,0,0,0,0,0],
    }
    # ability_id => [identifier, name_zh_hant, generation_id, is_main_series]
    ABILITY_CATALOG = {
      1=>["stench","惡臭",3,1],
      2=>["drizzle","降雨",3,1],
      3=>["speed-boost","加速",3,1],
      4=>["battle-armor","戰鬥盔甲",3,1],
      5=>["sturdy","結實",3,1],
      6=>["damp","濕氣",3,1],
      7=>["limber","柔軟",3,1],
      8=>["sand-veil","沙隱",3,1],
      9=>["static","靜電",3,1],
      10=>["volt-absorb","蓄電",3,1],
      11=>["water-absorb","儲水",3,1],
      12=>["oblivious","遲鈍",3,1],
      13=>["cloud-nine","無關天氣",3,1],
      14=>["compound-eyes","複眼",3,1],
      15=>["insomnia","不眠",3,1],
      16=>["color-change","變色",3,1],
      17=>["immunity","免疫",3,1],
      18=>["flash-fire","引火",3,1],
      19=>["shield-dust","鱗粉",3,1],
      20=>["own-tempo","我行我素",3,1],
      21=>["suction-cups","吸盤",3,1],
      22=>["intimidate","威嚇",3,1],
      23=>["shadow-tag","踩影",3,1],
      24=>["rough-skin","粗糙皮膚",3,1],
      25=>["wonder-guard","神奇守護",3,1],
      26=>["levitate","飄浮",3,1],
      27=>["effect-spore","孢子",3,1],
      28=>["synchronize","同步",3,1],
      29=>["clear-body","恆淨之軀",3,1],
      30=>["natural-cure","自然回復",3,1],
      31=>["lightning-rod","避雷針",3,1],
      32=>["serene-grace","天恩",3,1],
      33=>["swift-swim","悠游自如",3,1],
      34=>["chlorophyll","葉綠素",3,1],
      35=>["illuminate","發光",3,1],
      36=>["trace","複製",3,1],
      37=>["huge-power","大力士",3,1],
      38=>["poison-point","毒刺",3,1],
      39=>["inner-focus","精神力",3,1],
      40=>["magma-armor","熔岩鎧甲",3,1],
      41=>["water-veil","水幕",3,1],
      42=>["magnet-pull","磁力",3,1],
      43=>["soundproof","隔音",3,1],
      44=>["rain-dish","雨盤",3,1],
      45=>["sand-stream","揚沙",3,1],
      46=>["pressure","壓迫感",3,1],
      47=>["thick-fat","厚脂肪",3,1],
      48=>["early-bird","早起",3,1],
      49=>["flame-body","火焰之軀",3,1],
      50=>["run-away","逃跑",3,1],
      51=>["keen-eye","銳利目光",3,1],
      52=>["hyper-cutter","怪力鉗",3,1],
      53=>["pickup","撿拾",3,1],
      54=>["truant","懶惰",3,1],
      55=>["hustle","活力",3,1],
      56=>["cute-charm","迷人之軀",3,1],
      57=>["plus","正電",3,1],
      58=>["minus","負電",3,1],
      59=>["forecast","陰晴不定",3,1],
      60=>["sticky-hold","黏著",3,1],
      61=>["shed-skin","蛻皮",3,1],
      62=>["guts","毅力",3,1],
      63=>["marvel-scale","神奇鱗片",3,1],
      64=>["liquid-ooze","污泥漿",3,1],
      65=>["overgrow","茂盛",3,1],
      66=>["blaze","猛火",3,1],
      67=>["torrent","激流",3,1],
      68=>["swarm","蟲之預感",3,1],
      69=>["rock-head","堅硬腦袋",3,1],
      70=>["drought","日照",3,1],
      71=>["arena-trap","沙穴",3,1],
      72=>["vital-spirit","幹勁",3,1],
      73=>["white-smoke","白色煙霧",3,1],
      74=>["pure-power","瑜伽之力",3,1],
      75=>["shell-armor","硬殼盔甲",3,1],
      76=>["air-lock","氣閘",3,1],
      77=>["tangled-feet","蹣跚",4,1],
      78=>["motor-drive","電氣引擎",4,1],
      79=>["rivalry","鬥爭心",4,1],
      80=>["steadfast","不屈之心",4,1],
      81=>["snow-cloak","雪隱",4,1],
      82=>["gluttony","貪吃鬼",4,1],
      83=>["anger-point","憤怒穴位",4,1],
      84=>["unburden","輕裝",4,1],
      85=>["heatproof","耐熱",4,1],
      86=>["simple","單純",4,1],
      87=>["dry-skin","乾燥皮膚",4,1],
      88=>["download","下載",4,1],
      89=>["iron-fist","鐵拳",4,1],
      90=>["poison-heal","毒療",4,1],
      91=>["adaptability","適應力",4,1],
      92=>["skill-link","連續攻擊",4,1],
      93=>["hydration","濕潤之軀",4,1],
      94=>["solar-power","太陽之力",4,1],
      95=>["quick-feet","飛毛腿",4,1],
      96=>["normalize","一般皮膚",4,1],
      97=>["sniper","狙擊手",4,1],
      98=>["magic-guard","魔法防守",4,1],
      99=>["no-guard","無防守",4,1],
      100=>["stall","慢出",4,1],
      101=>["technician","技術高手",4,1],
      102=>["leaf-guard","葉子防守",4,1],
      103=>["klutz","笨拙",4,1],
      104=>["mold-breaker","破格",4,1],
      105=>["super-luck","超幸運",4,1],
      106=>["aftermath","引爆",4,1],
      107=>["anticipation","危險預知",4,1],
      108=>["forewarn","預知夢",4,1],
      109=>["unaware","純樸",4,1],
      110=>["tinted-lens","有色眼鏡",4,1],
      111=>["filter","過濾",4,1],
      112=>["slow-start","慢啟動",4,1],
      113=>["scrappy","膽量",4,1],
      114=>["storm-drain","引水",4,1],
      115=>["ice-body","冰凍之軀",4,1],
      116=>["solid-rock","堅硬岩石",4,1],
      117=>["snow-warning","降雪",4,1],
      118=>["honey-gather","採蜜",4,1],
      119=>["frisk","察覺",4,1],
      120=>["reckless","捨身",4,1],
      121=>["multitype","多屬性",4,1],
      122=>["flower-gift","花之禮",4,1],
      123=>["bad-dreams","夢魘",4,1],
      124=>["pickpocket","順手牽羊",5,1],
      125=>["sheer-force","強行",5,1],
      126=>["contrary","唱反調",5,1],
      127=>["unnerve","緊張感",5,1],
      128=>["defiant","不服輸",5,1],
      129=>["defeatist","軟弱",5,1],
      130=>["cursed-body","詛咒之軀",5,1],
      131=>["healer","治癒之心",5,1],
      132=>["friend-guard","友情防守",5,1],
      133=>["weak-armor","碎裂鎧甲",5,1],
      134=>["heavy-metal","重金屬",5,1],
      135=>["light-metal","輕金屬",5,1],
      136=>["multiscale","多重鱗片",5,1],
      137=>["toxic-boost","中毒激升",5,1],
      138=>["flare-boost","受熱激升",5,1],
      139=>["harvest","收穫",5,1],
      140=>["telepathy","心靈感應",5,1],
      141=>["moody","心情不定",5,1],
      142=>["overcoat","防塵",5,1],
      143=>["poison-touch","毒手",5,1],
      144=>["regenerator","再生力",5,1],
      145=>["big-pecks","健壯胸肌",5,1],
      146=>["sand-rush","撥沙",5,1],
      147=>["wonder-skin","奇跡皮膚",5,1],
      148=>["analytic","分析",5,1],
      149=>["illusion","幻覺",5,1],
      150=>["imposter","變身者",5,1],
      151=>["infiltrator","穿透",5,1],
      152=>["mummy","木乃伊",5,1],
      153=>["moxie","自信過度",5,1],
      154=>["justified","正義之心",5,1],
      155=>["rattled","膽怯",5,1],
      156=>["magic-bounce","魔法鏡",5,1],
      157=>["sap-sipper","食草",5,1],
      158=>["prankster","惡作劇之心",5,1],
      159=>["sand-force","沙之力",5,1],
      160=>["iron-barbs","鐵刺",5,1],
      161=>["zen-mode","達摩模式",5,1],
      162=>["victory-star","勝利之星",5,1],
      163=>["turboblaze","渦輪火焰",5,1],
      164=>["teravolt","兆級電壓",5,1],
      165=>["aroma-veil","芳香幕",6,1],
      166=>["flower-veil","花幕",6,1],
      167=>["cheek-pouch","頰囊",6,1],
      168=>["protean","變幻自如",6,1],
      169=>["fur-coat","毛皮大衣",6,1],
      170=>["magician","魔術師",6,1],
      171=>["bulletproof","防彈",6,1],
      172=>["competitive","好勝",6,1],
      173=>["strong-jaw","強壯之顎",6,1],
      174=>["refrigerate","冰凍皮膚",6,1],
      175=>["sweet-veil","甜幕",6,1],
      176=>["stance-change","戰鬥切換",6,1],
      177=>["gale-wings","疾風之翼",6,1],
      178=>["mega-launcher","超級發射器",6,1],
      179=>["grass-pelt","草之毛皮",6,1],
      180=>["symbiosis","共生",6,1],
      181=>["tough-claws","硬爪",6,1],
      182=>["pixilate","妖精皮膚",6,1],
      183=>["gooey","黏滑",6,1],
      184=>["aerilate","飛行皮膚",6,1],
      185=>["parental-bond","親子愛",6,1],
      186=>["dark-aura","暗黑氣場",6,1],
      187=>["fairy-aura","妖精氣場",6,1],
      188=>["aura-break","氣場破壞",6,1],
      189=>["primordial-sea","始源之海",6,1],
      190=>["desolate-land","終結之地",6,1],
      191=>["delta-stream","德爾塔氣流",6,1],
      192=>["stamina","持久力",7,1],
      193=>["wimp-out","躍躍欲逃",7,1],
      194=>["emergency-exit","危險迴避",7,1],
      195=>["water-compaction","遇水凝固",7,1],
      196=>["merciless","不仁不義",7,1],
      197=>["shields-down","界限盾殼",7,1],
      198=>["stakeout","監視",7,1],
      199=>["water-bubble","水泡",7,1],
      200=>["steelworker","鋼能力者",7,1],
      201=>["berserk","怒火沖天",7,1],
      202=>["slush-rush","撥雪",7,1],
      203=>["long-reach","遠隔",7,1],
      204=>["liquid-voice","濕潤之聲",7,1],
      205=>["triage","先行治療",7,1],
      206=>["galvanize","電氣皮膚",7,1],
      207=>["surge-surfer","衝浪之尾",7,1],
      208=>["schooling","魚群",7,1],
      209=>["disguise","畫皮",7,1],
      210=>["battle-bond","牽絆變身",7,1],
      211=>["power-construct","群聚變形",7,1],
      212=>["corrosion","腐蝕",7,1],
      213=>["comatose","絕對睡眠",7,1],
      214=>["queenly-majesty","女王的威嚴",7,1],
      215=>["innards-out","飛出的內在物",7,1],
      216=>["dancer","舞者",7,1],
      217=>["battery","蓄電池",7,1],
      218=>["fluffy","毛茸茸",7,1],
      219=>["dazzling","鮮艷之軀",7,1],
      220=>["soul-heart","魂心",7,1],
      221=>["tangling-hair","捲髮",7,1],
      222=>["receiver","接球手",7,1],
      223=>["power-of-alchemy","化學之力",7,1],
      224=>["beast-boost","異獸提升",7,1],
      225=>["rks-system","ＡＲ系統",7,1],
      226=>["electric-surge","電氣製造者",7,1],
      227=>["psychic-surge","精神製造者",7,1],
      228=>["misty-surge","薄霧製造者",7,1],
      229=>["grassy-surge","青草製造者",7,1],
      230=>["full-metal-body","金屬防護",7,1],
      231=>["shadow-shield","幻影防守",7,1],
      232=>["prism-armor","稜鏡裝甲",7,1],
      233=>["neuroforce","腦核之力",7,1],
      234=>["intrepid-sword","不撓之劍",8,1],
      235=>["dauntless-shield","不屈之盾",8,1],
      236=>["libero","自由者",8,1],
      237=>["ball-fetch","撿球",8,1],
      238=>["cotton-down","棉絮",8,1],
      239=>["propeller-tail","螺旋尾鰭",8,1],
      240=>["mirror-armor","鏡甲",8,1],
      241=>["gulp-missile","一口飛彈",8,1],
      242=>["stalwart","堅毅",8,1],
      243=>["steam-engine","蒸汽機",8,1],
      244=>["punk-rock","龐克搖滾",8,1],
      245=>["sand-spit","吐沙",8,1],
      246=>["ice-scales","冰鱗粉",8,1],
      247=>["ripen","熟成",8,1],
      248=>["ice-face","結凍頭",8,1],
      249=>["power-spot","能量點",8,1],
      250=>["mimicry","擬態",8,1],
      251=>["screen-cleaner","除障",8,1],
      252=>["steely-spirit","鋼之意志",8,1],
      253=>["perish-body","滅亡之軀",8,1],
      254=>["wandering-spirit","遊魂",8,1],
      255=>["gorilla-tactics","一猩一意",8,1],
      256=>["neutralizing-gas","化學變化氣體",8,1],
      257=>["pastel-veil","粉彩護幕",8,1],
      258=>["hunger-switch","飽了又餓",8,1],
      259=>["quick-draw","速擊",8,1],
      260=>["unseen-fist","無形拳",8,1],
      261=>["curious-medicine","怪藥",8,1],
      262=>["transistor","電晶體",8,1],
      263=>["dragons-maw","龍顎",8,1],
      264=>["chilling-neigh","蒼白嘶鳴",8,1],
      265=>["grim-neigh","漆黑嘶鳴",8,1],
      266=>["as-one-glastrier","人馬一體",8,1],
      267=>["as-one-spectrier","人馬一體",8,1],
      268=>["lingering-aroma","甩不掉的氣味",9,1],
      269=>["seed-sower","掉出種子",9,1],
      270=>["thermal-exchange","熱交換",9,1],
      271=>["anger-shell","憤怒甲殼",9,1],
      272=>["purifying-salt","潔淨之鹽",9,1],
      273=>["well-baked-body","焦香之軀",9,1],
      274=>["wind-rider","乘風",9,1],
      275=>["guard-dog","看門犬",9,1],
      276=>["rocky-payload","搬岩",9,1],
      277=>["wind-power","風力發電",9,1],
      278=>["zero-to-hero","全能變身",9,1],
      279=>["commander","發號施令",9,1],
      280=>["electromorphosis","電力轉換",9,1],
      281=>["protosynthesis","古代活性",9,1],
      282=>["quark-drive","夸克充能",9,1],
      283=>["good-as-gold","黃金之軀",9,1],
      284=>["vessel-of-ruin","災禍之鼎",9,1],
      285=>["sword-of-ruin","災禍之劍",9,1],
      286=>["tablets-of-ruin","災禍之簡",9,1],
      287=>["beads-of-ruin","災禍之玉",9,1],
      288=>["orichalcum-pulse","緋紅脈動",9,1],
      289=>["hadron-engine","強子引擎",9,1],
      290=>["opportunist","跟風",9,1],
      291=>["cud-chew","反芻",9,1],
      292=>["sharpness","鋒銳",9,1],
      293=>["supreme-overlord","大將",9,1],
      294=>["costar","同台共演",9,1],
      295=>["toxic-debris","毒滿地",9,1],
      296=>["armor-tail","尾甲",9,1],
      297=>["earth-eater","食土",9,1],
      298=>["mycelium-might","菌絲之力",9,1],
      299=>["minds-eye","心眼",9,1],
      300=>["supersweet-syrup","甘露之蜜",9,1],
      301=>["hospitality","款待",9,1],
      302=>["toxic-chain","毒鎖鏈",9,1],
      303=>["embody-aspect","面影輝映",9,1],
      304=>["tera-shift","太晶變形",9,1],
      305=>["tera-shell","太晶甲殼",9,1],
      306=>["teraform-zero","歸零化境",9,1],
      307=>["poison-puppeteer","毒傀儡",9,1],
      308=>["piercing-drill","貫穿鑽",9,1],
      309=>["dragonize","龍皮膚",9,1],
      310=>["mega-sol","超級日光",9,1],
      311=>["spicy-spray","辣椒噴發",9,1],
      312=>["eelevate","eelevate",9,1],
      313=>["fire-mane","fire-mane",9,1],
      10001=>["mountaineer","mountaineer",5,0],
      10002=>["wave-rider","wave-rider",5,0],
      10003=>["skater","skater",5,0],
      10004=>["thrust","thrust",5,0],
      10005=>["perception","perception",5,0],
      10006=>["parry","parry",5,0],
      10007=>["instinct","instinct",5,0],
      10008=>["dodge","dodge",5,0],
      10009=>["jagged-edge","jagged-edge",5,0],
      10010=>["frostbite","frostbite",5,0],
      10011=>["tenacity","tenacity",5,0],
      10012=>["pride","pride",5,0],
      10013=>["deep-sleep","deep-sleep",5,0],
      10014=>["power-nap","power-nap",5,0],
      10015=>["spirit","spirit",5,0],
      10016=>["warm-blanket","warm-blanket",5,0],
      10017=>["gulp","gulp",5,0],
      10018=>["herbivore","herbivore",5,0],
      10019=>["sandpit","sandpit",5,0],
      10020=>["hot-blooded","hot-blooded",5,0],
      10021=>["medic","medic",5,0],
      10022=>["life-force","life-force",5,0],
      10023=>["lunchbox","lunchbox",5,0],
      10024=>["nurse","nurse",5,0],
      10025=>["melee","melee",5,0],
      10026=>["sponge","sponge",5,0],
      10027=>["bodyguard","bodyguard",5,0],
      10028=>["hero","hero",5,0],
      10029=>["last-bastion","last-bastion",5,0],
      10030=>["stealth","stealth",5,0],
      10031=>["vanguard","vanguard",5,0],
      10032=>["nomad","nomad",5,0],
      10033=>["sequence","sequence",5,0],
      10034=>["grass-cloak","grass-cloak",5,0],
      10035=>["celebrate","celebrate",5,0],
      10036=>["lullaby","lullaby",5,0],
      10037=>["calming","calming",5,0],
      10038=>["daze","daze",5,0],
      10039=>["frighten","frighten",5,0],
      10040=>["interference","interference",5,0],
      10041=>["mood-maker","mood-maker",5,0],
      10042=>["confidence","confidence",5,0],
      10043=>["fortune","fortune",5,0],
      10044=>["bonanza","bonanza",5,0],
      10045=>["explode","explode",5,0],
      10046=>["omnipotent","omnipotent",5,0],
      10047=>["share","share",5,0],
      10048=>["black-hole","black-hole",5,0],
      10049=>["shadow-dash","shadow-dash",5,0],
      10050=>["sprint","sprint",5,0],
      10051=>["disgust","disgust",5,0],
      10052=>["high-rise","high-rise",5,0],
      10053=>["climber","climber",5,0],
      10054=>["flame-boost","flame-boost",5,0],
      10055=>["aqua-boost","aqua-boost",5,0],
      10056=>["run-up","run-up",5,0],
      10057=>["conqueror","conqueror",5,0],
      10058=>["shackle","shackle",5,0],
      10059=>["decoy","decoy",5,0],
      10060=>["shield","shield",5,0],
    }

    #--------------------------------------------------------------------------
    # ● F10 Master Scenario
    #--------------------------------------------------------------------------
    # :moves 使用「原作 Move ID」，不是 RPG Maker Skill ID。
    # Ability 效果於 v2.4 完成，目前會保存／顯示／寫 LOG，供指定情境測試。
    TEST_HUMAN_LEVEL = 50
    TEST_ALLIES = [
      {:dex=>150, :level=>50, :ability=>46, :moves=>[94,247,396,58]}, # 超夢
      {:dex=>445, :level=>50, :ability=>8,  :moves=>[89,242,337,407]}, # 烈咬陸鯊
      {:dex=>448, :level=>50, :ability=>39, :moves=>[396,399,245,406]}, # 路卡利歐
    ]
    TEST_ENEMIES = [
      {:dex=>143, :level=>50, :ability=>47,  :moves=>[34,242,89,280]}, # 卡比獸
      {:dex=>94,  :level=>50, :ability=>130, :moves=>[94,247,85,188]}, # 耿鬼
      {:dex=>248, :level=>50, :ability=>45,  :moves=>[44,89,242,444]}, # 班基拉斯
      {:dex=>376, :level=>50, :ability=>29,  :moves=>[232,94,89,418]}, # 巨金怪
    ]

    #--------------------------------------------------------------------------
    # ● 基本查詢 API
    #--------------------------------------------------------------------------
    def self.entry(dex)
      return SPECIES[dex.to_i]
    end

    def self.name_for_dex(dex)
      row = entry(dex)
      return row == nil ? "未知" : row[0].to_s
    end

    def self.identifier_for_dex(dex)
      row = entry(dex)
      return row == nil ? "" : row[1].to_s
    end

    def self.types_for_dex(dex)
      row = entry(dex)
      return row == nil ? [] : row[2].clone
    end

    def self.base_stats_for_dex(dex)
      row = entry(dex)
      return row == nil ? nil : row[3].clone
    end

    def self.root_dex(dex)
      row = entry(dex)
      return row == nil ? 0 : row[4].to_i
    end

    def self.stage_depth(dex)
      row = entry(dex)
      return row == nil ? 0 : row[5].to_i
    end

    def self.gender_rate(dex)
      row = entry(dex)
      return row == nil ? -1 : row[6].to_i
    end

    def self.capture_rate(dex)
      row = entry(dex)
      return row == nil ? 0 : row[7].to_i
    end

    def self.growth_rate(dex)
      row = entry(dex)
      return row == nil ? 0 : row[8].to_i
    end

    def self.flags(dex)
      row = entry(dex)
      return row == nil ? 0 : row[9].to_i
    end

    def self.baby?(dex); return (flags(dex) & 1) != 0; end
    def self.legendary?(dex); return (flags(dex) & 2) != 0; end
    def self.mythical?(dex); return (flags(dex) & 4) != 0; end

    def self.egg_groups(dex)
      row = entry(dex)
      return row == nil ? [] : row[10].clone
    end

    def self.ability_pool(dex)
      row = entry(dex)
      return row == nil ? [] : row[11].clone
    end

    def self.hidden_ability_pool(dex)
      row = entry(dex)
      return row == nil ? [] : row[12].clone
    end

    def self.nature_bias(dex)
      row = entry(dex)
      return row == nil ? [0,6,12,18,24] : row[13].clone
    end

    def self.ai_profile(dex)
      row = entry(dex)
      return row == nil ? [:mixed,:balanced,3,:hybrid] : row[14].clone
    end

    def self.base_experience(dex)
      row = entry(dex)
      return row == nil ? 0 : row[15].to_i
    end

    def self.level_learnset(dex)
      value = LEVEL_LEARNSETS[dex.to_i]
      return value == nil ? [] : value
    end

    def self.move_pool(dex)
      value = MOVE_POOLS[dex.to_i]
      return value == nil ? [] : value
    end

    def self.move(move_id)
      return MOVE_CATALOG[move_id.to_i]
    end

    def self.move_name(move_id)
      row = move(move_id)
      return row == nil ? "未知技能" : row[1].to_s
    end

    def self.ability(ability_id)
      return ABILITY_CATALOG[ability_id.to_i]
    end

    def self.ability_name(ability_id)
      row = ability(ability_id)
      return row == nil ? "未知特性" : row[1].to_s
    end

    def self.actor_id_for_dex(dex)
      dex = dex.to_i
      return 0 unless SPECIES.has_key?(dex)
      return dex + ACTOR_OFFSET
    end

    def self.enemy_id_for_dex(dex)
      dex = dex.to_i
      return 0 unless SPECIES.has_key?(dex)
      return dex + ENEMY_OFFSET
    end

    def self.dex_for_actor_id(actor_id)
      dex = actor_id.to_i - ACTOR_OFFSET
      return SPECIES.has_key?(dex) ? dex : 0
    end

    def self.dex_for_enemy_id(enemy_id)
      dex = enemy_id.to_i - ENEMY_OFFSET
      return SPECIES.has_key?(dex) ? dex : 0
    end

    def self.skill_id_for_move(move_id)
      id = move_id.to_i
      return 0 unless MOVE_CATALOG.has_key?(id)
      return MOVE_SKILL_OFFSET + id
    end

    def self.move_id_for_skill(skill_id)
      id = skill_id.to_i - MOVE_SKILL_OFFSET
      return MOVE_CATALOG.has_key?(id) ? id : 0
    end

    #--------------------------------------------------------------------------
    # ● PMD fallback
    #--------------------------------------------------------------------------
    def self.direct_pmd_key(dex)
      return sprintf("%04d", dex.to_i)
    end

    def self.pmd_directory_exists?(dex)
      return false unless defined?(CG_PMD)
      key = direct_pmd_key(dex)
      return FileTest.directory?(CG_PMD::ROOT + key)
    rescue
      return false
    end

    def self.fallback_pmd_dex(dex)
      dex = dex.to_i
      return 1 if dex <= 0
      return ((dex - 1) % FALLBACK_PMD_COUNT) + 1
    end

    def self.pmd_dex_for(dex)
      dex = dex.to_i
      return dex if pmd_directory_exists?(dex)
      return fallback_pmd_dex(dex)
    end

    def self.pmd_key_for_dex(dex)
      return sprintf("%04d", pmd_dex_for(dex))
    end

    #--------------------------------------------------------------------------
    # ● Nature / Gender
    #--------------------------------------------------------------------------
    def self.random_nature_for_dex(dex)
      list = nature_bias(dex)
      list = [0,6,12,18,24] if list == nil || list.empty?
      # 70% 取物種偏好，30% 保留全 25 Nature 的個體差異。
      return list[rand(list.size)].to_i if rand(100) < 70
      return rand(25)
    end

    def self.male_rate_per_thousand(dex)
      rate = gender_rate(dex)
      return :genderless if rate < 0
      # PokeAPI gender_rate = female eighths: 0=全雄、8=全雌。
      male = (8 - rate) * 1000 / 8
      male = 0 if male < 0
      male = 1000 if male > 1000
      return male
    end

    #--------------------------------------------------------------------------
    # ● AI / Motion Hint
    #--------------------------------------------------------------------------
    def self.move_motion_hint(move_id)
      row = move(move_id)
      return :charge if row == nil
      identifier = row[0].to_s
      damage_class = row[7]
      target_id = row[8].to_i

      if damage_class == :status
        # user / user's field / allies / whole-field 類先用姿勢技；
        # 對敵狀態技先以 Shoot 表示，v2.3 再逐招特調。
        return :pose if [7,12,13,15,16].include?(target_id)
        return :shoot
      end

      return :shoot if damage_class == :special

      # 物理但明顯屬於投射／全場震擊者，不讓使用者整隻貼到目標身上。
      stationary = [
        "earthquake","magnitude","bulldoze","razor-leaf","rock-throw",
        "rock-slide","rock-blast","seed-bomb","bullet-seed","pin-missile",
        "bone-club","bonemerang","ice-shard","spike-cannon","egg-bomb",
        "fissure","precipice-blades","stone-edge"
      ]
      return :stationary_attack if stationary.include?(identifier)
      return :stationary_attack if [9,11,12,14].include?(target_id)
      return :melee_attack
    end

    #--------------------------------------------------------------------------
    # ● 進化
    #--------------------------------------------------------------------------
    def self.evolution_options(dex)
      value = EVOLUTION_OPTIONS[dex.to_i]
      return value == nil ? [] : value
    end

    def self.minimum_evolution_level(dex)
      list = evolution_options(dex)
      return 0 if list.empty?
      result = list[0][1].to_i
      for row in list
        result = row[1].to_i if row[1].to_i < result
      end
      return result
    end

    def self.gender_matches_option?(actor, option)
      cond = option[3] || {}
      gender_id = cond[:gender_id]
      return true if gender_id == nil || gender_id.to_i <= 0
      return true unless actor.respond_to?(:cg_gender)
      gender = actor.cg_gender
      return gender == :female if gender_id.to_i == 1
      return gender == :male if gender_id.to_i == 2
      return true
    rescue
      return true
    end

    def self.eligible_evolution_options(actor)
      return [] if actor == nil || !actor.respond_to?(:cg_national_dex)
      dex = actor.cg_national_dex.to_i
      result = []
      for row in evolution_options(dex)
        next if actor.level.to_i < row[1].to_i
        next unless gender_matches_option?(actor, row)
        result.push(row)
      end
      return result
    end

    def self.choose_evolution_for(actor)
      list = eligible_evolution_options(actor)
      return nil if list.empty?
      choices = actor.instance_variable_get(:@cg_master_evolution_choices)
      choices = {} if choices == nil
      dex = actor.cg_national_dex.to_i
      target = choices[dex]
      valid = list.collect { |row| row[0].to_i }
      unless valid.include?(target.to_i)
        target = valid[rand(valid.size)]
        choices[dex] = target.to_i
        actor.instance_variable_set(:@cg_master_evolution_choices, choices)
      end
      for row in list
        return row if row[0].to_i == target.to_i
      end
      return list[0]
    end

    #--------------------------------------------------------------------------
    # ● 資料庫物件建置
    #--------------------------------------------------------------------------
    def self.ensure_index(array, index)
      array.push(nil) while array.size <= index
    end

    def self.install_species26_compatibility
      return unless defined?(ALBERT_CG::SPECIES26)
      for dex in 1..MAX_DEX
        row = SPECIES[dex]
        ALBERT_CG::SPECIES26::REGISTRY[dex] =
          [row[0], row[2].clone, row[3].clone, row[4].to_i]
      end

      ALBERT_CG::SPECIES26::LINEAGES.clear
      LINEAGES.each do |root, forms|
        ALBERT_CG::SPECIES26::LINEAGES[root] = forms.clone
      end

      # 既有前三世代測試 Class 保留；新系譜統一使用 Generic Pokémon Class。
      for root in LINEAGES.keys
        unless ALBERT_CG::SPECIES26::LINE_CLASS.has_key?(root)
          ALBERT_CG::SPECIES26::LINE_CLASS[root] = GENERIC_CLASS_ID
        end
      end
      ALBERT_CG::SPECIES26::CLASS_SKILLS[GENERIC_CLASS_ID] = []

      ALBERT_CG::SPECIES26::EVOLUTION_LEVEL.clear
      EVOLUTION_OPTIONS.each do |from_dex, opts|
        next if opts == nil || opts.empty?
        row = opts[0]
        ALBERT_CG::SPECIES26::EVOLUTION_LEVEL[from_dex] =
          [row[0].to_i, row[1].to_i]
      end
    end

    def self.make_generic_class
      klass = RPG::Class.new
      klass.id = GENERIC_CLASS_ID
      klass.name = "Pokémon"
      klass.position = 1
      klass.weapon_set = []
      klass.armor_set = []
      if defined?(ALBERT_CG::SPECIES26)
        klass.element_ranks = ALBERT_CG::SPECIES26.fill_rank_table($data_system.elements.size, 3)
        klass.state_ranks = ALBERT_CG::SPECIES26.fill_rank_table($data_states.size, 3)
      end
      klass.learnings = []
      klass.skill_name_valid = true
      klass.skill_name = "技能"
      return klass
    end

    def self.install_actor_enemy_database
      return unless defined?(ALBERT_CG::SPECIES26)
      ensure_index($data_classes, GENERIC_CLASS_ID)
      $data_classes[GENERIC_CLASS_ID] = make_generic_class

      for dex in 1..MAX_DEX
        actor_id = actor_id_for_dex(dex)
        enemy_id = enemy_id_for_dex(dex)
        ensure_index($data_actors, actor_id)
        ensure_index($data_enemies, enemy_id)
        $data_actors[actor_id] = ALBERT_CG::SPECIES26.make_actor(dex)
        $data_enemies[enemy_id] = ALBERT_CG::SPECIES26.make_enemy(dex)
        $data_enemies[enemy_id].exp = [base_experience(dex), 1].max
        $data_enemies[enemy_id].gold = [dex / 2 + 5, 5].max
      end
    end

    def self.stub_mp_cost(move_row)
      power = move_row[3].to_i
      pp = move_row[4].to_i
      cost = if power <= 0
        6
      elsif power <= 40
        4
      elsif power <= 60
        6
      elsif power <= 80
        8
      elsif power <= 100
        10
      else
        12
      end
      cost += 4 if pp > 0 && pp <= 5
      cost += 2 if pp > 5 && pp <= 10
      return cost
    end

    def self.stub_scope(move_row)
      target_id = move_row[8].to_i
      return 11 if target_id == 7
      return 8 if [13,15,16].include?(target_id)
      return 2 if [9,11].include?(target_id)
      return 1
    end

    def self.make_move_stub(move_id)
      row = move(move_id)
      skill = RPG::Skill.new
      skill.id = skill_id_for_move(move_id)
      skill.name = row[1].to_s
      skill.icon_index = 0
      skill.description = "Pokémon Move v2.2 測試 Stub；正式效果於 v2.3 完成。"
      skill.scope = stub_scope(row)
      skill.occasion = 1
      skill.speed = row[6].to_i
      skill.animation_id = PLACEHOLDER_ANIMATION_ID
      skill.common_event_id = 0
      skill.base_damage = row[3].to_i > 0 ? 1 : 0
      skill.variance = 10
      skill.atk_f = row[7] == :physical ? 100 : 0
      skill.spi_f = row[7] == :special ? 100 : 0
      skill.hit = row[5].to_i <= 0 ? 100 : row[5].to_i
      skill.physical_attack = row[7] == :physical
      skill.damage_to_mp = false
      skill.absorb_damage = false
      skill.ignore_defense = false
      skill.mp_cost = stub_mp_cost(row)
      type_id = 0
      if defined?(ALBERT_CG::POKEMON_COMBAT)
        type_id = ALBERT_CG::POKEMON_COMBAT.type_id(row[2])
      end
      skill.element_set = type_id.to_i <= 0 ? [] : [type_id.to_i]
      skill.plus_state_set = []
      skill.minus_state_set = []
      skill.message1 = "使用了" + skill.name + "！"
      skill.message2 = ""
      motion = move_motion_hint(move_id)
      skill.note = "<pmd_motion: " + motion.to_s + ">\n" +
                   "<pokemon_master_move: " + move_id.to_i.to_s + ">"
      return skill
    end

    def self.install_move_stubs
      return if $data_skills == nil
      MOVE_CATALOG.keys.sort.each do |move_id|
        skill_id = skill_id_for_move(move_id)
        ensure_index($data_skills, skill_id)
        $data_skills[skill_id] = make_move_stub(move_id)
        if defined?(ALBERT_CG::POKEMON_COMBAT_DATA)
          row = MOVE_CATALOG[move_id]
          type = row[2]
          type = :normal unless ALBERT_CG::POKEMON_COMBAT::TYPE_IDS.has_key?(type)
          ALBERT_CG::POKEMON_COMBAT_DATA::SKILL_COMBAT_TABLE[skill_id] =
            {:type=>type, :power=>row[3].to_i, :class=>row[7]}
        end
      end
    end

    def self.install_pmd_tables
      return unless defined?(CG_PMD)
      for dex in 1..MAX_DEX
        actor_id = actor_id_for_dex(dex)
        enemy_id = enemy_id_for_dex(dex)
        CG_PMD::SPECIES_SPRITES[actor_id] = pmd_key_for_dex(dex)
        CG_PMD::ENEMY_SPECIES[enemy_id] = actor_id
      end
    end

    def self.install_combat_tables
      return unless defined?(ALBERT_CG::POKEMON_COMBAT_DATA)
      data = ALBERT_CG::POKEMON_COMBAT_DATA
      for dex in 1..MAX_DEX
        actor_id = actor_id_for_dex(dex)
        enemy_id = enemy_id_for_dex(dex)
        data::FORM_TYPE_TABLE[actor_id] = types_for_dex(dex)
        data::ENEMY_FORM_TABLE[enemy_id] = actor_id
        data::ENEMY_LEVEL_TABLE[enemy_id] = 5
      end
    end

    def self.install_evolution_tables
      return unless defined?(ALBERT_CG::EVOLUTION_RULES)
      ALBERT_CG::EVOLUTION_RULES.clear
      EVOLUTION_OPTIONS.each do |from_dex, opts|
        next if opts == nil || opts.empty?
        row = opts[0]
        ALBERT_CG::EVOLUTION_RULES[actor_id_for_dex(from_dex)] =
          {:to=>actor_id_for_dex(row[0]), :level=>row[1].to_i}
      end

      if defined?(ALBERT_CG::EVOLUTION_LINEAGES)
        ALBERT_CG::EVOLUTION_LINEAGES.clear
        LINEAGES.each do |root, dex_list|
          forms = dex_list.collect { |dex| actor_id_for_dex(dex) }
          ALBERT_CG::EVOLUTION_LINEAGES[actor_id_for_dex(root)] = forms
        end
      end
    end

    def self.apply
      return false if $data_actors == nil || $data_enemies == nil
      install_species26_compatibility
      install_actor_enemy_database
      install_move_stubs
      install_pmd_tables
      install_combat_tables
      install_evolution_tables
      $data_system.game_title = "CG Pet Battle Prototype v2.2.0 Pokemon 0001-0494 Master"
      write_log
      return true
    end

    #--------------------------------------------------------------------------
    # ● LOG
    #--------------------------------------------------------------------------
    def self.write_log
      begin
        File.open(LOG_FILE, "wb") do |file|
          file.write("CG POKEMON MASTER DATA v" + VERSION + "\r\n")
          file.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
          file.write("SOURCE=" + DATA_SOURCE + "\r\n")
          file.write("SPECIES=" + SPECIES.size.to_s + "/494 MOVES=" +
            MOVE_CATALOG.size.to_s + " ABILITIES=" + ABILITY_CATALOG.size.to_s + "\r\n")
          level_ok = 0
          pool_ok = 0
          for dex in 1..MAX_DEX
            level_ok += 1 unless level_learnset(dex).empty?
            pool_ok += 1 unless move_pool(dex).empty?
          end
          file.write("LEARNSET_USUM=" + level_ok.to_s + "/494 MOVE_POOL_USUM=" +
            pool_ok.to_s + "/494\r\n")
          file.write("EVOLUTION_SOURCES=" + EVOLUTION_OPTIONS.size.to_s +
            " BONUS_SOURCES=" + BONUS_EVOLUTION.size.to_s +
            " LINE_ROOTS=" + LINEAGES.size.to_s + "\r\n")
          real = 0
          fallback = 0
          for dex in 1..MAX_DEX
            if pmd_dex_for(dex) == dex
              real += 1
            else
              fallback += 1
            end
          end
          file.write("PMD_REAL=" + real.to_s + " PMD_FALLBACK=" + fallback.to_s + "\r\n")
          actors_ok = 0
          enemies_ok = 0
          for dex in 1..MAX_DEX
            a = $data_actors[actor_id_for_dex(dex)]
            e = $data_enemies[enemy_id_for_dex(dex)]
            actors_ok += 1 if a != nil && a.name.to_s == name_for_dex(dex)
            enemies_ok += 1 if e != nil && e.name.to_s == name_for_dex(dex)
          end
          file.write("RUNTIME_ACTORS=" + actors_ok.to_s + "/494 RUNTIME_ENEMIES=" +
            enemies_ok.to_s + "/494\r\n")
          [1,25,150,445,494].each do |dex|
            file.write(sprintf("SAMPLE #%04d %s types=%s stats=%s abilities=%s hidden=%s pmd=%s ai=%s\r\n",
              dex, name_for_dex(dex), types_for_dex(dex).inspect,
              base_stats_for_dex(dex).inspect, ability_pool(dex).inspect,
              hidden_ability_pool(dex).inspect, pmd_key_for_dex(dex),
              ai_profile(dex).inspect))
          end
          pass = SPECIES.size == 494 && level_ok == 494 && pool_ok == 494 &&
                 actors_ok == 494 && enemies_ok == 494
          file.write("RESULT=" + (pass ? "PASS" : "CHECK") + "\r\n")
        end
      rescue => error
      end
    end

    def self.reset_test_log
      begin
        File.open(TEST_LOG_FILE, "wb") do |file|
          file.write("CG POKEMON MASTER TEST v" + VERSION + "\r\n")
          file.write("START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S") + "\r\n")
          file.write("------------------------------------------------------------\r\n")
        end
      rescue
      end
    end

    def self.test_log(text)
      begin
        File.open(TEST_LOG_FILE, "ab") do |file|
          file.write("[" + Time.now.strftime("%H:%M:%S") + "] " + text.to_s + "\r\n")
        end
      rescue
      end
    end

    #--------------------------------------------------------------------------
    # ● F10 Master Scenario
    #--------------------------------------------------------------------------
    def self.configure_actor(actor, cfg)
      return if actor == nil
      level = cfg[:level].to_i
      actor.change_level(level, false) if actor.respond_to?(:change_level)
      # Direct Actor 只作 Debug，可清掉 Runtime 已學技能後重新指定。
      if actor.respond_to?(:skills) && actor.respond_to?(:forget_skill)
        old = actor.skills.collect { |skill| skill.id }
        old.each { |id| actor.forget_skill(id) }
      end
      for move_id in (cfg[:moves] || [])
        skill_id = skill_id_for_move(move_id)
        actor.learn_skill(skill_id) if skill_id > 0 && actor.respond_to?(:learn_skill)
      end
      actor.instance_variable_set(:@cg_master_ability_id, cfg[:ability].to_i)
      actor.recover_all if actor.respond_to?(:recover_all)
      test_log("ALLY dex=" + sprintf("%04d", actor.cg_national_dex.to_i) +
        " name=" + actor.name.to_s + " lv=" + actor.level.to_i.to_s +
        " ability=" + ability_name(cfg[:ability]) + "(" + cfg[:ability].to_i.to_s + ")" +
        " moves=" + (cfg[:moves] || []).collect { |id| move_name(id) }.inspect +
        " pmd=" + (actor.respond_to?(:cg_pmd_sprite_key) ? actor.cg_pmd_sprite_key.to_s : ""))
    end

    def self.configure_enemy_data(cfg)
      dex = cfg[:dex].to_i
      enemy_id = enemy_id_for_dex(dex)
      enemy = $data_enemies[enemy_id]
      return if enemy == nil
      actions = []
      for move_id in (cfg[:moves] || [])
        skill_id = skill_id_for_move(move_id)
        next if skill_id <= 0
        actions.push(ALBERT_CG::SPECIES26.make_enemy_action(1, skill_id, 7))
      end
      actions.push(ALBERT_CG::SPECIES26.make_enemy_action(0, 0, 5)) if actions.empty?
      enemy.actions = actions
      if defined?(ALBERT_CG::POKEMON_COMBAT_DATA)
        ALBERT_CG::POKEMON_COMBAT_DATA::ENEMY_LEVEL_TABLE[enemy_id] = cfg[:level].to_i
      end
      enemy.note = enemy.note.to_s + "\n<master_ability: " + cfg[:ability].to_i.to_s + ">"
      test_log("ENEMY dex=" + sprintf("%04d", dex) +
        " name=" + name_for_dex(dex) + " lv=" + cfg[:level].to_i.to_s +
        " ability=" + ability_name(cfg[:ability]) + "(" + cfg[:ability].to_i.to_s + ")" +
        " moves=" + (cfg[:moves] || []).collect { |id| move_name(id) }.inspect +
        " pmd=" + pmd_key_for_dex(dex))
    end

    def self.make_test_troop
      ensure_index($data_troops, TEST_TROOP_ID)
      xs = [ALBERT_CG::ENEMY_FRONT_X, ALBERT_CG::ENEMY_FRONT_X,
            ALBERT_CG::ENEMY_BACK_X, ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[2],
            ALBERT_CG::GRID_COLUMN_Y[0], ALBERT_CG::GRID_COLUMN_Y[2]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg, i|
        configure_enemy_data(cfg)
        members.push(ALBERT_CG::SPECIES26.make_troop_member(
          enemy_id_for_dex(cfg[:dex]), xs[i] || 180, ys[i] || 220))
      end
      $data_troops[TEST_TROOP_ID] =
        ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,
          "Pokemon Master 0001-0494 Scenario", members)
    end

    def self.prepare_test_party
      return false if $game_party == nil
      ids = TEST_ALLIES.collect { |cfg| actor_id_for_dex(cfg[:dex]) }
      if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
        ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids)
      end
      # 防止 DirectParty bootstrap 把 Scenario 寵物全部重設回 Lv5。
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized, true)
      $game_party.cg_enable_direct_pmd_test_party! if
        $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each do |cfg|
        configure_actor($game_actors[actor_id_for_dex(cfg[:dex])], cfg)
      end
      human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if human != nil
        human.change_level(TEST_HUMAN_LEVEL, false)
        human.recover_all if human.respond_to?(:recover_all)
      end
      return true
    end

    def self.start_master_test
      reset_test_log
      prepare_test_party
      make_test_troop
      @master_test_active = true
      test_log("START troop=" + TEST_TROOP_ID.to_s)
      return ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
    end

    def self.master_test_active?
      return @master_test_active == true
    end

    # Win32 F10 自己讀，不重新啟用舊進化 UI。
    def self.f10_trigger?
      return false unless defined?(ALBERT_CG::CG_GET_ASYNC_KEY_STATE_F10)
      api = ALBERT_CG::CG_GET_ASYNC_KEY_STATE_F10
      return false if api == nil
      down = (api.call(ALBERT_CG::CG_VK_F10) & 0x8000) != 0
      trigger = down && @f10_down != true
      @f10_down = down
      return trigger
    rescue
      return false
    end
  end
end

#==============================================================================
# ■ 舊 Species26 API 延伸為 0001～0494
#==============================================================================
module ALBERT_CG
  module SPECIES26
    class << self
      def actor_id_for_dex(dex)
        return ALBERT_CG::POKEMON_MASTER.actor_id_for_dex(dex)
      end
      def enemy_id_for_dex(dex)
        return ALBERT_CG::POKEMON_MASTER.enemy_id_for_dex(dex)
      end
      def dex_for_actor_id(actor_id)
        return ALBERT_CG::POKEMON_MASTER.dex_for_actor_id(actor_id)
      end
      def dex_for_enemy_id(enemy_id)
        return ALBERT_CG::POKEMON_MASTER.dex_for_enemy_id(enemy_id)
      end
      def pmd_key_for_dex(dex)
        return ALBERT_CG::POKEMON_MASTER.pmd_key_for_dex(dex)
      end
      def entry_by_dex(dex)
        row = ALBERT_CG::POKEMON_MASTER.entry(dex)
        return nil if row == nil
        return [row[0], row[2].clone, row[3].clone, row[4].to_i]
      end
      def name_for_dex(dex)
        return ALBERT_CG::POKEMON_MASTER.name_for_dex(dex)
      end
      def types_for_dex(dex)
        return ALBERT_CG::POKEMON_MASTER.types_for_dex(dex)
      end
      def base_stats_for_dex(dex)
        return ALBERT_CG::POKEMON_MASTER.base_stats_for_dex(dex)
      end
      def line_base_dex(dex)
        return ALBERT_CG::POKEMON_MASTER.root_dex(dex)
      end
    end
  end
end

#==============================================================================
# ■ Nature / Gender：新個體依物種資料
#==============================================================================
module ALBERT_CG
  class << self
    if method_defined?(:gender_rate_for_actor)
      alias cg_master_old_gender_rate_for_actor gender_rate_for_actor
      def gender_rate_for_actor(actor)
        if actor != nil && actor.respond_to?(:cg_national_dex)
          dex = actor.cg_national_dex.to_i
          if dex > 0 && defined?(ALBERT_CG::POKEMON_MASTER)
            return ALBERT_CG::POKEMON_MASTER.male_rate_per_thousand(dex)
          end
        end
        return cg_master_old_gender_rate_for_actor(actor)
      end
    end
  end
end

class Game_Actor < Game_Battler
  alias cg_master_identity_prepare cg_prepare_identity_data
  def cg_prepare_identity_data
    if @cg_nature_id == nil && respond_to?(:cg_national_dex)
      dex = cg_national_dex.to_i
      if dex > 0 && defined?(ALBERT_CG::POKEMON_MASTER)
        @cg_nature_id = ALBERT_CG::POKEMON_MASTER.random_nature_for_dex(dex)
      end
    end
    return cg_master_identity_prepare
  end

  def cg_master_ability_id
    value = @cg_master_ability_id
    if value == nil && respond_to?(:cg_national_dex)
      pool = ALBERT_CG::POKEMON_MASTER.ability_pool(cg_national_dex)
      value = pool.empty? ? 0 : pool[0]
    end
    return value.to_i
  end
end

#==============================================================================
# ■ 進化 API：支援 494 與隨機分支
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_master_old_evolution_base_form evolution_base_form
    def evolution_base_form(species_id)
      dex = ALBERT_CG::POKEMON_MASTER.dex_for_actor_id(species_id)
      if dex > 0
        return ALBERT_CG::POKEMON_MASTER.actor_id_for_dex(
          ALBERT_CG::POKEMON_MASTER.root_dex(dex))
      end
      return cg_master_old_evolution_base_form(species_id)
    end

    alias cg_master_old_evolution_stage evolution_stage
    def evolution_stage(species_id)
      dex = ALBERT_CG::POKEMON_MASTER.dex_for_actor_id(species_id)
      return ALBERT_CG::POKEMON_MASTER.stage_depth(dex) + 1 if dex > 0
      return cg_master_old_evolution_stage(species_id)
    end
  end

  module AUTO_EVOLUTION
    class << self
      def species26_form_actor_id?(actor_id)
        dex = ALBERT_CG::POKEMON_MASTER.dex_for_actor_id(actor_id)
        return dex >= 1 && dex <= ALBERT_CG::POKEMON_MASTER::MAX_DEX
      rescue
        return false
      end
    end
  end
end

class Game_Actor < Game_Battler
  alias cg_master_old_evolution_next_form cg_evolution_next_form
  def cg_evolution_next_form
    if respond_to?(:cg_national_dex)
      dex = cg_national_dex.to_i
      if dex > 0
        row = ALBERT_CG::POKEMON_MASTER.choose_evolution_for(self)
        return ALBERT_CG::POKEMON_MASTER.actor_id_for_dex(row[0]) if row != nil
        list = ALBERT_CG::POKEMON_MASTER.evolution_options(dex)
        unless list.empty?
          return ALBERT_CG::POKEMON_MASTER.actor_id_for_dex(list[0][0])
        end
      end
    end
    return cg_master_old_evolution_next_form
  end

  alias cg_master_old_evolution_required_level cg_evolution_required_level
  def cg_evolution_required_level
    if respond_to?(:cg_national_dex)
      dex = cg_national_dex.to_i
      if dex > 0
        row = ALBERT_CG::POKEMON_MASTER.choose_evolution_for(self)
        return row[1].to_i if row != nil
        value = ALBERT_CG::POKEMON_MASTER.minimum_evolution_level(dex)
        return value if value > 0
      end
    end
    return cg_master_old_evolution_required_level
  end

  alias cg_master_old_evolution_ready cg_evolution_ready?
  def cg_evolution_ready?
    if respond_to?(:cg_national_dex) && cg_national_dex.to_i > 0
      return ALBERT_CG::POKEMON_MASTER.choose_evolution_for(self) != nil
    end
    return cg_master_old_evolution_ready
  end

  alias cg_master_old_evolve_to cg_evolve_to
  def cg_evolve_to(form_actor_id = nil, force = false)
    if !force && respond_to?(:cg_national_dex) && cg_national_dex.to_i > 0
      row = ALBERT_CG::POKEMON_MASTER.choose_evolution_for(self)
      return false if row == nil
      target = ALBERT_CG::POKEMON_MASTER.actor_id_for_dex(row[0])
      return false if form_actor_id != nil && form_actor_id.to_i != target
      return cg_master_old_evolve_to(target, true)
    end
    return cg_master_old_evolve_to(form_actor_id, force)
  end
end

#==============================================================================
# ■ Scene_Title：資料庫載入後建置 494
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_master_v220_load_database load_database
  def load_database
    cg_master_v220_load_database
    ALBERT_CG::POKEMON_MASTER.apply
  end

  alias cg_master_v220_load_bt_database load_bt_database
  def load_bt_database
    cg_master_v220_load_bt_database
    ALBERT_CG::POKEMON_MASTER.apply
  end
end

#==============================================================================
# ■ Scene_Map：F10 Master Scenario
#==============================================================================
class Scene_Map < Scene_Base
  alias cg_master_v220_update update
  def update
    cg_master_v220_update
    if !$game_temp.in_battle && ALBERT_CG::POKEMON_MASTER.f10_trigger?
      Sound.play_decision
      ALBERT_CG::POKEMON_MASTER.start_master_test
    end
  end
end

#==============================================================================
# ■ Demo bootstrap：Master Scenario 啟動時保留指定等級／技能
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_master_v220_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_master_v220_bootstrap_demo_party
      if ALBERT_CG::POKEMON_MASTER.master_test_active?
        ALBERT_CG::POKEMON_MASTER::TEST_ALLIES.each do |cfg|
          actor = $game_actors[ALBERT_CG::POKEMON_MASTER.actor_id_for_dex(cfg[:dex])]
          ALBERT_CG::POKEMON_MASTER.configure_actor(actor, cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::POKEMON_MASTER::TEST_HUMAN_LEVEL, false)
          human.recover_all if human.respond_to?(:recover_all)
        end
      end
      return result
    end
  end
end
