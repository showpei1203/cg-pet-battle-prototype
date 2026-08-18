# RMVX_SCRIPT_INDEX: 200
# RMVX_SCRIPT_ID: 2370001
# RMVX_SCRIPT_NAME: CG Pokemon Unique Move Batch D v2.3.7a
# RMVX_SOURCE_SHA256: 78c7b8ae8aeabf72d6503492a68efcfe740e56d9c247f48c43e970db44298a57

#==============================================================================
# ■ CG Pokemon Unique Move Batch D v2.3.7a
#------------------------------------------------------------------------------
# 【用途】
#  接續 v2.3.6c 已實機 PASS 的 Unique Batch C，正式處理 14 個「戰鬥身分改寫」
#  Unique Move，建立後續 Transform / Ability Core / 型態改寫招式都能共用的
#  Battle-only Runtime Identity Layer：
#    160 Conversion／紋理            176 Conversion 2／紋理２
#    272 Role Play／扮演             285 Skill Swap／特性互換
#    293 Camouflage／保護色          380 Gastro Acid／胃液
#    388 Worry Seed／煩惱種子        487 Soak／浸水
#    493 Simple Beam／單純光束       494 Entrainment／找夥伴
#    513 Reflect Type／鏡面屬性      567 Trick-or-Treat／萬聖夜
#    571 Forest's Curse／森林詛咒   750 Magic Powder／魔法粉
#
# 【正式機制規則】
#  1. Type Override 為 Battle-only：
#     - 不寫回 Species / Actor 永久資料。
#     - 換出與戰鬥結束後清除。
#     - cg_pokemon_types 會優先讀 Runtime Override；沒有 Override 才回既有 State / Species。
#  2. Ability Override / Suppression 為 Battle-only：
#     - 不覆寫永久 Ability Pool。
#     - Role Play / Skill Swap / Worry Seed / Simple Beam / Entrainment 改寫目前有效 Ability。
#     - Gastro Acid 只壓制，不摧毀底層 Ability；換出後恢復。
#     - Game_Actor / Game_Enemy 都走同一 Runtime Override 層。
#  3. Conversion：
#     從使用者目前已知招式依 skill_id 順序找第一個「有效且與目前第一屬性不同」的
#     Move Type，改為單一該屬性。若沒有合適招式則失敗。
#  4. Conversion 2：
#     讀目標上一個實際 Move（沿用 v2.3.4 Battle Memory），從 Type Chart 依固定順序
#     選第一個對該攻擊屬性抗性 <100% 的防禦屬性，使用者改成單一該屬性。
#     Regression 讓目標上一招固定為 Electric，預期選 Ground（0%）。
#  5. Camouflage：
#     依目前 Terrain 決定：Grassy=>Grass / Electric=>Electric / Misty=>Fairy /
#     Psychic=>Psychic；無 Terrain 時=>Normal。
#  6. Soak / Magic Powder：
#     Soak 把目標改為純 Water；Magic Powder 把目標改為純 Psychic。
#  7. Reflect Type：
#     使用者複製目標目前有效 Type（最多兩個）。
#  8. Trick-or-Treat / Forest's Curse：
#     分別追加 Ghost / Grass。若已有兩屬性，保留第一屬性並以新增屬性取代第二屬性；
#     若已含該屬性則視為成功但不重複追加。
#  9. Role Play：使用者複製目標目前有效 Ability。
# 10. Skill Swap：交換雙方目前有效 Ability；若任一側有效 Ability=0，則失敗。
# 11. Worry Seed：目標 Ability 改為 Insomnia（15）。
# 12. Simple Beam：目標 Ability 改為 Simple（86）。
# 13. Entrainment：目標 Ability 改為使用者目前有效 Ability。
# 14. Gastro Acid：目標 Ability 進入 suppressed，cg_master_ability_id 對外回 0。
#
# 【設計邊界】
#  - 本版先完成共通 Identity Runtime 與 14 招核心效果。
#  - 原作少數「不可覆寫／不可交換／不可壓制 Ability」的完整例外矩陣，會在 373 Ability
#    正式 Phase 統一收斂到 Ability Metadata，而不是在每個 Move 裡各寫一份大型黑名單。
#  - 本專案不做持有道具，因此本批不引入任何 item-dependent 分支。
#
# 【可調參數】
#  INSOMNIA_ABILITY_ID = 15
#  SIMPLE_ABILITY_ID   = 86
#  TEST_TROOP_ID       = 692
#  TEST_LEVEL          = 40
#
# 【事件／腳本呼叫方式】
#  正常戰鬥不需事件呼叫。Debug 可直接：
#    battler.cg_v237_set_types([:water])
#    battler.cg_v237_set_ability(15)
#    battler.cg_v237_suppress_ability(true)
#    battler.cg_v237_clear_identity
#
# 【實際範例】
#  噴火龍被浸水：
#    SOAK target=噴火龍 before=[:fire,:flying] after=[:water]
#  此後 cg_pokemon_type_rate_percent(:electric) 會立即按本作 4v4 柔化規則計算 160%。
#
# 【AutoRegression】
#  地圖畫面只按 F11，執行 3 回合真正 Scene_Battle：
#    R1：Conversion / Soak / Trick-or-Treat / Forest's Curse /
#        Reflect Type / Magic Powder
#    R2：Skill Swap / Role Play / Worry Seed / Entrainment /
#        Simple Beam / Gastro Acid，並讓 E3 最後使用 Thunderbolt 建立 Conversion2 Memory
#    R3：Conversion2 / Camouflage，並驗證 R1/R2 Identity Override 仍真的接入
#        Type Chart 與 Ability API。
#  成功標準：
#    RESULT=PASS
#    SUMMARY rounds=3 failures=0 unique_d_moves=14/14 type_checks=8 ability_checks=8
#
# 【v2.3.7a Regression 對齊修正】
#  - 不修改 14 招正式效果。v2.3.7 實機已證明 14/14 全部實際執行。
#  - Tom 使用 Guard 時，正式 Priority Core 定義 Guard=+4，因此 deterministic 順序
#    必須以 A0:Guard 為第一個 Action；v2.3.7 原 EXPECTED token 把 Guard 排最後是測試器錯誤。
#  - 本專案自 v2.1.0 起將原作 2.0x 弱點柔化為 1.60x、0.5x 抗性柔化為 0.63x。
#    Soak 後 Water 被 Electric 攻擊，cg_pokemon_type_rate_percent 正式預期為 160，
#    不是 raw Pokémon Type Chart 的 200。
#
# 【F11 政策】
#  F11 永遠只啟動目前最新版 AutoRegression；v2.3.6c 舊測試保留 script-call 能力，
#  但鍵盤 F11 由本版接管。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PokemonUniqueMoveBatchD"] = "2.3.7a"

module ALBERT_CG
  module UNIQUE_D_V237
    VERSION = "2.3.7a"

    MOVE_CONVERSION       = 160
    MOVE_CONVERSION_2     = 176
    MOVE_ROLE_PLAY        = 272
    MOVE_SKILL_SWAP       = 285
    MOVE_CAMOUFLAGE       = 293
    MOVE_GASTRO_ACID      = 380
    MOVE_WORRY_SEED       = 388
    MOVE_SOAK             = 487
    MOVE_SIMPLE_BEAM      = 493
    MOVE_ENTRAINMENT      = 494
    MOVE_REFLECT_TYPE     = 513
    MOVE_TRICK_OR_TREAT   = 567
    MOVE_FORESTS_CURSE    = 571
    MOVE_MAGIC_POWDER     = 750

    HANDLED_MOVE_IDS = [
      MOVE_CONVERSION, MOVE_CONVERSION_2, MOVE_ROLE_PLAY, MOVE_SKILL_SWAP,
      MOVE_CAMOUFLAGE, MOVE_GASTRO_ACID, MOVE_WORRY_SEED, MOVE_SOAK,
      MOVE_SIMPLE_BEAM, MOVE_ENTRAINMENT, MOVE_REFLECT_TYPE,
      MOVE_TRICK_OR_TREAT, MOVE_FORESTS_CURSE, MOVE_MAGIC_POWDER
    ]

    INSOMNIA_ABILITY_ID = 15
    SIMPLE_ABILITY_ID   = 86
    TEST_TROOP_ID = 692
    TEST_LEVEL = 40

    TEST_ALLIES = [
      {:dex=>137,:level=>40,:ability=>36, :moves=>[160,176,272,85]},
      {:dex=>3,  :level=>40,:ability=>65, :moves=>[487,388,293,150]},
      {:dex=>94, :level=>40,:ability=>130,:moves=>[567,380,150,150]},
    ]
    TEST_ENEMIES = [
      {:dex=>6, :level=>40,:ability=>66,:moves=>[493,150,150,150]},
      {:dex=>9, :level=>40,:ability=>67,:moves=>[571,494,150,150]},
      {:dex=>65,:level=>40,:ability=>28,:moves=>[513,285,150,150]},
      {:dex=>68,:level=>40,:ability=>62,:moves=>[750,85,150,150]},
    ]

    ROUND_PLANS = [
      {
        :name=>"TYPE_REWRITE_AND_COPY",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>160,:target=>1},
          {:kind=>:move,:move_id=>487,:target=>0},
          {:kind=>:move,:move_id=>567,:target=>1},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>571,:target=>0},
          {:kind=>:move,:move_id=>513,:target=>2},
          {:kind=>:move,:move_id=>750,:target=>3},
        ]
      },
      {
        :name=>"ABILITY_REWRITE_AND_SUPPRESS",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>272,:target=>0},
          {:kind=>:move,:move_id=>388,:target=>1},
          {:kind=>:move,:move_id=>380,:target=>2},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>493,:target=>0},
          {:kind=>:move,:move_id=>494,:target=>2},
          {:kind=>:move,:move_id=>285,:target=>3},
          {:kind=>:move,:move_id=>85,:target=>0},
        ]
      },
      {
        :name=>"CONVERSION2_CAMOUFLAGE_RUNTIME_INTEGRATION",
        :allies=>[
          {:kind=>:guard},
          {:kind=>:move,:move_id=>176,:target=>3},
          {:kind=>:move,:move_id=>293,:target=>2},
          {:kind=>:move,:move_id=>150,:target=>0},
        ],
        :enemies=>[
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
          {:kind=>:move,:move_id=>150,:target=>0},
        ]
      },
    ]

    TEST_SPEEDS = {
      :r1=>[10,120,110,100,20,90,80,70],
      :r2=>[10,110,100,60,70,90,120,50],
      :r3=>[10,120,110,100,80,70,60,50],
    }

    EXPECTED_EXECUTION_TOKENS = {
      1=>["A0:Guard","A1:M160","A2:M487","A3:M567","E1:M571","E2:M513","E3:M750","E0:M150"],
      2=>["A0:Guard","E2:M285","A1:M272","A2:M388","E1:M494","E0:M493","A3:M380","E3:M85"],
      3=>["A0:Guard","A1:M176","A2:M293","A3:M150","E0:M150","E1:M150","E2:M150","E3:M150"],
    }

    VK_F11 = 0x7A
    begin
      KEY_API = Win32API.new("user32", "GetAsyncKeyState", "i", "i")
    rescue
      KEY_API = nil
    end

    def self.master
      return defined?(ALBERT_CG::POKEMON_MASTER) ? ALBERT_CG::POKEMON_MASTER : nil
    end

    def self.combat
      return defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT : nil
    end

    def self.active?
      return @active == true
    end

    def self.handled?(move_id)
      return HANDLED_MOVE_IDS.include?(move_id.to_i)
    end

    def self.current_round
      return @round_index.to_i + 1
    end

    def self.current_plan
      return ROUND_PLANS[@round_index.to_i]
    end

    def self.finished?
      return @round_index.to_i >= ROUND_PLANS.size
    end

    def self.project_root
      if defined?(ALBERT_CG::UNIQUE_B_V234) && ALBERT_CG::UNIQUE_B_V234.respond_to?(:project_root)
        return ALBERT_CG::UNIQUE_B_V234.project_root
      end
      return Dir.pwd
    rescue
      return Dir.pwd
    end

    def self.log_path
      return File.join(project_root, "Pokemon_UniqueD_AutoTest_v2_3_7a.log")
    end

    def self.latest_log_path
      return File.join(project_root, "CG_AutoRegression_LATEST.log")
    end

    def self.trace_log_path
      return File.join(project_root, "PMD_BattleInitTrace.log")
    end

    def self.write_line(path, text, mode="ab")
      File.open(path, mode) { |f| f.write(text.to_s + "\r\n") }
      return true
    rescue
      return false
    end

    def self.important_line?(line)
      return true if line.index("AUTO_TEST_START") == 0
      return true if line.index("ASSERT ") == 0
      return true if line.index("TYPE_") == 0 || line.index("ABILITY_") == 0
      return true if line.index("CONVERSION") == 0 || line.index("CAMOUFLAGE") == 0
      return true if line.index("RESULT=") == 0 || line.index("SUMMARY ") == 0
      return false
    end

    def self.log(line)
      text = line.to_s
      write_line(log_path, text)
      write_line(latest_log_path, text)
      write_line(trace_log_path, "[UNIQUE_D_AUTOTEST] " + text) if important_line?(text)
    end

    def self.reset_log
      header = [
        "CG POKEMON UNIQUE MOVE D AUTO REGRESSION v2.3.7a",
        "START=" + Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        "RULE=Actual Scene_Battle; 14 battle-identity Unique Moves; deterministic type/ability checks",
        "AUTOTEST_LOG_PATH=" + log_path.to_s,
        "AUTOTEST_LATEST_PATH=" + latest_log_path.to_s,
        "------------------------------------------------------------"
      ]
      [log_path, latest_log_path].each do |p|
        begin
          File.open(p, "wb") { |f| header.each { |x| f.write(x + "\r\n") } }
        rescue
        end
      end
    end

    def self.key_down?(vk)
      return false if KEY_API == nil
      return (KEY_API.call(vk) & 0x8000) != 0
    rescue
      return false
    end

    def self.f11_trigger?
      down = key_down?(VK_F11)
      trigger = down && @f11_down != true
      @f11_down = down
      return trigger
    rescue
      return false
    end

    def self.show_text(text)
      scene = $scene
      if scene != nil && scene.respond_to?(:cg_show_special_action_text, true)
        scene.send(:cg_show_special_action_text, text.to_s)
      end
    rescue
    end

    def self.type_name(type)
      return type.to_s if combat == nil
      key = combat.type_key(type)
      names = combat.const_defined?(:TYPE_FULL_NAMES) ? combat::TYPE_FULL_NAMES : {}
      return names[key].to_s unless names[key] == nil
      return key.to_s
    rescue
      return type.to_s
    end

    def self.ability_name(id)
      return id.to_i.to_s if master == nil
      n = master.ability_name(id.to_i)
      return n.to_s == "" ? id.to_i.to_s : n.to_s
    rescue
      return id.to_i.to_s
    end

    def self.mark_apply(move_id)
      @apply_counts = {} if @apply_counts == nil
      mid = move_id.to_i
      @apply_counts[mid] = @apply_counts[mid].to_i + 1
      log("APPLY move=" + mid.to_s + ":" + (master == nil ? "" : master.move_name(mid).to_s) +
          " count=" + @apply_counts[mid].to_i.to_s) if active?
    end

    def self.install_skill_scopes
      return if master == nil || $data_skills == nil
      self_moves = [MOVE_CONVERSION, MOVE_CAMOUFLAGE]
      HANDLED_MOVE_IDS.each do |mid|
        sid = master.skill_id_for_move(mid)
        next if sid.to_i <= 0 || $data_skills[sid] == nil
        $data_skills[sid].scope = self_moves.include?(mid) ? 11 : 1
      end
    rescue => e
      log("SCOPE_INSTALL_ERROR " + e.class.to_s + ":" + e.message.to_s) if active?
    end

    def self.known_move_types(battler)
      result = []
      return result if battler == nil || master == nil
      skills = []
      if battler.actor? && battler.respond_to?(:skills)
        skills = battler.skills.compact.sort_by { |s| s.id.to_i }
      elsif !battler.actor? && $data_enemies != nil
        data = $data_enemies[battler.enemy_id]
        if data != nil && data.respond_to?(:actions)
          data.actions.each do |a|
            next unless a != nil && a.kind.to_i == 1
            sk = $data_skills[a.skill_id]
            skills.push(sk) if sk != nil
          end
        end
      end
      skills.each do |sk|
        mid = master.move_id_for_skill(sk.id).to_i
        next if mid <= 0 || mid == MOVE_CONVERSION || mid == MOVE_CONVERSION_2
        row = master.move(mid)
        next if row == nil
        type = row[2]
        next if type == nil
        result.push([mid,type])
      end
      return result
    rescue
      return []
    end

    def self.apply_conversion(user)
      before = user.cg_pokemon_types
      current = before == nil || before.empty? ? nil : before[0]
      pair = known_move_types(user).find { |x| x[1] != current }
      return false if pair == nil
      user.cg_v237_set_types([pair[1]])
      log("CONVERSION user=" + user.name.to_s + " source_move=" + pair[0].to_s +
          " before=" + before.inspect + " after=" + user.cg_pokemon_types.inspect)
      show_text(user.name.to_s + "的屬性變成" + type_name(pair[1]) + "！")
      return true
    end

    def self.resistant_type_for(attack_type, current_types)
      return nil if combat == nil
      order = [:normal,:fighting,:flying,:poison,:ground,:rock,:bug,:ghost,
               :steel,:fire,:water,:grass,:electric,:psychic,:ice,:dragon,:dark,:fairy]
      order.each do |type|
        next if current_types != nil && current_types.include?(type)
        rate = combat.type_chart_percent(attack_type, [type]).to_i
        return type if rate < 100
      end
      return nil
    rescue
      return nil
    end

    def self.apply_conversion2(user, target)
      return false if user == nil || target == nil || master == nil
      last_mid = target.respond_to?(:cg_v234_last_move_id) ? target.cg_v234_last_move_id.to_i : 0
      row = last_mid > 0 ? master.move(last_mid) : nil
      return false if row == nil
      attack_type = row[2]
      chosen = resistant_type_for(attack_type, user.cg_pokemon_types)
      return false if chosen == nil
      before = user.cg_pokemon_types
      user.cg_v237_set_types([chosen])
      log("CONVERSION2 user=" + user.name.to_s + " target=" + target.name.to_s +
          " last_move=" + last_mid.to_s + " attack_type=" + attack_type.to_s +
          " before=" + before.inspect + " after=" + user.cg_pokemon_types.inspect)
      show_text(user.name.to_s + "改變屬性以抵抗" + type_name(attack_type) + "！")
      return true
    end

    def self.terrain_type
      if defined?(ALBERT_CG::FIELD_V233) && ALBERT_CG::FIELD_V233.respond_to?(:state)
        terrain = ALBERT_CG::FIELD_V233.state.terrain
        return :grass if terrain == :grassy
        return :electric if terrain == :electric
        return :fairy if terrain == :misty
        return :psychic if terrain == :psychic
      end
      return :normal
    rescue
      return :normal
    end

    def self.apply_camouflage(user)
      type = terrain_type
      before = user.cg_pokemon_types
      user.cg_v237_set_types([type])
      log("CAMOUFLAGE user=" + user.name.to_s + " terrain=" +
          (defined?(ALBERT_CG::FIELD_V233) ? ALBERT_CG::FIELD_V233.state.terrain.to_s : "nil") +
          " before=" + before.inspect + " after=" + user.cg_pokemon_types.inspect)
      show_text(user.name.to_s + "配合場地變成" + type_name(type) + "屬性！")
      return true
    end

    def self.set_type(target, types, label)
      return false if target == nil
      before = target.cg_pokemon_types
      target.cg_v237_set_types(types)
      log("TYPE_SET kind=" + label.to_s + " target=" + target.name.to_s +
          " before=" + before.inspect + " after=" + target.cg_pokemon_types.inspect)
      show_text(target.name.to_s + "的屬性改變了！")
      return true
    end

    def self.add_type(target, type, label)
      return false if target == nil
      before = target.cg_pokemon_types || []
      after = before.dup
      unless after.include?(type)
        if after.size <= 0
          after = [type]
        elsif after.size == 1
          after.push(type)
        else
          after = [after[0], type]
        end
      end
      target.cg_v237_set_types(after)
      log("TYPE_ADD kind=" + label.to_s + " target=" + target.name.to_s +
          " before=" + before.inspect + " after=" + target.cg_pokemon_types.inspect)
      show_text(target.name.to_s + "追加了" + type_name(type) + "屬性！")
      return true
    end

    def self.effective_ability(battler)
      return 0 if battler == nil || !battler.respond_to?(:cg_master_ability_id)
      return battler.cg_master_ability_id.to_i
    rescue
      return 0
    end

    def self.set_ability(target, id, label)
      return false if target == nil || id.to_i <= 0
      before = effective_ability(target)
      target.cg_v237_set_ability(id.to_i)
      log("ABILITY_SET kind=" + label.to_s + " target=" + target.name.to_s +
          " before=" + before.to_s + " after=" + effective_ability(target).to_s)
      show_text(target.name.to_s + "的特性變成「" + ability_name(id) + "」！")
      return true
    end

    def self.apply_role_play(user, target)
      return false if user == nil || target == nil
      id = effective_ability(target)
      return false if id <= 0
      return set_ability(user, id, :role_play)
    end

    def self.apply_skill_swap(user, target)
      return false if user == nil || target == nil
      a = effective_ability(user)
      b = effective_ability(target)
      return false if a <= 0 || b <= 0
      user.cg_v237_set_ability(b)
      target.cg_v237_set_ability(a)
      log("ABILITY_SWAP user=" + user.name.to_s + " target=" + target.name.to_s +
          " user_before=" + a.to_s + " user_after=" + effective_ability(user).to_s +
          " target_before=" + b.to_s + " target_after=" + effective_ability(target).to_s)
      show_text(user.name.to_s + "與" + target.name.to_s + "交換了特性！")
      return true
    end

    def self.apply_gastro_acid(target)
      return false if target == nil
      before = effective_ability(target)
      target.cg_v237_suppress_ability(true)
      log("ABILITY_SUPPRESS target=" + target.name.to_s + " before=" + before.to_s +
          " after=" + effective_ability(target).to_s)
      show_text(target.name.to_s + "的特性被壓制了！")
      return true
    end

    def self.apply_unique(user, target, mid)
      case mid
      when MOVE_CONVERSION
        return apply_conversion(user)
      when MOVE_CONVERSION_2
        return apply_conversion2(user, target)
      when MOVE_CAMOUFLAGE
        return apply_camouflage(user)
      when MOVE_SOAK
        return set_type(target, [:water], :soak)
      when MOVE_REFLECT_TYPE
        return set_type(user, target.cg_pokemon_types, :reflect_type)
      when MOVE_TRICK_OR_TREAT
        return add_type(target, :ghost, :trick_or_treat)
      when MOVE_FORESTS_CURSE
        return add_type(target, :grass, :forests_curse)
      when MOVE_MAGIC_POWDER
        return set_type(target, [:psychic], :magic_powder)
      when MOVE_ROLE_PLAY
        return apply_role_play(user, target)
      when MOVE_SKILL_SWAP
        return apply_skill_swap(user, target)
      when MOVE_GASTRO_ACID
        return apply_gastro_acid(target)
      when MOVE_WORRY_SEED
        return set_ability(target, INSOMNIA_ABILITY_ID, :worry_seed)
      when MOVE_SIMPLE_BEAM
        return set_ability(target, SIMPLE_ABILITY_ID, :simple_beam)
      when MOVE_ENTRAINMENT
        return set_ability(target, effective_ability(user), :entrainment)
      end
      return false
    rescue => e
      log("APPLY_ERROR move=" + mid.to_i.to_s + " " + e.class.to_s + ":" + e.message.to_s) if active?
      return false
    end

    def self.test_allies
      return $game_party == nil ? [] : $game_party.members[0,4]
    end

    def self.test_enemies
      return $game_troop == nil ? [] : $game_troop.members[0,4]
    end

    def self.current_troop_id
      return -1 if $game_troop == nil
      return $game_troop.troop_id.to_i if $game_troop.respond_to?(:troop_id)
      return $game_troop.instance_variable_get(:@troop_id).to_i
    rescue
      return -1
    end

    def self.configure_actor(cfg)
      return if master == nil
      actor = $game_actors[master.actor_id_for_dex(cfg[:dex])]
      return if actor == nil
      master.configure_actor(actor, cfg)
      actor.cg_v237_clear_identity if actor.respond_to?(:cg_v237_clear_identity)
      actor.cg_reset_stat_stages if actor.respond_to?(:cg_reset_stat_stages)
      actor.recover_all if actor.respond_to?(:recover_all)
    end

    def self.configure_enemy(cfg)
      master.configure_enemy_data(cfg) if master != nil
    end

    def self.prepare_test_party
      ids = TEST_ALLIES.collect { |cfg| master.actor_id_for_dex(cfg[:dex]) }
      ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS.replace(ids) if defined?(ALBERT_CG::DIRECT_PMD_TEST_PET_ACTOR_IDS)
      $game_party.instance_variable_set(:@cg_direct_pmd_initialized, true)
      $game_party.cg_enable_direct_pmd_test_party! if $game_party.respond_to?(:cg_enable_direct_pmd_test_party!)
      TEST_ALLIES.each { |cfg| configure_actor(cfg) }
      human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
      if human != nil
        human.change_level(TEST_LEVEL, false)
        human.recover_all if human.respond_to?(:recover_all)
        human.cg_v237_clear_identity if human.respond_to?(:cg_v237_clear_identity)
      end
      return true
    end

    def self.apply_test_grid
      allies = test_allies
      enemies = test_enemies
      slots_a = [[:back,1],[:front,0],[:front,1],[:front,2]]
      slots_e = [[:front,0],[:front,1],[:front,2],[:back,1]]
      allies.each_with_index do |b,i|
        b.cg_set_battle_slot(slots_a[i][0],slots_a[i][1],true) if b != nil && b.respond_to?(:cg_set_battle_slot)
      end
      enemies.each_with_index do |b,i|
        b.cg_set_battle_slot(slots_e[i][0],slots_e[i][1],true) if b != nil && b.respond_to?(:cg_set_battle_slot)
      end
    end

    def self.make_test_troop
      master.ensure_index($data_troops, TEST_TROOP_ID)
      xs = [ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_FRONT_X,ALBERT_CG::ENEMY_BACK_X]
      ys = [ALBERT_CG::GRID_COLUMN_Y[0],ALBERT_CG::GRID_COLUMN_Y[1],ALBERT_CG::GRID_COLUMN_Y[2],ALBERT_CG::GRID_COLUMN_Y[1]]
      members = []
      TEST_ENEMIES.each_with_index do |cfg,i|
        configure_enemy(cfg)
        members.push(ALBERT_CG::SPECIES26.make_troop_member(master.enemy_id_for_dex(cfg[:dex]),xs[i],ys[i]))
      end
      $data_troops[TEST_TROOP_ID] = ALBERT_CG::SPECIES26.make_troop(TEST_TROOP_ID,
        "Pokemon UniqueD v2.3.7a AutoRegression",members)
    end

    def self.make_action(battler,cfg)
      action = Game_BattleAction.new(battler)
      if cfg[:kind] == :attack
        action.set_attack
      elsif cfg[:kind] == :guard
        action.set_guard
      elsif cfg[:kind] == :move
        action.set_skill(master.skill_id_for_move(cfg[:move_id].to_i))
      else
        action.clear
      end
      action.target_index = cfg[:target].to_i if cfg.has_key?(:target)
      return action
    end

    def self.forced_enemy_action(enemy)
      return nil unless active? && enemy != nil
      cfg = current_plan == nil ? nil : current_plan[:enemies][enemy.index]
      return nil if cfg == nil
      return make_action(enemy,cfg)
    end

    def self.apply_test_speeds
      vals = TEST_SPEEDS[("r" + current_round.to_s).to_sym] || []
      (test_allies + test_enemies).each_with_index do |b,i|
        b.instance_variable_set(:@cg_priority_test_speed_override,vals[i]) if b != nil
      end
    end

    def self.record_execution(battler)
      return unless active? && battler != nil
      @actual = [] if @actual == nil
      token = battler.actor? ? "A" + battler.index.to_s : "E" + battler.index.to_s
      if battler.action != nil && battler.action.skill?
        mid = ALBERT_CG::MOVE_EFFECT.move_id(battler.action.skill)
        token += ":M" + mid.to_s
      elsif battler.action != nil && battler.action.attack?
        token += ":Attack"
      elsif battler.action != nil && battler.action.guard?
        token += ":Guard"
      else
        token += ":Other"
      end
      @actual.push(token)
      log("ACTION_EXEC #" + @actual.size.to_s + " " + battler.name.to_s + " token=" + token)
    end

    def self.assign_action_to(b,action)
      return if b == nil
      if b.respond_to?(:cg_round_actions)
        b.cg_round_actions.clear
        b.cg_round_actions.push(action)
      end
      b.cg_assign_action(action) if b.respond_to?(:cg_assign_action)
      b.instance_variable_set(:@action,action) unless b.respond_to?(:cg_assign_action)
    end

    def self.prepare_round_preconditions
      if current_round == 3 && defined?(ALBERT_CG::FIELD_V233)
        ALBERT_CG::FIELD_V233.state.terrain = :grassy
        ALBERT_CG::FIELD_V233.state.terrain_turns = 5
        log("TYPE_TEST_TERRAIN terrain=grassy turns=5")
      end
    end

    def self.prepare_round_actions
      plan = current_plan
      return false if plan == nil
      apply_test_speeds
      prepare_round_preconditions
      @actual = []
      log("ROUND " + current_round.to_s + " BEGIN " + plan[:name].to_s)
      allies = test_allies
      plan[:allies].each_with_index do |cfg,i|
        b = allies[i]
        next if b == nil
        assign_action_to(b,make_action(b,cfg))
      end
      return true
    end

    def self.assert(condition,text)
      if condition
        log("ASSERT PASS " + text.to_s)
      else
        @failures = @failures.to_i + 1
        @failure_lines = [] if @failure_lines == nil
        @failure_lines.push(text.to_s)
        log("ASSERT FAIL " + text.to_s)
      end
      return condition
    end

    def self.note_type_check(ok)
      @type_checks = @type_checks.to_i + 1 if ok
      return ok
    end

    def self.note_ability_check(ok)
      @ability_checks = @ability_checks.to_i + 1 if ok
      return ok
    end

    def self.finish_round_assertions
      round = current_round
      expected = EXPECTED_EXECUTION_TOKENS[round] || []
      actual = @actual || []
      assert(actual.size == 8,"Round" + round.to_s + " executes exactly 8 scripted battler actions actual=" + actual.size.to_s)
      assert(actual == expected,"Round" + round.to_s + " execution order matches deterministic plan expected=" + expected.inspect + " actual=" + actual.inspect)
      a = test_allies
      e = test_enemies
      case round
      when 1
        ok = a[1].cg_pokemon_types == [:electric]; note_type_check(ok); assert(ok,"Conversion changes A1 Porygon to Electric actual=" + a[1].cg_pokemon_types.inspect)
        ok = e[0].cg_pokemon_types == [:water]; note_type_check(ok); assert(ok,"Soak changes E0 to pure Water actual=" + e[0].cg_pokemon_types.inspect)
        ok = e[1].cg_pokemon_types.include?(:water) && e[1].cg_pokemon_types.include?(:ghost); note_type_check(ok); assert(ok,"Trick-or-Treat adds Ghost to E1 actual=" + e[1].cg_pokemon_types.inspect)
        ok = a[0].cg_pokemon_types.include?(:grass); note_type_check(ok); assert(ok,"Forest's Curse adds Grass to human A0 actual=" + a[0].cg_pokemon_types.inspect)
        ok = e[2].cg_pokemon_types == a[2].cg_pokemon_types; note_type_check(ok); assert(ok,"Reflect Type copies A2 current types actual=" + e[2].cg_pokemon_types.inspect)
        ok = a[3].cg_pokemon_types == [:psychic]; note_type_check(ok); assert(ok,"Magic Powder changes A3 to pure Psychic actual=" + a[3].cg_pokemon_types.inspect)
      when 2
        ok = effective_ability(e[2]) == 0 && e[2].instance_variable_get(:@cg_v237_ability_suppressed) == true; note_ability_check(ok); assert(ok,"Gastro Acid suppresses E2 effective ability")
        ok = effective_ability(a[1]) == 66; note_ability_check(ok); assert(ok,"Role Play copies E0 Blaze to A1 actual=" + effective_ability(a[1]).to_s)
        ok = effective_ability(e[1]) == INSOMNIA_ABILITY_ID; note_ability_check(ok); assert(ok,"Worry Seed sets E1 Insomnia actual=" + effective_ability(e[1]).to_s)
        ok = effective_ability(a[2]) == INSOMNIA_ABILITY_ID; note_ability_check(ok); assert(ok,"Entrainment passes E1 current Insomnia to A2 actual=" + effective_ability(a[2]).to_s)
        ok = effective_ability(a[0]) == SIMPLE_ABILITY_ID; note_ability_check(ok); assert(ok,"Simple Beam sets A0 Simple actual=" + effective_ability(a[0]).to_s)
        ok = effective_ability(a[3]) == 28; note_ability_check(ok); assert(ok,"Skill Swap gives E2 original ability to A3 actual=" + effective_ability(a[3]).to_s)
        ok = e[2].instance_variable_get(:@cg_v237_ability_override).to_i == 130; note_ability_check(ok); assert(ok,"Skill Swap stores A3 original ability under E2 suppression actual=" + e[2].instance_variable_get(:@cg_v237_ability_override).to_i.to_s)
        if defined?(ALBERT_CG::FORCE_SWITCH_V235)
          ok = ALBERT_CG::FORCE_SWITCH_V235.ability_id(e[2]).to_i == 0; note_ability_check(ok); assert(ok,"Force Switch Ability API sees Gastro Acid suppression")
        end
      when 3
        ok = a[1].cg_pokemon_types == [:ground]; note_type_check(ok); assert(ok,"Conversion2 converts A1 to Ground against E3 last Electric move actual=" + a[1].cg_pokemon_types.inspect)
        ok = a[2].cg_pokemon_types == [:grass]; note_type_check(ok); assert(ok,"Camouflage under Grassy Terrain converts A2 to Grass actual=" + a[2].cg_pokemon_types.inspect)
        ok = e[0].cg_pokemon_type_rate_percent(:electric).to_i == ALBERT_CG::SIX_STAT_DAMAGE::WEAK_PERCENT.to_i; assert(ok,"Soak Runtime type really feeds softened Type Chart expected=" + ALBERT_CG::SIX_STAT_DAMAGE::WEAK_PERCENT.to_i.to_s + " actual=" + e[0].cg_pokemon_type_rate_percent(:electric).to_i.to_s)
        ok = effective_ability(a[0]) == SIMPLE_ABILITY_ID; assert(ok,"Ability Runtime override persists across rounds before switch")
      end
      log("ROUND " + round.to_s + " END")
      @round_index = @round_index.to_i + 1
    end

    def self.assert_bootstrap_once
      return if @boot_asserted
      @boot_asserted = true
      install_skill_scopes
      apply_test_grid
      assert(current_troop_id == TEST_TROOP_ID,"Scene_Battle uses Unique D test troop actual=" + current_troop_id.to_s)
      assert(test_allies.size == 4,"Unique D ally count=4 actual=" + test_allies.size.to_s)
      assert(test_enemies.size == 4,"Unique D enemy count=4 actual=" + test_enemies.size.to_s)
      assert(test_allies.collect { |b| b.actor? ? b.id : 0 } == [1,236,102,193],"Unique D exact ally roster")
      assert(test_enemies.collect { |b| b.enemy_id } == [605,608,664,667],"Unique D exact enemy roster")
    end

    def self.finish_suite
      missing = HANDLED_MOVE_IDS.select { |mid| @apply_counts[mid].to_i <= 0 }
      assert(missing.empty?,"All 14 Unique Batch D moves executed missing=" + missing.inspect)
      log("------------------------------------------------------------")
      log(@failures.to_i <= 0 ? "RESULT=PASS" : "RESULT=FAIL")
      log("SUMMARY rounds=3 failures=" + @failures.to_i.to_s +
          " unique_d_moves=" + (HANDLED_MOVE_IDS.size - missing.size).to_s + "/14" +
          " type_checks=" + @type_checks.to_i.to_s + " ability_checks=" + @ability_checks.to_i.to_s)
      if @failure_lines != nil
        @failure_lines.each_with_index { |x,i| log("FAILURE " + (i+1).to_s + " " + x.to_s) }
      end
      @active = false
      return @failures.to_i <= 0
    end

    def self.start_auto_test
      return false if active? || $game_temp.in_battle
      install_skill_scopes
      prepare_test_party
      make_test_troop
      ALBERT_CG::FIELD_V233.reset if defined?(ALBERT_CG::FIELD_V233) && ALBERT_CG::FIELD_V233.respond_to?(:reset)
      reset_log
      @active = true
      @round_index = 0
      @failures = 0
      @failure_lines = []
      @apply_counts = {}
      @type_checks = 0
      @ability_checks = 0
      @boot_asserted = false
      log("AUTO_TEST_START troop=" + TEST_TROOP_ID.to_s)
      if defined?(ALBERT_CG) && ALBERT_CG.respond_to?(:start_demo_battle)
        ALBERT_CG.start_demo_battle(TEST_TROOP_ID)
      else
        $game_troop.setup(TEST_TROOP_ID)
        $game_temp.in_battle = true
        $game_temp.battle_troop_id = TEST_TROOP_ID
        $scene = Scene_Battle.new
      end
      return true
    rescue => e
      log("AUTO_TEST_START_ERROR " + e.class.to_s + ":" + e.message.to_s)
      @active = false
      return false
    end
  end
end

#==============================================================================
# ■ Game_Battler：Battle-only Type / Ability Runtime Identity
#==============================================================================
class Game_Battler
  alias cg_v237_pokemon_types cg_pokemon_types
  def cg_pokemon_types
    types = @cg_v237_type_override
    if types != nil && types.is_a?(Array) && !types.empty?
      return types[0,2]
    end
    return cg_v237_pokemon_types
  rescue
    return cg_v237_pokemon_types
  end

  def cg_v237_set_types(types)
    result = []
    (types || []).each do |x|
      key = defined?(ALBERT_CG::POKEMON_COMBAT) ? ALBERT_CG::POKEMON_COMBAT.type_key(x) : x
      result.push(key) if key != nil && !result.include?(key)
    end
    @cg_v237_type_override = result[0,2]
    return @cg_v237_type_override
  end

  def cg_v237_set_ability(id)
    @cg_v237_ability_override = id.to_i
    @cg_v237_ability_suppressed = false
    return @cg_v237_ability_override
  end

  def cg_v237_suppress_ability(value=true)
    @cg_v237_ability_suppressed = value ? true : false
  end

  def cg_v237_clear_identity
    @cg_v237_type_override = nil
    @cg_v237_ability_override = nil
    @cg_v237_ability_suppressed = false
  end

  alias cg_v237_remove_states_battle remove_states_battle
  def remove_states_battle
    cg_v237_remove_states_battle
    cg_v237_clear_identity
  end

  alias cg_v237_skill_effect skill_effect
  def skill_effect(user,skill)
    mid = skill == nil ? 0 : ALBERT_CG::MOVE_EFFECT.move_id(skill)
    unless defined?(ALBERT_CG::UNIQUE_D_V237) && ALBERT_CG::UNIQUE_D_V237.handled?(mid)
      return cg_v237_skill_effect(user,skill)
    end
    clear_action_results
    ok = ALBERT_CG::UNIQUE_D_V237.apply_unique(user,self,mid)
    if ok
      ALBERT_CG::UNIQUE_D_V237.mark_apply(mid)
    else
      @skipped = true if instance_variable_defined?(:@skipped)
      ALBERT_CG::UNIQUE_D_V237.log("APPLY_FAIL move=" + mid.to_s + " user=" +
          (user == nil ? "nil" : user.name.to_s) + " target=" + name.to_s) if ALBERT_CG::UNIQUE_D_V237.active?
    end
    return
  end
end

#==============================================================================
# ■ Game_Actor / Game_Enemy：Runtime Ability Override / Suppression Bridge
#==============================================================================
class Game_Actor < Game_Battler
  alias cg_v237_actor_master_ability_id cg_master_ability_id
  def cg_master_ability_id
    return 0 if @cg_v237_ability_suppressed == true
    return @cg_v237_ability_override.to_i unless @cg_v237_ability_override == nil
    return cg_v237_actor_master_ability_id
  end
end

class Game_Enemy < Game_Battler
  alias cg_v237_enemy_master_ability_id cg_master_ability_id
  def cg_master_ability_id
    return 0 if @cg_v237_ability_suppressed == true
    return @cg_v237_ability_override.to_i unless @cg_v237_ability_override == nil
    return cg_v237_enemy_master_ability_id
  end
end

#==============================================================================
# ■ Force Switch：換出時清掉 Type / Ability Battle Override
#==============================================================================
if defined?(ALBERT_CG::FORCE_SWITCH_V235)
  module ALBERT_CG
    module FORCE_SWITCH_V235
      class << self
        alias cg_v237_clear_switch_out_volatile clear_switch_out_volatile
        def clear_switch_out_volatile(battler)
          cg_v237_clear_switch_out_volatile(battler)
          battler.cg_v237_clear_identity if battler != nil && battler.respond_to?(:cg_v237_clear_identity)
        end
      end
    end
  end
end

#==============================================================================
# ■ Action Priority Regression：Batch D active 時使用 deterministic SPE
#==============================================================================
class Game_Battler
  alias cg_v237_priority_base_speed cg_priority_base_speed
  def cg_priority_base_speed
    override = @cg_priority_test_speed_override
    if defined?(ALBERT_CG::UNIQUE_D_V237) && ALBERT_CG::UNIQUE_D_V237.active? && override != nil
      return override.to_i
    end
    return cg_v237_priority_base_speed
  end
end

#==============================================================================
# ■ Game_Enemy：Batch D Regression 敵方行動
#==============================================================================
class Game_Enemy < Game_Battler
  alias cg_v237_enemy_make_action make_action
  def make_action
    if defined?(ALBERT_CG::UNIQUE_D_V237) && ALBERT_CG::UNIQUE_D_V237.active?
      forced = ALBERT_CG::UNIQUE_D_V237.forced_enemy_action(self)
      if forced != nil
        cg_assign_action(forced) if respond_to?(:cg_assign_action)
        @action = forced unless respond_to?(:cg_assign_action)
        return
      end
    end
    cg_v237_enemy_make_action
  end
end

#==============================================================================
# ■ Scene_Battle：3 回合 deterministic Regression
#==============================================================================
class Scene_Battle < Scene_Base
  alias cg_v237_execute_action execute_action
  def execute_action
    if defined?(ALBERT_CG::UNIQUE_D_V237) && ALBERT_CG::UNIQUE_D_V237.active?
      ALBERT_CG::UNIQUE_D_V237.record_execution(@active_battler)
    end
    cg_v237_execute_action
  end

  alias cg_v237_turn_end turn_end
  def turn_end
    ALBERT_CG::UNIQUE_D_V237.finish_round_assertions if
      defined?(ALBERT_CG::UNIQUE_D_V237) && ALBERT_CG::UNIQUE_D_V237.active?
    cg_v237_turn_end
  end

  alias cg_v237_start_party_command start_party_command_selection
  def start_party_command_selection
    unless defined?(ALBERT_CG::UNIQUE_D_V237) && ALBERT_CG::UNIQUE_D_V237.active?
      return cg_v237_start_party_command
    end
    cg_v237_start_party_command
    return unless $game_temp.in_battle
    ALBERT_CG::UNIQUE_D_V237.assert_bootstrap_once
    if ALBERT_CG::UNIQUE_D_V237.finished?
      ALBERT_CG::UNIQUE_D_V237.finish_suite
      battle_end(0)
      return
    end
    ALBERT_CG::UNIQUE_D_V237.prepare_round_actions
    start_main
  end
end

#==============================================================================
# ■ ALBERT_CG bootstrap：Scene_Battle 重建 Party 後重套 Batch D 測試資料
#==============================================================================
module ALBERT_CG
  class << self
    alias cg_v237_bootstrap_demo_party bootstrap_demo_party
    def bootstrap_demo_party
      result = cg_v237_bootstrap_demo_party
      if defined?(ALBERT_CG::UNIQUE_D_V237) && ALBERT_CG::UNIQUE_D_V237.active?
        ALBERT_CG::UNIQUE_D_V237::TEST_ALLIES.each do |cfg|
          ALBERT_CG::UNIQUE_D_V237.configure_actor(cfg)
        end
        human = $game_actors[ALBERT_CG::SOLO_HUMAN_ACTOR_ID]
        if human != nil
          human.change_level(ALBERT_CG::UNIQUE_D_V237::TEST_LEVEL,false)
          human.recover_all if human.respond_to?(:recover_all)
          human.cg_v237_clear_identity if human.respond_to?(:cg_v237_clear_identity)
        end
        ALBERT_CG::UNIQUE_D_V237.install_skill_scopes
      end
      return result
    end
  end
end

#==============================================================================
# ■ Scene_Title：Move Stub 建立後校正 Unique D Scope
#==============================================================================
class Scene_Title < Scene_Base
  alias cg_v237_load_database load_database
  def load_database
    cg_v237_load_database
    ALBERT_CG::UNIQUE_D_V237.install_skill_scopes
  end

  alias cg_v237_load_bt_database load_bt_database
  def load_bt_database
    cg_v237_load_bt_database
    ALBERT_CG::UNIQUE_D_V237.install_skill_scopes
  end
end

#==============================================================================
# ■ F11：v2.3.7a 成為唯一最新版 AutoRegression
#==============================================================================
if defined?(ALBERT_CG::UNIQUE_C_V236)
  module ALBERT_CG
    module UNIQUE_C_V236
      def self.f11_trigger?
        return false
      end
    end
  end
end

class Scene_Map < Scene_Base
  alias cg_v237_scene_map_update update
  def update
    cg_v237_scene_map_update
    if !$game_temp.in_battle && ALBERT_CG::UNIQUE_D_V237.f11_trigger?
      Sound.play_decision
      ALBERT_CG::UNIQUE_D_V237.start_auto_test
    end
  end
end

#==============================================================================
# ■ Coverage：14 個 Unique Pending 轉為 V237_UNIQUE_D_HANDLED
#==============================================================================
module ALBERT_CG
  module MOVE_EFFECT
    class << self
      alias cg_v237_coverage_v231 coverage_v231
      def coverage_v231(move_id)
        return "V237_UNIQUE_D_HANDLED" if ALBERT_CG::UNIQUE_D_V237.handled?(move_id)
        return cg_v237_coverage_v231(move_id)
      end
    end
  end
end
