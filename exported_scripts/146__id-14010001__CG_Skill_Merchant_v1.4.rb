# RMVX_SCRIPT_INDEX: 146
# RMVX_SCRIPT_ID: 14010001
# RMVX_SCRIPT_NAME: CG Skill Merchant v1.4
# RMVX_SOURCE_SHA256: 042f9aa92bd6b52c327bb9f723f08a8c5ceedd4ee1c70eff35855f31afab32bd

#==============================================================================
# 【繁體中文說明】ALBERT CG 人類／寵物技能商人
#------------------------------------------------------------------------------
# 【版本】v1.4
# 【適用】RPG Maker VX / RGSS2 / Tankentai SBS 3.3
#
# 【正式規則】
#  1. 人類技能商人只販售 Lv.1 技能。
#  2. 人類技能學會後，靠實際使用與職業熟練倍率提升等級。
#  3. 寵物技能商人可直接販售 Lv.1～Lv.10 技能。
#  4. 寵物技能無法靠使用次數提升；只能購買較高等級或由特殊系統改變。
#  5. 技能欄已滿時，購買新技能必須當場選擇一格取代。
#  6. 人類不能購買目前職業／階級上限為 Lv.0 的技能。
#  7. 寵物已有同技能且等級不低於商品時，不能重複購買。
#
# 【測試操作】
#  地圖按實體鍵盤 F2：開啟技能商人測試入口。
#  第一次使用 F2 會補足 5000 G，僅供本原型測試；事件直接開店不會送錢。
#
# 【事件／腳本指令】
#  cg_open_human_skill_shop(:basic_human)
#  cg_open_pet_skill_shop(:basic_pet)
#  cg_open_skill_shop_hub
#
# 【設定方式】
#  HUMAN_SKILL_SHOPS：每項商品使用
#    {:skill_id=>59, :level=>1, :price=>120, :name=>"火焰魔法"}
#  人類商品的 level 即使誤設，也會強制視為 Lv.1。
#
#  PET_SKILL_SHOPS：可販售 Lv.1～Lv.10。
#
# 【腳本位置】
#  放在 CG Five Rank Job Core、CG Fixed Skill Slots 與
#  CG Skill Level Core 之後，Main 之前。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_SkillMerchant"] = true

module ALBERT_CG
  SKILL_MERCHANT_VERSION = "1.4"

  HUMAN_SKILL_SHOPS = {
    :basic_human => [
      {:skill_id=>59, :level=>1, :price=>120, :name=>"火焰魔法"},
      {:skill_id=>71, :level=>1, :price=>120, :name=>"水流魔法"},
      {:skill_id=>73, :level=>1, :price=>120, :name=>"大地魔法"},
      {:skill_id=>75, :level=>1, :price=>120, :name=>"風刃魔法"},
      {:skill_id=>33, :level=>1, :price=>100, :name=>"治療"},
      {:skill_id=>85, :level=>1, :price=>150, :name=>"連擊"}
    ]
  }

  PET_SKILL_SHOPS = {
    :basic_pet => [
      {:skill_id=>59, :level=>1,  :price=>100,  :name=>"火焰"},
      {:skill_id=>59, :level=>5,  :price=>650,  :name=>"火焰"},
      {:skill_id=>59, :level=>10, :price=>1800, :name=>"火焰"},
      {:skill_id=>71, :level=>1,  :price=>100,  :name=>"水流"},
      {:skill_id=>71, :level=>5,  :price=>650,  :name=>"水流"},
      {:skill_id=>71, :level=>10, :price=>1800, :name=>"水流"},
      {:skill_id=>73, :level=>3,  :price=>320,  :name=>"岩擊"},
      {:skill_id=>73, :level=>7,  :price=>980,  :name=>"岩擊"},
      {:skill_id=>75, :level=>3,  :price=>320,  :name=>"風刃"},
      {:skill_id=>75, :level=>7,  :price=>980,  :name=>"風刃"},
      {:skill_id=>33, :level=>3,  :price=>280,  :name=>"治癒"},
      {:skill_id=>33, :level=>6,  :price=>760,  :name=>"治癒"}
    ]
  }

  SKILL_PROFILE_DISPLAY_NAMES = {
    :default=>"一般",
    :physical=>"物理",
    :single_magic=>"單體魔法",
    :area_magic=>"範圍魔法",
    :healing=>"回復",
    :status=>"狀態／輔助"
  }

  # RGSS2 Input 沒有 Input::F2，使用 Win32 API 偵測實體 F2。
  CG_VK_F2 = 0x71 unless const_defined?(:CG_VK_F2)
  begin
    CG_GET_ASYNC_KEY_STATE_F2 = Win32API.new("user32", "GetAsyncKeyState", "i", "i") unless const_defined?(:CG_GET_ASYNC_KEY_STATE_F2)
  rescue
    CG_GET_ASYNC_KEY_STATE_F2 = nil unless const_defined?(:CG_GET_ASYNC_KEY_STATE_F2)
  end

  def self.cg_f2_trigger?
    return false if CG_GET_ASYNC_KEY_STATE_F2 == nil
    down = (CG_GET_ASYNC_KEY_STATE_F2.call(CG_VK_F2) & 0x8000) != 0
    trigger = down && @cg_f2_was_down != true
    @cg_f2_was_down = down
    return trigger
  rescue
    return false
  end

  def self.skill_shop_goods(kind, shop_id)
    source = kind == :pet ? PET_SKILL_SHOPS : HUMAN_SKILL_SHOPS
    data = source[shop_id]
    return data == nil ? [] : data
  end

  def self.skill_shop_good_skill(good)
    return nil if good == nil
    return $data_skills[good[:skill_id].to_i]
  end

  def self.skill_shop_good_level(kind, good)
    return 1 if kind == :human
    level = good == nil ? 1 : good[:level].to_i
    return [[level, 1].max, MAX_SKILL_LEVEL].min
  end

  def self.skill_shop_good_price(good)
    return good == nil ? 0 : [good[:price].to_i, 0].max
  end

  def self.skill_shop_good_name(good)
    return "" if good == nil
    text = good[:name]
    skill = skill_shop_good_skill(good)
    text = skill.name if (text == nil || text.to_s.empty?) && skill != nil
    return text == nil ? "" : text.to_s
  end

  def self.skill_shop_profile_display(skill_id)
    key = respond_to?(:skill_profile_key) ? skill_profile_key(skill_id) : :default
    text = SKILL_PROFILE_DISPLAY_NAMES[key]
    return text == nil ? key.to_s : text
  end

  def self.skill_shop_actor_valid?(actor, kind)
    return false if actor == nil
    if kind == :human
      return actor.respond_to?(:cg_skill_human?) && actor.cg_skill_human?
    else
      return actor.respond_to?(:cg_skill_pet?) && actor.cg_skill_pet?
    end
  end

  def self.skill_shop_status(actor, kind, good, check_gold = true)
    return :invalid_actor unless skill_shop_actor_valid?(actor, kind)
    skill = skill_shop_good_skill(good)
    return :invalid_skill if skill == nil
    skill_id = skill.id
    level = skill_shop_good_level(kind, good)

    if kind == :human
      cap = actor.respond_to?(:cg_human_skill_level_cap) ? actor.cg_human_skill_level_cap(skill_id).to_i : MAX_SKILL_LEVEL
      return :job_forbidden if cap <= 0
      return :already_known if actor.respond_to?(:cg_skill_slot_ids) && actor.cg_skill_slot_ids.include?(skill_id)
    else
      if actor.respond_to?(:cg_skill_slot_ids) && actor.cg_skill_slot_ids.include?(skill_id)
        current = actor.respond_to?(:cg_skill_level) ? actor.cg_skill_level(skill_id) : 1
        return :not_an_upgrade if current >= level
      end
    end

    if check_gold && $game_party != nil && $game_party.gold < skill_shop_good_price(good)
      return :not_enough_gold
    end
    return :ok
  end

  def self.skill_shop_status_text(status)
    case status
    when :ok
      return "可以購買"
    when :invalid_actor
      return "對象不符合商店類型"
    when :invalid_skill
      return "技能資料不存在"
    when :job_forbidden
      return "目前職業／階級不可學習"
    when :already_known
      return "人類已學會此技能"
    when :not_an_upgrade
      return "寵物目前技能等級不低於商品"
    when :not_enough_gold
      return "金錢不足"
    end
    return "無法購買"
  end

  def self.skill_shop_human_actors
    result = []
    return result if $game_party == nil
    for actor in $game_party.members
      next unless skill_shop_actor_valid?(actor, :human)
      result.push(actor) unless result.include?(actor)
    end
    return result
  end

  def self.skill_shop_pet_actors
    result = []
    return result if $game_party == nil

    if $game_party.respond_to?(:cg_carried_pets)
      for actor in $game_party.cg_carried_pets
        result.push(actor) if skill_shop_actor_valid?(actor, :pet) && !result.include?(actor)
      end
    end
    if $game_party.respond_to?(:cg_storage_pets)
      for actor in $game_party.cg_storage_pets
        result.push(actor) if skill_shop_actor_valid?(actor, :pet) && !result.include?(actor)
      end
    end

    for actor in $game_party.members
      result.push(actor) if skill_shop_actor_valid?(actor, :pet) && !result.include?(actor)
    end

    if defined?(ALBERT_CG::FIXED_PARTNER_PET_ACTORS)
      for owner_id in ALBERT_CG::FIXED_PARTNER_PET_ACTORS.keys
        owner_present = false
        for member in $game_party.members
          owner_present = true if member.id == owner_id.to_i
        end
        next unless owner_present
        pet_id = ALBERT_CG::FIXED_PARTNER_PET_ACTORS[owner_id].to_i
        pet = $game_actors[pet_id]
        result.push(pet) if skill_shop_actor_valid?(pet, :pet) && !result.include?(pet)
      end
    end
    return result
  end

  def self.skill_shop_actors(kind)
    return kind == :pet ? skill_shop_pet_actors : skill_shop_human_actors
  end
end

#==============================================================================
# ■ 選擇學習角色
#==============================================================================
class Window_CG_SkillShopActors < Window_Selectable
  attr_reader :kind

  def initialize(kind)
    super(0, 56, 220, 360)
    @kind = kind
    @column_max = 1
    refresh
    self.index = @item_max > 0 ? 0 : -1
  end

  def actor
    return nil if self.index < 0 || @data == nil
    return @data[self.index]
  end

  def refresh
    @data = ALBERT_CG.skill_shop_actors(@kind)
    @item_max = @data.size
    create_contents
    self.contents.clear
    for i in 0...@item_max
      draw_item(i)
    end
  end

  def draw_item(index)
    actor = @data[index]
    return if actor == nil
    rect = item_rect(index)
    self.contents.clear_rect(rect)
    self.contents.font.color = normal_color
    self.contents.draw_text(rect.x + 4, rect.y, rect.width - 8, rect.height, actor.name)
    if actor.respond_to?(:cg_skill_slot_ids) && actor.respond_to?(:cg_skill_slot_limit)
      used = actor.cg_skill_slot_ids.size
      limit = actor.cg_skill_slot_limit
      self.contents.font.color = system_color
      self.contents.draw_text(rect.x + rect.width - 72, rect.y, 68, rect.height,
        used.to_s + "/" + limit.to_s, 2)
    end
  end
end

#==============================================================================
# ■ 技能商品清單
#==============================================================================
class Window_CG_SkillShopGoods < Window_Selectable
  attr_reader :kind
  attr_reader :shop_id
  attr_reader :actor

  def initialize(kind, shop_id)
    super(220, 56, 324, 216)
    @kind = kind
    @shop_id = shop_id
    @actor = nil
    @goods = ALBERT_CG.skill_shop_goods(kind, shop_id)
    @column_max = 1
    refresh
    self.index = @item_max > 0 ? 0 : -1
  end

  def actor=(actor)
    return if @actor == actor
    @actor = actor
    refresh
  end

  def good
    return nil if self.index < 0 || @goods == nil
    return @goods[self.index]
  end

  def enabled?(good)
    return ALBERT_CG.skill_shop_status(@actor, @kind, good, true) == :ok
  end

  def refresh
    @item_max = @goods == nil ? 0 : @goods.size
    create_contents
    self.contents.clear
    for i in 0...@item_max
      draw_item(i)
    end
  end

  def draw_item(index)
    good = @goods[index]
    return if good == nil
    rect = item_rect(index)
    self.contents.clear_rect(rect)
    enabled = enabled?(good)
    self.contents.font.color = enabled ? normal_color : text_color(7)
    name = ALBERT_CG.skill_shop_good_name(good)
    level = ALBERT_CG.skill_shop_good_level(@kind, good)
    self.contents.draw_text(rect.x + 4, rect.y, rect.width - 128, rect.height, name)
    self.contents.draw_text(rect.x + rect.width - 124, rect.y, 52, rect.height,
      "Lv." + level.to_s, 2)
    self.contents.draw_text(rect.x + rect.width - 68, rect.y, 64, rect.height,
      ALBERT_CG.skill_shop_good_price(good).to_s + "G", 2)
  end
end

#==============================================================================
# ■ 商品詳細
#==============================================================================
class Window_CG_SkillShopInfo < Window_Base
  attr_accessor :actor
  attr_accessor :good
  attr_accessor :kind
  attr_accessor :notice

  def initialize
    super(220, 272, 324, 144)
    @actor = nil
    @good = nil
    @kind = :human
    @notice = ""
    refresh
  end

  def refresh
    self.contents.clear
    self.contents.font.size = 16
    draw_pair(0, "持有金", ($game_party == nil ? 0 : $game_party.gold).to_s + " G")
    if @actor == nil || @good == nil
      self.contents.font.color = text_color(7)
      self.contents.draw_text(0, 28, contents.width, 24, "請先選擇角色與技能。")
      self.contents.font.size = Font.default_size
      return
    end

    skill = ALBERT_CG.skill_shop_good_skill(@good)
    skill_id = skill == nil ? 0 : skill.id
    level = ALBERT_CG.skill_shop_good_level(@kind, @good)
    current = @actor.respond_to?(:cg_skill_slot_ids) && @actor.cg_skill_slot_ids.include?(skill_id) ? @actor.cg_skill_level(skill_id) : 0
    profile = ALBERT_CG.skill_shop_profile_display(skill_id)
    draw_pair(24, "對象", @actor.name)
    draw_pair(48, "技能類型", profile)
    if @kind == :human
      cap = @actor.respond_to?(:cg_human_skill_level_cap) ? @actor.cg_human_skill_level_cap(skill_id) : 10
      draw_pair(72, "職業上限", "Lv." + cap.to_s)
    else
      draw_pair(72, "目前／販售", "Lv." + current.to_s + " → Lv." + level.to_s)
    end
    status = ALBERT_CG.skill_shop_status(@actor, @kind, @good, true)
    text = @notice.to_s.empty? ? ALBERT_CG.skill_shop_status_text(status) : @notice.to_s
    self.contents.font.color = status == :ok || !@notice.to_s.empty? ? normal_color : text_color(7)
    self.contents.draw_text(0, 88, contents.width, 24, text)
    self.contents.font.size = Font.default_size
  end

  def draw_pair(y, label, value)
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 82, 24, label)
    self.contents.font.color = normal_color
    self.contents.draw_text(82, y, contents.width - 82, 24, value.to_s)
  end
end

#==============================================================================
# ■ 技能格滿時的取代視窗
#==============================================================================
class Window_CG_SkillShopReplace < Window_Selectable
  def initialize(actor)
    super(72, 88, 400, 280)
    @actor = actor
    @column_max = 1
    @item_max = actor.cg_skill_slot_ids.size
    refresh
    self.index = @item_max > 0 ? 0 : -1
  end

  def refresh
    create_contents
    self.contents.clear
    for i in 0...@item_max
      draw_item(i)
    end
  end

  def draw_item(index)
    rect = item_rect(index)
    self.contents.clear_rect(rect)
    skill_id = @actor.cg_skill_slot_ids[index]
    skill = $data_skills[skill_id]
    return if skill == nil
    level = @actor.cg_skill_level(skill_id)
    self.contents.font.color = system_color
    self.contents.draw_text(rect.x + 4, rect.y, 34, rect.height, (index + 1).to_s + ".")
    self.contents.font.color = normal_color
    self.contents.draw_text(rect.x + 38, rect.y, rect.width - 108, rect.height, skill.name)
    self.contents.draw_text(rect.x + rect.width - 68, rect.y, 64, rect.height,
      "Lv." + level.to_s, 2)
  end
end

#==============================================================================
# ■ 技能商人主畫面
#==============================================================================
class Scene_CG_SkillShop < Scene_Base
  def initialize(kind, shop_id, return_to_hub = true)
    @kind = kind
    @shop_id = shop_id
    @return_to_hub = return_to_hub
    @mode = :actor
    @last_actor_index = nil
    @last_good_index = nil
    @pending_good = nil
  end

  def main
    start
    perform_transition
    Input.update
    loop do
      Graphics.update
      Input.update
      update
      break if $scene != self
    end
    Graphics.update
    pre_terminate
    Graphics.freeze
    terminate
  end

  def start
    super
    create_menu_background
    @title_window = Window_Base.new(0, 0, 544, 56)
    title = @kind == :pet ? "寵物技能商人" : "人類技能商人"
    @title_window.contents.draw_text(0, 0, 512, Window_Base::WLH,
      title + "　C：決定　B：返回")
    @actor_window = Window_CG_SkillShopActors.new(@kind)
    @goods_window = Window_CG_SkillShopGoods.new(@kind, @shop_id)
    @info_window = Window_CG_SkillShopInfo.new
    @info_window.kind = @kind
    @actor_window.active = true
    @goods_window.active = false
    sync_actor
    sync_good
  end

  def terminate
    super
    dispose_menu_background
    @title_window.dispose if @title_window != nil
    @actor_window.dispose if @actor_window != nil
    @goods_window.dispose if @goods_window != nil
    @info_window.dispose if @info_window != nil
    dispose_replace_windows
  end

  def update
    super
    update_menu_background
    @actor_window.update
    @goods_window.update
    @info_window.update
    sync_actor
    sync_good
    case @mode
    when :actor
      update_actor_mode
    when :goods
      update_goods_mode
    when :replace
      update_replace_mode
    end
  end

  def sync_actor
    return if @last_actor_index == @actor_window.index
    @last_actor_index = @actor_window.index
    actor = @actor_window.actor
    @goods_window.actor = actor
    @info_window.actor = actor
    @info_window.notice = ""
    @info_window.refresh
  end

  def sync_good
    return if @last_good_index == @goods_window.index && @info_window.good == @goods_window.good
    @last_good_index = @goods_window.index
    @info_window.good = @goods_window.good
    @info_window.notice = ""
    @info_window.refresh
  end

  def update_actor_mode
    if Input.trigger?(Input::B)
      Sound.play_cancel
      return_scene
      return
    end
    return unless Input.trigger?(Input::C)
    if @actor_window.actor == nil || @goods_window.item_max <= 0
      Sound.play_buzzer
      return
    end
    Sound.play_decision
    @mode = :goods
    @actor_window.active = false
    @goods_window.active = true
    @goods_window.index = 0 if @goods_window.index < 0
    @last_good_index = nil
  end

  def update_goods_mode
    if Input.trigger?(Input::B)
      Sound.play_cancel
      @mode = :actor
      @goods_window.active = false
      @actor_window.active = true
      return
    end
    return unless Input.trigger?(Input::C)
    attempt_purchase(nil)
  end

  def attempt_purchase(replace_index)
    actor = @actor_window.actor
    good = @goods_window.good
    status = ALBERT_CG.skill_shop_status(actor, @kind, good, true)
    if status != :ok
      Sound.play_buzzer
      @info_window.notice = ALBERT_CG.skill_shop_status_text(status)
      @info_window.refresh
      return
    end

    skill = ALBERT_CG.skill_shop_good_skill(good)
    level = ALBERT_CG.skill_shop_good_level(@kind, good)
    price = ALBERT_CG.skill_shop_good_price(good)

    # 寵物已有同技能時直接升級，不占用新技能格。
    if @kind == :pet && actor.cg_skill_slot_ids.include?(skill.id)
      actor.cg_set_skill_level(skill.id, level)
      complete_purchase(price, skill.name + " 已提升至 Lv." + level.to_s)
      return
    end

    result = actor.cg_learn_skill_to_slot(skill.id, level, replace_index)
    if result == :need_replace
      open_replace_windows(actor, good)
      return
    elsif result != true
      Sound.play_buzzer
      @info_window.notice = "學習失敗"
      @info_window.refresh
      return
    end
    complete_purchase(price, skill.name + " 學習完成")
  end

  def complete_purchase(price, text)
    $game_party.lose_gold(price)
    Sound.play_shop
    @actor_window.refresh
    @goods_window.refresh
    @info_window.notice = text
    @info_window.refresh
  end

  def open_replace_windows(actor, good)
    Sound.play_decision
    @pending_good = good
    @mode = :replace
    @goods_window.active = false
    @replace_title = Window_Base.new(72, 32, 400, 56)
    @replace_title.z = 500
    @replace_title.contents.draw_text(0, 0, 368, Window_Base::WLH,
      "技能欄已滿：選擇要遺忘的技能")
    @replace_window = Window_CG_SkillShopReplace.new(actor)
    @replace_window.z = 500
    @replace_window.active = true
  end

  def update_replace_mode
    @replace_window.update if @replace_window != nil
    if Input.trigger?(Input::B)
      Sound.play_cancel
      dispose_replace_windows
      @mode = :goods
      @goods_window.active = true
      return
    end
    return unless Input.trigger?(Input::C)
    if @replace_window == nil || @replace_window.index < 0
      Sound.play_buzzer
      return
    end
    index = @replace_window.index
    dispose_replace_windows
    @mode = :goods
    @goods_window.active = true
    attempt_purchase(index)
  end

  def dispose_replace_windows
    if @replace_title != nil
      @replace_title.dispose unless @replace_title.disposed?
      @replace_title = nil
    end
    if @replace_window != nil
      @replace_window.dispose unless @replace_window.disposed?
      @replace_window = nil
    end
    @pending_good = nil
  end

  def return_scene
    if @return_to_hub
      $scene = Scene_CG_SkillShopHub.new
    else
      $scene = Scene_Map.new
    end
  end
end

#==============================================================================
# ■ F2 測試入口
#==============================================================================
class Scene_CG_SkillShopHub < Scene_Base
  def main
    start
    perform_transition
    Input.update
    loop do
      Graphics.update
      Input.update
      update
      break if $scene != self
    end
    Graphics.update
    pre_terminate
    Graphics.freeze
    terminate
  end

  def start
    super
    create_menu_background
    @title_window = Window_Base.new(0, 0, 544, 56)
    @title_window.contents.draw_text(0, 0, 512, Window_Base::WLH,
      "技能商人測試入口　F2 開啟")
    @command_window = Window_Command.new(304,
      ["人類技能商人", "寵物技能商人", "返回地圖"])
    @command_window.x = 120
    @command_window.y = 112
  end

  def terminate
    super
    dispose_menu_background
    @title_window.dispose if @title_window != nil
    @command_window.dispose if @command_window != nil
  end

  def update
    super
    update_menu_background
    @command_window.update
    if Input.trigger?(Input::B)
      Sound.play_cancel
      $scene = Scene_Map.new
      return
    end
    return unless Input.trigger?(Input::C)
    case @command_window.index
    when 0
      Sound.play_decision
      $scene = Scene_CG_SkillShop.new(:human, :basic_human, true)
    when 1
      Sound.play_decision
      $scene = Scene_CG_SkillShop.new(:pet, :basic_pet, true)
    when 2
      Sound.play_cancel
      $scene = Scene_Map.new
    end
  end
end

class Game_Interpreter
  def cg_open_human_skill_shop(shop_id = :basic_human)
    return false if ALBERT_CG.skill_shop_goods(:human, shop_id).empty?
    $scene = Scene_CG_SkillShop.new(:human, shop_id, false)
    return true
  end

  def cg_open_pet_skill_shop(shop_id = :basic_pet)
    return false if ALBERT_CG.skill_shop_goods(:pet, shop_id).empty?
    $scene = Scene_CG_SkillShop.new(:pet, shop_id, false)
    return true
  end

  def cg_open_skill_shop_hub
    $scene = Scene_CG_SkillShopHub.new
    return true
  end
end

class Scene_Map < Scene_Base
  alias albert_cg_v14_skill_shop_update update
  def update
    albert_cg_v14_skill_shop_update
    if ALBERT_CG.cg_f2_trigger? && !$game_temp.in_battle
      if $game_system != nil && $game_system.instance_variable_get(:@cg_v14_skill_shop_test_gold_given) != true
        need = 5000 - $game_party.gold
        $game_party.gain_gold(need) if need > 0
        $game_system.instance_variable_set(:@cg_v14_skill_shop_test_gold_given, true)
      end
      Sound.play_decision
      $scene = Scene_CG_SkillShopHub.new
    end
  end
end

module ALBERT_CG
  def self.apply_v14_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.4"
  end
end

class Scene_Title < Scene_Base
  alias albert_cg_v14_skill_shop_load_database load_database
  def load_database
    albert_cg_v14_skill_shop_load_database
    ALBERT_CG.apply_v14_title
  end

  alias albert_cg_v14_skill_shop_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v14_skill_shop_load_bt_database
    ALBERT_CG.apply_v14_title
  end
end
