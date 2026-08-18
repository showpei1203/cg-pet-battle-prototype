# RMVX_SCRIPT_INDEX: 120
# RMVX_SCRIPT_ID: 91000016
# RMVX_SCRIPT_NAME: CG Pet Lab v0.2.3
# RMVX_SOURCE_SHA256: faae7b3a419e81f2c2cc680e792a38f5d5849257cc0f40cab826fae7115fe105

#==============================================================================
# 【繁體中文說明】ALBERT CG 寵物名冊介面
#------------------------------------------------------------------------------
# 【用途】顯示主角持有的 Clone 寵物個體、物種、忠誠、傷勢、掉檔、技能與使用次數。
#  隊友固定普通 Actor 寵物不會出現在此名冊。
# 【使用】事件呼叫：$scene = Scene_CG_PetLab.new。
# 【v0.2.3】F5 使用地圖整備專用的派出／收回方法，不套用戰鬥格位判定。
# 【位置】請放在 CG Config 下方，並依專案腳本索引指定順序排列。
#==============================================================================

#==============================================================================
# ** ALBERT CG Pet Lab
#------------------------------------------------------------------------------
#  Version : 0.2.3
#------------------------------------------------------------------------------
#  Event call:
#    $scene = Scene_CG_PetLab.new
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PetLab"] = true

class Window_CG_PetList < Window_Selectable
  def initialize
    super(0, 56, 240, 360)
    @column_max = 1
    refresh
    self.index = 0
  end

  def pet
    return nil if @data == nil or @data.empty?
    return @data[self.index]
  end

  def refresh
    @data = $game_party.cg_owned_pets
    @item_max = [@data.size, 1].max
    create_contents
    if @data.empty?
      self.contents.draw_text(4, 0, contents.width - 8, WLH, "尚無寵物")
    else
      for i in 0...@data.size
        draw_item(i)
      end
    end
  end

  def draw_item(index)
    pet = @data[index]
    return if pet == nil
    rect = item_rect(index)
    self.contents.clear_rect(rect)
    active_pet = $game_party.respond_to?(:cg_actual_primary_clone_pet) ?
      $game_party.cg_actual_primary_clone_pet : $game_party.cg_active_pet
    active = active_pet != nil && active_pet.id == pet.id
    prefix = active ? "◆ " : "　"
    self.contents.draw_text(rect.x, rect.y, rect.width - 52, WLH,
                            prefix + pet.name)
    self.contents.draw_text(rect.x, rect.y, rect.width - 4, WLH,
                            "Lv." + pet.level.to_s, 2)
  end
end

class Window_CG_PetDetail < Window_Base
  def initialize
    super(240, 56, 304, 232)
    @pet = nil
  end

  def pet=(pet)
    return if @pet == pet
    @pet = pet
    refresh
  end

  def refresh
    self.contents.clear
    if @pet == nil
      self.contents.draw_text(0, 0, contents.width, WLH, "選擇一隻寵物")
      return
    end
    @pet.cg_prepare_pet_data
    y = 0
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 92, WLH, "個體 ID")
    self.contents.font.color = normal_color
    self.contents.draw_text(92, y, 180, WLH, @pet.id.to_s)
    y += WLH
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 92, WLH, "物種 ID")
    self.contents.font.color = normal_color
    self.contents.draw_text(92, y, 180, WLH, @pet.cg_species_id.to_s)
    y += WLH
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 92, WLH, "忠誠／傷勢")
    self.contents.font.color = normal_color
    self.contents.draw_text(92, y, 180, WLH,
                            @pet.cg_loyalty.to_s + "／" + @pet.cg_injury.to_s)
    y += WLH
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 92, WLH, "掉檔")
    self.contents.font.color = normal_color
    grades = []
    5.times { |i| grades.push(@pet.cg_grade_loss_at(i).to_s) }
    self.contents.draw_text(92, y, 180, WLH, grades.join(" / "))
    y += WLH
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 92, WLH, "技能")
    self.contents.font.color = normal_color
    names = @pet.skills.collect { |skill| skill.name }
    self.contents.draw_text(92, y, 180, WLH, names.join("、"))
    y += WLH
    self.contents.font.color = system_color
    self.contents.draw_text(0, y, 92, WLH, "使用次數")
    self.contents.font.color = normal_color
    counts = []
    for skill in @pet.skills
      counts.push(skill.name + ":" + @pet.cg_skill_use_count(skill.id).to_s)
    end
    self.contents.draw_text(0, y + WLH, contents.width, WLH, counts.join("  "))
  end
end

class Scene_CG_PetLab < Scene_Base
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
    $game_party.cg_normalize_pet_owners! if $game_party.respond_to?(:cg_normalize_pet_owners!)
    create_menu_background
    @title_window = Window_Base.new(0, 0, 544, 56)
    @title_window.contents.draw_text(0, 0, 512, Window_Base::WLH,
      "寵物名冊　C：操作　B：返回")
    @pet_window = Window_CG_PetList.new
    @detail_window = Window_CG_PetDetail.new
    @command_window = Window_Command.new(304, ["設為出戰", "收回目前寵物", "放生", "取消"])
    @command_window.x = 240
    @command_window.y = 288
    @command_window.active = false
    @command_window.index = -1
    refresh_detail
  end

  def terminate
    super
    dispose_menu_background
    @title_window.dispose
    @pet_window.dispose
    @detail_window.dispose
    @command_window.dispose
  end

  def update
    super
    update_menu_background
    @pet_window.update
    @command_window.update
    if @command_window.active
      update_command
    else
      update_pet_list
    end
    refresh_detail
  end

  def refresh_detail
    @detail_window.pet = @pet_window.pet
  end

  def update_pet_list
    if Input.trigger?(Input::B)
      Sound.play_cancel
      $scene = Scene_Map.new
    elsif Input.trigger?(Input::C)
      if @pet_window.pet == nil
        Sound.play_buzzer
      else
        Sound.play_decision
        @pet_window.active = false
        @command_window.active = true
        @command_window.index = 0
      end
    end
  end

  def update_command
    if Input.trigger?(Input::B)
      Sound.play_cancel
      close_command
      return
    end
    return unless Input.trigger?(Input::C)
    pet = @pet_window.pet
    case @command_window.index
    when 0
      if pet != nil and $game_party.cg_map_deploy_pet(pet.id)
        Sound.play_equip
        refresh_all
      else
        Sound.play_buzzer
      end
    when 1
      if $game_party.cg_map_recall_pet
        Sound.play_equip
        refresh_all
      else
        Sound.play_buzzer
      end
    when 2
      if pet != nil and $game_actors.cg_delete_pet(pet.id)
        Sound.play_decision
        refresh_all
      else
        Sound.play_buzzer
      end
    when 3
      Sound.play_cancel
    end
    close_command
  end

  def close_command
    @command_window.active = false
    @command_window.index = -1
    @pet_window.active = true
  end

  def refresh_all
    @pet_window.refresh
    @pet_window.index = [@pet_window.index, @pet_window.item_max - 1].min
    @detail_window.pet = nil
    refresh_detail
  end
end
